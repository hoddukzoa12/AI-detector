# Independent OCR and menu fixtures

These synthetic assets and labels are authored for the approved OCR/CLEF contract. No production detector, OCR model, CLEF output, private environment file, cookie, or live-site HTML generated the text or labels. They supplement `site.ts`/`truth.ts` without changing them. Human labels are test oracles, not a claim about real model accuracy or legal adjudication.

## Consumer entry points

- `startOcrFixtureSite()` from `ocr-site.ts`: two ephemeral local HTTP servers, `urls.images`, `urls.menu`, `urls.exceptions`, `origin`, `externalOrigin`, observable `requests`, and idempotent `stop()`.
- `assetTruth` from `ocr-truth.ts`: 15 original/reference assets with exact checked-in byte SHA-256, MIME, byte length, 640×160 dimensions, human text/label/readability. `recipes.json` is the manually authored source. The unreadable recipe records intended source wording, while its extraction oracle is empty: no guessed missing text.
- `imageTruth`: 39 distinct occurrences, with literal frame chains, owner selector, source kind/index, related nearest anchor, direct DOM text, and concealment. Resolve each frame selector in its parent document, then the owner selector; joined location is `framePath + selector` separated by ` >>> `. All occurrences belong to top-page `/images`; actual child frame URLs remain separate evidence.
- `imageExceptionTruth`: malformed PNG-signature bytes with a fixed SHA/length (200/decode failure), missing asset (404), unavailable asset (503), under isolated `/exceptions`. All fail Chromium image decoding and have no inferred text/ad label.
- `menuTruth`: 22 title negatives and five direct-text positives. The negative titles have no nearest anchor even though siblings include solicitation links. Their `OFFSCREEN` observation is a hidden ancestor, not a hardcoded title exception.

Image cases include Korean/English solicitation, library logo, book cover, ordinary bakery advertisement, reporting, public counseling notice, no-text illustration, deliberately unreadable low-contrast blurred text, picture/currentSrc selection, URL layers around a gradient, before/after images, data/blob, static SVG, GIF, actual JPEG/WebP/AVIF, opacity/display/offscreen concealment, identical PNG at separate positions, four asset kinds at one img owner, direct DOM text plus background image, nearest-anchor ownership, external assets, same-src sibling frames, nested external frames, srcdoc and no-src frames. External links are inert; no destination needs visiting. Main hostname is `127.0.0.1`; external hostname is `localhost`.

The two-frame GIF's first authored frame is the Korean solicitation; its second is the library logo. Each lasts 3 seconds. `animation-first.png` is an independent first-frame reference decoded using Pillow. Chromium's native `ImageDecoder.decode({frameIndex:0})` pixels are compared with this checked-in reference. This is decoder/frame verification, not whole-animation OCR.

## Menu observation provenance

`docs/tracking/findings.md` records the 2026-10-04 local toonkor observation: 22 false positives (11 MEMBER, 11 MENU), hidden closed sidebar, and unrelated parent sidebar links/text incorrectly inherited by the titles. Root's source assessment is `apps/inspector/release/site-tests/2026-10-04T15-49-35.039Z-toonkor1-local/assessment.json`/`assessment.md` (historical, ignored artifacts). The confirmed structural facts are `h5.sidebar-title` titles below an `aside` with `display:none`, beside separate 토토/회원가입/문의 anchors.

`/menu` recreates only these facts in 11 explicitly synthetic aside instances; it is not a copy of 11 captured pages or real URLs. The 22 title labels are human negatives. Nearby opacity-zero solicitation and transparent/zero-font direct parent and child solicitation are human positives. An aggregate parent with no direct text has no truth record. No private tokens, full saved HTML, cookies, or source-site query strings are included. Mock classification of this fixture does not establish actual CLEF accuracy on the captured 22 titles.

## Generation and notices

Run from `apps/inspector`:

```sh
node test/fixtures/generate-ocr-assets.mjs
npx vitest run test/fixtures/ocr-site.test.ts
```

Generation is offline and uses the already-installed Playwright Chromium, ImageMagick `convert`, and Python Pillow. PNG originals are fresh Chromium screenshots of literal recipes, with device scale 1, viewport 640×160, Noto Sans CJK KR Regular 30px (unreadable: 4px/3px blur), fixed colors, 1.6 line height. SVG is hand-authored, has no script/external reference, and is used as an image. The 16-byte malformed PNG is literal synthetic bytes with a valid signature and invalid body. JPEG/WebP/GIF conversions use ImageMagick. AVIF and the GIF first-frame reference use system Pillow; the generator must not silently label PNG bytes as AVIF. Chromium fixture tests check MIME signatures, response bytes, hashes, dimensions, selected currentSrc, CSS URL order, frame paths, styles, exact direct text, related anchors and GIF frame-zero pixels.

Generation environment: ImageMagick 7.1.1-43; Pillow 12.3.0; Chromium revision 1243; `/home/agent/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome`; font `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`. Font SHA-256: `b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a`. Installed font source: [Noto CJK](https://github.com/notofonts/noto-cjk), Debian `fonts-noto-cjk`; copyright 2010–2012 Google Corporation; SIL Open Font License 1.1. `ocr-assets/FONT-NOTICE.txt` retains the installed package's font copyright/license section. Font binaries are not redistributed in this fixture. The OFL says its font-license requirement does not apply to documents created with fonts.

All banner wording, shapes, colors, logo/cover stand-ins and SVG are newly authored synthetic test material. No real business logo, book cover or advertisement is copied. These source/notice facts do not resolve the repository's existing whole-project redistribution rights. Re-generation may change byte hashes with browser, font or encoder versions; review asset changes and manifest together. Normal tests consume committed bytes and do not re-generate expected hashes.
