#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.requests python3Packages.pyyaml
"""
sync rules.yaml -> paperless-ngx: creates/updates one tag + one filename-matching
workflow per entry. re-run anytime after editing rules.yaml, it's idempotent.

auth: export PAPERLESS_USER / PAPERLESS_PASSWORD (or PAPERLESS_TOKEN directly).

usage:
  ./sync.py                 push tags + workflows
  ./sync.py --apply-existing also retag all documents already in paperless
"""
import os, sys, fnmatch, yaml, requests

RULES = os.path.join(os.path.dirname(__file__), "rules.yaml")


def get_token(base):
    token = os.environ.get("PAPERLESS_TOKEN")
    if token:
        return token
    user = os.environ["PAPERLESS_USER"]
    pw = os.environ["PAPERLESS_PASSWORD"]
    r = requests.post(f"{base}/api/token/", data={"username": user, "password": pw})
    r.raise_for_status()
    return r.json()["token"]


def get_or_create(base, headers, endpoint, name, extra=None):
    r = requests.get(f"{base}/api/{endpoint}/", headers=headers,
                      params={"name__iexact": name, "page_size": 1})
    r.raise_for_status()
    results = r.json()["results"]
    if results:
        return results[0]["id"]
    payload = {"name": name, **(extra or {})}
    r = requests.post(f"{base}/api/{endpoint}/", headers=headers, json=payload)
    r.raise_for_status()
    return r.json()["id"]


def upsert_workflow(base, headers, name, payload):
    r = requests.get(f"{base}/api/workflows/", headers=headers, params={"page_size": 200})
    r.raise_for_status()
    existing = next((w for w in r.json()["results"] if w["name"] == name), None)
    if existing:
        r = requests.patch(f"{base}/api/workflows/{existing['id']}/", headers=headers, json=payload)
    else:
        r = requests.post(f"{base}/api/workflows/", headers=headers, json=payload)
    r.raise_for_status()
    return r.json()


def main():
    apply_existing = "--apply-existing" in sys.argv
    cfg = yaml.safe_load(open(RULES))
    base = cfg["paperless_url"]
    headers = {"Authorization": f"Token {get_token(base)}"}

    tag_ids = {}
    tag_globs = {}
    for order, (tag_name, spec) in enumerate(cfg["tags"].items()):
        globs = spec["globs"]
        tag_id = get_or_create(base, headers, "tags", tag_name)
        tag_ids[tag_name] = tag_id
        tag_globs[tag_name] = globs

        workflow_name = f"auto-tag: {tag_name}"
        wf_payload = {
            "name": workflow_name,
            "order": order,
            "enabled": True,
            "triggers": [
                {"type": 1, "sources": [1, 2, 4], "filter_filename": g}
                for g in globs
            ],
            "actions": [{"type": 1, "assign_tags": [tag_id]}],
        }
        upsert_workflow(base, headers, workflow_name, wf_payload)
        print(f"tag {tag_name!r} (id={tag_id}) <- {len(globs)} filename rule(s)")

    if not apply_existing:
        return

    print("\nretagging existing documents...")
    r = requests.get(f"{base}/api/documents/", headers=headers, params={"page_size": 200})
    r.raise_for_status()
    docs = r.json()["results"]
    for doc in docs:
        fname = doc.get("original_file_name") or doc["title"]
        matched = [tag_ids[t] for t, globs in tag_globs.items()
                   if any(fnmatch.fnmatch(fname.lower(), g.lower()) for g in globs)]
        if not matched:
            continue
        current = set(doc["tags"])
        new = current | set(matched)
        if new != current:
            requests.patch(f"{base}/api/documents/{doc['id']}/", headers=headers,
                            json={"tags": list(new)}).raise_for_status()
            print(f"  {doc['title']!r}: +{[t for t,i in tag_ids.items() if i in matched]}")


if __name__ == "__main__":
    main()
