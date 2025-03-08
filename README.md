<h1 align="center">
    <img align="center" src="https://logospng.org/download/uol/logo-uol-icon-256.png" width="30" height="30" /> Compass UOL - DevSecOps
</h1>

## Descrição do Projeto

Este projeto tem como objetivo configurar e implantar uma aplicação WordPress dentro de um contêiner Docker, hospedado em uma instância EC2 da AWS. A infraestrutura é projetada para ser escalável e segura, utilizando recursos como Amazon RDS, EFS e Load Balancer.

## Arquitetura

A arquitetura do projeto segue a tipologia abaixo:
![image.png](arquitetura.png)

## Tecnologias Utilizadas

- WSL Ubuntu
- Docker
- EC2 com Amazon Linux 2
- RDS MySQL
- EFS para armazenamento
- Load Balancer

## Configuração da Infraestrutura

### Criando e Configurando a VPC

1. Crie uma nova VPC e configure conforme as opções abaixo:
    - **Resources to create** → VPC and more
    - **Name** → wp-project-vpc
    - **IPv4 CIDR block** → 10.0.0.0/24
    - **Tenancy** → Default
    - **Availability Zones** → 2
    - **Public subnets** → 2
    - **Private subnets** → 2
    - **NAT Gateway** → None
    - **VPC Endpoint** → S3 Gateway

### Criando e Configurando os Security Groups

Criamos 3 Security Groups:

#### EC2 Security Group

- **Nome:** ec2-server-SG
- **Inbound rules:**
  - HTTP | Source: `0.0.0.0/0`
  - SSH | Source `MyIP`

#### EFS Security Group

- **Nome:** wp-efs-SG
- **Inbound rules:**
  - NFS | Source: `Security Group da EC2`

#### RDS Security Group

- **Nome:** wp-database-SG
- **Inbound rules:**
  - MySQL/Aurora | Source: `Security Group da EC2`

### Criando e Configurando o EFS

1. **Name** → wp-storage-efs
2. **VPC** → wp-project-vpc
3. **Configuração:**
    - File System Type → Regional
    - Performance mode → General Purpose
    - Throughput mode → Elastic
4. **Network:**
    - Selecione as subnets públicas
    - Associe ao **Security Group do EFS** (wp-efs-SG)

### Criando e Configurando o RDS

1. **Database creation** → Standard create
2. **Engine type** → MySQL
3. **Templates** → Free Tier
4. **Avaliability** → Single AZ
5. **DB cluster identifier** → wp_project
6. **Instance configuration** → db.t3.micro
7. **Security Group** → wp-database-SG
8. **Public access** → No

### Criando e Configurando a Instância EC2

1. **Application and OS** → Amazon Linux
2. **Instance Type** → t2.micro
3. **Key Pair** → Crie e selecione uma chave para acesso SSH
4. **Network:**
    - **VPC** → wp-project-vpc
    - **Subnet** → Subnet pública 1a
    - **Security Group** → ec2-server-SG
5. **Storage:**
    - Selecione o **EFS** criado anteriormente
    - Mantenha o **Mount point padrão**
6. **User Data Script:**
    - Configure a instância para instalar e configurar automaticamente o Docker e o EFS.

## Conectando-se via SSH

```bash
chmod 400 suachave.pem
ssh -i suachave.pem ec2-user@SEU_IP_EC2
```

## Configurando o Docker

1. Verifique a versão instalada:

    ```bash
    docker --version
    ```

2. Crie o diretório do projeto:

    ```bash
    mkdir -p ~/wordpress && cd ~/wordpress
    ```

3. Crie o arquivo `docker-compose.yml`:

    ```bash
    nano docker-compose.yml
    ```

4. Adicione o seguinte conteúdo:

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

5. Rode os containers:

    ```bash
    docker-compose up -d
    ```

6. Verifique os logs:

    ```bash
    docker logs -f wordpress
    ```

## Criando o Load Balancer

1. No **AWS Console**, acesse **EC2** → **Load Balancers** → **Criar Load Balancer**.
2. Escolha **Application Load Balancer** e configure:
    - **Nome:** wordpress-alb
    - **Scheme:** Internet-facing
    - **Listeners:** Porta 80 (HTTP)
    - **VPC:** wp-project-vpc
    - **Subnets:** Subnets públicas
3. **Security Group:**
    - Permitir **80 (HTTP)** de **qualquer lugar (0.0.0.0/0)**
    - Remova acesso direto à EC2
4. **Criar Target Group:**
    - **Nome:** wordpress-target
    - **Tipo:** EC2 Instances
    - **Health Check:** `/wp-admin/install.php`
    - Adicionar a **instância EC2**

## Bloqueando Acesso Direto à EC2

1. No **Security Groups** da EC2, altere a regra de entrada da porta 80 (HTTP) para permitir apenas o **Security Group do Load Balancer**.
2. Teste tentando acessar o IP da EC2 (`http://SEU_IP_EC2`). Deve estar bloqueado.
3. O acesso ao WordPress deve ser feito apenas pelo Load Balancer (`http://SEU_LOAD_BALANCER_DNS`).

## Conclusão

Agora sua aplicação WordPress está rodando em um ambiente seguro, escalável e gerenciado na AWS, utilizando Docker, RDS e Load Balancer para garantir desempenho e disponibilidade.

---

**Autor:** Maria Fernanda Trevizane Buonafina
**Contato:** [seuemail@exemplo.com](mailto:maria.fernanda.ufdc@gmail.com)

