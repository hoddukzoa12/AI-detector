// 실행 제어와 서버를 통합한 뒤 실제 시작 경로를 연결한다.
import { startServer } from './server/index.js';

try {
  const server = await startServer();
  console.log(`공개 웹사이트 점검: ${server.url}`);
  let closing = false;
  const close = async () => {
    if (closing) return;
    closing = true;
    try { await server.close(); }
    catch { console.error('점검 종료 또는 결과 저장에 실패했습니다. 출력 폴더를 확인하세요.'); process.exitCode = 1; }
  };
  process.once('SIGINT', () => { void close(); });
  process.once('SIGTERM', () => { void close(); });
} catch {
  console.error('점검 앱을 시작할 수 없습니다. 실행 설정과 포트 사용 여부를 확인하세요.');
  process.exitCode = 1;
}
