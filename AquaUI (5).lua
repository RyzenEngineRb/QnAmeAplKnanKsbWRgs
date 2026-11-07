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
	Base = Color3.fromRGB(5, 13, 24),
	Panel = Color3.fromRGB(8, 20, 34),
	Row = Color3.fromRGB(13, 30, 48),
	Hover = Color3.fromRGB(22, 48, 76),
	Line = Color3.fromRGB(38, 76, 110),
	Text = Color3.fromRGB(238, 247, 253),
	Sub = Color3.fromRGB(122, 152, 176),
	Accent = Color3.fromRGB(110, 205, 255),
	Off = Color3.fromRGB(22, 42, 64),
	Knob = Color3.fromRGB(6, 18, 30),
	Deep = Color3.fromRGB(3, 18, 36),
	Mid = Color3.fromRGB(8, 52, 92),
	Light = Color3.fromRGB(24, 98, 150),
	Foam = Color3.fromRGB(170, 225, 255),
}

local ROW_H = 38
local PAD = 14

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

local function ResolveImage(v)
	if not v then return nil end
	if type(v) == "number" then return "rbxassetid://" .. v end
	if type(v) == "string" then
		if v:find("^rbxasset") or v:find("^http") then return v end
		local ok, res = pcall(function()
			if isfile and getcustomasset and isfile(v) then
				return getcustomasset(v)
			end
		end)
		if ok and res then return res end
		if tonumber(v) then return "rbxassetid://" .. v end
	end
	return nil
end

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
	local img = ResolveImage(id)
	if not img then return nil end
	return New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = img,
		ImageColor3 = color or THEME.Sub,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = pos or UDim2.new(0, 0, 0.5, 0),
		Parent = parent,
	})
end

local function Chevron(parent, color)
	local c = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Bar(c, 8, 2, -45, UDim2.new(0.5, -3, 0.5, 0), color or THEME.Sub)
	Bar(c, 8, 2, 45, UDim2.new(0.5, 3, 0.5, 0), color or THEME.Sub)
	return c
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

local function BuildLogo(holder, size, image)
	for _, c in ipairs(holder:GetChildren()) do
		c:Destroy()
	end
	local img = ResolveImage(image)
	if img then
		New("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = img,
			ScaleType = Enum.ScaleType.Fit,
			Parent = holder,
		})
		return
	end
	local sq = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(size * 0.55, size * 0.55),
		Rotation = 45,
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Corner(sq, UDim.new(0, 2))
	local circ = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(size * 0.72, size * 0.72),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Corner(circ, UDim.new(1, 0))
	New("UIGradient", {
		Color = ColorSequence.new(THEME.Foam, THEME.Accent),
		Rotation = 90,
		Parent = sq,
	})
	New("UIGradient", {
		Color = ColorSequence.new(THEME.Accent, THEME.Light),
		Rotation = 90,
		Parent = circ,
	})
end

local waterLayers, shimmers, ticks = {}, {}, {}
local waterOn = true

local WATER_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.Deep),
	ColorSequenceKeypoint.new(0.35, THEME.Mid),
	ColorSequenceKeypoint.new(0.6, THEME.Light),
	ColorSequenceKeypoint.new(0.85, THEME.Mid),
	ColorSequenceKeypoint.new(1, THEME.Deep),
})
local FOAM_COLORS = ColorSequence.new(THEME.Foam)
local FOAM_ALPHA = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.94),
	NumberSequenceKeypoint.new(0.5, 0.84),
	NumberSequenceKeypoint.new(0.7, 0.95),
	NumberSequenceKeypoint.new(1, 1),
})

local function Water(frame, radius, baseTransparency)
	frame.BackgroundColor3 = THEME.Base
	frame.BackgroundTransparency = baseTransparency or 0.06
	frame.BorderSizePixel = 0
	local function layer(colors, alpha, rot, speed, amp)
		local l = New("Frame", {
			Name = "WaterLayer",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Visible = waterOn,
			Parent = frame,
		})
		Corner(l, radius)
		local g = New("UIGradient", { Color = colors, Transparency = alpha, Rotation = rot, Parent = l })
		table.insert(waterLayers, { g = g, frame = l, rot = rot, speed = speed, amp = amp, ph = math.random() * 6 })
	end
	layer(WATER_COLORS, NumberSequence.new(0.3), 30, 0.18, 0.5)
	layer(FOAM_COLORS, FOAM_ALPHA, -40, 0.28, 0.6)
end

local function Shimmer(parent, yPos)
	local line = New("Frame", {
		Position = yPos or UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = parent,
	})
	local g = New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = line,
	})
	table.insert(shimmers, g)
	return line
end

local function CreateWatermark(gui, yOffset)
	local bar = New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, yOffset or 70),
		Size = UDim2.fromOffset(230, 28),
		Parent = gui,
	})
	Corner(bar, UDim.new(1, 0))
	Water(bar, UDim.new(1, 0), 0.12)
	Stroke(bar, THEME.Line, 0)

	local content = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 20),
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
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(2, 10, 20),
			BackgroundTransparency = 0.32,
			LayoutOrder = order,
			Parent = content,
		})
		Corner(c, UDim.new(1, 0))
		local l = New("TextLabel", {
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = color or THEME.Text,
			Text = "...",
			Parent = c,
		})
		New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = l })
		return l
	end

	local nameL = Chip(1, THEME.Foam)
	local fpsL = Chip(2, THEME.Text)
	local pingL = Chip(3, THEME.Text)
	local timeL = Chip(4, THEME.Text)
	nameL.Text = LocalPlayer.DisplayName
	nameL.Font = Enum.Font.GothamBold

	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		bar.Size = UDim2.fromOffset(content.AbsoluteSize.X + 8, 28)
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

local function Elements(container, win)
	local E = {}
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function Row(h)
		local r = New("Frame", {
			Size = UDim2.new(1, 0, 0, h or ROW_H),
			BackgroundColor3 = THEME.Row,
			BackgroundTransparency = 0.3,
			LayoutOrder = nextOrder(),
			Parent = container,
		})
		Corner(r, UDim.new(0, 10))
		Stroke(r, THEME.Line, 0.25)
		return r
	end

	local function RowLabel(parent, text, y, h)
		return New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD, y or 0),
			Size = UDim2.new(1, -(PAD + 70), 0, h or ROW_H),
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
		local l = RowLabel(r, text, 0, 30)
		l.Size = UDim2.new(1, -(PAD * 2), 0, 30)
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
			Tween(r, { BackgroundColor3 = THEME.Accent }, 0.07)
			task.delay(0.1, function() Tween(r, { BackgroundColor3 = THEME.Hover }, 0.25) end)
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
			BackgroundColor3 = state and THEME.Knob or Color3.new(1, 1, 1),
			Parent = track,
		})
		Corner(knob, UDim.new(1, 0))
		local obj = {}
		function obj:Set(v, silent)
			state = v and true or false
			Tween(track, { BackgroundColor3 = state and THEME.Accent or THEME.Off })
			Tween(knob, {
				Position = UDim2.new(0, state and 21 or 3, 0.5, 0),
				BackgroundColor3 = state and THEME.Knob or Color3.new(1, 1, 1),
			}, 0.2)
			if callback and not silent then task.spawn(callback, state) end
		end
		function obj:Get() return state end
		track.MouseButton1Click:Connect(function() obj:Set(not state) end)
		Register(r, text)
		return obj
	end

	function E:AddSlider(text, min, max, default, callback, suffix)
		local r = Row(54)
		local lbl = RowLabel(r, text, 8, 18)
		lbl.Size = UDim2.new(1, -(PAD + 80), 0, 18)
		local valueLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -PAD, 0, 8),
			Size = UDim2.fromOffset(70, 18),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = THEME.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
		local bar = New("TextButton", {
			Position = UDim2.fromOffset(PAD, 34),
			Size = UDim2.new(1, -(PAD * 2), 0, 6),
			BackgroundColor3 = THEME.Off,
			Text = "",
			AutoButtonColor = false,
			Parent = r,
		})
		Corner(bar, UDim.new(1, 0))
		local fill = New("Frame", { BackgroundColor3 = THEME.Accent, Size = UDim2.fromScale(0, 1), Parent = bar })
		Corner(fill, UDim.new(1, 0))
		New("UIGradient", { Color = ColorSequence.new(THEME.Light, THEME.Accent), Parent = fill })
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
		local r = Row()
		r.ClipsDescendants = true
		local head = New("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_H),
			Text = "",
			Parent = r,
		})
		RowLabel(head, text)
		New("TextLabel", {
			Name = "Current",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 20),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = THEME.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(default or options[1]),
			Parent = head,
		})
		local cur = head.Current
		local open = false
		for i, opt in ipairs(options) do
			local ob = New("TextButton", {
				Position = UDim2.new(0, 6, 0, ROW_H + (i - 1) * 28),
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
				Tween(r, { Size = UDim2.new(1, 0, 0, ROW_H) })
				if callback then task.spawn(callback, opt) end
			end)
		end
		head.MouseButton1Click:Connect(function()
			open = not open
			Tween(r, { Size = UDim2.new(1, 0, 0, open and (ROW_H + 8 + #options * 28) or ROW_H) })
		end)
		Register(r, text)
	end

	function E:AddGroup(title, groupIcon, startOpen)
		local g = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = container,
		}, { New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local head = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
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
		if waterOn then
			for i = #waterLayers, 1, -1 do
				local w = waterLayers[i]
				if w.g.Parent then
					w.g.Offset = Vector2.new(math.sin(t * w.speed + w.ph) * w.amp, math.cos(t * w.speed * 0.7 + w.ph) * 0.25)
					w.g.Rotation = w.rot + math.sin(t * w.speed * 0.6 + w.ph) * 16
				else
					table.remove(waterLayers, i)
				end
			end
		end
		for i = #shimmers, 1, -1 do
			local g = shimmers[i]
			if g.Parent then
				g.Offset = Vector2.new(math.sin(t * 0.7) * 0.9, 0)
			else
				table.remove(shimmers, i)
			end
		end
		for _, f in ipairs(ticks) do
			f(t)
		end
	end)

	if opts.Watermark ~= false then
		win.WatermarkFrame = CreateWatermark(gui, opts.WatermarkY)
	end

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
		ClipsDescendants = true,
		Parent = gui,
	})
	Corner(main, UDim.new(0, 16))
	Water(main, UDim.new(0, 16), 0.06)
	Stroke(main, THEME.Line, 0)
	local uiScale = New("UIScale", { Scale = win.Scale, Parent = main })
	win.Main = main

	local bgOpacity = opts.BackgroundOpacity or 0.2
	local bgImage = New("ImageLabel", {
		Name = "Background",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = 1 - bgOpacity,
		ZIndex = 0,
		Visible = false,
		Parent = main,
	})
	Corner(bgImage, UDim.new(0, 16))

	function win:SetBackground(v)
		local img = ResolveImage(v)
		bgImage.Image = img or ""
		bgImage.Visible = img ~= nil
	end
	function win:SetBackgroundOpacity(v)
		bgOpacity = math.clamp(v, 0, 1)
		bgImage.ImageTransparency = 1 - bgOpacity
	end
	if opts.Background then win:SetBackground(opts.Background) end

	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = main })
	MakeDraggable(top, main)
	local headLine = New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = top })
	local headShimmer = Shimmer(top)

	local titleBox = New("Frame", {
		Position = UDim2.fromOffset(PAD + 2, 0),
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
	local logoHolder = New("Frame", { Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, LayoutOrder = 0, Parent = titleBox })
	BuildLogo(logoHolder, 20, opts.Logo)

	local extras = {}
	New("TextLabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = THEME.Text,
		Text = opts.Title or "Aqua",
		LayoutOrder = 1,
		Parent = titleBox,
	})
	if opts.Subtitle then
		local d = New("Frame", { Size = UDim2.fromOffset(1, 14), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, LayoutOrder = 2, Parent = titleBox })
		local l = New("TextLabel", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = THEME.Sub,
			Text = opts.Subtitle,
			LayoutOrder = 3,
			Parent = titleBox,
		})
		table.insert(extras, d)
		table.insert(extras, l)
	end

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
		b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = 0.2 }) end)
		b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 1 }) end)
		return b
	end

	local closeB = HeaderButton(-10)
	Bar(closeB, 14, 2, 45, nil, THEME.Sub)
	Bar(closeB, 14, 2, -45, nil, THEME.Sub)

	local minB = HeaderButton(-42)
	do
		local box = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Parent = minB })
		Bar(box, 6, 2, 0, UDim2.fromOffset(0, 5), THEME.Sub, Vector2.new(0, 0.5))
		Bar(box, 2, 6, 0, UDim2.fromOffset(5, 0), THEME.Sub, Vector2.new(0.5, 0))
		Bar(box, 6, 2, 0, UDim2.new(1, 0, 0, 5), THEME.Sub, Vector2.new(1, 0.5))
		Bar(box, 2, 6, 0, UDim2.new(1, -5, 0, 0), THEME.Sub, Vector2.new(0.5, 0))
		Bar(box, 6, 2, 0, UDim2.new(0, 0, 1, -5), THEME.Sub, Vector2.new(0, 0.5))
		Bar(box, 2, 6, 0, UDim2.new(0, 5, 1, 0), THEME.Sub, Vector2.new(0.5, 1))
		Bar(box, 6, 2, 0, UDim2.new(1, 0, 1, -5), THEME.Sub, Vector2.new(1, 0.5))
		Bar(box, 2, 6, 0, UDim2.new(1, -5, 1, 0), THEME.Sub, Vector2.new(0.5, 1))
	end

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

	local body = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		Parent = main,
	})

	local SIDE_W = 150

	local side = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, SIDE_W, 1, 0), Parent = body })
	New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = side })

	local sideTop = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -1, 0, 0), Parent = side })
	if opts.Badge then
		sideTop.Size = UDim2.new(1, -1, 0, 56)
		New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD + 2, 8), Size = UDim2.new(1, -(PAD + 6), 0, 20),
			Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text, Text = opts.Badge, Parent = sideTop,
		})
		New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD + 2, 28), Size = UDim2.new(1, -(PAD + 6), 0, 16),
			Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = opts.BadgeSub or "", Parent = sideTop,
		})
		New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, -10, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = sideTop })
	end

	local listTop = sideTop.Size.Y.Offset + 10
	local BOTTOM_H = 54
	local pageList = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, listTop),
		Size = UDim2.new(1, -21, 1, -(listTop + BOTTOM_H + 6)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = side,
	}, { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local bottomList = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -21, 0, ROW_H),
		Parent = side,
	}, { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }) })
	New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -(ROW_H + 18)), Size = UDim2.new(1, -10, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = side })

	local pagesHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(SIDE_W + PAD, 0),
		Size = UDim2.new(1, -(SIDE_W + PAD * 2), 1, 0),
		Parent = body,
	})

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
		searchB.Visible = not state
		headLine.Visible = not state
		headShimmer.Visible = not state
		for _, e in ipairs(extras) do e.Visible = not state end
		if state then
			searchBox.Visible = false
			searchBox.Text = ""
			win._full = main.Size
			body.Visible = false
			top.Size = UDim2.new(1, 0, 0, 38)
			Tween(main, { Size = UDim2.fromOffset(170, 38) }, 0.2)
		else
			top.Size = UDim2.new(1, 0, 0, 44)
			Tween(main, { Size = win._full or size }, 0.2)
			task.delay(0.12, function() body.Visible = not win.Minimized end)
		end
	end

	function win:SetWatermark(v)
		if win.WatermarkFrame then win.WatermarkFrame.Visible = v end
	end

	function win:SetWater(v)
		waterOn = v
		for _, w in ipairs(waterLayers) do
			if w.frame.Parent then w.frame.Visible = v end
		end
	end

	function win:SetOpacity(v)
		main.BackgroundTransparency = math.clamp(v, 0, 0.6)
	end

	closeB.MouseButton1Click:Connect(function() win:SetOpen(false) end)
	minB.MouseButton1Click:Connect(function() win:SetMinimized(not win.Minimized) end)

	local toggle, toggleLogo
	if opts.ToggleButton ~= false then
		toggle = New("TextButton", {
			Name = "Toggle",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = THEME.Base,
			BackgroundTransparency = 0.1,
			Text = "",
			AutoButtonColor = false,
			Parent = gui,
		})
		Corner(toggle, UDim.new(1, 0))
		Stroke(toggle, THEME.Accent, 0.35, 1.5)
		toggleLogo = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Parent = toggle,
		})
		BuildLogo(toggleLogo, 18, opts.Logo)
		local dragState = MakeDraggable(toggle, toggle)
		toggle.MouseButton1Click:Connect(function()
			if not dragState.moved then win:SetOpen(not win.Open) end
		end)
	end
	win.ToggleButton = toggle

	function win:SetToggleButton(v)
		if toggle then toggle.Visible = v end
	end

	function win:SetLogo(v)
		BuildLogo(logoHolder, 20, v)
		if toggleLogo then BuildLogo(toggleLogo, 18, v) end
	end

	if opts.ToggleKey then
		UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == opts.ToggleKey then win:SetOpen(not win.Open) end
		end)
	end

	local toastHolder = New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	function win:Notify(title, text, duration)
		local t = New("Frame", {
			Size = UDim2.fromOffset(240, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 1,
			Parent = toastHolder,
		})
		Corner(t, UDim.new(0, 12))
		local st = Stroke(t, THEME.Accent, 1)
		New("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = t,
		})
		New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = t })
		local a = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text, Text = title or "", TextTransparency = 1, LayoutOrder = 1, Parent = t,
		})
		local b = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = text or "", TextTransparency = 1, LayoutOrder = 2, Parent = t,
		})
		Tween(t, { BackgroundTransparency = 0.08 }, 0.25)
		Tween(st, { Transparency = 0.45 }, 0.25)
		Tween(a, { TextTransparency = 0 }, 0.25)
		Tween(b, { TextTransparency = 0 }, 0.25)
		task.delay(duration or 4, function()
			Tween(t, { BackgroundTransparency = 1 }, 0.3)
			Tween(st, { Transparency = 1 }, 0.3)
			Tween(a, { TextTransparency = 1 }, 0.3)
			Tween(b, { TextTransparency = 1 }, 0.3)
			task.delay(0.35, function() t:Destroy() end)
		end)
	end

	function win:AddPage(name, iconId, pinned)
		local page = { Tabs = {} }

		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundColor3 = THEME.Accent,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = #win.Pages + 1,
			Parent = pinned and bottomList or pageList,
		})
		Corner(btn, UDim.new(0, 10))
		local indicator = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 16), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0,
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

		local frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pagesHolder })
		local tabBar = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = frame }, {
			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 22),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local tabArea = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 1, -50),
			Parent = frame,
		})

		local function SelectPage()
			for _, p in ipairs(win.Pages) do
				p.Frame.Visible = false
				p.Indicator.Visible = false
				Tween(p.Button, { BackgroundTransparency = 1 })
				Tween(p.Label, { TextColor3 = THEME.Sub })
			end
			win._selected = page
			frame.Visible = true
			indicator.Visible = true
			Tween(btn, { BackgroundTransparency = 0.86 })
			Tween(label, { TextColor3 = THEME.Text })
		end
		btn.MouseButton1Click:Connect(SelectPage)
		page.Frame, page.Button, page.Indicator, page.Label = frame, btn, indicator, label
		table.insert(win.Pages, page)
		if not pinned and not win._selected then SelectPage() end

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
				Size = UDim2.new(1, tabIcon and 22 or 0, 0, 2), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0,
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
					Size = UDim2.new(0.5, -6, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Parent = scroll,
				}, { New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
			end
			tab.Left, tab.Right = Column(0, 0), Column(0.5, 6)

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
					BackgroundTransparency = 0.22,
					LayoutOrder = tab._order,
					Parent = col,
				})
				Corner(card, UDim.new(0, 14))
				Stroke(card, THEME.Line, 0.1)
				New("UIPadding", {
					PaddingTop = UDim.new(0, PAD), PaddingBottom = UDim.new(0, PAD),
					PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD), Parent = card,
				})
				New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

				local head = New("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
				Icon(head, cardIcon, 17, THEME.Accent, UDim2.new(0, 0, 0.5, 0))
				New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(cardIcon and 26 or 0, 0),
					Size = UDim2.new(1, -(cardIcon and 26 or 0), 1, 0),
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

	if opts.Settings ~= false then
		local sp = win:AddPage("Settings", nil, true)
		local st = sp:AddTab("Interface")
		local window = st:AddCard("Window")
		window:AddSlider("UI Scale", 50, 150, math.floor(win.Scale * 100 + 0.5), function(v)
			win:SetScale(v / 100)
		end, "%")
		window:AddSlider("Window Opacity", 0, 50, 6, function(v)
			win:SetOpacity(v / 100)
		end, "%")
		window:AddSlider("Background Image", 0, 100, math.floor(bgOpacity * 100 + 0.5), function(v)
			win:SetBackgroundOpacity(v / 100)
		end, "%")
		local display = st:AddCard("Display")
		display:AddToggle("Watermark", opts.Watermark ~= false, function(v)
			win:SetWatermark(v)
		end)
		display:AddToggle("Water Effect", true, function(v)
			win:SetWater(v)
		end)
		display:AddToggle("Open Button", opts.ToggleButton ~= false, function(v)
			win:SetToggleButton(v)
		end)
	end

	function win:Destroy()
		conn:Disconnect()
		gui:Destroy()
	end

	return win
end

return setmetatable({}, { __index = Aqua })
