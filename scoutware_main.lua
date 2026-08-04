local MOI_MULTSCRIPT_VERSION = "2.2.0"
local EXPECTED_SIGNATURE = "SCOUTWARE_SIGNATURE_V1"

-- =========================================================
-- SCOUTWARE.WTF - ULTIMATE CS2 SUITE (MAIN SCRIPT)
-- AUTHOR: Majkymit
-- =========================================================

local staleEvents = { "Draw", "CreateMove", "PreMove", "DrawESP", "FireGameEvent", "Unload" }
local function clearCallbacks(ids)
    for _, id in ipairs(ids) do
        for _, event in ipairs(staleEvents) do
            pcall(callbacks.Unregister, event, id)
        end
    end
end

clearCallbacks({
    "MOIMultitool_Watermark", "MOIMultitool_MISCLogic",
    "MOIMultitool_MISCLogicMove", "MOIMultitool_MISCEvents",
    "MOIMultitool_WeaponsSessionEvents", "MOIMultitool_GameEvents",
    "MOIMultitool_GameEventsUnload", "MOIMultitool_MISCUnload"
})

local __MOI_GUILIB = [===[
local M = {}
M.VERSION = "2.2"

-- SCOUTWARE DESIGN THEME
local T = {
    x = 360, y = 200, w = 680, h = 480,

    accent      = { 193, 31, 105 },  -- Scoutware Pink/Magenta
    accent2     = { 225, 45, 125, 255 },
    accent_bg   = { 45, 22, 40, 255 },
    bg          = { 18, 14, 26, 252 },
    bg2         = { 22, 18, 32, 252 },
    section     = { 26, 21, 36, 252 },
    border      = { 65, 45, 75, 255 },
    divider     = { 45, 32, 55, 255 },
    text        = { 215, 210, 225, 255 },
    textdim     = { 130, 120, 145, 255 },
    texthi      = { 255, 255, 255, 255 },
    widget      = { 32, 26, 46, 255 },
    widgethi    = { 42, 34, 60, 255 },
    shadow      = { 0, 0, 0, 150 },

    title       = "SCOUTWARE",
    title_tld   = ".WTF",
    titlebar    = 52,
    pad         = 18,
    sec_gap     = 16,

    font        = { "Segoe UI", "Bahnschrift", "Tahoma" },
    font_logo   = { "Bahnschrift", "Segoe UI Semibold", "Segoe UI" },
    font_size   = 14,

    notif_pos   = "bottom-right",
    notif_w     = 290,
    notif_margin = 18,
    notif_life  = 3.5,
}

local WH = { check = 28, button = 36, slider = 36, combo = 52, multicombo = 52, input = 52, color = 28, keybox = 52 }
local function wheight(wd)
    if wd.kind == "listbox" then
        return ((wd.label and wd.label ~= "") and 18 or 0) + wd.h + 6
    end
    if wd.kind == "custom" then return wd._measured or wd.h end
    return WH[wd.kind] or 28
end

local ANIM = { open = 13, tab = 17 }

local floor, sqrt, mmin, mmax, mabs = math.floor, math.sqrt, math.min, math.max, math.abs
local function rnd(n) return floor(n + 0.5) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function smooth(t) t = clamp(t, 0, 1); return t * t * (3 - 2 * t) end

local function decimalsOf(step)
    if not step or step >= 1 then return 0 end
    local d, s = 0, step
    while s < 1 and d < 6 do
        s = s * 10; d = d + 1
        if mabs(s - floor(s + 0.5)) < 1e-7 then break end
    end
    return d
end

local ALPHA = 1
local DT = 0
local clipTop, clipBottom

local function approach(cur, target, speed)
    return cur + (target - cur) * clamp(DT * speed, 0, 1)
end

local function lerpc(a, b, t)
    t = clamp(t, 0, 1)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        (a[4] or 255) + ((b[4] or 255) - (a[4] or 255)) * t,
    }
end

local ffi = ffi
local FONT, FONT_B, FONT_LOGO
local function initFonts()
    local mk = function(list, size, weight)
        for _, name in ipairs(list) do
            local f
            pcall(function() f = draw.CreateFont(name, size, weight) end)
            if not f then pcall(function() f = draw.AddFont(name, size, weight) end) end
            if f then return f, name end
        end
    end
    FONT        = mk(T.font, T.font_size, 400)
    FONT_B      = mk(T.font, T.font_size, 600)
    FONT_LOGO   = mk(T.font_logo, T.font_size + 3, 700) or FONT_B
end

local function setcol(c) draw.Color(c[1], c[2], c[3], rnd((c[4] or 255) * ALPHA)) end
local function rect(x, y, w, h, c) setcol(c); draw.FilledRect(rnd(x), rnd(y), rnd(x + w), rnd(y + h)) end

local function textw(s) local w = draw.GetTextSize(s); return w or 0 end
local function fitText(s, maxWidth, font)
    s = tostring(s or "")
    if font then pcall(function() draw.SetFont(font) end) end
    if textw(s) <= maxWidth then return s end
    local suffix = "..."
    local available = mmax(0, maxWidth - textw(suffix))
    local lo, hi, best = 0, #s, 0
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        if textw(s:sub(1, mid)) <= available then best = mid; lo = mid + 1
        else hi = mid - 1 end
    end
    return s:sub(1, best) .. suffix
end

local function text(x, y, c, s, font, align)
    if font then draw.SetFont(font) end
    if align == "center" then x = x - textw(s) / 2
    elseif align == "right" then x = x - textw(s) end
    setcol(c); draw.Text(rnd(x), rnd(y), s)
end

local _getMouse = resolveMouse or function() local p = input.GetMousePos(); return p.x or p[1], p.y or p[2] end
local _clock = resolveClock or function() return globals.RealTime() end
local function now() local ok, v = pcall(_clock); return ok and v or 0 end
local function readWheel() local ok, v = pcall(readWheel or input.GetMouseWheel); return ok and v or 0 end

local ms = { x = 0, y = 0, down = false, pressed = false, released = false, consumed = false }
local function updateMouse()
    local ok, x, y = pcall(function() local p = input.GetMousePos(); return p.x or p[1], p.y or p[2] end)
    if ok and x and y then ms.x, ms.y = x, y end
    local down = false
    pcall(function() down = input.IsButtonDown(0x01) end)
    ms.pressed = down and not ms.down
    ms.released = (not down) and ms.down
    ms.down = down
    ms.consumed = false
    ms.wheel = readWheel()
end

local function hovering(x, y, w, h) return ms.x >= x and ms.x <= x + w and ms.y >= y and ms.y <= y + h end
local function clicked(x, y, w, h)
    if ms.consumed or not ms.pressed then return false end
    if hovering(x, y, w, h) then ms.consumed = true; return true end
    return false
end

local function handle(w)
    return {
        Get = function() return w.value end,
        Set = function(_, v) w.value = v end,
    }
end

local UI = { T = T, now = now, clamp = clamp, lerp = lerpc }
local Tab = {}
Tab.__index = Tab
function Tab.new(name) return setmetatable({ name = name, secs = {}, subs = {}, _rows = {}, _activeSub = 1, _subT = 1 }, Tab) end

M._tabs = {}
M._active = 1
M._win = { x = T.x, y = T.y, w = T.w, h = T.h }
M._minimized = false
M._t = 0
M._tabT = 1
M._toasts = {}

function M:Tab(name)
    local t = Tab.new(name)
    self._tabs[#self._tabs + 1] = t
    return t
end

function M:Build(opts)
    opts = opts or {}
    if opts.w then self._win.w = opts.w end
    if opts.h then self._win.h = opts.h end
    initFonts()
    callbacks.Register("Draw", "Scoutware_MainUIDraw", function()
        updateMouse()
        local open = true
        pcall(function() local m = gui.Reference("MENU") if m then open = m:IsActive() end end)
        if open then
            draw.Color(T.bg[1], T.bg[2], T.bg[3], T.bg[4] or 252)
            draw.FilledRect(M._win.x, M._win.y, M._win.x + M._win.w, M._win.y + M._win.h)
            draw.Color(T.accent[1], T.accent[2], T.accent[3], 255)
            draw.OutlinedRect(M._win.x, M._win.y, M._win.x + M._win.w, M._win.y + M._win.h)
            text(M._win.x + 18, M._win.y + 14, T.texthi, T.title .. T.title_tld, FONT_B)
        end
    end)
    return self
end

return M
]===]

local __chunk, __err = loadstring(__MOI_GUILIB, "=scoutware_guilib.lua")
if not __chunk then print("[Scoutware] UI compile error: " .. tostring(__err)); return end
local __ok, M = pcall(__chunk)
if not __ok or type(M) ~= "table" then print("[Scoutware] UI load error: " .. tostring(M)); return end

local function loadModule(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        print("[Scoutware] " .. name .. " error: " .. tostring(err))
        return false
    end
    return true
end

-- Inicializace základní tabulky a testovacího menu
M:Tab("CONFIGS")
M:Tab("WEAPONS")
M:Tab("CUSTOM SOUNDS")

M:Build({ w = 900, h = 540 })
print("[Scoutware] Suite successfully loaded with clean UI!")
