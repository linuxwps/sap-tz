#!/bin/bash
# sap-report.sh - SAP 报表查询与导出（合同台账报表(成本)）
# 用法: bash sap-report.sh [--project <项目>] [--party-b <乙方>] [--contract <合同编号>] [--headed]
# 所有参数都是可选的，不传则导出全部
# 最终稳定版：使用 Python 生成临时 JS 文件，避免引号转义问题

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- 参数解析 ----
PROJECT_KEYWORD=""
PARTY_B_KEYWORD=""
CONTRACT_KEYWORD=""
HEADED_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)      PROJECT_KEYWORD="$2"; shift 2 ;;
    --party-b)      PARTY_B_KEYWORD="$2"; shift 2 ;;
    --contract)      CONTRACT_KEYWORD="$2"; shift 2 ;;
    --headed)        HEADED_FLAG="--headed"; shift ;;
    -*)              echo "未知参数: $1"; exit 1 ;;
    *)               echo "用法: bash sap-report.sh [--project <项目>] [--party-b <乙方>] [--contract <合同编号>] [--headed]"; exit 1 ;;
  esac
done

# ---- 环境检查 ----
if ! command -v node &>/dev/null; then
  echo "错误: node 未安装"
  exit 1
fi

XB="$SKILL_DIR/scripts/xb.cjs"
if [ ! -f "$XB" ]; then
  echo "错误: xbrowser 脚本未找到: $XB"
  exit 1
fi

NODE="${QCLAW_CLI_NODE_BINARY:-node}"

# ---- 辅助函数：调用 Python 脚本生成 JavaScript 文件 ----
gen_js_file() {
  local PROJECT="$1"
  local PARTY_B="$2"
  local CONTRACT="$3"
  
  # 调用独立的 Python 脚本
  python3 "$SCRIPT_DIR/gen_js.py" "$PROJECT" "$PARTY_B" "$CONTRACT"
}

# ---- 阶段 0: 初始化 xbrowser ----
echo "[阶段0] 初始化 xbrowser..."
"$NODE" "$XB" init 2>&1 | head -20

# ---- 阶段 1: 打开 SAP Portal（直接访问，不经过 OA）----
echo "[阶段1] 打开 SAP Portal..."
# ⚠️ 请替换为实际的 SAP Portal URL
SAP_PORTAL_URL="${SAP_PORTAL_URL:-http://your-sap-portal.example.com:8001/irj/portal}"
"$NODE" "$XB" run --browser edge open "$SAP_PORTAL_URL" 2>&1
"$NODE" "$XB" run --browser edge wait --load networkidle 2>&1
sleep 3

# ---- 阶段 2: 登录检查 ----
echo "[阶段2] 检查登录状态..."
SNAPSHOT=$("$NODE" "$XB" run --browser edge snapshot -i 2>&1 || true)

if echo "$SNAPSHOT" | grep -qi '用户.*\*'; then
  echo "需要登录，读取凭据..."
  # 优先使用环境变量，其次使用凭据文件
  USERNAME="${SAP_USER:-}"
  PASSWORD="${SAP_PASS:-}"
  
  if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    PWD_FILE="$SKILL_DIR/oa_pwd.txt"
    if [ ! -f "$PWD_FILE" ]; then
      echo "错误: 凭据未配置。请设置环境变量 SAP_USER/SAP_PASS，或创建 $PWD_FILE"
      exit 1
    fi
    USERNAME=$(sed -n '1p' "$PWD_FILE" | tr -d '\r')
    PASSWORD=$(sed -n '2p' "$PWD_FILE" | tr -d '\r')
  fi

  sleep 2
  # 填写用户名
  "$NODE" "$XB" run --browser edge eval "
    (() => {
      const inputs = document.querySelectorAll('input[type=\"text\"], input:not([type])');
      for (const inp of inputs) {
        if (inp.offsetHeight > 0 && !inp.readOnly && inp.type !== 'hidden') {
          inp.focus(); inp.select();
          const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
          setter.call(inp, '$USERNAME');
          inp.dispatchEvent(new Event('input', {bubbles:true}));
          inp.blur();
          return 'filled username';
        }
      }
      return 'username input not found';
    })()
  " 2>&1 || true
  sleep 1

  # 填写密码
  "$NODE" "$XB" run --browser edge eval "
    (() => {
      const inputs = document.querySelectorAll('input[type=\"password\"]');
      if (inputs.length > 0) {
        const inp = inputs[0];
        inp.focus(); inp.select();
        const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        setter.call(inp, '$PASSWORD');
        inp.dispatchEvent(new Event('input', {bubbles:true}));
        inp.blur();
        return 'filled password';
      }
      return 'password field not found';
    })()
  " 2>&1 || true
  sleep 1

  # 点击登录按钮
  "$NODE" "$XB" run --browser edge eval "
    (() => {
      const all = document.querySelectorAll('*');
      for (const el of all) {
        if ((el.textContent || '').trim() === '登录' && (el.tagName === 'BUTTON' || el.onclick)) {
          el.click(); return 'clicked login button';
        }
      }
      const submits = document.querySelectorAll('input[type=\"submit\"]');
      if (submits.length > 0) { submits[0].click(); return 'clicked submit'; }
      return 'login button not found';
    })()
  " 2>&1 || true

  sleep 5
  "$NODE" "$XB" run --browser edge wait --load networkidle 2>&1 || true
  sleep 3
fi

echo "登录状态检查完成"

# ---- 阶段 3: 导航到合同台账报表(成本) ----
echo "[阶段3] 导航到 招采管理 → 报表管理 → 合同台账报表(成本)..."

nav_click() {
  local TEXT="$1"
  local WAIT="${2:-3}"
  "$NODE" "$XB" run --browser edge eval "
    (() => {
      const all = document.querySelectorAll('*');
      for (const el of all) {
        if (el.textContent?.trim() === '$TEXT' && el.getAttribute('tabindex')) {
          el.click(); return 'clicked $TEXT';
        }
      }
      return '$TEXT not found';
    })()
  " 2>&1 || true
  sleep "$WAIT"
  "$NODE" "$XB" run --browser edge wait --load networkidle 2>&1 || true
  sleep 2
}

nav_click "招采管理" 5
nav_click "报表管理" 5
nav_click "合同台账报表(成本)" 10

# 额外等待 SAP 报表页面完全加载（SAP Web Dynpro 异步加载）
echo "等待 SAP 报表页面加载..."
sleep 15
"$NODE" "$XB" run --browser edge wait --load networkidle 2>&1 || true
sleep 5

# 检查页面是否加载完成（查找输入框）
LOAD_CHECK=$("$NODE" "$XB" run --browser edge eval '(() => {
  const ca = document.querySelector("iframe[name=contentAreaFrame]");
  if (!ca) return "ca not found";
  const caDoc = ca.contentDocument;
  if (!caDoc) return "caDoc not accessible";
  const iwa = caDoc.querySelector("iframe#isolatedWorkArea, iframe[name=isolatedWorkArea]");
  if (!iwa) return "iwa not found";
  const iwaDoc = iwa.contentDocument;
  if (!iwaDoc) return "iwaDoc not accessible";
  
  // 查找所有元素中包含"项目名称"文本的
  const all = iwaDoc.querySelectorAll("*");
  for (const el of all) {
    if ((el.textContent || "").includes("项目名称") && el.children.length === 0) {
      return "found: " + el.tagName + " text=" + el.textContent.trim().substring(0, 30);
    }
  }
  return "not loaded yet";
})()' 2>&1)
echo "页面状态: $LOAD_CHECK"

echo "导航完成"

# ---- 阶段 4: 填写搜索条件 ----
echo "[阶段4] 填写搜索条件..."

# 生成 JavaScript 文件（gen_js.py 会自动点击搜索按钮）
JS_FILE=$(gen_js_file "$PROJECT_KEYWORD" "$PARTY_B_KEYWORD" "$CONTRACT_KEYWORD")
echo "JS file: $JS_FILE"

# 读取 JS 内容并执行
JS_CONTENT=$(cat "$JS_FILE")
"$NODE" "$XB" run --browser edge eval "$JS_CONTENT" 2>&1 || true

# 删除临时文件
rm -f "$JS_FILE"

echo "搜索已提交，等待搜索结果加载（20秒）..."
sleep 20
"$NODE" "$XB" run --browser edge wait --load networkidle 2>&1 || true
sleep 3

# ---- 阶段 5: 导出 Excel ----
echo "[阶段5] 导出 Excel..."

# 调试：先查看页面上所有可点击元素
echo "[调试] 查看页面上的按钮和链接..."
DEBUG_JS='(() => {
  const results = [];
  function searchAll(doc, depth) {
    if (depth > 4) return;
    try {
      const all = doc.querySelectorAll("*");
      for (const el of all) {
        const t = (el.textContent || "").trim();
        const title = el.title || "";
        if ((t.includes("导出") || title.includes("导出") || t.includes("搜索") || t.includes("下载")) && el.tagName) {
          results.push("depth=" + depth + " tag=" + el.tagName + " text=\"" + t.substring(0, 30) + "\" title=\"" + title + "\"");
        }
      }
      const iframes = doc.querySelectorAll("iframe");
      for (const iframe of iframes) {
        try {
          const innerDoc = iframe.contentDocument;
          if (innerDoc) searchAll(innerDoc, depth + 1);
        } catch(e) {}
      }
    } catch(e) {}
  }
  searchAll(document, 0);
  return results.length > 0 ? results.join("\n") : "No matching elements found";
})()'
"$NODE" "$XB" run --browser edge eval "$DEBUG_JS" 2>&1

# 使用 Python 脚本生成导出按钮点击的 JavaScript
EXPORT_JS_FILE=$(python3 "$SCRIPT_DIR/gen_export_js.py")
echo "Export JS file: $EXPORT_JS_FILE"

# 读取 JS 内容并执行
EXPORT_JS_CONTENT=$(cat "$EXPORT_JS_FILE")
"$NODE" "$XB" run --browser edge eval "$EXPORT_JS_CONTENT" 2>&1 || true

# 删除临时文件
rm -f "$EXPORT_JS_FILE"

sleep 10

sleep 5

# 等待下载完成
echo "等待 Excel 下载完成..."
DOWNLOAD_DIR=~/Downloads
EXCEL_PATH=""

# 生成文件名（用户要求的格式：【项目名称】【乙方名称】【合同编号】报表.xlsx）
FILENAME_PARTS=()
[[ -n "$PROJECT_KEYWORD" ]] && FILENAME_PARTS+=("【${PROJECT_KEYWORD}】")
[[ -n "$PARTY_B_KEYWORD" ]] && FILENAME_PARTS+=("【${PARTY_B_KEYWORD}】")
[[ -n "$CONTRACT_KEYWORD" ]] && FILENAME_PARTS+=("【${CONTRACT_KEYWORD}】")
FILENAME=$(IFS=; echo "${FILENAME_PARTS[*]}报表")

for i in $(seq 1 30); do
  if ls "$DOWNLOAD_DIR"/*.crdownload 2>/dev/null; then
    sleep 1
    continue
  fi
  latest=$(ls -t "$DOWNLOAD_DIR"/Spreadsheet*.xlsx 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    EXCEL_PATH="$latest"
    echo "DOWNLOAD_COMPLETE:$EXCEL_PATH"
    break
  fi
  sleep 1
done

if [ -z "$EXCEL_PATH" ]; then
  echo "错误: Excel 下载超时或失败"
  exit 1
fi

# 重命名文件
FINAL_PATH="$DOWNLOAD_DIR/${FILENAME}.xlsx"
mv "$EXCEL_PATH" "$FINAL_PATH"
echo "Excel 已保存到: $FINAL_PATH"

# 输出文件路径给用户
echo ""
echo "📊 报表文件: $FINAL_PATH"
echo ""
echo "🗑️ 是否删除此文件？回复「删」即可删除。"
