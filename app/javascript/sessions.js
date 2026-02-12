/**
 * SmartTrader Login Page JavaScript
 * Handles interactions and animations for the login page
 */

(function() {
  'use strict';

  // Configuration
  const CONFIG = {
    particleCount: 20,
    animationDuration: 800,
    staggerDelay: 100
  };

  /**
   * Initialize the login page
   */
  function init() {
    createParticles();
    animateElements();
    bindEvents();
    setupGoogleSignIn();
  }

  /**
   * Create floating particles in the background
   */
  function createParticles() {
    const container = document.querySelector('.login-background__particles');
    if (!container) return;

    for (let i = 0; i < CONFIG.particleCount; i++) {
      const particle = document.createElement('div');
      particle.className = 'particle';
      particle.style.left = `${Math.random() * 100}%`;
      particle.style.animationDelay = `${Math.random() * 15}s`;
      particle.style.animationDuration = `${15 + Math.random() * 10}s`;
      container.appendChild(particle);
    }
  }

  /**
   * Animate elements on page load
   */
  function animateElements() {
    const card = document.querySelector('.login-card');
    const logo = document.querySelector('.login-logo');
    const features = document.querySelectorAll('.feature-item');

    if (card) {
      card.style.opacity = '0';
      card.style.transform = 'translateY(30px)';
      card.style.transition = `opacity ${CONFIG.animationDuration}ms ease, transform ${CONFIG.animationDuration}ms ease`;

      setTimeout(() => {
        card.style.opacity = '1';
        card.style.transform = 'translateY(0)';
      }, 100);
    }

    if (logo) {
      logo.style.opacity = '0';
      logo.style.transform = 'scale(0.9)';
      logo.style.transition = `opacity ${CONFIG.animationDuration}ms ease, transform ${CONFIG.animationDuration}ms ease`;

      setTimeout(() => {
        logo.style.opacity = '1';
        logo.style.transform = 'scale(1)';
      }, 200);
    }

    features.forEach((feature, index) => {
      feature.style.opacity = '0';
      feature.style.transform = 'translateY(20px)';
      feature.style.transition = `opacity ${CONFIG.animationDuration}ms ease, transform ${CONFIG.animationDuration}ms ease`;

      setTimeout(() => {
        feature.style.opacity = '1';
        feature.style.transform = 'translateY(0)';
      }, 400 + (index * CONFIG.staggerDelay));
    });
  }

  /**
   * Bind event listeners
   */
  function bindEvents() {
    const googleBtn = document.querySelector('.google-signin-btn');

    if (googleBtn) {
      googleBtn.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-2px)';
      });

      googleBtn.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0)';
      });

      googleBtn.addEventListener('click', function(e) {
        e.preventDefault();
        handleGoogleSignIn();
      });
    }

    // Add ripple effect to buttons
    document.querySelectorAll('.google-signin-btn').forEach(button => {
      button.addEventListener('click', createRipple);
    });
  }

  /**
   * Create ripple effect on button click
   */
  function createRipple(e) {
    const button = e.currentTarget;
    const rect = button.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height);
    const x = e.clientX - rect.left - size / 2;
    const y = e.clientY - rect.top - size / 2;

    const ripple = document.createElement('span');
    ripple.style.cssText = `
      position: absolute;
      width: ${size}px;
      height: ${size}px;
      left: ${x}px;
      top: ${y}px;
      background: rgba(255, 255, 255, 0.3);
      border-radius: 50%;
      transform: scale(0);
      animation: rippleEffect 0.6s ease-out;
      pointer-events: none;
    `;

    button.style.position = 'relative';
    button.style.overflow = 'hidden';
    button.appendChild(ripple);

    setTimeout(() => ripple.remove(), 600);
  }

  /**
   * Setup Google Sign-In
   */
  function setupGoogleSignIn() {
    // Check if Google API is loaded
    if (typeof google !== 'undefined' && google.accounts) {
      initializeGoogleButton();
    } else {
      // Wait for Google API to load
      window.addEventListener('load', function() {
        if (typeof google !== 'undefined' && google.accounts) {
          initializeGoogleButton();
        }
      });
    }
  }

  /**
   * Initialize Google Sign-In button
   */
  function initializeGoogleButton() {
    google.accounts.id.initialize({
      client_id: document.querySelector('meta[name="google-signin-client_id"]')?.content || '',
      callback: handleGoogleCredentialResponse,
      auto_select: false,
      cancel_on_tap_outside: true
    });

    // Render Google button if container exists
    const googleBtnContainer = document.getElementById('google-signin-button');
    if (googleBtnContainer) {
      google.accounts.id.renderButton(googleBtnContainer, {
        theme: 'filled_blue',
        size: 'large',
        width: '100%',
        text: 'signin_with',
        shape: 'rectangular'
      });
    }
  }

  /**
   * Handle Google Sign In click
   */
  function handleGoogleSignIn() {
    // Show loading state
    const btn = document.querySelector('.google-signin-btn');
    if (btn) {
      btn.disabled = true;
      btn.innerHTML = `
        <svg class="animate-spin" style="width: 20px; height: 20px; margin-right: 12px;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle style="opacity: 0.25;" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path style="opacity: 0.75;" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span>Connecting...</span>
      `;
    }

    // Trigger Google Sign-In
    if (typeof google !== 'undefined' && google.accounts) {
      google.accounts.id.prompt((notification) => {
        if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
          // Fall back to form-based login or show error
          console.log('Google Sign-In not displayed:', notification.getNotDisplayedReason());
          resetButton();
        }
      });
    } else {
      // Google API not loaded, submit form normally
      const form = document.querySelector('.login-form');
      if (form) {
        form.submit();
      }
    }
  }

  /**
   * Handle Google Credential Response
   */
  function handleGoogleCredentialResponse(response) {
    // Send the ID token to your backend
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/auth/google/callback';

    const tokenField = document.createElement('input');
    tokenField.type = 'hidden';
    tokenField.name = 'credential';
    tokenField.value = response.credential;

    form.appendChild(tokenField);
    document.body.appendChild(form);
    form.submit();
  }

  /**
   * Reset button state
   */
  function resetButton() {
    const btn = document.querySelector('.google-signin-btn');
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = `
        <span class="google-signin-btn__icon">
          <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
        </span>
        <span>Continue with Google</span>
      `;
    }
  }

  // Add keyframe animation for ripple
  const style = document.createElement('style');
  style.textContent = `
    @keyframes rippleEffect {
      to {
        transform: scale(4);
        opacity: 0;
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
})();
