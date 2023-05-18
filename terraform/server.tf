# IAM
resource "aws_iam_instance_profile" "worth_web_server_profile" {
  name = "worth_web_server_profile"
  role = aws_iam_role.worth_web_server_role.name
}

resource "aws_iam_role" "worth_web_server_role" {
  name = "worth_web_server_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "worth_web_server_role"
  }
}

resource "aws_iam_policy" "worth_web_server_efs_policy" {
  name        = "worth_web_server_efs_policy"
  path        = "/"
  description = "Policy to allow usage of EFS"

  policy = file("resources/iam_worth_web_efs_policy.json.tmpl")
}

resource "aws_iam_role_policy_attachment" "worth_web_server_efs_policy_attachment" {
  role       = aws_iam_role.worth_web_server_role.name
  policy_arn = aws_iam_policy.worth_web_server_efs_policy.arn
}

# EFS
resource "aws_efs_file_system" "worth_web_server_efs_a" {
  creation_token = "worth_web_server_efs_a"

  tags = {
    Name = "worth_web_server_efs_a"
  }
}

resource "aws_efs_file_system_policy" "worth_web_server_efs_policy" {
  file_system_id = aws_efs_file_system.worth_web_server_efs_a.id

  policy = templatefile(
    "resources/efs_resource_policy.json.tmpl",
    {
      principal_iam_role_arn = aws_iam_role.worth_web_server_role.arn
      resource_arn           = aws_efs_file_system.worth_web_server_efs_a.arn
    }
  )
}

resource "aws_efs_mount_target" "efs_mount_worth_private_subnet" {
  file_system_id  = aws_efs_file_system.worth_web_server_efs_a.id
  subnet_id       = aws_subnet.worth_private_subnet.id
  security_groups = [aws_security_group.worth_web_server_efs_a_sg.id]
}

resource "aws_security_group" "worth_web_server_efs_a_sg" {
  name        = "worth_web_server_efs_a_sg"
  vpc_id      = aws_vpc.worth_vpc.id

  tags = {
    Name = "worth_web_server_efs_a_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "worth_web_efs_allow_server" {
  security_group_id = aws_security_group.worth_web_server_efs_a_sg.id

  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.worth_web_server_sg.id
}

# launch template
resource "aws_launch_template" "worth_web_server_lt" {
  name = "worth_web_server_lt"

  iam_instance_profile {
    arn = aws_iam_instance_profile.worth_web_server_profile.arn
  }

  image_id = "ami-09fd16644beea3565"

  instance_type = "t2.micro"

  key_name = "worth-kl"

  vpc_security_group_ids = [aws_security_group.worth_web_server_sg.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "worth_web_server"
    }
  }

  user_data = base64encode(templatefile(
    "${path.module}/resources/worth_web_server_userdata.sh.tmpl", { file_system_id = aws_efs_file_system.worth_web_server_efs_a.id }
  ))
}

resource "aws_autoscaling_group" "worth_web_server_asg" {
  vpc_zone_identifier = [aws_subnet.worth_private_subnet.id]
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1

  launch_template {
    id      = aws_launch_template.worth_web_server_lt.id
    version = "$Default"
  }

  lifecycle {
    ignore_changes = [load_balancers]
  }
}

resource "aws_security_group" "worth_web_server_sg" {
  name        = "worth_web_server_sg"
  vpc_id      = aws_vpc.worth_vpc.id

  tags = {
    Name = "worth_web_server_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "worth_web_allow_lb" {
  security_group_id = aws_security_group.worth_web_server_sg.id

  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.worth_web_lb_sg.id
}

resource "aws_vpc_security_group_egress_rule" "worth_web_allow_all" {
  security_group_id = aws_security_group.worth_web_server_sg.id

  from_port   = 0
  to_port     = 65535
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# LB resources
resource "aws_elb" "worth_web_lb" {
  name    = "worth-web-lb"
  subnets = [aws_subnet.worth_public_subnet.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/test.html"
    interval            = 30
  }

  idle_timeout                = 300
  connection_draining         = true
  connection_draining_timeout = 300
  security_groups             = [aws_security_group.worth_web_lb_sg.id]

  tags = {
    Name = "worth_web_lb"
  }
}

resource "aws_autoscaling_attachment" "worth_web_asg_attachment_elb" {
  autoscaling_group_name = aws_autoscaling_group.worth_web_server_asg.id
  elb                    = aws_elb.worth_web_lb.id
}

resource "aws_security_group" "worth_web_lb_sg" {
  name        = "worth_web_lb_sg"
  vpc_id      = aws_vpc.worth_vpc.id

  tags = {
    Name = "worth_web_lb_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "worth_web_lb_allow_http" {
  security_group_id = aws_security_group.worth_web_lb_sg.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "worth_web_lb_allow_all" {
  security_group_id = aws_security_group.worth_web_lb_sg.id

  from_port   = 0
  to_port     = 65535
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}
