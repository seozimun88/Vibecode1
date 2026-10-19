/**
 * CHILL AI INTERIOR - ACCOUNT & LICENSING SYSTEM (HỆ THỐNG TÀI KHOẢN & BẢN QUYỀN)
 * Chuẩn mô hình ABF / One Click Cabinet / Unitool
 * Thiết kế cho The Architect (Anh Huy) - Mặc định mở khóa 100% (ALL_FREE)
 */

const ChillAuth = (function() {
  // Cấu hình kiểm soát bản quyền toàn hệ thống
  const CONFIG = {
    ALL_FREE: true, // Giai đoạn thử nghiệm: Miễn phí 100% tất cả tính năng cho anh Huy và người dùng
    APP_VERSION: 'v2.6.0 Pro',
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
  const DEFAULT_USER = {
    isLoggedIn: true,
    fullName: 'KTS. Nguyễn Văn Huy',
    phone: '0988.888.888',
    email: 'thearchitect.huy@gmail.com',
    role: 'Tổng Công Trình Sư',
    tier: 'VIP_PRO', // FREE, TRIAL, VIP_PRO
    tierName: 'Gói Doanh Nhân (VIP PRO)',
    badgeText: 'VIP PRO',
    expireDate: 'Vĩnh viễn (Trọn đời)',
    credits: 999999,
    hardwareId: getOrCreateHardwareId(),
    createdAt: '2026-10-12',
    avatarChar: '👑'
  };

  // Khởi tạo trạng thái phiên (Session)
  let currentUser = null;

  function loadSession() {
    const saved = localStorage.getItem('chill_user_session');
    if (saved) {
      try {
        currentUser = JSON.parse(saved);
      } catch (e) {
        currentUser = { ...DEFAULT_USER };
      }
    } else {
      // Mặc định đăng nhập sẵn tài khoản VIP cho anh Huy trải nghiệm trơn tru
      currentUser = { ...DEFAULT_USER };
      saveSession();
    }
    return currentUser;
  }

  function saveSession() {
    localStorage.setItem('chill_user_session', JSON.stringify(currentUser));
    updateUI();
  }

  // Cổng kiểm soát tính năng (Feature Gate)
  function canAccessFeature(featureKey, featureName = 'Tính năng') {
    if (CONFIG.ALL_FREE) {
      // Hiện tại miễn phí 100%
      return { allowed: true, reason: 'Chế độ thử nghiệm miễn phí toàn phần' };
    }

    if (!currentUser || !currentUser.isLoggedIn) {
      return { 
        allowed: false, 
        reason: 'Vui lòng đăng nhập tài khoản để sử dụng tính năng này.' 
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

    if (!currentUser || !currentUser.isLoggedIn) {
      if (nameEl) nameEl.textContent = 'Chưa Đăng Nhập';
      if (badgeEl) {
        badgeEl.textContent = 'FREE';
        badgeEl.className = 'account-tier-badge tier-guest';
      }
      if (avatarEl) avatarEl.textContent = '👤';
      return;
    }

    if (nameEl) nameEl.textContent = currentUser.fullName;
    if (avatarEl) avatarEl.textContent = currentUser.avatarChar || '👤';

    if (badgeEl) {
      badgeEl.textContent = currentUser.badgeText || 'VIP';
      badgeEl.className = `account-tier-badge tier-${currentUser.tier.toLowerCase()}`;
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

    if (pName) pName.textContent = currentUser.fullName;
    if (pRole) pRole.textContent = currentUser.role;
    if (pPhone) pPhone.textContent = currentUser.phone || 'Chưa cập nhật';
    if (pEmail) pEmail.textContent = currentUser.email || 'Chưa cập nhật';
    if (pHwid) pHwid.textContent = currentUser.hardwareId;
    if (pTier) pTier.textContent = currentUser.tierName;
    if (pExpire) pExpire.textContent = currentUser.expireDate;
    if (pCredits) pCredits.textContent = currentUser.credits.toLocaleString() + ' Điểm';
  }

  // Đăng nhập
  function login(username, password) {
    if (!username || !password) {
      return { success: false, message: 'Vui lòng nhập đầy đủ Số điện thoại / Email và Mật khẩu!' };
    }
    // Giả lập xác thực (hoặc kết nối Supabase sau này)
    currentUser = {
      isLoggedIn: true,
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
      avatarChar: '👤'
    };
    saveSession();
    return { success: true, message: `Chào mừng ${currentUser.fullName} đăng nhập thành công!` };
  }

  // Đăng ký
  function register(data) {
    if (!data.fullName || !data.phone || !data.password) {
      return { success: false, message: 'Vui lòng điền đủ Họ tên, Số điện thoại và Mật khẩu!' };
    }
    currentUser = {
      isLoggedIn: true,
      fullName: data.fullName,
      phone: data.phone,
      email: data.email || `${data.phone}@user.chillai`,
      role: data.role || 'Kiến Trúc Sư',
      tier: 'VIP_PRO', // Tặng ngay VIP PRO giai đoạn này
      tierName: 'Gói Tân Thủ VIP (Được tặng 100%)',
      badgeText: 'VIP PRO',
      expireDate: 'Vĩnh viễn (Beta Miễn Phí)',
      credits: 50000,
      hardwareId: getOrCreateHardwareId(),
      createdAt: new Date().toISOString().split('T')[0],
      avatarChar: '🌟'
    };
    saveSession();
    return { success: true, message: 'Tạo tài khoản thành công! Bạn đã được kích hoạt VIP PRO miễn phí.' };
  }

  // Kích hoạt License Key (như ABF)
  function activateLicenseKey(code) {
    if (!code || code.trim().length < 4) {
      return { success: false, message: 'Mã kích hoạt không hợp lệ! Vui lòng kiểm tra lại.' };
    }
    currentUser.tier = 'VIP_PRO';
    currentUser.tierName = 'Gói Doanh Nhân Bản Quyền Vĩnh Viễn';
    currentUser.badgeText = 'VIP PRO';
    currentUser.expireDate = 'Trọn đời (Không thời hạn)';
    currentUser.credits = 999999;
    saveSession();
    return { success: true, message: `Kích hoạt thành công mã "${code.toUpperCase()}"! Tất cả tính năng cao cấp đã mở khóa trọn đời.` };
  }

  // Đăng xuất
  function logout() {
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
      avatarChar: '👤'
    };
    saveSession();
  }

  // Khôi phục tài khoản Admin của Anh Huy
  function switchHuyProfile() {
    currentUser = { ...DEFAULT_USER };
    saveSession();
    return { success: true, message: 'Đã chuyển về hồ sơ Tổng Công Trình Sư Huy (Full Quyền VIP)!' };
  }

  // Gắn sự kiện giao diện (DOM Event Listeners)
  function bindEvents() {
    const modalEl = document.getElementById('modal-account');
    const openBtn = document.getElementById('btn-open-account-modal');
    const closeBtn = document.getElementById('btn-close-account-modal');

    // Mở / Đóng modal
    if (openBtn && modalEl) {
      openBtn.addEventListener('click', () => {
        modalEl.style.display = 'flex';
        updateUI();
      });
    }

    if (closeBtn && modalEl) {
      closeBtn.addEventListener('click', () => {
        modalEl.style.display = 'none';
      });
    }

    // Đóng khi click ngoài vùng modal
    if (modalEl) {
      modalEl.addEventListener('click', (e) => {
        if (e.target === modalEl) modalEl.style.display = 'none';
      });
    }

    // Chuyển Tab
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

    // Xử lý Đăng Nhập
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

    // Đăng nhập nhanh 1-chạm vào nick Anh Huy
    const quickHuyBtn = document.getElementById('btn-quick-login-huy');
    if (quickHuyBtn) {
      quickHuyBtn.addEventListener('click', () => {
        switchHuyProfile();
        switchTab('tab-acc-profile');
      });
    }

    // Nút chuyển nick Anh Huy ở Tab Gói cước
    const switchHuyAdmin = document.getElementById('btn-switch-huy-admin');
    if (switchHuyAdmin) {
      switchHuyAdmin.addEventListener('click', () => {
        switchHuyProfile();
        if (window.chillApp && window.chillApp.showMiniToast) {
          window.chillApp.showMiniToast('Đã kích hoạt hồ sơ VIP PRO trọn đời cho KTS. Nguyễn Văn Huy!', 'success', 3500);
        }
        switchTab('tab-acc-profile');
      });
    }

    // Xử lý Đăng Ký
    const regBtn = document.getElementById('btn-do-register');
    if (regBtn) {
      regBtn.addEventListener('click', () => {
        const name = document.getElementById('reg-fullname').value.trim();
        const phone = document.getElementById('reg-phone').value.trim();
        const role = document.getElementById('reg-role').value;
        const pass = document.getElementById('reg-password').value.trim();
        const msgBox = document.getElementById('reg-msg-box');

        const res = register({ fullName: name, phone, role, password: pass });
        if (msgBox) {
          msgBox.style.display = 'block';
          msgBox.style.color = res.success ? '#34d399' : '#f87171';
          msgBox.textContent = res.message;
        }

        if (res.success) {
          setTimeout(() => {
            switchTab('tab-acc-profile');
          }, 1000);
        }
      });
    }

    // Xử lý Nạp License Key
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

    // Xử lý Đăng Xuất
    const logoutBtn = document.getElementById('btn-acc-logout');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', () => {
        logout();
        switchTab('tab-acc-login');
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
      loadSession();
      updateUI();
      bindEvents();
    },
    getUser: () => currentUser,
    canAccess: canAccessFeature,
    openModal,
    closeModal,
    login,
    register,
    activateLicenseKey,
    logout,
    switchHuyProfile,
    getHwid: getOrCreateHardwareId
  };
})();

// Gán toàn cục window.ChillAuth để Co-Pilot và các module khác dễ dàng kích hoạt
window.ChillAuth = ChillAuth;

// Khởi chạy khi tài liệu nạp xong
document.addEventListener('DOMContentLoaded', () => {
  ChillAuth.init();
});
