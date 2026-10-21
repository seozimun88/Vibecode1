# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Native Windows Audio Bridge
# Plays audio via Windows Media Player COM object (Bypasses CEF codec limits)
# STA Main-Thread Execution, Multi-Chunk MP3 Stitching, Persona Rate Modulation
# ==============================================================================

require 'base64'
require 'tmpdir'
require 'net/http'
require 'uri'

module ChillAIInterior
  module AudioPlayer
    @wmp = nil
    @current_file = nil
    @monitor_timer = nil

    def self.get_player
      if @wmp.nil?
        begin
          require 'win32ole'
          @wmp = WIN32OLE.new('WMPlayer.OCX')
          @wmp.settings.autoStart = true
          @wmp.settings.volume = 100
        rescue => e
          puts "[Chill AI Audio] WIN32OLE init warning: #{e.message}"
          @wmp = nil
        end
      end
      @wmp
    end

    def self.ensure_tts_server
      root = ChillAIInterior.const_defined?(:PLUGIN_ROOT) ? ChillAIInterior::PLUGIN_ROOT : File.expand_path('..', __dir__)
      server_script = File.join(root, 'tts_server.py')
      return false unless File.exist?(server_script)

      # 1. Ping existing server
      begin
        uri = URI.parse('http://127.0.0.1:57821/ping')
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 0.4
        http.read_timeout = 0.4
        res = http.get(uri.request_uri)
        return true if res.is_a?(Net::HTTPSuccess)
      rescue => _
      end

      # 2. Launch background pythonw process
      python_exe = 'C:\\Python314\\pythonw.exe'
      python_exe = 'pythonw' unless File.exist?(python_exe)

      begin
        plugin_dir = File.dirname(server_script)
        pid = spawn(python_exe, "-X", "utf8", server_script, :chdir => plugin_dir, :new_pgroup => true, [:out, :err] => File::NULL)
        Process.detach(pid) if pid rescue nil
        puts "[Chill AI Audio] Spawned tts_server.py (PID: #{pid})"
      rescue => err
        puts "[Chill AI Audio] Spawn tts_server error: #{err.message}"
      end

      # 3. Wait up to 1.5s for server to start responding
      3.times do
        sleep 0.4
        begin
          uri = URI.parse('http://127.0.0.1:57821/ping')
          http = Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 0.5
          http.read_timeout = 0.5
          res = http.get(uri.request_uri)
          return true if res.is_a?(Net::HTTPSuccess)
        rescue => _
        end
      end

      false
    end


    def self.play(data)
      player = get_player
      return unless player

      ensure_tts_server

      base_speed = (data['speed'] || 1.0).to_f
      base_speed = 1.0 if base_speed <= 0
      voice = (data['voice'] || 'hoaimy').to_s.downcase

      detected_voice_type = 'neural'

      # Stop any currently playing audio safely
      begin
        player.controls.stop
      rescue => _
      end

      target_file = nil
      timestamp = (Time.now.to_f * 1000).to_i

      # 1. Base64 audio payload
      if data['base64'] && !data['base64'].empty?
        ext = data['format'] || 'mp3'
        temp_file = File.join(Dir.tmpdir, "chill_ai_voice_#{Process.pid}_#{timestamp}.#{ext}")
        File.open(temp_file, 'wb') { |f| f.write(Base64.decode64(data['base64'])) }
        target_file = temp_file

      # 2. Multi-chunk URLs (combines all chunks so long responses NEVER cut off!)
      elsif data['urls'] && data['urls'].is_a?(Array) && !data['urls'].empty?
        combined_data = "".b
        data['urls'].each do |url_str|
          begin
            uri = URI.parse(url_str.to_s.strip)
            is_local = (uri.host == '127.0.0.1' || uri.host == 'localhost')
            o_timeout = is_local ? 1.2 : 1.5
            r_timeout = is_local ? 6.5 : 2.5

            Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == 'https'), open_timeout: o_timeout, read_timeout: r_timeout) do |http|
              req = Net::HTTP::Get.new(uri.request_uri)
              req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
              res = http.request(req)
              if res.is_a?(Net::HTTPSuccess)
                combined_data << res.body
                detected_voice_type = res['X-ChillAI-Voice-Type'] || 'neural'
              end
            end
          rescue => err
            puts "[Chill AI Audio] Fetch notice: #{err.message}"
          end
        end

        # Fallback to Google Translate ONLY if explicitly requested voice is google
        if combined_data.bytesize == 0 && voice == 'google' && data['fallbackUrls'] && data['fallbackUrls'].is_a?(Array)
          detected_voice_type = 'fallback'
          data['fallbackUrls'].each do |url_str|
            begin
              uri = URI.parse(url_str.to_s.strip)
              Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == 'https'), open_timeout: 1.0, read_timeout: 2.0) do |http|
                req = Net::HTTP::Get.new(uri.request_uri)
                req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
                res = http.request(req)
                combined_data << res.body if res.is_a?(Net::HTTPSuccess)
              end
            rescue => _
            end
          end
        end

        if combined_data.bytesize > 0
          temp_file = File.join(Dir.tmpdir, "chill_ai_voice_#{Process.pid}_#{timestamp}.mp3")
          File.open(temp_file, 'wb') { |f| f.write(combined_data) }
          target_file = temp_file
        elsif data['urls'] && data['urls'][0]
          target_file = data['urls'][0]
        end

      # 3. Single direct URL fallback
      elsif data['url'] && !data['url'].empty?
        target_file = data['url']
      end

      return unless target_file

      # Determine effective playback rate based on user speed settings
      effective_rate = [[base_speed, 0.5].max, 2.0].min

      # Safely clean previous temp file if unlocked
      if @current_file && File.exist?(@current_file) && @current_file != target_file
        begin
          File.delete(@current_file)
        rescue => _
        end
      end
      @current_file = target_file if target_file.start_with?(Dir.tmpdir)

      # Load URL, reapply rate, and start playback
      player.url = target_file
      begin
        player.settings.rate = effective_rate
      rescue => _
      end
      player.controls.play

      # Re-apply rate once file opens so WMP doesn't reset it to 1.0
      if defined?(UI) && UI.respond_to?(:start_timer)
        UI.start_timer(0.08, false) { begin; player.settings.rate = effective_rate; rescue => _; end }
        UI.start_timer(0.25, false) { begin; player.settings.rate = effective_rate; rescue => _; end }
        UI.start_timer(0.50, false) { begin; player.settings.rate = effective_rate; rescue => _; end }

        # Real-time synchronization with avatar mouth animation
        UI.stop_timer(@monitor_timer) if @monitor_timer
        ChillAIInterior.dialog&.execute_script("if(window.avatar) window.avatar.onAudioStarted();") rescue nil

        has_started = false
        start_time = Time.now
        @monitor_timer = UI.start_timer(0.12, true) do
          begin
            state = player.playState
            has_started = true if state == 3 # wmppsPlaying

            if has_started
              if state == 1 || state == 8 || state == 2 || state == 0
                UI.stop_timer(@monitor_timer) rescue nil
                @monitor_timer = nil
                ChillAIInterior.dialog&.execute_script("if(window.avatar) window.avatar.onAudioFinished();") rescue nil
              end
            elsif (Time.now - start_time) > 4.0
              UI.stop_timer(@monitor_timer) rescue nil
              @monitor_timer = nil
              ChillAIInterior.dialog&.execute_script("if(window.avatar) window.avatar.onAudioFinished();") rescue nil
            end
          rescue => _
            UI.stop_timer(@monitor_timer) rescue nil
            @monitor_timer = nil
          end
        end
      end
    rescue => e
      puts "[Chill AI Audio Playback Error]: #{e.message}"
    end

    def self.stop
      if @monitor_timer
        UI.stop_timer(@monitor_timer) rescue nil
        @monitor_timer = nil
      end
      if @wmp
        begin
          @wmp.controls.stop
        rescue => _
        end
      end
      ChillAIInterior.dialog&.execute_script("if(window.avatar) window.avatar.onAudioFinished();") rescue nil
    end
  end
end
