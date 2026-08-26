(() => {
  const root = document.documentElement
  const savedTheme = localStorage.getItem("retaily-theme")

  if (savedTheme === "dark" || (!savedTheme && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
    root.classList.add("dark")
  }

  document.addEventListener("click", event => {
    if (!event.target.closest("[data-theme-toggle]")) return
    root.classList.toggle("dark")
    localStorage.setItem("retaily-theme", root.classList.contains("dark") ? "dark" : "light")
  })

  document.addEventListener("input", event => {
    if (!event.target.matches("[data-user-search]")) return
    const query = event.target.value.trim().toLowerCase()
    document.querySelectorAll("[data-user-row]").forEach(row => {
      row.hidden = query !== "" && !row.dataset.search.includes(query)
    })
  })
})()
