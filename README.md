# EC2 Monitoring Stack Setup

Terraform configuration to deploy a full monitoring stack (Prometheus, Grafana, Loki, Promtail) on an AWS EC2 Spot instance with Nginx reverse proxy and SSL.

## Overview

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Metrics collection and alerting |
| **Grafana** | Dashboards and visualization |
| **Loki** | Log aggregation |
| **Promtail** | Log shipping (CloudWatch ALB logs) |
| **Nginx** | Reverse proxy with SSL termination |
| **Certbot** | Auto-provisioned Let's Encrypt certificates |

- **Region:** `ap-southeast-3` (Jakarta)
- **Instance:** `t4g.medium` (ARM64) on Spot
- **Storage:** 8 GB gp3 encrypted root volume

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              EC2 Spot Instance              │
                    │            (t4g.medium, ARM64)              │
                    │                                             │
Internet ──► :443 ──┤  Nginx                                     │
                    │   ├── grafana.domain.io    ──► :3000 Grafana│
                    │   ├── prometheus.domain.io ──► :9090 Prom.  │
                    │   └── loki.domain.io       ──► :3100 Loki   │
                    │                                             │
                    │   Promtail(:9080) ──► Loki(:3100)           │
                    │                                             │
                    │   Prometheus ──► scrape targets (various)   │
                    └─────────────────────────────────────────────┘
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with valid credentials
- An existing AWS key pair
- An IAM instance profile (e.g. `ec2-readonly-prometheus-sd-role`) with permissions for Prometheus service discovery
- Two security groups:
  - One allowing inbound HTTP/HTTPS (80, 443)
  - One allowing internal traffic (9090, 3000, 3100, 9080)
- DNS A records for your three domains pointing to the instance's public IP

## Quick Start

```bash
# Clone the repository
git clone <repo-url> && cd ec2-monitoring-stack-setup

# Create your variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan
terraform apply
```

## Project Structure

```
.
├── main.tf                     # Terraform provider + EC2 Spot instance resource
├── variables.tf                # All configurable input variables
├── outputs.tf                  # Instance ID, public IP, spot request ID
├── terraform.tfvars.example    # Example variable values (copy to terraform.tfvars)
├── user_data/
│   └── setup.sh                # Bootstrap script (installs all services)
└── templates/
    ├── prometheus.yml          # Prometheus scrape configuration
    ├── loki-config.yml         # Loki server configuration
    ├── promtail.yml            # Promtail scrape + CloudWatch pipeline
    ├── nginx-grafana.conf      # Nginx reverse proxy for Grafana
    ├── nginx-prometheus.conf   # Nginx reverse proxy for Prometheus (with CORS)
    └── nginx-loki.conf         # Nginx reverse proxy for Loki
```

## Configuration

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `ami_id` | `string` | AMI ID (Ubuntu 22.04 LTS ARM recommended) |
| `key_pair_name` | `string` | AWS key pair name for SSH access |
| `iam_instance_profile` | `string` | IAM instance profile name |
| `subnet_id` | `string` | Subnet ID to launch the instance in |
| `security_group_ids` | `list(string)` | Security group IDs to attach |
| `grafana_domain` | `string` | Domain name for Grafana |
| `prometheus_domain` | `string` | Domain name for Prometheus |
| `loki_domain` | `string` | Domain name for Loki |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `ap-southeast-3` | AWS region |
| `name` | `monitoring-instance` | Name tag for resources |
| `instance_type` | `t4g.medium` | EC2 instance type |
| `spot_price` | `0.042000` | Max spot price (USD/hr) |
| `spot_type` | `persistent` | Spot request type |
| `spot_interruption_behavior` | `stop` | On interruption: stop, terminate, or hibernate |
| `root_volume_size` | `8` | Root volume size in GB |
| `root_volume_type` | `gp3` | EBS volume type |
| `root_volume_iops` | `3000` | EBS IOPS |
| `root_volume_throughput` | `125` | EBS throughput (MB/s) |
| `root_volume_encrypted` | `true` | Encrypt root volume |
| `prometheus_version` | `3.5.0` | Prometheus version |
| `promtail_version` | `3.5.5` | Promtail version |
| `promtail_listen_port` | `9080` | Promtail HTTP port |
| `loki_listen_port` | `3100` | Loki HTTP port |
| `promtail_cloudwatch_log_groups` | `[]` | CloudWatch log groups for Promtail |
| `tags` | `{}` | Additional resource tags |

### Scrape Targets

Define Prometheus scrape jobs using the `scrape_targets` map:

```hcl
scrape_targets = {
  job-name = {
    targets       = ["host:port"]         # required
    labels        = { app = "my-app" }    # optional, default {}
    scrape_timeout = "30s"                # optional, default "30s"
    metrics_path   = "/metrics"           # optional, default "/metrics"
  }
}
```

## Services & Ports

| Service | Port | Domain | Description |
|---------|------|--------|-------------|
| Grafana | 3000 | `grafana_domain` | Dashboard UI |
| Prometheus | 9090 | `prometheus_domain` | Metrics + PromQL |
| Loki | 3100 | `loki_domain` | Log aggregation API |
| Promtail | 9080 | internal only | Log shipping agent |
| Nginx | 80/443 | all three domains | Reverse proxy + SSL |

## SSL/TLS

Certificates are auto-provisioned via **Certbot** with the Nginx plugin. DNS A records for all three domains **must point to the instance's public IP** before provisioning. Certbot will obtain and install certificates, and Nginx will be configured to redirect HTTP to HTTPS.

## Usage

```bash
# Preview changes
terraform plan

# Apply
terraform apply

# SSH into the instance
ssh -i <key>.pem ubuntu@<public_ip>

# Check service status
sudo systemctl status prometheus grafana-server loki promtail nginx

# Destroy
terraform destroy
```

## Customization

### Adding Scrape Targets

Add new entries to `scrape_targets` in `terraform.tfvars`:

```hcl
scrape_targets = {
  my-new-service = {
    targets       = ["10.0.1.50:9100"]
    labels        = { app = "my-service", env = "prod" }
    scrape_timeout = "15s"
  }
}
```

### Changing Software Versions

Update `prometheus_version` and `promtail_version` in `terraform.tfvars`:

```hcl
prometheus_version = "3.6.0"
promtail_version   = "3.6.0"
```

### Adjusting Loki Log Retention

Edit `templates/loki-config.yml` and modify `retention_period` (default: `168h` = 7 days):

```yaml
limits_config:
  retention_period: 336h  # 14 days
```

### Modifying Spot Instance Behavior

Key variables to tune:

```hcl
instance_type                 = "t4g.large"     # scale up
spot_price                    = "0.084000"       # higher bid
spot_interruption_behavior    = "terminate"      # auto-terminate on reclaim
spot_type                     = "one-time"       # don't persist after stop
```

## Notes

- **Spot Interruption:** With `spot_type = "persistent"` and `interruption_behavior = "stop"`, the instance stops (not terminates) when reclaimed. It can be restarted manually once capacity returns. The EBS volume persists.
- **Encryption:** Root volume encryption is enabled by default (`root_volume_encrypted = true`).
- **Promtail:** When `promtail_cloudwatch_log_groups` is empty, Promtail installs but has no scrape configs. CloudWatch log groups require the IAM role to have `logs:FilterLogEvents` permissions.
- **ARM64:** The default AMI and all binary downloads target `linux-arm64`. If switching to an x86 instance type, update the AMI and download URLs in `user_data/setup.sh`.
