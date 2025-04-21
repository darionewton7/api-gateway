#!/bin/bash

# Script para testar a integração do gateway de pagamento

set -e

echo "Iniciando testes de integração do gateway de pagamento..."

# Diretório atual
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Instalar todas as dependências (incluindo as de desenvolvimento)
echo "Instalando dependências..."
npm install

# Executar os testes
echo "Executando testes..."
npm test

# Verificar se os testes foram bem-sucedidos
if [ $? -eq 0 ]; then
  echo "Testes de integração concluídos com sucesso!"
else
  echo "Falha nos testes de integração!"
  exit 1
fi
