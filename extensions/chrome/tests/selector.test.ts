import test from "node:test";
import assert from "node:assert/strict";

import { selectorCss } from "../src/shared/selector.js";
import { groupRulesByCard, matchesUrl, normalizeStore, readStore, removeRuleFromProfile, setCardEnabled } from "../src/shared/storage.js";
import { addTextBlockObjectCondition, normalizeTextBlockStore, readActiveTextBlockState, setTextBlockGlobalEnabled, setTextBlockHiddenObjectTag, setTextBlockObjectTags, setTextBlockRuleFingerprint, upsertTextBlockProfileRule } from "../src/shared/text-block-storage.js";
import { groupTextBlockRulesByObject, parseObjectTags } from "../packages/infocutter-text-blocks/src/index.js";
import { domainsToMatchers, networkRuleToDnrRule, parseFilterList } from "../packages/infocutter-filter-importer/src/index.js";
import { resolveActiveTab } from "../src/options/tabs.js";

void test("selectorCss emits display none rules", () => {
  const css = selectorCss([".target", "#banner"]);

  assert.equal(
    css,
    '.target { display: none !important; }\n#banner { display: none !important; }'
  );
});

void test("normalizeStore migrates version 1 shape to the current version", () => {
  const migrated = normalizeStore({
    version: 1,
    sites: {
      "example.com": {
        rules: [
          {
            cardName: "기본 카드",
            createdAt: "1970-01-01T00:00:00.000Z",
            frameScope: null,
            mode: "hide",
            selector: ".banner"
          }
        ],
        updatedAt: "2026-01-01T00:00:00.000Z"
      }
    }
  });

  const migratedProfileId = migrated.profiles[0]?.id;
  const migratedCardId = migrated.profiles[0]?.rules[0]?.cardId;

  assert.deepEqual(migrated, {
    version: 4,
    settings: {
      globalEnabled: true
    },
    profiles: [
      {
        cards: [
          {
            createdAt: "1970-01-01T00:00:00.000Z",
            enabled: true,
            id: migratedCardId,
            name: "기본 카드",
            updatedAt: "1970-01-01T00:00:00.000Z"
          }
        ],
        id: migratedProfileId,
        matchers: ["https://example.com/*"],
        name: "example.com",
        enabled: true,
        rules: [
          {
            cardId: migratedCardId,
            cardName: "기본 카드",
            createdAt: "1970-01-01T00:00:00.000Z",
            frameScope: null,
            mode: "hide",
            selector: ".banner"
          }
        ],
        sourceTemplateSlug: null,
        updatedAt: "2026-01-01T00:00:00.000Z"
      }
    ]
  });
});

void test("groupRulesByCard builds first-class card summaries", () => {
  const cards = groupRulesByCard([
    {
      cardId: "card-a",
      cardName: "헤더",
      createdAt: "2026-04-22T00:00:00.000Z",
      frameScope: null,
      mode: "hide",
      selector: ".header"
    },
    {
      cardId: "card-a",
      cardName: "헤더",
      createdAt: "2026-04-22T00:00:01.000Z",
      frameScope: "https://example.com/frame",
      mode: "hide",
      selector: ".header .cta"
    },
    {
      cardId: "card-b",
      cardName: "배너",
      createdAt: "2026-04-22T00:00:02.000Z",
      frameScope: null,
      mode: "hide",
      selector: ".banner"
    }
  ]);

  assert.equal(cards.length, 2);
  assert.deepEqual(cards[0], {
    cardId: "card-a",
    cardName: "헤더",
    createdAt: "2026-04-22T00:00:00.000Z",
    enabled: true,
    frameScopes: [null, "https://example.com/frame"],
    mode: "hide",
    ruleCount: 2,
    rules: [
      {
        cardId: "card-a",
        cardName: "헤더",
        createdAt: "2026-04-22T00:00:00.000Z",
        frameScope: null,
        mode: "hide",
        selector: ".header"
      },
      {
        cardId: "card-a",
        cardName: "헤더",
        createdAt: "2026-04-22T00:00:01.000Z",
        frameScope: "https://example.com/frame",
        mode: "hide",
        selector: ".header .cta"
      }
    ]
  });
  const secondCard = cards[1];

  assert.ok(secondCard);
  assert.equal(secondCard.cardId, "card-b");
  assert.equal(secondCard.ruleCount, 1);
});

void test("matchesUrl respects non-default ports in origin-based matchers", () => {
  assert.equal(matchesUrl("http://127.0.0.1:41771/*", "http://127.0.0.1:41771/"), true);
  assert.equal(matchesUrl("http://127.0.0.1:41771/*", "http://127.0.0.1:41772/"), false);
});

void test("removeRuleFromProfile removes only the targeted card rule", async () => {
  let persistedStore: unknown = {
    version: 4,
    settings: {
      globalEnabled: true
    },
    profiles: [
      {
        cards: [
          {
            createdAt: "2026-04-22T00:00:00.000Z",
            enabled: true,
            id: "card-a",
            name: "카드 A",
            updatedAt: "2026-04-22T00:00:00.000Z"
          },
          {
            createdAt: "2026-04-22T00:00:01.000Z",
            enabled: true,
            id: "card-b",
            name: "카드 B",
            updatedAt: "2026-04-22T00:00:01.000Z"
          }
        ],
        id: "profile-1",
        matchers: ["https://example.com/*"],
        name: "example.com",
        enabled: true,
        rules: [
          {
            cardId: "card-a",
            cardName: "카드 A",
            createdAt: "2026-04-22T00:00:00.000Z",
            frameScope: null,
            mode: "hide",
            selector: ".banner"
          },
          {
            cardId: "card-b",
            cardName: "카드 B",
            createdAt: "2026-04-22T00:00:01.000Z",
            frameScope: null,
            mode: "hide",
            selector: ".banner"
          }
        ],
        sourceTemplateSlug: null,
        updatedAt: "2026-04-22T00:00:00.000Z"
      }
    ]
  };

  Object.assign(globalThis, {
    chrome: {
      storage: {
        local: {
          get(key: string) {
            return Promise.resolve({ [key]: persistedStore });
          },
          set(nextValue: Record<string, unknown>) {
            persistedStore = nextValue["infocutter.ruleStore"];
            return Promise.resolve();
          }
        }
      }
    }
  });

  await removeRuleFromProfile("profile-1", {
    cardId: "card-a",
    createdAt: "2026-04-22T00:00:00.000Z",
    frameScope: null,
    mode: "hide",
    selector: ".banner"
  });

  const nextStore = await readStore();
  const remainingProfile = nextStore.profiles[0];

  assert.ok(remainingProfile);
  assert.equal(remainingProfile.rules.length, 1);
  const remainingRule = remainingProfile.rules[0];

  assert.ok(remainingRule);
  assert.equal(remainingRule.cardId, "card-b");
  assert.equal(remainingRule.selector, ".banner");
});

void test("setCardEnabled updates card metadata without removing rules", async () => {
  let persistedStore: unknown = {
    version: 4,
    settings: {
      globalEnabled: true
    },
    profiles: [
      {
        cards: [
          {
            createdAt: "2026-04-22T00:00:00.000Z",
            enabled: true,
            id: "card-a",
            name: "카드 A",
            updatedAt: "2026-04-22T00:00:00.000Z"
          }
        ],
        id: "profile-1",
        matchers: ["https://example.com/*"],
        name: "example.com",
        enabled: true,
        rules: [
          {
            cardId: "card-a",
            cardName: "카드 A",
            createdAt: "2026-04-22T00:00:00.000Z",
            frameScope: null,
            mode: "hide",
            selector: ".banner"
          }
        ],
        sourceTemplateSlug: null,
        updatedAt: "2026-04-22T00:00:00.000Z"
      }
    ]
  };

  Object.assign(globalThis, {
    chrome: {
      storage: {
        local: {
          get(key: string) {
            return Promise.resolve({ [key]: persistedStore });
          },
          set(nextValue: Record<string, unknown>) {
            persistedStore = nextValue["infocutter.ruleStore"];
            return Promise.resolve();
          }
        }
      }
    }
  });

  await setCardEnabled("profile-1", "card-a", false);

  const nextStore = await readStore();
  const nextProfile = nextStore.profiles[0];

  assert.ok(nextProfile);
  assert.equal(nextProfile.rules.length, 1);
  assert.equal(nextProfile.cards[0]?.enabled, false);
});

void test("normalizeTextBlockStore keeps the text domain separate and disabled by default", () => {
  assert.deepEqual(normalizeTextBlockStore(null), {
    version: 1,
    settings: {
      globalEnabled: false,
      hiddenObjectTags: ["ad"]
    },
    profiles: []
  });
});

void test("upsertTextBlockProfileRule creates a separate text profile and respects the minimum match count", async () => {
  let persistedRuleStore: unknown = undefined;
  let persistedTextBlockStore: unknown = undefined;

  Object.assign(globalThis, {
    chrome: {
      storage: {
        local: {
          get(key: string) {
            if (key === "infocutter.textBlockStore") {
              return Promise.resolve({ [key]: persistedTextBlockStore });
            }

            if (key === "infocutter.ruleStore") {
              return Promise.resolve({ [key]: persistedRuleStore });
            }

            return Promise.resolve({ [key]: undefined });
          },
          set(nextValue: Record<string, unknown>) {
            if ("infocutter.textBlockStore" in nextValue) {
              persistedTextBlockStore = nextValue["infocutter.textBlockStore"];
            }

            if ("infocutter.ruleStore" in nextValue) {
              persistedRuleStore = nextValue["infocutter.ruleStore"];
            }

            return Promise.resolve();
          }
        }
      }
    }
  });

  await upsertTextBlockProfileRule({
    keyword: "광고",
    matcher: "https://www.naver.com/*",
    minMatchCount: 1,
    profileName: "네이버 광고"
  });

  const initialState = await readActiveTextBlockState("https://www.naver.com/");
  const firstRule = initialState.rules[0];

  assert.equal(initialState.activeProfileName, "네이버 광고");
  assert.equal(initialState.ruleCount, 1);
  assert.equal(initialState.globalEnabled, false);
  assert.ok(firstRule);
  assert.equal(firstRule.keyword, "광고");
  assert.equal(firstRule.fingerprint, null);
  assert.equal(firstRule.minMatchCount, 2);
  assert.equal(firstRule.objectName, "광고");
  assert.equal(typeof firstRule.objectId, "string");
  assert.deepEqual(firstRule.objectTags, []);

  await setTextBlockGlobalEnabled(true);

  const enabledState = await readActiveTextBlockState("https://www.naver.com/");
  assert.equal(enabledState.globalEnabled, true);
  assert.deepEqual(enabledState.hiddenObjectTags, ["ad"]);

  const profileId = enabledState.activeProfileId;
  assert.ok(profileId);
  await setTextBlockObjectTags(profileId, firstRule.objectId, ["ad", "promo"]);
  await setTextBlockHiddenObjectTag("ad", false);
  await setTextBlockRuleFingerprint(profileId, firstRule.id, "article|promo");

  const scopedState = await readActiveTextBlockState("https://www.naver.com/");
  const scopedRule = scopedState.rules[0];
  assert.ok(scopedRule);
  assert.equal(scopedRule.fingerprint, "article|promo");
  assert.deepEqual(scopedRule.objectTags, ["ad", "promo"]);
  assert.deepEqual(scopedState.hiddenObjectTags, []);

  await addTextBlockObjectCondition(profileId, firstRule.objectId, {
    keyword: "협찬",
    minMatchCount: 3
  });

  const objectState = await readActiveTextBlockState("https://www.naver.com/");
  const sameObjectRules = objectState.rules.filter((rule) => rule.objectId === firstRule.objectId);
  const secondRule = sameObjectRules[1];
  assert.equal(sameObjectRules.length, 2);
  assert.ok(secondRule);
  assert.equal(secondRule.keyword, "협찬");
  assert.equal(secondRule.objectName, firstRule.objectName);

  const groupedObjects = groupTextBlockRulesByObject(objectState.rules);
  assert.equal(groupedObjects.length, 1);
  assert.deepEqual(groupedObjects[0]?.objectTags, ["ad", "promo"]);
  assert.deepEqual(parseObjectTags("ad, sponsored promo"), ["ad", "sponsored", "promo"]);
});

void test("parseFilterList imports AdGuard-compatible cosmetic and text rules", () => {
  const parsed = parseFilterList(`
! comment
example.com##.ad-banner
example.com#@#.allowed-ad
news.example#?#article:contains("광고")
||ads.example^$script,image
example.com#%#//scriptlet('abort-on-property-read', 'ad')
  `);

  assert.equal(parsed.summary.cosmeticCount, 1);
  assert.equal(parsed.summary.cosmeticExceptionCount, 1);
  assert.equal(parsed.summary.textCount, 1);
  assert.equal(parsed.summary.networkCount, 1);
  assert.equal(parsed.summary.unsupportedCount, 1);

  const cosmetic = parsed.rules.find((rule) => rule.kind === "cosmetic");
  const text = parsed.rules.find((rule) => rule.kind === "text");
  const network = parsed.rules.find((rule) => rule.kind === "network");

  assert.ok(cosmetic);
  assert.deepEqual(cosmetic.domains, ["example.com"]);
  assert.equal(cosmetic.selector, ".ad-banner");

  assert.ok(text);
  assert.equal(text.text, "광고");
  assert.equal(text.selector, "article");

  assert.ok(network);
  assert.equal(network.pattern, "||ads.example^");
  assert.deepEqual(network.modifiers, ["script", "image"]);
  assert.deepEqual(domainsToMatchers(["example.com"]), ["*://example.com/*"]);
});

void test("normalizeStore keeps hide and exception selector modes", () => {
  const store = normalizeStore({
    version: 4,
    settings: {
      globalEnabled: true
    },
    profiles: [
      {
        cards: [
          {
            createdAt: "2026-04-23T00:00:00.000Z",
            enabled: true,
            id: "card-hide",
            name: "숨김 카드",
            updatedAt: "2026-04-23T00:00:00.000Z"
          },
          {
            createdAt: "2026-04-23T00:00:01.000Z",
            enabled: true,
            id: "card-unhide",
            name: "예외 카드",
            updatedAt: "2026-04-23T00:00:01.000Z"
          }
        ],
        enabled: true,
        id: "profile-1",
        matchers: ["*://example.com/*"],
        name: "example.com",
        rules: [
          {
            cardId: "card-hide",
            cardName: "숨김 카드",
            createdAt: "2026-04-23T00:00:00.000Z",
            frameScope: null,
            mode: "hide",
            selector: ".ad"
          },
          {
            cardId: "card-unhide",
            cardName: "예외 카드",
            createdAt: "2026-04-23T00:00:01.000Z",
            frameScope: null,
            mode: "unhide",
            selector: ".allowed"
          }
        ],
        sourceTemplateSlug: null,
        updatedAt: "2026-04-23T00:00:00.000Z"
      }
    ]
  });

  const profile = store.profiles[0];
  if (!profile) {
    throw new Error("expected normalized profile");
  }
  assert.equal(profile.rules.length, 2);
  assert.equal(profile.rules.filter((rule) => rule.mode === "hide").length, 1);
  assert.equal(profile.rules.filter((rule) => rule.mode === "unhide").length, 1);
});

void test("networkRuleToDnrRule converts supported AdGuard network filters to MV3 dynamic rules", () => {
  const parsed = parseFilterList(`
||ads.example^$script,image,third-party,domain=naver.com|news.naver.com
@@||safe.ads.example^$image,important
||tracker.example^$redirect=noop.txt
  `);
  const networkRules = parsed.rules.filter((rule) => rule.kind === "network");
  const firstRule = networkRules[0];
  const allowRule = networkRules[1];
  const unsupportedRule = networkRules[2];

  assert.ok(firstRule);
  assert.ok(allowRule);
  assert.ok(unsupportedRule);

  const converted = networkRuleToDnrRule(firstRule, 1);
  const convertedAllow = networkRuleToDnrRule(allowRule, 2);
  const convertedUnsupported = networkRuleToDnrRule(unsupportedRule, 3);

  assert.deepEqual(converted, {
    raw: "||ads.example^$script,image,third-party,domain=naver.com|news.naver.com",
    reason: null,
    rule: {
      id: 1,
      priority: 1,
      action: {
        type: "block"
      },
      condition: {
        domainType: "thirdParty",
        initiatorDomains: ["naver.com", "news.naver.com"],
        resourceTypes: ["script", "image"],
        urlFilter: "||ads.example^"
      }
    }
  });
  assert.deepEqual(convertedAllow.rule, {
    id: 2,
    priority: 3,
    action: {
      type: "allow"
    },
    condition: {
      resourceTypes: ["image"],
      urlFilter: "||safe.ads.example^"
    }
  });
  assert.equal(convertedUnsupported.rule, null);
  assert.equal(convertedUnsupported.reason, "unsupported network modifier: redirect");
});

void test("resolveActiveTab keeps a stored key when it is valid", () => {
  assert.equal(
    resolveActiveTab("network", ["selector", "network", "template"]),
    "network"
  );
});

void test("resolveActiveTab falls back to the first key when stored is missing or invalid", () => {
  assert.equal(resolveActiveTab(null, ["selector", "text"]), "selector");
  assert.equal(resolveActiveTab("bogus", ["selector", "text"]), "selector");
  assert.equal(resolveActiveTab(undefined, ["selector", "text"]), "selector");
});
