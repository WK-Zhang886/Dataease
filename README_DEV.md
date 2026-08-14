# DataEase 本地开发说明

这个目录是 DataEase 源码版，主要用于本地改后端 Excel 导入逻辑和前端上传页面。

## 常用入口

一键启动前端和后端：

```bat
D:\Dataease\start-dataease-dev.bat
```

只检查环境：

```bat
D:\Dataease\start-dataease-dev-check.bat
```

前端页面：

`http://localhost:8080`

后端接口：

`http://localhost:8100`

停止服务：

关闭脚本启动出来的 PowerShell 窗口即可。通常会有一个前端窗口和一个后端窗口。

## 主要目录

- `core/core-frontend`：前端，Vue 3 + Vite。负责图表编辑、数据源页面、Excel 上传页面、字段选择、仪表板页面。
- `core/core-backend`：后端，Spring Boot。负责接口、登录权限、数据源管理、Excel 解析、字段类型识别、建表、数据同步、图表数据查询。
- `sdk`：公共 DTO、API 定义、工具类和扩展接口，后端模块会依赖它。
- `drivers`：数据库驱动。
- `dev`：本地开发启动脚本。

Excel 导入逻辑主要在：

`core/core-backend/src/main/java/io/dataease/datasource/provider/ExcelUtils.java`

## 当前不重点看的目录

这些目录没有删除，只是在 IDEA 里尽量排除索引或不用频繁展开：

- `.local`：本地 Node、H2 数据库、日志、上传文件。
- `.github`：GitHub CI 配置。
- `de-xpack`：扩展/企业版相关模块。
- `docs`：项目文档。
- `installer`：安装包和部署脚本。
- `mapFiles`：地图资源。
- `staticResource`：静态资源。
- `node_modules`、`target`：依赖和构建产物。

## 本机环境

已配置：

- JDK 21
- Maven 3.9.16，本机路径：

```text
C:\Users\Lenovo\.m2\wrapper\dists\apache-maven-3.9.16-bin\5grr65jo27hi51sujmtcldfovl\apache-maven-3.9.16\bin\mvn.cmd
```

- 项目内置 Node.js，路径：

```text
D:\Dataease\.local\tools\nodejs
```

## 启动脚本

PowerShell 原始启动命令：

```powershell
powershell -ExecutionPolicy Bypass -File D:\Dataease\dev\start-dataease-dev.ps1
```

只启动后端：

```powershell
powershell -ExecutionPolicy Bypass -File D:\Dataease\dev\start-dataease-dev.ps1 -BackendOnly -NoBrowser
```

只启动前端：

```powershell
powershell -ExecutionPolicy Bypass -File D:\Dataease\dev\start-dataease-dev.ps1 -FrontendOnly
```

跳过前端依赖安装检查：

```powershell
powershell -ExecutionPolicy Bypass -File D:\Dataease\dev\start-dataease-dev.ps1 -SkipNpmInstall
```

## 快速开发模式

默认启动是快速开发模式：

- 前端跳过 Vite 实时 eslint/stylelint 插件，减少启动卡顿和格式红屏。
- 后端 JVM 使用 `-Xms512m -Xmx4g`，大 Excel 导入更稳。
- 后端上传限制设置为 `500MB`。
- 本地 H2 数据库放在 `D:\Dataease\.local\dataease2.0`。

如果需要打开前端实时 lint：

```powershell
powershell -ExecutionPolicy Bypass -File D:\Dataease\dev\start-dataease-dev.ps1 -FullLint
```

## IDEA 建议

打开项目：

```text
D:\Dataease
```

主要关注：

- `core/core-backend`
- `core/core-frontend`
- `sdk`
- `dev`

如果 IDEA 左侧还是显示很多目录，可以右键不常用目录，选择 `Mark Directory as` -> `Excluded`。
