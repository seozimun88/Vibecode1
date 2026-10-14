import sys

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

# The bad code injected looks like:
#       });
#     }
#     
#     // Page 2 Command Grid Hooks
#     document.getElementById('btn-hud-save-load')?.addEventListener('click', () => {
# ...
#       });
#   
#   sendToSketchUp(actionName, data) {

bad_block_start = js.find('// Page 2 Command Grid Hooks')
bad_block_end = js.find('sendToSketchUp(actionName, data) {')

if bad_block_start != -1 and bad_block_end != -1:
    bad_code = js[bad_block_start:bad_block_end].strip()
    
    # Remove it from its current location
    js = js[:bad_block_start] + js[bad_block_end:]
    
    # Now, find the end of initActionButtons()
    # It ends right before where we just were. Let's find "initActionButtons() {" and its matching brace.
    # Actually, we can just insert it right before the closing brace of initActionButtons.
    # The last thing in initActionButtons is btn-toggle-wireframe
    target = "if (this.viewer) this.viewer.toggleWireframe();\n      });"
    
    if target in js:
        js = js.replace(target, target + "\n\n      " + bad_code)
    else:
        print("Could not find target in initActionButtons")
else:
    print("Could not find bad block")

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("app.js syntax error fixed!")
