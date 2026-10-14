import sys
import re

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

bad_block_start = js.find('// Page 2 Command Grid Hooks')
bad_block_end = js.find('sendToSketchUp(actionName, data) {')

if bad_block_start != -1 and bad_block_end != -1:
    bad_code = js[bad_block_start:bad_block_end].strip()
    js = js[:bad_block_start] + js[bad_block_end:]
    
    # Use regex to insert before the closing brace of initActionButtons
    # Find btn-toggle-wireframe event listener end
    js = re.sub(
        r"(document\.getElementById\('btn-toggle-wireframe'\)\?\.addEventListener\('click', \(\) => \{\s*if \(this\.viewer\) this\.viewer\.toggleWireframe\(\);\s*\}\);)",
        r"\1\n\n    " + bad_code,
        js
    )

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("app.js syntax error fixed properly!")
