#!/bin/bash

# Atualiza pacotes do sistema
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala dependências
sudo apt-get install -y docker.io git mysql-client binutils rustc cargo pkg-config libssl-dev mysql-client
sudo apt-get install -y nfs-common
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Instala e configura o EFS Utils
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
sudo apt-get install -y ./build/amazon-efs-utils*deb

# Criar diretório para o EFS
sudo mkdir -p /mnt/efs

# Configuração do EFS
EFS_ID="fs-05f3b208a4dfd0f56"
REGION="sa-east-1"

# Montar o EFS usando efs-utils
sudo mount -t nfs4 -o nfsvers=4.1,tcp ${EFS_ID}.efs.${REGION}.amazonaws.com:/ /mnt/efs
#sudo mount -t efs -o tls fs-05f3b208a4dfd0f56.efs.sa-east-1.amazonaws.com:/ /mnt/efs

# Adicionar montagem ao /etc/fstab para persistência
echo "fs-05f3b208a4dfd0f56.efs.sa-east-1.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Adicionar usuário ao grupo docker
sudo systemctl enable --now docker
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

# Criar diretório do WordPress
projeto=/mnt/efs/wordpress
sudo mkdir -p $projeto
sudo chmod -R 777 $projeto
cd $projeto

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
    environment:
      WORDPRESS_DB_HOST: wordpress-db.cx0yuyki0qpn.sa-east-1.rds.amazonaws.com
      WORDPRESS_DB_USER: fernanda
      WORDPRESS_DB_PASSWORD: COMPASS0fernandadb
      WORDPRESS_DB_NAME: wp
    volumes:
      - /mnt/efs/projeto:/var/www/html
EOL

# Iniciar WordPress com Docker Compose
sudo docker-compose up -d

# Criar arquivo de Health Check
echo "Criando o arquivo healthcheck.php..."
sudo tee /mnt/efs/projeto/healthcheck.php > /dev/null <<EOF
<?php
http_response_code(200);
header('Content-Type: application/json');
echo json_encode(["status" => "| OK |", "message" => "Health check passed! :)"]);
exit;
?>
EOF


if sudo docker exec -i wordpress ls /var/www/html/healthcheck.php > /dev/null 2>&1; then
  echo "Arquivo healthcheck.php criado!"
else
  echo "Falha ao criar o arquivo healthcheck.php."
fi

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


#Iniciar o CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

echo "Script de inicialização concluído!"
