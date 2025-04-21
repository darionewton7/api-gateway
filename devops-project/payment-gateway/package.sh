#!/bin/bash

# Script para empacotar a função Lambda do gateway de pagamento

set -e

echo "Iniciando empacotamento da função Lambda do gateway de pagamento..."

# Diretório atual
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Instalar dependências
echo "Instalando dependências..."
npm install --production

# Criar o arquivo zip
echo "Criando arquivo lambda_function.zip..."
zip -r lambda_function.zip index.js node_modules package.json

echo "Empacotamento concluído com sucesso!"
echo "Arquivo lambda_function.zip criado em: $DIR"
