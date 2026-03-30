import sys
with open(sys.argv[1]) as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if line.strip() == "": continue
    indent = len(line) - len(line.lstrip('\t'))
    if ' ' in line[:indent]:
        print(f"Space in indent line {i+1}: {line.repr()}")
