-- SimoClip — System-wide multi-slot clipboard for macOS
-- Requires: Hammerspoon  (https://hammerspoon.org)
--
-- COPY   Cmd+C  →  (keep Cmd held) press 0–9   → saves to slot
-- PASTE  Cmd+B  →  (keep Cmd held) press 0–9   → pastes from slot
-- Regular Cmd+C and Cmd+V are NEVER touched.
--
-- SHORTCUTS
--   Click  :)  in menu bar    open Slots / History panel
--   Cmd+Shift+H               quick history search (keyboard)
--   Cmd+Shift+A               AI smart search
--   Cmd+Shift+E               enable / disable
--   Cmd+Shift+X               clear all slots
--   Cmd+Ctrl+Shift+Del        clear history

-- Keep Hammerspoon's hammer icon visible as a backup reload/console access point
-- hs.menuIcon(false)  ← disabled: without this, if :) breaks there's no way to reload

-- Smaller, subtler alerts
hs.alert.defaultStyle.textSize   = 13
hs.alert.defaultStyle.radius     = 8
hs.alert.defaultStyle.fadeInDuration  = 0.1
hs.alert.defaultStyle.fadeOutDuration = 0.3

-- ── Config ─────────────────────────────────────────────────────────────────────

local CFG = {
    chordWindowSec  = 1.0,
    pasteDelaySec   = 0.05,
    maxHistoryItems = 2000,
    dataDir         = os.getenv("HOME") .. "/.simoclip/",
    claudeModel     = "claude-haiku-4-5-20251001",
}
CFG.slotsFile   = CFG.dataDir .. "slots.json"
CFG.historyFile = CFG.dataDir .. "history.json"
CFG.apiKeyFile  = CFG.dataDir .. "claude_api_key"

-- ── State ──────────────────────────────────────────────────────────────────────

local S = {
    enabled       = true,
    slots         = {},      -- [0..9] = {types, preview, contentType, ts}
    history       = {},      -- [{id,preview,content,contentType,slot,ts,date,app}]
    lastAction    = nil,     -- "copy" | "paste"
    lastActionAt  = 0,
    tap           = nil,
    pbWatcher     = nil,
    panel         = nil,     -- hs.webview
    panelUC       = nil,     -- hs.webview.usercontent
    panelPrevApp  = nil,     -- app that was frontmost when panel opened
    menubar       = nil,
    suppressWatch = false,
}

-- ── Helpers ────────────────────────────────────────────────────────────────────

local function now()   return hs.timer.secondsSinceEpoch() end
local function trim(s) if type(s)~="string" then return "" end; return s:match("^%s*(.-)%s*$") end
local function ellipsis(s, n)
    if not s or s=="" then return "" end
    s = s:gsub("[\r\n\t]+"," "):gsub("%s+"," ")
    return #s<=n and s or s:sub(1,n-1).."…"
end
local function readFile(p)
    local f=io.open(p,"r"); if not f then return nil end
    local c=f:read("*a"); f:close(); return c
end
local function writeFile(p,s)
    local f=io.open(p,"w"); if not f then return false end
    f:write(s); f:close(); return true
end

local IMAGE_UTIS = {
    ["public.png"]=true,["public.jpeg"]=true,["public.tiff"]=true,
    ["public.heic"]=true,["public.gif"]=true,["com.compuserve.gif"]=true,
    ["public.image"]=true,
}
local function detectType(pbd)
    if not pbd then return "empty" end
    for uti in pairs(pbd) do if IMAGE_UTIS[uti] then return "image" end end
    local url=pbd["public.url"]; local plain=pbd["public.utf8-plain-text"]
    if type(url)=="string"   and url:match("^https?://")   then return "url" end
    if type(plain)=="string" and plain:match("^https?://") then return "url" end
    if type(plain)=="string" then return "text" end
    return "data"
end
local function getPreview(pbd)
    if not pbd then return "(empty)" end
    for uti in pairs(pbd) do if IMAGE_UTIS[uti] then return "[image]" end end
    local url=pbd["public.url"]; local plain=pbd["public.utf8-plain-text"]
    if type(url)=="string"   and #url>0   then return "[url] "..ellipsis(url,55) end
    if type(plain)=="string" and #plain>0 then return ellipsis(plain,60) end
    return "[data]"
end
local function getTextContent(pbd)
    if not pbd then return nil end
    local url=pbd["public.url"]; local plain=pbd["public.utf8-plain-text"]
    if type(url)=="string"   and #url>0   then return url   end
    if type(plain)=="string" and #plain>0 then return plain end
    return nil
end
local function frontApp()
    local a=hs.application.frontmostApplication(); return a and a:name() or "unknown"
end

-- ── Persistence ────────────────────────────────────────────────────────────────

local function saveSlots()
    hs.fs.mkdir(CFG.dataDir)
    local out={}
    for i=0,9 do
        local sl=S.slots[i]
        if sl then
            local types={}
            for uti,data in pairs(sl.types or {}) do
                if type(data)=="string" then types[uti]={enc="s",d=data}
                else local ok,b64=pcall(hs.base64.encode,data); if ok then types[uti]={enc="b",d=b64} end
                end
            end
            out[tostring(i)]={types=types,preview=sl.preview,contentType=sl.contentType,ts=sl.ts}
        end
    end
    writeFile(CFG.slotsFile,hs.json.encode(out))
end

local function loadSlots()
    local raw=readFile(CFG.slotsFile); if not raw then return end
    local ok,data=pcall(hs.json.decode,raw); if not ok or type(data)~="table" then return end
    for key,sl in pairs(data) do
        local i=tonumber(key)
        if i and i>=0 and i<=9 then
            local types={}
            for uti,v in pairs(sl.types or {}) do
                if v.enc=="s" then types[uti]=v.d
                elseif v.enc=="b" then local ok2,dec=pcall(hs.base64.decode,v.d); if ok2 then types[uti]=dec end
                end
            end
            S.slots[i]={types=types,preview=sl.preview or "",contentType=sl.contentType or "text",ts=sl.ts or 0}
        end
    end
end

local function saveHistory()
    hs.fs.mkdir(CFG.dataDir)
    if #S.history>CFG.maxHistoryItems then
        local t={}; local s=#S.history-CFG.maxHistoryItems+1
        for i=s,#S.history do table.insert(t,S.history[i]) end; S.history=t
    end
    writeFile(CFG.historyFile,hs.json.encode(S.history))
end

local function loadHistory()
    local raw=readFile(CFG.historyFile); if not raw then return end
    local ok,data=pcall(hs.json.decode,raw)
    if ok and type(data)=="table" then S.history=data end
end

-- ── History recording ──────────────────────────────────────────────────────────

local lastHistContent=nil

local function recordHistory(pbd,slot,app)
    if not pbd then return end
    local preview=getPreview(pbd)
    local content=getTextContent(pbd) or (detectType(pbd)=="image" and "[image]" or "")
    local ctype=detectType(pbd)
    if content~="" and content==lastHistContent then return end
    lastHistContent=content
    table.insert(S.history,{
        id=#S.history+1, preview=preview, content=content,
        contentType=ctype, slot=slot, ts=now(),
        date=os.date("%Y-%m-%d %H:%M"), app=app or "unknown",
    })
    saveHistory()
end

-- ── Panel (webview two-tab UI) ─────────────────────────────────────────────────

local PANEL_HTML = [==[
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%;overflow:hidden;background:transparent}
body{
  font-family:-apple-system,'SF Pro Text',sans-serif;
  background:#fff;color:#1a1a1a;
  width:360px;display:flex;flex-direction:column;
  -webkit-user-select:none;
  border-radius:14px;
  border:1.5px solid #f48fb1;
  box-shadow:0 8px 32px rgba(0,0,0,0.18),0 0 0 0.5px rgba(233,30,140,0.15);
  overflow:hidden;
}
/* header */
.hdr{padding:14px 16px 10px;border-bottom:1px solid #fce4ec;flex:none}
.logo{font-size:15px;font-weight:700;color:#e91e8c}
.sub{font-size:10px;color:#f48fb1;margin-top:3px}
/* tabs */
.tabs{display:flex;border-bottom:2px solid #fce4ec;flex:none}
.tab{
  flex:1;padding:10px;border:none;background:#fff;
  color:#f48fb1;font-size:12px;font-weight:700;
  cursor:pointer;border-bottom:2px solid transparent;
  margin-bottom:-2px;transition:color .15s,border-color .15s;
}
.tab:hover{color:#e91e8c}
.tab.on{color:#e91e8c;border-bottom-color:#e91e8c}
/* panes — fill remaining height and scroll */
.pane{display:none;flex:1;overflow-y:auto}
.pane.on{display:block}
/* history rows */
.hr{
  padding:10px 16px;border-bottom:1px solid #fce4ec;
  cursor:pointer;transition:background .1s;
}
.hr:hover{background:#fff0f7}
.hp{font-size:13px;color:#1a1a1a;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.hm{font-size:10px;color:#f48fb1;margin-top:3px}
/* slot rows */
.row{
  display:flex;align-items:center;gap:10px;
  padding:10px 16px;border-bottom:1px solid #fce4ec;
  transition:background .1s;
}
.row:not(.empty){cursor:pointer}
.row:not(.empty):hover{background:#fff0f7}
.key{font:700 11px/1 monospace;min-width:24px}
.key.has{color:#e91e8c}
.key.emp{color:#f8bbd0}
.prv{flex:1;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.prv.emp{color:#f8bbd0;font-style:italic;font-size:12px}
.pbtn{
  font-size:11px;padding:5px 12px;border-radius:20px;border:none;
  background:#e91e8c;color:#fff;cursor:pointer;
  font-family:inherit;font-weight:700;white-space:nowrap;
  transition:background .1s;
}
.pbtn:hover{background:#c2185b}
.empty-msg{text-align:center;padding:50px 24px;color:#f8bbd0;font-size:13px;line-height:1.6}
/* scrollbar */
::-webkit-scrollbar{width:4px}
::-webkit-scrollbar-track{background:#fff}
::-webkit-scrollbar-thumb{background:#f8bbd0;border-radius:2px}
</style></head>
<body>
<div class="hdr">
  <div class="logo">:) SimoClip</div>
  <div class="sub">Cmd+C → Cmd+0–9 to save &nbsp;·&nbsp; Cmd+B → Cmd+0–9 to paste</div>
</div>
<div class="tabs">
  <button class="tab on"  onclick="doTab('hist',this)">History</button>
  <button class="tab"     onclick="doTab('slots',this)">Slots</button>
</div>
<div id="hist"  class="pane on"></div>
<div id="slots" class="pane"></div>
<script>
var histArr=[];
function doTab(id,el){
  document.querySelectorAll('.tab').forEach(function(t){t.classList.remove('on')});
  document.querySelectorAll('.pane').forEach(function(p){p.classList.remove('on')});
  el.classList.add('on');
  document.getElementById(id).classList.add('on');
}
function xe(s){return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
function post(o){window.webkit.messageHandlers.simoclip.postMessage(o)}
function renderSlots(data){
  var h='';
  for(var i=0;i<=9;i++){
    var s=data[String(i)]; var empty=!s;
    var icon=s?(s.t==='url'?'🔗 ':s.t==='image'?'🖼 ':''):'';
    h+='<div class="row'+(empty?' empty':'')+'"'
      +(!empty?' onclick="post({a:\'paste\',slot:'+i+'})"':'')+'>'+
      '<span class="key '+(empty?'emp':'has')+'">C'+i+'</span>'+
      '<span class="prv'+(empty?' emp':'')+'">'+xe(empty?'empty':icon+s.p)+'</span>'+
      (!empty?'<button class="pbtn" onclick="event.stopPropagation();post({a:\'paste\',slot:'+i+'})">Paste</button>':'')+
      '</div>';
  }
  document.getElementById('slots').innerHTML=h;
}
function renderHist(data){
  histArr=data;
  var el=document.getElementById('hist');
  if(!data||!data.length){
    el.innerHTML='<div class="empty-msg">No history yet.<br>Copy anything with Cmd+C<br>and it will show up here.</div>';
    return;
  }
  var h='';
  data.forEach(function(e,i){
    var slot=e.s!=null?' · C'+e.s:'';
    var ic=e.t==='url'?'🔗 ':e.t==='image'?'🖼 ':'';
    h+='<div class="hr" onclick="copyHist('+i+')">'+
      '<div class="hp">'+xe(ic+e.p)+'</div>'+
      '<div class="hm">'+xe(e.d)+xe(slot)+(e.a?' · '+xe(e.a):'')+'</div>'+
      '</div>';
  });
  el.innerHTML=h;
}
function copyHist(i){
  var e=histArr[i];
  if(e&&e.c) post({a:'copy',content:e.c});
}
// UTF-8 safe base64 decode
function b64d(s){
  return decodeURIComponent(atob(s).split('').map(function(c){
    return '%'+('00'+c.charCodeAt(0).toString(16)).slice(-2);
  }).join(''));
}
window._init=function(sb,hb){
  renderSlots(JSON.parse(b64d(sb)));
  renderHist(JSON.parse(b64d(hb)));
};
</script></body></html>
]==]

local function buildSlotData()
    local out={}
    for i=0,9 do
        local sl=S.slots[i]
        if sl then out[tostring(i)]={p=sl.preview or "",t=sl.contentType or "text"} end
    end
    return hs.json.encode(out)
end

local function buildHistData()
    local out={}
    local start=math.max(1,#S.history-300)
    for i=#S.history,start,-1 do
        local e=S.history[i]
        if e then
            table.insert(out,{
                p=e.preview or "", c=(e.content or ""):sub(1,500),
                t=e.contentType or "text", s=e.slot,
                d=e.date or "", a=e.app or "",
            })
        end
    end
    return hs.json.encode(out)
end

local function b64(s)
    -- Base64-encode so any content (emoji, quotes, backslashes) is safe to embed in JS
    return (hs.base64.encode(s):gsub("\n",""))
end

local function closePanel()
    if S.panel then S.panel:delete(); S.panel=nil end
    if S.panelUC then S.panelUC=nil end
end

local function showPanel()
    local ok, err = pcall(_showPanel)
    if not ok then hs.alert.show("Panel error: "..tostring(err), 5) end
end

_showPanel = function()
    -- Toggle
    if S.panel and S.panel:isShowing() then closePanel(); return end
    closePanel()

    S.panelPrevApp=hs.application.frontmostApplication()

    S.panelUC=hs.webview.usercontent.new("simoclip")
    S.panelUC:setCallback(function(msg)
        local b=msg.body
        if b.a=="paste" then
            local slot=b.slot
            closePanel()
            hs.timer.doAfter(0.12,function()
                if S.panelPrevApp then S.panelPrevApp:activate() end
                hs.timer.doAfter(0.08,function() pasteFromSlot(slot) end)
            end)
        elseif b.a=="copy" then
            if b.content and b.content~="" then
                hs.pasteboard.setContents(b.content)
                hs.alert.show("Copied ✓",1)
            end
        end
    end)

    local scr=hs.screen.mainScreen():frame()
    local W,H=360,580
    -- Position just below menu bar, right-aligned
    local x=scr.x+scr.w-W-16
    local y=scr.y+28

    S.panel=hs.webview.new({x=x,y=y,w=W,h=H},{},S.panelUC)
    S.panel:windowStyle(1 + 2 + 32768)  -- titled + closable + fullSizeContentView
    S.panel:level(hs.canvas.windowLevels.floating)
    S.panel:html(PANEL_HTML)
    S.panel:show()

    -- Inject live data after page renders (base64 avoids all escaping issues)
    hs.timer.doAfter(0.4,function()
        if S.panel then
            S.panel:evaluateJavaScript(
                "window._init('"..b64(buildSlotData()).."','"..b64(buildHistData()).."')"
            )
        end
    end)
end

-- ── Slot operations ────────────────────────────────────────────────────────────

-- Forward declaration so pasteFromSlot can be referenced before being defined
pasteFromSlot = nil

local function saveToSlot(i)
    local pbd=hs.pasteboard.readAllData()
    if not pbd then hs.alert.show("Nothing to save",1.5); return end
    S.slots[i]={types=pbd,preview=getPreview(pbd),contentType=detectType(pbd),ts=now()}
    saveSlots()
    -- Tag the latest history entry with the slot number instead of duplicating
    local content=getTextContent(pbd) or (detectType(pbd)=="image" and "[image]" or "")
    if #S.history>0 then
        local last=S.history[#S.history]
        if last.content==content and last.slot==nil then last.slot=i; saveHistory() end
    end
    hs.alert.show(string.format("C%d saved  ·  %s",i,ellipsis(S.slots[i].preview,30)),1.5)
end

pasteFromSlot=function(i)
    local sl=S.slots[i]
    if not sl or not sl.types then hs.alert.show("C"..i.." is empty",1.5); return end
    S.suppressWatch=true
    hs.pasteboard.writeAllData(sl.types)
    hs.timer.doAfter(CFG.pasteDelaySec,function()
        hs.eventtap.keyStroke({"cmd"},"v",0)
    end)
end

local function clearSlot(i)
    S.slots[i]=nil; saveSlots()
    hs.alert.show("C"..i.." cleared",1.2)
end

local function clearAllSlots()
    for i=0,9 do S.slots[i]=nil end; saveSlots()
    hs.alert.show("All slots cleared",1.5)
end

-- ── History chooser (keyboard-based quick search) ──────────────────────────────

local function openChooser(items,ph)
    if #items==0 then hs.alert.show("Nothing here",1.5); return end
    local ch=hs.chooser.new(function(sel)
        if not sel or not sel._c or sel._c=="" then return end
        hs.pasteboard.setContents(sel._c)
        hs.alert.show("Copied ✓",1)
    end)
    ch:placeholderText(ph or "Search…"); ch:choices(items); ch:rows(16); ch:width(65); ch:show()
end

local function buildItems(filter)
    local items={}
    for j=#S.history,1,-1 do
        local e=S.history[j]
        if not filter or filter(e) then
            local ic=e.contentType=="image" and "🖼" or e.contentType=="url" and "🔗" or "📋"
            local sl=e.slot~=nil and ("  [C"..e.slot.."]") or ""
            local prefix=e.slot~=nil and ("[C"..e.slot.."] ") or ""
            table.insert(items,{
                text=prefix..(e.preview or "(empty)"),
                subText=ic..sl.."  "..(e.date or "").."  "..(e.app or ""),
                _c=e.content or "",
            })
        end
    end
    return items
end

local function showHistory()    openChooser(buildItems(nil),"Search all history…  (type 'c3' to filter slot 3)") end
local function showUrlHistory() openChooser(buildItems(function(e) return e.contentType=="url" end),"URL history…") end

-- ── AI search ──────────────────────────────────────────────────────────────────

local function askText(prompt,title)
    local script=string.format([[
        set r to display dialog %q with title %q ¬
            default answer "" ¬
            buttons {"Cancel","Search"} ¬
            default button "Search"
        return text returned of r
    ]],prompt,title or "SimoClip")
    local ok,out=hs.osascript.applescript(script)
    if not ok or not out or trim(out)==""then return nil end; return trim(out)
end

local function aiSearch(query,cb)
    local key=trim(readFile(CFG.apiKeyFile) or "")
    if key=="" then cb(nil,"No API key.\nSave to: "..CFG.apiKeyFile); return end
    local lines={}
    for i=math.max(1,#S.history-300),#S.history do
        local e=S.history[i]
        if e then
            local st=e.slot~=nil and ("[C"..e.slot.."] ") or ""
            table.insert(lines,string.format("[%s] %s%s: %s",e.date or "?",st,e.contentType or "text",e.content or e.preview or ""))
        end
    end
    local prompt=string.format([==[You are a clipboard search assistant.
History (oldest first):
%s

Query: "%s"
Return JSON array only: [{"content":"...","reason":"..."}]]==],table.concat(lines,"\n"),query)
    local headers={["x-api-key"]=key,["anthropic-version"]="2023-06-01",["content-type"]="application/json"}
    local body=hs.json.encode({model=CFG.claudeModel,max_tokens=1024,messages={{role="user",content=prompt}}})
    hs.http.asyncPost("https://api.anthropic.com/v1/messages",body,headers,function(status,resp)
        if status~=200 then cb(nil,"HTTP "..status); return end
        local ok,r=pcall(hs.json.decode,resp); if not ok then cb(nil,"Parse error"); return end
        local text=r.content and r.content[1] and r.content[1].text
        if not text then cb(nil,"Empty response"); return end
        local ok2,results=pcall(hs.json.decode,text)
        if not ok2 then cb(nil,"Bad AI JSON"); return end; cb(results,nil)
    end)
end

local function showAiSearch()
    local q=askText("Describe what you're looking for:","AI Clipboard Search")
    if not q then return end
    hs.alert.show("Searching with AI…",1.5)
    aiSearch(q,function(results,err)
        if err then hs.alert.show("Error: "..err,4); return end
        if not results or #results==0 then hs.alert.show("No results",2); return end
        local items={}
        for _,r in ipairs(results) do
            table.insert(items,{text=r.content or "",subText="Why: "..(r.reason or ""),_c=r.content or ""})
        end
        openChooser(items,"AI results — click to copy")
    end)
end

-- ── Event tap ──────────────────────────────────────────────────────────────────

local DIGIT_KEY={[29]=0,[18]=1,[19]=2,[20]=3,[21]=4,[23]=5,[22]=6,[26]=7,[28]=8,[25]=9}
local KC_C=8    -- kVK_ANSI_C
local KC_B=11   -- kVK_ANSI_B  (Cmd+B → paste chord, never blocks Cmd+V)

local function onKeyDown(evt)
    if not S.enabled then return false end
    local flags=evt:getFlags(); local kc=evt:getKeyCode()
    local isCmd=flags.cmd and not flags.alt and not flags.fn and not flags.ctrl
    if not isCmd then return false end

    -- Cmd+C: mark copy mode, pass through (NEVER suppress)
    if kc==KC_C and not flags.shift then
        S.lastAction="copy"; S.lastActionAt=now()
        return false
    end

    -- Cmd+B: mark paste mode, pass through (bold still works in other apps)
    if kc==KC_B and not flags.shift then
        S.lastAction="paste"; S.lastActionAt=now()
        return false
    end

    -- Cmd+digit: chord action only within chord window
    local digit=DIGIT_KEY[kc]
    if digit~=nil and not flags.shift then
        local elapsed=now()-S.lastActionAt
        if elapsed<=CFG.chordWindowSec and S.lastAction then
            local action=S.lastAction; S.lastAction=nil; S.lastActionAt=0
            if action=="copy"  then saveToSlot(digit)    end
            if action=="paste" then pasteFromSlot(digit) end
            return true  -- suppress digit so it doesn't type into the active app
        end
    end
    return false
end

local function startTap()
    if S.tap then S.tap:stop() end
    S.tap=hs.eventtap.new({hs.eventtap.event.types.keyDown},onKeyDown)
    S.tap:start()
end
local function stopTap()
    if S.tap then S.tap:stop(); S.tap=nil end
end

-- ── Pasteboard watcher (auto-history) ──────────────────────────────────────────

local function startWatcher()
    if S.pbWatcher then S.pbWatcher:stop() end
    local ok,err=pcall(function()
        S.pbWatcher=hs.pasteboard.watcher.new(function()
            if S.suppressWatch then S.suppressWatch=false; return end
            local pbd=hs.pasteboard.readAllData()
            if pbd then recordHistory(pbd,nil,frontApp()) end
        end)
        S.pbWatcher:start()
    end)
    if not ok then print("SimoClip: pasteboard watcher error: "..tostring(err)) end
end

-- ── Menu bar ───────────────────────────────────────────────────────────────────

local function buildMenubar()
    if S.menubar then S.menubar:delete() end
    S.menubar = hs.menubar.new()
    if not S.menubar then
        hs.alert.show("SimoClip: menubar failed to create!", 5)
        return
    end
    S.menubar:setTitle(" :) ")
    S.menubar:setMenu(function()
        local slotCount = 0
        for i=0,9 do if S.slots[i] then slotCount=slotCount+1 end end
        return {
            { title = "Open Panel",    fn = showPanel },
            { title = "-" },
            { title = string.format("Clear Slots (%d/10 used)", slotCount), fn = function()
                local btn = hs.dialog.blockAlert("Clear all slots?", "C0–C9 will be erased. History kept.", "Clear", "Cancel")
                if btn == "Clear" then clearAllSlots() end
            end },
            { title = string.format("Clear History (%d entries)", #S.history), fn = function()
                local btn = hs.dialog.blockAlert("Clear all history?", string.format("%d entries will be deleted. Slots kept.", #S.history), "Clear", "Cancel")
                if btn == "Clear" then
                    S.history = {}; lastHistContent = nil; saveHistory()
                    hs.alert.show("History cleared", 1.5)
                end
            end },
            { title = "Clear Everything", fn = function()
                local btn = hs.dialog.blockAlert("Clear all slots AND history?", "This wipes everything. Cannot be undone.", "Clear All", "Cancel")
                if btn == "Clear All" then
                    for i=0,9 do S.slots[i]=nil end; saveSlots()
                    S.history = {}; lastHistContent = nil; saveHistory()
                    hs.alert.show("All data cleared", 1.5)
                end
            end },
            { title = "-" },
            { title = "Reload Config", fn = function() hs.reload() end },
            { title = "Quit SimoClip", fn = function() hs.quit() end },
        }
    end)
end

-- ── Global hotkeys ─────────────────────────────────────────────────────────────

hs.hotkey.bind({"cmd","shift"},"h", showHistory)
hs.hotkey.bind({"cmd","shift"},"u", showUrlHistory)
hs.hotkey.bind({"cmd","shift"},"a", showAiSearch)

hs.hotkey.bind({"cmd","shift"},"e",function()
    S.enabled=not S.enabled
    if S.enabled then startTap(); hs.alert.show("SimoClip  ✓  enabled",1.5)
    else stopTap(); hs.alert.show("SimoClip  ○  disabled",1.5) end
end)

hs.hotkey.bind({"cmd","shift"},"x",function()
    local btn=hs.dialog.blockAlert("Clear all slots?","C0–C9 will be erased. History kept.","Clear All","Cancel")
    if btn=="Clear All" then clearAllSlots() end
end)

hs.hotkey.bind({"cmd","ctrl","shift"},"forwarddelete",function()
    local btn=hs.dialog.blockAlert("Clear clipboard history?",
        string.format("This will erase all %d entries. Slots kept.",#S.history),"Clear History","Cancel")
    if btn=="Clear History" then
        S.history={}; lastHistContent=nil; saveHistory()
        hs.alert.show("History cleared",1.5)
    end
end)

-- ── Boot ───────────────────────────────────────────────────────────────────────

local ok, err = pcall(function()
    hs.fs.mkdir(CFG.dataDir)
    loadSlots()
    loadHistory()
    startTap()
    startWatcher()
    buildMenubar()
end)

if ok then
    hs.alert.show("SimoClip v2 ready  ·  click  :)  in menu bar", 3)
else
    hs.alert.show("SimoClip BOOT ERROR: " .. tostring(err), 8)
    print("SimoClip boot error: " .. tostring(err))
end
