/**
 * CHILL AI INTERIOR - GOOGLE FIREBASE SERVICE
 * Xử lý Google Authentication & Cloud Firestore Database
 * Tác giả: Trợ lý AI Lan & KTS. Nguyễn Văn Huy (The Architect)
 */

const ChillFirebase = (function() {
  let app = null;
  let auth = null;
  let db = null;
  let isInitialized = false;
  let currentUser = null;
  let authStateCallbacks = [];

  // Khởi tạo Firebase App & Services
  function init() {
    if (isInitialized) return true;

    // Kiểm tra thư viện Firebase Web SDK có sẵn không
    if (typeof firebase === 'undefined') {
      console.warn('[ChillFirebase] Firebase SDK chưa được nạp. Đang chạy chế độ Local Fallback.');
      return false;
    }

    try {
      const config = window.ChillFirebaseConfig ? window.ChillFirebaseConfig.getConfig() : null;
      if (!config) {
        console.warn('[ChillFirebase] Không tìm thấy Firebase Config!');
        return false;
      }

      // Khởi tạo Firebase App nếu chưa có app nào
      if (!firebase.apps.length) {
        app = firebase.initializeApp(config);
      } else {
        app = firebase.app();
      }

      // Khởi tạo Authentication
      if (firebase.auth) {
        auth = firebase.auth();
        // Cấu hình lưu trữ phiên đăng nhập bền vững (Persistent Auth)
        auth.setPersistence(firebase.auth.Auth.Persistence.LOCAL).catch(err => {
          console.warn('[ChillFirebase] Lưu persistence thất bại:', err);
        });

        // Lắng nghe trạng thái đăng nhập
        auth.onAuthStateChanged(async (firebaseUser) => {
          if (firebaseUser) {
            console.log('[ChillFirebase] Đã nhận diện tài khoản Google:', firebaseUser.email);
            currentUser = formatUserData(firebaseUser);
            
            // Tự động đồng bộ lên Cloud Firestore
            try {
              await syncUserToFirestore(currentUser);
            } catch (err) {
              console.warn('[ChillFirebase] Đồng bộ user Firestore lỗi:', err);
            }
          } else {
            console.log('[ChillFirebase] Chưa đăng nhập Google.');
            currentUser = null;
          }

          // Thông báo cho tất cả các bên đăng ký lắng nghe
          notifyAuthState(currentUser);
        });
      }

      // Khởi tạo Cloud Firestore
      if (firebase.firestore) {
        db = firebase.firestore();
        // Bật offline persistence cho Firestore nếu hỗ trợ
        try {
          db.enablePersistence({ synchronizeTabs: true }).catch(err => {
            if (err.code === 'failed-precondition') {
              console.warn('[ChillFirebase] Nhiều tab đang mở, persistence chỉ bật cho 1 tab.');
            } else if (err.code === 'unimplemented') {
              console.warn('[ChillFirebase] Trình duyệt không hỗ trợ offline persistence.');
            }
          });
        } catch (e) {
          // Bỏ qua nếu môi trường không cho phép
        }
      }

      isInitialized = true;
      console.log('[ChillFirebase] Khởi tạo Firebase thành công!');
      return true;
    } catch (e) {
      console.error('[ChillFirebase] Khởi tạo Firebase gặp sự cố:', e);
      return false;
    }
  }

  // Định dạng dữ liệu user từ Google Auth
  function formatUserData(fbUser) {
    return {
      uid: fbUser.uid,
      displayName: fbUser.displayName || 'Kiến Trúc Sư Google',
      email: fbUser.email || '',
      photoURL: fbUser.photoURL || '',
      phoneNumber: fbUser.phoneNumber || '',
      providerId: fbUser.providerData && fbUser.providerData[0] ? fbUser.providerData[0].providerId : 'google.com',
      lastLoginAt: new Date().toISOString()
    };
  }

  // Đăng ký nhận thông báo thay đổi trạng thái xác thực
  function onAuthStateChanged(cb) {
    if (typeof cb === 'function') {
      authStateCallbacks.push(cb);
      // Nếu đã có user hiện tại, gọi callback ngay lập tức
      if (currentUser !== null) {
        cb(currentUser);
      }
    }
  }

  function notifyAuthState(user) {
    authStateCallbacks.forEach(cb => {
      try {
        cb(user);
      } catch (e) {
        console.error('[ChillFirebase] Lỗi trong authStateCallback:', e);
      }
    });
  }

  // Đăng nhập bằng Google (Google Sign-In Popup & Redirect)
  async function signInWithGoogle() {
    if (!init()) {
      return { 
        success: false, 
        message: 'Firebase SDK chưa sẵn sàng. Vui lòng kiểm tra kết nối mạng hoặc thử lại!' 
      };
    }

    try {
      const provider = new firebase.auth.GoogleAuthProvider();
      provider.addScope('profile');
      provider.addScope('email');
      provider.setCustomParameters({ prompt: 'select_account' });

      // Thực hiện đăng nhập Popup
      const result = await auth.signInWithPopup(provider);
      const user = formatUserData(result.user);
      currentUser = user;

      // Đồng bộ profile người dùng lên Cloud Firestore
      await syncUserToFirestore(user);

      return {
        success: true,
        user: user,
        message: `Chào mừng ${user.displayName} đã đăng nhập Google thành công!`
      };
    } catch (error) {
      console.error('[ChillFirebase] Lỗi đăng nhập Google:', error);

      // Xử lý các mã lỗi phổ biến
      let errorMsg = 'Đăng nhập Google thất bại: ' + error.message;
      if (error.code === 'auth/popup-closed-by-user') {
        errorMsg = 'Bạn đã đóng cửa sổ đăng nhập Google!';
      } else if (error.code === 'auth/popup-blocked') {
        errorMsg = 'Cửa sổ popup đăng nhập đã bị trình duyệt chặn. Vui lòng cho phép popup!';
      } else if (error.code === 'auth/unauthorized-domain') {
        errorMsg = 'Tên miền chưa được cấp phép trong Firebase Console (Authorized Domains).';
      } else if (error.code === 'auth/disallowed_useragent') {
        errorMsg = 'Google chặn đăng nhập trong trình duyệt nhúng. Hãy mở bằng Google Chrome hoặc dùng Đăng nhập nhanh.';
      }

      return {
        success: false,
        code: error.code,
        message: errorMsg
      };
    }
  }

  // Đăng xuất Google
  async function signOut() {
    if (auth) {
      try {
        await auth.signOut();
      } catch (e) {
        console.warn('[ChillFirebase] Lỗi signOut auth:', e);
      }
    }
    currentUser = null;
    notifyAuthState(null);
    return { success: true, message: 'Đã đăng xuất tài khoản Google thành công.' };
  }

  // ===========================================================================
  // CLOUD FIRESTORE DATA STORAGE OPERATIONS (LƯU TRỮ DỮ LIỆU ĐÁM MÂY)
  // ===========================================================================

  // 1. Đồng bộ / Lưu Profile người dùng vào Firestore: collection 'users' / document '{uid}'
  async function syncUserToFirestore(user) {
    if (!user || !user.uid) return null;

    // Luôn lưu bản sao vào localStorage để truy xuất tức thì (Zero Latency)
    try {
      localStorage.setItem('chill_cached_google_user', JSON.stringify(user));
    } catch (e) {}

    if (!db) {
      console.log('[ChillFirebase] Firestore chưa sẵn sàng, lưu dữ liệu vào LocalStorage');
      return user;
    }

    try {
      const userRef = db.collection('users').doc(user.uid);
      const doc = await userRef.get();

      let userDataToSave = {
        uid: user.uid,
        displayName: user.displayName || 'KTS. Nội Thất',
        email: user.email || '',
        photoURL: user.photoURL || '',
        phoneNumber: user.phoneNumber || '',
        lastLoginAt: firebase.firestore.FieldValue.serverTimestamp(),
        hardwareId: (window.ChillAuth && window.ChillAuth.getHwid) ? window.ChillAuth.getHwid() : 'HWID-DEFAULT'
      };

      if (!doc.exists) {
        // Tài khoản mới đăng nhập lần đầu
        userDataToSave.role = 'Kiến Trúc Sư / Nội Thất';
        userDataToSave.tier = 'VIP_PRO'; // Tặng VIP PRO trải nghiệm
        userDataToSave.credits = 100000;
        userDataToSave.createdAt = firebase.firestore.FieldValue.serverTimestamp();
        await userRef.set(userDataToSave);
        console.log('[ChillFirebase] Đã tạo mới hồ sơ người dùng trên Firestore:', user.uid);
      } else {
        // Cập nhật thông tin mới nhất
        await userRef.set(userDataToSave, { merge: true });
        console.log('[ChillFirebase] Đã cập nhật hồ sơ người dùng trên Firestore:', user.uid);
      }

      return userDataToSave;
    } catch (e) {
      console.warn('[ChillFirebase] Không thể ghi dữ liệu lên Firestore:', e);
      return user;
    }
  }

  // 2. Lấy dữ liệu Profile từ Firestore
  async function getUserProfile(uid) {
    if (!uid) return null;
    if (!db) {
      const cached = localStorage.getItem('chill_cached_google_user');
      return cached ? JSON.parse(cached) : null;
    }

    try {
      const doc = await db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      console.warn('[ChillFirebase] Đọc user profile từ Firestore lỗi:', e);
    }
    return null;
  }

  // 3. Lưu Cài Đặt Người Dùng (Settings) vào Firestore: users/{uid}/settings/config
  async function saveUserSettings(settingsKey, settingsData) {
    const uid = currentUser ? currentUser.uid : null;
    if (!uid) {
      // Lưu local nếu chưa có UID
      localStorage.setItem(`chill_setting_${settingsKey}`, JSON.stringify(settingsData));
      return { success: true, localOnly: true };
    }

    // Lưu local dự phòng
    localStorage.setItem(`chill_setting_${settingsKey}`, JSON.stringify(settingsData));

    if (!db) return { success: true, localOnly: true };

    try {
      const settingsRef = db.collection('users').doc(uid).collection('settings').doc(settingsKey);
      await settingsRef.set({
        key: settingsKey,
        data: settingsData,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      console.log(`[ChillFirebase] Đã lưu cấu hình '${settingsKey}' lên Cloud Firestore!`);
      return { success: true };
    } catch (e) {
      console.warn(`[ChillFirebase] Lỗi lưu cấu hình '${settingsKey}' lên Firestore:`, e);
      return { success: false, error: e.message };
    }
  }

  // 4. Lấy Cài Đặt Người Dùng từ Firestore
  async function getUserSettings(settingsKey) {
    const uid = currentUser ? currentUser.uid : null;
    if (!uid || !db) {
      const local = localStorage.getItem(`chill_setting_${settingsKey}`);
      return local ? JSON.parse(local) : null;
    }

    try {
      const settingsRef = db.collection('users').doc(uid).collection('settings').doc(settingsKey);
      const doc = await settingsRef.get();
      if (doc.exists && doc.data().data) {
        return doc.data().data;
      }
    } catch (e) {
      console.warn(`[ChillFirebase] Lỗi đọc cấu hình '${settingsKey}' từ Firestore:`, e);
    }

    const local = localStorage.getItem(`chill_setting_${settingsKey}`);
    return local ? JSON.parse(local) : null;
  }

  // 5. Lưu Lịch Sử Dự Án / Xuất CNC / Bóc Tách Nesting vào Firestore: users/{uid}/history
  async function saveProjectHistory(historyItem) {
    const uid = currentUser ? currentUser.uid : null;
    const historyRecord = {
      ...historyItem,
      timestamp: new Date().toISOString(),
      savedAt: db ? firebase.firestore.FieldValue.serverTimestamp() : new Date().toISOString()
    };

    // Lưu cache local (tối đa 20 mục gần nhất)
    try {
      let localHistory = JSON.parse(localStorage.getItem('chill_project_history') || '[]');
      localHistory.unshift(historyRecord);
      if (localHistory.length > 20) localHistory = localHistory.slice(0, 20);
      localStorage.setItem('chill_project_history', JSON.stringify(localHistory));
    } catch (e) {}

    if (!uid || !db) return { success: true, localOnly: true };

    try {
      const historyRef = db.collection('users').doc(uid).collection('history');
      await historyRef.add(historyRecord);
      console.log('[ChillFirebase] Đã lưu lịch sử dự án lên Cloud Firestore!');
      return { success: true };
    } catch (e) {
      console.warn('[ChillFirebase] Lỗi lưu lịch sử lên Firestore:', e);
      return { success: false, error: e.message };
    }
  }

  // 6. Lấy Danh Sách Lịch Sử từ Firestore
  async function getProjectHistory(limit = 20) {
    const uid = currentUser ? currentUser.uid : null;
    if (!uid || !db) {
      try {
        return JSON.parse(localStorage.getItem('chill_project_history') || '[]');
      } catch (e) {
        return [];
      }
    }

    try {
      const snapshot = await db.collection('users').doc(uid).collection('history')
        .orderBy('savedAt', 'desc')
        .limit(limit)
        .get();

      const list = [];
      snapshot.forEach(doc => {
        list.push({ id: doc.id, ...doc.data() });
      });
      return list;
    } catch (e) {
      console.warn('[ChillFirebase] Lỗi lấy lịch sử từ Firestore:', e);
      return JSON.parse(localStorage.getItem('chill_project_history') || '[]');
    }
  }

  return {
    init,
    signInWithGoogle,
    signOut,
    onAuthStateChanged,
    getCurrentUser: () => currentUser,
    isLoggedIn: () => currentUser !== null,
    // Firestore
    syncUserToFirestore,
    getUserProfile,
    saveUserSettings,
    getUserSettings,
    saveProjectHistory,
    getProjectHistory
  };
})();

window.ChillFirebase = ChillFirebase;
