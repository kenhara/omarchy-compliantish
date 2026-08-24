#!/usr/bin/env python3
"""Bounded cache read for Compliantish (HC-05).

Rejects symlink / FIFO / non-regular / missing / oversize. Valid regular
file → raw bytes on stdout, exit 0. Failure → exit 1, no body.

Opens O_RDONLY|O_NOFOLLOW|O_NONBLOCK so a planted symlink or FIFO at the
predictable cache path cannot redirect the read or hang the helper.
"""
from __future__ import annotations

import argparse
import os
import stat
import sys


def main() -> None:
    p = argparse.ArgumentParser(description="Bounded trust-path cache read")
    p.add_argument("--file", required=True, help="cache file path")
    p.add_argument("--cap", type=int, default=262144, help="max bytes")
    args = p.parse_args()
    path = str(args.file or "")
    cap = int(args.cap)
    if not path or cap < 0:
        sys.exit(1)

    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    fd = -1
    data = b""
    try:
        fd = os.open(path, flags)
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            sys.exit(1)
        remaining = cap + 1
        while remaining > 0:
            chunk = os.read(fd, min(65536, remaining))
            if not chunk:
                break
            data += chunk
            remaining -= len(chunk)
    except Exception:
        sys.exit(1)
    finally:
        if fd >= 0:
            try:
                os.close(fd)
            except Exception:
                pass

    if len(data) > cap:
        sys.exit(1)
    try:
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
    except Exception:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
