/**
 * SmartTrader Home Page JavaScript
 * Handles interactions for the feature navigation dashboard
 */

(function() {
  'use strict';

  const CONFIG = {
    hoverDelay: 300,
    animationStagger: 50,
    scrollThreshold: 100
  };

  let modules = [];

  /**
   * Initialize the home page
   */
  function init() {
    cacheElements();
    bindEvents();
    animateOnScroll();
    initModuleCards();
    initParticles();
  }

  /**
   * Cache DOM elements
   */
  function cacheElements() {
    modules = document.querySelectorAll('.module-card');
  }

  /**
   * Bind event listeners
   */
  function bindEvents() {
    // Logout button confirmation - override Turbo's default behavior
    const logoutLink = document.querySelector('.logout-btn');
    if (logoutLink) {
      logoutLink.addEventListener('turbo:click', function(e) {
        if (!confirm('Are you sure you want to sign out?')) {
          e.preventDefault();
          e.stopImmediatePropagation();
        }
      });
      logoutLink.addEventListener('click', function(e) {
        if (!confirm('Are you sure you want to sign out?')) {
          e.preventDefault();
        }
      });
    }

    // Module card hover effects
    modules.forEach(module => {
      module.addEventListener('mouseenter', handleModuleHover);
      module.addEventListener('mouseenter', playSound);
    });

    // Keyboard navigation
    document.addEventListener('keydown', handleKeyboard);
  }

  /**
   * Handle module card hover
   */
  function handleModuleHover(e) {
    const module = e.currentTarget;
    const complexity = module.dataset.complexity;
    const moduleName = module.dataset.module;

    // Update visual feedback based on complexity
    if (complexity === '5') {
      module.style.zIndex = '10';
    }
  }

  /**
   * Play subtle sound on high complexity modules
   */
  function playSound(e) {
    const module = e.currentTarget;
    const complexity = parseInt(module.dataset.complexity);

    // Only play for high complexity modules (4+)
    if (complexity >= 4 && !sessionStorage.getItem(`sound-${Date.now()}`)) {
      // Could add sound effect here
      sessionStorage.setItem(`sound-${Date.now()}`, 'true');
      setTimeout(() => session.removeItem(`sound-${Date.now()}`), 1000);
    }
  }

  /**
   * Handle keyboard navigation
   */
  function handleKeyboard(e) {
    switch(e.key) {
      case 'Escape':
        // Reset any active states
        modules.forEach(m => m.style.zIndex = '');
        break;
    }
  }

  /**
   * Animate elements on scroll
   */
  function animateOnScroll() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
        }
      });
    }, { threshold: 0.1 });

    // Observe module cards
    modules.forEach((module, index) => {
      module.style.opacity = '0';
      module.style.transform = 'translateY(30px)';
      module.style.transition = `opacity 0.5s ease ${index * 0.05}s, transform 0.5s ease ${index * 0.05}s`;
      observer.observe(module);
    });
  }

  /**
   * Initialize module card interactions
   */
  function initModuleCards() {
    modules.forEach((module, index) => {
      // Add data attributes for tracking
      module.dataset.index = index;

      // Create tooltip with more info
      const title = module.querySelector('.module-card__title')?.textContent;
      const description = module.querySelector('.module-card__description')?.textContent;
      module.setAttribute('title', `${title}: ${description}`);

      // Add ripple effect on click
      module.addEventListener('click', createRipple);
    });

    // Sort modules by complexity
    sortModulesByComplexity();
  }

  /**
   * Create ripple effect on card click
   */
  function createRipple(e) {
    const card = e.currentTarget;
    const rect = card.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height);
    const x = e.clientX - rect.left - size / 2;
    const y = e.clientY - rect.top - size / 2;

    const ripple = document.createElement('div');
    ripple.style.cssText = `
      position: absolute;
      width: ${size}px;
      height: ${size}px;
      left: ${x}px;
      top: ${y}px;
      background: radial-gradient(circle, rgba(6, 182, 212, 0.1) 0%, transparent 70%);
      border-radius: 50%;
      transform: scale(0);
      animation: rippleEffect 0.6s ease-out;
      pointer-events: none;
    `;

    card.appendChild(ripple);
    setTimeout(() => ripple.remove(), 600);
  }

  /**
   * Sort modules by complexity
   */
  function sortModulesByComplexity() {
    const grid = document.querySelector('.modules-grid');
    const sortedModules = Array.from(modules).sort((a, b) => {
      return (parseInt(b.dataset.complexity) || 0) - (parseInt(a.dataset.complexity) || 0);
    });

    // Log for debugging (could be used to reorder if needed)
    console.log('Modules sorted by complexity:', sortedModules.map(m => ({
      name: m.querySelector('.module-card__title')?.textContent,
      complexity: m.dataset.complexity
    })));
  }

  /**
   * Initialize background particles
   */
  function initParticles() {
    const container = document.querySelector('.home-background');
    if (!container) return;

    // Create floating elements
    for (let i = 0; i < 5; i++) {
      const particle = document.createElement('div');
      particle.className = 'home-particle';
      particle.style.cssText = `
        position: absolute;
        width: 2px;
        height: 2px;
        background: rgba(6, 182, 212, 0.3);
        border-radius: 50%;
        left: ${Math.random() * 100}%;
        top: ${Math.random() * 100}%;
        animation: particleFloat ${10 + Math.random() * 10}s linear infinite;
        animation-delay: ${Math.random() * 5}s;
      `;
      container.appendChild(particle);
    }
  }

  /**
   * Get module info by selector
   */
  function getModuleInfo(selector) {
    const module = document.querySelector(selector);
    if (!module) return null;

    return {
      title: module.querySelector('.module-card__title')?.textContent,
      complexity: module.dataset.complexity,
      module: module.dataset.module
    };
  }

  /**
   * Export utility functions
   */
  window.smartTraderHome = {
    getModuleInfo,
    getModules: () => Array.from(modules).map(m => ({
      name: m.querySelector('.module-card__title')?.textContent,
      complexity: m.dataset.complexity,
      module: m.dataset.module
    })),
    highlightModule: (moduleId) => {
      const module = document.querySelector(`[data-module="${moduleId}"]`);
      if (module) {
        module.scrollIntoView({ behavior: 'smooth', block: 'center' });
        module.style.animation = 'none';
        module.offsetHeight;
        module.style.animation = 'pulse-glow 1s ease-out 3';
      }
    }
  };

  // Add keyframe animation for ripple
  const style = document.createElement('style');
  style.textContent = `
    @keyframes rippleEffect {
      to {
        transform: scale(3);
        opacity: 0;
      }
    }
    @keyframes particleFloat {
      0%, 100% {
        transform: translate(0, 0);
        opacity: 0.3;
      }
      50% {
        transform: translate(${Math.random() * 100 - 50}px, ${Math.random() * 100 - 50}px);
        opacity: 0.6;
      }
    }
  `;
  document.head.appendChild(style);

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  console.log('SmartTrader Home initialized - 9 modules loaded');
})();
