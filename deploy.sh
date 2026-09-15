#!/bin/bash
# Wigmore deploy: single self-contained index.html, commit and push.
# Usage: ./deploy.sh "commit message"
set -e
cd "$(dirname "$0")"
node --check <(python3 -c "
s=open('index.html').read()
print(s.split('<script>',1)[1].rsplit('</script>',1)[0])") > /dev/null && echo "js ok"
touch .nojekyll
git add -A
git -c user.name="dillingerstaffing" -c user.email="dillingerstaffing@users.noreply.github.com" \
  commit -q -m "${1:-Update site}" && git push -q origin master 2>/dev/null || git push -q origin main
echo "deployed"
