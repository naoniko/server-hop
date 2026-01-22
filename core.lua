repeat task.wait() until game:IsLoaded()

--// ===============================
--// AUTO SERVER HOP (CORE)
--// ===============================

--// SERVICES
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local req = request or http_request or (syn and syn.request)

--// ===============================
--// CONFIG (FROM EXECUTABLE)
--// ===============================
local CFG = getgenv().HOP_CFG
if not CFG then
    warn("HOP_CFG not found. Use executable loader.")
    return
end

local HOP_DELAY = CFG.HopDelay or 300
local POST_COMBAT_COOLDOWN = CFG.PostCombatCooldown or 5
local WEBHOOK_URL = CFG.Webhook

--// ===============================
--// STATE
--// ===============================
local elapsed = 0
local wasInCombat = false
local hopping = false
local lastWebhookState

--// ===============================
--// WEBHOOK (EMBED / COLORFUL)
--// ===============================
local function sendWebhook(title, combatText, color)
    if not req or not WEBHOOK_URL then return end
    if lastWebhookState == title then return end
    lastWebhookState = title

    pcall(function()
        req({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                username = "Auto Server Hop",
                embeds = {{
                    title = title,
                    color = color,
                    fields = {
                        {name = "👤 Player", value = lp.Name, inline = true},
                        {name = "⚔️ Combat", value = combatText, inline = true},
                        {name = "⏱ Hop Delay", value = HOP_DELAY.."s", inline = true},
                        {name = "🗺 PlaceId", value = tostring(game.PlaceId), inline = true},
                        {name = "🆔 JobId", value = string.sub(game.JobId,1,8), inline = true}
                    },
                    footer = { text = "Auto Server Hop" }
                }}
            })
        })
    end)
end

--// ===============================
--// COMBAT DETECTION (BLOX FRUITS)
--// ===============================
local function inCombat()
    local gui = lp:FindFirstChild("PlayerGui")
    if not gui then return false end

    for _,v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextLabel") and v.Visible then
            local t = (v.Text or ""):lower()
            if t:find("combat") or t:find("bounty") or t:find("leave the game") then
                return true
            end
        end
    end
    return false
end

--// ===============================
--// SAFE ZONE (CASTLE ON THE SEA)
--// ===============================
local function tpToCastle()
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return false end
    hrp.CFrame = CFrame.new(1060, 17, 1370)
    task.wait(2)
    return true
end

--// ===============================
--// SERVER FETCH
--// ===============================
local function getServer()
    local data = HttpService:JSONDecode(
        game:HttpGet(
            "https://games.roblox.com/v1/games/"..
            game.PlaceId..
            "/servers/Public?sortOrder=Asc&limit=100"
        )
    )

    for _,s in ipairs(data.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            return s.id
        end
    end
end

--// ===============================
--// START
--// ===============================
sendWebhook("▶ Auto Hop Started", "Not In Combat", 0x3498DB)

--// ===============================
--// MAIN LOOP
--// ===============================
while true do
    task.wait(1)
    elapsed += 1

    if inCombat() then
        elapsed = 0
        if not wasInCombat then
            sendWebhook("⛔ In Combat — Hop Locked", "IN COMBAT", 0xE74C3C)
        end
        wasInCombat = true
        continue
    end

    if wasInCombat then
        sendWebhook("🟢 Combat Ended — Cooldown", "SAFE", 0x2ECC71)
        task.wait(POST_COMBAT_COOLDOWN)
        wasInCombat = false
        elapsed = 0
    end

    if elapsed >= HOP_DELAY and not hopping then
        hopping = true
        elapsed = 0

        sendWebhook("🛡 Moving To Safe Zone", "SAFE", 0xF1C40F)
        tpToCastle()

        local server = getServer()
        if server then
            sendWebhook("🚀 Hopping Server", "SAFE", 0x3498DB)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server, lp)
        end

        hopping = false
    end
end
