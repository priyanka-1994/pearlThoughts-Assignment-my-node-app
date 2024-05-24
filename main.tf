provider "aws" {
  region = "us-east-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}
#  vpc creation

resource aws_vpc "main" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name="MainVPC"
    }
}

# creation public subnet
resource "aws_subnet" "public"{
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    
    tags = {
        Name = "PublicSubnet"
    }
}

#create IGW
resource "aws_internet_gateway" "gw"{
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "MainGateway"
    }
}

#Attaching gatway to VPC
# resource "aws_vpc_attachment" "gw_attach" {
#   vpc_id = aws_vpc.main.id
#   internet_gateway_id=aws_internet_gateway.gw.id

# }

# creating RT
resource "aws_route_table" "route"{
    vpc_id = aws_vpc.main.id
    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
    tags = {
        Name = "MainRouteTable"
    }
}

# associate public subnet to RT
resource "aws_route_table_association" "public_association" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.route.id
} 

# Create security group for the VPC
resource "aws_security_group" "ecs" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "ECSSecurityGroup"
  }
}

# ecs cluster
resource "aws_ecs_cluster" "main" {
    name="hello_world_cluster"
}

# creation of ecs task definition
resource "aws_ecs_task_definition" "main"{
    family="hello-world-task"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu = "256"
    memory = "512"
    execution_role_arn = aws_iam_role.ecs_task_execution.arn

    container_definitions = jsonencode(
        [
            {
                "name" = "hello-world-container",
                "image" = "prikale/PearlThoughtImage:latest",
                "cpu" = 256,
                "memory" = 512,
                "essential" = true,
                "portMappings" = [
                    {
                        "containerPort" = 8080,
                        "protocol" = "tcp"
                    }
                    ]
                }
            ]
    )
}

# creation of ecs services
resource "aws_ecs_service" "main" {
    name = "hello-world-service"
    cluster = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.main.arn
    launch_type = "FARGATE"
    desired_count = 1

    network_configuration {
        subnets = [aws_subnet.public.id]
        security_groups = [aws_security_group.ecs.id]
        assign_public_ip = true

    }
    depends_on = [ aws_iam_role_policy_attachment.ecs_execution_policy]
}

resource "aws_iam_role" "ecs_task_execution" {
    name = "ecsTaskExecutionRole"
    
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ecs-tasks.amazonaws.com"
            }
        }


        ]
    })
    tags = {
        tag-key = "ecs-tag"
    }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
    role = aws_iam_role.ecs_task_execution.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# creation of ECR repo
resource "aws_ecr_repository" "app" {
    name = "ecr-repo-pearlthoghts"
}
