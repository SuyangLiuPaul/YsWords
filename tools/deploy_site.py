#!/usr/bin/env python3
"""Deploy a YsWords build to one of the 6 Netlify sites with the
right per-site icons + manifest overlaid.

Why this exists: there are 2 Flutter builds (intl + cn) but 6
deployments (prod / dev / qat × intl / cn). Each tier should have a
visually distinct PWA icon so the user can tell saved-to-home-screen
installs apart. This script takes the base build and overlays the
matching variant from `tools/site-icons/<flavour>-<tier>/`.

Usage:
    python3 tools/deploy_site.py <site-name>
    python3 tools/deploy_site.py --all
    python3 tools/deploy_site.py --tier dev      # both intl + cn dev sites
    python3 tools/deploy_site.py --flavour cn    # all 3 cn-flavour sites

Pre-requisites:
    1. `flutter build web --release`
       and
       `flutter build web --release --dart-define=CHINA_MODE=true --output=build-cn`
       have already produced build/web/ and build-cn/.
    2. `python3 tools/generate_site_icons.py` has produced
       tools/site-icons/<flavour>-<tier>/ directories.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# site-name → (site_id, flavour, tier)
SITES: dict[str, tuple[str, str, str]] = {
    "yswords":         ("975d1a08-8203-4994-a7ef-ca60452e41bf", "intl", "prod"),
    "yswords-cn":      ("3094b5e5-bf62-48e4-9b3b-4ff8adc84f3c", "cn",   "prod"),
    "yswords-dev":     ("b745ae1f-0780-4fa3-8478-bdf2f2aaf59a", "intl", "dev"),
    "yswords-cn-dev":  ("50f1502c-299f-4ff8-a21b-28f53eaee1e1", "cn",   "dev"),
    "yswords-qat":     ("2bcb6644-2a3a-4050-b6dc-5b059bbe96d3", "intl", "qat"),
    "yswords-cn-qat":  ("266f97ef-f28b-4313-b83b-653c098df640", "cn",   "qat"),
}

NETLIFY_CLI = os.path.expanduser(
    "~/Documents/CodingProject/SmartHome/node_modules/.bin/netlify"
)

OVERLAY_FILES = [
    "favicon.png",
    "manifest.json",
    "icons/Icon-192.png",
    "icons/Icon-512.png",
    "icons/Icon-maskable-192.png",
    "icons/Icon-maskable-512.png",
]


def deploy_one(site: str, dry_run: bool = False) -> int:
    site_id, flavour, tier = SITES[site]
    base = os.path.join(REPO_ROOT,
                        "build/web" if flavour == "intl" else "build-cn")
    icons = os.path.join(REPO_ROOT, "tools", "site-icons", f"{flavour}-{tier}")

    if not os.path.isdir(base):
        print(f"  ✗ base build dir missing: {base}", file=sys.stderr)
        print("    run `flutter build web --release` first", file=sys.stderr)
        return 1
    if not os.path.isdir(icons):
        print(f"  ✗ icon variant dir missing: {icons}", file=sys.stderr)
        print("    run `python3 tools/generate_site_icons.py` first",
              file=sys.stderr)
        return 1

    print(f"==> {site}  (flavour={flavour}, tier={tier})")

    with tempfile.TemporaryDirectory(prefix=f"yswords-{site}-") as staging:
        # 1. mirror base build to staging
        for entry in os.listdir(base):
            src = os.path.join(base, entry)
            dst = os.path.join(staging, entry)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)
        # 2. overlay tier+flavour-specific icons + manifest
        for filename in OVERLAY_FILES:
            src = os.path.join(icons, filename)
            dst = os.path.join(staging, filename)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

        if dry_run:
            print(f"  (dry-run) staged {site} at {staging}")
            return 0

        # 3. deploy
        cmd = [
            NETLIFY_CLI, "deploy", "--prod",
            "--dir", staging,
            "--site", site_id,
        ]
        try:
            res = subprocess.run(cmd, check=False, capture_output=True,
                                 text=True)
        except FileNotFoundError:
            print(f"  ✗ netlify CLI not found at {NETLIFY_CLI}",
                  file=sys.stderr)
            return 2

        # Print just the live URL line(s) so the log stays compact
        for line in res.stdout.splitlines():
            if "live" in line.lower() or "Production URL" in line:
                print(f"    {line.strip()}")
        if res.returncode != 0:
            print(f"  ✗ deploy failed (exit {res.returncode})",
                  file=sys.stderr)
            print(res.stderr, file=sys.stderr)
            return res.returncode
        print(f"  ✓ deployed {site}")
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("site", nargs="?",
                        help="Site name (one of: " + ", ".join(SITES) + ")")
    parser.add_argument("--all", action="store_true",
                        help="Deploy to all 6 sites")
    parser.add_argument("--tier", choices=("prod", "dev", "qat"),
                        help="Deploy both intl + cn for this tier")
    parser.add_argument("--flavour", choices=("intl", "cn"),
                        help="Deploy all 3 tiers of this flavour")
    parser.add_argument("--dry-run", action="store_true",
                        help="Stage only, don't deploy")
    args = parser.parse_args()

    selectors = [args.site, args.all, args.tier, args.flavour]
    if sum(1 for s in selectors if s) != 1:
        parser.error("Pick exactly one of: <site>, --all, --tier, --flavour")

    if args.site:
        if args.site not in SITES:
            parser.error(f"Unknown site: {args.site}")
        targets = [args.site]
    elif args.all:
        targets = list(SITES.keys())
    elif args.tier:
        targets = [n for n, (_, _, t) in SITES.items() if t == args.tier]
    else:
        targets = [n for n, (_, f, _) in SITES.items() if f == args.flavour]

    print(f"Targets: {', '.join(targets)}")
    print()

    failures = 0
    for site in targets:
        rc = deploy_one(site, dry_run=args.dry_run)
        if rc != 0:
            failures += 1
        print()

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
