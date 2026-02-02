#########################
# Network (module)
#########################
module "network" {
  source = "./modules/network"

  vpc_cidr = "10.0.0.0/16"
  vpc_name = "alb-basics"

  public_subnets = {
    "public-a" = { cidr = "10.0.1.0/24", az = "ap-northeast-1a", name = "alb-basics-public-a" }
    "public-c" = { cidr = "10.0.2.0/24", az = "ap-northeast-1c", name = "alb-basics-public-c" }
  }
}

#########################
# Security Group - ALB
#########################
resource "aws_security_group" "alb" {
  name   = "alb-basics-alb-sg"
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-basics-alb-sg"
  }
}

#########################
# Security Group - EC2
#########################
resource "aws_security_group" "web" {
  name   = "alb-basics-web-sg"
  vpc_id = module.network.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-basics-web-sg"
  }
}

#########################
# EC2
#########################
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "web_a" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = module.network.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    INSTANCE_ID=$(ec2-metadata -i | cut -d' ' -f2)
    AZ=$(ec2-metadata -z | cut -d' ' -f2)
    echo "Hello from $INSTANCE_ID ($AZ)" > /var/www/html/index.html
  EOF

  tags = {
    Name = "alb-basics-web-a"
  }
}

resource "aws_instance" "web_c" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = module.network.public_subnet_ids[1]
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    INSTANCE_ID=$(ec2-metadata -i | cut -d' ' -f2)
    AZ=$(ec2-metadata -z | cut -d' ' -f2)
    echo "Hello from $INSTANCE_ID ($AZ)" > /var/www/html/index.html
  EOF

  tags = {
    Name = "alb-basics-web-c"
  }
}

#########################
# ALB
#########################
resource "aws_lb" "main" {
  name               = "alb-basics"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.network.public_subnet_ids

  tags = {
    Name = "alb-basics"
  }
}

#########################
# Target Group
#########################
resource "aws_lb_target_group" "web" {
  name     = "alb-basics-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }

  tags = {
    Name = "alb-basics-tg"
  }
}

resource "aws_lb_target_group_attachment" "web_a" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_c" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_c.id
  port             = 80
}

#########################
# Listener
#########################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

#########################
# Outputs
#########################
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}
