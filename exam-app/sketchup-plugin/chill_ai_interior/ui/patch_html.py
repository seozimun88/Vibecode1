import sys

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the old tab-chat
old_chat = """            <!-- 4. CHAT TAB -->
            <div class="tab-pane" id="tab-chat" style="display:none; height: 100%;">
               <div class="chat-messages" id="chat-messages" style="height: 120px; overflow-y:auto; font-size:12px;">
                 <div class="chat-bubble bot">"Chào chỉ huy!"</div>
               </div>
               <div class="chat-input-row" style="display:flex; margin-top:5px;">
                 <input type="text" id="chat-input" placeholder="Gõ lệnh..." style="flex:1;">
                 <button id="btn-send-chat" class="btn-game-tool">Gửi</button>
               </div>
            </div>"""

if old_chat in content:
    content = content.replace(old_chat, "")
elif 'id="tab-chat"' in content:
    # manual parse if exact match fails
    start = content.find('<!-- 4. CHAT TAB -->')
    end = content.find('<!-- 5. MARKET TAB -->')
    if start != -1 and end != -1:
        content = content[:start] + content[end:]


# Insert the new chat tab right after <div class="game-tab-content">
new_chat = """            <!-- 1. CHAT TAB (Moved to front) -->
            <div class="tab-pane active" id="tab-chat" style="display:flex; flex-direction:column; height: 100%;">
               <div class="chat-messages" id="chat-messages" style="flex:1; overflow-y:auto; font-size:12px; margin-bottom: 5px; padding-right: 5px;">
                 <div class="chat-bubble bot">"Xin chào! Mình là Lyly, trợ lý AI của bạn. Hãy nói cho mình biết bạn cần vẽ gì, hoặc kéo thả 1 tấm ảnh vào ô trống nhé!"</div>
               </div>
               <div class="chat-input-row" style="display:flex; gap: 5px; margin-top: auto;">
                 <input type="text" id="chat-input" placeholder="Yêu cầu AI..." style="flex:1; padding: 6px; background: rgba(0,0,0,0.6); border: 1px solid #4a5568; color: white; border-radius: 4px;">
                 <button id="btn-send-chat" class="btn-game-sys">Gửi</button>
               </div>
            </div>\n"""

# Change scan tab to not be active
content = content.replace('<div class="tab-pane active" id="tab-scan">', '<div class="tab-pane" id="tab-scan" style="display:none;">')

content = content.replace('<div class="game-tab-content">\n', '<div class="game-tab-content">\n' + new_chat)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("index.html patched!")
