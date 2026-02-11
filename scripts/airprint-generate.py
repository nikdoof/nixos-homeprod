#!/usr/bin/python3

"""
Copyright (c) 2010 Timothy J Fontaine <tjfontaine@atxconsulting.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

import argparse
import logging
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib.parse import ParseResult, urlparse
from xml.etree.ElementTree import Element, ElementTree, indent, tostring

import cups

# Configure logging first
logging.basicConfig(format="%(levelname)s: %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)


# Version information
__version__ = "1.2.0"

# Named constants
MAX_TXT_RECORD_LENGTH = 255
DEFAULT_CUPS_PORT = 631
EXIT_CODE_USER_CANCELLED = 130
EXIT_CODE_ERROR = 1

# Service type constants
IPP_SERVICE_TYPE = "_ipp._tcp"
IPP_SERVICE_SUBTYPE = "_universal._sub._ipp._tcp"

DOCUMENT_TYPES = {
    # These content-types will be at the front of the list
    "application/pdf": True,
    "application/postscript": True,
    "application/vnd.cups-raster": True,
    "application/octet-stream": True,
    "image/pwg-raster": True,
    "image/urf": True,
    "image/png": True,
    "image/tiff": True,
    "image/jpeg": True,
    "image/gif": True,
    "text/plain": True,
    "text/html": True,
    # These content-types will never be reported
    "image/x-xwindowdump": False,
    "image/x-xpixmap": False,
    "image/x-xbitmap": False,
    "image/x-sun-raster": False,
    "image/x-sgi-rgb": False,
    "image/x-portable-pixmap": False,
    "image/x-portable-graymap": False,
    "image/x-portable-bitmap": False,
    "image/x-portable-anymap": False,
    "application/x-shell": False,
    "application/x-perl": False,
    "application/x-csource": False,
    "application/x-cshell": False,
}


@dataclass
class AirPrintConfig:
    """Configuration for AirPrint service generation."""

    host: Optional[str] = None
    user: Optional[str] = None
    port: Optional[int] = None
    verbose: bool = False
    directory: Optional[Path] = None
    prefix: str = "AirPrint-"
    adminurl: bool = False
    descName: bool = False
    insecure: bool = False


class AirPrintGenerate:
    """Generate Avahi service files for AirPrint from CUPS printers."""

    def __init__(self, config: AirPrintConfig) -> None:
        self.config = config

        if self.config.user:
            cups.setUser(self.config.user)
            logger.debug(f"Set CUPS user to: {self.config.user}")

        # Disable SSL certificate verification if insecure flag is set
        if self.config.insecure:
            os.environ["CUPS_SSL_VERIFY"] = "0"
            logger.warning("SSL certificate verification disabled - this is insecure!")

        # Set logging level based on verbose flag
        if self.config.verbose:
            logger.setLevel(logging.DEBUG)

    def _connect_to_cups(self) -> cups.Connection:
        """Establish connection to CUPS server."""
        try:
            if not self.config.host:
                logger.debug("Connecting to local CUPS server")
                conn = cups.Connection()
            else:
                port = self.config.port or DEFAULT_CUPS_PORT
                logger.debug(f"Connecting to CUPS server at {self.config.host}:{port}")
                conn = cups.Connection(self.config.host, port)
            return conn
        except RuntimeError as e:
            error_msg = str(e).lower()
            if "certificate" in error_msg or "ssl" in error_msg or "tls" in error_msg:
                logger.error(f"SSL/TLS certificate error: {e}")
                logger.info(
                    "Hint: Try using the --insecure (-k) flag to disable certificate verification for self-signed certificates"
                )
                logger.info(
                    "      Example: airprint-generate.py -H cups.example.com -k"
                )
            else:
                logger.error(f"Failed to connect to CUPS server: {e}")
            raise
        except Exception as e:
            logger.error(f"Failed to connect to CUPS server: {e}")
            if self.config.host and not self.config.insecure:
                logger.info(
                    "If the server uses a self-signed certificate, try the --insecure (-k) flag"
                )
            raise

    def _get_port_number(self, uri: ParseResult) -> int:
        """Extract port number from URI or use defaults."""
        port_no = uri.port or self.config.port or cups.getPort()
        logger.debug(f"Using port: {port_no}")
        return port_no

    def _extract_resource_path(self, uri: ParseResult) -> str:
        """Extract and clean the resource path from URI."""
        path = uri.path if hasattr(uri, "path") else uri[2]

        # Extract path from format: //host:port/path
        if match := re.match(r"^//(.*):(\d+)(/.*)", path):
            path = match.group(3)

        # Remove leading slashes
        path = path.lstrip("/")
        logger.debug(f"Resource path: {path}")
        return path

    def _add_txt_record(
        self, service: Any, text: str, log_msg: Optional[str] = None
    ) -> None:
        """Add a TXT record to the service."""
        txt_record = Element("txt-record")
        txt_record.text = text
        service.append(txt_record)
        if log_msg:
            logger.debug(log_msg)

    def _add_color_support(self, service: Any, attrs: Dict[str, Any]) -> None:
        """Add color support attribute if available."""
        if attrs.get("color-supported"):
            self._add_txt_record(service, "Color=T", "Added color support")

    def _add_paper_size(self, service: Any, attrs: Dict[str, Any]) -> None:
        """Add paper size attribute if using A4."""
        if attrs.get("media-default") == "iso_a4_210x297mm":
            self._add_txt_record(
                service, "PaperMax=legal-A4", "Added paper size: legal-A4"
            )

    def _add_urf_support(self, service: Any, attrs: Dict[str, Any]) -> bool:
        """Add URF (Universal Raster Format) support."""
        if urf_supported := attrs.get("urf-supported"):
            urf_str = ",".join(urf_supported)
            self._add_txt_record(
                service, f"URF={urf_str}", f"Added URF support: {urf_str}"
            )
            return True
        return False

    def _add_duplex_support(self, service: Any, attrs: Dict[str, Any]) -> bool:
        """Add duplex printing support."""
        sides = attrs.get("sides-supported", [])
        if any("two-sided" in side for side in sides):
            self._add_txt_record(service, "Duplex=T", "Added duplex support")
            return True
        return False

    def _build_pdl_list(self, attrs: Dict[str, Any], printer_name: str) -> List[str]:
        """Build the PDL (Page Description Language) list."""
        supported_formats = attrs["document-format-supported"]

        # Separate into priority and deferred formats
        fmts = [mt for mt in supported_formats if DOCUMENT_TYPES.get(mt) is True]
        defer = [mt for mt in supported_formats if mt not in DOCUMENT_TYPES]

        if "image/urf" not in fmts:
            logger.warning(
                f"Printer '{printer_name}': image/urf is not in MIME types, "
                f"may not be available on iOS 6+ "
                f"(see https://github.com/tjfontaine/airprint-generate/issues/5)"
            )

        all_formats = [*fmts, *defer]
        logger.debug(
            f"Supported formats ({len(all_formats)}): {', '.join(all_formats)}"
        )
        return all_formats

    def _truncate_pdl_if_needed(self, fmts: List[str], printer_name: str) -> str:
        """Truncate PDL list if it exceeds MAX_TXT_RECORD_LENGTH character limit."""
        fmts_str = ",".join(fmts)
        dropped = []

        while len(f"pdl={fmts_str}") >= MAX_TXT_RECORD_LENGTH:
            fmts_list = fmts_str.rsplit(",", 1)
            if len(fmts_list) == 2:
                fmts_str, last = fmts_list
                dropped.append(last)
            else:
                break

        if dropped:
            logger.warning(
                f"Printer '{printer_name}': Dropped {len(dropped)} format(s) due to "
                f"{MAX_TXT_RECORD_LENGTH} char limit: {', '.join(reversed(dropped))}"
            )

        return fmts_str

    def _write_service_file(self, tree: ElementTree, fname: str) -> None:
        """Write the service file to disk."""
        try:
            # Add DOCTYPE declaration
            xml_declaration = '<?xml version="1.0" encoding="UTF-8"?>\n'
            doctype = '<!DOCTYPE service-group SYSTEM "avahi-service.dtd">\n'

            # Pretty print the XML
            root = tree.getroot()
            if root is not None:
                indent(root, space="  ")
                xml_str = tostring(root, encoding="unicode")  # type: ignore[call-overload]
            else:
                xml_str = ""

            # Write with DOCTYPE
            with open(fname, "w", encoding="utf-8") as f:
                f.write(xml_declaration)
                f.write(doctype)
                f.write(xml_str)
                f.write("\n")

            logger.info(f"Created service file: {fname}")
        except IOError as e:
            logger.error(f"Failed to write service file '{fname}': {e}")
            raise

    def generate(self) -> None:
        """Generate Avahi service files for all shared CUPS printers."""
        conn = self._connect_to_cups()

        try:
            printers = conn.getPrinters()
        except Exception as e:
            logger.error(f"Failed to get printers from CUPS: {e}")
            raise

        shared_printers = {
            p: v for p, v in printers.items() if v.get("printer-is-shared")
        }

        logger.info(f"Found {len(printers)} printer(s), {len(shared_printers)} shared")

        if not shared_printers:
            logger.warning("No shared printers found")
            return

        for printer_name, printer_info in shared_printers.items():
            logger.info(f"Processing printer: {printer_name}")

            try:
                self._generate_printer_service(conn, printer_name, printer_info)
            except Exception as e:
                logger.error(f"Failed to generate service for '{printer_name}': {e}")
                if self.config.verbose:
                    logger.exception("Detailed error:")

    def _generate_printer_service(
        self, conn: cups.Connection, printer_name: str, printer_info: Dict[str, Any]
    ) -> None:
        """Generate service file for a single printer."""
        attrs = conn.getPrinterAttributes(printer_name)
        uri = urlparse(printer_info["printer-uri-supported"])

        logger.debug(f"Printer URI: {printer_info['printer-uri-supported']}")
        logger.debug(f"Printer info: {printer_info.get('printer-info', 'N/A')}")
        logger.debug(f"Printer location: {printer_info.get('printer-location', 'N/A')}")

        # Build XML structure programmatically
        root = Element("service-group")

        # Set service name
        name = Element("name")
        name.set("replace-wildcards", "yes")
        if self.config.descName:
            name.text = printer_info["printer-info"]
        else:
            name.text = f"AirPrint {printer_name} @ %h"
        logger.debug(f"Service name: {name.text}")
        root.append(name)

        # Create service element
        service = Element("service")
        root.append(service)

        # Add service type and subtype
        service_type = Element("type")
        service_type.text = IPP_SERVICE_TYPE
        service.append(service_type)

        service_subtype = Element("subtype")
        service_subtype.text = IPP_SERVICE_SUBTYPE
        service.append(service_subtype)

        # Set port
        port = Element("port")
        port_no = self._get_port_number(uri)
        port.text = str(port_no)
        service.append(port)

        # Add base TXT records
        for txt in ("txtvers=1", "qtotal=1", "Transparent=T"):
            self._add_txt_record(service, txt)

        # Add resource path
        rp = self._extract_resource_path(uri)
        self._add_txt_record(service, f"rp={rp}")

        # Add description/note
        note = (
            printer_info["printer-location"]
            if self.config.descName
            else printer_info["printer-info"]
        )
        self._add_txt_record(service, f"note={note}")

        # Add printer capabilities
        self._add_color_support(service, attrs)
        self._add_paper_size(service, attrs)

        has_urf = self._add_urf_support(service, attrs)
        has_duplex = self._add_duplex_support(service, attrs)

        # Add hardcoded URF if duplex but no URF
        if has_duplex and not has_urf:
            self._add_txt_record(
                service, "URF=DM3", "Added hardcoded URF=DM3 for duplex support"
            )

        # Add standard printer information
        self._add_txt_record(service, "product=(GPL Ghostscript)")
        self._add_txt_record(service, f"printer-state={printer_info['printer-state']}")
        self._add_txt_record(
            service, f"printer-type={hex(printer_info['printer-type'])}"
        )

        # Build and add PDL list
        all_formats = self._build_pdl_list(attrs, printer_name)
        fmts_str = self._truncate_pdl_if_needed(all_formats, printer_name)
        self._add_txt_record(service, f"pdl={fmts_str}")

        # Add admin URL if requested
        if self.config.adminurl:
            admin_url = printer_info["printer-uri-supported"]
            self._add_txt_record(
                service, f"adminurl={admin_url}", f"Added admin URL: {admin_url}"
            )

        # Write service file
        fname = f"{self.config.prefix}{printer_name}.service"
        if self.config.directory:
            fname = str(self.config.directory / fname)

        tree = ElementTree(root)
        self._write_service_file(tree, fname)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Avahi service files for AirPrint from CUPS printers",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
        help="Show program version and exit",
    )
    parser.add_argument(
        "-H",
        "--host",
        dest="hostname",
        help="Hostname of CUPS server (optional)",
        metavar="HOSTNAME",
    )
    parser.add_argument(
        "-P",
        "--port",
        type=int,
        dest="port",
        help="Port number of CUPS server (default: 631)",
        metavar="PORT",
    )
    parser.add_argument(
        "-u",
        "--user",
        dest="username",
        help="Username to authenticate with against CUPS",
        metavar="USER",
    )
    parser.add_argument(
        "-d",
        "--directory",
        dest="directory",
        type=Path,
        help="Directory to create service files",
        metavar="DIRECTORY",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        dest="verbose",
        help="Print debugging information to STDERR",
    )
    parser.add_argument(
        "-p",
        "--prefix",
        dest="prefix",
        default="AirPrint-",
        help="Prefix all files with this string (default: AirPrint-)",
        metavar="PREFIX",
    )
    parser.add_argument(
        "-a",
        "--admin",
        action="store_true",
        dest="adminurl",
        help="Include the printer specified URI as the adminurl",
    )
    parser.add_argument(
        "-x",
        "--desc",
        action="store_true",
        dest="descName",
        help="Use CUPS description as the printer display name",
    )
    parser.add_argument(
        "-k",
        "--insecure",
        action="store_true",
        dest="insecure",
        help="Allow insecure SSL connections (disable certificate verification)",
    )

    args = parser.parse_args()

    # Set up password callback for CUPS
    from getpass import getpass

    cups.setPasswordCB(getpass)

    # Create directory if needed
    if args.directory:
        try:
            args.directory.mkdir(parents=True, exist_ok=True)
            logger.info(f"Created directory: {args.directory}")
        except OSError as e:
            logger.error(f"Failed to create directory '{args.directory}': {e}")
            sys.exit(EXIT_CODE_ERROR)

    try:
        config = AirPrintConfig(
            host=args.hostname,
            user=args.username,
            port=args.port,
            verbose=args.verbose,
            directory=args.directory,
            prefix=args.prefix,
            adminurl=args.adminurl,
            descName=args.descName,
            insecure=args.insecure,
        )

        apg = AirPrintGenerate(config)
        apg.generate()
        logger.info("Service generation completed successfully")
    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
        sys.exit(EXIT_CODE_USER_CANCELLED)
    except Exception as e:
        logger.error(f"Failed to generate service files: {e}")
        sys.exit(EXIT_CODE_ERROR)


if __name__ == "__main__":
    main()
