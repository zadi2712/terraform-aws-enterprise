################################################################################
# ALB Module  
# Description: Application Load Balancer with HTTPS support
# Features: Multiple target groups, health checks, SSL/TLS
################################################################################

resource "aws_lb" "main" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = var.enable_http2
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  idle_timeout = var.idle_timeout

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
    enabled = var.enable_access_logs
  }

  tags = merge(
    var.tags,
    {
      Name        = var.name
      Environment = var.environment
    }
  )
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  count = var.enable_http_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.enable_https_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
}

# Target Groups
resource "aws_lb_target_group" "main" {
  count = length(var.target_groups)

  name     = "${var.name}-tg-${count.index}"
  port     = var.target_groups[count.index].port
  protocol = var.target_groups[count.index].protocol
  vpc_id   = var.vpc_id

  target_type = var.target_groups[count.index].target_type

  deregistration_delay = var.target_groups[count.index].deregistration_delay

  health_check {
    enabled             = true
    healthy_threshold   = var.target_groups[count.index].health_check.healthy_threshold
    interval            = var.target_groups[count.index].health_check.interval
    matcher             = var.target_groups[count.index].health_check.matcher
    path                = var.target_groups[count.index].health_check.path
    port                = var.target_groups[count.index].health_check.port
    protocol            = var.target_groups[count.index].health_check.protocol
    timeout             = var.target_groups[count.index].health_check.timeout
    unhealthy_threshold = var.target_groups[count.index].health_check.unhealthy_threshold
  }

  stickiness {
    type            = var.target_groups[count.index].stickiness.type
    cookie_duration = var.target_groups[count.index].stickiness.cookie_duration
    enabled         = var.target_groups[count.index].stickiness.enabled
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-tg-${count.index}"
      Environment = var.environment
    }
  )
}

# Listener Rules
resource "aws_lb_listener_rule" "rules" {
  count = length(var.listener_rules)

  listener_arn = aws_lb_listener.https[0].arn
  priority     = var.listener_rules[count.index].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[var.listener_rules[count.index].target_group_index].arn
  }

  condition {
    path_pattern {
      values = var.listener_rules[count.index].path_patterns
    }
  }
}
