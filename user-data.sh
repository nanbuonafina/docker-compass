# Script para Amazon Linux 2

#!/bin/bash

# Atualiza pacotes
yum update -y
amazon-linux-extras enable docker
yum install -y docker amazon-efs-utils nfs-utils

# Inicia e habilita o Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Configuração do EFS
file_system_id_1=fs-0e7d97feaeecdc0b2
efs_mount_point_1=/mnt/efs/fs1
mkdir -p "${efs_mount_point_1}"
test -f "/sbin/mount.efs" && echo "${file_system_id_1}:/ ${efs_mount_point_1} efs tls,_netdev" >> /etc/fstab || echo "${file_system_id_1}.efs.sa-east-1.amazonaws.com:/ ${efs_mount_point_1} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
mount -a -t efs,nfs4 defaults

# Criação do diretório do projeto
mkdir -p ~/wordpress && cd ~/wordpress

# Criação do arquivo docker-compose.yml
echo "version: '3.8'\nservices:\n  wordpress:\n    image: wordpress\n    container_name: wordpress\n    restart: always\n    ports:\n      - '80:80'\n    environment:\n      WORDPRESS_DB_HOST: YOURS\n      WORDPRESS_DB_USER: YOURS\n      WORDPRESS_DB_PASSWORD: YOURS\n      WORDPRESS_DB_NAME: YOURS\n    volumes:\n      - /mnt/efs:/var/www/html" > docker-compose.yml

# Sobe os containers
docker-compose up -d

# Aguarda o container WordPress estar ativo
echo "Aguardando o container WordPress iniciar..."
until sudo docker ps | grep -q "Up.*wordpress"; do
  echo "Verificando containers em execução..."
  sudo docker ps
  sleep 5
done
echo "Container WordPress iniciado!"

# Adiciona o arquivo healthcheck.php no contêiner WordPress
echo "Criando o arquivo healthcheck.php no contêiner WordPress..."
sudo docker exec -i wordpress bash -c "cat <<EOF > /var/www/html/healthcheck.php
<?php
http_response_code(200);
header('Content-Type: application/json');
echo json_encode([\"status\" => \"OK\", \"message\" => \"Health check passed\"]);
exit;
?>
EOF"


# Script para Ubuntu
#!/bin/bash

# Atualiza pacotes do sistema
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala dependências
sudo apt-get install -y docker.io git nfs-common mysql-client binutils rustc cargo pkg-config libssl-dev

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
sudo mount -t efs -o tls fs-05f3b208a4dfd0f56.efs.sa-east-1.amazonaws.com:/ /mnt/efs

# Adicionar montagem ao /etc/fstab para persistência
echo "fs-05f3b208a4dfd0f56.efs.sa-east-1.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Adicionar usuário ao grupo docker
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
      WORDPRESS_DB_HOST: YOUR-ENDPOINT
      WORDPRESS_DB_USER: YOUR-USER
      WORDPRESS_DB_PASSWORD: YOUR-PASS
      WORDPRESS_DB_NAME: YOUR-DB-NAME
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

echo "Instalação concluída!"
