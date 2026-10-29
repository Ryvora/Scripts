local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local me = Players.LocalPlayer

local VALID_GAMES = {
    [4448566543] = true,
    [112555153856962] = true,
    [100849827235562] = true,
    [5787810194] = true,
}
if not VALID_GAMES[game.PlaceId] then
    WindUI:Notify({Title="Ryvora", Content="This script is only for Banana Eats!", Duration=6})
    return
end

local _RyEnv = {WindUI = WindUI}
_RyEnv.Window = _RyEnv.WindUI:CreateWindow({
    Title = "Ryvora | Banana Eats",
    Icon = "banana",
    Folder = "ryvora_banana_eats",
    Size = UDim2.fromOffset(600, 460),
    Transparent = true, 
    Theme = "Dark",
    User = {Enabled = true, Anonymous = true}
})

local window = _RyEnv.Window

local espDist = 500
local cakeAuraRange = 24
local cakeGrabDist = 10000
local solvingCombo, solvingValve, solvingPic = false, false, false

local tpFlagActive = false
local tpFlagTime = 0
local noclipOn, infJumpOn = false, false
local fullbrightOn, noFogOn, noEffectsOn = false, false, false
local antiPeelsOn = false

local function markTeleport()
    tpFlagActive = true
    tpFlagTime = tick()
    task.delay(.4, function() tpFlagActive = false end)
end

local function getHRP()
    local char = me.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getDistance(pos)
    local root = getHRP()
    if not root then return math.huge end
    return (root.Position - pos).Magnitude
end

local function updateLabel(lbl, txt) 
    if lbl.Text ~= txt then lbl.Text = txt end 
end

local function isOnBananas()
    return me.Team and me.Team.Name:lower():find("banana") ~= nil
end

local function isOnRunners()
    return me.Team and me.Team.Name:lower():find("runner") ~= nil
end

local espFolder = Instance.new("Folder")
espFolder.Name = "RyvoraESP"
espFolder.Parent = WS

local function createHighlight(obj, color, trans)
    local hl = Instance.new("Highlight")
    hl.Adornee = obj
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = trans or .5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = espFolder
    return hl
end

local function createTextLabel(obj, color, offset)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(170, 22)
    bb.StudsOffset = offset or Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = obj
    bb.Parent = espFolder
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromScale(1, 1)
    t.BackgroundTransparency = 1
    t.TextColor3 = color or Color3.new(1,1,1)
    t.TextStrokeTransparency = .2
    t.TextStrokeColor3 = Color3.new(0,0,0)
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.Parent = bb
    return bb, t
end

local function killEsp(x)
    if not x then return end
    if typeof(x) == "Instance" then 
        pcall(function() x:Destroy() end)
        return 
    end
    if x.hl then pcall(function() x.hl:Destroy() end) end
    if x.sb then pcall(function() x.sb:Destroy() end) end
    if x.bb then pcall(function() x.bb:Destroy() end) end
    if x.label then
        pcall(function() 
            if x.label.Parent then 
                x.label.Parent:Destroy() 
            else 
                x.label:Destroy() 
            end 
        end)
    end
end

local function clearEspCache(t)
    for k,v in pairs(t) do 
        killEsp(v)
        t[k] = nil 
    end
end

local espStates = {Banana=false, Runner=false, Cake=false, Puzzle=false, Valve=false, Crawlway=false, Peel=false, Locker=false, Token=false, Picture=false, Combination=false}
local espCache = {Banana={}, Runner={}, Cake={}, Puzzle={}, Valve={}, Crawlway={}, Peel={}, Locker={}, Token={}, Picture={}, Combination={}}

local function getCakesInMap()
    local out = {}
    local gk = WS:FindFirstChild("GameKeeper")
    local map = gk and gk:FindFirstChild("Map")
    local items = map and map:FindFirstChild("Items")
    if not items then return out end
    for _,v in ipairs(items:GetChildren()) do
        if v.Name:lower():find("cake") then
            local m = v:FindFirstChild("Model")
            local cp = m and m:FindFirstChild("CakePlate")
            local root = cp and cp:FindFirstChild("Root")
            if root and root:IsA("BasePart") then
                table.insert(out, {root=root, holder=cp})
            end
        end
    end
    return out
end

local tokenListCache, lastTokenCheck = {}, 0
local function getTokenList()
    if not espStates.Token then return tokenListCache end
    local now = tick()
    if now - lastTokenCheck > 1.5 then
        lastTokenCheck = now
        local list = {}
        local gk = WS:FindFirstChild("GameKeeper")
        local map = gk and gk:FindFirstChild("Map")
        if map then
            for _,v in ipairs(map:GetDescendants()) do
                if v:IsA("BasePart") and v.Name == "Token" then 
                    list[#list+1] = v 
                end
            end
        end
        tokenListCache = list
    end
    return tokenListCache
end

local function tweenTeleport(targetPos, dur)
    dur = dur or .15
    local root = getHRP()
    if not root then return end
    local startCF = root.CFrame
    local targetCF = CFrame.new(targetPos + Vector3.new(0,3,0)) * (startCF - startCF.Position)
    local t0 = tick()
    while true do
        local progress = (tick()-t0)/dur
        if progress >= 1 then 
            root.CFrame = targetCF
            break 
        end
        if not root.Parent then return end
        root.CFrame = startCF:Lerp(targetCF, progress)
        RunService.Heartbeat:Wait()
    end
end

local function checkIfInLocker(pos)
    local gk = WS:FindFirstChild("GameKeeper")
    local actors = gk and gk:FindFirstChild("Actors")
    local spots = actors and actors:FindFirstChild("Spots")
    if not spots then return false end
    for _,locker in ipairs(spots:GetChildren()) do
        if locker.Name:lower():find("locker") then
            local root = locker:FindFirstChild("Root") or locker.PrimaryPart or locker:FindFirstChildWhichIsA("BasePart")
            if root then
                local p = root.Position
                if math.abs(pos.X-p.X) < 6 and math.abs(pos.Z-p.Z) < 6 and math.abs(pos.Y-p.Y) < 8 then 
                    return true 
                end
            end
        end
    end
    return false
end

local function checkPathBlocked(startPos, endPos, char)
    local remaining = endPos - startPos
    local current = startPos
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {char}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local hitTouchable = false
    for i=1,10 do
        if remaining.Magnitude < .5 then return true, hitTouchable end
        local hit = WS:Raycast(current, remaining, rp)
        if not hit then return true, hitTouchable end
        local inst = hit.Instance
        if inst.CanCollide and not inst.CanTouch then return false, false end
        if inst.CanTouch and not inst.CanCollide then
            hitTouchable = true
            current = hit.Position + remaining.Unit*.5
            remaining = endPos - current
        elseif inst.CanCollide and inst.CanTouch then
            return false, false
        else
            current = hit.Position + remaining.Unit*.5
            remaining = endPos - current
        end
    end
    return true, hitTouchable
end

local aiBananaList, lastBananaCheck = {}, 0
local function getAiBananas()
    if not espStates.Banana then return aiBananaList end
    local now = tick()
    if now - lastBananaCheck > 2 then
        lastBananaCheck = now
        local list = {}
        for _,obj in ipairs(WS:GetDescendants()) do
            if obj.Name:lower():find("ai_banana") then
                local r
                if obj:IsA("Model") then
                    r = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Root") or obj:FindFirstChild("Head") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                elseif obj:IsA("BasePart") then 
                    r = obj 
                end
                if r and r.Parent then 
                    list[#list+1] = {model=obj, root=r} 
                end
            end
        end
        aiBananaList = list
    end
    return aiBananaList
end

local function isValveObj(name)
    local n = name:lower()
    return n == "value" or n == "valve" or n:find("valuebutton") ~= nil or n:find("valvebutton") ~= nil
end

local function checkSlimeNearby(pos, range)
    if not pos then return false end
    range = range or 40
    local gk = WS:FindFirstChild("GameKeeper")
    if not gk then return false end
    for _,obj in ipairs(gk:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("slime") then
            if (obj.Position-pos).Magnitude <= range then return true end
        elseif obj:IsA("Model") and obj.Name:lower():find("slime") then
            local r = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if r and (r.Position-pos).Magnitude <= range then return true end
        end
    end
    return false
end

local function waitSlimeClear(pos, label)
    if not checkSlimeNearby(pos) then return true end
    _RyEnv.WindUI:Notify({Title="Please Wait", Content=(label or "Puzzle").." is blocked by slime", Duration=3})
    local t0 = tick()
    while checkSlimeNearby(pos) and tick()-t0 < 60 do 
        task.wait(.3) 
    end
    if checkSlimeNearby(pos) then
        _RyEnv.WindUI:Notify({Title="Please Wait", Content=(label or "Puzzle").." - slime still present, skipping", Duration=3})
        return false
    end
    _RyEnv.WindUI:Notify({Title=label or "Puzzle", Content="Slime cleared - solving!", Duration=2})
    return true
end

function getComboSolution(puzzle)
    local key = puzzle:FindFirstChild("CombinationKey")
    if not key then return nil end
    local btns = key:FindFirstChild("Buttons")
    if not btns then return nil end
    local function getVal(button)
        local btn = btns:FindFirstChild("Button"..button)
        if not btn then return nil end
        local bl = btn:FindFirstChild("ButtonLabel")
        local l = bl and bl:FindFirstChild("Label")
        return l and l.Text
    end
    local a, b, c = getVal(1), getVal(2), getVal(3)
    if not a or not b or not c then return nil end
    return a..b..c, {tonumber(a), tonumber(b), tonumber(c)}
end

local function isComboSolved(puzzle)
    local _, vals = getComboSolution(puzzle)
    if not vals then return false end
    local btns = puzzle:FindFirstChild("Buttons")
    if not btns then return false end
    for i=1,#vals do
        local btn = btns:FindFirstChild("Button"..i)
        if not btn then return false end
        local bl = btn:FindFirstChild("ButtonLabel")
        local l = bl and bl:FindFirstChild("Label")
        if not l or l.Text ~= tostring(vals[i]) then return false end
    end
    return true
end

local function isPicSolved(root)
    if not root then return false end
    local camoBrick = BrickColor.new("Camo")
    local hasAny = false
    for _,r in ipairs(root:GetChildren()) do
        if r:IsA("BasePart") then
            hasAny = true
            if r.BrickColor ~= camoBrick then return false end
        end
    end
    return hasAny
end

local PlayerTab = window:Tab({Title="Player", Icon="user"})
local VisualTab = window:Tab({Title="Visual", Icon="eye"})
local AntiTab = window:Tab({Title="Anti", Icon="shield"})
local BananaTab = window:Tab({Title="Banana", Icon="banana"})
local RunnerTab = window:Tab({Title="Runners", Icon="users"})
local OPTab = window:Tab({Title="OP", Icon="zap"})
local CreditTab = window:Tab({Title="Credits", Icon="heart"})

local currentWS, currentJP = 16, 50
local wsActive, jpActive = false, false

PlayerTab:Slider({Title="Walkspeed", Step=1, Value={Min=16, Max=300, Default=16}, Callback=function(v)
    currentWS = v
    wsActive = v ~= 16
    local c = me.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = v end
end})

PlayerTab:Slider({Title="Jumppower", Step=1, Value={Min=50, Max=500, Default=50}, Callback=function(v)
    currentJP = v
    jpActive = v ~= 50
    local c = me.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h.UseJumpPower = true; h.JumpPower = v end
end})

PlayerTab:Toggle({Title="Noclip", Default=false, Callback=function(v) noclipOn = v end})
PlayerTab:Toggle({Title="Inf Jump", Default=false, Callback=function(v) infJumpOn = v end})

local function addEspToggle(tab, name, key)
    tab:Toggle({Title=name, Default=false, Callback=function(v)
        espStates[key] = v
        if not v then clearEspCache(espCache[key]) end
    end})
end

addEspToggle(VisualTab, "Banana Esp", "Banana")
addEspToggle(VisualTab, "Runners Esp", "Runner")
addEspToggle(VisualTab, "Cake Esp", "Cake")
addEspToggle(VisualTab, "Puzzle Esp", "Puzzle")
addEspToggle(VisualTab, "Picture Puzzle Esp", "Picture")
addEspToggle(VisualTab, "Valve Esp", "Valve")
addEspToggle(VisualTab, "Crawlway Esp", "Crawlway")
addEspToggle(VisualTab, "Peel Esp", "Peel")
addEspToggle(VisualTab, "Locker Esp", "Locker")
addEspToggle(VisualTab, "Coin Esp", "Token")
addEspToggle(VisualTab, "Combination Puzzle Esp", "Combination")

VisualTab:Toggle({Title="Fullbright", Default=false, Callback=function(v) fullbrightOn = v end})
VisualTab:Toggle({Title="No Fog", Default=false, Callback=function(v) noFogOn = v end})
VisualTab:Toggle({Title="No Effects", Default=false, Callback=function(v) noEffectsOn = v end})

AntiTab:Toggle({Title="Anti Peels", Default=false, Callback=function(v)
    antiPeelsOn = v
    if not v then return end
    task.spawn(function()
        local function disableTouch(part)
            if part:IsA("BasePart") then part.CanTouch = false end
        end
        local function hookPeels(peels)
            if not peels then return end
            for _,p in ipairs(peels:GetDescendants()) do disableTouch(p) end
            peels.DescendantAdded:Connect(function(d)
                if antiPeelsOn then task.wait(.05); disableTouch(d) end
            end)
        end
        local hooked = {}
        while antiPeelsOn do
            local gk = WS:FindFirstChild("GameKeeper")
            local map = gk and gk:FindFirstChild("Map")
            local peels = map and map:FindFirstChild("Peels")
            if peels and not hooked[peels] then hooked[peels] = true; hookPeels(peels) end
            if peels then
                for _,p in ipairs(peels:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanTouch then p.CanTouch = false end
                end
            end
            task.wait(.2)
        end
        for k in pairs(hooked) do hooked[k] = nil end
    end)
end})

local autoKillOn = false
BananaTab:Toggle({Title="Auto Kill", Default=false, Callback=function(v)
    autoKillOn = v
    if not v then return end
    task.spawn(function()
        while autoKillOn do
            if isOnBananas() then
                for _=1,3 do
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p ~= me and p.Character then
                            local tR = p.Character:FindFirstChild("HumanoidRootPart")
                            local mR = getHRP()
                            if tR and mR then markTeleport(); mR.CFrame = tR.CFrame; task.wait() end
                        end
                    end
                end
            end
            task.wait(.5)
        end
    end)
end})

local noCooldownPeelsOn = false
BananaTab:Toggle({Title="No Cooldown Peels", Default=false, Callback=function(v)
    noCooldownPeelsOn = v
    if not v then return end
    task.spawn(function()
        local Library = game:GetService("ReplicatedStorage"):FindFirstChild("Library")
        local ShopItemsModule = Library and require(Library:FindFirstChild("ShopItems"))
        if not ShopItemsModule then
            _RyEnv.WindUI:Notify({Title="No Cooldown Peels", Content="Couldn't find ShopItems module", Duration=4})
            noCooldownPeelsOn = false
            return
        end
        while noCooldownPeelsOn do
            if isOnBananas() then
                pcall(function() if ShopItemsModule.peel1 then ShopItemsModule.peel1.PeelDelay = 0 end end)
                local char = me.Character
                local limit = char and char:FindFirstChild("BananaPeelLimit")
                local delay = limit and limit:FindFirstChild("Delay")
                if delay then pcall(function() delay.Value = true end) end
            end
            task.wait(.02)
        end
    end)
end})

local autoPeelCrawlOn = false
BananaTab:Toggle({Title="Auto Peel Crawlway (Legit)", Default=false, Callback=function(v)
    autoPeelCrawlOn = v
    if not v then return end
    task.spawn(function()
        local rs = game:GetService("ReplicatedStorage")
        local events = rs:WaitForChild("Events", 5)
        local dropPeel = events and events:FindFirstChild("DropPeel")
        if not dropPeel then
            _RyEnv.WindUI:Notify({Title="Auto Peel Crawlway", Content="DropPeel remote not found", Duration=4})
            autoPeelCrawlOn = false
            return
        end
        while autoPeelCrawlOn do
            if isOnBananas() then
                local root = getHRP()
                if root then
                    local gk = WS:FindFirstChild("GameKeeper")
                    local map = gk and gk:FindFirstChild("Map")
                    local vents = map and map:FindFirstChild("Vents")
                    if vents then
                        for _,cw in ipairs(vents:GetChildren()) do
                            if cw.Name:lower():find("crawlway") then
                                local lock = cw:FindFirstChild("Lock")
                                if lock and lock:IsA("BasePart") then
                                    local d = (lock.Position-root.Position).Magnitude
                                    if d >= 2 and d <= 3 then
                                        pcall(function() dropPeel:InvokeServer() end)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(.15)
        end
    end)
end})

BananaTab:Toggle({Title="Delete Lockers", Default=false, Callback=function(v)
    if not v then return end
    local gk = WS:FindFirstChild("GameKeeper")
    local actors = gk and gk:FindFirstChild("Actors")
    local spots = actors and actors:FindFirstChild("Spots")
    if spots then
        for _,v2 in ipairs(spots:GetChildren()) do
            if v2.Name:lower():find("locker") then v2:Destroy() end
        end
    end
    _RyEnv.WindUI:Notify({Title="Delete Lockers", Content="Lockers deleted (client)", Duration=3})
end})

local cakeRunOn = false

local function solveCakeLoop()
    local notifiedNoTeam, didWork = false, false
    while cakeRunOn do
        if not isOnRunners() then
            if isOnBananas() and not notifiedNoTeam then
                _RyEnv.WindUI:Notify({Title="Auto Solve Cake", Content="You are not on the Runners Team!", Duration=3})
                notifiedNoTeam = true
            end
            task.wait(.5)
            continue
        end
        notifiedNoTeam = false
        local root = getHRP()
        if not root then task.wait(.25); continue end
        local all = getCakesInMap()
        if #all == 0 then
            if didWork then _RyEnv.WindUI:Notify({Title="Auto Solve Cake", Content="Solved!", Duration=3}) end
            cakeRunOn = false
            break
        end
        for _,cake in ipairs(all) do
            if not cakeRunOn or not isOnRunners() then break end
            if not (cake.root and cake.root.Parent) then continue end
            if not (cake.holder and cake.holder.Parent) then continue end
            if (cake.root.Position-root.Position).Magnitude <= cakeGrabDist then
                for _,d in ipairs(cake.holder:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then
                        pcall(function() fireproximityprompt(d, 1) end)
                    elseif d:IsA("ClickDetector") then
                        pcall(function() fireclickdetector(d, 1) end)
                    end
                end
            end
        end
        local gk = WS:FindFirstChild("GameKeeper")
        local pz = gk and gk:FindFirstChild("Puzzles")
        local cp = pz and pz:FindFirstChild("CakePuzzle")
        local pr = cp and cp:FindFirstChild("Root")
        if cp and pr and pr.Parent then
            didWork = true
            local puzzleCF = CFrame.new(pr.Position + Vector3.new(0,3,0))
            local closest = math.huge
            for _,p in ipairs(Players:GetPlayers()) do
                if p ~= me and p.Team and p.Team.Name:lower():find("banana") then
                    local c = p.Character
                    local r = c and c:FindFirstChild("HumanoidRootPart")
                    if r then
                        local d = (r.Position-pr.Position).Magnitude
                        if d < closest then closest = d end
                    end
                end
            end
            for _,e in ipairs(getAiBananas()) do
                if e.root and e.root.Parent then
                    local d = (e.root.Position-pr.Position).Magnitude
                    if d < closest then closest = d end
                end
            end
            if closest < 25 then
                markTeleport()
                local rx, rz = math.random(-150,150), math.random(-150,150)
                pcall(function() tweenTeleport(pr.Position + Vector3.new(rx,3,rz), .2) end)
                local w0 = tick()
                while cakeRunOn and tick()-w0 < 30 do
                    local stillClose = false
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p ~= me and p.Team and p.Team.Name:lower():find("banana") then
                            local c = p.Character
                            local r = c and c:FindFirstChild("HumanoidRootPart")
                            if r and (r.Position-pr.Position).Magnitude < 40 then stillClose = true; break end
                        end
                    end
                    if not stillClose then
                        for _,e in ipairs(getAiBananas()) do
                            if e.root and e.root.Parent and (e.root.Position-pr.Position).Magnitude < 40 then stillClose = true; break end
                        end
                    end
                    if not stillClose then break end
                    task.wait(.3)
                end
                if not cakeRunOn then break end
                markTeleport()
                local r2 = getHRP()
                if r2 then r2.CFrame = puzzleCF; r2.AssemblyLinearVelocity = Vector3.zero end
                task.wait(.15)
            end
            markTeleport()
            root.CFrame = puzzleCF
            root.AssemblyLinearVelocity = Vector3.zero
            task.wait(.08)
            for _=1,3 do
                for _,d in ipairs(cp:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then
                        pcall(function() fireproximityprompt(d, 1) end)
                    elseif d:IsA("ClickDetector") then
                        pcall(function() fireclickdetector(d, 1) end)
                    end
                end
                task.wait(.12)
            end
        end
        task.wait(.3)
    end
end

RunnerTab:Toggle({Title="Auto Solve Cake", Default=false, Callback=function(v)
    cakeRunOn = v
    if not v then return end
    local gkC = WS:FindFirstChild("GameKeeper")
    local pzC = gkC and gkC:FindFirstChild("Puzzles")
    local cpC = pzC and pzC:FindFirstChild("CakePuzzle")
    if cpC then
        local n = 0
        for _,c in ipairs(cpC:GetChildren()) do
            if c.Name:lower():find("cake") then n = n + 1 end
        end
        if n >= 10 then
            _RyEnv.WindUI:Notify({Title="Auto Solve Cake", Content="Already Solved!", Duration=3})
            cakeRunOn = false
            return
        end
    end
    task.spawn(solveCakeLoop)
end})

local cakeAuraOn = false
local cakeAuraVis = {}
local function clearCakeAura()
    for _,v in pairs(cakeAuraVis) do pcall(function() v:Destroy() end) end
    cakeAuraVis = {}
end

RunnerTab:Toggle({Title="Cake Grab Aura", Default=false, Callback=function(v)
    cakeAuraOn = v
    if not v then clearCakeAura(); return end
    task.spawn(function()
        local notifiedTeam = false
        while cakeAuraOn do
            if not isOnRunners() then
                if isOnBananas() and not notifiedTeam then
                    _RyEnv.WindUI:Notify({Title="Cake Grab Aura", Content="You are not on the Runners Team!", Duration=3})
                    notifiedTeam = true
                end
                task.wait(.5)
                continue
            end
            notifiedTeam = false
            local root = getHRP()
            local currentCakes = getCakesInMap()
            local seen = {}
            if root then
                for _,cake in ipairs(currentCakes) do
                    if cake.root and cake.root.Parent then
                        seen[cake.root] = true
                        local vis = cakeAuraVis[cake.root]
                        if not vis or not vis.Parent then
                            vis = Instance.new("Part")
                            vis.Shape = Enum.PartType.Ball
                            vis.Size = Vector3.new(cakeAuraRange*2, cakeAuraRange*2, cakeAuraRange*2)
                            vis.Material = Enum.Material.ForceField
                            vis.Color = Color3.fromRGB(255,100,255)
                            vis.Transparency = .85
                            vis.Anchored = true
                            vis.CanCollide, vis.CanQuery, vis.CanTouch, vis.CastShadow = false, false, false, false
                            vis.Name = "RyvoraCakeAura"
                            vis.Parent = espFolder
                            vis.CFrame = cake.root.CFrame
                            cakeAuraVis[cake.root] = vis
                        else
                            vis.CFrame = cake.root.CFrame
                        end
                        if (cake.root.Position-root.Position).Magnitude <= cakeAuraRange then
                            for _,pr in ipairs(cake.holder:GetDescendants()) do
                                if pr:IsA("ProximityPrompt") then
                                    pcall(function() fireproximityprompt(pr, 1) end)
                                elseif pr:IsA("ClickDetector") then
                                    pcall(function() fireclickdetector(pr, 1) end)
                                end
                            end
                        end
                    end
                end
            end
            for rootPart,vis in pairs(cakeAuraVis) do
                if not seen[rootPart] or not rootPart.Parent then
                    pcall(function() vis:Destroy() end)
                    cakeAuraVis[rootPart] = nil
                end
            end
            task.wait(.15)
        end
        clearCakeAura()
    end)
end})

local autoTakeCakeOn = false
RunnerTab:Toggle({Title="Auto Take Cake (Legit)", Default=false, Callback=function(v)
    autoTakeCakeOn = v
    if not v then return end
    task.spawn(function()
        while autoTakeCakeOn do
            if isOnRunners() then
                local root = getHRP()
                if root then
                    for _,cake in ipairs(getCakesInMap()) do
                        local d = (cake.root.Position-root.Position).Magnitude
                        if d >= 5 and d <= 7 then
                            local fired = false
                            for _,v2 in ipairs(cake.holder:GetDescendants()) do
                                if v2:IsA("ProximityPrompt") then
                                    pcall(function() fireproximityprompt(v2) end)
                                    fired = true
                                end
                            end
                            if not fired then
                                for _,v2 in ipairs(cake.holder:GetDescendants()) do
                                    if v2:IsA("ClickDetector") then 
                                        pcall(function() fireclickdetector(v2) end) 
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(.1)
        end
    end)
end})

local autoValveLegitOn = false
RunnerTab:Toggle({Title="Auto Solve Valve (Legit)", Default=false, Callback=function(v)
    autoValveLegitOn = v
    if not v then return end
    task.spawn(function()
        while autoValveLegitOn do
            if isOnRunners() then
                local root = getHRP()
                if root then
                    local gk = WS:FindFirstChild("GameKeeper")
                    local pz = gk and gk:FindFirstChild("Puzzles")
                    if pz then
                        for _,obj in ipairs(pz:GetDescendants()) do
                            if not autoValveLegitOn then break end
                            if isValveObj(obj.Name) then
                                local anchor
                                if obj:IsA("BasePart") then 
                                    anchor = obj
                                elseif obj:IsA("Model") then
                                    anchor = obj:FindFirstChild("Root") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                                end
                                if anchor then
                                    local d = (anchor.Position-root.Position).Magnitude
                                    if d <= 4 then
                                        local prompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                                        if prompt then pcall(function() fireproximityprompt(prompt) end) end
                                        for _,cd in ipairs(obj:GetDescendants()) do
                                            if cd:IsA("ClickDetector") then 
                                                pcall(function() fireclickdetector(cd) end) 
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(.06)
        end
    end)
end})

RunnerTab:Button({Title="Get Combination Code", Callback=function()
    if not isOnRunners() then
        _RyEnv.WindUI:Notify({Title="Get Combination Code", Content="You are not on the Runners Team!", Duration=4})
        return
    end
    local puzzle = WS.GameKeeper.Puzzles:FindFirstChild("CombinationPuzzle")
    if not puzzle then return end
    local code = getComboSolution(puzzle)
    if code then _RyEnv.WindUI:Notify({Title="Get Combination Code", Content="Code: "..code, Duration=20}) end
end})

local function solveValveFunc()
    if solvingValve then return end
    if not isOnRunners() then return end
    solvingValve = true
    for _,v in pairs(game.Workspace.GameKeeper.Puzzles:GetChildren()) do
        if v.Name == "ValvePuzzle" then
            local valves = {}
            for _,child in ipairs(v:GetDescendants()) do
                if child:IsA("ProximityPrompt") then
                    local host = child.Parent
                    if host and host:IsA("BasePart") then valves[#valves+1] = {part=host, prompt=child} end
                end
            end
            if #valves == 0 then
                local btn = v:FindFirstChild("ValveButton", true)
                if btn and btn:IsA("BasePart") then
                    local cd = btn:FindFirstChildOfClass("ClickDetector")
                    valves[#valves+1] = {part=btn, click=cd}
                end
            end
            for _,valve in ipairs(valves) do
                if not waitSlimeClear(valve.part.Position, "Solve Valve Puzzle") then
                    solvingValve = false
                    return
                end
                local root = getHRP()
                if not root then break end
                markTeleport()
                root.CFrame = CFrame.new(valve.part.Position + Vector3.new(0,3,0))
                root.AssemblyLinearVelocity = Vector3.zero
                task.wait(.1)
                local t0 = tick()
                while tick()-t0 < 3.5 do
                    markTeleport()
                    root.CFrame = CFrame.new(valve.part.Position + Vector3.new(0,3,0))
                    if valve.prompt then pcall(function() fireproximityprompt(valve.prompt, 0) end) end
                    if valve.click then pcall(function() fireclickdetector(valve.click, 0) end) end
                    RunService.Heartbeat:Wait()
                end
                task.wait(.3)
            end
        end
    end
    _RyEnv.WindUI:Notify({Title="Solve Valve Puzzle", Content="Done!", Duration=3})
    solvingValve = false
end

RunnerTab:Button({Title="Solve Valve Puzzle", Callback=function()
    if solvingValve then
        _RyEnv.WindUI:Notify({Title="Solve Valve Puzzle", Content="Already Solving...", Duration=3})
        return
    end
    if not isOnRunners() then
        _RyEnv.WindUI:Notify({Title="Solve Valve Puzzle", Content="You are not on the Runners Team!", Duration=4})
        return
    end
    task.spawn(solveValveFunc)
end})

function solvePictureFunc(root)
    local lp = game:GetService("Players").LocalPlayer
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local tc = BrickColor.new("Camo")
    local anchor = root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart")
    if not waitSlimeClear(anchor and anchor.Position, "Auto Solve Picture Puzzle") then return end
    local targetCF
    if anchor then targetCF = CFrame.new(anchor.Position) end
    local holding = true
    task.spawn(function()
        while holding do
            local cur = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if cur and targetCF then
                cur.CFrame = targetCF
                cur.AssemblyLinearVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
    for _,rotate in ipairs(root.Buttons:GetChildren()) do
        if rotate:IsA("BasePart") then
            local cd = rotate:FindFirstChildOfClass("ClickDetector")
            if cd then
                local t0 = tick()
                while rotate.BrickColor ~= tc and tick()-t0 < 15 do
                    local prev = rotate.BrickColor
                    pcall(function() fireclickdetector(cd, 1) end)
                    local t1 = tick()
                    while rotate.BrickColor == prev and tick()-t1 < .4 do task.wait() end
                end
            end
        end
    end
    for _,rotate in ipairs(root.Buttons:GetChildren()) do
        if rotate:IsA("BasePart") and rotate.BrickColor ~= tc then
            local cd = rotate:FindFirstChildOfClass("ClickDetector")
            if cd then
                local t0 = tick()
                while rotate.BrickColor ~= tc and tick()-t0 < 8 do
                    local prev = rotate.BrickColor
                    pcall(function() fireclickdetector(cd, 1) end)
                    local t1 = tick()
                    while rotate.BrickColor == prev and tick()-t1 < .4 do task.wait() end
                end
            end
        end
    end
    holding = false
end

RunnerTab:Button({Title="Auto Solve Picture Puzzle", Callback=function()
    if solvingPic then
        _RyEnv.WindUI:Notify({Title="Auto Solve Picture Puzzle", Content="Already Solving...", Duration=3})
        return
    end
    local target = nil
    for _,v in pairs(game:GetService("Workspace").GameKeeper.Puzzles:GetChildren()) do
        if v.Name == "PicturePuzzle" then target = v; break end
    end
    if not target then
        _RyEnv.WindUI:Notify({Title="Auto Solve Picture Puzzle", Content="Picture Puzzle not found", Duration=4})
        return
    end
    if isPicSolved(target) then
        _RyEnv.WindUI:Notify({Title="Auto Solve Picture Puzzle", Content="Already Solved!", Duration=3})
        return
    end
    solvingPic = true
    for _,v in pairs(game:GetService("Workspace").GameKeeper.Puzzles:GetChildren()) do
        if v.Name == "PicturePuzzle" then solvePictureFunc(v) end
    end
    solvingPic = false
    _RyEnv.WindUI:Notify({Title="Auto Solve Picture Puzzle", Content="Done", Duration=4})
end})

local function solveComboFunc()
    if solvingCombo then return end
    if not isOnRunners() then return end
    local puzzle = WS.GameKeeper.Puzzles:FindFirstChild("CombinationPuzzle")
    if not puzzle then return end
    local anchor = puzzle.PrimaryPart or puzzle:FindFirstChildWhichIsA("BasePart")
    if not waitSlimeClear(anchor and anchor.Position, "Solve Combination Puzzle") then return end
    if isComboSolved(puzzle) then return end
    local _, vals = getComboSolution(puzzle)
    if not vals then return end
    solvingCombo = true
    local root = getHRP()
    if not root then solvingCombo = false; return end
    if anchor then
        markTeleport()
        root.CFrame = CFrame.new(anchor.Position + Vector3.new(0,3,0))
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(.25)
    end
    local btns = puzzle:FindFirstChild("Buttons")
    if not btns then solvingCombo = false; return end
    for i=1,#vals do
        local target = tostring(vals[i])
        local btn = btns:FindFirstChild("Button"..i)
        if btn then
            local labelObj = btn:FindFirstChild("ButtonLabel")
            local label = labelObj and labelObj:FindFirstChild("Label")
            local cd = btn:FindFirstChild("ClickDetector")
            if label and cd then
                while label.Text ~= target do
                    local prev = label.Text
                    markTeleport()
                    if anchor then root.CFrame = CFrame.new(anchor.Position + Vector3.new(0,3,0)) end
                    pcall(function() fireclickdetector(cd, 0) end)
                    local t1 = tick()
                    while label.Text == prev and tick()-t1 < 1 do task.wait(.02) end
                    task.wait(.03)
                end
            end
        end
    end
    task.wait(.4)
    solvingCombo = false
end

RunnerTab:Button({Title="Solve Combination Puzzle", Callback=function()
    if solvingCombo then
        _RyEnv.WindUI:Notify({Title="Solve Combination Puzzle", Content="Already Solving...", Duration=3})
        return
    end
    if not isOnRunners() then
        _RyEnv.WindUI:Notify({Title="Solve Combination Puzzle", Content="You are not on the Runners Team!", Duration=4})
        return
    end
    task.spawn(solveComboFunc)
end})

local coinFarmOn = false
OPTab:Toggle({Title="Coin Farm", Default=false, Callback=function(v)
    coinFarmOn = v
    if not v then return end
    task.spawn(function()
        while coinFarmOn do
            local root = getHRP()
            if root then
                local best, bd = nil, math.huge
                for _,v2 in ipairs(WS:GetDescendants()) do
                    if v2:IsA("BasePart") and v2.Name == "Token" then
                        if v2.Transparency < .9 and v2.CanTouch ~= false then
                            local d = (v2.Position-root.Position).Magnitude
                            if d < bd then best = v2; bd = d end
                        end
                    end
                end
                if best then
                    markTeleport()
                    root.CFrame = CFrame.new(best.Position + Vector3.new(0,3,0))
                    task.wait(.05)
                    pcall(function()
                        firetouchinterest(best, root, 0)
                        task.wait()
                        firetouchinterest(best, root, 1)
                    end)
                end
            end
            task.wait(.15)
        end
    end)
end})

local acOn = false
local lastSafePos, lastRespawnTime = nil, 0

OPTab:Toggle({Title="Anti Cheat Bypass", Default=false, Callback=function(v)
    acOn = v
    if not v then lastSafePos = nil; return end
    lastSafePos = nil
    task.spawn(function()
        while acOn do
            RunService.Heartbeat:Wait()
            local root = getHRP()
            if root then
                if not lastSafePos then
                    lastSafePos = root.Position
                else
                    local d = (root.Position-lastSafePos).Magnitude
                    local respawned = tick()-lastRespawnTime < 8
                    local ownTp = tpFlagActive and tick()-tpFlagTime < .8
                    if d > 20 and d <= 80 and not respawned and not ownTp then
                        root.CFrame = CFrame.new(lastSafePos)
                        root.AssemblyLinearVelocity = Vector3.zero
                    else
                        lastSafePos = root.Position
                    end
                end
            end
        end
    end)
end})

local pumpkinFarmOn = false
OPTab:Toggle({Title="Pumpkin Farm", Default=false, Callback=function(v)
    pumpkinFarmOn = v
    if not v then return end
    task.spawn(function()
        local notified = false
        while pumpkinFarmOn do
            if not isOnRunners() then
                if isOnBananas() and not notified then
                    _RyEnv.WindUI:Notify({Title="Pumpkin Farm", Content="You need to be on the Runners Team!", Duration=3})
                    notified = true
                end
                task.wait(.5)
                continue
            end
            notified = false
            local root = getHRP()
            if root then
                local gk = WS:FindFirstChild("GameKeeper")
                local map = gk and gk:FindFirstChild("Map")
                local spawns = map and map:FindFirstChild("PumpkinSpawns")
                if spawns then
                    local targets = {}
                    for _,spawn in ipairs(spawns:GetChildren()) do
                        local pickup = spawn:FindFirstChild("PumpkinPickUp")
                        local pumpkin = pickup and pickup:FindFirstChild("Pumpkin")
                        if pumpkin and pumpkin:IsA("BasePart") and pumpkin.Parent then
                            targets[#targets+1] = pumpkin.Position
                        end
                    end
                    for _,pos in ipairs(targets) do
                        if not pumpkinFarmOn then break end
                        if not isOnRunners() then break end
                        root.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                        root.AssemblyLinearVelocity = Vector3.zero
                        RunService.Heartbeat:Wait()
                    end
                end
            end
            task.wait(.2)
        end
    end)
end})

CreditTab:Paragraph({Title="Main Programming", Desc="Efalo"})
CreditTab:Paragraph({Title="Scripting & Language", Desc="Chiplag"})
CreditTab:Paragraph({Title="This Script Is Currently In Beta So U May Expect Some Bugs", Desc="", Color=Color3.fromRGB(255,40,40)})

me.CharacterAdded:Connect(function(c)
    lastRespawnTime = tick()
    lastSafePos = nil
    task.wait(.5)
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then
        if wsActive then h.WalkSpeed = currentWS end
        if jpActive then h.UseJumpPower = true; h.JumpPower = currentJP end
    end
end)

task.spawn(function()
    while task.wait(.15) do
        local c = me.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            if wsActive and h.WalkSpeed ~= currentWS then h.WalkSpeed = currentWS end
            if jpActive then
                h.UseJumpPower = true
                if h.JumpPower ~= currentJP then h.JumpPower = currentJP end
            end
        end
    end
end)

RunService.Stepped:Connect(function()
    if noclipOn and me.Character then
        for _,v in ipairs(me.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

UIS.JumpRequest:Connect(function()
    if infJumpOn and me.Character then
        local h = me.Character:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

task.spawn(function()
    while task.wait(.5) do
        if fullbrightOn then
            Lighting.Brightness = 2
            Lighting.ClockTime = 12
            Lighting.Ambient = Color3.fromRGB(255,255,255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e6
        end
        if noFogOn then
            Lighting.FogEnd = 1e6
            Lighting.FogStart = 0
            for _,v in ipairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then v:Destroy() end
            end
        end
        if noEffectsOn then
            for _,v in ipairs(Lighting:GetChildren()) do
                if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
                    v:Destroy()
                end
            end
        end
    end
end)

local function drawPlayerEsp(key, teamName, color, showDisplay)
    local seen = {}
    if espStates[key] then
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= me and p.Team and p.Team.Name:lower():find(teamName) then
                local c = p.Character
                local root = c and c:FindFirstChild("HumanoidRootPart")
                if root then
                    local dpos = getDistance(root.Position)
                    if dpos > espDist then continue end
                    seen[p] = true
                    local d = espCache[key][p]
                    if not d or d.char ~= c then
                        if d then killEsp(d) end
                        local _, label = createTextLabel(root, color)
                        d = {hl=createHighlight(c, color), label=label, char=c}
                        espCache[key][p] = d
                    end
                    if showDisplay then
                        updateLabel(d.label, string.format("%s | %s | %d Studs", p.Name, p.DisplayName, math.floor(dpos)))
                    else
                        updateLabel(d.label, string.format("%s | %d Studs", p.Name, math.floor(dpos)))
                    end
                end
            end
        end
    end
    for p,d in pairs(espCache[key]) do
        if not seen[p] then killEsp(d); espCache[key][p] = nil end
    end
end

local function drawBananaEsp()
    local seen = {}
    if espStates.Banana then
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= me and p.Team and p.Team.Name:lower():find("banana") then
                local c = p.Character
                local root = c and c:FindFirstChild("HumanoidRootPart")
                if root then
                    local dpos = getDistance(root.Position)
                    if dpos > espDist then continue end
                    seen[p] = true
                    local d = espCache.Banana[p]
                    if not d or d.char ~= c then
                        if d then killEsp(d) end
                        local _, label = createTextLabel(root, Color3.fromRGB(255,255,0))
                        d = {hl=createHighlight(c, Color3.fromRGB(255,255,0)), label=label, char=c}
                        espCache.Banana[p] = d
                    end
                    updateLabel(d.label, string.format("%s | %d Studs", p.Name, math.floor(dpos)))
                end
            end
        end
        for _,e in ipairs(getAiBananas()) do
            if e.root and e.root.Parent then
                local dpos = getDistance(e.root.Position)
                if dpos > espDist then continue end
                seen[e.model] = true
                local d = espCache.Banana[e.model]
                if not d or d.model ~= e.model then
                    if d then killEsp(d) end
                    local _, label = createTextLabel(e.root, Color3.fromRGB(255,255,0))
                    d = {hl=createHighlight(e.model, Color3.fromRGB(255,255,0)), label=label, model=e.model}
                    espCache.Banana[e.model] = d
                end
                updateLabel(d.label, string.format("%s | %d Studs", e.model.Name, math.floor(dpos)))
            end
        end
    end
    for obj,d in pairs(espCache.Banana) do
        if not seen[obj] then killEsp(d); espCache.Banana[obj] = nil end
    end
end

local function drawCakeEsp()
    local seen = {}
    if espStates.Cake then
        for _,cake in ipairs(getCakesInMap()) do
            local dpos = getDistance(cake.root.Position)
            if dpos > espDist then continue end
            seen[cake.root] = true
            local d = espCache.Cake[cake.root]
            if not d or d.holder ~= cake.holder then
                if d then killEsp(d) end
                local _, label = createTextLabel(cake.root, Color3.fromRGB(255,180,255))
                d = {hl=createHighlight(cake.holder, Color3.fromRGB(255,180,255), .3), label=label, holder=cake.holder}
                espCache.Cake[cake.root] = d
            end
            updateLabel(d.label, string.format("Cake | %d Studs", math.floor(dpos)))
        end
    end
    for obj,d in pairs(espCache.Cake) do
        if not seen[obj] or not obj.Parent then killEsp(d); espCache.Cake[obj] = nil end
    end
end

local function drawPuzzleEsp()
    local gk = WS:FindFirstChild("GameKeeper")
    local pz = gk and gk:FindFirstChild("Puzzles")
    local cp = pz and pz:FindFirstChild("CakePuzzle")
    local root = cp and cp:FindFirstChild("Root")
    if not espStates.Puzzle then
        if espCache.Puzzle.obj then
            killEsp(espCache.Puzzle)
            for k in pairs(espCache.Puzzle) do espCache.Puzzle[k] = nil end
        end
        return
    end
    if cp and root then
        if espCache.Puzzle.obj ~= cp then
            if espCache.Puzzle.obj then killEsp(espCache.Puzzle) end
            local _, label = createTextLabel(root, Color3.fromRGB(180,0,255))
            espCache.Puzzle.obj = cp
            espCache.Puzzle.hl = createHighlight(cp, Color3.fromRGB(180,0,255))
            espCache.Puzzle.label = label
        end
        if espCache.Puzzle.label and root:IsA("BasePart") then
            updateLabel(espCache.Puzzle.label, string.format("Puzzle | %d Studs", math.floor(getDistance(root.Position))))
        end
    elseif espCache.Puzzle.obj then
        killEsp(espCache.Puzzle)
        for k in pairs(espCache.Puzzle) do espCache.Puzzle[k] = nil end
    end
end

local function drawPictureEsp()
    local seen = {}
    if espStates.Picture then
        local gk = WS:FindFirstChild("GameKeeper")
        local pz = gk and gk:FindFirstChild("Puzzles")
        if pz then
            for _,obj in ipairs(pz:GetChildren()) do
                if obj.Name == "PicturePuzzle" then
                    local anchor = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if anchor then
                        local dpos = getDistance(anchor.Position)
                        if dpos > espDist then continue end
                        seen[obj] = true
                        local d = espCache.Picture[obj]
                        if not d or d.model ~= obj then
                            if d then killEsp(d) end
                            local _, label = createTextLabel(anchor, Color3.fromRGB(255,130,0))
                            d = {hl=createHighlight(obj, Color3.fromRGB(255,130,0)), label=label, model=obj}
                            espCache.Picture[obj] = d
                        end
                        updateLabel(d.label, string.format("Picture Puzzle | %d Studs", math.floor(dpos)))
                    end
                end
            end
        end
    end
    for obj,d in pairs(espCache.Picture) do
        if not seen[obj] or not obj.Parent then killEsp(d); espCache.Picture[obj] = nil end
    end
end

local function drawValveEsp()
    local seen = {}
    if espStates.Valve then
        local gk = WS:FindFirstChild("GameKeeper")
        local pz = gk and gk:FindFirstChild("Puzzles")
        if pz then
            for _,obj in ipairs(pz:GetDescendants()) do
                if isValveObj(obj.Name) then
                    local anchor
                    if obj:IsA("BasePart") then 
                        anchor = obj
                    elseif obj:IsA("Model") then
                        anchor = obj:FindFirstChild("Root") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    end
                    if anchor then
                        local dpos = getDistance(anchor.Position)
                        if dpos > espDist then continue end
                        seen[obj] = true
                        local d = espCache.Valve[obj]
                        if not d or d.model ~= obj then
                            if d then killEsp(d) end
                            local _, label = createTextLabel(anchor, Color3.fromRGB(0,150,255))
                            d = {hl=createHighlight(obj, Color3.fromRGB(0,150,255)), label=label, model=obj}
                            espCache.Valve[obj] = d
                        end
                        updateLabel(d.label, string.format("Valve | %d Studs", math.floor(dpos)))
                    end
                end
            end
        end
    end
    for obj,d in pairs(espCache.Valve) do
        if not seen[obj] or not obj.Parent then killEsp(d); espCache.Valve[obj] = nil end
    end
end

local function drawCrawlEsp()
    local seen = {}
    if espStates.Crawlway then
        local gk = WS:FindFirstChild("GameKeeper")
        local map = gk and gk:FindFirstChild("Map")
        local vents = map and map:FindFirstChild("Vents")
        if vents then
            for _,obj in ipairs(vents:GetChildren()) do
                if obj.Name:lower():find("crawlway") then
                    seen[obj] = true
                    local d = espCache.Crawlway[obj]
                    if not d or d.model ~= obj then
                        if d then killEsp(d) end
                        espCache.Crawlway[obj] = {hl=createHighlight(obj, Color3.fromRGB(255,100,0)), model=obj}
                    end
                end
            end
        end
    end
    for obj,d in pairs(espCache.Crawlway) do
        if not seen[obj] or not obj.Parent then killEsp(d); espCache.Crawlway[obj] = nil end
    end
end

local function drawModelEsp(key, color, finder)
    local seen = {}
    if espStates[key] then
        for _,obj in ipairs(finder()) do
            seen[obj] = true
            if not espCache[key][obj] then
                espCache[key][obj] = {hl=createHighlight(obj, color, .4), model=obj}
            end
        end
    end
    for obj,d in pairs(espCache[key]) do
        if not seen[obj] or not obj.Parent then killEsp(d); espCache[key][obj] = nil end
    end
end

local function findPeelsList()
    local t = {}
    local gk = WS:FindFirstChild("GameKeeper")
    local map = gk and gk:FindFirstChild("Map")
    local peels = map and map:FindFirstChild("Peels")
    if peels then
        for _,v in ipairs(peels:GetChildren()) do
            if v.Name:lower():find("peel") then t[#t+1] = v end
        end
    end
    return t
end

local function findLockersList()
    local t = {}
    local gk = WS:FindFirstChild("GameKeeper")
    local actors = gk and gk:FindFirstChild("Actors")
    local spots = actors and actors:FindFirstChild("Spots")
    if spots then
        for _,v in ipairs(spots:GetChildren()) do
            if v.Name:lower():find("locker") then t[#t+1] = v end
        end
    end
    return t
end

local function drawTokenEsp()
    local seen = {}
    if espStates.Token then
        for _,v in ipairs(getTokenList()) do
            if v and v.Parent then
                if v.Transparency < .9 and v.CanTouch ~= false then
                    local dpos = getDistance(v.Position)
                    if dpos > espDist then continue end
                    seen[v] = true
                    local d = espCache.Token[v]
                    if not d then
                        local _, label = createTextLabel(v, Color3.fromRGB(255,215,0))
                        d = {hl=createHighlight(v, Color3.fromRGB(255,215,0), .3), label=label}
                        espCache.Token[v] = d
                    end
                    updateLabel(d.label, string.format("Token | %d Studs", math.floor(dpos)))
                end
            end
        end
    end
    for obj,d in pairs(espCache.Token) do
        if not seen[obj] or not obj.Parent then killEsp(d); espCache.Token[obj] = nil end
    end
end

local function drawComboEsp()
    local seen = {}
    if espStates.Combination then
        local gk = WS:FindFirstChild("GameKeeper")
        local pz = gk and gk:FindFirstChild("Puzzles")
        local cp = pz and pz:FindFirstChild("CombinationPuzzle")
        if cp then
            local anchor = cp.PrimaryPart or cp:FindFirstChildWhichIsA("BasePart")
            if anchor then
                seen[cp] = true
                local d = espCache.Combination[cp]
                if not d or d.model ~= cp then
                    if d then killEsp(d) end
                    local _, label = createTextLabel(anchor, Color3.fromRGB(255,220,0))
                    d = {hl=createHighlight(cp, Color3.fromRGB(255,220,0)), label=label, model=cp}
                    espCache.Combination[cp] = d
                end
                updateLabel(d.label, string.format("Combination Puzzle | %d Studs", math.floor(getDistance(anchor.Position))))
            end
        end
    end
    for obj,d in pairs(espCache.Combination) do
        if not seen[obj] or not obj.Parent then
            killEsp(d)
            espCache.Combination[obj] = nil
        end
    end
end

local espJobs = {
    {key="Banana", fn=drawBananaEsp},
    {key="Runner", fn=function() drawPlayerEsp("Runner", "runner", Color3.fromRGB(255,80,80), true) end},
    {key="Cake", fn=drawCakeEsp},
    {key="Puzzle", fn=drawPuzzleEsp},
    {key="Picture", fn=drawPictureEsp},
    {key="Valve", fn=drawValveEsp},
    {key="Crawlway", fn=drawCrawlEsp},
    {key="Peel", fn=function() drawModelEsp("Peel", Color3.fromRGB(120,255,120), findPeelsList) end},
    {key="Locker", fn=function() drawModelEsp("Locker", Color3.fromRGB(255,200,0), findLockersList) end},
    {key="Token", fn=drawTokenEsp},
    {key="Combination", fn=drawComboEsp}
}

task.spawn(function()
    local idx = 1
    while task.wait(.14) do
        local job = espJobs[idx]
        if job and espStates[job.key] then pcall(job.fn) end
        idx = idx + 1
        if idx > #espJobs then idx = 1 end
    end
end)

_RyEnv.WindUI:Notify({Title="Ryvora | Banana Eats", Content="Script Loaded Successfully!", Duration=4})
