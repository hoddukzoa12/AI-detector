# 인포커터

개발할 때는 `./infocutter`만 씁니다.

## 커맨드

- `./infocutter dev`
- `./infocutter doctor`
- `./infocutter build`
- `./infocutter watch`
- `./infocutter check`
- `./infocutter rc`
- `./infocutter reset`

## 크롬 로드

1. `./infocutter dev`
2. `chrome://extensions`
3. 개발자 모드 켜기
4. `Load unpacked`
5. `dist` 폴더 선택

## iOS Safari (플랫폼 분리 — issue #12 안2)

iOS = Safari Web Extension, Android = Flutter. 코어 숨김(content scripts + storage + declarativeNetRequest)은 iOS Safari 정식 지원이고, Google 로그인은 브라우저가 처리해 임베디드 웹뷰 정책 차단이 원천 해소된다.

```sh
npm run pipe:safari        # dist 빌드 → safari-web-extension-converter → safari-ios/
open safari-ios/*.xcodeproj   # Xcode Archive → App Store Connect (TestFlight)
```

- 출력 `safari-ios/`는 빌드 산물(.gitignore). 소스가 진실이고 converter로 재생성.
- 한계(C 스파이크): `chrome.offscreen` 미지원 → 증거 PDF 파이프라인은 제외/재설계. 코어 숨김·로그인과 독립 분리 가능.

## 메모

- npm 스크립트는 내부 파이프라인용입니다.
- 바깥에서는 `./infocutter ...`만 쓰면 됩니다.
