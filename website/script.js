/* Cannon Craze site behavior. No frameworks, no dependencies. */
(function () {
  "use strict";

  /* -- Sticky nav ------------------------------------------------------------ */

  var nav = document.getElementById("nav");
  var onScroll = function () {
    nav.classList.toggle("is-scrolled", window.scrollY > 12);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  var toggle = document.getElementById("navToggle");
  var links = document.getElementById("navLinks");
  toggle.addEventListener("click", function () {
    var open = links.classList.toggle("is-open");
    nav.classList.toggle("is-open", open);
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
  });
  links.addEventListener("click", function (e) {
    if (e.target.closest("a")) {
      links.classList.remove("is-open");
      nav.classList.remove("is-open");
      toggle.setAttribute("aria-expanded", "false");
    }
  });

  /* -- Reveal on scroll --------------------------------------------------------- */

  var reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add("is-visible"); });
  }

  /* -- Platform detection: point the hero CTA at the visitor's platform ---------- */

  var DL = {
    windows: {
      label: "Download for Windows",
      href: "https://github.com/theanasuddin/CannonCraze/releases/latest/download/CannonCraze-windows-x64.zip",
      sub: "Windows 10/11 · 189 MB · v1.1.0 · nothing else to install"
    },
    macos: {
      label: "Download for macOS",
      href: "https://github.com/theanasuddin/CannonCraze/releases/latest/download/CannonCraze-macos-apple-silicon.zip",
      sub: "macOS 11+ · 9.4 MB · v1.1.0 · Intel build below"
    },
    linux: {
      label: "Download for Linux",
      href: "https://github.com/theanasuddin/CannonCraze/releases/latest/download/CannonCraze-linux-x64.zip",
      sub: "Linux x64 · 9.3 MB · v1.1.0 · ARM builds below"
    },
    android: {
      label: "Download the APK",
      href: "https://github.com/theanasuddin/CannonCraze/releases/latest/download/CannonCraze-android.apk",
      sub: "Android 5.0+ · 3.4 MB · v1.1.0 · Google Play coming soon"
    }
  };

  function detectOS() {
    var ua = navigator.userAgent;
    if (/Android/i.test(ua)) return "android";
    if (/iPhone|iPad|iPod/i.test(ua)) return null; // no iOS build: keep generic
    if (/Windows/i.test(ua)) return "windows";
    if (/Macintosh|Mac OS X/i.test(ua)) return "macos";
    if (/Linux|X11|CrOS/i.test(ua)) return "linux";
    return null;
  }

  var os = detectOS();
  if (os && DL[os]) {
    var cta = document.getElementById("heroDownload");
    var label = document.getElementById("heroDownloadLabel");
    var sub = document.getElementById("heroSub");
    cta.href = DL[os].href;
    cta.removeAttribute("id"); // avoid double-styling on repaint
    label.textContent = DL[os].label;
    sub.innerHTML =
      DL[os].sub + ' · <a href="#download">all platforms</a>';
    var card = document.querySelector('.dl-card[data-os="' + os + '"]');
    if (card) card.classList.add("is-detected");
  }

  /* -- Screenshot lightbox --------------------------------------------------------- */

  var lightbox = document.getElementById("lightbox");
  var lightboxImg = document.getElementById("lightboxImg");
  var lightboxCaption = document.getElementById("lightboxCaption");
  var lastFocus = null;

  document.getElementById("gallery").addEventListener("click", function (e) {
    var btn = e.target.closest("button");
    if (!btn) return;
    var img = btn.querySelector("img");
    lastFocus = btn;
    lightboxImg.src = img.src;
    lightboxImg.alt = img.alt;
    lightboxCaption.textContent = btn.getAttribute("data-caption") || "";
    lightbox.classList.add("is-open");
    document.getElementById("lightboxClose").focus();
    document.body.style.overflow = "hidden";
  });

  function closeLightbox() {
    lightbox.classList.remove("is-open");
    lightboxImg.src = "";
    document.body.style.overflow = "";
    if (lastFocus) lastFocus.focus();
  }

  document.getElementById("lightboxClose").addEventListener("click", closeLightbox);
  lightbox.addEventListener("click", function (e) {
    if (e.target === lightbox) closeLightbox();
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && lightbox.classList.contains("is-open")) closeLightbox();
  });

  /* -- Footer year -------------------------------------------------------------------- */

  document.getElementById("year").textContent = new Date().getFullYear();

  /* -- Hero starfield: the game's own night sky, in miniature ---------------------------
     Stars twinkle on individual phases and a meteor streaks by every few
     seconds, exactly like in-game. Respects reduced motion and pauses when
     the tab is hidden or the hero has scrolled away. */

  var canvas = document.getElementById("starfield");
  if (canvas && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    var ctx = canvas.getContext("2d");
    var stars = [];
    var meteor = null;
    var meteorTimer = 4;
    var running = true;
    var lastT = performance.now();

    function resize() {
      var hero = canvas.parentElement;
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = hero.clientWidth * dpr;
      canvas.height = hero.clientHeight * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      seed(hero.clientWidth, hero.clientHeight);
    }

    function seed(w, h) {
      stars = [];
      var count = Math.min(210, Math.round((w * h) / 6200));
      for (var i = 0; i < count; i++) {
        stars.push({
          x: Math.random() * w,
          y: Math.random() * h * 0.92,
          r: 0.4 + Math.random() * 1.1,
          ph: Math.random() * Math.PI * 2,
          sp: 0.5 + Math.random() * 1.4
        });
      }
    }

    function frame(now) {
      if (!running) return;
      var dt = Math.min((now - lastT) / 1000, 0.05);
      lastT = now;
      var w = canvas.parentElement.clientWidth;
      var h = canvas.parentElement.clientHeight;
      ctx.clearRect(0, 0, w, h);

      var t = now / 1000;
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i];
        var tw = 0.55 + 0.45 * Math.sin(t * s.sp * 2.2 + s.ph);
        ctx.globalAlpha = 0.16 + 0.55 * tw * (s.r / 1.5);
        ctx.fillStyle = "#DDE6FF";
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.r, 0, 6.2832);
        ctx.fill();
      }
      ctx.globalAlpha = 1;

      // meteor
      if (!meteor) {
        meteorTimer -= dt;
        if (meteorTimer <= 0) {
          var speed = 340 + Math.random() * 160;
          meteor = {
            x: w * (0.3 + Math.random() * 0.65),
            y: h * (0.05 + Math.random() * 0.25),
            vx: -speed * 0.92,
            vy: speed * 0.4,
            age: 0,
            life: 0.7 + Math.random() * 0.5
          };
        }
      } else {
        meteor.age += dt;
        meteor.x += meteor.vx * dt;
        meteor.y += meteor.vy * dt;
        if (meteor.age >= meteor.life) {
          meteor = null;
          meteorTimer = 5 + Math.random() * 7;
        } else {
          var u = meteor.age / meteor.life;
          var a = Math.sin(u * Math.PI);
          var tail = 0.16;
          var grad = ctx.createLinearGradient(
            meteor.x, meteor.y,
            meteor.x - meteor.vx * tail, meteor.y - meteor.vy * tail
          );
          grad.addColorStop(0, "rgba(221,230,255," + 0.75 * a + ")");
          grad.addColorStop(1, "rgba(221,230,255,0)");
          ctx.strokeStyle = grad;
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.moveTo(meteor.x, meteor.y);
          ctx.lineTo(meteor.x - meteor.vx * tail, meteor.y - meteor.vy * tail);
          ctx.stroke();
        }
      }
      requestAnimationFrame(frame);
    }

    function setRunning(on) {
      if (on && !running) {
        running = true;
        lastT = performance.now();
        requestAnimationFrame(frame);
      } else if (!on) {
        running = false;
      }
    }

    document.addEventListener("visibilitychange", function () {
      setRunning(!document.hidden && heroVisible);
    });

    var heroVisible = true;
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (entries) {
        heroVisible = entries[0].isIntersecting;
        setRunning(heroVisible && !document.hidden);
      }).observe(canvas.parentElement);
    }

    var resizeTimer;
    window.addEventListener("resize", function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(resize, 150);
    });

    resize();
    requestAnimationFrame(frame);
  }
})();
