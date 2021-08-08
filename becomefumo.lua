--[[
    do - end blocks can be closed in most ides for organization
    variables beginning with c are constant and should not change
]]

local function log(msg)
    print("[fumo] "..msg)
end

version = "1.1.3"

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
WORKSPACE = game.Workspace

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
end -- base gui -- globals exposed: root

--
-- constants
--

cBackgroundColor = Color3.fromRGB(12, 13, 20)
cBackgroundColorDark = Color3.fromRGB(4, 4, 7)
cBackgroundColorLight = Color3.fromRGB(32, 35, 56)
cForegroundColor = Color3.fromRGB(255, 255, 255)
cAccentColor = Color3.fromRGB(10, 162, 175)

cFont = Enum.Font.Ubuntu

do  -- disable stuff
    local mainGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("MainGui")
    toggleButton = mainGui:FindFirstChild("MainFrame"):FindFirstChild("ToggleButton")
    toggleButton.Visible = false -- disable the default character selector

    settings = mainGui:FindFirstChild("SettingsFrame")
    settings.Visible = false -- disable the default settings
end -- disable stuff -- globals exposed: toggleButton & settings

do  -- tabs
    local tabs = {}

    --
    -- constants
    --

    cTabContentWidth = 250
    cTabContentHeight = 750

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
    -- tab container
    --

    local tabContainer = Instance.new("Frame")
    tabContainer.Parent = root
    tabContainer.BackgroundTransparency = 1
    tabContainer.BorderSizePixel = 0
    tabContainer.AnchorPoint = Vector2.new(0, 0.5)
    tabContainer.AutomaticSize = Enum.AutomaticSize.Y
    tabContainer.Size = UDim2.fromOffset(cTabWidth, 0)
    tabContainer.Position = cTabContainerPosClosed

    local function setTabsExpanded(expanded)
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

        for k, v in pairs(tabs) do
            if expanded then
                v.Tab.Text = v.Label
            else
                v.Tab.Text = v.Abbrev
            end

            local tween = TWEEN:Create(v.Tab, tweenInfo, goal)
            tween:Play()
        end
        
        local tabContainerTween = TWEEN:Create(tabContainer, tweenInfo, tabContainerGoal)
        tabContainerTween:Play()
    end

    tabContainer.MouseEnter:Connect(function()
        setTabsExpanded(true)
    end)

    tabContainer.MouseLeave:Connect(function()
        setTabsExpanded(false)
    end)
    
    function setTabOpen(label, open)
        for k, v in pairs(tabs) do
            if v.Label == label then
                if open == nil then
                    open = not v.GetOpen()
                end

                v.SetOpen(open, true)
                break
            end
        end
    end
    
    function closeAllTabs()
        for k, v in pairs(tabs) do
            v.SetOpen(false, true)
        end
    end

    --
    -- function: creates tab with given label and returns the content container
    --

    function createTab(label, abbrev)
        -- tab button
        local tab = Instance.new("TextLabel")
        tab.Parent = tabContainer
        tab.Name = label
        tab.Active = true
        tab.BackgroundTransparency = 0.3
        tab.BorderSizePixel = 0
        tab.BackgroundColor3 = cBackgroundColorDark
        tab.TextColor3 = cForegroundColor
        tab.TextSize = cTabHeight * 0.75
        tab.Font = cFont
        tab.Text = abbrev
        tab.TextXAlignment = Enum.TextXAlignment.Center
        tab.TextYAlignment = Enum.TextYAlignment.Center
        tab.AnchorPoint = Vector2.new(0, 0.5)
        tab.Size = cTabSizeSmall
        tab.Position = UDim2.new(0, 0, 0.5, #tabs * cTabHeight)
        
        -- tab content
        local content = Instance.new("Frame")
        content.Parent = root
        content.Active = true
        content.Name = "Content"
        content.BackgroundTransparency = 0.1
        content.BorderSizePixel = 0
        content.BackgroundColor3 = cBackgroundColorDark
        content.AnchorPoint = Vector2.new(0, 0.5)
        content.Size = UDim2.fromOffset(cTabContentWidth, cTabContentHeight)
        content.Position = cTabPosClosed

        -- functions (open/close)
        local isOpen = false
        local tween = nil
        
        local function getOpen() return isOpen end
        
        local function setOpen(open, shouldTween)
            if isOpen == open then return end
            
            -- check if other tabs are open
            local othersOpen = false
            
            for k, v in pairs(tabs) do
                if v.Label ~= label and v.GetOpen() then
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
                tabGoal.BackgroundColor3 = cBackgroundColorLight

                for k, v in pairs(tabs) do
                    if v.Label ~= label then
                        v.SetOpen(false, false)
                    end
                end
            else
                goal.Position = cTabPosClosed
                tabContainerGoal.Position = cTabContainerPosClosed
                tabGoal.BackgroundColor3 = cBackgroundColorDark
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

            local tabContainerTween = TWEEN:Create(tabContainer, tweenInfo, tabContainerGoal)
            tabContainerTween:Play()
            
            local tabTween = TWEEN:Create(tab, tweenInfo, tabGoal)
            tabTween:Play()
            
            isOpen = open
        end
        
        tab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                setOpen(not isOpen, true)
            end
        end)
        
        -- save to table
        local tabData = {}
        tabData.Label = label
        tabData.Abbrev = abbrev
        tabData.GetOpen = getOpen
        tabData.SetOpen = setOpen
        tabData.Tab = tab
        
        tabs[#tabs + 1] = tabData
        
        return content
    end
end -- tabs -- globals exposed: createTab, setTabOpen, closeAllTabs & all constants

--
-- common gui
--

function createScroll()
    local scroll = Instance.new("ScrollingFrame")
    scroll.BorderSizePixel = 0
    scroll.BackgroundTransparency = 1
    scroll.Size = UDim2.fromOffset(cTabContentWidth, cTabContentHeight)
    scroll.Position = UDim2.fromOffset(0, 0)
    scroll.ScrollBarImageColor3 = cForegroundColor
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.fromScale(1, 0)
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y

    return scroll
end

cLabelButtonHeight = 25

function createLabelButton(labelText, cb)
    local label = Instance.new("TextLabel")
    label.Name = labelText
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.TextColor3 = cForegroundColor
    label.TextSize = cLabelButtonHeight * 0.75
    label.Font = cFont
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Size = UDim2.new(1, 0, 0, cLabelButtonHeight)
    
    label.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            cb()
        end
    end)

    return label
end

cCategoryHeight = 32

function createCategoryLabel(labelText)
    local label = Instance.new("TextLabel")
    label.Name = labelText
    label.BackgroundTransparency = 0.9
    label.BackgroundColor3 = cBackgroundColorDark
    label.BorderSizePixel = 0
    label.Font = cFont
    label.TextSize = cCategoryHeight * 0.75
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Bottom
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Size = UDim2.new(1, 0, 0, cCategoryHeight)
    label.TextColor3 = cForegroundColor
    label.RichText = true
    label.Text = "<b>"..labelText.."</b>"
    
    return label
end

local cButtonOff = cBackgroundColorLight
local cButtonOn = cAccentColor

cButtonHeightLarge = 30

function createLabelButtonLarge(labelText, cb)
    local label = Instance.new("TextLabel")
    label.Name = labelText
    label.BackgroundTransparency = 0.5
    label.BackgroundColor3 = cButtonOff
    label.BorderSizePixel = 0
    label.TextColor3 = cForegroundColor
    label.Font = cFont
    label.TextSize = cButtonHeightLarge * 0.8
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Size = UDim2.new(1, 0, 0, cButtonHeightLarge)
    label.Text = labelText

    local labelInfo = {}
    labelInfo.Label = label
    labelInfo.SetActive = function(active)
        local tweenInfo = TweenInfo.new(0.15)
        local goal = {}
        
        if active then
            goal.BackgroundColor3 = cButtonOn
        else
            goal.BackgroundColor3 = cButtonOff
        end
        
        local tween = TWEEN:Create(label, tweenInfo, goal)
        
        tween:Play()
    end

    label.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            cb(labelInfo.SetActive)
        end
    end)
    
    
    return labelInfo
end

cCheckboxSize = 25
cCheckboxSpace = 5

-- function: creates a checkbox frame given label, calls the cb with the checkbox value when it changes, and returns the frame

function createCheckbox(labelText, cb)
    local checkbox = Instance.new("Frame")
    checkbox.BorderSizePixel = 0
    checkbox.BackgroundTransparency = 1
    checkbox.Size = UDim2.new(1, 0, 0, cCheckboxSize)
    
    local indicator = Instance.new("Frame")
    indicator.Parent = checkbox
    indicator.BorderSizePixel = 0
    indicator.BackgroundColor3 = cBackgroundColorLight
    indicator.Size = UDim2.fromOffset(cCheckboxSize, cCheckboxSize)
    indicator.Position = UDim2.fromScale(0, 0)
    
    local label = Instance.new("TextLabel")
    label.Parent = checkbox
    label.Name = labelText
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.TextColor3 = cForegroundColor
    label.Font = cFont
    label.TextSize = cCheckboxSize * 0.75
    label.Text = labelText
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Size = UDim2.new(1, -(cCheckboxSize + cCheckboxSpace), 0, cCheckboxSize)
    label.Position = UDim2.fromOffset(cCheckboxSize + cCheckboxSpace, 0)
    
    local checked = false
    
    checkbox.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        checked = not checked
        
        local tweenInfo = TweenInfo.new(0.15)
        local goal = {}
        
        if checked then
            goal.BackgroundColor3 = cAccentColor
        else
            goal.BackgroundColor3 = cBackgroundColorLight
        end
        
        local tween = TWEEN:Create(indicator, tweenInfo, goal)
        
        tween:Play()
        
        cb(checked)
    end)
    
    return checkbox
end

do  -- characters
    -- constants

    local cCharacters = {}

    for k, v in pairs(REPLICATED.CharacterList:GetChildren()) do
        cCharacters[#cCharacters + 1] = v.Name
    end

    table.sort(cCharacters)

    -- interface

    cCharactersLabel = "Characters"
    local charactersTab = createTab(cCharactersLabel, "1C")

    local characterScroll = createScroll()
    characterScroll.Parent = charactersTab
    characterScroll.Size = characterScroll.Size - UDim2.fromOffset(0, cCheckboxSize + cLabelButtonHeight)
    characterScroll.Position = characterScroll.Position + UDim2.fromOffset(0, cCheckboxSize + cLabelButtonHeight)

    local characterCount = 0

    local shouldReplaceHumanoid = false

    local humanoidCheckbox = createCheckbox("Replace Humanoid", function(checked)
        shouldReplaceHumanoid = checked
    end)

    humanoidCheckbox.Parent = charactersTab
    humanoidCheckbox.Position = UDim2.fromScale(0, 0)

    local jumpListener = nil

    local function replaceHumanoid(char, resetCam)
        local hum = char:FindFirstChildOfClass("Humanoid")
        local newHum = hum:Clone()
        hum:Destroy()
        newHum.Parent = char
        
        if resetCam then
            WORKSPACE.CurrentCamera.CameraSubject = char
            
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

    local replaceNowButton = createLabelButton("Replace Humanoid Now", function()
        replaceHumanoid(LocalPlayer.Character, true)
    end)

    replaceNowButton.Parent = charactersTab
    replaceNowButton.Position = UDim2.fromOffset(0, cCheckboxSize)

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

    local function addCharacter(name)
        local characterLabel = createLabelButton(name, function()
            switchCharacter(name)
        end)
        
        characterLabel.Parent = characterScroll
        characterLabel.Position = UDim2.fromOffset(0, characterCount * cLabelButtonHeight)

        characterCount = characterCount + 1
    end

    for k, v in pairs(cCharacters) do
        addCharacter(v)
    end
end -- characters -- globals exposed: disconnectJump, cCharactersLabel

do  -- options
    local cOptionSpacing = 5

    cOptionsLabel = "Options"
    local optionsTab = createTab(cOptionsLabel, "2O")

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
        local labelInfo = createLabelButtonLarge(labelText, function()
            closeAllTabs()
            cb()
        end)
        
        local label = labelInfo.Label
        
        label.Parent = optionsFrame
        label.Size = label.Size - UDim2.fromScale(0.2, 0)
        label.Position = UDim2.new(0.5, 0, 0, optionButtonCount * (cButtonHeightLarge + cOptionSpacing))
        
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
    local cDocsWidth = 800
    local cDocsHeight = 600

    local cDocsPosOpen = UDim2.fromScale(0.5, 0.5)
    local cDocsPosClosed = UDim2.fromScale(0.5, 1.5)

    local cDocsTitleHeight = 40
    local cDocsPadding = 5
    local cDocsCloseSize = 20

    local docsFrame = Instance.new("Frame")
    docsFrame.Parent = root
    docsFrame.Name = "Knowledgebase"
    docsFrame.BackgroundTransparency = 0.1
    docsFrame.BackgroundColor3 = cBackgroundColorDark
    docsFrame.BorderSizePixel = 1
    docsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    docsFrame.Size = UDim2.fromOffset(cDocsWidth, cDocsHeight)
    docsFrame.Position = cDocsPosClosed

    local docsClose = Instance.new("TextLabel")
    docsClose.Parent = docsFrame
    docsClose.Active = true
    docsClose.Name = "Close"
    docsClose.BackgroundTransparency = 1
    docsClose.BorderSizePixel = 0
    docsClose.TextColor3 = cForegroundColor
    docsClose.Font = cFont
    docsClose.TextSize = cDocsCloseSize
    docsClose.TextXAlignment = Enum.TextXAlignment.Center
    docsClose.TextYAlignment = Enum.TextYAlignment.Center
    docsClose.AnchorPoint = Vector2.new(1, 0)
    docsClose.Size = UDim2.fromOffset(cDocsCloseSize, cDocsCloseSize)
    docsClose.Position = UDim2.fromScale(1, 0)
    docsClose.Text = "x"

    local docsContentScroll = createScroll()
    docsContentScroll.Parent = docsFrame
    docsContentScroll.Size = UDim2.fromScale(1, 1)

    local docsTitle = Instance.new("TextLabel")
    docsTitle.Parent = docsContentScroll
    docsTitle.Name = "Title"
    docsTitle.BackgroundTransparency = 1
    docsTitle.BorderSizePixel = 0
    docsTitle.TextColor3 = cForegroundColor
    docsTitle.Font = cFont
    docsTitle.TextSize = cDocsTitleHeight * 0.9
    docsTitle.TextXAlignment = Enum.TextXAlignment.Left
    docsTitle.TextYAlignment = Enum.TextYAlignment.Center
    docsTitle.Size = UDim2.new(1, -cDocsPadding, 0, cDocsTitleHeight)
    docsTitle.Position = UDim2.fromOffset(cDocsPadding, cDocsPadding)
    docsTitle.TextTruncate = Enum.TextTruncate.AtEnd

    local docsContent = Instance.new("TextLabel")
    docsContent.Parent = docsContentScroll
    docsContent.Name = "Content"
    docsContent.BackgroundTransparency = 1
    docsContent.BorderSizePixel = 0
    docsContent.TextColor3 = cForegroundColor
    docsContent.Font = cFont
    docsContent.TextSize = 18
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
        else
            goal.Position = cDocsPosClosed
        end
        
        local tween = TWEEN:Create(docsFrame, tweenInfo, goal)
        
        tween:Play()
        
        docsOpen = open
    end

    docsClose.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            setDocsOpen(false)
        end
    end)

    cKnowledgebaseLabel = "Knowledgebase"
    local docsTab = createTab(cKnowledgebaseLabel, "3K")

    local docsScroll = createScroll()
    docsScroll.Parent = docsTab

    local docCount = 0

    function addDoc(info)
        local docLabel = createLabelButton(info.Label, function()
            setDocsOpen(true)
            
            docsTitle.Text = info.Label
            docsContent.Text = info.Content
        end)

        docLabel.Parent = docsScroll
        docLabel.Position = UDim2.fromOffset(0, docCount * cLabelButtonHeight)

        docCount = docCount + 1
    end
end -- knowledgebase UI -- globals exposed: addDoc, cKnowledgebaseLabel

do  -- docs content
    local cAboutContent =          "This script is dedicated to Become Fumo, and it has functions specific to it.<br />"
    cAboutContent = cAboutContent.."It provides replacements for some of Become Fumo's default UI components, as they currently lack polish.<br />"
    cAboutContent = cAboutContent.."It is intended to work alongside Infinite Yield and DEX, not replace them.<br />"
    cAboutContent = cAboutContent.."Information on certain features and bugs is provided in this knowledgebase. "
    cAboutContent = cAboutContent.."Credit for this information is provided whenever I can remember it. "
    cAboutContent = cAboutContent.."Please note that 'disclosed' and 'discovered' don't mean the same thing. I don't know who discovered most of these bugs.<br />"
    cAboutContent = cAboutContent.."For any questions, you can ask me in game.<br />"
    cAboutContent = cAboutContent.."As an alternative to clicking the tabs, you can navigate to any tab except the info tab through the number keys.<br />"
    cAboutContent = cAboutContent.."At any time, you can press [0] to close the script and reset everything back to normal.<br /><br />"
    cAboutContent = cAboutContent.."<b>Credits:</b><br />"
    cAboutContent = cAboutContent.."- AyaShameimaruCamera - Replace Humanoid & Inspiration<br />"
    cAboutContent = cAboutContent.."- FutoLurkingAround - Emotional Support<br />"
    cAboutContent = cAboutContent.."- gandalf872 - ?<br />"

    local cAboutInfo = {}
    cAboutInfo.Label = "About this Script"
    cAboutInfo.Content = cAboutContent

    addDoc(cAboutInfo)
    
    local cChangelogContent = ""
    cChangelogContent = cChangelogContent.."<b>1.1.3</b><br />"
    cChangelogContent = cChangelogContent.."- Increase maintainability by reusing the animation button style elsewhere<br />"
    cChangelogContent = cChangelogContent.."- Add category labels to the animations list<br /><br />"

    cChangelogContent = cChangelogContent.."<b>1.1.2</b><br />"
    cChangelogContent = cChangelogContent.."- Fix two tabs opening at once when pressing two keys simultaneously<br /><br />"

    cChangelogContent = cChangelogContent.."<b>1.1.1</b><br />"
    cChangelogContent = cChangelogContent.."- Fix tweens when using hotkeys to open menus<br /><br />"

    cChangelogContent = cChangelogContent.."<b>1.1.0</b><br />"
    cChangelogContent = cChangelogContent.."- Added an animations tab and added every significant animation default to the game (mostly emotes and arcade)<br />"
    cChangelogContent = cChangelogContent.."- Allow navigation through number keys<br /><br />"

    cChangelogContent = cChangelogContent.."<b>1.0.0</b><br />"
    cChangelogContent = cChangelogContent.."- Created a simple tab interface<br />"
    cChangelogContent = cChangelogContent.."- Replaced the default character select and options<br />"
    cChangelogContent = cChangelogContent.."    - Added options to replace the humanoid<br />"
    cChangelogContent = cChangelogContent.."- Added knowledgebase articles for the script and the replace humanoid option<br />"
    cChangelogContent = cChangelogContent.."- Added an about page"
    -- cChangelogContent = cChangelogContent..""
    
    local cChangelogInfo = {}
    cChangelogInfo.Label = "Changelog"
    cChangelogInfo.Content = cChangelogContent
    
    addDoc(cChangelogInfo)

    local cHumanoidContent =             "<i>Disclosed by: AyaShameimaruCamera</i><br />"
    cHumanoidContent = cHumanoidContent.."<i>Scripting refined by: me</i><br /><br />"
    cHumanoidContent = cHumanoidContent.."The 'Replace Humanoid' option found in the Character menu bypasses the check for removal of any children of your character's Head/Torso by replacing the humanoid object with a clone.<br />"
    cHumanoidContent = cHumanoidContent.."Note that this script purposefully provides no way of deleting any specific part from your character, as the way they are designed is inconsistent. Use DEX to delete parts.<br />"
    cHumanoidContent = cHumanoidContent.."Attempting to remove parts like bows and hats without using this feature will result in your character being reset.<br />"
    cHumanoidContent = cHumanoidContent.."You should not use this if you only want to delete limbs, or descendants of your Head that aren't direct children, such as your eyes and face. Those can be deleted without using this feature.<br /><br />"
    cHumanoidContent = cHumanoidContent.."The same functionality can be achieved using DEX only by duplicating your humanoid, deleting the original, and disabling and reenabling your camera, but it has more limitations. "
    cHumanoidContent = cHumanoidContent.."This script will replace the humanoid at almost the same time as you switch characters (as soon as the character is available by the CharacterAdded event). "
    cHumanoidContent = cHumanoidContent.."This will allow you to retain the ability to jump normally, and eliminates the need to reset the camera manually. Animations will be displayed client-side, but don't be fooled: they cannot be seen by others.<br /><br />"
    cHumanoidContent = cHumanoidContent.."<b>The following actions are impossible to do with this feature active:</b><br />"
    cHumanoidContent = cHumanoidContent.."1. Any emotes or animations (walk, idle, etc) including those provided by exploits. As mentioned above, they will be visible to you only (if at all).<br />"
    cHumanoidContent = cHumanoidContent.."2. Sitting in benches or on the train, or using the arcade.<br />"
    cHumanoidContent = cHumanoidContent.."3. Resetting your character. The only way to 'reset your character' is to switch characters.<br />"
    cHumanoidContent = cHumanoidContent.."4. Using tools or items. You may be able to hold them, but you cannot use them.<br /><br />"
    cHumanoidContent = cHumanoidContent.."Generally speaking, most server side scripts affecting your character will no longer work.<br /><br />"
    cHumanoidContent = cHumanoidContent.."Another button labeled 'Replace Humanoid Now' provides older functionality. It doesn't show animations client-side, it requires a custom key listener for jumping to work, and it requires resetting the camera. "
    cHumanoidContent = cHumanoidContent.."But, it activates the feature without needing to change characters. The benefit of this is you can use items or do things before you activate the feature (such as getting the red glow on Soul Edge)."

    local cHumanoidInfo = {}
    cHumanoidInfo.Label = "Replacing Humanoid"
    cHumanoidInfo.Content = cHumanoidContent

    addDoc(cHumanoidInfo)
end -- docs content

do  -- animation UI
    local cSpeedFieldSize = 25
    local cSpeedFieldPadding = 5

    local activeAnimations = {}
    local stoppingAnimations = {}
    
    local speed = 1
    
    local function adjustSpeed(target)
        for k, v in pairs(activeAnimations) do
            if v then
                v:AdjustSpeed(target)
            end
        end
        
        speed = target
    end
    
    cAnimationsLabel = "Animations"
    local animationsTab = createTab(cAnimationsLabel, "4A")
    
    local speedField = Instance.new("TextBox")
    speedField.Parent = animationsTab
    speedField.ClearTextOnFocus = false
    speedField.BackgroundColor3 = cBackgroundColorLight
    speedField.BorderSizePixel = 1
    speedField.Font = cFont
    speedField.TextSize = cButtonHeightLarge * 0.8
    speedField.TextColor3 = cForegroundColor
    speedField.Text = ""
    speedField.PlaceholderColor3 = Color3.fromRGB(127, 127, 127)
    speedField.PlaceholderText = "Speed"
    speedField.TextXAlignment = Enum.TextXAlignment.Left
    speedField.TextYAlignment = Enum.TextYAlignment.Center
    speedField.Size = UDim2.new(1, 0, 0, cSpeedFieldSize)
    speedField.Position = UDim2.fromScale(0, 0)
    
    speedField.FocusLost:Connect(function()
        local num = tonumber(speedField.Text)
        if num then
            log("adjusting speed to "..tostring(num))
            adjustSpeed(num)
        end
    end)

    local animationsScroll = createScroll()
    animationsScroll.Parent = animationsTab
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
    
    local animScrollY = 0
    
    function createAnimationCategory(name)
        local label = createCategoryLabel(name)
        label.Parent = animationsScroll
        label.Position = UDim2.new(0.5, 0, 0 , animScrollY)
        
        animScrollY = animScrollY + cCategoryHeight
    end
    
    function createAnimationButton(info)
        local active = false

        local labelInfo = createLabelButtonLarge(info.Name, function(setActive)
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

        local label = labelInfo.Label
        label.Parent = animationsScroll
        label.Position = UDim2.new(0.5, 0, 0, animScrollY)
        
        animScrollY = animScrollY + cButtonHeightLarge
    end
end -- animation UI -- globals exposed: createAnimationButton, createAnimationCategory, stopAllAnimations, cAnimationsLabel

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
    
    addAnimation("Walk", "rbxassetid://6235532038")
    addAnimation("Run", "rbxassetid://6235359704")
    addAnimation("Jump", "rbxassetid://6235182835")
    addAnimation("Fall", "rbxassetid://6235205527")
end -- animations

do  -- info
    local cInfoText =            "<b>Become Fumo Scripts</b><br />"
    cInfoText = cInfoText.."version "..version.."<br /><br />"
    cInfoText = cInfoText.."Created by voided_etc, 2021<br /><br />"
    cInfoText = cInfoText.."<i>Confused? Navigate to the Knowledgebase to see if any of your questions are answered there.</i><br /><br />"
    cInfoText = cInfoText.."Thank you, "..LocalPlayer.Name.."!"

    cInfoLabel = "Info"
    local infoTab = createTab(cInfoLabel, "I")

    local infoText = Instance.new("TextLabel")
    infoText.Parent = infoTab
    infoText.Name = "Info"
    infoText.BackgroundTransparency = 1
    infoText.BorderSizePixel = 0
    infoText.TextColor3 = cForegroundColor
    infoText.Font = cFont
    infoText.TextSize = 18
    infoText.TextXAlignment = Enum.TextXAlignment.Center
    infoText.TextYAlignment = Enum.TextYAlignment.Center
    infoText.Size = UDim2.fromScale(1, 1)
    infoText.Position = UDim2.fromScale(0, 0)
    infoText.TextWrapped = true
    infoText.RichText = true

    infoText.Text = cInfoText
end -- info

local function exit()
    root:Destroy()
    toggleButton.Visible = true -- reenable the default character selector
    settings.Visible = true -- reenable the default settings
    if lInput then lInput:Disconnect() end
    disconnectJump()
    stopAllAnimations()

    getgenv().BF_LOADED = false
end

cHotkeys = {}
cHotkeys[cCharactersLabel] = Enum.KeyCode.One
cHotkeys[cOptionsLabel] = Enum.KeyCode.Two
cHotkeys[cKnowledgebaseLabel] = Enum.KeyCode.Three
cHotkeys[cAnimationsLabel] = Enum.KeyCode.Four

lInput = INPUT.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard and not
        INPUT:GetFocusedTextBox() then
        
        for k, v in pairs(cHotkeys) do
            if input.KeyCode == v then
                setTabOpen(k, nil)
                return
            end
        end
        
        if input.KeyCode == Enum.KeyCode.Zero then
            exit()
        end
    end
end)
