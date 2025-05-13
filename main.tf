provider "aws" {
  region = "us-east-1"
}

resource "aws_lb_target_group" "catalogue" {
  name     = "catalogue-target"
  port     = 8080   # The port your targets will listen on
  protocol = "HTTP" # Can be HTTP, HTTPS, TCP, or TLS

  # Health check configuration
  health_check {
    healthy_threshold   = 3
    interval            = 30
    path                = "/health"
    port                = 8080
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  # Set the target type
  target_type = "instance" # Other options: "ip", "lambda"

  # The VPC ID where the target group will be located
  vpc_id = data.aws_ssm_parameter.vpcid.value
}

resource "aws_instance" "catalogue" {
  ami                    = var.centos
  instance_type          = "t2.micro"
  vpc_security_group_ids = [data.aws_ssm_parameter.sgid.value]
  subnet_id              = element(split(",", data.aws_ssm_parameter.private.value), 0)
  tags = {
    Name = "catalogue"
  }
}
resource "null_resource" "catalogue" {
  triggers = {
    instance_id = aws_instance.catalogue.id
  }
  connection {
    host     = aws_instance.catalogue.private_ip
    user     = "centos"
    password = "DevOps321"
    type     = "ssh"
  }
  provisioner "remote-exec" {
    inline = ["sudo yum update -y",
      "sudo yum install ansible -y",
    "ansible-pull -U https://github.com/swamy527/roboshop-ansible-roles-tf.git -e component=catalogue -e app_version=${var.app_version} -e env=${var.environment} main-tf.yaml"]
  }

}

resource "aws_ec2_instance_state" "catalogue" {
  instance_id = aws_instance.catalogue.id
  state       = "stopped"
  depends_on  = [null_resource.catalogue]
}

resource "aws_ami_from_instance" "catalogue" {
  name               = "catalogue-ami-${local.current_time}"
  source_instance_id = aws_instance.catalogue.id
  depends_on         = [aws_ec2_instance_state.catalogue]
}

resource "null_resource" "catalogue_delete" {
  # Changes to any instance of the cluster requires re-provisioning
  #   triggers = {
  #     instance_id = module.catalogue.id
  #   }

  provisioner "local-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.catalogue.id}"
  }

  depends_on = [aws_ami_from_instance.catalogue]
}

resource "aws_launch_template" "catalogue" {
  name = "${var.project_name}-${var.environment}-catalogue"

  image_id                             = aws_ami_from_instance.catalogue.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t2.micro"
  update_default_version               = true

  vpc_security_group_ids = [data.aws_ssm_parameter.sgid.value]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-${var.environment}-template"
    }
  }

}


resource "aws_autoscaling_group" "catalogue" {
  name                      = "${var.project_name}-${var.environment}-catalogue"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2
  vpc_zone_identifier       = split(",", data.aws_ssm_parameter.private.value)
  target_group_arns         = [aws_lb_target_group.catalogue.arn]

  launch_template {
    id      = aws_launch_template.catalogue.id
    version = aws_launch_template.catalogue.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-catalogue"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }
}

resource "aws_lb_listener_rule" "catalogue" {
  listener_arn = data.aws_ssm_parameter.app_alb_arn.value
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalogue.arn
  }


  condition {
    host_header {
      values = ["catalogue.${var.environment}.${var.zone_name}"]
    }
  }
}

resource "aws_autoscaling_policy" "catalogue" {
  autoscaling_group_name = aws_autoscaling_group.catalogue.name
  name                   = "${var.project_name}-${var.environment}"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 10
  }
}
