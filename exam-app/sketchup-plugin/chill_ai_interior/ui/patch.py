import sys, re

with open('app.js', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. API modal buttons
code = code.replace("document.getElementById('btn-api-settings')", "document.getElementById('btn-open-api-modal')")

# 2. dropZone and fileInput
code = code.replace("const dropZone = document.getElementById('drop-zone');", "const dropZone = document.getElementById('drop-zone') || document.getElementById('btn-upload-trigger');")
code = code.replace("const fileInput = document.getElementById('file-input');", "const fileInput = document.getElementById('file-input') || document.getElementById('image-upload');")

# 3. Prevent crashing on drag events for btn-upload-trigger
code = code.replace("dropZone.addEventListener('dragover'", "if(dropZone) dropZone.addEventListener('dragover'")
code = code.replace("dropZone.addEventListener('dragleave'", "if(dropZone) dropZone.addEventListener('dragleave'")
code = code.replace("dropZone.addEventListener('drop'", "if(dropZone) dropZone.addEventListener('drop'")
code = code.replace("dropZone.addEventListener('click'", "if(dropZone) dropZone.addEventListener('click'")
code = code.replace("fileInput.addEventListener('change'", "if(fileInput) fileInput.addEventListener('change'")


# 3. cardDefault
code = code.replace("cardDefault.addEventListener", "if(cardDefault) cardDefault.addEventListener")
code = code.replace("cardCustom.addEventListener", "if(cardCustom) cardCustom.addEventListener")

# 4. sliders
code = code.replace("sliderLenX.addEventListener", "if(sliderLenX) sliderLenX.addEventListener")
code = code.replace("sliderLenZ.addEventListener", "if(sliderLenZ) sliderLenZ.addEventListener")

# 5. Buttons in initActionButtons and initCAMNesting
buttons = [
    'btn-build-3d', 'btn-generate-dc', 'btn-send-dc-to-su', 'btn-reset-cam', 'btn-toggle-wireframe',
    'btn-re-nest', 'btn-save-gcode', 'btn-copy-gcode', 'btn-send-chat', 'btn-open-projects', 'btn-close-projects', 'btn-new-project'
]
for btn in buttons:
    code = re.sub(
        r"document\.getElementById\('" + btn + r"'\)\.addEventListener", 
        f"document.getElementById('{btn}')?.addEventListener", 
        code
    )

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(code)
print('Patched app.js successfully!')
