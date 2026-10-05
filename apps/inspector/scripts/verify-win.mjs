import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { verifyPackage } from './packaging-lib.mjs';
const release = resolve(dirname(fileURLToPath(import.meta.url)), '../release');
const manifest = JSON.parse(await readFile(resolve(release, 'Inspektor-win32-x64.manifest.json'), 'utf8'));
const files = await verifyPackage(resolve(release, 'Inspektor-win32-x64'), manifest);
console.log(`패키지 파일 ${files.length}개 SHA256·PE x64·필수 자산 검증 완료. 실제 Windows 실행은 별도 검사입니다.`);
