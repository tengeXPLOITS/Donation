local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local PLACE_ID = 6136825413
local SEARCH_MIN = 1
local SEARCH_MAX = 25
local DEFAULT_MIN_PLAYERS = 20

local player = Players.LocalPlayer
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)

if not success or not Rayfield then
    warn("Rayfield failed to load, idk why")
    return
end

local window = Rayfield:CreateWindow({
    name = "Donation Hub",
    subtitle = "Rayfield UI",
    color = Color3.fromRGB(60, 120, 220),
})

local mainTab = window:CreateTab({ name = "Main", icon = 0 })
local settingsTab = window:CreateTab({ name = "Settings", icon = 0 })

local state = {
    autoWalk = true,
    autoHop = true,
    hopTimer = 20,
    minPlayers = DEFAULT_MIN_PLAYERS,
    webhookUrl = "",
}

local function getServerPlayerCount()
    local count = 0
    for _ in ipairs(Players:GetPlayers()) do
        count += 1
    end
    return count
end

local function postWebhook(message)
    if not state.webhookUrl or state.webhookUrl == "" then
        return
    end

    pcall(function()
        HttpService:PostAsync(state.webhookUrl, HttpService:JSONEncode({ content = message }))
    end)
end

local function getStandEntries()
    local standFolder = workspace:FindFirstChild("Stands")
    if not standFolder then
        return {}
    end

    local entries = {}
    for _, child in ipairs(standFolder:GetChildren()) do
        if child:IsA("Model") then
            local sign = child:FindFirstChild("sign")
            if sign and sign:IsA("Model") then
                local proximity = sign:FindFirstChild("Proximity")
                if proximity and proximity:IsA("BasePart") then
                    local ownerValue = proximity:FindFirstChild("Owner")
                    local attachment = proximity:FindFirstChild("Attachment")
                    local prompt = attachment and attachment:FindFirstChildOfClass("ProximityPrompt")
                    if not prompt then
                        prompt = proximity:FindFirstChildOfClass("ProximityPrompt")
                    end

                    local ownerText = ""
                    local isOwned = false
                    if ownerValue and ownerValue:IsA("StringValue") then
                        ownerText = tostring(ownerValue.Value or "")
                        isOwned = ownerText ~= ""
                    end

                    table.insert(entries, {
                        model = child,
                        proximity = proximity,
                        ownerValue = ownerValue,
                        ownerText = ownerText,
                        prompt = prompt,
                        isOwned = isOwned,
                    })
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.isOwned ~= b.isOwned then
            return not a.isOwned
        end
        return tostring(a.model.Name) < tostring(b.model.Name)
    end)

    return entries
end

local function findBestStand()
    local entries = getStandEntries()
    if #entries == 0 then
        return nil
    end

    for _, entry in ipairs(entries) do
        if not entry.isOwned then
            return entry
        end
    end

    return entries[1]
end

local function claimBestStand()
    local standEntry = findBestStand()
    if not standEntry then
        window:Notify({ title = "Donation Hub", content = "No stands found in the Stands folder." })
        return false
    end

    if standEntry.isOwned then
        window:Notify({ title = "Donation Hub", content = string.format("%s is already owned by %s.", tostring(standEntry.model.Name), standEntry.ownerText ~= "" and standEntry.ownerText or "someone") })
        return false
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    if humanoid and rootPart and standEntry.proximity then
        local success = pcall(function()
            local targetPosition = standEntry.proximity.Position
            if humanoid and humanoid:IsA("Humanoid") then
                humanoid:MoveTo(targetPosition)
            end
            task.wait(0.4)
        end)

        if not success then
            warn("Failed to move player to stand")
        end
    end

    if standEntry.prompt then
        local ok = pcall(function()
            standEntry.prompt.Enabled = true
            standEntry.prompt:InputHoldBegin()
            standEntry.prompt:InputHoldEnd()
        end)
        if ok then
            window:Notify({ title = "Donation Hub", content = string.format("Claimed %s.", tostring(standEntry.model.Name)) })
            return true
        end
    end

    window:Notify({ title = "Donation Hub", content = string.format("Found %s but the prompt could not be triggered.", tostring(standEntry.model.Name)) })
    return false
end

local function findTargetServer()
    local baseUrl = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", PLACE_ID)
    local cursor = nil

    for _ = 1, 8 do
        local url = baseUrl
        if cursor then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end

        local ok, res = pcall(function()
            return HttpService:GetAsync(url)
        end)
        if not ok then
            break
        end

        local success, decoded = pcall(function()
            return HttpService:JSONDecode(res)
        end)
        if not success or type(decoded) ~= "table" then
            break
        end

        if type(decoded.data) == "table" then
            for _, server in ipairs(decoded.data) do
                local playing = tonumber(server.playing) or 0
                local id = server.id
                if id and playing >= SEARCH_MIN and playing <= SEARCH_MAX and tostring(id) ~= tostring(game.JobId) then
                    return tostring(id), playing
                end
            end
        end

        cursor = decoded.nextPageCursor
        if not cursor then
            break
        end
    end

    return nil
end

local function queueHop()
    if not state.autoHop then
        window:Notify({ title = "Donation Hub", content = "Auto Hop is disabled." })
        return false
    end

    local currentCount = getServerPlayerCount()
    if currentCount >= state.minPlayers then
        window:Notify({ title = "Donation Hub", content = string.format("Server has %d players, no hop needed.", currentCount) })
        return false
    end

    local targetId, targetCount = findTargetServer()
    if targetId then
        postWebhook(string.format("%s is hopping to a server with %d players.", player.Name, targetCount))
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, targetId, { player }, {
                autoWalk = state.autoWalk,
                autoHop = state.autoHop,
                hopTimer = state.hopTimer,
                minPlayers = state.minPlayers,
                webhookUrl = state.webhookUrl,
            })
        end)
        return true
    end

    pcall(function()
        TeleportService:Teleport(PLACE_ID, player)
    end)
    return true
end

local function startHopLoop()
    while true do
        if state.autoHop then
            local currentCount = getServerPlayerCount()
            if currentCount < state.minPlayers then
                for countdown = state.hopTimer, 1, -1 do
                    if not state.autoHop then
                        break
                    end
                    task.wait(1)
                end

                if state.autoHop then
                    queueHop()
                end
            end
        end
        task.wait(1)
    end
end

mainTab:CreateButton({
    name = "Hop Now",
    callback = function()
        task.spawn(function()
            queueHop()
        end)
    end,
})

mainTab:CreateButton({
    name = "Claim Best Unowned Stand",
    callback = function()
        task.spawn(function()
            claimBestStand()
        end)
    end,
})

mainTab:CreateToggle({
    name = "Auto Walk",
    callback = function(value)
        state.autoWalk = value
    end,
})

mainTab:CreateToggle({
    name = "Auto Hop",
    callback = function(value)
        state.autoHop = value
    end,
})

settingsTab:CreateInput({
    name = "Hop timer (seconds)",
    placeholder = "20",
    callback = function(text)
        local newValue = tonumber(text)
        if newValue then
            state.hopTimer = math.max(5, math.floor(newValue))
        else
            state.hopTimer = 20
        end
    end,
})

settingsTab:CreateInput({
    name = "Min players",
    placeholder = tostring(DEFAULT_MIN_PLAYERS),
    callback = function(text)
        local newValue = tonumber(text)
        if newValue then
            state.minPlayers = math.max(1, math.floor(newValue))
        else
            state.minPlayers = DEFAULT_MIN_PLAYERS
        end
    end,
})

settingsTab:CreateInput({
    name = "Webhook URL",
    placeholder = "https://discord.com/api/webhooks/...",
    callback = function(text)
        state.webhookUrl = text or ""
    end,
})

task.spawn(startHopLoop)

window:Notify({
    title = "Donation Hub",
    content = "Rayfield donation UI loaded.",
    duration = 5,
})

