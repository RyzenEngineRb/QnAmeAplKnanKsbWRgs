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
local DEFAULT_LOGO = "https://raw.githubusercontent.com/RyzenEngineRb/kMjanwixHa/refs/heads/main/file_0000000081f081f48529c8200775be33.png"

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

local ICON_NAMES = [[
3d-cube-arrow-left amazon arm-left arm-right arrow-curl-to-left arrow-curl-to-right arrow-down-to-line arrow-
large-down arrow-large-left arrow-large-right arrow-large-up arrow-right-from-portrait-rectangle arrow-right-
to-portrait-rectangle arrow-rotate-down-dashed arrow-rotate-right arrow-rotate-right-dashed arrow-small-down
arrow-small-left arrow-small-right arrow-small-up arrow-spin-clockwise arrow-spin-clockwise-10 arrow-spin-
clockwise-15 arrow-spin-clockwise-30 arrow-spin-counter-clockwise-10 arrow-spin-counter-clockwise-15 arrow-
spin-counter-clockwise-30 arrow-thick-to-left arrow-thick-to-right arrow-up-from-landscape-rectangle arrow-up-
right-from-square arrow-wide-short-down arrow-wide-short-left arrow-wide-short-right arrow-wide-short-up
arrows-small-directional audio-wave-dotted-line backpack beard bell bell-clock bell-plus bell-slash belt
binoculars book-closed bookmark bow-tie building-store bullet-flying butterfly-wings calendar calendar-plus
calendar-star camera-small caret-small-down caret-small-left caret-small-right caret-small-up chain-link
chart-four-vertical-bars chart-line chart-pie chart-scatter-plot chart-three-vertical-bars check check-large
check-small chevron-large-down chevron-large-down-to-line chevron-large-left chevron-large-left-to-line
chevron-large-right chevron-large-right-to-line chevron-large-up chevron-large-up-to-line chevron-small-down
chevron-small-down-to-line chevron-small-left chevron-small-left-to-line chevron-small-right chevron-small-
right-to-line chevron-small-up chevron-small-up-to-line circle-check circle-i circle-minus circle-person
circle-person-three-horizontal-bars-wrapping-right circle-play circle-plus circle-question circle-slash
circle-star circle-three-dots-horizontal circle-three-dots-vertical circle-x clock clock-dashed clock-spin-
reverse clock-spin-reverse-dashed clothes-hanger cloud cloud-arrow-down code compact-makeup-brush compass
controller-with-cog crop crosshairs crosshairs-slash cube-vertexes curved-rectangle-megaphone diagonal-line-
pattern diagonal-line-pattern-sticker diamond-simplified discord disguise-nose-glasses document-circle-slash
document-list-heart door-open-arrow-to-bottom-right dress dual-arrows-horizontal dual-arrows-to-corners dual-
arrows-vertical envelope eraser eye eye-slash eye-with-eyeliner eyebrows eyelashes face-winking facebook file-
box fingerprint flag flame folder fountain-pen-nib four-bars-horizontal-center-aligned four-bars-horizontal-
chevron-left four-bars-horizontal-chevron-right four-bars-horizontal-justified-aligned four-bars-horizontal-
left-aligned four-bars-horizontal-right-aligned frame-bubble-slash frame-bubble-soundwave frame-camera frame-
camera-center frame-collapsed frame-corners frame-expanded frame-face frame-person-torso frame-record frame-
single-bar-horizontal frame-soundwave frame-video-camera gear generic-dpad gift-box gift-card glasses globe-
detailed globe-simplified globe-simplipfied-speech-bubble grid guilded hack-week hammer-code hand-curved-
arrow-left hand-dual-arrows hand-ellipse hand-half-ellipse hand-two-arrows-horizontal hashtag hat-fedora hat-
toque head-blank head-blush head-female head-freckles head-lips head-male headphones headphones-arrow-up
headphones-arrow-up-lock headphones-slash headphones-x headphones-x-lock heart house image image-stacked
instagram jacket key key-alt key-apostrophe key-arrow-down key-arrow-right key-arrow-up key-asterisk key-
backspace key-caps-lock key-caret key-comma key-command key-control key-grave-accent key-period key-return
key-shift key-space key-tab language-characters leg-left leg-right lightning-bolt linkedin lips lipstick list-
bulleted location-pin location-pin-map lock-closed lollipop magnifying-glass magnifying-glass-minus
magnifying-glass-plus mascara megaphone memory-card messenger microphone microphone-slash microphone-text-box
microphone-triangle-exclamation minus minus-small mirror-standing moments moon mouse-button-left mouse-button-
right mouse-scrollwheel music-note nebula necklace nine-dots-grid ninja nose page paint-brush paint-bucket
pants pants-2d-text paper-airplane parrot pause-large pause-small pencil pencil-square person person-arrow-
from-bottom-right person-check person-circle-slash person-climbing person-clock person-falling person-graduate
person-jumping person-magnifying-glass person-photo-camera person-play person-play-clock person-plus person-
racing person-running person-standing person-standing-arrow-reverse person-standing-dual-arrows-vertical
person-standing-gear person-swimming person-teleport person-trash-can person-walking person-with-smaller-
person phone phone-down phone-plus phone-volume phone-x photo-camera photo-camera-face photo-camera-slash
picture-in-picture pig pin pin-slash play-large play-small plus-large plus-small premium ps-circle ps-dpad-
down ps-dpad-left ps-dpad-right ps-dpad-up ps-l1 ps-l2 ps-l3 ps-r1 ps-r2 ps-r3 ps-square ps-stick-left ps-
stick-right ps-triagle ps-x ps4-options ps4-share ps4-touchpad ps5-options ps5-share ps5-touchpad pumpkin
purse rectangle-list rectangle-numbers-counting rectangle-person-with-three-horizontal-lines robux rosette-
seven-point rosette-ten-point seven-point-rosette shield-check shield-lock shirt shirt-2d-text shirt-pants
shoe-left shoe-right shopping-basket shopping-basket-check shopping-cart shorts sidebar signal-exclamation
six-dots-two-column-grid skip-end-large skip-end-small skip-next-large skip-next-small skip-previous-large
skip-previous-small skip-start-large skip-start-small smartphone-portrait speaker speaker-slash speaker-
triangle-exclamation speaker-x speech-bubble-align-center speech-bubble-align-left speech-bubble-exclamation
speech-bubble-round square-bone square-books square-check square-code square-dashed-person-standing square-
dual-arrows-horizontal square-dual-arrows-to-corner square-face-sound square-face-waving-hand square-face-
winking square-minus square-person squares-grid-plus squares-grid-qr stacked-squares-arrow-down-left stacked-
squares-arrow-up-right stacked-squares-plus star stop-large stop-small studio sun sweater sword tag-sparkle
teletype tencent-qq text-b-bold text-box-microphone text-h-subscript-1 text-h-subscript-2 text-h-subscript-3
text-i-italic text-s-strikethrough text-u-underline text-uppercase-a-lowercase-a text-x-subscript-2 text-x-
superscript-2 three-bars-horizontal three-bars-horizontal-chevron-left three-bars-horizontal-narrowing three-
bars-horizontal-triangles-vertical three-bars-vertical-triangles-horizontal three-chevrons-enlarging-down
three-chevrons-enlarging-up three-dots-horizontal three-dots-vertical three-horizontal-bars-wrapping-right
three-people three-ring-note three-sliders-horizontal three-stacked-squares-tilted thumb-down thumb-up tik-tok
tilt torso trash-can triangle-exclamation trophy tshirt tshirt-2d-text tshirt-dual-arrows twitch twitter two-
arrows-down-and-up two-arrows-from-center two-arrows-left-right two-arrows-loop-clockwise two-arrows-loop-
clockwise-1 two-arrows-loop-clockwise-infinity two-arrows-spin-clockwise two-arrows-spin-clockwise-plus two-
arrows-switch-right two-arrows-to-center two-folders two-location-pins-connecting-arrow two-makeup-brushes
two-people two-people-speech-bubble two-stacked-squares two-switches-horizontal verified-backplate verified-
check verified-mono video-camera video-camera-arrow-to-bottom-left video-camera-arrow-to-top-right video-
camera-slash video-camera-triangle-exclamation video-camera-x wallet we-chat whatsapp x x-small xbox-a xbox-a-
pressed xbox-a-unpressed xbox-b xbox-dpad xbox-dpad-down xbox-dpad-left xbox-dpad-right xbox-dpad-up xbox-lb
xbox-lt xbox-menu xbox-rb xbox-rt xbox-stick-left xbox-stick-left-directional xbox-stick-left-horizontal xbox-
stick-left-vertical xbox-stick-right xbox-stick-right-directional xbox-stick-right-horizontal xbox-stick-
right-vertical xbox-view xbox-x xbox-y xr-headset youtube
]]
local ICON_SET, ICON_LIST = {}, {}
for n in ICON_NAMES:gmatch("%S+") do
	ICON_SET[n] = true
	table.insert(ICON_LIST, n)
end
table.sort(ICON_LIST)

local ICON_ALIAS = {
	add = "plus-large",
	aim = "crosshairs",
	announce = "megaphone",
	avatar = "head-male",
	award = "trophy",
	bolt = "lightning-bolt",
	book = "book-closed",
	brush = "paint-brush",
	camera = "photo-camera",
	cart = "shopping-cart",
	chart = "chart-line",
	chat = "speech-bubble-round",
	climb = "person-climbing",
	close = "x",
	clothes = "shirt",
	cog = "gear",
	combat = "sword",
	config = "three-sliders-horizontal",
	cross = "x",
	crown = "premium",
	currency = "robux",
	dark = "moon",
	day = "sun",
	delete = "trash-can",
	diamond = "diamond-simplified",
	dislike = "thumb-down",
	dots = "three-dots-horizontal",
	download = "cloud-arrow-down",
	edit = "pencil",
	error = "circle-x",
	esp = "eye",
	face = "head-male",
	fight = "sword",
	file = "page",
	filter = "three-sliders-horizontal",
	fire = "flame",
	friends = "three-people",
	game = "controller-with-cog",
	gamepad = "controller-with-cog",
	gift = "gift-box",
	globe = "globe-detailed",
	halloween = "pumpkin",
	help = "circle-question",
	home = "house",
	id = "fingerprint",
	info = "circle-i",
	inventory = "backpack",
	items = "backpack",
	jump = "person-jumping",
	light = "sun",
	lightning = "lightning-bolt",
	like = "thumb-up",
	link = "chain-link",
	list = "list-bulleted",
	lock = "lock-closed",
	map = "location-pin-map",
	menu = "three-bars-horizontal",
	message = "speech-bubble-align-left",
	mic = "microphone",
	misc = "nine-dots-grid",
	mobile = "smartphone-portrait",
	money = "robux",
	music = "music-note",
	news = "megaphone",
	night = "moon",
	notification = "bell",
	ok = "circle-check",
	outfit = "shirt-pants",
	palette = "paint-brush",
	photo = "image",
	player = "person",
	players = "two-people",
	plus = "plus-large",
	refresh = "arrow-rotate-right",
	reload = "arrow-rotate-right",
	run = "person-running",
	save = "memory-card",
	script = "code",
	search = "magnifying-glass",
	settings = "gear",
	shield = "shield-check",
	shop = "building-store",
	sliders = "three-sliders-horizontal",
	sound = "speaker",
	stats = "chart-four-vertical-bars",
	store = "building-store",
	swim = "person-swimming",
	target = "crosshairs",
	teleport = "person-teleport",
	tick = "check",
	time = "clock",
	tool = "hammer-code",
	tools = "hammer-code",
	tp = "person-teleport",
	trash = "trash-can",
	user = "person",
	users = "two-people",
	video = "video-camera",
	vip = "premium",
	visual = "eye",
	visuals = "eye",
	volume = "speaker",
	walk = "person-walking",
	warning = "triangle-exclamation",
	weapon = "sword",
}

local BUILDER_ICONS = "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json"
local ICON_FONT_REG = Font.new(BUILDER_ICONS, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local ICON_FONT_BOLD = Font.new(BUILDER_ICONS, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local iconLabels = {}

local function IconKind(id)
	if id == nil or id == false or id == "" then return nil end
	local img = ResolveImage(id, "icon", false)
	if img then return "image", img end
	if type(id) == "string" then
		local name = id:lower()
		local bold = false
		if name:sub(-5) == "-bold" then
			bold = true
			name = name:sub(1, -6)
		end
		name = ICON_ALIAS[name] or name
		if ICON_SET[name] then return "font", name, bold end
	end
	return nil
end

local function FixIcon(l)
	l.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	l.Text = tostring(l:GetAttribute("n") or "?"):sub(1, 1):upper()
	l.TextSize = math.max(8, math.floor(l.TextSize * 0.8))
end

local function Icon(parent, id, size, color, pos)
	local kind, a, bold = IconKind(id)
	if not kind then return nil end
	if kind == "image" then
		return New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = a,
			ImageColor3 = color or THEME.Sub,
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = pos or UDim2.new(0, 0, 0.5, 0),
			Parent = parent,
		})
	end
	local l = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = pos or UDim2.new(0, 0, 0.5, 0),
		FontFace = bold and ICON_FONT_BOLD or ICON_FONT_REG,
		Text = a,
		TextSize = size,
		TextColor3 = color or THEME.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
	l:SetAttribute("n", a)
	table.insert(iconLabels, l)
	if Library.IconFontOk == false then FixIcon(l) end
	return l
end

local function IconColor(obj, c)
	if not obj then return end
	if obj:IsA("ImageLabel") then
		Tween(obj, { ImageColor3 = c }, 0.15)
	else
		Tween(obj, { TextColor3 = c }, 0.15)
	end
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

local gearsSpin = {}

local function DrawGear(parent, size, color, pos, speed)
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	if speed then table.insert(gearsSpin, { h = holder, speed = speed }) end
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

local function BuildLogo(holder, size, image, color, zoom)
	for _, c in ipairs(holder:GetChildren()) do
		c:Destroy()
	end
	if image then
		local cg = New("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = holder,
		}, { Corner(UDim.new(1, 0)) })
		New("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(zoom or 1.5, zoom or 1.5),
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Crop,
			Parent = cg,
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

Library.IconNames = ICON_LIST

function Library:HasIcon(name)
	return IconKind(name) ~= nil
end

function Library:FindIcons(query)
	query = tostring(query or ""):lower()
	local out = {}
	for _, n in ipairs(ICON_LIST) do
		if query == "" or n:find(query, 1, true) then table.insert(out, n) end
	end
	return out
end

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

local neons = {}
local NEON_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(196, 214, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})
local NEON_ALPHA = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.55),
	NumberSequenceKeypoint.new(1, 0),
})

local function NeonRing(parent, thickness)
	local ring = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = parent,
	}, { Corner(UDim.new(1, 0)) })
	local rs = Stroke(ring, Color3.new(1, 1, 1), 0, thickness or 2)
	local rg = New("UIGradient", { Color = NEON_COLORS, Transparency = NEON_ALPHA, Parent = rs })
	table.insert(neons, { g = rg, speed = 70 })
	return ring
end

local function NeonStroke(parent, thickness, transparency)
	local st = Stroke(parent, Color3.new(1, 1, 1), transparency or 0.2, thickness or 1)
	local g = New("UIGradient", { Color = NEON_COLORS, Transparency = NEON_ALPHA, Parent = st })
	table.insert(neons, { g = g, speed = 40 })
	return st
end

local ticks = {}

local function CreateWatermark(gui, W, yOffset, cfg)
	local bar = New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, yOffset),
		Size = UDim2.fromOffset(230, 38),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = gui,
	})
	Corner(bar, UDim.new(1, 0))
	NeonStroke(bar, 1, 0.15)

	local content = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 30),
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
		Size = UDim2.fromOffset(30, 30),
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
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(28, 28, 33),
			LayoutOrder = order,
			Parent = content,
		})
		Corner(c, UDim.new(1, 0))
		local l = New("TextLabel", {
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = color or THEME.Text,
			Text = "...",
			Parent = c,
		})
		New("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11), Parent = l })
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
		bar.Size = UDim2.fromOffset(content.AbsoluteSize.X + 16, 38)
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
		Stroke(r, Color3.new(1, 1, 1), 0.86, 1)
		return r
	end

	local function Lbl(parent, text, reserve, y, h, icon)
		local hasIcon = IconKind(icon) ~= nil
		local off = hasIcon and 24 or 0
		if hasIcon then
			Icon(parent, icon, 16, THEME.Sub, UDim2.new(0, PAD, 0, (y or 0) + (h or ROW_H) / 2))
		end
		local l = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD + off, y or 0),
			Size = UDim2.new(1, -(PAD + off + (reserve or 70)), 0, h or ROW_H),
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
		}, { Corner(UDim.new(0, 8)), Stroke(Color3.new(1, 1, 1), 0.82, 1) })
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

	function E:AddLabel(text, icon)
		local r = Row(30)
		local l = Lbl(r, text, PAD, nil, nil, icon)
		l.Size = UDim2.new(1, -(PAD * 2 + (IconKind(icon) and 24 or 0)), 0, 30)
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
		Lbl(r, cfg.Name, fieldW + 24, nil, nil, cfg.Icon)
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
		Lbl(r, cfg.Name, TW + 24, nil, nil, cfg.Icon)
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
		local KR = MOBILE and 12 or 10
		local h = ROW_H + 24
		local r = Row(h)
		local lbl = Lbl(r, cfg.Name, 90, 8, 18, cfg.Icon)
		lbl.Size = UDim2.new(1, -(PAD + 90 + (IconKind(cfg.Icon) and 24 or 0)), 0, 18)
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
			Position = UDim2.fromOffset(PAD, h - 38),
			Size = UDim2.new(1, -(PAD * 2), 0, 32),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = r,
		})
		local track = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, KR, 0.5, 0),
			Size = UDim2.new(1, -KR * 2, 0, 8),
			BackgroundColor3 = THEME.Off,
			BorderSizePixel = 0,
			Parent = hit,
		}, { Corner(UDim.new(1, 0)), Stroke(THEME.Line, 0.3) })
		local fill = New("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = track,
		}, { Corner(UDim.new(1, 0)) })
		local fillGrad = New("UIGradient", { Parent = fill })
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(KR * 2, KR * 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = track,
		}, { Corner(UDim.new(1, 0)) })
		local knobRing = Stroke(knob, W.Accent, 0.35, 3)
		local dot = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.4, 0.4),
			BackgroundColor3 = W.Accent,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = knob,
		}, { Corner(UDim.new(1, 0)) })
		W:BindAccent(function(c)
			fillGrad.Color = ColorSequence.new(c:Lerp(Color3.new(0, 0, 0), 0.3), c:Lerp(Color3.new(1, 1, 1), 0.2))
			val.TextColor3 = c
			knobRing.Color = c
			dot.BackgroundColor3 = c
		end)
		local obj = { Value = min, Type = "Slider" }
		local function snap(v)
			v = math.clamp(v, min, max)
			v = math.floor((v - min) / inc + 0.5) * inc + min
			return tonumber(string.format("%." .. dec .. "f", math.clamp(v, min, max)))
		end
		local function render()
			local frac = (obj.Value - min) / math.max(max - min, 1e-9)
			fill.Size = UDim2.fromScale(frac, 1)
			knob.Position = UDim2.new(frac, 0, 0.5, 0)
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
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			obj:Set(min + (max - min) * rel)
		end
		local function stop()
			sliding = false
			Tween(knob, { Size = UDim2.fromOffset(KR * 2, KR * 2) }, 0.12)
			if scrollRef then
				scrollRef.ScrollingEnabled = true
				scrollRef = nil
			end
		end
		hit.InputBegan:Connect(function(i)
			if IsPointer(i) then
				sliding = true
				Tween(knob, { Size = UDim2.fromOffset(KR * 2 + 6, KR * 2 + 6) }, 0.12)
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
		Lbl(r, cfg.Name, fieldW + 24, nil, nil, cfg.Icon)
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
		Lbl(r, cfg.Name, fieldW + 24, nil, nil, cfg.Icon)
		local f = Field(r, fieldW)
		f.AnchorPoint = Vector2.new(1, 0.5)
		f.Position = UDim2.new(1, -10, 0, ROW_H / 2)
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
	table.clear(neons)
	table.clear(iconLabels)
	Library.IconFontOk = nil
	table.clear(gearsSpin)

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
	W._logoZoom = cfg.LogoZoom or 1.5

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

	task.spawn(function()
		local probe = New("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			Position = UDim2.fromOffset(-600, -600),
			FontFace = ICON_FONT_REG,
			Text = "house",
			TextSize = 20,
			Parent = gui,
		})
		task.wait(0.25)
		local w = probe.TextBounds.X
		probe:Destroy()
		Library.IconFontOk = w > 0 and w < 34
		if not Library.IconFontOk then
			for _, l in ipairs(iconLabels) do
				if l.Parent then FixIcon(l) end
			end
		end
	end)

	Library.Active = W

	local conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for i = #gearsSpin, 1, -1 do
			local g = gearsSpin[i]
			if g.h.Parent then
				g.h.Rotation = (t * g.speed * (W._gearMul or 1)) % 360
			else
				table.remove(gearsSpin, i)
			end
		end
		for i = #neons, 1, -1 do
			local n = neons[i]
			if n.g.Parent then
				n.g.Rotation = (t * n.speed) % 360
				if n.glow then n.glow.Transparency = 0.62 + 0.12 * math.sin(t * 2.2) end
			else
				table.remove(neons, i)
			end
		end
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
	NeonStroke(main, 1.5, 0.1)
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

	local HEAD_H = MOBILE and 62 or 58
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
	local logoWrap = New("Frame", {
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		BorderSizePixel = 0,
		LayoutOrder = 0,
		Parent = titleBox,
	}, { Corner(UDim.new(1, 0)) })
	NeonRing(logoWrap, 2)
	local logoHolder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(42, 42),
		BackgroundTransparency = 1,
		Parent = logoWrap,
	})
	New("TextLabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
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

	local pulseBars = {}
	local function PulseCluster(anchorX, posX)
		local f = New("Frame", {
			AnchorPoint = Vector2.new(anchorX, 1),
			Position = UDim2.new(anchorX, posX, 1, -8),
			Size = UDim2.fromOffset(21, ROW_H),
			BackgroundTransparency = 1,
			Parent = side,
		})
		for i = 1, 4 do
			local b = New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, (i - 1) * 6, 0.5, 0),
				Size = UDim2.fromOffset(3, 6),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				Parent = f,
			}, { Corner(UDim.new(1, 0)) })
			table.insert(pulseBars, { bar = b, phase = i * 0.9 + anchorX * 2.3 })
		end
		return f
	end
	local pulseL = PulseCluster(0, 12)
	local pulseR = PulseCluster(1, -12)

	local gearBtn = New("TextButton", {
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(ROW_H + 22, ROW_H),
		BackgroundColor3 = THEME.Select,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = side,
	})
	Corner(gearBtn, UDim.new(0, 10))
	DrawGear(gearBtn, MOBILE and 24 or 22, Color3.new(1, 1, 1), UDim2.fromScale(0.4, 0.58), 40)
	DrawGear(gearBtn, MOBILE and 16 or 14, Color3.new(1, 1, 1), UDim2.fromScale(0.74, 0.3), -62)
	local gear = { SetColor = function() end }
	gearBtn.MouseEnter:Connect(function()
		W._gearMul = 3
		if W._current ~= W._settings then Tween(gearBtn, { BackgroundTransparency = 0.5 }) end
	end)
	gearBtn.MouseLeave:Connect(function()
		W._gearMul = (W._current == W._settings) and 2 or 1
		if W._current ~= W._settings then Tween(gearBtn, { BackgroundTransparency = 1 }) end
	end)

	table.insert(ticks, function()
		local t = os.clock()
		local maxH = ROW_H - 14
		for _, pb in ipairs(pulseBars) do
			local k = 0.5 + 0.5 * math.sin(t * 3.2 + pb.phase)
			local env = 0.55 + 0.45 * math.sin(t * 1.1 + pb.phase * 0.5)
			pb.bar.Size = UDim2.fromOffset(3, 4 + (maxH - 4) * k * env)
		end
	 end)

	local pagesHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(150 + PAD, 0),
		Size = UDim2.new(1, -(150 + PAD * 2), 1, 0),
		ClipsDescendants = true,
		Parent = body,
	})

	local function SetLogoImage()
		BuildLogo(logoHolder, 32, W._logoImg, W.Accent, W._logoZoom)
		if W._toggleLogo then BuildLogo(W._toggleLogo, MOBILE and 34 or 28, W._logoImg, W.Accent, W._logoZoom) end
	end

	function W:SetLogoZoom(z)
		W._logoZoom = math.clamp(z, 1, 3)
		SetLogoImage()
	end
	W:BindAccent(function()
		if not W._logoImg then SetLogoImage() end
	end)

	function W:SetLogo(src, silent)
		if src == nil or src == "" then
			W._logoSrc, W._logoImg = nil, nil
			SetLogoImage()
			return true
		end
		local res = ResolveImage(src, "logo", true)
		if not res then
			if not silent then
				W:Notify({ Title = "Logo", Content = "Не удалось загрузить картинку. Укажите id, прямую ссылку или путь к файлу.", Duration = 4 })
			end
			return false
		end
		W._logoSrc, W._logoImg = src, res
		SetLogoImage()
		return true
	end

	function W:SetBackground(src)
		if src == nil or src == "" then
			bgImage.Image = ""
			bgImage.Visible = false
			return true
		end
		local res = ResolveImage(src, "bg", true)
		if not res then
			W:Notify({ Title = "Background", Content = "Не удалось загрузить картинку. Укажите id, прямую ссылку или путь к файлу.", Duration = 4 })
			return false
		end
		bgImage.Image = res
		bgImage.Visible = true
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
		pulseL.Visible = not rail
		pulseR.Visible = not rail
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
			top.Size = UDim2.new(1, 0, 0, 58)
			Tween(main, { Size = UDim2.fromOffset(210, 58) }, 0.2)
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
		local tsize = MOBILE and 52 or 44
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
		NeonRing(toggle, 1.5)
		W._toggleLogo = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(MOBILE and 46 or 38, MOBILE and 46 or 38),
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
				IconColor(p.IconImg, THEME.Sub)
			end
		end
		W._current = page
		page.Frame.Visible = true
		if page.Button then
			page.Indicator.Visible = true
			Tween(page.Button, { BackgroundTransparency = 0 })
			Tween(page.Label, { TextColor3 = THEME.Text })
			IconColor(page.IconImg, THEME.Text)
			W._last = page
		end
		local isSettings = page == W._settings
		Tween(gearBtn, { BackgroundTransparency = isSettings and 0 or 1 })
		W._gearMul = isSettings and 2 or 1
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
		local page = { Name = name, Subs = {}, SubByName = {}, HasIcon = IconKind(iconId) ~= nil }

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
			page.IconImg = Icon(btn, iconId, 17, THEME.Sub, UDim2.new(0, 12, 0.5, 0))
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

			local hasIcon = IconKind(subIcon) ~= nil
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
			sub.IconObj = Icon(tbtn, subIcon, 16, THEME.Sub, UDim2.new(0, -22, 0.5, 0))
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
					IconColor(t.IconObj, THEME.Sub)
				end
				scroll.Visible = true
				underline.Visible = true
				Tween(tbtn, { TextColor3 = THEME.Text })
				IconColor(sub.IconObj, THEME.Text)
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
				NeonStroke(card, 1, 0.45)
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
				local hasI = IconKind(scfg.Icon) ~= nil
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
		if cfg.Background then
			display:AddSlider({
				Name = "Background Image", Min = 0, Max = 100, Default = math.floor(bgOpacity * 100 + 0.5), Suffix = "%",
				Callback = function(v)
					W:SetBackgroundOpacity(v / 100)
					Persist("bgOpacity", v / 100)
				end,
			})
		end
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

	local logoSrc
	if cfg.Logo ~= false then logoSrc = cfg.Logo or DEFAULT_LOGO end
	if logoSrc then task.spawn(function() W:SetLogo(logoSrc, true) end) end
	local bgSrc = cfg.Background
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
