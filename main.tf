terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = merge(var.tags, {
    Name = var.name
  })
}

# ── EC2 Spot Instance ────────────────────────────────────────────────────────

resource "aws_spot_instance_request" "monitoring" {
  ami           = var.ami_id
  instance_type = var.instance_type

  spot_price                     = var.spot_price
  spot_type                      = var.spot_type
  instance_interruption_behavior = var.spot_interruption_behavior
  wait_for_fulfillment           = true

  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  vpc_security_group_ids = var.security_group_ids

  key_name             = var.key_pair_name
  iam_instance_profile = var.iam_instance_profile

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    iops                  = var.root_volume_iops
    throughput            = var.root_volume_throughput
    encrypted             = var.root_volume_encrypted
    delete_on_termination = true
  }

  monitoring = false

  user_data = templatefile("${path.module}/user_data/setup.sh", {
    prometheus_version   = var.prometheus_version
    promtail_version     = var.promtail_version
    grafana_domain       = var.grafana_domain
    prometheus_domain    = var.prometheus_domain
    loki_domain          = var.loki_domain
    loki_listen_port     = var.loki_listen_port
    promtail_listen_port = var.promtail_listen_port
    prometheus_config = templatefile("${path.module}/templates/prometheus.yml", {
      scrape_targets = var.scrape_targets
    })
    loki_config = file("${path.module}/templates/loki-config.yml")
    promtail_config = templatefile("${path.module}/templates/promtail.yml", {
      loki_listen_port      = var.loki_listen_port
      promtail_listen_port  = var.promtail_listen_port
      cloudwatch_log_groups = var.promtail_cloudwatch_log_groups
    })
    nginx_grafana = templatefile("${path.module}/templates/nginx-grafana.conf", { domain = var.grafana_domain })
    nginx_prometheus = templatefile("${path.module}/templates/nginx-prometheus.conf", {
      prometheus_domain = var.prometheus_domain
      grafana_domain    = var.grafana_domain
    })
    nginx_loki = templatefile("${path.module}/templates/nginx-loki.conf", { domain = var.loki_domain })
  })

  tags = local.common_tags

  volume_tags = local.common_tags
}
