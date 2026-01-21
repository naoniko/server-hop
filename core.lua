repeat task.wait() until game:IsLoaded()

local CFG = getgenv().HOP_CFG
if not CFG or not CFG.HopDelay then
    warn("HOP_CFG or HopDelay missing")
    return
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local req = request or http_request or (syn and syn.request)

local PLACE_ID = game.PlaceId
local HOP_DELAY = CFG.HopDelay

-- Blox Fruits place IDs
local BLOX_FRUITS = {
    [2753915549] = true,
    [4442272183] = true,
    [7449423635] = true
}

local isBloxFruits = BLOX_FRUITS[PLACE_ID] == true

-- ===== WEBHOOK =====
local lastMsg
local function webhook(msg, emoji)
    if lastMsg == msg then return end
    lastMsg = msg

    print("[ServerHop]", msg)

    if not CFG.Webhook or not req then return end
    pcall(function()
        req({
            Url = CFG.Webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                username = "Server Hopper",
                embeds = {{
                    title = emoji.." "..msg,
                    fields = {
                        {name="Player", value=player.Name, inline=true},
                        {name="PlaceId", value=tostring(PLACE_ID), inline=true},
                        {name="JobId", value=string.sub(game.JobId,1,8), inline=true},
                        {name="Hop Delay", value=HOP_DELAY.."s", inline=true}
                    },
                    footer = {text="Auto Server Hop"}
                }}
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
            if t:lower():find("combat")
            or t:lower():find("bounty")
            or t:lower():find("leave the game") then
                return true
            end
        end
    end
    return false
end

-- ===== GET SERVER =====
local function getServer()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet(
                "https://games.roblox.com/v1/games/"..
                PLACE_ID..
                "/servers/Public?limit=100"
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
webhook("Auto Hop Started", "▶️")

local elapsed = 0
local last = os.clock()

while true do
    task.wait(1)

    local now = os.clock()
    local delta = now - last
    last = now

    if inCombat() then
        webhook("Paused — In Combat", "⏸️")
        continue
    end

    elapsed += delta

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
            webhook("No Server Found — Retry", "⚠️")
            task.wait(CFG.RetryDelay)
        end
    end
end
