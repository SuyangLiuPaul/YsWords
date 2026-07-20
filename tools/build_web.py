#!/usr/bin/env python3
"""Wrap `flutter build web --release` so that `kAppVersion` and
`kAppReleaseTime` are auto-stamped from canonical sources.

Why this exists: prior to v1.2.34, both constants in
`lib/constants/app_version.dart` were edited by hand on every
release. Forgetting to bump them — or bumping pubspec.yaml's
`version:` separately — left the About page out of sync with
the actual build. This script makes pubspec's `version:` the
single source of truth + auto-stamps build time.

Behaviour:
  1. Read `version: X.Y.Z` from `pubspec.yaml`.
  2. Capture local wall-clock time as `YYYY-MM-DD HH:MM TZ`.
  3. Run two builds in sequence:
       • `flutter build web --release ...`               → build/web   (intl)
       • `flutter build web --release CHINA_MODE=true …` → build-cn   (cn)
     Both pass `--dart-define=APP_VERSION=…` and
     `--dart-define=APP_RELEASE_TIME=…`. The cn build also passes
     `--dart-define=CHINA_MODE=true`.
  4. After the cn build the script moves `build/web` → `build-cn`,
     then re-runs the intl build into `build/web`. This matches
     the directory layout `tools/deploy_site.py` expects (intl in
     `build/web`, cn in `build-cn`).

Usage:
    python3 tools/build_web.py             # both flavours
    python3 tools/build_web.py --intl-only # just the international build
    python3 tools/build_web.py --cn-only   # just the China build
    python3 tools/build_web.py --wasm      # skwasm renderer instead of canvaskit

Then run:
    python3 tools/deploy_site.py --tier dev    # / qat / prod

2026-07-21: `--wasm` builds with Flutter's skwasm (WebAssembly)
renderer instead of the default canvaskit. Re-added after v1.3.132
reverted it — that revert was for a "Failed to load" boot bug that
turned out to be UNRELATED to the renderer (see LoadingPage /
MainProvider.bootInFlight, fixed independently in v1.3.133), so it's
safe to re-try. Still runs single-threaded on every deployed site
(window.crossOriginIsolated is false — netlify.toml's COOP header is
same-origin-allow-popups for Firebase signInWithPopup, and there's no
COEP header), so don't expect a dramatic win; full multi-threaded
skwasm needs Google Sign-In moved off the popup flow first.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLUTTER = os.path.expanduser('~/flutter/bin/flutter')


def read_pubspec_version() -> str:
    """Parse `version: X.Y.Z` from pubspec.yaml — the single
    source of truth. Returns just the semver portion (everything
    before the first `+` build-suffix, if present)."""
    path = os.path.join(REPO_ROOT, 'pubspec.yaml')
    with open(path) as f:
        for line in f:
            m = re.match(r'^version:\s*([0-9A-Za-z.+_-]+)', line)
            if m:
                # Strip Flutter's optional `+buildNumber` suffix —
                # the user-visible string is just X.Y.Z.
                return m.group(1).split('+', 1)[0]
    raise RuntimeError(f"No `version:` field in {path}")


def current_release_time() -> str:
    """ISO 8601 UTC stamp, second-precision — e.g.
    `2026-05-10T09:48:00Z`. The Flutter app's
    `formatReleaseTimeLocal()` parses this and renders in the
    viewer's local timezone. Pre-v1.2.35 this returned a
    Melbourne wall-clock string; the new format ensures users
    everywhere see the time in their own zone."""
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


def run_build(version: str, release_time: str, *, china_mode: bool, wasm: bool):
    cmd = [
        FLUTTER, 'build', 'web', '--release',
        f'--dart-define=APP_VERSION={version}',
        f'--dart-define=APP_RELEASE_TIME={release_time}',
    ]
    if china_mode:
        cmd.append('--dart-define=CHINA_MODE=true')
    if wasm:
        cmd.append('--wasm')
    label = 'cn' if china_mode else 'intl'
    renderer = 'skwasm' if wasm else 'canvaskit'
    print(f'==> Building {label} ({renderer}): APP_VERSION={version}, '
          f'APP_RELEASE_TIME={release_time}')
    res = subprocess.run(cmd, cwd=REPO_ROOT)
    if res.returncode != 0:
        print(f'  ✗ flutter build web failed (exit {res.returncode})',
              file=sys.stderr)
        sys.exit(res.returncode)
    print(f'  ✓ {label} built into build/web')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--intl-only', action='store_true',
                    help='Build only the international flavour')
    ap.add_argument('--cn-only', action='store_true',
                    help='Build only the China flavour')
    ap.add_argument('--wasm', action='store_true',
                    help='Use the skwasm renderer instead of canvaskit')
    args = ap.parse_args()

    version = read_pubspec_version()
    release_time = current_release_time()

    if args.intl_only:
        run_build(version, release_time, china_mode=False, wasm=args.wasm)
        print(f'\nDone. Next: python3 tools/deploy_site.py --tier <dev|qat|prod>')
        return 0

    if args.cn_only:
        # Build cn into build/web, then move to build-cn so deploy_site.py
        # finds it at the expected path.
        run_build(version, release_time, china_mode=True, wasm=args.wasm)
        cn_path = os.path.join(REPO_ROOT, 'build-cn')
        web_path = os.path.join(REPO_ROOT, 'build', 'web')
        if os.path.isdir(cn_path):
            shutil.rmtree(cn_path)
        shutil.move(web_path, cn_path)
        print(f'\nMoved build/web → build-cn')
        return 0

    # Default: both flavours. Build intl first, stash, then cn.
    run_build(version, release_time, china_mode=False, wasm=args.wasm)
    web_path = os.path.join(REPO_ROOT, 'build', 'web')
    intl_path = os.path.join(REPO_ROOT, 'build', 'web-intl-stash')
    if os.path.isdir(intl_path):
        shutil.rmtree(intl_path)
    shutil.move(web_path, intl_path)

    run_build(version, release_time, china_mode=True, wasm=args.wasm)
    cn_path = os.path.join(REPO_ROOT, 'build-cn')
    if os.path.isdir(cn_path):
        shutil.rmtree(cn_path)
    shutil.move(web_path, cn_path)

    # Restore intl into build/web so deploy_site.py finds both at
    # the expected locations.
    shutil.move(intl_path, web_path)

    print()
    print(f'Done. Both flavours built with v{version} @ {release_time}.')
    print(f'  intl: build/web')
    print(f'  cn:   build-cn')
    print(f'\nNext: python3 tools/deploy_site.py --tier <dev|qat|prod>')
    return 0


if __name__ == '__main__':
    sys.exit(main())
