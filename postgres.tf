# Postgres (RDS) pro officyna-billing-service — banco relacional próprio, separado do
# DocumentDB (que é da os-service/production). Reaproveita a mesma VPC/subnets públicas do
# db.tf, sem tocar nos recursos existentes.

resource "aws_db_subnet_group" "billing_postgres" {
  name       = "officyna-billing-postgres-subnet-group"
  subnet_ids = aws_subnet.subnet_public[*].id

  tags = {
    Name = "officyna-billing-postgres-subnets"
  }
}

resource "aws_security_group" "billing_postgres_sg" {
  name        = "officyna-billing-postgres-sg"
  description = "Permite trafego interno na porta 5432 (Postgres)"
  vpc_id      = aws_vpc.vpc_fiap.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "billing_postgres" {
  identifier             = "officyna-billing-postgres"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "officyna_billing"
  username               = var.billing_db_username
  password               = var.billing_db_password
  db_subnet_group_name   = aws_db_subnet_group.billing_postgres.name
  vpc_security_group_ids = [aws_security_group.billing_postgres_sg.id]
  # Sem acesso público: o billing-service roda dentro da mesma VPC (EKS), não precisa expor o
  # banco pra internet — reduz superfície de ataque sem custo nenhum.
  publicly_accessible = false
  storage_encrypted   = true
  skip_final_snapshot = true
  # 7 dias de retenção: o SonarCloud (S6364) considerou até 1 dia "curto demais" ainda. RDS
  # dá armazenamento de backup grátis até o tamanho do banco, então 7 dias numa instância
  # pequena não tem custo relevante — não vale deixar o gate vermelho por isso.
  backup_retention_period = 7
}
