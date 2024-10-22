resource "aws_lb_target_group" "catalogue" {
  name     = "${var.project_name}-${var.environment}-catalogue"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
  health_check {
    healthy_threshold   = 2
    interval            = 10
    unhealthy_threshold = 3
    timeout             = 5
    path                = "/health"
    port                = 8080
    matcher             = "200-299"
  }
}


module "catalogue" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  ami                    = data.aws_ami.centos8.id
  name                   = "${var.project_name}-${var.environment}-catalogue"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [data.aws_ssm_parameter.catalogue_sg_id.value]
  subnet_id              = element(split(",", data.aws_ssm_parameter.private_subnet_ids.value), 0)
  tags = {
    Name = "${var.project_name}-${var.environment}-catalogue"
  }
}

resource "null_resource" "catalogue" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = module.catalogue.id
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    type     = "ssh"
    host     = module.catalogue.private_ip
    user     = "centos"
    password = "DevOps321"
  }

  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh catalogue dev ${var.app_version}"
    ]
  }
}

resource "aws_ec2_instance_state" "catalogue" {
  instance_id = module.catalogue.id
  state       = "stopped"
  depends_on  = [null_resource.catalogue]
}

resource "aws_ami_from_instance" "catalogue" {
  name               = "${var.project_name}-${var.environment}-catalogue-${local.current_time}"
  source_instance_id = module.catalogue.id
  depends_on         = [aws_ec2_instance_state.catalogue]
}

resource "null_resource" "catalogue_delete" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = module.catalogue.id
  }

  provisioner "local-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    command = "aws ec2 terminate-instances --instance-ids ${module.catalogue.id}"
  }

  depends_on = [aws_ami_from_instance.catalogue]
}

resource "aws_launch_template" "catalogue" {
  name = "${var.project_name}-${var.environment}-${var.app_version}"

  image_id                             = aws_ami_from_instance.catalogue.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t2.micro"
  update_default_version               = true

  vpc_security_group_ids = [data.aws_ssm_parameter.catalogue_sg_id.value]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-${var.environment}-template"
    }
  }

}

resource "aws_autoscaling_group" "catalogue" {
  name                      = "${var.project_name}-${var.environment}"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2
  vpc_zone_identifier       = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
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
      values = ["catalogue.dev.${var.zone_name}"]
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
