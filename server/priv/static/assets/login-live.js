(() => {
  window.LoginScreenHook = {
    mounted() {
      this.focusCurrent = () => requestAnimationFrame(() => this.el.querySelector(this.el.dataset.phase === "store_selection" ? "#login-store" : "#login-identifier")?.focus())
      this.onSubmit = event => {
        if (event.target.matches("#login-form") && !event.target.reportValidity()) {
          event.preventDefault()
          event.stopImmediatePropagation()
        }
      }
      this.el.addEventListener("submit", this.onSubmit, true)
      this.focusCurrent()
      this.handleEvent("login:complete", async ({token, store_id}) => {
        const csrf = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
        try {
          const response = await fetch("/pos/login/session", {method: "POST", credentials: "same-origin", headers: {"content-type": "application/json", "x-csrf-token": csrf}, body: JSON.stringify({token, store_id})})
          if (!response.ok) throw new Error("session login failed")
          const {redirect_to} = await response.json()
          window.location.assign(redirect_to)
        } catch (_) { this.pushEvent("session_failed") }
      })
    },
    updated() { this.focusCurrent?.() },
    destroyed() { this.el.removeEventListener("submit", this.onSubmit, true) }
  }
})()
