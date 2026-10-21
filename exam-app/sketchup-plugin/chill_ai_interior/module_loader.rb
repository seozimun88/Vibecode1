# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Module Loader (Hot-Reload Tự Động Quét Thư Mục)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  module ModuleLoader
    # Lấy đường dẫn gốc của plugin
    def self.plugin_root
      ChillAIInterior.const_defined?(:PLUGIN_ROOT) ? ChillAIInterior::PLUGIN_ROOT : File.expand_path(File.dirname(__FILE__))
    end

    # Thu thập toàn bộ danh sách file Ruby cần nạp theo thứ tự ưu tiên kiến trúc Lego
    def self.collect_ruby_files
      root = plugin_root
      core_dir = File.join(root, 'core')

      files = []

      # 1. Quầy Lễ Tân (Bridge Router)
      router_file = File.join(root, 'bridge_router.rb')
      files << router_file if File.exist?(router_file)

      # 2. Chuyên gia Cửa Sổ (WindowManager)
      win_file = File.join(core_dir, 'window_manager.rb')
      files << win_file if File.exist?(win_file)

      # 3. Tự động quét toàn bộ các khối Lego Services trong thư mục core/
      if Dir.exist?(core_dir)
        Dir.glob(File.join(core_dir, '*.rb')).sort.each do |fpath|
          normalized = File.expand_path(fpath)
          files << normalized unless files.include?(normalized)
        end
      end

      # 4. Entrypoint chính (main.rb)
      main_file = File.join(root, 'main.rb')
      files << main_file if File.exist?(main_file)

      files
    end

    # Nạp ban đầu khi khởi động plugin
    def self.load_all
      files = collect_ruby_files
      loaded_count = 0
      files.each do |fpath|
        begin
          require fpath
          loaded_count += 1
        rescue => e
          puts "[Chill AI Loader Error] Lỗi nạp #{File.basename(fpath)}: #{e.message}"
        end
      end
      puts "[Chill AI Loader] Khởi động thành công #{loaded_count}/#{files.length} module Lego."
      loaded_count
    end

    # CƠ CHẾ HOT-RELOAD TỰ ĐỘNG QUÉT THƯ MỤC: NẠP ĐÈ TƯƠI MỚI VÀO RAM SKETCHUP
    def self.reload_all
      files = collect_ruby_files
      reloaded = []

      files.each do |fpath|
        begin
          load fpath
          reloaded << File.basename(fpath)
        rescue => e
          puts "[Chill AI Hot-Reload Error] Lỗi reload #{File.basename(fpath)}: #{e.message}"
        end
      end

      puts "[Chill AI Hot-Reload] Đã nạp đè tươi mới #{reloaded.length} file vào RAM: #{reloaded.join(', ')}"
      reloaded
    rescue => err
      puts "[Chill AI Hot-Reload Fatal] #{err.message}"
      []
    end
  end
end
