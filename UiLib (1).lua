local Library = { Flags = {}, Options = {}, Listeners = {}, Version = "1.1.0" }

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
		local ok, err = pcall(fn, value)
		if not ok then warn("[UnflyUi] " .. tostring(err)) end
	end
end

function Library:Get(flag) return Library.Flags[flag] end

function Library:Set(flag, value, silent)
	local obj = Library.Options[flag]
	if not obj then return false end
	obj:Set(value, silent)
	return true
end

function Library:Copy(text)
	local fn = setclipboard or toclipboard
	if not fn then return false end
	return (pcall(fn, tostring(text or "")))
end

local cloneref = cloneref or function(x) return x end
local function Service(n) return cloneref(game:GetService(n)) end

local TweenService = Service("TweenService")
local UIS = Service("UserInputService")
local Players = Service("Players")
local HttpService = Service("HttpService")
local RunService = Service("RunService")
local ContextActionService = Service("ContextActionService")
local TextService = Service("TextService")
local LocalPlayer = Players.LocalPlayer

local MOBILE = (function()
	local p
	pcall(function() p = UIS:GetPlatform() end)
	if p == Enum.Platform.IOS or p == Enum.Platform.Android then return true end
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end)()

local D = MOBILE
	and { W = 740, H = 420, HEAD = 86, SB = 150, ROW = 38, BOT = 40, TAB = 38, TXT = 13, FIELD = 130, FH = 28 }
	or { W = 960, H = 600, HEAD = 104, SB = 206, ROW = 36, BOT = 46, TAB = 44, TXT = 13, FIELD = 150, FH = 28 }

local HAS_FS = (writefile and readfile and isfile and isfolder and makefolder and listfiles and delfile) and true or false

local T = {
	Bg = Color3.fromRGB(6, 8, 20),
	Panel = Color3.fromRGB(12, 15, 38),
	Card = Color3.fromRGB(14, 18, 46),
	Inner = Color3.fromRGB(10, 13, 34),
	Field = Color3.fromRGB(19, 24, 60),
	Pop = Color3.fromRGB(14, 18, 46),
	Line = Color3.fromRGB(88, 104, 235),
	Text = Color3.fromRGB(232, 236, 255),
	Dim = Color3.fromRGB(136, 146, 206),
	Off = Color3.fromRGB(30, 36, 84),
	Knob = Color3.fromRGB(214, 220, 255),
	IconC = Color3.fromRGB(205, 211, 255),
	Red = Color3.fromRGB(255, 102, 105),
}

local function New(class, props, kids)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, c in ipairs(kids or {}) do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function Round(n, inc) return math.floor(n / inc + 0.5) * inc end
local function Decimals(inc) local d = tostring(inc):match("%.(%d+)"); return d and #d or 0 end
local function IsPointer(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local function IsMove(i) return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end

local function Stroke(c, th, tr)
	local st = New("UIStroke", { Color = c, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	if c == T.Line then
		New("UIGradient", {
			Rotation = 40,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 208, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(92, 108, 238)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 174, 255)),
			}),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Parent = st,
		})
	end
	return st
end

local function Pad(l, t, r, b)
	return New("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b) })
end

local function List(pad, props)
	local p = { Padding = UDim.new(0, pad or 0), SortOrder = Enum.SortOrder.LayoutOrder }
	for k, v in pairs(props or {}) do p[k] = v end
	return New("UIListLayout", p)
end

local function Tw(o, props, t, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function Safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[UnflyUi] " .. tostring(err)) end
end

local function Drag(handle, onMove, onStart, onEnd, conns)
	local dragging = false
	local c1 = handle.InputBegan:Connect(function(i)
		if IsPointer(i) then
			dragging = true
			if onStart then onStart(i) end
			onMove(i)
			local c
			c = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					c:Disconnect()
					if onEnd then onEnd() end
				end
			end)
		end
	end)
	local c2 = UIS.InputChanged:Connect(function(i)
		if dragging and IsMove(i) then onMove(i) end
	end)
	if conns then
		table.insert(conns, c1)
		table.insert(conns, c2)
	end
end

local DEFAULT_LOGO = "https://raw.githubusercontent.com/RyzenEngineRb/UnflyProject/refs/heads/main/file_0000000084d48243bd8a0a6109e54d5b.png"

local function UrlHash(str)
	local h = 5381
	for i = 1, #str do h = (h * 33 + string.byte(str, i)) % 4294967296 end
	return tostring(h)
end

local function IsImageData(data)
	if type(data) ~= "string" or #data < 16 then return false end
	local h4 = string.sub(data, 1, 4)
	return h4 == "\137PNG" or string.sub(data, 1, 3) == "\255\216\255" or h4 == "RIFF" or string.sub(data, 1, 3) == "GIF"
end

local TAP_SLOP = 10

local function Tap(btn, fn)
	btn.InputBegan:Connect(function(i)
		if not IsPointer(i) then return end
		local start = i.Position
		local c
		c = i.Changed:Connect(function()
			if i.UserInputState ~= Enum.UserInputState.End then return end
			c:Disconnect()
			local d = i.Position - start
			if d.Magnitude <= TAP_SLOP then task.spawn(fn) end
		end)
	end)
end

local function MakeGui()
	local gui = New("ScreenGui", {
		Name = "UnflyUi", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
	})
	local ok = pcall(function() gui.Parent = (gethui and gethui()) or Service("CoreGui") end)
	if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
	return gui
end

local function Bar(p, cx, cy, w, h, col, rot, r)
	return New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(w, h), Rotation = rot or 0,
		BackgroundColor3 = col, BorderSizePixel = 0, Parent = p,
	}, { Corner(r or 1) })
end

local function Dot(p, cx, cy, s, col) return Bar(p, cx, cy, s, s, col, 0, s) end

local function Ring(p, x, y, s, col, th)
	return New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(s, s), Parent = p,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(col, th or 1.6, 0) })
end

local function Box(p, x, y, w, h, col, th, r)
	return New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Parent = p,
	}, { Corner(r or 2), Stroke(col, th or 1.6, 0) })
end

local Draw = {}
Draw.ring = function(h, c) Ring(h, 3, 3, 12, c); Dot(h, 9, 9, 3, c) end
Draw.home = function(h, c)
	Bar(h, 5.9, 6.6, 8, 1.8, c, -40)
	Bar(h, 12.1, 6.6, 8, 1.8, c, 40)
	Box(h, 4.5, 8.5, 9, 7.5, c, 1.6, 1)
	Bar(h, 9, 13.2, 2.2, 4, c, 0)
end
Draw.gear = function(h, c)
	Ring(h, 4, 4, 10, c, 2)
	Dot(h, 9, 9, 3, c)
	Bar(h, 9, 2, 2.4, 3.4, c)
	Bar(h, 9, 16, 2.4, 3.4, c)
	Bar(h, 2, 9, 3.4, 2.4, c)
	Bar(h, 16, 9, 3.4, 2.4, c)
end
Draw.eye = function(h, c)
	New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 4), Size = UDim2.fromOffset(16, 10), Parent = h,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(c, 1.6, 0) })
	Dot(h, 9, 9, 4.5, c)
end
Draw.target = function(h, c)
	Ring(h, 3, 3, 12, c)
	Dot(h, 9, 9, 3, c)
	Bar(h, 9, 1.5, 1.6, 3, c)
	Bar(h, 9, 16.5, 1.6, 3, c)
	Bar(h, 1.5, 9, 3, 1.6, c)
	Bar(h, 16.5, 9, 3, 1.6, c)
end
Draw.person = function(h, c)
	Ring(h, 6, 1.5, 6, c, 1.6)
	Box(h, 3, 10, 12, 7, c, 1.6, 4)
end
Draw.pin = function(h, c)
	Ring(h, 4, 2, 10, c, 1.8)
	Bar(h, 9, 14, 2, 5, c)
	Dot(h, 9, 7, 3, c)
end
Draw.dots = function(h, c)
	Dot(h, 3.5, 9, 3.4, c)
	Dot(h, 9, 9, 3.4, c)
	Dot(h, 14.5, 9, 3.4, c)
end
Draw.bolt = function(h, c)
	Bar(h, 10.5, 5, 2.2, 9, c, 28)
	Bar(h, 7.5, 13, 2.2, 9, c, 28)
	Bar(h, 9, 9, 7, 2, c, 0)
end
Draw.shield = function(h, c)
	Box(h, 3.5, 2, 11, 12, c, 1.6, 4)
	Bar(h, 9, 15.5, 5, 2, c, 0)
	Bar(h, 9, 8, 2, 6, c, 0)
end
Draw.expand = function(h, c)
	Bar(h, 9, 9, 15, 1.6, c, -45)
	Bar(h, 3.5, 3.5, 4, 1.6, c, 0)
	Bar(h, 3.5, 3.5, 1.6, 4, c, 0)
	Bar(h, 14.5, 14.5, 4, 1.6, c, 0)
	Bar(h, 14.5, 14.5, 1.6, 4, c, 0)
end
Draw.lock = function(h, c)
	New("Frame", { Position = UDim2.fromOffset(3, 8.5), Size = UDim2.fromOffset(12, 8), BackgroundColor3 = c, BorderSizePixel = 0, Parent = h }, { Corner(2) })
	Box(h, 5, 2.5, 8, 9, c, 1.6, 4)
end
Draw.chevron = function(h, c)
	Bar(h, 6.3, 9, 7, 1.8, c, 42)
	Bar(h, 11.7, 9, 7, 1.8, c, -42)
end
Draw.check = function(h, c)
	Bar(h, 5.5, 10.5, 5, 2, c, 45)
	Bar(h, 10.5, 8.5, 10, 2, c, -50)
end
Draw.minus = function(h, c) Bar(h, 9, 9, 12, 1.8, c) end
Draw.cross = function(h, c)
	Bar(h, 9, 9, 13, 1.8, c, 45)
	Bar(h, 9, 9, 13, 1.8, c, -45)
end
Draw.search = function(h, c)
	Ring(h, 2, 2, 10, c, 1.7)
	Bar(h, 13.6, 13.6, 6, 1.8, c, 45)
end
Draw.bell = function(h, c)
	Box(h, 4.5, 3.5, 9, 9, c, 1.6, 4)
	Bar(h, 9, 13, 12, 1.8, c, 0)
	Dot(h, 9, 16, 2.6, c)
	Dot(h, 9, 2.4, 2, c)
end
Draw.clock = function(h, c)
	Ring(h, 2, 2, 14, c, 1.6)
	Bar(h, 9, 6.4, 1.6, 5.2, c, 0)
	Bar(h, 11.6, 9, 5.2, 1.6, c, 0)
end
Draw.folder = function(h, c)
	Box(h, 2, 5.5, 14, 9.5, c, 1.6, 2)
	Bar(h, 5.5, 4.6, 5, 2, c, 0)
end
Draw.code = function(h, c)
	Bar(h, 4.3, 6.7, 5.8, 1.7, c, -52)
	Bar(h, 4.3, 11.3, 5.8, 1.7, c, 52)
	Bar(h, 13.7, 6.7, 5.8, 1.7, c, 52)
	Bar(h, 13.7, 11.3, 5.8, 1.7, c, -52)
	Bar(h, 9, 9, 1.6, 10, c, 20)
end
Draw.link = function(h, c)
	local a = Box(h, 1.5, 8, 9, 5.5, c, 1.6, 3)
	a.Rotation = -40
	local b = Box(h, 7.5, 4.5, 9, 5.5, c, 1.6, 3)
	b.Rotation = -40
end
Draw.copy = function(h, c)
	Box(h, 2.5, 6, 9.5, 10, c, 1.6, 2)
	Bar(h, 10.75, 2.5, 9.5, 1.6, c, 0)
	Bar(h, 15.5, 8, 1.6, 11, c, 0)
	Bar(h, 6, 4.3, 1.6, 3.6, c, 0)
end
Draw.chat = function(h, c)
	Box(h, 2, 3, 14, 9.5, c, 1.6, 4)
	Bar(h, 6, 14.2, 3.4, 1.8, c, 50)
	Dot(h, 6.2, 7.8, 2, c)
	Dot(h, 9, 7.8, 2, c)
	Dot(h, 11.8, 7.8, 2, c)
end
Draw.send = function(h, c)
	Bar(h, 9, 5.5, 15.2, 1.6, c, -23)
	Bar(h, 13.5, 9, 13.9, 1.6, c, -69)
	Bar(h, 9.75, 13, 5.6, 1.6, c, 63)
	Bar(h, 5.25, 9.5, 6.8, 1.6, c, 17)
	Bar(h, 12.25, 6.5, 11, 1.6, c, -47)
end
Draw.info = function(h, c)
	Ring(h, 2, 2, 14, c, 1.6)
	Dot(h, 9, 5.8, 2, c)
	Bar(h, 9, 10.6, 1.8, 5, c, 0)
end
Draw.sliders = function(h, c)
	Bar(h, 9, 4, 14, 1.5, c, 0)
	Bar(h, 9, 9, 14, 1.5, c, 0)
	Bar(h, 9, 14, 14, 1.5, c, 0)
	Dot(h, 6, 4, 4, c)
	Dot(h, 12, 9, 4, c)
	Dot(h, 7, 14, 4, c)
end
Draw.palette = function(h, c)
	Ring(h, 2, 2, 14, c, 1.6)
	Dot(h, 6, 7, 2.2, c)
	Dot(h, 9.5, 5.2, 2.2, c)
	Dot(h, 12.4, 8, 2.2, c)
	Dot(h, 6.6, 11.2, 2.2, c)
end
Draw.globe = function(h, c)
	Ring(h, 2, 2, 14, c, 1.5)
	Bar(h, 9, 9, 14, 1.4, c, 0)
	Box(h, 6, 2, 6, 14, c, 1.4, 3)
end
Draw.trash = function(h, c)
	Bar(h, 9, 4.6, 12, 1.8, c, 0)
	Bar(h, 9, 3, 4, 1.6, c, 0)
	Box(h, 4, 6, 10, 10, c, 1.6, 2)
	Bar(h, 7.2, 11, 1.4, 5, c, 0)
	Bar(h, 10.8, 11, 1.4, 5, c, 0)
end
Draw.plus = function(h, c)
	Bar(h, 9, 9, 12, 1.8, c, 0)
	Bar(h, 9, 9, 1.8, 12, c, 0)
end
Draw.users = function(h, c)
	Ring(h, 3, 2, 5.5, c, 1.5)
	Box(h, 1.5, 9, 9, 6.5, c, 1.5, 3)
	Ring(h, 10.5, 3.5, 4.5, c, 1.5)
	Box(h, 10.5, 9.5, 6, 5.5, c, 1.5, 3)
end
Draw.flag = function(h, c)
	Bar(h, 4.5, 9, 1.8, 14, c, 0)
	Box(h, 5.4, 3, 9, 6.5, c, 1.6, 1)
end
Draw.star = function(h, c)
	Box(h, 4, 4, 10, 10, c, 1.6, 1)
	local b = Box(h, 4, 4, 10, 10, c, 1.6, 1)
	b.Rotation = 45
end
Draw.sword = function(h, c)
	Bar(h, 9, 9, 15, 2, c, -45)
	Bar(h, 5.4, 12.6, 6, 1.8, c, 45)
	Dot(h, 3.4, 14.6, 2.6, c)
end
Draw.wrench = function(h, c)
	Bar(h, 9, 9, 12, 2.4, c, -45)
	Ring(h, 10.5, 1.5, 6.5, c, 1.8)
	Dot(h, 3.6, 14.4, 3, c)
end
Draw.map = function(h, c)
	Box(h, 2.5, 3.5, 13, 11, c, 1.6, 2)
	Bar(h, 7, 9, 1.4, 11, c, 0)
	Bar(h, 11.2, 9, 1.4, 11, c, 0)
end
Draw.key = function(h, c)
	Ring(h, 1.5, 5.5, 7, c, 1.7)
	Bar(h, 11.5, 9, 8, 1.8, c, 0)
	Bar(h, 13.2, 11.6, 1.6, 3.4, c, 0)
	Bar(h, 15.8, 11.2, 1.6, 2.6, c, 0)
end
Draw.image = function(h, c)
	Box(h, 2, 3, 14, 12, c, 1.6, 2)
	Dot(h, 6.2, 7, 2.8, c)
	Bar(h, 11.2, 12, 8, 1.6, c, -35)
end
Draw.download = function(h, c)
	Bar(h, 9, 6.5, 1.8, 9, c, 0)
	Bar(h, 6.4, 10.8, 5, 1.8, c, 45)
	Bar(h, 11.6, 10.8, 5, 1.8, c, -45)
	Bar(h, 9, 15.2, 12, 1.8, c, 0)
end

local Alias = {
	settings = "gear", close = "cross", crosshair = "target", aim = "target", user = "person", players = "users", telegram = "send", discord = "chat",
	combat = "sword", teleport = "pin", teleports = "pin", visuals = "eye", misc = "dots", movement = "bolt", tools = "wrench", world = "globe", config = "folder",
	save = "download", add = "plus", delete = "trash", find = "search", notification = "bell", time = "clock", script = "code", theme = "palette", warning = "info",
}

local ICON_FONT = Font.new("rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local ICON_OK = (function()
	local ok, w = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = "gear"
		params.Font = ICON_FONT
		params.Size = 24
		params.Width = 1000
		return TextService:GetTextBoundsAsync(params).X
	end)
	if not ok then return true end
	return type(w) == "number" and w > 0 and w < 34
end)()

local GLYPH_NAMES = table.concat({
	"3d-cube-arrow-left amazon arm-left arm-right arrow-curl-to-left arrow-curl-to-right arrow-down-to-line",
	"arrow-large-down arrow-large-left arrow-large-right arrow-large-up arrow-right-from-portrait-rectangle",
	"arrow-right-to-portrait-rectangle arrow-rotate-down-dashed arrow-rotate-right arrow-rotate-right-dashed",
	"arrow-small-down arrow-small-left arrow-small-right arrow-small-up arrow-spin-clockwise arrow-spin-clockwise-10",
	"arrow-spin-clockwise-15 arrow-spin-clockwise-30 arrow-spin-counter-clockwise-10 arrow-spin-counter-clockwise-15",
	"arrow-spin-counter-clockwise-30 arrow-thick-to-left arrow-thick-to-right arrow-up-from-landscape-rectangle",
	"arrow-up-right-from-square arrow-wide-short-down arrow-wide-short-left arrow-wide-short-right arrow-wide-short-up",
	"arrows-small-directional audio-wave-dotted-line backpack beard bell bell-clock bell-plus bell-slash belt binoculars",
	"book-closed bookmark bow-tie building-store bullet-flying butterfly-wings calendar calendar-plus calendar-star",
	"camera-small caret-small-down caret-small-left caret-small-right caret-small-up chain-link chart-four-vertical-bars",
	"chart-line chart-pie chart-scatter-plot chart-three-vertical-bars check check-large check-small chevron-large-down",
	"chevron-large-down-to-line chevron-large-left chevron-large-left-to-line chevron-large-right",
	"chevron-large-right-to-line chevron-large-up chevron-large-up-to-line chevron-small-down chevron-small-down-to-line",
	"chevron-small-left chevron-small-left-to-line chevron-small-right chevron-small-right-to-line chevron-small-up",
	"chevron-small-up-to-line circle-check circle-i circle-minus circle-person",
	"circle-person-three-horizontal-bars-wrapping-right circle-play circle-plus circle-question circle-slash circle-star",
	"circle-three-dots-horizontal circle-three-dots-vertical circle-x clock clock-dashed clock-spin-reverse",
	"clock-spin-reverse-dashed clothes-hanger cloud cloud-arrow-down code compact-makeup-brush compass controller-with-cog",
	"crop crosshairs crosshairs-slash cube-vertexes curved-rectangle-megaphone diagonal-line-pattern",
	"diagonal-line-pattern-sticker diamond-simplified discord disguise-nose-glasses document-circle-slash",
	"document-list-heart door-open-arrow-to-bottom-right dress dual-arrows-horizontal dual-arrows-to-corners",
	"dual-arrows-vertical envelope eraser eye eye-slash eye-with-eyeliner eyebrows eyelashes face-winking facebook file-box",
	"fingerprint flag flame folder fountain-pen-nib four-bars-horizontal-center-aligned four-bars-horizontal-chevron-left",
	"four-bars-horizontal-chevron-right four-bars-horizontal-justified-aligned four-bars-horizontal-left-aligned",
	"four-bars-horizontal-right-aligned frame-bubble-slash frame-bubble-soundwave frame-camera frame-camera-center",
	"frame-collapsed frame-corners frame-expanded frame-face frame-person-torso frame-record frame-single-bar-horizontal",
	"frame-soundwave frame-video-camera gear generic-dpad gift-box gift-card glasses globe-detailed globe-simplified",
	"globe-simplipfied-speech-bubble grid guilded hack-week hammer-code hand-curved-arrow-left hand-dual-arrows",
	"hand-ellipse hand-half-ellipse hand-two-arrows-horizontal hashtag hat-fedora hat-toque head-blank head-blush",
	"head-female head-freckles head-lips head-male headphones headphones-arrow-up headphones-arrow-up-lock headphones-slash",
	"headphones-x headphones-x-lock heart house image image-stacked instagram jacket key key-alt key-apostrophe",
	"key-arrow-down key-arrow-right key-arrow-up key-asterisk key-backspace key-caps-lock key-caret key-comma key-command",
	"key-control key-grave-accent key-period key-return key-shift key-space key-tab language-characters leg-left leg-right",
	"lightning-bolt linkedin lips lipstick list-bulleted location-pin location-pin-map lock-closed lollipop",
	"magnifying-glass magnifying-glass-minus magnifying-glass-plus mascara megaphone memory-card messenger microphone",
	"microphone-slash microphone-text-box microphone-triangle-exclamation minus minus-small mirror-standing moments moon",
	"mouse-button-left mouse-button-right mouse-scrollwheel music-note nebula necklace nine-dots-grid ninja nose page",
	"paint-brush paint-bucket pants pants-2d-text paper-airplane parrot pause-large pause-small pencil pencil-square person",
	"person-arrow-from-bottom-right person-check person-circle-slash person-climbing person-clock person-falling",
	"person-graduate person-jumping person-magnifying-glass person-photo-camera person-play person-play-clock person-plus",
	"person-racing person-running person-standing person-standing-arrow-reverse person-standing-dual-arrows-vertical",
	"person-standing-gear person-swimming person-teleport person-trash-can person-walking person-with-smaller-person phone",
	"phone-down phone-plus phone-volume phone-x photo-camera photo-camera-face photo-camera-slash picture-in-picture pig",
	"pin pin-slash play-large play-small plus-large plus-small premium ps-circle ps-dpad-down ps-dpad-left ps-dpad-right",
	"ps-dpad-up ps-l1 ps-l2 ps-l3 ps-r1 ps-r2 ps-r3 ps-square ps-stick-left ps-stick-right ps-triagle ps-x ps4-options",
	"ps4-share ps4-touchpad ps5-options ps5-share ps5-touchpad pumpkin purse rectangle-list rectangle-numbers-counting",
	"rectangle-person-with-three-horizontal-lines robux rosette-seven-point rosette-ten-point seven-point-rosette",
	"shield-check shield-lock shirt shirt-2d-text shirt-pants shoe-left shoe-right shopping-basket shopping-basket-check",
	"shopping-cart shorts sidebar signal-exclamation six-dots-two-column-grid skip-end-large skip-end-small skip-next-large",
	"skip-next-small skip-previous-large skip-previous-small skip-start-large skip-start-small smartphone-portrait speaker",
	"speaker-slash speaker-triangle-exclamation speaker-x speech-bubble-align-center speech-bubble-align-left",
	"speech-bubble-exclamation speech-bubble-round square-bone square-books square-check square-code",
	"square-dashed-person-standing square-dual-arrows-horizontal square-dual-arrows-to-corner square-face-sound",
	"square-face-waving-hand square-face-winking square-minus square-person squares-grid-plus squares-grid-qr",
	"stacked-squares-arrow-down-left stacked-squares-arrow-up-right stacked-squares-plus star stop-large stop-small studio",
	"sun sweater sword tag-sparkle teletype tencent-qq text-b-bold text-box-microphone text-h-subscript-1",
	"text-h-subscript-2 text-h-subscript-3 text-i-italic text-s-strikethrough text-u-underline text-uppercase-a-lowercase-a",
	"text-x-subscript-2 text-x-superscript-2 three-bars-horizontal three-bars-horizontal-chevron-left",
	"three-bars-horizontal-narrowing three-bars-horizontal-triangles-vertical three-bars-vertical-triangles-horizontal",
	"three-chevrons-enlarging-down three-chevrons-enlarging-up three-dots-horizontal three-dots-vertical",
	"three-horizontal-bars-wrapping-right three-people three-ring-note three-sliders-horizontal",
	"three-stacked-squares-tilted thumb-down thumb-up tik-tok tilt torso trash-can triangle-exclamation trophy tshirt",
	"tshirt-2d-text tshirt-dual-arrows twitch twitter two-arrows-down-and-up two-arrows-from-center two-arrows-left-right",
	"two-arrows-loop-clockwise two-arrows-loop-clockwise-1 two-arrows-loop-clockwise-infinity two-arrows-spin-clockwise",
	"two-arrows-spin-clockwise-plus two-arrows-switch-right two-arrows-to-center two-folders",
	"two-location-pins-connecting-arrow two-makeup-brushes two-people two-people-speech-bubble two-stacked-squares",
	"two-switches-horizontal verified-backplate verified-check verified-mono video-camera video-camera-arrow-to-bottom-left",
	"video-camera-arrow-to-top-right video-camera-slash video-camera-triangle-exclamation video-camera-x wallet we-chat",
	"whatsapp x x-small xbox-a xbox-a-pressed xbox-a-unpressed xbox-b xbox-dpad xbox-dpad-down xbox-dpad-left",
	"xbox-dpad-right xbox-dpad-up xbox-lb xbox-lt xbox-menu xbox-rb xbox-rt xbox-stick-left xbox-stick-left-directional",
	"xbox-stick-left-horizontal xbox-stick-left-vertical xbox-stick-right xbox-stick-right-directional",
	"xbox-stick-right-horizontal xbox-stick-right-vertical xbox-view xbox-x xbox-y xr-headset youtube",
}, " ")

local GlyphSet = {}
local GlyphList = {}
for name in string.gmatch(GLYPH_NAMES, "%S+") do
	GlyphSet[name] = true
	GlyphList[#GlyphList + 1] = name
end
table.sort(GlyphList)

local Glyphs = {
	ring = "diamond-simplified", home = "house", gear = "gear", eye = "eye", target = "crosshairs", person = "person", users = "two-people",
	pin = "location-pin", dots = "three-dots-horizontal", bolt = "lightning-bolt", shield = "shield-check", expand = "two-arrows-from-center",
	lock = "lock-closed", chevron = "chevron-small-down", check = "check", minus = "minus", cross = "x", plus = "plus-large", search = "magnifying-glass",
	bell = "bell", clock = "clock", folder = "folder", code = "code", link = "chain-link", copy = "two-stacked-squares", chat = "speech-bubble-round",
	send = "paper-airplane", info = "circle-i", sliders = "three-sliders-horizontal", palette = "paint-brush", globe = "globe-simplified", trash = "trash-can",
	flag = "flag", star = "star", sword = "sword", wrench = "hammer-code", map = "location-pin-map", key = "key", image = "image", download = "arrow-down-to-line",
	discord = "discord", telegram = "paper-airplane", combat = "sword", teleport = "person-teleport", teleports = "person-teleport", movement = "person-running",
	players = "two-people", visuals = "eye", misc = "three-dots-horizontal",
	adduser = "person-plus", admin = "person-standing-gear", alert = "triangle-exclamation", amazon = "amazon",
	arrows = "arrows-small-directional", avatar = "circle-person", back = "arrow-large-left", backpack = "backpack", bag = "purse",
	bars = "chart-three-vertical-bars", basket = "shopping-basket", belloff = "bell-slash", binoculars = "binoculars", book = "book-closed",
	brush = "paint-brush", butterfly = "butterfly-wings", calendar = "calendar", camera = "photo-camera", cart = "shopping-cart",
	chart = "chart-line", checkuser = "person-check", climb = "person-climbing", clipboard = "rectangle-list", clothes = "shirt",
	cloud = "cloud", coin = "robux", collapse = "two-arrows-to-center", compass = "compass", controller = "controller-with-cog", crop = "crop",
	crown = "premium", cube = "cube-vertexes", dislike = "thumb-down", document = "page", down = "arrow-large-down", dpad = "generic-dpad",
	edit = "pencil", envelope = "envelope", eraser = "eraser", error = "circle-x", eyeoff = "eye-slash", facebook = "facebook",
	fall = "person-falling", file = "page", fingerprint = "fingerprint", fire = "flame", flame = "flame", folders = "two-folders",
	forward = "arrow-large-right", friends = "two-people", gamepad = "generic-dpad", gift = "gift-box", glasses = "glasses",
	graph = "chart-line", grid = "grid", guilded = "guilded", hammer = "hammer-code", hashtag = "hashtag", headphones = "headphones",
	heart = "heart", help = "circle-question", hide = "eye-slash", instagram = "instagram", inventory = "backpack", jump = "person-jumping",
	language = "language-characters", left = "arrow-large-left", like = "thumb-up", linkedin = "linkedin", list = "list-bulleted",
	mail = "envelope", mask = "disguise-nose-glasses", megaphone = "megaphone", menu = "three-bars-horizontal", messenger = "messenger",
	mic = "microphone", microphone = "microphone", minusc = "circle-minus", mirror = "mirror-standing", money = "robux", moon = "moon",
	mouse = "mouse-button-left", music = "music-note", mute = "microphone-slash", next = "skip-next-large", ninja = "ninja",
	numbers = "rectangle-numbers-counting", ok = "circle-check", paint = "paint-bucket", parrot = "parrot", party = "three-people",
	pause = "pause-large", pencil = "pencil", phone = "phone", picture = "picture-in-picture", pie = "chart-pie", pig = "pig",
	play = "play-large", plusc = "circle-plus", premium = "premium", prev = "skip-previous-large", previous = "skip-previous-large",
	pumpkin = "pumpkin", question = "circle-question", refresh = "arrow-rotate-right", reload = "arrow-rotate-right",
	removeuser = "person-trash-can", right = "arrow-large-right", robux = "robux", run = "person-running", scroll = "mouse-scrollwheel",
	security = "shield-lock", share = "arrow-up-right-from-square", shirt = "shirt", shop = "shopping-cart", sidebar = "sidebar",
	signal = "signal-exclamation", sound = "speaker", speaker = "speaker", spectate = "person-magnifying-glass",
	stats = "chart-four-vertical-bars", stop = "stop-large", store = "building-store", success = "circle-check", sun = "sun",
	swap = "two-arrows-left-right", swim = "person-swimming", sync = "two-arrows-loop-clockwise", tag = "tag-sparkle", tiktok = "tik-tok",
	timer = "clock-dashed", trophy = "trophy", twitch = "twitch", twitter = "twitter", up = "arrow-large-up", verified = "verified-check",
	video = "video-camera", vip = "premium", volume = "speaker", volumeoff = "speaker-slash", walk = "person-walking", wallet = "wallet",
	warning = "triangle-exclamation", whatsapp = "whatsapp", youtube = "youtube", zoomin = "magnifying-glass-plus",
	zoomout = "magnifying-glass-minus",
}

Library.Icons = GlyphList

function Library:FindIcon(query)
	query = string.lower(tostring(query or ""))
	local out, seen = {}, {}
	local function add(n)
		if not seen[n] then
			seen[n] = true
			out[#out + 1] = n
		end
	end
	if query == "" then
		for _, n in ipairs(GlyphList) do add(n) end
		return out
	end
	for key, glyph in pairs(Glyphs) do
		if string.find(key, query, 1, true) then add(glyph) end
	end
	for _, n in ipairs(GlyphList) do
		if string.find(n, query, 1, true) then add(n) end
	end
	table.sort(out)
	return out
end

local function Icon(name, parent, color, size)
	local s = size or 18
	local box = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(s, s), Parent = parent })
	if type(name) == "string" and (name:match("^rbxassetid://") or name:match("^rbxasset://") or name:match("^%d+$")) then
		local id = name:match("^%d+$") and ("rbxassetid://" .. name) or name
		New("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = id, ImageColor3 = color or T.IconC, Parent = box })
		return box
	end
	if ICON_OK and type(name) == "string" then
		local canon = Alias[name] or name
		local glyph = Glyphs[name] or Glyphs[canon]
		if not glyph and not Draw[canon] and GlyphSet[name] then glyph = name end
		if glyph then
			New("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = ICON_FONT, Text = glyph, TextSize = s, TextColor3 = color or T.IconC,
				TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Parent = box,
			})
			return box
		end
	end
	local h = New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Parent = box,
	}, { New("UIScale", { Scale = s / 18 }) })
	;(Draw[name] or Draw[Alias[name] or ""] or Draw.ring)(h, color or T.IconC)
	return box
end

local function Logo(parent, scale)
	local h = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 44), Parent = parent }, { New("UIScale", { Scale = scale or 1 }) })
	local function arm(cx, rot, w, h2, c1, c2)
		local b = Bar(h, cx, 22, w, h2, Color3.new(1, 1, 1), rot, 2)
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(c1, c2), Parent = b })
	end
	arm(17, -20, 9, 42, Color3.fromRGB(244, 248, 255), Color3.fromRGB(67, 76, 136))
	arm(39, 20, 9, 42, Color3.fromRGB(244, 248, 255), Color3.fromRGB(67, 76, 136))
	arm(23.5, -20, 4, 30, Color3.fromRGB(95, 107, 188), Color3.fromRGB(38, 43, 83))
	arm(32.5, 20, 4, 30, Color3.fromRGB(95, 107, 188), Color3.fromRGB(38, 43, 83))
	return h
end

local function Elements(W, inner, rowsInfo)
	local E, order = {}, 0
	local LX = W.RowIcons and 40 or 14
	E.Container = inner

	local function lock(v)
		for _, s in ipairs(W.CurrentScrolls or {}) do
			if s then s.ScrollingEnabled = v end
		end
	end

	local function Row(icon, defIcon, h, iconY, name)
		order = order + 1
		local r = New("Frame", { Size = UDim2.new(1, 0, 0, h or D.ROW), BackgroundTransparency = 1, LayoutOrder = order, Parent = inner })
		if name then
			table.insert(W.Search, { row = r, name = string.lower(tostring(name)) })
			if rowsInfo then table.insert(rowsInfo.rows, r) end
		end
		if order > 1 then
			New("Frame", {
				Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = T.Line, BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = r,
			})
		end
		if W.RowIcons then
			local ic = Icon(icon or defIcon or "ring", r, T.IconC, 18)
			ic.Position = UDim2.new(0, 12, 0, (iconY or ((h or D.ROW) / 2)) - 9)
		end
		return r
	end

	local function Lbl(parent, text, rightW, props)
		local p = {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(LX, 0), Size = UDim2.new(1, -(LX + (rightW or 60)), 1, 0), Font = Enum.Font.GothamMedium,
			Text = text or "", TextColor3 = T.Text, TextSize = D.TXT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent,
		}
		for k, v in pairs(props or {}) do p[k] = v end
		return New("TextLabel", p)
	end

	local function Hit(parent)
		return New("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = parent })
	end

	local function Field(parent, w, props)
		local p = {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(w, D.FH), BackgroundColor3 = T.Field,
			BorderSizePixel = 0, Parent = parent,
		}
		for k, v in pairs(props or {}) do p[k] = v end
		return New("Frame", p, { Corner(12), Stroke(T.Line, 1, 0.35) })
	end

	local function Register(cfg, obj)
		if cfg.Flag then
			W.FlagObjs[cfg.Flag] = obj
			Library.Options[cfg.Flag] = obj
			Library.Flags[cfg.Flag] = obj.Value
		end
	end

	local function Commit(cfg, obj, silent)
		if cfg.Flag then Library.Flags[cfg.Flag] = obj.Value end
		if not silent then
			Safe(cfg.Callback, obj.Value)
			if cfg.Flag then Library:_emit(cfg.Flag, obj.Value) end
		end
	end

	local function Popup(anchor, w, h)
		local pop = New("Frame", {
			Size = UDim2.fromOffset(w, h), BackgroundColor3 = T.Pop, BorderSizePixel = 0, Visible = false, ZIndex = 62, Parent = W.Overlay,
		}, { Corner(8), Stroke(T.Line, 1, 0.1) })
		local api = { Frame = pop }
		function api:Open()
			W:ClosePopup()
			local s = W.Scale.Scale
			local rp = (anchor.AbsolutePosition - W.Root.AbsolutePosition) / s
			local ax, ay = anchor.AbsoluteSize.X / s, anchor.AbsoluteSize.Y / s
			local x = rp.X + ax - w
			local y = rp.Y + ay + 4
			local maxY = W.Root.AbsoluteSize.Y / s - h - 8
			if y > maxY then y = rp.Y - h - 4 end
			pop.Position = UDim2.fromOffset(math.max(4, x), math.max(4, y))
			pop.Visible = true
			W.Blocker.Visible = true
			W.OpenPop = api
		end
		function api:Close()
			pop.Visible = false
			if W.OpenPop == api then
				W.OpenPop = nil
				W.Blocker.Visible = false
			end
			if api.OnClose then api.OnClose() end
		end
		return api
	end

	function E:AddLabel(text)
		local r = New("Frame", { Size = UDim2.new(1, 0, 0, D.ROW), BackgroundTransparency = 1, LayoutOrder = order + 1, Parent = inner })
		order = order + 1
		local l = Lbl(r, text, 12, { Position = UDim2.fromOffset(14, 0), TextColor3 = T.Dim })
		local obj = {}
		function obj:Set(t) l.Text = t end
		return obj
	end

	function E:AddButton(cfg)
		cfg = type(cfg) == "string" and { Name = cfg } or cfg
		local r = Row(cfg.Icon, "bolt", nil, nil, cfg.Name)
		Lbl(r, cfg.Name, 120)
		local f = Field(r, 90)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(128, 144, 255), Color3.fromRGB(74, 88, 226)), Parent = f })
		local flash = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = W.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = f }, { Corner(6) })
		New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamMedium, Text = cfg.ButtonText or "Run", TextSize = D.TXT,
			TextColor3 = T.Text, ZIndex = 3, Parent = f,
		})
		Tap(Hit(r), function()
			flash.BackgroundTransparency = 0.6
			Tw(flash, { BackgroundTransparency = 1 }, 0.35)
			Safe(cfg.Callback)
		end)
		return {}
	end

	function E:AddToggle(cfg)
		cfg = type(cfg) == "string" and { Name = cfg } or cfg
		local TW, TH = MOBILE and 46 or 42, MOBILE and 26 or 22
		local r = Row(cfg.Icon, "ring", nil, nil, cfg.Name)
		Lbl(r, cfg.Name, TW + 24)
		local pill = New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(TW, TH), BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = r,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(T.Line, 1, 0.5) })
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, TH / 2, 0.5, 0), Size = UDim2.fromOffset(TH - 6, TH - 6), BackgroundColor3 = T.Knob, BorderSizePixel = 0, Parent = pill,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local obj = { Value = false, Type = "Toggle" }
		local function render()
			Tw(pill, { BackgroundColor3 = obj.Value and W.Accent:Lerp(Color3.new(0, 0, 0), 0.5) or T.Off }, 0.15)
			Tw(knob, {
				Position = UDim2.new(0, obj.Value and (TW - TH / 2) or (TH / 2), 0.5, 0),
				BackgroundColor3 = obj.Value and Color3.fromRGB(240, 244, 255) or T.Knob,
			}, 0.15)
			knob.Size = UDim2.fromOffset(TH + 2, TH - 8)
			Tw(knob, { Size = UDim2.fromOffset(TH - 6, TH - 6) }, 0.22, Enum.EasingStyle.Back)
		end
		local loopConn
		local function updateLoop()
			if cfg.Loop and obj.Value then
				if not loopConn then
					loopConn = RunService.Heartbeat:Connect(function(dt) Safe(cfg.Loop, dt) end)
					W.Loops[obj] = loopConn
				end
			elseif loopConn then
				loopConn:Disconnect()
				loopConn = nil
				W.Loops[obj] = nil
			end
		end
		function obj:Set(v, silent)
			obj.Value = v and true or false
			render()
			updateLoop()
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		W:BindAccent(render)
		Tap(Hit(r), function() obj:Set(not obj.Value) end)
		obj:Set(cfg.Default or false, true)
		Register(cfg, obj)
		if cfg.Default then Commit(cfg, obj, false) end
		return obj
	end

	function E:AddSlider(cfg)
		local min, max = cfg.Min or 0, cfg.Max or 100
		local inc = cfg.Increment or (cfg.Rounding and (1 / 10 ^ cfg.Rounding)) or 1
		local dec = Decimals(inc)
		local LW = MOBILE and 120 or 108
		local r = Row(cfg.Icon, "bolt", nil, nil, cfg.Name)
		Lbl(r, cfg.Name, 12, { Size = UDim2.fromOffset(LW, D.ROW) })
		local val = New("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(46, 20), Font = Enum.Font.GothamMedium,
			Text = "", TextSize = D.TXT, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Right, Parent = r,
		})
		local bar = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, LX + LW, 0.5, 0), Size = UDim2.new(1, -(LX + LW + 66), 0, 6), BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = r,
		}, { Corner(3), Stroke(T.Line, 1, 0.6) })
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = W.Accent, BorderSizePixel = 0, Parent = bar }, {
			Corner(3),
			New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(67, 75, 135), Color3.fromRGB(249, 253, 255)) }),
		})
		local KS = MOBILE and 18 or 14
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(KS, KS), BackgroundColor3 = T.Knob, BorderSizePixel = 0, ZIndex = 3, Parent = bar,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(Color3.fromRGB(249, 253, 255), 1, 0.55) })
		local obj = { Value = min, Type = "Slider" }
		local function render()
			local a = (obj.Value - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
			val.Text = string.format("%." .. dec .. "f", obj.Value) .. (cfg.Suffix or "")
		end
		function obj:Set(v, silent)
			obj.Value = math.clamp(Round(v, inc), min, max)
			render()
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		local hit = New("TextButton", {
			BackgroundTransparency = 1, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, LX - 8 + LW, 0.5, 0),
			Size = UDim2.new(1, -(LX - 8 + LW + 58), 1, 0), ZIndex = 4, Parent = r,
		})
		Drag(hit, function(i)
			obj:Set(min + (max - min) * math.clamp((i.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1))
		end, function()
			lock(false)
			Tw(knob, { Size = UDim2.fromOffset(KS + 5, KS + 5) }, 0.12)
		end, function()
			lock(true)
			Tw(knob, { Size = UDim2.fromOffset(KS, KS) }, 0.15)
		end, W.Conns)
		obj:Set(cfg.Default or min, true)
		Register(cfg, obj)
		if cfg.Default then Commit(cfg, obj, false) end
		return obj
	end

	function E:AddTextBox(cfg)
		local r = Row(cfg.Icon, "person", nil, nil, cfg.Name)
		Lbl(r, cfg.Name, D.FIELD + 24)
		local f = Field(r, D.FIELD)
		local st = f.UIStroke
		local tb = New("TextBox", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Font = Enum.Font.Gotham, TextSize = D.TXT, TextColor3 = T.Text,
			PlaceholderText = cfg.Placeholder or "...", PlaceholderColor3 = T.Dim, Text = cfg.Default or "", ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f,
		})
		local obj = { Value = tb.Text, Type = "TextBox" }
		function obj:Set(t, silent)
			tb.Text = tostring(t)
			obj.Value = tb.Text
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		tb.Focused:Connect(function()
			st.Color = W.Accent
			st.Transparency = 0.2
		end)
		tb.FocusLost:Connect(function()
			st.Color = T.Line
			st.Transparency = 0.35
			obj.Value = tb.Text
			Commit(cfg, obj)
		end)
		Register(cfg, obj)
		return obj
	end

	function E:AddDropdown(cfg)
		local r = Row(cfg.Icon, "target", nil, nil, cfg.Name)
		Lbl(r, cfg.Name, D.FIELD + 24)
		local f = Field(r, D.FIELD)
		local cur = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0), Font = Enum.Font.Gotham, Text = "", TextSize = D.TXT,
			TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f,
		})
		local chev = Icon("chevron", f, T.Dim, 14)
		chev.AnchorPoint = Vector2.new(1, 0.5)
		chev.Position = UDim2.new(1, -6, 0.5, 0)
		local obj = { Options = cfg.Options or {}, Multi = cfg.Multi, Type = "Dropdown" }
		obj.Value = cfg.Multi and {} or nil
		local OPT = MOBILE and 32 or 26
		local pop, list
		local btns = {}

		local function sel(o)
			if obj.Multi then return obj.Value[o] == true end
			return obj.Value == o
		end

		local function render()
			if obj.Multi then
				local t = {}
				for _, o in ipairs(obj.Options) do
					if obj.Value[o] then t[#t + 1] = tostring(o) end
				end
				cur.Text = #t > 0 and table.concat(t, ", ") or "None"
			else
				cur.Text = obj.Value ~= nil and tostring(obj.Value) or "None"
			end
			for o, b in pairs(btns) do
				b.check.Visible = sel(o)
				b.label.TextColor3 = sel(o) and Color3.new(1, 1, 1) or T.Dim
			end
		end

		local function build()
			if pop then pop.Frame:Destroy() end
			local h = math.min(#obj.Options, 6) * OPT + 10
			pop = Popup(f, D.FIELD, h)
			list = New("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 63, Parent = pop.Frame,
			}, { List(0), Pad(6, 5, 6, 5) })
			btns = {}
			for idx, o in ipairs(obj.Options) do
				local b = New("TextButton", {
					Size = UDim2.new(1, 0, 0, OPT), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = idx, ZIndex = 64, Parent = list,
				})
				local label = New("TextLabel", {
					BackgroundTransparency = 1, Size = UDim2.new(1, -22, 1, 0), Font = Enum.Font.Gotham, Text = tostring(o), TextSize = D.TXT, TextColor3 = T.Dim,
					TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 65, Parent = b,
				})
				local check = Icon("check", b, Color3.new(1, 1, 1), 14)
				check.AnchorPoint = Vector2.new(1, 0.5)
				check.Position = UDim2.new(1, 0, 0.5, 0)
				check.ZIndex = 65
				check.Visible = false
				btns[o] = { check = check, label = label }
				Tap(b, function()
					if obj.Multi then
						obj.Value[o] = (not obj.Value[o]) or nil
					else
						obj.Value = o
					end
					render()
					Commit(cfg, obj)
					if not obj.Multi then pop:Close() end
				end)
			end
			pop.OnClose = function() Tw(chev, { Rotation = 0 }, 0.15) end
			render()
		end

		function obj:Set(v, silent)
			if obj.Multi then
				obj.Value = {}
				for _, o in ipairs(type(v) == "table" and v or {}) do obj.Value[o] = true end
			else
				obj.Value = v
			end
			render()
			Commit(cfg, obj, silent)
		end
		function obj:SetOptions(opts)
			obj.Options = opts
			build()
		end
		function obj:Get() return obj.Value end

		Tap(Hit(r), function()
			if pop and pop.Frame.Visible then
				pop:Close()
			else
				if cfg.OnOpen then Safe(cfg.OnOpen, obj) end
				pop:Open()
				Tw(chev, { Rotation = 180 }, 0.15)
			end
		end)
		build()
		if cfg.Default ~= nil then obj:Set(cfg.Default, true) end
		Register(cfg, obj)
		return obj
	end

	function E:AddColorPicker(cfg)
		local r = Row(cfg.Icon, "eye", nil, nil, cfg.Name)
		Lbl(r, cfg.Name, D.FIELD + 24)
		local f = Field(r, D.FIELD)
		local sw = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = cfg.Default or Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(Color3.new(1, 1, 1), 1, 0.6) })
		local hex = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -52, 1, 0), Font = Enum.Font.Gotham, Text = "", TextSize = D.TXT, TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
		})
		local chev = Icon("chevron", f, T.Dim, 14)
		chev.AnchorPoint = Vector2.new(1, 0.5)
		chev.Position = UDim2.new(1, -6, 0.5, 0)

		local PW, PH = 196, 128
		local pop = Popup(f, PW, PH + 20)
		local sv = New("Frame", {
			Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(PW - 52, PH), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 0, 0),
			ClipsDescendants = true, ZIndex = 63, Parent = pop.Frame,
		}, { Corner(6) })
		New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 64, Parent = sv }, {
			New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 65, Parent = sv }, {
			New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }),
		})
		local cursor = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 67, Parent = sv,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(Color3.new(1, 1, 1), 2, 0) })
		local hue = New("Frame", {
			Position = UDim2.new(0, PW - 32, 0, 10), Size = UDim2.fromOffset(22, PH), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 63, Parent = pop.Frame,
		}, {
			Corner(6),
			New("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
					ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
					ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
					ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
					ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
					ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
				}),
			}),
		})
		local hmark = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 64, Parent = hue,
		}, { Corner(2), Stroke(Color3.new(0, 0, 0), 1, 0.3) })

		local obj = { Value = cfg.Default or Color3.new(1, 1, 1), Type = "ColorPicker" }
		local h, s, v = obj.Value:ToHSV()
		local function render()
			obj.Value = Color3.fromHSV(h, s, v)
			sw.BackgroundColor3 = obj.Value
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			cursor.Position = UDim2.fromScale(s, 1 - v)
			hmark.Position = UDim2.fromScale(0.5, h)
			hex.Text = "#" .. obj.Value:ToHex():upper()
		end
		function obj:Set(c, silent)
			h, s, v = c:ToHSV()
			render()
			Commit(cfg, obj, silent)
		end
		function obj:Get() return obj.Value end
		Drag(sv, function(i)
			s = math.clamp((i.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
			v = 1 - math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
			render()
			Commit(cfg, obj)
		end, nil, nil, W.Conns)
		Drag(hue, function(i)
			h = math.clamp((i.Position.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
			render()
			Commit(cfg, obj)
		end, nil, nil, W.Conns)
		pop.OnClose = function() Tw(chev, { Rotation = 0 }, 0.15) end
		Tap(Hit(r), function()
			if pop.Frame.Visible then
				pop:Close()
			else
				pop:Open()
				Tw(chev, { Rotation = 180 }, 0.15)
			end
		end)
		render()
		Register(cfg, obj)
		if cfg.Default then Commit(cfg, obj, false) end
		return obj
	end

	function E:AddKeybind(cfg)
		local r = Row(cfg.Icon, "bolt", nil, nil, cfg.Name)
		Lbl(r, cfg.Name, 110)
		local f = Field(r, 86)
		local btn = New("TextButton", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AutoButtonColor = false, Font = Enum.Font.GothamMedium, TextSize = D.TXT, TextColor3 = T.Text, Text = "", ZIndex = 5, Parent = f,
		})
		local obj = { Value = cfg.Default or Enum.KeyCode.Unknown, Type = "Keybind" }
		local listening = false
		local function render()
			btn.Text = listening and "..." or (obj.Value == Enum.KeyCode.Unknown and "None" or obj.Value.Name)
		end
		function obj:Set(k, silent)
			obj.Value = k
			listening = false
			render()
			if cfg.Flag then
				Library.Flags[cfg.Flag] = k
				if not silent then Library:_emit(cfg.Flag, k) end
			end
			if not silent then Safe(cfg.Changed, k) end
		end
		function obj:Get() return obj.Value end
		Tap(btn, function()
			listening = true
			render()
		end)
		table.insert(W.Conns, UIS.InputBegan:Connect(function(i, gp)
			if listening then
				if i.UserInputType == Enum.UserInputType.Keyboard then
					obj:Set(i.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or i.KeyCode)
				end
			elseif not gp and i.UserInputType == Enum.UserInputType.Keyboard and obj.Value ~= Enum.KeyCode.Unknown and i.KeyCode == obj.Value then
				Safe(cfg.Callback)
			end
		end))
		render()
		Register(cfg, obj)
		return obj
	end

	function E:AddLink(cfg)
		cfg = cfg or {}
		local h = D.ROW + 20
		local r = Row(cfg.Icon, "link", h, D.ROW / 2, cfg.Name)
		Lbl(r, cfg.Name or "Link", 120, { Size = UDim2.new(1, -(LX + 120), 0, D.ROW) })
		local urlLabel = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(LX, D.ROW - 4), Size = UDim2.new(1, -(LX + 12), 0, 16), Font = Enum.Font.Gotham, Text = (type(cfg.Url) == "string" and cfg.Url ~= "") and cfg.Url or "Not set",
			TextSize = D.TXT - 1, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r,
		})
		local f = Field(r, 78, { Position = UDim2.new(1, -12, 0, D.ROW / 2) })
		local flash = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = W.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = f }, { Corner(6) })
		local fl = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamMedium, Text = "Copy", TextSize = D.TXT, TextColor3 = T.Text, ZIndex = 3, Parent = f,
		})
		local btn = New("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = f })
		Tap(btn, function()
			if type(cfg.Url) ~= "string" or cfg.Url == "" then
				Library:Notify({ Title = cfg.Name or "Link", Content = "The community link is not set, please try again later.", Duration = 3.5 })
			elseif Library:Copy(cfg.Url) then
				fl.Text = "Copied"
				flash.BackgroundTransparency = 0.6
				Tw(flash, { BackgroundTransparency = 1 }, 0.4)
				task.delay(1.5, function()
					if fl.Parent then fl.Text = "Copy" end
				end)
			else
				Library:Notify({ Title = cfg.Name or "Link", Content = "Clipboard is not supported by your executor. Copy the link manually.", Duration = 4 })
			end
		end)
		local obj = {}
		function obj:SetUrl(u)
			cfg.Url = u
			urlLabel.Text = (type(u) == "string" and u ~= "") and u or "Not set"
		end
		return obj
	end

	function E:Toggle(name, default, callback, flag)
		return E:AddToggle({ Name = name, Default = default, Callback = callback, Flag = flag or W:AutoFlag(name) })
	end

	function E:Slider(name, min, max, default, callback, flag)
		return E:AddSlider({ Name = name, Min = min, Max = max, Default = default, Callback = callback, Flag = flag or W:AutoFlag(name) })
	end

	function E:Dropdown(name, options, default, callback, flag)
		return E:AddDropdown({ Name = name, Options = options, Default = default, Callback = callback, Flag = flag or W:AutoFlag(name) })
	end

	function E:Input(name, default, callback, flag)
		return E:AddTextBox({ Name = name, Default = default, Callback = callback, Flag = flag or W:AutoFlag(name) })
	end

	function E:Color(name, default, callback, flag)
		return E:AddColorPicker({ Name = name, Default = default, Callback = callback, Flag = flag or W:AutoFlag(name) })
	end

	function E:Key(name, default, callback, flag)
		return E:AddKeybind({ Name = name, Default = default, Callback = callback, Flag = flag or W:AutoFlag(name) })
	end

	function E:Button(name, callback)
		return E:AddButton({ Name = name, Callback = callback })
	end

	function E:Label(text)
		return E:AddLabel(text)
	end

	function E:Link(name, url, icon)
		return E:AddLink({ Name = name, Url = url, Icon = icon })
	end

	return E
end

function Library:Notify(cfg)
	local W = self.Active
	if not W then return end
	cfg = cfg or {}
	local item = New("Frame", {
		Size = UDim2.new(0, 0, 0, 46), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.Pop, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = W.NotifyHolder,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke(T.Line, 1.2, 0.25),
		New("UISizeConstraint", { MaxSize = Vector2.new(MOBILE and 320 or 420, 100) }),
		Pad(9, 0, 14, 0),
		List(10, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	local pop = New("UIScale", { Scale = 0.9, Parent = item })
	local badge = New("Frame", {
		Size = UDim2.fromOffset(28, 28), BackgroundColor3 = W.Accent, BorderSizePixel = 0, LayoutOrder = 1, Parent = item,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local check = Icon("check", badge, Color3.new(1, 1, 1), 16)
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	check.Position = UDim2.fromScale(0.5, 0.5)
	local text = cfg.Content or ""
	if cfg.Title and cfg.Title ~= "" then
		text = "<font color=\"rgb(150,162,235)\">" .. cfg.Title .. "</font>  " .. text
	end
	local msg = New("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, RichText = true, Text = text, TextSize = 13,
		TextColor3 = T.Text, TextTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 2, Parent = item,
	})
	local closeX = New("TextButton", {
		Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 3, Parent = item,
	})
	local cross = Icon("cross", closeX, T.Dim, 14)
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	Tw(item, { BackgroundTransparency = 0.05 }, 0.25)
	Tw(msg, { TextTransparency = 0 }, 0.25)
	Tw(pop, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
	local closed = false
	local function dismiss()
		if closed or not item.Parent then return end
		closed = true
		Tw(item, { BackgroundTransparency = 1 }, 0.25)
		Tw(msg, { TextTransparency = 1 }, 0.25)
		Tw(pop, { Scale = 0.9 }, 0.25)
		task.wait(0.3)
		item:Destroy()
	end
	Tap(closeX, function() dismiss() end)
	task.delay(cfg.Duration or 4, dismiss)
end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local env = (getgenv and getgenv()) or _G
	if env.UnflyUiWindow then
		pcall(function() env.UnflyUiWindow:Destroy() end)
	end
	for k in pairs(Library.Flags) do Library.Flags[k] = nil end
	for k in pairs(Library.Options) do Library.Options[k] = nil end
	for k in pairs(Library.Listeners) do Library.Listeners[k] = nil end
	local W = {
		Conns = {}, AccentFns = {}, NeonFns = {}, TransObjs = {}, Tabs = {}, MainTabs = {}, FlagObjs = {}, MemCfg = {}, LogoSlots = {}, NameFns = {}, TabByName = {}, Loops = {}, UnloadFns = {}, LinkObjs = {}, State = "open", RowIcons = cfg.ElementIcons == true, Search = {}, Sections = {},
		Trans = 0, UserScale = 1, CurrentConfig = "Default", ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift,
		Accent = cfg.Accent or Color3.fromRGB(104, 122, 255), Neon = cfg.Neon or Color3.fromRGB(128, 148, 255),
	}
	local NAME = cfg.Name or "UnflyUi"
	local PUBLISHER = "UnflyTm"
	local TAGLINE = cfg.Tagline or "Better UI - Better Experience"
	local FOLDER = cfg.ConfigFolder or "UnflyUi"
	local CFGDIR = FOLDER .. "/configs"
	local SETFILE = FOLDER .. "/settings.json"
	local SIZE = cfg.Size or Vector2.new(D.W, D.H)
	local vp0 = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
	W.OneCol = (SIZE.X - D.SB) < 520 or vp0.X < 500
	W.Cur = SIZE
	W.Name = NAME

	function W:BindAccent(fn)
		table.insert(W.AccentFns, fn)
		fn(W.Accent)
	end

	function W:BindNeon(fn)
		table.insert(W.NeonFns, fn)
		fn(W.Neon)
	end

	function W:Reg(obj, base)
		table.insert(W.TransObjs, { obj, base })
		obj.BackgroundTransparency = base + (1 - base) * W.Trans
	end

	function W:SetTransparency(t)
		W.Trans = math.clamp(t, 0, 0.85)
		for _, e in ipairs(W.TransObjs) do
			if e[1].Parent then e[1].BackgroundTransparency = e[2] + (1 - e[2]) * W.Trans end
		end
	end

	function W:SetAccent(c)
		W.Accent = c
		for _, fn in ipairs(W.AccentFns) do pcall(fn, c) end
	end

	function W:SetNeon(c)
		W.Neon = c
		for _, fn in ipairs(W.NeonFns) do pcall(fn, c) end
	end

	local gui = MakeGui()
	W.Gui = gui
	Library.Active = W

	local root = New("Frame", {
		Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SIZE.X, SIZE.Y), BackgroundColor3 = T.Bg,
		BorderSizePixel = 0, ClipsDescendants = true, Active = true, Parent = gui,
	}, {
		Corner(16),
		New("UIGradient", {
			Rotation = 120,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 19, 43)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(8, 9, 27)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 6, 22)),
			}),
		}),
	})
	W.Root = root
	TweenService:Create(root.UIGradient, TweenInfo.new(30, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 480 }):Play()
	W:Reg(root, 0.02)
	local rs = Stroke(Color3.fromRGB(140, 156, 255), 1.6, 0.3)
	rs.Parent = root
	local rsGradient = New("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0.1) }),
		Parent = rs,
	})
	TweenService:Create(rsGradient, TweenInfo.new(9, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 405 }):Play()
	local uiscale = New("UIScale", { Parent = root })
	W.Scale = uiscale

	local function ApplyScale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local target = math.max(0.35, math.min(1, (vp.X - 16) / W.Cur.X, (vp.Y - 16) / W.Cur.Y)) * W.UserScale
		W.TargetScale = target
		uiscale.Scale = target
	end

	function W:SetScale(s)
		W.UserScale = math.clamp(s, 0.5, 1.5)
		ApplyScale()
	end

	ApplyScale()
	if workspace.CurrentCamera then
		table.insert(W.Conns, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ApplyScale))
	end

	local function LongPressDrag(obj, onTap)
		local active
		obj.InputBegan:Connect(function(i)
			if not IsPointer(i) then return end
			local rec = { start = i.Position, base = obj.Position, drag = false }
			active = rec
			task.delay(0.5, function()
				if active == rec and i.UserInputState ~= Enum.UserInputState.End then rec.drag = true end
			end)
			local c
			c = i.Changed:Connect(function()
				if i.UserInputState ~= Enum.UserInputState.End then return end
				c:Disconnect()
				if active == rec then
					active = nil
					if onTap and not rec.drag and (i.Position - rec.start).Magnitude <= TAP_SLOP then task.spawn(onTap) end
				end
			end)
		end)
		table.insert(W.Conns, UIS.InputChanged:Connect(function(i)
			if active and active.drag and IsMove(i) then
				local d = i.Position - active.start
				local b = active.base
				obj.Position = UDim2.new(b.X.Scale, b.X.Offset + d.X, b.Y.Scale, b.Y.Offset + d.Y)
			end
		end))
	end

	local function Pulse(o, props, t)
		TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props):Play()
	end

	local particleLayer = New("Frame", {
		Name = "Particles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1, ClipsDescendants = true, Parent = root,
	})
	local function Particle()
		local size = math.random(2, 4)
		local p = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(), 0, 1.1, 0), Size = UDim2.fromOffset(size * 2.4, size * 1.3), Rotation = math.random(0, 180), BackgroundColor3 = Color3.fromRGB(196, 212, 255),
			BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1, Parent = particleLayer,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Pulse(p, { BackgroundTransparency = 0.97 }, 1 + math.random() * 2)
		task.spawn(function()
			task.wait(math.random() * 10)
			if not p.Parent then return end
			TweenService:Create(
				p,
				TweenInfo.new(9 + math.random() * 9, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
				{ Position = UDim2.new(math.random(), 0, -0.1, 0) }
			):Play()
		end)
	end
	for _ = 1, (MOBILE and 14 or 24) do Particle() end
	for idx, size in ipairs({ 440, 350, 270 }) do
		New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.56, 0.0), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(150, 170, 255),
			BackgroundTransparency = 0.975 - idx * 0.006, BorderSizePixel = 0, ZIndex = 1, Parent = particleLayer,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	local overlay = New("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Parent = root })
	W.Overlay = overlay
	W.Blocker = New("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 61, Parent = overlay,
	})
	function W:ClosePopup()
		if W.OpenPop then W.OpenPop:Close() end
	end
	Tap(W.Blocker, function() W:ClosePopup() end)

	local function ResolveImage(src)
		if src:match("^rbxassetid://") or src:match("^rbxasset://") or src:match("^rbxthumb://") then return src end
		if src:match("^%d+$") then return "rbxassetid://" .. src end
		if src:match("^https?://") then
			local getasset = getcustomasset or getsynasset
			if not (writefile and getasset and makefolder and isfolder) then return nil end
			local cachePath = (src == DEFAULT_LOGO) and (FOLDER .. "/logo_" .. UrlHash(src) .. ".png") or nil
			if cachePath and isfile then
				local okc, cached = pcall(function()
					if isfile(cachePath) then return getasset(cachePath) end
					return nil
				end)
				if okc and cached then return cached end
			end
			local ok, data = pcall(function() return game:HttpGet(src) end)
			if not ok or not IsImageData(data) then return nil end
			local ok2, asset = pcall(function()
				if not isfolder(FOLDER) then makefolder(FOLDER) end
				local path = cachePath or (FOLDER .. "/logo_" .. tostring(#data) .. ".png")
				writefile(path, data)
				return getasset(path)
			end)
			if ok2 and asset then return asset end
		end
		return nil
	end

	function W:SetLogo(src)
		src = tostring(src or "")
		src = src:match("^%s*(.-)%s*$")
		local img = ResolveImage(src ~= "" and src or DEFAULT_LOGO)
		if src ~= "" and not img then return false end
		W.LogoImage = img
		W.LogoSource = src
		for _, slot in ipairs(W.LogoSlots) do
			if slot.drawn.Parent then
				slot.drawn.Visible = (img == nil)
				slot.img.Visible = (img ~= nil)
				if img then slot.img.Image = img end
			end
		end
		return true
	end

	function W:SetName(n)
		n = tostring(n or "")
		if n == "" then return end
		W.Name = n
		for _, fn in ipairs(W.NameFns) do pcall(fn, n) end
	end

	local function LogoSlot(parent, w, h, scale, circle)
		local slot = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), Parent = parent })
		local drawn = Logo(slot, scale)
		drawn.AnchorPoint = Vector2.new(0.5, 0.5)
		drawn.Position = UDim2.fromScale(0.5, 0.5)
		local img = New("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = circle and Enum.ScaleType.Crop or Enum.ScaleType.Fit, Visible = false, Parent = slot,
		}, circle and { New("UICorner", { CornerRadius = UDim.new(1, 0) }) } or {})
		table.insert(W.LogoSlots, { drawn = drawn, img = img })
		if W.LogoImage then
			drawn.Visible = false
			img.Image = W.LogoImage
			img.Visible = true
		end
		return slot
	end

	local HEAD = D.HEAD
	local SBW = D.SB
	local MAINX = SBW + 28

	local header = New("Frame", {
		Name = "Header", Position = UDim2.fromOffset(MAINX, 12), Size = UDim2.new(1, -(MAINX + 16), 0, HEAD), BackgroundTransparency = 1, Active = true, ZIndex = 3, Parent = root,
	})

	local titleLbl = New("TextLabel", {
		Name = "PageTitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -(MOBILE and 160 or 280), 0, MOBILE and 40 or 56),
		Font = Enum.Font.Garamond, Text = NAME, TextSize = MOBILE and 36 or 50, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = header,
	})
	local subLbl = New("TextLabel", {
		Name = "PageSubtitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(2, MOBILE and 40 or 58), Size = UDim2.new(1, -(MOBILE and 170 or 300), 0, 24),
		Font = Enum.Font.Garamond, Text = TAGLINE, TextSize = MOBILE and 17 or 21, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = header,
	})

	local function Sparkle(parent, cx, cy, size, color)
		local g = New("Frame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(size * 2, size * 2), Parent = parent,
		})
		Bar(g, size, size, size * 2, 2, color, 0, 1)
		Bar(g, size, size, 2, size * 2, color, 0, 1)
		Bar(g, size, size, size * 1.2, 1.4, color, 45, 1)
		Bar(g, size, size, size * 1.2, 1.4, color, -45, 1)
		return g
	end
	local sparkleX = MOBILE and 230 or 360
	local sparkle = Sparkle(header, sparkleX, MOBILE and 52 or 70, 9, Color3.fromRGB(214, 222, 255))
	sparkle.ZIndex = 4
	Pulse(sparkle, { Rotation = 90 }, 3.2)
	New("Frame", {
		Position = UDim2.fromOffset(sparkleX + 12, MOBILE and 52 or 70), Size = UDim2.fromOffset(MOBILE and 60 or 110, 1), BackgroundColor3 = Color3.fromRGB(176, 190, 255), BorderSizePixel = 0, ZIndex = 4, Parent = header,
	}, { New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })

	local function CtrlButton(cx, iconName)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, cx, 0, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = T.Field, BackgroundTransparency = 0.2,
			BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 5, Parent = header,
		}, { Corner(11), Stroke(T.Line, 1, 0.3) })
		local ic = Icon(iconName, b, T.Text, 16)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		return b
	end
	local closeBtn = CtrlButton(0, "cross")
	local minBtn = CtrlButton(-42, "minus")

	local searchW = MOBILE and 150 or 250
	local FB = MOBILE and 38 or 42
	local searchY = MOBILE and 44 or 50
	local search = New("Frame", {
		Name = "Search", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(FB + 10), 0, searchY), Size = UDim2.fromOffset(searchW, FB), BackgroundColor3 = T.Field,
		BorderSizePixel = 0, ZIndex = 4, Parent = header,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(T.Line, 1.2, 0.25) })
	W:Reg(search, 0.2)
	local mag = Icon("search", search, T.Dim, 18)
	mag.Position = UDim2.new(0, 14, 0.5, -9)
	mag.ZIndex = 5
	local sbox = New("TextBox", {
		Name = "SearchBox", BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -52, 1, 0), Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = T.Text,
		PlaceholderText = "Search...", PlaceholderColor3 = T.Dim, Text = "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = search,
	})
	local filterBtn = New("TextButton", {
		Name = "FilterButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, searchY), Size = UDim2.fromOffset(FB, FB), BackgroundColor3 = T.Field, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "", ZIndex = 4, Parent = header,
	}, { Corner(14), Stroke(T.Line, 1.2, 0.25) })
	local filterIcon = Icon("sliders", filterBtn, T.Text, 20)
	filterIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	filterIcon.Position = UDim2.fromScale(0.5, 0.5)

	function W:Filter(q)
		q = string.lower(q or "")
		for _, e in ipairs(W.Search) do
			e.row.Visible = (q == "" or string.find(e.name, q, 1, true) ~= nil)
		end
		for _, sct in ipairs(W.Sections) do
			local any = false
			for _, r in ipairs(sct.rows) do
				if r.Visible then
					any = true
					break
				end
			end
			sct.frame.Visible = any or q == "" or #sct.rows == 0
		end
	end
	sbox:GetPropertyChangedSignal("Text"):Connect(function() W:Filter(sbox.Text) end)
	Tap(filterBtn, function()
		sbox.Text = ""
		W:Filter("")
	end)

	local BOT = D.BOT
	local sidebar = New("Frame", {
		Name = "Sidebar", Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0, SBW, 1, -24), BackgroundColor3 = T.Panel, BorderSizePixel = 0, Active = true, ZIndex = 3, Parent = root,
	}, { Corner(22), Stroke(T.Line, 1.3, 0.15) })
	W:Reg(sidebar, 0.2)

	local LOGO = MOBILE and 62 or 86
	for idx, extra in ipairs({ 54, 34, 16 }) do
		local g = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 18 + LOGO / 2), Size = UDim2.fromOffset(LOGO + extra, LOGO + extra), BackgroundColor3 = W.Accent,
			BackgroundTransparency = 0.96 - idx * 0.01, BorderSizePixel = 0, ZIndex = 3, Parent = sidebar,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		W:BindAccent(function(c) g.BackgroundColor3 = c end)
		Pulse(g, { BackgroundTransparency = 0.9 - idx * 0.01 }, 2.4 + idx * 0.4)
	end
	local logo = LogoSlot(sidebar, LOGO, LOGO, LOGO / 56, false)
	logo.AnchorPoint = Vector2.new(0.5, 0)
	logo.Position = UDim2.new(0.5, 0, 0, 18)
	logo.ZIndex = 4

	local NAVTOP = 18 + LOGO + 22
	local WIDGET_H = MOBILE and 76 or 92
	local CARD_H = D.TAB + 6
	local tabScroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(8, NAVTOP), Size = UDim2.new(1, -16, 1, -(NAVTOP + CARD_H + WIDGET_H + 26)), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = sidebar,
	}, { List(6) })

	local card = New("TextButton", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -(WIDGET_H + 16)), Size = UDim2.new(1, -16, 0, D.TAB), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 4, Parent = sidebar,
	}, { Corner(14), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(128, 144, 255), Color3.fromRGB(78, 92, 226)) }) })
	local cardStroke = Stroke(Color3.fromRGB(176, 190, 255), 1.2, 1)
	cardStroke.Parent = card
	local cardIcon = Icon("gear", card, T.Text, 22)
	cardIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	cardIcon.Position = UDim2.new(0, 28, 0.5, 0)
	cardIcon.ZIndex = 5
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -56, 1, 0), Font = Enum.Font.Garamond, Text = "Settings", TextSize = MOBILE and 18 or 21,
		TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = card,
	})
	W.SettingsBtn = card
	W.SettingsStroke = cardStroke

	local wcfg = type(cfg.Widget) == "table" and cfg.Widget or {}
	local widget = New("Frame", {
		Name = "Widget", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, WIDGET_H), BackgroundColor3 = T.Field, BorderSizePixel = 0,
		ZIndex = 4, Parent = sidebar,
	}, { Corner(18), Stroke(T.Line, 1.2, 0.25) })
	W:Reg(widget, 0.15)
	local eq = New("Frame", {
		Name = "Equalizer", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1, ZIndex = 5, Parent = widget,
	}, { New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	}) })
	for i = 1, (MOBILE and 14 or 20) do
		local hmax = math.random(8, 26)
		local bar = New("Frame", {
			Size = UDim2.fromOffset(3, math.random(3, 8)), BackgroundColor3 = T.Dim, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 5, Parent = eq,
		}, { Corner(2) })
		W:BindAccent(function(c) bar.BackgroundColor3 = c:Lerp(Color3.new(1, 1, 1), 0.3) end)
		Pulse(bar, { Size = UDim2.fromOffset(3, hmax) }, 0.35 + math.random() * 0.7)
	end
	local wAvatar = New("Frame", {
		Position = UDim2.new(0, 10, 1, -46), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = T.Panel, BorderSizePixel = 0, ZIndex = 5, Parent = widget,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(T.Line, 1.2, 0.2) })
	local wSlot = LogoSlot(wAvatar, 36, 36, 0.45, true)
	wSlot.ZIndex = 6
	local wTitle = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 54, 1, -46), Size = UDim2.new(1, -62, 0, 18), Font = Enum.Font.GothamMedium, Text = wcfg.Title or NAME, TextSize = 13,
		TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = widget,
	})
	if wcfg.Title == nil then table.insert(W.NameFns, function(n) wTitle.Text = n end) end
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 54, 1, -27), Size = UDim2.new(1, -62, 0, 16), Font = Enum.Font.Gotham, Text = wcfg.Subtitle or ("Created by " .. PUBLISHER),
		TextSize = 11, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = widget,
	})

	local content = New("Frame", {
		Name = "Content", Position = UDim2.fromOffset(MAINX, 12 + HEAD + 10), Size = UDim2.new(1, -(MAINX + 16), 1, -(12 + HEAD + 10 + BOT + 24)), BackgroundTransparency = 1, ZIndex = 3, Parent = root,
	})

	local bottom = New("Frame", {
		Name = "Bottom", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, MAINX, 1, -12), Size = UDim2.new(1, -(MAINX + 16), 0, BOT), BackgroundColor3 = T.Card, BorderSizePixel = 0, ZIndex = 4, Parent = root,
	}, { Corner(18), Stroke(T.Line, 1.2, 0.3) })
	W:Reg(bottom, 0.3)
	local bi = Icon("expand", bottom, T.IconC, 18)
	bi.Position = UDim2.new(0, 14, 0.5, -9)
	bi.ZIndex = 5
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(80, BOT), Font = Enum.Font.Gotham, Text = cfg.SizeLabel or "Размер GUI", TextSize = 12,
		TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = bottom,
	})
	local sTrackW = MOBILE and 110 or 200
	local sTrack = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 130, 0.5, 0), Size = UDim2.fromOffset(sTrackW, 6), BackgroundColor3 = T.Off, BorderSizePixel = 0, ZIndex = 5, Parent = bottom,
	}, { Corner(3), Stroke(T.Line, 1, 0.6) })
	local sFill = New("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6, Parent = sTrack }, {
		Corner(3),
		New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(67, 75, 135), Color3.fromRGB(249, 253, 255)) }),
	})
	local sKnob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(MOBILE and 18 or 14, MOBILE and 18 or 14), BackgroundColor3 = T.Knob, BorderSizePixel = 0,
		ZIndex = 7, Parent = sTrack,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(Color3.new(1, 1, 1), 1, 0.55) })
	local sVal = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 142 + sTrackW, 0, 0), Size = UDim2.fromOffset(50, BOT), Font = Enum.Font.Gotham, Text = "100%", TextSize = 12, TextColor3 = T.Dim,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = bottom,
	})
	local function RenderSize()
		local a = (W.UserScale - 0.5) / 1.0
		sFill.Size = UDim2.fromScale(a, 1)
		sKnob.Position = UDim2.fromScale(a, 0.5)
		sVal.Text = math.floor(W.UserScale * 100 + 0.5) .. "%"
	end
	local sHit = New("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 122, 0.5, 0), Size = UDim2.fromOffset(sTrackW + 16, BOT),
		ZIndex = 8, Parent = bottom,
	})
	Drag(sHit, function(i)
		local a = math.clamp((i.Position.X - sTrack.AbsolutePosition.X) / math.max(sTrack.AbsoluteSize.X, 1), 0, 1)
		W:SetScale(Round(0.5 + a, 0.05))
		RenderSize()
	end, nil, nil, W.Conns)
	RenderSize()

	local movePill = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0), Size = UDim2.fromOffset(MOBILE and 150 or 250, BOT - 14), BackgroundColor3 = Color3.fromRGB(7, 7, 24),
		BackgroundTransparency = 0.2, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 5, Parent = bottom,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(T.Line, 1, 0.3) })
	local li = Icon("lock", movePill, T.IconC, 15)
	li.Position = UDim2.new(0, 14, 0.5, -7.5)
	li.ZIndex = 6
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -44, 1, 0), Font = Enum.Font.Gotham, Text = cfg.DragLabel or "Перетащите чтобы переместить",
		TextSize = MOBILE and 10 or 11, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = movePill,
	})

	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9, Parent = root,
	})
	Bar(grip, 17, 17, 14, 1.4, T.Dim, -45)
	Bar(grip, 18, 12, 8, 1.4, T.Dim, -45)
	Bar(grip, 12, 18, 8, 1.4, T.Dim, -45)

	local sm, sp
	local function StartDrag(i)
		sm = i.Position
		sp = root.Position
	end
	local function MoveDrag(i)
		if not sm then return end
		local d = i.Position - sm
		root.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
	end
	Drag(header, MoveDrag, StartDrag, function() sm = nil end, W.Conns)
	Drag(movePill, MoveDrag, StartDrag, function() sm = nil end, W.Conns)

	local rs0, rsz
	Drag(grip, function(i)
		if not rs0 then return end
		local d = (i.Position - rs0) / uiscale.Scale
		local nx = math.clamp(rsz.X + d.X * 2, 560, 1400)
		local ny = math.clamp(rsz.Y + d.Y * 2, 340, 900)
		W.Cur = Vector2.new(nx, ny)
		root.Size = UDim2.fromOffset(nx, ny)
		ApplyScale()
	end, function(i)
		rs0 = i.Position
		rsz = W.Cur
	end, function() rs0 = nil end, W.Conns)

	W.NotifyHolder = New("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.new(0, 440, 1, -32), BackgroundTransparency = 1, Parent = gui,
	}, { List(8, { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Left }) })

	local barW = MOBILE and 176 or 210
	local collapsed = New("Frame", {
		Name = "CollapsedBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(barW, 36), BackgroundColor3 = T.Card,
		BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 45, Parent = gui,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(T.Line, 1, 0.1) })
	local barIcon = New("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		ZIndex = 46, Parent = collapsed,
	})
	local barSlot = LogoSlot(barIcon, 28, 28, 0.42, true)
	barSlot.ZIndex = 47
	local barName = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -84, 1, 0), Font = Enum.Font.GothamMedium, Text = NAME, TextSize = 13, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 46, Parent = collapsed,
	})
	table.insert(W.NameFns, function(n) barName.Text = n end)
	local barClose = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		ZIndex = 46, Parent = collapsed,
	})
	local barCross = Icon("cross", barClose, T.Text, 14)
	barCross.AnchorPoint = Vector2.new(0.5, 0.5)
	barCross.Position = UDim2.fromScale(0.5, 0.5)
	if cfg.DraggableButton then LongPressDrag(collapsed) end

	function W:SetState(state)
		W:ClosePopup()
		W.State = state
		root.Visible = (state == "open")
		if state == "open" and W.TargetScale then
			uiscale.Scale = W.TargetScale * 0.94
			Tw(uiscale, { Scale = W.TargetScale }, 0.28, Enum.EasingStyle.Back)
		end
		collapsed.Visible = (state == "collapsed")
	end
	function W:SetVisible(v) W:SetState(v and "open" or "hidden") end
	function W:Toggle() W:SetState(W.State == "open" and "hidden" or "open") end

	Tap(minBtn, function() W:SetState("collapsed") end)
	Tap(barIcon, function() W:SetState("open") end)
	Tap(barClose, function() W:SetState("hidden") end)

	local closeArmed = false
	Tap(closeBtn, function()
		if closeArmed then
			W:Destroy()
			return
		end
		closeArmed = true
		Library:Notify({ Title = "Unload", Content = "Tap X again to unload the interface.", Duration = 2 })
		task.delay(2, function() closeArmed = false end)
	end)

	table.insert(W.Conns, UIS.InputBegan:Connect(function(i, gp)
		if not gp and i.KeyCode == W.ToggleKey then W:Toggle() end
	end))

	local NB = MOBILE and 46 or 42
	local nb = New("TextButton", {
		Name = "NeonButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 42, 0.5, 0), Size = UDim2.fromOffset(NB + 22, NB + 22), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, ZIndex = 50, Parent = gui,
	})
	local halo = {}
	local haloDim = { 0.96, 0.93, 0.89 }
	local haloBright = { 0.9, 0.84, 0.76 }
	for idx, extra in ipairs({ 20, 13, 6 }) do
		halo[idx] = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(NB + extra, NB + extra), BackgroundColor3 = W.Neon,
			BackgroundTransparency = haloDim[idx], BorderSizePixel = 0, ZIndex = 50, Parent = nb,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	local core = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(NB, NB), BackgroundColor3 = Color3.fromRGB(7, 7, 24), BorderSizePixel = 0,
		ZIndex = 51, Parent = nb,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(Color3.new(1, 1, 1), 2.2, 0) })
	local shine = New("UIGradient", { Parent = core.UIStroke })
	local nslot = LogoSlot(core, NB, NB, 0.5, true)
	nslot.AnchorPoint = Vector2.new(0.5, 0.5)
	nslot.Position = UDim2.fromScale(0.5, 0.5)
	nslot.ZIndex = 52
	W:BindNeon(function(c)
		local bright = c:Lerp(Color3.new(1, 1, 1), 0.85)
		shine.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(0.5, bright),
			ColorSequenceKeypoint.new(1, c),
		})
		shine.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.35),
		})
		for _, f in ipairs(halo) do f.BackgroundColor3 = c end
	end)
	TweenService:Create(shine, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 }):Play()
	task.spawn(function()
		while nb.Parent do
			for i, f in ipairs(halo) do Tw(f, { BackgroundTransparency = haloBright[i] }, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end
			task.wait(1.4)
			for i, f in ipairs(halo) do Tw(f, { BackgroundTransparency = haloDim[i] }, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end
			task.wait(1.4)
		end
	end)
	if cfg.DraggableButton then
		LongPressDrag(nb, function() W:Toggle() end)
	else
		Tap(nb, function() W:Toggle() end)
	end
	W.NeonBtn = nb

	local SHIELD_NAME = "UnflyUiShield"
	local function Inside(obj, pos)
		if not obj or not obj.Visible then return false end
		local p, sz = obj.AbsolutePosition, obj.AbsoluteSize
		return pos.X >= p.X and pos.X <= p.X + sz.X and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y
	end
	pcall(function()
		ContextActionService:BindActionAtPriority(
			SHIELD_NAME,
			function(_, _, input)
				local pos = input.Position
				if Inside(root, pos) or Inside(collapsed, pos) or Inside(nb, pos) then
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end,
			false,
			4000,
			Enum.UserInputType.MouseButton1,
			Enum.UserInputType.MouseButton2,
			Enum.UserInputType.MouseWheel,
			Enum.UserInputType.Touch
		)
	end)
	for _, f in ipairs({ sidebar, content, bottom }) do f.Active = true end

	function W:SetFloatButton(v) nb.Visible = v end

	local function MakeTab(tcfg, hidden)
		tcfg = type(tcfg) == "string" and { Name = tcfg } or tcfg
		local tab = { Hidden = hidden, Top = 0, Sections = {}, Name = tcfg.Name, Subtitle = tcfg.Subtitle }
		if not hidden then W.TabByName[tcfg.Name] = tab end
		if not hidden then
			local btn = New("TextButton", {
				Size = UDim2.new(1, 0, 0, D.TAB), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 4,
				Parent = tabScroll,
			}, { Corner(14), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(128, 144, 255), Color3.fromRGB(78, 92, 226)) }) })
			local st = Stroke(Color3.fromRGB(176, 190, 255), 1.2, 1)
			st.Parent = btn
			local ic = Icon(tcfg.Icon or "ring", btn, Color3.new(1, 1, 1), 20)
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.new(0, 26, 0.5, 0)
			ic.ZIndex = 5
			local lbl = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -50, 1, 0), Font = Enum.Font.Garamond, Text = tcfg.Name, TextSize = MOBILE and 18 or 21,
				TextColor3 = Color3.fromRGB(224, 228, 255), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = btn,
			})
			tab.TabButton, tab.TabLabel, tab.TabStroke = btn, lbl, st
			table.insert(W.MainTabs, tab)
		end

		local page = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = content })
		local function Scroll(pos, size)
			return New("ScrollingFrame", {
				Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Dim, CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = page,
			}, { List(10), Pad(0, 0, 4, 6) })
		end
		local leftS, rightS
		if W.OneCol then
			leftS = Scroll(UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		else
			leftS = Scroll(UDim2.fromScale(0, 0), UDim2.new(0.5, -5, 1, 0))
			rightS = Scroll(UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 1, 0))
		end
		tab.Page, tab.Scrolls = page, { leftS, rightS }
		table.insert(W.Tabs, tab)

		local function Relayout()
			local top = tab.Top
			if W.OneCol then
				leftS.Position = UDim2.fromOffset(0, top)
				leftS.Size = UDim2.new(1, 0, 1, -top)
			else
				leftS.Position = UDim2.fromOffset(0, top)
				leftS.Size = UDim2.new(0.5, -5, 1, -top)
				rightS.Position = UDim2.new(0.5, 5, 0, top)
				rightS.Size = UDim2.new(0.5, -5, 1, -top)
			end
		end

		function tab:Select()
			W:ClosePopup()
			for _, t in ipairs(W.Tabs) do
				local on = (t == tab)
				t.Page.Visible = on
				if t.TabButton then
					Tw(t.TabButton, { BackgroundTransparency = on and 0.06 or 1 }, 0.15)
					Tw(t.TabStroke, { Transparency = on and 0.1 or 1 }, 0.15)
				end
			end
			W.CurrentScrolls = tab.Scrolls
			W.CurrentTab = tab
			titleLbl.Text = tab.Name or NAME
			subLbl.Text = tab.Subtitle or TAGLINE
			tab.Page.Position = UDim2.fromOffset(0, 12)
			Tw(tab.Page, { Position = UDim2.fromOffset(0, 0) }, 0.28, Enum.EasingStyle.Quart)
			if W.SettingsBtn then
				local on = (tab.Hidden == true)
				Tw(W.SettingsBtn, { BackgroundTransparency = on and 0.06 or 1 }, 0.15)
				Tw(W.SettingsStroke, { Transparency = on and 0.1 or 1 }, 0.15)
			end
		end

		if tab.TabButton then Tap(tab.TabButton, function() tab:Select() end) end
		if not hidden and not W.HasMain then
			W.HasMain = true
			tab:Select()
		end

		function tab:AddBanner(bcfg)
			bcfg = bcfg or {}
			local bh = MOBILE and 62 or 84
			local b = New("Frame", {
				Size = UDim2.new(1, 0, 0, bh), BackgroundColor3 = T.Card, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3, Parent = page,
			}, { Corner(20), Stroke(T.Line, 1.2, 0.25) })
			W:Reg(b, 0.2)
			local function shard(x, w, rot, tr)
				local f = New("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 0.5, 0), Size = UDim2.fromOffset(w, bh * 3), Rotation = rot, BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0, ZIndex = 3, Parent = b,
				}, { New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, tr), NumberSequenceKeypoint.new(1, 1) }) }) })
				Pulse(f, { Position = UDim2.new(x + 0.03, 0, 0.5, 0) }, 3.5 + math.random() * 3)
			end
			shard(0.72, 54, 32, 0.8)
			shard(0.82, 90, -28, 0.86)
			shard(0.9, 40, 32, 0.78)
			shard(0.5, 160, 32, 0.95)
			local hl = bcfg.Highlight or W.Name
			local bannerTitle = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(MOBILE and 16 or 24, bh * 0.14), Size = UDim2.new(0.7, 0, 0, bh * 0.44), Font = Enum.Font.Garamond, RichText = true,
				Text = (bcfg.Title or "Welcome to") .. " <font color=\"rgb(150,162,235)\">" .. hl .. "</font>", TextSize = MOBILE and 28 or 40, TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = b,
			})
			if not bcfg.Highlight then
				table.insert(W.NameFns, function(n)
					bannerTitle.Text = (bcfg.Title or "Welcome to") .. " <font color=\"rgb(150,162,235)\">" .. n .. "</font>"
				end)
			end
			New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(MOBILE and 16 or 26, bh * 0.6), Size = UDim2.new(0.7, 0, 0, bh * 0.24), Font = Enum.Font.Garamond,
				Text = bcfg.Subtitle or "Your perfect script hub for Roblox", TextSize = MOBILE and 16 or 20, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = b,
			})
			tab.Top = bh + 12
			Relayout()
		end

		local sorder, default = 0, nil
		function tab:AddSection(scfg)
			scfg = type(scfg) == "string" and { Name = scfg } or (scfg or {})
			sorder = sorder + 1
			local isRight = (not W.OneCol) and string.lower(tostring(scfg.Position or "left")) == "right"
			local parent = isRight and rightS or leftS
			local secCard = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = sorder, ZIndex = 3, Parent = parent,
			}, { Corner(20), Stroke(T.Line, 1.2, 0.25), Pad(12, 8, 12, 12), List(8) })
			W:Reg(secCard, 0.25)
			local hd = New("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 0, Parent = secCard })
			local hi = Icon(scfg.Icon or "gear", hd, T.IconC, 18)
			hi.Position = UDim2.new(0, 4, 0.5, -9)
			New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), Font = Enum.Font.Garamond, Text = scfg.Name or "Section", TextSize = MOBILE and 19 or 23,
				TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = hd,
			})
			local inner = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Inner, BorderSizePixel = 0, LayoutOrder = 1, Parent = secCard,
			}, { Corner(14), Stroke(T.Line, 1, 0.35), List(0) })
			W:Reg(inner, 0.2)
			local info = { rows = {}, frame = secCard }
			table.insert(W.Sections, info)
			local els = Elements(W, inner, info)
			if scfg.Name then tab.Sections[scfg.Name] = els end
			return els
		end

		for _, m in ipairs({ "AddLabel", "AddButton", "AddToggle", "AddSlider", "AddTextBox", "AddDropdown", "AddColorPicker", "AddKeybind", "AddLink", "Link", "Toggle", "Slider", "Dropdown", "Input", "Color", "Key", "Button", "Label" }) do
			tab[m] = function(_, ...)
				default = default or tab:AddSection("General")
				return default[m](default, ...)
			end
		end
		function tab:SetSubtitle(text)
			tab.Subtitle = text
			if W.CurrentTab == tab then subLbl.Text = text end
		end

		function tab:Section(name, position, icon)
			return tab.Sections[name] or tab:AddSection({ Name = name, Position = position, Icon = icon })
		end
		return tab
	end

	function W:AddTab(tcfg) return MakeTab(tcfg, false) end

	function W:Tab(name, icon)
		return W.TabByName[name] or W:AddTab({ Name = name, Icon = icon })
	end

	local function Serialize(obj)
		local t, v = obj.Type, obj.Value
		if t == "ColorPicker" then
			return { v.R, v.G, v.B }
		elseif t == "Keybind" then
			return v.Name
		elseif t == "Dropdown" and obj.Multi then
			local a = {}
			for k, on in pairs(v) do
				if on then a[#a + 1] = k end
			end
			return a
		end
		return v
	end

	local function Apply(obj, val)
		local t = obj.Type
		if t == "ColorPicker" then
			obj:Set(Color3.new(val[1], val[2], val[3]))
		elseif t == "Keybind" then
			obj:Set(Enum.KeyCode[val] or Enum.KeyCode.Unknown)
		else
			obj:Set(val)
		end
	end

	function W:GetConfigData()
		local d = {}
		for flag, obj in pairs(W.FlagObjs) do d[flag] = Serialize(obj) end
		return d
	end

	function W:LoadConfigData(d)
		for flag, val in pairs(d or {}) do
			local obj = W.FlagObjs[flag]
			if obj then pcall(Apply, obj, val) end
		end
	end

	function W:ListConfigs()
		local names = {}
		if HAS_FS then
			pcall(function()
				if not isfolder(CFGDIR) then return end
				for _, p in ipairs(listfiles(CFGDIR)) do
					local n = tostring(p):match("([^/\\]+)%.json$")
					if n then names[#names + 1] = n end
				end
			end)
		else
			for n in pairs(W.MemCfg) do names[#names + 1] = n end
		end
		table.sort(names)
		return names
	end

	function W:SaveConfig(name)
		name = (name or ""):gsub("[^%w _%-]", "")
		if name == "" then return false end
		local json = HttpService:JSONEncode(W:GetConfigData())
		if HAS_FS then
			pcall(function()
				if not isfolder(FOLDER) then makefolder(FOLDER) end
				if not isfolder(CFGDIR) then makefolder(CFGDIR) end
				writefile(CFGDIR .. "/" .. name .. ".json", json)
			end)
		else
			W.MemCfg[name] = json
		end
		W.CurrentConfig = name
		return true
	end

	function W:LoadConfig(name)
		local json
		if HAS_FS then
			pcall(function() json = readfile(CFGDIR .. "/" .. name .. ".json") end)
		else
			json = W.MemCfg[name]
		end
		if not json then return false end
		local ok, d = pcall(function() return HttpService:JSONDecode(json) end)
		if not ok then return false end
		W:LoadConfigData(d)
		W.CurrentConfig = name
		return true
	end

	function W:DeleteConfig(name)
		if HAS_FS then
			pcall(function() delfile(CFGDIR .. "/" .. name .. ".json") end)
		else
			W.MemCfg[name] = nil
		end
	end

	local saved = {}
	if HAS_FS and cfg.RememberSettings then
		pcall(function()
			if isfile(SETFILE) then saved = HttpService:JSONDecode(readfile(SETFILE)) end
		end)
	end

	local function SaveSettings()
		if not (HAS_FS and cfg.RememberSettings) then return end
		pcall(function()
			if not isfolder(FOLDER) then makefolder(FOLDER) end
			writefile(SETFILE, HttpService:JSONEncode({
				Scale = W.UserScale, Trans = W.Trans, Float = W.NeonBtn.Visible, Logo = W.LogoSource,
				Accent = { W.Accent.R, W.Accent.G, W.Accent.B }, Neon = { W.Neon.R, W.Neon.G, W.Neon.B },
			}))
		end)
	end

	if saved.Scale then
		W:SetScale(saved.Scale)
		RenderSize()
	end

	function W:StatsHud()
		if W.Hud then return W.Hud end
		local StatsService = Service("Stats")
		local hud = {}
		local HW, HH = MOBILE and 250 or 300, MOBILE and 56 or 66
		local frame = New("Frame", {
			Name = "StatsHud", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(HW, HH), BackgroundTransparency = 1, ZIndex = 40, Parent = gui,
		})
		hud.Root = frame
		local left = New("Frame", {
			Size = UDim2.new(0.58, -4, 1, 0), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 40, Parent = frame,
		}, { Corner(16), Stroke(T.Line, 1.2, 0.2) })
		local right = New("Frame", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.42, -4, 1, 0), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.2, BorderSizePixel = 0,
			ZIndex = 40, Parent = frame,
		}, { Corner(16), Stroke(T.Line, 1.2, 0.2) })
		local green = Color3.fromRGB(120, 255, 160)
		New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(40, 22), Font = Enum.Font.Code, Text = "FPS", TextSize = 15, TextColor3 = green,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41, Parent = left,
		})
		local fpsLbl = New("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 2), Size = UDim2.fromOffset(70, 24), Font = Enum.Font.Code, Text = "0", TextSize = 21,
			TextColor3 = green, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 41, Parent = left,
		})
		local graph = New("Frame", {
			Position = UDim2.new(0, 10, 1, -(HH * 0.4 + 6)), Size = UDim2.new(1, -20, 0, HH * 0.4), BackgroundTransparency = 1, ZIndex = 41, Parent = left,
		}, { New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder,
		}) })
		local bars, history, COUNT = {}, {}, 40
		for i = 1, COUNT do
			history[i] = 0
			bars[i] = New("Frame", { Size = UDim2.fromOffset(2, 2), BackgroundColor3 = green, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 41, Parent = graph })
		end
		local function Line(y, label)
			local l = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -16, 0, 16), Font = Enum.Font.Code, Text = label, TextSize = 12, TextColor3 = T.Dim,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41, Parent = right,
			})
			return l
		end
		local pad = (HH - 48) / 2
		local pingLbl = Line(pad, "Ping 0 ms")
		local memLbl = Line(pad + 16, "Mem 0 MB")
		local plrLbl = Line(pad + 32, "Plr 0")
		local frames, last = 0, os.clock()
		table.insert(W.Conns, RunService.RenderStepped:Connect(function()
			frames = frames + 1
			local now = os.clock()
			if now - last >= 0.25 then
				local fps = math.floor(frames / (now - last) + 0.5)
				frames, last = 0, now
				fpsLbl.Text = tostring(fps)
				table.remove(history, 1)
				table.insert(history, fps)
				local gh = HH * 0.4
				for i = 1, COUNT do
					bars[i].Size = UDim2.fromOffset(2, math.max(2, math.floor(gh * math.clamp(history[i] / 144, 0, 1))))
				end
				local okp, ping = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
				pingLbl.Text = "Ping " .. (okp and math.floor(ping) or 0) .. " ms"
				local okm, mem = pcall(function() return StatsService:GetTotalMemoryUsageMb() end)
				memLbl.Text = "Mem " .. (okm and math.floor(mem) or 0) .. " MB"
				plrLbl.Text = "Plr " .. #Players:GetPlayers()
			end
		end))
		function hud:SetVisible(v) frame.Visible = v end
		W.Hud = hud
		return hud
	end

	local st = MakeTab({ Name = "Settings" }, true)
	local appearance = st:AddSection({ Name = "Appearance", Icon = "eye", Position = "left" })
	appearance:AddSlider({
		Name = "Transparency", Min = 0, Max = 80, Increment = 5, Suffix = "%", Default = (saved.Trans or 0) * 100, Icon = "eye",
		Callback = function(v)
			W:SetTransparency(v / 100)
			SaveSettings()
		end,
	})
	appearance:AddColorPicker({
		Name = "Accent color", Icon = "gear",
		Default = saved.Accent and Color3.new(saved.Accent[1], saved.Accent[2], saved.Accent[3]) or W.Accent,
		Callback = function(c)
			W:SetAccent(c)
			SaveSettings()
		end,
	})
	appearance:AddColorPicker({
		Name = "Neon color", Icon = "bolt",
		Default = saved.Neon and Color3.new(saved.Neon[1], saved.Neon[2], saved.Neon[3]) or W.Neon,
		Callback = function(c)
			W:SetNeon(c)
			SaveSettings()
		end,
	})
	local LOCK_NAME = (cfg.LockName or cfg.LockBranding) and true or false
	local LOCK_LOGO = (cfg.LockLogo or cfg.LockBranding) and true or false
	local branding = st:AddSection({ Name = "Branding", Icon = "palette", Position = "left" })
	branding:AddLabel("Publisher: UnflyTm (locked)")
	if LOCK_NAME then
		branding:AddLabel("UI name: locked by the script author")
	else
		branding:AddTextBox({
			Name = "UI name", Icon = "code", Default = NAME, Placeholder = "name",
			Callback = function(v) W:SetName(v) end,
		})
	end
	local initLogo = saved.Logo
	if initLogo == nil or LOCK_LOGO then initLogo = cfg.Logo end
	if LOCK_LOGO then
		branding:AddLabel("Logo: locked by the script author")
	else
		local logoBox = branding:AddTextBox({
			Name = "Logo image", Icon = "image", Default = initLogo or "", Placeholder = "URL or asset id (empty = default)",
			Callback = function(v)
				task.spawn(function()
					if W:SetLogo(v) then
						SaveSettings()
					else
						Library:Notify({ Title = "Logo", Content = "Could not load the image. Use a direct image URL or an asset id.", Duration = 4 })
					end
				end)
			end,
		})
		branding:AddButton({
			Name = "Reset logo", Icon = "trash", ButtonText = "Reset",
			Callback = function()
				W:SetLogo("")
				logoBox:Set("", true)
				SaveSettings()
			end,
		})
	end
	local controls = st:AddSection({ Name = "Controls", Icon = "target", Position = "right" })
	controls:AddToggle({
		Name = "Floating button", Icon = "dots", Default = saved.Float ~= false,
		Callback = function(v)
			W:SetFloatButton(v)
			SaveSettings()
		end,
	})
	controls:AddToggle({
		Name = "Stats HUD", Default = cfg.Hud ~= false,
		Callback = function(v) W:StatsHud():SetVisible(v) end,
	})
	controls:AddKeybind({
		Name = "Toggle key", Icon = "lock", Default = W.ToggleKey,
		Changed = function(k)
			if k ~= Enum.KeyCode.Unknown then W.ToggleKey = k end
		end,
	})
	controls:AddButton({ Name = "Reset position", Icon = "pin", ButtonText = "Reset", Callback = function() root.Position = UDim2.fromScale(0.5, 0.5) end })
	controls:AddButton({ Name = "Unload interface", Icon = "cross", ButtonText = "Unload", Callback = function() W:Destroy() end })
	local configs = st:AddSection({ Name = "Configs", Icon = "shield", Position = "right" })
	local cfgNameBox = configs:AddTextBox({ Name = "Config name", Icon = "person", Placeholder = "name" })
	configs:AddButton({
		Name = "Save config", Icon = "check", ButtonText = "Save",
		Callback = function()
			if W:SaveConfig(cfgNameBox:Get()) then
				Library:Notify({ Title = "Config", Content = "Saved: " .. W.CurrentConfig, Duration = 2.5 })
			end
		end,
	})
	configs:AddDropdown({
		Name = "Load config", Icon = "expand", Options = {},
		OnOpen = function(dd) dd:SetOptions(W:ListConfigs()) end,
		Callback = function(name)
			if W:LoadConfig(name) then Library:Notify({ Title = "Config", Content = "Loaded: " .. name, Duration = 2.5 }) end
		end,
	})

	local function Community()
		if not W.CommunitySection then
			W.CommunitySection = st:AddSection({ Name = "Community", Icon = "users", Position = "right" })
		end
		return W.CommunitySection
	end

	function W:AddLink(lcfg)
		local o = Community():AddLink(lcfg)
		if lcfg and lcfg.Name then W.LinkObjs[lcfg.Name] = o end
		return o
	end

	function W:SetLink(name, url)
		local o = W.LinkObjs[name]
		if not o then return false end
		o:SetUrl(url)
		return true
	end

	local linkList = {}
	local function pushLink(name, url, icon, force)
		url = type(url) == "string" and url or ""
		if url ~= "" or force then
			table.insert(linkList, { Name = name, Url = url, Icon = icon })
		end
	end
	local showDefault = cfg.Community ~= false
	pushLink("Discord", cfg.Discord, "discord", showDefault)
	pushLink("Telegram", cfg.Telegram, "telegram", showDefault)
	if type(cfg.Links) == "table" then
		for _, entry in ipairs(cfg.Links) do
			if type(entry) == "table" then pushLink(entry.Name or "Link", entry.Url, entry.Icon or "link") end
		end
		local names = {}
		for k, v in pairs(cfg.Links) do
			if type(k) == "string" and type(v) == "string" then table.insert(names, k) end
		end
		table.sort(names)
		for _, k in ipairs(names) do
			local lk = string.lower(k)
			local icon = "link"
			if lk == "discord" then
				icon = "discord"
			elseif lk == "telegram" or lk == "tg" then
				icon = "telegram"
			end
			pushLink(k, cfg.Links[k], icon)
		end
	end
	for _, l in ipairs(linkList) do W:AddLink(l) end

	Tap(card, function()
		if W.CurrentTab == st then
			(W.MainTabs[1] or st):Select()
		else
			st:Select()
		end
	end)

	if saved.Float == false then nb.Visible = false end

	task.spawn(function()
		if not W:SetLogo(initLogo or "") then W:SetLogo("") end
	end)

	function W:AddIconBrowser(title)
		local tab = W:Tab(title or "Icons", "image")
		local sec = tab:Section("Icon browser", "left", "search")
		local PER = 15
		local state = { list = Library:FindIcon(""), page = 1 }
		local info = sec:AddLabel("")
		local grid
		local function render()
			for _, c in ipairs(grid:GetChildren()) do
				if c:IsA("TextButton") then c:Destroy() end
			end
			local total = #state.list
			local pages = math.max(1, math.ceil(total / PER))
			state.page = math.clamp(state.page, 1, pages)
			info:Set(total .. " icons, page " .. state.page .. " of " .. pages .. ". Tap an icon to copy its name.")
			for i = (state.page - 1) * PER + 1, math.min(total, state.page * PER) do
				local name = state.list[i]
				local cell = New("TextButton", {
					BackgroundColor3 = T.Field, AutoButtonColor = false, Text = "", LayoutOrder = i, Parent = grid,
				}, { Corner(8), Stroke(T.Line, 1, 0.4) })
				local ic = Icon(name, cell, T.Text, 22)
				ic.AnchorPoint = Vector2.new(0.5, 0)
				ic.Position = UDim2.new(0.5, 0, 0, 8)
				New("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 34), Size = UDim2.new(1, -4, 0, 24), Font = Enum.Font.Gotham, Text = name,
					TextSize = 9, TextColor3 = T.Dim, TextWrapped = true, Parent = cell,
				})
				Tap(cell, function()
					if Library:Copy(name) then
						Library:Notify({ Title = "Icon", Content = "Copied: " .. name, Duration = 1.8 })
					else
						Library:Notify({ Title = "Icon", Content = name, Duration = 3 })
					end
				end)
			end
		end
		sec:AddTextBox({
			Name = "Search", Placeholder = "heart, trophy, arrow...",
			Callback = function(text)
				state.list = Library:FindIcon(text)
				state.page = 1
				render()
			end,
		})
		sec:AddButton({
			Name = "Previous page", ButtonText = "Prev",
			Callback = function()
				state.page = state.page - 1
				render()
			end,
		})
		sec:AddButton({
			Name = "Next page", ButtonText = "Next",
			Callback = function()
				state.page = state.page + 1
				render()
			end,
		})
		grid = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1000, Parent = sec.Container,
		}, { New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 62), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }), Pad(6, 6, 6, 6) })
		render()
		return tab
	end

	function W:AutoFlag(name)
		local base = (tostring(name or "item"):lower():gsub("[^%w]+", "_"))
		if base == "" then base = "item" end
		local flag, n = base, 1
		while W.FlagObjs[flag] do
			n = n + 1
			flag = base .. "_" .. n
		end
		return flag
	end

	function W:OnUnload(fn) table.insert(W.UnloadFns, fn) end

	function W:Ready()
		if W.IsReady then return end
		W.IsReady = true
		if cfg.AutoLoad and cfg.AutoLoad ~= "" then W:LoadConfig(cfg.AutoLoad) end
	end

	function W:Build(schema)
		local made = {}
		local kinds = {
			toggle = "AddToggle", slider = "AddSlider", dropdown = "AddDropdown", color = "AddColorPicker", colorpicker = "AddColorPicker",
			input = "AddTextBox", textbox = "AddTextBox", key = "AddKeybind", keybind = "AddKeybind", button = "AddButton",
		}
		for _, t in ipairs(schema or {}) do
			local tab = W:Tab(t.Tab or t.Name, t.Icon)
			if t.Banner then tab:AddBanner(type(t.Banner) == "table" and t.Banner or {}) end
			for _, sec in ipairs(t.Sections or {}) do
				local section = tab:Section(sec.Name, sec.Position, sec.Icon)
				for _, item in ipairs(sec.Items or {}) do
					local kind = string.lower(tostring(item.Type or "label"))
					if kind == "label" then
						section:AddLabel(item.Text or item.Name or "")
					elseif kinds[kind] then
						if kind ~= "button" and not item.Flag then item.Flag = W:AutoFlag(item.Name) end
						made[item.Flag or item.Name] = section[kinds[kind]](section, item)
					end
				end
			end
		end
		W:Ready()
		return made
	end

	function W:Destroy()
		for _, fn in ipairs(W.UnloadFns) do pcall(fn) end
		for _, c in pairs(W.Loops) do pcall(function() c:Disconnect() end) end
		for _, c in ipairs(W.Conns) do pcall(function() c:Disconnect() end) end
		pcall(function() ContextActionService:UnbindAction(SHIELD_NAME) end)
		gui:Destroy()
		if Library.Active == W then Library.Active = nil end
		if env.UnflyUiWindow == W then env.UnflyUiWindow = nil end
	end

	env.UnflyUiWindow = W

	function W:Notify(c) Library:Notify(c) end

	return W
end

return Library
