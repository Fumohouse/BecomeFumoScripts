--[[
    Become Fumo Scripts UI & Utility Functions
    Copyright (c) 2021-2022 voided_etc & contributors
    Licensed under the MIT license. See the LICENSE.txt file at the project root for details.
]]

local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInput = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local BFS = {}

function BFS.log(msg)
	print("[fumo] " .. msg)
end

function BFS.teleport(pos)
    local char = LocalPlayer.Character
    local hum = char:FindFirstChildOfClass("Humanoid")

    if hum and hum.SeatPart then
        hum.Sit = false
        wait()
    end

    local origPos = char:GetPrimaryPartCFrame()

    if workspace.StreamingEnabled then
        coroutine.wrap(function()
            LocalPlayer:RequestStreamAroundAsync(pos.Position)
            char:SetPrimaryPartCFrame(pos)
        end)()
    else
        char:SetPrimaryPartCFrame(pos)
    end

    return origPos
end

getgenv().BFS = BFS

do -- base gui
    function randomString()
        local str = ""

        for i = 1, math.random(10, 20) do
            str = str .. string.char(math.random(32, 126))
        end

        return str
    end

    local root = Instance.new("ScreenGui")
    root.Name = randomString()
    BFS.Root = root
    BFS.IsUsingHUI = false

    if syn and syn.protect_gui then
        syn.protect_gui(root)
        root.Parent = CoreGui
    elseif get_hidden_gui or gethui then
        local hiddenUI = get_hidden_gui or gethui
        root.Parent = hiddenUI()
        BFS.IsUsingHUI = true
    else
        root.Parent = CoreGui
    end
end -- base gui

local cGui = {
    BackgroundColor = Color3.fromRGB(12, 13, 20),
    BackgroundColorDark = Color3.fromRGB(4, 4, 7),
    BackgroundColorLight = Color3.fromRGB(32, 35, 56),
    ForegroundColor = Color3.fromRGB(255, 255, 255),
    AccentColor = Color3.fromRGB(10, 162, 175),
    Font = Enum.Font.Ubuntu,

    LabelButtonHeight = 25,
    ButtonHeightLarge = 30,
    CategoryHeight = 32,

    CheckboxSize = 25
}

BFS.UIConsts = cGui

do -- gui class
    local UIUtils = {}
    UIUtils.__index = UIUtils

    -- creates a TextLabel with default font, no background (default color is light)
    -- and no border
    function UIUtils.createText(parent, size)
        size = size or 12

        local label = Instance.new("TextLabel")
        label.BackgroundColor3 = cGui.BackgroundColorLight
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.TextColor3 = cGui.ForegroundColor
        label.Font = cGui.Font
        label.TextSize = size
        label.Parent = parent

        return label
    end

    -- creates a ScrollingFrame which takes up the entire parent by default
    function UIUtils.createScroll(parent)
        local scroll = Instance.new("ScrollingFrame")
        scroll.BorderSizePixel = 0
        scroll.BackgroundTransparency = 1
        scroll.Size = UDim2.fromScale(1, 1)
        scroll.Position = UDim2.fromOffset(0, 0)
        scroll.ScrollBarImageColor3 = cGui.ForegroundColor
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.fromScale(1, 0)
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.ScrollBarThickness = 3
        scroll.Parent = parent

        return scroll
    end

    function UIUtils.createListLayout(parent, horizAlign, vertAlign, padding)
        local listLayout = Instance.new("UIListLayout")

        if padding then
            listLayout.Padding = UDim2.fromOffset(0, padding).Y
        end

        listLayout.HorizontalAlignment = horizAlign or Enum.HorizontalAlignment.Center
        listLayout.VerticalAlignment = vertAlign or Enum.VerticalAlignment.Top
        listLayout.FillDirection = Enum.FillDirection.Vertical
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder

        listLayout.Parent = parent

        return listLayout
    end

    -- creates a ScrollingFrame with a vertical UIListLayout inside.
    function UIUtils.createListScroll(parent, padding)
        local scroll = UIUtils.createScroll(parent)
        UIUtils.createListLayout(scroll, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top, padding)

        return scroll
    end

    -- creates a TextLabel with callback for MouseButton1, no background
    function UIUtils.createLabelButton(parent, labelText, cb)
        local label = UIUtils.createText(parent, cGui.LabelButtonHeight * 0.75)
        label.Text = labelText
        label.TextTruncate = Enum.TextTruncate.AtEnd
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
    function UIUtils.createCategoryLabel(parent, labelText)
        local label = UIUtils.createText(parent, cGui.CategoryHeight * 0.75)
        label.BackgroundTransparency = 0.9
        label.BackgroundColor3 = cGui.BackgroundColorDark
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Bottom
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Size = UDim2.new(1, 0, 0, cGui.CategoryHeight)
        label.RichText = true
        label.Text = "<b>" .. labelText .. "</b>"

        return label
    end

    -- creates a larger TextLabel with a background color and on/off state
    function UIUtils.createLabelButtonLarge(parent, labelText, cb)
        local label = UIUtils.createText(parent, cGui.ButtonHeightLarge * 0.8)
        label.BackgroundTransparency = 0.5
        label.BackgroundColor3 = cGui.BackgroundColorLight
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.fromScale(0.5, 0)
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

            local tween = TweenService:Create(label, tweenInfo, goal)

            tween:Play()
        end

        label.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
                input.UserInputType == Enum.UserInputType.MouseButton2 or
                input.UserInputType == Enum.UserInputType.MouseButton3 then
                cb(labelInfo.SetActive, input.UserInputType)
            end
        end)

        return labelInfo
    end

    -- creates a checkbox component, with callback and initial value options
    function UIUtils.createCheckbox(parent, labelText, cb, initial)
        local cSpacing = 5

        local checkbox = Instance.new("Frame")
        checkbox.BorderSizePixel = 0
        checkbox.BackgroundTransparency = 1
        checkbox.Size = UDim2.new(1, 0, 0, cGui.CheckboxSize)
        checkbox.Parent = parent

        local indicator = Instance.new("Frame")
        indicator.BorderSizePixel = 0
        indicator.BackgroundColor3 = cGui.BackgroundColorLight
        indicator.Size = UDim2.fromOffset(cGui.CheckboxSize, cGui.CheckboxSize)
        indicator.Position = UDim2.fromScale(0, 0)
        indicator.Parent = checkbox

        local label = UIUtils.createText(checkbox, cGui.CheckboxSize * 0.75)
        label.Text = labelText
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Size = UDim2.new(1, -(cGui.CheckboxSize + cSpacing), 0,
                               cGui.CheckboxSize)
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

            local tween = TweenService:Create(indicator, tweenInfo, goal)

            tween:Play()
        end

        updateColor()

        checkbox.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end

            checked = not checked

            updateColor()

            cb(checked)
        end)

        return checkbox
    end

    function UIUtils.createTextBox(parent, placeholder, height)
        local textBox = Instance.new("TextBox")
        textBox.ClearTextOnFocus = false
        textBox.BackgroundColor3 = cGui.BackgroundColorLight
        textBox.BorderSizePixel = 1
        textBox.Font = cGui.Font
        textBox.TextSize = cGui.ButtonHeightLarge * 0.8
        textBox.TextColor3 = cGui.ForegroundColor
        textBox.Text = ""
        textBox.PlaceholderColor3 = Color3.fromRGB(127, 127, 127)
        textBox.PlaceholderText = placeholder
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.TextYAlignment = Enum.TextYAlignment.Center
        textBox.Size = UDim2.new(1, 0, 0, height)
        textBox.Parent = parent

        return textBox
    end

    BFS.UI = UIUtils
end -- gui class

do -- config & bindings
    local ConfigManager = {}
    ConfigManager.__index = ConfigManager

    local function mergeTable(current, toMerge, cb)
        for key, value in pairs(toMerge) do
            if type(value) == "table" then
                current[key] = mergeTable(current[key] or {}, value, cb)
            else
                current[key] = value
            end

            cb(current, key)
        end

        return current
    end

    function ConfigManager.new()
        local self = setmetatable({}, ConfigManager)

        self.Filename = "fumo.json"
        self.Value = nil
        self.Default = {keybinds = {Exit = Enum.KeyCode.Zero.Name}}

        self.UseFs = true

        if not writefile then
            BFS.log(
                "WARNING: No file write access. Config will not save or load.")
            self.UseFs = false
        end

        self:load()
        self:checkMissingKeys()

        self.DefaultsUpdated = Instance.new("BindableEvent")

        return self
    end

    function ConfigManager:mergeDefaults(newDefaults)
        mergeTable(self.Default, newDefaults, function(obj, key)
            if obj == self.Default then
                self.DefaultsUpdated:Fire(key)
            end
        end)
        self:checkMissingKeys()
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

        local str = HttpService:JSONEncode(self.Value)
        writefile(self.Filename, str)
    end

    function ConfigManager:load()
        if not self.UseFs then
            self.Value = self.Default
            return
        end

        if not isfile(self.Filename) then
            BFS.log("Creating new config file.")
            self:setDefault()
        else
            local success = pcall(function()
                self.Value = HttpService:JSONDecode(readfile(self.Filename))
            end)

            if not success then
                BFS.log("WARNING: Config data is invalid. Restoring defaults...")
                self:setDefault()
            end
        end
    end

    function ConfigManager:destroy() self.DefaultsUpdated:Destroy() end

    BFS.Config = ConfigManager.new()

    local KeybindManager = {}
    KeybindManager.__index = KeybindManager

    function KeybindManager.new(configManager)
        local self = {}
        setmetatable(self, KeybindManager)

        self.Config = configManager
        self.Keybinds = configManager.Value.keybinds

        self._lKeyPress = UserInput.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard and
                not UserInput:GetFocusedTextBox() then
                self:_keyPress(input.KeyCode)
            end
        end)

        self.BindingsUpdated = Instance.new("BindableEvent")

        configManager.DefaultsUpdated.Event:Connect(function(key)
            if key == "keybinds" then self.BindingsUpdated:Fire() end
        end)

        self.Bindings = {}

        self.Disabled = false

        return self
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
            BFS.log("WARNING: Binding the same action twice is unsupported!")
        end

        self.Bindings[name] = del
    end

    function KeybindManager:_keyPress(code)
        if self.Disabled then return end

        for k, v in pairs(self.Keybinds) do
            if v == code.Name then
                local del = self.Bindings[k]
                if del then del() end
            end
        end
    end

    function KeybindManager:destroy()
        self._lKeyPress:Disconnect()
        self.BindingsUpdated:Destroy()
    end

    BFS.Binds = KeybindManager.new(BFS.Config)
end -- config & bindings

do -- exit
    local exitBinds = {}

    BFS.Binds:bind("Exit", function()
        BFS.Root:Destroy()
        BFS.Config:destroy()
        BFS.Binds:destroy()

        getgenv().BFS = null

        for name, func in pairs(exitBinds) do
            local success = pcall(func)

            if success then
                BFS.log("Cleaning up... " .. name)
            else
                warn("Exit handler failed:", name)
            end
        end
    end)

    function BFS.bindToExit(name, cb) exitBinds[name] = cb end
end -- exit

do -- tabcontrol
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
        local self = setmetatable({}, TabControl)

        self.Parent = parent
        self.Binds = binds

        local tabContainer = Instance.new("Frame")
        tabContainer.BackgroundTransparency = 1
        tabContainer.BorderSizePixel = 0
        tabContainer.AnchorPoint = Vector2.new(0, 0.5)
        tabContainer.AutomaticSize = Enum.AutomaticSize.Y
        tabContainer.Size = UDim2.fromOffset(cTabWidth, 0)
        tabContainer.Position = cTabContainerPosClosed
        tabContainer.Parent = parent

        BFS.UI.createListLayout(tabContainer, Enum.HorizontalAlignment.Left)

        tabContainer.MouseEnter:Connect(function()
            self:_setTabsExpanded(true)
        end)

        tabContainer.MouseLeave:Connect(function()
            self:_setTabsExpanded(false)
        end)

        self.TabContainer = tabContainer

        self.TabButtons = {}
        self.Tabs = {}

        return self
    end

    function TabControl:setTabsVisible(visible)
        self.TabContainer.Visible = visible
    end

    function TabControl:createTabButton(label, abbrev)
        local tab = BFS.UI.createText(self.TabContainer, cTabHeight * 0.75)
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
        content.Active = true
        content.Name = "Content"
        content.BackgroundTransparency = 0.1
        content.BorderSizePixel = 0
        content.BackgroundColor3 = cGui.BackgroundColorDark
        content.AnchorPoint = Vector2.new(0, 0.5)
        content.Size = UDim2.new(0, cTabContentWidth, cTabContentHeight, 0)
        content.Position = cTabPosClosed
        content.Parent = self.Parent

        -- functions (open/close)
        local isOpen = false
        local tween = nil

        local function getOpen() return isOpen end

        local function setOpen(open, shouldTween)
            if isOpen == open then return end

            if open then content.Visible = true end

            -- check if other tabs are open
            local othersOpen = false

            for _, v in pairs(self.Tabs) do
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

                for _, v in pairs(self.Tabs) do
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
                tween = TweenService:Create(content, tweenInfo, goal)
                tween:Play()

                tween.Completed:Connect(function()
                    tween:Destroy()
                    tween = nil

                    if not open then content.Visible = false end
                end)
            else
                content.Position = goal.Position
            end

            local tabContainerTween = TweenService:Create(self.TabContainer, tweenInfo, tabContainerGoal)
            tabContainerTween:Play()

            local tabTween = TweenService:Create(tabButtonData.Tab, tweenInfo, tabGoal)
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
        for _, v in pairs(self.Tabs) do
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
                if open == nil then open = not v.GetOpen() end

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

        for _, v in pairs(self.TabButtons) do
            if v then
                if expanded then
                    v.Tab.Text = v.Label
                else
                    v.Tab.Text = v.Abbrev
                end

                local tween = TweenService:Create(v.Tab, tweenInfo, goal)
                tween:Play()
            end
        end

        local tabContainerTween = TweenService:Create(self.TabContainer, tweenInfo, tabContainerGoal)
        tabContainerTween:Play()
    end

    BFS.TabControl = TabControl.new(BFS.Root, BFS.Binds)
end -- tabcontrol
