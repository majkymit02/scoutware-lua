local MOI_MULTSCRIPT_VERSION = "2.1.0"
local EXPECTED_SIGNATURE = "SCOUTWARE_SIGNATURE_V1"

-- =========================================================
-- SCOUTWARE.WTF - ULTIMATE CS2 SUITE
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
M.VERSION = "2.1"

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

local function drawLogo(x, y, w, h)
    pcall(function()
        if FONT_LOGO then draw.SetFont(FONT_LOGO) end
        draw.Color(T.texthi[1], T.texthi[2], T.texthi[3], rnd(255 * ALPHA))
        draw.Text(rnd(x), rnd(y + 2), T.title)
        local tw = draw.GetTextSize(T.title)
        draw.Color(T.accent[1], T.accent[2], T.accent[3], rnd(255 * ALPHA))
        draw.Text(rnd(x + tw), rnd(y + 2), T.title_tld)
    end)
end

local function rfill(x, y, w, h, r, c, tl, tr, br, bl)
    x, y, w, h = rnd(x), rnd(y), rnd(w), rnd(h)
    r = mmin(r, floor(w / 2), floor(h / 2))
    if r <= 0 then rect(x, y, w, h, c); return end
    if tl == nil then tl, tr, br, bl = true, true, true, true end
    rect(x, y + r, w, h - 2 * r, c)
    for dy = 0, r - 1 do
        local dx = r - floor(sqrt(r * r - (r - dy - 0.5) ^ 2) + 0.5)
        local lt, rt = tl and dx or 0, tr and dx or 0
        local lb, rb = bl and dx or 0, br and dx or 0
        rect(x + lt, y + dy, w - lt - rt, 1, c)
        rect(x + lb, y + h - 1 - dy, w - lb - rb, 1, c)
    end
end

local function rbox(x, y, w, h, r, fill, brd)
    rfill(x, y, w, h, r, brd)
    rfill(x + 1, y + 1, w - 2, h - 2, r - 1, fill)
end

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

local _getMouse = function() local p = input.GetMousePos(); return p.x or p[1], p.y or p[2] end
local _clock = function() return globals.RealTime() end
local function now() local ok, v = pcall(_clock); return ok and v or 0 end
local function readWheel() local ok, v = pcall(input.GetMouseWheel); return ok and v or 0 end

local ms = { x = 0, y = 0, down = false, pressed = false, released = false, consumed = false }
local function updateMouse()
    local ok, x, y = pcall(_getMouse)
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
local IM = {}
UI._x, UI._cy, UI._w = 0, 0, 200
UI.layout = function(x, y, w) UI._x = x; UI._cy = y; if w then UI._w = w end end

local Section = {}
Section.__index = Section
function Section.new(title) return setmetatable({ title = title, ws = {} }, Section) end
function Section:_add(w) self.ws[#self.ws + 1] = w; return handle(w) end

function Section:Checkbox(label, def) return self:_add({ kind = "check", label = label, value = def and true or false }) end
function Section:Button(label, cb) return self:_add({ kind = "button", label = label, cb = cb }) end
function Section:Slider(label, def, mn, mx, step, fmt)
    step = step or 1
    return self:_add({ kind = "slider", label = label, value = def, min = mn, max = mx, step = step, dec = decimalsOf(step), fmt = fmt })
end
function Section:Combo(label, options, def) return self:_add({ kind = "combo", label = label, options = options, value = def or 1 }) end
function Section:Input(label, def, placeholder) return self:_add({ kind = "input", label = label, value = def or "", placeholder = placeholder }) end
function Section:ColorPicker(label, col) col = col or { 255, 255, 255, 255 } return self:_add({ kind = "color", label = label, value = { col[1], col[2], col[3], col[4] or 255 } }) end
function Section:Keybox(label, def) return self:_add({ kind = "keybox", label = label, value = tonumber(def) or 0 }) end
function Section:Listbox(label, items, height, def)
    local fill = (height == "fill")
    if fill then self._hasFill = true end
    return self:_add({ kind = "listbox", label = label, items = items or {}, value = def or 1, h = fill and 120 or (height or 200), fill = fill, scroll = 0 })
end
function Section:Custom(height, fn) return self:_add({ kind = "custom", h = height or 60, fn = fn }) end

function Section:height()
    local h = 42 + 10
    for _, wd in ipairs(self.ws) do h = h + wheight(wd) end
    return h
end

function Section:render(x, y, w)
    local natural = self:height()
    local h = natural
    if self._layoutH then h = mmax(natural, self._layoutH)
    elseif self._hasFill and clipBottom then
        local fh = (clipBottom - 12) - y
        if fh > h then h = fh end
    end
    if clipBottom and y >= clipBottom then return h end
    if clipTop and (y + h) <= clipTop then return h end

    local boxH = h
    if clipBottom and (y + boxH) > clipBottom then boxH = mmax(0, clipBottom - y) end
    if boxH > 0 and (not clipTop or y + boxH > clipTop) then
        local drawY, drawH = y, boxH
        if clipTop and drawY < clipTop then drawH = drawH - (clipTop - drawY); drawY = clipTop end
        if drawH > 0 then
            rbox(x, drawY, w, drawH, 8, T.section, T.border)
            rfill(x + 1, drawY + 1, w - 2, 1, 7, { T.accent[1], T.accent[2], T.accent[3], 70 })
        end
        if (not clipTop or y + 26 > clipTop) and (not clipBottom or y + 12 < clipBottom) then
            rfill(x + 12, y + 10, 3, 14, 1, T.accent)
            text(x + 21, y + 10, T.texthi, self.title, FONT_B)
            rect(x + 12, y + 29, w - 24, 1, T.divider)
        end
    end

    local iy, ix, iw = y + 38, x + 12, w - 24
    for _, wd in ipairs(self.ws) do
        local wh = (wd.kind == "listbox" and wd.fill) and ((wd.label and wd.label ~= "" and 18 or 0) + mmax(wd.h or 120, (y + h - 12) - (iy + ((wd.label and wd.label ~= "") and 18 or 0))) + 6) or wheight(wd)
        if not (clipBottom and iy >= clipBottom) and not (clipTop and (iy + wh) <= clipTop) then
            self:_widget(wd, ix, iy, iw)
        end
        iy = iy + wh
        if clipBottom and iy >= clipBottom then break end
    end
    return h
end

function Section:_widget(wd, x, y, w)
    if wd.kind == "check" then
        local box, by = 15, y + 1
        local hov = hovering(x, by, w, box)
        wd._h = approach(wd._h or 0, hov and 1 or 0, 16)
        wd._on = approach(wd._on or 0, wd.value and 1 or 0, 16)
        local fill = lerpc(lerpc(T.widget, T.widgethi, wd._h), T.accent, wd._on)
        rbox(x, by, box, box, 4, fill, lerpc(T.border, T.accent, wd._on))
        text(x + box + 9, y + 1, lerpc(T.text, T.texthi, mmax(wd._h, wd._on)), wd.label, FONT)
        if clicked(x, by, w, box) then wd.value = not wd.value end
    elseif wd.kind == "button" then
        local bh = 22
        local hov = hovering(x, y + 1, w, bh)
        wd._h = approach(wd._h or 0, hov and 1 or 0, 16)
        rbox(x, y + 1, w, bh, 5, lerpc(T.widget, T.widgethi, wd._h), lerpc(T.border, T.accent, wd._h * 0.6))
        text(x + w / 2, y + 5, lerpc(T.text, T.texthi, wd._h), fitText(wd.label, mmax(20, w - 16), FONT), FONT, "center")
        if clicked(x, y + 1, w, bh) then pcall(wd.cb) end
    elseif wd.kind == "slider" then
        local active = (M._slider == wd)
        wd._h = approach(wd._h or 0, (active or hovering(x, y, w, 24)) and 1 or 0, 16)
        text(x, y, lerpc(T.text, T.texthi, wd._h), wd.label, FONT)
        local valstr = wd.fmt and string.format(wd.fmt, wd.value) or (wd.dec > 0 and string.format("%." .. wd.dec .. "f", wd.value) or tostring(rnd(wd.value)))
        text(x + w, y, T.texthi, valstr, FONT, "right")
        local ty, th = y + 18, 5
        local frac = clamp((wd.value - wd.min) / (wd.max - wd.min), 0, 1)
        rbox(x, ty, w, th, 2, lerpc(T.widget, T.widgethi, wd._h), T.border)
        if frac > 0 then rfill(x, ty, mmax(th, w * frac), th, 2, T.accent, true, false, false, true) end
        if ms.pressed and not ms.consumed and hovering(x, ty - 6, w, th + 12) then ms.consumed = true; M._slider = wd end
        if active then
            if ms.down and w > 0 then
                local raw = wd.min + clamp((ms.x - x) / w, 0, 1) * (wd.max - wd.min)
                local v = clamp(wd.min + floor((raw - wd.min) / wd.step + 0.5) * wd.step, wd.min, wd.max)
                if wd.dec > 0 then v = tonumber(string.format("%." .. wd.dec .. "f", v)) or v end
                wd.value = v
            elseif not ms.down then M._slider = nil end
        end
    end
end

return M
]===]
