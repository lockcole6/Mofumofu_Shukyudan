#!/bin/sh
# Web版を書き出して gh-pages ブランチに上げる。 使い方: sh tools/deploy_web.sh
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/c/Godot/Godot_v4.7-stable_win64_console.exe}
REMOTE=$(git remote get-url origin)
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
touch build/web/.nojekyll
cd build/web
rm -rf .git
git init -q -b gh-pages
git add -A
git commit -q -m "Web版を更新 ($(git -C ../.. rev-parse --short HEAD))"
git push -f "$REMOTE" gh-pages
rm -rf .git
