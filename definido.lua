-- ================================================================================
--                    EXO HUB v7.0 - Matcha LuaVM
--                    dc: ktavex_
-- ================================================================================

local Players = game:GetService("Players")
local player  = Players.LocalPlayer or Players:FindFirstChildOfClass("Player")
local rs     = game:GetService("RunService")

-- ================================================================================
--              SAVED CONFIG
-- ================================================================================
local cfg = {
    -- Z Boost
    boostOn    = false,
    boostKey   = 0x70,
    boostKeyName = "F1",
    boostSpeed = 410,
    boostDur   = 0.3,

    -- RX Macro
    rxKey      = 0x47,
    rxKeyName  = "G",
    rxMode     = "Aimbot",

    -- F1C Macro
    f1cKey     = 0x48,
    f1cKeyName = "H",
    f1cDelay1  = 80,
    f1cDelay2  = 80,

    -- Desync Macro
    dsKey      = 0x4A,
    dsKeyName  = "J",
    dsDelay1   = 80,   -- delay LMB -> 1
    dsDelay2   = 80,   -- delay 1   -> C

    -- Menu
    menuKey        = 0x73,
    menuKeyName    = "F4",
    showHotkeyList = true,
    
    -- Custom Macros
    customMacros = {},

    -- ── Legit / Memory Trigger ──────────────────────────────────────────────
    pixelTriggerOn = false,
    pmPX           = 960,   -- pixel X  (reference only, not used in logic)
    pmPY           = 540,   -- pixel Y  (reference only, not used in logic)
}

-- ================================================================================
--              STATE
-- ================================================================================
local state = {
    menuVisible  = true,
    currentTab   = 1,
    bindingTarget= nil,
    boosting     = false,
    wasZFire     = false,
    
    -- Dragging
    dragging     = false,
    dragOffsetX  = 0,
    dragOffsetY  = 0,
    
    -- Resizing
    resizing     = false,
    resizeOffsetX = 0,
    resizeOffsetY = 0,
    
    -- Menu position and size
    menuX        = 60,
    menuY        = 80,
    menuW        = 340,
    menuH        = 420,
    minW         = 300,
    minH         = 350,
    
    -- Macro editor
    macroEditorOpen = false,
    editingMacro    = nil,
    editorX         = 100,
    editorY         = 120,
    editorW         = 360,
    editorH         = 450,
    editorMinW      = 300,
    editorMinH      = 380,
    editorDragging  = false,
    editorDragOX    = 0,
    editorDragOY    = 0,
    editorResizing  = false,
    editorResizeOX  = 0,
    editorResizeOY  = 0,
    
    -- New macro data
    newMacroKeys    = {},
    newMacroName    = "",
    newMacroActivationKey = nil,
    newMacroMode    = "hold",
    
    -- Input states
    waitingForKey      = false,
    waitingForMacroKey = false,
    editingDelayIdx    = nil,
    editingName        = false,

    -- Numeric field editing
    editingNumField    = nil,   -- "pmPX" or "pmPY"
    editingNumStr      = "",

    -- Memory Trigger internal state
    soruActive         = false,
    triggerCooldown    = false,
    triggerLastFire    = 0,
    triggerCooldownMs  = 800,   -- ms between trigger fires
}

-- ================================================================================
--              KEY UTILS
-- ================================================================================
local wasKeys = {}

local VK_NAMES = {
    [0x30]="0",[0x31]="1",[0x32]="2",[0x33]="3",[0x34]="4",
    [0x35]="5",[0x36]="6",[0x37]="7",[0x38]="8",[0x39]="9",
    [0x41]="A",[0x42]="B",[0x43]="C",[0x44]="D",[0x45]="E",
    [0x46]="F",[0x47]="G",[0x48]="H",[0x49]="I",[0x4A]="J",
    [0x4B]="K",[0x4C]="L",[0x4D]="M",[0x4E]="N",[0x4F]="O",
    [0x50]="P",[0x51]="Q",[0x52]="R",[0x53]="S",[0x54]="T",
    [0x55]="U",[0x56]="V",[0x57]="W",[0x58]="X",[0x59]="Y",
    [0x5A]="Z",
    [0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",[0x74]="F5",
    [0x75]="F6",[0x76]="F7",[0x77]="F8",[0x78]="F9",[0x79]="F10",
    [0x20]="Space",[0x10]="Shift",[0x11]="Ctrl",[0x12]="Alt",
    [0x08]="Back",[0x0D]="Enter",
}

local VK_CHARS = {
    [0x30]="0",[0x31]="1",[0x32]="2",[0x33]="3",[0x34]="4",
    [0x35]="5",[0x36]="6",[0x37]="7",[0x38]="8",[0x39]="9",
    [0x41]="a",[0x42]="b",[0x43]="c",[0x44]="d",[0x45]="e",
    [0x46]="f",[0x47]="g",[0x48]="h",[0x49]="i",[0x4A]="j",
    [0x4B]="k",[0x4C]="l",[0x4D]="m",[0x4E]="n",[0x4F]="o",
    [0x50]="p",[0x51]="q",[0x52]="r",[0x53]="s",[0x54]="t",
    [0x55]="u",[0x56]="v",[0x57]="w",[0x58]="x",[0x59]="y",
    [0x5A]="z",[0x20]=" ",
}

local function getKeyName(k) 
    if k and VK_NAMES[k] then return VK_NAMES[k] end
    return "?"
end

-- Only detect keyboard keys (not mouse buttons)
local function detectKeyboardKey()
    for vk, name in pairs(VK_NAMES) do
        if iskeypressed(vk) then 
            return vk, name 
        end
    end
    return nil, nil
end

-- ================================================================================
--              DRAWING HELPERS
-- ================================================================================
local function makeRect(x, y, w, h, color, filled, transp)
    local r = Drawing.new("Square")
    r.Position     = Vector2.new(x, y)
    r.Size         = Vector2.new(w, h)
    r.Color        = color
    r.Filled       = filled ~= false
    r.Transparency = transp or 1
    r.Visible      = true
    return r
end

local function makeTxt(x, y, txt, color, sz, center)
    local t = Drawing.new("Text")
    t.Position = Vector2.new(x, y)
    t.Text     = txt
    t.Color    = color
    t.Size     = sz or 13
    t.Font     = 2
    t.Outline  = true
    t.Center   = center or false
    t.Visible  = true
    return t
end

local function makeLine(x1, y1, x2, y2, color, thick)
    local l = Drawing.new("Line")
    l.From      = Vector2.new(x1, y1)
    l.To        = Vector2.new(x2, y2)
    l.Color     = color
    l.Thickness = thick or 1
    l.Visible   = true
    return l
end

-- ================================================================================
--              COLORS
-- ================================================================================
local C = {
    bg          = Color3.fromRGB(15, 15, 20),
    panel       = Color3.fromRGB(22, 22, 30),
    panelLight  = Color3.fromRGB(28, 28, 38),
    topbar      = Color3.fromRGB(18, 18, 25),
    accent      = Color3.fromRGB(138, 43, 226),
    accentHi    = Color3.fromRGB(167, 94, 255),
    accentDim   = Color3.fromRGB(75, 0, 130),
    border      = Color3.fromRGB(45, 45, 60),
    borderHi    = Color3.fromRGB(90, 90, 120),
    text        = Color3.fromRGB(235, 235, 245),
    textDim     = Color3.fromRGB(140, 140, 160),
    on          = Color3.fromRGB(46, 204, 113),
    onDim       = Color3.fromRGB(30, 130, 76),
    off         = Color3.fromRGB(231, 76, 60),
    offDim      = Color3.fromRGB(150, 50, 40),
    white       = Color3.fromRGB(255, 255, 255),
    yellow      = Color3.fromRGB(241, 196, 15),
    cyan        = Color3.fromRGB(26, 188, 156),
    tabOn       = Color3.fromRGB(138, 43, 226),
    tabOff      = Color3.fromRGB(30, 30, 40),
    -- Legit tab accent
    green       = Color3.fromRGB(46, 204, 113),
    greenDim    = Color3.fromRGB(20, 90, 50),
}

-- ================================================================================
--              DRAWING STORAGE
-- ================================================================================
local drawings = {
    frame = {},
    content = {},
    editor = {},
    hkList = {},
    pingText = nil,
}

local hkState = {
    x        = 10,
    y        = 200,
    w        = 210,
    minW     = 160,
    minH     = 80,
    dragging = false,
    dragOX   = 0,
    dragOY   = 0,
    resizing  = false,
    resizeOX  = 0,
    resizeOY  = 0,
}

local contentDraws = {
    toggles = {},
    keybinds = {},
    sliders = {},
    buttons = {},
    macros = {},
}

local editorBtns = {}

local function clearDrawings(tbl)
    for _, d in pairs(tbl) do
        d.Visible = false
        pcall(function() d:Remove() end)
    end
end

-- Forward declare so content builders can call it
local switchTab

-- ================================================================================
--              MENU BUILDING
-- ================================================================================
local function rebuildMenu()
    clearDrawings(drawings.frame)
    drawings.frame = {}
    
    local MX, MY = state.menuX, state.menuY
    local MW, MH = state.menuW, state.menuH
    local TAB_H  = 32
    local TABS   = {"Boost", "Macros", "Legit", "Settings"}
    
    -- Shadow
    table.insert(drawings.frame, makeRect(MX+3, MY+3, MW, MH, Color3.fromRGB(0, 0, 0), true, 0.7))
    
    -- Main frame
    table.insert(drawings.frame, makeRect(MX-1, MY-1, MW+2, MH+2, C.borderHi, true))
    table.insert(drawings.frame, makeRect(MX, MY, MW, MH, C.bg, true, 0.95))
    
    -- Top bar
    table.insert(drawings.frame, makeRect(MX, MY, MW, 38, C.topbar, true))
    table.insert(drawings.frame, makeRect(MX, MY, MW, 3, C.accent, true))
    
    -- Title
    local title = makeTxt(MX+MW/2, MY+10, "EXO HUB", C.white, 18, true)
    table.insert(drawings.frame, title)
    local subtitle = makeTxt(MX+MW/2, MY+26, "dc: ktavex_", C.textDim, 10, true)
    table.insert(drawings.frame, subtitle)
    
    -- Resize handle (3 lines, clearly visible)
    table.insert(drawings.frame, makeRect(MX+MW-18, MY+MH-6,  14, 2, C.accentHi, true))
    table.insert(drawings.frame, makeRect(MX+MW-12, MY+MH-11, 8,  2, C.accentHi, true))
    table.insert(drawings.frame, makeRect(MX+MW-6,  MY+MH-16, 2,  12, C.accentHi, true))
    
    -- Tabs
    local TAB_W = MW / #TABS
    for i, name in ipairs(TABS) do
        local tx = MX + (i-1) * TAB_W
        local ty = MY + 38
        local isActive = (i == state.currentTab)
        
        -- Special color for Legit tab
        local activeColor = (i == 3) and C.green or C.tabOn

        if isActive then
            table.insert(drawings.frame, makeRect(tx, ty, TAB_W, TAB_H, activeColor, true))
            table.insert(drawings.frame, makeRect(tx, ty, TAB_W, 2, C.white, true))
        else
            table.insert(drawings.frame, makeRect(tx, ty, TAB_W, TAB_H, C.tabOff, true))
        end
        
        local txtColor = isActive and C.white or C.textDim
        local tabTxt = makeTxt(tx + TAB_W/2, ty + 10, name, txtColor, 12, true)
        table.insert(drawings.frame, tabTxt)
    end
    
    -- Tab separator
    table.insert(drawings.frame, makeLine(MX, MY+38+TAB_H, MX+MW, MY+38+TAB_H, C.border, 1))
    
    -- Footer
    table.insert(drawings.frame, makeRect(MX, MY+MH-30, MW, 30, C.panel, true))
    table.insert(drawings.frame, makeLine(MX, MY+MH-30, MX+MW, MY+MH-30, C.border, 1))
    
    local pingTxt = makeTxt(MX+12, MY+MH-22, "Ping: --ms", C.textDim, 11)
    table.insert(drawings.frame, pingTxt)
    drawings.pingText = pingTxt
end

-- ================================================================================
--              CONTENT BUILDERS
-- ================================================================================
local contentY = 0
local CX, CW = 0, 0

local function addContent(d)
    table.insert(drawings.content, d)
    return d
end

local function contentStart()
    clearDrawings(drawings.content)
    drawings.content = {}
    contentDraws.toggles = {}
    contentDraws.keybinds = {}
    contentDraws.sliders = {}
    contentDraws.buttons = {}
    contentDraws.macros = {}
    contentY = state.menuY + 38 + 32 + 10
    CX = state.menuX + 12
    CW = state.menuW - 24
end

local function nextY(h)
    local y = contentY
    contentY = contentY + (h or 26)
    return y
end

local function drawSection(label)
    local y = nextY(24)
    addContent(makeRect(CX-2, y-2, CW+4, 22, C.panelLight, true))
    addContent(makeRect(CX, y+3, 3, 12, C.accent, true))
    addContent(makeTxt(CX+10, y+2, label:upper(), C.accentHi, 12))
    nextY(4)
end

local function drawSectionColored(label, color)
    local y = nextY(24)
    addContent(makeRect(CX-2, y-2, CW+4, 22, C.panelLight, true))
    addContent(makeRect(CX, y+3, 3, 12, color, true))
    addContent(makeTxt(CX+10, y+2, label:upper(), color, 12))
    nextY(4)
end

local function drawToggle(id, label, valKey)
    local y = nextY(30)
    local val = cfg[valKey]
    
    addContent(makeRect(CX, y, CW, 28, C.panel, true))
    addContent(makeRect(CX, y, 3, 28, val and C.on or C.off, true))
    addContent(makeTxt(CX+12, y+7, label, C.text, 13))
    
    local switchX = CX + CW - 50
    addContent(makeRect(switchX, y+5, 44, 18, val and C.onDim or C.offDim, true))
    addContent(makeRect(switchX+2, y+7, 40, 14, C.panelLight, true))
    
    local dotX = val and (switchX+26) or (switchX+6)
    local dot = addContent(makeRect(dotX, y+9, 10, 10, val and C.on or C.off, true))
    
    contentDraws.toggles[id] = { dot = dot, valKey = valKey, x = CX, y = y, w = CW, h = 28 }
end

local function drawKeybind(id, label, keyKey, nameKey)
    local y = nextY(30)
    
    addContent(makeRect(CX, y, CW, 28, C.panel, true))
    addContent(makeRect(CX, y, 3, 28, C.cyan, true))
    addContent(makeTxt(CX+12, y+7, label, C.text, 13))
    
    local btnW = 70
    local btnX = CX + CW - btnW - 6
    addContent(makeRect(btnX, y+4, btnW, 20, C.accentDim, true))
    addContent(makeRect(btnX+1, y+5, btnW-2, 18, C.panelLight, true))
    
    local keyName = cfg[nameKey] or "..."
    local val = addContent(makeTxt(btnX + btnW/2, y+7, "["..keyName.."]", C.accentHi, 12, true))
    
    contentDraws.keybinds[id] = { txt = val, keyKey = keyKey, nameKey = nameKey, x = CX, y = y, w = CW, h = 28 }
end

local function drawSlider(id, label, valKey, minV, maxV, suffix)
    local y = nextY(38)
    local val = cfg[valKey] or minV
    suffix = suffix or ""
    
    addContent(makeRect(CX, y, CW, 36, C.panel, true))
    addContent(makeRect(CX, y, 3, 36, C.yellow, true))
    addContent(makeTxt(CX+12, y+4, label, C.textDim, 11))
    local valTxt = addContent(makeTxt(CX+CW-12, y+4, val..suffix, C.yellow, 12))
    valTxt.Center = false
    
    local trackX = CX + 12
    local trackW = CW - 24
    local trackY = y + 22
    addContent(makeRect(trackX, trackY, trackW, 6, C.panelLight, true))
    
    local pct = (val - minV) / (maxV - minV)
    local fill = addContent(makeRect(trackX, trackY, math.max(6, trackW * pct), 6, C.accent, true))
    local thumb = addContent(makeRect(trackX + trackW * pct - 5, trackY - 2, 10, 10, C.accentHi, true))
    
    contentDraws.sliders[id] = {
        valKey = valKey, minV = minV, maxV = maxV, suffix = suffix,
        trackX = trackX, trackY = trackY, trackW = trackW,
        fill = fill, thumb = thumb, valTxt = valTxt,
        x = CX, y = y, w = CW, h = 36
    }
end

local function drawButton(id, label, callback, color)
    local y = nextY(32)
    color = color or C.accent
    
    addContent(makeRect(CX, y, CW, 30, color, true))
    addContent(makeRect(CX+1, y+1, CW-2, 28, C.panel, true))
    addContent(makeRect(CX+2, y+2, CW-4, 26, color, true, 0.3))
    addContent(makeTxt(CX + CW/2, y+8, label, C.white, 13, true))
    
    contentDraws.buttons[id] = { x = CX, y = y, w = CW, h = 30, callback = callback }
end

local function drawSpacing(h)
    nextY(h or 8)
end

-- Two-option pill selector
local function drawPillSelect(id, label, valKey, opt1, opt2)
    local y = nextY(30)
    local val = cfg[valKey]

    addContent(makeRect(CX, y, CW, 28, C.panel, true))
    addContent(makeRect(CX, y, 3, 28, C.cyan, true))
    addContent(makeTxt(CX+12, y+7, label, C.text, 12))

    local pillW = 84
    local gap   = 4
    local pillX = CX + CW - pillW*2 - gap - 6

    local a1 = val == opt1
    addContent(makeRect(pillX,            y+5, pillW, 18, a1 and C.accent or C.panelLight, true))
    addContent(makeTxt(pillX+pillW/2,     y+8, opt1,  a1 and C.white or C.textDim, 10, true))

    local a2 = val == opt2
    addContent(makeRect(pillX+pillW+gap,  y+5, pillW, 18, a2 and C.accent or C.panelLight, true))
    addContent(makeTxt(pillX+pillW+gap+pillW/2, y+8, opt2, a2 and C.white or C.textDim, 10, true))

    contentDraws.buttons["pill_"..id.."_1"] = { x=pillX, y=y+5, w=pillW, h=18, callback=function()
        cfg[valKey] = opt1; state.tpSpamming = false
        switchTab(state.currentTab)
    end}
    contentDraws.buttons["pill_"..id.."_2"] = { x=pillX+pillW+gap, y=y+5, w=pillW, h=18, callback=function()
        cfg[valKey] = opt2; state.tpSpamming = false
        switchTab(state.currentTab)
    end}
end

local function drawNumInput(id, label, cfgKey)
    local y = nextY(30)
    local isEditing = (state.editingNumField == cfgKey)
    local displayVal = isEditing and (state.editingNumStr == "" and "|" or state.editingNumStr.."|")
                                 or tostring(cfg[cfgKey])

    addContent(makeRect(CX, y, CW, 28, C.panel, true))
    addContent(makeRect(CX, y, 3, 28, C.yellow, true))
    addContent(makeTxt(CX+12, y+7, label, C.text, 13))

    local boxW = 90
    local boxX = CX + CW - boxW - 6
    addContent(makeRect(boxX, y+4, boxW, 20, isEditing and C.accentDim or C.panelLight, true))
    addContent(makeRect(boxX, y+4, boxW, 20, isEditing and C.accent or C.border, false))
    addContent(makeTxt(boxX + boxW/2, y+7, displayVal, isEditing and C.yellow or C.accentHi, 12, true))

    contentDraws.buttons["numinput_"..id] = { x=boxX, y=y+4, w=boxW, h=20, callback=function()
        state.editingNumField = cfgKey
        state.editingNumStr   = tostring(cfg[cfgKey])
        state.waitingForKey   = false
        state.waitingForMacroKey = false
        state.editingName     = false
        switchTab(state.currentTab)
    end}
end

local function drawMacroItem(idx, macro)
    local y = nextY(34)
    
    addContent(makeRect(CX, y, CW, 32, C.panel, true))
    addContent(makeRect(CX, y, 3, 32, C.accent, true))
    
    addContent(makeTxt(CX+12, y+4, macro.name, C.text, 13))
    
    local modeText = macro.mode == "toggle" and "TOGGLE" or "HOLD"
    addContent(makeTxt(CX+12, y+18, "Key: "..getKeyName(macro.activationKey).." | "..modeText.." | "..#macro.keys.." keys", C.textDim, 10))
    
    local editX = CX + CW - 70
    addContent(makeRect(editX, y+6, 60, 20, C.accentDim, true))
    addContent(makeTxt(editX+30, y+9, "EDIT", C.accentHi, 10, true))
    
    local delX = CX + CW - 28
    addContent(makeRect(delX, y+6, 22, 20, C.offDim, true))
    addContent(makeTxt(delX+11, y+9, "X", C.off, 11, true))
    
    contentDraws.macros[idx] = { 
        x = CX, y = y, w = CW, h = 32, 
        delX = delX, editX = editX,
        macro = macro, idx = idx
    }
end

-- ================================================================================
--              MACRO EDITOR
-- ================================================================================
local function buildMacroEditor()
    clearDrawings(drawings.editor)
    editorBtns = {}
    
    if not state.macroEditorOpen then return end
    
    local MX, MY = state.editorX, state.editorY
    local MW, MH = state.editorW, state.editorH
    
    -- Shadow
    table.insert(drawings.editor, makeRect(MX+3, MY+3, MW, MH, Color3.fromRGB(0, 0, 0), true, 0.7))
    
    -- Main frame
    table.insert(drawings.editor, makeRect(MX-1, MY-1, MW+2, MH+2, C.borderHi, true))
    table.insert(drawings.editor, makeRect(MX, MY, MW, MH, C.bg, true, 0.97))
    
    -- Title bar
    table.insert(drawings.editor, makeRect(MX, MY, MW, 32, C.accentDim, true))
    table.insert(drawings.editor, makeRect(MX, MY, MW, 2, C.accent, true))
    
    local title = state.editingMacro and ("Edit: " .. state.editingMacro.name) or "Create New Macro"
    table.insert(drawings.editor, makeTxt(MX+MW/2, MY+9, title, C.white, 14, true))
    
    -- Close button
    table.insert(drawings.editor, makeRect(MX+MW-26, MY+6, 20, 20, C.offDim, true))
    table.insert(drawings.editor, makeTxt(MX+MW-16, MY+7, "X", C.off, 14, true))
    editorBtns.close = { x = MX+MW-26, y = MY+6, w = 20, h = 20 }
    
    -- Draggable title area
    editorBtns.titleBar = { x = MX, y = MY, w = MW-28, h = 32 }
    
    local y = MY + 40
    local x = MX + 12
    local w = MW - 24
    
    -- Name Input
    table.insert(drawings.editor, makeTxt(x, y+4, "NAME", C.textDim, 10))
    table.insert(drawings.editor, makeRect(x+50, y, w-50, 24, C.panelLight, true))
    table.insert(drawings.editor, makeRect(x+50, y, w-50, 24, state.editingName and C.accent or C.border, false))
    
    local nameVal = state.newMacroName ~= "" and state.newMacroName or "Click to name..."
    local nameTxt = makeTxt(x+56, y+6, nameVal, state.editingName and C.yellow or C.text, 12)
    nameTxt.Center = false
    table.insert(drawings.editor, nameTxt)
    editorBtns.nameInput = { x = x+50, y = y, w = w-50, h = 24 }
    
    y = y + 34
    
    -- Mode selection (Hold/Toggle)
    table.insert(drawings.editor, makeTxt(x, y+4, "MODE", C.textDim, 10))
    
    local holdActive = state.newMacroMode == "hold"
    local holdX = x + 50
    table.insert(drawings.editor, makeRect(holdX, y, 80, 24, holdActive and C.accent or C.border, true))
    table.insert(drawings.editor, makeTxt(holdX+40, y+6, "HOLD", holdActive and C.white or C.textDim, 11, true))
    editorBtns.holdBtn = { x = holdX, y = y, w = 80, h = 24 }
    
    local toggleX = x + 135
    table.insert(drawings.editor, makeRect(toggleX, y, 80, 24, not holdActive and C.accent or C.border, true))
    table.insert(drawings.editor, makeTxt(toggleX+40, y+6, "TOGGLE", not holdActive and C.white or C.textDim, 11, true))
    editorBtns.toggleBtn = { x = toggleX, y = y, w = 80, h = 24 }
    
    y = y + 32
    
    -- Keys section
    table.insert(drawings.editor, makeTxt(x, y+4, "KEYS", C.textDim, 10))
    table.insert(drawings.editor, makeTxt(x+40, y+4, "(click [+] to add keys)", C.yellow, 10))
    y = y + 20
    
    -- Keys container
    table.insert(drawings.editor, makeRect(x, y, w, 90, C.panelLight, true))
    
    local keyY = y + 10
    local keyX = x + 10
    
    for i, keyData in ipairs(state.newMacroKeys) do
        if keyX + 70 > x + w - 10 then
            keyX = x + 10
            keyY = keyY + 55
        end
        
        -- Key box
        table.insert(drawings.editor, makeRect(keyX, keyY, 65, 40, C.accentDim, true))
        table.insert(drawings.editor, makeRect(keyX+1, keyY+1, 63, 38, C.panel, true))
        
        -- Key name
        table.insert(drawings.editor, makeTxt(keyX+32, keyY+5, getKeyName(keyData.key), C.white, 14, true))
        
        -- Delay value
        table.insert(drawings.editor, makeTxt(keyX+32, keyY+22, keyData.delay.."ms", C.yellow, 11, true))
        
        -- Remove key button
        table.insert(drawings.editor, makeRect(keyX+52, keyY+2, 12, 14, C.offDim, true))
        table.insert(drawings.editor, makeTxt(keyX+58, keyY+2, "X", C.off, 9, true))
        
        editorBtns["editDelay"..i] = { x = keyX, y = keyY, w = 65, h = 40, idx = i }
        editorBtns["removeKey"..i] = { x = keyX+52, y = keyY+2, w = 12, h = 14, idx = i }
        
        keyX = keyX + 72
    end
    
    -- Add key button
    if keyX + 50 > x + w - 10 then
        keyX = x + 10
        keyY = keyY + 55
    end
    table.insert(drawings.editor, makeRect(keyX, keyY, 45, 40, C.border, true))
    table.insert(drawings.editor, makeRect(keyX+1, keyY+1, 43, 38, C.panelLight, true))
    if state.waitingForKey then
        table.insert(drawings.editor, makeTxt(keyX+22, keyY+12, "...", C.yellow, 16, true))
    else
        table.insert(drawings.editor, makeTxt(keyX+22, keyY+12, "+", C.textDim, 18, true))
    end
    editorBtns.addKey = { x = keyX, y = keyY, w = 45, h = 40 }
    
    y = y + 100
    
    -- Activation key
    table.insert(drawings.editor, makeTxt(x, y+4, "ACTIVATION KEY", C.textDim, 10))
    
    local actKey = state.newMacroActivationKey
    local actKeyName = actKey and actKey > 0 and getKeyName(actKey) or "..."
    
    table.insert(drawings.editor, makeRect(x+110, y-2, 100, 24, C.panelLight, true))
    table.insert(drawings.editor, makeRect(x+110, y-2, 100, 24, state.waitingForMacroKey and C.yellow or C.border, false))
    
    if state.waitingForMacroKey then
        table.insert(drawings.editor, makeTxt(x+160, y+4, "press...", C.yellow, 12, true))
    else
        table.insert(drawings.editor, makeTxt(x+160, y+4, actKeyName, actKey and C.accentHi or C.textDim, 13, true))
    end
    editorBtns.actKey = { x = x+110, y = y-2, w = 100, h = 24 }
    
    y = y + 32
    
    -- Delay editor
    if state.editingDelayIdx and state.newMacroKeys[state.editingDelayIdx] then
        local idx = state.editingDelayIdx
        local keyData = state.newMacroKeys[idx]
        
        table.insert(drawings.editor, makeRect(x, y, w, 60, C.panel, true))
        table.insert(drawings.editor, makeRect(x, y, 3, 60, C.yellow, true))
        
        -- Close button first
        table.insert(drawings.editor, makeRect(x+w-20, y+4, 16, 16, C.border, true))
        table.insert(drawings.editor, makeTxt(x+w-12, y+5, "X", C.textDim, 10, true))
        editorBtns.closeDelayEdit = { x = x+w-20, y = y+4, w = 16, h = 16 }
        
        -- Label (after close button)
        table.insert(drawings.editor, makeTxt(x+12, y+6, "DELAY: "..getKeyName(keyData.key), C.text, 11))
        table.insert(drawings.editor, makeTxt(x+w-50, y+6, keyData.delay.."ms", C.yellow, 13))
        
        -- Delay slider
        local sliderX = x + 12
        local sliderW = w - 24
        local sliderY = y + 32
        table.insert(drawings.editor, makeRect(sliderX, sliderY, sliderW, 8, C.panelLight, true))
        
        local pct = keyData.delay / 500
        table.insert(drawings.editor, makeRect(sliderX, sliderY, math.max(8, sliderW * pct), 8, C.accent, true))
        table.insert(drawings.editor, makeRect(sliderX + sliderW * pct - 6, sliderY - 3, 12, 14, C.accentHi, true))
        
        editorBtns.delayEditSlider = { 
            x = sliderX, y = sliderY - 4, w = sliderW, h = 16,
            trackX = sliderX, trackW = sliderW, idx = idx
        }
        
        y = y + 68
    end
    
    -- Action buttons
    local btnW = (w - 10) / 2
    
    table.insert(drawings.editor, makeRect(x, y, btnW, 32, C.onDim, true))
    table.insert(drawings.editor, makeRect(x+1, y+1, btnW-2, 30, C.panel, true))
    table.insert(drawings.editor, makeRect(x+2, y+2, btnW-4, 28, C.on, true, 0.2))
    table.insert(drawings.editor, makeTxt(x+btnW/2, y+9, "SAVE", C.white, 13, true))
    editorBtns.save = { x = x, y = y, w = btnW, h = 32 }
    
    table.insert(drawings.editor, makeRect(x+btnW+10, y, btnW, 32, C.offDim, true))
    table.insert(drawings.editor, makeRect(x+btnW+11, y+1, btnW-2, 30, C.panel, true))
    table.insert(drawings.editor, makeRect(x+btnW+12, y+2, btnW-4, 28, C.off, true, 0.2))
    table.insert(drawings.editor, makeTxt(x+btnW+10+btnW/2, y+9, "CANCEL", C.white, 13, true))
    editorBtns.cancel = { x = x+btnW+10, y = y, w = btnW, h = 32 }
    
    y = y + 38
    table.insert(drawings.editor, makeTxt(x, y, "Hold: all keys at once | Toggle: one key per press", C.textDim, 9))

    -- Resize handle (bottom-right corner, same style as main menu)
    table.insert(drawings.editor, makeRect(MX+MW-14, MY+MH-14, 10, 2, C.borderHi, true))
    table.insert(drawings.editor, makeRect(MX+MW-10, MY+MH-10, 6,  2, C.borderHi, true))
    editorBtns.resizeHandle = { x = MX+MW-20, y = MY+MH-20, w = 20, h = 20 }
end

local function closeMacroEditor()
    state.macroEditorOpen = false
    state.editingMacro = nil
    state.newMacroKeys = {}
    state.newMacroName = ""
    state.newMacroActivationKey = nil
    state.newMacroMode = "hold"
    state.waitingForKey = false
    state.waitingForMacroKey = false
    state.editingDelayIdx = nil
    state.editingName = false
    clearDrawings(drawings.editor)
    drawings.editor = {}
    editorBtns = {}
end

-- ================================================================================
--              TAB CONTENT BUILDERS
-- ================================================================================
local function buildBoost()
    contentStart()
    
    drawSpacing(4)
    drawSection("Z Sanguine Boost")
    drawToggle("boost", "Enable Boost", "boostOn")
    drawKeybind("boostKey", "Toggle Key", "boostKey", "boostKeyName")
    drawSlider("boostSpeed", "Speed", "boostSpeed", 50, 1500, "")
    drawSlider("boostDur", "Duration", "boostDurMs", 1, 30, " ticks")
end

local function buildMacros()
    contentStart()
    
    drawSpacing(4)
    drawSection("Built-in Macros")
    drawKeybind("rxKey", "R+X", "rxKey", "rxKeyName")
    drawSpacing(4)
    drawKeybind("f1cKey", "F-1-C", "f1cKey", "f1cKeyName")
    drawSlider("f1cDelay1", "Delay F->1", "f1cDelay1", 0, 500, "ms")
    drawSlider("f1cDelay2", "Delay 1->C", "f1cDelay2", 0, 500, "ms")
    drawSpacing(4)
    drawKeybind("dsKey", "Desync", "dsKey", "dsKeyName")
    drawSlider("dsDelay1", "Delay LMB->1", "dsDelay1", 0, 500, "ms")
    drawSlider("dsDelay2", "Delay 1->C", "dsDelay2", 0, 500, "ms")
    
    drawSpacing(8)
    drawSection("Custom Macros")
    
    for i, macro in ipairs(cfg.customMacros) do
        drawMacroItem(i, macro)
    end
    
    drawSpacing(6)
    drawButton("newMacro", "+ CREATE NEW MACRO", function()
        state.macroEditorOpen = true
        state.editingMacro = nil
        state.newMacroKeys = {}
        state.newMacroName = ""
        state.newMacroActivationKey = nil
        state.newMacroMode = "hold"
        state.editorX = state.menuX + 40
        state.editorY = state.menuY + 50
        state.editingDelayIdx = nil
        buildMacroEditor()
    end)
end

-- ================================================================================
--              LEGIT TAB - MEMORY TRIGGER
-- ================================================================================
local function buildLegit()
    contentStart()

    drawSpacing(4)
    drawSectionColored("Memory Trigger", C.green)

    drawToggle("pixelTrigger", "Pixel Trigger", "pixelTriggerOn")

    drawSpacing(6)
    drawSectionColored("Reference Coords", C.yellow)

    drawNumInput("pmPX", "Pixel X", "pmPX")
    drawNumInput("pmPY", "Pixel Y", "pmPY")

    drawSpacing(10)

    -- Status indicator box
    local y = contentY
    addContent(makeRect(CX, y, CW, 44, C.panel, true))
    addContent(makeRect(CX, y, 3, 44, C.green, true))

    local statusLabel = cfg.pixelTriggerOn
        and (state.soruActive and "STATE: SORU ACTIVE  >>  FIRING X" or "STATE: MONITORING...")
        or "STATE: DISABLED"
    local statusColor = cfg.pixelTriggerOn
        and (state.soruActive and C.on or C.yellow)
        or C.off

    addContent(makeTxt(CX+12, y+6, "Memory Trigger Status", C.textDim, 10))
    addContent(makeTxt(CX+12, y+20, statusLabel, statusColor, 12))

    local cdLabel = cfg.pixelTriggerOn
        and ("Cooldown: " .. tostring(state.triggerCooldownMs) .. "ms")
        or ""
    addContent(makeTxt(CX+12, y+33, cdLabel, C.textDim, 9))
    nextY(44)

    drawSpacing(10)

    -- Info box
    local iy = contentY
    addContent(makeRect(CX, iy, CW, 70, C.panelLight, true))
    addContent(makeRect(CX, iy, 3, 70, C.cyan, true))
    addContent(makeTxt(CX+12, iy+6,  ">> Memory-based: no color detection", C.textDim, 10))
    addContent(makeTxt(CX+12, iy+20, ">> Detects Soru state via Instance tree", C.textDim, 10))
    addContent(makeTxt(CX+12, iy+34, ">> Auto-fires Portal X instantly", C.text,    10))
    addContent(makeTxt(CX+12, iy+48, ">> Resolution independent", C.textDim, 10))
    addContent(makeTxt(CX+12, iy+60, ">> Pixel X/Y are reference only", C.yellow,   9))
    nextY(70)
end

local function buildSettings()
    contentStart()
    
    drawSpacing(4)
    drawSection("Menu Settings")
    drawKeybind("menuKey", "Toggle Menu", "menuKey", "menuKeyName")
    drawToggle("hkList", "Keybind List", "showHotkeyList")
    
    drawSpacing(10)
    drawSection("Instructions")
    
    local y = contentY
    addContent(makeRect(CX, y, CW, 90, C.panel, true))
    addContent(makeTxt(CX+12, y+8,  ">> Drag title bar to move menu",    C.text, 11))
    addContent(makeTxt(CX+12, y+24, ">> Drag corner to resize",           C.text, 11))
    addContent(makeTxt(CX+12, y+40, ">> Click keybinds to rebind",        C.text, 11))
    addContent(makeTxt(CX+12, y+56, ">> Hold: all keys at once",          C.text, 11))
    addContent(makeTxt(CX+12, y+72, ">> Toggle: one key per press",       C.yellow, 11))
    nextY(90)
end


local tabBuilders = { buildBoost, buildMacros, buildLegit, buildSettings }

-- ================================================================================
--              MOUSE HELPERS
-- ================================================================================
local mouse = player:GetMouse()
local mouseX, mouseY = 0, 0

local function updateMouse()
    mouseX = mouse.X
    mouseY = mouse.Y
end

local function inBox(mx, my, x, y, w, h)
    return mx >= x and mx <= x+w and my >= y and my <= y+h
end

-- ================================================================================
--              MACROS EXECUTION
-- ================================================================================
local function fireRX()
    -- Aimbot mode: instant R+X
    keypress(0x52)
    keypress(0x58)
    keyrelease(0x52)
    keyrelease(0x58)
end

local function fireF1C()
    keypress(0x46)
    keyrelease(0x46)
    task.wait(cfg.f1cDelay1 / 1000)
    keypress(0x31)
    keyrelease(0x31)
    task.wait(cfg.f1cDelay2 / 1000)
    keypress(0x43)
    keyrelease(0x43)
end

local function fireDesync()
    mouse1click()                      -- LMB
    task.wait(cfg.dsDelay1 / 1000)
    keypress(0x31)                     -- 1
    keyrelease(0x31)
    task.wait(cfg.dsDelay2 / 1000)
    keypress(0x43)                     -- C
    keyrelease(0x43)
end

local macroToggleState = {}

local function fireCustomMacro(macro)
    if not macro or not macro.keys or #macro.keys == 0 then
        return
    end
    
    if macro.mode == "toggle" then
        -- Toggle mode: press one key at a time
        local idx = macroToggleState[macro] or 1
        if idx > #macro.keys then idx = 1 end
        
        local keyData = macro.keys[idx]
        if keyData and keyData.key then
            keypress(keyData.key)
            task.wait(0.01)
            keyrelease(keyData.key)
        end
        
        macroToggleState[macro] = idx + 1
    else
        -- Hold mode: press all keys at once
        for i, keyData in ipairs(macro.keys) do
            if keyData and keyData.key then
                keypress(keyData.key)
                task.wait(0.01)
                keyrelease(keyData.key)
                if keyData.delay and keyData.delay > 0 and i < #macro.keys then
                    task.wait(keyData.delay / 1000)
                end
            end
        end
    end
end

-- ================================================================================
--              MEMORY TRIGGER (Soru → Portal X)
-- ================================================================================
-- Detects the Soru state by scanning the character's Instance tree for a
-- well-known marker object that the game creates when Soru is active.
-- No pixel / color detection is used at all.
-- The trigger fires Portal X (key 0x58) the moment Soru is detected,
-- then enters a cooldown period to prevent spam.
--
-- Known Soru marker names (extend this list if the game changes them):
local SORU_MARKERS = {
    "SoruEffect",
    "SoruActive",
    "SoruState",
    "SoruAnim",
    "SoruTrail",
    "Soru",
}

local function hasSoruMarker(char)
    if not char then return false end
    -- Check direct children first (fastest)
    for _, name in ipairs(SORU_MARKERS) do
        if char:FindFirstChild(name) then
            return true
        end
    end
    -- Fallback: scan descendants for any object whose name contains "Soru"
    for _, desc in ipairs(char:GetDescendants()) do
        local n = desc.Name:lower()
        if n:find("soru") then
            return true
        end
    end
    return false
end

-- Portal X fire: sends key X (0x58)
local function firePortalX()
    keypress(0x58)
    task.wait(0.01)
    keyrelease(0x58)
end

-- Main trigger loop — runs every Heartbeat, very low overhead
rs.Heartbeat:Connect(function()
    if not cfg.pixelTriggerOn then
        state.soruActive = false
        return
    end

    local char = player.Character
    if not char then
        state.soruActive = false
        return
    end

    local soruNow = hasSoruMarker(char)

    -- Rising edge: Soru just became active
    if soruNow and not state.soruActive then
        state.soruActive = true

        -- Cooldown gate (prevents double-fire)
        local now = os.clock() * 1000  -- ms
        if (now - state.triggerLastFire) >= state.triggerCooldownMs then
            state.triggerLastFire = now
            -- Fire instantly, no delay
            task.spawn(firePortalX)

            -- Refresh Legit tab status if visible
            if state.menuVisible and state.currentTab == 3 then
                tabBuilders[3]()
            end
        end

    elseif not soruNow then
        state.soruActive = false
    end
end)

-- ================================================================================
--              Z BOOST
-- ================================================================================
rs.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local zFire = root:FindFirstChild("SanguineArtZFire") ~= nil

    if cfg.boostOn and zFire and not state.wasZFire and not state.boosting then
        state.boosting = true
        local spd = cfg.boostSpeed
        local dur = (cfg.boostDurMs or 3) / 10
        local lv  = root.CFrame.LookVector
        task.spawn(function()
            local t = os.clock() + dur
            while os.clock() < t do
                local c = player.Character
                if not c then break end
                local r = c:FindFirstChild("HumanoidRootPart")
                if not r then break end
                r.AssemblyLinearVelocity = Vector3.new(lv.X * spd, lv.Y * spd, lv.Z * spd)
                task.wait()
            end
            state.boosting = false
        end)
    end
    state.wasZFire = zFire
end)

-- ================================================================================
--              PING UPDATE
-- ================================================================================
task.spawn(function()
    while true do
        local ok, p = pcall(GetPingValue)
        if ok and drawings.pingText then
            drawings.pingText.Text = "Ping: " .. tostring(p) .. "ms"
            drawings.pingText.Color = p < 80 and C.on or (p < 150 and C.yellow or C.off)
        end
        task.wait(1)
    end
end)

-- ================================================================================
--              MAIN INIT
-- ================================================================================
if not cfg.boostDurMs then cfg.boostDurMs = math.floor(cfg.boostDur * 10) end

-- ================================================================================
--              HOTKEY LIST OVERLAY
-- ================================================================================
local function buildHotkeyList()
    clearDrawings(drawings.hkList)
    drawings.hkList = {}
    if not cfg.showHotkeyList then return end

    local entries = {
        { label = "Z Boost",     key = cfg.boostKeyName or getKeyName(cfg.boostKey), isBoost = true },
        { label = "R+X ["..(cfg.rxMode or "Aimbot").."]", key = cfg.rxKeyName or getKeyName(cfg.rxKey) },
        { label = "F-1-C Macro", key = cfg.f1cKeyName   or getKeyName(cfg.f1cKey) },
        { label = "Desync",      key = cfg.dsKeyName    or getKeyName(cfg.dsKey) },
        { label = "Menu",        key = cfg.menuKeyName  or getKeyName(cfg.menuKey) },
        { label = "Pixel Trigger", key = cfg.pixelTriggerOn and "ON" or "OFF", isTrigger = true },
    }
    for _, macro in ipairs(cfg.customMacros) do
        table.insert(entries, { label = macro.name, key = getKeyName(macro.activationKey) })
    end

    local HX  = hkState.x
    local HY  = hkState.y
    local HW  = hkState.w
    -- ROW height scales with width so text fits; clamp between 18 and 26
    local ROW = math.clamp(math.floor(HW / 10), 18, 26)
    local fontSize = math.clamp(math.floor(HW / 19), 9, 13)
    local HH  = 30 + #entries * ROW + 6

    local function ins(d) table.insert(drawings.hkList, d) end

    -- Shadow
    ins(makeRect(HX+3, HY+3, HW, HH, Color3.fromRGB(0,0,0), true, 0.7))
    -- Outer border
    ins(makeRect(HX-1, HY-1, HW+2, HH+2, C.borderHi, true))
    -- Background
    ins(makeRect(HX, HY, HW, HH, C.bg, true, 0.95))
    -- Top accent stripe
    ins(makeRect(HX, HY, HW, 3, C.accent, true))
    -- Header bar
    ins(makeRect(HX, HY, HW, 28, C.topbar, true))
    -- Header title
    ins(makeTxt(HX + HW/2, HY + 8, "KEYBIND LIST", C.white, 13, true))
    -- Header separator
    ins(makeRect(HX, HY+28, HW, 1, C.border, true))

    for i, entry in ipairs(entries) do
        local ry = HY + 30 + (i-1) * ROW
        ins(makeRect(HX+4, ry+1, HW-8, ROW-2, C.panel, true))

        local accentCol
        if entry.isBoost then
            accentCol = cfg.boostOn and C.on or C.off
        elseif entry.isTrigger then
            accentCol = cfg.pixelTriggerOn and C.green or C.off
        else
            accentCol = C.cyan
        end
        ins(makeRect(HX+4, ry+1, 3, ROW-2, accentCol, true))

        local labelCol
        if entry.isBoost then
            labelCol = cfg.boostOn and C.on or C.off
        elseif entry.isTrigger then
            labelCol = cfg.pixelTriggerOn and C.green or C.textDim
        else
            labelCol = C.text
        end
        ins(makeTxt(HX+12, ry + math.floor(ROW/2) - 6, entry.label, labelCol, fontSize))

        local badgeW = math.max(32, math.floor(HW * 0.22))
        local badgeX = HX + HW - badgeW - 6
        local badgeCol = entry.isTrigger and (cfg.pixelTriggerOn and C.greenDim or C.accentDim) or C.accentDim
        ins(makeRect(badgeX, ry+3, badgeW, ROW-6, badgeCol, true))
        ins(makeTxt(badgeX + badgeW/2, ry + math.floor(ROW/2) - 6, "["..entry.key.."]", C.accentHi, fontSize, true))
    end

    -- Resize handle (bottom-right corner, same style as main menu)
    ins(makeRect(HX+HW-14, HY+HH-14, 10, 2, C.borderHi, true))
    ins(makeRect(HX+HW-10, HY+HH-10, 6,  2, C.borderHi, true))
end

switchTab = function(idx)
    state.currentTab = idx
    rebuildMenu()
    tabBuilders[idx]()
    buildMacroEditor()
end

local wasMB1 = false
local activeSlider = nil
local activeDelaySlider = nil
local lastKeyTime = 0
local lastRebuildTime = 0

rebuildMenu()
switchTab(1)
buildHotkeyList()

-- ================================================================================
--              MAIN INPUT LOOP
-- ================================================================================
task.spawn(function()
    while true do
        updateMouse()
        
        local mb1 = ismouse1pressed()
        local mb1tap = mb1 and not wasMB1
        wasMB1 = mb1
        
        -- KEY CHECKS (always active)
        -- When editing a numeric field, digits/backspace/enter are reserved for that input
        local numInputKeys = { [0x30]=true,[0x31]=true,[0x32]=true,[0x33]=true,[0x34]=true,
                               [0x35]=true,[0x36]=true,[0x37]=true,[0x38]=true,[0x39]=true,
                               [0x08]=true,[0x0D]=true }
        for vk, name in pairs(VK_NAMES) do
            local isPressed = iskeypressed(vk)
            -- If editing a numeric field, skip key bindings for reserved keys
            -- but still read their state so wasKeys stays accurate after the num block runs
            local skipBinding = state.editingNumField and numInputKeys[vk]
            if isPressed and not wasKeys[vk] and not skipBinding then
                -- Key just pressed - check all bindings
                if vk == cfg.menuKey then
                    state.menuVisible = not state.menuVisible
                    for _, d in pairs(drawings.frame) do d.Visible = state.menuVisible end
                    for _, d in pairs(drawings.content) do d.Visible = state.menuVisible end
                    for _, d in pairs(drawings.editor) do d.Visible = state.menuVisible end
                elseif vk == cfg.boostKey then
                    cfg.boostOn = not cfg.boostOn
                    if state.menuVisible then
                        rebuildMenu()
                        tabBuilders[state.currentTab]()
                    end
                    buildHotkeyList()
                elseif vk == cfg.rxKey then
                    task.spawn(fireRX)
                elseif vk == cfg.f1cKey then
                    task.spawn(fireF1C)
                elseif vk == cfg.dsKey then
                    task.spawn(fireDesync)
                else
                    -- Check custom macros
                    for _, macro in ipairs(cfg.customMacros) do
                        if macro.activationKey == vk then
                            task.spawn(function()
                                fireCustomMacro(macro)
                            end)
                        end
                    end
                end
            end
            -- Don't update wasKeys for reserved keys yet — the editingNumField block below needs the old value
            if not (state.editingNumField and numInputKeys[vk]) then
                wasKeys[vk] = isPressed
            end
        end
        
        -- Skip UI interaction if menu not visible
        if not state.menuVisible then
            task.wait(0.02)
            continue
        end
        
        local MX, MY = state.menuX, state.menuY
        local MW, MH = state.menuW, state.menuH
        
        -- KEYBIND CAPTURE
        if state.bindingTarget then
            if iskeypressed(0x1B) then
                state.bindingTarget = nil
                tabBuilders[state.currentTab]()
            else
                local vk, name = detectKeyboardKey()
                if vk then
                    local t = state.bindingTarget
                    cfg[t.keyKey] = vk
                    cfg[t.nameKey] = name or getKeyName(vk)
                    state.bindingTarget = nil
                    tabBuilders[state.currentTab]()
                    buildHotkeyList()
                end
            end
            
        -- WAITING FOR KEY IN MACRO EDITOR
        elseif state.waitingForKey then
            if iskeypressed(0x1B) then
                state.waitingForKey = false
                buildMacroEditor()
            else
                local now = os.clock()
                if now - lastKeyTime > 0.2 then
                    local vk, name = detectKeyboardKey()
                    if vk then
                        table.insert(state.newMacroKeys, { key = vk, delay = 80 })
                        state.waitingForKey = false
                        lastKeyTime = now
                        buildMacroEditor()
                    end
                end
            end
            
        -- WAITING FOR ACTIVATION KEY
        elseif state.waitingForMacroKey then
            if iskeypressed(0x1B) then
                state.waitingForMacroKey = false
                buildMacroEditor()
            else
                local now = os.clock()
                if now - lastKeyTime > 0.2 then
                    local vk, name = detectKeyboardKey()
                    if vk then
                        state.newMacroActivationKey = vk
                        state.waitingForMacroKey = false
                        lastKeyTime = now
                        buildMacroEditor()
                    end
                end
            end
            
        -- EDITING MACRO NAME
        elseif state.editingName then
            if iskeypressed(0x08) and not wasKeys[0x08] then
                state.newMacroName = string.sub(state.newMacroName, 1, -2)
                buildMacroEditor()
            elseif iskeypressed(0x1B) or iskeypressed(0x0D) then
                state.editingName = false
                buildMacroEditor()
            else
                for vk, char in pairs(VK_CHARS) do
                    if iskeypressed(vk) and not wasKeys[vk] then
                        if #state.newMacroName < 20 then
                            state.newMacroName = state.newMacroName .. char
                            buildMacroEditor()
                        end
                        break
                    end
                end
            end

        -- EDITING NUMERIC FIELD (PX / PY)
        elseif state.editingNumField then
            if iskeypressed(0x08) and not wasKeys[0x08] then
                state.editingNumStr = string.sub(state.editingNumStr, 1, -2)
                switchTab(state.currentTab)
            elseif iskeypressed(0x0D) and not wasKeys[0x0D] then
                local num = tonumber(state.editingNumStr)
                if num then cfg[state.editingNumField] = math.floor(num) end
                state.editingNumField = nil
                state.editingNumStr   = ""
                switchTab(state.currentTab)
            elseif iskeypressed(0x1B) then
                local num = tonumber(state.editingNumStr)
                if num then cfg[state.editingNumField] = math.floor(num) end
                state.editingNumField = nil
                state.editingNumStr   = ""
                switchTab(state.currentTab)
            else
                local digits = {
                    [0x30]="0",[0x31]="1",[0x32]="2",[0x33]="3",[0x34]="4",
                    [0x35]="5",[0x36]="6",[0x37]="7",[0x38]="8",[0x39]="9",
                }
                for vk, char in pairs(digits) do
                    if iskeypressed(vk) and not wasKeys[vk] then
                        if #state.editingNumStr < 5 then
                            state.editingNumStr = state.editingNumStr .. char
                            switchTab(state.currentTab)
                        end
                        break
                    end
                end
            end
            -- Update wasKeys for reserved keys NOW (after this block consumed them)
            for _, vk in ipairs({0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x08,0x0D}) do
                wasKeys[vk] = iskeypressed(vk)
            end
        end
        
        -- DRAGGING MAIN MENU
        if mb1 then
            if state.dragging then
                state.menuX = math.max(0, mouseX - state.dragOffsetX)
                state.menuY = math.max(0, mouseY - state.dragOffsetY)
            elseif state.resizing then
                state.menuW = math.max(state.minW, mouseX - state.menuX + state.resizeOffsetX)
                state.menuH = math.max(state.minH, mouseY - state.menuY + state.resizeOffsetY)
            elseif mb1tap then
                -- Resize handle checked FIRST (priority over drag)
                if inBox(mouseX, mouseY, MX+MW-24, MY+MH-24, 24, 24) then
                    state.resizing = true
                    state.resizeOffsetX = MX + MW - mouseX
                    state.resizeOffsetY = MY + MH - mouseY
                elseif inBox(mouseX, mouseY, MX, MY, MW, 38) then
                    state.dragging = true
                    state.dragOffsetX = mouseX - MX
                    state.dragOffsetY = mouseY - MY
                end
            end
        else
            state.dragging = false
            state.resizing = false
        end
        
        -- DRAGGING + RESIZING MACRO EDITOR
        if state.macroEditorOpen and mb1 then
            local eMX, eMY = state.editorX, state.editorY
            if state.editorResizing then
                state.editorW = math.max(state.editorMinW, mouseX - state.editorX + state.editorResizeOX)
                state.editorH = math.max(state.editorMinH, mouseY - state.editorY + state.editorResizeOY)
            elseif state.editorDragging then
                state.editorX = math.max(0, mouseX - state.editorDragOX)
                state.editorY = math.max(0, mouseY - state.editorDragOY)
            elseif mb1tap then
                if editorBtns.resizeHandle and inBox(mouseX, mouseY, editorBtns.resizeHandle.x, editorBtns.resizeHandle.y, editorBtns.resizeHandle.w, editorBtns.resizeHandle.h) then
                    state.editorResizing = true
                    state.editorResizeOX = state.editorX + state.editorW - mouseX
                    state.editorResizeOY = state.editorY + state.editorH - mouseY
                elseif editorBtns.titleBar and inBox(mouseX, mouseY, editorBtns.titleBar.x, editorBtns.titleBar.y, editorBtns.titleBar.w, editorBtns.titleBar.h) then
                    state.editorDragging = true
                    state.editorDragOX = mouseX - eMX
                    state.editorDragOY = mouseY - eMY
                end
            end
        else
            state.editorDragging = false
            state.editorResizing = false
        end

        -- DRAGGING + RESIZING HOTKEY LIST
        do
            local ROW = math.clamp(math.floor(hkState.w / 10), 18, 26)
            local entryCount = 5 + #cfg.customMacros  -- +1 for Pixel Trigger entry
            local HH = 30 + entryCount * ROW + 6
            local HW = hkState.w
            if mb1 then
                if hkState.resizing then
                    hkState.w = math.max(hkState.minW, mouseX - hkState.x + hkState.resizeOX)
                    buildHotkeyList()
                elseif hkState.dragging then
                    hkState.x = math.max(0, mouseX - hkState.dragOX)
                    hkState.y = math.max(0, mouseY - hkState.dragOY)
                    buildHotkeyList()
                elseif mb1tap then
                    -- Resize handle: bottom-right 20x20
                    if inBox(mouseX, mouseY, hkState.x + HW - 20, hkState.y + HH - 20, 20, 20) then
                        hkState.resizing = true
                        hkState.resizeOX = hkState.x + HW - mouseX
                    -- Drag: header bar
                    elseif inBox(mouseX, mouseY, hkState.x, hkState.y, HW, 30) then
                        hkState.dragging = true
                        hkState.dragOX = mouseX - hkState.x
                        hkState.dragOY = mouseY - hkState.y
                    end
                end
            else
                hkState.dragging = false
                hkState.resizing = false
            end
        end
        
        -- DELAY SLIDER DRAGGING
        if mb1 and activeDelaySlider and editorBtns.delayEditSlider then
            local btn = editorBtns.delayEditSlider
            local rel = math.clamp(mouseX - btn.trackX, 0, btn.trackW)
            local pct = rel / btn.trackW
            local newDelay = math.floor(pct * 500)
            if state.newMacroKeys[btn.idx] then
                state.newMacroKeys[btn.idx].delay = newDelay
            end
            buildMacroEditor()
        elseif not mb1 then
            activeDelaySlider = nil
        end
        
        -- CLICK DETECTION
        if mb1tap then
            -- Cancel numeric field edit only if clicking OUTSIDE a numinput button
            if state.editingNumField then
                local clickedNumInput = false
                for id, obj in pairs(contentDraws.buttons) do
                    if string.sub(id, 1, 8) == "numinput" and inBox(mouseX, mouseY, obj.x, obj.y, obj.w, obj.h) then
                        clickedNumInput = true
                        break
                    end
                end
                if not clickedNumInput then
                    local num = tonumber(state.editingNumStr)
                    if num then cfg[state.editingNumField] = math.floor(num) end
                    state.editingNumField = nil
                    state.editingNumStr   = ""
                    switchTab(state.currentTab)
                end
            end
            -- MACRO EDITOR CLICKS
            if state.macroEditorOpen then
                if editorBtns.close and inBox(mouseX, mouseY, editorBtns.close.x, editorBtns.close.y, editorBtns.close.w, editorBtns.close.h) then
                    closeMacroEditor()
                    tabBuilders[state.currentTab]()
                end
                
                if editorBtns.addKey and inBox(mouseX, mouseY, editorBtns.addKey.x, editorBtns.addKey.y, editorBtns.addKey.w, editorBtns.addKey.h) then
                    state.waitingForKey = true
                    state.waitingForMacroKey = false
                    state.editingName = false
                    lastKeyTime = os.clock()
                    buildMacroEditor()
                end
                
                if editorBtns.actKey and inBox(mouseX, mouseY, editorBtns.actKey.x, editorBtns.actKey.y, editorBtns.actKey.w, editorBtns.actKey.h) then
                    state.waitingForMacroKey = true
                    state.waitingForKey = false
                    state.editingName = false
                    lastKeyTime = os.clock()
                    buildMacroEditor()
                end
                
                if editorBtns.nameInput and inBox(mouseX, mouseY, editorBtns.nameInput.x, editorBtns.nameInput.y, editorBtns.nameInput.w, editorBtns.nameInput.h) then
                    state.editingName = true
                    state.waitingForKey = false
                    state.waitingForMacroKey = false
                    buildMacroEditor()
                end
                
                -- Mode buttons
                if editorBtns.holdBtn and inBox(mouseX, mouseY, editorBtns.holdBtn.x, editorBtns.holdBtn.y, editorBtns.holdBtn.w, editorBtns.holdBtn.h) then
                    state.newMacroMode = "hold"
                    buildMacroEditor()
                end
                
                if editorBtns.toggleBtn and inBox(mouseX, mouseY, editorBtns.toggleBtn.x, editorBtns.toggleBtn.y, editorBtns.toggleBtn.w, editorBtns.toggleBtn.h) then
                    state.newMacroMode = "toggle"
                    buildMacroEditor()
                end
                
                for i, keyData in ipairs(state.newMacroKeys) do
                    local editBtn = editorBtns["editDelay"..i]
                    if editBtn and inBox(mouseX, mouseY, editBtn.x, editBtn.y, editBtn.w, editBtn.h) then
                        state.editingDelayIdx = i
                        buildMacroEditor()
                    end
                    
                    local remBtn = editorBtns["removeKey"..i]
                    if remBtn and inBox(mouseX, mouseY, remBtn.x, remBtn.y, remBtn.w, remBtn.h) then
                        table.remove(state.newMacroKeys, i)
                        if state.editingDelayIdx == i then state.editingDelayIdx = nil end
                        buildMacroEditor()
                    end
                end
                
                if editorBtns.closeDelayEdit and inBox(mouseX, mouseY, editorBtns.closeDelayEdit.x, editorBtns.closeDelayEdit.y, editorBtns.closeDelayEdit.w, editorBtns.closeDelayEdit.h) then
                    state.editingDelayIdx = nil
                    buildMacroEditor()
                end
                
                if editorBtns.delayEditSlider and inBox(mouseX, mouseY, editorBtns.delayEditSlider.x, editorBtns.delayEditSlider.y, editorBtns.delayEditSlider.w, editorBtns.delayEditSlider.h) then
                    activeDelaySlider = editorBtns.delayEditSlider
                end
                
                if editorBtns.save and inBox(mouseX, mouseY, editorBtns.save.x, editorBtns.save.y, editorBtns.save.w, editorBtns.save.h) then
                    if #state.newMacroKeys > 0 and state.newMacroActivationKey then
                        local newMacro = {
                            name = state.newMacroName ~= "" and state.newMacroName or "Macro " .. (#cfg.customMacros + 1),
                            activationKey = state.newMacroActivationKey,
                            mode = state.newMacroMode,
                            keys = {}
                        }
                        for _, k in ipairs(state.newMacroKeys) do
                            table.insert(newMacro.keys, { key = k.key, delay = k.delay })
                        end
                        
                        if state.editingMacro then
                            for i, m in ipairs(cfg.customMacros) do
                                if m == state.editingMacro then
                                    cfg.customMacros[i] = newMacro
                                end
                            end
                        else
                            table.insert(cfg.customMacros, newMacro)
                        end
                        closeMacroEditor()
                        tabBuilders[state.currentTab]()
                        buildHotkeyList()
                        notify("Macro Saved!", "Press ["..getKeyName(newMacro.activationKey).."] to activate", 3)
                    else
                        notify("Error", "Add keys and activation key first", 2)
                    end
                end
                
                if editorBtns.cancel and inBox(mouseX, mouseY, editorBtns.cancel.x, editorBtns.cancel.y, editorBtns.cancel.w, editorBtns.cancel.h) then
                    closeMacroEditor()
                    tabBuilders[state.currentTab]()
                end
            end
            
            -- TAB CLICKS
            local TAB_H = 32
            local tabY0 = MY + 38
            local tabY1 = MY + 38 + TAB_H
            if mouseY >= tabY0 and mouseY <= tabY1 and mouseX >= MX and mouseX <= MX+MW then
                local TABS = {"Boost", "Macros", "Legit", "Settings"}
                local TAB_W = MW / #TABS
                local rel = mouseX - MX
                local idx = math.floor(rel / TAB_W) + 1
                if idx >= 1 and idx <= #TABS then
                    switchTab(idx)
                end
            end
            
            -- TOGGLE CLICKS
            for id, obj in pairs(contentDraws.toggles) do
                if inBox(mouseX, mouseY, obj.x, obj.y, obj.w, obj.h) then
                    cfg[obj.valKey] = not cfg[obj.valKey]
                    rebuildMenu()
                    tabBuilders[state.currentTab]()
                    buildHotkeyList()
                end
            end
            
            -- KEYBIND CLICKS
            for id, obj in pairs(contentDraws.keybinds) do
                if inBox(mouseX, mouseY, obj.x, obj.y, obj.w, obj.h) then
                    state.bindingTarget = obj
                    obj.txt.Text = "[...]"
                    obj.txt.Color = C.yellow
                end
            end
            
            -- BUTTON CLICKS
            for id, obj in pairs(contentDraws.buttons) do
                if inBox(mouseX, mouseY, obj.x, obj.y, obj.w, obj.h) then
                    if obj.callback then obj.callback() end
                end
            end
            
            -- MACRO ITEM CLICKS
            for idx, obj in pairs(contentDraws.macros) do
                if inBox(mouseX, mouseY, obj.x, obj.y, obj.w, obj.h) then
                    if inBox(mouseX, mouseY, obj.delX, obj.y+6, 22, 20) then
                        table.remove(cfg.customMacros, idx)
                        tabBuilders[state.currentTab]()
                        buildHotkeyList()
                    elseif inBox(mouseX, mouseY, obj.editX, obj.y+6, 60, 20) then
                        state.macroEditorOpen = true
                        state.editingMacro = obj.macro
                        state.newMacroName = obj.macro.name
                        state.newMacroKeys = {}
                        state.newMacroMode = obj.macro.mode or "hold"
                        for _, k in ipairs(obj.macro.keys) do
                            table.insert(state.newMacroKeys, { key = k.key, delay = k.delay })
                        end
                        state.newMacroActivationKey = obj.macro.activationKey
                        state.editorX = state.menuX + 40
                        state.editorY = state.menuY + 50
                        state.editingDelayIdx = nil
                        buildMacroEditor()
                    end
                end
            end
            
            -- SLIDER CLICKS
            for id, obj in pairs(contentDraws.sliders) do
                if inBox(mouseX, mouseY, obj.trackX, obj.trackY-4, obj.trackW, 12) then
                    activeSlider = obj
                end
            end
        end
        
        -- SLIDER DRAGGING
        if mb1 and activeSlider then
            local obj = activeSlider
            local rel = math.clamp(mouseX - obj.trackX, 0, obj.trackW)
            local pct = rel / obj.trackW
            local val = math.floor(obj.minV + pct * (obj.maxV - obj.minV))
            cfg[obj.valKey] = val
            obj.valTxt.Text = tostring(val)..(obj.suffix or "")
            local fw = math.max(6, obj.trackW * pct)
            obj.fill.Size = Vector2.new(fw, 6)
            obj.thumb.Position = Vector2.new(obj.trackX + obj.trackW * pct - 5, obj.trackY - 2)
        elseif not mb1 then
            activeSlider = nil
        end
        
        -- Rebuild menu on drag/resize (with throttle)
        local now = os.clock()
        if (state.dragging or state.resizing or state.editorDragging or state.editorResizing) and (now - lastRebuildTime > 0.016) then
            rebuildMenu()
            tabBuilders[state.currentTab]()
            buildMacroEditor()
            lastRebuildTime = now
        end
        
        task.wait(0.006)
    end
end)

notify("EXO HUB", "dc: ktavex_", 3)