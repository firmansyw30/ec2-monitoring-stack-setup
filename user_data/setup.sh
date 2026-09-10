#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

PROMETHEUS_VERSION="$${prometheus_version}"
PROMTAIL_VERSION="$${promtail_version}"

PROMETHEUS_USER="prometheus"
PROMETHEUS_GROUP="prometheus"

PROMETHEUS_CONFIG_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/var/lib/prometheus"

LOKI_CONFIG_DIR="/etc/loki"
LOKI_DATA_DIR="/var/loki"

GRAFANA_DOMAIN="$${grafana_domain}"
PROMETHEUS_DOMAIN="$${prometheus_domain}"
LOKI_DOMAIN="$${loki_domain}"

echo "======================================"
echo " Monitoring Stack Installation"
echo "======================================"

# ============================================================
# 1. System Update
# ============================================================

apt-get update
apt-get upgrade -y

apt-get install -y \
    wget \
    curl \
    unzip \
    tar \
    nginx \
    gnupg \
    apt-transport-https \
    software-properties-common \
    certbot \
    python3-certbot-nginx

# ============================================================
# 2. Prometheus
# ============================================================

echo "[1/7] Installing Prometheus..."

groupadd --system "$${PROMETHEUS_GROUP}" || true

useradd \
    -s /sbin/nologin \
    --system \
    -g "$${PROMETHEUS_GROUP}" \
    "$${PROMETHEUS_USER}" || true

mkdir -p \
    "$${PROMETHEUS_CONFIG_DIR}" \
    "$${PROMETHEUS_DATA_DIR}"

cd /tmp

wget -q \
    "https://github.com/prometheus/prometheus/releases/download/v$${PROMETHEUS_VERSION}/prometheus-$${PROMETHEUS_VERSION}.linux-arm64.tar.gz"

tar xvf \
    "prometheus-$${PROMETHEUS_VERSION}.linux-arm64.tar.gz"

mv \
    "prometheus-$${PROMETHEUS_VERSION}.linux-arm64/prometheus" \
    /usr/local/bin/

mv \
    "prometheus-$${PROMETHEUS_VERSION}.linux-arm64/promtool" \
    /usr/local/bin/

mv \
    "prometheus-$${PROMETHEUS_VERSION}.linux-arm64/consoles" \
    "$${PROMETHEUS_CONFIG_DIR}/"

mv \
    "prometheus-$${PROMETHEUS_VERSION}.linux-arm64/console_libraries" \
    "$${PROMETHEUS_CONFIG_DIR}/"

chown "$${PROMETHEUS_USER}:$${PROMETHEUS_GROUP}" \
    /usr/local/bin/prometheus \
    /usr/local/bin/promtool

chown -R \
    "$${PROMETHEUS_USER}:$${PROMETHEUS_GROUP}" \
    "$${PROMETHEUS_CONFIG_DIR}" \
    "$${PROMETHEUS_DATA_DIR}"

cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple

ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/prometheus/prometheus.yml <<'PROMETHEUS_EOF'
$${prometheus_config}
PROMETHEUS_EOF

/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# ============================================================
# 3. Grafana
# ============================================================

echo "[2/7] Installing Grafana..."

mkdir -p /etc/apt/keyrings

wget -q -O - \
    https://apt.grafana.com/gpg.key \
    | gpg --dearmor \
    | tee /etc/apt/keyrings/grafana.gpg > /dev/null

echo \
    "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    | tee /etc/apt/sources.list.d/grafana.list

apt-get update
apt-get install -y grafana

cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.bak

sed -i \
    "s|^;root_url =.*|root_url = https://$${GRAFANA_DOMAIN}|" \
    /etc/grafana/grafana.ini

systemctl enable grafana-server
systemctl start grafana-server

# ============================================================
# 4. Loki
# ============================================================

echo "[3/7] Configuring Loki..."

mkdir -p \
    "$${LOKI_CONFIG_DIR}" \
    "$${LOKI_DATA_DIR}/chunks" \
    "$${LOKI_DATA_DIR}/rules" \
    "$${LOKI_DATA_DIR}/compactor"

cat > "$${LOKI_CONFIG_DIR}/loki-config.yml" <<'LOKI_EOF'
$${loki_config}
LOKI_EOF

cat > /etc/systemd/system/loki.service <<'EOF'
[Unit]
Description=Loki Log Aggregator
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/loki \
  -config.file=/etc/loki/loki-config.yml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable loki
systemctl start loki

# ============================================================
# 5. Promtail
# ============================================================

echo "[4/7] Installing Promtail..."

cd /tmp

wget -q \
    "https://github.com/grafana/loki/releases/download/v$${PROMTAIL_VERSION}/promtail-linux-arm64.zip"

unzip -o promtail-linux-arm64.zip

chmod +x promtail-linux-arm64

mv promtail-linux-arm64 /usr/local/bin/promtail

cat > /etc/loki/promtail-config.yml <<'PROMTAIL_EOF'
$${promtail_config}
PROMTAIL_EOF

cat > /etc/systemd/system/promtail.service <<'EOF'
[Unit]
Description=Promtail
Wants=network-online.target
After=network-online.target

[Service]
Type=simple

ExecStart=/usr/local/bin/promtail \
  -config.file=/etc/loki/promtail-config.yml

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

# ============================================================
# 6. Nginx Reverse Proxy
# ============================================================

echo "[5/7] Configuring Nginx..."

cat > /etc/nginx/sites-available/grafana.conf <<'NGINX_GRAFANA_EOF'
$${nginx_grafana}
NGINX_GRAFANA_EOF

cat > /etc/nginx/sites-available/prometheus.conf <<'NGINX_PROMETHEUS_EOF'
$${nginx_prometheus}
NGINX_PROMETHEUS_EOF

cat > /etc/nginx/sites-available/loki.conf <<'NGINX_LOKI_EOF'
$${nginx_loki}
NGINX_LOKI_EOF

ln -sf \
    /etc/nginx/sites-available/grafana.conf \
    /etc/nginx/sites-enabled/grafana.conf

ln -sf \
    /etc/nginx/sites-available/prometheus.conf \
    /etc/nginx/sites-enabled/prometheus.conf

ln -sf \
    /etc/nginx/sites-available/loki.conf \
    /etc/nginx/sites-enabled/loki.conf

rm -f /etc/nginx/sites-enabled/default

nginx -t

systemctl enable nginx
systemctl reload nginx

# ============================================================
# 7. SSL/TLS
# ============================================================

echo "[6/7] Generating SSL certificates..."

certbot --nginx \
    --non-interactive \
    --agree-tos \
    --redirect \
    -d "$${GRAFANA_DOMAIN}"

certbot --nginx \
    --non-interactive \
    --agree-tos \
    --redirect \
    -d "$${PROMETHEUS_DOMAIN}"

certbot --nginx \
    --non-interactive \
    --agree-tos \
    --redirect \
    -d "$${LOKI_DOMAIN}"

# ============================================================
# 8. Final Verification
# ============================================================

echo "[7/7] Verifying services..."

systemctl --no-pager --full status prometheus || true
systemctl --no-pager --full status grafana-server || true
systemctl --no-pager --full status loki || true
systemctl --no-pager --full status promtail || true
systemctl --no-pager --full status nginx || true

echo ""
echo "======================================"
echo " Listening Ports"
echo "======================================"

ss -tuln | grep -E '3000|9090|3100|9080|80|443' || true

echo ""
echo "======================================"
echo " Prometheus Metrics"
echo "======================================"

curl -f http://localhost:9090/metrics >/dev/null \
    && echo "Prometheus OK" \
    || echo "Prometheus FAILED"

echo ""
echo "======================================"
echo " Loki Metrics"
echo "======================================"

curl -f http://localhost:3100/metrics >/dev/null \
    && echo "Loki OK" \
    || echo "Loki FAILED"

echo ""
echo "======================================"
echo " Installation Complete"
echo "======================================"

echo "Grafana     : https://$${GRAFANA_DOMAIN}"
echo "Prometheus  : https://$${PROMETHEUS_DOMAIN}"
echo "Loki        : https://$${LOKI_DOMAIN}"
