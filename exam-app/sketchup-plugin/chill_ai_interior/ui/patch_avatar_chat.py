import sys

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Add a history array in constructor
if 'this.chatHistory = [];' not in js:
    js = js.replace('this.speechBubble = document.getElementById(\'avatar-speech-bubble\');', 
                    'this.speechBubble = document.getElementById(\'avatar-speech-bubble\');\n    this.chatHistory = [];')

# Replace handleUserMessage
old_handle = """  handleUserMessage(query) {
    const q = query.toLowerCase();
    this.addMessage('user', query);
    this.setEmotion('thinking');

    setTimeout(() => {
      // 1. Kế chuyện quy trình làm nội thất
      if (q.includes('quy trình') || q.includes('kể chuyện') || q.includes('các bước')) {
        this.tellProcessStory();
      }
      // 2. Tư vấn phong cách
      else if (q.includes('phong cách') || q.includes('style') || q.includes('phòng ngủ') || q.includes('bố trí')) {
        this.consultStyle();
      }
      // 3. Tư vấn vật liệu
      else if (q.includes('vật liệu') || q.includes('gỗ') || q.includes('mdf') || q.includes('an cường') || q.includes('sồi')) {
        this.consultMaterials();
      }
      // 4. Tạo mô hình bàn công thái học
      else if (q.includes('bàn') || q.includes('công thái học') || q.includes('tạo')) {
        this.createErgonomicDeskAction();
      }
      // 5. Trả lời chung với suy luận chuyên sâu
      else {
        this.genericConsultation(query);
      }
    }, 400);
  }"""

new_handle = """  async handleUserMessage(query) {
    const q = query.toLowerCase();
    this.addMessage('user', query);
    this.setEmotion('thinking');
    
    // Store in history
    this.chatHistory.push({ role: "user", parts: [{ text: query }] });
    // Keep history manageable
    if (this.chatHistory.length > 10) this.chatHistory = this.chatHistory.slice(this.chatHistory.length - 10);

    // Nếu người dùng chưa nhập API Key, trả về chế độ Demo Mockup
    if (!window.app || !window.app.geminiApiKey) {
      setTimeout(() => {
        if (q.includes('quy trình')) this.tellProcessStory();
        else if (q.includes('phong cách') || q.includes('style')) this.consultStyle();
        else if (q.includes('vật liệu') || q.includes('gỗ')) this.consultMaterials();
        else if (q.includes('bàn') || q.includes('tạo')) this.createErgonomicDeskAction();
        else {
          this.setEmotion('explaining');
          this.addMessage('bot', `Chỉ huy ơi, Lyly hiện đang ở chế độ Offline (Demo).<br><br>Chỉ huy vui lòng vào mục <strong>Cấu hình API</strong> để dán API Key (Google AI). Khi có kết nối mạng, Lyly sẽ trò chuyện cực kỳ tự nhiên và thông minh như ChatGPT nhé!`);
        }
      }, 500);
      return;
    }

    // NẾU CÓ API KEY -> GỌI GEMINI API ĐỂ CHAT TỰ NHIÊN
    try {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${window.app.geminiApiKey}`;
      
      const requestBody = JSON.stringify({
        system_instruction: {
          parts: [{text: "Bạn là Lyly, nữ trợ lý ảo 2D của plugin Chill AI Interior trên phần mềm SketchUp. Bạn là một chuyên gia về thiết kế nội thất, gỗ công nghiệp MDF, sản xuất CNC, và nhân trắc học. Bạn nói chuyện dễ thương, thân thiện, và luôn gọi người dùng là 'Chỉ huy'. Câu trả lời của bạn phải ngắn gọn, súc tích (dưới 100 chữ) và mang tính tư vấn chuyên môn. Tránh dùng định dạng markdown quá phức tạp. Trả lời trực tiếp vào câu hỏi."}]
        },
        contents: this.chatHistory,
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 300
        }
      });

      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: requestBody
      });

      if (!res.ok) {
        throw new Error('API Error');
      }

      const data = await res.json();
      const aiText = data.candidates[0].content.parts[0].text;
      
      // Save bot response to history
      this.chatHistory.push({ role: "model", parts: [{ text: aiText }] });
      
      this.setEmotion('happy');
      // Replace bold markdown with html for bubble
      let formattedText = aiText.replace(/\\*\\*(.*?)\\*\\*/g, '<strong>$1</strong>');
      formattedText = formattedText.replace(/\\n/g, '<br>');
      this.addMessage('bot', formattedText);

    } catch (error) {
      console.error("Lỗi AI Chat:", error);
      this.setEmotion('sad');
      this.addMessage('bot', 'Xin lỗi Chỉ huy, đường truyền đến máy chủ AI (Gemini) đang bị lỗi hoặc API Key bị hết hạn. Vui lòng kiểm tra lại kết nối nhé!');
    }
  }"""

# A quick manual replace if exact match fails due to encoding or small whitespace diffs
import re
js = re.sub(r'handleUserMessage\(query\) \{[\s\S]*?genericConsultation\(query\);\s*\}\s*\}, 400\);\s*\}', new_handle, js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("avatar.js patched for natural Gemini chat!")
