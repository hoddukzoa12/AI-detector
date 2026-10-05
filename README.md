# AI-detector

[![Windows package test](https://github.com/hoddukzoa12/AI-detector/actions/workflows/windows-test.yml/badge.svg)](https://github.com/hoddukzoa12/AI-detector/actions/workflows/windows-test.yml)

공개 웹사이트의 은닉 텍스트와 이미지 광고를 점검하는 npm·Playwright 앱입니다. **Gemini OCR로 글자를 추출하고 CLEF로 광고를 분류**하며, 로컬 광고 판정이나 실패 시 대체 분류기를 사용하지 않습니다. Docker와 Electron Windows 패키지를 제공합니다.

```bash
cd apps/inspector
npm ci
npx playwright install chromium
cp inspector.env.example .env
# .env에 OPENROUTER_API_KEY를 설정합니다.
npm run dev
```

Node 24 LTS를 사용합니다. 실제 점검은 CLEF 전송 동의와 OpenRouter 키가 필요합니다. 이미지 OCR은 기본 꺼짐이며 선택할 수 있습니다. 입력 호스트의 공개 페이지와 포함 iframe만 읽고 로그인·폼 제출·외부 광고 링크 탐색은 수행하지 않습니다.

- 직접 DOM 원문 네 유형: `result.json`
- 이미지 광고 OCR 결과: `result_extra.json`
- 근거·검토·미완료·이미지/파일 해시: 실행별 로컬 출력

[실행 안내](apps/inspector/README.md) · [배포 방법](apps/inspector/PACKAGING.md) · [Windows Actions 검증](docs/windows-actions.md)

## Windows 자동 테스트

[Windows package test](https://github.com/hoddukzoa12/AI-detector/actions/workflows/windows-test.yml)는 Linux에서 회귀 검사와 Windows ZIP 생성 후 **windows-2025**에서 실제 bundled Node·Chromium·Inspektor.exe 자체 점검·GUI 표시·정상 종료를 검사합니다. Actions → Windows package test → Run workflow로 다시 실행할 수 있습니다.

실행 보고서와 GUI 스크린샷은 `windows-test-evidence`, 패키지는 `windows-package` artifact에 3일간 보관합니다. 검사는 합성 OCR/CLEF 응답을 명시적으로 주입하며 **실제 API 키·유료 모델 호출·실사이트 탐색은 사용하지 않습니다**.

2026-10-05 [실제 실행](https://github.com/hoddukzoa12/AI-detector/actions/runs/37298661138)이 **성공**했습니다. 단위 473개·통합 14개, Windows EXE 자체 점검·GUI·보안 설정·정상 종료를 확인했습니다. [검증 기록과 화면 캡처](docs/windows-actions.md#2026-10-05-실제-실행-결과)를 보존했습니다.

GitHub 러너는 Windows Server 2025이며 Windows 11 최종 사용자 PC 검증과 다릅니다. 실제 Windows 11·대표 사이트 정확도·30분 실행·두 실제 키 교체는 별도 확인이 필요합니다.

## 출처와 권리

[dalsoop/infocutter-mono](https://github.com/dalsoop/infocutter-mono)를 기반으로 확장했습니다. 공개 시작 소스는 로컬 검증 커밋 `0f904913b926412f901e1956bccea1f9077acd04`의 추적 파일 사본입니다. 개인 `.env`, 실행 결과, 배포 ZIP과 이전 Git 기록은 포함하지 않았습니다.

기존 Flutter·Chrome 소비자 앱은 기반 코드와 출처 보존을 위해 함께 남아 있으며 점검 앱을 실행하는 데 필요하지 않습니다. 기존 고지를 보존했고 저장소 전체 재배포 권리는 미확정입니다. 새 MIT 라이선스나 권리 허가를 임의로 부여하지 않습니다. [기존 README](UPSTREAM-README.md)와 `docs/submission/licenses.md`에 출처를 보존합니다.
