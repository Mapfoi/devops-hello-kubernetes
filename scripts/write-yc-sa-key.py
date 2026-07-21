#!/usr/bin/env python3
"""Write a valid Yandex Cloud SA key JSON for Terraform / yc CLI.

Fixes the common GitHub Actions issue where YC_SERVICE_ACCOUNT_JSON
contains literal newlines inside the private_key string, which breaks
JSON parsing (Terraform: key unmarshal fail: invalid character '\\n').
"""

from __future__ import annotations

import json
import os
import sys


def escape_newlines_inside_strings(raw: str) -> str:
    """Convert raw newlines/CRs that appear inside JSON strings into \\n."""
    out: list[str] = []
    in_string = False
    escape = False

    for ch in raw:
        if escape:
            out.append(ch)
            escape = False
            continue

        if ch == "\\" and in_string:
            out.append(ch)
            escape = True
            continue

        if ch == '"':
            in_string = not in_string
            out.append(ch)
            continue

        if in_string and ch == "\n":
            out.append("\\n")
            continue

        if in_string and ch == "\r":
            continue

        out.append(ch)

    return "".join(out)


def main() -> int:
    raw = os.environ.get("YC_SA_JSON", "").strip()
    if not raw:
        print("ERROR: env YC_SA_JSON is empty", file=sys.stderr)
        return 1

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        try:
            data = json.loads(escape_newlines_inside_strings(raw))
            print("Repaired literal newlines inside JSON string values")
        except json.JSONDecodeError as err:
            print(f"ERROR: YC_SERVICE_ACCOUNT_JSON is not valid JSON: {err}", file=sys.stderr)
            print(
                "Re-create the secret from the raw key file without reformatting:\n"
                "  cat key.json | jq -c .   # copy ONE line into the GitHub secret",
                file=sys.stderr,
            )
            return 1

    out_path = os.environ.get("YC_SA_KEY_PATH", "/tmp/key.json")
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))

    os.chmod(out_path, 0o600)
    print(f"Wrote valid service account key to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
