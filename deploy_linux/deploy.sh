#!/usr/bin/env bash
# =============================================================
# DataEase 2.10 (standalone) Linux 一键部署脚本
# 适用: WK-Zhang886/Dataease 仓库 (含 Excel 导入改造)
# 架构: Nginx(前端 dist, 8088) + Spring Boot 后端(18000) + MariaDB/MySQL + Redis
# 运行: 以 root 或 sudo 执行  bash deploy.sh
# =============================================================
set -euo pipefail

# ---------- 可配置项 ----------
APP_NAME="dataease"
APP_VERSION="2.10.26"
# 源码根目录（脚本所在目录的上级，即 deploy_linux/ 的上级 = 仓库根）
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_MODULE="$SOURCE_DIR/core/core-backend"
FRONTEND_DIR="$SOURCE_DIR/core/core-frontend"

# 运行用户（后端 java 进程以该用户跑）
RUN_USER="dataease"

# 部署数据/日志根目录（后端 yml 与参数里使用）
DATA_ROOT="/opt/dataease2.0"
LOG_PATH="$DATA_ROOT/logs/dataease"

# 后端 jar 名（pom.xml standalone 的 finalName）
JAR_NAME="CoreApplication.jar"

# 初始 admin 密码（substitule 简化登录，账号固定为 admin）
ADMIN_PASSWORD="123456"
SUBSTITULE_JSON="$DATA_ROOT/conf/substitule.json"

# 数据库配置（standalone profile 用 MariaDB/MySQL）
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="dataease10"
DB_USER="root"
DB_PASSWORD="123456"

# Nginx 站点
NGINX_SITE="/etc/nginx/conf.d/dataease.conf"
WEB_ROOT="$DATA_ROOT/webroot"        # 前端 dist 复制到这里由 Nginx 托管
# 端口（独立端口，与服务器上现有平台共存，避免占用 80/8100）
WEB_PORT="8088"                      # DataEase Web 访问端口
BACKEND_PORT="18000"                 # DataEase 后端端口

# ---------- 彩色输出 ----------
c_info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
c_ok()    { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
c_err()   { echo -e "\033[1;31m[ERR ]\033[0m $*"; }
c_warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }

# ---------- 权限检查 ----------
if [[ "$(id -u)" -ne 0 ]]; then
  c_err "请使用 root 或 sudo 运行此脚本"
  exit 1
fi

# ---------- 1. 系统依赖 ----------
c_info "安装系统依赖 (JDK21 / Maven / Node / Nginx / MariaDB / Redis)..."
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y openjdk-21-jdk maven nginx mariadb-server redis-server git curl wget
elif command -v yum >/dev/null 2>&1; then
  yum install -y java-21-openjdk-devel maven nginx mariadb-server redis git wget curl
else
  c_err "未识别的包管理器，请手动安装 JDK21/Maven/Node/Nginx/MariaDB/Redis"
  exit 1
fi
c_ok "系统依赖安装完成"

# ---------- 2. Node 版本检查（构建前端需要） ----------
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/v//' | cut -d. -f1)" -lt 18 ]]; then
  c_info "安装 Node.js 18 LTS..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1 || true
  apt-get install -y nodejs
fi
c_ok "Node: $(node -v)  npm: $(npm -v)"

# ---------- 3. 创建运行用户 ----------
if ! id "$RUN_USER" >/dev/null 2>&1; then
  c_info "创建运行用户 $RUN_USER..."
  useradd -r -s /bin/false "$RUN_USER" || true
fi
c_ok "运行用户 $RUN_USER"

# ---------- 4. 数据库 + Redis ----------
c_info "启动 MariaDB / Redis 并创建数据库..."
systemctl enable --now mariadb redis-server 2>/dev/null || systemctl enable --now mariadb redis 2>/dev/null || true

# 建库建用户（幂等）
mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
c_ok "数据库 $DB_NAME 已创建 (无需手动建表，后端 Flyway 自动建表)"

# ---------- 5. 配置数据库连接（standalone yml） ----------
STANDALONE_YML="$BACKEND_MODULE/src/main/resources/application-standalone.yml"
if [[ -f "$STANDALONE_YML" ]]; then
  c_info "写入数据库连接配置到 application-standalone.yml ..."
  cp "$STANDALONE_YML" "$STANDALONE_YML.bak" 2>/dev/null || true
  cat > "$STANDALONE_YML" <<YML
spring:
  datasource:
    driver-class-name: org.mariadb.jdbc.Driver
    url: jdbc:mariadb://$DB_HOST:$DB_PORT/$DB_NAME?autoReconnect=false&useUnicode=true&characterEncoding=UTF-8&characterSetResults=UTF-8&zeroDateTimeBehavior=convertToNull&useSSL=false&allowPublicKeyRetrieval=true
    username: $DB_USER
    password: $DB_PASSWORD
  messages:
    basename: i18n/lic,i18n/core,i18n/permissions,i18n/xpack,i18n/sync
  flyway:
    enabled: true
    table: de_standalone_version
    validate-on-migrate: false
    locations: classpath:db/migration
    baseline-on-migrate: true
    out-of-order: true

mybatis-plus:
  mapper-locations: classpath:mybatis/*.xml
YML
  c_ok "数据库连接已配置"
else
  c_warn "未找到 application-standalone.yml，跳过数据库配置（请手动配置）"
fi

# ---------- 6. 构建后端 + 前端 ----------
c_info "开始构建后端 (standalone profile)..."
cd "$SOURCE_DIR"
mvn -pl core/core-backend -am -DskipTests clean package
JAR="$BACKEND_MODULE/target/$JAR_NAME"
if [[ ! -f "$JAR" ]]; then
  JAR="$(ls "$BACKEND_MODULE"/target/*.jar 2>/dev/null | head -n1 || true)"
fi
if [[ -z "$JAR" || ! -f "$JAR" ]]; then
  c_err "后端构建产物未找到: $JAR_NAME"
  exit 1
fi
c_ok "后端构建完成: $JAR"

c_info "开始构建前端 (build:base)..."
cd "$FRONTEND_DIR"
npm install
npm run build:base
if [[ ! -d "dist" ]]; then
  c_err "前端构建产物 dist/ 未生成"
  exit 1
fi
c_ok "前端构建完成: $FRONTEND_DIR/dist"

# ---------- 7. 部署目录 + 数据路径 ----------
c_info "准备数据目录..."
mkdir -p "$DATA_ROOT"
mkdir -p "$DATA_ROOT/data/excel" "$DATA_ROOT/data/report" "$DATA_ROOT/data/exportData" \
         "$DATA_ROOT/data/font" "$DATA_ROOT/data/static-resource"
mkdir -p "$DATA_ROOT/cache" "$DATA_ROOT/conf" "$DATA_ROOT/custom-drivers" "$DATA_ROOT/logs"
chown -R "$RUN_USER":"$RUN_USER" "$DATA_ROOT" 2>/dev/null || true

# 复制前端 dist 到 Nginx 根
rm -rf "$WEB_ROOT"
mkdir -p "$WEB_ROOT"
cp -r "$FRONTEND_DIR/dist/." "$WEB_ROOT/"
chown -R "$RUN_USER":"$RUN_USER" "$WEB_ROOT" 2>/dev/null || true
c_ok "前端已部署到 $WEB_ROOT"

# 安装后端 jar
BACKEND_HOME="/opt/$APP_NAME"
mkdir -p "$BACKEND_HOME"
cp "$JAR" "$BACKEND_HOME/$JAR_NAME"
chown -R "$RUN_USER":"$RUN_USER" "$BACKEND_HOME"
c_ok "后端 jar 已安装到 $BACKEND_HOME/$JAR_NAME"

# ---------- 8. systemd 服务 ----------
c_info "生成 systemd 服务..."
cat > /etc/systemd/system/dataease-backend.service <<EOF
[Unit]
Description=DataEase ${APP_NAME} backend
After=network.target mariadb.service redis-server.service redis.service
Wants=mariadb.service redis-server.service

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
c_ok "systemd 服务已创建 (dataease-backend.service)"

# ---------- 9. Nginx ----------
c_info "生成 Nginx 配置..."
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

    # 后端 API 反代（剥离 /de2api 前缀）
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

# ---------- 10. 启动后端 ----------
c_info "启动后端服务..."
systemctl enable dataease-backend.service
systemctl restart dataease-backend.service

# ---------- 完成 ----------
IP=$(hostname -I | awk '{print $1}')
cat <<DONE

============================================================
  部署完成！
  访问地址:  http://$IP:$WEB_PORT
  后端:      http://127.0.0.1:$BACKEND_PORT
  数据库:    MariaDB/MySQL -> $DB_NAME (数据存这里)
  Redis:     缓存
  数据文件:  $DATA_ROOT/data/ (Excel/报表/上传文件)
  日志:      $LOG_PATH

  常用命令:
    查看后端日志:  journalctl -u dataease-backend -f
    重启后端:      systemctl restart dataease-backend
    重启 Nginx:    systemctl reload nginx

  首次登录默认账号 admin，初始密码见后端日志提示。
  请尽快修改数据库密码与管理员密码！
============================================================
DONE
