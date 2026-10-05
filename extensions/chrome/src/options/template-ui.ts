import { upsertProfileFromTemplate } from "../shared/storage.js";
import { readStore } from "../shared/storage.js";
import { DEFAULT_TEMPLATE_SERVER_URL, fetchTemplateJson, profileToTemplate } from "./template-server.js";
import type { RemoteTemplate, RemoteTemplateSummary } from "./template-server.js";
import { templateListElement, templateServerTokenElement, templateServerUrlElement, templateStatusElement } from "./elements.js";
import { requestRender } from "./render-bus.js";
import { createSecondaryButton } from "./site-card-dom.js";

export async function renderTemplates(): Promise<void> {
  const serverUrl = templateServerUrlElement.value.trim() || DEFAULT_TEMPLATE_SERVER_URL;
  const token = templateServerTokenElement.value;
  const store = await readStore();
  templateListElement.replaceChildren();

  try {
    const response = await fetchTemplateJson<{ ok: boolean; templates: RemoteTemplateSummary[] }>(serverUrl, token, "/templates");
    const templates = response.templates;
    templateStatusElement.textContent = `템플릿 서버 연결됨 · ${templates.length}개 템플릿`;

    if (templates.length === 0) {
      templateListElement.textContent = "템플릿이 아직 없습니다.";
      return;
    }

    const cards = templates.map((template) => {
      const card = document.createElement("section");
      card.className = "options__template-card";

      const title = document.createElement("h3");
      title.className = "options__template-title";
      title.textContent = template.name;

      const description = document.createElement("p");
      description.className = "options__template-description";
      description.textContent = template.description || "설명 없음";

      const meta = document.createElement("p");
      meta.className = "options__template-meta";
      meta.textContent = `slug ${template.slug} · matcher ${template.matcherCount}개 · 카드 ${template.cardCount}개 · 규칙 ${template.ruleCount}개`;

      const actions = document.createElement("div");
      actions.className = "options__template-actions";
      const linkedProfile = store.profiles.find((profile) => profile.sourceTemplateSlug === template.slug) ?? null;

      const applyButton = document.createElement("button");
      applyButton.type = "button";
      applyButton.textContent = "적용";
      applyButton.addEventListener("click", () => {
        void (async () => {
          const detail = await fetchTemplateJson<{ ok: boolean; template: RemoteTemplate }>(serverUrl, token, `/templates/${template.slug}`);
          await upsertProfileFromTemplate(detail.template);
          templateStatusElement.textContent = `${detail.template.name} 템플릿을 적용했습니다.`;
          await requestRender();
        })().catch((error: unknown) => {
          templateStatusElement.textContent = error instanceof Error ? error.message : "템플릿 적용에 실패했습니다.";
        });
      });

      const inspectButton = document.createElement("button");
      inspectButton.type = "button";
      inspectButton.textContent = "상세";
      inspectButton.className = "options__secondary";
      inspectButton.addEventListener("click", () => {
        void (async () => {
          const detail = await fetchTemplateJson<{ ok: boolean; template: RemoteTemplate }>(serverUrl, token, `/templates/${template.slug}`);
          templateStatusElement.textContent = JSON.stringify(detail.template, null, 2);
        })().catch((error: unknown) => {
          templateStatusElement.textContent = error instanceof Error ? error.message : "템플릿 상세 조회에 실패했습니다.";
        });
      });

      const updateButton = document.createElement("button");
      updateButton.type = "button";
      updateButton.textContent = linkedProfile ? "연결 프로필로 갱신" : "연결 프로필 없음";
      updateButton.className = "options__secondary";
      updateButton.disabled = !linkedProfile;
      updateButton.addEventListener("click", () => {
        if (!linkedProfile) {
          return;
        }
        void (async () => {
          await fetchTemplateJson<{ ok: boolean; template: RemoteTemplate }>(serverUrl, token, `/templates/${template.slug}`, {
            body: JSON.stringify(profileToTemplate(linkedProfile, template.slug, linkedProfile.name)),
            headers: {
              "content-type": "application/json"
            },
            method: "PUT"
          });
          templateStatusElement.textContent = `${template.name} 템플릿을 연결된 프로필 내용으로 갱신했습니다.`;
          await renderTemplates();
        })().catch((error: unknown) => {
          templateStatusElement.textContent = error instanceof Error ? error.message : "템플릿 갱신에 실패했습니다.";
        });
      });

      const deleteButton = createSecondaryButton("삭제", () => (async () => {
        await fetchTemplateJson<{ ok: boolean; slug: string }>(serverUrl, token, `/templates/${template.slug}`, {
          method: "DELETE"
        });
        templateStatusElement.textContent = `${template.name} 템플릿을 삭제했습니다.`;
        await renderTemplates();
      })().catch((error: unknown) => {
        templateStatusElement.textContent = error instanceof Error ? error.message : "템플릿 삭제에 실패했습니다.";
      }));

      actions.append(applyButton, inspectButton, updateButton, deleteButton);
      card.append(title, description, meta, actions);
      return card;
    });

    templateListElement.replaceChildren(...cards);
  } catch (error) {
    templateStatusElement.textContent = error instanceof Error
      ? `${error.message} · 템플릿 서버를 먼저 실행하세요.`
      : "템플릿 서버에 연결하지 못했습니다.";
    templateListElement.replaceChildren();
  }
}
