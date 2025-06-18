/**
 * Chatwoot Integration File for External Systems
 * Based on: backup/javascript_1748983635.bck/entrypoints/sdk.js
 * 
 * This file provides a clean interface for integrating Chatwoot
 * communication UI into your external system.
 */

class ChatwootIntegration {
  constructor(config = {}) {
    this.config = {
      baseUrl: config.baseUrl || 'https://chatwoot-security-gateway.eastus.azurecontainer.io:8080',
      websiteToken: config.websiteToken || 'zEGFZ3658VdbbvkCTrpy8C5z',
      locale: config.locale || 'en',
      position: config.position || 'right', // 'left' or 'right'
      hideMessageBubble: config.hideMessageBubble || false,
      widgetStyle: config.widgetStyle || 'standard', // 'standard' or 'flat'
      darkMode: config.darkMode || 'auto', // 'light', 'dark', 'auto'
      launcherTitle: config.launcherTitle || 'Chat with us',
      showPopoutButton: config.showPopoutButton || false,
      ...config
    };

    this.isLoaded = false;
    this.messageQueue = [];
    this.eventListeners = {};
  }

  /**
   * Initialize Chatwoot widget
   */
  async initialize() {
    try {
      // Load Chatwoot SDK
      await this.loadChatwootSDK();
      
      // Initialize with configuration
      window.chatwootSDK.run({
        websiteToken: this.config.websiteToken,
        baseUrl: this.config.baseUrl
      });

      // Set up global configuration
      this.setupConfiguration();
      
      // Process any queued messages
      this.processMessageQueue();
      
      this.isLoaded = true;
      this.emit('ready');
      
      return true;
    } catch (error) {
      console.error('Chatwoot Integration Error:', error);
      this.emit('error', error);
      return false;
    }
  }

  /**
   * Load Chatwoot SDK script dynamically
   */
  loadChatwootSDK() {
    return new Promise((resolve, reject) => {
      if (window.chatwootSDK) {
        resolve();
        return;
      }

      const script = document.createElement('script');
      script.src = `${this.config.baseUrl}/packs/js/sdk.js`;
      script.async = true;
      script.defer = true;
      
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Failed to load Chatwoot SDK'));
      
      document.head.appendChild(script);
    });
  }

  /**
   * Set up initial configuration
   */
  setupConfiguration() {
    // Wait for $chatwoot to be available
    const waitForChatwoot = () => {
      if (window.$chatwoot) {
        // Apply custom settings
        window.chatwootSettings = {
          ...this.config,
          hideMessageBubble: this.config.hideMessageBubble,
          position: this.config.position,
          widgetStyle: this.config.widgetStyle,
          darkMode: this.config.darkMode,
          launcherTitle: this.config.launcherTitle,
          showPopoutButton: this.config.showPopoutButton
        };

        // Set up event listeners
        this.setupEventListeners();
      } else {
        setTimeout(waitForChatwoot, 100);
      }
    };
    waitForChatwoot();
  }

  /**
   * Set up event listeners for Chatwoot events
   */
  setupEventListeners() {
    // Listen for Chatwoot ready event
    window.addEventListener('chatwoot:ready', () => {
      this.emit('widget-ready');
    });

    // Listen for new messages
    window.addEventListener('chatwoot:on-message', (event) => {
      this.emit('message-received', event.detail);
    });

    // Listen for errors
    window.addEventListener('chatwoot:error', (event) => {
      this.emit('error', event.detail);
    });
  }

  /**
   * API Methods - Direct integration with window.$chatwoot
   */

  // Open/close widget
  toggle(state) {
    this.executeWhenReady(() => window.$chatwoot.toggle(state));
  }

  // Show widget
  open() {
    this.toggle('open');
  }

  // Hide widget
  close() {
    this.toggle('close');
  }

  // Set user information
  setUser(identifier, userData) {
    this.executeWhenReady(() => {
      window.$chatwoot.setUser(identifier, {
        name: userData.name,
        email: userData.email,
        avatar_url: userData.avatar,
        phone_number: userData.phone,
        ...userData
      });
    });
  }

  // Set custom attributes
  setCustomAttributes(attributes) {
    this.executeWhenReady(() => {
      window.$chatwoot.setCustomAttributes(attributes);
    });
  }

  // Set conversation attributes
  setConversationAttributes(attributes) {
    this.executeWhenReady(() => {
      window.$chatwoot.setConversationCustomAttributes(attributes);
    });
  }

  // Add label to conversation
  addLabel(label) {
    this.executeWhenReady(() => {
      window.$chatwoot.setLabel(label);
    });
  }

  // Remove label from conversation
  removeLabel(label) {
    this.executeWhenReady(() => {
      window.$chatwoot.removeLabel(label);
    });
  }

  // Set widget language
  setLocale(locale) {
    this.executeWhenReady(() => {
      window.$chatwoot.setLocale(locale);
    });
  }

  // Set color scheme
  setColorScheme(scheme) {
    this.executeWhenReady(() => {
      window.$chatwoot.setColorScheme(scheme);
    });
  }

  // Reset conversation
  reset() {
    this.executeWhenReady(() => {
      window.$chatwoot.reset();
    });
  }

  // Open chat in popup window
  popout() {
    this.executeWhenReady(() => {
      window.$chatwoot.popoutChatWindow();
    });
  }

  // Hide/show message bubble
  toggleBubbleVisibility(visibility) {
    this.executeWhenReady(() => {
      window.$chatwoot.toggleBubbleVisibility(visibility);
    });
  }

  /**
   * Utility Methods
   */

  // Execute function when widget is ready
  executeWhenReady(callback) {
    if (this.isLoaded && window.$chatwoot) {
      callback();
    } else {
      this.messageQueue.push(callback);
    }
  }

  // Process queued messages
  processMessageQueue() {
    while (this.messageQueue.length > 0) {
      const callback = this.messageQueue.shift();
      callback();
    }
  }

  // Event emitter
  on(event, callback) {
    if (!this.eventListeners[event]) {
      this.eventListeners[event] = [];
    }
    this.eventListeners[event].push(callback);
  }

  // Emit event
  emit(event, data) {
    if (this.eventListeners[event]) {
      this.eventListeners[event].forEach(callback => {
        callback(data);
      });
    }
  }

  // Remove event listener
  off(event, callback) {
    if (this.eventListeners[event]) {
      const index = this.eventListeners[event].indexOf(callback);
      if (index > -1) {
        this.eventListeners[event].splice(index, 1);
      }
    }
  }

  /**
   * Advanced Integration Methods
   */

  // Send custom event to widget
  sendCustomEvent(eventName, data = {}) {
    this.executeWhenReady(() => {
      if (window.$chatwoot && window.$chatwoot.sendMessage) {
        window.$chatwoot.sendMessage('custom-event', {
          eventName,
          data
        });
      }
    });
  }

  // Get widget state
  getWidgetState() {
    if (window.$chatwoot) {
      return {
        isOpen: window.$chatwoot.isOpen,
        hasLoaded: window.$chatwoot.hasLoaded,
        position: window.$chatwoot.position,
        locale: window.$chatwoot.locale
      };
    }
    return null;
  }

  // Check if widget is ready
  isReady() {
    return this.isLoaded && window.$chatwoot && window.$chatwoot.hasLoaded;
  }
}

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ChatwootIntegration;
} else if (typeof define === 'function' && define.amd) {
  define([], function() { return ChatwootIntegration; });
} else {
  window.ChatwootIntegration = ChatwootIntegration;
} 