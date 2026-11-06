#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

for required in server.js package.json deploy-manifest.json; do
  if [[ ! -f "$required" ]]; then
    echo "ERRO: arquivo obrigatório não encontrado: $required" >&2
    exit 1
  fi
done

if [[ ! -d public ]]; then
  echo "ERRO: pasta public/ não encontrada." >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  echo "ERRO: node_modules/ não encontrado. Execute npm ci antes." >&2
  exit 1
fi

if [[ ! -d node_modules/mysql2 || ! -d node_modules/express || ! -d node_modules/dotenv ]]; then
  echo "ERRO: dependências do servidor incompletas. Confira package-lock.json e execute npm ci." >&2
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

echo "Pacote Amplify criado em: $PROJECT_DIR/.amplify-hosting"
