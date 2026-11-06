
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

rm -rf .amplify-hosting

mkdir -p .amplify-hosting/compute/default
mkdir -p .amplify-hosting/static

cp server.js .amplify-hosting/compute/default/
cp -R node_modules .amplify-hosting/compute/default/

cp -R public/. .amplify-hosting/static/

mkdir -p .amplify-hosting/compute/default/public
cp -R public/. .amplify-hosting/compute/default/public/

cp deploy-manifest.json .amplify-hosting/
