
locals {
  scanned_repo_url = data.terraform_remote_state.build.outputs.feedback_app_scanned_repository_url
  repo_id          = data.terraform_remote_state.build.outputs.feedback_app_scanned_registry_id
  subnets_ids      = data.terraform_remote_state.network.outputs.subnets
  sg_id            = data.terraform_remote_state.network.outputs.sg_app
  target_group_arn = data.terraform_remote_state.network.outputs.target_group_arn
  region           = data.aws_region.current.name
  table_name       = "feedback-app-table"
  sns_topic_arn    = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:feedback-app-topic"
}

resource "aws_ecs_cluster" "this" {
  name = "feedback-app-cluster"
  tags = var.tags
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name_prefix       = "feedback-app-ecs-logs"
  retention_in_days = 1
  tags              = var.tags
}

resource "aws_ecs_task_definition" "this" {
  family = var.name

  container_definitions = <<DEFINITION
  [
    {
      "name": "${local.repo_id}",
      "image": "${local.scanned_repo_url}:latest",
      "entryPoint": [],
      "environment": [
        {
          "name": "SNS_TOPIC_ARN",
          "value": "${local.sns_topic_arn}"
        },
        {
          "name": "TABLE_NAME",
          "value": "${local.table_name}"
        },
        {
          "name": "AWS_REGION",
          "value": "${local.region}"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.this.id}",
          "awslogs-region": "${local.region}",
          "awslogs-stream-prefix": "task"
        }
      },
      "portMappings": [
        {
          "containerPort": ${var.port},
          "hostPort": ${var.port}
        }
      ],
      "cpu": 256,
      "memory": 512,
      "networkMode": "awsvpc"
    }
  ]
  DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ecs-task-definition"
  })
}


resource "aws_ecs_service" "service" {
  name                 = "${var.name}-ecs-service"
  cluster              = aws_ecs_cluster.this.id
  task_definition      = "${aws_ecs_task_definition.this.family}:${max(aws_ecs_task_definition.this.revision, data.aws_ecs_task_definition.main.revision)}"
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets          = local.subnets_ids
    assign_public_ip = false
    security_groups  = [local.sg_id]
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ecs-service"
  })

  load_balancer {
    target_group_arn = local.target_group_arn
    container_name   = local.repo_id
    container_port   = var.port
  }
}