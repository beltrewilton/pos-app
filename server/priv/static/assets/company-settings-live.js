(() => {
  const MAX_BYTES = 10 * 1024 * 1024

  const within = target => target.closest("#company-settings-live")
  const logoParts = target => {
    const field = target.closest(".store-logo-field")
    if (!field) return {}
    return {field, dropzone: field.querySelector(".store-logo-dropzone"), input: field.querySelector('input[type="file"]'), raw: field.querySelector(".store-logo-value"), preview: field.querySelector(".store-logo-preview"), help: field.querySelector(".field-description")}
  }
  const clear = ({raw, preview}) => {
    if (raw) raw.value = ""
    if (preview) { preview.hidden = true; preview.removeAttribute("src") }
  }
  const prepare = async (target, file) => {
    const parts = logoParts(target)
    const {dropzone, raw, preview, help} = parts
    if (!dropzone || !raw || !preview || !help) return
    if (!file || !file.type.startsWith("image/")) {
      clear(parts); dropzone.dataset.imageInvalid = "true"; help.textContent = "Choose a valid image before saving."; return
    }
    if (file.size > MAX_BYTES) {
      clear(parts); dropzone.dataset.imageInvalid = "true"; help.textContent = "Image must be 10 MB or smaller."; return
    }
    dropzone.dataset.preparing = "true"; help.textContent = "Resizing image…"
    const objectUrl = URL.createObjectURL(file)
    try {
      const image = new Image(); image.src = objectUrl; await image.decode()
      const width = 100; const height = Math.max(1, Math.round(image.naturalHeight * (width / image.naturalWidth)))
      const canvas = document.createElement("canvas"); canvas.width = width; canvas.height = height
      const context = canvas.getContext("2d"); context.imageSmoothingEnabled = true; context.imageSmoothingQuality = "high"; context.drawImage(image, 0, 0, width, height)
      const blob = await new Promise((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error("Image conversion failed")), "image/jpeg", 0.82))
      const dataUrl = await new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.onerror = () => reject(reader.error); reader.readAsDataURL(blob) })
      raw.value = dataUrl; delete dropzone.dataset.imageInvalid; preview.src = dataUrl; preview.hidden = false; help.textContent = `${file.name} resized to ${width} × ${height}px and ready as Base64.`
    } catch (error) {
      clear(parts); dropzone.dataset.imageInvalid = "true"; help.textContent = `Image could not be prepared: ${error.message}`
    } finally { URL.revokeObjectURL(objectUrl); delete dropzone.dataset.preparing }
  }

  window.CompanySettingsHook = {
    mounted() {
      this.focusTitle = () => requestAnimationFrame(() => this.el.querySelector("#company-settings-title")?.focus())
      this.focusTitle()
      this.onClick = event => {
        const remove = event.target.closest("[data-remove-store-logo]")
        if (remove && within(remove)) {
          const parts = logoParts(remove); clear(parts); parts.input.value = ""; parts.help.textContent = "Logo will be removed when you save."; remove.remove(); return
        }
        const action = event.target.closest("[data-company-settings-confirm]")
        if (action && within(action) && window.confirm(action.dataset.companySettingsConfirm)) this.pushEvent("delete", {kind: action.dataset.deleteKind, id: action.dataset.deleteId})
      }
      this.onChange = event => { if (event.target.matches(".store-logo-field input[type='file']") && within(event.target)) prepare(event.target, event.target.files[0]) }
      this.onDrag = event => { const {dropzone} = logoParts(event.target); if (dropzone && within(dropzone)) { event.preventDefault(); dropzone.dataset.dragging = "true"; if (event.type === "dragover") event.dataTransfer.dropEffect = "copy" } }
      this.onDragLeave = event => { const {dropzone} = logoParts(event.target); if (dropzone && within(dropzone)) delete dropzone.dataset.dragging }
      this.onDrop = event => { const {dropzone} = logoParts(event.target); if (dropzone && within(dropzone)) { event.preventDefault(); delete dropzone.dataset.dragging; prepare(event.target, event.dataTransfer.files[0]) } }
      this.onKeydown = event => { const {dropzone, input} = logoParts(event.target); if (dropzone && event.target === dropzone && ["Enter", " "].includes(event.key)) { event.preventDefault(); input.click() } }
      this.onSubmit = event => { if (!event.target.matches(".company-setting-form")) return; const dropzone = event.target.querySelector(".store-logo-dropzone"); const help = event.target.querySelector(".store-logo-field .field-description"); if (dropzone?.dataset.preparing === "true") { event.preventDefault(); event.stopImmediatePropagation(); help.textContent = "Image is still being prepared. Please wait." } if (dropzone?.dataset.imageInvalid === "true") { event.preventDefault(); event.stopImmediatePropagation(); help.textContent = "Choose a valid image or remove it before saving." } }
      this.el.addEventListener("click", this.onClick); this.el.addEventListener("change", this.onChange); this.el.addEventListener("dragenter", this.onDrag); this.el.addEventListener("dragover", this.onDrag); this.el.addEventListener("dragleave", this.onDragLeave); this.el.addEventListener("drop", this.onDrop); this.el.addEventListener("keydown", this.onKeydown); this.el.addEventListener("submit", this.onSubmit, true)
    },
    updated() { this.focusTitle?.() },
    destroyed() { this.el.removeEventListener("click", this.onClick); this.el.removeEventListener("change", this.onChange); this.el.removeEventListener("dragenter", this.onDrag); this.el.removeEventListener("dragover", this.onDrag); this.el.removeEventListener("dragleave", this.onDragLeave); this.el.removeEventListener("drop", this.onDrop); this.el.removeEventListener("keydown", this.onKeydown); this.el.removeEventListener("submit", this.onSubmit, true) }
  }
})()
