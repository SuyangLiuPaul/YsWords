# Requests for the church web teams

Three things only the sites' own admins can do. Nothing here is urgent
for the app to work — it works today — but the first one would remove a
running cost, and the other two are broken links the churches probably
do not know about.

Written to be forwarded as-is. Each section has an English and a
Chinese version.

---

## 1. One HTTP header would let us stop proxying your audio

**Who:** whoever administers `fydt.org`,
`www.christiandiscipleschurch.org`, and `cgdc.hk`.

### Why we are asking

The YsWords app plays your songs directly from your servers. On phones
and desktop apps that works perfectly and costs you nothing unusual —
it is the same as someone opening the mp3 in a browser.

**On the web version it does not**, because browsers apply CORS: a page
on `yswords.netlify.app` may only read audio from another domain if
that domain says it is allowed. None of the three sites currently sends
that permission, so every web play would fail.

Our workaround is to pass the audio through our own server first. That
works, but it means the audio travels twice and we pay for bandwidth we
would not otherwise need. **One response header on your side removes
the workaround completely.**

### What to change

Send this header on files under your uploads/media directories:

```
Access-Control-Allow-Origin: *
```

`*` is appropriate here: these files are already public — anyone can
open them by URL today. The header does not grant any new access, it
only stops browsers from blocking a page that reads them. It cannot
expose private pages, member data, or anything behind a login.

**Apache / cPanel** — in `.htaccess` at the site root:

```apache
<FilesMatch "\.(mp3|m4a|ogg|pdf)$">
  Header set Access-Control-Allow-Origin "*"
</FilesMatch>
```

**Nginx** — inside the server block:

```nginx
location ~* \.(mp3|m4a|ogg|pdf)$ {
  add_header Access-Control-Allow-Origin "*" always;
}
```

**WordPress without server access** (fydt.org, cgdc.hk) — a small
plugin such as "Add Expires Headers" or "CORS Enabler" can set it, or
the host's support can add the rule above.

### How to check it worked

```bash
curl -I -H "Origin: https://example.com" https://YOURSITE/path/to/a-song.mp3
```

The response should include `access-control-allow-origin: *`.

### 中文

YsWords app 直接从贵站播放诗歌。手机和桌面版完全正常，对贵站来说
和有人用浏览器打开这个 mp3 没有区别。

**但网页版不行**，因为浏览器有 CORS 限制：`yswords.netlify.app` 上的
页面要读取另一个域名的音频，必须那个域名明确允许。三个站目前都没有
发送这个许可，所以网页版每次播放都会失败。

我们目前的做法是把音频先经过自己的服务器转一手。可以用，但音频要走
两趟，也让我们付了本来不需要的流量费。**贵站加一行响应头就可以完全
去掉这个中转。**

需要加的是（针对上传/媒体目录下的文件）：

```
Access-Control-Allow-Origin: *
```

这里用 `*` 是合适的：这些文件本来就是公开的，任何人现在就能用网址打
开。这行头不会开放任何新的权限，只是让浏览器不要拦截读取它们的页面，
不会影响任何需要登录的内容或会员资料。

具体配置见上面的 Apache / Nginx / WordPress 三种写法。

---

## 2. The 2021 and 2022 songbook QR codes are dead — cgdc.hk

The printed 2021 and 2022 MK Easter Camp songbooks carry QR codes
pointing to:

* `https://cgdc.hk/2021mk`
* `https://cgdc.hk/2022mk`

**Both return 404.** The pages are not on the site in any form — not as
drafts, not private; checked against the site's full page list. The
2023–2026 equivalents all work.

Anyone scanning an older printed songbook gets an error page. If those
years' songs still exist somewhere, republishing them at the same two
addresses would fix every printed copy at once — and the app would pick
them up automatically, because it discovers songbook years by pattern
rather than from a fixed list.

### 中文

2021 和 2022 年的 MK 复活节营诗歌本上印的 QR code 指向
`cgdc.hk/2021mk` 和 `cgdc.hk/2022mk`，**两个都是 404**。整个网站的页
面列表里都没有这两页（草稿、私密的也没有）。2023–2026 都是正常的。

拿着旧诗歌本扫码的人会看到错误页。如果那两年的诗歌还在，重新发布到
同样的两个网址就能一次性修好所有印刷本 —— app 那边不用改，它是按年份
规律自动发现的，新页面上线就会自己收录。

---

## 3. fuyindiantai.org no longer resolves

`fuyindiantai.org` is fydt.org's former domain, and it used to redirect
to the new one. **Its DNS is now broken**: both Google and Cloudflare
return SERVFAIL, because its nameserver records still point at
`ns1.fydt.org` / `ns2.fydt.org`, which stopped serving that zone when
fydt.org moved to a different DNS provider.

The effect: anyone holding an old `fuyindiantai.org` link — printed
material, bookmarks, links in other people's articles — currently gets
nothing at all, not even a redirect. Repointing the domain's
nameservers to the current provider and restoring the redirect to
fydt.org would recover all of it.

No action is needed for the app; its songs are already in the catalogue
under fydt.

### 中文

`fuyindiantai.org` 是 fydt.org 的旧域名，以前会跳转到新域名。**它的
DNS 现在是坏的** —— Google 和 Cloudflare 都返回 SERVFAIL，因为它的 NS
记录还指向 `ns1/ns2.fydt.org`，而 fydt.org 换了 DNS 服务商之后那边就
不再解析这个域了。

结果是：任何拿着旧 `fuyindiantai.org` 链接的人（印刷品、书签、别人文
章里的链接）现在什么都打不开，连跳转都没有。把域名的 NS 改到现在的服
务商、恢复到 fydt.org 的跳转就能全部恢复。

app 这边不需要处理，那些诗歌已经在 fydt 名下收录了。
