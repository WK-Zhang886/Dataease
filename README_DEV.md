# DataEase 本地开发说明

这个目录是 DataEase 源码版，当前目标是方便本地修改后端 Excel 导入逻辑，并保留一套可以快速启动前后端的开发环境。

## 当前状态

- 源码位置：`D:\Dataease`
- 当前分支：`codex/dataease-excel-import-fix`
- 本地数据目录：`D:\Dataease\.local\dataease2.0`
- 前端地址：`http://localhost:8080`
- 后端地址：`http://localhost:8100`
- 当前 remote 仍是官方仓库：`https://github.com/dataease/dataease.git`
- 上传到个人 GitHub 前，需要把 remote 改成自己的仓库地址

## 一键启动

双击根目录的：

```bat
D:\Dataease\start-dataease-dev.bat
```

只检查环境：

```bat
D:\Dataease\start-dataease-dev-check.bat
```

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

## 主要目录

- `core/core-backend`：后端，Spring Boot。负责登录、权限、数据源、Excel 解析、字段类型识别、建表、数据同步、图表数据查询。
- `core/core-frontend`：前端，Vue 3 + Vite。负责数据源页面、Excel 上传页面、字段选择、仪表板、图表编辑器。
- `sdk`：公共 DTO、接口定义、插件接口和工具类，后端模块会依赖它。
- `drivers`：数据库驱动。
- `dev`：本地开发启动脚本。

Excel 导入逻辑主要在：

```text
D:\Dataease\core\core-backend\src\main\java\io\dataease\datasource\provider\ExcelUtils.java
```

对应测试在：

```text
D:\Dataease\core\core-backend\src\test\java\io\dataease\datasource\provider\ExcelUtilsTest.java
```

## 已做过的关键修改

- Excel 导入时，空表头 Sheet 会跳过，不再直接报“首行不能为空”。
- 重复字段名会自动追加 `_2`、`_3`，避免导入时报重复字段名。
- `#N/A`、`N/A`、`NA`、`NULL`、空字符串会按空值处理，不参与数值类型判断。
- 日期格式字符串会识别为 `DATETIME`。
- 先识别为整数、后续遇到小数时，会升级为 `DOUBLE`。
- 行数据按表头顺序写入，避免缺值造成列错位。
- 前端开发默认跳过实时 eslint/stylelint，减少本地启动卡顿。
- 增加本地一键启动脚本。

## 本地环境

已经配置过：

- JDK 21
- Maven 3.9.16
- 项目内置 Node.js

Maven 路径：

```text
C:\Users\Lenovo\.m2\wrapper\dists\apache-maven-3.9.16-bin\5grr65jo27hi51sujmtcldfovl\apache-maven-3.9.16\bin\mvn.cmd
```

Node 路径：

```text
D:\Dataease\.local\tools\nodejs
```

## 本地数据说明

`.local` 是本地运行目录，不是源码，不会上传 GitHub。

主要数据在：

```text
D:\Dataease\.local\dataease2.0
```

里面通常包括：

- `h2`：本地 H2 数据库，保存账号、数据源、数据集、仪表板等配置。
- `data`：上传文件和本地运行数据。
- `logs`：日志。
- `cache`：缓存。

如果要清空 DataEase 本地数据，可以删除：

```text
D:\Dataease\.local\dataease2.0
```

如果删除整个 `.local`，Node、本地工具和数据库都会被删，之后可能需要重新配置。

## 验证命令

后端 Excel 导入测试：

```powershell
& 'C:\Users\Lenovo\.m2\wrapper\dists\apache-maven-3.9.16-bin\5grr65jo27hi51sujmtcldfovl\apache-maven-3.9.16\bin\mvn.cmd' -pl core-backend -Dtest=ExcelUtilsTest -DskipTests=false '-Dmaven.antrun.skip=true' test
```

之前该测试已经通过。

## Git 上传说明

当前本地提交：

```text
f05f9a9 Adapt DataEase for local Excel import development
```

上传到个人 GitHub 时，不要推到官方 `dataease/dataease`。推荐流程：

```powershell
git remote set-url origin https://github.com/你的用户名/dataease.git
git push -u origin codex/dataease-excel-import-fix
```

如果要创建全新的 GitHub 仓库，需要先在 GitHub 页面创建仓库，再把仓库 HTTPS 地址交给我继续推送。
