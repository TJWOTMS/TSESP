--[[
	TrisSplpit ESP Library
]]

local TSESP = {
	Version = "1.0.0",
	Author = "TrisSploit",
	_instances = {},
	_partInstances = {},
	_connections = {},
	_cache = {},
	_renderStep = nil,
}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Configuration defaults
local DefaultConfig = {
	Enabled = true,
	TeamCheck = false,
	AliveCheck = true,
	MaxDistance = 1000,
	
	-- Box ESP
	Box = {
		Enabled = true,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 2,
		Filled = false,
		FillTransparency = 0.8,
		Outline = true,
		OutlineColor = Color3.fromRGB(0, 0, 0),
	},
	
	-- Tracer
	Tracer = {
		Enabled = false,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1.5,
		Transparency = 1,
		From = "Bottom", -- "Top", "Center", "Bottom", "Mouse"
		Outline = true,
		OutlineColor = Color3.fromRGB(0, 0, 0),
	},
	
	-- Name ESP
	Name = {
		Enabled = true,
		Color = Color3.fromRGB(255, 255, 255),
		Size = 14,
		Font = (Drawing.Fonts.SFPixelate or Drawing.Fonts['SF Pixelate'] or Drawing.Fonts.Monospace),
		Outline = true,
		OutlineColor = Color3.fromRGB(0, 0, 0),
		DisplayDistance = true,
		DisplayHealth = false,
	},
	
	-- Health Bar
	HealthBar = {
		Enabled = true,
		Position = "Right", -- "Left", "Right", "Top", "Bottom"
		Size = 2,
		Color = Color3.fromRGB(0, 255, 0),
		LowHealthColor = Color3.fromRGB(255, 0, 0),
		Outline = true,
		OutlineColor = Color3.fromRGB(0, 0, 0),
		LerpColor = true,
		Gradient = {
			Enabled = false,
			Colors = {
				Color3.fromRGB(0, 255, 0),
				Color3.fromRGB(0, 170, 255),
				Color3.fromRGB(255, 0, 170),
			},
			Speed = 0.75, -- cycles per second
		},
	},
	
	-- Chams (Highlight)
	Chams = {
		Enabled = false,
		FillColor = Color3.fromRGB(255, 0, 0),
		FillTransparency = 0.5,
		OutlineColor = Color3.fromRGB(255, 255, 255),
		OutlineTransparency = 0,
	},
}

-- Utility Functions
local Utilities = {}

function Utilities:IsAlive(player)
	if not player or not player.Character then
		return false
	end
	
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
	
	return humanoid and rootPart and humanoid.Health > 0
end

function Utilities:GetTeam(player)
	return player.Team
end

function Utilities:IsOnScreen(position)
	local _, onScreen = Camera:WorldToViewportPoint(position)
	return onScreen
end

function Utilities:GetDistance(position)
	if not Camera then return math.huge end
	return (Camera.CFrame.Position - position).Magnitude
end

function Utilities:GetScreenPosition(position)
	local screenPos, onScreen = Camera:WorldToViewportPoint(position)
	return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

function Utilities:GetBoundingBox(character)
	if not character then return nil end

	local cf, size = character:GetBoundingBox()
	if not cf or not size then
		return nil
	end

	local half = size * 0.5
	local corners = {
		Vector3.new(half.X, half.Y, half.Z),
		Vector3.new(half.X, half.Y, -half.Z),
		Vector3.new(half.X, -half.Y, half.Z),
		Vector3.new(half.X, -half.Y, -half.Z),
		Vector3.new(-half.X, half.Y, half.Z),
		Vector3.new(-half.X, half.Y, -half.Z),
		Vector3.new(-half.X, -half.Y, half.Z),
		Vector3.new(-half.X, -half.Y, -half.Z),
	}

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local anyVisible = false

	for _, corner in ipairs(corners) do
		local worldPos = cf:PointToWorldSpace(corner)
		local screenPos, onScreen = self:GetScreenPosition(worldPos)
		if onScreen then
			anyVisible = true
		end
		minX = math.min(minX, screenPos.X)
		maxX = math.max(maxX, screenPos.X)
		minY = math.min(minY, screenPos.Y)
		maxY = math.max(maxY, screenPos.Y)
	end

	if not anyVisible then
		return nil
	end

	return {
		Position = Vector2.new(minX, minY),
		Size = Vector2.new(maxX - minX, maxY - minY),
	}
end

function Utilities:GetPartBoundingBox(part)
	if not part or not part.CFrame or not part.Size then
		return nil
	end

	local half = part.Size * 0.5
	local corners = {
		Vector3.new(half.X, half.Y, half.Z),
		Vector3.new(half.X, half.Y, -half.Z),
		Vector3.new(half.X, -half.Y, half.Z),
		Vector3.new(half.X, -half.Y, -half.Z),
		Vector3.new(-half.X, half.Y, half.Z),
		Vector3.new(-half.X, half.Y, -half.Z),
		Vector3.new(-half.X, -half.Y, half.Z),
		Vector3.new(-half.X, -half.Y, -half.Z),
	}

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local anyVisible = false

	for _, corner in ipairs(corners) do
		local worldPos = part.CFrame:PointToWorldSpace(corner)
		local screenPos, onScreen = self:GetScreenPosition(worldPos)
		if onScreen then
			anyVisible = true
		end
		minX = math.min(minX, screenPos.X)
		maxX = math.max(maxX, screenPos.X)
		minY = math.min(minY, screenPos.Y)
		maxY = math.max(maxY, screenPos.Y)
	end

	if not anyVisible then
		return nil
	end

	return {
		Position = Vector2.new(minX, minY),
		Size = Vector2.new(maxX - minX, maxY - minY),
	}
end

function Utilities:LerpColor(from, to, alpha)
	return Color3.new(
		from.R + (to.R - from.R) * alpha,
		from.G + (to.G - from.G) * alpha,
		from.B + (to.B - from.B) * alpha
	)
end

function Utilities:GetCycleColor(gradientConfig)
	local colors = gradientConfig and gradientConfig.Colors
	if not colors or #colors < 2 then
		return nil
	end

	local speed = gradientConfig.Speed or 1
	local s = (tick() * speed) % #colors
	local base = math.floor(s) + 1
	local next = base % #colors + 1
	local alpha = s - math.floor(s)

	return Utilities:LerpColor(colors[base], colors[next], alpha)
end

-- Drawing Object Manager
local DrawingCache = {}

function DrawingCache:Create(type)
	local drawing = Drawing.new(type)
	return drawing
end

function DrawingCache:Remove(drawing)
	if drawing then
		drawing:Remove()
	end
end

-- ESP Instance Class
local ESPInstance = {}
ESPInstance.__index = ESPInstance

function ESPInstance.new(player, config)
	local self = setmetatable({}, ESPInstance)
	
	self.Player = player
	self.Config = config or DefaultConfig
	self.Drawings = {}
	self.Highlight = nil
	self.Updating = false
	
	self:CreateDrawings()
	
	return self
end

function ESPInstance:CreateDrawings()
	-- Box
	self.Drawings.Box = DrawingCache:Create("Square")
	self.Drawings.BoxOutline = DrawingCache:Create("Square")
	
	-- Tracer
	self.Drawings.Tracer = DrawingCache:Create("Line")
	self.Drawings.TracerOutline = DrawingCache:Create("Line")
	
	-- Name
	self.Drawings.Name = DrawingCache:Create("Text")
	
	-- Health Bar
	self.Drawings.HealthBarOutline = DrawingCache:Create("Square")
	self.Drawings.HealthBar = DrawingCache:Create("Square")
	
	-- Chams (Highlight)
	if self.Config.Chams.Enabled then
		self:CreateHighlight()
	end
end

function ESPInstance:CreateHighlight()
	if self.Player.Character then
		self.Highlight = Instance.new("Highlight")
		self.Highlight.Adornee = self.Player.Character
		self.Highlight.FillColor = self.Config.Chams.FillColor
		self.Highlight.FillTransparency = self.Config.Chams.FillTransparency
		self.Highlight.OutlineColor = self.Config.Chams.OutlineColor
		self.Highlight.OutlineTransparency = self.Config.Chams.OutlineTransparency
		self.Highlight.Parent = Workspace
	end
end

function ESPInstance:UpdateHighlight()
	if self.Config.Chams.Enabled then
		if not self.Highlight and self.Player.Character then
			self:CreateHighlight()
		elseif self.Highlight then
			self.Highlight.FillColor = self.Config.Chams.FillColor
			self.Highlight.FillTransparency = self.Config.Chams.FillTransparency
			self.Highlight.OutlineColor = self.Config.Chams.OutlineColor
			self.Highlight.OutlineTransparency = self.Config.Chams.OutlineTransparency
			
			if self.Highlight.Adornee ~= self.Player.Character then
				self.Highlight.Adornee = self.Player.Character
			end
		end
	elseif self.Highlight then
		self.Highlight:Destroy()
		self.Highlight = nil
	end
end

function ESPInstance:Update()
	if self.Updating then return end
	self.Updating = true
	
	local success, err = pcall(function()
		local config = self.Config
		local player = self.Player
		
		-- Check if ESP should be visible
		if not config.Enabled then
			self:SetVisible(false)
			self.Updating = false
			return
		end
		
		if config.AliveCheck and not Utilities:IsAlive(player) then
			self:SetVisible(false)
			self.Updating = false
			return
		end
		
		if config.TeamCheck and player.Team == LocalPlayer.Team then
			self:SetVisible(false)
			self.Updating = false
			return
		end
		
		local character = player.Character
		if not character then
			self:SetVisible(false)
			self.Updating = false
			return
		end
		
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		
		if not rootPart then
			self:SetVisible(false)
			self.Updating = false
			return
		end
		
		local distance = Utilities:GetDistance(rootPart.Position)
		if distance > config.MaxDistance then
			self:SetVisible(false)
			self.Updating = false
			return
		end
		
		local boundingBox = Utilities:GetBoundingBox(character)
		if not boundingBox then
			self:SetVisible(false)
			self.Updating = false
			return
		end
		
		-- Update Box
		if config.Box.Enabled then
			self:UpdateBox(boundingBox)
		else
			self.Drawings.Box.Visible = false
			self.Drawings.BoxOutline.Visible = false
		end
		
		-- Update Tracer
		if config.Tracer.Enabled then
			self:UpdateTracer(rootPart.Position)
		else
			self.Drawings.Tracer.Visible = false
			self.Drawings.TracerOutline.Visible = false
		end
		
		-- Update Name
		if config.Name.Enabled then
			self:UpdateName(player, boundingBox, distance, humanoid)
		else
			self.Drawings.Name.Visible = false
		end
		
		-- Update Health Bar
		if config.HealthBar.Enabled and humanoid then
			self:UpdateHealthBar(boundingBox, humanoid)
		else
			self.Drawings.HealthBar.Visible = false
			self.Drawings.HealthBarOutline.Visible = false
		end
		
		-- Update Chams
		self:UpdateHighlight()
	end)
	
	if not success then
		warn("[TSESP] Error updating ESP for " .. tostring(self.Player) .. ": " .. tostring(err))
	end
	
	self.Updating = false
end

function ESPInstance:UpdateBox(boundingBox)
	local config = self.Config.Box
	
	-- Outline
	if config.Outline then
		self.Drawings.BoxOutline.Visible = true
		self.Drawings.BoxOutline.Position = boundingBox.Position - Vector2.new(1, 1)
		self.Drawings.BoxOutline.Size = boundingBox.Size + Vector2.new(2, 2)
		self.Drawings.BoxOutline.Color = config.OutlineColor
		self.Drawings.BoxOutline.Thickness = config.Thickness
		self.Drawings.BoxOutline.Filled = false
		self.Drawings.BoxOutline.ZIndex = 1
	else
		self.Drawings.BoxOutline.Visible = false
	end
	
	-- Main Box
	self.Drawings.Box.Visible = true
	self.Drawings.Box.Position = boundingBox.Position
	self.Drawings.Box.Size = boundingBox.Size
	self.Drawings.Box.Color = config.Color
	self.Drawings.Box.Thickness = config.Thickness
	self.Drawings.Box.Filled = config.Filled
	self.Drawings.Box.Transparency = config.Filled and config.FillTransparency or 1
	self.Drawings.Box.ZIndex = 2
end

function ESPInstance:UpdateTracer(position)
	local config = self.Config.Tracer
	
	local screenPos, onScreen = Utilities:GetScreenPosition(position)
	if not onScreen then
		self.Drawings.Tracer.Visible = false
		self.Drawings.TracerOutline.Visible = false
		return
	end
	
	local fromPosition
	local viewportSize = Camera.ViewportSize
	
	if config.From == "Top" then
		fromPosition = Vector2.new(viewportSize.X / 2, 0)
	elseif config.From == "Center" then
		fromPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	elseif config.From == "Bottom" then
		fromPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y)
	elseif config.From == "Mouse" then
		local mouse = LocalPlayer:GetMouse()
		fromPosition = Vector2.new(mouse.X, mouse.Y)
	else
		fromPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y)
	end
	
	-- Outline
	if config.Outline then
		self.Drawings.TracerOutline.Visible = true
		self.Drawings.TracerOutline.From = fromPosition
		self.Drawings.TracerOutline.To = screenPos
		self.Drawings.TracerOutline.Color = config.OutlineColor
		self.Drawings.TracerOutline.Thickness = config.Thickness + 2
		self.Drawings.TracerOutline.Transparency = config.Transparency
		self.Drawings.TracerOutline.ZIndex = 1
	else
		self.Drawings.TracerOutline.Visible = false
	end
	
	-- Main Tracer
	self.Drawings.Tracer.Visible = true
	self.Drawings.Tracer.From = fromPosition
	self.Drawings.Tracer.To = screenPos
	self.Drawings.Tracer.Color = config.Color
	self.Drawings.Tracer.Thickness = config.Thickness
	self.Drawings.Tracer.Transparency = config.Transparency
	self.Drawings.Tracer.ZIndex = 2
end

function ESPInstance:UpdateName(player, boundingBox, distance, humanoid)
	local config = self.Config.Name
	
	local displayText = player.Name
	
	if config.DisplayDistance then
		displayText = displayText .. string.format(" [%.0fm]", distance)
	end
	
	if config.DisplayHealth and humanoid then
		displayText = displayText .. string.format(" [%d/%d]", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
	end
	
	self.Drawings.Name.Visible = true
	self.Drawings.Name.Text = displayText
	self.Drawings.Name.Color = config.Color
	self.Drawings.Name.Size = config.Size
	self.Drawings.Name.Font = config.Font
	self.Drawings.Name.Outline = config.Outline
	self.Drawings.Name.OutlineColor = config.OutlineColor
	self.Drawings.Name.Center = true
	self.Drawings.Name.Position = Vector2.new(
		boundingBox.Position.X + boundingBox.Size.X / 2,
		boundingBox.Position.Y - 18
	)
	self.Drawings.Name.ZIndex = 3
end

function ESPInstance:UpdateHealthBar(boundingBox, humanoid)
	local config = self.Config.HealthBar
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	
	local barWidth, barHeight
	local barPos
	
	if config.Position == "Left" then
		barWidth = config.Size
		barHeight = boundingBox.Size.Y
		barPos = Vector2.new(boundingBox.Position.X - config.Size - 3, boundingBox.Position.Y)
	elseif config.Position == "Right" then
		barWidth = config.Size
		barHeight = boundingBox.Size.Y
		barPos = Vector2.new(boundingBox.Position.X + boundingBox.Size.X + 3, boundingBox.Position.Y)
	elseif config.Position == "Top" then
		barWidth = boundingBox.Size.X
		barHeight = config.Size
		barPos = Vector2.new(boundingBox.Position.X, boundingBox.Position.Y - config.Size - 3)
	elseif config.Position == "Bottom" then
		barWidth = boundingBox.Size.X
		barHeight = config.Size
		barPos = Vector2.new(boundingBox.Position.X, boundingBox.Position.Y + boundingBox.Size.Y + 3)
	end
	
	-- Outline
	if config.Outline then
		self.Drawings.HealthBarOutline.Visible = true
		self.Drawings.HealthBarOutline.Position = barPos - Vector2.new(1, 1)
		self.Drawings.HealthBarOutline.Size = Vector2.new(barWidth + 2, barHeight + 2)
		self.Drawings.HealthBarOutline.Color = config.OutlineColor
		self.Drawings.HealthBarOutline.Filled = true
		self.Drawings.HealthBarOutline.Transparency = 1
		self.Drawings.HealthBarOutline.ZIndex = 1
	else
		self.Drawings.HealthBarOutline.Visible = false
	end
	
	-- Health Bar
	local healthColor = config.Color
	local gradientColor = config.Gradient.Enabled and Utilities:GetCycleColor(config.Gradient)
	if gradientColor then
		healthColor = gradientColor
	elseif config.LerpColor then
		healthColor = Utilities:LerpColor(config.LowHealthColor, config.Color, healthPercent)
	elseif healthPercent < 0.3 then
		healthColor = config.LowHealthColor
	end
	
	local healthBarSize
	if config.Position == "Left" or config.Position == "Right" then
		healthBarSize = Vector2.new(barWidth, barHeight * healthPercent)
		barPos = Vector2.new(barPos.X, barPos.Y + barHeight * (1 - healthPercent))
	else
		healthBarSize = Vector2.new(barWidth * healthPercent, barHeight)
	end
	
	self.Drawings.HealthBar.Visible = true
	self.Drawings.HealthBar.Position = barPos
	self.Drawings.HealthBar.Size = healthBarSize
	self.Drawings.HealthBar.Color = healthColor
	self.Drawings.HealthBar.Filled = true
	self.Drawings.HealthBar.Transparency = 1
	self.Drawings.HealthBar.ZIndex = 2
end

function ESPInstance:SetVisible(visible)
	for _, drawing in pairs(self.Drawings) do
		if drawing then
			drawing.Visible = visible
		end
	end
	
	if self.Highlight then
		self.Highlight.Enabled = visible
	end
end

function ESPInstance:Remove()
	for _, drawing in pairs(self.Drawings) do
		DrawingCache:Remove(drawing)
	end
	
	if self.Highlight then
		self.Highlight:Destroy()
	end
	
	self.Drawings = {}
	self.Highlight = nil
end

-- Part ESP Instance Class
local PartESPInstance = {}
PartESPInstance.__index = PartESPInstance

function PartESPInstance.new(part, label, config)
	local self = setmetatable({}, PartESPInstance)

	self.Part = part
	self.Label = label or (part and part.Name) or "Part"
	self.Config = config or DefaultConfig
	self.Drawings = {}
	self.Highlight = nil
	self.Updating = false

	self:CreateDrawings()

	return self
end

function PartESPInstance:CreateDrawings()
	self.Drawings.Box = DrawingCache:Create("Square")
	self.Drawings.BoxOutline = DrawingCache:Create("Square")
	self.Drawings.Tracer = DrawingCache:Create("Line")
	self.Drawings.TracerOutline = DrawingCache:Create("Line")
	self.Drawings.Name = DrawingCache:Create("Text")

	if self.Config.Chams.Enabled then
		self:CreateHighlight()
	end
end

function PartESPInstance:CreateHighlight()
	if self.Part then
		self.Highlight = Instance.new("Highlight")
		self.Highlight.Adornee = self.Part
		self.Highlight.FillColor = self.Config.Chams.FillColor
		self.Highlight.FillTransparency = self.Config.Chams.FillTransparency
		self.Highlight.OutlineColor = self.Config.Chams.OutlineColor
		self.Highlight.OutlineTransparency = self.Config.Chams.OutlineTransparency
		self.Highlight.Parent = Workspace
	end
end

function PartESPInstance:UpdateHighlight()
	if self.Config.Chams.Enabled then
		if not self.Highlight and self.Part then
			self:CreateHighlight()
		elseif self.Highlight then
			self.Highlight.FillColor = self.Config.Chams.FillColor
			self.Highlight.FillTransparency = self.Config.Chams.FillTransparency
			self.Highlight.OutlineColor = self.Config.Chams.OutlineColor
			self.Highlight.OutlineTransparency = self.Config.Chams.OutlineTransparency
			if self.Highlight.Adornee ~= self.Part then
				self.Highlight.Adornee = self.Part
			end
		end
	elseif self.Highlight then
		self.Highlight:Destroy()
		self.Highlight = nil
	end
end

function PartESPInstance:Update()
	if self.Updating then return end
	self.Updating = true

	local ok, err = pcall(function()
		local config = self.Config
		local part = self.Part

		if not config.Enabled then
			self:SetVisible(false)
			self.Updating = false
			return
		end

		if not part or not part.Parent or not part:IsA("BasePart") then
			self:SetVisible(false)
			self.Updating = false
			return
		end

		local position = part.Position
		local distance = Utilities:GetDistance(position)
		if distance > config.MaxDistance then
			self:SetVisible(false)
			self.Updating = false
			return
		end

		local boundingBox = Utilities:GetPartBoundingBox(part)
		if not boundingBox then
			self:SetVisible(false)
			self.Updating = false
			return
		end

		if config.Box.Enabled then
			self:UpdateBox(boundingBox)
		else
			self.Drawings.Box.Visible = false
			self.Drawings.BoxOutline.Visible = false
		end

		if config.Tracer.Enabled then
			self:UpdateTracer(position)
		else
			self.Drawings.Tracer.Visible = false
			self.Drawings.TracerOutline.Visible = false
		end

		if config.Name.Enabled then
			self:UpdateName(boundingBox, distance)
		else
			self.Drawings.Name.Visible = false
		end

		self:UpdateHighlight()
	end)

	if not ok then
		warn("[TSESP] Error updating part ESP: " .. tostring(err))
	end

	self.Updating = false
end

function PartESPInstance:UpdateBox(boundingBox)
	local config = self.Config.Box

	if config.Outline then
		self.Drawings.BoxOutline.Visible = true
		self.Drawings.BoxOutline.Position = boundingBox.Position - Vector2.new(1, 1)
		self.Drawings.BoxOutline.Size = boundingBox.Size + Vector2.new(2, 2)
		self.Drawings.BoxOutline.Color = config.OutlineColor
		self.Drawings.BoxOutline.Thickness = config.Thickness
		self.Drawings.BoxOutline.Filled = false
		self.Drawings.BoxOutline.ZIndex = 1
	else
		self.Drawings.BoxOutline.Visible = false
	end

	self.Drawings.Box.Visible = true
	self.Drawings.Box.Position = boundingBox.Position
	self.Drawings.Box.Size = boundingBox.Size
	self.Drawings.Box.Color = config.Color
	self.Drawings.Box.Thickness = config.Thickness
	self.Drawings.Box.Filled = config.Filled
	self.Drawings.Box.Transparency = config.Filled and config.FillTransparency or 1
	self.Drawings.Box.ZIndex = 2
end

function PartESPInstance:UpdateTracer(position)
	local config = self.Config.Tracer

	local screenPos, onScreen = Utilities:GetScreenPosition(position)
	if not onScreen then
		self.Drawings.Tracer.Visible = false
		self.Drawings.TracerOutline.Visible = false
		return
	end

	local fromPosition
	local viewportSize = Camera.ViewportSize

	if config.From == "Top" then
		fromPosition = Vector2.new(viewportSize.X / 2, 0)
	elseif config.From == "Center" then
		fromPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	elseif config.From == "Bottom" then
		fromPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y)
	elseif config.From == "Mouse" then
		local mouse = LocalPlayer:GetMouse()
		fromPosition = Vector2.new(mouse.X, mouse.Y)
	else
		fromPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y)
	end

	if config.Outline then
		self.Drawings.TracerOutline.Visible = true
		self.Drawings.TracerOutline.From = fromPosition
		self.Drawings.TracerOutline.To = screenPos
		self.Drawings.TracerOutline.Color = config.OutlineColor
		self.Drawings.TracerOutline.Thickness = config.Thickness + 2
		self.Drawings.TracerOutline.Transparency = config.Transparency
		self.Drawings.TracerOutline.ZIndex = 1
	else
		self.Drawings.TracerOutline.Visible = false
	end

	self.Drawings.Tracer.Visible = true
	self.Drawings.Tracer.From = fromPosition
	self.Drawings.Tracer.To = screenPos
	self.Drawings.Tracer.Color = config.Color
	self.Drawings.Tracer.Thickness = config.Thickness
	self.Drawings.Tracer.Transparency = config.Transparency
	self.Drawings.Tracer.ZIndex = 2
end

function PartESPInstance:UpdateName(boundingBox, distance)
	local config = self.Config.Name
	local displayText = self.Label

	if config.DisplayDistance then
		displayText = displayText .. string.format(" [%.0fm]", distance)
	end

	self.Drawings.Name.Visible = true
	self.Drawings.Name.Text = displayText
	self.Drawings.Name.Color = config.Color
	self.Drawings.Name.Size = config.Size
	self.Drawings.Name.Font = config.Font
	self.Drawings.Name.Outline = config.Outline
	self.Drawings.Name.OutlineColor = config.OutlineColor
	self.Drawings.Name.Center = true
	self.Drawings.Name.Position = Vector2.new(
		boundingBox.Position.X + boundingBox.Size.X / 2,
		boundingBox.Position.Y - 18
	)
	self.Drawings.Name.ZIndex = 3
end

function PartESPInstance:SetVisible(visible)
	for _, drawing in pairs(self.Drawings) do
		if drawing then
			drawing.Visible = visible
		end
	end

	if self.Highlight then
		self.Highlight.Enabled = visible
	end
end

function PartESPInstance:Remove()
	for _, drawing in pairs(self.Drawings) do
		DrawingCache:Remove(drawing)
	end

	if self.Highlight then
		self.Highlight:Destroy()
	end

	self.Drawings = {}
	self.Highlight = nil
end

-- Main TSESP Functions
function TSESP:AddPlayer(player, customConfig)
	if self._instances[player] then
		return
	end
	
	local config = customConfig or self:DeepCopy(DefaultConfig)
	local instance = ESPInstance.new(player, config)
	self._instances[player] = instance
	
	return instance
end

function TSESP:RemovePlayer(player)
	local instance = self._instances[player]
	if instance then
		instance:Remove()
		self._instances[player] = nil
	end
end

function TSESP:GetPlayer(player)
	return self._instances[player]
end

function TSESP:AddAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			self:AddPlayer(player)
		end
	end
end

function TSESP:AddPart(part, label, customConfig)
	if not part or not part:IsA("BasePart") then
		return
	end

	if self._partInstances[part] then
		return
	end

	local config = customConfig or self:DeepCopy(DefaultConfig)
	local instance = PartESPInstance.new(part, label, config)
	self._partInstances[part] = instance

	return instance
end

function TSESP:RemovePart(part)
	local instance = self._partInstances[part]
	if instance then
		instance:Remove()
		self._partInstances[part] = nil
	end
end

function TSESP:GetPart(part)
	return self._partInstances[part]
end

function TSESP:RemoveAllPlayers()
	for player, _ in pairs(self._instances) do
		self:RemovePlayer(player)
	end
end

function TSESP:RemoveAllParts()
	for part, _ in pairs(self._partInstances) do
		self:RemovePart(part)
	end
end

function TSESP:UpdateConfig(player, newConfig)
	local instance = self._instances[player]
	if instance then
		for key, value in pairs(newConfig) do
			if type(value) == "table" then
				for subKey, subValue in pairs(value) do
					instance.Config[key][subKey] = subValue
				end
			else
				instance.Config[key] = value
			end
		end
	end
end

function TSESP:UpdateAllConfigs(newConfig)
	for player, _ in pairs(self._instances) do
		self:UpdateConfig(player, newConfig)
	end

	for part, _ in pairs(self._partInstances) do
		local instance = self._partInstances[part]
		if instance then
			for key, value in pairs(newConfig) do
				if type(value) == "table" then
					for subKey, subValue in pairs(value) do
						instance.Config[key][subKey] = subValue
					end
				else
					instance.Config[key] = value
				end
			end
		end
	end
end

function TSESP:SetDefaultConfig(config)
	DefaultConfig = self:DeepCopy(config)
end

function TSESP:GetDefaultConfig()
	return self:DeepCopy(DefaultConfig)
end

function TSESP:DeepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = self:DeepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function TSESP:Enable()
	if self._renderStep then return end
	
	self._renderStep = RunService.RenderStepped:Connect(function()
		for _, instance in pairs(self._instances) do
			instance:Update()
		end

		for _, instance in pairs(self._partInstances) do
			instance:Update()
		end
	end)
	
	-- Player added/removed
	self._connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
		if player ~= LocalPlayer then
			self:AddPlayer(player)
		end
	end)
	
	self._connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
	end)
end

function TSESP:Disable()
	if self._renderStep then
		self._renderStep:Disconnect()
		self._renderStep = nil
	end
	
	for _, connection in pairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
	
	for _, instance in pairs(self._instances) do
		instance:SetVisible(false)
	end

	for _, instance in pairs(self._partInstances) do
		instance:SetVisible(false)
	end
end

function TSESP:Destroy()
	self:Disable()
	self:RemoveAllPlayers()
	self:RemoveAllParts()
end

-- Auto-initialization
function TSESP:Init(autoAdd)
	self:Enable()
	if autoAdd ~= false then
		self:AddAllPlayers()
	end
	return self
end

-- Export
return TSESP