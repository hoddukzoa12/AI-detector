---
name: infocutter-introduce-page
description: 인포커터 introduce/ 폴더의 HTML 페이지(랜딩 index.html, 블로그 페이지 등)를 만들거나 고칠 때의 절차·구조 규약. 항상 최신 template-*.html 를 베이스로 복사해 시작하고, 색·타이포는 [[dalsoop-design-pattern]], 카피는 [[infocutter-voice]]/[[infocutter-blog-post]] 를 따른다. Use when - introduce 랜딩·소개·블로그 HTML 을 새로 만들거나 레이아웃·디자인을 손볼 때.
---

# 인포커터 introduce 페이지 빌드 규약

`vibecode-chrome-extension-infocutter/introduce/` 의 HTML 페이지를 일관되게 만든다.

## 역할 분담 (다른 스킬과 함께 쓴다)

- **디자인(색·타이포·간격·컴포넌트)** → [[dalsoop-design-pattern]] (파랑 #0a6cff, 그레이, Pretendard, 아이보리 금지).
- **랜딩·소개 카피(메시지·톤)** → [[infocutter-voice]] (위로→안심→설득, 공포·과대광고 금지).
- **블로그 글 본문** → [[infocutter-blog-post]] (구어체·공감 훅, 각주 인용, 제품 추천 금지).
- 이 스킬은 그 위에서 **HTML 페이지의 구조·파일 규약·작업 순서**만 정한다.

## 파일 규약

```
introduce/
├── template-YYMMDDHHMMSS.html   # 재사용 베이스 템플릿(타임스탬프). 가장 최신 파일이 현재 표준.
├── index.html                   # 랜딩(제품 소개) — 템플릿에서 복사해 채움
├── README.md                    # 마크다운 소개(GitLab 렌더용)
└── blog/                        # 블로그(.md 소스 + 생성 .html), build-blog.mjs 로 생성
```

- **베이스 템플릿은 항상 `template-YYMMDDHHMMSS.html`** 한 형태로 둔다. 토큰·헤더·푸터·컴포넌트 스캐폴드만 들어가고 더미 콘텐츠로 채워져 있다.
- 템플릿을 **갱신**할 땐: 현재 시각으로 새 파일(`date +%y%m%d%H%M%S`)을 만들고 옛 템플릿은 지운다(항상 1개만 유지).
- **실제 페이지(index.html 등)는 최신 템플릿을 복사**해 헤더/푸터/토큰을 그대로 쓰고 본문만 교체한다.

## 페이지 구조 (표준)

헤더(sticky) → 히어로 → 본문 섹션들 → CTA → 푸터. 폭은 `.container`(1080) / `.read`(720). 컴포넌트: `.btn`/`.btn-ghost`/`.card`/`.badge`/`.note`/`.grid-2,3`/`.eyebrow`/`.lead`.

- CSS 토큰은 `:root` 인라인(외부 의존성 0). dalsoop 변수명을 그대로 쓴다.
- 푸터엔 **면책 + 자살예방상담 109(24시간)** 한 줄을 항상 넣는다.
- 랜딩(index.html)은 **제품을 설명**해도 된다(제품 페이지니까). 블로그 글은 제품을 대놓고 권하지 않는다.

## 작업 순서

1. 최신 `template-*.html` 를 연다(없으면 dalsoop-design-pattern 토큰으로 새로 만든다).
2. `index.html`(또는 대상 페이지)로 복사. `<title>`·`<meta description>` 교체.
3. 히어로/섹션 본문을 [[infocutter-voice]] 카피로 채운다. 용어·아이콘 남발 금지, 심플하게.
4. 면책·109 푸터 유지. 외부 링크는 `.html` 내부 페이지로 연결(블로그는 `blog/` 인덱스).
5. **렌더 확인**: file:// 로 열어 스크린샷으로 본다(아이보리·깨진 레이아웃·오타 체크).
6. 커밋. 블로그 .html 은 `node introduce/build-blog.mjs` 로 재생성(직접 손대지 않는다).

## 하지 말 것

- 아이보리/크림 팔레트, 과한 그림자·그라데이션.
- 템플릿을 여러 개 방치(항상 1개).
- 랜딩 본문에 출처 인용 블록(`> 요지:`) — 그건 블로그 규약이 아니라 여기선 애초에 안 씀.
- 블로그 .html 을 손으로 편집(생성기로만).
