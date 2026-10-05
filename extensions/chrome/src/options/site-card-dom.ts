export type SiteCardShell = {
  card: HTMLElement;
  header: HTMLDivElement;
  headingWrap: HTMLDivElement;
  title: HTMLHeadingElement;
  subtitle: HTMLParagraphElement;
};

export function createSiteCardShell(titleText: string, subtitleText: string): SiteCardShell {
  const card = document.createElement("section");
  card.className = "options__site-card";

  const header = document.createElement("div");
  header.className = "options__site-header";

  const headingWrap = document.createElement("div");
  const title = document.createElement("h2");
  title.className = "options__site-title";
  title.textContent = titleText;

  const subtitle = document.createElement("p");
  subtitle.className = "options__site-subtitle";
  subtitle.textContent = subtitleText;

  return { card, header, headingWrap, title, subtitle };
}

export function createSecondaryButton(label: string, onClick: () => Promise<void> | void): HTMLButtonElement {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = label;
  button.className = "options__secondary";
  button.addEventListener("click", () => {
    void onClick();
  });
  return button;
}

export type ProfileEditFields = {
  editWrap: HTMLDivElement;
  nameInput: HTMLInputElement;
  matcherEditor: HTMLTextAreaElement;
  matcherHint: HTMLUListElement;
};

export function createProfileEditFields(nameValue: string, matchersText: string, matcherHintItems: string[]): ProfileEditFields {
  const editWrap = document.createElement("div");
  editWrap.className = "options__profile-edit";

  const nameInput = document.createElement("input");
  nameInput.className = "options__input";
  nameInput.type = "text";
  nameInput.value = nameValue;

  const matcherEditor = document.createElement("textarea");
  matcherEditor.className = "options__input options__matcher-editor";
  matcherEditor.value = matchersText;

  const matcherHint = document.createElement("ul");
  matcherHint.className = "options__matcher-list";
  matcherHint.innerHTML = matcherHintItems.join("");

  return { editWrap, nameInput, matcherEditor, matcherHint };
}
