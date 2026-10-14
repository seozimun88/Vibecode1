import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Replace the fallbackCandidates loop with dynamic ListModels fetch
old_block = r"const fallbackCandidates = \[\];[\s\S]*?if \(!success\) \{[\s\S]*?throw new Error\(lastErrorMsg\);\s*\}"

new_block = """
        let targetModel = 'models/gemini-1.5-flash';
        let listErr = null;
        try {
            const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${window.app.geminiApiKey}`);
            const listData = await listRes.json().catch(() => null);
            if (listRes.ok && listData && listData.models) {
                const validModels = listData.models.filter(m => m.supportedGenerationMethods && m.supportedGenerationMethods.includes('generateContent'));
                
                if (validModels.length > 0) {
                    const userChoice = window.app.geminiModel ? `models/${window.app.geminiModel}`.replace('models/models/', 'models/') : '';
                    const hasUserChoice = validModels.find(m => m.name === userChoice);
                    
                    if (hasUserChoice) {
                        targetModel = userChoice;
                    } else {
                        const flash = validModels.find(m => m.name.includes('1.5-flash'));
                        const pro = validModels.find(m => m.name.includes('1.5-pro'));
                        targetModel = flash ? flash.name : (pro ? pro.name : validModels[0].name);
                    }
                } else {
                    listErr = "Tài khoản của bạn không có mô hình nào hỗ trợ chat (generateContent).";
                }
            } else {
                listErr = listData && listData.error ? listData.error.message : "API Key không hợp lệ hoặc lỗi mạng.";
            }
        } catch (e) {
            listErr = `Lỗi mạng khi tải danh sách AI: ${e.message}`;
        }

        if (listErr) {
            throw new Error(`Kiểm tra API: ${listErr}`);
        }

        const endpoint = `https://generativelanguage.googleapis.com/v1beta/${targetModel}:generateContent?key=${window.app.geminiApiKey}`;
        const res = await fetch(endpoint, {
             method: 'POST',
             headers: { 'Content-Type': 'application/json' },
             body: requestBody
        });
        
        const data = await res.json().catch(() => null);
        
        if (!res.ok) {
             throw new Error(data && data.error ? data.error.message : 'Lỗi gọi AI (Unknown)');
        }
"""

js = re.sub(old_block, new_block, js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("avatar.js updated with dynamic ListModels fallback!")
