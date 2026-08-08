local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    webhookUrl = "",
    claimInProgress = false,
}

local function getServerPlayerCount()
    local count = 0
    for _ in ipairs(Players:GetPlayers()) do
        count += 1
    end
    return count
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
        local prompt = candidate:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            return candidate, nil, prompt
        end
    end

    for _, candidate in ipairs(candidates) do
        local ownerValue = candidate:FindFirstChild("Owner")
        if ownerValue then
            return candidate, ownerValue, nil
        end
    end

    return candidates[1], nil, nil
end

local function getOwnerInfo(container)
    local ownerValue = nil
    local ownerText = ""

    local function scan(obj)
        if not obj then
            return
        end

        if obj.Name == "Owner" then
            ownerValue = obj
            if obj:IsA("StringValue") then
                ownerText = tostring(obj.Value or "")
            elseif obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("BoolValue") then
                ownerText = tostring(obj.Value or "")
            elseif obj:IsA("ObjectValue") then
                ownerText = obj.Value and tostring(obj.Value) or ""
            end
            return true
        end

        for _, child in ipairs(obj:GetChildren()) do
            if scan(child) then
                return true
            end
        end

        return false
    end

    scan(container)

    local normalized = string.lower(tostring(ownerText or ""))
    local isNoOne = normalized == "none" or normalized == "noone" or normalized == "" or normalized == "nil"
    local isOwned = ownerValue ~= nil and not isNoOne
    return ownerValue, ownerText, isOwned, isNoOne
end

local function getStandEntries()
    local standFolder = getStandFolder()
    if not standFolder then
        return {}
    end

    local entries = {}
    local function scan(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") then
                local index = tonumber(child.Name)
                if index and index >= 1 and index <= 30 then
                    local proximity, ownerValue, prompt = findStandProximity(child)
                    if proximity then
                        local _, ownerText, isOwned, isNoOne = getOwnerInfo(child)
                        table.insert(entries, {
                            model = child,
                            proximity = proximity,
                            ownerValue = ownerValue,
                            ownerText = ownerText,
                            prompt = prompt,
                            isOwned = isOwned,
                            isNoOne = isNoOne,
                        })
                    end
                end
            end

            if child:IsA("Folder") or child:IsA("Model") or child:IsA("BasePart") then
                scan(child)
            end
        end
    end

    scan(standFolder)

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
        if entry.isNoOne then
            return entry
        end
    end

    for _, entry in ipairs(entries) do
        if not entry.isOwned then
            return entry
        end
    end

    return entries[1]
end

local function triggerEditPlotClaim(standName)
    local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
    if not eventsFolder then
        return false
    end

    local editPlotEvent = eventsFolder:FindFirstChild("EditPlot")
    if not editPlotEvent or not editPlotEvent:IsA("RemoteEvent") then
        return false
    end

    local ok = pcall(function()
        editPlotEvent:FireServer(tostring(standName), false)
    end)

    return ok
end

local function claimBestStand()
    state.claimInProgress = true

    local standEntry = findBestStand()
    if not standEntry then
        state.claimInProgress = false
        window:Notify({ title = "Donation Hub", content = "No stands found in the Stands folder." })
        return false
    end

    if standEntry.isOwned then
        state.claimInProgress = false
        window:Notify({ title = "Donation Hub", content = string.format("%s is already owned by %s.", tostring(standEntry.model.Name), standEntry.ownerText ~= "" and standEntry.ownerText or "someone") })
        return false
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local targetPosition = standEntry.proximity and standEntry.proximity.Position or nil

    if rootPart and targetPosition then
        local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 4, 0))
        pcall(function()
            if character and character:IsA("Model") then
                character:PivotTo(targetCFrame)
            end
        end)

        pcall(function()
            rootPart.CFrame = targetCFrame
        end)

        if humanoid and humanoid:IsA("Humanoid") then
            pcall(function()
                humanoid:MoveTo(targetPosition)
            end)
        end
    end

    task.wait(0.1)

    local standName = tostring(standEntry.model.Name or "")
    local eventTriggered = triggerEditPlotClaim(standName)
    if eventTriggered then
        state.claimInProgress = false
        window:Notify({ title = "Donation Hub", content = string.format("Triggered claim for %s.", standName) })
        return true
    end

    if standEntry.prompt then
        local ok = pcall(function()
            standEntry.prompt.Enabled = true
            standEntry.prompt:InputHoldBegin()
            standEntry.prompt:InputHoldEnd()
        end)
        if ok then
            state.claimInProgress = false
            window:Notify({ title = "Donation Hub", content = string.format("Claimed %s.", standName) })
            return true
        end
    end

    state.claimInProgress = false
    window:Notify({ title = "Donation Hub", content = string.format("Found %s but the claim event could not be triggered.", standName) })
    return false
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

settingsTab:CreateInput({
    name = "Webhook URL",
    placeholder = "https://discord.com/api/webhooks/...",
    callback = function(text)
        state.webhookUrl = text or ""
    end,
})

window:Notify({
    title = "Donation Hub",
    content = "Rayfield donation UI loaded.",
    duration = 5,
})

