#!/usr/bin/env python3
"""Write a valid Yandex Cloud SA key JSON for Terraform / yc CLI.

Handles common GitHub Actions corruption of YC_SERVICE_ACCOUNT_JSON:
  - literal newlines inside JSON strings (esp. private_key PEM)
  - broken timestamps like created_at = "2\\n026-07-21T..."
  - base64-encoded secrets (recommended)
"""

from __future__ import annotations

import base64
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


def maybe_decode_base64(raw: str) -> str:
    """If secret is base64 (recommended), decode it to JSON text."""
    stripped = raw.strip()
    if stripped.startswith("{"):
        return stripped

    try:
        decoded = base64.b64decode(stripped, validate=True).decode("utf-8")
    except Exception:
        return stripped

    if decoded.lstrip().startswith("{"):
        print("Decoded YC_SERVICE_ACCOUNT_JSON from base64")
        return decoded.strip()

    return stripped


def parse_sa_json(raw: str) -> dict:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        repaired = escape_newlines_inside_strings(raw)
        return json.loads(repaired)


def sanitize_key(data: dict) -> dict:
    """Fix fields that Terraform/protobuf reject when corrupted."""
    # created_at must be a single-line RFC3339 timestamp
    if isinstance(data.get("created_at"), str):
        cleaned = "".join(data["created_at"].split())
        if cleaned != data["created_at"]:
            print(f"Sanitized created_at: removed embedded whitespace/newlines")
        data["created_at"] = cleaned

    # private_key: normalize line endings inside PEM
    if isinstance(data.get("private_key"), str):
        pk = data["private_key"].replace("\r\n", "\n").replace("\r", "\n")
        data["private_key"] = pk

    if isinstance(data.get("public_key"), str):
        data["public_key"] = data["public_key"].replace("\r\n", "\n").replace("\r", "\n")

    return data


def main() -> int:
    raw = os.environ.get("YC_SA_JSON", "").strip()
    if not raw:
        print("ERROR: env YC_SA_JSON is empty", file=sys.stderr)
        return 1

    raw = maybe_decode_base64(raw)

    try:
        data = parse_sa_json(raw)
    except json.JSONDecodeError as err:
        print(f"ERROR: YC_SERVICE_ACCOUNT_JSON is not valid JSON: {err}", file=sys.stderr)
        print(
            "Store the key as base64 (recommended):\n"
            "  base64 -w0 key.json\n"
            "Paste the output into GitHub Secret YC_SERVICE_ACCOUNT_JSON",
            file=sys.stderr,
        )
        return 1

    if not isinstance(data, dict) or "private_key" not in data:
        print("ERROR: JSON does not look like a YC service account key", file=sys.stderr)
        return 1

    data = sanitize_key(data)

    out_path = os.environ.get("YC_SA_KEY_PATH", "/tmp/key.json")
    with open(out_path, "w", encoding="utf-8") as fh:
        # Compact single-line JSON — avoids any multiline parsing issues
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))

    os.chmod(out_path, 0o600)

    # Quick self-check: file must round-trip as JSON
    with open(out_path, encoding="utf-8") as fh:
        check = json.load(fh)
    if "\n" in str(check.get("created_at", "")):
        print("ERROR: created_at still contains newlines after sanitize", file=sys.stderr)
        return 1

    print(f"Wrote valid service account key to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
