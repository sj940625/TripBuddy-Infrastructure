# ==========================================
# 1. VPC 생성
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ai-travel-vpc"
  }
}

# ==========================================
# 2. 인터넷 게이트웨이 (IGW)
# ==========================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ai-travel-igw"
  }
}

# ==========================================
# 3. 퍼블릭 서브넷 2개
# ==========================================

# Public Subnet A - ap-northeast-2a
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "ai-travel-public-subnet-a"
    "kubernetes.io/role/elb" = "1"
  }
}

# Public Subnet B - ap-northeast-2c
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "ai-travel-public-subnet-b"
    "kubernetes.io/role/elb" = "1"
  }
}

# ==========================================
# 4. 프라이빗 서브넷 2개
# ==========================================

# Private Subnet A - ap-northeast-2a
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name                              = "ai-travel-private-subnet-a"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Private Subnet B - ap-northeast-2c
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name                              = "ai-travel-private-subnet-b"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ==========================================
# 5. NAT Gateway용 Elastic IP 2개
# ==========================================

resource "aws_eip" "nat_a" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "ai-travel-nat-eip-a"
  }
}

resource "aws_eip" "nat_b" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "ai-travel-nat-eip-b"
  }
}

# ==========================================
# 6. NAT Gateway 2개
# ==========================================

# NAT Gateway A
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_route_table_association.public_a]

  tags = {
    Name = "ai-travel-nat-gw-a"
  }
}

# NAT Gateway B
resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  depends_on    = [aws_route_table_association.public_b]

  tags = {
    Name = "ai-travel-nat-gw-b"
  }
}

# ==========================================
# 7. Public Route Table
# 0.0.0.0/0 -> Internet Gateway
# ==========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ai-travel-public-rt"
  }
}

# Public Subnet A -> Public Route Table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# Public Subnet B -> Public Route Table
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ==========================================
# 8. Private Route Table A
# 0.0.0.0/0 -> NAT Gateway A
# ==========================================

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "ai-travel-private-rt-a"
  }
}

# Private Subnet A -> Private Route Table A
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

# ==========================================
# 9. Private Route Table B
# 0.0.0.0/0 -> NAT Gateway B
# ==========================================

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }

  tags = {
    Name = "ai-travel-private-rt-b"
  }
}

# Private Subnet B -> Private Route Table B
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}
# ==========================================
# 10. DB 전용 Private Subnet 2개
# ==========================================

# DB Private Subnet A - ap-northeast-2a
resource "aws_subnet" "db_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.30.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "ai-travel-db-subnet-a"
  }
}

# DB Private Subnet B - ap-northeast-2c
resource "aws_subnet" "db_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.40.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = false

  tags = {
    Name = "ai-travel-db-subnet-b"
  }
}


# ==========================================
# 11. Cache 전용 Private Subnet 2개
# ==========================================

# Cache Private Subnet A - ap-northeast-2a
resource "aws_subnet" "cache_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.50.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "ai-travel-cache-subnet-a"
  }
}

# Cache Private Subnet B - ap-northeast-2c
resource "aws_subnet" "cache_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.60.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = false

  tags = {
    Name = "ai-travel-cache-subnet-b"
  }
}


# ==========================================
# 12. DB 전용 Route Table
# VPC Local 통신만 허용
# NAT / IGW 경로 없음
# ==========================================

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ai-travel-db-rt"
  }
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.db.id
}


# ==========================================
# 13. Cache 전용 Route Table
# VPC Local 통신만 허용
# NAT / IGW 경로 없음
# ==========================================

resource "aws_route_table" "cache" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ai-travel-cache-rt"
  }
}

resource "aws_route_table_association" "cache_a" {
  subnet_id      = aws_subnet.cache_a.id
  route_table_id = aws_route_table.cache.id
}

resource "aws_route_table_association" "cache_b" {
  subnet_id      = aws_subnet.cache_b.id
  route_table_id = aws_route_table.cache.id
}