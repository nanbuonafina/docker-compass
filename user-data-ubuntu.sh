#!/bin/bash

# Atualiza pacotes do sistema
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala dependências
sudo apt-get install -y docker.io git nfs-common amazon-cloudwatch-agent mysql-client

# Inicia e habilita o Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Instala e configura o EFS Utils
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
sudo apt-get install -y ./build/amazon-efs-utils*deb
cd ..

# Criar diretório para o EFS
sudo mkdir -p /mnt/efs

# Configuração do EFS
EFS_ID="fs-XXXXXXXXX"
REGION="sa-east-1"

# Montar o EFS usando efs-utils
sudo mount -t efs -o tls ${EFS_ID}.efs.${REGION}.amazonaws.com:/ /mnt/efs

# Adicionar montagem ao /etc/fstab para persistência
echo "${EFS_ID}.efs.${REGION}.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Criar diretório do WordPress
PROJETO_DIR="/mnt/efs/wordpress"
sudo mkdir -p $PROJETO_DIR
sudo chmod -R 777 $PROJETO_DIR
cd $PROJETO_DIR

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
      WORDPRESS_DB_HOST: YOUR-ENDPOINT
      WORDPRESS_DB_USER: YOUR-USER
      WORDPRESS_DB_PASSWORD: YOUR-PASS
      WORDPRESS_DB_NAME: YOUR-DB-NAME
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
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

# ============================
# Finalização
# ============================

echo "Script de inicialização concluído!"
