import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Current logic:
# let targetModel = 'models/gemini-3.8-flash';
# let listErr = null;
# try {
#     const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${window.app.geminiApiKey}`);
# ...

# We want to change it so we use a cached this.targetModel if it exists.

fast_model_logic = """
          let targetModel = this.targetModelCache;
          let listErr = null;
          
          if (!targetModel) {
              try {
                  const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${window.app.geminiApiKey}`);
                  const listData = await listRes.json().catch(() => null);
                  if (listRes.ok && listData && listData.models) {
                      const validModels = listData.models.filter(m => m.supportedGenerationMethods && m.supportedGenerationMethods.includes("generateContent"));
                      const userChoice = window.app.geminiModel;
                      const hasUserChoice = validModels.some(m => m.name === `models/${userChoice}` || m.name === userChoice);
                      
                      if (hasUserChoice) {
                          targetModel = userChoice.startsWith('models/') ? userChoice : `models/${userChoice}`;
                      } else {
                          const flash38 = validModels.find(m => m.name.includes('3.8-flash'));
                          const pro38 = validModels.find(m => m.name.includes('3.8-pro'));
                          const anyFlash = validModels.find(m => m.name.includes('flash') && !m.name.includes('2.5') && !m.name.includes('1.5'));
                          const fallback = validModels.length > 0 ? validModels[validModels.length - 1].name : 'models/gemini-3.8-flash';
                          targetModel = flash38 ? flash38.name : (pro38 ? pro38.name : (anyFlash ? anyFlash.name : fallback));
                      }
                  } else {
                      targetModel = 'models/gemini-3.8-flash';
                  }
                  this.targetModelCache = targetModel;
              } catch (e) {
                  console.error("List models failed", e);
                  targetModel = window.app.geminiModel ? (window.app.geminiModel.startsWith('models/') ? window.app.geminiModel : `models/${window.app.geminiModel}`) : 'models/gemini-3.8-flash';
                  this.targetModelCache = targetModel;
              }
          }
"""

# Regex to find the existing block
old_logic_pattern = r"let targetModel = 'models/gemini-3\.8-flash';\s*let listErr = null;\s*try\s*\{[\s\S]*?\} catch \(e\) \{\s*console\.error\(\"List models failed\", e\);\s*targetModel = window\.app\.geminiModel\s*\?\s*\(window\.app\.geminiModel\.startsWith\('models/'\) \? window\.app\.geminiModel : `models/\$\{window\.app\.geminiModel\}`\) : 'models/gemini-3\.8-flash';\s*listErr = e;\s*\}"

js = re.sub(old_logic_pattern, fast_model_logic.strip(), js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Properly patched avatar.js to cache targetModel!")
