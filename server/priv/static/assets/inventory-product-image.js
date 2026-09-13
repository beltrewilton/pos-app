(() => {
  const MAX_BYTES = 10 * 1024 * 1024
  const selector = "#product-dialog"
  const uploadTargets = {
    product: {
      input: "#product-image",
      raw: "#product-image-raw",
      preview: "#product-image-preview",
      help: "#product-image-help",
      dropzone: "#product-image-dropzone",
      form: "#product-form",
      width: 100,
      helpText: "Drop an image here or choose a file (max 10 MB). It will be resized and stored as Base64."
    },
    companyLogo: {
      input: "#company-logo",
      raw: "#company-brand-logo",
      preview: "#company-logo-preview",
      help: "#company-logo-help",
      dropzone: "#company-logo-dropzone",
      form: "#company-logo-form",
      width: 360,
      preserveTransparency: true,
      helpText: "Drop an image here or choose a file (max 10 MB). It will be resized and stored as Base64."
    }
  }

  const dialog = () => document.querySelector(selector)
  const activateOperationsHeader = fixed => {
    if (!fixed || fixed.dataset.operationsFixedObserved) return
    fixed.dataset.operationsFixedObserved = "true"
    const screen = fixed.closest(".operations-screen")
    if (!screen) return
    const update = () => screen.style.setProperty("--operations-fixed-height", `${fixed.offsetHeight}px`)
    update()
    new ResizeObserver(update).observe(fixed)
  }
  const activateDialog = root => {
    if (!root || root.dataset.tauriDialogInitialized) return
    root.dataset.tauriDialogInitialized = "true"
    root.showModal()
    root.addEventListener("cancel", event => event.preventDefault())
    root.addEventListener("click", event => {
      if (event.target === root) event.preventDefault()
    })
  }
  const elements = (target = uploadTargets.product) => {
    const root = dialog()
    const scope = document.querySelector(target.dropzone)?.closest("form") || root
    if (!scope) return {}
    return {
      root: scope,
      input: scope.querySelector(target.input),
      raw: scope.querySelector(target.raw),
      preview: scope.querySelector(target.preview),
      help: scope.querySelector(target.help),
      dropzone: scope.querySelector(target.dropzone)
    }
  }

  const clearPreview = ({raw, preview}) => {
    raw.value = ""
    preview.hidden = true
    preview.removeAttribute("src")
  }

  const targetForElement = element => Object.values(uploadTargets).find(target => element?.matches?.(target.input) || element?.matches?.(target.dropzone) || element?.closest?.(target.dropzone))
  const hasTransparentPixels = context => {
    const {width, height} = context.canvas
    const data = context.getImageData(0, 0, width, height).data
    for (let index = 3; index < data.length; index += 4) {
      if (data[index] < 255) return true
    }
    return false
  }
  const outputType = (file, context, target) => {
    if (target.preserveTransparency && (file.type === "image/png" || hasTransparentPixels(context))) return "image/png"
    return "image/jpeg"
  }
  const canvasBlob = (canvas, type) => new Promise((resolve, reject) => {
    const quality = type === "image/jpeg" ? 0.82 : undefined
    canvas.toBlob(value => value ? resolve(value) : reject(new Error("Image conversion failed")), type, quality)
  })

  const prepare = async (file, target = uploadTargets.product) => {
    const {raw, preview, help, dropzone} = elements(target)
    if (!raw || !preview || !help || !dropzone) return
    if (!file) {
      clearPreview({raw, preview})
      delete dropzone.dataset.imageInvalid
      help.textContent = target.helpText
      return
    }
    if (!file.type.startsWith("image/")) {
      clearPreview({raw, preview})
      dropzone.dataset.imageInvalid = "true"
      help.textContent = "Choose a valid image before saving."
      return
    }
    if (file.size > MAX_BYTES) {
      clearPreview({raw, preview})
      dropzone.dataset.imageInvalid = "true"
      help.textContent = "Image must be 10 MB or smaller."
      return
    }

    dropzone.dataset.preparing = "true"
    help.textContent = "Resizing image…"
    const objectUrl = URL.createObjectURL(file)
    try {
      const image = new Image()
      image.src = objectUrl
      await image.decode()
      const width = target.width
      const height = Math.max(1, Math.round(image.naturalHeight * (width / image.naturalWidth)))
      const canvas = document.createElement("canvas")
      canvas.width = width
      canvas.height = height
      const context = canvas.getContext("2d")
      context.imageSmoothingEnabled = true
      context.imageSmoothingQuality = "high"
      context.drawImage(image, 0, 0, width, height)
      const type = outputType(file, context, target)
      const blob = await canvasBlob(canvas, type)
      const dataUrl = await new Promise((resolve, reject) => {
        const reader = new FileReader()
        reader.onload = () => resolve(reader.result)
        reader.onerror = () => reject(reader.error)
        reader.readAsDataURL(blob)
      })
      raw.value = dataUrl
      delete dropzone.dataset.imageInvalid
      preview.src = dataUrl
      preview.hidden = false
      help.textContent = `${file.name} resized to ${width} × ${height}px and ready as Base64.`
    } catch (error) {
      clearPreview({raw, preview})
      dropzone.dataset.imageInvalid = "true"
      help.textContent = `Image could not be prepared: ${error.message}`
    } finally {
      URL.revokeObjectURL(objectUrl)
      delete dropzone.dataset.preparing
    }
  }

  document.addEventListener("change", event => {
    const target = targetForElement(event.target)
    if (target && event.target.matches(target.input)) prepare(event.target.files[0], target)
  })
  document.addEventListener("dragenter", event => {
    const target = targetForElement(event.target)
    const {dropzone} = elements(target)
    if (dropzone && (event.target === dropzone || dropzone.contains(event.target))) { event.preventDefault(); dropzone.dataset.dragging = "true" }
  })
  document.addEventListener("dragover", event => {
    const target = targetForElement(event.target)
    const {dropzone} = elements(target)
    if (dropzone && (event.target === dropzone || dropzone.contains(event.target))) { event.preventDefault(); event.dataTransfer.dropEffect = "copy"; dropzone.dataset.dragging = "true" }
  })
  document.addEventListener("dragleave", event => {
    const target = targetForElement(event.target)
    const {dropzone} = elements(target)
    if (dropzone && (event.target === dropzone || dropzone.contains(event.target))) delete dropzone.dataset.dragging
  })
  document.addEventListener("drop", event => {
    const target = targetForElement(event.target)
    const {dropzone} = elements(target)
    if (dropzone && (event.target === dropzone || dropzone.contains(event.target))) { event.preventDefault(); delete dropzone.dataset.dragging; prepare(event.dataTransfer.files[0], target) }
  })
  document.addEventListener("keydown", event => {
    const target = targetForElement(event.target)
    const {dropzone, input} = elements(target)
    if (dropzone && event.target === dropzone && ["Enter", " "].includes(event.key)) { event.preventDefault(); input.click() }
  })
  document.addEventListener("submit", event => {
    if (event.target.matches("#workspace-setup-form")) {
      const button = event.target.querySelector("button[type='submit']")
      const label = event.target.querySelector("[data-submit-label]")
      if (button) button.disabled = true
      if (label) label.textContent = event.target.dataset.submittingLabel || "Creating workspace..."
      event.target.setAttribute("aria-busy", "true")
      event.target.dataset.submitting = "true"
      return
    }

    const target = Object.values(uploadTargets).find(uploadTarget => event.target.matches(uploadTarget.form))
    if (!target) return
    const {dropzone, help} = elements(target)
    if (dropzone?.dataset.preparing === "true") {
      event.preventDefault()
      help.textContent = "Image is still being prepared. Please wait."
    }
    if (dropzone?.dataset.imageInvalid === "true") {
      event.preventDefault()
      help.textContent = "Choose a valid image or remove it before saving."
    }
  }, true)
  document.querySelectorAll(".operations-fixed").forEach(activateOperationsHeader)
  activateDialog(dialog())
  new MutationObserver(() => {
    document.querySelectorAll(".operations-fixed").forEach(activateOperationsHeader)
    activateDialog(dialog())
  }).observe(document.body, {childList: true, subtree: true})
})()
