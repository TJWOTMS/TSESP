-- TSESP - Lightweight ESP Library for executors (Luau)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera

local Drawing = Drawing

local TSESP = {}
TSESP.__index = TSESP

local function resolveFont(f)
    if typeof(f) == "EnumItem" then return f end
    if type(f) == "string" then
        local ef = Enum.Font[f]
        if ef then return ef end
    end
    if Enum and Enum.Font and Enum.Font.SFPixelate then
        return Enum.Font.SFPixelate
    end
    return Enum.Font.SourceSans
end

TSESP.Settings = {
    Enabled = true,
    Box = true,
    Name = true,
    Tracer = true,
    Healthbar = true,
    HealthbarGradient = false,
    GradientColors = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,255,0), Color3.fromRGB(0,255,0)},
    GradientSpeed = 1, -- cycles per second
    GradientSegments = 12,
    TeamColor = true,
    VisibleCheck = true,
    MaxDistance = 1000,
    Thickness = 1,
    Font = resolveFont("SFPixelate"),
    Outline = true,
    Color = Color3.fromRGB(255,255,255),
    TracerFrom = "Bottom", -- "Bottom" | "Top" | "Center"
}

TSESP._players = {}

local function isDrawingAvailable()
    return type(Drawing) == "table" or type(Drawing) == "function"
end

local function safeWorldToViewport(pos)
    if not Camera or not Camera.WorldToViewportPoint then
        return Vector2.new(0,0), 0, false
    end
    local x,y,z = Camera:WorldToViewportPoint(pos)
    return Vector2.new(x,y), z, z > 0
end

local function createDrawing(kind)
    if not isDrawingAvailable() then return nil end
    local ok, obj = pcall(function() return Drawing.new(kind) end)
    if not ok then return nil end
    return obj
end

local function lerp(a,b,t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return Color3.new(lerp(c1.R, c2.R, t), lerp(c1.G, c2.G, t), lerp(c1.B, c2.B, t))
end

local function sampleGradient(colors, t)
    local n = #colors
    if n == 0 then return Color3.new(1,1,1) end
    if n == 1 then return colors[1] end
    t = math.clamp(t, 0, 1)
    local total = (n - 1)
    local scaled = t * total
    local idx = math.floor(scaled) + 1
    if idx >= n then return colors[n] end
    local localT = scaled - (idx - 1)
    return lerpColor(colors[idx], colors[idx + 1], localT)
end

local function getCharacterRoot(character)
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function raycastVisible(from, to, ignoreList)
    if not Workspace.Raycast then return true end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignoreList or {}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local dir = to - from
    local result = Workspace:Raycast(from, dir, params)
    return result == nil
end

local function makeESPForPlayer(player, settings)
    local obj = {}
    obj.Player = player
    obj.Settings = settings or {}
    obj.Enabled = true
    obj.Drawings = {}

    if isDrawingAvailable() then
        obj.Drawings.Box = createDrawing("Square")
        obj.Drawings.Tracer = createDrawing("Line")
        obj.Drawings.Name = createDrawing("Text")
        obj.Drawings.HealthBack = createDrawing("Square")
        obj.Drawings.HealthFront = createDrawing("Square")
        obj.Drawings.HealthSegments = {}
    end

    function obj:SetEnabled(val)
        self.Enabled = val and true or false
        for _,v in pairs(self.Drawings) do
            if type(v) == "table" then
                for _,seg in pairs(v) do if seg and seg.Visible ~= nil then seg.Visible = self.Enabled end end
            else
                if v and v.Visible ~= nil then v.Visible = self.Enabled end
            end
        end
    end

    function obj:SetOption(k,v)
        self.Settings[k] = v
    end

    function obj:Remove()
        for _,v in pairs(self.Drawings) do
            if type(v) == "table" then
                for _,seg in pairs(v) do if seg and type(seg.Remove) == "function" then pcall(function() seg:Remove() end) end end
            else
                if v and type(v.Remove) == "function" then pcall(function() v:Remove() end) end
            end
        end
        self.Drawings = {}
        self.Enabled = false
    end

    return obj
end

local function ensureSegments(eobj, count)
    if not isDrawingAvailable() then return end
    eobj.Drawings.HealthSegments = eobj.Drawings.HealthSegments or {}
    local segs = eobj.Drawings.HealthSegments
    while #segs < count do
        local n = createDrawing("Square")
        table.insert(segs, n)
    end
    while #segs > count do
        local s = table.remove(segs)
        if s and type(s.Remove) == "function" then pcall(function() s:Remove() end) end
    end
end

local function updateESPObject(eobj)
    local plr = eobj.Player
    local settings = eobj.Settings
    local char = plr and plr.Character
    if not plr or not char then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local root = getCharacterRoot(char)
    local head = char:FindFirstChild("Head")
    local humanoid = getHumanoid(char)
    if not root or not head then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local camPos = Camera and Camera.CFrame and Camera.CFrame.Position or Workspace.CurrentCamera.CFrame.Position
    local headPos = head.Position
    local rootPos = root.Position

    local headScreen, headZ, headOnScreen = safeWorldToViewport(headPos)
    local rootScreen, rootZ, rootOnScreen = safeWorldToViewport(rootPos)

    local dist = (camPos - rootPos).Magnitude
    if dist > (settings.MaxDistance or TSESP.Settings.MaxDistance) then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local visible = true
    if settings.VisibleCheck ~= false and TSESP.Settings.VisibleCheck then
        visible = raycastVisible(camPos, headPos, {char})
    end

    local color = settings.Color or TSESP.Settings.Color
    if settings.TeamColor and plr.Team and plr.TeamColor then
        color = plr.TeamColor.Color
    end

    local onScreen = headOnScreen and rootOnScreen
    if not onScreen or not visible then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local height = math.abs(headScreen.Y - rootScreen.Y)
    local width = math.max(10, height * 0.5)
    local boxPos = Vector2.new(rootScreen.X - width/2, rootScreen.Y - height/2)

    -- Box
    if eobj.Drawings.Box and (settings.Box or TSESP.Settings.Box) then
        local box = eobj.Drawings.Box
        box.Size = Vector2.new(width, height)
        box.Position = Vector2.new(rootScreen.X - width/2, rootScreen.Y - height/2)
        box.Thickness = settings.Thickness or TSESP.Settings.Thickness
        box.Color = color
        box.Filled = false
        box.Visible = true
    elseif eobj.Drawings.Box then eobj.Drawings.Box.Visible = false end

    -- Name
    if eobj.Drawings.Name and (settings.Name or TSESP.Settings.Name) then
        local txt = eobj.Drawings.Name
        local nameText = plr.Name
        if settings.Distance or TSESP.Settings.Distance then
            nameText = nameText .. " (" .. tostring(math.floor(dist)) .. "m)"
        end
        txt.Text = nameText
        txt.Size = 16
        txt.Font = (settings.Font or TSESP.Settings.Font)
        txt.Position = Vector2.new(headScreen.X, headScreen.Y - (height/2) - 18)
        txt.Color = color
        txt.Center = true
        txt.Outline = TSESP.Settings.Outline
        txt.Visible = true
    elseif eobj.Drawings.Name then eobj.Drawings.Name.Visible = false end

    -- Tracer
    if eobj.Drawings.Tracer and (settings.Tracer or TSESP.Settings.Tracer) then
        local tri = eobj.Drawings.Tracer
        local from = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        local tracerFrom = (settings.TracerFrom or TSESP.Settings.TracerFrom)
        if tracerFrom == "Top" then
            from = Vector2.new(Camera.ViewportSize.X/2, 0)
        elseif tracerFrom == "Center" then
            from = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        elseif tracerFrom == "Mouse" then
            local ok, mouse = pcall(function() return Players.LocalPlayer and Players.LocalPlayer:GetMouse() end)
            if ok and mouse then
                from = Vector2.new(mouse.X or 0, mouse.Y or 0)
            end
        end
        tri.From = from
        tri.To = headScreen
        tri.Color = color
        tri.Thickness = settings.Thickness or TSESP.Settings.Thickness
        tri.Visible = true
    elseif eobj.Drawings.Tracer then eobj.Drawings.Tracer.Visible = false end

    -- Healthbar
    if settings.Healthbar or TSESP.Settings.Healthbar then
        local hum = humanoid
        local maxHp = hum and hum.MaxHealth or 100
        local hp = hum and hum.Health or maxHp
        local pct = math.clamp(hp / maxHp, 0, 1)

        local barWidth = math.max(4, width * 0.08)
        local barHeight = height
        local backPos = Vector2.new(rootScreen.X - width/2 - barWidth - 4, rootScreen.Y - height/2)

        if settings.HealthbarGradient or TSESP.Settings.HealthbarGradient then
            -- hide simple front/back
            if eobj.Drawings.HealthBack then eobj.Drawings.HealthBack.Visible = false end
            if eobj.Drawings.HealthFront then eobj.Drawings.HealthFront.Visible = false end

            local segCount = settings.GradientSegments or TSESP.Settings.GradientSegments
            ensureSegments(eobj, segCount)
            local segs = eobj.Drawings.HealthSegments
            local speed = settings.GradientSpeed or TSESP.Settings.GradientSpeed
            local colors = settings.GradientColors or TSESP.Settings.GradientColors
            local t = tick() * (speed or 1)
            local offset = (math.sin(t * math.pi * 2) + 1) / 2 -- 0..1 oscillation

            for i=1,segCount do
                local s = segs[i]
                if not s then break end
                local segH = barHeight / segCount
                local posY = backPos.Y + (i-1) * segH
                local segVisible = true
                s.Size = Vector2.new(barWidth - 1, segH + 1)
                s.Position = Vector2.new(backPos.X + 1, posY)
                -- sample position along gradient, shifted by offset and wrapped
                local samplePos = ((i - 1) / (segCount - 1 + 0.0001)) + (offset * 1.0)
                samplePos = samplePos % 1
                local col = sampleGradient(colors, 1 - samplePos) -- invert so top->bottom looks natural
                s.Color = col
                -- fade segment based on health percentage (only show portion equal to hp)
                local healthTop = backPos.Y + (1 - pct) * barHeight
                if posY + segH < healthTop then
                    segVisible = false
                end
                s.Filled = true
                s.Visible = segVisible
            end
        else
            -- simple bar
            local back = eobj.Drawings.HealthBack
            local front = eobj.Drawings.HealthFront
            if back then
                back.Size = Vector2.new(barWidth, barHeight)
                back.Position = backPos
                back.Color = Color3.fromRGB(40,40,40)
                back.Filled = true
                back.Visible = true
            end
            if front then
                front.Size = Vector2.new(barWidth - 1, barHeight * pct)
                front.Position = Vector2.new(backPos.X + 1, backPos.Y + (barHeight * (1 - pct)))
                front.Color = Color3.new(1 - (1-pct), pct, 0)
                front.Filled = true
                front.Visible = true
            end
        end
    else
        if eobj.Drawings.HealthBack then eobj.Drawings.HealthBack.Visible = false end
        if eobj.Drawings.HealthFront then eobj.Drawings.HealthFront.Visible = false end
        if eobj.Drawings.HealthSegments then
            for _,s in pairs(eobj.Drawings.HealthSegments) do if s and s.Visible ~= nil then s.Visible = false end end
        end
    end
end

-- Public API
function TSESP:CreateESP(player, opts)
    if not player then return nil end
    local settings = {}
    for k,v in pairs(TSESP.Settings) do settings[k] = v end
    if type(opts) == "table" then for k,v in pairs(opts) do settings[k] = v end end

    local eobj = makeESPForPlayer(player, settings)
    TSESP._players[player] = eobj
    return eobj
end

function TSESP:RemoveESP(player)
    local e = TSESP._players[player]
    if e then e:Remove() end
    TSESP._players[player] = nil
end

function TSESP:GetESP(player)
    return TSESP._players[player]
end

function TSESP:SetGlobalOption(k,v)
    TSESP.Settings[k] = v
    for plr,e in pairs(TSESP._players) do e.Settings[k] = v end
end

function TSESP:SetPlayerOption(player,k,v)
    local e = TSESP._players[player]
    if e then e.Settings[k] = v end
end

-- Compatibility Add(opts) for loader-style libraries
-- Accepts options like in the user's snippet and maps them to TSESP objects.
function TSESP:Add(opts)
    if type(opts) ~= "table" then return nil end
    -- Determine player from Model or Player field
    local player = nil
    if opts.Player and typeof(opts.Player) == "Instance" and opts.Player:IsA("Player") then
        player = opts.Player
    elseif opts.Model and typeof(opts.Model) == "Instance" then
        player = Players:GetPlayerFromCharacter(opts.Model) or Players:FindFirstChild(opts.Model.Name)
    elseif opts.Name and type(opts.Name) == "string" then
        player = Players:FindFirstChild(opts.Name) or Players:GetPlayers()[opts.Name]
    end

    if not player then
        return nil
    end

    local e = TSESP._players[player] or TSESP:CreateESP(player)

    -- Basic mappings
    if opts.MaxDistance then e.Settings.MaxDistance = opts.MaxDistance end
    if opts.Color then e.Settings.Color = opts.Color end
    if opts.TextSize and e.Drawings.Name then e.Drawings.Name.Size = opts.TextSize end
    if opts.Name and e.Drawings.Name then e.Drawings.Name.Text = opts.Name end

    -- Box fill / outline
    if opts.FillColor and e.Drawings.Box then
        e.Drawings.Box.Filled = true
        e.Drawings.Box.Color = opts.FillColor
        if opts.FillTransparency ~= nil then e.Drawings.Box.Transparency = opts.FillTransparency end
    end
    if opts.OutlineColor and e.Drawings.Box then
        e.Drawings.Box.Thickness = e.Drawings.Box.Thickness or (e.Settings.Thickness or 1)
        -- best-effort: no separate outline drawing by default
        e.Drawings.Box.Color = opts.OutlineColor
        if opts.OutlineTransparency ~= nil then e.Drawings.Box.Transparency = opts.OutlineTransparency end
    end

    -- Tracer mapping
    if type(opts.Tracer) == "table" then
        e.Settings.Tracer = opts.Tracer.Enabled ~= false
        if e.Drawings.Tracer and opts.Tracer.Color then e.Drawings.Tracer.Color = opts.Tracer.Color end
        if opts.Tracer.From then
            e.Settings.TracerFrom = opts.Tracer.From
        end
    end

    -- Arrow: use an extra Line to approximate
    if type(opts.Arrow) == "table" and opts.Arrow.Enabled and e.Drawings.Tracer then
        if not e.Drawings.Arrow then
            e.Drawings.Arrow = createDrawing("Line")
        end
        e.Drawings.Arrow.Color = opts.Arrow.Color or e.Settings.Color
        e.Drawings.Arrow.Thickness = (opts.Arrow.Thickness or 1)
    end

    -- Return a handler compatible object
    local handler = {}
    function handler:Remove()
        TSESP:RemoveESP(player)
    end
    return handler
end

function TSESP:Toggle(val)
    TSESP.Settings.Enabled = val and true or false
end

function TSESP:Destroy()
    for p,e in pairs(TSESP._players) do pcall(function() e:Remove() end) end
    TSESP._players = {}
    if TSESP._conn then pcall(function() TSESP._conn:Disconnect() end) end
    TSESP._conn = nil
end

-- Update loop
TSESP._conn = RunService.RenderStepped:Connect(function()
    if not TSESP.Settings.Enabled then
        return
    end
    for p,e in pairs(TSESP._players) do
        pcall(function() updateESPObject(e) end)
    end
end)

-- Auto attach existing players (except local player)
for _,plr in pairs(Players:GetPlayers()) do
    if plr ~= Players.LocalPlayer then
        TSESP._players[plr] = makeESPForPlayer(plr, nil)
    end
end

Players.PlayerAdded:Connect(function(plr)
    if plr ~= Players.LocalPlayer then
        TSESP._players[plr] = makeESPForPlayer(plr, nil)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    local e = TSESP._players[plr]
    if e then e:Remove() end
    TSESP._players[plr] = nil
end)

return TSESP
-- TSESP - Lightweight ESP Library for executors (Luau)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera

local Drawing = Drawing

local TSESP = {}
TSESP.__index = TSESP

TSESP.Settings = {
    Enabled = true,
    Box = true,
    Name = true,
    Tracer = true,
    Healthbar = true,
    TeamColor = true,
    VisibleCheck = true,
    MaxDistance = 1000,
    Thickness = 1,
    Font = 2,
    Outline = true,
    Color = Color3.fromRGB(255,255,255),
    TracerFrom = "Bottom", -- "Bottom" | "Top" | "Center"
}

TSESP._players = {}

local function isDrawingAvailable()
    return type(Drawing) == "table" or type(Drawing) == "function"
end

local function safeWorldToViewport(pos)
    if not Camera or not Camera.WorldToViewportPoint then
        return Vector2.new(0,0), 0, false
    end
    local x,y,z = Camera:WorldToViewportPoint(pos)
    return Vector2.new(x,y), z, z > 0
end

local function createDrawing(kind)
    if not isDrawingAvailable() then return nil end
    local ok, obj = pcall(function() return Drawing.new(kind) end)
    if not ok then return nil end
    return obj
end

local function getCharacterRoot(character)
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function raycastVisible(from, to, ignoreList)
    if not Workspace.Raycast then return true end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignoreList or {}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local dir = to - from
    local result = Workspace:Raycast(from, dir, params)
    return result == nil
end

local function makeESPForPlayer(player, settings)
    local obj = {}
    obj.Player = player
    obj.Settings = settings or {}
    obj.Enabled = true
    obj.Drawings = {}

    if isDrawingAvailable() then
        obj.Drawings.Box = createDrawing("Square")
        obj.Drawings.Tracer = createDrawing("Line")
        obj.Drawings.Name = createDrawing("Text")
        obj.Drawings.HealthBack = createDrawing("Square")
        obj.Drawings.HealthFront = createDrawing("Square")
    end

    function obj:SetEnabled(val)
        self.Enabled = val and true or false
        for _,v in pairs(self.Drawings) do if v and v.Visible ~= nil then v.Visible = self.Enabled end end
    end

    function obj:SetOption(k,v)
        self.Settings[k] = v
    end

    function obj:Remove()
        for _,v in pairs(self.Drawings) do
            if v and type(v.Remove) == "function" then
                pcall(function() v:Remove() end)
            end
        end
        self.Drawings = {}
        self.Enabled = false
    end

    return obj
end

local function updateESPObject(eobj)
    local plr = eobj.Player
    local settings = eobj.Settings
    local char = plr and plr.Character
    if not plr or not char then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local root = getCharacterRoot(char)
    local head = char:FindFirstChild("Head")
    local humanoid = getHumanoid(char)
    if not root or not head then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local camPos = Camera and Camera.CFrame and Camera.CFrame.Position or Workspace.CurrentCamera.CFrame.Position
    local headPos = head.Position
    local rootPos = root.Position

    local headScreen, headZ, headOnScreen = safeWorldToViewport(headPos)
    local rootScreen, rootZ, rootOnScreen = safeWorldToViewport(rootPos)

    local dist = (camPos - rootPos).Magnitude
    if dist > (settings.MaxDistance or TSESP.Settings.MaxDistance) then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local visible = true
    if settings.VisibleCheck ~= false and TSESP.Settings.VisibleCheck then
        visible = raycastVisible(camPos, headPos, {char})
    end

    local color = settings.Color or TSESP.Settings.Color
    if settings.TeamColor and plr.Team and plr.TeamColor then
        color = plr.TeamColor.Color
    end

    local onScreen = headOnScreen and rootOnScreen
    if not onScreen or not visible then
        for _,v in pairs(eobj.Drawings) do if v and v.Visible ~= nil then v.Visible = false end end
        return
    end

    local height = math.abs(headScreen.Y - rootScreen.Y)
    local width = math.max(10, height * 0.5)
    local boxPos = Vector2.new(rootScreen.X - width/2, rootScreen.Y - height/2)

    -- Box
    if eobj.Drawings.Box and (settings.Box or TSESP.Settings.Box) then
        local box = eobj.Drawings.Box
        box.Size = Vector2.new(width, height)
        box.Position = Vector2.new(rootScreen.X - width/2, rootScreen.Y - height/2)
        box.Thickness = settings.Thickness or TSESP.Settings.Thickness
        box.Color = color
        box.Filled = false
        box.Visible = true
    elseif eobj.Drawings.Box then eobj.Drawings.Box.Visible = false end

    -- Name
    if eobj.Drawings.Name and (settings.Name or TSESP.Settings.Name) then
        local txt = eobj.Drawings.Name
        local nameText = plr.Name
        if settings.Distance or TSESP.Settings.Distance then
            nameText = nameText .. " (" .. tostring(math.floor(dist)) .. "m)"
        end
        txt.Text = nameText
        txt.Size = 16
        txt.Font = (settings.Font or TSESP.Settings.Font)
        txt.Position = Vector2.new(headScreen.X, headScreen.Y - (height/2) - 18)
        txt.Color = color
        txt.Center = true
        txt.Outline = TSESP.Settings.Outline
        txt.Visible = true
    elseif eobj.Drawings.Name then eobj.Drawings.Name.Visible = false end

    -- Tracer
    if eobj.Drawings.Tracer and (settings.Tracer or TSESP.Settings.Tracer) then
        local tri = eobj.Drawings.Tracer
        local from = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        if (settings.TracerFrom or TSESP.Settings.TracerFrom) == "Top" then
            from = Vector2.new(Camera.ViewportSize.X/2, 0)
        elseif (settings.TracerFrom or TSESP.Settings.TracerFrom) == "Center" then
            from = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        end
        tri.From = from
        tri.To = headScreen
        tri.Color = color
        tri.Thickness = settings.Thickness or TSESP.Settings.Thickness
        tri.Visible = true
    elseif eobj.Drawings.Tracer then eobj.Drawings.Tracer.Visible = false end

    -- Healthbar (simple vertical bar at left of box)
    if eobj.Drawings.HealthBack and eobj.Drawings.HealthFront and (settings.Healthbar or TSESP.Settings.Healthbar) then
        local back = eobj.Drawings.HealthBack
        local front = eobj.Drawings.HealthFront
        local hum = humanoid
        local maxHp = hum and hum.MaxHealth or 100
        local hp = hum and hum.Health or maxHp
        local pct = math.clamp(hp / maxHp, 0, 1)

        local barWidth = math.max(4, width * 0.08)
        local barHeight = height
        back.Size = Vector2.new(barWidth, barHeight)
        back.Position = Vector2.new(rootScreen.X - width/2 - barWidth - 4, rootScreen.Y - height/2)
        back.Color = Color3.fromRGB(40,40,40)
        back.Filled = true
        back.Visible = true

        front.Size = Vector2.new(barWidth - 1, barHeight * pct)
        front.Position = Vector2.new(back.Position.X + 1, back.Position.Y + (barHeight * (1 - pct)))
        front.Color = Color3.new(1 - (1-pct), pct, 0)
        front.Filled = true
        front.Visible = true
    elseif eobj.Drawings.HealthBack then eobj.Drawings.HealthBack.Visible = false; eobj.Drawings.HealthFront.Visible = false end
end

-- Public API
function TSESP:CreateESP(player, opts)
    if not player then return nil end
    local settings = {}
    for k,v in pairs(TSESP.Settings) do settings[k] = v end
    if type(opts) == "table" then for k,v in pairs(opts) do settings[k] = v end end

    local eobj = makeESPForPlayer(player, settings)
    TSESP._players[player] = eobj
    return eobj
end

function TSESP:RemoveESP(player)
    local e = TSESP._players[player]
    if e then e:Remove() end
    TSESP._players[player] = nil
end

function TSESP:GetESP(player)
    return TSESP._players[player]
end

function TSESP:SetGlobalOption(k,v)
    TSESP.Settings[k] = v
    for plr,e in pairs(TSESP._players) do e.Settings[k] = v end
end

function TSESP:SetPlayerOption(player,k,v)
    local e = TSESP._players[player]
    if e then e.Settings[k] = v end
end

function TSESP:Toggle(val)
    TSESP.Settings.Enabled = val and true or false
end

function TSESP:Destroy()
    for p,e in pairs(TSESP._players) do pcall(function() e:Remove() end) end
    TSESP._players = {}
    if TSESP._conn then pcall(function() TSESP._conn:Disconnect() end) end
    TSESP._conn = nil
end

-- Update loop
TSESP._conn = RunService.RenderStepped:Connect(function()
    if not TSESP.Settings.Enabled then
        return
    end
    for p,e in pairs(TSESP._players) do
        pcall(function() updateESPObject(e) end)
    end
end)

-- Auto attach existing players (except local player)
for _,plr in pairs(Players:GetPlayers()) do
    if plr ~= Players.LocalPlayer then
        TSESP._players[plr] = makeESPForPlayer(plr, nil)
    end
end

Players.PlayerAdded:Connect(function(plr)
    if plr ~= Players.LocalPlayer then
        TSESP._players[plr] = makeESPForPlayer(plr, nil)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    local e = TSESP._players[plr]
    if e then e:Remove() end
    TSESP._players[plr] = nil
end)

return TSESP
