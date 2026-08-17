# DataEase 2.10 Linux 部署说明

本目录是 **standalone（正式单机部署）** 模式的 Linux 部署文件，基于本仓库源码
（含 **Excel 导入逻辑改造**），用于把 DataEase 部署到 Linux 服务器，打开网页直接使用。

## 架构

```
浏览器
  │
  └── Nginx (8088)
        ├── /        → 前端静态文件 (core-frontend/dist 构建产物)
        └── /de2api/ → 反代到后端 127.0.0.1:18000 (剥离 de2api 前缀)
                          │
                          └── Spring Boot 后端 (18000) ──→ MariaDB/MySQL (dataease10)
                                                        └──→ Redis (缓存)
```

> **端口说明**：本部署使用**独立端口**（Web `8088`、后端 `18000`），
> 避免与服务器上**已运行的平台**（占用 80/Nginx）冲突，可共存运行。
> 如服务器 8088/18000 已被占用，可在 `deploy.sh` 顶部修改 `WEB_PORT` / `BACKEND_PORT`。

## 数据存储在哪里？（重要）

本仓库有**两种模式**，数据存储位置不同：

| 模式 | 数据库 | 数据存放位置 |
|------|--------|--------------|
| desktop（开发） | H2 内嵌文件 | 本地 `core/.local/dataease2.0/desktop` 等文件 |
| **standalone（Linux 正式部署，用这个）** | **MariaDB/MySQL** | 数据库 `dataease10`（用户/仪表板/图表/数据集等元数据都在这里） |

- **元数据（账号、仪表板、图表配置、数据集）** → 存在 **MySQL 的 `dataease10` 数据库**
- **缓存** → Redis
- **上传/生成的文件类数据（Excel、报表、导出）** → 存在数据目录 `/opt/dataease2.0/data/...`
- **日志** → `/opt/dataease2.0/logs/dataease`

> 表结构**无需手动创建**，后端首次启动时 Flyway 会自动建表（`db/migration`）。

## 快速开始（推荐）

把整个仓库（含 `deploy_linux/`）传到 Linux，然后以 root 运行：

```bash
cd /path/to/Dataease/deploy_linux
bash deploy.sh
```

脚本会依次完成：
1. 安装依赖（JDK21 / Maven / Node / Nginx / MariaDB / Redis）
2. 启动并创建数据库 `dataease10`（用户 root / 密码 123456，可在脚本顶部改）
3. 自动写入数据库连接配置到 `application-standalone.yml`
4. 构建后端 jar（standalone profile）+ 前端（build:base）
5. 准备数据目录，安装后端 jar、前端 dist
6. 生成 systemd 服务 + Nginx 配置并启动

完成后访问：`http://服务器IP:8088`

## 手动部署步骤

如果不想用一键脚本，按下面步骤：

### 1. 安装依赖
```bash
# Debian/Ubuntu
sudo apt update
sudo apt install -y openjdk-21-jdk maven nginx mariadb-server redis-server git nodejs npm
```

### 2. 准备数据库
```bash
sudo mysql
CREATE DATABASE dataease10 DEFAULT CHARACTER SET utf8mb4;
# 或用 root/123456，与 application-standalone.yml 一致
```

### 3. 配置数据库连接
编辑 `core/core-backend/src/main/resources/application-standalone.yml`：
- `url` 的地址/库名
- `username` / `password`

### 4. 构建
```bash
# 后端（standalone 是默认激活 profile）
cd /path/to/Dataease
mvn -pl core/core-backend -am -DskipTests clean package
# 产物: core/core-backend/target/CoreApplication.jar

# 前端
cd core/core-frontend
npm install
npm run build:base
# 产物: core/core-frontend/dist
```

### 5. 部署目录
```bash
sudo mkdir -p /opt/dataease2.0
sudo mkdir -p /opt/dataease2.0/data/{excel,report,exportData,font,static-resource}
sudo mkdir -p /opt/dataease2.0/{cache,conf,custom-drivers,logs}
sudo cp core/core-frontend/dist /opt/dataease2.0/webroot   # 前端
sudo mkdir -p /opt/dataease
sudo cp core/core-backend/target/CoreApplication.jar /opt/dataease/
```

### 6. 配置并启动后端（systemd，推荐）
使用仓库内的 `dataease-backend.service` 模板：

```bash
# 创建运行用户
sudo useradd -r -s /bin/false dataease
# 数据目录属主改为该用户（后端需写入权限）
sudo chown -R dataease:dataease /opt/dataease2.0

# 安装 systemd 服务（需先按需修改 dataease-backend.service 里的密码/端口）
sudo cp dataease-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now dataease-backend
```

或直接前台启动调试：
```bash
sudo java -jar /opt/dataease/CoreApplication.jar \
  --server.port=18000 \
  --spring.profiles.active=standalone \
  --dataease.default-pwd=123456 \
  --dataease.path.substitule=/opt/dataease2.0/conf/substitule.json \
  --logging.file.path=/opt/dataease2.0/logs/dataease \
  --dataease.path.excel=/opt/dataease2.0/data/excel/ \
  --dataease.path.report=/opt/dataease2.0/data/report/ \
  --dataease.path.exportData=/opt/dataease2.0/data/exportData/ \
  --dataease.path.font=/opt/dataease2.0/data/font/ \
  --dataease.path.static-resource=/opt/dataease2.0/data/static-resource/ \
  --dataease.path.ehcache=/opt/dataease2.0/cache \
  --dataease.path.share-secret=/opt/dataease2.0/conf/share-secret.json \
  --dataease.path.custom-drivers=/opt/dataease2.0/custom-drivers/
```

### 7. 配置 Nginx
参考 `nginx.conf`，放到 `/etc/nginx/conf.d/dataease.conf`，然后：
```bash
sudo nginx -t && sudo systemctl reload nginx
```

### 8. 验证与登录
```bash
# 后端是否监听
ss -tlnp | grep 18000
# 前端是否可访问（应在浏览器打开 http://服务器IP:8088）
curl -I http://127.0.0.1:8088
```
浏览器访问 `http://服务器IP:8088`，使用：
- 账号：**`admin`**
- 密码：**`123456`**（即 `--dataease.default-pwd` 指定的值）

## 注意事项

1. **必须用 standalone profile**，不要用 desktop（desktop 是 H2 开发库）。
2. **Redis 建议保留**：`application.yml` 里配置了 Redis 缓存，正式部署建议启用。
3. **登录账号**：本版本使用"简化登录"（substitule 模块），账号固定为 **`admin`**。
   - 密码通过后端启动参数 `--dataease.default-pwd` 指定（脚本默认 `123456`）。
   - 若未指定，首次启动会**自动生成随机密码**并写入 `substitule.json` 及日志。
   - 密码配置文件位于 `/opt/dataease2.0/conf/substitule.json`，请妥善保管。
4. **安全**：部署后请修改数据库密码和管理员密码；生产环境建议启用 HTTPS。
5. **Excel 改造**：改造在后端 Java 源码中，用本仓库编译即可保留该功能。

## 常见问题排查

**Q1: 访问 http://IP:8088 打不开？**
```bash
# 看后端是否起来
systemctl status dataease-backend
journalctl -u dataease-backend -n 50
# 看端口是否监听
ss -tlnp | grep -E '8088|18000'
# 看 Nginx
nginx -t && systemctl status nginx
```
常见原因：后端启动失败（看日志）、Nginx 没监听 8088、防火墙/安全组没放行 8088。

**Q2: 后端启动报数据库连接失败？**
检查 `application-standalone.yml` 或启动参数里的数据库地址/账号/密码，确认 MariaDB/MySQL 已启动：
```bash
systemctl status mariadb
mysql -uroot -p123456 -e "show databases;"
```

**Q3: 忘记 admin 密码？**
密码保存在 `/opt/dataease2.0/conf/substitule.json`，直接查看 `pwd` 字段：
```bash
cat /opt/dataease2.0/conf/substitule.json
```
或重启后端并加参数 `--dataease.default-pwd=新密码`。

**Q4: 端口被占用？**
在 `deploy.sh` 顶部修改 `WEB_PORT` / `BACKEND_PORT`，或改 `nginx.conf` 的 `listen` 与 `proxy_pass`。

**Q5: 阿里云/腾讯云外网访问不了？**
需在云控制台的**安全组**中放行 `8088`（TCP）端口（以及数据库 3306 视需要）。

**Q6: 已存在 MySQL，不想再装 MariaDB？**
在 `deploy.sh` 顶部修改 `DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASSWORD` 指向现有 MySQL，脚本会自动跳过 MariaDB 安装。

## 文件清单

| 文件 | 用途 |
|------|------|
| `deploy.sh` | 一键部署脚本（推荐） |
| `nginx.conf` | Nginx 配置模板 |
| `dataease-backend.service` | systemd 服务模板 |
| `README.md` | 本说明 |
