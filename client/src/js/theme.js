const THEME_KEY = "pos-theme";
const THEMES = new Set(["default-light", "nature-light", "nature-dark", "caffeine-light", "caffeine-dark", "bold-tech-light", "bold-tech-dark", "doom-64-light", "doom-64-dark"]);
const LEGACY_THEMES = { default: "default-light", nature: "nature-light", "default-dark": "default-light" };

export function getTheme() {
  try {
    const savedTheme = localStorage.getItem(THEME_KEY);
    return THEMES.has(savedTheme) ? savedTheme : LEGACY_THEMES[savedTheme] || "default-light";
  } catch { return "default-light"; }
}

export function setTheme(theme) {
  const nextTheme = THEMES.has(theme) ? theme : "default-light";
  const mode = nextTheme.endsWith("-dark") ? "dark" : "light";
  const family = nextTheme.replace(/-(light|dark)$/, "");
  document.documentElement.classList.toggle("theme-nature", family === "nature");
  document.documentElement.classList.toggle("theme-caffeine", family === "caffeine");
  document.documentElement.classList.toggle("theme-bold-tech", family === "bold-tech");
  document.documentElement.classList.toggle("theme-doom-64", family === "doom-64");
  document.documentElement.classList.toggle("dark", mode === "dark");
  try { localStorage.setItem(THEME_KEY, nextTheme); } catch { /* Storage may be unavailable in private contexts. */ }
  return nextTheme;
}

export function initializeThemePicker(menu) {
  const applySelection = (theme) => {
    const selectedTheme = setTheme(theme);
    menu.querySelectorAll("[data-theme]").forEach((button) => button.setAttribute("aria-current", String(button.dataset.theme === selectedTheme)));
  };
  applySelection(getTheme());
  menu.addEventListener("click", (event) => {
    const button = event.target.closest("[data-theme]");
    if (!button) return;
    applySelection(button.dataset.theme);
    menu.open = false;
  });
}
