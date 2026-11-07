--[[
    AquaUI v4 - компактная чёрная UI-библиотека (монохром) + водяная ватермарка
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
	BG = Color3.fromRGB(16, 16, 16),
	Panel = Color3.fromRGB(19, 19, 19),
	Row = Color3.fromRGB(23, 23, 23),
	Hover = Color3.fromRGB(32, 32, 32),
	Select = Color3.fromRGB(30, 30, 30),
	Line = Color3.fromRGB(44, 44, 44),
	Text = Color3.fromRGB(240, 240, 240),
	Sub = Color3.fromRGB(128, 128, 128),
	Accent = Color3.fromRGB(236, 236, 236),
	Off = Color3.fromRGB(38, 38, 38),
	-- вода (ватермарка)
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

local function Pointer(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

-- нарисованная палочка (из неё делаются иконки)
local function Bar(parent, w, h, rot, pos, color, anchor)
	local f = New("Frame", {
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		Rotation = rot or 0,
		BackgroundColor3 = color or THEME.Text,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Corner(f, UDim.new(1, 0))
	return f
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

-- шеврон "^" (повернуть на 180 = "v")
local function Chevron(parent, color)
	local c = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Bar(c, 8, 2, -45, UDim2.new(0.5, -3, 0.5, 0), color or THEME.Sub)
	Bar(c, 8, 2, 45, UDim2.new(0.5, 3, 0.5, 0), color or THEME.Sub)
	return c
end

-- анимируемые элементы (вода ватермарки)
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
		Thickness = thickness or 1.2,
		Transparency = 0.1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	local g = New("UIGradient", { Color = STROKE_COLORS, Parent = s })
	table.insert(spinners, { g = g, speed = 70 })
end

local function MakeDraggable(handle, target)
	local state = { moved = false }
	local dragging, startPos, startInput
	handle.InputBegan:Connect(function(input)
		if Pointer(input) then
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

-- полумесяц (логотип)
local function Moon(parent, size, bgColor, pos)
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local a = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Text, BorderSizePixel = 0, Parent = holder })
	Corner(a, UDim.new(1, 0))
	local b = New("Frame", {
		Position = UDim2.fromScale(0.28, -0.12),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Corner(b, UDim.new(1, 0))
	return holder
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
			Size = UDim2.new(1, 0, 0, h or 36),
			BackgroundColor3 = THEME.Row,
			LayoutOrder = nextOrder(),
			Parent = container,
		})
		Corner(r, UDim.new(0, 10))
		Stroke(r, THEME.Line, 0)
		return r
	end

	local function RowLabel(parent, text)
		return New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -70, 1, 0),
			Font = Enum.Font.Gotham,
			TextSize = 13,
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
		RowLabel(r, text).Size = UDim2.new(1, -24, 1, 0)
		Register(r, text)
	end

	function E:AddButton(text, callback)
		local r = Row()
		local b = New("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = THEME.Text,
			Text = text,
			Parent = r,
		})
		b.MouseEnter:Connect(function() Tween(r, { BackgroundColor3 = THEME.Hover }) end)
		b.MouseLeave:Connect(function() Tween(r, { BackgroundColor3 = THEME.Row }) end)
		b.MouseButton1Click:Connect(function()
			Tween(r, { BackgroundColor3 = Color3.fromRGB(70, 70, 70) }, 0.07)
			task.delay(0.1, function() Tween(r, { BackgroundColor3 = THEME.Hover }, 0.2) end)
			if callback then task.spawn(callback) end
		end)
		Register(r, text)
	end

	-- включено: светлая дорожка + тёмный кружок; выключено: тёмная дорожка + белый кружок
	function E:AddToggle(text, default, callback)
		local r = Row()
		RowLabel(r, text)
		local state = default and true or false
		local track = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(40, 22),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = state and THEME.Accent or THEME.Off,
			Parent = r,
		})
		Corner(track, UDim.new(1, 0))
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, state and 21 or 3, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = state and Color3.fromRGB(22, 22, 22) or Color3.new(1, 1, 1),
			Parent = track,
		})
		Corner(knob, UDim.new(1, 0))
		local obj = {}
		function obj:Set(v, silent)
			state = v and true or false
			Tween(track, { BackgroundColor3 = state and THEME.Accent or THEME.Off })
			Tween(knob, {
				Position = UDim2.new(0, state and 21 or 3, 0.5, 0),
				BackgroundColor3 = state and Color3.fromRGB(22, 22, 22) or Color3.new(1, 1, 1),
			}, 0.2)
			if callback and not silent then task.spawn(callback, state) end
		end
		function obj:Get() return state end
		track.MouseButton1Click:Connect(function() obj:Set(not state) end)
		Register(r, text)
		return obj
	end

	function E:AddSlider(text, min, max, default, callback, suffix)
		local r = Row(50)
		local lbl = RowLabel(r, text)
		lbl.Position = UDim2.fromOffset(12, -8)
		local valueLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 8),
			Size = UDim2.fromOffset(70, 18),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = THEME.Sub,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
		local bar = New("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0, 5),
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
		local r = Row(36)
		r.ClipsDescendants = true
		local head = New("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 36),
			Text = "",
			Parent = r,
		})
		RowLabel(head, text)
		local cur = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 20),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = THEME.Sub,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(default or options[1]),
			Parent = head,
		})
		local open = false
		for i, opt in ipairs(options) do
			local ob = New("TextButton", {
				Position = UDim2.new(0, 6, 0, 38 + (i - 1) * 28),
				Size = UDim2.new(1, -12, 0, 26),
				BackgroundColor3 = THEME.Panel,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = THEME.Text,
				Text = tostring(opt),
				AutoButtonColor = false,
				Parent = r,
			})
			Corner(ob, UDim.new(0, 8))
			ob.MouseButton1Click:Connect(function()
				cur.Text = tostring(opt)
				open = false
				Tween(r, { Size = UDim2.new(1, 0, 0, 36) })
				if callback then task.spawn(callback, opt) end
			end)
		end
		head.MouseButton1Click:Connect(function()
			open = not open
			Tween(r, { Size = UDim2.new(1, 0, 0, open and (44 + #options * 28) or 36) })
		end)
		Register(r, text)
	end

	-- цепочка статусов: AddSteps({ {"Готово"}, {"Casting", iconId}, ... })
	function E:AddSteps(steps)
		local holder = New("Frame", {
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = container,
		}, {
			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local circles, n = {}, 0
		for i, st in ipairs(steps) do
			n += 1
			local col = New("Frame", { Size = UDim2.fromOffset(64, 74), BackgroundTransparency = 1, LayoutOrder = n, Parent = holder })
			local circle = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.fromOffset(38, 38),
				BackgroundColor3 = THEME.Row,
				Parent = col,
			})
			Corner(circle, UDim.new(1, 0))
			local cs = Stroke(circle, THEME.Line, 0)
			local ic
			if st[2] then
				ic = Icon(circle, st[2], 18, THEME.Sub, UDim2.new(0.5, -9, 0.5, 0))
			else
				ic = New("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Parent = circle,
				})
				Corner(ic, UDim.new(1, 0))
				Stroke(ic, THEME.Sub, 0, 2)
			end
			local lb = New("TextLabel", {
				Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
				TextColor3 = THEME.Sub, Text = st[1], Parent = col,
			})
			circles[i] = { stroke = cs, label = lb, icon = ic }
			if i < #steps then
				n += 1
				local dash = New("Frame", { Size = UDim2.fromOffset(8, 74), BackgroundTransparency = 1, LayoutOrder = n, Parent = holder })
				Bar(dash, 6, 2, 0, UDim2.new(0.5, 0, 0, 19), THEME.Line)
			end
		end
		local obj = {}
		function obj:SetActive(idx)
			for i, c in ipairs(circles) do
				local on = (i == idx)
				Tween(c.stroke, { Color = on and THEME.Text or THEME.Line })
				Tween(c.label, { TextColor3 = on and THEME.Text or THEME.Sub })
			end
		end
		return obj
	end

	-- сворачиваемая группа (как «Options»)
	function E:AddGroup(title, groupIcon, startOpen)
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
		Icon(head, groupIcon, 16, THEME.Text, UDim2.new(0, 0, 0.5, 0))
		New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(groupIcon and 24 or 0, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text,
			Text = title,
			Parent = head,
		})
		local chev = Chevron(head)
		chev.Rotation = (startOpen == false) and 180 or 0
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
			Tween(chev, { Rotation = body.Visible and 0 or 180 })
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
	local win = setmetatable({ Pages = {}, Scale = 1, Open = true, Minimized = false, Collapsed = false, _search = {} }, Aqua)

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

	-- размер и автоподгонка под экран
	local size = opts.Size or UDim2.fromOffset(540, 330)
	do
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		if opts.AutoScale ~= false then
			win.Scale = math.clamp(math.min(vp.X * 0.85 / size.X.Offset, vp.Y * 0.85 / size.Y.Offset, 1), 0.5, 1)
		end
	end

	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = size,
		BackgroundColor3 = THEME.BG,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Corner(main, UDim.new(0, 14))
	Stroke(main, THEME.Line, 0)
	local uiScale = New("UIScale", { Scale = win.Scale, Parent = main })
	win.Main = main

	-- шапка
	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = main })
	MakeDraggable(top, main)
	New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = top })

	local titleBox = New("Frame", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 9),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local logoHolder = New("Frame", { Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, LayoutOrder = 0, Parent = titleBox })
	Moon(logoHolder, 16, THEME.BG)
	local ord = 0
	local function TitlePart(text, color)
		ord += 1
		if ord > 1 then
			New("Frame", { Size = UDim2.fromOffset(1, 14), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, LayoutOrder = ord * 2 - 1, Parent = titleBox })
		end
		New("TextLabel", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = color or THEME.Text,
			Text = text,
			LayoutOrder = ord * 2,
			Parent = titleBox,
		})
	end
	TitlePart(opts.Title or "Aqua")
	if opts.Subtitle then TitlePart(opts.Subtitle) end
	if opts.Version then TitlePart(opts.Version) end

	local function HeaderButton(xOffset)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = THEME.Hover,
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

	-- закрыть (X)
	local closeB = HeaderButton(-10)
	Bar(closeB, 14, 2, 45, nil, THEME.Sub)
	Bar(closeB, 14, 2, -45, nil, THEME.Sub)

	-- свернуть (четыре уголка внутрь)
	local minB = HeaderButton(-42)
	do
		local box = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Parent = minB })
		local function L(ax, ay)
			local p = UDim2.fromScale(ax, ay)
			Bar(box, 6, 2, 0, p, THEME.Sub, Vector2.new(ax, ay))
			Bar(box, 2, 6, 0, p, THEME.Sub, Vector2.new(ax, ay))
		end
		-- уголки смотрят внутрь: рисуем у центра
		Bar(box, 6, 2, 0, UDim2.fromOffset(0, 5), THEME.Sub, Vector2.new(0, 0.5))
		Bar(box, 2, 6, 0, UDim2.fromOffset(5, 0), THEME.Sub, Vector2.new(0.5, 0))
		Bar(box, 6, 2, 0, UDim2.new(1, 0, 0, 5), THEME.Sub, Vector2.new(1, 0.5))
		Bar(box, 2, 6, 0, UDim2.new(1, -5, 0, 0), THEME.Sub, Vector2.new(0.5, 0))
		Bar(box, 6, 2, 0, UDim2.new(0, 0, 1, -5), THEME.Sub, Vector2.new(0, 0.5))
		Bar(box, 2, 6, 0, UDim2.new(0, 5, 1, 0), THEME.Sub, Vector2.new(0.5, 1))
		Bar(box, 6, 2, 0, UDim2.new(1, 0, 1, -5), THEME.Sub, Vector2.new(1, 0.5))
		Bar(box, 2, 6, 0, UDim2.new(1, -5, 1, 0), THEME.Sub, Vector2.new(0.5, 1))
	end

	-- поиск (лупа)
	local searchB = HeaderButton(-74)
	do
		local ring = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -2, 0.5, -2),
			Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = searchB,
		})
		Corner(ring, UDim.new(1, 0))
		Stroke(ring, THEME.Sub, 0, 2)
		Bar(searchB, 6, 2, 45, UDim2.new(0.5, 6, 0.5, 6), THEME.Sub)
	end

	local searchBox = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -108, 0.5, 0),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = THEME.Row,
		Font = Enum.Font.Gotham,
		TextSize = 12,
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
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		Parent = main,
	})

	local SIDE_W, SIDE_MIN = 140, 46

	local side = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, SIDE_W, 1, 0), Parent = body })
	New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = side })

	local sideTop = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -1, 0, 0), Parent = side })
	local badgeLabels = {}
	if opts.Badge then
		sideTop.Size = UDim2.new(1, -1, 0, 56)
		local b1 = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -18, 0, 20),
			Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text, Text = opts.Badge, Parent = sideTop,
		})
		local b2 = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -18, 0, 16),
			Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = opts.BadgeSub or "", Parent = sideTop,
		})
		badgeLabels = { b1, b2 }
		New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, -8, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = sideTop })
	end

	local listTop = sideTop.Size.Y.Offset + 8
	local pageList = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, listTop),
		Size = UDim2.new(1, -17, 1, -(listTop + 8)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = side,
	}, { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local pagesHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(SIDE_W + 12, 0),
		Size = UDim2.new(1, -(SIDE_W + 24), 1, 0),
		Parent = body,
	})

	-- ручка сворачивания боковой панели (на разделителе)
	local handle = New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, SIDE_W, 0.5, 0),
		Size = UDim2.fromOffset(16, 28),
		BackgroundColor3 = THEME.Select,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 4,
		Parent = body,
	})
	Corner(handle, UDim.new(0, 5))
	for cx = 0, 1 do
		for cy = 0, 2 do
			local d = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, (cx - 0.5) * 5, 0.5, (cy - 1) * 6),
				Size = UDim2.fromOffset(2, 2),
				BackgroundColor3 = THEME.Sub,
				BorderSizePixel = 0,
				ZIndex = 5,
				Parent = handle,
			})
			Corner(d, UDim.new(1, 0))
		end
	end
	local function ApplySide()
		local w = win.Collapsed and SIDE_MIN or SIDE_W
		Tween(side, { Size = UDim2.new(0, w, 1, 0) }, 0.22)
		Tween(pagesHolder, { Position = UDim2.fromOffset(w + 12, 0), Size = UDim2.new(1, -(w + 24), 1, 0) }, 0.22)
		Tween(handle, { Position = UDim2.new(0, w, 0.5, 0) }, 0.22)
		for _, l in ipairs(badgeLabels) do l.Visible = not win.Collapsed end
		for _, p in ipairs(win.Pages) do
			p.Label.Visible = not win.Collapsed
			p.Letter.Visible = win.Collapsed and not p.HasIcon
		end
	end
	handle.MouseButton1Click:Connect(function()
		win.Collapsed = not win.Collapsed
		ApplySide()
	end)

	-- уголок растягивания (диагональная двойная стрелка)
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 6,
		Parent = main,
	})
	Bar(grip, 18, 1.5, -45, nil, THEME.Sub)
	Bar(grip, 6, 2, 0, UDim2.fromScale(1, 0), THEME.Sub, Vector2.new(1, 0))
	Bar(grip, 2, 6, 0, UDim2.fromScale(1, 0), THEME.Sub, Vector2.new(1, 0))
	Bar(grip, 6, 2, 0, UDim2.fromScale(0, 1), THEME.Sub, Vector2.new(0, 1))
	Bar(grip, 2, 6, 0, UDim2.fromScale(0, 1), THEME.Sub, Vector2.new(0, 1))
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
				main.Size = UDim2.fromOffset(math.max(420, startSize.X + d.X), math.max(260, startSize.Y + d.Y))
			end
		end)
	end

	-----------------------------------------------------------------
	-- Управление окном
	-----------------------------------------------------------------
	function win:SetScale(s)
		win.Scale = math.clamp(s, 0.5, 1.6)
		Tween(uiScale, { Scale = win.Scale })
	end

	function win:SetOpen(state)
		win.Open = state
		if state then
			uiScale.Scale = win.Scale * 0.9
			main.Visible = true
			Tween(uiScale, { Scale = win.Scale }, 0.25, Enum.EasingStyle.Back)
		else
			Tween(uiScale, { Scale = win.Scale * 0.9 }, 0.15)
			task.delay(0.15, function()
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
			Tween(main, { Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 44) }, 0.2)
		else
			Tween(main, { Size = win._full or size }, 0.2)
			task.delay(0.12, function() body.Visible = not win.Minimized end)
		end
	end

	closeB.MouseButton1Click:Connect(function() win:SetOpen(false) end)
	minB.MouseButton1Click:Connect(function() win:SetMinimized(not win.Minimized) end)

	-----------------------------------------------------------------
	-- Маленькая кнопка открытия (отключается: ToggleButton = false)
	-----------------------------------------------------------------
	if opts.ToggleButton ~= false then
		local toggle = New("TextButton", {
			Name = "Toggle",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = THEME.BG,
			Text = "",
			AutoButtonColor = false,
			Parent = gui,
		})
		Corner(toggle, UDim.new(1, 0))
		Stroke(toggle, THEME.Line, 0, 1.5)
		Moon(toggle, 14, THEME.BG)
		local dragState = MakeDraggable(toggle, toggle)
		toggle.MouseButton1Click:Connect(function()
			if not dragState.moved then win:SetOpen(not win.Open) end
		end)
	end
	if opts.ToggleKey then
		UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == opts.ToggleKey then win:SetOpen(not win.Open) end
		end)
	end

	-----------------------------------------------------------------
	-- Страницы (слева) -> вкладки (сверху) -> карточки
	-----------------------------------------------------------------
	function win:AddPage(name, iconId)
		local page = { Tabs = {}, HasIcon = iconId ~= nil }

		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = THEME.Select,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = #win.Pages + 1,
			Parent = pageList,
		})
		Corner(btn, UDim.new(0, 9))
		local indicator = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 16), BackgroundColor3 = THEME.Text, BorderSizePixel = 0,
			Visible = false, Parent = btn,
		})
		Corner(indicator, UDim.new(1, 0))
		Icon(btn, iconId, 16, THEME.Text, UDim2.new(0, 12, 0.5, 0))
		local label = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(iconId and 36 or 14, 0),
			Size = UDim2.new(1, -(iconId and 40 or 18), 1, 0),
			Font = Enum.Font.GothamMedium, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = name, Parent = btn,
		})
		local letter = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Text,
			Text = name:sub(1, 1):upper(), Visible = false, Parent = btn,
		})

		local frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pagesHolder })
		local tabBar = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = frame }, {
			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 20),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			New("UIPadding", { PaddingLeft = UDim.new(0, 4) }),
		})
		local tabArea = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 1, -46),
			Parent = frame,
		})

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
		page.Frame, page.Button, page.Indicator, page.Label, page.Letter = frame, btn, indicator, label, letter
		table.insert(win.Pages, page)
		if #win.Pages == 1 then SelectPage() end

		function page:AddTab(tabName, tabIcon)
			local tab = { _l = 0, _r = 0, _order = 0 }

			local tbtn = New("TextButton", {
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextColor3 = THEME.Sub,
				Text = tabName,
				LayoutOrder = #page.Tabs + 1,
				Parent = tabBar,
			})
			New("UIPadding", { PaddingLeft = UDim.new(0, tabIcon and 22 or 0), Parent = tbtn })
			Icon(tbtn, tabIcon, 15, THEME.Sub, UDim2.new(0, -22, 0.5, 0))
			local underline = New("Frame", {
				AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, tabIcon and -22 or 0, 1, -2),
				Size = UDim2.new(1, tabIcon and 22 or 0, 0, 2), BackgroundColor3 = THEME.Text, BorderSizePixel = 0,
				Visible = false, Parent = tbtn,
			})
			Corner(underline, UDim.new(1, 0))

			local scroll = New("ScrollingFrame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = THEME.Line,
				Visible = false,
				Parent = tabArea,
			})
			local function Column(x, offset)
				return New("Frame", {
					Position = UDim2.new(x, offset, 0, 0),
					Size = UDim2.new(0.5, -5, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Parent = scroll,
				}, { New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
			end
			tab.Left, tab.Right = Column(0, 0), Column(0.5, 5)

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
				Corner(card, UDim.new(0, 12))
				Stroke(card, THEME.Line, 0)
				New("UIPadding", {
					PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = card,
				})
				New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

				local head = New("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
				Icon(head, cardIcon, 17, THEME.Text, UDim2.new(0, 0, 0.5, 0))
				New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(cardIcon and 25 or 0, 0),
					Size = UDim2.new(1, -(cardIcon and 25 or 0), 1, 0),
					Font = Enum.Font.GothamBold, TextSize = 15,
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
