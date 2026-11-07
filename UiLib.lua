--[[
  UnflyUi — Crystal Azure
  Clean glass UI · blue logo palette · logo & background photos
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

local Library = {
	Flags = {},
	Options = {},
	Listeners = {},
	Windows = {},
	Version = "2.0.0-crystal",
}

local T = {
	Bg = Color3.fromRGB(8, 12, 28),
	Panel = Color3.fromRGB(12, 18, 40),
	Sidebar = Color3.fromRGB(10, 14, 32),
	Card = Color3.fromRGB(16, 24, 52),
	CardHover = Color3.fromRGB(22, 34, 68),
	Inner = Color3.fromRGB(14, 22, 48),
	Field = Color3.fromRGB(20, 32, 64),
	Line = Color3.fromRGB(60, 120, 220),
	Text = Color3.fromRGB(230, 240, 255),
	Dim = Color3.fromRGB(130, 155, 200),
	Muted = Color3.fromRGB(90, 115, 160),
	Accent = Color3.fromRGB(70, 160, 255),
	Accent2 = Color3.fromRGB(120, 200, 255),
	Glow = Color3.fromRGB(80, 180, 255),
	Success = Color3.fromRGB(80, 220, 160),
	Danger = Color3.fromRGB(255, 100, 130),
	Knob = Color3.fromRGB(240, 248, 255),
}

local function tween(obj, props, t, style, dir)
	local ti = TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local tw = TweenService:Create(obj, ti, props)
	tw:Play()
	return tw
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or T.Line
	s.Thickness = thickness or 1
	s.Transparency = trans or 0.55
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c0 or T.Accent),
		ColorSequenceKeypoint.new(1, c1 or T.Accent2),
	})
	g.Rotation = rot or 90
	g.Parent = parent
	return g
end

local function pad(parent, l, t, r, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l or 10)
	p.PaddingTop = UDim.new(0, t or l or 10)
	p.PaddingRight = UDim.new(0, r or l or 10)
	p.PaddingBottom = UDim.new(0, b or t or l or 10)
	p.Parent = parent
	return p
end

local function list(parent, dir, gap)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap or 8)
	l.Parent = parent
	return l
end

local function protect(gui)
	pcall(function()
		if gethui then
			gui.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = CoreGui
		else
			gui.Parent = CoreGui
		end
	end)
	if not gui.Parent then
		gui.Parent = LP:WaitForChild("PlayerGui")
	end
end

local function asset(id)
	if id == nil or id == "" or id == 0 then
		return ""
	end
	if type(id) == "number" then
		return "rbxassetid://" .. tostring(id)
	end
	id = tostring(id)
	if id:match("^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

local function loadHttpImage(url, fileName)
	if type(url) ~= "string" or not url:find("^https?://") then
		return asset(url)
	end
	local ok, result = pcall(function()
		local data = game:HttpGet(url)
		if type(data) ~= "string" or #data < 100 then
			error("empty image")
		end
		local folder = "UnflyUi"
		if isfolder and not isfolder(folder) and makefolder then
			makefolder(folder)
		end
		local path = folder .. "/" .. (fileName or "img.png")
		if writefile then
			writefile(path, data)
		else
			error("writefile missing")
		end
		if getcustomasset then
			return getcustomasset(path)
		end
		if getcustomasset == nil and syn and syn.getcustomasset then
			return syn.getcustomasset(path)
		end
		error("getcustomasset missing")
	end)
	if ok and type(result) == "string" and #result > 0 then
		return result
	end
	warn("[UnflyUi] image load failed:", url, result)
	return ""
end

function Library:Notify(opts)
	opts = opts or {}
	local title = opts.Title or "Unfly"
	local content = opts.Content or ""
	local dur = opts.Duration or 3

	local host = CoreGui:FindFirstChild("UnflyNotifyHost")
	if not host then
		host = Instance.new("ScreenGui")
		host.Name = "UnflyNotifyHost"
		host.ResetOnSpawn = false
		host.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		protect(host)
		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(0, 320, 1, 0)
		holder.Position = UDim2.new(1, -340, 0, 20)
		holder.Parent = host
		list(holder, Enum.FillDirection.Vertical, 10)
	end
	local holder = host:FindFirstChild("Holder")

	local card = Instance.new("Frame")
	card.BackgroundColor3 = T.Card
	card.BackgroundTransparency = 0.08
	card.Size = UDim2.new(1, 0, 0, 72)
	card.Parent = holder
	corner(card, 12)
	stroke(card, T.Accent, 1.2, 0.4)
	gradient(card, Color3.fromRGB(20, 40, 90), Color3.fromRGB(12, 20, 50), 120)

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = T.Accent
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0, 4, 1, -16)
	bar.Position = UDim2.new(0, 8, 0, 8)
	bar.Parent = card
	corner(bar, 3)

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextColor3 = T.Text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title
	t.Size = UDim2.new(1, -28, 0, 22)
	t.Position = UDim2.new(0, 22, 0, 10)
	t.Parent = card

	local c = Instance.new("TextLabel")
	c.BackgroundTransparency = 1
	c.Font = Enum.Font.Gotham
	c.TextSize = 12
	c.TextColor3 = T.Dim
	c.TextXAlignment = Enum.TextXAlignment.Left
	c.TextWrapped = true
	c.Text = content
	c.Size = UDim2.new(1, -28, 0, 30)
	c.Position = UDim2.new(0, 22, 0, 32)
	c.Parent = card

	card.BackgroundTransparency = 1
	tween(card, { BackgroundTransparency = 0.08 }, 0.25)
	task.delay(dur, function()
		tween(card, { BackgroundTransparency = 1 }, 0.25)
		task.wait(0.3)
		card:Destroy()
	end)
end

function Library:OnChanged(flag, fn)
	self.Listeners[flag] = self.Listeners[flag] or {}
	table.insert(self.Listeners[flag], fn)
end

function Library:_fire(flag, value)
	self.Flags[flag] = value
	local list = self.Listeners[flag]
	if list then
		for _, fn in ipairs(list) do
			pcall(fn, value)
		end
	end
end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local accent = cfg.Accent or T.Accent
	local neon = cfg.Neon or T.Accent2
	T.Accent = accent
	T.Accent2 = neon

	local gui = Instance.new("ScreenGui")
	gui.Name = cfg.GuiName or "UnflyCrystal"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	protect(gui)

	local scale = Instance.new("UIScale")
	scale.Scale = cfg.Scale or 1
	scale.Parent = gui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = T.Bg
	root.BackgroundTransparency = cfg.Transparency or 0.06
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(cfg.Width or 780, cfg.Height or 520)
	root.Position = UDim2.new(0.5, -(cfg.Width or 780) / 2, 0.5, -(cfg.Height or 520) / 2)
	root.Parent = gui
	corner(root, 16)
	stroke(root, accent, 1.4, 0.35)
	gradient(root, Color3.fromRGB(14, 28, 70), Color3.fromRGB(6, 10, 24), 145)

	-- Background photo
	local bgPhoto = Instance.new("ImageLabel")
	bgPhoto.Name = "BackgroundPhoto"
	bgPhoto.BackgroundTransparency = 1
	bgPhoto.Size = UDim2.fromScale(1, 1)
	bgPhoto.ScaleType = Enum.ScaleType.Crop
	bgPhoto.ImageTransparency = 1
	bgPhoto.ZIndex = 0
	bgPhoto.Parent = root
	corner(bgPhoto, 16)
	if cfg.BackgroundImage then
		bgPhoto.ImageTransparency = cfg.BackgroundTransparency or 0.55
		bgPhoto.ImageColor3 = cfg.BackgroundTint or Color3.fromRGB(140, 180, 255)
		task.spawn(function()
			local img = loadHttpImage(cfg.BackgroundImage, "background.png")
			if img ~= "" then
				bgPhoto.Image = img
			end
		end)
	end

	local bgVeil = Instance.new("Frame")
	bgVeil.Name = "Veil"
	bgVeil.BackgroundColor3 = Color3.fromRGB(8, 14, 36)
	bgVeil.BackgroundTransparency = 0.35
	bgVeil.BorderSizePixel = 0
	bgVeil.Size = UDim2.fromScale(1, 1)
	bgVeil.ZIndex = 1
	bgVeil.Parent = root
	corner(bgVeil, 16)
	gradient(bgVeil, Color3.fromRGB(30, 90, 200), Color3.fromRGB(8, 20, 50), 160)

	-- Sidebar
	local sideW = cfg.SidebarWidth or 200
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundColor3 = T.Sidebar
	sidebar.BackgroundTransparency = 0.15
	sidebar.BorderSizePixel = 0
	sidebar.Size = UDim2.new(0, sideW, 1, 0)
	sidebar.ZIndex = 2
	sidebar.Parent = root
	corner(sidebar, 16)

	local sideMask = Instance.new("Frame")
	sideMask.BackgroundTransparency = 1
	sideMask.Size = UDim2.new(1, 0, 1, 0)
	sideMask.Parent = sidebar

	-- Brand / logo
	local brand = Instance.new("Frame")
	brand.Name = "Brand"
	brand.BackgroundTransparency = 1
	brand.Size = UDim2.new(1, -20, 0, 64)
	brand.Position = UDim2.new(0, 10, 0, 10)
	brand.ZIndex = 3
	brand.Parent = sidebar

	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.BackgroundColor3 = T.Card
	logo.BackgroundTransparency = 0.3
	logo.Size = UDim2.fromOffset(42, 42)
	logo.Position = UDim2.new(0, 4, 0.5, -21)
	logo.ScaleType = Enum.ScaleType.Fit
	logo.ZIndex = 4
	logo.Parent = brand
	corner(logo, 10)
	stroke(logo, accent, 1, 0.4)
	if cfg.Logo or cfg.LogoImage then
		task.spawn(function()
			logo.Image = loadHttpImage(cfg.Logo or cfg.LogoImage, "logo.png")
			if float then
				float.Image = logo.Image
			end
		end)
	else
		logo.Image = ""
		local logoText = Instance.new("TextLabel")
		logoText.BackgroundTransparency = 1
		logoText.Size = UDim2.fromScale(1, 1)
		logoText.Font = Enum.Font.GothamBlack
		logoText.TextSize = 18
		logoText.TextColor3 = accent
		logoText.Text = (cfg.Name or "U"):sub(1, 1)
		logoText.ZIndex = 5
		logoText.Parent = logo
	end

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = T.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = cfg.Name or "Unfly"
	title.Size = UDim2.new(1, -60, 0, 22)
	title.Position = UDim2.new(0, 54, 0, 10)
	title.ZIndex = 4
	title.Parent = brand

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 11
	subtitle.TextColor3 = T.Dim
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = cfg.Tagline or cfg.Subtitle or "Crystal UI"
	subtitle.Size = UDim2.new(1, -60, 0, 16)
	subtitle.Position = UDim2.new(0, 54, 0, 34)
	subtitle.ZIndex = 4
	subtitle.Parent = brand

	local nav = Instance.new("ScrollingFrame")
	nav.Name = "Nav"
	nav.BackgroundTransparency = 1
	nav.BorderSizePixel = 0
	nav.Size = UDim2.new(1, -12, 1, -140)
	nav.Position = UDim2.new(0, 6, 0, 80)
	nav.ScrollBarThickness = 2
	nav.ScrollBarImageColor3 = accent
	nav.CanvasSize = UDim2.new(0, 0, 0, 0)
	nav.AutomaticCanvasSize = Enum.AutomaticSize.Y
	nav.ZIndex = 3
	nav.Parent = sidebar
	list(nav, Enum.FillDirection.Vertical, 4)
	pad(nav, 4, 4, 4, 4)

	local foot = Instance.new("TextLabel")
	foot.BackgroundTransparency = 1
	foot.Font = Enum.Font.Gotham
	foot.TextSize = 10
	foot.TextColor3 = T.Muted
	foot.Text = cfg.Footer or ("v" .. Library.Version)
	foot.Size = UDim2.new(1, -20, 0, 20)
	foot.Position = UDim2.new(0, 10, 1, -36)
	foot.ZIndex = 3
	foot.Parent = sidebar

	-- Content area
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -(sideW + 16), 1, -16)
	content.Position = UDim2.new(0, sideW + 8, 0, 8)
	content.ZIndex = 2
	content.Parent = root

	local topBar = Instance.new("Frame")
	topBar.BackgroundTransparency = 1
	topBar.Size = UDim2.new(1, 0, 0, 36)
	topBar.ZIndex = 3
	topBar.Parent = content

	local pageTitle = Instance.new("TextLabel")
	pageTitle.BackgroundTransparency = 1
	pageTitle.Font = Enum.Font.GothamBold
	pageTitle.TextSize = 18
	pageTitle.TextColor3 = T.Text
	pageTitle.TextXAlignment = Enum.TextXAlignment.Left
	pageTitle.Text = "Home"
	pageTitle.Size = UDim2.new(1, -80, 1, 0)
	pageTitle.ZIndex = 4
	pageTitle.Parent = topBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "×"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 22
	closeBtn.TextColor3 = T.Dim
	closeBtn.BackgroundColor3 = T.Card
	closeBtn.BackgroundTransparency = 0.4
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.Position = UDim2.new(1, -32, 0, 2)
	closeBtn.ZIndex = 5
	closeBtn.Parent = topBar
	corner(closeBtn, 8)

	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.Size = UDim2.new(1, 0, 1, -44)
	pages.Position = UDim2.new(0, 0, 0, 44)
	pages.ZIndex = 3
	pages.Parent = content

	-- Drag
	local dragging, dragStart, startPos
	brand.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	local visible = true
	local function setVisible(v)
		visible = v
		root.Visible = v
	end
	closeBtn.MouseButton1Click:Connect(function()
		setVisible(false)
	end)

	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == toggleKey then
			setVisible(not visible)
		end
	end)

	-- Floating reopen button
	local float = Instance.new("ImageButton")
	float.Name = "Float"
	float.Size = UDim2.fromOffset(48, 48)
	float.Position = UDim2.new(0, 18, 1, -70)
	float.BackgroundColor3 = T.Card
	float.BackgroundTransparency = 0.15
	float.Image = cfg.Logo and asset(cfg.Logo) or ""
	float.ScaleType = Enum.ScaleType.Fit
	float.ZIndex = 20
	float.Visible = false
	float.Parent = gui
	corner(float, 12)
	stroke(float, accent, 1.2, 0.3)
	if not cfg.Logo then
		local ft = Instance.new("TextLabel")
		ft.BackgroundTransparency = 1
		ft.Size = UDim2.fromScale(1, 1)
		ft.Font = Enum.Font.GothamBlack
		ft.TextSize = 18
		ft.TextColor3 = accent
		ft.Text = (cfg.Name or "U"):sub(1, 1)
		ft.Parent = float
	end
	float.MouseButton1Click:Connect(function()
		setVisible(true)
		float.Visible = false
	end)
	closeBtn.MouseButton1Click:Connect(function()
		float.Visible = true
	end)

	local Window = {
		Gui = gui,
		Root = root,
		Tabs = {},
		TabList = {},
		Current = nil,
		Flags = Library.Flags,
	}

	function Window:SetBackgroundImage(image, transparency, tint)
		bgPhoto.ImageTransparency = transparency or 0.55
		if tint then bgPhoto.ImageColor3 = tint end
		task.spawn(function()
			local img = loadHttpImage(image, "background.png")
			if img ~= "" then
				bgPhoto.Image = img
			end
		end)
	end

	function Window:SetLogo(image)
		for _, ch in ipairs(logo:GetChildren()) do
			if ch:IsA("TextLabel") then ch:Destroy() end
		end
		task.spawn(function()
			local img = loadHttpImage(image, "logo.png")
			if img ~= "" then
				logo.Image = img
				float.Image = img
			end
		end)
	end

	function Window:SetVisible(v)
		setVisible(v)
		float.Visible = not v
	end

	function Window:Notify(opts)
		Library:Notify(opts)
	end

	function Window:Tab(name, icon)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = T.Card
		btn.BackgroundTransparency = 1
		btn.Size = UDim2.new(1, 0, 0, 40)
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 13
		btn.TextColor3 = T.Dim
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Text = "  " .. tostring(name)
		btn.ZIndex = 4
		btn.Parent = nav
		corner(btn, 10)

		local indicator = Instance.new("Frame")
		indicator.BackgroundColor3 = accent
		indicator.BorderSizePixel = 0
		indicator.Size = UDim2.new(0, 3, 0, 18)
		indicator.Position = UDim2.new(0, 4, 0.5, -9)
		indicator.BackgroundTransparency = 1
		indicator.ZIndex = 5
		indicator.Parent = btn
		corner(indicator, 2)

		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.fromScale(1, 1)
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = accent
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible = false
		page.ZIndex = 3
		page.Parent = pages

		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = page

		local leftCol = Instance.new("Frame")
		leftCol.Name = "Left"
		leftCol.BackgroundTransparency = 1
		leftCol.Size = UDim2.new(0.5, -6, 0, 0)
		leftCol.AutomaticSize = Enum.AutomaticSize.Y
		leftCol.Parent = grid
		list(leftCol, Enum.FillDirection.Vertical, 10)
		pad(leftCol, 2, 2, 2, 2)

		local rightCol = Instance.new("Frame")
		rightCol.Name = "Right"
		rightCol.BackgroundTransparency = 1
		rightCol.Size = UDim2.new(0.5, -6, 0, 0)
		rightCol.Position = UDim2.new(0.5, 6, 0, 0)
		rightCol.AutomaticSize = Enum.AutomaticSize.Y
		rightCol.Parent = grid
		list(rightCol, Enum.FillDirection.Vertical, 10)
		pad(rightCol, 2, 2, 2, 2)

		local fullCol = Instance.new("Frame")
		fullCol.Name = "Full"
		fullCol.BackgroundTransparency = 1
		fullCol.Size = UDim2.new(1, 0, 0, 0)
		fullCol.AutomaticSize = Enum.AutomaticSize.Y
		fullCol.Parent = page
		list(fullCol, Enum.FillDirection.Vertical, 10)
		pad(fullCol, 2, 2, 2, 2)

		-- layout: full under grid
		local pageLayout = Instance.new("UIListLayout")
		pageLayout.FillDirection = Enum.FillDirection.Vertical
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Padding = UDim.new(0, 10)
		pageLayout.Parent = page
		grid.LayoutOrder = 1
		fullCol.LayoutOrder = 2

		local Tab = { Name = name, Page = page, Button = btn }

		local function selectTab()
			for _, t in ipairs(Window.TabList) do
				t.Page.Visible = false
				t.Button.BackgroundTransparency = 1
				t.Button.TextColor3 = T.Dim
				local ind = t.Button:FindFirstChildOfClass("Frame")
				if ind then ind.BackgroundTransparency = 1 end
			end
			page.Visible = true
			btn.BackgroundTransparency = 0.35
			btn.TextColor3 = T.Text
			indicator.BackgroundTransparency = 0
			pageTitle.Text = name
			Window.Current = Tab
		end

		btn.MouseButton1Click:Connect(selectTab)
		btn.MouseEnter:Connect(function()
			if Window.Current ~= Tab then
				tween(btn, { BackgroundTransparency = 0.7 }, 0.15)
			end
		end)
		btn.MouseLeave:Connect(function()
			if Window.Current ~= Tab then
				tween(btn, { BackgroundTransparency = 1 }, 0.15)
			end
		end)

		function Tab:Section(secName, position)
			position = position or "left"
			local parent = leftCol
			if position == "right" then parent = rightCol end
			if position == "full" then parent = fullCol end

			local card = Instance.new("Frame")
			card.Name = secName
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.2
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.ZIndex = 4
			card.Parent = parent
			corner(card, 12)
			stroke(card, Color3.fromRGB(70, 130, 220), 1, 0.65)

			local head = Instance.new("TextLabel")
			head.BackgroundTransparency = 1
			head.Font = Enum.Font.GothamBold
			head.TextSize = 14
			head.TextColor3 = T.Text
			head.TextXAlignment = Enum.TextXAlignment.Left
			head.Text = secName
			head.Size = UDim2.new(1, -20, 0, 28)
			head.Position = UDim2.new(0, 14, 0, 8)
			head.ZIndex = 5
			head.Parent = card

			local body = Instance.new("Frame")
			body.BackgroundTransparency = 1
			body.Size = UDim2.new(1, 0, 0, 0)
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.Position = UDim2.new(0, 0, 0, 36)
			body.ZIndex = 5
			body.Parent = card
			list(body, Enum.FillDirection.Vertical, 6)
			pad(body, 12, 4, 12, 12)

			local Section = {}

			local function row()
				local r = Instance.new("Frame")
				r.BackgroundColor3 = T.Inner
				r.BackgroundTransparency = 0.35
				r.Size = UDim2.new(1, 0, 0, 40)
				r.ZIndex = 5
				r.Parent = body
				corner(r, 10)
				return r
			end

			function Section:Toggle(text, default, callback)
				local flag = text
				local state = default == true
				Library.Flags[flag] = state

				local r = row()
				local lbl = Instance.new("TextLabel")
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 13
				lbl.TextColor3 = T.Text
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Text = text
				lbl.Size = UDim2.new(1, -70, 1, 0)
				lbl.Position = UDim2.new(0, 12, 0, 0)
				lbl.ZIndex = 6
				lbl.Parent = r

				local track = Instance.new("Frame")
				track.Size = UDim2.fromOffset(42, 22)
				track.Position = UDim2.new(1, -54, 0.5, -11)
				track.BackgroundColor3 = state and accent or T.Field
				track.ZIndex = 6
				track.Parent = r
				corner(track, 11)

				local knob = Instance.new("Frame")
				knob.Size = UDim2.fromOffset(18, 18)
				knob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
				knob.BackgroundColor3 = T.Knob
				knob.ZIndex = 7
				knob.Parent = track
				corner(knob, 9)

				local hit = Instance.new("TextButton")
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 8
				hit.Parent = r

				local function apply(v, fire)
					state = v
					Library.Flags[flag] = v
					tween(track, { BackgroundColor3 = v and accent or T.Field }, 0.15)
					tween(knob, { Position = v and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }, 0.15)
					if fire and callback then pcall(callback, v) end
					Library:_fire(flag, v)
				end
				hit.MouseButton1Click:Connect(function() apply(not state, true) end)
				return {
					Set = function(_, v) apply(v == true, true) end,
					Get = function() return state end,
				}
			end

			function Section:Slider(text, min, max, default, callback)
				min, max = min or 0, max or 100
				local value = tonumber(default) or min
				Library.Flags[text] = value

				local r = Instance.new("Frame")
				r.BackgroundColor3 = T.Inner
				r.BackgroundTransparency = 0.35
				r.Size = UDim2.new(1, 0, 0, 54)
				r.ZIndex = 5
				r.Parent = body
				corner(r, 10)

				local lbl = Instance.new("TextLabel")
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 13
				lbl.TextColor3 = T.Text
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Text = text
				lbl.Size = UDim2.new(1, -60, 0, 20)
				lbl.Position = UDim2.new(0, 12, 0, 6)
				lbl.ZIndex = 6
				lbl.Parent = r

				local val = Instance.new("TextLabel")
				val.BackgroundTransparency = 1
				val.Font = Enum.Font.GothamBold
				val.TextSize = 12
				val.TextColor3 = accent
				val.TextXAlignment = Enum.TextXAlignment.Right
				val.Text = tostring(value)
				val.Size = UDim2.new(0, 48, 0, 20)
				val.Position = UDim2.new(1, -56, 0, 6)
				val.ZIndex = 6
				val.Parent = r

				local track = Instance.new("Frame")
				track.BackgroundColor3 = T.Field
				track.Size = UDim2.new(1, -24, 0, 6)
				track.Position = UDim2.new(0, 12, 0, 36)
				track.ZIndex = 6
				track.Parent = r
				corner(track, 3)

				local fill = Instance.new("Frame")
				fill.BackgroundColor3 = accent
				fill.BorderSizePixel = 0
				fill.Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0)
				fill.ZIndex = 7
				fill.Parent = track
				corner(fill, 3)
				gradient(fill, accent, neon, 0)

				local sliding = false
				local function set(v, fire)
					v = math.clamp(tonumber(v) or min, min, max)
					value = math.floor(v + 0.5)
					Library.Flags[text] = value
					val.Text = tostring(value)
					fill.Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0)
					if fire and callback then pcall(callback, value) end
					Library:_fire(text, value)
				end

				track.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						sliding = true
					end
				end)
				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						sliding = false
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if not sliding then return end
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
						set(min + (max - min) * rel, true)
					end
				end)
				return { Set = function(_, v) set(v, true) end, Get = function() return value end }
			end

			function Section:Button(text, callback)
				local r = row()
				r.BackgroundColor3 = accent
				r.BackgroundTransparency = 0.15
				local lbl = Instance.new("TextLabel")
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamBold
				lbl.TextSize = 13
				lbl.TextColor3 = T.Text
				lbl.Text = text
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.ZIndex = 6
				lbl.Parent = r
				local hit = Instance.new("TextButton")
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 7
				hit.Parent = r
				hit.MouseButton1Click:Connect(function()
					if callback then pcall(callback) end
				end)
				hit.MouseEnter:Connect(function() tween(r, { BackgroundTransparency = 0 }, 0.12) end)
				hit.MouseLeave:Connect(function() tween(r, { BackgroundTransparency = 0.15 }, 0.12) end)
			end

			function Section:Label(text)
				local r = row()
				r.BackgroundTransparency = 0.6
				local lbl = Instance.new("TextLabel")
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 12
				lbl.TextColor3 = T.Dim
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Text = text
				lbl.Size = UDim2.new(1, -20, 1, 0)
				lbl.Position = UDim2.new(0, 12, 0, 0)
				lbl.ZIndex = 6
				lbl.Parent = r
			end

			function Section:Dropdown(text, options, default, callback)
				options = options or {}
				local value = default or options[1]
				Library.Flags[text] = value
				local open = false

				local r = row()
				local lbl = Instance.new("TextLabel")
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 13
				lbl.TextColor3 = T.Text
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Text = text
				lbl.Size = UDim2.new(0.45, 0, 1, 0)
				lbl.Position = UDim2.new(0, 12, 0, 0)
				lbl.ZIndex = 6
				lbl.Parent = r

				local val = Instance.new("TextLabel")
				val.BackgroundTransparency = 1
				val.Font = Enum.Font.GothamBold
				val.TextSize = 12
				val.TextColor3 = accent
				val.TextXAlignment = Enum.TextXAlignment.Right
				val.Text = tostring(value) .. "  ▾"
				val.Size = UDim2.new(0.5, -16, 1, 0)
				val.Position = UDim2.new(0.5, 0, 0, 0)
				val.ZIndex = 6
				val.Parent = r

				local menu = Instance.new("Frame")
				menu.BackgroundColor3 = T.Panel
				menu.Visible = false
				menu.Size = UDim2.new(1, 0, 0, math.min(#options, 5) * 32 + 8)
				menu.ZIndex = 20
				menu.Parent = body
				corner(menu, 10)
				stroke(menu, accent, 1, 0.5)
				list(menu, Enum.FillDirection.Vertical, 2)
				pad(menu, 4, 4, 4, 4)

				for _, opt in ipairs(options) do
					local ob = Instance.new("TextButton")
					ob.BackgroundColor3 = T.Inner
					ob.BackgroundTransparency = 0.3
					ob.Size = UDim2.new(1, 0, 0, 28)
					ob.Font = Enum.Font.Gotham
					ob.TextSize = 12
					ob.TextColor3 = T.Text
					ob.Text = tostring(opt)
					ob.ZIndex = 21
					ob.Parent = menu
					corner(ob, 6)
					ob.MouseButton1Click:Connect(function()
						value = opt
						Library.Flags[text] = value
						val.Text = tostring(value) .. "  ▾"
						menu.Visible = false
						open = false
						if callback then pcall(callback, value) end
						Library:_fire(text, value)
					end)
				end

				local hit = Instance.new("TextButton")
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 7
				hit.Parent = r
				hit.MouseButton1Click:Connect(function()
					open = not open
					menu.Visible = open
				end)
			end

			function Section:Color(text, default, callback)
				local color = default or accent
				Library.Flags[text] = color
				local r = row()
				local lbl = Instance.new("TextLabel")
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 13
				lbl.TextColor3 = T.Text
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Text = text
				lbl.Size = UDim2.new(1, -70, 1, 0)
				lbl.Position = UDim2.new(0, 12, 0, 0)
				lbl.ZIndex = 6
				lbl.Parent = r

				local swatch = Instance.new("TextButton")
				swatch.Size = UDim2.fromOffset(28, 28)
				swatch.Position = UDim2.new(1, -42, 0.5, -14)
				swatch.BackgroundColor3 = color
				swatch.Text = ""
				swatch.ZIndex = 6
				swatch.Parent = r
				corner(swatch, 8)
				stroke(swatch, T.Text, 1, 0.6)

				-- simple cycle presets on click
				local presets = {
					Color3.fromRGB(70, 160, 255),
					Color3.fromRGB(120, 200, 255),
					Color3.fromRGB(80, 220, 180),
					Color3.fromRGB(180, 120, 255),
					Color3.fromRGB(255, 120, 160),
					Color3.fromRGB(255, 200, 80),
				}
				local idx = 1
				swatch.MouseButton1Click:Connect(function()
					idx = idx % #presets + 1
					color = presets[idx]
					swatch.BackgroundColor3 = color
					Library.Flags[text] = color
					if callback then pcall(callback, color) end
					Library:_fire(text, color)
				end)
			end

			-- aliases
			Section.AddToggle = Section.Toggle
			Section.AddSlider = Section.Slider
			Section.AddButton = Section.Button
			Section.AddLabel = Section.Label
			Section.AddDropdown = Section.Dropdown
			Section.AddColor = Section.Color

			return Section
		end

		function Tab:AddBanner(opts)
			opts = opts or {}
			local card = Instance.new("Frame")
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.15
			card.Size = UDim2.new(1, 0, 0, 72)
			card.ZIndex = 4
			card.Parent = fullCol
			corner(card, 12)
			stroke(card, accent, 1, 0.5)
			gradient(card, Color3.fromRGB(30, 80, 180), Color3.fromRGB(12, 24, 60), 120)

			local t1 = Instance.new("TextLabel")
			t1.BackgroundTransparency = 1
			t1.Font = Enum.Font.Gotham
			t1.TextSize = 13
			t1.TextColor3 = T.Dim
			t1.TextXAlignment = Enum.TextXAlignment.Left
			t1.Text = opts.Title or "Welcome"
			t1.Size = UDim2.new(1, -24, 0, 20)
			t1.Position = UDim2.new(0, 16, 0, 12)
			t1.ZIndex = 5
			t1.Parent = card

			local t2 = Instance.new("TextLabel")
			t2.BackgroundTransparency = 1
			t2.Font = Enum.Font.GothamBold
			t2.TextSize = 20
			t2.TextColor3 = T.Text
			t2.TextXAlignment = Enum.TextXAlignment.Left
			t2.Text = opts.Highlight or cfg.Name or "Unfly"
			t2.Size = UDim2.new(1, -24, 0, 28)
			t2.Position = UDim2.new(0, 16, 0, 32)
			t2.ZIndex = 5
			t2.Parent = card
		end

		-- short aliases
		Tab.AddSection = Tab.Section
		table.insert(Window.TabList, Tab)
		Window.Tabs[name] = Tab
		if #Window.TabList == 1 then selectTab() end
		return Tab
	end

	Window.AddTab = Window.Tab

	function Window:Ready()
		-- noop for compatibility
	end

	table.insert(Library.Windows, Window)
	return Window
end

return Library
