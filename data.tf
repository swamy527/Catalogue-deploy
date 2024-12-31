data "aws_ssm_parameter" "private" {
  name = "/${var.project}/${var.environment}/private_sub"
}


data "aws_ssm_parameter" "sgid" {
  name = "/${var.project}/${var.environment}/all_sgid"
}


data "aws_ssm_parameter" "vpcid" {
  name = "/${var.project}/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "app_alb_arn" {
  name = "/${var.project}/${var.environment}/alb-rule"
}
