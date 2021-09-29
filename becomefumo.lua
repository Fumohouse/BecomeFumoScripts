--[[
    do - end blocks can be closed in most ides for organization
    variables beginning with c are constant and should not change
]]

local function log(msg)
    print("[fumo] "..msg)
end

version = "1.5.6"

do  -- double load prevention
    if BF_LOADED then
        log("already loaded!")
        return
    end

    pcall(function()
        getgenv().BF_LOADED = true
    end)

    if not game:IsLoaded() then game.Loaded:Wait() end
end -- double load prevention

--
-- services
--

COREGUI = game:GetService("CoreGui")
TWEEN = game:GetService("TweenService")
INPUT = game:GetService("UserInputService")
REPLICATED = game:GetService("ReplicatedStorage")
PLAYERS = game:GetService("Players")
RUN = game:GetService("RunService")
HTTP = game:GetService("HttpService")

LocalPlayer = PLAYERS.LocalPlayer

do  -- base gui
    function randomString()
        local str = ""

        for i = 1, math.random(10, 20) do
            str = str..string.char(math.random(32, 126))
        end

        return str
    end

    root = Instance.new("ScreenGui")
    root.Name = randomString()

    if syn and syn.protect_gui then
        syn.protect_gui(root)
        root.Parent = COREGUI
    elseif get_hidden_gui or gethui then
        local hiddenUI = get_hidden_gui or gethui
        root.Parent = hiddenUI()
    else
        root.Parent = COREGUI
    end

    secondaryRoot = Instance.new("Frame")
    secondaryRoot.Parent = root
    secondaryRoot.Size = UDim2.fromScale(1, 1)
    secondaryRoot.BackgroundTransparency = 1
    secondaryRoot.BorderSizePixel = 0
end -- base gui -- globals exposed: root

--
-- constants
--

cGui = {
    ["BackgroundColor"] = Color3.fromRGB(12, 13, 20),
    ["BackgroundColorDark"] = Color3.fromRGB(4, 4, 7),
    ["BackgroundColorLight"] = Color3.fromRGB(32, 35, 56),
    ["ForegroundColor"] = Color3.fromRGB(255, 255, 255),
    ["AccentColor"] = Color3.fromRGB(10, 162, 175),
    ["Font"] = Enum.Font.Ubuntu,

    ["LabelButtonHeight"] = 25,
    ["ButtonHeightLarge"] = 30,
    ["CategoryHeight"] = 32,

    ["CheckboxSize"] = 25
}

do  -- gui components
    Gui = {}
    Gui.__index = Gui

    -- creates a TextLabel with default font, no background (default color is light)
    -- and no border
    function Gui.createText(parent, size)
        size = size or 12

        local label = Instance.new("TextLabel")
        label.Parent = parent
        label.BackgroundColor3 = cGui.BackgroundColorLight
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.TextColor3 = cGui.ForegroundColor
        label.Font = cGui.Font
        label.TextSize = size

        return label
    end

    -- creates a ScrollingFrame which takes up the entire parent by default
    function Gui.createScroll(parent)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Parent = parent
        scroll.BorderSizePixel = 0
        scroll.BackgroundTransparency = 1
        scroll.Size = UDim2.fromScale(1, 1)
        scroll.Position = UDim2.fromOffset(0, 0)
        scroll.ScrollBarImageColor3 = cGui.ForegroundColor
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.fromScale(1, 0)
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.ScrollBarThickness = 3

        return scroll
    end

    function Gui.createListLayout(parent, horizAlign, padding)
        local listLayout = Instance.new("UIListLayout")
        listLayout.Parent = parent

        if padding then
            listLayout.Padding = UDim2.fromOffset(0, padding).Y
        end

        listLayout.HorizontalAlignment = horizAlign
        listLayout.FillDirection = Enum.FillDirection.Vertical
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder

        return listLayout
    end

    -- creates a ScrollingFrame with a vertical UIListLayout inside.
    function Gui.createListScroll(parent, padding)
        local scroll = Gui.createScroll(parent)
        Gui.createListLayout(scroll, Enum.HorizontalAlignment.Center, padding)

        return scroll
    end

    -- creates a TextLabel with callback for MouseButton1, no background
    function Gui.createLabelButton(parent, labelText, cb)
        local label = Gui.createText(parent, cGui.LabelButtonHeight * 0.75)
        label.Text = labelText
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Size = UDim2.new(1, 0, 0, cGui.LabelButtonHeight)

        label.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                cb()
            end
        end)

        return label
    end

    -- creates a bold, centered TextLabel intended to be used as a category label for ScrollingFrames
    function Gui.createCategoryLabel(parent, labelText)
        local label = Gui.createText(parent, cGui.CategoryHeight * 0.75)
        label.BackgroundTransparency = 0.9
        label.BackgroundColor3 = cGui.BackgroundColorDark
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Bottom
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Size = UDim2.new(1, 0, 0, cGui.CategoryHeight)
        label.RichText = true
        label.Text = "<b>"..labelText.."</b>"

        return label
    end

    -- creates a larger TextLabel with a background color and on/off state
    function Gui.createLabelButtonLarge(parent, labelText, cb)
        local label = Gui.createText(parent, cGui.ButtonHeightLarge * 0.8)
        label.BackgroundTransparency = 0.5
        label.BackgroundColor3 = cGui.BackgroundColorLight
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Size = UDim2.new(0.95, 0, 0, cGui.ButtonHeightLarge)
        label.Text = labelText

        local labelInfo = {}
        labelInfo.Label = label
        labelInfo.SetActive = function(active)
            local tweenInfo = TweenInfo.new(0.15)
            local goal = {}

            if active then
                goal.BackgroundColor3 = cGui.AccentColor
            else
                goal.BackgroundColor3 = cGui.BackgroundColorLight
            end

            local tween = TWEEN:Create(label, tweenInfo, goal)

            tween:Play()
        end

        label.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                cb(labelInfo.SetActive, input.UserInputType)
            end
        end)

        return labelInfo
    end

    -- creates a checkbox component, with callback and initial value options
    function Gui.createCheckbox(parent, labelText, cb, initial)
        local cSpacing = 5

        local checkbox = Instance.new("Frame")
        checkbox.Parent = parent
        checkbox.BorderSizePixel = 0
        checkbox.BackgroundTransparency = 1
        checkbox.Size = UDim2.new(1, 0, 0, cGui.CheckboxSize)

        local indicator = Instance.new("Frame")
        indicator.Parent = checkbox
        indicator.BorderSizePixel = 0
        indicator.BackgroundColor3 = cGui.BackgroundColorLight
        indicator.Size = UDim2.fromOffset(cGui.CheckboxSize, cGui.CheckboxSize)
        indicator.Position = UDim2.fromScale(0, 0)

        local label = Gui.createText(checkbox, cGui.CheckboxSize * 0.75)
        label.Text = labelText
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Size = UDim2.new(1, -(cGui.CheckboxSize + cSpacing), 0, cGui.CheckboxSize)
        label.Position = UDim2.fromOffset(cGui.CheckboxSize + cSpacing, 0)

        local checked = initial

        local function updateColor()
            local tweenInfo = TweenInfo.new(0.15)
            local goal = {}

            if checked then
                goal.BackgroundColor3 = cGui.AccentColor
            else
                goal.BackgroundColor3 = cGui.BackgroundColorLight
            end

            local tween = TWEEN:Create(indicator, tweenInfo, goal)

            tween:Play()
        end

        updateColor()

        checkbox.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

            checked = not checked

            updateColor()

            cb(checked)
        end)

        return checkbox
    end
end -- gui components -- globals exposed: Gui

do  -- config & bindings
    local ConfigManager = {}
    ConfigManager.__index = ConfigManager

    function ConfigManager.new()
        local obj = {}
        setmetatable(obj, ConfigManager)

        obj.Filename = "fumo.json"
        obj.Value = nil
        obj.Default = {
            ["version"] = nil, -- for version check
            ["keybinds"] = {
                ["TabCharacters"] = Enum.KeyCode.One.Name,
                ["TabOptions"] = Enum.KeyCode.Two.Name,
                ["TabDocs"] = Enum.KeyCode.Three.Name,
                ["TabAnims"] = Enum.KeyCode.Four.Name,
                ["TabWaypoints"] = Enum.KeyCode.Five.Name,
                ["TabWelds"] = Enum.KeyCode.Six.Name,
                ["TabSettings"] = Enum.KeyCode.Seven.Name,
                ["HideGui"] = Enum.KeyCode.F1.Name,
                ["MapVis"] = Enum.KeyCode.N.Name,
                ["MapView"] = Enum.KeyCode.M.Name,
                ["RaySit"] = Enum.KeyCode.E.Name,
                ["Exit"] = Enum.KeyCode.Zero.Name
            },
            ["orbitTp"] = false,
            ["debug"] = false
        }

        obj.UseFs = true

        if not writefile then
            log("WARNING: No file write access. Config will not save or load.")
            obj.UseFs = false
        end

        obj:load()
        obj:checkMissingKeys()

        return obj
    end

    function ConfigManager:checkMissingKeys()
        local shouldSave = false

        -- recursively check if anything is missing.
        local function checkTable(t, default)
            for k, v in pairs(default) do
                if t[k] == nil then
                    t[k] = v
                    shouldSave = true
                elseif type(v) == "table" then
                    checkTable(t[k], v)
                end
            end
        end

        checkTable(self.Value, self.Default)

        if shouldSave then self:save() end
    end

    function ConfigManager:setDefault()
        self.Value = self.Default
        self:save()
    end

    function ConfigManager:save()
        if not self.UseFs then return end

        local str = HTTP:JSONEncode(self.Value)
        writefile(self.Filename, str)
    end

    function ConfigManager:load()
        if not self.UseFs then self.Value = self.Default return end

        if not pcall(function() readfile(self.Filename) end) then
            log("Creating new config file.")
            self:setDefault()
        else
            local success = pcall(function()
                self.Value = HTTP:JSONDecode(readfile(self.Filename))
            end)

            if not success then
                log("WARNING: Config data is invalid. Restoring defaults...")
                self:setDefault()
            end
        end
    end

    config = ConfigManager.new()

    local KeybindManager = {}
    KeybindManager.__index = KeybindManager

    function KeybindManager.new(configManager)
        local obj = {}
        setmetatable(obj, KeybindManager)

        obj.Config = configManager
        obj.Keybinds = configManager.Value.keybinds

        obj._lKeyPress = INPUT.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard and not
                INPUT:GetFocusedTextBox() then
                obj:_keyPress(input.KeyCode)
            end
        end)

        obj.Bindings = {}

        obj.Disabled = false

        return obj
    end

    function KeybindManager:rebind(name, key)
        self.Keybinds[name] = key.Name
        self.Config:save()
    end

    function KeybindManager:unbind(name)
        self.Keybinds[name] = -1
        self.Config:save()
    end

    function KeybindManager:bind(name, del)
        if self.Bindings[name] then
            log("WARNING: Binding the same action twice is unsupported!")
        end

        self.Bindings[name] = del
    end

    function KeybindManager:_keyPress(code)
        if self.Disabled then return end

        for k, v in pairs(self.Keybinds) do
            if v == code.Name then
                local del = self.Bindings[k]
                if del then del() end

                return
            end
        end
    end

    function KeybindManager:destroy()
        self._lKeyPress:Disconnect()
    end

    binds = KeybindManager.new(config)
end -- config & bindings -- globals exposed: config, binds

do  -- disable stuff
    local mainGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("MainGui")
    toggleButton = mainGui:FindFirstChild("MainFrame"):FindFirstChild("ToggleButton")
    toggleButton.Visible = false -- disable the default character selector

    settings = mainGui:FindFirstChild("SettingsFrame")
    settings.Visible = false -- disable the default settings
end -- disable stuff -- globals exposed: toggleButton & settings

do  -- tabcontrol
    --
    -- constants
    --

    cTabContentWidth = 250
    cTabContentHeight = 750 / 1080

    cTabWidth = 175
    cTabHeight = 30

    cTabWidthSmall = 45

    cTabSize = UDim2.fromOffset(cTabWidth, cTabHeight)
    cTabSizeSmall = UDim2.fromOffset(cTabWidthSmall, cTabHeight)

    cTabPosOpen = UDim2.fromScale(0, 0.5)
    cTabPosClosed = UDim2.new(0, -cTabContentWidth, 0.5, 0)

    cTabContainerPosOpen = UDim2.new(0, cTabContentWidth, 0.5, 0)
    cTabContainerPosClosed = UDim2.fromScale(0, 0.5)

    --
    -- class def
    --

    TabControl = {}

    TabControl.__index = TabControl

    function TabControl.new(parent, binds)
        local obj = {}
        setmetatable(obj, TabControl)

        obj.Parent = parent
        obj.Binds = binds

        local tabContainer = Instance.new("Frame")
        tabContainer.Parent = parent
        tabContainer.BackgroundTransparency = 1
        tabContainer.BorderSizePixel = 0
        tabContainer.AnchorPoint = Vector2.new(0, 0.5)
        tabContainer.AutomaticSize = Enum.AutomaticSize.Y
        tabContainer.Size = UDim2.fromOffset(cTabWidth, 0)
        tabContainer.Position = cTabContainerPosClosed

        Gui.createListLayout(tabContainer, Enum.HorizontalAlignment.Left)

        tabContainer.MouseEnter:Connect(function()
            obj:_setTabsExpanded(true)
        end)

        tabContainer.MouseLeave:Connect(function()
            obj:_setTabsExpanded(false)
        end)

        obj.TabContainer = tabContainer

        obj.TabButtons = {}
        obj.Tabs = {}

        return obj
    end

    function TabControl:setTabsVisible(visible)
        self.TabContainer.Visible = visible
    end

    function TabControl:createTabButton(label, abbrev)
        local tab = Gui.createText(self.TabContainer, cTabHeight * 0.75)
        tab.Active = true
        tab.BackgroundTransparency = 0.3
        tab.BackgroundColor3 = cGui.BackgroundColorDark
        tab.Text = abbrev
        tab.TextXAlignment = Enum.TextXAlignment.Center
        tab.TextYAlignment = Enum.TextYAlignment.Center
        tab.AnchorPoint = Vector2.new(0, 0.5)
        tab.Size = cTabSizeSmall

        local tabButtonData = {}
        tabButtonData.Label = label
        tabButtonData.Abbrev = abbrev
        tabButtonData.Tab = tab

        self.TabButtons[#self.TabButtons + 1] = tabButtonData

        return tabButtonData
    end

    function TabControl:createTab(label, abbrev, bindName)
        local tabButtonData = self:createTabButton(label, abbrev)

        -- tab content
        local content = Instance.new("Frame")
        content.Parent = self.Parent
        content.Active = true
        content.Name = "Content"
        content.BackgroundTransparency = 0.1
        content.BorderSizePixel = 0
        content.BackgroundColor3 = cGui.BackgroundColorDark
        content.AnchorPoint = Vector2.new(0, 0.5)
        content.Size = UDim2.new(0, cTabContentWidth, cTabContentHeight, 0)
        content.Position = cTabPosClosed

        -- functions (open/close)
        local isOpen = false
        local tween = nil

        local function getOpen() return isOpen end

        local function setOpen(open, shouldTween)
            if isOpen == open then return end

            -- check if other tabs are open
            local othersOpen = false

            for k, v in pairs(self.Tabs) do
                if v.Button.Label ~= label and v.GetOpen() then
                    othersOpen = true
                    break
                end
            end

            -- tween
            local tweenInfo = TweenInfo.new(0.15)
            local goal = {}
            local tabGoal = {}
            local tabContainerGoal = {}

            if open then
                goal.Position = cTabPosOpen
                tabContainerGoal.Position = cTabContainerPosOpen
                tabGoal.BackgroundColor3 = cGui.BackgroundColorLight

                for k, v in pairs(self.Tabs) do
                    if v.Button.Label ~= label then
                        v.SetOpen(false, false)
                    end
                end
            else
                goal.Position = cTabPosClosed
                tabContainerGoal.Position = cTabContainerPosClosed
                tabGoal.BackgroundColor3 = cGui.BackgroundColorDark
            end

            -- if two keys are pressed at once this will prevent the tween from completing when the tab should be closed
            if tween then tween:Cancel() end

            if shouldTween and not othersOpen then
                tween = TWEEN:Create(content, tweenInfo, goal)
                tween:Play()

                tween.Completed:Connect(function()
                    tween = nil
                end)
            else
                content.Position = goal.Position
            end

            local tabContainerTween = TWEEN:Create(self.TabContainer, tweenInfo, tabContainerGoal)
            tabContainerTween:Play()

            local tabTween = TWEEN:Create(tabButtonData.Tab, tweenInfo, tabGoal)
            tabTween:Play()

            isOpen = open
        end

        tabButtonData.Tab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                setOpen(not isOpen, true)
            end
        end)

        local tabData = {}
        tabData.Button = tabButtonData
        tabData.GetOpen = getOpen
        tabData.SetOpen = setOpen
        tabData.IsButton = false

        self.Tabs[#self.Tabs + 1] = tabData

        if bindName then
            self.Binds:bind(bindName, function()
                setOpen(not isOpen, true)
            end)
        end

        return content
    end

    function TabControl:closeAllTabs()
        for k, v in pairs(self.Tabs) do
            v.SetOpen(false, true)
        end
    end

    function TabControl:removeTabButton(info)
        info.Tab:Destroy()

        for k, v in pairs(self.TabButtons) do
            if v == info then
                self.TabButtons[k] = nil
                break
            end
        end
    end

    function TabControl:setTabOpen(label, open)
        for k, v in pairs(self.Tabs) do
            if v.Button.Label == label then
                if open == nil then
                    open = not v.GetOpen()
                end

                v.SetOpen(open, true)
                break
            end
        end
    end

    function TabControl:_setTabsExpanded(expanded)
        local tweenInfo = TweenInfo.new(0.15)

        local goal = {}
        local tabContainerGoal = {}

        if expanded then
            goal.Size = cTabSize
            tabContainerGoal.Size = UDim2.fromOffset(cTabWidth, 0)
        else
            goal.Size = cTabSizeSmall
            tabContainerGoal.Size = UDim2.fromOffset(cTabWidthSmall, 0)
        end

        for k, v in pairs(self.TabButtons) do
            if v then
                if expanded then
                    v.Tab.Text = v.Label
                else
                    v.Tab.Text = v.Abbrev
                end

                local tween = TWEEN:Create(v.Tab, tweenInfo, goal)
                tween:Play()
            end
        end

        local tabContainerTween = TWEEN:Create(self.TabContainer, tweenInfo, tabContainerGoal)
        tabContainerTween:Play()
    end
end -- tabcontrol -- globals exposed: TabControl

--
-- random functions
--

function teleport(pos)
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum.SeatPart then
        hum.Sit = false
        wait()
    end

    local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local origPos = root.CFrame
    root.CFrame = pos

    return origPos
end

tabControl = TabControl.new(root, binds)

do  -- characters
    -- constants

    local cCharacters = {}

    for k, v in pairs(LocalPlayer.PlayerGui.MainGui.MainFrame.ScrollingFrame:GetChildren()) do -- steal from the gui instead of the replicated list, which does not include badge chars
        if v:IsA("TextButton") then
            cCharacters[#cCharacters + 1] = v.Name
        end
    end

    table.sort(cCharacters)

    -- interface

    local charactersTab = tabControl:createTab("Characters", "1C", "TabCharacters")

    local characterScroll = Gui.createListScroll(charactersTab)
    characterScroll.Size = characterScroll.Size - UDim2.fromOffset(0, cGui.CheckboxSize + cGui.LabelButtonHeight)
    characterScroll.Position = characterScroll.Position + UDim2.fromOffset(0, cGui.CheckboxSize + cGui.LabelButtonHeight)

    local shouldReplaceHumanoid = false

    local humanoidCheckbox = Gui.createCheckbox(charactersTab, "Replace Humanoid", function(checked)
        shouldReplaceHumanoid = checked
    end)

    local jumpListener = nil

    local function replaceHumanoid(char, resetCam)
        local hum = char:FindFirstChildOfClass("Humanoid")
        local newHum = hum:Clone()
        hum:Destroy()
        newHum.Parent = char

        if resetCam then
            workspace.CurrentCamera.CameraSubject = char

            if not jumpListener then
                log("connecting jump listener")
                jumpListener = INPUT.InputBegan:Connect(function(input)
                    if not INPUT:GetFocusedTextBox() and
                        input.UserInputType == Enum.UserInputType.Keyboard and
                        input.KeyCode == Enum.KeyCode.Space then
                            newHum.Jump = true
                    end
                end)
            end
        end
    end

    function disconnectJump()
        if jumpListener then
            log("disconnecting jump listener")
            jumpListener:Disconnect()
            jumpListener = nil
        end
    end

    local replaceNowButton, _ = Gui.createLabelButton(charactersTab, "Replace Humanoid Now", function()
        replaceHumanoid(LocalPlayer.Character, true)
    end)

    replaceNowButton.Position = UDim2.fromOffset(0, cGui.CheckboxSize)

    local waitingForSwitch = false

    local function switchCharacter(name)
        disconnectJump()

        REPLICATED.ChangeChar:FireServer(name)

        if waitingForSwitch or not shouldReplaceHumanoid then return end
        waitingForSwitch = true

        local char = LocalPlayer.CharacterAdded:Wait()
        replaceHumanoid(char, false)

        waitingForSwitch = false
    end

    for k, name in pairs(cCharacters) do
        Gui.createLabelButton(characterScroll, name, function()
            switchCharacter(name)
        end)
    end
end -- characters -- globals exposed: disconnectJump

do  -- options
    local cOptionSpacing = 5

    local optionsTab = tabControl:createTab("Options", "2O", "TabOptions")

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Parent = optionsTab
    optionsFrame.Name = "Options"
    optionsFrame.BackgroundTransparency = 1
    optionsFrame.BorderSizePixel = 0
    optionsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    optionsFrame.AutomaticSize = Enum.AutomaticSize.Y
    optionsFrame.Size = UDim2.fromScale(1, 0)
    optionsFrame.Position = UDim2.fromScale(0.5, 0.5)

    local optionButtonCount = 0

    local function createOptionsButton(labelText, cb)
        local labelInfo = Gui.createLabelButtonLarge(optionsFrame, labelText, function()
            tabControl:closeAllTabs()
            cb()
        end)

        local label = labelInfo.Label

        label.Position = UDim2.new(0.5, 0, 0, optionButtonCount * (cGui.ButtonHeightLarge + cOptionSpacing))

        optionButtonCount = optionButtonCount + 1
    end

    createOptionsButton("Toggle Anti-Grief", function()
        if _G.GlobalDebounce then return end

        _G.GlobalDebounce = true
        REPLICATED.UIRemotes.SetColl:FireServer()
        wait(1)
        _G.GlobalDebounce = false
    end)

    createOptionsButton("Day/Night Settings", function()
        if _G.GlobalDebounce then return end

        _G.GlobalDebounce = true
        REPLICATED.ClientUIEvents.OpenClose:Fire("DayNightSetting", true)
        wait(0.6)
        _G.GlobalDebounce = false
    end)
end -- options

do  -- knowledgebase UI
    local cDocsWidth = 900 / 1920
    local cDocsHeight = 700 / 1080

    local cDocsPosOpen = UDim2.fromScale(0.5, 0.5)
    local cDocsPosClosed = UDim2.fromScale(0.5, 1.5)

    local cDocsTitleHeight = 40
    local cDocsPadding = 5
    local cDocsCloseSize = 20

    local docsFrame = Instance.new("Frame")
    docsFrame.Parent = root
    docsFrame.Name = "Knowledgebase"
    docsFrame.Transparency = 1
    docsFrame.BackgroundColor3 = cGui.BackgroundColorDark
    docsFrame.BorderSizePixel = 1
    docsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    docsFrame.Size = UDim2.fromScale(cDocsWidth, cDocsHeight)
    docsFrame.Position = cDocsPosClosed

    local docsClose = Gui.createText(docsFrame, cDocsCloseSize)
    docsClose.Active = true
    docsClose.TextXAlignment = Enum.TextXAlignment.Center
    docsClose.TextYAlignment = Enum.TextYAlignment.Center
    docsClose.AnchorPoint = Vector2.new(1, 0)
    docsClose.Size = UDim2.fromOffset(cDocsCloseSize, cDocsCloseSize)
    docsClose.Position = UDim2.fromScale(1, 0)
    docsClose.Text = "x"

    local docsContentScroll = Gui.createScroll(docsFrame)

    local docsTitle = Gui.createText(docsContentScroll, cDocsTitleHeight * 0.9)
    docsTitle.TextXAlignment = Enum.TextXAlignment.Left
    docsTitle.TextYAlignment = Enum.TextYAlignment.Center
    docsTitle.Size = UDim2.new(1, -cDocsPadding, 0, cDocsTitleHeight)
    docsTitle.Position = UDim2.fromOffset(cDocsPadding, cDocsPadding)
    docsTitle.TextTruncate = Enum.TextTruncate.AtEnd

    local docsContent = Gui.createText(docsContentScroll, 18)
    docsContent.TextXAlignment = Enum.TextXAlignment.Left
    docsContent.TextYAlignment = Enum.TextYAlignment.Bottom
    docsContent.AutomaticSize = Enum.AutomaticSize.Y
    docsContent.Size = UDim2.new(0.8, -cDocsPadding, 0, 0)
    docsContent.Position = UDim2.fromOffset(cDocsPadding, cDocsTitleHeight + cDocsPadding)
    docsContent.TextWrapped = true
    docsContent.RichText = true

    local docsOpen = false

    local function setDocsOpen(open)
        if open == docsOpen then return end

        local tweenInfo = TweenInfo.new(0.15)
        local goal = {}

        if open then
            goal.Position = cDocsPosOpen
            goal.Transparency = 0.1
        else
            goal.Position = cDocsPosClosed
            goal.Transparency = 1
        end

        local tween = TWEEN:Create(docsFrame, tweenInfo, goal)

        tween:Play()

        docsOpen = open

        tween.Completed:Wait()
        if open then
            docsFrame.Transparency = 0
            docsFrame.BackgroundTransparency = 0.1
        end
    end

    function openPage(info)
        docsTitle.Text = info.Label
        docsContent.Text = info.Content

        setDocsOpen(true)
    end

    docsClose.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            setDocsOpen(false)
        end
    end)

    local docsTab = tabControl:createTab("Knowledgebase", "3K", "TabDocs")

    local docsScroll = Gui.createListScroll(docsTab)

    function createKnowledgebaseCategory(name)
        Gui.createCategoryLabel(docsScroll, name)
    end

    function addDoc(info)
        Gui.createLabelButton(docsScroll, info.Label, function()
            openPage(info)
        end)
    end
end -- knowledgebase UI -- globals exposed: addDoc, openPage

do  -- docs content
    createKnowledgebaseCategory("Meta")

    local cAboutContent = [[
This script is dedicated to Become Fumo, and it has functions specific to it.
It provides replacements for some of Become Fumo's default UI components, as they currently lack polish.
It is intended to work alongside Infinite Yield and DEX, not replace them.
Information on certain features and bugs is provided in this knowledgebase. Credit for this information is provided whenever I can remember it. Please note that 'disclosed' and 'discovered' don't mean the same thing. I don't know who discovered most of these bugs.
For any questions, you can ask me in game.
As an alternative to clicking the tabs, you can navigate to any tab except the info tab through the number keys.
At any time, you can press [0] to close the script and reset everything back to normal.
<b>Credits:</b>
- xowada - Detaching and controlling accessories
- AyaShameimaruCamera - Replace Humanoid & Inspiration
- FutoLurkingAround - Emotional Support
- LordOfCatgirls - Early user & Welds research
- gandalf872 - ? & Welds research
- zorro - hat
    ]]

    local cAboutInfo = {}
    cAboutInfo.Label = "About this Script"
    cAboutInfo.Content = cAboutContent

    addDoc(cAboutInfo)

    local cChangelogContent = [[
<b>1.5.6</b>
- Added labels to the Knowledgebase
- Scroll now zooms the map in and out while expanded
- (BORING!) Converted minimap objects to lua classes
- Added seats to the map

<b>1.5.5</b>
- Added the version of the Drip animation that has blended animations
- Posted A3, explaining the real situation in full.
- Updated the Etiquette article, which now contains <i>real policies</i>. The contents differ slightly from A2. Please read it.
- Updated credits

<b>1.5.4</b>
- (BORING!) Code quality improvements to GUI
    - Moved constants into an object
    - Put common GUI components into a static class
- (BORING!) Get rid of the WORKSPACE global
- (BORING!) Get rid of stupid layout code in favor of UIListLayout
- Add category labels to the settings tab
- Typing nothing in the animations speed field now sets the speed back to 1
- Added a hotkey (default F1) which will hide all guis except the tab content (i.e. the tab buttons and the map). You can still use tab hotkeys while this is active.
- A1 has been removed from the main menu, but is still accessible through 3K. Its contents have not changed since 1.5.3.
- Added a link to announcement A2. <b>Please read it!</b>

<b>1.5.3</b>
- Added an announcement about the new character checks. <b>Please read it!</b>
- (BORING!) Refactor Knowledgebase articles to use multiline strings instead of concatenation
- The minimap now renders under the tab gui
- The minimap now scales to display size
- Tweaked behavior of minimap keybinds
- Added a label under all players in the minimap while expanded (sometimes unreadable, but should help)
- (BORING!) Increased code quality with minimap player handling

<b>1.5.2</b>
- Added September to the animations tab
- Remove bobbing direction and make it always vertical, as rotation seems to cause deaths, especially when target is face down
- Added support for attaching to people with no Humanoid/replaced Humanoid
- Added a debug overlay which can be enabled through 7S
- Make the movement checker more strict, but consider rotation as motion (i.e. dance3 torso parts will no longer bob)
- Return parts to orbit when target character dies
- Added Motor6Ds (aka limbs and head) to the welds list. This breaks everything, so expect frequent deaths when removing your head or any other integral part.

<b>1.5.1</b>
- Added lerps back to mouse movement and orbit of weld parts + additional tweaking
- Blacklist music region bounding boxes and the main invis walls from weld raycast
- Make bobbing movements be the correct direction instead of always up/down
- Try to maximize fps during removal of welds by teleporting to a remote location (disabled by default)
* Please try enabling it in the 7S tab ('Orbit Teleport') and report if it improves rate of death on removal.
- Remove unnecessary code and use BodyGyro for all rotations
- Limit raycasting to once per frame instead of once per part per frame
- Automatically unweld children of parts set to be put into orbit (i.e. for Doremy's hat, the 'part of it yes' is now orbited first automatically)
- Automatically unweld parts that are welded twice (i.e. for Nazrin's 'Neck' part, which is welded twice to the torso, both welds are now destroyed automatically)

<b>1.5.0 - Minimap</b>
- Added a minimap. Due to performance overhead and incompleteness, the map is unloaded by default. Press N (by default) to toggle map visiblity and M to toggle zoomed view.
- Fixed animations still being highlighted after character is reset
- Fixed badged characters not appearing in the character list when they are unlocked
- Switched to a JSON config system. In your workspace folder, you can now delete the file named 'fumofumo.txt'.
- You can now rebind keybinds to other keys if you wish, by using the 7S tab. Tab numbers will not change with keybind changes. To set a keybind to blank, right click it.
- Since sitting is fixed, the raycast sit feature has been moved to a keybind (E by default) and is now extra janky for some reason.

<b>1.4.5</b>
- Holding down middle click while dragging multiple parts no longer causes them to get closer to the camera
- Parts no longer appear too high when attached to players
- Parts welded to non-standard parts (such as Doremy's dress' balls) can now be attached to proper positions on other characters
- Stationary target check has been made a bit more strict
- Attempt to improve stability of initially detaching welds
- The middle click raycast for sitting no longer runs in guis
* Stability issues likely persist. Continue to report them to me.

<b>1.4.4</b>
- Better ensure constant motion of detached accessories

<b>1.4.3</b>
- Fix accessory teleport target not resetting when character reset
- Fix middle click moving accessories while in menu

<b>1.4.2</b>
- Fix some situations where part rotation is wrong (i.e. Nazrin's inner ear parts)

<b>1.4.1</b>
- Refactor the tab system and add an alert when a new version is run. Thanks for reading the changelog!

<b>1.4.0 - Hats Come Alive</b>
- Add the ability to detach and control accessories by middle clicking welds in the 6R menu and dragging while middle clicking
- Add article on detached accessories

<b>1.3.7</b>
- Give the ability to sit in any seat by middle clicking its approximate location

<b>1.3.6</b>
- Attempt to fix some deaths on laggy systems
- Fix early teleport back when removing multiple welds at once

<b>1.3.5</b>
- GUI tweaks

<b>1.3.4</b>
- Flash weld target on right click

<b>1.3.3</b>
- I hate Yuyuko
- Scale the buttons for ridiculously long weld names

<b>1.3.2</b>
- Add some UI scaling for better usability at lower resolution
- Remove mention of Doremy's hat's ball

<b>1.3.1</b>
- Minor fixes

<b>1.3.0 - The Welds Update</b>
- Added a welds tab (6R) and populate it with a list of welds that can be deleted
- Added a Knowledgebase article on welds

<b>1.2.0</b>
- Added a Knowledgebase article on etiquette
- Add waypoints tab (5W) and add waypoints to most major locations outside of Memento Mori

<b>1.1.3</b>
- Increase maintainability by reusing the animation button style elsewhere
- Add category labels to the animations list

<b>1.1.2</b>
- Fix two tabs opening at once when pressing two keys simultaneously

<b>1.1.1</b>
- Fix tweens when using hotkeys to open menus

<b>1.1.0</b>
- Added an animations tab and added every significant animation default to the game (mostly emotes and arcade)
- Allow navigation through number keys

<b>1.0.0</b>
- Created a simple tab interface
- Replaced the default character select and options
    - Added options to replace the humanoid
- Added knowledgebase articles for the script and the replace humanoid option
- Added an about page
    ]]

    cChangelogInfo = {}
    cChangelogInfo.Label = "Changelog"
    cChangelogInfo.Content = cChangelogContent

    addDoc(cChangelogInfo)

    local cEtiquetteContent = [[
The policies outlined in this article were first introduced in Announcement A2.

The policies are guided by the following principles:
- <b>Respect the developers' decisions.</b> Be polite to them, and try to respect their decisions regarding the game.
- <b>Try to act PG-13 as much as possible.</b> Bypassing the swear filter is discouraged, and using animations to have sex with others is disallowed.
- <b>Avoid disturbing regular players.</b> Being annoying is not appreciated.
- <b>Avoid being a disappointment.</b> You know who you are.

Explicit policies are outlined below:
- <b>Do not depict fumo in inappropriate acts.</b> This covers both usage of animations and chat.
- <b>Do not take off fumos' clothing, and avoid making them bald.</b> Try to avoid traumatizing people. Removing accessories that are attached to the clothes or hair is ok.
- <b>Avoid hijacking the train.</b> Generally, this causes unnecessary disruption.
- <b>Do not attempt to access developer/contributor-only content*, especially while they are online.</b> Self-explanatory. *outside of testing
- <b>Do not share, or attempt to share, the script with other people.</b> If you have been issued a copy which bypasses the whitelist, <i>do not share it</i>.
    - Excerpts of the source, or the complete source, may be given to you if you request them from me.

The following policy only affects the 6R tab:
- <b>Do not give your parts to random players unless they ask.</b>

Restricted access to the script is possible with the violation of any of the above policies and principles. Restriction could last any amount of time, depending on level of infraction.
<i>Your behavior outside of the usage of this script is also covered by these rules.</i>
    ]]

    local cEtiquetteInfo = {}
    cEtiquetteInfo.Label = "Cheaters' Etiquette"
    cEtiquetteInfo.Content = cEtiquetteContent

    addDoc(cEtiquetteInfo)

    createKnowledgebaseCategory("Exploit Write-ups")

    local cHumanoidContent = [[
<i>Disclosed by: AyaShameimaruCamera</i>
<i>Scripting refined by: me</i>

The 'Replace Humanoid' option found in the Character menu bypasses the check for removal of any children of your character's Head/Torso by replacing the humanoid object with a clone.
Note that this script purposefully provides no way of deleting any specific part from your character, as the way they are designed is inconsistent. Use DEX to delete parts.
Attempting to remove parts like bows and hats without using this feature will result in your character being reset.
You should not use this if you only want to delete limbs, or descendants of your Head that aren't direct children, such as your eyes and face. Those can be deleted without using this feature.

The same functionality can be achieved using DEX only by duplicating your humanoid, deleting the original, and disabling and reenabling your camera, but it has more limitations. This script will replace the humanoid at almost the same time as you switch characters (as soon as the character is available by the CharacterAdded event). This will allow you to retain the ability to jump normally, and eliminates the need to reset the camera manually. Animations will be displayed client-side, but don't be fooled: they cannot be seen by others.

<b>The following actions are impossible to do with this feature active:</b>
1. Any emotes or animations (walk, idle, etc) including those provided by exploits. As mentioned above, they will be visible to you only (if at all).
2. Sitting in benches or on the train, or using the arcade.
3. Resetting your character. The only way to 'reset your character' is to switch characters.
4. Using tools or items. You may be able to hold them, but you cannot use them.

Generally speaking, most server side scripts affecting your character will no longer work.

Another button labeled 'Replace Humanoid Now' provides older functionality. It doesn't show animations client-side, it requires a custom key listener for jumping to work, and it requires resetting the camera. But, it activates the feature without needing to change characters. The benefit of this is you can use items or do things before you activate the feature (such as getting the red glow on Soul Edge).
    ]]

    local cHumanoidInfo = {}
    cHumanoidInfo.Label = "Replacing Humanoid"
    cHumanoidInfo.Content = cHumanoidContent

    addDoc(cHumanoidInfo)

    local cWeldsContent = [[
<i>Discovery & disclosure: gandalf872 and LordOfCatgirls</i>
<i>Scripting refined by: me</i>

The 'Remove Welds' tab serves as a successor to the 'Replace Humanoid' functionality. However, it cannot remove any parts that are not held on with welds. For those parts, continue to use 'Replace Humanoid.'

Many parts are held onto the fumo's head, torso, or limbs through welds. Deleting the welds will cause the parts to effectively be removed from your body. This script automates the process of removing welds.
Unlike 'Replace Humanoid,' removing welds through this script does not require the use of DEX or any other scripts.

Welds are named with the name of the anchor point (usually something like Head, Torso, etc), then a box character, then the name of the part (e.g. hat, clothes, shoes). This is how you should identify them in the list. If the name of a weld is ambiguous or unclear, right click it and the weld's Part1 ('target') will flash for a few seconds instead of the weld being deleted.
Much like Replace Humanoid, the functionality in this script can be achieved using DEX by removing the weld and quickly anchoring the part that fell. This method has proven to be unreliable and sometimes difficult to pull off, but best results are achieved by going to high locations like a hill or the treehouse.
Early findings indicate that leaving children in the object that falls (see Doremy's hat for an example) will make death after removal much more likely. As such, this script will clear all children of the target before removing the weld. The script will teleport you to the top of the treehouse to ensure that the part's falling distance is held relatively constant. After deleting the weld, the script waits around 1.5 seconds to anchor the part, as giving too little time has also resulted in death (for unknown reasons). After everything is done, the button you clicked will disappear and the script will teleport you back to your original location. Support exists for removing multiple welds at once, if you wanted to do that.

The method used in this script may still be unstable, causing death after minutes or hours. If this occurs, please report to me how long it took, which character, and which part you removed. Include as much detail as possible.

Please remember that the people who discovered this did not do it for you to take off your clothes. Please do not take off your clothes. Please do not take off your clothes. Ple
    ]]

    local cWeldsInfo = {}
    cWeldsInfo.Label = "Removing Welds"
    cWeldsInfo.Content = cWeldsContent

    addDoc(cWeldsInfo)

    local cDetachContent = [[
<i>Disclosure: xowada</i>
<i>Code basis: Infinite Yield</i>
<i>Scripting refined by: me</i>
The weld strategy to 'removing' parts from the character's body can also be used to detach and control them.
The BodyPosition class is used to control the parts after they have been detached, and a constant velocity is applied to them for (relative) stability (i.e. less death).
The Stepped event in RunService is used to control the parts, and set their position and rotation every frame. Paths for the objects can be made through functions of position offset to time.

This script has the parts orbit the player by default. If middle click is held, the parts will follow the mouse, and if the parts touch a player then they will attach to them as close to the correct position as possible.

The script still suffers from relative instability and death may occur frequently. Report these instances to me with as much detail as possible."
    ]]

    local cDetachInfo = {}
    cDetachInfo.Label = "Detaching Accessories"
    cDetachInfo.Content = cDetachContent

    addDoc(cDetachInfo)

    createKnowledgebaseCategory("Announcements")

    local cChecksContent = [[
Announcement, 2021/9/24
<i>Initial disclosure: initialfum</i>
On 09/23, initialfum disclosed that scary had planned to release a patch disabling the removal of parts in the next week.
On 09/24, I discovered these scripts (currently disabled as of writing) inside ReplicatedFirst.
These scripts have now been deobfuscated and inspected, and they appear to target specifically the movement of detached parts. For your reference, these scripts have been made available at: <i>https://pastebin.com/s3uwN4Z2</i>. The pastebin also contains comments on structure and function of each script. If you wish to view these scripts yourself, open DarkDex and browse ReplicatedFirst.

In short, these scripts target the modification of the character:
- I <i>know</i> that it targets movement functionality (as implemented by xowada) because it checks if certain instance types (BodyGyro, BodyPosition, BodyVelocity, BodyThrust, BodyAngularVelocity, and BodyForce) are added to RootPart (as far as I know, checking using this method does not work, but nonetheless it shows scary is targeting this script)
- I <i>know</i> that the new scripts will phone home to the server whenever something suspicious is done (ReplicatedStorage/DoCheck2) and every five seconds (ReplicatedFirst/DoCheck), after which the server will investigate.
    - I <i>suspect</i> that the both checks may also kick the player upon deleting parts/instances or otherwise modifying the character, but this behavior is unconfirmed.
- I <i>believe</i> that the tests scary performed a few days ago were targeting testing for this change, and possibly specifically me.

After discovering these unreleased changes, I recommend the following for <b>all users of this script</b>:
- Do not use the Replace Humanoid feature or the 6R tab prominently (i.e. avoid orbiting for long periods, removing your clothes, or anything that stands out).
- Avoid giving your parts to random people.
- Avoid using the above mentioned features near the developers (specifically scary and Naz). Using it around contributors (specifically zorro, cyrrots, and Anx) is probably safe.
- If these changes are pushed soon, <i>do not</i> try to bypass the new checks. If scary is serious about this enough to write checks to prevent it, please respect the decision for now.

As for the development of this script:
- This script's founding purpose was to remove parts, so it is slightly disheartening to see these changes being pushed. See the 1.0.0 changelog and you will know.
- Updates will likely slow down as the above mentioned features are not going to be maintained until their functionality is confirmed upon release of the checks.
- Upon release of the checks, the affected features will be disabled by default and may be accessible through a hidden config option.
- Focus will return to less 'destructive' parts of the script, including the minimap and animations tab.
- If you have any ideas for me to code, please tell me (I need ideas more than ever!)

Other information about the new checks and the fate of this script will be in this announcement. Pay attention to the changelog.

<i>This script is not dead yet!</i>
    ]]

    local cChecksInfo = {}
    cChecksInfo.Label = "ReplicatedFirst Scripts"
    cChecksInfo.Content = cChecksContent

    addDoc(cChecksInfo)

    local cA2Content = [[
Announcement, 2021/9/26

A1 is still available through the 3K menu.

A2 contains updates on the situation mentioned in A1, and also contains a set of policies that, by continuing to use this script, you are bound by. Please read both.
A2 is hosted on Google Docs, the link is in this pastebin: <i>https://pastebin.com/ssEg8dRd</i>.
If you wish to sign the document, please tell me. It may be used during negotiations.
    ]]

    local cA2Info = {}
    cA2Info.Label = "Update & Policies"
    cA2Info.Content = cA2Content

    addDoc(cA2Info)

    local cA3Content = [[
Announcement, 2021/9/26

Hello!

scary has responded to A2 and has explained the situation to me. In short, everybody who saw what he said in #fumo (including me) misunderstood the purpose of the checks.
The new checks <i>actually</i> cover the attachment of players to others <i>using body movers, the exact method I used to orbit parts</i> and saying naughty things.
The checks do not specifically target unwelding or removal of parts, but they will kill you if you remove anything from Torso (details currently unknown).

The policy changes outlined in A2 have gone into place already, and are available under the once-joking Etiquette article. The wishes by the developers (specifically removal of clothes), while not enforced by a check, are still present.
He has made the following recommendations to me:
1. Restrict the giving of parts to friends (specifically, don't give things to people who don't want them)
2. Restrict the removal of clothes

For the first point, no strict restriction is planned. He suggested restricting to friends, but I don't think that is necessary right now.
Please read the Etiquette document for details.

For the second point, a blacklist may go into place over time. Please use the features responsibly.

Your signatures in A2 were highly appreciated. Thank you for your help.
    ]]

    cA3Info = {}
    cA3Info.Label = "Update Again"
    cA3Info.Content = cA3Content

    addDoc(cA3Info)
end -- docs content -- globals exposed: cChangelogInfo, cA3Info

do  -- animation UI
    local cSpeedFieldSize = 25
    local cSpeedFieldPadding = 5

    local activeAnimations = {}
    local stoppingAnimations = {}

    local speed = 1

    local function adjustSpeed(target)
        if speed == target then return end

        log("adjusting speed to "..tostring(num))

        for k, v in pairs(activeAnimations) do
            if v then
                v:AdjustSpeed(target)
            end
        end

        speed = target
    end

    local animationsTab = tabControl:createTab("Animations", "4A", "TabAnims")

    local speedField = Instance.new("TextBox")
    speedField.Parent = animationsTab
    speedField.ClearTextOnFocus = false
    speedField.BackgroundColor3 = cGui.BackgroundColorLight
    speedField.BorderSizePixel = 1
    speedField.Font = cGui.Font
    speedField.TextSize = cGui.ButtonHeightLarge * 0.8
    speedField.TextColor3 = cGui.ForegroundColor
    speedField.Text = ""
    speedField.PlaceholderColor3 = Color3.fromRGB(127, 127, 127)
    speedField.PlaceholderText = "Speed"
    speedField.TextXAlignment = Enum.TextXAlignment.Left
    speedField.TextYAlignment = Enum.TextYAlignment.Center
    speedField.Size = UDim2.new(1, 0, 0, cSpeedFieldSize)
    speedField.Position = UDim2.fromScale(0, 0)

    speedField.FocusLost:Connect(function()
        if speedField.Text == "" then
            adjustSpeed(1)
        else
            local num = tonumber(speedField.Text)
            if num then
                adjustSpeed(num)
            end
        end
    end)

    local animationsScroll = Gui.createListScroll(animationsTab)
    animationsScroll.Size = animationsScroll.Size - UDim2.fromOffset(0, cSpeedFieldSize + cSpeedFieldPadding)
    animationsScroll.Position = animationsScroll.Position + UDim2.fromOffset(0, cSpeedFieldSize + cSpeedFieldPadding)

    local function stopAnimation(id)
        if activeAnimations[id] and not stoppingAnimations[id] then
            stoppingAnimations[id] = true
            activeAnimations[id]:Stop()
            activeAnimations[id]:Destroy()
            activeAnimations[id] = nil
            stoppingAnimations[id] = false
        end
    end

    function stopAllAnimations()
        for k, v in pairs(activeAnimations) do
            if v then
                stopAnimation(k)
            end
        end
    end

    local function playAnimation(id, cb)
        stopAnimation(id)

        local animator = LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")

        local animation = Instance.new("Animation")
        animation.AnimationId = id

        local animationTrack = animator:LoadAnimation(animation)

        animationTrack.Priority = Enum.AnimationPriority.Action
        animationTrack:Play()

        activeAnimations[id] = animationTrack
        animationTrack:AdjustSpeed(speed)

        animationTrack.Stopped:Connect(function()
            stopAnimation(id)
            cb()
        end)
    end

    function createAnimationCategory(name)
        Gui.createCategoryLabel(animationsScroll, name)
    end

    function createAnimationButton(info)
        local active = false

        Gui.createLabelButtonLarge(animationsScroll, info.Name, function(setActive)
            active = not active

            if active then
                playAnimation(info.Id, function()
                    setActive(false)
                    active = false
                end)
            else
                stopAnimation(info.Id)
            end

            setActive(active)
        end)
    end

    lCharacter3 = LocalPlayer.CharacterAdded:Connect(function(char)
        stopAllAnimations()
    end)
end -- animation UI -- globals exposed: createAnimationButton, createAnimationCategory, stopAllAnimations, lCharacter3

do  -- animations
    local function addAnimation(name, id)
        local info = {}
        info.Name = name
        info.Id = id

        createAnimationButton(info)
    end

    createAnimationCategory("Emotes")
    addAnimation("Wave", "rbxassetid://6235397232")
    addAnimation("Point", "rbxassetid://6237758978")
    addAnimation("Dance1", "rbxassetid://6237334056")
    addAnimation("Dance2", "rbxassetid://6237617098")
    addAnimation("Dance3", "rbxassetid://6237729300")
    addAnimation("Laugh", "rbxassetid://6237857610")
    addAnimation("Cheer", "rbxassetid://6235416318")
    addAnimation("Abunai", "rbxassetid://6384606896")
    addAnimation("Sonanoka", "rbxassetid://6384613936")
    addAnimation("Scarlet Police", "rbxassetid://6509462656")
    addAnimation("Caramell", "rbxassetid://6542355684")
    addAnimation("Swag", "rbxassetid://6659873025")
    addAnimation("Penguin", "rbxassetid://6898226631")
    addAnimation("September", "rbxassetid://7532444804")

    createAnimationCategory("Arcade")
    addAnimation("Taiko", "rbxassetid://7162205569")
    addAnimation("SDVX", "rbxassetid://7162634952")
    addAnimation("DDR", "rbxassetid://7162282756")
    addAnimation("Flip", "rbxassetid://7162815644")
    addAnimation("Drive", "rbxassetid://7162720899")
    addAnimation("Shoot", "rbxassetid://7162118758")
    addAnimation("Maimai", "rbxassetid://7162040292")

    createAnimationCategory("Misc Default")
    addAnimation("Drip", "rbxassetid://6573833053")
    addAnimation("Drip (w/ sitting)", "rbxassetid://6565089997")

    addAnimation("Walk", "rbxassetid://6235532038")
    addAnimation("Run", "rbxassetid://6235359704")
    addAnimation("Jump", "rbxassetid://6235182835")
    addAnimation("Fall", "rbxassetid://6235205527")
end -- animations

do  -- waypoints UI
    local waypointsTab = tabControl:createTab("Waypoints", "5W", "TabWaypoints")

    local waypointsScroll = Gui.createListScroll(waypointsTab)

    function createWaypointCategory(name)
        Gui.createCategoryLabel(waypointsScroll, name)
    end

    function createWaypointButton(info)
        Gui.createLabelButtonLarge(waypointsScroll, info.Name, function()
            teleport(info.CFrame)
        end)
    end
end -- waypoints UI -- globals exposed: createWaypointButton, createWaypointCategory

do  -- waypoints
    createWaypointCategory("Spawns")
    local cSpawnOffset = Vector3.new(0, 1, 0)

    local cSpawn1 = {}
    cSpawn1.Name = "Spawn (Cave)"
    cSpawn1.CFrame = CFrame.new(37.4692039, 19.4567928, 38.4004898, 1, 0, 0, 0, 1, 0, 0, 0, 1) + cSpawnOffset
    createWaypointButton(cSpawn1)

    local cSpawn2 = {}
    cSpawn2.Name = "Spawn (Large Hill)"
    cSpawn2.CFrame = CFrame.new(-46.0499954, 14.253479, -43.9750061, 1, 0, 0, 0, 1, 0, 0, 0, 1) + cSpawnOffset
    createWaypointButton(cSpawn2)

    local cSpawn3 = {}
    cSpawn3.Name = "Spawn (Ground)"
    cSpawn3.CFrame = CFrame.new(-0.0499948636, -4.746521, -4.97500801, 1, 0, 0, 0, 1, 0, 0, 0, 1) + cSpawnOffset
    createWaypointButton(cSpawn3)

    -----
    createWaypointCategory("Items")

    local cBurger = {}
    cBurger.Name = "Burger/Soda"
    cBurger.CFrame = CFrame.new(-12.6373434, -2.39721942, -104.279655, 0.999609232, -9.48658307e-09, -0.0279524103, 9.50391588e-09, 1, 4.87206442e-10, 0.0279524103, -7.5267359e-10, 0.999609232)
    createWaypointButton(cBurger)

    local cBun = {}
    cBun.Name = "Japari Bun (Rock)"
    cBun.CFrame = CFrame.new(44.2933311, 2.69040394, -174.404465, -0.926118135, 2.03467754e-09, -0.377233654, -1.18587207e-09, 1, 8.30502511e-09, 0.377233654, 8.13878565e-09, -0.926118135)
    createWaypointButton(cBun)

    local cShrimp = {}
    cShrimp.Name = "Shrimp Fry"
    cShrimp.CFrame = CFrame.new(23.7285004, -3.39721847, -38.656456, -0.999925613, 1.10185701e-08, 0.0121939164, 1.07577787e-08, 1, -2.14526548e-08, -0.0121939164, -2.13198827e-08, -0.999925613)
    createWaypointButton(cShrimp)

    local cIceCream = {}
    cIceCream.Name = "Ice Cream"
    cIceCream.CFrame = CFrame.new(47.6086464, -2.35769129, 86.1823273, -0.999982059, 1.08832019e-08, 0.00585500291, 1.07577787e-08, 1, -2.14526548e-08, -0.00585500291, -2.13892744e-08, -0.999982059)
    createWaypointButton(cIceCream)

    local cBike = {}
    cBike.Name = "Bike"
    cBike.CFrame = CFrame.new(41.1308136, -3.39721847, 70.4393082, 0.999999881, -4.17922266e-08, 0.000145394108, 4.18030872e-08, 1, -7.49089111e-08, -0.000145394108, 7.49150004e-08, 0.999999881)
    createWaypointButton(cBike)

    local cFishingRod = {}
    cFishingRod.Name = "Fishing Rod"
    cFishingRod.CFrame = CFrame.new(-50.5187149, 1.6041007, -120.919296, 0.998044968, 5.13549168e-08, -0.0625005439, -5.57155957e-08, 1, -6.80274113e-08, 0.0625005439, 7.13766752e-08, 0.998044968)
    createWaypointButton(cFishingRod)

    local cBaseball = {}
    cBaseball.Name = "Baseball Equipment"
    cBaseball.CFrame = CFrame.new(63.9862785, 1.61707997, -113.393738, 0.852416873, -1.00618301e-07, 0.522862673, 9.67299414e-08, 1, 3.47396458e-08, -0.522862673, 2.09638351e-08, 0.852416873)
    createWaypointButton(cBaseball)

    local cRifle = {}
    cRifle.Name = "LunarTech Rifle"
    cRifle.CFrame = CFrame.new(-76.0725632, -3.39721847, -122.150734, 0.00984575041, 1.867169e-08, -0.999951541, -1.71646324e-08, 1, 1.85035862e-08, 0.999951541, 1.69816179e-08, 0.00984575041)
    createWaypointButton(cRifle)

    local cGauntlet = {}
    cGauntlet.Name = "Buster Gauntlets"
    cGauntlet.CFrame = CFrame.new(3.52978015, 8.10278034, -103.847221, -0.999056339, -9.71976277e-08, 0.0434325524, -9.49071506e-08, 1, 5.47984236e-08, -0.0434325524, 5.06246529e-08, -0.999056339)
    createWaypointButton(cGauntlet)

    local cTrolldier = {}
    cTrolldier.Name = "Trolldier Set"
    cTrolldier.CFrame = CFrame.new(-57.4301414, 36.6266022, -77.7773438, 0.0280102566, 2.76124923e-09, 0.999607563, -8.18409589e-08, 1, -4.69047745e-10, -0.999607563, -8.17956973e-08, 0.0280102566)
    createWaypointButton(cTrolldier)

    local cSoulEdge = {}
    cSoulEdge.Name = "Soul Edge"
    cSoulEdge.CFrame = CFrame.new(62.3707314, 22.2510509, 45.5647964, -0.0124317836, 7.14263138e-08, -0.999922097, 3.7549458e-10, 1, 7.14271877e-08, 0.999922097, 5.12501597e-10, -0.0124317836)
    createWaypointButton(cSoulEdge)

    local cChair = {}
    cChair.Name = "Chair"
    cChair.CFrame = CFrame.new(-14.3926878, -3.39721847, -127.052185, -0.998602152, -1.55643036e-08, 0.0528521165, -2.24233379e-08, 1, -1.29184926e-07, -0.0528521165, -1.30189534e-07, -0.998602152)
    createWaypointButton(cChair)

    local cGigasword = {}
    cGigasword.Name = "Gigasword"
    cGigasword.CFrame = CFrame.new(-54.6563225, 22.4595356, -172.48053, 0.320373297, 5.91488103e-08, 0.947291434, 1.88988629e-08, 1, -6.88315112e-08, -0.947291434, 3.99545073e-08, 0.320373297)
    createWaypointButton(cGigasword)

    -----
    createWaypointCategory("Other (Expansion 0)")

    local cFire1 = {}
    cFire1.Name = "Campfire (Cave)"
    cFire1.CFrame = CFrame.new(50.5005188, -3.27936959, 45.8245049, 0.511625528, -1.06045634e-08, 0.859208643, 3.62333026e-08, 1, -9.23321064e-09, -0.859208643, 3.58559191e-08, 0.511625528)
    createWaypointButton(cFire1)

    local cFire2 = {}
    cFire2.Name = "Campfire (Ground)"
    cFire2.CFrame = CFrame.new(-35.0969467, -3.39721847, -5.80594683, -0.782029748, 2.27397319e-08, -0.623240769, 3.63110004e-08, 1, -9.07598174e-09, 0.623240769, -2.97281399e-08, -0.782029748)
    createWaypointButton(cFire2)

    local cFire3 = {}
    cFire3.Name = "Campfire (Poolside)"
    cFire3.CFrame = CFrame.new(49.8565903, 1.61707997, -102.113022, 0.53096503, -5.22703569e-09, -0.847393513, 5.28910675e-08, 1, 2.69724456e-08, 0.847393513, -5.9140973e-08, 0.53096503)
    createWaypointButton(cFire3)

    local cMikoBorgar = {}
    cMikoBorgar.Name = "Miko Borgar (Door)"
    cMikoBorgar.CFrame = CFrame.new(-1.05410039, -3.39721847, -82.1947021, 0.998766482, -2.69013523e-08, -0.0496555455, 3.06295682e-08, 1, 7.43202406e-08, 0.0496555455, -7.57493979e-08, 0.998766482)
    createWaypointButton(cMikoBorgar)

    local cPond = {}
    cPond.Name = "Pond"
    cPond.CFrame = CFrame.new(-51.4066544, -2.45410466, -103.242828, -0.937839568, 3.27229159e-08, 0.347069085, 3.4841225e-08, 1, -1.36675046e-10, -0.347069085, 1.19641328e-08, -0.937839568)
    createWaypointButton(cPond)

    local cPool1 = {}
    cPool1.Name = "Pool (Steps)"
    cPool1.CFrame = CFrame.new(69.1763077, -3.39721847, -45.1866875, 0.99876368, -2.64645528e-09, -0.0496931486, -1.14304344e-09, 1, -7.62298313e-08, 0.0496931486, 7.61923999e-08, 0.99876368)
    createWaypointButton(cPool1)

    local cPool2 = {}
    cPool2.Name = "Pool (Benches)"
    cPool2.CFrame = CFrame.new(30.9888954, -3.39721847, -80.3704605, -0.715499997, -5.40728564e-08, -0.698610604, -1.14304344e-09, 1, -7.62298313e-08, 0.698610604, -5.37439142e-08, -0.715499997)
    createWaypointButton(cPool2)

    local cCirno = {}
    cCirno.Name = "Cirno Statues"
    cCirno.CFrame = CFrame.new(49.1739616, -3.39721847, -8.75012016, -0.543244958, -6.46215383e-08, -0.839574218, -1.14304521e-09, 1, -7.62298455e-08, 0.839574218, -4.04518019e-08, -0.543244958)
    createWaypointButton(cCirno)

    local cTreehouse = {}
    cTreehouse.Name = "Treehouse"
    cTreehouse.CFrame = CFrame.new(31.4564857, 35.6251411, 50.0041885, 0.715494156, 5.91811222e-08, 0.69861877, 3.8019552e-09, 1, -8.86053471e-08, -0.69861877, 6.60527633e-08, 0.715494156)
    createWaypointButton(cTreehouse)

    local cBouncyCastle = {}
    cBouncyCastle.Name = "Bouncy Castle"
    cBouncyCastle.CFrame = CFrame.new(0.475164026, -3.39721847, 23.8564453, -0.99950707, 9.88343851e-10, 0.0313819498, -1.32396899e-10, 1, -3.57108298e-08, -0.0313819498, -3.56973651e-08, -0.99950707)
    createWaypointButton(cBouncyCastle)

    local cSlide1 = {}
    cSlide1.Name = "Slide (Small Hill)"
    cSlide1.CFrame = CFrame.new(-50.6221809, 9.94405937, 56.1536865, 0.997613728, 2.3075911e-08, -0.0690322742, -2.23911307e-08, 1, 1.06936717e-08, 0.0690322742, -9.12244946e-09, 0.997613728)
    createWaypointButton(cSlide1)

    local cSlide2 = {}
    cSlide2.Name = "Slide (Poolside)"
    cSlide2.CFrame = CFrame.new(40.0324783, 6.6087389, -39.532444, 0.999875724, -1.93160812e-08, -0.0157229118, 1.95169676e-08, 1, 1.26231088e-08, 0.0157229118, -1.29284112e-08, 0.999875724)
    createWaypointButton(cSlide2)

    local cFunkyRoom = {}
    cFunkyRoom.Name = "Funky Room"
    cFunkyRoom.CFrame = CFrame.new(-68.484436, -3.39721847, 60.7482109, -2.32830644e-10, -3.11954729e-08, -0.999997795, 5.44967769e-08, 1, -3.11955013e-08, 0.999997795, -5.44967342e-08, -2.32830644e-10)
    createWaypointButton(cFunkyRoom)

    local cGamerShack = {}
    cGamerShack.Name = "Gamer Shack"
    cGamerShack.CFrame = CFrame.new(-50.2287025, -3.39721847, -3.56329846, 0.0125501379, -7.96809871e-08, 0.999920964, -4.29299334e-08, 1, 8.02261013e-08, -0.999920964, -4.39333938e-08, 0.0125501379)
    createWaypointButton(cGamerShack)

    local cSuwako = {}
    cSuwako.Name = "Suwako Room"
    cSuwako.CFrame = CFrame.new(-61.846508, -3.39721847, -66.5909882, 0.00312713091, -3.28514393e-09, -0.999995053, 7.25480831e-08, 1, -3.05829273e-09, 0.999995053, -7.25381568e-08, 0.00312713091)
    createWaypointButton(cSuwako)

    local cLobster = {}
    cLobster.Name = "Lobster"
    cLobster.CFrame = CFrame.new(5.77875519, -12.7361145, -63.4011688, 0.999820292, 1.11183072e-08, -0.0189436078, -9.94847138e-09, 1, 6.18481266e-08, 0.0189436078, -6.16485281e-08, 0.999820292)
    createWaypointButton(cLobster)

    local cMMP = {}
    cMMP.Name = "Memento Mori Portal"
    cMMP.CFrame = CFrame.new(2.64911199, -12.7361145, -92.2972336, -0.00299006794, -7.72914319e-08, 0.99999553, 5.85626445e-08, 1, 7.74668862e-08, -0.99999553, 5.8794015e-08, -0.00299006794)
    createWaypointButton(cMMP)

    -----
    createWaypointCategory("Other (Expansion 1)")

    local cSavanna1 = {}
    cSavanna1.Name = "Savanna"
    cSavanna1.CFrame = CFrame.new(37.7001686, -3.40405059, -137.407516, 0.999959052, 4.18167581e-08, 0.00899411179, -4.13985326e-08, 1, -4.66871946e-08, -0.00899411179, 4.63129659e-08, 0.999959052)
    createWaypointButton(cSavanna1)

    local cSavanna2 = {}
    cSavanna2.Name = "Savanna (Treetop)"
    cSavanna2.CFrame = CFrame.new(35.8279114, 26.9120026, -182.731674, 0.701667905, 3.67231046e-08, 0.71250397, -9.58126307e-08, 1, 4.28145697e-08, -0.71250397, -9.83084973e-08, 0.701667905)
    createWaypointButton(cSavanna2)

    local cBlueDoor = {}
    cBlueDoor.Name = "Blue Door"
    cBlueDoor.CFrame = CFrame.new(-33.5249329, -3.39721847, -211.964386, -0.999284327, 2.38968401e-08, 0.037821576, 2.54846189e-08, 1, 4.14982999e-08, -0.037821576, 4.24324718e-08, -0.999284327)
    createWaypointButton(cBlueDoor)

    local cTrain = {}
    cTrain.Name = "Train Station"
    cTrain.CFrame = CFrame.new(-54.2110176, 6.25, -161.287369, -0.999873161, 7.6191661e-08, 0.0159097109, 7.52258629e-08, 1, -6.13025932e-08, -0.0159097109, -6.0098003e-08, -0.999873161)
    createWaypointButton(cTrain)

    -----
    createWaypointCategory("Other (Expansion 2)")

    local cFountain = {}
    cFountain.Name = "Fountain"
    cFountain.CFrame = CFrame.new(35.8924446, -2.35769129, 96.6178894, -0.0536103845, -2.98055269e-08, -0.998561919, -6.42211972e-08, 1, -2.64005671e-08, 0.998561919, 6.27135108e-08, -0.0536103845)
    createWaypointButton(cFountain)

    local cRatcade = {}
    cRatcade.Name = "Ratcade"
    cRatcade.CFrame = CFrame.new(3.75609636, -3.39721847, 89.8193359, 0.0222254563, 5.80779727e-08, 0.999752939, 3.18127285e-08, 1, -5.87995359e-08, -0.999752939, 3.31117072e-08, 0.0222254563)
    createWaypointButton(cRatcade)

    local cPicnic = {}
    cPicnic.Name = "Ratcade (Picnic Tables)"
    cPicnic.CFrame = CFrame.new(-51.8626671, -3.39721847, 101.30365, 0.739765823, 1.6030107e-08, 0.672863305, 3.18127285e-08, 1, -5.87995359e-08, -0.672863305, 6.49035243e-08, 0.739765823)
    createWaypointButton(cPicnic)

    local cUfo = {}
    cUfo.Name = "Inside UFO Catcher"
    cUfo.CFrame = CFrame.new(-37.7735367, -0.92603755, 78.7536469, -0.999979138, -6.31962678e-08, 0.00645794719, -6.36200426e-08, 1, -6.5419826e-08, -0.00645794719, -6.5829326e-08, -0.999979138)
    createWaypointButton(cUfo)
end -- waypoints

do  -- hats come alive
    debugL = Gui.createText(root, 18)
    debugL.Visible = config.Value.debug
    debugL.AnchorPoint = Vector2.new(0.5, 0)
    debugL.BackgroundTransparency = 0.5
    debugL.BackgroundColor3 = cGui.BackgroundColor
    debugL.RichText = true
    debugL.Position = UDim2.fromScale(0.5, 0)
    debugL.AutomaticSize = Enum.AutomaticSize.XY

    local cBobThreshold = 1e-6
    local cAngleThreshold = math.pi / 48

    local commonWelds = {"Head", "Torso", "LArm", "RArm", "LLeg", "RLeg"}
    local parts = {}

    local tpTarget
    local tpTargetLastPos = {}
    local tpTargetLastMove = {}

    local function resetTpTarget(newTarget)
        tpTarget = newTarget
        tpTargetLastPos = {}
        tpTargetLastMove = {}
    end

    local mousePos
    local draggedAway

    local function checkCommonWeld(partName)
        for k, v in pairs(commonWelds) do
            if v == partName then
                return true
            end
        end

        return false
    end

    local savedLocation = nil
    local inProgress = 0
    local awaitingStart = 0

    function makeAlive(weld, cb)
        coroutine.wrap(function()
            local part = weld.Part1

            local humanRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local shouldTp = config.Value.orbitTp

            for k, v in pairs(part:GetDescendants()) do
                if v:IsA("Weld") then
                    makeAlive(v, cb)
                    if cb then cb(v) end
                end
            end

            for k, v in pairs(LocalPlayer.Character:GetDescendants()) do
                if v ~= weld and v:IsA("Weld") and v.Part1 == weld.Part1 then
                    v:Destroy()
                    if cb then cb(v) end
                end
            end

            if shouldTp then
                inProgress = inProgress + 1
                awaitingStart = awaitingStart + 1

                if not savedLocation then savedLocation = humanRoot.CFrame end

                teleport(CFrame.new(10000, 0, 10000))
                humanRoot.Anchored = true

                wait(2)
                awaitingStart = awaitingStart - 1

                while awaitingStart > 1 do
                    RUN.Stepped:Wait()
                end

                LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
                wait(1)
            end

            part.CanTouch = true

            local pos = Instance.new("BodyPosition")
            pos.Parent = part
            pos.P = 500000
            pos.D = 1000
            pos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            pos.Position = part.Position

            local gyro = Instance.new("BodyGyro")
            gyro.Parent = part
            gyro.P = 500000
            gyro.D = 1000
            gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)

            local antiG = Instance.new("BodyForce")
            antiG.Parent = part
            antiG.Force = Vector3.new(0, part:GetMass() * workspace.Gravity, 0)

            -- add offsets of welds until a common part is reached
            local checkWeld = weld
            local totalOffset = weld.C0 * weld.C1:Inverse()

            while not checkCommonWeld(checkWeld.Part0.Name) do
                for k, desc in pairs(LocalPlayer.Character:GetDescendants()) do
                    if desc:IsA("Weld") and desc.Part1 == checkWeld.Part0 then
                        totalOffset = desc.C0 * desc.C1:Inverse() * totalOffset
                        checkWeld = desc
                    end
                end

                break
            end

            local partInfo = {}
            partInfo.Weld = weld
            partInfo.TargetName = checkWeld.Part0.Name
            partInfo.Part = part
            partInfo.Pos = pos
            partInfo.Gyro = gyro
            partInfo.TotalOffset = totalOffset

            parts[#parts+1] = partInfo

            local lTouch = part.Touched:Connect(function(otherPart)
                local hum = otherPart.Parent:FindFirstChildOfClass("Humanoid")

                if not hum then
                    hum = otherPart.Parent:FindFirstChild("HumanoidRootPart")
                end

                if hum and mousePos then
                    local newTarget = hum.Parent

                    if draggedAway ~= newTarget then
                        mousePos = nil
                        resetTpTarget(newTarget)
                    end
                end
            end)

            weld:Destroy()
            part.Velocity = Vector3.new(0, 100, 0)
            part.Anchored = true

            if shouldTp then
                wait(2)
                inProgress = inProgress - 1

                if inProgress == 0 then
                    teleport(savedLocation)
                    savedLocation = nil
                    humanRoot.Anchored = false
                    LocalPlayer.CameraMode = Enum.CameraMode.Classic
                end
            end
        end)()
    end

    local function updatePart(info, raycastPos, t, dT, idx)
        local debugReport = {}

        debugReport.Part = info.Part
        debugReport.TargetName = info.TargetName

        local targetPos
        local alpha = 1

        local ang = ((t + 10 * idx) * math.pi) % (2 * math.pi)

        if raycastPos then
            debugReport.Type = "cast"

            targetPos = raycastPos
            alpha = 0.3
            info.Gyro.CFrame = CFrame.Angles(0, ang, 0)
        elseif tpTarget then
            debugReport.Type = "follow"

            local targetPart = tpTarget:FindFirstChild(info.TargetName)

            if targetPart then
                targetPart = targetPart:FindFirstChild(info.TargetName)
            end

            if not targetPart then
                if tpTarget == LocalPlayer.Character then
                    targetPart = info.Weld.Part0
                else
                    targetPart = tpTarget.Torso.Torso

                    for k, v in pairs(parts) do
                        if v and v.Part.Name == info.TargetName then
                            targetPart = v.Part
                        end
                    end
                end
            end

            debugReport.TargetPart = targetPart

            local vOff = Vector3.new(0, 0, 0)
            local lastCf = tpTargetLastPos[info.Part]

            if lastCf then
                local pos2 = targetPart.Position
                local pos1 = lastCf.Position
                local dist = math.sqrt((pos2.X - pos1.X)^2 + (pos2.Y - pos1.Y)^2 + (pos2.Z - pos1.Z)^2)

                local x2, y2, z2 = targetPart.CFrame:ToOrientation()
                local x1, y1, z1 = lastCf:ToOrientation()

                if dist > cBobThreshold or math.abs(x2 - x1) > cAngleThreshold or math.abs(y2 - y1) > cAngleThreshold or math.abs(z2 - z1) > cAngleThreshold then
                    tpTargetLastMove[info.Part] = t
                end

                if not tpTargetLastMove[info.Part] or t - tpTargetLastMove[info.Part] > 2/60 then
                    local shake = math.sin(t) * 0.25
                    vOff = Vector3.new(0, shake, 0)

                    debugReport.DidBob = true
                else
                    debugReport.DidBob = false
                end

                debugReport.Distance = dist
            else
                debugReport.Distance = 0
            end

            tpTargetLastPos[info.Part] = targetPart.CFrame

            local cf = targetPart.CFrame * info.TotalOffset

            -- targetPos = cf.Position + (targetPart.CFrame - targetPart.Position) * vOff
            targetPos = cf.Position + vOff
            info.Gyro.CFrame = cf - cf.Position + info.Part.Position
        else
            debugReport.Type = "orbit"

            local theta = (t + 10 * idx) * 3
            local xOff = math.cos(theta)
            local yOff = math.sin(theta)
            local zOff = math.cos(theta * 2) / 2
            local vOff = Vector3.new(xOff, zOff, yOff) * 2

            if LocalPlayer.Character.Torso.Torso:FindFirstChild("Head") then
                targetPos = LocalPlayer.Character.Head.Head.Position + vOff
            else
                targetPos = LocalPlayer.Character.Torso.Torso.Position + vOff
            end
            alpha = 0.2
            info.Gyro.CFrame = CFrame.Angles(ang, ang, ang)
        end

        local dist = math.sqrt((targetPos.X - info.Pos.Position.X)^2 + (targetPos.Y - info.Pos.Position.Y)^2)

        if alpha ~= 1 and dist < 1000 then
            info.Pos.Position = info.Pos.Position:Lerp(targetPos, alpha * 60 * dT)
        else
            info.Pos.Position = targetPos
        end

        return debugReport
    end

    lInputB = INPUT.InputBegan:Connect(function(input, handled)
        if not handled and input.UserInputType == Enum.UserInputType.MouseButton3 then
            draggedAway = tpTarget
            resetTpTarget()
            mousePos = input.Position
        end
    end)

    lInputC = INPUT.InputChanged:Connect(function(input, handled)
        if not handled and input.UserInputType == Enum.UserInputType.MouseMovement and mousePos then
            mousePos = input.Position
        end
    end)

    lInputE = INPUT.InputEnded:Connect(function(input, handled)
        if not handled and input.UserInputType == Enum.UserInputType.MouseButton3 then
            mousePos = nil
            draggedAway = nil
        end
    end)

    lStepped = RUN.Stepped:Connect(function(t, dT)
        local idx = 0
        local raycastPos

        if mousePos then
            local unitRay = workspace.CurrentCamera:ScreenPointToRay(mousePos.X, mousePos.Y)
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = { LocalPlayer.Character, workspace.MusicPlayer.SoundRegions, workspace.PlayArea["invis walls"] }
            params.FilterType = Enum.RaycastFilterType.Blacklist

            local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
            if result then
                raycastPos = result.Position
            end
        end

        if tpTarget and tpTarget.Parent == nil then
            resetTpTarget()
        end

        local debugStr

        if tpTarget then
            debugStr = "Currently tracking "..tpTarget.Name
        else
            debugStr = "Not tracking anybody"
        end

        for k, info in pairs(parts) do
            if info then
                info.Part.Anchored = false
                local report = updatePart(info, raycastPos, t, dT, idx)

                debugStr = debugStr.."<br />"..report.Part.Name.." -> "..report.TargetName

                if report.Type == "follow" then
                    local distColor = "#FFFFFF"

                    if report.DidBob then
                        distColor = "#FFFF00"
                    elseif report.Distance <= cBobThreshold then
                        distColor = "#FF0000"
                    end

                    debugStr = debugStr.." - A: "..report.TargetPart.Name..", <font color=\""..distColor.."\">D: "..report.Distance.."</font>"
                end
            end

            idx = idx + 1
        end

        debugL.Text = debugStr
    end)

    lHeartbeat = RUN.Heartbeat:Connect(function()
        for k, info in pairs(parts) do
            if info then
                info.Part.Velocity = Vector3.new(0, 35, 0)
            end
        end
    end)

    lCharacter2 = LocalPlayer.CharacterAdded:Connect(function(char)
        parts = {}
        resetTpTarget()
    end)
end -- hats come alive -- globals exposed: makeAlive, lHeartbeat, lStepped, lInputB, lInputC, lInputE, lCharacter2, debugL

do  -- welds
    local weldsTab = tabControl:createTab("Remove Welds", "6R", "TabWelds")

    local weldsScroll = Gui.createListScroll(weldsTab, 2)

    local savedLocation = nil
    local inProgress = 0

    local function deleteWeld(weld, cb)
        inProgress = inProgress + 1

        for k, v in pairs(weld.Part1:GetChildren()) do -- destroying parts in this loop causes death.
            -- notify caller that something other than the weld was destroyed,
            -- mostly so welds that were deleted in this operation are also removed from the list
            cb(v)
        end

        weld.Part1:ClearAllChildren()

        -- allows for tp-back location to be correct between concurrent calls.
        local origPos = teleport(CFrame.new(31, 45, 50, 1, 0, 0, 0, 1, 0, 0, 0, 1))
        if not savedLocation then savedLocation = origPos end
        wait(0.2)

        weld:Destroy()

        -- wait for movement (lag?)
        local v0 = weld.Part1.Velocity

        while weld.Part1.Velocity == v0 do
            wait(0.1)
        end

        wait(1.5)
        weld.Part1.Anchored = true

        if savedLocation and inProgress == 1 then
            teleport(savedLocation)
            savedLocation = nil
        end

        inProgress = inProgress - 1
    end

    local labels = {}

    local function removeWeldButton(weld)
        for k, l in pairs(labels) do
            if l and l.Weld == weld then
                l.Label:Destroy()
            end
        end
    end

    local function addWeld(weld)
        local label = nil
        local labelInfo = Gui.createLabelButtonLarge(weldsScroll, weld.Name, function(setActive, type)
            if not weld.Parent then return end

            if type == Enum.UserInputType.MouseButton1 then
                setActive(true)

                deleteWeld(weld, function(p)
                    for k, l in pairs(labels) do
                        if l and l.Weld == p or l.Weld.Part0 == p or l.Weld.Part1 == p then
                            l.Label:Destroy()
                        end
                    end
                end)

                if label then label:Destroy() end
            elseif type == Enum.UserInputType.MouseButton2 then
                local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 5, true)
                local goal = {}
                goal.Transparency = 1
                local tween = TWEEN:Create(weld.Part1, tweenInfo, goal)

                setActive(true)
                tween:Play()

                tween.Completed:Wait()
                setActive(false)
            else
                makeAlive(weld, function(p)
                    removeWeldButton(p)
                end)

                removeWeldButton(weld)
            end
        end)

        label = labelInfo.Label
        label.TextTruncate = Enum.TextTruncate.AtEnd

        -- I hate Yuyuko.
        if not label.TextFits then
            label.TextScaled = true
        end

        local labelInfo = {}
        labelInfo.Label = label
        labelInfo.Weld = weld

        labels[#labels + 1] = labelInfo
    end

    local function updateChar(char)
        for k, l in pairs(labels) do
            l.Label:Destroy()
        end

        labels = {}

        for k, v in pairs(char:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                addWeld(v)
            end
        end
    end

    lCharacter = LocalPlayer.CharacterAdded:Connect(function(char)
        updateChar(char)
    end)
    if LocalPlayer.Character then updateChar(LocalPlayer.Character) end
end -- welds -- globals exposed: lCharacter

do  -- settings
    local settingsTab = tabControl:createTab("Settings", "7S", "TabSettings")

    local settingsScroll = Gui.createListScroll(settingsTab)

    local function createSettingsCategory(name)
        Gui.createCategoryLabel(settingsScroll, name)
    end

    local currentlyBinding = nil
    local listener = nil

    local function addBind(name)
        local labelInfo = nil
        local label = nil

        local function getName()
            local bindText = binds.Keybinds[name]
            if bindText == -1 then bindText = "NONE" end

            return name.." ("..bindText..")"
        end

        local function stopBinding()
            listener:Disconnect()
            listener = nil

            label.Text = getName()
            labelInfo.SetActive(false)

            wait(0.2)
            binds.Disabled = false
            currentlyBinding = nil
        end

        labelInfo = Gui.createLabelButtonLarge(settingsScroll, getName(), function(setActive, type)
            if type == Enum.UserInputType.MouseButton1 then
                if currentlyBinding then
                    if currentlyBinding == name then
                        stopBinding()
                    else
                        return
                    end
                else
                    listener = INPUT.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Keyboard and
                            not INPUT:GetFocusedTextBox() then
                            binds:rebind(name, input.KeyCode)

                            stopBinding()
                            setActive(false)
                        end
                    end)

                    setActive(true)

                    label.Text = "press a key..."
                    binds.Disabled = true
                    currentlyBinding = name
                end
            elseif type == Enum.UserInputType.MouseButton2 then
                binds:unbind(name)
                label.Text = getName()
            end
        end)

        label = labelInfo.Label
    end

    createSettingsCategory("Keybinds")

    local cBinds = { "TabCharacters", "TabOptions", "TabDocs", "TabAnims", "TabWaypoints", "TabWelds", "TabSettings", "HideGui", "MapVis", "MapView", "RaySit", "Exit" }

    for k, v in pairs(cBinds) do
        addBind(v)
    end

    local function addCheckbox(label, field, cb)
        Gui.createCheckbox(settingsScroll, label, function(checked)
            config.Value[field] = checked
            config:save()

            if cb then cb(checked) end
        end, config.Value[field])
    end

    createSettingsCategory("Weld Options")

    addCheckbox("Orbit Teleport", "orbitTp")
    addCheckbox("Debug", "debug", function(checked)
        debugL.Visible = checked
    end)
end -- settings

do  -- info
    local cInfoText =            "<b>Become Fumo Scripts</b><br />"
    cInfoText = cInfoText.."version "..version.."<br /><br />"
    cInfoText = cInfoText.."Created by voided_etc, 2021<br /><br />"
    cInfoText = cInfoText.."<i>Confused? Navigate to the Knowledgebase to see if any of your questions are answered there.</i><br /><br />"
    cInfoText = cInfoText.."Thank you, "..LocalPlayer.Name.."!"

    cInfoLabel = "Info"
    local infoTab = tabControl:createTab(cInfoLabel, "I")

    local infoText = Gui.createText(infoTab, 18)
    infoText.TextXAlignment = Enum.TextXAlignment.Center
    infoText.TextYAlignment = Enum.TextYAlignment.Center
    infoText.Size = UDim2.fromScale(1, 1)
    infoText.Position = UDim2.fromScale(0, 0)
    infoText.TextWrapped = true
    infoText.RichText = true

    infoText.Text = cInfoText
end -- info

do  -- minimap
    local TooltipProvider = {}
    TooltipProvider.__index = TooltipProvider

    -- TooltipObject spec (abstract)
    -- :ShowTooltip (opt) - whether the object should show a tooltip
    -- :CreateTooltip(tp) - create the tooltip
    -- TooltipObject (GuiObject) - the object that, when hovered, should cause a tooltip to appear
    -- :Clicked(input) (opt) - called on click

    function TooltipProvider.new(parent)
        local obj = {}
        setmetatable(obj, TooltipProvider)

        obj.Parent = parent

        local tooltipFrame = Instance.new("Frame")
        tooltipFrame.Parent = parent
        tooltipFrame.AnchorPoint = Vector2.new(0, 0)
        tooltipFrame.AutomaticSize = Enum.AutomaticSize.XY
        tooltipFrame.BackgroundTransparency = 0.25
        tooltipFrame.BackgroundColor3 = cGui.BackgroundColor
        tooltipFrame.BorderSizePixel = 0

        obj.Frame = tooltipFrame

        obj.Instances = {}
        obj.Scale = 1

        return obj
    end

    function TooltipProvider:createText(size)
        local text = Gui.createText(self.Frame, size)
        text.AutomaticSize = Enum.AutomaticSize.XY
        text.TextWrapped = false
        text.RichText = true

        return text
    end

    function TooltipProvider:_mouseEnter(obj)
        if obj.ShowTooltip and not obj:ShowTooltip() then return end

        local pos = INPUT:GetMouseLocation()

        self.Frame:ClearAllChildren()
        obj:CreateTooltip(self)
        self.Frame.Position = UDim2.fromOffset(pos.X, pos.Y)

        self.Frame.Visible = true
    end

    function TooltipProvider:_mouseLeave(obj)
        self.Frame:ClearAllChildren()
        self.Frame.Visible = false
    end

    function TooltipProvider:register(obj)
        if not obj.TooltipObject or not obj.CreateTooltip then return end

        local info = {}
        info.Object = obj

        info.lEnter = obj.TooltipObject.MouseEnter:Connect(function()
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
    -- UpdateSize(scaleFactor, mapPosition): Causes the MapObject to resize/change appearance based on a new scale factor

    local MapBBox = {}
    MapBBox.__index = MapBBox

    function MapBBox.new(minimap, cf, size, color, colorB)
        local obj = {}
        setmetatable(obj, MapBBox)

        local quad = Instance.new("Frame")
        quad.AnchorPoint = Vector2.new(0.5, 0.5)
        quad.BackgroundTransparency = 0.25
        quad.BackgroundColor3 = color
        quad.BorderSizePixel = 1
        quad.BorderColor3 = colorB

        obj.Map = minimap
        obj.Root = quad
        obj.CFrame = cf
        obj.Size = size

        return obj
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

    local MapSeat = setmetatable({}, { __index = MapBBox });
    MapSeat.__index = MapSeat

    function MapSeat.new(minimap, seat)
        local cSeatColor = Color3.fromRGB(38, 38, 38)
        local cSeatColorB = Color3.fromRGB(0, 0, 0)

        local obj = setmetatable(MapBBox.new(minimap, seat.CFrame, seat.Size, cSeatColor, cSeatColorB), MapSeat)

        obj.Seat = seat
        obj.TooltipObject = obj.Root

        return obj
    end

    function MapSeat:ShowTooltip()
        return self.Map.ScaleFactor > 2
    end

    function MapSeat:CreateTooltip(tp)
        Gui.createListLayout(tp.Frame, Enum.HorizontalAlignment.Left)

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

    local FriendsCache = {}
    FriendsCache.__index = FriendsCache

    function FriendsCache.new()
        local obj = {}
        setmetatable(obj, FriendsCache)

        obj.Value = nil
        obj.LastCollected = 0

        obj:update()

        return obj
    end

    function FriendsCache:update()
        if not self.Value or DateTime.now().UnixTimestamp - self.LastCollected > 10 then
            self.Value = LocalPlayer:GetFriendsOnline()
            self.LastCollected = DateTime.now().UnixTimestamp
        end
    end

    local PlayerDot = {}
    PlayerDot.__index = PlayerDot

    function PlayerDot.new(player, cache, layers)
        local obj = {}
        setmetatable(obj, PlayerDot)

        local cIconSize = 20

        local frame = Instance.new("Frame")
        frame.Parent = parent
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromOffset(cIconSize, cIconSize)

        local dot = Instance.new("Frame")
        dot.Parent = frame
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size = UDim2.fromOffset(5, 5)
        dot.Position = UDim2.fromScale(0.5, 0.5)
        dot.BorderSizePixel = 0

        local icon = Instance.new("ImageLabel")
        icon.Parent = frame
        icon.Image = "rbxassetid://7480141029"
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.fromOffset(cIconSize, cIconSize)
        icon.BorderSizePixel = 0

        local label = Gui.createText(frame)
        label.Position = UDim2.fromScale(1, 1)
        label.AutomaticSize = Enum.AutomaticSize.XY
        label.Visible = false
        label.Text = player.Name

        obj.TooltipObject = frame
        obj.Frame = frame
        obj.Dot = dot
        obj.Icon = icon
        obj.Label = label

        obj.Player = player
        obj.IsLocal = player == LocalPlayer

        obj.FriendsCache = cache

        obj.Layers = layers

        obj.InfoText = nil

        obj:update()

        return obj
    end

    function PlayerDot:update()
        if self.Player.UserId == LocalPlayer.UserId then
            self:setParent(self.Layers[3])
            self:setColor(Color3.fromRGB(255, 255, 0))
            return
        end

        for k, v in pairs(self.FriendsCache.Value) do
            if v.VisitorId == self.Player.UserId then
                self:setParent(self.Layers[2])
                self.InfoText = "Friend"
                self:setColor(Color3.fromRGB(19, 165, 214))
                return
            end
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

        Gui.createListLayout(tp.Frame, Enum.HorizontalAlignment.Left)

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
            tpText.Text = "<i>Click to teleport</i>"
        end
    end

    function PlayerDot:Clicked(input)
        if self.IsLocal then return end

        local root = self.Player.Character:FindFirstChild("HumanoidRootPart")

        if root then
            teleport(root.CFrame)
        end
    end

    local cEpsilon = 1e-7
    local function almostEqual(v1, v2, epsilon)
        if not epsilon then epsilon = cEpsilon end
        return math.abs(v1 - v2) < epsilon
    end

    Minimap = {}
    Minimap.__index = Minimap

    function Minimap.new(parent)
        local obj = {}
        setmetatable(obj, Minimap)

        obj.Parent = parent

        local origin, maxPos = obj:_findWorldBounds()
        obj.WorldOrigin = origin
        obj.RealSize2 = maxPos - origin

        obj.ScaleFactor = 1.2
        obj.ScaleFactorSmall = 1.2
        obj.MapSizeSmall = UDim2.fromOffset(300, 300)

        local mapFrameO = Instance.new("Frame")
        mapFrameO.Parent = parent
        mapFrameO.AnchorPoint = Vector2.new(0, 1)
        mapFrameO.Position = UDim2.fromScale(0, 1)
        mapFrameO.Size = UDim2.fromScale(0, 0)
        mapFrameO.BackgroundColor3 = cGui.BackgroundColor
        mapFrameO.BackgroundTransparency = 0.5
        mapFrameO.BorderSizePixel = 3
        mapFrameO.BorderColor3 = cGui.ForegroundColor
        mapFrameO.ClipsDescendants = true

        obj.FrameOuter = mapFrameO

        local mapFrameI = Instance.new("Frame")
        mapFrameI.Parent = mapFrameO
        mapFrameI.BackgroundTransparency = 1
        mapFrameI.BorderSizePixel = 0
        mapFrameI.Position = UDim2.fromScale(0, 0)

        obj.FrameInner = mapFrameI

        obj.Tooltips = TooltipProvider.new(parent)

        obj.AreaLayer = obj:createLayer()
        obj.TerrainLayer = obj:createLayer()
        obj.SeatLayer = obj:createLayer()
        obj.PlayerLayerRandom = obj:createLayer()
        obj.PlayerLayerSpecial = obj:createLayer()
        obj.PlayerLayerSelf = obj:createLayer()

        obj.PlayerLayers = { obj.PlayerLayerRandom, obj.PlayerLayerSpecial, obj.PlayerLayerSelf }

        obj.MapObjects = {}
        obj:_plotAreas()
        obj:_plotTerrain()

        obj.Players = {}
        obj.PlayerPositions = {}
        obj.FriendsCache = FriendsCache.new()

        for k, v in pairs(PLAYERS:GetPlayers()) do
            obj:_playerConnect(v)
        end

        obj._lConnect = PLAYERS.PlayerAdded:Connect(function(player)
            obj:_playerConnect(player)
        end)

        obj._lDisconnect = PLAYERS.PlayerRemoving:Connect(function(player)
            obj:_playerDisconnect(player)
        end)

        obj._lHeartbeat = RUN.Heartbeat:Connect(function()
            obj:_heartbeat()
        end)

        obj._expandTween = nil
        obj.Expanded = nil
        obj:setExpanded(false)

        obj._dragStart = nil
        obj._dragPosOrig = nil

        mapFrameO.InputBegan:Connect(function(input)
            obj:_inputB(input)
        end)

        mapFrameO.InputChanged:Connect(function(input)
            obj:_inputC(input)
        end)

        mapFrameO.InputEnded:Connect(function(input)
            obj:_inputE(input)
        end)

        obj._lSizeChange = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            obj:updateSizeO()
        end)

        obj:updateSizeO()

        return obj
    end

    function Minimap:createLayer()
        local layer = Instance.new("Frame")
        layer.Parent = self.FrameInner
        layer.Size = UDim2.fromScale(1, 1)
        layer.BorderSizePixel = 0
        layer.BackgroundTransparency = 1

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

        for k, v in pairs(insts) do
            for _, part in pairs(v:GetDescendants()) do
                scan(part)
            end
        end

        return Vector3.new(xMin, yMin, zMin), Vector3.new(xMax, yMax, zMax)
    end

    function Minimap:_findWorldBounds()
        local posMin, posMax = self:_findBounds({ workspace.PlayArea, REPLICATED.Zones, workspace.ActiveZone })
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

        local tween = TWEEN:Create(self.FrameOuter, tweenInfo, goal)
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

        for k, v in pairs(self.MapObjects) do
            if v then
                v:UpdateSize(self.ScaleFactor)
            end
        end

        for k, v in pairs(self.Players) do
            if v then
                v:UpdateSize(self.ScaleFactor)
                self:plotPlayer(v.Player)
            end
        end
    end

    function Minimap:_findZone(name)
        local rep = REPLICATED.Zones:FindFirstChild(name)
        if rep then return rep end

        local active = workspace.ActiveZone:FindFirstChild(name)
        if active then return active end

        log("WARNING: Did you delete any zones? Failed to find "..name.."!")
    end

    function Minimap:_plotAreas()
        local cArea = Color3.fromRGB(86, 94, 81)
        local cAreaB = Color3.fromRGB(89, 149, 111)

        local mwCf, mwSize = workspace.PlayArea["invis walls"]:GetBoundingBox()
        self:plotBBox(mwCf, mwSize, cArea, cAreaB, self.AreaLayer)

        local cBeachCf = CFrame.new(-978.322266, 134.538483, 8961.99805, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- the roof barrier
        local cBeachSize = Vector3.new(273.79, 29.45, 239.5)
        self:plotBBox(cBeachCf, cBeachSize, cArea, cAreaB, self.AreaLayer)

        local ruinsMin, ruinsMax = self:_findBounds({ self:_findZone("Ruins") }, function(inst) return inst.Name ~= "bal" end)
        local ruinsCenter = CFrame.new((ruinsMin + ruinsMax) / 2)
        self:plotBBox(ruinsCenter, ruinsMax - ruinsMin, cArea, cAreaB, self.AreaLayer)

        local velvetMin, velvetMax = self:_findBounds({ self:_findZone("VelvetRoom") })
        local velvetCenter = CFrame.new((velvetMin + velvetMax) / 2)
        self:plotBBox(velvetCenter, velvetMax - velvetMin, cArea, cAreaB, self.AreaLayer)
    end

    function Minimap:_plotTerrain()
        local features = workspace.PlayArea:GetDescendants()

        local cWater = Color3.fromRGB(70, 92, 86)
        local cWaterB = Color3.fromRGB(2, 135, 99)

        local cPoolCf = CFrame.new(51.980999, -16.854372, -63.6765823, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- cframe and size of the pool floor
        local cPoolSize = Vector3.new(45.3603, 5.33651, 32.0191)

        self:plotBBox(cPoolCf, cPoolSize, cWater, cWaterB)

        local cTree = Color3.fromRGB(89, 149, 111)
        local cTreeB = Color3.fromRGB(5, 145, 56)

        local cRock = Color3.fromRGB(89, 105, 108)
        local cRockB = Color3.fromRGB(89, 89, 89)

        local cParkourSize = 4.0023837089539
        local cParkourEpsilon = 1e-2

        for k, v in pairs(features) do -- not so important stuff
            if v:IsA("Model") and v.Name == "stupid tree1" then -- single square trees
                self:plotPartQuad(v:FindFirstChild("Part"), cTree, cTreeB)
            elseif v:IsA("Part") then
                local children = v:GetChildren()

                if v.Color == cRock then -- any rocks
                    self:plotPartQuad(v, cRock, cRockB)
                elseif almostEqual(v.Size.X, cParkourSize, cParkourEpsilon) and -- parkour
                    almostEqual(v.Size.Z, cParkourSize, cParkourEpsilon) and
                    #children >= 6 and children[1]:IsA("Texture") and children[1].Texture == "http://www.roblox.com/asset/?id=6022009301" then
                    self:plotPartQuad(v, v.Color, cRockB)
                end
            end
        end

        local cBench = Color3.fromRGB(173, 125, 110)
        local cBenchB = Color3.fromRGB(173, 88, 62)

        for k, v in pairs(features) do -- bench
            if v:IsA("Model") and (v.Name == "Bench" or v.Name == "log") then
                local cf, size = v:GetBoundingBox()
                self:plotBBox(cf, size, cBench, cBenchB)
            end
        end

        -- ALL SEATS!!!
        for k, list in pairs({ features, workspace.ActiveZone:GetDescendants(), REPLICATED.Zones:GetDescendants() }) do
            for k, v in pairs(list) do
                if v:IsA("Seat") then
                    local seatObj = MapSeat.new(self, v)
                    self:addMapObject(seatObj, self.SeatLayer)
                    self.Tooltips:register(seatObj)
                end
            end
        end

        local spawns = workspace.Spawns:GetChildren()
        local cColorSpawn = Color3.fromRGB(255, 166, 193)
        local cColorSpawnB = Color3.fromRGB(247, 0, 74)

        for k, v in pairs(spawns) do
            self:plotPartQuad(v, cColorSpawn, cColorSpawnB)
        end
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
        local cIconSize = 20

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
            local dot = PlayerDot.new(player, self.FriendsCache, self.PlayerLayers)
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
        for k, v in pairs(PLAYERS:GetPlayers()) do
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

do  -- update info
    if config.Value.version ~= version then
        local tabButtonInfo = tabControl:createTabButton("Update Info", "!")

        tabButtonInfo.Tab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                openPage(cChangelogInfo)

                tabControl:removeTabButton(tabButtonInfo)
            end
        end)

        local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)

        local goal = {}
        goal.BackgroundColor3 = Color3.fromRGB(255, 165, 0)

        local tween = TWEEN:Create(tabButtonInfo.Tab, tweenInfo, goal)
        tween:Play()

        config.Value.version = version
        config:save()
    end
end -- update info

do  -- announcements
    local tabButtonInfo = tabControl:createTabButton("Announcement", "!A3!")

    tabButtonInfo.Tab.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            openPage(cA3Info)
        end
    end)
end -- announcements

local guiVisible = true

binds:bind("HideGui", function()
    guiVisible = not guiVisible

    tabControl:setTabsVisible(guiVisible)
    secondaryRoot.Visible = guiVisible
end)

local map = nil

binds:bind("MapVis", function()
    if not map then
        map = Minimap.new(secondaryRoot)
    elseif guiVisible then
        map:setVisible(not map.FrameOuter.Visible)
    end
end)

binds:bind("MapView", function()
    if map then
        map:setExpanded(not map.Expanded)
    end
end)

binds:bind("RaySit", function()
    local pos = INPUT:GetMouseLocation()
    local unitRay = workspace.CurrentCamera:ScreenPointToRay(pos.X, pos.Y)

    local filter = {}
    for k, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Seat") then
            filter[#filter+1] = v.Parent
        end
    end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = filter
    params.FilterType = Enum.RaycastFilterType.Whitelist

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
    if not result then return end

    if result.Instance:IsA("Seat") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

        if hum.SeatPart then
            hum.Sit = false
            wait()
        end

        result.Instance:Sit(hum)
    end
end)

binds:bind("Exit", function()
    root:Destroy()
    toggleButton.Visible = true -- reenable the default character selector
    settings.Visible = true -- reenable the default settings
    lCharacter:Disconnect()
    disconnectJump()
    stopAllAnimations()

    binds:destroy()

    lHeartbeat:Disconnect()
    lStepped:Disconnect()
    lInputB:Disconnect()
    lInputC:Disconnect()
    lInputE:Disconnect()
    lCharacter2:Disconnect()

    lCharacter3:Disconnect()

    pcall(function()
        map:destroy()
    end)

    getgenv().BF_LOADED = false
end)
