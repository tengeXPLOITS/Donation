local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local PLACE_ID = 6136825413
local SEARCH_MIN = 19
local SEARCH_MAX = 23
local DEFAULT_MIN_PLAYERS = 13
local DEFAULT_HOP_TIMER = 10

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
local serverHopTab = window:CreateTab({ name = "Server Hop", icon = 0 })
local settingsTab = window:CreateTab({ name = "Settings", icon = 0 })

local state = {
    autoWalk = true,
    autoHop = true,
    hopTimer = DEFAULT_HOP_TIMER,
    minPlayers = DEFAULT_MIN_PLAYERS,
    webhookUrl = "",
    hopCount = 1,
    suppressHopUntil = 0,
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

local function getStandFolder()
    local found = workspace:FindFirstChild("Stands")
    if found then
        return found
    end

    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("Folder") and descendant.Name == "Stands" then
            return descendant
        end
    end

    return nil
end

local function findStandProximity(model)
    local candidates = {}
    if model:IsA("BasePart") then
        table.insert(candidates, model)
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(candidates, descendant)
        end
    end

    for _, candidate in ipairs(candidates) do
        local ownerValue = candidate:FindFirstChild("Owner")
        local prompt = candidate:FindFirstChildOfClass("ProximityPrompt")
        if ownerValue or prompt then
            return candidate, ownerValue, prompt
        end
    end

    return nil
end

local function getStandEntries()
    local standFolder = getStandFolder()
    if not standFolder then
        return {}
    end

    local entries = {}
    for _, child in ipairs(standFolder:GetChildren()) do
        local index = tonumber(child.Name)
        if child:IsA("Model") and index and index >= 1 and index <= 30 then
            local proximity, ownerValue, prompt = findStandProximity(child)
            if proximity then
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

    table.sort(entries, function(a, b)
        if a.isOwned ~= b.isOwned then
            return not a.isOwned
        end
        return tonumber(a.model.Name or 0) < tonumber(b.model.Name or 0)
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
    local targetPosition = standEntry.proximity and standEntry.proximity.Position or nil

    if rootPart and targetPosition then
        pcall(function()
            rootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 4, 0))
        end)
    end

    if humanoid and rootPart and standEntry.proximity then
        pcall(function()
            if humanoid and humanoid:IsA("Humanoid") then
                humanoid:MoveTo(targetPosition)
            end
            task.wait(0.2)
        end)
    end

    if standEntry.prompt then
        local ok = pcall(function()
            standEntry.prompt.Enabled = true
            standEntry.prompt:InputHoldBegin()
            standEntry.prompt:InputHoldEnd()
        end)
        if ok then
            state.suppressHopUntil = os.clock() + 20
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

local function queueHop(force)
    if not state.autoHop and not force then
        return false
    end

    if os.clock() < state.suppressHopUntil then
        return false
    end

    local currentCount = getServerPlayerCount()
    if not force and currentCount >= state.minPlayers then
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
                    queueHop(false)
                end
            end
        end
        task.wait(1)
    end
end

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

serverHopTab:CreateButton({
    name = "Hop Now",
    callback = function()
        task.spawn(function()
            queueHop(true)
        end)
    end,
})

serverHopTab:CreateToggle({
    name = "Auto Hop",
    callback = function(value)
        state.autoHop = value
    end,
})

serverHopTab:CreateSlider({
    name = "Hop timer (seconds)",
    min = 1,
    max = 30,
    value = DEFAULT_HOP_TIMER,
    callback = function(value)
        state.hopTimer = math.max(1, math.floor(value))
    end,
})

serverHopTab:CreateSlider({
    name = "Hop below players",
    min = 1,
    max = 25,
    value = DEFAULT_MIN_PLAYERS,
    callback = function(value)
        state.minPlayers = math.max(1, math.floor(value))
    end,
})

serverHopTab:CreateSlider({
    name = "Hops per action",
    min = 1,
    max = 30,
    value = 1,
    callback = function(value)
        state.hopCount = math.max(1, math.floor(value))
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

