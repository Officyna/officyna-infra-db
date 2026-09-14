# Cria Internet Gateway para a api da officyna
resource "aws_internet_gateway" "igw_api" {
  vpc_id = aws_vpc.vpc_fiap.id
}

# 1. Cria as Subnets Privadas (onde ficará a sua Lambda)
resource "aws_subnet" "subnet_private" {
  count             = 3
  vpc_id            = aws_vpc.vpc_fiap.id
  cidr_block        = cidrsubnet(aws_vpc.vpc_fiap.cidr_block, 4, count.index + 3)
  availability_zone = ["us-east-1a", "us-east-1b", "us-east-1c"][count.index]

  tags = {
    Name = "officyna-private-subnet-${count.index}"
    Type = "private" # <--- TAG CHAVE
  }
}

# 2. Cria o Elastic IP para o NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# 3. Cria o NAT Gateway (Alocado dentro da sua Subnet Pública existente)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet_public[0].id

  tags = {
    Name = "officyna-nat-gateway"
  }
}

# 4. Tabela de Roteamento Pública (Conecta as subnets públicas ao Internet Gateway existente)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc_fiap.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_api.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.subnet_public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 5. Tabela de Roteamento Privada (Faz a Lambda sair para a Internet via NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc_fiap.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.subnet_private[count.index].id
  route_table_id = aws_route_table.private.id
}