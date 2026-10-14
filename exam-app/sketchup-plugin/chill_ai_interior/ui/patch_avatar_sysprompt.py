import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Replace the requestBody block
old_request = r"const requestBody = JSON\.stringify\(\{[\s\S]*?systemInstruction: \{[\s\S]*?contents: this\.chatHistory,[\s\S]*?maxOutputTokens: 300\s*\}\s*\}\);"

new_request = """const sysInstruction = "Bạn là Lyly, nữ trợ lý ảo 2D của plugin Chill AI Interior trên phần mềm SketchUp. Bạn là một chuyên gia về thiết kế nội thất, gỗ công nghiệp MDF, sản xuất CNC, và nhân trắc học. Bạn nói chuyện dễ thương, thân thiện, và luôn gọi người dùng là 'Chỉ huy'. Câu trả lời của bạn phải ngắn gọn, súc tích (dưới 100 chữ) và mang tính tư vấn chuyên môn. Tránh dùng định dạng markdown quá phức tạp. Trả lời trực tiếp vào câu hỏi.";

        let clonedHistory = JSON.parse(JSON.stringify(this.chatHistory));
        if (clonedHistory.length > 0 && clonedHistory[0].role === 'user') {
            clonedHistory[0].parts[0].text = `[HƯỚNG DẪN HỆ THỐNG: ${sysInstruction}]\\n\\nCâu hỏi của người dùng: ${clonedHistory[0].parts[0].text}`;
        }

        const requestBody = JSON.stringify({
          contents: clonedHistory,
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 300
          }
        });"""

js = re.sub(old_request, new_request, js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("avatar.js updated to remove systemInstruction and use prompt injection!")
