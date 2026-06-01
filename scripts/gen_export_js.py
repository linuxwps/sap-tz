#!/usr/bin/env python3
"""
生成 SAP 报表导出按钮点击的 JavaScript 代码（递归搜索 iframe）
用法: python3 gen_export_js.py
输出: 临时 JavaScript 文件路径
"""

import json
import sys
import tempfile

def gen_export_js():
    """生成点击导出按钮的 JavaScript 代码"""
    
    js_code = """(() => {
  // 递归搜索所有 iframe，找到导出按钮
  function findExportButton(doc) {
    try {
      const all = doc.querySelectorAll('*');
      for (const el of all) {
        const t = el.title || el.textContent?.trim();
        if (t && t.includes('导出至电子表格')) {
          return el;
        }
      }
    } catch(e) {}
    
    // 递归搜索嵌套 iframe
    try {
      const iframes = doc.querySelectorAll('iframe');
      for (const iframe of iframes) {
        try {
          const innerDoc = iframe.contentDocument;
          if (innerDoc) {
            const result = findExportButton(innerDoc);
            if (result) return result;
          }
        } catch(e) {}
      }
    } catch(e) {}
    
    return null;
  }
  
  const exportBtn = findExportButton(document);
  if (exportBtn) {
    exportBtn.click();
    return 'clicked 导出 button: ' + (exportBtn.title || exportBtn.textContent?.trim());
  }
  
  return 'export button not found';
})()"""
    
    # 写入临时文件
    with tempfile.NamedTemporaryFile(mode='w', suffix='.js', delete=False) as f:
        f.write(js_code)
        return f.name

if __name__ == '__main__':
    js_file = gen_export_js()
    print(js_file)
