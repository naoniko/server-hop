repeat task.wait() until game:IsLoaded()

local CFG = getgenv().HOP_CFG
if not CFG then warn("HOP_CFG missing") return end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local req = request or http_request or (syn and syn.request)

-- ===== PLACE / DELAY =====
local PLACE_ID = game.PlaceId
local HopDelay =
    (CFG.GameHopDelay and CFG.GameHopDelay[PLACE_ID])
    or (CFG.GameHopDelay and CFG.GameHopDelay.Default)
    or 30

-- Blox Fruits places
local BLOX_FRUITS = {
    [2753915549] = true,
    [4442272183] = true,
    [7449423635] = true
}

local isBloxFruits = BLOX_FRUITS[PLACE_ID] == true

-- ===== WEBHOOK (STATE ONLY) =====
local lastState
local function logState(msg, emoji)
    if lastState == msg then return end
    lastState = msg

    print("[ServerHop]", msg)

    if not CFG.Webhook or not req then return end
    pcall(function()
        req({
            Url = CFG.Webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                username = "Server Hopper",
                content =
                    emoji.." "..msg..
                    "\n👤 "..player.Name..
                    "\n🌍 PlaceId: "..PLACE_ID..
                    "\n🆔 Server: "..string.sub(game.JobId,1,8)..
                    "\n⏱ Delay: "..HopDelay.."s"
            })
        })
    end)
end

-- ===== COMBAT CHECK (BLOX FRUITS ONLY) =====
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

    if not ok or not data or not data.data then return nil end

    for _,s in ipairs(data.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            return s.id
        end
    end
end

-- ===== MAIN LOOP =====
logState("Auto Hop Active", "▶️")

local elapsed = 0
local lastTick = os.clock()
local wasInCombat = false

while true do
    task.wait(1)

    local now = os.clock()
    local delta = now - lastTick
    lastTick = now

    if inCombat() then
        if not wasInCombat then
            logState("Paused — In Combat", "⏸️")
            wasInCombat = true
        end
        -- DO NOT advance timer
        continue
    end

    if wasInCombat then
        logState("Combat Cleared — Resuming in 5s", "▶️")
        task.wait(5)
        lastTick = os.clock()
        wasInCombat = false
    end

    elapsed += delta

    if elapsed >= HopDelay then
        elapsed = 0

        local id = getServer()
        if id then
            logState("Hopping Server", "🚀")
            TeleportService:TeleportToPlaceInstance(
                PLACE_ID,
                id,
                player
            )
            task.wait(10)
        else
            logState("No Server Found — Retrying", "⚠️")
            task.wait(CFG.RetryDelay)
        end
    end
end
