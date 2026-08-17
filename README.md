# DataEase 改造版

本项目基于 **DataEase 开源版**源码进行改造，主要用于本地开发与二次开发，后续可部署到 Linux 服务器使用。具体改造点不在此说明，如需了解请查看代码。

## 快速启动

双击根目录脚本，或手动执行：

```bat
start-dataease-dev.bat
```

只检查环境：

```bat
start-dataease-dev-check.bat
```

启动后访问：

```text
前端：http://localhost:8080
后端：http://localhost:8100
```

> Linux 部署：见 `deploy_linux/` 目录，内含一键部署脚本 `deploy.sh`、Nginx 配置、systemd 服务及部署说明。

## 目录结构

| 目录/文件 | 作用 |
|-----------|------|
| `core/core-backend` | 后端（Spring Boot）。登录、权限、数据源、数据集、Excel 导入、字段类型识别、图表查询等核心逻辑。 |
| `core/core-frontend` | 前端（Vue 3 + Vite）。数据源页面、Excel 上传页面、仪表板、图表编辑器等界面。 |
| `sdk` | 公共接口、DTO、插件接口与工具类，后端模块依赖。 |
| `drivers` | 数据库驱动。 |
| `dev` | 本地开发启动脚本。 |
| `deploy_linux` | Linux 部署脚本与文档（standalone 单机部署）。 |
| `start-dataease-dev.bat` | Windows 一键启动脚本。 |
| `start-dataease-dev-check.bat` | Windows 环境检查脚本。 |

Excel 导入核心代码：

```text
core/core-backend/src/main/java/io/dataease/datasource/provider/ExcelUtils.java
```

Excel 导入测试：

```text
core/core-backend/src/test/java/io/dataease/datasource/provider/ExcelUtilsTest.java
```

## 本地数据

本地运行数据不纳入版本控制，位于：

```text
.local/dataease2.0
```

包含 H2 数据库、上传文件、日志、缓存等。如需清空本地数据，删除该目录即可。`.local` 下还可能包含本地 Node 等开发工具，请勿随意删除整个 `.local`。

## 本地环境要求

- JDK 21
- Maven 3.9+
- Node.js 18+（项目内置 Node 也可）

## 登录账号

- 账号：`admin`
- 密码：本地开发（desktop 模式）默认免登录；Linux 部署（standalone 模式）默认 `123456`，可通过后端启动参数 `--dataease.default-pwd` 修改。
