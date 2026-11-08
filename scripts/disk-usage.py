#!/usr/bin/env python3
# collects local mount + rclone remote usage once a day, writing json for the
# dashboard's sys tab. mounts/remotes that fail (eg. ssd/hdd not plugged in)
# keep their last known numbers instead of disappearing.
import json, os, shutil, subprocess, time

OUT = "/home/richard/dashboard/data/disks.json"
RCLONE_PASSWORD_FILE = "/run/agenix/rclone-password"

LOCAL_MOUNTS = {
    "nvme (/)": "/",
    "ssd": "/mnt/ssd",
    "hdd": "/mnt/hdd",
    "iphone": "/mnt/iphone",
}
RCLONE_REMOTES = {"gdrive": "gdrive:", "pdrive": "pdrive:"}


def load_existing():
    try:
        with open(OUT, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def local_usage(path):
    if path != "/" and not os.path.ismount(path):
        return None
    try:
        u = shutil.disk_usage(path)
        return {"total": u.total, "used": u.used, "free": u.free}
    except OSError:
        return None


def rclone_usage(remote):
    try:
        res = subprocess.run(["rclone", "about", remote, "--json"],
                              capture_output=True, text=True, timeout=60)
        return json.loads(res.stdout) if res.returncode == 0 else None
    except Exception:
        return None


def main():
    if os.path.exists(RCLONE_PASSWORD_FILE):
        with open(RCLONE_PASSWORD_FILE) as f:
            os.environ["RCLONE_CONFIG_PASS"] = f.read().strip()

    data = load_existing()
    local = data.setdefault("local", {})
    remote = data.setdefault("remote", {})
    now = time.strftime("%Y-%m-%d %H:%M")

    for name, path in LOCAL_MOUNTS.items():
        usage = local_usage(path)
        if usage is not None:
            local[name] = {**usage, "mounted": True, "checked_at": now}
        else:
            local.setdefault(name, {}).update(mounted=False, checked_at=now)

    for name, slug in RCLONE_REMOTES.items():
        usage = rclone_usage(slug)
        if usage is not None:
            remote[name] = {**usage, "checked_at": now}

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    main()
