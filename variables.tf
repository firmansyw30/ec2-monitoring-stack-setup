variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-3"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "monitoring-instance"
}

# ── EC2 ──────────────────────────────────────────────────────────────────────

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 22.04 LTS ARM)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.medium"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "subnet_id" {
  description = "Subnet ID to launch the instance in"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach"
  type        = list(string)
}

# ── Spot ─────────────────────────────────────────────────────────────────────

variable "spot_price" {
  description = "Maximum spot price (USD/hr)"
  type        = string
  default     = "0.042000"
}

variable "spot_type" {
  description = "Spot request type: one-time or persistent"
  type        = string
  default     = "persistent"
}

variable "spot_interruption_behavior" {
  description = "Behavior on spot interruption: stop, terminate, or hibernate"
  type        = string
  default     = "stop"
}

# ── Storage ──────────────────────────────────────────────────────────────────

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "root_volume_iops" {
  description = "Root EBS volume IOPS"
  type        = number
  default     = 3000
}

variable "root_volume_throughput" {
  description = "Root EBS volume throughput in MB/s"
  type        = number
  default     = 125
}

variable "root_volume_encrypted" {
  description = "Enable encryption on the root volume"
  type        = bool
  default     = true
}

# ── Domains ──────────────────────────────────────────────────────────────────

variable "grafana_domain" {
  description = "Domain name for Grafana"
  type        = string
}

variable "prometheus_domain" {
  description = "Domain name for Prometheus"
  type        = string
}

variable "loki_domain" {
  description = "Domain name for Loki"
  type        = string
}

# ── Versions ─────────────────────────────────────────────────────────────────

variable "prometheus_version" {
  description = "Prometheus version to install"
  type        = string
  default     = "3.5.0"
}

variable "promtail_version" {
  description = "Promtail version to install"
  type        = string
  default     = "3.5.5"
}

# ── Prometheus Scrape Targets ────────────────────────────────────────────────

variable "scrape_targets" {
  description = "Map of Prometheus scrape job configurations"
  type = map(object({
    targets        = list(string)
    labels         = optional(map(string), {})
    scrape_timeout = optional(string, "30s")
    metrics_path   = optional(string, "/metrics")
  }))
  default = {}
}

# ── Promtail ─────────────────────────────────────────────────────────────────

variable "promtail_listen_port" {
  description = "Promtail HTTP listen port"
  type        = number
  default     = 9080
}

variable "loki_listen_port" {
  description = "Loki HTTP listen port"
  type        = number
  default     = 3100
}

variable "promtail_cloudwatch_log_groups" {
  description = "List of CloudWatch log groups for Promtail to scrape"
  type        = list(string)
  default     = []
}

# ── Tags ─────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
