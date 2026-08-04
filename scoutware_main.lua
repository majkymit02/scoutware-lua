-- =========================================================
-- SCOUTWARE.WTF - LOADER / AUTO-UPDATER
-- AUTHOR: Majkymit
-- =========================================================

local USER = "majkymit02"
local REPO = "scoutware-lua"
local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/" .. USER .. "/" .. REPO .. "/" .. BRANCH .. "/"

local MANIFEST_FILE = "SCOUTWARE_local_version.txt"
local CACHE_FILE = "SCOUTWARE_source_cache.txt"
local EXPECTED_SIGNATURE = "SCOUTWARE_SIGNATURE_V1"
local DEFAULT_MIN_BYTES = 100

local function readFile(path)
    if type(file) == "table" and type(file.Read) == "function" then
        local ok, data = pcall(file.Read, path)
        if ok and type(data) == "string" then return data end
    end
    local data
    pcall(function()
        local f = file.Open(path, "r")
        if f then data = f:Read(); f:Close() end
    end)
    return data
end

local function writeFile(path, data)
    if type(file) == "table" and type(file.Write) == "function" then
        local ok = pcall(file.Write, path, data)
        if ok then return true end
    end
    local ok = false
    pcall(function()
        local f = file.Open(path, "w")
        if f then f:Write(data); f:Close(); ok = true end
    end)
    return ok
end

local function fetch(url)
    local body
    pcall(function() body = http.Get(url) end)
    if type(body) == "string" and #body > 0 then return body end
    return nil
end

local function parseManifest(text)
    if type(text) ~= "string" then return nil, "manifest unavailable" end
    local out = {}
    for line in text:gmatch("[^\r\n]+") do
        local key, value = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
        if key and value and value ~= "" then out[key] = value end
    end
    if not out.version or not out.source then return nil, "invalid manifest" end
    out.min_bytes = tonumber(out.min_bytes) or DEFAULT_MIN_BYTES
    return out
end

local function readLocalVersion()
    local text = readFile(MANIFEST_FILE)
    if type(text) ~= "string" then return nil end
    return text:match("version%s*=%s*([^%s]+)")
end

local function validateSource(source, expectedVersion, minBytes)
    if type(source) ~= "string" or #source < (minBytes or DEFAULT_MIN_BYTES) then
        return nil, "source is missing or truncated"
    end
    if not source:find(EXPECTED_SIGNATURE, 1, true) then
        return nil, "source signature mismatch"
    end
    if expectedVersion then
        local marker = 'local MOI_MULTSCRIPT_VERSION = "' .. expectedVersion .. '"'
        if not source:find(marker, 1, true) then return nil, "source version mismatch" end
    end
    local chunk, err = loadstring(source, "=Scoutware.lua")
    if not chunk then return nil, "compile error: " .. tostring(err) end
    return chunk
end

local function downloadRelease(manifest)
    local source = fetch(BASE .. manifest.source)
    local chunk, err = validateSource(source, manifest.version, manifest.min_bytes)
    if not chunk then return nil, err end
    writeFile(CACHE_FILE, source)
    writeFile(MANIFEST_FILE, "version=" .. manifest.version .. "\n")
    return source, chunk
end

local manifestText = fetch(BASE .. "version.txt")
local manifest = parseManifest(manifestText)
local source, chunk, where

if manifest then
    local localVersion = readLocalVersion()
    local cached = readFile(CACHE_FILE)
    if localVersion == manifest.version then
        chunk = validateSource(cached, manifest.version, manifest.min_bytes)
        if chunk then source, where = cached, "cache" end
    end
    if not chunk then
        local downloaded, downloadedChunk = downloadRelease(manifest)
        if downloaded then source, chunk, where = downloaded, downloadedChunk, "server" end
    end
end

if not chunk then
    source = readFile(CACHE_FILE)
    chunk = validateSource(source, nil, DEFAULT_MIN_BYTES)
    if chunk then where = "offline cache" end
end

if not chunk then
    print("[Scoutware Loader] Error: No valid release or offline cache found!")
    return
end

print(string.format("[Scoutware Loader] Successfully loaded from %s", tostring(where)))
local ok, err = pcall(chunk)
if not ok then print("[Scoutware Loader Error] " .. tostring(err)) end
