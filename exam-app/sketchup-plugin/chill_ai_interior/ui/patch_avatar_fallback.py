import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Replace the single fetch with a fallback loop
old_fetch_pattern = r"const endpoint = `https://generativelanguage\.googleapis\.com/v1beta/models/\$\{window\.app\.geminiModel \|\| 'gemini-1\.5-flash-latest'\}:generateContent\?key=\$\{window\.app\.geminiApiKey\}`;[\s\S]*?const data = await res\.json\(\);\s*if \(!res\.ok\) \{[\s\S]*?throw new Error\(errMsg\);\s*\}"

new_fetch = """        const fallbackCandidates = [];
        if (window.app && window.app.geminiModel) {
            fallbackCandidates.push(`models/${window.app.geminiModel}`);
        }
        fallbackCandidates.push('models/gemini-1.5-flash');
        fallbackCandidates.push('models/gemini-1.5-pro');
        fallbackCandidates.push('models/gemini-1.5-flash-latest');
        fallbackCandidates.push('models/gemini-1.5-pro-latest');
        fallbackCandidates.push('models/gemini-pro');

        let res;
        let success = false;
        let lastErrorMsg = 'Unknown API Error';
        let data = null;

        for (const candidate of fallbackCandidates) {
           const endpoint = `https://generativelanguage.googleapis.com/v1beta/${candidate}:generateContent?key=${window.app.geminiApiKey}`;
           res = await fetch(endpoint, {
             method: 'POST',
             headers: { 'Content-Type': 'application/json' },
             body: requestBody
           });
           
           data = await res.json().catch(() => null);
           
           if (res.ok && data) {
             success = true;
             break;
           } else {
             if (data && data.error && data.error.message) {
                 lastErrorMsg = data.error.message;
                 // If the key is outright invalid, stop trying
                 if (lastErrorMsg.includes("API key not valid") || lastErrorMsg.includes("API_KEY_INVALID")) {
                     break;
                 }
             }
           }
        }

        if (!success) {
          throw new Error(lastErrorMsg);
        }"""

js = re.sub(old_fetch_pattern, new_fetch, js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("avatar.js updated to use model fallback loop!")
