repeat task.wait() until game:IsLoaded()

if _G.GlokHubLoaded then return end
_G.GlokHubLoaded = true

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local PlaceId = game.PlaceId

_G.autoStartFinder = false
_G.finderRunning = false

local basePosition = nil

-- GET HRP
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- NOTIFY
local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Glok Hub",
            Text = msg,
            Duration = 5
        })
    end)
end

-- BELL
local function playBell()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9118823104"
    sound.Volume = 5
    sound.Parent = workspace
    sound:Play()
    game.Debris:AddItem(sound, 3)
end

-- SAFE STEP TELEPORT
local function stepTeleport(destination)
    local hrp = getHRP()

    local distance = (hrp.Position - destination).Magnitude
    local steps = math.clamp(math.floor(distance / 10), 8, 60)

    for i = 1, steps do
        hrp = getHRP()
        local newPos = hrp.Position:Lerp(destination, i / steps)
        hrp.CFrame = CFrame.new(newPos + Vector3.new(0,4,0))
        task.wait(0.06)
    end

    hrp = getHRP()
    hrp.CFrame = CFrame.new(destination + Vector3.new(0,4,0))
end

-- SAFE LOCK POSITION
local function lockPosition(pos, duration)
    local start = tick()

    while tick() - start < duration do
        local hrp = getHRP()
        hrp.CFrame = CFrame.new(pos + Vector3.new(0,4,0))
        task.wait(0.1)
    end
end

-- SET BASE
function setBase()
    local hrp = getHRP()
    basePosition = hrp.Position
    notify("Base Saved")
end

-- TP TO BASE
function tpToBase()
    if basePosition then
        stepTeleport(basePosition)
        lockPosition(basePosition, 0.5)
    else
        notify("Set Base First")
    end
end

-- MONEY PARSER
local function parseMoney(str)
    if not str then return 0 end
    str = string.lower(str)

    if str:find("b") then return tonumber(str:gsub("b",""))*1e9 end
    if str:find("m") then return tonumber(str:gsub("m",""))*1e6 end
    if str:find("k") then return tonumber(str:gsub("k",""))*1e3 end

    return tonumber(str) or 0
end

-- GRAB BRAINROT
local function grabBrainrot(model)
    if not basePosition then
        notify("Set Base First!")
        return
    end

    local targetPart = model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChild("Head") 
        or model:FindFirstChildWhichIsA("BasePart")

    if targetPart then
        stepTeleport(targetPart.Position)
        task.wait(0.5)

        for _, v in pairs(model:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                fireproximityprompt(v)
            end
        end

        task.wait(0.5)
        stepTeleport(basePosition)
        lockPosition(basePosition, 0.5)
    end
end

-- CHECK SERVER FOR 100M
local function serverHas100M()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("TextLabel") and v.Text and v.Text:find("/sec") then
            local money = parseMoney(v.Text)
            if money >= 100000000 then
                return true, v.Text, v:FindFirstAncestorOfClass("Model")
            end
        end
    end
    return false
end

-- FINDER
function startFinder(statusLabel)
    if _G.finderRunning then return end
    _G.finderRunning = true

    notify("Finder Started")

    while _G.finderRunning do
        statusLabel.Text = "Status: Checking Server..."

        local found, text, model = serverHas100M()

        if found then
            statusLabel.Text = "Status: FOUND "..text
            notify("FOUND: "..text)
            playBell()

            if model then
                grabBrainrot(model)
            end

            _G.finderRunning = false
            return
        end

        statusLabel.Text = "Status: Server Hop..."

        local url = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(game:HttpGet(url))

        for _, server in pairs(data.data) do
            if server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(PlaceId, server.id, player)
                task.wait(5)
            end
        end

        task.wait(2)
    end
end

function stopFinder()
    _G.finderRunning = false
    notify("Finder Stopped")
end

-- GUI
pcall(function()
    game.CoreGui:FindFirstChild("GlokHubUI"):Destroy()
end)

local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "GlokHubUI"

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,230,0,320)
frame.Position = UDim2.new(0,50,0,100)
frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
frame.Active = true
frame.Draggable = true

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,30)
title.Text = "GLOK HUB V6"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundColor3 = Color3.fromRGB(20,20,20)

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1,0,0,30)
status.Position = UDim2.new(0,0,0,30)
status.Text = "Status: Idle"
status.TextColor3 = Color3.new(1,1,1)
status.BackgroundColor3 = Color3.fromRGB(30,30,30)

local function button(name, y, callback)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1,-20,0,30)
    b.Position = UDim2.new(0,10,0,y)
    b.Text = name
    b.BackgroundColor3 = Color3.fromRGB(40,40,40)
    b.TextColor3 = Color3.new(1,1,1)
    b.MouseButton1Click:Connect(callback)
end

button("Set Base", 70, setBase)
button("TP To Base", 110, tpToBase)
button("Start Finder", 150, function() startFinder(status) end)
button("Stop Finder", 190, stopFinder)

-- AUTO START AFTER TELEPORT
task.spawn(function()
    task.wait(8)
    if _G.autoStartFinder then
        startFinder(status)
    end
end)
