repeat task.wait() until game:IsLoaded()

-- READ CONFIG FROM EXECUTOR
local CFG = getgenv().HOP_CFG
if not CFG then
    warn("HOP_CFG missing")
    return
end

-- SERVICES
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local req = request or http_request or (syn and syn.request)

-- SESSION ID (for webhook clarity)
getgenv().HOP_SESSION = getgenv().HOP_SESSION
    or (os.time() .. "-" .. math.random(1000,9999))

-- STATS (BEST POSSIBLE PERSISTENCE)
getgenv().HOP_STATS = getgenv().HOP_STATS or {
    Attempts = 0,
    Success = 0,
    Fail = 0,
    Retries = 0
}

-- CORE LOAD LOG FLAG (ANTI-SPAM)
getgenv().CORE_LOGGED = getgenv().CORE_LOGGED or false

-- WEBHOOK LOGGER
local function log(msg, emoji)
    if not CFG.Webhook or CFG.Webhook == "" or not req then return end
    pcall(function()
        req({
            Url = CFG.Webhook,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({
                username = "Server Hopper",
                content =
                    emoji.." "..msg..
                    "\n🧠 Session: "..getgenv().HOP_SESSION..
                    "\n👤 Player: "..player.Name..
                    "\n🔁 Attempts: "..getgenv().HOP_STATS.Attempts..
                    "\n✅ Success: "..getgenv().HOP_STATS.Success..
                    "\n❌ Fail: "..getgenv().HOP_STATS.Fail..
                    "\n🔄 Retries: "..getgenv().HOP_STATS.Retries..
                    "\n🆔 Server: "..string.sub(game.JobId,1,8)
            })
        })
    end)
end

-- LOG CORE LOAD ONLY ONCE
if not getgenv().CORE_LOGGED then
    log("Core loaded. Hop every "..CFG.HopDelay.."s", "▶️")
    getgenv().CORE_LOGGED = true
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
    getgenv().HOP_STATS.Attempts += 1

    local id = getServer()
    if id then
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(
                game.PlaceId,
                id,
                player
            )
        end)

        if ok then
            getgenv().HOP_STATS.Success += 1
            log("Hop success", "✅")
            task.wait(10)
        else
            getgenv().HOP_STATS.Fail += 1
            getgenv().HOP_STATS.Retries += 1
            log("Teleport failed", "❌")
            task.wait(CFG.RetryDelay)
        end
    else
        getgenv().HOP_STATS.Fail += 1
        getgenv().HOP_STATS.Retries += 1
        log("No server found", "⚠️")
        task.wait(CFG.RetryDelay)
    end
end
