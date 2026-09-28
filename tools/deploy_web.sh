#!/bin/sh
# Web版を書き出して gh-pages ブランチに上げる。 使い方: sh tools/deploy_web.sh
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/c/Godot/Godot_v4.7-stable_win64_console.exe}
REMOTE=$(git remote get-url origin)
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
touch build/web/.nojekyll
# ブラウザのキャッシュで古いゲームデータが読まれないよう、pck に版番号をつけて参照する
V=$(git rev-parse --short HEAD)-$(date +%s)
mv build/web/index.pck "build/web/index-$V.pck"
sed -i "s/\"executable\":\"index\"/\"executable\":\"index\",\"mainPack\":\"index-$V.pck\"/; s/\"index.pck\":/\"index-$V.pck\":/" build/web/index.html
grep -q "index-$V.pck" build/web/index.html || { echo "mainPack の書き換えに失敗"; exit 1; }
cd build/web
rm -rf .git
git init -q -b gh-pages
git add -A
git commit -q -m "Web版を更新 ($(git -C ../.. rev-parse --short HEAD))"
git push -f "$REMOTE" gh-pages
rm -rf .git
