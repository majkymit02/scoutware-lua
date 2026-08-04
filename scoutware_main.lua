local MOI_MULTSCRIPT_VERSION = "4.0.0"
local EXPECTED_SIGNATURE = "SCOUTWARE_SIGNATURE_V1"

-- =========================================================
-- SCOUTWARE.WTF - AIMWARE CS2 LUA SCRIPT (FATALITY STYLE)
-- AUTHOR: Majkymit
-- =========================================================

local is_menu_open = true
local current_tab = 1

local ui_enable_wm = true
local ui_enable_hitsound = true
local ui_hitsound_index = 1
local ui_enable_killsound = true
local ui_killsound_index = 1
local ui_hit_volume = 100
local ui_kill_volume = 100

-- Scope Overlay konfigurace
local ui_enable_scope = false
local ui_replace_scope = true
local ui_scope_dot = true
local ui_scope_scale = 100
local scopeState, removalState = "disabled", "original scope unchanged"
local NO_SCOPE_KEY = "world.noscope"
local NATIVE_OVERLAY_KEY = "world.noscopeoverlay"
local originalNoScope, originalNativeOverlay, ownsRemoval = nil, nil, false
local lastRemovalEnforce = 0

local active_slider = nil

-- =========================================================
-- FATALITY CONFIG SYSTEM (LIVE INPUT & AUTO-LOAD ON START)
-- =========================================================
local CONFIG_FOLDER = "scoutware_configs/"
local AUTO_LOAD_FILE = CONFIG_FOLDER .. "autoad_config.txt"
local configNameInput = "default"
local selectedConfigIdx = 1
local configsList = {}
local autoLoadConfigName = "default"
local isTypingConfigName = false

local function getAvailableConfigs()
    local list = {}
    pcall(function()
        local f = file.Open(CONFIG_FOLDER .. "config_index.txt", "r")
        if f then
            local content = f:Read() or ""
            f:Close()
            for line in content:gmatch("[^\r\n]+") do
                if line ~= "" then list[#list + 1] = line end
            end
        end
    end)
    if #list == 0 then list = { "default", "legit", "rage" } end
    return list
end

local function saveConfigIndex(list)
    pcall(function()
        local data = table.concat(list, "\n")
        local f = file.Open(CONFIG_FOLDER .. "config_index.txt", "w")
        if f then f:Write(data); f:Close() end
    end)
end

local function loadAutoLoadSetting()
    pcall(function()
        local f = file.Open(AUTO_LOAD_FILE, "r")
        if f then
            local name = f:Read() or ""
            f:Close()
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            if name ~= "" then autoLoadConfigName = name end
        end
    end)
end

local function saveAutoLoadSetting(name)
    pcall(function()
        local f = file.Open(AUTO_LOAD_FILE, "w")
        if f then f:Write(name or "default"); f:Close() end
    end)
end

local function SaveScoutwareConfig(name)
    if not name or name == "" then return end
    pcall(function()
        local data = string.format("wm=%d\nhs_en=%d\nhs_idx=%d\nhs_vol=%d\nks_en=%d\nks_idx=%d\nks_vol=%d\nsc_en=%d\nsc_rep=%d\nsc_dot=%d\nsc_scale=%d",
            ui_enable_wm and 1 or 0,
            ui_enable_hitsound and 1 or 0,
            ui_hitsound_index,
            ui_hit_volume,
            ui_enable_killsound and 1 or 0,
            ui_killsound_index,
            ui_kill_volume,
            ui_enable_scope and 1 or 0,
            ui_replace_scope and 1 or 0,
            ui_scope_dot and 1 or 0,
            ui_scope_scale
        )
        local f = file.Open(CONFIG_FOLDER .. name .. ".cfg", "w")
        if f then f:Write(data); f:Close() end

        local list = getAvailableConfigs()
        local found = false
        for _, v in ipairs(list) do if v == name then found = true break end end
        if not found then
            list[#list + 1] = name
            saveConfigIndex(list)
        end
        configsList = list
    end)
end

local function LoadScoutwareConfig(name)
    if not name or name == "" then return end
    pcall(function()
        local f = file.Open(CONFIG_FOLDER .. name .. ".cfg", "r")
        if not f then return end
        local data = f:Read() or ""
        f:Close()

        for k, v in data:gmatch("([%w_]+)=(%-?%d+)") do
            local num = tonumber(v)
            if k == "wm" then ui_enable_wm = (num == 1)
            elseif k == "hs_en" then ui_enable_hitsound = (num == 1)
            elseif k == "hs_idx" then ui_hitsound_index = num
            elseif k == "hs_vol" then ui_hit_volume = num
            elseif k == "ks_en" then ui_enable_killsound = (num == 1)
            elseif k == "ks_idx" then ui_killsound_index = num
            elseif k == "ks_vol" then ui_kill_volume = num
            elseif k == "sc_en" then ui_enable_scope = (num == 1)
            elseif k == "sc_rep" then ui_replace_scope = (num == 1)
            elseif k == "sc_dot" then ui_scope_dot = (num == 1)
            elseif k == "sc_scale" then ui_scope_scale = num
            end
        end
    end)
end

local function DeleteScoutwareConfig(name)
    if not name or name == "" then return end
    pcall(function()
        local f = file.Open(CONFIG_FOLDER .. name .. ".cfg", "w")
        if f then f:Write(""); f:Close() end

        local list = getAvailableConfigs()
        local new_list = {}
        for _, v in ipairs(list) do
            if v ~= name then new_list[#new_list + 1] = v end
        end
        if #new_list == 0 then new_list = { "default" } end
        saveConfigIndex(new_list)
        configsList = new_list
    end)
end

configsList = getAvailableConfigs()
loadAutoLoadSetting()

if autoLoadConfigName and autoLoadConfigName ~= "" then
    LoadScoutwareConfig(autoLoadConfigName)
end

-- =========================================================
-- VOTE REVEALER NA POZADÍ (BEZ ZBYTEČNÉHO UI)
-- =========================================================
local PLAY_SOUND = true
local voteChatQueue = {}
local namesByUserID, namesByIndex, voteSlotNames = {}, {}, {}
local teamsByUserID, teamsByIndex, voteSlotTeams = {}, {}, {}
local preStartVotes, firstNoName = {}, ""
local currentVoteTeam, currentVoteLabel = nil, ""
local pendingVoteHint = { at = -1000, team = nil, label = "", issue = nil, parameter = nil }
local nextListenerRefresh, nextLogicTick = 0, 0, 0

local function clean(value)
    value = tostring(value or "")
    value = value:gsub("[%c]", " "):gsub('"', ""):gsub(";", ""):gsub("\\", "")
    value = value:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if #value > 80 then value = value:sub(1, 80) end
    return value
end

local function requestVoteListeners()
    pcall(function()
        if not client or type(client.AllowListener) ~= "function" then return end
        for _, name in ipairs({
            "vote_started", "vote_begin", "start_vote", "vote_cast", "vote_changed", "vote_options",
            "vote_ended", "vote_failed", "vote_passed", "player_connect",
            "player_info", "player_team", "player_disconnect", "server_spawn",
            "game_newmap", "cs_game_disconnected"
        }) do
            client.AllowListener(name)
        end
    end)
end

local function clearVoteSession(reason, preserveChat)
    if not preserveChat then voteChatQueue = {} end
    preStartVotes, firstNoName = {}, ""
    currentVoteTeam, currentVoteLabel = nil, ""
end

local function eventInt(event, field)
    local value; pcall(function() value = tonumber(event:GetInt(field)) end); return value
end
local function eventString(event, field)
    local value; pcall(function() value = event:GetString(field) end); return clean(value)
end

local function entityIndex(entity)
    local value; pcall(function() value = tonumber(entity:GetIndex()) end)
    return value and value > 0 and value or nil
end

local function controllerFor(raw)
    raw = tonumber(raw); if not raw then return nil, nil end
    local controllerIndex = (raw % 32768) + 1
    local controllers; pcall(function() controllers = entities.FindByClass("CCSPlayerController") end)
    if type(controllers) == "table" then
        for i = 1, #controllers do
            local candidate = entityIndex(controllers[i])
            if candidate == controllerIndex then return controllers[i], candidate end
        end
    end
    return nil, controllerIndex
end

local function playerNameByIndex(index)
    index = tonumber(index); if not index or index <= 0 then return "" end
    local name = ""; pcall(function() if client and type(client.GetPlayerNameByIndex) == "function" then name = client.GetPlayerNameByIndex(index) end end)
    return clean(name) ~= "CCSPlayerController" and clean(name) or ""
end

local function playerNameByUserID(userID)
    userID = tonumber(userID); if not userID or userID <= 0 then return "" end
    local name = ""; pcall(function() if client and type(client.GetPlayerNameByUserID) == "function" then name = client.GetPlayerNameByUserID(userID) end end)
    return clean(name) ~= "CCSPlayerController" and clean(name) or ""
end

local function pawnForController(controller)
    if not controller then return nil, nil end
    local pawn; pcall(function() pawn = controller:GetPropEntity("m_hPlayerPawn") end)
    if not pawn then pcall(function() pawn = controller:GetFieldEntity("m_hPlayerPawn") end) end
    local pawnIndex = entityIndex(pawn)
    if pawn and pawnIndex then return pawn, pawnIndex end
    return nil, nil
end

local function entityPlayerName(entity)
    if not entity then return "" end
    local name = ""; pcall(function() name = entity:GetName() end)
    name = clean(name)
    if name == "CCSPlayerController" or name == "C_CSPlayerPawn" then return "" end
    return name
end

local function voteIssueIndexLabel(issue, team)
    issue = tonumber(issue); team = tonumber(team)
    if issue == nil then return nil end
    if team == 2 or team == 3 then
        if issue == 0 then return "KICK PLAYER" end
        if issue == 1 then return "TIMEOUT" end
        if issue == 2 then return "SURRENDER" end
    else
        if issue == 0 then return "KICK PLAYER" end
        if issue == 1 then return "CHANGE MAP" end
        if issue == 3 then return "SCRAMBLE TEAMS" end
        if issue == 4 then return "SWAP TEAMS" end
    end
    return nil
end

local function controllerVoteLabel(team)
    if not entities or type(entities.FindByClass) ~= "function" then return nil, nil end
    local seen, candidates = {}, {}
    for _, className in ipairs({ "CVoteController", "C_VoteController" }) do
        local list; pcall(function() list = entities.FindByClass(className) end)
        if type(list) == "table" then
            for i = 1, #list do
                local entity = list[i]
                local index = entityIndex(entity) or tostring(entity)
                if not seen[index] then seen[index] = true; candidates[#candidates + 1] = entity end
            end
        end
    end
    for i = 1, #candidates do
        local entity = candidates[i]
        local issue = entityInt(entity, "m_iActiveIssueIndex")
        local onlyTeam = entityInt(entity, "m_iOnlyTeamToVote")
        if issue ~= nil and (onlyTeam == team or (team == nil and (onlyTeam == 2 or onlyTeam == 3))) then
            return voteIssueIndexLabel(issue, onlyTeam or team), issue
        end
    end
    return nil, nil
end

local function bestVoteLabel(team)
    local label, issue = controllerVoteLabel(team)
    if label then return label, issue end
    local age = clock() - (tonumber(pendingVoteHint.at) or -1000)
    if age >= 0 and age <= 3.0 and (pendingVoteHint.team == nil or team == nil or pendingVoteHint.team == team) then
        if pendingVoteHint.label ~= "" then return pendingVoteHint.label, pendingVoteHint.issue end
    end
    return nil, issue
end

local function replaceQueuedVoteLabel(label)
    if not label or label == "" then return end
    for i = 1, #voteChatQueue do
        local entry = voteChatQueue[i]
        if type(entry) == "table" and type(entry.text) == "string" then
            entry.text = entry.text:gsub("TEAM VOTE %(UNKNOWN TYPE%)", label):gsub("UNKNOWN VOTE", label)
        end
    end
end

local function voterInfo(raw, eventTeam)
    raw = tonumber(raw) or 0
    local entity, index = controllerFor(raw)
    local pawn, pawnIndex = pawnForController(entity)
    local name = ""; if pawn then name = entityPlayerName(pawn) end
    if name == "" and index then name = playerNameByIndex(index) end
    if name == "" and not entity then name = playerNameByUserID(raw) end
    if name == "" then name = "player #" .. tostring(raw) end
    local team = tonumber(eventTeam)
    if team ~= 2 and team ~= 3 and entity then team = entityInt(entity, "m_iTeamNum") end
    local teamName = team == 2 and "T" or (team == 3 and "CT" or "SPEC")
    return name, teamName, team
end

local function queueVoteChat(teamName, message)
    message = clean(message)
    if message ~= "" then voteChatQueue[#voteChatQueue + 1] = { team = teamName, text = message } end
    if #voteChatQueue > 24 then table.remove(voteChatQueue, 1) end
end

local function voteLabel(issue)
    local lower = clean(issue):lower()
    if lower:find("timeout", 1, true) then return "TIMEOUT" end
    if lower:find("kick", 1, true) then return "KICK PLAYER" end
    if lower:find("surrender", 1, true) then return "SURRENDER" end
    if lower ~= "" then return lower:gsub("#", ""):gsub("_", " "):upper() end
    return "UNKNOWN VOTE"
end

local function dispatchVoteEvent(event)
    local name; pcall(function() name = event:GetName() end)

    if name == "server_spawn" or name == "game_newmap" or name == "cs_game_disconnected" then
        requestVoteListeners(); clearVoteSession("session rearmed", true)
        namesByUserID, namesByIndex, voteSlotNames = {}, {}, {}
        return
    end
    if name == "vote_started" or name == "vote_begin" then
        preStartVotes, firstNoName = {}, ""
        local initiator = eventInt(event, "initiator") or eventInt(event, "userid") or 0
        local initiatorName, teamName, team = voterInfo(initiator, eventInt(event, "team"))
        local label = voteLabel(eventString(event, "issue"))
        if label == "UNKNOWN VOTE" then local detected = bestVoteLabel(team); if detected then label = detected end end
        currentVoteTeam, currentVoteLabel = team, label
        queueVoteChat(teamName, string.format("%s started vote: %s", initiatorName, label))
        return
    end
    if name ~= "vote_cast" then return end

    local raw = eventInt(event, "userid") or eventInt(event, "entityid"); if not raw then return end
    local option = eventInt(event, "vote_option") or eventInt(event, "vote"); if option == nil then return end

    local voter, teamName, team = voterInfo(raw, eventInt(event, "team"))
    local choice = option == 0 and "YES (F1)" or (option == 1 and "NO (F2)" or ("OPTION " .. tostring(option + 1)))
    local detectedLabel = bestVoteLabel(team)
    if detectedLabel and (currentVoteLabel == "" or currentVoteLabel:find("UNKNOWN", 1, true)) then
        currentVoteLabel = detectedLabel; replaceQueuedVoteLabel(detectedLabel)
    end
    queueVoteChat(teamName, string.format("%s voted %s | %s", voter, choice, currentVoteLabel ~= "" and currentVoteLabel or "VOTE"))
    if PLAY_SOUND then pcall(function() client.Command("play buttons\\button14.wav", true) end) end
end

local function sendVoteChat()
    if #voteChatQueue == 0 then return end
    while #voteChatQueue > 0 do
        local entry = table.remove(voteChatQueue, 1)
        local message = clean(entry.text)
        local formatted = string.char(14) .. "[VoteReveal] " .. string.char(1) .. message
        pcall(function() client.ChatSay(formatted) end)
    end
end

local function voteLogicTick(t)
    if t >= nextListenerRefresh then nextListenerRefresh = t + 2.0; requestVoteListeners() end
    sendVoteChat()
end

requestVoteListeners()

-- =========================================================
-- ČASOVAČ A POMOCNÉ FUNKCE
-- =========================================================
local function clock()
    local value = 0
    pcall(function()
        if common and type(common.Time) == "function" then value = common.Time()
        elseif globals and type(globals.RealTime) == "function" then value = globals.RealTime()
        elseif globals and type(globals.CurTime) == "function" then value = globals.CurTime() end
    end)
    return tonumber(value) or 0
end

local soundNames = { "hitsound", "killsound", "bell", "bubble", "pop", "stab" }
local soundPaths = { "hitsound", "killsound", "bell", "bubble", "pop", "stab" }

local win_x, win_y = 100, 100
local window_width, window_height = 780, 600
local is_dragging = false
local drag_offset_x, drag_offset_y = 0, 0
local key_toggle_down = false
local mouse_click_down = false

local function DrawScoutwareBox(x, y, w, h, fill_r, fill_g, fill_b, fill_a, border_r, border_g, border_b)
    draw.Color(fill_r, fill_g, fill_b, fill_a)
    draw.FilledRect(x, y, x + w, y + h)
    draw.Color(border_r, border_g, border_b, 255)
    draw.OutlinedRect(x, y, x + w, y + h)
end

local function DrawScoutwareSwitch(x, y, state)
    local sw, sh = 40, 20
    if state then
        DrawScoutwareBox(x, y, sw, sh, 193, 31, 105, 255, 225, 45, 125)
        draw.Color(255, 255, 255, 255)
        draw.FilledRect(x + sw - 18, y + 2, x + sw - 2, y + 18)
    else
        DrawScoutwareBox(x, y, sw, sh, 32, 26, 46, 255, 65, 45, 75)
        draw.Color(130, 120, 145, 255)
        draw.FilledRect(x + 2, y + 2, x + 18, y + 18)
    end
end

local function DrawScoutwareSlider(x, y, w, label, val_ref, slider_id, mx, my, is_mouse_down, is_single_click, min_v, max_v, suffix)
    min_v = min_v or 0
    max_v = max_v or 100
    suffix = suffix or "%"
    
    draw.Color(180, 175, 195, 255)
    draw.Text(x, y, label .. ": " .. tostring(val_ref) .. suffix)

    local sy = y + 18
    local sh = 6
    local sw = w

    if is_mouse_down then
        if active_slider == slider_id or (is_single_click and mx >= x and mx <= x + sw and my >= sy - 6 and my <= sy + sh + 6) then
            active_slider = slider_id
            local rel_x = math.max(0, math.min(sw, mx - x))
            local val = min_v + (rel_x / sw) * (max_v - min_v)
            return val < 1 and tonumber(string.format("%.4f", val)) or math.floor(val + 0.5)
        end
    else
        if active_slider == slider_id then
            active_slider = nil
        end
    end

    DrawScoutwareBox(x, sy, sw, sh, 32, 26, 46, 255, 65, 45, 75)

    local frac = (val_ref - min_v) / (max_v - min_v)
    local fill_w = math.floor(sw * frac)
    if fill_w > 0 then
        DrawScoutwareBox(x, sy, fill_w, sh, 193, 31, 105, 255, 225, 45, 125)
    end

    return val_ref
end

local function PlayCustomVsnd(path, volume)
    if not path or path == "" then return end
    path = path:gsub("/", "\\")
    local amount = math.max(0, math.min(100, tonumber(volume) or 100)) / 100
    pcall(function() client.SetConVar("snd_toolvolume", amount, true) end)
    pcall(function() client.Command('play "sounds\\' .. path .. '"', true) end)
end

local function DrawFatalityListbox(x, y, w, h, items, selected_idx, mx, my, is_single_click)
    DrawScoutwareBox(x, y, w, h, 22, 18, 32, 255, 65, 45, 75)
    local item_h = 24
    local visible_count = math.floor(h / item_h)

    for i = 0, visible_count - 1 do
        local index = i + 1
        if index <= #items then
            local iy = y + 2 + (i * item_h)
            local is_sel = (index == selected_idx)
            local is_hover = (mx >= x + 2 and mx <= x + w - 2 and my >= iy and my <= iy + item_h - 2)

            if is_sel then
                DrawScoutwareBox(x + 2, iy, w - 4, item_h - 2, 193, 31, 105, 180, 225, 45, 125)
                draw.Color(255, 255, 255, 255)
            elseif is_hover then
                DrawScoutwareBox(x + 2, iy, w - 4, item_h - 2, 45, 36, 60, 255, 90, 60, 105)
                draw.Color(210, 205, 225, 255)
            else
                draw.Color(160, 155, 175, 255)
            end

            if is_single_click and is_hover then
                selected_idx = index
                configNameInput = items[index]
            end

            draw.Text(x + 10, iy + 5, items[index])
        end
    end

    return selected_idx
end

-- =========================================================
-- LOGIKA PRO HITY A KILLY
-- =========================================================

local function entityIndex(entity)
    local value
    if not entity then return nil end
    pcall(function() value = tonumber(entity:GetIndex()) end)
    return value and value > 0 and value or nil
end

local function pawnHandleIndex(value)
    value = tonumber(value)
    if not value or value == 0 or value == -1 then return nil end
    local index = value % 32768
    if index <= 0 or index == 32767 then return nil end
    return index
end

local function controllerPawn(controller)
    local pawn
    if not controller then return nil end
    pcall(function() pawn = controller:GetPropEntity("m_hPlayerPawn") end)
    if not pawn then pcall(function() pawn = controller:GetFieldEntity("m_hPlayerPawn") end) end
    return pawn
end

local localIdentity = { updatedAt = -100, pawnIndices = {}, playerIndices = {}, userIDs = {} }

local function addPlayerInfo(identity, index)
    index = tonumber(index)
    if not index or index <= 0 then return end
    identity.playerIndices[index] = true
    local info
    pcall(function() info = client.GetPlayerInfo(index) end)
    if type(info) ~= "table" then return end
    local userID = tonumber(info.UserID or info.userID or info.userid)
    if userID and userID > 0 then identity.userIDs[userID] = true end
end

local function refreshLocalIdentity(force)
    local now = clock()
    if not force and now - localIdentity.updatedAt < 0.25 then return localIdentity end
    localIdentity.updatedAt = now
    localIdentity.pawnIndices = {}
    localIdentity.playerIndices = {}
    localIdentity.userIDs = {}

    local localPawn
    pcall(function() localPawn = entities.GetLocalPlayer() end)
    local localPawnIndex = entityIndex(localPawn)
    if localPawnIndex then
        localIdentity.pawnIndices[localPawnIndex] = true
        addPlayerInfo(localIdentity, localPawnIndex)
    end

    local localClientIndex
    pcall(function() localClientIndex = tonumber(client.GetLocalPlayerIndex()) end)
    addPlayerInfo(localIdentity, localClientIndex)

    local controllers
    pcall(function() controllers = entities.FindByClass("CCSPlayerController") end)
    if type(controllers) == "table" then
        for i = 1, #controllers do
            local controller = controllers[i]
            local controllerIndex = entityIndex(controller)
            local controllerIsLocal
            pcall(function() controllerIsLocal = controller:GetFieldBool("m_bIsLocalPlayerController") end)
            if controllerIsLocal == nil then
                pcall(function() controllerIsLocal = controller:GetPropBool("m_bIsLocalPlayerController") end)
            end
            local pawnIndex = entityIndex(controllerPawn(controller))
            if controllerIsLocal == true or (localPawnIndex and pawnIndex and pawnIndex == localPawnIndex) then
                if pawnIndex then localIdentity.pawnIndices[pawnIndex] = true end
                addPlayerInfo(localIdentity, controllerIndex)
                if pawnIndex then addPlayerInfo(localIdentity, controllerIndex) end
            end
        end
    end
    return localIdentity
end

local function isLocalActor(rawUserID, pawnHandle)
    local identity = refreshLocalIdentity(false)
    local pawnIndex = pawnHandleIndex(pawnHandle)
    if pawnIndex then return identity.pawnIndices[pawnIndex] == true end

    rawUserID = tonumber(rawUserID)
    if not rawUserID or rawUserID <= 0 then return false end
    if identity.userIDs[rawUserID] == true then return true end

    local mappedIndex
    pcall(function() mappedIndex = tonumber(client.GetPlayerIndexByUserID(rawUserID)) end)
    return mappedIndex ~= nil and identity.playerIndices[mappedIndex] == true
end

local lastKillSignature, lastKillAt = nil, -100

local function killSignature(attacker, victim, attackerPawn, victimPawn)
    return table.concat({ tostring(pawnHandleIndex(attackerPawn) or attacker or 0), tostring(pawnHandleIndex(victimPawn) or victim or 0) }, ":")
end

local function playKillOnce(signature)
    local t = clock()
    if signature == lastKillSignature and t - lastKillAt < 0.50 then return end
    lastKillSignature, lastKillAt = signature, t
    local sound_path = soundPaths[ui_killsound_index] or soundPaths[1]
    if sound_path then PlayCustomVsnd(sound_path, ui_kill_volume) end
end

callbacks.Register("FireGameEvent", function(event)
    if not event then return end
    dispatchVoteEvent(event)

    local name
    pcall(function() name = event:GetName() end)
    if name ~= "player_hurt" and name ~= "player_death" then return end

    local attacker, victim, attackerPawn, victimPawn, health, damage
    pcall(function()
        attacker = tonumber(event:GetInt("attacker"))
        victim = tonumber(event:GetInt("userid"))
        attackerPawn = tonumber(event:GetInt("attacker_pawn"))
        victimPawn = tonumber(event:GetInt("userid_pawn"))
        health = tonumber(event:GetInt("health"))
        damage = tonumber(event:GetInt("dmg_health"))
    end)

    local attackerPawnIndex, victimPawnIndex = pawnHandleIndex(attackerPawn), pawnHandleIndex(victimPawn)
    if attacker and victim and attacker == victim then return end
    if attackerPawnIndex and victimPawnIndex and attackerPawnIndex == victimPawnIndex then return end
    if not isLocalActor(attacker, attackerPawn) then return end
    if isLocalActor(victim, victimPawn) then return end

    local signature = killSignature(attacker, victim, attackerPawn, victimPawn)
    if name == "player_death" then
        if ui_enable_killsound then playKillOnce(signature) end
        return
    end
    
    if not damage or damage <= 0 then return end
    if health and health <= 0 then
        if ui_enable_killsound then playKillOnce(signature)
        elseif ui_enable_hitsound then
            local sound_path = soundPaths[ui_hitsound_index] or soundPaths[1]
            if sound_path then PlayCustomVsnd(sound_path, ui_hit_volume) end
        end
    elseif ui_enable_hitsound then
        local sound_path = soundPaths[ui_hitsound_index] or soundPaths[1]
        if sound_path then PlayCustomVsnd(sound_path, ui_hit_volume) end
    end
end)

-- =========================================================
-- SCOPE OVERLAY LOGIKA
-- =========================================================

local function getGuiValue(key)
    local value, ok
    ok = pcall(function() value = gui.GetValue(key) end)
    if not ok then return nil end
    return value
end

local function setGuiValue(key, value)
    return pcall(function() gui.SetValue(key, value) end)
end

local function restoreRemoval()
    if not ownsRemoval then return end
    if originalNoScope ~= nil then pcall(setGuiValue, NO_SCOPE_KEY, originalNoScope) end
    if originalNativeOverlay ~= nil then pcall(setGuiValue, NATIVE_OVERLAY_KEY, originalNativeOverlay) end
    ownsRemoval, originalNoScope, originalNativeOverlay = false, nil, nil
    removalState = "original scope restored"
end

local function syncRemoval(wanted)
    if wanted == nil then wanted = ui_enable_scope and ui_replace_scope end
    if wanted and not ownsRemoval then
        local currentNoScope = getGuiValue(NO_SCOPE_KEY)
        local currentNativeOverlay = getGuiValue(NATIVE_OVERLAY_KEY)
        if currentNoScope == nil and currentNativeOverlay == nil then
            removalState = "Aimware removal unavailable; overlay only"
            return
        end
        originalNoScope = currentNoScope
        originalNativeOverlay = currentNativeOverlay
        local scopeOK = currentNoScope == nil or setGuiValue(NO_SCOPE_KEY, true)
        local overlayOK = currentNativeOverlay == nil or setGuiValue(NATIVE_OVERLAY_KEY, false)
        if scopeOK and overlayOK then
            ownsRemoval = true
            lastRemovalEnforce = clock()
            removalState = "native scope + cross lines hidden"
        else
            if originalNoScope ~= nil then pcall(setGuiValue, NO_SCOPE_KEY, originalNoScope) end
            if originalNativeOverlay ~= nil then pcall(setGuiValue, NATIVE_OVERLAY_KEY, originalNativeOverlay) end
            originalNoScope, originalNativeOverlay = nil, nil
            removalState = "Aimware removal refused; overlay only"
        end
    elseif wanted and ownsRemoval then
        local now = clock()
        if now - lastRemovalEnforce >= 0.50 then
            lastRemovalEnforce = now
            if originalNoScope ~= nil and getGuiValue(NO_SCOPE_KEY) ~= true then
                setGuiValue(NO_SCOPE_KEY, true)
            end
            if originalNativeOverlay ~= nil and getGuiValue(NATIVE_OVERLAY_KEY) ~= false then
                setGuiValue(NATIVE_OVERLAY_KEY, false)
            end
        end
        removalState = "native scope + cross lines hidden"
    elseif not wanted and ownsRemoval then
        restoreRemoval()
    elseif not wanted then
        removalState = "original scope unchanged"
    end
end

local SNIPER_IDS = { [9] = true, [11] = true, [38] = true, [40] = true }

local function applyGlowColor(color, alpha, whiteMix)
    whiteMix = whiteMix or 0
    draw.Color(
        math.floor(color[1] + (255 - color[1]) * whiteMix + 0.5),
        math.floor(color[2] + (255 - color[2]) * whiteMix + 0.5),
        math.floor(color[3] + (255 - color[3]) * whiteMix + 0.5),
        math.floor(color[4] * alpha + 0.5)
    )
end

local function fourTaperedSegments(cx, cy, inner, outer, halfWidth)
    draw.Triangle(cx - inner, cy - halfWidth, cx - inner, cy + halfWidth, cx - outer, cy)
    draw.Triangle(cx + inner, cy - halfWidth, cx + inner, cy + halfWidth, cx + outer, cy)
    draw.Triangle(cx - halfWidth, cy - inner, cx + halfWidth, cy - inner, cx, cy - outer)
    draw.Triangle(cx - halfWidth, cy + inner, cx + halfWidth, cy + inner, cx, cy + outer)
end

local function drawNeverloseGlow(cx, cy, color, alpha, scale, showDot)
    local s = scale / 100
    applyGlowColor(color, alpha * 0.075, 0.00)
    fourTaperedSegments(cx, cy, math.floor(10 * s), math.floor(122 * s), math.floor(5 * s))
    if showDot then draw.FilledCircle(cx, cy, math.max(1, math.floor(5 * s))) end

    applyGlowColor(color, alpha * 0.20, 0.22)
    fourTaperedSegments(cx, cy, math.floor(12 * s), math.floor(118 * s), math.floor(3 * s))
    if showDot then draw.FilledCircle(cx, cy, math.max(1, math.floor(3 * s))) end

    applyGlowColor(color, alpha * 0.88, 0.76)
    fourTaperedSegments(cx, cy, math.floor(15 * s), math.floor(112 * s), math.floor(1 * s))
    if showDot then draw.FilledCircle(cx, cy, math.max(1, math.floor(2 * s))) end
end

local TEXTURE_SIZE, TEXTURE_HALF = 300, 150
local scopeTexture = nil
local requestedTextureKey, requestedTextureColor = nil, nil
local textureDirtyAt, nextTextureRetry = 0, 0

local function colorKey(color)
    return table.concat({ color[1], color[2], color[3], color[4] }, ",")
end

local function mixedRGB(color, whiteMix)
    local function channel(value)
        return math.floor(value + (255 - value) * whiteMix + 0.5)
    end
    return string.format("rgb(%d,%d,%d)", channel(color[1]), channel(color[2]), channel(color[3]))
end

local function taperedArmsPath(halfWidth, tipLength)
    local c, inner, outer = TEXTURE_HALF, 17, 112
    local leftInner, leftTip = c - inner, c - outer
    local rightInner, rightTip = c + inner, c + outer
    local topInner, topTip = c - inner, c - outer
    local bottomInner, bottomTip = c + inner, c + outer
    local leftBase, rightBase = leftTip + tipLength, rightTip - tipLength
    local topBase, bottomBase = topTip + tipLength, bottomTip - tipLength
    return table.concat({
        string.format("M %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f Z",
            leftInner, c - halfWidth, leftBase, c - halfWidth, leftTip, c,
            leftBase, c + halfWidth, leftInner, c + halfWidth),
        string.format("M %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f Z",
            rightInner, c - halfWidth, rightBase, c - halfWidth, rightTip, c,
            rightBase, c + halfWidth, rightInner, c + halfWidth),
        string.format("M %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f Z",
            c - halfWidth, topInner, c - halfWidth, topBase, c, topTip,
            c + halfWidth, topBase, c + halfWidth, topInner),
        string.format("M %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f Z",
            c - halfWidth, bottomInner, c - halfWidth, bottomBase, c, bottomTip,
            c + halfWidth, bottomBase, c + halfWidth, bottomInner),
    }, " ")
end

local function buildScopeSVG(color, showDot)
    local alphaScale = (tonumber(color[4]) or 255) / 255
    local layers = {
        { 16.0, 24, 0.010, 0.00, 14.0 },
        { 11.0, 21, 0.018, 0.02, 10.0 },
        {  7.0, 18, 0.032, 0.06,  7.0 },
        {  4.0, 15, 0.065, 0.14,  4.5 },
        {  2.1, 12, 0.160, 0.32,  2.8 },
        {  0.65, 9, 0.940, 0.78,  1.55 },
    }
    local parts = {
        string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" shape-rendering="geometricPrecision">',
            TEXTURE_SIZE, TEXTURE_SIZE, TEXTURE_SIZE, TEXTURE_SIZE),
    }
    for i = 1, #layers do
        local layer = layers[i]
        local opacity = layer[3] * alphaScale
        parts[#parts + 1] = string.format('<path d="%s" fill="%s" fill-opacity="%.5f"/>',
            taperedArmsPath(layer[1], layer[2]), mixedRGB(color, layer[4]), opacity)
        if showDot then
            parts[#parts + 1] = string.format('<circle cx="%d" cy="%d" r="%.2f" fill="%s" fill-opacity="%.5f"/>',
                TEXTURE_HALF, TEXTURE_HALF, layer[5], mixedRGB(color, layer[4]), opacity)
        end
    end
    parts[#parts + 1] = "</svg>"
    return table.concat(parts)
end

local function rebuildScopeTexture(color, showDot, now)
    now = now or clock()
    if not common or type(common.RasterizeSVG) ~= "function" or
       not draw or type(draw.CreateTexture) ~= "function" then
        nextTextureRetry = now + 2.0
        return false
    end
    local key = colorKey(color) .. tostring(showDot)
    local ok, rgba, width, height = pcall(common.RasterizeSVG, buildScopeSVG(color, showDot), 2)
    if not ok or type(rgba) ~= "string" or not width or not height then
        nextTextureRetry = now + 2.0
        return false
    end
    if scopeTexture and type(draw.UpdateTexture) == "function" then
        local updateOK = pcall(draw.UpdateTexture, scopeTexture, rgba)
        if updateOK then
            textureDirtyAt = 0
            return true
        end
    end
    local createOK, texture = pcall(draw.CreateTexture, rgba, width, height)
    if createOK and texture then
        scopeTexture, textureDirtyAt = texture, 0
        return true
    end
    nextTextureRetry = now + 2.0
    return false
end

local function requestScopeTexture(color, showDot, now, immediate)
    local key = colorKey(color) .. tostring(showDot)
    if key ~= requestedTextureKey then
        requestedTextureKey = key
        requestedTextureColor = { color[1], color[2], color[3], color[4] }
        textureDirtyAt = immediate and now or (now + 0.12)
    end
end

local ui_scope_color = { 255, 205, 160, 255 }
requestScopeTexture(ui_scope_color, ui_scope_dot, clock(), true)
rebuildScopeTexture(requestedTextureColor, ui_scope_dot, clock())

local scopedReaders = {
    function(player) return player:GetFieldBool("m_bIsScoped") end,
    function(player) return player:GetPropBool("m_bIsScoped") end,
    function(player) return player:GetFieldInt("m_bIsScoped") end,
    function(player) return player:GetPropInt("m_bIsScoped") end,
}
local selectedScopedReader = nil
local function readScopedFast(player)
    if selectedScopedReader then
        local ok, value = pcall(selectedScopedReader, player)
        if ok and value ~= nil then return value == true or tonumber(value) == 1 end
        selectedScopedReader = nil
    end
    for i = 1, #scopedReaders do
        local reader = scopedReaders[i]
        local ok, value = pcall(reader, player)
        if ok and value ~= nil then
            selectedScopedReader = reader
            return value == true or tonumber(value) == 1
        end
    end
    return false
end

local function scopedSniperFast()
    local ok, player = pcall(entities.GetLocalPlayer)
    if not ok or not player then return false, "waiting for player" end
    local aliveOK, alive = pcall(function() return player:IsAlive() end)
    if not aliveOK or alive ~= true then return false, "waiting for spawn" end
    local idOK, weaponID = pcall(function() return tonumber(player:GetWeaponID()) end)
    if not idOK or not SNIPER_IDS[weaponID] then return false, "sniper inactive" end
    if not readScopedFast(player) then return false, "not scoped" end
    return true, "active"
end

local fade, lastDrawAt = 0, clock()
local scopeVisible = false
local nextStatePoll, nextRemovalPoll, nextScreenPoll = 0, 0, 0
local screenWidth, screenHeight = 0, 0

local function drawScopeOverlay()
    local now = clock()
    local dt = math.max(0, math.min(0.10, now - lastDrawAt))
    lastDrawAt = now

    if now >= nextStatePoll then
        nextStatePoll = now + 0.05
        if ui_enable_scope then
            scopeVisible, scopeState = scopedSniperFast()
        else
            scopeVisible, scopeState = false, "disabled"
        end
    end
    if now >= nextRemovalPoll then
        nextRemovalPoll = now + 0.50
        syncRemoval(ui_enable_scope and ui_replace_scope)
    end

    local target = scopeVisible and 1 or 0
    fade = fade + (target - fade) * math.min(1, dt * 16)
    if fade < 0.01 or is_menu_open then return end

    if now >= nextScreenPoll or screenWidth <= 0 or screenHeight <= 0 then
        nextScreenPoll = now + 2.0
        pcall(function() screenWidth, screenHeight = draw.GetScreenSize() end)
    end
    if not screenWidth or not screenHeight or screenWidth <= 0 or screenHeight <= 0 then return end
    local cx, cy = math.floor(screenWidth / 2), math.floor(screenHeight / 2)
    if textureDirtyAt > 0 and now >= textureDirtyAt and now >= nextTextureRetry then
        rebuildScopeTexture(requestedTextureColor or ui_scope_color, ui_scope_dot, now)
    end
    
    local s = ui_scope_scale / 100
    if scopeTexture and type(draw.SetTexture) == "function" then
        draw.Color(255, 255, 255, math.floor(255 * fade + 0.5))
        draw.SetTexture(scopeTexture)
        local halfW = math.floor(TEXTURE_HALF * s)
        draw.FilledRect(cx - halfW, cy - halfW, cx + halfW, cy + halfW)
        pcall(draw.SetTexture, nil)
    else
        drawNeverloseGlow(cx, cy, ui_scope_color, fade, ui_scope_scale, ui_scope_dot)
    end
end

-- =========================================================
-- VYKRESLOVÁNÍ MENU A ROZHRANÍ
-- =========================================================

callbacks.Register("Draw", function()
    local sw, sh = draw.GetScreenSize()
    if not sw or not sh then return end

    drawScopeOverlay()
    
    local t = clock()
    if t >= nextLogicTick then
        nextLogicTick = t + 0.05
        voteLogicTick(t)
    end

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
            if not is_dragging and active_slider == nil then
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

        -- Hlavní pozadí okna
        DrawScoutwareBox(win_x, win_y, window_width, window_height, 18, 14, 26, 252, 193, 31, 105)

        -- 1. HORNÍ LIŠTA S NÁPISEM
        DrawScoutwareBox(win_x, win_y, window_width, 42, 22, 18, 32, 255, 65, 45, 75)
        draw.Color(255, 255, 255, 255)
        draw.Text(win_x + 16, win_y + 12, "SCOUT")
        local tw = draw.GetTextSize("SCOUT")
        draw.Color(193, 31, 105, 255)
        draw.Text(win_x + 16 + tw, win_y + 12, "WARE.WTF")

        -- 2. ZÁLOŽKY
        local tabs = {"Visuals", "Sounds", "Misc", "Configs"}
        local tab_width, tab_height = 100, 24
        local start_tab_x = win_x + 16
        local start_tab_y = win_y + 48

        for i, tab_name in ipairs(tabs) do
            local tx = start_tab_x + (i - 1) * (tab_width + 8)
            local ty = start_tab_y
            
            local is_tab_hovered = mx >= tx and mx <= (tx + tab_width) and my >= ty and my <= (ty + tab_height)
            if is_tab_hovered and is_single_click then
                current_tab = i
            end

            if current_tab == i then
                DrawScoutwareBox(tx, ty, tab_width, tab_height, 45, 22, 40, 255, 193, 31, 105)
                draw.Color(255, 255, 255, 255)
            else
                if is_tab_hovered then
                    DrawScoutwareBox(tx, ty, tab_width, tab_height, 40, 32, 55, 200, 90, 60, 105)
                else
                    DrawScoutwareBox(tx, ty, tab_width, tab_height, 28, 22, 40, 200, 55, 40, 65)
                end
                draw.Color(160, 155, 175, 255)
            end
            
            local ttw, _ = draw.GetTextSize(tab_name)
            draw.Text(tx + math.floor((tab_width - ttw) / 2), ty + 4, tab_name)
        end

        -- 3. OBSAHOVÉ OKNO
        local content_x = win_x + 16
        local content_y = win_y + 84
        local area_w = window_width - 32
        local area_h = window_height - 100

        DrawScoutwareBox(content_x, content_y, area_w, area_h, 26, 21, 36, 255, 65, 45, 75)

        local inner_x = content_x + 16
        local inner_y = content_y + 16
        local sw_w, sw_h = 40, 20

        -- TAB 1: VISUALS
        if current_tab == 1 then
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, inner_y + 2, "Scope Overlay")
            
            local sw_scope_x = content_x + area_w - sw_w - 24
            if mx >= sw_scope_x and mx <= (sw_scope_x + sw_w) and my >= inner_y and my <= (inner_y + sw_h) and is_single_click then
                ui_enable_scope = not ui_enable_scope
            end

            DrawScoutwareSwitch(sw_scope_x, inner_y, ui_enable_scope)

            local row_rep_y = inner_y + 35
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, row_rep_y + 2, "Replace Original Scope")

            if mx >= sw_scope_x and mx <= (sw_scope_x + sw_w) and my >= row_rep_y and my <= (row_rep_y + sw_h) and is_single_click then
                ui_replace_scope = not ui_replace_scope
            end

            DrawScoutwareSwitch(sw_scope_x, row_rep_y, ui_replace_scope)

            local row_dot_y = row_rep_y + 35
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, row_dot_y + 2, "Center Dot")

            if mx >= sw_scope_x and mx <= (sw_scope_x + sw_w) and my >= row_dot_y and my <= (row_dot_y + sw_h) and is_single_click then
                ui_scope_dot = not ui_scope_dot
                requestScopeTexture(ui_scope_color, ui_scope_dot, clock(), true)
                rebuildScopeTexture(requestedTextureColor, ui_scope_dot, clock())
            end

            DrawScoutwareSwitch(sw_scope_x, row_dot_y, ui_scope_dot)

            local row_scale_y = row_dot_y + 35
            ui_scope_scale = DrawScoutwareSlider(inner_x, row_scale_y, area_w - 32, "Scope Scale", ui_scope_scale, "scope_scale", mx, my, is_mouse_down, is_single_click, 25, 200, "%")

            local row_stat_y = row_scale_y + 45
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x, row_stat_y, "Status: " .. scopeState)
            draw.Text(inner_x, row_stat_y + 20, "Default: " .. removalState)

        -- TAB 2: SOUNDS
        elseif current_tab == 2 then
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, inner_y + 2, "Hit Sound")
            
            local sw_hit_x = content_x + area_w - sw_w - 24
            if mx >= sw_hit_x and mx <= (sw_hit_x + sw_w) and my >= inner_y and my <= (inner_y + sw_h) and is_single_click then
                ui_enable_hitsound = not ui_enable_hitsound
            end

            DrawScoutwareSwitch(sw_hit_x, inner_y, ui_enable_hitsound)

            local row_hs_y = inner_y + 30
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x, row_hs_y + 2, "Hit Sound File:")
            
            local hs_btn_x = content_x + area_w - 200
            local current_hit_name = soundNames[ui_hitsound_index] or "Žádný"
            
            if mx >= hs_btn_x and mx <= (hs_btn_x + 172) and my >= row_hs_y and my <= (row_hs_y + 22) and is_single_click then
                ui_hitsound_index = (ui_hitsound_index % #soundNames) + 1
            end
            DrawScoutwareBox(hs_btn_x, row_hs_y, 172, 22, 32, 26, 46, 255, 193, 31, 105)
            draw.Color(255, 255, 255, 255)
            local hstw, _ = draw.GetTextSize(current_hit_name)
            draw.Text(hs_btn_x + math.floor((172 - hstw) / 2), row_hs_y + 4, current_hit_name)

            local vol_hs_y = inner_y + 60
            ui_hit_volume = DrawScoutwareSlider(inner_x, vol_hs_y, area_w - 32, "Hit Sound Volume", ui_hit_volume, "hit_vol", mx, my, is_mouse_down, is_single_click, 0, 100, "%")

            local test_hit_y = inner_y + 92
            local test_btn_w = 110
            if mx >= inner_x and mx <= (inner_x + test_btn_w) and my >= test_hit_y and my <= (test_hit_y + 20) and is_single_click then
                if soundPaths[ui_hitsound_index] then
                    PlayCustomVsnd(soundPaths[ui_hitsound_index], ui_hit_volume)
                end
            end
            DrawScoutwareBox(inner_x, test_hit_y, test_btn_w, 20, 193, 31, 105, 255, 225, 45, 125)
            draw.Color(255, 255, 255, 255)
            local tht_w, _ = draw.GetTextSize("TEST HIT")
            draw.Text(inner_x + math.floor((test_btn_w - tht_w) / 2), test_hit_y + 3, "TEST HIT")

            local row_ks_start = inner_y + 124
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, row_ks_start + 2, "Kill Sound")

            if mx >= sw_hit_x and mx <= (sw_hit_x + sw_w) and my >= row_ks_start and my <= (row_ks_start + sw_h) and is_single_click then
                ui_enable_killsound = not ui_enable_killsound
            end

            DrawScoutwareSwitch(sw_hit_x, row_ks_start, ui_enable_killsound)

            local row_ks_y = row_ks_start + 30
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x, row_ks_y + 2, "Kill Sound File:")

            local current_kill_name = soundNames[ui_killsound_index] or "Žádný"
            
            if mx >= hs_btn_x and mx <= (hs_btn_x + 172) and my >= row_ks_y and my <= (row_ks_y + 22) and is_single_click then
                ui_killsound_index = (ui_killsound_index % #soundNames) + 1
            end
            DrawScoutwareBox(hs_btn_x, row_ks_y, 172, 22, 32, 26, 46, 255, 193, 31, 105)
            draw.Color(255, 255, 255, 255)
            local kstw, _ = draw.GetTextSize(current_kill_name)
            draw.Text(hs_btn_x + math.floor((172 - kstw) / 2), row_ks_y + 4, current_kill_name)

            local vol_ks_y = row_ks_start + 60
            ui_kill_volume = DrawScoutwareSlider(inner_x, vol_ks_y, area_w - 32, "Kill Sound Volume", ui_kill_volume, "kill_vol", mx, my, is_mouse_down, is_single_click, 0, 100, "%")

            local test_kill_y = row_ks_start + 92
            if mx >= inner_x and mx <= (inner_x + test_btn_w) and my >= test_kill_y and my <= (test_kill_y + 20) and is_single_click then
                if soundPaths[ui_killsound_index] then
                    PlayCustomVsnd(soundPaths[ui_killsound_index], ui_kill_volume)
                end
            end
            DrawScoutwareBox(inner_x, test_kill_y, test_btn_w, 20, 193, 31, 105, 255, 225, 45, 125)
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
            
            DrawScoutwareSwitch(sw_wm_x, inner_y, ui_enable_wm)

        -- TAB 4: CONFIGS (BEZPEČNĚ UVNITŘ S MEZEROU OD OKRAJE)
        elseif current_tab == 4 then
            draw.Color(235, 235, 245, 255)
            draw.Text(inner_x, inner_y + 2, "Configuration Manager")

            local gap = 24
            local total_usable_w = area_w - 32
            local col_w = math.floor((total_usable_w - gap) / 2)
            local col_h = area_h - 50
            local col_y = inner_y + 28

            -- Levý sloupec: Seznam uložených configů
            draw.Color(180, 175, 195, 255)
            draw.Text(inner_x, col_y, "Saved Configs:")
            selectedConfigIdx = DrawFatalityListbox(inner_x, col_y + 18, col_w, col_h - 18, configsList, selectedConfigIdx, mx, my, is_single_click)

            -- Pravý sloupec
            local right_x = inner_x + col_w + gap
            draw.Color(180, 175, 195, 255)
            draw.Text(right_x, col_y, "Config Name:")

            local input_box_y = col_y + 18
            local is_input_hover = (mx >= right_x and mx <= right_x + col_w and my >= input_box_y and my <= input_box_y + 28)
            if is_single_click then isTypingConfigName = is_input_hover end

            if isTypingConfigName and input and input.IsButtonDown then
                for vk = 65, 90 do
                    if input.IsButtonPressed and input.IsButtonPressed(vk) then
                        local char = string.char(vk):lower()
                        configNameInput = configNameInput == "default" and char or (configNameInput .. char)
                    end
                end
                if input.IsButtonPressed and input.IsButtonPressed(8) then
                    if #configNameInput > 0 then configNameInput = configNameInput:sub(1, #configNameInput - 1) end
                end
            end

            DrawScoutwareBox(right_x, input_box_y, col_w, 28, 32, 26, 46, 255, isTypingConfigName and 225 or 193, isTypingConfigName and 45 or 31, isTypingConfigName and 125 or 105)
            draw.Color(255, 255, 255, 255)
            draw.Text(right_x + 12, input_box_y + 6, configNameInput .. (isTypingConfigName and "_" or ""))

            local btn_y = col_y + 64
            local btn_h = 30
            local btn_spacing = 38

            -- Tlačítko SAVE
            local is_save_hover = (mx >= right_x and mx <= right_x + col_w and my >= btn_y and my <= btn_y + btn_h)
            if is_single_click and is_save_hover then SaveScoutwareConfig(configNameInput) end
            DrawScoutwareBox(right_x, btn_y, col_w, btn_h, is_save_hover and 225 or 193, is_save_hover and 45 or 31, is_save_hover and 125 or 105, 255, 255, 255, 255)
            draw.Color(255, 255, 255, 255)
            local stw, _ = draw.GetTextSize("SAVE CONFIG")
            draw.Text(right_x + math.floor((col_w - stw) / 2), btn_y + 8, "SAVE CONFIG")

            -- Tlačítko LOAD
            local load_y = btn_y + btn_spacing
            local is_load_hover = (mx >= right_x and mx <= right_x + col_w and my >= load_y and my <= load_y + btn_h)
            if is_single_click and is_load_hover then LoadScoutwareConfig(configsList[selectedConfigIdx] or configNameInput) end
            DrawScoutwareBox(right_x, load_y, col_w, btn_h, is_load_hover and 75 or 55, is_load_hover and 65 or 45, is_load_hover and 85 or 65, 255, 193, 31, 105)
            draw.Color(255, 255, 255, 255)
            local ltw, _ = draw.GetTextSize("LOAD CONFIG")
            draw.Text(right_x + math.floor((col_w - ltw) / 2), load_y + 8, "LOAD CONFIG")

            -- Tlačítko AUTO-LOAD
            local autoload_y = load_y + btn_spacing
            local is_autoload_hover = (mx >= right_x and mx <= right_x + col_w and my >= autoload_y and my <= autoload_y + btn_h)
            if is_single_click and is_autoload_hover then autoLoadConfigName = configNameInput; saveAutoLoadSetting(autoLoadConfigName) end
            DrawScoutwareBox(right_x, autoload_y, col_w, btn_h, is_autoload_hover and 40 or 30, is_autoload_hover and 120 or 90, is_autoload_hover and 180 or 140, 255, 193, 31, 105)
            draw.Color(255, 255, 255, 255)
            local alt_txt = "SET AUTO-LOAD (" .. autoLoadConfigName .. ")"
            local altw, _ = draw.GetTextSize(alt_txt)
            if altw > col_w - 10 then alt_txt = "SET AUTO-LOAD"; altw, _ = draw.GetTextSize(alt_txt) end
            draw.Text(right_x + math.floor((col_w - altw) / 2), autoload_y + 8, alt_txt)

            -- Tlačítko DELETE
            local del_y = autoload_y + btn_spacing
            local is_del_hover = (mx >= right_x and mx <= right_x + col_w and my >= del_y and my <= del_y + btn_h)
            if is_single_click and is_del_hover then DeleteScoutwareConfig(configsList[selectedConfigIdx] or configNameInput) end
            DrawScoutwareBox(right_x, del_y, col_w, btn_h, is_del_hover and 200 or 150, is_del_hover and 50 or 30, is_del_hover and 50 or 30, 255, 193, 31, 105)
            draw.Color(255, 255, 255, 255)
            local dtw, _ = draw.GetTextSize("DELETE CONFIG")
            draw.Text(right_x + math.floor((col_w - dtw) / 2), del_y + 8, "DELETE CONFIG")
        end
    end

    if ui_enable_wm then
        local fps = math.floor(1 / (globals.AbsoluteFrameTime() > 0 and globals.AbsoluteFrameTime() or 0.016))
        local wm_title = "Scoutware.wtf (beta)"
        local wm_fps = " | FPS: " .. fps
        local tw1, _ = draw.GetTextSize(wm_title)
        local tw2, _ = draw.GetTextSize(wm_fps)
        local wm_w = tw1 + tw2 + 28
        local wm_h = 32
        local wm_x = sw - wm_w - 16
        local wm_y = 16

        DrawScoutwareBox(wm_x, wm_y, wm_w, wm_h, 18, 14, 26, 230, 193, 31, 105)
        draw.Color(255, 255, 255, 255)
        draw.Text(wm_x + 14, wm_y + 9, wm_title)
        draw.Color(193, 31, 105, 255)
        draw.Text(wm_x + 14 + tw1, wm_y + 9, wm_fps)
    end
end)

callbacks.Register("Unload", function()
    restoreRemoval()
    pcall(draw.SetTexture, nil)
    scopeTexture = nil
end)
