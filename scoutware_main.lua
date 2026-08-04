local MOI_MULTSCRIPT_VERSION = "1.0.0"
local EXPECTED_SIGNATURE = "SCOUTWARE_SIGNATURE_V1"

-- =========================================================
-- SCOUTWARE.WTF - AIMWARE CS2 LUA SCRIPT (MAIN)
-- AUTHOR: Majkymit
-- =========================================================

-- UI State Variables
local is_menu_open = true
local current_tab = 2 -- Default to Sounds tab

-- Config Variables
local ui_enable_wm = true

-- Visuals Config (Locked in UI)
local ui_scope_overlay_type = 1
local ui_scope_glow = true
local ui_enable_indicators = true
local ui_enable_hitmarker = true
local ui_enable_speclist = true

-- Sounds Config (SEPARATE HIT & KILL)
local ui_enable_hitsound = true
local ui_hitsound_index = 1

local ui_enable_killsound = true
local ui_killsound_index = 2

-- Sound files from game/csgo/sounds/scoutware/
local sound_files = {"hitsound.vsnd_c", "killsound.vsnd_c"}

-- Pre-loaded sound objects cache
local loaded_sounds = {}

-- Window Positioning & State
local win_x, win_y = 100, 150
local window_width, window_height = 480, 420
local is_dragging = false
local drag_offset_x, drag_offset_y = 0, 0
local key_toggle_down = false
local mouse_click_down = false

-- =========================================================
-- DRAWING HELPERS
-- =========================================================

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
    local last_cx1, last_cy1, last_cx2, last_cy2
    local last_cx3, last_cy3, last_cx4, last_cy4
    
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

-- =========================================================
-- ADVANCED AIMWARE SOUND PLAYBACK
-- =========================================================

local function PlayCustomVsnd(filename)
    if not filename then return end

    local path = "sounds/scoutware/" .. filename

    -- Method 1: Aimware sounds object API
    if sounds and sounds.Create then
        if not loaded_sounds[filename] then
            loaded_sounds[filename] = sounds.Create(path)
        end
        
        if loaded_sounds[filename] and loaded_sounds[filename].Play then
            loaded_sounds[filename]:Play()
            return
        end
    end

    -- Method 2: Engine Direct Sound Playback
    if engine and engine.PlaySound then
        engine.PlaySound(path)
        return
    end

    -- Method 3: Surface / Client Direct Play
    if client and client.PlaySound then
        client.PlaySound(path)
        return
    end
end

-- =========================================================
-- GAME EVENT HANDLERS
-- =========================================================

callbacks.Register("FireGameEvent", function(event)
    if not event then return end

    local local_player = entities.GetLocalPlayer()
    if not local_player then return end

    local local_idx = client.GetLocalPlayerIndex()

    if event:GetName() == "player_hurt" and ui_enable_hitsound then
        local attacker = event:GetInt("attacker")
        local victim = event:GetInt("userid")
        
        if (attacker == local_idx or attacker == (local_idx - 1)) and victim ~= attacker then
            local selected_sound = sound_files[ui_hitsound_index] or "hitsound.vsnd_c"
            PlayCustomVsnd(selected_sound)
        end

    elseif event:GetName() == "player_death" and ui_enable_killsound then
        local attacker = event:GetInt("attacker")
        local victim = event:GetInt("userid")
        
        if (attacker == local_idx or attacker == (local_idx - 1)) and victim ~= attacker then
            local selected_sound = sound_files[ui_killsound_index] or "killsound.vsnd_c"
            PlayCustomVsnd(selected_sound)
        end
    end
end)

-- =========================================================
-- MAIN DRAW LOOP & MENU RENDER
-- =========================================================

callbacks.Register("Draw", function()
    local sw, sh = draw.GetScreenSize()
    if not sw or not sh then return end

    -- Menu Toggle Key (INSERT = 45)
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
        draw.Text(win_x + 28, win_y + 18, "SCOUTWARE CFG BY Majkymit")

        local tabs = {"Visuals", "Sounds", "Misc"}
        local tab_width = 130
        local tab_height = 34
        local start_tab_x = win_x + 28
        local start_tab_y = win_y + 52

        for i, tab_name in ipairs(tabs) do
            local tx = start_tab_x + (i - 1) * (tab_width + 12)
            local ty = start_tab_y
            
            local is_tab_hovered = mx >= tx and mx <= (tx + tab_width) and my >= ty and my <= (ty + tab_height)
            if is_tab_hovered and is_single_click then
                current_tab = i
            end

            if current_tab == i then
                DrawRoundedRect(tx, ty, tab_width, tab_height, 6, 36, 30, 50, 255)
                DrawRoundedOutline(tx, ty, tab_width, tab_height, 6, 193, 31, 105, 255)
                draw.Color(193, 31, 105, 255)
            else
                if is_tab_hovered then
                    DrawRoundedRect(tx, ty, tab_width, tab_height, 6, 255, 255, 255, 8)
                    draw.Color(255, 255, 255, 200)
                else
                    draw.Color(150, 145, 165, 255)
                end
                DrawRoundedOutline(tx, ty, tab_width, tab_height, 6, 255, 255, 255, 10)
            end
            
            local tw, _ = draw.GetTextSize(tab_name)
            draw.Text(tx + math.floor((tab_width - tw) / 2), ty + 10, tab_name)
        end

        local content_x = win_x + 28
        local content_y = win_y + 98
        local area_w = window_width - 56
        local area_h = window_height - 122

        DrawRoundedRect(content_x, content_y, area_w, area_h, 8, 18, 14, 26, 255)
        DrawRoundedOutline(content_x, content_y, area_w, area_h, 8, 255, 255, 255, 8)

        local inner_x = content_x + 20
        local inner_y = content_y + 16
        local sw_w, sw_h = 44, 22

        -- TAB 1: VISUALS (LOCKED)
        if current_tab == 1 then
            draw.Color(120, 120, 135, 255)
            draw.Text(inner_x, inner_y + 2, "Custom Scope Overlay")
            DrawRoundedRect(content_x + area_w - 150, inner_y, 130, 22, 6, 28, 24, 38, 255)

            DrawRoundedRect(content_x + 2, content_y + 2, area_w - 4, area_h - 4, 7, 16, 12, 22, 210)
            DrawRoundedOutline(content_x + 6, content_y + 6, area_w - 12, area_h - 12, 6, 193, 31, 105, 180)

            local cs_title = "FEATURE COMING SOON"
            local cs_sub = "Visual module is under maintenance"
            local ctw1, _ = draw.GetTextSize(cs_title)
            local ctw2, _ = draw.GetTextSize(cs_sub)
            
            local center_box_x = content_x + math.floor(area_w / 2)
            local center_box_y = content_y + math.floor(area_h / 2)

            DrawRoundedRect(center_box_x - 130, center_box_y - 25, 260, 50, 8, 26, 21, 36, 240)
            DrawRoundedOutline(center_box_x - 130, center_box_y - 25, 260, 50, 8, 193, 31, 105, 255)

            draw.Color(255, 255, 255, 255)
            draw.Text(center_box_x - math.floor(ctw1 / 2), center_box_y - 15, cs_title)
            draw.Color(180, 175, 195, 255)
            draw.Text(center_box_x - math.floor(ctw2 / 2), center_box_y + 4, cs_sub)

        -- TAB 2: SOUNDS
        elseif current_tab == 2 then
            -- HIT SOUND
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, inner_y + 2, "Enable Hit Sound")
            
            local sw_hit_x = content_x + area_w - sw_w - 20
            if mx >= sw_hit_x and mx <= (sw_hit_x + sw_w) and my >= inner_y and my <= (inner_y + sw_h) and is_single_click then
                ui_enable_hitsound = not ui_enable_hitsound
            end

            if ui_enable_hitsound then
                DrawRoundedRect(sw_hit_x, inner_y, sw_w, sw_h, 11, 193, 31, 105, 255)
                DrawRoundedRect(sw_hit_x + sw_w - 19, inner_y + 2, 17, 17, 8, 255, 255, 255, 255)
            else
                DrawRoundedRect(sw_hit_x, inner_y, sw_w, sw_h, 11, 36, 30, 50, 255)
                DrawRoundedOutline(sw_hit_x, inner_y, sw_w, sw_h, 11, 255, 255, 255, 15)
                DrawRoundedRect(sw_hit_x + 2, inner_y + 2, 17, 17, 8, 110, 105, 125, 255)
            end

            local row_hs_y = inner_y + 36
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x + 10, row_hs_y + 2, "Hit Sound File:")
            
            local hs_btn_x = content_x + area_w - 170
            if mx >= hs_btn_x and mx <= (hs_btn_x + 150) and my >= row_hs_y and my <= (row_hs_y + 22) and is_single_click then
                ui_hitsound_index = (ui_hitsound_index % #sound_files) + 1
            end
            DrawRoundedRect(hs_btn_x, row_hs_y, 150, 22, 6, 36, 30, 50, 255)
            DrawRoundedOutline(hs_btn_x, row_hs_y, 150, 22, 6, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            local hstw, _ = draw.GetTextSize(sound_files[ui_hitsound_index])
            draw.Text(hs_btn_x + math.floor((150 - hstw) / 2), row_hs_y + 4, sound_files[ui_hitsound_index])

            -- TEST HIT BUTTON
            local test_hit_y = inner_y + 68
            local test_btn_x = inner_x + 10
            if mx >= test_btn_x and mx <= (test_btn_x + 120) and my >= test_hit_y and my <= (test_hit_y + 22) and is_single_click then
                PlayCustomVsnd(sound_files[ui_hitsound_index])
            end
            DrawRoundedRect(test_btn_x, test_hit_y, 120, 22, 6, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            draw.Text(test_btn_x + 16, test_hit_y + 4, "TEST HIT SOUND")

            -- KILL SOUND
            local row_ks_start = inner_y + 115
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, row_ks_start + 2, "Enable Kill Sound")

            if mx >= sw_hit_x and mx <= (sw_hit_x + sw_w) and my >= row_ks_start and my <= (row_ks_start + sw_h) and is_single_click then
                ui_enable_killsound = not ui_enable_killsound
            end

            if ui_enable_killsound then
                DrawRoundedRect(sw_hit_x, row_ks_start, sw_w, sw_h, 11, 193, 31, 105, 255)
                DrawRoundedRect(sw_hit_x + sw_w - 19, row_ks_start + 2, 17, 17, 8, 255, 255, 255, 255)
            else
                DrawRoundedRect(sw_hit_x, row_ks_start, sw_w, sw_h, 11, 36, 30, 50, 255)
                DrawRoundedOutline(sw_hit_x, row_ks_start, sw_w, sw_h, 11, 255, 255, 255, 15)
                DrawRoundedRect(sw_hit_x + 2, row_ks_start + 2, 17, 17, 8, 110, 105, 125, 255)
            end

            local row_ks_y = row_ks_start + 36
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x + 10, row_ks_y + 2, "Kill Sound File:")

            if mx >= hs_btn_x and mx <= (hs_btn_x + 150) and my >= row_ks_y and my <= (row_ks_y + 22) and is_single_click then
                ui_killsound_index = (ui_killsound_index % #sound_files) + 1
            end
            DrawRoundedRect(hs_btn_x, row_ks_y, 150, 22, 6, 36, 30, 50, 255)
            DrawRoundedOutline(hs_btn_x, row_ks_y, 150, 22, 6, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            local kstw, _ = draw.GetTextSize(sound_files[ui_killsound_index])
            draw.Text(hs_btn_x + math.floor((150 - kstw) / 2), row_ks_y + 4, sound_files[ui_killsound_index])

            -- TEST KILL BUTTON
            local test_kill_y = row_ks_start + 68
            if mx >= test_btn_x and mx <= (test_btn_x + 120) and my >= test_kill_y and my <= (test_kill_y + 22) and is_single_click then
                PlayCustomVsnd(sound_files[ui_killsound_index])
            end
            DrawRoundedRect(test_btn_x, test_kill_y, 120, 22, 6, 193, 31, 105, 255)
            draw.Color(255, 255, 255, 255)
            draw.Text(test_btn_x + 14, test_kill_y + 4, "TEST KILL SOUND")
        
        -- TAB 3: MISC
        elseif current_tab == 3 then
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, inner_y + 2, "Enable Watermark Overlay")
            local sw_wm_x = content_x + area_w - sw_w - 20
            if mx >= sw_wm_x and mx <= (sw_wm_x + sw_w) and my >= inner_y and my <= (inner_y + sw_h) and is_single_click then
                ui_enable_wm = not ui_enable_wm
            end
            if ui_enable_wm then
                DrawRoundedRect(sw_wm_x, inner_y, sw_w, sw_h, 11, 193, 31, 105, 255)
                DrawRoundedRect(sw_wm_x + sw_w - 19, inner_y + 2, 17, 17, 8, 255, 255, 255, 255)
            else
                DrawRoundedRect(sw_wm_x, inner_y, sw_w, sw_h, 11, 36, 30, 50, 255)
                DrawRoundedOutline(sw_wm_x, inner_y, sw_w, sw_h, 11, 255, 255, 255, 15)
                DrawRoundedRect(sw_wm_x + 2, inner_y + 2, 17, 17, 8, 110, 105, 125, 255)
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
