#!/usr/bin/env python3
"""
helpers/asar_icon.py — Extracts icon.png from an Electron app.asar package.
Usage:
  python3 helpers/asar_icon.py <asar_file> <output_png_file>
Exits 0 on success, 1 on failure.
"""

import json
import os
import struct
import sys


def extract_asar_icon(asar_file: str, output_file: str) -> int:
    if not os.path.isfile(asar_file):
        return 1

    try:
        with open(asar_file, "rb") as f:
            v1, v2, v3, v4 = struct.unpack("<IIII", f.read(16))
            header = json.loads(f.read(v4).decode("utf-8"))
            info = header.get("files", {}).get("icon.png", {})
            if "offset" in info and "size" in info:
                f.seek(8 + v2 + int(info["offset"]))
                os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
                with open(output_file, "wb") as out:
                    out.write(f.read(info["size"]))
                return 0
    except Exception:
        return 1

    return 1


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <asar_file> <output_png_file>", file=sys.stderr)
        sys.exit(1)
    sys.exit(extract_asar_icon(sys.argv[1], sys.argv[2]))
