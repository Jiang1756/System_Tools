#!/bin/bash
# =========================================================
# 一键安装 Zabbix Agent 7.0.20 (静态版) for CentOS (curl 版)
# by ChatGPT - 2025-11 增强版（含自测）
# =========================================================

set -e
info() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# ---------- 基础配置 ----------
ZBX_URL="https://cdn.zabbix.com/zabbix/binaries/stable/7.0/7.0.20/zabbix_agent-7.0.20-linux-3.0-amd64-static.tar.gz"
INSTALL_DIR="/opt/zabbix"
CONF_DIR="/etc/zabbix"
LOG_DIR="/var/log/zabbix"
SYSTEMD_FILE="/etc/systemd/system/zabbix-agent.service"
SERVER_IP="10.10.10.50"   # ✅ 固定 Zabbix Server 地址

# ---------- 权限检查 ----------
if [ "$EUID" -ne 0 ]; then
  error "请使用 root 权限运行此脚本！(sudo bash install_zabbix_agent_centos.sh)"
fi

# ---------- 安装依赖 ----------
info "检查依赖..."
yum install -y curl tar >/dev/null

# ---------- 下载 ----------
info "下载 Zabbix Agent..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
curl -fSL "$ZBX_URL" -o zabbix_agent.tar.gz || error "下载失败，请检查网络！"

# ---------- 解压 ----------
info "解压文件..."
tar -zxf zabbix_agent.tar.gz

# ---------- 安装二进制 ----------
info "复制可执行文件..."
cp sbin/zabbix_agentd /usr/sbin/
cp bin/zabbix_get /usr/bin/
cp bin/zabbix_sender /usr/bin/

# ---------- 创建用户 ----------
id zabbix &>/dev/null || useradd -r -M -s /sbin/nologin zabbix

# ---------- 配置文件 ----------
info "配置 Zabbix Agent..."
mkdir -p "$CONF_DIR"
cp conf/zabbix_agentd.conf "$CONF_DIR/zabbix_agentd.conf"

HOSTNAME=$(hostname)

sed -i "s/^Server=.*/Server=${SERVER_IP}/" "$CONF_DIR/zabbix_agentd.conf"
sed -i "s/^ServerActive=.*/ServerActive=${SERVER_IP}/" "$CONF_DIR/zabbix_agentd.conf"
sed -i "s/^Hostname=.*/Hostname=${HOSTNAME}/" "$CONF_DIR/zabbix_agentd.conf"
sed -i "s|^LogFile=.*|LogFile=${LOG_DIR}/zabbix_agentd.log|" "$CONF_DIR/zabbix_agentd.conf"

# 确保监听所有 IP
grep -q "^ListenIP" "$CONF_DIR/zabbix_agentd.conf" \
  && sed -i "s/^ListenIP=.*/ListenIP=0.0.0.0/" "$CONF_DIR/zabbix_agentd.conf" \
  || echo "ListenIP=0.0.0.0" >> "$CONF_DIR/zabbix_agentd.conf"

mkdir -p "$LOG_DIR"
chown -R zabbix:zabbix "$LOG_DIR"

# ---------- 防火墙 ----------
info "配置防火墙规则..."
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=10050/tcp >/dev/null
  firewall-cmd --reload >/dev/null
  info "已放行 10050/TCP 端口"
else
  warn "firewalld 未运行，跳过防火墙配置"
fi

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
info "启动 Zabbix Agent..."
systemctl daemon-reload
systemctl enable --now zabbix-agent
sleep 2

if ss -tuln | grep -q ":10050"; then
  info "✅ Zabbix Agent 已成功运行 (端口: 10050/TCP)"
else
  error "❌ Zabbix Agent 启动失败，请查看日志：$LOG_DIR/zabbix_agentd.log"
fi

# ---------- 自测 ----------
info "执行自测 (agent.ping)..."
if /usr/bin/zabbix_get -s 127.0.0.1 -p 10050 -k agent.ping 2>/dev/null | grep -q '^1$'; then
  info "✅ 自测通过：Zabbix Agent 正常响应 (agent.ping=1)"
else
  warn "⚠️ 自测未通过：Zabbix Agent 未返回有效响应，请检查日志：$LOG_DIR/zabbix_agentd.log"
fi

# ---------- 完成 ----------
echo ""
info "🎉 安装完成！"
echo "配置文件：$CONF_DIR/zabbix_agentd.conf"
echo "日志文件：$LOG_DIR/zabbix_agentd.log"
echo "Zabbix Server IP：$SERVER_IP"
echo "服务命令：systemctl {start|stop|restart|status} zabbix-agent"