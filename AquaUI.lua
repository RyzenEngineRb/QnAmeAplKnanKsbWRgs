local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Aqua = {}
Aqua.__index = Aqua

local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local ROW_H = MOBILE and 44 or 38
local PAD = 14
local TS = MOBILE and 14 or 13

local THEME = {
	BG = Color3.fromRGB(14, 14, 16),
	Panel = Color3.fromRGB(19, 19, 22),
	Row = Color3.fromRGB(25, 25, 29),
	Hover = Color3.fromRGB(34, 34, 40),
	Line = Color3.fromRGB(44, 44, 52),
	Text = Color3.fromRGB(240, 240, 244),
	Sub = Color3.fromRGB(132, 132, 142),
	Off = Color3.fromRGB(40, 40, 47),
	Knob = Color3.fromRGB(18, 18, 20),
}

local ACCENTS = {
	White = Color3.fromRGB(236, 236, 240),
	Aqua = Color3.fromRGB(100, 200, 255),
	Violet = Color3.fromRGB(170, 140, 255),
	Green = Color3.fromRGB(110, 225, 160),
	Rose = Color3.fromRGB(255, 130, 160),
	Amber = Color3.fromRGB(255, 195, 90),
}
local ACCENT_NAMES = { "White", "Aqua", "Violet", "Green", "Rose", "Amber" }

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

local function Moving(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
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
		if dragging and Moving(input) then
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

local function BuildLogo(holder, size, image, color)
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
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Corner(sq, UDim.new(0, 2))
	local circ = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(size * 0.72, size * 0.72),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Corner(circ, UDim.new(1, 0))
end

local ticks = {}

local function CreateWatermark(gui, win, yOffset)
	local bar = New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, yOffset),
		Size = UDim2.fromOffset(230, 28),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		BorderSizePixel = 0,
		Parent = gui,
	})
	Corner(bar, UDim.new(1, 0))
	Stroke(bar, Color3.fromRGB(58, 58, 66), 0)

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
			BackgroundColor3 = Color3.fromRGB(28, 28, 33),
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

	local nameL = Chip(1, win.Accent)
	local fpsL = Chip(2, THEME.Text)
	local pingL = Chip(3, THEME.Text)
	local timeL = Chip(4, THEME.Sub)
	nameL.Text = LocalPlayer.DisplayName
	nameL.Font = Enum.Font.GothamBold
	table.insert(win._accentFns, function(c) nameL.TextColor3 = c end)

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

local function Elements(container, win, cardRef)
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
			LayoutOrder = nextOrder(),
			Parent = container,
		})
		Corner(r, UDim.new(0, 10))
		Stroke(r, THEME.Line, 0)
		return r
	end

	local function RowLabel(parent, text, y, h)
		return New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD, y or 0),
			Size = UDim2.new(1, -(PAD + 70), 0, h or ROW_H),
			Font = Enum.Font.Gotham,
			TextSize = TS,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text,
			Text = text,
			Parent = parent,
		})
	end

	local function Register(row, text)
		table.insert(win._search, { row = row, text = tostring(text):lower(), card = cardRef })
	end

	function E:AddLabel(text)
		local r = Row(30)
		local l = RowLabel(r, text, 0, 30)
		l.Size = UDim2.new(1, -(PAD * 2), 0, 30)
		l.TextColor3 = THEME.Sub
		Register(r, text)
	end

	function E:AddButton(text, callback)
		local r = Row()
		local b = New("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamMedium,
			TextSize = TS,
			TextColor3 = THEME.Text,
			Text = text,
			Parent = r,
		})
		b.MouseEnter:Connect(function() Tween(r, { BackgroundColor3 = THEME.Hover }) end)
		b.MouseLeave:Connect(function() Tween(r, { BackgroundColor3 = THEME.Row }) end)
		b.MouseButton1Click:Connect(function()
			Tween(r, { BackgroundColor3 = win.Accent }, 0.07)
			task.delay(0.1, function() Tween(r, { BackgroundColor3 = THEME.Row }, 0.25) end)
			if callback then task.spawn(callback) end
		end)
		Register(r, text)
	end

	function E:AddToggle(text, default, callback, flag)
		local r = Row()
		RowLabel(r, text)
		local saved = flag and win._cfg.flags[flag]
		local state = default and true or false
		if saved ~= nil then state = saved end
		local track = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(44, 24),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = THEME.Off,
			Parent = r,
		})
		Corner(track, UDim.new(1, 0))
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(18, 18),
			Parent = track,
		})
		Corner(knob, UDim.new(1, 0))
		local function Refresh(animate)
			local props = {
				BackgroundColor3 = state and win.Accent or THEME.Off,
			}
			local kprops = {
				Position = UDim2.new(0, state and 23 or 3, 0.5, 0),
				BackgroundColor3 = state and THEME.Knob or Color3.new(1, 1, 1),
			}
			if animate then
				Tween(track, props)
				Tween(knob, kprops, 0.2)
			else
				for k, v in pairs(props) do track[k] = v end
				for k, v in pairs(kprops) do knob[k] = v end
			end
		end
		Refresh(false)
		table.insert(win._accentFns, function() Refresh(false) end)
		local obj = {}
		function obj:Set(v, silent)
			state = v and true or false
			Refresh(true)
			if flag then win:SetFlag(flag, state) end
			if callback and not silent then task.spawn(callback, state) end
		end
		function obj:Get() return state end
		track.MouseButton1Click:Connect(function() obj:Set(not state) end)
		if saved ~= nil and callback then task.defer(callback, state) end
		Register(r, text)
		return obj
	end

	function E:AddSlider(text, min, max, default, callback, suffix, flag)
		local h = ROW_H + 16
		local r = Row(h)
		local lbl = RowLabel(r, text, 8, 18)
		lbl.Size = UDim2.new(1, -(PAD + 80), 0, 18)
		local valueLabel = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -PAD, 0, 8),
			Size = UDim2.fromOffset(70, 18),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = win.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
		local hit = New("TextButton", {
			Position = UDim2.fromOffset(PAD, h - 30),
			Size = UDim2.new(1, -(PAD * 2), 0, 24),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = r,
		})
		local track = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = THEME.Off,
			Parent = hit,
		})
		Corner(track, UDim.new(1, 0))
		local fill = New("Frame", { BackgroundColor3 = win.Accent, Size = UDim2.fromScale(0, 1), Parent = track })
		Corner(fill, UDim.new(1, 0))
		table.insert(win._accentFns, function(c)
			fill.BackgroundColor3 = c
			valueLabel.TextColor3 = c
		end)
		local saved = flag and win._cfg.flags[flag]
		local value = saved or default or min
		local function Set(v)
			value = math.clamp(math.floor(v + 0.5), min, max)
			fill.Size = UDim2.fromScale((value - min) / (max - min), 1)
			valueLabel.Text = tostring(value) .. (suffix or "")
		end
		Set(value)
		local sliding = false
		local function Update(x)
			local rel = math.clamp((x - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
			Set(min + (max - min) * rel)
			if flag then win:SetFlag(flag, value) end
			if callback then task.spawn(callback, value) end
		end
		hit.InputBegan:Connect(function(i)
			if Pointer(i) then sliding = true Update(i.Position.X) end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if Pointer(i) then sliding = false end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if sliding and Moving(i) then Update(i.Position.X) end
		end)
		if saved ~= nil and callback then task.defer(callback, value) end
		Register(r, text)
		return { Set = Set, Get = function() return value end }
	end

	function E:AddDropdown(text, options, default, callback, flag)
		local r = Row()
		r.ClipsDescendants = true
		local head = New("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_H),
			Text = "",
			Parent = r,
		})
		RowLabel(head, text)
		local saved = flag and win._cfg.flags[flag]
		local cur = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 20),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = win.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(saved or default or options[1]),
			Parent = head,
		})
		table.insert(win._accentFns, function(c) cur.TextColor3 = c end)
		local optH = MOBILE and 34 or 28
		local open = false
		for i, opt in ipairs(options) do
			local ob = New("TextButton", {
				Position = UDim2.new(0, 6, 0, ROW_H + (i - 1) * optH),
				Size = UDim2.new(1, -12, 0, optH - 2),
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
				if flag then win:SetFlag(flag, opt) end
				if callback then task.spawn(callback, opt) end
			end)
		end
		head.MouseButton1Click:Connect(function()
			open = not open
			Tween(r, { Size = UDim2.new(1, 0, 0, open and (ROW_H + 8 + #options * optH) or ROW_H) })
		end)
		if saved ~= nil and callback then task.defer(callback, saved) end
		Register(r, text)
	end

	function E:AddInput(text, placeholder, callback, flag)
		local r = Row()
		RowLabel(r, text)
		local saved = flag and win._cfg.flags[flag]
		local box = New("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.45, 0, 0, ROW_H - 12),
			BackgroundColor3 = THEME.Panel,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = THEME.Text,
			PlaceholderText = placeholder or "",
			PlaceholderColor3 = THEME.Sub,
			Text = saved or "",
			ClearTextOnFocus = false,
			Parent = r,
		})
		Corner(box, UDim.new(0, 8))
		Stroke(box, THEME.Line, 0)
		box.FocusLost:Connect(function()
			if flag then win:SetFlag(flag, box.Text) end
			if callback then task.spawn(callback, box.Text) end
		end)
		if saved ~= nil and callback then task.defer(callback, saved) end
		Register(r, text)
		return box
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
			Size = UDim2.new(1, 0, 0, MOBILE and 32 or 26),
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
			TextSize = TS,
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
		return Elements(body, win, cardRef)
	end

	return E
end

function Aqua:CreateWindow(opts)
	opts = opts or {}
	local win = setmetatable({
		Pages = {},
		Scale = 1,
		Open = true,
		Minimized = false,
		Accent = ACCENTS.White,
		_search = {},
		_accentFns = {},
		_cards = {},
		_manual = false,
		_single = false,
		_cfg = { settings = {}, flags = {} },
	}, Aqua)

	win._cfgPath = (opts.Config ~= false) and ("AquaUI_" .. (tostring(opts.Title or "Aqua"):gsub("%W", "")) .. ".json") or nil
	if win._cfgPath then
		pcall(function()
			if isfile and isfile(win._cfgPath) then
				local data = HttpService:JSONDecode(readfile(win._cfgPath))
				if type(data) == "table" then
					win._cfg.settings = data.settings or {}
					win._cfg.flags = data.flags or {}
				end
			end
		end)
	end
	local S = win._cfg.settings

	function win:_save()
		if not win._cfgPath or win._saving then return end
		win._saving = true
		task.delay(0.8, function()
			win._saving = false
			pcall(function()
				writefile(win._cfgPath, HttpService:JSONEncode(win._cfg))
			end)
		end)
	end

	function win:SetFlag(flag, value)
		win._cfg.flags[flag] = value
		win:_save()
	end

	local function Persist(key, value)
		S[key] = value
		win:_save()
	end

	local accentSetting = opts.Accent
	if S.accent and ACCENTS[S.accent] then accentSetting = S.accent end
	if type(accentSetting) == "string" and ACCENTS[accentSetting] then
		win.Accent = ACCENTS[accentSetting]
	elseif typeof(accentSetting) == "Color3" then
		win.Accent = accentSetting
	end

	local gui = New("ScreenGui", {
		Name = "AquaUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = GetParent(),
	})
	win.Gui = gui

	local conn = RunService.RenderStepped:Connect(function(dt)
		for _, f in ipairs(ticks) do
			f(dt)
		end
	end)

	local wmY = opts.WatermarkY or (MOBILE and 66 or 12)
	if opts.Watermark ~= false then
		win.WatermarkFrame = CreateWatermark(gui, win, wmY)
		if S.watermark == false then win.WatermarkFrame.Visible = false end
	end

	local size = opts.Size or UDim2.fromOffset(620, 380)

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
	Corner(main, UDim.new(0, 16))
	Stroke(main, THEME.Line, 0)
	local uiScale = New("UIScale", { Scale = 1, Parent = main })
	win.Main = main

	local bgOpacity = S.bgOpacity or opts.BackgroundOpacity or 0.2
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

	local HEAD_H = MOBILE and 48 or 44
	local BTN = MOBILE and 34 or 28

	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HEAD_H), Parent = main })
	MakeDraggable(top, main)
	local headLine = New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = top })

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
	win._logo = opts.Logo
	BuildLogo(logoHolder, 20, win._logo, win.Accent)

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
	local subExtras = {}
	if opts.Subtitle then
		table.insert(subExtras, New("Frame", { Size = UDim2.fromOffset(1, 14), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, LayoutOrder = 2, Parent = titleBox }))
		table.insert(subExtras, New("TextLabel", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = THEME.Sub,
			Text = opts.Subtitle,
			LayoutOrder = 3,
			Parent = titleBox,
		}))
	end

	local function HeaderButton(index)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(10 + index * (BTN + 6)), 0.5, 0),
			Size = UDim2.fromOffset(BTN, BTN),
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

	local closeB = HeaderButton(0)
	Bar(closeB, 14, 2, 45, nil, THEME.Sub)
	Bar(closeB, 14, 2, -45, nil, THEME.Sub)

	local minB = HeaderButton(1)
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

	local searchB = HeaderButton(2)
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
		Position = UDim2.new(1, -(10 + 3 * (BTN + 6)), 0.5, 0),
		Size = UDim2.fromOffset(MOBILE and 130 or 150, BTN - 2),
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
		local seen = {}
		for _, s in ipairs(win._search) do
			if s.row.Parent then
				local vis = q == "" or s.text:find(q, 1, true) ~= nil
				s.row.Visible = vis
				if s.card then seen[s.card] = seen[s.card] or vis end
			end
		end
		for card, any in pairs(seen) do
			card.Visible = q == "" or any
		end
	end)

	local body = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, HEAD_H),
		Size = UDim2.new(1, 0, 1, -HEAD_H),
		Parent = main,
	})

	local side = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0), Parent = body })
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
	local pageList = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, listTop),
		Size = UDim2.new(1, -21, 1, -(listTop + ROW_H + 22)),
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
	New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -(ROW_H + 16)), Size = UDim2.new(1, -10, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = side })

	local pagesHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(150 + PAD, 0),
		Size = UDim2.new(1, -(150 + PAD * 2), 1, 0),
		Parent = body,
	})

	local badgeVisibleTargets = {}
	for _, c in ipairs(sideTop:GetChildren()) do
		table.insert(badgeVisibleTargets, c)
	end

	local function Relayout()
		local W = (win.Minimized and win._full and win._full.X.Offset) or main.Size.X.Offset
		local rail = W < 470
		local sideW = rail and 60 or (W < 560 and 132 or 150)
		local contentW = W - sideW - PAD * 2
		local single = contentW < 380
		win._single = single
		side.Size = UDim2.new(0, sideW, 1, 0)
		pagesHolder.Position = UDim2.fromOffset(sideW + PAD, 0)
		pagesHolder.Size = UDim2.new(1, -(sideW + PAD * 2), 1, 0)
		for _, c in ipairs(badgeVisibleTargets) do c.Visible = not rail end
		for _, p in ipairs(win.Pages) do
			p.Label.Visible = not rail
			p.Letter.Visible = rail and not p.HasIcon
			if p.IconImg then
				p.IconImg.Position = rail and UDim2.new(0.5, -8, 0.5, 0) or UDim2.new(0, 12, 0.5, 0)
			end
			for _, t in ipairs(p.Tabs) do t:_apply(single) end
		end
		local showSub = not win.Minimized and W >= 540
		for _, e in ipairs(subExtras) do e.Visible = showSub end
	end

	function win:Fit()
		if win.Minimized then return end
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local bw, bh = size.X.Offset, size.Y.Offset
		local s
		if win._manual then
			s = win.Scale
		else
			s = math.clamp(math.min(vp.X * 0.94 / bw, vp.Y * 0.88 / bh, 1), 0.75, 1)
		end
		win.Scale = s
		uiScale.Scale = s
		main.Size = UDim2.fromOffset(math.floor(math.min(bw, vp.X * 0.94 / s)), math.floor(math.min(bh, vp.Y * 0.88 / s)))
		Relayout()
	end

	function win:SetScale(v)
		win._manual = true
		win.Scale = math.clamp(v, 0.5, 1.5)
		win:Fit()
	end

	function win:SetOpen(state)
		win.Open = state
		if state then
			uiScale.Scale = win.Scale * 0.92
			main.Visible = true
			Tween(uiScale, { Scale = win.Scale }, 0.25, Enum.EasingStyle.Back)
		else
			Tween(uiScale, { Scale = win.Scale * 0.92 }, 0.15)
			task.delay(0.15, function()
				if not win.Open then main.Visible = false end
			end)
		end
	end

	function win:SetMinimized(state)
		win.Minimized = state
		searchB.Visible = not state
		headLine.Visible = not state
		if state then
			searchBox.Visible = false
			searchBox.Text = ""
			win._full = main.Size
			body.Visible = false
			for _, e in ipairs(subExtras) do e.Visible = false end
			top.Size = UDim2.new(1, 0, 0, 38)
			Tween(main, { Size = UDim2.fromOffset(170, 38) }, 0.2)
		else
			top.Size = UDim2.new(1, 0, 0, HEAD_H)
			Tween(main, { Size = win._full or size }, 0.2)
			task.delay(0.22, function()
				body.Visible = not win.Minimized
				Relayout()
			end)
		end
	end

	function win:SetWatermark(v)
		if win.WatermarkFrame then win.WatermarkFrame.Visible = v end
	end

	function win:SetOpacity(v)
		main.BackgroundTransparency = math.clamp(v, 0, 0.6)
	end

	function win:SetAccent(v)
		local c = v
		if type(v) == "string" then c = ACCENTS[v] end
		if typeof(c) ~= "Color3" then return end
		win.Accent = c
		for _, f in ipairs(win._accentFns) do pcall(f, c) end
	end

	closeB.MouseButton1Click:Connect(function() win:SetOpen(false) end)
	minB.MouseButton1Click:Connect(function() win:SetMinimized(not win.Minimized) end)

	local toggle, toggleLogo
	if opts.ToggleButton ~= false then
		local tsize = MOBILE and 44 or 36
		toggle = New("TextButton", {
			Name = "Toggle",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(tsize, tsize),
			BackgroundColor3 = Color3.fromRGB(12, 12, 14),
			Text = "",
			AutoButtonColor = false,
			Parent = gui,
		})
		Corner(toggle, UDim.new(1, 0))
		Stroke(toggle, THEME.Line, 0, 1.5)
		toggleLogo = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Parent = toggle,
		})
		BuildLogo(toggleLogo, 20, win._logo, win.Accent)
		local dragState = MakeDraggable(toggle, toggle)
		toggle.MouseButton1Click:Connect(function()
			if not dragState.moved then win:SetOpen(not win.Open) end
		end)
		if S.openButton == false then toggle.Visible = false end
	end

	function win:SetToggleButton(v)
		if toggle then toggle.Visible = v end
	end

	function win:SetLogo(v)
		win._logo = v
		BuildLogo(logoHolder, 20, v, win.Accent)
		if toggleLogo then BuildLogo(toggleLogo, 20, v, win.Accent) end
	end

	table.insert(win._accentFns, function(c)
		if not ResolveImage(win._logo) then
			BuildLogo(logoHolder, 20, nil, c)
			if toggleLogo then BuildLogo(toggleLogo, 20, nil, c) end
		end
	end)

	local toggleKey = opts.ToggleKey
	if toggleKey == nil and not MOBILE then toggleKey = Enum.KeyCode.RightShift end
	if toggleKey then
		UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == toggleKey then win:SetOpen(not win.Open) end
		end)
	end

	local toastW = MOBILE and 230 or 250
	local toastHolder = New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(toastW, 0),
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
			Size = UDim2.fromOffset(toastW, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 1,
			Parent = toastHolder,
		})
		Corner(t, UDim.new(0, 12))
		local st = Stroke(t, win.Accent, 1)
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
		Tween(t, { BackgroundTransparency = 0.05 }, 0.25)
		Tween(st, { Transparency = 0.5 }, 0.25)
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
		local page = { Tabs = {}, HasIcon = ResolveImage(iconId) ~= nil }

		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundColor3 = THEME.Row,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = #win.Pages + 1,
			Parent = pinned and bottomList or pageList,
		})
		Corner(btn, UDim.new(0, 10))
		local indicator = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 16), BackgroundColor3 = win.Accent, BorderSizePixel = 0,
			Visible = false, Parent = btn,
		})
		Corner(indicator, UDim.new(1, 0))
		table.insert(win._accentFns, function(c) indicator.BackgroundColor3 = c end)
		page.IconImg = Icon(btn, iconId, 16, THEME.Text, UDim2.new(0, 12, 0.5, 0))
		local label = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(page.HasIcon and 36 or 14, 0),
			Size = UDim2.new(1, -(page.HasIcon and 40 or 18), 1, 0),
			Font = Enum.Font.GothamMedium, TextSize = TS,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = name, Parent = btn,
		})
		local letter = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Text,
			Text = name:sub(1, 1):upper(), Visible = false, Parent = btn,
		})

		local frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pagesHolder })
		local tabBar = New("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 42),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			Parent = frame,
		}, {
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
			Tween(btn, { BackgroundTransparency = 0 })
			Tween(label, { TextColor3 = THEME.Text })
		end
		btn.MouseButton1Click:Connect(SelectPage)
		page.Frame, page.Button, page.Indicator, page.Label, page.Letter = frame, btn, indicator, label, letter
		table.insert(win.Pages, page)
		if not pinned and not win._selected then SelectPage() end

		function page:AddTab(tabName, tabIcon)
			local tab = { _l = 0, _r = 0, _index = 0, _entries = {} }

			local tbtn = New("TextButton", {
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = TS,
				TextColor3 = THEME.Sub,
				Text = tabName,
				LayoutOrder = #page.Tabs + 1,
				Parent = tabBar,
			})
			New("UIPadding", { PaddingLeft = UDim.new(0, ResolveImage(tabIcon) and 22 or 0), Parent = tbtn })
			Icon(tbtn, tabIcon, 15, THEME.Sub, UDim2.new(0, -22, 0.5, 0))
			local hasTabIcon = ResolveImage(tabIcon) ~= nil
			local underline = New("Frame", {
				AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, hasTabIcon and -22 or 0, 1, -2),
				Size = UDim2.new(1, hasTabIcon and 22 or 0, 0, 2), BackgroundColor3 = win.Accent, BorderSizePixel = 0,
				Visible = false, Parent = tbtn,
			})
			Corner(underline, UDim.new(1, 0))
			table.insert(win._accentFns, function(c) underline.BackgroundColor3 = c end)

			local scroll = New("ScrollingFrame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = MOBILE and 0 or 2,
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

			function tab:_apply(single)
				tab.Left.Size = single and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0)
				tab.Right.Visible = not single
				for _, e in ipairs(tab._entries) do
					if single then
						e.frame.Parent = tab.Left
						e.frame.LayoutOrder = e.index
					else
						e.frame.Parent = e.side == "Right" and tab.Right or tab.Left
						e.frame.LayoutOrder = e.colOrder
					end
				end
			end

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
				if useRight then tab._r += 1 else tab._l += 1 end
				tab._index += 1

				local card = New("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = THEME.Panel,
					Parent = useRight and tab.Right or tab.Left,
				})
				Corner(card, UDim.new(0, 14))
				Stroke(card, THEME.Line, 0)
				New("UIPadding", {
					PaddingTop = UDim.new(0, PAD), PaddingBottom = UDim.new(0, PAD),
					PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD), Parent = card,
				})
				New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

				local entry = {
					frame = card,
					side = useRight and "Right" or "Left",
					index = tab._index,
					colOrder = useRight and tab._r or tab._l,
				}
				card.LayoutOrder = entry.colOrder
				table.insert(tab._entries, entry)
				if win._single then tab:_apply(true) end

				local head = New("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
				Icon(head, cardIcon, 17, THEME.Text, UDim2.new(0, 0, 0.5, 0))
				New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(ResolveImage(cardIcon) and 26 or 0, 0),
					Size = UDim2.new(1, -(ResolveImage(cardIcon) and 26 or 0), 1, 0),
					Font = Enum.Font.GothamBold, TextSize = MOBILE and 16 or 15,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = THEME.Text, Text = title, Parent = head,
				})
				return Elements(card, win, card)
			end

			return tab
		end

		Relayout()
		return page
	end

	if opts.Settings ~= false then
		if S.manual and S.scale then
			win._manual = true
			win.Scale = S.scale
		end
		if S.opacity then win:SetOpacity(S.opacity) end
		if S.accent and ACCENTS[S.accent] then win:SetAccent(S.accent) end

		local sp = win:AddPage("Settings", nil, true)
		local st = sp:AddTab("Interface")

		local window = st:AddCard("Window")
		local autoFit, scaleSlider
		autoFit = window:AddToggle("Auto Fit", not win._manual, function(v)
			if v then
				win._manual = false
				Persist("manual", false)
				win:Fit()
				if scaleSlider then scaleSlider.Set(win.Scale * 100) end
			else
				win._manual = true
				Persist("manual", true)
				Persist("scale", win.Scale)
			end
		end)
		scaleSlider = window:AddSlider("UI Scale", 50, 150, math.floor(win.Scale * 100 + 0.5), function(v)
			if autoFit:Get() then autoFit:Set(false, true) end
			win:SetScale(v / 100)
			Persist("manual", true)
			Persist("scale", v / 100)
		end, "%")
		window:AddSlider("Window Opacity", 0, 40, math.floor((S.opacity or 0) * 100 + 0.5), function(v)
			win:SetOpacity(v / 100)
			Persist("opacity", v / 100)
		end, "%")
		window:AddSlider("Background Image", 0, 100, math.floor(bgOpacity * 100 + 0.5), function(v)
			win:SetBackgroundOpacity(v / 100)
			Persist("bgOpacity", v / 100)
		end, "%")

		local display = st:AddCard("Display")
		display:AddDropdown("Accent", ACCENT_NAMES, S.accent or "White", function(v)
			win:SetAccent(v)
			Persist("accent", v)
		end)
		display:AddToggle("Watermark", S.watermark ~= false and opts.Watermark ~= false, function(v)
			win:SetWatermark(v)
			Persist("watermark", v)
		end)
		display:AddToggle("Open Button", S.openButton ~= false and opts.ToggleButton ~= false, function(v)
			win:SetToggleButton(v)
			Persist("openButton", v)
		end)

		local data = st:AddCard("Data")
		data:AddButton("Reset Settings", function()
			win._cfg.settings = {}
			win._cfg.flags = {}
			S = win._cfg.settings
			win:_save()
			win:Notify("Aqua", "Настройки сброшены. Перезапустите скрипт.", 4)
		end)
	end

	win:Fit()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			win:Fit()
		end)
	end

	function win:Destroy()
		conn:Disconnect()
		gui:Destroy()
	end

	return win
end

return setmetatable({}, { __index = Aqua })
