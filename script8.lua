if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait() until game:GetService("Players").LocalPlayer
	and game:GetService("Players").LocalPlayer.Character
task.wait(3)

--==============================================================
--  PvB Main UI  (merged, tabbed)
--  Tabs: Cards | Keep | Plant | Misc
--==============================================================

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local CoreGui     = game:GetService("CoreGui")
local RS          = game:GetService("ReplicatedStorage")
local VIM         = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local unpackFn    = table.unpack or unpack

----------------------------------------------------------------------
--  SHELL
----------------------------------------------------------------------
local GUI_NAME = "PvBMainUI"
-- destroy any previous toolkit gui WHEREVER it lives. The gui is parented
-- to PlayerGui (thread-permission reasons), so a CoreGui-only check missed
-- it and re-executions stacked instances. Sweep every possible holder.
pcall(function()
    local holders = { CoreGui }
    pcall(function() holders[#holders+1] = LocalPlayer:WaitForChild("PlayerGui") end)
    pcall(function() if type(gethui)=="function" then holders[#holders+1] = gethui() end end)
    for _, h in ipairs(holders) do
        for _, g in ipairs(h:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name == GUI_NAME then pcall(function() g:Destroy() end) end
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
-- Parent into PlayerGui first. gethui/CoreGui can be protected, and spawned
-- automation threads may not have permission to read/write UI there.
local ok = pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
if not ok and type(gethui) == "function" then ok = pcall(function() gui.Parent = gethui() end) end
if not ok then ok = pcall(function() gui.Parent = CoreGui end) end

getgenv().PvBSession = (getgenv().PvBSession or 0) + 1
local SESSION = getgenv().PvBSession

-- MAIN ACCOUNT GUARD. Twelve clients run this same script; the main account
-- is the one being played by hand, so every unattended grind auto-arms OFF
-- there. Alts are unaffected. Nothing is disabled permanently: each toggle
-- still works if pressed by hand, this only stops the SAVED state from
-- re-arming a grind on the account you are sitting at.
local MAIN_ACCOUNT = "beanbean123"
getgenv().PvBIsMain = (tostring(LocalPlayer.Name):lower() == MAIN_ACCOUNT)

-- shared ItemSell gate: the server debounces ALL ItemSell variants together,
-- so every sell (junk brainrots, plants) goes through one spaced path.
getgenv().PvBLastSell = getgenv().PvBLastSell or 0
getgenv().PvBSellBusy = getgenv().PvBSellBusy or false
local ItemSellRem = RS:WaitForChild("Remotes"):WaitForChild("ItemSell")
local function fireSell(...)
    while getgenv().PvBSellBusy do task.wait(0.05) end
    getgenv().PvBSellBusy = true
    local args = table.pack(...)
    local ok,err = pcall(function()
        local gap = 2.2
        local waitTime = gap - (os.clock() - (getgenv().PvBLastSell or 0))
        if waitTime > 0 then task.wait(waitTime) end
        ItemSellRem:FireServer(unpackFn(args, 1, args.n))
        getgenv().PvBLastSell = os.clock()
    end)
    getgenv().PvBSellBusy = false
    if not ok then warn("[PvBFireSell] "..tostring(err)) end
end
getgenv().PvBFireSell = fireSell

local function alive()
    if getgenv().PvBSession~=SESSION then return false end
    local ok,p=pcall(function() return gui.Parent end)
    return (not ok) or (p~=nil)
end
-- transient grinds start OFF each run (wheel + auto-buy keep their own defaults)
getgenv().PvBTornado=false; getgenv().PvBAscended=false; getgenv().PvBBatteryBoost=false; getgenv().PvBInvest=false; getgenv().PvBAutoClick=false; getgenv().PvBStPattys=false; getgenv().PvBStPattysBusy=false

local C = {
    bg=Color3.fromRGB(18,18,22), panel=Color3.fromRGB(28,28,34), row=Color3.fromRGB(40,40,48),
    field=Color3.fromRGB(54,54,62), stroke=Color3.fromRGB(70,70,82),
    green=Color3.fromRGB(46,160,110), blue=Color3.fromRGB(70,120,210), purple=Color3.fromRGB(140,92,205),
    red=Color3.fromRGB(205,78,78), amber=Color3.fromRGB(190,140,45), grey=Color3.fromRGB(78,78,88),
    txt=Color3.fromRGB(232,232,240), dim=Color3.fromRGB(160,160,172),
    gray=Color3.fromRGB(46,46,52),
}
local function corner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 6); return c end
local function mkButton(parent,text,color,size,pos)
    local b=Instance.new("TextButton")
    b.Text=text; b.BackgroundColor3=color; b.TextColor3=Color3.new(1,1,1); b.BorderSizePixel=0
    b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.AutoButtonColor=true
    b.Size=size; b.Position=pos; b.Parent=parent; corner(b,6); return b
end
local function mkLabel(parent,text,size,pos,color,font,tsize)
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Text=text
    l.Size=size; l.Position=pos; l.TextColor3=color or C.txt
    l.Font=font or Enum.Font.Gotham; l.TextSize=tsize or 13
    l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent; return l
end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(420, 480)
frame.Position = UDim2.fromOffset(40, 50)
frame.BackgroundColor3 = C.bg
frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
corner(frame, 12)
do local s=Instance.new("UIStroke",frame); s.Thickness=1; s.Color=C.stroke; s.Transparency=0.4 end

local titleLbl = mkLabel(frame, "P&B Toolkit", UDim2.fromOffset(170,22), UDim2.fromOffset(14,8), C.txt, Enum.Font.GothamBold, 15)
local transBtn = mkButton(frame,"◐",C.grey,UDim2.fromOffset(30,22),UDim2.new(1,-132,0,8)); transBtn.Font=Enum.Font.GothamBold; transBtn.TextSize=14
local minBtn = mkButton(frame,"-",C.grey,UDim2.fromOffset(30,22),UDim2.new(1,-98,0,8)); minBtn.Font=Enum.Font.GothamBold; minBtn.TextSize=16
local closeBtn = mkButton(frame,"X",C.red,UDim2.fromOffset(30,22),UDim2.new(1,-64,0,8)); closeBtn.Font=Enum.Font.GothamBold

local statusLabel = mkLabel(frame, "Ready.", UDim2.new(1,-28,0,16), UDim2.new(0,14,0,40), C.dim, Enum.Font.Gotham, 11)
statusLabel.TextTruncate=Enum.TextTruncate.AtEnd
local function setStatus(t) pcall(function() statusLabel.Text = tostring(t) end) end

----------------------------------------------------------------------
--  HEADER READOUTS (replaces the earlier datasize patch)
--  Paste right after the `local function setStatus(t)` line in script7.
--  Top-left  (next to the title):  live bag count  "384/500"
--  Top-right (next to minimize):   data size       "1.23 / 4 MB"
--  Both sit on the title row, so they stay visible even when minimized.
----------------------------------------------------------------------
local Players2    = game:GetService("Players")
local LP2         = Players2.LocalPlayer

-- bag count, computed exactly like the game's own "384/500" label:
-- #Backpack:GetChildren() vs Util:GetMaxInventorySpace(player) (gamepass-aware cap)
local invLabel = mkLabel(frame, "--/--", UDim2.fromOffset(96,22), UDim2.fromOffset(110,8), C.dim, Enum.Font.GothamMedium, 12)
local UtilMod
pcall(function() UtilMod = require(RS:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("Util")) end)

local function invCap()
    local cap
    pcall(function() cap = UtilMod and UtilMod:GetMaxInventorySpace(LP2) end)
    return tonumber(cap) or 500
end

local function refreshInv()
    pcall(function()
        local n   = #LP2.Backpack:GetChildren()
        local cap = invCap()
        invLabel.Text = ("%d/%d"):format(n, cap)
        invLabel.TextColor3 = (n >= cap and C.red) or (n >= cap*0.85 and Color3.fromRGB(230,160,60)) or C.dim
    end)
end

task.spawn(function()
    local bp
    pcall(function() bp = LP2:WaitForChild("Backpack") end)
    if bp then
        bp.ChildAdded:Connect(refreshInv)
        bp.ChildRemoved:Connect(refreshInv)
    end
    -- new Backpack instance appears on respawn; rebind then
    LP2.CharacterAdded:Connect(function()
        task.wait(0.5)
        pcall(function()
            local nbp = LP2:WaitForChild("Backpack", 5)
            if nbp and nbp ~= bp then
                bp = nbp
                bp.ChildAdded:Connect(refreshInv)
                bp.ChildRemoved:Connect(refreshInv)
            end
        end)
        refreshInv()
    end)
    refreshInv()
    while gui.Parent do task.wait(5) refreshInv() end   -- safety poll (cap can change via gamepass)
end)

-- data size (your JSONEncode measurement), top-right next to minimize
local sizeLabel = mkLabel(frame, "-- / 4 MB", UDim2.fromOffset(110,22), UDim2.new(1,-248,0,8), C.dim, Enum.Font.GothamMedium, 12)
sizeLabel.TextXAlignment = Enum.TextXAlignment.Right

task.spawn(function()
    local HS = game:GetService("HttpService")
    local PDs
    pcall(function() PDs = require(RS:WaitForChild("PlayerData")) end)
    while gui.Parent do
        local mb
        pcall(function()
            local g = PDs:GetData()
            local d = g.Data or g
            mb = #HS:JSONEncode(d) / 1024 / 1024
        end)
        if mb then
            sizeLabel.Text = ("%.2f / 4 MB"):format(mb)
            local pct = mb / 4
            sizeLabel.TextColor3 = (pct >= 0.9 and C.red) or (pct >= 0.75 and Color3.fromRGB(230,160,60)) or C.dim
        else
            sizeLabel.Text = "size: n/a"
            sizeLabel.TextColor3 = C.dim
        end
        task.wait(10)
    end
end)

local tabBar = Instance.new("Frame"); tabBar.BackgroundTransparency=1
tabBar.Size=UDim2.new(1,-20,0,28); tabBar.Position=UDim2.fromOffset(10,62); tabBar.Parent=frame
local tabLayout=Instance.new("UIListLayout",tabBar); tabLayout.FillDirection=Enum.FillDirection.Horizontal
tabLayout.Padding=UDim.new(0,2); tabLayout.SortOrder=Enum.SortOrder.LayoutOrder

local body = Instance.new("Frame"); body.BackgroundTransparency=1
body.Size=UDim2.new(1,-20,1,-102); body.Position=UDim2.fromOffset(10,96); body.Parent=frame

local tabs, tabBtns = {}, {}
local function showTab(name)
    for n,f in pairs(tabs) do f.Visible=(n==name) end
    for n,b in pairs(tabBtns) do b.BackgroundColor3 = (n==name) and C.purple or C.panel end
    if onTabShown then onTabShown(name) end
end
local function addTab(name)
    local btn = mkButton(tabBar, name, C.panel, UDim2.new(0.2,-2,1,0), UDim2.new())
    btn.TextSize = 11
    btn.LayoutOrder = #tabBtns + 1
    local content = Instance.new("Frame"); content.Name=name; content.BackgroundTransparency=1
    content.Size=UDim2.new(1,0,1,0); content.Visible=false; content.Parent=body
    tabs[name]=content; tabBtns[name]=btn
    btn.MouseButton1Click:Connect(function() showTab(name) end)
    return content
end
onTabShown = nil

local cardTab   = addTab("Home")
local keepTab   = addTab("Keep")
local plantTab  = addTab("Plant")
local eventsTab = addTab("Events")
local miscTab   = addTab("Misc")

-- Plant tab scroll wrapper: content outgrew the fixed body height
do
    local outer = plantTab
    outer.ClipsDescendants = true
    local sc = Instance.new("ScrollingFrame")
    sc.Name="PlantScroll"; sc.BackgroundTransparency=1; sc.BorderSizePixel=0
    sc.Size=UDim2.new(1,0,1,0); sc.ScrollBarThickness=6
    sc.ScrollingDirection=Enum.ScrollingDirection.Y
    sc.CanvasSize=UDim2.fromOffset(0,480); sc.AutomaticCanvasSize=Enum.AutomaticSize.Y
    sc.Parent=outer
    -- content lives in an inner frame 12px narrower than the scroll area, so the
    -- 6px scrollbar gets its own lane: button / gap / bar / border (same as Misc).
    local inner=Instance.new("Frame")
    inner.Name="PlantContent"; inner.BackgroundTransparency=1
    inner.Size=UDim2.new(1,-12,0,480); inner.Position=UDim2.new()
    inner.Parent=sc
    local spacer=Instance.new("Frame"); spacer.Name="PlantSpacer"; spacer.BackgroundTransparency=1
    spacer.Size=UDim2.new(1,0,0,18); spacer.Position=UDim2.fromOffset(0,462); spacer.Parent=sc
    plantTab = inner
end

closeBtn.MouseButton1Click:Connect(function()
    getgenv().PvBTornado=false; getgenv().PvBAscended=false; getgenv().PvBBatteryBoost=false; getgenv().PvBInvest=false; getgenv().PvBAutoFish=false; getgenv().PvBAutoClick=false; getgenv().PvBStPattys=false
    gui:Destroy()
end)

pcall(function()
    local CS = RS.Remotes:WaitForChild("ConfirmSell")
    local function hidePrompts()
        local pg = LocalPlayer:FindFirstChild("PlayerGui") if not pg then return end
        for _,d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and type(d.Text)=="string" and d.Text:lower():find("sure you want to sell") then
                local f=d while f and f.Parent and not f.Parent:IsA("ScreenGui") do f=f.Parent end
                if f then pcall(function() f.Visible=false end) end
            end
        end
    end
    CS.OnClientEvent:Connect(function(p1,p2,p3)
        pcall(function() CS:FireServer(p1,p2,p3,true) end)
        for i=1,6 do task.wait(0.1) hidePrompts() end
    end)
end)

local minimized, oldSize = false, frame.Size
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    -- full minimize: nothing but the three window buttons stays on the bar
    tabBar.Visible = not minimized; body.Visible = not minimized; statusLabel.Visible = not minimized
    titleLbl.Visible = not minimized; invLabel.Visible = not minimized; sizeLabel.Visible = not minimized
    if minimized then oldSize=frame.Size; frame.Size=UDim2.fromOffset(146,40)
    else frame.Size=oldSize end
end)

-- transparency ("ghost") toggle: fades every panel/button/stroke, remembers the
-- exact originals per element, and restores them on the second click.
local ghosted=false
local ghostSaved={}
local function ghostApply(d)
    if d:IsA("UIStroke") then
        if ghostSaved[d]==nil then ghostSaved[d]={tr=d.Transparency} end
        d.Transparency=math.min(1,(ghostSaved[d].tr or 0)+0.8)
    elseif d:IsA("Frame") or d:IsA("ScrollingFrame") or d:IsA("TextButton") or d:IsA("TextBox") or d:IsA("ImageButton") then
        if ghostSaved[d]==nil then ghostSaved[d]={bg=d.BackgroundTransparency} end
        d.BackgroundTransparency=math.min(1,(ghostSaved[d].bg or 0)+0.8)
    end
end
local function setGhost(on)
    ghosted=on
    transBtn.BackgroundColor3 = on and C.purple or C.grey
    if on then
        ghostApply(frame)
        for _,d in ipairs(frame:GetDescendants()) do ghostApply(d) end
    else
        for d,s in pairs(ghostSaved) do
            pcall(function()
                if s.bg~=nil then d.BackgroundTransparency=s.bg end
                if s.tr~=nil then d.Transparency=s.tr end
            end)
        end
        ghostSaved={}
    end
end
transBtn.MouseButton1Click:Connect(function() setGhost(not ghosted) end)
-- exposed so the AFK system can fade the window while idle and bring it back
getgenv().PvBSetGhost = function(on) if on ~= ghosted then setGhost(on) end end
getgenv().PvBIsGhost  = function() return ghosted end

-- AUTO-FADE WHILE AFK.
--
-- This used to run its OWN idle timer with its own input listeners, and that
-- is exactly why it never fired. It reset on MouseButton1/MouseButton2, and
-- safe-mode auto-click injects a right-click every few seconds, so the timer
-- was poked awake forever while the Misc idle timer (which ignores mouse
-- buttons) correctly went idle. Two timers, two answers, one of them wrong.
--
-- Now there is exactly one idle decision in the whole script: the Misc AFK
-- watcher publishes getgenv().PvBIdleNow and this just follows it. If the
-- idle actions fire, the fade fires, because it is the same boolean.
do
    local byAuto = false
    task.spawn(function()
        -- the publisher lives further down the file; until it has run once,
        -- PvBIdleNow is nil and we simply stay solid
        while frame and frame.Parent do
            task.wait(0.5)
            local idle = (getgenv().PvBIdleNow == true)
            if idle and not ghosted and not byAuto then
                byAuto = true
                setGhost(true)                 -- fade: AFK
            elseif (not idle) and byAuto then
                byAuto = false
                setGhost(false)                -- solid: you are back
            end
        end
    end)
end

-- Cards controls now live in the Misc tab's "Cards" section. This host frame is
-- created before the cards block so it can build into it; the Misc tab adopts
-- and positions the host when it lays out its sections.
local cardsHost = Instance.new("Frame")
cardsHost.Name = "CardsSection"
cardsHost.BackgroundTransparency = 1

----------------------------------------------------------------------
--  CARDS CONTROLS (hosted in the Misc tab)
----------------------------------------------------------------------
do
    local cardTab = cardsHost   -- everything below builds into the Misc host
    local packOpRunning, suppressorActive = false, false
    local PACK_TYPES = {
        { label="Shiny Expansion", match=function(n) return n:find("shiny") and n:find("expansion") end },
        { label="Expansion",       match=function(n) return n:find("expansion") and not n:find("shiny") end },
        { label="Shiny Base",      match=function(n) return n:find("shiny") and n:find("base") end },
        { label="Base",            match=function(n) return n:find("base") and not n:find("shiny") end },
    }
    local selectedPack = 1
    local openCount = 20

    local function findPack(m) local bp=LocalPlayer:FindFirstChild("Backpack")
        if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and m(t.Name:lower()) then return t end end end
        local ch=LocalPlayer.Character local h=ch and ch:FindFirstChildOfClass("Tool") if h and m(h.Name:lower()) then return h end end

    -- instant open: skip the reveal visuals + HUD hide, but still send the per-card
    -- overhead signal the server expects so it keeps letting you open. cards are
    -- granted server-side by OpenHeldPack regardless.
    local PackObject, packNewOrig, overheadRemote
    pcall(function() overheadRemote = RS:WaitForChild("Remotes"):WaitForChild("Pack"):WaitForChild("ReceiveOverheadCard") end)
    local function findPackObject()
        if PackObject then return PackObject end
        if type(getloadedmodules)~="function" then return nil end
        for _,m in ipairs(getloadedmodules()) do
            if m:IsA("ModuleScript") and m.Name=="PackObject" then
                local ok,mod=pcall(require,m)
                if ok and type(mod)=="table" and mod.new and mod._create then
                    PackObject=mod packNewOrig=packNewOrig or mod.new return mod
                end
            end
        end
        return nil
    end
    local function setInstantOpen(on)
        local po=findPackObject() if not po then return false end
        if on then
            po.new=function(_, cards)
                if overheadRemote and type(cards)=="table" then
                    for _=1,#cards do pcall(function() overheadRemote:FireServer() end) end
                end
                local ev=Instance.new("BindableEvent")
                task.defer(function() pcall(function() ev:Fire() end) end)
                return ev.Event
            end
        elseif packNewOrig then po.new=packNewOrig end
        return true
    end
    local function restoreView()
        local CS
        if type(getloadedmodules)=="function" then
            for _,m in ipairs(getloadedmodules()) do
                if m:IsA("ModuleScript") and m.Name=="CutsceneService" then
                    local ok,mod=pcall(require,m)
                    if ok and type(mod)=="table" and mod.DisableUI then CS=mod break end
                end
            end
        end
        if CS then pcall(CS.DisableUI,false) end
        pcall(function() LocalPlayer:SetAttribute("OpeningPacks",nil) end)
    end

    -- opensOverride = raw number of opens (the box value is packs x5);
    -- onDone(opened) fires when the batch ends; stopFn() ends it early.
    local function openCards(opensOverride, onDone, stopFn)
        if packOpRunning then setStatus("Already opening...") if onDone then onDone(0) end return end
        packOpRunning=true
        local def=PACK_TYPES[selectedPack]
        local target = opensOverride and math.max(1,math.floor(opensOverride))
                       or math.clamp(math.floor(tonumber(openCount) or 20),1,2000)*5

        setInstantOpen(true)
        getgenv().KillPackGui=true
        if not suppressorActive then suppressorActive=true task.spawn(function()
            local pg=LocalPlayer:WaitForChild("PlayerGui")
            while getgenv().KillPackGui do for _,g in pairs(pg:GetChildren()) do local n=g.Name:lower()
                if g:IsA("ScreenGui") and (n:find("pack") or n:find("card")) then g.Enabled=false end end task.wait(0.05) end
            suppressorActive=false end) end
        task.spawn(function()
            local opened=0
            local ok,err=pcall(function()
                for i=1,target do
                    local hum,p
                    local t0=os.clock()
                    repeat                                  -- wait out replication so we don't quit early
                        local ch=LocalPlayer.Character
                        hum=ch and ch:FindFirstChildOfClass("Humanoid")
                        p=findPack(def.match)
                        if hum and p then break end
                        task.wait(0.1)
                    until os.clock()-t0>1.5
                    if not (hum and p) then break end       -- genuinely out of packs
                    pcall(function() hum:EquipTool(p) end)
                    task.wait(0.08)
                    pcall(function() RS.Remotes.OpenHeldPack:FireServer() end)
                    opened+=1
                    if stopFn and opened % 3 == 0 and stopFn(opened) then break end
                    if opened%3==0 then setStatus(("Opening %s... %d/%d"):format(def.label,opened,target)) end
                    task.wait(0.25)                         -- let the server consume + hand you the next one
                end
            end)
            getgenv().KillPackGui=false
            restoreView()
            packOpRunning=false                             -- ALWAYS clears, even on error
            if not ok then setStatus("Open stopped: "..tostring(err).." (got "..opened..")")
            elseif not onDone then setStatus(opened==0 and ("No '"..def.label.."' packs found.") or (("Opened %d %s. No rejoin."):format(opened,def.label))) end
            if onDone then onDone(opened) end
        end)
    end

    local function deleteCards(onDone)
        task.spawn(function() local ok2,err=pcall(function()
            local pg=LocalPlayer:WaitForChild("PlayerGui")
            local sz=pg:FindFirstChild("SiblingZIndex") local deck=sz and sz:FindFirstChild("DeckCreator")
            local mc=deck and deck:FindFirstChild("Main") mc=mc and mc:FindFirstChild("Main_Content")
            if not mc then setStatus("Open the card menu first.") return "nomenu" end
            local Cards=mc:FindFirstChild("Cards") local DeleteCards=RS.Remotes.Cards.General.DeleteCards
            if not Cards then setStatus("Card grid not found.") return "nogrid" end
            local function tierOf(t) t=(t or ""):upper() if t:find("III") then return 3 elseif t:find("II") then return 2 else return 1 end end
            local function readFrame(c) local m=c:FindFirstChild("Main") if not m then return nil end
                local nl=m:FindFirstChild("Name") local r=m:FindFirstChild("Rarity")
                local a=nl and nl.Parent:FindFirstChild("Amount") local cnt=1
                if a and a.Text then local n=tonumber((a.Text:gsub("[^%d]",""))) if n and n>0 then cnt=n end end
                return {name=nl and nl.Text or "?",tier=tierOf(r and r.Text),shiny=m:FindFirstChild("Hidden_Details")~=nil,count=cnt} end
            local function vkey(n,s) return (n:lower():gsub("^%s+",""):gsub("%s+$","")).."|"..(s and "S" or "N") end
            local pageBox for _,o in ipairs(mc:GetDescendants()) do if o:IsA("TextBox") and (o.Text or ""):match("%d+%s*/%s*%d+") then pageBox=o break end end
            if not pageBox then setStatus("Page box not found.") return "nopagebox" end
            local function cur() return tonumber((pageBox.Text or ""):match("(%d+)")) end
            local function maxp() return tonumber((pageBox.Text or ""):match("/%s*(%d+)")) end
            local function goto(n) for _=1,3 do pcall(function() pageBox:CaptureFocus() task.wait(0.08) pageBox.Text=tostring(n)
                task.wait(0.05) VIM:SendKeyEvent(true,Enum.KeyCode.Return,false,game) task.wait(0.04) VIM:SendKeyEvent(false,Enum.KeyCode.Return,false,game)
                pcall(function() pageBox:ReleaseFocus(true) end) end) task.wait(0.5) if cur()==n then return true end end return false end
            local mx=maxp() if not mx then setStatus("Couldn't read page count.") return "nopages" end
            if not goto(1) then setStatus("Couldn't go to page 1.") return "nopage1" end
            local store={} for n=1,mx do if cur()~=n then goto(n) end task.wait(0.15)
                for _,c in ipairs(Cards:GetChildren()) do if c:IsA("Frame") and c.Name~="NormalTemplate" and c.Name~="ShinyTemplate" then
                    if not store[c.Name] then local i=readFrame(c) if i then i.uuid=c.Name store[c.Name]=i end end end end
                setStatus(("Reading page %d/%d"):format(n,mx)) end
            local hasT3={} for _,i in pairs(store) do if i.tier==3 and i.count>=1 then hasT3[vkey(i.name,i.shiny)]=true end end
            local plan,total={},0 for _,i in pairs(store) do local target
                if i.tier==3 then target=1 else target=hasT3[vkey(i.name,i.shiny)] and 0 or i.count end
                local f=i.count-target if f>0 then total=total+f table.insert(plan,{uuid=i.uuid,fires=f}) end end
            if total==0 then setStatus("Nothing to delete - already clean.") return "clean" end
            local queue={} for _,p in ipairs(plan) do for _=1,p.fires do queue[#queue+1]=p.uuid end end
            local BATCH,done=25,0
            for i=1,#queue,BATCH do local chunk={} for j=i,math.min(i+BATCH-1,#queue) do chunk[#chunk+1]=queue[j] end
                DeleteCards:FireServer(chunk) done=done+#chunk setStatus(("Deleting %d/%d"):format(done,total)) task.wait(0.12) end
            setStatus(("Done - deleted %d cards."):format(total))
            return "deleted"
        end)
        if not ok2 then setStatus("Delete error: "..tostring(err)) end
        if onDone then onDone(ok2 and err or nil, (not ok2) and tostring(err) or nil) end
        end)
    end

    -- row 1: pack dropdown + amount + Open
    local packBtn = mkButton(cardTab,"v "..PACK_TYPES[selectedPack].label,C.panel,UDim2.fromOffset(150,28),UDim2.fromOffset(0,0))
    packBtn.TextXAlignment=Enum.TextXAlignment.Left local pp=Instance.new("UIPadding",packBtn) pp.PaddingLeft=UDim.new(0,8)
    mkLabel(cardTab,"Packs",UDim2.fromOffset(46,28),UDim2.fromOffset(158,0),C.dim,Enum.Font.Gotham,12)
    local amtBox=Instance.new("TextBox",cardTab)
    amtBox.Size=UDim2.fromOffset(64,28) amtBox.Position=UDim2.fromOffset(210,0)
    amtBox.BackgroundColor3=C.field amtBox.TextColor3=Color3.new(1,1,1) amtBox.Font=Enum.Font.GothamMedium amtBox.TextSize=15
    amtBox.Text=tostring(openCount) amtBox.ClearTextOnFocus=false corner(amtBox,6)
    amtBox.FocusLost:Connect(function() local n=tonumber(amtBox.Text) if n and n>=1 then openCount=math.floor(n) end amtBox.Text=tostring(openCount) end)
    local openBtn=mkButton(cardTab,"Open",C.purple,UDim2.fromOffset(108,28),UDim2.fromOffset(284,0))

    -- row 2: Delete
    local delBtn=mkButton(cardTab,"Delete Cards",C.amber,UDim2.fromOffset(140,28),UDim2.fromOffset(0,36))

    do local h=mkLabel(cardTab,"Pick a pack, set how many packs, hit Open. Opens that many fast and leaves your HUD alone. No rejoin.",
        UDim2.new(1,0,0,40),UDim2.fromOffset(0,72),C.dim,Enum.Font.Gotham,11) h.TextWrapped=true h.Visible=false end

    -- dropdown
    local drop=Instance.new("Frame",cardTab) drop.Visible=false drop.Size=UDim2.fromOffset(150,(#PACK_TYPES*28)+8)
    drop.Position=UDim2.fromOffset(0,30) drop.BackgroundColor3=C.panel drop.BorderSizePixel=0 drop.ZIndex=50 corner(drop,6)
    local dl=Instance.new("UIListLayout",drop) dl.Padding=UDim.new(0,2) local dpad=Instance.new("UIPadding",drop)
    dpad.PaddingTop=UDim.new(0,3) dpad.PaddingLeft=UDim.new(0,3) dpad.PaddingRight=UDim.new(0,3)
    for idx,pt in ipairs(PACK_TYPES) do local opt=mkButton(drop,pt.label,C.row,UDim2.new(1,0,0,26),UDim2.new()) opt.ZIndex=51 opt.LayoutOrder=idx
        opt.MouseButton1Click:Connect(function() selectedPack=idx packBtn.Text="v "..pt.label drop.Visible=false setStatus("Pack: "..pt.label) end) end
    packBtn.MouseButton1Click:Connect(function() drop.Visible=not drop.Visible end)

    openBtn.MouseButton1Click:Connect(function() setStatus("Opening...") openCards() end)
    delBtn.MouseButton1Click:Connect(function() setStatus("Deleting...") deleteCards() end)
    ------------------------------------------------------------------
    -- AUTO FARM: open -> merge -> delete -> keep opening, unattended.
    -- Wrapped in its own function so its locals don't count against the
    -- main chunk's 200-local limit.
    --
    -- Lessons baked in from the last round:
    --  * count comes from the replica first (GetData() may return the inner
    --    table directly, so "g.Data or g"), the menu label only as a validated
    --    fallback - a bare "N/M" scan also matches the PAGE counter
    --  * "no room" always means make room: merge, and only if merging frees
    --    nothing, delete. Never stop just because a batch would be zero.
    --  * a full bag is detected by the count NOT RISING mid-batch, so it works
    --    even if the absolute number is off
    --  * every phase also prints to the console, because the card menu covers
    --    the status bar
    ------------------------------------------------------------------
    local function __buildAutoFarm()
        local PDc, GeneralCfg, MergeAllCards
        pcall(function() PDc = require(RS:WaitForChild("PlayerData")) end)
        pcall(function() GeneralCfg = require(RS.Modules.Library.General) end)
        local autoRunning, autoTarget = false, 0

        local function phase(msg) setStatus("Auto farm: "..msg) warn("[AutoFarm] "..msg) end
        local function mergeRemote()
            if MergeAllCards and MergeAllCards.Parent then return MergeAllCards end
            local rem = RS:FindFirstChild("Remotes")
            MergeAllCards = rem and rem:FindFirstChild("MergeAllCards")
            return MergeAllCards
        end

        local function cardsFromReplica()
            if not PDc then return nil end
            local ok,n = pcall(function()
                local g = PDc:GetData()
                local d = g and (g.Data or g)
                local inv = d and d.Cards and d.Cards.Inventory
                if type(inv)~="table" then return nil end
                local total = 0
                for _,v in pairs(inv) do
                    total = total + ((type(v)=="table" and type(v.Data)=="table" and tonumber(v.Data.Count)) or 1)
                end
                return total
            end)
            return ok and n or nil
        end
        local function cardsFromUI()
            local ok,n,m = pcall(function()
                local pg   = LocalPlayer:FindFirstChild("PlayerGui")
                local sz   = pg and pg:FindFirstChild("SiblingZIndex")
                local deck = sz and sz:FindFirstChild("DeckCreator")
                local mc   = deck and deck:FindFirstChild("Main")
                mc = mc and mc:FindFirstChild("Main_Content")
                local prog = mc and mc:FindFirstChild("Progress")
                if not prog then return nil end
                for _,o in ipairs(prog:GetDescendants()) do
                    if o:IsA("TextLabel") or o:IsA("TextBox") or o:IsA("TextButton") then
                        local a,b = tostring(o.Text):match("(%d[%d,]*)%s*/%s*(%d[%d,]*)")
                        if a then return tonumber((a:gsub(",",""))), tonumber((b:gsub(",",""))) end
                    end
                end
                return nil
            end)
            if ok then return n,m end
            return nil
        end

        local uiMax = nil
        local function maxCards()     return uiMax or (GeneralCfg and tonumber(GeneralCfg.MaxCardsOwned)) or 1000 end
        local function cardsPerOpen() return (GeneralCfg and tonumber(GeneralCfg.PackCardAmount)) or 5 end
        local function plausibleCap(m)
            local cfg = GeneralCfg and tonumber(GeneralCfg.MaxCardsOwned)
            if cfg then return m == cfg end
            return m and m >= 200          -- page counts are small, the card cap is not
        end
        local function cardsOwned()
            local r = cardsFromReplica()
            if r then return r end
            local n,m = cardsFromUI()
            if n and plausibleCap(m) then uiMax = m return n end
            return nil
        end

        -- merging cascades (tier 1s make tier 2s that can make tier 3s), so
        -- keep firing until the count stops falling
        local function mergeAllUntilStable()
            local rem = mergeRemote()
            if not rem then phase("MergeAllCards remote not found") return cardsOwned(), false end
            local last = cardsOwned()
            for _=1,6 do
                pcall(function() rem:FireServer() end)
                local t0, settled = os.clock(), false
                while os.clock()-t0 < 4 do
                    task.wait(0.25)
                    local now = cardsOwned()
                    if now and last and now < last then last = now t0 = os.clock()
                    elseif now and last and now == last and os.clock()-t0 > 1.2 then settled = true break end
                end
                local now = cardsOwned()
                if settled and now and last and now >= last then break end
                last = now or last
            end
            return cardsOwned(), true
        end

        -- the deck menu is opened by EQUIPPING the "View Cards" tool
        local function ensureCardMenu()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local function vis()
                local sz = pg and pg:FindFirstChild("SiblingZIndex")
                local deck = sz and sz:FindFirstChild("DeckCreator")
                return deck and deck.Visible or false
            end
            if vis() then return true end
            local ch  = LocalPlayer.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local bp  = LocalPlayer:FindFirstChild("Backpack")
            local tool = (bp and bp:FindFirstChild("View Cards")) or (ch and ch:FindFirstChild("View Cards"))
            if not (tool and hum) then return false, "no 'View Cards' tool in the bag" end
            pcall(function() hum:EquipTool(tool) end)
            local t0 = os.clock()
            while os.clock()-t0 < 6 do
                task.wait(0.2)
                if vis() then task.wait(0.4) return true end
            end
            return false, "card menu did not open"
        end

        local function runDelete()
            local ok, why = ensureCardMenu()
            if not ok then return false, why end
            local done, res, err = false, nil, nil
            deleteCards(function(r,e) res, err, done = r, e, true end)
            local t0 = os.clock()
            while not done and os.clock()-t0 < 300 and autoRunning do task.wait(0.2) end
            if not done then return false, "delete timed out" end
            if err then return false, err end
            if res=="nomenu" or res=="nogrid" or res=="nopagebox" or res=="nopages" or res=="nopage1" then
                return false, "card menu not usable - page 1, no filters or search"
            end
            return true
        end

        -- no room always means make room: merge, then delete if merging is maxed
        local function makeRoom(now, mx)
            phase(("no room at %s/%d - merging"):format(tostring(now or "?"), mx))
            local after = mergeAllUntilStable()
            phase(("after merge: %s/%d"):format(tostring(after or "?"), mx))
            if after and now and after < now then return true end
            phase("merging freed nothing - deleting (scans every page, can take a few minutes)")
            local ok, why = runDelete()
            if not ok then phase("stopped: "..tostring(why)) return false end
            task.wait(1)
            local n3 = cardsOwned()
            if n3 and after and n3 >= after then
                phase(("stopped: still %d/%d after merge and delete"):format(n3, mx))
                return false
            end
            return true
        end

        local autoBtn, autoBox
        local function rfAuto()
            if not autoBtn then return end
            autoBtn.Text = autoRunning and "Auto farm: ON" or "Auto farm: OFF"
            autoBtn.BackgroundColor3 = autoRunning and C.green or C.grey
        end

        local function autoFarm()
            if autoRunning then autoRunning = false rfAuto() phase("stopping") return end
            autoRunning = true rfAuto()
            task.spawn(function()
                -- an uncaught error used to kill the loop silently; never again
                local okRun, runErr = pcall(function()
                    local def     = PACK_TYPES[selectedPack]
                    local per     = cardsPerOpen()
                    local RESERVE = per * 4
                    local total   = 0
                    local target  = math.max(0, math.floor(tonumber(autoTarget) or 0))

                    phase("starting")
                    phase(mergeRemote() and "merge remote OK" or "merge remote MISSING")
                    phase(ensureCardMenu() and "card menu ready" or "card menu not open yet")
                    phase("initial merge")
                    mergeAllUntilStable()

                    local pass = 0
                    while autoRunning do
                        pass = pass + 1
                        local mx  = maxCards()
                        local now = cardsOwned()
                        local opens
                        if now then
                            phase(("pass %d - storage %d/%d (%s)"):format(pass, now, mx, cardsFromReplica() and "replica" or "menu"))
                            opens = math.floor(((mx - RESERVE) - now) / per)
                        else
                            phase(("pass %d - storage unreadable, opening a fixed batch"):format(pass))
                            opens = 20
                        end
                        if target > 0 and total >= target then phase(("done: %d packs"):format(total)) break end
                        if target > 0 then opens = math.min(opens, target - total) end

                        if opens < 1 then
                            if not makeRoom(now, mx) then break end
                            continue
                        end

                        local bDone, bGot, hitFull = false, 0, false
                        local lastSample, stalls = cardsOwned(), 0
                        phase(("opening %d (%d done so far)"):format(opens, total))
                        openCards(opens, function(g) bGot = g bDone = true end, function()
                            if not autoRunning then return true end
                            local c = cardsOwned()
                            if c and lastSample then
                                if c > lastSample then stalls = 0 else stalls = stalls + 1 end
                                lastSample = c
                                if c >= mx - RESERVE then hitFull = true return true end
                            end
                            if stalls >= 3 then hitFull = true return true end   -- bag stopped accepting cards
                            return false
                        end)
                        local t0 = os.clock()
                        while not bDone and os.clock()-t0 < 900 do task.wait(0.2) end
                        if not autoRunning then break end
                        if not bDone then phase("stopped: opener timed out") break end

                        total = total + bGot
                        if bGot == 0 and not hitFull then
                            phase(("done: out of %s packs (%d opened)"):format(def.label, total))
                            break
                        end
                        if hitFull and not makeRoom(cardsOwned(), mx) then break end
                        task.wait(0.2)
                    end
                end)
                if not okRun then phase("ERROR: "..tostring(runErr)) end
                autoRunning = false rfAuto()
            end)
        end

        -- row 2, re-laid out to fit the 72px strip without pushing Potions down:
        -- [Delete][Merge all][Auto farm: OFF] stop [ 0 ]
        delBtn.Text = "Delete"
        delBtn.Size = UDim2.fromOffset(84,28)
        local mergeBtn = mkButton(cardTab,"Merge all",C.blue,UDim2.fromOffset(84,28),UDim2.fromOffset(88,36))
        autoBtn = mkButton(cardTab,"Auto farm: OFF",C.grey,UDim2.fromOffset(110,28),UDim2.fromOffset(176,36))
        mkLabel(cardTab,"stop",UDim2.fromOffset(30,28),UDim2.fromOffset(290,36),C.dim,Enum.Font.Gotham,12)
        autoBox = Instance.new("TextBox",cardTab)
        autoBox.Size = UDim2.fromOffset(64,28) autoBox.Position = UDim2.fromOffset(322,36)
        autoBox.BackgroundColor3 = C.field autoBox.TextColor3 = Color3.new(1,1,1)
        autoBox.Font = Enum.Font.GothamMedium autoBox.TextSize = 14 autoBox.Text = "0"
        autoBox.ClearTextOnFocus = false corner(autoBox,6)
        autoBox.FocusLost:Connect(function()
            local n = tonumber(autoBox.Text)
            autoTarget = (n and n > 0) and math.floor(n) or 0
            autoBox.Text = tostring(autoTarget)
            setStatus(autoTarget > 0 and ("Auto farm stops after %d packs"):format(autoTarget) or "Auto farm runs until packs run out")
        end)

        mergeBtn.MouseButton1Click:Connect(function()
            task.spawn(function()
                local before = cardsOwned()
                phase("merge all: firing (before "..tostring(before or "?")..")")
                local after, ok = mergeAllUntilStable()
                phase(ok and ("merge all: %s -> %s"):format(tostring(before or "?"), tostring(after or "?")) or "merge all: remote missing")
            end)
        end)
        autoBtn.MouseButton1Click:Connect(autoFarm)
        rfAuto()
    end
    __buildAutoFarm()

end
----------------------------------------------------------------------
--  HOME TAB  (replaces the old Cards tab UI)
--  Profile header + your live leaderboard standings, fed by the same
--  Remotes.UpdateLeaderboards push the physical board uses. Entries are
--  rank-ordered {key="x_userid_username", value=n}; Playtime is seconds.
----------------------------------------------------------------------
do
    local METRICS = {
        { key="TotalPlanted",      label="Plants Planted" },
        { key="Defeated",          label="Brainrots Defeated", eta=true },
        { key="Playtime",          label="Time Played" },
        { key="InfiniteHighScore", label="Mission High Score" },
        { key="Robux Spent",       label="Robux Spent", joinGap=true },
        { key="FishCaught",        label="Fish Caught", liveOnly=true },
    }
    local boards, gotPush = {}, false
    -- LIVE values straight from player data - the same source as the settings
    -- Stats window (Data[statName]) - so numbers tick in real time instead of
    -- waiting for board pushes. FishCaught = Data.Fishing.TotalFished.
    local PDH; pcall(function() PDH = require(RS:WaitForChild("PlayerData")) end)
    local function liveVal(key)
        if not PDH then return nil end
        local ok,v = pcall(function()
            local g = PDH:GetData()
            local d = g.Data or g
            if key=="FishCaught" then return d.Fishing and d.Fishing.TotalFished end
            return d[key]
        end)
        return ok and tonumber(v) or nil
    end
    -- defeat-rate tracker for the ETA (rolling ~2 min window of live Defeated)
    local defHist = {}
    local function defeatRate()
        local now, v = os.clock(), liveVal("Defeated")
        if v then
            defHist[#defHist+1] = { t=now, v=v }
            while #defHist>0 and now-defHist[1].t>120 do table.remove(defHist,1) end
        end
        if #defHist>=2 then
            local a,b = defHist[1], defHist[#defHist]
            local dt = b.t-a.t
            if dt>5 and b.v>a.v then return (b.v-a.v)/dt end
        end
        return nil
    end
    local function fmtEta(sec)
        if sec<60 then return "under a minute" end
        local d=math.floor(sec/86400) sec=sec-d*86400
        local h=math.floor(sec/3600) sec=sec-h*3600
        local m=math.floor(sec/60)
        if d>0 then return ("%dd %dh"):format(d,h) end
        if h>0 then return ("%dh %dm"):format(h,m) end
        return ("%dm"):format(m)
    end

    local function fmtNum(n)
        n = tonumber(n) or 0
        if n >= 1e9 then return ("%.2fB"):format(n/1e9) end
        if n >= 1e6 then return ("%.2fM"):format(n/1e6) end
        if n >= 1e3 then return ("%.1fK"):format(n/1e3) end
        return tostring(math.floor(n))
    end
    local function fmtVal(key, v)
        if key=="Playtime" then
            local s = math.floor(tonumber(v) or 0)
            local d = math.floor(s/86400); s = s - d*86400
            local h = math.floor(s/3600);  s = s - h*3600
            return ("%dd %dh %dm"):format(d, h, math.floor(s/60))
        end
        return fmtNum(v)
    end
    local function myRow(key)
        local list = boards[key]
        if type(list)~="table" then return nil end
        local uid = tostring(LocalPlayer.UserId)
        for i,e in ipairs(list) do
            if type(e)=="table" and type(e.key)=="string" then
                local parts = string.split(e.key,"_")
                if parts[2]==uid then
                    local gap
                    if i>1 and type(list[i-1])=="table" and tonumber(list[i-1].value) then
                        gap = list[i-1].value - (tonumber(e.value) or 0)
                    end
                    return { rank=i, value=e.value, gap=gap }
                end
            end
        end
        return nil
    end

    -- profile header
    local head = Instance.new("Frame")
    head.BackgroundColor3=C.panel; head.BorderSizePixel=0
    head.Size=UDim2.new(1,0,0,72); head.Position=UDim2.new(); head.Parent=cardTab
    corner(head,10)
    local pfp = Instance.new("ImageLabel")
    pfp.Size=UDim2.fromOffset(56,56); pfp.Position=UDim2.fromOffset(8,8)
    pfp.BackgroundColor3=C.row; pfp.BorderSizePixel=0
    pfp.Image=("rbxthumb://type=AvatarHeadShot&id=%d&w=180&h=180"):format(LocalPlayer.UserId)
    pfp.Parent=head corner(pfp,28)
    mkLabel(head, LocalPlayer.DisplayName, UDim2.new(1,-140,0,22), UDim2.fromOffset(74,12), C.txt, Enum.Font.GothamBold, 16)
    mkLabel(head, "@"..LocalPlayer.Name, UDim2.new(1,-140,0,16), UDim2.fromOffset(74,36), C.dim, Enum.Font.Gotham, 12)
    local pushLbl = mkLabel(head, "waiting for board...", UDim2.fromOffset(120,16), UDim2.new(1,-128,0,8), C.dim, Enum.Font.Gotham, 10)
    pushLbl.TextXAlignment=Enum.TextXAlignment.Right

    -- metric cards
    local listS = Instance.new("ScrollingFrame")
    listS.BackgroundTransparency=1; listS.BorderSizePixel=0
    listS.Size=UDim2.new(1,0,1,-80); listS.Position=UDim2.fromOffset(0,80)
    listS.ScrollBarThickness=6; listS.CanvasSize=UDim2.new()
    listS.AutomaticCanvasSize=Enum.AutomaticSize.Y; listS.Parent=cardTab
    local innerH = Instance.new("Frame")
    innerH.BackgroundTransparency=1; innerH.Size=UDim2.new(1,-12,0,#METRICS*56)
    innerH.Parent=listS
    local rows = {}
    for i,m in ipairs(METRICS) do
        local r = Instance.new("Frame")
        r.BackgroundColor3=C.panel; r.BorderSizePixel=0
        r.Size=UDim2.new(1,0,0,50); r.Position=UDim2.fromOffset(0,(i-1)*56); r.Parent=innerH
        corner(r,8)
        mkLabel(r, m.label, UDim2.new(0.55,-10,0,20), UDim2.fromOffset(10,6), C.dim, Enum.Font.Gotham, 12)
        local val = mkLabel(r, "-", UDim2.new(0.55,-10,0,22), UDim2.fromOffset(10,24), C.txt, Enum.Font.GothamBold, 15)
        local rk  = mkLabel(r, "", UDim2.new(0.45,-10,0,20), UDim2.new(0.55,0,0,6), C.dim, Enum.Font.GothamMedium, 12)
        rk.TextXAlignment=Enum.TextXAlignment.Right
        local gp  = mkLabel(r, "", UDim2.new(0.45,-10,0,18), UDim2.new(0.55,0,0,26), C.dim, Enum.Font.Gotham, 11)
        gp.TextXAlignment=Enum.TextXAlignment.Right
        rows[m.key] = { val=val, rk=rk, gp=gp }
    end

    local function render()
        for _,m in ipairs(METRICS) do
            local r  = rows[m.key]
            local lv = liveVal(m.key)                          -- live number first
            local me = (not m.liveOnly) and myRow(m.key) or nil
            local shown = lv or (me and me.value)
            r.val.Text = shown and fmtVal(m.key, shown) or (gotPush and "not on board" or "waiting...")
            if m.liveOnly then
                r.rk.Text="" r.gp.Text=""
            elseif me then
                r.rk.Text = "#"..me.rank
                r.rk.TextColor3 = (me.rank==1) and Color3.fromRGB(240,205,50) or C.txt
                if me.rank==1 then
                    r.gp.Text = "top of the board"
                else
                    local myv   = lv or tonumber(me.value) or 0
                    local ahead = boards[m.key] and boards[m.key][me.rank-1]
                    local gap   = (ahead and tonumber(ahead.value)) and (ahead.value - myv) or me.gap
                    if gap and gap>0 then
                        local line = fmtVal(m.key, gap).." behind #"..(me.rank-1)
                        if m.eta then
                            local rate = defeatRate()
                            if rate and rate>0 then line = line.."  |  ETA "..fmtEta(gap/rate) end
                        end
                        r.gp.Text = line
                    else
                        r.gp.Text = ""
                    end
                end
            else
                r.rk.Text = ""
                if m.joinGap and gotPush and lv then           -- how far from getting ON the board
                    local list = boards[m.key]
                    local tail = list and list[#list]
                    if tail and tonumber(tail.value) and tail.value>lv then
                        r.gp.Text = fmtVal(m.key, tail.value-lv).." more to reach #"..#list
                    else r.gp.Text = "" end
                else
                    r.gp.Text = ""
                end
            end
        end
    end
    render()

    pcall(function()
        RS.Remotes:WaitForChild("UpdateLeaderboards").OnClientEvent:Connect(function(p1)
            if type(p1)~="table" then return end
            for k,v in pairs(p1) do boards[k]=v end
            gotPush=true
            pushLbl.Text="live"
            pushLbl.TextColor3=C.green
            render()
        end)
    end)

    -- The server pushes the board once right after join, almost always BEFORE this
    -- script loads, so listening alone can wait a long time for the next push.
    -- The game's own board handler keeps that pushed data in an upvalue table,
    -- so pull it straight out via getconnections + getupvalues and keep syncing.
    local function upvalsOf(f)
        local out
        pcall(function() out = debug.getupvalues(f) end)
        if type(out)~="table" and type(getupvalues)=="function" then pcall(function() out = getupvalues(f) end) end
        return type(out)=="table" and out or nil
    end
    local function pullGameBoards()
        if type(getconnections)~="function" then return false end
        local found=false
        pcall(function()
            for _,cn in ipairs(getconnections(RS.Remotes.UpdateLeaderboards.OnClientEvent)) do
                local f = cn.Function or cn.Fn
                if type(f)=="function" then
                    local ups=upvalsOf(f)
                    if ups then
                        for _,uv in pairs(ups) do
                            if type(uv)=="table" and (type(uv.TotalPlanted)=="table" or type(uv.Defeated)=="table" or type(uv.Playtime)=="table") then
                                for k,v in pairs(uv) do
                                    if type(v)=="table" and #v>0 then boards[k]=v found=true end
                                end
                            end
                        end
                    end
                end
            end
        end)
        return found
    end
    task.spawn(function()
        while gui.Parent do
            if pullGameBoards() and not gotPush then
                gotPush=true
                pushLbl.Text="live"
                pushLbl.TextColor3=C.green
            end
            render()
            task.wait(5)
        end
    end)
end

----------------------------------------------------------------------
--  KEEP TAB  (filter flips at the kill line)   -- UPDATED
--  Changes vs original:
--   * Secret mode OFF now means "keep MUTATED secrets only" (was "keep all").
--   * Hardened mutation detector isMut() (tier/seed-suffix tolerant).
--   * Publishes getgenv().PvBKeepCfg so the Foolies/event tab can read
--     the same thresholds (keepSecretKg / keepAnyKg / keepOneMil / keepForbidden).
--  Drop-in replacement for the whole Keep do-block.
----------------------------------------------------------------------
do
    local AutoSell = RS.Remotes.AutoSell
    local FavoriteItem = RS.Remotes.FavoriteItem
    local LANE = workspace:WaitForChild("ScriptedMap"):WaitForChild("MissionBrainrots")
    local BP = LocalPlayer:WaitForChild("Backpack")

    local KEEP_Z = 595

    local cfg    = { enabled=true, keepForbidden=true, keepSecretKg=75, keepAnyKg=150, doHeart=true, invManage=true, keepOneMil=true, sellEverySec=3.5, sellLullSec=3 }
    local staged = { enabled=true, keepForbidden=true, keepSecretKg=75, keepAnyKg=150, doHeart=true, invManage=true, keepOneMil=true, sellEverySec=3.5, sellLullSec=3 }

    ------------------------------------------------------------------ persistence across sessions (executor file API)
    local SAVE_FILE = "PvBToolkit_keep.json"
    local function saveCfg()
        pcall(function()
            if writefile then writefile(SAVE_FILE, game:GetService("HttpService"):JSONEncode(cfg)) end
        end)
    end
    local function loadCfg()
        pcall(function()
            if isfile and readfile and isfile(SAVE_FILE) then
                local data = game:GetService("HttpService"):JSONDecode(readfile(SAVE_FILE))
                if type(data)=="table" then
                    for k,v in pairs(data) do
                        if cfg[k]~=nil and type(v)==type(cfg[k]) then cfg[k]=v staged[k]=v end  -- known keys, same type
                    end
                end
            end
        end)
    end
    loadCfg()  -- restore saved toggles/thresholds before anything reads them
    -- expose live config to other tabs (event tab reads thresholds from here).
    -- expose live config to other tabs; cfg is mutated in place so this reference stays current.
    getgenv().PvBKeepCfg = cfg

    local function kgToSize(kg) return kg/10 end
    local secretNames = {}

    local function meetsCriteria(rarity,size)
        if cfg.keepForbidden and rarity=="Forbidden" then return true end
        if size and size>kgToSize(cfg.keepAnyKg) then return true end
        return false
    end
    local function shouldKeep(rarity,size)
        return cfg.enabled and meetsCriteria(rarity,size)
    end

    local filterOn, touched = {}, {}
    local preFlip  = {}   -- rarity -> filter state sampled JUST BEFORE we flipped for a keeper
    local holding  = {}   -- rarity -> true while we hold the flip for a keeper at the line
    local asPending = {}  -- rarity -> time we last fired, so replica lag doesn't cause rapid re-toggling
    local kStat = { seen=0, kept=0, fires=0, z=nil, keepers=0, last="" }   -- keep-health readout
    local PD0 pcall(function() PD0 = require(RS:WaitForChild("PlayerData")) end)
    local function curAutoSell(rarity)                    -- ACTUAL in-game state from the replica
        if not PD0 then return nil end
        local ok,v = pcall(function()
            local g = PD0:GetData()
            local d = g.Data or g                          -- GetData() sometimes returns the inner table directly
            return d.AutoSell
        end)
        if ok and type(v)=="table" then return v[rarity] and true or false end
        return nil
    end
    local function fireToggle(rarity)
        if (os.clock() - (asPending[rarity] or 0)) > 0.6 then   -- one fire, then wait for it to replicate
            AutoSell:FireServer(rarity)
            asPending[rarity]=os.clock()
            kStat.fires = kStat.fires + 1
        end
    end
    -- Flip-and-restore, sampled fresh PER KEEPER. The old version captured a
    -- "resting baseline" once per session; if anything else touched the filters
    -- (cycle, foolies, a manual click) at the wrong moment, that baseline went
    -- stale and every later flip computed a no-op - silently collecting nothing
    -- for the rest of the session. Now: when a keeper reaches the line we read
    -- the CURRENT state, flip it, hold; when the keeper is gone we restore the
    -- sampled state and go hands-off. Wrong state can never outlive one wave.
    local function setFilter(rarity,want)
        local cur = curAutoSell(rarity)
        if cur == nil then                                -- replica unreadable: fall back to the old tracked toggle
            if (filterOn[rarity] or false)~=want then AutoSell:FireServer(rarity) filterOn[rarity]=want end
            return
        end
        if want then
            if not holding[rarity] then
                if preFlip[rarity]==nil then preFlip[rarity]=cur end   -- sample at the moment of need
                holding[rarity]=true
            end
            local desired = not preFlip[rarity]
            if cur ~= desired then fireToggle(rarity) else asPending[rarity]=nil end
        elseif holding[rarity] then
            local desired = preFlip[rarity]
            if cur ~= desired then fireToggle(rarity)
            else holding[rarity]=nil preFlip[rarity]=nil asPending[rarity]=nil end
        end
        -- not holding and no keeper: hands off; the filter rests wherever YOU set it
        filterOn[rarity] = want
    end

    local pending={}
    local function tryHeart(item)
        if item:GetAttribute("PlantName") then return end
        local id=item:GetAttribute("ID") local name=item:GetAttribute("Brainrot") or item:GetAttribute("ItemName") local size=item:GetAttribute("Size")
        if not (id and name and size) then return end
        for i,p in ipairs(pending) do if p.name==name and math.abs(p.size-size)<0.0001 then
            FavoriteItem:FireServer(id) table.remove(pending,i) return end end
    end
    local PD2 pcall(function() PD2 = require(RS:WaitForChild("PlayerData")) end)
    local function isFav(id)
        if PD2 then local ok2,fav=pcall(function() return PD2:GetData().Data.Favorites end)
            if ok2 and type(fav)=="table" then local f=fav[id] return f~=nil and f~=false end end
        return false
    end
    local function setFav(id,want) if isFav(id)~=want then FavoriteItem:FireServer(id) end end

    -- display helper (unchanged): returns the mutation string or "Normal"
    local function mutOf(item)
        local ms=item:GetAttribute("MutationString")
        local base=item:GetAttribute("Brainrot") or item:GetAttribute("ItemName")
        if ms and base and ms~=base then return ms end
        return "Normal"
    end

    -- boolean mutation test: the mutation is the words in MutationString that the
    -- base name doesn't account for. We cancel words as a MULTISET, so a tier
    -- token ("IV") present in BOTH the base name and the MutationString cancels and
    -- never looks like a mutation. Any leftover non-tier word => mutated. The
    -- mutation registries are only a fallback for when the base name is missing.
    local PlantMutations, BrainrotMutations
    pcall(function() PlantMutations    = require(RS.Modules.Library.PlantMutations) end)
    pcall(function() BrainrotMutations = require(RS.Modules.Library.BrainrotMutations) end)
    local ROMAN  = {i=true,ii=true,iii=true,iv=true,v=true,vi=true,vii=true,viii=true,ix=true,x=true,xi=true,xii=true}
    local IGNORE = {seed=true}
    local MUT_TOKENS = {}
    local function addMutKeys(mod)
        if type(mod)~="table" then return end
        local colors = mod.Colors or mod
        if type(colors)~="table" then return end
        for name in pairs(colors) do
            if type(name)=="string" and name:lower()~="normal" then MUT_TOKENS[name:lower()]=true end
        end
    end
    addMutKeys(PlantMutations); addMutKeys(BrainrotMutations)
    for _,n in ipairs({"Gold","Diamond","Ruby","Rainbow","Love","Electrified","Underworld",
        "Upside Down","Upside","Neon","Amped","Tornado","Galactic","Foggy","Corrupted",
        "Ascended","Magma","Wrapped"}) do MUT_TOKENS[n:lower()]=true end
    local function isMut(item)
        local ms = item:GetAttribute("MutationString")
        if not ms or ms=="" then return false end
        local base = item:GetAttribute("Brainrot") or item:GetAttribute("ItemName")
                  or item:GetAttribute("PlantName") or item:GetAttribute("SeedName")
        if not base then
            local first = ms:match("^(%S+)")
            return (first~=nil and MUT_TOKENS[first:lower()]==true)
        end
        local bw = {}
        for w in tostring(base):lower():gmatch("[%w]+") do bw[w]=(bw[w] or 0)+1 end
        for w in tostring(ms):lower():gmatch("[%w]+") do
            if (bw[w] or 0)>0 then bw[w]=bw[w]-1
            elseif not (ROMAN[w] or IGNORE[w]) then return true end
        end
        return false
    end

    -- KEEP DECISION for a Secret in the bag:
    --   over keepSecretKg            -> keep (any mode)
    --   1M-mode ON  -> keep only >= 1,000,000
    --   1M-mode OFF -> keep only MUTATED   (changed: was "keep all")
    -- While the Foolies tab is running we force mutated-only, so the sub-1M mutated Secrets
    -- it feeds to the blender are KEPT instead of auto-sold out from under it.
    local function fooliesActive() return getgenv().PvBFooliesRun==true end
    local function effKeepOneMil() return cfg.keepOneMil and not fooliesActive() end
    local function secretKeeps(item)
        local size=tonumber(item:GetAttribute("Size")) or 0
        if size > kgToSize(cfg.keepSecretKg) then return true end
        if not effKeepOneMil() then return isMut(item) end
        local w=tonumber(item:GetAttribute("Worth"))
        if w==nil then return true end       -- worth not computed yet: keep for now, re-decide when it lands
        return w >= 1000000
    end

    -- a Secret's Worth only appears once the bag entry computes it. Deciding
    -- before that made 1M-mode read nil -> 0 -> "sell", which is how 1M Secrets
    -- were getting auto-sold. Now: wait for Worth, and if it still hasn't
    -- landed, keep the Secret and re-decide the moment Worth appears.
    local worthWatch = {}
    local function watchWorth(item)
        local id=item:GetAttribute("ID")
        if not id or worthWatch[id] then return end
        worthWatch[id]=true
        local conn
        conn=item:GetAttributeChangedSignal("Worth"):Connect(function()
            if conn then conn:Disconnect() conn=nil end
            worthWatch[id]=nil
            if cfg.enabled and item.Parent then setFav(id, secretKeeps(item)) end
        end)
        task.delay(30,function() if conn then conn:Disconnect() conn=nil worthWatch[id]=nil end end)
    end
    local function secretWaitWorth(item, timeout)
        local t0=os.clock()
        while item.Parent and tonumber(item:GetAttribute("Worth"))==nil and os.clock()-t0<(timeout or 6) do
            task.wait(0.15)
        end
        return tonumber(item:GetAttribute("Worth"))
    end
    local decided = {}
    local function secretHandler(item)
        if not cfg.enabled then return end
        local id=item:GetAttribute("ID") if not id then return end
        if decided[id] then return end
        decided[id]=true
        task.wait(0.25)
        if not item.Parent then decided[id]=nil return end
        -- only the 1M rule needs Worth; over-kg keeps decide on Size alone
        if effKeepOneMil() and (tonumber(item:GetAttribute("Size")) or 0) <= kgToSize(cfg.keepSecretKg) then
            if secretWaitWorth(item, 6)==nil then watchWorth(item) end
        end
        local keep=secretKeeps(item)
        setFav(id,keep)
        kStat.last = (keep and "kept Secret %s" or "sold Secret %s"):format(mutOf(item))
    end
    local function resweepSecrets()
        if not cfg.enabled then return end
        for _,t in ipairs(BP:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("ID") and not t:GetAttribute("PlantName")
               and t:GetAttribute("Rarity")=="Secret" then
                local id=t:GetAttribute("ID")
                decided[id]=true
                setFav(id, secretKeeps(t))
                task.wait(0.05)
            end
        end
    end
    local lastArrival = 0
    BP.ChildAdded:Connect(function(item)
        if item:IsA("Tool") and item:GetAttribute("ID") and not item:GetAttribute("PlantName") then
            lastArrival=os.clock()
            local nm=item:GetAttribute("Brainrot") or item:GetAttribute("ItemName")
            if cfg.enabled and nm and secretNames[nm] then task.delay(0.25,function() secretHandler(item) end) return end
        end
        task.delay(0.3,function() tryHeart(item) end)
    end)

    local ItemSell = RS.Remotes:WaitForChild("ItemSell")
    local function hasLooseBrainrot()
        for _,t in ipairs(BP:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("ID") and not t:GetAttribute("PlantName") then return true end
        end
        return false
    end
    -- keep-criteria check for a brainrot ALREADY IN THE BAG. The auto-sell is a
    -- bag-wide "sell all unhearted", so anything that qualifies under the keep
    -- rules must be hearted BEFORE the fire or it's gone.
    local function bagShouldKeep(t)
        if not cfg.enabled then return false end
        local rarity=t:GetAttribute("Rarity")
        local size=tonumber(t:GetAttribute("Size")) or 0
        if rarity=="Secret" then return secretKeeps(t) end
        return meetsCriteria(rarity,size)
    end
    local recentlyHearted = {}   -- id -> os.clock(); FavoriteItem is a TOGGLE, so
                                 -- never re-fire before the replica reflects the first heart
    local function preSellSweep()
        if not cfg.enabled then return end
        local now=os.clock()
        for id,t0 in pairs(recentlyHearted) do if now-t0>8 then recentlyHearted[id]=nil end end
        for _,t in ipairs(BP:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("ID") and not t:GetAttribute("PlantName") then
                local id=t:GetAttribute("ID")
                if not recentlyHearted[id] and not isFav(id) and bagShouldKeep(t) then
                    setFav(id,true)
                    recentlyHearted[id]=os.clock()
                    if t:GetAttribute("Rarity")=="Secret" and tonumber(t:GetAttribute("Worth"))==nil then watchWorth(t) end
                    kStat.last=("hearted %s pre-sell"):format(t:GetAttribute("Brainrot") or t:GetAttribute("ItemName") or "?")
                    task.wait(0.1)
                end
            end
        end
    end
    -- THE SWEEP. It used to sleep a full interval, test ONE instant, and if
    -- anything blocked it right then, sleep another full interval - which is
    -- why it skipped sells "half the time". It also clamped a lull of 0 up to
    -- 0.5s; with everything being collected a brainrot lands every ~0.3s, so
    -- that lull was almost never satisfied. Now it checks every 0.2s once a
    -- sell is due, uses the lull exactly as set, and cannot starve: a sell
    -- that is a whole extra interval late goes anyway.
    task.spawn(function()
        local lastSell = os.clock()
        while alive() do
            task.wait(0.2)
            local every  = math.max(tonumber(cfg.sellEverySec) or 3.5, 0.5)
            local waited = os.clock() - lastSell
            if waited >= every and (not getgenv().PvBCycleOn) and cfg.invManage and hasLooseBrainrot() then
                local lull    = math.max(tonumber(cfg.sellLullSec) or 0, 0)
                local lullOk  = lull <= 0 or (os.clock()-lastArrival) > lull
                local goldFn  = getgenv().PvBGoldWaiting
                local goldWait = goldFn and goldFn() or false
                -- golds still in the bag are protected; if one has sat there
                -- for three whole intervals the event is refusing it, and
                -- holding the sell any longer would just fill the bag
                if (lullOk or waited >= every*2) and ((not goldWait) or waited >= every*3) then
                    preSellSweep()   -- heart everything that meets the keep criteria first
                    task.wait(0.15)  -- let those hearts land before the bag is sold
                    local sellFn = getgenv().PvBFireSell
                    if sellFn then sellFn() else ItemSell:FireServer() end
                    lastSell = os.clock()
                end
            end
        end
    end)

    local function modelZ(model)
        local ok2,pos = pcall(function() return model:GetPivot().Position end)
        if ok2 and pos then return pos.Z end
        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        return part and part.Position.Z
    end

    local keepers = {}
    local function watch(model)
        if not model:IsA("Model") then return end
        local size=model:GetAttribute("Size") local t0=os.clock()
        while size==nil and os.clock()-t0<3 do task.wait() size=model:GetAttribute("Size") end
        local rarity=model:GetAttribute("Rarity") local name=model:GetAttribute("Brainrot")
        if not (rarity and size and name) then return end
        kStat.seen = kStat.seen + 1
        if not cfg.enabled then return end   -- master toggle gates ALL keep behavior
        if rarity=="Secret" then
            secretNames[name]=true
            keepers[model]="Secret" touched["Secret"]=true
            kStat.kept = kStat.kept + 1
            kStat.last = "Secret "..name
            return
        end
        if not shouldKeep(rarity,size) then return end
        kStat.kept = kStat.kept + 1
        kStat.last = ("%s %dkg"):format(rarity, math.floor(size*10))
        table.insert(pending,{name=name,size=size,t=os.clock()})
        keepers[model]=rarity
        touched[rarity]=true
    end
    for _,m in ipairs(LANE:GetChildren()) do task.spawn(watch,m) end
    LANE.ChildAdded:Connect(function(m) task.spawn(watch,m) end)

    RunService.Heartbeat:Connect(function()
        local want={}
        local n,topZ=0,nil
        for model,rarity in pairs(keepers) do
            if not model.Parent then
                keepers[model]=nil
            else
                n=n+1
                local z=modelZ(model)
                if z then if not topZ or z>topZ then topZ=z end
                    if z>=KEEP_Z then want[rarity]=true end
                end
            end
        end
        kStat.keepers, kStat.z = n, topZ
        if not cfg.enabled then
            table.clear(want)                             -- master OFF: release every held flip
            for m in pairs(keepers) do keepers[m]=nil end
        end
        for rarity in pairs(touched) do
            setFilter(rarity, want[rarity]==true)
        end
    end)
    task.spawn(function() while alive() do task.wait(10) local now=os.clock()
        for i=#pending,1,-1 do if now-pending[i].t>30 then table.remove(pending,i) end end end end)

    local y=0
    local function row(h) local r=Instance.new("Frame",keepTab) r.BackgroundTransparency=1 r.Size=UDim2.new(1,0,0,h) r.Position=UDim2.fromOffset(0,y) y=y+h+6 return r end
    local applyHint
    local function markDirty()
        local dirty=false for k,v in pairs(staged) do if cfg[k]~=v then dirty=true break end end
        if applyHint then applyHint.Text = dirty and "unsaved changes" or "" end
    end
    local toggleRf={}
    local function toggle(text,key)
        local r=row(26) local b=mkButton(r,"",C.row,UDim2.new(1,0,1,0),UDim2.new()) b.AutoButtonColor=true
        mkLabel(b,text,UDim2.new(1,-44,1,0),UDim2.fromOffset(8,0),C.txt,Enum.Font.Gotham,13)
        local pip=mkLabel(b,"",UDim2.fromOffset(34,18),UDim2.new(1,-40,0.5,-9),Color3.new(1,1,1),Enum.Font.GothamBold,11)
        pip.TextXAlignment=Enum.TextXAlignment.Center corner(pip,5)
        local function rf()
            local on=cfg[key]
            if key=="keepOneMil" then on=effKeepOneMil() end   -- show what's actually in effect (Foolies forces OFF)
            pip.Text=on and "ON" or "OFF" pip.BackgroundColor3=on and C.green or C.grey
        end
        toggleRf[key]=rf
        b.MouseButton1Click:Connect(function()
            cfg[key]=not cfg[key] staged[key]=cfg[key] saveCfg() rf() markDirty()
            if key=="enabled" and not cfg.enabled then
                for i=#pending,1,-1 do table.remove(pending,i) end
            end
        end) rf()
    end
    local function input(text,key)
        local r=row(26) mkLabel(r,text,UDim2.new(1,-70,1,0),UDim2.new(),C.txt,Enum.Font.Gotham,13)
        local box=Instance.new("TextBox",r) box.Size=UDim2.fromOffset(62,24) box.Position=UDim2.new(1,-62,0.5,-12)
        box.BackgroundColor3=C.field box.TextColor3=Color3.new(1,1,1) box.Font=Enum.Font.GothamMedium box.TextSize=13
        box.Text=tostring(staged[key]) box.ClearTextOnFocus=false corner(box,6)
        box.FocusLost:Connect(function() local n=tonumber(box.Text) if n then cfg[key]=n staged[key]=n getgenv().PvBKeepCfg=cfg saveCfg() else box.Text=tostring(cfg[key]) end end)
        return r
    end

    mkLabel(keepTab,"Auto-Keep",UDim2.new(1,0,0,18),UDim2.new(),C.txt,Enum.Font.GothamBold,14) y=22
    toggle("Enabled","enabled")
    toggle("Keep all Forbidden","keepForbidden")
    toggle("Secret mode: 1M only (off = mutated only)","keepOneMil")   -- text updated
    input("Keep secrets over (kg)","keepSecretKg")
    input("Keep anything over (kg)","keepAnyKg")
    toggle("Auto-sell brainrots in bag","invManage")
    -- when Foolies starts/stops, reflect the forced Secret-mode in the pip and re-decide bag secrets
    task.spawn(function()
        local last
        while alive() do
            task.wait(0.5)
            local now = fooliesActive()
            if now~=last then
                last=now
                if toggleRf.keepOneMil then toggleRf.keepOneMil() end
                resweepSecrets()
            end
        end
    end)
    mkLabel(keepTab,"Secret mode ON keeps >=1M, OFF keeps mutated only. Over-kg lines and Forbidden are always kept.",
        UDim2.new(1,0,0,32),UDim2.fromOffset(0,y),C.dim,Enum.Font.Gotham,11).TextWrapped=true
    y=y+36

    -- live pipeline health: proves at a glance which stage is working
    local kLbl = mkLabel(keepTab,"keep: starting...",UDim2.new(1,0,0,16),UDim2.fromOffset(0,y),C.dim,Enum.Font.Gotham,10)
    y=y+20
    task.spawn(function()
        while alive() do
            task.wait(1)
            pcall(function()
                kLbl.Text = ("keep: seen %d | kept %d | on-lane %d | z %s/%d | flips %d | last: %s"):format(
                    kStat.seen, kStat.kept, kStat.keepers,
                    kStat.z and tostring(math.floor(kStat.z)) or "-", KEEP_Z,
                    kStat.fires, kStat.last=="" and "-" or kStat.last)
            end)
        end
    end)

    ------------------------------------------------------------------
    -- Auto-sell timing lives behind an expander: rarely touched, was
    -- eating UI space next to the everyday toggles.
    ------------------------------------------------------------------
    local advBtn = mkButton(keepTab,"Auto-sell timing  v",C.row,UDim2.new(1,0,0,20),UDim2.fromOffset(0,y))
    advBtn.TextSize=11
    y=y+24
    local advRows={}
    advRows[1]=input("Auto-sell every (s)","sellEverySec")
    advRows[2]=input("Sell only after lull (s)","sellLullSec")
    for _,r in ipairs(advRows) do r.Visible=false end
    advBtn.MouseButton1Click:Connect(function()
        local show=not advRows[1].Visible
        for _,r in ipairs(advRows) do r.Visible=show end
        advBtn.Text=show and "Auto-sell timing  ^" or "Auto-sell timing  v"
    end)
end
----------------------------------------------------------------------
--  PLANT TAB  ->  AUTO PLANTER  (Standalone Plant Test v2 integrated)
--  Growth read from Plots[x].Seeds CompletionTime on the SERVER clock.
--  Water: equips premium bucket and splashes planned grid 3x3 cluster centers via
--         UseItem:FireServer({Toggle=true, Tool=bucket, Pos=centerPos}).
--  Harvest matured plants by ID; optional Sell; optional Loop.
----------------------------------------------------------------------
do
    local CS = game:GetService("CollectionService")
    local Remotes   = RS:WaitForChild("Remotes")
    local PlantSeed = Remotes:WaitForChild("Seeds"):WaitForChild("PlantSeed")
    local Pickup    = Remotes:WaitForChild("Plants"):WaitForChild("Pickup")
    local ItemSell  = Remotes:WaitForChild("ItemSell")
    local UseItem   = Remotes:WaitForChild("UseItem")
    local PlantRegistry; pcall(function() PlantRegistry = require(RS.Modules.Registries.PlantRegistry) end)

    ------------------------------------------------------------------ helpers
    local function serverNow()
        local ok,t = pcall(function() return workspace:GetServerTimeNow() end)
        if ok and type(t)=="number" and t>1e9 then return t end
        return os.time()
    end
    local function growTimeFor(seedName)
        if not (PlantRegistry and seedName) then return nil end
        local e = PlantRegistry[seedName] or PlantRegistry[(seedName:gsub("%s*Seed$",""))]
        return e and tonumber(e.GrowTime) or nil
    end
    local function myPlot()
        local plots = workspace:FindFirstChild("Plots"); if not plots then return nil end
        local anyOwned = false
        for _,p in ipairs(plots:GetChildren()) do
            local o = p:GetAttribute("Owner")
            if o ~= nil then anyOwned = true end
            if o == LocalPlayer.UserId then return p end
        end
        -- Only guess when the game is publishing no ownership at all. The old
        -- unconditional fallback grabbed ANY plot that had seeds in it, so a
        -- client whose own base failed to load would quietly start operating
        -- on a stranger's garden and look busy while accomplishing nothing.
        if anyOwned then return nil end
        for _,p in ipairs(plots:GetChildren()) do local s=p:FindFirstChild("Seeds") if s and #s:GetChildren()>0 then return p end end
    end
    -- published for the heartbeat: did OUR base actually load?
    task.spawn(function()
        while alive() do
            local plots = workspace:FindFirstChild("Plots")
            local owned = false
            if plots then
                for _,p in ipairs(plots:GetChildren()) do
                    if p:GetAttribute("Owner")==LocalPlayer.UserId then owned=true break end
                end
            end
            getgenv().PvBBaseOK = owned
            task.wait(4)
        end
    end)
    local function tilePos(t) return (t.CFrame * CFrame.new(0, t.Size.Y/2, 0)).Position end
    local function gatherTiles(freeOnly)
        local plot=myPlot(); if not plot then return {} end
        local out={}
        for _,d in ipairs(plot:GetDescendants()) do
            if d:IsA("BasePart") and d:GetAttribute("CanPlace")~=nil then
                if not freeOnly or (d:GetAttribute("CanPlace")==true and not d:GetAttribute("Occupied")) then
                    out[#out+1]={ tile=d, pos=tilePos(d) }
                end
            end
        end
        return out
    end
    local function tileSpacing(tiles)
        if #tiles<2 then return 6 end
        local d={}
        for i,a in ipairs(tiles) do
            local best for j,b in ipairs(tiles) do if i~=j then local dist=(a.pos-b.pos).Magnitude if not best or dist<best then best=dist end end end
            if best then d[#d+1]=best end
        end
        table.sort(d) return d[math.ceil(#d/2)] or 6
    end

    -- snap tiles to an integer grid so we can pack real 3x3 blocks
    local function buildGrid(allTiles)
        local sp = tileSpacing(allTiles); if sp<=0 then sp=6 end
        local x0,z0,ysum,yn = math.huge, math.huge, 0, 0
        for _,e in ipairs(allTiles) do
            if e.pos.X<x0 then x0=e.pos.X end
            if e.pos.Z<z0 then z0=e.pos.Z end
            ysum=ysum+e.pos.Y yn=yn+1
        end
        local yavg = yn>0 and ysum/yn or 0
        local map={}
        local function key(c,r) return c..","..r end
        local function cellOf(pos) return math.floor((pos.X-x0)/sp+0.5), math.floor((pos.Z-z0)/sp+0.5) end
        for _,e in ipairs(allTiles) do local c,r=cellOf(e.pos) map[key(c,r)]=e end
        local function cellPos(c,r) local e=map[key(c,r)] if e then return e.pos end return Vector3.new(x0+c*sp, yavg, z0+r*sp) end
        return { key=key, cellOf=cellOf, cellPos=cellPos }
    end

    -- pack free tiles into grid-aligned 3x3 blocks; each block's CENTER is the single water point
    local function planClusters(free, allTiles, want)
        local g = buildGrid(allTiles)
        local freeCells = {}
        for _,e in ipairs(free) do local c,r=g.cellOf(e.pos) e.col,e.row=c,r freeCells[g.key(c,r)]=e end
        local plant,centers,placed = {},{},0
        while placed<want do
            local bestCells,bestCenter,seen = nil,nil,{}
            for _,e in pairs(freeCells) do
                for dc=-1,1 do for dr=-1,1 do          -- try each free cell and its neighbors as a block center
                    local cc,cr = e.col+dc, e.row+dr
                    local ck = g.key(cc,cr)
                    if not seen[ck] then
                        seen[ck]=true
                        local cells={}
                        for ac=-1,1 do for ar=-1,1 do
                            local f=freeCells[g.key(cc+ac,cr+ar)]  -- only the 8 immediate neighbors + center
                            if f then cells[#cells+1]=f end
                        end end
                        if #cells>0 and (not bestCells or #cells>#bestCells) then bestCells,bestCenter=cells,{cc,cr} end
                    end
                end end
            end
            if not bestCenter then break end
            for _,f in ipairs(bestCells) do
                if placed>=want then break end
                if freeCells[g.key(f.col,f.row)] then
                    plant[#plant+1]=f freeCells[g.key(f.col,f.row)]=nil placed=placed+1
                end
            end
            centers[#centers+1] = { pos = g.cellPos(bestCenter[1], bestCenter[2]) }
        end
        return plant,centers,placed
    end

    -- matured, harvestable plants (tagged Plants/Plant, have ID) -> {id, inst}
    local function harvestable()
        local out,seen={},{}
        for _,tag in ipairs({"Plants","Plant"}) do
            for _,p in ipairs(CS:GetTagged(tag)) do
                local id=p:GetAttribute("ID"); local own=p:GetAttribute("Owner")
                if id and not seen[p] and (own==nil or own==LocalPlayer.UserId) then seen[p]=true out[#out+1]={id=id, inst=p} end
            end
        end
        return out
    end
    local function findToolById(id)
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("ID")==id then return t end end end
        end
    end
    local function sellPlantById(id)
        local tool=findToolById(id); if not tool then return end
        local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        hum:EquipTool(tool)
        local t=0 while tool.Parent~=char and t<0.6 do task.wait(0.03) t=t+0.03 end
        local sellFn = getgenv().PvBFireSell
        if sellFn then sellFn(true) else ItemSell:FireServer(true) end
    end
    -- premium water bucket preferred; plain "Water Bucket" as fallback so
    -- accounts without premium still water.
    local function findPremiumBucket()
        local function hay(t)
            return (tostring(t.Name or "").." "..tostring(t:GetAttribute("Gear") or "").." "
                ..tostring(t:GetAttribute("ToolName") or "").." "..tostring(t:GetAttribute("ItemName") or "")):lower()
        end
        local premium, plain
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then
                for _,t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") then
                        local h = hay(t)
                        if h:find("water") and (h:find("bucket") or h:find("premium")) then
                            if h:find("premium") then premium = premium or t
                            else plain = plain or t end
                        end
                    end
                end
            end
        end
        return premium or plain
    end
    local function equipBucket()
        local b=findPremiumBucket(); if not b then return nil end
        local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum and b.Parent~=char then pcall(function() hum:EquipTool(b) end) end
        return b
    end

    ------------------------------------------------------------------ state + round
    -- world position of a growing seed instance
    local function seedPos(s)
        if s:IsA("BasePart") then return s.Position end
        local ok,cf=pcall(function() return s:GetPivot() end)
        if ok and cf then return cf.Position end
        local pp=s:FindFirstChildWhichIsA("BasePart",true)
        return pp and pp.Position or nil
    end
    -- splash points from where seeds ACTUALLY are, so every seed is covered by some 3x3 center
    local function waterCentersFor(seedInsts, allTiles)
        local g=buildGrid(allTiles)
        local rem={}
        for _,s in ipairs(seedInsts) do local p=seedPos(s) if p then local c,r=g.cellOf(p) rem[#rem+1]={c=c,r=r} end end
        local centers={}
        while #rem>0 do
            local bestC,bestN,seen=nil,0,{}
            for _,u in ipairs(rem) do for dc=-1,1 do for dr=-1,1 do
                local cc,cr=u.c+dc,u.r+dr local k=cc..","..cr
                if not seen[k] then seen[k]=true
                    local n=0 for _,v in ipairs(rem) do if math.abs(v.c-cc)<=1 and math.abs(v.r-cr)<=1 then n=n+1 end end
                    if n>bestN then bestN=n bestC={cc,cr} end
                end
            end end end
            if not bestC then break end
            centers[#centers+1]={ pos=g.cellPos(bestC[1],bestC[2]) }
            local keep={} for _,v in ipairs(rem) do if not (math.abs(v.c-bestC[1])<=1 and math.abs(v.r-bestC[2])<=1) then keep[#keep+1]=v end end
            rem=keep
        end
        return centers
    end

    local cfg = { seed=nil, count=9, water=false, sell=false, loop=false, potions=false, waterFreq=2, fullGarden=false, capacity=40, harvest=true }
    local SAVE="PvBPlantTest.json"
    local function saveCfg()
        pcall(function()
            if writefile then
                writefile(SAVE, HttpService:JSONEncode({
                    waterFreq=cfg.waterFreq, capacity=cfg.capacity, fullGarden=cfg.fullGarden,
                    count=cfg.count, water=cfg.water, sell=cfg.sell, loop=cfg.loop, potions=cfg.potions,
                    harvest=cfg.harvest, plantCap=getgenv().PvBPlantCap,
                    seed=cfg.seed and { seedName=cfg.seed.seedName, colors=cfg.seed.colors, label=cfg.seed.label } or nil,
                }))
            end
        end)
    end
    pcall(function()
        if readfile and isfile and isfile(SAVE) then
            local d = HttpService:JSONDecode(readfile(SAVE))
            if type(d)=="table" then
                if tonumber(d.waterFreq) then cfg.waterFreq=tonumber(d.waterFreq) end
                if tonumber(d.capacity) then cfg.capacity=tonumber(d.capacity) end
                if tonumber(d.count) then cfg.count=tonumber(d.count) end
                if tonumber(d.plantCap) then getgenv().PvBPlantCap=tonumber(d.plantCap) end
                for _,k in ipairs({"fullGarden","water","sell","loop","potions","harvest"}) do
                    if type(d[k])=="boolean" then cfg[k]=d[k] end
                end
                if type(d.seed)=="table" and d.seed.seedName then cfg.seed=d.seed end
            end
        end
    end)
    local running=false
	local opDriven=false   -- true only when OP Plant Maker started this run
	local lastStop=nil     -- why the last run ended: "invfull" | "noseeds" | "manual"

    local UtilMod; pcall(function() UtilMod = require(RS:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("Util")) end)
-- garden capacity: 40 only with Gardening Expertise T3 SHINY equipped, else 35
    local PDg; pcall(function() PDg = require(RS:WaitForChild("PlayerData")) end)
    local function gardenCap()
        local ok,d = pcall(function() return PDg and PDg:GetDataAsync() end)
        if ok and d and type(d.Cards)=="table" and type(d.Cards.Equipped)=="table" and type(d.Cards.Inventory)=="table" then
            for _,guid in pairs(d.Cards.Equipped) do
                local e = guid and d.Cards.Inventory[guid]
                if e then
                    local t = tostring(e.Type):lower()
                    local tier = (type(e.Data)=="table" and tonumber(e.Data.Tier)) or 1
                    local shiny = (type(e.Data)=="table" and e.Data.Shiny==true)
                    if t:find("gardening") and tier>=3 and shiny then return 40 end
                end
            end
        end
        return 35
    end
    if getgenv().PvBPlantCap==nil then getgenv().PvBPlantCap=0 end
    if getgenv().PvBPlantCapUsed==nil then getgenv().PvBPlantCapUsed=0 end
    local function invFull()
        -- primary: same check the game uses (#Backpack children vs max space)
        local ok,mx = pcall(function() return UtilMod:GetMaxInventorySpace(LocalPlayer) end)
        if ok and type(mx)=="number" and #LocalPlayer.Backpack:GetChildren() >= mx then return true end
        -- fallback: the game's own "MaxInv" indicator flag it maintains client-side
        local ok2,vis = pcall(function() return LocalPlayer.PlayerGui.RenderedStatUserInterfaces.MaxInv.Visible end)
        return (ok2 and vis)==true
    end
    -- "near full" for STAGE decisions: the Keep tab's junk-selling keeps freeing
    -- slots, so the bag hovers just under max and a strict invFull() flickers.
    local function invNearFull(slack)
        local ok,mx = pcall(function() return UtilMod:GetMaxInventorySpace(LocalPlayer) end)
        if ok and type(mx)=="number" then return #LocalPlayer.Backpack:GetChildren() >= (mx - (slack or 3)) end
        return invFull()
    end

    local setRunning

    local function waterCenters(centers)
        for _,c in ipairs(centers or {}) do
            if not running then break end
            local b = equipBucket()
            if b then
                pcall(function()
                    UseItem:FireServer({ Toggle=true, Tool=b, Pos=c.pos })
                end)
            end
            task.wait(0.55)
        end
    end


    local PDp; pcall(function() PDp = require(RS:WaitForChild("PlayerData")) end)
    local POTION_SPECS = {
        { label="Witch Potion", keys={"witch"} },
        { label="Size Potion",  keys={"size"}  },
    }
    local function normPotionName(v)
        return tostring(v or ""):lower():gsub("[^%a%d]","")
    end
    local function findGearByName(keys)
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then
                for _,t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") then
                        local hay = normPotionName(table.concat({
                            t.Name,
                            tostring(t:GetAttribute("Gear") or ""),
                            tostring(t:GetAttribute("ToolName") or ""),
                            tostring(t:GetAttribute("ItemName") or ""),
                        }, " "))
                        for _,k in ipairs(keys) do
                            if hay:find(normPotionName(k),1,true) then return t end
                        end
                    end
                end
            end
        end
    end
    local function potionActive(keys)
        if not PDp then return false end
        local ok,d=pcall(function() return PDp:GetData().Data end)
        local pots=ok and d and d.Potions
        if type(pots)~="table" then return false end
        for name,v in pairs(pots) do
            if v~=nil and v~=false then
                local n=normPotionName(name)
                for _,k in ipairs(keys) do
                    if n:find(normPotionName(k),1,true) then return true end
                end
            end
        end
        return false
    end
    local function drinkPotion(spec)
        if potionActive(spec.keys) then return true,"active" end
        local tool=findGearByName(spec.keys)
        if not tool then return false,"missing" end
        local char=LocalPlayer.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum and tool.Parent~=char then
            pcall(function() hum:EquipTool(tool) end)
            local t0=os.clock()
            while tool.Parent~=char and os.clock()-t0<0.6 do task.wait(0.03) end
        end
        local pos
        pcall(function() pos=(char and char:GetPivot().Position) end)
        pos = pos or Vector3.new()
        pcall(function() UseItem:FireServer({ Toggle=true, Tool=tool, Pos=pos }) end)
        task.wait(0.35)
        pcall(function()
            local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h:UnequipTools() end
        end)
        return potionActive(spec.keys),"fire sent"
    end
    local function ensurePotions()
        if not cfg.potions then return end
        local missing={}
        for _,spec in ipairs(POTION_SPECS) do
            local ok,state=drinkPotion(spec)
            if not ok and state~="active" then missing[#missing+1]=spec.label.." "..tostring(state) end
        end
        if #missing>0 then setStatus("potions: "..table.concat(missing, ", ")) end
    end

    local function roundOnce()
        if not cfg.seed then setStatus("pick a seed"); return "stop" end
        ensurePotions()
        local plot=myPlot(); if not plot then setStatus("no plot found"); return "stop" end
        local sf=plot:FindFirstChild("Seeds")
        local allTiles=gatherTiles(false); if #allTiles==0 then setStatus("no tiles"); return "stop" end
        local free=gatherTiles(true); if #free==0 then setStatus("no free tiles"); return "retry" end
        local want = cfg.count
        if cfg.fullGarden then
            local gcap = gardenCap()
            local occupied = #allTiles - #free
            want = math.max(0, gcap - occupied)
            if want<=0 then setStatus(("garden full (%d/%d)"):format(occupied, gcap)); return "retry" end
        end
        -- plant cap: never plant past the session ceiling (leaderboard safety)
        local pcap = tonumber(getgenv().PvBPlantCap) or 0
        if pcap > 0 then
            local used = tonumber(getgenv().PvBPlantCapUsed) or 0
            if used >= pcap then setStatus(("plant cap reached (%d/%d)"):format(used, pcap)); lastStop="plant cap"; return "stop" end
            want = math.min(want, pcap - used)
        end
        local plant,centers,placed=planClusters(free, allTiles, want)
        if placed==0 then setStatus("nothing to plant"); return "retry" end

        local preSeeds={} if sf then for _,s in ipairs(sf:GetChildren()) do preSeeds[s]=true end end
        local preHarv={} for _,e in ipairs(harvestable()) do preHarv[e.id]=true end

        -- plant
        setStatus(("planting %d..."):format(placed))
        for _,e in ipairs(plant) do
            if not running then return "stop" end
            PlantSeed:FireServer(cfg.seed.seedName, cfg.seed.colors, e.pos)
            getgenv().PvBPlantCapUsed = (tonumber(getgenv().PvBPlantCapUsed) or 0) + 1
            task.wait(0.1)
        end

        -- collect my new growing seeds (under Plots[x].Seeds). Fast crops can mature before
        -- they stay in Seeds long enough, so matured plants also count toward detection.
        local myseeds,t = {},0
        while t<6 do
            task.wait(0.3) t=t+0.3
            myseeds={}
            if sf then for _,s in ipairs(sf:GetChildren()) do if not preSeeds[s] then myseeds[#myseeds+1]=s end end end
            local mat=0
            for _,e in ipairs(harvestable()) do if not preHarv[e.id] then mat=mat+1 end end
            setStatus(("growing %d/%d detected"):format(#myseeds+mat, placed))
            if #myseeds+mat>=placed then break end
        end
        local matNow=0
        for _,e in ipairs(harvestable()) do if not preHarv[e.id] then matNow=matNow+1 end end
        if #myseeds==0 and matNow==0 then setStatus("0 growing seeds - HALT"); lastStop="noseeds"; return "stop" end

        if cfg.water and not equipBucket() then setStatus("no water bucket (premium or plain) - unwatered") end

        -- GROW: wait on live CompletionTime (server clock), splash planned cluster centers if watering.
        -- Only seeds with a FUTURE completion time count as growing. A matured seed clears its
        -- CompletionTime (or leaves Plots.Seeds); the old "not ct => still growing" check could
        -- keep long-grow plants watering forever. Also stop once the batch is harvestable.
        local hardStop = os.clock() + (growTimeFor(cfg.seed.seedName) or 300) + 30
        local lastWater, sawGrowth = 0, false
        while running and alive() do
            local now=serverNow(); local remaining,growing = 0,0
            for _,s in ipairs(myseeds) do
                if s.Parent then
                    local ct=tonumber(s:GetAttribute("CompletionTime"))
                    if ct and ct>now then growing=growing+1 remaining=math.max(remaining, ct-now) end
                end
            end
            if growing>0 then sawGrowth=true end
            local matured=0
            for _,e in ipairs(harvestable()) do if not preHarv[e.id] then matured=matured+1 end end
            if (sawGrowth and growing==0) or matured>=placed or os.clock()>hardStop then break end
            if cfg.water and (os.clock()-lastWater)>=math.max(cfg.waterFreq,0.1) then
                waterCenters(centers)
                lastWater=os.clock()
            end
            setStatus(("growing %d, ready %d/%d, ~%ds"):format(growing, matured, placed, math.ceil(remaining)))
            task.wait(0.3)
        end
        if (not running) or (not alive()) then return "stop" end
        if cfg.harvest==false then setStatus(("grown %d - left in garden"):format(placed)) return "ok" end

        -- HARVEST matured plants (new Plants-tagged IDs), then optional sell
        setStatus("harvesting")
        local hset,hcount = {},0
        local roundPlants,known = {},{}
        local function addRoundPlants()
            for _,e in ipairs(harvestable()) do
                if not preHarv[e.id] and not known[e.id] then
                    known[e.id]=true
                    roundPlants[#roundPlants+1]=e
                end
            end
        end
        local waitNew, lastN, lastChange = 0, 0, os.clock()
        local stuckRounds, lastStuck = 0, nil    -- harvest progress watchdog
        while running and alive() and #roundPlants<placed and waitNew<8 do
            addRoundPlants()
            if #roundPlants~=lastN then lastN=#roundPlants lastChange=os.clock() end
            if #roundPlants>=placed then break end
            if #roundPlants>0 and os.clock()-lastChange>1.5 then break end
            task.wait(0.3)
            waitNew=waitNew+0.3
        end
        while running and alive() do
            addRoundPlants()
            local remaining=0
            for _,e in ipairs(roundPlants) do
                if not hset[e.id] then
                    if (not e.inst) or (not e.inst.Parent) or findToolById(e.id) then
                        hset[e.id]=true
                        hcount=hcount+1
                    else
                        remaining=remaining+1
                        Pickup:FireServer(e.id)
                        task.wait(0.12)
                    end
                end
            end
            if remaining==0 then break end
            task.wait(0.6)                               -- most pickups land within a beat; recheck before camping
            local still=0
            for _,e in ipairs(roundPlants) do
                if not hset[e.id] and e.inst and e.inst.Parent and not findToolById(e.id) then still=still+1 end
            end
            if still>0 then
                if opDriven and invFull() then
                    setStatus("inventory full - stopped")   -- OP Maker reads this as stage complete
                    lastStop="invfull"
                    return "stop"
                end
                -- progress watchdog: invFull() flickers because the Keep tab
                -- keeps freeing slots, so a strict check alone used to leave
                -- this retrying the same blocked pickups forever.
                if still >= (lastStuck or math.huge) then
                    stuckRounds = stuckRounds + 1
                else
                    stuckRounds = 0
                end
                lastStuck = still
                if stuckRounds >= 3 then
                    setStatus(("harvesting blocked: %d stuck, bag full - moving on"):format(still))
                    lastStop="invfull"          -- OP Maker advances to upsize/submit
                    return "stop"
                end
                setStatus(("harvesting: %d stuck (inventory full?) - retry %d/3"):format(still, stuckRounds+1))
                for _=1,24 do
                    if not (running and alive()) then break end
                    task.wait(0.1)
                end
            end
        end
        if cfg.sell and hcount>0 then task.spawn(function()
            task.wait(0.5)                       -- let pickups finish replicating into the bag
            local function sellablePlantCount()
                local favs={}
                pcall(function() favs=(PDp and PDp:GetData().Data.Favorites) or {} end)
                local n=0
                for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
                    if c then for _,t in ipairs(c:GetChildren()) do
                        if t:IsA("Tool") and t:GetAttribute("PlantName") then
                            local id=t:GetAttribute("ID")
                            if id and not favs[id] then n=n+1 end
                        end
                    end end
                end
                return n
            end
            for _=1,3 do
                local before=sellablePlantCount()
                if before<=0 then break end
                local sellFn = getgenv().PvBFireSell
                if sellFn then sellFn(nil, true) else ItemSell:FireServer(nil, true) end       -- game's own "sell my plants" call; hearted plants are protected
                local t0=os.clock()
                while sellablePlantCount()>=before and os.clock()-t0<2 do task.wait(0.2) end
                if sellablePlantCount()<=0 then break end
            end
        end) end
        setStatus(("round done: %d planted, %d harvested"):format(placed, hcount))
        return "ok"
    end

    local function loopFn()
        while running and alive() do
            if opDriven and invFull() then setRunning(false) setStatus("inventory full - stopped") lastStop="invfull" break end
            local r=roundOnce()
            if not running then break end
            if r=="stop" then setRunning(false) break end
            if not cfg.loop then setRunning(false) break end
            task.wait(r=="ok" and 0.1 or 1.5)
        end
    end

    ------------------------------------------------------------------ UI (toolkit-native)
    local function mkBox(parent, size, pos, text)
        local box=Instance.new("TextBox")
        box.Size=size; box.Position=pos; box.BackgroundColor3=C.field; box.TextColor3=C.txt; box.Text=text
        box.Font=Enum.Font.GothamMedium; box.TextSize=13; box.TextXAlignment=Enum.TextXAlignment.Center
        box.BorderSizePixel=0; box.ClearTextOnFocus=false; box.Parent=parent; corner(box,6)
        return box
    end

    local y=0
    local seedBtn = mkButton(plantTab,"  Pick a seed",C.panel,UDim2.new(1,-88,0,30),UDim2.fromOffset(0,y))
    seedBtn.TextXAlignment=Enum.TextXAlignment.Left
    if cfg.seed then seedBtn.Text="  "..(cfg.seed.label or cfg.seed.seedName) end
    local qtyBox = mkBox(plantTab,UDim2.fromOffset(80,30),UDim2.new(1,-80,0,y),tostring(cfg.count))
    qtyBox:GetPropertyChangedSignal("Text"):Connect(function() local n=tonumber(qtyBox.Text) if n then cfg.count=math.clamp(math.floor(n),1,63) saveCfg() end end)
    y=y+38

    local fullBtn = mkButton(plantTab,"",C.row,UDim2.new(0.5,-3,0,28),UDim2.fromOffset(0,y))
    local harvBtn = mkButton(plantTab,"",C.row,UDim2.new(0.5,-3,0,28),UDim2.new(0.5,3,0,y))
    local sellBtn
    local loopBtn   -- forward-declared: harvest OFF must also switch Loop off
    local function rfQty()
        fullBtn.Text = cfg.fullGarden and "Qty: Fill garden" or "Qty: Use box"
        fullBtn.BackgroundColor3 = cfg.fullGarden and C.green or C.row
        qtyBox.TextTransparency = cfg.fullGarden and 0.55 or 0
        harvBtn.Text = "Harvest: "..(cfg.harvest and "ON" or "OFF")
        harvBtn.BackgroundColor3 = cfg.harvest and C.green or C.row
        if sellBtn then
            sellBtn.BackgroundColor3 = (cfg.harvest and cfg.sell) and C.green or C.row
            sellBtn.TextTransparency = cfg.harvest and 0 or 0.55
        end
    end
    fullBtn.MouseButton1Click:Connect(function() cfg.fullGarden=not cfg.fullGarden saveCfg() rfQty() end)
    harvBtn.MouseButton1Click:Connect(function()
        cfg.harvest=not cfg.harvest
        if not cfg.harvest then
            cfg.sell=false                            -- can't sell what you don't pick up
            cfg.loop=false                            -- can't loop without harvesting
            if loopBtn then loopBtn.BackgroundColor3=C.row end
        end
        saveCfg() rfQty()
    end)
    rfQty()
    if cfg.seed then seedBtn.Text="  "..(cfg.seed.label or cfg.seed.seedName) end
    qtyBox.Text=tostring(cfg.count)
    y=y+34

    local function toggle(text,pos,size,get,set)
        local b=mkButton(plantTab,text,get() and C.green or C.row,size,pos) b.TextSize=11
        b.MouseButton1Click:Connect(function() set(not get()) b.BackgroundColor3=get() and C.green or C.row end)
        return b
    end
    toggle("Water while growing",UDim2.fromOffset(0,y),UDim2.new(0.5,-3,0,28),function() return cfg.water end,function(v) cfg.water=v saveCfg() end)
    sellBtn = toggle("Sell after harvest",UDim2.new(0.5,3,0,y),UDim2.new(0.5,-3,0,28),
        function() return cfg.harvest and cfg.sell end,
        function(v) if not cfg.harvest then setStatus("enable Harvest first") return end cfg.sell=v saveCfg() end)
    rfQty()
    y=y+34
    toggle("Auto potions (Witch + Size)",UDim2.fromOffset(0,y),UDim2.new(1,0,0,28),function() return cfg.potions end,function(v) cfg.potions=v saveCfg() end)
    y=y+34
    loopBtn = toggle("Loop",UDim2.fromOffset(0,y),UDim2.new(0.34,-3,0,28),function() return cfg.loop end,function(v)
        cfg.loop=v
        if v and not cfg.harvest then cfg.harvest=true rfQty() end   -- looping requires harvesting
        saveCfg()
    end)
    local wfLbl=mkLabel(plantTab,"Water every (s)",UDim2.new(0.66,-74,0,28),UDim2.new(0.34,4,0,y),C.dim,Enum.Font.Gotham,11)
    wfLbl.TextXAlignment=Enum.TextXAlignment.Right
    local wfBox = mkBox(plantTab,UDim2.fromOffset(62,28),UDim2.new(1,-62,0,y),tostring(cfg.waterFreq))
    wfBox:GetPropertyChangedSignal("Text"):Connect(function() local n=tonumber(wfBox.Text) if n and n>=0 then cfg.waterFreq=n saveCfg() end end)
    y=y+34

    local pcLbl=mkLabel(plantTab,"Plant cap (blank = off)",UDim2.new(0.45,0,0,28),UDim2.fromOffset(0,y),C.dim,Enum.Font.Gotham,11)
    local pcCap0 = tonumber(getgenv().PvBPlantCap) or 0
    local pcBox = mkBox(plantTab,UDim2.fromOffset(62,28),UDim2.new(1,-62,0,y), pcCap0>0 and tostring(pcCap0) or "")
    pcBox.PlaceholderText="off"
    pcBox.PlaceholderColor3=C.dim
    local pcUsed=mkLabel(plantTab,"",UDim2.new(0.3,-8,0,28),UDim2.new(0.46,0,0,y),C.dim,Enum.Font.Gotham,11)
    pcUsed.TextXAlignment=Enum.TextXAlignment.Right
    local function rfCap()
        local cap=tonumber(getgenv().PvBPlantCap) or 0
        pcUsed.Text = cap>0 and (tostring(getgenv().PvBPlantCapUsed or 0).."/"..cap) or ""
    end
    pcBox.FocusLost:Connect(function()
        local txt = pcBox.Text:gsub("%s","")
        local n = (txt=="") and 0 or tonumber(txt)   -- clearing the box turns the cap OFF
        if n and n>=0 then
            getgenv().PvBPlantCap=math.floor(n)
            getgenv().PvBPlantCapUsed=0          -- editing the cap resets the planted counter
            saveCfg()
        end
        local cap = tonumber(getgenv().PvBPlantCap) or 0
        pcBox.Text = cap>0 and tostring(cap) or ""
        rfCap()
    end)
    task.spawn(function() while alive() do rfCap() task.wait(1) end end)
    y=y+38

    local startBtn = mkButton(plantTab,"Start",C.green,UDim2.new(1,0,0,34),UDim2.fromOffset(0,y))
    startBtn.Font=Enum.Font.GothamBold; startBtn.TextSize=14
    setRunning = function(v) running=v startBtn.Text=v and "Stop" or "Start" startBtn.BackgroundColor3=v and C.red or C.green end
    startBtn.MouseButton1Click:Connect(function()
        if running then setRunning(false) lastStop="manual" setStatus("stopped")
        elseif not cfg.seed then setStatus("pick a seed first")
        else opDriven=false setRunning(true) task.spawn(loopFn) end

    end)

    getgenv().PvBPlantAPI = {
        start     = function(ignoreInvGate) if running or not cfg.seed then return false end opDriven=not ignoreInvGate lastStop=nil setRunning(true) task.spawn(loopFn) return true end,
        stop      = function() if running then setRunning(false) lastStop="manual" end end,
        lastStop  = function() return lastStop end,
        -- Empty the garden completely: first grow out anything still in the
        -- ground - watering the SAME 3x3-cluster centres the normal run uses,
        -- computed from where the seeds actually are - then pick every matured
        -- plant up. Used by the OP Plant Maker at the top of each planting
        -- cycle so it never plants into a half-full garden.
        clearGarden = function(say, keepGoing)
            say = say or setStatus
            local t0 = os.clock()
            local lastCount, lastEta, stalledFor = nil, nil, 0
            while alive() and os.clock()-t0 < 240 do
                if keepGoing and not keepGoing() then           -- OP toggled off mid-clear
                    say("clearing garden: aborted")
                    return 0
                end
                local plot = myPlot()
                local sf   = plot and plot:FindFirstChild("Seeds")
                local now  = serverNow()
                local growing = {}
                local eta = 0
                if sf then
                    for _,s in ipairs(sf:GetChildren()) do
                        local ct = tonumber(s:GetAttribute("CompletionTime"))
                        if ct and ct > now then
                            growing[#growing+1] = s
                            if (ct-now) > eta then eta = ct-now end
                        end
                    end
                end
                if #growing == 0 then break end
                -- Progress watchdog. If neither the number of growing plants
                -- nor the longest remaining time has moved for ~45s, watering
                -- is not achieving anything (no bucket charge, or a long-grow
                -- crop like Troll Mango). Stop waiting and pick up what IS
                -- ready rather than sitting here until the 4-minute cap.
                if lastCount and #growing >= lastCount and lastEta and eta >= (lastEta - 1) then
                    stalledFor = stalledFor + math.max(tonumber(cfg.waterFreq) or 2, 0.5)
                else
                    stalledFor = 0
                end
                lastCount, lastEta = #growing, eta
                if stalledFor >= 45 then
                    say(("clearing garden: %d not maturing (~%ds left) - moving on"):format(#growing, math.ceil(eta)))
                    break
                end
                -- ALWAYS water here, regardless of the "Water while growing"
                -- toggle: the whole point of clearing is to finish these plants
                -- off fast, and without watering this just sat and counted.
                -- waterCenters equips the bucket itself (premium or plain).
                if equipBucket() then
                    say(("clearing garden: watering %d growing"):format(#growing))
                    waterCenters(waterCentersFor(growing, gatherTiles(false)))
                else
                    say(("clearing garden: %d growing (no water bucket)"):format(#growing))
                end
                task.wait(math.max(tonumber(cfg.waterFreq) or 2, 0.5))
            end
            local picked = 0
            for _ = 1, 6 do
                local left = harvestable()
                if #left == 0 then break end
                for _,e in ipairs(left) do
                    if not alive() then return picked end
                    Pickup:FireServer(e.id)
                    picked = picked + 1
                    task.wait(0.12)
                end
                task.wait(0.6)
            end
            say(("garden cleared: %d picked up"):format(picked))
            return picked
        end,
        invNearFull = invNearFull,
        serverNow   = serverNow,
        equipBucket = equipBucket,
        -- splash the equipped bucket at a world position (used by the cycle's
        -- troll-straggler wait, which previously called Plant-tab locals it
        -- could not see and silently did nothing)
        waterAt     = function(pos)
            local b = equipBucket()
            if not (b and pos) then return false end
            return (pcall(function() UseItem:FireServer({Toggle=true, Tool=b, Pos=pos}) end))
        end,
        isRunning = function() return running end,
        seedName  = function() return cfg.seed and cfg.seed.seedName or nil end,
        setLoop   = function(v) cfg.loop=v end,
        setSell   = function(v) cfg.sell=v end,
        setWater  = function(v) cfg.water=v end,
        setHarvest= function(v) cfg.harvest=v end,
        setFull   = function(v) cfg.fullGarden=v end,
        setCount  = function(v) local x=tonumber(v) if x then cfg.count=math.clamp(math.floor(x),1,63) end end,
        setSeed   = function(name)
            for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
                if c then for _,t in ipairs(c:GetChildren()) do
                    local sn=t:IsA("Tool") and t:GetAttribute("SeedName")
                    if sn and (sn==name or sn:lower():find(name:lower(),1,true)) then
                        cfg.seed={ label=t.Name, seedName=sn, colors=t:GetAttribute("Colors") }
                        seedBtn.Text="  "..(cfg.seed.label or sn) saveCfg()
                        return true
                    end
                end end
            end
            return false
        end,
        garden    = function()
            -- identity from every source at once: model name, replica record, string attrs
            local plants={} pcall(function() plants=PDp:GetData().Data.Plants or {} end)
            local out={}
            for _,e in ipairs(harvestable()) do
                local bits={ (e.inst and e.inst.Name) or "" }
                local rec=plants[e.id]
                if rec==nil and e.id~=nil then rec=plants[tostring(e.id)] end
                if type(rec)=="table" and rec.PlantName then bits[#bits+1]=tostring(rec.PlantName) end
                if e.inst then
                    local ok,attrs=pcall(function() return e.inst:GetAttributes() end)
                    if ok and type(attrs)=="table" then
                        for _,v in pairs(attrs) do if type(v)=="string" then bits[#bits+1]=v end end
                    end
                end
                out[#out+1]={ id=e.id, name=table.concat(bits," | ") }
            end
            return out
        end,
        invFull   = invFull,
    }


    local panel = Instance.new("Frame")
    panel.Visible=false; panel.Size=UDim2.fromOffset(300,200); panel.Position=UDim2.fromOffset(0,58)
    panel.BackgroundColor3=C.panel; panel.BorderSizePixel=0; panel.ZIndex=10; panel.Parent=plantTab; corner(panel,8)
    do local s=Instance.new("UIStroke",panel) s.Color=C.stroke s.Transparency=0.3 end

    local search = Instance.new("TextBox")
    search.Size=UDim2.new(1,-16,0,26); search.Position=UDim2.fromOffset(8,8); search.BackgroundColor3=C.field
    search.TextColor3=C.txt; search.PlaceholderText="search seeds..."; search.Text=""; search.Font=Enum.Font.Gotham
    search.TextSize=12; search.BorderSizePixel=0; search.ClearTextOnFocus=false; search.ZIndex=11; search.Parent=panel; corner(search,6)

    local listF = Instance.new("ScrollingFrame")
    listF.Active=true; listF.Size=UDim2.new(1,-16,1,-44); listF.Position=UDim2.fromOffset(8,40)
    listF.BackgroundTransparency=1; listF.BorderSizePixel=0; listF.ScrollBarThickness=4; listF.ZIndex=11; listF.Parent=panel
    local ll = Instance.new("UIListLayout", listF) ll.Padding=UDim.new(0,3) ll.SortOrder=Enum.SortOrder.LayoutOrder
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() listF.CanvasSize=UDim2.fromOffset(0, ll.AbsoluteContentSize.Y+4) end)

    local function listSeeds()
        local out={}
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do local sn=t:IsA("Tool") and t:GetAttribute("SeedName") if sn then out[#out+1]={ label=t.Name, seedName=sn, colors=t:GetAttribute("Colors") } end end end
        end
        table.sort(out, function(a,b) return a.label:lower()<b.label:lower() end)
        return out
    end
    local function rebuildList()
        for _,ch in ipairs(listF:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
        local q=search.Text:lower()
        for _,s in ipairs(listSeeds()) do
            if q=="" or s.label:lower():find(q,1,true) then
                local b=mkButton(listF,"  "..s.label,C.row,UDim2.new(1,0,0,26),UDim2.new())
                b.TextXAlignment=Enum.TextXAlignment.Left; b.ZIndex=11; corner(b,5)
                b.MouseButton1Click:Connect(function() cfg.seed=s seedBtn.Text="  "..s.label panel.Visible=false saveCfg() end)
            end
        end
    end
    search:GetPropertyChangedSignal("Text"):Connect(rebuildList)
    seedBtn.MouseButton1Click:Connect(function() panel.Visible=not panel.Visible if panel.Visible then search.Text="" rebuildList() end end)

    setStatus("Plant ready - pick a seed, set qty, Start")
end

----------------------------------------------------------------------
--  EVENTS + MISC TABS
--  Events: Tornado/Ascended behind a segmented switch, plus Investment.
--  Misc: AFK (fishing + auto-click), Cards, Potions, Quality of life,
--  Each tab scrolls on its own.
----------------------------------------------------------------------
do
    ------------------------------------------------------------------
    -- Scroll wrappers: one per tab. miscTab is shadowed inside this
    -- do-block so the section builders parent into the right canvas.
    ------------------------------------------------------------------
    local function mkScrollTab(outer, canvasH)
        outer.ClipsDescendants = true
        local sc = Instance.new("ScrollingFrame")
        sc.BackgroundTransparency=1; sc.BorderSizePixel=0
        sc.Size=UDim2.new(1,0,1,0); sc.Position=UDim2.new()
        sc.ScrollBarThickness=6
        sc.ScrollingDirection=Enum.ScrollingDirection.Y
        sc.CanvasSize=UDim2.fromOffset(0,canvasH)
        sc.AutomaticCanvasSize=Enum.AutomaticSize.Y
        sc.Parent=outer
        -- content sits in an inner frame 12px narrower than the scroll area so
        -- the 6px scrollbar gets its own lane: button / gap / bar / border.
        local inner=Instance.new("Frame")
        inner.Name="Content"; inner.BackgroundTransparency=1
        inner.Size=UDim2.new(1,-12,0,canvasH); inner.Position=UDim2.new()
        inner.Parent=sc
        local spacer=Instance.new("Frame"); spacer.Name="BottomSpacer"
        spacer.BackgroundTransparency=1
        spacer.Size=UDim2.new(1,0,0,18); spacer.Position=UDim2.fromOffset(0,canvasH-18)
        spacer.Parent=sc
        return inner
    end
    local eventsC = mkScrollTab(eventsTab, 610)
    local miscC   = mkScrollTab(miscTab, 1360)
    local miscTab = miscC     -- default host: the section builders below target Misc

    local MISC_SAVE="PvBToolkit_misc.json"
    -- merge-on-save: 12 clients share this file, so read what's there and
    -- overlay our fields instead of blind-overwriting. An older instance or
    -- a client that failed a read can no longer erase everyone else's settings.
    -- WHAT THIS CLIENT READ AT STARTUP.
    --
    -- PvBToolkit_misc.json is shared by all 12 clients, and getgenv() survives
    -- a reload, so on "Reload ALL" every client restarts within ~2 seconds
    -- still holding its OWN stale settings. The old saveMisc wrote every key
    -- it had, so whichever client happened to save last overwrote the change
    -- you had just made on one client. That is why a new OP mutation or new
    -- fishing numbers came back as they were.
    --
    -- Fix: a client only writes a key it actually CHANGED (current value
    -- differs from what it loaded), or a key the file does not have yet.
    -- A client that never touched the OP mutation can no longer clobber it.
    local miscLoaded = {}
    local miscReady  = false

    local function saveMisc()
        pcall(function()
            if writefile then
                local merged = {}
                pcall(function()
                    if readfile and isfile and isfile(MISC_SAVE) then
                        local ex = HttpService:JSONDecode(readfile(MISC_SAVE))
                        if type(ex)=="table" then merged = ex end
                    end
                end)
                local mine = ({
                    fishGap=getgenv().PvBFishGap,
                    fishMax=getgenv().PvBFishSellEvery,
                    fishWait=getgenv().PvBFishSellWait,
                    idleAuto=getgenv().PvBIdleAuto,
                    idleFish=getgenv().PvBIdleFish,
                    subMut=getgenv().PvBSubMut,
                    clickFreq=getgenv().PvBClickFreq,
                    clickSafe=getgenv().PvBClickSafe,
                    clickX=getgenv().PvBClickX,
                    clickY=getgenv().PvBClickY,
                    idleDelay=getgenv().PvBIdleDelay,
                    opMut=getgenv().PvBOPMut,
                    opRun=getgenv().PvBOPRun,
                    opSeedTarget=getgenv().PvBOPSeedTarget,
                    eventSide=getgenv().PvBEventSide,
                    perfMode=getgenv().PvBPerfMode,
                    perfFps=getgenv().PvBPerfFps,
                    pvb3d=getgenv().PvB3DOn,
                    wheel=getgenv().PvBWheelSpin,
                    -- If OP Plant Maker turned fishing on for a refill, that is a
                    -- transient machine state, not a user setting. This file is
                    -- shared by all 12 clients, so persisting it armed fishing on
                    -- every client that reloaded afterwards - which is how a client
                    -- ended up fishing and submitting at the same time.
                    autoFish=(getgenv().PvBFishByOP and false or getgenv().PvBAutoFish),
                    autoClick=getgenv().PvBAutoClick,
                    perfPurge=getgenv().PvBPerfPurge,
                })
                for k, v in pairs(mine) do
                    if not miscReady then
                        -- load has not run yet: only seed keys nobody has set
                        if merged[k] == nil then merged[k] = v end
                    elseif merged[k] == nil then
                        merged[k] = v                     -- file lacks it entirely
                    elseif v ~= miscLoaded[k] then
                        merged[k] = v                     -- WE changed it: assert it
                        miscLoaded[k] = v                 -- new baseline
                    end
                    -- otherwise leave whatever is in the file alone: another
                    -- client may have just changed it and we must not undo that
                end
                writefile(MISC_SAVE, HttpService:JSONEncode(merged))
            end
        end)
    end
    pcall(function()
        if readfile and isfile and isfile(MISC_SAVE) then
            local d
            for attempt = 1, 3 do          -- shared file: another client may be mid-write
                local ok = pcall(function() d = HttpService:JSONDecode(readfile(MISC_SAVE)) end)
                if ok and type(d)=="table" then break end
                d = nil
                task.wait(0.25)
            end
            if type(d)=="table" then
                -- remember exactly what we read, so saveMisc can tell the
                -- difference between "this client changed it" and "this client
                -- is just holding a stale copy from before the reload"
                for k, v in pairs(d) do miscLoaded[k] = v end
                if tonumber(d.fishGap) then getgenv().PvBFishGap=tonumber(d.fishGap) end
                if tonumber(d.fishMax) then getgenv().PvBFishSellEvery=tonumber(d.fishMax) end
                if tonumber(d.fishWait) then getgenv().PvBFishSellWait=tonumber(d.fishWait) end
                if type(d.idleAuto)=="boolean" then getgenv().PvBIdleAuto=d.idleAuto end
                if type(d.idleFish)=="boolean" then getgenv().PvBIdleFish=d.idleFish end
                if type(d.subMut)=="string" then getgenv().PvBSubMut=d.subMut end
                if tonumber(d.clickFreq) then getgenv().PvBClickFreq=tonumber(d.clickFreq) end
                if type(d.clickSafe)=="boolean" then getgenv().PvBClickSafe=d.clickSafe end
                if tonumber(d.clickX) then getgenv().PvBClickX=tonumber(d.clickX) end
                if tonumber(d.clickY) then getgenv().PvBClickY=tonumber(d.clickY) end
                if tonumber(d.idleDelay) then getgenv().PvBIdleDelay=tonumber(d.idleDelay) end
                if type(d.opMut)=="string" then getgenv().PvBOPMut=d.opMut end
                if type(d.opRun)=="boolean" then getgenv().PvBOPRun=d.opRun end
                if tonumber(d.opSeedTarget) then getgenv().PvBOPSeedTarget=tonumber(d.opSeedTarget) end
                if type(d.eventSide)=="string" then getgenv().PvBEventSide=d.eventSide end
                if type(d.perfMode)=="boolean" then getgenv().PvBPerfMode=d.perfMode end
                if tonumber(d.perfFps) then getgenv().PvBPerfFps=tonumber(d.perfFps) end
                if type(d.pvb3d)=="boolean" then getgenv().PvB3DOn=d.pvb3d end
                if type(d.wheel)=="boolean" then getgenv().PvBWheelSpin=d.wheel end
                if type(d.autoFish)=="boolean" then getgenv().PvBAutoFish=d.autoFish end
                if type(d.autoClick)=="boolean" then getgenv().PvBAutoClick=d.autoClick end
                if type(d.perfPurge)=="boolean" then getgenv().PvBPerfPurge=d.perfPurge end
            end
        end
    end)
    -- From here on, saveMisc can tell a real change from a stale carry-over
    miscReady = true
    -- Main account never re-arms an unattended grind from saved state.
    if getgenv().PvBIsMain then
        getgenv().PvBOPRun   = false     -- OP Plant Maker stays off
        getgenv().PvBIdleFish = false    -- no fishing when AFK
        getgenv().PvBAutoFish = false
    end

    local TheWheelSpin
    pcall(function()
        TheWheelSpin = RS:WaitForChild("Remotes"):WaitForChild("Cards"):WaitForChild("TheWheelSpin")
    end)

    -- is The Wheel card in the equipped deck? (Data.Cards.Equipped -> Inventory[guid].Type)
    local PDw
    pcall(function()
        PDw = require(RS:WaitForChild("PlayerData"))
    end)

    local function wheelEquipped()
        local ok2,d = pcall(function()
            return PDw and PDw:GetDataAsync()
        end)

        if ok2 and d and type(d.Cards)=="table" and type(d.Cards.Equipped)=="table" and type(d.Cards.Inventory)=="table" then
            for _,guid in pairs(d.Cards.Equipped) do
                local e = guid and d.Cards.Inventory[guid]
                if e and tostring(e.Type):lower():gsub("[^%a%d]","")=="thewheel" then
                    return true
                end
            end
        end

        return false
    end

    -- section headers: bold title + hairline divider, groups related controls
    local function mkSection(parent,text,y)
        mkLabel(parent,text,UDim2.new(1,0,0,16),UDim2.fromOffset(0,y),C.txt,Enum.Font.GothamBold,13)
        local ln=Instance.new("Frame")
        ln.BackgroundColor3=C.stroke; ln.BackgroundTransparency=0.5; ln.BorderSizePixel=0
        ln.Size=UDim2.new(1,0,0,1); ln.Position=UDim2.fromOffset(0,y+18); ln.Parent=parent
    end

    ------------------------------------------------------------------
    -- Events tab scaffolding: Tornado and Ascended occupy the same slot
    -- behind a segmented switch (only one shows at a time), Investment
    -- sits below whichever is active.
    ------------------------------------------------------------------
    if getgenv().PvBEventSide==nil then getgenv().PvBEventSide="tornado" end
    local sideSw=Instance.new("Frame")
    sideSw.BackgroundColor3=C.row; sideSw.BorderSizePixel=0
    sideSw.Size=UDim2.new(1,0,0,30); sideSw.Position=UDim2.fromOffset(0,0); sideSw.Parent=eventsC
    corner(sideSw,15)
    local swTor=mkButton(sideSw,"Tornado",C.blue,UDim2.new(0.5,-2,1,-4),UDim2.fromOffset(2,2)); corner(swTor,13)
    local swAsc=mkButton(sideSw,"Ascended",C.row,UDim2.new(0.5,-2,1,-4),UDim2.new(0.5,0,0,2)); corner(swAsc,13)
    local torGroup=Instance.new("Frame")
    torGroup.Name="TornadoGroup"; torGroup.BackgroundTransparency=1
    torGroup.Size=UDim2.new(1,0,0,292); torGroup.Position=UDim2.fromOffset(0,40); torGroup.Parent=eventsC
    local ascGroup=Instance.new("Frame")
    ascGroup.Name="AscendedGroup"; ascGroup.BackgroundTransparency=1
    ascGroup.Size=UDim2.new(1,0,0,292); ascGroup.Position=UDim2.fromOffset(0,40); ascGroup.Parent=eventsC
    local function rfSide()
        local tor = getgenv().PvBEventSide~="ascended"
        torGroup.Visible=tor; ascGroup.Visible=not tor
        swTor.BackgroundColor3 = tor and C.blue or C.row
        swAsc.BackgroundColor3 = tor and C.row or C.purple
    end
    swTor.MouseButton1Click:Connect(function() getgenv().PvBEventSide="tornado" saveMisc() rfSide() end)
    swAsc.MouseButton1Click:Connect(function() getgenv().PvBEventSide="ascended" saveMisc() rfSide() end)
    rfSide()

    mkSection(torGroup,"Tornado",0)
    mkSection(torGroup,"Submit to Tornado",148)
    mkSection(ascGroup,"Ascended",0)
    mkSection(ascGroup,"Submit to Ascended",148)
    mkSection(eventsC,"Investment",336)
    mkSection(miscC,"AFK",0)
    mkSection(miscC,"Cards",208)
    mkSection(miscC,"Potions",316)
    mkSection(miscC,"Quality of life",468)

    pcall(function()
        local VU=game:GetService("VirtualUser")
        LocalPlayer.Idled:Connect(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end)

    ------------------------------------------------------------------
    -- Wheel auto-spin
    ------------------------------------------------------------------
    local spinBtn = mkButton(miscTab,"Wheel auto-spin: ON",C.green,UDim2.new(1,0,0,30),UDim2.fromOffset(0,492))

    if getgenv().PvBWheelSpin == nil then
        getgenv().PvBWheelSpin = true
    end

    local function rfSpin()
        local on = getgenv().PvBWheelSpin
        spinBtn.Text = "Wheel auto-spin: " .. (on and "ON" or "OFF")
        spinBtn.BackgroundColor3 = on and C.green or C.grey
    end

    spinBtn.MouseButton1Click:Connect(function()
        getgenv().PvBWheelSpin = not getgenv().PvBWheelSpin
        rfSpin()
        saveMisc()
        setStatus("Wheel auto-spin " .. (getgenv().PvBWheelSpin and "on" or "off"))
    end)

    rfSpin()

    -- event-driven: TheWheelStateUpdate pushes the stored-spin count; any
    -- count above zero gets spun instantly, and each spin's own state push
    -- cascades until the wheel is drained. Slow fallback poll covers missed
    -- pushes (e.g. spins earned while this client lagged).
    do
        local spinBusy=false
        local function drainSpin(count)
            if spinBusy then return end
            if not (getgenv().PvBWheelSpin and TheWheelSpin and wheelEquipped()) then return end
            if count~=nil and (tonumber(count) or 0)<=0 then return end
            spinBusy=true
            pcall(function() TheWheelSpin:FireServer() end)
            task.delay(0.4,function() spinBusy=false end)
        end
        pcall(function()
            RS.Remotes.Cards.TheWheelStateUpdate.OnClientEvent:Connect(function(a,b)
                local n = tonumber(a) or tonumber(b)
                drainSpin(n)
            end)
        end)
        pcall(function()
            RS.Remotes.Cards.TheWheelInit.OnClientEvent:Connect(function(_,n) drainSpin(tonumber(n)) end)
        end)
        task.spawn(function()
            while alive() do
                task.wait(45)
                drainSpin(nil)
            end
        end)
    end

    ------------------------------------------------------------------
    -- Battery boost: adaptive Flash Mob supercharging.
    -- Live progress via Remotes.UpdateCardProgress {CardType,Progress,MaxProgress}.
    -- A progress DROP marks proc start (10x window). When no window is active
    -- and the bar is short, fire exactly enough Battery Packs (+25% each) to
    -- fill it - natural kills during windows cover the rest for free.
    -- Hand-sharing: sets PvBAscPause, waits for the Ascended loop to ack via
    -- PvBAscPaused, uses packs, restores the previous tool, releases.
    ------------------------------------------------------------------
    local function __buildBattery()
        local UseItemB
        pcall(function() UseItemB = RS:WaitForChild("Remotes"):WaitForChild("UseItem") end)
        local cardProg = {}
        local procStart = 0
        local PROC_DUR = 8
        pcall(function()
            RS.Remotes.UpdateCardProgress.OnClientEvent:Connect(function(p)
                if type(p)~="table" or not p.CardType then return end
                local prev = cardProg[p.CardType]
                if prev and tonumber(p.Progress) and tonumber(prev.Progress) and p.Progress < prev.Progress then
                    if p.CardType=="Flash Mob" then procStart=os.clock() end
                end
                cardProg[p.CardType] = { Progress=tonumber(p.Progress) or 0, MaxProgress=tonumber(p.MaxProgress) or 0 }
            end)
        end)
        pcall(function() RS.Remotes.CardMachineRequestAll:FireServer() end)

        local function findBatteries()
            local out={}
            for _,c in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
                if c then for _,t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") and t.Name:find("Battery Pack",1,true) then out[#out+1]=t end
                end end
            end
            return out
        end
        local function currentTool()
            local ch=LocalPlayer.Character
            return ch and ch:FindFirstChildWhichIsA("Tool")
        end
        local function equipT(t)
            local ch=LocalPlayer.Character
            local h=ch and ch:FindFirstChildOfClass("Humanoid")
            if h and t then pcall(function() h:EquipTool(t) end) return true end
            return false
        end

        local batBtn = mkButton(miscTab,"Battery boost: OFF",C.grey,UDim2.new(1,0,0,30),UDim2.fromOffset(0,594))
        local batLbl = mkLabel(miscTab,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,628),C.dim,Enum.Font.Gotham,12)
        local function rfBat()
            local on=getgenv().PvBBatteryBoost
            batBtn.Text="Battery boost: "..(on and "ON" or "OFF")
            batBtn.BackgroundColor3=on and C.green or C.grey
        end

        local function usePacks(n)
            local packs=findBatteries()
            if #packs==0 then return 0 end
            n=math.min(n,#packs)
            local wasAsc = getgenv().PvBAscended
            local prev = currentTool()
            if wasAsc then
                getgenv().PvBAscPause=true
                local t0=os.clock()
                while not getgenv().PvBAscPaused and os.clock()-t0<2 do task.wait(0.05) end
                task.wait(0.15)
            end
            local used=0
            for i=1,n do
                local t=packs[i]
                if t and t.Parent and equipT(t) then
                    task.wait(0.15)
                    pcall(function() UseItemB:FireServer({Toggle=true, Tool=t}) end)
                    used=used+1
                    task.wait(0.55)  -- game-side 0.5s use debounce
                end
            end
            if prev and prev.Parent then equipT(prev) end
            if wasAsc then getgenv().PvBAscPause=false end
            return used
        end

        task.spawn(function()
            while alive() do
                task.wait(0.25)
                if not getgenv().PvBBatteryBoost then batLbl.Text="" continue end
                local fp=cardProg["Flash Mob"]
                if not fp or fp.MaxProgress<=0 then
                    batLbl.Text="waiting for Flash Mob progress data..."
                    pcall(function() RS.Remotes.CardMachineRequestAll:FireServer() end)
                    task.wait(3)
                elseif os.clock()-procStart < PROC_DUR then
                    batLbl.Text=("10x ACTIVE (%.1fs left) - holding packs"):format(PROC_DUR-(os.clock()-procStart))
                else
                    local missing = fp.MaxProgress - fp.Progress
                    if missing>0 then
                        local per = fp.MaxProgress*0.25
                        local need = math.ceil(missing/per)
                        local have = #findBatteries()
                        if have<=0 then batLbl.Text=("out of Battery Packs (bar %d/%d)"):format(fp.Progress,fp.MaxProgress)
                        else
                            batLbl.Text=("topping up: %d/%d, firing %d pack(s)"):format(fp.Progress,fp.MaxProgress,math.min(need,have))
                            usePacks(need)
                            task.wait(0.4)
                            pcall(function() RS.Remotes.CardMachineRequestAll:FireServer() end)
                        end
                    else
                        batLbl.Text=("bar full %d/%d - proc imminent"):format(fp.Progress,fp.MaxProgress)
                    end
                end
            end
        end)

        batBtn.MouseButton1Click:Connect(function()
            getgenv().PvBBatteryBoost = not getgenv().PvBBatteryBoost
            rfBat()
            setStatus("Battery boost "..(getgenv().PvBBatteryBoost and "on" or "off"))
        end)
        rfBat()
    end
    __buildBattery()


------------------------------------------------------------------
    -- Auto-click (AFK section): fires every PvBClickFreq seconds
    ------------------------------------------------------------------
    local clickBtn = mkButton(miscTab,"Auto-click: OFF",C.grey,UDim2.new(1,-70,0,30),UDim2.fromOffset(0,122))

    if getgenv().PvBAutoClick == nil then
        getgenv().PvBAutoClick = false
    end

    local function rfClick()
        local on = getgenv().PvBAutoClick
        clickBtn.Text = "Auto-click: " .. (on and "ON" or "OFF")
        clickBtn.BackgroundColor3 = on and C.green or C.grey
    end

    local idleClicking=false          -- true when WE auto-enabled the clicker
    local idleFishing=false           -- true when WE auto-enabled fishing
    -- while idle auto-click is live, blanket every toolkit window with a click
    -- sink so the synthetic clicks (bottom-left quadrant) can't press our own
    -- buttons if a window happens to sit there. Any real mouse move unblocks.
    -- The old idle "blocker" overlay is retired: it was the frozen box.
    -- It covered the whole frame when idle armed, ate the focus click, and
    -- could orphan across reloads. Injected clicks are kept off the UI by
    -- position-dodging + the human-presence pause instead. This now only
    -- cleans up any blocker left behind by an older instance.
    local function setUiBlocked(_)
        pcall(function()
            for _, w in ipairs(gui:GetChildren()) do
                if w:IsA("Frame") then
                    local blk = w:FindFirstChild("PvBIdleBlocker")
                    if blk then blk:Destroy() end
                end
            end
        end)
    end
    setUiBlocked(false)

    -- never let injected clicks land on (or fight with) the toolkit UI.
    -- On small farm windows the old fixed idle point (25%w,72%h) sat right on
    -- top of the frame, which is why the UI felt frozen: every injected click
    -- broke drags and ghost-pressed whatever button was under that spot.
    local function overToolkit(x, y)
        local ok, res = pcall(function()
            local inset = game:GetService("GuiService"):GetGuiInset()
            local p, s = frame.AbsolutePosition, frame.AbsoluteSize
            local yy = y - inset.Y
            return x >= p.X - 10 and x <= p.X + s.X + 10 and yy >= p.Y - 10 and yy <= p.Y + s.Y + 10
        end)
        return ok and res == true
    end
    -- human-presence detector. Injected clicks are the reason the UI felt
    -- frozen: the mouse-UP we send releases a physically held drag no matter
    -- WHERE the click lands, so dodging the frame's position isn't enough.
    -- VIM button events never move the mouse, so mouse movement (or any
    -- keyboard input) means a real person is on this client - pause every
    -- injected click for a few seconds around human activity.
    -- Panic switch: RightCtrl toggles ALL injected clicks for this client.
    local lastHuman, lastPtWarn = 0, 0
    UIS.InputChanged:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseMovement
            or io.UserInputType == Enum.UserInputType.MouseWheel then
            -- our own injected cursor move must not register as a human, or the
            -- presence-pause would retrigger every beat and clicking would stall
            if os.clock() - (getgenv().PvBSyntheticAt or 0) < 0.5 then return end
            lastHuman = os.clock()
        end
    end)
    UIS.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.Keyboard then
            -- RightCtrl must ALWAYS register (it is the panic switch), but the
            -- presence timestamp must ignore our own injected F13 - otherwise
            -- safe-mode clicking sets lastHuman itself and then suppresses its
            -- own next click for 3s, halving the effective click rate.
            if io.KeyCode ~= Enum.KeyCode.RightControl
               and os.clock() - (getgenv().PvBSyntheticAt or 0) < 0.5 then return end
            lastHuman = os.clock()
            if io.KeyCode == Enum.KeyCode.RightControl then
                getgenv().PvBClicksPaused = not getgenv().PvBClicksPaused
                setStatus(getgenv().PvBClicksPaused
                    and "Injected clicks PAUSED on this client (RightCtrl to resume)"
                    or  "Injected clicks resumed")
            end
        end
    end)

    local function clickMouseOnce()
        if getgenv().PvBClicksPaused then return end
        if os.clock() - lastHuman < 3 then return end        -- a human is interacting here
        if UIS:GetFocusedTextBox() then return end           -- never click while typing in a box

        -- SAFE MODE (default). Position-based clicking cannot be made reliable:
        -- Roblox re-syncs its cursor to the real OS pointer every frame, and
        -- when your mouse leaves the window that pointer is frozen at the edge
        -- crossing - so injected clicks land there whatever coordinates we pass.
        -- A RIGHT-click sidesteps the whole problem: Roblox GUI buttons only
        -- respond to left-click, so this can never press a button or open a
        -- dialog, wherever the cursor happens to be parked. It still counts as
        -- input, which is all the AFK timer needs.
        if getgenv().PvBClickSafe ~= false then
            -- Dump-verified: the GAME runs its own AFK tracker (AFKBannerHandle).
            -- It listens ONLY to UserInputService.InputBegan with
            -- gameProcessedEvent == false, and fires PlayerAFK(true) after 120s
            -- of silence. VirtualUser input never reaches UIS, which is why the
            -- previous safe mode let characters go AFK. VirtualInputManager DOES
            -- reach UIS, so use it - but with inputs that cannot press anything:
            --   F13: a key nothing in this game binds. No character movement, no
            --        hotbar switching, cannot activate a GuiButton.
            --   MouseButton2: GuiButtons only respond to MouseButton1, so a
            --        right-click can never press a button or open a dialog.
            -- Stamp BEFORE and AFTER every send. VirtualInputManager input
            -- reaches UserInputService (that is the whole point of using it),
            -- so without this marker our own F13 / right-click read as human
            -- activity and reset the AFK timers we are trying to satisfy.
            -- This branch is the DEFAULT path and used to skip the stamp
            -- entirely, which silently disabled every synthetic-input guard.
            getgenv().PvBSyntheticAt = os.clock()
            pcall(function()
                VIM:SendKeyEvent(true,  Enum.KeyCode.F13, false, game)
                task.wait(0.03)
                getgenv().PvBSyntheticAt = os.clock()
                VIM:SendKeyEvent(false, Enum.KeyCode.F13, false, game)
            end)
            getgenv().PvBSyntheticAt = os.clock()
            pcall(function()                       -- redundancy: covers executors
                VIM:SendMouseButtonEvent(0, 0, 1, true,  game, 0)   -- 1 = right button
                task.wait(0.03)                     -- where SendKeyEvent is a no-op
                getgenv().PvBSyntheticAt = os.clock()
                VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
            end)
            getgenv().PvBSyntheticAt = os.clock()
            return
        end

        local pos
        if idleClicking then
            local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
            if vp then
                -- ONE fixed, saved point. Never randomised and never relocated:
                -- the old version picked between candidate spots, so the target
                -- could move when the toolkit window moved. Stored as a fraction
                -- of the viewport so one setting lands correctly on every client
                -- regardless of its window size.
                local fx = tonumber(getgenv().PvBClickX) or 0.25
                local fy = tonumber(getgenv().PvBClickY) or 0.72
                pos = Vector2.new(vp.X * fx, vp.Y * fy)
                if overToolkit(pos.X, pos.Y) then            -- refuse to click our own UI
                    if os.clock() - lastPtWarn > 20 then
                        lastPtWarn = os.clock()
                        setStatus("click point sits under the toolkit - move the window or re-set the point")
                    end
                    return
                end
            else
                pos = UIS:GetMouseLocation()
                if overToolkit(pos.X, pos.Y) then return end
            end
        else
            pos = UIS:GetMouseLocation()
            if overToolkit(pos.X, pos.Y) then return end     -- cursor is on the UI: skip this beat
        end

        -- The x,y given to SendMouseButtonEvent do NOT decide where the click
        -- lands: Roblox hit-tests with its own cursor position, which FREEZES
        -- at wherever the real mouse last was inside the window. Move the mouse
        -- off the edge and every injected click keeps hitting whatever button
        -- sits at that frozen crossing point. So: move the engine cursor to our
        -- chosen spot FIRST, then click - now the click lands where we intend.
        local inset = Vector2.new(0, 0)
        pcall(function()
            local gi = game:GetService("GuiService"):GetGuiInset()
            inset = Vector2.new(gi.X, gi.Y)
        end)
        local tx, ty = pos.X + inset.X, pos.Y + inset.Y
        getgenv().PvBSyntheticAt = os.clock()
        pcall(function() VIM:SendMouseMoveEvent(tx, ty, game) end)
        task.wait(0.03)
        getgenv().PvBSyntheticAt = os.clock()
        pcall(function()
            VIM:SendMouseButtonEvent(tx, ty, 0, true, game, 0)
            task.wait(0.04)
            VIM:SendMouseButtonEvent(tx, ty, 0, false, game, 0)
        end)
        getgenv().PvBSyntheticAt = os.clock()
    end

    clickBtn.MouseButton1Click:Connect(function()
        getgenv().PvBAutoClick = not getgenv().PvBAutoClick
        rfClick()
        saveMisc()
        setStatus("Auto-click " .. (getgenv().PvBAutoClick and ("on: clicking every "..tostring(getgenv().PvBClickFreq or 3).."s") or "off"))
    end)

    rfClick()

    task.spawn(function()
        while alive() do
            if getgenv().PvBAutoClick then
                clickMouseOnce()
                task.wait(math.max(tonumber(getgenv().PvBClickFreq) or 3, 0.2))
            else
                task.wait(0.15)
            end
        end
    end)

------------------------------------------------------------------
    -- Stats window toggle
    ------------------------------------------------------------------
    -- fleet census has no in-game window on purpose: it is read from an
    -- external console so checking progress never means opening a client
    local statsBtn = mkButton(miscTab,"Open stats window",C.blue,UDim2.new(1,0,0,30),UDim2.fromOffset(0,526))

    statsBtn.MouseButton1Click:Connect(function()
        local f = getgenv().PvBStatsFrame

        if not f then
            setStatus("Stats window not ready yet.")
            return
        end

        f.Visible = not f.Visible
        statsBtn.Text = f.Visible and "Close stats window" or "Open stats window"
        statsBtn.BackgroundColor3 = f.Visible and C.purple or C.blue
        setStatus("Stats window " .. (f.Visible and "opened" or "closed"))
    end)

------------------------------------------------------------------
    -- Auto-buy (moved from Buy tab): all in-stock seeds + gears when on
    ------------------------------------------------------------------
    do
        local BuyItem = RS.Remotes:WaitForChild("BuyItem")
        local BuyGear = RS.Remotes:WaitForChild("BuyGear")
        local SEEDS   = RS.Assets:WaitForChild("Seeds")
        local GEARS   = RS.Assets:WaitForChild("Gears")
        if getgenv().PvBAutoBuy == nil then getgenv().PvBAutoBuy = true end
        local function buyFolder(folder, remote)
            for _,item in ipairs(folder:GetChildren()) do
                if not getgenv().PvBAutoBuy then return end
                if (item:GetAttribute("Stock") or 0) > 0 then remote:FireServer(item.Name, false) task.wait(0.45) end
            end
        end
        task.spawn(function() while alive() do task.wait(2)
            if getgenv().PvBAutoBuy then buyFolder(SEEDS, BuyItem) buyFolder(GEARS, BuyGear) end
        end end)
        local buyBtn = mkButton(miscTab,"Auto-buy plants & gears: OFF",C.grey,UDim2.new(1,0,0,30),UDim2.fromOffset(0,560))
        if getgenv().PvBAutoBuy then buyBtn.Text="Auto-buy plants & gears: ON" buyBtn.BackgroundColor3=C.green end
        buyBtn.MouseButton1Click:Connect(function()
            getgenv().PvBAutoBuy = not getgenv().PvBAutoBuy
            local on=getgenv().PvBAutoBuy
            buyBtn.Text="Auto-buy plants & gears: "..(on and "ON" or "OFF") buyBtn.BackgroundColor3=on and C.green or C.grey
            setStatus("auto-buy "..(on and "on" or "off"))
        end)
    end

    ------------------------------------------------------------------
    -- Fishing rewards (spams the fishing event remotes on a loop)
    ------------------------------------------------------------------
    local Fishable, FishDone
    -- NEVER block here. The toolkit auto-injects at game load, when
    -- Remotes.Fishing may not have replicated yet. A plain WaitForChild has no
    -- timeout, so on a slow client it yielded FOREVER and everything below it -
    -- including the entire AFK/idle system - was never built. That is exactly
    -- why some clients never started AFK fishing while others (where the folder
    -- arrived quickly, or arrived later) did. Resolve without blocking, then
    -- keep retrying in the background.
    local function resolveFishRemotes()
        pcall(function()
            local rem = RS:FindFirstChild("Remotes")
            local f = rem and rem:FindFirstChild("Fishing")
            if f then
                Fishable = f:FindFirstChild("FishableRequest") or Fishable
                FishDone = f:FindFirstChild("FishingComplete") or FishDone
            end
        end)
        return (Fishable ~= nil) and (FishDone ~= nil)
    end
    resolveFishRemotes()
    task.spawn(function()
        while alive() and not (Fishable and FishDone) do
            task.wait(3)
            resolveFishRemotes()
        end
    end)

    getgenv().PvBAutoFish = false
    if getgenv().PvBFishGap == nil then getgenv().PvBFishGap = 0.007 end   -- seconds after each request/complete pair
    if getgenv().PvBFishSellEvery == nil then getgenv().PvBFishSellEvery = 1500 end
    if getgenv().PvBFishSellWait  == nil then getgenv().PvBFishSellWait  = 16 end
    local PD; pcall(function() PD = require(RS:WaitForChild("PlayerData")) end)
    local function totalFished()
        local ok,n = pcall(function() return PD:GetData().Data.Fishing.TotalFished end)
        return ok and tonumber(n) or nil
    end

	-- Passive fishing speed gauge. Does NOT fire fishing remotes.
task.spawn(function()
    local last = totalFished()
    local lastT = os.clock()

    while alive() do
        task.wait(1)

        local cur = totalFished()
        local now = os.clock()

        if cur and last then
            local dt = now - lastT
            local gained = cur - last
            local rate = gained / math.max(dt, 0.001)

            if getgenv().PvBAutoFish then
                setStatus(("Fishing speed: %.1f fish/s | +%d in %.1fs | total %d"):format(rate, gained, dt, cur))
            end

            last = cur
            lastT = now
        else
            if getgenv().PvBAutoFish then setStatus("Fishing speed: totalFished unreadable") end
            last = cur
            lastT = now
        end
    end
	end)
    ------------------------------------------------------------------
    -- AFK section. The fishing timing boxes fold behind a slim "v"
    -- segment on the toggle row; expanding reflows only this section.
    ------------------------------------------------------------------
    if getgenv().PvBClickFreq==nil then getgenv().PvBClickFreq=3 end
    if getgenv().PvBClickSafe==nil then getgenv().PvBClickSafe=true end  -- right-click: cannot press UI
    if getgenv().PvBClickX==nil then getgenv().PvBClickX=0.25 end   -- fraction of viewport
    if getgenv().PvBClickY==nil then getgenv().PvBClickY=0.72 end
    if getgenv().PvBIdleDelay==nil then getgenv().PvBIdleDelay=25 end

    local fishBtn = mkButton(miscTab,"Fishing rewards: OFF",C.grey,UDim2.new(1,-34,0,30),UDim2.fromOffset(0,24))
    local fishAdvBtn = mkButton(miscTab,"v",C.row,UDim2.fromOffset(30,30),UDim2.new(1,-30,0,24))
    fishAdvBtn.TextSize=11; fishAdvBtn.TextColor3=C.dim
    local fishAdvLbl = mkLabel(miscTab,"fire gap (s)   /   fires before pause   /   pause (s)",UDim2.new(1,0,0,12),UDim2.fromOffset(0,58),C.dim,Enum.Font.Gotham,10)
    local fishGapBox = Instance.new("TextBox")
    fishGapBox.Size=UDim2.new(1/3,-4,0,26); fishGapBox.Position=UDim2.fromOffset(0,72)
    fishGapBox.BackgroundColor3=C.field; fishGapBox.TextColor3=C.txt; fishGapBox.Font=Enum.Font.GothamMedium
    fishGapBox.TextSize=12; fishGapBox.PlaceholderText="gap s"; fishGapBox.PlaceholderColor3=C.dim
    fishGapBox.Text=tostring(getgenv().PvBFishGap or 0.007); fishGapBox.ClearTextOnFocus=false
    fishGapBox.BorderSizePixel=0; fishGapBox.Parent=miscTab; corner(fishGapBox,6)
    local fishMaxBox = fishGapBox:Clone()
    fishMaxBox.Position=UDim2.new(1/3,2,0,72); fishMaxBox.PlaceholderText="max"
    fishMaxBox.Text=tostring(getgenv().PvBFishSellEvery or 1500); fishMaxBox.Parent=miscTab
    local fishWaitBox = fishGapBox:Clone()
    fishWaitBox.Position=UDim2.new(2/3,4,0,72); fishWaitBox.PlaceholderText="pause s"
    fishWaitBox.Text=tostring(getgenv().PvBFishSellWait or 16); fishWaitBox.Parent=miscTab
    fishAdvLbl.Visible=false; fishGapBox.Visible=false; fishMaxBox.Visible=false; fishWaitBox.Visible=false
    fishGapBox.FocusLost:Connect(function()
        local n=tonumber(fishGapBox.Text)
        if n and n>=0 then getgenv().PvBFishGap=n saveMisc() end
        fishGapBox.Text=tostring(getgenv().PvBFishGap)
    end)
    fishMaxBox.FocusLost:Connect(function()
        local n=tonumber(fishMaxBox.Text)
        if n and n>=1 then getgenv().PvBFishSellEvery=math.floor(n) saveMisc() end
        fishMaxBox.Text=tostring(getgenv().PvBFishSellEvery)
    end)
    fishWaitBox.FocusLost:Connect(function()
        local n=tonumber(fishWaitBox.Text)
        if n and n>=0 then getgenv().PvBFishSellWait=n saveMisc() end
        fishWaitBox.Text=tostring(getgenv().PvBFishSellWait)
    end)
    local idleFishBtn = mkButton(miscTab,"Start fishing when AFK: ON",C.green,UDim2.new(1,0,0,26),UDim2.fromOffset(0,88))
    local fishAfkSaved = nil   -- your AFK-fishing setting from before a planting run forced it off; nil = not suppressed
    local function rfIdleFish()
        if fishAfkSaved~=nil then
            idleFishBtn.Text = "Start fishing when AFK: OFF (planting)"
            idleFishBtn.BackgroundColor3 = C.grey
            return
        end
        local on = getgenv().PvBIdleFish~=false
        idleFishBtn.Text = "Start fishing when AFK: "..(on and "ON" or "OFF")
        idleFishBtn.BackgroundColor3 = on and C.green or C.grey
    end
    idleFishBtn.MouseButton1Click:Connect(function()
        if fishAfkSaved~=nil then
            -- suppressed right now: edit the state it RETURNS to instead
            fishAfkSaved = not fishAfkSaved
            setStatus("AFK fishing will be "..(fishAfkSaved and "ON" or "OFF").." after planting")
            return
        end
        getgenv().PvBIdleFish = not (getgenv().PvBIdleFish~=false)
        saveMisc() rfIdleFish()
    end)
    rfIdleFish()

    -- auto-click frequency + AFK trigger delay (defaults 3s / 25s)
    local function mkMiniBox(txt)
        local b=Instance.new("TextBox")
        b.Size=UDim2.fromOffset(62,26); b.BackgroundColor3=C.field; b.TextColor3=C.txt
        b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.ClearTextOnFocus=false
        b.BorderSizePixel=0; b.Text=txt; b.Parent=miscTab; corner(b,6)
        return b
    end
    local clickFreqBox = mkMiniBox(tostring(getgenv().PvBClickFreq))
    clickFreqBox.PlaceholderText="every s"; clickFreqBox.PlaceholderColor3=C.dim
    clickFreqBox.FocusLost:Connect(function()
        local n=tonumber(clickFreqBox.Text)
        if n and n>=0.2 then getgenv().PvBClickFreq=n saveMisc() end
        clickFreqBox.Text=tostring(getgenv().PvBClickFreq)
    end)
    local afkLbl = mkLabel(miscTab,"AFK after (s)",UDim2.new(0.34,-4,0,26),UDim2.fromOffset(0,156),C.txt,Enum.Font.Gotham,13)
    local clickSafeBtn = mkButton(miscTab,"Safe click",C.green,UDim2.new(0.3,-4,0,26),UDim2.new(0.34,0,0,156))
    local clickPtBtn = mkButton(miscTab,"Click pt",C.row,UDim2.new(0.36,-66,0,26),UDim2.new(0.64,0,0,156))
    local function rfClickSafe()
        local safe = getgenv().PvBClickSafe ~= false
        clickSafeBtn.Text = safe and "Safe click" or "Point click"
        clickSafeBtn.BackgroundColor3 = safe and C.green or C.amber
        clickPtBtn.Visible = not safe
    end
    clickSafeBtn.MouseButton1Click:Connect(function()
        getgenv().PvBClickSafe = not (getgenv().PvBClickSafe ~= false)
        saveMisc() rfClickSafe()
        setStatus(getgenv().PvBClickSafe ~= false
            and "Safe click: right-click, cannot press any button"
            or  "Point click: left-clicks your saved point (can hit UI)")
    end)
    local ptArmed=false
    local function rfClickPt()
        if ptArmed then clickPtBtn.Text="click anywhere to set..." return end
        clickPtBtn.Text=("Click pt: %d%%, %d%%"):format(
            math.floor((tonumber(getgenv().PvBClickX) or 0.25)*100+0.5),
            math.floor((tonumber(getgenv().PvBClickY) or 0.72)*100+0.5))
    end
    clickPtBtn.MouseButton1Click:Connect(function()
        if ptArmed then return end
        ptArmed=true rfClickPt()
        -- capture the NEXT click anywhere: pressing this button can't set the
        -- point to itself, and the saved value is a viewport fraction.
        local conn
        conn=UIS.InputBegan:Connect(function(io)
            if io.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            if conn then conn:Disconnect() conn=nil end
            task.defer(function()
                local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                local m=UIS:GetMouseLocation()
                if vp and vp.X>0 and vp.Y>0 then
                    getgenv().PvBClickX=math.clamp(m.X/vp.X,0,1)
                    getgenv().PvBClickY=math.clamp(m.Y/vp.Y,0,1)
                    saveMisc()
                    setStatus(("click point saved: %d%%, %d%% of screen"):format(
                        math.floor(getgenv().PvBClickX*100+0.5), math.floor(getgenv().PvBClickY*100+0.5)))
                end
                ptArmed=false rfClickPt()
            end)
        end)
    end)
    rfClickPt()
    rfClickSafe()
    local afkBox = mkMiniBox(tostring(getgenv().PvBIdleDelay))
    afkBox.FocusLost:Connect(function()
        local n=tonumber(afkBox.Text)
        if n and n>=3 then getgenv().PvBIdleDelay=math.floor(n) saveMisc() end
        afkBox.Text=tostring(getgenv().PvBIdleDelay)
    end)

    -- one relayout keeps the AFK rows tight whether the timing row is open or not
    local function relayoutAFK()
        local y=24
        fishBtn.Position=UDim2.fromOffset(0,y); fishAdvBtn.Position=UDim2.new(1,-30,0,y); y=y+34
        if fishAdvLbl.Visible then
            fishAdvLbl.Position=UDim2.fromOffset(0,y); y=y+14
            fishGapBox.Position=UDim2.fromOffset(0,y)
            fishMaxBox.Position=UDim2.new(1/3,2,0,y)
            fishWaitBox.Position=UDim2.new(2/3,4,0,y)
            y=y+30
        end
        idleFishBtn.Position=UDim2.fromOffset(0,y); y=y+30
        clickBtn.Position=UDim2.fromOffset(0,y); clickFreqBox.Position=UDim2.new(1,-62,0,y+2); y=y+34
        afkLbl.Position=UDim2.fromOffset(0,y); clickSafeBtn.Position=UDim2.new(0.34,0,0,y)
        clickPtBtn.Position=UDim2.new(0.64,0,0,y)
        afkBox.Position=UDim2.new(1,-62,0,y); y=y+32
    end
    fishAdvBtn.MouseButton1Click:Connect(function()
        local show = not fishAdvLbl.Visible
        fishAdvLbl.Visible=show; fishGapBox.Visible=show; fishMaxBox.Visible=show; fishWaitBox.Visible=show
        fishAdvBtn.Text = show and "^" or "v"
        relayoutAFK()
    end)
    relayoutAFK()

    local function rfFish()
        local on = getgenv().PvBAutoFish
        fishBtn.Text = "Fishing rewards: " .. (on and "ON" or "OFF")
        fishBtn.BackgroundColor3 = on and C.green or C.grey
    end

    fishBtn.MouseButton1Click:Connect(function()
        if not (Fishable and FishDone) then
            setStatus("Fishing remotes not found (event not live?)")
            return
        end
        getgenv().PvBAutoFish = not getgenv().PvBAutoFish
        rfFish()
        saveMisc()
        setStatus("Fishing rewards " .. (getgenv().PvBAutoFish and "on" or "off"))
    end)

    rfFish()

    task.spawn(function()
        local base, cycles = totalFished(), 0
        while alive() do
            if getgenv().PvBAutoFish and Fishable and FishDone then
                local gap = tonumber(getgenv().PvBFishGap) or 0.009
                if gap < 0 then gap = 0 end
                pcall(function() Fishable:FireServer() end)
                pcall(function() FishDone:FireServer() end)
                cycles += 1
                local every = tonumber(getgenv().PvBFishSellEvery) or 1500
                local cur = totalFished()
                local caught = (cur and base) and (cur - base) or cycles
                if every > 0 and caught >= every then
                    setStatus(("Fishing: %d caught, pausing for Keep sell..."):format(caught))
                    task.wait(tonumber(getgenv().PvBFishSellWait) or 20)
                    base, cycles = totalFished(), 0
                    setStatus("Fishing: resumed")
                else
                    task.wait(gap)
                end
            else
                task.wait(0.15)
            end
        end
    end)

    if getgenv().PvBIdleAuto==nil then getgenv().PvBIdleAuto=true end
    if getgenv().PvBIdleFish==nil then getgenv().PvBIdleFish=true end
    local lastActivity=os.clock()
    local lastFishWarn=0
    -- only keyboard / mouse movement / scroll count as human activity: our synthetic
    -- clicks are button events at a fixed spot and must NOT reset the idle timer
    UIS.InputBegan:Connect(function(io)
        local t=io.UserInputType
        if t==Enum.UserInputType.Keyboard or t==Enum.UserInputType.MouseWheel then
            -- safe-mode auto-click injects F13, which arrives here as a
            -- Keyboard event; without this guard the clicker kept resetting
            -- the very timer that armed it
            if os.clock() - (getgenv().PvBSyntheticAt or 0) < 0.5 then return end
            lastActivity=os.clock()
        end
    end)
    UIS.InputChanged:Connect(function(io)
        if io.UserInputType==Enum.UserInputType.MouseMovement then
            -- ignore the auto-clicker's own injected cursor moves, or it would
            -- reset the AFK timer every beat and idle actions would keep
            -- standing down a second after arming
            if os.clock() - (getgenv().PvBSyntheticAt or 0) < 0.5 then return end
            lastActivity=os.clock()
        end
    end)
    task.spawn(function()
        while alive() do
            task.wait(1)
            -- Single source of truth for "is the player AFK". Computed here,
            -- unconditionally, before any branching, so the window fade and
            -- the idle actions can never disagree about it. Everything that
            -- needs idle state reads this instead of running its own timer.
            getgenv().PvBIdleNow =
                (os.clock()-lastActivity) >= math.max(tonumber(getgenv().PvBIdleDelay) or 25, 3)
            if getgenv().PvBCycleOn then
                -- Leaderboard Cycle owns the toggles; undo anything idle-started and stay out
                if idleClicking or idleFishing then
                    if idleClicking then idleClicking=false getgenv().PvBAutoClick=false rfClick() end
                    if idleFishing  then idleFishing=false  getgenv().PvBAutoFish=false  rfFish()  end
                    setStatus("cycle running: idle auto stood down")
                end
            elseif getgenv().PvBIdleAuto then
                local idle = (os.clock()-lastActivity) >= math.max(tonumber(getgenv().PvBIdleDelay) or 25, 3)
                -- click and fishing arm INDEPENDENTLY: with auto-click persisted,
                -- farms boot with it already on, and fishing must still arm.
                -- The idle system never saves: these are transient machine states,
                -- and saving them from 12 clients stomped the shared settings file.
                if idle then
                    local armed = {}
                    if not getgenv().PvBAutoClick then
                        idleClicking=true getgenv().PvBAutoClick=true rfClick()
                        armed[#armed+1]="auto-click"
                    end
                    if getgenv().PvBIdleFish~=false and not getgenv().PvBAutoFish then
                        if not (Fishable and FishDone) then resolveFishRemotes() end
                        if Fishable and FishDone then
                            idleFishing=true getgenv().PvBAutoFish=true rfFish()
                            armed[#armed+1]="fishing"
                        elseif os.clock() - lastFishWarn > 30 then
                            lastFishWarn = os.clock()
                            setStatus("AFK: fishing remotes not present on this server yet")
                        end
                    end
                    if #armed>0 then
                        setStatus("idle "..tostring(getgenv().PvBIdleDelay or 25).."s: "..table.concat(armed," + ").." on")
                    end
                else
                    local stood = {}
                    if idleClicking then
                        idleClicking=false getgenv().PvBAutoClick=false rfClick()
                        stood[#stood+1]="auto-click"
                    end
                    if idleFishing then
                        idleFishing=false getgenv().PvBAutoFish=false rfFish()
                        stood[#stood+1]="fishing"
                    end
                    if #stood>0 then setStatus("activity: "..table.concat(stood," + ").." off") end
                end
            end
        end
    end)

------------------------------------------------------------------
    -- Tornado event: Standard = fill weather with Cactus (as before).
    --                Upsize = upsize ANY picked plant to 20kg via
    --                hand-in/cash-out, then heart it, next plant.
    -- Submit block: hand in every non-mutated >=20kg of a picked plant
    --                (RequestGive only, never cashes out).
    ------------------------------------------------------------------
    local FavItem, torBoothSafe, torData, torFavs, torFav, torEquip, TARGET_KG, plantWeight, plantColors,
          torPlantsOfType, openPicker, torBtn, refreshMode, standardLoop, torLoop, subRunning, MUT_CAPS,
          subBtn, rfMut, refreshSubLabels, subTargets, claimAndHeart, subDidClaim, subStart,
          upsizeLoop, ascUpsizeLoop
    -- Resolve a nested remote WITHOUT ever blocking. Event remotes
    -- (Tornado / Ascended / Investment / PlantFuseMachine) simply do not exist
    -- while that event is off, and a timeout-less WaitForChild on them stalls
    -- the builder FOREVER - taking every section built after it down with it,
    -- including OP Plant Maker and the fleet reload watcher. Same bug class as
    -- the fishing remotes. Resolve now if present, else keep retrying quietly.
    local function lazyRemote(path, onGot)
        local function try()
            local node = RS
            for _, nm in ipairs(path) do
                node = node and node:FindFirstChild(nm)
                if not node then return nil end
            end
            return node
        end
        local got = try()
        if got then onGot(got) return end
        task.spawn(function()
            while alive() do
                task.wait(3)
                local g = try()
                if g then onGot(g) return end
            end
        end)
    end

    local function __buildTornado()
    local TorInteract
    lazyRemote({"Remotes","Events","Tornado","Interact"}, function(r) TorInteract = r end)
    pcall(function() FavItem = RS:WaitForChild("Remotes"):WaitForChild("FavoriteItem") end)
    local TorPD; pcall(function() TorPD = require(RS:WaitForChild("PlayerData")) end)
    local function torBooth() local b; pcall(function() b = require(RS.Modules.Utility.AutoEventModelGrabber)("Tornado") end) return b end
    -- grab the booth in a throwaway thread; its yield can strip caps from ITS thread, not the worker
    function torBoothSafe()
        local b,done=nil,false
        task.spawn(function() b=torBooth() done=true end)
        local w=0 while not done and w<3 do task.wait(0.05) w=w+0.05 end
        return b
    end
    function torData()  local ok,d=pcall(function() return TorPD:GetData().Data end) return ok and d or nil end
    function torFavs()  local d=torData() return (d and d.Favorites) or {} end
    -- Publish whether the player's SAVE DATA has actually resolved. This is the
    -- difference between "joined the game" and "joined but stuck on Loading
    -- data / your things are safe" - the client is in the server either way, so
    -- nothing outside the game can tell them apart without this.
    task.spawn(function()
        while alive() do
            getgenv().PvBDataOK = (torData() ~= nil)
            task.wait(3)
        end
    end)
    local function torCount(b)  return b and b:GetAttribute("WeatherCount") end
    local function torMax(b)    return b and b:GetAttribute("WeatherCountMax") end
    local function torActive(b) return b and b:GetAttribute("WeatherActive")==true end
    function torFav(id) local d=torData() local f=d and d.Favorites and d.Favorites[id] return f~=nil and f~=false end
    function torEquip(t)
        local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not (t and t.Parent and hum) then return false end
        hum:EquipTool(t)
        local w=0 while t.Parent~=LocalPlayer.Character and w<0.6 do task.wait(0.03) w=w+0.03 end
        return t.Parent==LocalPlayer.Character
    end
    local function torResetPopup()
        local pg=LocalPlayer:FindFirstChild("PlayerGui") if not pg then return nil end
        for _,x in ipairs(pg:GetDescendants()) do
            if x:IsA("TextLabel") and type(x.Text)=="string" and x.Text:lower():find("reset event") then
                local f=x while f and f.Parent and not f.Parent:IsA("ScreenGui") do f=f.Parent end
                return f
            end
        end
    end
    local function torClearPopup(wait_s)
        local rp=torResetPopup()
        if rp then
            pcall(function() TorInteract:FireServer("Reset") end)
            pcall(function() rp.Visible=false end)
            task.wait(wait_s or 0.015)
        end
    end

    -- state (persist across re-execute)
    if getgenv().PvBTorMode  == nil then getgenv().PvBTorMode  = "standard" end
    if getgenv().PvBTorPlant == nil then getgenv().PvBTorPlant = "Corn Cobblazzio" end
    if getgenv().PvBSubPlant == nil then getgenv().PvBSubPlant = "Corn Cobblazzio" end
    TARGET_KG = 20

    function plantWeight(t)
        local w=t:GetAttribute("Size") or t:GetAttribute("Weight")   -- Size == kg
        return (type(w)=="number") and w or 0
    end
    function plantColors(t) return t:GetAttribute("Colors") or "Normal" end
    function torPlantsOfType(name)
        local out={}
        for _,c in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:HasTag("PlantTool") and (t.Name==name or t:GetAttribute("PlantName")==name) then out[#out+1]=t end
            end end
        end
        return out
    end

    -- ---- any-plant picker (shared by Upsize mode and Submit block) ----
    local function distinctPlants()
        local seen,names={},{}
        for _,c in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:HasTag("PlantTool") then
                    local n=t:GetAttribute("PlantName") or t.Name
                    if n and n~="" and not seen[n] then seen[n]=true names[#names+1]=n end
                end
            end end
        end
        table.sort(names)
        return names
    end
    local pickerF
    local function closePicker() if pickerF then pickerF:Destroy() pickerF=nil end end
    function openPicker(anchorBtn, onPick)
        if pickerF then closePicker() return end
        local names=distinctPlants()
        -- same pattern as the Plant tab's seed picker: search box on top, filtered list below
        pickerF=Instance.new("Frame")
        pickerF.Size=UDim2.new(1,0,0,math.min(math.max(#names,1)*26+40,172))
        pickerF.Position=UDim2.fromOffset(0, anchorBtn.Position.Y.Offset + anchorBtn.Size.Y.Offset + 2)
        pickerF.BackgroundColor3=C.field; pickerF.BorderSizePixel=0; pickerF.ZIndex=10
        pickerF.Parent=anchorBtn.Parent
        local cr=Instance.new("UICorner",pickerF) cr.CornerRadius=UDim.new(0,6)
        local search=Instance.new("TextBox")
        search.Size=UDim2.new(1,-12,0,24); search.Position=UDim2.fromOffset(6,6)
        search.BackgroundColor3=C.row; search.TextColor3=C.txt; search.Text=""
        search.PlaceholderText="search plants..."; search.PlaceholderColor3=C.dim
        search.Font=Enum.Font.Gotham; search.TextSize=12; search.BorderSizePixel=0
        search.ClearTextOnFocus=false; search.ZIndex=11; search.Parent=pickerF
        do local c2=Instance.new("UICorner",search) c2.CornerRadius=UDim.new(0,5) end
        local listF=Instance.new("ScrollingFrame")
        listF.Size=UDim2.new(1,-12,1,-40); listF.Position=UDim2.fromOffset(6,34)
        listF.BackgroundTransparency=1; listF.BorderSizePixel=0
        listF.ScrollBarThickness=4; listF.ZIndex=11; listF.Parent=pickerF
        local ll=Instance.new("UIListLayout",listF) ll.Padding=UDim.new(0,2)
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listF.CanvasSize=UDim2.fromOffset(0, ll.AbsoluteContentSize.Y+4)
        end)
        local function rebuild()
            for _,c in ipairs(listF:GetChildren()) do
                if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
            end
            local q=search.Text:lower()
            local shown=0
            for _,n in ipairs(names) do
                if q=="" or n:lower():find(q,1,true) then
                    shown=shown+1
                    local b=Instance.new("TextButton")
                    b.Size=UDim2.new(1,-6,0,24); b.BackgroundColor3=C.row; b.BorderSizePixel=0
                    b.Text=n; b.TextColor3=C.txt; b.Font=Enum.Font.Gotham; b.TextSize=12; b.ZIndex=12
                    b.Parent=listF
                    local bc=Instance.new("UICorner",b) bc.CornerRadius=UDim.new(0,4)
                    b.MouseButton1Click:Connect(function() closePicker() onPick(n) end)
                end
            end
            if shown==0 then
                local l=Instance.new("TextLabel")
                l.Size=UDim2.new(1,-6,0,24); l.BackgroundTransparency=1
                l.Text=(#names==0) and "no plants in inventory" or "no match"
                l.TextColor3=C.dim; l.Font=Enum.Font.Gotham; l.TextSize=12; l.ZIndex=12; l.Parent=listF
            end
        end
        search:GetPropertyChangedSignal("Text"):Connect(rebuild)
        rebuild()
    end

    torBtn   = mkButton(torGroup,"Tornado: OFF",C.grey,UDim2.new(1,0,0,30),UDim2.fromOffset(0,24))
    local modeBtn  = mkButton(torGroup,"Mode: Standard (Cactus)",C.blue,UDim2.new(1,0,0,26),UDim2.fromOffset(0,58))
    local plantBtn = mkButton(torGroup,"Plant: "..getgenv().PvBTorPlant,C.blue,UDim2.new(1,0,0,26),UDim2.fromOffset(0,88))
    local torLbl   = mkLabel(torGroup,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,118),C.dim,Enum.Font.Gotham,12)
    function refreshMode()
        local fb = getgenv().PvBTorMode=="forbidden"
        modeBtn.Text = fb and "Mode: Upsize (pick plant)" or "Mode: Standard (Cactus)"
        modeBtn.BackgroundColor3 = fb and C.purple or C.blue
        plantBtn.Text = "Plant: "..getgenv().PvBTorPlant
        plantBtn.Visible = fb
    end

    -- STANDARD: recycle cactus to fill the weather meter; keep running even when active
    function standardLoop(b)
        local mx=torMax(b) or 100
        while getgenv().PvBTornado do
            if torActive(b) then torLbl.Text="WEATHER ACTIVE. continuing..." setStatus("Tornado: WEATHER ACTIVE continuing") end
            torClearPopup(0.3)
            local plant
            for _,t in ipairs(torPlantsOfType("Cactus")) do if not torFav(t:GetAttribute("ID")) then plant=t break end end
            if not plant then torLbl.Text="waiting for Cactus..." task.wait(1)
            else
                if torEquip(plant) then
                    pcall(function() TorInteract:FireServer("RequestGive") end)
                    pcall(function() TorInteract:FireServer("CashOut","Cactus") end)
                end
                torLbl.Text=("count %s/%s"):format(tostring(torCount(b)),tostring(mx))
                task.wait(0.009)
            end
        end
    end

    -- UPSIZE: upsize each unhearted picked-plant to 20kg, then heart it.
    -- SHARED by Tornado and Ascended, so the two are identical by construction
    -- rather than by copy: same scan order, same hearting pass, same target
    -- choice, same waits. Only the Interact remote, the on-flag and the label
    -- differ. Editing this improves both at once; they cannot drift apart.
    function upsizeLoop(interact, isOn, lbl, booth, resetFn)
        local name = getgenv().PvBTorPlant
        lbl.Text="upsize: scanning for "..name
        while isOn() do
            if not interact then lbl.Text="Interact remote missing" break end
            if booth and torActive(booth) then lbl.Text="weather active, pausing..." task.wait(1) end
            -- each event clears/resets ITSELF. This used to hardcode the Tornado
            -- popup clear, which fires Tornado's Reset - so running this loop on
            -- Ascended never reset the Ascended track and it jammed on
            -- "reset the event first".
            if resetFn then resetFn() end
            -- heart anything already at/over target
            for _,t in ipairs(torPlantsOfType(name)) do
                local id=t:GetAttribute("ID")
                if id and plantWeight(t)>=TARGET_KG and not torFav(id) then pcall(function() FavItem:FireServer(id) end) task.wait(0.015) end
            end
            -- pick the heaviest unhearted plant still under target
            local target,tw
            local seen,maxw=0,0
            for _,t in ipairs(torPlantsOfType(name)) do
                seen=seen+1 local w=plantWeight(t) if w>maxw then maxw=w end
                local id=t:GetAttribute("ID")
                if id and not torFav(id) then if w<TARGET_KG and (not tw or w>tw) then target,tw=t,w end end
            end
            if not target then
                lbl.Text=("no target: %d %s seen, heaviest %.1fkg"):format(seen,name,maxw)
                setStatus("upsize: nothing under "..TARGET_KG.."kg unhearted")
                break
            end
            lbl.Text=("upsizing %s: %.1f/%dkg"):format(name, tw, TARGET_KG)
            if torEquip(target) then
                pcall(function() interact:FireServer("RequestGive") end)
                task.wait(0.009)
                pcall(function() interact:FireServer("CashOut", name) end)  -- count 1 = upsize, strips mutation
                task.wait(0.009)
            else task.wait(0.015) end
        end
    end

    local function forbiddenLoop(b)
        upsizeLoop(TorInteract, function() return getgenv().PvBTornado end, torLbl, b,
            function() torClearPopup(0.015) end)
    end

    function torLoop()
        torLbl.Text="starting "..getgenv().PvBTorMode.."..."
        if not TorInteract then
            setStatus("Tornado: remote missing") torLbl.Text="Interact remote missing"
        elseif getgenv().PvBTorMode=="forbidden" then
            forbiddenLoop(nil)                       -- no booth needed; keeps worker caps intact
        else
            local b=torBoothSafe()
            if not b then setStatus("Tornado: booth missing") torLbl.Text="booth missing (need it for Standard)"
            else standardLoop(b) end
        end
        getgenv().PvBTornado=false
        torBtn.Text="Tornado: OFF" torBtn.BackgroundColor3=C.grey
    end

    torBtn.MouseButton1Click:Connect(function()
        if getgenv().PvBTornado then
            getgenv().PvBTornado=false
            if getgenv().PvBOPStop then getgenv().PvBOPStop("tornado toggled off") end
            return
        end
        getgenv().PvBTornado=true
        torBtn.Text="Tornado: ON" torBtn.BackgroundColor3=C.green
        setStatus("Tornado: "..getgenv().PvBTorMode)
        task.spawn(torLoop)
    end)
    modeBtn.MouseButton1Click:Connect(function()
        getgenv().PvBTorMode = (getgenv().PvBTorMode=="forbidden") and "standard" or "forbidden"
        refreshMode()
    end)
    plantBtn.MouseButton1Click:Connect(function()
        openPicker(plantBtn, function(n)
            getgenv().PvBTorPlant = n
            refreshMode()
        end)
    end)
    refreshMode()

    ------------------------------------------------------------------
    -- Submit to Tornado: hand in every non-mutated >=20kg of the picked
    -- plant. Unhearts first. RequestGive only, NEVER cashes out.
    ------------------------------------------------------------------
    local SUB_MIN, SUB_TOL, SUB_DELAY = 20, 0.05, 0.3
    subRunning=false

    -- mutation -> hand-ins needed before claiming back (declared BEFORE the UI
    -- that reads it; it used to sit below, so the dropdown button rendered as an
    -- empty box and clicking it errored on a nil MUT_CAPS)
    MUT_CAPS = {
        { name="Tornado",  n=75, col=Color3.fromRGB(170,215,255) },
        { name="Ascended", n=60, col=Color3.fromRGB(240,205,50)  },
        { name="Rainbow",  n=40, col=nil                          },  -- gradient
        { name="Neon",     n=30, col=Color3.fromRGB(57,235,90)   },
        { name="Frozen",   n=22, col=Color3.fromRGB(30,110,170)  },
    }
    -- Thresholds read from the game's own EventTracks.Tornado at runtime.
    -- They are NOT fixed: the module halves them on one PlaceId
    -- (Frozen 15 / Neon 18 / Rainbow 21 / Ascended 23 / Tornado 27 instead of
    -- 22 / 30 / 40 / 60 / 75). The Ascended side already did this; Tornado was
    -- still hardcoded, so on that place every claim fired at the wrong count.
    local TOR_LADDER
    pcall(function()
        local m = require(RS.Modules.Library.EventTracks.Tornado)
        if m and type(m.Mutations)=="table" then
            TOR_LADDER = m
            for _,cap in ipairs(MUT_CAPS) do
                for _,e in ipairs(m.Mutations) do
                    if e.Name==cap.name and tonumber(e.PlantsRequired) then
                        cap.n = tonumber(e.PlantsRequired)
                    end
                end
            end
        end
    end)
    -- Authoritative submitted-plant count. Confirmed from the game code:
    --   Data.TornadoTracker[plantName] = { count, ... }
    -- and the client reads v[1] for the number submitted so far. This is the
    -- real number, and unlike anything counted locally it already includes
    -- plants left in the booth by an earlier partial run.
    -- NOTE: distinct from torCount(booth) above, which reads the booth's
    -- WeatherCount attribute. This is the per-plant submission tally.
    local function torSubmitted(name)
        local d = torData()
        local t = d and d.TornadoTracker and d.TornadoTracker[name]
        if type(t)=="table" then return tonumber(t[1]) or 0 end
        return tonumber(t) or 0
    end
    -- which mutation a claim would actually hand back at this count
    local function torTierAt(n)
        if TOR_LADDER and TOR_LADDER.GetCurrentMutation then
            local ok,cur = pcall(function() return TOR_LADDER:GetCurrentMutation(n) end)
            if ok and type(cur)=="table" and cur.Name then return cur.Name end
        end
        local best="Normal"
        for i=#MUT_CAPS,1,-1 do
            local e=MUT_CAPS[i]
            if n >= e.n then best=e.name end
        end
        return best
    end
    if getgenv().PvBSubMut == nil then getgenv().PvBSubMut = "Tornado" end
    local function subMutEntry()
        for _,e in ipairs(MUT_CAPS) do if e.name==getgenv().PvBSubMut then return e end end
        return MUT_CAPS[1]
    end
    local function subCap() return subMutEntry().n end

    local subPlantBtn = mkButton(torGroup,"Submit plant: "..getgenv().PvBSubPlant,C.blue,UDim2.new(1,0,0,26),UDim2.fromOffset(0,172))
    subBtn   = mkButton(torGroup,"Submit all 20kg",C.green,UDim2.new(0.55,-3,0,30),UDim2.fromOffset(0,202))
    local subMutBtn = mkButton(torGroup,"",C.row,UDim2.new(0.45,-3,0,30),UDim2.new(0.55,3,0,202))
    local claimBtn = mkButton(torGroup,"Claim back: "..getgenv().PvBSubPlant,C.amber,UDim2.new(1,0,0,26),UDim2.fromOffset(0,236))
    local subLbl   = mkLabel(torGroup,"idle",UDim2.new(1,0,0,20),UDim2.fromOffset(0,266),C.dim,Enum.Font.Gotham,12)

    -- adopt the Cards controls (built early into cardsHost) into the Cards section
    cardsHost.Size = UDim2.new(1,0,0,72)
    cardsHost.Position = UDim2.fromOffset(0,232)
    cardsHost.Parent = miscC

    local mutGrad
    function rfMut()
        local e = subMutEntry()
        subMutBtn.Text = ("%s (%d)"):format(e.name, e.n)
        if mutGrad then mutGrad:Destroy() mutGrad=nil end
        if e.name=="Rainbow" then
            subMutBtn.BackgroundColor3=Color3.new(1,1,1)
            mutGrad=Instance.new("UIGradient")
            mutGrad.Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,80,80)),
                ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255,170,60)),
                ColorSequenceKeypoint.new(0.40, Color3.fromRGB(250,235,80)),
                ColorSequenceKeypoint.new(0.60, Color3.fromRGB(90,220,110)),
                ColorSequenceKeypoint.new(0.80, Color3.fromRGB(90,150,255)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(190,110,255)),
            })
            mutGrad.Parent=subMutBtn
        else
            subMutBtn.BackgroundColor3=e.col
        end
    end
    local mutDrop
    subMutBtn.MouseButton1Click:Connect(function()
        if mutDrop then mutDrop:Destroy() mutDrop=nil return end
        if subRunning then return end
        mutDrop=Instance.new("Frame")
        mutDrop.Size=UDim2.new(0.45,-3,0,#MUT_CAPS*28+6)
        mutDrop.Position=UDim2.new(0.55,3,0,234)
        mutDrop.BackgroundColor3=C.panel; mutDrop.BorderSizePixel=0; mutDrop.ZIndex=20
        mutDrop.Parent=torGroup
        do local cr=Instance.new("UICorner",mutDrop) cr.CornerRadius=UDim.new(0,6) end
        local ll=Instance.new("UIListLayout",mutDrop) ll.Padding=UDim.new(0,2)
        local pd=Instance.new("UIPadding",mutDrop) pd.PaddingTop=UDim.new(0,3) pd.PaddingLeft=UDim.new(0,3) pd.PaddingRight=UDim.new(0,3)
        for _,e in ipairs(MUT_CAPS) do
            local o=mkButton(mutDrop, ("%s (%d)"):format(e.name,e.n), e.col or Color3.new(1,1,1), UDim2.new(1,0,0,26), UDim2.new())
            o.ZIndex=21
            if e.name=="Rainbow" then
                local g=Instance.new("UIGradient")
                g.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,80,80)),
            ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255,170,60)),
            ColorSequenceKeypoint.new(0.40, Color3.fromRGB(250,235,80)),
            ColorSequenceKeypoint.new(0.60, Color3.fromRGB(90,220,110)),
            ColorSequenceKeypoint.new(0.80, Color3.fromRGB(90,150,255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(190,110,255)),
        })
                g.Parent=o
            end
            o.MouseButton1Click:Connect(function()
                getgenv().PvBSubMut=e.name
                saveMisc() rfMut()
                if mutDrop then mutDrop:Destroy() mutDrop=nil end
            end)
        end
    end)
    task.defer(rfMut)

    function refreshSubLabels()
        subPlantBtn.Text="Submit plant: "..getgenv().PvBSubPlant
        claimBtn.Text="Claim back: "..getgenv().PvBSubPlant
        if not subRunning then subBtn.Text = "Submit all 20kg" end
    end

    function subTargets(name)
        local favs=torFavs()
        local out={}
        for _,t in ipairs(torPlantsOfType(name)) do
            if plantWeight(t) >= (SUB_MIN - SUB_TOL) and plantColors(t)=="Normal" then out[#out+1]={tool=t, fav=favs[t:GetAttribute("ID")]} end
        end
        return out
    end

    -- claimAndHeart: forward-declared at the section top; assigned in the OP Plant Maker section below
    subDidClaim = false

    local function subEquip(t)
        local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not (t and t.Parent and hum) then return false end
        hum:EquipTool(t)
        local t0=os.clock()
        while t.Parent~=LocalPlayer.Character and os.clock()-t0<0.6 do task.wait(0.03) end
        return t.Parent==LocalPlayer.Character
    end

    local function subRun(limit)
        local name=getgenv().PvBSubPlant
        subDidClaim=false
        local cap=subCap()

        --
        -- CLAIM ON THE SERVER'S COUNT, NOT ON FIRE ATTEMPTS.
        --
        -- The old code claimed as soon as it had FIRED cap times. Under load a
        -- RequestGive can fail to register, so it fired 30 for Neon, landed
        -- ~24, and claimed anyway. The ladder is cumulative, so 24 sits on the
        -- Frozen rung (22) and the booth correctly handed back a Frozen.
        --
        -- Data.TornadoTracker[plant][1] is the number the SERVER has counted.
        -- Everything below keys off that, and it also accounts for plants left
        -- in the booth by an earlier partial run, which no local count can see.
        --
        local start = torSubmitted(name)

        if start >= cap then                       -- already there from before
            subLbl.Text=("booth already %d (%s) - claiming"):format(start, torTierAt(start))
            if claimAndHeart then subDidClaim = claimAndHeart()==true end
            subRunning=false subBtn.BackgroundColor3=C.green refreshSubLabels()
            return
        end

        local pass=0
        while subRunning and torSubmitted(name) < cap and pass < 4 do
            pass = pass + 1
            local have = torSubmitted(name)
            local need = cap - have

            local batch={}
            for _,t in ipairs(subTargets(name)) do
                if #batch >= need then break end
                if t.tool and t.tool.Parent then batch[#batch+1]=t end
            end
            if #batch==0 then break end

            local fired=0
            for _,en in ipairs(batch) do
                if not subRunning then break end
                torClearPopup(0.35)
                local t=en.tool
                if t and t.Parent then
                    local id=t:GetAttribute("ID")
                    if id and en.fav then pcall(function() FavItem:FireServer(id) end) task.wait(0.15) end
                    if subEquip(t) then
                        pcall(function() TorInteract:FireServer("RequestGive") end)
                        fired=fired+1
                        subLbl.Text=("pass %d: fired %d/%d  (booth %d/%d)"):format(pass,fired,#batch,have,cap)
                        task.wait(SUB_DELAY)
                    end
                end
            end

            if subRunning then torClearPopup(0.35) end
            task.wait(1)                                    -- let the tracker replicate

            local now = torSubmitted(name)
            subLbl.Text=("booth %d/%d %s"):format(now, cap, name)
            if fired==0 then break end                      -- nothing to fire, stop
            if now <= have then break end                   -- nothing landing, stop
        end

        local booth = torSubmitted(name)
        local tier  = torTierAt(booth)

        if booth >= cap and claimAndHeart then
            subLbl.Text=("booth %d = %s - claiming"):format(booth, tier)
            task.wait(0.3)
            subDidClaim = claimAndHeart()==true
            subLbl.Text = subDidClaim and ("claimed %s %s at %d"):format(tier,name,booth)
                                       or ("claim not detected (booth %d)"):format(booth)
        else
            -- Never claim short: at 24 with Neon needing 30 the game hands back
            -- a Frozen. Leave it in the booth and top up on the next pass.
            subLbl.Text=("booth %d/%d (%s) - holding, need %d more"):format(
                booth, cap, tier, math.max(0, cap-booth))
        end

        subRunning=false
        subBtn.BackgroundColor3=C.green
        refreshSubLabels()
    end


    subPlantBtn.MouseButton1Click:Connect(function()
        if subRunning then return end
        openPicker(subPlantBtn, function(n)
            getgenv().PvBSubPlant=n
            refreshSubLabels()
        end)
    end)
    claimBtn.MouseButton1Click:Connect(function()
        if subRunning then subLbl.Text="stop the run first" return end
        local name=getgenv().PvBSubPlant
        pcall(function() TorInteract:FireServer("CashOut", name) end)
        subLbl.Text="fired CashOut for "..name
    end)
    subBtn.MouseButton1Click:Connect(function()
        if subRunning then
            subRunning=false
            subBtn.BackgroundColor3=C.green
            refreshSubLabels()
            subLbl.Text="stopped"
            return
        end
        local limit=math.huge
        subRunning=true
        subBtn.Text="Stop"; subBtn.BackgroundColor3=C.red
        task.spawn(function() subRun(limit) end)
    end)

    function subStart(limit)
        if subRunning then return false end
        subRunning=true
        subBtn.Text="Stop"; subBtn.BackgroundColor3=C.red
        task.spawn(function() subRun(limit or math.huge) end)
        return true
    end

    -- fire CashOut for the picked plant, catch the returned tool's new ID, heart it
    claimAndHeart = function()
        local name=getgenv().PvBSubPlant
        local pre={}
        for _,t in ipairs(torPlantsOfType(name)) do
            local id=t:GetAttribute("ID")
            if id then pre[id]=true end
        end
        pcall(function() TorInteract:FireServer("CashOut", name) end)
        local newTool
        local t0=os.clock()
        while os.clock()-t0<4 do
            for _,t in ipairs(torPlantsOfType(name)) do
                local id=t:GetAttribute("ID")
                if id and not pre[id] then newTool=t break end
            end
            if newTool then break end
            task.wait(0.1)
        end
        if newTool then
            pcall(function() FavItem:FireServer(newTool:GetAttribute("ID")) end)
            return true
        end
        return false
    end

    end
    __buildTornado()

    local function __buildAscended()
    ------------------------------------------------------------------
    -- Ascended event: mirrors the Tornado feature.
    -- Feed loop: Standard = unhearted Cactus, or a picked plant.
    -- Progress per plant type: Data.AscendedTracker[name] = {count,...}
    -- Ladder (EventTracks.Ascended, production): Corrupted 3, Gold 6,
    -- AmpedUp 9, Diamond 12, Ruby 18, Frozen 25, Neon 38, Ascended 50.
    -- Submit block: submit up to the chosen tier; claim = CashOut(plant).
    ------------------------------------------------------------------
    local AscInteract
    lazyRemote({"Remotes","Events","Ascended","Interact"}, function(r) AscInteract = r end)
    -- ladder read from the game's own EventTracks.Ascended at runtime, so the
    -- thresholds always match THIS place (the module halves costs on some
    -- PlaceIds: 2/4/6/8/10/12/14/16 vs 3/6/9/12/18/25/38/50)
    local ASC_LADDER = {
        { name="Corrupted", n=3 },
        { name="Gold",      n=6 },
        { name="AmpedUp",   n=9 },
        { name="Diamond",   n=12 },
        { name="Ruby",      n=18 },
        { name="Frozen",    n=25 },
        { name="Neon",      n=38 },
        { name="Ascended",  n=50 },
    }
    pcall(function()
        local m = require(RS.Modules.Library.EventTracks.Ascended)
        local t = m and m.Mutations
        if type(t)=="table" then
            local out={}
            for _,e in ipairs(t) do
                local n=tonumber(e.PlantsRequired)
                if e.Name and e.Name~="Normal" and n and n>0 then out[#out+1]={name=e.Name,n=n} end
            end
            if #out>0 then
                table.sort(out,function(a,b) return a.n<b.n end)
                ASC_LADDER=out
            end
        end
    end)
    local function ascCount(name)
        local d=torData()
        local t=d and d.AscendedTracker and d.AscendedTracker[name]
        if type(t)=="table" then return tonumber(t[1]) or 0 end
        return tonumber(t) or 0
    end
    local function ascTierFor(c)
        local cur,nxt="Normal",ASC_LADDER[1]
        for _,e in ipairs(ASC_LADDER) do
            if c>=e.n then cur=e.name else nxt=e break end
        end
        if c>=ASC_LADDER[#ASC_LADDER].n then nxt=nil end
        return cur,nxt
    end
    -- reward track state: progress = Data.ClaimedRewards.Ascended, full = #RewardTracks.Ascended.
    -- Reset fires ONLY when the track is actually complete (it costs money) and
    -- waits for the server to confirm the rollback. Never scans GUI text: the
    -- booth's surface GUI (with its permanent "Reset Event!" label) lives
    -- reparented inside PlayerGui, so text-scanning fires paid resets nonstop.
    local ascTrackCount = 30
    pcall(function()
        local n=0
        for _ in pairs(require(RS.Modules.Library.RewardTracks.Ascended)) do n=n+1 end
        if n>0 then ascTrackCount=n end
    end)
    local function ascProgress()
        local d=torData()
        local v=d and d.ClaimedRewards and d.ClaimedRewards.Ascended
        return tonumber(v) or 0
    end
    local function ascMaybeReset(lbl)
        if ascProgress() < ascTrackCount then return end
        if lbl then lbl.Text=("track full (%d/%d) - resetting"):format(ascProgress(),ascTrackCount) end
        pcall(function() AscInteract:FireServer("Reset") end)
        local t0=os.clock()
        while os.clock()-t0<4 and ascProgress()>=ascTrackCount do task.wait(0.1) end
    end

    if getgenv().PvBAscMode     == nil then getgenv().PvBAscMode     = "standard" end
    if getgenv().PvBAscPlant    == nil then getgenv().PvBAscPlant    = "Corn Cobblazzio" end
    if getgenv().PvBAscSubPlant == nil then getgenv().PvBAscSubPlant = "Corn Cobblazzio" end
    if getgenv().PvBAscSubMut   == nil then getgenv().PvBAscSubMut   = "Ascended" end

    local ascBtn      = mkButton(ascGroup,"Ascended: OFF",C.grey,UDim2.new(1,0,0,30),UDim2.fromOffset(0,24))
    local ascModeBtn  = mkButton(ascGroup,"Mode: Standard (Cactus)",C.blue,UDim2.new(1,0,0,26),UDim2.fromOffset(0,58))
    local ascPlantBtn = mkButton(ascGroup,"Plant: "..getgenv().PvBAscPlant,C.blue,UDim2.new(1,0,0,26),UDim2.fromOffset(0,88))
    local ascLbl      = mkLabel(ascGroup,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,118),C.dim,Enum.Font.Gotham,12)
    local function ascRefreshMode()
        local pk = getgenv().PvBAscMode=="pick"
        ascModeBtn.Text = pk and "Mode: Feed picked plant" or "Mode: Standard (Cactus)"
        ascModeBtn.BackgroundColor3 = pk and C.purple or C.blue
        ascPlantBtn.Text = "Plant: "..getgenv().PvBAscPlant
        ascPlantBtn.Visible = pk
    end

    local function ascFeedLoop()
        local name = (getgenv().PvBAscMode=="pick") and getgenv().PvBAscPlant or "Cactus"
        while getgenv().PvBAscended do
            if getgenv().PvBAscPause then
                getgenv().PvBAscPaused=true
                ascLbl.Text="paused (battery)"
                task.wait(0.1)
            else
            getgenv().PvBAscPaused=false
            ascMaybeReset(ascLbl)
            local plant
            for _,t in ipairs(torPlantsOfType(name)) do if not torFav(t:GetAttribute("ID")) then plant=t break end end
            if not plant then ascLbl.Text="waiting for "..name.."..." task.wait(1)
            else
                if torEquip(plant) then
                    pcall(function() AscInteract:FireServer("RequestGive") end)
                    pcall(function() AscInteract:FireServer("CashOut", name) end)
                end
                local c=ascCount(name)
                local cur=select(1,ascTierFor(c))
                ascLbl.Text = ("track %d/%d | %s: %d [%s]"):format(ascProgress(),ascTrackCount,name,c,cur)
                task.wait(0.009)
            end
            end
        end
        getgenv().PvBAscPaused=false
    end

    -- Ascended upsize: the SAME shared loop the Tornado upsize runs, pointed at
    -- the Ascended Interact remote. Identical pacing and behaviour by design.
    function ascUpsizeLoop()
        ascBtn.Text="Ascended: ON" ascBtn.BackgroundColor3=C.green
        upsizeLoop(AscInteract, function() return getgenv().PvBAscended end, ascLbl, nil,
            function() ascMaybeReset(ascLbl) end)
        getgenv().PvBAscended=false
        ascBtn.Text="Ascended: OFF" ascBtn.BackgroundColor3=C.grey
    end

    ascBtn.MouseButton1Click:Connect(function()
        if getgenv().PvBAscended then getgenv().PvBAscended=false return end
        if not AscInteract then ascLbl.Text="Interact remote missing" return end
        getgenv().PvBAscended=true
        ascBtn.Text="Ascended: ON" ascBtn.BackgroundColor3=C.green
        setStatus("Ascended: "..getgenv().PvBAscMode)
        task.spawn(function()
            ascFeedLoop()
            getgenv().PvBAscended=false
            ascBtn.Text="Ascended: OFF" ascBtn.BackgroundColor3=C.grey
        end)
    end)
    ascModeBtn.MouseButton1Click:Connect(function()
        getgenv().PvBAscMode = (getgenv().PvBAscMode=="pick") and "standard" or "pick"
        ascRefreshMode()
    end)
    ascPlantBtn.MouseButton1Click:Connect(function()
        openPicker(ascPlantBtn, function(n) getgenv().PvBAscPlant=n ascRefreshMode() end)
    end)
    ascRefreshMode()

    -- Submit to Ascended: submit the picked plant up to the chosen tier,
    -- never past it, never cashing out. Claim = CashOut(plant), hearts result.
    local ascSubRunning=false
    local function ascSubEntry()
        for _,e in ipairs(ASC_LADDER) do if e.name==getgenv().PvBAscSubMut then return e end end
        return ASC_LADDER[#ASC_LADDER]
    end
    local ascSubPlantBtn = mkButton(ascGroup,"Submit plant: "..getgenv().PvBAscSubPlant,C.blue,UDim2.new(1,0,0,26),UDim2.fromOffset(0,172))
    local ascSubBtn      = mkButton(ascGroup,"Submit to tier",C.green,UDim2.new(0.55,-3,0,30),UDim2.fromOffset(0,202))
    local ascSubMutBtn   = mkButton(ascGroup,"",C.row,UDim2.new(0.45,-3,0,30),UDim2.new(0.55,3,0,202))
    local ascClaimBtn    = mkButton(ascGroup,"Claim back: "..getgenv().PvBAscSubPlant,C.amber,UDim2.new(1,0,0,26),UDim2.fromOffset(0,236))
    local ascSubLbl      = mkLabel(ascGroup,"idle",UDim2.new(1,0,0,20),UDim2.fromOffset(0,266),C.dim,Enum.Font.Gotham,12)
    local function ascRfSub()
        local e=ascSubEntry()
        ascSubMutBtn.Text=("%s (%d)"):format(e.name,e.n)
        ascSubPlantBtn.Text="Submit plant: "..getgenv().PvBAscSubPlant
        ascClaimBtn.Text="Claim back: "..getgenv().PvBAscSubPlant
        if not ascSubRunning then ascSubBtn.Text="Submit to tier" end
    end
    local function ascSubRun()
        local name=getgenv().PvBAscSubPlant
        local goal=ascSubEntry().n
        while ascSubRunning and getgenv().PvBAscSubMutGoal==goal do
            local c=ascCount(name)
            if c>=goal then ascSubLbl.Text=("%s at %d/%d - tier reached"):format(name,c,goal) break end
            ascMaybeReset(nil)
            local plant
            for _,t in ipairs(torPlantsOfType(name)) do if not torFav(t:GetAttribute("ID")) then plant=t break end end
            if not plant then ascSubLbl.Text=("out of unhearted %s at %d/%d"):format(name,c,goal) break end
            if torEquip(plant) then
                pcall(function() AscInteract:FireServer("RequestGive") end)
                ascSubLbl.Text=("%s: %d/%d"):format(name,c+1,goal)
                task.wait(0.3)
            else task.wait(0.05) end
        end
        ascSubRunning=false
        ascSubBtn.BackgroundColor3=C.green
        ascRfSub()
    end
    ascSubBtn.MouseButton1Click:Connect(function()
        if ascSubRunning then ascSubRunning=false ascSubLbl.Text="stopped" return end
        if not AscInteract then ascSubLbl.Text="Interact remote missing" return end
        ascSubRunning=true
        getgenv().PvBAscSubMutGoal=ascSubEntry().n
        ascSubBtn.Text="Stop" ascSubBtn.BackgroundColor3=C.red
        task.spawn(ascSubRun)
    end)
    ascSubMutBtn.MouseButton1Click:Connect(function()
        local cur=ascSubEntry()
        for i,e in ipairs(ASC_LADDER) do
            if e.name==cur.name then
                getgenv().PvBAscSubMut = ASC_LADDER[(i % #ASC_LADDER)+1].name
                break
            end
        end
        ascRfSub()
    end)
    ascSubPlantBtn.MouseButton1Click:Connect(function()
        openPicker(ascSubPlantBtn, function(n) getgenv().PvBAscSubPlant=n ascRfSub() end)
    end)
    ascClaimBtn.MouseButton1Click:Connect(function()
        if not AscInteract then ascSubLbl.Text="Interact remote missing" return end
        local name=getgenv().PvBAscSubPlant
        local c=ascCount(name)
        if c<=0 then ascSubLbl.Text="nothing submitted for "..name return end
        local pre={}
        for _,t in ipairs(torPlantsOfType(name)) do
            local id=t:GetAttribute("ID") if id then pre[id]=true end
        end
        pcall(function() AscInteract:FireServer("CashOut", name) end)
        ascSubLbl.Text=("claimed %s at %d submitted - watching for it"):format(name,c)
        task.spawn(function()
            local t0=os.clock()
            while os.clock()-t0<4 do
                for _,t in ipairs(torPlantsOfType(name)) do
                    local id=t:GetAttribute("ID")
                    if id and not pre[id] then
                        pcall(function() FavItem:FireServer(id) end)
                        ascSubLbl.Text=("claimed + hearted [%s] %s"):format(t:GetAttribute("Colors") or "?", name)
                        return
                    end
                end
                task.wait(0.1)
            end
            ascSubLbl.Text="claim fired but no new tool seen (bag full?)"
        end)
    end)
    ascRfSub()
    end
    __buildAscended()

    ------------------------------------------------------------------
    -- Plant tab "Advanced": collapsible, default closed. Order inside:
    -- Auto Plant Fuser -> OP Plant Maker -> OP Troll Mango Cycle.
    -- OP Maker and the Cycle each carry a slim "v" segment on their own
    -- row that unfolds their options in place - no orphan buttons.
    ------------------------------------------------------------------
    local function __buildAdvanced()
    local ADV_Y = 262
    local advHdr = mkButton(plantTab,"Advanced  >",C.row,UDim2.new(1,0,0,22),UDim2.fromOffset(0,ADV_Y))
    advHdr.TextXAlignment=Enum.TextXAlignment.Left
    do local p=Instance.new("UIPadding",advHdr) p.PaddingLeft=UDim.new(0,8) end
    local advBox = Instance.new("Frame")
    advBox.Name="PlantAdvanced"; advBox.BackgroundTransparency=1
    advBox.Position=UDim2.fromOffset(0,ADV_Y+28); advBox.Size=UDim2.new(1,0,0,0)
    advBox.Visible=false; advBox.Parent=plantTab
    local advRelayout   -- assigned once every advanced row exists (end of the Cycle block)
    advHdr.MouseButton1Click:Connect(function()
        advBox.Visible = not advBox.Visible
        advHdr.Text = advBox.Visible and "Advanced  v" or "Advanced  >"
        if advRelayout then advRelayout() end
    end)

    if getgenv().PvBOPMut==nil then getgenv().PvBOPMut="Tornado" end
    local opRunning=false
    local opBtn = mkButton(advBox,"OP Plant Maker: OFF",C.grey,UDim2.new(1,-34,0,30),UDim2.fromOffset(0,0))
    local opAdvBtn = mkButton(advBox,"v",C.row,UDim2.fromOffset(30,30),UDim2.new(1,-30,0,0))
    opAdvBtn.TextSize=11; opAdvBtn.TextColor3=C.dim
    local opLbl = mkLabel(advBox,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,34),C.dim,Enum.Font.Gotham,12)
    -- mutation chips: which submit target OP Maker drives (the Fuser follows it too)
    local opMutRow = Instance.new("Frame")
    opMutRow.BackgroundTransparency=1; opMutRow.Size=UDim2.new(1,0,0,26)
    opMutRow.Visible=false; opMutRow.Parent=advBox
    local opChips={}
    local function rfOpChips()
        for _,c in ipairs(opChips) do
            local on = c.name==getgenv().PvBOPMut
            c.btn.BackgroundColor3 = on and (c.col or C.purple) or C.row
            c.btn.TextColor3 = on and Color3.new(1,1,1) or C.dim
        end
    end
    for i,e in ipairs(MUT_CAPS) do
        local b=mkButton(opMutRow, ("%s %d"):format(e.name:sub(1,3), e.n), C.row, UDim2.new(0.2,-3,1,0), UDim2.new((i-1)*0.2,(i>1) and 3 or 0,0,0))
        b.TextSize=10
        b.MouseButton1Click:Connect(function()
            getgenv().PvBOPMut=e.name
            saveMisc() rfOpChips()
        end)
        opChips[#opChips+1]={name=e.name, col=e.col, btn=b}
    end
    rfOpChips()
    -- seed refill target: how many forbidden seeds to fish up before the
    -- pipeline goes back to planting
    if getgenv().PvBOPSeedTarget==nil then getgenv().PvBOPSeedTarget=1000 end
    local opSeedRow = Instance.new("Frame")
    opSeedRow.BackgroundTransparency=1; opSeedRow.Size=UDim2.new(1,0,0,26)
    opSeedRow.Visible=false; opSeedRow.Parent=advBox
    mkLabel(opSeedRow,"Fish until seeds:",UDim2.new(1,-70,1,0),UDim2.new(),C.dim,Enum.Font.Gotham,12)
    local opSeedBox = Instance.new("TextBox")
    opSeedBox.Size=UDim2.fromOffset(62,24); opSeedBox.Position=UDim2.new(1,-62,0,1)
    opSeedBox.BackgroundColor3=C.field; opSeedBox.TextColor3=C.txt
    opSeedBox.Font=Enum.Font.GothamMedium; opSeedBox.TextSize=12; opSeedBox.ClearTextOnFocus=false
    opSeedBox.BorderSizePixel=0; opSeedBox.Text=tostring(getgenv().PvBOPSeedTarget)
    opSeedBox.Parent=opSeedRow; corner(opSeedBox,6)
    opSeedBox.FocusLost:Connect(function()
        local n=tonumber(opSeedBox.Text)
        if n and n>=1 then getgenv().PvBOPSeedTarget=math.floor(n) saveMisc() end
        opSeedBox.Text=tostring(getgenv().PvBOPSeedTarget)
    end)
    opAdvBtn.MouseButton1Click:Connect(function()
        opMutRow.Visible = not opMutRow.Visible
        opSeedRow.Visible = opMutRow.Visible
        opAdvBtn.Text = opMutRow.Visible and "^" or "v"
        if advRelayout then advRelayout() end
    end)

    -- Forbidden seeds the pipeline runs on, in planting order: drain kelp
    -- first, then corn, then go fishing for more. Fusing needs 3x 20kg of
    -- one mutation and both types fuse, so either is equally good stock.
    local OP_SEEDS = { "Kelp", "Corn" }
    if getgenv().PvBOPSeedTarget==nil then getgenv().PvBOPSeedTarget=1000 end

    -- count seed TOOLS in the bag whose name matches one of the forbidden types
    local function opSeedTools(kind)
        local out={}
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") then
                    local sn = t:GetAttribute("SeedName")
                    if sn then
                        local h = tostring(sn):lower()
                        if (not kind) or h:find(tostring(kind):lower(),1,true) then out[#out+1]={tool=t, seedName=sn} end
                    end
                end
            end end
        end
        return out
    end
    -- SEED STACKS.
    -- Seeds stack: 1300 corn seeds is ONE tool carrying a quantity, not 1300
    -- tools. Counting tool objects therefore returned ~2 for a bag holding
    -- 1800 seeds, so a 1000 target could never be reached and the pipeline
    -- fished forever. Read the stack quantity, falling back to 1 for a tool
    -- that genuinely represents a single seed.
    local SEED_QTY_ATTRS = { "Count","Amount","Quantity","Stack","StackCount",
                             "Stacks","Num","Number","Seeds","SeedCount","Total" }
    local function seedQty(t)
        for _,a in ipairs(SEED_QTY_ATTRS) do
            local v = tonumber(t:GetAttribute(a))
            if v and v >= 1 then return math.floor(v) end
        end
        return 1
    end
    local function opSeedCount(kind)
        local n = 0
        for _,e in ipairs(opSeedTools(kind)) do n = n + seedQty(e.tool) end
        return n
    end

    -- Diagnostic: run getgenv().PvBDumpSeed() in the executor console to print
    -- every attribute on the first seed tool found. If the quantity attribute
    -- is named something not in the list above, this is how to find it.
    getgenv().PvBDumpSeed = function()
        local list = opSeedTools(nil)
        if #list == 0 then warn("[PvB] no seed tools in bag") return end
        for i,e in ipairs(list) do
            if i > 3 then break end
            local t = e.tool
            warn(("[PvB] seed tool %d: %s  (SeedName=%s)"):format(i, t.Name, tostring(e.seedName)))
            local attrs = t:GetAttributes()
            local any = false
            for k,v in pairs(attrs) do
                warn(("        %s = %s  (%s)"):format(tostring(k), tostring(v), typeof(v)))
                any = true
            end
            if not any then warn("        (no attributes)") end
            warn(("        -> seedQty() reads: %d"):format(seedQty(t)))
        end
    end
    -- the harvested PLANT name matching a forbidden type ("Corn Cobblazzio"),
    -- found from what is actually in the bag rather than hardcoded
    local function opPlantNameFor(kind)
        kind = tostring(kind):lower()
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:HasTag("PlantTool") then
                    local nm = t:GetAttribute("PlantName") or t.Name
                    if nm and tostring(nm):lower():find(kind,1,true) then return nm end
                end
            end end
        end
        return nil
    end
    local function opForbiddenSeedCount()
        local n=0
        for _,k in ipairs(OP_SEEDS) do n = n + opSeedCount(k) end
        return n
    end

    ------------------------------------------------------------------
    -- PIPELINE PHASE, PERSISTED PER ACCOUNT.
    --   "plant"  = generating plants from seeds
    --   "refill" = seeds exhausted, fishing until the target is reached
    --
    -- This has to survive a client restart. Without it, a client that had
    -- run itself out of seeds and switched to fishing would come back up,
    -- see the handful of seeds fishing had already produced, and go
    -- straight back to planting - undoing the refill decision every time
    -- the instance was reopened.
    --
    -- The file is per-username on purpose. The shared misc save is written
    -- by all 12 clients and they would stomp each other's phase.
    ------------------------------------------------------------------
    local OP_STATE  = "PvBOPState_"..tostring(LocalPlayer.Name)..".json"
    local opPhase   = "plant"
    local function opSavePhase()
        pcall(function()
            if type(writefile)=="function" then
                writefile(OP_STATE, HttpService:JSONEncode({ phase=opPhase, t=os.time() }))
            end
        end)
    end
    local function opLoadPhase()
        pcall(function()
            if type(isfile)=="function" and type(readfile)=="function" and isfile(OP_STATE) then
                local d = HttpService:JSONDecode(readfile(OP_STATE))
                if type(d)=="table" and (d.phase=="plant" or d.phase=="refill") then
                    opPhase = d.phase
                end
            end
        end)
    end
    local function opSetPhase(p)
        if opPhase ~= p then opPhase = p opSavePhase() end
        getgenv().PvBOPPhasePub = p     -- read by the fleet console
    end

    ------------------------------------------------------------------
    -- FISHING OWNERSHIP.
    -- Fishing is correct in exactly one situation: the refill phase.
    -- During plant / upsize / submit it must be off, or the client fishes
    -- and hands plants in at the same time. Because PvBAutoFish is restored
    -- from the shared save on inject, it can come back ON while the phase
    -- says "plant", so the loop reconciles it rather than trusting it.
    ------------------------------------------------------------------
    local function opSyncFishing(shouldFish)
        if shouldFish then
            if not getgenv().PvBAutoFish then
                getgenv().PvBAutoFish = true
                getgenv().PvBFishByOP = true
                pcall(rfFish)
            end
        else
            -- only stand down fishing that OP itself started, so a client
            -- deliberately left fishing by hand is not overridden
            if getgenv().PvBAutoFish and getgenv().PvBFishByOP then
                getgenv().PvBAutoFish = false
                getgenv().PvBFishByOP = nil
                pcall(rfFish)
            end
        end
    end
    local function opReleaseFishing()
        if getgenv().PvBFishByOP then
            getgenv().PvBAutoFish = false
            getgenv().PvBFishByOP = nil
            pcall(rfFish)
        end
    end

    local function opLoop()
        -- Wait for the plant API rather than switching off. Auto-inject can
        -- fire before the Plant tab has finished building, and a pipeline
        -- that is meant to run for days must not die because it started
        -- half a second early.
        local P=getgenv().PvBPlantAPI
        while opRunning and alive() and not P do
            opLbl.Text="waiting for plant API..."
            task.wait(1)
            P=getgenv().PvBPlantAPI
        end
        if not (opRunning and alive()) then return end

        opLoadPhase()
        getgenv().PvBOPPhasePub = opPhase
        -- RECONCILE ON START. PvBAutoFish may have been restored ON from the
        -- shared save while this account's phase says "plant". Make the world
        -- match the phase before doing anything.
        if opPhase ~= "refill" and getgenv().PvBAutoFish then
            getgenv().PvBAutoFish = false
            getgenv().PvBFishByOP = nil
            pcall(rfFish)
            setStatus("OP resume: fishing stood down (phase is planting)")
        end
        opLbl.Text = (opPhase=="refill")
            and ("resuming in refill (fishing to %d seeds)"):format(math.max(tonumber(getgenv().PvBOPSeedTarget) or 1000,1))
            or  "resuming in planting"

        -- Pick the seed to run this pass: first forbidden type we still hold.
        -- Returns nil when both are exhausted, which sends us fishing.
        local function opPickSeed()
            for _,k in ipairs(OP_SEEDS) do
                local have = opSeedTools(k)
                if #have > 0 then
                    if P.setSeed(have[1].seedName) then return have[1].seedName, #have end
                end
            end
            return nil
        end

        -- FISHING REFILL - one tick, then hand control back to the main loop.
        -- The old version blocked here and gave up (halting the whole maker)
        -- if it ever saw PvBAutoFish go false. Plenty of things legitimately
        -- clear that flag, so instead we simply re-arm it every tick and let
        -- the outer loop re-evaluate. Nothing in here can stop the pipeline.
        local function opRefillTick()
            local target = math.max(tonumber(getgenv().PvBOPSeedTarget) or 1000, 1)
            local n = opForbiddenSeedCount()
            if n >= target then
                opSyncFishing(false)
                return true                       -- restocked
            end
            opSyncFishing(true)                   -- re-arm whatever turned it off
            -- distinguish "fishing" from "flag on but the remotes are missing",
            -- which otherwise looks identical from the outside: a client that
            -- just sits there doing nothing
            -- show the tool count alongside the seed count: if these are wildly
            -- different the stack quantity is being read, if they are equal the
            -- quantity attribute was not found and seeds are counting 1 each
            local tools = #opSeedTools(nil)
            if not (Fishable and FishDone) then
                opLbl.Text = ("refill: %d/%d seeds (%d stacks) - FISHING REMOTES MISSING"):format(n, target, tools)
            else
                opLbl.Text = ("refill: fishing %d/%d seeds (%d stacks)"):format(n, target, tools)
            end
            task.wait(3)
            return false
        end

        -- how many submits make one mutated plant for the chosen mutation
        local function opCap()
            local want = getgenv().PvBOPMut or getgenv().PvBSubMut
            for _,e in ipairs(MUT_CAPS) do if e.name==want then return e.n end end
            return (MUT_CAPS[1] and MUT_CAPS[1].n) or 75
        end

        -- plants of this type still below target weight and not hearted
        local function opPendingCount(plantName)
            local favs, pending = torFavs(), 0
            for _,t in ipairs(torPlantsOfType(plantName)) do
                local id=t:GetAttribute("ID")
                if id and not favs[id] and plantWeight(t)<TARGET_KG then pending = pending + 1 end
            end
            return pending
        end

        ----------------------------------------------------------------
        -- DEADLOCK BREAKER
        --
        -- The jam: a bag full of 20kg plants split across BOTH forbidden
        -- types, neither side reaching the mutation cap. Nothing to upsize,
        -- no batch to submit, and no room to harvest more - so the planter
        -- reports "inventory full" forever.
        --
        -- Confirmed sell contract, read out of the game's own sell NPC:
        --     ItemSell:FireServer()            all unhearted BRAINROTS
        --     ItemSell:FireServer(nil, true)   all unhearted PLANTS
        --     ItemSell:FireServer(true)        the EQUIPPED item only
        --
        -- Everything below uses the third form. It cannot touch anything we
        -- did not personally equip first, so a mistake costs one plant
        -- instead of a bagful. Mass sell-all is never used here.
        ----------------------------------------------------------------
        local ItemSellR = RS.Remotes:FindFirstChild("ItemSell")

        -- sell exactly one tool: unheart if needed, equip, fire, verify
        local function opSellOne(t)
            if not (t and t.Parent and ItemSellR) then return false end
            local id = t:GetAttribute("ID")
            if id and torFavs()[id] then
                pcall(function() FavItem:FireServer(id) end)
                task.wait(0.15)
            end
            if not torEquip(t) then return false end
            pcall(function() ItemSellR:FireServer(true) end)
            local w=0
            while t.Parent and w<1.2 do task.wait(0.05) w=w+0.05 end
            return t.Parent == nil
        end

        local function opBagPlants()
            local out={}
            for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
                if c then for _,t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") and (t:HasTag("PlantTool") or t:GetAttribute("PlantName")) then
                        out[#out+1]=t
                    end
                end end
            end
            return out
        end

        -- STEP 1: Dessert Destroyers are the 99% fuse byproduct and pile up
        -- unused. Sell them, but always keep one Tornado and one Ascended if
        -- this account has them. Spelling-tolerant match on "destroyer".
        local function opSellDestroyers()
            local keepTor, keepAsc = false, false
            local sold = 0
            for _,t in ipairs(opBagPlants()) do
                local nm = tostring(t:GetAttribute("PlantName") or t.Name):lower()
                if nm:find("destroyer",1,true) then
                    local mut = tostring(plantColors(t) or "Normal")
                    if mut=="Tornado" and not keepTor then
                        keepTor = true                      -- keep this one
                    elseif mut=="Ascended" and not keepAsc then
                        keepAsc = true                      -- keep this one
                    else
                        if opSellOne(t) then
                            sold = sold + 1
                            opLbl.Text = ("unblocking: sold %d Dessert Destroyer(s)"):format(sold)
                            task.wait(0.1)
                        end
                    end
                end
                if not opRunning then break end
            end
            return sold
        end

        -- STEP 2: still jammed. Work out which type is CLOSEST to a full
        -- batch, then free exactly enough room by selling the OTHER type -
        -- the one we are not trying to complete. Sells the lightest first so
        -- finished 20kg stock is sacrificed last.
        local function opFreeRoomFor(cap)
            local best, bestDef, other = nil, math.huge, nil
            for _,k in ipairs(OP_SEEDS) do
                local nm = opPlantNameFor(k)
                if nm then
                    local def = cap - #subTargets(nm)
                    if def > 0 and def < bestDef then bestDef, best = def, nm end
                end
            end
            if not best then return 0 end
            for _,k in ipairs(OP_SEEDS) do
                local nm = opPlantNameFor(k)
                if nm and nm ~= best then other = nm break end
            end
            if not other then return 0 end

            -- a couple spare slots so harvesting has somewhere to land
            local want = math.min(bestDef + 2, 40)
            local pool = {}
            for _,t in ipairs(torPlantsOfType(other)) do pool[#pool+1]=t end
            table.sort(pool, function(a,b) return plantWeight(a) < plantWeight(b) end)

            local sold = 0
            for _,t in ipairs(pool) do
                if sold >= want or not opRunning then break end
                if opSellOne(t) then
                    sold = sold + 1
                    opLbl.Text = ("unblocking: freed %d/%d slots (sold %s)"):format(sold, want, other)
                    task.wait(0.1)
                end
            end
            return sold
        end

        -- Decide purely from current state, so it can start at any point.
        -- DRAIN-FIRST: keep submitting/upsizing while another full batch is
        -- still reachable from what's already in the bag. A bag of 120 corn
        -- with Neon (30) selected now yields 4 neons before replanting,
        -- instead of one neon and a trip back to the watering cycle.
        local function opStage(plantName)
            local cap   = opCap()
            local ready = #subTargets(plantName)          -- Normal and >= 20kg: submit-ready
            if ready >= cap then return "submit" end      -- full batch in hand: fire it now

            local favs, pending = torFavs(), 0            -- below weight but still growable
            for _,t in ipairs(torPlantsOfType(plantName)) do
                local id=t:GetAttribute("ID")
                if id and not favs[id] and plantWeight(t)<TARGET_KG then pending = pending + 1 end
            end
            if ready + pending >= cap then return "upsize" end   -- one more batch is reachable

            -- can't complete another batch from stock: only now go get more seeds
            local nearFull = P.invFull() or (P.invNearFull and P.invNearFull(3))
            if not nearFull then return "plant" end
            if pending > 0 then return "upsize" end
            return "submit"    -- bag full: fire the partial (or halt if nothing to fire)
        end

        local opBlocked = 0
        local opLastUnblock = 0     -- cooldown so a jam cannot cause a sell spiral
        while opRunning and alive() do
            -- WORK IN HAND FIRST, but only work that can ACTUALLY proceed.
            --
            -- opStage falls back to "submit" whenever the bag is near-full,
            -- even when there is nothing submittable - which happens as soon
            -- as the bag fills with plants that are already mutated or
            -- hearted, since those are neither submit-ready nor upsizable.
            -- Committing to that stage on trust is what produced the endless
            -- "nothing to submit yet - waiting". Verify before committing.
            --
            -- SUBMIT REQUIRES A FULL BATCH. This is the important line.
            -- opStage has a "bag full -> fire the partial" fallback, and
            -- last round I let the picker act on it whenever ONE plant was
            -- submit-ready. The result: submit 1, fail to reach cap, claim
            -- it straight back, repeat forever - and because each pass left
            -- fires in the booth, the booth would silently creep up to cap
            -- on its own and pop out mutated plants at random moments.
            -- That is both the "submitting and taking back a single plant"
            -- and the "stray frozen corns at the wrong count".
            --
            local cap = opCap()
            local plantName, stage, progress
            for _,k in ipairs(OP_SEEDS) do
                local nm = opPlantNameFor(k)
                if nm then
                    local ready = #subTargets(nm)
                    local pend  = opPendingCount(nm)
                    local roomless = P.invFull() or (P.invNearFull and P.invNearFull(3))
                    if ready >= cap then
                        plantName, stage = nm, "submit" break          -- full batch: fire it
                    elseif pend > 0 and ((ready + pend) >= cap or roomless) then
                        plantName, stage = nm, "upsize" break          -- a batch is reachable, or
                    end                                                -- no room so finish what we hold
                    if ready > 0 or pend > 0 then
                        progress = ("%s %d+%d/%d"):format(k, ready, pend, cap)
                    end
                end
            end

            -- Nothing to cash in, so it is plant-or-fish, and the PHASE
            -- decides which. Note there is no exit anywhere below: every
            -- branch either does work or waits and comes back round. The
            -- only thing that ends this loop is opRunning going false,
            -- which only the toggle does.
            if not plantName then
                -- NO GARDEN. An account whose base failed to load can still
                -- join, inject, and collect rewards, so from the outside it
                -- looks like it is working. It cannot plant. Say so loudly
                -- instead of cycling as though everything is fine - the
                -- launcher reads the same condition and will relaunch it.
                if getgenv().PvBBaseOK == false then
                    opLbl.Text = "NO GARDEN - base never loaded, cannot plant"
                    opSyncFishing(false)
                    task.wait(10)
                    continue
                end

                -- BLOCKED DETECTION. If several passes in a row produce no
                -- productive work, say exactly why instead of looking idle.
                -- The usual cause is a bag full of finished mutated plants:
                -- nothing to submit, nothing to upsize, no room to harvest.
                local seedsNow = opForbiddenSeedCount()
                local roomless = P.invFull() or (P.invNearFull and P.invNearFull(3))
                if roomless and seedsNow > 0 and opPhase ~= "refill" then
                    opBlocked = (opBlocked or 0) + 1
                    if opBlocked >= 3 then
                        local bits = {}
                        for _,k in ipairs(OP_SEEDS) do
                            local nm = opPlantNameFor(k)
                            if nm then
                                bits[#bits+1] = ("%s %d+%d/%d"):format(k, #subTargets(nm), opPendingCount(nm), cap)
                            end
                        end
                        opLbl.Text = ("JAMMED: %s batch short (%s) - freeing room"):format(
                            tostring(getgenv().PvBOPMut), (#bits>0 and table.concat(bits,", ") or "none held"))

                        -- UNBLOCK LADDER, gentlest first. Each rung re-tests
                        -- the real condition rather than trusting the "bag
                        -- full" text, which lingers for a few seconds after
                        -- space is actually freed and would otherwise read as
                        -- a false negative and trigger more selling.
                        local acted = false
                        if os.clock() - (opLastUnblock or 0) > 20 then
                            opLastUnblock = os.clock()

                            if opSellDestroyers() > 0 then acted = true end

                            -- let the bag settle, then ask the only question
                            -- that matters: is there room now?
                            if acted then
                                task.wait(2.5)
                                if not (P.invFull() or (P.invNearFull and P.invNearFull(3))) then
                                    opLbl.Text = "unjammed by selling Dessert Destroyers"
                                    opBlocked = 0
                                    continue
                                end
                            end

                            if opFreeRoomFor(cap) > 0 then
                                acted = true
                                task.wait(2.5)
                            end
                        end

                        if acted then
                            opBlocked = 0        -- re-evaluate from scratch
                            task.wait(1)
                        else
                            opLbl.Text = ("JAMMED: nothing left to sell (%s) - %d seeds waiting"):format(
                                (#bits>0 and table.concat(bits,", ") or "none held"), seedsNow)
                            task.wait(10)
                        end
                        continue
                    end
                end
                -- NOTE: deliberately no "else opBlocked = 0" here. invFull()
                -- flickers because the Keep tab frees slots constantly, and a
                -- single false sample used to wipe a jam streak the planter
                -- had legitimately earned. The counter is cleared only by real
                -- progress: a submit, an upsize, or a plant that actually ran.

                if opPhase == "refill" then
                    -- stay fishing until the target is hit, even if a few
                    -- seeds are already in the bag
                    if opRefillTick() then
                        opSetPhase("plant")
                    end
                    task.wait(0.2)
                    continue
                end

                local seed = opPickSeed()
                if not seed then
                    -- out of both forbidden seed types: switch phases and
                    -- let the next pass start fishing
                    opLbl.Text = "out of forbidden seeds - switching to refill"
                    opSetPhase("refill")
                    task.wait(0.5)
                    continue
                end
                plantName = (seed:gsub("%s*Seed$",""))
                stage = "plant"
            end

            -- Only submit/upsize count as progress. A plant PICK does not:
            -- having seeds in the bag is not the same as being able to plant
            -- them, and treating it as progress reset the jam counter every
            -- pass, making the whole unblock ladder unreachable.
            if stage ~= "plant" then opBlocked = 0 end
            opSyncFishing(false)     -- never fish while planting/upsizing/submitting
            getgenv().PvBTorPlant=plantName
            getgenv().PvBSubPlant=plantName
            getgenv().PvBSubMut=getgenv().PvBOPMut or getgenv().PvBSubMut   -- OP drives the submit target
            pcall(refreshMode) pcall(refreshSubLabels) pcall(rfMut)
            if stage=="plant" then
                -- Start every planting cycle from a genuinely empty garden:
                -- grow out anything still in the ground (watered the same
                -- efficient 3x3-cluster way the normal run waters), then pick
                -- every plant up. No garden loadout is loaded any more.
                if P.clearGarden then
                    pcall(function() P.clearGarden(function(m) opLbl.Text=m end, function() return opRunning end) end)
                end
                if not opRunning then break end
                opLbl.Text = progress
                    and ("planting %s  [%s toward %s]"):format(plantName, progress, tostring(getgenv().PvBOPMut))
                    or  ("planting "..plantName)
                P.setLoop(true) P.setSell(false)      -- selling would starve the pipeline
                P.start()
                while opRunning and P.isRunning() do task.wait(0.5) end
                if not opRunning then P.stop() break end
                -- decide from WHY it stopped, not a one-instant invFull() sample: the Keep
                -- tab's junk-selling frees slots so a strict check flickers false right
                -- when we look, which used to halt the whole pipeline here.
                local why = P.lastStop and P.lastStop() or nil
                local fullish = (why=="invfull")
                if not fullish then
                    for _=1,8 do                             -- sample ~4s; any hit counts
                        if P.invFull() or (P.invNearFull and P.invNearFull(3)) then fullish=true break end
                        task.wait(0.5)
                    end
                end
                if fullish then
                    -- Planted nothing because there is no room. THIS is the
                    -- jam, and it is where it must be counted: the picker
                    -- above will hand us the same seed again next pass.
                    opBlocked = (opBlocked or 0) + 1
                    opLbl.Text = ("bag full, cannot plant (jam %d/3)"):format(opBlocked)
                else
                    opBlocked = 0
                    -- Out of THIS seed just means rotate: the picker at the
                    -- top of the loop moves to the next forbidden type, or
                    -- parks on fishing if both are spent.
                    local left = opForbiddenSeedCount()
                    if left > 0 then
                        opLbl.Text=("planter stopped (%s) - %d seeds left, rotating"):format(tostring(why or "out of seeds"), left)
                    else
                        opLbl.Text="out of forbidden seeds - going fishing"
                    end
                end
            elseif stage=="upsize" then
                -- upsize through the ASCENDED event (same loop as Tornado's);
                -- submission further down still goes to Tornado.
                opLbl.Text="upsizing "..plantName.." (Ascended)"
                if not getgenv().PvBAscended then
                    getgenv().PvBAscended=true
                    task.spawn(ascUpsizeLoop)
                end
                while opRunning and getgenv().PvBAscended do task.wait(0.5) end
                if not opRunning then getgenv().PvBAscended=false break end
            else -- submit
                if #subTargets(plantName)==0 then
                    -- should be unreachable now that the stage picker verifies
                    -- actionability, but never sit on it: go round again
                    task.wait(1)
                    continue
                end
                opLbl.Text="submitting "..plantName
                subStart(math.huge)
                while opRunning and subRunning do task.wait(0.5) end
                if not opRunning then break end
                if subDidClaim then
                    opLbl.Text="claimed at cap + hearted"
                else
                    -- We entered with a full batch but fewer fires landed
                    -- (plants moved or a fire failed). Leave what IS in the
                    -- booth there so the next pass tops it up to cap. Pulling
                    -- it back out is what created the submit/claim churn.
                    opLbl.Text=("partial batch fired - leaving in booth to top up"):format()
                    task.wait(1)
                end
            end
            task.wait(0.8)
        end
        -- Reaching here means opRunning went false (the toggle) or the UI was
        -- torn down. No internal condition breaks the loop any more.
        opRunning=false
        opReleaseFishing()
        opBtn.Text="OP Plant Maker: OFF" opBtn.BackgroundColor3=C.grey
        if alive() then opLbl.Text="stopped" end
    end

    opBtn.MouseButton1Click:Connect(function()
        if opRunning then
            opRunning=false
            opReleaseFishing()                       -- do not leave refill fishing running
            getgenv().PvBOPRun=false saveMisc()      -- an explicit OFF sticks across reloads
            pcall(function() getgenv().PvBPlantAPI.stop() end)
            getgenv().PvBTornado=false
            if subRunning then subRunning=false subBtn.BackgroundColor3=C.green refreshSubLabels() end
            opBtn.Text="OP Plant Maker: OFF" opBtn.BackgroundColor3=C.grey
            opLbl.Text="stopped"
            return
        end
        opRunning=true
        getgenv().PvBOPRun=true saveMisc()           -- so Reload ALL brings it back on
        -- A MANUAL press is an explicit instruction, so if there are seeds in
        -- the bag start by planting them. A restart / auto-resume does NOT
        -- come through here, so it keeps whatever phase was saved.
        if opForbiddenSeedCount() > 0 then opSetPhase("plant") end
        opBtn.Text="OP Plant Maker: ON" opBtn.BackgroundColor3=C.green
        task.spawn(opLoop)
    end)

    getgenv().PvBOPStop = function(reason)
        if not opRunning then return end
        opRunning=false
        opReleaseFishing()
        pcall(function() getgenv().PvBPlantAPI.stop() end)
        if subRunning then subRunning=false subBtn.BackgroundColor3=C.green refreshSubLabels() end
        opBtn.Text="OP Plant Maker: OFF" opBtn.BackgroundColor3=C.grey
        opLbl.Text="stopped ("..tostring(reason or "manual")..")"
    end

    -- Resume across reloads. The toggle is saved, so a fleet Reload ALL brings
    -- every client back with the maker running. Auto-inject fires before assets
    -- finish loading, so wait for the plant API and a chosen seed to exist.
    task.spawn(function()
        if not getgenv().PvBOPRun then return end
        opLbl.Text="auto-resume armed (waiting for garden)..."
        local t0=os.clock()
        while alive() and os.clock()-t0 < 120 do
            local P=getgenv().PvBPlantAPI
            if P and P.seedName and P.seedName() then break end
            task.wait(2)
        end
        if not alive() or not getgenv().PvBOPRun or opRunning then return end
        local P=getgenv().PvBPlantAPI
        if not (P and P.seedName and P.seedName()) then
            opLbl.Text="auto-resume: pick a seed in the Plant tab"
            return
        end
        opRunning=true
        opBtn.Text="OP Plant Maker: ON" opBtn.BackgroundColor3=C.green
        opLbl.Text="auto-resumed after reload"
        task.spawn(opLoop)
    end)

    ------------------------------------------------------------------
    -- AFK-fishing suppressor: while the OP Plant Maker is on OR any
    -- planting loop is running, force "Start fishing when AFK" off and
    -- stand down idle-started fishing. When the run ends, restore the
    -- exact state it was in before (off stays off, on comes back on).
    ------------------------------------------------------------------
    task.spawn(function()
        while alive() do
            task.wait(1)
            local P = getgenv().PvBPlantAPI
            local planting = (P and P.isRunning and P.isRunning())==true
            local busy = opRunning or planting
            if busy and fishAfkSaved==nil then
                fishAfkSaved = (getgenv().PvBIdleFish~=false)      -- snapshot, then force off
                getgenv().PvBIdleFish = false
                rfIdleFish()
                if idleFishing then                                 -- idle already started fishing: stop it
                    idleFishing=false
                    getgenv().PvBAutoFish=false
                    rfFish()
                end
                setStatus("planting active: AFK fishing suppressed")
            elseif (not busy) and fishAfkSaved~=nil then
                getgenv().PvBIdleFish = fishAfkSaved
                fishAfkSaved = nil
                saveMisc()                                          -- heal any mid-run save that captured the forced OFF
                rfIdleFish()
                setStatus("planting done: AFK fishing restored ("..(getgenv().PvBIdleFish~=false and "ON" or "OFF")..")")
            end
        end
    end)


    ------------------------------------------------------------------
    -- Auto Plant Fuser: when the fuse machine is idle AND empty, load
    -- three 20kg forbidden plants of the SAME mutation (Tornado or
    -- Ascended; corn/kelp only), unhearting each first, then StartFuse.
    -- State checks are local data reads (no remote spam); remotes only
    -- fire when actually loading.
    ------------------------------------------------------------------
    local FUSE_TYPES = { ["Corn Cobblazzio"]=true, ["Kelp Katapulter"]=true }
    -- fuse target follows OP Plant Maker's mutation while it runs, otherwise
    -- the standalone Submit-to-Tornado dropdown selection
    local function fuseTargetMut()
        if opRunning then return getgenv().PvBOPMut or "Tornado" end
        return getgenv().PvBSubMut or "Tornado"
    end
    local FuseRem
    lazyRemote({"Remotes","PlantFuseMachine"}, function(r) FuseRem = r end)

    local function fuseData()
        local d=torData()
        return d and d.PlantFuseMachine or nil
    end
    local function fusePlacedCount()
        local f=fuseData()
        local p=f and f.PlacedPlants
        if type(p)~="table" then return 0 end
        local c=0 for _,v in pairs(p) do if v~=nil then c=c+1 end end
        return math.max(c,#p)
    end
    local function fuseIdle()
        local f=fuseData()
        if not f then return false end
        local st=f.FuseStarted
        return st==nil or st==-1        -- game treats FuseStarted ~= -1 as "fusing"
    end
    local function fuseCandidates()
        local favs=torFavs()
        local mut=fuseTargetMut()
        local list={}
        for _,c in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:HasTag("PlantTool") then
                    local nm=t:GetAttribute("PlantName") or t.Name
                    if FUSE_TYPES[nm] and plantWeight(t)>=(TARGET_KG-0.05) and plantColors(t)==mut then
                        list[#list+1]={tool=t, fav=favs[t:GetAttribute("ID")]}
                    end
                end
            end end
        end
        if #list>=3 then return mut, {list[1],list[2],list[3]} end
        return nil
    end

    local fuserOn=false
    local fuserBtn = mkButton(advBox,"Auto Plant Fuser: OFF",C.grey,UDim2.new(1,0,0,30),UDim2.fromOffset(0,0))
    local fuserLbl = mkLabel(advBox,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,34),C.dim,Enum.Font.Gotham,12)

    local fuserMut=nil   -- mutation of an in-progress load WE started (lets the loop resume it)
    local function fusePlaceOne(id, slot)
        local before=fusePlacedCount()
        for _=1,4 do
            pcall(function() FuseRem.PlacePlant:FireServer(id, slot) end)
            local t0=os.clock()
            while fusePlacedCount()<=before and os.clock()-t0<1.2 do task.wait(0.1) end
            if fusePlacedCount()>before then return true end
            task.wait(0.7)   -- server enforces a wait between placements; back off and refire
        end
        return false
    end
    local function fuseLoadAndStart(mut)
        fuserMut=mut
        while fuserOn and fusePlacedCount()<3 do
            local placed=fusePlacedCount()
            -- pick a fresh candidate of this mutation each pass
            local favs=torFavs()
            local pick
            for _,c in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
                if c and not pick then for _,t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") and t:HasTag("PlantTool") then
                        local nm=t:GetAttribute("PlantName") or t.Name
                        if FUSE_TYPES[nm] and plantWeight(t)>=(TARGET_KG-0.05) and plantColors(t)==mut then
                            pick={tool=t, fav=favs[t:GetAttribute("ID")]}
                            break
                        end
                    end
                end end
            end
            if not pick then
                fuserLbl.Text="ran out of "..mut.." candidates mid-load"
                return false
            end
            local t=pick.tool
            local id=t:GetAttribute("ID")
            if pick.fav then pcall(function() FavItem:FireServer(id) end) task.wait(0.2) end   -- must be unhearted
            if not torEquip(t) then
                fuserLbl.Text="equip failed, retrying"
                task.wait(0.5)
            elseif fusePlaceOne(id, placed+1) then
                fuserLbl.Text=("placed %d/3 (%s)"):format(fusePlacedCount(), mut)
                task.wait(0.8)   -- respect the placement cooldown before the next slot
            else
                fuserLbl.Text=("slot %d place failed, will retry"):format(placed+1)
                task.wait(1)
            end
        end
        if fusePlacedCount()>=3 then
            task.wait(0.3)
            pcall(function() FuseRem.StartFuse:FireServer() end)
            fuserLbl.Text="fuse started: 3x "..mut
            fuserMut=nil
            return true
        end
        return false
    end

    local function fuserLoop()
        while fuserOn and alive() do
            if not FuseRem then fuserLbl.Text="fuse remotes missing" break end
            local placed=fusePlacedCount()
            if fuseIdle() and placed==0 then
                local mut=fuseCandidates()
                if mut then
                    fuseLoadAndStart(mut)
                else
                    fuserLbl.Text="machine empty: need 3x 20kg "..fuseTargetMut().." corn/kelp"
                end
            elseif fuseIdle() and placed<3 and fuserMut then
                fuseLoadAndStart(fuserMut)               -- finish the load WE started
            elseif not fuseIdle() then
                fuserLbl.Text="fusing..."
            else
                fuserLbl.Text="machine has plants (manual) - waiting"
            end
            for _=1,80 do if not fuserOn then break end task.wait(0.1) end   -- ~8s cadence, quick stop
        end
        fuserOn=false
        fuserBtn.Text="Auto Plant Fuser: OFF" fuserBtn.BackgroundColor3=C.grey
    end

    fuserBtn.MouseButton1Click:Connect(function()
        if fuserOn then
            fuserOn=false
            fuserBtn.Text="Auto Plant Fuser: OFF" fuserBtn.BackgroundColor3=C.grey
            return
        end
        fuserOn=true
        fuserBtn.Text="Auto Plant Fuser: ON" fuserBtn.BackgroundColor3=C.green
        task.spawn(fuserLoop)
    end)

    task.defer(function()
        task.wait(1)
        if not fuserOn and FuseRem then
            fuserOn=true
            fuserBtn.Text="Auto Plant Fuser: ON" fuserBtn.BackgroundColor3=C.green
            task.spawn(fuserLoop)
        end
    end)


    ------------------------------------------------------------------
    -- Leaderboard Cycle: full private-server farm loop, one pass per join.
    -- wait data -> tornado standard until weather -> fish to bag target
    -- -> mango full garden + water (no harvest) -> troll check:
    --    troll: sell brainrots, pick up all, heart trolls, sell plants,
    --           ensure cactus, settle, drain bag -> rejoin
    --    no troll: rejoin immediately
    -- State in workspace file so it survives the rejoin; auto-arms on
    -- execute when the flag is on. Toggle OFF stops everything.
    ------------------------------------------------------------------
    local TeleportService = game:GetService("TeleportService")
    local CYC_FILE = "PvBCycle.json"
    local cyc = { on=false, fishTarget=1250, dataTargetMB=4.00, seed="Mango", runs=0, trolls=0, tornado=true, captureAll=false }
    pcall(function()
        if isfile and isfile(CYC_FILE) then
            local d=HttpService:JSONDecode(readfile(CYC_FILE))
            if type(d)=="table" then for k,v in pairs(d) do cyc[k]=v end end
        end
    end)
    -- migrate old saved targets: PvBCycle.json overrides the default above,
    -- so without this an existing save would keep the old value forever
    if cyc.dataTargetMB==4.05 or cyc.dataTargetMB==4.01 then cyc.dataTargetMB=4.00 end
    if getgenv().PvBIsMain then cyc.on=false end   -- main account never auto-arms the cycle
    local function cycSave() pcall(function() if writefile then writefile(CYC_FILE, HttpService:JSONEncode(cyc)) end end) end
    cycSave()
    -- persistent log: survives server hops, unlike the console
    local CYC_LOG = "PvBCycle_log.txt"
    local function cycLog(fmt, ...)
        local line = ("[%s run %d] "):format(os.date("%H:%M:%S"), tonumber(cyc.runs) or 0)..fmt:format(...)
        warn(line)
        pcall(function()
            if appendfile then appendfile(CYC_LOG, line.."\n")
            elseif writefile and readfile then
                local prev = (isfile and isfile(CYC_LOG)) and readfile(CYC_LOG) or ""
                writefile(CYC_LOG, prev..line.."\n")
            end
        end)
    end

    local cycBtn = mkButton(advBox,"OP Troll Mango Cycle: OFF",C.grey,UDim2.new(1,-34,0,30),UDim2.fromOffset(0,0))
    local cycAdvBtn = mkButton(advBox,"v",C.row,UDim2.fromOffset(30,30),UDim2.new(1,-30,0,0))
    cycAdvBtn.TextSize=11; cycAdvBtn.TextColor3=C.dim
    local cycTorBtn = mkButton(advBox,"Cycle tornado step: ON",C.green,UDim2.new(1,0,0,24),UDim2.fromOffset(0,0))
    local cycCapBtn = mkButton(advBox,"Capture: OP mutations",C.green,UDim2.new(1,0,0,24),UDim2.fromOffset(0,0))
    local cycLbl = mkLabel(advBox,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,0),C.dim,Enum.Font.Gotham,12)
    cycTorBtn.Visible=false cycCapBtn.Visible=false
    cycAdvBtn.MouseButton1Click:Connect(function()
        local show = not cycTorBtn.Visible
        cycTorBtn.Visible=show cycCapBtn.Visible=show
        cycAdvBtn.Text = show and "^" or "v"
        if advRelayout then advRelayout() end
    end)

    ------------------------------------------------------------------
    -- Advanced relayout: stacks Fuser -> OP Maker -> Cycle, folds each
    -- button's option rows in place, and resizes the Plant scroll.
    ------------------------------------------------------------------
    advRelayout = function()
        local y=0
        fuserBtn.Position=UDim2.fromOffset(0,y); y=y+34
        fuserLbl.Position=UDim2.fromOffset(0,y); y=y+24
        opBtn.Position=UDim2.fromOffset(0,y); opAdvBtn.Position=UDim2.new(1,-30,0,y); y=y+34
        if opMutRow.Visible then opMutRow.Position=UDim2.fromOffset(0,y); y=y+30 end
        if opSeedRow.Visible then opSeedRow.Position=UDim2.fromOffset(0,y); y=y+30 end
        opLbl.Position=UDim2.fromOffset(0,y); y=y+24
        cycBtn.Position=UDim2.fromOffset(0,y); cycAdvBtn.Position=UDim2.new(1,-30,0,y); y=y+34
        if cycTorBtn.Visible then cycTorBtn.Position=UDim2.fromOffset(0,y); y=y+28 end
        if cycCapBtn.Visible then cycCapBtn.Position=UDim2.fromOffset(0,y); y=y+28 end
        cycLbl.Position=UDim2.fromOffset(0,y); y=y+24
        advBox.Size=UDim2.new(1,0,0,y)
        local total = ADV_Y + 28 + (advBox.Visible and y or 0) + 24
        total = math.max(total, 480)
        plantTab.Size=UDim2.new(1,-12,0,total)
        pcall(function()
            local sc=plantTab.Parent
            sc.CanvasSize=UDim2.fromOffset(0,total)
            local sp=sc:FindFirstChild("PlantSpacer")
            if sp then sp.Position=UDim2.fromOffset(0,total-18) end
        end)
    end
    advRelayout()
    local function cycRefresh()
        getgenv().PvBCycleOn = cyc.on and true or false     -- idle watcher reads this
        cycBtn.Text = "OP Troll Mango Cycle: "..(cyc.on and "ON" or "OFF")
        cycBtn.BackgroundColor3 = cyc.on and C.green or C.grey
    end
    -- the cycle cranks the fishing knobs; snapshot first, put them back after,
    -- and rewrite the misc save so a mid-cycle save can't poison future sessions
    local function restoreFish()
        local s=getgenv().PvBFishSnap
        if not s then return end
        if s.gap~=nil then getgenv().PvBFishGap=s.gap end
        if s.sell~=nil then getgenv().PvBFishSellEvery=s.sell end
        getgenv().PvBFishSnap=nil
        saveMisc()   -- heal any mid-cycle save without dropping the newer keys
    end

    local function bagCount() local b=LocalPlayer:FindFirstChild("Backpack") return b and #b:GetChildren() or 0 end
    local function bagMax()
        local ok,mx=pcall(function() return require(RS.Modules.Utility.Util):GetMaxInventorySpace(LocalPlayer) end)
        return (ok and type(mx)=="number") and mx or 500
    end
    local function cycGate() return cyc.on and alive() end
    local function haveCactusPlant()
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:HasTag("PlantTool") and ((t:GetAttribute("PlantName") or t.Name)=="Cactus") then return true end
            end end
        end
        return false
    end

    local function cycRun()
        -- 0) wait for player data + bag to load in
        while cycGate() do
            local ok,d=pcall(function() return require(RS:WaitForChild("PlayerData")):GetData().Data end)
            if ok and d and bagCount()>0 and getgenv().PvBPlantAPI then break end
            cycLbl.Text="waiting for data load..."
            task.wait(1)
        end
        if not cycGate() then return end
        task.wait(3)

        -- 0.5) out of seeds means the farm is complete: kill the toggle.
        -- Checked HERE (fresh join, post-rollback) because pre-hop the seeds
        -- are always spent and only restore after the no-save rejoin.
        if not getgenv().PvBPlantAPI.setSeed(cyc.seed) then
            cycLbl.Text="out of "..tostring(cyc.seed).." seeds - cycle complete"
            cyc.on=false cycSave() cycRefresh()
            return
        end

        -- 1) tornado standard until the weather activates (skippable via toggle)
        if cyc.tornado==false then
            cycLog("tornado step skipped (toggle off)")
            cycLbl.Text="tornado step skipped"
        else
        getgenv().PvBTorMode="standard" pcall(refreshMode)
        if not getgenv().PvBTornado then
            getgenv().PvBTornado=true
            torBtn.Text="Tornado: ON" torBtn.BackgroundColor3=C.green
            task.spawn(torLoop)
        end
        while cycGate() and getgenv().PvBTornado do
            cycLbl.Text="tornado: filling weather..."
            -- standardLoop's own booth reference goes stale once the weather event
            -- swaps the model, so re-grab fresh and force the stage closed ourselves
            local fresh = torBoothSafe()
            if fresh and fresh:GetAttribute("WeatherActive")==true then
                getgenv().PvBTornado=false
                torBtn.Text="Tornado: OFF" torBtn.BackgroundColor3=C.grey
                cycLbl.Text="weather active - tornado stage done"
                break
            end
            task.wait(4)
        end
        getgenv().PvBTornado=false
        end
        if not cycGate() then return end

        -- 2) fish until SAVE DATA exceeds the 4MB cap (the actual no-save condition)
        getgenv().PvBFishSnap = { gap=getgenv().PvBFishGap, sell=getgenv().PvBFishSellEvery }
        getgenv().PvBFishSellEvery = 1e9
        getgenv().PvBFishGap = 0.009
        getgenv().PvBAutoFish = true
        pcall(function() rfFish() end)
        local function dataMB()
            local ok,d=pcall(function() return require(RS:WaitForChild("PlayerData")):GetData().Data end)
            if not (ok and d) then return nil end
            local ok2,j=pcall(function() return HttpService:JSONEncode(d) end)
            if ok2 and j then return #j/1048576 end
            return nil
        end
        local tgt = tonumber(cyc.dataTargetMB) or 4.00
        while cycGate() do
            local mb=dataMB()
            if mb then
                cycLbl.Text=("fishing: %.2f / %.2f MB"):format(math.floor(mb*100)/100, tgt)
                if mb>=tgt then break end
            else
                -- size unreadable: fall back to the old item-count target
                cycLbl.Text=("fishing: %d items (size read failed)"):format(bagCount())
                if bagCount()>=(tonumber(cyc.fishTarget) or 1250) then break end
            end
            task.wait(1)
        end
        getgenv().PvBAutoFish=false
        pcall(function() rfFish() end)
        restoreFish()
        if not cycGate() then return end

        -- 3) plant a full garden of mango, water it, leave it in the ground
        local P=getgenv().PvBPlantAPI
        if not P.setSeed(cyc.seed) then cycLbl.Text="no "..tostring(cyc.seed).." seeds - halted" cyc.on=false cycSave() cycRefresh() return end
        P.setFull(true) P.setWater(true) P.setSell(false) P.setLoop(false) P.setHarvest(false)
        P.start(true)                      -- bag is over cap on purpose; skip the inv gate
        task.wait(1)
        while cycGate() and P.isRunning() do cycLbl.Text="growing "..tostring(cyc.seed).."..." task.wait(1) end
        P.setHarvest(true)
        if not cycGate() then P.stop() return end

        -- 3.5) TROLL STRAGGLER WAIT. A Troll Mango roll (0.67% per mango) keeps
        -- growing long after normal mangos mature (GrowTime 4020s vs mango), and
        -- growing seeds are INVISIBLE to the garden scan (they only get tagged as
        -- plants at maturity). So any of our seeds still growing at this point is
        -- a troll candidate: wait for it (watering it to speed it up) instead of
        -- scanning past it and rolling it back with the hop.
        local function growingSeeds()
            local out={}
            pcall(function()
                local plot=workspace.Plots[tostring(LocalPlayer:GetAttribute("Plot"))]
                local sf=plot and plot:FindFirstChild("Seeds")
                if sf then
                    local now=(getgenv().PvBPlantAPI and getgenv().PvBPlantAPI.serverNow and getgenv().PvBPlantAPI.serverNow()) or os.time()
                    for _,s in ipairs(sf:GetChildren()) do
                        local ct=tonumber(s:GetAttribute("CompletionTime"))
                        if ct and ct>now then out[#out+1]={inst=s,ct=ct} end
                    end
                end
            end)
            return out
        end
        do
            local straggle=growingSeeds()
            if #straggle>0 then
                cycLog("straggler: %d seed(s) still growing after batch (troll candidate) - waiting it out", #straggle)
                local cap=os.clock()+4800   -- 80 min absolute ceiling
                local lastW=0
                while cycGate() and os.clock()<cap do
                    local g=growingSeeds()
                    if #g==0 then break end
                    local rem=0
                    local nowS=(getgenv().PvBPlantAPI and getgenv().PvBPlantAPI.serverNow and getgenv().PvBPlantAPI.serverNow()) or os.time()
                    for _,e in ipairs(g) do rem=math.max(rem, e.ct-nowS) end
                    cycLbl.Text=("troll candidate growing - ~%dm %02ds left"):format(math.floor(rem/60), math.floor(rem%60))
                    if os.clock()-lastW>=3 then
                        local API=getgenv().PvBPlantAPI
                        if API and API.waterAt then
                            for _,e in ipairs(g) do
                                local okp,p=pcall(function() return e.inst:GetPivot().Position end)
                                if okp and p then API.waterAt(p) end
                            end
                        end
                        lastW=os.clock()
                    end
                    task.wait(1)
                end
                if not cycGate() then return end
                task.wait(2)  -- let the matured plant tag + attributes replicate
                cycLog("straggler wait done, scanning")
            end
        end

        -- 3.6) SETTLE: a seed whose timer just expired isn't a tagged plant yet.
        -- Wait for the Seeds folder to empty (models swapping to plants) before
        -- scanning, so a just-matured troll can't slip through untagged.
        do
            local t0=os.clock()
            while cycGate() and os.clock()-t0<20 do
                local pending=0
                pcall(function()
                    local plot=workspace.Plots[tostring(LocalPlayer:GetAttribute("Plot"))]
                    local sf=plot and plot:FindFirstChild("Seeds")
                    if sf then pending=#sf:GetChildren() end
                end)
                if pending==0 then break end
                cycLbl.Text=("settling: %d seed(s) converting to plants..."):format(pending)
                task.wait(1)
            end
            task.wait(2)
        end

        -- 4) troll check straight off the garden
        -- mutation gate. Sources in order: plant model "Colors" attribute (authoritative,
        -- same field the game's own GetPlantsDataFromModel reads), then replica record.
        -- If NEITHER is readable the troll counts as QUALIFYING (fail-keep). A plain troll
        -- wrongly kept costs nothing; a mutated troll wrongly sold is unrecoverable.
        local function trollMut(id)
            local col
            local ColSvc = game:GetService("CollectionService")
            pcall(function()
                for _,tag in ipairs({"Plants","Plant"}) do
                    for _,m in ipairs(ColSvc:GetTagged(tag)) do
                        if m:GetAttribute("ID")==id then col=m:GetAttribute("Colors") return end
                    end
                end
            end)
            if col==nil then
                pcall(function()
                    local plants=require(RS.PlayerData):GetData().Data.Plants or {}
                    local rec=plants[id] or plants[tostring(id)]
                    if type(rec)=="table" and type(rec.MutationData)=="table" then col=rec.MutationData.Colors end
                end)
            end
            return col and tostring(col) or nil   -- nil = unreadable, NOT "Normal"
        end
        local function mutOK(col)
            if cyc.captureAll then return true end   -- Capture: all -> every troll qualifies
            return col==nil or (col~="Normal" and col~="Gold")
        end
        local function scanTrolls(quiet)
            local found=false
            local gsnap=P.garden()
            for _,e in ipairs(gsnap) do
                local isTroll=tostring(e.name):lower():find("troll mango",1,true)
                local col
                if isTroll then
                    col=trollMut(e.id)
                    if not quiet then
                        local attrV, recV
                        pcall(function()
                            local ColSvc=game:GetService("CollectionService")
                            for _,tag in ipairs({"Plants","Plant"}) do
                                for _,m in ipairs(ColSvc:GetTagged(tag)) do
                                    if m:GetAttribute("ID")==e.id then attrV=m:GetAttribute("Colors") return end
                                end
                            end
                        end)
                        pcall(function()
                            local rec=(require(RS.PlayerData):GetData().Data.Plants or {})[e.id]
                            if type(rec)=="table" and type(rec.MutationData)=="table" then recV=rec.MutationData.Colors end
                        end)
                        cycLog("troll %s attr=%s record=%s -> %s", tostring(e.id), tostring(attrV), tostring(recV), mutOK(col) and "QUALIFIES" or "skip (plain/gold)")
                    end
                elseif not quiet then
                    warn(("[Cycle][garden] %s :: %s"):format(tostring(e.id), tostring(e.name)))
                end
                if isTroll and mutOK(col) then found=true end
            end
            if not quiet then
                cycLog("troll check: %s (%d plants scanned)", found and "MUTATED TROLL FOUND" or "none qualifying", #gsnap)
            end
            return found
        end
        local troll=scanTrolls(false)

        -- No countdown. The settle step above already waited for every seed to
        -- finish converting into a plant, so one immediate rescan is enough to
        -- catch a troll whose attributes landed a beat late.
        if not cycGate() then return end
        if not troll and scanTrolls(true) then
            troll=true
            cycLog("last-moment troll caught on final rescan")
        end

        if troll then
            cyc.trolls=(cyc.trolls or 0)+1 cycSave()
            cycLog("KEEP branch: selling brainrots, picking up garden")
            -- 4a) sell all brainrots to make room
            cycLbl.Text="TROLL! selling brainrots..."
            pcall(function() getgenv().PvBFireSell() end)
            local t0=os.clock()
            while cycGate() and bagCount()>bagMax() and os.clock()-t0<25 do task.wait(0.5) end
            -- 4b) pick everything up
            cycLbl.Text="picking up all plants..."
            local PickupRem = RS:WaitForChild("Remotes"):WaitForChild("Plants"):WaitForChild("Pickup")
            for _=1,6 do
                if not cycGate() then return end
                local left=P.garden()
                if #left==0 then break end
                for _,e in ipairs(left) do PickupRem:FireServer(e.id) task.wait(0.15) end
                task.wait(1)
            end
            -- 4c) heart every unhearted troll mango in the bag
            local favs={} pcall(function() favs=require(RS.PlayerData):GetData().Data.Favorites or {} end)
            local FavRem = RS:WaitForChild("Remotes"):WaitForChild("FavoriteItem")
            for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
                if c then for _,t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") and tostring(t:GetAttribute("PlantName") or t.Name):find("Troll Mango",1,true) then
                        local col=t:GetAttribute("Colors")  -- nil = unreadable -> keep
                        if mutOK(col) then
                            local id=t:GetAttribute("ID")
                            if id and not favs[id] then FavRem:FireServer(id) cycLog("hearted troll bag %s (mut: %s)", tostring(id), tostring(col)) task.wait(0.2) end
                        else
                            cycLog("skipping troll bag (mut: %s)", tostring(col))
                        end
                    end
                end end
            end
            -- 4d) sell all plants (hearted are protected)
            cycLbl.Text="selling plants..."
            pcall(function() getgenv().PvBFireSell(nil, true) end)
            -- 4e) a Cactus is only needed to feed the NEXT run's tornado step, so
            -- skip all of this when that step is turned off
            if cyc.tornado ~= false then
            task.wait(3)   -- let the sell land, or the old cactus still looks present
            if not haveCactusPlant() then
                cycLbl.Text="replacing cactus..."
                if P.setSeed("Cactus") then
                    P.setFull(false) P.setCount(1) P.setWater(false) P.setSell(false) P.setLoop(false) P.setHarvest(true)
                    P.start(true)
                    task.wait(1)
                    local t1=os.clock()
                    while cycGate() and P.isRunning() and os.clock()-t1<240 do cycLbl.Text="growing a cactus..." task.wait(1) end
                else
                    cycLbl.Text="NO cactus seed! next tornado will stall"
                    task.wait(2)
                end
            end
            end
            -- 4f) leave the instant save data is back under the cap. That is the
            -- only thing that matters: under the cap means the leave-save goes
            -- through and the hearted troll is kept. No fixed settle time.
            local t2=os.clock()
            while cycGate() and os.clock()-t2<120 do
                local mb=dataMB()
                if mb then
                    if mb<tgt then cycLog("data %.3f MB - under cap, leaving", mb) break end
                    cycLbl.Text=("saving: %.2f / %.2f MB - waiting to drop under"):format(math.floor(mb*100)/100, tgt)
                elseif bagCount()<=bagMax() then
                    break   -- size unreadable: fall back to the old bag-count rule
                else
                    cycLbl.Text=("bag %d/%d - draining..."):format(bagCount(), bagMax())
                end
                task.wait(0.5)
            end
        end
        if not cycGate() then return end

        -- 5) rejoin the same private server; autoexec re-arms the cycle there
        cyc.runs=(cyc.runs or 0)+1 cycSave()
        -- PUBLIC server hop, fully in-client. Private servers reject client
        -- teleports (error 773), but public ones don't, so: ask the games API
        -- for this place's public server list, pick the emptiest one that isn't
        -- the server we're on, and TeleportToPlaceInstance straight into it.
        -- Autoexec fires on the new server and the saved cyc.on re-arms.
        cycLbl.Text=("run %d done (trolls %d) - finding a quiet server..."):format(cyc.runs, cyc.trolls or 0)
        local function apiGet(url)
            local reqFn = (syn and syn.request) or request or http_request
            if reqFn then
                local ok,r=pcall(reqFn, {Url=url, Method="GET"})
                if ok and r and (r.StatusCode==200 or r.Status==200) then return r.Body end
            end
            local ok,body=pcall(function() return game:HttpGet(url) end)
            return ok and body or nil
        end
        local function quietServer(exclude)
            local body=apiGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId))
            if not body then return nil end
            local ok,list=pcall(function() return HttpService:JSONDecode(body) end)
            if not (ok and type(list)=="table" and type(list.data)=="table") then return nil end
            local best
            for _,s in ipairs(list.data) do
                if s.id and s.id~=game.JobId and not (exclude and exclude[s.id]) and type(s.playing)=="number" and s.playing < (tonumber(s.maxPlayers) or 999) then
                    if (not best) or s.playing<best.playing then best=s end
                end
            end
            return best
        end
        -- servers we've already attempted this hop: a restricted server can sit at
        -- the top of the emptiest list forever, so each retry must exclude it and
        -- take the next one up instead of slamming the same door
        local tried={}
        local tpFailed=false
        local tpConn; tpConn=TeleportService.TeleportInitFailed:Connect(function() tpFailed=true end)
        for attempt=1,5 do
            if not cyc.on then if tpConn then tpConn:Disconnect() end return end
            local s=quietServer(tried)
            if s then
                tried[s.id]=true
                cycLbl.Text=("hopping to a %d-player server (try %d)..."):format(s.playing, attempt)
                cycLog("hop attempt %d: server %s (%d players)", attempt, tostring(s.id), s.playing)
                tpFailed=false
                pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer) end)
            else
                cycLbl.Text=("no untried server found (try %d) - refetching..."):format(attempt)
            end
            -- wait up to 10s; a TeleportInitFailed (restricted server etc) skips ahead
            for _=1,20 do
                task.wait(0.5)
                if tpFailed then cycLog("hop attempt %d rejected - excluding that server", attempt) break end
            end
        end
        if tpConn then tpConn:Disconnect() end
        -- last resort: plain rejoin into whatever matchmaking gives us
        cycLbl.Text="quiet-hop failed 5x - plain teleport fallback"
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        task.wait(15)
        cycLbl.Text="teleport never fired - cycle stopped"
        cyc.on=false cycSave() cycRefresh()
    end

    local function cycTorRefresh()
        local on = cyc.tornado~=false
        cycTorBtn.Text = "Cycle tornado step: "..(on and "ON" or "OFF")
        cycTorBtn.BackgroundColor3 = on and C.green or C.grey
        local all = cyc.captureAll==true
        cycCapBtn.Text = all and "Capture: ALL trolls (gold+normal too)" or "Capture: OP mutations only"
        cycCapBtn.BackgroundColor3 = all and C.amber or C.green
    end
    cycTorRefresh()
    cycTorBtn.MouseButton1Click:Connect(function()
        cyc.tornado = not (cyc.tornado~=false)
        cycSave() cycTorRefresh()
    end)
    cycCapBtn.MouseButton1Click:Connect(function()
        cyc.captureAll = not (cyc.captureAll==true)
        cycSave() cycTorRefresh()
    end)
    cycBtn.MouseButton1Click:Connect(function()
        cyc.on = not cyc.on
        cycSave() cycRefresh()
        if cyc.on then
            cycLbl.Text="cycle armed"
            task.spawn(cycRun)
        else
            pcall(function() getgenv().PvBPlantAPI.stop() end)
            getgenv().PvBTornado=false
            getgenv().PvBAutoFish=false
            restoreFish()
            cycLbl.Text="stopped"
        end
    end)
    cycRefresh()
    if cyc.on then
        cycLbl.Text="auto-armed (saved state)"
        task.spawn(cycRun)
    end

    ------------------------------------------------------------------
    -- Potions: highlight any set of potions, type total minutes, Go
    -- drinks each enough times to cover it. Per-use durations are the
    -- game's own PotionRegistry values.
    ------------------------------------------------------------------
    do
        local UseItemP = RS.Remotes:WaitForChild("UseItem")
        local POTS = {
            { name="Biggify Potion",   icon="rbxassetid://120955768436184", per=10 },
            { name="Pine Tree Potion", icon="rbxassetid://127160520852128", per=5  },
            { name="Riot Potion",      icon="rbxassetid://127226436124740", per=10 },
            { name="Pre-Workout",      icon="rbxassetid://90139628805121",  per=10 },
            { name="Fire Potion",      icon="rbxassetid://134667181918172", per=5  },
            { name="Size Potion",      icon="rbxassetid://99820665306185",  per=5  },
            { name="Witch Potion",     icon="rbxassetid://72485223834101",  per=5  },
            { name="Damage Potion",    icon="rbxassetid://77407334948589",  per=30 },
            { name="Lucky Potion",     icon="rbxassetid://75866965031249",  per=30 },
        }
        local potSel, potBusy = {}, false
        for i,p in ipairs(POTS) do
            local col = (i-1) % 5
            local rowi = math.floor((i-1) / 5)
            local b=Instance.new("ImageButton")
            b.Size=UDim2.fromOffset(36,36)
            b.Position=UDim2.fromOffset(col*42, 340 + rowi*42)
            b.BackgroundColor3=C.row b.BorderSizePixel=0 b.Image=p.icon
            b.Parent=miscTab corner(b,8)
            local st=Instance.new("UIStroke",b) st.Thickness=2 st.Color=C.green st.Enabled=false
            b.MouseButton1Click:Connect(function()
                potSel[i]=not potSel[i]
                st.Enabled=potSel[i]==true
            end)
            local mins=mkLabel(b,tostring(p.per).."m",UDim2.fromOffset(20,10),UDim2.new(1,-20,1,-11),C.dim,Enum.Font.Gotham,8)
            mins.TextXAlignment=Enum.TextXAlignment.Right
        end
        local potMin=Instance.new("TextBox")
        potMin.Size=UDim2.fromOffset(52,28) potMin.Position=UDim2.fromOffset(0,428)
        potMin.BackgroundColor3=C.field potMin.TextColor3=C.txt potMin.Text=""
        potMin.PlaceholderText="min" potMin.PlaceholderColor3=C.dim
        potMin.Font=Enum.Font.GothamMedium potMin.TextSize=13 potMin.ClearTextOnFocus=false
        potMin.BorderSizePixel=0 potMin.Parent=miscTab corner(potMin,6)
        local potGo=mkButton(miscTab,"Go",C.purple,UDim2.fromOffset(46,28),UDim2.fromOffset(58,428))
        local potLbl=mkLabel(miscTab,"highlight potions, set total minutes",UDim2.new(1,-114,0,28),UDim2.fromOffset(114,428),C.dim,Enum.Font.Gotham,10)
        potLbl.TextWrapped=true
        local function findGearP(nm)
            nm=nm:lower()
            for _,c in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
                if c then for _,t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") then
                        local hay=(t.Name.." "..tostring(t:GetAttribute("Gear") or "").." "..tostring(t:GetAttribute("ItemName") or "")):lower()
                        if hay:find(nm,1,true) then return t end
                    end
                end end
            end
        end
        potGo.MouseButton1Click:Connect(function()
            if potBusy then return end
            local mins=tonumber(potMin.Text)
            if not mins or mins<=0 then potLbl.Text="enter minutes first" return end
            local any=false for _,v in pairs(potSel) do if v then any=true end end
            if not any then potLbl.Text="highlight a potion first" return end
            potBusy=true
            task.spawn(function()
                for i,p in ipairs(POTS) do
                    if potSel[i] then
                        local uses=math.ceil(mins/p.per)
                        for u=1,uses do
                            local tool=findGearP(p.name)
                            if not tool then potLbl.Text=("out of %s (%d/%d)"):format(p.name,u-1,uses) break end
                            local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if hum and tool.Parent~=LocalPlayer.Character then pcall(function() hum:EquipTool(tool) end) task.wait(0.25) end
                            local pos pcall(function() pos=LocalPlayer.Character:GetPivot().Position end)
                            pcall(function() UseItemP:FireServer({Toggle=true, Tool=tool, Pos=pos or Vector3.new()}) end)
                            potLbl.Text=("%s %d/%d"):format(p.name,u,uses)
                            task.wait(0.5)
                        end
                    end
                end
                pcall(function()
                    local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if h then h:UnequipTools() end
                end)
                potLbl.Text="done - check buff timers"
                potBusy=false
            end)
        end)
    end

    ------------------------------------------------------------------
    -- Investment upsize: place equipped plant, upsize to the round cap,
    -- pull out, wait the cooldown, repeat while on.
    ------------------------------------------------------------------
    local InvInteract
    lazyRemote({"Remotes","Events","Investment","Interact"}, function(r) InvInteract = r end)
    local InvPD; pcall(function() InvPD = require(RS:WaitForChild("PlayerData")) end)
    local InvTiers; pcall(function() InvTiers = require(RS.Modules.Library.EventTracks.Investment) end)
    local function invD() local ok,d=pcall(function() local g=InvPD:GetData() return g.Data or g end) return ok and d or {} end
    local INV_STALL, INV_COOLDOWN = 4, 92

    local invBtn = mkButton(eventsC,"Investment upsize: OFF",C.grey,UDim2.new(1,0,0,30),UDim2.fromOffset(0,360))
    local invLbl = mkLabel(eventsC,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,394),C.dim,Enum.Font.Gotham,12)

    ------------------------------------------------------------------
    -- Refinery: one-click remotes.
    -- Remotes.Events.Refinery.Interact takes three actions (read from the
    -- booth's own client script):
    --   "RequestGive"        submit the plant you are holding
    --   "CashOut", <plant>   claim a refined plant (needs 2+ of it fed)
    --   "Reset"              reset the event - costs money, so it asks twice
    ------------------------------------------------------------------
    local function __buildRefineryRemotes()
        local function refRemote()
            local r=RS:FindFirstChild("Remotes")
            r=r and r:FindFirstChild("Events")
            r=r and r:FindFirstChild("Refinery")
            return r and r:FindFirstChild("Interact")
        end
        local function refData()
            local ok,d=pcall(function()
                local g=require(RS:WaitForChild("PlayerData")):GetData()
                return g and (g.Data or g)
            end)
            return ok and d or nil
        end

        mkSection(eventsC,"Refinery",426)
        local subBtn   = mkButton(eventsC,"Submit held plant",C.green,UDim2.new(1/3,-4,0,28),UDim2.fromOffset(0,452))
        local cashBtn  = mkButton(eventsC,"Cash out all",C.amber,UDim2.new(1/3,-4,0,28),UDim2.new(1/3,2,0,452))
        local resetBtn = mkButton(eventsC,"Reset event",C.red,UDim2.new(1/3,-4,0,28),UDim2.new(2/3,4,0,452))
        local refLbl   = mkLabel(eventsC,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,486),C.dim,Enum.Font.Gotham,12)
        local function say(t) refLbl.Text=t setStatus("Refinery: "..t) end

        subBtn.MouseButton1Click:Connect(function()
            local rem=refRemote()
            if not rem then say("event not active") return end
            local ch=LocalPlayer.Character
            local tool=ch and ch:FindFirstChildWhichIsA("Tool")
            if not (tool and tool:HasTag("PlantTool")) then say("equip a plant first") return end
            pcall(function() rem:FireServer("RequestGive") end)
            say("submitted "..tostring(tool:GetAttribute("PlantName") or tool.Name))
        end)

        cashBtn.MouseButton1Click:Connect(function()
            local rem=refRemote()
            if not rem then say("event not active") return end
            local d=refData()
            local tr=d and d.RefineryTracker
            if type(tr)~="table" then say("nothing to cash out") return end
            task.spawn(function()
                local n=0
                for name,v in pairs(tr) do
                    local c=(type(v)=="table" and tonumber(v[1])) or tonumber(v) or 0
                    if c>1 then
                        pcall(function() rem:FireServer("CashOut", name) end)
                        n=n+1
                        task.wait(0.15)
                    end
                end
                say(n>0 and ("cashed out %d plant type(s)"):format(n) or "nothing ready (needs 2+ fed)")
            end)
        end)

        local armed=0
        resetBtn.MouseButton1Click:Connect(function()
            local rem=refRemote()
            if not rem then say("event not active") return end
            if os.clock()-armed > 3 then
                armed=os.clock()
                resetBtn.Text="Click again"
                task.delay(3,function() if resetBtn.Parent then resetBtn.Text="Reset event" end end)
                say("reset costs money - click again to confirm")
                return
            end
            armed=0
            resetBtn.Text="Reset event"
            pcall(function() rem:FireServer("Reset") end)
            say("reset sent")
        end)
    end
    __buildRefineryRemotes()

    ------------------------------------------------------------------
    -- St. Patty's (gold) event.  Read from the booth's own client script:
    --   Remotes.Events.StPattys.Interact:FireServer("RequestGive")  submit HELD brainrot
    --   Interact:FireServer("Reset")                                 reset (costs money)
    --   progress = Data.ClaimedRewards.StPattys, full = #RewardTracks.StPattys (50)
    -- ON : every rarity filter (Modules.Library.Chances) -> ACCEPT (AutoSell[r]=false), except
    --      Eggs / Dailys / Bosses (separate keys, never touched). You flip the
    --      Gold mutation filter yourself.
    --      Any GOLD brainrot in the bag is equipped + submitted immediately.
    --      Track rewards can be non-gold brainrots, so ONLY gold is submitted.
    --      Hearted brainrots are never submitted (hearted = you're keeping it).
    -- OFF: every rarity filter -> filtered out again (AutoSell[r]=true).
    -- While a gold brainrot is being handed in, the Keep tab's bag auto-sell
    -- is held for ~1.5s so it can't sell it first.
    ------------------------------------------------------------------
    local function __buildStPattys()
        local SPInteract
        local spLastErr, spErrAt = nil, -99
        local spLat = nil   -- rolling avg seconds: fire -> server removes the brainrot
        lazyRemote({"Remotes","Events","StPattys","Interact"}, function(r)
            SPInteract = r
            pcall(function()
                r.OnClientEvent:Connect(function(kind, msg)
                    if kind=="Error" then spLastErr=tostring(msg or "error") spErrAt=os.clock() end
                end)
            end)
        end)
        local SPPD; pcall(function() SPPD = require(RS:WaitForChild("PlayerData")) end)
        local function spData()
            local ok,d=pcall(function() local g=SPPD:GetData() return g.Data or g end)
            return ok and type(d)=="table" and d or nil
        end
        local spTrackCount = 50
        pcall(function()
            local n=0
            for _ in pairs(require(RS.Modules.Library.RewardTracks.StPattys)) do n=n+1 end
            if n>0 then spTrackCount=n end
        end)
        local function spProgress()
            local d=spData()
            return tonumber(d and d.ClaimedRewards and d.ClaimedRewards.StPattys) or 0
        end

        -- rarity filter keys = exactly what the game's AutoSell panel lists
        local SP_RARITIES = {"Rare","Epic","Legendary","Mythic","Godly","Limited","Secret","Forbidden"}
        pcall(function()
            local ch = require(RS.Modules.Library.Chances)
            local out = {}
            for name,v in pairs(ch) do
                if type(name)=="string" and not (type(v)=="table" and v.CantSpawn) then out[#out+1]=name end
            end
            if #out>0 then SP_RARITIES = out end
        end)
        local SP_SKIP = {Eggs=true, Dailys=true, Dailies=true, Bosses=true}
        local AutoSellRem = RS.Remotes:FindFirstChild("AutoSell")
        local function filterState(r)
            local d=spData()
            local a=d and d.AutoSell
            if type(a)~="table" then return nil end
            return a[r] and true or false
        end
        -- drive every rarity filter to `want`; re-checks the replica and retries
        local function setAllFilters(want)
            if not AutoSellRem then return 0 end
            local wrong=0
            for attempt=1,4 do
                wrong=0
                for _,r in ipairs(SP_RARITIES) do
                    if not SP_SKIP[r] then
                        local cur=filterState(r)
                        if cur~=want then
                            wrong=wrong+1
                            pcall(function() AutoSellRem:FireServer(r) end)
                            task.wait(0.3)
                        end
                    end
                end
                if wrong==0 then break end
                task.wait(0.8)   -- let the replica catch up before re-checking
            end
            return wrong
        end

        -- gold = "Gold" is a word in MutationString that the base name doesn't account for
        local function isGoldBrainrot(t)
            if not (t:IsA("Tool") and t:GetAttribute("ID")) then return false end
            if t:GetAttribute("PlantName") or t:GetAttribute("SeedName") then return false end
            local ms=t:GetAttribute("MutationString")
            if type(ms)~="string" or ms=="" then return false end
            local base=t:GetAttribute("Brainrot") or t:GetAttribute("ItemName") or ""
            local bw={}
            for w in tostring(base):lower():gmatch("[%w]+") do bw[w]=(bw[w] or 0)+1 end
            for w in ms:lower():gmatch("[%w]+") do
                if (bw[w] or 0)>0 then bw[w]=bw[w]-1
                elseif w=="gold" then return true end
            end
            return false
        end
        local function spFav(id)
            local d=spData()
            local f=d and d.Favorites
            if type(f)~="table" then return false end
            local v=f[id]
            return v~=nil and v~=false
        end

        -- Pipelined: equip -> fire -> next, no waiting on the server between
        -- hand-ins. Each request hands in whatever is HELD when the server
        -- processes it, and we only ever hold unhearted gold, so a race just
        -- hands in a different gold one. Anything still in the bag 1s after
        -- its fire gets fired again; 4 misses parks it for 15s.
        local spInflight = {}   -- id -> {t=last fire, n=fires}
        local spBadUntil = {}   -- id -> clock
        local spGold = setmetatable({}, {__mode="k"})   -- tool -> is gold (attrs never change)
        local spSeen = setmetatable({}, {__mode="k"})   -- tool -> first seen
        -- Only brainrots the Keep tab might heart (it hearts ~0.3s after arrival)
        -- wait 0.6s first. Everything else goes the instant it lands.
        local SP_SETTLE = 0.6
        local function keepRisk(t)
            local k=getgenv().PvBKeepCfg
            if type(k)~="table" or not k.enabled then return false end
            local r=t:GetAttribute("Rarity")
            if r=="Secret" then return true end
            if r=="Forbidden" and k.keepForbidden then return true end
            local size=tonumber(t:GetAttribute("Size")) or 0
            return size > (tonumber(k.keepAnyKg) or 150)/10
        end
        local function okGold(t, now)
            local g=spGold[t]
            if g==nil then g=isGoldBrainrot(t) spGold[t]=g end
            if not g then return false end
            if not spSeen[t] then spSeen[t]=now end
            local id=t:GetAttribute("ID")
            if now<(spBadUntil[id] or 0) then return false end
            local f=spInflight[id]
            if f and now-f.t<1 then return false end
            if keepRisk(t) and now-spSeen[t]<SP_SETTLE then return false end
            return not spFav(id)
        end
        local function findGold()
            local now=os.clock()
            local ch=LocalPlayer.Character
            local held=ch and ch:FindFirstChildWhichIsA("Tool")
            if held and okGold(held, now) then return held end
            local bp=LocalPlayer:FindFirstChild("Backpack")
            if bp then
                for _,t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") and okGold(t, now) then return t end
                end
            end
            return nil
        end

        -- For the Keep tab's sell sweep. ItemSell() sells the BAG, not the hand,
        -- so the only golds at risk are unhearted ones still sitting in the bag.
        -- This replaces the old rolling hold, which every submit re-armed for
        -- 1.5s and which therefore blocked selling the whole time golds flowed.
        getgenv().PvBGoldWaiting = function()
            if getgenv().PvBStPattys ~= true then return false end
            local bp = LocalPlayer:FindFirstChild("Backpack")
            if not bp then return false end
            for _,t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") then
                    local g = spGold[t]
                    if g == nil then g = isGoldBrainrot(t) spGold[t] = g end
                    if g and not spFav(t:GetAttribute("ID")) then return true end
                end
            end
            return false
        end

        mkSection(eventsC,"St. Patty's (gold)",516)
        local spBtn = mkButton(eventsC,"St. Patty's gold: OFF",C.grey,UDim2.new(1,0,0,30),UDim2.fromOffset(0,542))
        local spLbl = mkLabel(eventsC,"",UDim2.new(1,0,0,20),UDim2.fromOffset(0,576),C.dim,Enum.Font.Gotham,12)
        local spDone, spLastReset = 0, 0
        local spNote, spNoteAt = nil, -99   -- a message that holds the label for 4s

        local function spMaybeReset()
            if spProgress() < spTrackCount then return end
            if os.clock()-spLastReset < 10 then return end   -- reset costs money: one try per 10s
            spLastReset=os.clock()
            spLbl.Text=("track full (%d/%d) - resetting"):format(spProgress(),spTrackCount)
            pcall(function() SPInteract:FireServer("Reset") end)
            local t0=os.clock()
            while os.clock()-t0<4 and spProgress()>=spTrackCount do task.wait(0.05) end
            spLbl.Text = spProgress()<spTrackCount and "event reset" or "reset not confirmed (money?) - retrying in 10s"
        end

        local function submitOne(tool)
            local ch=LocalPlayer.Character
            local hum=ch and ch:FindFirstChildOfClass("Humanoid")
            if not hum then return false end
            local id=tool:GetAttribute("ID")
            getgenv().PvBGoldHoldUntil = os.clock()+1.5
            if tool.Parent~=ch then
                pcall(function() hum:EquipTool(tool) end)
                local t0=os.clock()
                while tool.Parent~=ch and os.clock()-t0<0.3 do task.wait() end
                if tool.Parent~=ch then return false end
            end
            if spFav(id) then   -- hearted while equipping: put it back, never submit
                pcall(function() hum:UnequipTools() end)
                return false
            end
            pcall(function() SPInteract:FireServer("RequestGive") end)
            local f=spInflight[id] or {n=0}
            f.t=os.clock() f.n=f.n+1
            spInflight[id]=f
            if not f.t0 then
                -- time how long the server takes to actually take it
                f.t0=f.t
                local c; c=tool.AncestryChanged:Connect(function()
                    if not tool:IsDescendantOf(game) then
                        c:Disconnect()
                        local lat=os.clock()-f.t0
                        spLat = spLat and (spLat*0.7+lat*0.3) or lat
                        spInflight[id]=nil
                    end
                end)
            end
            if f.n>=4 then
                spBadUntil[id]=os.clock()+15
                spInflight[id]=nil
                spNote=("booth keeps refusing %s: %s"):format(
                    tostring(tool:GetAttribute("Brainrot") or tool.Name), tostring(spLastErr or "no response"))
                spNoteAt=os.clock()
                spLbl.Text=spNote
            end
            return true
        end

        local function rf()
            local on=getgenv().PvBStPattys==true
            spBtn.Text = on and "St. Patty's gold: ON" or "St. Patty's gold: OFF"
            spBtn.BackgroundColor3 = on and C.amber or C.grey
        end

        local function spRun()
            spDone=0
            spLbl.Text="filters -> accept all rarities..."
            -- flip filters in the background so hand-ins start immediately
            local filtering=true
            task.spawn(function()
                local bad=setAllFilters(false)   -- AutoSell[r]=false = rarity is ACCEPTED (your "on")
                if bad>0 then
                    spNote=("%d filter(s) didn't flip - check AutoSell panel"):format(bad)
                    spNoteAt=os.clock() spLbl.Text=spNote
                end
                filtering=false
            end)
            local lastProg=spProgress()
            local lastLbl=0
            while alive() and getgenv().PvBStPattys==true do
                if not SPInteract then
                    spLbl.Text="StPattys booth remote not found (event off?)"
                    task.wait(0.5)
                else
                    if spProgress()>=spTrackCount then spMaybeReset() end
                    local g=findGold()
                    if g then submitOne(g) end
                    -- count hand-ins from the track itself (resets drop it back to 0)
                    local p=spProgress()
                    if p>lastProg then spDone=spDone+(p-lastProg) end
                    lastProg=p
                    if os.clock()-lastLbl>0.25 then
                        lastLbl=os.clock()
                        if os.clock()-(spLastReset or 0)>4 and os.clock()-spNoteAt>4 then
                            if os.clock()-spErrAt<4 then
                                spLbl.Text="booth: "..tostring(spLastErr)
                            else
                                spLbl.Text=("track %d/%d | %d in | server %s"):format(p,spTrackCount,spDone,
                                    spLat and (math.floor(spLat*1000).."ms") or "--")
                            end
                        end
                    end
                    task.wait()   -- one frame between hand-ins
                end
            end
            getgenv().PvBGoldHoldUntil = 0
            local tw=os.clock()   -- don't fight the start-up flip if it's still running
            while filtering and os.clock()-tw<6 do task.wait(0.1) end
            -- OFF (or closed / re-injected): every rarity back to filtered out
            local bad2=setAllFilters(true)    -- AutoSell[r]=true = rarity is SOLD (your "off")
            if spLbl.Parent then
                spLbl.Text = bad2>0 and ("stopped - %d filter(s) didn't flip back, check AutoSell panel"):format(bad2)
                    or ("stopped - filters back off | submitted %d"):format(spDone)
            end
        end

        spBtn.MouseButton1Click:Connect(function()
            if getgenv().PvBStPattys==true then
                getgenv().PvBStPattys=false
                rf()
                return
            end
            if getgenv().PvBStPattysBusy then spLbl.Text="still restoring filters, one sec" return end
            getgenv().PvBStPattys=true
            rf()
            task.spawn(function()
                getgenv().PvBStPattysBusy=true
                local ok,err=pcall(spRun)
                getgenv().PvBStPattysBusy=false
                if not ok then spLbl.Text="error: "..tostring(err) end
                getgenv().PvBStPattys=false
                rf()
            end)
        end)
        rf()
    end
    __buildStPattys()

    local function invEquipPlant()  -- keep what's in hand; only pick from bag if hands are empty
        local char=LocalPlayer.Character
        local held=char and char:FindFirstChildWhichIsA("Tool")
        if held and (held:GetAttribute("PlantName") or held:HasTag("PlantTool")) then return held end
        local best,bw
        for _,t in ipairs(LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:GetChildren() or {}) do
            if t:IsA("Tool") and (t:GetAttribute("PlantName") or t:HasTag("PlantTool")) then
                local w=tonumber(t:GetAttribute("Size")) or 0
                if not bw or w>bw then best,bw=t,w end
            end
        end
        if best then local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(best) end) task.wait(0.2) end end
        return best
    end

    local function invRound()
        if not invD().InvestmentPlant then invEquipPlant() pcall(function() InvInteract:FireServer("AttemptAddPlant") end) task.wait(0.6) end
        local p=invD().InvestmentPlant
        if not p then invLbl.Text="no plant to place" return "noplant" end
        local startSize=p.Size
        task.wait(0.4)                                     -- let the place settle so the first invest isn't "too quick"
        local fails=0
        while getgenv().PvBInvest and alive() do
            local cur=invD().InvestmentAmount or 0
            if InvTiers and InvTiers[cur+1]==nil then break end     -- no next tier = round is maxed
            pcall(function() InvInteract:FireServer("IncrementMoney") end)
            local t,after=0,cur
            while t<1.3 do task.wait(0.1) t=t+0.1 after=invD().InvestmentAmount or 0 if after>cur then break end end
            if after>cur then
                fails=0
                invLbl.Text=("upsizing tier %d, %s kg"):format(after, tostring((invD().InvestmentPlant or {}).Size))
            else
                fails=fails+1
                if fails>=6 then break end                          -- genuinely stuck (out of money), not just a throttle
            end
        end
        task.wait(0.3)
        pcall(function() InvInteract:FireServer("AttemptPickupPlant") end)
        task.wait(0.3)
        local held=invD().InvestmentPlant
        invLbl.Text=("round done: %s -> %s kg"):format(tostring(startSize), tostring(held and held.Size or "returned"))
        return "ok"
    end

    local function invLoop()
        while getgenv().PvBInvest and alive() do
            local r=invRound()
            if not getgenv().PvBInvest then break end
            if r=="noplant" then task.wait(1)
            else for i=INV_COOLDOWN,1,-1 do if not getgenv().PvBInvest then break end invLbl.Text=("cooldown %ds"):format(i) task.wait(1) end end
        end
        getgenv().PvBInvest=false
        invBtn.Text="Investment upsize: OFF" invBtn.BackgroundColor3=C.grey
    end

    invBtn.MouseButton1Click:Connect(function()
        if getgenv().PvBInvest then getgenv().PvBInvest=false return end
        if not InvInteract then setStatus("Investment remote missing") return end
        getgenv().PvBInvest=true
        invBtn.Text="Investment upsize: ON" invBtn.BackgroundColor3=C.green
        setStatus("Investment: upsizing")
        task.spawn(invLoop)
    end)

    end
    __buildAdvanced()

    ------------------------------------------------------------------
    -- Performance mode + Fleet sync. Perf = integrated potato: hides
    -- every animated rig (brainrots/plants/others), other plots,
    -- particles/lights/sounds, caps fps. Fully reversible toggle,
    -- persisted via saveMisc. Reload-all writes a nonce to a shared
    -- executor file; every client's watcher refetches the script from
    -- GitHub and restarts itself with the freshly saved settings.
    ------------------------------------------------------------------
    local function __buildPerfFleet()
        -- fully local fleet: keep THIS script saved as script8.lua inside the
        -- executor's workspace folder (same folder your PvBToolkit_*.json
        -- settings files live in - it is shared by every client on the machine).
        local SRC_FILE    = "script8.lua"
        local RELOAD_FILE = "PvBToolkit_reload.txt"
        if getgenv().PvBPerfMode == nil then getgenv().PvBPerfMode = false end
        if getgenv().PvBPerfPurge == nil then getgenv().PvBPerfPurge = false end
        if getgenv().PvBPerfFps  == nil then getgenv().PvBPerfFps  = 20 end

        -- shared session token: enabling here supersedes any standalone potato loops
        local mySession = 0
        local function perfAlive() return getgenv().PvBPotatoSession == mySession and getgenv().PvBPerfMode end

        local saved = setmetatable({}, { __mode="k" })
        local hiddenRoots = setmetatable({}, { __mode="k" })

        local function isRig(m)
            return m:FindFirstChildOfClass("Humanoid")~=nil or m:FindFirstChildOfClass("AnimationController")~=nil
        end
        local function isMyChar(m)
            return LocalPlayer.Character~=nil and (m==LocalPlayer.Character or m:IsDescendantOf(LocalPlayer.Character))
        end
        local myPlotP
        local function myPlotRef()
            if myPlotP and myPlotP.Parent then return myPlotP end
            pcall(function()
                local ps=workspace:FindFirstChild("Plots")
                if ps then for _,p in ipairs(ps:GetChildren()) do
                    if p:GetAttribute("Owner")==LocalPlayer.UserId then myPlotP=p break end
                end end
            end)
            return myPlotP
        end

        local function hideOne(d)
            local cls=d.ClassName
            if d:IsA("BasePart") then
                pcall(function() d.LocalTransparencyModifier=1 d.CastShadow=false end)
            elseif cls=="Decal" or cls=="Texture" then
                pcall(function()
                    if saved[d]==nil then saved[d]={tr=d.Transparency} end
                    d.Transparency=1
                end)
            elseif cls=="BillboardGui" then
                pcall(function()
                    if saved[d]==nil then saved[d]={md=d.MaxDistance,en=d.Enabled} end
                    d.MaxDistance=0 d.Enabled=false   -- game fights Enabled; never touches MaxDistance
                end)
            elseif cls=="SurfaceGui" then
                pcall(function()
                    if saved[d]==nil then saved[d]={en=d.Enabled} end
                    d.Enabled=false
                end)
            elseif cls=="ParticleEmitter" or cls=="Trail" or cls=="Beam" or cls=="Fire" or cls=="Smoke" or cls=="Sparkles"
                or cls=="PointLight" or cls=="SpotLight" or cls=="SurfaceLight" then
                pcall(function()
                    if saved[d]==nil then saved[d]={en=d.Enabled} end
                    d.Enabled=false
                end)
            elseif cls=="Sound" then
                pcall(function()
                    if saved[d]==nil then saved[d]={vol=d.Volume} end
                    d.Volume=0
                end)
            end
        end
        local function showOne(d)
            local s=saved[d]
            if d:IsA("BasePart") then
                pcall(function() d.LocalTransparencyModifier=0 end)
            elseif s then
                pcall(function()
                    if s.tr~=nil then d.Transparency=s.tr end
                    if s.md~=nil then d.MaxDistance=s.md end
                    if s.en~=nil then d.Enabled=s.en end
                    if s.vol~=nil then d.Volume=s.vol end
                end)
            end
        end

        local function stopAnims(root)
            for _,a in ipairs(root:GetDescendants()) do
                if a:IsA("Animator") then
                    pcall(function() for _,tr in ipairs(a:GetPlayingAnimationTracks()) do tr:Stop(0) end end)
                    if not saved[a] then
                        saved[a]={hook=true}
                        pcall(function()
                            a.AnimationPlayed:Connect(function(tr)
                                if getgenv().PvBPerfMode then pcall(function() tr:Stop(0) end) end
                            end)
                        end)
                    end
                end
            end
        end
        local function hideRoot(root)
            if hiddenRoots[root] then return end
            hiddenRoots[root]=true
            task.defer(function()
                if not getgenv().PvBPerfMode then return end
                for _,d in ipairs(root:GetDescendants()) do hideOne(d) end
                if root:IsA("BasePart") then hideOne(root) end
                stopAnims(root)
            end)
        end
        local function considerModel(m)
            if m:IsA("Model") and not isMyChar(m) and isRig(m) then hideRoot(m) end
        end
        -- purge: actually DESTROY other plots' replicated contents (frees real
        -- memory, unlike hiding). Irreversible until rejoin - which the hourly
        -- relaunch does anyway. Own plot and the brainrot lane are never touched.
        local function purgePlot(p)
            task.defer(function()
                for _,c in ipairs(p:GetChildren()) do
                    pcall(function() c:Destroy() end)
                end
            end)
        end
        local function sweepOtherPlots()
            pcall(function()
                local ps=workspace:FindFirstChild("Plots")
                if ps then for _,p in ipairs(ps:GetChildren()) do
                    if p:GetAttribute("Owner")~=LocalPlayer.UserId then
                        if getgenv().PvBPerfPurge then purgePlot(p) else hideRoot(p) end
                    end
                end end
            end)
        end

        local litSaved=nil
        local function enablePerf()
            getgenv().PvBPotatoSession=(getgenv().PvBPotatoSession or 0)+1
            mySession=getgenv().PvBPotatoSession
            pcall(function() setfpscap(tonumber(getgenv().PvBPerfFps) or 20) end)
            pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
            pcall(function()
                local L=game:GetService("Lighting")
                if litSaved==nil then litSaved={gs=L.GlobalShadows} end
                L.GlobalShadows=false
            end)
            task.spawn(function()
                local all=workspace:GetDescendants()
                for i,d in ipairs(all) do
                    if not perfAlive() then return end
                    local cls=d.ClassName
                    if cls=="ParticleEmitter" or cls=="Trail" or cls=="Beam" or cls=="Fire" or cls=="Smoke"
                        or cls=="Sparkles" or cls=="PointLight" or cls=="SpotLight" or cls=="SurfaceLight"
                        or cls=="Sound" then
                        hideOne(d)                       -- world-wide kills only
                    elseif d:IsA("Model") then
                        considerModel(d)                 -- rigs + plots go through hideRoot
                    end
                    if i%500==0 then task.wait() end
                end
                sweepOtherPlots()
            end)
            task.spawn(function()  -- resweep: server updates can undo local hides
                while perfAlive() do
                    task.wait(8)
                    local roots={}
                    for r in pairs(hiddenRoots) do if r.Parent then roots[#roots+1]=r end end
                    for i,r in ipairs(roots) do
                        hiddenRoots[r]=nil hideRoot(r)
                        if i%20==0 then task.wait() end
                    end
                    sweepOtherPlots()
                end
            end)
        end
        local function disablePerf()
            getgenv().PvBPotatoSession=(getgenv().PvBPotatoSession or 0)+1  -- kills loops
            pcall(function() setfpscap(60) end)
            pcall(function()
                local L=game:GetService("Lighting")
                if litSaved and litSaved.gs~=nil then L.GlobalShadows=litSaved.gs end
            end)
            task.spawn(function()
                local i=0
                for r in pairs(hiddenRoots) do
                    if r.Parent then
                        for _,d in ipairs(r:GetDescendants()) do showOne(d) end
                        if r:IsA("BasePart") then showOne(r) end
                    end
                    hiddenRoots[r]=nil
                    i=i+1 if i%15==0 then task.wait() end
                end
                for d in pairs(saved) do
                    if typeof(d)=="Instance" and d.Parent and not d:IsA("Animator") then showOne(d) end
                end
            end)
        end

        workspace.DescendantAdded:Connect(function(d)
            if not getgenv().PvBPerfMode then return end
            if not gui.Parent then return end
            task.defer(function()
                if not d.Parent then return end
                local cls=d.ClassName
                if cls=="ParticleEmitter" or cls=="Trail" or cls=="Beam" or cls=="Fire" or cls=="Smoke"
                    or cls=="Sparkles" or cls=="PointLight" or cls=="SpotLight" or cls=="SurfaceLight" or cls=="Sound" then
                    hideOne(d) return
                end
                if (d:IsA("Humanoid") or d:IsA("AnimationController")) then
                    local m=d.Parent
                    if m and m:IsA("Model") and not isMyChar(m) then hideRoot(m) end
                    return
                end
                if d:IsA("Model") and d.Parent and d.Parent.Name=="Plots"
                    and d:GetAttribute("Owner")~=LocalPlayer.UserId then
                    if getgenv().PvBPerfPurge then purgePlot(d) else hideRoot(d) end
                    return
                end
                -- parts/guis/decals arriving under an already-hidden root
                local m=d:FindFirstAncestorWhichIsA("Model")
                while m do
                    if hiddenRoots[m] then hideOne(d) return end
                    m=m:FindFirstAncestorWhichIsA("Model")
                end
                local ps=workspace:FindFirstChild("Plots")
                if ps and d:IsDescendantOf(ps) then
                    local mp=myPlotRef()
                    if not (mp and d:IsDescendantOf(mp)) then
                        if getgenv().PvBPerfPurge then pcall(function() d:Destroy() end)
                        else hideOne(d) end
                    end
                end
            end)
        end)

        ---------------------------------------------------------- UI
        mkSection(miscC,"Performance + Fleet",868)
        local perfBtn=mkButton(miscC,"Performance mode: OFF",C.grey,UDim2.fromOffset(170,28),UDim2.fromOffset(0,894))
        local fpsBox=Instance.new("TextBox")
        fpsBox.Size=UDim2.fromOffset(44,28) fpsBox.Position=UDim2.fromOffset(178,894)
        fpsBox.BackgroundColor3=C.field fpsBox.TextColor3=C.txt fpsBox.Font=Enum.Font.GothamMedium
        fpsBox.TextSize=13 fpsBox.Text=tostring(getgenv().PvBPerfFps) fpsBox.ClearTextOnFocus=false
        fpsBox.BorderSizePixel=0 fpsBox.Parent=miscC corner(fpsBox,6)
        mkLabel(miscC,"fps cap",UDim2.fromOffset(50,28),UDim2.fromOffset(226,894),C.dim,Enum.Font.Gotham,11)
        fpsBox.FocusLost:Connect(function()
            local n=tonumber(fpsBox.Text)
            if n and n>=5 then
                getgenv().PvBPerfFps=math.floor(n) saveMisc()
                if getgenv().PvBPerfMode then pcall(function() setfpscap(getgenv().PvBPerfFps) end) end
            end
            fpsBox.Text=tostring(getgenv().PvBPerfFps)
        end)
        local function rfPerf()
            local on=getgenv().PvBPerfMode
            perfBtn.Text="Performance mode: "..(on and "ON" or "OFF")
            perfBtn.BackgroundColor3=on and C.green or C.grey
        end
        perfBtn.MouseButton1Click:Connect(function()
            getgenv().PvBPerfMode=not getgenv().PvBPerfMode
            saveMisc() rfPerf()
            if getgenv().PvBPerfMode then enablePerf() setStatus("Performance mode on")
            else disablePerf() setStatus("Performance mode off (restoring visuals)") end
        end)
        rfPerf()

        if getgenv().PvB3DOn==nil then getgenv().PvB3DOn=true end
        local rdBtn=mkButton(miscC,"3D render: ON",C.green,UDim2.fromOffset(120,28),UDim2.fromOffset(0,930))
        local function rf3D()
            rdBtn.Text="3D render: "..(getgenv().PvB3DOn and "ON" or "OFF")
            rdBtn.BackgroundColor3=getgenv().PvB3DOn and C.green or C.red
        end
        rdBtn.MouseButton1Click:Connect(function()
            getgenv().PvB3DOn=not getgenv().PvB3DOn
            pcall(function() RunService:Set3dRenderingEnabled(getgenv().PvB3DOn) end)
            rf3D()
            saveMisc()
        end)
        rf3D()
        pcall(function() RunService:Set3dRenderingEnabled(getgenv().PvB3DOn) end)

        local purgeBtn=mkButton(miscC,"Purge assets: OFF",C.grey,UDim2.fromOffset(150,28),UDim2.fromOffset(128,930))
        local function rfPurge()
            local on=getgenv().PvBPerfPurge
            purgeBtn.Text="Purge assets: "..(on and "ON" or "OFF")
            purgeBtn.BackgroundColor3=on and C.green or C.grey
        end
        purgeBtn.MouseButton1Click:Connect(function()
            getgenv().PvBPerfPurge=not getgenv().PvBPerfPurge
            saveMisc() rfPurge()
            if getgenv().PvBPerfPurge and getgenv().PvBPerfMode then
                sweepOtherPlots()
                setStatus("Purge on: destroying other plots' contents (rejoin restores)")
            else
                setStatus("Purge "..(getgenv().PvBPerfPurge and "on (takes effect with Performance mode)" or "off (rejoin restores assets)"))
            end
        end)
        rfPurge()

        mkLabel(miscC,"Perf hides all brainrots/plants/other plots + labels, stops animations, caps fps. Purge goes further: DESTROYS other plots' replicated contents to free real memory (rejoin restores). Both saved: toggle then Reload ALL applies fleet-wide.",
            UDim2.new(1,0,0,56),UDim2.fromOffset(0,1058),C.dim,Enum.Font.Gotham,10).TextWrapped=true

        ---------------------------------------------------------- fleet reload
        local baseline=""
        pcall(function() if isfile and isfile(RELOAD_FILE) then baseline=readfile(RELOAD_FILE) end end)

        local function doReload()
            setStatus("Fleet reload: reading local script...")
            local src
            local ok=pcall(function() src=readfile(SRC_FILE) end)
            if not ok or type(src)~="string" or #src<1000 then
                setStatus("Fleet reload FAILED: save the toolkit as "..SRC_FILE.." in the executor workspace folder.")
                return
            end
            getgenv().PvBTornado=false; getgenv().PvBAscended=false; getgenv().PvBBatteryBoost=false
            getgenv().PvBInvest=false; getgenv().PvBAutoFish=false; getgenv().PvBAutoClick=false
            local f=loadstring(src)
            if not f then setStatus("Fleet reload: fetched script failed to compile.") return end
            pcall(function() gui:Destroy() end)
            task.spawn(function() task.wait(0.3) pcall(f) end)
        end

        local relBtn=mkButton(miscC,"Reload ALL clients (this machine)",C.amber,UDim2.fromOffset(230,28),UDim2.fromOffset(0,978))
        relBtn.MouseButton1Click:Connect(function()
            if not writefile then setStatus("Executor lacks writefile - can't signal fleet.") return end
            pcall(function() writefile(RELOAD_FILE, tostring(os.time()).."_"..tostring(math.random(1,1e6))) end)
            setStatus("Fleet reload signaled - every client restarts within ~2s.")
        end)
        mkLabel(miscC,"Change settings here, then press this: every running toolkit on this machine (all 12 clients) restarts itself from the local script8.lua in the executor workspace folder and loads the settings you just saved. This client restarts too.",
            UDim2.new(1,0,0,44),UDim2.fromOffset(0,1010),C.dim,Enum.Font.Gotham,10).TextWrapped=true

        task.spawn(function()  -- the watcher: every client runs this
            while gui.Parent do
                task.wait(2)
                local cur=baseline
                pcall(function() if isfile and isfile(RELOAD_FILE) then cur=readfile(RELOAD_FILE) end end)
                if cur~=baseline then
                    baseline=cur
                    doReload()
                end
            end
        end)

        -- boot: apply persisted perf mode
        if getgenv().PvBPerfMode then task.defer(enablePerf) rfPerf() end
    end
    __buildPerfFleet()
    local function __buildManualSell()
        local PDm
        pcall(function() PDm = require(RS:WaitForChild("PlayerData")) end)
        local function favs()
            local ok,f = pcall(function()
                local g = PDm and PDm:GetData()
                local d = g and (g.Data or g)
                return d and d.Favorites
            end)
            return (ok and type(f)=="table") and f or {}
        end
        local function nameOf(t) return t:GetAttribute("PlantName") or t.Name end
        local function isPlant(t) return t:IsA("Tool") and t:HasTag("PlantTool") end

        -- every unhearted plant of one type, bag and hand
        local function unhearted(name)
            local fav, out = favs(), {}
            for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
                if c then for _,t in ipairs(c:GetChildren()) do
                    if isPlant(t) and nameOf(t)==name then
                        local id = t:GetAttribute("ID")
                        local f = id and fav[id]
                        if id and not (f ~= nil and f ~= false) then out[#out+1] = t end
                    end
                end end
            end
            return out
        end
        -- name -> unhearted count, for the dropdown
        local function counts()
            local fav, c = favs(), {}
            for _,box in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
                if box then for _,t in ipairs(box:GetChildren()) do
                    if isPlant(t) then
                        local id = t:GetAttribute("ID")
                        local f = id and fav[id]
                        if id and not (f ~= nil and f ~= false) then
                            local n = nameOf(t) c[n] = (c[n] or 0) + 1
                        end
                    end
                end end
            end
            return c
        end

        local selected, running = nil, false

        mkSection(miscC,"Manual sell",1128)
        local pickBtn = mkButton(miscC,"Plant: pick one",C.blue,UDim2.fromOffset(226,28),UDim2.fromOffset(0,1154))
        local sellBtn = mkButton(miscC,"Sell unhearted",C.amber,UDim2.fromOffset(156,28),UDim2.fromOffset(230,1154))
        local lbl     = mkLabel(miscC,"Pick a plant, then sell every unhearted one of it.",UDim2.new(1,0,0,20),UDim2.fromOffset(0,1188),C.dim,Enum.Font.Gotham,12)

        -- dropdown list
        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.fromOffset(226,150) list.Position = UDim2.fromOffset(0,1184)
        list.BackgroundColor3 = C.panel list.BorderSizePixel = 0 list.ZIndex = 20
        list.ScrollBarThickness = 6 list.CanvasSize = UDim2.new() list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.Visible = false list.Parent = miscC
        corner(list,6)
        local lay = Instance.new("UIListLayout") lay.Padding = UDim.new(0,2) lay.SortOrder = Enum.SortOrder.Name lay.Parent = list

        local function paintPick()
            if not selected then pickBtn.Text = "Plant: pick one" return end
            local n = counts()[selected] or 0
            pickBtn.Text = ("Plant: %s (%d)"):format(selected, n)
        end
        local function closeList() list.Visible = false end
        local function openList()
            for _,ch in ipairs(list:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
            local c = counts()
            local names = {}
            for n in pairs(c) do names[#names+1] = n end
            table.sort(names)
            if #names == 0 then
                lbl.Text = "No unhearted plants in your inventory."
                return
            end
            for _,n in ipairs(names) do
                local b = Instance.new("TextButton")
                b.Name = n
                b.Size = UDim2.new(1,-8,0,24)
                b.BackgroundColor3 = C.row b.BorderSizePixel = 0 b.ZIndex = 21
                b.TextColor3 = C.txt b.Font = Enum.Font.Gotham b.TextSize = 12
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.Text = ("  %s  (%d)"):format(n, c[n])
                b.Parent = list
                corner(b,4)
                b.MouseButton1Click:Connect(function()
                    selected = n
                    closeList()
                    paintPick()
                    lbl.Text = ("%d unhearted %s ready to sell."):format(c[n], n)
                end)
            end
            list.Visible = true
        end
        pickBtn.MouseButton1Click:Connect(function()
            if running then return end
            if list.Visible then closeList() else openList() end
        end)

        local function rfSell()
            sellBtn.Text = running and "Stop" or "Sell unhearted"
            sellBtn.BackgroundColor3 = running and C.red or C.amber
        end

        sellBtn.MouseButton1Click:Connect(function()
            if running then running = false rfSell() lbl.Text = "stopping..." return end
            if not selected then lbl.Text = "Pick a plant first." return end
            closeList()
            running = true rfSell()
            task.spawn(function()
                -- FAST PASS, THEN MOP UP.
                -- Waiting to confirm each plant sold before moving on cost up
                -- to ~1s per plant. Instead: equip, sell, move straight to the
                -- next one, the whole list in one sweep. Then recount, and run
                -- another sweep over whatever is still there. Repeats until the
                -- type is gone, or a sweep removes nothing (server refusing).
                local name   = selected
                -- TESTED: the server accepts roughly one sell every 2 seconds and
                -- silently drops anything faster. So every sell goes through the
                -- toolkit's shared 2.2s gate (PvBFireSell), which fires at that
                -- pace and shares the budget fairly with the Keep auto-sell.
                -- Firing faster just wastes calls; this way each one lands.
                local start  = #unhearted(name)
                local remain = start
                local stalls, pass = 0, 0
                local ItemSellR = RS.Remotes:FindFirstChild("ItemSell")
                local hum
                local okRun, runErr = pcall(function()
                while running and remain > 0 and stalls < 2 do
                    pass = pass + 1
                    for _,t in ipairs(unhearted(name)) do
                        if not running then break end
                        if t.Parent then
                            local ch = LocalPlayer.Character
                            hum = ch and ch:FindFirstChildOfClass("Humanoid")
                            if hum and t.Parent ~= ch then pcall(function() hum:EquipTool(t) end) end
                            local w0 = os.clock()
                            while t.Parent ~= ch and os.clock()-w0 < 0.25 do task.wait() end
                            -- the gate waits up to ~2.2s, then fires while this
                            -- plant is still the one in hand
                            local sellFn = getgenv().PvBFireSell
                            if sellFn then sellFn(true)
                            elseif ItemSellR then pcall(function() ItemSellR:FireServer(true) end) task.wait(2.2) end
                        end
                    end
                    task.wait(0.4)           -- let the last sale replicate before recounting
                    local now = #unhearted(name)
                    if now >= remain then stalls = stalls + 1 else stalls = 0 end
                    remain = now
                    lbl.Text = ("selling %s: %d/%d sold (pass %d)"):format(name, start-remain, start, pass)
                end
                end)
                if hum then pcall(function() hum:UnequipTools() end) end
                if not okRun then warn("[ManualSell] "..tostring(runErr)) end
                local sold = start - remain
                if remain == 0 then
                    lbl.Text = ("Done: sold all %d %s"):format(sold, name)
                elseif stalls >= 2 and sold == 0 then
                    lbl.Text = ("Server refused to sell %s, even one at a time."):format(name)
                elseif stalls >= 2 then
                    lbl.Text = ("Sold %d %s, %d wouldn't sell."):format(sold, name, remain)
                else
                    lbl.Text = ("Stopped: sold %d of %d %s"):format(sold, start, name)
                end
                setStatus(("Manual sell: %d %s sold"):format(sold, name))
                running = false rfSell() paintPick()
            end)
        end)
    end
    __buildManualSell()

    ------------------------------------------------------------------
    -- Hotbar auto-arrange. Stock Roblox backpack assigns slots by the
    -- ORDER tools are added: 1st..9th -> slots 1..9, 10th -> slot 0.
    -- Target layout:  bucket -> 7, bucket -> 8, corn -> 9, kelp -> 0.
    --
    -- Why the old version "sometimes just didn't work": it required BOTH
    -- corn and kelp to exist or it returned without doing anything, and
    -- it ran exactly once at inject. If a seed type was out at that
    -- moment (which happens constantly mid-pipeline) you got no hotbar
    -- at all. Now it places whatever it finds and re-checks on a loop,
    -- re-arranging only when the layout has actually drifted.
    ------------------------------------------------------------------
    local function __buildHotbar()
        local function findTools(BP)
            local corn, kelp, buckets = nil, nil, {}
            for _, t in ipairs(BP:GetChildren()) do
                if t:IsA("Tool") then
                    local h = (tostring(t.Name).." "
                            ..tostring(t:GetAttribute("ItemName") or "").." "
                            ..tostring(t:GetAttribute("SeedName") or "").." "
                            ..tostring(t:GetAttribute("Gear") or "")):lower()
                    if h:find("corn") and h:find("seed") and not corn then corn = t
                    elseif h:find("kelp") and h:find("seed") and not kelp then kelp = t
                    elseif h:find("water") and #buckets < 2 then
                        -- premium bucket first so it lands in the lower slot
                        if h:find("premium") then table.insert(buckets, 1, t)
                        else buckets[#buckets+1] = t end
                    end
                end
            end
            return corn, kelp, buckets
        end

        -- the tail of the desired order, in slot order 7,8,9,0
        local function desiredTail(corn, kelp, buckets)
            local tail = {}
            if buckets[1] then tail[#tail+1] = buckets[1] end
            if buckets[2] then tail[#tail+1] = buckets[2] end
            if corn then tail[#tail+1] = corn end
            if kelp then tail[#tail+1] = kelp end
            return tail
        end

        local function alreadyArranged(BP, tail)
            if #tail == 0 then return true end
            local kids = BP:GetChildren()
            local tools = {}
            for _, t in ipairs(kids) do if t:IsA("Tool") then tools[#tools+1] = t end end
            -- the tail must occupy the final positions, in order, ending at
            -- index 10 (slot 0) when we have a full set
            local want = 10 - (4 - #tail)
            if #tools < want then return false end
            for i, t in ipairs(tail) do
                if tools[want - #tail + i] ~= t then return false end
            end
            return true
        end

        local function arrange()
            local BP = LocalPlayer:FindFirstChild("Backpack")
            if not BP then return false end
            local corn, kelp, buckets = findTools(BP)
            local tail = desiredTail(corn, kelp, buckets)
            if #tail == 0 then return false end
            if alreadyArranged(BP, tail) then return true end

            local inTail = {}
            for _, t in ipairs(tail) do inTail[t] = true end
            local others = {}
            for _, t in ipairs(BP:GetChildren()) do
                if t:IsA("Tool") and not inTail[t] then others[#others+1] = t end
            end

            local lead = 10 - #tail          -- how many fillers before the tail
            local order = {}
            for i = 1, math.min(lead, #others) do order[#order+1] = others[i] end
            for _, t in ipairs(tail) do order[#order+1] = t end
            for i = lead + 1, #others do order[#order+1] = others[i] end

            local ok = pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:UnequipTools() task.wait(0.15) end
                for _, t in ipairs(order) do t.Parent = nil end
                task.wait(0.1)
                for _, t in ipairs(order) do
                    t.Parent = BP
                    task.wait(0.03)
                end
            end)
            if ok then
                local bits = {}
                if buckets[1] then bits[#bits+1] = "bucket->7" end
                if buckets[2] then bits[#bits+1] = "bucket->8" end
                if corn then bits[#bits+1] = "corn->9" end
                if kelp then bits[#bits+1] = "kelp->0" end
                setStatus("Hotbar: "..table.concat(bits, ", "))
            end
            return ok
        end

        task.spawn(function()
            task.wait(8)                       -- let the bag replicate in
            while gui.Parent do
                -- never re-shuffle mid-action: moving tools out of the bag
                -- while a loop is equipping them causes dropped remotes
                local busy = getgenv().PvBOPRun or getgenv().PvBCycleOn
                    or (getgenv().PvBPlantAPI and getgenv().PvBPlantAPI.isRunning
                        and getgenv().PvBPlantAPI.isRunning())
                if not busy then pcall(arrange) end
                task.wait(30)
            end
        end)
        getgenv().PvBFixHotbar = function() return arrange() end
    end
    __buildHotbar()
end

----------------------------------------------------------------------
--  FLEET CENSUS  (cross-account fuse-output tracker)
--
--  This half only WRITES data. The viewer is a separate console app that
--  runs outside Roblox entirely - see PvBFleet.ps1. Nothing here draws a
--  window; checking progress must never mean opening a laggy client.
--
--    PvBFleet/<username>.json   one per account, rewritten every 20s
--
--  Each file carries the watched items AND a full dump of every plant in
--  the bag, so if a name is ever spelled differently in-game than we
--  expect, the console can still show you what is actually there.
----------------------------------------------------------------------
do
    local FLEET_DIR   = "PvBFleet"
    local WRITE_EVERY = 20

    local canWrite = (type(writefile)=="function")
    local canDir   = (type(isfolder)=="function" and type(makefolder)=="function")

    local useDir = false
    if canWrite and canDir then
        pcall(function()
            if not isfolder(FLEET_DIR) then makefolder(FLEET_DIR) end
            useDir = isfolder(FLEET_DIR)
        end)
    end
    local function myFile()
        if useDir then return FLEET_DIR.."/"..LocalPlayer.Name..".json" end
        return "PvBFleet_"..LocalPlayer.Name..".json"
    end

    -- WATCH LIST.
    -- Bumping WATCH_VER force-overwrites the value held in getgenv(). That
    -- matters: getgenv() is the executor's shared global table and it
    -- SURVIVES re-injection, so a plain `if x==nil then x=default end`
    -- keeps whatever the first inject of this Roblox session set, no matter
    -- how the file is edited afterwards. That is exactly why a corrected
    -- spelling here appeared not to take effect.
    local WATCH_VER = 3
    if getgenv().PvBWatchVer ~= WATCH_VER then
        getgenv().PvBWatch    = "Dessert Destroyer, Wind Petal"
        getgenv().PvBWatchVer = WATCH_VER
    end

    -- Match on a spelling-tolerant form: strip non-letters and collapse any
    -- run of a repeated letter, so "Dessert" and "Desert" both reduce to
    -- "desert" and either spelling matches whichever the game actually uses.
    local function loose(s)
        s = tostring(s):lower():gsub("[^%a]","")
        -- Lua patterns do NOT allow a quantifier on a backreference, so the
        -- obvious "(%a)%1+" silently matches nothing. Collapse one doubled
        -- pair per pass until it stops changing.
        local prev
        repeat prev = s; s = s:gsub("(.)%1","%1") until s == prev
        return s
    end

    local function watchList()
        local out={}
        for part in tostring(getgenv().PvBWatch or ""):gmatch("[^,]+") do
            part = part:gsub("^%s+",""):gsub("%s+$","")
            if part~="" then out[#out+1]=part end
        end
        if #out==0 then out={"Dessert Destroyer","Wind Petal"} end
        return out
    end

    local function census()
        local want = watchList()
        local wantLoose = {}
        for _,w in ipairs(want) do wantLoose[#wantLoose+1] = { disp=w, key=loose(w) } end

        local items, all, heavy, seeds = {}, {}, {}, {}
        -- seeds stack, so a "Corn Seed" tool can represent hundreds. Same
        -- quantity attributes the OP pipeline reads.
        local SEED_QTY = { "Count","Amount","Quantity","Stack","StackCount",
                           "Stacks","Num","Number","Seeds","SeedCount","Total" }
        local function qtyOf(t)
            for _,a in ipairs(SEED_QTY) do
                local v = tonumber(t:GetAttribute(a))
                if v and v >= 1 then return math.floor(v) end
            end
            return 1
        end
        for _,c in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if c then for _,t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") then
                    local nm  = tostring(t:GetAttribute("PlantName") or t.Name)
                    local mut = tostring(t:GetAttribute("Colors") or "Normal")
                    if mut=="" then mut="Normal" end
                    -- full inventory dump, so a mis-spelled watch term can
                    -- never hide what you actually own
                    if t:HasTag("PlantTool") or t:GetAttribute("PlantName") then
                        local ak = mut.."|"..nm
                        all[ak] = (all[ak] or 0) + 1
                        -- Size on a plant tool IS the weight in kg. Only fully
                        -- grown plants are worth counting as stock: anything
                        -- under target is not submittable and not fusable, so
                        -- including it just inflated the numbers.
                        local w = tonumber(t:GetAttribute("Size")) or tonumber(t:GetAttribute("Weight")) or 0
                        if w >= 19.95 then heavy[ak] = (heavy[ak] or 0) + 1 end
                    end
                    -- forbidden SEEDS, counted by stack quantity, per account
                    local sn = t:GetAttribute("SeedName")
                    if sn then
                        local sl = tostring(sn):lower()
                        for _,k in ipairs({ "Corn", "Kelp" }) do
                            if sl:find(k:lower(),1,true) then
                                seeds[k] = (seeds[k] or 0) + qtyOf(t)
                                break
                            end
                        end
                    end
                    local nl = loose(nm)
                    for _,w in ipairs(wantLoose) do
                        if nl:find(w.key,1,true) then
                            local key = mut.."|"..w.disp
                            items[key] = (items[key] or 0) + 1
                            break
                        end
                    end
                end
            end end
        end
        return items, all, heavy, seeds
    end

    ------------------------------------------------------------------
    -- HEARTBEAT for the external launcher.
    --
    -- One file per account, rewritten every few seconds. Its existence and
    -- freshness prove the ENTIRE chain in one signal:
    --     process alive -> joined the server -> save data resolved ->
    --     toolkit injected -> toolkit still executing
    --
    -- The launcher judged health by process memory, which cannot see any of
    -- that: a client stuck on "Loading data" has already loaded the place and
    -- looks fat and healthy, while a perfectly good client whose working set
    -- has been trimmed looks dead. Keyed by account name, not PID, so there is
    -- no fragile launch-order mapping either.
    ------------------------------------------------------------------
    local function hbFile()
        if useDir then return FLEET_DIR.."/hb_"..LocalPlayer.Name..".json" end
        return "PvBFleet_hb_"..LocalPlayer.Name..".json"
    end
    local function writeHeartbeat()
        if not canWrite then return end
        pcall(function()
            local plot  = LocalPlayer:GetAttribute("Plot")
            -- "base" is a SEPARATE failure from "data": an account can have its
            -- inventory fully loaded and still have no garden of its own, having
            -- spawned into someone else's. Ownership of a plot is the only
            -- reliable way to tell from inside the client.
            local baseOK = (getgenv().PvBBaseOK == true)
            local ready = (getgenv().PvBDataOK == true)
                          and (plot ~= nil)
                          and baseOK
                          and (LocalPlayer:FindFirstChild("Backpack") ~= nil)
            writefile(hbFile(), HttpService:JSONEncode({
                u       = LocalPlayer.Name,
                t       = os.time(),
                ready   = ready,          -- false while stuck on "Loading data"
                data    = (getgenv().PvBDataOK == true),
                base    = (getgenv().PvBBaseOK == true),
                plot    = plot and tostring(plot) or nil,
                place   = tostring(game.PlaceId),
                job     = tostring(game.JobId),
                opRun   = (getgenv().PvBOPRun == true),
            }))
        end)
    end
    task.spawn(function()
        writeHeartbeat()                  -- first beat immediately on inject
        while alive() do
            writeHeartbeat()
            task.wait(5)
        end
    end)

    local function writeCensus()
        if not canWrite then return false end
        return (pcall(function()
            local items, all, heavy, seeds = census()
            writefile(myFile(), HttpService:JSONEncode({
                u     = LocalPlayer.Name,
                t     = os.time(),
                watch = getgenv().PvBWatch,
                items = items,
                all   = all,
                heavy = heavy,      -- 20kg+ only: the stock that can be used
                seeds = seeds,      -- corn / kelp seed counts, stack-aware
                -- whether this client is ACTUALLY fishing right now, so the
                -- console can rate seeds against fishing time instead of
                -- wall clock. An account parked in the planting phase earns
                -- no seeds and must not drag its own rate down.
                fishing = (getgenv().PvBAutoFish == true),
                opPhase = tostring(getgenv().PvBOPPhasePub or ""),
            }))
        end))
    end

    getgenv().PvBWriteCensus = writeCensus   -- callable by hand for a forced update

    task.spawn(function()
        task.wait(6)
        while alive() do
            writeCensus()
            task.wait(WRITE_EVERY)
        end
    end)
end

----------------------------------------------------------------------
--  STATS PANEL  (separate window, opened from the Misc tab)
--  Auto-detects your config from equipped cards (+tier), active potions,
--  and server luck, then logs brainrot spawn stats under that config.
--  Re-checks the config every 15s and switches on its own. Configs are
--  deletable. Hidden by default. Persists to .PvBStats/stats.json.
----------------------------------------------------------------------
do
    local PD
    pcall(function() PD = require(RS:WaitForChild("PlayerData")) end)
    local LANE  = workspace:WaitForChild("ScriptedMap"):WaitForChild("MissionBrainrots")
    local BP    = LocalPlayer:WaitForChild("Backpack")

    local DATA
    local function refreshData() pcall(function() DATA = PD and PD:GetDataAsync() or DATA end) end
    refreshData()

    local DIR, FILE = ".PvBStats", ".PvBStats/stats.json"
    local canWrite = (type(writefile)=="function" and type(readfile)=="function")
    local canFS    = (type(isfile)=="function" and type(isfolder)=="function" and type(makefolder)=="function")
    if canFS and not isfolder(DIR) then pcall(makefolder,DIR) end

    local activeMode = "none"
    local buckets    = {}
    local order      = {}
    local winW, winH = 400, 420
    local dirty = false

    ---------- config detection ----------
    -- matched as substrings of the normalized Type, so apostrophes / extra words
    -- (e.g. "Alchemist's Expertise") and "The"/"Collection" parts don't matter
    local CARD_WL = {
        { root="secret",    disp="Secret" },
        { root="forbidden", disp="Forbidden" },
        { root="wheel",     disp="Wheel" },
        { root="weighted",  disp="Weighted" },
        { root="flashmob",  disp="FlashMob" },
        { root="alchemist", disp="Alchemist" },
        { root="trick",     disp="TrickOrTreat" },
    }
    -- matched as substrings of the normalized key, so "Riot Potion",
    -- "Pine Tree Potion", "Pre-Workout" etc. all match regardless of suffix/spacing
    local POTION_WL = {
        { root="riot",    disp="Riot" },
        { root="biggify", disp="Biggify" },
        { root="pine",    disp="Pine" },
		{ root="luck",    disp="LuckyPtn" },
        { root="workout", disp="PreWorkout" },
    }
    local function norm(s) return tostring(s):lower():gsub("[^%a%d]","") end
    local function potionDisp(nameNorm)
        for _,e in ipairs(POTION_WL) do
            if nameNorm:find(e.root, 1, true) then return e.disp end
        end
        return nil
    end
    local function cardDisp(nameNorm)
        for _,e in ipairs(CARD_WL) do
            if nameNorm:find(e.root, 1, true) then return e.disp end
        end
        return nil
    end

    local function equippedCards()
        local out={}
        local d=DATA
        if d and type(d.Cards)=="table" and type(d.Cards.Equipped)=="table" and type(d.Cards.Inventory)=="table" then
            for _,guid in pairs(d.Cards.Equipped) do
                local e = guid and d.Cards.Inventory[guid]
                if e then
                    local disp=cardDisp(norm(tostring(e.Type)))
                    if disp then
                        local tier=(type(e.Data)=="table" and tonumber(e.Data.Tier)) or 1
                        out[#out+1]=disp.."T"..tier
                    end
                end
            end
        end
        table.sort(out) return out
    end
    local function activePotions()
        local out={}
        local d=DATA
        if d and type(d.Potions)=="table" then
            for name,v in pairs(d.Potions) do
                local left = (type(v)=="number" and v)
                    or (type(v)=="table" and tonumber(v.TimeLeft or v.Time or v.Duration or v.Seconds)) or 1
                if (left or 0)>0 then
                    local disp=potionDisp(norm(tostring(name)))
                    if disp then out[#out+1]=disp end
                end
            end
        end
        table.sort(out) return out
    end
    -- any active potion key we did NOT recognize (so a missed one stays visible)
    local function unmatchedPotions()
        local out={}
        local d=DATA
        if d and type(d.Potions)=="table" then
            for name,v in pairs(d.Potions) do
                local left=(type(v)=="number" and v) or (type(v)=="table" and tonumber(v.TimeLeft or v.Time or v.Duration or v.Seconds)) or 1
                if (left or 0)>0 and not potionDisp(norm(tostring(name))) then out[#out+1]=tostring(name) end
            end
        end
        table.sort(out) return out
    end
    -- equipped cards we did NOT recognize (shows the raw .Type so we can map it)
    local function unmatchedCards()
        local out={}
        local d=DATA
        if d and type(d.Cards)=="table" and type(d.Cards.Equipped)=="table" and type(d.Cards.Inventory)=="table" then
            for _,guid in pairs(d.Cards.Equipped) do
                local e = guid and d.Cards.Inventory[guid]
                if e and not cardDisp(norm(tostring(e.Type))) then out[#out+1]=tostring(e.Type) end
            end
        end
        table.sort(out) return out
    end
    -- admin server luck: workspace attribute "ServerLuck" (number, shown as Nx)
    local function serverLuck()
        local v=tonumber(workspace:GetAttribute("ServerLuck"))
        if v and v>1.0001 then
            local s = (v%1==0) and tostring(math.floor(v)) or tostring(math.floor(v*10+0.5)/10)
            return "Luck"..s.."x"
        end
        return nil
    end
    local function configKey()
        local seg={}
        local c=equippedCards() local p=activePotions() local luck=serverLuck()
        if #c>0 then seg[#seg+1]=table.concat(c,"+") end
        if #p>0 then seg[#seg+1]=table.concat(p,"+") end
        if luck then seg[#seg+1]=luck end
        if #seg==0 then return "none" end
        return table.concat(seg," | ")
    end

    local function curKey() return activeMode or "none" end
    local function bucket(k)
        local b=buckets[k]
        if not b then
            b={spawns=0,sizeSum=0,sizeCount=0,sizeMin=math.huge,sizeMax=0,span=0,lastT=nil,millions=0,rar={}}
            buckets[k]=b order[#order+1]=k dirty=true
        end
        return b
    end

    ---------- persistence ----------
    local function loadSaved()
        if not canWrite then return end
        if canFS and not isfile(FILE) then return end
        local ok,raw = pcall(readfile,FILE) if not ok or not raw or #raw==0 then return end
        local ok2,t = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok2 or type(t)~="table" then return end
        if type(t.order)=="table" then for _,k in ipairs(t.order) do order[#order+1]=tostring(k) end end
        if type(t.activeMode)=="string" then activeMode=t.activeMode end
        if type(t.win)=="table" then winW=tonumber(t.win.w) or winW winH=tonumber(t.win.h) or winH end
        if type(t.buckets)=="table" then
            for k,b in pairs(t.buckets) do
                buckets[k]={ spawns=b.spawns or 0, sizeSum=b.sizeSum or 0, sizeCount=b.sizeCount or 0,
                    sizeMin=((b.sizeCount or 0)>0 and (b.sizeMin or 0)) or math.huge,
                    sizeMax=b.sizeMax or 0, span=b.span or 0, lastT=nil,
                    millions=b.millions or 0, rar=(type(b.rar)=="table" and b.rar or {}) }
                if not table.find(order,k) then order[#order+1]=k end
            end
        end
    end
    local function snap()
        local out={ v=3, order=order, activeMode=activeMode, win={w=winW,h=winH}, buckets={} }
        for k,b in pairs(buckets) do
            out.buckets[k]={ spawns=b.spawns, sizeSum=b.sizeSum, sizeCount=b.sizeCount,
                sizeMin=(b.sizeCount>0 and b.sizeMin or 0), sizeMax=b.sizeMax, span=b.span,
                millions=b.millions, rar=b.rar }
        end
        return out
    end
    local function saveNow()
        if not canWrite then return end
        local ok,j=pcall(function() return HttpService:JSONEncode(snap()) end)
        if ok then pcall(writefile,FILE,j) dirty=false end
    end
    loadSaved()

    ---------- brainrot stream ----------
    local seen={}
    local function logSpawn(m)
        if not m:IsA("Model") or seen[m] then return end seen[m]=true
        task.spawn(function()
            local size=m:GetAttribute("Size") local t0=os.clock()
            while size==nil and os.clock()-t0<3 do task.wait() size=m:GetAttribute("Size") end
            local rarity=m:GetAttribute("Rarity") or "?"
            local b=bucket(curKey())
            local now=os.clock()
            if b.lastT then b.span=b.span+math.min(now-b.lastT,10) end
            b.lastT=now b.spawns+=1
            if size then b.sizeSum+=size b.sizeCount+=1 b.sizeMin=math.min(b.sizeMin,size) b.sizeMax=math.max(b.sizeMax,size) end
            b.rar[rarity]=(b.rar[rarity] or 0)+1
            dirty=true
        end)
    end
    for _,m in ipairs(LANE:GetChildren()) do logSpawn(m) end
    LANE.ChildAdded:Connect(logSpawn)

    -- count each 1M+ brainrot only once, keyed by its unique ID, so pulling one
    -- out of the hotbar and back into the bag can't re-count it
    local countedMillion = {}
    BP.ChildAdded:Connect(function(t)
        if t:IsA("Tool") and t:GetAttribute("ID") and not t:GetAttribute("PlantName") then
            local id=t:GetAttribute("ID")
            task.delay(0.3,function()
                if id and not countedMillion[id] and (tonumber(t:GetAttribute("Worth")) or 0) >= 1000000 then
                    countedMillion[id]=true
                    bucket(curKey()).millions+=1 dirty=true
                end
            end)
        end
    end)

    ---------- window ----------
    local sp=Instance.new("Frame") sp.Name="PvBStatsPanel"
    sp.Size=UDim2.fromOffset(winW,winH) sp.Position=UDim2.fromOffset(480,50)
    sp.BackgroundColor3=C.bg sp.BackgroundTransparency=0.05 sp.BorderSizePixel=0 sp.Visible=false sp.Parent=gui
    corner(sp,12) do local s=Instance.new("UIStroke",sp) s.Thickness=1 s.Color=C.stroke s.Transparency=0.4 end
    getgenv().PvBStatsFrame = sp   -- Misc tab toggles this

    local header=Instance.new("Frame",sp) header.BackgroundTransparency=1 header.Size=UDim2.new(1,0,0,30) header.Position=UDim2.new() header.ZIndex=1
    mkLabel(header,"PvB Stats (auto)",UDim2.fromOffset(180,22),UDim2.fromOffset(14,6),C.txt,Enum.Font.GothamBold,15)
    local resetBtn=mkButton(sp,"Reset",C.grey,UDim2.fromOffset(54,22),UDim2.new(1,-172,0,6)) resetBtn.ZIndex=5
    local copyBtn =mkButton(sp,"Copy",C.blue,UDim2.fromOffset(54,22),UDim2.new(1,-114,0,6)) copyBtn.ZIndex=5
    local minB    =mkButton(sp,"-",C.grey,UDim2.fromOffset(48,22),UDim2.new(1,-56,0,6)) minB.Font=Enum.Font.GothamBold minB.TextSize=16 minB.ZIndex=5

    local cfgList=Instance.new("ScrollingFrame",sp) cfgList.Size=UDim2.new(1,-16,0,96) cfgList.Position=UDim2.fromOffset(8,36)
    cfgList.BackgroundColor3=C.panel cfgList.BackgroundTransparency=0.3 cfgList.BorderSizePixel=0
    cfgList.ScrollBarThickness=5 cfgList.CanvasSize=UDim2.new() cfgList.AutomaticCanvasSize=Enum.AutomaticSize.Y corner(cfgList,6)
    local cll=Instance.new("UIListLayout",cfgList) cll.Padding=UDim.new(0,3) cll.SortOrder=Enum.SortOrder.LayoutOrder
    local clp=Instance.new("UIPadding",cfgList) clp.PaddingTop=UDim.new(0,3) clp.PaddingLeft=UDim.new(0,3) clp.PaddingRight=UDim.new(0,3)

    local scroller=Instance.new("ScrollingFrame",sp) scroller.Size=UDim2.new(1,-16,1,-148) scroller.Position=UDim2.fromOffset(8,140)
    scroller.BackgroundColor3=C.panel scroller.BackgroundTransparency=0.15 scroller.BorderSizePixel=0
    scroller.ScrollBarThickness=6 scroller.CanvasSize=UDim2.new() scroller.AutomaticCanvasSize=Enum.AutomaticSize.Y corner(scroller,8)
    local bodyLbl=Instance.new("TextLabel",scroller) bodyLbl.BackgroundTransparency=1 bodyLbl.Size=UDim2.new(1,-16,0,10)
    bodyLbl.AutomaticSize=Enum.AutomaticSize.Y bodyLbl.Position=UDim2.fromOffset(8,6)
    bodyLbl.Font=Enum.Font.Gotham bodyLbl.TextSize=13 bodyLbl.TextColor3=C.txt bodyLbl.RichText=true
    bodyLbl.LineHeight=1.15 bodyLbl.TextWrapped=true
    bodyLbl.TextXAlignment=Enum.TextXAlignment.Left bodyLbl.TextYAlignment=Enum.TextYAlignment.Top bodyLbl.Text=""

    local grip=mkButton(sp,"",Color3.fromRGB(90,90,100),UDim2.fromOffset(18,18),UDim2.new(1,-20,1,-20)) grip.AutoButtonColor=false grip.ZIndex=10
    do local t=mkLabel(grip,"//",UDim2.new(1,0,1,0),UDim2.new(),Color3.new(1,1,1),Enum.Font.GothamBold,10) t.TextXAlignment=Enum.TextXAlignment.Center t.ZIndex=11 end

    local function delConfig(label)
        buckets[label]=nil
        local i=table.find(order,label) if i then table.remove(order,i) end
        if activeMode==label then activeMode="none" end
        dirty=true saveNow()
    end
    local rebuildConfigs
    rebuildConfigs=function()
        for _,c in ipairs(cfgList:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
        local o=0
        local function chip(label)
            o=o+1
            local rowf=Instance.new("Frame",cfgList) rowf.Size=UDim2.new(1,-6,0,24) rowf.BackgroundTransparency=1 rowf.LayoutOrder=o
            local isActive = (label==activeMode)
            local sel=mkButton(rowf,(isActive and "* " or "")..label, isActive and C.green or C.row, UDim2.new(1,-26,1,0),UDim2.new())
            sel.TextXAlignment=Enum.TextXAlignment.Left sel.TextSize=11 local p=Instance.new("UIPadding",sel) p.PaddingLeft=UDim.new(0,8)
            sel.AutoButtonColor=false sel.TextTruncate=Enum.TextTruncate.AtEnd
            local x=mkButton(rowf,"x",C.red,UDim2.fromOffset(22,24),UDim2.new(1,-22,0,0))
            x.MouseButton1Click:Connect(function() delConfig(label) rebuildConfigs() end)
        end
        local shown={}
        if activeMode and not table.find(order,activeMode) then chip(activeMode) shown[activeMode]=true end
        for _,k in ipairs(order) do if not shown[k] then chip(k) shown[k]=true end end
        if o==0 then mkLabel(cfgList,"(detecting config...)",UDim2.new(1,-6,0,22),UDim2.new(),C.dim,Enum.Font.Gotham,12) end
    end
    rebuildConfigs()

    local function applyLayout(h)
        local hidden = h<=60
        cfgList.Visible=not hidden scroller.Visible=not hidden grip.Visible=not hidden
    end
    local minimized=false
    minB.MouseButton1Click:Connect(function()
        minimized=not minimized
        if minimized then sp.Size=UDim2.fromOffset(winW,40) applyLayout(40)
        else sp.Size=UDim2.fromOffset(winW,winH) applyLayout(winH) end
    end)
    resetBtn.MouseButton1Click:Connect(function()
        buckets={} order={} dirty=true saveNow() rebuildConfigs() setStatus("Stats reset.")
    end)
    copyBtn.MouseButton1Click:Connect(function()
        local ok,j=pcall(function() return HttpService:JSONEncode(snap()) end)
        if ok and type(setclipboard)=="function" then setclipboard(j) setStatus("Stats JSON copied.")
        elseif ok and type(toclipboard)=="function" then toclipboard(j) setStatus("Stats JSON copied.")
        else setStatus("Clipboard n/a; saved to "..FILE) end
    end)

    local drag={a=false} local rez={a=false}
    header.InputBegan:Connect(function(io) if io.UserInputType==Enum.UserInputType.MouseButton1 then drag.a=true drag.s=io.Position drag.base=sp.Position end end)
    grip.InputBegan:Connect(function(io) if io.UserInputType==Enum.UserInputType.MouseButton1 then rez.a=true rez.s=io.Position rez.base=sp.AbsoluteSize end end)
    UIS.InputChanged:Connect(function(io)
        if io.UserInputType~=Enum.UserInputType.MouseMovement then return end
        if drag.a then local d=io.Position-drag.s
            sp.Position=UDim2.new(drag.base.X.Scale,drag.base.X.Offset+d.X,drag.base.Y.Scale,drag.base.Y.Offset+d.Y)
        elseif rez.a then local d=io.Position-rez.s
            winW=math.max(300,math.floor(rez.base.X+d.X)) winH=math.max(200,math.floor(rez.base.Y+d.Y))
            if not minimized then sp.Size=UDim2.fromOffset(winW,winH) end
        end
    end)
    UIS.InputEnded:Connect(function(io) if io.UserInputType==Enum.UserInputType.MouseButton1 then
        if rez.a then dirty=true saveNow() end drag.a=false rez.a=false end end)

    ---------- render ----------
    local LBL = 'rgb(150,150,162)'   -- dim label colour
    local function render()
        local keys={} for k in pairs(buckets) do keys[#keys+1]=k end
        table.sort(keys, function(a,b)
            if a==activeMode and b~=activeMode then return true end
            if b==activeMode and a~=activeMode then return false end
            return a<b
        end)
        if #keys==0 then bodyLbl.Text="waiting for spawns..." return end
        local lines={}
        for _,k in ipairs(keys) do
            local b=buckets[k]
            local avg  = b.sizeCount>0 and (b.sizeSum/b.sizeCount*10) or 0
            local rate = b.spawns/math.max(1,b.span)
            local mn   = (b.sizeMin==math.huge and 0 or b.sizeMin*10)
            local mx   = b.sizeMax*10
            local active = (k==activeMode)
            local title = (active and "> " or "")..k
            if active then
                lines[#lines+1]=('<font color="rgb(110,220,165)"><b>%s</b></font>'):format(title)
            else
                lines[#lines+1]=('<font color="%s"><b>%s</b></font>'):format(LBL,title)
            end
            lines[#lines+1]=('   <font color="%s">spawns</font> %d      <font color="%s">rate</font> %.2f/s'):format(LBL,b.spawns,LBL,rate)
            lines[#lines+1]=('   <font color="%s">avg</font> %.0f kg   <font color="%s">min</font> %.0f kg   <font color="%s">max</font> %.0f kg   <font color="%s">1M+</font> %d'):format(LBL,avg,LBL,mn,LBL,mx,LBL,b.millions)
            local rk={} for r in pairs(b.rar) do rk[#rk+1]=r end table.sort(rk)
            if #rk>0 then
                local parts={} for _,r in ipairs(rk) do parts[#parts+1]=("%s %d"):format(r,b.rar[r]) end
                lines[#lines+1]='   <font color="'..LBL..'">'..table.concat(parts,"   ")..'</font>'
            end
            lines[#lines+1]=""
        end
        local uc=unmatchedCards()
        if #uc>0 then
            lines[#lines+1]=('<font color="rgb(190,140,45)">unrecognized equipped cards: %s</font>'):format(table.concat(uc,", "))
        end
        local um=unmatchedPotions()
        if #um>0 then
            lines[#lines+1]=('<font color="rgb(190,140,45)">unrecognized active potions: %s</font>'):format(table.concat(um,", "))
        end
        bodyLbl.Text=table.concat(lines,"\n")
    end

    ---------- driver ----------
    task.spawn(function()
        local tick=0
        while sp.Parent do
            refreshData()
            tick+=1
            if tick%15==0 then          -- 15s buffer on config re-check
                local key=configKey()
                if key~=activeMode then
                    activeMode=key bucket(key) dirty=true rebuildConfigs()
                    setStatus("stats: config -> "..key)
                end
            end
            render()
            if dirty and tick%5==0 then saveNow() end
            task.wait(1)
        end
    end)
    -- detect the starting config immediately (don't wait the first 15s)
    task.spawn(function()
        task.wait(2) refreshData()
        local key=configKey()
        activeMode=key bucket(key) rebuildConfigs() render()
    end)
    setStatus("Stats panel ready (open from Misc)"..(canWrite and "" or " (no file access)"))
end
showTab("Home")
print("PvB Main UI loaded.")

print("[PvBToolkit] build 2026-07-27f loaded (per-event reset, clear-garden waters)")