provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

resource "aws_s3_bucket" "static" {
  bucket = "cloudfront-test"
}

resource "aws_s3_bucket_policy" "static_policy" {
  bucket = aws_s3_bucket.static.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "cloudfront.amazonaws.com" },
      Action = "s3:GetObject",
      Resource = "${aws_s3_bucket.static.arn}/*",
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.main.arn }
      }
    }]
  })
}

resource "aws_cloudfront_origin_access_control" "oac" {
    name = "s3-cloudfront-oac-test"
    origin_access_control_origin_type = "s3"
    signing_behavior = "always"
    signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "main" {
    enabled = true
    default_root_object = "index.html"
    is_ipv6_enabled = true
    wait_for_deployment = true

    origin {
        domain_name = aws_s3_bucket.static.bucket_regional_domain_name
        origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
        origin_id = "S3Origin"
    }

    default_cache_behavior {
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods = ["GET", "HEAD"]
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
      target_origin_id = "S3Origin"
      viewer_protocol_policy = "redirect-to-https"
    }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
}

resource "aws_launch_template" "foobar" {
  name_prefix   = "foobar"
  image_id      = "ami-0eaf62527f5bb8940"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.web_sg.id]
  }
}

resource "aws_autoscaling_group" "scale" {
    max_size = 4
    min_size = 2
    desired_capacity = 2
    vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]

    launch_template {
    id      = aws_launch_template.foobar.id
    version = "$Latest"
  }
  health_check_type = "ELB"
}

resource "aws_autoscaling_attachment" "asg_lb_attachment" {
  autoscaling_group_name = aws_autoscaling_group.scale.id
  lb_target_group_arn    = aws_lb_target_group.web_tg.arn
}

resource "aws_s3_bucket" "loadb-logs" {
  bucket = "my-loadb-logs"
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "web" {
  name = "ec2-cloudwatch"
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 4
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.scale.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.scale.name
  }
}
