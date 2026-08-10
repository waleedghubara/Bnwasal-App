/**
 * We Deliver (بنوصل) - Main JavaScript
 */

let currentLang = 'ar';
let isMobileMenuOpen = false;

function _dec(str) {
  try { return atob(str); } catch (e) { return str; }
}

// ==========================================
// LANGUAGE SYSTEM
// ==========================================
function detectLanguage() {
  const saved = localStorage.getItem('wedeliver_lang');
  if (saved && ['ar', 'en'].includes(saved)) return saved;
  const browserLang = navigator.language || navigator.userLanguage;
  if (browserLang && browserLang.startsWith('en')) return 'en';
  return 'ar';
}

function setLanguage(lang) {
  currentLang = lang;
  localStorage.setItem('wedeliver_lang', lang);
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  document.body.className = lang === 'ar' ? '' : 'ltr';
  applyTranslations();
  updateLangToggleText();
}

function t(key) {
  return translations[currentLang]?.[key] || translations['ar']?.[key] || key;
}

function applyTranslations() {
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.dataset.i18n;
    const value = t(key);
    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
      el.placeholder = value;
    } else {
      el.innerHTML = value.replace(/\n/g, '<br>');
    }
  });

  document.querySelectorAll('[data-i18n-attr]').forEach(el => {
    const parts = el.dataset.i18nAttr.split(':');
    if (parts.length === 2) {
      const [attr, key] = parts;
      el.setAttribute(attr, t(key));
    }
  });
}

function updateLangToggleText() {
  document.querySelectorAll('.lang-toggle').forEach(el => {
    el.textContent = t('lang_switch');
  });
}

function toggleLanguage() {
  setLanguage(currentLang === 'ar' ? 'en' : 'ar');
}

// ==========================================
// MOBILE MENU
// ==========================================
function toggleMobileMenu() {
  const nav = document.querySelector('.nav-links');
  const btn = document.querySelector('.mobile-menu-btn i');
  isMobileMenuOpen = !isMobileMenuOpen;
  nav.classList.toggle('open');
  btn.className = isMobileMenuOpen ? 'fas fa-times' : 'fas fa-bars';
}

// ==========================================
// NAVBAR SCROLL
// ==========================================
function handleNavScroll() {
  const navbar = document.querySelector('.navbar');
  if (!navbar) return;
  if (window.scrollY > 50) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }
}

// ==========================================
// FAQ ACCORDION
// ==========================================
function initFaq() {
  document.querySelectorAll('.faq-question').forEach(btn => {
    btn.addEventListener('click', () => {
      const item = btn.closest('.faq-item');
      const isActive = item.classList.contains('active');
      // Close all
      document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('active'));
      // Toggle current
      if (!isActive) item.classList.add('active');
    });
  });
}

// ==========================================
// SCROLL ANIMATIONS (Intersection Observer)
// ==========================================
function initScrollReveal() {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  }, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });

  document.querySelectorAll('.reveal, .reveal-left, .reveal-right').forEach(el => {
    observer.observe(el);
  });
}

// ==========================================
// COUNTER ANIMATION
// ==========================================
function initCounters() {
  const counterObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const el = entry.target;
        const target = parseInt(el.dataset.count);
        animateCounter(el, target);
        counterObserver.unobserve(el);
      }
    });
  }, { threshold: 0.5 });

  document.querySelectorAll('[data-count]').forEach(el => {
    counterObserver.observe(el);
  });
}

function animateCounter(el, target) {
  let current = 0;
  const increment = Math.ceil(target / 60);
  const timer = setInterval(() => {
    current += increment;
    if (current >= target) {
      current = target;
      clearInterval(timer);
    }
    el.textContent = current.toLocaleString(currentLang === 'ar' ? 'ar-SA' : 'en-US');
  }, 25);
}

// ==========================================
// CONTACT FORM
// ==========================================
function initContactForm() {
  const form = document.getElementById('contactForm');
  if (!form) return;
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = form.querySelector('button[type="submit"]');
    const originalText = btn.innerHTML;
    const name = document.getElementById('name').value.trim();
    const email = document.getElementById('email').value.trim();
    const subject = document.getElementById('subject').value.trim();
    const message = document.getElementById('message').value.trim();

    if (!name || !email || !subject || !message) return;

    const sendingText = currentLang === 'ar' ? 'جاري الإرسال...' : 'Sending...';
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> ' + sendingText;
    btn.disabled = true;

    try {
      let contactUrl = _dec('L2FwaS9zdXBwb3J0L2NvbnRhY3Q=');
      if (typeof APP_CONFIG !== 'undefined' && APP_CONFIG.api && APP_CONFIG.api.contactUrl) {
        contactUrl = _dec(APP_CONFIG.api.contactUrl);
      }
      const res = await fetch(contactUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, subject, message, source: 'website' }),
      });
      const json = await res.json();
      if (json.status === 1) {
        btn.innerHTML = '<i class="fas fa-check"></i> ' + (currentLang === 'ar' ? 'تم الإرسال بنجاح!' : 'Sent Successfully!');
        btn.style.background = '#10b981';
        form.reset();
      } else {
        btn.innerHTML = '<i class="fas fa-times"></i> ' + (json.message || (currentLang === 'ar' ? 'فشل الإرسال' : 'Failed'));
        btn.style.background = '#ef4444';
      }
    } catch (err) {
      btn.innerHTML = '<i class="fas fa-times"></i> ' + (currentLang === 'ar' ? 'خطأ في الاتصال' : 'Connection Error');
      btn.style.background = '#ef4444';
    }

    setTimeout(() => {
      btn.innerHTML = originalText;
      btn.style.background = '';
      btn.disabled = false;
    }, 4000);
  });
}

// ==========================================
// SMOOTH SCROLL
// ==========================================
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', (e) => {
      const href = anchor.getAttribute('href');
      if (href && href.length > 1) {
        const target = document.querySelector(href);
        if (target) {
          e.preventDefault();
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          if (isMobileMenuOpen) toggleMobileMenu();
        }
      }
    });
  });
}

// ==========================================
// ACTIVE NAV LINK
// ==========================================
function setActiveNavLink() {
  const path = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav-links a').forEach(a => {
    a.classList.remove('active');
    const href = a.getAttribute('href');
    if (href === path || (path === '' && href === 'index.html') || (path === 'index.html' && href === 'index.html')) {
      a.classList.add('active');
    }
  });
}

// ==========================================
// DYNAMIC YEAR
// ==========================================
function setCopyrightYear() {
  document.querySelectorAll('[data-year]').forEach(el => {
    el.textContent = new Date().getFullYear();
  });
}

// ==========================================
// DOWNLOAD LINKS FROM CONFIG
// ==========================================
function initDownloadLinks() {
  if (typeof APP_CONFIG === 'undefined' || !APP_CONFIG.downloads) return;
  const config = APP_CONFIG.downloads;
  const androidBtn = document.getElementById('androidDownloadBtn');
  const iosBtn = document.getElementById('iosDownloadBtn');
  if (androidBtn && config.android.playStore) {
    androidBtn.href = config.android.playStore;
  }
  if (iosBtn && config.ios.appStore) {
    iosBtn.href = config.ios.appStore;
  }
  // Also update any generic download links containing play/apple/app-store icons
  document.querySelectorAll('a i.fa-google-play').forEach(icon => {
    const btn = icon.closest('a');
    if (btn && config.android.playStore) btn.href = config.android.playStore;
  });
  document.querySelectorAll('a i.fa-apple').forEach(icon => {
    const btn = icon.closest('a');
    if (btn && config.ios.appStore) btn.href = config.ios.appStore;
  });
  document.querySelectorAll('a i.fa-app-store-ios').forEach(icon => {
    const btn = icon.closest('a');
    if (btn && config.android.galaxyStore) btn.href = config.android.galaxyStore;
  });
}

// ==========================================
// iPHONE CAROUSEL
// ==========================================
function initIphoneCarousel() {
  const slides = document.querySelectorAll('.iphone-slide');
  const dots = document.querySelectorAll('.iphone-dots .dot');
  if (!slides.length) return;
  let current = 0;
  const total = slides.length;
  setInterval(() => {
    slides[current].classList.remove('active');
    dots[current]?.classList.remove('active');
    current = (current + 1) % total;
    slides[current].classList.add('active');
    dots[current]?.classList.add('active');
  }, 3500);
}

// ==========================================
// LIVE STATS FROM API
// ==========================================
async function initLiveStats() {
  if (typeof APP_CONFIG === 'undefined' || !APP_CONFIG.api) return;
  const endpoint = _dec(APP_CONFIG.api.endpoint);
  const key = _dec(APP_CONFIG.api.key);
  if (!endpoint) return;

  try {
    const res = await fetch(endpoint, {
      headers: { 'X-API-Key': key },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();
    if (json.status !== 1 || !json.data) return;

    const stats = json.data;

    // Update every [data-count] that has a matching data-stat-key
    document.querySelectorAll('[data-count][data-stat-key]').forEach(el => {
      const apiKey = el.dataset.statKey;
      if (apiKey && stats[apiKey] != null) {
        el.dataset.count = String(stats[apiKey]);
      }
    });

    // Update the about-badge static text (if present)
    const badge = document.querySelector('.about-image-badge [data-i18n="about_badge_shipments"]');
    if (badge && stats.totalCompleted != null) {
      const formatted = stats.totalCompleted.toLocaleString('ar-SA');
      badge.textContent = `+${formatted}`;
    }
  } catch (err) {
    console.warn('⚠️ Could not fetch live stats, using fallback values:', err.message);
  }
}

// ==========================================
// INIT
// ==========================================
document.addEventListener('DOMContentLoaded', () => {
  setLanguage(detectLanguage());
  handleNavScroll();
  initFaq();
  initScrollReveal();
  initLiveStats().then(() => initCounters());
  initContactForm();
  initSmoothScroll();
  setActiveNavLink();
  setCopyrightYear();
  initDownloadLinks();
  initIphoneCarousel();

  window.addEventListener('scroll', handleNavScroll);

  // Close mobile menu on resize
  window.addEventListener('resize', () => {
    if (window.innerWidth > 768 && isMobileMenuOpen) {
      toggleMobileMenu();
    }
  });
});
