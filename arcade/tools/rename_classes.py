#!/usr/bin/env python3
"""Rename global class names (and autoload names) inside one imported game, so they
can't clash with the arcade's or other games' names.

Usage: python3 -I tools/rename_classes.py <game_dir> Old=New [Old=New ...]

In .gd files a name is replaced where it is code: not inside string literals or
comments, and not after $ or % (node paths keep their node names). In scenes and
resources only `script_class="Old"` and `Array[Old]` change.
"""
import os, re, sys

root, pairs = sys.argv[1], [a.split("=", 1) for a in sys.argv[2:]]
STR = re.compile(r'''("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|#.*$)''', re.M)


NODE_PATH = re.compile(r'[$%][\w/%.]+')  # $Node/Child and %Unique paths keep node names


def code_sub(text, old, new):
    word = re.compile(r'(?<![\w$%@"\'/])' + re.escape(old) + r'\b')
    out, last = [], 0
    for m in STR.finditer(text):
        out.append(word.sub(new, text[last:m.start()]))
        out.append(m.group(0))
        last = m.end()
    out.append(word.sub(new, text[last:]))
    return "".join(out)


n = 0
for dp, _, fs in os.walk(root):
    for f in fs:
        p = os.path.join(dp, f)
        if not f.endswith((".gd", ".tscn", ".tres")):
            continue
        try:
            t = open(p, encoding="utf-8").read()
        except UnicodeDecodeError:
            continue
        orig = t
        for old, new in pairs:
            if f.endswith(".gd"):
                t = code_sub(t, old, new)
            else:
                t = t.replace('script_class="%s"' % old, 'script_class="%s"' % new)
                t = re.sub(r'Array\[%s\]' % re.escape(old), 'Array[%s]' % new, t)
        if t != orig:
            open(p, "w", encoding="utf-8").write(t)
            n += 1
print("changed", n, "files")
