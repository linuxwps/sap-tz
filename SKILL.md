---
name: sap-tz
description: 查询和导出企业内网 SAP「合同台账报表(成本)」。支持按项目名称、乙方名称、合同编号搜索，结果导出为 Excel。触发关键词：合同台账报表、台账报表、sap报表、tz。仅在目标企业内网或 VPN 环境下可用。
---

# SAP 台账报表查询导出 (sap-tz)

> ⚠️ **开发中** — 此 skill 尚未完成，核心阻塞：SAP Portal 跨域 iframe 操作问题。

使用 xbrowser 控制真实浏览器（Chrome/Edge/QQ浏览器），查询 SAP Portal 的「合同台账报表(成本)」页面并导出 Excel。

## 快速使用

```bash
bash <skill_dir>/scripts/sap-report.sh [--project <项目>] [--party-b <乙方>] [--contract <合同编号>] [--headed]
```

**所有参数都是可选的**，不传则导出全部数据。

| 参数 | 说明 | 示例 |
|------|------|------|
| `--project <项目名>` | 按项目名称筛选 | `--project 某项目` |
| `--party-b <乙方名>` | 按乙方名称筛选 | `--party-b 某乙方` |
| `--contract <编号>` | 按合同编号筛选 | `--contract 某编号` |
| `--headed` | 显示浏览器窗口（调试用） | `--headed` |

## 导出文件

- **存放路径：** `~/Downloads/`
- **命名格式：** `【项目名称关键字】【乙方名称关键字】【合同编号关键字】报表.xlsx`

## 前置条件

- 在目标企业内网或已连接 VPN
- xbrowser 已安装（`xb init` 检测）
- 浏览器（Chrome/Edge/QQ浏览器）已安装
- 凭据文件 `oa_pwd.txt` 在 skill 根目录下（第一行用户名，第二行密码）

## 当前状态与已知问题

### ✅ 已完成

1. **OA 登录流程** — 从 OA 首页登录进入 SAP Portal
2. **Portal 导航** — 招采管理 → 报表管理 → 合同台账报表(成本)
3. **JavaScript 生成方案** — 用 Python (`gen_js.py`) 生成 JS 文件避免 shell 引号转义问题
4. **iframe 结构分析** — 详见下方

### ❌ 核心阻塞：跨域 iframe

**问题：**
- SAP Portal 运行在 **8001 端口**
- 报表页面（Web Dynpro）运行在 **8003 端口**
- 报表内容在 `contentAreaFrame` 内的一个**无 name/id 的 iframe** 中（非 `isolatedWorkArea`）
- xbrowser 的 `snapshot -i` 无法穿透跨域 iframe 获取内部元素
- 通过 Portal 页面的 `eval` 可以获取到报表 iframe 的 src URL（含 `sap-ext-sid` session token）

**已尝试但失败的方案：**
1. 直接导航到报表 URL → 空白页（`sap-ext-sid` token 绑定在 Portal iframe 上下文）
2. `dispatchEvent` 模拟完整鼠标事件序列 → 导航未生效
3. `el.onclick()` → 无反应
4. snapshot 看到报表 iframe (e99) 但无法展开内部元素

**可能的解决方向（待验证）：**
1. 使用 CDP `Runtime.evaluate` 的 `contextId` 或 `frameId` 参数指定执行上下文
2. 在 Playwright 层面用 `page.frame(url)` 获取跨域 frame 对象再操作
3. 参考 Playwright 录制代码中的 frame 切换方式
4. 构造不带 session token 的报表 URL，让 SAP 自己做 SSO 重定向

### iframe 结构

```
Portal (8001)
 └── contentAreaFrame (同域, 可通过 eval 访问)
      ├── [无name/id] (8003 跨域!) ← 实际报表页面在这里
      │    └── Web Dynpro 表单 (项目名称/乙方名称/合同编号 搜索框)
      └── isolatedWorkArea (EmptyDocument)
```

### Playwright 录制参考

录制文件位置：`scripts/baobiao.js`（仅供参考，本 skill 不直接使用 Playwright）

关键信息：
- SAP Portal 在 popup 新窗口打开（`waitForEvent('popup')`）
- 导航路径：招采管理 → 报表管理 → 合同台账报表(成本)
- 搜索字段：项目名称、乙方名称、合同编号（textbox role）
- 导出按钮：`getByTitle('导出至电子表格 ')`（末尾有空格）

## 文件说明

| 文件 | 用途 |
|------|------|
| `scripts/sap-report.sh` | 主脚本（最新版） |
| `scripts/gen_js.py` | 生成填写搜索条件的 JavaScript |
| `scripts/gen_export_js.py` | 生成点击导出按钮的 JavaScript |
| `scripts/debug-iframe.sh` | iframe 结构调试脚本 |
| `scripts/debug-export.sh` | 导出按钮调试脚本 |
| `scripts/xb.cjs` | xbrowser CLI 工具（从 sap-skill 复制） |
| `oa_pwd.txt.example` | 凭据模板（请勿提交真实凭据） |

## 注意事项

- **本技能使用 Edge 浏览器**（可通过修改脚本切换）
- SAP Portal URL: `http://your-sap-portal.example.com:8001/irj/portal`（请替换为实际地址）
- 任务结束后建议关闭浏览器或清理会话
- **请勿将 `oa_pwd.txt` 提交到版本库**，请使用 `oa_pwd.txt.example` 作为模板
