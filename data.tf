data "aws_ssm_parameter" "private" {
  name = "/${var.project_name}/${var.environment}/private_subnets"
}


data "aws_ssm_parameter" "sgid" {
  name = "/${var.project_name}/${var.environment}/catalogue_sg_id"
}


data "aws_ssm_parameter" "vpcid" {
  name = "/${var.project_name}/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "app_alb_arn" {
  name = "/${var.project_name}/${var.environment}/internal_alb_listener"
}
