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
	Dark = Color3.fromRGB(10, 10, 10),
	Chip = Color3.fromRGB(28, 28, 28),
}

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

local ticks = {}

local function CreateWatermark(gui, yOffset)
	local bar = New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, yOffset or 70),
		Size = UDim2.fromOffset(230, 28),
		BackgroundColor3 = THEME.Dark,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Corner(bar, UDim.new(1, 0))
	Stroke(bar, Color3.fromRGB(58, 58, 58), 0)

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
			BackgroundColor3 = THEME.Chip,
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

	local nameL = Chip(1, THEME.Text)
	local fpsL = Chip(2, THEME.Sub)
	local pingL = Chip(3, THEME.Sub)
	local timeL = Chip(4, THEME.Sub)
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
		for _, f in ipairs(ticks) do
			f(t)
		end
	end)

	if opts.Watermark ~= false then
		CreateWatermark(gui, opts.WatermarkY)
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
		BackgroundColor3 = THEME.BG,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	Corner(main, UDim.new(0, 14))
	Stroke(main, THEME.Line, 0)
	local uiScale = New("UIScale", { Scale = win.Scale, Parent = main })
	win.Main = main

	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = main })
	MakeDraggable(top, main)
	local headLine = New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = top })

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

	local extras = {}
	local ord = 0
	local function TitlePart(text)
		ord += 1
		if ord > 1 then
			local d = New("Frame", { Size = UDim2.fromOffset(1, 14), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, LayoutOrder = ord * 2 - 1, Parent = titleBox })
			table.insert(extras, d)
		end
		local l = New("TextLabel", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = THEME.Text,
			Text = text,
			LayoutOrder = ord * 2,
			Parent = titleBox,
		})
		if ord > 1 then table.insert(extras, l) end
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
		searchB.Visible = not state
		headLine.Visible = not state
		for _, e in ipairs(extras) do e.Visible = not state end
		if state then
			searchBox.Visible = false
			searchBox.Text = ""
			win._full = main.Size
			body.Visible = false
			top.Size = UDim2.new(1, 0, 0, 36)
			Tween(main, { Size = UDim2.fromOffset(170, 36) }, 0.2)
		else
			top.Size = UDim2.new(1, 0, 0, 44)
			Tween(main, { Size = win._full or size }, 0.2)
			task.delay(0.12, function() body.Visible = not win.Minimized end)
		end
	end

	closeB.MouseButton1Click:Connect(function() win:SetOpen(false) end)
	minB.MouseButton1Click:Connect(function() win:SetMinimized(not win.Minimized) end)

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
