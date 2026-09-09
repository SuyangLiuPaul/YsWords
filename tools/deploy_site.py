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
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

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

# The CLI lives in another project's node_modules, so a cleanup over
# there disarms deploys here — it did, 2026-09-09. Both release shell
# scripts read $NETLIFY first, and the recovery text they print says "or
# point NETLIFY= at another copy"; this script ignored that variable, so
# following its own repo's documented recovery fixed the shell path and
# left this one still pointing at the missing binary.
NETLIFY_CLI = os.environ.get("NETLIFY") or os.path.expanduser(
    "~/Documents/CodingProject/SmartHome/node_modules/.bin/netlify"
)

NETLIFY_RECOVERY = (
    "    restore it with:\n"
    "      (cd ~/Documents/CodingProject/SmartHome && "
    "npm install netlify-cli --no-save --legacy-peer-deps)\n"
    "    or point NETLIFY= at another copy."
)

# Seconds between verification attempts. A knob only so
# tools/test_release_scripts.py can exercise the failure path without
# waiting on it.
VERIFY_SLEEP = float(os.environ.get("RELEASE_VERIFY_SLEEP", "5"))

OVERLAY_FILES = [
    "favicon.png",
    "manifest.json",
    "icons/Icon-192.png",
    "icons/Icon-512.png",
    "icons/Icon-maskable-192.png",
    "icons/Icon-maskable-512.png",
]

# How much of the app bundle verify_site() fingerprints, byte-for-byte
# the same 256 KB tools/release_web.sh settled on (its MAIN_SLICE,
# measured 2026-08-30): the intl and cn bundles already differ inside a
# slice this size, and it keeps the check cheap enough to run on six
# sites on every retry instead of pulling ~10 MB each time.
MAIN_SLICE = 262144

# The compiled file that carries the flavour, in preference order. It is
# main.dart.js for every build this script normally sees, but
# `tools/build_web.py --wasm` prints THIS script as its next step, and a
# dart2wasm build's payload is main.dart.wasm. Either is the same
# evidence — dart-defines compile into both — and looking for both is
# what keeps a wasm deploy from being refused at the verification step,
# after it has already uploaded.
BUNDLE_CANDIDATES = ("main.dart.js", "main.dart.wasm")


def netlify_cli_problem() -> str | None:
    """Why the netlify CLI cannot be run, or None if it can.

    Checked ONCE up front rather than at the deploy: the staging copy
    below duplicates the whole ~10 MB build tree per site, so with --all
    the old code copied six of them before six identical FileNotFoundError
    lines — none of which said how to get the CLI back.
    """
    if not os.path.isfile(NETLIFY_CLI):
        return f"netlify CLI not found at {NETLIFY_CLI}"
    if not os.access(NETLIFY_CLI, os.X_OK):
        return f"netlify CLI at {NETLIFY_CLI} is not executable"
    return None


def _fetch(url: str, timeout: int = 30,
           headers: dict[str, str] | None = None) -> bytes:
    """Read a URL. Split out so the tests can answer for the network."""
    sent = {"Cache-Control": "no-cache"}
    sent.update(headers or {})
    req = urllib.request.Request(url, headers=sent)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.read()


def _digest(path: str, limit: int | None = None) -> str | None:
    """sha256 of a staged file, or of its first `limit` bytes."""
    if not os.path.isfile(path):
        return None
    with open(path, "rb") as handle:
        return hashlib.sha256(
            handle.read() if limit is None else handle.read(limit)).hexdigest()


def verify_site(site: str, staged: str) -> bool:
    """Ask the SITE whether the deploy landed.

    2026-09-09: `netlify deploy` exiting 0 was the only thing this script
    ever checked before printing "✓ deployed". That is not enough, and
    the repo has the receipts: tools/release_web.sh documents v1.4.61 and
    v1.4.65, where the CLI exited 0, the script announced the release,
    and `netlify api listSiteDeploys` showed `state: error, "Deploy
    canceled"` — a state Netlify sets after the CLI is gone, which no
    exit code can carry. release_web.sh answers it by re-fetching from
    each site; this script deploys to the same six sites and had no such
    check.

    The site names in SITES are the Netlify subdomains, which is what
    release_web.sh's verify_site() fetches too.

    WHICH bundle landed matters as much as which version, and
    flutter_bootstrap.js cannot answer that here — this repo measured
    that and retired it. web/flutter_bootstrap.js is a committed custom
    bootstrap holding two tokens, {{flutter_js}} and
    {{flutter_build_config}}; the build config carries the engine
    revision and renderer, and NOT dart-defines. tools/build_web.py
    builds the two flavours with identical flags apart from
    `--dart-define=CHINA_MODE=true`, so the two bootstraps come out
    byte-identical — see release_web.sh's verify_site(), which names this
    exact blind spot ("Pass that flag to both builds, or neither, and
    this check keeps passing while no longer being able to tell the
    bundles apart") and moved the job to a 256 KB main.dart.js slice on
    2026-08-30. A check that says it distinguishes flavours while it
    cannot is worse than no check, so the four things compared are:

      • version.json    — the site moved at all
      • the app bundle  — WHICH flavour landed. dart-defines DO reach
                          main.dart.js (or main.dart.wasm), which is what
                          makes it the one file that can tell intl from
                          cn.
      • manifest.json   — WHICH tier's overlay landed. Per-tier PWA icons
                          are this script's entire reason to exist, and
                          nothing verified them: a deploy that shipped
                          the base build with no overlay, or another
                          tier's, printed "✓ deployed" like any other.
      • flutter_bootstrap.js — kept because it costs 11 KB and still
                          catches engine-revision and build-config
                          drift. It just is not the flavour guard.
    """
    url = f"https://{site}.netlify.app"

    want_version = None
    version_path = os.path.join(staged, "version.json")
    if os.path.isfile(version_path):
        try:
            with open(version_path, encoding="utf-8") as handle:
                want_version = json.load(handle).get("version")
        except (OSError, ValueError):
            want_version = None
    want_manifest = _digest(os.path.join(staged, "manifest.json"))
    want_boot = _digest(os.path.join(staged, "flutter_bootstrap.js"))
    bundle = want_bundle = None
    for candidate in BUNDLE_CANDIDATES:
        want_bundle = _digest(os.path.join(staged, candidate), MAIN_SLICE)
        if want_bundle is not None:
            bundle = candidate
            break

    if want_bundle is None:
        # release_web.sh refuses to deploy a tree with no main.dart.js at
        # all ("refusing to deploy a shell"); by the time we are here the
        # upload has happened, so the most this can do is decline to
        # bless it.
        print("  ✗ cannot verify: the staged build has neither "
              "main.dart.js nor main.dart.wasm — that is a shell, and "
              "which flavour it carries is unknowable", file=sys.stderr)
        return False

    def served_digest(path: str, limit: int | None = None) -> str:
        headers = None
        timeout = 30
        if limit is not None:
            # Ask for the slice, not the ~10 MB file. `Accept-Encoding:
            # identity` is required, not decoration: without it the range
            # would apply to a compressed stream and not to the bytes on
            # disk, and the hashes could never match.
            headers = {"Range": f"bytes=0-{limit - 1}",
                       "Accept-Encoding": "identity"}
            timeout = 60
        try:
            body = _fetch(f"{url}/{path}", timeout=timeout, headers=headers)
        except Exception as exc:                # noqa: BLE001 — any read failure
            return f"<{type(exc).__name__}>"
        # A server that ignores Range answers 200 with the whole file;
        # hash the same prefix either way.
        return hashlib.sha256(
            body if limit is None else body[:limit]).hexdigest()

    problems: list[str] = []
    for attempt in range(3):
        problems = []
        if want_version is not None:
            try:
                served = json.loads(
                    _fetch(f"{url}/version.json").decode("utf-8")).get("version")
            except Exception as exc:            # noqa: BLE001 — any read failure
                served = f"<{type(exc).__name__}>"
            if served != want_version:
                problems.append(
                    f"version.json says {served!r}, expected {want_version!r}")
        got_bundle = served_digest(bundle, MAIN_SLICE)
        if got_bundle != want_bundle:
            problems.append(
                f"{bundle} differs from the bundle just staged (first "
                f"{MAIN_SLICE // 1024} KB: {got_bundle[:12]} vs "
                f"{want_bundle[:12]}) — this site may be serving the other "
                "flavour's build, i.e. CHINA_MODE went to the wrong site")
        if want_manifest is not None:
            got_manifest = served_digest("manifest.json")
            if got_manifest != want_manifest:
                problems.append(
                    "manifest.json differs from the one just staged "
                    f"({got_manifest[:12]} vs {want_manifest[:12]}) — this "
                    "site may be serving another tier's PWA icons, or the "
                    "base build with no overlay at all")
        if want_boot is not None:
            got_boot = served_digest("flutter_bootstrap.js")
            if got_boot != want_boot:
                problems.append(
                    "flutter_bootstrap.js differs from the bundle just "
                    f"staged ({got_boot[:12]} vs {want_boot[:12]}) — engine "
                    "revision or build-config drift")
        if not problems:
            print(f"  ✓ {site} re-fetched: serving this deploy")
            return True
        if attempt < 2:
            time.sleep(VERIFY_SLEEP)

    print(f"  ✗ {url} is not serving this deploy:", file=sys.stderr)
    for problem in problems:
        print(f"      {problem}", file=sys.stderr)
    return False


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
        except OSError as exc:
            # FileNotFoundError alone left the "exists but chmod -x" case
            # to raise out of here and abort the remaining sites of a
            # --all run with a traceback.
            print(f"  ✗ could not run the netlify CLI: {exc}",
                  file=sys.stderr)
            print(NETLIFY_RECOVERY, file=sys.stderr)
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
        # Exit 0 is where this used to stop and print the ✓. See
        # verify_site() for why that is not the same as a deploy.
        if not verify_site(site, staging):
            return 1
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

    if not args.dry_run:
        problem = netlify_cli_problem()
        if problem:
            print(f"✗ {problem}", file=sys.stderr)
            print(NETLIFY_RECOVERY, file=sys.stderr)
            return 2

    print(f"Targets: {', '.join(targets)}")
    print()

    failed = []
    for site in targets:
        rc = deploy_one(site, dry_run=args.dry_run)
        if rc != 0:
            failed.append(site)
        print()

    # The exit code was always right; the LAST LINE was not. On a --all
    # run the tail of the log is whichever site went last, so a failure
    # three sites up scrolled away under a "✓ deployed" and the operator
    # read the run as done. Name them at the end, where the eye lands.
    if failed:
        print(f"✗ {len(failed)} of {len(targets)} site(s) did not deploy:",
              file=sys.stderr)
        for site in failed:
            print(f"    {site}  https://{site}.netlify.app", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
