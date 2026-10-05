---
name: chrome-extension-content-series
description: 블록셀렉터, SEO 체크, YouTube Evaluator 같은 달숲 크롬 확장의 랜딩/블로그 8편 시리즈를 기획하거나 점검할 때 쓰는 제품별 보이스·글감 라우팅 가이드. 인포커터 피해자 보이스를 다른 실무형 확장에 섞지 않고, 각 제품의 introduce/SKILL.md 와 blog/SKILL.md 를 먼저 읽게 한다.
---

# 크롬 확장 콘텐츠 시리즈 가이드

이 스킬은 `vibecode-chrome-extension-infocutter/.claude` 에 있지만, 아래 세 제품까지 함께 점검할 때 쓴다. 실제 정본은 각 제품 폴더의 `introduce/SKILL.md` 와 `introduce/blog/SKILL.md` 다.

## 먼저 라우팅

| 제품 | 정본 보이스 | 정본 블로그 규칙 |
|---|---|---|
| 블록셀렉터 | `../../../../vibecode-chrome-extension-block-selector/introduce/SKILL.md` | `../../../../vibecode-chrome-extension-block-selector/introduce/blog/SKILL.md` |
| SEO 체크 | `../../../../vibecode-chrome-extension-seo-check/introduce/SKILL.md` | `../../../../vibecode-chrome-extension-seo-check/introduce/blog/SKILL.md` |
| YouTube Evaluator | `../../../../vibecode-chrome-extension-youtube-evaluator/introduce/SKILL.md` | `../../../../vibecode-chrome-extension-youtube-evaluator/introduce/blog/SKILL.md` |
| 인포커터 | `../../../introduce/SKILL.md` 또는 `[[infocutter-voice]]` | `[[infocutter-blog-post]]` |

디자인이 들어가면 모노레포 루트의 `../../../../.claude/skills/dalsoop-design-pattern/SKILL.md` 를 함께 본다.

## 제품별 콘텐츠 약속

| 확장 | 보이스 | 8편 시리즈의 역할 |
|---|---|---|
| 블록셀렉터 | "복붙 지옥에서 클릭 추출로." 코딩 못함을 약점으로 다루지 말고, 손작업이 줄어드는 장면을 먼저 보여준다. | 노코드 입문 -> CSS 선택자 -> XPath 판단 -> 반복 블록 -> 가격 모니터링 -> 뉴스/블로그 목록 -> robots/약관 매너 -> 웹훅 자동화 |
| SEO 체크 | "왜 검색에 안 잡히는지 쉽게 보이게." 검색엔진은 도서관 사서, title/canonical/schema는 이름표·카드처럼 푼다. | SEO 첫걸음 -> title -> description -> 대표 제목/heading 구조 -> alt -> OG/Twitter -> canonical -> schema |
| YouTube Evaluator | "클릭 전에는 거르는 눈, 업로드 전에는 고치는 눈." 글마다 시청자/크리에이터 중 한 대상을 먼저 고른다. | 시청자 4편: 썸네일, 싫어요 추정 신호, 반응 품질, 낚시 제목. 크리에이터 4편: 제목/썸네일, 챕터, 자막, 메타데이터 |

## 개선 원칙

- 제품별 톤을 섞지 않는다. 인포커터의 위로/안심 보이스는 악플 피해자 글에만 쓴다.
- 블로그는 광고가 아니다. 제품명을 밀기보다 독자의 일을 하나 해결한다.
- 첫 문장은 공감/장면/질문 훅으로 시작한다. "오늘은 ~ 알아보겠습니다" 금지.
- 기술 글은 쉬워야 하지만 틀리면 안 된다. CSS/XPath, robots, SEO, YouTube 신호는 공식 문서나 신뢰 가능한 실제 출처만 쓴다.
- SEO는 순위 보장, 마법의 글자수, `h1 하나면 된다` 같은 미신을 피한다. Google Search 관점에서 heading 개수/순서는 절대 규칙이 아니므로, 사람과 화면낭독기를 위한 구조로 설명한다.
- YouTube는 알고리즘 내부를 단정하지 않는다. 싫어요 수는 공식 공개값이 아니라 추정/참고 신호로만 다룬다.
- 스크래핑은 "다 합법"처럼 말하지 않는다. robots.txt, 약관, 로그인/개인정보, 요청 빈도 매너를 함께 말한다.

## 빠른 점검

- [ ] 제품 정본 `introduce/SKILL.md` 와 `introduce/blog/SKILL.md` 를 읽었나?
- [ ] 8편이 입문 -> 판단 기준 -> 실전 -> 주의/자동화 순서로 흐르나?
- [ ] 글마다 독자가 "오늘 하나 해볼 일"을 얻나?
- [ ] 가짜 통계, 순위/조회수 보장, 알고리즘 단정, 법률 단정이 없나?
- [ ] 제목이 주제 나열이 아니라 궁금증/상황을 담고 있나?
