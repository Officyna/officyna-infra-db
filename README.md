# officyna-infra-db

Infraestrutura como código (Terraform) do banco de dados gerenciado (Amazon
DocumentDB, compatível com MongoDB) usado pela aplicação
[officyna-service](https://github.com/Officyna/officyna-service).

Parte do Tech Challenge da Pós Tech (Arquitetura de Software Orientada a
Serviços) — repositório separado conforme requisito de segregação de
infraestrutura em repositórios próprios com CI/CD.

## Tecnologias utilizadas

- [Terraform](https://developer.hashicorp.com/terraform) >= 1.5
- [Amazon DocumentDB](https://aws.amazon.com/documentdb/) (compatível com MongoDB)
- AWS Systems Manager Parameter Store (para publicar o endpoint do banco)
- GitHub Actions (CI/CD)

## Recursos provisionados

| Recurso | Descrição |
|---|---|
| `aws_vpc.vpc_fiap` | VPC própria da infraestrutura |
| `aws_subnet.subnet_public` | 3 subnets públicas (uma por AZ) |
| `aws_internet_gateway.igw_api` | Internet Gateway da VPC |
| `aws_docdb_subnet_group.default` | Subnet group do cluster |
| `aws_security_group.docdb_sg` | Security group liberando a porta 27017 internamente |
| `aws_docdb_cluster.docdb` | Cluster DocumentDB (`officyna-mongodb-cluster`) |
| `aws_docdb_cluster_instance.cluster_instances` | Instância `db.t3.medium` do cluster |

O estado do Terraform é armazenado remotamente no bucket S3
`projeto-officyna-soat` (`docdb/terraform.tfstate`).

A VPC e as subnets criadas aqui são reaproveitadas pelo cluster EKS do
[officyna-infra-k8s](https://github.com/Officyna/officyna-infra-k8s) — o
`vpc_id` e os `subnet_ids` são publicados no SSM Parameter Store (veja CI/CD
abaixo) para esse outro repositório consumir.

## Pré-requisitos

- [Terraform >= 1.5](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  configurado com permissões de DocumentDB/EC2/SSM
- Credenciais AWS com acesso ao bucket de state remoto

## Como aplicar localmente

```bash
terraform init
terraform plan -var="db_password=<senha>"
terraform apply -var="db_password=<senha>"
```

## Como destruir

```bash
terraform destroy -var="db_password=<senha>"
```

## CI/CD

O workflow em [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml)
executa:

- **Pull Request para `main`**: `terraform fmt -check`, `terraform validate` e
  `terraform plan`.
- **Push em `main`**: `terraform apply -auto-approve` e, em seguida, publica no
  **AWS Systems Manager Parameter Store**:
  - `/officyna/db/endpoint` e `/officyna/db/port` — usados pelo pipeline do
    [officyna-service](https://github.com/Officyna/officyna-service) para
    montar a connection string sem depender diretamente deste repositório.
  - `/officyna/network/vpc_id`, `/officyna/network/vpc_cidr` e
    `/officyna/network/subnet_ids` — usados pelo pipeline do
    [officyna-infra-k8s](https://github.com/Officyna/officyna-infra-k8s) para
    criar o cluster EKS na mesma VPC/subnets do banco.
- **Manual** (aba *Actions* → *Terraform CI/CD (DocumentDB)* → *Run workflow*):
  escolha `action: apply` para reaplicar, ou `action: destroy` (digitando
  `destroy` no campo de confirmação) para desligar o banco quando não
  estiver em uso e evitar custo na AWS.

### Secrets necessários no repositório

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key com permissão de DocumentDB/EC2/SSM |
| `AWS_SECRET_ACCESS_KEY` | Secret key correspondente |
| `AWS_REGION` | Região da AWS (ex: `us-east-1`) |
| `DB_PASSWORD` | Senha master do banco (usada como `var.db_password`) |

### Regras de proteção da branch `main`

- Bloqueada para commits diretos.
- Merge somente via Pull Request, com deploy automático (`terraform apply`)
  disparado após o merge.

## Repositórios relacionados

- [officyna-service](https://github.com/Officyna/officyna-service) — aplicação principal
- [officyna-infra-k8s](https://github.com/Officyna/officyna-infra-k8s) — cluster Kubernetes (EKS)
