#!/bin/bash
# =========================================================
# 幂等安装 Zabbix Agent 7.0.20 (静态版) for CentOS/RHEL
# 特点：
#   - 可重复执行（幂等），不会粗暴覆盖已有调优配置
#   - 二进制/配置/systemd 发生变化才重启
#   - systemd 使用 Type=simple + 前台运行 (-f)
#   - 日志使用 logrotate + copytruncate，无需 reload/restart
#   - 支持参数：--server-ip / --hostname / --no-firewall / --no-restart
# =========================================================

set -e

# ---------- 日志输出函数 ----------
info()  { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# ---------- 基础配置 ----------
ZBX_VERSION="7.0.20"
ZBX_URL="https://cdn.zabbix.com/zabbix/binaries/stable/7.0/${ZBX_VERSION}/zabbix_agent-${ZBX_VERSION}-linux-3.0-amd64-static.tar.gz"

# 若有官方 SHA256 可填在此；为空则不校验
ZBX_SHA256=""

INSTALL_DIR="/opt/zabbix"
CONF_DIR="/etc/zabbix"
LOG_DIR="/var/log/zabbix"
SYSTEMD_FILE="/etc/systemd/system/zabbix-agent.service"
LOGROTATE_FILE="/etc/logrotate.d/zabbix_agentd"

CONF_FILE="${CONF_DIR}/zabbix_agentd.conf"

# ---------- 参数处理 ----------
SERVER_IP="${ZABBIX_SERVER_IP:-}"
HOSTNAME_OVERRIDE="${ZABBIX_AGENT_HOSTNAME:-}"
NO_FIREWALL=0
NO_RESTART=0

usage() {
  cat <<EOF
用法: $0 [选项]

选项:
  --server-ip IP        设置 Zabbix Server IP（也可用环境变量 ZABBIX_SERVER_IP）
  --hostname NAME       设置 Agent Hostname（也可用环境变量 ZABBIX_AGENT_HOSTNAME）
  --no-firewall         不自动修改 firewalld 规则
  --no-restart          不自动重启/启动 zabbix-agent 服务
  -h, --help            显示本帮助并退出

示例:
  $0 --server-ip 10.10.10.50
  ZABBIX_SERVER_IP=10.10.10.50 $0 --no-restart
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --server-ip=*)
      SERVER_IP="${1#*=}"
      ;;
    --server-ip)
      shift
      SERVER_IP="$1"
      ;;
    --hostname=*)
      HOSTNAME_OVERRIDE="${1#*=}"
      ;;
    --hostname)
      shift
      HOSTNAME_OVERRIDE="$1"
      ;;
    --no-firewall)
      NO_FIREWALL=1
      ;;
    --no-restart)
      NO_RESTART=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "未知参数: $1（使用 -h 查看帮助）"
      ;;
  esac
  shift
done

# 如果仍未指定 SERVER_IP，则给默认值并提示
if [ -z "$SERVER_IP" ]; then
  SERVER_IP="10.10.10.50"
  warn "未显式指定 Zabbix Server IP，使用默认值：$SERVER_IP"
fi

# Hostname 默认使用系统 hostname
if [ -z "$HOSTNAME_OVERRIDE" ]; then
  HOSTNAME_OVERRIDE=$(hostname)
fi

# ---------- 权限与系统检查 ----------
if [ "$EUID" -ne 0 ]; then
  error "请使用 root 权限运行！（例如：sudo bash $0 ...）"
fi

ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
  error "当前架构为 ${ARCH}，仅支持 x86_64/amd64 架构的静态版 Zabbix Agent。"
fi

if [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  if ! echo "$OS_ID $OS_LIKE" | grep -qiE 'centos|rhel|rocky|alma'; then
    warn "未检测到 CentOS/RHEL/兼容发行版（ID=${OS_ID}，ID_LIKE=${OS_LIKE}），可能存在兼容性问题。"
  fi
else
  warn "/etc/os-release 不存在，无法识别系统类型，继续安装但可能存在兼容风险。"
fi

# ---------- 检测已有 zabbix-agent 服务 ----------
if systemctl list-unit-files 2>/dev/null | grep -q '^zabbix-agent\.service'; then
  info "系统中已存在 zabbix-agent systemd 单元（可能来自 RPM 或旧安装）。"
fi

# ---------- 安装依赖 ----------
info "安装依赖包 curl、tar..."
PKG_MGR=$(command -v yum || command -v dnf || true)
if [ -z "$PKG_MGR" ]; then
  error "未找到 yum/dnf 包管理器，请确认当前系统是否为 CentOS/RHEL 系。"
fi

$PKG_MGR install -y curl tar >/dev/null 2>&1 || error "安装依赖包失败，请检查软件源配置。"

# ---------- 记录原有文件 checksum（用于判断是否变化） ----------
MD5_AVAILABLE=0
if command -v md5sum >/dev/null 2>&1; then
  MD5_AVAILABLE=1
fi

OLD_BIN_CHECKSUM=""
OLD_CONF_CHECKSUM=""
OLD_UNIT_CHECKSUM=""

if [ "$MD5_AVAILABLE" -eq 1 ]; then
  if [ -f /usr/sbin/zabbix_agentd ]; then
    OLD_BIN_CHECKSUM=$(md5sum /usr/sbin/zabbix_agentd | awk '{print $1}')
  fi
  if [ -f "$CONF_FILE" ]; then
    OLD_CONF_CHECKSUM=$(md5sum "$CONF_FILE" | awk '{print $1}')
  fi
  if [ -f "$SYSTEMD_FILE" ]; then
    OLD_UNIT_CHECKSUM=$(md5sum "$SYSTEMD_FILE" | awk '{print $1}')
  fi
fi

NEED_RESTART=0
UNIT_CHANGED=0

# ---------- 准备安装目录 ----------
info "准备安装目录：$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ---------- 下载 Zabbix Agent ----------
info "下载 Zabbix Agent 静态包..."
curl -fSL "$ZBX_URL" -o zabbix_agent.tar.gz || error "下载失败，请检查网络或 Zabbix CDN 是否可达。"

# ---------- 可选：SHA256 校验 ----------
if command -v sha256sum >/dev/null 2>&1 && [ -n "$ZBX_SHA256" ]; then
  info "校验下载包 SHA256..."
  echo "$ZBX_SHA256  zabbix_agent.tar.gz" | sha256sum -c - || error "SHA256 校验失败，请确认下载包是否完整/未被篡改。"
else
  warn "未配置 SHA256 或系统无 sha256sum 命令，跳过完整性校验。"
fi

# ---------- 解压 ----------
info "解压 Zabbix Agent 包..."
tar -zxf zabbix_agent.tar.gz --strip-components=1

# ---------- 安装二进制 ----------
info "安装二进制文件到系统路径..."
install -m 0755 sbin/zabbix_agentd /usr/sbin/zabbix_agentd
install -m 0755 bin/zabbix_get      /usr/bin/zabbix_get
install -m 0755 bin/zabbix_sender   /usr/bin/zabbix_sender

if [ "$MD5_AVAILABLE" -eq 1 ]; then
  NEW_BIN_CHECKSUM=$(md5sum /usr/sbin/zabbix_agentd | awk '{print $1}')
  if [ "$OLD_BIN_CHECKSUM" != "$NEW_BIN_CHECKSUM" ]; then
    info "Zabbix Agent 二进制有变更，将标记为需要重启。"
    NEED_RESTART=1
  fi
else
  NEED_RESTART=1
fi

# ---------- 创建 zabbix 用户 ----------
if id zabbix &>/dev/null; then
  info "用户 zabbix 已存在，跳过创建。"
else
  info "创建系统用户 zabbix（不可登录，无 home）..."
  useradd -r -M -s /sbin/nologin zabbix
fi

# ---------- 配置文件处理 ----------
info "配置 Zabbix Agent 配置文件..."
mkdir -p "$CONF_DIR"

# 第一次存在旧配置时进行初始备份
if [ -f "$CONF_FILE" ] && [ ! -f "${CONF_FILE}.bak.initial" ]; then
  cp "$CONF_FILE" "${CONF_FILE}.bak.initial"
  warn "检测到已有配置文件，已备份初始版本为：${CONF_FILE}.bak.initial"
fi

# 如果系统完全没有配置文件，则尝试用 conf/ 模板创建一次
if [ ! -f "$CONF_FILE" ]; then
  if [ -f conf/zabbix_agentd.conf ]; then
    info "系统中不存在配置文件，使用模板 conf/zabbix_agentd.conf 初始化。"
    cp conf/zabbix_agentd.conf "$CONF_FILE"
  else
    error "未找到模板 conf/zabbix_agentd.conf，且系统中不存在旧配置，无法生成配置文件。"
  fi
fi

# 封装一个帮助函数：更新或追加键值（外科手术式修改）
set_or_append_key() {
  local KEY="$1"
  local VALUE="$2"
  local FILE="$3"
  # 兼容前面有注释/空格的写法：^[#空白]*KEY=
  if grep -Eq "^[#[:space:]]*${KEY}=" "$FILE"; then
    sed -i -E "s|^[#[:space:]]*${KEY}=.*|${KEY}=${VALUE}|" "$FILE"
  else
    echo "${KEY}=${VALUE}" >> "$FILE"
  fi
}

# 修改关键项（只改不覆盖）
set_or_append_key "Server"       "${SERVER_IP}"           "$CONF_FILE"
set_or_append_key "ServerActive" "${SERVER_IP}"           "$CONF_FILE"
set_or_append_key "Hostname"     "${HOSTNAME_OVERRIDE}"   "$CONF_FILE"
set_or_append_key "LogFile"      "${LOG_DIR}/zabbix_agentd.log" "$CONF_FILE"

# PidFile：在 Type=simple + -f 模式下不再使用，尽量禁用
if grep -Eq "^[#[:space:]]*PidFile=" "$CONF_FILE"; then
  sed -i -E "s|^[#[:space:]]*PidFile=.*|# PidFile disabled (managed by systemd foreground mode)|" "$CONF_FILE"
fi

# ListenIP：监听所有 IP
set_or_append_key "ListenIP" "0.0.0.0" "$CONF_FILE"

if [ "$MD5_AVAILABLE" -eq 1 ]; then
  NEW_CONF_CHECKSUM=$(md5sum "$CONF_FILE" | awk '{print $1}')
  if [ "$OLD_CONF_CHECKSUM" != "$NEW_CONF_CHECKSUM" ]; then
    info "配置文件有变更，将标记为需要重启。"
    NEED_RESTART=1
  fi
else
  NEED_RESTART=1
fi

# ---------- 日志目录与权限 ----------
info "配置日志目录：$LOG_DIR"
mkdir -p "$LOG_DIR"
chown -R zabbix:zabbix "$LOG_DIR"

# ---------- logrotate 配置（使用 copytruncate，无需 reload/restart） ----------
if [ -f "$LOGROTATE_FILE" ]; then
  info "logrotate 配置已存在：$LOGROTATE_FILE"
else
  info "创建 logrotate 配置：$LOGROTATE_FILE"
  cat > "$LOGROTATE_FILE" <<EOF
${LOG_DIR}/zabbix_agentd.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
    create 0640 zabbix zabbix
}
EOF
fi

# ---------- 防火墙 ----------
if [ "$NO_FIREWALL" -eq 1 ]; then
  warn "根据 --no-firewall 参数，跳过防火墙配置。"
else
  info "检查并配置 firewalld（如适用）..."
  if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=10050/tcp >/dev/null 2>&1 || warn "firewalld 添加端口规则失败，请手动检查。"
    firewall-cmd --reload >/dev/null 2>&1 || warn "firewalld reload 失败，请手动检查。"
    info "已通过 firewalld 放行 10050/TCP 端口。"
  else
    warn "firewalld 未运行或未安装，跳过防火墙配置（如有需要请自行放行 10050/TCP）。"
  fi
fi

# ---------- 创建/更新 systemd 单元（Type=simple 前台运行） ----------
info "创建/更新 systemd 单元文件：$SYSTEMD_FILE"
cat > "${SYSTEMD_FILE}.tmp" <<EOF
[Unit]
Description=Zabbix Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/zabbix_agentd -f -c ${CONF_FILE}
User=zabbix
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

if [ "$MD5_AVAILABLE" -eq 1 ] && [ -f "$SYSTEMD_FILE" ]; then
  NEW_UNIT_CHECKSUM=$(md5sum "${SYSTEMD_FILE}.tmp" | awk '{print $1}')
  if [ "$OLD_UNIT_CHECKSUM" != "$NEW_UNIT_CHECKSUM" ]; then
    UNIT_CHANGED=1
  fi
else
  UNIT_CHANGED=1
fi

mv "${SYSTEMD_FILE}.tmp" "$SYSTEMD_FILE"

if [ "$UNIT_CHANGED" -eq 1 ]; then
  info "systemd 单元文件有变更，将重新 daemon-reload。"
  systemctl daemon-reload
else
  info "systemd 单元文件未变化。"
fi

# ---------- 服务启动 / 重启逻辑 ----------
ACTIVE=0
if systemctl is-active --quiet zabbix-agent; then
  ACTIVE=1
fi

if [ "$NO_RESTART" -eq 1 ]; then
  warn "根据 --no-restart 参数，不自动启动/重启 zabbix-agent。"
else
  systemctl enable zabbix-agent >/dev/null 2>&1 || true

  if [ "$ACTIVE" -eq 0 ]; then
    info "zabbix-agent 当前未运行，将尝试启动..."
    systemctl start zabbix-agent || error "启动 zabbix-agent 服务失败，请检查 systemd 日志。"
  else
    if [ "$NEED_RESTART" -eq 1 ]; then
      info "检测到二进制/配置有变更，将重启 zabbix-agent..."
      systemctl restart zabbix-agent || error "重启 zabbix-agent 服务失败，请检查 systemd 日志。"
    else
      info "二进制与关键配置无变化，保持现有 zabbix-agent 进程，不重启。"
    fi
  fi
fi

# ---------- 端口检查 ----------
sleep 2
if ss -tuln | grep -q ":10050 "; then
  info "✅ Zabbix Agent 已成功监听 10050/TCP。"
else
  warn "⚠️ 未检测到 10050/TCP 监听，Zabbix Agent 可能未正常运行，请检查日志：$LOG_DIR/zabbix_agentd.log"
fi

# ---------- 自测 ----------
if command -v zabbix_get >/dev/null 2>&1; then
  info "执行自测：zabbix_get -s 127.0.0.1 -p 10050 -k agent.ping ..."
  if zabbix_get -s 127.0.0.1 -p 10050 -k agent.ping 2>/dev/null | grep -q '^1$'; then
    info "✅ 自测通过：Zabbix Agent 正常响应 (agent.ping=1)。"
  else
    warn "⚠️ 自测失败：未获得 agent.ping=1，请检查日志：$LOG_DIR/zabbix_agentd.log"
  fi
else
  warn "未找到 zabbix_get 命令，跳过自测。"
fi

# ---------- 完成信息 ----------
echo ""
info "🎉 Zabbix Agent 安装/更新 已完成（幂等 + 安全配置版）。"
echo "---------------------------------------------"
echo "Zabbix Server IP：$SERVER_IP"
echo "Agent Hostname：$HOSTNAME_OVERRIDE"
echo "配置文件：$CONF_FILE"
echo "日志文件：$LOG_DIR/zabbix_agentd.log"
echo "systemd 单元：$SYSTEMD_FILE"
echo "logrotate 配置：$LOGROTATE_FILE"
echo "服务管理：systemctl {start|stop|restart|status} zabbix-agent"
echo "---------------------------------------------"
echo "如遇问题，请优先查看："
echo "  - $LOG_DIR/zabbix_agentd.log"
echo "  - journalctl -u zabbix-agent"
