/**
 * CHILL AI INTERIOR - FIREBASE CONFIGURATION MODULE
 * Dự án chính thức của Anh Huy: chill-chill-decor
 * Quản lý cấu hình Google Firebase (Authentication & Cloud Firestore)
 */

const ChillFirebaseConfig = (function() {
  // Cấu hình Firebase chính thức của Anh Huy
  const DEFAULT_CONFIG = {
    apiKey: "AIzaSyAnt50KVjx3Ctk0Mu16YE_OiFItBykNRCk",
    authDomain: "chill-chill-decor.firebaseapp.com",
    projectId: "chill-chill-decor",
    storageBucket: "chill-chill-decor.firebasestorage.app",
    messagingSenderId: "1023430319962",
    appId: "1:1023430319962:web:7dc942efc2b3da8f9a1d63",
    measurementId: "G-CFSGEH0HBL"
  };

  const STORAGE_KEY = 'chill_custom_firebase_config';

  function getConfig() {
    try {
      const custom = localStorage.getItem(STORAGE_KEY);
      if (custom) {
        const parsed = JSON.parse(custom);
        if (parsed && parsed.apiKey && parsed.projectId) {
          return parsed;
        }
      }
    } catch (e) {
      console.warn('[FirebaseConfig] Lỗi đọc custom config:', e);
    }
    return DEFAULT_CONFIG;
  }

  function saveConfig(cfg) {
    if (!cfg || !cfg.apiKey || !cfg.projectId) {
      return { success: false, message: 'Cấu hình không hợp lệ!' };
    }
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
      return { success: true, message: 'Đã lưu cấu hình Firebase thành công!' };
    } catch (e) {
      return { success: false, message: 'Lỗi lưu: ' + e.message };
    }
  }

  function resetConfig() {
    localStorage.removeItem(STORAGE_KEY);
    return { success: true, message: 'Đã khôi phục cấu hình Firebase mặc định!' };
  }

  return {
    getConfig,
    saveConfig,
    resetConfig,
    DEFAULT_CONFIG
  };
})();

window.ChillFirebaseConfig = ChillFirebaseConfig;
