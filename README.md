# DataEase 本地改造版

这是基于 DataEase 源码整理出来的本地开发版，主要用于后续修改 Excel 导入逻辑，适配芳烃价格这类不规则 Excel 表格。

## 当前用途

- 本地运行 DataEase 前后端
- 调试 Excel 上传和字段类型识别
- 修改后端 Excel 导入逻辑
- 后续可迁移到 Linux 服务器部署，并通过网页访问

## 快速启动

双击根目录：

```bat
D:\Dataease\start-dataease-dev.bat
```

只检查环境：

```bat
D:\Dataease\start-dataease-dev-check.bat
```

启动后访问：

```text
http://localhost:8080
```

后端接口：

```text
http://localhost:8100
```

## 主要目录

- `core/core-backend`：后端，Spring Boot。Excel 导入、字段类型识别、数据源、数据集、图表查询等逻辑主要在这里。
- `core/core-frontend`：前端，Vue 3 + Vite。数据源页面、Excel 上传页面、图表编辑器主要在这里。
- `sdk`：公共接口、DTO、插件接口和工具类。
- `drivers`：数据库驱动。
- `dev`：本地开发启动脚本。

Excel 导入核心文件：

```text
core/core-backend/src/main/java/io/dataease/datasource/provider/ExcelUtils.java
```

Excel 导入测试文件：

```text
core/core-backend/src/test/java/io/dataease/datasource/provider/ExcelUtilsTest.java
```

## 已完成的本地改造

- 空表头 Sheet 会跳过，不再直接导致导入失败。
- 重复字段名会自动追加 `_2`、`_3`。
- `#N/A`、`N/A`、`NA`、`NULL`、空字符串会按空值处理。
- 日期格式字符串会识别为 `DATETIME`。
- 整数列后续遇到小数时，会升级为 `DOUBLE`。
- 行数据按表头顺序写入，减少缺值导致的列错位。
- 前端开发默认跳过实时 eslint/stylelint，减少本地启动卡顿。
- 增加一键启动脚本。

## 本地数据

本地运行数据不在 GitHub 仓库里，位置是：

```text
D:\Dataease\.local\dataease2.0
```

这里通常包含：

- H2 数据库
- 上传文件
- 日志
- 缓存

如果要清空本地 DataEase 数据，可以删除：

```text
D:\Dataease\.local\dataease2.0
```

不要随便删除整个 `.local`，里面还可能有本地 Node.js 等开发工具。

## 更多交接说明

更详细的本地环境、启动参数、验证命令、Git 说明在：

```text
README_DEV.md
```

下一次开新对话时，可以让 Codex 先读取 `README.md` 和 `README_DEV.md`，再继续修改 Excel 导入功能。
