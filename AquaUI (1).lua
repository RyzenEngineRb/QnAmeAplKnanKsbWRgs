--[[
    AquaUI v2 - водяная голубая UI-библиотека
    Подключение:
        local Aqua = loadstring(game:HttpGet("https://YOUR_HOST/AquaUI.lua"))()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Aqua = {}
Aqua.__index = Aqua

local THEME = {
	Deep = Color3.fromRGB(6, 70, 140),
	Mid = Color3.fromRGB(20, 130, 225),
	Light = Color3.fromRGB(110, 212, 255),
	Foam = Color3.fromRGB(215, 246, 255),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(205, 232, 250),
}

---------------------------------------------------------------------
-- Хелперы
---------------------------------------------------------------------
local function New(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local function Corner(parent, r)
	return New("UICorner", { CornerRadius = r or UDim.new(0, 10), Parent = parent })
end

local function Tween(obj, props, t, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad), props)
	tw:Play()
	return tw
end

-- анимируемые элементы (водяные слои, бегущие рамки, пульсации)
local waterLayers, spinners, ticks = {}, {}, {}

local WATER_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.Deep),
	ColorSequenceKeypoint.new(0.3, THEME.Mid),
	ColorSequenceKeypoint.new(0.55, THEME.Light),
	ColorSequenceKeypoint.new(0.8, THEME.Mid),
	ColorSequenceKeypoint.new(1, THEME.Deep),
})
local FOAM_COLORS = ColorSequence.new(THEME.Foam)
local FOAM_ALPHA = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0.88),
	NumberSequenceKeypoint.new(0.45, 0.62),
	NumberSequenceKeypoint.new(0.65, 0.9),
	NumberSequenceKeypoint.new(1, 1),
})
local STROKE_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.Foam),
	ColorSequenceKeypoint.new(0.35, THEME.Light),
	ColorSequenceKeypoint.new(0.6, THEME.Mid),
	ColorSequenceKeypoint.new(1, THEME.Foam),
})

-- «вода»: непрозрачная основа + два текущих слоя градиента
local function Water(frame, radius)
	frame.BackgroundColor3 = THEME.Deep
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0

	local function layer(colors, alpha, rot, speed, amp)
		local l = New("Frame", {
			Name = "WaterLayer",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Active = false,
			Parent = frame,
		})
		Corner(l, radius)
		local g = New("UIGradient", { Color = colors, Transparency = alpha, Rotation = rot, Parent = l })
		table.insert(waterLayers, { g = g, rot = rot, speed = speed, amp = amp, ph = math.random() * 6 })
	end
	layer(WATER_COLORS, NumberSequence.new(0), 28, 0.35, 0.55)
	layer(FOAM_COLORS, FOAM_ALPHA, -38, 0.55, 0.7)
end

-- бегущая светящаяся рамка
local function FlowStroke(parent, thickness)
	local s = New("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = thickness or 1.5,
		Transparency = 0.1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	local g = New("UIGradient", { Color = STROKE_COLORS, Parent = s })
	table.insert(spinners, { g = g, speed = 70 })
	return s
end

local function MakeDraggable(handle, target)
	local state = { moved = false }
	local dragging, startPos, startInput
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, state.moved = true, false
			startInput, startPos = input.Position, target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startInput
			if d.Magnitude > 6 then
				state.moved = true
			end
			if state.moved then
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	return state
end

local function GetParent()
	local ok, ui = pcall(function()
		return (gethui and gethui()) or CoreGui
	end)
	if ok and ui then
		return ui
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

---------------------------------------------------------------------
-- Watermark: ник | FPS | пинг | время
---------------------------------------------------------------------
local function CreateWatermark(gui, yOffset)
	local bar = New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, yOffset or 70),
		Size = UDim2.fromOffset(400, 36),
		Parent = gui,
	})
	Corner(bar, UDim.new(1, 0))
	Water(bar, UDim.new(1, 0))
	FlowStroke(bar, 1.5)

	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = THEME.Text,
		RichText = true,
		Text = "",
		Parent = bar,
	})
	MakeDraggable(bar, bar)

	local frames, last = 0, os.clock()
	table.insert(ticks, function()
		frames += 1
		local now = os.clock()
		if now - last >= 0.5 then
			local fps = math.floor(frames / (now - last))
			frames, last = 0, now
			local ping = 0
			pcall(function()
				ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
			end)
			label.Text = string.format(
				'<font color="#d7f6ff"><b>%s</b></font>  |  FPS %d  |  %d ms  |  %s',
				LocalPlayer.DisplayName, fps, ping, os.date("%H:%M:%S")
			)
		end
	end)
	return bar
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------
function Aqua:CreateWindow(opts)
	opts = opts or {}
	local self = setmetatable({ Tabs = {}, Scale = 1, Open = true }, Aqua)

	local gui = New("ScreenGui", {
		Name = "AquaUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = GetParent(),
	})
	self.Gui = gui

	-- общий цикл анимации
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for i = #waterLayers, 1, -1 do
			local w = waterLayers[i]
			if w.g.Parent then
				w.g.Offset = Vector2.new(math.sin(t * w.speed + w.ph) * w.amp, math.cos(t * w.speed * 0.7 + w.ph) * 0.25)
				w.g.Rotation = w.rot + math.sin(t * w.speed * 0.6 + w.ph) * 18
			else
				table.remove(waterLayers, i)
			end
		end
		for i = #spinners, 1, -1 do
			local s = spinners[i]
			if s.g.Parent then
				s.g.Rotation = (t * s.speed) % 360
			else
				table.remove(spinners, i)
			end
		end
		for _, f in ipairs(ticks) do
			f(t)
		end
	end)

	if opts.Watermark ~= false then
		CreateWatermark(gui, opts.WatermarkY)
	end

	-- главное окно
	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = opts.Size or UDim2.fromOffset(560, 360),
		Parent = gui,
	})
	Corner(main, UDim.new(0, 20))
	Water(main, UDim.new(0, 20))
	FlowStroke(main, 2)
	local uiScale = New("UIScale", { Scale = 1, Parent = main })
	self.Main = main

	local top = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = main,
	})
	MakeDraggable(top, main)

	-- маленькая «капля» рядом с заголовком
	local dropDot = New("Frame", {
		Position = UDim2.fromOffset(18, 17),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = THEME.Foam,
		Parent = top,
	})
	Corner(dropDot, UDim.new(1, 0))
	New("UIStroke", { Color = THEME.Light, Thickness = 2, Transparency = 0.2, Parent = dropDot })

	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -170, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Text,
		Text = opts.Title or "Aqua",
		Parent = top,
	})

	local function HeaderButton(text, xOffset)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.8,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = THEME.Text,
			Text = text,
			AutoButtonColor = false,
			Parent = top,
		})
		Corner(b, UDim.new(1, 0))
		New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6, Parent = b })
		b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = 0.55 }) end)
		b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 0.8 }) end)
		return b
	end

	function self:SetScale(s)
		self.Scale = math.clamp(s, 0.6, 1.6)
		Tween(uiScale, { Scale = self.Scale })
	end

	function self:SetOpen(state)
		self.Open = state
		if state then
			uiScale.Scale = self.Scale * 0.85
			main.Visible = true
			Tween(uiScale, { Scale = self.Scale }, 0.28, Enum.EasingStyle.Back)
		else
			Tween(uiScale, { Scale = self.Scale * 0.85 }, 0.16)
			task.delay(0.16, function()
				if not self.Open then
					main.Visible = false
				end
			end)
		end
	end

	HeaderButton("×", -12).MouseButton1Click:Connect(function() self:SetOpen(false) end)
	HeaderButton("+", -48).MouseButton1Click:Connect(function() self:SetScale(self.Scale + 0.1) end)
	HeaderButton("−", -84).MouseButton1Click:Connect(function() self:SetScale(self.Scale - 0.1) end)

	-- боковая панель вкладок
	local side = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 56),
		Size = UDim2.new(0, 130, 1, -72),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = main,
	}, { New("UIListLayout", { Padding = UDim.new(0, 8) }) })

	local pages = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(158, 56),
		Size = UDim2.new(1, -172, 1, -72),
		Parent = main,
	})

	-- уголок для растягивания
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Text = "◢",
		TextSize = 16,
		TextColor3 = THEME.Foam,
		Parent = main,
	})
	do
		local resizing, startPos, startSize
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing, startPos, startSize = true, input.Position, main.AbsoluteSize / uiScale.Scale
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then resizing = false end
				end)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local d = (input.Position - startPos) / uiScale.Scale
				main.Size = UDim2.fromOffset(math.max(420, startSize.X + d.X), math.max(280, startSize.Y + d.Y))
			end
		end)
	end

	-----------------------------------------------------------------
	-- Кнопка открытия: водяной шар с кольцом и пульсирующей точкой
	-----------------------------------------------------------------
	local toggle = New("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.38, 0),
		Size = UDim2.fromOffset(56, 56),
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	Corner(toggle, UDim.new(1, 0))
	Water(toggle, UDim.new(1, 0))
	FlowStroke(toggle, 2)

	local ring = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Parent = toggle,
	})
	Corner(ring, UDim.new(1, 0))
	New("UIStroke", { Color = THEME.Foam, Thickness = 2.5, Parent = ring })

	local dot = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = THEME.Foam,
		Parent = toggle,
	})
	Corner(dot, UDim.new(1, 0))

	table.insert(ticks, function(t)
		local k = (math.sin(t * 3) + 1) / 2
		dot.Size = UDim2.fromOffset(8 + 5 * k, 8 + 5 * k)
		ring.Size = UDim2.fromOffset(26 + 4 * k, 26 + 4 * k)
	end)

	local dragState = MakeDraggable(toggle, toggle)
	toggle.MouseButton1Click:Connect(function()
		if not dragState.moved then
			self:SetOpen(not self.Open)
		end
	end)
	toggle.MouseEnter:Connect(function() Tween(toggle, { Size = UDim2.fromOffset(62, 62) }) end)
	toggle.MouseLeave:Connect(function() Tween(toggle, { Size = UDim2.fromOffset(56, 56) }) end)

	if opts.ToggleKey then
		UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == opts.ToggleKey then self:SetOpen(not self.Open) end
		end)
	end

	-----------------------------------------------------------------
	-- Tabs
	-----------------------------------------------------------------
	function self:AddTab(name)
		local tab = {}
		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = THEME.SubText,
			Text = name,
			AutoButtonColor = false,
			Parent = side,
		})
		Corner(btn, UDim.new(0, 12))
		local btnStroke = New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 1, Parent = btn })

		local page = New("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.Foam,
			Visible = false,
			Parent = pages,
		}, { New("UIListLayout", { Padding = UDim.new(0, 10) }) })

		local function Select()
			for _, t in ipairs(self.Tabs) do
				t.Page.Visible = false
				Tween(t.Button, { BackgroundTransparency = 1, TextColor3 = THEME.SubText })
				Tween(t.Stroke, { Transparency = 1 })
			end
			page.Visible = true
			Tween(btn, { BackgroundTransparency = 0.75, TextColor3 = THEME.Text })
			Tween(btnStroke, { Transparency = 0.45 })
		end
		btn.MouseButton1Click:Connect(Select)
		tab.Page, tab.Button, tab.Stroke = page, btn, btnStroke
		table.insert(self.Tabs, tab)
		if #self.Tabs == 1 then Select() end

		local function Row(h)
			local r = New("Frame", {
				Size = UDim2.new(1, -6, 0, h or 42),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.88,
				Parent = page,
			})
			Corner(r, UDim.new(0, 12))
			New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.65, Parent = r })
			return r
		end
		local function RowLabel(parent, text)
			return New("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -80, 1, 0),
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = THEME.Text,
				Text = text,
				Parent = parent,
			})
		end

		function tab:AddLabel(text)
			local r = Row(30)
			RowLabel(r, text).Size = UDim2.new(1, -28, 1, 0)
		end

		function tab:AddButton(text, callback)
			local r = Row()
			local b = New("TextButton", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = THEME.Text,
				Text = text,
				Parent = r,
			})
			b.MouseEnter:Connect(function() Tween(r, { BackgroundTransparency = 0.8 }) end)
			b.MouseLeave:Connect(function() Tween(r, { BackgroundTransparency = 0.88 }) end)
			b.MouseButton1Click:Connect(function()
				Tween(r, { BackgroundTransparency = 0.6 }, 0.08)
				task.delay(0.1, function() Tween(r, { BackgroundTransparency = 0.88 }) end)
				if callback then task.spawn(callback) end
			end)
		end

		function tab:AddToggle(text, default, callback)
			local r = Row()
			RowLabel(r, text)
			local state = default and true or false
			local OFF, ON = Color3.fromRGB(8, 45, 95), THEME.Light
			local track = New("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(44, 24),
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = state and ON or OFF,
				Parent = r,
			})
			Corner(track, UDim.new(1, 0))
			New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6, Parent = track })
			local knob = New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, state and 23 or 3, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = track,
			})
			Corner(knob, UDim.new(1, 0))
			track.MouseButton1Click:Connect(function()
				state = not state
				Tween(track, { BackgroundColor3 = state and ON or OFF })
				Tween(knob, { Position = UDim2.new(0, state and 23 or 3, 0.5, 0) }, 0.2, Enum.EasingStyle.Back)
				if callback then task.spawn(callback, state) end
			end)
		end

		function tab:AddSlider(text, min, max, default, callback)
			local r = Row(58)
			local lbl = RowLabel(r, text)
			lbl.Position = UDim2.fromOffset(14, -10)
			local valueLabel = New("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 8),
				Size = UDim2.fromOffset(60, 20),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextColor3 = THEME.Foam,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = r,
			})
			local bar = New("TextButton", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -12),
				Size = UDim2.new(1, -28, 0, 8),
				BackgroundColor3 = Color3.fromRGB(8, 45, 95),
				Text = "",
				AutoButtonColor = false,
				Parent = r,
			})
			Corner(bar, UDim.new(1, 0))
			local fill = New("Frame", { BackgroundColor3 = THEME.Light, Size = UDim2.fromScale(0, 1), Parent = bar })
			Corner(fill, UDim.new(1, 0))
			New("UIGradient", { Color = ColorSequence.new(THEME.Mid, THEME.Foam), Parent = fill })

			local function Set(v)
				v = math.clamp(math.floor(v + 0.5), min, max)
				fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
				valueLabel.Text = tostring(v)
				return v
			end
			Set(default or min)

			local sliding = false
			local function Update(x)
				local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
				local v = Set(min + (max - min) * rel)
				if callback then task.spawn(callback, v) end
			end
			bar.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					Update(i.Position.X)
				end
			end)
			UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					sliding = false
				end
			end)
			UserInputService.InputChanged:Connect(function(i)
				if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
					Update(i.Position.X)
				end
			end)
		end

		return tab
	end

	function self:Destroy()
		conn:Disconnect()
		gui:Destroy()
	end

	return self
end

return setmetatable({}, { __index = Aqua })
