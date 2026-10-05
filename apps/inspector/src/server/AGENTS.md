# 로컬 HTTP 경계

세션 토큰·Host/Origin·입력·등록 파일/근거 경로·정적 bootstrap을 맡는다. 탐지·AI 정책·임의 JS/명령 실행·임의 파일 읽기를 넣지 않는다.

실제 listener 포트의 루프백 Host만 허용하고 API에 현재 Bearer 토큰을 요구한다. bootstrap은 정적 원문을 검증해 nonce와 토큰을 넣으며 키를 반환하지 않는다. 파일은 여섯 JSON 허용 목록과 등록 snapshotId만 제공한다. V2 시작 입력은 키·CLEF 전송 동의·OCR 선택을 엄격 검증하며 PNG는 등록 input assetId·경로·해시·symlink 검사 후 image/png·nosniff로만 제공한다. 임의 URL·원본 SVG/HTML은 제공하지 않는다.

인증/Origin/Host/CSRF·body상한·중복 시작·상태/다운로드·identifier/path/symlink·닫기/취소·정적 CSP와 토큰 비노출을 검사한다.
