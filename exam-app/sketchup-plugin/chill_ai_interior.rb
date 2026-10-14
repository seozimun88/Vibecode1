# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - SketchUp Plugin Loader
# Tự động hóa thiết kế 3D, Dynamic Component & xuất G-Code CNC bằng AI
# ==============================================================================

require 'sketchup.rb'
require 'extensions.rb'

module ChillAIInterior
  PLUGIN_ID = 'chill_ai_interior'.freeze
  PLUGIN_NAME = 'Chill AI Interior - Trợ Lý Thiết Kế & CNC AI'.freeze
  PLUGIN_VERSION = '1.0.0'.freeze

  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new(PLUGIN_NAME, File.join(File.dirname(__FILE__), PLUGIN_ID, 'main.rb'))
    extension.description = 'Plugin AI cho SketchUp: Quét ảnh tạo 3D, sinh Dynamic Component, trợ lý ảo 2D và bóc tách xuất G-Code CNC.'
    extension.version     = PLUGIN_VERSION
    extension.creator     = 'Chill Chill Decor'
    extension.copyright   = '2026 Chill Chill Decor'

    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
