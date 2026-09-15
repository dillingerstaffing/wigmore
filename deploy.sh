#!/bin/bash
# Wigmore deploy: single self-contained index.html, commit and push.
# Usage: ./deploy.sh "commit message"
set -e
cd "$(dirname "$0")"
BV="v$(date +%Y%m%d-%H%M)"
python3 - "$BV" <<'PYBV'
import sys, re
bv = sys.argv[1]
s = open('index.html').read()
s2, n = re.subn(r'<meta name="build-version" content="[^"]*">',
                '<meta name="build-version" content="'+bv+'">', s, count=1)
assert n == 1, "version meta anchor missing"
open('index.html','w').write(s2)
print("build-version:", bv)
PYBV
python3 - <<'PYJS'
import re
s = open('index.html').read()
blocks = re.findall(r'<script>(.*?)</script>', s, re.S)
assert blocks, "no plain script blocks found"
assert len(blocks[0]) > 40000, "main script block suspiciously short"
for i, js in enumerate(blocks):
    open('/tmp/wigmore-jscheck-%d.js' % i, 'w').write(js)
print(len(blocks), "script blocks extracted")
PYJS
for f in /tmp/wigmore-jscheck-*.js; do node --check "$f" || { echo "JS SYNTAX CHECK FAILED ($f), deploy blocked" >&2; exit 1; }; done
echo "js ok"
touch .nojekyll
git add -A
git -c user.name="dillingerstaffing" -c user.email="dillingerstaffing@users.noreply.github.com" \
  commit -q -m "${1:-Update site}" && git push -q origin master 2>/dev/null || git push -q origin main
echo "deployed"
