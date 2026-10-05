# 0002. iOS는 Safari Web Extension으로, 증거 PDF는 offscreen 없이도 만든다

- 날짜: 2026-08-09 (이전 저장소 `chrome-extension-mono` 커밋 `6439e8d`), PDF 경로 분기는 2026-08-10 (`d13e94e`)
- 상태: 기존 제품의 결정 이력; 공모전 정책은 별도로 확정

## 배경

임베디드 WebView 기반 앱에서는 Google 로그인이 IdP 정책으로 막힌다. 반면 Safari Web Extension은 content script, 저장소, declarativeNetRequest를 iOS Safari에서 정식으로 지원하고, 로그인은 Safari가 직접 처리한다. 다만 iOS Safari 확장에는 `chrome.offscreen`이 없어서, offscreen 문서에서 PDF를 합성하던 기존 증거 파이프라인이 그대로는 동작하지 않았다.

## 결정

- 플랫폼을 나눈다. iOS는 Chrome 확장 코드를 `xcrun safari-web-extension-converter`로 변환한 Safari Web Extension, Android는 Flutter 앱이다. 변환 결과(`safari-ios/`)는 빌드 산물로 두고 커밋하지 않는다.
- 증거 PDF 합성 본체(`buildEvidenceInPage`)를 하나로 두고, `chrome.offscreen`이 있으면 offscreen 문서에서, 없으면 `chrome.scripting.executeScript`로 페이지에 주입해 실행한다.

## 검토한 대안

- **iOS에서도 Flutter 앱을 쓰는 것**: 임베디드 WebView의 로그인 정책 차단을 피할 수 없어서 iOS의 주 경로로 삼지 않았다.
- **Safari에서 증거 PDF를 빼는 것**: 첫 스파이크에서 한계로 적어 두었으나, 다음 날 content script 경로로 PDF를 되살렸다.

## 결과

- `buildEvidenceInPage`는 함수 밖의 import, 모듈 상수, 클로저를 참조할 수 없다. `executeScript`가 함수를 직렬화해 페이지에 넣기 때문이다. jsPDF는 `globalThis.jspdf`에서만 가져온다.
- Chrome 확장 코드를 바꾸면 Safari 변환 결과도 바뀐다. `chrome.*` API를 새로 쓸 때는 iOS Safari 지원 여부를 확인해야 한다.
- Safari 확장의 실제 로드와 TestFlight 업로드는 Apple 인증서가 필요해 사람이 한다.
- Flutter 앱의 iOS 타깃(`apps/browser/ios`)은 저장소에 그대로 남아 있다.
