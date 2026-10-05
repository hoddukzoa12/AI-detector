/* eslint-disable @typescript-eslint/no-unused-vars */

let infocutterPeekActive = false;

function toggleInfocutterPeek(): boolean {
  infocutterPeekActive = !infocutterPeekActive;
  return infocutterPeekActive;
}

function hiddenAttrCss(attr: string): string {
  if (infocutterPeekActive) {
    return `[${attr}] { opacity: 0.35 !important; outline: 1px dashed rgba(217, 119, 6, 0.9) !important; }`;
  }

  return `[${attr}] { display: none !important; }`;
}
