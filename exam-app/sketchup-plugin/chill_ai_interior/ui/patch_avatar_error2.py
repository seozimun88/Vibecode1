import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Replace the throw Error('API Error') safely using regex
bad_fetch = r"if \(!res\.ok\) \{\s*throw new Error\('API Error'\);\s*\}\s*const data = await res\.json\(\);"
good_fetch = """const data = await res.json();
        
        if (!res.ok) {
          const errMsg = data.error ? data.error.message : 'Unknown API Error';
          throw new Error(errMsg);
        }"""

js = re.sub(bad_fetch, good_fetch, js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("avatar.js updated to parse API Error message properly!")
