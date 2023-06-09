data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}


#create ami param store with default value
resource "aws_ssm_parameter" "webserver_ami_id_ssmps" {
    name = "/webserver/amiid" 
    type = "String"
    value = var.ami_id

    lifecycle {
        ignore_changes = [value]
    }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_http"
  }
}

### ASG
resource "aws_launch_template" "webserver_lt" {
  name_prefix   = "webserver"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  key_name = var.keypair_name

  lifecycle {
    ignore_changes = [image_id]
  }

  user_data = filebase64("${path.module}/scripts/user_data_script.sh")
}

resource "aws_autoscaling_group" "webserver_asg" {
  name = "webserver_asg"
  vpc_zone_identifier = data.aws_subnets.subnets.ids
  desired_capacity   = 2
  max_size           = 4
  min_size           = 1

  launch_template {
    id      = aws_launch_template.webserver_lt.id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }
}

### ALB
resource "aws_security_group" "allow_http_lb" {
  name        = "allow_http_lb"
  description = "Allow HTTP inbound traffic for LB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from VPC"
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
    Name = "allow_http_lb"
  }
}

resource "aws_lb" "webserver_alb" {
  name               = "webserveralb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.subnets.ids
  security_groups    = [aws_security_group.allow_http_lb.id]
  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_target_group" "webserver_tg" {
  name     = "webservertg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {    
    healthy_threshold   = 3    
    unhealthy_threshold = 10    
    timeout             = 5    
    interval            = 10    
    path                = "/hello.html" 
    port                = 80
  }
}

resource "aws_lb_listener" "webserver_listner" {
  load_balancer_arn = aws_lb.webserver_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver_tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_webserver" {
  autoscaling_group_name = aws_autoscaling_group.webserver_asg.id
  alb_target_group_arn   = aws_lb_target_group.webserver_tg.arn
}
