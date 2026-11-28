#!/usr/bin/env python3
# sorts files by extension into subfolders. run every 5 minutes via systemd timer.
import shutil
from pathlib import Path

HOME = Path.home()
DOWNLOADS = HOME / "Downloads"


def unique_dest(dest_dir, name):
    # avoid clobbering an existing file with the same name in the dest dir
    dest = dest_dir / name
    if not dest.exists():
        return dest
    stem, suffix = Path(name).stem, Path(name).suffix
    i = 1
    while True:
        candidate = dest_dir / f"{stem} ({i}){suffix}"
        if not candidate.exists():
            return candidate
        i += 1


def move_into(path, dest_dir):
    dest_dir.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), str(unique_dest(dest_dir, path.name)))


def sort_by_extension(src_dir):
    if not src_dir.is_dir():
        return
    for item in src_dir.iterdir():
        if not item.is_file():
            continue
        ext = item.suffix.lstrip(".").lower()
        move_into(item, DOWNLOADS / (ext if ext else "noext"))


def dump_all_files(src_dir, dest_name):
    if not src_dir.is_dir():
        return
    dest_dir = DOWNLOADS / dest_name
    for item in src_dir.iterdir():
        if item.is_file():
            move_into(item, dest_dir)


def main():
    sort_by_extension(DOWNLOADS)
    dump_all_files(HOME / "Desktop", "desktop")
    dump_all_files(HOME / "Documents", "documents")


if __name__ == "__main__":
    main()
