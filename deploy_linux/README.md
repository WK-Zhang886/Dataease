# DataEase 2.10 Linux 部署说明

本目录是 **standalone（正式单机部署）** 模式的 Linux 部署文件，基于本仓库源码（含 **Excel 导入逻辑改造**），用于把 DataEase 部署到 Linux 服务器。

**部署方式**：本地编译好后端 `CoreApplication.jar` + 前端 `dist/`，打包上传到服务器，用 `install.sh` 安装（配现有 MySQL）。

## 架构

```
浏览器
  │
  └── Nginx (8088)
        ├── /        → 前端静态文件 (/opt/dataease2.0/webroot)
        └── /de2api/ → 反代到后端 127.0.0.1:18000
                          │
                          └── Spring Boot 后端 (18000) ──→ MySQL (dataease10)
                                                        └──→ Redis (缓存)
```

> **端口**：Web `8088`、后端 `18000`，独立端口，可与其他平台共存。

## 数据存储位置

- **元数据（账号、仪表板、图表、数据集）** → MySQL 的 `dataease10` 库（表结构由 Flyway 自动创建，无需手动建表）
- **上传/生成的文件（Excel、报表、导出）** → `/opt/dataease2.0/data/...`
- **日志** → `/opt/dataease2.0/logs/dataease`

## 部署步骤

### 1. 本地编译

```powershell
# 后端（在 D:\Dataease\core 下）
mvn -pl core-backend -am -DskipTests "-Dmaven.antrun.skip=true" clean package
# 产物: core/core-backend/target/CoreApplication.jar

# 前端（在 core/core-frontend 下）
$env:NODE_OPTIONS="--max_old_space_size=4096"
node node_modules/vite/bin/vite.js build --mode base
# 产物: core/core-frontend/dist
```

### 2. 打包上传

```bash
# 组织部署包
mkdir -p deploy_package
cp core/core-backend/target/CoreApplication.jar deploy_package/
cp -r core/core-frontend/dist deploy_package/dist
cp deploy_linux/install.sh deploy_linux/nginx.conf deploy_linux/dataease-backend.service deploy_package/

# 压缩并上传到服务器
tar -czf deploy_package.tar.gz deploy_package
scp deploy_package.tar.gz root@服务器IP:/root/
```

### 3. 服务器安装

```bash
# 0. 确保服务器已装 JDK21 + Nginx
sudo apt update && sudo apt install -y openjdk-21-jre-headless nginx

# 1. 在现有 MySQL 里建库和账号（如未建）
sudo mysql <<'SQL'
CREATE DATABASE IF NOT EXISTS dataease10 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'dataease'@'localhost' IDENTIFIED BY '123456';
CREATE USER IF NOT EXISTS 'dataease'@'127.0.0.1' IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON dataease10.* TO 'dataease'@'localhost';
GRANT ALL PRIVILEGES ON dataease10.* TO 'dataease'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

# 2. 解压并安装
cd /root
tar -xzf deploy_package.tar.gz
cd deploy_package
chmod +x install.sh
bash install.sh

# 3. 阿里云安全组放行 8088（TCP，授权 0.0.0.0/0）
```

安装完成后访问 `http://服务器IP:8088`，账号 `admin`，密码 `123456`。

## 常见问题

**Q1: 接口 404（登录页打不开 / 一直转圈）？**
多为 Nginx `proxy_pass` 末尾带 `/`，剥离了 `/de2api` 前缀导致。后端接口统一挂在 `/de2api` 前缀下，`proxy_pass` **末尾不能带 `/`**：
```bash
grep proxy_pass /etc/nginx/conf.d/dataease.conf   # 应为 http://127.0.0.1:18000; （无末尾 /）
# 若带 /，修正：
sed -i 's#proxy_pass http://127.0.0.1:18000/;#proxy_pass http://127.0.0.1:18000;#g' /etc/nginx/conf.d/dataease.conf
nginx -t && systemctl reload nginx
```
验证：`curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8088/de2api/model` 应返回 200。

**Q2: 上传大 Excel 一直转圈 / 1 分钟就断？**
前端请求超时由后端参数 `basic.frontTimeOut` 控制（默认 60 秒）。上传大文件需调大：
```bash
mysql -uroot -e "UPDATE dataease10.core_sys_setting SET pval='600' WHERE pkey='basic.frontTimeOut';"
```
（改完刷新浏览器页面生效。同时上传大小限制已在 `application-standalone.yml` 配置为 500MB，Nginx `client_max_body_size 500m`。）

**Q3: 启动日志有 `ClassNotFoundException: oracle.jdbc.driver.OracleDriver` 等？**
无害警告——后端尝试注册各种数据库驱动但缺少对应 jar。DataEase 只用 MySQL，**不影响运行**，可忽略。

**Q4: 外网访问慢？**
DataEase 前端资源较大（几十 MB），在低带宽下首次加载慢属正常。Nginx 已开启 `gzip_static` 压缩传输；二次访问浏览器缓存后秒开。如需更快可提升公网带宽或上 CDN。

**Q5: 忘记 admin 密码？**
密码在 `/opt/dataease2.0/conf/substitule.json`，查看 `pwd` 字段；或重启后端加参数 `--dataease.default-pwd=新密码`。

## 常用命令（服务器上执行）

```bash
systemctl status dataease-backend   # 后端状态
journalctl -u dataease-backend -f   # 实时日志
systemctl restart dataease-backend  # 重启后端
systemctl reload nginx              # 重载 Nginx
ss -tlnp | grep -E '8088|18000'     # 查看端口
```

## 文件清单

| 文件 | 用途 |
|------|------|
| `install.sh` | 部署脚本（配现有 MySQL，装 jar + dist） |
| `nginx.conf` | Nginx 配置模板（`proxy_pass` 末尾**不带** `/`） |
| `dataease-backend.service` | systemd 服务模板 |
| `README.md` | 本说明 |
