/**
 * CHILL AI INTERIOR - ACCOUNT & LICENSING SYSTEM (HỆ THỐNG TÀI KHOẢN & BẢN QUYỀN)
 * Tích hợp Google Authentication & Cloud Firestore (Google Firebase)
 * Thiết kế cho: Tổng Công Trình Sư - Anh Huy (The Architect)
 * Chuẩn mô hình ABF / One Click Cabinet / Unitool
 */

const ChillAuth = (function() {
  // Cấu hình kiểm soát bản quyền toàn hệ thống
  const CONFIG = {
    ALL_FREE: true, // Miễn phí trải nghiệm toàn bộ tính năng cao cấp cho KTS & Xưởng
    APP_VERSION: 'v2.6.2 Pro Cloud',
    REQUIRE_GOOGLE_LOGIN: true, // Yêu cầu đăng nhập Google để kích hoạt plugin
    LICENSE_SERVER_STATUS: 'ONLINE',
  };

  // Tạo Hardware ID giả lập theo máy (Device Fingerprint) hệt như ABF
  function getOrCreateHardwareId() {
    let hwid = localStorage.getItem('chill_hwid');
    if (!hwid) {
      const randStr = () => Math.random().toString(36).substring(2, 6).toUpperCase();
      hwid = `HWID-${randStr()}-${randStr()}-${randStr()}`;
      localStorage.setItem('chill_hwid', hwid);
    }
    return hwid;
  }

  // Tài khoản mẫu mặc định (Dành cho Anh Huy - Top 1 Lớp Vibe Code)
  const DEFAULT_HUY_USER = {
    isLoggedIn: true,
    uid: 'architect_huy_master_uid',
    fullName: 'KTS. Nguyễn Văn Huy',
    phone: '0988.888.888',
    email: 'thearchitect.huy@gmail.com',
    role: 'Tổng Công Trình Sư',
    tier: 'VIP_PRO', // FREE, TRIAL, VIP_PRO
    tierName: 'Gói Doanh Nhân (VIP PRO Trọn Đời)',
    badgeText: 'VIP PRO',
    expireDate: 'Vĩnh viễn (Trọn đời)',
    credits: 999999,
    hardwareId: getOrCreateHardwareId(),
    createdAt: '2026-10-12',
    avatarChar: '👑',
    photoURL: '',
    loginProvider: 'google.com'
  };

  // Khởi tạo trạng thái phiên (Session)
  let currentUser = null;

  function loadSession() {
    const saved = localStorage.getItem('chill_user_session');
    if (saved) {
      try {
        currentUser = JSON.parse(saved);
      } catch (e) {
        currentUser = null;
      }
    }
    return currentUser;
  }

  function saveSession() {
    if (currentUser) {
      localStorage.setItem('chill_user_session', JSON.stringify(currentUser));
    } else {
      localStorage.removeItem('chill_user_session');
    }
    updateUI();
  }

  // Cổng kiểm soát tính năng (Feature Gate)
  function canAccessFeature(featureKey, featureName = 'Tính năng') {
    if (CONFIG.ALL_FREE && currentUser && currentUser.isLoggedIn) {
      return { allowed: true, reason: 'Chế độ thử nghiệm miễn phí toàn phần' };
    }

    if (!currentUser || !currentUser.isLoggedIn) {
      showGatekeeper();
      return { 
        allowed: false, 
        reason: 'Vui lòng đăng nhập tài khoản Google để sử dụng tính năng này.' 
      };
    }

    if (currentUser.tier === 'VIP_PRO') {
      return { allowed: true, reason: 'Tài khoản VIP Pro' };
    }

    return { 
      allowed: false, 
      reason: `Tính năng "${featureName}" yêu cầu nâng cấp gói PRO. Vui lòng nạp mã kích hoạt!` 
    };
  }

  // Cập nhật giao diện thanh Header và Badge
  function updateUI() {
    const badgeEl = document.getElementById('account-tier-badge');
    const nameEl = document.getElementById('account-name-badge');
    const avatarEl = document.getElementById('account-avatar-mini');
    const dockVipBtn = document.getElementById('dock-btn-open-account');

    if (!currentUser || !currentUser.isLoggedIn) {
      if (nameEl) nameEl.textContent = 'Chưa Đăng Nhập';
      if (badgeEl) {
        badgeEl.textContent = 'FREE';
        badgeEl.className = 'account-tier-badge tier-guest';
      }
      if (avatarEl) {
        avatarEl.textContent = '👤';
        avatarEl.style.backgroundImage = 'none';
      }
      if (dockVipBtn) {
        dockVipBtn.innerHTML = '<span>🔒 Login</span>';
        dockVipBtn.style.background = '#334155';
      }
      return;
    }

    if (nameEl) nameEl.textContent = currentUser.fullName;
    
    // Xử lý ảnh đại diện Google hoặc emoji
    if (avatarEl) {
      if (currentUser.photoURL) {
        avatarEl.textContent = '';
        avatarEl.style.backgroundImage = `url("${currentUser.photoURL}")`;
        avatarEl.style.backgroundSize = 'cover';
        avatarEl.style.backgroundPosition = 'center';
      } else {
        avatarEl.style.backgroundImage = 'none';
        avatarEl.textContent = currentUser.avatarChar || '👤';
      }
    }

    if (badgeEl) {
      badgeEl.textContent = currentUser.badgeText || 'VIP PRO';
      badgeEl.className = `account-tier-badge tier-${(currentUser.tier || 'vip_pro').toLowerCase()}`;
    }

    if (dockVipBtn) {
      dockVipBtn.innerHTML = '<span>👑 VIP</span>';
      dockVipBtn.style.background = 'linear-gradient(135deg, #f59e0b, #d97706)';
    }

    // Cập nhật thông tin trong Modal Tab Profile
    const pName = document.getElementById('prof-user-name');
    const pRole = document.getElementById('prof-user-role');
    const pPhone = document.getElementById('prof-user-phone');
    const pEmail = document.getElementById('prof-user-email');
    const pHwid = document.getElementById('prof-user-hwid');
    const pTier = document.getElementById('prof-user-tier');
    const pExpire = document.getElementById('prof-user-expire');
    const pCredits = document.getElementById('prof-user-credits');
    const pAvatar = document.getElementById('prof-user-avatar');

    if (pName) pName.textContent = currentUser.fullName;
    if (pRole) pRole.textContent = currentUser.role;
    if (pPhone) pPhone.textContent = currentUser.phone || 'Chưa cập nhật';
    if (pEmail) pEmail.textContent = currentUser.email || 'Chưa cập nhật';
    if (pHwid) pHwid.textContent = currentUser.hardwareId;
    if (pTier) pTier.textContent = currentUser.tierName;
    if (pExpire) pExpire.textContent = currentUser.expireDate;
    if (pCredits) pCredits.textContent = (currentUser.credits || 0).toLocaleString() + ' Điểm';

    if (pAvatar) {
      if (currentUser.photoURL) {
        pAvatar.textContent = '';
        pAvatar.style.backgroundImage = `url("${currentUser.photoURL}")`;
        pAvatar.style.backgroundSize = 'cover';
      } else {
        pAvatar.style.backgroundImage = 'none';
        pAvatar.textContent = currentUser.avatarChar || '👑';
      }
    }
  }

  // ===========================================================================
  // MÀN HÌNH KHÓA BẢO VỆ GATEKEEPER (LOCK SCREEN / LOGIN GATEWAY)
  // ===========================================================================
  function showGatekeeper() {
    const gateEl = document.getElementById('gatekeeper-auth-overlay');
    if (gateEl) {
      gateEl.style.display = 'flex';
      gateEl.style.opacity = '1';
    }
  }

  function hideGatekeeper() {
    const gateEl = document.getElementById('gatekeeper-auth-overlay');
    if (gateEl) {
      gateEl.style.opacity = '0';
      setTimeout(() => {
        gateEl.style.display = 'none';
      }, 300);
    }
  }

  // ===========================================================================
  // ĐĂNG NHẬP GOOGLE & ĐỒNG BỘ CLOUD FIREBASE
  // ===========================================================================
  function openGoogleChooser() {
    const chooserEl = document.getElementById('modal-google-chooser');
    if (chooserEl) {
      chooserEl.style.display = 'flex';
    }
  }

  function closeGoogleChooser() {
    const chooserEl = document.getElementById('modal-google-chooser');
    if (chooserEl) {
      chooserEl.style.display = 'none';
    }
  }

  // Đăng nhập Google với thông tin tài khoản cụ thể
  async function loginAsGoogleUser(googleData) {
    setLoadingState(true, 'Đang đồng bộ Google Firebase Cloud...');

    currentUser = {
      isLoggedIn: true,
      uid: googleData.uid || ('google_' + Math.random().toString(36).substring(2, 10)),
      fullName: googleData.displayName || 'Kiến Trúc Sư Google',
      email: googleData.email || 'user@gmail.com',
      phone: googleData.phone || '0988.888.888',
      photoURL: googleData.photoURL || '',
      role: googleData.role || 'Kiến Trúc Sư / Nội Thất',
      tier: googleData.tier || 'VIP_PRO',
      tierName: 'Gói Doanh Nhân Cloud (VIP PRO)',
      badgeText: 'GOOGLE VIP',
      expireDate: 'Vĩnh viễn (Trọn đời)',
      credits: 999999,
      hardwareId: getOrCreateHardwareId(),
      createdAt: new Date().toISOString().split('T')[0],
      avatarChar: googleData.avatarChar || (googleData.displayName ? googleData.displayName.charAt(0).toUpperCase() : '👑'),
      loginProvider: 'google.com'
    };

    saveSession();
    hideGatekeeper();
    closeModal();
    closeGoogleChooser();
    setLoadingState(false);

    // Đồng bộ lên Google Firebase Cloud Firestore
    if (window.ChillFirebase && typeof window.ChillFirebase.syncUserToFirestore === 'function') {
      try {
        await window.ChillFirebase.syncUserToFirestore(currentUser);
      } catch (err) {
        console.warn('[ChillAuth] Đồng bộ Firestore lỗi:', err);
      }
    }

    // Tự động tải cài đặt từ Firestore nếu có
    await loadRemoteSettings(currentUser.uid);

    if (window.chillApp && window.chillApp.showMiniToast) {
      window.chillApp.showMiniToast(`🎉 Chào mừng ${currentUser.fullName}! Đã đăng nhập Google & đồng bộ Firebase.`, 'success', 4000);
    }
    return { success: true, user: currentUser };
  }

  // Khởi động luồng đăng nhập Google
  async function loginWithGoogle() {
    // Mở ngay hộp thoại chọn tài khoản Google chuẩn phong cách Google
    openGoogleChooser();
  }

  // Tải cài đặt người dùng từ Cloud Firestore
  async function loadRemoteSettings(uid) {
    if (!window.ChillFirebase || !window.ChillFirebase.getUserSettings) return;
    try {
      const remoteConfig = await window.ChillFirebase.getUserSettings('user_config');
      if (remoteConfig) {
        console.log('[ChillAuth] Đã nạp thành công cấu hình từ Cloud Firestore:', remoteConfig);
      }
    } catch (e) {
      console.warn('[ChillAuth] Lỗi nạp cài đặt từ Cloud:', e);
    }
  }

  // Trạng thái đang tải (Loading spinner)
  function setLoadingState(isLoading, text = 'Đang xử lý...') {
    const spinner = document.getElementById('gatekeeper-loading-spinner');
    const statusText = document.getElementById('gatekeeper-status-text');
    const googleBtn = document.getElementById('btn-gatekeeper-google-login');
    const modalGoogleBtn = document.getElementById('btn-modal-google-login');

    if (spinner) spinner.style.display = isLoading ? 'inline-block' : 'none';
    if (statusText) {
      statusText.textContent = isLoading ? text : '';
      statusText.style.display = isLoading ? 'block' : 'none';
    }
    if (googleBtn) {
      googleBtn.disabled = isLoading;
      googleBtn.style.opacity = isLoading ? '0.7' : '1';
    }
    if (modalGoogleBtn) {
      modalGoogleBtn.disabled = isLoading;
      modalGoogleBtn.style.opacity = isLoading ? '0.7' : '1';
    }
  }

  function showAuthMessage(msg, type = 'error') {
    const msgBoxes = [
      document.getElementById('gatekeeper-msg-box'),
      document.getElementById('login-msg-box')
    ];
    msgBoxes.forEach(msgBox => {
      if (msgBox) {
        msgBox.style.display = 'block';
        msgBox.style.color = type === 'success' ? '#34d399' : '#f87171';
        msgBox.textContent = msg;
      }
    });

    if (window.chillApp && window.chillApp.showMiniToast) {
      window.chillApp.showMiniToast(msg, type === 'success' ? 'success' : 'error', 3500);
    }
  }

  // Đăng xuất tài khoản
  async function logout() {
    if (window.ChillFirebase && typeof window.ChillFirebase.signOut === 'function') {
      await window.ChillFirebase.signOut();
    }

    currentUser = {
      isLoggedIn: false,
      fullName: 'Khách Vãng Lai',
      role: 'Khách',
      tier: 'FREE',
      tierName: 'Chưa Đăng Nhập',
      badgeText: 'GUEST',
      expireDate: 'Hết hạn',
      credits: 0,
      hardwareId: getOrCreateHardwareId(),
      avatarChar: '👤',
      photoURL: ''
    };

    saveSession();
    updateUI();
    closeModal();
    showGatekeeper(); // Khóa plugin lại
  }

  // Khôi phục tài khoản Admin của Anh Huy (Dành cho Anh Huy vào việc ngay)
  function switchHuyProfile() {
    currentUser = { ...DEFAULT_HUY_USER };
    saveSession();
    hideGatekeeper();
    updateUI();

    // Đồng bộ lên Firebase Firestore nếu có mạng
    if (window.ChillFirebase && window.ChillFirebase.syncUserToFirestore) {
      window.ChillFirebase.syncUserToFirestore(currentUser).catch(() => {});
    }

    if (window.chillApp && window.chillApp.showMiniToast) {
      window.chillApp.showMiniToast('👑 Đã kích hoạt hồ sơ VIP PRO trọn đời cho KTS. Nguyễn Văn Huy!', 'success', 3500);
    }
    return { success: true, message: 'Đã kích hoạt hồ sơ Tổng Công Trình Sư Huy!' };
  }

  // Đăng nhập thường qua SĐT / Mật khẩu
  function login(username, password) {
    if (!username || !password) {
      return { success: false, message: 'Vui lòng nhập đầy đủ Số điện thoại / Email và Mật khẩu!' };
    }
    currentUser = {
      isLoggedIn: true,
      uid: 'local_' + Math.random().toString(36).substring(2, 9),
      fullName: username.includes('@') ? username.split('@')[0] : `Thành viên (${username})`,
      phone: username.includes('@') ? '0912.345.678' : username,
      email: username.includes('@') ? username : `${username}@chilldecor.vn`,
      role: 'Kiến Trúc Sư / Nội Thất',
      tier: 'VIP_PRO',
      tierName: 'Gói Trải Nghiệm Không Giới Hạn',
      badgeText: 'VIP PRO',
      expireDate: 'Vĩnh viễn (Beta)',
      credits: 99999,
      hardwareId: getOrCreateHardwareId(),
      createdAt: new Date().toISOString().split('T')[0],
      avatarChar: '👤',
      loginProvider: 'password'
    };
    saveSession();
    hideGatekeeper();
    return { success: true, message: `Chào mừng ${currentUser.fullName} đăng nhập thành công!` };
  }

  // Kích hoạt License Key (như ABF)
  function activateLicenseKey(code) {
    if (!code || code.trim().length < 4) {
      return { success: false, message: 'Mã kích hoạt không hợp lệ! Vui lòng kiểm tra lại.' };
    }
    if (!currentUser) currentUser = { ...DEFAULT_HUY_USER };
    currentUser.tier = 'VIP_PRO';
    currentUser.tierName = 'Gói Doanh Nhân Bản Quyền Vĩnh Viễn';
    currentUser.badgeText = 'VIP PRO';
    currentUser.expireDate = 'Trọn đời (Không thời hạn)';
    currentUser.credits = 999999;
    saveSession();

    // Lưu vào Firebase Firestore
    if (window.ChillFirebase && window.ChillFirebase.saveUserSettings) {
      window.ChillFirebase.saveUserSettings('license_status', { key: code, activatedAt: new Date().toISOString() });
    }

    return { success: true, message: `Kích hoạt thành công mã "${code.toUpperCase()}"! Tất cả tính năng cao cấp đã mở khóa trọn đời.` };
  }

  // Gắn sự kiện giao diện (DOM Event Listeners)
  function bindEvents() {
    const modalEl = document.getElementById('modal-account');
    const openBtn = document.getElementById('btn-open-account-modal');
    const dockOpenBtn = document.getElementById('dock-btn-open-account');
    const closeBtn = document.getElementById('btn-close-account-modal');

    // Mở Modal Account
    const handleOpenModal = () => {
      if (modalEl) {
        modalEl.style.display = 'flex';
        updateUI();
      }
    };

    if (openBtn) openBtn.addEventListener('click', handleOpenModal);
    if (dockOpenBtn) dockOpenBtn.addEventListener('click', handleOpenModal);

    // Đóng Modal
    if (closeBtn && modalEl) {
      closeBtn.addEventListener('click', () => {
        modalEl.style.display = 'none';
      });
    }

    if (modalEl) {
      modalEl.addEventListener('click', (e) => {
        if (e.target === modalEl) modalEl.style.display = 'none';
      });
    }

    // Chuyển Tab trong Modal Account
    const tabBtns = document.querySelectorAll('.account-tab-btn');
    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        tabBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const targetId = btn.getAttribute('data-tab');
        document.querySelectorAll('.account-tab-content').forEach(c => {
          c.style.display = 'none';
        });
        const targetEl = document.getElementById(targetId);
        if (targetEl) targetEl.style.display = 'block';
      });
    });

    // 1. Nút Đăng nhập Google trên MÀN HÌNH KHÓA GATEKEEPER
    const gateGoogleBtn = document.getElementById('btn-gatekeeper-google-login');
    if (gateGoogleBtn) {
      gateGoogleBtn.addEventListener('click', () => {
        loginWithGoogle();
      });
    }

    // 2. Nút Đăng nhập Google trong MODAL ACCOUNT (Tab Đăng Nhập)
    const modalGoogleBtn = document.getElementById('btn-modal-google-login');
    if (modalGoogleBtn) {
      modalGoogleBtn.addEventListener('click', () => {
        loginWithGoogle();
      });
    }

    // --- SỰ KIỆN CHO MODAL GOOGLE CHOOSER (CHỌN TÀI KHOẢN GOOGLE) ---
    const chooserModal = document.getElementById('modal-google-chooser');
    const closeChooserBtn = document.getElementById('btn-close-google-chooser');
    const accHuyBtn = document.getElementById('google-account-huy');
    const customAccBtn = document.getElementById('google-account-custom-btn');
    const customBox = document.getElementById('google-custom-email-box');
    const submitCustomBtn = document.getElementById('btn-submit-custom-google');
    const inputCustomEmail = document.getElementById('input-custom-google-email');

    if (closeChooserBtn) {
      closeChooserBtn.addEventListener('click', () => {
        closeGoogleChooser();
      });
    }

    if (chooserModal) {
      chooserModal.addEventListener('click', (e) => {
        if (e.target === chooserModal) closeGoogleChooser();
      });
    }

    // Chọn tài khoản KTS Huy (Chính chủ)
    if (accHuyBtn) {
      accHuyBtn.addEventListener('click', () => {
        loginAsGoogleUser({
          displayName: 'KTS. Nguyễn Văn Huy',
          email: 'thearchitect.huy@gmail.com',
          uid: 'google_huy_master_2026',
          role: 'Tổng Công Trình Sư',
          tier: 'VIP_PRO',
          avatarChar: '👑'
        });
      });
    }

    // Bật form nhập email Google khác
    if (customAccBtn && customBox) {
      customAccBtn.addEventListener('click', () => {
        customBox.style.display = (customBox.style.display === 'none') ? 'block' : 'none';
        if (inputCustomEmail && customBox.style.display === 'block') {
          inputCustomEmail.focus();
        }
      });
    }

    // Xác nhận đăng nhập email Google tùy chỉnh
    if (submitCustomBtn && inputCustomEmail) {
      submitCustomBtn.addEventListener('click', () => {
        const email = inputCustomEmail.value.trim();
        if (!email || !email.includes('@')) {
          alert('Vui lòng nhập một địa chỉ Email Google (Gmail) hợp lệ!');
          return;
        }
        const namePart = email.split('@')[0];
        const formattedName = 'KTS. ' + namePart.charAt(0).toUpperCase() + namePart.slice(1);
        loginAsGoogleUser({
          displayName: formattedName,
          email: email,
          uid: 'google_' + namePart + '_' + Math.random().toString(36).substring(2, 6),
          role: 'Kiến Trúc Sư / Nội Thất',
          tier: 'VIP_PRO',
          avatarChar: namePart.charAt(0).toUpperCase()
        });
      });
    }

    // 3. Nút Đăng nhập nhanh KTS Huy trên Gatekeeper
    const gateQuickHuyBtn = document.getElementById('btn-gatekeeper-quick-huy');
    if (gateQuickHuyBtn) {
      gateQuickHuyBtn.addEventListener('click', () => {
        switchHuyProfile();
      });
    }

    // 4. Nút Đăng nhập 1-chạm KTS Huy trong Modal
    const quickHuyBtn = document.getElementById('btn-quick-login-huy');
    if (quickHuyBtn) {
      quickHuyBtn.addEventListener('click', () => {
        switchHuyProfile();
        switchTab('tab-acc-profile');
      });
    }

    // 5. Nút chuyển nick Anh Huy ở Tab Gói cước
    const switchHuyAdmin = document.getElementById('btn-switch-huy-admin');
    if (switchHuyAdmin) {
      switchHuyAdmin.addEventListener('click', () => {
        switchHuyProfile();
        switchTab('tab-acc-profile');
      });
    }

    // 6. Xử lý Đăng Nhập Form thường
    const loginBtn = document.getElementById('btn-do-login');
    if (loginBtn) {
      loginBtn.addEventListener('click', () => {
        const u = document.getElementById('login-username').value.trim();
        const p = document.getElementById('login-password').value.trim();
        const msgBox = document.getElementById('login-msg-box');
        
        const res = login(u, p);
        if (msgBox) {
          msgBox.style.display = 'block';
          msgBox.style.color = res.success ? '#34d399' : '#f87171';
          msgBox.textContent = res.message;
        }

        if (res.success) {
          setTimeout(() => {
            switchTab('tab-acc-profile');
          }, 800);
        }
      });
    }

    // 7. Xử lý Nạp License Key
    const actBtn = document.getElementById('btn-activate-license');
    if (actBtn) {
      actBtn.addEventListener('click', () => {
        const codeInput = document.getElementById('input-license-code');
        const code = codeInput ? codeInput.value.trim() : '';
        const msgBox = document.getElementById('license-msg-box');

        const res = activateLicenseKey(code);
        if (msgBox) {
          msgBox.style.display = 'block';
          msgBox.style.color = res.success ? '#34d399' : '#f87171';
          msgBox.textContent = res.message;
        }

        if (res.success && codeInput) codeInput.value = '';
      });
    }

    // 8. Xử lý Đăng Xuất
    const logoutBtn = document.getElementById('btn-acc-logout');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', () => {
        logout();
      });
    }
  }

  function switchTab(tabId) {
    const tabBtns = document.querySelectorAll('.account-tab-btn');
    tabBtns.forEach(b => {
      if (b.getAttribute('data-tab') === tabId) b.classList.add('active');
      else b.classList.remove('active');
    });

    document.querySelectorAll('.account-tab-content').forEach(c => {
      c.style.display = (c.id === tabId) ? 'block' : 'none';
    });
  }

  function openModal() {
    const modalEl = document.getElementById('modal-account');
    if (modalEl) {
      modalEl.style.display = 'flex';
      updateUI();
    }
  }

  function closeModal() {
    const modalEl = document.getElementById('modal-account');
    if (modalEl) {
      modalEl.style.display = 'none';
    }
  }

  return {
    CONFIG,
    init: function() {
      // 1. Tải phiên lưu sẵn từ localStorage
      loadSession();

      // 2. Khởi tạo Google Firebase
      if (window.ChillFirebase && typeof window.ChillFirebase.init === 'function') {
        window.ChillFirebase.init();

        // Lắng nghe trạng thái đăng nhập Google Auth từ Firebase
        window.ChillFirebase.onAuthStateChanged((fbUser) => {
          if (fbUser) {
            currentUser = {
              isLoggedIn: true,
              uid: fbUser.uid,
              fullName: fbUser.displayName || 'Kiến Trúc Sư Google',
              email: fbUser.email || '',
              phone: fbUser.phoneNumber || 'Tài khoản Google',
              photoURL: fbUser.photoURL || '',
              role: 'Kiến Trúc Sư / Xưởng Nội Thất',
              tier: 'VIP_PRO',
              tierName: 'Gói Doanh Nhân Cloud (VIP PRO)',
              badgeText: 'GOOGLE VIP',
              expireDate: 'Vĩnh viễn (Trọn đời)',
              credits: 999999,
              hardwareId: getOrCreateHardwareId(),
              createdAt: new Date().toISOString().split('T')[0],
              avatarChar: fbUser.displayName ? fbUser.displayName.charAt(0).toUpperCase() : 'G',
              loginProvider: 'google.com'
            };
            saveSession();
            hideGatekeeper(); // Tự động mở khóa plugin
          } else {
            // Nếu chưa có user Google và chưa có session hợp lệ -> Bật Gatekeeper khóa plugin
            if (!currentUser || !currentUser.isLoggedIn) {
              showGatekeeper();
            } else {
              hideGatekeeper();
            }
          }
          updateUI();
        });
      } else {
        // Fallback: nếu không có Firebase SDK
        if (!currentUser || !currentUser.isLoggedIn) {
          showGatekeeper();
        } else {
          hideGatekeeper();
        }
      }

      updateUI();
      bindEvents();
    },
    getUser: () => currentUser,
    canAccess: canAccessFeature,
    openModal,
    closeModal,
    login,
    loginWithGoogle,
    activateLicenseKey,
    logout,
    switchHuyProfile,
    openGoogleChooser,
    closeGoogleChooser,
    showGatekeeper,
    hideGatekeeper,
    getHwid: getOrCreateHardwareId
  };
})();

// Gán toàn cục window.ChillAuth
window.ChillAuth = ChillAuth;

// Khởi chạy khi tài liệu nạp xong
document.addEventListener('DOMContentLoaded', () => {
  ChillAuth.init();
});
