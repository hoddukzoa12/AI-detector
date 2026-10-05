export type FilterImportRule =
  | CosmeticFilterImportRule
  | CosmeticExceptionFilterImportRule
  | TextFilterImportRule
  | NetworkFilterImportRule
  | UnsupportedFilterImportRule;

export type CosmeticFilterImportRule = {
  kind: "cosmetic";
  domains: string[];
  raw: string;
  selector: string;
};

export type CosmeticExceptionFilterImportRule = {
  kind: "cosmetic-exception";
  domains: string[];
  raw: string;
  selector: string;
};

export type TextFilterImportRule = {
  kind: "text";
  domains: string[];
  raw: string;
  selector: string;
  text: string;
};

export type NetworkFilterImportRule = {
  kind: "network";
  allow: boolean;
  modifiers: string[];
  pattern: string;
  raw: string;
};

export type UnsupportedFilterImportRule = {
  kind: "unsupported";
  reason: string;
  raw: string;
};

export type FilterImportSummary = {
  cosmeticCount: number;
  cosmeticExceptionCount: number;
  networkCount: number;
  textCount: number;
  unsupportedCount: number;
};

export type ParsedFilterList = {
  rules: FilterImportRule[];
  summary: FilterImportSummary;
};

export type PortableDnrResourceType =
  | "main_frame"
  | "sub_frame"
  | "stylesheet"
  | "script"
  | "image"
  | "font"
  | "object"
  | "xmlhttprequest"
  | "ping"
  | "media"
  | "websocket"
  | "other";

export type PortableDnrRule = {
  id: number;
  priority: number;
  action: {
    type: "allow" | "block";
  };
  condition: {
    domainType?: "firstParty" | "thirdParty";
    excludedInitiatorDomains?: string[];
    excludedResourceTypes?: PortableDnrResourceType[];
    initiatorDomains?: string[];
    isUrlFilterCaseSensitive?: boolean;
    regexFilter?: string;
    resourceTypes?: PortableDnrResourceType[];
    urlFilter?: string;
  };
};

export type DnrConversionResult = {
  raw: string;
  reason: string | null;
  rule: PortableDnrRule | null;
};

const COSMETIC_MARKERS = ["#@?#", "#?#", "#@#", "##"] as const;
const DNR_RESOURCE_TYPE_BY_MODIFIER: Record<string, PortableDnrResourceType[]> = {
  document: ["main_frame"],
  font: ["font"],
  image: ["image"],
  media: ["media"],
  object: ["object"],
  other: ["other"],
  ping: ["ping"],
  script: ["script"],
  stylesheet: ["stylesheet"],
  subdocument: ["sub_frame"],
  websocket: ["websocket"],
  xmlhttprequest: ["xmlhttprequest"]
};
const UNSUPPORTED_NETWORK_MODIFIERS = new Set([
  "badfilter",
  "csp",
  "cookie",
  "elemhide",
  "genericblock",
  "generichide",
  "header",
  "permissions",
  "popup",
  "redirect",
  "redirect-rule",
  "removeheader",
  "removeparam",
  "replace"
]);

function stripComment(rawLine: string): string {
  const trimmed = rawLine.trim();
  if (!trimmed || trimmed.startsWith("!") || trimmed.startsWith("[")) {
    return "";
  }

  return trimmed;
}

function splitDomains(rawDomains: string): string[] {
  return rawDomains
    .split(",")
    .map((domain) => domain.trim())
    .filter((domain) => domain.length > 0 && !domain.startsWith("~"));
}

function unquote(value: string): string {
  const trimmed = value.trim();
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.slice(1, -1);
  }

  return trimmed;
}

function extractTextCondition(selector: string): { selector: string; text: string } | null {
  const patterns = [
    /:contains\((?<text>[^)]*)\)/i,
    /:-abp-contains\((?<text>[^)]*)\)/i,
    /:has-text\((?<text>[^)]*)\)/i
  ];

  for (const pattern of patterns) {
    const match = selector.match(pattern);
    const text = match?.groups?.text;
    if (!match || typeof text !== "string") {
      continue;
    }

    const cleanedSelector = selector.replace(match[0], "").trim() || "*";
    const cleanedText = unquote(text);
    if (!cleanedText) {
      return null;
    }

    return {
      selector: cleanedSelector,
      text: cleanedText
    };
  }

  return null;
}

function parseCosmeticRule(line: string): FilterImportRule | null {
  const marker = COSMETIC_MARKERS.find((candidate) => line.includes(candidate));
  if (!marker) {
    return null;
  }

  const markerIndex = line.indexOf(marker);
  const rawDomains = line.slice(0, markerIndex);
  const selector = line.slice(markerIndex + marker.length).trim();
  if (!selector) {
    return {
      kind: "unsupported",
      raw: line,
      reason: "empty cosmetic selector"
    };
  }

  const domains = splitDomains(rawDomains);
  const textCondition = extractTextCondition(selector);
  if (textCondition && (marker === "#?#" || marker === "##")) {
    return {
      kind: "text",
      domains,
      raw: line,
      selector: textCondition.selector,
      text: textCondition.text
    };
  }

  if (marker === "#@#" || marker === "#@?#") {
    return {
      kind: "cosmetic-exception",
      domains,
      raw: line,
      selector
    };
  }

  if (marker === "#?#") {
    return {
      kind: "unsupported",
      raw: line,
      reason: "extended cosmetic rule without supported text condition"
    };
  }

  return {
    kind: "cosmetic",
    domains,
    raw: line,
    selector
  };
}

function parseNetworkRule(line: string): FilterImportRule {
  const allow = line.startsWith("@@");
  const body = allow ? line.slice(2) : line;
  const [pattern = "", modifierText = ""] = body.split("$", 2);
  const modifiers = modifierText
    ? modifierText.split(",").map((modifier) => modifier.trim()).filter((modifier) => modifier.length > 0)
    : [];

  if (!pattern.trim()) {
    return {
      kind: "unsupported",
      raw: line,
      reason: "empty network pattern"
    };
  }

  return {
    kind: "network",
    allow,
    modifiers,
    pattern: pattern.trim(),
    raw: line
  };
}

export function parseFilterRule(rawLine: string): FilterImportRule | null {
  const line = stripComment(rawLine);
  if (!line) {
    return null;
  }

  const cosmetic = parseCosmeticRule(line);
  if (cosmetic) {
    return cosmetic;
  }

  if (line.includes("#%#") || line.includes("#$#")) {
    return {
      kind: "unsupported",
      raw: line,
      reason: "scriptlet/html injection rules are not imported"
    };
  }

  return parseNetworkRule(line);
}

export function parseFilterList(text: string): ParsedFilterList {
  const rules = text
    .split(/\r?\n/)
    .map((line) => parseFilterRule(line))
    .filter((rule): rule is FilterImportRule => rule !== null);

  return {
    rules,
    summary: summarizeFilterImport(rules)
  };
}

export function summarizeFilterImport(rules: FilterImportRule[]): FilterImportSummary {
  return {
    cosmeticCount: rules.filter((rule) => rule.kind === "cosmetic").length,
    cosmeticExceptionCount: rules.filter((rule) => rule.kind === "cosmetic-exception").length,
    networkCount: rules.filter((rule) => rule.kind === "network").length,
    textCount: rules.filter((rule) => rule.kind === "text").length,
    unsupportedCount: rules.filter((rule) => rule.kind === "unsupported").length
  };
}

export function domainsToMatchers(domains: string[]): string[] {
  return domains.length > 0
    ? domains.map((domain) => `*://${domain.replace(/^\|\|/, "").replace(/\^$/, "")}/*`)
    : ["*://*/*"];
}

function uniqueResourceTypes(values: PortableDnrResourceType[]): PortableDnrResourceType[] {
  return Array.from(new Set(values));
}

function parseDomainModifier(value: string): { included: string[]; excluded: string[] } {
  const included: string[] = [];
  const excluded: string[] = [];

  for (const domain of value.split("|")) {
    const trimmed = domain.trim().toLowerCase();
    if (!trimmed) {
      continue;
    }

    if (trimmed.startsWith("~")) {
      const excludedDomain = trimmed.slice(1);
      if (excludedDomain) {
        excluded.push(excludedDomain);
      }
      continue;
    }

    included.push(trimmed);
  }

  return { included, excluded };
}

function normalizeNetworkPattern(pattern: string): { regexFilter?: string; urlFilter?: string; reason?: string } {
  const trimmed = pattern.trim();
  if (!trimmed) {
    return { reason: "empty network pattern" };
  }

  if (trimmed.startsWith("/") && trimmed.endsWith("/") && trimmed.length > 2) {
    return { regexFilter: trimmed.slice(1, -1) };
  }

  return { urlFilter: trimmed };
}

export function networkRuleToDnrRule(rule: NetworkFilterImportRule, id: number): DnrConversionResult {
  const pattern = normalizeNetworkPattern(rule.pattern);
  if (pattern.reason) {
    return {
      raw: rule.raw,
      reason: pattern.reason,
      rule: null
    };
  }

  const resourceTypes: PortableDnrResourceType[] = [];
  const excludedResourceTypes: PortableDnrResourceType[] = [];
  const initiatorDomains: string[] = [];
  const excludedInitiatorDomains: string[] = [];
  let domainType: "firstParty" | "thirdParty" | undefined;
  let isUrlFilterCaseSensitive = false;
  let priority = rule.allow ? 2 : 1;

  for (const rawModifier of rule.modifiers) {
    const modifier = rawModifier.trim().toLowerCase();
    const negated = modifier.startsWith("~");
    const normalizedModifier = negated ? modifier.slice(1) : modifier;

    if (!normalizedModifier) {
      continue;
    }

    if (normalizedModifier.startsWith("domain=")) {
      const { included, excluded } = parseDomainModifier(normalizedModifier.slice("domain=".length));
      initiatorDomains.push(...included);
      excludedInitiatorDomains.push(...excluded);
      continue;
    }

    const modifierName = normalizedModifier.split("=", 1)[0] ?? normalizedModifier;

    if (UNSUPPORTED_NETWORK_MODIFIERS.has(modifierName)) {
      return {
        raw: rule.raw,
        reason: `unsupported network modifier: ${modifierName}`,
        rule: null
      };
    }

    if (modifierName === "important") {
      priority = Math.max(priority, 3);
      continue;
    }

    if (modifierName === "match-case") {
      isUrlFilterCaseSensitive = true;
      continue;
    }

    if (modifierName === "third-party") {
      domainType = negated ? "firstParty" : "thirdParty";
      continue;
    }

    if (modifierName === "first-party") {
      domainType = negated ? "thirdParty" : "firstParty";
      continue;
    }

    const mappedResourceTypes = DNR_RESOURCE_TYPE_BY_MODIFIER[modifierName];
    if (mappedResourceTypes) {
      if (negated) {
        excludedResourceTypes.push(...mappedResourceTypes);
      } else {
        resourceTypes.push(...mappedResourceTypes);
      }
      continue;
    }

    return {
      raw: rule.raw,
      reason: `unsupported network modifier: ${modifierName}`,
      rule: null
    };
  }

  const condition: PortableDnrRule["condition"] = {
    ...pattern
  };
  const uniqueIncludedResources = uniqueResourceTypes(resourceTypes);
  const uniqueExcludedResources = uniqueResourceTypes(excludedResourceTypes);

  if (uniqueIncludedResources.length > 0) {
    condition.resourceTypes = uniqueIncludedResources;
  } else if (uniqueExcludedResources.length > 0) {
    condition.excludedResourceTypes = uniqueExcludedResources;
  }

  if (domainType) {
    condition.domainType = domainType;
  }

  if (initiatorDomains.length > 0) {
    condition.initiatorDomains = Array.from(new Set(initiatorDomains));
  }

  if (excludedInitiatorDomains.length > 0) {
    condition.excludedInitiatorDomains = Array.from(new Set(excludedInitiatorDomains));
  }

  if (isUrlFilterCaseSensitive) {
    condition.isUrlFilterCaseSensitive = true;
  }

  return {
    raw: rule.raw,
    reason: null,
    rule: {
      id,
      priority,
      action: {
        type: rule.allow ? "allow" : "block"
      },
      condition
    }
  };
}

export function networkRulesToDnrRules(rules: NetworkFilterImportRule[], startId: number): DnrConversionResult[] {
  return rules.map((rule, index) => networkRuleToDnrRule(rule, startId + index));
}
