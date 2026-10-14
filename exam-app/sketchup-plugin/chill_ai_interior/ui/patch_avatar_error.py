import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Change system_instruction to systemInstruction, and fix typo "Bán là" to "Bạn là"
js = js.replace("system_instruction:", "systemInstruction:")
js = js.replace("Bán là Lyly", "Bạn là Lyly")

# Modify the fetch block to extract error message if !res.ok
old_fetch = """        if (!res.ok) {
          throw new Error('API Error');
        }

        const data = await res.json();
        const aiText = data.candidates[0].content.parts[0].text;"""

new_fetch = """        const data = await res.json();
        
        if (!res.ok) {
          const errMsg = data.error ? data.error.message : 'API Error';
          throw new Error(`Gemini API Error: ${errMsg}`);
        }

        const aiText = data.candidates[0].content.parts[0].text;"""

if "if (!res.ok)" in js:
    js = js.replace(old_fetch, new_fetch)

# Modify the catch block to display the actual error
old_catch = """      } catch (error) {
        console.error("Lỗi AI Chat:", error);
        this.setEmotion('sad');
        this.addMessage('bot', 'Xin lỗi Chỉ huy, đường truyền đến máy chủ AI (Gemini) đang bị lỗi hoặc API Key bị hết hạn. Vui lòng kiểm tra lại kết nối nhé!');
      }"""

new_catch = """      } catch (error) {
        console.error("Lỗi AI Chat:", error);
        this.setEmotion('sad');
        this.addMessage('bot', `Xin lỗi Chỉ huy, AI gặp lỗi: <strong>${error.message}</strong><br>Vui lòng kiểm tra lại API Key hoặc mạng nhé!`);
        // Remove the last user message from history so they can retry without breaking the alternating roles rule
        if (this.chatHistory.length > 0 && this.chatHistory[this.chatHistory.length - 1].role === 'user') {
          this.chatHistory.pop();
        }
      }"""

# handle encodings properly by using regex for catch
catch_pattern = r"\} catch \(error\) \{[\s\S]*?kiểm tra lại kết nối nhé!'\);\s*\}"
js = re.sub(catch_pattern, new_catch, js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("avatar.js updated with detailed error reporting and systemInstruction fix!")
