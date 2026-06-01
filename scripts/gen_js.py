#!/usr/bin/env python3
"""
生成 SAP 报表查询的 JavaScript 代码（递归搜索 iframe）
用法: python3 gen_js.py <project> <party_b> <contract>
输出: 临时 JavaScript 文件路径
"""

import json
import sys
import tempfile

def gen_js(project, party_b, contract):
    """生成 JavaScript 代码（递归搜索所有 iframe + 调试输出）"""
    
    # 安全地转义字符串（用于 JavaScript）
    project_js = json.dumps(project) if project else '""'
    party_b_js = json.dumps(party_b) if party_b else '""'
    contract_js = json.dumps(contract) if contract else '""'
    
    # 完整 JavaScript 代码（递归搜索 iframe）
    js_code = """(() => {
  const results = [];
  
  // 递归搜索所有 iframe，找到包含目标 input 的 document
  function findInput(doc, titleKeyword) {
    try {
      const inp = doc.querySelector('input[title*=\"' + titleKeyword + '\"], input[aria-label*=\"' + titleKeyword + '\"]');
      if (inp) return {doc: doc, input: inp};
    } catch(e) {}
    
    // 递归搜索嵌套 iframe
    try {
      const iframes = doc.querySelectorAll('iframe');
      for (const iframe of iframes) {
        try {
          const innerDoc = iframe.contentDocument;
          if (innerDoc) {
            const result = findInput(innerDoc, titleKeyword);
            if (result) return result;
          }
        } catch(e) {}
      }
    } catch(e) {}
    
    return null;
  }
  
  // 填写项目名称
  results.push('=== 填写项目名称 ===');
  const projectResult = findInput(document, '项目名称');
  if (projectResult && projectResult.input) {
    results.push('✅ found 项目名称 input: tag=' + projectResult.input.tagName + ' type=' + projectResult.input.type);
    if (""" + project_js + """) {
      const inp = projectResult.input;
      inp.focus();
      const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
      setter.call(inp, """ + project_js + """);
      inp.dispatchEvent(new Event('input', {bubbles: true}));
      inp.dispatchEvent(new Event('change', {bubbles: true}));
      results.push('✅ filled value=' + inp.value);
    } else {
      results.push('⚠️ no value to fill');
    }
  } else {
    results.push('❌ 项目名称 input not found');
  }
  
  // 填写乙方名称
  results.push('=== 填写乙方名称 ===');
  const partyBResult = findInput(document, '乙方名称');
  if (partyBResult && partyBResult.input) {
    results.push('✅ found 乙方名称 input: tag=' + partyBResult.input.tagName + ' type=' + partyBResult.input.type);
    if (""" + party_b_js + """) {
      const inp = partyBResult.input;
      inp.focus();
      const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
      setter.call(inp, """ + party_b_js + """);
      inp.dispatchEvent(new Event('input', {bubbles: true}));
      inp.dispatchEvent(new Event('change', {bubbles: true}));
      results.push('✅ filled value=' + inp.value);
    } else {
      results.push('⚠️ no value to fill');
    }
  } else {
    results.push('❌ 乙方名称 input not found');
  }
  
  // 填写合同编号
  results.push('=== 填写合同编号 ===');
  const contractResult = findInput(document, '合同编号');
  if (contractResult && contractResult.input) {
    results.push('✅ found 合同编号 input: tag=' + contractResult.input.tagName + ' type=' + contractResult.input.type);
    if (""" + contract_js + """) {
      const inp = contractResult.input;
      inp.focus();
      const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
      setter.call(inp, """ + contract_js + """);
      inp.dispatchEvent(new Event('input', {bubbles: true}));
      inp.dispatchEvent(new Event('change', {bubbles: true}));
      results.push('✅ filled value=' + inp.value);
    } else {
      results.push('⚠️ no value to fill');
    }
  } else {
    results.push('❌ 合同编号 input not found');
  }
  
  // 找搜索按钮（也用递归搜索）
  function findButton(doc, text) {
    try {
      const all = doc.querySelectorAll('*');
      for (const el of all) {
        const t = (el.textContent || '').trim();
        if ((t === text || t.includes(text)) && (el.tagName === 'DIV' || el.onclick)) {
          return el;
        }
      }
    } catch(e) {}
    
    try {
      const iframes = doc.querySelectorAll('iframe');
      for (const iframe of iframes) {
        try {
          const innerDoc = iframe.contentDocument;
          if (innerDoc) {
            const result = findButton(innerDoc, text);
            if (result) return result;
          }
        } catch(e) {}
      }
    } catch(e) {}
    
    return null;
  }
  
  results.push('=== 点击搜索按钮 ===');
  const searchBtn = findButton(document, '搜索');
  if (searchBtn) {
    searchBtn.click();
    results.push('✅ clicked 搜索 button');
  } else {
    results.push('❌ 搜索 button not found');
  }
  
  return results.join('\\n');
})()"""
    
    # 写入临时文件
    with tempfile.NamedTemporaryFile(mode='w', suffix='.js', delete=False) as f:
        f.write(js_code)
        return f.name

if __name__ == '__main__':
    project = sys.argv[1] if len(sys.argv) > 1 else ''
    party_b = sys.argv[2] if len(sys.argv) > 2 else ''
    contract = sys.argv[3] if len(sys.argv) > 3 else ''
    
    js_file = gen_js(project, party_b, contract)
    print(js_file)
