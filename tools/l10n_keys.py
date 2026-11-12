"""Extrait les textes traduisibles du code Swift : appels L("…") et littéraux
passés directement aux vues SwiftUI qui les traduisent d'elles-mêmes."""
import re, sys, glob, json
AUTO = r'(?:Text|Button|Label|Toggle|Picker|Link|LabeledContent|Marker|NavigationLink|ContentUnavailableView|Section|Stepper|\.navigationTitle|\.accessibilityLabel|\.accessibilityValue|\.accessibilityHint|\.alert|\.confirmationDialog|\.value)'
LIT = r'"((?:[^"\\]|\\.)*)"'
def norm(s):
    s = re.sub(r'\\\((?:[^()]|\([^()]*\))*\)', '%@', s)   # interpolation → %@
    return s.replace('\\"', '"')
def keys(folder):
    found = {}
    for path in sorted(glob.glob(folder + '/**/*.swift', recursive=True)):
        src = open(path, encoding='utf-8').read()
        src = re.sub(r'#Preview\s*\{.*', '', src, flags=re.S)      # les aperçus ne sont pas livrés
        for line_no, line in enumerate(src.split('\n'), 1):
            if line.strip().startswith('//'): continue
            for m in re.finditer(r'\bL\(' + LIT + r'\)', line):
                found.setdefault(norm(m.group(1)), path + ':' + str(line_no))
            for m in re.finditer(AUTO + r'\(\s*' + LIT, line):
                found.setdefault(norm(m.group(1)), path + ':' + str(line_no))
            # premier argument sur la ligne suivante : ContentUnavailableView(\n "…"
        for m in re.finditer(r'(?:ContentUnavailableView)\(\s*\n\s*' + LIT, src):
            found.setdefault(norm(m.group(1)), path)
    return found
if __name__ == '__main__':
    for folder in sys.argv[1:]:
        ks = keys(folder)
        print('##', folder, len(ks))
        for k in sorted(ks): print(json.dumps(k, ensure_ascii=False))
