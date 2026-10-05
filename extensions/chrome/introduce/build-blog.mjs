import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const here = path.dirname(new URL(import.meta.url).pathname);
const blogDir = path.join(here, "blog");

const CSS = `
:root{--bg:#fff;--card:#fff;--surface:#f5f5f5;--ink:#141414;--muted:#787878;--dim:#a3a3a3;--line:#e5e5e5;--brand:#0a6cff;--brand-dark:#084fbf;--brand-tint:#f6f9ff;--brand-soft:#e6efff;--maxw:720px}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font-family:"Pretendard Variable","Pretendard",-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo",system-ui,"Noto Sans KR",sans-serif;line-height:1.8;font-size:17px;-webkit-font-smoothing:antialiased}
.wrap{max-width:var(--maxw);margin:0 auto;padding:0 22px}
a{color:var(--brand)}
.top{padding:18px 0;border-bottom:1px solid var(--line)}
.top a{font-size:14px;color:var(--muted);text-decoration:none}
article{padding:40px 0 8px}
h1{font-size:30px;line-height:1.32;letter-spacing:-.02em;margin:.2em 0 .3em}
.meta{color:var(--muted);font-size:14px;margin-bottom:8px}
.tag{display:inline-block;background:var(--brand-soft);color:var(--brand-dark);border-radius:999px;padding:2px 10px;font-size:12px;margin-right:6px;font-weight:600}
h2{font-size:21px;margin:1.6em 0 .4em;letter-spacing:-.01em}
p{margin:.7em 0}
blockquote{margin:1em 0;padding:12px 18px;background:var(--brand-tint);border-left:3px solid var(--brand);border-radius:8px;color:#374151;font-size:15px}
ul{padding-left:1.2em}li{margin:.3em 0}
hr{border:0;border-top:1px solid var(--line);margin:2em 0}
.refs a{word-break:break-all}
footer{padding:28px 0 70px;color:var(--dim);font-size:13px;border-top:1px solid var(--line);margin-top:24px}
/* index */
.hero{padding:56px 0 28px;text-align:center}
.hero h1{font-size:30px}.hero p{color:var(--muted);max-width:30em;margin:.4em auto}
.group{padding:26px 0;border-top:1px solid var(--line)}
.group h2{font-size:18px;margin:0 0 14px}
.cardlist{display:grid;gap:12px}
.post{display:flex;gap:14px;align-items:center;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px;text-decoration:none;color:inherit;transition:border-color .12s ease,background .12s ease}
.post:hover{border-color:var(--brand);background:var(--brand-tint)}
.post-thumb{flex:0 0 auto;width:104px;height:72px;object-fit:cover;border-radius:10px;border:1px solid var(--line);background:var(--surface)}
.post-body{flex:1 1 auto;min-width:0}
.post b{display:block;font-size:16px;margin-bottom:4px}
.post span{color:var(--muted);font-size:14px}
.thumb{display:block;width:100%;aspect-ratio:16/9;object-fit:cover;border-radius:14px;border:1px solid var(--line);background:var(--surface);margin:6px 0 20px}
.body-image{display:block;width:100%;aspect-ratio:4/3;object-fit:cover;border-radius:14px;border:1px solid var(--line);background:var(--surface);margin:14px 0 24px}
.site-header{position:sticky;top:0;z-index:20;background:rgba(255,255,255,.9);backdrop-filter:saturate(140%) blur(8px);border-bottom:1px solid var(--line)}
.site-header .bar{max-width:var(--maxw);margin:0 auto;padding:0 22px;display:flex;align-items:center;justify-content:space-between;height:64px}
.brand{font-weight:800;font-size:18px;letter-spacing:-.02em;color:var(--ink);text-decoration:none}
.nav{display:flex;gap:20px}.nav a{color:var(--muted);font-size:15px}.nav a:hover{color:var(--ink);text-decoration:none}
.site-footer{border-top:1px solid var(--line);padding:32px 0 64px;color:var(--dim);font-size:13px;text-align:center}
`;

function escapeHtml(s){return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}
function escapeAttr(s){return escapeHtml(s).replace(/"/g,"&quot;");}

function assetHead(depth, title, description){
  const up = depth === "blog" ? "../" : "";
  const lines = [
    "<!-- asset-meta:start -->",
    '<link rel="icon" type="image/png" sizes="16x16" href="' + up + 'assets/favicon-16.png" />',
    '<link rel="icon" type="image/png" sizes="32x32" href="' + up + 'assets/favicon-32.png" />',
    '<link rel="apple-touch-icon" href="' + up + 'assets/apple-touch-icon.png" />',
    '<link rel="manifest" href="' + up + 'assets/site.webmanifest" />',
    '<meta property="og:type" content="website" />',
    '<meta property="og:title" content="' + escapeHtml(title) + '" />'
  ];
  if (description) lines.push('<meta property="og:description" content="' + escapeHtml(description) + '" />');
  lines.push('<meta property="og:image" content="' + up + 'assets/og-image.png" />');
  lines.push('<meta name="twitter:card" content="summary_large_image" />');
  lines.push('<meta name="twitter:title" content="' + escapeHtml(title) + '" />');
  if (description) lines.push('<meta name="twitter:description" content="' + escapeHtml(description) + '" />');
  lines.push('<meta name="twitter:image" content="' + up + 'assets/og-image.png" />');
  lines.push("<!-- asset-meta:end -->");
  return lines.join("\n");
}

function inline(s){
  let out = escapeHtml(s);
  out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m,t,u)=>`<a href="${u.replace(/&amp;/g,"&")}">${t}</a>`);
  out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  out = out.replace(/\*([^*\n]+)\*/g, "<em>$1</em>");
  return out;
}

function parseFrontmatter(raw){
  const m = /^---\n([\s\S]*?)\n---\n?/.exec(raw);
  const meta = { title:"", date:"", tags:[], summary:"" };
  let body = raw;
  if (m){
    body = raw.slice(m[0].length);
    for (const line of m[1].split("\n")){
      const kv = /^(\w+):\s*(.*)$/.exec(line);
      if (!kv) continue;
      const [,k,v] = kv;
      if (k === "tags"){
        meta.tags = v.replace(/^\[|\]$/g,"").split(",").map(s=>s.trim()).filter(Boolean);
      } else if (k in meta){
        meta[k] = v.trim();
      }
    }
  }
  return { meta, body };
}

function mdToHtml(body){
  const lines = body.split("\n");
  const html = [];
  let para = [];
  let quote = [];
  let list = [];
  let skippedH1 = false;
  const flushPara = ()=>{ if(para.length){ html.push(`<p>${para.map(inline).join(" ")}</p>`); para=[]; } };
  const flushQuote = ()=>{ if(quote.length){ html.push(`<blockquote>${quote.map(inline).join("<br/>")}</blockquote>`); quote=[]; } };
  const flushList = ()=>{ if(list.length){ html.push(`<ul>${list.map(li=>`<li>${inline(li)}</li>`).join("")}</ul>`); list=[]; } };
  const flushAll = ()=>{ flushPara(); flushQuote(); flushList(); };
  for (const raw of lines){
    const line = raw.replace(/\s+$/,"");
    if (/^#\s+/.test(line)){ flushAll(); if(!skippedH1){ skippedH1=true; continue; } continue; }
    if (/^##\s+/.test(line)){ flushAll(); html.push(`<h2>${inline(line.replace(/^##\s+/,""))}</h2>`); continue; }
    const img = /^!\[([^\]]*)\]\(([^)]+)\)$/.exec(line.trim());
    if (img){ flushAll(); html.push(`<img class="body-image" src="${escapeAttr(img[2])}" alt="${escapeAttr(img[1])}" loading="lazy" />`); continue; }
    if (/^---\s*$/.test(line)){ flushAll(); html.push("<hr/>"); continue; }
    if (/^>\s?/.test(line)){ flushPara(); flushList(); quote.push(line.replace(/^>\s?/,"")); continue; }
    if (/^-\s+/.test(line)){ flushPara(); flushQuote(); list.push(line.replace(/^-\s+/,"")); continue; }
    if (line.trim() === ""){ flushAll(); continue; }
    flushQuote(); flushList(); para.push(line);
  }
  flushAll();
  return html.join("\n");
}

function pageHtml({ meta, contentHtml, image }){
  const tags = meta.tags.map(t=>`<span class="tag">${escapeHtml(t)}</span>`).join("");
  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
${assetHead("blog", `${meta.title} — 인포커터 블로그`, meta.summary)}
<title>${escapeHtml(meta.title)} — 인포커터 블로그</title>
<meta name="description" content="${escapeHtml(meta.summary)}" />
<style>${CSS}</style>
</head>
<body>
<header class="site-header"><div class="bar"><a class="brand" href="../index.html">인포커터</a><nav class="nav"><a href="../index.html">소개</a><a href="index.html">블로그</a><a href="../faq.html">FAQ</a><a href="../index.html#start">시작하기</a></nav></div></header>
<div class="wrap">
<p style="margin:22px 0 0"><a href="index.html" style="font-size:14px;color:var(--muted)">← 블로그 목록</a></p>
<article>
<h1>${escapeHtml(meta.title)}</h1>
<div class="meta">${escapeHtml(meta.date)} · ${tags}</div>
${image ? `<img class="thumb" src="${image}" alt="${escapeHtml(meta.title)}" />` : ""}
${contentHtml}
</article>
</div>
<footer class="site-footer">인포커터 · 보고 싶지 않은 이름을 가려 주는 크롬 확장 · 본 글은 일반 정보이며 의료·법률 자문이 아닙니다. · 힘들 땐 자살예방상담 <strong>109</strong>(24시간)</footer>
</body>
</html>
`;
}

function indexHtml(groups){
  const section = (title, posts)=>`
<div class="group">
<h2>${title}</h2>
<div class="cardlist">
${posts.map(p=>`<a class="post" href="${p.file}">${p.image?`<img class="post-thumb" src="${p.image}" alt="" loading="lazy" />`:""}<div class="post-body"><b>${escapeHtml(p.meta.title)}</b><span>${escapeHtml(p.meta.summary)}</span></div></a>`).join("\n")}
</div>
</div>`;
  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
${assetHead("blog", "인포커터 블로그", "악플이 왜 아픈지, 어떻게 마음을 추스르는지에 대한 글 모음.")}
<title>인포커터 블로그</title>
<meta name="description" content="악플이 왜 아픈지, 어떻게 마음을 추스르는지에 대한 글 모음." />
<style>${CSS}</style>
</head>
<body>
<header class="site-header"><div class="bar"><a class="brand" href="../index.html">인포커터</a><nav class="nav"><a href="../index.html">소개</a><a href="index.html">블로그</a><a href="../faq.html">FAQ</a><a href="../index.html#start">시작하기</a></nav></div></header>
<div class="wrap">
<div class="hero">
<h1>인포커터 블로그</h1>
<p>악플이 왜 이렇게까지 아픈지, 그리고 어떻게 마음을 추스르는지. 모든 글은 실제 연구·자료를 바탕으로 합니다.</p>
<p style="font-size:14px">힘들 때는 혼자 두지 마세요 — 자살예방상담 <b>109</b> (24시간)</p>
</div>
${section("마음과 회복", groups.care)}
${section("증거와 법", groups.law)}
</div>
<footer class="site-footer">인포커터 · 본 글은 일반 정보이며 의료·법률 자문이 아닙니다. · 힘들 땐 자살예방상담 <strong>109</strong>(24시간)</footer>
</body>
</html>
`;
}

async function main(){
  const files = (await readdir(blogDir)).filter(f=>/^\d{2}-.*\.md$/.test(f)).sort();
  let imageSet = new Set();
  try { imageSet = new Set(await readdir(path.join(blogDir, "images"))); } catch {}
  const posts = [];
  let withThumb = 0;
  for (const f of files){
    const raw = await readFile(path.join(blogDir, f), "utf8");
    const { meta, body } = parseFrontmatter(raw);
    const contentHtml = mdToHtml(body);
    const htmlFile = f.replace(/\.md$/, ".html");
    const imgName = f.replace(/\.md$/, ".png");
    const image = imageSet.has(imgName) ? `images/${imgName}` : null;
    if (image) withThumb++;
    await writeFile(path.join(blogDir, htmlFile), pageHtml({ meta, contentHtml, image }), "utf8");
    posts.push({ file: htmlFile, meta, image });
  }
  const isLaw = (p)=>p.meta.tags.some(t=>["법률","증거"].includes(t));
  const groups = {
    care: posts.filter(p=>!isLaw(p)),
    law: posts.filter(isLaw)
  };
  await writeFile(path.join(blogDir, "index.html"), indexHtml(groups), "utf8");
  console.log(`generated ${posts.length} post pages + index.html (${withThumb} with thumbnails)`);
}

main().catch((e)=>{ console.error(e); process.exitCode = 1; });
