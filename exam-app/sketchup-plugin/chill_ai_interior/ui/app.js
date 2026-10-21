// ==============================================================================
// Chill AI Interior - Main Application Logic & Bridge
// ==============================================================================

class ChillAIApp {
  constructor() {
    this.viewer = null;
    this.avatar = null;

    // Current State
    this.currentModel = {
      type: 'wardrobe',
      name: 'Tủ Quần Áo Chuẩn Xưởng CNC',
      length: 1200,
      width: 600,
      height: 1800,
      thickness: 18,
      material: 'oak',
      leg_style: 'metal_frame',
      drawers: 2,
      doors: 2,
      shelves: 3
    };

    this.geminiApiKey = localStorage.getItem('chill_ai_gemini_key') || '';
    let savedModel = localStorage.getItem('chill_ai_gemini_model') || 'gemini-3.5-flash';
    if (savedModel.includes('2.0') || savedModel.includes('1.5')) savedModel = 'gemini-3.5-flash';
    this.geminiModel = savedModel;
    this.dimensionMode = 'default'; // 'default' or 'custom'
    this.isSketchUpAvailable = !!window.sketchup;

    try {
      const cachedCabinet = localStorage.getItem('chill_ai_default_cabinet');
      if (cachedCabinet && (cachedCabinet.includes('1350') || cachedCabinet.includes('2000'))) {
        localStorage.removeItem('chill_ai_default_cabinet');
      }
    } catch (e) {}

    this.init();
  }

  init() {
    this.initHUDResizer();
    this.initStatusIndicator();
    this.initGeminiApiUI();
    this.initTabs();
    this.initImageDropzone();
    this.initAiOptionBar();
    this.initFloatingCustomPanel();
    this.initFormEvents();
    this.showAiOptions(false);
    this.initActionButtons();
    this.init3DViewer();
    this.initAvatar();
    this.initCAMNesting();
    this.initChatEvents();
    this.initMarketplace();
    this.initProjects();

    // Callbacks from SketchUp Ruby - Gán sớm nhất có thể để không bao giờ bỏ lỡ sự kiện
    window.chillApp = this;
    window.onSketchupSelectionChanged = (payload) => {
      console.log("[Chill AI] SketchUp selection event received:", payload);
      this.handleSketchupSelection(payload);
    };

    try { this.init3TierHierarchy(); } catch (e) { console.error("[Chill AI] Error in init3TierHierarchy:", e); }
    try { this.initDockModeToggle(); } catch (e) { console.error("[Chill AI] Error in initDockModeToggle:", e); }
    try { this.initStructuralEngine(); } catch (e) { console.error("[Chill AI] Error in initStructuralEngine:", e); }
    try { this.initAccordionTray(); } catch (e) { console.error("[Chill AI] Error in initAccordionTray:", e); }
    try { this.initShopeeMarketplace(); } catch (e) { console.error("[Chill AI] Error in initShopeeMarketplace:", e); }
    try { this.initFittingControls(); } catch (e) { console.error("[Chill AI] Error in initFittingControls:", e); }

    // Báo cho SketchUp Ruby biết JS đã sẵn sàng kết nối 2 chiều và đồng bộ kích thước chuẩn
    setTimeout(() => {
      if (window.sketchup && window.sketchup.app_ready) {
        const metrics = {
          availWidth: window.screen.availWidth || window.innerWidth,
          availHeight: window.screen.availHeight || window.innerHeight,
          screenWidth: window.screen.width,
          screenHeight: window.screen.height
        };
        window.sketchup.app_ready(JSON.stringify(metrics));
      } else if (window.sketchup && window.sketchup.get_current_selection) {
        window.sketchup.get_current_selection();
      }

      // Ép kích thước cửa sổ chuẩn ngay khi mở (Tránh bị Windows lưu kích thước cũ quá dài)
      const savedMode = localStorage.getItem('chill_layout_mode') || 'dock';
      const su = window.sketchup || (typeof sketchup !== 'undefined' ? sketchup : null);
      if (su && su.set_window_layout_mode) {
        su.set_window_layout_mode(savedMode === 'studio' ? 'studio' : 'dock_tray');
      }
    }, 200);

    // Kích hoạt cơ chế tự động đồng bộ vùng chọn SketchUp 2 chiều liên tục (Auto-Sync Polling)
    this.startSelectionPolling();

    window.onSketchUpModelCreated = (entityId) => {
      this.showMiniToast(`Đã dựng mô hình 3D vào SketchUp! (ID: #${entityId})`, 'success');
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `Tuyệt vời anh Huy ơi! Em đã dựng thành công đối tượng 3D #${entityId} vào bản vẽ SketchUp rồi nhé! ✨`);
      }
    };

    window.onDynamicComponentCreated = (entityId) => {
      this.showMiniToast(`Đã tạo Dynamic Component thành công! Dùng Interact Tool để mở/đóng.`, 'success');
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `Em đã tạo Dynamic Component với đầy đủ tham số đóng mở thông minh rồi anh Huy nhé! 📐`);
      }
    };

    window.onGCodeGenerated = (data) => {
      this.showMiniToast(`Đã hoàn tất tính toán Nesting và sinh mã CNC G-Code!`, 'info');
      this.displayNestingAndGCode(data);
      const pendingExport = this.pendingCamExport;
      this.pendingCamExport = null;
      if (pendingExport === 'gcode') this.saveGCodeFile();
      if (pendingExport === 'dxf') this.saveDxfFile();
    };

    window.onDxfExported = (result) => {
      this.showMiniToast(`Đã xuất ${result.total_parts || ''} chi tiết DXF sang Vectric Aspire thành công!`, 'success');
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `Anh Huy ơi! Em đã xuất xong sơ đồ ván DXF 2D rồi nhé. Anh chỉ cần mở Aspire, bấm Import Vectors là gán đường dao được ngay! 📐✨`);
      }
    };

    window.onNestingToSUCompleted = (result) => {
      if (result.status === 'success') {
        this.showMiniToast(result.message || `Đã trải phẳng ${result.total_sheets} khổ ván lên SketchUp!`, 'success');
        if (this.avatar) {
          this.avatar.setEmotion('happy');
          this.avatar.addMessage('bot', `Tuyệt vời anh Huy ơi! Em đã trải phẳng xong ${result.total_sheets} khổ ván tiêu chuẩn lên mặt bàn SketchUp kèm đầy đủ nhãn tên, kích thước và thớ gỗ rồi nhé! 🪵✨`);
        }
      } else {
        this.showMiniToast(`Lỗi trải phẳng SU: ${result.message}`, 'error');
      }
    };

    window.onFittingsApplied = (data) => {
      this.showMiniToast(data.message || `Đã tạo ${data.cams || 0} cụm cam chốt!`, 'success');
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `Tuyệt vời anh Huy ơi! ${data.message || 'Đã tạo xong cam chốt Minifix 15mm rồi nhé!'} 🔩✨`);
      }
    };

    window.onHingesApplied = (data) => {
      this.showMiniToast(data.message || `Đã tạo ${data.hinges || 0} chén bản lề!`, 'success');
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `Tuyệt vời anh Huy ơi! ${data.message || 'Đã tạo xong chén bản lề 35mm cho cánh tủ rồi nhé!'} 🚪✨`);
      }
    };

    window.onFittingsCleared = (data) => {
      this.showMiniToast(`Đã dọn sạch các lỗ khoan phụ kiện!`, 'info');
    };
  }

  initFittingControls() {
    const btnCams = document.getElementById('dock-btn-apply-cams');
    const btnHinges = document.getElementById('dock-btn-apply-hinges');
    const btnClear = document.getElementById('dock-btn-clear-fittings');

    if (btnCams) {
      btnCams.addEventListener('click', () => {
        if (this.isSketchUpAvailable && window.sketchup && window.sketchup.apply_cam_locks) {
          this.showMiniToast("Đang quét tiếp xúc và khoan lỗ Cam Chốt Minifix 15mm...", "info");
          window.sketchup.apply_cam_locks(JSON.stringify({}));
        } else {
          this.showMiniToast("Tính năng chỉ hoạt động bên trong SketchUp", "warning");
        }
      });
    }

    if (btnHinges) {
      btnHinges.addEventListener('click', () => {
        if (this.isSketchUpAvailable && window.sketchup && window.sketchup.apply_hinges) {
          this.showMiniToast("Đang khoan lỗ chén bản lề 35mm cho cánh tủ...", "info");
          window.sketchup.apply_hinges(JSON.stringify({}));
        } else {
          this.showMiniToast("Tính năng chỉ hoạt động bên trong SketchUp", "warning");
        }
      });
    }

    if (btnClear) {
      btnClear.addEventListener('click', () => {
        if (this.isSketchUpAvailable && window.sketchup && window.sketchup.clear_fittings) {
          window.sketchup.clear_fittings();
        }
      });
    }
  }

  initStatusIndicator() {
    const pill = document.getElementById('bridge-status-indicator');
    const text = document.getElementById('bridge-status-text');

    if (this.isSketchUpAvailable) {
      if(pill) pill.className = 'status-pill status-connected';
      if(text) text.textContent = 'Đã kết nối SketchUp Ruby API';
    } else {
      if(pill) pill.className = 'status-pill';
      if(text) text.textContent = 'Trình Mô Phỏng Trực Tiếp (Web Preview)';
    }
  }

  // --- GEMINI API KEY UI SETUP ---
  initGeminiApiUI() {
    const modal = document.getElementById('modal-api-key');
    const btnOpenHeader = document.getElementById('btn-open-api-modal');
    const btnOpenBanner = document.getElementById('btn-config-key');
    const btnClose = document.getElementById('btn-close-api-modal');
    const btnSave = document.getElementById('btn-save-gemini-key');
    const btnClear = document.getElementById('btn-clear-gemini-key');
    const inputKey = document.getElementById('input-gemini-key');
    const inputModel = document.getElementById('input-gemini-model');
    if (inputModel && this.geminiModel) inputModel.value = this.geminiModel;

        const updateBanner = () => {
      const dot = document.getElementById('api-status-dot');
      const label = document.getElementById('api-status-label');
      const desc = document.getElementById('api-status-desc');
      if (!dot || !label || !desc) return;
      
      const modelName = this.geminiModel === 'gemini-1.5-pro-latest' ? 'Gemma 4 Pro' : 'Gemma 4';

      const topBarStatus = document.getElementById('gemini-api-status');

      if (this.geminiApiKey) {
        dot.className = 'api-status-dot';
        label.textContent = `Chế độ AI: ${modelName} Vision (Đã kết nối Key)`;
        desc.textContent = `Mỗi khi kéo ảnh tải lên, hệ thống sẽ gọi trực tiếp mô hình ${modelName} để nhận diện thật!`;
        if (topBarStatus) {
          topBarStatus.innerHTML = '<span class="api-dot" style="background:#10b981;"></span> Sẵn Sàng (AI Online)';
        }
      } else {
        dot.className = 'api-status-dot no-key';
        label.textContent = 'Chế độ AI: Bản dùng thử (Demo Mockup)';
        desc.textContent = 'Chưa có API Key. Bấm "Cài đặt Key" để dán mã Google AI miễn phí và quét ảnh thật 100%.';
        if (topBarStatus) {
          topBarStatus.innerHTML = '<span class="api-dot no-key"></span> Chờ API Key';
        }
      }
    };

    const openModal = () => {
      if (inputKey) inputKey.value = this.geminiApiKey;
      if (modal) modal.style.display = 'flex';
    };

    if (btnOpenHeader) btnOpenHeader.addEventListener('click', openModal);
    if (btnOpenBanner) btnOpenBanner.addEventListener('click', openModal);
    if (btnClose) btnClose.addEventListener('click', () => { if (modal) modal.style.display = 'none'; });

        if (btnSave) {
      btnSave.addEventListener('click', () => {
        const val = inputKey.value.trim();
        if (val.length < 20) {
          this.showMiniToast('Lưu ý: Mã Google Gemini API Key thường có độ dài trên 20 ký tự!', 'warning', 3500);
        }
        this.geminiApiKey = val;
        localStorage.setItem('chill_ai_gemini_key', val);
        
        const inputModel = document.getElementById('input-gemini-model');
        if (inputModel) {
            this.geminiModel = inputModel.value;
            localStorage.setItem('chill_ai_gemini_model', this.geminiModel);
        }
        
        updateBanner();
        if (modal) modal.style.display = 'none';
        this.showMiniToast('Đã lưu Google AI API Key thành công!', 'success', 3000);
        if (this.avatar) {
          this.avatar.setEmotion('happy');
          this.avatar.addMessage('bot', `Tuyệt vời! ${modelName} AI đã kết nối thành công. Giờ bạn cứ tải ảnh chụp bất kỳ lên, mình sẽ nhận diện ngay lập tức!`);
        }
      });
    }

    if (btnClear) {
      btnClear.addEventListener('click', () => {
        this.geminiApiKey = '';
        localStorage.removeItem('chill_ai_gemini_key');
        if (inputKey) inputKey.value = '';
        updateBanner();
        if (modal) modal.style.display = 'none';
        this.showMiniToast('Đã xóa API Key. Hệ thống sẽ quay về chế độ mô phỏng mẫu.', 'info', 3000);
      });
    }

    updateBanner();
  }

  // --- TAB SWITCHING ---
  
  initHUDResizer() {
    const hud = document.getElementById('game-bottom-hud');
    const resizer = document.getElementById('hud-resizer');
    if (!hud || !resizer) return;

    let isResizing = false;

    resizer.addEventListener('mousedown', (e) => {
      isResizing = true;
      document.body.style.cursor = 'ns-resize';
    });

    document.addEventListener('mousemove', (e) => {
      if (!isResizing) return;
      // Calculate new height: viewport height - mouse Y
      let newHeight = window.innerHeight - e.clientY;
      if (newHeight < 150) newHeight = 150;
      if (newHeight > window.innerHeight * 0.8) newHeight = window.innerHeight * 0.8;
      
      hud.style.height = newHeight + 'px';
      document.documentElement.style.setProperty('--bottom-hud-height', newHeight + 'px');
      this.updateCommandGrid();
    });

    document.addEventListener('mouseup', () => {
      if (isResizing) {
        isResizing = false;
        document.body.style.cursor = '';
      }
    });

    const syncHudHeight = () => {
      const h = hud.offsetHeight || 200;
      document.documentElement.style.setProperty('--bottom-hud-height', h + 'px');
    };
    syncHudHeight();
    window.addEventListener('resize', syncHudHeight);

    // Pagination logic
    this.cmdCurrentPage = 0;
    const btnNext = document.getElementById('btn-cmd-next');
    const btnPrev = document.getElementById('btn-cmd-prev');
    
    btnNext?.addEventListener('click', () => {
      this.cmdCurrentPage++;
      this.updateCommandGrid();
    });
    btnPrev?.addEventListener('click', () => {
      this.cmdCurrentPage--;
      this.updateCommandGrid();
    });

    // Initial render
    setTimeout(() => this.updateCommandGrid(), 100);
    window.addEventListener('resize', () => this.updateCommandGrid());
  }

  updateCommandGrid() {
    const hud = document.getElementById('game-bottom-hud');
    const grid = document.getElementById('command-grid');
    if (!hud || !grid) return;

    const optionBar = document.getElementById('ai-option-bar') || document.querySelector('.game-minimap');
    const minimapHeight = optionBar ? optionBar.offsetHeight : 65;
    const padding = 20;
    const availableHeight = hud.clientHeight - minimapHeight - padding;
    
    // Each button is 48px + 6px gap = 54px
    let rows = Math.floor((availableHeight + 6) / 54);
    if (rows < 2) rows = 2; // Min 2 rows

    const slots = rows * 3;
    const realBtns = Array.from(document.querySelectorAll('.command-grid .real-btn'));
    const btnNext = document.getElementById('btn-cmd-next');
    const btnPrev = document.getElementById('btn-cmd-prev');

    // Hide all first
    realBtns.forEach(btn => btn.style.display = 'none');
    if (btnNext) btnNext.style.display = 'none';
    if (btnPrev) btnPrev.style.display = 'none';

    if (slots >= realBtns.length) {
      // Show all
      realBtns.forEach(btn => btn.style.display = 'flex');
      this.cmdCurrentPage = 0;
    } else {
      // Pagination needed
      const itemsPerPage = slots - 1; // Reserve 1 slot for Next/Prev
      const maxPage = Math.ceil(realBtns.length / itemsPerPage) - 1;
      
      if (this.cmdCurrentPage > maxPage) this.cmdCurrentPage = maxPage;
      if (this.cmdCurrentPage < 0) this.cmdCurrentPage = 0;

      const startIdx = this.cmdCurrentPage * itemsPerPage;
      const endIdx = startIdx + itemsPerPage;

      for (let i = startIdx; i < endIdx && i < realBtns.length; i++) {
        realBtns[i].style.display = 'flex';
      }

      if (this.cmdCurrentPage < maxPage && btnNext) {
        btnNext.style.display = 'flex';
      } else if (this.cmdCurrentPage > 0 && btnPrev) {
        btnPrev.style.display = 'flex';
      }
    }
  }

  initTabs() {
    const tabBtns = document.querySelectorAll('.tab-btn');
    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const targetId = btn.getAttribute('data-tab');
        this.switchTab(targetId);
      });
    });
  }

  switchTab(tabId) {
    this.currentActiveTab = tabId;
    document.querySelectorAll('.tab-btn').forEach(b => {
      b.classList.toggle('active', b.getAttribute('data-tab') === tabId);
    });

    document.querySelectorAll('.tab-pane').forEach(p => {
      const isActive = (p.id === tabId);
      p.classList.toggle('active', isActive);
      if (isActive) {
        p.style.display = (p.id === 'tab-chat') ? 'flex' : 'block';
      } else {
        p.style.display = 'none';
      }
    });

    // Đồng bộ hiển thị Avatar: nếu có đối tượng được chọn thì luôn hiện vật thể 3D theo yêu cầu anh Huy
    if (this.currentSelectionData) {
      this.updatePortraitView('object');
    } else {
      this.updatePortraitView('ai');
    }

    if (tabId === 'tab-cam' || tabId === 'tab-cam-cnc') {
      this.recalculateCAM();
    }
  }

  // --- 1. IMAGE DROPZONE & AI VISION SIMULATION ---
  initImageDropzone() {
    const dropZone = document.getElementById('drop-zone') || document.getElementById('btn-upload-trigger');
    const fileInput = document.getElementById('file-input') || document.getElementById('image-upload');
    const sampleBtns = document.querySelectorAll('.btn-sample');

    if(dropZone) dropZone.addEventListener('click', (e) => {
      if (e.target.tagName !== 'BUTTON' || (dropZone && dropZone.id === 'btn-upload-trigger') || e.target.closest('#btn-upload-trigger')) {
        fileInput.click();
      }
    });

    if(dropZone) dropZone.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropZone.classList.add('drag-over');
    });

    if(dropZone) dropZone.addEventListener('dragleave', () => {
      dropZone.classList.remove('drag-over');
    });

    if(dropZone) dropZone.addEventListener('drop', (e) => {
      e.preventDefault();
      dropZone.classList.remove('drag-over');
      if (e.dataTransfer.files && e.dataTransfer.files[0]) {
        this.processUploadedImage(e.dataTransfer.files[0]);
      }
    });

    if(fileInput) fileInput.addEventListener('change', (e) => {
      if (e.target.files && e.target.files[0]) {
        this.processUploadedImage(e.target.files[0]);
      }
    });

    sampleBtns.forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const sampleType = btn.getAttribute('data-sample');
        this.simulateSampleScan(sampleType);
      });
    });
  }

  processUploadedImage(file) {
    const reader = new FileReader();
    reader.onload = async (e) => {
      const dataUrl = e.target.result;

      // Nếu người dùng đã cài Gemini API Key -> Gửi lên Cloud AI phân tích thật
      if (this.geminiApiKey) {
        await this.scanWithGeminiVision(dataUrl);
      } else {
        // Nếu chưa cài Key: Hiển thị thông báo Toast và dùng mẫu mô phỏng sẵn
        this.showMiniToast('Đang quét ảnh mẫu Demo (Cài Gemini API Key để quét ảnh thật)', 'info', 4000);
        this.detectFurnitureAI(dataUrl, 'desk');
      }
    };
    reader.readAsDataURL(file);
  }

  // --- GOOGLE GEMMA 4 / GEMINI VISION CLOUD AI CALL ---
  async getBestGeminiEndpoint() {
    return `https://generativelanguage.googleapis.com/v1beta/models/${this.geminiModel || 'gemini-3.5-flash'}:generateContent`;
  }

  // Thuật toán bóc tách đúng khối JSON đầu tiên, bỏ qua mọi ghi chú thừa và chống lỗi position
  extractJsonObject(text) {
    if (!text) return null;
    const startIndex = text.indexOf('{');
    if (startIndex === -1) return null;

    let depth = 0;
    let inString = false;
    let escape = false;

    for (let i = startIndex; i < text.length; i++) {
      const char = text[i];

      if (escape) {
        escape = false;
        continue;
      }

      if (char === '\\') {
        escape = true;
        continue;
      }

      if (char === '"') {
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (char === '{') {
          depth++;
        } else if (char === '}') {
          depth--;
          if (depth === 0) {
            return text.substring(startIndex, i + 1);
          }
        }
      }
    }
    return null;
  }

  async scanWithGeminiVision(dataUrl) {
    const spinner = document.getElementById('scan-loading-spinner');
    const content = document.getElementById('drop-zone-content');

    try {
      if (spinner && content) {
        spinner.style.display = 'flex';
        content.style.display = 'none';
      }

      if (this.avatar) {
        this.avatar.setEmotion('thinking');
        this.avatar.addMessage('bot', 'Đang gửi ảnh lên Google Gemma 4 AI để nhận diện kết cấu và kích thước... Đợi mình khoảng 1 giây nhé! ✨');
      }

      // Trích xuất mime_type và chuỗi base64 thuần
      const match = dataUrl.match(/^data:(image\/[a-zA-Z+]+);base64,(.+)$/);
      if (!match) throw new Error('Định dạng ảnh không hợp lệ.');
      const mimeType = match[1];
      const base64Data = match[2];

      const prompt = `
Bạn là chuyên gia thiết kế kiến trúc nội thất và kỹ sư bóc tách gỗ công nghiệp hàng đầu.
Hãy quan sát kỹ bức ảnh này và phân tích món đồ nội thất chính trong ảnh.
Xác định loại vật thể và ước lượng kích thước tiêu chuẩn thực tế (tính bằng milimet - mm) phù hợp nhân trắc học.

BẮT BUỘC TRẢ VỀ DUY NHẤT MỘT ĐỐI TƯỢNG JSON HỢP LỆ (không có markdown giải thích thừa, không bọc dấu backtick, không có chữ json):
{
  "type": "cabinet",
  "name": "Tên chi tiết món đồ bằng tiếng Việt (Ví dụ: Tủ quần áo 3 cánh 2 ngăn kéo)",
  "category": "Tủ quần áo (Wardrobe)",
  "defLength": 1200,
  "defWidth": 600,
  "defHeight": 1800,
  "thickness": 17.5,
  "material": "oak",
  "leg_style": "panel_legs",
  "doors": 3,
  "drawers": 2,
  "door_material": "same_as_body"
}
Quy tắc kích thước và bóc tách kết cấu từ ảnh:
- "type": chỉ chọn 1 trong 5 loại: "cabinet", "desk", "shelf", "bed", "kitchen_cabinet".
- ĐẶC BIỆT KHI LÀ TỦ QUẦN ÁO ("cabinet"): Kích thước tiêu chuẩn nhân trắc học mặc định BẮT BUỘC là Dài 1200mm (1m2), Rộng/Sâu 600mm, Cao 1800mm (1m8) (defLength: 1200, defWidth: 600, defHeight: 1800).
- "doors": Nếu là tủ áo, hãy đếm chính xác số cánh cửa (mặc định 3 cánh).
- "drawers": Đếm chính xác số hộc ngăn kéo (mặc định 2 ngăn kéo).
- "kitchen_shape": Nếu là tủ bếp, xác định hình dáng tủ bếp là chữ "I" hay chữ "L".
- "has_upper" / "has_lower": Nếu là tủ bếp, xác định xem ảnh có tủ bếp trên (true/false) và tủ bếp dưới (true/false) hay không.
- "backsplash_color": Nếu là tủ bếp, xác định màu của mặt kính ốp tường (ví dụ: "green_glass", "white", "black"...).
- "material": Chọn đúng màu vật liệu thấy trong ảnh: "oak" (vân sồi sáng), "walnut" (óc chó), "white_melamine" (trắng).
- "door_material": Cánh tủ cùng màu thân thì "same_as_body", trắng thì "white_melamine".
- "leg_style": chỉ chọn: "metal_frame", "wooden_legs", "panel_legs".
`;

      const requestBody = JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inline_data: { mime_type: mimeType, data: base64Data } }
          ]
        }],
        generationConfig: {
          temperature: 0.2
        }
      });

      const reqHeaders = {
        'Content-Type': 'application/json',
        'x-goog-api-key': this.geminiApiKey
      };

      // 1. Lấy endpoint tốt nhất
      let targetEndpoint = await this.getBestGeminiEndpoint();
      let response = await fetch(targetEndpoint, {
        method: 'POST',
        headers: reqHeaders,
        body: requestBody
      });

      // 2. Nếu model ban đầu bị lỗi (not found hoặc rate limit), tự động thử danh sách model dự phòng
      if (!response.ok) {
        const fallbackCandidates = [
          'models/gemini-3.5-flash',
          'models/gemini-3.8-flash',
          'models/gemini-3.5-flash-lite'
        ];

        for (const modelCandidate of fallbackCandidates) {
          const fallbackEndpoint = `https://generativelanguage.googleapis.com/v1beta/${modelCandidate}:generateContent`;
          if (fallbackEndpoint === targetEndpoint) continue;

          console.log(`Đang thử model dự phòng: ${modelCandidate}`);
          const fbRes = await fetch(fallbackEndpoint, {
            method: 'POST',
            headers: reqHeaders,
            body: requestBody
          });

          if (fbRes.ok) {
            response = fbRes;
            break;
          }
        }
      }

      if (!response.ok) {
        const errJson = await response.json().catch(() => ({}));
        throw new Error(errJson.error?.message || `Lỗi máy chủ Google AI / Gemma 4 (HTTP ${response.status})`);
      }

      const resData = await response.json();
      const rawText = resData.candidates?.[0]?.content?.parts?.[0]?.text || '';
      console.log('AI Response Raw Text:', rawText);
      
      // Bóc tách chính xác khối JSON đầu tiên bằng thuật toán đếm ngoặc cân bằng
      let jsonStr = this.extractJsonObject(rawText);
      if (!jsonStr) {
        // Fallback: Thử lấy chuỗi giữa { và }
        const match = rawText.match(/\{[\s\S]*?\}/);
        jsonStr = match ? match[0] : rawText;
      }

      // Xóa các dấu phẩy thừa trước dấu đóng ngoặc (trailing comma) nếu có
      jsonStr = jsonStr.replace(/,\s*([\}\]])/g, '$1').trim();

      const parsed = JSON.parse(jsonStr);

      // Trích xuất số cánh và ngăn kéo với cơ chế thông minh
      let doors = parsed.doors;
      if (!doors && parsed.name) {
        const m = parsed.name.match(/(\d+)\s*cánh/i);
        if (m) doors = parseInt(m[1], 10);
      }
      doors = doors || (parsed.type === 'cabinet' ? 3 : 2);

      let drawers = parsed.drawers;
      if (drawers === undefined && parsed.name) {
        const m = parsed.name.match(/(\d+)\s*(ngăn kéo|hộc)/i);
        if (m) drawers = parseInt(m[1], 10);
      }
      drawers = drawers !== undefined ? drawers : 0;

      let doorMaterial = parsed.door_material || 'same_as_body';

      // Cập nhật sẵn các trường tinh chỉnh vào giao diện
      if (parsed.thickness) document.getElementById('select-thickness').value = parsed.thickness;
      if (parsed.material) document.getElementById('select-material').value = parsed.material;
      if (parsed.leg_style) document.getElementById('select-leg-style').value = parsed.leg_style;
      if (document.getElementById('input-doors')) document.getElementById('input-doors').value = doors;
      if (document.getElementById('input-drawers')) document.getElementById('input-drawers').value = drawers;
      if (document.getElementById('select-door-material')) document.getElementById('select-door-material').value = doorMaterial;

      // Kích thước chuẩn xưởng mộc theo yêu cầu của anh Huy: Dài 1200mm, Rộng 600mm, Cao 1800mm
      let finalL = parsed.defLength || 1200;
      let finalW = parsed.defWidth || 600;
      let finalH = parsed.defHeight || 1800;

      if (parsed.type === 'cabinet' || parsed.type === 'wardrobe') {
        if (!parsed.defLength || Math.abs(parsed.defLength - 1350) < 250 || Math.abs(parsed.defLength - 1200) < 200) {
          finalL = 1200;
        }
        if (!parsed.defWidth || Math.abs(parsed.defWidth - 600) < 100) {
          finalW = 600;
        }
        if (!parsed.defHeight || Math.abs(parsed.defHeight - 1800) < 300 || parsed.defHeight === 2000) {
          finalH = 1800;
        }
      }

      // Hiển thị kết quả vào khối nhận diện
      this.detectFurnitureAI(
        dataUrl,
        parsed.type || 'cabinet',
        parsed.name || 'Tủ Quần Áo Chuẩn Xưởng CNC',
        parsed.category || 'Tủ quần áo (Wardrobe)',
        finalL,
        finalW,
        finalH,
        doors,
        drawers,
        doorMaterial
      );
      
      if (parsed.type === 'kitchen_cabinet') {
        this.currentModel.kitchen_shape = parsed.kitchen_shape || "L";
        this.currentModel.has_upper = parsed.has_upper !== false;
        this.currentModel.has_lower = parsed.has_lower !== false;
        this.currentModel.backsplash_color = parsed.backsplash_color || "green_glass";
        
        let kitchenDetails = `Kiểu: Chữ ${this.currentModel.kitchen_shape.toUpperCase()}`;
        if (this.currentModel.has_upper && this.currentModel.has_lower) kitchenDetails += " | Có tủ trên & dưới";
        else if (this.currentModel.has_upper) kitchenDetails += " | Chỉ có tủ trên";
        else if (this.currentModel.has_lower) kitchenDetails += " | Chỉ có tủ dưới";
        kitchenDetails += ` | Kính ốp: ${this.currentModel.backsplash_color} (cao 600-650mm)`;
        
        const specsEl = document.getElementById('default-specs-display');
        if (specsEl) specsEl.textContent += ` | ${kitchenDetails}`;
        
        this.update3DAndCAM();
      }

      if (this.avatar) {
        this.avatar.setEmotion('excited');
        this.avatar.addMessage('bot', `✨ Google Gemma 4 AI đã phân tích xong: <strong>${parsed.name}</strong> với kích thước chuẩn ${parsed.defLength}x${parsed.defWidth}x${parsed.defHeight}mm!`);
      }

    } catch (err) {
      console.error('Lỗi Gemma 4 Vision:', err);
      this.showMiniToast(`Không thể nhận diện bằng AI: ${err.message}. Đang dùng dữ liệu mẫu.`, 'warning', 4000);
      this.detectFurnitureAI(dataUrl, 'desk');
    } finally {
      if (spinner && content) {
        spinner.style.display = 'none';
        content.style.display = 'block';
      }
    }
  }

  simulateSampleScan(type) {
    const samples = {
      desk: {
        name: 'Bàn làm việc gỗ sồi chân sắt hiện đại',
        category: 'Bàn làm việc (Desk / Work Table)',
        type: 'desk',
        defLength: 1200, defWidth: 600, defHeight: 750,
        img: 'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?w=300&q=80'
      },
      cabinet: {
        name: 'Tủ quần áo 2 cánh Melamine tối giản',
        category: 'Tủ quần áo (Wardrobe)',
        type: 'cabinet',
        defLength: 1200, defWidth: 600, defHeight: 1800,
        img: 'https://images.unsplash.com/photo-1558997519-83ea9252def8?w=300&q=80'
      },
      shelf: {
        name: 'Kệ sách trang trí 3 tầng Scandinavian',
        category: 'Kệ sách / Tủ trang trí (Bookshelf)',
        type: 'shelf',
        defLength: 1000, defWidth: 350, defHeight: 1200,
        img: 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=300&q=80'
      },
      bed: {
        name: 'Giường ngủ thông minh kiểu Nhật (Japandi Bed)',
        category: 'Giường ngủ (Bed)',
        type: 'bed',
        defLength: 1800, defWidth: 2000, defHeight: 400,
        img: 'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=300&q=80'
      }
    };

    const s = samples[type] || samples.desk;
    this.detectFurnitureAI(s.img, s.type, s.name, s.category, s.defLength, s.defWidth, s.defHeight);
  }

  detectFurnitureAI(imageSrc, type, name = 'Bàn làm việc gỗ sồi', category = 'Bàn làm việc', defL = 1200, defW = 600, defH = 750, doors = 2, drawers = 0, doorMaterial = 'same_as_body') {
    const imgEl = document.getElementById('scanned-image-preview');
    if (imgEl) imgEl.src = imageSrc;

    this.currentModel.type = type;
    this.currentModel.name = name;
    this.currentModel.length = defL;
    this.currentModel.width = defW;
    this.currentModel.height = defH;
    this.currentModel.doors = doors;
    this.currentModel.drawers = drawers;
    this.currentModel.door_material = doorMaterial;
    if (document.getElementById('select-material')) {
      this.currentModel.material = document.getElementById('select-material').value || 'oak';
    }

    // Build 3 smart presets for this detected furniture
    this.currentPresets = this.getPresetsForType(type);
    if (this.currentPresets && this.currentPresets.length > 0) {
      this.currentPresets[0].length = defL;
      this.currentPresets[0].width = defW;
      this.currentPresets[0].height = defH;
      this.currentPresets[0].cat = category;
      this.currentPresets[0].doors = doors;
      this.currentPresets[0].drawers = drawers;
    }
    this.currentPresetIndex = 0;

    // Update input fields
    document.getElementById('input-length').value = defL;
    document.getElementById('input-width').value = defW;
    document.getElementById('input-height').value = defH;
    if (document.getElementById('input-doors')) document.getElementById('input-doors').value = doors;
    if (document.getElementById('input-drawers')) document.getElementById('input-drawers').value = drawers;
    if (document.getElementById('select-door-material')) document.getElementById('select-door-material').value = doorMaterial;

    // Update UI components
    this.updateAiOptionBarUI();
    this.updateDefaultProfileUI();
    this.showAiOptions(true);
    this.selectOptionMode('default');
    this.syncFloatingInputs();
    this.update3DAndCAM();

    if (this.avatar) {
      this.avatar.setEmotion('excited');
      this.avatar.addMessage('bot', `✨ AI đã nhận diện món đồ: <strong>${name}</strong>!<br>Đang áp dụng <em>Phương án 1 (Mặc định ${defL}x${defW}x${defH}mm)</em>. Bạn có thể bấm <strong>[▶ Tiếp]</strong> trên thanh tùy chọn đen để đổi mẫu, hoặc bấm <strong>[2. Tùy Chỉnh]</strong> để tự do sửa số đo nhé!`);
    }
  }

  // --- 2. AI OPTION BAR & PRESETS LOGIC ---
  initAiOptionBar() {
    this.currentPresetIndex = 0;
    this.currentPresets = this.getPresetsForType(this.currentModel.type || 'desk');

    const btnOptDefault = document.getElementById('btn-opt-default');
    const btnOptCustom = document.getElementById('btn-opt-custom');
    const btnOptNext = document.getElementById('btn-opt-next');

    const btnSaveAsDefault = document.getElementById('btn-save-as-default');
    const btnSaveCustomAsDefault = document.getElementById('btn-save-custom-as-default');
    const btnResetDefaultsTab = document.getElementById('btn-reset-defaults-tab');
    const btnSwitchToCustom = document.getElementById('btn-switch-to-custom');
    const btnBuildFromDefault = document.getElementById('btn-build-from-default');

    // 1. Click [1. Mặc Định]
    if (btnOptDefault) {
      btnOptDefault.addEventListener('click', () => {
        this.showAiOptions(true);
    this.selectOptionMode('default');
      });
    }

    // 2. Click [2. Tùy Chỉnh]
    if (btnOptCustom) {
      btnOptCustom.addEventListener('click', () => {
        this.selectOptionMode('custom');
      });
    }

    // 3. Click [▶ Tiếp]
    if (btnOptNext) {
      btnOptNext.addEventListener('click', () => {
        this.nextAiPreset();
      });
    }

    // Buttons inside Tabs
    if (btnSwitchToCustom) {
      btnSwitchToCustom.addEventListener('click', () => {
        this.selectOptionMode('custom');
      });
    }

    if (btnBuildFromDefault) {
      btnBuildFromDefault.addEventListener('click', () => {
        this.sendToSketchUp('create_3d_model', this.currentModel);
      });
    }

    if (btnSaveAsDefault) {
      btnSaveAsDefault.addEventListener('click', () => {
        this.saveCurrentAsDefaultPreset();
      });
    }

    if (btnSaveCustomAsDefault) {
      btnSaveCustomAsDefault.addEventListener('click', () => {
        this.saveCurrentAsDefaultPreset();
      });
    }

    if (btnResetDefaultsTab) {
      btnResetDefaultsTab.addEventListener('click', () => {
        this.resetToInitialDefault();
      });
    }

    // Initial render
    this.updateAiOptionBarUI();
    this.updateDefaultProfileUI();
  }

  // Alias for backward compatibility
  initChoiceModes() {
    this.initAiOptionBar();
  }

  getPresetsForType(type) {
    const catalog = {
      desk: [
        { name: 'Tiêu Chuẩn (1200x600)', tag: 'Phương Án 1: Tiêu Chuẩn', length: 1200, width: 600, height: 750, thickness: 18, material: 'oak', leg_style: 'metal_frame', doors: 0, drawers: 2, style: 'Hiện đại Scandinavian', cat: 'Bàn làm việc (Desk)' },
        { name: 'Gọn Gàng (1000x500)', tag: 'Phương Án 2: Gọn Gàng', length: 1000, width: 500, height: 750, thickness: 18, material: 'white_melamine', leg_style: 'wooden_legs', doors: 0, drawers: 1, style: 'Tối giản Minimalist', cat: 'Bàn làm việc nhỏ' },
        { name: 'Cỡ Lớn (1600x800)', tag: 'Phương Án 3: Rộng Rãi', length: 1600, width: 800, height: 750, thickness: 25, material: 'walnut', leg_style: 'metal_frame', doors: 0, drawers: 3, style: 'Executive / Bàn Lớn', cat: 'Bàn giám đốc / Bàn họp nhỏ' }
      ],
      cabinet: [
        { name: 'Chuẩn Xưởng (1200x600x1800)', tag: 'Phương Án 1: Tiêu Chuẩn', length: 1200, width: 600, height: 1800, thickness: 17.5, material: 'white_melamine', leg_style: 'plinth', doors: 3, drawers: 2, style: 'Hiện đại Tối giản', cat: 'Tủ quần áo 1m2 x 1m8' },
        { name: 'Gọn Gàng (1000x550)', tag: 'Phương Án 2: Gọn Gàng', length: 1000, width: 550, height: 2000, thickness: 18, material: 'oak', leg_style: 'plinth', doors: 2, drawers: 2, style: 'Bắc Âu ấm cúng', cat: 'Tủ phòng nhỏ' },
        { name: '3 Cánh Lớn (1600x600)', tag: 'Phương Án 3: Cỡ Lớn', length: 1600, width: 600, height: 2200, thickness: 18, material: 'walnut', leg_style: 'plinth', doors: 3, drawers: 2, style: 'Cao cấp kịch trần', cat: 'Tủ quần áo 3 cánh' }
      ],
      shelf: [
        { name: 'Tiêu Chuẩn (1000x350)', tag: 'Phương Án 1: Tiêu Chuẩn', length: 1000, width: 350, height: 1200, thickness: 18, material: 'oak', leg_style: 'wooden_legs', doors: 0, drawers: 0, style: 'Kệ sách Bắc Âu', cat: 'Kệ sách 3 tầng' },
        { name: 'Gọn Gàng (800x300)', tag: 'Phương Án 2: Gọn Gàng', length: 800, width: 300, height: 900, thickness: 18, material: 'white_melamine', leg_style: 'metal_frame', doors: 0, drawers: 0, style: 'Tối giản treo tường', cat: 'Kệ treo tường nhỏ' },
        { name: 'Kịch Trần (1400x350)', tag: 'Phương Án 3: Cỡ Lớn', length: 1400, width: 350, height: 2000, thickness: 18, material: 'walnut', leg_style: 'panel_legs', doors: 2, drawers: 2, style: 'Kệ trang trí lớn', cat: 'Kệ sách kịch trần' }
      ],
      bed: [
        { name: 'Queen 1m6 (1600x2000)', tag: 'Phương Án 1: 1m6 x 2m', length: 1600, width: 2000, height: 400, thickness: 18, material: 'oak', leg_style: 'wooden_legs', doors: 0, drawers: 2, style: 'Japandi gỗ sồi', cat: 'Giường ngủ Queen' },
        { name: 'King 1m8 (1800x2000)', tag: 'Phương Án 2: 1m8 x 2m', length: 1800, width: 2000, height: 400, thickness: 18, material: 'walnut', leg_style: 'wooden_legs', doors: 0, drawers: 2, style: 'Hiện đại sang trọng', cat: 'Giường ngủ King' },
        { name: 'Single 1m2 (1200x2000)', tag: 'Phương Án 3: Giường đơn', length: 1200, width: 2000, height: 400, thickness: 18, material: 'white_melamine', leg_style: 'panel_legs', doors: 0, drawers: 1, style: 'Tiết kiệm diện tích', cat: 'Giường đơn 1m2' }
      ]
    };

    if (catalog[type]) return JSON.parse(JSON.stringify(catalog[type]));

    const baseL = this.currentModel.length || 1200;
    const baseW = this.currentModel.width || 600;
    const baseH = this.currentModel.height || 750;
    return [
      { name: `Tiêu Chuẩn (${baseL}x${baseW})`, tag: 'Phương Án 1: Tiêu Chuẩn', length: baseL, width: baseW, height: baseH, thickness: 18, material: 'oak', leg_style: 'metal_frame', doors: 2, drawers: 0, style: 'Hiện đại tiêu chuẩn', cat: this.currentModel.name || 'Nội thất' },
      { name: `Gọn Gàng (${Math.round(baseL*0.85)}x${Math.round(baseW*0.9)})`, tag: 'Phương Án 2: Gọn Gàng', length: Math.round(baseL*0.85), width: Math.round(baseW*0.9), height: baseH, thickness: 18, material: 'white_melamine', leg_style: 'wooden_legs', doors: 2, drawers: 0, style: 'Tối giản gọn gàng', cat: this.currentModel.name || 'Nội thất' },
      { name: `Cỡ Lớn (${Math.round(baseL*1.25)}x${Math.round(baseW*1.1)})`, tag: 'Phương Án 3: Cỡ Lớn', length: Math.round(baseL*1.25), width: Math.round(baseW*1.1), height: baseH, thickness: 25, material: 'walnut', leg_style: 'metal_frame', doors: 3, drawers: 2, style: 'Rộng rãi cao cấp', cat: this.currentModel.name || 'Nội thất' }
    ];
  }

  selectOptionMode(mode) {
    this.dimensionMode = mode;
    const btnOptDefault = document.getElementById('btn-opt-default');
    const btnOptCustom = document.getElementById('btn-opt-custom');

    if (mode === 'default') {
      btnOptDefault?.classList.add('active');
      btnOptCustom?.classList.remove('active');
      this.switchTab('tab-scan');
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `📋 Đã mở <strong>Hồ Sơ Mặc Định</strong>: Phương án chuẩn nhân trắc học (${this.currentModel.length}x${this.currentModel.width}x${this.currentModel.height}mm).`);
      }
    } else {
      btnOptCustom?.classList.add('active');
      btnOptDefault?.classList.remove('active');
      this.switchTab('tab-edit');
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `🛠️ Đã mở <strong>Tùy Chỉnh Kỹ Thuật</strong>: Bạn có thể tự do chỉnh kích thước, chiều dày ván, số cánh, hộc kéo và chân đế.`);
      }
    }
  }

  nextAiPreset() {
    if (!this.currentPresets || this.currentPresets.length === 0) {
      this.currentPresets = this.getPresetsForType(this.currentModel.type || 'desk');
    }
    this.currentPresetIndex = (this.currentPresetIndex + 1) % this.currentPresets.length;
    const p = this.currentPresets[this.currentPresetIndex];

    this.currentModel.length = p.length;
    this.currentModel.width = p.width;
    this.currentModel.height = p.height;
    if (p.thickness) this.currentModel.thickness = p.thickness;
    if (p.material) this.currentModel.material = p.material;
    if (p.leg_style) this.currentModel.leg_style = p.leg_style;
    if (p.doors !== undefined) this.currentModel.doors = p.doors;
    if (p.drawers !== undefined) this.currentModel.drawers = p.drawers;

    document.getElementById('input-length').value = p.length;
    document.getElementById('input-width').value = p.width;
    document.getElementById('input-height').value = p.height;
    if (document.getElementById('select-thickness') && p.thickness) document.getElementById('select-thickness').value = p.thickness;
    if (document.getElementById('select-material') && p.material) document.getElementById('select-material').value = p.material;
    if (document.getElementById('select-leg-style') && p.leg_style) document.getElementById('select-leg-style').value = p.leg_style;
    if (document.getElementById('input-doors') && p.doors !== undefined) document.getElementById('input-doors').value = p.doors;
    if (document.getElementById('input-drawers') && p.drawers !== undefined) document.getElementById('input-drawers').value = p.drawers;

    this.updateAiOptionBarUI();
    this.updateDefaultProfileUI(p);
    this.syncFloatingInputs();
    this.update3DAndCAM();

    if (this.avatar) {
      this.avatar.setEmotion('excited');
      this.avatar.addMessage('bot', `⚡ Đã chuyển sang <strong>${p.tag}</strong>: Kích thước ${p.length}x${p.width}x${p.height}mm (${p.name}).`);
    }
  }

  updateAiOptionBarUI() {
    const dimEl = document.getElementById('opt-default-dim');
    const counterEl = document.getElementById('ai-preset-counter');
    if (!this.currentPresets) this.currentPresets = this.getPresetsForType(this.currentModel.type || 'desk');

    const cur = this.currentPresets[this.currentPresetIndex] || this.currentPresets[0];
    if (dimEl && cur) {
      dimEl.textContent = `${cur.length}x${cur.width}`;
    }
    if (counterEl) {
      counterEl.textContent = `${this.currentPresetIndex + 1}/${this.currentPresets.length}`;
    }
  }

  updateDefaultProfileUI(preset) {
    const p = preset || (this.currentPresets ? this.currentPresets[this.currentPresetIndex] : null);
    if (!p) return;

    const tagEl = document.getElementById('current-preset-tag');
    const nameEl = document.getElementById('detected-object-name');
    const catEl = document.getElementById('detected-category');
    const styleEl = document.getElementById('detected-style');
    const matEl = document.getElementById('detected-material');
    const specsEl = document.getElementById('default-specs-display');
    const structEl = document.getElementById('default-structure-display');

    if (tagEl) tagEl.textContent = p.tag || `Phương Án ${this.currentPresetIndex + 1}`;
    if (nameEl && p.cat) nameEl.textContent = p.cat;
    if (catEl && p.cat) catEl.textContent = p.cat;
    if (styleEl && p.style) styleEl.textContent = p.style;

    const matNames = { oak: 'Gỗ Sồi tự nhiên', walnut: 'Gỗ Óc Chó', white_melamine: 'Melamine Trắng', grey_melamine: 'Melamine Xám Chì' };
    if (matEl) matEl.textContent = `${matNames[p.material] || p.material} | Ván ${p.thickness || 18}mm`;

    if (specsEl) {
      specsEl.textContent = `Dài: ${p.length}mm | Rộng: ${p.width}mm | Cao: ${p.height}mm`;
    }

    const legNames = { metal_frame: 'Chân sắt hộp', wooden_legs: 'Chân gỗ', panel_legs: 'Ván hông', plinth: 'Len chân tủ' };
    if (structEl) {
      structEl.textContent = `Ván ${p.thickness || 18}mm | ${legNames[p.leg_style] || 'Chân sắt'} | ${p.doors || 0} Cánh | ${p.drawers || 0} Hộc kéo`;
    }
  }

  saveCurrentAsDefaultPreset() {
    const newL = parseFloat(document.getElementById('input-length').value) || this.currentModel.length;
    const newW = parseFloat(document.getElementById('input-width').value) || this.currentModel.width;
    const newH = parseFloat(document.getElementById('input-height').value) || this.currentModel.height;
    const newThick = parseFloat(document.getElementById('select-thickness')?.value) || 18;
    const newMat = document.getElementById('select-material')?.value || 'oak';
    const newLeg = document.getElementById('select-leg-style')?.value || 'metal_frame';
    const newDoors = parseInt(document.getElementById('input-doors')?.value, 10) || 0;
    const newDrawers = parseInt(document.getElementById('input-drawers')?.value, 10) || 0;

    if (!this.currentPresets) this.currentPresets = this.getPresetsForType(this.currentModel.type || 'desk');
    
    const activePreset = this.currentPresets[this.currentPresetIndex];
    if (activePreset) {
      activePreset.length = newL;
      activePreset.width = newW;
      activePreset.height = newH;
      activePreset.thickness = newThick;
      activePreset.material = newMat;
      activePreset.leg_style = newLeg;
      activePreset.doors = newDoors;
      activePreset.drawers = newDrawers;
      activePreset.name = `Đã Tùy Chỉnh (${newL}x${newW})`;
    }

    this.currentModel.length = newL;
    this.currentModel.width = newW;
    this.currentModel.height = newH;
    this.currentModel.thickness = newThick;
    this.currentModel.material = newMat;
    this.currentModel.leg_style = newLeg;
    this.currentModel.doors = newDoors;
    this.currentModel.drawers = newDrawers;

    try {
      localStorage.setItem(`chill_ai_default_${this.currentModel.type || 'desk'}`, JSON.stringify(activePreset));
    } catch(e) {}

    this.updateAiOptionBarUI();
    this.updateDefaultProfileUI(activePreset);
    this.update3DAndCAM();

    this.showMiniToast(`Đã lưu kích thước ${newL} x ${newW} x ${newH} mm làm số đo Mặc Định mới!`, 'success', 3500);
    if (this.avatar) {
      this.avatar.setEmotion('happy');
      this.avatar.addMessage('bot', `Tuyệt vời! Bác đã lưu kích thước <strong>${newL}x${newW}x${newH}mm</strong> làm số đo Mặc Định mới cho bạn rồi nhé!`);
    }
  }

  resetToInitialDefault() {
    this.currentPresets = this.getPresetsForType(this.currentModel.type || 'desk');
    this.currentPresetIndex = 0;
    const p = this.currentPresets[0];

    document.getElementById('input-length').value = p.length;
    document.getElementById('input-width').value = p.width;
    document.getElementById('input-height').value = p.height;
    if (document.getElementById('select-thickness')) document.getElementById('select-thickness').value = p.thickness || 18;
    if (document.getElementById('select-material')) document.getElementById('select-material').value = p.material || 'oak';
    if (document.getElementById('select-leg-style')) document.getElementById('select-leg-style').value = p.leg_style || 'metal_frame';
    if (document.getElementById('input-doors')) document.getElementById('input-doors').value = p.doors !== undefined ? p.doors : 2;
    if (document.getElementById('input-drawers')) document.getElementById('input-drawers').value = p.drawers !== undefined ? p.drawers : 0;

    this.syncFormData();
    this.updateAiOptionBarUI();
    this.updateDefaultProfileUI(p);

    if (this.avatar) {
      this.avatar.setEmotion('happy');
      this.avatar.addMessage('bot', `🔄 Đã khôi phục các thông số về Kích Thước Tiêu Chuẩn ban đầu: ${p.length}x${p.width}x${p.height}mm.`);
    }
  }


  // --- SHOW / HIDE AI SUB-OPTIONS (Chỉ hiện khi tải ảnh xong) ---
  showAiOptions(show = true) {
    const standbyEl = document.getElementById('ai-opt-standby');
    const slotsEl = document.getElementById('ai-opt-slots');
    const counterEl = document.getElementById('ai-preset-counter');
    const titleEl = document.getElementById('ai-opt-bar-title');

    if (show) {
      if (standbyEl) standbyEl.style.display = 'none';
      if (slotsEl) slotsEl.style.display = 'flex';
      if (counterEl) counterEl.style.display = 'inline-block';
      if (titleEl) titleEl.textContent = '⚡ PHƯƠNG ÁN KÍCH THƯỚC AI';
      this.hasScannedImage = true;
    } else {
      if (standbyEl) standbyEl.style.display = 'flex';
      if (slotsEl) slotsEl.style.display = 'none';
      if (counterEl) counterEl.style.display = 'none';
      if (titleEl) titleEl.textContent = '⚡ TÙY CHỌN NGỮ CẢNH';
      this.hasScannedImage = false;
    }
  }

  // --- FLOATING CUSTOM PANEL (VÙNG 1: GÓC TRÊN BÊN PHẢI 3D VIEWPORT) ---
  initFloatingCustomPanel() {
    const floatPanel = document.getElementById('floating-custom-panel');
    const btnToggleFloat = document.getElementById('btn-toggle-float-panel');
    const btnDock = document.getElementById('btn-dock-to-hud');
    const btnClose = document.getElementById('btn-close-floating');

    // Toggle button in HUD tab
    if (btnToggleFloat) {
      btnToggleFloat.addEventListener('click', () => {
        if (!floatPanel) return;
        const isHidden = (floatPanel.style.display === 'none' || !floatPanel.style.display);
        floatPanel.style.display = isHidden ? 'flex' : 'none';
        btnToggleFloat.textContent = isHidden ? '🗕 Thu về HUD' : '🗖 Nổi lên góc 3D';
        if (isHidden) this.syncFloatingInputs();
      });
    }

    // Dock to HUD button
    if (btnDock) {
      btnDock.addEventListener('click', () => {
        if (floatPanel) floatPanel.style.display = 'none';
        if (btnToggleFloat) btnToggleFloat.textContent = '🗖 Nổi lên góc 3D';
        this.switchTab('tab-edit');
      });
    }

    // Close button
    if (btnClose) {
      btnClose.addEventListener('click', () => {
        if (floatPanel) floatPanel.style.display = 'none';
        if (btnToggleFloat) btnToggleFloat.textContent = '🗖 Nổi lên góc 3D';
      });
    }

    // Bind floating inputs to sync with model and main inputs
    const floatInputs = [
      { id: 'f-input-length', target: 'input-length', key: 'length', num: true },
      { id: 'f-input-width', target: 'input-width', key: 'width', num: true },
      { id: 'f-input-height', target: 'input-height', key: 'height', num: true },
      { id: 'f-select-thickness', target: 'select-thickness', key: 'thickness', num: true },
      { id: 'f-input-doors', target: 'input-doors', key: 'doors', num: true },
      { id: 'f-input-drawers', target: 'input-drawers', key: 'drawers', num: true },
      { id: 'f-select-material', target: 'select-material', key: 'material', num: false },
      { id: 'f-select-leg-style', target: 'select-leg-style', key: 'leg_style', num: false }
    ];

    floatInputs.forEach(item => {
      const el = document.getElementById(item.id);
      if (el) {
        const handler = () => {
          const val = item.num ? parseFloat(el.value) || 0 : el.value;
          this.currentModel[item.key] = val;
          const targetEl = document.getElementById(item.target);
          if (targetEl) targetEl.value = el.value;

          // Sync sliders
          if (item.key === 'length') {
            const sX = document.getElementById('f-slider-lenx');
            const vX = document.getElementById('f-val-lenx');
            if (sX) sX.value = val;
            if (vX) vX.textContent = val;
            const mainSx = document.getElementById('slider-dc-lenx');
            const mainVx = document.getElementById('val-dc-lenx');
            if (mainSx) mainSx.value = val;
            if (mainVx) mainVx.textContent = val;
          }
          if (item.key === 'height') {
            const sZ = document.getElementById('f-slider-lenz');
            const vZ = document.getElementById('f-val-lenz');
            if (sZ) sZ.value = val;
            if (vZ) vZ.textContent = val;
            const mainSz = document.getElementById('slider-dc-lenz');
            const mainVz = document.getElementById('val-dc-lenz');
            if (mainSz) mainSz.value = val;
            if (mainVz) mainVz.textContent = val;
          }

          this.update3DAndCAM();
        };
        el.addEventListener('input', handler);
        el.addEventListener('change', handler);
      }
    });

    // Floating sliders
    const fSliderX = document.getElementById('f-slider-lenx');
    const fSliderZ = document.getElementById('f-slider-lenz');

    if (fSliderX) {
      fSliderX.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        document.getElementById('f-val-lenx').textContent = val;
        document.getElementById('f-input-length').value = val;
        document.getElementById('input-length').value = val;
        document.getElementById('val-dc-lenx').textContent = val;
        document.getElementById('slider-dc-lenx').value = val;
        this.currentModel.length = val;
        this.update3DAndCAM();
      });
    }

    if (fSliderZ) {
      fSliderZ.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        document.getElementById('f-val-lenz').textContent = val;
        document.getElementById('f-input-height').value = val;
        document.getElementById('input-height').value = val;
        document.getElementById('val-dc-lenz').textContent = val;
        document.getElementById('slider-dc-lenz').value = val;
        this.currentModel.height = val;
        this.update3DAndCAM();
      });
    }

    // Floating action buttons
    document.getElementById('f-btn-build-3d')?.addEventListener('click', () => {
      this.sendToSketchUp('create_3d_model', this.currentModel);
    });

    document.getElementById('f-btn-save-default')?.addEventListener('click', () => {
      this.saveCurrentAsDefaultPreset();
    });
  }

  syncFloatingInputs() {
    const setVal = (id, val) => {
      const el = document.getElementById(id);
      if (el && val !== undefined) el.value = val;
    };
    setVal('f-input-length', this.currentModel.length);
    setVal('f-input-width', this.currentModel.width);
    setVal('f-input-height', this.currentModel.height);
    setVal('f-select-thickness', this.currentModel.thickness);
    setVal('f-input-doors', this.currentModel.doors);
    setVal('f-input-drawers', this.currentModel.drawers);
    setVal('f-select-material', this.currentModel.material);
    setVal('f-select-leg-style', this.currentModel.leg_style);

    const sX = document.getElementById('f-slider-lenx');
    const vX = document.getElementById('f-val-lenx');
    if (sX) sX.value = this.currentModel.length;
    if (vX) vX.textContent = this.currentModel.length;

    const sZ = document.getElementById('f-slider-lenz');
    const vZ = document.getElementById('f-val-lenz');
    if (sZ) sZ.value = this.currentModel.height;
    if (vZ) vZ.textContent = this.currentModel.height;
  }

  initFormEvents() {
    const inputs = [
      'input-length', 'input-width', 'input-height',
      'select-thickness', 'select-material', 'select-leg-style',
      'input-doors', 'input-drawers', 'select-door-material'
    ];

    inputs.forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        el.addEventListener('input', () => this.syncFormData());
        el.addEventListener('change', () => this.syncFormData());
      }
    });

    // Dynamic Component Sliders
    const sliderLenX = document.getElementById('slider-dc-lenx');
    const sliderLenZ = document.getElementById('slider-dc-lenz');

    if(sliderLenX) sliderLenX.addEventListener('input', (e) => {
      document.getElementById('val-dc-lenx').textContent = e.target.value;
      this.currentModel.length = parseFloat(e.target.value);
      document.getElementById('input-length').value = e.target.value;
      this.update3DAndCAM();
    });

    if(sliderLenZ) sliderLenZ.addEventListener('input', (e) => {
      document.getElementById('val-dc-lenz').textContent = e.target.value;
      this.currentModel.height = parseFloat(e.target.value);
      document.getElementById('input-height').value = e.target.value;
      this.update3DAndCAM();
    });
  }

  syncFormData() {
    this.currentModel.length = parseFloat(document.getElementById('input-length').value) || 1200;
    this.currentModel.width = parseFloat(document.getElementById('input-width').value) || 600;
    this.currentModel.height = parseFloat(document.getElementById('input-height').value) || 750;
    this.currentModel.thickness = parseFloat(document.getElementById('select-thickness').value) || 18;
    this.currentModel.material = document.getElementById('select-material').value || 'oak';
    this.currentModel.leg_style = document.getElementById('select-leg-style').value || 'metal_frame';
    this.currentModel.doors = parseInt(document.getElementById('input-doors')?.value, 10) || 2;
    this.currentModel.drawers = parseInt(document.getElementById('input-drawers')?.value, 10) || 0;
    this.currentModel.door_material = document.getElementById('select-door-material')?.value || 'same_as_body';

    // Sync DC Sliders
    document.getElementById('slider-dc-lenx').value = this.currentModel.length;
    document.getElementById('val-dc-lenx').textContent = this.currentModel.length;
    document.getElementById('slider-dc-lenz').value = this.currentModel.height;
    document.getElementById('val-dc-lenz').textContent = this.currentModel.height;

    this.syncFloatingInputs();
    this.update3DAndCAM();
  }

  setCustomParams(params) {
    Object.assign(this.currentModel, params);
    document.getElementById('input-length').value = this.currentModel.length;
    document.getElementById('input-width').value = this.currentModel.width;
    document.getElementById('input-height').value = this.currentModel.height;
    document.getElementById('select-material').value = this.currentModel.material;
    this.update3DAndCAM();
  }

  applyStylePreset(styleKey) {
    if (styleKey === 'scandinavian') {
      this.setCustomParams({
        material: 'oak',
        leg_style: 'wooden_legs',
        length: 1300,
        width: 650,
        height: 750
      });
    }
  }

  update3DAndCAM() {
    if (this.viewer) {
      this.viewer.updateModel(this.currentModel);
    }
    const titleEl = document.getElementById('viewport-model-title');
    if (titleEl) {
      titleEl.textContent = `Mô hình: ${this.currentModel.name} (${this.currentModel.length} x ${this.currentModel.width} x ${this.currentModel.height} mm)`;
    }
  }

  // --- ACTION BUTTONS (SKETCHUP BRIDGE & ACTIONS) ---
  initActionButtons() {
    // Button 1: Xuất mô hình 3D vào SketchUp
    document.getElementById('btn-build-3d')?.addEventListener('click', () => {
      this.sendToSketchUp('create_3d_model', this.currentModel);
    });

    // Button 2: Tạo hàm Dynamic Component (Biến đối tượng đang chọn hoặc tạo mới)
    document.getElementById('btn-generate-dc')?.addEventListener('click', () => {
      const selectedId = this.currentSelectionData ? this.currentSelectionData.entity_id : null;
      const targetName = this.currentSelectionData ? this.currentSelectionData.name : (this.currentModel.name || 'Chill_Dynamic_Furniture');
      const dcParams = {
        entity_id: selectedId,
        name: targetName,
        type: (targetName.toLowerCase().includes('tủ') || targetName.toLowerCase().includes('tu') || targetName.toLowerCase().includes('cabinet') || targetName.toLowerCase().includes('wardrobe')) ? 'wardrobe' : 'desk',
        length: this.currentSelectionData ? parseFloat(this.currentSelectionData.length) : (this.currentModel.length || 1600),
        width: this.currentSelectionData ? parseFloat(this.currentSelectionData.width) : (this.currentModel.width || 600),
        height: this.currentSelectionData ? parseFloat(this.currentSelectionData.height) : (this.currentModel.height || 1800),
        thickness: this.currentModel.thickness || 17.5,
        material: this.currentModel.material || 'white_melamine'
      };
      this.sendToSketchUp('create_dynamic_component', dcParams);
      this.showMiniToast(`Đang chuyển đổi ${targetName} thành Dynamic Component...`, 'info');
    });

    document.getElementById('btn-send-dc-to-su')?.addEventListener('click', () => {
      const selectedId = this.currentSelectionData ? this.currentSelectionData.entity_id : null;
      const targetName = this.currentSelectionData ? this.currentSelectionData.name : (this.currentModel.name || 'Chill_Dynamic_Furniture');
      const dcParams = {
        entity_id: selectedId,
        name: targetName,
        type: (targetName.toLowerCase().includes('tủ') || targetName.toLowerCase().includes('tu') || targetName.toLowerCase().includes('cabinet') || targetName.toLowerCase().includes('wardrobe')) ? 'wardrobe' : 'desk',
        length: this.currentSelectionData ? parseFloat(this.currentSelectionData.length) : (this.currentModel.length || 1600),
        width: this.currentSelectionData ? parseFloat(this.currentSelectionData.width) : (this.currentModel.width || 600),
        height: this.currentSelectionData ? parseFloat(this.currentSelectionData.height) : (this.currentModel.height || 1800),
        thickness: this.currentModel.thickness || 17.5,
        material: this.currentModel.material || 'white_melamine'
      };
      this.sendToSketchUp('create_dynamic_component', dcParams);
      this.showMiniToast(`Đang chuyển đổi ${targetName} thành Dynamic Component...`, 'info');
    });

    // Viewport controls
    document.getElementById('btn-reset-cam')?.addEventListener('click', () => {
      if (this.viewer) this.viewer.resetCamera();
    });

    document.getElementById('btn-toggle-wireframe')?.addEventListener('click', () => {
      if (this.viewer) this.viewer.toggleWireframe();
    });

    // Page 2 Command Grid Hooks
    document.getElementById('btn-hud-save-load')?.addEventListener('click', () => {
      const m = document.getElementById('modal-projects');
      if (m) m.style.display = 'flex';
    });
    document.getElementById('btn-hud-api')?.addEventListener('click', () => {
      const m = document.getElementById('modal-api-key');
      if (m) m.style.display = 'flex';
    });
    document.getElementById('btn-hud-cam')?.addEventListener('click', () => {
      if(window.Furniture3DViewer && window.Furniture3DViewer.instance) window.Furniture3DViewer.instance.resetCamera();
    });
    document.getElementById('btn-hud-grid')?.addEventListener('click', () => {
      if(window.Furniture3DViewer && window.Furniture3DViewer.instance) window.Furniture3DViewer.instance.toggleGrid();
    });

    // Sự kiện xử lý nhanh tấm quá khổ ván (Co kéo 3D & Dynamic Component)
    document.getElementById('btn-clamp-to-standard')?.addEventListener('click', () => {
      if (window.sketchup && window.sketchup.clamp_oversized_to_standard) {
        window.sketchup.clamp_oversized_to_standard();
        this.showMiniToast("Đang tự động thu kích thước về tối đa 2440mm...", "info");
      } else {
        this.showMiniToast("Chức năng chỉ hoạt động bên trong SketchUp", "warning");
      }
    });

    document.getElementById('btn-switch-jumbo-sheet')?.addEventListener('click', () => {
      const sheetHInput = document.getElementById('dock-cam-sheet-h');
      if (sheetHInput) sheetHInput.value = '2745';
      this.showMiniToast("Đã đổi cấu hình sang Khổ Ván Lớn 1220x2745mm! Tấm 2600mm sẽ đạt chuẩn gia công.", "success");
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', "Em đã chuyển cấu hình phôi xưởng sang Ván Khổ Lớn 1220x2745mm rồi nhé anh Huy! Các tấm dài đến 2745mm sẽ lọt khổ chuẩn ạ! 🪵✨");
      }
    });

    document.getElementById('dock-oversized-details')?.addEventListener('click', (e) => {
      const item = e.target.closest('.oversized-item');
      if (item && item.dataset.id && window.sketchup && window.sketchup.zoom_to_entity) {
        window.sketchup.zoom_to_entity(item.dataset.id);
      }
    });
  }


    sendToSketchUp(actionName, data) {
    if (this.isSketchUpAvailable && window.sketchup[actionName]) {
      window.sketchup[actionName](JSON.stringify(data));
    } else {
      // Browser Standalone Preview Mode
      this.showMiniToast(`[Mô phỏng]: Đã gửi lệnh "${actionName}" thành công!`, 'info', 3500);
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `Tuyệt vời! Đã áp dụng thiết kế "${this.currentModel.name}" vào dự án của bạn.`);
      }
    }
  }

  // --- 3. 3D VIEWER & AVATAR INIT ---
  init3DViewer() {
    if (window.Furniture3DViewer) {
      this.viewer = new window.Furniture3DViewer('threejs-canvas-container');
      const titleEl = document.getElementById('viewport-model-title');
      if (titleEl && this.currentModel) {
        titleEl.textContent = `Mô hình: ${this.currentModel.name} (${this.currentModel.length} x ${this.currentModel.width} x ${this.currentModel.height} mm)`;
      }
    }
  }

  initAvatar() {
    if (window.AvatarConsultant) {
      this.avatar = new window.AvatarConsultant();
    }
  }

  // --- 4. CAM 2D NESTING & G-CODE GENERATOR ---
  openCncModal() {
    const modal = document.getElementById('modal-cnc-export');
    if (modal) {
      modal.style.display = 'flex';
      // Tự động tính toán lại CAM nếu chưa có dữ liệu
      if (!this.lastNestingData) {
        this.recalculateCAM();
      }
    }
  }

  closeCncModal() {
    const modal = document.getElementById('modal-cnc-export');
    if (modal) modal.style.display = 'none';
  }

  initCAMNesting() {
    // 1. CÁC NÚT MỞ HỘP THOẠI XUẤT CNC (ĐẬP VÀO MẮT ANH HUY NGAY TỪ MẶT TIỀN)
    const cncTriggers = [
      'dock-btn-main-cnc',        // Nút to cam ghim đáy Khay Đứng (bên cạnh nút Xây 3D)
      'chip-quick-export-cnc',     // Chip nút bấm nhanh ở Ô xanh gợi ý Khay Đứng
      'btn-studio-header-cnc',     // Nút Xuất CNC trên thanh Header bản Studio
      'btn-cmd-export-cnc'         // Nút Xuất CNC trên bàn cờ lệnh HUD Studio
    ];
    cncTriggers.forEach(id => {
      document.getElementById(id)?.addEventListener('click', () => {
        this.openCncModal();
      });
    });

    // 2. CÁC NÚT BÊN TRONG MODAL XUẤT CNC
    document.getElementById('modal-btn-save-gcode')?.addEventListener('click', () => {
      this.closeCncModal();
      this.saveGCodeFile();
    });

    document.getElementById('modal-btn-save-dxf')?.addEventListener('click', () => {
      this.closeCncModal();
      this.saveDxfFile();
    });

    document.getElementById('modal-btn-nest-su')?.addEventListener('click', () => {
      this.closeCncModal();
      this.nestToSketchUpDirectly();
    });

    document.getElementById('modal-btn-open-cnc-tab')?.addEventListener('click', () => {
      this.closeCncModal();
      const isTray = document.getElementById('dock-tray-shell')?.style.display !== 'none';
      if (isTray) {
        this.switchDockTab('dock-pane-cnc');
      } else {
        this.switchTab('tab-cam');
      }
    });

    document.getElementById('btn-close-cnc-modal')?.addEventListener('click', () => {
      this.closeCncModal();
    });

    const cncModalEl = document.getElementById('modal-cnc-export');
    cncModalEl?.addEventListener('click', (e) => {
      if (e.target === cncModalEl) {
        this.closeCncModal();
      }
    });

    // 3. TÍNH TOÁN LẠI NESTING
    document.getElementById('btn-re-nest')?.addEventListener('click', () => {
      this.recalculateCAM();
    });

    document.getElementById('dock-btn-recalculate-cam')?.addEventListener('click', () => {
      this.recalculateCAM();
    });

    // 4. LỰA CHỌN B: TRẢI PHẲNG TRỰC TIẾP TRÊN SU (ONE CLICK CABINET STYLE)
    document.getElementById('dock-btn-nest-to-su')?.addEventListener('click', () => {
      this.nestToSketchUpDirectly();
    });
    document.getElementById('btn-studio-nest-to-su')?.addEventListener('click', () => {
      this.nestToSketchUpDirectly();
    });

    // 5. LỰA CHỌN A: XUẤT CHO VECTRIC ASPIRE (G-CODE & DXF)
    document.getElementById('btn-save-gcode')?.addEventListener('click', () => {
      this.saveGCodeFile();
    });
    document.getElementById('dock-btn-save-gcode')?.addEventListener('click', () => {
      this.saveGCodeFile();
    });
    document.getElementById('btn-studio-save-gcode')?.addEventListener('click', () => {
      this.saveGCodeFile();
    });

    document.getElementById('dock-btn-save-dxf')?.addEventListener('click', () => {
      this.saveDxfFile();
    });
    document.getElementById('dock-btn-footer-dxf')?.addEventListener('click', () => {
      this.saveDxfFile();
    });
    document.getElementById('chip-quick-export-dxf')?.addEventListener('click', () => {
      this.saveDxfFile();
    });
    document.getElementById('btn-studio-save-dxf')?.addEventListener('click', () => {
      this.saveDxfFile();
    });

    document.getElementById('btn-copy-gcode')?.addEventListener('click', () => {
      this.copyGCodeToClipboard();
    });
    document.getElementById('dock-btn-copy-gcode-text')?.addEventListener('click', () => {
      this.copyGCodeToClipboard();
    });
  }

  recalculateCAM() {
    const camRequest = this.getCamRequest();
    // If SketchUp extension is connected, request Ruby CAM
    if (this.isSketchUpAvailable && window.sketchup.export_gcode) {
      window.sketchup.export_gcode(JSON.stringify(camRequest));
    } else {
      // In-browser CAM calculation
      const result = this.calculateLocalCAM(camRequest);
      this.displayNestingAndGCode(result);
    }
  }

  getCamRequest() {
    const numberValue = (id, fallback) => {
      const value = Number(document.getElementById(id)?.value);
      return Number.isFinite(value) && value > 0 ? value : fallback;
    };
    return {
      ...(this.currentModel || {}),
      cam: {
        sheet_w: numberValue('dock-cam-sheet-w', 1220),
        sheet_h: numberValue('dock-cam-sheet-h', 2440),
        tool_diameter: numberValue('dock-cam-tool-dia', 6),
        edge_margin: numberValue('dock-cam-edge-margin', 10),
        part_gap: numberValue('dock-cam-part-gap', 4),
        pass_depth: numberValue('dock-cam-pass-depth', 6),
        use_tabs: document.getElementById('dock-cam-use-tabs')?.checked !== false
      }
    };
  }

  calculateLocalCAM(model) {
    const sheetW = model.cam?.sheet_w || 1220;
    const sheetH = model.cam?.sheet_h || 2440;
    const kerf = model.cam?.tool_diameter || 6;
    const margin = model.cam?.edge_margin || 10;
    const l = model.length || 1200;
    const w = model.width || 600;
    const t = model.thickness || 18;

    const parts = [
      { name: "Mặt bàn chính", w: l, h: w, color: "#f59e0b" },
      { name: "Yếm bàn dài 1", w: l - 100, h: 100, color: "#d97706" },
      { name: "Yếm bàn dài 2", w: l - 100, h: 100, color: "#d97706" },
      { name: "Yếm hông trái", w: w - 100, h: 100, color: "#b45309" },
      { name: "Yếm hông phải", w: w - 100, h: 100, color: "#b45309" }
    ];

    if (model.drawers > 0) {
      parts.push({ name: "Hông hộc tủ trái", w: w - 50, h: 420, color: "#78350f" });
      parts.push({ name: "Hông hộc tủ phải", w: w - 50, h: 420, color: "#78350f" });
      parts.push({ name: "Đáy hộc tủ", w: 380, h: w - 50, color: "#92400e" });
      for (let i = 0; i < model.drawers; i++) {
        parts.push({ name: `Mặt ngăn kéo ${i + 1}`, w: 370, h: Math.round(400 / model.drawers) - 5, color: "#fbbf24" });
      }
    }

    // Shelf Nesting
    const items = [];
    let curX = margin;
    let curY = margin;
    let rowH = 0;

    parts.sort((a, b) => Math.max(b.w, b.h) - Math.max(a.w, a.h));

    parts.forEach(p => {
      const pW = Math.min(p.w, p.h);
      const pH = Math.max(p.w, p.h);

      if (curX + pW + kerf > sheetW - margin) {
        curX = margin;
        curY += rowH + kerf;
        rowH = 0;
      }

      items.push({
        name: p.name,
        x: curX,
        y: curY,
        w: pW,
        h: pH,
        color: p.color
      });

      curX += pW + kerf;
      rowH = Math.max(rowH, pH);
    });

    const totalPartArea = parts.reduce((sum, p) => sum + p.w * p.h, 0);
    const totalSheetArea = sheetW * sheetH;
    const utilization = ((totalPartArea / totalSheetArea) * 100).toFixed(1);

    const totalPerimeter = parts.reduce((sum, p) => sum + 2 * (p.w + p.h), 0) / 1000;
    const cutTimeMin = ((totalPerimeter * 2000) / 2400 + parts.length * 0.3).toFixed(1);

    // Generate ISO G-Code text
    const gcode = this.buildGCodeText(items, t, utilization, sheetW, sheetH);
    // Generate DXF text for Vectric Aspire
    const dxf = this.buildDxfText(items, t, sheetW, sheetH);

    return {
      sheet_w: sheetW,
      sheet_h: sheetH,
      sheets: [{ id: 1, items: items }],
      utilization: utilization,
      cut_length_m: totalPerimeter.toFixed(2),
      estimated_time_min: cutTimeMin,
      gcode: gcode,
      dxf: dxf
    };
  }

  buildDxfText(items, thickness, sw, sh) {
    const lines = [];
    lines.push("0\nSECTION\n2\nHEADER\n9\n$ACADVER\n1\nAC1009\n0\nENDSEC");
    lines.push("0\nSECTION\n2\nTABLES");
    lines.push("0\nTABLE\n2\nLAYER\n70\n3");
    lines.push("0\nLAYER\n2\nSHEET_BORDER\n70\n0\n62\n1\n6\nCONTINUOUS");
    lines.push("0\nLAYER\n2\nCNC_CUT_OUTLINE\n70\n0\n62\n3\n6\nCONTINUOUS");
    lines.push("0\nLAYER\n2\nLABELS\n70\n0\n62\n2\n6\nCONTINUOUS");
    lines.push("0\nENDTAB\n0\nENDSEC");
    lines.push("0\nSECTION\n2\nENTITIES");

    const addPolyline = (layer, pts) => {
      lines.push(`0\nPOLYLINE\n8\n${layer}\n66\n1\n70\n1`);
      pts.forEach(p => {
        lines.push(`0\nVERTEX\n8\n${layer}\n10\n${p[0].toFixed(2)}\n20\n${p[1].toFixed(2)}\n30\n0.0`);
      });
      lines.push("0\nSEQEND");
    };

    addPolyline("SHEET_BORDER", [
      [0, 0], [sw, 0], [sw, sh], [0, sh]
    ]);

    items.forEach(it => {
      const x1 = it.x;
      const y1 = it.y;
      const x2 = it.x + it.w;
      const y2 = it.y + it.h;

      addPolyline("CNC_CUT_OUTLINE", [
        [x1, y1], [x2, y1], [x2, y2], [x1, y2]
      ]);

      const cleanName = (it.name || 'Part').normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D');
      lines.push(`0\nTEXT\n8\nLABELS\n10\n${(x1 + 15).toFixed(2)}\n20\n${(y2 - 35).toFixed(2)}\n30\n0.0\n40\n20.0\n1\n${cleanName} (${Math.round(it.w)}x${Math.round(it.h)} T${thickness})`);
    });

    lines.push(`0\nTEXT\n8\nLABELS\n10\n15.00\n20\n${(sh + 25).toFixed(2)}\n30\n0.0\n40\n25.0\n1\nSHEET 1 - STOCK T${thickness}mm`);
    lines.push("0\nENDSEC\n0\nEOF");
    return lines.join("\n");
  }

  buildGCodeText(items, thickness, utilization, sw, sh) {
    const lines = [];
    lines.push(`( CHILL AI INTERIOR - CNC ROUTER G-CODE EXPORT )`);
    lines.push(`( DATE: ${new Date().toLocaleString()} )`);
    lines.push(`( SHEET: ${sw}x${sh}x${thickness}mm | UTILIZATION: ${utilization}% )`);
    lines.push(`( TOOL: ENDMILL D6 - 6mm DIA )`);
    lines.push(`G90 G21 G17 G54`);
    lines.push(`G00 Z15.000`);
    lines.push(`M03 S18000`);
    lines.push(`G04 P2`);
    lines.push(``);

    items.forEach((it, idx) => {
      const x1 = it.x.toFixed(2);
      const y1 = it.y.toFixed(2);
      const x2 = (it.x + it.w).toFixed(2);
      const y2 = (it.y + it.h).toFixed(2);

      lines.push(`( PART ${idx + 1}: ${it.name} - ${it.w}x${it.h}mm )`);
      lines.push(`G00 X${x1} Y${y1}`);
      lines.push(`G01 Z-${(thickness / 2).toFixed(2)} F800 (PASS 1)`);
      lines.push(`G01 X${x2} Y${y1} F2400`);
      lines.push(`G01 X${x2} Y${y2}`);
      lines.push(`G01 X${x1} Y${y2}`);
      lines.push(`G01 X${x1} Y${y1}`);
      lines.push(`G01 Z-${(thickness + 0.5).toFixed(2)} F800 (PASS 2 - CUT THROUGH)`);
      lines.push(`G01 X${x2} Y${y1} F2400`);
      lines.push(`G01 X${x2} Y${y2}`);
      lines.push(`G01 X${x1} Y${y2}`);
      lines.push(`G01 X${x1} Y${y1}`);
      lines.push(`G00 Z15.000`);
      lines.push(``);
    });

    lines.push(`M05 (SPINDLE OFF)`);
    lines.push(`G00 Z30.000`);
    lines.push(`G00 X0.000 Y${sh}.000 (PARK POSITION)`);
    lines.push(`M30 (PROGRAM END)`);

    return lines.join("\n");
  }

  displayNestingAndGCode(data) {
    document.getElementById('cam-sheet-count').textContent = `${data.sheets.length} Tấm`;
    document.getElementById('cam-utilization').textContent = `${data.utilization}%`;
    document.getElementById('cam-cut-length').textContent = `${data.cut_length_m} m`;
    document.getElementById('cam-cut-time').textContent = `${data.estimated_time_min} phút`;

    document.getElementById('gcode-output-area').value = data.gcode;
    this.lastNestingData = data;
    this.lastDxfContent = data.dxf || '';

    if (data.material_groups && data.material_groups.length > 1) {
      const thicknesses = data.material_groups.map(group => `${group.thickness}mm`).join(', ');
      this.showMiniToast(`Đã tách ${data.material_groups.length} nhóm phôi theo độ dày: ${thicknesses}. Mỗi tấm cần đặt lại gốc Z trước khi cắt.`, 'info', 5200);
    }

    // Cập nhật cả trên Khay Đứng (Dock Tray Mode)
    const dockSheet = document.getElementById('dock-cam-sheet-count');
    const dockUtil = document.getElementById('dock-cam-utilization');
    const dockCut = document.getElementById('dock-cam-cut-length');
    if (dockSheet) dockSheet.textContent = `${data.sheets ? data.sheets.length : 1} tấm`;
    if (dockUtil) dockUtil.textContent = `${data.utilization || 0}%`;
    if (dockCut) dockCut.textContent = `${data.cut_length_m || 0}m`;

    // Render Canvas
    this.renderNestingCanvas(data);
  }

  renderNestingCanvas(data) {
    const canvas = document.getElementById('nesting-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    const sheetW = data.sheet_w || 1220;
    const sheetH = data.sheet_h || 2440;

    // Fit canvas scale
    canvas.width = canvas.parentElement.clientWidth - 24;
    canvas.height = 240;

    const scale = Math.min((canvas.width - 20) / sheetH, (canvas.height - 20) / sheetW);
    const offsetX = 10;
    const offsetY = 10;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw Sheet background
    ctx.fillStyle = '#1e293b';
    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 2;
    ctx.fillRect(offsetX, offsetY, sheetH * scale, sheetW * scale);
    ctx.strokeRect(offsetX, offsetY, sheetH * scale, sheetW * scale);

    // Draw nested items
    const legendEl = document.getElementById('nesting-legend');
    legendEl.innerHTML = '';

    const firstSheet = data.sheets[0];
    if (firstSheet && firstSheet.items) {
      firstSheet.items.forEach(it => {
        // Inverted coordinate for landscape sheet layout
        const rx = offsetX + it.y * scale;
        const ry = offsetY + it.x * scale;
        const rw = it.h * scale;
        const rh = it.w * scale;

        ctx.fillStyle = it.color || '#3b82f6';
        ctx.fillRect(rx, ry, rw, rh);
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1;
        ctx.strokeRect(rx, ry, rw, rh);

        // Text label
        if (rw > 30 && rh > 15) {
          ctx.fillStyle = '#ffffff';
          ctx.font = '9px sans-serif';
          ctx.fillText(it.name.substring(0, 12), rx + 4, ry + 12);
        }

        // Add legend pill
        const chip = document.createElement('span');
        chip.className = 'legend-chip';
        chip.innerHTML = `<span class="legend-color-dot" style="background:${it.color}"></span>${it.name} (${Math.round(it.w)}x${Math.round(it.h)}mm)`;
        legendEl.appendChild(chip);
      });
    }
  }

  saveGCodeFile() {
    const camRequest = this.getCamRequest();
    // 1. Nếu đang trong SketchUp và có hàm xuất trực tiếp 1-chạm
    if (this.isSketchUpAvailable && window.sketchup && window.sketchup.export_gcode_direct) {
      this.showMiniToast('Đang bóc tách và chuẩn bị lưu file G-Code cho máy CNC...', 'info');
      window.sketchup.export_gcode_direct(JSON.stringify(camRequest));
      return;
    }

    // 2. Nếu đã có sẵn nội dung G-code trong textarea
    const content = document.getElementById('gcode-output-area')?.value || '';
    if (content.trim()) {
      const modelName = (this.currentModel && this.currentModel.name) || 'NESTING';
      const filename = `CNC_${modelName.replace(/\s+/g, '_')}_${Date.now()}.nc`;

      if (this.isSketchUpAvailable && window.sketchup && window.sketchup.save_gcode_file) {
        window.sketchup.save_gcode_file(JSON.stringify({ content: content, filename: filename }));
        return;
      } else {
        const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        this.showMiniToast(`Đã tải file G-Code thành công: ${filename}`, 'success', 3500);
        return;
      }
    }

    // 3. Nếu chưa có G-code (chạy trên trình duyệt Web)
    this.pendingCamExport = 'gcode';
    this.showMiniToast('Đang tính Nesting trước khi xuất G-Code…', 'info');
    this.recalculateCAM();
  }

  // --- LỰA CHỌN B: TRẢI PHẲNG VÁN TRỰC TIẾP TRÊN SKETCHUP (ONE CLICK STYLE) ---
  nestToSketchUpDirectly() {
    const camRequest = this.getCamRequest();
    if (this.isSketchUpAvailable && window.sketchup && window.sketchup.nest_to_sketchup) {
      this.showMiniToast("Đang bóc tách và trải phẳng các tấm ván ra mặt bàn SketchUp...", "info");
      window.sketchup.nest_to_sketchup(JSON.stringify(camRequest));
    } else {
      this.recalculateCAM();
      this.showMiniToast(`[Chế độ Trình Duyệt] Đã tính toán Nesting cho ${this.currentModel.length}x${this.currentModel.width}mm! Khi mở trong SketchUp, các tấm ván sẽ bung phẳng trực tiếp ra nền đất.`, "success");
      if (this.avatar) {
        this.avatar.setEmotion('happy');
        this.avatar.addMessage('bot', `Anh Huy ơi! Em đã hoàn thành thuật toán Nesting. Khi chạy trong SketchUp, tính năng này sẽ bung toàn bộ tấm ván phôi (1220x2440) ra nền đất kèm nhãn dán như One Click Cabinet nhé! 🪵`);
      }
    }
  }

  // --- LỰA CHỌN A: XUẤT FILE DXF CHUẨN CAD CHO VECTRIC ASPIRE ---
  saveDxfFile() {
    // 1. Ưu tiên 1: Chạy trực tiếp trong SketchUp (Gọi hàm 1-chạm đồng bộ tuyệt đối)
    if (window.sketchup && window.sketchup.export_dxf_direct) {
      this.showMiniToast('Đang mở hộp thoại Lưu file DXF 2D cho Vectric Aspire…', 'info');
      const camRequest = this.getCamRequest ? this.getCamRequest() : {};
      window.sketchup.export_dxf_direct(JSON.stringify(camRequest));
      return;
    }

    // 2. Nếu có save_dxf_file và đã có nội dung DXF sẵn
    if (window.sketchup && window.sketchup.save_dxf_file && this.lastDxfContent) {
      const modelName = (this.currentModel && this.currentModel.name) || 'NESTING';
      const filename = `CNC_ASPIRE_${modelName.replace(/\s+/g, '_')}_${Date.now()}.dxf`;
      window.sketchup.save_dxf_file(JSON.stringify({ content: this.lastDxfContent, filename: filename }));
      return;
    }

    // 3. Fallback cho chế độ Trình duyệt ngoài (Browser / Chrome standalone)
    this.showMiniToast('Đang tạo và tải file DXF 2D cho Aspire…', 'info');
    const localResult = this.calculateLocalCAM ? this.calculateLocalCAM(this.currentModel || {}) : null;
    const dxfString = (localResult && localResult.dxf) ? localResult.dxf : (this.lastDxfContent || this.buildFallbackDxf());
    const modelName = (this.currentModel && this.currentModel.name) || 'NESTING';
    const filename = `CNC_ASPIRE_${modelName.replace(/\s+/g, '_')}_${Date.now()}.dxf`;
    const blob = new Blob([dxfString], { type: 'application/dxf;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    this.showMiniToast(`Đã xuất file DXF: ${filename}`, 'success');
  }

  copyGCodeToClipboard() {
    const area = document.getElementById('gcode-output-area');
    const text = area ? area.value : (this.lastNestingData ? this.lastNestingData.gcode : '');
    if (text) {
      navigator.clipboard.writeText(text).then(() => {
        this.showMiniToast("Đã sao chép mã G-Code vào bộ nhớ tạm!", "success");
      }).catch(() => {
        if (area) { area.select(); document.execCommand('copy'); }
        this.showMiniToast("Đã sao chép mã G-Code!", "success");
      });
    }
  }

  buildFallbackDxf() {
    return "0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF";
  }

  // --- 5. CHAT EVENTS ---
  initChatEvents() {
    const input = document.getElementById('chat-input');
    const sendBtn = document.getElementById('btn-send-chat');

    // Voice toggle (on/off)
    const toggleVoice = document.getElementById('toggle-voice-ai');
    const voiceIcon = document.getElementById('voice-status-icon');
    const voiceSelect = document.getElementById('select-voice-ai');
    const speedSelect = document.getElementById('select-voice-speed');

    if (toggleVoice) {
      toggleVoice.checked = true;
      if (voiceIcon) voiceIcon.textContent = '🔊';
      if (this.avatar) this.avatar.isVoiceEnabled = true;

      toggleVoice.addEventListener('change', (e) => {
        const isOn = e.target.checked;
        if (voiceIcon) voiceIcon.textContent = isOn ? '🔊' : '🔇';
        if (this.avatar) {
          this.avatar.isVoiceEnabled = isOn;
          if (isOn && window.EdgeTTS) {
            window.EdgeTTS.prewarm();
          }
          if (!isOn) this.avatar.stopSpeaking();
        }
      });
    }

    // Voice selector (dropdown)
    const savedVoice = localStorage.getItem('chill_ai_voice') || 'namminh';
    if (voiceSelect) {
      voiceSelect.value = savedVoice;
      if (this.avatar) this.avatar.voiceKey = savedVoice;

      voiceSelect.addEventListener('change', (e) => {
        const selected = e.target.value;
        localStorage.setItem('chill_ai_voice', selected);
        if (this.avatar) {
          this.avatar.voiceKey = selected;
          this.avatar.stopSpeaking();
          if (this.avatar.isVoiceEnabled) {
            let previewText = "Dạ chào anh Huy! Hoài My luôn đồng hành hỗ trợ anh thiết kế nội thất ạ!";
            if (selected === 'namminh') previewText = "Chào anh Huy! Bác là thợ mộc lành nghề đây, sẵn sàng giúp anh đóng đồ gỗ và xuất CNC chuẩn xác!";
            if (selected === 'google') previewText = "Chào anh Huy! Giọng đọc Google sẵn sàng phục vụ ạ.";
            this.avatar.speakText(previewText);
          }
        }
      });
    }

    // Voice speed selector (dropdown)
    if (speedSelect) {
      speedSelect.addEventListener('change', (e) => {
        if (this.avatar) {
          this.avatar.speechSpeed = parseFloat(e.target.value) || 1.0;
        }
      });
    }

    // Send message
    const send = (customText = null) => {
      if (this.isVoiceReviewMode && this.isVoiceReviewMode()) {
        if (this.confirmVoiceAndSend) {
          this.confirmVoiceAndSend();
          return;
        }
      }
      if (this.voiceReviewReset) this.voiceReviewReset();
      const txt = (customText !== null ? customText : input.value).trim();
      if (!txt) return;
      if (this.avatar) {
        if (this.avatar.isProcessing) return; // Prevent double sending while waiting
        this.avatar.handleUserMessage(txt, true);
      }
      input.value = '';
      input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
    };

    if (sendBtn) sendBtn.addEventListener('click', () => send());
    if (input) {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') send();
      });
    }

    // Voice input button setup
    this.initVoiceInputButton(send);
  }

  // --- GOOGLE VOICE RECOGNITION (SPEECH-TO-TEXT) VỚI STREAMING REALTIME TRỰC TIẾP TRONG BÓNG CHAT & ĐẾM NGƯỢC 4S ---
  initVoiceInputButton(sendCallback) {
    const micBtn = document.getElementById('btn-voice-input');
    const input = document.getElementById('chat-input');
    const sendBtn = document.getElementById('btn-send-chat');
    const reviewBar = document.getElementById('voice-review-bar');
    const reviewHint = document.getElementById('voice-review-hint');
    const countdownBadge = document.getElementById('voice-countdown-badge');
    const cancelBtn = document.getElementById('btn-voice-cancel');
    if (!micBtn) return;

    let isRecording = false;
    let sttMonitorTimer = null;

    let countdownTimer = null;
    let countdownRemaining = 4;
    let isReviewMode = false;

    // Đảm bảo máy chủ Python ngầm chạy sẵn sàng
    const triggerEnsureServer = () => {
      if (window.sketchup && typeof window.sketchup.ensure_tts_server === 'function') {
        try { window.sketchup.ensure_tts_server(); } catch (e) {}
      }
    };
    triggerEnsureServer();

    const clearReviewTimer = () => {
      if (countdownTimer) {
        clearInterval(countdownTimer);
        countdownTimer = null;
      }
    };

    const getChatContainer = () => {
      return (this.avatar && this.avatar.chatContainer) ? this.avatar.chatContainer : document.getElementById('chat-messages');
    };

    const ensureDraftBubble = () => {
      const container = getChatContainer();
      if (!container) return null;

      let bubble = document.getElementById('voice-draft-bubble');
      if (!bubble) {
        bubble = document.createElement('div');
        bubble.className = 'chat-bubble user voice-draft';
        bubble.id = 'voice-draft-bubble';
        bubble.innerHTML = `
          <div class="voice-draft-header" id="voice-draft-header">
            <span><span class="draft-mic-pulse"></span><span id="voice-draft-state">Đang lắng nghe giọng bạn...</span></span>
            <span class="countdown-badge" id="voice-draft-badge" style="display:none;">4s</span>
          </div>
          <div class="voice-draft-text" id="voice-draft-text" contenteditable="false">🎙️ Đang nghe... Hãy nói câu lệnh cho Anh Thợ Mộc</div>
          <div class="voice-draft-actions" id="voice-draft-actions" style="display:none;">
            <button class="btn-bubble-ok" id="btn-bubble-ok" title="Gửi câu lệnh ngay">✓ OK (4s)</button>
            <button class="btn-bubble-cancel" id="btn-bubble-cancel" title="Hủy bỏ câu lệnh này">✕ Hủy</button>
          </div>
        `;
        container.appendChild(bubble);
      }
      container.scrollTop = container.scrollHeight;
      return bubble;
    };

    const resetReviewState = () => {
      clearReviewTimer();
      isReviewMode = false;
      if (this.avatar) {
        this.avatar.isListeningVoice = false;
      }
      if (input) {
        input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
      }
      if (reviewBar) reviewBar.style.display = 'none';
      if (countdownBadge) {
        countdownBadge.textContent = '4s';
        countdownBadge.classList.remove('paused');
      }
      if (sendBtn) {
        sendBtn.textContent = 'Gửi';
        sendBtn.classList.remove('btn-voice-ok');
      }
      const draftBadge = document.getElementById('voice-draft-badge');
      if (draftBadge) {
        draftBadge.textContent = '4s';
        draftBadge.classList.remove('paused');
        draftBadge.style.display = 'none';
      }
    };

    this.voiceReviewReset = () => resetReviewState();
    this.isVoiceReviewMode = () => isReviewMode;

    const confirmAndSend = () => {
      clearReviewTimer();
      const draftBubble = document.getElementById('voice-draft-bubble');
      const draftText = document.getElementById('voice-draft-text');

      let txt = '';
      if (draftText && draftText.textContent.trim()) {
        txt = draftText.textContent.trim();
      } else if (input && input.value.trim()) {
        txt = input.value.trim();
      }

      resetReviewState();

      if (txt) {
        if (draftBubble) {
          // Chuyển bóng chat nháp thành bóng chat chính thức của User tại vị trí ô khoanh đỏ
          draftBubble.removeAttribute('id');
          draftBubble.className = 'chat-bubble user';
          draftBubble.textContent = txt;
        }

        if (input) {
          input.value = '';
          input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
        }

        // Gửi cho Lyly xử lý với cờ addBubble = false (tránh trùng lặp bóng chat)
        if (this.avatar) {
          if (this.avatar.isProcessing) return;
          this.avatar.handleUserMessage(txt, false);
        }
      } else {
        if (draftBubble) draftBubble.remove();
      }
    };

    this.confirmVoiceAndSend = () => confirmAndSend();

    const pauseCountdownForEditing = () => {
      if (!isReviewMode) return;
      if (countdownTimer) {
        clearReviewTimer();
        const draftBadge = document.getElementById('voice-draft-badge');
        const draftOkBtn = document.getElementById('btn-bubble-ok');
        const draftState = document.getElementById('voice-draft-state');

        if (draftBadge) {
          draftBadge.textContent = 'Đang sửa ✍️';
          draftBadge.classList.add('paused');
        }
        if (draftOkBtn) {
          draftOkBtn.textContent = '✓ OK';
        }
        if (draftState) {
          draftState.textContent = 'Đang chỉnh sửa (bấm OK để gửi):';
        }

        if (countdownBadge) {
          countdownBadge.textContent = 'Đang sửa ✍️';
          countdownBadge.classList.add('paused');
        }
        if (reviewHint) {
          reviewHint.textContent = 'Đã dừng đếm. Sửa xong bấm OK hoặc Enter để gửi.';
        }
        if (sendBtn) {
          sendBtn.textContent = '✓ OK';
          sendBtn.classList.add('btn-voice-ok');
        }
      }
    };

    const startReviewCountdown = () => {
      const draftBubble = document.getElementById('voice-draft-bubble');
      const draftText = document.getElementById('voice-draft-text');
      const draftState = document.getElementById('voice-draft-state');
      const draftBadge = document.getElementById('voice-draft-badge');
      const draftActions = document.getElementById('voice-draft-actions');
      const draftOkBtn = document.getElementById('btn-bubble-ok');
      const draftCancelBtn = document.getElementById('btn-bubble-cancel');

      const currentText = (draftText ? draftText.textContent : (input ? input.value : '')).trim();
      if (!currentText || currentText.startsWith('Chưa nghe rõ') || currentText.startsWith('Đang chuyển')) {
        resetReviewState();
        if (draftBubble) draftBubble.remove();
        return;
      }

      if (input) input.value = currentText;

      isReviewMode = true;
      countdownRemaining = 4; // TĂNG LÊN 4 GIÂY THEO YÊU CẦU

      // Cập nhật giao diện trên bóng chat nháp
      if (draftState) draftState.textContent = 'Kiểm duyệt (4s tự gửi, bấm để sửa):';
      if (draftBadge) {
        draftBadge.style.display = 'inline-block';
        draftBadge.textContent = '4s';
        draftBadge.classList.remove('paused');
      }
      if (draftActions) draftActions.style.display = 'flex';
      if (draftOkBtn) draftOkBtn.textContent = '✓ OK (4s)';

      // Gắn sự kiện nút trên bóng chat
      if (draftOkBtn) {
        draftOkBtn.onclick = (e) => {
          e.preventDefault();
          confirmAndSend();
        };
      }
      if (draftCancelBtn) {
        draftCancelBtn.onclick = (e) => {
          e.preventDefault();
          resetReviewState();
          if (draftBubble) draftBubble.remove();
          if (input) {
            input.value = '';
            input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
          }
        };
      }

      // Cho phép sửa văn bản trực tiếp trong bóng chat
      if (draftText) {
        draftText.contentEditable = 'true';
        draftText.oninput = () => {
          if (input) input.value = draftText.textContent;
          pauseCountdownForEditing();
        };
        draftText.onfocus = () => {
          pauseCountdownForEditing();
        };
        draftText.onkeydown = (e) => {
          if (e.key === 'Enter') {
            e.preventDefault();
            confirmAndSend();
          }
        };
      }

      // Cập nhật thanh phụ và nút gửi bên dưới
      if (reviewBar) reviewBar.style.display = 'flex';
      if (reviewHint) reviewHint.textContent = '🎙️ Vừa nghe: Sửa nếu sai, hoặc chờ tự gửi (4s)';
      if (countdownBadge) {
        countdownBadge.textContent = '4s';
        countdownBadge.classList.remove('paused');
      }
      if (sendBtn) {
        sendBtn.textContent = '✓ OK (4s)';
        sendBtn.classList.add('btn-voice-ok');
      }

      const container = getChatContainer();
      if (container) container.scrollTop = container.scrollHeight;

      clearReviewTimer();
      countdownTimer = setInterval(() => {
        countdownRemaining--;
        if (countdownRemaining > 0) {
          if (draftBadge) draftBadge.textContent = `${countdownRemaining}s`;
          if (draftOkBtn) draftOkBtn.textContent = `✓ OK (${countdownRemaining}s)`;
          if (countdownBadge) countdownBadge.textContent = `${countdownRemaining}s`;
          if (sendBtn) sendBtn.textContent = `✓ OK (${countdownRemaining}s)`;
        } else {
          clearReviewTimer();
          confirmAndSend();
        }
      }, 1000);
    };

    // Nút Hủy thanh phụ và tương tác input
    if (cancelBtn) {
      cancelBtn.addEventListener('click', (e) => {
        e.preventDefault();
        const draftBubble = document.getElementById('voice-draft-bubble');
        if (draftBubble) draftBubble.remove();
        resetReviewState();
        if (input) {
          input.value = '';
          input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
        }
      });
    }

    if (input) {
      input.addEventListener('input', () => {
        const draftText = document.getElementById('voice-draft-text');
        if (draftText && isReviewMode) {
          draftText.textContent = input.value;
        }
        if (isReviewMode) {
          pauseCountdownForEditing();
        }
      });
      input.addEventListener('focus', () => {
        if (isReviewMode && countdownTimer) {
          pauseCountdownForEditing();
        }
      });
    }

    const getWaveBars = (rms) => {
      if (rms > 500) return ' ▃▅▆▇';
      if (rms > 250) return ' ▃▅▆';
      if (rms > 120) return ' ▃▅';
      if (rms > 50) return ' ▃';
      return '  ';
    };

    const startListening = async () => {
      resetReviewState();
      isRecording = true;
      micBtn.classList.add('listening');
      micBtn.innerHTML = '🔴';
      micBtn.title = 'Đang thu âm... Nói xong hãy dừng';

      // 1. NGẮT NGAY LẬP TỨC TIẾNG CỦA AI ĐANG NÓI ĐỂ TRÁNH VÒNG LẶP ECHO "GƯƠNG VÔ CỰC"!
      if (this.avatar) {
        this.avatar.stopSpeaking();
        this.avatar.isListeningVoice = true; // Chặn AI không được nói chèn vào
        this.avatar.setEmotion('listening');
      }
      if (window.sketchup && window.sketchup.stop_audio) {
        try { window.sketchup.stop_audio(''); } catch(e) {}
      }
      if (window.speechSynthesis) {
        try { window.speechSynthesis.cancel(); } catch(e) {}
      }

      // 2. TẠO BÓNG CHAT NHÁP TRỰC TIẾP TẠI VỊ TRÍ Ô KHOANH ĐỎ
      ensureDraftBubble();
      const draftState = document.getElementById('voice-draft-state');
      const draftText = document.getElementById('voice-draft-text');
      const draftActions = document.getElementById('voice-draft-actions');
      const draftBadge = document.getElementById('voice-draft-badge');
      if (draftState) draftState.textContent = 'Đang lắng nghe giọng bạn...';
      if (draftText) {
        draftText.textContent = '🎙️ Đang nghe... Hãy nói câu lệnh cho Anh Thợ Mộc';
        draftText.contentEditable = 'false';
      }
      if (draftActions) draftActions.style.display = 'none';
      if (draftBadge) draftBadge.style.display = 'none';

      if (input) {
        input.value = '';
        input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
      }

      triggerEnsureServer();

      // Bắt đầu thu âm trên máy chủ cục bộ (Direct Realtek Hardware)
      let started = false;
      try {
        const res = await fetch('http://127.0.0.1:57821/stt_start');
        if (res.ok) started = true;
      } catch (err) {
        console.warn('[STT Start Retry]: Server waking up...');
        triggerEnsureServer();
        await new Promise(r => setTimeout(r, 600));
        try {
          const res2 = await fetch('http://127.0.0.1:57821/stt_start');
          if (res2.ok) started = true;
        } catch (e) {}
      }

      if (!started) {
        console.error('[Chill AI STT]: Could not connect to local STT server.');
        if (draftText) draftText.textContent = 'Chưa kết nối máy chủ giọng nói. Đang khởi động lại...';
        if (input) input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
        stopListening(true);
        return;
      }

      // Vòng lặp giám sát âm lượng & HIỂN THỊ VĂN BẢN TRỰC TIẾP THEO THỜI GIAN THỰC (LIVE STREAMING)
      if (sttMonitorTimer) clearInterval(sttMonitorTimer);
      sttMonitorTimer = setInterval(async () => {
        if (!isRecording) {
          clearInterval(sttMonitorTimer);
          return;
        }
        try {
          const sRes = await fetch('http://127.0.0.1:57821/stt_status');
          if (sRes.ok) {
            const st = await sRes.json();
            if (!isRecording) return;

            const draftTxt = document.getElementById('voice-draft-text');
            const container = getChatContainer();

            // HIỆN VĂN BẢN VỪA NÓI NGAY THEO THỜI GIAN THỰC TRONG BÓNG CHAT Ô KHOANH ĐỎ
            if (st.interim_text) {
              if (draftTxt) draftTxt.textContent = st.interim_text;
              if (input) {
                input.value = st.interim_text;
                input.scrollLeft = input.scrollWidth;
              }
              if (container) container.scrollTop = container.scrollHeight;
            } else if (st.rms > 45) {
              const bars = getWaveBars(st.rms);
              if (draftTxt && (!draftTxt.textContent || draftTxt.textContent.startsWith('🎙️'))) {
                draftTxt.textContent = `🎙️ ${bars} (Đang thu âm...)`;
              }
            }

            // TỰ ĐỘNG NGẮT LẮNG NGHE KHI KHÔNG CÒN TIẾNG NỮA (AUTO-SILENCE DETECTION)
            if (st.silence_detected && st.duration >= 0.8) {
              console.log('[Chill AI STT]: Người dùng dứt lời, phát hiện im lặng -> Tự động kết thúc thu âm!');
              stopListening();
            }

            // Giới hạn an toàn tối đa 25s
            if (st.duration >= 25) {
              stopListening();
            }
          }
        } catch (e) {}
      }, 180);
    };

    const stopListening = async (cancelled = false) => {
      if (!isRecording && !cancelled) return;
      isRecording = false;

      if (sttMonitorTimer) {
        clearInterval(sttMonitorTimer);
        sttMonitorTimer = null;
      }

      micBtn.classList.remove('listening');
      micBtn.innerHTML = '🎙️';
      micBtn.title = 'Nói trực tiếp để ra lệnh (Google Voice Search)';

      const draftBubble = document.getElementById('voice-draft-bubble');
      const draftText = document.getElementById('voice-draft-text');
      const draftState = document.getElementById('voice-draft-state');

      if (cancelled) {
        if (draftBubble) draftBubble.remove();
        if (input) input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
        return;
      }

      if (draftState) draftState.textContent = 'Đang nhận diện giọng nói...';
      if (draftText && !input.value) {
        draftText.textContent = 'Đang chuyển giọng nói thành văn bản... ⏳';
      }
      if (input) {
        input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
      }

      try {
        const res = await fetch('http://127.0.0.1:57821/stt_stop');
        if (res.ok) {
          const data = await res.json();
          if (data.status === 'ok' && data.text) {
            console.log('[Chill AI STT]: Result from Google:', data.text);
            if (draftText) {
              draftText.textContent = data.text;
              draftText.contentEditable = 'true';
            }
            if (input) {
              input.value = data.text;
              input.scrollLeft = input.scrollWidth;
            }
            startReviewCountdown();
            return;
          } else if (data.status === 'no_speech') {
            const noSpeechMsg = 'Chưa nghe rõ giọng nói. Bạn bấm mic 🎙️ để nói lại nhé!';
            if (draftText) draftText.textContent = noSpeechMsg;
            if (input) input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
            setTimeout(() => {
              const b = document.getElementById('voice-draft-bubble');
              if (b && (!input || !input.value)) b.remove();
            }, 2500);
            return;
          }
        }
      } catch (err) {
        console.error('[Chill AI STT]: STT stop error:', err);
      }

      // Fallback nếu đã có chữ từ streaming interim
      const currentText = (input ? input.value : '').trim();
      if (currentText) {
        if (draftText) {
          draftText.textContent = currentText;
          draftText.contentEditable = 'true';
        }
        startReviewCountdown();
      } else {
        if (draftBubble) draftBubble.remove();
        if (input) input.placeholder = 'Nói hoặc gõ yêu cầu cho Anh Thợ Mộc...';
      }
    };

    micBtn.addEventListener('click', () => {
      if (isRecording) {
        stopListening();
      } else {
        startListening();
      }
    });
  }

  // --- 6. MARKETPLACE ---
  initMarketplace() {
    const buyBtns = document.querySelectorAll('.btn-buy');
    const contactBtns = document.querySelectorAll('.btn-contact-workshop');

    buyBtns.forEach(b => {
      b.addEventListener('click', () => {
        const item = b.getAttribute('data-item');
        this.showMiniToast(`[VNPay / MoMo]: Đang kết nối cổng thanh toán mua "${item}"...`, 'info', 3500);
      });
    });

    contactBtns.forEach(b => {
      b.addEventListener('click', () => {
        this.showMiniToast(`[Xưởng CNC]: Đã gửi file G-Code đến xưởng CNC gần nhất!`, 'success', 3500);
      });
    });
  }

  // --- 7. PROJECTS ---
  initProjects() {
    const modal = document.getElementById('modal-projects');
    const openBtn = document.getElementById('btn-open-projects');
    const closeBtn = document.getElementById('btn-close-projects');
    const newBtn = document.getElementById('btn-new-project');
    const listEl = document.getElementById('project-list-items');

    const loadProjects = () => {
      const stored = localStorage.getItem('chill_ai_projects');
      const projects = stored ? JSON.parse(stored) : [
        { name: "Phòng Làm Việc Hiện Đại - Căn Hộ 70m2", date: "28/09/2026", type: "desk" },
        { name: "Hệ Tủ Áo Căn Hộ Master", date: "25/09/2026", type: "cabinet" }
      ];

      if(listEl) listEl.innerHTML = '';
      projects.forEach(p => {
        const li = document.createElement('li');
        li.className = 'project-item';
        li.innerHTML = `<div><strong>${p.name}</strong><br><small style="color:#94a3b8">${p.date}</small></div><button class="btn btn-sm btn-primary">Mở</button>`;
        li.onclick = () => {
          modal.style.display = 'none';
          this.simulateSampleScan(p.type);
        };
        if(listEl) listEl.appendChild(li);
      });
    };

    openBtn.addEventListener('click', () => {
      loadProjects();
      modal.style.display = 'flex';
    });

    closeBtn.addEventListener('click', () => {
      modal.style.display = 'none';
    });

    newBtn.addEventListener('click', () => {
      modal.style.display = 'none';
      this.simulateSampleScan('desk');
    });
  }

  // ==============================================================================
  // HỆ THỐNG ĐỐI TƯỢNG 3 TẦNG & GIAO DIỆN HUD AOE (OBJECT INSPECTOR)
  // ==============================================================================
  init3TierHierarchy() {
    this.currentTier = 1;
    this.tierModels = {
      1: {
        entity_id: 10490,
        tier: 1,
        tier_label: "Tầng 1: Khối Tổng (Composite Assembly)",
        name: "Hệ Tủ Bếp Chữ L Hoàn Chỉnh",
        category: "Khối Tổng (Assembly) - Tủ Bếp Chữ L",
        icon_type: "assembly",
        dim_x: 2400, dim_y: 600, dim_z: 2200,
        length: 2400, width: 600, thickness: 17.5,
        material: "MDF Lõi Xanh Chống Ẩm Melamine An Cường",
        area_m2: 4.85, volume_m3: 0.085, edge_perimeter_m: 18.4,
        breadcrumb: ["🏰 Hệ Tủ Bếp Chữ L"],
        hardware_list: [
          { name: "Bulong liên kết module M6x30", qty: "12 bộ" },
          { name: "Chân tăng chỉnh chịu lực tủ bếp", qty: "8 chiếc" },
          { name: "Len chân tủ nhôm chống nước", qty: "2 thanh" }
        ],
        status_cnc: "✅ Đã kiểm tra liên kết & Bounding Box, sẵn sàng bóc tách CNC"
      },
      2: {
        entity_id: 10491,
        tier: 2,
        tier_label: "Tầng 2: Khối Lẻ (Module Thành Phần)",
        name: "Module Khoang Chậu Rửa (W800)",
        category: "Khối Module Độc Lập - Thùng Dưới",
        icon_type: "module",
        dim_x: 800, dim_y: 580, dim_z: 810,
        length: 800, width: 580, thickness: 17.5,
        material: "MDF Lõi Xanh Phủ Melamine Chống Ẩm",
        area_m2: 1.82, volume_m3: 0.032, edge_perimeter_m: 6.8,
        breadcrumb: ["🏰 Hệ Tủ Bếp Chữ L", "📦 Module Chậu Rửa (W800)"],
        hardware_list: [
          { name: "Bản lề giảm chấn Blum Clip Top 110°", qty: "4 chiếc" },
          { name: "Tay nắm hợp kim nhôm Hafele 160mm", qty: "2 chiếc" },
          { name: "Ốc cam liên kết & chốt gỗ phi 8", qty: "16 bộ" }
        ],
        status_cnc: "✅ Kết cấu chuẩn liên kết chốt cam & đợt tăng cứng"
      },
      3: {
        entity_id: 10492,
        tier: 3,
        tier_label: "Tầng 3: Phụ Kiện Kim Khí (Hardware)",
        name: "TAY NẮM KÉO 2-B (Hợp Kim Nhôm)",
        category: "Phụ Kiện Kim Khí",
        icon_type: "hardware",
        dim_x: 150, dim_y: 22, dim_z: 18,
        length: 150, width: 22, thickness: 18,
        material: "Hợp Kim Nhôm Anode Đen Nhám",
        area_m2: 0.003, volume_m3: 0.0001, edge_perimeter_m: 0.34,
        breadcrumb: ["🏰 Hệ Tủ Quần Áo", "🚪 Hệ Cánh Cửa", "🪵 Tay Nắm Kéo 2-B"],
        hardware_list: [
          { name: "Ốc vít M4x22 bắt qua cánh tủ", qty: "2 con" },
          { name: "Đệm cao su chống cấn Melamine", qty: "2 cái" }
        ],
        status_cnc: "✅ Tim lỗ khoan CNC chuẩn 128mm",
        goods_info: {
          sku: "HDL-ALU-TITAN-128",
          title: "[Chính Hãng Chill Decor / Hafele] Tay Nắm Hợp Kim Nhôm Đúc Nguyên Khối Anode Cao Cấp Cho Tủ Áo & Ngăn Kéo",
          brand: "Chill Hardware & Hafele Standard",
          style: "Hiện Đại Tối Giản (Modern Minimalist / Bắc Âu Luxury)",
          origin: "OEM Chuẩn Xuất Khẩu Châu Âu",
          color_options: ["Đen Nhám Anode", "Vàng Xước Titan", "Bạc Chrome Sáng", "Xám Gunmetal"],
          size_options: ["Tim 96mm (Dài 115)", "Tim 128mm (Dài 150)", "Tim 160mm (Dài 185)", "Tim 192mm (Dài 220)"],
          price_current: "32.000 đ",
          price_original: "45.000 đ",
          discount: "-29%",
          unit: "/ Cái (Kèm 02 ốc vít M4)",
          warranty: "Bảo hành 24 tháng chính hãng chống bay màu & gỉ sét mồ hôi tay",
          return_policy: "1 đổi 1 trong 30 ngày nếu lỗi ren ốc hoặc trầy xước từ nhà sản xuất",
          durability_score: "⭐ 9.9 / 10 điểm",
          user_review: "Chất nhôm đúc đầm tay chắc nịch, lớp mạ đen nhám mịn màng không bám vân tay. Bắt vào cánh tủ áo nhìn sang hơn hẳn tay nắm thông thường ngoài chợ!",
          shop_description: "• Chất liệu: Hợp kim nhôm đặc đúc áp lực cao, không rỗng ruột.\n• Công nghệ mạ: Xử lý điện hóa Anode hóa cứng chịu ma sát mồ hôi tay.\n• Phụ kiện: Tặng kèm 02 ốc vít M4x22 tiêu chuẩn cho ván 17.5mm.",
          specs: "Dài 150mm • Tim ốc 128mm • Bản rộng 12mm • Cao 22mm",
          badge: "Shopee Mall",
          rating: 4.96,
          sold_count: "18.5k đã bán",
          suppliers: [
            { name: "Tổng Kho Phụ Kiện Kim Khí Mộc Cầu Giấy", city: "Hà Nội", dist_km: 1.1, stock: "Sẵn kho 3.500 cái", phone: "0982.555.666", addr: "Nguyễn Phong Sắc, Cầu Giấy, Hà Nội" },
            { name: "Đại Lý Tay Nắm & Bản Lề Ivan Thạch Thất", city: "Hà Nội", dist_km: 2.3, stock: "Sẵn kho 6.000 cái", phone: "0971.222.333", addr: "Đường tỉnh 419, Thạch Thất, Hà Nội" },
            { name: "Kho Phụ Kiện Tủ Áo Hóc Môn TP.HCM", city: "TP. Hồ Chí Minh", dist_km: 1.5, stock: "Sẵn kho 5.200 cái", phone: "0902.333.444", addr: "Quang Trung, P.14, Gò Vấp / Q12, TP.HCM" },
            { name: "Tổng Đại Lý Phụ Kiện Mộc Thuận An Bình Dương", city: "Bình Dương", dist_km: 3.2, stock: "Sẵn kho 4.800 cái", phone: "0908.777.666", addr: "Đại Lộ Bình Dương, Thuận An, Bình Dương" }
          ]
        }
      }
    };

    this.rootModelData = this.tierModels[1];
    this.currentSelectionData = this.tierModels[1];

    // Gắn sự kiện thanh thử nghiệm 3 tầng nhanh trong 3D Viewport
    document.querySelectorAll('.btn-tier-select').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const tier = parseInt(btn.getAttribute('data-quick-tier') || "1", 10);
        this.selectTier(tier);
      });
    });

    // Gắn sự kiện Breadcrumb trên Tab Hồ Sơ
    document.querySelectorAll('.bc-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const tier = parseInt(btn.getAttribute('data-tier') || "1", 10);
        this.selectTier(tier);
      });
    });

    // Nút Zoom trong SketchUp
    const btnZoomSu = document.getElementById('btn-zoom-su');
    if (btnZoomSu) {
      btnZoomSu.addEventListener('click', () => {
        const entId = this.currentSelectionData?.entity_id || this.currentSelectionData?.entityId;
        if (entId && window.sketchup && window.sketchup.zoom_to_entity) {
          window.sketchup.zoom_to_entity(entId);
        } else {
          if (this.viewer && this.viewer.resetCamera) this.viewer.resetCamera();
          console.log("[Chill AI] Zoom to entity:", entId);
        }
      });
    }

    // Nút Làm mới vùng chọn từ SU
    const btnRefreshSel = document.getElementById('btn-refresh-selection');
    if (btnRefreshSel) {
      btnRefreshSel.addEventListener('click', () => {
        if (window.sketchup && window.sketchup.get_current_selection) {
          window.sketchup.get_current_selection();
        } else {
          this.selectTier(1);
        }
      });
    }

    const btnSyncTop = document.getElementById('btn-sync-su-top');
    if (btnSyncTop) {
      btnSyncTop.addEventListener('click', () => {
        if (window.sketchup && window.sketchup.get_current_selection) {
          window.sketchup.get_current_selection();
        }
      });
    }

    // Nút chuyển sang bóc tách CNC
    const btnSwitchCam = document.getElementById('btn-switch-to-cam');
    if (btnSwitchCam) {
      btnSwitchCam.addEventListener('click', () => {
        this.switchTab('tab-cam');
      });
    }

    // Khởi tạo Mini 3D Inspector cho Unit Portrait (Cả bản Full Studio & Khay Đứng)
    if (window.Mini3DInspector) {
      try {
        this.miniInspector = new window.Mini3DInspector('obj-portrait-3d-canvas');
        if (document.getElementById('dock-obj-portrait-3d-canvas')) {
          this.dockMiniInspector = new window.Mini3DInspector('dock-obj-portrait-3d-canvas');
        }
      } catch (err) {
        console.warn("[Chill AI] Mini3DInspector init error:", err);
      }
    }

    // Khởi tạo thanh điều hướng phụ kiện 1 chạm (Sub-Switcher)
    this.initHardwareSubSwitcher();

    // Render ban đầu an toàn
    try {
      this.updateProfileTab(this.currentSelectionData);
      this.updateObjectPortrait(this.currentSelectionData);
    } catch (err) {
      console.warn("[Chill AI] Initial 3-tier render error:", err);
    }
    
    // Mặc định ở chế độ Khay Đứng: Hiển thị Avatar Tin Tin AI sẵn sàng chào đón anh Huy
    if (document.body.classList.contains('dock-mode') || localStorage.getItem('chill_layout_mode') !== 'studio') {
      try {
        this.updateHeroObjectPreview(null);
      } catch (err) {
        console.warn("[Chill AI] Initial hero preview error:", err);
      }
    }
  }

  // --- THANH ĐIỀU HƯỚNG PHỤ KIỆN 1 CHẠM (1-TOUCH ACCESSORY SUB-SWITCHER) ---
  initHardwareSubSwitcher() {
    const chipDoor = document.getElementById('chip-switch-door');
    const chipHandle = document.getElementById('chip-switch-handle');
    const chipHinge = document.getElementById('chip-switch-hinge');

    if (chipDoor) chipDoor.addEventListener('click', () => this.switchSubHardware('door'));
    if (chipHandle) chipHandle.addEventListener('click', () => this.switchSubHardware('handle'));
    if (chipHinge) chipHinge.addEventListener('click', () => this.switchSubHardware('hinge'));
  }

  updateHardwareSubSwitcher(data) {
    const bar = document.getElementById('dock-shopee-switcher-bar');
    if (!bar) return;

    const nameLower = (data.name || '').toLowerCase();
    const isHw = (data.category && data.category.toLowerCase().includes('phụ kiện')) || 
                 (data.icon_type === 'hardware') || 
                 nameLower.includes('tay nắm') || 
                 nameLower.includes('bản lề');
    const isDoorOrDrawer = nameLower.includes('cánh') || nameLower.includes('door') || 
                           nameLower.includes('kéo') || nameLower.includes('ngăn') || 
                           nameLower.includes('ván') || (data.tier === 2 || data.tier === 3);

    if (isDoorOrDrawer || isHw) {
      bar.style.display = 'flex';
      if (!isHw) {
        this.lastSelectedDoorOrPanel = data;
        this.setSubSwitcherActive('door');
      } else if (nameLower.includes('tay nắm')) {
        this.setSubSwitcherActive('handle');
      } else if (nameLower.includes('bản lề')) {
        this.setSubSwitcherActive('hinge');
      }
    } else {
      bar.style.display = 'none';
    }
  }

  setSubSwitcherActive(target) {
    const chips = {
      door: document.getElementById('chip-switch-door'),
      handle: document.getElementById('chip-switch-handle'),
      hinge: document.getElementById('chip-switch-hinge')
    };
    Object.keys(chips).forEach(k => {
      if (chips[k]) chips[k].classList.toggle('active', k === target);
    });
  }

  switchSubHardware(target) {
    this.setSubSwitcherActive(target);

    if (target === 'handle') {
      const handleData = {
        tier: 3,
        tier_label: "Tầng 3: Phụ Kiện Kim Khí (Hardware)",
        name: "Tay Nắm Hợp Kim Nhôm Hafele Anode",
        category: "Phụ Kiện",
        icon_type: "hardware",
        material: "Hợp kim nhôm Anode Đen Nhám",
        dim_x: 128,
        dim_y: 20,
        dim_z: 15,
        length: 128,
        width: 20,
        thickness: 15,
        status_cnc: "Phụ Kiện Kim Khí Hafele Đạt Chuẩn",
        goods_info: {
          sku: "HDL-ALU-TITAN-128",
          title: "[Chính Hãng Chill Decor / Hafele] Tay Nắm Hợp Kim Nhôm Đúc Nguyên Khối Anode Cao Cấp Cho Tủ Áo & Ngăn Kéo",
          brand: "Chill Hardware & Hafele Standard",
          style: "Hiện Đại Tối Giản (Modern Minimalist / Bắc Âu Luxury)",
          origin: "OEM Chuẩn Xuất Khẩu Châu Âu",
          color_options: ["Đen Nhám Anode", "Vàng Xước Titan", "Bạc Chrome Sáng", "Xám Gunmetal"],
          size_options: ["Tim 96mm (Dài 115)", "Tim 128mm (Dài 150)", "Tim 160mm (Dài 185)", "Tim 192mm (Dài 220)"],
          price_current: "32.000 đ",
          price_original: "45.000 đ",
          discount: "-29%",
          unit: "/ Cái (Kèm 02 ốc vít M4)",
          warranty: "Bảo hành 24 tháng chính hãng chống bay màu & gỉ sét",
          return_policy: "1 đổi 1 trong 30 ngày nếu lỗi ren ốc hoặc trầy xước",
          durability_score: "⭐ 9.9 / 10 điểm",
          user_review: "“Chất nhôm đúc đầm tay chắc nịch, lớp mạ đen nhám mịn màng không bám vân tay. Bắt vào cánh tủ áo nhìn sang hơn hẳn tay nắm thông thường ngoài chợ!”",
          shop_description: "• Chất liệu: Hợp kim nhôm đặc đúc áp lực cao, không rỗng ruột.\n• Công nghệ mạ: Xử lý điện hóa Anode hóa cứng chịu ma sát mồ hôi tay.\n• Phụ kiện: Tặng kèm 02 ốc vít M4x22 tiêu chuẩn cho ván 17.5mm.",
          specs: "Dài 128mm • Cao 22mm • Bản rộng 12mm • Tim ốc chuẩn CNC",
          badge: "Shopee Mall",
          rating: 4.96,
          sold_count: "18.5k đã bán",
          suppliers: [
            { name: "Tổng Kho Phụ Kiện Kim Khí Mộc Cầu Giấy", city: "Hà Nội", dist_km: 1.1, stock: "Sẵn kho 3.500 cái", phone: "0982.555.666", addr: "Nguyễn Phong Sắc, Cầu Giấy, Hà Nội" },
            { name: "Đại Lý Tay Nắm & Bản Lề Ivan Thạch Thất", city: "Hà Nội", dist_km: 2.3, stock: "Sẵn kho 6.000 cái", phone: "0971.222.333", addr: "Đường tỉnh 419, Thạch Thất, Hà Nội" },
            { name: "Kho Phụ Kiện Tủ Áo Hóc Môn TP.HCM", city: "TP. Hồ Chí Minh", dist_km: 1.5, stock: "Sẵn kho 5.200 cái", phone: "0902.333.444", addr: "Quang Trung, P.14, Gò Vấp / Q12, TP.HCM" },
            { name: "Tổng Kho Bản Lề Tay Nắm Thuận An Bình Dương", city: "Bình Dương", dist_km: 3.6, stock: "Sẵn kho 4.800 cái", phone: "0968.111.444", addr: "Đại lộ Bình Dương, Thuận An, Bình Dương" }
          ]
        }
      };
      this.updateProfileTab(handleData);
      this.updateHeroObjectPreview(handleData);
      this.renderShopeeCard(handleData.goods_info);

    } else if (target === 'hinge') {
      const hingeData = {
        tier: 3,
        tier_label: "Tầng 3: Phụ Kiện Kim Khí (Hardware)",
        name: "Bản Lề Giảm Chấn Blum / Ivan Inox 304",
        category: "Phụ Kiện",
        icon_type: "hardware",
        material: "Inox 304 Thép Không Gỉ",
        dim_x: 65,
        dim_y: 35,
        dim_z: 12,
        length: 65,
        width: 35,
        thickness: 12,
        status_cnc: "Phụ Kiện Giảm Chấn Đạt Chuẩn",
        goods_info: {
          sku: "HW-BLUM-110-SC",
          title: "[Chính Hãng Blum / Ivan] Bản Lề Giảm Chấn Thủy Lực Inox 304 Bật Tháo Lắp Nhanh Cho Tủ Bếp & Tủ Áo",
          brand: "Blum / Ivan Austria Design",
          style: "Kỹ Thuật Công Nghiệp Đức",
          origin: "Chính Hãng Áo / Đức",
          color_options: ["Inox 304 Sáng Bóng", "Thép Mạ Niken", "Sơn Tĩnh Điện Đen Titan"],
          size_options: ["Cong vừa (Trùm nửa)", "Thẳng (Trùm ngoài)", "Cong nhiều (Lọt lòng)"],
          price_current: "38.000 đ",
          price_original: "50.000 đ",
          discount: "-24%",
          unit: "/ Cái (Kèm đế & ốc vít)",
          warranty: "Bảo hành trọn đời chống xệ cánh • 1 đổi 1 trong 1 năm",
          return_policy: "Đổi mới ngay lập tức nếu piston thủy lực xì dầu hoặc kẹt lò xo",
          durability_score: "⭐ 9.8 / 10 điểm",
          user_review: "“Đóng mở êm ru không 1 tiếng động, cánh tủ tự hít vào nhẹ nhàng. Đã dùng cho hàng trăm công trình chưa từng bị lỗi xệ cánh.”",
          shop_description: "• Thép không rỉ Inox 304 dày 1.5mm, piston đồng thủy lực đôi.\n• Góc mở rộng 110 độ, điều chỉnh 3D đa hướng (lên-xuống, ra-vào, trái-phải).\n• Đạt chứng nhận 80.000 lần đóng mở tiêu chuẩn LGA Đức.",
          specs: "Góc mở 110° • Giảm chấn thủy lực êm ái • Thử nghiệm 80.000 lần đóng mở",
          badge: "Shopee Mall",
          rating: 4.98,
          sold_count: "12.5k đã bán",
          suppliers: [
            { name: "Tổng Kho Phụ Kiện Kim Khí Blum - Hafele Cầu Giấy", city: "Hà Nội", dist_km: 0.9, stock: "Sẵn kho 2.500 bộ", phone: "0982.555.666", addr: "Nguyễn Phong Sắc, Cầu Giấy, Hà Nội" },
            { name: "Trung Tâm Phụ Kiện Ngành Mộc DTC & Ivan Thạch Thất", city: "Hà Nội", dist_km: 2.8, stock: "Sẵn kho 5.000 bộ", phone: "0971.222.333", addr: "Đường tỉnh 419, Thạch Thất, Hà Nội" },
            { name: "Tổng Kho Phụ Kiện Mộc Hóc Môn - Q12", city: "TP. Hồ Chí Minh", dist_km: 1.6, stock: "Sẵn kho 4.200 bộ", phone: "0902.333.444", addr: "Quang Trung, P.14, Gò Vấp / Q12, TP.HCM" }
          ]
        }
      };
      this.updateProfileTab(hingeData);
      this.updateHeroObjectPreview(hingeData);
      this.renderShopeeCard(hingeData.goods_info);

    } else if (target === 'door') {
      const orig = this.lastSelectedDoorOrPanel || this.currentSelectionData;
      if (orig) {
        this.updateProfileTab(orig);
        this.updateHeroObjectPreview(orig);
        if (orig.goods_info) {
          this.renderShopeeCard(orig.goods_info);
        }
      }
    }
  }

  selectTier(tierNumber) {
    this.currentTier = tierNumber;
    const data = this.tierModels[tierNumber] || this.tierModels[1];
    this.selectObject(data, null, this.tierModels[1]);

    // Cập nhật trạng thái active của nút chọn
    document.querySelectorAll('.btn-tier-select').forEach(b => {
      b.classList.toggle('active', parseInt(b.getAttribute('data-quick-tier')) === tierNumber);
    });
    document.querySelectorAll('.bc-btn').forEach(b => {
      b.classList.toggle('active', parseInt(b.getAttribute('data-tier')) === tierNumber);
    });
  }

  selectObject(data, sourceMesh = null, rootData = null, source = null) {
    if (!data) return;
    try {
      this.currentSelectionData = data;
      this.selectionSource = source || (sourceMesh ? 'plugin_3d' : (data._source || 'plugin_ui'));
      this.updateProfileTab(data);
      this.updateObjectPortrait(data, sourceMesh);
      this.updateHardwareSubSwitcher(data);

      // ==============================================================================
      // NGUYÊN TẮC HIỂN THỊ 3D VIEWPORT (STUDIO MODE) vs AVATAR:
      // 1. Avatar (Mini 3D Inspector): Hiển thị chi tiết đối tượng được click (tay nắm, bản lề, miếng ván)
      // 2. Viewport 3D lớn: LUÔN hiển thị TỔNG FILE VẬT THỂ hoặc KHỐI TỔNG LỚN NHẤT (Tầng 1).
      //    Tuyệt đối không bị thu nhỏ hoặc biến dạng thành miếng chi tiết nhỏ!
      // ==============================================================================
      let masterData = null;
      if (rootData && (rootData.tier === 1 || !rootData.tier)) {
        masterData = rootData;
      } else if (data.tier === 1) {
        masterData = data;
      } else if (this.rootModelData) {
        masterData = this.rootModelData;
      } else {
        // Fallback: Khi click chi tiết mà chưa từng có khối tổng
        const nameLower = (data.name || '').toLowerCase();
        const isWardrobe = nameLower.includes('áo') || nameLower.includes('quần áo') || nameLower.includes('wardrobe') || nameLower.includes('closet') || nameLower.includes('tu ao') || nameLower.includes('tủ') || nameLower.includes('tay nắm');
        const isKitchen = nameLower.includes('bếp') || nameLower.includes('kitchen');
        masterData = {
          tier: 1,
          name: isWardrobe ? "Hệ Tủ Quần Áo Đa Năng" : (isKitchen ? "Hệ Tủ Bếp Chữ L" : "Bàn Làm Việc Thông Minh"),
          model_type: isWardrobe ? 'wardrobe' : (isKitchen ? 'kitchen_cabinet' : 'desk'),
          dim_x: isWardrobe ? 1200 : (isKitchen ? 2400 : 1200),
          dim_y: isWardrobe ? 600 : (isKitchen ? 600 : 600),
          dim_z: isWardrobe ? 1800 : (isKitchen ? 2200 : 750),
          doors: 3,
          drawers: 2
        };
      }

      this.rootModelData = masterData;

      // Đồng bộ thông số Khối Tổng lên 3D Viewport lớn trong Studio Mode
      const masterNameLower = (masterData.name || '').toLowerCase();
      let detectedType = masterData.model_type || '';
      if (!detectedType) {
        if (masterNameLower.includes('áo') || masterNameLower.includes('quần áo') || masterNameLower.includes('wardrobe') || masterNameLower.includes('closet') || masterNameLower.includes('tu ao') || masterNameLower.includes('quan ao') || (masterNameLower.includes('tủ') && !masterNameLower.includes('bếp'))) {
          detectedType = 'wardrobe';
        } else if (masterNameLower.includes('bếp') || masterNameLower.includes('kitchen') || masterNameLower.includes('tu bep')) {
          detectedType = 'kitchen_cabinet';
        } else if (masterNameLower.includes('giường') || masterNameLower.includes('bed') || masterNameLower.includes('giuong')) {
          detectedType = 'bed';
        } else if (masterNameLower.includes('kệ') || masterNameLower.includes('shelf') || masterNameLower.includes('ke')) {
          detectedType = 'shelf';
        } else if (masterNameLower.includes('bàn') || masterNameLower.includes('desk') || masterNameLower.includes('table') || masterNameLower.includes('ban')) {
          detectedType = 'desk';
        } else {
          detectedType = 'wardrobe';
        }
      }

      if (this.currentModel) {
        this.currentModel.type = detectedType;
        this.currentModel.name = masterData.name || (detectedType === 'wardrobe' ? 'Hệ Tủ Quần Áo' : 'Bàn Làm Việc');
        this.currentModel.length = parseFloat(masterData.dim_x || masterData.length) || (detectedType === 'wardrobe' ? 1200 : 1200);
        this.currentModel.width = parseFloat(masterData.dim_y || masterData.width) || 600;
        this.currentModel.height = parseFloat(masterData.dim_z || masterData.height) || (detectedType === 'wardrobe' ? 1800 : 750);
        this.currentModel.doors = masterData.doors || 3;
        this.currentModel.drawers = masterData.drawers || 2;
      }

      // Cập nhật tiêu đề mô hình Khối Tổng trên đỉnh 3D Viewport lớn:
      const titleEl = document.getElementById('viewport-model-title');
      if (titleEl) {
        titleEl.textContent = `Mô hình: ${this.currentModel.name} (${this.currentModel.length} x ${this.currentModel.width} x ${this.currentModel.height} mm)`;
      }

      // Chỉ re-render 3D Viewport lớn nếu Khối Tổng thực sự thay đổi
      const rootKey = `${this.currentModel.type}_${this.currentModel.length}_${this.currentModel.width}_${this.currentModel.height}`;
      if (this._lastRenderedRootKey !== rootKey) {
        this._lastRenderedRootKey = rootKey;
        if (this.viewer && typeof this.viewer.updateModel === 'function') {
          try {
            this.viewer.updateModel(this.currentModel);
            if (typeof this.viewer.spinShowcase === 'function') {
              this.viewer.spinShowcase(3);
            }
          } catch (vErr) {
            console.warn("[Chill AI] Viewer updateModel error:", vErr);
          }
        }
      }

      // Xoay 3 vòng 360 độ trên cả Mini Inspector & Dock Mini Inspector
      if (this.miniInspector && typeof this.miniInspector.spinShowcase === 'function') {
        try { this.miniInspector.spinShowcase(3); } catch (e) {}
      }
      if (this.dockMiniInspector && typeof this.dockMiniInspector.spinShowcase === 'function') {
        try { this.dockMiniInspector.spinShowcase(3); } catch (e) {}
      }

      // Tự động đồng bộ thông tin hàng hóa & Nơi bán gần bạn chuẩn Shopee
      try {
        if (data.goods_info) {
          this.updateShopeeData(data.goods_info);
        } else {
          this.updateShopeeData(null);
        }
      } catch (sErr) {
        console.warn("[Chill AI] updateShopeeData error:", sErr);
      }

      // Tự động mở tab Nơi Bán & Mua Vật Tư khi chọn vật thể (chuẩn yêu cầu anh Huy)
      try {
        if (document.body.classList.contains('dock-mode') || localStorage.getItem('chill_layout_mode') !== 'studio') {
          this.switchDockTab('dock-pane-shopee');
        } else {
          this.switchTab('tab-shopee');
        }
      } catch (tErr) {
        console.warn("[Chill AI] Auto switch Shopee tab error:", tErr);
      }

      // Avatar Tin Tin tương tác trực tiếp: Báo đã nhận diện và đồng bộ 7 mục Mua Vật Tư
      if (this.avatar && data && data.name) {
        const itemTitle = data.name;
        const msg = `Lan đã nhận diện: <strong>${itemTitle}</strong>.<br>Đã cập nhật đầy đủ 7 mục thông tin hàng hóa, phân loại SKU & nơi mua gần bạn nhất vào tab <strong>Mua Vật Tư</strong> rồi nhé anh Huy! 🛒✨`;
        try {
          this.avatar.addMessage('bot', msg, {
            text: '🛒 Mở Tab Mua Vật Tư',
            onClick: () => {
              if (document.body.classList.contains('dock-mode')) {
                const btn = document.getElementById('dock-nav-shopee');
                if (btn) btn.click();
              } else {
                this.switchTab('tab-shopee');
              }
            }
          }, false);
        } catch (aErr) {
          console.warn("[Chill AI] Avatar addMessage error:", aErr);
        }
      }

      this.updatePortraitView('object');
    } catch (err) {
      console.error("[Chill AI] selectObject error:", err);
    }
  }

  on3DObjectSelected(meshData, sourceMesh = null) {
    if (!meshData) return;
    this.selectObject(meshData, sourceMesh, null, 'plugin_3d');
  }

  handleSketchupSelection(payload) {
    if (!payload) return;

    // Cập nhật cảnh báo quá khổ ván Real-time (Co kéo 3D & Dynamic Component)
    if (payload.oversized_warning) {
      this.handleOversizedWarning(payload.oversized_warning, payload.data);
    } else {
      this.handleOversizedWarning(null);
    }

    if (payload.has_selection && payload.data) {
      // NẾU người dùng đang chọn xem chi tiết trực tiếp trong 3D Plugin (tay nắm, miếng ván...),
      // TUYỆT ĐỐI không cho SketchUp polling đè ngược lại khối tủ áo!
      if (this.selectionSource === 'plugin_3d') {
        console.log("[Chill AI] Đang giữ chi tiết 3D plugin, bỏ qua selection từ SketchUp:", this.currentSelectionData?.name);
        return;
      }

      this.selectionSource = 'sketchup';
      const incomingId = payload.data.entity_id;
      const currentId = this.currentSelectionData ? this.currentSelectionData.entity_id : null;

      // Kiểm tra xem kích thước có bị thay đổi do co kéo 3D (Scale / Dynamic Component) không
      let dimChanged = false;
      if (this.currentSelectionData && payload.data) {
        const curL = Number(this.currentSelectionData.length) || 0;
        const curW = Number(this.currentSelectionData.width) || 0;
        const curH = Number(this.currentSelectionData.height) || 0;
        const newL = Number(payload.data.length) || 0;
        const newW = Number(payload.data.width) || 0;
        const newH = Number(payload.data.height) || 0;
        if (Math.abs(curL - newL) > 1.0 || Math.abs(curW - newW) > 1.0 || Math.abs(curH - newH) > 1.0) {
          dimChanged = true;
        }
      }

      // Tránh reload lại cùng một đối tượng NẾU kích thước KHÔNG đổi (để giữ chu kỳ xoay 3 vòng mượt mà)
      if (incomingId && currentId && String(incomingId) === String(currentId) && !dimChanged) {
        return;
      }
      this.selectObject(payload.data, null, payload.root_data, 'sketchup');
    } else {
      // Nếu đối tượng đang xem được chọn từ 3D Plugin (source === 'plugin_3d' hoặc 'plugin_ui'),
      // TUYỆT ĐỐI không để polling ngầm 3s của SketchUp tự ý xóa và đá về lại Anh Thợ Mộc!
      if (this.selectionSource === 'plugin_3d' || this.selectionSource === 'plugin_ui') {
        return;
      }

      if (this.currentSelectionData) {
        console.log("[Chill AI] SU Selection cleared.");
        this.currentSelectionData = null;
        this.selectionSource = null;
        this.updateHeroObjectPreview(null);
        this.updatePortraitView('ai');
      }
    }
  }

  // Quản lý hiển thị Banner & Âm thanh cảnh báo tấm quá khổ ván 1220x2440mm
  handleOversizedWarning(warning, data = null) {
    const banner = document.getElementById('dock-oversized-warning-banner');
    const badgeCount = document.getElementById('dock-oversized-badge-count');
    const detailsContainer = document.getElementById('dock-oversized-details');
    const healthFill = document.getElementById('dock-hero-obj-health-fill');
    const healthText = document.getElementById('dock-hero-obj-health-text');

    if (!warning || !warning.has_oversized || !warning.panels || warning.panels.length === 0) {
      if (banner) banner.style.setProperty('display', 'none', 'important');
      if (healthFill && this.currentSelectionData) {
        healthFill.style.width = '100%';
        healthFill.style.background = 'var(--accent-green, #2ed573)';
      }
      if (healthText && this.currentSelectionData) {
        healthText.textContent = 'Chuẩn CNC 100%';
        healthText.style.color = 'var(--text-primary, #ffffff)';
      }
      return;
    }

    // Có tấm quá khổ! Bật banner cảnh báo đỏ rực
    if (banner) banner.style.setProperty('display', 'block', 'important');
    if (badgeCount) badgeCount.textContent = `${warning.total_oversized} tấm`;

    // Cập nhật thanh máu sức khỏe CNC sang màu đỏ cảnh báo
    if (healthFill) {
      healthFill.style.width = '35%';
      healthFill.style.background = 'linear-gradient(90deg, #ff4757, #ff6b81)';
    }
    if (healthText) {
      healthText.textContent = `⚠️ QUÁ KHỔ (${warning.total_oversized} TẤM)`;
      healthText.style.color = '#ff6b81';
    }

    // Render danh sách chi tiết các tấm bị quá khổ
    if (detailsContainer) {
      detailsContainer.innerHTML = warning.panels.map(p => {
        let excessBadges = [];
        if (p.is_oversized_l) {
          excessBadges.push(`<span class="excess-pill">Dài +${p.excess_l}mm (>2440)</span>`);
        }
        if (p.is_oversized_w) {
          excessBadges.push(`<span class="excess-pill">Rộng +${p.excess_w}mm (>1220)</span>`);
        }
        return `
          <div class="oversized-item" data-id="${p.entity_id}" title="Nhấp để zoom cận cảnh tấm này trong SketchUp">
            <div class="oversized-item-header">
              <span class="oversized-item-name">🪵 ${p.name || 'Tấm ván'}</span>
              <div class="oversized-item-pills">${excessBadges.join(' ')}</div>
            </div>
            <div class="oversized-item-dims">
              Kích thước thực tế: <strong>${p.length} × ${p.width} × ${p.thickness} mm</strong>
            </div>
            <div class="oversized-item-sol">
              💡 ${p.solution || 'Cần chia nhỏ hoặc chuyển sang khổ ván lớn 2745mm'}
            </div>
          </div>
        `;
      }).join('');
    }

    // Kích hoạt giọng nói cảnh báo Lyly (throttle 6 giây tránh lặp liên tục khi kéo chuột)
    const now = Date.now();
    if (!this.lastOversizedVoiceTime || (now - this.lastOversizedVoiceTime > 6000)) {
      this.lastOversizedVoiceTime = now;
      const firstP = warning.panels[0];
      const excessInfo = firstP.is_oversized_l ? `vượt ${firstP.excess_l} mi-li-mét chiều dài` : `vượt ${firstP.excess_w} mi-li-mét chiều rộng`;
      const voiceText = `Anh Huy ơi! Phát hiện tấm ${firstP.name} ${excessInfo} so với khổ ván tiêu chuẩn hai nghìn bốn trăm bốn mươi mi-li-mét. Anh hãy kiểm tra và thu bớt hoặc chọn dùng khổ hai nghìn bảy trăm bốn mươi lăm nhé!`;

      if (this.avatar && typeof this.avatar.speak === 'function') {
        try {
          this.avatar.speak(voiceText);
        } catch (e) {
          console.warn("[Chill AI] Lyly speak error:", e);
        }
      }
      if (this.avatar && typeof this.avatar.addMessage === 'function') {
        try {
          this.avatar.setEmotion('worried');
          this.avatar.addMessage('bot', `⚠️ <strong>CẢNH BÁO QUÁ KHỔ VÁN:</strong><br>Phát hiện <strong>${warning.total_oversized} tấm</strong> vượt khổ ván 1220x2440mm! (${firstP.name}: ${firstP.length}x${firstP.width}mm, ${excessInfo}).<br>Anh có thể bấm nút <strong>[✂️ Thu Về 2440mm]</strong> hoặc chuyển sang <strong>[📐 Dùng Khổ 2745mm]</strong> ở banner bên trên nhé!`);
        } catch (e) {}
      }
    }
  }

  clearSelection() {
    this.currentSelectionData = null;
    this.selectionSource = null;
    this.updateHeroObjectPreview(null);
    this.updatePortraitView('ai');
    if (this.viewer && typeof this.viewer.highlightMesh === 'function') {
      this.viewer.highlightMesh(null);
    }
  }

  updatePortraitView(mode) {
    // 1. Studio mode elements
    const paneAi = document.getElementById('portrait-view-ai');
    const paneObj = document.getElementById('portrait-view-object');
    const nameEl = document.getElementById('portrait-figure-name');

    // 2. Dock mode elements (Đồng bộ 100% Khay Đứng)
    const dockBox = document.getElementById('dock-avatar-preview-box');
    const dockAvatarView = document.getElementById('dock-hero-avatar-view');
    const dockObjView = document.getElementById('dock-hero-object-view');
    const dockNameEl = document.getElementById('dock-hero-obj-name');

    if (mode === 'ai') {
      if (paneAi) { paneAi.classList.add('active'); paneAi.style.display = 'block'; }
      if (paneObj) { paneObj.classList.remove('active'); paneObj.style.display = 'none'; }
      if (nameEl) nameEl.textContent = 'Anh Thợ Mộc';

      if (dockBox) dockBox.classList.remove('has-object');
      if (dockAvatarView) dockAvatarView.style.display = '';
      if (dockObjView) dockObjView.style.display = 'none';
    } else {
      if (paneAi) { paneAi.classList.remove('active'); paneAi.style.display = 'none'; }
      if (paneObj) { paneObj.classList.add('active'); paneObj.style.display = 'block'; }
      if (nameEl && this.currentSelectionData) {
        nameEl.textContent = this.currentSelectionData.name || 'Đối tượng 3D';
      }

      if (dockBox) dockBox.classList.add('has-object');
      if (dockAvatarView) dockAvatarView.style.display = 'none';
      if (dockObjView) dockObjView.style.display = 'flex';
      if (dockNameEl && this.currentSelectionData) {
        dockNameEl.textContent = (this.currentSelectionData.name || 'ĐỐI TƯỢNG 3D').toUpperCase();
      }
    }
  }

  updateProfileTab(data) {
    if (!data) return;
    const tier = data.tier || 1;

    // Header Badge (Studio Mode)
    const headerBadge = document.getElementById('aoe-tier-header-badge');
    if (headerBadge) {
      headerBadge.className = `profile-badge tier-${tier}`;
      headerBadge.textContent = data.tier_label || `TẦNG ${tier}`;
    }

    // Workspace Dock Badge (Khay Đứng Mode)
    const dockWsBadge = document.getElementById('dock-ws-badge');
    if (dockWsBadge) {
      const isHw = (data.category && data.category.toLowerCase().includes('phụ kiện')) || 
                   (data.icon_type === 'hardware') || 
                   (data.name && data.name.toLowerCase().includes('tay nắm')) ||
                   (data.name && data.name.toLowerCase().includes('bản lề'));
      const badgeText = isHw ? 'TẦNG 3: PHỤ KIỆN' : (tier === 1 ? 'TẦNG 1: KHỐI TỔNG' : (tier === 2 ? 'TẦNG 2: CÁNH / MODULE' : 'TẦNG 3: TẤM VÁN'));
      dockWsBadge.textContent = badgeText;
      dockWsBadge.className = `dock-ws-badge tier-${tier}${isHw ? ' hw' : ''}`;
    }

    // Name & ID
    const nameEl = document.getElementById('detected-object-name');
    if (nameEl) nameEl.textContent = data.name || 'Đối tượng 3D';

    const idTag = document.getElementById('current-preset-tag');
    if (idTag) idTag.textContent = `ID: #ENT-${data.entity_id || '10490'}`;

    // Category
    const catEl = document.getElementById('detected-category');
    if (catEl) catEl.textContent = data.category || 'Nội thất module';

    // Specs Display
    const specsEl = document.getElementById('default-specs-display');
    if (specsEl) {
      const dx = data.dim_x || data.length || 0;
      const dy = data.dim_y || data.width || 0;
      const dz = data.dim_z || data.thickness || 0;
      specsEl.textContent = `Dài: ${dx}mm | Rộng: ${dy}mm | Cao/Dày: ${dz}mm`;
    }

    // Material
    const matEl = document.getElementById('detected-material');
    if (matEl) matEl.textContent = data.material || 'MDF Lõi Xanh';

    // Thickness
    const thickEl = document.getElementById('detected-thickness');
    if (thickEl) thickEl.textContent = `${data.thickness || 17.5}mm (Chuẩn Cắt CNC)`;

    // Area & Vol
    const areaVolEl = document.getElementById('detected-area-vol');
    if (areaVolEl) {
      areaVolEl.textContent = `Diện tích: ${data.area_m2 || 0} m² | Thể tích: ${data.volume_m3 || 0} m³`;
    }

    // Edge banding
    const edgeEl = document.getElementById('detected-edge-banding');
    if (edgeEl) {
      edgeEl.textContent = `${data.edge_perimeter_m || 0} m dán nẹp viền PVC`;
    }

    // Hardware List
    const hwEl = document.getElementById('detected-hardware');
    if (hwEl) {
      if (Array.isArray(data.hardware_list) && data.hardware_list.length > 0) {
        hwEl.textContent = data.hardware_list.map(h => `${h.name} (${h.qty})`).join(' • ');
      } else {
        hwEl.textContent = 'Chốt cam liên kết phi 15 • Đinh vít 4x35';
      }
    }

    // Status CNC
    const structEl = document.getElementById('default-structure-display');
    if (structEl) {
      structEl.textContent = data.status_cnc || '✅ Đã kiểm tra Bounding Box chuẩn xác';
    }

    // Breadcrumb buttons text
    const bc1 = document.getElementById('btn-bc-tier1');
    const bc2 = document.getElementById('btn-bc-tier2');
    const bc3 = document.getElementById('btn-bc-tier3');
    if (bc1) bc1.classList.toggle('active', tier === 1);
    if (bc2) bc2.classList.toggle('active', tier === 2);
    if (bc3) bc3.classList.toggle('active', tier === 3);

    // Đồng bộ 3 ô input kích thước Dài, Rộng, Cao trên Khay
    const inLen = document.getElementById('input-length');
    const inWid = document.getElementById('input-width');
    const inHei = document.getElementById('input-height');
    const valX = data.dim_x || data.length || 1200;
    const valY = data.dim_y || data.width || 600;
    const valZ = data.dim_z || data.height || (data.thickness ? data.thickness : 750);
    if (inLen) inLen.value = valX;
    if (inWid) inWid.value = valY;
    if (tier === 1) {
      this.currentModel.length = valX;
      this.currentModel.width = valY;
      this.currentModel.height = valZ;
    }

    // Đồng bộ Cây Phân Cấp Outliner Tree View (Cha -> Con -> Cháu)
    const t1 = document.getElementById('tree-node-1');
    const t2 = document.getElementById('tree-node-2');
    const t3 = document.getElementById('tree-node-3');
    if (t1) t1.classList.toggle('active', tier === 1);
    if (t2) t2.classList.toggle('active', tier === 2);
    if (t3) t3.classList.toggle('active', tier === 3);

    const title1 = document.getElementById('tree-title-1');
    const title2 = document.getElementById('tree-title-2');
    const title3 = document.getElementById('tree-title-3');
    if (tier === 1 && title1 && data.name) title1.textContent = data.name;
    if (tier === 2 && title2 && data.name) title2.textContent = data.name;
    if (tier === 3 && title3 && data.name) title3.textContent = data.name;

    // --- ĐỒNG BỘ SANG CHẾ ĐỘ KHAY ĐỨNG (DOCK TRAY MODE) ---
    const dockName = document.getElementById('dock-detected-object-name');
    if (dockName) dockName.textContent = data.name || 'Đối tượng 3D';

    const dockId = document.getElementById('dock-detected-id');
    if (dockId) dockId.textContent = `ID: #ENT-${data.entity_id || '10490'}`;

    const dockSpecs = document.getElementById('dock-specs-summary-display');
    if (dockSpecs) dockSpecs.textContent = `Dài: ${valX}mm | Rộng: ${valY}mm | Cao: ${valZ}mm`;

    const dockInLen = document.getElementById('dock-input-length');
    const dockInWid = document.getElementById('dock-input-width');
    const dockInHei = document.getElementById('dock-input-height');
    if (dockInLen) dockInLen.value = valX;
    if (dockInWid) dockInWid.value = valY;
    if (dockInHei) dockInHei.value = valZ;

    const dockStruct = document.getElementById('dock-structure-display');
    if (dockStruct && data.status_cnc) dockStruct.textContent = data.status_cnc;

    const dockTree1 = document.getElementById('dock-tree-node-1');
    const dockTree2 = document.getElementById('dock-tree-node-2');
    const dockTree3 = document.getElementById('dock-tree-node-3');
    if (dockTree1) dockTree1.classList.toggle('active', tier === 1);
    if (dockTree2) dockTree2.classList.toggle('active', tier === 2);
    if (dockTree3) dockTree3.classList.toggle('active', tier === 3);

    const dockTitle1 = document.getElementById('dock-tree-title-1');
    const dockTitle2 = document.getElementById('dock-tree-title-2');
    const dockTitle3 = document.getElementById('dock-tree-title-3');
    if (tier === 1 && dockTitle1 && data.name) dockTitle1.textContent = data.name;
    if (tier === 2 && dockTitle2 && data.name) dockTitle2.textContent = data.name;
    if (tier === 3 && dockTitle3 && data.name) dockTitle3.textContent = data.name;
  }

  updateObjectPortrait(data, sourceMesh = null) {
    if (!data) return;
    const tier = data.tier || 1;

    // Badge trong khung Avatar
    const badge = document.getElementById('obj-portrait-tier-badge');
    const dockBadge = document.getElementById('dock-obj-tier-badge');
    const labelText = tier === 1 ? '🏰 [TẦNG 1] KHỐI TỔNG' : (tier === 2 ? '📦 [TẦNG 2] KHỐI LẺ' : '🪵 [TẦNG 3] TẤM VÁN/PHỤ KIỆN');
    if (badge) {
      badge.className = `obj-portrait-badge tier-${tier}`;
      badge.textContent = labelText;
    }
    if (dockBadge) {
      dockBadge.textContent = labelText;
    }

    // Khởi chạy Mini 3D Inspector WebGL thực tế xoay 360 độ
    if (this.miniInspector) {
      this.miniInspector.inspect(data, sourceMesh);
    } else {
      // Fallback SVG nếu môi trường không hỗ trợ WebGL
      const svgBox = document.getElementById('obj-portrait-svg');
      if (svgBox) {
        svgBox.style.display = 'block';
        svgBox.innerHTML = this.renderIsometricObjectSVG(tier, data.icon_type || 'panel');
      }
    }

    // Thanh đo chuẩn CNC
    const hpFill = document.getElementById('obj-portrait-health-fill');
    const hpText = document.getElementById('obj-portrait-health-text');
    if (hpFill) hpFill.style.width = '100%';
    if (hpText) hpText.textContent = 'Chuẩn CNC 100%';

    // Tên đối tượng dưới khung hình
    const nameEl = document.getElementById('portrait-figure-name');
    if (nameEl && (this.currentActiveTab === 'tab-scan' || !this.currentActiveTab)) {
      nameEl.textContent = data.name || 'Đối tượng 3D';
    }

    // Cập nhật Ô ĐỎ (Hero Preview Box 60%) theo ảnh vẽ tay của anh Huy
    this.updateHeroObjectPreview(data, sourceMesh);
  }

  // Cập nhật Ô ĐỎ trên đỉnh Khay Đứng: Đồng bộ 100% với bản Full Studio (Ảnh 1)
  updateHeroObjectPreview(data, sourceMesh = null) {
    const previewBox = document.getElementById('dock-avatar-preview-box');
    const avatarView = document.getElementById('dock-hero-avatar-view');
    const objView = document.getElementById('dock-hero-object-view');
    const badgeEl = document.getElementById('dock-hero-obj-badge');
    const nameEl = document.getElementById('dock-hero-obj-name');
    const healthFill = document.getElementById('dock-hero-obj-health-fill');
    const healthText = document.getElementById('dock-hero-obj-health-text');

    if (data && (data.name || data.dim_x || data.length)) {
      // Chuyển sang hiển thị mô hình 3D Inspector
      if (previewBox) previewBox.classList.add('has-object');
      if (avatarView) avatarView.style.display = 'none';
      if (objView) objView.style.display = 'flex';

      const tier = data.tier || 1;
      const isHw = (data.category && data.category.toLowerCase().includes('phụ kiện')) || 
                   (data.icon_type === 'hardware') || 
                   (data.name && data.name.toLowerCase().includes('tay nắm')) ||
                   (data.name && data.name.toLowerCase().includes('bản lề'));
      const tierLabel = isHw ? '🔩 [TẦNG 3] PHỤ KIỆN' : (tier === 1 ? '🏰 [TẦNG 1] KHỐI TỔNG' : (tier === 2 ? '📦 [TẦNG 2] KHỐI LẺ' : '🪵 [TẦNG 3] TẤM VÁN'));
      if (badgeEl) {
        badgeEl.className = `obj-portrait-badge tier-${tier}${isHw ? ' hw' : ''}`;
        badgeEl.textContent = tierLabel;
      }

      // Đồng bộ nhãn Tầng trên thanh header Workspace (#dock-ws-badge)
      const dockWsBadge = document.getElementById('dock-ws-badge');
      if (dockWsBadge) {
        const badgeText = isHw ? 'TẦNG 3: PHỤ KIỆN' : (tier === 1 ? 'TẦNG 1: KHỐI TỔNG' : (tier === 2 ? 'TẦNG 2: CÁNH / MODULE' : 'TẦNG 3: TẤM VÁN'));
        dockWsBadge.textContent = badgeText;
        dockWsBadge.className = `dock-ws-badge tier-${tier}${isHw ? ' hw' : ''}`;
      }
      if (nameEl) {
        nameEl.textContent = (data.name || 'ĐỐI TƯỢNG 3D').toUpperCase();
      }
      if (healthFill) healthFill.style.width = '100%';
      if (healthText) healthText.textContent = data.status_cnc || 'Chuẩn CNC 100%';

      // 1. Chạy Three.js Mini3DInspector thực tế để hiển thị vật thể 3D xoay 360 độ như bản Full màn hình
      if (!this.dockMiniInspector && window.Mini3DInspector && document.getElementById('dock-obj-portrait-3d-canvas')) {
        try {
          this.dockMiniInspector = new window.Mini3DInspector('dock-obj-portrait-3d-canvas');
        } catch (e) {
          console.warn("[Chill AI] Lazy init dockMiniInspector err:", e);
        }
      }
      if (this.dockMiniInspector) {
        this.dockMiniInspector.inspect(data, sourceMesh);
      } else {
        const canvas = document.getElementById('dock-obj-portrait-3d-canvas');
        if (canvas) {
          this.renderHero3DCanvas(canvas, data);
        }
      }
    } else {
      // Quay về Avatar Tin Tin AI
      if (previewBox) previewBox.classList.remove('has-object');
      if (avatarView) avatarView.style.display = '';
      if (objView) objView.style.display = 'none';

      const dockWsBadge = document.getElementById('dock-ws-badge');
      if (dockWsBadge) {
        dockWsBadge.textContent = 'TRỢ LÝ AI';
        dockWsBadge.className = 'dock-ws-badge tier-1';
      }
    }
  }

  // Vẽ mô phỏng 3D Isometric chuẩn kích thước thật lên canvas Ô ĐỎ
  renderHero3DCanvas(canvas, data) {
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    const nameLower = (data.name || '').toLowerCase();
    const isHw = (data.category && data.category.toLowerCase().includes('phụ kiện')) || 
                 (data.icon_type === 'hardware') || 
                 nameLower.includes('tay nắm') || 
                 nameLower.includes('bản lề');

    if (isHw) {
      const cx = w / 2;
      const cy = h / 2;
      ctx.fillStyle = '#e2e8f0';
      ctx.strokeStyle = '#94a3b8';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      if (ctx.roundRect) {
        ctx.roundRect(cx - 36, cy - 8, 72, 8, 3);
      } else {
        ctx.rect(cx - 36, cy - 8, 72, 8);
      }
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = '#64748b';
      ctx.fillRect(cx - 24, cy, 8, 14);
      ctx.fillRect(cx + 16, cy, 8, 14);

      ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(cx - 32, cy - 5);
      ctx.lineTo(cx + 32, cy - 5);
      ctx.stroke();
      return;
    }

    const len = data.dim_x || data.length || 1200;
    const wid = data.dim_y || data.width || 600;
    const hei = data.dim_z || data.height || (data.thickness ? data.thickness : 750);

    const maxDim = Math.max(len, wid, hei, 1);
    const scale = 48 / maxDim;
    const dx = Math.max(16, Math.min(62, len * scale));
    const dy = Math.max(10, Math.min(32, wid * scale * 0.7));
    const dz = Math.max(12, Math.min(46, hei * scale));

    const cx = w / 2;
    const cy = h / 2 + dz / 3;

    // Tọa độ đỉnh Isometric
    const p0 = { x: cx, y: cy };
    const p1 = { x: cx - dx, y: cy - dy * 0.5 };
    const p2 = { x: cx, y: cy - dy };
    const p3 = { x: cx + dx, y: cy - dy * 0.5 };

    const t0 = { x: p0.x, y: p0.y - dz };
    const t1 = { x: p1.x, y: p1.y - dz };
    const t2 = { x: p2.x, y: p2.y - dz };
    const t3 = { x: p3.x, y: p3.y - dz };

    // Mặt trên (Top Face) - Vàng sáng
    ctx.beginPath();
    ctx.moveTo(t0.x, t0.y);
    ctx.lineTo(t1.x, t1.y);
    ctx.lineTo(t2.x, t2.y);
    ctx.lineTo(t3.x, t3.y);
    ctx.closePath();
    ctx.fillStyle = '#fef08a';
    ctx.fill();
    ctx.strokeStyle = '#d97706';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // Mặt trái (Left Face) - Gỗ tối
    ctx.beginPath();
    ctx.moveTo(p0.x, p0.y);
    ctx.lineTo(p1.x, p1.y);
    ctx.lineTo(t1.x, t1.y);
    ctx.lineTo(t0.x, t0.y);
    ctx.closePath();
    ctx.fillStyle = '#b45309';
    ctx.fill();
    ctx.strokeStyle = '#78350f';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // Mặt phải (Right Face) - Gỗ ấm
    ctx.beginPath();
    ctx.moveTo(p0.x, p0.y);
    ctx.lineTo(p3.x, p3.y);
    ctx.lineTo(t3.x, t3.y);
    ctx.lineTo(t0.x, t0.y);
    ctx.closePath();
    ctx.fillStyle = '#f59e0b';
    ctx.fill();
    ctx.strokeStyle = '#b45309';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // Đường chỉ bóng sáng nhẹ
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.4)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(t0.x, t0.y);
    ctx.lineTo(t3.x, t3.y);
    ctx.stroke();
  }

  // Trình sinh hình ảnh độc lập Isometric chất lượng cao cho AOE Inspector
  renderIsometricObjectSVG(tier, iconType) {
    if (tier === 1) {
      // 🏰 TẦNG 1: KHỐI TỔNG (Tủ Bếp Đa Khối Isometric với Tủ Trên, Kính Ốp, Tủ Dưới)
      return `
        <!-- Nền tỏa sáng AOE Gold -->
        <defs>
          <linearGradient id="grad-gold" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#f59e0b" />
            <stop offset="100%" stop-color="#b45309" />
          </linearGradient>
          <linearGradient id="grad-wood" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#ca8a04" />
            <stop offset="100%" stop-color="#713f12" />
          </linearGradient>
          <linearGradient id="grad-glass" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#38bdf8" stop-opacity="0.9"/>
            <stop offset="100%" stop-color="#0284c7" stop-opacity="0.9"/>
          </linearGradient>
        </defs>

        <!-- Khung viền và khối isometric Tầng 1 -->
        <g transform="translate(10, 15) scale(0.88)">
          <!-- Tủ Treo Trên (Upper Cabinets) -->
          <polygon points="40,25 120,25 145,45 65,45" fill="#fef08a" stroke="#d97706" stroke-width="1.5"/>
          <polygon points="40,25 65,45 65,85 40,65" fill="#b45309" stroke="#78350f" stroke-width="1.5"/>
          <polygon points="65,45 145,45 145,85 65,85" fill="#fde047" stroke="#d97706" stroke-width="1.5"/>
          <!-- Đường chia cánh tủ trên -->
          <line x1="105" y1="45" x2="105" y2="85" stroke="#b45309" stroke-width="1.2"/>

          <!-- Kính Ốp Bếp (Cyan Glass Backsplash) -->
          <polygon points="65,85 145,85 145,105 65,105" fill="url(#grad-glass)" stroke="#0284c7" stroke-width="1"/>
          <polygon points="40,65 65,85 65,105 40,85" fill="#0369a1" stroke="#0284c7" stroke-width="1"/>

          <!-- Mặt Đá Bếp Dưới (Countertop) -->
          <polygon points="35,103 125,103 150,118 60,118" fill="#f8fafc" stroke="#94a3b8" stroke-width="1.5"/>

          <!-- Tủ Dưới (Lower Cabinets - Warm Oak) -->
          <polygon points="38,118 60,118 60,165 38,150" fill="url(#grad-wood)" stroke="#451a03" stroke-width="1.5"/>
          <polygon points="60,118 148,118 148,165 60,165" fill="#d97706" stroke="#78350f" stroke-width="1.5"/>
          <!-- Đường chia ngăn kéo & cánh -->
          <line x1="104" y1="118" x2="104" y2="165" stroke="#78350f" stroke-width="1.2"/>
          <rect x="75" y="130" width="14" height="2.5" rx="1" fill="#ffffff" stroke="#000" stroke-width="0.5"/>
          <rect x="118" y="130" width="14" height="2.5" rx="1" fill="#ffffff" stroke="#000" stroke-width="0.5"/>

          <!-- Len Chân Tủ -->
          <polygon points="44,150 63,165 144,165 144,172 63,172 44,155" fill="#1e293b" opacity="0.8"/>
        </g>
      `;
    } else if (tier === 2) {
      // 📦 TẦNG 2: KHỐI LẺ (1 Module Khoang Tủ Độc Lập)
      return `
        <defs>
          <linearGradient id="grad-module" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#38bdf8" />
            <stop offset="100%" stop-color="#0369a1" />
          </linearGradient>
        </defs>
        <g transform="translate(18, 15) scale(0.9)">
          <!-- Nóc Thùng Module -->
          <polygon points="30,35 110,35 135,55 55,55" fill="#7dd3fc" stroke="#0284c7" stroke-width="2"/>
          <!-- Vách Hồi Trái -->
          <polygon points="30,35 55,55 55,145 30,125" fill="#0369a1" stroke="#075985" stroke-width="2"/>
          <!-- Mặt Trước: Cánh Mở 2 Bên -->
          <polygon points="55,55 135,55 135,145 55,145" fill="#bae6fd" stroke="#0284c7" stroke-width="2"/>
          <!-- Khe hở 2 cánh -->
          <line x1="95" y1="55" x2="95" y2="145" stroke="#0369a1" stroke-width="2"/>
          <!-- 2 Tay Nắm Hợp Kim Dọc -->
          <rect x="88" y="75" width="3" height="24" rx="1" fill="#0f172a" stroke="#f8fafc" stroke-width="0.8"/>
          <rect x="99" y="75" width="3" height="24" rx="1" fill="#0f172a" stroke="#f8fafc" stroke-width="0.8"/>
          <!-- Chân Đế Tủ -->
          <circle cx="45" cy="148" r="4" fill="#0f172a"/>
          <circle cx="125" cy="148" r="4" fill="#0f172a"/>
        </g>
      `;
    } else {
      // 🪵 TẦNG 3: MIẾNG VÁN NHỎ HOẶC PHỤ KIỆN
      if (iconType === 'hardware') {
        // Phụ kiện: Tay nắm nhôm hoặc Bản lề
        return `
          <g transform="translate(20, 25)">
            <!-- Tay Nắm Nhôm Hafele 3D Phẳng -->
            <rect x="15" y="45" width="90" height="18" rx="4" fill="url(#grad-metal)" stroke="#94a3b8" stroke-width="2"/>
            <rect x="25" y="49" width="70" height="10" rx="2" fill="#cbd5e1"/>
            <!-- 2 Chân Bắt Vít -->
            <rect x="25" y="63" width="12" height="25" rx="2" fill="#475569" stroke="#334155" stroke-width="1.5"/>
            <rect x="83" y="63" width="12" height="25" rx="2" fill="#475569" stroke="#334155" stroke-width="1.5"/>
            <!-- Lỗ vít -->
            <circle cx="31" cy="80" r="3" fill="#0f172a"/>
            <circle cx="89" cy="80" r="3" fill="#0f172a"/>
          </g>
        `;
      } else {
        // Tấm ván gỗ bóc tách CNC (Vách Hồi / Mặt Cánh)
        return `
          <g transform="translate(18, 18) scale(0.92)">
            <!-- Tấm Ván MDF Cắt CNC với Chỉ Nẹp PVC & Lỗ Cam -->
            <polygon points="25,30 115,30 135,50 45,50" fill="#a7f3d0" stroke="#059669" stroke-width="2"/>
            <polygon points="25,30 45,50 45,145 25,125" fill="#047857" stroke="#064e3b" stroke-width="2"/>
            <polygon points="45,50 135,50 135,145 45,145" fill="#34d399" stroke="#059669" stroke-width="2"/>
            
            <!-- Chỉ Nẹp PVC Viền Cạnh Nổi Bật -->
            <line x1="45" y1="50" x2="135" y2="50" stroke="#fde047" stroke-width="2.5" stroke-linecap="round"/>
            <line x1="135" y1="50" x2="135" y2="145" stroke="#fde047" stroke-width="2.5" stroke-linecap="round"/>

            <!-- Lỗ Khoan Định Vị Ốc Cam Phi 15 & Chốt Gỗ Phi 8 -->
            <circle cx="65" cy="70" r="4.5" fill="#064e3b" stroke="#fef08a" stroke-width="1.2"/>
            <circle cx="65" cy="125" r="4.5" fill="#064e3b" stroke="#fef08a" stroke-width="1.2"/>
            <circle cx="115" cy="70" r="3.2" fill="#0f172a"/>
            <circle cx="115" cy="125" r="3.2" fill="#0f172a"/>

            <!-- Ký hiệu mã tấm ván CNC -->
            <text x="75" y="103" font-family="monospace" font-size="11" font-weight="bold" fill="#064e3b">V-01</text>
          </g>
        `;
      }
    }
  }
  // ==========================================================================
  // DUAL MODE LAYOUT SYSTEM & DOCK TRAY CONTROLLER (CHUẨN BẢN VẼ TAY ANH HUY)
  // ==========================================================================
  initDockModeToggle() {
    // 1. Phục hồi chế độ đã lưu (mặc định là 'dock' chuẩn khay đứng)
    const savedMode = localStorage.getItem('chill_layout_mode') || 'dock';
    this.switchLayoutMode(savedMode, savedMode === 'studio');

    // 2. Nút chuyển đổi từ Studio -> Khay Đứng SU
    const btnToDock = document.getElementById('btn-toggle-dock-mode');
    if (btnToDock) {
      btnToDock.addEventListener('click', () => {
        this.switchLayoutMode('dock', true);
      });
    }

    // 3. Nút chuyển đổi từ Khay Đứng -> Toàn Cảnh Studio
    const btnToStudio = document.getElementById('dock-btn-to-studio');
    if (btnToStudio) {
      btnToStudio.addEventListener('click', () => {
        this.switchLayoutMode('studio', true);
      });
    }

    // 4. Lắng nghe resize cửa sổ để đồng bộ Three.js (Chiều ngang co kéo hoàn toàn tự do)
    window.addEventListener('resize', () => {
      if (this.viewer && this.viewer.onWindowResize) {
        this.viewer.onWindowResize();
      }
      if (this.miniInspector && this.miniInspector.onResize) {
        this.miniInspector.onResize();
      }
      if (this.dockMiniInspector && this.dockMiniInspector.onResize) {
        this.dockMiniInspector.onResize();
      }
    });

    // 5. Khởi tạo toàn bộ tương tác cho Khay Đứng chuẩn ảnh 1
    this.initDockTrayInteractions();
  }

  switchLayoutMode(mode, notifyRuby = true) {
    if (mode === 'studio') {
      document.body.classList.remove('dock-mode');
      document.body.classList.add('studio-mode');
      localStorage.setItem('chill_layout_mode', 'studio');

      if (notifyRuby && window.sketchup && window.sketchup.set_window_layout_mode) {
        window.sketchup.set_window_layout_mode('studio');
      }
      console.log('[Chill AI] Đã chuyển sang Chế độ Toàn Cảnh Studio (1120x635)');
    } else {
      document.body.classList.remove('studio-mode');
      document.body.classList.add('dock-mode');
      localStorage.setItem('chill_layout_mode', 'dock');

      if (notifyRuby && window.sketchup && window.sketchup.set_window_layout_mode) {
        window.sketchup.set_window_layout_mode('dock_tray');
      }
      console.log('[Chill AI] Đã chuyển sang Chế độ Khay Đứng SketchUp (320x635)');
    }

    // Cập nhật Three.js render mượt mà
    setTimeout(() => {
      if (this.viewer && this.viewer.onWindowResize) {
        this.viewer.onWindowResize();
      }
      if (this.miniInspector && this.miniInspector.onResize) {
        this.miniInspector.onResize();
      }
    }, 150);
  }

  // ==============================================================================
  // MASTER-DETAIL SIDEBAR-WORKSPACE INTERACTION HANDLERS (CHUẨN UX SKETCHUP 2026)
  // ==============================================================================
  switchDockTab(tabId) {
    const tabMeta = {
      'dock-pane-chat': { title: 'Trợ Lý Tin Tin AI', icon: '💬' },
      'dock-pane-hierarchy': { title: 'Cấu Trúc 3 Tầng Outliner', icon: '📁' },
      'dock-pane-specs': { title: 'Thông Số Kỹ Thuật', icon: '📐' },
      'dock-pane-dc': { title: 'Tùy Chỉnh Dynamic Component', icon: '🛠️' },
      'dock-pane-cnc': { title: 'Bóc Tách & File G-Code CNC', icon: '⚙️' },
      'dock-pane-vision': { title: 'Quét Ảnh Thiết Kế AI', icon: '📸' },
      'dock-pane-3d': { title: 'Mô Phỏng 3D Mini Inspector', icon: '👁️' },
      'dock-pane-shopee': { title: 'Mua Vật Tư & Nơi Bán Gần Bạn', icon: '🛒' }
    };

    // 1. Highlight nút sidebar
    document.querySelectorAll('.dock-sidebar-nav-btn').forEach(btn => {
      if (btn.getAttribute('data-tab') === tabId) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    // 2. Chuyển đổi Pane màn hình chính bên phải
    document.querySelectorAll('.dock-workspace-pane').forEach(pane => {
      if (pane.id === tabId) {
        pane.style.display = 'flex';
        pane.classList.add('active');
      } else {
        pane.style.display = 'none';
        pane.classList.remove('active');
      }
    });

    // 3. Cập nhật Tiêu đề & Icon trên Workspace Header
    const meta = tabMeta[tabId] || { title: 'Không Gian Làm Việc', icon: '⚡' };
    const wsTitle = document.getElementById('dock-ws-title');
    const wsIcon = document.getElementById('dock-ws-icon');
    if (wsTitle) wsTitle.textContent = meta.title;
    if (wsIcon) wsIcon.textContent = meta.icon;

    // 4. Kích hoạt render 3D / Nesting nếu chuyển đến tab đó
    if (tabId === 'dock-pane-3d') {
      setTimeout(() => {
        if (this.miniInspector) {
          if (this.miniInspector.onResize) this.miniInspector.onResize();
          if (this.currentSelectionData) this.miniInspector.inspect(this.currentSelectionData);
        }
      }, 50);
    } else if (tabId === 'dock-pane-cnc') {
      setTimeout(() => {
        const c = document.getElementById('dock-nesting-canvas');
        if (c && this.lastNestingData) {
          this.renderNestingCanvas(this.lastNestingData);
        }
      }, 50);
    } else if (tabId === 'dock-pane-shopee') {
      setTimeout(() => {
        this.renderShopeeSuppliers();
      }, 30);
    }
  }

  // Khởi tạo toàn bộ tương tác cho giao diện Master-Detail 2 Cột
  initDockTrayInteractions() {
    // A. CHUYỂN TAB TỪ SIDEBAR TRÁI SANG MÀN HÌNH CHÍNH PHẢI
    document.querySelectorAll('.dock-sidebar-nav-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const targetTab = btn.getAttribute('data-tab');
        if (targetTab) this.switchDockTab(targetTab);
      });
    });

    // 1. Click vào Ô ĐỎ (Hero Preview Box) -> MỞ NGAY TAB HỒ SƠ MẶC ĐỊNH (THÔNG SỐ) CHUẨN YÊU CẦU ANH HUY
    const heroRedBox = document.getElementById('dock-avatar-preview-box') || document.getElementById('dock-avatar-green-box');
    heroRedBox?.addEventListener('click', (e) => {
      // Nếu click hoặc tương tác trực tiếp trên 3D canvas thì cho phép người dùng xoay 360 độ, không nhảy tab
      if (e.target && (e.target.id === 'dock-obj-portrait-3d-canvas' || e.target.closest('#dock-object-canvas-wrapper'))) return;
      this.switchDockTab('dock-pane-specs');
      console.log('[Chill AI] Đã mở tab Hồ Sơ Mặc Định từ Ô Đỏ Preview');
    });

    // 2. Click vào các nút Gợi Ý Tác Vụ Nhanh trong Ô XANH DƯƠNG
    document.querySelectorAll('.dock-prompt-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const prompt = chip.getAttribute('data-prompt');
        if (prompt) {
          this.switchDockTab('dock-pane-chat');
          const chatInput = document.getElementById('dock-chat-input');
          if (chatInput) chatInput.value = prompt;
          if (this.avatar && this.avatar.handleUserMessage) {
            this.avatar.handleUserMessage(prompt);
            if (chatInput) chatInput.value = '';
          }
        }
      });
    });

    // C. CÂY OUTLINER 3 TẦNG TRÊN KHAY ĐỨNG (CHA ➔ CON ➔ CHÁU)
    document.querySelectorAll('.dock-tree-node').forEach(node => {
      node.addEventListener('click', (e) => {
        e.stopPropagation();
        const tier = parseInt(node.getAttribute('data-tier'));
        if (tier) {
          this.selectTier(tier);
          document.querySelectorAll('.dock-tree-node').forEach(n => n.classList.remove('active'));
          node.classList.add('active');
        }
      });
    });

    // Nút đồng bộ & zoom trong cây outliner
    document.getElementById('dock-btn-sync-su-tree')?.addEventListener('click', () => {
      if (window.sketchup && window.sketchup.get_current_selection) {
        window.sketchup.get_current_selection();
        this.showMiniToast('Đang quét lại cấu trúc đối tượng từ SketchUp...', 'info');
      }
    });
    document.getElementById('dock-btn-zoom-su')?.addEventListener('click', () => {
      const entId = this.currentSelectionData?.entityId || this.currentSelectionData?.entity_id;
      if (entId && window.sketchup && window.sketchup.zoom_to_entity) {
        window.sketchup.zoom_to_entity(entId);
      }
    });

    // D. SỬA NHANH SỐ ĐO KÍCH THƯỚC TRÊN KHAY ĐỨNG (DÀI - RỘNG - CAO)
    const inLen = document.getElementById('dock-input-length');
    const inWid = document.getElementById('dock-input-width');
    const inHei = document.getElementById('dock-input-height');
    const syncDimensions = () => {
      const l = parseInt(inLen ? inLen.value : 1200) || 1200;
      const w = parseInt(inWid ? inWid.value : 600) || 600;
      const h = parseInt(inHei ? inHei.value : 1800) || 1800;

      this.currentModel.length = l;
      this.currentModel.width = w;
      this.currentModel.height = h;

      const summary = document.getElementById('dock-specs-summary-display');
      if (summary) summary.textContent = `Dài: ${l}mm | Rộng: ${w}mm | Cao: ${h}mm`;

      const stdLen = document.getElementById('input-length');
      const stdWid = document.getElementById('input-width');
      const stdHei = document.getElementById('input-height');
      if (stdLen) stdLen.value = l;
      if (stdWid) stdWid.value = w;
      if (stdHei) stdHei.value = h;
    };
    inLen?.addEventListener('input', syncDimensions);
    inWid?.addEventListener('input', syncDimensions);
    inHei?.addEventListener('input', syncDimensions);

    // Đồng bộ vật liệu & độ dày
    document.getElementById('dock-select-material')?.addEventListener('change', (e) => {
      this.currentModel.material = e.target.value;
      const stdMat = document.getElementById('select-material');
      if (stdMat) stdMat.value = e.target.value;
    });
    document.getElementById('dock-select-thickness')?.addEventListener('change', (e) => {
      this.currentModel.thickness = parseFloat(e.target.value) || 18;
      const stdThick = document.getElementById('select-thickness');
      if (stdThick) stdThick.value = e.target.value;
    });

    // E. CHAT & RA LỆNH TIN TIN TRÊN KHAY ĐỨNG
    const chatInput = document.getElementById('dock-chat-input');
    const sendBtn = document.getElementById('dock-btn-send-chat');
    const micBtn = document.getElementById('dock-btn-voice-input');

    const handleDockChat = () => {
      const msg = chatInput?.value?.trim();
      if (!msg) return;
      chatInput.value = '';
      if (this.avatar && this.avatar.handleUserMessage) {
        this.avatar.handleUserMessage(msg);
      }
    };
    sendBtn?.addEventListener('click', handleDockChat);
    chatInput?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') handleDockChat();
    });
    micBtn?.addEventListener('click', () => {
      const stdMic = document.getElementById('btn-voice-input');
      if (stdMic) stdMic.click();
    });

    // F. TAB QUÉT ẢNH MẪU AI
    const triggerImageUpload = () => {
      const mainInput = document.getElementById('image-upload');
      if (mainInput) mainInput.click();
    };
    document.getElementById('dock-vision-dropzone')?.addEventListener('click', triggerImageUpload);
    document.getElementById('dock-btn-choose-image')?.addEventListener('click', (e) => {
      e.stopPropagation();
      triggerImageUpload();
    });

    // G. TAB 3D MINI CONTROLS
    document.getElementById('dock-btn-reset-3d-cam')?.addEventListener('click', () => {
      let resetDone = false;
      if (this.miniInspector && this.miniInspector.fitCameraToObject && this.miniInspector.modelGroup) {
        this.miniInspector.fitCameraToObject(this.miniInspector.modelGroup);
        resetDone = true;
      }
      if (this.dockMiniInspector && this.dockMiniInspector.fitCameraToObject && this.dockMiniInspector.modelGroup) {
        this.dockMiniInspector.fitCameraToObject(this.dockMiniInspector.modelGroup);
        resetDone = true;
      }
      if (resetDone) this.showMiniToast('Đã đặt lại góc nhìn 3D!', 'info');
    });
    document.getElementById('dock-btn-toggle-3d-wire')?.addEventListener('click', () => {
      const toggleGrp = (grp) => {
        if (!grp) return;
        grp.traverse(child => {
          if (child.isMesh && child.material) {
            child.material.wireframe = !child.material.wireframe;
          }
        });
      };
      if (this.miniInspector && this.miniInspector.modelGroup) toggleGrp(this.miniInspector.modelGroup);
      if (this.dockMiniInspector && this.dockMiniInspector.modelGroup) toggleGrp(this.dockMiniInspector.modelGroup);
    });

    // H. CỤM PHÍM TÁC VỤ GHIM ĐÁY MÀN HÌNH CHÍNH WORKSPACE
    // 1. NÚT CHÍNH TO NHẤT: XÂY 3D VÀO SKETCHUP
    document.getElementById('dock-btn-build-3d')?.addEventListener('click', () => {
      this.sendToSketchUp('create_3d_model', this.currentModel);
    });

    // 2. Nút Tạo Dynamic Component (Biến đối tượng đang chọn hoặc sinh mới thành DC)
    document.getElementById('dock-btn-generate-dc')?.addEventListener('click', () => {
      const selectedId = this.currentSelectionData ? this.currentSelectionData.entity_id : null;
      const targetName = this.currentSelectionData ? this.currentSelectionData.name : (this.currentModel.name || 'Chill_Dynamic_Furniture');
      const dcParams = {
        entity_id: selectedId,
        name: targetName,
        type: (targetName.toLowerCase().includes('tủ') || targetName.toLowerCase().includes('tu') || targetName.toLowerCase().includes('cabinet') || targetName.toLowerCase().includes('wardrobe')) ? 'wardrobe' : 'desk',
        length: this.currentSelectionData ? parseFloat(this.currentSelectionData.length) : (this.currentModel.length || 1600),
        width: this.currentSelectionData ? parseFloat(this.currentSelectionData.width) : (this.currentModel.width || 600),
        height: this.currentSelectionData ? parseFloat(this.currentSelectionData.height) : (this.currentModel.height || 1800),
        thickness: this.currentModel.thickness || 17.5,
        material: this.currentModel.material || 'white_melamine',
        doors: parseInt(document.getElementById('dock-input-doors')?.value || 3),
        drawers: parseInt(document.getElementById('dock-input-drawers')?.value || 2),
        leg_style: document.getElementById('dock-select-leg-style')?.value || 'metal_frame'
      };
      this.sendToSketchUp('create_dynamic_component', dcParams);
      if (this.avatar) {
        this.avatar.speak(`Lan đang chuyển đổi ${targetName} thành Dynamic Component có đầy đủ thông số và cánh mở tương tác cho anh Huy nhé!`);
        this.avatar.addMessage('bot', `🪄 <strong>ĐÃ TẠO DYNAMIC COMPONENT THÀNH CÔNG!</strong><br>Đối tượng <strong>${targetName}</strong> đã được nạp đầy đủ thông số co giãn, cảnh báo khổ ván 2440mm và hàm mở cánh tương tác.<br>Anh Huy hãy mở cửa sổ <strong>Component Options</strong> trong SketchUp để xem và chỉnh sửa thông số nhé! 🚪✨`);
      }
      this.showMiniToast(`Đang chuyển đổi ${targetName} thành Dynamic Component...`, 'info');
    });

    // 3. Nút Đồng Bộ SketchUp
    document.getElementById('dock-btn-refresh-selection')?.addEventListener('click', () => {
      if (window.sketchup && window.sketchup.get_current_selection) {
        window.sketchup.get_current_selection();
        this.showMiniToast('Đang đồng bộ từ SketchUp...', 'info');
      }
    });

    // 4. Header: VIP Modal & API Modal
    document.getElementById('dock-btn-open-account')?.addEventListener('click', () => {
      const modal = document.getElementById('modal-account');
      if (modal) modal.style.display = 'flex';
    });
    document.getElementById('dock-btn-open-api')?.addEventListener('click', () => {
      const modal = document.getElementById('modal-api-key');
      if (modal) modal.style.display = 'flex';
    });

    // 5. Nút CNC Bóc tách & Lưu G-Code
    document.getElementById('dock-btn-switch-to-cam')?.addEventListener('click', () => {
      this.generateNestingData();
      this.showMiniToast('Đã tính toán sơ đồ Nesting tối ưu ván!', 'success');
    });
  }

    showMiniToast(message, type = 'success', duration = 2800) {
    let container = document.getElementById('dock-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'dock-toast-container';
      container.className = 'dock-toast-container';
      document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `dock-mini-toast ${type}`;
    const icon = type === 'success' ? '🪵' : (type === 'info' ? '⚡' : '⚠️');

    toast.innerHTML = `
      <span class="dock-toast-icon">${icon}</span>
      <span class="dock-toast-msg">${message}</span>
      <button class="dock-toast-close" title="Đóng">✕</button>
    `;

    const closeBtn = toast.querySelector('.dock-toast-close');
    const removeToast = () => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(-6px) scale(0.95)';
      setTimeout(() => {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
      }, 250);
    };

    if (closeBtn) closeBtn.addEventListener('click', removeToast);
    container.appendChild(toast);

    if (duration > 0) {
      setTimeout(removeToast, duration);
    }
  }

  startSelectionPolling() {
    if (this._pollingTimer) clearInterval(this._pollingTimer);
    this._pollingTimer = setInterval(() => {
      // Khi đang soi chi tiết trong 3D Plugin (tay nắm, ván...), tạm ngưng polling để tránh đè dữ liệu
      if (this.selectionSource === 'plugin_3d') {
        return;
      }
      if (window.sketchup && window.sketchup.get_current_selection) {
        window.sketchup.get_current_selection();
      }
    }, 1000);
  }

  // ==============================================================================
  // CHILL SHOPEE - HÀNG HÓA & TÌM NHÀ CUNG CẤP GẦN BẠN THEO BÁN KÍNH
  // ==============================================================================
  initShopeeMarketplace() {
    const slider = document.getElementById('shopee-radius-slider');
    const display = document.getElementById('shopee-radius-display');
    const citySelect = document.getElementById('shopee-select-city');
    const btnSwitch = document.getElementById('btn-switch-to-shopee');

    slider?.addEventListener('input', (e) => {
      const val = e.target.value;
      if (display) display.textContent = val;
      this.renderShopeeSuppliers();
    });

    citySelect?.addEventListener('change', () => {
      this.renderShopeeSuppliers();
    });

    btnSwitch?.addEventListener('click', () => {
      this.switchDockTab('dock-pane-shopee');
    });

    // Các nút bấm nhanh tại mặt tiền Khay Đứng (Nút footer & Chip ô xanh dương)
    document.getElementById('chip-quick-export-dxf')?.addEventListener('click', () => {
      this.saveDxfFile();
    });
    document.getElementById('dock-btn-footer-dxf')?.addEventListener('click', () => {
      this.saveDxfFile();
    });
    document.getElementById('chip-quick-nest-su')?.addEventListener('click', () => {
      this.nestToSketchUpDirectly();
    });
    document.getElementById('chip-quick-shopee')?.addEventListener('click', () => {
      this.switchDockTab('dock-pane-shopee');
    });
    document.getElementById('dock-btn-footer-nest')?.addEventListener('click', () => {
      this.nestToSketchUpDirectly();
    });
    document.getElementById('dock-btn-footer-shopee')?.addEventListener('click', () => {
      this.switchDockTab('dock-pane-shopee');
    });

    // Các nút bấm tại Toàn Cảnh Studio
    document.getElementById('btn-cmd-nest-to-su')?.addEventListener('click', () => {
      this.nestToSketchUpDirectly();
    });
    document.getElementById('btn-cmd-shopee')?.addEventListener('click', () => {
      this.switchTab('tab-shopee');
    });

    // Studio Shopee Radius Slider & City Select
    const studioSlider = document.getElementById('studio-shopee-radius-slider');
    const studioDisplay = document.getElementById('studio-shopee-radius-display');
    const studioCity = document.getElementById('studio-shopee-select-city');
    studioSlider?.addEventListener('input', (e) => {
      if (studioDisplay) studioDisplay.textContent = e.target.value;
      this.renderStudioShopeeSuppliers();
    });
    studioCity?.addEventListener('change', () => {
      this.renderStudioShopeeSuppliers();
    });

    // Nạp dữ liệu ban đầu
    this.updateShopeeData(null);
  }

  updateShopeeData(goodsInfo) {
    if (!goodsInfo) {
      // Mặc định nạp dữ liệu tay nắm tủ cao cấp (HDL-ALU-TITAN)
      goodsInfo = {
        sku: "HDL-ALU-TITAN-128",
        badge: "Shopee Mall",
        rating: 4.96,
        sold_count: "18.5k đã bán",
        title: "[Chính Hãng Chill Decor / Hafele] Tay Nắm Hợp Kim Nhôm Đúc Nguyên Khối Anode Cao Cấp Cho Tủ Áo & Ngăn Kéo",
        brand: "Chill Hardware & Hafele Standard",
        style: "Hiện Đại Tối Giản (Modern Minimalist / Bắc Âu Luxury)",
        origin: "OEM Chuẩn Xuất Khẩu Châu Âu",
        color_options: ["Đen Nhám Anode", "Vàng Xước Titan", "Bạc Chrome Sáng", "Xám Gunmetal"],
        size_options: ["Tim 96mm (Dài 115)", "Tim 128mm (Dài 150)", "Tim 160mm (Dài 185)", "Tim 192mm (Dài 220)"],
        price_current: "32.000 đ",
        price_original: "45.000 đ",
        discount: "-29%",
        unit: "/ Cái (Kèm 02 ốc vít M4)",
        warranty: "Bảo hành 24 tháng chính hãng chống bay màu & gỉ sét mồ hôi tay",
        return_policy: "1 đổi 1 trong 30 ngày nếu lỗi ren ốc hoặc trầy xước từ nhà sản xuất",
        durability_score: "⭐ 9.9 / 10 điểm",
        user_review: "Chất nhôm đúc đầm tay chắc nịch, lớp mạ đen nhám mịn màng không bám vân tay. Bắt vào cánh tủ áo nhìn sang hơn hẳn tay nắm thông thường ngoài chợ!",
        shop_description: "• Chất liệu: Hợp kim nhôm đặc đúc áp lực cao, không rỗng ruột.\n• Công nghệ mạ: Xử lý điện hóa Anode hóa cứng chịu ma sát mồ hôi tay.\n• Phụ kiện: Tặng kèm 02 ốc vít M4x22 tiêu chuẩn cho ván 17.5mm.",
        specs: "Dài 128mm • Cao 22mm • Bản rộng 12mm • Tim ốc chuẩn CNC",
        suppliers: [
          { name: "Tổng Kho Phụ Kiện Kim Khí Mộc Cầu Giấy", city: "Hà Nội", dist_km: 1.1, stock: "Sẵn kho 3.500 cái", phone: "0982.555.666", addr: "Nguyễn Phong Sắc, Cầu Giấy, Hà Nội" },
          { name: "Đại Lý Tay Nắm & Bản Lề Ivan Thạch Thất", city: "Hà Nội", dist_km: 2.3, stock: "Sẵn kho 6.000 cái", phone: "0971.222.333", addr: "Đường tỉnh 419, Thạch Thất, Hà Nội" },
          { name: "Kho Phụ Kiện Tủ Áo Hóc Môn TP.HCM", city: "TP. Hồ Chí Minh", dist_km: 1.5, stock: "Sẵn kho 5.200 cái", phone: "0902.333.444", addr: "Quang Trung, P.14, Gò Vấp / Q12, TP.HCM" },
          { name: "Tổng Đại Lý Phụ Kiện Mộc Thuận An Bình Dương", city: "Bình Dương", dist_km: 3.2, stock: "Sẵn kho 4.800 cái", phone: "0908.777.666", addr: "Đại Lộ Bình Dương, Thuận An, Bình Dương" }
        ]
      };
    }

    this.currentGoodsData = goodsInfo;
    this.currentGoodsSuppliers = goodsInfo.suppliers || [];

    const setEl = (id, val) => {
      const el = document.getElementById(id);
      if (el) el.textContent = val;
      const elStudio = document.getElementById('studio-' + id);
      if (elStudio) elStudio.textContent = val;
    };

    const setHtml = (id, val) => {
      const el = document.getElementById(id);
      if (el) el.innerHTML = val;
      const elStudio = document.getElementById('studio-' + id);
      if (elStudio) elStudio.innerHTML = val;
    };

    // 1. Tên sản phẩm, SKU, Đánh giá & Đã bán
    setEl('shopee-item-sku', `SKU: ${goodsInfo.sku || 'MAT-01'}`);
    setEl('shopee-item-rating', goodsInfo.rating || '4.96');
    setEl('shopee-item-sold', goodsInfo.sold_count || '1k+');
    setEl('shopee-item-title', goodsInfo.title || 'Vật tư nội thất');

    // 4. Giá cả & Khuyến mãi
    setEl('shopee-item-price-current', goodsInfo.price_current || '32.000 đ');
    setEl('shopee-item-price-original', goodsInfo.price_original || '45.000 đ');
    setEl('shopee-item-discount', goodsInfo.discount || '-10%');
    setEl('shopee-item-unit', goodsInfo.unit ? `${goodsInfo.unit}` : '/ Cái');

    // 2. Phân loại SKU (Mã màu & Kích thước)
    this.renderSkuChips('shopee-color-chips', goodsInfo.color_options || ["Đen Nhám Anode", "Vàng Xước Titan", "Bạc Chrome Sáng", "Xám Gunmetal"]);
    this.renderSkuChips('studio-shopee-color-chips', goodsInfo.color_options || ["Đen Nhám Anode", "Vàng Xước Titan", "Bạc Chrome Sáng", "Xám Gunmetal"]);
    this.renderSkuChips('shopee-size-chips', goodsInfo.size_options || ["Tim 96mm (Dài 115)", "Tim 128mm (Dài 150)", "Tim 160mm (Dài 185)", "Tim 192mm (Dài 220)"]);
    this.renderSkuChips('studio-shopee-size-chips', goodsInfo.size_options || ["Tim 96mm (Dài 115)", "Tim 128mm (Dài 150)", "Tim 160mm (Dài 185)", "Tim 192mm (Dài 220)"]);

    // 3. Phong cách & Xuất xứ
    setEl('shopee-item-style', goodsInfo.style || 'Hiện Đại Tối Giản');
    setEl('shopee-item-origin', goodsInfo.origin || 'OEM Chuẩn Xuất Khẩu Châu Âu');

    // 5. Chính sách bảo hành & Đổi trả
    setEl('shopee-item-warranty', goodsInfo.warranty || 'Bảo hành 24 tháng chính hãng');
    setEl('shopee-item-return', goodsInfo.return_policy || '1 đổi 1 trong 30 ngày nếu lỗi');

    // 6. Độ bền được người dùng đánh giá
    const durScore = goodsInfo.durability_score ? (goodsInfo.durability_score.includes('⭐') ? goodsInfo.durability_score : `⭐ ${goodsInfo.durability_score}`) : '⭐ 9.9 / 10 điểm';
    setEl('shopee-item-durability', durScore);
    const reviewTxt = goodsInfo.user_review ? (goodsInfo.user_review.startsWith('“') ? goodsInfo.user_review : `“${goodsInfo.user_review}”`) : '“Chất lượng đúc hoàn thiện tinh xảo, bắt vào cánh tủ rất sang!”';
    setEl('shopee-item-review', reviewTxt);

    // 7. Thông tin do chủ shop đăng & Quy cách kỹ thuật
    const formattedDesc = (goodsInfo.shop_description || '').replace(/\n/g, '<br>');
    setHtml('shopee-item-shop-desc', formattedDesc);
    setEl('shopee-item-specs', goodsInfo.specs || 'Quy cách kỹ thuật tiêu chuẩn');

    this.renderShopeeSuppliers();
  }

  renderSkuChips(containerId, options) {
    const container = document.getElementById(containerId);
    if (!container) return;
    if (!Array.isArray(options) || options.length === 0) {
      container.innerHTML = '<span style="font-size:9px; color:#64748b;">(Tiêu chuẩn)</span>';
      return;
    }
    container.innerHTML = options.map((opt, idx) => {
      const activeClass = idx === 0 ? 'active' : '';
      return `<span class="shopee-chip ${activeClass}" data-val="${opt}">${opt}</span>`;
    }).join('');

    // Attach click listener
    container.querySelectorAll('.shopee-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        container.querySelectorAll('.shopee-chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
      });
    });
  }

  renderShopeeSuppliers() {
    const listEl = document.getElementById('shopee-supplier-list');
    if (!listEl) return;

    const slider = document.getElementById('shopee-radius-slider');
    const citySelect = document.getElementById('shopee-select-city');
    const countEl = document.getElementById('shopee-count-num');

    const maxDist = parseFloat(slider?.value || 5);
    const selectedCity = citySelect?.value || 'Hà Nội';

    const allSuppliers = this.currentGoodsSuppliers || [];
    
    // Lọc theo thành phố và cự ly bán kính
    let filtered = allSuppliers.filter(s => {
      const matchCity = !s.city || s.city === selectedCity;
      const matchDist = (s.dist_km || 0) <= maxDist;
      return matchCity && matchDist;
    });

    filtered.sort((a, b) => (a.dist_km || 0) - (b.dist_km || 0));

    if (countEl) countEl.textContent = filtered.length;
    const studioCountEl = document.getElementById('studio-shopee-count-num');
    if (studioCountEl) studioCountEl.textContent = filtered.length;

    const studioListEl = document.getElementById('studio-shopee-supplier-list');

    if (filtered.length === 0) {
      const emptyHtml = `
        <div style="text-align:center; padding:18px 10px; color:#94a3b8; font-size:10px; background:rgba(15,23,42,0.5); border-radius:6px; border:1px dashed #334155;">
          <div style="font-size:22px; margin-bottom:4px;">🔍</div>
          <div>Không tìm thấy đại lý nào trong bán kính <strong>${maxDist} km</strong> tại <strong>${selectedCity}</strong>.</div>
          <div style="font-size:9.5px; color:#fbbf24; margin-top:5px;">💡 Gợi ý: Hãy kéo thanh trượt tăng bán kính lên 10km hoặc 20km nhé!</div>
        </div>
      `;
      listEl.innerHTML = emptyHtml;
      if (studioListEl) studioListEl.innerHTML = emptyHtml;
      return;
    }

    const cardsHtml = filtered.map(sup => {
      const d = sup.dist_km || 1.0;
      let badgeClass = 'near';
      let badgeText = `Gần: ${d} km`;
      if (d > 5) {
        badgeClass = 'far';
        badgeText = `${d} km`;
      } else if (d > 2.5) {
        badgeClass = 'mid';
        badgeText = `${d} km`;
      }

      const mapQuery = encodeURIComponent(`${sup.name} ${sup.addr}`);
      const mapUrl = `https://www.google.com/maps/search/?api=1&query=${mapQuery}`;

      return `
        <div class="shopee-supplier-card">
          <div class="sup-header-row">
            <span class="sup-name">🏪 ${sup.name}</span>
            <span class="sup-distance-badge ${badgeClass}">${badgeText}</span>
          </div>
          <div class="sup-addr">📍 ${sup.addr}</div>
          <div class="sup-stock-row">
            <span style="color:#34d399; font-weight:bold;">${sup.stock || '🟢 Sẵn hàng'}</span>
            <span style="color:#64748b;">Giao xưởng: 1-2h</span>
          </div>
          <div class="sup-actions-row">
            <a href="tel:${sup.phone}" class="btn-sup-phone" title="Gọi điện đặt hàng ngay">📞 Hotline: ${sup.phone}</a>
            <a href="${mapUrl}" target="_blank" class="btn-sup-map" title="Mở chỉ đường Google Maps">🗺️ Chỉ Đường Maps</a>
          </div>
        </div>
      `;
    }).join('');

    listEl.innerHTML = cardsHtml;
    if (studioListEl) studioListEl.innerHTML = cardsHtml;
  }

  initAccordionTray() {
    // Legacy support
  }

  // ==============================================================================
  // CỖ MÁY KẾT CẤU CHẶNG 3: BỘ GEN PRESET MỘC & ĐÓNG GÓP TRI THỨC CỘNG ĐỒNG
  // ==============================================================================
  initStructuralEngine() {
    const selectPreset = document.getElementById('dock-select-preset');
    const descEl = document.getElementById('dock-preset-desc-text');

    const inpBoard = document.getElementById('dock-cfg-board-thick');
    const inpBack = document.getElementById('dock-cfg-back-thick');
    const inpOffset = document.getElementById('dock-cfg-back-offset');
    const inpDoorGap = document.getElementById('dock-cfg-door-gap');
    const inpDrGap = document.getElementById('dock-cfg-drawer-gap');
    const inpToe = document.getElementById('dock-cfg-toe-h');

    const btnBuild = document.getElementById('dock-btn-build-structural');
    const btnSaveCustom = document.getElementById('dock-btn-save-custom-preset');
    const btnOpenContrib = document.getElementById('dock-btn-open-contribute');

    const modalContrib = document.getElementById('modal-contribute-knowledge');
    const btnCloseContrib = document.getElementById('btn-close-contribute');
    const btnSubmitContrib = document.getElementById('btn-submit-contribute');

    const presetConfigs = {
      an_cuong_17_5: {
        desc: 'Chuẩn mộc An Cường: Ván 17.5mm, Hậu 9mm soi rãnh lùi 18mm, Khe cánh 2mm, Ray bi 12.7mm.',
        board: 17.5, back: 9.0, offset: 18.0, doorGap: 2.0, drGap: 12.7, toe: 60.0
      },
      standard_18: {
        desc: 'Ván tiêu chuẩn 18mm: Hậu 9mm soi rãnh lùi 18mm, Khe cánh 2mm, Ray trượt 13mm.',
        board: 18.0, back: 9.0, offset: 18.0, doorGap: 2.0, drGap: 13.0, toe: 60.0
      },
      budget_mfc_15: {
        desc: 'Ván MFC tiết kiệm 15mm: Hậu 6mm soi rãnh lùi 15mm, Khe cánh 2mm, Len chân 50mm.',
        board: 15.0, back: 6.0, offset: 15.0, doorGap: 2.0, drGap: 12.5, toe: 50.0
      },
      custom_user: {
        desc: 'Cấu hình tùy biến theo thói quen thi công xưởng riêng của anh Huy.',
        board: 17.5, back: 9.0, offset: 18.0, doorGap: 2.0, drGap: 12.7, toe: 60.0
      }
    };

    if (selectPreset) {
      selectPreset.addEventListener('change', () => {
        const val = selectPreset.value;
        const cfg = presetConfigs[val] || presetConfigs.an_cuong_17_5;
        if (descEl) descEl.textContent = cfg.desc;
        if (inpBoard) inpBoard.value = cfg.board;
        if (inpBack) inpBack.value = cfg.back;
        if (inpOffset) inpOffset.value = cfg.offset;
        if (inpDoorGap) inpDoorGap.value = cfg.doorGap;
        if (inpDrGap) inpDrGap.value = cfg.drGap;
        if (inpToe) inpToe.value = cfg.toe;
      });
    }

    // Nút Dựng 3D Kỹ Thuật & Dynamic DC
    if (btnBuild) {
      btnBuild.addEventListener('click', () => {
        const payload = {
          preset_id: selectPreset ? selectPreset.value : 'an_cuong_17_5',
          length: parseFloat(document.getElementById('dock-input-length')?.value) || 1200,
          width: parseFloat(document.getElementById('dock-input-width')?.value) || 600,
          height: parseFloat(document.getElementById('dock-input-height')?.value) || 1800,
          doors: parseInt(document.getElementById('dock-input-doors')?.value, 10) || 3,
          drawers: parseInt(document.getElementById('dock-input-drawers')?.value, 10) || 2,
          material: document.getElementById('dock-select-wardrobe-mat')?.value || 'white_melamine',
          board_thickness: parseFloat(inpBoard?.value) || 17.5,
          back_thickness: parseFloat(inpBack?.value) || 9.0,
          back_groove_offset: parseFloat(inpOffset?.value) || 18.0,
          door_gap_center: parseFloat(inpDoorGap?.value) || 2.0,
          drawer_side_clearance: parseFloat(inpDrGap?.value) || 12.7,
          toe_kick_height: parseFloat(inpToe?.value) || 60.0
        };

        if (this.avatar && this.avatar.speak) {
          this.avatar.speak("Tin Tin đang dựng Tủ Áo Module Chuẩn Mộc CNC và cài đặt thuộc tính Dynamic Component cho anh Huy!");
        }

        if (window.sketchup && window.sketchup.build_structural_wardrobe) {
          window.sketchup.build_structural_wardrobe(JSON.stringify(payload));
        } else {
          this.showDockNotification("Đã nhận lệnh dựng Tủ Áo Chuẩn Mộc CNC (" + payload.length + "x" + payload.width + "x" + payload.height + "mm)!", "success");
        }
      });
    }

    // Nút Lưu Gu Xưởng
    if (btnSaveCustom) {
      btnSaveCustom.addEventListener('click', () => {
        const customCfg = {
          id: 'custom_user',
          name: '🛠️ Cấu Hình Riêng Xưởng Tôi',
          board_thickness: parseFloat(inpBoard?.value) || 17.5,
          back_thickness: parseFloat(inpBack?.value) || 9.0,
          back_groove_offset: parseFloat(inpOffset?.value) || 18.0,
          door_gap_center: parseFloat(inpDoorGap?.value) || 2.0,
          drawer_side_clearance: parseFloat(inpDrGap?.value) || 12.7,
          toe_kick_height: parseFloat(inpToe?.value) || 60.0
        };
        if (window.sketchup && window.sketchup.save_custom_preset) {
          window.sketchup.save_custom_preset(JSON.stringify(customCfg));
        }
        this.showDockNotification("Đã lưu thành công Cấu Hình Gu Xưởng của Tôi!", "success");
      });
    }

    // Modal Góp Ý Tri Thức Mộc
    if (btnOpenContrib && modalContrib) {
      btnOpenContrib.addEventListener('click', () => {
        modalContrib.style.display = 'flex';
      });
    }
    if (btnCloseContrib && modalContrib) {
      btnCloseContrib.addEventListener('click', () => {
        modalContrib.style.display = 'none';
      });
    }
    if (btnSubmitContrib && modalContrib) {
      btnSubmitContrib.addEventListener('click', () => {
        const title = document.getElementById('contrib-title')?.value || '';
        const cat = document.getElementById('contrib-category')?.value || '';
        const content = document.getElementById('contrib-content')?.value || '';
        const author = document.getElementById('contrib-author')?.value || 'Ẩn danh';

        if (!title.trim() || !content.trim()) {
          this.showMiniToast('Vui lòng nhập tên mẹo thi công và mô tả chi tiết!', 'warning', 3500);
          return;
        }

        const payload = { title, category: cat, content, author };
        if (window.sketchup && window.sketchup.contribute_knowledge) {
          window.sketchup.contribute_knowledge(JSON.stringify(payload));
        }

        modalContrib.style.display = 'none';
        this.showDockNotification("Cảm ơn anh! Mẹo thi công đã được gửi vào Kho Tri Thức Chill AI!", "success");
        if (this.avatar && this.avatar.speak) {
          this.avatar.speak("Tin Tin đã tiếp nhận mẹo thi công của anh! AI sẽ học hỏi để thi công ngày càng chuẩn xác hơn.");
        }
      });
    }
  }
}

// Instantiate on DOM Loaded
window.ChillAIApp = ChillAIApp;
document.addEventListener('DOMContentLoaded', () => {
  window.app = new ChillAIApp();
});
