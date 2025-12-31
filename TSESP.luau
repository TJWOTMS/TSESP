--[[
 _________  ________  ___  ________   ________  ________  ___       ________  ___  _________
|\___   ___\\   __  \|\  \|\   ____\ |\   ____\|\   __  \|\  \     |\   __  \|\  \|\___   ___\
\|___ \  \_\ \  \|\  \ \  \ \  \___|_\ \  \___|\ \  \|\  \ \  \    \ \  \|\  \ \  \|___ \  \_|
     \ \  \ \ \   _  _\ \  \ \_____  \\ \_____  \ \   ____\ \  \    \ \  \\\  \ \  \   \ \  \
      \ \  \ \ \  \\  \\ \  \|____|\  \\|____|\  \ \  \___|\ \  \____\ \  \\\  \ \  \   \ \  \
       \ \__\ \ \__\\ _\\ \__\____\_\  \ ____\_\  \ \__\    \ \_______\ \_______\ \__\   \ \__\
        \|__|  \|__|\|__|\|__|\_________\\_________\|__|     \|_______|\|_______|\|__|    \|__|
                             \|_________\|_________|




                       _______   ________  ________        ___       ___  ________  ________  ________  ________      ___    ___
                      |\  ___ \ |\   ____\|\   __  \      |\  \     |\  \|\   __  \|\   __  \|\   __  \|\   __  \    |\  \  /  /|
                      \ \   __/|\ \  \___|\ \  \|\  \     \ \  \    \ \  \ \  \|\ /\ \  \|\  \ \  \|\  \ \  \|\  \   \ \  \/  / /
                       \ \  \_|/_\ \_____  \ \   ____\     \ \  \    \ \  \ \   __  \ \   _  _\ \   __  \ \   _  _\   \ \    / /
                        \ \  \_|\ \|____|\  \ \  \___|      \ \  \____\ \  \ \  \|\  \ \  \\  \\ \  \ \  \ \  \\  \|   \/  /  /
                         \ \_______\____\_\  \ \__\          \ \_______\ \__\ \_______\ \__\\ _\\ \__\ \__\ \__\\ _\ __/  / /
                          \|_______|\_________\|__|           \|_______|\|_______|\|_______|\|__|\|__|\|__|\|__|\|___| /
                                   \|_________|                                                                     \|___|/

]]

-- TrisSploit's ESP Library v1.0.0

local ESP = {}
local activeESPs = {}
local isVisible = true
local renderConnection = nil
local autoAddOptions = nil
local playerAddedConnection = nil
local playerRemovingConnection = nil

ESP.activeESPs = activeESPs  -- Expose for external access

-- Check if Drawing is available
if not Drawing then
    warn("Drawing API not available. ESP will not work.")
    return ESP
end

-- Function to get screen position and size for a model
local function getBoundingBox(model: Model)
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local parts = {}
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(parts, part)
        end
    end

    if #parts == 0 then return nil end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, part in ipairs(parts) do
        local cf = part.CFrame
        local size = part.Size
        local corners = {
            cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
            cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
            cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
            cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
            cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
            cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
            cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
            cf * CFrame.new(size.X/2, size.Y/2, size.Z/2),
        }

        for _, corner in ipairs(corners) do
            local pos = camera:WorldToViewportPoint(corner.Position)
            minX = math.min(minX, pos.X)
            minY = math.min(minY, pos.Y)
            maxX = math.max(maxX, pos.X)
            maxY = math.max(maxY, pos.Y)
        end
    end

    if minX == math.huge then return nil end

    return {
        Position = Vector2.new((minX + maxX)/2, (maxY + minY)/2),
        Size = Vector2.new(maxX - minX, maxY - minY)
    }
end

-- Function to calculate distance
local function getDistance(pos: Vector3)
    local camera = workspace.CurrentCamera
    if not camera then return 0 end
    return (camera.CFrame.Position - pos).Magnitude
end

-- Add ESP to a target
function ESP:Add(target: Instance, options: table?)
    if not target or activeESPs[target] then return end

    -- Prevent adding ESP to local player
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    if localPlayer and (target == localPlayer.Character or (localPlayer.Character and target:IsDescendantOf(localPlayer.Character))) then return end

    options = options or {}
    local color = options.Color or Color3.new(1, 1, 1)
    local showBox = options.ShowBox
    local boxType = options.BoxType or "Full"
    local boxThickness = options.BoxThickness or 1
    local cornerThickness = options.CornerThickness or 2
    local cornerOutlineThickness = options.CornerOutlineThickness or 4
    local nameOffsetY = options.NameOffsetY or -20
    local bottomOffsetY = options.BottomOffsetY or 15
    local healthTextOffsetX = options.HealthTextOffsetX or -50
    local healthTextOffsetY = options.HealthTextOffsetY or 0
    local healthbarWidth = options.HealthbarWidth or 6
    local showText = options.ShowText
    local showName = options.ShowName
    local showHealth = options.ShowHealth
    local showDistance = options.ShowDistance
    local showTracer = options.ShowTracer
    local tracerFrom = options.TracerFrom or "Bottom"
    local showChams = options.ShowChams
    local chamsColor = options.ChamsColor or color
    local maxDistance = options.MaxDistance
    local showHealthbar = options.Healthbar
    local healthbarGradient = options.HealthbarGradient
    local shrinkHealthbar = options.ShrinkHealthbar or false
    local gradientColors = options.GradientColors or {Color3.new(1,0,0), Color3.new(0,1,0)}
    local gradientSpeed = options.GradientSpeed or 1
    local font = options.Font or "Gotham"
    local textSize = options.TextSize or 14

    local espData = {
        Target = target,
        Drawings = {},
        Options = options
    }

    local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")

    if showBox then
        if boxType == "Full" then
            -- outline behind the box
            local boxOutline = Drawing.new("Square")
            boxOutline.Color = Color3.new(0,0,0)
            boxOutline.Thickness = options.BoxOutlineThickness or 1
            boxOutline.Filled = false
            boxOutline.Visible = isVisible
            espData.Drawings.BoxOutline = boxOutline

            local box = Drawing.new("Square")
            box.Color = color
            box.Thickness = boxThickness
            box.Filled = false
            box.Visible = isVisible
            espData.Drawings.Box = box
        elseif boxType == "Corner" then
            local outlineLines = {}
            for i = 1, 8 do
                local ol = Drawing.new("Line")
                ol.Color = Color3.new(0,0,0)
                ol.Thickness = cornerOutlineThickness
                ol.Visible = isVisible
                table.insert(outlineLines, ol)
            end
            local lines = {}
            for i = 1, 8 do
                local line = Drawing.new("Line")
                line.Color = color
                line.Thickness = cornerThickness
                line.Visible = isVisible
                table.insert(lines, line)
            end
            espData.Drawings.CornerOutlines = outlineLines
            espData.Drawings.CornerLines = lines
        end
    end

    if showTracer then
        local tracer = Drawing.new("Line")
        tracer.Color = color
        tracer.Thickness = 1
        tracer.Visible = isVisible
        espData.Drawings.Tracer = tracer
    end

    if showChams then
        local highlight = Instance.new("Highlight")
        highlight.FillColor = chamsColor
        highlight.OutlineColor = chamsColor
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Enabled = isVisible
        if model then highlight.Parent = model end
        espData.Highlight = highlight
    end

    -- Use BillboardGui for text instead of Drawing for better scaling and positioning
    if showText or showName or showHealth or showDistance then
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Size = UDim2.new(0, 200, 0, 100)
        billboardGui.AlwaysOnTop = true
        billboardGui.Enabled = isVisible
        billboardGui.Adornee = model
        billboardGui.StudsOffset = Vector3.new(0, 0, 0)
        espData.BillboardGui = billboardGui

        local texts = {}
        local yOffset = 0
        if showName then
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0, 20)
            nameLabel.Position = UDim2.new(0, 0, 0, yOffset)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = color
            nameLabel.TextSize = textSize
            nameLabel.Font = Enum.Font[font] or Enum.Font.Gotham
            nameLabel.TextStrokeTransparency = 0
            nameLabel.Parent = billboardGui
            texts.name = nameLabel
            yOffset = yOffset + 20
        end
        if showHealth then
            local healthLabel = Instance.new("TextLabel")
            healthLabel.Size = UDim2.new(1, 0, 0, 20)
            healthLabel.Position = UDim2.new(0, 0, 0, yOffset)
            healthLabel.BackgroundTransparency = 1
            healthLabel.TextColor3 = color
            healthLabel.TextSize = textSize
            healthLabel.Font = Enum.Font[font] or Enum.Font.Gotham
            healthLabel.TextStrokeTransparency = 0
            healthLabel.Parent = billboardGui
            texts.health = healthLabel
            yOffset = yOffset + 20
        end
        if showDistance then
            local distanceLabel = Instance.new("TextLabel")
            distanceLabel.Size = UDim2.new(1, 0, 0, 20)
            distanceLabel.Position = UDim2.new(0, 0, 0, yOffset)
            distanceLabel.BackgroundTransparency = 1
            distanceLabel.TextColor3 = color
            distanceLabel.TextSize = textSize
            distanceLabel.Font = Enum.Font[font] or Enum.Font.Gotham
            distanceLabel.TextStrokeTransparency = 0
            distanceLabel.Parent = billboardGui
            texts.distance = distanceLabel
        end
        espData.Texts = texts
    end

    if showHealthbar then
        local segments = {}
        local numSegments = options.HealthbarSegments or 200  -- more segments for smooth gradient (default 200)
        for i = 1, numSegments do
            local fill = Drawing.new("Square")
            fill.Filled = true
            fill.Visible = isVisible
            table.insert(segments, fill)
        end
        espData.Drawings.HealthFillSegments = segments

        -- Add outline (keep thicker default so gradient doesn't overlap)
        local outline = Drawing.new("Square")
        outline.Color = Color3.new(0,0,0)
        outline.Thickness = options.HealthbarOutlineThickness or 1
        outline.Filled = false
        outline.Visible = isVisible
        espData.Drawings.HealthbarOutline = outline
    end

    activeESPs[target] = espData

    -- Start render loop if not already
    if not renderConnection then
        local RunService = game:GetService("RunService")
        renderConnection = RunService.RenderStepped:Connect(function()
            for _, data in pairs(activeESPs) do
                pcall(function() ESP:UpdateESP(data) end)
            end
        end)
    end
end

-- Update a single ESP
function ESP:UpdateESP(data)
    local target = data.Target
    if not target or not target:IsDescendantOf(workspace) then
        ESP:Remove(target)
        return
    end

    local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
    if not model then
        -- Hide drawings if no model
        for _, drawing in pairs(data.Drawings) do
            if type(drawing) == "table" then
                for _, d in pairs(drawing) do
                    d.Visible = false
                end
            else
                drawing.Visible = false
            end
        end
        if data.Highlight then data.Highlight.Enabled = false end
        if data.BillboardGui then data.BillboardGui.Enabled = false end
        return
    end

    -- Reparent highlight if necessary
    if data.Highlight then
        if data.Highlight.Parent ~= model then
            data.Highlight.Parent = model
        end
    end

    local camera = workspace.CurrentCamera
    if not camera then return end

    local pivot = model:GetPivot()
    local screenPos3, onScreen = camera:WorldToViewportPoint(pivot.Position)
    local screenPos = Vector2.new(screenPos3.X, screenPos3.Y)
    local dist = getDistance(pivot.Position)
    local options = data.Options

    -- Rainbow support: compute a currentColor to use for all components when enabled
    local rainbowEnabled = options.Rainbow
    local rainbowSpeed = options.RainbowSpeed or 1
    local currentColor = options.Color or Color3.new(1,1,1)
    if rainbowEnabled then
        local h = (tick() * rainbowSpeed) % 1
        currentColor = Color3.fromHSV(h, 1, 1)
    end

    if options.MaxDistance and dist > options.MaxDistance then
        -- hide all
        for _, drawing in pairs(data.Drawings) do
            if type(drawing) == "table" then
                for _, d in pairs(drawing) do
                    d.Visible = false
                end
            else
                drawing.Visible = false
            end
        end
        if data.Highlight then data.Highlight.Enabled = false end
        if data.BillboardGui then data.BillboardGui.Enabled = false end
        return
    end

    local bbox = nil
    if onScreen then
        bbox = getBoundingBox(model)
    end

    -- Update chams
    if data.Highlight then
        data.Highlight.Enabled = isVisible
        -- set chams colors when available (respect rainbow)
        if options.Rainbow then
            data.Highlight.FillColor = currentColor
            data.Highlight.OutlineColor = currentColor
        else
            data.Highlight.FillColor = options.ChamsColor or options.Color or data.Highlight.FillColor
            data.Highlight.OutlineColor = options.ChamsColor or options.Color or data.Highlight.OutlineColor
        end
    end

    -- Update offscreen arrow
    if data.Drawings.Arrow then
        if not onScreen then
            -- calculate accurate edge pos
            local viewportSize = camera.ViewportSize
            local center = viewportSize / 2
            local dir = (screenPos - center).Unit
            -- Find intersection with viewport edges
            local tMin = math.huge
            if dir.X > 0 then
                local t = (viewportSize.X - center.X) / dir.X
                if t > 0 then tMin = math.min(tMin, t) end
            elseif dir.X < 0 then
                local t = (0 - center.X) / dir.X
                if t > 0 then tMin = math.min(tMin, t) end
            end
            if dir.Y > 0 then
                local t = (viewportSize.Y - center.Y) / dir.Y
                if t > 0 then tMin = math.min(tMin, t) end
            elseif dir.Y < 0 then
                local t = (0 - center.Y) / dir.Y
                if t > 0 then tMin = math.min(tMin, t) end
            end
            local margin = 20  -- pixels inside the edge
            local edgePos = center + dir * math.max(0, tMin - margin)
            -- set triangle points for arrow pointing towards target
            local angle = math.atan2(dir.Y, dir.X)
            local size = 25
            local p1 = edgePos - dir * size  -- tip towards center
            local p2 = edgePos + Vector2.new(math.cos(angle + math.pi/2), math.sin(angle + math.pi/2)) * size / 2
            local p3 = edgePos + Vector2.new(math.cos(angle - math.pi/2), math.sin(angle - math.pi/2)) * size / 2
            data.Drawings.Arrow.PointA = p1
            data.Drawings.Arrow.PointB = p2
            data.Drawings.Arrow.PointC = p3
            data.Drawings.Arrow.Visible = isVisible
        else
            data.Drawings.Arrow.Visible = false
        end
    end

    if not bbox then
        -- hide box, 3dbox, tracer, text, healthbar
        if data.Drawings.Box then data.Drawings.Box.Visible = false end
        if data.Drawings.BoxOutline then data.Drawings.BoxOutline.Visible = false end
        if data.Drawings.CornerLines then for _, l in pairs(data.Drawings.CornerLines) do l.Visible = false end end
        if data.Drawings.CornerOutlines then for _, l in pairs(data.Drawings.CornerOutlines) do l.Visible = false end end
        if data.Drawings.Tracer then data.Drawings.Tracer.Visible = false end
        if data.Texts then for _, txt in pairs(data.Texts) do txt.Visible = false end end
        if data.Drawings.HealthbarOutline then data.Drawings.HealthbarOutline.Visible = false end
        if data.Drawings.HealthFillSegments then for _, d in pairs(data.Drawings.HealthFillSegments) do d.Visible = false end end
        return
    end

    -- Compute a screen-space scale factor so visuals stay proportional
    local avgSize = (bbox.Size.X + bbox.Size.Y) / 2
    local baseline = options.ScaleBaseline or 100
    local scale = math.clamp(avgSize / baseline, options.MinScale or 0.6, options.MaxScale or 1.6)

    -- Update box
    if data.Drawings.Box then
        data.Drawings.Box.Position = bbox.Position - bbox.Size / 2
        data.Drawings.Box.Size = bbox.Size
        local boxTh = (options.BoxThickness or 1) * scale
        data.Drawings.Box.Thickness = math.clamp(boxTh, 1, options.MaxBoxThickness or 6)
        data.Drawings.Box.Color = currentColor
        data.Drawings.Box.Visible = isVisible
    end

    -- ensure full-box outline exists when using full boxes (handles runtime BoxType changes)
    if options.ShowBox and options.BoxType == "Full" then
        local createdOutlineNow = false
        if not data.Drawings.BoxOutline then
            local boxOutline = Drawing.new("Square")
            boxOutline.Color = Color3.new(0,0,0)
            boxOutline.Thickness = options.BoxOutlineThickness or 1
            boxOutline.Filled = false
            boxOutline.Visible = isVisible
            data.Drawings.BoxOutline = boxOutline
            createdOutlineNow = true
        end
        -- only recreate or create the box if the outline was just created or box is missing
        if createdOutlineNow or not data.Drawings.Box then
            local old = data.Drawings.Box
            local c = (old and old.Color) or (options.Color or Color3.new(1,1,1))
            local t = (old and old.Thickness) or (options.BoxThickness or 1)
            local f = (old and old.Filled) or false
            local vis = (old and old.Visible) or isVisible
            if old then old:Remove() end
            local newBox = Drawing.new("Square")
            newBox.Color = c
            newBox.Thickness = t
            newBox.Filled = f
            newBox.Visible = vis
            data.Drawings.Box = newBox
        end
    end

    -- Update box outline (full box outline should be behind main box)
    if data.Drawings.BoxOutline then
        local outline = data.Drawings.BoxOutline
        local outlineTh = math.clamp((options.BoxOutlineThickness or 1) * scale, 1, options.MaxBoxOutlineThickness or 6)
        -- make outline slightly larger than box so it frames it
        local outlineSize = bbox.Size + Vector2.new(outlineTh * 2, outlineTh * 2)
        outline.Size = outlineSize
        outline.Position = bbox.Position - outlineSize / 2
        outline.Color = Color3.new(0,0,0)
        outline.Thickness = outlineTh
        outline.Visible = isVisible
    end

    if data.Drawings.CornerLines then
        local lines = data.Drawings.CornerLines
        -- support outlines for corner boxes (draw outlines behind colored lines)
        local outlineLines = data.Drawings.CornerOutlines
        if outlineLines then
            local pos = bbox.Position - bbox.Size / 2
                local size = bbox.Size
                local cornerSize = math.min(size.X, size.Y) / 4
                local outlineThickness = math.clamp((options.CornerOutlineThickness or 4) * scale, 1, options.MaxCornerOutlineThickness or 8)
            -- top left
            outlineLines[1].From = pos
            outlineLines[1].To = pos + Vector2.new(cornerSize, 0)
            outlineLines[2].From = pos
            outlineLines[2].To = pos + Vector2.new(0, cornerSize)
            -- top right
            outlineLines[3].From = pos + Vector2.new(size.X, 0)
            outlineLines[3].To = pos + Vector2.new(size.X - cornerSize, 0)
            outlineLines[4].From = pos + Vector2.new(size.X, 0)
            outlineLines[4].To = pos + Vector2.new(size.X, cornerSize)
            -- bottom left
            outlineLines[5].From = pos + Vector2.new(0, size.Y)
            outlineLines[5].To = pos + Vector2.new(cornerSize, size.Y)
            outlineLines[6].From = pos + Vector2.new(0, size.Y)
            outlineLines[6].To = pos + Vector2.new(0, size.Y - cornerSize)
            -- bottom right
            outlineLines[7].From = pos + size
            outlineLines[7].To = pos + size - Vector2.new(cornerSize, 0)
            outlineLines[8].From = pos + size
            outlineLines[8].To = pos + size - Vector2.new(0, cornerSize)
            for _, l in pairs(outlineLines) do l.Thickness = outlineThickness; l.Color = Color3.new(0,0,0); l.Visible = isVisible end
        end
        local pos = bbox.Position - bbox.Size / 2
        local size = bbox.Size
        local cornerSize = math.min(size.X, size.Y) / 4
        local mainThickness = math.clamp((options.CornerThickness or 2) * scale, 1, options.MaxCornerThickness or 6)
        -- top left
        lines[1].From = pos
        lines[1].To = pos + Vector2.new(cornerSize, 0)
        lines[2].From = pos
        lines[2].To = pos + Vector2.new(0, cornerSize)
        -- top right
        lines[3].From = pos + Vector2.new(size.X, 0)
        lines[3].To = pos + Vector2.new(size.X - cornerSize, 0)
        lines[4].From = pos + Vector2.new(size.X, 0)
        lines[4].To = pos + Vector2.new(size.X, cornerSize)
        -- bottom left
        lines[5].From = pos + Vector2.new(0, size.Y)
        lines[5].To = pos + Vector2.new(cornerSize, size.Y)
        lines[6].From = pos + Vector2.new(0, size.Y)
        lines[6].To = pos + Vector2.new(0, size.Y - cornerSize)
        -- bottom right
        lines[7].From = pos + size
        lines[7].To = pos + size - Vector2.new(cornerSize, 0)
        lines[8].From = pos + size
        lines[8].To = pos + size - Vector2.new(0, cornerSize)
        for _, l in pairs(lines) do l.Thickness = mainThickness; l.Color = currentColor; l.Visible = isVisible end
    end

    -- Update tracer
    if data.Drawings.Tracer then
        local fromPos
        local mouse = game.Players.LocalPlayer:GetMouse()
        if options.TracerFrom == "Top" then
            fromPos = Vector2.new(camera.ViewportSize.X / 2, 0)
        elseif options.TracerFrom == "Bottom" then
            fromPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
        elseif options.TracerFrom == "Center" then
            fromPos = camera.ViewportSize / 2
        elseif options.TracerFrom == "Mouse" then
            fromPos = Vector2.new(mouse.X, mouse.Y)
        end
        data.Drawings.Tracer.From = fromPos
        data.Drawings.Tracer.To = bbox.Position
        data.Drawings.Tracer.Color = currentColor
        data.Drawings.Tracer.Thickness = math.clamp((options.TracerThickness or 1) * scale, 1, options.MaxTracerThickness or 6)
        data.Drawings.Tracer.Visible = isVisible
    end

    -- Update BillboardGui text
    if data.BillboardGui then
        data.BillboardGui.Enabled = isVisible
        local texts = data.Texts
        if texts then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if texts.name then
                texts.name.Text = options.Text or target.Name
                texts.name.TextColor3 = currentColor
                texts.name.Visible = isVisible
            end
            if texts.health and humanoid then
                texts.health.Text = tostring(math.floor(humanoid.Health))
                texts.health.TextColor3 = currentColor
                texts.health.Visible = isVisible
            elseif texts.health then
                texts.health.Visible = false
            end
            if texts.distance then
                texts.distance.Text = "[" .. math.floor(dist) .. "m]"
                texts.distance.TextColor3 = currentColor
                texts.distance.Visible = isVisible
            end
        end
    end

    -- Update healthbar
    if data.Drawings.HealthFillSegments or data.Drawings.HealthbarOutline then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local baseBarWidth = options.HealthbarWidth or 6
            local barWidth = math.max(4, baseBarWidth * scale)
            local baseBarHeight = bbox.Size.Y
            local barHeight = (options.ShrinkHealthbar and (baseBarHeight * healthPercent) or baseBarHeight) * scale
            local barPos = bbox.Position - bbox.Size / 2 - Vector2.new(barWidth + 4, 0)
            if options.ShrinkHealthbar then
                barPos = barPos + Vector2.new(0, baseBarHeight * scale - barHeight)  -- Adjust position for shrinking from top
            end
            local outlineTh = math.clamp((options.HealthbarOutlineThickness or 1) * scale, 1, options.MaxHealthbarOutlineThickness or 6)
            local inset = math.max(2, outlineTh + 1)  -- Ensure fills don't touch outline
            if data.Drawings.HealthFillSegments then
                local segments = data.Drawings.HealthFillSegments
                local numSegments = #segments
                local heightPerSegment = barHeight / numSegments
                for i = 1, numSegments do
                    local fill = segments[i]
                    local yOffset = (i-1) * heightPerSegment
                    -- inset fills to stay clearly inside the outline
                    local fillWidth = math.max(1, barWidth - inset * 2)
                    -- compute fractional visibility for partial segment handling
                    -- align fills to bottom so gradient grows from bottom up and doesn't overflow outline
                    local filledAmount = barHeight * healthPercent
                    local segmentTop = (i-1) * heightPerSegment
                    local segmentBottom = i * heightPerSegment
                    local visibleTop = math.max(segmentTop, barHeight - filledAmount)
                    local segVisibleHeight = math.max(0, segmentBottom - visibleTop)
                    if segVisibleHeight > 0 then
                        fill.Position = barPos + Vector2.new(inset, visibleTop)
                        fill.Size = Vector2.new(fillWidth, segVisibleHeight)
                        if options.Rainbow then
                            local hue = (tick() * options.RainbowSpeed + (i / numSegments)) % 1
                            fill.Color = Color3.fromHSV(hue, 1, 1)
                        elseif options.HealthbarGradient then
                            local t = tick() * options.GradientSpeed
                            local offset = t % 1
                            local fracColor = ((i-1) / numSegments + offset) % 1
                            local numColors = #options.GradientColors
                            local colorIndex = math.floor(fracColor * numColors) + 1
                            local nextIndex = colorIndex % numColors + 1
                            local lerpFrac = (fracColor * numColors) % 1
                            local color = options.GradientColors[colorIndex]:Lerp(options.GradientColors[nextIndex], lerpFrac)
                            fill.Color = color
                        else
                            fill.Color = options.Color or Color3.new(1,1,1)
                        end
                        fill.Visible = isVisible
                    else
                        fill.Visible = false
                    end
                end
            end
            if data.Drawings.HealthbarOutline then
                -- outline same size as bar
                data.Drawings.HealthbarOutline.Position = barPos
                data.Drawings.HealthbarOutline.Size = Vector2.new(barWidth, barHeight)
                data.Drawings.HealthbarOutline.Color = Color3.new(0,0,0)
                data.Drawings.HealthbarOutline.Thickness = outlineTh
                data.Drawings.HealthbarOutline.Visible = isVisible
            end
        else
            if data.Drawings.HealthbarOutline then data.Drawings.HealthbarOutline.Visible = false end
            if data.Drawings.HealthFillSegments then
                for _, fill in pairs(data.Drawings.HealthFillSegments) do
                    fill.Visible = false
                end
            end
        end
    end
end

-- Remove ESP from a target
function ESP:Remove(target: Instance)
    local data = activeESPs[target]
    if not data then return end

    for _, drawing in pairs(data.Drawings) do
        if type(drawing) == "table" then
            for _, d in pairs(drawing) do
                d:Remove()
            end
        else
            drawing:Remove()
        end
    end

    if data.Highlight then
        data.Highlight:Destroy()
    end

    if data.BillboardGui then
        data.BillboardGui:Destroy()
    end

    activeESPs[target] = nil

    -- Stop render loop if no more ESPs
    if next(activeESPs) == nil and renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
end

-- Update options for an existing ESP
function ESP:UpdateOptions(target: Instance, newOptions: table)
    local data = activeESPs[target]
    if not data then return end
    for k, v in pairs(newOptions) do
        data.Options[k] = v
    end
end

-- Set visibility of all ESPs
function ESP:SetVisible(visible: boolean)
    isVisible = visible
    for _, data in pairs(activeESPs) do
        for _, drawing in pairs(data.Drawings) do
            if type(drawing) == "table" then
                for _, d in pairs(drawing) do
                    d.Visible = visible
                end
            else
                drawing.Visible = visible
            end
        end
        if data.Highlight then
            data.Highlight.Enabled = visible
        end
        if data.BillboardGui then
            data.BillboardGui.Enabled = visible
        end
    end
end

-- Auto-add ESP to new players
function ESP:AutoAdd(options: table)
    if playerAddedConnection then playerAddedConnection:Disconnect() end
    if playerRemovingConnection then playerRemovingConnection:Disconnect() end

    autoAddOptions = options
    local Players = game:GetService("Players")

    local function addPlayer(player: Player)
        if player == Players.LocalPlayer then return end

        local function onCharacter(char: Model)
            if char then pcall(function() ESP:Add(char, options) end) end
        end

        if player.Character then pcall(function() onCharacter(player.Character) end) end
        player.CharacterAdded:Connect(onCharacter)
    end

    local function removePlayer(player: Player)
        if player.Character then pcall(function() ESP:Remove(player.Character) end) end
    end

    -- Add to existing players
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function() addPlayer(player) end)
    end

    -- Connect to new players
    playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
    playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
end

-- Stop auto-adding ESP
function ESP:StopAutoAdd()
    if playerAddedConnection then
        playerAddedConnection:Disconnect()
        playerAddedConnection = nil
    end
    if playerRemovingConnection then
        playerRemovingConnection:Disconnect()
        playerRemovingConnection = nil
    end
    autoAddOptions = nil
end

return ESP
