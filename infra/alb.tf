resource "aws_alb" "main"{
    name = "${var.project_name}-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb.id]
    subnets = aws_subnet.public[*].id

    enable_deletion_protection = false
    drop_invalid_header_fields = true
    tags = {Name = "${var.project_name} - alb"}
}

#TAGS  groups - where ALB dredirect the traffic to the webtier 

resource "aws_alb_target_group" "web"{
    name = "${var.project_name}-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id
    target_type = "instance"

    health_check  {
        enabled = true 
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 30 
        timeout = 5
        healthy_threshold = 2
        unhealthy_threshold = 3
    }
    tags = {Name = "${var.project_name} - health_check_tg"}
}
#PORT 80 - to HTTPS 
resource "aws_lb_listener" "http"{
    load_balancer_arn = aws_alb.main.arn
    port = 80
    protocol = "HTTP"
    default_action {
      type = "redirect"

      redirect {
        port = "443"
        protocol =  "HTTPS"
        status_code = "HTTP_301"
      }
    }
}
#PORT 443 a TLS termintation to use thhe ACM certificate 
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_alb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.web.arn
  }
}

output "alb_dns_name" {
  description = "Point the app CNAME at this"
  value       = aws_alb.main.dns_name
}