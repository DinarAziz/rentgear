#!/usr/bin/env bash
# Builds the web release with cache-busted file names, then refreshes ../webapp/
# and ../rentgear-web.zip.
#
# Why: the site sits behind Cloudflare, which caches main.dart.js per
# Accept-Encoding for hours. Without a new file name, browsers kept getting the
# previous build after a deploy. main.dart.js gets a content hash in its name,
# and index.html (not cached by Cloudflare) loads flutter_bootstrap.js with a
# ?v=<hash> query, so every deploy is picked up right away.
set -euo pipefail

cd "$(dirname "$0")/.."
# flutter build keeps old files, so a previous main.dart.<hash>.js would ship too.
rm -rf build/web
flutter build web --release

out=build/web
hash=$(shasum "$out/main.dart.js" | cut -c1-10)
mv "$out/main.dart.js" "$out/main.dart.$hash.js"
sed -i '' "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.$hash.js\"|" "$out/flutter_bootstrap.js"
sed -i '' "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=$hash\"|" "$out/index.html"
grep -q "main.dart.$hash.js" "$out/flutter_bootstrap.js" || { echo "mainJsPath not rewritten" >&2; exit 1; }
grep -q "flutter_bootstrap.js?v=$hash" "$out/index.html" || { echo "index.html not rewritten" >&2; exit 1; }

rsync -a --delete --exclude README.md "$out/" ../webapp/
rm -f ../rentgear-web.zip
(cd "$out" && zip -qr ../../../rentgear-web.zip .)
echo "Built main.dart.$hash.js; updated ../webapp/ and ../rentgear-web.zip"
