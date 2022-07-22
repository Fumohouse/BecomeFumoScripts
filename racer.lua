--[[
    !! READ ME !!
    SBF Race Utilities
    voided_etc // 2022

    Designed for UNC executors

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
            i. Place the file into your executor's workspace folder.
            ii. Type the file name into the "File name" field.
            iii. Press "Load".
            - Make sure you pay attention to the direction of the track. If it is wrong, you need to make the checkpoints yourself.
        c. Save your list of checkpoints: Type the file name and press "Save".
    2. In the 1R (Race) tab:
        a. Indicate how many laps the race should be, and press [ENTER]
        b. Press "Hide Checkpoints" to hide the checkpoints in the workspace and on the map.
        c. If you do not want to log data about each racer every frame, switch off "Log Verbose Data"
            - This data will easily reach 30+ megabytes.
        d. Press "Race Active" to begin tracking players.
    3. Once the race is over, press "Race Active" again to export all logs, clear data, and end the race.
        - DO NOT END THE RACE EARLY! There is no way to recover/reimport the data after you end the race.
          Only do so when you are sure everyone has finished or forfeited.

    Notes:
    - You should press "Race Active" by the time the countdown starts. If you are late, results may be incorrect.
    - A player will be placed on the leaderboard as soon as they enter any of the checkpoints.
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

local BFSMap = getgenv().BFSMap

if not BFSMap then
    loadstring(game:HttpGet(("https://gist.githubusercontent.com/kyoseki/07f37b493f46895e67339e85c223423c/raw/minimap.lua"), true))()
    BFSMap = getgenv().BFSMap
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

version = "1.0.1"

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

--
-- constants
--

local cDateFormat = "%d-%m-%y_%H-%M-%S"

local cPadding = 30

local map

local raceData = {
    active = false,
    activeTimeLocal = 0,
    activeTime = 0,
    checkpoints = {},
    players = {},
    eventLog = {},
    playerCount = 0,
    laps = 0,
    checkpointsVisible = true,
    logVerboseData = true,
}

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

local function createOverlayFrame()
    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 0.3
    frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    frame.BorderSizePixel = 4
    frame.BorderColor3 = Color3.new(0.05, 0.05, 0.05)

    return frame
end

function raceData:Folder()
    return string.format(
        "race-%s",
        os.date(cDateFormat, self.activeTimeLocal)
    )
end

function raceData:InitFolder()
    local folder = self:Folder()
    if not isfolder(folder) then
        makefolder(folder)
    end
end

function raceData:ExportLog()
    self:InitFolder()
    local output = {
        string.format(
            "---- Race log, exported %s ----\n\n",
            os.date("%d-%m-%Y at %H:%M:%S (local time)")
        ),
        "--- RACE SUMMARY ---",
    }

    local finishedSorted, playersSorted = raceData:SortPlayers()
    local place = 1

    for _, playerData in pairs(finishedSorted) do
        output[#output + 1] = string.format(
            "#%d - %s - %.2f seconds",
            place, playerData.Player.Name, playerData.Finished - playerData.Started
        )

        place += 1
    end

    for _, playerData in pairs(playersSorted) do
        output[#output + 1] = string.format(
            "#%d - %s - DNF",
            place, playerData.Player.Name
        )

        place += 1
    end

    output[#output + 1] = "========"
    output[#output + 1] = table.concat(raceData.eventLog, "\n")

    local filename = string.format("%s/race.log", self:Folder(), os.date(cDateFormat))
    writefile(filename, table.concat(output, "\n"))
end

function raceData:Log(msg)
    self.eventLog[#self.eventLog + 1] = string.format(
        "[%s] %s",
        os.date("%H:%M:%S", os.time()), msg
    )
end

function raceData:ClearCheckpoints()
    for _, checkpoint in pairs(self.checkpoints) do
        checkpoint:Destroy()
    end

    self.checkpoints = {}
end

function raceData:SetCheckpointsVisible(visible)
    for _, checkpoint in pairs(self.checkpoints) do
        checkpoint:SetVisible(visible)
    end

    self.checkpointsVisible = visible
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

function raceData:SortPlayers()
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

        return finishedSorted, playersSorted
end

local Checkpoint = {}
Checkpoint.__index = Checkpoint

function Checkpoint.new(parent, index, point1, point2, removeHook)
    local self = setmetatable({}, Checkpoint)

    self.Point1 = point1
    self.Point2 = point2
    self.Region = nil

    self.RegionPart = nil
    self.RegionLabel = nil

    local root = Instance.new("Frame")
    root.Size = UDim2.new(1, 0, 0, 0)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.AutomaticSize = Enum.AutomaticSize.Y
    BFS.UI.createListLayout(root, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

    root.Parent = parent
    self.Root = root

    local label = BFS.UI.createCategoryLabel(root, "")
    self.Label = label

    local point1Button
    point1Button = BFS.UI.createLabelButtonLarge(root, "Point 1: "..formatVector(self.Point1), function()
        self.Point1 = getFootPosition()
        self:UpdateRegion()
        point1Button.Label.Text = "Point 1: "..formatVector(self.Point1)
    end)

    local point2Button
    point2Button = BFS.UI.createLabelButtonLarge(root, "Point 2: "..formatVector(self.Point2), function()
        self.Point2 = getFootPosition() + Vector3.new(0, 5, 0)
        self:UpdateRegion()
        point2Button.Label.Text = "Point 2: "..formatVector(self.Point2)
    end)

    BFS.UI.createLabelButtonLarge(root, "Delete", removeHook)

    self:UpdateIndex(index)
    self:UpdateRegion()

    return self
end

function Checkpoint:UpdateIndex(index)
    self.Index = index
    self.Label.Text = "Checkpoint "..index

    if self.RegionLabel then
        self.RegionLabel.Text = "C"..index
    end
end

function Checkpoint:initRegionPart()
    local part = Instance.new("Part")
    part.Color = Color3.new(1, 1, 1)
    part.CanCollide = false
    part.Anchored = true
    part.Material = Enum.Material.SmoothPlastic
    part.Parent = workspace

    self.RegionPart = part

    local billboard = Instance.new("BillboardGui")
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
    billboard.Adornee = part
    billboard.Parent = part
    billboard.Size = UDim2.new(0, 200, 0, 50)
    self.Billboard = billboard

    local text = BFS.UI.createText(billboard, 40)
    text.Text = "C"..self.Index
    text.Size = UDim2.fromScale(1, 1)
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.TextYAlignment = Enum.TextYAlignment.Center
    self.RegionLabel = text

    local bBox = map:plotBBox(CFrame.new(), Vector3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(1, 1, 1))
    self.MapBBox = bBox

    self:SetVisible(raceData.checkpointsVisible)
end

function Checkpoint:UpdateRegion()
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
        self:initRegionPart()
    end

    self.RegionPart.CFrame = self.Region.CFrame
    self.RegionPart.Size = self.Region.Size

    self.MapBBox:UpdateBounds(self.Region.CFrame, self.Region.Size)
end

function Checkpoint:SetVisible(visible)
    if self.RegionPart then
        self.Billboard.Enabled = visible
        self.MapBBox.Root.Visible = visible

        if visible then
            self.RegionPart.Transparency = 0.5
        else
            self.RegionPart.Transparency = 1
        end
    end
end

function Checkpoint:Destroy()
    self.Root:Destroy()
    if self.RegionPart then
        self.RegionPart:Destroy()
        map:removeMapObject(self.MapBBox)
    end
end

local PlayerData = {}
PlayerData.__index = PlayerData

function PlayerData.new(player, overlayEntry)
    local self = setmetatable({}, PlayerData)

    self.Player = player

    self.Started = tick()
    self.Place = 0
    self.Lap = 0
    self.Checkpoint = 0
    self.CheckpointsMissed = 0
    self.Finished = nil
    self.DataPoints = {}

    self.OverlayEntry = overlayEntry

    return self
end

function PlayerData:FlushData()
    raceData:InitFolder()

    local filename = string.format("%s/%s.csv", raceData:Folder(), self.Player.Name)
    local fileExists = isfile(filename)
    local output

    if fileExists then
        output = { "" }
    else
        output = { "Tick,Place,Lap,Checkpoint,Speed,Sitting" }
    end

    for _, dataPoint in ipairs(self.DataPoints) do
        local sitNum
        if dataPoint.Sitting then
            sitNum = 1
        else
            sitNum = 0
        end

        output[#output + 1] = string.format(
            "%f,%d,%d,%d,%f,%d",
            dataPoint.Tick, dataPoint.Place, dataPoint.Lap, dataPoint.Checkpoint, dataPoint.Speed, sitNum
        )
    end

    if fileExists then
        appendfile(filename, table.concat(output, "\n"))
    else
        writefile(filename, table.concat(output, "\n"))
    end

    self.DataPoints = {}
end

function PlayerData:LogData()
    local char = self.Player.Character
    if not char then
        return
    end

    local rootPart = char.PrimaryPart
    if not rootPart then
        return
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local data = {
        Tick = tick() - raceData.activeTime,
        Speed = rootPart.AssemblyLinearVelocity.Magnitude,
        Sitting = humanoid.Sit,
        Place = self.Place,
        Lap = self.Lap,
        Checkpoint = self.Checkpoint,
    }

    self.DataPoints[#self.DataPoints + 1] = data

    if #self.DataPoints > 600 then
        self:FlushData()
    end
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

do  -- spectating
    local cPositionHidden = UDim2.fromScale(0.5, -0.2)
    local cPositionVisible = UDim2.fromScale(0.5, 0)

    local spectatorOverlay = createOverlayFrame()
    spectatorOverlay.Size = UDim2.fromScale(0.25, 0.08)
    spectatorOverlay.AnchorPoint = Vector2.new(0.5, 0)
    spectatorOverlay.Position = cPositionHidden
    spectatorOverlay.Parent = secondaryRoot

    local spectatingText = BFS.UI.createText(spectatorOverlay, 0)
    spectatingText.Size = UDim2.fromScale(1, 0.2)
    spectatingText.RichText = true
    spectatingText.Text = "<i>Now Spectating</i>"
    spectatingText.TextScaled = true

    local playerInfo = Instance.new("Frame")
    playerInfo.BackgroundTransparency = 1
    playerInfo.BorderSizePixel = 0
    playerInfo.AnchorPoint = Vector2.new(0.5, 0)
    playerInfo.Position = UDim2.fromScale(0.5, 0.3)
    playerInfo.Size = UDim2.fromScale(0.8, 0.6)
    playerInfo.Parent = spectatorOverlay

    local listLayout = BFS.UI.createListLayout(playerInfo, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center, 20)
    listLayout.FillDirection = Enum.FillDirection.Horizontal

    local placeText = BFS.UI.createText(playerInfo)
    placeText.TextScaled = true
    placeText.Size = UDim2.fromScale(0.2, 1)
    placeText.Text = "#1"

    local usernameText = BFS.UI.createText(playerInfo)
    usernameText.TextScaled = true
    usernameText.Size = UDim2.fromScale(0, 0.8)
    usernameText.Text = "voided_etc"
    usernameText.AutomaticSize = Enum.AutomaticSize.X

    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)

    local function setVisible(visible)
        local target = {}

        if visible then
            target.Position = cPositionVisible
        else
            target.Position = cPositionHidden
        end

        local tween = TweenService:Create(spectatorOverlay, tweenInfo, target)
        tween:Play()
    end

    local spectatingPlayer = nil

    local preSpectate = {
        Focus = nil,
        CameraType = nil,
        CameraSubject = nil,
    }

    local camera = workspace.Camera

    function updateSpectatingOverlay()
        if spectatingPlayer then
            placeText.Text = "#"..spectatingPlayer.Place
            placeText.TextColor3 = getColor(spectatingPlayer, spectatingPlayer.Place)
            usernameText.Text = spectatingPlayer.Player.Name
        end
    end

    function stopSpectating()
        if spectatingPlayer then
            map.Focus = preSpectate.Focus
            camera.CameraType = preSpectate.CameraType
            camera.CameraSubject = preSpectate.CameraSubject

            setVisible(false)
            spectatingPlayer = nil
        end
    end

    function toggleSpectate(playerData)
        if spectatingPlayer == playerData then
            stopSpectating()
            return
        end

        if not spectatingPlayer then
            setVisible(true)
            preSpectate.Focus = map.Focus
            preSpectate.CameraType = camera.CameraType
            preSpectate.CameraSubject = camera.CameraSubject
        end

        spectatingPlayer = playerData
        updateSpectatingOverlay()

        map.Focus = { Player = playerData.Player.UserId }
        camera.CameraType = Enum.CameraType.Follow
        camera.CameraSubject = playerData.Player.Character.Humanoid
    end

    BFS.bindToExit("Stop spectating", stopSpectating)
end -- spectating

do  -- race overlay
    local cPlayers = 5

    local cHeaderHeight = 24
    local cPlayerHeight = 30

    local cRowPadding = 0.05
    local cPlaceWidth = 0.1
    local cPlayerWidth = 0.7
    local cLapWidth = 0.1

    local cBodyHeight = cPlayerHeight * cPlayers

    local raceOverlay = createOverlayFrame()
    raceOverlay.Size = UDim2.new(0.3, 0, 0, cBodyHeight + cHeaderHeight)
    raceOverlay.AnchorPoint = Vector2.new(1, 1)
    raceOverlay.Position = UDim2.new(1, -cPadding, 1, -cPadding)
    raceOverlay.Parent = secondaryRoot

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
    playerHeader.Position = UDim2.fromScale(cRowPadding + cPlaceWidth, 0)
    playerHeader.Size = UDim2.fromScale(cPlayerWidth, 1)
    playerHeader.Text = "Player"

    local lapsHeader = createRowText(header, 15)
    lapsHeader.Position = UDim2.fromScale(cRowPadding + cPlaceWidth + cPlayerWidth, 0)
    lapsHeader.Size = UDim2.fromScale(cLapWidth, 1)
    lapsHeader.Text = "Laps"

    local leaderboardScroll = BFS.UI.createScroll(raceOverlay)
    leaderboardScroll.Size = UDim2.new(1, 0, 0, cBodyHeight)
    leaderboardScroll.AnchorPoint = Vector2.new(0, 1)
    leaderboardScroll.Position = UDim2.fromScale(0, 1)

    function addPlayerToOverlay(player)
        local entryData = {}
        local entry = Instance.new("Frame")
        entry.Active = true
        entry.BackgroundTransparency = 1
        entry.BorderSizePixel = 0
        entry.Size = UDim2.new(1, 0, 0, cPlayerHeight)
        entry.Position = UDim2.fromOffset(0, cPlayerHeight * raceData.playerCount)

        entry.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                toggleSpectate(raceData.players[player])
            end
        end)

        entry.Parent = leaderboardScroll
        entryData.Root = entry

        local x = cRowPadding

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

    function updateOverlay()
        local finishedSorted, playersSorted = raceData:SortPlayers()

        local y = 0
        local place = 1

        local function updatePlayer(playerData)
            playerData.Place = place
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
    local raceScroll = BFS.UI.createListScroll(raceTab)

    BFS.UI.createCategoryLabel(raceScroll, "Race")

    local lapsField = BFS.UI.createTextBox(raceScroll, "Total Laps", 24)

    lapsField.FocusLost:Connect(function()
        if lapsField.Text == "" then
            return
        end

        local num = tonumber(lapsField.Text)
        if num then
            raceData.laps = num
        end
    end)

    BFS.UI.createLabelButtonLarge(raceScroll, "Race Active", function(setActive)
        raceData.active = not raceData.active
        if raceData.active then
            raceData.activeTimeLocal = os.time()
            raceData.activeTime = tick()
            raceData:Log(string.format("Race was marked active. - tick: %f", raceData.activeTime))
        else
            raceData:Log("Race was marked inactive.")

            raceData:ExportLog()

            for _, player in pairs(raceData.players) do
                if raceData.logVerboseData then
                    player:FlushData()
                end
                player:Destroy()
            end

            raceData.players = {}
            raceData.playerCount = 0
            raceData.eventLog = {}

            stopSpectating()
        end
        setActive(raceData.active)
    end)

    BFS.UI.createLabelButtonLarge(raceScroll, "Hide Checkpoints", function(setActive)
        raceData:SetCheckpointsVisible(not raceData.checkpointsVisible)
        setActive(not raceData.checkpointsVisible)
    end)

    local collectDataToggle = BFS.UI.createLabelButtonLarge(raceScroll, "Log Verbose Data", function(setActive)
        raceData.logVerboseData = not raceData.logVerboseData
        setActive(raceData.logVerboseData)
    end)

    collectDataToggle.SetActive(true)

    BFS.UI.createCategoryLabel(raceScroll, "Map Focus")

    BFS.UI.createLabelButtonLarge(raceScroll, "Focus map on SDM track", function()
        map.Focus = { Size = BFSMap.Presets.SBF.cSDMSize, Position = BFSMap.Presets.SBF.cSDMPos }
    end)

    BFS.UI.createLabelButtonLarge(raceScroll, "Focus map on RDR track", function()
        map.Focus = { Size = BFSMap.Presets.SBF.cRDRSize, Position = BFSMap.Presets.SBF.cRDRPos }
    end)

    BFS.UI.createLabelButtonLarge(raceScroll, "Focus map on me", function()
        map.Focus = nil
    end)

    BFS.UI.createCategoryLabel(raceScroll, "Misc")

    local lSpeedometer
    local lastSpeed
    local maxSpeed

    local speedText
    local accelText

    BFS.UI.createLabelButtonLarge(raceScroll, "Max Speed-o-meter", function(setActive)
        if lSpeedometer then
            lSpeedometer:Disconnect()
            lSpeedometer = nil
            setActive(false)
        else
            lastSpeed = 0
            maxSpeed = 0

            lSpeedometer = RunService.Heartbeat:Connect(function(dT)
                local char = LocalPlayer.Character
                if not char then
                    return
                end

                local root = char.PrimaryPart
                if not root then
                    return
                end

                local speed = root.AssemblyLinearVelocity.Magnitude
                if speed > maxSpeed then
                    maxSpeed = speed
                    speedText.Text = string.format("%.2f studs/s", speed)
                end

                local accel = (speed - lastSpeed) / dT
                accelText.Text = string.format("%.2f studs/s^2", accel)

                lastSpeed = speed
            end)

            setActive(true)
        end
    end)

    speedText = BFS.UI.createText(raceScroll, 24)
    speedText.AutomaticSize = Enum.AutomaticSize.XY
    speedText.Text = "Speed"
    accelText = BFS.UI.createText(raceScroll, 24)
    accelText.AutomaticSize = Enum.AutomaticSize.XY
    accelText.Text = "Acceleration"

    BFS.bindToExit("Unbind speedometer", function()
        if lSpeedometer then
            lSpeedometer:Disconnect()
        end
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
                whitelist[#whitelist + 1] = player.Character.PrimaryPart or player.Character:FindFirstChild("HumanoidRootPart") -- rigless!!!
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
                updateSpectatingOverlay()
            end
        end

        if raceData.logVerboseData then
            for _, playerData in pairs(raceData.players) do
                playerData:LogData()
            end
        end
    end)

    BFS.bindToExit("Race: Clean up", function()
        raceData:ClearCheckpoints()
        lHeartbeat:Disconnect()
    end)
end -- race

do  -- checkpoints
    local checkpointsTab = BFS.TabControl:createTab("Checkpoints", "2C", "TabCheckpoints")

    local cListPadding = 10
    local checkpointsScroll = BFS.UI.createListScroll(checkpointsTab, cListPadding)

    local checkpointsFrame = Instance.new("Frame")
    checkpointsFrame.Size = UDim2.new(1, 0, 0, 0)
    checkpointsFrame.BackgroundTransparency = 1
    checkpointsFrame.BorderSizePixel = 0
    checkpointsFrame.AutomaticSize = Enum.AutomaticSize.Y
    BFS.UI.createListLayout(checkpointsFrame, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top, cListPadding)

    checkpointsFrame.Parent = checkpointsScroll

    local function updateCheckpoints()
        for idx, checkpoint in ipairs(raceData.checkpoints) do
            checkpoint.Index = idx
            checkpoint:UpdateIndex(idx)
        end
    end

    local function addCheckpoint(point1, point2)
        local index = #raceData.checkpoints + 1

        local checkpoint
        checkpoint = Checkpoint.new(checkpointsFrame, index, point1, point2, function()
            checkpoint:Destroy()
            table.remove(raceData.checkpoints, checkpoint.Index)
            updateCheckpoints()
        end)

        raceData.checkpoints[index] = checkpoint

        return checkpoint
    end

    BFS.UI.createLabelButtonLarge(checkpointsScroll, "Add", function()
        addCheckpoint()
    end)

    BFS.UI.createLabelButtonLarge(checkpointsScroll, "Clear Checkpoints", function()
        raceData:ClearCheckpoints()
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
        if fileNameField.Text == "" or #raceData.checkpoints == 0 then
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

        raceData:ClearCheckpoints()

        if not isfile(fileNameField.Text) then
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
    function plotTerrain(target)
        local features = workspace.Map:GetDescendants()

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
                target:plotPartQuad(v, v.Color, cRockB)
            end

            local cBench = Color3.fromRGB(173, 125, 110)
            local cBenchB = Color3.fromRGB(173, 88, 62)

            for _, v in pairs(features) do -- bench
                if v:IsA("Model") and (v.Name == "Bench" or v.Name == "log") then
                    local cf, size = v:GetBoundingBox()
                    target:plotBBox(cf, size, cBench, cBenchB)
                end
            end
        else
            -- TODO
        end
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

map = BFSMap.Minimap.new(secondaryRoot, cPadding)
plotTerrain(map)
BFSMap.Presets.SBF:setup(map)

BFS.bindToExit("Destroy Map", function()
    map:destroy()
end)

BFS.Binds:bind("MapVis", function()
    map:setVisible(not map.FrameOuter.Visible)
end)

BFS.Binds:bind("MapView", function()
    if map then
        map:setExpanded(not map.Expanded)
    end
end)
