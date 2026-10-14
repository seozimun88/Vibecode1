import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

request_body = """        const requestBody = JSON.stringify({
          systemInstruction: {
            parts: [{text: "Bạn là Lyly, nữ trợ lý ảo 2D của plugin Chill AI Interior trên phần mềm SketchUp. Bạn là một chuyên gia về thiết kế nội thất, gỗ công nghiệp MDF, sản xuất CNC, và nhân trắc học. Bạn nói chuyện dễ thương, thân thiện, và luôn gọi người dùng là 'Chỉ huy'. Câu trả lời của bạn phải ngắn gọn, súc tích (dưới 100 chữ) và mang tính tư vấn chuyên môn. Tránh dùng định dạng markdown quá phức tạp. Trả lời trực tiếp vào câu hỏi."}]
          },
          contents: this.chatHistory,
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 300
          }
        });
        
        const fallbackCandidates = [];"""

js = js.replace("        const fallbackCandidates = [];", request_body)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Restored requestBody in avatar.js!")
