(() => {
  const THEME_KEY = "pos-theme"
  const THEMES = new Set(["default-light", "nature-light", "nature-dark", "caffeine-light", "caffeine-dark", "bold-tech-light", "bold-tech-dark", "doom-64-light", "doom-64-dark"])
  const LEGACY_THEMES = {default: "default-light", nature: "nature-light", "default-dark": "default-light"}

  function getTheme() {
    try {
      const savedTheme = localStorage.getItem(THEME_KEY)
      return THEMES.has(savedTheme) ? savedTheme : LEGACY_THEMES[savedTheme] || "default-light"
    } catch {
      return "default-light"
    }
  }

  function setTheme(theme) {
    const nextTheme = THEMES.has(theme) ? theme : "default-light"
    const mode = nextTheme.endsWith("-dark") ? "dark" : "light"
    const family = nextTheme.replace(/-(light|dark)$/, "")
    document.documentElement.classList.toggle("theme-nature", family === "nature")
    document.documentElement.classList.toggle("theme-caffeine", family === "caffeine")
    document.documentElement.classList.toggle("theme-bold-tech", family === "bold-tech")
    document.documentElement.classList.toggle("theme-doom-64", family === "doom-64")
    document.documentElement.classList.toggle("dark", mode === "dark")
    try {
      localStorage.setItem(THEME_KEY, nextTheme)
    } catch {
      /* Storage may be unavailable in private contexts. */
    }
    return nextTheme
  }

  function syncThemePicker(menu, selectedTheme) {
    menu.querySelectorAll("[data-theme]").forEach(button => {
      button.setAttribute("aria-current", String(button.dataset.theme === selectedTheme))
    })
  }

  function initializeThemePicker(menu) {
    if (!menu) return

    syncThemePicker(menu, setTheme(getTheme()))
    menu.addEventListener("click", event => {
      const button = event.target.closest("[data-theme]")
      if (!button) return
      syncThemePicker(menu, setTheme(button.dataset.theme))
      menu.open = false
    })
  }

  document.querySelectorAll(".sidebar-theme-selector").forEach(initializeThemePicker)

  document.addEventListener("click", event => {
    if (!event.target.closest("[data-theme-toggle]")) return
    const currentTheme = getTheme()
    const family = currentTheme.replace(/-(light|dark)$/, "")
    setTheme(`${family}-${currentTheme.endsWith("-dark") ? "light" : "dark"}`)
  })

  document.addEventListener("input", event => {
    if (!event.target.matches("[data-user-search]")) return
    const query = event.target.value.trim().toLowerCase()
    document.querySelectorAll("[data-user-row]").forEach(row => {
      row.hidden = query !== "" && !row.dataset.search.includes(query)
    })
  })

  document.addEventListener("click", event => {
    const toggle = event.target.closest("[data-dashboard-sidebar-toggle]")
    if (!toggle) return

    const shell = toggle.closest(".dashboard-shell")
    if (!shell) return

    const collapsed = shell.classList.toggle("is-sidebar-collapsed")
    toggle.setAttribute("aria-expanded", String(!collapsed))
    toggle.setAttribute("aria-label", collapsed ? "Expand navigation" : "Collapse navigation")
  })
})()
