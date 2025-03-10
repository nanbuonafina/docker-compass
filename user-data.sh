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
