// ==============================================================================
// Chill AI Interior - 3D Realtime Viewport Engine (Three.js)
// ==============================================================================

class Furniture3DViewer {
  constructor(containerId) {
    this.container = document.getElementById(containerId);
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.currentMeshGroup = null;
    this.isWireframe = false;
    this.spinRemaining = 0;

    // Mouse Orbit Controls State
    this.isMouseDown = false;
    this.prevMouseX = 0;
    this.prevMouseY = 0;
    this.spherical = { radius: 2400, theta: Math.PI / 4, phi: Math.PI / 3 };
    this.isPausedByDblClick = false;
    this.pauseTimer = null;

    this.init();
  }

  init() {
    if (!this.container || typeof THREE === 'undefined') {
      console.warn("Three.js chưa tải hoặc container không tìm thấy.");
      return;
    }

    const width = this.container.clientWidth || 380;
    const height = this.container.clientHeight || 280;

    // 1. Scene
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xccccc9); /* Màu xám SketchUp chuẩn xác */

    // 2. Camera
    this.camera = new THREE.PerspectiveCamera(45, width / height, 10, 15000);
    this.updateCameraPosition();

    // 3. Renderer
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.renderer.setSize(width, height);
    this.renderer.setPixelRatio(window.devicePixelRatio || 1);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.container.appendChild(this.renderer.domElement);

    // 4. Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.75);
    this.scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xfff5e6, 0.95);
    dirLight.position.set(1200, 2500, 1500);
    dirLight.castShadow = true;
    dirLight.shadow.mapSize.width = 1024;
    dirLight.shadow.mapSize.height = 1024;
    this.scene.add(dirLight);

    const fillLight = new THREE.DirectionalLight(0xe0f2fe, 0.35);
    fillLight.position.set(-1500, 1000, -1000);
    this.scene.add(fillLight);

    // 5. Grid Helper Floor & Soft Contact Shadow
    const grid = new THREE.GridHelper(3000, 30, 0x82827e, 0xbebeb9);
    grid.position.y = 0;
    this.scene.add(grid);

    const shadowPlaneGeo = new THREE.PlaneGeometry(3000, 3000);
    const shadowPlaneMat = new THREE.ShadowMaterial({ opacity: 0.12 });
    const shadowPlane = new THREE.Mesh(shadowPlaneGeo, shadowPlaneMat);
    shadowPlane.rotation.x = -Math.PI / 2;
    shadowPlane.position.y = -0.1;
    shadowPlane.receiveShadow = true;
    this.scene.add(shadowPlane);

    // 6. Setup Mouse Events for Smooth Orbit
    this.setupEvents();

    // 7. Initial Model (Desk Default)
    this.updateModel({
      type: 'desk',
      length: 1200,
      width: 600,
      height: 750,
      thickness: 18,
      material: 'oak',
      leg_style: 'metal_frame',
      drawers: 2
    });

    // 8. Animation Loop
    this.animate();
  }

  setupEvents() {
    const el = this.container;

    el.addEventListener('mousedown', (e) => {
      this.isMouseDown = true;
      this.prevMouseX = e.clientX;
      this.prevMouseY = e.clientY;
      this.clickStartX = e.clientX;
      this.clickStartY = e.clientY;
    });

    let lastClickTime = 0;
    el.addEventListener('mouseup', (e) => {
      this.isMouseDown = false;
      const dist = Math.hypot(e.clientX - (this.clickStartX || 0), e.clientY - (this.clickStartY || 0));
      if (dist < 8) {
        const now = Date.now();
        if (now - lastClickTime < 380) {
          // Kích chọn chuột trái 2 lần liên tiếp (<380ms)
          lastClickTime = 0;
          this.handleDoubleClickPause();
        } else {
          lastClickTime = now;
          this.handleClickRaycast(e);
        }
      }
    });

    el.addEventListener('dblclick', (e) => {
      e.preventDefault();
      this.handleDoubleClickPause();
    });

    window.addEventListener('mouseup', () => {
      this.isMouseDown = false;
    });

    el.addEventListener('mousemove', (e) => {
      if (!this.isMouseDown) return;
      const dx = e.clientX - this.prevMouseX;
      const dy = e.clientY - this.prevMouseY;

      this.spherical.theta -= dx * 0.008;
      // Cho phép xoay trục thẳng đứng tự do bằng chuột trái: từ đỉnh (top-down) đến đáy (bottom-up gầm bàn)
      this.spherical.phi = Math.max(0.02, Math.min(Math.PI - 0.02, this.spherical.phi - dy * 0.008));

      this.updateCameraPosition();
      this.prevMouseX = e.clientX;
      this.prevMouseY = e.clientY;
    });

    el.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.spherical.radius = Math.max(800, Math.min(6000, this.spherical.radius + e.deltaY * 2));
      this.updateCameraPosition();
    }, { passive: false });

    window.addEventListener('resize', () => {
      if (!this.container || !this.renderer) return;
      const w = this.container.clientWidth;
      const h = this.container.clientHeight;
      this.camera.aspect = w / h;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(w, h);
    });
  }

  updateCameraPosition() {
    const { radius, theta, phi } = this.spherical;
    const target = this.targetCenter || new THREE.Vector3(0, 375, 0);
    this.camera.position.x = target.x + radius * Math.sin(phi) * Math.sin(theta);
    this.camera.position.y = target.y + radius * Math.cos(phi);
    this.camera.position.z = target.z + radius * Math.sin(phi) * Math.cos(theta);
    this.camera.lookAt(target.x, target.y, target.z);
  }

  resetCamera() {
    this.spherical = { radius: 2400, theta: Math.PI / 4, phi: Math.PI / 3 };
    this.centerModelToViewport();
    this.spinShowcase(3);
  }

  centerModelToViewport() {
    if (!this.currentMeshGroup) return;
    const box = new THREE.Box3().setFromObject(this.currentMeshGroup);
    if (box.isEmpty()) return;

    this.targetCenter = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z, 600);

    // Bán kính camera bao quát trọng tâm chuẩn xác
    this.spherical.radius = Math.max(1600, maxDim * 2.1);
    this.updateCameraPosition();
  }

  toggleWireframe() {
    this.isWireframe = !this.isWireframe;
    if (this.currentMeshGroup) {
      this.currentMeshGroup.traverse((child) => {
        if (child.isMesh && child.material) {
          child.material.wireframe = this.isWireframe;
        }
      });
    }
  }

  animate() {
    requestAnimationFrame(() => this.animate());

    // Môi trường 3D cứ xoay bình thường, trừ khi đang giữ chuột kéo hoặc đang tạm dừng 30s sau cú click đúp
    if (this.currentMeshGroup && !this.isMouseDown && !this.isPausedByDblClick) {
      if (this.spinRemaining > 0) {
        const step = 0.022; // Vòng quay tăng tốc showcase
        this.currentMeshGroup.rotation.y += step;
        this.spinRemaining -= step;
      } else {
        this.currentMeshGroup.rotation.y += 0.005; // Tốc độ xoay tự động êm ái, thanh lịch chuẩn showroom
      }
    }

    if (this.renderer && this.scene && this.camera) {
      this.renderer.render(this.scene, this.camera);
    }
  }

  handleDoubleClickPause() {
    this.isPausedByDblClick = true;
    if (this.pauseTimer) clearTimeout(this.pauseTimer);

    console.log("[Chill AI 3D] Đã kích chọn chuột trái 2 lần: Ngưng xoay 3D. Đợi 30s sau mới xoay tiếp.");
    if (window.chillApp && typeof window.chillApp.showMiniToast === 'function') {
      window.chillApp.showMiniToast("⏸️ Đã ngưng xoay 3D (Đợi 30s sau mới xoay tiếp)", "info");
    }

    // Đồng bộ tạm dừng 30s cho cả Mini Inspector
    if (window.chillApp && window.chillApp.miniInspector && typeof window.chillApp.miniInspector.handleDoubleClickPause === 'function') {
      window.chillApp.miniInspector.handleDoubleClickPause(false);
    }

    // Đợi đúng 30 giây (30,000 ms) sau mới xoay tiếp
    this.pauseTimer = setTimeout(() => {
      this.isPausedByDblClick = false;
      console.log("[Chill AI 3D] Đã hết 30s: Tiếp tục xoay 3D bình thường.");
      if (window.chillApp && typeof window.chillApp.showMiniToast === 'function') {
        window.chillApp.showMiniToast("▶️ Tiếp tục xoay 3D bình thường", "info");
      }
    }, 30000);
  }

  spinShowcase(rotations = 3) {
    this.spinRemaining = Math.PI * 2 * rotations;
  }

  // --- MODEL GENERATION FOR 3D VIEWPORT ---
  updateModel(params) {
    if (!this.scene) return;

    if (this.currentMeshGroup) {
      this.scene.remove(this.currentMeshGroup);
    }

    this.currentMeshGroup = new THREE.Group();
    const type = (params.type || 'desk').toLowerCase();
    const l = parseFloat(params.length) || 1200;
    const w = parseFloat(params.width) || 600;
    const h = parseFloat(params.height) || 750;
    const t = parseFloat(params.thickness) || 18;
    const woodMat = this.getMaterial(params.material || 'oak');
    const metalMat = this.getMaterial('metal_black');

    switch (type) {
      case 'desk':
      case 'table':
        this.buildDeskMesh(l, w, h, t, params.leg_style, params.drawers, woodMat, metalMat);
        break;
      case 'cabinet':
      case 'wardrobe':
        this.buildCabinetMesh(l, w, h, t, params.doors || 3, params.drawers || 0, woodMat, params.door_material);
        break;
      case 'kitchen_cabinet':
        this.buildKitchenMesh(l, w, h, t, params, woodMat);
        break;
      case 'shelf':
      case 'bookshelf':
        this.buildShelfMesh(l, w, h, t, params.shelves || 3, woodMat);
        break;
      case 'bed':
        this.buildBedMesh(l, w, h, t, woodMat);
        break;
      default:
        this.buildDeskMesh(l, w, h, t, 'metal_frame', 2, woodMat, metalMat);
    }

    this.scene.add(this.currentMeshGroup);

    // Tự động căn chỉnh mô hình vào đúng giữa trọng tâm (Center to Viewport)
    this.centerModelToViewport();
    this.spinShowcase(3);
  }

  // Helper box creator centered

  handleClickRaycast(e) {
    if (!this.container || !this.camera || !this.currentMeshGroup) return;
    const rect = this.container.getBoundingClientRect();
    const mouse = new THREE.Vector2(
      ((e.clientX - rect.left) / rect.width) * 2 - 1,
      -((e.clientY - rect.top) / rect.height) * 2 + 1
    );

    if (!this.raycaster) this.raycaster = new THREE.Raycaster();
    this.raycaster.setFromCamera(mouse, this.camera);

    const intersects = this.raycaster.intersectObjects(this.currentMeshGroup.children, true);
    if (intersects.length > 0) {
      const hitMesh = intersects[0].object;
      this.highlightMesh(hitMesh);
      if (hitMesh.userData && window.chillApp) {
        if (typeof window.chillApp.selectObject === 'function') {
          window.chillApp.selectObject(hitMesh.userData, hitMesh, null, 'plugin_3d');
        } else {
          window.chillApp.on3DObjectSelected(hitMesh.userData, hitMesh);
        }
      }
    } else {
      // Click vào khoảng trống nền 3D -> Hủy vùng chọn và quay lại Trợ lý AI
      this.highlightMesh(null);
      if (window.chillApp && typeof window.chillApp.clearSelection === 'function') {
        window.chillApp.clearSelection();
      }
    }
  }

  highlightMesh(mesh) {
    if (this.selectedHighlightBox) {
      this.scene.remove(this.selectedHighlightBox);
      this.selectedHighlightBox = null;
    }
    if (!mesh) return;

    const box = new THREE.BoxHelper(mesh, 0xfbbf24);
    box.material.linewidth = 2;
    this.selectedHighlightBox = box;
    this.scene.add(box);
  }

  addBox(dx, dy, dz, posX, posY, posZ, mat, userData) {
    const geo = new THREE.BoxGeometry(dx, dy, dz);
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.set(posX, posY, posZ);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.material.wireframe = this.isWireframe;
    mesh.userData = userData || {
      entity_id: 10495,
      tier: 3,
      tier_label: "Tầng 3: Miếng Ván Nhỏ (Part)",
      name: "Tấm Ván Tiêu Chuẩn",
      category: "Chi Tiết Ván Thùng",
      icon_type: "panel",
      dim_x: Math.round(dx), dim_y: Math.round(dy), dim_z: Math.round(dz),
      length: Math.max(Math.round(dx), Math.round(dy), Math.round(dz)),
      width: Math.round(dy),
      thickness: Math.min(Math.round(dx), Math.round(dy), Math.round(dz)),
      material: "MDF Lõi Xanh Chống Ẩm",
      area_m2: ((dx * dy) / 1000000).toFixed(3),
      volume_m3: ((dx * dy * dz) / 1000000000).toFixed(4),
      edge_perimeter_m: (((dx + dy) * 2) / 1000).toFixed(2),
      breadcrumb: ["🏰 Khối Tổng Dự Án", "📦 Khối Module Lẻ", "🪵 Tấm Ván Tiêu Chuẩn"],
      hardware_list: [{ name: "Chỉ nẹp PVC dán cạnh viền 1mm", qty: "2.8m" }],
      status_cnc: "✅ Đã kiểm tra Bounding Box, sẵn sàng cắt CNC"
    };
    this.currentMeshGroup.add(mesh);
    return mesh;
  }

  buildDeskMesh(l, w, h, t, legStyle, drawers, woodMat, metalMat) {
    // 1. Mặt bàn
    const topUserData = {
      entity_id: 10491,
      tier: 2,
      tier_label: "Tầng 2: Khối Lẻ (Mặt Bàn Gỗ Sồi)",
      name: "Mặt Bàn Gỗ Tự Nhiên Sồi Nga",
      category: "Chi Tiết Mặt Bàn",
      icon_type: "panel",
      dim_x: Math.round(l), dim_y: Math.round(w), dim_z: Math.round(t),
      length: Math.round(l), width: Math.round(w), thickness: Math.round(t),
      material: "Gỗ Sồi Tự Nhiên (Oak Wood)",
      area_m2: ((l * w) / 1000000).toFixed(3),
      volume_m3: ((l * w * t) / 1000000000).toFixed(4),
      edge_perimeter_m: (((l + w) * 2) / 1000).toFixed(2),
      breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Mặt Bàn Gỗ Sồi", "🪵 Tấm Mặt Bàn"],
      hardware_list: [{ name: "Pát sắt liên kết chữ Z", qty: "8 bộ" }, { name: "Vít bắt mặt bàn 4x25", qty: "16 con" }],
      status_cnc: "✅ Đã bo cạnh R3, xử lý vát 45 độ chuẩn xác"
    };
    this.addBox(l, t, w, 0, h - t / 2, 0, woodMat, topUserData);

    // 2. Chân bàn
    const legThick = 40;
    if (legStyle === 'metal_frame') {
      const legUserData = {
        entity_id: 10492,
        tier: 2,
        tier_label: "Tầng 2: Khối Lẻ (Khung Chân Sắt U)",
        name: "Khung Chân Sắt Hộp 40x40 Sơn Tĩnh Điện",
        category: "Kết Cấu Chịu Lực",
        icon_type: "module",
        dim_x: 40, dim_y: Math.round(w), dim_z: Math.round(h - t),
        length: Math.round(w), width: 40, thickness: 40,
        material: "Thép Hộp 40x40x1.4mm Sơn Tĩnh Điện",
        area_m2: "0.450", volume_m3: "0.0035", edge_perimeter_m: "3.20",
        breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Khung Chân Sắt Hộp", "⚙️ Chân U Đôi"],
        hardware_list: [{ name: "Nút cao su tăng chỉnh đế chân", qty: "4 cái" }, { name: "Bulong M6 lục giác chìm", qty: "8 con" }],
        status_cnc: "✅ Đã cắt laser ống thép & hàn mài nhẵn"
      };

      // 2 Khung chữ U sắt
      [-l / 2 + legThick / 2, l / 2 - legThick / 2].forEach(x => {
        // 2 Cột đứng
        this.addBox(legThick, h - t, legThick, x, (h - t) / 2, -w / 2 + legThick / 2, metalMat, legUserData);
        this.addBox(legThick, h - t, legThick, x, (h - t) / 2, w / 2 - legThick / 2, metalMat, legUserData);
        // Giằng chân đáy
        this.addBox(legThick, legThick, w, x, legThick / 2, 0, metalMat, legUserData);
        // Giằng trên
        this.addBox(legThick, legThick, w, x, h - t - legThick / 2, 0, metalMat, legUserData);
      });
      // Giằng ngang sau
      const stretchUserData = {
        entity_id: 10494,
        tier: 3,
        tier_label: "Tầng 3: Thanh Giằng Chịu Lực",
        name: "Thanh Giằng Ngang Hộp Thép",
        category: "Chi Tiết Giằng",
        icon_type: "hardware",
        dim_x: Math.round(l - legThick * 2), dim_y: 30, dim_z: 30,
        length: Math.round(l - legThick * 2), width: 30, thickness: 30,
        material: "Thép Hộp 30x30 Sơn Tĩnh Điện",
        area_m2: "0.150", volume_m3: "0.0010", edge_perimeter_m: "2.40",
        breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Khung Chân Sắt Hộp", "🪵 Thanh Giằng Ngang"],
        hardware_list: [{ name: "Ốc tán ren M6", qty: "4 con" }],
        status_cnc: "✅ Chuẩn kích thước đột lỗ liên kết"
      };
      this.addBox(l - legThick * 2, 30, 30, 0, h - t - 30, -w / 2 + 50, metalMat, stretchUserData);
    } else {
      // 4 Chân gỗ
      const xOff = l / 2 - legThick / 2 - 10;
      const zOff = w / 2 - legThick / 2 - 10;
      const legWoodUserData = {
        entity_id: 10492,
        tier: 2,
        tier_label: "Tầng 2: Khối Lẻ (Chân Bàn Gỗ Tự Nhiên)",
        name: "Chân Bàn Gỗ Vuông 40x40",
        category: "Kết Cấu Chịu Lực",
        icon_type: "module",
        dim_x: 40, dim_y: 40, dim_z: Math.round(h - t),
        length: Math.round(h - t), width: 40, thickness: 40,
        material: "Gỗ Tự Nhiên Tiện Vuông",
        area_m2: "0.180", volume_m3: "0.0012", edge_perimeter_m: "1.60",
        breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Cụm Chân Bàn Gỗ", "🪵 Trụ Chân Đứng"],
        hardware_list: [{ name: "Bát sắt góc đỡ chân", qty: "4 cái" }],
        status_cnc: "✅ Đã khoan lỗ chốt âm mộng gỗ"
      };
      [-xOff, xOff].forEach(x => {
        [-zOff, zOff].forEach(z => {
          this.addBox(legThick, h - t, legThick, x, (h - t) / 2, z, woodMat, legWoodUserData);
        });
      });
      // Yếm bàn
      const yemUserData = {
        entity_id: 10495,
        tier: 3,
        tier_label: "Tầng 3: Tấm Yếm Bàn Khóa Cứng",
        name: "Tấm Ván Yếm Bàn Khóa Khung",
        category: "Tấm Ván Chi Tiết",
        icon_type: "panel",
        dim_x: Math.round(l - 40), dim_y: 70, dim_z: Math.round(t),
        length: Math.round(l - 40), width: 70, thickness: Math.round(t),
        material: "MDF Lõi Xanh Phủ Melamine",
        area_m2: "0.090", volume_m3: "0.0015", edge_perimeter_m: "2.50",
        breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Cụm Yếm Bàn", "🪵 Thanh Yếm Khóa Khung"],
        hardware_list: [{ name: "Chốt gỗ liên kết phi 8x30", qty: "8 cái" }],
        status_cnc: "✅ Đã dán cạnh 4 mặt"
      };
      this.addBox(l - 40, 70, t, 0, h - t - 35, zOff, woodMat, yemUserData);
      this.addBox(l - 40, 70, t, 0, h - t - 35, -zOff, woodMat, yemUserData);
      this.addBox(t, 70, w - 40, xOff, h - t - 35, 0, woodMat, yemUserData);
      this.addBox(t, 70, w - 40, -xOff, h - t - 35, 0, woodMat, yemUserData);
    }

    // 3. Hộc tủ ngăn kéo nếu có
    if (drawers > 0) {
      const drW = 360;
      const drH = Math.min(drawers * 150, h - t - 40);
      const drD = w - 40;
      const drX = l / 2 - drW / 2 - 20;
      const drY = h - t - drH / 2 - 10;

      const drUserData = {
        entity_id: 10493,
        tier: 2,
        tier_label: "Tầng 2: Khối Lẻ (Hộc Tủ Ngăn Kéo)",
        name: `Hộc Tủ Di Động ${drawers} Ngăn Kéo`,
        category: "Module Lưu Trữ",
        icon_type: "module",
        dim_x: drW, dim_y: Math.round(drD), dim_z: Math.round(drH),
        length: drW, width: Math.round(drD), thickness: 17.5,
        material: "MDF Lõi Xanh Phủ Melamine Chống Ẩm",
        area_m2: "1.250", volume_m3: "0.0450", edge_perimeter_m: "8.40",
        breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Hộc Tủ Ngăn Kéo", "🪵 Thùng Hộc & Ngăn Kéo"],
        hardware_list: [{ name: "Ray trượt bi 3 tầng giảm chấn 400mm", qty: `${drawers} bộ` }, { name: "Tay nắm kim loại chữ U", qty: `${drawers} cái` }],
        status_cnc: "✅ Đã dán cạnh 100%, khoan mồi liên kết chốt cam"
      };

      // Khối hộc
      this.addBox(drW, drH, drD, drX, drY, 0, woodMat, drUserData);

      // Mặt ngăn kéo trang trí
      const slotH = drH / drawers;
      for (let i = 0; i < drawers; i++) {
        const slotY = h - t - 10 - slotH * (i + 0.5);
        const frontUserData = {
          entity_id: 10496 + i,
          tier: 3,
          tier_label: "Tầng 3: Mặt Ngăn Kéo",
          name: `Mặt Ngăn Kéo Số ${i + 1}`,
          category: "Tấm Cánh / Mặt Kéo",
          icon_type: "panel",
          dim_x: drW - 8, dim_y: Math.round(slotH - 6), dim_z: 8,
          length: drW - 8, width: Math.round(slotH - 6), thickness: 17.5,
          material: "MDF Phủ Melamine Vân Gỗ Sồi",
          area_m2: "0.060", volume_m3: "0.0010", edge_perimeter_m: "1.10",
          breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Hộc Tủ Ngăn Kéo", `🪵 Mặt Ngăn Kéo ${i + 1}`],
          hardware_list: [{ name: "Nẹp chỉ viền PVC dày 1mm", qty: "1.2m" }],
          status_cnc: "✅ Cắt CNC chính xác dung sai 0.2mm"
        };
        this.addBox(drW - 8, slotH - 6, 8, drX, slotY, drD / 2 + 4, woodMat, frontUserData);

        // Tay nắm
        const handleUserData = {
          entity_id: 10500 + i,
          tier: 3,
          tier_label: "Tầng 3: Phụ Kiện Tay Nắm",
          name: "Tay Nắm Nhôm Chữ U Titan Đen",
          category: "Phụ Kiện Kim Khí",
          icon_type: "hardware",
          dim_x: 80, dim_y: 10, dim_z: 12,
          length: 80, width: 10, thickness: 12,
          material: "Hợp Kim Nhôm Đúc Anode Đen",
          area_m2: "0.005", volume_m3: "0.0001", edge_perimeter_m: "0.20",
          breadcrumb: ["🏰 Bàn Làm Việc Tổng Thể", "📦 Hộc Tủ Ngăn Kéo", "⚙️ Tay Nắm Nhôm"],
          hardware_list: [{ name: "Vít tay nắm M4x22", qty: "2 con" }],
          status_cnc: "✅ Phụ kiện sẵn kho lắp ráp"
        };
        this.addBox(80, 10, 12, drX, slotY, drD / 2 + 12, metalMat, handleUserData);
      }
    }
  }

  buildCabinetMesh(l, w, h, t, doors, drawers, woodMat, doorMaterial) {
    const whiteMat = this.getMaterial('white_melamine');
    const metalMat = this.getMaterial('metal_black');
    const doorMat = (doorMaterial === 'white_melamine') ? whiteMat : woodMat;

    // Hông trái & phải
    this.addBox(t, h, w, -l / 2 + t / 2, h / 2, 0, woodMat);
    this.addBox(t, h, w, l / 2 - t / 2, h / 2, 0, woodMat);

    // Đáy & nóc
    this.addBox(l - 2 * t, t, w, 0, 60 + t / 2, 0, woodMat);
    this.addBox(l - 2 * t, t, w, 0, h - t / 2, 0, woodMat);

    // Len chân tủ
    this.addBox(l - 2 * t, 60, t, 0, 30, w / 2 - 20, woodMat);

    // Tấm hậu tủ
    this.addBox(l - 2 * t, h - 60 - t, 6, 0, 60 + (h - 60 - t) / 2, -w / 2 + 3, whiteMat);

    const posZ = w / 2 + t / 2;

    const handleUserData = {
      entity_id: 10601,
      tier: 3,
      tier_label: "Tầng 3: Phụ Kiện Kim Khí (Tay Nắm)",
      name: "Tay Nắm Hợp Kim Nhôm Đúc",
      category: "Phụ Kiện Kim Khí",
      icon_type: "hardware",
      dim_x: 12, dim_y: 100, dim_z: 15,
      length: 100, width: 12, thickness: 15,
      material: "Hợp Kim Nhôm Đúc Anode Đen",
      hardware_list: [{ name: "Vít bắt tay nắm M4x25", qty: "2 con" }],
      status_cnc: "Phụ kiện hoàn thiện lắp ráp"
    };

    const doorUserData = {
      entity_id: 10610,
      tier: 2,
      tier_label: "Tầng 2: Hệ Cánh Cửa Tủ",
      name: "Cánh Tủ Áo Melamine",
      category: "Cánh Tủ",
      icon_type: "panel",
      material: "MDF Chống Ẩm Phủ Melamine",
      hardware_list: [{ name: "Bản lề bật giảm chấn Hafele", qty: "4 cái" }]
    };

    const drawerUserData = {
      entity_id: 10620,
      tier: 2,
      tier_label: "Tầng 2: Ngăn Kéo Tủ Áo",
      name: "Mặt Ngăn Kéo Tủ Áo",
      category: "Ngăn Kéo",
      icon_type: "panel",
      material: "MDF Chống Ẩm Phủ Melamine",
      hardware_list: [{ name: "Ray trượt bi 3 tầng giảm chấn", qty: "1 bộ" }]
    };

    // TRƯỜNG HỢP A: TỦ 3 CÁNH + 2 NGĂN KÉO (Khớp 100% ảnh thực tế)
    if (doors === 3 && drawers > 0) {
      const colW = (l - 4) / 3;
      const drTotalH = Math.min(drawers * 180, 420);
      const upperDoorH = h - 64 - drTotalH - 4;

      // Vách ngăn đứng bên trong chia khoang 2 cánh trái và khoang 1 cánh phải
      const dividerX = -l / 2 + 2 * colW;
      this.addBox(t, h - 60 - t, w - 20, dividerX, 60 + (h - 60 - t) / 2, 0, woodMat);

      // Đợt ngang chia trên nóc ngăn kéo khoang trái
      this.addBox(2 * colW - t, t, w - 20, -l / 2 + colW, 60 + drTotalH + t / 2, 0, woodMat);

      // 1 Cánh dài suốt bên phải
      const rightX = dividerX + colW / 2;
      this.addBox(colW - 2, h - 64, t, rightX, 60 + (h - 64) / 2, posZ, doorMat, doorUserData);
      // Tay nắm đứng cánh phải
      this.addBox(12, 100, 15, rightX - colW / 2 + 30, h * 0.5, posZ + 8, metalMat, handleUserData);

      // 2 Cánh ngắn bên trái
      const door1X = -l / 2 + colW * 0.5 + 2;
      const door2X = -l / 2 + colW * 1.5 + 2;
      const upperY = 60 + drTotalH + 4 + upperDoorH / 2;
      this.addBox(colW - 2, upperDoorH, t, door1X, upperY, posZ, doorMat, doorUserData);
      this.addBox(colW - 2, upperDoorH, t, door2X, upperY, posZ, doorMat, doorUserData);
      // Tay nắm đứng 2 cánh ngắn
      this.addBox(12, 100, 15, -l / 2 + colW - 30, upperY - 40, posZ + 8, metalMat, handleUserData);
      this.addBox(12, 100, 15, -l / 2 + colW + 30, upperY - 40, posZ + 8, metalMat, handleUserData);

      // Các ngăn kéo bên dưới (trải rộng qua 2 khoang trái)
      const singleDrH = (drTotalH - (drawers - 1) * 4) / drawers;
      const drW = 2 * colW - 2;
      const drX = -l / 2 + colW + 1;
      for (let j = 0; j < drawers; j++) {
        const drY = 60 + j * (singleDrH + 4) + singleDrH / 2;
        this.addBox(drW, singleDrH, t, drX, drY, posZ, doorMat, drawerUserData);
        // 2 Tay nắm ngang cho mỗi ngăn kéo
        this.addBox(80, 12, 15, -l / 2 + colW * 0.5, drY, posZ + 8, metalMat, handleUserData);
        this.addBox(80, 12, 15, -l / 2 + colW * 1.5, drY, posZ + 8, metalMat, handleUserData);
      }
    } else if (doors === 2 && drawers > 0) {
      // TRƯỜNG HỢP B: TỦ 2 CÁNH + NGĂN KÉO DƯỚI
      const doorW = (l - 4) / 2;
      const drTotalH = Math.min(drawers * 180, 420);
      const upperDoorH = h - 64 - drTotalH - 4;
      const upperY = 60 + drTotalH + 4 + upperDoorH / 2;

      for (let i = 0; i < 2; i++) {
        const dX = -l / 2 + doorW * (i + 0.5) + 2;
        this.addBox(doorW - 2, upperDoorH, t, dX, upperY, posZ, doorMat, doorUserData);
        const hX = (i === 0) ? dX + doorW / 2 - 30 : dX - doorW / 2 + 30;
        this.addBox(12, 100, 15, hX, upperY - 30, posZ + 8, metalMat, handleUserData);
      }

      const singleDrH = (drTotalH - (drawers - 1) * 4) / drawers;
      for (let j = 0; j < drawers; j++) {
        const drY = 60 + j * (singleDrH + 4) + singleDrH / 2;
        this.addBox(l - 4, singleDrH, t, 0, drY, posZ, doorMat, drawerUserData);
        this.addBox(90, 12, 15, 0, drY, posZ + 8, metalMat, handleUserData);
      }
    } else {
      // TRƯỜNG HỢP C: TỦ CÁNH MỞ TIÊU CHUẨN
      const doorW = (l - 4) / doors;
      const doorH = h - 64;
      for (let i = 0; i < doors; i++) {
        const doorX = -l / 2 + doorW * (i + 0.5) + 2;
        this.addBox(doorW - 2, doorH, t, doorX, 60 + doorH / 2, posZ, doorMat, doorUserData);
        const hX = (i % 2 === 0) ? doorX + doorW / 2 - 30 : doorX - doorW / 2 + 30;
        this.addBox(12, 100, 15, hX, h * 0.5, posZ + 8, metalMat, handleUserData);
      }
    }
  }

  buildKitchenMesh(l, w, h, t, params, woodMat) {
    const whiteMat = this.getMaterial('white_melamine');
    const shape = params.kitchen_shape || "I";
    const bsColor = params.backsplash_color || 'green_glass';
    
    let bsMat = new THREE.MeshStandardMaterial({ color: 0x4ade80, roughness: 0.1, metalness: 0.2, transparent: true, opacity: 0.8 });
    if (bsColor.includes('white')) bsMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.2 });
    if (bsColor.includes('black')) bsMat = new THREE.MeshStandardMaterial({ color: 0x222222, roughness: 0.2 });

    const lowerH = 810; 
    const lowerD = w;   
    const bsH = 650;    
    const upperH = Math.max(h - lowerH - bsH, 400); 
    const upperD = 350;

    const hasUpper = params.has_upper !== false;
    const hasLower = params.has_lower !== false;

    // Helper for a kitchen arm
    const buildArm = (armL, armD, dirX, dirZ, startX, startZ) => {
      const sizeX = dirX !== 0 ? armL : armD;
      const sizeZ = dirZ !== 0 ? armL : armD;
      
      const cx = startX + dirX * (armL / 2 - armD / 2);
      const cz = startZ + dirZ * (armL / 2 - armD / 2);

      if (hasLower) {
        const lowerData = {
          entity_id: 10491,
          tier: 2,
          tier_label: "Tầng 2: Khối Lẻ (Module Thành Phần)",
          name: "Module Tủ Dưới - Khoang Chậu & Bếp (W800)",
          category: "Khối Module Độc Lập - Thùng Dưới",
          icon_type: "module",
          dim_x: sizeX, dim_y: lowerH, dim_z: sizeZ,
          length: sizeX, width: sizeZ, thickness: 17.5,
          material: "MDF Lõi Xanh Phủ Melamine Chống Ẩm",
          area_m2: ((sizeX * lowerH * 2) / 1000000).toFixed(2),
          volume_m3: ((sizeX * lowerH * sizeZ) / 1000000000).toFixed(3),
          edge_perimeter_m: (((sizeX + lowerH) * 2) / 1000).toFixed(1),
          breadcrumb: ["🏰 Hệ Tủ Bếp Chữ L", "📦 Module Tủ Dưới (W800)"],
          hardware_list: [
            { name: "Bản lề Blum giảm chấn Clip Top", qty: "4 chiếc" },
            { name: "Tay nắm Hafele 160mm", qty: "2 chiếc" },
            { name: "Ốc cam phi 15", qty: "16 bộ" }
          ],
          status_cnc: "✅ Chuẩn liên kết chốt cam & đợt tăng cứng"
        };
        this.addBox(sizeX, lowerH, sizeZ, cx, lowerH / 2, cz, woodMat, lowerData);
      }
      
      if (hasLower && hasUpper) {
        let trueBsCx = cx;
        let trueBsCz = cz;
        if (dirX !== 0) trueBsCz -= (armD/2 - 5);
        if (dirZ !== 0) trueBsCx -= (armD/2 - 5);
        
        const bszX = dirX !== 0 ? armL : 10;
        const bszZ = dirZ !== 0 ? armL : 10;
        const bsData = {
          entity_id: 10493,
          tier: 3,
          tier_label: "Tầng 3: Chi Tiết Hoàn Thiện (Part / Panel)",
          name: "Kính Ốp Bếp Cường Lực Hải Long 8mm",
          category: "Kính Ốp Bếp Hoàn Thiện",
          icon_type: "panel",
          dim_x: bszX, dim_y: bsH, dim_z: bszZ,
          length: bszX, width: bsH, thickness: 8,
          material: "Kính Cường Lực Sơn Nhiệt 8mm",
          area_m2: ((bszX * bsH) / 1000000).toFixed(2),
          volume_m3: ((bszX * bsH * 8) / 1000000000).toFixed(4),
          edge_perimeter_m: (((bszX + bsH) * 2) / 1000).toFixed(1),
          breadcrumb: ["🏰 Hệ Tủ Bếp Chữ L", "📦 Cụm Khoang Bếp", "🪵 Kính Cường Lực 8mm"],
          hardware_list: [{ name: "Keo silicone Apollo A500 chuyên dụng", qty: "2 tuýp" }],
          status_cnc: "✅ Kính cường lực tôi nhiệt mài xiết 4 cạnh an toàn"
        };
        this.addBox(bszX, bsH, bszZ, trueBsCx, lowerH + bsH / 2, trueBsCz, bsMat, bsData);
      }
      
      if (hasUpper) {
        const upSizeX = dirX !== 0 ? armL : upperD;
        const upSizeZ = dirZ !== 0 ? armL : upperD;
        let upCx = cx;
        let upCz = cz;
        if (dirX !== 0) upCz -= (armD/2 - upperD/2);
        if (dirZ !== 0) upCx -= (armD/2 - upperD/2);
        const upperData = {
          entity_id: 10494,
          tier: 2,
          tier_label: "Tầng 2: Khối Lẻ (Module Thành Phần)",
          name: "Module Tủ Trên - Khoang Hút Mùi & Giá Bát (W800)",
          category: "Khối Module Độc Lập - Tủ Trên",
          icon_type: "module",
          dim_x: upSizeX, dim_y: upperH, dim_z: upSizeZ,
          length: upSizeX, width: upSizeZ, thickness: 17.5,
          material: "MDF Lõi Xanh Phủ Melamine Trắng Sứ",
          area_m2: ((upSizeX * upperH * 2) / 1000000).toFixed(2),
          volume_m3: ((upSizeX * upperH * upSizeZ) / 1000000000).toFixed(3),
          edge_perimeter_m: (((upSizeX + upperH) * 2) / 1000).toFixed(1),
          breadcrumb: ["🏰 Hệ Tủ Bếp Chữ L", "📦 Module Tủ Trên (W800)"],
          hardware_list: [
            { name: "Tay nâng Blum Aventos HF", qty: "1 bộ" },
            { name: "Giá bát nâng hạ inox 304", qty: "1 bộ" }
          ],
          status_cnc: "✅ Chuẩn treo tường ke góc chịu lực Z-Hanger"
        };
        this.addBox(upSizeX, upperH, upSizeZ, upCx, lowerH + bsH + upperH / 2, upCz, whiteMat, upperData);
      }
    };

    // Main I arm along X axis
    buildArm(l, lowerD, 1, 0, 0, 0);

    if (shape === "L") {
      const lArmLen = Math.min(l * 0.8, 1500);
      buildArm(lArmLen, lowerD, 0, 1, -l/2 + lowerD/2, lowerD/2);
    }
  }

  buildShelfMesh(l, w, h, t, shelves, woodMat) {
    // 2 vách đứng
    this.addBox(t, h, w, -l / 2 + t / 2, h / 2, 0, woodMat);
    this.addBox(t, h, w, l / 2 - t / 2, h / 2, 0, woodMat);
    // Đáy & nóc
    this.addBox(l - 2 * t, t, w, 0, t / 2, 0, woodMat);
    this.addBox(l - 2 * t, t, w, 0, h - t / 2, 0, woodMat);

    // Các đợt ngang
    const spacing = (h - 2 * t) / (shelves + 1);
    for (let i = 1; i <= shelves; i++) {
      this.addBox(l - 2 * t, t, w, 0, i * spacing, 0, woodMat);
    }
  }

  buildBedMesh(l, w, h, t, woodMat) {
    const headH = h * 2.2;
    // Đầu giường
    this.addBox(l, headH, t, 0, headH / 2, -w / 2 + t / 2, woodMat);
    // Đuôi giường
    this.addBox(l, h, t, 0, h / 2, w / 2 - t / 2, woodMat);
    // 2 Vai giường
    this.addBox(t, h, w - 2 * t, -l / 2 + t / 2, h / 2, 0, woodMat);
    this.addBox(t, h, w - 2 * t, l / 2 - t / 2, h / 2, 0, woodMat);
    // Đệm nằm
    const matMat = this.getMaterial('white_melamine');
    this.addBox(l - 2 * t - 10, 160, w - 2 * t - 10, 0, h - 20, 0, matMat);
  }

  getMaterial(type) {
    switch (type) {
      case 'walnut':
        return new THREE.MeshStandardMaterial({ color: 0x5c4033, roughness: 0.6, metalness: 0.1 });
      case 'white_melamine':
        return new THREE.MeshStandardMaterial({ color: 0xf1f5f9, roughness: 0.3, metalness: 0.05 });
      case 'metal_black':
        return new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.4, metalness: 0.8 });
      case 'oak':
      default:
        return new THREE.MeshStandardMaterial({ color: 0xd4a373, roughness: 0.7, metalness: 0.1 });
    }
  }
}

// Global instance exposed
window.Furniture3DViewer = Furniture3DViewer;


// ==============================================================================
// MINI 3D INSPECTOR (AOE UNIT PORTRAIT 3D ENGINE)
// Khung hiển thị mô hình 3D thực tế xoay 360 độ trong Avatar khi chọn đối tượng
// ==============================================================================
class Mini3DInspector {
  constructor(canvasId = 'obj-portrait-3d-canvas') {
    this.canvas = document.getElementById(canvasId);
    this.isSupported = !!(window.THREE && this.canvas);
    if (!this.isSupported) {
      console.warn("[Mini3DInspector] ThreeJS or Canvas not found, using SVG fallback.");
      return;
    }

    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.modelGroup = null;
    this.animationId = null;
    this.timerLoopId = null;
    this.isDragging = false;
    this.prevMouseX = 0;
    this.prevMouseY = 0;
    this.autoRotate = true;
    this.spinSpeed = 0.018; // Tốc độ xoay chậm êm ái, mượt mà chuẩn điện ảnh
    this.rotationsPerCycle = 3; // Xoay ít nhất 3 vòng 360 độ đầy đủ trước khi nghỉ một nhịp
    this.spinRemaining = Math.PI * 2 * this.rotationsPerCycle;
    this.isPausedCycle = false;
    this.pauseRemainingFrames = 0;
    this.lastRafTime = 0;
    this.isPausedByDblClick = false;
    this.pauseTimer = null;

    this.init();
  }

  init() {
    const width = 160;
    const height = 130;

    // Scene với nền trắng tinh khiết đồng bộ không gian mô phỏng 3D
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xccccc9); /* Màu xám SketchUp chuẩn xác */

    // Camera Perspective góc Isometric Studio
    this.camera = new THREE.PerspectiveCamera(40, width / height, 1, 3000);
    this.camera.position.set(130, 100, 150);
    this.camera.lookAt(0, 0, 0);

    // Renderer WebGL mượt mà trong suốt
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      alpha: true,
      antialias: true,
      powerPreference: "high-performance"
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.setSize(width, height, false);
    if (THREE.sRGBEncoding) this.renderer.outputEncoding = THREE.sRGBEncoding;

    // Hệ thống chiếu sáng Studio 3 điểm vàng kim sang trọng
    const ambientLight = new THREE.AmbientLight(0xffeedd, 0.95);
    this.scene.add(ambientLight);

    const keyLight = new THREE.DirectionalLight(0xfffaed, 1.2);
    keyLight.position.set(160, 220, 140);
    this.scene.add(keyLight);

    const rimLight = new THREE.DirectionalLight(0x60a5fa, 0.6);
    rimLight.position.set(-140, -60, -120);
    this.scene.add(rimLight);

    // Nhóm đối tượng hiển thị
    this.modelGroup = new THREE.Group();
    this.scene.add(this.modelGroup);

    // Sự kiện kéo xoay chuột tương tác
    this.setupInteraction();

    // Vòng lặp render kép: requestAnimationFrame + setInterval (Chống đơ khi cửa sổ SketchUp mất focus)
    this.animate();
    this.startTimerLoop();
  }

  setupInteraction() {
    if (!this.canvas) return;

    this.canvas.addEventListener('mousedown', (e) => {
      this.isDragging = true;
      this.prevMouseX = e.clientX;
      this.prevMouseY = e.clientY;
      this.autoRotate = false;
      e.stopPropagation();
    });

    window.addEventListener('mousemove', (e) => {
      if (!this.isDragging || !this.modelGroup) return;
      const dx = e.clientX - this.prevMouseX;
      const dy = e.clientY - this.prevMouseY;
      this.modelGroup.rotation.y += dx * 0.025;
      this.modelGroup.rotation.x += dy * 0.025;
      this.prevMouseX = e.clientX;
      this.prevMouseY = e.clientY;
      this.renderFrame();
    });

    window.addEventListener('mouseup', () => {
      if (this.isDragging) {
        this.isDragging = false;
        clearTimeout(this.resumeTimer);
        this.resumeTimer = setTimeout(() => {
          this.autoRotate = true;
        }, 1500);
      }
    });

    // Touch support cho màn hình cảm ứng
    this.canvas.addEventListener('touchstart', (e) => {
      if (e.touches.length === 1) {
        this.isDragging = true;
        this.prevMouseX = e.touches[0].clientX;
        this.prevMouseY = e.touches[0].clientY;
        this.autoRotate = false;
        e.stopPropagation();
      }
    }, { passive: true });

    window.addEventListener('touchmove', (e) => {
      if (!this.isDragging || !this.modelGroup || e.touches.length !== 1) return;
      const dx = e.touches[0].clientX - this.prevMouseX;
      const dy = e.touches[0].clientY - this.prevMouseY;
      this.modelGroup.rotation.y += dx * 0.025;
      this.modelGroup.rotation.x += dy * 0.025;
      this.prevMouseX = e.touches[0].clientX;
      this.prevMouseY = e.touches[0].clientY;
      this.renderFrame();
    }, { passive: true });

    window.addEventListener('touchend', () => {
      if (this.isDragging) {
        this.isDragging = false;
        clearTimeout(this.resumeTimer);
        this.resumeTimer = setTimeout(() => {
          this.autoRotate = true;
        }, 1500);
      }
    });

    let lastMiniClickTime = 0;
    this.canvas.addEventListener('click', (e) => {
      const now = Date.now();
      if (now - lastMiniClickTime < 380) {
        lastMiniClickTime = 0;
        e.stopPropagation();
        this.handleDoubleClickPause();
      } else {
        lastMiniClickTime = now;
      }
    });

    this.canvas.addEventListener('dblclick', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.handleDoubleClickPause();
    });
  }

  handleDoubleClickPause(notifyParent = true) {
    this.isPausedByDblClick = true;
    if (this.pauseTimer) clearTimeout(this.pauseTimer);

    console.log("[Mini3DInspector] Kích 2 lần: Ngưng xoay 3D. Đợi 30s sau mới xoay tiếp.");
    if (notifyParent && window.chillApp && typeof window.chillApp.showMiniToast === 'function') {
      window.chillApp.showMiniToast("⏸️ Đã ngưng xoay 3D (Đợi 30s sau mới xoay tiếp)", "info");
    }

    if (notifyParent && window.chillApp && window.chillApp.viewer && typeof window.chillApp.viewer.handleDoubleClickPause === 'function') {
      window.chillApp.viewer.isPausedByDblClick = true;
      if (window.chillApp.viewer.pauseTimer) clearTimeout(window.chillApp.viewer.pauseTimer);
      window.chillApp.viewer.pauseTimer = setTimeout(() => {
        window.chillApp.viewer.isPausedByDblClick = false;
      }, 30000);
    }

    this.pauseTimer = setTimeout(() => {
      this.isPausedByDblClick = false;
      console.log("[Mini3DInspector] Đã hết 30s: Tiếp tục xoay chi tiết.");
    }, 30000);
  }

  startTimerLoop() {
    if (this.timerLoopId) clearInterval(this.timerLoopId);
    // Khi người dùng click trong SketchUp viewport, cửa sổ HtmlDialog mất focus khiến Chromium
    // ngừng requestAnimationFrame. Timer kiểm tra nếu RAF ngừng > 50ms thì tiếp tục duy trì xoay mượt mà!
    this.timerLoopId = setInterval(() => {
      const now = (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();
      if (now - this.lastRafTime > 50) {
        this.renderFrame();
      }
    }, 33);
  }

  animate() {
    this.lastRafTime = (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();
    this.animationId = requestAnimationFrame(this.animate.bind(this));
    this.renderFrame();
  }

  renderFrame() {
    if (!this.canvas) return;
    // Bỏ qua nếu canvas thực sự bị ẩn
    if (this.canvas.offsetParent === null && window.getComputedStyle(this.canvas).display === 'none') return;

    if (this.modelGroup && this.autoRotate && !this.isDragging && !this.isPausedByDblClick) {
      if (this.spinRemaining > 0) {
        // Đang trong chu kỳ xoay chậm êm ái (ít nhất 3 vòng 360 độ liên tục)
        this.modelGroup.rotation.y += this.spinSpeed;
        this.spinRemaining -= this.spinSpeed;
      } else {
        // Đã hoàn thành ít nhất 3 vòng xoay (3 x 360 độ) -> Tạm dừng một nhịp ngắn ngắm mặt tiền rồi tiếp tục chu kỳ 3 vòng tiếp
        if (!this.isPausedCycle) {
          this.isPausedCycle = true;
          this.pauseRemainingFrames = 80; // ~2.5 giây dừng ngắm mặt chính diện
        } else {
          this.pauseRemainingFrames--;
          if (this.pauseRemainingFrames <= 0) {
            // Hết thời gian nghỉ -> Chuẩn hóa góc quay mượt mà và bắt đầu chu kỳ 3 vòng mới uyển chuyển!
            this.isPausedCycle = false;
            this.modelGroup.rotation.y = this.modelGroup.rotation.y % (Math.PI * 2);
            this.spinRemaining = Math.PI * 2 * this.rotationsPerCycle;
          }
        }
      }
    }

    if (this.renderer && this.scene && this.camera) {
      this.renderer.render(this.scene, this.camera);
    }
  }

  onResize() {
    if (!this.canvas || !this.renderer || !this.camera) return;
    const parent = this.canvas.parentElement;
    const w = parent ? parent.clientWidth : 160;
    const h = parent ? parent.clientHeight : 100;
    if (w > 10 && h > 10) {
      this.camera.aspect = w / h;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(w, h, false);
      if (this.modelGroup) this.fitCameraToObject(this.modelGroup);
    }
  }

  // Làm sạch model cũ
  clearModel() {
    if (!this.modelGroup) return;
    while (this.modelGroup.children.length > 0) {
      const obj = this.modelGroup.children[0];
      this.modelGroup.remove(obj);
      if (obj.geometry) obj.geometry.dispose();
      if (obj.material) {
        if (Array.isArray(obj.material)) obj.material.forEach(m => m.dispose());
        else obj.material.dispose();
      }
    }
    this.modelGroup.rotation.set(0.15, 0.4, 0);
  }

  // Hiển thị và phân tích đối tượng
  inspect(data, sourceMesh = null) {
    if (!this.isSupported) return;
    try {
      this.clearModel();
      this.autoRotate = true;
      this.onResize();

      const svgFallback = document.getElementById('obj-portrait-svg');
      if (this.canvas) this.canvas.style.display = 'block';
      if (svgFallback) svgFallback.style.display = 'none';

      // 1. Nếu có Mesh thực tế truyền vào từ ThreeJS Viewport
      if (sourceMesh && sourceMesh.geometry) {
        try {
          const cloneGeo = sourceMesh.geometry.clone();
          const cloneMat = (sourceMesh.material && sourceMesh.material.clone)
            ? sourceMesh.material.clone()
            : new THREE.MeshStandardMaterial({ color: 0xd4a373, roughness: 0.5, metalness: 0.1 });

          const mesh = new THREE.Mesh(cloneGeo, cloneMat);
          mesh.castShadow = true;

          // Viền vàng kim sắc nét bao quanh chi tiết
          const edges = new THREE.EdgesGeometry(cloneGeo);
          const line = new THREE.LineSegments(edges, new THREE.LineBasicMaterial({ color: 0xf59e0b, linewidth: 1 }));
          mesh.add(line);

          this.modelGroup.add(mesh);
          this.fitCameraToObject(this.modelGroup);
          this.spinShowcase(3);
          return;
        } catch (err) {
          console.warn("[Mini3DInspector] Failed to clone sourceMesh, falling back to procedural model:", err);
        }
      }

      // 2. Dựng mô hình 3D thực tế theo Tầng (Procedural 3D Model theo Tier & Kích Thước Thật)
      const tier = (data && data.tier) ? parseInt(data.tier) : 1;
      const name = ((data && data.name) || "").toLowerCase();
      const iconType = (data && data.icon_type) || "panel";

      // Vật liệu chuẩn Studio
      const woodOakMat = new THREE.MeshStandardMaterial({ color: 0xd4a373, roughness: 0.6, metalness: 0.1 });
      const woodWalnutMat = new THREE.MeshStandardMaterial({ color: 0x5c4033, roughness: 0.5, metalness: 0.1 });
      const metalBlackMat = new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.35, metalness: 0.85 });
      const metalChromeMat = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.15, metalness: 0.95 });
      const glassCyanMat = new THREE.MeshStandardMaterial({ color: 0x38bdf8, transparent: true, opacity: 0.85, roughness: 0.1 });
      const pvcEdgeMat = new THREE.MeshStandardMaterial({ color: 0xf59e0b, roughness: 0.4, metalness: 0.2 });

      const modelType = ((data && (data.model_type || data.type)) || "").toLowerCase();
      const isWardrobe = modelType === 'wardrobe' || name.includes('tủ áo') || name.includes('quần áo') || name.includes('wardrobe') || name.includes('closet') || (name.includes('tủ') && !name.includes('bếp'));
      const isKitchen = modelType === 'kitchen_cabinet' || name.includes('bếp') || name.includes('kitchen');
      const isBed = modelType === 'bed' || name.includes('giường') || name.includes('bed');
      const isShelf = modelType === 'shelf' || name.includes('kệ') || name.includes('shelf') || name.includes('giá sách');
      const isDesk = modelType === 'desk' || name.includes('bàn') || name.includes('desk') || name.includes('table');

      if (tier === 1) {
        if (isWardrobe) {
          // Tủ quần áo 3 cánh 2 ngăn kéo chuẩn xác 100% như mô hình SketchUp của anh Huy
          this.buildMiniWardrobe(woodOakMat, woodWalnutMat, metalChromeMat, pvcEdgeMat);
        } else if (isKitchen) {
          this.buildMiniKitchen(woodOakMat, metalChromeMat, glassCyanMat);
        } else if (isBed) {
          this.buildMiniBed(woodOakMat, woodWalnutMat);
        } else if (isShelf) {
          this.buildMiniShelf(woodOakMat);
        } else {
          this.buildMiniDesk(woodOakMat, metalBlackMat, woodWalnutMat, metalChromeMat);
        }

      } else if (tier === 2) {
        // 📦 TẦNG 2: KHỐI LẺ (Module Thành Phần Độc Lập)
        if (name.includes('chân') || name.includes('sat') || iconType === 'module' && name.includes('khung')) {
          // Mô hình Khung Chân Sắt Chữ U Đôi Hộp 40x40
          const leg1 = new THREE.Mesh(new THREE.BoxGeometry(10, 100, 10), metalBlackMat);
          leg1.position.set(0, 0, -35);
          const leg2 = new THREE.Mesh(new THREE.BoxGeometry(10, 100, 10), metalBlackMat);
          leg2.position.set(0, 0, 35);
          const botBar = new THREE.Mesh(new THREE.BoxGeometry(10, 10, 80), metalBlackMat);
          botBar.position.set(0, -45, 0);
          const topBar = new THREE.Mesh(new THREE.BoxGeometry(10, 10, 80), metalBlackMat);
          topBar.position.set(0, 45, 0);
          this.modelGroup.add(leg1, leg2, botBar, topBar);

          // Nút đế chân cao su
          [-35, 35].forEach(z => {
            const foot = new THREE.Mesh(new THREE.CylinderGeometry(7, 7, 4, 16), metalChromeMat);
            foot.position.set(0, -52, z);
            this.modelGroup.add(foot);
          });

        } else if (name.includes('hộc') || name.includes('ngăn kéo')) {
          // Mô hình Hộc Tủ 2 Ngăn Kéo Hoàn Chỉnh
          const box = new THREE.Mesh(new THREE.BoxGeometry(60, 80, 70), woodOakMat);
          this.modelGroup.add(box);

          // Mặt ngăn kéo nổi
          [-18, 18].forEach(y => {
            const drawerFront = new THREE.Mesh(new THREE.BoxGeometry(56, 32, 4), woodWalnutMat);
            drawerFront.position.set(0, y, 36);
            const handle = new THREE.Mesh(new THREE.BoxGeometry(22, 4, 6), metalChromeMat);
            handle.position.set(0, y, 39);
            this.modelGroup.add(drawerFront, handle);
          });

        } else {
          // Mô hình Mặt Bàn Gỗ Sồi Dày 25mm Bo Cạnh Tinh Xảo
          const l = Math.min(Math.max((data.dim_x || 120) * 0.1, 70), 120);
          const w = Math.min(Math.max((data.dim_y || 60) * 0.1, 45), 80);
          const deskTop = new THREE.Mesh(new THREE.BoxGeometry(l, 10, w), woodOakMat);
          const edges = new THREE.EdgesGeometry(deskTop.geometry);
          const line = new THREE.LineSegments(edges, new THREE.LineBasicMaterial({ color: 0xf59e0b, linewidth: 2 }));
          deskTop.add(line);
          this.modelGroup.add(deskTop);
        }

      } else {
        // 🪵 TẦNG 3: MIẾNG VÁN NHỎ / PHỤ KIỆN KIM KHÍ
        if (name.includes('tay nắm') || iconType === 'hardware' && (name.includes('tay') || name.includes('handle') || name.includes('pull') || name.includes('knob'))) {
          // Tay nắm hợp kim nhôm đúc sang trọng, tỉ lệ thanh thoát chuẩn thiết kế (vừa vặn, to hơn bản cũ một chút)
          const barGeo = new THREE.CylinderGeometry(3.6, 3.6, 76, 24);
          const bar = new THREE.Mesh(barGeo, metalChromeMat);
          bar.rotation.z = Math.PI / 2;

          const legGeo = new THREE.CylinderGeometry(4, 4, 22, 24);
          const legL = new THREE.Mesh(legGeo, metalChromeMat);
          legL.position.set(-29, -11, 0);
          const legR = new THREE.Mesh(legGeo, metalChromeMat);
          legR.position.set(29, -11, 0);

          // Đế chân tiếp xúc Melamine cánh tủ
          const footGeo = new THREE.CylinderGeometry(6, 6, 2.5, 24);
          const footL = new THREE.Mesh(footGeo, metalBlackMat);
          footL.position.set(-29, -22, 0);
          const footR = new THREE.Mesh(footGeo, metalBlackMat);
          footR.position.set(29, -22, 0);

          this.modelGroup.add(bar, legL, legR, footL, footR);

        } else if (name.includes('bản lề') || name.includes('hinge')) {
          const cup = new THREE.Mesh(new THREE.CylinderGeometry(18, 18, 10, 24), metalChromeMat);
          cup.position.set(-20, 0, 0);
          const arm = new THREE.Mesh(new THREE.BoxGeometry(45, 12, 14), metalChromeMat);
          arm.position.set(12, 0, 0);
          this.modelGroup.add(cup, arm);

        } else {
          const panelGeo = new THREE.BoxGeometry(85, 8, 55);
          const panel = new THREE.Mesh(panelGeo, woodOakMat);

          const edgeL = new THREE.Mesh(new THREE.BoxGeometry(85, 9, 2), pvcEdgeMat);
          edgeL.position.set(0, 0, 28);
          const edgeR = new THREE.Mesh(new THREE.BoxGeometry(85, 9, 2), pvcEdgeMat);
          edgeR.position.set(0, 0, -28);
          this.modelGroup.add(panel, edgeL, edgeR);
        }
      }

      this.fitCameraToObject(this.modelGroup);
      this.spinShowcase(3);
      this.renderFrame();
    } catch (err) {
      console.warn("[Mini3DInspector] inspect error:", err);
    }
  }

  buildMiniDesk(woodOakMat, metalBlackMat, woodWalnutMat, metalChromeMat) {
    try {
      const topGeo = new THREE.BoxGeometry(120, 5, 60);
      const topMesh = new THREE.Mesh(topGeo, woodOakMat);
      topMesh.position.set(0, 36, 0);
      this.modelGroup.add(topMesh);

      [-52, 52].forEach(x => {
        const leg1 = new THREE.Mesh(new THREE.BoxGeometry(6, 70, 6), metalBlackMat);
        leg1.position.set(x, 0, -24);
        const leg2 = new THREE.Mesh(new THREE.BoxGeometry(6, 70, 6), metalBlackMat);
        leg2.position.set(x, 0, 24);
        const legBot = new THREE.Mesh(new THREE.BoxGeometry(6, 6, 54), metalBlackMat);
        legBot.position.set(x, -33, 0);
        const legTop = new THREE.Mesh(new THREE.BoxGeometry(6, 6, 54), metalBlackMat);
        legTop.position.set(x, 32, 0);
        this.modelGroup.add(leg1, leg2, legBot, legTop);
      });

      const brace = new THREE.Mesh(new THREE.BoxGeometry(100, 5, 5), metalBlackMat);
      brace.position.set(0, 28, -24);
      this.modelGroup.add(brace);

      const cabinet = new THREE.Mesh(new THREE.BoxGeometry(32, 42, 48), woodWalnutMat);
      cabinet.position.set(28, 6, 0);
      this.modelGroup.add(cabinet);

      [-3, 15].forEach(y => {
        const handle = new THREE.Mesh(new THREE.BoxGeometry(12, 2, 3), metalChromeMat);
        handle.position.set(28, y, 25);
        this.modelGroup.add(handle);
      });
    } catch (err) {
      console.warn("[Mini3DInspector] buildMiniDesk error:", err);
    }
  }

  buildMiniWardrobe(woodOakMat, woodWalnutMat, metalChromeMat, pvcEdgeMat) {
    try {
      const w = 96, h = 136, d = 46, t = 4;
      const sideL = new THREE.Mesh(new THREE.BoxGeometry(t, h, d), woodOakMat);
      sideL.position.set(-w / 2 + t / 2, 0, 0);
      const sideR = new THREE.Mesh(new THREE.BoxGeometry(t, h, d), woodOakMat);
      sideR.position.set(w / 2 - t / 2, 0, 0);
      const top = new THREE.Mesh(new THREE.BoxGeometry(w - 2 * t, t, d), woodOakMat);
      top.position.set(0, h / 2 - t / 2, 0);
      const bottom = new THREE.Mesh(new THREE.BoxGeometry(w - 2 * t, t, d), woodOakMat);
      bottom.position.set(0, -h / 2 + t / 2 + 8, 0);
      const plinth = new THREE.Mesh(new THREE.BoxGeometry(w - 2 * t, 8, t), woodOakMat);
      plinth.position.set(0, -h / 2 + 4, d / 2 - 4);
      const back = new THREE.Mesh(new THREE.BoxGeometry(w - 2 * t, h - 12, 2), woodWalnutMat);
      back.position.set(0, 2, -d / 2 + 2);

      this.modelGroup.add(sideL, sideR, top, bottom, plinth, back);

      const colW = (w - 2 * t) / 3;
      const dividerX = -w / 2 + t + 2 * colW;
      const divider = new THREE.Mesh(new THREE.BoxGeometry(t, h - t - 8, d - 4), woodOakMat);
      divider.position.set(dividerX, 4, 0);
      this.modelGroup.add(divider);

      const drH = 34;
      const shelfX = -w / 2 + t + colW;
      const shelfY = -h / 2 + 8 + t + drH;
      const shelf = new THREE.Mesh(new THREE.BoxGeometry(2 * colW, t, d - 4), woodOakMat);
      shelf.position.set(shelfX, shelfY, 0);
      this.modelGroup.add(shelf);

      const posZ = d / 2 + 1;

      const rightDoorW = colW - 1.5;
      const rightDoorH = h - 10;
      const rightDoorX = dividerX + colW / 2;
      const rightDoor = new THREE.Mesh(new THREE.BoxGeometry(rightDoorW, rightDoorH, t), woodOakMat);
      rightDoor.position.set(rightDoorX, 1, posZ);
      const rightHandle = new THREE.Mesh(new THREE.BoxGeometry(2, 16, 2.5), metalChromeMat);
      rightHandle.position.set(rightDoorX - rightDoorW / 2 + 4, 0, posZ + 2.5);
      this.modelGroup.add(rightDoor, rightHandle);

      const leftDoorW = colW - 1.5;
      const leftDoorH = h - 10 - drH - t;
      const upperY = shelfY + t / 2 + leftDoorH / 2;
      [-0.5, 0.5].forEach((offset, idx) => {
        const doorX = shelfX + offset * colW;
        const door = new THREE.Mesh(new THREE.BoxGeometry(leftDoorW, leftDoorH, t), woodOakMat);
        door.position.set(doorX, upperY, posZ);
        const handle = new THREE.Mesh(new THREE.BoxGeometry(2, 14, 2.5), metalChromeMat);
        const hX = (idx === 0) ? doorX + leftDoorW / 2 - 4 : doorX - leftDoorW / 2 + 4;
        handle.position.set(hX, upperY - 10, posZ + 2.5);
        this.modelGroup.add(door, handle);
      });

      const singleDrH = (drH - 4) / 2;
      const drW = 2 * colW - 2;
      for (let j = 0; j < 2; j++) {
        const drY = -h / 2 + 8 + t + j * (singleDrH + 2) + singleDrH / 2;
        const drawerFront = new THREE.Mesh(new THREE.BoxGeometry(drW, singleDrH, t), woodWalnutMat);
        drawerFront.position.set(shelfX, drY, posZ);
        [-colW / 2, colW / 2].forEach(hx => {
          const hMesh = new THREE.Mesh(new THREE.BoxGeometry(10, 2, 2.5), metalChromeMat);
          hMesh.position.set(shelfX + hx, drY, posZ + 2.5);
          this.modelGroup.add(hMesh);
        });
        this.modelGroup.add(drawerFront);
      }
    } catch (err) {
      console.warn("[Mini3DInspector] buildMiniWardrobe error:", err);
    }
  }

  buildMiniKitchen(woodOakMat, metalChromeMat, glassCyanMat) {
    try {
      const w = 110, lowerH = 46, upperH = 40, splashH = 34, d = 48;
      const lower = new THREE.Mesh(new THREE.BoxGeometry(w, lowerH, d), woodOakMat);
      lower.position.set(0, -35, 0);

      const stoneMat = new THREE.MeshStandardMaterial({ color: 0xf1f5f9, roughness: 0.2, metalness: 0.1 });
      const stoneTop = new THREE.Mesh(new THREE.BoxGeometry(w + 4, 4, d + 4), stoneMat);
      stoneTop.position.set(0, -10, 0);

      const splash = new THREE.Mesh(new THREE.BoxGeometry(w, splashH, 2), glassCyanMat);
      splash.position.set(0, 10, -d / 2 + 2);

      const upper = new THREE.Mesh(new THREE.BoxGeometry(w, upperH, d * 0.65), woodOakMat);
      upper.position.set(0, 48, -d * 0.175);

      const tap = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 14, 16), metalChromeMat);
      tap.position.set(20, -1, 4);

      this.modelGroup.add(lower, stoneTop, splash, upper, tap);
    } catch (err) {
      console.warn("[Mini3DInspector] buildMiniKitchen error:", err);
    }
  }

  buildMiniBed(woodOakMat, woodWalnutMat) {
    try {
      const w = 90, l = 120, h = 22;
      const headboard = new THREE.Mesh(new THREE.BoxGeometry(w, 54, 6), woodWalnutMat);
      headboard.position.set(0, 12, -l / 2 + 3);

      const bedFrame = new THREE.Mesh(new THREE.BoxGeometry(w, h, l), woodOakMat);
      bedFrame.position.set(0, -10, 0);

      const mattressMat = new THREE.MeshStandardMaterial({ color: 0xf8fafc, roughness: 0.8 });
      const mattress = new THREE.Mesh(new THREE.BoxGeometry(w - 8, 14, l - 12), mattressMat);
      mattress.position.set(0, 2, 4);

      const pillowMat = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.7 });
      [-22, 22].forEach(px => {
        const pillow = new THREE.Mesh(new THREE.BoxGeometry(28, 6, 20), pillowMat);
        pillow.position.set(px, 11, -l / 2 + 22);
        this.modelGroup.add(pillow);
      });

      this.modelGroup.add(headboard, bedFrame, mattress);
    } catch (err) {
      console.warn("[Mini3DInspector] buildMiniBed error:", err);
    }
  }

  buildMiniShelf(woodOakMat) {
    try {
      const w = 76, h = 130, d = 32, t = 4;
      const sideL = new THREE.Mesh(new THREE.BoxGeometry(t, h, d), woodOakMat);
      sideL.position.set(-w / 2 + t / 2, 0, 0);
      const sideR = new THREE.Mesh(new THREE.BoxGeometry(t, h, d), woodOakMat);
      sideR.position.set(w / 2 - t / 2, 0, 0);
      this.modelGroup.add(sideL, sideR);

      for (let i = 0; i < 5; i++) {
        const shelfY = -h / 2 + t / 2 + i * ((h - t) / 4);
        const shelf = new THREE.Mesh(new THREE.BoxGeometry(w - 2 * t, t, d), woodOakMat);
        shelf.position.set(0, shelfY, 0);
        this.modelGroup.add(shelf);
      }
    } catch (err) {
      console.warn("[Mini3DInspector] buildMiniShelf error:", err);
    }
  }

  spinShowcase(rotations = 3) {
    this.rotationsPerCycle = rotations;
    this.spinRemaining = Math.PI * 2 * rotations;
    this.isPausedCycle = false;
    this.pauseRemainingFrames = 0;
    this.autoRotate = true;
  }

  // Tự động căn giữa tâm đối tượng và điều chỉnh camera vừa khít góc nhìn
  fitCameraToObject(objectGroup) {
    if (!objectGroup || !this.camera) return;

    const bbox = new THREE.Box3().setFromObject(objectGroup);
    const center = bbox.getCenter(new THREE.Vector3());
    const size = bbox.getSize(new THREE.Vector3());

    // Căn giữa tâm đối tượng về gốc (0, 0, 0)
    objectGroup.children.forEach(child => {
      child.position.sub(center);
    });

    const maxDim = Math.max(size.x, size.y, size.z, 35);
    // Khoảng cách camera cân đối: cách viền biên vừa phải (~15-18% lề thoáng đãng), to hơn bản cũ một chút, tuyệt đối không cấn viền
    const dist = maxDim * 1.22;

    this.camera.position.set(dist * 0.9, dist * 0.65, dist * 1.15);
    this.camera.lookAt(0, 0, 0);
  }
}

window.Mini3DInspector = Mini3DInspector;
