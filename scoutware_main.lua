local MOI_MULTSCRIPT_VERSION = "1.0.0"
local EXPECTED_SIGNATURE = "SCOUTWARE_SIGNATURE_V1"

-- =========================================================
-- SCOUTWARE.WTF - AIMWARE CS2 LUA SCRIPT (MAIN)
-- AUTHOR: Majkymit
-- =========================================================

local is_menu_open = true
local current_tab = 2

local ui_enable_wm = true
local ui_enable_hitsound = true
local ui_hitsound_index = 1
local ui_enable_killsound = true
local ui_killsound_index = 2

local loaded_sounds = {}

-- Automatické načtení souborů ze složky sounds/
local sound_files = {}
local sound_names = {"[ Žádné soubory ]"}

local function ScanSoundsFolder()
    local found_files = {}
    pcall(function()
        -- Použijeme Aimware souborový systém / FFI k nalezení .vsnd_c souborů v "sounds/"
        -- Pokud ffi/find funguje, naplníme tabulku
        local handle = file.FindFirst and file.FindFirst("sounds/*.vsnd_c") or nil
        -- Alternativně zkusíme bezpečný průzkum složky, pokud je dostupný
    end)
    
    -- Pro jistotu, pokud by nativní skenování přes Aimware v téhle verzi zlobilo,
    -- definujeme si základní detekci, ale zkusíme to načíst z disku.
    -- V Aimwaru se na to nejčastěji používá standardní průzkum, nebo si sem 
    -- můžeš vypsat seznam z tvojí složky.
end

-- Bezpečný fallback na načtení dynamického seznamu z Aimwaru
local function GetSoundFiles()
    local list = {}
    pcall(function()
        -- Zkusíme vyhledat soubory ve složce sounds/
        local files = file.Find and file.Find("sounds/*.vsnd_c") or {}
        for _, f in ipairs(files) do
            if f:lower():sub(-7) == ".vsnd_c" then
                table.insert(list, f)
            end
        end
    end)
    if #list == 0 then
        -- Pokud by to přes file.Find v téhle verzi neprošlo, dáme sem hlášku
        list = {"hitsound.vsnd_c", "killsound.vsnd_c"}
    end
    return list
end

sound_files = GetSoundFiles()

local win_x, win_y = 100, 150
local window_width, window_height = 480, 420
local is_dragging = false
local drag_offset_x, drag_offset_y = 0, 0
local key_toggle_down = false
local mouse_click_down = false

local function DrawRoundedRect(x, y, w, h, r, r_col, g_col, b_col, a_col)
    draw.Color(r_col, g_col, b_col, a_col)
    draw.FilledRect(x + r, y, x + w - r, y + h)
    draw.FilledRect(x, y + r, x + w, y + h - r)
    local steps = 12
    for i = 0, steps do
        local a1 = (i / steps) * (math.pi / 2)
        local cosx = math.cos(a1) * r
        local sinx = math.sin(a1) * r
        draw.FilledRect(x + r - cosx, y + r - sinx, x + r, y + r)
        draw.FilledRect(x + w - r + cosx, y + r - sinx, x + w - r, y + r)
        draw.FilledRect(x + r - cosx, y + h - r + sinx, x + r, y + h)
        draw.FilledRect(x + w - r + cosx, y + h - r + sinx, x + w - r, y + h)
    end
end

local function DrawRoundedOutline(x, y, w, h, r, r_col, g_col, b_col, a_col)
    draw.Color(r_col, g_col, b_col, a_col)
    draw.Line(x + r, y, x + w - r, y)
    draw.Line(x + r, y + h, x + w - r, y + h)
    draw.Line(x, y + r, x, y + h - r)
    draw.Line(x + w, y + r, x + w, y + h - r)
    local steps = 12
    local last_cx1, last_cy1, last_cx2, last_cy2, last_cx3, last_cy3, last_cx4, last_cy4
    for i = 0, steps do
        local a = (i / steps) * (math.pi / 2)
        local cosx = math.cos(a) * r
        local sinx = math.sin(a) * r
        local cx1, cy1 = x + r - cosx, y + r - sinx
        local cx2, cy2 = x + w - r + cosx, y + r - sinx
        local cx3, cy3 = x + r - cosx, y + h - r + sinx
        local cx4, cy4 = x + w - r + cosx, y + h - r + sinx
        if i > 0 then
            draw.Line(last_cx1, last_cy1, cx1, cy1)
            draw.Line(last_cx2, last_cy2, cx2, cy2)
            draw.Line(last_cx3, last_cy3, cx3, cy3)
            draw.Line(last_cx4, last_cy4, cx4, cy4)
        end
        last_cx1, last_cy1 = cx1, cy1
        last_cx2, last_cy2 = cx2, cy2
        last_cx3, last_cy3 = cx3, cy3
        last_cx4, last_cy4 = cx4, cy4
    end
end

local function PlayCustomVsnd(filename)
    if not filename then return end
    local path = "sounds/" .. filename

    if sounds and sounds.Create then
        if not loaded_sounds[filename] then
            loaded_sounds[filename] = sounds.Create(path)
        end
        if loaded_sounds[filename] and loaded_sounds[filename].Play then
            loaded_sounds[filename]:Play()
            return
        end
    end
    if engine and engine.PlaySound then engine.PlaySound(path); return end
    if client and client.PlaySound then client.PlaySound(path); return end
end

callbacks.Register("FireGameEvent", function(event)
    if not event then return end
    local local_player = entities.GetLocalPlayer()
    if not local_player then return end
    local local_idx = client.GetLocalPlayerIndex()

    if event:GetName() == "player_hurt" and ui_enable_hitsound then
        local attacker = event:GetInt("attacker")
        local victim = event:GetInt("userid")
        if (attacker == local_idx or attacker == (local_idx - 1)) and victim ~= attacker then
            local file_to_play = sound_files[ui_hitsound_index] or sound_files[1]
            PlayCustomVsnd(file_to_play)
        end
    elseif event:GetName() == "player_death" and ui_enable_killsound then
        local attacker = event:GetInt("attacker")
        local victim = event:GetInt("userid")
        if (attacker == local_idx or attacker == (local_idx - 1)) and victim ~= attacker then
            local file_to_play = sound_files[ui_killsound_index] or sound_files[1]
            PlayCustomVsnd(file_to_play)
        end
    end
end)

callbacks.Register("Draw", function()
    local sw, sh = draw.GetScreenSize()
    if not sw or not sh then return end

    local is_insert_down = input.IsButtonDown(45)
    if is_insert_down and not key_toggle_down then
        is_menu_open = not is_menu_open
        key_toggle_down = true
    elseif not is_insert_down then
        key_toggle_down = false
    end

    if is_menu_open then
        local mx, my = input.GetMousePos()
        local is_mouse_down = input.IsButtonDown(1)
        local is_single_click = false
        if is_mouse_down and not mouse_click_down then
            is_single_click = true
            mouse_click_down = true
        elseif not is_mouse_down then
            mouse_click_down = false
        end

        if is_mouse_down then
            if not is_dragging then
                if mx >= win_x and mx <= (win_x + window_width) and my >= win_y and my <= (win_y + 45) then
                    is_dragging = true
                    drag_offset_x = mx - win_x
                    drag_offset_y = my - win_y
                end
            elseif is_dragging then
                win_x = mx - drag_offset_x
                win_y = my - drag_offset_y
            end
        else
            is_dragging = false
        end

        DrawRoundedRect(win_x, win_y, window_width, window_height, 10, 26, 21, 36, 245)
        DrawRoundedOutline(win_x, win_y, window_width, window_height, 10, 193, 31, 105, 255)

        draw.Color(255, 255, 255, 255)
        draw.Text(win_x + 20, win_y + 16, "SCOUTWARE CFG BY Majkymit")

        local tabs = {"Visuals", "Sounds", "Misc"}
        local tab_width = 130
        local tab_height = 28
        local start_tab_x = win_x + 20
        local start_tab_y = win_y + 44

        for i, tab_name in ipairs(tabs) do
            local tx = start_tab_x + (i - 1) * (tab_width + 10)
            local ty = start_tab_y
            
            local is_tab_hovered = mx >= tx and mx <= (tx + tab_width) and my >= ty and my <= (ty + tab_height)
            if is_tab_hovered and is_single_click then
                current_tab = i
            end

            if current_tab == i then
                DrawRoundedRect(tx, ty, tab_width, tab_height, 6, 36, 30, 50, 255)
                DrawRoundedOutline(tx, ty, tab_width, tab_height, 6, 193, 31, 105, 255)
                draw.Color(255, 255, 255, 255)
            else
                if is_tab_hovered then
                    DrawRoundedRect(tx, ty, tab_width, tab_height, 6, 255, 255, 255, 8)
                else
                    DrawRoundedRect(tx, ty, tab_width, tab_height, 6, 20, 17, 28, 200)
                end
                DrawRoundedOutline(tx, ty, tab_width, tab_height, 6, 255, 255, 255, 15)
                draw.Color(160, 155, 175, 255)
            end
            
            local tw, _ = draw.GetTextSize(tab_name)
            draw.Text(tx + math.floor((tab_width - tw) / 2), ty + 7, tab_name)
        end

        local content_x = win_x + 20
        local content_y = win_y + 84
        local area_w = window_width - 40
        local area_h = window_height - 104

        DrawRoundedRect(content_x, content_y, area_w, area_h, 8, 18, 14, 26, 255)
        DrawRoundedOutline(content_x, content_y, area_w, area_h, 8, 255, 255, 255, 8)

        local inner_x = content_x + 16
        local inner_y = content_y + 16
        local sw_w, sw_h = 40, 20

        -- TAB 1: VISUALS
        if current_tab == 1 then
            draw.Color(200, 195, 215, 255)
            draw.Text(inner_x, inner_y + 2, "Visual module under maintenance")

        -- TAB 2: SOUNDS
        elseif current_tab == 2 then
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, inner_y + 2, "Hit Sound")
            
            local sw_hit_x = content_x + area_w - sw_w - 24
            if mx >= sw_hit_x and mx <= (sw_hit_x + sw_w) and my >= inner_y and my <= (inner_y + sw_h) and is_single_click then
                ui_enable_hitsound = not ui_enable_hitsound
            end

            if ui_enable_hitsound then
                DrawRoundedRect(sw_hit_x, inner_y, sw_w, sw_h, 5, 193, 31, 105, 255)
                DrawRoundedRect(sw_hit_x + sw_w - 18, inner_y + 2, 16, 16, 4, 255, 255, 255, 255)
            else
                DrawRoundedRect(sw_hit_x, inner_y, sw_w, sw_h, 5, 36, 30, 50, 255)
                DrawRoundedOutline(sw_hit_x, inner_y, sw_w, sw_h, 5, 255, 255, 255, 15)
                DrawRoundedRect(sw_hit_x + 2, inner_y + 2, 16, 16, 4, 110, 105, 125, 255)
            end

            -- HIT SOUND FILE SELECTOR
            local row_hs_y = inner_y + 32
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x, row_hs_y + 2, "Hit Sound File:")
            
            local hs_btn_x = content_x + area_w - 168
            local current_hit_name = sound_files[ui_hitsound_index] or "Žádný"
            if mx >= hs_btn_x and mx <= (hs_btn_x + 140) and my >= row_hs_y and my <= (row_hs_y + 22) and is_single_click then
                ui_hitsound_index = (ui_hitsound_index % #sound_files) + 1
            end
            DrawRoundedRect(hs_btn_x, row_hs_y, 140, 22, 6, 36, 30, 50, 255)
            DrawRoundedOutline(hs_btn_x, row_hs_y, 140, 22, 6, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            local hstw, _ = draw.GetTextSize(current_hit_name)
            draw.Text(hs_btn_x + math.floor((140 - hstw) / 2), row_hs_y + 4, current_hit_name)

            -- TEST HIT BUTTON
            local test_hit_y = inner_y + 60
            local test_btn_w = 110
            if mx >= inner_x and mx <= (inner_x + test_btn_w) and my >= test_hit_y and my <= (test_hit_y + 20) and is_single_click then
                PlayCustomVsnd(sound_files[ui_hitsound_index])
            end
            DrawRoundedRect(inner_x, test_hit_y, test_btn_w, 20, 5, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            local tht_w, _ = draw.GetTextSize("TEST HIT")
            draw.Text(inner_x + math.floor((test_btn_w - tht_w) / 2), test_hit_y + 3, "TEST HIT")

            -- KILL SOUND TOGGLE
            local row_ks_start = inner_y + 95
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, row_ks_start + 2, "Kill Sound")

            if mx >= sw_hit_x and mx <= (sw_hit_x + sw_w) and my >= row_ks_start and my <= (row_ks_start + sw_h) and is_single_click then
                ui_enable_killsound = not ui_enable_killsound
            end

            if ui_enable_killsound then
                DrawRoundedRect(sw_hit_x, row_ks_start, sw_w, sw_h, 5, 193, 31, 105, 255)
                DrawRoundedRect(sw_hit_x + sw_w - 18, row_ks_start + 2, 16, 16, 4, 255, 255, 255, 255)
            else
                DrawRoundedRect(sw_hit_x, row_ks_start, sw_w, sw_h, 5, 36, 30, 50, 255)
                DrawRoundedOutline(sw_hit_x, row_ks_start, sw_w, sw_h, 5, 255, 255, 255, 15)
                DrawRoundedRect(sw_hit_x + 2, row_ks_start + 2, 16, 16, 4, 110, 105, 125, 255)
            end

            -- KILL SOUND FILE SELECTOR
            local row_ks_y = row_ks_start + 32
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x, row_ks_y + 2, "Kill Sound File:")

            local current_kill_name = sound_files[ui_killsound_index] or "Žádný"
            if mx >= hs_btn_x and mx <= (hs_btn_x + 140) and my >= row_ks_y and my <= (row_ks_y + 22) and is_single_click then
                ui_killsound_index = (ui_killsound_index % #sound_files) + 1
            end
            DrawRoundedRect(hs_btn_x, row_ks_y, 140, 22, 6, 36, 30, 50, 255)
            DrawRoundedOutline(hs_btn_x, row_ks_y, 140, 22, 6, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            local kstw, _ = draw.GetTextSize(current_kill_name)
            draw.Text(hs_btn_x + math.floor((140 - kstw) / 2), row_ks_y + 4, current_kill_name)

            -- TEST KILL BUTTON
            local test_kill_y = row_ks_start + 60
            if mx >= inner_x and mx <= (inner_x + test_btn_w) and my >= test_kill_y and my <= (test_kill_y + 20) and is_single_click then
                PlayCustomVsnd(sound_files[ui_killsound_index])
            end
            DrawRoundedRect(inner_x, test_kill_y, test_btn_w, 20, 5, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            local tkt_w, _ = draw.GetTextSize("TEST KILL")
            draw.Text(inner_x + math.floor((test_btn_w - tkt_w) / 2), test_kill_y + 3, "TEST KILL")
        
        -- TAB 3: MISC
        elseif current_tab == 3 then
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, inner_y + 2, "Watermark Overlay")
            
            local sw_wm_x = content_x + area_w - sw_w - 24
            if mx >= sw_wm_x and mx <= (sw_wm_x + sw_w) and my >= inner_y and my <= (inner_y + sw_h) and is_single_click then
                ui_enable_wm = not ui_enable_wm
            end
            if ui_enable_wm then
                DrawRoundedRect(sw_wm_x, inner_y, sw_w, sw_h, 5, 193, 31, 105, 255)
                DrawRoundedRect(sw_wm_x + sw_w - 18, inner_y + 2, 16, 16, 4, 255, 255, 255, 255)
            else
                DrawRoundedRect(sw_wm_x, inner_y, sw_w, sw_h, 5, 36, 30, 50, 255)
                DrawRoundedOutline(sw_wm_x, inner_y, sw_w, sw_h, 5, 255, 255, 255, 15)
                DrawRoundedRect(sw_wm_x + 2, inner_y + 2, 16, 16, 4, 110, 105, 125, 255)
            end
        end
    end

    if ui_enable_wm then
        local fps = math.floor(1 / globals.AbsoluteFrameTime())
        local wm_title = "Scoutware.wtf (beta)"
        local wm_fps = " | FPS: " .. fps
        local tw1, _ = draw.GetTextSize(wm_title)
        local tw2, _ = draw.GetTextSize(wm_fps)
        local wm_w = tw1 + tw2 + 28
        local wm_h = 34
        local wm_x = sw - wm_w - 16
        local wm_y = 16

        DrawRoundedRect(wm_x, wm_y, wm_w, wm_h, 6, 26, 21, 36, 220)
        DrawRoundedOutline(wm_x, wm_y, wm_w, wm_h, 6, 193, 31, 105, 255)
        draw.Color(255, 255, 255, 255)
        draw.Text(wm_x + 14, wm_y + 11, wm_title)
        draw.Color(193, 31, 105, 255)
        draw.Text(wm_x + 14 + tw1, wm_y + 11, wm_fps)
    end
end)
