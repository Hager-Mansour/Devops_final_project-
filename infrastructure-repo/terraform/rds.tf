# RDS PostgreSQL Configuration
# Creates a managed PostgreSQL database for the application

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  # Allow PostgreSQL access from VPC CIDR (EKS pods)
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-rds-subnet-group"
  description = "RDS subnet group for ${var.project_name}"
  subnet_ids  = module.vpc.private_subnets

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-subnet-group"
    }
  )
}

# Generate random password for RDS
resource "random_password" "rds" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store RDS password in SSM Parameter Store
resource "aws_ssm_parameter" "rds_password" {
  name        = "/${var.project_name}/${var.environment}/rds/password"
  description = "RDS PostgreSQL password"
  type        = "SecureString"
  value       = random_password.rds.result

  tags = local.common_tags
}

# Store RDS connection string in SSM Parameter Store
resource "aws_ssm_parameter" "rds_connection_string" {
  name        = "/${var.project_name}/${var.environment}/rds/connection-string"
  description = "RDS PostgreSQL connection string"
  type        = "SecureString"
  value       = "postgresql://${var.rds_username}:${random_password.rds.result}@${aws_db_instance.main.endpoint}/${var.rds_database_name}"

  tags = local.common_tags
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  # Engine configuration
  engine            = "postgres"
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  # Database configuration
  db_name  = var.rds_database_name
  username = var.rds_username
  password = random_password.rds.result

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.environment == "prod" ? true : false

  # Backup configuration
  backup_retention_period   = var.environment == "prod" ? 7 : 0
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-final-snapshot" : null

  # Maintenance
  auto_minor_version_upgrade = true
  maintenance_window         = "Mon:03:00-Mon:04:00"

  # Performance Insights (disabled for t3.micro)
  performance_insights_enabled = var.rds_instance_class == "db.t3.micro" ? false : true

  # Deletion protection (enabled in prod)
  deletion_protection = var.environment == "prod" ? true : false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-postgres"
    }
  )
}

# ============================================
# IAM Role for Backend Pods (IRSA) - SSM Access
# ============================================

# IAM Policy for reading SSM parameters
resource "aws_iam_policy" "backend_ssm_read" {
  name        = "${var.project_name}-${var.environment}-backend-ssm-read"
  description = "Allow backend pods to read RDS connection from SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/rds/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IRSA Role for backend pods
module "backend_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-backend-ssm-role"

  role_policy_arns = {
    ssm_read = aws_iam_policy.backend_ssm_read.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["dev:backend-sa", "staging:backend-sa", "prod:backend-sa"]
    }
  }

  tags = local.common_tags
}

