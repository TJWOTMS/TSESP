-- TSESP.luau
-- A LuaU Roblox ESP Library

local TSESP = {}
TSESP.__index = TSESP

function TSESP.new()
    local self = setmetatable({}, TSESP)
    self.activeESPs = {}
    self.rainbowEnabled = false
    self.rainbowSpeed = 1
    return self
end

function TSESP:AddESP(target, options)
    if self.activeESPs[target] then return end
    local espData = {
        target = target,
        options = options or {},
        drawings = {},
        highlight = nil,
    }
    self:CreateDrawings(espData)
    self.activeESPs[target] = espData
end

function TSESP:CreateDrawings(espData)
    local options = espData.options
    if options.ShowBox then
        if options.BoxType == "Full" then
            local box = Drawing.new("Square")
            box.Thickness = 1
            box.Filled = false
            box.Color = options.Color or Color3.new(1, 1, 1)
            espData.drawings.box = box
        elseif options.BoxType == "Corner" then
            local lines = {}
            for i = 1, 8 do
                lines[i] = Drawing.new("Line")
                lines[i].Thickness = 1
                lines[i].Color = options.Color or Color3.new(1, 1, 1)
            end
            espData.drawings.box = lines
        end
    end
    if options.ShowTracer then
        local tracer = Drawing.new("Line")
        tracer.Thickness = 1
        tracer.Color = options.Color or Color3.new(1, 1, 1)
        espData.drawings.tracer = tracer
    end
    if options.ShowText then
        if options.ShowName then
            local nameText = Drawing.new("Text")
            nameText.Size = 14
            nameText.Color = options.Color or Color3.new(1, 1, 1)
            nameText.Outline = true
            nameText.Font = options.Font or Drawing.Fonts.UI
            espData.drawings.name = nameText
        end
        if options.ShowDistance then
            local distText = Drawing.new("Text")
            distText.Size = 12
            distText.Color = options.Color or Color3.new(1, 1, 1)
            distText.Outline = true
            distText.Font = options.Font or Drawing.Fonts.UI
            espData.drawings.distance = distText
        end
        if options.ShowHealth then
            local healthText = Drawing.new("Text")
            healthText.Size = 12
            healthText.Color = options.Color or Color3.new(1, 1, 1)
            healthText.Outline = true
            healthText.Font = options.Font or Drawing.Fonts.UI
            espData.drawings.health = healthText
        end
    end
    if options.Healthbar then
        local healthbarBg = Drawing.new("Square")
        healthbarBg.Filled = true
        healthbarBg.Color = Color3.new(0, 0, 0)
        healthbarBg.Transparency = 0.5
        local healthbarFill = Drawing.new("Square")
        healthbarFill.Filled = true
        healthbarFill.Color = Color3.new(0, 1, 0)
        espData.drawings.healthbarBg = healthbarBg
        espData.drawings.healthbarFill = healthbarFill
    end
    if options.ShowChams then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = espData.target
        highlight.FillColor = options.ChamsColor or Color3.new(1, 1, 1)
        highlight.FillTransparency = options.ChamsFillTransparency or 0.5
        highlight.OutlineColor = options.ChamsOutlineColor or Color3.new(0, 0, 0)
        highlight.OutlineTransparency = options.ChamsOutlineTransparency or 0
        highlight.Parent = workspace
        espData.highlight = highlight
    end
end

function TSESP:Update()
    for target, espData in pairs(self.activeESPs) do
        if not target or not target:IsDescendantOf(workspace) then
            self:RemoveESP(target)
        else
            self:UpdateESP(espData)
        end
    end
end

function TSESP:UpdateESP(espData)
    local target = espData.target
    local options = espData.options
    local camera = workspace.CurrentCamera
    local rootPart = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("RootPart")
    if not rootPart then return end
    local pos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then
        self:HideDrawings(espData)
        return
    end
    local distance = (camera.CFrame.Position - rootPart.Position).Magnitude
    if options.MaxDistance and distance > options.MaxDistance then
        self:HideDrawings(espData)
        return
    end
    self:ShowDrawings(espData)
    -- Get bounding box
    local size = target:GetExtentsSize()
    local topLeft = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(-size.X / 2, size.Y / 2, 0))
    local bottomRight = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(size.X / 2, -size.Y / 2, 0))
    local width = bottomRight.X - topLeft.X
    local height = bottomRight.Y - topLeft.Y
    -- Box
    if options.ShowBox then
        if options.BoxType == "Full" then
            local box = espData.drawings.box
            box.Position = Vector2.new(topLeft.X, topLeft.Y)
            box.Size = Vector2.new(width, height)
            box.Color = self:GetColor(options.Color, options.Rainbow)
        elseif options.BoxType == "Corner" then
            local lines = espData.drawings.box
            local cornerSize = math.min(width, height) * 0.2
            -- Top left
            lines[1].From = Vector2.new(topLeft.X, topLeft.Y)
            lines[1].To = Vector2.new(topLeft.X + cornerSize, topLeft.Y)
            lines[2].From = Vector2.new(topLeft.X, topLeft.Y)
            lines[2].To = Vector2.new(topLeft.X, topLeft.Y + cornerSize)
            -- Top right
            lines[3].From = Vector2.new(bottomRight.X, topLeft.Y)
            lines[3].To = Vector2.new(bottomRight.X - cornerSize, topLeft.Y)
            lines[4].From = Vector2.new(bottomRight.X, topLeft.Y)
            lines[4].To = Vector2.new(bottomRight.X, topLeft.Y + cornerSize)
            -- Bottom left
            lines[5].From = Vector2.new(topLeft.X, bottomRight.Y)
            lines[5].To = Vector2.new(topLeft.X + cornerSize, bottomRight.Y)
            lines[6].From = Vector2.new(topLeft.X, bottomRight.Y)
            lines[6].To = Vector2.new(topLeft.X, bottomRight.Y - cornerSize)
            -- Bottom right
            lines[7].From = Vector2.new(bottomRight.X, bottomRight.Y)
            lines[7].To = Vector2.new(bottomRight.X - cornerSize, bottomRight.Y)
            lines[8].From = Vector2.new(bottomRight.X, bottomRight.Y)
            lines[8].To = Vector2.new(bottomRight.X, bottomRight.Y - cornerSize)
            for _, line in ipairs(lines) do
                line.Color = self:GetColor(options.Color, options.Rainbow)
            end
        end
    end
    -- Tracer
    if options.ShowTracer then
        local tracer = espData.drawings.tracer
        local fromPos
        if options.TracerFrom == "Bottom" then
            fromPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
        elseif options.TracerFrom == "Top" then
            fromPos = Vector2.new(camera.ViewportSize.X / 2, 0)
        elseif options.TracerFrom == "Center" then
            fromPos = camera.ViewportSize / 2
        elseif options.TracerFrom == "Mouse" then
            fromPos = Vector2.new(game.Players.LocalPlayer:GetMouse().X, game.Players.LocalPlayer:GetMouse().Y)
        end
        tracer.From = fromPos
        tracer.To = Vector2.new(pos.X, pos.Y)
        tracer.Color = self:GetColor(options.Color, options.Rainbow)
    end
    -- Text
    if options.ShowText then
        if options.ShowName then
            local nameText = espData.drawings.name
            nameText.Text = target.Name
            nameText.Position = Vector2.new(pos.X, topLeft.Y - 20)
            nameText.Color = self:GetColor(options.Color, options.Rainbow)
        end
        if options.ShowDistance then
            local distText = espData.drawings.distance
            distText.Text = string.format("[%d]", math.floor(distance))
            distText.Position = Vector2.new(pos.X, bottomRight.Y + 5)
            distText.Color = self:GetColor(options.Color, options.Rainbow)
        end
        if options.ShowHealth then
            local humanoid = target:FindFirstChild("Humanoid")
            if humanoid then
                local healthText = espData.drawings.health
                healthText.Text = string.format("HP: %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
                if options.Healthbar then
                    local bg = espData.drawings.healthbarBg
                    healthText.Position = Vector2.new(bg.Position.X + bg.Size.X + 5, bg.Position.Y + bg.Size.Y / 2)
                else
                    healthText.Position = Vector2.new(bottomRight.X + 5, pos.Y)
                end
                healthText.Color = self:GetColor(options.Color, options.Rainbow)
            end
        end
    end
    -- Healthbar
    if options.Healthbar then
        local humanoid = target:FindFirstChild("Humanoid")
        if humanoid then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local bg = espData.drawings.healthbarBg
            bg.Position = Vector2.new(topLeft.X - 10, topLeft.Y)
            bg.Size = Vector2.new(5, height)
            local fill = espData.drawings.healthbarFill
            if options.ShrinkHealthbar then
                fill.Position = Vector2.new(topLeft.X - 10, topLeft.Y + height * (1 - healthPercent))
                fill.Size = Vector2.new(5, height * healthPercent)
            else
                fill.Position = Vector2.new(topLeft.X - 10, topLeft.Y)
                fill.Size = Vector2.new(5, height * healthPercent)
            end
            if options.HealthbarGradient then
                fill.Color = self:GetGradientColor(healthPercent, options.GradientColors or {Color3.new(1, 0, 0), Color3.new(1, 0.65, 0), Color3.new(1, 1, 0), Color3.new(0, 1, 0)}, options.GradientSpeed or 0.6)
            else
                fill.Color = self:GetColor(options.HealthbarColor or Color3.new(0, 1, 0), options.Rainbow)
            end
        end
    end
    -- Chams
    if options.ShowChams then
        local highlight = espData.highlight
        highlight.FillColor = self:GetColor(options.ChamsColor, options.Rainbow)
        highlight.FillTransparency = options.ChamsFillTransparency or 0.5
    end
end

function TSESP:GetColor(baseColor, rainbow)
    if rainbow and self.rainbowEnabled then
        local time = tick() * self.rainbowSpeed
        return Color3.fromHSV(time % 1, 1, 1)
    else
        return baseColor or Color3.new(1, 1, 1)
    end
end

function TSESP:GetGradientColor(percent, colors, speed)
    local time = tick() * (speed or 1)
    local shiftedPercent = (percent + time * 0.1) % 1  -- Slow cycling
    local index = math.floor(shiftedPercent * (#colors - 1)) + 1
    local nextIndex = index % #colors + 1
    local lerp = (shiftedPercent * (#colors - 1)) % 1
    return colors[index]:Lerp(colors[nextIndex], lerp)
end

function TSESP:HideDrawings(espData)
    for _, drawing in pairs(espData.drawings) do
        if typeof(drawing) == "table" then
            for _, d in pairs(drawing) do
                d.Visible = false
            end
        else
            drawing.Visible = false
        end
    end
    if espData.highlight then
        espData.highlight.Enabled = false
    end
end

function TSESP:ShowDrawings(espData)
    for _, drawing in pairs(espData.drawings) do
        if typeof(drawing) == "table" then
            for _, d in pairs(drawing) do
                d.Visible = true
            end
        else
            drawing.Visible = true
        end
    end
    if espData.highlight then
        espData.highlight.Enabled = true
    end
end

function TSESP:RemoveESP(target)
    local espData = self.activeESPs[target]
    if not espData then return end
    self:HideDrawings(espData)
    for _, drawing in pairs(espData.drawings) do
        if typeof(drawing) == "table" then
            for _, d in pairs(drawing) do
                d:Remove()
            end
        else
            drawing:Remove()
        end
    end
    if espData.highlight then
        espData.highlight:Destroy()
    end
    self.activeESPs[target] = nil
end

function TSESP:UpdateOptions(target, options)
    local espData = self.activeESPs[target]
    if not espData then return end
    for k, v in pairs(options) do
        espData.options[k] = v
    end
    -- Recreate drawings if necessary
    self:RemoveESP(target)
    self:AddESP(target, espData.options)
end

function TSESP:AutoAdd(options)
    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= game.Players.LocalPlayer then
            if player.Character then
                self:AddESP(player.Character, options)
            end
            player.CharacterAdded:Connect(function(char)
                self:AddESP(char, options)
            end)
        end
    end
    game.Players.PlayerAdded:Connect(function(player)
        if player ~= game.Players.LocalPlayer then
            player.CharacterAdded:Connect(function(char)
                self:AddESP(char, options)
            end)
        end
    end)
end

function TSESP:ToggleRainbow(enabled)
    self.rainbowEnabled = enabled
end

local defaultESP = TSESP.new()
return defaultESP
