local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local UI = {}

function UI.notify(text)
    local notificationText = tostring(text)
    local now = os.clock()
    local env = _G
    if type(getgenv) == "function" then
        local ok, executorEnv = pcall(getgenv)
        if ok and type(executorEnv) == "table" then
            env = executorEnv
        end
    end
    local lastNotification = rawget(env, "__ForestDonationsLastNotification")
    if type(lastNotification) == "table"
        and notificationText == lastNotification.Text
        and now - (tonumber(lastNotification.At) or 0) < 1.5 then
        return false
    end
    rawset(env, "__ForestDonationsLastNotification", {
        Text = notificationText,
        At = now,
    })

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Forest Donations",
            Text = notificationText,
            Duration = 5,
        })
    end)
    return true
end

function UI.create(serverHopPlaceId, savedSettings)
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
        or localPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then
        return nil, "PlayerGui was not available; UI could not be created."
    end

    local oldGui = playerGui:FindFirstChild("ForestDonationsUI")
    if oldGui then
        oldGui:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ForestDonationsUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromOffset(360, 390)
    panel.Position = UDim2.new(0.5, -180, 0.5, -195)
    panel.BackgroundColor3 = Color3.fromRGB(48, 48, 52)
    panel.BorderSizePixel = 0
    panel.Parent = screenGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 42)
    title.BackgroundColor3 = Color3.fromRGB(76, 78, 84)
    title.BorderSizePixel = 0
    title.Text = "Forest Donations"
    title.TextColor3 = Color3.fromRGB(245, 245, 248)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Active = true
    title.Parent = panel
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, 0, 0, 32)
    tabBar.Position = UDim2.fromOffset(0, 42)
    tabBar.BackgroundColor3 = Color3.fromRGB(58, 59, 64)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = panel

    local boothTab = Instance.new("TextButton")
    boothTab.Name = "BoothTab"
    boothTab.Size = UDim2.fromOffset(76, 26)
    boothTab.Position = UDim2.fromOffset(12, 3)
    boothTab.BackgroundColor3 = Color3.fromRGB(96, 99, 108)
    boothTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    boothTab.Text = "Booth"
    boothTab.Font = Enum.Font.GothamBold
    boothTab.TextSize = 13
    boothTab.AutoButtonColor = false
    boothTab.Parent = tabBar
    Instance.new("UICorner", boothTab).CornerRadius = UDim.new(0, 6)

    local serverHopTab = Instance.new("TextButton")
    serverHopTab.Name = "ServerHopTab"
    serverHopTab.Size = UDim2.fromOffset(100, 26)
    serverHopTab.Position = UDim2.fromOffset(96, 3)
    serverHopTab.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    serverHopTab.TextColor3 = Color3.fromRGB(220, 220, 224)
    serverHopTab.Text = "Server Hop"
    serverHopTab.Font = Enum.Font.GothamBold
    serverHopTab.TextSize = 13
    serverHopTab.AutoButtonColor = false
    serverHopTab.Parent = tabBar
    Instance.new("UICorner", serverHopTab).CornerRadius = UDim.new(0, 6)

    local boothPage = Instance.new("Frame")
    boothPage.Name = "BoothPage"
    boothPage.Size = UDim2.new(1, 0, 1, -74)
    boothPage.Position = UDim2.fromOffset(0, 74)
    boothPage.BackgroundTransparency = 1
    boothPage.Parent = panel

    local serverHopPage = Instance.new("Frame")
    serverHopPage.Name = "ServerHopPage"
    serverHopPage.Size = UDim2.new(1, 0, 1, -74)
    serverHopPage.Position = UDim2.fromOffset(0, 74)
    serverHopPage.BackgroundTransparency = 1
    serverHopPage.Visible = false
    serverHopPage.Parent = panel

    local function selectTab(selectedPage, selectedButton, otherPage, otherButton)
        selectedPage.Visible = true
        otherPage.Visible = false
        selectedButton.BackgroundColor3 = Color3.fromRGB(96, 99, 108)
        selectedButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        otherButton.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
        otherButton.TextColor3 = Color3.fromRGB(220, 220, 224)
    end

    boothTab.MouseButton1Click:Connect(function()
        selectTab(boothPage, boothTab, serverHopPage, serverHopTab)
    end)
    serverHopTab.MouseButton1Click:Connect(function()
        selectTab(serverHopPage, serverHopTab, boothPage, boothTab)
    end)

    local dragging = false
    local dragStart
    local panelStart
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            panelStart = panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                panelStart.X.Scale,
                panelStart.X.Offset + delta.X,
                panelStart.Y.Scale,
                panelStart.Y.Offset + delta.Y
            )
        end
    end)

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -24, 0, 24)
    subtitle.Position = UDim2.fromOffset(12, 8)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Claim a Donation Stand"
    subtitle.TextColor3 = Color3.fromRGB(224, 224, 228)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 14
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = boothPage

    local standBox = Instance.new("TextBox")
    standBox.Name = "StandNumber"
    standBox.Size = UDim2.fromOffset(76, 34)
    standBox.Position = UDim2.fromOffset(12, 42)
    standBox.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    standBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    standBox.PlaceholderText = "1 - 27"
    standBox.Text = ""
    standBox.ClearTextOnFocus = false
    standBox.Font = Enum.Font.Gotham
    standBox.TextSize = 14
    standBox.Parent = boothPage
    Instance.new("UICorner", standBox).CornerRadius = UDim.new(0, 6)

    local claimButton = Instance.new("TextButton")
    claimButton.Name = "ClaimButton"
    claimButton.Size = UDim2.fromOffset(200, 34)
    claimButton.Position = UDim2.fromOffset(100, 42)
    claimButton.BackgroundColor3 = Color3.fromRGB(96, 99, 108)
    claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimButton.Text = "Claim & Teleport"
    claimButton.Font = Enum.Font.GothamBold
    claimButton.TextSize = 14
    claimButton.AutoButtonColor = true
    claimButton.Parent = boothPage
    Instance.new("UICorner", claimButton).CornerRadius = UDim.new(0, 6)

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -24, 0, 58)
    status.Position = UDim2.fromOffset(12, 88)
    status.BackgroundTransparency = 1
    status.Text = "Searching for an available stand..."
    status.TextColor3 = Color3.fromRGB(214, 214, 218)
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Parent = boothPage

    local populationSection = Instance.new("Frame")
    populationSection.Name = "PopulationHopperSection"
    populationSection.Size = UDim2.new(1, -24, 0, 124)
    populationSection.Position = UDim2.fromOffset(12, 188)
    populationSection.BackgroundColor3 = Color3.fromRGB(58, 59, 64)
    populationSection.BorderSizePixel = 0
    populationSection.Parent = serverHopPage
    Instance.new("UICorner", populationSection).CornerRadius = UDim.new(0, 8)

    local populationSubtitle = Instance.new("TextLabel")
    populationSubtitle.Name = "PopulationHopSubtitle"
    populationSubtitle.Size = UDim2.new(1, -16, 0, 22)
    populationSubtitle.Position = UDim2.fromOffset(8, 6)
    populationSubtitle.BackgroundTransparency = 1
    populationSubtitle.Text = "Population hopper"
    populationSubtitle.TextColor3 = Color3.fromRGB(224, 224, 228)
    populationSubtitle.Font = Enum.Font.GothamBold
    populationSubtitle.TextSize = 14
    populationSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    populationSubtitle.Parent = populationSection

    local populationThresholdBox = Instance.new("TextBox")
    populationThresholdBox.Name = "PopulationThreshold"
    populationThresholdBox.Size = UDim2.fromOffset(76, 34)
    populationThresholdBox.Position = UDim2.fromOffset(8, 34)
    populationThresholdBox.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    populationThresholdBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    populationThresholdBox.PlaceholderText = "Below #"
    populationThresholdBox.Text = savedSettings
        and tostring(savedSettings.PopulationThreshold) or "10"
    populationThresholdBox.ClearTextOnFocus = false
    populationThresholdBox.Font = Enum.Font.Gotham
    populationThresholdBox.TextSize = 14
    populationThresholdBox.Parent = populationSection
    Instance.new("UICorner", populationThresholdBox).CornerRadius = UDim.new(0, 6)

    local populationHopButton = Instance.new("TextButton")
    populationHopButton.Name = "PopulationHopButton"
    populationHopButton.Size = UDim2.fromOffset(196, 34)
    populationHopButton.Position = UDim2.fromOffset(92, 34)
    populationHopButton.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    populationHopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    populationHopButton.Text = "Population Hop: OFF"
    populationHopButton.Font = Enum.Font.GothamBold
    populationHopButton.TextSize = 13
    populationHopButton.Parent = populationSection
    Instance.new("UICorner", populationHopButton).CornerRadius = UDim.new(0, 6)

    local populationHopStatus = Instance.new("TextLabel")
    populationHopStatus.Name = "PopulationHopStatus"
    populationHopStatus.Size = UDim2.new(1, -16, 0, 42)
    populationHopStatus.Position = UDim2.fromOffset(8, 74)
    populationHopStatus.BackgroundTransparency = 1
    populationHopStatus.Text = "Hops when this server drops below the threshold; destination uses Server Hop Min/Max."
    populationHopStatus.TextColor3 = Color3.fromRGB(214, 214, 218)
    populationHopStatus.Font = Enum.Font.Gotham
    populationHopStatus.TextSize = 12
    populationHopStatus.TextWrapped = true
    populationHopStatus.TextXAlignment = Enum.TextXAlignment.Left
    populationHopStatus.TextYAlignment = Enum.TextYAlignment.Top
    populationHopStatus.Parent = populationSection

    local hopSubtitle = Instance.new("TextLabel")
    hopSubtitle.Size = UDim2.new(1, -24, 0, 24)
    hopSubtitle.Position = UDim2.fromOffset(12, 8)
    hopSubtitle.BackgroundTransparency = 1
    hopSubtitle.Text = ("Find a server in place %d"):format(serverHopPlaceId)
    hopSubtitle.TextColor3 = Color3.fromRGB(224, 224, 228)
    hopSubtitle.Font = Enum.Font.Gotham
    hopSubtitle.TextSize = 13
    hopSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    hopSubtitle.Parent = serverHopPage

    local minPlayersBox = Instance.new("TextBox")
    minPlayersBox.Name = "MinimumPlayers"
    minPlayersBox.Size = UDim2.fromOffset(76, 34)
    minPlayersBox.Position = UDim2.fromOffset(12, 42)
    minPlayersBox.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    minPlayersBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    minPlayersBox.PlaceholderText = "Min"
    minPlayersBox.Text = ""
    minPlayersBox.ClearTextOnFocus = false
    minPlayersBox.Font = Enum.Font.Gotham
    minPlayersBox.TextSize = 14
    minPlayersBox.Parent = serverHopPage
    Instance.new("UICorner", minPlayersBox).CornerRadius = UDim.new(0, 6)

    local maxPlayersBox = Instance.new("TextBox")
    maxPlayersBox.Name = "MaximumPlayers"
    maxPlayersBox.Size = UDim2.fromOffset(76, 34)
    maxPlayersBox.Position = UDim2.fromOffset(96, 42)
    maxPlayersBox.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    maxPlayersBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    maxPlayersBox.PlaceholderText = "Max"
    maxPlayersBox.Text = ""
    maxPlayersBox.ClearTextOnFocus = false
    maxPlayersBox.Font = Enum.Font.Gotham
    maxPlayersBox.TextSize = 14
    maxPlayersBox.Parent = serverHopPage
    Instance.new("UICorner", maxPlayersBox).CornerRadius = UDim.new(0, 6)

    local hopButton = Instance.new("TextButton")
    hopButton.Name = "HopButton"
    hopButton.Size = UDim2.fromOffset(148, 34)
    hopButton.Position = UDim2.fromOffset(184, 42)
    hopButton.BackgroundColor3 = Color3.fromRGB(96, 99, 108)
    hopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    hopButton.Text = "Find & Join"
    hopButton.Font = Enum.Font.GothamBold
    hopButton.TextSize = 14
    hopButton.Parent = serverHopPage
    Instance.new("UICorner", hopButton).CornerRadius = UDim.new(0, 6)

    local autoIntervalBox = Instance.new("TextBox")
    autoIntervalBox.Name = "AutoHopIntervalMinutes"
    autoIntervalBox.Size = UDim2.fromOffset(76, 34)
    autoIntervalBox.Position = UDim2.fromOffset(12, 88)
    autoIntervalBox.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    autoIntervalBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoIntervalBox.PlaceholderText = "Minutes"
    autoIntervalBox.Text = savedSettings and tostring(savedSettings.IntervalMinutes) or "30"
    autoIntervalBox.ClearTextOnFocus = false
    autoIntervalBox.Font = Enum.Font.Gotham
    autoIntervalBox.TextSize = 14
    autoIntervalBox.Parent = serverHopPage
    Instance.new("UICorner", autoIntervalBox).CornerRadius = UDim.new(0, 6)

    local autoHopButton = Instance.new("TextButton")
    autoHopButton.Name = "AutoHopButton"
    autoHopButton.Size = UDim2.fromOffset(148, 34)
    autoHopButton.Position = UDim2.fromOffset(96, 88)
    autoHopButton.BackgroundColor3 = Color3.fromRGB(68, 69, 74)
    autoHopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoHopButton.Text = "Auto Hop: OFF"
    autoHopButton.Font = Enum.Font.GothamBold
    autoHopButton.TextSize = 14
    autoHopButton.Parent = serverHopPage
    Instance.new("UICorner", autoHopButton).CornerRadius = UDim.new(0, 6)

    local hopStatus = Instance.new("TextLabel")
    hopStatus.Name = "ServerHopStatus"
    hopStatus.Size = UDim2.new(1, -24, 0, 58)
    hopStatus.Position = UDim2.fromOffset(12, 132)
    hopStatus.BackgroundTransparency = 1
    hopStatus.Text = "Enter minimum and maximum player counts."
    hopStatus.TextColor3 = Color3.fromRGB(214, 214, 218)
    hopStatus.Font = Enum.Font.Gotham
    hopStatus.TextSize = 13
    hopStatus.TextWrapped = true
    hopStatus.TextXAlignment = Enum.TextXAlignment.Left
    hopStatus.TextYAlignment = Enum.TextYAlignment.Top
    hopStatus.Parent = serverHopPage

    return {
        screenGui = screenGui,
        standBox = standBox,
        claimButton = claimButton,
        status = status,
        populationThresholdBox = populationThresholdBox,
        populationHopButton = populationHopButton,
        populationHopStatus = populationHopStatus,
        minPlayersBox = minPlayersBox,
        maxPlayersBox = maxPlayersBox,
        hopButton = hopButton,
        autoIntervalBox = autoIntervalBox,
        autoHopButton = autoHopButton,
        hopStatus = hopStatus,
    }
end

return UI
