#!/usr/bin/env python3
"""Fails if generated files, build outputs or credentials are tracked in git,
or if tracked text files contain obvious secret material.

    python3 tools/check_repo_hygiene.py
"""
import re
import subprocess
import sys

FORBIDDEN_PATHS = [
    (re.compile(r"(^|/)\.godot/"), "engine cache"),
    (re.compile(r"^android/"), "generated Android build template"),
    (re.compile(r"^build/(?!\.gitkeep$)"), "build output"),
    (re.compile(r"\.(apk|aab|ipa|xcarchive|pck|zip|tpz)$"), "binary build artifact"),
    (re.compile(r"\.(keystore|jks|p12|p8|mobileprovision|cer|pem|key)$"), "signing credential"),
    (re.compile(r"(^|/)export_credentials\.cfg$"), "export credentials"),
    (re.compile(r"(^|/)\.env$"), "environment file"),
    (re.compile(r"\.translation$"), "generated translation"),
]
SECRET_PATTERNS = [
    (re.compile(r"-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"), "private key"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS access key"),
    (re.compile(r"ghp_[A-Za-z0-9]{36}"), "GitHub token"),
    (re.compile(r"AIza[0-9A-Za-z\-_]{35}"), "Google API key"),
    (re.compile(r"xox[baprs]-[0-9A-Za-z-]{10,}"), "Slack token"),
]
TEXT_EXT = (".gd", ".py", ".json", ".cfg", ".godot", ".tscn", ".tres", ".md", ".yml", ".yaml", ".sh", ".csv", ".txt")


def main():
    files = subprocess.run(["git", "ls-files"], capture_output=True, text=True, check=True).stdout.split("\n")
    errors = []
    for f in filter(None, files):
        for rx, why in FORBIDDEN_PATHS:
            if rx.search(f):
                errors.append("%s is tracked but is a %s" % (f, why))
        if f.endswith(TEXT_EXT) and f != "tools/check_repo_hygiene.py":
            try:
                with open(f, encoding="utf-8", errors="replace") as fh:
                    text = fh.read()
            except FileNotFoundError:
                continue
            for rx, why in SECRET_PATTERNS:
                if rx.search(text):
                    errors.append("%s appears to contain a %s (value not printed)" % (f, why))
    for e in errors:
        print("ERROR", e)
    print("%d tracked files checked, %d problems" % (len([f for f in files if f]), len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
