#!/usr/bin/env bash
# =============================================================
# DataEase 2.10 standalone 服务器安装脚本（产物版）
# 适用: WK-Zhang886/Dataease 仓库（含 Excel 导入改造）
# 前提: 服务器已有 MySQL，且已创建 dataease10 库 + dataease 账号
#      产物: CoreApplication.jar(后端) + dist(前端) 已在本地编译好
# 运行: 以 root 或 sudo 执行  bash install.sh
# 架构: Nginx(8088 前端) + Spring Boot 后端(18000) + 现有MySQL + Redis
# =============================================================
set -euo pipefail

# ---------- 可配置项 ----------
APP_NAME="dataease"
JAR_NAME="CoreApplication.jar"
# 脚本所在目录（即打包后的 install 目录，含 jar 和 dist）
PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 运行用户
RUN_USER="dataease"

# 部署数据/日志根目录
DATA_ROOT="/opt/dataease2.0"
BACKEND_HOME="/opt/$APP_NAME"
WEB_ROOT="$DATA_ROOT/webroot"
LOG_PATH="$DATA_ROOT/logs/dataease"
SUBSTITULE_JSON="$DATA_ROOT/conf/substitule.json"

# 初始 admin 密码
ADMIN_PASSWORD="123456"

# 端口
WEB_PORT="8088"
BACKEND_PORT="18000"

# Nginx 站点
NGINX_SITE="/etc/nginx/conf.d/dataease.conf"

# ---------- 彩色输出 ----------
c_info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
c_ok()   { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
c_err()  { echo -e "\033[1;31m[ERR ]\033[0m $*"; }

# ---------- 权限检查 ----------
if [[ "$(id -u)" -ne 0 ]]; then
  c_err "请使用 root 或 sudo 运行此脚本"
  exit 1
fi

# ---------- 1. 检查产物 ----------
if [[ ! -f "$PKG_DIR/$JAR_NAME" ]]; then
  c_err "未找到后端产物: $PKG_DIR/$JAR_NAME"
  exit 1
fi
if [[ ! -d "$PKG_DIR/dist" ]]; then
  c_err "未找到前端产物目录: $PKG_DIR/dist"
  exit 1
fi
c_ok "产物检查通过 (jar + dist)"

# ---------- 2. 检查系统依赖 ----------
for cmd in java nginx; do
  if ! command -v $cmd >/dev/null 2>&1; then
    c_err "缺少命令: $cmd，请先安装 (java: JDK21, nginx: nginx)"
    exit 1
  fi
done
c_ok "系统依赖: $(java -version 2>&1 | head -n1) / $(nginx -v 2>&1)"

# ---------- 3. 创建运行用户 ----------
if ! id "$RUN_USER" >/dev/null 2>&1; then
  c_info "创建运行用户 $RUN_USER..."
  useradd -r -s /bin/false "$RUN_USER" || true
fi
c_ok "运行用户 $RUN_USER"

# ---------- 4. 准备数据目录 ----------
c_info "准备数据目录..."
mkdir -p "$DATA_ROOT"
mkdir -p "$DATA_ROOT/data/excel" "$DATA_ROOT/data/report" "$DATA_ROOT/data/exportData" \
         "$DATA_ROOT/data/font" "$DATA_ROOT/data/static-resource"
mkdir -p "$DATA_ROOT/cache" "$DATA_ROOT/conf" "$DATA_ROOT/custom-drivers" "$DATA_ROOT/logs"
chown -R "$RUN_USER":"$RUN_USER" "$DATA_ROOT" 2>/dev/null || true
c_ok "数据目录就绪 $DATA_ROOT"

# ---------- 5. 部署前端 dist ----------
c_info "部署前端到 $WEB_ROOT ..."
rm -rf "$WEB_ROOT"
mkdir -p "$WEB_ROOT"
cp -r "$PKG_DIR/dist/." "$WEB_ROOT/"
chown -R "$RUN_USER":"$RUN_USER" "$WEB_ROOT" 2>/dev/null || true
c_ok "前端已部署"

# ---------- 6. 部署后端 jar ----------
c_info "部署后端到 $BACKEND_HOME ..."
mkdir -p "$BACKEND_HOME"
cp "$PKG_DIR/$JAR_NAME" "$BACKEND_HOME/$JAR_NAME"
chown -R "$RUN_USER":"$RUN_USER" "$BACKEND_HOME"
c_ok "后端 jar 已部署"

# ---------- 7. systemd 服务 ----------
c_info "生成 systemd 服务 (端口 $BACKEND_PORT)..."
cat > /etc/systemd/system/dataease-backend.service <<EOF
[Unit]
Description=DataEase ${APP_NAME} backend
After=network.target
Wants=network.target

[Service]
Type=simple
User=$RUN_USER
Group=$RUN_USER
WorkingDirectory=$BACKEND_HOME
ExecStart=/usr/bin/java -Xms512m -Xmx4g -jar $BACKEND_HOME/$JAR_NAME \\
  --server.port=$BACKEND_PORT \\
  --spring.profiles.active=standalone \\
  --dataease.default-pwd=$ADMIN_PASSWORD \\
  --dataease.path.substitule=$SUBSTITULE_JSON \\
  --logging.file.path=$LOG_PATH \\
  --dataease.path.excel=$DATA_ROOT/data/excel/ \\
  --dataease.path.report=$DATA_ROOT/data/report/ \\
  --dataease.path.exportData=$DATA_ROOT/data/exportData/ \\
  --dataease.path.font=$DATA_ROOT/data/font/ \\
  --dataease.path.static-resource=$DATA_ROOT/data/static-resource/ \\
  --dataease.path.ehcache=$DATA_ROOT/cache \\
  --dataease.path.share-secret=$DATA_ROOT/conf/share-secret.json \\
  --dataease.path.custom-drivers=$DATA_ROOT/custom-drivers/
Restart=on-failure
RestartSec=5
SuccessExitStatus=143
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable dataease-backend.service
c_ok "systemd 服务已创建"

# ---------- 8. Nginx ----------
c_info "生成 Nginx 配置 (端口 $WEB_PORT)..."
cat > "$NGINX_SITE" <<EOF
server {
    listen $WEB_PORT;
    server_name _;
    client_max_body_size 500m;

    root $WEB_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /de2api/ {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_connect_timeout 60s;
    }
}
EOF
nginx -t && systemctl reload nginx || { c_err "Nginx 配置错误"; exit 1; }
c_ok "Nginx 已配置"

# ---------- 9. 启动后端 ----------
c_info "启动后端服务..."
systemctl restart dataease-backend.service
sleep 3

# ---------- 完成 ----------
IP=$(hostname -I | awk '{print $1}')
cat <<DONE

============================================================
  安装完成！
  访问地址:  http://$IP:$WEB_PORT
  后端:      http://127.0.0.1:$BACKEND_PORT
  数据库:    现有 MySQL -> dataease10 (dataease/123456)
  数据文件:  $DATA_ROOT/data/
  日志:      $LOG_PATH

  常用命令:
    查看后端日志:  journalctl -u dataease-backend -f
    重启后端:      systemctl restart dataease-backend
    重启 Nginx:    systemctl reload nginx

  首次登录: 账号 admin，密码 $ADMIN_PASSWORD
  请尽快修改数据库密码与管理密码！
============================================================
DONE
