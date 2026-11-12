/* SKINCAR — thème noir + gris clair, piloté en JavaScript.
   - DARK  : couleurs des parties noires (en-tête, accroche, pied de page, sections noires).
   - LIGHT : couleurs des parties gris clair (sections claires, page admin).
   - Les sections de la page d'accueil alternent automatiquement gris clair / noir.
   Modifiez les couleurs ici, à un seul endroit. */
(function () {
  "use strict";

  var LIME = "#B7F36B";

  var DARK = {
    "--bg": "#0a0a0a", "--surface": "#1a1a1a", "--fg": "#f2f2f2", "--muted": "#a6a6a6", "--line": "#333333",
    "--btn-bg": LIME, "--btn-fg": "#000000", "--sel-line": LIME, "--sel-bg": "#26301c",
    "--hero-bg": "#0a0a0a", "--hero-fg": "#f2f2f2", "--hero-muted": "#b0b0b0", "--hero-line": "#2c2c2c",
    "--tag": LIME, "--link": LIME, "--focus": LIME, "--bad": "#ff8a98",
    "--warn-bg": "#2e2508", "--warn-fg": "#ffd978", "--field": "#111111"
  };

  var LIGHT = {
    "--bg": "#e8e8e8",          // gris clair (fond des bandes)
    "--surface": "#ffffff",     // cartes blanches
    "--fg": "#111111", "--muted": "#555555", "--line": "#cccccc",
    "--btn-bg": "#111111", "--btn-fg": LIME, "--sel-line": "#111111", "--sel-bg": "#e6f8c8",
    "--tag": "#3a6a0a", "--link": "#111111", "--focus": "#111111", "--bad": "#c62d3f",
    "--warn-bg": "#fff1cc", "--warn-fg": "#6b4a00", "--field": "#f4f4f4",
    // admin
    "--bar-bg": "#000000", "--bar-fg": "#f2f2f2", "--bar-muted": "#a8a8a8",
    "--info-bg": "#dce9ff", "--info-fg": "#0f3a85", "--ok-bg": "#d9f5c2", "--ok-fg": "#1d5a0a",
    "--off-bg": "#e2e2e2", "--off-fg": "#4a4a4a"
  };

  function vars(obj) {
    return Object.keys(obj).map(function (k) { return k + ":" + obj[k]; }).join(";");
  }

  var isAdmin = /admin|compte|rejoindre/i.test(location.pathname);
  var root = document.documentElement;

  // Pages admin et compte : gris clair avec barre noire. Accueil : base noire.
  var base = isAdmin ? LIGHT : DARK;
  Object.keys(base).forEach(function (k) { root.style.setProperty(k, base[k]); });
  root.style.colorScheme = isAdmin ? "light" : "dark";

  var css = [
    "html,body{overflow-x:clip}",
    // bandes pleine largeur
    ".band{position:relative;color:var(--fg)}",
    ".band::before{content:'';position:absolute;inset:0 calc(50% - 50vw);z-index:-1;background:var(--bg)}",
    "main>.wrap{position:relative;z-index:0}",
    ".band-light{" + vars(LIGHT) + ";color-scheme:light}",
    ".band-dark{" + vars(DARK) + "}",
    // champs
    "input[type=text],input[type=tel],input[type=date],select,textarea,.opt span{background:var(--field,var(--bg))}",
    // accroche + en-tête + pied de page en noir
    ".hero{background:#0a0a0a}",
    ".quick{background:#e8e8e8;color:#111;border:0;" + vars({ "--fg": "#111111", "--muted": "#555555", "--line": "#c4c4c4", "--field": "#ffffff", "--btn-bg": "#111111", "--btn-fg": LIME, "--focus": "#111111", "--bad": "#c62d3f" }) + ";color-scheme:light}",
    ".top{background:rgba(0,0,0,.92);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);transition:box-shadow .3s ease}",
    ".top.scrolled{box-shadow:0 6px 22px rgba(0,0,0,.35)}",
    "footer{background:#000;border-top:1px solid #2c2c2c}",
    // cartes
    ".card.top-pick{background:#111;color:#f2f2f2;border-color:#111}",
    ".band-light .card,.band-light .zone,.band-light .book{box-shadow:0 1px 2px rgba(0,0,0,.06)}",
    ".card,.zone{position:relative;overflow:hidden}",
    ".card::after,.zone::after{content:'';position:absolute;inset:0;pointer-events:none;opacity:0;transition:opacity .25s ease;",
    "background:radial-gradient(240px circle at var(--mx,50%) var(--my,50%),rgba(183,243,107,.18),transparent 70%)}",
    ".card:hover::after,.zone:hover::after{opacity:1}",
    ".card:hover,.zone:hover{box-shadow:0 12px 26px rgba(0,0,0,.14)}",
    ".band-dark .card:hover,.band-dark .zone:hover{box-shadow:0 12px 26px rgba(0,0,0,.6)}",
    // étapes
    ".steps li{border-top-color:var(--line);transition:border-color .4s ease}",
    ".steps li.lit{border-top-color:" + LIME + "}"
  ].join("");

  var style = document.createElement("style");
  style.id = "washgo-theme";
  style.textContent = css;
  document.head.appendChild(style);

  function ready(fn) {
    if (document.readyState !== "loading") fn();
    else document.addEventListener("DOMContentLoaded", fn);
  }

  ready(function () {
    // 1. Sections de l'accueil : gris clair / noir en alternance
    var sections = document.querySelectorAll("main > .wrap > section");
    for (var i = 0; i < sections.length; i++) {
      sections[i].classList.add("band", i % 2 === 0 ? "band-light" : "band-dark");
    }

    // 2. Ombre de l'en-tête au défilement
    var top = document.querySelector(".top");
    if (top) {
      var onScroll = function () { top.classList.toggle("scrolled", window.scrollY > 10); };
      window.addEventListener("scroll", onScroll, { passive: true });
      onScroll();
    }

    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    // 3. Halo lime qui suit la souris sur les cartes et les zones
    document.addEventListener("pointermove", function (e) {
      var el = e.target.closest && e.target.closest(".card, .zone");
      if (!el) return;
      var r = el.getBoundingClientRect();
      el.style.setProperty("--mx", (e.clientX - r.left) + "px");
      el.style.setProperty("--my", (e.clientY - r.top) + "px");
    }, { passive: true });

    // 4. Étapes : la ligne passe au vert l'une après l'autre
    var steps = document.querySelectorAll(".steps li");
    if (steps.length && "IntersectionObserver" in window) {
      var io = new IntersectionObserver(function (entries) {
        if (!entries[0].isIntersecting) return;
        for (var j = 0; j < steps.length; j++) {
          (function (li, d) { setTimeout(function () { li.classList.add("lit"); }, d); })(steps[j], j * 250);
        }
        io.disconnect();
      }, { threshold: 0.4 });
      io.observe(steps[0]);
    }
  });
})();
