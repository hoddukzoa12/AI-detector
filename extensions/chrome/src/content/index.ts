(() => {
  if (infocutterGlobal.__INFOCUTTER_CONTENT_LOADED__) {
    return;
  }

  infocutterGlobal.__INFOCUTTER_CONTENT_LOADED__ = true;

  document.addEventListener(
    "contextmenu",
    (event) => {
      const target = event.target;
      lastContextTarget = target instanceof Element ? target : null;
    },
    true
  );

  window.addEventListener("message", (event: MessageEvent) => {
    const message = parseFrameMessage(event);
    if (!message) {
      return;
    }

    const { source, type } = message;

    if (source === "infocutter" && type === PICKER_FRAME_MESSAGE_TYPE) {
      const requestId = message.requestId;
      if (requestId && event.source && "postMessage" in event.source && typeof event.source.postMessage === "function") {
        event.source.postMessage(
          {
            requestId,
            source: "infocutter",
            type: PICKER_FRAME_ACK_TYPE
          },
          {
            targetOrigin: "*"
          }
        );
      }
      startPicker();
    }
  });

  chrome.runtime.onMessage.addListener((message: unknown, _sender, sendResponse) => {
    void (async () => {
      if (!message || typeof message !== "object") {
        sendResponse({ ok: false });
        return;
      }

      const type = "type" in message ? message.type : null;

      if (type === messageTypes.ping) {
        sendResponse({
          ok: true,
          data: {
            ready: true,
            url: window.location.href
          }
        });
        return;
      }

      if (type === messageTypes.getPageState) {
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.getTextBlockState) {
        sendResponse({
          ok: true,
          data: await readActiveTextBlockState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.getTextBlockDiagnostics) {
        sendResponse({
          ok: true,
          data: await readTextBlockDiagnostics(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.startPicker) {
        startPicker();
        sendResponse({ ok: true });
        return;
      }

      if (type === messageTypes.stopPicker) {
        pickerStop?.();
        sendResponse({ ok: true });
        return;
      }

      if (type === messageTypes.togglePeek) {
        const active = toggleInfocutterPeek();
        await renderAllRules();
        if (window.top === window) {
          showToast(active ? "peek 켬" : "peek 끔");
        }
        sendResponse({ ok: true, data: { active } });
        return;
      }

      if (type === messageTypes.hideLastContextTarget) {
        if (!lastContextTarget) {
          sendResponse({ ok: false });
          return;
        }

        const selector = await hideTargetElement(lastContextTarget);
        sendResponse({
          ok: true,
          data: {
            selector,
            state: await readActiveSiteState(window.location.href)
          }
        });
        return;
      }

      if (type === messageTypes.clearSiteRules) {
        const currentState = await readActiveSiteState(ownerPageUrl());
        if (!currentState.activeProfileId) {
          sendResponse({ ok: false });
          return;
        }

        await clearSiteRules(currentState.activeProfileId);
        await renderAllRules();
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.removeSiteRule) {
        const selector = "selector" in message && typeof message.selector === "string" ? message.selector : null;
        const cardId = "cardId" in message && typeof message.cardId === "string" ? message.cardId : null;
        const createdAt = "createdAt" in message && typeof message.createdAt === "string"
          ? message.createdAt
          : null;
        const mode = "mode" in message && message.mode === "unhide" ? "unhide" : "hide";
        const frameScope =
          "frameScope" in message && typeof message.frameScope === "string"
            ? message.frameScope
            : null;
        const profileId =
          "profileId" in message && typeof message.profileId === "string"
            ? message.profileId
            : null;
        if (!selector || !cardId || !createdAt || !profileId) {
          sendResponse({ ok: false });
          return;
        }

        await removeSiteRule(profileId, {
          cardId,
          createdAt,
          frameScope,
          mode,
          selector
        });
        await renderAllRules();
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.toggleSiteEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        const wantsToast = "toast" in message && message.toast === true;
        const currentState = await readActiveSiteState(ownerPageUrl());
        if (enabled === null || !currentState.activeProfileId) {
          if (wantsToast && window.top === window) {
            showToast("이 사이트에 규칙 없음");
          }
          sendResponse({ ok: false });
          return;
        }

        await setSiteEnabled(currentState.activeProfileId, enabled);
        await renderAllRules();
        if (wantsToast) {
          showToast(enabled ? "이 사이트 켬" : "이 사이트 끔");
        }
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.toggleGlobalEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        const wantsToast = "toast" in message && message.toast === true;
        if (enabled === null) {
          sendResponse({ ok: false });
          return;
        }

        await setGlobalEnabled(enabled);
        await renderAllRules();
        if (wantsToast) {
          showToast(enabled ? "전역 숨김 켬" : "전역 숨김 끔");
        }
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.toggleTextBlockProfileEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        const currentState = await readActiveTextBlockState(ownerPageUrl());
        if (enabled === null || !currentState.activeProfileId) {
          sendResponse({ ok: false });
          return;
        }

        await setTextBlockProfileEnabled(currentState.activeProfileId, enabled);
        await renderAllRules();
        sendResponse({
          ok: true,
          data: await readActiveTextBlockState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.toggleTextBlockGlobalEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        if (enabled === null) {
          sendResponse({ ok: false });
          return;
        }

        await setTextBlockGlobalEnabled(enabled);
        await renderAllRules();
        sendResponse({
          ok: true,
          data: await readActiveTextBlockState(ownerPageUrl())
        });
        return;
      }

      if (type === messageTypes.collectAiBlocks) {
        sendResponse({ ok: true, data: collectAiBlocks() });
        return;
      }

      sendResponse({ ok: false });
    })().catch((error: unknown) => {
      console.error("콘텐츠 스크립트 메시지 처리에 실패했습니다", error);
      sendResponse({ ok: false });
    });

    return true;
  });

  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName !== "local") {
      return;
    }

    if (WATCH_STORAGE_KEY in changes) {
      scheduleWatchRender();
    }

    if (STORAGE_KEY in changes || TEXT_BLOCK_STORAGE_KEY in changes || AI_RULE_STORAGE_KEY in changes) {
      void renderAllRules();
    }
  });

  ensureSelectorObserver();
  ensureTextBlockObserver();
  bootWatchRuntime();
  void renderAllRules();
})();
