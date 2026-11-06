#!/usr/bin/env bash
set -euo pipefail

for required in server.js package.json deploy-manifest.json; do
  if [[ ! -f "$required" ]]; then
    echo "ERRO: arquivo não encontrado: $required" >&2
    exit 1
  fi
done

if [[ ! -d public || ! -d node_modules ]]; then
  echo "ERRO: public ou node_modules não encontrado." >&2
  exit 1
fi

rm -rf .amplify-hosting

mkdir -p .amplify-hosting/compute/default/public
mkdir -p .amplify-hosting/static

cp server.js .amplify-hosting/compute/default/server.js
cp -R node_modules .amplify-hosting/compute/default/node_modules
cp -R public/. .amplify-hosting/compute/default/public/
cp -R public/. .amplify-hosting/static/
cp deploy-manifest.json .amplify-hosting/deploy-manifest.json

echo "Pacote Amplify criado com sucesso!"
