# 인포커터 — introduce

악플로 지친 사람을 위한 소개 페이지와 블로그입니다. **"그 댓글, 더는 당신이 보지 않아도 됩니다."**

> 당신의 평화가 먼저예요. 보고 싶지 않은 이름이 든 글은 조용히 가려 둘게요.

## 무엇이 들어 있나

- **[랜딩 페이지](index.html)** — 제품 소개(왜 아픈지 → 마음 지키기 → 작동 방식 → 도움 창구). dalsoop 디자인.
- **[블로그](blog/)** — 악플 심리·회복·법에 대한 글 22편. `.md` 소스 + 생성된 `.html`.
- **베이스 템플릿** `template-YYMMDDHHMMSS.html` — 새 페이지의 출발점(dalsoop 토큰·헤더·푸터·컴포넌트).

## 폴더 구조

```
introduce/
├── index.html                  # 랜딩(제품 소개)
├── template-YYMMDDHHMMSS.html   # 재사용 베이스 템플릿(항상 1개)
├── README.md                   # 이 문서
├── AUTHORING.md                # 콘텐츠 유지·확장 가이드
├── SKILL.md                    # 보이스 가이드(문서형)
├── build-blog.mjs              # 블로그 .md → .html 생성기
└── blog/
    ├── index.html              # 블로그 인덱스(생성물)
    ├── NN-*.md / NN-*.html      # 글 22편(소스 + 생성물)
    ├── README.md               # 블로그 인덱스(마크다운)
    └── SKILL.md                # 블로그 작성 규칙(문서형)
```

## 어떻게 작업하나

- **HTML 페이지(랜딩 등)**: 최신 `template-*.html`을 복사해 본문만 채운다. 규약은 스킬 `infocutter-introduce-page`.
- **디자인(색·타이포)**: 스킬 `dalsoop-design-pattern` (파랑 #0a6cff·그레이·Pretendard, 아이보리 금지).
- **랜딩 카피**: 스킬 `infocutter-voice` (위로→안심→설득).
- **블로그 글**: 스킬 `infocutter-blog-post` (구어체·공감 훅, 각주 인용, 제품 추천 금지). 글 추가 후 `node introduce/build-blog.mjs`로 HTML 재생성.

## 도움 창구

힘들 때는 혼자 두지 마세요.

- **자살예방상담전화 109** (24시간) · **정신건강위기상담 1577-0199** · 가까운 정신건강복지센터

> 본 폴더의 글은 일반 정보이며 의료·법률 자문이 아닙니다.
