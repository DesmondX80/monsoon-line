#!/usr/bin/env python3
"""Vie docs/backlog/*.json -tehtävät Planeen work itemeiksi.

Käyttö:
    export PLANE_API_KEY=plane_api_...        # Plane: Profile Settings > Personal Access Tokens
    export PLANE_WORKSPACE=oma-workspace      # workspace-slug URL:sta
    export PLANE_PROJECT_ID=<projektin UUID>  # projektin asetuksista tai URL:sta
    python3 scripts/plane_import.py docs/backlog/milestone-1-prototype.json
    python3 scripts/plane_import.py docs/backlog/milestone-1-prototype.json --dry-run

Itsehostattu Plane: export PLANE_BASE_URL=https://plane.oma-domain.fi
"""
from __future__ import annotations

import argparse
import html
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE_URL = os.environ.get("PLANE_BASE_URL", "https://api.plane.so").rstrip("/")


def task_html(task: dict, milestone: str) -> str:
    parts = [f"<p><strong>{html.escape(milestone)}</strong> · rooli: <code>{html.escape(task['role'])}</code></p>"]
    parts.append(f"<p>{html.escape(task['description'])}</p>")
    if task.get("acceptance"):
        parts.append("<p><strong>Hyväksymiskriteerit</strong></p><ul>")
        parts += [f"<li>{html.escape(a)}</li>" for a in task["acceptance"]]
        parts.append("</ul>")
    if task.get("depends_on"):
        parts.append(f"<p>Riippuu: {html.escape(', '.join(task['depends_on']))}</p>")
    return "".join(parts)


def create_work_item(api_key: str, workspace: str, project_id: str, body: dict) -> dict:
    url = f"{BASE_URL}/api/v1/workspaces/{workspace}/projects/{project_id}/work-items/"
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={"X-API-Key": api_key, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("backlog", help="polku backlog-JSONiin")
    parser.add_argument("--dry-run", action="store_true", help="tulosta vain, älä luo")
    args = parser.parse_args()

    with open(args.backlog, encoding="utf-8") as f:
        backlog = json.load(f)

    milestone = backlog["milestone"]
    tasks = backlog["tasks"]

    if args.dry_run:
        for t in tasks:
            print(f"[{t['key']}] [{t['role']}] {t['name']} ({t['priority']})")
        print(f"\n{len(tasks)} tehtävää. Ei luotu mitään (--dry-run).")
        return 0

    missing = [v for v in ("PLANE_API_KEY", "PLANE_WORKSPACE", "PLANE_PROJECT_ID") if not os.environ.get(v)]
    if missing:
        print(f"Puuttuu ympäristömuuttuja: {', '.join(missing)}", file=sys.stderr)
        return 1

    api_key = os.environ["PLANE_API_KEY"]
    workspace = os.environ["PLANE_WORKSPACE"]
    project_id = os.environ["PLANE_PROJECT_ID"]

    created = 0
    for t in tasks:
        body = {
            "name": f"[{t['key']}] [{t['role']}] {t['name']}",
            "description_html": task_html(t, milestone),
            "priority": t.get("priority", "none"),
        }
        try:
            item = create_work_item(api_key, workspace, project_id, body)
            created += 1
            print(f"OK  {t['key']} → {item.get('id', '?')}")
        except urllib.error.HTTPError as e:
            print(f"VIRHE {t['key']}: HTTP {e.code} {e.read().decode('utf-8', 'replace')[:300]}", file=sys.stderr)
            if e.code in (401, 403, 404):
                print("Tarkista API-avain, workspace-slug ja projektin UUID.", file=sys.stderr)
                return 1
        time.sleep(0.5)  # kevyt rajoitus, ettei osuta rate limitiin

    print(f"\nLuotu {created}/{len(tasks)} tehtävää Planeen ({milestone}).")
    return 0 if created == len(tasks) else 1


if __name__ == "__main__":
    sys.exit(main())
