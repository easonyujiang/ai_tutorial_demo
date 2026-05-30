import json
import psutil
import platform
import time

from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse, HTMLResponse, JSONResponse

from infrastructure.log_capture import get_log_capture

router = APIRouter()

START_TIME = time.time()

MONITOR_HTML = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Tutorial 后端控制台</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,-apple-system,sans-serif;background:#f5f6fa;color:#2d3436;height:100vh;display:flex;flex-direction:column}
.header{background:#fff;border-bottom:1px solid #e2e8f0;padding:10px 20px;display:flex;align-items:center;gap:14px;box-shadow:0 1px 3px rgba(0,0,0,.04)}
.header h1{font-size:17px;color:#3b5998;font-weight:700}
.tab-bar{display:flex;gap:0;padding:0 20px;background:#fff;border-bottom:2px solid #e2e8f0}
.tab-btn{padding:12px 20px;border:none;background:none;color:#8899a6;cursor:pointer;font-size:13px;font-weight:600;border-bottom:2px solid transparent;transition:all .15s}
.tab-btn:hover{color:#3b5998}
.tab-btn.active{color:#3b5998;border-bottom-color:#3b5998}
.stats{display:flex;gap:10px;font-size:11px;color:#8899a6;margin-left:auto}
.stats span{padding:4px 10px;background:#f1f5f9;border-radius:6px;border:1px solid #e2e8f0;color:#64748b}
.toolbar{display:flex;gap:8px;padding:8px 16px;background:#fff;border-bottom:1px solid #e2e8f0;align-items:center;flex-wrap:wrap}
.toolbar input,.toolbar select{height:32px;font-size:12px;padding:0 10px;border:1px solid #d1d5db;border-radius:6px;background:#fff;color:#2d3436;outline:none}
.toolbar input:focus,.toolbar select:focus{border-color:#3b5998;box-shadow:0 0 0 2px rgba(59,89,152,.12)}
.toolbar input{width:180px}

.btn{padding:6px 14px;border:1px solid #d1d5db;border-radius:6px;background:#fff;color:#4a5568;cursor:pointer;font-size:12px;font-weight:500;transition:all .15s;display:inline-flex;align-items:center;gap:4px;white-space:nowrap;line-height:1.4}
.btn:hover{background:#f7fafc;border-color:#a0aec0}
.btn:active{transform:scale(.97)}
.btn.primary{background:#3b5998;border-color:#3b5998;color:#fff}
.btn.primary:hover{background:#34508a;border-color:#34508a}
.btn.success{background:#10b981;border-color:#10b981;color:#fff}
.btn.success:hover{background:#059669;border-color:#059669}
.btn.danger{background:#fff;border-color:#ef4444;color:#ef4444}
.btn.danger:hover{background:#fef2f2;border-color:#dc2626}
.btn.warn{background:#fff;border-color:#f59e0b;color:#f59e0b}
.btn.warn:hover{background:#fffbeb;border-color:#d97706}
.btn.sm{padding:3px 10px;font-size:11px;border-radius:5px}
.btn:disabled{opacity:.5;pointer-events:none}

.panel{flex:1;overflow:hidden;display:flex}
.panel.hidden{display:none}
.log-container{flex:1;overflow-y:auto;padding:2px 0;font-family:'Cascadia Code','Fira Code',Consolas,monospace;font-size:12px;line-height:1.5}
.log-entry{display:flex;padding:2px 16px;border-bottom:1px solid #f1f5f9}
.log-entry:hover{background:#f8fafc}
.log-time{color:#94a3b8;min-width:72px}
.log-level{min-width:48px;font-weight:600;text-align:center}
.log-level.DEBUG{color:#94a3b8}.log-level.INFO{color:#3b82f6}
.log-level.WARNING{color:#f59e0b}.log-level.ERROR{color:#ef4444}
.log-module{color:#94a3b8;min-width:60px;text-align:right;padding-right:8px;font-size:11px}
.log-msg{color:#334155;word-break:break-all}
.empty-state{display:flex;align-items:center;justify-content:center;height:200px;color:#94a3b8;font-size:13px}
::-webkit-scrollbar{width:6px}
::-webkit-scrollbar-track{background:#f1f5f9}
::-webkit-scrollbar-thumb{background:#cbd5e1;border-radius:3px}

.skill-panel{padding:16px;flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:10px}
.skill-list{display:flex;flex-direction:column;gap:8px}
.skill-card{background:#fff;border:1px solid #e2e8f0;border-radius:10px;padding:14px 16px;box-shadow:0 1px 3px rgba(0,0,0,.04);transition:box-shadow .15s}
.skill-card:hover{box-shadow:0 2px 8px rgba(0,0,0,.08)}
.skill-card .title{color:#1e293b;font-size:14px;font-weight:600;display:flex;align-items:center;gap:8px}
.skill-card .meta{color:#64748b;font-size:11px;margin-top:5px}
.skill-card .steps-preview{color:#94a3b8;font-size:11px;margin-top:5px}
.skill-card .actions{margin-top:10px;display:flex;gap:6px}

.editor-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(15,23,42,.6);display:flex;align-items:center;justify-content:center;z-index:100}
.editor-overlay.hidden{display:none}
.editor-box{background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:24px;width:94%;max-width:760px;max-height:92vh;overflow-y:auto;box-shadow:0 8px 30px rgba(0,0,0,.12)}
.editor-box h3{color:#3b5998;font-size:17px;margin-bottom:16px}
.editor-box label{display:block;color:#64748b;font-size:12px;font-weight:600;margin:10px 0 4px}
.editor-box input,.editor-box textarea,.editor-box select{width:100%;padding:8px 12px;border:1px solid #d1d5db;border-radius:8px;background:#fff;color:#2d3436;font-size:13px;font-family:inherit;outline:none;transition:border-color .15s}
.editor-box input:focus,.editor-box textarea:focus,.editor-box select:focus{border-color:#3b5998;box-shadow:0 0 0 2px rgba(59,89,152,.1)}
.editor-box textarea{min-height:60px;resize:vertical}
.step-editor{border:1px solid #e2e8f0;border-radius:10px;padding:14px;margin:8px 0;background:#f8fafc}
.step-editor .step-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px}
.step-editor .step-header span{color:#3b5998;font-size:12px;font-weight:700}
.step-editor input{margin-bottom:8px}
.editor-actions{display:flex;gap:10px;margin-top:18px;justify-content:flex-end}

.ai-box{background:#f0f4ff;border:1px solid #c7d2fe;border-radius:10px;padding:14px;margin-bottom:16px}
.ai-box .ai-title{color:#3b5998;font-size:13px;font-weight:700;margin-bottom:10px}
.help-tip{font-size:11px;color:#94a3b8;margin-top:3px;line-height:1.5}
.summary-box{background:#f1f5f9;border:1px solid #e2e8f0;border-radius:10px;padding:12px;margin:10px 0}
.summary-box summary{color:#3b5998;cursor:pointer;font-size:12px;font-weight:600;outline:none}
.summary-box summary:hover{color:#34508a}
</style>
</head>
<body>
<div class="header">
  <h1>⚡ AI Tutorial 后端控制台</h1>
  <div class="stats">
    <span id="sys-cpu">CPU: --</span>
    <span id="sys-mem">MEM: --</span>
    <span id="uptime">运行: --</span>
    <span id="conn-status">● 连接中</span>
  </div>
</div>
<div class="tab-bar">
  <button class="tab-btn active" onclick="switchTab('logs')">📋 日志监控</button>
  <button class="tab-btn" onclick="switchTab('skills')">📚 技能库编辑</button>
  <span id="tab-skills-actions" style="display:none;align-items:center;gap:8px;margin-left:auto;padding-right:8px">
    <button class="btn primary sm" onclick="openSkillEditor()">+ 新建技能</button>
    <button class="btn sm" onclick="refreshSkills()">🔄 刷新</button>
    <input id="skill-search" placeholder="搜索技能..." oninput="filterSkills()" style="width:160px">
    <span id="skill-count" style="font-size:12px;color:#64748b;white-space:nowrap"></span>
  </span>
</div>

<!-- LOGS PANEL -->
<div class="panel" id="panel-logs">
  <div style="display:flex;flex-direction:column;flex:1">
    <div class="toolbar">
      <button class="btn sm active" onclick="setFilter('all',this)">全部</button>
      <button class="btn sm" onclick="setFilter('INFO',this)">INFO</button>
      <button class="btn sm" onclick="setFilter('WARNING',this)">WARNING</button>
      <button class="btn sm" onclick="setFilter('ERROR',this)">ERROR</button>
      <input id="search" placeholder="搜索日志..." oninput="applySearch()">
      <button class="btn sm" id="btn-pause" onclick="togglePause()">⏸ 暂停</button>
      <button class="btn sm" onclick="clearLogs()">🗑 清屏</button>
      <label style="font-size:12px;color:#64748b;display:flex;align-items:center;gap:4px;cursor:pointer"><input type="checkbox" id="auto-scroll" checked> 自动滚屏</label>
    </div>
    <div class="log-container" id="log-container"><div class="empty-state">等待日志...</div></div>
  </div>
</div>

<!-- SKILLS PANEL -->
<div class="panel hidden" id="panel-skills">
  <div class="skill-panel"><div class="skill-list" id="skill-list"></div></div>
</div>

<!-- SKILL EDITOR OVERLAY -->
<div class="editor-overlay hidden" id="skill-editor-overlay">
  <div class="editor-box">
    <h3 id="editor-title">新建技能</h3>
    <div class="ai-box">
      <div class="ai-title">🤖 AI 智能解析</div>
      <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
        <input id="ai-video-url" placeholder="粘贴视频链接（抖音/B站/YouTube）" style="flex:1;min-width:200px">
        <button class="btn primary sm" id="btn-ai-analyze" onclick="aiAnalyzeUrl()">🔍 解析链接</button>
        <span style="color:#94a3b8;font-size:12px">或</span>
        <label class="btn primary sm" style="cursor:pointer">📁 上传视频<input type="file" id="ai-video-file" accept="video/*" onchange="aiAnalyzeFile()" style="display:none"></label>
      </div>
      <div id="ai-status" style="margin-top:8px;font-size:12px;color:#64748b;display:none"></div>
    </div>
    <label>标题 *</label>
    <input id="ed-title" placeholder="技能标题，如：如何连接WiFi">
    <label>描述</label>
    <textarea id="ed-desc" placeholder="简短描述这个技能是做什么的"></textarea>

    <div class="summary-box">
      <summary onclick="document.getElementById('pkg-ref').classList.toggle('hidden')" style="cursor:pointer;color:#3b5998;font-size:12px;font-weight:600;outline:none;user-select:none">📦 包名参考（点击展开）</summary>
      <div id="pkg-ref" class="hidden" style="margin-top:8px"><input id="pkg-search" placeholder="搜索应用..." oninput="filterPkgRef()" style="margin-bottom:8px"><div id="pkg-ref-list" style="max-height:150px;overflow-y:auto;font-size:11px"></div></div>
    </div>
    <div style="display:flex;gap:10px">
      <div style="flex:1"><label>目标应用包名</label><input id="ed-launch-package" placeholder="如：com.android.settings"></div>
      <div style="flex:1"><label>启动 Activity</label><input id="ed-launch-activity" placeholder="通常留空即可"></div>
    </div>
    <div class="help-tip">💡 <b>关于 Activity：</b>绝大多数应用留空即可，系统会自动找默认启动页。只有特定页面（如 com.tencent.mm/.ui.LauncherUI）才需要填写。</div>

    <label>机型白名单（逗号分隔品牌关键字）</label>
    <input id="ed-device-allowlist" placeholder="如：Xiaomi,Redmi,OPPO,vivo">
    <div class="help-tip">💡 匹配规则：设备型号包含任一关键字即适用此技能。如填 "Xiaomi" 可匹配 Redmi Note 11T Pro（其型号含 xaga 属于小米系）。</div>

    <label>系统白名单（逗号分隔系统版本关键字）</label>
    <input id="ed-os-allowlist" placeholder="如：MIUI 14,HyperOS,ColorOS 13,One UI 5">
    <div class="help-tip">💡 不同品牌系统版本名不同：小米=MIUI/HyperOS、OPPO=ColorOS、vivo=OriginOS、三星=One UI、华为=HarmonyOS。留空则不限系统。</div>

    <label>操作步骤</label>
    <div id="steps-container"></div>
    <button class="btn primary sm" style="margin-top:8px" onclick="addStep()">+ 添加步骤</button>
    <div class="editor-actions">
      <button class="btn" onclick="closeSkillEditor()">取消</button>
      <button class="btn success" onclick="saveSkill()">💾 保存</button>
    </div>
  </div>
</div>

<script>
// ===== TAB SWITCHING =====
let currentTab = 'logs';
function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.textContent.includes(tab==='logs'?'日志':'技能')));
  document.getElementById('panel-logs').classList.toggle('hidden', tab !== 'logs');
  document.getElementById('panel-skills').classList.toggle('hidden', tab !== 'skills');
  document.getElementById('tab-skills-actions').style.display = tab === 'skills' ? 'flex' : 'none';
  if (tab === 'skills') refreshSkills();
}

// ===== LOG PANEL =====
let logFilter = 'all', paused = false, autoScroll = true, logCount = 0, retryDelay = 1000;
function setFilter(f,btn){logFilter=f;document.querySelectorAll('#panel-logs .toolbar .btn').forEach(b=>b.classList.remove('active'));if(btn)btn.classList.add('active');applySearch()}
function applySearch(){const s=(document.getElementById('search').value||'').toLowerCase();document.querySelectorAll('.log-entry').forEach(el=>{const l=el.dataset.level,m=el.textContent.toLowerCase();el.style.display=(logFilter==='all'||l===logFilter)&&(!s||m.includes(s))?'flex':'none'})}
function togglePause(){paused=!paused;document.getElementById('btn-pause').textContent=paused?'▶ 继续':'⏸ 暂停'}
function clearLogs(){document.getElementById('log-container').innerHTML='<div class="empty-state">已清屏...</div>';logCount=0}
function addLogEntry(e){if(e.type==='heartbeat'||paused)return;logCount++;const d=document.createElement('div');d.className='log-entry';d.dataset.level=e.level;d.innerHTML='<span class="log-time">'+e.time+'</span><span class="log-level '+e.level+'">'+e.level+'</span><span class="log-module">'+(e.logger||'')+'</span><span class="log-msg">'+esc(e.message)+'</span>';const c=document.getElementById('log-container');if(c.querySelector('.empty-state'))c.innerHTML='';c.appendChild(d);applySearch();if(autoScroll)c.scrollTop=c.scrollHeight;if(c.children.length>800)c.firstElementChild?.remove()}
function esc(t){return t.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}

let logSSE;
function connectLogSSE(){logSSE=new EventSource('/monitor/api/stream');logSSE.onopen=()=>{document.getElementById('conn-status').textContent='● 已连接';retryDelay=1000};logSSE.onmessage=e=>{try{addLogEntry(JSON.parse(e.data))}catch(_){}};logSSE.onerror=()=>{document.getElementById('conn-status').textContent='● 重连中';logSSE.close();setTimeout(connectLogSSE,retryDelay);retryDelay=Math.min(retryDelay*2,30000)}}
connectLogSSE();

// ===== STATS =====
async function fetchStats(){try{const r=await fetch('/monitor/api/stats');if(r.ok){const d=await r.json();document.getElementById('sys-cpu').textContent='CPU: '+d.cpu_percent+'%';document.getElementById('sys-mem').textContent='MEM: '+d.memory_percent+'%';const h=Math.floor(d.uptime_seconds/3600),m=Math.floor((d.uptime_seconds%3600)/60),s=Math.floor(d.uptime_seconds%60);document.getElementById('uptime').textContent='运行: '+(h?h+'h ':'')+m+'m '+s+'s'}}catch(_){}}
setInterval(fetchStats,3000);fetchStats();

// ===== SKILL EDITOR =====
let skills=[], editingId=null;
async function refreshSkills(){try{const r=await fetch('/api/skills');skills=await r.json();renderSkills()}catch(e){skills=[];renderSkills()}}
function renderSkills(){const c=document.getElementById('skill-list');document.getElementById('skill-count').textContent='共 '+skills.length+' 个技能';const q=(document.getElementById('skill-search')?.value||'').toLowerCase();const filtered=skills.filter(s=>!q||s.title.toLowerCase().includes(q)||s.description.toLowerCase().includes(q)||(s.device_allowlist||'').toLowerCase().includes(q)||(s.os_allowlist||'').toLowerCase().includes(q));if(!filtered.length){c.innerHTML='<div class="empty-state">暂无技能，点击「+ 新建技能」添加</div>';return}c.innerHTML='';filtered.forEach(s=>{const card=document.createElement('div');card.className='skill-card';const iconSteps=s.steps.filter(st=>st.target_type==='icon').length;const appTag=s.launch_package?' · 📱 '+(s.launch_package.split('.').pop()||'应用'):'';const devTag=s.device_allowlist?' · 🖥 '+s.device_allowlist:'';const osTag=s.os_allowlist?' · ⚙ '+s.os_allowlist:'';const stepsPreview=s.steps.map((st,i)=>(i+1)+'. '+(st.target_description||st.target_text||esc(st.instruction).slice(0,15))).join(' · ');card.innerHTML='<div class="title">'+esc(s.title)+appTag.replace(' · ','')+'</div><div class="meta">'+esc(s.description||'无描述')+' · '+s.steps.length+' 个步骤'+(iconSteps?' · 🤖 含'+iconSteps+'个图标识别':'')+devTag+osTag+' · '+s.updated_at.slice(0,16).replace('T',' ')+'</div><div class="steps-preview">'+stepsPreview+'</div><div class="actions"></div>';const acts=card.querySelector('.actions');const ebtn=document.createElement('button');ebtn.className='btn primary sm';ebtn.textContent='✏ 编辑';ebtn.onclick=function(){editSkill(s.id)};acts.appendChild(ebtn);const dbtn=document.createElement('button');dbtn.className='btn danger sm';dbtn.textContent='🗑 删除';dbtn.onclick=function(){deleteSkill(s.id)};acts.appendChild(dbtn);c.appendChild(card)})}
function filterSkills(){renderSkills()}
function openSkillEditor(){editingId=null;document.getElementById('editor-title').textContent='新建技能';document.getElementById('ed-title').value='';document.getElementById('ed-desc').value='';document.getElementById('ed-launch-package').value='';document.getElementById('ed-launch-activity').value='';document.getElementById('ed-device-allowlist').value='';document.getElementById('ed-os-allowlist').value='';document.getElementById('steps-container').innerHTML='';addStep();document.getElementById('skill-editor-overlay').classList.remove('hidden')}
function closeSkillEditor(){document.getElementById('skill-editor-overlay').classList.add('hidden')}
function editSkill(id){const s=skills.find(x=>x.id===id);if(!s)return;editingId=id;document.getElementById('editor-title').textContent='编辑技能';document.getElementById('ed-title').value=s.title;document.getElementById('ed-desc').value=s.description||'';document.getElementById('ed-launch-package').value=s.launch_package||'';document.getElementById('ed-launch-activity').value=s.launch_activity||'';document.getElementById('ed-device-allowlist').value=s.device_allowlist||'';document.getElementById('ed-os-allowlist').value=s.os_allowlist||'';const sc=document.getElementById('steps-container');sc.innerHTML='';s.steps.forEach((st,i)=>addStep(st.instruction,st.target_text||'',st.target_description||'',st.page_description||''));if(!s.steps.length)addStep();document.getElementById('skill-editor-overlay').classList.remove('hidden')}
function addStep(inst,target,targetDesc,page){const i=document.getElementById('steps-container').children.length+1;const d=document.createElement('div');d.className='step-editor';const h='<div class="step-header"><span>步骤 '+i+'</span><button class="btn danger sm" onclick="this.closest(\'.step-editor\').remove();renumberSteps()" style="font-size:11px">删除</button></div><input placeholder="操作说明，如：点击设置图标" value="'+(inst||'')+'"><div style="display:flex;gap:8px"><input placeholder="目标文字（文字按钮）" value="'+(target||'')+'" style="flex:1"><input placeholder="目标外观描述（图标按钮，如：右上角三个点）" value="'+(targetDesc||'')+'" style="flex:1"></div><input placeholder="页面描述，如：手机桌面主屏幕" value="'+(page||'')+'">';d.innerHTML=h;document.getElementById('steps-container').appendChild(d)}
function renumberSteps(){document.querySelectorAll('#steps-container .step-header span').forEach((s,i)=>{s.textContent='步骤 '+(i+1)})}
async function saveSkill(){const title=document.getElementById('ed-title').value.trim();if(!title)return alert('请输入标题');const steps=[];document.querySelectorAll('#steps-container .step-editor').forEach(ed=>{const ins=ed.querySelectorAll('input');const inst=ins[0].value.trim(),t=ins[1].value.trim(),td=ins[2].value.trim(),p=ins[3].value.trim();if(inst)steps.push({instruction:inst,target_text:t,target_description:td,target_type:td?'icon':'text',page_description:p})});if(!steps.length)return alert('请至少添加一个步骤');const body={title,description:document.getElementById('ed-desc').value.trim(),device_allowlist:document.getElementById('ed-device-allowlist').value.trim(),os_allowlist:document.getElementById('ed-os-allowlist').value.trim(),launch_package:document.getElementById('ed-launch-package').value.trim(),launch_activity:document.getElementById('ed-launch-activity').value.trim(),steps};const method=editingId?'PUT':'POST';const url=editingId?'/api/skills/'+editingId:'/api/skills';try{const r=await fetch(url,{method,headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});if(!r.ok)throw await r.text();closeSkillEditor();refreshSkills()}catch(e){alert('保存失败: '+e)}}
async function deleteSkill(id){if(!confirm('确定删除这个技能？'))return;try{await fetch('/api/skills/'+id,{method:'DELETE'});refreshSkills()}catch(e){alert('删除失败: '+e)}}

// ===== PACKAGE REFERENCE =====
const PKG_REF = [
  {n:'设置',p:'com.android.settings',a:'.Settings'},
  {n:'微信',p:'com.tencent.mm',a:'.ui.LauncherUI'},
  {n:'支付宝',p:'com.eg.android.AlipayGphone',a:''},
  {n:'抖音',p:'com.ss.android.ugc.aweme',a:''},
  {n:'QQ',p:'com.tencent.mobileqq',a:''},
  {n:'淘宝',p:'com.taobao.taobao',a:''},
  {n:'美团',p:'com.sankuai.meituan',a:''},
  {n:'头条',p:'com.ss.android.article.news',a:''},
  {n:'小红书',p:'com.xingin.xhs',a:''},
  {n:'哔哩哔哩',p:'tv.danmaku.bili',a:''},
  {n:'百度地图',p:'com.baidu.BaiduMap',a:''},
  {n:'高德地图',p:'com.autonavi.minimap',a:''},
  {n:'京东',p:'com.jingdong.app.mall',a:''},
  {n:'拼多多',p:'com.xunmeng.pinduoduo',a:''},
  {n:'网易云音乐',p:'com.netease.cloudmusic',a:''},
  {n:'QQ音乐',p:'com.tencent.qqmusic',a:''},
  {n:'相机',p:'com.android.camera',a:''},
  {n:'相册',p:'com.android.gallery3d',a:''},
  {n:'电话',p:'com.android.dialer',a:''},
  {n:'短信',p:'com.android.mms',a:''},
  {n:'浏览器',p:'com.android.browser',a:''},
  {n:'文件管理',p:'com.android.fileexplorer',a:''},
  {n:'应用商店',p:'com.android.vending',a:''},
  {n:'小米应用商店',p:'com.xiaomi.market',a:''},
  {n:'小米安全中心',p:'com.miui.securitycenter',a:''},
  {n:'OPPO软件商店',p:'com.oppo.market',a:''},
  {n:'华为应用市场',p:'com.huawei.appmarket',a:''},
  {n:'vivo应用商店',p:'com.vivo.appstore',a:''},
];
function filterPkgRef(){const q=(document.getElementById('pkg-search').value||'').toLowerCase();const list=document.getElementById('pkg-ref-list');list.innerHTML='';const filtered=PKG_REF.filter(x=>!q||x.n.toLowerCase().includes(q)||x.p.toLowerCase().includes(q));if(!filtered.length){list.innerHTML='<span style="color:#94a3b8;font-size:11px">无匹配</span>';return}filtered.forEach(x=>{const row=document.createElement('div');row.style.cssText='padding:3px 6px;cursor:pointer;border-radius:6px;display:flex;gap:8px;transition:background .1s';row.onclick=function(){document.getElementById('ed-launch-package').value=x.p;document.getElementById('ed-launch-activity').value=x.a};row.onmouseover=function(){row.style.background='#e2e8f0'};row.onmouseout=function(){row.style.background=''};row.innerHTML='<span style="color:#334155;font-weight:500">'+x.n+'</span><span style="color:#3b5998;font-family:monospace;font-size:11px">'+x.p+'</span>'+(x.a?'<span style="color:#94a3b8;font-family:monospace;font-size:11px">'+x.a+'</span>':'');list.appendChild(row)})}
filterPkgRef();

// ===== AI ANALYSIS =====
async function aiAnalyzeUrl(){const url=document.getElementById('ai-video-url').value.trim();if(!url)return alert('请输入视频链接');await runAiAnalysis('/api/skills/analyze',JSON.stringify({url}))}
async function aiAnalyzeFile(){const file=document.getElementById('ai-video-file').files[0];if(!file)return;if(file.size>200*1024*1024)return alert('视频文件不能超过200MB');const fd=new FormData();fd.append('file',file);await runAiAnalysis('/api/skills/analyze/upload',fd)}
async function runAiAnalysis(endpoint,body){const status=document.getElementById('ai-status');const btn=document.getElementById('btn-ai-analyze');status.style.display='block';status.style.color='#f59e0b';status.textContent='⏳ AI 正在分析视频，请耐心等待（约1~3分钟）...';btn&&(btn.disabled=true,btn.textContent='⏳ 解析中...');try{const r=await fetch(endpoint,{method:'POST',body:body instanceof FormData?body:body,headers:body instanceof FormData?{}:{'Content-Type':'application/json'}});if(!r.ok){const e=await r.text();throw e}const d=await r.json();document.getElementById('ed-title').value=d.title||'';const descParts=['AI 解析自视频'];if(d.app_name)descParts.push('目标应用: '+d.app_name);descParts.push('平台: '+(d.platform||'未知'));document.getElementById('ed-desc').value=descParts.join(' · ');if(d.app_package){document.getElementById('ed-launch-package').value=d.app_package}const sc=document.getElementById('steps-container');sc.innerHTML='';(d.steps||[]).forEach(s=>addStep(s.instruction,s.target_text||'',s.target_description||'',s.page_description||''));if(!(d.steps||[]).length)addStep();status.style.color='#10b981';const iconSteps=(d.steps||[]).filter(s=>s.target_type==='icon').length;status.textContent='✅ AI 解析完成！已填充 '+d.steps.length+' 个步骤'+(iconSteps?'（含 '+iconSteps+' 个图标识别）':'')+'，请人工校对后保存';btn&&(btn.disabled=false,btn.textContent='🔍 解析链接')}catch(e){status.style.color='#ef4444';status.textContent='❌ 解析失败: '+e;btn&&(btn.disabled=false,btn.textContent='🔍 解析链接')}}
</script>
</body>
</html>"""


@router.get("/monitor", response_class=HTMLResponse)
async def monitor_page():
    return MONITOR_HTML


@router.get("/monitor/api/stream")
async def log_stream(request: Request):
    capture = get_log_capture()

    async def event_generator():
        async for entry in capture.stream():
            if await request.is_disconnected():
                break
            yield f"data: {json.dumps(entry, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/monitor/api/stats")
async def system_stats():
    return JSONResponse({
        "cpu_percent": psutil.cpu_percent(interval=0.1),
        "memory_percent": psutil.virtual_memory().percent,
        "uptime_seconds": time.time() - START_TIME,
        "platform": platform.platform(),
        "python_version": platform.python_version(),
    })
