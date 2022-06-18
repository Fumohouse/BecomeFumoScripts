--[[
    !! READ ME !!
    SBF Race Utilities
    voided_etc // 2022

    Designed for KRNL

    How to use:
    1. In the 2C (Checkpoints) tab, you can:
        a. Create a new list of checkpoints:
            i. Press the add button
            ii. Press the button marked "Point 1", which will place one corner of the checkpoint region at your current position.
            iii. Press the button marked "Point 2", which will place the other corner of the checkpoint region at your current position.
            iv. Repeat until you have checkpointed the entire track. "Forward" is indicated by the checkpoints in ascending order.
            - Make sure your checkpoint spans a sufficient amount of the track.
                - If the checkpoint region is too small, **the tracker could miss a player passing a checkpoint.**
        b. Import an existing list of checkpoints:
            i. Place the file into your KRNL workspace folder.
            ii. Type the file name into the "File name" field.
            iii. Press "Load".
            - Make sure you pay attention to the direction of the track. If it is wrong, you need to make the checkpoints yourself.
        c. Save your list of checkpoints: Type the file name and press "Save".
    2. In the 1R (Race) tab:
        a. Indicate how many laps the race should be, and press [ENTER]
        b. Press "Race Active" to begin tracking players.
    3. Once the race is over, go to the 1R tab and press "Export Event Log" to export the log of the entire event to your KRNL workspace.

    Notes:
    - Racers should know that a lap is finished only after they reach all checkpoints, **then reach the first one again.**
        - This means that **they should not stop short of the starting line after finishing.**
    - Racers can miss up to 3 checkpoints and have the lap still counted. This is in order to account for possible network/FPS lag.
        - For this reason, place a sufficient number of checkpoints on the track.
        - If there is contention over the results, check the event log.
    - If a racer goes over 3 checkpoints *backward*, **their entire lap will be invalidated**.
        - For this reason, design the checkpoint layout such that it is difficult to actually do this accidentally.
]]

local BFS = getgenv().BFS

if not BFS then
    loadstring(game:HttpGet(("https://gist.githubusercontent.com/kyoseki/07f37b493f46895e67339e85c223423c/raw/gui.lua"), true))()
    BFS = getgenv().BFS
end

local cDefaultConfig = {
    keybinds = {
        TabRace = Enum.KeyCode.One.Name,
        TabCheckpoints = Enum.KeyCode.Two.Name,
        TabSettings = Enum.KeyCode.Seven.Name,
        HideGui = Enum.KeyCode.F1.Name,
        MapVis = Enum.KeyCode.N.Name,
        MapView = Enum.KeyCode.M.Name,
    },
    mapRenderEverything = false,
}

BFS.Config:mergeDefaults(cDefaultConfig)

version = "1.0.0"

do  -- double load prevention
    if BF_LOADED then
        BFS.log("already loaded!")
        return
    end

    pcall(function()
        getgenv().BF_LOADED = true
    end)

    if not game:IsLoaded() then game.Loaded:Wait() end

    BFS.bindToExit("Free BF_LOADED", function()
        getgenv().BF_LOADED = false
    end)
end -- double load prevention

--
-- services
--

local TweenService = game:GetService("TweenService")
local UserInput = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local huiFolder
if BFS.IsUsingHUI then
    huiFolder = BFS.Root.Parent
end

local LocalPlayer = Players.LocalPlayer

local secondaryRoot = Instance.new("Frame")
secondaryRoot.Size = UDim2.fromScale(1, 1)
secondaryRoot.BackgroundTransparency = 1
secondaryRoot.BorderSizePixel = 0
secondaryRoot.Parent = BFS.Root

--
-- random functions
--

function teleport(pos)
    local char = LocalPlayer.Character
    local hum = char:FindFirstChildOfClass("Humanoid")

    if hum and hum.SeatPart then
        hum.Sit = false
        wait()
    end

    local origPos = char:GetPrimaryPartCFrame()
    char:SetPrimaryPartCFrame(pos)

    return origPos
end

local raceData = {
    active = false,
    checkpoints = {},
    players = {},
    eventLog = {},
    playerCount = 0,
    laps = 0,
}

function raceData:Log(msg)
    self.eventLog[#self.eventLog + 1] = string.format(
        "[%s] %s",
        os.date("%H:%M:%S", os.time()), msg
    )
end

local PlayerData = {}
PlayerData.__index = PlayerData

function PlayerData.new(player, overlayEntry)
    local self = setmetatable({}, PlayerData)

    self.Player = player

    self.Lap = 0
    self.Checkpoint = 0
    self.CheckpointsMissed = 0
    self.Finished = nil

    self.OverlayEntry = overlayEntry

    return self
end

function PlayerData:HandleVisit(checkpoint)
    local lastCheckpoint = self.Checkpoint
    local diff = checkpoint.Index - lastCheckpoint

    if diff > 0 then
        raceData:Log(string.format("Player %s passed checkpoint %d (last visited %d)", self.Player.Name, checkpoint.Index, lastCheckpoint))
        self.CheckpointsMissed += diff - 1
        self.Checkpoint = checkpoint.Index

        return true
    elseif diff < -(math.min(#raceData.checkpoints - 2, 3)) then
        -- Distance from last visited to last checkpoint
        self.CheckpointsMissed += #raceData.checkpoints - lastCheckpoint
        -- Distance from here to the first checkpoint
        self.CheckpointsMissed += checkpoint.Index - 1

        local cMaxMisses = 3

        if self.CheckpointsMissed <= cMaxMisses then
            self.Lap += 1

            raceData:Log(string.format(
                "Player %s completed a lap (total: %d), now on checkpoint %d (last visited %d; missed %d)",
                self.Player.Name, self.Lap, checkpoint.Index, lastCheckpoint, self.CheckpointsMissed
            ))

            if self.Lap == raceData.laps then
                raceData:Log(string.format(
                    "Player %s finished the race!",
                    self.Player.Name
                ))

                self.Finished = tick()
            end
        else
            raceData:Log(string.format(
                "!!! Player %s, now on checkpoint %d, missed %d checkpoints, so a lap was not awarded. !!!",
                self.Player.Name, checkpoint.Index, self.CheckpointsMissed
            ))
        end

        self.Checkpoint = checkpoint.Index
        self.CheckpointsMissed = 0

        return true
    end

    return false
end

function PlayerData:Destroy()
    self.OverlayEntry.Root:Destroy()
end

do  -- race overlay
    local cPlayers = 5

    local cHeaderHeight = 24
    local cPlayerHeight = 30

    local cPadding = 0.05
    local cPlaceWidth = 0.1
    local cPlayerWidth = 0.7
    local cLapWidth = 0.1

    local cBodyHeight = cPlayerHeight * cPlayers

    local raceOverlay = Instance.new("Frame")
    raceOverlay.Size = UDim2.new(0.3, 0, 0, cBodyHeight + cHeaderHeight)
    raceOverlay.AnchorPoint = Vector2.new(1, 1)
    raceOverlay.Position = UDim2.new(1, -30, 1, -30)
    raceOverlay.BackgroundTransparency = 0.3
    raceOverlay.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    raceOverlay.BorderSizePixel = 4
    raceOverlay.BorderColor3 = Color3.new(0.05, 0.05, 0.05)
    raceOverlay.Parent = BFS.Root

    local function createRowText(parent, size)
        local text = BFS.UI.createText(parent, size)
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.TextYAlignment = Enum.TextYAlignment.Center
        text.TextTruncate = Enum.TextTruncate.AtEnd

        return text
    end

    local header = Instance.new("Frame")
    header.BackgroundTransparency = 1
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, cHeaderHeight)
    header.Parent = raceOverlay

    local playerHeader = createRowText(header, 15)
    playerHeader.Position = UDim2.fromScale(cPadding + cPlaceWidth, 0)
    playerHeader.Size = UDim2.fromScale(cPlayerWidth, 1)
    playerHeader.Text = "Player"

    local lapsHeader = createRowText(header, 15)
    lapsHeader.Position = UDim2.fromScale(cPadding + cPlaceWidth + cPlayerWidth, 0)
    lapsHeader.Size = UDim2.fromScale(cLapWidth, 1)
    lapsHeader.Text = "Laps"

    local leaderboardScroll = BFS.UI.createScroll(raceOverlay)
    leaderboardScroll.Size = UDim2.new(1, 0, 0, cBodyHeight)
    leaderboardScroll.AnchorPoint = Vector2.new(0, 1)
    leaderboardScroll.Position = UDim2.fromScale(0, 1)

    function addPlayerToOverlay(player)
        local entryData = {}
        local entry = Instance.new("Frame")
        entry.BackgroundTransparency = 1
        entry.BorderSizePixel = 0
        entry.Size = UDim2.new(1, 0, 0, cPlayerHeight)
        entry.Position = UDim2.fromOffset(0, cPlayerHeight * raceData.playerCount)

        entry.Parent = leaderboardScroll
        entryData.Root = entry

        local x = cPadding

        local place = createRowText(entry, 25)
        place.Position = UDim2.fromScale(x, 0)
        place.Size = UDim2.fromScale(cPlaceWidth, 1)
        place.Text = "#1"

        entryData.Place = place

        x += cPlaceWidth

        local username = createRowText(entry, 20)
        username.Position = UDim2.fromScale(x, 0)
        username.Size = UDim2.fromScale(cPlayerWidth, 1)
        username.Text = player.Name

        x += cPlayerWidth

        local laps = createRowText(entry, 20)
        laps.Position = UDim2.fromScale(x, 0)
        laps.Size = UDim2.fromScale(cLapWidth, 1)
        laps.Text = "0"

        entryData.Laps = laps

        return entryData
    end

    local function partialScore(playerData)
        return playerData.Lap + playerData.Checkpoint / #raceData.checkpoints
    end

    local function finishedComp(a, b)
        return a.Finished < b.Finished
    end

    local function playerComp(a, b)
        return partialScore(a) > partialScore(b)
    end

    local function getColor(playerData, place)
        if playerData.Finished then
            return Color3.fromRGB(46, 199, 4)
        end

        if place == 1 then
            return Color3.fromRGB(255, 215, 0)
        end

        if place == 2 then
            return Color3.fromRGB(192, 192, 192)
        end

        if place == 3 then
            return Color3.fromRGB(165, 113, 100)
        end

        return Color3.new(1, 1, 1)
    end

    function updateOverlay()
        local finishedSorted = {}
        local playersSorted = {}
        for _, playerData in pairs(raceData.players) do
            if playerData.Finished then
                finishedSorted[#finishedSorted + 1] = playerData
            else
                playersSorted[#playersSorted + 1] = playerData
            end
        end

        table.sort(finishedSorted, finishedComp)
        table.sort(playersSorted, playerComp)

        local y = 0
        local place = 1

        local function updatePlayer(playerData)
            playerData.OverlayEntry.Place.Text = "#"..place
            playerData.OverlayEntry.Laps.Text = playerData.Lap

            local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local posTween = TweenService:Create(playerData.OverlayEntry.Root, tweenInfo, {
                Position = UDim2.fromOffset(0, y)
            })

            posTween:Play()

            local colorTween = TweenService:Create(playerData.OverlayEntry.Place, tweenInfo, {
                TextColor3 = getColor(playerData, place)
            })

            colorTween:Play()

            place += 1
            y += cPlayerHeight
        end

        for _, playerData in ipairs(finishedSorted) do
            updatePlayer(playerData)
        end

        for _, playerData in ipairs(playersSorted) do
            updatePlayer(playerData)
        end
    end
end -- race overlay

do  -- race
    local raceTab = BFS.TabControl:createTab("Race", "1R", "TabRace")
    BFS.UI.createListLayout(raceTab, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

    local lapsField = BFS.UI.createTextBox(raceTab, "Total Laps", 24)

    lapsField.FocusLost:Connect(function()
        if lapsField.Text == "" then
            return
        end

        local num = tonumber(lapsField.Text)
        if num then
            raceData.laps = num
        end
    end)

    BFS.UI.createLabelButtonLarge(raceTab, "Race Active", function(setActive)
        raceData.active = not raceData.active
        if raceData.active then
            raceData:Log("Race was marked active.")
        else
            raceData:Log("Race was marked inactive.")
        end
        setActive(raceData.active)
    end)

    BFS.UI.createLabelButtonLarge(raceTab, "Reset Player Data", function()
        for _, player in pairs(raceData.players) do
            player:Destroy()
        end

        raceData.players = {}
        raceData.playerCount = 0
        raceData.eventLog = {}
    end)

    BFS.UI.createLabelButtonLarge(raceTab, "Export Event Log", function()
        local time = os.time()
        local output = string.format(
            "---- Race log, exported %s ----\n\n",
            os.date("%d-%m-%Y at %H:%M:%S (local time)")
        )

        output = output..table.concat(raceData.eventLog, "\n")

        local filename = string.format("race-%s.log", os.date("%d-%m-%y_%H-%M-%S"))
        writefile(filename, output)
    end)

    local function initPlayer(player)
        local playerData = PlayerData.new(player, addPlayerToOverlay(player))
        raceData.players[player] = playerData
        raceData.playerCount += 1

        return playerData
    end

    local lHeartbeat = RunService.Heartbeat:Connect(function()
        if not raceData.active then
            return
        end

        local validCheckpoints = 0
        for _, checkpoint in ipairs(raceData.checkpoints) do
            if checkpoint.Region then
                validCheckpoints += 1
            end
        end

        if validCheckpoints < 2 then
            return
        end

        local whitelist = {}
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character then
                whitelist[#whitelist + 1] = player.Character.PrimaryPart
            end
        end

        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Whitelist
        params.FilterDescendantsInstances = whitelist

        for _, checkpoint in ipairs(raceData.checkpoints) do
            if not checkpoint.Region then
                continue
            end

            local results = workspace:GetPartBoundsInBox(checkpoint.Region.CFrame, checkpoint.Region.Size, params)

            local anyChanged = false

            for _, result in pairs(results) do
                local player = Players:GetPlayerFromCharacter(result.Parent)
                if not player then
                    continue
                end

                local playerData = raceData.players[player]

                if not playerData then
                    playerData = initPlayer(player)
                    updateOverlay()
                end

                anyChanged = playerData:HandleVisit(checkpoint) or anyChanged
            end

            if anyChanged then
                updateOverlay()
            end
        end
    end)

    BFS.bindToExit("Race: Clean up", function()
        for _, checkpoint in pairs(raceData.checkpoints) do
            checkpoint:Cleanup()
        end

        lHeartbeat:Disconnect()
    end)
end -- race

do  -- checkpoints
    local checkpointsTab = BFS.TabControl:createTab("Checkpoints", "2C", "TabCheckpoints")

    local cPadding = 10
    local checkpointsScroll = BFS.UI.createListScroll(checkpointsTab, cPadding)

    local checkpointsFrame = Instance.new("Frame")
    checkpointsFrame.Size = UDim2.new(1, 0, 0, 0)
    checkpointsFrame.BackgroundTransparency = 1
    checkpointsFrame.BorderSizePixel = 0
    checkpointsFrame.AutomaticSize = Enum.AutomaticSize.Y
    BFS.UI.createListLayout(checkpointsFrame, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top, cPadding)

    checkpointsFrame.Parent = checkpointsScroll

    local function updateCheckpoints()
        for idx, checkpoint in ipairs(raceData.checkpoints) do
            checkpoint.Index = idx
            checkpoint:UpdateIndex(idx)
        end
    end

    local function getFootPosition()
        local orientation, size = LocalPlayer.Character:GetBoundingBox()
        return orientation.Position - Vector3.new(0, size.Y / 2, 0)
    end

    local function formatVector(v)
        if not v then
            return "unset"
        end

        return string.format("(%02d, %02d, %02d)", v.X, v.Y, v.Z)
    end

    local function addCheckpoint(point1, point2)
        -- nils for reference
        local checkpoint = {
            Index = nil,
            Root = nil,
            Point1 = point1,
            Point2 = point2,
            Region = nil,
            RegionPart = nil,
            RegionLabel = nil,
        }

        local index = #raceData.checkpoints + 1
        checkpoint.Index = index

        function checkpoint:UpdateRegion()
            local cExpand = Vector3.new(1.0, 1.0, 1.0)

            if not self.Point1 or not self.Point2 then
                return
            end

            local min = Vector3.new(
                math.min(self.Point1.X, self.Point2.X),
                math.min(self.Point1.Y, self.Point2.Y),
                math.min(self.Point1.Z, self.Point2.Z)
            )

            local max = Vector3.new(
                math.max(self.Point1.X, self.Point2.X),
                math.max(self.Point1.Y, self.Point2.Y),
                math.max(self.Point1.Z, self.Point2.Z)
            )

            self.Region = Region3.new(min - cExpand, max + cExpand)

            if not self.RegionPart then
                local part = Instance.new("Part")
                part.Color = Color3.new(1, 1, 1)
                part.CanCollide = false
                part.Transparency = 0.3
                part.Anchored = true
                part.Material = Enum.Material.SmoothPlastic
                part.Parent = workspace

                self.RegionPart = part

                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = part
                billboard.Parent = part
                billboard.Size = UDim2.new(0, 200, 0, 50)

                local text = BFS.UI.createText(billboard, 40)
                text.Text = "C"..self.Index
                text.AutomaticSize = Enum.AutomaticSize.XY
                self.RegionLabel = text
            end

            self.RegionPart.CFrame = self.Region.CFrame
            self.RegionPart.Size = self.Region.Size
        end

        checkpoint:UpdateRegion()

        function checkpoint:Cleanup()
            self.Root:Destroy()
            if self.RegionPart then
                self.RegionPart:Destroy()
            end
        end

        local root = Instance.new("Frame")
        root.Size = UDim2.new(1, 0, 0, 0)
        root.BackgroundTransparency = 1
        root.BorderSizePixel = 0
        root.AutomaticSize = Enum.AutomaticSize.Y
        BFS.UI.createListLayout(root, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

        root.Parent = checkpointsFrame
        checkpoint.Root = root

        local label = BFS.UI.createCategoryLabel(root, "")

        function checkpoint:UpdateIndex(i)
            self.Index = i
            label.Text = "Checkpoint "..i

            if self.RegionLabel then
                self.RegionLabel.Text = "C"..i
            end
        end

        checkpoint:UpdateIndex(index)

        local point1Button
        point1Button = BFS.UI.createLabelButtonLarge(root, "Point 1: "..formatVector(checkpoint.Point1), function()
            checkpoint.Point1 = getFootPosition()
            checkpoint:UpdateRegion()
            point1Button.Label.Text = "Point 1: "..formatVector(checkpoint.Point1)
        end)

        local point2Button
        point2Button = BFS.UI.createLabelButtonLarge(root, "Point 2: "..formatVector(checkpoint.Point2), function()
            checkpoint.Point2 = getFootPosition() + Vector3.new(0, 5, 0)
            checkpoint:UpdateRegion()
            point2Button.Label.Text = "Point 2: "..formatVector(checkpoint.Point2)
        end)

        BFS.UI.createLabelButtonLarge(root, "Delete", function()
            checkpoint:Cleanup()
            table.remove(raceData.checkpoints, checkpoint.Index)
            updateCheckpoints()
        end)

        raceData.checkpoints[index] = checkpoint

        return checkpoint
    end

    BFS.UI.createLabelButtonLarge(checkpointsScroll, "Add", function()
        addCheckpoint()
    end)

    local ioFrame = Instance.new("Frame")
    ioFrame.Size = UDim2.fromScale(1, 0)
    ioFrame.BackgroundTransparency = 1
    ioFrame.BorderSizePixel = 0
    ioFrame.AutomaticSize = Enum.AutomaticSize.Y
    BFS.UI.createListLayout(ioFrame)

    ioFrame.Parent = checkpointsScroll

    local fileNameField = BFS.UI.createTextBox(ioFrame, "File name", 24)

    BFS.UI.createLabelButtonLarge(ioFrame, "Save", function()
        if fileNameField.Text == "" then
            return
        end

        local export = {}

        for _, checkpoint in ipairs(raceData.checkpoints) do
            local point1 = checkpoint.Point1
            local point2 = checkpoint.Point2

            export[#export + 1] = {
                Point1 = point1 and { point1.X, point1.Y, point1.Z },
                Point2 = point2 and { point2.X, point2.Y, point2.Z },
            }
        end

        local encoded = HttpService:JSONEncode(export)
        writefile(fileNameField.Text, encoded)
    end)

    BFS.UI.createLabelButtonLarge(ioFrame, "Load", function()
        if fileNameField.Text == "" then
            return
        end

        raceData.checkpoints = {}

        if not pcall(function() readfile(fileNameField.Text) end) then
            return
        end

        local encoded = readfile(fileNameField.Text)
        for _, checkpoint in ipairs(HttpService:JSONDecode(encoded)) do
            local point1 = checkpoint.Point1
            local point2 = checkpoint.Point2
            addCheckpoint(Vector3.new(point1[1], point1[2], point1[3]), Vector3.new(point2[1], point2[2], point2[3]))
        end
    end)
end -- checkpoints

do  -- settings
    local settingsTab = BFS.TabControl:createTab("Settings", "7S", "TabSettings")

    local settingsScroll = BFS.UI.createListScroll(settingsTab)

    local function createSettingsCategory(name)
        BFS.UI.createCategoryLabel(settingsScroll, name)

        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromScale(1, 0)
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.Parent = settingsScroll

        BFS.UI.createListLayout(frame)

        return frame
    end

    local bindFrame = createSettingsCategory("Keybinds")

    local currentlyBinding = nil
    local listener = nil

    local bindButtons = {}

    local function addBind(name)
        if bindButtons[name] then
            return
        end

        local labelInfo = nil
        local label = nil

        local function getName()
            local bindText = BFS.Binds.Keybinds[name]
            if bindText == -1 then bindText = "NONE" end

            return name.." ("..bindText..")"
        end

        local function stopBinding()
            listener:Disconnect()
            listener = nil

            label.Text = getName()
            labelInfo.SetActive(false)

            wait(0.2)
            BFS.Binds.Disabled = false
            currentlyBinding = nil
        end

        labelInfo = BFS.UI.createLabelButtonLarge(bindFrame, getName(), function(setActive, type)
            if type == Enum.UserInputType.MouseButton1 then
                if currentlyBinding then
                    if currentlyBinding == name then
                        stopBinding()
                    else
                        return
                    end
                else
                    listener = UserInput.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Keyboard and
                            not UserInput:GetFocusedTextBox() then
                            BFS.Binds:rebind(name, input.KeyCode)

                            stopBinding()
                            setActive(false)
                        end
                    end)

                    setActive(true)

                    label.Text = "press a key..."
                    BFS.Binds.Disabled = true
                    currentlyBinding = name
                end
            elseif type == Enum.UserInputType.MouseButton2 then
                BFS.Binds:unbind(name)
                label.Text = getName()
            end
        end)

        label = labelInfo.Label
        bindButtons[name] = labelInfo
    end

    BFS.Binds.BindingsUpdated.Event:Connect(function()
        for key, _ in pairs(BFS.Binds.Keybinds) do
            addBind(key)
        end
    end)

    local cBinds = { "TabRace", "TabCheckpoints", "TabSettings", "HideGui", "MapVis", "MapView", "Exit" }

    for _, v in pairs(cBinds) do
        addBind(v)
    end

    local function addCheckbox(parent, label, field, cb)
        BFS.UI.createCheckbox(parent, label, function(checked)
            BFS.Config.Value[field] = checked
            BFS.Config:save()

            if cb then cb(checked) end
        end, BFS.Config.Value[field])
    end

    local mapFrame = createSettingsCategory("Map Options")

    addCheckbox(mapFrame, "Map Everything", "mapRenderEverything")
end -- settings

do  -- minimap
    local TooltipProvider = {}
    TooltipProvider.__index = TooltipProvider

    -- TooltipObject spec (abstract)
    -- :ShowTooltip (opt) - whether the object should show a tooltip
    -- :CreateTooltip(tp) - create the tooltip
    -- TooltipObject (GuiObject) - the object that, when hovered, should cause a tooltip to appear
    -- :Clicked(input) (opt) - called on click

    function TooltipProvider.new(parent)
        local self = setmetatable({}, TooltipProvider)

        self.Parent = parent

        local tooltipFrame = Instance.new("Frame")
        tooltipFrame.AnchorPoint = Vector2.new(0, 0)
        tooltipFrame.AutomaticSize = Enum.AutomaticSize.XY
        tooltipFrame.BackgroundTransparency = 0.25
        tooltipFrame.BackgroundColor3 = BFS.UIConsts.BackgroundColor
        tooltipFrame.BorderSizePixel = 0
        tooltipFrame.Parent = parent

        self.Focus = nil

        self.Frame = tooltipFrame

        self.Instances = {}
        self.Scale = 1

        return self
    end

    function TooltipProvider:createText(size)
        local text = BFS.UI.createText(self.Frame, size)
        text.AutomaticSize = Enum.AutomaticSize.XY
        text.TextWrapped = false
        text.RichText = true

        return text
    end

    function TooltipProvider:_mouseEnter(obj)
        if obj.ShowTooltip and not obj:ShowTooltip() then return end

        local pos = UserInput:GetMouseLocation()

        if self.Focus ~= obj then
            self.Frame:ClearAllChildren()
            obj:CreateTooltip(self)
        end

        self.Frame.Position = UDim2.fromOffset(pos.X, pos.Y)

        self.Focus = obj
        self.Frame.Visible = true
    end

    function TooltipProvider:_mouseLeave(obj)
        self.Frame:ClearAllChildren()
        self.Frame.Visible = false
        self.Focus = nil
    end

    function TooltipProvider:register(obj)
        if not obj.TooltipObject or not obj.CreateTooltip then return end

        obj.TooltipObject.Active = true

        local info = {}
        info.Object = obj

        info.lEnter = obj.TooltipObject.MouseEnter:Connect(function()
            self:_mouseEnter(obj)
        end)

        info.lMove = obj.TooltipObject.MouseMoved:Connect(function()
            self:_mouseEnter(obj)
        end)

        info.lLeave = obj.TooltipObject.MouseLeave:Connect(function()
            self:_mouseLeave(obj)
        end)

        if obj.Clicked then
            info.lClicked = obj.TooltipObject.InputBegan:Connect(function(input)
                if (not obj.ShowTooltip or obj:ShowTooltip()) and input.UserInputType == Enum.UserInputType.MouseButton1 then
                    obj:Clicked(input)
                end
            end)
        end

        self.Instances[#self.Instances + 1] = info
    end

    function TooltipProvider:deregister(obj)
        for k, v in pairs(self.Instances) do
            if v.Object == obj then
                v.lEnter:Disconnect()
                v.lMove:Disconnect()
                v.lLeave:Disconnect()
                if v.lClicked then
                    v.lClicked:Disconnect()
                end

                self.Instances[k] = nil

                break
            end
        end
    end

    -- MapObject spec (abstract)
    -- constructor should contain minimap as first param
    -- Map - Minimap: the map the object is assigned to
    -- Root - GuiObject: the parent element of all other components of this MapObject
    -- UpdateSize(scaleFactor): Causes the MapObject to resize/change appearance based on a new scale factor

    local MapBBox = {}
    MapBBox.__index = MapBBox

    function MapBBox.new(minimap, cf, size, color, colorB)
        local self = setmetatable({}, MapBBox)

        local quad = Instance.new("Frame")
        quad.AnchorPoint = Vector2.new(0.5, 0.5)
        quad.BackgroundTransparency = 0.25
        quad.BackgroundColor3 = color
        quad.BorderSizePixel = 1
        quad.BorderColor3 = colorB

        self.Map = minimap
        self.Root = quad
        self.CFrame = cf
        self.Size = size

        return self
    end

    function MapBBox:UpdateSize(scaleFactor)
        local scaled = self.Size * scaleFactor

        local x, y, z = self.CFrame:ToOrientation()

        if y % (math.pi / 2) > 1e-3 then
            self.Root.Rotation = -y * 180 / math.pi
        else
            scaled = (self.CFrame - self.CFrame.Position):Inverse() * scaled -- if its a multiple of 90deg then just rotate the size instead of rotating the component
        end

        self.Root.Size = UDim2.fromOffset(scaled.X, scaled.Z)

        local pos2 = self.Map:mapPosition(Vector2.new(self.CFrame.Position.X, self.CFrame.Position.Z))
        self.Root.Position = UDim2.fromOffset(pos2.X, pos2.Y)
    end

    local MapSeat = setmetatable({}, { __index = MapBBox })
    MapSeat.__index = MapSeat

    function MapSeat.new(minimap, seat)
        local cSeatColor = Color3.fromRGB(38, 38, 38)
        local cSeatColorB = Color3.fromRGB(0, 0, 0)

        local self = setmetatable(MapBBox.new(minimap, seat.CFrame, seat.Size, cSeatColor, cSeatColorB), MapSeat)

        self.Seat = seat
        self.TooltipObject = self.Root

        return self
    end

    function MapSeat:ShowTooltip()
        return self.Map.ScaleFactor > 2
    end

    function MapSeat:CreateTooltip(tp)
        BFS.UI.createListLayout(tp.Frame, Enum.HorizontalAlignment.Left)

        local headerText = tp:createText(24)
        headerText.Text = "<b>Seat</b>"

        local infoText = tp:createText(15)

        if LocalPlayer.Character and self.Seat.Occupant == LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            infoText.Text = "Seat is occupied by you"
        elseif self.Seat.Occupant then
            infoText.Text = "Seat is occupied by "..self.Seat.Occupant.Parent.Name
        else
            infoText.Text = "<i>Click to sit!</i>"
        end
    end

    function MapSeat:Clicked()
        if self.Seat.Occupant then return end

        local char = LocalPlayer.Character
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum.SeatPart then
            hum.Sit = false
            wait()
        end

        self.Seat:Sit(hum)
    end

    function MapSeat:UpdateSize(scaleFactor)
        self.Root.Visible = scaleFactor > 2
        MapBBox.UpdateSize(self, scaleFactor)
    end

    local PlayerDot = {}
    PlayerDot.__index = PlayerDot

    function PlayerDot.new(player, layers)
        local self = setmetatable({}, PlayerDot)

        local cIconSize = 20

        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromOffset(cIconSize, cIconSize)

        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size = UDim2.fromOffset(5, 5)
        dot.Position = UDim2.fromScale(0.5, 0.5)
        dot.BorderSizePixel = 0
        dot.Parent = frame

        local icon = Instance.new("ImageLabel")
        icon.Image = "rbxassetid://7480141029"
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.fromOffset(cIconSize, cIconSize)
        icon.BorderSizePixel = 0
        icon.Parent = frame

        local label = BFS.UI.createText(frame)
        label.Position = UDim2.fromScale(1, 1)
        label.AutomaticSize = Enum.AutomaticSize.XY
        label.Visible = false
        label.Text = player.Name

        self.TooltipObject = frame
        self.Frame = frame
        self.Dot = dot
        self.Icon = icon
        self.Label = label

        self.Player = player
        self.IsLocal = player == LocalPlayer

        self.Layers = layers

        self.InfoText = nil

        self:update()

        return self
    end

    function PlayerDot:update()
        if self.Player.UserId == LocalPlayer.UserId then
            self:setParent(self.Layers[3])
            self:setColor(Color3.fromRGB(255, 255, 0))
            return
        end

        self:setParent(self.Layers[1])
        self:setColor(Color3.fromRGB(255, 255, 255))
    end

    function PlayerDot:UpdateSize(scale)
        self.Scale = scale

        if scale > 2 then
            self.Dot.BackgroundTransparency = 1
            self.Icon.ImageTransparency = 0
            self.Label.Visible = true
        else
            self.Dot.BackgroundTransparency = 0
            self.Icon.ImageTransparency = 1
            self.Label.Visible = false
        end
    end

    function PlayerDot:setParent(parent)
        self.Frame.Parent = parent
    end

    function PlayerDot:setColor(color)
        self.Dot.BackgroundColor3 = color
        self.Icon.ImageColor3 = color
    end

    function PlayerDot:ShowTooltip()
        return self.Scale > 2
    end

    function PlayerDot:CreateTooltip(tp)
        local cUsernameHeight = 24
        local cInfoHeight = 15

        BFS.UI.createListLayout(tp.Frame, Enum.HorizontalAlignment.Left)

        local usernameText = tp:createText(cUsernameHeight)
        usernameText.Text = "<b>"..self.Player.Name.."</b>"

        local infoText = tp:createText(cInfoHeight)
        if self.InfoText then
            infoText.Text = self.InfoText
        elseif self.IsLocal then
            infoText.Text = "This is you."
        else
            infoText.Text = "Random"
        end

        if not self.IsLocal then
            local tpText = tp:createText(cInfoHeight)
            tpText.Text = "<i>Click to teleport!</i>"
        end
    end

    function PlayerDot:Clicked(input)
        if self.IsLocal then return end

        local root = self.Player.Character:FindFirstChild("HumanoidRootPart")

        if root then
            teleport(root.CFrame)
        end
    end

    local Waypoint = {}
    Waypoint.__index = Waypoint

    function Waypoint.new(minimap, name, loc, color)
        local self = setmetatable({}, Waypoint)

        local icon = Instance.new("ImageLabel")
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Image = "rbxassetid://7596158422"
        icon.ImageColor3 = color
        icon.Size = UDim2.fromOffset(25, 25)
        icon.BackgroundTransparency = 1
        icon.BorderSizePixel = 0

        self.Map = minimap
        self.Root = icon

        self.Name = name
        self.CFrame = loc

        self.TooltipObject = icon

        return self
    end

    function Waypoint:UpdateSize(scaleFactor)
        local pos2 = self.Map:mapPosition(Vector2.new(self.CFrame.Position.X, self.CFrame.Position.Z))
        self.Root.Position = UDim2.fromOffset(pos2.X, pos2.Y)

        self.Root.Visible = scaleFactor > 2
    end

    function Waypoint:Clicked(input)
        teleport(self.CFrame)
    end

    function Waypoint:CreateTooltip(tp)
        BFS.UI.createListLayout(tp.Frame, Enum.HorizontalAlignment.Left)

        local name = tp:createText(24)
        name.Text = "<b>"..self.Name.."</b>"

        local info = tp:createText(15)
        info.Text = "<i>Click to teleport!</i>"
    end

    Minimap = {}
    Minimap.__index = Minimap

    function Minimap.new(parent)
        local self = setmetatable({}, Minimap)

        self.Parent = parent

        local origin, maxPos = self:_findWorldBounds()
        self.WorldOrigin = origin
        self.RealSize2 = maxPos - origin

        self.ScaleFactor = 1.2
        self.ScaleFactorSmall = 1.2
        self.MapSizeSmall = UDim2.fromOffset(300, 300)

        local mapFrameO = Instance.new("Frame")
        mapFrameO.AnchorPoint = Vector2.new(0, 1)
        mapFrameO.Position = UDim2.fromScale(0, 1)
        mapFrameO.Size = UDim2.fromScale(0, 0)
        mapFrameO.BackgroundColor3 = BFS.UIConsts.BackgroundColor
        mapFrameO.BackgroundTransparency = 0.5
        mapFrameO.BorderSizePixel = 3
        mapFrameO.BorderColor3 = BFS.UIConsts.ForegroundColor
        mapFrameO.ClipsDescendants = true
        mapFrameO.Parent = parent

        self.FrameOuter = mapFrameO

        local mapFrameI = Instance.new("Frame")
        mapFrameI.BackgroundTransparency = 1
        mapFrameI.BorderSizePixel = 0
        mapFrameI.Position = UDim2.fromScale(0, 0)
        mapFrameI.Parent = mapFrameO

        self.FrameInner = mapFrameI

        self.Tooltips = TooltipProvider.new(parent)

        self.AreaLayer = self:createLayer()
        self.TerrainLayer = self:createLayer()
        self.SeatLayer = self:createLayer()
        self.PlayerLayerRandom = self:createLayer()
        self.PlayerLayerSpecial = self:createLayer()
        self.PlayerLayerSelf = self:createLayer()
        self.WaypointLayer = self:createLayer()

        self.PlayerLayers = { self.PlayerLayerRandom, self.PlayerLayerSpecial, self.PlayerLayerSelf }

        self.MapObjects = {}
        self:_plotAreas()
        self:_plotTerrain()
        self:_plotWaypoints()

        self.Players = {}
        self.PlayerPositions = {}

        for _, v in pairs(Players:GetPlayers()) do
            self:_playerConnect(v)
        end

        self._lConnect = Players.PlayerAdded:Connect(function(player)
            self:_playerConnect(player)
        end)

        self._lDisconnect = Players.PlayerRemoving:Connect(function(player)
            self:_playerDisconnect(player)
        end)

        self._lHeartbeat = RunService.Heartbeat:Connect(function()
            self:_heartbeat()
        end)

        self._expandTween = nil
        self.Expanded = nil
        self:setExpanded(false)

        self._dragStart = nil
        self._dragPosOrig = nil

        mapFrameO.InputBegan:Connect(function(input)
            self:_inputB(input)
        end)

        mapFrameO.InputChanged:Connect(function(input)
            self:_inputC(input)
        end)

        mapFrameO.InputEnded:Connect(function(input)
            self:_inputE(input)
        end)

        self._lSizeChange = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            self:updateSizeO()
        end)

        self:updateSizeO()

        return self
    end

    function Minimap:createLayer()
        local layer = Instance.new("Frame")
        layer.Size = UDim2.fromScale(1, 1)
        layer.BorderSizePixel = 0
        layer.BackgroundTransparency = 1
        layer.Parent = self.FrameInner

        return layer
    end

    function Minimap:_findBounds(insts, check)
        local xMin = math.huge
        local yMin = math.huge
        local zMin = math.huge

        local xMax = -math.huge
        local yMax = -math.huge
        local zMax = -math.huge

        local function scan(inst)
            if not (inst:IsA("Part") or inst:IsA("MeshPart")) or (check and not check(inst)) then return end

            for _, player in pairs(Players:GetPlayers()) do
                if player.Character and inst:IsDescendantOf(player.Character) then
                    return
                end
            end

            local posMin = inst.Position - inst.Size / 2 -- top left
            local posMax = inst.Position + inst.Size / 2 -- bottom right

            if posMin.X < xMin then
                xMin = posMin.X
            end

            if posMax.X > xMax then
                xMax = posMax.X
            end

            if posMin.Y < yMin then
                yMin = posMin.Y
            end

            if posMax.Y > yMax then
                yMax = posMax.Y
            end

            if posMin.Z < zMin then
                zMin = posMin.Z
            end

            if posMax.Z > zMax then
                zMax = posMax.Z
            end
        end

        for _, v in pairs(insts) do
            for _, part in pairs(v:GetDescendants()) do
                scan(part)
            end
        end

        return Vector3.new(xMin, yMin, zMin), Vector3.new(xMax, yMax, zMax)
    end

    function Minimap:_findWorldBounds()
        local posMin, posMax = self:_findBounds({ workspace })

        -- must scan ActiveZone for zones player is currently inside
        return Vector2.new(posMin.X, posMin.Z), Vector2.new(posMax.X, posMax.Z)
    end

    function Minimap:setVisible(visible)
        if visible == self.FrameOuter.Visible then return end

        self.FrameOuter.Visible = visible

        if not visible then
            self:setExpanded(false)
        end
    end

    function Minimap:setExpanded(expanded, force)
        if expanded and not self.FrameOuter.Visible then return end

        if not force and expanded == self.Expanded then return end
        self.Expanded = expanded

        local tweenInfo = TweenInfo.new(0.5)
        local goal = {}

        if expanded then
            goal.Size = UDim2.fromScale(1, 1)
            goal.Position = UDim2.fromScale(0, 1)
            self.ScaleFactor = 5
        else
            goal.Size = self.MapSizeSmall
            goal.Position = UDim2.new(0, 100, 1, -100)
            self.ScaleFactor = self.ScaleFactorSmall
        end

        local tween = TweenService:Create(self.FrameOuter, tweenInfo, goal)
        self._expandTween = tween
        tween:Play()

        self:updateZoom()
        self.FrameOuter.Active = expanded
    end

    -- anchorPoint is in screen coordinates.
    function Minimap:updateZoom(anchorPoint)
        local targetSize = self.RealSize2 * self.ScaleFactor

        local offset
        local origSize

        if anchorPoint then
            offset = (Vector2.new(anchorPoint.X, anchorPoint.Y) - self.FrameInner.AbsolutePosition) / self.FrameInner.AbsoluteSize
            origSize = self.FrameInner.AbsoluteSize
        end

        self.FrameInner.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)

        if anchorPoint then
            local offsetLocal = offset * self.FrameInner.AbsoluteSize
            local distance = offsetLocal - offset * origSize
            self.FrameInner.Position = self.FrameInner.Position - UDim2.fromOffset(distance.X, distance.Y)
        end

        for _, v in pairs(self.MapObjects) do
            if v then
                v:UpdateSize(self.ScaleFactor)
            end
        end

        for _, v in pairs(self.Players) do
            if v then
                v:UpdateSize(self.ScaleFactor)
                self:plotPlayer(v.Player)
            end
        end
    end

    function Minimap:_findZone(name)
        local rep = ReplicatedStorage.Zones:FindFirstChild(name)
        if rep then return rep end

        local active = workspace.ActiveZone:FindFirstChild(name)
        if active then return active end

        BFS.log("WARNING: Did you delete any zones? Failed to find "..name.."!")
    end

    function Minimap:_plotAreas()
        local cArea = Color3.fromRGB(86, 94, 81)
        local cAreaB = Color3.fromRGB(89, 149, 111)

        -- TODO
    end

    function Minimap:_plotTerrain()
        local features = workspace.Map:GetDescendants()
        local seatList = { features }

        local cTree = Color3.fromRGB(89, 149, 111)
        local cTreeB = Color3.fromRGB(5, 145, 56)

        local cRock = Color3.fromRGB(89, 105, 108)
        local cRockB = Color3.fromRGB(89, 89, 89)

        if BFS.Config.Value.mapRenderEverything then
            local function getTopY(part)
                return part.Position.Y + part.Size.Y / 2
            end

            local function compare(a, b)
                return getTopY(a) < getTopY(b)
            end

            local parts = {}

            for _, v in pairs(features) do
                if v:IsA("BasePart") then
                    parts[#parts + 1] = v
                end
            end

            table.sort(parts, compare)

            for _, v in pairs(parts) do
                self:plotPartQuad(v, v.Color, cRockB)
            end

            local cBench = Color3.fromRGB(173, 125, 110)
            local cBenchB = Color3.fromRGB(173, 88, 62)

            for _, v in pairs(features) do -- bench
                if v:IsA("Model") and (v.Name == "Bench" or v.Name == "log") then
                    local cf, size = v:GetBoundingBox()
                    self:plotBBox(cf, size, cBench, cBenchB)
                end
            end

            -- ALL SEATS!!!
            for _, list in pairs(seatList) do
                for _, v in pairs(list) do
                    if v:IsA("Seat") then
                        local seatObj = MapSeat.new(self, v)
                        self:addMapObject(seatObj, self.SeatLayer)
                        self.Tooltips:register(seatObj)
                    end
                end
            end
        else
            -- TODO
        end
    end

    function Minimap:_plotWaypoints()
        -- TODO
    end

    function Minimap:plotWaypoint(name, loc, color)
        local waypointObj = Waypoint.new(self, name, loc, color)
        self:addMapObject(waypointObj, self.WaypointLayer)
        self.Tooltips:register(waypointObj)
    end

    function Minimap:updateSizeO()
        local cMapSize169 = 300
        local parentSize = self.Parent.AbsoluteSize
        local dim = math.min(cMapSize169 * parentSize.X / 1920, cMapSize169 * parentSize.Y / 1080)
        self.MapSizeSmall = UDim2.fromOffset(dim, dim)
        self.ScaleFactorSmall = 1.2 * parentSize.X / 1920
        self:setExpanded(self.Expanded, true)
    end

    function Minimap:mapPosition(pos)
        return (pos - self.WorldOrigin) * self.ScaleFactor
    end

    function Minimap:plotPlayer(player)
        if not player.Character then return end

        local humanRoot = player.Character:FindFirstChild("HumanoidRootPart")
        if not humanRoot then return end

        local pos3D = humanRoot.Position
        local mapped = self:mapPosition(Vector2.new(pos3D.X, pos3D.Z))
        self.PlayerPositions[player.UserId] = mapped

        if not self.Players[player.UserId] then return end
        self.Players[player.UserId].Frame.Position = UDim2.fromOffset(mapped.X, mapped.Y)
        self.Players[player.UserId].Icon.Rotation = -humanRoot.Orientation.Y - 45
    end

    function Minimap:addMapObject(obj, parent)
        self.MapObjects[#self.MapObjects + 1] = obj
        obj:UpdateSize(self.ScaleFactor)
        obj.Root.Parent = parent
    end

    function Minimap:plotBBox(cf, size, color, colorB, parent)
        if not parent then parent = self.TerrainLayer end

        local mapObj = MapBBox.new(self, cf, size, color, colorB)
        self:addMapObject(mapObj, parent)
    end

    function Minimap:plotPartQuad(part, color, colorB, parent)
        self:plotBBox(part.CFrame, part.Size, color, colorB, parent)
    end

    function Minimap:_playerConnect(player)
        if not self.Players[player.UserId] then
            local dot = PlayerDot.new(player, self.PlayerLayers)
            dot:UpdateSize(self.ScaleFactor)

            self.Tooltips:register(dot)

            self.Players[player.UserId] = dot
        end
    end

    function Minimap:_playerDisconnect(player)
        if self.Players[player.UserId] then
            self.Tooltips:deregister(self.Players[player.UserId])
            self.Players[player.UserId].Frame:Destroy()
        end

        self.Players[player.UserId] = nil
        self.PlayerPositions[player.UserId] = nil
    end

    function Minimap:_heartbeat()
        for _, v in pairs(Players:GetPlayers()) do
            self:plotPlayer(v)
        end

        local pos = self.PlayerPositions[LocalPlayer.UserId]

        if not self.Expanded or (self._expandTween and self._expandTween.PlaybackState ~= Enum.PlaybackState.Completed) then
            self.FrameInner.Position = UDim2.new(0.5, -pos.X, 0.5, -pos.Y)
        end
    end

    function Minimap:_zoom(position)
        self.ScaleFactor = math.min(math.max(self.ScaleFactor + 0.5 * position.Z, 0.2), 16)
        self:updateZoom(position)
    end

    function Minimap:_inputB(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and self.Expanded then
            self._dragStart = input.Position
            self._dragPosOrig = self.FrameInner.Position
        elseif input.UserInputType == Enum.UserInputType.MouseWheel and self.Expanded then
            self:_zoom(input.Position)
        end
    end

    function Minimap:_inputC(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and self._dragStart then
            local offset = input.Position - self._dragStart
            self.FrameInner.Position = self._dragPosOrig + UDim2.fromOffset(offset.X, offset.Y)
        elseif input.UserInputType == Enum.UserInputType.MouseWheel and self.Expanded then
            self:_zoom(input.Position)
        end
    end

    function Minimap:_inputE(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._dragStart = nil
        end
    end

    function Minimap:destroy()
        self.FrameOuter:Destroy()
        self.Tooltips.Frame:Destroy()
        self._lSizeChange:Disconnect()
        self._lConnect:Disconnect()
        self._lDisconnect:Disconnect()
        self._lHeartbeat:Disconnect()
    end
end -- minimap -- globals exposed: Minimap

local guiVisible = true
local guiWasVisible = {}

local function setGuiVisible(isVisible)
    BFS.TabControl:setTabsVisible(isVisible)
    secondaryRoot.Visible = isVisible

    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, isVisible) -- for chat window

    local function updateRecursive(root)
        for _, gui in pairs(root:GetDescendants()) do
            if gui:IsA("ScreenGui") then
                if guiWasVisible[gui] == nil then
                    guiWasVisible[gui] = gui.Enabled
                end

                gui.Enabled = guiWasVisible[gui] and isVisible
            end
        end
    end

    updateRecursive(CoreGui)
    if huiFolder then
        updateRecursive(huiFolder)
    end

    LocalPlayer.PlayerGui.MainGui.Enabled = isVisible
end

BFS.Binds:bind("HideGui", function()
    guiVisible = not guiVisible
    setGuiVisible(guiVisible)
end)

BFS.bindToExit("Unhide GUIs", function()
    setGuiVisible(true)
end)

local map = nil

BFS.Binds:bind("MapVis", function()
    if not map then
        map = Minimap.new(secondaryRoot)
        BFS.bindToExit("Destroy Map", function()
            map:destroy()
        end)
    elseif guiVisible then
        map:setVisible(not map.FrameOuter.Visible)
    end
end)

BFS.Binds:bind("MapView", function()
    if map then
        map:setExpanded(not map.Expanded)
    end
end)
