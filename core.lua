repeat task.wait() until game:IsLoaded()

-- ===== CONFIG =====
local CFG = getgenv().HOP_CFG
if not CFG then warn("HOP_CFG missing") return end

-- ===== SERVICES =====
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local req = request or http_request or (syn and syn.request)

-- ===== CONSTANTS =====
local PLACE_ID = game.PlaceId
local HOP_DELAY = CFG.HopDelay or 300
local RETRY_DELAY = CFG.RetryDelay or 5

local BLOX_FRUITS = {
    [2753915549] = true,
    [4442272183] = true,
    [7449423635] = true
}
local isBloxFruits = BLOX_FRUITS[PLACE_ID] == true

-- ===== WEBHOOK =====
local lastLog
local function webhook(msg, emoji)
    if msg == lastLog then return end
    lastLog = msg

    print("[ServerHop]", msg)

    if not CFG.Webhook or not req then return end
    pcall(function()
        req({
            Url = CFG.Webhook,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({
                username = "Auto Server Hop",
                content =
                    emoji.." "..msg..
                    "\n👤 "..player.Name..
                    "\n🆔 "..string.sub(game.JobId,1,8)..
                    "\n⏱ Delay: "..HOP_DELAY.."s"
            })
        })
    end)
end

-- ===== COMBAT DETECTION (BLOX FRUITS) =====
local function inCombat()
    if not isBloxFruits then return false end
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end

    for _,v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local t = v.Text or ""
            if t:find("Combat")
            or t:find("Bounty")
            or t:find("leave the game") then
                return true
            end
        end
    end
    return false
end

-- ===== SAFE ZONE (CASTLE) =====
local function teleportToSafeZone()
    if not isBloxFruits then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Castle on the Sea coords (safe)
    hrp.CFrame = CFrame.new(1060, 17, 1370)
end

-- ===== SERVER FETCH =====
local function getServer()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet(
                "https://games.roblox.com/v1/games/"..
                PLACE_ID..
                "/servers/Public?sortOrder=Asc&limit=100"
            )
        )
    end)
    if not ok or not data or not data.data then return end

    for _,s in ipairs(data.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            return s.id
        end
    end
end

-- ===== TELEPORT FIREWALL (BLOCK ALL OTHER SCRIPTS) =====
local rawTeleport = TeleportService.TeleportToPlaceInstance
local teleportLock = false

TeleportService.TeleportToPlaceInstance = function(self, placeId, jobId, plr, ...)
    if teleportLock then return end

    if isBloxFruits then
        if inCombat() then
            webhook("External Hop BLOCKED — In Combat", "⛔")
            return
        end

        teleportLock = true
        webhook("External Hop Intercepted — Moving to Safe Zone", "🛡️")
        teleportToSafeZone()
        task.wait(2)
        teleportLock = false
    end

    webhook("Allowing Server Hop", "🚀")
    return rawTeleport(self, placeId, jobId, plr, ...)
end

-- ===== MAIN TIMER =====
webhook("Auto Hop Active", "▶️")

local elapsed = 0
local last = os.clock()
local wasInCombat = false

while true do
    task.wait(1)

    local now = os.clock()
    elapsed += (now - last)
    last = now

    if inCombat() then
        wasInCombat = true
        webhook("Paused — In Combat", "⏸️")
        elapsed = 0
        continue
    end

    if wasInCombat then
        webhook("Combat Cleared — Waiting 5s", "🕒")
        task.wait(5)
        elapsed = 0
        wasInCombat = false
    end

    if elapsed >= HOP_DELAY then
        elapsed = 0
        local server = getServer()
        if server then
            webhook("Hopping Server", "🚀")
            TeleportService:TeleportToPlaceInstance(
                PLACE_ID,
                server,
                player
            )
            task.wait(10)
        else
            webhook("No Server Found — Retrying", "⚠️")
            task.wait(RETRY_DELAY)
        end
    end
end
