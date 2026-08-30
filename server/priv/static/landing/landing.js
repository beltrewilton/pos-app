(() => {
  if (!document.querySelector("[data-landing-page]")) return;
  if (window.__landingPageInitialized) return;
  window.__landingPageInitialized = true;

(function () {
  const faqData = [
    {
      question: "¿Qué es tigoo?",
      answer:
        "tigoo es una solución para gestionar ventas, inventario, clientes, compras y facturación desde un solo lugar."
    },
    {
      question: "¿Puedo usar tigoo en varias tiendas?",
      answer:
        "Sí. Puedes organizar existencias y operaciones por tienda y mantener una visión centralizada del negocio."
    },
    {
      question: "¿Puedo usar lectores de código de barras?",
      answer:
        "tigoo agiliza la búsqueda y venta de productos mediante códigos de barras cuando el equipo está configurado para ello."
    },
    {
      question: "¿Puedo imprimir recibos?",
      answer:
        "Sí. La solución contempla impresión de recibos en el flujo de venta y reimpresión desde las facturas."
    },
    {
      question: "¿Puedo gestionar inventario?",
      answer:
        "Sí. Consulta cantidades, movimientos, compras, ajustes y transferencias entre tiendas."
    },
    {
      question: "¿Puedo emitir facturación electrónica?",
      answer:
        "tigoo incorpora flujos de facturación orientados a la operación comercial en República Dominicana."
    },
    {
      question: "¿Puedo consultar mi negocio desde otro dispositivo?",
      answer:
        "Consulta ventas, productos e inventario desde computador, tablet o móvil sin perder de vista tu operación."
    }
  ];

  const plusSVG = `<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M9.78906 4.45312V15.7688" stroke="#737373" stroke-width="1.6163" stroke-linecap="round" stroke-linejoin="round" />
                <path d="M15.4466 10.1113H4.13086" stroke="#737373" stroke-width="1.6163" stroke-linecap="round" stroke-linejoin="round" />
            </svg>`;

  const minusSVG = `<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M15.4466 10.1113H4.13086" stroke="#737373" stroke-width="1.6163" stroke-linecap="round" stroke-linejoin="round" />
            </svg>`;

  const container = document.getElementById("faqList");
  if (!container) return;

  faqData.forEach((item, index) => {
    const isFirst = index === 0;
    const faqItem = document.createElement("div");
    faqItem.className = "faq-item";

    const button = document.createElement("button");
    button.className = "faq-toggle";

    const spanQuestion = document.createElement("span");
    spanQuestion.textContent = item.question;

    const spanPlus = document.createElement("span");
    spanPlus.className = "icon-plus";
    spanPlus.innerHTML = plusSVG;
    if (isFirst) spanPlus.style.display = "none";

    const spanMinus = document.createElement("span");
    spanMinus.className = "icon-minus";
    spanMinus.innerHTML = minusSVG;
    if (!isFirst) spanMinus.style.display = "none";

    button.appendChild(spanQuestion);
    button.appendChild(spanPlus);
    button.appendChild(spanMinus);

    const answerDiv = document.createElement("div");
    answerDiv.className = "faq-answer" + (isFirst ? " expanded" : "");
    answerDiv.textContent = item.answer;

    faqItem.appendChild(button);
    faqItem.appendChild(answerDiv);
    container.appendChild(faqItem);

    button._plus = spanPlus;
    button._minus = spanMinus;
    button._answer = answerDiv;
  });

  document.querySelectorAll(".faq-toggle").forEach((btn) => {
    btn.addEventListener("click", function (e) {
      const currentAnswer = this._answer;
      const currentPlus = this._plus;
      const currentMinus = this._minus;
      const isOpen = currentAnswer.classList.contains("expanded");

      document.querySelectorAll(".faq-answer").forEach((ans) => {
        ans.classList.remove("expanded");
      });
      document.querySelectorAll(".faq-toggle").forEach((b) => {
        b._plus.style.display = "inline";
        b._minus.style.display = "none";
      });

      if (!isOpen) {
        currentAnswer.classList.add("expanded");
        currentPlus.style.display = "none";
        currentMinus.style.display = "inline";
      }
    });
  });
})();

(function () {
  const track = document.getElementById("carouselTrack");
  const cardWidth = 300;
  const gap = 20;
  const totalWidth = cardWidth + gap;

  const videoSources = [
    "https://cdn.dribbble.com/userupload/47251901/file/e63022873002b6fad20950fd382dcc4a.mp4",
    "https://cdn.dribbble.com/userupload/43632609/file/large-173cdb1cfd56d5100c0e887971cf7fe5.mp4",
    "https://cdn.dribbble.com/userupload/40451540/file/original-548e206dd2e1d1ee20311b05b8201b73.mp4",
    "https://cdn.dribbble.com/userupload/44195616/file/original-d3d75f592a33c722cc8de01f90676e32.mp4",
    "https://cdn.dribbble.com/userupload/44133227/file/original-43aed8758ee4c58c821529ef40f7c427.mp4",
    "https://cdn.dribbble.com/userupload/46098225/file/2220b0825e1d35b019a1803ffc9c5e4a.mp4"
  ];

  const cardCount = videoSources.length;

  function createCard(index) {
    const div = document.createElement("div");
    div.className = "carousel-card";
    const video = document.createElement("video");
    video.src = videoSources[index];
    video.autoplay = true;
    video.loop = true;
    video.muted = true;
    video.playsInline = true;
    div.appendChild(video);
    return div;
  }

  for (let i = 0; i < 3; i++) {
    for (let j = 0; j < cardCount; j++) {
      track.appendChild(createCard(j));
    }
  }

  let position = 0;
  let direction = -1;
  let speed = 2;
  let lastScrollY = window.scrollY;

  window.addEventListener("scroll", function () {
    const currentScrollY = window.scrollY;
    if (currentScrollY > lastScrollY) {
      direction = -1;
    } else if (currentScrollY < lastScrollY) {
      direction = 1;
    }
    lastScrollY = currentScrollY;
  });

  function animate() {
    const step = direction * speed;
    position += step;
    const maxTranslate = -(cardCount * totalWidth);
    if (position < maxTranslate) {
      position += cardCount * totalWidth;
    } else if (position > 0) {
      position -= cardCount * totalWidth;
    }
    track.style.transform = `translateX(${position}px)`;
    requestAnimationFrame(animate);
  }
  animate();
})();

document.addEventListener("DOMContentLoaded", function () {
  const container = document.querySelector(".about-container");
  const section = document.querySelector("#about");
  if (!container || !section) return;

  const words = section.querySelectorAll(".about-word");
  if (!words.length) return;

  function updateWords() {
    const rect = container.getBoundingClientRect();
    const containerHeight = container.offsetHeight;
    const windowHeight = window.innerHeight;

    let progress = -rect.top / (containerHeight - windowHeight);
    progress = Math.min(1, Math.max(0, progress));

    words.forEach((word, index) => {
      const delay = (index + 1) / (words.length + 1);
      const threshold = delay * 0.9;

      if (progress >= threshold) {
        word.classList.add("active");
      } else {
        word.classList.remove("active");
      }
    });
  }

  window.addEventListener("scroll", updateWords, { passive: true });
  window.addEventListener("resize", updateWords);
  updateWords();
});

document.addEventListener("DOMContentLoaded", function () {
  const cards = document.querySelectorAll(".work-card");
  if (!cards.length) return;

  function handleScrollStack() {
    cards.forEach((card, index) => {
      const rect = card.getBoundingClientRect();
      const stickyTop = 120 + index * 20;

      if (rect.top <= stickyTop) {
        const distanceScrolled = stickyTop - rect.top;
        const progress = Math.min(1, distanceScrolled / 400);
        const scale = 1 - progress * 0.08;
        const rotate = index % 2 === 0 ? progress * -2 : progress * 2;
        const opacity = 1;

        card.style.transform = `scale(${scale}) rotate(${rotate}deg)`;
        card.style.opacity = opacity;
      } else {
        card.style.transform = "scale(1) rotate(0deg)";
        card.style.opacity = "1";
      }
    });
  }

  window.addEventListener("scroll", handleScrollStack, { passive: true });
  window.addEventListener("resize", handleScrollStack);
  handleScrollStack();
});

(function () {
  const navbar = document.querySelector(".navbar");
  if (!navbar) return;

  function handleNavbarScroll() {
    if (window.scrollY > 24) {
      navbar.classList.add("scrolled");
    } else {
      navbar.classList.remove("scrolled");
    }
  }

  window.addEventListener("scroll", handleNavbarScroll, { passive: true });
  handleNavbarScroll();
})();

const canvas = document.getElementById("dots-canvas");
const context = canvas.getContext("2d", { alpha: true });
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

const settings = {
  spacing: 25,
  baseRadius: 1.3,
  interactionRadius: 165,
  displacement: 30,
  maxScale: 3.4,
  easing: 0.13,
  idleOpacity: 0.27,
  activeOpacity: 0.92
};

const grey = { r: 148, g: 151, b: 158 };
const orange = { r: 59, g: 130, b: 247 };
const pointer = { x: -1000, y: -1000, active: false };

let dots = [];
let viewWidth = 0;
let viewHeight = 0;
let pixelRatio = 1;
let animationFrame = 0;

class Dot {
  constructor(x, y) {
    this.baseX = x;
    this.baseY = y;
    this.x = x;
    this.y = y;
    this.scale = 1;
    this.highlight = 0;
  }

  update() {
    let targetX = this.baseX;
    let targetY = this.baseY;
    let targetScale = 1;
    let targetHighlight = 0;

    if (pointer.active && !reducedMotion.matches) {
      const dx = pointer.x - this.baseX;
      const dy = pointer.y - this.baseY;
      const distance = Math.hypot(dx, dy);

      if (distance < settings.interactionRadius) {
        const safeDistance = Math.max(distance, 0.001);
        const normalized = 1 - distance / settings.interactionRadius;
        const force = normalized * normalized;

        targetX =
          this.baseX - (dx / safeDistance) * force * settings.displacement;
        targetY =
          this.baseY - (dy / safeDistance) * force * settings.displacement;
        targetScale = 1 + force * (settings.maxScale - 1);
        targetHighlight = force;
      }
    }

    this.x += (targetX - this.x) * settings.easing;
    this.y += (targetY - this.y) * settings.easing;
    this.scale += (targetScale - this.scale) * settings.easing;
    this.highlight += (targetHighlight - this.highlight) * settings.easing;
  }

  draw() {
    const mix = this.highlight;
    const red = Math.round(grey.r + (orange.r - grey.r) * mix);
    const green = Math.round(grey.g + (orange.g - grey.g) * mix);
    const blue = Math.round(grey.b + (orange.b - grey.b) * mix);
    const opacity =
      settings.idleOpacity +
      (settings.activeOpacity - settings.idleOpacity) * mix;
    const radius = settings.baseRadius * this.scale;

    context.beginPath();
    context.arc(this.x, this.y, radius, 0, Math.PI * 2);
    context.fillStyle = `rgba(${red}, ${green}, ${blue}, ${opacity})`;
    context.fill();
  }
}

function createDotGrid() {
  dots = [];
  const responsiveSpacing = viewWidth < 640 ? 20 : settings.spacing;
  const columns = Math.ceil(viewWidth / responsiveSpacing) + 1;
  const rows = Math.ceil(viewHeight / responsiveSpacing) + 1;
  const offsetX = (viewWidth - (columns - 1) * responsiveSpacing) / 2;
  const offsetY = (viewHeight - (rows - 1) * responsiveSpacing) / 2;

  for (let row = 0; row < rows; row++) {
    for (let column = 0; column < columns; column++) {
      dots.push(
        new Dot(
          offsetX + column * responsiveSpacing,
          offsetY + row * responsiveSpacing
        )
      );
    }
  }
}

function resizeCanvas() {
  viewWidth = window.innerWidth;
  viewHeight = window.innerHeight;
  pixelRatio = Math.min(window.devicePixelRatio || 1, 2);

  canvas.width = Math.round(viewWidth * pixelRatio);
  canvas.height = Math.round(viewHeight * pixelRatio);
  canvas.style.width = `${viewWidth}px`;
  canvas.style.height = `${viewHeight}px`;

  context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  createDotGrid();
}

function renderDots() {
  context.clearRect(0, 0, viewWidth, viewHeight);
  for (const dot of dots) {
    dot.update();
    dot.draw();
  }
  animationFrame = requestAnimationFrame(renderDots);
}

function updatePointer(event) {
  pointer.x = event.clientX;
  pointer.y = event.clientY;
  pointer.active = true;
}

window.addEventListener("pointermove", updatePointer, { passive: true });
window.addEventListener("pointerdown", updatePointer, { passive: true });
document.documentElement.addEventListener("pointerleave", () => {
  pointer.active = false;
});
window.addEventListener("blur", () => {
  pointer.active = false;
});

let resizeTimer;
window.addEventListener("resize", () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(resizeCanvas, 100);
});

window.addEventListener(
  "pagehide",
  () => {
    cancelAnimationFrame(animationFrame);
    window.__landingPageInitialized = false;
  },
  { once: true }
);

resizeCanvas();
renderDots();

(function () {
  const navLinks = document.querySelectorAll(".navbar .nav-links a");
  if (!navLinks.length) return;

  navLinks.forEach((link) => {
    link.addEventListener("click", function () {
      navLinks.forEach((item) => item.classList.remove("active"));
      this.classList.add("active");
    });
  });
})();

})();
