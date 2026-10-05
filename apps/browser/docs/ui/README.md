# 모바일 크롬 UI 시안

구현 전에 화면을 먼저 확정하기 위한 시안이다. 이슈 #23 의 근거 문서다.

| 파일 | 성격 |
|---|---|
| `infocutter-chrome-artboard.blockdoc` | **화면 시안 정본.** 375×812 아트보드를 좌표로 그린다 |
| `infocutter-chrome-artboard-mobile.png` | 렌더 결과 — 라이트·다크 두 장 |
| `infocutter-mobile-chrome.blockdoc` | 결함 설명 문서(As-is/To-be 주석형) |
| `infocutter-mobile-chrome-mobile.png` | 위 문서의 렌더 결과 |

**둘은 성격이 다르다.** 아트보드는 *화면이 어떻게 생겼는가*, 설명 문서는 *무엇이 왜
잘못됐는가* 를 말한다. 처음에 설명 문서만 만들었다가 "이건 시안이 아니다" 는 지적을
받고 아트보드를 따로 그렸다 — 라벨과 화살표가 붙은 그림은 스펙 시트지 화면이 아니다.

렌더 HTML 은 커밋하지 않는다 — 폰트가 내장돼 5.5MB 이고, 아래 명령으로 언제든 다시 만든다.

## 재생성

```sh
cd apps/infocutter-app/docs/ui
design-component-library doc render infocutter-chrome-artboard.blockdoc --viewport mobile --out .
design-component-library doc render infocutter-mobile-chrome.blockdoc  --viewport mobile --out . --html
```

아트보드는 두 장(라이트·다크)이 세로로 이어진 한 PNG 로 나온다. 사이에 검은 띠가
남는데 도구의 캔버스 높이 계산 탓이며, 리뷰에 쓸 때는 잘라서 쓴다.

`design-component-library` 는 `swift-app-mono/apps/design-component-library-swift` 의 CLI 다
(`/opt/homebrew/bin`). 색·타이포는 `design-system-studio` 의 `studio-default` 토큰셋과
`pretendard-default` 타이포셋을 참조한다 — 시안 안에서 색을 새로 발명하지 않는다.

```sh
design-system-studio tokens show studio-default --json
design-system-studio typo list --json
```

## 시안이 말하는 것

### As-is
아이콘 4개(32×4 = **128px**)가 주소창이 비워 둔 오른쪽 여백(**48px**)보다 넓어 URL 위로
겹친다. 근거는 `lib/app_bar/webview_tab_address_field.dart:49`(Stack) · `:84-90`
(`contentPadding right: 48`) · `:223`(버튼 폭 32). 하단 내비게이션은 아예 없다
(`grep -rn "bottomNavigationBar\|BottomAppBar" lib/` → 0건).

### To-be
- **상단은 신원과 주소만 남긴다.** 스킴·`www` 를 접고 호스트를 강조한다
- **인포커터 3버튼을 하단 액션바로 내린다.** 겹침의 원인이 사라지고, 이 앱의 핵심 동작이
  엄지 도달 범위로 온다
- **뒤로/앞으로가 화면에 생긴다.** iOS 는 지금 빠져나갈 길이 없다
- **`⋮` 는 하나만 둔다.** 지금은 주소창 안과 앱바 끝에 각각 있어 구분이 안 된다
- 브라우저 이동(중립색)과 인포커터 동작(브랜드색)을 **색으로 가른다**
- 상단 `SafeArea` 를 지킨다

## 구현 시 주의

시안은 **배치와 정보구조**를 정한 것이지 픽셀 사양이 아니다. 실제 구현은 손으로 좌표를
잡지 말고 프레임워크가 주는 것을 쓴다 — 겹침이 난 이유가 그것이다.

| 시안 요소 | 구현 |
|---|---|
| 주소창 + 우측 아이콘 | `TextField.prefixIcon` / `suffixIcon` (여백 자동 예약) |
| 주소창 + 제안 | `SearchAnchor` / `SearchBar` — #15 자동완성까지 함께 먹는다 |
| 하단 액션바 | `NavigationBar` 또는 `BottomAppBar` (Material 3) |
| 메뉴 계층 | `MenuAnchor` |

`design-component-library` 는 **Dart 를 내보내지 않는다**(HTML/CSS/PNG 전용). 이 시안에서
위젯 코드가 나오지 않는다는 뜻이다. 토큰만 Dart 로 옮기는 것은 별개 작업이다.
