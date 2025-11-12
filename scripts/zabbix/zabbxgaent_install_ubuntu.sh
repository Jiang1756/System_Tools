#!/bin/bash
# ---------- 基本配置 ----------
ZBX_VERSION="7.0.20"
ZBX_URL="https://cdn.zabbix.com/zabbix/binaries/stable/7.0/${ZBX_VERSION}/zabbix_agent-${ZBX_VERSION}-linux-3.0-amd64-static.tar.gz"
INSTALL_DIR="/opt/zabbix"
CONF_DIR="/etc/zabbix"
LOG_DIR="/var/log/zabbix"
SYSTEMD_FILE="/etc/systemd/system/zabbix-agent.service"
SERVER_IP="10.10.10.50"   # ⚠️ 修改为你的 Zabbix Server IP

# ---------- 函数 ----------
set -e

info() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# ---------- 检查权限 ----------
if [ "$EUID" -ne 0 ]; then
  error "请使用 root 权限运行此脚本！(sudo bash install_zabbix_agent_ubuntu.sh)"
fi

# ---------- 检查依赖 ----------
info "检查依赖..."
apt-get update -qq
apt-get install -y wget tar vim net-tools >/dev/null

# ---------- 下载 ----------
info "下载 Zabbix Agent..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
wget -q --show-progress "$ZBX_URL" -O zabbix_agent.tar.gz || error "下载失败，请检查网络！"

# ---------- 解压 ----------
info "解压文件..."
tar -zxf zabbix_agent.tar.gz
cd zabbix_agent-${ZBX_VERSION}-linux-3.0-amd64-static

# ---------- 安装二进制 ----------
info "复制可执行文件..."
cp sbin/zabbix_agentd /usr/sbin/
cp bin/zabbix_get /usr/bin/
cp bin/zabbix_sender /usr/bin/

# ---------- 创建 zabbix 用户 ----------
id zabbix &>/dev/null || useradd -r -M -s /usr/sbin/nologin zabbix

# ---------- 配置文件 ----------
info "配置文件..."
mkdir -p "$CONF_DIR"
cp conf/zabbix_agentd.conf "$CONF_DIR/zabbix_agentd.conf"

HOSTNAME=$(hostname)

sed -i "s/^Server=.*/Server=${SERVER_IP}/" "$CONF_DIR/zabbix_agentd.conf"
sed -i "s/^ServerActive=.*/ServerActive=${SERVER_IP}/" "$CONF_DIR/zabbix_agentd.conf"
sed -i "s/^Hostname=.*/Hostname=${HOSTNAME}/" "$CONF_DIR/zabbix_agentd.conf"
sed -i "s|^LogFile=.*|LogFile=${LOG_DIR}/zabbix_agentd.log|" "$CONF_DIR/zabbix_agentd.conf"

# ---------- 日志目录 ----------
mkdir -p "$LOG_DIR"
chown -R zabbix:zabbix "$LOG_DIR"

# ---------- 创建 systemd 服务 ----------
info "创建 systemd 服务..."
cat > "$SYSTEMD_FILE" <<'EOF'
[Unit]
Description=Zabbix Agent
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/zabbix_agentd -c /etc/zabbix/zabbix_agentd.conf
ExecStop=/usr/bin/pkill zabbix_agentd
User=zabbix
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# ---------- 启动服务 ----------
info "启动并启用 Zabbix Agent..."
systemctl daemon-reload
systemctl enable --now zabbix-agent

sleep 2
systemctl status zabbix-agent --no-pager

# ---------- 验证 ----------
if netstat -tulnp 2>/dev/null | grep -q 10050; then
  info "✅ Zabbix Agent 已成功运行 (端口: 10050)"
else
  error "❌ Zabbix Agent 未启动，请检查日志：$LOG_DIR/zabbix_agentd.log"
fi

# ---------- 完成 ----------
echo ""
info "🎉 安装完成！"
echo "配置文件：$CONF_DIR/zabbix_agentd.conf"
echo "日志文件：$LOG_DIR/zabbix_agentd.log"
echo "服务管理：systemctl {start|stop|restart|status} zabbix-agent"
