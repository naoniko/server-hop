repeat task.wait() until game:IsLoaded()

local CFG = getgenv().HOP_CFG
if not CFG then warn("HOP_CFG missing") return end

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local req = request or http_request or (syn and syn.request)

-- SESSION ID (for logs)
getgenv().HOP_SESSION = getgenv().HOP_SESSION or (os.time() .. "-" .. math.random(1000,9999))

-- Stats (local only)
local stats = {
    Attempts = 0,
    Success = 0,
    Fail = 0,
    Retries = 0
}

-- Logging helper (prints + webhook)
local function log(msg, emoji)
    print("[Server Hop] "..msg)
    if not CFG.Webhook or CFG.Webhook == "" or not req then return end
    pcall(function()
        req({
            Url = CFG.Webhook,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({
                username = "Server Hopper",
                content = emoji.." "..msg..
                    "\n🧠 Session: "..getgenv().HOP_SESSION..
                    "\n👤 Player: "..player.Name..
                    "\n🆔 Server: "..string.sub(game.JobId,1,8)
            })
        })
    end)
end

-- Initial log on load
local loggedNormalHop = false
local loggedCombatPause = false
local loggedCombatResume = false

if not loggedNormalHop then
    log("Auto Hop Active (no combat)", "▶️")
    loggedNormalHop = true
end

-- Check if bounty/combat warning active
local function isBountyActive()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end

    for _, child in ipairs(gui:GetDescendants()) do
        if child:IsA("TextLabel") then
            local txt = child.Text or ""
            if txt:find("In Combat") or txt:find("Bounty at Risk") or txt:find("leave the game") then
                return true
            end
        end
    end
    return false
end

-- Get server function
local function getServer()
    local data
    local ok = pcall(function()
        local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        data = HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not data or not data.data then
        return nil
    end

    for _, s in ipairs(data.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            return s.id
        end
    end
end

while true do
    -- Wait with combat check & 5s delay after combat ends
    local waited = 0
    local hopReady = false
    local inCombatLogged = false

    while not hopReady do
        task.wait(1)
        waited += 1

        if isBountyActive() then
            if not inCombatLogged then
                log("Auto Hop Paused (in combat, waiting...)", "⏸️")
                inCombatLogged = true
                loggedNormalHop = false
                loggedCombatResume = false
            end
            waited = 0 -- reset timer while in combat
        else
            if inCombatLogged and not loggedCombatResume then
                log("Combat cleared, resuming hops in 5 seconds...", "▶️")
                loggedCombatResume = true
            end
            if waited >= 5 then
                hopReady = true
                inCombatLogged = false
            end
        end
    end

    if not loggedNormalHop then
        log("Auto Hop Active (no combat)", "▶️")
        loggedNormalHop = true
        loggedCombatPause = false
        loggedCombatResume = false
    end

    stats.Attempts += 1

    local id = getServer()
    if id then
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, id, player)
        end)

        if ok then
            stats.Success += 1
            -- Wait 10 seconds after teleport before continuing
            task.wait(10)
        else
            stats.Fail += 1
            stats.Retries += 1
            log("Teleport failed: "..tostring(err), "❌")
            task.wait(CFG.RetryDelay)
        end
    else
        stats.Fail += 1
        stats.Retries += 1
        log("No server found, retrying...", "⚠️")
        task.wait(CFG.RetryDelay)
    end
end
