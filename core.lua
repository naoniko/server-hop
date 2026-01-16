repeat task.wait() until game:IsLoaded()

-- CONFIG
local CFG = getgenv().HOP_CFG
if not CFG then return warn("HOP_CFG missing") end

-- SERVICES
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local req = request or http_request or (syn and syn.request)

-- LOAD STATS FROM TELEPORT (PERSIST ACROSS HOPS)
local stats = TeleportService:GetTeleportSetting("HOP_STATS") or {
    Attempts = 0,
    Success = 0,
    Fail = 0,
    Retries = 0
}

-- SESSION ID (PERSISTED)
local SESSION = TeleportService:GetTeleportSetting("HOP_SESSION")
if not SESSION then
    SESSION = os.time() .. "-" .. math.random(1000,9999)
    TeleportService:SetTeleportSetting("HOP_SESSION", SESSION)
end

-- SAVE STATS BACK
local function saveStats()
    TeleportService:SetTeleportSetting("HOP_STATS", stats)
end

-- WEBHOOK
local function log(msg, emoji)
    if not CFG.Webhook or not req then return end
    pcall(function()
        req({
            Url = CFG.Webhook,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({
                username = "Server Hopper",
                content =
                    emoji.." "..msg..
                    "\n🧠 Session: "..SESSION..
                    "\n👤 Player: "..player.Name..
                    "\n🔁 Attempts: "..stats.Attempts..
                    "\n✅ Success: "..stats.Success..
                    "\n❌ Fail: "..stats.Fail..
                    "\n🔄 Retries: "..stats.Retries..
                    "\n🆔 Server: "..string.sub(game.JobId,1,8)
            })
        })
    end)
end

-- LOG CORE LOAD ONLY ONCE
if not TeleportService:GetTeleportSetting("CORE_LOGGED") then
    log("Core loaded. Hop every "..CFG.HopDelay.."s", "▶️")
    TeleportService:SetTeleportSetting("CORE_LOGGED", true)
end

-- GET SERVER
local function getServer()
    local url =
        "https://games.roblox.com/v1/games/"..
        game.PlaceId..
        "/servers/Public?sortOrder=Asc&limit=100"

    local data = HttpService:JSONDecode(game:HttpGet(url))
    for _, s in ipairs(data.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            return s.id
        end
    end
end

-- MAIN LOOP
while true do
    task.wait(CFG.HopDelay)
    stats.Attempts += 1
    saveStats()

    local id = getServer()
    if id then
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, id, player)
        end)

        if ok then
            stats.Success += 1
            saveStats()
            log("Hop success", "✅")
            task.wait(10)
        else
            stats.Fail += 1
            stats.Retries += 1
            saveStats()
            log("Teleport failed", "❌")
            task.wait(CFG.RetryDelay)
        end
    else
        stats.Fail += 1
        stats.Retries += 1
        saveStats()
        log("No server found", "⚠️")
        task.wait(CFG.RetryDelay)
    end
end
