#!/bin/bash

set -xe  # Ativa debug para ver erros no log

# Atualiza pacotes do sistema
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala dependências necessárias
sudo apt-get install -y docker.io git mysql-client binutils rustc cargo pkg-config libssl-dev unzip nfs-common rpcbind jq

# Instalar AWS CLI (se ainda não estiver instalado)
if ! command -v aws &> /dev/null; then
    echo "AWS CLI não encontrado. Instalando..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Instalar Amazon CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Ativar serviços necessários para NFS
sudo systemctl unmask nfs-client.target
sudo systemctl enable --now nfs-client.target
sudo systemctl enable --now rpcbind

# Criar diretório do EFS
sudo mkdir -p /mnt/efs

# Definir variáveis do EFS
EFS_ID="fs-XXXXXXXX"
REGION="sa-east-1"

# Montar o EFS
sudo mount -t nfs4 -o nfsvers=4.1,tcp ${EFS_ID}.efs.${REGION}.amazonaws.com:/ /mnt/efs

# Adicionar montagem ao /etc/fstab para persistência após reboot
echo "${EFS_ID}.efs.${REGION}.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Adicionar usuário ao grupo docker
sudo systemctl enable --now docker
sudo groupadd docker || true
sudo usermod -aG docker ubuntu

# Criar diretório do WordPress
PROJETO_DIR="/mnt/efs/wordpress"
sudo mkdir -p $PROJETO_DIR
sudo chmod -R 777 $PROJETO_DIR
cd $PROJETO_DIR

# Recuperar o segredo usando AWS Secrets Manager
echo "Aguardando AWS Secrets Manager..."
while ! aws secretsmanager get-secret-value --secret-id WordPressDBSecret --query SecretString --output text > /dev/null 2>&1; do
  echo "AWS Secrets Manager ainda não está pronto. Tentando novamente em 5 segundos..."
  sleep 5
done

# Buscar credenciais do banco de dados do AWS Secrets Manager e armazenar no .env
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id WordPressDBSecret --query SecretString --output text)
echo "WORDPRESS_DB_HOST=$(echo $DB_SECRET | jq -r '.WORDPRESS_DB_HOST')" | sudo tee /mnt/efs/wordpress/.env
echo "WORDPRESS_DB_USER=$(echo $DB_SECRET | jq -r '.WORDPRESS_DB_USER')" | sudo tee -a /mnt/efs/wordpress/.env
echo "WORDPRESS_DB_PASSWORD=$(echo $DB_SECRET | jq -r '.WORDPRESS_DB_PASSWORD')" | sudo tee -a /mnt/efs/wordpress/.env
echo "WORDPRESS_DB_NAME=$(echo $DB_SECRET | jq -r '.WORDPRESS_DB_NAME')" | sudo tee -a /mnt/efs/wordpress/.env

# Criar docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<EOL
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    restart: always
    ports:
      - "80:80"
    env_file:
      - /mnt/efs/wordpress/.env
    volumes:
      - /mnt/efs/wordpress:/var/www/html
EOL

# Iniciar WordPress com Docker Compose
sudo docker-compose up -d

# Criar arquivo de Health Check
echo "Criando o arquivo healthcheck.php..."
sudo tee /mnt/efs/wordpress/healthcheck.php > /dev/null <<EOF
<?php
http_response_code(200);
header('Content-Type: application/json');
echo json_encode(["status" => "| OK |", "message" => "Health check passed! :)"]);
exit;
?>
EOF

# ============================
# Configuração do AWS CloudWatch
# ============================

# Criar diretório de configuração do CloudWatch Agent
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/bin/

# Criar arquivo JSON de configuração do CloudWatch
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "usage_idle",
          "usage_system",
          "usage_user"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "WordPressSysLog",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Iniciar o CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

echo "Script de inicialização concluído!"
