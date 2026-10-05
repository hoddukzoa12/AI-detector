/* eslint-disable @typescript-eslint/no-unused-vars */

async function renderAllRules(): Promise<void> {
  await renderRules();
  await renderTextBlockRules();
  await renderAiRules();
}
