--[[
    AquaUI v3 - чёрная UI-библиотека с водяной ватермаркой
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
	BG = Color3.fromRGB(13, 13, 16),
	Panel = Color3.fromRGB(20, 20, 24),
	Row = Color3.fromRGB(27, 27, 32),
	Line = Color3.fromRGB(46, 46, 54),
	Text = Color3.fromRGB(245, 245, 248),
	Sub = Color3.fromRGB(140, 140, 152),
	Accent = Color3.fromRGB(90, 190, 255),
	Off = Color3.fromRGB(44, 44, 52),
	-- вода
	Deep = Color3.fromRGB(6, 70, 140),
	Mid = Color3.fromRGB(20, 130, 225),
	Light = Color3.fromRGB(110, 212, 255),
	Foam = Color3.fromRGB(215, 246, 255),
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

local function Stroke(parent, color, transparency, thickness)
	return New("UIStroke", {
		Color = color or THEME.Line,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function Tween(obj, props, t, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad), props)
	tw:Play()
	return tw
end

local function Icon(parent, id, size, color, pos)
	if not id then return nil end
	return New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = type(id) == "number" and ("rbxassetid://" .. id) or id,
		ImageColor3 = color or THEME.Sub,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = pos or UDim2.new(0, 0, 0.5, 0),
		Parent = parent,
	})
end

-- анимируемые элементы
local waterLayers, spinners, ticks = {}, {}, {}

local WATER_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.Deep),
	ColorSequenceKeypoint.new(0.3, THEME.Mid),
	ColorSequenceKeypoint.new(0.55, THEME.Light),
	ColorSequenceKeypoint.new(0.8, THEME.Mid),
	ColorSequenceKeypoint.new(1, THEME.Deep),
})
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
			Parent = frame,
		})
		Corner(l, radius)
		local g = New("UIGradient", { Color = colors, Transparency = alpha, Rotation = rot, Parent = l })
		table.insert(waterLayers, { g = g, rot = rot, speed = speed, amp = amp, ph = math.random() * 6 })
	end
	layer(WATER_COLORS, NumberSequence.new(0), 28, 0.35, 0.55)
	layer(ColorSequence.new(THEME.Foam), FOAM_ALPHA, -38, 0.55, 0.7)
end

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

local function Pointer(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

---------------------------------------------------------------------
-- Ватермарка: отдельные капсулы (ник / FPS / пинг / время)
---------------------------------------------------------------------
local function CreateWatermark(gui, yOffset)
	local bar = New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, yOffset or 70),
		Size = UDim2.fromOffset(250, 30),
		Parent = gui,
	})
	Corner(bar, UDim.new(1, 0))
	Water(bar, UDim.new(1, 0))
	FlowStroke(bar, 1.2)

	local content = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = bar,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local function Chip(order, color)
		local c = New("Frame", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.42,
			LayoutOrder = order,
			Parent = content,
		})
		Corner(c, UDim.new(1, 0))
		local l = New("TextLabel", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = color or THEME.Text,
			Text = "...",
			Parent = c,
		})
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = l })
		return l
	end

	local nameL = Chip(1, THEME.Foam)
	local fpsL = Chip(2)
	local pingL = Chip(3)
	local timeL = Chip(4)
	nameL.Text = LocalPlayer.DisplayName
	nameL.Font = Enum.Font.GothamBold

	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		bar.Size = UDim2.fromOffset(content.AbsoluteSize.X + 10, 30)
	end)
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
			fpsL.Text = "FPS " .. fps
			pingL.Text = ping .. " ms"
			timeL.Text = os.date("%H:%M:%S")
		end
	end)
	return bar
end

---------------------------------------------------------------------
-- Элементы (общие для карточек и групп)
---------------------------------------------------------------------
local function Elements(container, win)
	local E = {}
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function Row(h)
		local r = New("Frame", {
			Size = UDim2.new(1, 0, 0, h or 40),
			BackgroundColor3 = THEME.Row,
			LayoutOrder = nextOrder(),
			Parent = container,
		})
		Corner(r, UDim.new(0, 10))
		Stroke(r, THEME.Line, 0.35)
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

	local function Register(row, text)
		table.insert(win._search, { row = row, text = tostring(text):lower() })
	end

	function E:AddLabel(text)
		local r = Row(30)
		RowLabel(r, text).Size = UDim2.new(1, -28, 1, 0)
		Register(r, text)
	end

	function E:AddButton(text, callback)
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
		b.MouseEnter:Connect(function() Tween(r, { BackgroundColor3 = Color3.fromRGB(36, 36, 43) }) end)
		b.MouseLeave:Connect(function() Tween(r, { BackgroundColor3 = THEME.Row }) end)
		b.MouseButton1Click:Connect(function()
			Tween(r, { BackgroundColor3 = THEME.Accent }, 0.08)
			task.delay(0.12, function() Tween(r, { BackgroundColor3 = THEME.Row }, 0.25) end)
			if callback then task.spawn(callback) end
		end)
		Register(r, text)
	end

	function E:AddToggle(text, default, callback)
		local r = Row()
		RowLabel(r, text)
		local state = default and true or false
		local track = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(46, 24),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = state and THEME.Accent or THEME.Off,
			Parent = r,
		})
		Corner(track, UDim.new(1, 0))
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, state and 25 or 3, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = track,
		})
		Corner(knob, UDim.new(1, 0))
		local obj = {}
		function obj:Set(v, silent)
			state = v and true or false
			Tween(track, { BackgroundColor3 = state and THEME.Accent or THEME.Off })
			Tween(knob, { Position = UDim2.new(0, state and 25 or 3, 0.5, 0) }, 0.2, Enum.EasingStyle.Back)
			if callback and not silent then task.spawn(callback, state) end
		end
		function obj:Get() return state end
		track.MouseButton1Click:Connect(function() obj:Set(not state) end)
		Register(r, text)
		return obj
	end

	function E:AddSlider(text, min, max, default, callback, suffix)
		local r = Row(58)
		local lbl = RowLabel(r, text)
		lbl.Position = UDim2.fromOffset(14, -10)
		local valueLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 9),
			Size = UDim2.fromOffset(70, 20),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = THEME.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
		local bar = New("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -28, 0, 6),
			BackgroundColor3 = THEME.Off,
			Text = "",
			AutoButtonColor = false,
			Parent = r,
		})
		Corner(bar, UDim.new(1, 0))
		local fill = New("Frame", { BackgroundColor3 = THEME.Accent, Size = UDim2.fromScale(0, 1), Parent = bar })
		Corner(fill, UDim.new(1, 0))
		local value = default or min
		local function Set(v)
			value = math.clamp(math.floor(v + 0.5), min, max)
			fill.Size = UDim2.fromScale((value - min) / (max - min), 1)
			valueLabel.Text = tostring(value) .. (suffix or "")
		end
		Set(value)
		local sliding = false
		local function Update(x)
			local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			Set(min + (max - min) * rel)
			if callback then task.spawn(callback, value) end
		end
		bar.InputBegan:Connect(function(i)
			if Pointer(i) then sliding = true Update(i.Position.X) end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if Pointer(i) then sliding = false end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				Update(i.Position.X)
			end
		end)
		Register(r, text)
		return { Set = Set, Get = function() return value end }
	end

	function E:AddDropdown(text, options, default, callback)
		local r = Row(40)
		r.ClipsDescendants = true
		local head = New("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			Text = "",
			Parent = r,
		})
		RowLabel(head, text)
		local cur = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(130, 20),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = THEME.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(default or options[1]),
			Parent = head,
		})
		local open = false
		local function Select(v)
			cur.Text = tostring(v)
			if callback then task.spawn(callback, v) end
		end
		for i, opt in ipairs(options) do
			local ob = New("TextButton", {
				Position = UDim2.new(0, 8, 0, 40 + (i - 1) * 30),
				Size = UDim2.new(1, -16, 0, 28),
				BackgroundColor3 = THEME.Panel,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextColor3 = THEME.Text,
				Text = tostring(opt),
				AutoButtonColor = false,
				Parent = r,
			})
			Corner(ob, UDim.new(0, 8))
			ob.MouseButton1Click:Connect(function()
				Select(opt)
				open = false
				Tween(r, { Size = UDim2.new(1, 0, 0, 40) })
			end)
		end
		head.MouseButton1Click:Connect(function()
			open = not open
			Tween(r, { Size = UDim2.new(1, 0, 0, open and (46 + #options * 30) or 40) })
		end)
		Register(r, text)
	end

	-- сворачиваемая группа (как «Options» на скриншоте)
	function E:AddGroup(title, startOpen)
		local g = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = container,
		}, { New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local head = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = 0,
			Parent = g,
		})
		New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -30, 1, 0),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text,
			Text = title,
			Parent = head,
		})
		local sign = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = THEME.Sub,
			Text = startOpen == false and "+" or "−",
			Parent = head,
		})
		local body = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Visible = startOpen ~= false,
			Parent = g,
		}, { New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		head.MouseButton1Click:Connect(function()
			body.Visible = not body.Visible
			sign.Text = body.Visible and "−" or "+"
		end)
		return Elements(body, win)
	end

	return E
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------
function Aqua:CreateWindow(opts)
	opts = opts or {}
	local win = setmetatable({ Pages = {}, Scale = 1, Open = true, Minimized = false, _search = {} }, Aqua)

	local gui = New("ScreenGui", {
		Name = "AquaUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = GetParent(),
	})
	win.Gui = gui

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
		Size = opts.Size or UDim2.fromOffset(640, 400),
		BackgroundColor3 = THEME.BG,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Corner(main, UDim.new(0, 16))
	Stroke(main, THEME.Line, 0.1)
	New("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(24, 24, 30), Color3.fromRGB(10, 10, 12)),
		Rotation = 70,
		Parent = main,
	})
	local uiScale = New("UIScale", { Scale = 1, Parent = main })
	win.Main = main

	-- шапка
	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = main })
	MakeDraggable(top, main)
	New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = top })

	local titleBox = New("Frame", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local ord = 0
	local function TitlePart(text, bold, color)
		ord += 1
		if ord > 1 then
			New("Frame", { Size = UDim2.fromOffset(1, 16), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, LayoutOrder = ord, Parent = titleBox })
			ord += 1
		end
		New("TextLabel", {
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
			TextSize = 15,
			TextColor3 = color or THEME.Text,
			Text = text,
			LayoutOrder = ord,
			Parent = titleBox,
		})
	end
	TitlePart(opts.Title or "Aqua", true)
	if opts.Subtitle then TitlePart(opts.Subtitle, false, THEME.Sub) end
	if opts.Version then TitlePart(opts.Version, false, THEME.Sub) end

	local function HeaderButton(xOffset)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = THEME.Row,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = top,
		})
		Corner(b, UDim.new(0, 8))
		b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = 0 }) end)
		b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 1 }) end)
		return b
	end
	local function BtnText(b, text)
		New("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = THEME.Text,
			Text = text,
			Parent = b,
		})
	end

	local closeB = HeaderButton(-12)
	BtnText(closeB, "×")
	local minB = HeaderButton(-46)
	BtnText(minB, "−")
	local searchB = HeaderButton(-80)
	-- иконка поиска из фигур
	local sRing = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -2, 0.5, -2),
		Size = UDim2.fromOffset(13, 13),
		BackgroundTransparency = 1,
		Parent = searchB,
	})
	Corner(sRing, UDim.new(1, 0))
	Stroke(sRing, THEME.Text, 0, 2)
	New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 6, 0.5, 6),
		Size = UDim2.fromOffset(7, 2),
		Rotation = 45,
		BackgroundColor3 = THEME.Text,
		BorderSizePixel = 0,
		Parent = searchB,
	})

	local searchBox = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -118, 0.5, 0),
		Size = UDim2.fromOffset(170, 28),
		BackgroundColor3 = THEME.Row,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = THEME.Text,
		PlaceholderText = "Поиск...",
		PlaceholderColor3 = THEME.Sub,
		Text = "",
		ClearTextOnFocus = false,
		Visible = false,
		Parent = top,
	})
	Corner(searchBox, UDim.new(0, 8))
	Stroke(searchBox, THEME.Line, 0)
	searchB.MouseButton1Click:Connect(function()
		searchBox.Visible = not searchBox.Visible
		if searchBox.Visible then searchBox:CaptureFocus() else searchBox.Text = "" end
	end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = searchBox.Text:lower()
		for _, s in ipairs(win._search) do
			if s.row.Parent then
				s.row.Visible = (q == "" or s.text:find(q, 1, true) ~= nil)
			end
		end
	end)

	-- тело окна
	local body = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		Parent = main,
	})

	-- боковая панель
	local side = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 160, 1, 0), Parent = body })
	New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = side })

	local sideTop = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Parent = side })
	if opts.Badge then
		sideTop.Size = UDim2.new(1, 0, 0, 62)
		New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -24, 0, 22),
			Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text, Text = opts.Badge, Parent = sideTop,
		})
		New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -24, 0, 18),
			Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = opts.BadgeSub or "", Parent = sideTop,
		})
		New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = sideTop })
	end

	local pageList = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, sideTop.Size.Y.Offset + 8),
		Size = UDim2.new(1, -17, 1, -(sideTop.Size.Y.Offset + 16)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = side,
	}, { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local pagesHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(172, 0),
		Size = UDim2.new(1, -184, 1, 0),
		Parent = body,
	})

	-- уголок растягивания
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Text = "◢",
		TextSize = 15,
		TextColor3 = THEME.Sub,
		ZIndex = 5,
		Parent = main,
	})
	do
		local resizing, startPos, startSize
		grip.InputBegan:Connect(function(input)
			if Pointer(input) then
				resizing, startPos, startSize = true, input.Position, main.AbsoluteSize / uiScale.Scale
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then resizing = false end
				end)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local d = (input.Position - startPos) / uiScale.Scale
				main.Size = UDim2.fromOffset(math.max(480, startSize.X + d.X), math.max(300, startSize.Y + d.Y))
			end
		end)
	end

	-----------------------------------------------------------------
	-- Управление окном
	-----------------------------------------------------------------
	function win:SetScale(s)
		win.Scale = math.clamp(s, 0.6, 1.6)
		Tween(uiScale, { Scale = win.Scale })
	end

	function win:SetOpen(state)
		win.Open = state
		if state then
			uiScale.Scale = win.Scale * 0.88
			main.Visible = true
			Tween(uiScale, { Scale = win.Scale }, 0.28, Enum.EasingStyle.Back)
		else
			Tween(uiScale, { Scale = win.Scale * 0.88 }, 0.16)
			task.delay(0.16, function()
				if not win.Open then main.Visible = false end
			end)
		end
	end

	function win:SetMinimized(state)
		win.Minimized = state
		grip.Visible = not state
		if state then
			win._full = main.Size
			body.Visible = false
			Tween(main, { Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 50) }, 0.2)
		else
			Tween(main, { Size = win._full or UDim2.fromOffset(640, 400) }, 0.2)
			task.delay(0.12, function() body.Visible = not win.Minimized end)
		end
	end

	closeB.MouseButton1Click:Connect(function() win:SetOpen(false) end)
	minB.MouseButton1Click:Connect(function() win:SetMinimized(not win.Minimized) end)

	-----------------------------------------------------------------
	-- Кнопка открытия (водяной шар)
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
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Parent = toggle,
	})
	Corner(ring, UDim.new(1, 0))
	Stroke(ring, THEME.Foam, 0, 2.5)
	local dot = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10), BackgroundColor3 = THEME.Foam, Parent = toggle,
	})
	Corner(dot, UDim.new(1, 0))
	table.insert(ticks, function(t)
		local k = (math.sin(t * 3) + 1) / 2
		dot.Size = UDim2.fromOffset(8 + 5 * k, 8 + 5 * k)
		ring.Size = UDim2.fromOffset(26 + 4 * k, 26 + 4 * k)
	end)
	local dragState = MakeDraggable(toggle, toggle)
	toggle.MouseButton1Click:Connect(function()
		if not dragState.moved then win:SetOpen(not win.Open) end
	end)
	toggle.MouseEnter:Connect(function() Tween(toggle, { Size = UDim2.fromOffset(62, 62) }) end)
	toggle.MouseLeave:Connect(function() Tween(toggle, { Size = UDim2.fromOffset(56, 56) }) end)
	if opts.ToggleKey then
		UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == opts.ToggleKey then win:SetOpen(not win.Open) end
		end)
	end

	-----------------------------------------------------------------
	-- Страницы (боковая панель) -> вкладки (сверху) -> карточки
	-----------------------------------------------------------------
	function win:AddPage(name, iconId)
		local page = { Tabs = {} }

		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = THEME.Row,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = #win.Pages + 1,
			Parent = pageList,
		})
		Corner(btn, UDim.new(0, 10))
		local indicator = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 18), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0,
			Visible = false, Parent = btn,
		})
		Corner(indicator, UDim.new(1, 0))
		Icon(btn, iconId, 18, THEME.Sub, UDim2.new(0, 14, 0.5, 0))
		local label = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(iconId and 40 or 16, 0),
			Size = UDim2.new(1, -(iconId and 46 or 22), 1, 0),
			Font = Enum.Font.GothamMedium, TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = name, Parent = btn,
		})

		local frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pagesHolder })
		local tabBar = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = frame }, {
			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 22),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			New("UIPadding", { PaddingLeft = UDim.new(0, 6) }),
		})
		local tabArea = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			Parent = frame,
		})
		New("Frame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = frame })

		local function SelectPage()
			for _, p in ipairs(win.Pages) do
				p.Frame.Visible = false
				p.Indicator.Visible = false
				Tween(p.Button, { BackgroundTransparency = 1 })
				Tween(p.Label, { TextColor3 = THEME.Sub })
			end
			frame.Visible = true
			indicator.Visible = true
			Tween(btn, { BackgroundTransparency = 0 })
			Tween(label, { TextColor3 = THEME.Text })
		end
		btn.MouseButton1Click:Connect(SelectPage)
		page.Frame, page.Button, page.Indicator, page.Label = frame, btn, indicator, label
		table.insert(win.Pages, page)
		if #win.Pages == 1 then SelectPage() end

		function page:AddTab(tabName, tabIcon)
			local tab = { _l = 0, _r = 0 }

			local tbtn = New("TextButton", {
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
				TextColor3 = THEME.Sub,
				Text = tabName,
				LayoutOrder = #page.Tabs + 1,
				Parent = tabBar,
			})
			New("UIPadding", { PaddingLeft = UDim.new(0, tabIcon and 24 or 2), PaddingRight = UDim.new(0, 2), Parent = tbtn })
			Icon(tbtn, tabIcon, 16, THEME.Sub, UDim2.new(0, -22, 0.5, 0))
			local underline = New("Frame", {
				AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0,
				Visible = false, Parent = tbtn,
			})

			local scroll = New("ScrollingFrame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = THEME.Line,
				Visible = false,
				Parent = tabArea,
			})
			local function Column(x, offset)
				return New("Frame", {
					Position = UDim2.new(x, offset, 0, 0),
					Size = UDim2.new(0.5, -6, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Parent = scroll,
				}, { New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
			end
			tab.Left, tab.Right = Column(0, 0), Column(0.5, 6)
			tab._order = 0

			local function SelectTab()
				for _, t in ipairs(page.Tabs) do
					t.Scroll.Visible = false
					t.Underline.Visible = false
					Tween(t.Button, { TextColor3 = THEME.Sub })
				end
				scroll.Visible = true
				underline.Visible = true
				Tween(tbtn, { TextColor3 = THEME.Text })
			end
			tbtn.MouseButton1Click:Connect(SelectTab)
			tab.Scroll, tab.Button, tab.Underline = scroll, tbtn, underline
			table.insert(page.Tabs, tab)
			if #page.Tabs == 1 then SelectTab() end

			function tab:AddCard(title, cardIcon, side)
				local useRight = (side == "Right") or (side == nil and tab._l > tab._r)
				local col = useRight and tab.Right or tab.Left
				if useRight then tab._r += 1 else tab._l += 1 end
				tab._order += 1

				local card = New("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = THEME.Panel,
					LayoutOrder = tab._order,
					Parent = col,
				})
				Corner(card, UDim.new(0, 14))
				Stroke(card, THEME.Line, 0.2)
				New("UIPadding", {
					PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
					PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = card,
				})
				New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

				local head = New("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
				Icon(head, cardIcon, 18, THEME.Text, UDim2.new(0, 0, 0.5, 0))
				New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(cardIcon and 26 or 0, 0),
					Size = UDim2.new(1, -(cardIcon and 26 or 0), 1, 0),
					Font = Enum.Font.GothamBold, TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = THEME.Text, Text = title, Parent = head,
				})
				return Elements(card, win)
			end

			return tab
		end

		return page
	end

	function win:Destroy()
		conn:Disconnect()
		gui:Destroy()
	end

	return win
end

return setmetatable({}, { __index = Aqua })
