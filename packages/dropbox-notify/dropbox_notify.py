#!/usr/bin/env python3
"""
dropbox-notify: Watch a directory with inotify and post to a Mastodon-compatible
ActivityPub instance when new user files appear.
"""

import argparse
import collections
import logging
import os
import sys
import time

import inotify_simple
import requests

log = logging.getLogger("dropbox-notify")

# ---------------------------------------------------------------------------
# Patterns that are NOT real user files.  Netatalk creates these alongside
# every uploaded file so we must silently ignore them.
# ---------------------------------------------------------------------------
IGNORED_PREFIXES = (
    ".",  # .AppleDouble, .DS_Store, ._filename resource forks, etc.
)

IGNORED_SUFFIXES = (
    ".tmp",
    ".part",
    ".crdownload",
)

# inotify event flags we care about – the file must be fully written
# (IN_CLOSE_WRITE) or moved into the watched directory (IN_MOVED_TO).
WATCH_FLAGS = inotify_simple.flags.CLOSE_WRITE | inotify_simple.flags.MOVED_TO


def is_user_file(filename: str) -> bool:
    """Return True only for files that look like real user uploads."""
    if not filename:
        return False
    if filename.startswith(IGNORED_PREFIXES):
        return False
    if filename.endswith(IGNORED_SUFFIXES):
        return False
    return True


def read_token(token_path: str) -> str:
    """Read the Mastodon API access token from a file, stripping whitespace."""
    with open(token_path) as fh:
        token = fh.read().strip()
    if not token:
        raise ValueError(f"Token file {token_path!r} is empty")
    return token


def post_status(
    instance_url: str, token: str, filename: str, dry_run: bool = False
) -> None:
    """Publish a public status to the Mastodon-compatible instance."""
    status_text = f"New file uploaded to Doofnet: {filename} #Globaltalk"
    log.info("Posting status: %s", status_text)

    if dry_run:
        log.info("[dry-run] Would POST to %s/api/v1/statuses", instance_url)
        return

    url = f"{instance_url.rstrip('/')}/api/v1/statuses"
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "status": status_text,
        "visibility": "public",
    }

    try:
        resp = requests.post(url, headers=headers, data=payload, timeout=30)
        resp.raise_for_status()
        log.info("Status posted successfully (id=%s)", resp.json().get("id"))
    except requests.RequestException as exc:
        log.error("Failed to post status: %s", exc)


def watch(
    watch_dir: str,
    instance_url: str,
    token_path: str,
    dry_run: bool = False,
    post_interval: int = 60,
) -> None:
    """Main watch loop – blocks forever."""
    log.info("Watching %s for new files (post interval: %ds)", watch_dir, post_interval)

    # Pre-populate with files that already exist so we don't re-announce them
    # on startup or after a service restart.
    seen_files: set[str] = {f for f in os.listdir(watch_dir) if is_user_file(f)}
    log.debug("Pre-seeded %d existing files", len(seen_files))

    queue: collections.deque[str] = collections.deque()
    last_post_time = 0.0

    inotify = inotify_simple.INotify()
    inotify.add_watch(watch_dir, WATCH_FLAGS)

    while True:
        # Use a 1-second timeout so we can drain the queue on schedule even
        # when no new inotify events arrive.
        events = inotify.read(timeout=1000)
        for event in events:
            filename = event.name

            if not is_user_file(filename):
                log.debug("Ignoring non-user file: %s", filename)
                continue

            if filename in seen_files:
                log.debug("Ignoring already-seen file: %s", filename)
                continue

            seen_files.add(filename)
            log.info("Queuing new file: %s", os.path.join(watch_dir, filename))
            queue.append(filename)

        # Post at most one queued item per interval.
        now = time.monotonic()
        if queue and now - last_post_time >= post_interval:
            filename = queue.popleft()
            if queue:
                log.info("Posting %s (%d more queued)", filename, len(queue))
            try:
                token = read_token(token_path)
            except (OSError, ValueError) as exc:
                log.error("Could not read token: %s", exc)
            else:
                post_status(instance_url, token, filename, dry_run=dry_run)
            last_post_time = now


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Watch a directory and toot on every new user file."
    )
    parser.add_argument(
        "--watch-dir",
        required=True,
        help="Directory to watch for new files.",
    )
    parser.add_argument(
        "--instance-url",
        required=True,
        help="Base URL of the Mastodon-compatible instance (e.g. https://social.example.com).",
    )
    parser.add_argument(
        "--token-file",
        required=True,
        help="Path to a file containing the Mastodon API access token.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Log what would be posted without actually calling the API.",
    )
    parser.add_argument(
        "--post-interval",
        type=int,
        default=60,
        metavar="SECONDS",
        help="Minimum seconds between posts (default: 60).",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity (default: INFO).",
    )

    args = parser.parse_args()

    logging.basicConfig(
        stream=sys.stdout,
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )

    if not os.path.isdir(args.watch_dir):
        log.error("Watch directory does not exist: %s", args.watch_dir)
        sys.exit(1)

    # Retry the watch loop on unexpected errors so the service stays up.
    while True:
        try:
            watch(
                watch_dir=args.watch_dir,
                instance_url=args.instance_url,
                token_path=args.token_file,
                dry_run=args.dry_run,
                post_interval=args.post_interval,
            )
        except KeyboardInterrupt:
            log.info("Interrupted, exiting.")
            sys.exit(0)
        except Exception as exc:  # noqa: BLE001
            log.exception("Unexpected error in watch loop: %s – restarting in 5 s", exc)
            time.sleep(5)


if __name__ == "__main__":
    main()
