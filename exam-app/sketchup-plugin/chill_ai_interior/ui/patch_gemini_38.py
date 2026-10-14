import re

# 1. Update index.html
with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Replace all select options with 3.8
old_select = r'<select id="input-gemini-model"[\s\S]*?</select>'
new_select = """<select id="input-gemini-model" style="width: 100%; padding: 8px; background: rgba(0,0,0,0.6); color: #fbbf24; border: 1px solid #4a5568; border-radius: 4px; text-align: center; font-family: inherit;">
            <option value="gemini-3.8-flash">Gemini 3.8 Flash (Tốc độ siêu tốc)</option>
            <option value="gemini-3.8-pro">Gemini 3.8 Pro (Suy luận sâu)</option>
          </select>"""
html = re.sub(old_select, new_select, html)
with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

# 2. Update app.js migration
with open('app.js', 'r', encoding='utf-8') as f:
    app_js = f.read()

old_migration = r"this\.geminiModel = localStorage\.getItem\('chill_ai_gemini_model'\) \|\| 'gemini-1\.5-flash-latest';[\s\S]*?localStorage\.setItem\('chill_ai_gemini_model', this\.geminiModel\);\s*\}"
new_migration = """this.geminiModel = localStorage.getItem('chill_ai_gemini_model') || 'gemini-3.8-flash';
    if (this.geminiModel.includes('1.5') || this.geminiModel.includes('2.5')) {
        this.geminiModel = this.geminiModel.includes('pro') ? 'gemini-3.8-pro' : 'gemini-3.8-flash';
        localStorage.setItem('chill_ai_gemini_model', this.geminiModel);
    }"""
app_js = re.sub(old_migration, new_migration, app_js)
with open('app.js', 'w', encoding='utf-8') as f:
    f.write(app_js)

# 3. Update avatar.js fallback prioritization
with open('avatar.js', 'r', encoding='utf-8') as f:
    avatar_js = f.read()

old_avatar_logic = r"const flash = validModels\.find\(m => m\.name\.includes\('1\.5-flash'\)\);[\s\S]*?targetModel = flash \? flash\.name : \(pro \? pro\.name : validModels\[0\]\.name\);"
new_avatar_logic = """const flash38 = validModels.find(m => m.name.includes('3.8-flash'));
                        const pro38 = validModels.find(m => m.name.includes('3.8-pro'));
                        const anyFlash = validModels.find(m => m.name.includes('flash') && !m.name.includes('2.5') && !m.name.includes('1.5'));
                        targetModel = flash38 ? flash38.name : (pro38 ? pro38.name : (anyFlash ? anyFlash.name : validModels[validModels.length - 1].name));"""
avatar_js = re.sub(old_avatar_logic, new_avatar_logic, avatar_js)

# Replace 'models/gemini-1.5-flash' default with 'models/gemini-3.8-flash'
avatar_js = avatar_js.replace("'models/gemini-1.5-flash'", "'models/gemini-3.8-flash'")

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(avatar_js)

print("Updated everything to Gemini 3.8!")
