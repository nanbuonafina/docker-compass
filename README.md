<h1 align="center">
    <img align="center" src="https://logospng.org/download/uol/logo-uol-icon-256.png" width="40" height="40" /> Compass UOL - DevSecOps
</h1>


## 📌 Descrição do Projeto

Este projeto tem como objetivo configurar e implantar uma aplicação **WordPress** dentro de um contêiner **Docker**, hospedado em uma instância **EC2 da AWS**, sendo monitorado com o **Cloud Watch** e a visualização das métricas em Dashboards. A infraestrutura é projetada para ser **escalável** e **segura**, utilizando recursos como **Amazon RDS, EFS, Load Balancer e Auto Scaling**.

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
🔹 **Auto Scaling**  
🔹 **Cloud Watch**  

---

# 📄 Documentação da Infraestrutura AWS para WordPress

## 📌 Passo 0: Configurar a VPC e a Rede na AWS
Antes de instalar o Docker e configurar as EC2, siga este passo a passo para criar uma VPC com sub-redes privadas, NAT Gateway, EFS e Load Balancer.

### 1️⃣ Criar a VPC
No AWS Console, vá para **VPC > Create VPC**

Preencha os dados:
- **Nome:** VPC-WordPress
- **IPv4 CIDR:** 10.0.0.0/16
- **IPv6 CIDR:** Nenhum (opcional)
- **Tenancy:** Default
- **Clique em Create VPC**

### 2️⃣ Criar Duas Sub-redes Privadas
Agora, criamos duas sub-redes privadas em diferentes zonas de disponibilidade.

#### ✔ Criar Sub-rede Privada 1
Vá para **VPC > Subnets > Create Subnet**
- Escolha a VPC criada
- **Nome:** Subnet-Privada-1
- **Zona de Disponibilidade:** Escolha uma AZ (ex: us-east-1a)
- **IPv4 CIDR:** 10.0.1.0/24
- **Clique em Create**

#### ✔ Criar Sub-rede Privada 2
Repita os passos acima:
- **Nome:** Subnet-Privada-2
- **Zona de Disponibilidade:** Escolha uma AZ diferente (ex: us-east-1b)
- **IPv4 CIDR:** 10.0.2.0/24
- **Crie a sub-rede**

### 3️⃣ Criar Duas Sub-rede Pública
Essas sub-redes serão usadas para o NAT Gateway e o Load Balancer.

Vá para **VPC > Subnets > Create Subnet**
- Escolha a VPC criada
- **Nome:** Subnet-Publica-1
- **Zona de Disponibilidade:** Pode ser qualquer uma
- **IPv4 CIDR:** 10.0.3.0/24
- **Clique em Create**

- **Nome:** Subnet-Publica-2
- **Zona de Disponibilidade:** Escolha uma AZ diferente da primeira
- **IPv4 CIDR:** 10.0.4.0/24
- **Crie a sub-rede**

### 4️⃣ Criar um Internet Gateway
O Internet Gateway permitirá que a sub-rede pública tenha acesso à internet.

Vá para **VPC > Internet Gateways > Create Internet Gateway**
- **Nome:** IGW-WordPress
- **Clique em Create**

Anexe à VPC:
- Vá até **"Actions" > "Attach to VPC"**
- Selecione a VPC criada
- Confirme

### 5️⃣ Criar um NAT Gateway para as Sub-redes Privadas
O NAT Gateway permitirá que as EC2 privadas acessem a internet, sem ficarem expostas.

Vá para **VPC > NAT Gateways > Create NAT Gateway**
- Escolha a **Sub-rede Pública** criada
- **Alocar um Elastic IP** (AWS cria um automaticamente)
- **Clique em Create NAT Gateway**

### 6️⃣ Configurar as Tabelas de Rotas
Agora, configuramos as rotas para cada sub-rede.

#### ✔ Editar Tabela de Rotas da Sub-rede Pública
- Vá para **VPC > Route Tables**
- Encontre a tabela de rotas da **Subnet Pública**
- Adicione uma nova rota:
  - **Destination:** 0.0.0.0/0
  - **Target:** Selecione o **Internet Gateway (IGW-WordPress)**
- **Salve as alterações**

#### ✔ Editar Tabela de Rotas das Sub-redes Privadas
- Vá para **Route Tables**
- Encontre a tabela de rotas da **Subnet Privada 1**
- Adicione uma nova rota:
  - **Destination:** 0.0.0.0/0
  - **Target:** Selecione o **NAT Gateway criado**
- **Repita para a Subnet Privada 2**

Agora, as EC2 privadas terão acesso à internet via NAT Gateway, mas não serão acessíveis externamente.

### 7️⃣ Criar Security Group para as EC2, EFS, RDS e Load Balancer 

| Security Group | Regras de Entrada | Regras de Saída |
|---------------|------------------|----------------|
| **WP-LB-SG** | HTTP e HTTPS -> 0.0.0.0/0 | All Traffic |
| **WP-EC2-SG** | HTTP e HTTPS -> WP-LB-SG <br> SSH -> Qualquer IPV4 (Somente para testes) | Padrão |
| **WP-RDS-SG** | MySQL -> WP-EC2-SG | Padrão |
| **WP-EFS-SG** | NFS -> WP-EC2-SG | Padrão |

---

## Criar um Elastic File System (EFS)
Vá para **EFS > Create File System**
- **Type:** Regional
- **Lifecycle Management:** None, None e None.    
- **Performance** Bursting
- **VPC:** VPC-wordpress
- **Subnets:** Selecione as subnets privadas
- **Clique em Create**

---

## Criar um Banco de Dados usando o Relational Database Service (RDS)
Como as EC2 do WordPress estão em subnets privadas, precisamos de uma EC2 pública para intermediá-las.

Vá para **RDS > Create Database**
- **Creation method:** Standard
- **Engine** MySQL
- **Template:** Free Tier
- **DB Identifier:** wordpress-db
- **Credentials:** Defina o master username e a sua senha
- **Instance Configuration:** db.t3.micro
- **Connectivity:** Não conecte com nenhuma instância EC2
- **VPC:** Selecione a VPC criada para o projeto `VPC-wordpress`
- **DB Subnet Group:** Crie um subnet group selecionando a VPC do projeto e selecione as subnets privadas.
- **Public Access:** No
- **Security Group:** WP-RDS-SG.
- **Additional configuration > Database Options > Initial Database Name:** Crie um nome inicial para a sua tabela, ele será usado no script do user-data.sh mais para frente.
- **Clique em Create Database**

---

## 📈 Configurando o Identity and Access Management (IAM)
Configurar o IAM para integrar o Cloud Watch com a instância EC2 rodando o Wordpress. 

Vá em **IAM** > **Roles** > Clique em **“Create Role”**

- Selecione **AWS Service** e escolha **EC2** como entidade confiável
- Anexe a política **“CloudWatchAgentServerPolicy”** para permitir que a instância envie métricas e logs
- Dê um nome a role, por exemplo “EC2-CloudWatchAgent-Role”
- Clique em **“Create Role”**

---

## 🔑 Criar uma Instância Bastion Host
Como as EC2 do WordPress estão em subnets privadas, precisamos de uma EC2 pública para intermediá-las.

Vá para **EC2 > Launch Instance**
- **AMI:** Ubuntu
- **Tipo:** t2.micro
- **Rede:** VPC-wordpress
- **Subnet:** Escolha uma subnet pública
- **Habilitar IP Público**
- **Security Group:** WP-EC2-SG.

## 🔑 Criar uma Instância EC2 rodando o WordPress
Agora, para configurar a instância com o Wordpress, faça as seguintes configurações:

Vá para **EC2 > Launch Instance**
- **AMI:** Ubuntu
- **Tipo:** t2.micro
- **Rede:** VPC-wordpress
- **Subnet:** Escolha uma subnet pública
- **Desabilitar IP Público**
- **Security Group:** WP-EC2-SG.
- Em **Advanced Details:**
    - **IAM Instance Profile:** Selecione o IAM criado anteriormente `EC2-CloudWatchAgent-Role`     
    - **Script user-data.sh:** Copie/Baixe o script no arquivo `user-data.sh` e cole/upload. 

### 🔹 Configurar o Security Group das Instâncias WordPress
No Security Group `WP-EC2-SG`, edite as regras de entrada:
- **SSH (22):** Permitir somente o IP do Bastion Host

---

## 🌐 Criando o Load Balancer

### 🔗 Escolhendo e Criando o Load Balancer
Neste projeto, utilizamos um **Application Load Balancer**.

Vá para **EC2 > Load Balancers > Create Load Balancer**
- Escolha **Application Load Balancer**
- **Nome:** WP-ALB
- **VPC:** VPC-wordpress
- **Subnets:** Escolha as subnets privadas
- **Security Group:** WP-LB-SG

### 🔥 Criando um Target Group
O Target Group define para onde o Load Balancer direciona o tráfego.

Vá para **EC2 > Target Groups > Create Target Group**
- **Tipo:** Instances
- **Protocolo:** HTTP
- **Porta:** 80
- **VPC:** VPC-wordpress
- **Clique em Create Target Group**

Após criar, associe as EC2 ao **Target Group**.

---

## 📈 Criando o Auto Scaling Group
O **Auto Scaling Group (ASG)** permite escalar automaticamente suas instâncias EC2.

Vá para **EC2 > Auto Scaling > Create Auto Scaling Group**

- **Nome:** wordpress-asg
- **Template:** Crie um template da instância EC2 rodando o Wordpress.
- **VPC** VPC-wordpress
- **Subnets** Selecione as duas subnets privadas
- **Load Balancer:** Adicione WP-ALB
- **Target Group:** Escolha o target group criado anteriormente
- **Definir capacidade mínima/máxima:**
  - **Min:** 1
  - **Max:** 3
  - **Desired:** 2
- **Política de Auto Scaling:** Ajustar com base no uso de CPU

---

### 🔗 Conectar-se às Instâncias via Bastion Host
Acesse o Bastion Host via SSH:
```bash
ssh -i "minha-chave.pem" ec2-user@IP-PUBLICO-BASTION
```
E, a partir dele, conecte-se às EC2 privadas:
```bash
ssh -i "minha-chave.pem" ec2-user@IP-PRIVADO-EC2
```
---
🚀 Agora sua infraestrutura está pronta e escalável! 🎯
---

## 🎯 Conclusão

Agora sua aplicação **WordPress** está rodando em um ambiente **seguro**, **escalável** e **gerenciado na AWS**, utilizando **Docker, RDS, Load Balancer e Auto Scaling** para garantir desempenho e disponibilidade. 🚀

---

## 📞 Contato

👩‍💻 **Autor:** Maria Fernanda Trevizane Buonafina  
📩 **E-mail:** [maria.fernanda.ufdc@gmail.com](mailto:maria.fernanda.ufdc@gmail.com)  

🚀 *Happy coding!* 🎉
