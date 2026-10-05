/* eslint-disable @typescript-eslint/no-unused-vars */

const INFOCUTTER_TOAST_ID = "infocutter-toast";

function showToast(text: string): void {
  document.getElementById(INFOCUTTER_TOAST_ID)?.remove();

  const toast = document.createElement("div");
  toast.id = INFOCUTTER_TOAST_ID;
  toast.textContent = text;
  toast.style.position = "fixed";
  toast.style.right = "16px";
  toast.style.bottom = "16px";
  toast.style.padding = "10px 14px";
  toast.style.background = "#231f17";
  toast.style.color = "#f7f4eb";
  toast.style.font = '13px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';
  toast.style.borderRadius = "8px";
  toast.style.boxShadow = "0 12px 30px rgba(0,0,0,0.24)";
  toast.style.zIndex = "2147483647";
  toast.style.pointerEvents = "none";
  toast.style.opacity = "1";
  toast.style.transition = "opacity 240ms ease-out";
  document.documentElement.append(toast);

  window.setTimeout(() => {
    toast.style.opacity = "0";
  }, 1500);
  window.setTimeout(() => {
    toast.remove();
  }, 1800);
}
