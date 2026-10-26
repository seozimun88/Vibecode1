/**
 * CHILL AI INTERIOR - FIREBASE CONFIGURATION MODULE
 * Quản lý cấu hình Google Firebase (Authentication & Cloud Firestore)
 * Thiết kế cho: Tổng Công Trình Sư - Anh Huy
 */

const ChillFirebaseConfig = (function() {
  // Cấu hình Firebase mặc định cho Chill AI Interior
  const DEFAULT_CONFIG = {
    apiKey: "AIzaSyChillAIInteriorFirebase2026ProKey",
    authDomain: "chill-ai-interior.firebaseapp.com",
    projectId: "chill-ai-interior",
    storageBucket: "chill-ai-interior.appspot.com",
    messagingSenderId: "987654321098",
    appId: "1:987654321098:web:chillai2026interior"
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
      console.warn('[FirebaseConfig] Lỗi đọc custom config từ localStorage:', e);
    }
    return DEFAULT_CONFIG;
  }

  function saveConfig(cfg) {
    if (!cfg || !cfg.apiKey || !cfg.projectId) {
      return { success: false, message: 'Cấu hình Firebase không hợp lệ (cần ít nhất apiKey và projectId)!' };
    }
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
      return { success: true, message: 'Đã lưu cấu hình Firebase thành công!' };
    } catch (e) {
      return { success: false, message: 'Lỗi lưu cấu hình: ' + e.message };
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
