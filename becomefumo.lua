--[[
    Become Fumo Scripts
    Copyright (c) 2021-2022 voided_etc & contributors
    Licensed under the MIT license. See the LICENSE.txt file at the project root for details.

    do - end blocks can be closed in most ides for organization
    variables beginning with c are constant and should not change
]]

local BFS = getgenv().BFS

if not BFS then
    loadstring(game:HttpGet(("https://raw.githubusercontent.com/Fumohouse/BecomeFumoScripts/master/gui.lua"), true))()
    BFS = getgenv().BFS
end

local BFSMap = getgenv().BFSMap

if not BFSMap then
    loadstring(game:HttpGet(("https://raw.githubusercontent.com/Fumohouse/BecomeFumoScripts/master/minimap.lua"), true))()
    BFSMap = getgenv().BFSMap
end

local cDefaultConfig = {
    version = nil, -- for version check
    keybinds = {
        TabCharacters = Enum.KeyCode.One.Name,
        TabOptions = Enum.KeyCode.Two.Name,
        TabDocs = Enum.KeyCode.Three.Name,
        TabAnims = Enum.KeyCode.Four.Name,
        -- TabWaypoints = Enum.KeyCode.Five.Name,
        TabTools = Enum.KeyCode.Five.Name,
        TabWelds = Enum.KeyCode.Six.Name,
        TabSettings = Enum.KeyCode.Seven.Name,
        HideGui = Enum.KeyCode.F1.Name,
        MapVis = Enum.KeyCode.N.Name,
        MapView = Enum.KeyCode.M.Name,
    },
    orbitTp = false,
    debug = false,
    replaceHumanoid = false,
    mapRenderEverything = false,
    postLoad = {},
    blockList = {},
}

BFS.Config:mergeDefaults(cDefaultConfig)

version = "1.8.3"

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

do  -- place detection
    local cPlaces = {
        [6238705697] = "BCF",
        [7363647365] = "SBF"
    }

    place = cPlaces[game.PlaceId]

    BFS.log("Detected place: "..place)
end -- place detection

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

local huiFolder
if BFS.IsUsingHUI then
    huiFolder = BFS.Root.Parent
end

local LocalPlayer = Players.LocalPlayer

do  -- disable stuff
    if place == "BCF" then
        -- anticipating GUI rework will break things
        pcall(function()
            local mainGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("MainGui")

            local selectButton = mainGui:FindFirstChild("FumoSelectButton")
            selectButton.Visible = false

            local settingsButton = mainGui:FindFirstChild("SettingsButton")
            settingsButton.Visible = false

            BFS.bindToExit("Re-enable GUI", function()
                selectButton.Visible = true
                settingsButton.Visible = true
            end)
        end)
    end
end -- disable stuff

local secondaryRoot = Instance.new("Frame")
secondaryRoot.Size = UDim2.fromScale(1, 1)
secondaryRoot.BackgroundTransparency = 1
secondaryRoot.BorderSizePixel = 0
secondaryRoot.Parent = BFS.Root

do  -- characters
    local charactersTab = BFS.TabControl:createTab("Characters", "1C", "TabCharacters")
    local characterScroll = BFS.UI.createListScroll(charactersTab)

    if place == "BCF" then
        local cCharacters = {}

        for _, v in pairs(LocalPlayer.PlayerGui.MainGui.FumoSelectFrame.ScrollingFrame:GetChildren()) do -- steal from the gui instead of the replicated list, which does not include badge chars
            if v:IsA("TextButton") then
                cCharacters[#cCharacters + 1] = v.Name
            end
        end

        table.sort(cCharacters)

        -- RIP
        if BFS.Config.Value.replaceHumanoid then
            characterScroll.Size = characterScroll.Size - UDim2.fromOffset(0, BFS.UIConsts.CheckboxSize + BFS.UIConsts.LabelButtonHeight)
            characterScroll.Position = characterScroll.Position + UDim2.fromOffset(0, BFS.UIConsts.CheckboxSize + BFS.UIConsts.LabelButtonHeight)
        end

        local shouldReplaceHumanoid = false

        if BFS.Config.Value.replaceHumanoid then
            BFS.UI.createCheckbox(charactersTab, "Replace Humanoid", function(checked)
                shouldReplaceHumanoid = checked
            end)
        end

        local jumpListener = nil

        local function replaceHumanoid(char, resetCam)
            local hum = char:FindFirstChildOfClass("Humanoid")
            local newHum = hum:Clone()
            hum:Destroy()
            newHum.Parent = char

            if resetCam then
                workspace.CurrentCamera.CameraSubject = char

                if not jumpListener then
                    BFS.log("connecting jump listener")

                    jumpListener = UserInput.InputBegan:Connect(function(input)
                        if not UserInput:GetFocusedTextBox() and
                            input.UserInputType == Enum.UserInputType.Keyboard and
                            input.KeyCode == Enum.KeyCode.Space then
                                newHum.Jump = true
                        end
                    end)
                end
            end
        end

        local function disconnectJump()
            if jumpListener then
                BFS.log("disconnecting jump listener")
                jumpListener:Disconnect()
                jumpListener = nil
            end
        end

        BFS.bindToExit("Disconnect Jump", disconnectJump)

        if BFS.Config.Value.replaceHumanoid then
            local replaceNowButton, _ = BFS.UI.createLabelButton(charactersTab, "Replace Humanoid Now", function()
                replaceHumanoid(LocalPlayer.Character, true)
            end)

            replaceNowButton.Position = UDim2.fromOffset(0, BFS.UIConsts.CheckboxSize)
        end

        local waitingForSwitch = false

        local function switchCharacter(name)
            disconnectJump()

            ReplicatedStorage.ChangeChar:FireServer(name)

            if waitingForSwitch or not shouldReplaceHumanoid then return end
            waitingForSwitch = true

            local char = LocalPlayer.CharacterAdded:Wait()
            replaceHumanoid(char, false)

            waitingForSwitch = false
        end

        for _, name in pairs(cCharacters) do
            BFS.UI.createLabelButton(characterScroll, name, function()
                switchCharacter(name)
            end)
        end
    elseif place == "SBF" then
        BFS.UI.createCategoryLabel(characterScroll, "Accessories")

        local function changeCharAndReturn(cb)
            local char = LocalPlayer.Character
            if not char then
                return
            end

            local origPos = char:GetPrimaryPartCFrame()

            cb(char)

            if origPos then
                if not LocalPlayer.Character then
                    LocalPlayer.CharacterAdded:Wait()
                end

                if not LocalPlayer.Character.PrimaryPart then
                    LocalPlayer.Character:WaitForChild("HumanoidRootPart")
                end

                BFS.teleport(origPos)
            end
        end

        local function addAccessory(id, displayName)
            BFS.UI.createLabelButtonLarge(characterScroll, displayName, function()
                changeCharAndReturn(function(char)
                    ReplicatedStorage.Req:InvokeServer("ChangeFumo", {
                        Fumo = char:GetAttribute("FumoType"),
                        Scale = char:GetAttribute("FumoScale"),
                        Hat = id,
                    })
                end)
            end)
        end

        addAccessory("youmumyonandswords", "Myon and Swords")
        addAccessory("pancak", "Pancake")
        addAccessory("KOISHIIIIIIII", "Koishi Hat")
        addAccessory("hanyuuhat", "Straw Hat")
        addAccessory("ellyscythe", "Elly Scythe")
        addAccessory("Keine", "Keine Glasses")
        addAccessory("gagglasses", "Gag Glasses")
        -- addAccessory("EdgyHat", "Edgy Hat")
        addAccessory("ceat1", "White Socks")
        addAccessory("ceat2", "Black Socks")
        addAccessory("NikoHat", "Classic Niko Hat")
        addAccessory("MarisaHat", "Marisa Hat")
        addAccessory("Marisapc98Hat", "Marisa (PC98) Hat")
        addAccessory("Marisapc98casualHat", "Marisa (PC98 Casual) Hat")
        addAccessory("MarisasoewHat", "Marisa (SOEW) Hat")
        addAccessory("MarisaufoHat", "Marisa (UFO) Hat")
        addAccessory("Marisav2Hat", "Marisa (v2) Hat")
        addAccessory("MikoCape", "Miko Cape")
        addAccessory("meilinghat", "Meiling Hat")
        addAccessory("redmarisahat", "Red Marisa Hat")

        BFS.UI.createCategoryLabel(characterScroll, "Abilities")

        local function addAbility(id, displayName)
            BFS.UI.createLabelButtonLarge(characterScroll, displayName, function()
                ReplicatedStorage.Req:InvokeServer("CheckCharacterAbility", id)
            end)
        end

        addAbility("Koishi", "Koishi (Hide)")

        BFS.UI.createCategoryLabel(characterScroll, "Misc")

        BFS.UI.createLabelButtonLarge(characterScroll, "Velvet Room Roll", function()
            changeCharAndReturn(function()
                ReplicatedStorage.Req:InvokeServer("ChangeFumoVelvet")
            end)
        end)
    end
end -- characters

if place == "BCF" then  -- options
    local cOptionSpacing = 5

    local optionsTab = BFS.TabControl:createTab("Options", "2O", "TabOptions")

    BFS.UI.createListLayout(optionsTab, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center, cOptionSpacing)

    local function createOptionsButton(labelText, cb)
        local button

        button = BFS.UI.createLabelButtonLarge(optionsTab, labelText, function()
            cb(button)
        end)

        return button
    end

    local function openGui(name)
        if _G.GlobalDebounce then return end

        _G.GlobalDebounce = true
        ReplicatedStorage.ClientUIEvents.OpenClose:Fire(name, true)
        BFS.TabControl:closeAllTabs()
        wait(0.6)
        _G.GlobalDebounce = false
    end

    local function updateAntiGrief(button)
        local char = LocalPlayer.Character
        if not char then
            return
        end

        button.SetActive(char.PrimaryPart.CollisionGroupId == 2)
    end

    local collSignal

    local collButton = createOptionsButton("Toggle Anti-Grief", function(button)
        if _G.GlobalDebounce then return end

        _G.GlobalDebounce = true
        ReplicatedStorage.UIRemotes.SetColl:FireServer()

        if LocalPlayer.Character then
            if collSignal then
                collSignal:Disconnect()
            end

            collSignal = LocalPlayer.Character.PrimaryPart:GetPropertyChangedSignal("CollisionGroupId"):Connect(function()
                updateAntiGrief(button)
                collSignal:Disconnect()
            end)
        end

        wait(1)
        _G.GlobalDebounce = false
    end)

    updateAntiGrief(collButton)

    createOptionsButton("Day/Night Settings", function()
        openGui("DayNightSetting")
    end)

    createOptionsButton("Block Players", function()
        openGui("UserSettings")
    end)

    local specialChatValue = ReplicatedStorage.UIRemotes:FindFirstChild("SpecialChatEnabled")

    local voiceButton = createOptionsButton("Mute Special Voicelines", function(button)
        _G.GlobalDebounce = true
        specialChatValue.Value = not specialChatValue.Value
        button.SetActive(not specialChatValue.Value)
        wait(1)
        _G.GlobalDebounce = false
    end)

    voiceButton.SetActive(not specialChatValue.Value)

    createOptionsButton("BCF Credits", function()
        openGui("Credits")
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
    docsFrame.Name = "Knowledgebase"
    docsFrame.Transparency = 1
    docsFrame.BackgroundColor3 = BFS.UIConsts.BackgroundColorDark
    docsFrame.BorderSizePixel = 1
    docsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    docsFrame.Size = UDim2.fromScale(cDocsWidth, cDocsHeight)
    docsFrame.Position = cDocsPosClosed
    docsFrame.Parent = BFS.Root

    local docsClose = BFS.UI.createText(docsFrame, cDocsCloseSize)
    docsClose.Active = true
    docsClose.TextXAlignment = Enum.TextXAlignment.Center
    docsClose.TextYAlignment = Enum.TextYAlignment.Center
    docsClose.AnchorPoint = Vector2.new(1, 0)
    docsClose.Size = UDim2.fromOffset(cDocsCloseSize, cDocsCloseSize)
    docsClose.Position = UDim2.fromScale(1, 0)
    docsClose.Text = "x"

    local docsContentScroll = BFS.UI.createScroll(docsFrame)

    local docsTitle = BFS.UI.createText(docsContentScroll, cDocsTitleHeight * 0.9)
    docsTitle.TextXAlignment = Enum.TextXAlignment.Left
    docsTitle.TextYAlignment = Enum.TextYAlignment.Center
    docsTitle.Size = UDim2.new(1, -cDocsPadding, 0, cDocsTitleHeight)
    docsTitle.Position = UDim2.fromOffset(cDocsPadding, cDocsPadding)
    docsTitle.TextTruncate = Enum.TextTruncate.AtEnd

    local docsContent = BFS.UI.createText(docsContentScroll, 18)
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

        local tween = TweenService:Create(docsFrame, tweenInfo, goal)

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

    local docsTab = BFS.TabControl:createTab("Knowledgebase", "3K", "TabDocs")

    local docsScroll = BFS.UI.createListScroll(docsTab)

    function createKnowledgebaseCategory(name)
        BFS.UI.createCategoryLabel(docsScroll, name)
    end

    function addDoc(info)
        BFS.UI.createLabelButton(docsScroll, info.Label, function()
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

    addDoc({
        Label = "About this Script",
        Content = cAboutContent
    })

    local cChangelogContent = [[
<b>1.8.3</b>
- Added abilities to the 1C menu (SBF)
- Added more accessories (SBF)
- Updated animation list for Become Fumo

<b>1.8.2</b>
- Players outside the streaming radius should now have their position, but not their orientation, shown on the map
- Teleporting will now request streaming around the place you are about to go
- Added a list of players and regions you can click to focus on the map
- Added back SBF's spawns as waypoints
- In SBF, the 1C tab is back with a list of accessories you can apply to your current character
- Added a button to spawn as a velvet room character

<b>1.8.1</b>
- Added rendered maps of SBF's fountain, SDM, and RDR islands

<b>1.8.0 - Blocked</b>
- Fixed 7S tab crashing on fresh config files
- The minimap is now a library as it is shared between multiple scripts
- All plotting of waypoints/terrain on SBF is now disabled due to StreamingEnabled
- Friends are no longer indicated in blue on the minimap (for now). The feature was intermittent at best.
- Added the headbang emote on SBF
- You can now block people using the 5T tab, using essentially the same code as I submitted to Become Fumo (which was hardly used)
    - Blocking persists through the config
    - Just as everything else, blocked players are restored when you stop the script
    - It should block chat messages and hide the player, including nametag
    - People who were blocked and are occupying a seat should be translucent, although if they were sitting when you connected it may not work (and this cannot be fixed)
    * This code was tested rather extensively in the past, but there might still be problems. Report back if any.

<b>1.7.2</b>
- Added new SBF animations

<b>1.7.1b</b>
- Attempt 2 to fix execution on BCF

<b>1.7.1</b>
- Hopefully fixed execution on BCF (I did not check)

<b>1.7.0 - Tools and Postload</b>
- Added Nanodesu
- Added better handling of certain welds
- Made it so you can unweld tools without reloading the script
- Game shouldn't crash when attempting to unweld weirdly welded parts
* Certain welds will not work because of how they were made. The script will send a warning in the console, and in these cases, it is not possible to orbit.
- Automatically stop orbitting/attempting to orbit parts which are destroyed
- GUI: Binding multiple actions to the same key causes all actions to run instead of just the first one
- Replaced Tab 5 with a "Tools" tab for misc. actions like equipping everything in the backpack at once
- You can now configure BFS to load other scripts on start through the 7S section "Post-load scripts". Paste any script URL (i.e. from Github) into the list and it will load after BFS.
    - Post-loading happens every time BFS starts, and BFS will avoid loading the same script twice (if it was the one who loaded it originally).
    - More details in a Knowledgebase article titled "Manual: Niche Features"

<b>1.6.0</b>
- Waypoints are now automatically placed at each spawnpoint.
- Added an option to 7S which sets the map to render absolutely everything.
    - This is incredibly laggy and could cause your game to crash.
- Added basic support for Scuffed Become Fumo.
    - Tabs 1C and 2O are removed on SBF because I don't think they're necessary. The GUI is already very non-intrusive.
    - The animation list is specific to each place due to how animation usage permissions work.

<b>1.5.9</b>
- Policies in the Knowledgebase "Cheaters' Etiquette" article have been updated. <b>Please reread it.</b>
    - Many A2-era rules have been removed or reworded.
    - Rules relating to the BCF developers have been removed. The recommendation now is that you maintain respectful distance with them. For more information, ask me.
    * If you read Appendix I to the Code of Conduct (issued 2021/11/26), it no longer applies. It has been covered by broader rules in this update.
    * Generally, try to make a positive impact on the community.
- Added the nanodesu and Inu Sakuya animations.
- Added indicator to collision button.
- Added mute voicelines and credits buttons.
- Made the F1 key hide more of the GUI, to come in line with Photo Mode. It hides quite literally everything - core game GUIs and other exploit script's GUIs included (at least on KRNL).

<b>1.5.8</b>
- The GUI has been split into another file, which is publicly accessible.
    - It is now possible to create your own scripts with the same UI as BFS, or to extend the current script (but you should ask me how before you try).
- (BORING!) Various code quality and conventions improvements
- Added a way to have custom orbit patterns
    - Set using getgenv().orbitFunction - contact for details
- Fixed HumanoidRootPart welds causing infinite loop

<b>1.5.7</b>
- Fix error when closing script with map not loaded
- Fix bugs with right click to flash in 6R
- (BORING!) Fix logic of finding total weld offset
- Added the new block setting to the 2O menu

<b>1.5.6</b>
- Added labels to the Knowledgebase
- Scroll now zooms the map in and out while expanded
- (BORING!) Converted minimap objects to lua classes
- Added seats to the map
- <b>The RaySit function has now been removed.</b> Please use the minimap in its place (RaySit didn't work so well anyway)
- Attempt to improve reliability of tooltips
- Added waypoints to the map
- <b>The tab 5W has now been removed, and is now empty.</b> Please use the minimap in its place.
- To avoid clutter, some waypoints have been removed. Just walk to them.
- A3 has been removed from the main tab control
- Added the Spooky emote to 4A
- <b>Replace Humanoid is now disabled by default.</b> The game will automatically kick you if you ever delete your humanoid, so the feature has been hidden.
- (BORING!) Simplify 2O tab layout
- (Performance) Set tab content to invisible once they are offscreen
- (Performance) Instance.Parent is now set <i>last</i> instead of <i>first</i>. Oops!

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

    cChangelogInfo = {
        Label = "Changelog",
        Content = cChangelogContent
    }

    addDoc(cChangelogInfo)

    local cEtiquetteContent = [[
The policies are guided by the following principles:
- <b>Try to act PG-13 as much as possible.</b> Keep in mind the age demographic of this game and Roblox.
- <b>Avoid disturbing regular players.</b> Being annoying is not appreciated.
- <b>Avoid interacting with bad actors.</b> If people seek attention, giving it to them will only make it worse.
- <b>Avoid being a disappointment.</b> You know who you are.

Explicit policies are outlined below:
- <b>Do not depict fumo in inappropriate acts.</b> This covers both usage of animations and chat.
- <b>Avoid taking off fumos' clothing.</b> Try not to traumatize people.
- <b>Do not share, or attempt to share, the script with other people.</b> If you have been issued a copy which bypasses the whitelist, <i>do not share it</i>.
    - Excerpts of the source, or the complete source, may be given to you if you request them from me.

Your behavior is also governed by the Fumohouse Code of Conduct:
> https://github.com/Fumohouse/Fumohouse/blob/master/CODE_OF_CONDUCT.md

Restricted access to the script is possible with the violation of any of the above policies and principles. Restriction could last any amount of time, depending on level of infraction.
<i>Your behavior outside of the usage of this script is also covered by these rules.</i>

For questions or other information, contact me ingame, via Discord (voided#6691) or on Fumohouse's Discord:
> discord.gg/X8Z3WzA6m6
    ]]

    addDoc({
        Label = "Cheaters' Etiquette",
        Content = cEtiquetteContent
    })

    local cNicheDocsContent = [[
<b>1. The post-load scripts feature</b>
Post-load scripts can be configured through the section of the same name in the Settings (7S) tab.
Whenever BFS starts, it will load any scripts configured and run them, as long as it has not run them before in the same session.

Text boxes will appear with previously configured post-load scripts. To add one, just paste a URL into the "Script URL" spot.

Script URLs must have a URL protocol (the thing before ://).
- You can use standard http:// or https://, essentially, any URL hosted on the web (Github, Pastebin, etc). Make sure that the website responds with raw text (i.e. use raw Pastebin or raw Github links)
- You can also configure BFS to load scripts from the filesystem. If the URL protocol is "workspace://", you can add your script to the workspace folder of your exploit and add the path to the file after the protocol.
    - For KRNL, the workspace folder is in the same folder as krnl.exe.
    - For example, if there is a script located at "[WORKSPACE FOLDER]\test.lua", use the URL "workspace://test.lua".
    ]]

    addDoc({
        Label = "Manual: Niche Features",
        Content = cNicheDocsContent
    })

    createKnowledgebaseCategory("Exploit Write-ups")

    local cHumanoidContent = [[
<b>The functions mentioned in this article are no longer supported. It is preserved for historical purposes.</b>
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

    addDoc({
        Label = "Replacing Humanoid",
        Content = cHumanoidContent
    })

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

    addDoc({
        Label = "Removing Welds",
        Content = cWeldsContent
    })

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

    addDoc({
        Label = "Detaching Accessories",
        Content = cDetachContent
    })

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

    addDoc({
        Label = "ReplicatedFirst Scripts",
        Content = cChecksContent
    })

    local cA2Content = [[
Announcement, 2021/9/26

A1 is still available through the 3K menu.

A2 contains updates on the situation mentioned in A1, and also contains a set of policies that, by continuing to use this script, you are bound by. Please read both.
A2 is hosted on Google Docs, the link is in this pastebin: <i>https://pastebin.com/ssEg8dRd</i>.
If you wish to sign the document, please tell me. It may be used during negotiations.
    ]]

    addDoc({
        Label = "Update & Policies",
        Content = cA2Content
    })

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

    addDoc({
        Label = "Update Again",
        Content = cA3Content
    })
end -- docs content -- globals exposed: cChangelogInfo

do  -- animation UI
    local cSpeedFieldSize = 25
    local cSpeedFieldPadding = 5

    local activeAnimations = {}
    local stoppingAnimations = {}

    local speed = 1

    local function adjustSpeed(target)
        if speed == target then return end

        BFS.log("adjusting speed to "..tostring(target))

        for _, v in pairs(activeAnimations) do
            if v then
                v:AdjustSpeed(target)
            end
        end

        speed = target
    end

    local animationsTab = BFS.TabControl:createTab("Animations", "4A", "TabAnims")

    local speedField = BFS.UI.createTextBox(animationsTab, "Speed", cSpeedFieldSize)

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

    local animationsScroll = BFS.UI.createListScroll(animationsTab)
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

    local function stopAllAnimations()
        for k, v in pairs(activeAnimations) do
            if v then
                stopAnimation(k)
            end
        end
    end

    BFS.bindToExit("Stop All Animations", stopAllAnimations)

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
        BFS.UI.createCategoryLabel(animationsScroll, name)
    end

    function createAnimationButton(info)
        local active = false

        BFS.UI.createLabelButtonLarge(animationsScroll, info.Name, function(setActive)
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

    local lCharacter = LocalPlayer.CharacterAdded:Connect(function(char)
        stopAllAnimations()
    end)

    BFS.bindToExit("Animations: Unbind CharacterAdded", function()
        lCharacter:Disconnect()
    end)
end -- animation UI -- globals exposed: createAnimationButton, createAnimationCategory, lCharacter3

do  -- animations
    local function addAnimation(name, id)
        local info = {}
        info.Name = name
        info.Id = id

        createAnimationButton(info)
    end

    if place == "BCF" then
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
        addAnimation("Spooky", "rbxassetid://7640665121")
        addAnimation("Nanodesu", "rbxassetid://8208645816")
        addAnimation("Orin", "rbxassetid://10228321885")
        addAnimation("California", "rbxassetid://10228119453")

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

        addAnimation("Inu Sakuya - Sleep", "rbxassetid://8146736060")
        addAnimation("Inu Sakuya - Awake", "rbxassetid://8146775417")
    elseif place == "SBF" then
        createAnimationCategory("Emotes")
        addAnimation("Wave", "rbxassetid://8369377676")
        addAnimation("Point", "rbxassetid://8369361957")
        addAnimation("Dance1", "rbxassetid://8369300730")
        addAnimation("Dance2", "rbxassetid://8369304237")
        addAnimation("Dance3", "rbxassetid://7364328999")
        addAnimation("Dance4", "rbxassetid://8950972041")
        addAnimation("Laugh", "rbxassetid://8369369772")
        addAnimation("Laugh1", "rbxassetid://9081137241")
        addAnimation("Cheer", "rbxassetid://8369365889")
        addAnimation("Abunai", "rbxassetid://8377632838")
        addAnimation("Sonanoka", "rbxassetid://8377647016")
        addAnimation("September", "rbxassetid://8377653917")
        addAnimation("Scarlet Police", "rbxassetid://8377644069")
        addAnimation("Spooky", "rbxassetid://8377651174")
        addAnimation("Swag", "rbxassetid://8377648781")
        addAnimation("Caramell", "rbxassetid://8393935521")
        addAnimation("Drip", "rbxassetid://8557253884")
        addAnimation("Penguin", "rbxassetid://8557261868")
        addAnimation("Clap", "rbxassetid://8557305015")
        addAnimation("Nanodesu", "rbxassetid://8828894391")
        addAnimation("The J", "rbxassetid://8959872788")
        addAnimation("Flan Dance", "rbxassetid://8974536681")
        addAnimation("Yoinky Sploinky", "rbxassetid://9468968342")
        addAnimation("Katzotsky Kick", "rbxassetid://9119699991")
        addAnimation("Orin Dance", "rbxassetid://9612119226")
        addAnimation("Headbang", "rbxassetid://9658056382")
    end
end -- animations

do  -- block
    local ChatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")

    local BlockInfo = {}
    BlockInfo.__index = BlockInfo

    function BlockInfo.new(player)
        local obj = {}
        setmetatable(obj, BlockInfo)

        obj.Player = player
        obj.TargetTransparency = 1

        obj.CharacterAdded = player.CharacterAdded:Connect(function(char)
            obj:_characterAdded(char)
        end)

        if player.Character then
            obj:_characterAdded(player.Character)
        end

        return obj
    end

    function BlockInfo:_characterAdded(char)
        self.Transparency = {}
        self.Signals = {}
        self.AdjustingTransparency = {}

        --// During studio testing with multiple players locally, Humanoid was nil on CharacterAdded. I don't know why.
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 2)

        if hum then
            self.Seated = hum.Seated:Connect(function(active, part)
                self:updateVisibility(false)
            end)
        end

        self.DescendantAdded = char.DescendantAdded:Connect(function(inst)
            self:_updatePartVisibility(inst, false)
        end)

        self:updateVisibility(false)
    end

    function BlockInfo:_getTargetTransparency(part)
        local partTransparency = part.Transparency

        if self.Transparency[part] ~= nil then
            partTransparency = self.Transparency[part]
        end

        return math.max(partTransparency, self.TargetTransparency)
    end

    function BlockInfo:_updateBoolVisibility(part, field, visible)
        if visible then
            if self.Transparency[part] ~= nil then
                part[field] = self.Transparency[part]
            else
                part[field] = true
            end
        else
            if not self.Transparency[part] then
                self.Transparency[part] = part[field]
            end

            self.AdjustingTransparency[part] = true
            part[field] = false
            self.AdjustingTransparency[part] = false

            if self.Signals[part] then return end

            self.Signals[part] = part:GetPropertyChangedSignal(field):Connect(function()
                if not self.AdjustingTransparency[part] and part[field] then
                    self.Transparency[part] = part[field]
                    self.AdjustingTransparency[part] = true
                    part[field] = false
                    self.AdjustingTransparency[part] = false
                end
            end)
        end
    end

    function BlockInfo:_updatePartVisibility(part, visible)
        if visible and self.Signals[part] then
            self.Signals[part]:Disconnect()
            self.Signals[part] = nil
        end

        if part:IsA("BasePart") or part:IsA("Decal") then --// for numeric Transparency
            if visible then
                part.Transparency = self.Transparency[part] or 0
            else
                if not self.Transparency[part] then
                    self.Transparency[part] = part.Transparency
                end

                local targetTransparency = self:_getTargetTransparency(part)

                self.AdjustingTransparency[part] = true
                part.Transparency = targetTransparency
                self.AdjustingTransparency[part] = false

                if self.Signals[part] then return end

                self.Signals[part] = part:GetPropertyChangedSignal("Transparency"):Connect(function()
                    if not self.AdjustingTransparency[part] and math.abs(part.Transparency - targetTransparency) > 1e-3 then
                        self.Transparency[part] = part.Transparency
                        targetTransparency = self:_getTargetTransparency(part)

                        self.AdjustingTransparency[part] = true
                        part.Transparency = targetTransparency
                        self.AdjustingTransparency[part] = false
                    end
                end)
            end
        elseif part:IsA("BillboardGui") or part:IsA("Beam") or part:IsA("Trail") then --// for Enabled
            self:_updateBoolVisibility(part, "Enabled", visible)
        elseif part:IsA("RopeConstraint") then -- // for Visible
            self:_updateBoolVisibility(part, "Visible", visible)
        end
    end

    function BlockInfo:updateVisibility(visible)
        local char = self.Player.Character

        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CanCollide = visible
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then
            self.TargetTransparency = 0.9
        else
            self.TargetTransparency = 1
        end

        for k, v in pairs(char:GetDescendants()) do
            self:_updatePartVisibility(v, visible)
        end
    end

    function BlockInfo:destroy()
        self:updateVisibility(true)

        if self.CharacterAdded then self.CharacterAdded:Disconnect() end
        if self.DescendantAdded then self.DescendantAdded:Disconnect() end
        if self.Seated then self.Seated:Disconnect() end
    end

    BlockModule = {
        BlockedPlayers = {},
        BlockList = {},
        NameCache = {}
    }
    BlockModule.__index = BlockModule

    function BlockModule:init()
        self._playerAdded = Players.PlayerAdded:Connect(function(player)
            if self.BlockedPlayers[player.UserId] then
                self:setBlocked(player.UserId, true)
            end
        end)

        self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
            if self.BlockList[player.UserId] then
                self.BlockList[player.UserId]:destroy()
                self.BlockList[player.UserId] = nil
            end
        end)
    end

    function BlockModule:setBlocked(targetId, blocked)
        self.BlockedPlayers[targetId] = blocked

        local target = Players:GetPlayerByUserId(targetId)

        --// update pre-mute list
        --// this updates mutes but not unmutes. unmutes must be done explicitly.
        local blockList = {}
        for k, v in pairs(self.BlockedPlayers) do
            if v then
                blockList[#blockList + 1] = k
            end
        end

        ChatEvents.SetBlockedUserIdsRequest:FireServer(blockList)

        if place == "SBF" then
            local billboards = LocalPlayer.PlayerGui.sbfBillboards

            local nameTag = billboards:FindFirstChild(target.Name.."_NameTag")
            local chatBubble = billboards:FindFirstChild(target.Name.."_ChatBubble")

            if nameTag then
                nameTag.Enabled = not blocked
            end

            if chatBubble then
                chatBubble.Enabled = not blocked
            end
        end

        if blocked and target then
            if self.BlockList[targetId] then
                self.BlockList[targetId]:updateVisibility()
                return
            end

            local blockInfo = BlockInfo.new(target)
            blockInfo:updateVisibility()

            self.BlockList[targetId] = blockInfo
        elseif self.BlockList[targetId] then
            self.BlockList[targetId]:destroy()
            self.BlockList[targetId] = nil

            -- if not target then return end
            return

            coroutine.wrap(function()
                if not ChatEvents.UnMutePlayerRequest:InvokeServer(target.Name) then
                    warn("Failed to unmute player", targetId)
                end
            end)()
        end

        return target
    end

    function BlockModule:isBlocked(playerId)
        return self.BlockList[playerId] ~= nil
    end

    function BlockModule:getPlayerName(playerId)
        local name = self.NameCache[playerId]

        if not name then
            local player = game.Players:GetPlayerByUserId(playerId)

            if player then
                name = player.Name
            else
                local success, err = pcall(function()
                    name = game.Players:GetNameFromUserIdAsync(playerId)
                end)

                if not success then
                    return "<UNKNOWN>"
                end
            end
        end

        self.NameCache[playerId] = name

        return name
    end

    function BlockModule:deinit()
        for k, v in pairs(self.BlockList) do
            if v then
                self:setBlocked(k, false)
            end
        end
        self._playerAdded:Disconnect()
        self._playerRemoving:Disconnect()
    end

    BlockModule:init()

    BFS.bindToExit("Clean up block list", function()
        BlockModule:deinit()
    end)
end -- block

do  -- tools
    local toolsTab = BFS.TabControl:createTab("Tools", "5T", "TabTools")

    local toolsScroll = BFS.UI.createListScroll(toolsTab, 2)

    local function addToolHeader(text)
        BFS.UI.createCategoryLabel(toolsScroll, text)
    end

    local function addTool(text, callback)
        BFS.UI.createLabelButtonLarge(toolsScroll, text, callback)
    end

    addToolHeader("Backpack")

    addTool("Equip all tools", function()
        if not LocalPlayer.Character then
            return
        end

        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            tool.Parent = LocalPlayer.Character
        end
    end)

    addTool("Clear all tools", function()
        if not LocalPlayer.Character then
            return
        end

        LocalPlayer.Backpack:ClearAllChildren()

        for _, tool in pairs(LocalPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") then
                tool:Destroy()
            end
        end
    end)

    addToolHeader("Misc")

    addTool("Log running animations", function()
        if not LocalPlayer.Character then
            return
        end

        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hum then
            return
        end

        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            return
        end

        for k, v in pairs(animator:GetPlayingAnimationTracks()) do
            print("#"..tostring(k)..": "..v.Animation.AnimationId)
        end
    end)

    addToolHeader("Blocked Players")

    local cBlockedTextSize = 20

    local blockList = BFS.Config.Value.blockList

    local blockedFrame = Instance.new("Frame")
    blockedFrame.BackgroundTransparency = 1
    blockedFrame.BorderSizePixel = 0
    blockedFrame.Size = UDim2.fromScale(1, 0)
    blockedFrame.AutomaticSize = Enum.AutomaticSize.Y
    blockedFrame.Parent = toolsScroll

    BFS.UI.createListLayout(blockedFrame)

    local function addBlocked(id)
        if not blockList[id] then
            blockList[id] = true
            BFS.Config:save()
        end

        local target = BlockModule:setBlocked(id, true)

        local username
        if target then
            username = target.Name
        else
            username = Players:GetNameFromUserIdAsync(id)
        end

        local listEntry = Instance.new("Frame")
        listEntry.BackgroundTransparency = 1
        listEntry.BorderSizePixel = 0
        listEntry.Size = UDim2.fromScale(1, 0)
        listEntry.AutomaticSize = Enum.AutomaticSize.Y
        listEntry.Parent = blockedFrame

        local usernameText = BFS.UI.createText(listEntry, cBlockedTextSize)
        usernameText.TextXAlignment = Enum.TextXAlignment.Left
        usernameText.TextYAlignment = Enum.TextYAlignment.Center
        usernameText.Text = username
        usernameText.Size = UDim2.new(0.8, 0, 0, cBlockedTextSize)

        local closeButton = BFS.UI.createText(listEntry, cBlockedTextSize)
        closeButton.TextXAlignment = Enum.TextXAlignment.Center
        closeButton.TextYAlignment = Enum.TextYAlignment.Center
        closeButton.Text = "x"
        closeButton.Position = UDim2.fromScale(0.8, 0)
        closeButton.Size = UDim2.new(0.2, 0, 0, cBlockedTextSize)

        closeButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                BlockModule:setBlocked(id, false)
                listEntry:Destroy()

                blockList[id] = nil
                BFS.Config:save()
            end
        end)
    end

    for id, blocked in pairs(blockList) do
        if blocked then
            addBlocked(id)
        end
    end

    local blockField = BFS.UI.createTextBox(toolsScroll, "Player Name", 24)

    blockField.FocusLost:Connect(function(enterPressed)
        if not enterPressed then
            return
        end

        for _, player in pairs(Players:GetPlayers()) do
            if blockField.Text:lower() == player.Name:lower() then
                addBlocked(player.UserId)
                blockField.Text = ""
            end
        end
    end)
end -- tools

do  -- hats come alive
    debugL = BFS.UI.createText(BFS.Root, 18)
    debugL.Visible = BFS.Config.Value.debug
    debugL.AnchorPoint = Vector2.new(0.5, 0)
    debugL.BackgroundTransparency = 0.5
    debugL.BackgroundColor3 = BFS.UIConsts.BackgroundColor
    debugL.RichText = true
    debugL.Position = UDim2.fromScale(0.5, 0)
    debugL.AutomaticSize = Enum.AutomaticSize.XY

    local cBobThreshold = 1e-6
    local cAngleThreshold = math.pi / 48

    local commonWelds = {"Head", "Torso", "LArm", "RArm", "LLeg", "RLeg", "HumanoidRootPart"}

    -- add offsets of welds until a common part is reached
    local function findCommonWeld(weld)
        -- add offsets of welds until a common part is reached
        local checkWeld = weld
        local totalOffset = weld.C0 * weld.C1:Inverse()

        local iterations = 0

        while not table.find(commonWelds, checkWeld.Part0.Name) and not table.find(commonWelds, checkWeld.Part1.Name) do
            local found

            for _, desc in pairs(LocalPlayer.Character:GetDescendants()) do
                if desc:IsA("JointInstance") then
                    if desc ~= checkWeld then
                        if desc.Part1 == checkWeld.Part0 then
                            totalOffset = desc.C0 * desc.C1:Inverse() * totalOffset
                            checkWeld = desc

                            found = true
                        end
                    end
                end
            end

            if iterations > 1000 then
                warn("fumo WCA: Exceeded 1000 iterations on weld " .. checkWeld.Name .. ", Part0: " .. checkWeld.Part0.Name .. ", Part1: " .. checkWeld.Part1.Name)
                return
            end

            if not found then
                warn("fumo WCA: Weld path is a dead end")
                return
            end

            iterations += 1
        end

        return checkWeld, totalOffset
    end

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

    local savedLocation = nil
    local inProgress = 0
    local awaitingStart = 0

    function makeAlive(weld, cb)
        coroutine.wrap(function()
            local part = weld.Part1

            local humanRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local shouldTp = BFS.Config.Value.orbitTp

            for _, v in pairs(part:GetDescendants()) do
                if v:IsA("JointInstance") and v.Part0 == part then
                    makeAlive(v, cb)
                    if cb then cb(v) end
                end
            end

            for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                if v ~= weld and v:IsA("JointInstance") and v.Part1 == weld.Part1 then
                    v:Destroy()
                    if cb then cb(v) end
                end
            end

            if shouldTp then
                inProgress = inProgress + 1
                awaitingStart = awaitingStart + 1

                if not savedLocation then savedLocation = humanRoot.CFrame end

                BFS.teleport(CFrame.new(10000, 0, 10000))
                humanRoot.Anchored = true

                wait(2)
                awaitingStart = awaitingStart - 1

                while awaitingStart > 1 do
                    RunService.Stepped:Wait()
                end

                LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
                wait(1)
            end

            local baseWeld, totalOffset = findCommonWeld(weld)
            if not baseWeld then
                warn("fumo WCA: Something is wrong! Did not find a base weld.")
            else
                part.CanTouch = true

                local pos = Instance.new("BodyPosition")
                pos.P = 500000
                pos.D = 1000
                pos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                pos.Position = part.Position
                pos.Parent = part

                local gyro = Instance.new("BodyGyro")
                gyro.P = 500000
                gyro.D = 1000
                gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                gyro.Parent = part

                local antiG = Instance.new("BodyForce")
                antiG.Force = Vector3.new(0, part:GetMass() * workspace.Gravity, 0)
                antiG.Parent = part

                local partInfo = {}
                partInfo.Weld = weld
                partInfo.TargetName = baseWeld.Part0.Name
                partInfo.Part = part
                partInfo.Pos = pos
                partInfo.Gyro = gyro
                partInfo.TotalOffset = totalOffset

                parts[#parts + 1] = partInfo

                part.Touched:Connect(function(otherPart)
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

                part.AncestryChanged:Connect(function(_, parent)
                    if parent then
                        return
                    end

                    for i, partData in pairs(parts) do
                        if partData.Part == part then
                            print("fumo WCA: Stopped tracking part", part.Name, "(#"..tostring(i)..")")
                            table.remove(parts, i)
                            break
                        end
                    end
                end)

                weld:Destroy()
                part.Velocity = Vector3.new(0, 100, 0)
                part.Anchored = true
            end

            if shouldTp then
                wait(2)
                inProgress = inProgress - 1

                if inProgress == 0 then
                    BFS.teleport(savedLocation)
                    savedLocation = nil
                    humanRoot.Anchored = false
                    LocalPlayer.CameraMode = Enum.CameraMode.Classic
                end
            end
        end)()
    end

    local function defaultOrbitFunction(ctx)
        local theta = (ctx.Time + 10 * ctx.PartIndex) * 3
        local xOff = math.cos(theta)
        local yOff = math.sin(theta)
        local zOff = math.cos(theta * 2) / 2

        return ctx.Pivot.Position + Vector3.new(xOff, zOff, yOff) * 2
    end

    local function updatePart(info, raycastPos, t, dT, idx)
        local debugReport = {}

        debugReport.Part = info.Part
        debugReport.TargetName = info.TargetName

        local targetPos
        local alpha = 1

        local ang = ((t + 10 * idx) * math.pi) % (2 * math.pi)

        local target = tpTarget or LocalPlayer.Character
        local targetPart = target:FindFirstChild(info.TargetName)

        if targetPart:IsA("Model") then
            targetPart = targetPart:FindFirstChild(info.TargetName)
        end

        if not targetPart then
            if tpTarget == LocalPlayer.Character then
                targetPart = info.Weld.Part0
            else
                targetPart = tpTarget.Torso.Torso

                for _, v in pairs(parts) do
                    if v and v.Part.Name == info.TargetName then
                        targetPart = v.Part
                    end
                end
            end
        end

        if raycastPos then
            debugReport.Type = "cast"

            targetPos = raycastPos
            alpha = 0.3
            info.Gyro.CFrame = CFrame.Angles(0, ang, 0)
        elseif tpTarget then
            debugReport.Type = "follow"

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

            -- Function should return either one value (the position of the part, global space)
            -- or two values (the position and the rotation of the part, rotation being a CFrame (i.e. use CFrame.Angles or similar))
            local orbitFunction = getgenv().orbitFunction or defaultOrbitFunction

            local pivot

            if LocalPlayer.Character.Torso.Torso:FindFirstChild("Head") then
                pivot = LocalPlayer.Character.Head.Head.CFrame
            else
                pivot = LocalPlayer.Character.Torso.Torso.CFrame
            end

            local pos, angle = orbitFunction({
                Pivot = pivot, -- Pivot location (always head or torso) (CFrame)
                Time = t, -- Game time (seconds) (Number)
                PartIndex = idx, -- Part index, starting from 1 (Number)
                PartInfo = info, -- Various information on the part orbitting (.Part - Part that is orbiting, .TotalOffset - CFrame offset from TargetPart to original weld location)
                TargetPart = targetPart, -- Body part that the part was originally welded to (Part)
            })

            targetPos = pos
            info.Gyro.CFrame = angle or CFrame.Angles(ang, ang, ang)

            alpha = 0.2
        end

        local dist = math.sqrt((targetPos.X - info.Pos.Position.X)^2 + (targetPos.Y - info.Pos.Position.Y)^2)

        if alpha ~= 1 and dist < 1000 then
            info.Pos.Position = info.Pos.Position:Lerp(targetPos, alpha * 60 * dT)
        else
            info.Pos.Position = targetPos
        end

        return debugReport
    end

    local lInputB = UserInput.InputBegan:Connect(function(input, handled)
        if not handled and input.UserInputType == Enum.UserInputType.MouseButton3 then
            draggedAway = tpTarget
            resetTpTarget()
            mousePos = input.Position
        end
    end)

    local lInputC = UserInput.InputChanged:Connect(function(input, handled)
        if not handled and input.UserInputType == Enum.UserInputType.MouseMovement and mousePos then
            mousePos = input.Position
        end
    end)

    local lInputE = UserInput.InputEnded:Connect(function(input, handled)
        if not handled and input.UserInputType == Enum.UserInputType.MouseButton3 then
            mousePos = nil
            draggedAway = nil
        end
    end)

    local lStepped = RunService.Stepped:Connect(function(t, dT)
        local idx = 0
        local raycastPos

        if mousePos then
            local unitRay = workspace.CurrentCamera:ScreenPointToRay(mousePos.X, mousePos.Y)
            local params = RaycastParams.new()

            if place == "BCF" then
                params.FilterDescendantsInstances = { LocalPlayer.Character, workspace.MusicPlayer.SoundRegions, workspace.PlayArea["invis walls"] }
            elseif place == "SBF" then
                params.FilterDescendantsInstances = { LocalPlayer.Character }
            end

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

        for _, info in pairs(parts) do
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

    local lHeartbeat = RunService.Heartbeat:Connect(function()
        for _, info in pairs(parts) do
            if info then
                info.Part.Velocity = Vector3.new(0, 35, 0)
            end
        end
    end)

    local lCharacter = LocalPlayer.CharacterAdded:Connect(function(char)
        parts = {}
        resetTpTarget()
    end)

    BFS.bindToExit("HCA: Clean up", function()
        lHeartbeat:Disconnect()
        lStepped:Disconnect()
        lInputB:Disconnect()
        lInputC:Disconnect()
        lInputE:Disconnect()
        lCharacter:Disconnect()
    end)
end -- hats come alive -- globals exposed: makeAlive, debugL

do  -- welds
    local weldsTab = BFS.TabControl:createTab("Remove Welds", "6R", "TabWelds")

    local weldsScroll = BFS.UI.createListScroll(weldsTab, 2)

    local savedLocation
    local inProgress = 0

    local function deleteWeld(weld, cb)
        inProgress = inProgress + 1

        for _, v in pairs(weld.Part1:GetChildren()) do -- destroying parts in this loop causes death.
            -- notify caller that something other than the weld was destroyed,
            -- mostly so welds that were deleted in this operation are also removed from the list
            cb(v)
        end

        weld.Part1:ClearAllChildren()

        -- allows for tp-back location to be correct between concurrent calls.
        local origPos = BFS.teleport(CFrame.new(31, 45, 50, 1, 0, 0, 0, 1, 0, 0, 0, 1))
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
            BFS.teleport(savedLocation)
            savedLocation = nil
        end

        inProgress = inProgress - 1
    end

    local welds = {}

    local function removeWeldButton(weld)
        for _, l in pairs(welds) do
            if l and l.Weld == weld then
                l.Label:Destroy()
            end
        end
    end

    local function addWeld(weld)
        local label
        local tween

        local labelInfo = BFS.UI.createLabelButtonLarge(weldsScroll, weld.Name, function(setActive, type)
            if not weld.Parent then return end

            if type == Enum.UserInputType.MouseButton1 then
                setActive(true)

                deleteWeld(weld, function(p)
                    for _, l in pairs(welds) do
                        if l and l.Weld == p or l.Weld.Part0 == p or l.Weld.Part1 == p then
                            l.Label:Destroy()
                        end
                    end
                end)

                if label then label:Destroy() end
            elseif type == Enum.UserInputType.MouseButton2 then
                if tween then return end

                local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 5, true)
                local goal = {}
                goal.Transparency = 1
                tween = TweenService:Create(weld.Part1, tweenInfo, goal)

                setActive(true)
                tween:Play()

                tween.Completed:Wait()
                setActive(false)

                tween = nil
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

        local weldInfo = {}
        weldInfo.Label = label
        weldInfo.Weld = weld

        welds[#welds + 1] = weldInfo
    end

    local lCharacterDescendantAdded, lCharacterDescendantRemoved

    local function updateChar(char)
        for _, l in pairs(welds) do
            l.Label:Destroy()
        end

        welds = {}

        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("JointInstance") then
                addWeld(v)
            end
        end

        lCharacterDescendantAdded = char.DescendantAdded:Connect(function(desc)
            if desc:IsA("JointInstance") then
                addWeld(desc)
            end
        end)

        lCharacterDescendantRemoved = char.DescendantRemoving:Connect(function(desc)
            if desc:IsA("JointInstance") then
                removeWeldButton(desc)
            end
        end)
    end

    local function setChar(char)
        updateChar(char)
    end

    local lCharacter = LocalPlayer.CharacterAdded:Connect(function(char)
        setChar(char)
    end)

    BFS.bindToExit("Welds: Unbind CharacterAdded", function()
        lCharacter:Disconnect()

        if lCharacterDescendantAdded then
            lCharacterDescendantAdded:Disconnect()
        end

        if lCharacterDescendantRemoved then
            lCharacterDescendantRemoved:Disconnect()
        end
    end)

    if LocalPlayer.Character then setChar(LocalPlayer.Character) end
end -- welds

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

    local cBinds = { "TabCharacters", "TabOptions", "TabDocs", "TabAnims", "TabTools", "TabWelds", "TabSettings", "HideGui", "MapVis", "MapView", "Exit" }

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

    local weldFrame = createSettingsCategory("Weld Options")

    addCheckbox(weldFrame, "Orbit Teleport", "orbitTp")
    addCheckbox(weldFrame, "Debug", "debug", function(checked)
        debugL.Visible = checked
    end)

    local mapFrame = createSettingsCategory("Map Options")

    addCheckbox(mapFrame, "Map Everything", "mapRenderEverything")

    local postLoadFrame = createSettingsCategory("Post-load scripts")
    local postLoadTextBoxes = {}

    local function updatePostLoads()
        local urls = {}

        for _, textBox in pairs(postLoadTextBoxes) do
            if textBox.Text ~= "" then
                urls[#urls + 1] = textBox.Text
            end
        end

        BFS.Config.Value.postLoad = urls
        BFS.Config:save()
    end

    local function addPostLoadBox(initialText)
        local textBox = BFS.UI.createTextBox(postLoadFrame, "Script URL", 24)
        textBox.Text = initialText or ""

        textBox.FocusLost:Connect(function()
            local idx = table.find(postLoadTextBoxes, textBox)

            if idx == #postLoadTextBoxes then
                if textBox.Text ~= "" then
                    addPostLoadBox()
                end
            else
                if textBox.Text == "" then
                    textBox:Destroy()
                    table.remove(postLoadTextBoxes, idx)
                end
            end

            updatePostLoads()
        end)

        postLoadTextBoxes[#postLoadTextBoxes + 1] = textBox
    end

    for _, url in pairs(BFS.Config.Value.postLoad) do
        addPostLoadBox(url)
    end

    addPostLoadBox()
end -- settings

do  -- info
    local cInfoText =            "<b>Become Fumo Scripts</b><br />"
    cInfoText = cInfoText.."version "..version.."<br /><br />"
    cInfoText = cInfoText.."Created by voided_etc, 2021<br /><br />"
    cInfoText = cInfoText.."<i>Confused? Navigate to the Knowledgebase to see if any of your questions are answered there.</i><br /><br />"
    cInfoText = cInfoText.."Thank you, "..LocalPlayer.Name.."!"

    cInfoLabel = "Info"
    local infoTab = BFS.TabControl:createTab(cInfoLabel, "I")

    local infoText = BFS.UI.createText(infoTab, 18)
    infoText.TextXAlignment = Enum.TextXAlignment.Center
    infoText.TextYAlignment = Enum.TextYAlignment.Center
    infoText.Size = UDim2.fromScale(1, 1)
    infoText.Position = UDim2.fromScale(0, 0)
    infoText.TextWrapped = true
    infoText.RichText = true

    infoText.Text = cInfoText
end -- info

do  -- minimap
    function plotAreas(map)
        local cArea = Color3.fromRGB(86, 94, 81)
        local cAreaB = Color3.fromRGB(89, 149, 111)

        if place == "BCF" then
            local mwCf, mwSize = workspace.PlayArea["invis walls"]:GetBoundingBox()
            map:plotBBox(mwCf, mwSize, cArea, cAreaB, map.AreaLayer)

            local cBeachCf = CFrame.new(-978.322266, 134.538483, 8961.99805, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- the roof barrier
            local cBeachSize = Vector3.new(273.79, 29.45, 239.5)
            map:plotBBox(cBeachCf, cBeachSize, cArea, cAreaB, map.AreaLayer)

            local ruinsMin, ruinsMax = map:_findBounds({ map:_findZone("Ruins") }, function(inst) return inst.Name ~= "bal" end)
            local ruinsCenter = CFrame.new((ruinsMin + ruinsMax) / 2)
            map:plotBBox(ruinsCenter, ruinsMax - ruinsMin, cArea, cAreaB, map.AreaLayer)

            local velvetMin, velvetMax = map:_findBounds({ map:_findZone("VelvetRoom") })
            local velvetCenter = CFrame.new((velvetMin + velvetMax) / 2)
            map:plotBBox(velvetCenter, velvetMax - velvetMin, cArea, cAreaB, map.AreaLayer)
        end
    end

    local cEpsilon = 1e-7
    local function almostEqual(v1, v2, epsilon)
        if not epsilon then epsilon = cEpsilon end
        return math.abs(v1 - v2) < epsilon
    end

    function plotTerrain(map)
        local features
        local seatList

        if place == "BCF" then
            features = workspace.PlayArea:GetDescendants()
            seatList = { features, workspace.ActiveZone:GetDescendants(), ReplicatedStorage.Zones:GetDescendants() }

            local cWater = Color3.fromRGB(70, 92, 86)
            local cWaterB = Color3.fromRGB(2, 135, 99)

            local cPoolCf = CFrame.new(51.980999, -16.854372, -63.6765823, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- cframe and size of the pool floor
            local cPoolSize = Vector3.new(45.3603, 5.33651, 32.0191)

            map:plotBBox(cPoolCf, cPoolSize, cWater, cWaterB)
        elseif place == "SBF" then
            features = workspace.Map:GetDescendants()
            seatList = { features }
        end

        local cTree = Color3.fromRGB(89, 149, 111)
        local cTreeB = Color3.fromRGB(5, 145, 56)

        local cRock = Color3.fromRGB(89, 105, 108)
        local cRockB = Color3.fromRGB(89, 89, 89)

        local cParkourSize = 4.0023837089539
        local cParkourEpsilon = 1e-2

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
                map:plotPartQuad(v, v.Color, cRockB)
            end

            local cBench = Color3.fromRGB(173, 125, 110)
            local cBenchB = Color3.fromRGB(173, 88, 62)

            for _, v in pairs(features) do -- bench
                if v:IsA("Model") and (v.Name == "Bench" or v.Name == "log") then
                    local cf, size = v:GetBoundingBox()
                    map:plotBBox(cf, size, cBench, cBenchB)
                end
            end

            -- ALL SEATS!!!
            for _, list in pairs(seatList) do
                for _, v in pairs(list) do
                    if v:IsA("Seat") then
                        local seatObj = BFSMap.MapSeat.new(map, v)
                        map:addMapObject(seatObj, map.SeatLayer)
                        map.Tooltips:register(seatObj)
                    end
                end
            end
        elseif place == "BCF" then
            for _, v in pairs(features) do -- not so important stuff
                if v:IsA("Model") and v.Name == "stupid tree1" then -- single square trees
                    map:plotPartQuad(v:FindFirstChild("Part"), cTree, cTreeB)
                elseif v:IsA("Part") then
                    local children = v:GetChildren()

                    if v.Color == cRock then -- any rocks
                        map:plotPartQuad(v, cRock, cRockB)
                    elseif almostEqual(v.Size.X, cParkourSize, cParkourEpsilon) and -- parkour
                        almostEqual(v.Size.Z, cParkourSize, cParkourEpsilon) and
                        #children >= 6 and children[1]:IsA("Texture") and children[1].Texture == "http://www.roblox.com/asset/?id=6022009301" then
                        map:plotPartQuad(v, v.Color, cRockB)
                    end
                end
            end
        end

        if place == "BCF" then
            local spawns = workspace.Spawns:GetChildren()
            local cColorSpawn
            local cColorSpawnB

            cColorSpawn = Color3.fromRGB(255, 166, 193)
            cColorSpawnB = Color3.fromRGB(247, 0, 74)

            local cSpawnOffset = Vector3.new(0, 0.5, 0)

            for _, v in pairs(spawns) do
                map:plotPartQuad(v, cColorSpawn, cColorSpawnB)
                map:plotWaypoint(v.Name, v.CFrame + cSpawnOffset, cColorSpawnB)
            end
        end
    end

    function plotWaypoints(map)
        if place == "BCF" then
            local cItemColor = Color3.fromRGB(61, 161, 255)

            map:plotWaypoint("Burger/Soda", CFrame.new(-12.6373434, -2.39721942, -104.279655, 0.999609232, -9.48658307e-09, -0.0279524103, 9.50391588e-09, 1, 4.87206442e-10, 0.0279524103, -7.5267359e-10, 0.999609232), cItemColor)
            map:plotWaypoint("Japari Bun (Rock)", CFrame.new(44.2933311, 2.69040394, -174.404465, -0.926118135, 2.03467754e-09, -0.377233654, -1.18587207e-09, 1, 8.30502511e-09, 0.377233654, 8.13878565e-09, -0.926118135), cItemColor)
            map:plotWaypoint("Shrimp Fry", CFrame.new(23.7285004, -3.39721847, -38.656456, -0.999925613, 1.10185701e-08, 0.0121939164, 1.07577787e-08, 1, -2.14526548e-08, -0.0121939164, -2.13198827e-08, -0.999925613), cItemColor)
            map:plotWaypoint("Ice Cream", CFrame.new(47.6086464, -2.35769129, 86.1823273, -0.999982059, 1.08832019e-08, 0.00585500291, 1.07577787e-08, 1, -2.14526548e-08, -0.00585500291, -2.13892744e-08, -0.999982059), cItemColor)
            map:plotWaypoint("Bike", CFrame.new(41.1308136, -3.39721847, 70.4393082, 0.999999881, -4.17922266e-08, 0.000145394108, 4.18030872e-08, 1, -7.49089111e-08, -0.000145394108, 7.49150004e-08, 0.999999881), cItemColor)
            map:plotWaypoint("Fishing Rod", CFrame.new(-50.5187149, 1.6041007, -120.919296, 0.998044968, 5.13549168e-08, -0.0625005439, -5.57155957e-08, 1, -6.80274113e-08, 0.0625005439, 7.13766752e-08, 0.998044968), cItemColor)
            map:plotWaypoint("Baseball", CFrame.new(63.9862785, 1.61707997, -113.393738, 0.852416873, -1.00618301e-07, 0.522862673, 9.67299414e-08, 1, 3.47396458e-08, -0.522862673, 2.09638351e-08, 0.852416873), cItemColor)
            map:plotWaypoint("LunarTech Rifle", CFrame.new(-76.0725632, -3.39721847, -122.150734, 0.00984575041, 1.867169e-08, -0.999951541, -1.71646324e-08, 1, 1.85035862e-08, 0.999951541, 1.69816179e-08, 0.00984575041), cItemColor)
            map:plotWaypoint("Buster Gauntlets", CFrame.new(3.52978015, 8.10278034, -103.847221, -0.999056339, -9.71976277e-08, 0.0434325524, -9.49071506e-08, 1, 5.47984236e-08, -0.0434325524, 5.06246529e-08, -0.999056339), cItemColor)
            map:plotWaypoint("Trolldier Set", CFrame.new(-57.4301414, 36.6266022, -77.7773438, 0.0280102566, 2.76124923e-09, 0.999607563, -8.18409589e-08, 1, -4.69047745e-10, -0.999607563, -8.17956973e-08, 0.0280102566), cItemColor)
            map:plotWaypoint("Soul Edge", CFrame.new(62.3707314, 22.2510509, 45.5647964, -0.0124317836, 7.14263138e-08, -0.999922097, 3.7549458e-10, 1, 7.14271877e-08, 0.999922097, 5.12501597e-10, -0.0124317836), cItemColor)
            map:plotWaypoint("Chair", CFrame.new(-14.3926878, -3.39721847, -127.052185, -0.998602152, -1.55643036e-08, 0.0528521165, -2.24233379e-08, 1, -1.29184926e-07, -0.0528521165, -1.30189534e-07, -0.998602152), cItemColor)
            map:plotWaypoint("Gigasword", CFrame.new(-54.6563225, 22.4595356, -172.48053, 0.320373297, 5.91488103e-08, 0.947291434, 1.88988629e-08, 1, -6.88315112e-08, -0.947291434, 3.99545073e-08, 0.320373297), cItemColor)
            map:plotWaypoint("Totsugeki", CFrame.new(-15.5478992, -3.39721918, 110.352875, 0.99858731, 6.11212769e-08, -0.0531353056, -6.31656292e-08, 1, -3.67950932e-08, 0.0531353056, 4.00994402e-08, 0.99858731), cItemColor)

            local cE0Color = Color3.fromRGB(61, 255, 122)

            map:plotWaypoint("Campfire (Cave)", CFrame.new(50.5005188, -3.27936959, 45.8245049, 0.511625528, -1.06045634e-08, 0.859208643, 3.62333026e-08, 1, -9.23321064e-09, -0.859208643, 3.58559191e-08, 0.511625528), cE0Color)
            map:plotWaypoint("Campfire (Ground) & Gamer Shack", CFrame.new(-35.0969467, -3.39721847, -5.80594683, -0.782029748, 2.27397319e-08, -0.623240769, 3.63110004e-08, 1, -9.07598174e-09, 0.623240769, -2.97281399e-08, -0.782029748), cE0Color)
            map:plotWaypoint("Campfire (Poolside)", CFrame.new(49.8565903, 1.61707997, -102.113022, 0.53096503, -5.22703569e-09, -0.847393513, 5.28910675e-08, 1, 2.69724456e-08, 0.847393513, -5.9140973e-08, 0.53096503), cE0Color)
            map:plotWaypoint("Miko Borgar (Door)", CFrame.new(-1.05410039, -3.39721847, -82.1947021, 0.998766482, -2.69013523e-08, -0.0496555455, 3.06295682e-08, 1, 7.43202406e-08, 0.0496555455, -7.57493979e-08, 0.998766482), cE0Color)
            map:plotWaypoint("Pond", CFrame.new(-51.4066544, -2.45410466, -103.242828, -0.937839568, 3.27229159e-08, 0.347069085, 3.4841225e-08, 1, -1.36675046e-10, -0.347069085, 1.19641328e-08, -0.937839568), cE0Color)
            map:plotWaypoint("Pool (Benches)", CFrame.new(30.9888954, -3.39721847, -80.3704605, -0.715499997, -5.40728564e-08, -0.698610604, -1.14304344e-09, 1, -7.62298313e-08, 0.698610604, -5.37439142e-08, -0.715499997), cE0Color)
            map:plotWaypoint("Cirno Statues", CFrame.new(49.1739616, -3.39721847, -8.75012016, -0.543244958, -6.46215383e-08, -0.839574218, -1.14304521e-09, 1, -7.62298455e-08, 0.839574218, -4.04518019e-08, -0.543244958), cE0Color)
            map:plotWaypoint("Treehouse", CFrame.new(31.4564857, 35.6251411, 50.0041885, 0.715494156, 5.91811222e-08, 0.69861877, 3.8019552e-09, 1, -8.86053471e-08, -0.69861877, 6.60527633e-08, 0.715494156), cE0Color)
            map:plotWaypoint("Bouncy Castle", CFrame.new(0.475164026, -3.39721847, 23.8564453, -0.99950707, 9.88343851e-10, 0.0313819498, -1.32396899e-10, 1, -3.57108298e-08, -0.0313819498, -3.56973651e-08, -0.99950707), cE0Color)
            map:plotWaypoint("Slide (Small Hill)", CFrame.new(-50.6221809, 9.94405937, 56.1536865, 0.997613728, 2.3075911e-08, -0.0690322742, -2.23911307e-08, 1, 1.06936717e-08, 0.0690322742, -9.12244946e-09, 0.997613728), cE0Color)
            map:plotWaypoint("Slide (Poolside)", CFrame.new(40.0324783, 6.6087389, -39.532444, 0.999875724, -1.93160812e-08, -0.0157229118, 1.95169676e-08, 1, 1.26231088e-08, 0.0157229118, -1.29284112e-08, 0.999875724), cE0Color)
            map:plotWaypoint("Funky Room", CFrame.new(-68.484436, -3.39721847, 60.7482109, -2.32830644e-10, -3.11954729e-08, -0.999997795, 5.44967769e-08, 1, -3.11955013e-08, 0.999997795, -5.44967342e-08, -2.32830644e-10), cE0Color)
            map:plotWaypoint("Suwako Room", CFrame.new(-61.846508, -3.39721847, -66.5909882, 0.00312713091, -3.28514393e-09, -0.999995053, 7.25480831e-08, 1, -3.05829273e-09, 0.999995053, -7.25381568e-08, 0.00312713091), cE0Color)
            map:plotWaypoint("Lobster", CFrame.new(5.77875519, -12.7361145, -63.4011688, 0.999820292, 1.11183072e-08, -0.0189436078, -9.94847138e-09, 1, 6.18481266e-08, 0.0189436078, -6.16485281e-08, 0.999820292), cE0Color)
            map:plotWaypoint("Izakaya", CFrame.new(-6.60881424, -3.277318, -45.8185806, -0.0179589726, -3.68412358e-08, 0.99983871, -8.20734258e-10, 1, 3.68324358e-08, -0.99983871, -1.59129168e-10, -0.0179589726), cE0Color)

            local cE1Color = Color3.fromRGB(255, 196, 61)

            map:plotWaypoint("Savanna", CFrame.new(37.7001686, -3.40405059, -137.407516, 0.999959052, 4.18167581e-08, 0.00899411179, -4.13985326e-08, 1, -4.66871946e-08, -0.00899411179, 4.63129659e-08, 0.999959052), cE1Color)
            map:plotWaypoint("Blue Door", CFrame.new(-33.5249329, -3.39721847, -211.964386, -0.999284327, 2.38968401e-08, 0.037821576, 2.54846189e-08, 1, 4.14982999e-08, -0.037821576, 4.24324718e-08, -0.999284327), cE1Color)
            map:plotWaypoint("Train Station", CFrame.new(-54.2110176, 6.25, -161.287369, -0.999873161, 7.6191661e-08, 0.0159097109, 7.52258629e-08, 1, -6.13025932e-08, -0.0159097109, -6.0098003e-08, -0.999873161), cE1Color)

            local cE2Color = Color3.fromRGB(242, 255, 61)

            map:plotWaypoint("Fountain", CFrame.new(35.8924446, -2.35769129, 96.6178894, -0.0536103845, -2.98055269e-08, -0.998561919, -6.42211972e-08, 1, -2.64005671e-08, 0.998561919, 6.27135108e-08, -0.0536103845), cE2Color)
            map:plotWaypoint("Ratcade", CFrame.new(3.75609636, -3.39721847, 89.8193359, 0.0222254563, 5.80779727e-08, 0.999752939, 3.18127285e-08, 1, -5.87995359e-08, -0.999752939, 3.31117072e-08, 0.0222254563), cE2Color)
            map:plotWaypoint("Inside UFO Catcher", CFrame.new(-37.7735367, -0.92603755, 78.7536469, -0.999979138, -6.31962678e-08, 0.00645794719, -6.36200426e-08, 1, -6.5419826e-08, -0.00645794719, -6.5829326e-08, -0.999979138), cE2Color)
            map:plotWaypoint("Beach Portal", CFrame.new(67.0926361, -2.81909084, 99.9620361, -0.34926942, 1.66901373e-08, -0.937022328, 5.79714232e-08, 1, -3.79660969e-09, 0.937022328, -5.56465594e-08, -0.34926942), cE2Color)
        end
    end
end -- minimap -- globals exposed: Minimap

do  -- update info
    if BFS.Config.Value.version ~= version then
        local tabButtonInfo = BFS.TabControl:createTabButton("Update Info", "!")

        tabButtonInfo.Tab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                openPage(cChangelogInfo)

                BFS.TabControl:removeTabButton(tabButtonInfo)
            end
        end)

        local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)

        local goal = {}
        goal.BackgroundColor3 = Color3.fromRGB(255, 165, 0)

        local tween = TweenService:Create(tabButtonInfo.Tab, tweenInfo, goal)
        tween:Play()

        BFS.Config.Value.version = version
        BFS.Config:save()
    end
end -- update info

do  -- announcements
    --[[
    local tabButtonInfo = BFS.TabControl:createTabButton("Announcement", "!A3!")

    tabButtonInfo.Tab.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            openPage(cA3Info)
        end
    end)
    ]]
end -- announcements

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
        map = BFSMap.Minimap.new(secondaryRoot, 30)
        plotAreas(map)
        plotTerrain(map)
        BFSMap.Presets.SBF:setup(map)
        plotWaypoints(map)

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

do  -- postload
    local loadedScripts = getgenv().loadedScripts
    if not loadedScripts then
        loadedScripts = {}
        getgenv().loadedScripts = loadedScripts
    end

    local cWorkspacePrefix = "workspace://"

    local function startsWith(str, prefix)
        return string.sub(str, 1, #prefix) == prefix
    end

    for _, url in pairs(BFS.Config.Value.postLoad) do
        if table.find(loadedScripts, url) then
            print("fumo postload: Skipping", url, "as it has already been loaded by BFS.")
        else
            if startsWith(url, "http://") or startsWith(url, "https://") then
                loadstring(game:HttpGet((url), true))()
            elseif startsWith(url, cWorkspacePrefix) then
                loadstring(readfile(string.sub(url, #cWorkspacePrefix + 1)))()
            end

            loadedScripts[#loadedScripts + 1] = url
        end
    end
end -- postload
