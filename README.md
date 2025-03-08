<h1 align="center">
    <img align="center" src="https://logospng.org/download/uol/logo-uol-icon-256.png" width="40" height="40" /> Compass UOL - DevSecOps
</h1>


## 📌 Descrição do Projeto

Este projeto tem como objetivo configurar e implantar uma aplicação **WordPress** dentro de um contêiner **Docker**, hospedado em uma instância **EC2 da AWS**. A infraestrutura é projetada para ser **escalável** e **segura**, utilizando recursos como **Amazon RDS, EFS e Load Balancer**.

---

## 🏗️ Arquitetura

A arquitetura do projeto segue a tipologia abaixo:

![Arquitetura](arquitetura.png)

---

## 🛠️ Tecnologias Utilizadas

🔹 **WSL Ubuntu**  
🔹 **Docker**  
🔹 **EC2 com Amazon Linux 2**  
🔹 **RDS MySQL**  
🔹 **EFS para armazenamento**  
🔹 **Load Balancer**  

---

## ⚙️ Configuração da Infraestrutura

### 🏢 Criando e Configurando a VPC

1️⃣ **Crie uma nova VPC** e configure conforme as opções abaixo:
   - **Resources to create** → VPC and more
   - **Name** → `wp-project-vpc`
   - **IPv4 CIDR block** → `10.0.0.0/24`
   - **Tenancy** → `Default`
   - **Availability Zones** → `2`
   - **Public subnets** → `2`
   - **Private subnets** → `2`
   - **NAT Gateway** → `None`
   - **VPC Endpoint** → `S3 Gateway`

---

### 🔐 Criando e Configurando os Security Groups

Criamos **3 Security Groups**:

#### ✅ EC2 Security Group
- **Nome:** `ec2-server-SG`
- **Inbound rules:**
  - 🔓 HTTP | Source: `0.0.0.0/0`
  - 🔐 SSH | Source `MyIP`

#### ✅ EFS Security Group
- **Nome:** `wp-efs-SG`
- **Inbound rules:**
  - 📂 NFS | Source: `Security Group da EC2`

#### ✅ RDS Security Group
- **Nome:** `wp-database-SG`
- **Inbound rules:**
  - 🗄️ MySQL/Aurora | Source: `Security Group da EC2`

---

## 🚀 Configurando o Docker na EC2

1️⃣ Verifique a versão instalada:
```bash
docker --version
```

2️⃣ Crie o diretório do projeto:
```bash
mkdir -p ~/wordpress && cd ~/wordpress
```

3️⃣ Crie o arquivo `docker-compose.yml`:
```bash
nano docker-compose.yml
```

4️⃣ Adicione o seguinte conteúdo:
```yaml
version: '3.8'
services:
  wordpress:
    image: wordpress
    container_name: wordpress
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: SEU_ENDPOINT_RDS
      WORDPRESS_DB_USER: SEU_USER
      WORDPRESS_DB_PASSWORD: SUA_SENHA
      WORDPRESS_DB_NAME: wp_project
    volumes:
      - /mnt/efs:/var/www/html
```

5️⃣ Rode os containers:
```bash
docker-compose up -d
```

6️⃣ Verifique os logs:
```bash
docker logs -f wordpress
```

---

## 🌍 Criando o Load Balancer

1️⃣ No **AWS Console**, acesse **EC2** → **Load Balancers** → **Criar Load Balancer**.  
2️⃣ Escolha **Application Load Balancer** e configure:
   - **Nome:** `wordpress-alb`
   - **Scheme:** `Internet-facing`
   - **Listeners:** `Porta 80 (HTTP)`
   - **VPC:** `wp-project-vpc`
   - **Subnets:** `Subnets públicas`

3️⃣ **Security Group:**
   - ✅ Permitir **80 (HTTP)** de **qualquer lugar (0.0.0.0/0)**
   - ❌ Remova acesso direto à EC2

4️⃣ **Criar Target Group:**
   - **Nome:** `wordpress-target`
   - **Tipo:** `EC2 Instances`
   - **Health Check:** `/wp-admin/install.php`
   - Adicionar a **instância EC2**

---

## 🔒 Bloqueando Acesso Direto à EC2

1️⃣ No **Security Groups** da EC2, altere a regra de entrada da porta 80 (HTTP) para permitir apenas o **Security Group do Load Balancer**.  
2️⃣ Teste tentando acessar o IP da EC2 (`http://SEU_IP_EC2`). Deve estar bloqueado.  
3️⃣ O acesso ao WordPress deve ser feito apenas pelo Load Balancer (`http://SEU_LOAD_BALANCER_DNS`).  

---

## 🎯 Conclusão

Agora sua aplicação **WordPress** está rodando em um ambiente **seguro**, **escalável** e **gerenciado na AWS**, utilizando **Docker, RDS e Load Balancer** para garantir desempenho e disponibilidade. 🚀

---

## 📞 Contato

👩‍💻 **Autor:** Maria Fernanda Trevizane Buonafina  
📩 **E-mail:** [maria.fernanda.ufdc@gmail.com](mailto:maria.fernanda.ufdc@gmail.com)  

🚀 *Happy coding!* 🎉
