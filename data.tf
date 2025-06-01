data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "feedback-terraform-state"
    key    = "terraform/network/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "build" {
  backend = "s3"

  config = {
    bucket = "feedback-terraform-state"
    key    = "terraform/build/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.this.family
}