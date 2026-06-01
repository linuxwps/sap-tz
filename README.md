# sap-tz

使用 xbrowser 自动化查询 SAP Portal 合同台账报表(成本) 的 Skill。

## 功能特点

- 🔍 **智能查询**：按项目名称/乙方名称/合同编号搜索 SAP 合同台账报表
- 📊 **自动导出**：触发 SAP 自带「导出至电子表格」功能，下载 Excel 文件
- 🤖 **浏览器自动化**：基于 xbrowser (CDP) 控制 Chrome/Edge/QQ浏览器
- 🔐 **凭据安全**：支持环境变量或本地文件，不硬编码密码
- 🛠️ **故障可调试**：提供调试脚本，便于排查 iframe / 导出按钮问题

## 技术亮点

本项目触及并记录了 SAP Web Dynpro 自动化中的多个坑：

1. **SAP Portal 跨域 iframe 问题** → 报表运行在 8003 端口，Portal 在 8001 端口，CDP 无法直接穿透
2. **SAP input 必须用 native setter** → `inp.value='x'` 会被 SAP 数据模型拦截
3. **iframe 三层嵌套** → `contentAreaFrame → (跨域 iframe) → 报表表单`
4. **元素 title 属性匹配** → SAP Web Dynpro 元素 ID 动态变化，需通过 `title` 属性定位
5. **中文在 eval JS 里乱码** → 通过 Python 生成 .js 文件传入，避免 shell heredoc 编码问题

## 前置条件

- 在目标企业内网或已连接 VPN
- [xbrowser](https://github.com/agent-browser/agent-browser) 已安装（本 skill 内置 `xb.cjs`）
  ```bash
  # 如果未安装 xbrowser，可以运行（仅限 agent-browser 项目）
  npm i -g agent-browser
  xb init
  ```
- 浏览器（Chrome/Edge/QQ浏览器）已安装
- Python 3（用于 `gen_js.py` / `gen_export_js.py`）

## 安装

将本 skill 放入 skills 目录（以 openclaw 举例）：

```bash
cp -r sap-tz ~/.openclaw/skills/
```

## 配置

### 方式一：环境变量（推荐）

```bash
export SAP_PORTAL_URL="http://your-sap-portal.example.com:8001/irj/portal"
export SAP_USER="your_username"
export SAP_PASS="your_password"
```

### 方式二：凭据文件

在 skill 根目录创建 `oa_pwd.txt`（勿提交到 Git）：

```
your_username
your_password
```

或使用模板：

```bash
cp oa_pwd.txt.example oa_pwd.txt
# 然后编辑 oa_pwd.txt 填入用户名和密码
```

## 使用方法

### 直接运行脚本

```bash
bash ~/.openclaw/skills/sap-tz/scripts/sap-report.sh [--project <项目>] [--party-b <乙方>] [--contract <合同编号>] [--headed]
```

示例：

```bash
# 按项目名称查询
bash ~/.openclaw/skills/sap-tz/scripts/sap-report.sh --project 某项目

# 按乙方名称筛选
bash ~/.openclaw/skills/sap-tz/scripts/sap-report.sh --party-b "某乙方"

# 按合同编号筛选
bash ~/.openclaw/skills/sap-tz/scripts/sap-report.sh --contract 某编号

# 组合查询 + 显示浏览器窗口（调试用）
bash ~/.openclaw/skills/sap-tz/scripts/sap-report.sh --project 某项目 --party-b "某乙方" --headed
```

### 通过 OpenClaw 等 agent 触发

对话中提及以下关键词即可触发：
- `合同台账报表`、`台账报表`
- `sap报表`、`tz`
- `导出报表`、`报表导出`

## 输出文件

| 文件 | 路径 | 说明 |
|------|------|------|
| Excel 报表 | `~/Downloads/【关键字】报表.xlsx` | SAP 导出的原始 Excel |
| 调试快照 | 终端输出 | iframe 结构、导出按钮查找日志 |

Excel 包含字段（以 SAP 实际导出为准）：项目名称、乙方名称、合同编号等（完整字段由 SAP 决定）。

## 项目结构

```
sap-tz/
├── SKILL.md                # Skill 说明（供 AI agent 阅读）
├── oa_pwd.txt.example     # 凭据模板（勿提交真实凭据）
└── scripts/
    ├── sap-report.sh      # 主执行脚本
    ├── gen_js.py          # 生成填写搜索条件的 JavaScript
    ├── gen_export_js.py   # 生成点击导出按钮的 JavaScript
    ├── debug-iframe.sh    # iframe 结构调试脚本
    ├── debug-export.sh    # 导出按钮调试脚本
    └── xb.cjs            # xbrowser CLI 工具（内置）
```

## 工作原理

```
┌─────────────────┐
│  xbrowser      │ 打开 SAP Portal（CDP 控制浏览器）
└────────┬────────┘
         │
    ┌────▼────┐
    │ 登录页  │  eval + native setter 填写用户名密码
    └────┬────┘
         │
    ┌────▼────┐
    │ 导航菜单  │  eval 按 textContent 点击：招采管理 → 报表管理 → 合同台账报表(成本)
    └────┬────┘
         │
    ┌────▼────┐
    │ 填写表单  │  eval + native setter 填写项目名称/乙方名称/合同编号
    └────┬────┘
         │
    ┌────▼────┐
    │ 点击搜索  │  eval 递归搜索 iframe，点击搜索按钮
    └────┬────┘
         │
    ┌────▼────┐
    │ 导出报表  │  点击「导出至电子表格」按钮，等待浏览器下载完成
    └────┬────┘
         │
    ┌────▼────┐
    │ 重命名    │  将下载的 Spreadsheet.xlsx 重命名为【项目】【乙方】【合同】报表.xlsx
    └──────────┘
```

## 当前状态与已知问题

### ✅ 已完成

1. OA 登录流程 — 从 OA 首页登录进入 SAP Portal
2. Portal 导航 — 招采管理 → 报表管理 → 合同台账报表(成本)
3. JavaScript 生成方案 — 用 Python (`gen_js.py`) 生成 JS 文件避免 shell 引号转义问题
4. iframe 结构分析 — 已定位报表所在的跨域 iframe

### ❌ 核心阻塞：跨域 iframe

**问题：**
- SAP Portal 运行在 **8001 端口**，报表页面（Web Dynpro）运行在 **8003 端口**
- 报表内容在 `contentAreaFrame` 内的一个**无 name/id 的跨域 iframe** 中
- xbrowser 的 `snapshot -i` 无法穿透跨域 iframe 获取内部元素
- 通过 Portal 页面的 `eval` 可以获取到报表 iframe 的 src URL（含 `sap-ext-sid` session token），但直接导航到该 URL 会因 session 验证失败而空白

**已尝试但失败的方案：**
1. 直接导航到报表 URL → 空白页（`sap-ext-sid` token 绑定在 Portal iframe 上下文）
2. `dispatchEvent` 模拟完整鼠标事件序列 → 导航未生效
3. `el.onclick()` → 无反应
4. snapshot 看到报表 iframe (e99) 但无法展开内部元素

**可能的解决方向（待验证）：**
1. 使用 CDP `Runtime.evaluate` 的 `contextId` 或 `frameId` 参数指定执行上下文
2. 在 Playwright 层面用 `page.frame(url)` 获取跨域 frame 对象再操作
3. 参考 Playwright 录制代码（`baobiao.js`）中的 frame 切换方式
4. 构造不带 session token 的报表 URL，让 SAP 自己做 SSO 重定向

## 常见问题

### Q: 为什么搜索条件填写后没有生效？
A: SAP 数据模型会拦截 `inp.value = 'x'`，必须用 `Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set` 原生 setter。

### Q: 中文在 eval JS 里乱码怎么办？
A: shell heredoc 中直接写中文可能导致 JS 语法错误。方案：（1）用 Unicode 转义 `\uXXXX`；（2）用 Python 生成 .js 文件再传入（本 skill 采用此方案）。

### Q: 元素 ID 每次都变怎么办？
A: SAP Web Dynpro 每次登录后 input ID 都会变化。必须通过 `title` 属性匹配，不能硬编码 ID。

### Q: 导出按钮无法点击怎么办？
A: 这是本 skill 的**核心阻塞问题**。报表在跨域 iframe 内，CDP 无法直接操作。目前通过调试脚本 `debug-export.sh` 可以查看页面上所有包含「导出」的元素，帮助定位问题。

## 依赖

- [xbrowser](https://github.com/agent-browser/agent-browser) — 浏览器自动化 CLI（内置 `xb.cjs`，无需单独安装）
- Python 3 — 用于生成 JavaScript 文件（`gen_js.py` / `gen_export_js.py`）
- Chrome/Edge/QQ浏览器 — 被 xbrowser 控制

## 注意事项

- ⚠️ 浏览器自动化对网络条件苛刻，如网络较差可能因为 timeout 时间不足而无法顺利进入下一阶段
- ⚠️ 技能能否稳定运行与模型能力尤其上下文窗口有直接关系
- ✅ 用户名和密码推荐使用环境变量 `SAP_USER` / `SAP_PASS`
- ⚠️ 导出的 Excel 默认存放于 `~/Downloads/`，用户可根据自身情况调整
- ⚠️ SAP Portal URL 需要在 `sap-report.sh` 中配置，或通过环境变量 `SAP_PORTAL_URL` 指定

## 许可

MIT License

## 作者

[@linuxwps](https://github.com/linuxwps)

---

> 💡 本 Skill 是 OpenClaw agent 生态的一部分，可在其他 agent 按本文配置后复用。欢迎提交 PR 改进！
