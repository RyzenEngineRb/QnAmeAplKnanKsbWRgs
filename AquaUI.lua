local Library = { Flags = {}, Options = {}, Listeners = {} }

local cloneref = cloneref or function(x) return x end
local function Service(n) return cloneref(game:GetService(n)) end

local Players = Service("Players")
local RunService = Service("RunService")
local UserInputService = Service("UserInputService")
local TweenService = Service("TweenService")
local HttpService = Service("HttpService")
local Stats = Service("Stats")
local CoreGui = Service("CoreGui")
local TextService = Service("TextService")

local LocalPlayer = Players.LocalPlayer

local MOBILE = (function()
	local p
	pcall(function() p = UserInputService:GetPlatform() end)
	if p == Enum.Platform.IOS or p == Enum.Platform.Android then return true end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end)()

local ROW_H = MOBILE and 42 or 36
local PAD = 14
local TS = 12
local HAS_FS = (writefile and readfile and isfile and isfolder and makefolder) and true or false

local THEME = {
	BG = Color3.fromRGB(14, 14, 16),
	Panel = Color3.fromRGB(19, 19, 22),
	Row = Color3.fromRGB(25, 25, 29),
	Hover = Color3.fromRGB(34, 34, 40),
	Select = Color3.fromRGB(30, 30, 35),
	Line = Color3.fromRGB(44, 44, 52),
	Text = Color3.fromRGB(240, 240, 244),
	Sub = Color3.fromRGB(132, 132, 142),
	Off = Color3.fromRGB(40, 40, 47),
}

local ACCENTS = {
	Blue = Color3.fromRGB(104, 122, 255),
	White = Color3.fromRGB(236, 236, 240),
	Aqua = Color3.fromRGB(100, 200, 255),
	Violet = Color3.fromRGB(170, 140, 255),
	Green = Color3.fromRGB(110, 225, 160),
	Rose = Color3.fromRGB(255, 130, 160),
	Amber = Color3.fromRGB(255, 195, 90),
}
local ACCENT_NAMES = { "Blue", "White", "Aqua", "Violet", "Green", "Rose", "Amber" }

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
	if typeof(parent) == "UDim" then
		return New("UICorner", { CornerRadius = parent })
	end
	return New("UICorner", { CornerRadius = r or UDim.new(0, 10), Parent = parent })
end

local function Stroke(parent, color, transparency, thickness)
	if typeof(parent) == "Color3" then
		return New("UIStroke", {
			Color = parent,
			Transparency = color or 0,
			Thickness = transparency or 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end
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

local function Safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[AquaUI] " .. tostring(err)) end
end

local function IsPointer(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function Moving(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function Tap(btn, fn)
	btn.InputBegan:Connect(function(i)
		if not IsPointer(i) then return end
		local start = i.Position
		local c
		c = i.Changed:Connect(function()
			if i.UserInputState ~= Enum.UserInputState.End then return end
			c:Disconnect()
			if (i.Position - start).Magnitude <= 10 then task.spawn(fn) end
		end)
	end)
end

local function TextOn(c)
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return lum > 0.62 and Color3.fromRGB(18, 18, 20) or Color3.new(1, 1, 1)
end

local CACHE_FOLDER = "AquaUI"

local function UrlHash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return tostring(h)
end

local function IsImageData(d)
	if type(d) ~= "string" or #d < 8 then return false end
	return d:sub(1, 4) == "\137PNG" or d:sub(1, 2) == "\255\216" or d:sub(1, 4) == "GIF8"
end

local function ResolveImage(src, kind, download)
	if src == nil or src == "" then return nil end
	if type(src) == "number" then return "rbxassetid://" .. src end
	if type(src) ~= "string" then return nil end
	if src:match("^rbxassetid://") or src:match("^rbxasset://") or src:match("^rbxthumb://") then return src end
	if src:match("^%d+$") then return "rbxassetid://" .. src end
	if not download then return nil end
	local getasset = getcustomasset or getsynasset
	if src:match("^https?://") then
		if not (HAS_FS and getasset) then return nil end
		local path = CACHE_FOLDER .. "/" .. (kind or "img") .. "_" .. UrlHash(src) .. ".png"
		local okc, cached = pcall(function()
			if isfile(path) then return getasset(path) end
			return nil
		end)
		if okc and cached then return cached end
		local ok, data = pcall(function() return game:HttpGet(src) end)
		if not ok or not IsImageData(data) then return nil end
		local ok2, asset = pcall(function()
			if not isfolder(CACHE_FOLDER) then makefolder(CACHE_FOLDER) end
			writefile(path, data)
			return getasset(path)
		end)
		if ok2 and asset then return asset end
		return nil
	end
	if getasset and isfile then
		local ok, res = pcall(function()
			if isfile(src) then return getasset(src) end
			return nil
		end)
		if ok and res then return res end
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
	local img = ResolveImage(id, "icon", false)
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

local function DrawGear(parent, size, color)
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local parts = {}
	local r = size * 0.4
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local t = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r),
			Size = UDim2.fromOffset(size * 0.2, size * 0.26),
			Rotation = i * 45 + 90,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = holder,
		})
		Corner(t, UDim.new(0, 1))
		table.insert(parts, t)
	end
	local ring = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.5, size * 0.5),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	Corner(ring, UDim.new(1, 0))
	local st = Stroke(ring, color, 0, math.max(2, size * 0.14))
	local obj = { Holder = holder }
	function obj:SetColor(c)
		for _, p in ipairs(parts) do p.BackgroundColor3 = c end
		st.Color = c
	end
	return obj
end

local function MakeDraggable(handle, target)
	local state = { moved = false }
	local dragging, startPos, startInput
	handle.InputBegan:Connect(function(input)
		if IsPointer(input) then
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
	if image then
		New("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = image,
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

function Library:OnChanged(flag, fn)
	Library.Listeners[flag] = Library.Listeners[flag] or {}
	table.insert(Library.Listeners[flag], fn)
	return function()
		local list = Library.Listeners[flag]
		if not list then return end
		for i, f in ipairs(list) do
			if f == fn then
				table.remove(list, i)
				break
			end
		end
	end
end

function Library:_emit(flag, value)
	local list = Library.Listeners[flag]
	if not list then return end
	for _, fn in ipairs({ table.unpack(list) }) do
		Safe(fn, value)
	end
end

function Library:Get(flag) return Library.Flags[flag] end

function Library:Set(flag, value, silent)
	local obj = Library.Options[flag]
	if not obj then return false end
	obj:Set(value, silent)
	return true
end

function Library:Notify(cfg)
	local W = Library.Active
	if W then W:Notify(cfg) end
end

local function AutoFit(label, max, min)
	local function upd()
		local sc = (Library.Active and Library.Active.Scale) or 1
		local w = label.AbsoluteSize.X / sc
		if w <= 4 or label.Text == "" then return end
		local sz = max
		while sz > min do
			local b = TextService:GetTextSize(label.Text, sz, label.Font, Vector2.new(10000, 100))
			if b.X <= w - 2 then break end
			sz -= 1
		end
		label.TextSize = sz
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd)
	label:GetPropertyChangedSignal("Text"):Connect(upd)
	task.defer(upd)
end

local ticks = {}

local function CreateWatermark(gui, W, yOffset, cfg)
	local bar = New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, yOffset),
		Size = UDim2.fromOffset(200, 32),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = gui,
	})
	Corner(bar, UDim.new(1, 0))
	Stroke(bar, Color3.fromRGB(58, 58, 66), 0)

	local content = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = bar,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 5),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local avatar = New("Frame", {
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(28, 28, 33),
		LayoutOrder = 0,
		Parent = content,
	}, { Corner(UDim.new(1, 0)) })
	New("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
		Parent = avatar,
	}, { Corner(UDim.new(1, 0)) })
	local ring = Stroke(avatar, W.Accent, 0, 1.5)
	W:BindAccent(function(c) ring.Color = c end)

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

	local nameL
	if cfg.WatermarkName then
		nameL = Chip(1, W.Accent)
		nameL.Text = LocalPlayer.DisplayName
		nameL.Font = Enum.Font.GothamBold
		W:BindAccent(function(c) nameL.TextColor3 = c end)
	end
	local playersL = Chip(2, THEME.Text)
	local fpsL = Chip(3, THEME.Text)
	local pingL = Chip(4, THEME.Text)
	local timeL
	if cfg.WatermarkTime then timeL = Chip(5, THEME.Sub) end

	local function UpdatePlayers()
		playersL.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
	end
	UpdatePlayers()
	table.insert(W.Conns, Players.PlayerAdded:Connect(UpdatePlayers))
	table.insert(W.Conns, Players.PlayerRemoving:Connect(function()
		task.defer(UpdatePlayers)
	end))

	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		bar.Size = UDim2.fromOffset(content.AbsoluteSize.X + 12, 32)
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
			if timeL then timeL.Text = os.date("%H:%M:%S") end
		end
	end)
	return bar
end

local function Elements(container, W, cardRef)
	local E = {}
	local order = 0

	local function Row(h)
		order += 1
		local r = New("Frame", {
			Size = UDim2.new(1, 0, 0, h or ROW_H),
			BackgroundColor3 = THEME.Row,
			LayoutOrder = order,
			Parent = container,
		})
		Corner(r, UDim.new(0, 10))
		Stroke(r, THEME.Line, 0)
		return r
	end

	local function Lbl(parent, text, reserve, y, h)
		local l = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD, y or 0),
			Size = UDim2.new(1, -(PAD + (reserve or 70)), 0, h or ROW_H),
			Font = Enum.Font.Gotham,
			TextSize = TS,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = THEME.Text,
			Text = tostring(text or ""),
			Parent = parent,
		})
		AutoFit(l, TS, 9)
		return l
	end

	local function Hit(parent, h)
		return New("TextButton", {
			BackgroundTransparency = 1,
			Size = h and UDim2.new(1, 0, 0, h) or UDim2.fromScale(1, 1),
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = parent,
		})
	end

	local function Field(parent, w)
		return New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(w, MOBILE and 32 or 28),
			BackgroundColor3 = THEME.Panel,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = parent,
		}, { Corner(UDim.new(0, 8)), Stroke(THEME.Line, 0) })
	end

	local function Register(row, text)
		table.insert(W._search, { row = row, text = tostring(text or ""):lower(), card = cardRef })
	end

	local function Decimals(inc)
		local s = tostring(inc)
		local p = s:find("%.")
		return p and (#s - p) or 0
	end

	local function RegisterFlag(cfg, obj)
		if cfg.Flag then
			Library.Options[cfg.Flag] = obj
			Library.Flags[cfg.Flag] = obj.Value
		end
	end

	local function Commit(cfg, obj, silent)
		if cfg.Flag then
			Library.Flags[cfg.Flag] = obj.Value
			W:_setFlag(cfg.Flag, obj.Value)
		end
		if not silent then
			Safe(cfg.Callback, obj.Value)
			if cfg.Flag then Library:_emit(cfg.Flag, obj.Value) end
		end
	end

	function E:AddLabel(text)
		local r = Row(30)
		local l = Lbl(r, text, PAD)
		l.Size = UDim2.new(1, -(PAD * 2), 0, 30)
		l.TextColor3 = THEME.Sub
		l.TextSize = 12
		Register(r, text)
		local obj = {}
		function obj:Set(t) l.Text = tostring(t) end
		return obj
	end

	function E:AddButton(cfg)
		cfg = type(cfg) == "string" and { Name = cfg } or cfg
		local r = Row()
		local fieldW = MOBILE and 84 or 84
		Lbl(r, cfg.Name, fieldW + 24)
		local f = Field(r, fieldW)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		local grad = New("UIGradient", { Rotation = 90, Parent = f })
		local flash = New("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = f,
		}, { Corner(UDim.new(0, 8)) })
		local txt = New("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamMedium,
			Text = cfg.ButtonText or "Run",
			TextSize = TS,
			ZIndex = 5,
			Parent = f,
		})
		W:BindAccent(function(c)
			grad.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.22), c:Lerp(Color3.new(0, 0, 0), 0.3))
			txt.TextColor3 = TextOn(c)
		end)
		local hit = Hit(r)
		hit.MouseEnter:Connect(function() Tween(r, { BackgroundColor3 = THEME.Hover }) end)
		hit.MouseLeave:Connect(function() Tween(r, { BackgroundColor3 = THEME.Row }) end)
		Tap(hit, function()
			flash.BackgroundTransparency = 0.6
			Tween(flash, { BackgroundTransparency = 1 }, 0.35)
			Safe(cfg.Callback)
		end)
		Register(r, cfg.Name)
		return {}
	end

	function E:AddToggle(cfg)
		cfg = type(cfg) == "string" and { Name = cfg } or cfg
		local r = Row()
		local TW, TH = 46, MOBILE and 26 or 24
		Lbl(r, cfg.Name, TW + 24)
		local pill = New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(TW, TH),
			BackgroundColor3 = THEME.Off,
			BorderSizePixel = 0,
			Parent = r,
		}, { Corner(UDim.new(1, 0)) })
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, TH / 2, 0.5, 0),
			Size = UDim2.fromOffset(TH - 8, TH - 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = pill,
		}, { Corner(UDim.new(1, 0)) })
		local obj = { Value = false, Type = "Toggle" }
		local function render(animate)
			local on = obj.Value
			local p = { BackgroundColor3 = on and W.Accent or THEME.Off }
			local k = {
				Position = UDim2.new(0, on and (TW - TH / 2) or (TH / 2), 0.5, 0),
				BackgroundColor3 = on and TextOn(W.Accent) or Color3.new(1, 1, 1),
			}
			if animate then
				Tween(pill, p, 0.15)
				Tween(knob, k, 0.15)
			else
				for key, v in pairs(p) do pill[key] = v end
				for key, v in pairs(k) do knob[key] = v end
			end
		end
		function obj:Set(v, silent)
			obj.Value = v and true or false
			render(true)
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		W:BindAccent(function() render(false) end)
		Tap(Hit(r), function() obj:Set(not obj.Value) end)
		local saved = cfg.Flag and W._cfg.flags[cfg.Flag]
		obj.Value = (saved ~= nil) and saved or (cfg.Default and true or false)
		render(false)
		RegisterFlag(cfg, obj)
		if obj.Value then Commit(cfg, obj, false) end
		Register(r, cfg.Name)
		return obj
	end

	function E:AddSlider(cfg)
		local min, max = cfg.Min or 0, cfg.Max or 100
		local inc = cfg.Increment or 1
		local dec = Decimals(inc)
		local h = ROW_H + 16
		local r = Row(h)
		local lbl = Lbl(r, cfg.Name, 90, 8, 18)
		lbl.Size = UDim2.new(1, -(PAD + 90), 0, 18)
		local val = New("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -PAD, 0, 8),
			Size = UDim2.fromOffset(80, 18),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = W.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
		local hit = New("TextButton", {
			Position = UDim2.fromOffset(PAD, h - 30),
			Size = UDim2.new(1, -(PAD * 2), 0, 26),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = r,
		})
		local track = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = THEME.Off,
			BorderSizePixel = 0,
			Parent = hit,
		}, { Corner(UDim.new(1, 0)) })
		local fill = New("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = W.Accent,
			BorderSizePixel = 0,
			Parent = track,
		}, { Corner(UDim.new(1, 0)) })
		W:BindAccent(function(c)
			fill.BackgroundColor3 = c
			val.TextColor3 = c
		end)
		local obj = { Value = min, Type = "Slider" }
		local function snap(v)
			v = math.clamp(v, min, max)
			v = math.floor((v - min) / inc + 0.5) * inc + min
			return tonumber(string.format("%." .. dec .. "f", math.clamp(v, min, max)))
		end
		local function render()
			fill.Size = UDim2.fromScale((obj.Value - min) / math.max(max - min, 1e-9), 1)
			val.Text = string.format("%." .. dec .. "f", obj.Value) .. (cfg.Suffix or "")
		end
		function obj:Set(v, silent)
			obj.Value = snap(tonumber(v) or min)
			render()
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		local sliding, scrollRef = false, nil
		local function update(x)
			local rel = math.clamp((x - hit.AbsolutePosition.X) / math.max(hit.AbsoluteSize.X, 1), 0, 1)
			obj:Set(min + (max - min) * rel)
		end
		local function stop()
			sliding = false
			if scrollRef then
				scrollRef.ScrollingEnabled = true
				scrollRef = nil
			end
		end
		hit.InputBegan:Connect(function(i)
			if IsPointer(i) then
				sliding = true
				scrollRef = hit:FindFirstAncestorOfClass("ScrollingFrame")
				if scrollRef then scrollRef.ScrollingEnabled = false end
				update(i.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if IsPointer(i) and sliding then stop() end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if sliding and Moving(i) then update(i.Position.X) end
		end)
		local saved = cfg.Flag and W._cfg.flags[cfg.Flag]
		obj.Value = snap((saved ~= nil) and saved or cfg.Default or min)
		render()
		RegisterFlag(cfg, obj)
		if saved ~= nil then Commit(cfg, obj, false) end
		Register(r, cfg.Name)
		return obj
	end

	function E:AddTextBox(cfg)
		local r = Row()
		local fieldW = MOBILE and 112 or 124
		Lbl(r, cfg.Name, fieldW + 24)
		local f = Field(r, fieldW)
		local st = f:FindFirstChildOfClass("UIStroke")
		local tb = New("TextBox", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			Font = Enum.Font.Gotham,
			TextSize = TS - 1,
			TextColor3 = THEME.Text,
			PlaceholderText = cfg.Placeholder or "...",
			PlaceholderColor3 = THEME.Sub,
			Text = "",
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
			Parent = f,
		})
		local obj = { Value = "", Type = "TextBox" }
		function obj:Set(t, silent)
			tb.Text = tostring(t or "")
			obj.Value = tb.Text
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		tb.Focused:Connect(function()
			st.Color = W.Accent
		end)
		tb.FocusLost:Connect(function()
			st.Color = THEME.Line
			obj.Value = tb.Text
			Commit(cfg, obj, false)
		end)
		local saved = cfg.Flag and W._cfg.flags[cfg.Flag]
		tb.Text = tostring((saved ~= nil) and saved or cfg.Default or "")
		obj.Value = tb.Text
		RegisterFlag(cfg, obj)
		if saved ~= nil then Commit(cfg, obj, false) end
		Register(r, cfg.Name)
		return obj
	end

	function E:AddDropdown(cfg)
		local r = Row()
		r.ClipsDescendants = true
		local fieldW = MOBILE and 112 or 124
		Lbl(r, cfg.Name, fieldW + 24)
		local f = Field(r, fieldW)
		local cur = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -30, 1, 0),
			Font = Enum.Font.Gotham,
			TextSize = TS - 1,
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "",
			ZIndex = 4,
			Parent = f,
		})
		local chev = Chevron(f, THEME.Sub)
		chev.Position = UDim2.new(1, -8, 0.5, 0)
		chev.ZIndex = 4
		local options = cfg.Options or {}
		local optH = MOBILE and 36 or 30
		local obj = { Value = nil, Type = "Dropdown", Options = options }
		local open = false
		local btns = {}
		local function render()
			cur.Text = tostring(obj.Value or "")
			for o, b in pairs(btns) do
				b.TextColor3 = (o == obj.Value) and W.Accent or THEME.Text
			end
		end
		function obj:Set(v, silent)
			obj.Value = v
			render()
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		W:BindAccent(render)
		for i, o in ipairs(options) do
			local b = New("TextButton", {
				Position = UDim2.new(0, 6, 0, ROW_H + (i - 1) * optH),
				Size = UDim2.new(1, -12, 0, optH - 2),
				BackgroundColor3 = THEME.Panel,
				Font = Enum.Font.Gotham,
				TextSize = TS - 1,
				TextColor3 = THEME.Text,
				Text = tostring(o),
				AutoButtonColor = false,
				Parent = r,
			}, { Corner(UDim.new(0, 8)) })
			btns[o] = b
			Tap(b, function()
				open = false
				Tween(r, { Size = UDim2.new(1, 0, 0, ROW_H) })
				chev.Rotation = 0
				obj:Set(o)
			end)
		end
		Tap(Hit(r, ROW_H), function()
			open = not open
			Tween(r, { Size = UDim2.new(1, 0, 0, open and (ROW_H + 8 + #options * optH) or ROW_H) })
			Tween(chev, { Rotation = open and 180 or 0 })
		end)
		local saved = cfg.Flag and W._cfg.flags[cfg.Flag]
		obj.Value = (saved ~= nil) and saved or cfg.Default or options[1]
		render()
		RegisterFlag(cfg, obj)
		if saved ~= nil then Commit(cfg, obj, false) end
		Register(r, cfg.Name)
		return obj
	end

	return E
end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local env = (getgenv and getgenv()) or _G
	if env.AquaUIWindow then
		pcall(function() env.AquaUIWindow:Destroy() end)
	end
	for k in pairs(Library.Flags) do Library.Flags[k] = nil end
	for k in pairs(Library.Options) do Library.Options[k] = nil end
	for k in pairs(Library.Listeners) do Library.Listeners[k] = nil end
	table.clear(ticks)

	local NAME = tostring(cfg.Name or cfg.Title or "Aqua")
	local FOLDER = cfg.ConfigFolder or "AquaUI"
	CACHE_FOLDER = FOLDER

	local W = {
		Pages = {},
		AllPages = {},
		PageByName = {},
		Scale = 1,
		Open = true,
		Minimized = false,
		Accent = ACCENTS.Blue,
		_search = {},
		_accentFns = {},
		_manual = false,
		_single = false,
		_cfg = { settings = {}, flags = {} },
		Conns = {},
	}

	local cfgPath = FOLDER .. "/" .. NAME:gsub("%W", "") .. ".json"
	if HAS_FS and cfg.SaveConfig ~= false then
		pcall(function()
			if not isfolder(FOLDER) then makefolder(FOLDER) end
			if isfile(cfgPath) then
				local data = HttpService:JSONDecode(readfile(cfgPath))
				if type(data) == "table" then
					W._cfg.settings = data.settings or {}
					W._cfg.flags = data.flags or {}
				end
			end
		end)
	end
	local S = W._cfg.settings

	function W:_save()
		if not HAS_FS or cfg.SaveConfig == false or W._saving then return end
		W._saving = true
		task.delay(0.8, function()
			W._saving = false
			pcall(function()
				writefile(cfgPath, HttpService:JSONEncode(W._cfg))
			end)
		end)
	end

	function W:_setFlag(flag, value)
		W._cfg.flags[flag] = value
		W:_save()
	end

	local function Persist(key, value)
		S[key] = value
		W:_save()
	end

	function W:BindAccent(fn)
		table.insert(W._accentFns, fn)
		fn(W.Accent)
	end

	function W:SetAccent(v)
		local c = v
		if type(v) == "string" then c = ACCENTS[v] end
		if typeof(c) ~= "Color3" then return end
		W.Accent = c
		for _, f in ipairs(W._accentFns) do pcall(f, c) end
	end

	local accentSetting = cfg.Accent
	if S.accent and ACCENTS[S.accent] then accentSetting = S.accent end
	if type(accentSetting) == "string" and ACCENTS[accentSetting] then
		W.Accent = ACCENTS[accentSetting]
	elseif typeof(accentSetting) == "Color3" then
		W.Accent = accentSetting
	end

	local gui = New("ScreenGui", {
		Name = "AquaUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
		IgnoreGuiInset = true,
		Parent = GetParent(),
	})
	W.Gui = gui

	Library.Active = W

	local conn = RunService.RenderStepped:Connect(function(dt)
		for _, f in ipairs(ticks) do
			f(dt)
		end
	end)

	local wmY = cfg.WatermarkY or (MOBILE and 60 or 44)
	if cfg.Watermark ~= false then
		W.WatermarkFrame = CreateWatermark(gui, W, wmY, cfg)
		if S.watermark == false then W.WatermarkFrame.Visible = false end
	end

	local size = cfg.Size or (MOBILE and UDim2.fromOffset(760, 380) or UDim2.fromOffset(700, 430))

	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = size,
		BackgroundColor3 = THEME.BG,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	Corner(main, UDim.new(0, 16))
	Stroke(main, THEME.Line, 0)
	local uiScale = New("UIScale", { Scale = 1, Parent = main })
	W.Main = main

	local bgOpacity = S.bgOpacity or cfg.BackgroundOpacity or 0.2
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
	New("TextLabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = THEME.Text,
		Text = NAME,
		LayoutOrder = 1,
		Parent = titleBox,
	})
	local subExtras = {}
	if cfg.Subtitle then
		table.insert(subExtras, New("Frame", { Size = UDim2.fromOffset(1, 14), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, LayoutOrder = 2, Parent = titleBox }))
		table.insert(subExtras, New("TextLabel", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = THEME.Sub,
			Text = cfg.Subtitle,
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
		for _, s in ipairs(W._search) do
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

	local pageList = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -21, 1, -(ROW_H + 32)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
		Parent = side,
	}, { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -(ROW_H + 16)), Size = UDim2.new(1, -10, 0, 1), BackgroundColor3 = THEME.Line, BorderSizePixel = 0, Parent = side })

	local gearBtn = New("TextButton", {
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(ROW_H + 6, ROW_H),
		BackgroundColor3 = THEME.Select,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = side,
	})
	Corner(gearBtn, UDim.new(0, 10))
	local gear = DrawGear(gearBtn, MOBILE and 22 or 20, THEME.Sub)
	gearBtn.MouseEnter:Connect(function()
		if W._current ~= W._settings then Tween(gearBtn, { BackgroundTransparency = 0.5 }) end
	end)
	gearBtn.MouseLeave:Connect(function()
		if W._current ~= W._settings then Tween(gearBtn, { BackgroundTransparency = 1 }) end
	end)

	local pagesHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(150 + PAD, 0),
		Size = UDim2.new(1, -(150 + PAD * 2), 1, 0),
		ClipsDescendants = true,
		Parent = body,
	})

	local function SetLogoImage()
		BuildLogo(logoHolder, 20, W._logoImg, W.Accent)
		if W._toggleLogo then BuildLogo(W._toggleLogo, 20, W._logoImg, W.Accent) end
	end
	W:BindAccent(function()
		if not W._logoImg then SetLogoImage() end
	end)

	function W:SetLogo(src)
		if src == nil or src == "" then
			W._logoSrc, W._logoImg = nil, nil
			SetLogoImage()
			Persist("logo", "")
			return true
		end
		local res = ResolveImage(src, "logo", true)
		if not res then
			W:Notify({ Title = "Logo", Content = "Не удалось загрузить картинку. Укажите id, прямую ссылку или путь к файлу.", Duration = 4 })
			return false
		end
		W._logoSrc, W._logoImg = src, res
		SetLogoImage()
		Persist("logo", tostring(src))
		return true
	end

	function W:SetBackground(src)
		if src == nil or src == "" then
			bgImage.Image = ""
			bgImage.Visible = false
			Persist("bg", "")
			return true
		end
		local res = ResolveImage(src, "bg", true)
		if not res then
			W:Notify({ Title = "Background", Content = "Не удалось загрузить картинку. Укажите id, прямую ссылку или путь к файлу.", Duration = 4 })
			return false
		end
		bgImage.Image = res
		bgImage.Visible = true
		Persist("bg", tostring(src))
		return true
	end

	function W:SetBackgroundOpacity(v)
		bgOpacity = math.clamp(v, 0, 1)
		bgImage.ImageTransparency = 1 - bgOpacity
	end

	function W:SetOpacity(v)
		main.BackgroundTransparency = math.clamp(v, 0, 0.6)
	end

	local function Relayout()
		local Wd = (W.Minimized and W._full and W._full.X.Offset) or main.Size.X.Offset
		local rail = Wd < 470
		local sideW = rail and 60 or (Wd < 560 and 132 or 150)
		local contentW = Wd - sideW - PAD * 2
		local single = contentW < 380
		W._single = single
		side.Size = UDim2.new(0, sideW, 1, 0)
		pagesHolder.Position = UDim2.fromOffset(sideW + PAD, 0)
		pagesHolder.Size = UDim2.new(1, -(sideW + PAD * 2), 1, 0)
		for _, p in ipairs(W.AllPages) do
			if p.Button then
				p.Label.Visible = not rail
				p.Letter.Visible = rail and not p.HasIcon
				if p.IconImg then
					p.IconImg.Position = rail and UDim2.new(0.5, -8, 0.5, 0) or UDim2.new(0, 12, 0.5, 0)
				end
			end
			for _, s in ipairs(p.Subs) do s:_apply(single) end
		end
		local showSub = not W.Minimized and Wd >= 540
		for _, e in ipairs(subExtras) do e.Visible = showSub end
	end

	function W:Fit()
		if W.Minimized then return end
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local reserve = MOBILE and 64 or 44
		local availH = vp.Y - reserve - 10
		local bw, bh = size.X.Offset, size.Y.Offset
		local sc
		if W._manual then
			sc = W.Scale
		else
			sc = math.clamp(math.min(vp.X * 0.94 / bw, availH / bh, 1), 0.75, 1)
		end
		W.Scale = sc
		uiScale.Scale = sc
		local w = math.floor(math.min(bw, vp.X * 0.94 / sc))
		local h = math.floor(math.min(bh, availH / sc))
		main.Size = UDim2.fromOffset(w, h)
		main.Position = UDim2.new(0.5, 0, 0, reserve + math.max(0, (availH - h * sc) / 2))
		Relayout()
	end

	function W:SetScale(v)
		W._manual = true
		W.Scale = math.clamp(v, 0.5, 1.5)
		W:Fit()
	end

	function W:SetOpen(state)
		W.Open = state
		if state then
			uiScale.Scale = W.Scale * 0.92
			main.Visible = true
			Tween(uiScale, { Scale = W.Scale }, 0.25, Enum.EasingStyle.Back)
		else
			Tween(uiScale, { Scale = W.Scale * 0.92 }, 0.15)
			task.delay(0.15, function()
				if not W.Open then main.Visible = false end
			end)
		end
	end

	function W:SetMinimized(state)
		W.Minimized = state
		searchB.Visible = not state
		headLine.Visible = not state
		if state then
			searchBox.Visible = false
			searchBox.Text = ""
			W._full = main.Size
			body.Visible = false
			for _, e in ipairs(subExtras) do e.Visible = false end
			top.Size = UDim2.new(1, 0, 0, 38)
			Tween(main, { Size = UDim2.fromOffset(170, 38) }, 0.2)
		else
			top.Size = UDim2.new(1, 0, 0, HEAD_H)
			Tween(main, { Size = W._full or size }, 0.2)
			task.delay(0.22, function()
				body.Visible = not W.Minimized
				Relayout()
			end)
		end
	end

	function W:SetWatermark(v)
		if W.WatermarkFrame then W.WatermarkFrame.Visible = v end
	end

	closeB.MouseButton1Click:Connect(function() W:SetOpen(false) end)
	minB.MouseButton1Click:Connect(function() W:SetMinimized(not W.Minimized) end)

	local toggle
	if cfg.ToggleButton ~= false then
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
		W._toggleLogo = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Parent = toggle,
		})
		local dragState = MakeDraggable(toggle, toggle)
		toggle.MouseButton1Click:Connect(function()
			if not dragState.moved then W:SetOpen(not W.Open) end
		end)
		if S.openButton == false then toggle.Visible = false end
	end
	W.ToggleButton = toggle

	function W:SetToggleButton(v)
		if toggle then toggle.Visible = v end
	end

	SetLogoImage()

	local toggleKey = cfg.ToggleKey
	if toggleKey == nil and not MOBILE then toggleKey = Enum.KeyCode.RightShift end
	if toggleKey then
		table.insert(W.Conns, UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == toggleKey then W:SetOpen(not W.Open) end
		end))
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

	function W:Notify(c)
		c = c or {}
		local t = New("Frame", {
			Size = UDim2.fromOffset(toastW, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 1,
			Parent = toastHolder,
		})
		Corner(t, UDim.new(0, 12))
		local st = Stroke(t, W.Accent, 1)
		New("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = t,
		})
		New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = t })
		local a = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text, Text = tostring(c.Title or ""), TextTransparency = 1, LayoutOrder = 1, Parent = t,
		})
		local b = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Sub, Text = tostring(c.Content or ""), TextTransparency = 1, LayoutOrder = 2, Parent = t,
		})
		Tween(t, { BackgroundTransparency = 0.05 }, 0.25)
		Tween(st, { Transparency = 0.5 }, 0.25)
		Tween(a, { TextTransparency = 0 }, 0.25)
		Tween(b, { TextTransparency = 0 }, 0.25)
		task.delay(c.Duration or 4, function()
			Tween(t, { BackgroundTransparency = 1 }, 0.3)
			Tween(st, { Transparency = 1 }, 0.3)
			Tween(a, { TextTransparency = 1 }, 0.3)
			Tween(b, { TextTransparency = 1 }, 0.3)
			task.delay(0.35, function() t:Destroy() end)
		end)
	end

	local function ShowPage(page)
		for _, p in ipairs(W.AllPages) do
			p.Frame.Visible = false
			if p.Button then
				p.Indicator.Visible = false
				Tween(p.Button, { BackgroundTransparency = 1 })
				Tween(p.Label, { TextColor3 = THEME.Sub })
			end
		end
		W._current = page
		page.Frame.Visible = true
		if page.Button then
			page.Indicator.Visible = true
			Tween(page.Button, { BackgroundTransparency = 0 })
			Tween(page.Label, { TextColor3 = THEME.Text })
			W._last = page
		end
		local isSettings = page == W._settings
		Tween(gearBtn, { BackgroundTransparency = isSettings and 0 or 1 })
		gear:SetColor(isSettings and W.Accent or THEME.Sub)
	end

	Tap(gearBtn, function()
		if not W._settings then return end
		if W._current == W._settings then
			if W._last then ShowPage(W._last) end
		else
			ShowPage(W._settings)
		end
	end)
	W:BindAccent(function(c)
		if W._current and W._current == W._settings then gear:SetColor(c) end
	end)

	local function MakePage(name, iconId, hidden)
		local page = { Name = name, Subs = {}, SubByName = {}, HasIcon = ResolveImage(iconId, "icon", false) ~= nil }

		if not hidden then
			local btn = New("TextButton", {
				Size = UDim2.new(1, 0, 0, ROW_H),
				BackgroundColor3 = THEME.Select,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = #W.Pages + 1,
				Parent = pageList,
			})
			Corner(btn, UDim.new(0, 10))
			local indicator = New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(3, 16), BackgroundColor3 = W.Accent, BorderSizePixel = 0,
				Visible = false, Parent = btn,
			}, { Corner(UDim.new(1, 0)) })
			W:BindAccent(function(c) indicator.BackgroundColor3 = c end)
			page.IconImg = Icon(btn, iconId, 16, THEME.Text, UDim2.new(0, 12, 0.5, 0))
			page.Label = New("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(page.HasIcon and 36 or 14, 0),
				Size = UDim2.new(1, -(page.HasIcon and 40 or 18), 1, 0),
				Font = Enum.Font.GothamMedium, TextSize = TS,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = THEME.Sub, Text = name, Parent = btn,
			})
			page.Letter = New("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Text,
				Text = tostring(name):sub(1, 1):upper(), Visible = false, Parent = btn,
			})
			page.Button, page.Indicator = btn, indicator
			Tap(btn, function() ShowPage(page) end)
		end

		page.Frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pagesHolder })
		page.Bar = New("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 42),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			BorderSizePixel = 0,
			Visible = false,
			Parent = page.Frame,
		}, {
			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 22),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			New("UIPadding", { PaddingLeft = UDim.new(0, 4) }),
		})
		page.Area = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			Parent = page.Frame,
		})

		local function UpdateBar()
			local named = #page.Subs > 1
			for _, s in ipairs(page.Subs) do
				if s.Named then named = true end
			end
			page.Bar.Visible = named
			page.Area.Position = UDim2.fromOffset(0, named and 46 or 0)
			page.Area.Size = UDim2.new(1, 0, 1, named and -46 or 0)
			if named then
				for _, s in ipairs(page.Subs) do
					if not s.Named then s.Button.Text = page.Name end
				end
			end
		end

		local function MakeSub(subName, subIcon)
			local sub = { Named = subName ~= nil, _l = 0, _r = 0, _index = 0, _entries = {}, Sections = {} }

			local hasIcon = ResolveImage(subIcon, "icon", false) ~= nil
			local tbtn = New("TextButton", {
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = TS,
				TextColor3 = THEME.Sub,
				Text = subName or page.Name,
				LayoutOrder = #page.Subs + 1,
				Parent = page.Bar,
			})
			New("UIPadding", { PaddingLeft = UDim.new(0, hasIcon and 22 or 0), Parent = tbtn })
			Icon(tbtn, subIcon, 15, THEME.Sub, UDim2.new(0, -22, 0.5, 0))
			local underline = New("Frame", {
				AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, hasIcon and -22 or 0, 1, -2),
				Size = UDim2.new(1, hasIcon and 22 or 0, 0, 2), BackgroundColor3 = W.Accent, BorderSizePixel = 0,
				Visible = false, Parent = tbtn,
			}, { Corner(UDim.new(1, 0)) })
			W:BindAccent(function(c) underline.BackgroundColor3 = c end)

			local scroll = New("ScrollingFrame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = MOBILE and 0 or 3,
				ScrollBarImageColor3 = THEME.Line,
				BorderSizePixel = 0,
				Visible = false,
				Parent = page.Area,
			}, {
				New("UIPadding", {
					PaddingTop = UDim.new(0, 4),
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, MOBILE and 4 or 10),
					PaddingBottom = UDim.new(0, 16),
				}),
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
			sub.Left, sub.Right = Column(0, 0), Column(0.5, 6)
			sub.Scroll, sub.Button, sub.Underline = scroll, tbtn, underline

			function sub:_apply(single)
				sub.Left.Size = single and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0)
				sub.Right.Visible = not single
				for _, e in ipairs(sub._entries) do
					if single then
						e.frame.Parent = sub.Left
						e.frame.LayoutOrder = e.index
					else
						e.frame.Parent = e.side == "Right" and sub.Right or sub.Left
						e.frame.LayoutOrder = e.colOrder
					end
				end
			end

			local function SelectSub()
				for _, t in ipairs(page.Subs) do
					t.Scroll.Visible = false
					t.Underline.Visible = false
					Tween(t.Button, { TextColor3 = THEME.Sub })
				end
				scroll.Visible = true
				underline.Visible = true
				Tween(tbtn, { TextColor3 = THEME.Text })
			end
			Tap(tbtn, SelectSub)
			table.insert(page.Subs, sub)
			if #page.Subs == 1 then SelectSub() end
			UpdateBar()

			function sub:AddSection(scfg)
				scfg = scfg or {}
				local useRight = (scfg.Position == "Right") or (scfg.Position == nil and sub._l > sub._r)
				if useRight then sub._r += 1 else sub._l += 1 end
				sub._index += 1

				local card = New("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = THEME.Panel,
					Parent = useRight and sub.Right or sub.Left,
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
					index = sub._index,
					colOrder = useRight and sub._r or sub._l,
				}
				card.LayoutOrder = entry.colOrder
				table.insert(sub._entries, entry)
				if W._single then sub:_apply(true) end

				local head = New("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
				local hasI = ResolveImage(scfg.Icon, "icon", false) ~= nil
				Icon(head, scfg.Icon, 17, THEME.Text, UDim2.new(0, 0, 0.5, 0))
				New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(hasI and 26 or 0, 0),
					Size = UDim2.new(1, -(hasI and 26 or 0), 1, 0),
					Font = Enum.Font.GothamBold, TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColor3 = THEME.Text, Text = tostring(scfg.Name or ""), Parent = head,
				})
				local E = Elements(card, W, card)
				if scfg.Name then sub.Sections[scfg.Name] = E end
				return E
			end

			function sub:Section(sname, position, icon)
				return sub.Sections[sname] or sub:AddSection({ Name = sname, Position = position, Icon = icon })
			end

			return sub
		end

		function page:SubTab(subName, subIcon)
			if page.SubByName[subName] then return page.SubByName[subName] end
			local s = MakeSub(subName, subIcon)
			page.SubByName[subName] = s
			return s
		end

		function page:Section(sname, position, icon)
			if not page.Default then page.Default = MakeSub(nil, nil) end
			return page.Default:Section(sname, position, icon)
		end

		function page:AddSection(scfg)
			if not page.Default then page.Default = MakeSub(nil, nil) end
			return page.Default:AddSection(scfg)
		end

		table.insert(W.AllPages, page)
		if not hidden then
			table.insert(W.Pages, page)
			if not W._current then ShowPage(page) end
		end
		return page
	end

	function W:Tab(name, icon)
		if W.PageByName[name] then return W.PageByName[name] end
		local p = MakePage(name, icon, false)
		W.PageByName[name] = p
		Relayout()
		return p
	end

	function W:AddTab(tcfg)
		tcfg = tcfg or {}
		return W:Tab(tcfg.Name, tcfg.Icon)
	end

	W._settings = MakePage("Settings", nil, true)

	if S.manual and S.scale then
		W._manual = true
		W.Scale = S.scale
	end
	if S.opacity then W:SetOpacity(S.opacity) end

	if cfg.SettingsPage ~= false then
		local interface = W._settings:SubTab("Interface")
		local window = interface:Section("Window", "Left")
		local autoFit, scaleSlider
		autoFit = window:AddToggle({
			Name = "Auto Fit",
			Default = not W._manual,
			Callback = function(v)
				if v then
					W._manual = false
					Persist("manual", false)
					W:Fit()
					if scaleSlider then scaleSlider:Set(W.Scale * 100, true) end
				else
					W._manual = true
					Persist("manual", true)
					Persist("scale", W.Scale)
				end
			end,
		})
		scaleSlider = window:AddSlider({
			Name = "UI Scale", Min = 50, Max = 150, Default = math.floor(W.Scale * 100 + 0.5), Suffix = "%",
			Callback = function(v)
				if autoFit:Get() then autoFit:Set(false, true) end
				W:SetScale(v / 100)
				Persist("manual", true)
				Persist("scale", v / 100)
			end,
		})
		window:AddSlider({
			Name = "Window Opacity", Min = 0, Max = 40, Default = math.floor((S.opacity or 0) * 100 + 0.5), Suffix = "%",
			Callback = function(v)
				W:SetOpacity(v / 100)
				Persist("opacity", v / 100)
			end,
		})

		local display = interface:Section("Display", "Right")
		display:AddDropdown({
			Name = "Accent", Options = ACCENT_NAMES,
			Default = (S.accent and ACCENTS[S.accent]) and S.accent or "Blue",
			Callback = function(v)
				W:SetAccent(v)
				Persist("accent", v)
			end,
		})
		display:AddToggle({
			Name = "Watermark", Default = S.watermark ~= false and cfg.Watermark ~= false,
			Callback = function(v)
				W:SetWatermark(v)
				Persist("watermark", v)
			end,
		})
		display:AddToggle({
			Name = "Open Button", Default = S.openButton ~= false and cfg.ToggleButton ~= false,
			Callback = function(v)
				W:SetToggleButton(v)
				Persist("openButton", v)
			end,
		})

		local branding = W._settings:SubTab("Branding")
		local logo = branding:Section("Logo", "Left")
		local logoBox = logo:AddTextBox({
			Name = "Image", Placeholder = "id / url / file", Default = S.logo or "",
			Callback = function(v)
				task.spawn(function() W:SetLogo(v) end)
			end,
		})
		logo:AddButton({
			Name = "Logo", ButtonText = "Clear",
			Callback = function()
				logoBox:Set("", true)
				W:SetLogo(nil)
			end,
		})
		local bg = branding:Section("Background", "Right")
		local bgBox = bg:AddTextBox({
			Name = "Image", Placeholder = "id / url / file", Default = S.bg or "",
			Callback = function(v)
				task.spawn(function() W:SetBackground(v) end)
			end,
		})
		bg:AddSlider({
			Name = "Image opacity", Min = 0, Max = 100, Default = math.floor(bgOpacity * 100 + 0.5), Suffix = "%",
			Callback = function(v)
				W:SetBackgroundOpacity(v / 100)
				Persist("bgOpacity", v / 100)
			end,
		})
		bg:AddButton({
			Name = "Background", ButtonText = "Clear",
			Callback = function()
				bgBox:Set("", true)
				W:SetBackground(nil)
			end,
		})

		local data = W._settings:SubTab("Data")
		local reset = data:Section("Settings", "Left")
		reset:AddButton({
			Name = "Reset settings", ButtonText = "Reset",
			Callback = function()
				W._cfg.settings = {}
				W._cfg.flags = {}
				S = W._cfg.settings
				W:_save()
				W:Notify({ Title = "Aqua", Content = "Настройки сброшены. Перезапустите скрипт.", Duration = 4 })
			end,
		})
		reset:AddButton({
			Name = "Unload interface", ButtonText = "Unload",
			Callback = function() W:Destroy() end,
		})
	end

	local logoSrc = (S.logo and S.logo ~= "") and S.logo or cfg.Logo
	if logoSrc then task.spawn(function() W:SetLogo(logoSrc) end) end
	local bgSrc = (S.bg and S.bg ~= "") and S.bg or cfg.Background
	if bgSrc then task.spawn(function() W:SetBackground(bgSrc) end) end

	W:Fit()
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(W.Conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			W:Fit()
		end))
	end

	function W:Ready() end

	function W:Destroy()
		conn:Disconnect()
		for _, c in ipairs(W.Conns) do pcall(function() c:Disconnect() end) end
		gui:Destroy()
		if Library.Active == W then Library.Active = nil end
		if env.AquaUIWindow == W then env.AquaUIWindow = nil end
	end

	env.AquaUIWindow = W
	Library.Active = W

	return W
end

return Library
