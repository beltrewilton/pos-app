import { getLanguage, setLanguage, t } from "./i18n.js";

export function createLanguageSwitcher(element) {
  const sync = () => {
    const language = getLanguage();
    element.querySelectorAll("[data-language]").forEach((button) => {
      const selected = String(button.dataset.language === language);
      button.setAttribute("aria-current", selected);
      button.setAttribute("aria-pressed", selected);
    });
    element.querySelector("summary").setAttribute("aria-label", t("language.change"));
  };
  element.addEventListener("click", (event) => {
    const button = event.target.closest("[data-language]");
    if (!button) return;
    setLanguage(button.dataset.language);
    element.open = false;
  });
  element.querySelector("summary").setAttribute("aria-label", t("language.change"));
  sync();
  return { sync };
}
