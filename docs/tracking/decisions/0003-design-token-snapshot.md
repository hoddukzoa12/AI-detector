# 0003. 디자인 토큰은 저장소에 커밋한 스냅샷에서 생성한다

- 날짜: 2026-08-04 (이전 저장소 `flutter-app-mono` 커밋 `abda45d`)
- 상태: 기존 제품의 결정 이력; 공모전 정책은 별도로 확정

## 배경

Flutter 앱의 색이 `infocutter_theme.dart` 안에 `Color(0xFF...)`로 흩어져 있어서 다른 앱과 기준이 따로 놀고, UI 작업자에게 쓸 수 있는 색의 경계가 없었다. 토큰의 정본은 macOS 앱 `design-system-studio`에 있다.

## 결정

`design-system-studio`에서 export한 JSON을 `apps/browser/design/design-tokens.json`으로 커밋하고, `tool/generate_theme_tokens.dart`가 그 파일만 읽어 `lib/theme/infocutter_tokens.g.dart`를 만든다. 생성물도 커밋한다. `--check` 모드로 두 파일의 동기를 검사한다.

## 검토한 대안

- **생성기가 `design-system-studio` CLI를 직접 호출하는 것**: studio는 macOS 앱이라 CI와 다른 기여자 기기에 없다. 직접 호출하면 그 맥 밖에서는 빌드도 `--check`도 할 수 없어서 택하지 않았다.
- **studio 기본 팔레트로 바꾸는 것**: 기본 팔레트는 인디고 계열이라 브랜드가 통째로 바뀐다. 브랜드 변경은 별개 결정으로 두고, 스냅샷에는 당시 앱 팔레트를 그대로 담았다.

## 결과

- 테마 파일에서 색을 새로 만들 수 없다. 색은 토큰을 늘리고 다시 생성하는 방식으로만 추가한다.
- 정본(studio)과 스냅샷이 어긋날 수 있다. 정본을 바꾼 사람은 export와 재생성을 같은 커밋에 넣어야 한다.
- 라이트·다크 색 값이 테스트에 고정되어 있어, 브랜드를 바꾸는 날에는 그 기대값도 같이 고친다.
