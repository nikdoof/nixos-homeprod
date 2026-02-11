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
import os.path
import re
import sys
from io import StringIO
from urllib.parse import urlparse
from xml.dom import minidom
from xml.dom.minidom import parseString

import cups

try:
    import lxml.etree as etree
    from lxml.etree import Element, ElementTree
except ImportError:
    etree = None
    try:
        from xml.etree.ElementTree import Element, ElementTree
    except ImportError:
        try:
            from elementtree import Element, ElementTree
        except ImportError:
            raise ImportError(
                "Failed to find python libxml or elementtree, please install one of those or use python >= 2.5"
            )

# Configure logging
logging.basicConfig(format="%(levelname)s: %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

XML_TEMPLATE = """<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
<name replace-wildcards="yes"></name>
<service>
	<type>_ipp._tcp</type>
	<subtype>_universal._sub._ipp._tcp</subtype>
	<port>631</port>
	<txt-record>txtvers=1</txt-record>
	<txt-record>qtotal=1</txt-record>
	<txt-record>Transparent=T</txt-record>
</service>
</service-group>"""

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


class AirPrintGenerate(object):
    def __init__(
        self,
        host=None,
        user=None,
        port=None,
        verbose=False,
        directory=None,
        prefix="AirPrint-",
        adminurl=False,
        descName=False,
        insecure=False,
    ):
        self.host = host
        self.user = user
        self.port = port
        self.verbose = verbose
        self.directory = directory
        self.prefix = prefix
        self.adminurl = adminurl
        self.descName = descName
        self.insecure = insecure

        if self.user:
            cups.setUser(self.user)
            logger.debug(f"Set CUPS user to: {self.user}")

        # Disable SSL certificate verification if insecure flag is set
        if self.insecure:
            os.environ["CUPS_SSL_VERIFY"] = "0"
            logger.warning("SSL certificate verification disabled - this is insecure!")

        # Set logging level based on verbose flag
        if self.verbose:
            logger.setLevel(logging.DEBUG)

    def _connect_to_cups(self):
        """Establish connection to CUPS server."""
        try:
            if not self.host:
                logger.debug("Connecting to local CUPS server")
                conn = cups.Connection()
            else:
                if not self.port:
                    self.port = 631
                logger.debug(f"Connecting to CUPS server at {self.host}:{self.port}")
                conn = cups.Connection(self.host, self.port)
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to CUPS server: {e}")
            raise

    def _get_port_number(self, uri):
        """Extract port number from URI or use defaults."""
        port_no = None
        if hasattr(uri, "port"):
            port_no = uri.port
        if not port_no:
            port_no = self.port
        if not port_no:
            port_no = cups.getPort()

        logger.debug(f"Using port: {port_no}")
        return port_no

    def _extract_resource_path(self, uri):
        """Extract and clean the resource path from URI."""
        if hasattr(uri, "path"):
            rp = uri.path
        else:
            rp = uri[2]

        re_match = re.match(r"^//(.*):(\d+)(/.*)", rp)
        if re_match:
            rp = re_match.group(3)

        # Remove leading slashes from path
        rp = re.sub(r"^/+", "", rp)
        logger.debug(f"Resource path: {rp}")
        return rp

    def _add_color_support(self, service, attrs):
        """Add color support attribute if available."""
        if attrs.get("color-supported"):
            color = Element("txt-record")
            color.text = "Color=T"
            service.append(color)
            logger.debug("Added color support")

    def _add_paper_size(self, service, attrs):
        """Add paper size attribute if using A4."""
        if attrs.get("media-default") == "iso_a4_210x297mm":
            max_paper = Element("txt-record")
            max_paper.text = "PaperMax=legal-A4"
            service.append(max_paper)
            logger.debug("Added paper size: legal-A4")

    def _add_urf_support(self, service, attrs):
        """Add URF (Universal Raster Format) support."""
        if "urf-supported" in attrs:
            urf = Element("txt-record")
            delimiter = ","
            urf_attr_join_str = delimiter.join(attrs["urf-supported"])
            urf.text = f"URF={urf_attr_join_str}"
            service.append(urf)
            logger.debug(f"Added URF support: {urf_attr_join_str}")
            return True
        return False

    def _add_duplex_support(self, service, attrs):
        """Add duplex printing support."""
        if "sides-supported" in attrs and any(
            "two-sided" in element for element in attrs["sides-supported"]
        ):
            duplex = Element("txt-record")
            duplex.text = "Duplex=T"
            service.append(duplex)
            logger.debug("Added duplex support")
            return True
        return False

    def _build_pdl_list(self, attrs, printer_name):
        """Build the PDL (Page Description Language) list."""
        fmts = []
        defer = []

        for mime_type in attrs["document-format-supported"]:
            if mime_type in DOCUMENT_TYPES:
                if DOCUMENT_TYPES[mime_type]:
                    fmts.append(mime_type)
            else:
                defer.append(mime_type)

        if "image/urf" not in fmts:
            logger.warning(
                f"Printer '{printer_name}': image/urf is not in MIME types, "
                f"may not be available on iOS 6+ "
                f"(see https://github.com/tjfontaine/airprint-generate/issues/5)"
            )

        all_formats = fmts + defer
        logger.debug(
            f"Supported formats ({len(all_formats)}): {', '.join(all_formats)}"
        )

        return all_formats

    def _truncate_pdl_if_needed(self, fmts, printer_name):
        """Truncate PDL list if it exceeds 255 character limit."""
        fmts_str = ",".join(fmts)
        dropped = []

        while len(f"pdl={fmts_str}") >= 255:
            fmts_list = fmts_str.split(",")
            dropped.append(fmts_list.pop())
            fmts_str = ",".join(fmts_list)

        if dropped:
            logger.warning(
                f"Printer '{printer_name}': Dropped {len(dropped)} format(s) due to "
                f"255 char limit: {', '.join(reversed(dropped))}"
            )

        return fmts_str

    def _write_service_file(self, tree, fname):
        """Write the service file to disk."""
        try:
            with open(fname, "w") as f:
                if etree:
                    tree.write(
                        f, pretty_print=True, xml_declaration=True, encoding="UTF-8"
                    )
                else:
                    from xml.etree.ElementTree import tostring

                    xmlstr = tostring(tree.getroot())
                    doc = parseString(xmlstr)
                    dt = minidom.getDOMImplementation("").createDocumentType(
                        "service-group", None, "avahi-service.dtd"
                    )
                    doc.insertBefore(dt, doc.documentElement)
                    doc.writexml(f)
            logger.info(f"Created service file: {fname}")
        except IOError as e:
            logger.error(f"Failed to write service file '{fname}': {e}")
            raise

    def generate(self):
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
                if self.verbose:
                    logger.exception("Detailed error:")

    def _generate_printer_service(self, conn, printer_name, printer_info):
        """Generate service file for a single printer."""
        attrs = conn.getPrinterAttributes(printer_name)
        uri = urlparse(printer_info["printer-uri-supported"])

        logger.debug(f"Printer URI: {printer_info['printer-uri-supported']}")
        logger.debug(f"Printer info: {printer_info.get('printer-info', 'N/A')}")
        logger.debug(f"Printer location: {printer_info.get('printer-location', 'N/A')}")

        tree = ElementTree()
        tree.parse(
            StringIO(XML_TEMPLATE.replace("\n", "").replace("\r", "").replace("\t", ""))
        )

        # Set service name
        name = tree.find("name")
        if self.descName:
            name.text = f"{printer_info['printer-info']}"
        else:
            name.text = f"AirPrint {printer_name} @ %h"
        logger.debug(f"Service name: {name.text}")

        service = tree.find("service")

        # Set port
        port = service.find("port")
        port_no = self._get_port_number(uri)
        port.text = f"{port_no}"

        # Set resource path
        rp = self._extract_resource_path(uri)
        path = Element("txt-record")
        path.text = f"rp={rp}"
        service.append(path)

        # Set description
        desc = Element("txt-record")
        if self.descName:
            desc.text = f"note={printer_info['printer-location']}"
        else:
            desc.text = f"note={printer_info['printer-info']}"
        service.append(desc)

        # Add printer capabilities
        self._add_color_support(service, attrs)
        self._add_paper_size(service, attrs)

        has_urf = self._add_urf_support(service, attrs)
        has_duplex = self._add_duplex_support(service, attrs)

        # Add hardcoded URF if duplex but no URF
        if has_duplex and not has_urf:
            urf = Element("txt-record")
            urf.text = "URF=DM3"
            service.append(urf)
            logger.debug("Added hardcoded URF=DM3 for duplex support")

        # Add product info
        product = Element("txt-record")
        product.text = "product=(GPL Ghostscript)"
        service.append(product)

        # Add printer state
        state = Element("txt-record")
        state.text = f"printer-state={printer_info['printer-state']}"
        service.append(state)

        # Add printer type
        ptype = Element("txt-record")
        ptype.text = f"printer-type={hex(printer_info['printer-type'])}"
        service.append(ptype)

        # Build and add PDL list
        all_formats = self._build_pdl_list(attrs, printer_name)
        fmts_str = self._truncate_pdl_if_needed(all_formats, printer_name)

        pdl = Element("txt-record")
        pdl.text = f"pdl={fmts_str}"
        service.append(pdl)

        # Add admin URL if requested
        if self.adminurl:
            admin = Element("txt-record")
            admin.text = f"adminurl={printer_info['printer-uri-supported']}"
            service.append(admin)
            logger.debug(f"Added admin URL: {printer_info['printer-uri-supported']}")

        # Write service file
        fname = f"{self.prefix}{printer_name}.service"
        if self.directory:
            fname = os.path.join(self.directory, fname)

        self._write_service_file(tree, fname)


def main():
    parser = argparse.ArgumentParser(
        description="Generate Avahi service files for AirPrint from CUPS printers",
        formatter_class=argparse.RawDescriptionHelpFormatter,
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
        if not os.path.exists(args.directory):
            try:
                os.makedirs(args.directory)
                logger.info(f"Created directory: {args.directory}")
            except OSError as e:
                logger.error(f"Failed to create directory '{args.directory}': {e}")
                sys.exit(1)

    try:
        apg = AirPrintGenerate(
            user=args.username,
            host=args.hostname,
            port=args.port,
            verbose=args.verbose,
            directory=args.directory,
            prefix=args.prefix,
            adminurl=args.adminurl,
            descName=args.descName,
            insecure=args.insecure,
        )

        apg.generate()
        logger.info("Service generation completed successfully")
    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Failed to generate service files: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
