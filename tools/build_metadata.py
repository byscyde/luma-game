#!/usr/bin/env python3
"""Build metadata + version stamping for CI.

    python3 tools/build_metadata.py --platform android --build-number 42 [--apply]

Writes build/metadata.json (version, build number, commit, workflow run, time).
With --apply, stamps the build number into export_presets.cfg (Android
version/code, iOS application/version) in the CI workspace only.
"""
import argparse
import datetime
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def project_version():
    with open(os.path.join(ROOT, "project.godot")) as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
    return m.group(1) if m else "0.0.0"


def git_commit():
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    except Exception:  # noqa: BLE001
        return os.environ.get("GITHUB_SHA", "unknown")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--platform", required=True)
    ap.add_argument("--build-number", type=int, default=int(os.environ.get("GITHUB_RUN_NUMBER", "1")))
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--extra", action="append", default=[], help="key=value pairs to record")
    args = ap.parse_args()
    version = project_version()
    meta = {
        "app": "LUMA: Restore the Wild",
        "version": version,
        "build_number": args.build_number,
        "platform": args.platform,
        "commit": git_commit(),
        "ref": os.environ.get("GITHUB_REF", ""),
        "workflow_run": os.environ.get("GITHUB_RUN_ID", ""),
        "workflow_url": "%s/%s/actions/runs/%s" % (os.environ.get("GITHUB_SERVER_URL", ""),
                                                    os.environ.get("GITHUB_REPOSITORY", ""),
                                                    os.environ.get("GITHUB_RUN_ID", "")),
        "built_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    }
    for kv in args.extra:
        k, _, v = kv.partition("=")
        meta[k] = v
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    with open(os.path.join(ROOT, "build", "metadata.json"), "w") as f:
        json.dump(meta, f, indent=2)
    if args.apply:
        path = os.path.join(ROOT, "export_presets.cfg")
        with open(path) as f:
            cfg = f.read()
        cfg = re.sub(r'^version/code=\d+', "version/code=%d" % args.build_number, cfg, flags=re.M)
        cfg = re.sub(r'^version/name="[^"]*"', 'version/name="%s"' % version, cfg, flags=re.M)
        cfg = re.sub(r'^application/version="[^"]*"', 'application/version="%d"' % args.build_number, cfg, flags=re.M)
        cfg = re.sub(r'^application/short_version="[^"]*"', 'application/short_version="%s"' % version, cfg, flags=re.M)
        with open(path, "w") as f:
            f.write(cfg)
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
