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
                          \|_______|\_________\|__|           \|_______|\|__|\|_______|\|__|\|__|\|__|\|__|\|__|\|__|\___/ /
                                   \|_________|                                                                     \|___|/

]]

-- TrisSploit's ESP Library v1.0.0

local ESP = {}
local activeESPs = {}
local isVisible = true
local renderConnection = nil

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
            local pos, onScreen = camera:WorldToViewportPoint(corner.Position)
            if onScreen then
                minX = math.min(minX, pos.X)
                minY = math.min(minY, pos.Y)
                maxX = math.max(maxX, pos.X)
                maxY = math.max(maxY, pos.Y)
            end
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
    local show3DBox = options.Show3DBox
    local showText = options.ShowText
    local showName = options.ShowName
    local showHealth = options.ShowHealth
    local showDistance = options.ShowDistance
    local showTracer = options.ShowTracer
    local tracerFrom = options.TracerFrom or "Bottom"
    local showOffscreenArrow = options.ShowOffscreenArrow
    local showChams = options.ShowChams
    local chamsColor = options.ChamsColor or color
    local maxDistance = options.MaxDistance
    local showHealthbar = options.Healthbar
    local healthbarGradient = options.HealthbarGradient
    local shrinkHealthbar = options.ShrinkHealthbar or false
    local gradientColors = options.GradientColors or {Color3.new(1,0,0), Color3.new(0,1,0)}
    local gradientSpeed = options.GradientSpeed or 1

    local espData = {
        Target = target,
        Drawings = {},
        Options = options
    }

    local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")

    if showBox then
        if boxType == "Full" then
            local box = Drawing.new("Square")
            box.Color = color
            box.Thickness = 1
            box.Filled = false
            box.Visible = isVisible
            espData.Drawings.Box = box
        elseif boxType == "Corner" then
            local lines = {}
            for i = 1, 8 do
                local line = Drawing.new("Line")
                line.Color = color
                line.Thickness = 1
                line.Visible = isVisible
                table.insert(lines, line)
            end
            espData.Drawings.CornerLines = lines
        elseif boxType == "Radius" then
            local circle = Drawing.new("Circle")
            circle.Color = color
            circle.Thickness = 1
            circle.Filled = false
            circle.NumSides = 32
            circle.Visible = isVisible
            espData.Drawings.Circle = circle
        end
    end

    if show3DBox then
        local lines = {}
        for i = 1, 12 do
            local line = Drawing.new("Line")
            line.Color = color
            line.Thickness = 1
            line.Visible = isVisible
            table.insert(lines, line)
        end
        espData.Drawings.Box3DLines = lines
    end

    if showTracer then
        local tracer = Drawing.new("Line")
        tracer.Color = color
        tracer.Thickness = 1
        tracer.Visible = isVisible
        espData.Drawings.Tracer = tracer
    end

    if showOffscreenArrow then
        local arrow = Drawing.new("Triangle")
        arrow.Color = color
        arrow.Filled = true
        arrow.Visible = false
        espData.Drawings.Arrow = arrow
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

    if showText or showName or showHealth or showDistance then
        local txt = Drawing.new("Text")
        txt.Color = color
        txt.Size = 14
        txt.Center = true
        txt.Outline = true
        txt.Visible = isVisible
        espData.Drawings.Text = txt
    end

    if showHealthbar then
        local segments = {}
        local numSegments = 200  -- Ultra-smooth gradient
        for i = 1, numSegments do
            local fill = Drawing.new("Square")
            fill.Filled = true
            fill.Visible = isVisible
            table.insert(segments, fill)
        end
        espData.Drawings.HealthFillSegments = segments

        -- Add outline
        local outline = Drawing.new("Square")
        outline.Color = Color3.new(0,0,0)
        outline.Thickness = 1
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
        return
    end

    local bbox = nil
    if onScreen then
        bbox = getBoundingBox(model)
    end

    -- Update chams
    if data.Highlight then
        data.Highlight.Enabled = isVisible
    end

    -- Update offscreen arrow
    if data.Drawings.Arrow then
        if not onScreen then
            -- calculate edge pos
            local viewportSize = camera.ViewportSize
            local center = viewportSize / 2
            local dir = (screenPos - center).Unit
            local edgeDist = math.min(viewportSize.X, viewportSize.Y) / 2
            local edgePos = center + dir * edgeDist
            -- set triangle points for arrow
            local angle = math.atan2(dir.Y, dir.X)
            local size = 20
            local p1 = edgePos + Vector2.new(math.cos(angle), math.sin(angle)) * size
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
        if data.Drawings.CornerLines then for _, l in pairs(data.Drawings.CornerLines) do l.Visible = false end end
        if data.Drawings.Circle then data.Drawings.Circle.Visible = false end
        if data.Drawings.Box3DLines then for _, l in pairs(data.Drawings.Box3DLines) do l.Visible = false end end
        if data.Drawings.Tracer then data.Drawings.Tracer.Visible = false end
        if data.Drawings.Text then data.Drawings.Text.Visible = false end
        if data.Drawings.HealthbarOutline then data.Drawings.HealthbarOutline.Visible = false end
        if data.Drawings.HealthFillSegments then for _, d in pairs(data.Drawings.HealthFillSegments) do d.Visible = false end end
        return
    end

    -- Update box
    if data.Drawings.Box then
        data.Drawings.Box.Position = bbox.Position - bbox.Size / 2
        data.Drawings.Box.Size = bbox.Size
        data.Drawings.Box.Thickness = 2  -- Thicker outline
        data.Drawings.Box.Visible = isVisible
    end

    if data.Drawings.CornerLines then
        local lines = data.Drawings.CornerLines
        local pos = bbox.Position - bbox.Size / 2
        local size = bbox.Size
        local cornerSize = math.min(size.X, size.Y) / 4
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
        for _, l in pairs(lines) do l.Visible = isVisible end
    end

    if data.Drawings.Circle then
        data.Drawings.Circle.Position = bbox.Position
        data.Drawings.Circle.Radius = math.max(bbox.Size.X, bbox.Size.Y) / 2
        data.Drawings.Circle.Visible = isVisible
    end

    -- Update 3D box
    if data.Drawings.Box3DLines then
        -- get corners
        local cf = model:GetPivot()
        local size = model:GetExtentsSize()
        local corners = {}
        for i, offset in ipairs({
            CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
            CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
            CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
            CFrame.new(size.X/2, size.Y/2, -size.Z/2),
            CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
            CFrame.new(size.X/2, -size.Y/2, size.Z/2),
            CFrame.new(-size.X/2, size.Y/2, size.Z/2),
            CFrame.new(size.X/2, size.Y/2, size.Z/2),
        }) do
            local worldPos = (cf * offset).Position
            local screenPos3 = camera:WorldToViewportPoint(worldPos)
            corners[i] = Vector2.new(screenPos3.X, screenPos3.Y)
        end
        local lines = data.Drawings.Box3DLines
        -- front face
        lines[1].From = corners[1]
        lines[1].To = corners[2]
        lines[2].From = corners[2]
        lines[2].To = corners[4]
        lines[3].From = corners[4]
        lines[3].To = corners[3]
        lines[4].From = corners[3]
        lines[4].To = corners[1]
        -- back face
        lines[5].From = corners[5]
        lines[5].To = corners[6]
        lines[6].From = corners[6]
        lines[6].To = corners[8]
        lines[7].From = corners[8]
        lines[7].To = corners[7]
        lines[8].From = corners[7]
        lines[8].To = corners[5]
        -- sides
        lines[9].From = corners[1]
        lines[9].To = corners[5]
        lines[10].From = corners[2]
        lines[10].To = corners[6]
        lines[11].From = corners[3]
        lines[11].To = corners[7]
        lines[12].From = corners[4]
        lines[12].To = corners[8]
        for _, l in pairs(lines) do l.Visible = isVisible end
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
        data.Drawings.Tracer.Visible = isVisible
    end

    -- Update text
    if data.Drawings.Text then
        local textStr = ""
        if options.ShowName then
            textStr = textStr .. (options.Text or target.Name)
        end
        if options.ShowHealth then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid then
                textStr = textStr .. " [" .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth) .. "]"
            end
        end
        if options.ShowDistance then
            textStr = textStr .. " [" .. math.floor(dist) .. "m]"
        end
        data.Drawings.Text.Text = textStr
        data.Drawings.Text.Position = bbox.Position + Vector2.new(0, bbox.Size.Y / 2 + 10)
        data.Drawings.Text.Outline = true  -- Ensure outline
        data.Drawings.Text.Visible = isVisible
    end

    -- Update healthbar
    if data.Drawings.HealthFillSegments or data.Drawings.HealthbarOutline then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local barWidth = math.max(2, bbox.Size.Y * 0.03)  -- Scale with distance, min 2
            local baseBarHeight = bbox.Size.Y
            local barHeight = options.ShrinkHealthbar and (baseBarHeight * healthPercent) or baseBarHeight
            local barPos = bbox.Position - bbox.Size / 2 - Vector2.new(barWidth + 2, 0)
            if options.ShrinkHealthbar then
                barPos = barPos + Vector2.new(0, baseBarHeight - barHeight)  -- Adjust position for shrinking from top
            end
            if data.Drawings.HealthbarOutline then
                data.Drawings.HealthbarOutline.Position = barPos - Vector2.new(1, 1)
                data.Drawings.HealthbarOutline.Size = Vector2.new(barWidth + 2, baseBarHeight + 2)
                data.Drawings.HealthbarOutline.Visible = isVisible
            end
            if data.Drawings.HealthFillSegments then
                local segments = data.Drawings.HealthFillSegments
                local numSegments = #segments
                local heightPerSegment = barHeight / numSegments
                for i = 1, numSegments do
                    local fill = segments[i]
                    local yOffset = (i-1) * heightPerSegment
                    fill.Position = barPos + Vector2.new(0, yOffset)
                    fill.Size = Vector2.new(barWidth, heightPerSegment + 2)  -- Larger overlap to remove gaps
                    if (i / numSegments) <= 1 then  -- Always show segments up to bar height
                        if options.HealthbarGradient then
                            local t = tick() * options.GradientSpeed
                            local offset = t % 1
                            local frac = ((i-1) / numSegments + offset) % 1
                            local numColors = #options.GradientColors
                            local colorIndex = math.floor(frac * numColors) + 1
                            local nextIndex = colorIndex % numColors + 1
                            local lerpFrac = (frac * numColors) % 1
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

    activeESPs[target] = nil

    -- Stop render loop if no more ESPs
    if next(activeESPs) == nil and renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
end

-- Clear all ESPs
function ESP:Clear()
    for target in pairs(activeESPs) do
        ESP:Remove(target)
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
    end
end

return ESP
