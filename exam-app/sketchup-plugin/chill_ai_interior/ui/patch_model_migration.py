import re

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Find where geminiModel is loaded from localStorage
# this.geminiModel = localStorage.getItem('chill_ai_gemini_model') || 'gemini-1.5-flash-latest';
# We will inject a migration script.
migration = """    this.geminiModel = localStorage.getItem('chill_ai_gemini_model') || 'gemini-1.5-flash-latest';
    if (this.geminiModel === 'gemini-1.5-flash') {
        this.geminiModel = 'gemini-1.5-flash-latest';
        localStorage.setItem('chill_ai_gemini_model', this.geminiModel);
    }
    if (this.geminiModel === 'gemini-1.5-pro') {
        this.geminiModel = 'gemini-1.5-pro-latest';
        localStorage.setItem('chill_ai_gemini_model', this.geminiModel);
    }
"""

js = re.sub(r"this\.geminiModel = localStorage\.getItem\('chill_ai_gemini_model'\) \|\| 'gemini-1\.5-flash-latest';\n", migration, js)

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Added localStorage migration for geminiModel!")
