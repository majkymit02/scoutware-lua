local MOI_MULTSCRIPT_VERSION = "2.3.0"
local EXPECTED_SIGNATURE = "SCOUTWARE_SIGNATURE_V1"

-- =========================================================
-- SCOUTWARE.WTF - ULTIMATE CS2 SUITE (MAIN)
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
M.VERSION = "2.3"

-- SCOUTWARE / FATALITY DESIGN THEME
local T = {
    x = 360, y = 200, w = 720, h = 500,

    accent      = { 193, 31, 105 },  -- Scoutware Pink / Magenta
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

    title       = "SCOUT",
    title_tld   = "WARE.WTF",
    titlebar    = 46,
    pad         = 16,

    font        = { "Segoe UI", "Tahoma" },
    font_size   = 14,
}

local floor, mmin, mmax = math.floor, math.min, math.max
local function rnd(n) return floor(n + 0.5) end
local function setcol(c) draw.Color(c[1], c[2], c[3], c[4] or 255) end
local function textw(s) local w = draw.GetTextSize(s); return w or 0 end

local function text(x, y, c, s, font, align)
    if font then draw.SetFont(font) end
    if align == "center" then x = x - textw(s) / 2
    elseif align == "right" then x = x - textw(s) end
    setcol(c); draw.Text(rnd(x), rnd(y), s)
end

local FONT, FONT_B
local function initFonts()
    pcall(function()
        FONT = draw.CreateFont("Segoe UI", 14, 400)
        FONT_B = draw.CreateFont("Segoe UI Semibold", 14, 700)
    end)
    if not FONT then FONT = 0 end
    if not FONT_B then FONT_B = 0 end
end

local active_tab = 1
local tabs_list = { "Sounds", "Visuals", "Settings" }

M._tabs = {}
function M:Tab(name)
    local t = { name = name }
    self._tabs[#self._tabs + 1] = t
    return t
end

function M:Build(opts)
    initFonts()
    callbacks.Register("Draw", "Scoutware_MainDraw", function()
        local open = true
        pcall(function() local m = gui.Reference("MENU") if m then open = m:IsActive() end end)
        if not open then return end

        local wx, wy, ww, wh = T.x, T.y, T.w, T.h

        -- Hlavní okno (Scoutware/Fatality styl)
        setcol(T.bg)
        draw.FilledRect(wx, wy, wx + ww, wy + wh)
        setcol(T.border)
        draw.OutlinedRect(wx, wy, wx + ww, wy + wh)

        -- Horní lišta
        setcol(T.bg2)
        draw.FilledRect(wx, wy, wx + ww, wy + T.titlebar)
        setcol(T.border)
        draw.Line(wx, wy + T.titlebar, wx + ww, wy + T.titlebar)

        -- Logo / Název
        if FONT_B then draw.SetFont(FONT_B) end
        setcol(T.texthi)
        draw.Text(wx + 15, wy + 14, T.title)
        setcol(T.accent)
        draw.Text(wx + 15 + textw(T.title), wy + 14, T.title_tld)

        -- Záložky (Tabs)
        local tab_w, tab_h = 100, 26
        local start_x = wx + 160
        local mx, my = input.GetMousePos()
        local clicked_mouse = input.IsButtonDown(0x01)

        for i, tname in ipairs(tabs_list) do
            local tx = start_x + (i - 1) * (tab_w + 8)
            local ty = wy + 10
            local hovered = mx >= tx and mx <= tx + tab_w and my >= ty and my <= ty + tab_h

            if hovered and clicked_mouse then
                active_tab = i
            end

            if active_tab == i then
                setcol(T.accent_bg)
                draw.FilledRect(tx, ty, tx + tab_w, ty + tab_h)
                setcol(T.accent)
                draw.OutlinedRect(tx, ty, tx + tab_w, ty + tab_h)
                setcol(T.texthi)
            else
                setcol(T.widget)
                draw.FilledRect(tx, ty, tx + tab_w, ty + tab_h)
                setcol(T.border)
                draw.OutlinedRect(tx, ty, tx + tab_w, ty + tab_h)
                setcol(T.textdim)
            end
            if FONT then draw.SetFont(FONT) end
            text(tx + tab_w / 2, ty + 5, nil, tname, FONT, "center")
        end

        -- Obsahová plocha
        local cx, cy, cw, ch = wx + 14, wy + T.titlebar + 14, ww - 28, wh - T.titlebar - 28
        setcol(T.section)
        draw.FilledRect(cx, cy, cx + cw, cy + ch)
        setcol(T.border)
        draw.OutlinedRect(cx, cy, cx + cw, cy + ch)

        -- Vykreslení obsahu podle aktivní záložky
        if FONT then draw.SetFont(FONT) end
        if active_tab == 1 then
            text(cx + 20, cy + 20, T.texthi, "Custom Hit & Kill Sounds")
            text(cx + 20, cy + 50, T.textdim, "Zde budou nastavení zvuků ze složky sounds/")
        elseif active_tab == 2 then
            text(cx + 20, cy + 20, T.texthi, "Visuals & Watermark")
            text(cx + 20, cy + 50, T.textdim, "Zde budou nastavení pro watermark a overlay.")
        elseif active_tab == 3 then
            text(cx + 20, cy + 20, T.texthi, "Configs & Settings")
            text(cx + 20, cy + 50, T.textdim, "Zde bude správa konfigurací.")
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

M:Build({ w = 720, h = 500 })
print("[Scoutware] UI Suite loaded cleanly!")
