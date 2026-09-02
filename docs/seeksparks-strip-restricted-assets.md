# Take NASB and LEB off sword.yahwehword.com

**This is now a written commitment, not a tidy-up.** The NASB permission
request was sent to The Lockman Foundation on 2026-09-02 and its
disclosure paragraph says, of the bulk text file:

> "The same file is still reachable on `sword.yahwehword.com` as I write
> this, because that application is built and deployed separately; **I am
> removing it there as well and it will be gone within days of this
> letter.**"

So this has a deadline, and the deadline was given to the party deciding
the request.

## What is wrong

Measured 2026-09-02:

```
sword.yahwehword.com/assets/assets/nasb.json   200   7,588,512 bytes
sword.yahwehword.com/assets/assets/leb.json    200   8,748,709 bytes
sword.yahwehword.com/assets/assets/kjv.json    200   7,511,109 bytes   ← fine, public domain
```

Confirmed to be the real text, not an error page — the first bytes are
`[{"book":"Genesis","chapter":"1","verse":"1","text":"In the beginning
God created the heavens and the earth.",…`.

`sword.yahwehword.com` serves the **SeekSparks** build
(`/version.json` → `{"app_name":"seeksparks","version":"1.6.204"}`),
which lives in `~/Documents/CodingProject/SeekSparks` and deploys
separately. `tools/release_web.sh` in the *yswords* repo strips these
two files, and that strip has never covered SeekSparks. yswords
production is clean (`yahwehword.com` and `yswords.netlify.app` both
answer 404).

## The fix — two halves, and one alone is not enough

yswords learned this the hard way on 2026-09-02: deleting the file left
the SPA catch-all answering those URLs with `200` + `index.html`. A
`200` under a path naming an unlicensed translation is close to the
signal we are trying not to send.

### Half 1 — delete the files after the build

In the SeekSparks release script, after `flutter build web` and before
any deploy:

```bash
WEB_RESTRICTED_ASSETS=(nasb leb)
strip_restricted_assets() {
  echo "==> stripping unlicensed translations from build/web"
  for v in "${WEB_RESTRICTED_ASSETS[@]}"; do
    f="$PROJECT/build/web/assets/assets/$v.json"
    if [[ -f "$f" ]]; then
      echo "    removed assets/$v.json ($(wc -c <"$f" | tr -d ' ') bytes)"
      rm -f "$f"
    fi
    # Belt and braces: refuse to deploy if it is somehow still there.
    if [[ -f "$f" ]]; then
      echo "✗ could not remove $f — refusing to deploy" >&2
      exit 1
    fi
  done
}
```

Call it after **every** `flutter build web` in that script — yswords has
two (international and China builds) and needed it after both.

`AssetManifest.bin` still names the two files. That is deliberate and
harmless: rewriting the binary manifest is fragile, and a request for a
stripped asset returns 404 through `rootBundle`, which the loaders
already treat as an empty result.

### Half 2 — make the URLs answer a real 404

In SeekSparks's `netlify.toml`, **above** the SPA catch-all
(`from = "/*"`), because Netlify takes the first matching rule:

```toml
[[redirects]]
  from = "/assets/assets/nasb.json"
  to = "/404.html"
  status = 404

[[redirects]]
  from = "/assets/assets/leb.json"
  to = "/404.html"
  status = 404
```

Point `to` at whatever 404 page that site actually has.

## Also worth doing while in there

The app's LEB attribution is wrong, and this is separate from the
takedown — see `docs/leb-licence-request.md`. The LEB licence requires,
for 100+ verses, this text verbatim:

> Scripture quotations marked (LEB) are from the Lexham English Bible.
> Copyright 2012 Logos Bible Software. Lexham is a registered trademark
> of Logos Bible Software.

with "Lexham English Bible" linked to `lexhamenglishbible.com` and
"Logos Bible Software" linked to `logos.com`. Both apps currently show
`© Logos Bible Software · non-commercial study only`, which is neither
the required statement nor a restriction the licence imposes in those
words.

Note the LEB's terms **do** permit giving the whole text away — "you can
give away the Lexham English Bible, but you can't sell it on its own" —
so the LEB half of this exposure is much less serious than the NASB
half. Strip it anyway: it is simpler to treat both the same, and the
attribution requirement is failed either way.

## Verify when done

All six must be 404:

```bash
for h in yahwehword.com yswords.netlify.app sword.yahwehword.com; do
  for a in nasb leb; do
    printf '%-26s %-5s %s\n' "$h" "$a" \
      "$(curl -s -o /dev/null -w '%{http_code}' https://$h/assets/assets/$a.json)"
  done
done
```

And `kjv.json` must still be `200` everywhere — if it 404s too, the
strip is matching more than it should.
