import sys

with open('app.js', 'r', encoding='utf-8') as f:
    code = f.read()

# Fix initProjects
code = code.replace("listEl.innerHTML = '';", "if(listEl) listEl.innerHTML = '';")
code = code.replace("listEl.appendChild(li);", "if(listEl) listEl.appendChild(li);")

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(code)
print('Patched initProjects successfully!')
