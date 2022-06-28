--[[
    Become Fumo Scripts Minimap
    voided_etc // 2021-2022
    Use with attribution.
]]

local BFS = getgenv().BFS
if not BFS then
    error("BFS UI is not loaded!")
end

local BFSMap = {}
getgenv().BFSMap = BFSMap

local TweenService = game:GetService("TweenService")
local UserInput = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

do  -- TooltipProvider
    TooltipProvider = {}
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
end -- TooltipProvider

-- MapObject spec (abstract)
-- constructor should contain minimap as first param
-- Map - Minimap: the map the object is assigned to
-- Root - GuiObject: the parent element of all other components of this MapObject
-- UpdateSize(scaleFactor): Causes the MapObject to resize/change appearance based on a new scale factor

do  -- MapBBox
    MapBBox = {}
    MapBBox.__index = MapBBox

    function MapBBox.new(minimap, cf, size, color, colorB, contents)
        local self = setmetatable({}, MapBBox)

        local quad = Instance.new("Frame")
        quad.AnchorPoint = Vector2.new(0.5, 0.5)
        if contents then
            quad.BackgroundTransparency = 1
            quad.BorderSizePixel = 0
            contents.Parent = quad
        else
            quad.BackgroundTransparency = 0.25
            quad.BackgroundColor3 = color
            quad.BorderSizePixel = 1
            quad.BorderColor3 = colorB
        end


        self.Map = minimap
        self.Root = quad
        self.CFrame = cf
        self.Size = size

        self.ScaleFactor = nil

        return self
    end

    function MapBBox:UpdateBounds(cf, size)
        self.CFrame = cf
        self.Size = size

        self:UpdateSize(self.ScaleFactor)
    end

    function MapBBox:UpdateSize(scaleFactor)
        self.ScaleFactor = scaleFactor

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
end -- MapBBox

do  -- MapSeat
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

    BFSMap.MapSeat = MapSeat
end -- MapSeat

do  -- PlayerDot
    PlayerDot = {}
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
            BFS.teleport(root.CFrame)
        end
    end
end -- PlayerDot

do  -- Waypoint
    Waypoint = {}
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
        BFS.teleport(self.CFrame)
    end

    function Waypoint:CreateTooltip(tp)
        BFS.UI.createListLayout(tp.Frame, Enum.HorizontalAlignment.Left)

        local name = tp:createText(24)
        name.Text = "<b>"..self.Name.."</b>"

        local info = tp:createText(15)
        info.Text = "<i>Click to teleport!</i>"
    end
end -- Waypoint

do  -- Minimap
    local Minimap = {}
    Minimap.__index = Minimap

    function Minimap.new(parent, padding)
        local self = setmetatable({}, Minimap)

        self.Parent = parent
        self.Padding = padding

        self.Focus = nil

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
            goal.Position = UDim2.new(0, self.Padding, 1, -self.Padding)
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
        self.PlayerPositions[player.UserId] = pos3D

        if not self.Players[player.UserId] then return end
        self.Players[player.UserId].Frame.Position = UDim2.fromOffset(mapped.X, mapped.Y)
        self.Players[player.UserId].Icon.Rotation = -humanRoot.Orientation.Y - 45
    end

    function Minimap:addMapObject(obj, parent)
        self.MapObjects[#self.MapObjects + 1] = obj
        obj:UpdateSize(self.ScaleFactor)
        obj.Root.Parent = parent
    end

    function Minimap:removeMapObject(toRemove)
        for idx, obj in pairs(self.MapObjects) do
            if obj == toRemove then
                local obj = table.remove(self.MapObjects, idx)
                obj.Root:Destroy()

                break
            end
        end
    end

    function Minimap:plotImage(cf, size, parent, id)
        local image = Instance.new("ImageLabel")
        image.Image = id
        image.ScaleType = Enum.ScaleType.Fit
        image.Size = UDim2.fromScale(1, 1)
        image.BorderSizePixel = 0
        image.BackgroundTransparency = 1

        self:plotBBox(cf, size, nil, nil, parent, image)
    end

    function Minimap:plotBBox(cf, size, color, colorB, parent, contents)
        if not parent then parent = self.TerrainLayer end

        local mapObj = MapBBox.new(self, cf, size, color, colorB, contents)
        self:addMapObject(mapObj, parent)

        return mapObj
    end

    function Minimap:plotPartQuad(part, color, colorB, parent)
        return self:plotBBox(part.CFrame, part.Size, color, colorB, parent)
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

    function Minimap:_focus(position, scale)
        self.ScaleFactor = scale
        position = self:mapPosition(position)
        self:updateZoom(position)

        self.FrameInner.Position = UDim2.new(0.5, -position.X, 0.5, -position.Y)
    end

    function Minimap:_heartbeat()
        for _, v in pairs(Players:GetPlayers()) do
            self:plotPlayer(v)
        end

        if self.Expanded and not (self._expandTween and self._expandTween.PlaybackState ~= Enum.PlaybackState.Completed) then
            return
        end

        if self.Focus and self.Focus.Position and self.Focus.Size then
            local scale2D = self.FrameOuter.AbsoluteSize / Vector2.new(self.Focus.Size.X, self.Focus.Size.Z)
            local pos = Vector2.new(self.Focus.Position.X, self.Focus.Position.Z)

            self:_focus(pos, math.min(scale2D.X, scale2D.Y))
        else
            local id = (self.Focus and self.Focus.Player) or LocalPlayer.UserId
            local pos = self.PlayerPositions[id] or self.PlayerPositions[LocalPlayer.UserId]

            self:_focus(Vector2.new(pos.X, pos.Z), self.ScaleFactorSmall)
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

    BFSMap.Minimap = Minimap
end -- Minimap

do  -- presets
    local Presets = {}

    local SBF = {
        cFountainPos = CFrame.new(-3.519104, 6.6499958, -13.2595749),
        --cFountainSize = Vector3.new(194.03819274902344, 80.0999984741211, 196.51914978027344),
        cFountainSize = Vector3.new(196.51914978027344, 80.0999984741211, 194.03819274902344),

        cSDMPos = CFrame.new(12485.9893, -19.8234463, 420.502899),
        cSDMSize = Vector3.new(420, 2.647937774658203, 420),

        cRDRPos = CFrame.new(370.240845, -0.996834755, 267.614807),
        -- cRDRSize = Vector3.new(265.57061767578125, 66.67078399658203, 225.7150115966797),
        cRDRSize = Vector3.new(225.7150115966797, 66.67078399658203, 265.57061767578125),
    }

    function SBF:plot(map)
        -- Fountain
        map:plotImage(self.cFountainPos, self.cFountainSize, map.TerrainLayer, "rbxassetid://10048236123")

        -- SDM
        map:plotImage(self.cSDMPos, self.cSDMSize, map.TerrainLayer, "rbxassetid://10048435454")

        -- RDR
        map:plotImage(self.cRDRPos, self.cRDRSize, map.TerrainLayer, "rbxassetid://10048586517")
    end

    Presets.SBF = SBF

    BFSMap.Presets = Presets
end -- presets
