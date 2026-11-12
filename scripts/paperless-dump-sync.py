#!/usr/bin/env python3
# daily: rclone copy anything new from gdrive:paperless (general document dump,
# not receipt-specific) down into a local inbox, then drop every new file
# straight into paperless's consume root so it gets ingested. no subdir tag is
# applied here -- categorization happens entirely via the filename-matching
# workflows pushed by paperless/sync.py (see paperless/rules.yaml).
#
# idempotent: a state file tracks the sha256 of every file already fed to
# paperless (not the filename -- paperless deletes consumed files from its
# consume dir on ingest, so "already in the consume dir" can't be used to
# dedupe, and dedupe-by-name would either re-feed a renamed-but-unchanged
# file or silently skip a genuinely new file that happens to reuse an old name).
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

DUMP_DIR = Path("/home/richard/life/paperless_dump")
INBOX_DIR = DUMP_DIR / "inbox"
STATE_FILE = DUMP_DIR / ".sync_state.json"
PAPERLESS_CONSUME_DIR = Path("/home/richard/life/paperless")
RCLONE_REMOTE = "gdrive:paperless"
RCLONE_PASSWORD_FILE = "/run/agenix/rclone-password"


def sha256_file(path, chunk_size=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {}
    # migrate old filename-based state into hash-based state by hashing
    # whatever's still sitting in the local inbox under that name
    if "fed_to_paperless" in state and "fed" not in state:
        fed = {}
        for name in state["fed_to_paperless"]:
            p = INBOX_DIR / name
            if p.is_file():
                fed[sha256_file(p)] = name
        state = {"fed": fed}
    state.setdefault("fed", {})
    return state


def save_state(state):
    tmp = STATE_FILE.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    tmp.replace(STATE_FILE)


def rclone_pull():
    print(f"==> rclone copy {RCLONE_REMOTE} -> {INBOX_DIR}")
    res = subprocess.run(
        ["rclone", "copy", RCLONE_REMOTE, str(INBOX_DIR)],
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        print(f"==> rclone copy failed: {res.stderr.strip()}", file=sys.stderr)
        return False
    return True


def main():
    if os.path.exists(RCLONE_PASSWORD_FILE):
        with open(RCLONE_PASSWORD_FILE) as f:
            os.environ["RCLONE_CONFIG_PASS"] = f.read().strip()

    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    PAPERLESS_CONSUME_DIR.mkdir(parents=True, exist_ok=True)

    if not rclone_pull():
        return 1

    state = load_state()
    fed = state["fed"]  # sha256 -> filename last fed under

    new_count = 0
    for path in sorted(p for p in INBOX_DIR.iterdir() if p.is_file()):
        file_hash = sha256_file(path)
        if file_hash in fed:
            continue

        dest = PAPERLESS_CONSUME_DIR / path.name
        try:
            shutil.copy2(path, dest)
        except OSError as exc:
            print(
                f"failed to copy {path.name} into paperless consume dir: {exc}",
                file=sys.stderr,
            )
            continue  # retry next run, don't mark as fed

        fed[file_hash] = path.name
        new_count += 1
        print(f"fed {path.name} to paperless")

    state["fed"] = fed
    save_state(state)
    print(f"done: {new_count} new document(s) fed to paperless")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
