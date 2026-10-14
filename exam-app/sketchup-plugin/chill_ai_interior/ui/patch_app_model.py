import re

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Make sure we add `this.geminiModel` to constructor or init
js = js.replace("this.geminiApiKey = localStorage.getItem('chill_ai_gemini_key') || '';",
                "this.geminiApiKey = localStorage.getItem('chill_ai_gemini_key') || '';\n    this.geminiModel = localStorage.getItem('chill_ai_gemini_model') || 'gemini-1.5-flash';")

# Replace updateBanner to show model info
new_updateBanner = """    const updateBanner = () => {
      const dot = document.getElementById('api-status-dot');
      const label = document.getElementById('api-status-label');
      const desc = document.getElementById('api-status-desc');
      if (!dot || !label || !desc) return;
      
      const modelName = this.geminiModel === 'gemini-1.5-pro' ? 'Gemma 4 Pro' : 'Gemma 4';

      if (this.geminiApiKey) {
        dot.className = 'api-status-dot';
        label.textContent = `Chế độ AI: ${modelName} Vision (Đã kết nối Key)`;
        desc.textContent = `Mỗi khi kéo ảnh tải lên, hệ thống sẽ gọi trực tiếp mô hình ${modelName} để nhận diện thật!`;
      } else {
        dot.className = 'api-status-dot no-key';
        label.textContent = 'Chế độ AI: Bản dùng thử (Demo Mockup)';
        desc.textContent = 'Chưa có API Key. Bấm "Cài đặt Key" để dán mã Google AI miễn phí và quét ảnh thật 100%.';
      }
    };"""

js = re.sub(r"const updateBanner = \(\) => \{[\s\S]*?\};\n", new_updateBanner + "\n", js)

# Hook input initialization
initGemini = """    const inputModel = document.getElementById('input-gemini-model');
    if (inputModel && this.geminiModel) inputModel.value = this.geminiModel;
"""
js = js.replace("const inputKey = document.getElementById('input-gemini-key');\n", "const inputKey = document.getElementById('input-gemini-key');\n" + initGemini)

# Replace save button logic to save the model
old_save = """    if (btnSave) {
      btnSave.addEventListener('click', () => {
        const val = inputKey.value.trim();
        if (!val) {
          alert('Vui lòng nhập API Key hợp lệ!');
          return;
        }
        this.geminiApiKey = val;
        localStorage.setItem('chill_ai_gemini_key', val);
        updateBanner();
        if (modal) modal.style.display = 'none';
        alert('Đã lưu Google AI (Gemma 4) API Key thành công! Bây giờ bạn có thể tải bất kỳ ảnh nào lên để quét thật.');
        if (this.avatar) {
          this.avatar.setEmotion('happy');
          this.avatar.addMessage('bot', 'Tuyệt vời! Gemma 4 AI đã kết nối thành công. Giờ bạn cứ tải ảnh chụp bất kỳ lên, mình sẽ nhận diện ngay lập tức!');
        }
      });
    }"""

new_save = """    if (btnSave) {
      btnSave.addEventListener('click', () => {
        const val = inputKey.value.trim();
        if (!val) {
          alert('Vui lòng nhập API Key hợp lệ!');
          return;
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
        const modelName = this.geminiModel === 'gemini-1.5-pro' ? 'Gemma 4 Pro' : 'Gemma 4';
        alert(`Đã lưu Google AI (${modelName}) API Key thành công! Bây giờ bạn có thể tải bất kỳ ảnh nào lên để quét thật.`);
        if (this.avatar) {
          this.avatar.setEmotion('happy');
          this.avatar.addMessage('bot', `Tuyệt vời! ${modelName} AI đã kết nối thành công. Giờ bạn cứ tải ảnh chụp bất kỳ lên, mình sẽ nhận diện ngay lập tức!`);
        }
      });
    }"""

# Do a simple string replace for old_save but considering encodings it might fail, so we'll use regex for btnSave
btnSave_pattern = r"if \(btnSave\) \{\s*btnSave\.addEventListener\('click', \(\) => \{[\s\S]*?\}\);\s*\}"
js = re.sub(btnSave_pattern, new_save, js)


# Also in scanImage, use this.geminiModel
js = js.replace("models/gemini-1.5-flash:generateContent", "models/${this.geminiModel || 'gemini-1.5-flash'}:generateContent")

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Updated app.js with geminiModel!")
