--[[
  Nova UI — extracted from Pulse Hub (NovaFoundation stack)
  Standalone wrapper with environment shim so it runs outside Pulse sandbox.
  Usage:
    local Nova = loadstring(game:HttpGet(".../NovaUI.lua"))()
    local Window = Nova:CreateWindow({ Title = "Unfly", Subtitle = "Test", Key = Enum.KeyCode.RightShift })
]]

local function buildEnvironment()
	local env = {
		game = game,
		workspace = workspace,
		Instance = Instance,
		Color3 = Color3,
		UDim2 = UDim2,
		UDim = UDim,
		Vector2 = Vector2,
		Vector3 = Vector3,
		Enum = Enum,
		TweenInfo = TweenInfo,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		Rect = Rect,
		Font = Font,
		math = math,
		string = string,
		table = table,
		task = task,
		os = os,
		buffer = buffer,
		bit32 = bit32,
		pcall = pcall,
		xpcall = xpcall,
		typeof = typeof,
		type = type,
		tonumber = tonumber,
		tostring = tostring,
		ipairs = ipairs,
		pairs = pairs,
		next = next,
		select = select,
		unpack = unpack or table.unpack,
		warn = warn,
		print = print,
		error = error,
		getfenv = getfenv,
		setfenv = setfenv,
		rawget = rawget,
		rawset = rawset,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
	}

	env.getgenv = (getgenv and getgenv) or function() return _G end
	env.gethui = gethui
	env.protectgui = protectgui
	env.isfile = isfile
	env.isfolder = isfolder
	env.makefolder = makefolder
	env.writefile = writefile
	env.readfile = readfile
	env.appendfile = appendfile
	env.listfiles = listfiles
	env.delfile = delfile
	env.getcustomasset = getcustomasset
	env.syn = syn

	setmetatable(env, {
		__index = function(_, key)
			local ok, value = pcall(function()
				return getfenv and getfenv(0)[key] or _G[key]
			end)
			if ok then return value end
			return nil
		end,
	})

	return env
end

local environment = buildEnvironment()


local NovaUtility = {}

local TEXT_CLASSES = {TextLabel = true, TextButton = true, TextBox = true}

function NovaUtility.create(environment, windows, connections, services)
	local registries = {}
	local detached = {}
	local utility = {radiusMult = 1, textScale = 1}

	function utility.newReg()
		local registry = {}
		table.insert(registries, registry)
		return registry
	end

	function utility.sweep()
		local entries = {}

		for _, registry in registries do
			for object in registry do
				table.insert(entries, {object = object, registry = registry})
			end
		end

		local parents = {}
		local started = environment.os.clock()

		for _, entry in entries do
			local object, registry = entry.object, entry.registry

			if registry[object] ~= nil then
				NovaUtility._sweepEntry(environment, object, registry, parents, detached)
			end

			if environment.os.clock() - started > 0.001 then
				environment.task.wait()
				started = environment.os.clock()
				parents = {}
			end
		end
	end

	function utility.regCount()
		local count = 0

		for _, registry in registries do
			for _ in registry do
				count += 1
			end
		end

		return count
	end

	function utility.startSweep()
		if utility.sweeping then
			return
		end

		utility.sweeping = true
		environment.task.spawn(function()
			while true do
				environment.task.wait(15)
				local hasWindows = false

				for _, window in environment.ipairs(windows) do
					if not window.Destroyed then
						hasWindows = true
					end
				end

				utility.sweep()

				if not hasWindows then
					utility.sweeping = false
					return
				end
			end
		end)
	end

	utility.textReg = utility.newReg()
	utility.cornerReg = utility.newReg()

	function utility.new(className, properties, children)
		local object = environment.Instance.new(className)
		local parent

		for key, value in environment.pairs(properties or {}) do
			if key == "Parent" then
				parent = value
				continue
			end

			object[key] = value
		end

		for _, child in environment.ipairs(children or {}) do
			child.Parent = object
		end

		if TEXT_CLASSES[className] then
			local font = object.FontFace
			local size = object.TextSize
			utility.textReg[object] = {weight = font.Weight, style = font.Style, size = size}

			if utility.textScale ~= 1 then
				object.TextSize = environment.math.max(8, environment.math.floor(size * utility.textScale + 0.5))
			end
		end

		if className == "UICorner" then
			local radius = object.CornerRadius
			utility.cornerReg[object] = radius

			if utility.radiusMult ~= 1 and radius.Scale == 0 then
				object.CornerRadius = environment.UDim.new(0, environment.math.floor(radius.Offset * utility.radiusMult + 0.5))
			end
		end

		if parent then
			object.Parent = parent
		end

		return object
	end

	function utility.setTextSize(object, size)
		local entry = utility.textReg[object]

		if entry then
			entry.size = size
		end

		object.TextSize = environment.math.max(8, environment.math.floor(size * utility.textScale + 0.5))
	end

	function utility.corner(parent, radius)
		local value = environment.typeof(radius) == "UDim" and radius or environment.UDim.new(0, radius or 8)
		return utility.new("UICorner", {CornerRadius = value, Parent = parent})
	end

	function utility.radiusOne(object)
		local radius = utility.cornerReg[object]

		if radius and radius.Scale == 0 then
			object.CornerRadius = environment.UDim.new(0, environment.math.floor(radius.Offset * utility.radiusMult + 0.5))
		end
	end

	function utility.connect(event, callback, registry)
		local connection = event:Connect(callback)
		table.insert(registry or connections, connection)
		return connection
	end

	function utility.leave(object, callback)
		local connection = object.MouseLeave:Connect(callback)
		object.InputEnded:Connect(function(input)
			if input.UserInputType == environment.Enum.UserInputType.Touch then
				environment.task.delay(0.12, callback)
			end
		end)
		return connection
	end

	function utility.setRadius(radius)
		utility.radiusMult = environment.math.clamp(radius, 0, 2)
		services.refresh.run("radius", utility.radiusOne, function()
			for object in utility.cornerReg do
				if object.Parent then
					utility.radiusOne(object)
				end
			end
		end)
	end

	function utility.stroke(parent, color, thickness, transparency, mode)
		return utility.new("UIStroke", {
			Color = color or environment.Color3.new(1, 1, 1), Thickness = thickness or 1,
			Transparency = transparency or 0, ApplyStrokeMode = mode or environment.Enum.ApplyStrokeMode.Border,
			Parent = parent,
		})
	end

	function utility.pad(parent, top, right, bottom, left)
		return utility.new("UIPadding", {
			PaddingTop = environment.UDim.new(0, top or 0),
			PaddingRight = environment.UDim.new(0, right or top or 0),
			PaddingBottom = environment.UDim.new(0, bottom or top or 0),
			PaddingLeft = environment.UDim.new(0, left or right or top or 0), Parent = parent,
		})
	end

	function utility.list(parent, padding, direction, horizontal, vertical)
		return utility.new("UIListLayout", {
			Padding = environment.UDim.new(0, padding or 0),
			FillDirection = direction or environment.Enum.FillDirection.Vertical,
			HorizontalAlignment = horizontal or environment.Enum.HorizontalAlignment.Left,
			VerticalAlignment = vertical or environment.Enum.VerticalAlignment.Top,
			SortOrder = environment.Enum.SortOrder.LayoutOrder, Parent = parent,
		})
	end

	function utility.shadow(parent, transparency, blur, offset, spread)
		local ok, shadow = environment.pcall(function()
			return utility.new("UIShadow", {
				Color = environment.Color3.new(0, 0, 0), Transparency = transparency or 0.5,
				BlurRadius = environment.UDim.new(0, blur or 12), Offset = environment.UDim2.fromOffset(0, offset or 2),
				Spread = environment.UDim2.fromOffset(spread or 0, spread or 0), Parent = parent,
			})
		end)

		return ok and shadow or nil
	end

	function utility.clamp(value, minimum, maximum)
		if value < minimum then
			return minimum
		end

		if value > maximum then
			return maximum
		end

		return value
	end

	function utility.round(value, decimals)
		local multiplier = 10 ^ (decimals or 0)
		return environment.math.floor(value * multiplier + 0.5) / multiplier
	end

	function utility.fmt(value, decimals)
		decimals = decimals or 0

		if decimals <= 0 then
			return environment.tostring(environment.math.floor(value + 0.5))
		end

		return environment.string.format("%." .. decimals .. "f", value)
	end

	function utility.textWidth(text, font, size)
		local ok, bounds = environment.pcall(function()
			local params = environment.Instance.new("GetTextBoundsParams")
			params.Text = environment.tostring(text)
			params.Font = font
			params.Size = size
			params.Width = 10000
			return services.textService:GetTextBoundsAsync(params)
		end)

		if ok and bounds then
			return bounds.X
		end

		return #environment.tostring(text) * size * 0.5
	end

	function utility.hostGui()
		local gui

		environment.pcall(function()
			if environment.gethui then
				gui = environment.gethui()
			end
		end)

		if environment.typeof(gui) ~= "Instance" then
			environment.pcall(function()
				gui = environment.game:GetService("CoreGui")
			end)
			local ok = environment.pcall(function()
				local folder = environment.Instance.new("Folder")
				folder.Parent = gui
				folder:Destroy()
			end)

			if not ok then
				gui = nil
			end
		end

		if environment.typeof(gui) ~= "Instance" then
			gui = services.player:WaitForChild("PlayerGui")
		end

		return gui
	end

	function utility.protect(gui)
		environment.pcall(function()
			if environment.syn and environment.syn.protect_gui then
				environment.syn.protect_gui(gui)
			end
		end)
		environment.pcall(function()
			if environment.protectgui then
				environment.protectgui(gui)
			end
		end)
	end

	function utility.lighten(color, amount)
		local hue, saturation, value = color:ToHSV()
		return environment.Color3.fromHSV(hue, environment.math.max(0, saturation - amount * 0.35),
			environment.math.min(1, value + amount))
	end

	function utility.darken(color, amount)
		local hue, saturation, value = color:ToHSV()
		return environment.Color3.fromHSV(hue, saturation, environment.math.max(0, value - amount))
	end

	function utility.mouse()
		return services.inputService:GetMouseLocation() - environment.game:GetService("GuiService"):GetGuiInset()
	end

	function utility.isClick(input)
		return input.UserInputType == environment.Enum.UserInputType.MouseButton1
			or input.UserInputType == environment.Enum.UserInputType.Touch
	end

	function utility.isMove(input)
		return input.UserInputType == environment.Enum.UserInputType.MouseMovement
			or input.UserInputType == environment.Enum.UserInputType.Touch
	end

	function utility.sameMove(input, started)
		if started and started.UserInputType == environment.Enum.UserInputType.Touch then
			return input == started
		end

		if started then
			return input.UserInputType == environment.Enum.UserInputType.MouseMovement
		end

		return utility.isMove(input)
	end

	function utility.sameEnd(input, started)
		if started and started.UserInputType == environment.Enum.UserInputType.Touch then
			return input == started
		end

		return utility.isClick(input)
	end

	function utility.at(input)
		if input and input.UserInputType == environment.Enum.UserInputType.Touch then
			return environment.Vector2.new(input.Position.X, input.Position.Y)
		end

		return utility.mouse()
	end

	return utility
end

function NovaUtility._sweepEntry(environment, object, registry, parents, detached)
	local ok, attached = environment.pcall(NovaUtility._isAttached, object, parents)

	if ok and attached then
		detached[object] = nil
		return
	end

	if detached[object] then
		registry[object] = nil
		detached[object] = nil
		return
	end

	detached[object] = true
end

function NovaUtility._isAttached(object, parents)
	local parent = object.Parent

	if parent == nil then
		return false
	end

	local attached = parents[parent]

	if attached == nil then
		attached = object:FindFirstAncestorWhichIsA("ScreenGui") ~= nil
		parents[parent] = attached
	end

	return attached
end

local NovaMotion = {}

function NovaMotion.create(environment, tweenService, utility)
	local easing = environment.Enum.EasingStyle
	local direction = environment.Enum.EasingDirection
	local tweenInfo = environment.TweenInfo.new
	local motion = {
		enabled = true,
		Presets = {
			Quick = tweenInfo(0.15, easing.Quint, direction.Out),
			Base = tweenInfo(0.25, easing.Quint, direction.Out),
			Slow = tweenInfo(0.4, easing.Quint, direction.Out),
			Pop = tweenInfo(0.35, easing.Back, direction.Out),
			PopSmall = tweenInfo(0.22, easing.Back, direction.Out),
			Exit = tweenInfo(0.18, easing.Quint, direction.In),
			Linear = tweenInfo(0.2, easing.Linear),
			Spin = tweenInfo(1.2, easing.Quint, direction.InOut, -1),
		},
	}

	function motion.tween(object, preset, properties)
		if environment.typeof(object) ~= "Instance" then
			return nil
		end

		if environment.type(preset) == "string" then
			preset = motion.Presets[preset] or motion.Presets.Base
		end

		if motion.enabled then
			local ok, tween = environment.pcall(tweenService.Create, tweenService, object, preset, properties)

			if ok and tween then
				tween:Play()
				return tween
			end
		end

		for property, value in environment.pairs(properties) do
			environment.pcall(function()
				object[property] = value
			end)
		end

		return nil
	end

	function motion.ripple(object, color, usePointer)
		if not motion.enabled or environment.typeof(object) ~= "Instance" then
			return
		end

		local position = object.AbsolutePosition
		local size = object.AbsoluteSize
		local origin = size / 2

		if usePointer then
			local mouse = utility.mouse()
			origin = environment.Vector2.new(
				utility.clamp(mouse.X - position.X, 0, size.X),
				utility.clamp(mouse.Y - position.Y, 0, size.Y)
			)
		end

		local diameter = environment.math.max(size.X, size.Y) * 1.6
		local ripple = utility.new("Frame", {
			Name = "Ripple", AnchorPoint = environment.Vector2.new(0.5, 0.5),
			Position = environment.UDim2.fromOffset(origin.X, origin.Y), Size = environment.UDim2.fromOffset(4, 4),
			BackgroundColor3 = color or environment.Color3.new(1, 1, 1),
			BackgroundTransparency = 0.8, ZIndex = object.ZIndex + 5, Parent = object,
		})

		utility.corner(ripple, environment.UDim.new(1, 0))
		motion.tween(ripple, tweenInfo(0.45, easing.Quad, direction.Out), {
			Size = environment.UDim2.fromOffset(diameter, diameter), BackgroundTransparency = 1,
		})
		environment.task.delay(0.5, function()
			ripple:Destroy()
		end)
	end

	return motion
end

local NovaRefresh = {}

function NovaRefresh.create(environment, windows)
	local refresh = {gen = 0, names = {}, full = {}, busy = 0, budget = 0.003}

	function refresh.run(name, apply, fallback)
		refresh.gen += 1
		refresh.names[name] = (refresh.names[name] or 0) + 1
		local generation = refresh.names[name]
		local roots = {}

		for _, window in environment.ipairs(windows or {}) do
			if not window.Destroyed and window.Gui and window.Gui.Parent then
				table.insert(roots, window.Gui)
			end
		end

		if #roots == 0 then
			if fallback then
				fallback()
			end

			return
		end

		refresh.busy += 1
		environment.task.spawn(function()
			local started = environment.os.clock()

			for _, root in environment.ipairs(roots) do
				local objects = root:GetDescendants()

				for index = 1, #objects do
					if refresh.names[name] ~= generation then
						refresh.busy -= 1
						return
					end

					apply(objects[index])

					if index % 40 == 0 and environment.os.clock() - started > refresh.budget then
						environment.task.wait()
						started = environment.os.clock()
					end
				end
			end

			refresh.busy -= 1
		end)
	end

	function refresh.sync(root)
		if not root then
			return
		end

		local objects = root:GetDescendants()
		objects[#objects + 1] = root

		for _, apply in environment.ipairs(refresh.full) do
			for _, object in environment.ipairs(objects) do
				apply(object)
			end
		end
	end

	return refresh
end

local NovaTheme = {}

local NOVA_BASES = {
	{"Midnight", {Background = "0a0e18", Sidebar = "0c1220", Surface = "121a2c", Surface2 = "182438",
		Elevated = "203050", Line = "1a2840", Text = "e8f0ff", Muted = "8aa0c0", Faint = "5a7090"}},
	{"Graphite", {Background = "111214", Sidebar = "141517", Surface = "1a1b1e", Surface2 = "232427",
		Elevated = "2b2d31", Line = "2a2c30", Text = "f0f1f3", Muted = "9a9da4", Faint = "62656c"}},
	{"Amoled", {Background = "000000", Sidebar = "040405", Surface = "0b0c0e", Surface2 = "111216",
		Elevated = "181a1f", Line = "16181c", Text = "f2f3f6", Muted = "8f94a1", Faint = "545965"}},
	{"Deep Sea", {Background = "060c18", Sidebar = "081220", Surface = "0c1a30", Surface2 = "122440",
		Elevated = "183058", Line = "142838", Text = "e6f2ff", Muted = "7eb0e0", Faint = "4a7098"}},
	{"Azure", {Background = "050a16", Sidebar = "07101e", Surface = "0a1830", Surface2 = "102848",
		Elevated = "163860", Line = "122c44", Text = "eef6ff", Muted = "88b8e8", Faint = "5078a8"}},
	{"Plum", {Background = "0e0b12", Sidebar = "110d16", Surface = "17121d", Surface2 = "1f1927",
		Elevated = "271f32", Line = "221b2b", Text = "efe9f6", Muted = "9a8fa8", Faint = "625870"}},
	{"Forest", {Background = "0b0f0d", Sidebar = "0d1210", Surface = "121815", Surface2 = "19211d",
		Elevated = "202a25", Line = "1c241f", Text = "e9f0ec", Muted = "8a9a92", Faint = "56645d"}},
	{"Halloween", {Background = "0d0b0a", Sidebar = "100e0c", Surface = "161311", Surface2 = "1e1a17",
		Elevated = "27221e", Line = "241f1b", Text = "f5eee6", Muted = "a39a90", Faint = "675e55"}},
}

function NovaTheme.create(environment, utility, refresh)
	local fromHex = environment.Color3.fromHex
	local bases = {}

	for _, base in NOVA_BASES do
		table.insert(bases, {base[1], table.clone(base[2])})
	end

	local theme = {
		registry = utility.newReg(), listeners = {}, Bases = bases, base = "Deep Sea",
		Presets = {
			Crimson = fromHex("d64458"), Ember = fromHex("ff7a3d"), Gold = fromHex("f5b94a"),
			Mint = fromHex("3ddc97"), Ocean = fromHex("3d9bff"), Violet = fromHex("8b6cff"),
			Rose = fromHex("ff5fa2"), Ice = fromHex("7fe0ff"),
		},
	}

	theme.tokens = {
		Background = fromHex("060c18"), Sidebar = fromHex("081220"), Surface = fromHex("0c1a30"),
		Surface2 = fromHex("122440"), Elevated = fromHex("183058"), Line = fromHex("142838"),
		Text = fromHex("e6f2ff"), Muted = fromHex("7eb0e0"), Faint = fromHex("4a7098"),
		Accent = theme.Presets.Ocean, OnAccent = fromHex("ffffff"), Success = fromHex("3ddc97"),
		Warning = fromHex("f5b94a"), Danger = fromHex("f0506e"), Glass = fromHex("ffffff"),
	}

	function theme.resolve(role)
		if environment.typeof(role) == "Color3" then
			return role
		end

		if environment.type(role) == "function" then
			return role(theme.tokens)
		end

		return theme.tokens[role] or theme.tokens.Text
	end

	function theme.bind(object, property, role)
		if environment.typeof(object) ~= "Instance" then
			return object
		end

		local properties = theme.registry[object]

		if not properties then
			properties = {}
			theme.registry[object] = properties
		end

		properties[property] = role
		environment.pcall(function()
			object[property] = theme.resolve(role)
		end)
		return object
	end

	function theme.applyOne(object, filter)
		local properties = theme.registry[object]

		if not properties then
			return
		end

		for property, role in environment.pairs(properties) do
			if not filter or filter(role) then
				local ok, value = environment.pcall(theme.resolve, role)

				if ok and value ~= nil then
					environment.pcall(function()
						object[property] = value
					end)
				end
			end
		end
	end

	local function apply(filter, name)
		refresh.run("theme:" .. environment.tostring(name or "all"), function(object)
			theme.applyOne(object, filter)
		end, function()
			for object in environment.pairs(theme.registry) do
				if object.Parent then
					theme.applyOne(object, filter)
				end
			end
		end)
	end

	function theme.set(role, color)
		if environment.typeof(color) ~= "Color3" then
			return
		end

		theme.tokens[role] = color
		apply(function(value) return value == role or environment.type(value) == "function" end, "one:" .. environment.tostring(role))

		for _, listener in environment.ipairs(theme.listeners) do
			environment.pcall(listener, role, color)
		end
	end

	function theme.setMany(colors)
		for role, color in environment.pairs(colors) do
			if environment.typeof(color) == "Color3" then
				theme.tokens[role] = color
			end
		end

		local names = {}

		for role in environment.pairs(colors) do
			table.insert(names, environment.tostring(role))
		end

		table.sort(names)
		apply(function(role)
			return environment.type(role) == "function" or environment.type(role) == "string" and colors[role] ~= nil
		end, "many:" .. table.concat(names, ","))

		for _, listener in environment.ipairs(theme.listeners) do
			for role, color in environment.pairs(colors) do
				environment.pcall(listener, role, color)
			end
		end
	end

	function theme.setBase(name)
		for _, base in environment.ipairs(theme.Bases) do
			if base[1] == name then
				local colors = {}

				for role, value in environment.pairs(base[2]) do
					colors[role] = fromHex(value)
				end

				theme.setMany(colors)
				theme.base = name
				return true
			end
		end

		return false
	end

	function theme.panelFrom(color)
		local hue, saturation, value = color:ToHSV()
		saturation = environment.math.min(saturation, 0.9)
		value = environment.math.clamp(value, 0.025, 0.3)

		local function panel(offset, multiplier)
			return environment.Color3.fromHSV(hue, environment.math.clamp(saturation * (multiplier or 1), 0, 1),
				environment.math.clamp(value + offset, 0, 1))
		end

		return {
			Background = panel(0), Sidebar = panel(0.014), Surface = panel(0.042), Surface2 = panel(0.08, 0.92),
			Elevated = panel(0.112, 0.86), Line = panel(0.096, 0.9),
			Text = environment.Color3.fromHSV(hue, saturation * 0.07, 0.95),
			Muted = environment.Color3.fromHSV(hue, saturation * 0.16, 0.62),
			Faint = environment.Color3.fromHSV(hue, saturation * 0.18, 0.41),
		}
	end

	function theme.onChange(listener)
		table.insert(theme.listeners, listener)
	end

	function theme.accentSoft(amount)
		return function(tokens) return tokens.Surface2:Lerp(tokens.Accent, amount) end
	end

	return theme
end

local NovaFont = {}

function NovaFont.create(environment, utility, refresh)
	local cache = {}
	local font = {
		name = "Builder Sans", id = "BuilderSans",
		Families = {
			{"Builder Sans", "BuilderSans"}, {"Montserrat", "Montserrat"}, {"Nunito", "Nunito"},
			{"Roboto", "Roboto"}, {"Ubuntu", "Ubuntu"}, {"Titillium Web", "TitilliumWeb"},
			{"Josefin Sans", "JosefinSans"}, {"Jura", "Jura"}, {"Source Sans", "SourceSansPro"},
			{"Oswald", "Oswald"}, {"Roboto Mono", "RobotoMono"}, {"Michroma", "Michroma"},
		},
	}

	function font.get(weight, style)
		weight = weight or environment.Enum.FontWeight.Medium
		style = style or environment.Enum.FontStyle.Normal
		local key = font.id .. "|" .. weight.Name .. "|" .. style.Name

		if not cache[key] then
			local path = "rbxasset://fonts/families/" .. font.id .. ".json"
			local ok, value = environment.pcall(environment.Font.new, path, weight, style)
			cache[key] = ok and value or environment.Font.fromEnum(environment.Enum.Font.GothamMedium)
		end

		return cache[key]
	end

	function font.Regular() return font.get(environment.Enum.FontWeight.Regular) end
	function font.Medium() return font.get(environment.Enum.FontWeight.Medium) end
	function font.Semi() return font.get(environment.Enum.FontWeight.SemiBold) end
	function font.Bold() return font.get(environment.Enum.FontWeight.Bold) end
	function font.Heavy() return font.get(environment.Enum.FontWeight.ExtraBold) end

	function font.fontOne(object)
		local settings = utility.textReg[object]

		if settings then
			environment.pcall(function()
				object.FontFace = font.get(settings.weight, settings.style)
			end)
		end
	end

	function font.sizeOne(object)
		local settings = utility.textReg[object]

		if settings then
			environment.pcall(function()
				object.TextSize = environment.math.max(8, environment.math.floor(settings.size * utility.textScale + 0.5))
			end)
		end
	end

	function font.setFamily(name)
		for _, family in environment.ipairs(font.Families) do
			if family[1] == name or family[2] == name then
				font.name = family[1]
				font.id = family[2]
				refresh.run("font", font.fontOne, function()
					for object in environment.pairs(utility.textReg) do
						if object.Parent then
							font.fontOne(object)
						end
					end
				end)
				return true
			end
		end

		return false
	end

	function font.setScale(scale)
		utility.textScale = environment.math.clamp(scale, 0.8, 1.3)
		refresh.run("textsize", font.sizeOne, function()
			for object in environment.pairs(utility.textReg) do
				if object.Parent then
					font.sizeOne(object)
				end
			end
		end)
	end

	return font
end

local NovaIcons = {}

do -- Keep module-private locals out of the main chunk's register budget.

local ICON_NAMES = [=[align-vertical-distribute-center,chevron-down,list-restart,table-cells-split,gavel,dna-off,refresh-ccw-dot,venus,bean,circle-question-mark,folder-code,bolt,heater,feather,align-horizontal-distribute-center,grip-vertical,pill-bottle,person-standing,badge-swiss-franc,between-horizontal-end,file-braces-corner,rotate-cw,house-plus,bus-front,shield-ellipsis,between-vertical-end,globe-lock,tags,concierge-bell,bookmark-minus,plant-pot,file-down,picture-in-picture,messages-square,scissors,file-check-corner,phone-call,anchor,hand-helping,text-wrap,birdhouse,wifi-off,cloud-alert,message-square,cloud-download,folder-plus,cctv-off,notebook-dot,mirror-round,user-round,pointer,between-horizontal-start,chevrons-up-down,brush,message-circle-more,parentheses,book-up-2,flame,chevrons-up,square-dashed,square-mouse-pointer,superscript,signal,wifi-cog,hexagon,navigation-2-off,eye-off,arrows-up-from-line,file-code-corner,square-centerline-dashed-horizontal,panels-right-bottom,scaling,hash,arrow-left-from-line,ship,ticket-percent,calendar-clock,x,non-binary,voicemail,presentation,tree-palm,badge,captions-off,align-vertical-justify-center,download,mouse-right,lens-convex,shrimp-off,focus,diamond-percent,arrow-big-up,volume-x,mouse-pointer-click,face-slightly-smiling-plus,hard-drive,grid-2x2-x,package-minus,cloud,pipette,corner-left-down,badge-cent,cloud-lightning,user-round-pen,arrow-left-to-line,book-open-text,monitor-cloud,parking-meter,cat,heart-handshake,dam,trees,ham,circle-pause,chess-king,bean-off,clef-alto,separator-horizontal,ambulance,globe-code,citrus,phone-missed,calendar-off,chart-column,battery-medium,square-minus,star-check,decimals-arrow-left,folder-output,menu,bangladeshi-taka,image-down,terminal,building-complex-plus,circle-dot-dashed,medal,cake-slice,git-graph,armchair,tickets,qr-code,copy,goal,book-bookmark,trending-down,creative-commons,layers-arrow-down,ev-charger,user-star,road,nfc,align-center-horizontal,car,notebook-tabs,ear,videotape,sun-moon,chart-scatter,podium,toolbox,calendar,calendar-cog,gallery-horizontal,clipboard-x,list-sort-ascending,book-open,circle-pile,rectangle-ellipsis,badge-plus,badge-info,file-headphone,bow-arrow,clipboard-pen-line,user-round-key,folder-search,utensils-crossed,arrow-up,arrow-up-from-dot,align-vertical-justify-start,layers-minus,pause,shrub,flag,biceps-flexed,align-horizontal-distribute-end,donut,calendar-plus-2,move-vertical,file-pen-line,badge-russian-ruble,radius,pilcrow,corner-left-up,georgian-lari,cable,book-user,square-arrow-down,circle-plus,view,cctv,circle-arrow-left,square-off,octagon-alert,panel-bottom-dashed,book-a,align-end-vertical,thumbs-up,globe,rabbit,layers-plus,door-stairwell,banknote-arrow-down,message-square-off,dice-4,message-circle-x,folder-x,message-circle-warning,map,move,arrow-up-left,award,arrow-down-wide-narrow,unfold-horizontal,lens-concave,zoom-out,motorbike,music-4,zoom-in,shield-x,file-volume,disc-3,file-signal,columns-4,archive-x,zodiac-virgo,square-dashed-kanban,mouse-pointer-2,clock-arrow-up,clock-fading,pencil-sparkles,library-big,vegan,star-plus,file-check,clef-bass,message-circle-plus,user-key,credit-card-plus,zodiac-pisces,fast-forward,user-pen,chess-knight,wifi-pen,files,send-to-back,alarm-clock,microscope,zodiac-libra,zodiac-leo,zodiac-gemini,shopping-basket,send,smartphone,square-dashed-bottom,zodiac-aries,zodiac-aquarius,land-plot,wind-arrow-down,germ-off,brush-cleaning,skip-back,x-line-top,book-audio,octagon-minus,file-scan,cupcake,midi-port,message-square-dashed,shield-check,worm,chevrons-left,workflow,umbrella,skip-forward,clipboard-copy,map-pin-off,arrow-up-from-line,circle-chevron-up,wine-off,wine,circle-small,align-vertical-space-between,lamp-desk,circle-arrow-up,zap,beaker,timeline,panel-left-right-dashed,wifi-sync,paintbrush,sliders-vertical,broccoli,wifi-high,wifi,chevron-up,triangles-centerline-dashed-horizontal,whistle,pen-tool,database-check,wheat-off,form,pencil-ruler,dna,arrow-big-down-dash,chart-area,bug-off,wheat,weight-tilde,card-sim,weight,server-crash,map-pin-search,flask-round,eye-dashed,webcam-off,ellipse,spell-check,webcam,waypoints,popcorn,blocks,waves-vertical,layer-arrow-up,microchip,waves-ladder,badge-minus,cloud-sun,circle,shield-alert,waves-horizontal,phone-incoming,map-minus,waves-arrow-down,watch,separator-vertical,washing-machine,heart-minus,scan-square,ampersands,wand-sparkles,user-search,magnet,fence,wallpaper,square-user-round,wallet-minimal,wallet-cards,sunrise,strikethrough,calendar-days,folder-bookmark,wallet,banknote-arrow-up,layout-arrow-right,vote,dollar-sign,message-square-quote,volume-off,ruler-dimension-line,volume-1,list-minus,cloud-hail,volume,eye-closed,app-window-mac,volleyball,ellipsis,copy-check,clock-arrow-right,satellite,bookmark-plus,virus,folder-key,coffee,circle-power,ligature,hourglass,tickets-plane,folder-git,video,bomb,layers-2,battery-full,sparkle,line-dot-bottom-vertical,chart-gantt,folder-tree,command,badge-dollar-sign,align-start-vertical,briefcase-conveyor-belt,message-circle-question-mark,vibrate,bluetooth-off,venus-and-mars,square-square,cannabis,equal-approximately-not,book,grip-horizontal,circle-minus,audio-waveform,moon-star,arrow-down-narrow-wide,ghost,database-backup,wand,receipt-turkish-lira,vector-polygon,calendar-minus-2,copy-minus,vault,folder-input,book-image,badge-x,mouse-left,tag-plus,shirt,van,server-off,move-up,message-circle-dashed,utensils,plug-2,users-round,chess-rook,brackets,calendar-heart,list-ordered,users,star-x,mic-off,user-x,arrow-big-left,square-split-horizontal,triangle-alert,user-round-x,clover,sun-snow,sofa,user-round-search,handbag,funnel-x,map-pin,clock-2,calendar-fold,fish-off,baby,database-x,fold-vertical,user-round-group,hop,face-angry,user-round-cog,cigarette,calendar-chevrons-right,user-round-check,user-round-arrow-left,diamond-plus,refrigerator,file-chart-column,triangle-dashed,git-pull-request-closed,badge-check,user-minus,user-lock,layers-arrow-up,plug-zap,heading-4,chess-queen,graduation-cap,grid-3x2,zodiac-sagittarius,square-dashed-x-corner,square-dashed-bottom-code,clock-7,ethernet-port,scan-text,user-group,shower-head,equal-not,user-cog,move-down,clock-arrow-down,ticket-slash,ruler,settings-2,user,circle-user-round,usb-c-port,layers,list-filter,map-pin-check,egg-off,upload,cog,dog,unplug,swords,spotlight,panel-right-dashed,signal-zero,paper-bag,truck-electric,unlink,check-line,university,bubbles,bot,chart-bar-increasing,ungroup,playing-card,air-vent,unfold-vertical,dot,ice-cream-cone,mouth,file-symlink,clipboard-paste,chevron-last,book-heart,undo-2,circle-parking,globe-check,cloud-check,panel-left,circle-chevron-right,undo,underline,squares-unite,arrow-down-up,git-fork,forward,brain-circuit,between-vertical-start,database,panel-right,umbrella-off,type-outline,flower,log-out,git-branch-plus,clipboard-minus,file-text,trending-up,fire-extinguisher,fan,table-rows-split,milk-off,tv-minimal,cloud-upload,banknote,turntable,message-circle-dashed-check,drumstick,turkish-lira,calendar-search,tube-lotion,line-dot-top-vertical,bell-ring,circle-chevron-left,truck,arrow-down,arrow-up-down,folder-dot,trophy,case-lower,whole-word,monitor,disc-2,trending-up-down,folder-cog,user-shield,triangle,tv-minimal-play,circle-stop,align-vertical-space-around,switch-camera,tree-deciduous,square-chart-gantt,arrow-big-down,circle-parking-off,calendar-x-2,user-plus,move-diagonal-2,bandage,gallery-horizontal-end,panel-top-dashed,transgender,chess-bishop,tram-front,train-front-tunnel,train-front,refresh-cw-off,audio-lines,traffic-cone,tractor,toothbrush,tower-control,rocket,fish,ear-off,touchpad-off,save-check,touchpad,torus,printer,megaphone-off,tornado,arrow-big-right,section,file-clock,toothbrush-sparkles,toy-brick,square-chevron-down,dice-1,drill,app-window,robot-vacuum,hand-metal,tool-case,spell-check-2,toilet,squirrel,list-plus,toggle-left,rotate-ccw-key,timer-reset,chart-pie,paw-print,timer,copy-slash,wind,ticket-x,layout-panel-left,moon,circle-percent,ticket-minus,circle-arrow-out-down-right,square-x,italic,chart-column-increasing,layout-freeform,step-forward,message-square-diff,a-arrow-down,broom-sparkles,sticker,tic-tac-toe,move-left,thermometer-sun,thermometer-snowflake,thermometer,theater,import,badge-turkish-lira,square-terminal,file-music,logs,beef,faucet,file-user,text-quote,square-radical,lightbulb,image-upscale,book-type,text-cursor-input,signpost-big,text-cursor,cloudy,helicopter,square-percent,text-align-justify,navigation-off,arrow-left,car-taxi-front,text-align-end,mouth-off,chevrons-right-left,text-align-center,test-tubes,test-tube-diagonal,brick-wall-fire,square-stack,tent,square-dimensions,face-slightly-smiling,align-end-horizontal,layer-arrow-down,equal,megaphone,calendar-x,telescope,ice-cream-bowl,egg,tangent,save-off,ship-cargo,circle-pound-sterling,video-off,japanese-yen,tally-3,tag,tally-1,library,file-terminal,circle-chevron-down,accessibility,route,square-library,amphora,hourglass-cog,tally-2,tablets,tablet-smartphone,building-complex,remove-formatting,sheet,circle-check-big,table-properties,table-of-contents,map-pinned,corner-down-left,circuit-board,table-columns-split,table-cells-merge,table-2,table,folder-open-dot,book-dashed,syringe,lasso,bluetooth,tree-pine,receipt-indian-rupee,swiss-franc,shield-plus,sunset,sun-medium,sun-dim,can-soda,flask-conical,power,funnel,square-star,folder-sync,monitor-pc,zodiac-ophiuchus,subscript,stretch-vertical,arrow-up-narrow-wide,fishing-hook,stretch-horizontal,maximize-2,stone,frame,calendar-arrow-down,clock-12,star-minus,heart,sticky-note-x,images,lollipop,book-text,chart-no-axes-column-increasing,lamp-floor,file-plus-corner,image,equal-approximately,badge-euro,bike,angle,gap-vertical,sticky-note-check,sticky-note,stethoscope,step-back,star-off,option,banknote-check,scroll-text,server-plus,repeat,star,stamp,toggle-right,file-x,ferris-wheel,camera-off,squircle,search-slash,repeat-off,squares-exclude,square-user,group,square-text,battery,mic-audio-lines,tent-tree,square-split-vertical,rectangle-horizontal,spade,square-slash,screen-share-off,bitcoin,square-scissors,battery-plus,database-search,square-round-corner,file-diff,joystick,square-plus,square-play,spline-pointer,square-pilcrow,axis-3d,square-pi,message-square-share,binoculars,square-pause,calendar-range,square-parking,rose,euro,mail-minus,square-m,square-kanban,square-function,pyramid,clipboard-pen,bottle-wine,alarm-clock-off,square-equal,list,square-dot,square-arrow-right,dome,badge-pound-sterling,bookmark-check,square-divide,wrench-off,shopping-bag,a-arrow-up,clock-check,shrink,chevrons-down,vibrate-off,face-grinning,zodiac-cancer,square-code,file-code,square-chevron-up,carton-off,credit-card-reader,paintbrush-vertical,cassette-tape,battery-low,square-chevron-left,receipt-japanese-yen,signpost,snail,calendar-arrow-up,landmark,fish-symbol,trash-off,loader,bold,dice-2,file-type,clipboard-clock,beer,lectern,square-centerline-dashed-vertical,square-bottom-dashed-scissors,square-bookmark,binary,move-diagonal,square-asterisk,door-closed,square-arrow-up-right,layout-template,rows-4,piano,square-arrow-right-exit,bookmark-off,hand-heart,square-arrow-right-enter,scan-qr-code,message-square-check,square-arrow-out-up-right,square-arrow-out-up-left,monitor-play,brain,square-arrow-out-down-left,server-cog,square-arrow-down-right,key,clock-11,gap-horizontal,ticket-plus,arrow-up-0-1,bell-electric,square,heading,book-open-check,panel-top-close,lasso-select,sprout,spray-can,sport-shoe,shield-off,bus,search-alert,audio-lines-x,chart-no-axes-gantt,file-spreadsheet,percent,clipboard-list,speech,contact-round,speaker,keyboard-off,sparkles,file-badge,battery-warning,mail-question-mark,arrow-down-from-line,briefcase,biohazard,rectangle-circle,braces,scale-3d,panel-top-bottom-dashed,mail-x,square-dashed-mouse-pointer,square-sparkles,lock-open,file-play,pizza,list-indent-decrease,arrow-up-wide-narrow,soup,clock-5,solar-panel,rotate-ccw,align-horizontal-justify-center,soap-dispenser-droplet,antenna,memory-stick,scan-eye,snowflake,square-check,heart-plus,smartphone-nfc,map-pin-minus-inside,git-merge,gallery-vertical-end,square-dashed-plus,hand-coins,zodiac-capricorn,wifi-low,sliders-horizontal,clock,file-pen,git-compare-arrows,cloud-sun-rain,align-horizontal-justify-start,power-off,mail-badge,skull,calendar-plus,siren,arrow-down-z-a,bath,signature,unlink-2,signal-medium,shopping-cart-minus,folder-check,signal-low,book-key,ribbon,microwave,calculator,gallery-vertical,sigma,shuffle,square-dashed-text,map-pin-pen,move-up-left,shrimp,folder-heart,hard-drive-upload,monitor-speaker,shopping-cart-plus,arrow-up-a-z,package,square-dashed-top-solid,ship-wheel,shield-user,shield-question-mark,swatch-book,receipt-cent,spool,folder-archive,folder-symlink,can,ban,message-square-x,paint-roller,git-pull-request-draft,archive,shield-lock,shield-keyhole,shield-half,circle-slash-2,shield-cog-corner,cake,cloud-rain,chart-bar,shield-cog,wrench,shield-ban,shield,shelving-unit,flag-triangle-right,shell,gamepad-directional,bell,share,shapes,music-3,chart-bar-big,user-check,proportions,settings,plane,webhook-off,carrot,square-arrow-left,file-cog,circle-dashed,server,send-horizontal,search-x,germ,squares-subtract,search-code,dices,split,list-sort-descending,search,forklift,scroll,alarm-clock-minus,heart-x,eraser,square-sigma,screen-share,bluetooth-connected,rotate-ccw-square,chart-no-axes-column,cannabis-off,folder-kanban,lighthouse,mars-stroke,roller-coaster,school,scan-search,file-box,pickaxe,paint-bucket,glass-water,mic,glasses,piggy-bank,scan-face,cuboid,cloud-off,check-check,activity,axe,plane-takeoff,scan-box,cloud-rain-wind,scan-barcode,scan,copy-x,file-axis-3d,radical,chart-column-decreasing,play-off,bug-play,align-vertical-distribute-start,save-plus,waves-arrow-up,tally-5,headset,save,saudi-riyal,circle-divide,satellite-dish,sandwich,salad,life-buoy,sailboat,external-link,volume-2,battery-charging,russian-ruble,square-arrow-up-left,brick-wall-shield,footprints,rows-3,building,rows-2,router,route-off,tag-x,book-alert,link-2,astroid,bell-minus,image-up,closed-caption,drum,arrow-up-z-a,sun,rotate-cw-fading-clock,rotate-cw-clock,file-key,rotate-ccw-clock,rotate-3d,scissors-line-dashed,house-wifi,robot-arm,rewind,ticket-check,combine,reply,replace-all,mountain,mars,picture-in-picture-2,radio-off,flower-2,replace,squares-intersect,repeat-2,repeat-1,keyboard-music,star-half,playing-cards-fan,code-xml,pencil-line,mails,brain-cog,tablet,regex,pi,trash,book-down,hdmi-port,trailer,case-upper,circle-fading-arrow-up,refresh-cw,croissant,phone,computer,barcode,pin,redo,bed,circle-arrow-right,divide,grape,rectangle-vertical,party-popper,file-chart-pie,rectangle-goggles,file-x-corner,dice-6,receipt-swiss-franc,blender,receipt-russian-ruble,zap-off,square-check-big,receipt-euro,receipt,ratio,laptop-minimal,rat,rainbow,map-pin-minus,omega,chart-spline,message-square-more,radio-receiver,chart-candlestick,radio,arrow-down-a-z,radiation,radar,move-horizontal,file-sliders,quote,square-exclamation-point,cup-soda,puzzle,projector,sword,printer-check,map-pin-x,earth,slice,dice-3,milk,mouse-pointer-ban,crown,circle-slash,circle-star,rotate-cw-square,atom,package-x,bed-double,pound-sterling,circle-dot,file-exclamation-point,hand-fist,message-circle-code,folder-git-2,message-square-code,popsicle,towel-rack,layout-grid,arrow-big-left-dash,plus,dumbbell,plug,playing-cards,houses,scale,play,flashlight,panel-top-open,plane-landing,pin-off,notebook,redo-2,pill,square-menu,pilcrow-left,monitor-smartphone,laptop,scan-line,clock-4,square-arrow-up,book-minus,file-question-mark,chevrons-left-right,phone-off,save-pen,arrow-down-to-line,phone-forwarded,refresh-ccw,venetian-mask,calendar-check-2,phi,spline,banknote-x,git-pull-request-create-arrow,pentagon,circle-check,pencil-off,caravan,pen-off,pen-line,hand-platter,pc-case,timer-off,arrow-big-right-dash,bed-single,parasol,paperclip,backpack,calendar-minus,panels-left-bottom,panel-top,panel-right-open,mic-signal,arrow-down-right,panel-right-close,letters,wifi-zero,panel-left-open,panel-left-dashed,map-pin-plus,hard-drive-download,image-off,panel-bottom-close,panel-bottom,panda,engine,square-chevron-right,mail-search,package-search,bone-fracture,package-plus,package-open,crop,package-2,lambda,ampersand,ad,shopping-cart,align-vertical-justify-end,origami,alarm-smoke,orbit,file-input,clock-8,hand-grab,cloud-cog,blend,hd,radio-tower,list-tree,droplet,line-squiggle,eye,octagon-pause,square-dashed-x,banana,gpu,message-square-heart,nut-off,circle-equal,face-slightly-frowning,nut,notepad-text-dashed,notepad-text,text-initial,arrow-up-right,maximize,leafy-green,message-square-dot,file-chart-line,columns-3-cog,newspaper,network,minimize-2,nepali-rupee,navigation-2,cone,navigation,file-image,music-2,palette,barrel,gallery-thumbnails,move-up-right,cpu,move-right,thumbs-down,merge,hamburger,move-down-right,hat-glasses,code,move-down-left,move-3d,mail-check,mouse-pointer,carton,mouse-off,kanban,bone,apple,rocking-chair,bot-off,circle-arrow-out-down-left,database-arrow-down,folder,circle-arrow-out-up-left,mop,cable-car,arrow-down-left,square-activity,message-square-text,cigarette-off,monitor-up,message-circle,circle-arrow-out-up-right,car-battery,monitor-stop,fold-horizontal,shovel,calendar-1,cloud-moon,square-arrow-out-down-right,monitor-pause,clock-plus,circle-euro,cloud-snow,anvil,arrow-big-up-dash,monitor-off,log-in,monitor-dot,monitor-cog,monitor-check,list-checks,chevrons-down-up,clipboard-plus,circle-x,list-end,minus,list-collapse,chevrons-right,audio-lines-off,message-square-reply,corner-down-right,milestone,summary,lamp-wall-down,mic-vocal,layout-arrow-down,ellipsis-vertical,globe-off,square-stop,arrow-up-1-0,align-horizontal-justify-end,scan-heart,align-vertical-distribute-end,heart-crack,airplay,case-sensitive,messages-circle,message-square-warning,monitor-x,bell-check,database-minus,square-pen,message-square-plus,message-square-lock,dice-5,octagon,ticket,folder-lock,message-circle-off,briefcase-plus,bookmark,message-circle-heart,utility-pole,message-circle-check,chart-bar-decreasing,database-plus,calendar-sync,funnel-plus,store,circle-arrow-down,notebook-pen,egg-fried,compass,keyboard,corner-right-up,map-pin-x-inside,printer-3d,user-round-plus,panel-left-close,crosshair,pilcrow-right,user-round-minus,mailbox,indian-rupee,mail-plus,mail-pen,bell-off,mail-clock,mouse-pointer-2-off,drone,slash,credit-card-x,aperture,arrow-right-left,mail,vector-square,circle-gauge,circle-alert,check,text-search,arrow-down-to-dot,monitor-down,lock-keyhole-open,chef-hat,lock-keyhole,lock,file-archive,signal-high,inbox,locate-fixed,locate,image-play,align-horizontal-space-between,loader-pinwheel,calendar-check,database-zap,droplets,loader-circle,broom,corner-right-down,layout-list,file-search,list-video,alarm-clock-plus,circle-dollar-sign,usb,house,receipt-pound-sterling,list-music,list-indent-increase,id-card,mouse,minimize,list-clock,list-chevrons-up-down,galaxy,list-chevrons-down-up,book-x,mirror-rectangular,list-check,link-2-off,link,headphone-off,asterisk,line-style,octagon-x,languages,line-dot-right-horizontal,alarm-clock-check,guitar,dock,beer-off,scooter,square-parking-off,notebook-text,arrow-right-to-line,clef-treble,tally-4,zodiac-taurus,leaf,door-open,flag-triangle-left,grid-3x3,file,layout-panel-top,pocket-knife,book-copy,castle,car-front,clock-alert,reply-all,cloud-moon-rain,clipboard-type,layout-dashboard,list-todo,printer-x,bird,list-start,lamp-wall-up,a-large-small,lamp-ceiling,lamp,map-plus,key-square,file-chart-column-increasing,kayak,database-arrow-up,arrow-right-from-line,flame-kindling,square-power,iv-bag,bring-to-front,iteration-cw,iteration-ccw,bell-plus,inspection-panel,info,infinity,folders,mail-warning,image-plus,image-minus,id-card-lanyard,bridge,chart-line,file-lock,cast,circle-fading-plus,clock-10,undo-dot,target,list-filter-plus,house-plug,drama,house-heart,baseline,martini,contrast,hotel,candy-off,hospital,book-check,heart-off,book-lock,highlighter,briefcase-medical,calendars,text-align-start,heart-pulse,hop-off,warehouse,sticky-notes,drafting-compass,save-all,file-braces,heading-6,heading-5,heading-3,heading-2,fishing-rod,book-headphones,credit-card,heading-1,haze,hard-hat,shredder,panel-bottom-open,door-closed-package,eject,credit-card-check,balloon,map-pin-plus-inside,bookmark-x,badge-question-mark,pen,hand,candy-cane,hammer,grip,gamepad-2,file-type-corner,grid-2x2-check,grid-2x2,globe-x,shield-minus,circle-off,dessert,eclipse,church,git-pull-request-create,cylinder,badge-japanese-yen,columns-3,receipt-text,git-merge-conflict,git-compare,git-commit-vertical,git-commit-horizontal,file-output,disc-album,circle-ellipsis,arrow-down-0-1,captions,git-branch,gift,philippine-peso,badge-alert,gem,folder-pen,cross,gauge,chevron-right,sticky-note-minus,square-arrow-down-left,share-2,gamepad,fullscreen,fuel,folder-up,folder-search-2,folder-root,chess-pawn,folder-open,briefcase-business,folder-minus,message-circle-reply,cloud-sync,triangle-right,folder-clock,folder-closed,mop-sparkles,type,webhook,flask-conical-off,align-horizontal-distribute-start,flashlight-off,flag-off,pointer-off,turtle,camera,fingerprint-pattern,film,git-pull-request,bluetooth-searching,arrow-up-to-line,squircle-dashed,clock-3,badge-percent,face-expressionless,file-video-camera,file-up,grid-2x2-plus,file-stack,box,file-search-corner,clock-1,file-heart,house-cog,space,file-minus-corner,file-minus,file-digit,corner-up-left,clock-6,zodiac-scorpio,key-round,headphones,tv,factory,face-neutral,rss,expand,at-sign,map-pin-check-inside,sticky-note-off,music,handshake,earth-lock,circle-user,copy-plus,droplet-off,virus-off,line-dot-left-horizontal,disc,diff,search-check,clipboard-check,columns-2,diamond-minus,clipboard,align-center-vertical,diameter,delete,club,cloud-fog,mosque,currency,map-pin-house,package-check,chevron-first,pencil,boxes,list-x,copyright,copyleft,corner-up-right,cookie,clock-arrow-left,container,contact,badge-indian-rupee,construction,redo-dot,component,align-start-horizontal,chart-column-stacked,file-plus,git-pull-request-arrow,coins,decimals-arrow-right,bell-dot,folder-down,cloud-drizzle,cloud-backup,align-horizontal-space-around,door-closed-locked,clock-9,diamond,blinds,clapperboard,circle-play,book-search,git-branch-minus,circle-dashed-check,recycle,mountain-snow,luggage,chevrons-left-right-ellipsis,bot-message-square,phone-outgoing,smartphone-charging,chevron-left,train-track,cherry,chart-bar-stacked,sticky-note-plus,chart-no-axes-column-decreasing,chart-network,chart-column-big,chart-no-axes-combined,metronome,triangles-centerline-dashed-vertical,arrow-down-1-0,credit-card-minus,candy,arrow-left-right,lightbulb-off,panels-top-left,beef-off,locate-off,bug,test-tube,brick-wall,cooking-pot,boom-box,book-up,book-plus,laptop-minimal-check,mail-open,park,baggage-claim,variable,arrow-right,archive-restore]=]
local ICON_POSITIONS = [=[1,175,0;1,650,0;1,850,250;2,150,0;1,250,700;1,600,225;1,575,800;2,225,225;1,50,350;1,675,25;1,500,425;1,50,400;1,75,925;1,825,50;1,50,75;1,175,800;1,375,925;1,850,450;1,325,50;1,100,325;1,650,225;1,950,475;1,725,300;1,425,125;1,650,850;1,50,375;1,550,425;2,50,125;1,25,725;1,300,200;1,825,500;1,300,575;1,500,800;1,950,225;1,525,925;1,500,375;1,775,525;1,100,100;1,900,100;2,200,50;1,325,125;2,100,400;1,175,550;1,175,975;1,75,650;1,100,825;1,225,375;1,525,700;1,500,675;2,225,200;1,500,825;1,75,350;1,325,325;1,50,475;1,775,375;1,600,675;1,450,50;1,900,25;1,300,350;1,775,900;1,775,925;2,50,50;1,750,800;2,175,325;1,25,975;1,750,475;1,250,600;1,250,75;1,425,450;1,925,725;1,725,550;1,875,575;1,650,350;1,100,175;1,800,725;2,250,25;1,100,450;2,225,300;1,550,675;2,0,450;1,350,975;2,25,300;1,250,125;1,50,525;1,100,75;1,275,550;1,525,675;1,775,300;1,550,975;1,700,225;1,150,650;1,150,100;2,375,100;1,575,625;1,75,775;1,700,300;1,300,675;1,775,475;1,475,275;1,950,375;1,350,425;1,250,100;1,750,0;2,325,100;1,50,225;1,75,400;1,450,725;1,550,725;1,250,350;1,250,750;1,575,225;2,350,0;1,75,900;1,125,550;1,100,525;1,75,325;1,350,350;1,650,825;1,200,0;1,575,400;1,400,300;1,700,600;1,525,50;1,550,75;1,200,200;1,800,900;1,950,875;1,300,500;1,150,775;1,950,200;1,100,275;1,525,500;2,0,200;1,500,50;1,425,250;1,200,925;1,325,225;1,875,100;1,75,150;2,100,175;1,775,575;1,475,300;1,450,525;1,375,100;2,325,25;1,175,600;1,300,750;1,375,475;2,150,275;1,750,650;1,575,650;1,0,100;1,550,50;1,475,750;1,850,0;2,100,350;2,50,25;1,300,325;1,550,775;2,200,100;1,325,250;1,75,475;1,500,450;1,25,675;1,825,275;1,50,425;1,75,600;1,775,600;1,25,325;1,125,225;1,250,625;1,50,450;1,125,575;2,375,50;1,25,900;2,25,400;1,275,50;1,125,175;1,50,125;1,250,800;1,500,775;1,925,625;1,0,900;1,0,425;1,25,100;1,450,375;1,500,75;1,900,325;1,0,875;1,350,25;1,525,825;1,400,900;1,325,450;1,200,750;1,350,200;1,400,100;1,950,675;1,25,650;2,75,375;1,200,400;1,150,500;1,750,950;1,300,925;1,450,800;1,450,25;1,75,50;2,50,200;1,475,500;1,725,625;1,225,825;1,325,500;1,75,300;1,375,775;1,0,800;1,625,525;1,875,75;1,650,500;1,350,775;1,875,350;1,75,225;1,25,300;1,175,100;2,50,325;1,800,275;2,250,300;1,775,425;1,800,425;2,275,275;1,900,625;1,400,500;1,700,125;1,700,200;1,175,575;1,125,100;2,300,250;1,950,725;1,625,575;1,325,400;1,275,450;1,950,350;1,725,350;2,300,150;1,850,975;1,475,400;1,325,375;1,725,425;2,150,250;1,100,675;2,400,150;1,875,0;2,75,325;1,75,550;2,75,425;1,300,600;1,700,775;1,50,50;1,750,425;2,450,100;2,475,75;2,50,475;1,725,800;1,675,800;1,825,750;1,975,700;2,125,400;2,150,375;1,575,475;2,450,75;1,175,775;1,75,450;1,625,925;2,250,275;1,400,75;1,275,950;1,775,125;1,650,150;1,700,475;1,525,625;1,725,775;2,325,200;1,400,250;2,350,175;2,175,200;1,600,950;1,225,475;1,600,525;1,100,200;1,550,125;2,400,125;2,375,150;1,600,100;1,0,175;1,700,350;1,0,650;2,175,350;1,100,300;2,75,200;1,300,950;2,50,450;1,550,700;1,900,675;1,150,375;2,150,350;2,475,50;1,525,125;2,150,200;2,225,275;1,375,900;1,475,325;2,275,225;1,750,200;1,975,325;1,575,250;1,50,175;1,175,425;1,0,525;2,250,250;2,325,175;1,500,100;2,300,200;1,575,900;1,500,625;1,775,150;1,275,575;2,425,75;1,650,200;1,875,725;2,400,100;2,450,50;1,475,850;1,200,250;2,475,25;1,350,700;1,775,400;2,0,475;1,75,275;1,550,200;1,450,250;1,775,725;2,25,450;1,725,575;1,750,375;2,75,400;2,100,375;1,625,850;2,125,350;1,225,775;1,650,800;1,150,50;2,200,275;2,200,225;1,250,850;1,800,75;2,225,250;1,875,900;2,275,200;2,300,175;2,100,0;2,0,25;1,50,500;1,600,325;2,250,225;1,50,325;1,150,900;2,325,150;1,500,325;1,325,825;2,400,75;1,750,675;2,450,25;1,950,150;1,0,725;2,350,125;1,300,550;1,225,0;2,475,0;1,600,250;1,600,175;1,350,375;1,575,850;1,250,250;2,25,425;1,275,650;1,325,425;1,700,0;1,650,425;1,825,200;2,125,150;1,375,550;2,125,325;1,25,425;1,325,725;1,250,150;1,600,975;1,550,525;1,525,100;1,925,25;1,125,625;1,200,150;1,0,150;1,275,250;1,700,450;2,175,275;1,150,300;2,250,200;1,800,950;1,75,500;1,550,300;1,350,150;1,200,775;1,225,450;1,50,275;1,900,300;1,0,250;1,125,825;1,500,300;2,175,300;1,850,525;2,350,100;1,575,0;1,575,200;2,375,75;1,325,600;1,200,275;1,275,100;1,700,500;2,125,50;1,775,750;2,425,25;1,550,925;1,925,300;1,825,325;2,0,425;1,675,650;2,75,350;1,0,625;1,500,25;1,0,550;1,900,200;2,50,375;1,975,875;1,875,300;2,125,300;1,250,0;1,850,900;2,250,100;2,250,175;1,425,325;2,25,50;1,725,850;2,275,150;1,800,200;1,600,350;1,425,700;1,625,100;1,25,525;1,200,700;1,325,25;1,375,425;1,650,275;2,400,25;1,925,100;1,200,650;2,425,0;1,225,425;1,125,425;2,0,400;2,25,375;1,125,675;1,475,900;1,575,300;2,225,125;1,775,200;1,225,125;2,100,300;2,125,275;1,275,775;1,650,675;1,450,550;1,25,600;1,400,575;1,250,725;2,375,175;1,825,850;1,675,975;1,500,225;1,425,425;1,625,825;2,175,225;1,600,925;1,500,350;2,200,200;1,300,900;1,400,325;2,200,75;1,725,700;1,975,525;2,100,325;1,525,175;2,275,125;1,200,850;1,125,950;1,700,425;1,725,125;2,300,100;1,300,450;1,525,300;2,325,75;2,75,50;1,725,875;1,950,325;1,775,775;1,675,600;2,75,275;2,350,50;1,225,400;2,400,0;1,25,500;1,100,400;1,100,500;2,0,375;1,750,575;1,75,0;2,25,350;1,300,525;1,600,425;1,450,750;1,600,300;1,150,550;1,600,50;1,225,250;2,125,250;1,150,525;1,600,375;1,125,600;1,275,975;1,575,100;2,75,300;2,150,225;1,900,900;1,200,75;1,900,75;1,725,225;1,475,50;1,25,400;1,325,475;1,900,375;2,200,175;2,250,125;1,725,200;1,350,750;1,50,900;1,175,525;1,550,350;2,275,75;1,225,675;1,0,850;2,50,100;1,650,525;2,300,75;1,500,250;1,400,0;2,375,0;1,850,300;1,50,775;2,0,350;1,425,150;2,25,325;1,475,600;1,150,275;1,600,75;2,50,300;1,125,150;1,150,150;1,450,475;2,100,250;1,400,200;2,200,300;1,925,275;1,725,100;2,300,50;1,475,450;2,175,250;2,175,175;2,325,50;1,550,150;1,25,150;2,125,0;2,50,275;1,875,775;1,25,200;1,175,500;1,375,200;2,50,350;1,400,800;1,125,250;1,525,425;1,825,450;2,125,200;1,125,500;2,150,175;2,225,100;2,200,125;1,525,850;1,75,250;2,275,50;2,300,25;2,150,150;2,0,300;1,675,725;1,150,750;1,0,825;2,75,225;1,500,925;2,50,250;2,100,200;1,900,450;1,175,950;2,125,175;1,200,50;1,750,725;1,450,425;2,175,125;2,325,0;1,800,850;1,75,725;1,200,625;1,200,25;1,700,700;1,875,125;2,225,75;1,900,700;2,250,50;1,825,975;1,875,225;2,300,0;1,525,875;2,25,250;1,325,300;1,475,800;2,0,275;1,525,250;2,425,100;2,175,100;1,950,125;1,875,325;1,100,575;2,275,0;1,100,550;1,825,950;1,150,875;1,600,25;1,100,950;1,900,950;1,500,650;1,0,0;1,125,400;1,975,900;2,25,225;1,250,950;2,125,125;2,150,100;2,100,150;2,175,75;1,300,725;1,300,75;1,925,850;1,50,825;1,325,775;1,375,50;1,850,25;1,450,450;2,250,0;1,750,975;1,600,475;1,375,650;1,475,25;2,50,175;1,700,850;2,25,200;1,450,300;1,50,950;1,900,825;2,100,125;1,700,525;1,25,250;1,575,25;2,125,100;1,475,725;1,375,275;2,150,75;2,175,50;2,225,0;1,400,125;1,775,975;2,25,175;1,750,925;1,50,800;1,100,25;1,375,675;1,475,375;1,150,975;1,350,225;2,75,125;1,625,400;1,700,150;2,125,75;1,475,950;1,850,675;1,0,675;2,150,300;1,50,975;2,200,0;2,75,100;2,25,150;1,700,375;1,575,325;1,625,50;1,50,0;1,900,525;1,875,825;1,125,75;1,850,175;2,0,175;2,150,25;2,0,150;1,475,75;1,425,950;1,850,650;1,675,0;2,75,75;2,100,50;1,400,725;1,400,375;1,425,275;2,125,25;2,0,125;2,25,100;2,25,125;1,200,725;1,300,175;2,50,75;1,400,650;1,100,350;2,0,325;1,375,975;2,0,100;1,975,550;2,75,25;2,75,0;2,0,50;1,225,350;1,800,125;1,375,950;1,575,375;1,975,800;1,950,0;1,300,875;2,425,125;2,50,0;2,25,0;1,50,250;1,125,775;2,0,0;1,250,875;1,950,975;1,700,250;1,225,325;1,650,75;1,900,925;1,100,900;1,950,950;1,325,700;1,300,800;1,500,0;1,425,200;1,675,375;1,850,50;1,350,675;1,525,325;1,175,175;1,450,0;1,75,125;1,300,650;1,950,925;1,925,975;1,875,975;1,925,925;1,875,950;1,900,350;1,25,350;1,950,525;1,525,950;1,925,475;1,950,900;1,975,850;2,275,25;1,350,550;1,775,100;1,275,300;1,850,950;1,825,650;1,950,450;1,975,825;1,850,925;1,125,850;1,900,875;1,125,275;1,900,275;2,50,150;1,825,925;1,725,650;1,625,950;1,900,850;1,475,975;1,300,150;1,950,800;1,175,225;1,400,400;1,975,775;1,350,525;1,975,75;1,800,925;1,825,900;1,850,750;1,850,875;1,350,0;1,875,850;1,275,875;1,400,50;1,950,775;1,450,125;1,975,750;1,600,800;1,400,450;1,150,950;1,850,850;1,900,800;1,925,775;1,800,550;1,100,600;1,75,425;1,100,0;1,975,725;1,650,450;1,700,975;1,750,875;1,475,350;1,0,350;1,325,175;1,725,950;2,300,225;1,750,775;1,25,0;1,300,425;1,950,600;1,475,175;2,200,250;1,150,700;2,100,425;1,700,950;1,400,475;1,725,925;1,450,150;1,75,700;1,575,675;1,325,275;1,225,175;1,775,875;1,975,400;1,675,875;1,800,775;1,200,350;1,550,500;1,175,725;2,100,225;1,575,525;1,75,375;1,50,750;1,500,400;1,250,450;1,325,100;1,825,250;1,900,750;1,950,700;1,975,675;1,425,25;1,375,825;1,650,975;1,375,450;1,700,925;1,900,175;1,800,625;1,575,725;1,775,850;1,275,225;1,925,75;1,800,825;1,700,750;1,575,575;1,825,800;1,850,775;1,275,900;1,425,100;1,900,725;1,600,875;1,975,650;1,850,200;1,675,50;1,325,625;2,225,50;1,225,75;1,250,175;1,800,975;1,375,625;1,100,375;1,850,425;1,425,625;1,675,925;1,700,900;1,750,850;1,525,975;1,400,150;1,900,575;1,100,225;1,350,275;1,650,250;1,875,425;1,200,500;1,925,675;1,750,25;1,950,650;1,800,250;1,975,625;1,700,175;1,150,250;1,925,200;1,50,200;1,200,325;1,375,75;1,800,575;1,525,0;1,925,525;1,875,400;1,850,275;1,925,750;1,875,875;1,425,675;1,875,25;1,925,400;1,100,975;1,325,0;1,675,900;1,550,175;1,700,875;1,475,925;1,150,0;1,750,825;1,50,150;1,975,175;1,800,650;1,775,800;1,825,825;1,175,825;1,850,725;1,650,475;1,825,150;1,450,500;1,900,775;1,0,975;2,75,450;2,125,375;1,925,650;1,225,500;1,900,0;1,950,25;1,575,175;1,100,50;1,400,925;1,225,875;1,575,975;1,475,100;1,650,900;1,150,125;1,300,100;1,725,825;2,375,25;1,800,750;1,700,825;1,575,350;1,825,725;1,175,300;1,775,625;1,725,450;1,275,275;1,425,525;1,875,675;1,900,650;1,875,800;1,575,550;1,975,250;1,975,575;1,350,575;1,725,275;1,225,950;1,675,850;1,175,125;1,650,600;1,850,825;1,825,700;1,925,600;1,950,575;2,25,75;1,425,925;1,775,825;1,625,300;1,0,925;1,200,375;1,175,200;1,200,950;1,600,650;1,700,275;1,100,125;1,575,925;1,600,900;1,625,875;1,650,50;1,700,800;1,300,250;1,625,125;1,50,550;1,675,825;2,275,250;1,750,750;1,875,650;1,800,700;1,25,875;1,825,675;1,375,575;1,125,300;1,875,625;1,925,575;1,825,400;1,150,450;2,225,175;1,850,500;1,950,550;1,850,475;2,375,125;1,475,125;1,925,700;1,375,500;1,500,175;1,500,975;1,725,750;1,800,675;1,150,800;1,925,875;1,850,625;1,775,50;1,800,800;1,800,300;1,775,700;1,775,175;1,925,550;1,0,75;1,125,875;1,450,400;1,925,825;1,975,500;1,175,275;1,500,900;1,400,225;1,100,475;1,300,625;1,575,500;1,325,800;1,625,775;1,575,875;1,675,775;1,675,200;1,550,750;1,625,625;1,650,325;1,800,375;1,625,350;1,475,825;1,775,675;1,700,100;1,675,75;1,250,375;1,25,25;1,0,325;1,875,450;1,825,625;1,650,100;1,850,600;1,600,850;1,500,275;1,725,150;1,650,700;1,625,0;1,800,525;1,550,0;1,125,50;1,975,475;2,50,425;2,150,50;1,300,700;1,950,500;1,550,875;1,475,200;1,600,825;1,625,800;1,650,775;1,675,400;1,675,750;1,325,525;2,425,50;1,275,125;1,700,725;1,725,900;1,375,150;1,800,150;1,825,600;1,450,100;1,850,575;1,875,550;1,925,500;2,100,75;1,425,50;1,375,700;1,200,125;1,225,200;1,400,625;1,200,525;1,75,750;1,300,25;2,0,75;1,425,975;1,450,950;1,150,725;1,550,850;1,575,825;1,550,900;1,700,325;1,725,675;1,800,600;2,0,250;1,150,600;1,825,575;1,900,500;1,725,475;1,300,825;1,525,775;1,625,725;1,750,175;1,875,525;1,950,850;1,975,425;1,400,975;1,825,225;1,925,900;1,725,600;1,375,375;1,325,950;1,775,350;1,450,75;2,175,0;1,450,925;1,600,700;2,75,250;1,275,200;1,550,450;2,250,75;1,350,250;1,300,375;1,500,875;1,0,775;1,625,675;1,50,700;1,375,25;1,975,350;1,600,775;1,425,0;1,25,625;1,625,200;1,375,600;1,700,675;1,525,750;1,525,350;1,750,625;1,375,525;1,800,25;1,900,475;1,250,200;1,925,450;2,200,325;1,850,800;1,400,950;1,825,550;1,450,900;1,475,575;1,475,875;1,500,850;1,625,500;1,925,325;1,275,350;1,400,750;1,600,750;1,25,575;1,550,800;1,75,175;1,675,675;1,700,650;1,275,925;1,675,225;1,750,600;1,950,750;1,675,125;1,825,525;1,875,475;2,100,25;1,950,400;1,450,675;1,800,50;1,950,625;1,25,775;1,625,550;1,600,600;1,725,75;1,625,75;1,575,125;1,975,450;1,150,175;1,675,575;1,25,375;1,425,900;1,400,275;1,275,600;1,975,25;1,875,275;1,400,525;1,550,600;1,450,875;2,25,275;1,75,975;1,0,225;1,600,725;1,25,800;1,625,700;1,700,625;1,650,375;1,900,550;1,775,550;1,850,75;1,800,475;1,900,425;1,325,975;1,425,800;1,650,725;1,350,950;1,825,875;1,450,850;1,250,925;1,450,600;1,725,725;1,575,150;1,675,950;1,125,350;1,800,100;1,425,225;1,675,625;1,450,975;1,225,50;1,750,550;1,550,825;2,275,175;1,175,375;1,825,475;1,825,775;1,0,375;1,750,225;1,900,400;1,650,25;1,300,975;1,525,75;1,400,875;1,425,850;1,850,150;1,450,825;2,50,225;1,225,25;1,0,400;1,625,650;1,650,625;1,300,50;1,550,25;1,750,525;1,775,500;1,925,350;1,850,325;1,275,0;1,975,300;1,750,325;2,25,475;1,325,925;1,350,900;1,525,600;1,750,250;1,475,550;1,475,775;1,400,850;1,500,750;1,575,275;1,750,900;1,900,225;1,700,550;1,0,450;1,725,525;1,750,500;1,800,0;1,825,425;1,750,300;1,175,25;1,0,50;1,650,875;1,75,100;1,850,400;1,25,75;1,875,375;1,175,700;1,475,250;1,950,50;1,100,625;1,275,175;1,575,425;1,575,775;1,725,375;1,125,700;1,450,625;1,225,625;1,250,975;1,800,875;1,150,225;1,425,550;1,450,700;1,350,875;1,350,325;1,100,750;1,325,900;1,400,825;1,375,850;2,0,225;1,25,275;1,225,900;1,850,225;1,475,675;1,550,325;1,225,525;1,600,625;1,625,600;1,600,575;1,650,575;1,725,500;1,0,750;1,675,550;1,200,675;1,850,375;1,525,725;1,350,50;1,475,475;1,950,275;1,200,575;1,225,975;2,75,175;1,925,225;1,50,925;1,325,875;1,625,375;1,350,400;1,350,850;1,425,775;1,200,900;1,550,650;1,425,175;1,675,525;1,950,100;1,475,0;1,175,50;1,650,750;1,125,375;1,125,525;1,550,250;1,850,100;1,75,575;1,825,375;1,375,175;1,25,225;1,650,950;1,250,900;1,250,400;1,975,225;1,600,550;1,50,600;1,0,575;1,200,975;1,675,250;1,625,900;1,250,300;1,700,50;1,875,750;1,325,850;1,250,475;1,325,350;1,600,150;1,25,175;1,175,75;1,350,825;1,375,725;1,400,775;1,425,750;1,475,700;1,300,775;1,500,150;1,75,625;1,475,225;1,175,900;1,550,625;1,200,875;1,350,300;1,125,200;1,300,850;1,375,400;1,675,500;2,25,25;1,650,400;1,825,350;1,175,875;1,625,225;1,525,450;1,950,825;1,200,100;1,125,25;1,750,700;1,150,25;1,275,725;1,50,25;1,375,225;1,975,200;1,225,925;1,950,250;1,300,125;1,450,350;1,925,800;1,350,800;1,425,725;1,825,0;1,950,300;2,150,125;1,250,675;1,750,400;1,225,300;1,200,300;1,800,350;2,450,0;1,900,250;1,125,475;1,425,375;1,400,175;1,625,325;1,975,975;1,175,475;1,500,725;1,750,100;1,100,650;1,775,275;1,275,500;1,475,650;1,975,375;2,300,125;1,375,875;1,750,50;1,425,875;2,350,75;1,800,325;1,250,775;1,950,175;1,975,150;1,200,225;1,175,925;1,650,550;1,175,650;1,975,600;1,50,725;1,0,200;1,300,0;1,825,300;2,325,125;1,250,425;1,200,450;1,200,425;2,225,25;1,250,25;1,375,800;1,475,625;1,175,450;1,450,650;1,400,700;1,750,125;1,850,700;1,275,750;1,550,550;1,500,600;1,450,575;1,50,100;1,600,500;1,150,400;1,350,450;1,100,725;1,625,475;1,100,425;1,300,475;1,975,100;1,725,175;1,700,400;1,75,25;1,450,225;2,250,150;1,675,350;1,950,425;1,925,175;1,975,125;1,550,475;1,500,700;1,575,600;1,225,850;1,250,825;1,550,400;1,275,800;1,375,125;1,525,650;1,325,750;1,400,675;1,350,725;1,350,650;1,225,100;1,425,650;1,975,275;1,525,525;1,500,575;1,25,50;1,100,875;1,550,275;1,350,75;1,500,950;1,725,975;1,450,775;1,275,25;1,300,400;2,175,25;2,325,225;1,875,200;1,350,475;1,50,850;1,225,750;1,325,575;1,925,150;1,575,750;1,325,150;1,275,325;1,600,0;1,425,300;1,850,550;1,725,25;1,50,650;1,125,925;1,750,350;1,925,425;1,350,100;1,775,325;1,625,425;1,0,25;1,725,325;1,600,450;1,375,750;1,875,175;1,600,275;1,925,125;1,525,275;1,0,275;1,925,0;1,775,950;1,75,950;1,175,350;1,100,925;1,125,900;1,175,250;1,175,850;1,200,825;1,225,800;1,825,125;1,875,250;1,425,600;1,500,525;1,575,450;1,325,200;1,500,125;1,125,750;1,300,300;1,275,400;1,700,25;2,100,275;2,100,100;1,150,925;1,750,275;1,225,600;1,775,250;1,325,75;1,275,850;1,675,100;1,875,150;1,150,425;1,900,125;1,350,125;1,200,800;1,150,325;1,975,50;1,250,275;1,300,275;2,75,150;1,150,850;1,950,75;2,150,325;1,975,950;1,250,575;1,525,900;1,625,250;1,400,600;1,425,575;1,475,525;1,500,500;1,100,800;1,250,225;1,25,750;1,525,475;1,600,400;1,675,325;1,575,950;1,425,825;1,400,425;1,675,175;1,150,625;1,200,175;1,550,575;1,225,275;1,375,0;1,350,925;1,825,175;1,175,400;1,25,950;1,150,825;1,400,550;1,525,375;1,350,625;1,275,700;1,500,475;1,550,950;1,200,475;1,225,575;1,775,75;1,275,375;1,725,250;1,600,200;1,100,250;1,200,550;1,875,500;1,850,125;1,925,50;1,975,0;1,0,950;1,25,850;1,675,150;1,375,300;1,125,125;1,25,550;1,25,925;1,100,850;1,800,500;1,275,75;1,225,725;1,125,800;1,775,25;1,275,675;1,550,100;1,925,950;1,625,975;1,900,600;1,350,600;1,650,300;1,675,275;1,900,50;1,50,875;1,75,850;1,50,575;1,175,750;1,300,225;1,225,700;1,675,475;1,525,225;2,200,150;1,550,375;1,525,400;1,850,350;2,225,150;2,350,150;1,825,100;1,0,125;1,875,50;1,75,825;1,525,800;2,350,25;1,250,325;1,250,650;1,275,625;1,675,300;1,125,325;1,0,300;1,875,925;1,600,125;1,50,300;1,175,675;1,425,475;1,475,425;1,325,650;1,625,275;1,25,475;1,750,150;1,725,0;1,225,650;1,800,225;1,650,925;1,100,775;1,75,800;1,325,550;1,250,525;1,525,200;2,350,200;1,900,150;1,325,675;2,275,100;1,25,825;1,125,725;1,775,650;1,350,500;1,175,150;1,725,400;1,900,975;1,775,450;1,775,225;1,825,25;1,500,200;1,550,225;1,150,675;2,50,400;1,525,550;1,650,175;1,750,75;1,875,600;1,275,425;1,250,500;1,175,625;1,0,700;1,125,0;1,200,600;1,250,550;1,400,350;1,25,700;1,800,400;1,625,175;1,675,450;1,800,450;1,625,25;1,925,375;1,0,500;1,675,425;1,425,350;1,450,325;1,225,550;1,650,125;1,375,350;1,700,75;1,725,50;1,150,200;1,775,0;1,625,750;1,75,675;1,25,125;1,575,50;1,825,75;1,800,175;1,275,475;1,275,525;1,275,150;1,425,500;1,50,675;1,150,575;1,75,75;1,425,400;1,450,275;1,100,700;1,225,225;1,375,325;1,50,625;1,0,475;1,75,875;1,525,150;1,675,700;1,750,450;1,275,825;1,450,200;1,150,350;1,650,650;1,875,700;1,575,75;2,175,150;1,150,475;1,75,525;1,975,925;1,450,175;1,475,150;1,0,600;1,375,250;1,925,250;2,125,225;1,100,150;1,125,650;1,125,450;1,75,200;1,625,450;1,700,575;1,400,25;1,525,575;1,525,25;2,200,25;1,350,175;1,625,150;1,175,325;1,425,75;1,25,450;1,500,550;1,125,975;1,575,700;1,225,150;2,400,50;1,250,50;1,150,75]=]
local ICON_URLS = {"rbxassetid://104502745253902", "rbxassetid://89421818506275"}
local ICON_ALIASES = {
	["trash-2"] = "trash", gear = "settings", grid = "grid-3x3", ["person-running"] = "footprints",
	["alert-triangle"] = "triangle-alert", ["alert-circle"] = "circle-alert", ["check-circle"] = "circle-check",
	["check-circle-2"] = "circle-check-big", ["x-circle"] = "circle-x", ["help-circle"] = "circle-question-mark",
	["more-horizontal"] = "ellipsis", ["more-vertical"] = "ellipsis-vertical", edit = "pencil", ["edit-2"] = "pencil",
	["edit-3"] = "pencil-line", home = "house", unlock = "lock-open", ["bar-chart"] = "chart-bar",
	["bar-chart-2"] = "chart-bar", ["loader-2"] = "loader-circle", sliders = "sliders-horizontal", filter = "funnel",
	["wand-2"] = "wand-sparkles", ["play-circle"] = "circle-play", ["pause-circle"] = "circle-pause",
	["stop-circle"] = "circle-stop", ["user-circle"] = "circle-user", ["plus-circle"] = "circle-plus",
	["minus-circle"] = "circle-minus", ["pie-chart"] = "chart-pie", ["line-chart"] = "chart-line",
	["shield-close"] = "shield-x", ["sort-asc"] = "arrow-up-narrow-wide", ["sort-desc"] = "arrow-down-wide-narrow",
	verified = "badge-check", ["file-warning"] = "file-exclamation-point",
}

function NovaIcons.create(environment)
	local icons = {module = nil, tried = false, waiting = {}}
	local size = environment.Vector2.new(24, 24)

	function icons.load()
		if icons.module then
			return icons.module
		end

		icons.tried = true
		local indexes = {}

		for index, name in environment.ipairs(environment.string.split(ICON_NAMES, ",")) do
			indexes[name] = index
		end

		local positions = environment.string.split(ICON_POSITIONS, ";")
		icons.module = {GetAsset = function(name)
			local index = indexes[name] or indexes[ICON_ALIASES[name] or ""]
			local position = index and positions[index]

			if not position then
				return nil
			end

			local values = environment.string.split(position, ",")
			return {
				IconName = name, Url = ICON_URLS[environment.tonumber(values[1])], ImageRectSize = size,
				ImageRectOffset = environment.Vector2.new(environment.tonumber(values[2]), environment.tonumber(values[3])),
			}
		end}

		local waiting = icons.waiting
		icons.waiting = {}

		for _, callback in environment.ipairs(waiting) do
			environment.pcall(callback)
		end

		return icons.module
	end

	function icons.resolve(name)
		if not name or name == "" then
			return nil
		end

		if environment.type(name) == "number" or environment.tostring(name):match("^%d+$") then
			return {Url = "rbxassetid://" .. environment.tostring(name),
				ImageRectOffset = environment.Vector2.zero, ImageRectSize = environment.Vector2.zero}
		end

		if environment.tostring(name):match("^rbx") then
			return {Url = environment.tostring(name), ImageRectOffset = environment.Vector2.zero,
				ImageRectSize = environment.Vector2.zero}
		end

		if not icons.module then
			icons.load()
		end

		if not icons.module then
			return nil
		end

		local ok, asset = environment.pcall(icons.module.GetAsset, name)

		if ok and environment.type(asset) == "table" then
			return asset
		end

		return nil
	end

	function icons.apply(object, name)
		if environment.typeof(object) ~= "Instance" then
			return
		end

		if not icons.module then
			icons.load()
		end

		local asset = icons.resolve(name)

		if asset then
			object.Image = asset.Url
			object.ImageRectOffset = asset.ImageRectOffset or environment.Vector2.zero
			object.ImageRectSize = asset.ImageRectSize or environment.Vector2.zero
			object.Visible = true
		end
	end

	return icons
end

end -- NovaIcons private scope

local NovaStore = {}

function NovaStore.create(environment, json)
	local store = {}

	function store.new(path)
		local state = {path = path, data = {}, dirty = false}

		environment.pcall(function()
			if path and environment.isfile and environment.readfile and environment.isfile(path) then
				local data = json:JSONDecode(environment.readfile(path))

				if environment.type(data) == "table" then
					state.data = data
				end
			end
		end)

		function state.get(key, default)
			local value = state.data[key]

			if value == nil then
				return default
			end

			return value
		end

		function state.set(key, value)
			if state.data[key] == value then
				return
			end

			state.data[key] = value
			state.save()
		end

		function state.save()
			if state.dirty then
				return
			end

			state.dirty = true
			environment.task.delay(0.6, function()
				state.dirty = false
				environment.pcall(function()
					if not path or not environment.writefile then
						return
					end

					if environment.isfolder and environment.makefolder then
						if not environment.isfolder("PulseHub") then
							environment.makefolder("PulseHub")
						end

						if not environment.isfolder("PulseHub/nova") then
							environment.makefolder("PulseHub/nova")
						end
					end

					environment.writefile(path, json:JSONEncode(state.data))
				end)
			end)
		end

		return state
	end

	return store
end

local NovaSound = {}

function NovaSound.create(environment)
	local sound = {
		volume = 0.5, enabled = true, cache = {}, folder = "PulseHub/nova",
		specs = {
			click = {dur = 0.07, tones = {{f0 = 1900, f1 = 1300, decay = 70, amp = 0.55},
				{f0 = 3800, f1 = 2600, decay = 120, amp = 0.18}}, noise = 0.05},
			hover = {dur = 0.035, tones = {{f0 = 2600, f1 = 2400, decay = 160, amp = 0.22}}},
			on = {dur = 0.12, tones = {{f0 = 880, f1 = 880, decay = 40, amp = 0.4},
				{f0 = 1320, f1 = 1320, decay = 40, amp = 0.4, start = 0.045}}},
			off = {dur = 0.12, tones = {{f0 = 1320, f1 = 1320, decay = 40, amp = 0.35},
				{f0 = 880, f1 = 880, decay = 40, amp = 0.35, start = 0.045}}},
			open = {dur = 0.22, tones = {{f0 = 520, f1 = 980, glide = 0.5, decay = 16, amp = 0.35},
				{f0 = 1040, f1 = 1960, glide = 0.5, decay = 22, amp = 0.12}}},
			close = {dur = 0.18, tones = {{f0 = 980, f1 = 520, glide = 0.6, decay = 20, amp = 0.3}}},
			notify = {dur = 0.45, tones = {{f0 = 1175, f1 = 1175, decay = 9, amp = 0.3},
				{f0 = 1568, f1 = 1568, decay = 9, amp = 0.28, start = 0.09}}},
			tick = {dur = 0.025, tones = {{f0 = 3200, f1 = 3000, decay = 220, amp = 0.16}}},
		},
	}

	function sound.asset(name)
		if sound.cache[name] ~= nil then
			return sound.cache[name]
		end

		sound.cache[name] = false
		local ok, asset = environment.pcall(function()
			if not environment.writefile or not environment.getcustomasset then
				return nil
			end

			if environment.isfolder and environment.makefolder then
				if not environment.isfolder("PulseHub") then
					environment.makefolder("PulseHub")
				end

				if not environment.isfolder(sound.folder) then
					environment.makefolder(sound.folder)
				end
			end

			local path = sound.folder .. "/" .. name .. ".wav"

			if not (environment.isfile and environment.isfile(path)) then
				local samples = NovaSound._samples(environment, sound.specs[name])
				environment.writefile(path, NovaSound._wave(environment, samples))
			end

			return environment.getcustomasset(path)
		end)

		if ok and asset then
			sound.cache[name] = asset
		end

		return sound.cache[name]
	end

	function sound.play(name, volume)
		if not sound.enabled or sound.volume <= 0 then
			return
		end

		local asset = sound.asset(name)

		if not asset or not sound.host then
			return
		end

		local instance = environment.Instance.new("Sound")
		instance.SoundId = asset
		instance.Volume = sound.volume * (volume or 1)
		instance.Parent = sound.host
		instance:Play()

		environment.task.delay(1, function()
			instance:Destroy()
		end)
	end

	function sound.preload()
		environment.task.spawn(function()
			for name in environment.pairs(sound.specs) do
				environment.pcall(sound.asset, name)
			end
		end)
	end

	return sound
end

function NovaSound._samples(environment, specification)
	local count = environment.math.floor(22050 * specification.dur)
	local samples = table.create(count)
	local phases = {}

	for index = 1, count do
		local time = (index - 1) / 22050
		local progress = time / specification.dur
		local value = 0

		for toneIndex, tone in environment.ipairs(specification.tones) do
			local frequency = tone.f0 + (tone.f1 - tone.f0) * environment.math.min(1, progress / (tone.glide or 1))
			phases[toneIndex] = (phases[toneIndex] or 0) + 6.283185307179586 * frequency / 22050
			local envelope = environment.math.exp(-time * (tone.decay or 30))
				* environment.math.min(1, time / (tone.attack or 0.002))

			if tone.start and time < tone.start then
				envelope = 0
			end

			if tone.start and time >= tone.start then
				local elapsed = time - tone.start
				envelope = environment.math.exp(-elapsed * (tone.decay or 30))
					* environment.math.min(1, elapsed / (tone.attack or 0.002))
			end

			value += environment.math.sin(phases[toneIndex]) * envelope * (tone.amp or 0.5)
		end

		if specification.noise then
			value += (environment.math.random() * 2 - 1) * specification.noise * environment.math.exp(-time * 90)
		end

		samples[index] = value
	end

	return samples
end

function NovaSound._wave(environment, samples)
	local count = #samples
	local header = {
		"RIFF", environment.string.pack("<I4", 36 + count * 2), "WAVE", "fmt ",
		environment.string.pack("<I4I2I2I4I4I2I2", 16, 1, 1, 22050, 44100, 2, 16),
		"data", environment.string.pack("<I4", count * 2),
	}
	local encoded = table.create(count)

	for index, sample in samples do
		local value = environment.math.floor(environment.math.clamp(sample, -1, 1) * 32767)
		encoded[index] = environment.string.pack("<i2", value)
	end

	return table.concat(header) .. table.concat(encoded)
end

local NovaTexture = {}

do -- Keep module-private locals out of the main chunk's register budget.

local CRC32_TABLE
local TEXTURE_BUCKETS = {3, 5, 7, 9, 12, 15, 19, 24, 30, 38}

function NovaTexture.encode(environment, width, height, pixel)
	local buffer = environment.buffer
	local bit32 = environment.bit32
	local math = environment.math
	local string = environment.string
	local stride = width * 4 + 1
	local image = buffer.create(stride * height)
	local offset = 0

	for row = 0, height - 1 do
		buffer.writeu8(image, offset, 0)
		offset += 1

		for column = 0, width - 1 do
			local red, green, blue, alpha = pixel(column, row)
			buffer.writeu8(image, offset, math.clamp(math.floor(red + 0.5), 0, 255))
			buffer.writeu8(image, offset + 1, math.clamp(math.floor(green + 0.5), 0, 255))
			buffer.writeu8(image, offset + 2, math.clamp(math.floor(blue + 0.5), 0, 255))
			buffer.writeu8(image, offset + 3, math.clamp(math.floor(alpha + 0.5), 0, 255))
			offset += 4
		end
	end

	local size = buffer.len(image)
	local first, second = 1, 0

	for index = 0, size - 1 do
		first = (first + buffer.readu8(image, index)) % 65521
		second = (second + first) % 65521
	end

	local blocks = {"x\1"}
	offset = 0

	while offset < size do
		local length = math.min(65535, size - offset)
		local last = offset + length >= size and 1 or 0
		table.insert(blocks, string.char(last) .. string.pack("<I2I2", length, bit32.bxor(length, 65535)))
		table.insert(blocks, buffer.readstring(image, offset, length))
		offset += length
	end

	table.insert(blocks, string.pack(">I4", second * 65536 + first))
	local header = string.pack(">I4I4", width, height) .. "\8\6\0\0\0"

	return "\137PNG\13\10\26\10"
		.. NovaTexture._chunk(environment, "IHDR", header)
		.. NovaTexture._chunk(environment, "IDAT", table.concat(blocks))
		.. NovaTexture._chunk(environment, "IEND", "")
end

function NovaTexture.resolve(utility, kind, radius, buckets)
	buckets = buckets or TEXTURE_BUCKETS
	local scaled = radius * utility.radiusMult
	local distance = math.huge
	local bucket = buckets[1]

	for _, candidate in buckets do
		local current = math.abs(math.log(math.max(scaled, 0.5) / candidate))

		if current < distance then
			distance = current
			bucket = candidate
		end
	end

	return kind .. "@" .. bucket, math.max(scaled / bucket, 0.3)
end

function NovaTexture._chunk(environment, kind, data)
	local string = environment.string
	return string.pack(">I4", #data) .. kind .. data .. string.pack(">I4", NovaTexture._checksum(environment, kind .. data))
end

function NovaTexture._checksum(environment, data)
	local bit32 = environment.bit32
	local buffer = environment.buffer

	if not CRC32_TABLE then
		CRC32_TABLE = table.create(256)

		for index = 0, 255 do
			local value = index

			for _ = 1, 8 do
				if bit32.band(value, 1) == 1 then
					value = bit32.bxor(3988292384, bit32.rshift(value, 1))
					continue
				end

				value = bit32.rshift(value, 1)
			end

			CRC32_TABLE[index] = value
		end
	end

	local bytes = buffer.fromstring(data)
	local checksum = 4294967295

	for index = 0, buffer.len(bytes) - 1 do
		local lookup = bit32.band(bit32.bxor(checksum, buffer.readu8(bytes, index)), 255)
		checksum = bit32.bxor(CRC32_TABLE[lookup], bit32.rshift(checksum, 8))
	end

	return bit32.bxor(checksum, 4294967295)
end

function NovaTexture.specifications(environment)
	local math = environment.math
	local pill = {x = 48, y = 24, width = 48, height = 24, radius = 24}
	local shadow = {x = 48, y = 48, width = 16, height = 16, radius = 10}
	local meshA = {{0.12, 0.18, 0.42, 0.55, 1}, {0.62, 0.05, 0.32, 0.4, 0.6},
		{0.88, 0.72, 0.4, 0.55, 0.9}, {0.35, 0.95, 0.5, 0.35, 0.55}}
	local meshB = {{0.85, 0.15, 0.36, 0.5, 0.95}, {0.2, 0.85, 0.45, 0.5, 0.85}, {0.55, 0.5, 0.3, 0.3, 0.35}}

	local function meshPixel(spots, x, y)
		local horizontal, vertical = (x + 0.5) / 256, (y + 0.5) / 160
		local strength = 0

		for _, spot in environment.ipairs(spots) do
			local dx, dy = (horizontal - spot[1]) / spot[3], (vertical - spot[2]) / spot[4]
			strength += spot[5] * math.exp(-(dx * dx + dy * dy))
		end

		strength = math.clamp(strength, 0, 1)
		local edge = NovaTexture._smooth(0, 0.2, horizontal) * NovaTexture._smooth(0, 0.2, 1 - horizontal)
			* NovaTexture._smooth(0, 0.2, vertical) * NovaTexture._smooth(0, 0.2, 1 - vertical)
		return 255, 255, 255, 255 * strength ^ 1.15 * edge
	end

	return {
		grain = {w = 128, h = 128, tile = true, px = function()
			return function(x, y)
				local noise = NovaTexture._noise(x, y, 3.3) * 0.7 + NovaTexture._noise(x * 0.5, y * 0.5, 9.1) * 0.3
				return 255, 255, 255, noise * noise * 64
			end
		end},
		glow = {w = 256, h = 256, px = function()
			return function(x, y)
				local distance = math.sqrt(((x + 0.5) / 128 - 1) ^ 2 + ((y + 0.5) / 128 - 1) ^ 2)
				return 255, 255, 255, math.max(0, 1 - distance) ^ 2.3 * 255
			end
		end},
		vignette = {w = 256, h = 256, px = function()
			return function(x, y)
				local dx, dy = (x + 0.5) / 128 - 1, (y + 0.5) / 128 - 1
				return 0, 0, 0, NovaTexture._smooth(0.45, 1.35, math.sqrt(dx * dx * 0.8 + dy * dy)) * 255
			end
		end},
		knob = {w = 128, h = 128, px = function()
			return function(x, y)
				local dx, dy = x + 0.5 - 64, y + 0.5 - 64
				local distance = math.sqrt(dx * dx + dy * dy)
				local alpha = math.clamp(63 - distance + 0.5, 0, 1)
				local brightness = (1 - 0.2 * ((dy + 63) / 126)) * (1 - 0.14 * math.clamp((distance - 52) / 11, 0, 1))
				local glowX, glowY = (dx + 14) / 34, (dy + 30) / 22
				local highlight = math.max(0, 1 - (glowX * glowX + glowY * glowY))
				brightness = math.min(1, brightness + 0.1 * highlight ^ 1.5)
				return 255 * brightness, 255 * brightness, 255 * brightness, 255 * alpha
			end
		end},
		pillfill = {w = 96, h = 48, px = function()
			return function(x, y)
				return 255, 255, 255, 255 * NovaTexture._coverage(NovaTexture._distance(x + 0.5, y + 0.5, pill))
			end
		end},
		trackshade = {w = 96, h = 48, px = function()
			return function(x, y)
				local distance = NovaTexture._distance(x + 0.5, y + 0.5, pill)
				local inside, coverage, vertical = -distance, NovaTexture._coverage(distance), (y + 0.5) / 48
				local gradient = math.clamp(1.15 - 1.6 * vertical, 0, 1)
				local alpha = 0.55 * (1 - NovaTexture._smooth(0, 11, inside)) * gradient
					+ 0.16 * (1 - NovaTexture._smooth(0, 5, inside))
				alpha = math.clamp(alpha, 0, 0.7)
				local shade = 0.1 * (1 - NovaTexture._smooth(0, 5, inside)) * math.clamp((vertical - 0.5) * 3, 0, 1)
				local combined = alpha + shade * (1 - alpha)
				local color = combined > 0 and 255 * shade * (1 - alpha) / combined or 0
				return color, color, color, 255 * combined * coverage
			end
		end},
		dots = {w = 24, h = 24, tile = true, px = function()
			return function(x, y)
				local distance = math.sqrt((x + 0.5 - 12) ^ 2 + (y + 0.5 - 12) ^ 2)
				return 255, 255, 255, 255 * math.clamp(1.25 - distance, 0, 1)
			end
		end},
		grid = {w = 40, h = 40, tile = true, px = function()
			return function(x, y) return 255, 255, 255, (x == 0 or y == 0) and 255 or 0 end
		end},
		diag = {w = 20, h = 20, tile = true, px = function()
			return function(x, y)
				local position = (x + y) % 10 / 10
				return 255, 255, 255, 255 * (1 - NovaTexture._smooth(0.12, 0.3, math.abs(position - 0.06) * 2))
			end
		end},
		crosses = {w = 32, h = 32, tile = true, px = function()
			return function(x, y)
				local dx, dy = math.abs(x + 0.5 - 16), math.abs(y + 0.5 - 16)
				local alpha = (dx < 0.9 and dy < 4.2 or dy < 0.9 and dx < 4.2) and 255 or 0
				return 255, 255, 255, alpha
			end
		end},
		scan = {w = 4, h = 4, tile = true, px = function()
			return function(_, y) return 255, 255, 255, y == 0 and 255 or 0 end
		end},
		stripes = {w = 32, h = 32, tile = true, px = function()
			return function(x, y)
				local brightness = math.sin((x + y) / 16 * 3.141592653589793 * 2) * 0.5 + 0.5
				return 255, 255, 255, 255 * brightness * brightness
			end
		end},
		checker = {w = 16, h = 16, tile = true, px = function()
			return function(x, y)
				local brightness = (math.floor(x / 8) + math.floor(y / 8)) % 2 == 0 and 74 or 52
				return brightness, brightness, brightness + 4, 255
			end
		end},
		meshA = {w = 256, h = 160, px = function() return function(x, y) return meshPixel(meshA, x, y) end end},
		meshB = {w = 256, h = 160, px = function() return function(x, y) return meshPixel(meshB, x, y) end end},
		shadow9 = {w = 96, h = 96, slice = environment.Rect.new(40, 40, 56, 56), px = function()
			return function(x, y)
				local distance = NovaTexture._distance(x + 0.5, y + 0.5, shadow)
				return 0, 0, 0, 255 * (1 / (1 + math.exp(distance / 4.6))) * 0.9
			end
		end},
	}
end

function NovaTexture._smooth(minimum, maximum, value)
	local progress = math.clamp((value - minimum) / (maximum - minimum), 0, 1)
	return progress * progress * (3 - 2 * progress)
end

function NovaTexture._distance(x, y, shape)
	local dx = math.abs(x - shape.x) - (shape.width - shape.radius)
	local dy = math.abs(y - shape.y) - (shape.height - shape.radius)
	local outsideX, outsideY = math.max(dx, 0), math.max(dy, 0)
	return math.sqrt(outsideX * outsideX + outsideY * outsideY) + math.min(math.max(dx, dy), 0) - shape.radius
end

function NovaTexture._coverage(distance)
	return math.clamp(0.5 - distance, 0, 1)
end

function NovaTexture._noise(x, y, seed)
	local value = math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453
	return value - math.floor(value)
end

function NovaTexture._radiusSpecification(environment, kind, radius)
	local padding = radius + 4
	local size = math.max(64, 2 * padding + 24)
	local center = size / 2
	local scale = size / 64
	local shape = {x = center, y = center, width = center, height = center, radius = radius}
	local rim = {x = center, y = center, width = center - 0.6, height = center - 0.6, radius = radius}

	local renderers = {
		rim9 = function(x, y)
			local distance = NovaTexture._distance(x + 0.5, y + 0.5, rim)
			local edge = math.clamp(1 - math.abs(distance + 0.5) / 1.05, 0, 1)
			local vertical = 0.95 - 0.86 * NovaTexture._smooth(0, size, y + 0.5)
			local horizontal = 0.75 + 0.25 * (1 - math.abs(x + 0.5 - center) / center)
			return 255, 255, 255, 255 * edge * vertical * horizontal
		end,
		gloss9 = function(x, y)
			local distance = NovaTexture._distance(x + 0.5, y + 0.5, shape)
			local coverage = NovaTexture._coverage(distance)
			local top = 1 - NovaTexture._smooth(0, 34 * scale, y + 0.5)
			local edge = (1 - NovaTexture._smooth(0, 2.4, -distance)) * top
			return 255, 255, 255, 255 * (0.2 * top + 0.16 * edge) * coverage
		end,
		tile9 = function(x, y)
			local distance = NovaTexture._distance(x + 0.5, y + 0.5, shape)
			local coverage = NovaTexture._coverage(distance)
			local brightness = 1 - 0.24 * NovaTexture._smooth(0, size, y + 0.5)
			brightness = math.min(1, brightness + 0.16 * (1 - NovaTexture._smooth(0, 3.2, y + 0.5)))
				* (1 - 0.1 * (1 - NovaTexture._smooth(0, 3, -distance)) * NovaTexture._smooth(size * 0.47, size, y + 0.5))
			return 255 * brightness, 255 * brightness, 255 * brightness, 255 * coverage
		end,
		plate9 = function(x, y)
			local distance = NovaTexture._distance(x + 0.5, y + 0.5, shape)
			local brightness = 1 - 0.1 * NovaTexture._smooth(0, size, y + 0.5)
			return 255 * brightness, 255 * brightness, 255 * brightness, 255 * NovaTexture._coverage(distance)
		end,
	}

	local pixel = renderers[kind] or renderers.plate9
	return {w = size, h = size, slice = environment.Rect.new(padding, padding, size - padding, size - padding),
		px = function() return pixel end}
end

function NovaTexture.create(environment, utility, refresh)
	local texture = {
		cache = {}, folder = "PulseHub/nova/tex", version = "v7", specs = NovaTexture.specifications(environment),
		buckets = table.clone(TEXTURE_BUCKETS), kinds = {rim9 = 14, gloss9 = 14, tile9 = 15, plate9 = 14},
		tracked = utility.newReg(),
	}

	function texture.resolve(kind, radius)
		return NovaTexture.resolve(utility, kind, radius, texture.buckets)
	end

	function texture.get(name)
		if texture.cache[name] ~= nil then
			return texture.cache[name] or nil
		end

		texture.cache[name] = false
		local specification = texture.specs[name]

		if not specification then
			local kind, radius = environment.string.match(name, "^(%a+%d)@(%d+)$")

			if kind and texture.kinds[kind] then
				specification = NovaTexture._radiusSpecification(environment, kind, environment.tonumber(radius))
				texture.specs[name] = specification
			end
		end

		if not specification then
			return nil
		end

		local ok, asset = environment.pcall(function()
			if not environment.writefile or not environment.getcustomasset or not environment.buffer then
				return nil
			end

			if environment.isfolder and environment.makefolder then
				for _, folder in {"PulseHub", "PulseHub/nova", texture.folder} do
					if not environment.isfolder(folder) then
						environment.makefolder(folder)
					end
				end
			end

			local path = texture.folder .. "/" .. environment.string.gsub(name, "@", "_r") .. "_" .. texture.version .. ".png"

			if not (environment.isfile and environment.isfile(path)) then
				environment.writefile(path, NovaTexture.encode(environment, specification.w, specification.h, specification.px()))
			end

			return environment.getcustomasset(path)
		end)

		if ok and asset then
			texture.cache[name] = asset
		end

		return texture.cache[name] or nil
	end

	function texture.image(parent, kind, properties)
		properties = properties or {}
		local trackedKind = texture.kinds[kind] and kind or nil
		local base, name, sliceScale

		if trackedKind then
			base = texture.kinds[trackedKind] * (properties.SliceScale or 0.5)
			name, sliceScale = texture.resolve(trackedKind, base)
		end

		name = name or kind
		local asset = texture.get(name)

		if not asset then
			return nil
		end

		local specification = texture.specs[name]
		local image = environment.Instance.new("ImageLabel")
		image.Name = properties.Name or "Tex_" .. kind
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Image = asset

		if specification.slice then
			image.ScaleType = environment.Enum.ScaleType.Slice
			image.SliceCenter = specification.slice
			image.SliceScale = sliceScale or properties.SliceScale or 0.5
		end

		if not specification.slice and specification.tile then
			image.ScaleType = environment.Enum.ScaleType.Tile
			image.TileSize = environment.UDim2.fromOffset(specification.w, specification.h)
		end

		for key, value in environment.pairs(properties) do
			if key ~= "Name" and key ~= "SliceScale" and key ~= "Parent" then
				image[key] = value
			end
		end

		image.Parent = parent

		if trackedKind then
			texture.tracked[image] = {kind = trackedKind, base = base}
		end

		return image
	end

	function texture.retarget(image)
		local tracked = texture.tracked[image]

		if not tracked then
			return
		end

		local name, scale = texture.resolve(tracked.kind, tracked.base)
		local asset = texture.get(name)
		local specification = texture.specs[name]

		if asset and specification then
			image.Image = asset
			image.SliceCenter = specification.slice
			image.SliceScale = scale
		end
	end

	function texture.setRadius()
		refresh.run("texradius", texture.retarget, function()
			for image in environment.pairs(texture.tracked) do
				texture.retarget(image)
			end
		end)
	end

	function texture.cleanup()
		environment.pcall(function()
			if not environment.listfiles or not environment.delfile or not environment.isfolder
				or not environment.isfolder(texture.folder) then
				return
			end

			for _, path in environment.ipairs(environment.listfiles(texture.folder)) do
				if path:match("_v%d+%.png$") and not path:match("_" .. texture.version .. "%.png$") then
					environment.pcall(environment.delfile, path)
				end
			end
		end)
	end

	function texture.preload()
		if texture.preloading then
			return
		end

		texture.preloading = true
		texture.cleanup()
		environment.task.spawn(function()
			for name in environment.pairs(texture.specs) do
				environment.pcall(texture.get, name)
				environment.task.wait()
			end

			for kind in environment.pairs(texture.kinds) do
				for _, radius in environment.ipairs(texture.buckets) do
					environment.pcall(texture.get, kind .. "@" .. radius)
					environment.task.wait()
				end
			end
		end)
	end

	table.insert(refresh.full, texture.retarget)
	return texture
end

end -- NovaTexture private scope

local NovaWidgets = {}

function NovaWidgets.install(environment, nova)
	local utility = nova.U
	local theme = nova.Theme
	local font = nova.Font
	local icons = nova.Icons
	local textures = nova.Tex

	function nova.label(options)
		local label = utility.new("TextLabel", {
			BackgroundTransparency = 1, FontFace = options.Font or font.Medium(), TextSize = options.Size or 14,
			Text = options.Text or "", TextXAlignment = options.AlignX or environment.Enum.TextXAlignment.Left,
			TextYAlignment = options.AlignY or environment.Enum.TextYAlignment.Center,
			TextTruncate = options.Truncate and environment.Enum.TextTruncate.AtEnd or environment.Enum.TextTruncate.None,
			TextWrapped = options.Wrap or false, RichText = options.Rich or false,
			Size = options.Box or environment.UDim2.new(1, 0, 0, 18), Position = options.Pos or environment.UDim2.new(),
			AnchorPoint = options.Anchor or environment.Vector2.zero, AutomaticSize = options.Auto or environment.Enum.AutomaticSize.None,
			ZIndex = options.Z or 1, Name = options.Name or "Label", Parent = options.Parent,
		})
		theme.bind(label, "TextColor3", options.Color or "Text")
		return label
	end

	function nova.icon(options)
		local size = options.Size or 18
		local icon = utility.new("ImageLabel", {
			BackgroundTransparency = 1, Size = environment.UDim2.fromOffset(size, size),
			Position = options.Pos or environment.UDim2.new(), AnchorPoint = options.Anchor or environment.Vector2.zero,
			Visible = false, ZIndex = options.Z or 1, Name = options.Name or "Icon", Parent = options.Parent,
		})
		theme.bind(icon, "ImageColor3", options.Color or "Text")
		icons.apply(icon, options.Icon)
		return icon
	end

	function nova.tile(parent, options)
		local image = textures.image(parent, options.Tex or "tile9", {
			Name = options.Name or "Tile", Size = options.Size or environment.UDim2.fromOffset(30, 30),
			Position = options.Pos or environment.UDim2.new(), AnchorPoint = options.Anchor or environment.Vector2.zero,
			SliceScale = options.SliceScale or 0.5, ImageTransparency = options.Alpha or 0, ZIndex = options.Z or 1,
		})

		if image then
			theme.bind(image, "ImageColor3", options.Color or "Accent")
			return image, true
		end

		local frame = utility.new("Frame", {
			Name = options.Name or "Tile", Size = options.Size or environment.UDim2.fromOffset(30, 30),
			Position = options.Pos or environment.UDim2.new(), AnchorPoint = options.Anchor or environment.Vector2.zero,
			BorderSizePixel = 0, BackgroundTransparency = options.Alpha or 0, ZIndex = options.Z or 1, Parent = parent,
		})
		utility.corner(frame, options.Radius or environment.math.floor(15 * (options.SliceScale or 0.5) + 0.5))
		theme.bind(frame, "BackgroundColor3", options.Color or "Accent")
		return frame, false
	end

	function nova.keyName(key)
		if environment.typeof(key) ~= "EnumItem" then return "None" end
		if key.EnumType == environment.Enum.UserInputType then
			if key == environment.Enum.UserInputType.MouseButton1 then return "MB1" end
			if key == environment.Enum.UserInputType.MouseButton2 then return "MB2" end
			if key == environment.Enum.UserInputType.MouseButton3 then return "MB3" end
			return "None"
		end
		local names = {LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt",
			RightAlt = "RAlt", Backquote = "`", Return = "Enter", F13 = "MB4", F14 = "MB5"}
		return names[key.Name] or key.Name
	end

	function nova.keyHeld(key)
		if environment.typeof(key) ~= "EnumItem" then return false end
		local ok, held = environment.pcall(function()
			if key.EnumType == environment.Enum.UserInputType then return nova.Services.UserInputService:IsMouseButtonPressed(key) end
			return nova.Services.UserInputService:IsKeyDown(key)
		end)
		return ok and held or false
	end

	function nova.bindHit(window, event, key, processed)
		if environment.typeof(key) ~= "EnumItem" then return false end
		if key.EnumType == environment.Enum.UserInputType then
			if event.UserInputType ~= key or processed then return false end
			if window and window.PointerOverUI and window:PointerOverUI() then return false end
			return true
		end
		return event.UserInputType == environment.Enum.UserInputType.Keyboard and event.KeyCode == key
	end

	function nova.bindChip(window, parent, key, onChanged, order)
		local chip = utility.new("TextButton", {Name = "Bind", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = environment.UDim2.fromOffset(36, 26), LayoutOrder = order or 5, ZIndex = 3, Parent = parent})
		local base = utility.new("Frame", {Name = "Base", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0,
			BackgroundColor3 = environment.Color3.fromRGB(6, 7, 10), ZIndex = 3, Parent = chip})
		utility.corner(base, 7)
		local white = environment.Color3.new(1, 1, 1)
		local baseStroke = utility.stroke(base, white, 1, 0.9)
		theme.bind(baseStroke, "Color", "Glass")
		local face = utility.new("Frame", {Name = "Face", Size = environment.UDim2.new(1, 0, 0, 23), BorderSizePixel = 0, ZIndex = 4, Parent = chip})
		theme.bind(face, "BackgroundColor3", "Elevated")
		utility.corner(face, 7)
		utility.new("UIGradient", {Color = environment.ColorSequence.new(white, environment.Color3.fromRGB(196, 199, 208)), Rotation = 90, Parent = face})
		local faceStroke = utility.stroke(face, white, 1, 0.82)
		theme.bind(faceStroke, "Color", "Glass")
		local label = nova.label({Parent = face, Text = "", Font = font.Semi(), Size = 12, Box = environment.UDim2.fromScale(1, 1),
			AlignX = environment.Enum.TextXAlignment.Center, Color = "Muted", Z = 5})
		local bind = {Key = key, Chip = chip}
		local listening, pulse, hovering = false, nil, false
		local function update()
			local text = environment.typeof(bind.Key) == "EnumItem" and nova.keyName(bind.Key) or "вЂ”"
			chip.Size = environment.UDim2.fromOffset(math.max(34, math.floor((utf8.len(text) or #text) * 7.4 + 18)), 26)
			label.Text = text
		end
		update()
		local function stop()
			listening = false
			environment.task.defer(function() if not listening then window.Listening = false end end)
			if pulse then pulse:Cancel(); pulse = nil end
			nova.paint(faceStroke, "Color", "Glass", "Quick")
			nova.Motion.tween(faceStroke, "Quick", {Transparency = hovering and 0.6 or 0.82})
			nova.paint(baseStroke, "Color", "Glass", "Quick")
			nova.Motion.tween(baseStroke, "Quick", {Transparency = 0.9})
			nova.paint(label, "TextColor3", bind.Key and "Text" or "Faint", "Quick")
			update()
		end
		nova.paint(label, "TextColor3", bind.Key and "Text" or "Faint", environment.TweenInfo.new(0))
		bind.Set = function(value, silent)
			bind.Key = value
			if listening then update() else stop() end
			if not silent then nova.safe(onChanged, value) end
		end
		chip.MouseEnter:Connect(function()
			hovering = true
			if not listening then nova.Motion.tween(faceStroke, "Quick", {Transparency = 0.6}) end
		end)
		utility.leave(chip, function()
			hovering = false
			if not listening then nova.Motion.tween(faceStroke, "Quick", {Transparency = 0.82}) end
			nova.Motion.tween(face, "Quick", {Position = environment.UDim2.fromOffset(0, 0), Size = environment.UDim2.new(1, 0, 0, 23)})
		end)
		chip.MouseButton1Down:Connect(function() nova.Motion.tween(face, "Quick", {Position = environment.UDim2.fromOffset(0, 2), Size = environment.UDim2.new(1, 0, 0, 21)}) end)
		chip.MouseButton1Up:Connect(function() nova.Motion.tween(face, "PopSmall", {Position = environment.UDim2.fromOffset(0, 0), Size = environment.UDim2.new(1, 0, 0, 23)}) end)
		chip.MouseButton2Click:Connect(function()
			if listening or bind.Key == nil or environment.os.clock() - (bind.BoundAt or 0) < 0.3 then return end
			nova.Sound.play("tick")
			bind.Key = nil
			stop()
			nova.safe(onChanged, nil)
		end)
		chip.MouseButton1Click:Connect(function()
			if listening or environment.os.clock() - (bind.BoundAt or 0) < 0.3 then return end
			nova.Sound.play("click")
			listening = true
			label.Text = nova.tr("Press") .. " вЂ¦"
			chip.Size = environment.UDim2.fromOffset(66, 26)
			nova.paint(label, "TextColor3", "Accent", "Quick")
			nova.paint(faceStroke, "Color", "Accent", "Quick")
			nova.paint(baseStroke, "Color", "Accent", "Quick")
			nova.Motion.tween(baseStroke, "Quick", {Transparency = 0.55})
			local info = environment.TweenInfo.new(0.55, environment.Enum.EasingStyle.Sine, environment.Enum.EasingDirection.InOut, -1, true)
			pulse = nova.Services.TweenService:Create(faceStroke, info, {Transparency = 0.15})
			pulse:Play()
			environment.task.defer(function() window.Listening = true end)
		end)
		utility.connect(nova.Services.UserInputService.InputBegan, function(event)
			if not listening or not window.Listening then return end
			local value
			if event.UserInputType == environment.Enum.UserInputType.Keyboard then
				if event.KeyCode == environment.Enum.KeyCode.Escape then stop(); return end
				if event.KeyCode == environment.Enum.KeyCode.Backspace or event.KeyCode == environment.Enum.KeyCode.Delete then
					bind.Key = nil
					stop()
					nova.safe(onChanged, nil)
					return
				end
				value = event.KeyCode
			end
			if event.UserInputType == environment.Enum.UserInputType.Touch then stop(); return end
			if event.UserInputType == environment.Enum.UserInputType.MouseButton1 or event.UserInputType == environment.Enum.UserInputType.MouseButton2
				or event.UserInputType == environment.Enum.UserInputType.MouseButton3 then
				value = event.UserInputType
				bind.BoundAt = environment.os.clock()
			end
			if value then
				bind.Key = value
				stop()
				nova.Sound.play("tick")
				nova.safe(onChanged, value)
			end
		end, window.Conns)
		return bind
	end

	function nova.field(parent, options)
		local field = utility.new(options.Class or "Frame", {Name = options.Name or "Field", Size = options.Size,
			BorderSizePixel = 0, LayoutOrder = options.Order or 10, ZIndex = options.Z or 2, Parent = parent})
		if options.Class == "TextButton" then field.Text, field.AutoButtonColor = "", false end
		theme.bind(field, "BackgroundColor3", "Elevated")
		utility.corner(field, options.Radius or 8)
		local white = environment.Color3.new(1, 1, 1)
		utility.new("UIGradient", {Color = environment.ColorSequence.new(white, environment.Color3.fromRGB(190, 193, 202)), Rotation = 90, Parent = field})
		local stroke = utility.stroke(field, white, 1, 0.84)
		theme.bind(stroke, "Color", "Glass")
		return field, stroke
	end

	function nova.paint(object, property, role, preset)
		local properties = theme.registry[object]

		if not properties then
			properties = {}
			theme.registry[object] = properties
		end

		properties[property] = role
		nova.Motion.tween(object, preset or "Base", {[property] = theme.resolve(role)})
	end
end

local NovaSection = {}
local NovaTab = {}
local NovaWindow = {}

local BACKGROUND_PATTERNS = {
	Grid = {tex = "grid", alpha = 0.955}, Dots = {tex = "dots", alpha = 0.9},
	Diagonal = {tex = "diag", alpha = 0.965}, Crosses = {tex = "crosses", alpha = 0.93},
	Scanlines = {tex = "scan", alpha = 0.955},
}

function NovaWindow.initialize(environment, nova, options)
	options = options or {}
	local window = setmetatable({}, nova.WindowClass)
	window.Tabs = {}
	window.TabList = {}
	window.Groups = {}
	window.Conns = {}
	window.Popups = {}
	window.Floats = {}
	window.Key = options.Key or environment.Enum.KeyCode.RightControl
	window.Size = options.Size or environment.Vector2.new(860, 620)
	window.MinSize = options.MinSize or environment.Vector2.new(660, 420)
	window.IsOpen = false
	window.FloatZ = 10
	window.Initial = environment.tostring(options.Initial or environment.string.sub(options.Title or "N", 1, 1))
	window.LogoAsset = options.Logo
	window.LogoGlow = options.LogoGlow

	table.insert(nova.Windows, window)
	nova.U.startSweep()

	local guiName = options.GuiName or "NovaUI"
	local state = nova.Store.new(options.StateFile or "PulseHub/nova/ui_" .. guiName .. ".json")
	window.State = state
	window.StateDefaults = environment.type(options.StateDefaults) == "table" and options.StateDefaults or nil
	NovaWindow._mergeDefaults(environment, nova.Services.HttpService, state, options.StateDefaults)

	local savedSize = state.get("size", nil)

	if environment.type(savedSize) == "table" and environment.tonumber(savedSize[1]) and environment.tonumber(savedSize[2]) then
		window.Size = environment.Vector2.new(
			environment.math.max(window.MinSize.X, environment.tonumber(savedSize[1])),
			environment.math.max(window.MinSize.Y, environment.tonumber(savedSize[2]))
		)
	end

	NovaWindow._applyTheme(environment, nova.Theme, window, state, options)
	nova.U.setRadius(environment.tonumber(state.get("radius", options.Radius or 1)) or 1)
	nova.Font.setFamily(state.get("font", options.Font or "Builder Sans"))
	nova.Font.setScale(environment.tonumber(state.get("textScale", 1)) or 1)
	nova.Sound.enabled = state.get("sounds", true) ~= false
	nova.Sound.volume = environment.tonumber(state.get("volume", 0.5)) or 0.5
	nova.Motion.enabled = state.get("motion", true) ~= false

	window.DefaultScale = environment.math.clamp(environment.tonumber(options.Scale) or 1, 0.6, 1.5)
	window.UserScale = environment.math.clamp(environment.tonumber(state.get("scale", window.DefaultScale)) or window.DefaultScale, 0.6, 1.5)
	window.BlurEnabled = state.get("blur", options.Blur == true) == true
	window.BgStyle = state.get("bgStyle", options.Background or "Aurora")
	window.CardStyle = state.get("cardStyle", options.CardStyle or "Glass")
	window.BgIntensity = environment.math.clamp(environment.tonumber(state.get("bgIntensity", 1)) or 1, 0, 1.5)
	window.Opacity = environment.math.clamp(environment.tonumber(state.get("opacity", 1)) or 1, 0.5, 1)
	window.TooltipsOn = state.get("tooltips", true) ~= false
	window.LauncherOn = state.get("launcher", options.Launcher ~= false) ~= false
	window.BaseSize = window.Size
	window.AutoFit = state.get("autoFit", options.AutoFit ~= false) ~= false
	window.ScaleHooks = {}
	window.ScreenFactor = 1
	window.OverlayScale = 1

	local forceTouch = false
	environment.pcall(function()
		forceTouch = environment.getgenv().NOVA_FORCE_TOUCH == true
	end)

	local input = nova.Services.UserInputService
	window.IsTouch = forceTouch or input.TouchEnabled and not input.KeyboardEnabled

	if window.IsTouch then
		window.LauncherOn = true
	end

	local touchSize = state.get("touchSize", nil)

	if window.IsTouch and environment.type(touchSize) == "table"
		and environment.tonumber(touchSize[1]) and environment.tonumber(touchSize[2]) then
		window.TouchSize = environment.Vector2.new(environment.tonumber(touchSize[1]), environment.tonumber(touchSize[2]))
	end

	return window
end

function NovaWindow.createRoot(environment, nova, window, options)
	local utility = nova.U
	local textures = nova.Tex
	local guiName = options.GuiName or "NovaUI"

	nova.Icons.load()
	nova.Sound.preload()
	textures.preload()

	local gui = utility.new("ScreenGui", {
		Name = guiName, IgnoreGuiInset = true, ResetOnSpawn = false,
		ZIndexBehavior = environment.Enum.ZIndexBehavior.Sibling, DisplayOrder = 999999,
	})
	utility.protect(gui)
	gui.Parent = options.Parent or utility.hostGui()
	window.Gui = gui

	local parking = utility.new("ScreenGui", {Name = guiName .. "_Parked", Enabled = false, ResetOnSpawn = false})
	utility.protect(parking)
	parking.Parent = gui.Parent
	window.Parking = parking
	nova.Sound.host = gui

	local position = environment.UDim2.fromScale(0.5, 0.5)
	local saved = window.State.get(window.IsTouch and "touchPos" or "winPos", nil)

	if environment.type(saved) == "table" and environment.tonumber(saved[1]) and environment.tonumber(saved[2]) then
		position = environment.UDim2.new(0.5, environment.math.floor(environment.tonumber(saved[1])),
			0.5, environment.math.floor(environment.tonumber(saved[2])))
	end

	local root = utility.new("Frame", {
		Name = "Root", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = position,
		Size = environment.UDim2.fromOffset(window.Size.X, window.Size.Y),
		BackgroundTransparency = 1, Visible = false, ZIndex = 1, Parent = gui,
	})
	window.Root = root
	window.Scale = utility.new("UIScale", {Parent = root})
	window.WindowShadow = textures.image(root, "shadow9", {
		Name = "WindowShadow", Position = environment.UDim2.fromOffset(-40, -30),
		Size = environment.UDim2.new(1, 80, 1, 90), SliceScale = 1.2, ImageTransparency = 0.45, ZIndex = 0,
	})

	local canvas = utility.new("CanvasGroup", {
		Name = "Window", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0,
		GroupTransparency = 1, BackgroundTransparency = 1 - window.Opacity, ZIndex = 1, Parent = root,
	})
	nova.Theme.bind(canvas, "BackgroundColor3", "Background")
	utility.corner(canvas, 14)
	window.Win = canvas
end

function NovaWindow.createContent(environment, nova, window, options)
	local utility, theme, textures = nova.U, nova.Theme, nova.Tex
	local gui, canvas = window.Gui, window.Win
	window:_buildBackdrop()
	window:_buildSidebar(options)

	local width = window.SidebarWidth
	local main = utility.new("Frame", {
		Name = "Main", Position = environment.UDim2.fromOffset(width, 0), Size = environment.UDim2.new(1, -width, 1, 0),
		BackgroundTransparency = 1, ZIndex = 1, Parent = canvas,
	})
	window.Main = main
	local header = utility.new("Frame", {
		Name = "Header", Size = environment.UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = main,
	})
	window.Header = header
	window.HeaderTitle = nova.label({Parent = header, Text = "", Font = nova.Font.Bold(), Size = 21,
		Pos = environment.UDim2.fromOffset(24, 13), Box = environment.UDim2.new(1, -110, 0, 26), Truncate = true})
	window.HeaderDesc = nova.label({Parent = header, Text = "", Font = nova.Font.Medium(), Size = 12,
		Pos = environment.UDim2.fromOffset(24, 39), Box = environment.UDim2.new(1, -110, 0, 14), Color = "Muted", Truncate = true})

	local line = utility.new("Frame", {Name = "Line", Position = environment.UDim2.fromOffset(20, 63), Size = environment.UDim2.new(1, -40, 0, 1),
		BorderSizePixel = 0, BackgroundTransparency = 0.88, Parent = header})
	theme.bind(line, "BackgroundColor3", "Glass")
	local keypoint = environment.NumberSequenceKeypoint.new
	utility.new("UIGradient", {Transparency = environment.NumberSequence.new({keypoint(0, 1), keypoint(0.15, 0), keypoint(0.85, 0), keypoint(1, 1)}), Parent = line})
	window:_buildClose(header)
	window.Body = utility.new("Frame", {Name = "Body", Position = environment.UDim2.fromOffset(0, 64), Size = environment.UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = main})

	local resize = utility.new("TextButton", {Name = "Resize", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		AnchorPoint = environment.Vector2.new(1, 1), Position = environment.UDim2.new(1, -5, 1, -5), Size = environment.UDim2.fromOffset(18, 18), ZIndex = 40, Parent = canvas})
	for column = 0, 2 do
		for row = 0, 2 - column do
			local dot = utility.new("Frame", {Size = environment.UDim2.fromOffset(2, 2), Position = environment.UDim2.fromOffset(13 - column * 4, 13 - row * 4),
				BorderSizePixel = 0, ZIndex = 40, Parent = resize})
			theme.bind(dot, "BackgroundColor3", "Faint")
			utility.corner(dot, environment.UDim.new(1, 0))
		end
	end

	local rim = textures.image(canvas, "rim9", {Name = "WindowRim", Size = environment.UDim2.fromScale(1, 1), SliceScale = 1, ImageTransparency = 0.55, ZIndex = 45})
	if rim then
		theme.bind(rim, "ImageColor3", "Glass")
	end

	window.FloatLayer = utility.new("Frame", {Name = "Floats", BackgroundTransparency = 1, Size = environment.UDim2.fromScale(1, 1), ZIndex = 5, Visible = true, Parent = gui})
	window.FloatScale = utility.new("UIScale", {Parent = window.FloatLayer})
	window.PopLayer = utility.new("Frame", {Name = "Popups", BackgroundTransparency = 1, Size = environment.UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui})
	window.PopScale = utility.new("UIScale", {Parent = window.PopLayer})
	window.Overlay = window.PopLayer
	local catcher = utility.new("TextButton", {Name = "Catcher", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = environment.UDim2.fromScale(1, 1), Visible = false, ZIndex = 1, Parent = window.PopLayer})
	catcher.MouseButton1Click:Connect(function() window:ClosePopups() end)
	catcher.MouseButton2Click:Connect(function() window:ClosePopups() end)
	window.Catcher = catcher
	window:_drag(header)
	window:_drag(window.BrandFrame)
	window:_resize(resize)

	if window.IsTouch then
		resize.Size = environment.UDim2.fromOffset(30, 30)
		resize.Position = environment.UDim2.new(1, -4, 1, -4)
		resize.BackgroundTransparency = 0.35
		theme.bind(resize, "BackgroundColor3", "Elevated")
		utility.corner(resize, 9)
		for _, child in ipairs(resize:GetChildren()) do
			if child:IsA("Frame") then
				child.Size = environment.UDim2.fromOffset(3, 3)
				child.Position = environment.UDim2.fromOffset(child.Position.X.Offset + 8, child.Position.Y.Offset + 8)
				theme.bind(child, "BackgroundColor3", "Text")
			end
		end
	end

	local toasts = utility.new("Frame", {Name = "Toasts", AnchorPoint = environment.Vector2.new(1, 1), Position = environment.UDim2.new(1, -18, 1, -20),
		Size = environment.UDim2.new(0, 300, 1, -40), BackgroundTransparency = 1, ZIndex = 30, Parent = gui})
	window.ToastScale = utility.new("UIScale", {Parent = toasts})
	window.Toasts = toasts
	window.ToastList = {}
	local tip = utility.new("Frame", {Name = "Tooltip", Size = environment.UDim2.fromOffset(10, 28), AutomaticSize = environment.Enum.AutomaticSize.X,
		BorderSizePixel = 0, Visible = false, ZIndex = 200, Parent = gui})
	theme.bind(tip, "BackgroundColor3", "Elevated")
	utility.corner(tip, 8)
	local tipRim = textures.image(tip, "rim9", {Position = environment.UDim2.fromOffset(-11, 0), Size = environment.UDim2.new(1, 22, 1, 0),
		SliceScale = 0.57, ImageTransparency = 0.5, ZIndex = 201})
	if tipRim then
		theme.bind(tipRim, "ImageColor3", "Glass")
	else
		theme.bind(utility.stroke(tip, environment.Color3.new(1, 1, 1), 1, 0.88), "Color", "Glass")
	end
	utility.pad(tip, 0, 11, 0, 11)
	window.TipLabel = nova.label({Parent = tip, Text = "", Font = nova.Font.Medium(), Size = 12, Box = environment.UDim2.new(0, 0, 1, 0),
		Auto = environment.Enum.AutomaticSize.X, Z = 202, Color = "Text"})
	window.Tip = tip
	local tipScale = utility.new("UIScale", {Parent = tip})
	window:OnScreenScale(function(value)
		if not tip.Parent then
			return false
		end

		tipScale.Scale = value
	end)
end

function NovaWindow.create(environment, nova, options)
	options = options or {}
	local window = NovaWindow.initialize(environment, nova, options)
	NovaWindow.createRoot(environment, nova, window, options)
	NovaWindow.createContent(environment, nova, window, options)
	window:_launcher(options)
	window:_input()
	window:_autoScale()
	environment.pcall(function() window:_buildDecor() end)
	window:_applyBackground()
	nova.Theme.onChange(function(role)
		if role ~= "Accent" or window.CardStyle ~= "Tinted" or window.Destroyed then return end
		for _, tab in ipairs(window.TabList) do
			for _, section in ipairs(tab.Sections) do
				environment.pcall(function() window:_applyCardStyle(section) end)
			end
		end
	end)
	if window._initCards then window:_initCards() end
	local key = window.State.get("menuKey", nil)
	if type(key) == "string" and environment.Enum.KeyCode[key] then window.Key = environment.Enum.KeyCode[key] end
	window:_syncFooter()
	if window.SetWatermark and window.State.get("watermark", false) == true then window:SetWatermark(true) end
	if window.SetKeybindList and window.State.get("keybindList", window.IsTouch == true) == true then window:SetKeybindList(true) end
	return window
end

function NovaWindow._mergeDefaults(environment, json, state, defaults)
	if environment.type(defaults) ~= "table" then
		return
	end

	for key, value in environment.pairs(defaults) do
		if state.data[key] ~= nil then
			continue
		end

		if environment.type(value) == "table" then
			local ok, copied = environment.pcall(function()
				return json:JSONDecode(json:JSONEncode(value))
			end)
			state.data[key] = ok and copied or value
			continue
		end

		state.data[key] = value
	end
end

function NovaWindow._applyTheme(environment, theme, window, state, options)
	local accent = state.get("accent", nil)

	if environment.type(accent) == "string" then
		environment.pcall(function()
			theme.set("Accent", environment.Color3.fromHex(accent))
		end)
	end

	if environment.type(accent) ~= "string" and options.Accent then
		theme.set("Accent", options.Accent)
	end

	local base = state.get("base", options.Base or "Deep Sea")

	if base ~= "Midnight" then
		theme.setBase(base)
	end

	local panel = state.get("panel", nil)

	if environment.type(panel) ~= "string" then
		return
	end

	local ok, color = environment.pcall(environment.Color3.fromHex, panel)

	if ok and environment.typeof(color) == "Color3" then
		window.PanelColor = color
		theme.setMany(theme.panelFrom(color))
		theme.base = "Custom"
	end
end

function NovaWindow.keybindSnapshot(environment, window)
	local entries, rows, seen = {}, {}, {}
	local bound, activeCount = 0, 0

	for _, entry in window.KeybindEntries or {} do
		local ok, alive = true, true
		if entry.alive then ok, alive = pcall(entry.alive) end
		if ok and alive == false then continue end
		table.insert(entries, entry)
	end
	window.KeybindEntries = entries

	for index, entry in entries do
		local keyOk, key = pcall(entry.key)
		if not keyOk or environment.typeof(key) ~= "EnumItem" then key = nil end
		local nameOk, value = pcall(entry.name)
		local name = nameOk and tostring(value) or ""
		local captured = window.KbCap and window.KbCap.entry == entry
		local identity = window.IsTouch and name or name .. "|" .. (key and tostring(key) or (window.KbEdit and "" or "-"))
		local show = false
		if window.IsTouch then show = type(entry.toggle) == "function" and name ~= "" and not seen[identity] end
		if not window.IsTouch then
			show = captured or key ~= nil and not seen[identity] or window.KbEdit and entry.set ~= nil and name ~= "" and not seen[identity]
		end
		if not show then continue end

		seen[identity] = true
		local activeOk, active = pcall(entry.active)
		active = activeOk and not not active
		local hasKey = key ~= nil or window.IsTouch
		if hasKey then
			bound += 1
			if active then activeCount += 1 end
		end
		table.insert(rows, {entry = entry, name = name, key = key, on = active, order = (hasKey and 0 or 100000) + index})
	end
	return rows, activeCount, bound
end

function NovaWindow.createClass(environment, nova)
	local class = {}
	class.__index = class
	class.HEADER = 64
	class.BackgroundStyles = {"Halloween", "Aurora", "Grid", "Dots", "Diagonal", "Crosses", "Scanlines", "Noise", "Plain"}
	class.HalloweenAccent = "ff7a1a"
	class.HalloweenEmber = environment.Color3.fromRGB(150, 46, 14)
	class.HalloweenArt = {
		pattern = "rbxthumb://type=Asset&id=103789687660312&w=420&h=420",
		web = "rbxthumb://type=Asset&id=18223787274&w=420&h=420",
		flock = "rbxthumb://type=Asset&id=79966766029610&w=420&h=420",
		bat = "rbxthumb://type=Asset&id=9461132204&w=420&h=420",
		pumpkin = "rbxthumb://type=Asset&id=6955343878&w=420&h=420",
		moon = "rbxthumb://type=Asset&id=5385993191&w=420&h=420",
		sheet = "rbxthumb://type=Asset&id=71103752828050&w=420&h=420",
		pumpkinA = "rbxthumb://type=Asset&id=1103904516&w=420&h=420",
		pumpkinB = "rbxthumb://type=Asset&id=110396402211452&w=420&h=420",
		witchMoon = "rbxthumb://type=Asset&id=4019375628&w=420&h=420",
		spider = "rbxthumb://type=Asset&id=79296253808483&w=420&h=420",
		fog = "rbxthumb://type=Asset&id=4770542480&w=420&h=420",
	}

	class.SIDEBAR_EXPANDED = 228
	class.SIDEBAR_COLLAPSED = 64
	class.Densities = {"Comfortable", "Compact"}

	function class.applyDensity(window)
		if window.Density == "Compact" then
			window.RowH, window.CapH, window.TileS, window.LabelX = 31, 22, 22, 36
			return
		end

		window.Density = "Comfortable"
		window.RowH, window.CapH, window.TileS, window.LabelX = 40, 30, 30, 46
	end

	function class._ensureGroup(window)
		if window.CurGroup then
			return window.CurGroup
		end

		local group = {Key = "_", Tabs = {}, Collapsed = false}
		table.insert(window.Groups, group)
		window.CurGroup = group
		return group
	end

	function class._styleTab(window, tab, selected, animated)
		if not tab.Row then
			return
		end

		local tween = nova.Motion.tween
		local preset = animated and "Base" or environment.TweenInfo.new(0)
		if selected then
			nova.paint(tab.Tile, tab.TileProp, "Accent", preset)
			tween(tab.Tile, preset, {[tab.TileAlphaProp] = 0})
			nova.paint(tab.IconImg, "ImageColor3", "OnAccent", preset)
			nova.paint(tab.Label, "TextColor3", "Text", preset)
			tween(tab.Bg, preset, {BackgroundTransparency = window.SidebarCollapsed and 1 or 0.42})
			nova.paint(tab.BgStroke, "Color", "Accent", preset)
			tween(tab.BgStroke, preset, {Transparency = window.SidebarCollapsed and 1 or 0.72})
			if tab.Glow then tween(tab.Glow, preset, {ImageTransparency = 0.5}) end
			return
		end

		nova.paint(tab.Tile, tab.TileProp, "Elevated", preset)
		local transparency = tab.Hover and 0.05 or 0.4
		if window.SidebarCollapsed then transparency = 1 end
		tween(tab.Tile, preset, {[tab.TileAlphaProp] = transparency})
		nova.paint(tab.IconImg, "ImageColor3", tab.Hover and "Text" or "Muted", preset)
		nova.paint(tab.Label, "TextColor3", tab.Hover and "Text" or "Muted", preset)
		tween(tab.Bg, preset, {BackgroundTransparency = tab.Hover and 0.6 or 1})
		tween(tab.BgStroke, preset, {Transparency = 1})
		if tab.Glow then tween(tab.Glow, preset, {ImageTransparency = 1}) end
	end

	function class._layoutTabRow(window, tab, y, hidden, animated, height)
		local row = tab.Row
		tab.TargetY = y
		tab.RowToken = (tab.RowToken or 0) + 1
		local token = tab.RowToken
		local position = environment.UDim2.fromOffset(8, y)
		local size = environment.UDim2.new(1, -16, 0, height)
		if not animated then
			row.Position = position
			row.Size = size
			row.GroupTransparency = hidden and 1 or 0
			row.Visible = not hidden
			return
		end

		if not hidden then row.Visible = true end
		local info = environment.TweenInfo.new(0.34, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
		nova.Motion.tween(row, info, {Position = position, Size = size, GroupTransparency = hidden and 1 or 0})
		if hidden then
			environment.task.delay(0.36, function()
				if tab.RowToken == token then row.Visible = false end
			end)
		end
	end

	function class._layoutTabs(window, animated)
		if not window.TabCanvas then
			return
		end

		animated = nova.Motion.enabled and animated or false
		local collapsed = window.SidebarCollapsed
		local height = collapsed and 36 or window.RowH
		local labels = window.GroupLabels ~= false
		local y = 4
		local firstGroup
		for _, group in ipairs(window.Groups) do
			if group.Row then firstGroup = group; break end
		end

		for _, group in ipairs(window.Groups) do
			if group.Row and not labels then
				group.Row.Visible = false
				group.Row.Position = environment.UDim2.fromOffset(8, y)
				group.Row.Size = environment.UDim2.new(1, -16, 0, 0)
			end
			if group.Row and labels then
				group.Row.Visible = true
				local captionHeight = collapsed and (group == firstGroup and 6 or 12) or window.CapH
				group.Row.Position = environment.UDim2.fromOffset(8, y)
				local size = environment.UDim2.new(1, -16, 0, captionHeight)
				if animated then
					local info = environment.TweenInfo.new(0.34, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
					nova.Motion.tween(group.Row, info, {Position = environment.UDim2.fromOffset(8, y), Size = size})
				else
					group.Row.Size = size
				end
				y += captionHeight
			end

			local hidden = group.Collapsed and not collapsed and labels
			local groupY = y
			for _, tab in ipairs(group.Tabs) do
				if tab ~= window.DraggingTab then
					window:_layoutTabRow(tab, hidden and groupY or y, hidden, animated, height)
				end
				if not hidden then y += height + 2 end
			end
			if #group.Tabs > 0 and not hidden and labels then y += 4 end
		end
		window.TabCanvas.Size = environment.UDim2.new(1, 0, 0, y + 6)
	end

	function class.SetGroupLabels(window, enabled)
		enabled = enabled ~= false
		if enabled == (window.GroupLabels ~= false) then
			return
		end

		window.GroupLabels = enabled
		window.State.set("groupLabels", enabled)
		if enabled and not window.SidebarCollapsed then
			for _, group in ipairs(window.Groups) do
				if group.Row then
					group.Label.TextTransparency, group.Chev.ImageTransparency = 1, 1
					nova.Motion.tween(group.Label, "Base", {TextTransparency = 0})
					nova.Motion.tween(group.Chev, "Base", {ImageTransparency = 0})
				end
			end
		end
		window:_layoutTabs(true)
		if window.OnGroupLabels then environment.pcall(window.OnGroupLabels, enabled) end
	end

	function class.SetGroupCollapsed(window, group, collapsed)
		if type(group) == "string" then
			for _, item in ipairs(window.Groups) do
				if item.Key == group then group = item; break end
			end
		end
		if type(group) ~= "table" then return end

		group.Collapsed = collapsed and true or false
		local groups = window.State.get("groups", {})
		if type(groups) ~= "table" then groups = {} end
		groups[group.Key] = group.Collapsed or nil
		window.State.data.groups = groups
		window.State.save()
		if group.Chev then nova.Motion.tween(group.Chev, "Base", {Rotation = group.Collapsed and -90 or 0}) end
		window:_layoutTabs(true)
	end

	function class._revealTab(window, tab)
		local scroll, row = window.TabScroll, tab and tab.Row
		if not scroll or not row then return end

		local top = row.Position.Y.Offset
		local bottom = top + row.Size.Y.Offset
		local height = scroll.AbsoluteWindowSize.Y / math.max(window.Scale.Scale, 0.1)
		local current = scroll.CanvasPosition.Y
		local target = current
		if top - 6 < current then
			target = math.max(0, top - 6)
		end
		if top - 6 >= current and bottom + 6 > current + height then
			target = bottom + 6 - height
		end
		if math.abs(target - current) < 1 then return end
		nova.Motion.tween(scroll, "Base", {CanvasPosition = environment.Vector2.new(0, target)})
	end

	function class.SetDensity(window, density)
		if not table.find(class.Densities, density) then return end
		window.Density = density
		window.State.set("density", density)
		class.applyDensity(window)
		if not window.SidebarCollapsed then
			for _, group in ipairs(window.Groups) do
				for _, tab in ipairs(group.Tabs) do
					local size = window.TileS
					nova.Motion.tween(tab.Tile, "Base", {Size = environment.UDim2.fromOffset(size, size)})
					nova.Motion.tween(tab.Label, "Base", {Position = environment.UDim2.fromOffset(window.LabelX, 0), Size = environment.UDim2.new(1, -(window.LabelX + 10), 1, 0)})
					if tab.Glow then nova.Motion.tween(tab.Glow, "Base", {Position = environment.UDim2.new(0, 6 + size / 2, 0.5, 0)}) end
				end
			end
		end
		window:_layoutTabs(true)
	end

	function class.SetSidebarWidth(window, width, immediate)
		nova.trace("SetSidebarWidth")
		local maximum = math.min(340, math.max(188, (window.Size and window.Size.X or 860) - 420))
		width = math.clamp(tonumber(width) or 228, 188, maximum)
		window.ExpandedWidth = width
		if not immediate then window.State.set("sidebarWidth", math.floor(width + 0.5)) end
		if window.OnSidebarWidth then environment.pcall(window.OnSidebarWidth, width) end
		if window.SidebarCollapsed then return end

		window.SidebarWidth = width
		local info = immediate and environment.TweenInfo.new(0) or environment.TweenInfo.new(0.25, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
		nova.Motion.tween(window.Sidebar, info, {Size = environment.UDim2.new(0, width, 1, 0)})
		window.Main.Size = environment.UDim2.new(1, -width, 1, 0)
		nova.Motion.tween(window.Main, info, {Position = environment.UDim2.fromOffset(width, 0)})
		nova.Motion.tween(window.SidebarEdge, info, {Position = environment.UDim2.new(0, width, 0, 0)})
	end

	function class.SetSidebarCollapsed(window, collapsed, immediate)
		collapsed = collapsed and true or false
		if collapsed == window.SidebarCollapsed and not immediate then return end

		window.SidebarCollapsed = collapsed
		window.State.set("sidebarCollapsed", collapsed)
		local width = collapsed and 64 or window.ExpandedWidth
		window.SidebarWidth = width
		local tween = nova.Motion.tween
		local info = immediate and environment.TweenInfo.new(0) or environment.TweenInfo.new(0.38, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
		local fade = immediate and environment.TweenInfo.new(0) or "Base"
		tween(window.Sidebar, info, {Size = environment.UDim2.new(0, width, 1, 0)})
		window.Main.Size = environment.UDim2.new(1, -width, 1, 0)
		tween(window.Main, info, {Position = environment.UDim2.fromOffset(width, 0)})
		tween(window.SidebarEdge, info, {Position = environment.UDim2.new(0, width, 0, 0)})
		window.SidebarEdge.Visible = not collapsed

		local logoX, logoY, searchY, tabTop, footerHeight = 16, 14, 68, 112, 50
		if collapsed then logoX, logoY, searchY, tabTop, footerHeight = 14, 10, 52, 92, 44 end
		tween(window.LogoButton, info, {Position = environment.UDim2.fromOffset(logoX, logoY)})
		tween(window.SearchField.Parent, info, {Position = environment.UDim2.fromOffset(0, searchY)})
		tween(window.TabClip, info, {Position = environment.UDim2.fromOffset(0, tabTop), Size = environment.UDim2.new(1, 0, 1, -(tabTop + footerHeight + 2))})
		tween(window.Footer, info, {Size = environment.UDim2.new(1, 0, 0, footerHeight)})
		tween(window.TitleLabel, fade, {TextTransparency = collapsed and 1 or 0})
		tween(window.SubtitleLabel, fade, {TextTransparency = collapsed and 1 or 0})
		tween(window.FooterText, fade, {TextTransparency = collapsed and 1 or 0})
		tween(window.FooterChip, info, {AnchorPoint = collapsed and environment.Vector2.new(0.5, 0.5) or environment.Vector2.new(1, 0.5),
			Position = collapsed and environment.UDim2.new(0.5, 0, 0.5, 1) or environment.UDim2.new(1, -14, 0.5, 1)})
		window.FoldButton.Visible = not collapsed
		window.SearchField.Parent.Visible = true
		window.SearchField.Visible = not collapsed
		window.SearchTile.Visible = collapsed

		local firstGroup
		for _, group in ipairs(window.Groups) do
			if group.Row then firstGroup = group; break end
		end
		for _, group in ipairs(window.Groups) do
			if group.Row then
				tween(group.Label, fade, {TextTransparency = collapsed and 1 or 0})
				tween(group.Chev, fade, {ImageTransparency = collapsed and 1 or 0})
				tween(group.Line, fade, {BackgroundTransparency = collapsed and (firstGroup == group and 1 or 0.88) or 1})
			end
			for _, tab in ipairs(group.Tabs) do
				local size = collapsed and 32 or window.TileS
				local x = collapsed and 8 or 6
				tab.BgGrad.Enabled, tab.StrokeGrad.Enabled = not collapsed, not collapsed
				tween(tab.Tile, info, {Size = environment.UDim2.fromOffset(size, size), Position = environment.UDim2.new(0, x, 0.5, 0)})
				local iconSize = collapsed and 17 or 16
				tween(tab.IconImg, info, {Size = environment.UDim2.fromOffset(iconSize, iconSize)})
				window:_styleTab(tab, window.Current == tab, not immediate)
				tween(tab.Label, fade, {TextTransparency = collapsed and 1 or 0})
				if tab.Glow then tween(tab.Glow, info, {Position = environment.UDim2.new(0, x + size / 2, 0.5, 0)}) end
				if tab.Badge and collapsed then
					tween(tab.Badge, info, {Size = environment.UDim2.fromOffset(10, 10), Position = environment.UDim2.new(0, x + size - 2, 0.5, -size / 2 + 4)})
					tween(tab.BadgeLabel, fade, {TextTransparency = 1})
					tween(tab.BadgeRing, fade, {Transparency = 0})
				end
				if tab.Badge and not collapsed then
					tween(tab.Badge, info, {Size = environment.UDim2.fromOffset(tab.BadgeWidth, 18), Position = environment.UDim2.new(1, -9, 0.5, 0)})
					tween(tab.BadgeLabel, fade, {TextTransparency = 0})
					tween(tab.BadgeRing, fade, {Transparency = 1})
				end
			end
		end
		window:_layoutTabs(not immediate)
		if window.OnSidebarChanged then environment.pcall(window.OnSidebarChanged, collapsed) end
	end

	function class.ToggleSidebar(window)
		window:SetSidebarCollapsed(not window.SidebarCollapsed)
	end

	function class._buildSidebar(window, options)
		local state, utility, theme = window.State, nova.U, nova.Theme
		local collapsed = state.get("sidebarCollapsed", nil)
		if collapsed == nil then
			local camera = environment.workspace.CurrentCamera
			collapsed = camera ~= nil and camera.ViewportSize.X < 760
		end

		window.SidebarCollapsed = collapsed == true
		window.Density = state.get("density", options.Density or "Comfortable")
		class.applyDensity(window)
		window.GroupLabels = state.get("groupLabels", true) ~= false
		window.DefaultSidebarWidth = math.clamp(tonumber(options.SidebarWidth) or 228, 188, 340)
		window.ExpandedWidth = math.clamp(tonumber(state.get("sidebarWidth", window.DefaultSidebarWidth)) or window.DefaultSidebarWidth, 188, 340)
		window.SidebarWidth = window.SidebarCollapsed and 64 or window.ExpandedWidth
		local sidebar = utility.new("Frame", {Name = "Sidebar", Size = environment.UDim2.new(0, window.SidebarWidth, 1, 0), BorderSizePixel = 0,
			BackgroundTransparency = 0.3 + (1 - window.Opacity) * 0.7, ClipsDescendants = true, ZIndex = 2, Parent = window.Win})
		theme.bind(sidebar, "BackgroundColor3", "Sidebar")
		window.Sidebar = sidebar
		local edge = utility.new("Frame", {Name = "Edge", AnchorPoint = environment.Vector2.new(1, 0), Position = environment.UDim2.fromScale(1, 0),
			Size = environment.UDim2.new(0, 1, 1, 0), BorderSizePixel = 0, BackgroundTransparency = 0.84, ZIndex = 3, Parent = sidebar})
		theme.bind(edge, "BackgroundColor3", "Glass")
		local keypoint = environment.NumberSequenceKeypoint.new
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new({keypoint(0, 1), keypoint(0.1, 0), keypoint(0.9, 0), keypoint(1, 1)}), Rotation = 90, Parent = edge})
		local brand = utility.new("Frame", {Name = "Brand", Size = environment.UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, ZIndex = 3, Parent = sidebar})
		window.BrandFrame = brand
		local logo = utility.new("TextButton", {Name = "Logo", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = environment.UDim2.fromOffset(window.SidebarCollapsed and 14 or 16, window.SidebarCollapsed and 10 or 14),
			Size = environment.UDim2.fromOffset(36, 36), ZIndex = 4, Parent = brand})
		window.LogoButton = logo
		local glow = nova.Tex.image(logo, "glow", {Name = "Glow", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromOffset(96, 96), ImageTransparency = 0.6, ZIndex = 4})
		if glow and options.Logo then glow.Visible = false end
		if glow and not options.Logo then theme.bind(glow, "ImageColor3", "Accent") end
		if options.Logo then
			utility.new("ImageLabel", {Name = "Mark", BackgroundTransparency = 1, Size = environment.UDim2.fromOffset(42, 42),
				Position = environment.UDim2.fromOffset(-3, -3), Image = options.Logo, ScaleType = environment.Enum.ScaleType.Fit, ZIndex = 6, Parent = logo})
		else
			nova.tile(logo, {Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Accent", Z = 5})
			nova.label({Parent = logo, Text = tostring(options.Initial or string.sub(options.Title or "N", 1, 1)), Font = nova.Font.Heavy(), Size = 19,
				Box = environment.UDim2.fromScale(1, 1), AlignX = environment.Enum.TextXAlignment.Center, Color = "OnAccent", Z = 6})
		end

		local titleX = options.Logo and 66 or 60
		window.TitleLabel = nova.label({Parent = brand, Text = options.Title or "Nova", Font = nova.Font.Bold(), Size = 17,
			Pos = environment.UDim2.fromOffset(titleX, 16), Box = environment.UDim2.new(1, -(titleX + 44), 0, 19), Truncate = true, Z = 4})
		window.SubtitleLabel = nova.label({Parent = brand, Text = options.Subtitle or "", Font = nova.Font.Medium(), Size = 11,
			Pos = environment.UDim2.fromOffset(titleX, 36), Box = environment.UDim2.new(1, -(titleX + 44), 0, 14), Color = "Muted", Truncate = true, Z = 4})
		if window.SidebarCollapsed then window.TitleLabel.TextTransparency, window.SubtitleLabel.TextTransparency = 1, 1 end

		window:_sidebarResize()
		window:_sidebarFold()
		window:_sidebarSearch(options)
		window:_sidebarTabs()
		window:_sidebarFooter(options)
	end

	function class._sidebarResize(window)
		local utility, theme = nova.U, nova.Theme
		local edge = utility.new("TextButton", {Name = "SidebarEdge", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			AnchorPoint = environment.Vector2.new(0.5, 0), Position = environment.UDim2.new(0, window.SidebarWidth, 0, 0), Size = environment.UDim2.new(0, 10, 1, 0),
			Visible = not window.SidebarCollapsed, ZIndex = 42, Parent = window.Win})
		local line = utility.new("Frame", {Name = "Line", AnchorPoint = environment.Vector2.new(0.5, 0), Position = environment.UDim2.fromScale(0.5, 0),
			Size = environment.UDim2.new(0, 2, 1, 0), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 43, Parent = edge})
		theme.bind(line, "BackgroundColor3", "Accent")
		local point = environment.NumberSequenceKeypoint.new
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 1), point(0.18, 0), point(0.82, 0), point(1, 1)}), Rotation = 90, Parent = line})
		window.SidebarEdge = edge
		local dragging, startX, startWidth, lastClick, press = false, 0, 0, 0, nil
		edge.MouseEnter:Connect(function()
			if not dragging then nova.Motion.tween(line, "Quick", {BackgroundTransparency = 0.45}) end
			window:ShowTip("Drag to resize")
		end)
		utility.leave(edge, function()
			if not dragging then nova.Motion.tween(line, "Quick", {BackgroundTransparency = 1}) end
			window:HideTip()
		end)
		edge.InputBegan:Connect(function(event)
			if not utility.isClick(event) or window.SidebarCollapsed then return end
			window:HideTip()
			if environment.os.clock() - lastClick < 0.35 then
				lastClick = 0
				window:SetSidebarWidth(window.DefaultSidebarWidth)
				return
			end
			lastClick = environment.os.clock()
			dragging, startX, startWidth, press = true, event.Position.X, window.SidebarWidth, event
			nova.Motion.tween(line, "Quick", {BackgroundTransparency = 0.05})
		end)
		local input = nova.Services.UserInputService
		utility.connect(input.InputChanged, function(event)
			if not dragging or not utility.sameMove(event, press) then return end
			window:SetSidebarWidth(startWidth + (event.Position.X - startX) / math.max(window.Scale.Scale, 0.1), true)
		end, window.Conns)
		utility.connect(input.InputEnded, function(event)
			if not dragging or not utility.sameEnd(event, press) then return end
			dragging = false
			nova.Motion.tween(line, "Base", {BackgroundTransparency = 1})
			window.State.set("sidebarWidth", math.floor(window.ExpandedWidth + 0.5))
		end, window.Conns)
	end

	function class._sidebarFold(window)
		local utility, theme = nova.U, nova.Theme
		local fold = utility.new("TextButton", {Name = "Fold", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			AnchorPoint = environment.Vector2.new(1, 0), Position = environment.UDim2.new(1, -12, 0, 19), Size = environment.UDim2.fromOffset(28, 28), ZIndex = 5, Parent = window.BrandFrame})
		local face, isImage = nova.tile(fold, {Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Elevated", Alpha = 0.35, Z = 5})
		local icon = nova.icon({Parent = fold, Icon = "panel-left-close", Size = 15, Pos = environment.UDim2.fromScale(0.5, 0.5),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 6})
		fold.MouseEnter:Connect(function()
			nova.Motion.tween(face, "Quick", {[isImage and "ImageColor3" or "BackgroundColor3"] = theme.resolve("Elevated")})
			nova.Motion.tween(icon, "Quick", {ImageColor3 = theme.resolve("Text")})
			window:ShowTip("Collapse sidebar")
		end)
		utility.leave(fold, function()
			nova.Motion.tween(icon, "Quick", {ImageColor3 = theme.resolve("Muted")})
			window:HideTip()
		end)
		fold.MouseButton1Click:Connect(function()
			nova.Sound.play("click")
			window:HideTip()
			window:SetSidebarCollapsed(true)
		end)
		window.FoldButton = fold
		window.LogoButton.MouseButton1Click:Connect(function()
			if window.SidebarCollapsed then
				nova.Sound.play("click")
				window:SetSidebarCollapsed(false)
			end
		end)
		window.LogoButton.MouseEnter:Connect(function()
			if window.SidebarCollapsed then window:ShowTip("Expand sidebar") end
		end)
		utility.leave(window.LogoButton, function() window:HideTip() end)
	end

	function class._sidebarSearch(window, options)
		local utility, theme = nova.U, nova.Theme
		local holder = utility.new("Frame", {Name = "SearchHolder", Position = environment.UDim2.fromOffset(0, window.SidebarCollapsed and 52 or 68),
			Size = environment.UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 3, Parent = window.Sidebar})
		local field = utility.new("Frame", {Name = "Search", Position = environment.UDim2.fromOffset(12, 3), Size = environment.UDim2.new(1, -24, 0, 34), BorderSizePixel = 0, ZIndex = 3, Parent = holder})
		theme.bind(field, "BackgroundColor3", "Elevated")
		utility.corner(field, 10)
		local white = environment.Color3.new(1, 1, 1)
		utility.new("UIGradient", {Color = environment.ColorSequence.new(white, environment.Color3.fromRGB(190, 193, 202)), Rotation = 90, Parent = field})
		local stroke = utility.stroke(field, white, 1, 0.86)
		theme.bind(stroke, "Color", "Glass")
		nova.icon({Parent = field, Icon = "search", Size = 15, Pos = environment.UDim2.new(0, 11, 0.5, 0), Anchor = environment.Vector2.new(0, 0.5), Color = "Faint", Z = 4})
		local box = utility.new("TextBox", {Name = "Box", BackgroundTransparency = 1, Position = environment.UDim2.fromOffset(34, 0), Size = environment.UDim2.new(1, -44, 1, 0),
			FontFace = nova.Font.Medium(), TextSize = 13, PlaceholderText = options.SearchText or "Search", Text = "", ClearTextOnFocus = false,
			TextXAlignment = environment.Enum.TextXAlignment.Left, ZIndex = 4, Parent = field})
		theme.bind(box, "TextColor3", "Text")
		theme.bind(box, "PlaceholderColor3", "Faint")
		window.SearchBox, window.SearchField = box, field
		field.Visible = not window.SidebarCollapsed
		window.FoldButton.Visible = not window.SidebarCollapsed
		box.Focused:Connect(function()
			nova.paint(stroke, "Color", "Accent", "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = 0.35})
		end)
		box.FocusLost:Connect(function()
			nova.paint(stroke, "Color", "Glass", "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = 0.86})
		end)
		box:GetPropertyChangedSignal("Text"):Connect(function() window:Search(box.Text) end)
		box.Focused:Connect(function()
			if string.find(box.Text, "%S") and not window.SearchPop then window:Search(box.Text) end
		end)
		box.FocusLost:Connect(function(enter, event)
			local popup = window.SearchPop
			if enter and popup and popup.Items and popup.Items[popup.Sel or 1] then
				window:_searchJump(popup.Items[popup.Sel or 1])
			end
			if not enter and event and event.KeyCode == environment.Enum.KeyCode.Escape then box.Text = "" end
		end)
		utility.connect(nova.Services.UserInputService.InputBegan, function(event)
			local popup = window.SearchPop
			if not popup then return end
			local key = event.KeyCode
			if (key == environment.Enum.KeyCode.Down or key == environment.Enum.KeyCode.Up) and box:IsFocused() then
				window:_searchSelect((popup.Sel or 1) + (key == environment.Enum.KeyCode.Down and 1 or -1))
				return
			end
			local inputType = event.UserInputType
			if inputType ~= environment.Enum.UserInputType.MouseButton1 and inputType ~= environment.Enum.UserInputType.Touch then return end
			local mouse = utility.mouse()
			local function contains(object)
				if not object or not object.Parent then return false end
				local position, size = object.AbsolutePosition, object.AbsoluteSize
				return mouse.X >= position.X and mouse.X <= position.X + size.X and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
			end
			if not contains(popup.Frame) and not contains(field) then window:_searchClose() end
		end, window.Conns)

		local tile = utility.new("TextButton", {Name = "SearchTile", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			AnchorPoint = environment.Vector2.new(0.5, 0), Position = environment.UDim2.new(0.5, 0, 0, 3), Size = environment.UDim2.fromOffset(40, 34),
			Visible = window.SidebarCollapsed, ZIndex = 3, Parent = holder})
		local face = utility.new("Frame", {Name = "Face", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 3, Parent = tile})
		theme.bind(face, "BackgroundColor3", "Elevated")
		utility.corner(face, 10)
		local icon = nova.icon({Parent = tile, Icon = "search", Size = 17, Pos = environment.UDim2.fromScale(0.5, 0.5), Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 4})
		tile.MouseButton1Click:Connect(function()
			nova.Sound.play("click")
			window:SetSidebarCollapsed(false)
			environment.task.delay(0.2, function() box:CaptureFocus() end)
		end)
		tile.MouseEnter:Connect(function()
			nova.Motion.tween(face, "Quick", {BackgroundTransparency = 0.55})
			nova.paint(icon, "ImageColor3", "Text", "Quick")
			window:ShowTip("Search")
		end)
		utility.leave(tile, function()
			nova.Motion.tween(face, "Quick", {BackgroundTransparency = 1})
			nova.paint(icon, "ImageColor3", "Muted", "Quick")
			window:HideTip()
		end)
		window.SearchTile = tile
	end

	function class._sidebarTabs(window)
		local utility, theme = nova.U, nova.Theme
		local tabTop = window.SidebarCollapsed and 92 or 112
		local foot = window.SidebarCollapsed and 44 or 50
		local clip = utility.new("CanvasGroup", {Name = "TabsClip", Position = environment.UDim2.fromOffset(0, tabTop),
			Size = environment.UDim2.new(1, 0, 1, -(tabTop + foot + 2)), BackgroundTransparency = 1, ZIndex = 3, Parent = window.Sidebar})
		window.TabClip = clip
		local scroll = utility.new("ScrollingFrame", {Name = "Tabs", Size = environment.UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = environment.UDim2.new(), AutomaticCanvasSize = environment.Enum.AutomaticSize.Y,
			ScrollingDirection = environment.Enum.ScrollingDirection.Y, ZIndex = 3, Parent = clip})
		theme.bind(scroll, "ScrollBarImageColor3", "Faint")
		local gradient = utility.new("UIGradient", {Rotation = 90, Parent = clip})
		local function updateGradient()
			if window.Scaling then
				window:_scalingDefer(updateGradient)
				return
			end
			local height = clip.AbsoluteSize.Y
			if height < 60 then return end
			local top = math.clamp(scroll.CanvasPosition.Y / 10, 0, 1)
			local bottom = math.clamp((scroll.AbsoluteCanvasSize.Y - scroll.CanvasPosition.Y - scroll.AbsoluteWindowSize.Y) / 10, 0, 1)
			local inset = math.min(18 / height, 0.25)
			local point = environment.NumberSequenceKeypoint.new
			gradient.Transparency = environment.NumberSequence.new({point(0, top * 0.92), point(inset, 0), point(1 - inset, 0), point(1, bottom * 0.92)})
		end
		scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateGradient)
		scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateGradient)
		scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateGradient)
		environment.task.defer(updateGradient)
		local canvas = utility.new("Frame", {Name = "Canvas", Size = environment.UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, Parent = scroll})
		window.TabScroll, window.TabCanvas, window.TabListFrame = scroll, canvas, canvas
	end

	function class._sidebarFooter(window, options)
		local utility, theme = nova.U, nova.Theme
		local footer = utility.new("Frame", {Name = "Footer", AnchorPoint = environment.Vector2.new(0, 1), Position = environment.UDim2.fromScale(0, 1),
			Size = environment.UDim2.new(1, 0, 0, window.SidebarCollapsed and 44 or 50), BackgroundTransparency = 1, ZIndex = 3, Parent = window.Sidebar})
		local line = utility.new("Frame", {Name = "Line", Position = environment.UDim2.fromOffset(14, 0), Size = environment.UDim2.new(1, -28, 0, 1),
			BorderSizePixel = 0, BackgroundTransparency = 0.88, ZIndex = 3, Parent = footer})
		theme.bind(line, "BackgroundColor3", "Glass")
		local point = environment.NumberSequenceKeypoint.new
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 1), point(0.2, 0), point(0.8, 0), point(1, 1)}), Parent = line})
		window.FooterText = nova.label({Parent = footer, Text = tostring(options.Footer or ""), Font = nova.Font.Medium(), Size = 11,
			Pos = environment.UDim2.fromOffset(18, 1), Box = environment.UDim2.new(1, -96, 1, -1), Color = "Faint", Truncate = true, Z = 4, Name = "Version"})
		local chip = utility.new("TextButton", {Name = "KeyChip", Text = "", AutoButtonColor = false, AnchorPoint = environment.Vector2.new(1, 0.5),
			Position = environment.UDim2.new(1, -14, 0.5, 1), Size = environment.UDim2.fromOffset(34, 22), BackgroundTransparency = 1, ZIndex = 4, Parent = footer})
		nova.tile(chip, {Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Elevated", Alpha = 0.2, SliceScale = 0.45, Z = 4})
		local rim = nova.Tex.image(chip, "rim9", {Name = "Rim", Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.45, ImageTransparency = 0.6, ZIndex = 6})
		if rim then theme.bind(rim, "ImageColor3", "Glass") end
		window.FooterKey = nova.label({Parent = chip, Text = "", Font = nova.Font.Semi(), Size = 11, Box = environment.UDim2.fromScale(1, 1),
			AlignX = environment.Enum.TextXAlignment.Center, Color = "Muted", Z = 7, Name = "Key"})
		window.FooterKey:GetPropertyChangedSignal("TextBounds"):Connect(function()
			chip.Size = environment.UDim2.fromOffset(math.max(30, math.ceil(window.FooterKey.TextBounds.X) + 18), 22)
		end)
		window.FooterChip, window.Footer = chip, footer
		chip.Visible = not window.IsTouch
		window:_sidebarKey(chip, rim)
		local input = nova.Services.UserInputService
		utility.connect(input.InputChanged, function(event)
			if utility.sameMove(event, window.PressInput) then window:_reorderMove() end
		end, window.Conns)
		utility.connect(input.InputEnded, function(event)
			if utility.sameEnd(event, window.PressInput) then window:_reorderEnd() end
		end, window.Conns)
	end

	function class._sidebarKey(window, chip, rim)
		local listening, pulse, lastStop = false, nil, 0
		local function stop()
			listening = false
			lastStop = environment.os.clock()
			if pulse then
				pulse:Cancel()
				pulse = nil
			end
			if rim then
				nova.paint(rim, "ImageColor3", "Glass", "Quick")
				nova.Motion.tween(rim, "Quick", {ImageTransparency = 0.6})
			end
			nova.paint(window.FooterKey, "TextColor3", "Muted", "Quick")
			window:_syncFooter()
			environment.task.defer(function()
				if not listening then window.Listening = false end
			end)
		end
		chip.MouseEnter:Connect(function()
			if listening then return end
			nova.paint(window.FooterKey, "TextColor3", "Text", "Quick")
			if rim then nova.Motion.tween(rim, "Quick", {ImageTransparency = 0.35}) end
		end)
		nova.U.leave(chip, function()
			if listening then return end
			nova.paint(window.FooterKey, "TextColor3", "Muted", "Quick")
			if rim then nova.Motion.tween(rim, "Quick", {ImageTransparency = 0.6}) end
		end)
		chip.MouseButton1Click:Connect(function()
			if listening or environment.os.clock() - lastStop < 0.3 then return end
			nova.Sound.play("click")
			listening = true
			window.FooterKey.Text = "вЂ¦"
			nova.paint(window.FooterKey, "TextColor3", "Accent", "Quick")
			if rim then
				nova.paint(rim, "ImageColor3", "Accent", "Quick")
				rim.ImageTransparency = 0.5
				local info = environment.TweenInfo.new(0.55, environment.Enum.EasingStyle.Sine, environment.Enum.EasingDirection.InOut, -1, true)
				pulse = nova.Services.TweenService:Create(rim, info, {ImageTransparency = 0.05})
				pulse:Play()
			end
			environment.task.defer(function()
				if listening then window.Listening = true end
			end)
		end)
		nova.U.connect(nova.Services.UserInputService.InputBegan, function(event)
			if not listening or not window.Listening then return end
			if event.UserInputType == environment.Enum.UserInputType.Keyboard then
				local key = event.KeyCode
				if key == environment.Enum.KeyCode.Escape or key == environment.Enum.KeyCode.Unknown then
					stop()
					return
				end
				window:SetKey(key)
				nova.Sound.play("tick")
				stop()
				return
			end
			if nova.U.isClick(event) or event.UserInputType == environment.Enum.UserInputType.MouseButton2 then stop() end
		end, window.Conns)
	end

	function class.Tab(window, options)
		if type(options) == "string" then options = {Name = options} end
		options = options or {}
		local tab = setmetatable({}, nova.TabClass)
		tab.Window = window
		tab.Name = options.Name or "Tab " .. (#window.TabList + 1)
		tab.Title = options.Title or tab.Name
		tab.Desc = options.Desc or ""
		tab.Icon = options.Icon
		tab.Rows, tab.Sections, tab.Pages, tab.Loads = {}, {}, {}, {}
		tab.Columns = options.Columns or 2
		window.Tabs[tab.Name] = tab
		table.insert(window.TabList, tab)
		window:_addTabRow(tab, options)
		tab.Frame = nova.U.new("CanvasGroup", {Name = tab.Name, Size = environment.UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Visible = false, Parent = window.Parking or window.Body})
		tab.RefreshGen = nova.Refresh.gen
		tab.PageHost = nova.U.new("Frame", {Name = "Pages", Size = environment.UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = tab.Frame})
		return tab
	end

	function class.SelectTab(window, tab)
		nova.trace("SelectTab")
		if type(tab) == "string" then tab = window.Tabs[tab] end
		if not tab or tab == window.Current then return end
		local previous = window.Current
		window.Current = tab
		window:ClosePopups()
		if tab.Group and tab.Group.Collapsed and not window.SidebarCollapsed then window:SetGroupCollapsed(tab.Group, false) end
		if previous then
			window:_styleTab(previous, false, true)
			local frame = previous.Frame
			nova.Motion.tween(frame, "Quick", {GroupTransparency = 1, Position = environment.UDim2.fromOffset(-14, 0)})
			environment.task.delay(0.16, function()
				if window.Current ~= previous then
					frame.Visible = false
					if window.Parking then
						frame.Parent = window.Parking
						previous.RefreshGen = nova.Refresh.gen
					end
				end
			end)
		end
		window:_styleTab(tab, true, true)
		window:_revealTab(tab)
		local frame = tab.Frame
		if frame.Parent ~= window.Body then
			frame.Parent = window.Body
			if tab.RefreshGen ~= nova.Refresh.gen then
				nova.Refresh.sync(frame)
				tab.RefreshGen = nova.Refresh.gen
			end
		end
		frame.Visible = true
		frame.GroupTransparency = 1
		frame.Position = environment.UDim2.fromOffset(18, 0)
		nova.Motion.tween(frame, "Base", {GroupTransparency = 0, Position = environment.UDim2.fromOffset(0, 0)})
		environment.task.delay(0.2, function()
			if window.Current == tab then tab:_balanceActive() end
		end)
		window.HeaderTitle.Text = tab.Title
		window.HeaderDesc.Text = tab.Desc or ""
		if window.OnTabChanged then environment.pcall(window.OnTabChanged, tab) end
	end

	function class.TabGroup(window, name)
		name = tostring(name or "")
		local saved = window.State.get("groups", {})
		local group = {Key = name, Tabs = {}, Collapsed = type(saved) == "table" and saved[name] == true}
		local utility, theme = nova.U, nova.Theme
		local row = utility.new("Frame", {Name = "Group_" .. name, Size = environment.UDim2.new(1, -16, 0, window.CapH),
			Position = environment.UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Parent = window.TabCanvas})
		local hit = utility.new("TextButton", {Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = environment.UDim2.fromScale(1, 1), ZIndex = 4, Parent = row})
		group.Row = row
		group.Label = nova.label({Parent = row, Text = name, Font = nova.Font.Bold(), Size = 11, Pos = environment.UDim2.fromOffset(10, 2),
			Box = environment.UDim2.new(1, -36, 1, -2), Color = "Faint", Z = 2, Name = "Caption"})
		group.Chev = nova.icon({Parent = row, Icon = "chevron-down", Size = 13, Pos = environment.UDim2.new(1, -10, 0.5, 1),
			Anchor = environment.Vector2.new(1, 0.5), Color = "Faint", Z = 2})
		group.Line = utility.new("Frame", {Name = "Divider", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromOffset(22, 2), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = row})
		theme.bind(group.Line, "BackgroundColor3", "Glass")
		utility.corner(group.Line, environment.UDim.new(1, 0))
		if group.Collapsed then group.Chev.Rotation = -90 end
		hit.MouseEnter:Connect(function()
			nova.paint(group.Label, "TextColor3", "Muted", "Quick")
			nova.paint(group.Chev, "ImageColor3", "Muted", "Quick")
		end)
		utility.leave(hit, function()
			nova.paint(group.Label, "TextColor3", "Faint", "Quick")
			nova.paint(group.Chev, "ImageColor3", "Faint", "Quick")
		end)
		hit.MouseButton1Click:Connect(function()
			if window.SidebarCollapsed then return end
			nova.Sound.play("tick")
			window:SetGroupCollapsed(group, not group.Collapsed)
		end)
		table.insert(window.Groups, group)
		window.CurGroup = group
		if window.SidebarCollapsed then
			local first
			for _, item in ipairs(window.Groups) do
				if item.Row then first = item; break end
			end
			group.Label.TextTransparency, group.Chev.ImageTransparency, group.Line.BackgroundTransparency = 1, 1, first == group and 1 or 0.88
		end
		window:_layoutTabs(false)
		return group.Label
	end

	function class._addTabRow(window, tab, options)
		local group = window:_ensureGroup()
		tab.Group = group
		local collapsed = window.SidebarCollapsed
		local utility, theme = nova.U, nova.Theme
		local row = utility.new("CanvasGroup", {Name = tab.Name, Size = environment.UDim2.new(1, -16, 0, collapsed and 36 or window.RowH),
			Position = environment.UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Parent = window.TabCanvas})
		tab.Row = row
		utility.corner(row, 12)
		local background = utility.new("Frame", {Name = "Bg", Position = environment.UDim2.fromOffset(1, 1), Size = environment.UDim2.new(1, -2, 1, -2),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = row})
		theme.bind(background, "BackgroundColor3", "Elevated")
		utility.corner(background, 11)
		local stroke = utility.stroke(background, environment.Color3.new(1, 1, 1), 1, 1)
		theme.bind(stroke, "Color", "Accent")
		tab.Bg, tab.BgStroke = background, stroke
		local point = environment.NumberSequenceKeypoint.new
		tab.BgGrad = utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 0), point(0.5, 0.12), point(1, 0.92)}), Enabled = not collapsed, Parent = background})
		tab.StrokeGrad = utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 0), point(0.4, 0.35), point(0.85, 1), point(1, 1)}), Enabled = not collapsed, Parent = stroke})
		local size = collapsed and 32 or window.TileS
		local x = collapsed and 8 or 6
		local glow = nova.Tex.image(row, "glow", {Name = "Glow", AnchorPoint = environment.Vector2.new(0.5, 0.5),
			Position = environment.UDim2.new(0, x + size / 2, 0.5, 0), Size = environment.UDim2.new(0, 72, 1, 0), ImageTransparency = 1, ZIndex = 1})
		if glow then theme.bind(glow, "ImageColor3", "Accent") end
		tab.Glow = glow
		local tile, isImage = nova.tile(row, {Name = "Tile", Size = environment.UDim2.fromOffset(size, size), Pos = environment.UDim2.new(0, x, 0.5, 0),
			Anchor = environment.Vector2.new(0, 0.5), Color = "Elevated", Alpha = collapsed and 1 or 0.4, Z = 2})
		tab.Tile = tile
		tab.TileProp = isImage and "ImageColor3" or "BackgroundColor3"
		tab.TileAlphaProp = isImage and "ImageTransparency" or "BackgroundTransparency"
		tab.IconImg = nova.icon({Parent = tile, Icon = options.Icon, Size = collapsed and 17 or 16, Pos = environment.UDim2.fromScale(0.5, 0.5),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 3})
		tab.Label = nova.label({Parent = row, Text = tab.Name, Font = nova.Font.Semi(), Size = 14, Pos = environment.UDim2.fromOffset(window.LabelX, 0),
			Box = environment.UDim2.new(1, -(window.LabelX + 10), 1, 0), Color = "Muted", Truncate = true, Z = 2})
		if collapsed then tab.Label.TextTransparency = 1 end
		if options.Badge then
			local text = tostring(options.Badge)
			local width = math.max(20, #text * 6.4 + 12)
			local badge = utility.new("Frame", {Name = "Badge", AnchorPoint = environment.Vector2.new(1, 0.5), Position = environment.UDim2.new(1, -9, 0.5, 0),
				Size = environment.UDim2.fromOffset(width, 18), BorderSizePixel = 0, ZIndex = 3, Parent = row})
			theme.bind(badge, "BackgroundColor3", "Accent")
			utility.corner(badge, environment.UDim.new(1, 0))
			tab.BadgeLabel = nova.label({Parent = badge, Text = text, Font = nova.Font.Bold(), Size = 10, Box = environment.UDim2.fromScale(1, 1),
				AlignX = environment.Enum.TextXAlignment.Center, Color = "OnAccent", Z = 4})
			tab.Badge, tab.BadgeWidth = badge, width
			tab.BadgeRing = utility.stroke(badge, environment.Color3.new(1, 1, 1), 2, collapsed and 0 or 1)
			theme.bind(tab.BadgeRing, "Color", "Sidebar")
			if collapsed then
				badge.Size = environment.UDim2.fromOffset(10, 10)
				badge.Position = environment.UDim2.new(0, x + size - 2, 0.5, -size / 2 + 4)
				tab.BadgeLabel.TextTransparency = 1
			end
		end

		local hit = utility.new("TextButton", {Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = environment.UDim2.fromScale(1, 1), ZIndex = 8, Parent = row})
		tab.Hit = hit
		window:_tabRowInput(tab)
		local order = window.State.get("tabOrder", {})
		local saved = type(order) == "table" and order[group.Key] or nil
		local function rank(name)
			if type(saved) ~= "table" then return math.huge end
			return table.find(saved, name) or math.huge
		end
		local target = rank(tab.Name)
		local index = #group.Tabs + 1
		if target ~= math.huge then
			for position, other in ipairs(group.Tabs) do
				if rank(other.Name) > target then index = position; break end
			end
		end
		table.insert(group.Tabs, index, tab)
		window:_layoutTabs(false)
	end

	function class._tabRowInput(window, tab)
		local hit, utility = tab.Hit, nova.U
		local function tileTransparency(hover)
			if window.SidebarCollapsed then return 1 end
			return hover and 0.05 or 0.4
		end
		hit.MouseEnter:Connect(function()
			tab.Hover = true
			if window.DraggingTab then return end
			if window.Current ~= tab then
				nova.Motion.tween(tab.Bg, "Quick", {BackgroundTransparency = 0.6})
				nova.paint(tab.Label, "TextColor3", "Text", "Quick")
				nova.Motion.tween(tab.Tile, "Quick", {[tab.TileAlphaProp] = tileTransparency(true)})
				nova.paint(tab.IconImg, "ImageColor3", "Text", "Quick")
			end
			nova.Sound.play("hover", 0.4)
			if window.SidebarCollapsed then window:ShowTip(tab.Name) end
		end)
		utility.leave(hit, function()
			tab.Hover = false
			window:HideTip()
			if window.DraggingTab == tab then return end
			if window.Current ~= tab then
				nova.Motion.tween(tab.Bg, "Quick", {BackgroundTransparency = 1})
				nova.paint(tab.Label, "TextColor3", "Muted", "Quick")
				nova.Motion.tween(tab.Tile, "Quick", {[tab.TileAlphaProp] = tileTransparency(false)})
				nova.paint(tab.IconImg, "ImageColor3", "Muted", "Quick")
			end
		end)
		hit.InputBegan:Connect(function(event)
			if event.UserInputType ~= environment.Enum.UserInputType.MouseButton1 and event.UserInputType ~= environment.Enum.UserInputType.Touch then return end
			window.PressTab = tab
			window.PressTime = environment.os.clock()
			window.PressInput = event
			window.PressAt = utility.at(event)
		end)
		hit.MouseButton1Click:Connect(function()
			if window.DraggingTab or environment.os.clock() - (window.LastDragEnd or 0) < 0.3 then return end
			if window.Current ~= tab then nova.Sound.play("click", 0.8) end
			window:SelectTab(tab)
		end)
	end

	class.CardStyles = {"Glass", "Frosted", "Tinted", "Flat"}

	function class._applyCardStyle(window, section)
		local style, card = window.CardStyle or "Glass", section.Card
		if not card then return end
		local white = environment.Color3.new(1, 1, 1)
		local accent = nova.Theme.resolve("Accent")
		local first, second, transparency, gloss, grain = white, environment.Color3.fromRGB(208, 210, 218), 0.03, 0.9, 0.94
		if style == "Flat" then
			card.BackgroundTransparency = 0
			section.CardGrad.Color = environment.ColorSequence.new(white)
			if section.Gloss then section.Gloss.ImageTransparency = 1 end
			if section.Grain then section.Grain.ImageTransparency = 1 end
			return
		end
		if style == "Frosted" then
			second, transparency, gloss, grain = environment.Color3.fromRGB(220, 222, 230), 0.32, 0.72, 0.9
		end
		if style == "Tinted" then
			first, second, gloss = white:Lerp(accent, 0.05), white:Lerp(accent, 0.34), 0.88
		end
		card.BackgroundTransparency = transparency
		section.CardGrad.Color = environment.ColorSequence.new(first, second)
		if section.Gloss then section.Gloss.ImageTransparency = gloss end
		if section.Grain then section.Grain.ImageTransparency = grain end
	end

	function class.SetCardStyle(window, style)
		nova.trace("SetCardStyle")
		if not table.find(class.CardStyles, style) then return end
		window.CardStyle = style
		window.State.set("cardStyle", style)
		for _, tab in ipairs(window.TabList) do
			for _, section in ipairs(tab.Sections) do window:_applyCardStyle(section) end
		end
	end

	function class._nextZ(window)
		window.FloatZ += 1
		return window.FloatZ
	end

	function class._initCards(window)
		local input = nova.Services.UserInputService
		nova.U.connect(input.InputChanged, function(event)
			if window.CardPress and nova.U.sameMove(event, window.CardPress.input) then window:_cardMove() end
		end, window.Conns)
		nova.U.connect(input.InputEnded, function(event)
			if nova.U.sameEnd(event, window.CardPress and window.CardPress.input) then window:_cardEnd() end
		end, window.Conns)
	end

	function class._cardPress(window, section, input)
		window.CardPress = {sec = section, at = nova.U.at(input), t = environment.os.clock(), input = input}
		if section.Floating then section.Wrap.ZIndex = window:_nextZ() end
	end

	function class._cardMove(window)
		local press = window.CardPress
		if not press then return end
		local section, position = press.sec, nova.U.at(press.input)
		local scale = math.max(window.FloatScale.Scale, 0.1)
		if not window.CardDrag then
			local distance = (position - press.at).Magnitude
			if section.Floating and distance < 4 then return end
			if not section.Floating then
				if window.IsTouch and environment.os.clock() - press.t < 0.35 then
					if distance >= 10 then window.CardPress = nil end
					return
				end
				if distance < 12 or environment.os.clock() - press.t < 0.08 then return end
				window:FloatSection(section, (section.Card.AbsolutePosition - window.FloatLayer.AbsolutePosition) / scale)
				nova.Sound.play("click", 0.8)
			end
			local origin = (section.Wrap.AbsolutePosition - window.FloatLayer.AbsolutePosition) / scale
			window.CardDrag = {sec = section, grab = (position - window.FloatLayer.AbsolutePosition) / scale - origin, fresh = not section.WasFloating}
			window:HideTip()
			nova.Motion.tween(section.Shadow, "Quick", {ImageTransparency = 0.25})
		end
		local drag = window.CardDrag
		local target = (position - window.FloatLayer.AbsolutePosition) / scale - drag.grab
		local area, size = window.FloatLayer.AbsoluteSize / scale, section.Wrap.AbsoluteSize / scale
		target = environment.Vector2.new(math.clamp(target.X, 8 - size.X + 80, area.X - 80), math.clamp(target.Y, 4, area.Y - 40))
		section.Wrap.Position = environment.UDim2.fromOffset(target.X, target.Y)
		if section.Slot and section.SlotStroke then
			local slot = section.Slot.AbsolutePosition + section.Slot.AbsoluteSize / 2
			local card = section.Wrap.AbsolutePosition + environment.Vector2.new(section.Wrap.AbsoluteSize.X / 2, math.min(section.Wrap.AbsoluteSize.Y / 2, 40))
			local near = window.IsOpen and section.Tab == window.Current and (slot - card).Magnitude < 110 * scale
			if near ~= section.NearSlot then
				section.NearSlot = near
				nova.Motion.tween(section.SlotStroke, "Quick", {Transparency = near and 0.2 or 0.86})
				if section.SlotGlow then nova.Motion.tween(section.SlotGlow, "Quick", {ImageTransparency = near and 0.7 or 1}) end
			end
		end
	end

	function class._cardEnd(window)
		window.CardPress = nil
		local drag = window.CardDrag
		if not drag then return end
		window.CardDrag = nil
		window.LastCardDrag = environment.os.clock()
		local section = drag.sec
		nova.Motion.tween(section.Shadow, "Base", {ImageTransparency = 0.3})
		if section.NearSlot then
			section.NearSlot = false
			window:DockSection(section)
			return
		end
		local position, floats = section.Wrap.Position, window.State.get("floats", {})
		if type(floats) ~= "table" then floats = {} end
		floats[section.Key] = {math.floor(position.X.Offset), math.floor(position.Y.Offset)}
		window.State.data.floats = floats
		window.State.save()
	end

	function class.FloatSection(window, section, position)
		nova.trace("FloatSection")
		if section.Floating or window.Destroyed then return end
		local wrap, utility, theme = section.Wrap, nova.U, nova.Theme
		local scale = math.max(window.FloatScale.Scale, 0.1)
		local size = wrap.AbsoluteSize / scale
		local slot = utility.new("Frame", {Name = "Slot", Size = environment.UDim2.new(1, 0, 0, math.max(44, size.Y)),
			LayoutOrder = wrap.LayoutOrder, BackgroundTransparency = 1, Parent = wrap.Parent})
		local ghost = utility.new("Frame", {Name = "Ghost", Size = environment.UDim2.new(1, -4, 1, -4), Position = environment.UDim2.fromOffset(2, 2),
			BorderSizePixel = 0, BackgroundTransparency = 0.6, Parent = slot})
		theme.bind(ghost, "BackgroundColor3", "Surface")
		utility.corner(ghost, 14)
		section.SlotStroke = utility.stroke(ghost, environment.Color3.new(1, 1, 1), 1, 0.86)
		theme.bind(section.SlotStroke, "Color", "Accent")
		section.SlotGlow = nova.Tex.image(slot, "glow", {Name = "Glow", AnchorPoint = environment.Vector2.new(0.5, 0.5),
			Position = environment.UDim2.fromScale(0.5, 0.5), Size = environment.UDim2.new(1, 60, 1, 60), ImageTransparency = 1})
		if section.SlotGlow then theme.bind(section.SlotGlow, "ImageColor3", "Accent") end
		nova.icon({Parent = ghost, Icon = "picture-in-picture-2", Size = 20, Pos = environment.UDim2.fromScale(0.5, 0.42),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Faint"})
		local caption = nova.label({Parent = ghost, Text = nova.tr("Floating В· drag back to dock"), Font = nova.Font.Medium(), Size = 12,
			Pos = environment.UDim2.fromScale(0, 0.42), Box = environment.UDim2.new(1, 0, 0, 16), AlignX = environment.Enum.TextXAlignment.Center, Color = "Faint"})
		caption.Position = environment.UDim2.new(0, 0, 0.42, 16)
		section.Slot = slot
		wrap.Parent = window.FloatLayer
		wrap.Size = environment.UDim2.new(0, math.floor(size.X), 0, math.floor(size.Y))
		position = position or (wrap.AbsolutePosition - window.FloatLayer.AbsolutePosition) / scale
		wrap.Position = environment.UDim2.fromOffset(position.X, position.Y)
		wrap.ZIndex = window:_nextZ()
		section.Floating, section.WasFloating = true, true
		table.insert(window.Floats, section)
		if section.Shadow then section.Shadow.ImageTransparency = 0.3 end
		if section.Rim then section.Rim.ImageTransparency = 0.3 end
		local dock = utility.new("TextButton", {Name = "Dock", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = environment.UDim2.fromOffset(24, 24), LayoutOrder = 9, ZIndex = 7, Parent = section.Accessory})
		nova.tile(dock, {Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Elevated", Alpha = 0.3, Z = 7})
		local icon = nova.icon({Parent = dock, Icon = "undo-2", Size = 13, Pos = environment.UDim2.fromScale(0.5, 0.5),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 8})
		dock.MouseEnter:Connect(function()
			nova.paint(icon, "ImageColor3", "Text", "Quick")
			window:ShowTip("Return to window")
		end)
		utility.leave(dock, function()
			nova.paint(icon, "ImageColor3", "Muted", "Quick")
			window:HideTip()
		end)
		dock.MouseButton1Click:Connect(function()
			window:HideTip()
			nova.Sound.play("click")
			window:DockSection(section)
		end)
		section.DockButton = dock
		section:_refreshVisibility()
		local floats = window.State.get("floats", {})
		if type(floats) ~= "table" then floats = {} end
		floats[section.Key] = {math.floor(position.X), math.floor(position.Y)}
		window.State.data.floats = floats
		window.State.save()
		window:_refreshTabState(section.Tab)
	end

	function class.FloatTab(window, tab, position)
		nova.trace("FloatTab")
		if type(tab) == "string" then tab = window.Tabs[tab] end
		if not tab or window.Destroyed then return end
		local scale = math.max(window.FloatScale.Scale, 0.1)
		local area = window.FloatLayer.AbsoluteSize / scale
		local origin = environment.Vector2.new(math.max(12, position.X), math.max(12, position.Y))
		local parked = window.Parking and tab.Frame.Parent == window.Parking
		if parked then
			tab.Frame.Visible = false
			tab.Frame.Parent = window.Body
			if tab.RefreshGen ~= nova.Refresh.gen then
				nova.Refresh.sync(tab.Frame)
				tab.RefreshGen = nova.Refresh.gen
			end
		end
		local x, y = origin.X, origin.Y
		local right, rowHeight = math.min(origin.X + 640, area.X - 24), 0
		for _, section in ipairs(tab.Sections) do
			if section.Floating or section.Hidden then continue end
			local size = section.Wrap.AbsoluteSize / math.max(window.Scale.Scale, 0.1)
			if x + size.X > right and x > origin.X then
				x, y, rowHeight = origin.X, y + rowHeight + 14, 0
			end
			window:FloatSection(section, environment.Vector2.new(math.clamp(x, 8, math.max(8, area.X - size.X - 8)), math.clamp(y, 8, math.max(8, area.Y - 80))))
			x += size.X + 14
			rowHeight = math.max(rowHeight, size.Y)
		end
		if parked and window.Current ~= tab then tab.Frame.Parent = window.Parking end
		window:_refreshTabState(tab)
	end

	function class.DockTab(window, tab)
		nova.trace("DockTab")
		if type(tab) == "string" then tab = window.Tabs[tab] end
		if not tab then return end
		for _, section in ipairs(tab.Sections) do
			if section.Floating then window:DockSection(section) end
		end
		window:_refreshTabState(tab)
	end

	function class._refreshTabState(window, tab)
		if not tab or not tab.PageHost then return end
		local total, floating = 0, 0
		for _, section in ipairs(tab.Sections) do
			if not section.Hidden then
				total += 1
				if section.Floating then floating += 1 end
			end
		end
		local empty = total > 0 and floating == total
		if empty and not tab.EmptyState then
			local utility, theme = nova.U, nova.Theme
			local frame = utility.new("Frame", {Name = "Popped", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.45),
				Size = environment.UDim2.fromOffset(240, 150), BackgroundTransparency = 1, ZIndex = 3, Parent = tab.PageHost})
			local glow = nova.Tex.image(frame, "glow", {AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.35),
				Size = environment.UDim2.fromOffset(200, 200), ImageTransparency = 0.86, ZIndex = 2})
			if glow then theme.bind(glow, "ImageColor3", "Accent") end
			nova.icon({Parent = frame, Icon = "picture-in-picture-2", Size = 30, Pos = environment.UDim2.new(0.5, 0, 0, 28),
				Anchor = environment.Vector2.new(0.5, 0.5), Color = "Faint", Z = 4})
			nova.label({Parent = frame, Text = nova.tr("Panels are floating"), Font = nova.Font.Semi(), Size = 14, Pos = environment.UDim2.fromOffset(0, 56),
				Box = environment.UDim2.new(1, 0, 0, 20), AlignX = environment.Enum.TextXAlignment.Center, Color = "Muted", Z = 4, Name = "Caption"})
			local dock = utility.new("TextButton", {Name = "DockAll", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
				AnchorPoint = environment.Vector2.new(0.5, 0), Position = environment.UDim2.new(0.5, 0, 0, 92), Size = environment.UDim2.fromOffset(150, 34), ZIndex = 4, Parent = frame})
			nova.tile(dock, {Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Accent", SliceScale = 0.6, Z = 4})
			local rim = nova.Tex.image(dock, "rim9", {Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.64, ImageTransparency = 0.6, ZIndex = 6})
			if rim then theme.bind(rim, "ImageColor3", "Glass") end
			nova.label({Parent = dock, Text = nova.tr("Dock all"), Font = nova.Font.Semi(), Size = 13, Box = environment.UDim2.fromScale(1, 1),
				AlignX = environment.Enum.TextXAlignment.Center, Color = "OnAccent", Z = 7, Name = "Caption"})
			local scale = utility.new("UIScale", {Parent = dock})
			dock.MouseEnter:Connect(function() nova.Motion.tween(scale, "Quick", {Scale = 1.05}) end)
			utility.leave(dock, function() nova.Motion.tween(scale, "Quick", {Scale = 1}) end)
			dock.MouseButton1Click:Connect(function() nova.Sound.play("click"); window:DockTab(tab) end)
			tab.EmptyState = frame
		end
		if tab.EmptyState then tab.EmptyState.Visible = empty end
		for _, section in ipairs(tab.Sections) do
			if section.Slot then section.Slot.Visible = not empty end
		end
	end

	function class.DockSection(window, section)
		nova.trace("DockSection")
		if not section.Floating then return end
		section.Floating = false
		local index = table.find(window.Floats, section)
		if index then table.remove(window.Floats, index) end
		local wrap, slot = section.Wrap, section.Slot
		if slot and slot.Parent then
			wrap.LayoutOrder = slot.LayoutOrder
			wrap.Parent = slot.Parent
			slot:Destroy()
		end
		section.Slot, section.SlotStroke, section.SlotGlow = nil, nil, nil
		wrap.Position = environment.UDim2.new()
		wrap.Size = environment.UDim2.new(1, 0, 0, wrap.AbsoluteSize.Y / math.max(window.Scale.Scale, 0.1))
		wrap.ZIndex = 1
		if section.DockButton then section.DockButton:Destroy(); section.DockButton = nil end
		if section.Shadow then nova.Motion.tween(section.Shadow, "Base", {ImageTransparency = 0.62}) end
		if section.Rim then section.Rim.ImageTransparency = 0.5 end
		environment.task.defer(function() if section._sync then section._sync() end end)
		section:_refreshVisibility()
		local floats = window.State.get("floats", {})
		if type(floats) == "table" then
			floats[section.Key] = nil
			window.State.data.floats = floats
			window.State.save()
		end
		window:_refreshTabState(section.Tab)
	end

	function class._reorderPosition(window)
		return (nova.U.at(window.PressInput).Y - window.TabCanvas.AbsolutePosition.Y) / math.max(window.Scale.Scale, 0.1)
	end

	function class._reorderMove(window)
		local tab = window.PressTab
		if not tab and not window.DraggingTab then return end
		if not window.DraggingTab then
			local position = nova.U.at(window.PressInput)
			if window.IsTouch and environment.os.clock() - (window.PressTime or 0) < 0.35 then
				if (position - window.PressAt).Magnitude >= 9 then window.PressTab = nil end
				return
			end
			if (position - window.PressAt).Magnitude < 9 then return end
			window.DraggingTab = tab
			window.DragOffset = window:_reorderPosition() - (tab.TargetY or 0)
			tab.Row.ZIndex = 10
			window:HideTip()
			nova.Motion.tween(tab.Bg, "Quick", {BackgroundTransparency = 0.25})
			nova.paint(tab.BgStroke, "Color", "Accent", "Quick")
			nova.Motion.tween(tab.BgStroke, "Quick", {Transparency = 0.35})
			if tab.Glow then nova.Motion.tween(tab.Glow, "Quick", {ImageTransparency = 0.5}) end
			nova.Sound.play("tick")
		end

		tab = window.DraggingTab
		if not tab then return end
		window:_tabPopFeedback(tab)
		local group = tab.Group
		local height = window.SidebarCollapsed and 36 or window.RowH
		local first = group.Tabs[1] and group.Tabs[1].TargetY or 0
		local last = first + math.max(0, #group.Tabs - 1) * (height + 2)
		local y = math.clamp(window:_reorderPosition() - window.DragOffset, first - 8, last + 8)
		tab.Row.Position = environment.UDim2.fromOffset(8, y)
		local center, cursor, target = y + height / 2, first, 1
		for _, other in ipairs(group.Tabs) do
			if other ~= tab then
				if center > cursor + height / 2 then target += 1 end
				cursor += height + 2
			end
		end
		target = math.clamp(target, 1, #group.Tabs)
		local current = table.find(group.Tabs, tab)
		if current and current ~= target then
			table.remove(group.Tabs, current)
			table.insert(group.Tabs, target, tab)
			window:_layoutTabs(true)
			nova.Sound.play("tick", 0.6)
		end
	end

	function class._tabPopFeedback(window, tab)
		local position = nova.U.at(window.PressInput)
		local edge = window.Sidebar.AbsolutePosition.X + window.Sidebar.AbsoluteSize.X
		local intent = position.X > edge + 46 * math.max(window.Scale.Scale, 0.1) and #tab.Sections > 0
		if not window.TabGhost then
			local utility, theme = nova.U, nova.Theme
			local frame = utility.new("CanvasGroup", {Name = "TabGhost", AnchorPoint = environment.Vector2.new(0.5, 0.5), Size = environment.UDim2.fromOffset(160, 44),
				BorderSizePixel = 0, GroupTransparency = 1, Visible = false, ZIndex = 400, Parent = window.FloatLayer})
			theme.bind(frame, "BackgroundColor3", "Elevated")
			utility.corner(frame, 14)
			local rim = nova.Tex.image(frame, "rim9", {Size = environment.UDim2.fromScale(1, 1), SliceScale = 1, ImageTransparency = 0.3, ZIndex = 402})
			if rim then
				theme.bind(rim, "ImageColor3", "Accent")
			else
				theme.bind(utility.stroke(frame, environment.Color3.new(1, 1, 1), 1, 0.4), "Color", "Accent")
			end
			local shadow = nova.Tex.image(window.FloatLayer, "shadow9", {Name = "TabGhostShadow", AnchorPoint = environment.Vector2.new(0.5, 0.5),
				Size = environment.UDim2.fromOffset(220, 100), SliceScale = 1, ImageTransparency = 1, Visible = false, ZIndex = 399})
			nova.tile(frame, {Name = "Tile", Size = environment.UDim2.fromOffset(28, 28), Pos = environment.UDim2.fromOffset(8, 8), Color = "Accent", Z = 401})
			window.TabGhost = {Frame = frame, Shadow = shadow,
				Icon = nova.icon({Parent = frame, Icon = "layout-panel-top", Size = 15, Pos = environment.UDim2.fromOffset(22, 22),
					Anchor = environment.Vector2.new(0.5, 0.5), Color = "OnAccent", Z = 403}),
				Label = nova.label({Parent = frame, Text = "", Font = nova.Font.Semi(), Size = 13, Pos = environment.UDim2.fromOffset(44, 0),
					Box = environment.UDim2.new(1, -52, 1, 0), Truncate = true, Z = 403})}
		end

		local ghost = window.TabGhost
		local offset = (position - window.FloatLayer.AbsolutePosition) / math.max(window.FloatScale.Scale, 0.1)
		ghost.Frame.Position = environment.UDim2.fromOffset(offset.X + 96, offset.Y)
		if ghost.Shadow then ghost.Shadow.Position = environment.UDim2.fromOffset(offset.X + 96, offset.Y + 6) end
		if intent == window.TabPopIntent then return end
		window.TabPopIntent = intent
		ghost.Label.Text = tab.Label and tab.Label.Text or tab.Name
		if tab.IconImg and tab.IconImg.Image ~= "" then
			ghost.Icon.Image, ghost.Icon.ImageRectOffset, ghost.Icon.ImageRectSize = tab.IconImg.Image, tab.IconImg.ImageRectOffset, tab.IconImg.ImageRectSize
			ghost.Icon.Visible = true
		end
		if intent then
			ghost.Frame.Visible = true
			if ghost.Shadow then ghost.Shadow.Visible = true end
			nova.Sound.play("click", 0.7)
		end
		nova.Motion.tween(ghost.Frame, "Base", {GroupTransparency = intent and 0 or 1})
		if ghost.Shadow then nova.Motion.tween(ghost.Shadow, "Base", {ImageTransparency = intent and 0.45 or 1}) end
		nova.Motion.tween(tab.Row, "Quick", {GroupTransparency = intent and 0.45 or 0})
		if not intent then
			environment.task.delay(0.2, function()
				if not window.TabPopIntent then
					ghost.Frame.Visible = false
					if ghost.Shadow then ghost.Shadow.Visible = false end
				end
			end)
		end
	end

	function class._reorderEnd(window)
		local tab = window.DraggingTab
		window.PressTab = nil
		if not tab then return end
		window.DraggingTab = nil
		window.LastDragEnd = environment.os.clock()
		if window.TabPopIntent then
			window.TabPopIntent = false
			local ghost = window.TabGhost
			if ghost then
				nova.Motion.tween(ghost.Frame, "Quick", {GroupTransparency = 1})
				if ghost.Shadow then nova.Motion.tween(ghost.Shadow, "Quick", {ImageTransparency = 1}) end
				environment.task.delay(0.2, function()
					ghost.Frame.Visible = false
					if ghost.Shadow then ghost.Shadow.Visible = false end
				end)
			end
			nova.Motion.tween(tab.Row, "Quick", {GroupTransparency = 0})
			local position = (nova.U.at(window.PressInput) - window.FloatLayer.AbsolutePosition) / math.max(window.FloatScale.Scale, 0.1)
			window:FloatTab(tab, position - environment.Vector2.new(80, 20))
		end
		tab.Row.ZIndex = 1
		window:_styleTab(tab, window.Current == tab, true)
		window:_layoutTabs(true)
		local order = {}
		for _, group in ipairs(window.Groups) do
			local names = {}
			for _, item in ipairs(group.Tabs) do table.insert(names, item.Name) end
			order[group.Key] = names
		end
		window.State.data.tabOrder = order
		window.State.save()
		if window.OnTabOrder then environment.pcall(window.OnTabOrder, order) end
	end

	function class._buildBackdrop(window)
		local utility, textures, theme = nova.U, nova.Tex, nova.Theme
		local backdrop = utility.new("Frame", {
			Name = "Backdrop", Size = environment.UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, ZIndex = 0, Parent = window.Win,
		})
		window.Backdrop = backdrop
		local layers = {}

		layers.meshA = textures.image(backdrop, "meshA", {
			Name = "MeshA", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.25, 0.18),
			Size = environment.UDim2.fromScale(1.5, 1.5), ImageTransparency = 0.84, ZIndex = 0,
		})

		if layers.meshA then
			theme.bind(layers.meshA, "ImageColor3", "Accent")
		end

		layers.meshB = textures.image(backdrop, "meshB", {
			Name = "MeshB", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.85, 0.9),
			Size = environment.UDim2.fromScale(1.4, 1.4), ImageTransparency = 0.9, ZIndex = 0,
		})

		if layers.meshB then
			theme.bind(layers.meshB, "ImageColor3", function(tokens)
				return tokens.Accent:Lerp(environment.Color3.fromRGB(80, 110, 255), 0.55)
			end)
		end

		layers.auraA = textures.image(backdrop, "glow", {
			Name = "AuraA", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromOffset(60, 10),
			Size = environment.UDim2.fromOffset(640, 540), ImageTransparency = 0.84, ZIndex = 0,
		})

		if layers.auraA then
			theme.bind(layers.auraA, "ImageColor3", "Accent")
		end

		layers.auraB = textures.image(backdrop, "glow", {
			Name = "AuraB", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.new(1, 40, 1, 60),
			Size = environment.UDim2.fromOffset(660, 480), ImageTransparency = 0.9, ZIndex = 0,
		})

		if layers.auraB then
			theme.bind(layers.auraB, "ImageColor3", function(tokens)
				return window.BgStyle == "Halloween" and class.HalloweenEmber or tokens.Accent
			end)
		end

		layers.pattern = utility.new("ImageLabel", {
			Name = "Pattern", BackgroundTransparency = 1, BorderSizePixel = 0, Size = environment.UDim2.fromScale(1, 1),
			ImageTransparency = 1, ZIndex = 0, Parent = backdrop,
		})
		theme.bind(layers.pattern, "ImageColor3", function(tokens)
			return window.BgStyle == "Halloween" and environment.Color3.new(1, 1, 1) or tokens.Glass
		end)

		layers.hwMoon = utility.new("ImageLabel", {
			Name = "HwMoon", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = environment.Vector2.new(0.5, 0.5),
			Position = environment.UDim2.new(1, -96, 0, 92), Size = environment.UDim2.fromOffset(250, 250),
			Image = class.HalloweenArt.moon, ImageColor3 = environment.Color3.fromRGB(255, 186, 120),
			ImageTransparency = 1, Visible = false, ZIndex = 0, Parent = backdrop,
		})
		layers.hwWeb = utility.new("ImageLabel", {
			Name = "HwWeb", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = environment.Vector2.new(1, 0),
			Position = environment.UDim2.fromScale(1, 0), Size = environment.UDim2.fromOffset(200, 200),
			Image = class.HalloweenArt.web, ImageTransparency = 1, Visible = false, ZIndex = 0, Parent = backdrop,
		})
		layers.hwWeb2 = utility.new("ImageLabel", {
			Name = "HwWeb2", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = environment.Vector2.new(1, 1),
			Position = environment.UDim2.fromScale(1, 1), Size = environment.UDim2.fromOffset(140, 140), Rotation = 90,
			Image = class.HalloweenArt.web, ImageTransparency = 1, Visible = false, ZIndex = 0, Parent = backdrop,
		})

		layers.hwBats = {}

		for index = 1, 3 do
			layers.hwBats[index] = utility.new("ImageLabel", {
				Name = "HwBat" .. index, BackgroundTransparency = 1, BorderSizePixel = 0,
				AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromOffset(-200, 60),
				Size = environment.UDim2.fromOffset(62 - index * 10, 62 - index * 10), Image = class.HalloweenArt.sheet,
				ImageRectSize = environment.Vector2.new(105, 105), ImageColor3 = environment.Color3.fromRGB(8, 6, 6),
				ImageTransparency = 1, Visible = false, ZIndex = 0, Parent = backdrop,
			})
		end

		layers.vignette = textures.image(backdrop, "vignette", {
			Name = "Vignette", Size = environment.UDim2.fromScale(1, 1), ImageTransparency = 0.3, ZIndex = 0,
		})
		layers.grain = textures.image(backdrop, "grain", {
			Name = "Grain", Size = environment.UDim2.fromScale(1, 1), ImageTransparency = 0.82, ZIndex = 0,
		})
		window.BgLayers = layers

		local state = {layers = layers, backdrop = backdrop}
		environment.task.spawn(function()
			window:_animateBackdrop(state)
		end)
	end

	function class._animateBackdrop(window, state)
		local layers = state.layers
		local elapsed, nextBats = 0, 6

		while not window.Destroyed do
			environment.task.wait(0.08)
			local isHalloween = window.BgStyle == "Halloween"

			if not window.IsOpen or not nova.Motion.enabled or (window.BgStyle ~= "Aurora" and not isHalloween) then
				continue
			end

			elapsed += 0.08

			if layers.auraA then
				layers.auraA.Position = environment.UDim2.fromOffset(60 + environment.math.sin(elapsed * 0.35) * 34,
					10 + environment.math.cos(elapsed * 0.27) * 22)
			end

			if layers.auraB then
				layers.auraB.Position = environment.UDim2.new(1, 40 + environment.math.cos(elapsed * 0.22) * 38,
					1, 60 + environment.math.sin(elapsed * 0.31) * 24)
			end

			if layers.meshA then
				layers.meshA.Position = environment.UDim2.fromScale(0.25 + environment.math.sin(elapsed * 0.11) * 0.06,
					0.18 + environment.math.cos(elapsed * 0.09) * 0.05)
			end

			if layers.meshB then
				layers.meshB.Position = environment.UDim2.fromScale(0.85 + environment.math.cos(elapsed * 0.1) * 0.06,
					0.9 + environment.math.sin(elapsed * 0.12) * 0.05)
			end

			if isHalloween and layers.hwBats and elapsed >= nextBats then
				nextBats = elapsed + 16 + environment.math.random() * 12
				window:_launchBats(state)
			end
		end
	end

	function class._launchBats(window, state)
		local layers = state.layers
		local scale = environment.math.max(window.Scale.Scale, 0.05)
		local width = state.backdrop.AbsoluteSize.X / scale
		local height = state.backdrop.AbsoluteSize.Y / scale
		local top = 40 + environment.math.random() * environment.math.max(height * 0.3, 1)
		local isRightward = environment.math.random() < 0.5
		local started = environment.os.clock()

		for index, bat in environment.ipairs(layers.hwBats) do
			local vertical = (index - 1) * 22 + environment.math.random() * 10
			local offset = (index - 1) * 46
			bat.ImageRectSize = environment.Vector2.new(isRightward and 105 or -105, 105)
			bat.Position = environment.UDim2.fromOffset(isRightward and -80 - offset or width + 80 + offset, top + vertical)
			bat.Rotation = isRightward and -8 or 8
			bat.ImageTransparency = 0.3
			bat.Visible = true
			nova.Motion.tween(bat, environment.TweenInfo.new(7.5, environment.Enum.EasingStyle.Linear), {
				Position = environment.UDim2.fromOffset(isRightward and width + 80 + offset or -80 - offset,
					top + vertical - 50 - environment.math.random() * 30),
			})
		end

		if window.HwFlap then
			environment.pcall(function()
				window.HwFlap:Disconnect()
			end)
		end

		window.HwFlap = nova.Services.RunService.RenderStepped:Connect(function()
			local elapsed = environment.os.clock() - started

			if elapsed > 7.8 or window.Destroyed or window.BgStyle ~= "Halloween" then
				if window.HwFlap then
					window.HwFlap:Disconnect()
					window.HwFlap = nil
				end

				for _, bat in environment.ipairs(layers.hwBats) do
					bat.Visible = false
				end
				return
			end

			for index, bat in environment.ipairs(layers.hwBats) do
				local frame = environment.math.floor(elapsed * (15 + index * 2) + index * 5) % 16
				bat.ImageRectOffset = environment.Vector2.new(frame % 4 * 105 + (isRightward and 0 or 105),
					environment.math.floor(frame / 4) * 105)
			end
		end)
	end

	function class._buildDecor(window)
		local art, decor, utility = class.HalloweenArt, {bats = {}}, nova.U
		local glow = nova.Tex.get("glow") or ""
		local function image(properties, parent)
			properties.BackgroundTransparency = 1
			properties.BorderSizePixel = 0
			properties.Parent = parent
			return utility.new("ImageLabel", properties)
		end
		decor.back = utility.new("Frame", {Name = "HwBack", BackgroundTransparency = 1, Size = environment.UDim2.fromScale(1, 1), ZIndex = 0, Visible = false, Parent = window.Backdrop})
		decor.web = image({Name = "Web", AnchorPoint = environment.Vector2.new(1, 0), Position = environment.UDim2.fromScale(1, 0),
			Size = environment.UDim2.fromOffset(128, 128), Image = art.web, ImageTransparency = 0.5}, decor.back)
		decor.moonGlow = image({Name = "MoonGlow", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.new(1, -178, 0, 33),
			Size = environment.UDim2.fromOffset(120, 120), Image = glow, ImageColor3 = environment.Color3.fromRGB(255, 214, 130), ImageTransparency = 0.8}, decor.back)
		decor.moon = image({Name = "Moon", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.new(1, -178, 0, 33),
			Size = environment.UDim2.fromOffset(46, 46), Image = art.witchMoon, ImageTransparency = 0.08}, decor.back)
		decor.bats[1] = image({Name = "MoonBat", AnchorPoint = environment.Vector2.new(0.5, 0.5), Size = environment.UDim2.fromOffset(20, 20),
			Image = art.sheet, ImageRectSize = environment.Vector2.new(105, 105), ImageColor3 = environment.Color3.fromRGB(10, 6, 6)}, decor.back)
		decor.side = utility.new("Frame", {Name = "HwSide", BackgroundTransparency = 1, Size = environment.UDim2.fromScale(1, 1),
			ZIndex = 5, Visible = false, Parent = window.Footer or window.Backdrop})
		decor.pkGlow = image({Name = "PumpkinGlow", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.new(0, 76, 0.5, 0),
			Size = environment.UDim2.fromOffset(96, 64), Image = glow, ImageColor3 = environment.Color3.fromRGB(255, 118, 24), ImageTransparency = 0.66, ZIndex = 5}, decor.side)
		decor.pkA = image({Name = "PumpkinA", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.new(0, 68, 0.5, 0),
			Size = environment.UDim2.fromOffset(28, 28), Image = art.pumpkinA, ZIndex = 6}, decor.side)
		decor.pkB = image({Name = "PumpkinB", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.new(0, 92, 0.5, 2),
			Size = environment.UDim2.fromOffset(30, 30), Image = art.pumpkinB, ZIndex = 6}, decor.side)
		window.HwDecor = decor
		local started = false
		decor.start = function()
			if started then return end
			started = true
			local info = environment.TweenInfo.new(3.4, environment.Enum.EasingStyle.Sine, environment.Enum.EasingDirection.InOut, -1, true)
			nova.Motion.tween(decor.moonGlow, info, {ImageTransparency = 0.88, Size = environment.UDim2.fromOffset(104, 104)})
		end
		local start, pumpkin = environment.os.clock(), 0.66
		window.HwDecorConn = nova.Services.RunService.RenderStepped:Connect(function(delta)
			if window.Destroyed then
				if window.HwDecorConn then window.HwDecorConn:Disconnect(); window.HwDecorConn = nil end
				return
			end
			if not window.IsOpen or not decor.back.Visible then return end
			local sideVisible = not window.SidebarCollapsed
			if decor.side.Visible ~= sideVisible then decor.side.Visible = sideVisible end
			if not nova.Motion.enabled then return end
			local elapsed, factor = environment.os.clock() - start, math.clamp(delta * 12, 0, 1)
			local noise = math.noise(elapsed * 2.7, 0.31) + math.noise(elapsed * 7.3, 1.7) * 0.4
			pumpkin += (0.62 - noise * 0.2 - pumpkin) * factor
			decor.pkGlow.ImageTransparency = math.clamp(pumpkin, 0.4, 0.9)
			local bat, angle = decor.bats[1], elapsed * 0.9
			local flipped = -math.sin(angle) < 0
			bat.Position = environment.UDim2.new(1, -178 + math.cos(angle) * 40, 0, 30 + math.sin(angle) * 12)
			bat.ImageRectSize = environment.Vector2.new(flipped and -105 or 105, 105)
			local frame = math.floor(elapsed * 18) % 16
			bat.ImageRectOffset = environment.Vector2.new(frame % 4 * 105 + (flipped and 105 or 0), math.floor(frame / 4) * 105)
		end)
	end

	function class._applyBackground(window)
		local layers = window.BgLayers

		if not layers then
			return
		end

		local style, intensity = window.BgStyle, window.BgIntensity
		local isHalloween = style == "Halloween"
		local isAurora = style == "Aurora" or isHalloween
		local function transparency(value)
			return environment.math.clamp(1 - (1 - value) * intensity, 0, 1)
		end

		if layers.meshA then
			layers.meshA.ImageTransparency = transparency(isAurora and 0.84 or 0.965)
		end

		if layers.meshB then
			layers.meshB.ImageTransparency = transparency(isAurora and 0.9 or 0.975)
		end

		if isHalloween and layers.meshA then
			layers.meshA.ImageTransparency = transparency(0.965)
		end

		if isHalloween and layers.meshB then
			layers.meshB.ImageTransparency = transparency(0.98)
		end

		if layers.auraA then
			local value = isAurora and (isHalloween and 0.93 or 0.84)
			layers.auraA.ImageTransparency = transparency(value or 0.9)
		end

		if layers.auraB then
			local value = isAurora and (isHalloween and 0.92 or 0.9)
			layers.auraB.ImageTransparency = transparency(value or 0.94)
			layers.auraB.ImageColor3 = isHalloween and class.HalloweenEmber or nova.Theme.tokens.Accent
		end

		if window.HwDrift then
			environment.pcall(function() window.HwDrift:Cancel() end)
			window.HwDrift = nil
		end

		for _, layer in environment.ipairs({"hwMoon", "hwWeb", "hwWeb2"}) do
			if layers[layer] then
				layers[layer].Visible = false
			end
		end

		if window.HwDecor then
			window.HwDecor.back.Visible = isHalloween
			window.HwDecor.side.Visible = isHalloween and not window.SidebarCollapsed

			if isHalloween and window.HwDecor.start then
				window.HwDecor.start()
			end
		end

		if layers.hwBats and not isHalloween then
			for _, bat in environment.ipairs(layers.hwBats) do
				bat.Visible = false
			end
		end

		window:_applyPattern(style, transparency)

		if layers.grain then
			layers.grain.ImageTransparency = transparency(style == "Noise" and 0.55 or 0.82)
		end
	end

	function class._applyPattern(window, style, transparency)
		local pattern = window.BgLayers.pattern
		local settings = BACKGROUND_PATTERNS[style]

		if not settings then
			pattern.ImageTransparency = 1
			return
		end

		pattern.Size = environment.UDim2.fromScale(1, 1)
		pattern.Position = environment.UDim2.fromOffset(0, 0)
		pattern.ImageColor3 = nova.Theme.tokens.Glass or pattern.ImageColor3
		local asset = nova.Tex.get(settings.tex)

		if asset then
			local specification = nova.Tex.specs[settings.tex]
			pattern.Image = asset
			pattern.ScaleType = environment.Enum.ScaleType.Tile
			pattern.TileSize = environment.UDim2.fromOffset(specification.w, specification.h)
			pattern.ImageTransparency = transparency(settings.alpha)
		end
	end

	function class.SetBackground(window, style)
		nova.trace("SetBackground")

		for _, candidate in environment.ipairs(class.BackgroundStyles) do
			if candidate == style then
				window.BgStyle = style
				window.State.set("bgStyle", style)
				window:_applyBackground()
				return
			end
		end
	end

	function class.SetBackgroundIntensity(window, value)
		nova.trace("SetBackgroundIntensity")
		window.BgIntensity = environment.math.clamp(environment.tonumber(value) or 1, 0, 1.5)
		window.State.set("bgIntensity", window.BgIntensity)
		window:_applyBackground()
	end

	function class.SetOpacity(window, value)
		nova.trace("SetOpacity")
		window.Opacity = environment.math.clamp(environment.tonumber(value) or 1, 0.5, 1)
		window.State.set("opacity", window.Opacity)
		window.Win.BackgroundTransparency = 1 - window.Opacity

		if window.Sidebar then
			window.Sidebar.BackgroundTransparency = 0.3 + (1 - window.Opacity) * 0.7
		end
	end

	function class.SetCornerRadius(window, value)
		nova.trace("SetCornerRadius")
		local radius = environment.math.clamp(environment.tonumber(value) or 1, 0, 2)
		window.State.set("radius", radius)
		nova.U.setRadius(radius)
		nova.Tex.setRadius()
	end

	function class.SetFont(window, value)
		nova.trace("SetFont")

		if nova.Font.setFamily(value) then
			window.State.set("font", nova.Font.name)
		end
	end

	function class.SetTextScale(window, value)
		nova.trace("SetTextScale")
		local scale = environment.math.clamp(environment.tonumber(value) or 1, 0.8, 1.3)
		window.State.set("textScale", scale)
		nova.Font.setScale(scale)
	end

	function class.SetSounds(window, value)
		nova.Sound.enabled = value and true or false
		window.State.set("sounds", nova.Sound.enabled)
	end

	function class.SetVolume(window, value)
		nova.Sound.volume = environment.math.clamp(environment.tonumber(value) or 0.5, 0, 1)
		window.State.set("volume", nova.Sound.volume)
	end

	function class.SetMotion(window, value)
		nova.Motion.enabled = value and true or false
		window.State.set("motion", nova.Motion.enabled)
	end

	function class.SetTooltips(window, value)
		window.TooltipsOn = value and true or false
		window.State.set("tooltips", window.TooltipsOn)

		if not window.TooltipsOn then
			window:HideTip()
		end
	end

	function class.SetLauncher(window, value)
		window.LauncherOn = (value or window.IsTouch) and true or false
		window.State.set("launcher", window.LauncherOn)

		if window.Launcher then
			window.Launcher.Visible = window.LauncherOn and not (window.IsTouch and window.IsOpen)
		end
	end

	function class.SetAccent(window, color)
		nova.trace("SetAccent")

		if environment.typeof(color) ~= "Color3" then
			return
		end

		nova.Theme.set("Accent", color)
		window.State.set("accent", color:ToHex())
	end

	function class.SetBase(window, base)
		nova.trace("SetBase")
		if nova.Theme.setBase(base) then
			window.State.set("base", base)
			window.State.set("panel", nil)
			window.PanelColor = nil
		end
	end

	function class.IsHalloween(window)
		return nova.Theme.base == "Halloween" and window.BgStyle == "Halloween"
	end

	function class.SetHalloween(window, enabled)
		nova.trace("SetHalloween")
		local state, theme = window.State, nova.Theme
		if enabled then
			if not window:IsHalloween() then
				state.set("preHw", {base = theme.base ~= "Halloween" and theme.base or nil,
					panel = window.PanelColor and window.PanelColor:ToHex() or nil,
					accent = theme.tokens.Accent and theme.tokens.Accent:ToHex() or nil,
					bgStyle = window.BgStyle ~= "Halloween" and window.BgStyle or nil})
			end
			window:SetBase("Halloween")
			window:SetAccent(environment.Color3.fromHex(class.HalloweenAccent))
			window:SetBackground("Halloween")
		else
			local saved = state.get("preHw", nil)
			if type(saved) ~= "table" then saved = window.HalloweenFallback or {} end
			window:SetBase(saved.base and saved.base ~= "Custom" and saved.base ~= "Halloween" and saved.base or "Midnight")
			if saved.panel then environment.pcall(function() window:SetPanelColor(environment.Color3.fromHex(saved.panel)) end) end
			if saved.accent then environment.pcall(function() window:SetAccent(environment.Color3.fromHex(saved.accent)) end) end
			window:SetBackground(saved.bgStyle and saved.bgStyle ~= "Halloween" and saved.bgStyle or "Aurora")
		end
		state.set("hwOn", enabled and true or false)
		if window.AppearanceRefs then environment.pcall(function() window:SyncAppearance() end) end
	end

	function class.SetPanelColor(window, color)
		nova.trace("SetPanelColor")
		if environment.typeof(color) ~= "Color3" then return end
		window.PanelColor = color
		window.State.set("panel", color:ToHex())
		nova.Theme.base = "Custom"
		if window._panelQueued then return end
		window._panelQueued = true
		environment.task.delay(0.06, function()
			window._panelQueued = false
			if window.PanelColor and not window.Destroyed then
				nova.Theme.setMany(nova.Theme.panelFrom(window.PanelColor))
				nova.Theme.base = "Custom"
			end
		end)
	end

	function class.ResetAppearance(window)
		local keys = {"accent", "radius", "font", "textScale", "scale", "autoFit", "blur", "bgStyle", "bgIntensity", "opacity", "tooltips",
			"launcher", "base", "cardStyle", "density", "watermark", "keybindList", "sidebarWidth", "panel"}
		for _, key in ipairs(keys) do window.State.data[key] = nil end
		window.State.save()
		window.PanelColor = nil
		local defaults = window.StateDefaults
		if type(defaults) == "table" then
			if defaults.base then window:SetBase(defaults.base) end
			if defaults.panel then environment.pcall(function() window:SetPanelColor(environment.Color3.fromHex(defaults.panel)) end) end
			if defaults.accent then environment.pcall(function() window:SetAccent(environment.Color3.fromHex(defaults.accent)) end) end
			window:SetCornerRadius(tonumber(defaults.radius) or 1)
			if defaults.font then window:SetFont(defaults.font) end
			window:SetTextScale(tonumber(defaults.textScale) or 1)
			window:SetScale(tonumber(defaults.scale) or window.DefaultScale)
			window:SetAutoFit(defaults.autoFit ~= false)
			window:SetBlur(defaults.blur == true)
			if defaults.bgStyle then window:SetBackground(defaults.bgStyle) end
			window:SetBackgroundIntensity(tonumber(defaults.bgIntensity) or 1)
			if defaults.cardStyle then window:SetCardStyle(defaults.cardStyle) end
			if defaults.density then window:SetDensity(defaults.density) end
			window:SetSidebarWidth(tonumber(defaults.sidebarWidth) or window.DefaultSidebarWidth)
			window:SetOpacity(tonumber(defaults.opacity) or 1)
			if defaults.groupLabels ~= nil and window.SetGroupLabels then window:SetGroupLabels(defaults.groupLabels) end
			if window.SetTooltips then window:SetTooltips(defaults.tooltips ~= false) end
			if defaults.launcher ~= nil and window.SetLauncher then window:SetLauncher(defaults.launcher) end
			window.State.save()
			if window.OnReset then environment.pcall(window.OnReset) end
			return
		end
		nova.Theme.setBase("Midnight")
		nova.Theme.set("Accent", nova.Theme.Presets.Crimson)
		window:SetCornerRadius(1)
		window:SetFont("Builder Sans")
		window:SetTextScale(1)
		window:SetScale(window.DefaultScale)
		window:SetAutoFit(true)
		window:SetBlur(false)
		window:SetBackground("Aurora")
		window:SetBackgroundIntensity(1)
		window:SetCardStyle("Glass")
		window:SetDensity("Comfortable")
		window:SetSidebarWidth(window.DefaultSidebarWidth)
		window:SetOpacity(1)
		for _, key in ipairs({"accent", "radius", "font", "textScale", "scale", "blur", "bgStyle", "bgIntensity", "opacity"}) do window.State.data[key] = nil end
		window.State.save()
		if window.OnReset then environment.pcall(window.OnReset) end
	end

	function class._buildClose(window, header)
		local utility, textures, theme = nova.U, nova.Tex, nova.Theme
		local button = utility.new("TextButton", {
			Name = "Close", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			AnchorPoint = environment.Vector2.new(1, 0.5), Position = environment.UDim2.new(1, -20, 0, 31),
			Size = environment.UDim2.fromOffset(34, 34), ZIndex = 5, Parent = header,
		})
		local scale = utility.new("UIScale", {Parent = button})
		local glow = textures.image(button, "glow", {
			Name = "Glow", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromOffset(84, 84), ImageTransparency = 1, ZIndex = 4,
		})

		if glow then
			theme.bind(glow, "ImageColor3", "Danger")
		end

		local face, isImage = nova.tile(button, {
			Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Elevated", Alpha = 0.05, SliceScale = 0.6, Z = 5,
		})
		local rim = textures.image(button, "rim9", {
			Name = "Rim", Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.64, ImageTransparency = 0.72, ZIndex = 7,
		})

		if rim then
			theme.bind(rim, "ImageColor3", "Glass")
		end

		local icon = nova.icon({
			Parent = button, Icon = "x", Size = 16, Pos = environment.UDim2.fromScale(0.5, 0.5),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 8,
		})
		local colorProperty = isImage and "ImageColor3" or "BackgroundColor3"
		local tween = nova.Motion.tween

		button.MouseEnter:Connect(function()
			tween(face, "Quick", {[colorProperty] = theme.resolve("Danger")})
			tween(icon, "Quick", {ImageColor3 = environment.Color3.new(1, 1, 1)})

			if glow then
				tween(glow, "Quick", {ImageTransparency = 0.72})
			end

			tween(scale, "Quick", {Scale = 1.06})
			nova.Sound.play("hover", 0.6)
			window:ShowTip("Close")
		end)

		utility.leave(button, function()
			tween(face, "Quick", {[colorProperty] = theme.resolve("Elevated")})
			tween(icon, "Quick", {ImageColor3 = theme.resolve("Muted")})

			if glow then
				tween(glow, "Quick", {ImageTransparency = 1})
			end

			tween(scale, "Quick", {Scale = 1})
			window:HideTip()
		end)

		button.MouseButton1Down:Connect(function()
			tween(scale, "Quick", {Scale = 0.9})
		end)
		button.MouseButton1Up:Connect(function()
			tween(scale, "PopSmall", {Scale = 1.06})
		end)
		button.MouseButton1Click:Connect(function()
			nova.Sound.play("click")
			window:HideTip()
			window:Close()
		end)
		window.CloseButton = button

		if window.IsTouch then
			button.Size = environment.UDim2.fromOffset(42, 42)
			button.Position = environment.UDim2.new(1, -16, 0, 31)
			icon.Size = environment.UDim2.fromOffset(19, 19)

			if glow then
				glow.Size = environment.UDim2.fromOffset(70, 70)
			end

			local hitPad = utility.new("TextButton", {
				Name = "HitPad", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
				AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
				Size = environment.UDim2.fromOffset(56, 56), ZIndex = 9, Parent = button,
			})
			hitPad.MouseButton1Down:Connect(function() tween(scale, "Quick", {Scale = 0.9}) end)
			hitPad.MouseButton1Up:Connect(function() tween(scale, "PopSmall", {Scale = 1}) end)
			hitPad.MouseButton1Click:Connect(function()
				nova.Sound.play("click")
				window:HideTip()
				window:Close()
			end)
		end

		theme.onChange(function(role)
			if role == "Elevated" or role == "Danger" then
				environment.pcall(function()
					face[colorProperty] = theme.resolve("Elevated")
				end)
			end
		end)
	end

	function class.AddHeaderButton(window, options)
		options = options or {}
		local header = window.CloseButton and window.CloseButton.Parent

		if not header then
			return nil
		end

		window.HeaderButtons = window.HeaderButtons or {}
		local index = #window.HeaderButtons + 1
		local buttonSize = window.IsTouch and 42 or 34
		local spacing = buttonSize + 8
		local margin = window.IsTouch and 16 or 20
		local utility, textures, theme = nova.U, nova.Tex, nova.Theme
		local hoverColor = options.HoverColor or theme.resolve("Accent")
		local button = utility.new("TextButton", {
			Name = options.Name or "HeaderButton", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			AnchorPoint = environment.Vector2.new(1, 0.5), Position = environment.UDim2.new(1, -(margin + spacing * index), 0, 31),
			Size = environment.UDim2.fromOffset(buttonSize, buttonSize), ZIndex = 5, Parent = header,
		})
		local scale = utility.new("UIScale", {Parent = button})
		local glowSize = window.IsTouch and 70 or 84
		local glow = textures.image(button, "glow", {
			Name = "Glow", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromOffset(glowSize, glowSize), ImageTransparency = 1, ZIndex = 4,
		})

		if glow then
			glow.ImageColor3 = hoverColor
		end

		local face, isImage = nova.tile(button, {
			Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Elevated", Alpha = 0.05, SliceScale = 0.6, Z = 5,
		})
		local rim = textures.image(button, "rim9", {
			Name = "Rim", Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.64, ImageTransparency = 0.72, ZIndex = 7,
		})

		if rim then
			theme.bind(rim, "ImageColor3", "Glass")
		end

		local icon

		if options.Image then
			local width = options.ImageSize and options.ImageSize.X or 18
			local height = options.ImageSize and options.ImageSize.Y or 14

			if window.IsTouch then
				width = environment.math.floor(width * 1.2 + 0.5)
				height = environment.math.floor(height * 1.2 + 0.5)
			end

			icon = utility.new("ImageLabel", {
				Name = "Icon", BackgroundTransparency = 1, Image = options.Image,
				AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
				Size = environment.UDim2.fromOffset(width, height), ScaleType = environment.Enum.ScaleType.Fit,
				ImageColor3 = theme.resolve("Muted"), ZIndex = 8, Parent = button,
			})
		end

		if not options.Image then
			icon = nova.icon({
				Parent = button, Icon = options.Icon or "circle", Size = window.IsTouch and 19 or 16,
				Pos = environment.UDim2.fromScale(0.5, 0.5), Anchor = environment.Vector2.new(0.5, 0.5),
				Color = "Muted", Z = 8,
			})
		end

		local colorProperty = isImage and "ImageColor3" or "BackgroundColor3"
		local isHovered = false
		local tween = nova.Motion.tween

		button.MouseEnter:Connect(function()
			isHovered = true
			tween(face, "Quick", {[colorProperty] = hoverColor})
			tween(icon, "Quick", {ImageColor3 = environment.Color3.new(1, 1, 1)})

			if glow then
				tween(glow, "Quick", {ImageTransparency = 0.72})
			end

			tween(scale, "Quick", {Scale = 1.06})
			nova.Sound.play("hover", 0.6)

			if options.Tip then
				window:ShowTip(options.Tip)
			end
		end)

		utility.leave(button, function()
			isHovered = false
			tween(face, "Quick", {[colorProperty] = theme.resolve("Elevated")})
			tween(icon, "Quick", {ImageColor3 = theme.resolve("Muted")})

			if glow then
				tween(glow, "Quick", {ImageTransparency = 1})
			end

			tween(scale, "Quick", {Scale = 1})
			window:HideTip()
		end)

		button.MouseButton1Down:Connect(function() tween(scale, "Quick", {Scale = 0.9}) end)
		button.MouseButton1Up:Connect(function() tween(scale, "PopSmall", {Scale = 1.06}) end)
		button.MouseButton1Click:Connect(function()
			nova.Sound.play("click")
			window:HideTip()

			if options.Callback then
				environment.task.spawn(options.Callback)
			end
		end)

		theme.onChange(function(role)
			if isHovered then
				return
			end

			if role == "Elevated" or role == "Muted" then
				environment.pcall(function()
					face[colorProperty] = theme.resolve("Elevated")
					icon.ImageColor3 = theme.resolve("Muted")
				end)
			end
		end)

		table.insert(window.HeaderButtons, button)
		return button
	end

	function class._acrylicStep(window)
		local part, mesh = window.AcrylicPart, window.AcrylicMesh
		local camera = environment.workspace.CurrentCamera
		if not part or not mesh or not camera then
			return
		end

		if part.Parent ~= camera then
			part.Parent = camera
		end

		local root = window.Root
		local position, size = root.AbsolutePosition, root.AbsoluteSize
		if not root.Visible or size.X < 8 or size.Y < 8 then
			mesh.Scale = environment.Vector3.zero
			return
		end

		local margin = math.floor(14 * (nova.U.radiusMult or 1) * math.max(window.Scale.Scale, 0.1) * 0.3 + 0.5) + 2
		local inset = environment.Vector2.zero
		if window.Gui and not window.Gui.IgnoreGuiInset then
			environment.pcall(function()
				inset = environment.game:GetService("GuiService"):GetGuiInset()
			end)
		end

		local viewport, cameraFrame = camera.ViewportSize, camera.CFrame
		local halfHeight = math.tan(math.rad(camera.FieldOfView) * 0.5)
		local halfWidth = halfHeight * viewport.X / math.max(viewport.Y, 1)
		local function project(x, y)
			local horizontal = (x + inset.X) / math.max(viewport.X, 1) * 2 - 1
			local vertical = 1 - (y + inset.Y) / math.max(viewport.Y, 1) * 2
			local point = environment.Vector3.new(horizontal * halfWidth, vertical * halfHeight, -1) * 0.001
			return cameraFrame:PointToWorldSpace(point)
		end

		local topLeft = project(position.X + margin, position.Y + margin)
		local topRight = project(position.X + size.X - margin, position.Y + margin)
		local bottomRight = project(position.X + size.X - margin, position.Y + size.Y - margin)
		part.CFrame = environment.CFrame.fromMatrix((topLeft + bottomRight) / 2, cameraFrame.XVector.Unit, cameraFrame.YVector.Unit, cameraFrame.ZVector.Unit)
		mesh.Scale = environment.Vector3.new((topRight - topLeft).Magnitude, (topRight - bottomRight).Magnitude, 0)
	end

	function class._blur(window, enabled)
		local runService = nova.Services.RunService
		window.AcrylicToken = (window.AcrylicToken or 0) + 1
		local token = window.AcrylicToken

		if enabled and window.BlurEnabled and not window.Destroyed then
			local camera = environment.workspace.CurrentCamera
			if not camera then
				return
			end

			if not (window.AcrylicDof and window.AcrylicDof.Parent) then
				window.AcrylicDof = nova.U.new("DepthOfFieldEffect", {
					Name = "NovaDepth", FarIntensity = 0, FocusDistance = 51.6, InFocusRadius = 50, NearIntensity = 0,
					Parent = nova.Services.Lighting,
				})
			end

			if not (window.AcrylicPart and window.AcrylicPart.Parent) then
				local part = environment.Instance.new("Part")
				part.Name = "NovaGlass"
				part.Material = environment.Enum.Material.Glass
				part.Transparency = 0.98
				part.Color = environment.Color3.new(0, 0, 0)
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Size = environment.Vector3.new(1, 1, 0)

				local mesh = environment.Instance.new("SpecialMesh")
				mesh.MeshType = environment.Enum.MeshType.Brick
				mesh.Scale = environment.Vector3.zero
				mesh.Parent = part
				part.Parent = camera
				window.AcrylicPart = part
				window.AcrylicMesh = mesh
			end

			if not window.AcrylicBound then
				window.AcrylicBound = "NovaAcrylic_" .. tostring(window.Gui and window.Gui.Name or "Nova")
				environment.pcall(function()
					runService:UnbindFromRenderStep(window.AcrylicBound)
				end)
				runService:BindToRenderStep(window.AcrylicBound, environment.Enum.RenderPriority.Camera.Value + 1, function()
					window:_acrylicStep()
				end)
			end

			nova.Motion.tween(window.AcrylicDof, "Slow", {NearIntensity = 1})
			return
		end

		if window.AcrylicDof then
			nova.Motion.tween(window.AcrylicDof, "Quick", {NearIntensity = 0})
		end

		local function cleanup()
			if window.AcrylicToken ~= token then
				return
			end

			if window.AcrylicBound then
				local binding = window.AcrylicBound
				window.AcrylicBound = nil
				environment.pcall(function()
					runService:UnbindFromRenderStep(binding)
				end)
			end

			if window.AcrylicPart then
				environment.pcall(function()
					window.AcrylicPart:Destroy()
				end)
				window.AcrylicPart = nil
				window.AcrylicMesh = nil
			end

			if window.AcrylicDof then
				environment.pcall(function()
					window.AcrylicDof:Destroy()
				end)
				window.AcrylicDof = nil
			end
		end

		if window.Destroyed then
			cleanup()
			return
		end

		environment.task.delay(0.22, cleanup)
	end

	function class.SetBlur(window, enabled)
		nova.trace("SetBlur")
		window.BlurEnabled = enabled and true or false
		window.State.set("blur", window.BlurEnabled)
		if window.IsOpen then
			window:_blur(window.BlurEnabled)
		end
	end

	function class._launcher(window, options)
		local utility, textures, theme = nova.U, nova.Tex, nova.Theme
		local saved = window.State.get("launcherPos", nil)
		local position = environment.UDim2.fromOffset(16, 70)
		if type(saved) == "table" and tonumber(saved[1]) and tonumber(saved[2]) then
			position = environment.UDim2.fromOffset(saved[1], saved[2])
		end

		local button = utility.new("TextButton", {
			Name = "Launcher", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = position, Size = environment.UDim2.fromOffset(150, 42), Visible = window.LauncherOn, ZIndex = 25, Parent = window.Gui,
		})
		local scale = utility.new("UIScale", {Parent = button})
		window.LauncherBase = 1
		local shadow = textures.image(button, "shadow9", {
			Name = "Shadow", Position = environment.UDim2.fromOffset(-22, -14), Size = environment.UDim2.new(1, 44, 1, 46),
			SliceScale = 1, ImageTransparency = 0.5, ZIndex = 24,
		})
		local card = utility.new("Frame", {
			Name = "Card", Size = environment.UDim2.new(0, 0, 1, 0), AutomaticSize = environment.Enum.AutomaticSize.X,
			BorderSizePixel = 0, BackgroundTransparency = 0.04, ZIndex = 26, Parent = button,
		})
		theme.bind(card, "BackgroundColor3", "Surface")
		utility.corner(card, 14)
		utility.new("UIGradient", {
			Color = environment.ColorSequence.new(environment.Color3.new(1, 1, 1), environment.Color3.fromRGB(206, 208, 216)),
			Rotation = 90, Parent = card,
		})

		local glow = textures.image(card, "glow", {
			Name = "Glow", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.new(0, 22, 0.5, 0),
			Size = environment.UDim2.fromOffset(120, 90), ImageTransparency = 0.85, ZIndex = 26,
		})
		if glow then
			if options.Logo and options.LogoGlow then
				glow.ImageColor3 = options.LogoGlow
			else
				theme.bind(glow, "ImageColor3", "Accent")
			end
		end

		textures.image(card, "gloss9", {Name = "Gloss", Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.79, ImageTransparency = 0.9, ZIndex = 27})
		local rim = textures.image(card, "rim9", {Name = "Rim", Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.79, ImageTransparency = 0.45, ZIndex = 34})
		if rim then
			theme.bind(rim, "ImageColor3", "Glass")
		else
			theme.bind(utility.stroke(card, environment.Color3.new(1, 1, 1), 1, 0.85), "Color", "Glass")
		end

		local row = utility.new("Frame", {
			Name = "Row", Size = environment.UDim2.new(0, 0, 1, 0), AutomaticSize = environment.Enum.AutomaticSize.X,
			BackgroundTransparency = 1, ZIndex = 28, Parent = card,
		})
		utility.pad(row, 0, 7, 0, 6)
		utility.list(row, 9, environment.Enum.FillDirection.Horizontal, environment.Enum.HorizontalAlignment.Left, environment.Enum.VerticalAlignment.Center)
		local logo = utility.new("Frame", {Name = "Logo", Size = environment.UDim2.fromOffset(30, 30), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 28, Parent = row})
		if options.Logo then
			utility.new("ImageLabel", {
				Name = "Mark", BackgroundTransparency = 1, AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
				Size = environment.UDim2.fromOffset(34, 34), Image = options.Logo, ScaleType = environment.Enum.ScaleType.Fit, ZIndex = 29, Parent = logo,
			})
		else
			nova.tile(logo, {Name = "Face", Size = environment.UDim2.fromScale(1, 1), Color = "Accent", SliceScale = 0.5, Z = 28})
			nova.label({Parent = logo, Text = tostring(options.Initial or string.sub(options.Title or "N", 1, 1)), Font = nova.Font.Heavy(), Size = 15,
				Box = environment.UDim2.fromScale(1, 1), AlignX = environment.Enum.TextXAlignment.Center, Color = "OnAccent", Z = 30})
		end

		local title = nova.label({Parent = row, Text = tostring(options.Title or "Nova"), Font = nova.Font.Bold(), Size = 14,
			Box = environment.UDim2.new(0, 0, 1, 0), Auto = environment.Enum.AutomaticSize.X, Z = 29, Name = "Title"})
		title.LayoutOrder = 2
		local key
		if not window.IsTouch then
			local keyFrame = utility.new("Frame", {Name = "Key", Size = environment.UDim2.fromOffset(0, 20), AutomaticSize = environment.Enum.AutomaticSize.X,
				BorderSizePixel = 0, BackgroundTransparency = 0.45, LayoutOrder = 3, ZIndex = 29, Parent = row})
			theme.bind(keyFrame, "BackgroundColor3", "Elevated")
			utility.corner(keyFrame, 6)
			utility.pad(keyFrame, 0, 7, 0, 7)
			theme.bind(utility.stroke(keyFrame, environment.Color3.new(1, 1, 1), 1, 0.88), "Color", "Glass")
			key = nova.label({Parent = keyFrame, Text = nova.keyName and nova.keyName(window.Key) or window.Key.Name, Font = nova.Font.Semi(), Size = 11,
				Box = environment.UDim2.new(0, 0, 1, 0), Auto = environment.Enum.AutomaticSize.X, Color = "Muted", Z = 30})
		end

		local orb = utility.new("Frame", {Name = "Orb", Size = environment.UDim2.fromOffset(28, 28), BorderSizePixel = 0,
			BackgroundTransparency = 0.35, LayoutOrder = 4, ZIndex = 29, Parent = row})
		theme.bind(orb, "BackgroundColor3", "Elevated")
		utility.corner(orb, environment.UDim.new(1, 0))
		local orbStroke = utility.stroke(orb, environment.Color3.new(1, 1, 1), 1, 0.85)
		theme.bind(orbStroke, "Color", "Glass")
		local chevron = nova.icon({Parent = orb, Icon = "chevron-down", Size = 15, Pos = environment.UDim2.fromScale(0.5, 0.5),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 30})
		window.LauncherParts = {btn = button, card = card, orb = orb, orbStroke = orbStroke, chev = chevron, glow = glow,
			rim = rim, key = key, scale = scale, shadow = shadow}

		local function updateWidth()
			local width = math.ceil(card.AbsoluteSize.X / math.max(scale.Scale, 0.1))
			if width > 0 and button.Size.X.Offset ~= width then
				button.Size = environment.UDim2.fromOffset(width, 42)
			end
		end
		card:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateWidth)
		environment.task.defer(updateWidth)
		local isDragging = window:_launcherInput(button, title)
		window.Launcher = button
		window:OnScreenScale(function(value)
			if not button.Parent then
				return false
			end

			window.LauncherBase = value
			if not isDragging() then
				scale.Scale = value
			end
			environment.task.defer(function()
				environment.pcall(window._clampLauncher, window)
			end)
		end)
		window:_launcherState(false, true)
		utility.connect(window.Gui:GetPropertyChangedSignal("AbsoluteSize"), function()
			environment.task.defer(function()
				environment.pcall(window._clampLauncher, window)
			end)
		end, window.Conns)
		environment.task.spawn(function()
			environment.task.wait(1)
			while button.Parent and not window.Destroyed do
				environment.pcall(window._clampLauncher, window)
				if window.IsTouch and not window.IsOpen and not button.Visible then
					button.Visible = true
				end
				environment.task.wait(2)
			end
		end)
	end

	function class._launcherInput(window, button, title)
		local utility, parts = nova.U, window.LauncherParts
		local tween = nova.Motion.tween
		local easing = environment.Enum.EasingStyle
		local direction = environment.Enum.EasingDirection
		local press = environment.TweenInfo.new(0.1, easing.Quad, direction.Out)
		local release = environment.TweenInfo.new(0.34, easing.Quint, direction.Out)
		local dragging, moved, start, position, input

		button.InputBegan:Connect(function(event)
			if not utility.isClick(event) then
				return
			end

			start, position, input = event.Position, button.Position, event
			dragging = true
			moved = false
			tween(parts.scale, press, {Scale = window.LauncherBase * 0.95})
		end)
		utility.connect(nova.Services.UserInputService.InputChanged, function(event)
			if not dragging or not utility.sameMove(event, input) then
				return
			end

			local delta = event.Position - start
			if delta.Magnitude > 6 then
				moved = true
			end
			if moved then
				local area = window:_launcherArea()
				local x = math.clamp(position.X.Offset + delta.X, 4, math.max(4, area.X - button.AbsoluteSize.X - 4))
				local y = math.clamp(position.Y.Offset + delta.Y, 4, math.max(4, area.Y - button.AbsoluteSize.Y - 4))
				button.Position = environment.UDim2.fromOffset(x, y)
			end
		end, window.Conns)
		utility.connect(nova.Services.UserInputService.InputEnded, function(event)
			if not dragging or not utility.sameEnd(event, input) then
				return
			end

			dragging = false
			tween(parts.scale, release, {Scale = window.LauncherBase})
			if moved then
				window.State.set("launcherPos", {math.floor(button.Position.X.Offset), math.floor(button.Position.Y.Offset)})
				return
			end

			nova.Sound.play("click")
			window:Toggle()
		end, window.Conns)
		button.MouseEnter:Connect(function()
			if parts.rim then tween(parts.rim, "Quick", {ImageTransparency = 0.2}) end
			if parts.shadow then tween(parts.shadow, "Quick", {ImageTransparency = 0.35}) end
			if not dragging then tween(parts.scale, "Quick", {Scale = window.LauncherBase * 1.03}) end
			nova.paint(title, "TextColor3", "Text", "Quick")
			if not window.IsOpen then nova.paint(parts.chev, "ImageColor3", "Text", "Quick") end
		end)
		utility.leave(button, function()
			if parts.rim then tween(parts.rim, "Quick", {ImageTransparency = 0.45}) end
			if parts.shadow then tween(parts.shadow, "Quick", {ImageTransparency = 0.5}) end
			if not dragging then tween(parts.scale, release, {Scale = window.LauncherBase}) end
			if not window.IsOpen then nova.paint(parts.chev, "ImageColor3", "Muted", "Quick") end
		end)

		return function() return dragging end
	end

	function class._launcherArea(window)
		local size = window.Gui and window.Gui.AbsoluteSize
		if not size or size.X < 120 or size.Y < 120 then
			local camera = environment.workspace.CurrentCamera
			return camera and camera.ViewportSize or environment.Vector2.new(1280, 720)
		end

		return size
	end

	function class._clampLauncher(window)
		local launcher = window.Launcher
		if not launcher or not launcher.Parent then
			return
		end

		local area = window:_launcherArea()
		if area.X < 120 or area.Y < 120 then
			return
		end

		local width, height = launcher.AbsoluteSize.X, launcher.AbsoluteSize.Y
		if width < 1 or height < 1 then
			width, height = 150, 42
		end

		local position = launcher.Position
		local x = math.floor(math.clamp(position.X.Offset, 4, math.max(4, area.X - width - 4)))
		local y = math.floor(math.clamp(position.Y.Offset, 4, math.max(4, area.Y - height - 4)))
		if x ~= position.X.Offset or y ~= position.Y.Offset or position.X.Scale ~= 0 or position.Y.Scale ~= 0 then
			launcher.Position = environment.UDim2.fromOffset(x, y)
			environment.pcall(function()
				window.State.set("launcherPos", {x, y})
			end)
		end
	end

	function class._launcherState(window, isOpen, instant)
		local parts = window.LauncherParts
		if not parts then
			return
		end

		local easing = environment.Enum.EasingStyle
		local direction = environment.Enum.EasingDirection
		local info = instant and environment.TweenInfo.new(0) or environment.TweenInfo.new(0.35, easing.Quint, direction.Out)
		local tween = nova.Motion.tween

		tween(parts.chev, info, {Rotation = isOpen and 180 or 0})
		nova.paint(parts.chev, "ImageColor3", isOpen and "Accent" or "Muted", info)
		nova.paint(parts.orb, "BackgroundColor3", isOpen and "Accent" or "Elevated", info)
		tween(parts.orb, info, {BackgroundTransparency = isOpen and 0.8 or 0.35})
		nova.paint(parts.orbStroke, "Color", isOpen and "Accent" or "Glass", info)
		tween(parts.orbStroke, info, {Transparency = isOpen and 0.45 or 0.85})

		if parts.glow then
			tween(parts.glow, info, {ImageTransparency = isOpen and 0.62 or 0.85})
		end
	end

	function class._input(window)
		local input = nova.Services.UserInputService
		nova.U.connect(input.InputBegan, function(event)
			if window.Destroyed or window.Listening then
				return
			end

			if event.KeyCode == window.Key and window.Key ~= environment.Enum.KeyCode.Unknown and not input:GetFocusedTextBox() then
				window:Toggle()
			end
		end, window.Conns)
		nova.U.connect(nova.Services.RunService.RenderStepped, function()
			if not window.Tip.Visible then
				return
			end

			local mouse = input:GetMouseLocation()
			local viewport = environment.workspace.CurrentCamera.ViewportSize
			local size = window.Tip.AbsoluteSize
			local x = math.min(mouse.X + 14, viewport.X - size.X - 6)
			local y = math.min(mouse.Y + 18, viewport.Y - size.Y - 6)
			window.Tip.Position = environment.UDim2.fromOffset(x, y)
		end, window.Conns)
	end

	function class._syncFooter(window)
		local key = nova.keyName and nova.keyName(window.Key) or window.Key.Name
		if window.FooterKey then
			window.FooterKey.Text = key
		end
		if window.LauncherParts and window.LauncherParts.key then
			window.LauncherParts.key.Text = key
		end
		if window.SidebarCollapsed and window.FooterText then
			window.FooterText.TextTransparency = 1
			window.FooterChip.AnchorPoint = environment.Vector2.new(0.5, 0.5)
			window.FooterChip.Position = environment.UDim2.new(0.5, 0, 0.5, 1)
		end
	end

	function class.Notify(window, options)
		if type(options) == "string" then options = {Title = options} end
		options = options or {}
		local kinds = {
			info = {token = "Accent", icon = "bell"}, success = {token = "Success", icon = "circle-check"},
			warning = {token = "Warning", icon = "triangle-alert"}, danger = {token = "Danger", icon = "circle-x"},
			error = {token = "Danger", icon = "circle-x"},
		}
		local kind = kinds[string.lower(tostring(options.Kind or options.Type or "info"))] or kinds.info
		local duration = math.max(tonumber(options.Duration) or 4, 0.5)
		local utility, theme, textures = nova.U, nova.Theme, nova.Tex
		local new, tween = utility.new, nova.Motion.tween
		local udim, vector, enum = environment.UDim2, environment.Vector2, environment.Enum
		local white = environment.Color3.new(1, 1, 1)
		local enter = environment.TweenInfo.new(0.38, enum.EasingStyle.Quint, enum.EasingDirection.Out)
		local exit = environment.TweenInfo.new(0.22, enum.EasingStyle.Quint, enum.EasingDirection.In)

		if not window.ToastLayout then
			window.ToastLayout = utility.list(window.Toasts, 8, enum.FillDirection.Vertical, enum.HorizontalAlignment.Right, enum.VerticalAlignment.Bottom)
		end
		window.ToastOrder = (window.ToastOrder or 0) + 1
		local toast = new("Frame", {Name = "Toast", Size = udim.new(1, 0, 0, 0), BackgroundTransparency = 1,
			LayoutOrder = window.ToastOrder, Parent = window.Toasts})
		local slide = new("Frame", {Name = "Slide", Position = udim.fromOffset(40, 0), Size = udim.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = toast})
		local shadow = textures.image(slide, "shadow9", {Name = "Shadow", Position = udim.fromOffset(-22, -14),
			Size = udim.new(1, 44, 1, 46), SliceScale = 1, ImageTransparency = 1, ZIndex = 0})
		local card = new("CanvasGroup", {Name = "Card", Size = udim.new(1, 0, 0, 52), BorderSizePixel = 0, GroupTransparency = 1, Parent = slide})
		theme.bind(card, "BackgroundColor3", "Surface")
		utility.corner(card, 12)
		new("UIGradient", {Color = environment.ColorSequence.new(white, environment.Color3.fromRGB(214, 216, 224)), Rotation = 90, Parent = card})
		textures.image(card, "gloss9", {Name = "Gloss", Size = udim.fromScale(1, 1), SliceScale = 0.86, ImageTransparency = 0.92, ZIndex = 1})
		local tint = textures.image(card, "glow", {Name = "Tint", AnchorPoint = vector.new(0.5, 0.5), Position = udim.new(0, 30, 0.5, 0),
			Size = udim.fromOffset(150, 110), ImageTransparency = 0.86, ZIndex = 1})
		if tint then theme.bind(tint, "ImageColor3", kind.token) end
		local rim = textures.image(card, "rim9", {Name = "Rim", Size = udim.fromScale(1, 1), SliceScale = 0.86, ImageTransparency = 0.5, ZIndex = 9})
		if rim then
			theme.bind(rim, "ImageColor3", "Glass")
		else
			theme.bind(utility.stroke(card, white, 1, 0.88), "Color", "Glass")
		end
		local badge = new("Frame", {Name = "Badge", AnchorPoint = vector.new(0, 0.5), Position = udim.new(0, 13, 0.5, 0),
			Size = udim.fromOffset(30, 30), BorderSizePixel = 0, BackgroundTransparency = 0.84, ZIndex = 3, Parent = card})
		theme.bind(badge, "BackgroundColor3", kind.token)
		utility.corner(badge, environment.UDim.new(1, 0))
		theme.bind(utility.stroke(badge, white, 1, 0.62), "Color", kind.token)
		nova.icon({Parent = badge, Icon = options.Icon or kind.icon, Size = 15, Pos = udim.fromScale(0.5, 0.5),
			Anchor = vector.new(0.5, 0.5), Color = kind.token, Z = 4})
		local body = new("Frame", {Name = "Body", AnchorPoint = vector.new(0, 0.5), Position = udim.new(0, 54, 0.5, 0),
			Size = udim.new(1, -86, 0, 0), AutomaticSize = enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 3, Parent = card})
		utility.pad(body, 11, 0, 11, 0)
		utility.list(body, 2)
		nova.label({Parent = body, Text = options.Title or nova.tr("Notification"), Font = nova.Font.Semi(), Size = 14,
			Box = udim.new(1, 0, 0, 17), Truncate = true, Z = 4, Name = "Title"})
		if options.Text and options.Text ~= "" then
			nova.label({Parent = body, Text = options.Text, Font = nova.Font.Regular(), Size = 12, Box = udim.new(1, 0, 0, 0),
				Auto = enum.AutomaticSize.Y, Wrap = true, Rich = true, Color = "Muted", Z = 4, Name = "Text"}).LayoutOrder = 1
		end
		local close = new("TextButton", {Name = "Close", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			AnchorPoint = vector.new(1, 0.5), Position = udim.new(1, -8, 0.5, 0), Size = udim.fromOffset(22, 22), ZIndex = 11, Parent = card})
		local face = new("Frame", {Name = "Face", Size = udim.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 11, Parent = close})
		theme.bind(face, "BackgroundColor3", "Elevated")
		utility.corner(face, 7)
		local closeIcon = nova.icon({Parent = close, Icon = "x", Size = 12, Pos = udim.fromScale(0.5, 0.5), Anchor = vector.new(0.5, 0.5), Color = "Muted", Z = 12})
		closeIcon.ImageTransparency = 1
		local timer = new("Frame", {Name = "Timer", AnchorPoint = vector.new(0, 1), Position = udim.fromScale(0, 1),
			Size = udim.new(1, 0, 0, 2), BorderSizePixel = 0, BackgroundTransparency = 0.35, ZIndex = 8, Parent = card})
		theme.bind(timer, "BackgroundColor3", kind.token)
		local hit = new("TextButton", {Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = udim.fromScale(1, 1), ZIndex = 10, Parent = card})

		local function resizeCard()
			local height = math.ceil(body.AbsoluteSize.Y / math.max(window.ToastScale.Scale, 0.1))
			if height > 0 then
				local size = udim.new(1, 0, 0, math.max(52, height))
				card.Size, slide.Size = size, size
			end
		end
		body:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCard)
		environment.task.defer(resizeCard)
		local dismissed, hovered = false, false
		local function dismiss()
			if dismissed then return end
			dismissed = true
			tween(slide, exit, {Position = udim.fromOffset(60, 0)})
			tween(card, exit, {GroupTransparency = 1})
			if shadow then tween(shadow, exit, {ImageTransparency = 1}) end
			environment.task.delay(0.2, function()
				tween(toast, "Base", {Size = udim.new(1, 0, 0, 0)})
				environment.task.delay(0.28, function() toast:Destroy() end)
			end)
		end
		hit.MouseButton1Click:Connect(function()
			if options.OnClick then environment.task.spawn(options.OnClick) end
			dismiss()
		end)
		close.MouseButton1Click:Connect(dismiss)
		local function hover(value)
			hovered = value
			tween(closeIcon, "Quick", {ImageTransparency = value and 0.1 or 1})
			tween(face, "Quick", {BackgroundTransparency = value and 0.35 or 1})
			if rim then tween(rim, "Quick", {ImageTransparency = value and 0.3 or 0.5}) end
		end
		hit.MouseEnter:Connect(function() hover(true) end)
		utility.leave(hit, function() hover(false) end)
		close.MouseEnter:Connect(function()
			hover(true)
			tween(closeIcon, "Quick", {ImageColor3 = theme.resolve("Text")})
		end)
		utility.leave(close, function() tween(closeIcon, "Quick", {ImageColor3 = theme.resolve("Muted")}) end)
		local function resizeToast(animated)
			if dismissed then return end
			local height = slide.AbsoluteSize.Y / math.max(window.ToastScale.Scale, 0.1)
			local size = udim.new(1, 0, 0, height)
			if animated then tween(toast, "Base", {Size = size}) else toast.Size = size end
		end
		slide:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() resizeToast(false) end)
		environment.task.defer(function()
			environment.task.wait()
			resizeToast(true)
			tween(slide, enter, {Position = udim.fromOffset(0, 0)})
			tween(card, enter, {GroupTransparency = 0})
			if shadow then tween(shadow, enter, {ImageTransparency = 0.45}) end
			local remaining = duration
			while not dismissed and remaining > 0 do
				local elapsed = environment.task.wait()
				if not hovered then remaining -= elapsed end
				timer.Size = udim.new(math.clamp(remaining / duration, 0, 1), 0, 0, 2)
			end
			dismiss()
		end)
		if options.Sound ~= false then nova.Sound.play("notify") end
		return {Dismiss = dismiss}
	end

	function class.RegisterKeybind(window, entry)
		window.KeybindEntries = window.KeybindEntries or {}
		table.insert(window.KeybindEntries, entry)
		window:_kbDirty()
	end

	function class._kbDirty(window)
		if window.KbPending or window.Destroyed then return end
		window.KbPending = true
		environment.task.defer(function()
			window.KbPending = false
			if window.KeybindFrame and not window.Destroyed then window:_kbRebuild() end
		end)
	end

	function class._kbCancel(window)
		if not window.KbCap then return end
		window.KbCap = nil
		environment.task.defer(function() if not window.KbCap then window.Listening = false end end)
	end

	function class._kbCapture(window, row)
		if window.KbCap == row then return end
		window:_kbCancel()
		window.KbCap = row
		row.keyButton.Text = "вЂ¦"
		environment.task.defer(function() if window.KbCap == row then window.Listening = true end end)
	end

	function class._kbInput(window, input)
		local row = window.KbCap
		if not row or not window.Listening then return end

		local kind = input.UserInputType
		local key
		if kind == environment.Enum.UserInputType.Keyboard then
			if input.KeyCode == environment.Enum.KeyCode.Escape then window:_kbCancel(); window:_kbRebuild(); return end
			if input.KeyCode == environment.Enum.KeyCode.Backspace or input.KeyCode == environment.Enum.KeyCode.Delete then
				nova.Sound.play("tick")
				pcall(row.entry.set, nil)
				window:_kbCancel()
				window:_kbRebuild()
				return
			end
			if input.KeyCode ~= environment.Enum.KeyCode.Unknown then key = input.KeyCode end
		end
		if kind == environment.Enum.UserInputType.MouseButton2 or kind == environment.Enum.UserInputType.MouseButton3 then
			window.KbBoundAt = environment.os.clock()
			key = kind
		end
		if kind == environment.Enum.UserInputType.MouseButton1 or kind == environment.Enum.UserInputType.Touch then
			window.KbBoundAt = environment.os.clock()
			window:_kbCancel()
			window:_kbRebuild()
			return
		end
		if not key then return end

		nova.Sound.play("tick")
		pcall(row.entry.set, key)
		window:_kbCancel()
		window:_kbRebuild()
	end

	function class._kbRow(window, entry)
		local utility = nova.U
		local row = {entry = entry}
		row.frame = utility.new("TextButton", {Name = "Entry", Text = "", AutoButtonColor = false, Size = environment.UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = environment.Color3.new(1, 1, 1), BackgroundTransparency = 0.92, BorderSizePixel = 0, ZIndex = 8, Parent = window.KeybindList})
		utility.corner(row.frame, 10)
		row.label = utility.new("TextLabel", {Name = "Name", Text = "", BackgroundTransparency = 1, Position = environment.UDim2.fromOffset(9, 0),
			Size = environment.UDim2.new(1, -86, 1, 0), FontFace = nova.Font.Semi(), TextSize = 11, TextXAlignment = environment.Enum.TextXAlignment.Left,
			TextTruncate = environment.Enum.TextTruncate.AtEnd, ZIndex = 9, Parent = row.frame})
		row.switch = utility.new("TextLabel", {Name = "Switch", Text = "", BackgroundTransparency = 1, AnchorPoint = environment.Vector2.new(1, 0.5),
			Position = environment.UDim2.new(1, -8, 0.5, 0), Size = environment.UDim2.fromOffset(20, 18), FontFace = nova.Font.Bold(), TextSize = 10,
			ZIndex = 9, Parent = row.frame})
		row.keyButton = utility.new("TextButton", {Name = "Key", Text = "вЂ”", AutoButtonColor = false, AnchorPoint = environment.Vector2.new(1, 0.5),
			Position = environment.UDim2.new(1, -30, 0.5, 0), Size = environment.UDim2.fromOffset(48, 18), BackgroundColor3 = environment.Color3.new(1, 1, 1),
			BackgroundTransparency = 0.88, BorderSizePixel = 0, FontFace = nova.Font.Bold(), TextSize = 10, TextColor3 = environment.Color3.new(1, 1, 1),
			ZIndex = 10, Parent = row.frame})
		utility.corner(row.keyButton, 4)
		row.keyButton.Visible = not window.IsTouch
		row.frame.MouseButton1Click:Connect(function()
			if window.KbCap or type(entry.toggle) ~= "function" then return end
			pcall(entry.toggle)
			window:_kbDirty()
		end)
		row.keyButton.MouseButton1Click:Connect(function()
			if type(entry.set) ~= "function" or window.KbCap == row or environment.os.clock() - (window.KbBoundAt or 0) < 0.3 then return end
			nova.Sound.play("click")
			window:_kbCapture(row)
		end)
		row.keyButton.MouseButton2Click:Connect(function()
			if type(entry.set) ~= "function" or window.KbCap or environment.os.clock() - (window.KbBoundAt or 0) < 0.3 then return end
			nova.Sound.play("tick")
			pcall(entry.set, nil)
			window:_kbRebuild()
		end)
		return row
	end

	function class._kbRebuild(window, immediate)
		if not window.KeybindFrame or window.Destroyed then return end

		local rows, onCount, bindCount = NovaWindow.keybindSnapshot(environment, window)
		local present = {}
		for _, item in rows do
			local row = window.KbRows[item.entry]
			if not row then row = window:_kbRow(item.entry); window.KbRows[item.entry] = row end
			present[item.entry] = true
			row.key = item.key
			if row.frame.LayoutOrder ~= item.order then row.frame.LayoutOrder = item.order end
			if row.label.Text ~= item.name then row.label.Text = item.name end
			if row.on ~= item.on then
				row.on = item.on
				row.label.TextColor3 = item.on and environment.Color3.new(1, 1, 1) or environment.Color3.fromRGB(200, 203, 214)
				row.frame.BackgroundColor3 = item.on and nova.Theme.resolve("Accent") or environment.Color3.new(1, 1, 1)
				row.frame.BackgroundTransparency = item.on and 0.2 or 0.92
				row.switch.Text = type(item.entry.toggle) == "function" and (item.on and "в—Џ" or "в—‹") or ""
				row.switch.TextColor3 = item.on and nova.Theme.resolve("Accent") or environment.Color3.fromRGB(200, 203, 214)
			end
			if window.KbCap ~= row then
				local text = item.key and nova.keyName(item.key) or "вЂ”"
				if row.keyButton.Text ~= text then row.keyButton.Text = text end
			end
		end
		for entry, row in window.KbRows do
			if present[entry] then continue end
			if window.KbCap == row then window:_kbCancel() end
			row.frame:Destroy()
			window.KbRows[entry] = nil
		end

		window.KbEmpty.Visible = #rows == 0
		local count = tostring(onCount) .. "/" .. tostring(bindCount)
		if window.KbCountLabel.Text ~= count then window.KbCountLabel.Text = count end
		window.KeybindList.Visible = not window.KbFold
		local listHeight = #rows > 0 and #rows * 26 + (#rows - 1) * 3 or 18
		local height = window.KbFold and 32 or 32 + math.min(5 + listHeight + 6, 280)
		if window.KbHeight == height then return end
		window.KbHeight = height
		local size = environment.UDim2.fromOffset(190, height)
		if immediate or not window.KeybindFrame.Visible then window.KeybindFrame.Size = size; return end
		nova.Motion.tween(window.KeybindFrame, "Base", {Size = size})
	end

	function class._overlayBehavior(window, frame, handle, positionKey)
		local utility, input = nova.U, nova.Services.UserInputService
		local scale = utility.new("UIScale", {Parent = frame})
		local function clamp()
			local camera = environment.workspace.CurrentCamera
			if not camera or not frame.Parent or frame.AbsoluteSize.X <= 0 or frame.AbsoluteSize.Y <= 0 then return end
			local viewport, position = camera.ViewportSize, frame.Position
			local left = math.clamp(position.X.Offset, 4, math.max(4, viewport.X - frame.AbsoluteSize.X - 4))
			local top = math.clamp(position.Y.Offset, 4, math.max(4, viewport.Y - frame.AbsoluteSize.Y - 4))
			if left ~= position.X.Offset or top ~= position.Y.Offset then frame.Position = environment.UDim2.fromOffset(left, top) end
		end
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() environment.task.defer(clamp) end)
		frame:GetPropertyChangedSignal("Visible"):Connect(function() if frame.Visible then environment.task.defer(clamp) end end)
		window:OnScreenScale(function(value)
			if not frame.Parent then return false end
			scale.Scale = value
			environment.task.defer(clamp)
		end)
		local drag, origin, start
		handle.InputBegan:Connect(function(event)
			if not utility.isClick(event) then return end
			drag, origin, start = event, event.Position, frame.Position
			local connection
			connection = event.Changed:Connect(function()
				if event.UserInputState ~= environment.Enum.UserInputState.End then return end
				drag = nil
				connection:Disconnect()
				window.State.set(positionKey, {math.floor(frame.Position.X.Offset), math.floor(frame.Position.Y.Offset)})
			end)
		end)
		utility.connect(input.InputChanged, function(event)
			if not drag or not utility.sameMove(event, drag) then return end
			local delta = event.Position - origin
			frame.Position = environment.UDim2.fromOffset(start.X.Offset + delta.X, start.Y.Offset + delta.Y)
			clamp()
		end, window.Conns)
	end

	function class._buildKeybindList(window)
		local utility, input = nova.U, nova.Services.UserInputService
		local saved = window.State.get("keybindPos", nil)
		local x, y = 16, 190
		if type(saved) == "table" and tonumber(saved[1]) and tonumber(saved[2]) then x, y = tonumber(saved[1]), tonumber(saved[2]) end
		local frame = utility.new("Frame", {Name = "KeybindList", Position = environment.UDim2.fromOffset(x, y), Size = environment.UDim2.fromOffset(190, 62),
			BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = window.Gui})
		local card = utility.new("Frame", {Name = "Card", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0,
			BackgroundTransparency = 0.04, ClipsDescendants = true, ZIndex = 6, Parent = frame})
		nova.Theme.bind(card, "BackgroundColor3", "Surface")
		utility.corner(card, 11)
		local head = utility.new("Frame", {Name = "Head", Active = true, Size = environment.UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, ZIndex = 7, Parent = card})
		utility.new("TextLabel", {Name = "Title", Text = nova.tr("Keybinds"), BackgroundTransparency = 1, Position = environment.UDim2.fromOffset(11, 0),
			Size = environment.UDim2.new(1, -95, 1, 0), TextColor3 = environment.Color3.new(1, 1, 1), TextXAlignment = environment.Enum.TextXAlignment.Left,
			FontFace = nova.Font.Bold(), TextSize = 13, ZIndex = 8, Parent = head})
		local count = utility.new("TextLabel", {Name = "Count", Text = "0/0", BackgroundTransparency = 1, Position = environment.UDim2.new(1, -100, 0, 0),
			Size = environment.UDim2.fromOffset(40, 32), TextColor3 = environment.Color3.new(1, 1, 1), FontFace = nova.Font.Bold(), TextSize = 10, ZIndex = 8, Parent = head})
		local edit = utility.new("TextButton", {Name = "Edit", Text = "вњЋ", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = environment.UDim2.new(1, -55, 0, 0), Size = environment.UDim2.fromOffset(22, 32), TextColor3 = environment.Color3.new(1, 1, 1),
			FontFace = nova.Font.Bold(), TextSize = 14, Visible = not window.IsTouch, ZIndex = 9, Parent = head})
		local fold = utility.new("TextButton", {Name = "Fold", Text = "вЊѓ", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = environment.UDim2.new(1, -30, 0, 0), Size = environment.UDim2.fromOffset(22, 32), TextColor3 = environment.Color3.new(1, 1, 1),
			FontFace = nova.Font.Bold(), TextSize = 14, ZIndex = 9, Parent = head})
		local list = utility.new("ScrollingFrame", {Name = "List", Position = environment.UDim2.fromOffset(0, 32), Size = environment.UDim2.new(1, 0, 1, -32),
			BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollingDirection = environment.Enum.ScrollingDirection.Y,
			CanvasSize = environment.UDim2.new(), AutomaticCanvasSize = environment.Enum.AutomaticSize.Y, ZIndex = 7, Parent = card})
		utility.list(list, 3)
		utility.pad(list, 5, 6, 6, 5)
		local empty = utility.new("TextLabel", {Name = "Empty", Text = "вЂ”", Size = environment.UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
			FontFace = nova.Font.Medium(), TextSize = 11, TextColor3 = environment.Color3.fromRGB(155, 158, 168), LayoutOrder = 1000000, ZIndex = 8, Parent = list})
		window.KeybindFrame, window.KeybindList, window.KbRows = frame, list, {}
		window.KbEmpty, window.KbCountLabel = empty, count
		window.KbEdit, window.KbFold = false, window.State.get("keybindFold", false) == true
		fold.Text = window.KbFold and "вЊ„" or "вЊѓ"
		nova.Theme.onChange(function(role)
			if role ~= "Accent" or window.Destroyed then return end
			for _, row in window.KbRows do row.on = nil end
			window:_kbDirty()
		end)
		edit.MouseButton1Click:Connect(function()
			nova.Sound.play("click")
			window:_kbCancel()
			window.KbEdit = not window.KbEdit
			if window.KbEdit and window.KbFold then window.KbFold = false; window.State.set("keybindFold", false); fold.Text = "вЊѓ" end
			window:_kbRebuild()
		end)
		fold.MouseButton1Click:Connect(function()
			nova.Sound.play("tick")
			window:_kbCancel()
			window.KbFold = not window.KbFold
			if window.KbFold then window.KbEdit = false end
			window.State.set("keybindFold", window.KbFold)
			fold.Text = window.KbFold and "вЊ„" or "вЊѓ"
			window:_kbRebuild()
		end)

		window:_overlayBehavior(frame, head, "keybindPos")
		utility.connect(input.InputBegan, function(event) window:_kbInput(event) end, window.Conns)
		local elapsed = 0
		utility.connect(nova.Services.RunService.Heartbeat, function(delta)
			if window.Destroyed or not frame.Visible then return end
			elapsed += delta
			if elapsed < 0.08 then return end
			elapsed = 0
			window:_kbRebuild(true)
		end, window.Conns)
	end

	function class.SetKeybindList(window, enabled)
		enabled = not not enabled
		window.State.set("keybindList", enabled)
		if enabled then
			if not window.KeybindFrame then window:_buildKeybindList() end
			window.KeybindFrame.Visible = true
			window.KbHeight = nil
			window:_kbRebuild(true)
			return
		end
		if window.KeybindFrame then window:_kbCancel(); window.KeybindFrame.Visible = false end
	end

	function class.SetWatermarkTitle(window, title)
		window.WatermarkTitleText = title
		local label = window.WatermarkTitle
		if not label then return end

		if title then
			label.AutomaticSize = environment.Enum.AutomaticSize.None
			label.Size = environment.UDim2.new(0, 38, 1, 0)
			label.TextXAlignment = environment.Enum.TextXAlignment.Center
			label.Text = title
			return
		end
		label.Size = environment.UDim2.new(0, 0, 1, 0)
		label.AutomaticSize = environment.Enum.AutomaticSize.X
		label.TextXAlignment = environment.Enum.TextXAlignment.Left
		label.Text = tostring(window.TitleLabel and window.TitleLabel.Text or "Nova")
	end

	function class._buildWatermark(window)
		local utility, theme = nova.U, nova.Theme
		local saved = window.State.get("watermarkPos", nil)
		local x, y = 16, 16
		if type(saved) == "table" and tonumber(saved[1]) and tonumber(saved[2]) then x, y = tonumber(saved[1]), tonumber(saved[2]) end
		local frame = utility.new("Frame", {Name = "Watermark", Position = environment.UDim2.fromOffset(x, y), Size = environment.UDim2.fromOffset(0, 34),
			AutomaticSize = environment.Enum.AutomaticSize.X, BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = window.Gui})
		local card = utility.new("Frame", {Name = "Card", Size = environment.UDim2.new(0, 0, 1, 0), AutomaticSize = environment.Enum.AutomaticSize.X,
			BorderSizePixel = 0, BackgroundTransparency = 0.04, Active = true, ZIndex = 6, Parent = frame})
		theme.bind(card, "BackgroundColor3", "Surface")
		utility.corner(card, 12)
		local row = utility.new("Frame", {Name = "Row", Size = environment.UDim2.new(0, 0, 1, 0), AutomaticSize = environment.Enum.AutomaticSize.X,
			BackgroundTransparency = 1, ZIndex = 7, Parent = card})
		utility.pad(row, 0, 12, 0, 8)
		utility.list(row, 10, environment.Enum.FillDirection.Horizontal, environment.Enum.HorizontalAlignment.Left, environment.Enum.VerticalAlignment.Center)
		local logo = utility.new("Frame", {Name = "Logo", Size = environment.UDim2.fromOffset(22, 22), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 7, Parent = row})
		if window.LogoAsset then
			utility.new("ImageLabel", {Name = "Mark", BackgroundTransparency = 1, AnchorPoint = environment.Vector2.new(0.5, 0.5),
				Position = environment.UDim2.fromScale(0.5, 0.5), Size = environment.UDim2.fromOffset(26, 26), Image = window.LogoAsset,
				ScaleType = environment.Enum.ScaleType.Fit, ZIndex = 8, Parent = logo})
		end
		if not window.LogoAsset then
			nova.label({Parent = logo, Text = tostring(window.Initial or "N"), Font = nova.Font.Heavy(), Size = 11,
				Box = environment.UDim2.fromScale(1, 1), AlignX = environment.Enum.TextXAlignment.Center, Color = "OnAccent", Z = 9})
		end
		local title = nova.label({Parent = row, Name = "Title", Text = tostring(window.TitleLabel and window.TitleLabel.Text or "Nova"),
			Font = nova.Font.Bold(), Size = 13, Box = environment.UDim2.new(0, 0, 1, 0), Auto = environment.Enum.AutomaticSize.X, Z = 8})
		title.LayoutOrder = 2
		window.WatermarkTitle = title
		if window.WatermarkTitleText then window:SetWatermarkTitle(window.WatermarkTitleText) end

		local function separator(order)
			local line = utility.new("Frame", {Name = "Sep", Size = environment.UDim2.fromOffset(1, 14), BorderSizePixel = 0,
				BackgroundTransparency = 0.82, LayoutOrder = order, ZIndex = 8, Parent = row})
			theme.bind(line, "BackgroundColor3", "Glass")
		end
		local function stat(order, icon, suffix, width)
			local group = utility.new("Frame", {Name = "Stat", Size = environment.UDim2.new(0, 0, 1, 0), AutomaticSize = environment.Enum.AutomaticSize.X,
				BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 8, Parent = row})
			utility.list(group, 5, environment.Enum.FillDirection.Horizontal, environment.Enum.HorizontalAlignment.Left, environment.Enum.VerticalAlignment.Center)
			local picture = nova.icon({Parent = group, Icon = icon, Size = 14, Color = "Muted", Z = 8})
			picture.LayoutOrder = 1
			local value = nova.label({Parent = group, Name = "Value", Text = "--", Font = nova.Font.Bold(), Size = 13,
				Box = environment.UDim2.new(0, width, 1, 0), AlignX = environment.Enum.TextXAlignment.Right, Color = "Text", Z = 8})
			value.LayoutOrder = 2
			local label = nova.label({Parent = group, Name = "Suffix", Text = suffix, Font = nova.Font.Medium(), Size = 10,
				Box = environment.UDim2.new(0, 0, 1, 0), Auto = environment.Enum.AutomaticSize.X, Color = "Faint", Z = 8})
			label.LayoutOrder = 3
			return {icon = picture, value = value}
		end
		separator(3)
		local fps = stat(4, "gauge", "FPS", 28)
		separator(5)
		local ping = stat(6, "wifi", "MS", 30)
		window:_overlayBehavior(frame, card, "watermarkPos")
		window.WatermarkFrame = frame
		if saved == nil then
			environment.task.defer(function()
				local camera = environment.workspace.CurrentCamera
				if camera and card.AbsoluteSize.X > 0 then frame.Position = environment.UDim2.fromOffset(math.floor(camera.ViewportSize.X - card.AbsoluteSize.X - 16), 16) end
			end)
		end

		local frames, started = 0, environment.os.clock()
		utility.connect(nova.Services.RunService.RenderStepped, function()
			local now = environment.os.clock()
			if not frame.Visible then frames, started = 0, now; return end
			frames += 1
			local elapsed = now - started
			if elapsed < 0.5 then return end

			local value = math.floor(frames / elapsed + 0.5)
			frames, started = 0, now
			fps.value.Text = tostring(value)
			local fpsTone = value >= 55 and "Success" or (value >= 30 and "Warning" or "Danger")
			if fps.tone ~= fpsTone then
				fps.tone = fpsTone
				nova.paint(fps.icon, "ImageColor3", fpsTone, "Base")
				nova.paint(fps.value, "TextColor3", fpsTone, "Base")
			end
			local latency
			pcall(function() latency = nova.Services.Players.LocalPlayer:GetNetworkPing() * 1000 end)
			if not latency then pcall(function() latency = environment.game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end) end
			if not latency then ping.value.Text = "--"; return end

			value = math.floor(latency + 0.5)
			ping.value.Text = tostring(value)
			local pingTone = value <= 90 and "Success" or (value <= 180 and "Warning" or "Danger")
			if ping.tone ~= pingTone then
				ping.tone = pingTone
				nova.paint(ping.icon, "ImageColor3", pingTone, "Base")
				nova.paint(ping.value, "TextColor3", pingTone, "Base")
			end
		end, window.Conns)
	end

	function class.SetWatermark(window, enabled)
		enabled = not not enabled
		window.State.set("watermark", enabled)
		if enabled then
			if not window.WatermarkFrame then window:_buildWatermark() end
			window.WatermarkFrame.Visible = true
			return
		end
		if window.WatermarkFrame then window.WatermarkFrame.Visible = false end
	end

	function class.OnKeyChanged(window, callback)
		window.KeyListeners = window.KeyListeners or {}
		table.insert(window.KeyListeners, callback)
	end

	function class.SetKey(window, key)
		if environment.typeof(key) ~= "EnumItem" or key.EnumType ~= environment.Enum.KeyCode then
			return
		end

		window.Key = key
		window.State.set("menuKey", key.Name)
		window:_syncFooter()
		for _, callback in ipairs(window.KeyListeners or {}) do
			environment.task.spawn(environment.pcall, callback, key)
		end
	end

	function class.SetTitle(window, title, subtitle)
		if title then
			window.TitleLabel.Text = title
		end
		if subtitle then
			window.SubtitleLabel.Text = subtitle
		end
	end

	function class.ShowTip(window, text)
		if not text or text == "" or not window.TooltipsOn or window.IsTouch then
			return
		end

		window.TipToken = (window.TipToken or 0) + 1
		local token = window.TipToken
		environment.task.delay(0.35, function()
			if window.TipToken ~= token or window.Destroyed then
				return
			end

			window.TipLabel.Text = nova.tr(text)
			window.Tip.Visible = true
			window.Tip.BackgroundTransparency = 1
			window.TipLabel.TextTransparency = 1
			nova.Motion.tween(window.Tip, "Quick", {BackgroundTransparency = 0})
			nova.Motion.tween(window.TipLabel, "Quick", {TextTransparency = 0})
		end)
	end

	function class.HideTip(window)
		window.TipToken = (window.TipToken or 0) + 1
		window.Tip.Visible = false
	end

	function class._launcherPoint(window)
		local launcher = window.Launcher
		if not launcher or not launcher.Visible or not launcher.Parent or not nova.Motion.enabled then
			return nil
		end

		local point = launcher.AbsolutePosition + launcher.AbsoluteSize / 2 - window.Gui.AbsolutePosition
		return environment.UDim2.fromOffset(math.floor(point.X), math.floor(point.Y))
	end

	function class._scalingDefer(window, callback)
		window.ScaleDeferred = window.ScaleDeferred or {}
		window.ScaleDeferred[callback] = true
	end

	function class._endScaling(window)
		window.Scaling = false
		local deferred = window.ScaleDeferred
		window.ScaleDeferred = nil

		if deferred then
			for callback in pairs(deferred) do
				environment.pcall(callback)
			end
		end
	end

	function class._stopGenie(window)
		for _, key in ipairs({"GeniePos", "GenieScale"}) do
			if window[key] then
				environment.pcall(function()
					window[key]:Cancel()
				end)
				window[key] = nil
			end
		end
	end

	function class.Open(window)
		nova.trace("Open")
		if window.Destroyed or window.IsOpen then
			return
		end

		window.IsOpen = true
		window.OpenToken = (window.OpenToken or 0) + 1
		local token = window.OpenToken
		window:_stopGenie()
		local position = window:_placeOnScreen(window.HomePos or window.Root.Position)
		window.HomePos = nil
		window.Root.Position = position
		local launcher = window.GenieAnim and window:_launcherPoint() or nil

		if window.IsTouch and window.Launcher then
			window.Launcher.Visible = false
		end

		local scale = window.AutoScale * window.UserScale
		local tween = nova.Motion.tween
		local easing = environment.Enum.EasingStyle
		local direction = environment.Enum.EasingDirection
		local fade = environment.TweenInfo.new(0.28, easing.Quad, direction.Out)
		window.Win.GroupTransparency = 1

		if launcher then
			local genie = environment.TweenInfo.new(0.44, easing.Quint, direction.Out)
			window.Scaling = true
			window.Root.Position = launcher
			window.Scale.Scale = scale * 0.12
			window:_syncLayers()
			window.Root.Visible = true
			window.FloatLayer.Visible = true
			window.GeniePos = tween(window.Root, genie, {Position = position})
			window.GenieScale = tween(window.Scale, genie, {Scale = scale})
			tween(window.Win, fade, {GroupTransparency = 0})
			environment.task.delay(genie.Time + 0.03, function()
				if window.OpenToken == token then
					window:_endScaling()
				end
			end)
		end

		if not launcher then
			window:_endScaling()
			window.Scale.Scale = scale
			window:_syncLayers()
			window.Root.Visible = true
			window.FloatLayer.Visible = true
			tween(window.Win, fade, {GroupTransparency = 0})
		end

		if window.WindowShadow then
			window.WindowShadow.ImageTransparency = 1
			tween(window.WindowShadow, "Slow", {ImageTransparency = 0.45})
		end

		window:_blur(true)
		window:_launcherState(true)
		nova.Sound.play("open")

		if not window.Current and window.TabList[1] then
			window:SelectTab(window.TabList[1])
		end

		environment.task.defer(function()
			window:_layoutTabs(false)
		end)
	end

	function class.Close(window)
		nova.trace("Close")
		if window.Destroyed or not window.IsOpen then
			return
		end

		window.IsOpen = false
		window.OpenToken = (window.OpenToken or 0) + 1
		local token = window.OpenToken
		window:ClosePopups()
		window:HideTip()
		window:_stopGenie()

		if window.Launcher then
			window.Launcher.Visible = window.LauncherOn
		end

		local scale = window.AutoScale * window.UserScale
		local launcher = window.GenieAnim and window:_launcherPoint() or nil
		local duration = 0.2
		local tween = nova.Motion.tween
		local easing = environment.Enum.EasingStyle
		local direction = environment.Enum.EasingDirection

		if launcher then
			local genie = environment.TweenInfo.new(0.3, easing.Quart, direction.In)
			window.Scaling = true
			window.HomePos = window.Root.Position
			window.GeniePos = tween(window.Root, genie, {Position = launcher})
			window.GenieScale = tween(window.Scale, genie, {Scale = scale * 0.12})
			tween(window.Win, environment.TweenInfo.new(0.26, easing.Quad, direction.In), {GroupTransparency = 1})
			duration = genie.Time + 0.03
			local parts = window.LauncherParts

			if parts then
				environment.task.delay(0.24, function()
					if window.OpenToken ~= token then
						return
					end

					tween(parts.scale, environment.TweenInfo.new(0.12, easing.Quad, direction.Out), {Scale = window.LauncherBase * 1.08})
					environment.task.delay(0.12, function()
						tween(parts.scale, environment.TweenInfo.new(0.3, easing.Quint, direction.Out), {Scale = window.LauncherBase})
					end)
				end)
			end
		end

		if not launcher then
			tween(window.Win, "Exit", {GroupTransparency = 1})
		end

		if window.WindowShadow then
			tween(window.WindowShadow, "Exit", {ImageTransparency = 1})
		end

		window:_blur(false)
		window:_launcherState(false)
		nova.Sound.play("close")
		environment.task.delay(duration, function()
			if window.IsOpen or window.OpenToken ~= token then
				return
			end

			window:_stopGenie()
			window.Root.Visible = false
			if window.HomePos then
				window.Root.Position = window.HomePos
				window.HomePos = nil
			end
			window.Scale.Scale = scale
			environment.task.defer(function()
				if not window.IsOpen and window.OpenToken == token then
					window:_endScaling()
				end
			end)
		end)
	end

	function class.RegistryCount(window)
		return nova.U.regCount()
	end

	function class.Toggle(window)
		if window.IsOpen then
			window:Close()
			return
		end

		window:Open()
	end

	function class.Destroy(window)
		if window.Destroyed then
			return
		end

		window.Destroyed = true
		window:_blur(false)
		for _, connection in ipairs(window.Conns) do
			environment.pcall(function()
				connection:Disconnect()
			end)
		end

		environment.pcall(function() window.Gui:Destroy() end)
		environment.pcall(function() window.Parking:Destroy() end)
		if window.OnDestroy then
			environment.pcall(window.OnDestroy)
		end
	end

	function class.ClosePopups(window)
		for _, popup in environment.ipairs(window.Popups) do
			environment.pcall(popup.close)
		end

		window.Popups = {}
		window.Catcher.Visible = false
	end

	function class.OpenPopup(window, popup)
		nova.trace("OpenPopup")
		window:ClosePopups()
		table.insert(window.Popups, popup)
		window.Catcher.Visible = true
	end

	function class.PointerOverUI(window)
		if window.Destroyed then
			return false
		end

		local mouse = nova.U.mouse()
		local function contains(object)
			if not object or not object.Visible then
				return false
			end

			local position, size = object.AbsolutePosition, object.AbsoluteSize
			return mouse.X >= position.X and mouse.X <= position.X + size.X
				and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
		end

		if window.IsOpen and contains(window.Root) then
			return true
		end

		for _, layer in environment.ipairs({window.FloatLayer, window.PopLayer}) do
			for _, object in environment.ipairs(layer:GetChildren()) do
				if object:IsA("GuiObject") and contains(object) then
					return true
				end
			end
		end

		return contains(window.KeybindFrame) or contains(window.WatermarkFrame)
			or contains(window.FlingFrame) or contains(window.Launcher)
	end

	function class.PopupShell(window, width, height)
		local utility = nova.U
		local textures = nova.Tex
		local frame = utility.new("Frame", {
			Name = "PopupFrame", BackgroundTransparency = 1, Size = environment.UDim2.fromOffset(width, height),
			ZIndex = 2, Parent = window.PopLayer,
		})
		textures.image(frame, "shadow9", {
			Name = "Shadow", Position = environment.UDim2.fromOffset(-30, -22), Size = environment.UDim2.new(1, 60, 1, 64),
			SliceScale = 1, ImageTransparency = 0.4, ZIndex = 1,
		})

		local popup = utility.new("CanvasGroup", {
			Name = "Popup", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 2, Parent = frame,
		})
		nova.Theme.bind(popup, "BackgroundColor3", "Elevated")
		utility.corner(popup, 12)
		textures.image(popup, "gloss9", {Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.86,
			ImageTransparency = 0.88, ZIndex = 2})

		local rim = textures.image(popup, "rim9", {Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.86,
			ImageTransparency = 0.45, ZIndex = 300})

		if rim then
			nova.Theme.bind(rim, "ImageColor3", "Glass")
		end

		if not rim then
			local stroke = utility.stroke(popup, environment.Color3.new(1, 1, 1), 1, 0.85)
			nova.Theme.bind(stroke, "Color", "Glass")
		end

		return frame, popup, utility.new("UIScale", {Scale = 0.92, Parent = popup})
	end

	function class.PopupPlace(window, anchor, width, height, alignment)
		local scale = environment.math.max(window.PopScale.Scale, 0.1)
		local position = (anchor.AbsolutePosition - window.PopLayer.AbsolutePosition) / scale
		local size = anchor.AbsoluteSize / scale
		local layerSize = window.PopLayer.AbsoluteSize / scale
		local x = alignment == "left" and position.X or position.X + size.X - width
		x = environment.math.clamp(x, 8, environment.math.max(8, layerSize.X - width - 8))

		local y = position.Y + size.Y + 6
		local isAbove = false

		if y + height > layerSize.Y - 8 then
			y = environment.math.max(8, position.Y - height - 6)
			isAbove = true
		end

		return x, y, alignment == "left" and 0 or 1, isAbove and 1 or 0
	end

	function class.PopupReveal(window, frame, popup, scale, above)
		local origin = above and 1 or 0
		if scale then scale.Scale = 1 end
		popup.AnchorPoint = environment.Vector2.new(0, origin)
		popup.Position = environment.UDim2.fromScale(0, origin)
		popup.Size = environment.UDim2.new(1, 0, 0, 0)
		popup.GroupTransparency = 1
		local easing, direction = environment.Enum.EasingStyle, environment.Enum.EasingDirection
		local grow = environment.TweenInfo.new(0.32, easing.Quint, direction.Out)
		local fade = environment.TweenInfo.new(0.2, easing.Quad, direction.Out)
		nova.Motion.tween(popup, grow, {Size = environment.UDim2.fromScale(1, 1)})
		nova.Motion.tween(popup, fade, {GroupTransparency = 0})
		local shadow = frame:FindFirstChild("Shadow")
		if shadow then
			shadow.ImageTransparency = 1
			nova.Motion.tween(shadow, grow, {ImageTransparency = 0.4})
		end
	end

	function class.PopupConceal(window, frame, popup)
		local info = environment.TweenInfo.new(0.16, environment.Enum.EasingStyle.Quad, environment.Enum.EasingDirection.In)
		nova.Motion.tween(popup, info, {Size = environment.UDim2.new(1, 0, 0, 0), GroupTransparency = 1})
		local shadow = frame:FindFirstChild("Shadow")
		if shadow then nova.Motion.tween(shadow, info, {ImageTransparency = 1}) end
	end

	function class.PopupOrigin(window, popup, x, y)
		popup.AnchorPoint = environment.Vector2.new(x or 0.5, y or 0.5)
		popup.Position = environment.UDim2.fromScale(x or 0.5, y or 0.5)
	end

	function class.ConfirmPopup(window, anchor, options, callback)
		options = type(options) == "table" and options or {}
		local text = tostring(options.Text or "")
		local textHeight = 0
		if text ~= "" then
			local fontSize = math.ceil(13 * (tonumber(nova.U.textScale) or 1))
			local ok, measured = environment.pcall(function()
				return nova.Services.TextService:GetTextSize(text, fontSize, environment.Enum.Font.GothamMedium, environment.Vector2.new(235.7142857142857, 1000))
			end)
			textHeight = (ok and measured and measured.Y or 40) + 6
		end
		local buttonY = 50 + (textHeight > 0 and textHeight + 8 or 0)
		local height = buttonY + 34 + 14
		local frame, popup, scale = window:PopupShell(296, height)
		local x, y, _, above = window:PopupPlace(anchor, 296, height, "right")
		frame.Position = environment.UDim2.fromOffset(x, y)
		window:PopupReveal(frame, popup, scale, above == 1)
		local danger = options.Danger == true
		local utility, theme = nova.U, nova.Theme
		local badge = utility.new("Frame", {Name = "Badge", Position = environment.UDim2.fromOffset(14, 14), Size = environment.UDim2.fromOffset(28, 28),
			BorderSizePixel = 0, BackgroundTransparency = 0.8, ZIndex = 61, Parent = popup})
		theme.bind(badge, "BackgroundColor3", danger and "Danger" or "Accent")
		utility.corner(badge, 9)
		nova.icon({Parent = badge, Icon = options.Icon or (danger and "triangle-alert" or "info"), Size = 15, Pos = environment.UDim2.fromScale(0.5, 0.5),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = danger and "Danger" or "Accent", Z = 62})
		nova.label({Parent = popup, Text = tostring(options.Title or "Are you sure?"), Font = nova.Font.Semi(), Size = 15,
			Pos = environment.UDim2.fromOffset(50, 15), Box = environment.UDim2.new(1, -64, 0, 26), Truncate = true, Color = "Text", Z = 61})
		local description
		if textHeight > 0 then
			description = nova.label({Parent = popup, Text = text, Font = nova.Font.Medium(), Size = 13, Pos = environment.UDim2.fromOffset(16, 50),
				Box = environment.UDim2.new(1, -32, 0, textHeight), Wrap = true, AlignY = environment.Enum.TextYAlignment.Top, Color = "Muted", Z = 61})
		end
		local closed = false
		local function close()
			if closed then return end
			closed = true
			window:ClosePopups()
		end
		local function makeButton(label, position, width, accept)
			local button = utility.new("TextButton", {Name = accept and "Accept" or "Cancel", Text = "", AutoButtonColor = false,
				Position = environment.UDim2.fromOffset(position, buttonY), Size = environment.UDim2.fromOffset(width, 34), BorderSizePixel = 0, ZIndex = 61, Parent = popup})
			theme.bind(button, "BackgroundColor3", accept and (danger and "Danger" or "Accent") or "Surface2")
			utility.corner(button, 9)
			theme.bind(utility.stroke(button, environment.Color3.new(1, 1, 1), 1, accept and 0.78 or 0.88), "Color", "Glass")
			local color = accept and (danger and function() return environment.Color3.new(1, 1, 1) end or "OnAccent") or "Text"
			nova.label({Parent = button, Text = label, Font = nova.Font.Semi(), Size = 14, Box = environment.UDim2.fromScale(1, 1),
				AlignX = environment.Enum.TextXAlignment.Center, Color = color, Z = 62})
			local buttonScale = utility.new("UIScale", {Parent = button})
			button.MouseEnter:Connect(function()
				nova.Motion.tween(button, "Quick", {BackgroundTransparency = 0.14})
				nova.Sound.play("hover", 0.6)
			end)
			utility.leave(button, function()
				nova.Motion.tween(button, "Quick", {BackgroundTransparency = 0})
				nova.Motion.tween(buttonScale, "Quick", {Scale = 1})
			end)
			button.MouseButton1Down:Connect(function() nova.Motion.tween(buttonScale, "Quick", {Scale = 0.97}) end)
			button.MouseButton1Up:Connect(function() nova.Motion.tween(buttonScale, "Quick", {Scale = 1}) end)
			return button
		end
		local cancel = makeButton(tostring(options.Cancel or "Cancel"), 16, 128, false)
		local accept = makeButton(tostring(options.Accept or "OK"), 152, 128, true)
		if description then
			environment.task.delay(0.05, function()
				if closed or not description.Parent then return end
				local measured = math.ceil(description.TextBounds.Y) + 6
				if measured <= textHeight then return end
				local difference = measured - textHeight
				textHeight = measured
				description.Size = environment.UDim2.new(1, -32, 0, measured)
				frame.Size = environment.UDim2.fromOffset(296, height + difference)
				cancel.Position = environment.UDim2.fromOffset(cancel.Position.X.Offset, buttonY + difference)
				accept.Position = environment.UDim2.fromOffset(accept.Position.X.Offset, buttonY + difference)
				if above == 1 then frame.Position = environment.UDim2.fromOffset(x, y - difference) end
			end)
		end
		cancel.MouseButton1Click:Connect(function()
			nova.Sound.play("click")
			close()
		end)
		accept.MouseButton1Click:Connect(function()
			nova.Sound.play("click")
			close()
			if type(callback) == "function" then environment.task.defer(callback, accept) end
		end)
		window:OpenPopup({close = function()
			closed = true
			window:PopupConceal(frame, popup)
			environment.task.delay(0.18, function() frame:Destroy() end)
		end})
	end

	local function stripMarkup(value)
		return (string.gsub(tostring(value or ""), "<[^>]->", ""))
	end

	local function searchText(value)
		local text = stripMarkup(string.lower(tostring(value or "")))
		text = string.gsub(text, "\208([\144-\159])", function(byte) return "\208" .. string.char(string.byte(byte) + 32) end)
		text = string.gsub(text, "\208([\160-\175])", function(byte) return "\209" .. string.char(string.byte(byte) - 32) end)
		return (string.gsub(text, "\208([\129\132\134\135])", function(byte) return "\209" .. string.char(string.byte(byte) + 16) end))
	end

	local function escapeMarkup(text)
		text = string.gsub(text, "&", "&amp;")
		text = string.gsub(text, "<", "&lt;")
		return (string.gsub(text, ">", "&gt;"))
	end

	local function highlight(text, query, color)
		local first, last = string.find(searchText(text), query, 1, true)
		if not first then return escapeMarkup(text) end
		return escapeMarkup(string.sub(text, 1, first - 1)) .. '<font color="#' .. color .. '">' .. escapeMarkup(string.sub(text, first, last)) .. "</font>" .. escapeMarkup(string.sub(text, last + 1))
	end

	function class._searchSubLabel(window, tab, page)
		local key = page and page.Key
		if not key or key == "_" or not tab.SubButtons then return nil end
		local button = tab.SubButtons[key]
		return stripMarkup(button and button.Label and button.Label.Text or key)
	end

	function class._searchCollect(window)
		local results = {}
		local separator = "  вЂє  "
		for _, tab in ipairs(window.TabList) do
			local tabTitle = stripMarkup(tab.Label and tab.Label.Text or tab.Name)
			local tabHay = searchText(tabTitle .. " " .. tostring(tab.Name))
			table.insert(results, {kind = "tab", tab = tab, title = tabTitle, path = nova.tr("Tab"), hay = tabHay, titleL = searchText(tabTitle)})
			if tab.SubDefs and tab.SubButtons then
				for _, sub in ipairs(tab.SubDefs) do
					local button = tab.SubButtons[sub.key]
					local title = stripMarkup(button and button.Label and button.Label.Text or sub.label or sub.key)
					table.insert(results, {kind = "sub", tab = tab, sub = sub.key, title = title, path = tabTitle,
						hay = searchText(title .. " " .. tostring(sub.key)) .. " " .. tabHay, titleL = searchText(title)})
				end
			end
			for _, section in ipairs(tab.Sections) do
				if not section.Hidden and section.TitleLabel and not section.ParentSection then
					local sub = window:_searchSubLabel(tab, section.Page)
					local title = stripMarkup(section.TitleLabel.Text)
					local path = sub and tabTitle .. separator .. sub or tabTitle
					table.insert(results, {kind = "section", tab = tab, sec = section, title = title, path = path,
						hay = searchText(title .. " " .. tostring(section.Key) .. " " .. path), titleL = searchText(title)})
				end
			end
			for _, entry in ipairs(tab.Rows) do
				local row = entry.row
				if not row or not row.Title or row.selfHidden or row.parentHidden or not row.Frame or not row.Frame.Parent then continue end
				local chain, section, visible = {}, entry.sec, true
				while section and section.ParentSection do
					if section.OwnerRow and (section.OwnerRow.selfHidden or section.OwnerRow.parentHidden) then visible = false end
					table.insert(chain, section)
					section = section.ParentSection
				end
				local title = stripMarkup(row.Title.Text)
				if not visible or not section or section.Hidden or title == "" then continue end
				local path = {tabTitle}
				local sub = window:_searchSubLabel(tab, section.Page)
				if sub then table.insert(path, sub) end
				if section.TitleLabel then table.insert(path, stripMarkup(section.TitleLabel.Text)) end
				for index = #chain, 1, -1 do
					local owner = chain[index].OwnerRow
					if owner and owner.Title then table.insert(path, stripMarkup(owner.Title.Text)) end
				end
				local pathText = table.concat(path, separator)
				local extra = (row.Desc and row.Desc.Text or "") .. " " .. tostring(row.Opts and row.Opts.Text or "")
				if row.SearchOptions then
					local ok, options = environment.pcall(row.SearchOptions)
					if ok and type(options) == "string" then extra ..= " " .. options end
				end
				table.insert(results, {kind = "row", tab = tab, sec = section, row = row, chain = chain, title = title, path = pathText,
					hay = searchText(title .. " " .. extra .. " " .. pathText), titleL = searchText(title)})
			end
		end
		return results
	end

	function class._searchRank(window, query)
		query = string.gsub(searchText(query), "^%s+", "")
		query = string.gsub(query, "%s+$", "")
		if query == "" then return {}, query end
		local words = {}
		for word in string.gmatch(query, "%S+") do table.insert(words, word) end
		local results, seen = {}, {}
		local priorities = {tab = 30, sub = 22, section = 10, row = 0}
		for _, result in ipairs(window:_searchCollect()) do
			local position = string.find(result.titleL, query, 1, true)
			local score, titleMatch, matches = position == 1 and 120 or position and 70 or 0, position ~= nil, true
			for _, word in ipairs(words) do
				if string.find(result.titleL, word, 1, true) then
					score, titleMatch = score + 18, true
					continue
				end
				if string.find(result.hay, word, 1, true) then
					score += 4
					continue
				end
				matches = false
				break
			end
			local key = result.kind .. "|" .. result.title .. "|" .. result.path
			if matches and (titleMatch or result.kind ~= "row") and not seen[key] then
				seen[key] = true
				result.score = score + priorities[result.kind] - #result.titleL / 40
				table.insert(results, result)
			end
		end
		table.sort(results, function(left, right) return left.score > right.score end)
		while #results > 40 do table.remove(results) end
		return results, query
	end

	function class._searchClose(window)
		local popup = window.SearchPop
		if not popup then return end
		window.SearchPop = nil
		window:PopupConceal(popup.Frame, popup.Shell)
		environment.task.delay(0.18, function() environment.pcall(function() popup.Frame:Destroy() end) end)
	end

	function class._searchOpen(window, height)
		if window.SearchPop then return window.SearchPop end
		local frame, shell, scale = window:PopupShell(360, height)
		frame.Name = "SearchResults"
		local list = nova.U.new("ScrollingFrame", {Name = "List", Position = environment.UDim2.fromOffset(0, 5), Size = environment.UDim2.new(1, 0, 1, -10),
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = environment.UDim2.new(), AutomaticCanvasSize = environment.Enum.AutomaticSize.Y,
			ScrollingDirection = environment.Enum.ScrollingDirection.Y, ZIndex = 61, Parent = shell})
		nova.Theme.bind(list, "ScrollBarImageColor3", "Faint")
		nova.U.list(list, 2)
		nova.U.pad(list, 0, 5, 0, 5)
		local empty = nova.label({Parent = shell, Text = nova.tr("Nothing found"), Font = nova.Font.Medium(), Size = 13, Color = "Muted",
			AlignX = environment.Enum.TextXAlignment.Center, Box = environment.UDim2.fromScale(1, 1), Z = 62})
		empty.Visible = false
		local popup = {Frame = frame, Shell = shell, List = list, Empty = empty, Rows = {}, Items = {}, Sel = 1, H = height}
		window.SearchPop = popup
		local x, y, _, above = window:PopupPlace(window.SearchField, 360, height, "left")
		frame.Position = environment.UDim2.fromOffset(x, y)
		window:PopupReveal(frame, shell, scale, above == 1)
		table.insert(window.Popups, {close = function() if window.SearchPop == popup then window:_searchClose() end end})
		return popup
	end

	function class._searchSelect(window, index)
		local popup = window.SearchPop
		if not popup or #popup.Rows == 0 then return end
		index = math.clamp(index, 1, #popup.Rows)
		popup.Sel = index
		for position, row in ipairs(popup.Rows) do nova.Motion.tween(row, "Quick", {BackgroundTransparency = position == index and 0.84 or 1}) end
		local scroll, scale = popup.List, math.max(window.PopScale.Scale, 0.1)
		local y = (index - 1) * 48
		local height, current = scroll.AbsoluteWindowSize.Y / scale, scroll.CanvasPosition.Y
		if y < current then
			scroll.CanvasPosition = environment.Vector2.new(0, y)
			return
		end
		if height > 1 and y + 46 > current + height then scroll.CanvasPosition = environment.Vector2.new(0, y + 46 - height) end
	end

	function class._searchRender(window, results, query)
		local popup = window.SearchPop
		if not popup then return end
		for _, row in ipairs(popup.Rows) do row:Destroy() end
		popup.Rows, popup.Items = {}, results
		popup.Empty.Visible = #results == 0
		local color = nova.Theme.resolve("Accent"):ToHex()
		for index, result in ipairs(results) do
			local row = nova.U.new("TextButton", {Name = "Result", Text = "", AutoButtonColor = false, Size = environment.UDim2.new(1, 0, 0, 46),
				BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = index, ZIndex = 62, Parent = popup.List})
			nova.Theme.bind(row, "BackgroundColor3", "Accent")
			nova.U.corner(row, 9)
			local tile = nova.U.new("Frame", {Name = "Tile", AnchorPoint = environment.Vector2.new(0, 0.5), Position = environment.UDim2.new(0, 8, 0.5, 0),
				Size = environment.UDim2.fromOffset(30, 30), BorderSizePixel = 0, BackgroundTransparency = 0.82, ZIndex = 63, Parent = row})
			nova.Theme.bind(tile, "BackgroundColor3", "Accent")
			nova.U.corner(tile, 9)
			nova.icon({Parent = tile, Icon = result.tab.Icon or "search", Size = 15, Pos = environment.UDim2.fromScale(0.5, 0.5),
				Anchor = environment.Vector2.new(0.5, 0.5), Color = "Accent", Z = 64})
			nova.label({Parent = row, Text = highlight(result.title, query, color), Rich = true, Font = nova.Font.Semi(), Size = 13,
				Pos = environment.UDim2.fromOffset(48, 6), Box = environment.UDim2.new(1, -58, 0, 18), Truncate = true, Z = 63})
			nova.label({Parent = row, Text = escapeMarkup(result.path), Rich = true, Font = nova.Font.Medium(), Size = 11, Color = "Muted",
				Pos = environment.UDim2.fromOffset(48, 24), Box = environment.UDim2.new(1, -58, 0, 15), Truncate = true, Z = 63})
			row.MouseEnter:Connect(function() if popup.Sel ~= index then window:_searchSelect(index) end end)
			row.MouseButton1Click:Connect(function() window:_searchJump(result) end)
			table.insert(popup.Rows, row)
		end
		local height = #results == 0 and 56 or math.min(#results, 7) * 48 + 8
		if popup.H ~= height then
			popup.H = height
			local info = environment.TweenInfo.new(0.2, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
			nova.Motion.tween(popup.Frame, info, {Size = environment.UDim2.fromOffset(360, height)})
		end
		popup.List.CanvasPosition = environment.Vector2.zero
		popup.Sel = 1
		window:_searchSelect(1)
	end

	function class._searchFlash(window, target)
		if not target or not target.Parent then return end
		local frame = nova.U.new("Frame", {Name = "SearchFlash", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0,
			BackgroundTransparency = 1, ZIndex = 0, Parent = target})
		nova.Theme.bind(frame, "BackgroundColor3", "Accent")
		nova.U.corner(frame, 10)
		local stroke = nova.U.stroke(frame, environment.Color3.new(1, 1, 1), 1.5, 1)
		nova.Theme.bind(stroke, "Color", "Accent")
		local show = environment.TweenInfo.new(0.22, environment.Enum.EasingStyle.Quad, environment.Enum.EasingDirection.Out)
		local hide = environment.TweenInfo.new(0.55, environment.Enum.EasingStyle.Quad, environment.Enum.EasingDirection.In)
		environment.task.spawn(function()
			for _ = 1, 2 do
				nova.Motion.tween(frame, show, {BackgroundTransparency = 0.8})
				nova.Motion.tween(stroke, show, {Transparency = 0.25})
				environment.task.wait(0.24)
				nova.Motion.tween(frame, hide, {BackgroundTransparency = 1})
				nova.Motion.tween(stroke, hide, {Transparency = 1})
				environment.task.wait(0.56)
			end
			frame:Destroy()
		end)
	end

	function class._searchScroll(window, section, target)
		if not section or section.Floating then return end
		local scroll = section.Page and section.Page.Scroll
		if not scroll or not target or not target.Parent then return end
		local scale = math.max(window.Scale.Scale, 0.1)
		local y = (target.AbsolutePosition.Y - scroll.AbsolutePosition.Y) / scale + scroll.CanvasPosition.Y
		local height = scroll.AbsoluteWindowSize.Y / scale
		local maximum = math.max(0, scroll.AbsoluteCanvasSize.Y / scale - height)
		local position = math.clamp(y - height * 0.3, 0, maximum)
		local info = environment.TweenInfo.new(0.45, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
		nova.Motion.tween(scroll, info, {CanvasPosition = environment.Vector2.new(0, position)})
	end

	function class._searchJump(window, result)
		if not result or not result.tab then return end
		local tab = result.tab
		window:_searchClose()
		window.SearchBox.Text = ""
		environment.pcall(function() window.SearchBox:ReleaseFocus() end)
		nova.Sound.play("click")
		if window.Current ~= tab then window:SelectTab(tab) end
		if result.kind == "tab" then return end
		local section = result.sec
		local sub = result.sub or section and section.Page and section.Page.Key
		if sub and tab.SubButtons and tab.SubButtons[sub] and tab.ActiveSub ~= sub then tab:SelectSub(sub) end
		if result.kind == "sub" then return end
		if section and section.Collapsed then section:SetCollapsed(false) end
		local chain = result.chain or {}
		for index = #chain, 1, -1 do
			local toggle = chain[index].OwnerToggle
			if toggle and toggle.SetDrawer and toggle.IsDrawerOpen and not toggle:IsDrawerOpen() then toggle:SetDrawer(true) end
		end
		local target = result.kind == "row" and result.row.Frame or section and section.Wrap
		local flash = result.kind == "row" and result.row.Frame or section and section.Card
		environment.task.delay(0.4, function()
			if window.Destroyed or not target or not target.Parent then return end
			window:_searchScroll(section, target)
			environment.task.delay(0.35, function() window:_searchFlash(flash) end)
		end)
	end

	function class.Search(window, query)
		nova.trace("Search")
		if window.Query ~= "" then
			for _, tab in ipairs(window.TabList) do
				for _, entry in ipairs(tab.Rows) do
					if entry.searchHidden then entry.searchHidden = false; entry.refresh() end
				end
				for _, section in ipairs(tab.Sections) do section:_refreshVisibility() end
				if tab.Label and not window.SidebarCollapsed then nova.Motion.tween(tab.Label, "Quick", {TextTransparency = 0}) end
				if tab.IconImg then nova.Motion.tween(tab.IconImg, "Quick", {ImageTransparency = 0}) end
			end
		end
		window.Query = ""
		local text = tostring(query or "")
		if not string.find(text, "%S") then window:_searchClose(); return end
		local results, normalized = window:_searchRank(text)
		local height = #results == 0 and 56 or math.min(#results, 7) * 48 + 8
		window:_searchOpen(height)
		window:_searchRender(results, normalized)
	end

	function class._drag(window, target)
		if environment.typeof(target) ~= "Instance" then
			return
		end

		local isDragging, start, origin, startedInput
		target.InputBegan:Connect(function(input)
			if not nova.U.isClick(input) then
				return
			end

			isDragging = true
			start = input.Position
			origin = window.Root.Position
			startedInput = input

			local connection
			connection = input.Changed:Connect(function()
				if input.UserInputState == environment.Enum.UserInputState.End then
					isDragging = false
					connection:Disconnect()
					window:_savePos()
				end
			end)
		end)

		nova.U.connect(nova.Services.UserInputService.InputChanged, function(input)
			if not isDragging or not nova.U.sameMove(input, startedInput) then
				return
			end

			local delta = input.Position - start
			window.Root.Position = environment.UDim2.new(origin.X.Scale, origin.X.Offset + delta.X,
				origin.Y.Scale, origin.Y.Offset + delta.Y)
		end, window.Conns)
	end

	function class._savePos(window)
		if not window.State or not window.Root then
			return
		end

		local position = window.Root.Position

		if environment.math.abs(position.X.Scale - 0.5) > 0.001 then
			return
		end

		if environment.math.abs(position.Y.Scale - 0.5) > 0.001 then
			return
		end

		environment.pcall(window.State.set, window.IsTouch and "touchPos" or "winPos", {
			environment.math.floor(position.X.Offset + 0.5), environment.math.floor(position.Y.Offset + 0.5),
		})
	end

	function class._resize(window, target)
		local isResizing, start, originalSize, origin, startedInput
		target.InputBegan:Connect(function(input)
			if not nova.U.isClick(input) then
				return
			end

			isResizing = true
			start = input.Position
			originalSize = window.Root.AbsoluteSize / environment.math.max(window.Scale.Scale, 0.1)
			origin = window.Root.Position
			startedInput = input

			local connection
			connection = input.Changed:Connect(function()
				if input.UserInputState == environment.Enum.UserInputState.End then
					isResizing = false
					connection:Disconnect()
					window:_finishResize()
				end
			end)
		end)

		nova.U.connect(nova.Services.UserInputService.InputChanged, function(input)
			if not isResizing or not nova.U.sameMove(input, startedInput) then
				return
			end

			local scale = environment.math.max(window.Scale.Scale, 0.1)
			local delta = (input.Position - start) / scale
			local minimumX, minimumY = window.MinSize.X, window.MinSize.Y

			if window.IsTouch then
				local camera = environment.workspace.CurrentCamera
				local viewport = camera and camera.ViewportSize or environment.Vector2.new(1280, 720)
				delta = environment.Vector2.new(
					environment.math.min(delta.X, (viewport.X - 16) / scale - originalSize.X),
					environment.math.min(delta.Y, (viewport.Y - 16) / scale - originalSize.Y)
				)
				minimumX, minimumY = 360, 240
			end

			local width = environment.math.max(minimumX, originalSize.X + delta.X)
			local height = environment.math.max(minimumY, originalSize.Y + delta.Y)
			window.Size = environment.Vector2.new(width, height)
			window.Root.Size = environment.UDim2.fromOffset(width, height)

			local actualScale = window.Scale.Scale
			window.Root.Position = environment.UDim2.new(origin.X.Scale, origin.X.Offset + (width - originalSize.X) * actualScale / 2,
				origin.Y.Scale, origin.Y.Offset + (height - originalSize.Y) * actualScale / 2)
		end, window.Conns)
	end

	function class._finishResize(window)
		if window.IsTouch then
			window.TouchSize = window.Size
		end

		if window.State then
			environment.pcall(window.State.set, window.IsTouch and "touchSize" or "size", {
				environment.math.floor(window.Size.X + 0.5), environment.math.floor(window.Size.Y + 0.5),
			})
		end

		window:_savePos()
	end

	function class._syncLayers(window)
		local scale = environment.math.max((window.AutoScale or 1) * window.UserScale, 0.1)

		for _, layer in environment.ipairs({{window.FloatLayer, window.FloatScale}, {window.PopLayer, window.PopScale}}) do
			layer[2].Scale = scale
			layer[1].Size = environment.UDim2.fromScale(1 / scale, 1 / scale)
		end
	end

	function class._placeOnScreen(window, position)
		local camera = environment.workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or environment.Vector2.new(1280, 720)
		position = position or window.Root.Position

		local scale = (window.AutoScale or 1) * window.UserScale
		local size = environment.Vector2.new(window.Root.Size.X.Offset, window.Root.Size.Y.Offset) * scale
		local width, height = size.X, size.Y
		local x = position.X.Scale * viewport.X + position.X.Offset
		local y = position.Y.Scale * viewport.Y + position.Y.Offset
		local boundedX = width + 16 >= viewport.X and viewport.X / 2
			or environment.math.clamp(x, width / 2 + 8, viewport.X - width / 2 - 8)
		local boundedY = height + 16 >= viewport.Y and viewport.Y / 2
			or environment.math.clamp(y, height / 2 + 8, viewport.Y - height / 2 - 8)

		if environment.math.abs(boundedX - x) < 0.5 and environment.math.abs(boundedY - y) < 0.5 then
			return position
		end

		return environment.UDim2.new(position.X.Scale, environment.math.floor(position.X.Offset + (boundedX - x) + 0.5),
			position.Y.Scale, environment.math.floor(position.Y.Offset + (boundedY - y) + 0.5))
	end

	function class.OnScreenScale(window, callback)
		table.insert(window.ScaleHooks, callback)
		local camera = environment.workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or environment.Vector2.new(1280, 720)
		local ok, result = environment.pcall(callback, window.OverlayScale or 1, viewport)

		if ok and result == false then
			local index = table.find(window.ScaleHooks, callback)

			if index then
				table.remove(window.ScaleHooks, index)
			end
		end
	end

	function class.SetAutoFit(window, isEnabled)
		nova.trace("SetAutoFit")
		window.AutoFit = isEnabled and true or false
		window.State.set("autoFit", window.AutoFit)

		if not window.AutoFit and not window.IsTouch then
			window.Root.Size = environment.UDim2.fromOffset(window.Size.X, window.Size.Y)
		end

		if window._applyScale then
			window._applyScale(true)
		end
	end

	function class._autoScale(window)
		local camera = environment.workspace.CurrentCamera
		local function applyScale()
			local viewport = camera and camera.ViewportSize or environment.Vector2.new(1280, 720)
			local factor = window.AutoFit and nova.screenFactor(viewport) or 1
			window.ScreenFactor = factor
			window.OverlayScale = window.AutoFit and nova.U.clamp(factor, 0.6, 1.2) or 1

			if window.IsTouch then
				window:_scaleTouch(viewport)
			end

			if not window.IsTouch and window.AutoFit then
				window:_scaleFit(viewport, factor)
			end

			if not window.IsTouch and not window.AutoFit then
				window:_scaleManual(viewport)
			end

			window.Scale.Scale = window.AutoScale * window.UserScale
			window.ToastScale.Scale = nova.U.clamp(environment.math.min(window.OverlayScale, viewport.X / 900), 0.55, 1.2)
			window:_syncLayers()

			if not window.Scaling and not window.HomePos then
				local position = window:_placeOnScreen(window.Root.Position)

				if position ~= window.Root.Position then
					window.Root.Position = position
				end
			end

			for index = #window.ScaleHooks, 1, -1 do
				local ok, result = environment.pcall(window.ScaleHooks[index], window.OverlayScale, viewport)

				if ok and result == false then
					table.remove(window.ScaleHooks, index)
				end
			end
		end

		applyScale()

		if camera then
			nova.U.connect(camera:GetPropertyChangedSignal("ViewportSize"), applyScale, window.Conns)
		end

		window._applyScale = applyScale
	end

	function class._scaleTouch(window, viewport)
		local baseScale = nova.U.clamp((viewport.Y - 16) / 440, 0.55, 1)
		local scale = nova.U.clamp(baseScale * window.UserScale / environment.math.max(window.DefaultScale or 1, 0.1), 0.45, 1.3)
		local maxWidth = environment.math.floor(environment.math.min(window.BaseSize.X, (viewport.X - 16) / scale))
		local maxHeight = environment.math.floor(environment.math.min(window.BaseSize.Y, (viewport.Y - 16) / scale))
		local width, height

		if window.TouchSize then
			width = environment.math.floor(nova.U.clamp(window.TouchSize.X, environment.math.min(360, maxWidth), maxWidth))
			height = environment.math.floor(nova.U.clamp(window.TouchSize.Y, environment.math.min(240, maxHeight), maxHeight))
		end

		if not window.TouchSize then
			width = environment.math.min(maxWidth, environment.math.floor(viewport.X * 0.72 / scale))
			height = environment.math.min(maxHeight, environment.math.floor(viewport.Y * 0.86 / scale))
		end

		if window.Size.X ~= width or window.Size.Y ~= height then
			window.Size = environment.Vector2.new(width, height)
			window.Root.Size = environment.UDim2.fromOffset(width, height)
		end

		window.AutoScale = scale / environment.math.max(window.UserScale, 0.1)
	end

	function class._scaleFit(window, viewport, factor)
		local userScale = environment.math.max(window.UserScale, 0.1)
		local scale = environment.math.max(userScale * factor, environment.math.min(0.6, userScale))
		local availableWidth, availableHeight = viewport.X - 24, viewport.Y - 24
		local width = environment.math.max(environment.math.min(window.MinSize.X, window.Size.X),
			environment.math.min(window.Size.X, environment.math.floor(availableWidth / scale)))
		local height = environment.math.max(environment.math.min(window.MinSize.Y, window.Size.Y),
			environment.math.min(window.Size.Y, environment.math.floor(availableHeight / scale)))
		local fit = environment.math.min(1, availableWidth / (width * scale), availableHeight / (height * scale))
		local size = environment.UDim2.fromOffset(width, height)

		if window.Root.Size ~= size then
			window.Root.Size = size
		end

		window.AutoScale = nova.U.clamp(scale * fit, 0.3, 1.8) / userScale
	end

	function class._scaleManual(window, viewport)
		local scale = environment.math.min(1, (viewport.X - 30) / window.Size.X, (viewport.Y - 30) / window.Size.Y)
		window.AutoScale = nova.U.clamp(scale, 0.45, 1)
	end

	function class.SetScale(window, value)
		nova.trace("SetScale")
		window.UserScale = nova.U.clamp(environment.tonumber(value) or 1, 0.6, 1.5)
		window.State.set("scale", window.UserScale)

		if window._applyScale then
			window._applyScale(true)
		end
	end

	return class
end

function NovaWindow.screenFactor(environment, utility, viewport)
	if not viewport then
		local camera = environment.workspace.CurrentCamera
		viewport = camera and camera.ViewportSize or environment.Vector2.new(1920, 1000)
	end

	local factor = environment.math.min(viewport.X / 1920, viewport.Y / 1000)

	if environment.math.abs(factor - 1) < 0.04 then
		factor = 1
	end

	return utility.clamp(factor, 0.5, 1.3)
end

function NovaSection.createClass(environment, nova)
	local class = {}
	class.__index = class

	function class.SetTitle(section, title)
		section.TitleLabel.Text = tostring(title)
	end

	function class._refreshVisibility(section)
		local visible = false
		for _, row in ipairs(section.Rows) do
			if row.Frame.Visible then visible = true; break end
		end
		local query = section.Window.Query or ""
		if section.Floating then
			section.Wrap.Visible = not section.Hidden
			return
		end
		section.Wrap.Visible = not section.Hidden and (query == "" or visible)
	end

	function class.SetVisible(section, visible)
		section.Hidden = not visible
		section:_refreshVisibility()
	end

	function class.SetCollapsed(section, collapsed, immediate)
		collapsed = collapsed and true or false
		if collapsed == section.Collapsed then return end
		section.Collapsed = collapsed
		local window = section.Window
		local saved = window.State.get("collapsed", {})
		if type(saved) ~= "table" then saved = {} end
		saved[section.Key] = collapsed or nil
		window.State.data.collapsed = saved
		window.State.save()
		local body, content = section.Body, section.Content
		local scale = math.max(window.Scale.Scale, 0.1)
		section.BodyToken = (section.BodyToken or 0) + 1
		local token = section.BodyToken
		local preset = (immediate or not nova.Motion.enabled) and environment.TweenInfo.new(0) or "Base"
		nova.Motion.tween(section.Chev, preset, {Rotation = collapsed and -90 or 0})
		nova.Motion.tween(section.HeadLine, preset, {BackgroundTransparency = collapsed and 1 or 0.5})
		local height = math.ceil(content.AbsoluteSize.Y / scale) + 16
		local info = environment.TweenInfo.new(0.32, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
		if collapsed then
			body.AutomaticSize = environment.Enum.AutomaticSize.None
			body.Size = environment.UDim2.new(1, 0, 0, immediate and 0 or height)
			if not immediate then nova.Motion.tween(body, info, {Size = environment.UDim2.new(1, 0, 0, 0)}) end
			return
		end
		body.AutomaticSize = environment.Enum.AutomaticSize.None
		if immediate then
			body.AutomaticSize = environment.Enum.AutomaticSize.Y
			body.Size = environment.UDim2.new(1, 0, 0, 0)
			return
		end
		nova.Motion.tween(body, info, {Size = environment.UDim2.new(1, 0, 0, height)})
		environment.task.delay(0.34, function()
			if section.BodyToken == token and not section.Collapsed then
				body.AutomaticSize = environment.Enum.AutomaticSize.Y
				body.Size = environment.UDim2.new(1, 0, 0, 0)
			end
		end)
	end

	function class.Colorpicker(section, options)
		options = options or {}
		local window, utility, theme = section.Window, nova.U, nova.Theme
		local row = section:_row({Text = options.Text, Desc = options.Desc, Tooltip = options.Tooltip, Reserve = 150,
			Indent = options.Indent, Order = options.Order, Parent = options.Parent})
		local color = environment.typeof(options.Default) == "Color3" and options.Default or environment.Color3.new(1, 1, 1)
		local state = {alpha = math.clamp(tonumber(options.DefaultAlpha) or 1, 0, 1), alphaEnabled = options.Alpha ~= false}
		state.hue, state.saturation, state.value = color:ToHSV()
		state.color = color
		local function hex(value) return "#" .. string.upper(value:ToHex()) end
		local function description()
			if state.alphaEnabled and state.alpha < 0.995 then return hex(color) .. "  " .. math.floor(state.alpha * 100 + 0.5) .. "%" end
			return hex(color)
		end
		local label = nova.label({Parent = row.Right, Text = description(), Font = nova.Font.Semi(), Size = 12, Box = environment.UDim2.new(0, 0, 0, 20),
			Auto = environment.Enum.AutomaticSize.X, AlignX = environment.Enum.TextXAlignment.Right, Color = "Faint", Z = 3, Name = "Hex"})
		label.LayoutOrder = 5
		local titleWidth
		local function measureTitle()
			environment.task.spawn(function()
				local text = row.Title.Text
				local width = utility.textWidth(text, row.Title.FontFace, 14)
				if row.Title.Text == text then
					titleWidth = width
					if row.fitTitle then row.fitTitle() end
				end
			end)
		end
		row.OnWidth = function(width)
			if not titleWidth then return end
			local hexWidth = math.max(label.TextBounds.X / math.max(window.Scale.Scale, 0.1), 52)
			local visible = width - (10 + row.Indent) - titleWidth - 44 - hexWidth - 32 >= 0
			if label.Visible ~= visible then label.Visible = visible end
		end
		row.Title:GetPropertyChangedSignal("Text"):Connect(measureTitle)
		row.Title:GetPropertyChangedSignal("FontFace"):Connect(measureTitle)
		measureTitle()
		local swatch = utility.new("TextButton", {Name = "Swatch", Text = "", AutoButtonColor = false, Size = environment.UDim2.fromOffset(44, 24),
			BackgroundTransparency = 1, LayoutOrder = 10, ZIndex = 3, Parent = row.Right})
		local swatchScale = utility.new("UIScale", {Parent = swatch})
		local checker = nova.Tex.image(swatch, "checker", {Name = "Checker", Size = environment.UDim2.fromScale(1, 1), ZIndex = 3})
		if checker then utility.corner(checker, 8) end
		local fill = utility.new("Frame", {Name = "Fill", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = color,
			BackgroundTransparency = state.alphaEnabled and 1 - state.alpha or 0, ZIndex = 4, Parent = swatch})
		utility.corner(fill, 8)
		nova.Tex.image(swatch, "gloss9", {Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.57, ImageTransparency = 0.75, ZIndex = 5})
		local rim = nova.Tex.image(swatch, "rim9", {Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.57, ImageTransparency = 0.3, ZIndex = 6})
		if rim then
			theme.bind(rim, "ImageColor3", "Glass")
		else
			theme.bind(utility.stroke(swatch, environment.Color3.new(1, 1, 1), 1, 0.7), "Color", "Glass")
		end
		local picker = {Row = row.Frame, Type = "Colorpicker"}
		local function update(notify)
			color = environment.Color3.fromHSV(state.hue, state.saturation, state.value)
			state.color = color
			fill.BackgroundColor3 = color
			fill.BackgroundTransparency = state.alphaEnabled and 1 - state.alpha or 0
			label.Text = description()
			if state.updatePopup then state.updatePopup() end
			if notify ~= false then
				nova.safe(options.Callback, color, state.alpha)
				if picker.Changed then nova.safe(picker.Changed, color, state.alpha) end
			end
		end
		swatch.MouseButton1Click:Connect(function() section:_colorPopup(swatch, swatchScale, state, color, update, hex) end)
		swatch.MouseEnter:Connect(function() if not swatchScale:GetAttribute("open") then nova.Motion.tween(swatchScale, "Quick", {Scale = 1.06}) end end)
		utility.leave(swatch, function() nova.Motion.tween(swatchScale, "Quick", {Scale = 1}) end)
		local function setColor(nextColor, alpha, notify)
			if environment.typeof(nextColor) ~= "Color3" then return end
			state.hue, state.saturation, state.value = nextColor:ToHSV()
			if alpha ~= nil then state.alpha = math.clamp(tonumber(alpha) or 1, 0, 1) end
			update(notify)
		end
		picker.Set = function(_, nextColor, alpha) setColor(nextColor, alpha, true) end
		picker.SetValue, picker.SetValueRGB = picker.Set, picker.Set
		picker.SetSilent = function(_, nextColor, alpha) setColor(nextColor, alpha, false) end
		picker.Get = function() return color, state.alpha end
		picker.SetText = function(_, text) row.SetText(text) end
		picker.SetVisible = function(_, visible) row.SetVisible(visible) end
		picker.SetParentHidden = function(_, hidden) row.SetParentHidden(hidden) end
		picker.RowObj, picker.Title = row, row.Title
		return picker
	end

	function class._colorPopup(section, swatch, swatchScale, state, originalColor, update, hex)
		local window, utility, theme = section.Window, nova.U, nova.Theme
		nova.Sound.play("click")
		local frame, popup, popupScale = window:PopupShell(236, 234)
		local x, y, _, above = window:PopupPlace(swatch, 236, 234, "right")
		frame.Position = environment.UDim2.fromOffset(x, y)
		window:PopupReveal(frame, popup, popupScale, above == 1)
		nova.Motion.tween(swatchScale, "Quick", {Scale = 0.94})
		local originalAlpha = state.alpha
		local white = environment.Color3.new(1, 1, 1)
		local black = environment.Color3.new(0, 0, 0)
		local function makeKnob(parent, size)
			local knob = utility.new("Frame", {Name = "Knob", AnchorPoint = environment.Vector2.new(0.5, 0.5), Size = environment.UDim2.fromOffset(size, size),
				BackgroundColor3 = state.color, ZIndex = 10, Parent = parent})
			utility.corner(knob, environment.UDim.new(1, 0))
			utility.stroke(knob, white, 2, 0, environment.Enum.ApplyStrokeMode.Border)
			local shade = utility.new("Frame", {Name = "Shade", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
				Size = environment.UDim2.new(1, 6, 1, 6), BackgroundTransparency = 1, ZIndex = 9, Parent = knob})
			utility.corner(shade, environment.UDim.new(1, 0))
			utility.stroke(shade, black, 1, 0.7, environment.Enum.ApplyStrokeMode.Border)
			return knob
		end
		local saturation = utility.new("TextButton", {Name = "SV", Text = "", AutoButtonColor = false, Position = environment.UDim2.fromOffset(12, 12),
			Size = environment.UDim2.fromOffset(212, 124), BorderSizePixel = 0, BackgroundColor3 = environment.Color3.fromHSV(state.hue, 1, 1), ZIndex = 5, Parent = popup})
		utility.corner(saturation, 9)
		local whiteLayer = utility.new("Frame", {Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = white, ZIndex = 6, Parent = saturation})
		utility.corner(whiteLayer, 9)
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new(0, 1), Parent = whiteLayer})
		local blackLayer = utility.new("Frame", {Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = black, ZIndex = 7, Parent = saturation})
		utility.corner(blackLayer, 9)
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new(1, 0), Rotation = 90, Parent = blackLayer})
		local rim = nova.Tex.image(saturation, "rim9", {Size = environment.UDim2.fromScale(1, 1), SliceScale = 0.71, ImageTransparency = 0.6, ZIndex = 8})
		if rim then theme.bind(rim, "ImageColor3", "Glass") end
		local saturationKnob = makeKnob(saturation, 14)
		local preview = utility.new("Frame", {Name = "Preview", Position = environment.UDim2.fromOffset(12, 148), Size = environment.UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1, ZIndex = 5, Parent = popup})
		local checker = nova.Tex.image(preview, "checker", {Size = environment.UDim2.fromScale(1, 1), ZIndex = 5})
		if checker then utility.corner(checker, environment.UDim.new(1, 0)) end
		local previewFill = utility.new("Frame", {Name = "Fill", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = state.color, ZIndex = 6, Parent = preview})
		utility.corner(previewFill, environment.UDim.new(1, 0))
		theme.bind(utility.stroke(previewFill, white, 1, 0.75, environment.Enum.ApplyStrokeMode.Border), "Color", "Glass")
		local hue = utility.new("TextButton", {Name = "Hue", Text = "", AutoButtonColor = false, Position = environment.UDim2.fromOffset(60, state.alphaEnabled and 150 or 160),
			Size = environment.UDim2.fromOffset(157, 10), BorderSizePixel = 0, BackgroundColor3 = white, ZIndex = 5, Parent = popup})
		utility.corner(hue, environment.UDim.new(1, 0))
		local huePoints = {}
		for index = 0, 6 do
			table.insert(huePoints, environment.ColorSequenceKeypoint.new(index / 6, environment.Color3.fromHSV(index / 6, 1, 1)))
		end
		utility.new("UIGradient", {Color = environment.ColorSequence.new(huePoints), Parent = hue})
		local hueKnob = makeKnob(hue, 14)
		local alphaTrack, alphaKnob, alphaFill
		if state.alphaEnabled then
			alphaTrack = utility.new("TextButton", {Name = "Alpha", Text = "", AutoButtonColor = false, Position = environment.UDim2.fromOffset(60, 170),
				Size = environment.UDim2.fromOffset(157, 10), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 5, Parent = popup})
			utility.corner(alphaTrack, environment.UDim.new(1, 0))
			checker = nova.Tex.image(alphaTrack, "checker", {Size = environment.UDim2.fromScale(1, 1), ZIndex = 5})
			if checker then utility.corner(checker, environment.UDim.new(1, 0)) end
			alphaFill = utility.new("Frame", {Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = state.color, ZIndex = 6, Parent = alphaTrack})
			utility.corner(alphaFill, environment.UDim.new(1, 0))
			utility.new("UIGradient", {Transparency = environment.NumberSequence.new(1, 0), Parent = alphaFill})
			alphaKnob = makeKnob(alphaTrack, 14)
		end
		local alphaWidth = state.alphaEnabled and 56 or 0
		local hexWidth = 178 - (state.alphaEnabled and alphaWidth + 6 or 0)
		local hexField, hexStroke = nova.field(popup, {Name = "HexField", Size = environment.UDim2.fromOffset(hexWidth, 28), Z = 5})
		hexField.Position = environment.UDim2.fromOffset(12, 194)
		nova.label({Parent = hexField, Text = "#", Font = nova.Font.Semi(), Size = 12, Pos = environment.UDim2.fromOffset(9, 0),
			Box = environment.UDim2.fromOffset(10, 28), Color = "Faint", Z = 6})
		local hexBox = utility.new("TextBox", {BackgroundTransparency = 1, Position = environment.UDim2.fromOffset(20, 0), Size = environment.UDim2.new(1, -26, 1, 0),
			Text = "", FontFace = nova.Font.Semi(), TextSize = 13, ClearTextOnFocus = false, TextXAlignment = environment.Enum.TextXAlignment.Left, ZIndex = 6, Parent = hexField})
		theme.bind(hexBox, "TextColor3", "Text")
		local alphaBox, alphaStroke
		if state.alphaEnabled then
			local field
			field, alphaStroke = nova.field(popup, {Name = "AlphaField", Size = environment.UDim2.fromOffset(alphaWidth, 28), Z = 5})
			field.Position = environment.UDim2.fromOffset(12 + hexWidth + 6, 194)
			alphaBox = utility.new("TextBox", {BackgroundTransparency = 1, Position = environment.UDim2.fromOffset(8, 0), Size = environment.UDim2.new(1, -24, 1, 0),
				Text = "", FontFace = nova.Font.Semi(), TextSize = 13, ClearTextOnFocus = false, TextXAlignment = environment.Enum.TextXAlignment.Right, ZIndex = 6, Parent = field})
			theme.bind(alphaBox, "TextColor3", "Text")
			nova.label({Parent = field, Text = "%", Font = nova.Font.Semi(), Size = 12, Anchor = environment.Vector2.new(1, 0), Pos = environment.UDim2.new(1, -8, 0, 0),
				Box = environment.UDim2.fromOffset(12, 28), AlignX = environment.Enum.TextXAlignment.Right, Color = "Faint", Z = 6})
		end
		local revert, revertStroke = nova.field(popup, {Class = "TextButton", Name = "Revert", Size = environment.UDim2.fromOffset(28, 28), Z = 5})
		revert.Position = environment.UDim2.fromOffset(196, 194)
		local revertIcon = nova.icon({Parent = revert, Icon = "rotate-ccw", Size = 13, Pos = environment.UDim2.fromScale(0.5, 0.5),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 6})
		revert.MouseEnter:Connect(function()
			nova.paint(revertIcon, "ImageColor3", "Text", "Quick")
			nova.paint(revertStroke, "Color", "Accent", "Quick")
			nova.Motion.tween(revertStroke, "Quick", {Transparency = 0.5})
		end)
		utility.leave(revert, function()
			nova.paint(revertIcon, "ImageColor3", "Muted", "Quick")
			nova.paint(revertStroke, "Color", "Glass", "Quick")
			nova.Motion.tween(revertStroke, "Quick", {Transparency = 0.84})
		end)
		local smooth = environment.TweenInfo.new(0.08, environment.Enum.EasingStyle.Quad, environment.Enum.EasingDirection.Out)
		local first = true
		state.updatePopup = function()
			local info = first and environment.TweenInfo.new(0) or smooth
			first = false
			nova.Motion.tween(saturationKnob, info, {Position = environment.UDim2.fromScale(state.saturation, 1 - state.value)})
			saturationKnob.BackgroundColor3 = state.color
			saturation.BackgroundColor3 = environment.Color3.fromHSV(state.hue, 1, 1)
			nova.Motion.tween(hueKnob, info, {Position = environment.UDim2.fromScale(state.hue, 0.5)})
			hueKnob.BackgroundColor3 = environment.Color3.fromHSV(state.hue, 1, 1)
			previewFill.BackgroundColor3 = state.color
			previewFill.BackgroundTransparency = state.alphaEnabled and 1 - state.alpha or 0
			if alphaTrack then
				alphaFill.BackgroundColor3 = state.color
				nova.Motion.tween(alphaKnob, info, {Position = environment.UDim2.fromScale(state.alpha, 0.5)})
				alphaKnob.BackgroundColor3 = state.color
				if not alphaBox:IsFocused() then alphaBox.Text = tostring(math.floor(state.alpha * 100 + 0.5)) end
			end
			if not hexBox:IsFocused() then hexBox.Text = string.sub(hex(state.color), 2) end
		end
		state.updatePopup()
		local dragging, started
		local function move(position)
			if dragging == "sv" then
				state.saturation = utility.clamp((position.X - saturation.AbsolutePosition.X) / math.max(saturation.AbsoluteSize.X, 1), 0, 1)
				state.value = 1 - utility.clamp((position.Y - saturation.AbsolutePosition.Y) / math.max(saturation.AbsoluteSize.Y, 1), 0, 1)
			end
			if dragging == "hue" then state.hue = utility.clamp((position.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 0.999) end
			if dragging == "alpha" and alphaTrack then state.alpha = utility.clamp((position.X - alphaTrack.AbsolutePosition.X) / math.max(alphaTrack.AbsoluteSize.X, 1), 0, 1) end
			update(true)
		end
		local function begin(kind, knob, event)
			if not utility.isClick(event) then return end
			dragging, started = kind, event
			if knob then nova.Motion.tween(knob, "Quick", {Size = environment.UDim2.fromOffset(17, 17)}) end
			move(event.Position)
		end
		local function finish()
			for _, knob in ipairs({saturationKnob, hueKnob, alphaKnob}) do
				if knob then
					local info = environment.TweenInfo.new(0.25, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
					nova.Motion.tween(knob, info, {Size = environment.UDim2.fromOffset(14, 14)})
				end
			end
			dragging = nil
		end
		saturation.InputBegan:Connect(function(event) begin("sv", saturationKnob, event) end)
		hue.InputBegan:Connect(function(event) begin("hue", hueKnob, event) end)
		if alphaTrack then alphaTrack.InputBegan:Connect(function(event) begin("alpha", alphaKnob, event) end) end
		local input = nova.Services.UserInputService
		local connections = {
			input.InputChanged:Connect(function(event) if dragging and utility.sameMove(event, started) then move(event.Position) end end),
			input.InputEnded:Connect(function(event) if dragging and utility.sameEnd(event, started) then finish() end end),
		}
		revert.MouseButton1Click:Connect(function()
			state.hue, state.saturation, state.value = originalColor:ToHSV()
			state.alpha = originalAlpha
			update(true)
			nova.Sound.play("tick")
			local info = environment.TweenInfo.new(0.35, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
			nova.Motion.tween(revertIcon, info, {Rotation = -360})
			environment.task.delay(0.36, function() revertIcon.Rotation = 0 end)
		end)
		hexBox.Focused:Connect(function()
			nova.paint(hexStroke, "Color", "Accent", "Quick")
			nova.Motion.tween(hexStroke, "Quick", {Transparency = 0.25})
		end)
		hexBox.FocusLost:Connect(function()
			nova.paint(hexStroke, "Color", "Glass", "Quick")
			nova.Motion.tween(hexStroke, "Quick", {Transparency = 0.84})
			local text = hexBox.Text
			local red, green, blue = string.match(text, "^%s*(%d+)%s*[,;%s]%s*(%d+)%s*[,;%s]%s*(%d+)%s*$")
			if red then
				local color = environment.Color3.fromRGB(math.clamp(tonumber(red), 0, 255), math.clamp(tonumber(green), 0, 255), math.clamp(tonumber(blue), 0, 255))
				state.hue, state.saturation, state.value = color:ToHSV()
				update(true)
				state.updatePopup()
				return
			end
			local value = text:gsub("#", ""):gsub("%s", "")
			if #value == 3 then value = value:sub(1, 1):rep(2) .. value:sub(2, 2):rep(2) .. value:sub(3, 3):rep(2) end
			local ok, color = environment.pcall(environment.Color3.fromHex, value)
			if ok and environment.typeof(color) == "Color3" and #value == 6 then
				state.hue, state.saturation, state.value = color:ToHSV()
				update(true)
			end
			state.updatePopup()
		end)
		if alphaBox then
			alphaBox.Focused:Connect(function()
				nova.paint(alphaStroke, "Color", "Accent", "Quick")
				nova.Motion.tween(alphaStroke, "Quick", {Transparency = 0.25})
			end)
			alphaBox.FocusLost:Connect(function()
				nova.paint(alphaStroke, "Color", "Glass", "Quick")
				nova.Motion.tween(alphaStroke, "Quick", {Transparency = 0.84})
				local value = tonumber((alphaBox.Text:gsub("%%", "")))
				if value then state.alpha = math.clamp(value, 0, 100) / 100; update(true) end
				state.updatePopup()
			end)
		end
		window:OpenPopup({close = function()
			for _, connection in ipairs(connections) do connection:Disconnect() end
			state.updatePopup = nil
			nova.Motion.tween(swatchScale, "Quick", {Scale = 1})
			window:PopupConceal(frame, popup)
			environment.task.delay(0.18, function() frame:Destroy() end)
		end})
	end

	function class.Dropdown(section, options)
		options = options or {}
		local window, utility, theme = section.Window, nova.U, nova.Theme
		local inline = section.Nested == true and options.Inline ~= true
		local row = section:_row({Text = options.Text, Desc = options.Desc, Tooltip = options.Tooltip, Reserve = inline and 0 or 190,
			Height = inline and (options.Desc and 74 or 60) or nil, Indent = options.Indent, Order = options.Order, Parent = options.Parent})
		local function normalize(values)
			local items = {}
			for _, item in ipairs(values or {}) do
				if type(item) == "table" then
					table.insert(items, {value = item.code ~= nil and item.code or item.value or item[1],
						label = tostring(item.label or item.Text or item.code or item.value or item[2] or item[1]), image = item.image or item.Image})
				else
					table.insert(items, {value = item, label = tostring(item)})
				end
			end
			return items
		end
		local items, multi, selected, value = normalize(options.Options or options.Values), options.Multi == true, {}, nil
		if multi then
			for _, item in ipairs(type(options.Default) == "table" and options.Default or {}) do selected[item] = true end
		else
			value = options.Default
		end
		local box, stroke
		if inline then
			local x = 10 + row.Indent
			box, stroke = nova.field(row.Frame, {Class = "TextButton", Name = "Box", Size = environment.UDim2.new(1, -(x + 10), 0, 28)})
			box.Position = environment.UDim2.fromOffset(x, row.Frame.Size.Y.Offset - 33)
			row.Title.Position = environment.UDim2.fromOffset(x, 5)
			row.Title.Size = environment.UDim2.new(1, -(x + 10), 0, 18)
			if row.Desc then
				row.Desc.Position = environment.UDim2.fromOffset(x, 24)
				row.Desc.Size = environment.UDim2.new(1, -(x + 10), 0, 16)
			end
			row.Right.Visible = false
		else
			box, stroke = nova.field(row.Right, {Class = "TextButton", Name = "Box", Size = environment.UDim2.fromOffset(150, 30)})
		end
		local titleWidth
		local function measureTitle()
			environment.task.spawn(function()
				local text = row.Title.Text
				local width = utility.textWidth(text, row.Title.FontFace, 14)
				if row.Title.Text == text then
					titleWidth = width
					if row.fitTitle then row.fitTitle() end
				end
			end)
		end
		row.OnWidth = function(width)
			if inline then return end
			local target = width * 0.44
			if titleWidth then target = math.max(target, width - (10 + row.Indent) - titleWidth - 36) end
			target = math.floor(utility.clamp(target, 100, 190))
			if box.Size.X.Offset ~= target then box.Size = environment.UDim2.fromOffset(target, 30) end
		end
		row.Title:GetPropertyChangedSignal("Text"):Connect(measureTitle)
		row.Title:GetPropertyChangedSignal("FontFace"):Connect(measureTitle)
		measureTitle()
		local label = nova.label({Parent = box, Text = "", Font = nova.Font.Medium(), Size = 13, Pos = environment.UDim2.fromOffset(12, 0),
			Box = environment.UDim2.new(1, -46, 1, 0), Truncate = true, Z = 3})
		local valueIcon = utility.new("ImageLabel", {Name = "ValueIcon", BackgroundTransparency = 1, AnchorPoint = environment.Vector2.new(0, 0.5),
			Position = environment.UDim2.new(0, 8, 0.5, 0), Size = environment.UDim2.fromOffset(20, 20), ScaleType = environment.Enum.ScaleType.Fit, Visible = false, ZIndex = 3, Parent = box})
		utility.corner(valueIcon, 5)
		utility.new("Frame", {Name = "Divider", AnchorPoint = environment.Vector2.new(1, 0.5), Position = environment.UDim2.new(1, -30, 0.5, 0),
			Size = environment.UDim2.new(0, 1, 1, -12), BorderSizePixel = 0, BackgroundColor3 = environment.Color3.new(1, 1, 1), BackgroundTransparency = 0.9, ZIndex = 3, Parent = box})
		local chevron = nova.icon({Parent = box, Icon = "chevron-down", Size = 14, Pos = environment.UDim2.new(1, -15, 0.5, 0),
			Anchor = environment.Vector2.new(0.5, 0.5), Color = "Muted", Z = 3})
		local dropdown = {Row = row.Frame, Type = "Dropdown"}
		local function display()
			local image
			if multi then
				local labels = {}
				for _, item in ipairs(items) do if selected[item.value] then table.insert(labels, item.label) end end
				local joined = table.concat(labels, ", ")
				label.Text = #labels == 0 and (options.Placeholder or nova.tr("None")) or ((#labels == 1 or #joined <= 13) and joined or #labels .. " " .. nova.tr("selected"))
			else
				local text
				for _, item in ipairs(items) do
					if item.value == value then text, image = item.label, item.image; break end
				end
				label.Text = text or (value ~= nil and tostring(value)) or (options.Placeholder or nova.tr("Select"))
			end
			if image then
				valueIcon.Image, valueIcon.Visible = image, true
				label.Position = environment.UDim2.fromOffset(34, 0)
				label.Size = environment.UDim2.new(1, -68, 1, 0)
				return
			end
			if valueIcon.Visible then
				valueIcon.Visible = false
				label.Position = environment.UDim2.fromOffset(12, 0)
				label.Size = environment.UDim2.new(1, -46, 1, 0)
			end
		end
		display()
		row.SearchExtra = function() return label.Text end
		row.SearchOptions = function()
			local labels = {}
			for _, item in ipairs(items) do table.insert(labels, tostring(item.label)) end
			return table.concat(labels, " ")
		end
		local function getValue()
			if not multi then return value end
			local values = {}
			for _, item in ipairs(items) do if selected[item.value] then table.insert(values, item.value) end end
			return values
		end
		local opened = false
		local function open()
			if opened then window:ClosePopups(); return end
			opened = true
			nova.Sound.play("click")
			local scale = math.max(window.PopScale.Scale, 0.1)
			local minWidth = 96
			for _, item in ipairs(items) do minWidth = math.max(minWidth, utility.textWidth(item.label, nova.Font.Medium(), 13) + 56) end
			local width = math.min(math.max(box.AbsoluteSize.X / scale, minWidth), 280)
			local filterHeight = #items > 8 and 42 or 0
			local height = math.min(#items, 8) * 32 + 8 + filterHeight
			local frame, popup, popupScale = window:PopupShell(width, height)
			local x, y, _, above = window:PopupPlace(box, width, height, "right")
			frame.Position = environment.UDim2.fromOffset(x, y)
			window:PopupReveal(frame, popup, popupScale, above == 1)
			nova.Motion.tween(chevron, "Base", {Rotation = 180})
			nova.paint(stroke, "Color", "Accent", "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = 0.25})
			nova.paint(chevron, "ImageColor3", "Accent", "Quick")
			local filter, rows = "", {}
			local list = utility.new("ScrollingFrame", {Name = "List", Position = environment.UDim2.fromOffset(0, filterHeight), Size = environment.UDim2.new(1, 0, 1, -filterHeight),
				BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = environment.UDim2.new(), AutomaticCanvasSize = environment.Enum.AutomaticSize.Y, ZIndex = 61, Parent = popup})
			theme.bind(list, "ScrollBarImageColor3", "Faint")
			utility.list(list, 2)
			utility.pad(list, 5, 5, 5, 5)
			local function renderRows()
				for _, old in ipairs(rows) do old:Destroy() end
				rows = {}
				for index, item in ipairs(items) do
					if filter ~= "" and not string.find(string.lower(item.label), filter, 1, true) then continue end
					local isSelected = multi and selected[item.value] or not multi and item.value == value
					local option = utility.new("TextButton", {Name = "Opt", Text = "", AutoButtonColor = false, Size = environment.UDim2.new(1, 0, 0, 30),
						BackgroundTransparency = isSelected and 0.8 or 1, BorderSizePixel = 0, LayoutOrder = index, ZIndex = 62, Parent = list})
					theme.bind(option, "BackgroundColor3", isSelected and "Accent" or "Surface2")
					utility.corner(option, 8)
					local textX = 11
					if item.image then
						local icon = utility.new("ImageLabel", {Name = "Icon", Image = item.image, BackgroundTransparency = 1, AnchorPoint = environment.Vector2.new(0, 0.5),
							Position = environment.UDim2.new(0, 8, 0.5, 0), Size = environment.UDim2.fromOffset(22, 22), ScaleType = environment.Enum.ScaleType.Fit, ZIndex = 62, Parent = option})
						utility.corner(icon, 6)
						textX = 37
					end
					local optionLabel = nova.label({Parent = option, Text = item.label, Font = isSelected and nova.Font.Semi() or nova.Font.Medium(), Size = 13,
						Pos = environment.UDim2.fromOffset(textX, 0), Box = environment.UDim2.new(1, -(textX + 27), 1, 0), Truncate = true, Color = "Text", Z = 62})
					local check = nova.icon({Parent = option, Icon = "check", Size = 14, Pos = environment.UDim2.new(1, -10, 0.5, 0),
						Anchor = environment.Vector2.new(1, 0.5), Color = "Accent", Z = 62})
					if not isSelected then check.ImageTransparency = 1 end
					local hovering = false
					local function style()
						local active = multi and selected[item.value] or not multi and item.value == value
						nova.paint(option, "BackgroundColor3", active and "Accent" or "Surface2", "Quick")
						nova.Motion.tween(option, "Quick", {BackgroundTransparency = hovering and (active and 0.68 or 0.5) or (active and 0.8 or 1)})
					end
					option.MouseEnter:Connect(function() hovering = true; style() end)
					utility.leave(option, function() hovering = false; style() end)
					option.MouseButton1Click:Connect(function()
						nova.Sound.play("tick")
						if multi then
							selected[item.value] = not selected[item.value] or nil
							local active = selected[item.value] == true
							nova.Motion.tween(check, "Quick", {ImageTransparency = active and 0 or 1})
							optionLabel.FontFace = active and nova.Font.Semi() or nova.Font.Medium()
							style()
							display()
							nova.safe(options.Callback, getValue())
							if dropdown.Changed then nova.safe(dropdown.Changed, getValue()) end
							return
						end
						value = item.value
						display()
						window:ClosePopups()
						nova.safe(options.Callback, value)
						if dropdown.Changed then nova.safe(dropdown.Changed, value) end
					end)
					table.insert(rows, option)
				end
			end
			if filterHeight > 0 then
				local search = utility.new("TextBox", {Name = "Filter", Position = environment.UDim2.fromOffset(6, 7), Size = environment.UDim2.new(1, -12, 0, 28),
					BorderSizePixel = 0, Text = "", PlaceholderText = nova.tr("Search") .. "...", FontFace = nova.Font.Medium(), TextSize = 13, ClearTextOnFocus = false,
					TextXAlignment = environment.Enum.TextXAlignment.Left, ZIndex = 62, Parent = popup})
				theme.bind(search, "BackgroundColor3", "Surface")
				theme.bind(search, "TextColor3", "Text")
				theme.bind(search, "PlaceholderColor3", "Faint")
				utility.corner(search, 7)
				utility.pad(search, 0, 8, 0, 8)
				search:GetPropertyChangedSignal("Text"):Connect(function() filter = string.lower(search.Text); renderRows() end)
			end
			renderRows()
			window:OpenPopup({close = function()
				opened = false
				nova.Motion.tween(chevron, "Base", {Rotation = 0})
				nova.paint(stroke, "Color", "Glass", "Quick")
				nova.Motion.tween(stroke, "Quick", {Transparency = 0.84})
				nova.paint(chevron, "ImageColor3", "Muted", "Quick")
				window:PopupConceal(frame, popup)
				environment.task.delay(0.18, function() frame:Destroy() end)
			end})
		end
		box.MouseButton1Click:Connect(open)
		box.MouseEnter:Connect(function()
			if opened then return end
			nova.paint(stroke, "Color", "Accent", "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = 0.62})
			nova.paint(chevron, "ImageColor3", "Text", "Quick")
		end)
		utility.leave(box, function()
			if opened then return end
			nova.paint(stroke, "Color", "Glass", "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = 0.84})
			nova.paint(chevron, "ImageColor3", "Muted", "Quick")
		end)
		dropdown.Set = function(_, nextValue, silent)
			if multi then
				selected = {}
				for _, item in ipairs(type(nextValue) == "table" and nextValue or {}) do selected[item] = true end
			else
				value = nextValue
			end
			display()
			if not silent then nova.safe(options.Callback, getValue()) end
		end
		dropdown.SetValue = function(_, nextValue) dropdown:Set(nextValue) end
		dropdown.SetSilent = function(_, nextValue) dropdown:Set(nextValue, true) end
		dropdown.Get = function() return getValue() end
		dropdown.SetOptions = function(_, values) items = normalize(values); display() end
		dropdown.Refresh = dropdown.SetOptions
		dropdown.SetText = function(_, text) row.SetText(text) end
		dropdown.SetVisible = function(_, visible) row.SetVisible(visible) end
		dropdown.SetParentHidden = function(_, hidden) row.SetParentHidden(hidden) end
		dropdown.RowObj, dropdown.Title = row, row.Title
		return dropdown
	end

	function class.Keybind(section, options)
		options = options or {}
		local window = section.Window
		local row = section:_row({Text = options.Text, Desc = options.Desc, Tooltip = options.Tooltip, Reserve = 110,
			Indent = options.Indent, Order = options.Order, Parent = options.Parent})
		local result = {Row = row.Frame, Type = "Keybind"}
		local bind = nova.bindChip(window, row.Right, options.Default, function(key)
			result.Key = key
			window:_kbDirty()
			nova.safe(options.Callback, key)
			nova.safe(options.ChangedCallback, key)
		end, 10)
		result.Key = options.Default
		local input = nova.Services.UserInputService
		nova.U.connect(input.InputBegan, function(event, processed)
			if window.Listening or not options.Pressed or not result.Key or input:GetFocusedTextBox() then return end
			if nova.bindHit(window, event, result.Key, processed) then nova.safe(options.Pressed, result.Key) end
		end, window.Conns)
		result.Set = function(_, key)
			result.Key = key
			bind.Set(key, true)
			window:_kbDirty()
		end
		if not options.NoList then
			window:RegisterKeybind({kind = "key", name = function() return row.Title.Text end, key = function() return result.Key end,
				active = function()
					if type(options.Active) == "function" then return options.Active() and true or false end
					return nova.keyHeld(result.Key)
				end,
				set = function(key) bind.Set(key) end, alive = function() return row.Frame.Parent ~= nil end})
		end
		result.SetValue = result.Set
		result.Get = function() return result.Key end
		result.SetText = function(_, text) row.SetText(text) end
		result.SetVisible = function(_, visible) row.SetVisible(visible) end
		result.SetParentHidden = function(_, hidden) row.SetParentHidden(hidden) end
		row.SearchExtra = function() return nova.keyName(result.Key) end
		result.RowObj, result.Title = row, row.Title
		return result
	end

	function class.Toggle(section, options)
		options = options or {}
		local window, utility, theme = section.Window, nova.U, nova.Theme
		local row = section:_row({Text = options.Text, Desc = options.Desc, Tooltip = options.Tooltip,
			Reserve = (options.Keybind ~= nil or options.Bind) and 128 or 70, Indent = options.Indent, Order = options.Order, Parent = options.Parent})
		local value = options.Default and true or false
		local hit = row.hit()
		local width, height, knobSize = 48, 24, 18
		if section.Nested then width, height, knobSize = 38, 20, 14 end
		local switch = utility.new("Frame", {Name = "Switch", Size = environment.UDim2.fromOffset(width, height), BackgroundTransparency = 1,
			BorderSizePixel = 0, LayoutOrder = 10, ZIndex = 2, Parent = row.Right})
		utility.corner(switch, environment.UDim.new(1, 0))
		local stroke = utility.stroke(switch, environment.Color3.new(1, 1, 1), 1, 0.86)
		theme.bind(stroke, "Color", "Glass")
		local glow = nova.Tex.image(switch, "glow", {Name = "Glow", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromOffset(width + 36, height + 32), ImageTransparency = 1, ZIndex = 1})
		if glow then theme.bind(glow, "ImageColor3", "Accent") end
		local fill = nova.Tex.image(switch, "pillfill", {Name = "Fill", Size = environment.UDim2.fromScale(1, 1), ZIndex = 2})
		nova.Tex.image(switch, "trackshade", {Name = "Shade", Size = environment.UDim2.fromScale(1, 1), ZIndex = 3})
		if not fill then switch.BackgroundTransparency = 0 end
		local knob = utility.new("Frame", {Name = "Knob", AnchorPoint = environment.Vector2.new(0, 0.5), Position = environment.UDim2.new(0, 3, 0.5, 0),
			Size = environment.UDim2.fromOffset(knobSize, knobSize), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4, Parent = switch})
		local face = nova.Tex.image(knob, "knob", {Name = "Face", Size = environment.UDim2.fromScale(1, 1), ZIndex = 4})
		if face then
			utility.shadow(face, 0.45, 5, 1.5, 0)
		else
			knob.BackgroundTransparency = 0
			utility.corner(knob, environment.UDim.new(1, 0))
		end
		local pressed = false
		local function render(immediate)
			local currentWidth = pressed and knobSize + 6 or knobSize
			local position = value and width - currentWidth - 3 or 3
			local info = immediate and environment.TweenInfo.new(0) or environment.TweenInfo.new(0.3, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
			local colorInfo = immediate and environment.TweenInfo.new(0) or "Quick"
			nova.Motion.tween(knob, info, {Position = environment.UDim2.new(0, position, 0.5, 0), Size = environment.UDim2.fromOffset(currentWidth, knobSize)})
			nova.paint(fill or switch, fill and "ImageColor3" or "BackgroundColor3", value and "Accent" or "Elevated", colorInfo)
			local knobColor = value and "OnAccent" or function(tokens) return tokens.Muted:Lerp(tokens.Text, 0.5) end
			nova.paint(face or knob, face and "ImageColor3" or "BackgroundColor3", knobColor, colorInfo)
			if glow then nova.Motion.tween(glow, colorInfo, {ImageTransparency = value and 0.6 or 1}) end
			nova.paint(stroke, "Color", value and "Accent" or "Glass", colorInfo)
			nova.Motion.tween(stroke, colorInfo, {Transparency = value and 0.55 or 0.86})
		end
		render(true)
		local toggle = {Row = row.Frame, Type = "Toggle"}
		local function setValue(nextValue, notify)
			nextValue = nextValue and true or false
			local changed = nextValue ~= value
			value = nextValue
			render(false)
			if changed then window:_kbDirty() end
			if changed and toggle.Changed then nova.safe(toggle.Changed, value) end
			if notify ~= false then nova.safe(options.Callback, value) end
		end
		local function flip()
			if options.Locked then return end
			nova.Sound.play(value and "off" or "on")
			setValue(not value)
		end
		hit.MouseButton1Down:Connect(function() pressed = true; render(false) end)
		hit.MouseButton1Up:Connect(function() pressed = false end)
		utility.leave(hit, function() if pressed then pressed = false; render(false) end end)
		hit.MouseButton1Click:Connect(function()
			if options.Locked then return end
			pressed = false
			flip()
		end)
		if options.Keybind ~= nil or options.Bind then
			local key = environment.typeof(options.Keybind) == "EnumItem" and options.Keybind or nil
			toggle.Bind = nova.bindChip(window, row.Right, key, function(nextKey)
				nova.safe(options.OnBind, nextKey)
				window:_kbDirty()
			end, 5)
			window:RegisterKeybind({kind = "toggle", name = function() return row.Title.Text end, key = function() return toggle.Bind.Key end,
				active = function() return value end, set = function(nextKey) toggle.Bind.Set(nextKey) end, toggle = flip, alive = function() return row.Frame.Parent ~= nil end})
			if options.KeyToggle then
				utility.connect(nova.Services.UserInputService.InputBegan, function(event, processed)
					if window.Destroyed or window.Listening or options.Locked or nova.Services.UserInputService:GetFocusedTextBox() then return end
					if nova.bindHit(window, event, toggle.Bind.Key, processed) then
						nova.Sound.play(value and "off" or "on")
						setValue(not value)
					end
				end, window.Conns)
			end
		end
		if options.Drawer then section:_toggleDrawer(toggle, row, options, function() return value end) end
		toggle.Set = function(_, nextValue) setValue(nextValue, true) end
		toggle.SetValue = function(_, nextValue) setValue(nextValue, true) end
		toggle.SetSilent = function(_, nextValue) setValue(nextValue, false) end
		toggle.Get = function() return value end
		toggle.SetText = function(_, text) row.SetText(text) end
		toggle.SetDesc = function(_, desc) row.SetDesc(desc) end
		toggle.SetVisible = function(_, visible) row.SetVisible(visible) end
		toggle.SetParentHidden = function(_, hidden) row.SetParentHidden(hidden) end
		toggle.SetLocked = function(_, locked) options.Locked = locked end
		toggle.RowObj, toggle.Title, toggle.DescLabel = row, row.Title, row.Desc
		return toggle
	end

	function class._toggleDrawer(section, toggle, row, options, getValue)
		local window, utility, theme = section.Window, nova.U, nova.Theme
		local icon = nova.icon({Parent = row.Right, Icon = "settings", Size = 13, Color = "Faint", Z = 3})
		icon.LayoutOrder = 8
		section.Order += 1
		local indent = row.Indent
		local tile = utility.new("Frame", {Name = "Tile", Position = environment.UDim2.fromOffset(indent + 2, 1),
			Size = environment.UDim2.new(1, -(indent + 4), 0, row.Frame.Size.Y.Offset - 2), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 0, Parent = row.Frame})
		theme.bind(tile, "BackgroundColor3", "Elevated")
		utility.corner(tile, 10)
		local frame = utility.new("Frame", {Name = "Drawer", Size = environment.UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
			ClipsDescendants = true, LayoutOrder = section.Order, Parent = options.Parent or section.Content})
		local panel = utility.new("Frame", {Name = "Panel", Position = environment.UDim2.fromOffset(indent, 0), Size = environment.UDim2.new(1, -indent, 0, 0),
			AutomaticSize = environment.Enum.AutomaticSize.Y, BorderSizePixel = 0, BackgroundTransparency = 1, Parent = frame})
		local content = utility.new("Frame", {Name = "Content", Size = environment.UDim2.new(1, 0, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, Parent = panel})
		utility.list(content, 0)
		local rule = utility.new("Frame", {Name = "Rule", Position = environment.UDim2.new(0, 12, 0, 0), Size = environment.UDim2.new(1, -24, 0, 1),
			BorderSizePixel = 0, BackgroundTransparency = 0.92, ZIndex = 2, Parent = panel})
		theme.bind(rule, "BackgroundColor3", "Glass")
		utility.pad(content, 3, 2, 4, 2)
		local drawer = setmetatable({Tab = section.Tab, Window = window, Page = section.Page, Side = section.Side, Rows = section.Rows, Order = 0,
			Content = content, Card = section.Card, ParentSection = section, Nested = true}, nova.SectionClass)
		drawer.OwnerToggle, drawer.OwnerRow = toggle, row
		drawer._refreshVisibility = function() section:_refreshVisibility() end
		local rows = {}
		drawer._row = function(self, rowOptions)
			local child = nova.SectionClass._row(self, rowOptions)
			table.insert(rows, child)
			return child
		end
		row.SearchExtra = function()
			local values = {}
			for _, child in ipairs(rows) do table.insert(values, child.Entry.text()) end
			return table.concat(values, " ")
		end
		local manual, search = false, false
		local function isOpen() return manual or search end
		local function openHeight() return math.floor(panel.AbsoluteSize.Y / math.max(window.Scale.Scale, 0.1) + 10) end
		local function tileSize(height)
			return environment.UDim2.new(1, -(indent + 4), 0, row.Frame.Size.Y.Offset - 2 + math.max(height - 8, 0))
		end
		local function update(immediate)
			local open = isOpen()
			nova.paint(icon, "ImageColor3", open and "Accent" or "Faint", immediate and environment.TweenInfo.new(0) or "Quick")
			local height, transparency = open and openHeight() or 0, open and 0.42 or 1
			if immediate then
				frame.Size = environment.UDim2.new(1, 0, 0, height)
				tile.Size = tileSize(height)
				tile.BackgroundTransparency = transparency
				return
			end
			local info = environment.TweenInfo.new(0.34, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
			nova.Motion.tween(frame, info, {Size = environment.UDim2.new(1, 0, 0, height)})
			nova.Motion.tween(tile, info, {Size = tileSize(height), BackgroundTransparency = transparency})
		end
		local function setManual(open, immediate)
			manual = open and true or false
			update(immediate)
		end
		row.OnRefresh = function()
			local query = window.Query or ""
			local hasVisible = query == ""
			if not hasVisible then
				for _, child in ipairs(rows) do
					if child.isVisible() then hasVisible = true; break end
				end
			end
			frame.Visible = row.isVisible() and hasVisible
			tile.Visible = frame.Visible
			local shouldOpen = query ~= "" and hasVisible and row.isVisible()
			if shouldOpen ~= search then
				search = shouldOpen
				update(false)
			end
		end
		local function resize()
			if window.Scaling then
				window:_scalingDefer(resize)
				return
			end
			if isOpen() then
				local height = openHeight()
				frame.Size = environment.UDim2.new(1, 0, 0, height)
				tile.Size = tileSize(height)
			end
		end
		panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		toggle.Drawer, toggle.DrawerFrame = drawer, frame
		toggle.SetDrawer = function(_, open, immediate) setManual(open, immediate) end
		toggle.IsDrawerOpen = function() return manual end
		toggle.Changed = function(value) setManual(value, false) end
		environment.task.defer(function() setManual(getValue(), true) end)
	end

	function class.Slider(section, options)
		options = options or {}
		local minimum, maximum = tonumber(options.Min) or 0, tonumber(options.Max) or 100
		if maximum <= minimum then maximum = minimum + 1 end
		local decimals = tonumber(options.Decimals) or tonumber(options.Rounding) or 0
		local utility, theme, window = nova.U, nova.Theme, section.Window
		local row = section:_row({Text = options.Text, Tooltip = options.Tooltip, Height = 56, Reserve = 90,
			Indent = options.Indent, Order = options.Order, Parent = options.Parent})
		row.Title.Position = environment.UDim2.fromOffset(10 + row.Indent, 7)
		row.Title.Size = environment.UDim2.new(1, -(100 + row.Indent), 0, 20)
		local display = nova.label({Parent = row.Frame, Text = "", Font = nova.Font.Semi(), Size = 13, Anchor = environment.Vector2.new(1, 0),
			Pos = environment.UDim2.new(1, -12, 0, 7), Box = environment.UDim2.fromOffset(90, 20), AlignX = environment.Enum.TextXAlignment.Right, Color = "Muted"})
		row.Right.Visible = false
		row.OnWidth = function(width)
			local displayWidth = display.TextBounds.X / math.max(window.Scale.Scale, 0.1)
			row.Title.Size = environment.UDim2.new(0, math.max(width - (10 + row.Indent) - displayWidth - 28, 40), 0, 20)
		end
		display:GetPropertyChangedSignal("TextBounds"):Connect(function() if row.fitTitle then row.fitTitle() end end)
		local track = utility.new("TextButton", {Name = "Track", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = environment.UDim2.new(0, 12 + row.Indent, 0, 30), Size = environment.UDim2.new(1, -(24 + row.Indent), 0, 20), ZIndex = 2, Parent = row.Frame})
		local bar = utility.new("Frame", {Name = "Bar", AnchorPoint = environment.Vector2.new(0, 0.5), Position = environment.UDim2.fromScale(0, 0.5),
			Size = environment.UDim2.new(1, 0, 0, 8), BorderSizePixel = 0, ZIndex = 2, Parent = track})
		theme.bind(bar, "BackgroundColor3", "Elevated")
		utility.corner(bar, environment.UDim.new(1, 0))
		local shade = utility.new("Frame", {Name = "Shade", Size = environment.UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = environment.Color3.new(0, 0, 0), ZIndex = 2, Parent = bar})
		utility.corner(shade, environment.UDim.new(1, 0))
		local point = environment.NumberSequenceKeypoint.new
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 0.35), point(0.6, 0.9), point(1, 1)}), Rotation = 90, Parent = shade})
		local white = environment.Color3.new(1, 1, 1)
		theme.bind(utility.stroke(bar, white, 1, 0.9), "Color", "Glass")
		local fill = utility.new("Frame", {Name = "Fill", Size = environment.UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = 3, Parent = bar})
		theme.bind(fill, "BackgroundColor3", "Accent")
		utility.corner(fill, environment.UDim.new(1, 0))
		utility.new("UIGradient", {Color = environment.ColorSequence.new(environment.Color3.fromRGB(200, 200, 200), white), Parent = fill})
		local shadow = utility.shadow(fill, 0.55, 8, 0, 0)
		if shadow then theme.bind(shadow, "Color", "Accent") end
		local knob = utility.new("Frame", {Name = "Knob", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0, 0.5),
			Size = environment.UDim2.fromOffset(16, 16), BorderSizePixel = 0, ZIndex = 4, Parent = bar})
		theme.bind(knob, "BackgroundColor3", "OnAccent")
		utility.corner(knob, environment.UDim.new(1, 0))
		if nova.Tex.image(knob, "knob", {Name = "Face", Size = environment.UDim2.fromScale(1, 1), ZIndex = 4}) then knob.BackgroundTransparency = 1 end
		theme.bind(utility.stroke(knob, white, 2, 0.1), "Color", "Accent")
		utility.shadow(knob, 0.35, 6, 1, 0)
		local knobScale = utility.new("UIScale", {Parent = knob})
		local value = utility.clamp(tonumber(options.Default) or minimum, minimum, maximum)
		local slider = {Row = row.Frame, Type = "Slider"}
		local function format(number)
			if options.Display then
				local ok, result = environment.pcall(options.Display, number)
				if ok and type(result) == "string" then return result end
			end
			return utility.fmt(number, decimals) .. (options.Suffix or "")
		end
		local function render(immediate)
			local ratio = (value - minimum) / (maximum - minimum)
			local info = immediate and environment.TweenInfo.new(0) or environment.TweenInfo.new(0.09, environment.Enum.EasingStyle.Quad, environment.Enum.EasingDirection.Out)
			nova.Motion.tween(fill, info, {Size = environment.UDim2.fromScale(ratio, 1)})
			nova.Motion.tween(knob, info, {Position = environment.UDim2.fromScale(ratio, 0.5)})
			display.Text = format(value)
		end
		render(true)
		local function setValue(nextValue, notify)
			nextValue = utility.round(utility.clamp(tonumber(nextValue) or minimum, minimum, maximum), decimals)
			if options.Step then nextValue = utility.round(math.floor((nextValue - minimum) / options.Step + 0.5) * options.Step + minimum, decimals) end
			if nextValue == value and notify ~= "force" then return end
			local previous = value
			value = nextValue
			render(false)
			if notify ~= false then nova.safe(options.Callback, value) end
			if previous ~= value and slider.Changed then nova.safe(slider.Changed, value) end
		end
		local dragging, dragInput, pending, origin = false, nil, nil, nil
		local lastTick = 0
		local function tick(previous)
			if value ~= previous and environment.os.clock() - lastTick > 0.04 then
				lastTick = environment.os.clock()
				nova.Sound.play("tick", 0.5)
			end
		end
		local function updateAt(position)
			local ratio = utility.clamp((position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			local previous = value
			setValue(minimum + (maximum - minimum) * ratio, true)
			tick(previous)
		end
		local function updateRelative(position)
			local ratio = utility.clamp((origin.value - minimum) / (maximum - minimum) + (position.X - origin.x) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			local previous = value
			setValue(minimum + (maximum - minimum) * ratio, true)
			tick(previous)
		end
		track.InputBegan:Connect(function(event)
			if not utility.isClick(event) or options.Locked then return end
			if event.UserInputType == environment.Enum.UserInputType.Touch then
				pending = {input = event, x = event.Position.X, y = event.Position.Y}
				return
			end
			dragging, dragInput, origin = true, event, nil
			nova.Motion.tween(knobScale, "Quick", {Scale = 1.3})
			nova.paint(display, "TextColor3", "Text", "Quick")
			updateAt(event.Position)
		end)
		local input = nova.Services.UserInputService
		utility.connect(input.InputChanged, function(event)
			if pending and event == pending.input then
				local dx, dy = event.Position.X - pending.x, event.Position.Y - pending.y
				if math.abs(dy) > 10 and math.abs(dy) > math.abs(dx) then
					pending = nil
					return
				end
				if math.abs(dx) > 8 then
					pending, dragging, dragInput = nil, true, event
					origin = {x = event.Position.X, value = value}
					nova.Motion.tween(knobScale, "Quick", {Scale = 1.3})
					nova.paint(display, "TextColor3", "Text", "Quick")
				end
				return
			end
			if dragging and utility.sameMove(event, dragInput) then
				if origin then updateRelative(event.Position) else updateAt(event.Position) end
			end
		end, window.Conns)
		utility.connect(input.InputEnded, function(event)
			if pending and event == pending.input then pending = nil end
			if not dragging or not utility.sameEnd(event, dragInput) then return end
			dragging, origin = false, nil
			nova.Motion.tween(knobScale, "PopSmall", {Scale = 1})
			nova.paint(display, "TextColor3", "Muted", "Quick")
			nova.safe(options.Released, value)
		end, window.Conns)
		row.Frame.MouseEnter:Connect(function() if not dragging then nova.Motion.tween(knobScale, "Quick", {Scale = 1.15}) end end)
		utility.leave(row.Frame, function() if not dragging then nova.Motion.tween(knobScale, "Quick", {Scale = 1}) end end)
		slider.Set = function(_, nextValue) setValue(nextValue, true) end
		slider.SetValue = function(_, nextValue) setValue(nextValue, true) end
		slider.SetSilent = function(_, nextValue) setValue(nextValue, false) end
		slider.Get = function() return value end
		slider.SetMax = function(_, nextValue) maximum = tonumber(nextValue) or maximum; setValue(value, false); render(true) end
		slider.SetMin = function(_, nextValue) minimum = tonumber(nextValue) or minimum; setValue(value, false); render(true) end
		slider.Refresh = function() render(true) end
		slider.SetText = function(_, text) row.SetText(text) end
		slider.SetVisible = function(_, visible) row.SetVisible(visible) end
		slider.SetParentHidden = function(_, hidden) row.SetParentHidden(hidden) end
		slider.RowObj, slider.Title = row, row.Title
		return slider
	end

	function class.Input(section, options)
		options = options or {}
		local row = section:_row({Text = options.Text, Desc = options.Desc, Tooltip = options.Tooltip, Reserve = 200,
			Indent = options.Indent, Order = options.Order, Parent = options.Parent})
		local field, stroke = nova.field(row.Right, {Name = "Input", Size = environment.UDim2.fromOffset(options.Width or 150, 30)})
		if not options.Width then
			row.OnWidth = function(width)
				local target = math.floor(nova.U.clamp(width * 0.5, 118, 200))
				if field.Size.X.Offset ~= target then field.Size = environment.UDim2.fromOffset(target, 30) end
			end
		end
		local box = nova.U.new("TextBox", {Name = "Box", BackgroundTransparency = 1, Position = environment.UDim2.fromOffset(10, 0),
			Size = environment.UDim2.new(1, -20, 1, 0), Text = tostring(options.Default or ""), PlaceholderText = options.Placeholder or "",
			FontFace = nova.Font.Medium(), TextSize = 13, ClearTextOnFocus = options.ClearOnFocus == true,
			TextXAlignment = environment.Enum.TextXAlignment.Left, TextTruncate = environment.Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = field})
		nova.Theme.bind(box, "TextColor3", "Text")
		nova.Theme.bind(box, "PlaceholderColor3", "Faint")
		local input = {Row = row.Frame, Type = "Input", Box = box}
		local previous = box.Text
		box.Focused:Connect(function()
			nova.paint(stroke, "Color", "Accent", "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = 0.25})
		end)
		box.FocusLost:Connect(function(enter)
			nova.paint(stroke, "Color", "Glass", "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = 0.84})
			if options.Numeric and box.Text ~= "" and not tonumber(box.Text) then box.Text = previous end
			if box.Text ~= previous or enter then
				previous = box.Text
				local value = options.Numeric and tonumber(box.Text) or box.Text
				nova.safe(options.Callback, value)
				nova.safe(options.Finished, value, enter)
			end
		end)
		if options.Live then
			box:GetPropertyChangedSignal("Text"):Connect(function()
				if options.Numeric and box.Text ~= "" and not tonumber(box.Text) and box.Text ~= "-" and box.Text ~= "." then return end
				nova.safe(options.Callback, options.Numeric and tonumber(box.Text) or box.Text)
			end)
		end
		input.Set = function(_, value) box.Text = tostring(value or ""); previous = box.Text end
		input.SetValue = input.Set
		input.Get = function() return options.Numeric and tonumber(box.Text) or box.Text end
		input.SetText = function(_, value) row.SetText(value) end
		input.SetVisible = function(_, value) row.SetVisible(value) end
		input.SetParentHidden = function(_, value) row.SetParentHidden(value) end
		input.RowObj, input.Title = row, row.Title
		return input
	end

	function class.Button(section, options)
		options = options or {}
		local window, utility, theme = section.Window, nova.U, nova.Theme
		local row = section:_row({Text = "", Tooltip = options.Tooltip, Height = 44, Reserve = 0, Indent = options.Indent, Order = options.Order, Parent = options.Parent})
		row.Title.Visible, row.Right.Visible, row.Hover.Visible = false, false, false
		local primary = options.Style == "Primary"
		local button = utility.new("TextButton", {Name = "Button", Text = "", AutoButtonColor = false, Position = environment.UDim2.fromOffset(8 + row.Indent, 5),
			Size = environment.UDim2.new(1, -(16 + row.Indent), 0, 34), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = row.Frame})
		theme.bind(button, "BackgroundColor3", primary and "Accent" or "Surface2")
		utility.corner(button, 9)
		local white = environment.Color3.new(1, 1, 1)
		local stroke = utility.stroke(button, white, 1, 0.9)
		theme.bind(stroke, "Color", "Glass")
		local shadow = utility.shadow(button, 0.7, 10, 3, 0)
		local scale = utility.new("UIScale", {Parent = button})
		utility.new("UIGradient", {Color = environment.ColorSequence.new(white, environment.Color3.fromRGB(205, 207, 214)), Rotation = 90, Parent = button})
		local bevel = utility.new("Frame", {Name = "Bevel", Size = environment.UDim2.new(1, -16, 0, 1), Position = environment.UDim2.fromOffset(8, 1),
			BorderSizePixel = 0, BackgroundColor3 = white, BackgroundTransparency = primary and 0.55 or 0.8, ZIndex = 3, Parent = button})
		local point = environment.NumberSequenceKeypoint.new
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 1), point(0.5, 0), point(1, 1)}), Parent = bevel})
		local spotIdle, spotHover = 1, primary and 0.76 or 0.66
		local clip = utility.new("CanvasGroup", {Name = "SpotClip", Size = environment.UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = button})
		utility.corner(clip, 9)
		local spot = nova.Tex.image(clip, "glow", {Name = "Spot", AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromOffset(190, 120), ImageTransparency = spotIdle, ZIndex = 2})
		if spot then theme.bind(spot, "ImageColor3", primary and "OnAccent" or "Accent") end
		local gradient = utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 0.85), point(0.5, 0), point(1, 0.85)}), Enabled = false, Parent = stroke})
		local easing, direction = environment.Enum.EasingStyle, environment.Enum.EasingDirection
		local enter = environment.TweenInfo.new(0.24, easing.Sine, direction.Out)
		local leave = environment.TweenInfo.new(0.32, easing.Sine, direction.Out)
		local move = environment.TweenInfo.new(0.14, easing.Quad, direction.Out)
		local press = environment.TweenInfo.new(0.1, easing.Quad, direction.Out)
		local release = environment.TweenInfo.new(0.32, easing.Quint, direction.Out)
		local hovering = false
		local function moveSpot(immediate)
			if button.AbsoluteSize.X < 1 then return end
			local x = utility.clamp((utility.mouse().X - button.AbsolutePosition.X) / button.AbsoluteSize.X, 0, 1)
			if spot and immediate then spot.Position = environment.UDim2.fromScale(x, 0.5) end
			if spot and not immediate then nova.Motion.tween(spot, move, {Position = environment.UDim2.fromScale(x, 0.5)}) end
			if immediate then
				gradient.Offset = environment.Vector2.new(x - 0.5, 0)
				return
			end
			nova.Motion.tween(gradient, move, {Offset = environment.Vector2.new(x - 0.5, 0)})
		end
		local content = utility.new("Frame", {Name = "Content", Size = environment.UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = button})
		local label = nova.label({Parent = content, Text = options.Text or "Button", Font = nova.Font.Semi(), Size = 14,
			Box = environment.UDim2.fromScale(1, 1), AlignX = environment.Enum.TextXAlignment.Center, Color = primary and "OnAccent" or "Text", Z = 3})
		if options.Icon then
			label.Size = environment.UDim2.new(1, -24, 1, 0)
			label.Position = environment.UDim2.fromOffset(24, 0)
			nova.icon({Parent = content, Icon = options.Icon, Size = 15, Pos = environment.UDim2.new(0.5, -math.floor(utility.textWidth(options.Text or "", nova.Font.Semi(), 14) / 2) - 2, 0.5, 0),
				Anchor = environment.Vector2.new(1, 0.5), Color = primary and "OnAccent" or "Accent", Z = 3})
		end
		local confirming, token = false, 0
		local result = {Row = row.Frame, Type = "Button", Base = button}
		local function resetConfirmation()
			confirming = false
			label.Text = options.Text or "Button"
			gradient.Enabled = hovering
			local role = hovering and (primary and "OnAccent" or "Accent") or "Glass"
			nova.paint(stroke, "Color", role, "Quick")
			nova.Motion.tween(stroke, "Quick", {Transparency = hovering and (primary and 0.55 or 0.4) or 0.9})
		end
		button.MouseEnter:Connect(function()
			if options.Locked then return end
			hovering = true
			moveSpot(true)
			if spot then nova.Motion.tween(spot, enter, {ImageTransparency = spotHover}) end
			if not primary then nova.paint(button, "BackgroundColor3", "Elevated", enter) end
			if shadow then nova.Motion.tween(shadow, enter, {Transparency = 0.55}) end
			if not confirming then
				gradient.Enabled = true
				nova.paint(stroke, "Color", primary and "OnAccent" or "Accent", enter)
				nova.Motion.tween(stroke, enter, {Transparency = primary and 0.55 or 0.4})
			end
			nova.Sound.play("hover", 0.6)
			if options.Tooltip then window:ShowTip(options.Tooltip) end
		end)
		button.MouseMoved:Connect(function() if hovering then moveSpot(false) end end)
		utility.leave(button, function()
			hovering = false
			if spot then nova.Motion.tween(spot, leave, {ImageTransparency = spotIdle}) end
			if not primary then nova.paint(button, "BackgroundColor3", "Surface2", leave) end
			if shadow then nova.Motion.tween(shadow, leave, {Transparency = 0.75}) end
			if not confirming then
				nova.paint(stroke, "Color", "Glass", leave)
				nova.Motion.tween(stroke, leave, {Transparency = 0.9})
				environment.task.delay(0.32, function() if not hovering and not confirming then gradient.Enabled = false end end)
			end
			nova.Motion.tween(scale, release, {Scale = 1})
			window:HideTip()
		end)
		button.MouseButton1Down:Connect(function()
			if options.Locked then return end
			nova.Motion.tween(scale, press, {Scale = 0.975})
			if spot then nova.Motion.tween(spot, press, {ImageTransparency = spotHover - 0.14}) end
		end)
		button.MouseButton1Up:Connect(function()
			nova.Motion.tween(scale, release, {Scale = 1})
			if spot then nova.Motion.tween(spot, release, {ImageTransparency = hovering and spotHover or spotIdle}) end
		end)
		button.MouseButton1Click:Connect(function()
			if options.Locked then return end
			nova.Sound.play("click")
			if options.Confirm and type(window.ConfirmPopup) == "function" then
				window:ConfirmPopup(button, options.Confirm, function() nova.safe(options.Callback) end)
				return
			end
			if options.DoubleClick and not confirming then
				confirming = true
				token += 1
				local current = token
				label.Text = options.ConfirmText or "Click again to confirm"
				gradient.Enabled = false
				nova.paint(stroke, "Color", "Danger", "Quick")
				nova.Motion.tween(stroke, "Quick", {Transparency = 0.3})
				environment.task.delay(2.5, function() if confirming and token == current then resetConfirmation() end end)
				return
			end
			if confirming then resetConfirmation() end
			nova.safe(options.Callback)
		end)
		result.SetText = function(_, text)
			options.Text = tostring(text)
			if not confirming then label.Text = options.Text end
		end
		result.SetVisible = function(_, visible) row.SetVisible(visible) end
		result.SetParentHidden = function(_, hidden) row.SetParentHidden(hidden) end
		result.SetLocked = function(_, locked) options.Locked = locked; label.TextTransparency = locked and 0.5 or 0 end
		row.SearchExtra = function() return options.Text or "" end
		result.RowObj, result.Label = row, label
		return result
	end

	function class.Label(section, options)
		if type(options) == "string" then options = {Text = options} end
		options = options or {}
		section.Order += 1
		local frame = nova.U.new("Frame", {Name = "Label", Size = environment.UDim2.new(1, 0, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, LayoutOrder = options.Order or section.Order, Parent = options.Parent or section.Content})
		nova.U.pad(frame, 6, 10, 6, 10 + (options.Indent or 0) * 14)
		local label = nova.label({Parent = frame, Text = options.Text or "", Font = nova.Font.Regular(), Size = options.Size or 13,
			Box = environment.UDim2.new(1, 0, 0, 0), Auto = environment.Enum.AutomaticSize.Y, Wrap = true, Rich = true, Color = options.Color or "Muted"})
		local row = {Frame = frame, Title = label, selfHidden = false, parentHidden = false, searchHidden = false}
		local entry = {text = function() return string.lower(label.Text) end, refresh = function() frame.Visible = not (row.selfHidden or row.parentHidden or row.searchHidden) end}
		table.insert(section.Tab.Rows, entry)
		table.insert(section.Rows, row)
		row.Entry = entry
		return {Row = frame, Type = "Label", Label = label, Title = label,
			SetText = function(_, text) label.Text = tostring(text) end,
			SetVisible = function(_, visible) row.selfHidden = not visible; entry.refresh() end,
			SetParentHidden = function(_, hidden) row.parentHidden = hidden and true or false; entry.refresh() end}
	end

	function class.Paragraph(section, options)
		options = options or {}
		section.Order += 1
		local frame = nova.U.new("Frame", {Name = "Paragraph", Size = environment.UDim2.new(1, 0, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, LayoutOrder = options.Order or section.Order, Parent = options.Parent or section.Content})
		nova.U.pad(frame, 8, 10, 8, 10)
		nova.U.list(frame, 3)
		local title = nova.label({Parent = frame, Text = options.Title or "", Font = nova.Font.Semi(), Size = 14, Box = environment.UDim2.new(1, 0, 0, 18)})
		local text = nova.label({Parent = frame, Text = options.Text or "", Font = nova.Font.Regular(), Size = 13, Box = environment.UDim2.new(1, 0, 0, 0),
			Auto = environment.Enum.AutomaticSize.Y, Wrap = true, Rich = true, Color = "Muted"})
		text.LayoutOrder = 1
		return {Row = frame, Type = "Paragraph", SetTitle = function(_, value) title.Text = tostring(value) end,
			SetText = function(_, value) text.Text = tostring(value) end, SetVisible = function(_, visible) frame.Visible = visible end}
	end

	function class.Divider(section, title)
		section.Order += 1
		local frame = nova.U.new("Frame", {Name = "Divider", Size = environment.UDim2.new(1, 0, 0, title and 30 or 13),
			BackgroundTransparency = 1, LayoutOrder = section.Order, Parent = section.Content})
		local line = nova.U.new("Frame", {AnchorPoint = environment.Vector2.new(0, 1), Position = environment.UDim2.new(0, 10, 1, -6),
			Size = environment.UDim2.new(1, -20, 0, 1), BorderSizePixel = 0, Parent = frame})
		nova.Theme.bind(line, "BackgroundColor3", "Line")
		local label
		if title then
			label = nova.label({Parent = frame, Text = string.upper(title), Font = nova.Font.Bold(), Size = 11, Pos = environment.UDim2.fromOffset(10, 4),
				Box = environment.UDim2.new(1, -20, 0, 14), Color = "Faint"})
		end
		return {Row = frame, Type = "Divider", Label = label, SetText = function(_, value) if label then label.Text = string.upper(tostring(value)) end end,
			SetVisible = function(_, visible) frame.Visible = visible end}
	end

	function class.Container(section, options)
		options = options or {}
		section.Order += 1
		local frame = nova.U.new("Frame", {Name = "Container", Size = environment.UDim2.new(1, 0, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, LayoutOrder = options.Order or section.Order, Parent = options.Parent or section.Content})
		nova.U.pad(frame, options.Pad or 4, 8, options.Pad or 4, 8)
		nova.U.list(frame, options.Gap or 6)
		return frame
	end

	function class._row(section, options)
		section.Order += 1
		section.Tab.Loads[section.Page.Key] = (section.Tab.Loads[section.Page.Key] or 0) + 1
		if not section.ParentSection then section.Page.Load[section.Side] += 1 end
		local window, utility = section.Window, nova.U
		local desc, nested = options.Desc, section.Nested == true
		local height = options.Height or (desc and (nested and 46 or 50) or (nested and 33 or 38))
		local indent = (options.Indent or 0) * 14
		local frame = utility.new("Frame", {Name = options.Name or "Row", Size = environment.UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1, LayoutOrder = options.Order or section.Order, Parent = options.Parent or section.Content})
		local hover = utility.new("Frame", {Name = "Hover", Position = environment.UDim2.fromOffset(indent, 1), Size = environment.UDim2.new(1, -indent, 1, -2),
			BorderSizePixel = 0, BackgroundTransparency = 1, Parent = frame})
		nova.Theme.bind(hover, "BackgroundColor3", "Elevated")
		utility.corner(hover, 9)
		if indent > 0 then
			local guide = utility.new("Frame", {Name = "Guide", Position = environment.UDim2.fromOffset(indent - 6, 8), Size = environment.UDim2.new(0, 2, 1, -16), BorderSizePixel = 0, Parent = frame})
			nova.Theme.bind(guide, "BackgroundColor3", nova.Theme.accentSoft(0.45))
			utility.corner(guide, environment.UDim.new(1, 0))
		end
		local row = {Frame = frame, Hover = hover, Section = section, Opts = options, Indent = indent}
		local titleX = 10 + indent
		local color = nested and function(tokens) return tokens.Text:Lerp(tokens.Muted, 0.22) end or nil
		row.Title = nova.label({Parent = frame, Text = options.Text or "", Font = nova.Font.Medium(), Size = nested and 13 or 14, Color = color,
			Pos = environment.UDim2.fromOffset(titleX, desc and 8 or 0), Box = environment.UDim2.new(1, -(titleX + (options.Reserve or 70)), 0, desc and 18 or height),
			Truncate = true, Rich = options.Rich})
		if desc then
			row.Desc = nova.label({Parent = frame, Text = desc, Font = nova.Font.Regular(), Size = 12, Pos = environment.UDim2.fromOffset(titleX, 27),
				Box = environment.UDim2.new(1, -(titleX + (options.Reserve or 70)), 0, 16), Color = "Muted", Truncate = true})
		end
		row.Right = utility.new("Frame", {Name = "Right", AnchorPoint = environment.Vector2.new(1, 0.5), Position = environment.UDim2.new(1, -10, 0.5, 0),
			Size = environment.UDim2.fromOffset(0, 28), AutomaticSize = environment.Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 2, Parent = frame})
		utility.list(row.Right, 8, environment.Enum.FillDirection.Horizontal, environment.Enum.HorizontalAlignment.Right, environment.Enum.VerticalAlignment.Center)
		local wrapHeight = not desc and not options.Height and options.Wrap ~= false and (nested and 46 or 52) or nil
		local textWidth, measuredKey, fitTitle
		local function measureTitle()
			if not wrapHeight then return end
			local title = row.Title
			local key = title.Text .. "|" .. tostring(title.TextSize) .. "|" .. tostring(title.FontFace)
			if key == measuredKey then return end
			measuredKey = key
			environment.task.spawn(function()
				local width = utility.textWidth(title.Text, title.FontFace, title.TextSize)
				if measuredKey == key then
					textWidth = width
					if fitTitle then fitTitle() end
				end
			end)
		end
		fitTitle = function()
			if window.Scaling then
				window:_scalingDefer(fitTitle)
				return
			end
			local scale = math.max(window.Scale.Scale, 0.1)
			if row.OnWidth then row.OnWidth(frame.AbsoluteSize.X / scale) end
			if options.Reserve == 0 or not row.Right.Visible then return end
			local available = frame.AbsoluteSize.X / scale - titleX - row.Right.AbsoluteSize.X / scale - 16
			local titleHeight = row.Title.Size.Y.Offset
			if wrapHeight and textWidth then
				local wrapped = textWidth > math.max(available, 40) + 1
				if wrapped ~= (row.wrapped == true) then
					row.wrapped = wrapped
					row.Title.TextWrapped = wrapped
					frame.Size = environment.UDim2.new(1, 0, 0, wrapped and wrapHeight or height)
				end
				titleHeight = wrapped and wrapHeight or height
			end
			row.Title.Size = environment.UDim2.new(0, math.max(available, 40), row.Title.Size.Y.Scale, titleHeight)
			if row.Desc then row.Desc.Size = environment.UDim2.new(0, math.max(available, 40), 0, 16) end
		end
		row.fitTitle = fitTitle
		row.Right:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTitle)
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTitle)
		if wrapHeight then
			row.Title:GetPropertyChangedSignal("Text"):Connect(measureTitle)
			row.Title:GetPropertyChangedSignal("TextSize"):Connect(measureTitle)
			row.Title:GetPropertyChangedSignal("FontFace"):Connect(measureTitle)
			environment.task.defer(measureTitle)
		end
		environment.task.defer(fitTitle)
		row.selfHidden, row.parentHidden, row.searchHidden = false, false, false
		local entry = {sec = section, searchHidden = false, row = row, text = function()
			local text = row.Title and row.Title.Text or ""
			if row.Desc then text ..= " " .. row.Desc.Text end
			if row.SearchExtra then text ..= " " .. row.SearchExtra() end
			return string.lower(text)
		end}
		row.isVisible = function() return not (row.selfHidden or row.parentHidden or entry.searchHidden) end
		entry.refresh = function()
			frame.Visible = row.isVisible()
			if row.OnRefresh then row.OnRefresh() end
		end
		row.Entry = entry
		table.insert(section.Tab.Rows, entry)
		table.insert(section.Rows, row)
		row.setHover = function(active) nova.Motion.tween(hover, "Quick", {BackgroundTransparency = active and 0.55 or 1}) end
		frame.MouseEnter:Connect(function()
			row.setHover(true)
			if options.Tooltip then window:ShowTip(options.Tooltip) end
		end)
		utility.leave(frame, function()
			row.setHover(false)
			if options.Tooltip then window:HideTip() end
		end)
		row.SetText = function(text) row.Title.Text = tostring(text) end
		row.SetDesc = function(text) if row.Desc then row.Desc.Text = tostring(text) end end
		row.SetVisible = function(visible)
			row.selfHidden = not visible
			entry.refresh()
			section:_refreshVisibility()
		end
		row.SetParentHidden = function(hidden)
			row.parentHidden = hidden and true or false
			entry.refresh()
			section:_refreshVisibility()
		end
		row.hit = function()
			return utility.new("TextButton", {Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
				Size = environment.UDim2.fromScale(1, 1), ZIndex = 1, Parent = frame})
		end
		return row
	end

	function class.IsCollapsed(section)
		return section.Collapsed == true
	end

	function class.Float(section, position)
		section.Window:FloatSection(section, position)
	end

	function class.Dock(section)
		section.Window:DockSection(section)
	end

	return class
end

function NovaTab.createClass(environment, nova)
	local class = {}
	class.__index = class

	function class.Section(tab, options)
		if type(options) == "string" then options = {Title = options} end
		options = options or {}
		local window, utility, theme = tab.Window, nova.U, nova.Theme
		local sub = options.Sub or tab.SubDefs and (options.Sub or tab.BuildSub or tab.SubDefs[1].key)
		local page = tab:_page(sub or "_")
		local column = page.Left
		if tab.Columns ~= 1 and not page.One and (options.Side == "Right" or options.Side ~= "Left" and page.Load[1] > page.Load[2]) then column = page.Right end
		local section = setmetatable({}, nova.SectionClass)
		section.Tab, section.Window, section.Page = tab, window, page
		section.Side, section.Pinned, section.Rows, section.Order = column == page.Left and 1 or 2, options.Side ~= nil, {}, 0
		section.Key = tab.Name .. "/" .. tostring(options.Title or "Section")
		tab.KeyCount = tab.KeyCount or {}
		local count = (tab.KeyCount[section.Key] or 0) + 1
		tab.KeyCount[section.Key] = count
		if count > 1 then section.Key ..= "#" .. count end
		table.insert(tab.Sections, section)
		local wrap = utility.new("Frame", {Name = options.Title or "Section", Size = environment.UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1, LayoutOrder = #column:GetChildren(), Parent = column})
		section.Wrap = wrap
		section.Shadow = nova.Tex.image(wrap, "shadow9", {Name = "Shadow", Position = environment.UDim2.fromOffset(-28, -18),
			Size = environment.UDim2.new(1, 56, 1, 58), SliceScale = 1, ImageTransparency = 0.62, ZIndex = 0})
		local card = utility.new("Frame", {Name = "Card", Size = environment.UDim2.new(1, 0, 0, 44), BorderSizePixel = 0,
			BackgroundTransparency = 0.03, ClipsDescendants = true, ZIndex = 1, Parent = wrap})
		theme.bind(card, "BackgroundColor3", "Surface")
		utility.corner(card, 14)
		section.CardGrad = utility.new("UIGradient", {Color = environment.ColorSequence.new(environment.Color3.new(1, 1, 1), environment.Color3.fromRGB(208, 210, 218)), Rotation = 90, Parent = card})
		section.Card = card
		section.Gloss = nova.Tex.image(card, "gloss9", {Name = "Gloss", Size = environment.UDim2.fromScale(1, 1), SliceScale = 1, ImageTransparency = 0.9, ZIndex = 1})
		section.Grain = nova.Tex.image(card, "grain", {Name = "Grain", Size = environment.UDim2.fromScale(1, 1), ImageTransparency = 0.94, ZIndex = 1})
		section.Spot = nova.Tex.image(card, "glow", {Name = "Spot", AnchorPoint = environment.Vector2.new(0.5, 0.5), Size = environment.UDim2.fromOffset(300, 220), ImageTransparency = 1, ZIndex = 1})
		if section.Spot then theme.bind(section.Spot, "ImageColor3", "Accent") end
		section.Rim = nova.Tex.image(card, "rim9", {Name = "Rim", Size = environment.UDim2.fromScale(1, 1), SliceScale = 1, ImageTransparency = 0.5, ZIndex = 8})
		if section.Rim then
			theme.bind(section.Rim, "ImageColor3", "Glass")
		else
			theme.bind(utility.stroke(card, environment.Color3.new(1, 1, 1), 1, 0.92), "Color", "Glass")
		end

		local stack = utility.new("Frame", {Name = "Stack", Size = environment.UDim2.new(1, 0, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, ZIndex = 2, Parent = card})
		utility.list(stack, 0)
		section._sync = function()
			if window.Scaling and not section.Floating then
				window:_scalingDefer(section._sync)
				return
			end
			local height = math.ceil(stack.AbsoluteSize.Y / math.max(window.Scale.Scale, 0.1))
			if height < 1 then return end
			card.Size = environment.UDim2.new(1, 0, 0, height)
			wrap.Size = environment.UDim2.new(wrap.Size.X.Scale, wrap.Size.X.Offset, 0, height)
		end
		stack:GetPropertyChangedSignal("AbsoluteSize"):Connect(section._sync)
		local head = utility.new("Frame", {Name = "Head", Size = environment.UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 3, Parent = stack})
		section.Head = head
		local titleX = 16
		if options.Icon then
			section.IconTile = nova.tile(head, {Name = "IconTile", Size = environment.UDim2.fromOffset(26, 26), Pos = environment.UDim2.new(0, 12, 0.5, 0),
				Anchor = environment.Vector2.new(0, 0.5), Color = "Accent", Alpha = 0.78, Z = 3})
			section.HeadIcon = nova.icon({Parent = head, Icon = options.Icon, Size = 15, Pos = environment.UDim2.new(0, 25, 0.5, 0),
				Anchor = environment.Vector2.new(0.5, 0.5), Color = "Accent", Z = 4})
			titleX = 46
		end
		section.TitleLabel = nova.label({Parent = head, Text = options.Title or "Section", Font = nova.Font.Bold(), Size = 14,
			Pos = environment.UDim2.new(0, titleX, 0, 0), Box = environment.UDim2.new(1, -titleX - 52, 1, 0), Truncate = true, Z = 4})
		section.Accessory = utility.new("Frame", {Name = "Accessory", AnchorPoint = environment.Vector2.new(1, 0.5), Position = environment.UDim2.new(1, -34, 0.5, 0),
			Size = environment.UDim2.fromOffset(0, 24), AutomaticSize = environment.Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 9, Parent = head})
		utility.list(section.Accessory, 6, environment.Enum.FillDirection.Horizontal, environment.Enum.HorizontalAlignment.Right, environment.Enum.VerticalAlignment.Center)
		section.Chev = nova.icon({Parent = head, Icon = "chevron-down", Size = 14, Pos = environment.UDim2.new(1, -16, 0.5, 0), Anchor = environment.Vector2.new(0.5, 0.5), Color = "Faint", Z = 4})
		section.HeadLine = utility.new("Frame", {Name = "Line", AnchorPoint = environment.Vector2.new(0.5, 1), Position = environment.UDim2.new(0.5, 0, 1, 0),
			Size = environment.UDim2.new(1, -28, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.5, ZIndex = 3, Parent = head})
		theme.bind(section.HeadLine, "BackgroundColor3", "Line")
		local point = environment.NumberSequenceKeypoint.new
		utility.new("UIGradient", {Transparency = environment.NumberSequence.new({point(0, 1), point(0.12, 0), point(0.88, 0), point(1, 1)}), Parent = section.HeadLine})
		local hit = utility.new("TextButton", {Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = environment.UDim2.fromScale(1, 1), ZIndex = 6, Parent = head})
		section.HeadHit = hit
		hit.InputBegan:Connect(function(event)
			if event.UserInputType == environment.Enum.UserInputType.MouseButton1 or event.UserInputType == environment.Enum.UserInputType.Touch then window:_cardPress(section, event) end
		end)
		hit.MouseButton1Click:Connect(function()
			if window.CardDrag or environment.os.clock() - (window.LastCardDrag or 0) < 0.3 or options.Collapsible == false then return end
			nova.Sound.play("tick")
			section:SetCollapsed(not section.Collapsed)
		end)
		hit.MouseEnter:Connect(function()
			if options.Collapsible ~= false then nova.paint(section.Chev, "ImageColor3", "Text", "Quick") end
			window:ShowTip("Drag out to float В· click to fold")
		end)
		utility.leave(hit, function()
			nova.paint(section.Chev, "ImageColor3", "Faint", "Quick")
			window:HideTip()
		end)
		if options.Collapsible == false then section.Chev.Visible = false end
		section.Body = utility.new("Frame", {Name = "Body", Size = environment.UDim2.new(1, 0, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 1, ZIndex = 2, Parent = stack})
		local content = utility.new("Frame", {Name = "Content", Size = environment.UDim2.new(1, 0, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, ZIndex = 2, Parent = section.Body})
		utility.list(content, 0)
		utility.pad(content, 6, 6, 10, 6)
		section.Content = content
		card.MouseMoved:Connect(function()
			if not section.Spot then return end
			local offset = (utility.mouse() - card.AbsolutePosition) / math.max(window.Scale.Scale, 0.1)
			section.Spot.Position = environment.UDim2.fromOffset(offset.X, offset.Y)
		end)
		card.MouseEnter:Connect(function()
			if section.Spot then nova.Motion.tween(section.Spot, "Base", {ImageTransparency = 0.9}) end
			if section.Rim then nova.Motion.tween(section.Rim, "Quick", {ImageTransparency = 0.25}) end
		end)
		utility.leave(card, function()
			if section.Spot then nova.Motion.tween(section.Spot, "Base", {ImageTransparency = 1}) end
			if section.Rim then nova.Motion.tween(section.Rim, "Quick", {ImageTransparency = section.Floating and 0.3 or 0.5}) end
		end)
		page.Load[section.Side] += 1
		tab:_queueBalance(page)
		window:_applyCardStyle(section)
		local collapsed = window.State.get("collapsed", {})
		if type(collapsed) == "table" and collapsed[section.Key] then section:SetCollapsed(true, true) end
		local floats = window.State.get("floats", {})
		if type(floats) == "table" and floats[section.Key] then
			local position = floats[section.Key]
			environment.task.delay(0.8, function()
				if not section.Floating and not window.Destroyed then
					environment.pcall(function() window:FloatSection(section, environment.Vector2.new(tonumber(position[1]) or 40, tonumber(position[2]) or 40)) end)
				end
			end)
		end
		return section
	end

	function class._setActive(tab, active)
		tab.Window:_styleTab(tab, active, true)
	end

	function class._page(tab, key)
		key = key or "_"
		if tab.Pages[key] then return tab.Pages[key] end
		local one = tab.Columns == 1 or tab.PageColumns ~= nil and tab.PageColumns[key] == 1
		local offset = tab.SubBar and 48 or 0
		local utility = nova.U
		local clip = utility.new("CanvasGroup", {Name = "Clip_" .. tostring(key), Position = environment.UDim2.fromOffset(0, offset),
			Size = environment.UDim2.new(1, 0, 1, -offset), BackgroundTransparency = 1, Visible = key == "_" or key == tab.ActiveSub, Parent = tab.PageHost})
		local scroll = utility.new("ScrollingFrame", {Name = "Page_" .. tostring(key), Size = environment.UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageTransparency = 0.4, CanvasSize = environment.UDim2.new(), AutomaticCanvasSize = environment.Enum.AutomaticSize.Y,
			ScrollingDirection = environment.Enum.ScrollingDirection.Y, Parent = clip})
		local gradient = utility.new("UIGradient", {Rotation = 90, Parent = clip})
		local function updateGradient()
			if tab.Window.Scaling then
				tab.Window:_scalingDefer(updateGradient)
				return
			end
			local height = clip.AbsoluteSize.Y
			if height < 60 then return end
			local top = math.clamp(scroll.CanvasPosition.Y / 12, 0, 1)
			local bottom = math.clamp((scroll.AbsoluteCanvasSize.Y - scroll.CanvasPosition.Y - scroll.AbsoluteWindowSize.Y) / 12, 0, 1)
			local inset = math.min(22 / height, 0.3)
			local point = environment.NumberSequenceKeypoint.new
			gradient.Transparency = environment.NumberSequence.new({point(0, top * 0.9), point(inset, 0), point(1 - inset, 0), point(1, bottom * 0.9)})
		end
		scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateGradient)
		scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateGradient)
		scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateGradient)
		environment.task.defer(updateGradient)
		nova.Theme.bind(scroll, "ScrollBarImageColor3", "Faint")
		utility.pad(scroll, 6, 0, 22, 0)
		local columns = utility.new("Frame", {Name = "Columns", Position = environment.UDim2.fromOffset(22, 0), Size = environment.UDim2.new(1, -44, 0, 0),
			AutomaticSize = environment.Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll})
		local left = utility.new("Frame", {Name = "Left", Size = environment.UDim2.new(one and 1 or 0.5, one and 0 or -8, 0, 0),
			AutomaticSize = environment.Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = columns})
		utility.list(left, 16)
		local right = utility.new("Frame", {Name = "Right", AnchorPoint = environment.Vector2.new(1, 0), Position = environment.UDim2.fromScale(1, 0),
			Size = environment.UDim2.new(0.5, -8, 0, 0), AutomaticSize = environment.Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = not one, Parent = columns})
		utility.list(right, 16)
		local page = {Root = clip, Scroll = scroll, Left = left, Right = right, Load = {0, 0}, Key = key, Cols = columns, One = one}
		local layout = utility.new("UIListLayout", {Padding = environment.UDim.new(0, 16), SortOrder = environment.Enum.SortOrder.LayoutOrder})
		local stacked = false
		local function updateColumns()
			if tab.Window.Scaling then
				tab.Window:_scalingDefer(updateColumns)
				return
			end
			local width = scroll.AbsoluteSize.X / math.max(tab.Window.Scale.Scale, 0.1)
			local shouldStack = not one and width < 440
			if shouldStack == stacked then return end
			stacked = shouldStack
			if stacked then
				left.Size = environment.UDim2.new(1, 0, 0, 0)
				right.AnchorPoint, right.Position, right.Size = environment.Vector2.zero, environment.UDim2.new(), environment.UDim2.new(1, 0, 0, 0)
				left.LayoutOrder, right.LayoutOrder, layout.Parent = 1, 2, columns
				return
			end
			layout.Parent = nil
			left.Size = environment.UDim2.new(0.5, -8, 0, 0)
			right.AnchorPoint, right.Position, right.Size = environment.Vector2.new(1, 0), environment.UDim2.fromScale(1, 0), environment.UDim2.new(0.5, -8, 0, 0)
		end
		scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateColumns)
		environment.task.defer(updateColumns)
		tab.Pages[key] = page
		return page
	end

	function class.SubTabs(tab, options)
		if tab.SubBar then return end
		local definitions = {}
		for _, option in ipairs(options or {}) do
			if type(option) == "string" then option = {key = option, label = option} end
			if type(option) == "table" and option.key then table.insert(definitions, option) end
		end
		if #definitions == 0 then return end
		tab.SubDefs = definitions
		for _, definition in ipairs(definitions) do
			if definition.Columns then
				tab.PageColumns = tab.PageColumns or {}
				tab.PageColumns[definition.key] = definition.Columns
			end
		end
		local utility, theme = nova.U, nova.Theme
		local bar = utility.new("Frame", {Name = "SubBar", Size = environment.UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = tab.Frame})
		tab.SubBar = bar
		local shell = utility.new("Frame", {Name = "Shell", Position = environment.UDim2.fromOffset(22, 6), Size = environment.UDim2.fromOffset(0, 36),
			AutomaticSize = environment.Enum.AutomaticSize.X, BorderSizePixel = 0, Parent = bar})
		theme.bind(shell, "BackgroundColor3", "Surface")
		utility.corner(shell, 11)
		theme.bind(utility.stroke(shell, environment.Color3.new(1, 1, 1), 1, 0.9), "Color", "Glass")
		local pill = utility.new("Frame", {Name = "Pill", Size = environment.UDim2.fromOffset(60, 30), Position = environment.UDim2.fromOffset(3, 3),
			BorderSizePixel = 0, ZIndex = 2, Parent = shell})
		theme.bind(pill, "BackgroundColor3", "Elevated")
		utility.corner(pill, 9)
		theme.bind(utility.stroke(pill, environment.Color3.new(1, 1, 1), 1, 0.88), "Color", "Glass")
		tab.SubPill = pill
		local row = utility.new("Frame", {Name = "Row", Size = environment.UDim2.new(0, 0, 1, 0), AutomaticSize = environment.Enum.AutomaticSize.X,
			BackgroundTransparency = 1, ZIndex = 3, Parent = shell})
		utility.list(row, 2, environment.Enum.FillDirection.Horizontal, environment.Enum.HorizontalAlignment.Left, environment.Enum.VerticalAlignment.Center)
		utility.pad(row, 3, 3, 3, 3)
		tab.SubButtons = {}
		for index, definition in ipairs(definitions) do
			local button = utility.new("TextButton", {Name = definition.key, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
				Size = environment.UDim2.fromOffset(0, 30), AutomaticSize = environment.Enum.AutomaticSize.X, LayoutOrder = index, ZIndex = 4, Parent = row})
			local padding = utility.pad(button, 0, 15, 0, 15)
			local label = nova.label({Parent = button, Text = definition.label or definition.key, Font = nova.Font.Semi(), Size = 13,
				Box = environment.UDim2.new(0, 0, 1, 0), Auto = environment.Enum.AutomaticSize.X, Color = "Muted", Z = 4})
			local registry = utility.textReg[label]
			tab.SubButtons[definition.key] = {Button = button, Label = label, Def = definition, Pad = padding, Base = registry and registry.size or 13}
			button.MouseEnter:Connect(function()
				if tab.ActiveSub ~= definition.key then nova.paint(label, "TextColor3", "Text", "Quick") end
				nova.Sound.play("hover", 0.4)
			end)
			utility.leave(button, function()
				if tab.ActiveSub ~= definition.key then nova.paint(label, "TextColor3", "Muted", "Quick") end
			end)
			button.MouseButton1Click:Connect(function()
				if tab.ActiveSub ~= definition.key then nova.Sound.play("tick") end
				tab:SelectSub(definition.key)
			end)
		end
		for _, page in pairs(tab.Pages) do
			page.Root.Position = environment.UDim2.fromOffset(0, 48)
			page.Root.Size = environment.UDim2.new(1, 0, 1, -48)
		end
		tab.ActiveSub = definitions[1].key
		local function place() tab:_placePill(true) end
		shell:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			tab:_queueFitSubs()
			if tab.Window.Scaling then
				tab.Window:_scalingDefer(place)
				return
			end
			place()
		end)
		bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() tab:_queueFitSubs() end)
		environment.task.defer(place)
		tab:_queueFitSubs()
	end

	function class._queueFitSubs(tab)
		if tab.FitQueued then return end
		tab.FitQueued = true
		environment.task.delay(0.06, function()
			tab.FitQueued = false
			local window = tab.Window
			if not window or window.Destroyed then return end
			if window.Scaling then
				window:_scalingDefer(function() tab:_queueFitSubs() end)
				return
			end
			environment.pcall(tab._fitSubs, tab)
		end)
	end

	function class._fitSubs(tab)
		local bar, shell = tab.SubBar, tab.SubPill and tab.SubPill.Parent
		if not bar or not shell or not tab.SubButtons then return end
		local scale = shell.AbsoluteSize.Y / 36
		if scale <= 0.01 then return end
		local available = bar.AbsoluteSize.X / scale
		if available < 60 then return end
		if not tab.SubFitAvail or math.abs(tab.SubFitAvail - available) > 2 then tab.SubFitAdj = 1 end
		tab.SubFitAvail = available
		local adjustment, count, width = tab.SubFitAdj or 1, 0, 0
		for _, button in pairs(tab.SubButtons) do
			local size = button.Label.TextSize
			if size <= 0 then return end
			count += 1
			width += button.Label.AbsoluteSize.X / scale * (button.Base * nova.U.textScale) / size
		end
		if count == 0 or width <= 0 then return end
		width /= adjustment
		local gaps, margin, padding, factor = (count - 1) * 2 + 6, 22, 15, 1
		if width + count * 30 + gaps + 44 > available then
			margin = 10
			padding = math.floor((available - 20 - gaps - width) / (2 * count))
			if padding >= 6 then
				padding = math.min(padding, 15)
			else
				padding, factor = 6, (available - 20 - gaps - count * 12) / width
				if factor < 0.75 then margin, padding, factor = 4, 3, (available - 8 - gaps - count * 6) / width end
				factor = math.clamp(factor, 0.6, 1)
			end
		end
		local changed = false
		if shell.Position.X.Offset ~= margin then
			shell.Position = environment.UDim2.fromOffset(margin, 6)
			changed = true
		end
		for _, button in pairs(tab.SubButtons) do
			if button.Pad and button.Pad.PaddingLeft.Offset ~= padding then
				button.Pad.PaddingLeft, button.Pad.PaddingRight = environment.UDim.new(0, padding), environment.UDim.new(0, padding)
				changed = true
			end
			local size = math.max(8, math.floor(button.Base * factor + 0.5))
			local entry = nova.U.textReg[button.Label]
			if entry and entry.size ~= size then
				entry.size = size
				nova.Font.sizeOne(button.Label)
				changed = true
			end
		end
		tab.SubFit = {margin = margin, pad = padding, f = factor}
		if changed then environment.task.defer(function() tab:_placePill(true) end) end
		environment.task.delay(0.08, function()
			if not shell.Parent or not bar.Parent then return end
			local currentScale = shell.AbsoluteSize.Y / 36
			if currentScale <= 0.01 then return end
			if (shell.AbsolutePosition.X + shell.AbsoluteSize.X - bar.AbsolutePosition.X) / currentScale > bar.AbsoluteSize.X / currentScale - 2
				and (tab.SubFitAdj or 1) > 0.8 then
				tab.SubFitAdj = (tab.SubFitAdj or 1) - 0.04
				environment.pcall(tab._fitSubs, tab)
			end
		end)
	end

	function class._placePill(tab, immediate)
		local button = tab.SubButtons and tab.SubButtons[tab.ActiveSub]
		if not button or not tab.SubPill or not tab.SubPill.Parent then return end
		local shell = tab.SubPill.Parent
		local scale = shell.AbsoluteSize.Y / 36
		if scale <= 0.01 then return end
		local x = (button.Button.AbsolutePosition.X - shell.AbsolutePosition.X) / scale
		local width = button.Button.AbsoluteSize.X / scale
		if width <= 1 then return end
		local position, size = environment.UDim2.fromOffset(x, 3), environment.UDim2.fromOffset(width, 30)
		if immediate then
			tab.SubPill.Position, tab.SubPill.Size = position, size
		else
			local info = environment.TweenInfo.new(0.34, environment.Enum.EasingStyle.Quint, environment.Enum.EasingDirection.Out)
			nova.Motion.tween(tab.SubPill, info, {Position = position, Size = size})
		end
		for key, item in pairs(tab.SubButtons) do
			nova.paint(item.Label, "TextColor3", key == tab.ActiveSub and "Text" or "Muted", immediate and environment.TweenInfo.new(0) or "Quick")
		end
	end

	function class.SelectSub(tab, key)
		if not tab.SubButtons or not tab.SubButtons[key] or key == tab.ActiveSub then return end
		local previous = tab.ActiveSub
		tab.ActiveSub = key
		tab.Window:ClosePopups()
		tab:_placePill(false)
		local old, page = tab.Pages[previous], tab:_page(key)
		if old then old.Root.Visible = false end
		page.Root.Visible = true
		page.Root.Position = environment.UDim2.fromOffset(18, 48)
		nova.Motion.tween(page.Root, "Base", {Position = environment.UDim2.fromOffset(0, 48)})
		environment.task.delay(0.2, function()
			if tab.ActiveSub == key then tab:_balanceActive() end
		end)
		if tab.OnSubChanged then environment.pcall(tab.OnSubChanged, key) end
	end

	function class._balance(tab, page, attempt)
		local window = tab.Window
		if not page or window.Destroyed or not page.Root.Visible then return end
		if not window.Scaling then
			for _, section in ipairs(tab.Sections) do
				if section.Page == page and section._sync and not section.Floating then environment.pcall(section._sync) end
			end
		end
		if page.One or tab.Columns == 1 then return end
		if window.Scaling then
			if (attempt or 0) < 12 then
				environment.task.delay(0.25, function() tab:_balance(page, (attempt or 0) + 1) end)
			end
			return
		end

		local scale, sections, movable = math.max(window.Scale.Scale, 0.1), {}, 0
		for index, section in ipairs(tab.Sections) do
			if section.Page == page and not section.ParentSection and section.Wrap and section.Wrap.Parent then
				table.insert(sections, {section = section, order = index})
				if not section.Pinned and not section.Floating then movable += 1 end
			end
		end
		if movable == 0 then return end
		local heights = {}
		for _, item in ipairs(sections) do
			local section, height = item.section, 0
			if section.Floating then
				height = section.Slot and section.Slot.Visible and section.Slot.AbsoluteSize.Y / scale or 0
			end
			if not section.Floating and not section.Hidden and section.Wrap.Visible then
				height = section.Wrap.AbsoluteSize.Y / scale
				if height < 2 then
					if (attempt or 0) < 12 then environment.task.delay(0.25, function() tab:_balance(page, (attempt or 0) + 1) end) end
					return
				end
			end
			heights[section] = height
		end
		local loads = {0, 0}
		for _, item in ipairs(sections) do
			local section = item.section
			local side = section.Side or 1
			if not section.Pinned and not section.Floating then
				side = loads[1] <= loads[2] + 1 and 1 or 2
				local parent = side == 1 and page.Left or page.Right
				if section.Wrap.Parent ~= parent then section.Wrap.Parent = parent end
				section.Side = side
			end
			local object = section.Floating and section.Slot or section.Wrap
			if object then object.LayoutOrder = item.order end
			if heights[section] > 0 then loads[side] += heights[section] + 16 end
		end
		page.BalancedCount = #sections
	end

	function class._balanceActive(tab, force)
		local page = tab.Pages[tab.ActiveSub or "_"] or tab.Pages._
		if not page then return end
		local count = 0
		for _, section in ipairs(tab.Sections) do
			if section.Page == page and not section.ParentSection then count += 1 end
		end
		if not force and page.BalancedCount == count then return end
		tab:_balance(page)
	end

	function class._queueBalance(tab, page)
		if page.BalanceQueued then return end
		page.BalanceQueued = true
		environment.task.delay(0.4, function()
			page.BalanceQueued = false
			if tab.Window.Current == tab and page.Root.Visible then tab:_balanceActive() end
		end)
	end

	return class
end

local Translation = {}

function Translation.create()
	local translator = {
		lang = "en", reg = {}, searchRegs = {}, onChange = {},
		data = {en = {}, ru = {
			["%d online"] = "%d РІ РёРіСЂРµ",
			["%dd"] = "%dРґ",
			["%dh"] = "%dС‡",
			["%dm"] = "%dРј",
			["8D Audio"] = "8D Р·РІСѓРє",
			["A SoundCloud track link, or a DIRECT link to an mp3/ogg file. A download page will not work."] = "РЎСЃС‹Р»РєР° РЅР° С‚СЂРµРє SoundCloud РёР»Рё РџР РЇРњРђРЇ СЃСЃС‹Р»РєР° РЅР° mp3/ogg. РЎС‚СЂР°РЅРёС†Р° СЃРєР°С‡РёРІР°РЅРёСЏ РЅРµ РїРѕРґРѕР№РґС‘С‚.",
			["A feature doesn't work"] = "Р¤СѓРЅРєС†РёСЏ РЅРµ СЂР°Р±РѕС‚Р°РµС‚",
			["AA Mode"] = "Р РµР¶РёРј",
			["About"] = "Рћ С…Р°Р±Рµ",
			["Abyss"] = "Р‘РµР·РґРЅР°",
			["Accent preset"] = "РђРєС†РµРЅС‚",
			["Accent"] = "РђРєС†РµРЅС‚",
			["Accessories"] = "РђРєСЃРµСЃСЃСѓР°СЂС‹",
			["Accurate"] = "РўРѕС‡РЅРѕ",
			["Add Current Link To List"] = "Р”РѕР±Р°РІРёС‚СЊ СЃСЃС‹Р»РєСѓ РІ СЃРїРёСЃРѕРє",
			["Add Song"] = "Р”РѕР±Р°РІРёС‚СЊ С‚СЂРµРє",
			["Add all"] = "Р”РѕР±Р°РІРёС‚СЊ РІСЃРµ",
			["Add to saved"] = "Р’ РёР·Р±СЂР°РЅРЅРѕРµ",
			["Add"] = "Р”РѕР±Р°РІРёС‚СЊ",
			["Added to My configs"] = "Р”РѕР±Р°РІР»РµРЅ РІ РњРѕРё РєРѕРЅС„РёРіРё",
			["Added to favorites"] = "Р”РѕР±Р°РІР»РµРЅРѕ РІ РёР·Р±СЂР°РЅРЅРѕРµ",
			["Added"] = "Р”РѕР±Р°РІР»РµРЅРѕ",
			["Admin secret (paste once)"] = "РЎРµРєСЂРµС‚ Р°РґРјРёРЅР° (РІСЃС‚Р°РІРёС‚СЊ РѕРґРёРЅ СЂР°Р·)",
			["After Hours"] = "РџРѕСЃР»Рµ РїРѕР»СѓРЅРѕС‡Рё",
			["Aim & combat"] = "РђРёРј Рё Р±РѕР№",
			["Aim Debug"] = "Р”РµР±Р°Рі Р°РёРјР°",
			["Aim Version"] = "Р’РµСЂСЃРёСЏ Р°РёРјР°",
			["AimBot FOV"] = "РљСЂСѓРі Р°РёРјР° (FOV)",
			["AimBot Type"] = "РўРёРї Р°РёРјР±РѕС‚Р°",
			["AimBot"] = "РђРёРјР±РѕС‚",
			["Air Dance"] = "Р‘РµР·СѓРјРёРµ",
			["Air"] = "Р’РѕР·РґСѓС…",
			["All your settings will be reset to the script's default config. Saved configs stay."] = "Р’СЃРµ С‚РІРѕРё РЅР°СЃС‚СЂРѕР№РєРё СЃР±СЂРѕСЃСЏС‚СЃСЏ РЅР° РєРѕРЅС„РёРі СЃРєСЂРёРїС‚Р° РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ. РЎРѕС…СЂР°РЅС‘РЅРЅС‹Рµ РєРѕРЅС„РёРіРё РѕСЃС‚Р°РЅСѓС‚СЃСЏ.",
			["All"] = "Р’СЃРµ",
			["Already in the list"] = "РЈР¶Рµ РІ СЃРїРёСЃРєРµ",
			["Already sent"] = "РЈР¶Рµ РѕС‚РїСЂР°РІР»РµРЅРѕ",
			["Amber Glow"] = "РЇРЅС‚Р°СЂРЅС‹Р№",
			["Ambient level"] = "РЈСЂРѕРІРµРЅСЊ С„РѕРЅР°",
			["Ambient light"] = "РћРєСЂСѓР¶Р°СЋС‰РёР№ СЃРІРµС‚",
			["Ambient tint"] = "РћС‚С‚РµРЅРѕРє С„РѕРЅР°",
			["Angel Aura"] = "РђСѓСЂР°: РђРЅРіРµР»",
			["Angel Wings Aura"] = "РђРЅРіРµР»СЊСЃРєРёРµ РєСЂС‹Р»СЊСЏ (Р°СѓСЂР°)",
			["Animated Window"] = "РђРЅРёРјР°С†РёСЏ РѕРєРЅР°",
			["Animation Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ Р°РЅРёРјР°С†РёРё",
			["Animation combo"] = "РљРѕРјР±Рѕ Р°РЅРёРјР°С†РёР№",
			["Animation options"] = "РќР°СЃС‚СЂРѕР№РєРё Р°РЅРёРјР°С†РёРё",
			["Animation packs"] = "РџР°РєРё Р°РЅРёРјР°С†РёР№",
			["Animation"] = "РђРЅРёРјР°С†РёСЏ",
			["Animations"] = "РђРЅРёРјР°С†РёРё",
			["Anime"] = "РђРЅРёРјРµ",
			["Anti AFK"] = "РђРЅС‚Рё-AFK",
			["Anti Aim"] = "РђРЅС‚Рё-Р°РёРј",
			["Anti Coin"] = "РђРЅС‚Рё-РјРѕРЅРµС‚С‹",
			["Anti Steal on night"] = "РђРЅС‚Рё-РєСЂР°Р¶Р° РЅРѕС‡СЊСЋ",
			["Anti-Aim"] = "РђРЅС‚Рё-Р°РёРј",
			["Anti-Fling"] = "РђРЅС‚Рё-С„Р»РёРЅРі",
			["Anti-Glare (Darken)"] = "РђРЅС‚Рё-Р±Р»РёРє (Р·Р°С‚РµРјРЅРµРЅРёРµ)",
			["Anti-Glare"] = "РђРЅС‚РёР±Р»РёРє",
			["Any"] = "Р›СЋР±Р°СЏ",
			["Appearance reset"] = "Р’РЅРµС€РЅРёР№ РІРёРґ СЃР±СЂРѕС€РµРЅ",
			["Appearance"] = "Р’РЅРµС€РЅРёР№ РІРёРґ",
			["Apply look"] = "РџСЂРёРјРµРЅРёС‚СЊ РѕР±СЂР°Р·",
			["Apply"] = "РџСЂРёРјРµРЅРёС‚СЊ",
			["Applying"] = "РџСЂРёРјРµРЅСЏСЋ",
			["Arctic"] = "РђСЂРєС‚РёРєР°",
			["Arms"] = "Р СѓРєРё",
			["Ash Gray"] = "РџРµРїРµР»СЊРЅС‹Р№",
			["Atmosphere"] = "РђС‚РјРѕСЃС„РµСЂР°",
			["Audio Effects"] = "Р­С„С„РµРєС‚С‹ Р·РІСѓРєР°",
			["Aura Radius"] = "Р Р°РґРёСѓСЃ Р°СѓСЂС‹",
			["Auras"] = "РђСѓСЂС‹",
			["Auto Bomb Jump Button"] = "РљРЅРѕРїРєР° Р±РѕРјР±Р°-РїСЂС‹Р¶РєР°",
			["Auto Bomb Jump"] = "Р‘РѕРјР±Р°-РїСЂС‹Р¶РѕРє",
			["Auto Buy"] = "РђРІС‚РѕРїРѕРєСѓРїРєР°",
			["Auto Collect Event Seeds"] = "РђРІС‚РѕСЃР±РѕСЂ РёРІРµРЅС‚-СЃРµРјСЏРЅ",
			["Auto Delay"] = "РђРІС‚Рѕ-Р·Р°РґРµСЂР¶РєР°",
			["Auto Emote"] = "РђРІС‚Рѕ СЌРјРѕС†РёСЏ",
			["Auto Equip Toy"] = "РђРІС‚Рѕ-РёРіСЂСѓС€РєРё РІ СЃР»РѕС‚С‹",
			["Auto Farm with Coin and Role modes: wins, murderer kills and EXP. On phones: on-screen buttons in three styles, Double Tap Lock, Fly, Bhop, NoClip, Speed and more, plus safe two-finger dragging. New fly and walk speed methods, Wall Hop, better invisibility, an optimizer, an FPS and ping widget, and Russian and Ukrainian."] = "РђРІС‚РѕС„Р°СЂРј СЃ СЂРµР¶РёРјР°РјРё Coin Рё Role: РїРѕР±РµРґС‹, РєРёР»С‹ РјР°СЂРґРµСЂРѕРј Рё EXP. РќР° С‚РµР»РµС„РѕРЅРµ: СЌРєСЂР°РЅРЅС‹Рµ РєРЅРѕРїРєРё РІ С‚СЂС‘С… СЃС‚РёР»СЏС…, Double Tap Lock, Fly, Bhop, NoClip, Speed Рё РґСЂСѓРіРёРµ, РїР»СЋСЃ РїРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµ РґРІСѓРјСЏ РїР°Р»СЊС†Р°РјРё Р±РµР· РіР»СЋРєРѕРІ. РќРѕРІС‹Рµ РјРµС‚РѕРґС‹ РїРѕР»С‘С‚Р° Рё СЃРєРѕСЂРѕСЃС‚Рё, Wall Hop, СѓР»СѓС‡С€РµРЅРЅР°СЏ РЅРµРІРёРґРёРјРѕСЃС‚СЊ, РѕРїС‚РёРјРёР·Р°С‚РѕСЂ, РІРёРґР¶РµС‚ FPS Рё РїРёРЅРіР°, СЂСѓСЃСЃРєРёР№ Рё СѓРєСЂР°РёРЅСЃРєРёР№ СЏР·С‹Рє.",
			["Auto Farm"] = "РђРІС‚РѕС„Р°СЂРј",
			["Auto Fling Sheriff"] = "РђРІС‚Рѕ-С„Р»РёРЅРі С€РµСЂРёС„Р°",
			["Auto Fling"] = "РђРІС‚Рѕ-С„Р»РёРЅРі",
			["Auto Harvest"] = "РђРІС‚РѕСЃР±РѕСЂ",
			["Auto Kill Murder"] = "РђРІС‚Рѕ СѓР±РёР№СЃС‚РІРѕ РјР°СЂРґРµСЂР°",
			["Auto Kill"] = "РђРІС‚Рѕ СѓР±РёР№СЃС‚РІРѕ",
			["Auto Open"] = "РђРІС‚Рѕ-РѕС‚РєСЂС‹С‚РёРµ",
			["Auto Pickup Gun"] = "РђРІС‚Рѕ РїРѕРґР±РѕСЂ РїРёСЃС‚РѕР»РµС‚Р°",
			["Auto Plant"] = "РђРІС‚РѕРїРѕСЃР°РґРєР°",
			["Auto Play on Round Start"] = "РђРІС‚Рѕ-РјСѓР·С‹РєР° РІ РЅР°С‡Р°Р»Рµ СЂР°СѓРЅРґР°",
			["Auto Rejoin on Kick"] = "РђРІС‚Рѕ-РїРµСЂРµР·Р°С…РѕРґ РїСЂРё РєРёРєРµ",
			["Auto Sell"] = "РђРІС‚РѕРїСЂРѕРґР°Р¶Р°",
			["Auto Shoot Murder"] = "РђРІС‚Рѕ РІС‹СЃС‚СЂРµР» РІ РјР°СЂРґРµСЂР°",
			["Auto Shoot"] = "РђРІС‚Рѕ СЃС‚СЂРµР»СЊР±Р°",
			["Auto Steal on Night"] = "РђРІС‚РѕРєСЂР°Р¶Р° РЅРѕС‡СЊСЋ",
			["Auto Steal"] = "РђРІС‚РѕРєСЂР°Р¶Р°",
			["Auto farm, session stats and trading"] = "РђРІС‚РѕС„Р°СЂРј, СЃС‚Р°С‚РёСЃС‚РёРєР° Рё С‚СЂРµР№Рґ",
			["Auto"] = "РђРІС‚Рѕ",
			["Auto-Fling Murder after respawn"] = "РђРІС‚Рѕ-С„Р»РёРЅРі РјР°СЂРґРµСЂР° РїРѕСЃР»Рµ СЂРµСЃРїР°РІРЅР°",
			["Auto-Fling"] = "РђРІС‚Рѕ-С„Р»РёРЅРі",
			["Auto-Respawn on full bag"] = "РђРІС‚Рѕ-СЂРµСЃРїР°РІРЅ РїСЂРё РїРѕР»РЅРѕРј РјРµС€РєРµ",
			["Auto-Respawn"] = "РђРІС‚Рѕ-СЂРµСЃРїР°РІРЅ",
			["Auto-load on respawn"] = "РђРІС‚Рѕ-Р·Р°РіСЂСѓР·РєР° РїСЂРё СЂРµСЃРїР°РІРЅРµ",
			["Avoid Murderer"] = "РР·Р±РµРіР°С‚СЊ СѓР±РёР№С†Сѓ",
			["BETA"] = "Р‘Р•РўРђ",
			["BG Image Transparency"] = "РџСЂРѕР·СЂР°С‡РЅРѕСЃС‚СЊ С„РѕРЅР°",
			["Back"] = "РќР°Р·Р°Рґ",
			["Background Saver"] = "Р­РєРѕРЅРѕРјРёСЏ РІ С„РѕРЅРµ",
			["Background Strength"] = "РЇСЂРєРѕСЃС‚СЊ С„РѕРЅР°",
			["Background intensity"] = "РЇСЂРєРѕСЃС‚СЊ С„РѕРЅР°",
			["Background"] = "Р¤РѕРЅ",
			["Backtrack Color"] = "Р‘СЌРєС‚СЂРµРє: С†РІРµС‚",
			["Backtrack Style"] = "Р‘СЌРєС‚СЂРµРє: СЃС‚РёР»СЊ",
			["Backtrack"] = "Р‘СЌРєС‚СЂРµРє",
			["Backwards"] = "РЎРїРёРЅРѕР№",
			["Bad config data"] = "РљРѕРЅС„РёРі РїРѕРІСЂРµР¶РґС‘РЅ",
			["Bad words are not allowed"] = "РњР°С‚ Р·Р°РїСЂРµС‰С‘РЅ",
			["Balance"] = "Р‘Р°Р»Р°РЅСЃ",
			["Ban author"] = "Р—Р°Р±Р°РЅРёС‚СЊ Р°РІС‚РѕСЂР°",
			["Base theme"] = "РћСЃРЅРѕРІР° С‚РµРјС‹",
			["Bass Boost"] = "Р‘Р°СЃ Р±СѓСЃС‚",
			["Bass"] = "Р‘Р°СЃС‹",
			["Beams"] = "Р›СѓС‡Рё",
			["Behavior"] = "РџРѕРІРµРґРµРЅРёРµ",
			["Bhop Button"] = "РљРЅРѕРїРєР° Р±С…РѕРїР°",
			["Bhop Key"] = "Bhop",
			["Bhop Power"] = "РЎРёР»Р° Р±С…РѕРїР°",
			["Bhop Sound"] = "Р—РІСѓРє Р±С…РѕРїР°",
			["Bhop"] = "Р‘С…РѕРї",
			["Bhop: OFF"] = "Р‘С…РѕРї: Р’Р«РљР›",
			["Bind"] = "Р‘РёРЅРґ",
			["Black"] = "Р§С‘СЂРЅС‹Р№",
			["Blood Moon"] = "РљСЂРѕРІР°РІР°СЏ Р»СѓРЅР°",
			["Blood Red"] = "РљСЂРѕРІР°РІС‹Р№",
			["Bloom"] = "РЎРІРµС‡РµРЅРёРµ",
			["Blue"] = "РЎРёРЅРёР№",
			["Blur Strength"] = "РЎРёР»Р° СЂР°Р·РјС‹С‚РёСЏ",
			["Blur background"] = "Р Р°Р·РјС‹С‚РёРµ С„РѕРЅР°",
			["Blur behind menu"] = "Р Р°Р·РјС‹С‚РёРµ Р·Р° РјРµРЅСЋ",
			["Blur strength"] = "РЎРёР»Р° СЂР°Р·РјС‹С‚РёСЏ",
			["Blur"] = "Р Р°Р·РјС‹С‚РёРµ",
			["Blurs the game behind the menu"] = "Р Р°Р·РјС‹РІР°РµС‚ РёРіСЂСѓ Р·Р° РјРµРЅСЋ",
			["Bomb Jump"] = "Р‘РѕРјР±Р°-РїСЂС‹Р¶РѕРє",
			["Boombox"] = "Р‘СѓРјР±РѕРєСЃ",
			["Bottom"] = "РЎРЅРёР·Сѓ",
			["Bounce"] = "РџСЂС‹Р¶РєРё",
			["Box Brightness"] = "РЇСЂРєРѕСЃС‚СЊ Р±РѕРєСЃР°",
			["Box Color"] = "Р¦РІРµС‚ Р±РѕРєСЃР°",
			["Box ESP"] = "РњРµС‚РєРё: СЂР°РјРєР°",
			["Box Own Color"] = "РЎРІРѕР№ С†РІРµС‚ Р±РѕРєСЃР°",
			["Box Saturation"] = "РќР°СЃС‹С‰РµРЅРЅРѕСЃС‚СЊ Р±РѕРєСЃР°",
			["Box"] = "РљРµР№СЃ",
			["Boxes"] = "РљРµР№СЃС‹",
			["Break Dance"] = "Р‘СЂРµР№Рє",
			["Brightness"] = "РЇСЂРєРѕСЃС‚СЊ",
			["Browse and share configs"] = "РљРѕРЅС„РёРіРё РѕС‚ РёРіСЂРѕРєРѕРІ",
			["Bubbles"] = "РџСѓР·С‹СЂРё",
			["Bullet Tracers"] = "РўСЂРµР№СЃРµСЂС‹ РїСѓР»СЊ",
			["Bundles"] = "Р‘Р°РЅРґР»С‹",
			["Buttons Style"] = "РЎС‚РёР»СЊ РєРЅРѕРїРѕРє",
			["Bye"] = "РџРѕРєР°",
			["Camera Flick"] = "Р¤Р»РёРє РєР°РјРµСЂРѕР№",
			["Cancel"] = "РћС‚РјРµРЅР°",
			["Candies"] = "РљРѕРЅС„РµС‚С‹",
			["Card style"] = "РЎС‚РёР»СЊ РєР°СЂС‚РѕС‡РµРє",
			["Cards"] = "РљР°СЂС‚С‹",
			["Catalog error (rate limit?). Try again."] = "РћС€РёР±РєР° РєР°С‚Р°Р»РѕРіР° (Р»РёРјРёС‚ Р·Р°РїСЂРѕСЃРѕРІ?). РџРѕРїСЂРѕР±СѓР№ РµС‰С‘ СЂР°Р·.",
			["Center"] = "РџРѕ С†РµРЅС‚СЂСѓ",
			["Chams (through walls)"] = "Р§Р°РјСЃС‹ (СЃРєРІРѕР·СЊ СЃС‚РµРЅС‹)",
			["Chams B"] = "Р§Р°РјСЃС‹ B",
			["Chams Brightness"] = "РЇСЂРєРѕСЃС‚СЊ С‡Р°РјСЃРѕРІ",
			["Chams Color"] = "Р¦РІРµС‚ С‡Р°РјСЃРѕРІ",
			["Chams G"] = "Р§Р°РјСЃС‹ G",
			["Chams R"] = "Р§Р°РјСЃС‹ R",
			["Chams"] = "Р§Р°РјСЃС‹",
			["Chat"] = "Р§Р°С‚",
			["Check Link"] = "РџСЂРѕРІРµСЂРёС‚СЊ СЃСЃС‹Р»РєСѓ",
			["Check failed (network)."] = "РџСЂРѕРІРµСЂРєР° РЅРµ РїСЂРѕС€Р»Р° (СЃРµС‚СЊ).",
			["Checking the file..."] = "РџСЂРѕРІРµСЂСЏСЋ С„Р°Р№Р»...",
			["Checking the link..."] = "РџСЂРѕРІРµСЂСЏСЋ СЃСЃС‹Р»РєСѓ...",
			["Checking..."] = "РџСЂРѕРІРµСЂСЏСЋ...",
			["Chipmunk"] = "Р‘СѓСЂСѓРЅРґСѓРє",
			["Cinematic Film"] = "РљРёРЅРѕС„РёР»СЊРј",
			["Cinematic"] = "РљРёРЅРѕ",
			["Classic"] = "РљР»Р°СЃСЃРёРєР°",
			["Clear All"] = "РћС‡РёСЃС‚РёС‚СЊ РІСЃС‘",
			["Clear combo"] = "РћС‡РёСЃС‚РёС‚СЊ РєРѕРјР±Рѕ",
			["Clear history"] = "РћС‡РёСЃС‚РёС‚СЊ РёСЃС‚РѕСЂРёСЋ",
			["Clear"] = "РћС‡РёСЃС‚РёС‚СЊ",
			["Click Fling"] = "РљР»РёРє-С„Р»РёРЅРі",
			["Click Hump"] = "РљР»РёРє-С…Р°РјРї",
			["Click again to confirm"] = "РќР°Р¶РјРё РµС‰С‘ СЂР°Р· РґР»СЏ РїРѕРґС‚РІРµСЂР¶РґРµРЅРёСЏ",
			["Climb"] = "Р›Р°Р·Р°РЅРёРµ",
			["Clipboard unavailable"] = "Р‘СѓС„РµСЂ РѕР±РјРµРЅР° РЅРµРґРѕСЃС‚СѓРїРµРЅ",
			["Close"] = "Р—Р°РєСЂС‹С‚СЊ",
			["Clothes"] = "РћРґРµР¶РґР°",
			["Cloud cover"] = "РџРѕРєСЂС‹С‚РёРµ РѕР±Р»Р°РєРѕРІ",
			["Cloud density"] = "РџР»РѕС‚РЅРѕСЃС‚СЊ РѕР±Р»Р°РєРѕРІ",
			["Clouds"] = "РћР±Р»Р°РєР°",
			["Coin leaked, strict mode on"] = "РњРѕРЅРµС‚Р° Р·Р°СЃС‡РёС‚Р°Р»Р°СЃСЊ, РІРєР»СЋС‡РµРЅР° Р¶С‘СЃС‚РєР°СЏ Р·Р°С‰РёС‚Р°",
			["Coin"] = "РњРѕРЅРµС‚С‹",
			["Coins / day"] = "РњРѕРЅРµС‚ / РґРµРЅСЊ",
			["Coins"] = "РњРѕРЅРµС‚С‹",
			["Collapse sidebar"] = "РЎРІРµСЂРЅСѓС‚СЊ РїР°РЅРµР»СЊ",
			["Collect hold time (sec)"] = "Р’СЂРµРјСЏ СѓРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂР° (СЃРµРє)",
			["Color Target"] = "Р¦РµР»СЊ РѕРєСЂР°СЃРєРё",
			["Color grading"] = "Р¦РІРµС‚РѕРєРѕСЂСЂРµРєС†РёСЏ",
			["Color"] = "Р¦РІРµС‚",
			["Colorpicker"] = "РљРѕР»РѕСЂРїРёРєРµСЂ",
			["Combat"] = "Р‘РѕР№",
			["Community"] = "РЎРѕРѕР±С‰РµСЃС‚РІРѕ",
			["Compact sidebar"] = "РЈР·РєР°СЏ РїР°РЅРµР»СЊ",
			["Competitive"] = "РЎРѕСЂРµРІРЅРѕРІР°С‚РµР»СЊРЅС‹Р№",
			["Concert"] = "РљРѕРЅС†РµСЂС‚",
			["Config Hub"] = "РҐР°Р± РєРѕРЅС„РёРіРѕРІ",
			["Config applied"] = "РљРѕРЅС„РёРі РїСЂРёРјРµРЅС‘РЅ",
			["Config created"] = "РљРѕРЅС„РёРі СЃРѕР·РґР°РЅ",
			["Config deleted"] = "РљРѕРЅС„РёРі СѓРґР°Р»С‘РЅ",
			["Config imported"] = "РљРѕРЅС„РёРі РёРјРїРѕСЂС‚РёСЂРѕРІР°РЅ",
			["Config is gone"] = "РљРѕРЅС„РёРі СѓРґР°Р»С‘РЅ",
			["Config is too big"] = "РљРѕРЅС„РёРі СЃР»РёС€РєРѕРј Р±РѕР»СЊС€РѕР№",
			["Config key"] = "РљР»СЋС‡ РєРѕРЅС„РёРіР°",
			["Config not found"] = "РљРѕРЅС„РёРі РЅРµ РЅР°Р№РґРµРЅ",
			["Config saved"] = "РљРѕРЅС„РёРі СЃРѕС…СЂР°РЅС‘РЅ",
			["Config"] = "РљРѕРЅС„РёРі",
			["Configs"] = "РљРѕРЅС„РёРіРё",
			["Connecting"] = "РџРѕРґРєР»СЋС‡РµРЅРёРµ",
			["Contrast"] = "РљРѕРЅС‚СЂР°СЃС‚",
			["Copied ID "] = "ID СЃРєРѕРїРёСЂРѕРІР°РЅ ",
			["Copied!"] = "РЎРєРѕРїРёСЂРѕРІР°РЅРѕ!",
			["Copy Discord Link"] = "РЎРєРѕРїРёСЂРѕРІР°С‚СЊ СЃСЃС‹Р»РєСѓ Discord",
			["Copy HWID"] = "РЎРєРѕРїРёСЂРѕРІР°С‚СЊ HWID",
			["Copy Job ID"] = "РљРѕРїРёСЂРѕРІР°С‚СЊ Job ID",
			["Copy key"] = "РЎРєРѕРїРёСЂРѕРІР°С‚СЊ РєР»СЋС‡",
			["Corner radius"] = "РЎРєСЂСѓРіР»РµРЅРёРµ СѓРіР»РѕРІ",
			["Corners"] = "РЈРіР»С‹",
			["Could not load the track"] = "РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ С‚СЂРµРє",
			["Could not resolve that track (private, geo-blocked or removed?)."] = "РўСЂРµРє РЅРµ РѕС‚РєСЂС‹Р»СЃСЏ (РїСЂРёРІР°С‚РЅС‹Р№, Р·Р°Р±Р»РѕРєРёСЂРѕРІР°РЅ РїРѕ СЂРµРіРёРѕРЅСѓ РёР»Рё СѓРґР°Р»С‘РЅ?).",
			["Could not verify account, try later"] = "РќРµ СѓРґР°Р»РѕСЃСЊ РїСЂРѕРІРµСЂРёС‚СЊ Р°РєРєР°СѓРЅС‚, РїРѕРїСЂРѕР±СѓР№ РїРѕР·Р¶Рµ",
			["Couldn't join this server"] = "РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°Р№С‚Рё РЅР° СЃРµСЂРІРµСЂ",
			["Couldn't load the image"] = "РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ С„РѕС‚Рѕ",
			["Create Config"] = "РЎРѕР·РґР°С‚СЊ РєРѕРЅС„РёРі",
			["Create a config in Settings first"] = "РЎРЅР°С‡Р°Р»Р° СЃРѕР·РґР°Р№ РєРѕРЅС„РёРі РІ РќР°СЃС‚СЂРѕР№РєР°С…",
			["Create a config or import one by key below."] = "РЎРѕР·РґР°Р№ РєРѕРЅС„РёРі РёР»Рё РёРјРїРѕСЂС‚РёСЂСѓР№ РїРѕ РєР»СЋС‡Сѓ РЅРёР¶Рµ.",
			["Create config"] = "РЎРѕР·РґР°С‚СЊ РєРѕРЅС„РёРі",
			["Crosshair"] = "РџСЂРёС†РµР»",
			["Cubes"] = "РљСѓР±С‹",
			["Cursor Brightness"] = "РЇСЂРєРѕСЃС‚СЊ РєСѓСЂСЃРѕСЂР°",
			["Cursor Color"] = "Р¦РІРµС‚ РєСѓСЂСЃРѕСЂР°",
			["Cursor"] = "РљСѓСЂСЃРѕСЂ",
			["Custom Color"] = "РЎРІРѕР№ С†РІРµС‚",
			["Custom Cursor"] = "РљР°СЃС‚РѕРј РєСѓСЂСЃРѕСЂ",
			["Custom Skies"] = "РљР°СЃС‚РѕРј РЅРµР±Рѕ",
			["Custom Sounds"] = "РљР°СЃС‚РѕРј Р·РІСѓРєРё",
			["Custom accent"] = "РЎРІРѕР№ Р°РєС†РµРЅС‚",
			["Custom"] = "РЎРІРѕР№",
			["Cyan"] = "Р“РѕР»СѓР±РѕР№",
			["Cyanic"] = "Р¦РёР°РЅ",
			["Cyberpunk"] = "РљРёР±РµСЂРїР°РЅРє",
			["Daily limit reached"] = "Р›РёРјРёС‚ С‚СЂРµРєРѕРІ РЅР° СЃРµРіРѕРґРЅСЏ",
			["Dark Fog"] = "РўС‘РјРЅС‹Р№ С‚СѓРјР°РЅ",
			["Dark"] = "РўСЊРјР°",
			["Darken"] = "Р—Р°С‚РµРјРЅРµРЅРёРµ",
			["Dashed"] = "РџСѓРЅРєС‚РёСЂ",
			["Day"] = "Р”РµРЅСЊ",
			["Dead"] = "РњС‘СЂС‚РІ",
			["Deep Ocean"] = "Р“Р»СѓР±РѕРєРёР№ РѕРєРµР°РЅ",
			["Deep Sea"] = "Р“Р»СѓР±РёРЅР°",
			["Deep Violet"] = "РўС‘РјРЅРѕ-С„РёРѕР»РµС‚РѕРІС‹Р№",
			["Default"] = "РџРѕ СѓРјРѕР»С‡Р°РЅРёСЋ",
			["Delay Tag"] = "РњРµС‚РєР° Р·Р°РґРµСЂР¶РєРё",
			["Delay after round start (sec)"] = "Р—Р°РґРµСЂР¶РєР° РїРѕСЃР»Рµ СЃС‚Р°СЂС‚Р° (СЃРµРє)",
			["Delete"] = "РЈРґР°Р»РёС‚СЊ",
			["Demon"] = "Р”РµРјРѕРЅ",
			["Density"] = "РџР»РѕС‚РЅРѕСЃС‚СЊ",
			["Depth Blur"] = "Р Р°Р·РјС‹С‚РёРµ РїРѕ РіР»СѓР±РёРЅРµ",
			["Depth Of Field"] = "Р“Р»СѓР±РёРЅР° СЂРµР·РєРѕСЃС‚Рё",
			["Depth of field"] = "Р“Р»СѓР±РёРЅР° СЂРµР·РєРѕСЃС‚Рё",
			["Description"] = "РћРїРёСЃР°РЅРёРµ",
			["Description: up to 240 characters and 4 lines"] = "РћРїРёСЃР°РЅРёРµ: РґРѕ 240 СЃРёРјРІРѕР»РѕРІ Рё 4 СЃС‚СЂРѕРє",
			["Desert Brightness"] = "РџСѓСЃС‚С‹РЅСЏ: СЏСЂРєРѕСЃС‚СЊ",
			["Desert Dust"] = "РџСѓСЃС‚С‹РЅСЏ: РїС‹Р»СЊ",
			["Desert Haze"] = "РџСѓСЃС‚С‹РЅСЏ: РїР»РѕС‚РЅРѕСЃС‚СЊ РґС‹РјРєРё",
			["Desert Hour"] = "РџСѓСЃС‚С‹РЅСЏ: РІСЂРµРјСЏ СЃСѓС‚РѕРє",
			["Desert Sun"] = "РџСѓСЃС‚С‹РЅСЏ: СЃРѕР»РЅС†Рµ",
			["Desert Time"] = "РџСѓСЃС‚С‹РЅСЏ: РІСЂРµРјСЏ СЃСѓС‚РѕРє",
			["Desert"] = "РџСѓСЃС‚С‹РЅСЏ",
			["Desync"] = "Р”РµСЃРёРЅРє",
			["Diamond"] = "Diamond",
			["Diffuse light"] = "Р Р°СЃСЃРµСЏРЅРЅС‹Р№ СЃРІРµС‚",
			["Direction"] = "РќР°РїСЂР°РІР»РµРЅРёРµ",
			["Disable Background Images"] = "РЈР±СЂР°С‚СЊ С„РѕРЅРѕРІС‹Рµ РєР°СЂС‚РёРЅРєРё",
			["Distortion"] = "РџРµСЂРµРіСЂСѓР·",
			["Dock all"] = "Р’РµСЂРЅСѓС‚СЊ РІСЃРµ",
			["Done! If Discord didn't open, the link is already in your clipboard. See you there."] = "Р“РѕС‚РѕРІРѕ! Р•СЃР»Рё Discord РЅРµ РѕС‚РєСЂС‹Р»СЃСЏ, СЃСЃС‹Р»РєР° СѓР¶Рµ РІ Р±СѓС„РµСЂРµ РѕР±РјРµРЅР°. РЈРІРёРґРёРјСЃСЏ С‚Р°Рј.",
			["Dot"] = "РўРѕС‡РєР°",
			["Download it first"] = "РЎРЅР°С‡Р°Р»Р° СЃРєР°С‡Р°Р№ РєРѕРЅС„РёРі",
			["Download to rate"] = "РЎРєР°С‡Р°Р№, С‡С‚РѕР±С‹ РѕС†РµРЅРёС‚СЊ",
			["Download"] = "РЎРєР°С‡Р°С‚СЊ",
			["Downloaded"] = "РЎРєР°С‡Р°РЅ",
			["Downloading for everyone..."] = "РЎРєР°С‡РёРІР°РµС‚СЃСЏ Сѓ РІСЃРµС…...",
			["Downloading in the background. Nothing is shown to them."] = "РљР°С‡Р°РµС‚СЃСЏ РІ С„РѕРЅРµ. РРіСЂРѕРєР°Рј РЅРёС‡РµРіРѕ РЅРµ РїРѕРєР°Р·С‹РІР°РµС‚СЃСЏ.",
			["Dracula Wings Aura"] = "РљСЂС‹Р»СЊСЏ Р”СЂР°РєСѓР»С‹ (Р°СѓСЂР°)",
			["Drag out to float В· click to fold"] = "Р’С‹С‚Р°С‰Рё, С‡С‚РѕР±С‹ РѕС‚РєСЂРµРїРёС‚СЊ В· РєР»РёРє вЂ” СЃРІРµСЂРЅСѓС‚СЊ",
			["Drag to resize"] = "РџРѕС‚СЏРЅРё, С‡С‚РѕР±С‹ РёР·РјРµРЅРёС‚СЊ СЂР°Р·РјРµСЂ",
			["Dreamscape"] = "РњРµС‡С‚Р°",
			["Dropping for you only, in "] = "РџР°РґР°РµС‚ С‚РѕР»СЊРєРѕ Сѓ С‚РµР±СЏ, С‡РµСЂРµР· ",
			["Dupe script is in our Discord"] = "Р”СЋРї СЃРєСЂРёРїС‚ РІ РЅР°С€РµРј Discord",
			["Dupe"] = "Р”СЋРї",
			["Duration"] = "Р”Р»РёС‚РµР»СЊРЅРѕСЃС‚СЊ",
			["Dusk"] = "РЎСѓРјРµСЂРєРё",
			["ESP & visuals"] = "ESP Рё РІРёР·СѓР°Р»С‹",
			["ESP rebuilt from zero: boxes, skeleton, chams, names, fonts and presets with previews, plus ghosts of desync cheaters. Shader packs with HD materials, Texture Pack, custom skies and sky effects, weather, bullet and knife tracers, custom cursors and kill effects with sounds. Screen stretch now keeps every label in place."] = "ESP СЃ РЅСѓР»СЏ: СЂР°РјРєРё, СЃРєРµР»РµС‚, С‡Р°РјСЃС‹, РЅРёРєРё, С€СЂРёС„С‚С‹ Рё РїСЂРµСЃРµС‚С‹ СЃ РїСЂРµРІСЊСЋ, РїР»СЋСЃ РїСЂРёР·СЂР°РєРё РґРµСЃРёРЅРє-С‡РёС‚РµСЂРѕРІ. РЁРµР№РґРµСЂ-РїР°РєРё СЃ HD-РјР°С‚РµСЂРёР°Р»Р°РјРё, Texture Pack, СЃРІРѕРё РЅРµР±РµСЃР° Рё СЌС„С„РµРєС‚С‹ РЅРµР±Р°, РїРѕРіРѕРґР°, С‚СЂРµР№СЃРµСЂС‹ РїСѓР»СЊ Рё РЅРѕР¶РµР№, СЃРІРѕРё РєСѓСЂСЃРѕСЂС‹ Рё kill-СЌС„С„РµРєС‚С‹ СЃРѕ Р·РІСѓРєР°РјРё. Р Р°СЃС‚СЏР¶РєР° СЌРєСЂР°РЅР° Р±РѕР»СЊС€Рµ РЅРµ СЃР±РёРІР°РµС‚ РјРµС‚РєРё.",
			["ESP"] = "РњРµС‚РєРё",
			["ESP, world lighting and effects"] = "ESP, РѕСЃРІРµС‰РµРЅРёРµ Рё СЌС„С„РµРєС‚С‹",
			["EXP Farm"] = "Р¤Р°СЂРј РѕРїС‹С‚Р°",
			["Echo"] = "Р­С…Рѕ",
			["Economy"] = "Р­РєРѕРЅРѕРјРёРєР°",
			["Edge shade"] = "Р—Р°С‚РµРјРЅРµРЅРёРµ РєСЂР°С‘РІ",
			["Edit Stop #"] = "РР·РјРµРЅРёС‚СЊ С‚РѕС‡РєСѓ #",
			["Effect"] = "Р­С„С„РµРєС‚",
			["Effects"] = "Р­С„С„РµРєС‚С‹",
			["Electronic"] = "Р­Р»РµРєС‚СЂРѕРЅРёРєР°",
			["Emote Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ СЌРјРѕС†РёРё",
			["Emote catalog"] = "РљР°С‚Р°Р»РѕРі СЌРјРѕС†РёР№",
			["Emote options"] = "РќР°СЃС‚СЂРѕР№РєРё СЌРјРѕС†РёРё",
			["Emote"] = "Р­РјРѕС†РёСЏ",
			["Emotes"] = "Р­РјРѕС†РёРё",
			["Empty response."] = "РџСѓСЃС‚РѕР№ РѕС‚РІРµС‚.",
			["Enable Auto Buy Gears"] = "РђРІС‚РѕРїРѕРєСѓРїРєР° СЃРЅР°СЂСЏР¶РµРЅРёСЏ",
			["Enable Auto Buy Pets"] = "РђРІС‚РѕРїРѕРєСѓРїРєР° РїРёС‚РѕРјС†РµРІ",
			["Enable Auto Buy Props"] = "РђРІС‚РѕРїРѕРєСѓРїРєР° РїСЂРµРґРјРµС‚РѕРІ",
			["Enable Auto Buy Seeds"] = "РђРІС‚РѕРїРѕРєСѓРїРєР° СЃРµРјСЏРЅ",
			["Enable Auto Harvest"] = "РђРІС‚РѕСЃР±РѕСЂ",
			["Enable Auto Plant"] = "РђРІС‚РѕРїРѕСЃР°РґРєР°",
			["Enable Auto Sell"] = "РђРІС‚РѕРїСЂРѕРґР°Р¶Р°",
			["Enable Fruit ESP"] = "РњРµС‚РєРё С„СЂСѓРєС‚РѕРІ",
			["Enable Pet ESP"] = "РњРµС‚РєРё РїРёС‚РѕРјС†РµРІ",
			["Enable Players ESP"] = "РњРµС‚РєРё РёРіСЂРѕРєРѕРІ",
			["Enable Role ESP"] = "ESP СЂРѕР»РµР№",
			["Enable"] = "Р’РєР»СЋС‡РёС‚СЊ",
			["Enabled"] = "Р’РєР»СЋС‡РµРЅРѕ",
			["Energy"] = "Р­РЅРµСЂРіРёСЏ",
			["Engine"] = "Р”РІРёР¶РѕРє",
			["Enter a config key"] = "Р’РІРµРґРё РєР»СЋС‡ РєРѕРЅС„РёРіР°",
			["Enter a config name first"] = "РЎРЅР°С‡Р°Р»Р° РІРІРµРґРё РЅР°Р·РІР°РЅРёРµ",
			["Enter a username"] = "Р’РІРµРґРё РЅРёРє РёР»Рё ID",
			["Environment"] = "РћРєСЂСѓР¶РµРЅРёРµ",
			["Equip Selected"] = "РќР°РґРµС‚СЊ РІС‹Р±СЂР°РЅРЅСѓСЋ",
			["Equip Toy"] = "РќР°РґРµС‚СЊ РёРіСЂСѓС€РєСѓ",
			["Error: %s"] = "РћС€РёР±РєР°: %s",
			["Evening"] = "Р’РµС‡РµСЂ",
			["Events"] = "РЎРѕР±С‹С‚РёСЏ",
			["Everything important lives in our Discord: updates, keys and support. Jump in: discord.gg/pulsezone"] = "Р’СЃС‘ СЃР°РјРѕРµ РІР°Р¶РЅРѕРµ РІ РЅР°С€РµРј Discord: РѕР±РЅРѕРІР»РµРЅРёСЏ, РєР»СЋС‡Рё Рё РїРѕРґРґРµСЂР¶РєР°. Р—Р°Р»РµС‚Р°Р№: discord.gg/pulsezone",
			["Exclude (do not harvest)"] = "РСЃРєР»СЋС‡РёС‚СЊ (РЅРµ СЃРѕР±РёСЂР°С‚СЊ)",
			["Executor has no HTTP function."] = "РЈ СЌРєР·РµРєСѓС‚РѕСЂР° РЅРµС‚ HTTP-С„СѓРЅРєС†РёРё.",
			["Expand sidebar"] = "Р Р°Р·РІРµСЂРЅСѓС‚СЊ РїР°РЅРµР»СЊ",
			["Exposure level"] = "РЈСЂРѕРІРµРЅСЊ СЌРєСЃРїРѕР·РёС†РёРё",
			["Exposure"] = "Р­РєСЃРїРѕР·РёС†РёСЏ",
			["Extras"] = "Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ",
			["FAQ"] = "РРЅС„Рѕ",
			["FOV Color"] = "Р¦РІРµС‚ FOV",
			["FOV Size"] = "Р Р°Р·РјРµСЂ FOV",
			["FOV Transparency"] = "РџСЂРѕР·СЂР°С‡РЅРѕСЃС‚СЊ FOV",
			["FPS Unlocker (9999)"] = "РЎРЅСЏС‚СЊ Р»РёРјРёС‚ FPS (9999)",
			["Fade When Synced"] = "Р“Р°СЃРёС‚СЊ РїСЂРё СЃРѕРІРїР°РґРµРЅРёРё",
			["Fake Headless"] = "Р¤РµР№Рє Headless",
			["Fake Items"] = "Р¤РµР№Рє РїСЂРµРґРјРµС‚С‹",
			["Fake Korblox"] = "Р¤РµР№Рє Korblox",
			["Fall"] = "РџР°РґРµРЅРёРµ",
			["Farm Method"] = "РњРµС‚РѕРґ С„Р°СЂРјР°",
			["Farm Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ С„Р°СЂРјР°",
			["Farm"] = "Р¤Р°СЂРј",
			["Farm, mobile & more"] = "Р¤Р°СЂРј, РјРѕР±РёР»РєР° Рё РґСЂ.",
			["Farming"] = "Р¤Р°СЂРјР»СЋ",
			["Fast Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ Р±С‹СЃС‚СЂРѕРіРѕ",
			["Fast"] = "Р‘С‹СЃС‚СЂС‹Р№",
			["Favorite"] = "Р’ РёР·Р±СЂР°РЅРЅРѕРµ",
			["Favorites"] = "РР·Р±СЂР°РЅРЅРѕРµ",
			["Favs"] = "РР·Р±СЂ.",
			["Fetching config..."] = "РџРѕР»СѓС‡Р°СЋ РєРѕРЅС„РёРі...",
			["Fill Strength"] = "РЎРёР»Р° Р·Р°Р»РёРІРєРё",
			["Filled"] = "Р—Р°Р»РёРІРєР°",
			["Fire"] = "РћРіРѕРЅСЊ",
			["Fit to screen"] = "РџРѕРґРіРѕРЅРєР° РїРѕРґ СЌРєСЂР°РЅ",
			["Flames"] = "РџР»Р°РјСЏ",
			["Flick Angle"] = "РЈРіРѕР» С„Р»РёРєР°",
			["Flick Return %"] = "Р’РѕР·РІСЂР°С‚ С„Р»РёРєР° %",
			["Flick Shot"] = "Р¤Р»РёРє-С€РѕС‚",
			["Flick Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ С„Р»РёРєР°",
			["Flick With Mouse"] = "Р¤Р»РёРє СЂРµР°Р»СЊРЅРѕР№ РјС‹С€СЊСЋ",
			["Fling Murder"] = "Р¤Р»РёРЅРі РјР°СЂРґРµСЂР°",
			["Fling Murderer Button"] = "РљРЅРѕРїРєР° С„Р»РёРЅРіР° РјР°СЂРґРµСЂР°",
			["Fling Panel"] = "РџР°РЅРµР»СЊ С„Р»РёРЅРіР°",
			["Fling Players"] = "Р¤Р»РёРЅРі РёРіСЂРѕРєРѕРІ",
			["Fling Sheriff Button"] = "РљРЅРѕРїРєР° С„Р»РёРЅРіР° С€РµСЂРёС„Р°",
			["Fling Sheriff"] = "Р¤Р»РёРЅРі С€РµСЂРёС„Р°",
			["Fling"] = "Р¤Р»РёРЅРі",
			["Flinging"] = "Р¤Р»РёРЅРі",
			["Float"] = "РџР°СЂРµРЅРёРµ",
			["Floating В· drag back to dock"] = "РћС‚РєСЂРµРїР»РµРЅРѕ В· РІРµСЂРЅРё РїРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµРј",
			["Floss"] = "Р¤Р»РѕСЃСЃ",
			["Flow Aura"] = "РђСѓСЂР°: РџРѕС‚РѕРє",
			["Fly Button"] = "РљРЅРѕРїРєР° РїРѕР»С‘С‚Р°",
			["Fly Method"] = "РњРµС‚РѕРґ РїРѕР»С‘С‚Р°",
			["Fly Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ РїРѕР»С‘С‚Р°",
			["Fly"] = "РџРѕР»С‘С‚",
			["Fly: OFF"] = "РџРѕР»С‘С‚: Р’Р«РљР›",
			["Focus Distance"] = "Р”РёСЃС‚Р°РЅС†РёСЏ С„РѕРєСѓСЃР°",
			["Focus distance"] = "Р”РёСЃС‚Р°РЅС†РёСЏ С„РѕРєСѓСЃР°",
			["Fog control"] = "РўСѓРјР°РЅ",
			["Fog end"] = "РљРѕРЅРµС† С‚СѓРјР°РЅР°",
			["Fog start"] = "РќР°С‡Р°Р»Рѕ С‚СѓРјР°РЅР°",
			["Font"] = "РЁСЂРёС„С‚",
			["Fonts marked (A-Z) have no Cyrillic glyphs: Russian text stays in the default font."] = "РЈ С€СЂРёС„С‚РѕРІ СЃ РїРѕРјРµС‚РєРѕР№ (A-Z) РЅРµС‚ РєРёСЂРёР»Р»РёС†С‹: СЂСѓСЃСЃРєРёР№ С‚РµРєСЃС‚ РѕСЃС‚Р°РЅРµС‚СЃСЏ С€СЂРёС„С‚РѕРј РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ.",
			["Forget Secret"] = "Р—Р°Р±С‹С‚СЊ СЃРµРєСЂРµС‚",
			["Frames (surfaces)"] = "Р¤СЂРµР№РјС‹ (РїРѕРІРµСЂС…РЅРѕСЃС‚Рё)",
			["Free anims"] = "РђРЅРёРјР°С†РёРё",
			["Free bundles, emotes and skins"] = "Р‘РµСЃРїР»Р°С‚РЅС‹Рµ Р±Р°РЅРґР»С‹, СЌРјРѕС†РёРё Рё СЃРєРёРЅС‹",
			["Frostbite"] = "РњРѕСЂРѕР·",
			["Frozen Bloom Aura"] = "Р›РµРґСЏРЅРѕРµ С†РІРµС‚РµРЅРёРµ (Р°СѓСЂР°)",
			["Fruit ESP"] = "РњРµС‚РєРё С„СЂСѓРєС‚РѕРІ",
			["Fruit"] = "Р¤СЂСѓРєС‚С‹",
			["Full bag"] = "РњРµС€РѕРє РїРѕР»РѕРЅ",
			["Full"] = "РџРѕР»РЅС‹Р№",
			["Fun"] = "Р¤Р°РЅ",
			["Fun/Troll"] = "Р¤Р°РЅ/РўСЂРѕР»Р»",
			["Future Lighting"] = "РћСЃРІРµС‰РµРЅРёРµ Future",
			["GUIDE"] = "Р“РР”",
			["Galaxy Purple"] = "Р“Р°Р»Р°РєС‚РёРєР°",
			["Game Sounds Volume"] = "Р“СЂРѕРјРєРѕСЃС‚СЊ Р·РІСѓРєРѕРІ РёРіСЂС‹",
			["Game Sounds"] = "Р—РІСѓРєРё РёРіСЂС‹",
			["Game"] = "РљР°Рє РІ РёРіСЂРµ",
			["Gears"] = "РЎРЅР°СЂСЏР¶РµРЅРёРµ",
			["Gems"] = "Р“РµРјС‹",
			["General"] = "РћР±С‰РµРµ",
			["Get"] = "РЎРєР°С‡Р°С‚СЊ",
			["Ghost (animated)"] = "РџСЂРёР·СЂР°Рє (Р°РЅРёРјР°С†РёСЏ)",
			["Ghost"] = "РџСЂРёР·СЂР°Рє",
			["Glitch Acceleration"] = "Р Р°Р·РіРѕРЅ РІ РІРѕР·РґСѓС…Рµ",
			["Glitch Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ РіР»РёС‚С‡Р°",
			["Glow (animated)"] = "РЎРІРµС‡РµРЅРёРµ (Р°РЅРёРјР°С†РёСЏ)",
			["Glow intensity"] = "РЎРёР»Р° СЃРІРµС‡РµРЅРёСЏ",
			["Glow radius"] = "Р Р°РґРёСѓСЃ СЃРІРµС‡РµРЅРёСЏ",
			["Glow threshold"] = "РџРѕСЂРѕРі СЃРІРµС‡РµРЅРёСЏ",
			["Glow"] = "РЎРІРµС‡РµРЅРёРµ",
			["Go"] = "РќР°Р№С‚Рё",
			["Golden Hour"] = "Р—РѕР»РѕС‚РѕР№ С‡Р°СЃ",
			["Golden Valley"] = "Р—РѕР»РѕС‚Р°СЏ РґРѕР»РёРЅР°",
			["Got"] = "РЎРєР°С‡Р°РЅ",
			["Gradient Angle"] = "РЈРіРѕР» РіСЂР°РґРёРµРЅС‚Р°",
			["Gradient Stops"] = "РўРѕС‡РєРё РіСЂР°РґРёРµРЅС‚Р°",
			["Gradient"] = "Р“СЂР°РґРёРµРЅС‚",
			["Gravity Value"] = "РЎРёР»Р° РіСЂР°РІРёС‚Р°С†РёРё",
			["Gravity"] = "Р“СЂР°РІРёС‚Р°С†РёСЏ",
			["Green button label"] = "РќР°РґРїРёСЃСЊ РЅР° Р·РµР»С‘РЅРѕР№ РєРЅРѕРїРєРµ",
			["Green"] = "Р—РµР»С‘РЅС‹Р№",
			["Ground Fog"] = "РўСѓРјР°РЅ РѕС‚ Р·РµРјР»Рё",
			["Group labels"] = "РќР°Р·РІР°РЅРёСЏ РіСЂСѓРїРї",
			["Guide"] = "Р“РёРґ",
			["Gun ESP"] = "ESP РїРёСЃС‚РѕР»РµС‚Р°",
			["Gun"] = "РџРёСЃС‚РѕР»РµС‚",
			["GunFired not found: retries and ping measurement are off, still searching"] = "GunFired РЅРµ РЅР°Р№РґРµРЅ: СЂРµС‚СЂР°Рё Рё Р·Р°РјРµСЂ РїРёРЅРіР° РІС‹РєР»СЋС‡РµРЅС‹, РёС‰Сѓ РґР°Р»СЊС€Рµ",
			["HD Realistic"] = "HD СЂРµР°Р»РёР·Рј",
			["HD Wet"] = "HD РјРѕРєСЂС‹Рµ",
			["HD Worn"] = "HD РїРѕС‚С‘СЂС‚С‹Рµ",
			["HWID copied"] = "HWID СЃРєРѕРїРёСЂРѕРІР°РЅ",
			["Hair"] = "Р’РѕР»РѕСЃС‹",
			["Halloween Key"] = "РҐСЌР»Р»РѕСѓРёРЅ-РєР»СЋС‡",
			["Halloween theme"] = "РҐСЌР»Р»РѕСѓРёРЅ-С‚РµРјР°",
			["Halo"] = "РќРёРјР±",
			["Hats"] = "РЁР»СЏРїС‹",
			["Haze"] = "Р”С‹РјРєР°",
			["Head"] = "Р“РѕР»РѕРІР°",
			["Heart"] = "РЎРµСЂРґС†Рµ",
			["Hearts"] = "РЎРµСЂРґС†Р°",
			["Heavenly Aura"] = "РђСѓСЂР°: РќРµР±РµСЃРЅР°СЏ",
			["Heavy"] = "РўСЏР¶С‘Р»С‹Р№",
			["Height"] = "Р’С‹СЃРѕС‚Р°",
			["Helicopter"] = "Р’РµСЂС‚РѕР»С‘С‚",
			["Hero Flip"] = "РЎР°Р»СЊС‚Рѕ",
			["Hero"] = "Р“РµСЂРѕР№",
			["Hidden from the list"] = "РЈР±СЂР°РЅ РёР· СЃРїРёСЃРєР°",
			["Hidden"] = "РЎРєСЂС‹С‚",
			["Hide Dead"] = "РЎРєСЂС‹РІР°С‚СЊ РјС‘СЂС‚РІС‹С…",
			["Hide server"] = "РЎРєСЂС‹С‚СЊ СЃРµСЂРІРµСЂ",
			["Hide"] = "РЎРєСЂС‹С‚СЊ",
			["Highlight body"] = "РџРѕРґСЃРІРµС‚РєР° С‚РµР»Р°",
			["Hip Height Value"] = "Р’С‹СЃРѕС‚Р°",
			["Hip Height"] = "Р’С‹СЃРѕС‚Р° РЅР°Рґ Р·РµРјР»С‘Р№",
			["Hip Hop"] = "РҐРёРї-С…РѕРї",
			["Hold (don't stop when moving)"] = "РЈРґРµСЂР¶Р°РЅРёРµ (РЅРµ СЃС‚РѕРїРёС‚СЊ РїСЂРё РґРІРёР¶РµРЅРёРё)",
			["Hold"] = "РЈРґРµСЂР¶Р°РЅРёРµ",
			["Hop Mode"] = "Р РµР¶РёРј РѕС‚СЃРєРѕРєР°",
			["Hopping: %d/%d players"] = "РџСЂС‹РіР°СЋ: %d/%d РёРіСЂРѕРєРѕРІ",
			["Horizon offset"] = "РЎРґРІРёРі РіРѕСЂРёР·РѕРЅС‚Р°",
			["Horizon"] = "Р“РѕСЂРёР·РѕРЅС‚",
			["Horror"] = "РҐРѕСЂСЂРѕСЂ",
			["Hour"] = "Р§Р°СЃ",
			["House"] = "РҐР°СѓСЃ",
			["Hover"] = "Р›РµРІРёС‚Р°С†РёСЏ",
			["Hump Duration (0 = hold)"] = "Р”Р»РёС‚РµР»СЊРЅРѕСЃС‚СЊ (0 = РґРµСЂР¶Р°С‚СЊ)",
			["I have a problem"] = "РЈ РјРµРЅСЏ РїСЂРѕР±Р»РµРјР°",
			["Ice & Love"] = "Р›С‘Рґ Рё Р»СЋР±РѕРІСЊ",
			["Idle"] = "РЎС‚РѕСЏ",
			["Image Transparency"] = "РџСЂРѕР·СЂР°С‡РЅРѕСЃС‚СЊ РєР°СЂС‚РёРЅРєРё",
			["Image is too large"] = "Р¤РѕС‚Рѕ СЃР»РёС€РєРѕРј Р±РѕР»СЊС€РѕРµ",
			["Impact Effect"] = "Р­С„С„РµРєС‚ РїРѕРїР°РґР°РЅРёСЏ",
			["Import Config"] = "РРјРїРѕСЂС‚ РєРѕРЅС„РёРіР°",
			["Import config"] = "РРјРїРѕСЂС‚РёСЂРѕРІР°С‚СЊ",
			["Import"] = "РРјРїРѕСЂС‚",
			["In development"] = "Р’ СЂР°Р·СЂР°Р±РѕС‚РєРµ",
			["In saved"] = "Р’ РёР·Р±СЂР°РЅРЅРѕРј",
			["Indoor"] = "Р’РЅСѓС‚СЂРё",
			["Infinite Jump"] = "Р‘РµСЃРєРѕРЅРµС‡РЅС‹Р№ РїСЂС‹Р¶РѕРє",
			["Infinite Jumps"] = "Р‘РµСЃРєРѕРЅРµС‡РЅС‹Рµ РїСЂС‹Р¶РєРё",
			["Innocent Win Farm"] = "Р¤Р°СЂРј РїРѕР±РµРґ Р·Р° РјРёСЂРЅРѕРіРѕ",
			["Innocent"] = "РњРёСЂРЅС‹Р№",
			["Instant"] = "РњРіРЅРѕРІРµРЅРЅРѕ",
			["Intensity"] = "РРЅС‚РµРЅСЃРёРІРЅРѕСЃС‚СЊ",
			["Interface sounds"] = "Р—РІСѓРєРё РёРЅС‚РµСЂС„РµР№СЃР°",
			["Interface"] = "РРЅС‚РµСЂС„РµР№СЃ",
			["Inventory Values"] = "Р¦РµРЅС‹ РІ РёРЅРІРµРЅС‚Р°СЂРµ",
			["Invis"] = "РќРµРІРёРґРёРјРєР°",
			["Invis: OFF"] = "РќРµРІРёРґРёРјРєР°: Р’Р«РљР›",
			["Invisible Button"] = "РљРЅРѕРїРєР° РЅРµРІРёРґРёРјРєРё",
			["Invisible"] = "РќРµРІРёРґРёРјРѕСЃС‚СЊ",
			["Jacks"] = "РџСЂС‹Р¶РєРё Р·РІРµР·РґРѕР№",
			["Jerk Off Tool (R15)"] = "Р”СЂРѕС‡РєР° Р 15",
			["Jitter (anti-lead)"] = "Р”СЂРѕР¶Р°РЅРёРµ (РїСЂРѕС‚РёРІ СѓРїСЂРµР¶РґРµРЅРёСЏ)",
			["Jitter"] = "Р”СЂРѕР¶СЊ",
			["Join Discord"] = "Р—Р°Р№С‚Рё РІ Discord",
			["Join Job ID"] = "Р—Р°Р№С‚Рё РїРѕ Job ID",
			["Join Small Server"] = "РњР°Р»С‹Р№ СЃРµСЂРІРµСЂ",
			["Join Smallest Server"] = "Р—Р°Р№С‚Рё РіРґРµ РјРµРЅСЊС€Рµ РёРіСЂРѕРєРѕРІ",
			["Join link copied, open it in your browser"] = "РЎСЃС‹Р»РєР° РґР»СЏ РІС…РѕРґР° СЃРєРѕРїРёСЂРѕРІР°РЅР°, РѕС‚РєСЂРѕР№ РµС‘ РІ Р±СЂР°СѓР·РµСЂРµ",
			["Join servers with other Pulse users"] = "Р—Р°С…РѕРґРё РЅР° СЃРµСЂРІРµСЂС‹ Рє РґСЂСѓРіРёРј Pulse СЋР·РµСЂР°Рј",
			["Join"] = "Р—Р°Р№С‚Рё",
			["Joining..."] = "Р—Р°С…РѕР¶Сѓ...",
			["Joining: %d/%d players"] = "Р—Р°С…РѕР¶Сѓ: %d/%d РёРіСЂРѕРєРѕРІ",
			["Jump Power Value"] = "РЎРёР»Р° РїСЂС‹Р¶РєР°",
			["Jump Power"] = "РЎРёР»Р° РїСЂС‹Р¶РєР°",
			["Jump to roles and players"] = "РўРµР»РµРїРѕСЂС‚ Рє СЂРѕР»СЏРј Рё РёРіСЂРѕРєР°Рј",
			["Jump"] = "РџСЂС‹Р¶РѕРє",
			["Just a troll who lives next to the radio. I watch sheriffs miss and murderers fail all day. Problem?"] = "РџСЂРѕСЃС‚Рѕ С‚СЂРѕР»Р»СЊ, РєРѕС‚РѕСЂС‹Р№ Р¶РёРІС‘С‚ Сѓ СЂР°РґРёРѕ. Р¦РµР»С‹Р№ РґРµРЅСЊ СЃРјРѕС‚СЂСЋ, РєР°Рє С€РµСЂРёС„С‹ РјР°Р¶СѓС‚, Р° РјР°СЂРґРµСЂС‹ С„РµР№Р»СЏС‚. РџСЂРѕР±Р»РµРјС‹?",
			["Keep pitch"] = "РЎРѕС…СЂР°РЅСЏС‚СЊ С‚РѕРЅ",
			["Kept for this session only - executor has no writefile."] = "РўРѕР»СЊРєРѕ РЅР° СЌС‚Сѓ СЃРµСЃСЃРёСЋ вЂ” Сѓ СЌРєР·РµРєСѓС‚РѕСЂР° РЅРµС‚ writefile.",
			["Key copied"] = "РљР»СЋС‡ СЃРєРѕРїРёСЂРѕРІР°РЅ",
			["Key"] = "РљР»СЋС‡",
			["Keybinds"] = "РљРµР№Р±РёРЅРґС‹",
			["Kill All Murder Button"] = "РљРЅРѕРїРєР° СѓР±РёС‚СЊ РІСЃРµС…",
			["Kill All"] = "РЈР±РёС‚СЊ РІСЃРµС…",
			["Kill Aura"] = "РљРёР»Р» Р°СѓСЂР°",
			["Kill Distance"] = "Р”РёСЃС‚Р°РЅС†РёСЏ СѓР±РёР№СЃС‚РІР°",
			["Kill Gun Players"] = "РЈР±РёС‚СЊ РІСЃРµС… СЃ РїРёСЃС‚РѕР»РµС‚РѕРј",
			["Kill Player"] = "РЈР±РёС‚СЊ РёРіСЂРѕРєР°",
			["Kill Selected"] = "РЈР±РёС‚СЊ РІС‹Р±СЂР°РЅРЅРѕРіРѕ",
			["Kill Sound"] = "Р—РІСѓРє СѓР±РёР№СЃС‚РІР°",
			["Kill all on full bag (murder role)"] = "РЈР±РёС‚СЊ РІСЃРµС… РїСЂРё РїРѕР»РЅРѕРј РјРµС€РєРµ (СЂРѕР»СЊ РјР°СЂРґРµСЂР°)",
			["Kill aura, knife throws and targets"] = "РљРёР»Р» Р°СѓСЂР°, Р±СЂРѕСЃРєРё РЅРѕР¶Р° Рё С†РµР»Рё",
			["KillAll: OFF"] = "РЈР±РёС‚СЊ РІСЃРµС…: Р’Р«РљР›",
			["Killing"] = "РЈР±РёРІР°РµС‚",
			["Kills"] = "РЈР±РёР№СЃС‚РІР°",
			["Knife Effects"] = "Р­С„С„РµРєС‚С‹ РЅРѕР¶Р°",
			["Knife On Belt"] = "РќРѕР¶ РЅР° РїРѕСЏСЃРµ",
			["Knife Throw Aimbot"] = "РђРёРјР±РѕС‚ Р±СЂРѕСЃРєР° РЅРѕР¶Р°",
			["Knife Throw Button"] = "РљРЅРѕРїРєР° Р±СЂРѕСЃРєР° РЅРѕР¶Р°",
			["Knife Throw"] = "Р‘СЂРѕСЃРѕРє РЅРѕР¶Р°",
			["Knife"] = "РќРѕР¶",
			["Lamp brightness"] = "РЇСЂРєРѕСЃС‚СЊ Р»Р°РјРї",
			["Lamp shadows"] = "РўРµРЅРё РѕС‚ Р»Р°РјРї",
			["Language"] = "РЇР·С‹Рє",
			["Laser"] = "Р›Р°Р·РµСЂ",
			["Last Drop"] = "РџРѕСЃР»РµРґРЅРёР№ РґСЂРѕРї",
			["Latitude"] = "РЁРёСЂРѕС‚Р°",
			["Launcher button"] = "РљРЅРѕРїРєР° Р·Р°РїСѓСЃРєР°",
			["Legs"] = "РќРѕРіРё",
			["Less time = faster pickup"] = "РњРµРЅСЊС€Рµ СЃРµРєСѓРЅРґ вЂ” Р±С‹СЃС‚СЂРµРµ РїРѕРґР±РѕСЂ",
			["Library"] = "Р‘РёР±Р»РёРѕС‚РµРєР°",
			["Light colors"] = "Р¦РІРµС‚Р° СЃРІРµС‚Р°",
			["Light level"] = "РЈСЂРѕРІРµРЅСЊ СЃРІРµС‚Р°",
			["Light"] = "РЎРІРµС‚",
			["Lighting"] = "РћСЃРІРµС‰РµРЅРёРµ",
			["Lightning"] = "РњРѕР»РЅРёСЏ",
			["Limit Distance"] = "РћРіСЂР°РЅРёС‡РёС‚СЊ РґРёСЃС‚Р°РЅС†РёСЋ",
			["Link copied: discord.gg/pulsezone"] = "РЎСЃС‹Р»РєР° СЃРєРѕРїРёСЂРѕРІР°РЅР°: discord.gg/pulsezone",
			["Links and ads are not allowed"] = "РЎСЃС‹Р»РєРё Рё СЂРµРєР»Р°РјР° Р·Р°РїСЂРµС‰РµРЅС‹",
			["Links are not allowed"] = "РЎСЃС‹Р»РєРё Р·Р°РїСЂРµС‰РµРЅС‹",
			["List is empty - paste a link and press Add."] = "РЎРїРёСЃРѕРє РїСѓСЃС‚ вЂ” РІСЃС‚Р°РІСЊ СЃСЃС‹Р»РєСѓ Рё РЅР°Р¶РјРё Р”РѕР±Р°РІРёС‚СЊ.",
			["Lo-Fi"] = "Р›РѕСѓ-С„Р°Р№",
			["Load more"] = "РџРѕРєР°Р·Р°С‚СЊ РµС‰С‘",
			["Loading skins"] = "Р—Р°РіСЂСѓР·РєР° СЃРєРёРЅРѕРІ",
			["Loading"] = "Р—Р°РіСЂСѓР·РєР°",
			["Loading..."] = "Р—Р°РіСЂСѓР·РєР°...",
			["Lobby"] = "Р›РѕР±Р±Рё",
			["Lock Color"] = "Р¦РІРµС‚ Р·Р°С…РІР°С‚Р°",
			["Look"] = "РћР±СЂР°Р·",
			["Looks"] = "РћР±СЂР°Р·С‹",
			["Low FPS / lag"] = "РќРёР·РєРёР№ FPS / Р»Р°РіРё",
			["Low Graphics"] = "РќРёР·РєР°СЏ РіСЂР°С„РёРєР°",
			["Low Quality"] = "РќРёР·РєРѕРµ РєР°С‡РµСЃС‚РІРѕ",
			["Magic Circle Aura"] = "РњР°РіРёС‡РµСЃРєРёР№ РєСЂСѓРі (Р°СѓСЂР°)",
			["Main"] = "Р“Р»Р°РІРЅР°СЏ",
			["Manual Delay"] = "Р СѓС‡РЅР°СЏ Р·Р°РґРµСЂР¶РєР°",
			["Materials"] = "РњР°С‚РµСЂРёР°Р»С‹",
			["Matrix"] = "РњР°С‚СЂРёС†Р°",
			["Max billboards"] = "РњР°РєСЃ. РјРµС‚РѕРє",
			["Max distance (0 = all)"] = "РњР°РєСЃ. РґРёСЃС‚Р°РЅС†РёСЏ (0 = РІСЃРµ)",
			["Mention"] = "РЈРїРѕРјРёРЅР°РЅРёРµ",
			["Menu & community"] = "РњРµРЅСЋ Рё РєРѕРјСЊСЋРЅРёС‚Рё",
			["Menu Font"] = "РЁСЂРёС„С‚ РјРµРЅСЋ",
			["Menu key"] = "РљР»Р°РІРёС€Р° РјРµРЅСЋ",
			["Menu"] = "РњРµРЅСЋ",
			["Menu, configs and performance"] = "РњРµРЅСЋ, РєРѕРЅС„РёРіРё Рё РїСЂРѕРёР·РІРѕРґРёС‚РµР»СЊРЅРѕСЃС‚СЊ",
			["Message is empty."] = "РЎРѕРѕР±С‰РµРЅРёРµ РїСѓСЃС‚РѕРµ.",
			["Message is too long"] = "РЎР»РёС€РєРѕРј РґР»РёРЅРЅРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ",
			["Message is too old"] = "РЎРѕРѕР±С‰РµРЅРёРµ СЃР»РёС€РєРѕРј СЃС‚Р°СЂРѕРµ",
			["Message not found"] = "РЎРѕРѕР±С‰РµРЅРёРµ РЅРµ РЅР°Р№РґРµРЅРѕ",
			["Message text"] = "РўРµРєСЃС‚ СЃРѕРѕР±С‰РµРЅРёСЏ",
			["Message"] = "РЎРѕРѕР±С‰РµРЅРёРµ",
			["Midday"] = "РџРѕР»РґРµРЅСЊ",
			["Midnight Blue"] = "РџРѕР»СѓРЅРѕС‡РЅС‹Р№ СЃРёРЅРёР№",
			["Midnight"] = "РџРѕР»РЅРѕС‡СЊ",
			["Mine"] = "РњРѕРё",
			["Minimal"] = "РњРёРЅРёРјР°Р»",
			["Mobile"] = "РўРµР»РµС„РѕРЅ",
			["Mode"] = "Р РµР¶РёРј",
			["Moon size"] = "Р Р°Р·РјРµСЂ Р»СѓРЅС‹",
			["Moonlight"] = "Р›СѓРЅРЅС‹Р№ СЃРІРµС‚",
			["Morning"] = "РЈС‚СЂРѕ",
			["Movement key"] = "РљР»Р°РІРёС€Р° РґРІРёР¶РµРЅРёСЏ",
			["Movement"] = "РџРµСЂРµРґРІРёР¶РµРЅРёРµ",
			["Movement, speed and protection"] = "Р”РІРёР¶РµРЅРёРµ, СЃРєРѕСЂРѕСЃС‚СЊ Рё Р·Р°С‰РёС‚Р°",
			["Muffled"] = "Р—Р° СЃС‚РµРЅРѕР№",
			["Murder"] = "РЈР±РёР№С†Р°",
			["Murderer Kill Farm"] = "Р¤Р°СЂРј СѓР±РёР№СЃС‚РІ Р·Р° РјР°СЂРґРµСЂР°",
			["Murderer"] = "РЈР±РёР№С†Р°",
			["Music Player"] = "РџР»РµРµСЂ",
			["Music Volume"] = "Р“СЂРѕРјРєРѕСЃС‚СЊ РјСѓР·С‹РєРё",
			["Music started, rain in "] = "РњСѓР·С‹РєР° РїРѕС€Р»Р°, РґРѕР¶РґСЊ С‡РµСЂРµР· ",
			["Music"] = "РњСѓР·С‹РєР°",
			["Mute game effects"] = "РЈР±СЂР°С‚СЊ СЌС„С„РµРєС‚С‹ РёРіСЂС‹",
			["Mute"] = "Р‘РµР· Р·РІСѓРєР°",
			["Muzzle Flash"] = "Р’СЃРїС‹С€РєР° РґСѓР»Р°",
			["My Configs"] = "РњРѕРё РєРѕРЅС„РёРіРё",
			["My Songs"] = "РњРѕРё С‚СЂРµРєРё",
			["My Themes"] = "РњРѕРё С‚РµРјС‹",
			["My configs"] = "РњРѕРё РєРѕРЅС„РёРіРё",
			["Mystic"] = "РњРёСЃС‚РёРєР°",
			["NO STOCK"] = "РќР•Рў Р’ РЎРўРћРљР•",
			["Name (optional)"] = "РќР°Р·РІР°РЅРёРµ (РЅРµРѕР±СЏР·Р°С‚РµР»СЊРЅРѕ)",
			["Natural"] = "РќР°С‚СѓСЂР°Р»СЊРЅС‹Р№",
			["Nebula"] = "РўСѓРјР°РЅРЅРѕСЃС‚СЊ",
			["Need an http(s) link."] = "РќСѓР¶РЅР° СЃСЃС‹Р»РєР° http(s).",
			["Neon Brightness"] = "РќРµРѕРЅ: СЏСЂРєРѕСЃС‚СЊ",
			["Neon City"] = "РќРµРѕРЅРѕРІС‹Р№ РіРѕСЂРѕРґ",
			["Neon Clock"] = "РќРµРѕРЅ: РІСЂРµРјСЏ СЃСѓС‚РѕРє",
			["Neon Cyber"] = "РќРµРѕРЅ РљРёР±РµСЂ",
			["Neon Exposure"] = "РќРµРѕРЅ: СЌРєСЃРїРѕР·РёС†РёСЏ",
			["Neon Haze"] = "РќРµРѕРЅ: РґС‹РјРєР°",
			["Neon Night"] = "РќРµРѕРЅРѕРІР°СЏ РЅРѕС‡СЊ",
			["Neon Purple"] = "РќРµРѕРЅ Р¤РёРѕР»РµС‚",
			["Neon glow"] = "РЎРІРµС‡РµРЅРёРµ РЅРµРѕРЅР°",
			["Neon"] = "РќРµРѕРЅ",
			["New Pulse X aim: predicts movement, beats speed and desync cheaters and waits for a clean shot near walls. Shot Timing, Sticky Target, knife throw aim and Auto Throw. Backtrack shows where the server really sees players. Plus Anti Aim with desync modes, Anti Coin, a Fling panel and Pick Up Gun from any distance."] = "РќРѕРІС‹Р№ Р°РёРј Pulse X: РїСЂРµРґСѓРіР°РґС‹РІР°РµС‚ РґРІРёР¶РµРЅРёРµ, РїСЂРѕР±РёРІР°РµС‚ С‡РёС‚РµСЂРѕРІ СЃРѕ СЃРєРѕСЂРѕСЃС‚СЊСЋ Рё РґРµСЃРёРЅРєРѕРј Рё Р¶РґС‘С‚ С‡РёСЃС‚С‹Р№ РІС‹СЃС‚СЂРµР» Сѓ СЃС‚РµРЅ. Shot Timing, Sticky Target, Р°РёРј Р±СЂРѕСЃРєР° РЅРѕР¶Р° Рё Auto Throw. Backtrack РїРѕРєР°Р·С‹РІР°РµС‚, РіРґРµ РёРіСЂРѕРєР° СЂРµР°Р»СЊРЅРѕ РІРёРґРёС‚ СЃРµСЂРІРµСЂ. Рђ РµС‰С‘ Anti Aim СЃ СЂРµР¶РёРјР°РјРё РґРµСЃРёРЅРєР°, Anti Coin, РїР°РЅРµР»СЊ С„Р»РёРЅРіР° Рё РїРѕРґР±РѕСЂ РїРёСЃС‚РѕР»РµС‚Р° СЃ Р»СЋР±РѕР№ РґРёСЃС‚Р°РЅС†РёРё.",
			["New config"] = "РќРѕРІС‹Р№ РєРѕРЅС„РёРі",
			["New messages"] = "РќРѕРІС‹Рµ СЃРѕРѕР±С‰РµРЅРёСЏ",
			["New"] = "РќРѕРІС‹Рµ",
			["Next look"] = "РЎР»РµРґСѓСЋС‰РёР№ РѕР±СЂР°Р·",
			["Next"] = "Р”Р°Р»СЊС€Рµ",
			["Night Brightness"] = "РќРѕС‡СЊ: СЏСЂРєРѕСЃС‚СЊ",
			["Night Clock"] = "РќРѕС‡СЊ: РІСЂРµРјСЏ СЃСѓС‚РѕРє",
			["Night Exposure"] = "РќРѕС‡СЊ: СЌРєСЃРїРѕР·РёС†РёСЏ",
			["Night Haze"] = "РќРѕС‡СЊ: РїР»РѕС‚РЅРѕСЃС‚СЊ РґС‹РјРєРё",
			["Night"] = "РќРѕС‡СЊ",
			["No Clip (walk through walls)"] = "No Clip (СЃРєРІРѕР·СЊ СЃС‚РµРЅС‹)",
			["No Clip Camera"] = "РљР°РјРµСЂР° СЃРєРІРѕР·СЊ СЃС‚РµРЅС‹",
			["No Clip Key"] = "No Clip",
			["No Clip"] = "РЎРєРІРѕР·СЊ РѕР±СЉРµРєС‚С‹",
			["No HWID for this message"] = "РЈ СЃРѕРѕР±С‰РµРЅРёСЏ РЅРµС‚ HWID",
			["No Map Lights"] = "Р‘РµР· Р»Р°РјРї РєР°СЂС‚С‹",
			["No Particles"] = "Р‘РµР· С‡Р°СЃС‚РёС†",
			["No Post Effects"] = "Р‘РµР· РїРѕСЃС‚-СЌС„С„РµРєС‚РѕРІ",
			["No Pulse users on other servers"] = "РќР° РґСЂСѓРіРёС… СЃРµСЂРІРµСЂР°С… Pulse СЋР·РµСЂРѕРІ РЅРµС‚",
			["No Shadows"] = "Р‘РµР· С‚РµРЅРµР№",
			["No Textures"] = "Р‘РµР· С‚РµРєСЃС‚СѓСЂ",
			["No admin secret saved - the backend will reject this."] = "РЎРµРєСЂРµС‚ РЅРµ СЃРѕС…СЂР°РЅС‘РЅ вЂ” СЃРµСЂРІРµСЂ РѕС‚РєР»РѕРЅРёС‚ Р·Р°РїСЂРѕСЃ.",
			["No atmosphere"] = "Р‘РµР· Р°С‚РјРѕСЃС„РµСЂС‹",
			["No configs yet"] = "РљРѕРЅС„РёРіРѕРІ РїРѕРєР° РЅРµС‚",
			["No connection"] = "РќРµС‚ СЃРІСЏР·Рё",
			["No favorites yet save bundles/emotes from the other sub-tabs."] = "РР·Р±СЂР°РЅРЅРѕРіРѕ РїРѕРєР° РЅРµС‚ вЂ” СЃРѕС…СЂР°РЅСЏР№ Р±Р°РЅРґР»С‹ Рё СЌРјРѕС†РёРё РЅР° СЃРѕСЃРµРґРЅРёС… РІРєР»Р°РґРєР°С….",
			["No favorites yet"] = "Р’ РёР·Р±СЂР°РЅРЅРѕРј РїСѓСЃС‚Рѕ",
			["No keybinds set"] = "РљРµР№Р±РёРЅРґС‹ РЅРµ Р·Р°РґР°РЅС‹",
			["No map loaded"] = "РљР°СЂС‚Р° РµС‰С‘ РЅРµ Р·Р°РіСЂСѓР¶РµРЅР°",
			["No messages yet"] = "РЎРѕРѕР±С‰РµРЅРёР№ РїРѕРєР° РЅРµС‚",
			["No players in the server"] = "РќР° СЃРµСЂРІРµСЂРµ РЅРµС‚ РёРіСЂРѕРєРѕРІ",
			["No players"] = "РќРµС‚ РёРіСЂРѕРєРѕРІ",
			["No published configs"] = "РќРµС‚ РѕРїСѓР±Р»РёРєРѕРІР°РЅРЅС‹С… РєРѕРЅС„РёРіРѕРІ",
			["No rights"] = "РќРµС‚ РїСЂР°РІ",
			["No saved configs"] = "РќРµС‚ РёР·Р±СЂР°РЅРЅС‹С… РєРѕРЅС„РёРіРѕРІ",
			["No secret yet - broadcasts will be rejected with 403."] = "РЎРµРєСЂРµС‚Р° РїРѕРєР° РЅРµС‚ вЂ” РѕР±СЉСЏРІР»РµРЅРёСЏ РІРµСЂРЅСѓС‚ 403.",
			["No servers found, try again"] = "РЎРµСЂРІРµСЂРѕРІ РЅРµ РЅР°С€С‘Р» вЂ” РїРѕРїСЂРѕР±СѓР№ РµС‰С‘ СЂР°Р·",
			["No shadows"] = "Р‘РµР· С‚РµРЅРµР№",
			["No songs add ID + name above"] = "РўСЂРµРєРѕРІ РЅРµС‚ вЂ” РґРѕР±Р°РІСЊ ID Рё РЅР°Р·РІР°РЅРёРµ РІС‹С€Рµ",
			["No songs"] = "РЎРїРёСЃРѕРє РїСѓСЃС‚",
			["No votes"] = "РќРµС‚ РѕС†РµРЅРѕРє",
			["Noir"] = "РќСѓР°СЂ",
			["None"] = "РќРµС‚",
			["Not allowed"] = "РќРµР»СЊР·СЏ",
			["Not enough"] = "РќРµ С…РІР°С‚Р°РµС‚",
			["Not sent"] = "РќРµ РѕС‚РїСЂР°РІР»РµРЅРѕ",
			["Nothing found"] = "РќРёС‡РµРіРѕ РЅРµ РЅР°Р№РґРµРЅРѕ",
			["Nothing played yet"] = "Р•С‰С‘ РЅРёС‡РµРіРѕ РЅРµ РёРіСЂР°Р»Рѕ",
			["Nothing playing"] = "РќРёС‡РµРіРѕ РЅРµ РёРіСЂР°РµС‚",
			["Nothing selected"] = "РўСЂРµРє РЅРµ РІС‹Р±СЂР°РЅ",
			["Notification"] = "РЈРІРµРґРѕРјР»РµРЅРёРµ",
			["Off"] = "Р’С‹РєР»",
			["On-screen Player"] = "РџР»РµРµСЂ РЅР° СЌРєСЂР°РЅРµ",
			["On-screen buttons (mobile). Hold & drag a button to move it, tap to use."] = "Р­РєСЂР°РЅРЅС‹Рµ РєРЅРѕРїРєРё (РјРѕР±.). Р—Р°Р¶РјРё Рё С‚Р°С‰Рё РєРЅРѕРїРєСѓ, С‡С‚РѕР±С‹ РґРІРёРіР°С‚СЊ, С‚Р°РїРЅРё вЂ” С‡С‚РѕР±С‹ РЅР°Р¶Р°С‚СЊ.",
			["On-screen buttons for touch"] = "РљРЅРѕРїРєРё РЅР° СЌРєСЂР°РЅРµ РґР»СЏ С‚РµР»РµС„РѕРЅР°",
			["Once a minute"] = "РџРёСЃР°С‚СЊ РјРѕР¶РЅРѕ СЂР°Р· РІ РјРёРЅСѓС‚Сѓ",
			["One of the best scripts for Grow a Garden 2"] = "РћРґРёРЅ РёР· Р»СѓС‡С€РёС… СЃРєСЂРёРїС‚РѕРІ РґР»СЏ Grow a Garden 2",
			["Online"] = "РћРЅР»Р°Р№РЅ",
			["Only Legendary+"] = "РўРѕР»СЊРєРѕ Legendary+",
			["Opacity"] = "РќРµРїСЂРѕР·СЂР°С‡РЅРѕСЃС‚СЊ",
			["Open Delay"] = "Р—Р°РґРµСЂР¶РєР° РѕС‚РєСЂС‹С‚РёСЏ",
			["Open Once"] = "РћС‚РєСЂС‹С‚СЊ 1",
			["Open a ticket in our Discord. Real people answer there, not trolls. Mostly."] = "РћС‚РєСЂРѕР№ С‚РёРєРµС‚ РІ РЅР°С€РµРј Discord. РўР°Рј РѕС‚РІРµС‡Р°СЋС‚ Р¶РёРІС‹Рµ Р»СЋРґРё, Р° РЅРµ С‚СЂРѕР»Р»Рё. Р’ РѕСЃРЅРѕРІРЅРѕРј.",
			["Opened"] = "РћС‚РєСЂС‹С‚Рѕ",
			["Opening"] = "РћС‚РєСЂС‹РІР°РµС‚",
			["Optimizer (ON)"] = "РћРїС‚РёРјРёР·Р°С‚РѕСЂ (Р’РљР›)",
			["Optimizer"] = "РћРїС‚РёРјРёР·Р°С‚РѕСЂ",
			["Orbit (anti-median)"] = "РћСЂР±РёС‚Р° (РїСЂРѕС‚РёРІ РјРµРґРёР°РЅС‹)",
			["Orbit"] = "РћСЂР±РёС‚Р°",
			["Orbs"] = "РЎС„РµСЂС‹",
			["Origin"] = "РћС‚РєСѓРґР°",
			["Original"] = "РћСЂРёРіРёРЅР°Р»",
			["Our Discord"] = "РќР°С€ Discord",
			["Outdoor"] = "РЎРЅР°СЂСѓР¶Рё",
			["Outline"] = "РћР±РІРѕРґРєР°",
			["Overcast"] = "РџР°СЃРјСѓСЂРЅРѕ",
			["Overview"] = "РћР±Р·РѕСЂ",
			["Panel color"] = "Р¦РІРµС‚ РїР°РЅРµР»Рё",
			["Panels are floating"] = "РџР°РЅРµР»Рё РѕС‚РєСЂРµРїР»РµРЅС‹",
			["Particles"] = "Р§Р°СЃС‚РёС†С‹",
			["Parts"] = "Р§Р°СЃС‚Рё",
			["Paste Job ID first"] = "РЎРЅР°С‡Р°Р»Р° РІСЃС‚Р°РІСЊ Job ID",
			["Pastel"] = "РџР°СЃС‚РµР»СЊ",
			["Path Finder"] = "РџРѕРёСЃРє РїСѓС‚Рё",
			["Paused"] = "РџР°СѓР·Р°",
			["Pay With"] = "РћРїР»Р°С‚Р°",
			["Performance"] = "РџСЂРѕРёР·РІРѕРґРёС‚РµР»СЊРЅРѕСЃС‚СЊ",
			["Pet ESP"] = "РњРµС‚РєРё РїРёС‚РѕРјС†РµРІ",
			["Pets"] = "РџРёС‚РѕРјС†С‹",
			["Phonk"] = "Р¤РѕРЅРє",
			["Photo Studio"] = "Р¤РѕС‚РѕСЃС‚СѓРґРёСЏ",
			["Photo"] = "Р¤РѕС‚Рѕ",
			["Photoreal"] = "Р¤РѕС‚РѕСЂРµР°Р»РёР·Рј",
			["Pick Up Gun"] = "РџРѕРґР±РёСЂР°С‚СЊ РїРёСЃС‚РѕР»РµС‚",
			["Pick a target (window, frames, toggles, slider), color it with the picker or enable Gradient and color each stop. The menu updates live. Save with a name; custom themes go into your configs too."] = "(,,, )..;.",
			["Picking Gun"] = "РџРѕРґР±РѕСЂ РїРёСЃС‚РѕР»РµС‚Р°",
			["Pickup Distance"] = "Р”РёСЃС‚Р°РЅС†РёСЏ РїРѕРґР±РѕСЂР°",
			["Pin"] = "Р—Р°РєСЂРµРїРёС‚СЊ",
			["Pink"] = "Р РѕР·РѕРІС‹Р№",
			["Pinned"] = "Р—Р°РєСЂРµРїР»С‘РЅ",
			["Pitch"] = "РўРѕРЅ",
			["Plasma"] = "РџР»Р°Р·РјР°",
			["Plastic Materials"] = "РџР»Р°СЃС‚РёРєРѕРІС‹Рµ РјР°С‚РµСЂРёР°Р»С‹",
			["Play For Everyone"] = "Р’РєР»СЋС‡РёС‚СЊ РІСЃРµРј",
			["Play all"] = "РЎР»СѓС€Р°С‚СЊ РІСЃРµ",
			["Play your songs in the round"] = "РўРІРѕСЏ РјСѓР·С‹РєР° РІ СЂР°СѓРЅРґРµ",
			["Player Menu"] = "РњРµРЅСЋ РёРіСЂРѕРєР°",
			["Player not found"] = "РРіСЂРѕРє РЅРµ РЅР°Р№РґРµРЅ",
			["Player"] = "РРіСЂРѕРє",
			["Players ESP"] = "РњРµС‚РєРё РёРіСЂРѕРєРѕРІ",
			["Players"] = "РРіСЂРѕРєРё",
			["Players: %d/%d Ping: %d ms"] = "Players: %d/%d Ping: %d ms",
			["Playing locally: "] = "РРіСЂР°РµС‚ Р»РѕРєР°Р»СЊРЅРѕ: ",
			["Playing"] = "РРіСЂР°РµС‚",
			["Playing. Preloaded clients start instantly."] = "РРіСЂР°РµС‚. РЈ РєРѕРіРѕ РїСЂРµРґР·Р°РіСЂСѓР¶РµРЅРѕ вЂ” РЅР°С‡РЅС‘С‚СЃСЏ СЃСЂР°Р·Сѓ.",
			["Plays the track for everyone, then drops props from the sky."] = "Р’РєР»СЋС‡Р°РµС‚ С‚СЂРµРє РІСЃРµРј, Р·Р°С‚РµРј СЃ РЅРµР±Р° РЅР°С‡РёРЅР°СЋС‚ РїР°РґР°С‚СЊ РїСЂРѕРїС‹.",
			["Point Blank (1 stud)"] = "Р’ СѓРїРѕСЂ (1 СЃС‚Р°Рґ)",
			["Pop"] = "РџРѕРї",
			["Popular"] = "РџРѕРїСѓР»СЏСЂРЅС‹Рµ",
			["Pranks, flings, toys and emotes"] = "РџСЂРёРєРѕР»С‹, С„Р»РёРЅРі, РёРіСЂСѓС€РєРё Рё СЌРјРѕС†РёРё",
			["Prediction (ms)"] = "РџСЂРµРґРёРєС‚ (РјСЃ)",
			["Prediction Lead %"] = "Р›РёРґ РїСЂРµРґРёРєС‚Р° %",
			["Prediction"] = "РћР±РјР°РЅ СѓРїСЂРµР¶РґРµРЅРёСЏ",
			["Preload For Everyone"] = "РџСЂРµРґР·Р°РіСЂСѓР·РёС‚СЊ РІСЃРµРј",
			["Presets"] = "Р“РѕС‚РѕРІС‹Рµ СЃРєРёРЅС‹",
			["Press"] = "РќР°Р¶Р°С‚РёРµ",
			["Preview Kill"] = "РџСЂРѕСЃР»СѓС€Р°С‚СЊ СѓР±РёР№СЃС‚РІРѕ",
			["Preview Roles"] = "РџСЂРѕСЃР»СѓС€Р°С‚СЊ СЂРѕР»Рё",
			["Preview Shot"] = "РџСЂРѕСЃР»СѓС€Р°С‚СЊ РІС‹СЃС‚СЂРµР»",
			["Preview Tracer"] = "РџРѕРєР°Р·Р°С‚СЊ С‚СЂРµР№СЃРµСЂ",
			["Preview Victory"] = "РџСЂРѕСЃР»СѓС€Р°С‚СЊ РїРѕР±РµРґСѓ",
			["Private server"] = "РџСЂРёРІР°С‚РЅС‹Р№ СЃРµСЂРІРµСЂ",
			["Pro Clarity"] = "Р§С‘С‚РєРѕСЃС‚СЊ",
			["Problem? Heh. I'm Trolly, the Pulse Hub guide. Need something?"] = "РџСЂРѕР±Р»РµРјС‹? РҐРµ-С…Рµ. РЇ РўСЂРѕР»Р»Рё, РіРёРґ Pulse Hub. Р§РµРј РїРѕРјРѕС‡СЊ?",
			["Props"] = "РџСЂРµРґРјРµС‚С‹",
			["Protection"] = "Р—Р°С‰РёС‚Р°",
			["Publish config"] = "РџСѓР±Р»РёРєР°С†РёСЏ РєРѕРЅС„РёРіР°",
			["Publish"] = "РћРїСѓР±Р»РёРєРѕРІР°С‚СЊ",
			["Published %d/%d"] = "РћРїСѓР±Р»РёРєРѕРІР°РЅРѕ %d/%d",
			["Published from this device"] = "РћРїСѓР±Р»РёРєРѕРІР°РЅ СЃ СЌС‚РѕРіРѕ СѓСЃС‚СЂРѕР№СЃС‚РІР°",
			["Published"] = "РћРїСѓР±Р»РёРєРѕРІР°РЅРѕ",
			["Publishing is blocked for you"] = "РџСѓР±Р»РёРєР°С†РёСЏ РґР»СЏ С‚РµР±СЏ Р·Р°РєСЂС‹С‚Р°",
			["Pulse (animated)"] = "РџСѓР»СЊСЃ (Р°РЅРёРјР°С†РёСЏ)",
			["Pulse (site)"] = "Pulse (СЃР°Р№С‚)",
			["Pulse Hub for Murder Mystery 2"] = "Pulse Hub РґР»СЏ Murder Mystery 2",
			["Pulse Hub is in beta"] = "Pulse Hub РІ Р±РµС‚Рµ",
			["Pulse Hub is in beta:>"] = "Pulse Hub РІ Р±РµС‚Рµ:>",
			["Pulse Hub was rebuilt almost from scratch: new menu, new aim, new ESP and a pile of new features. Pick a topic!"] = "Pulse Hub РїРµСЂРµРґРµР»Р°РЅ РїРѕС‡С‚Рё СЃ РЅСѓР»СЏ: РЅРѕРІРѕРµ РјРµРЅСЋ, РЅРѕРІС‹Р№ Р°РёРј, РЅРѕРІС‹Р№ ESP Рё РєСѓС‡Р° РЅРѕРІС‹С… С„СѓРЅРєС†РёР№. Р’С‹Р±РёСЂР°Р№ С‚РµРјСѓ!",
			["Pulse Users"] = "Pulse СЋР·РµСЂС‹",
			["Pulse"] = "РџСѓР»СЊСЃ",
			["Purple"] = "Р¤РёРѕР»РµС‚РѕРІС‹Р№",
			["Push Volume Now"] = "РџСЂРёРјРµРЅРёС‚СЊ РіСЂРѕРјРєРѕСЃС‚СЊ",
			["Quality"] = "РљР°С‡РµСЃС‚РІРѕ",
			["Quick Teleport"] = "Р‘С‹СЃС‚СЂС‹Р№ С‚РµР»РµРїРѕСЂС‚",
			["R&B"] = "R&B",
			["RU Rap"] = "Р СѓСЃСЃРєРёР№ СЂСЌРї",
			["Radio not equipped buy & wear the Radio gamepass"] = "Р Р°РґРёРѕ РЅРµ РЅР°РґРµС‚Рѕ вЂ” РєСѓРїРё Рё РЅР°РґРµРЅСЊ РіРµР№РјРїР°СЃСЃ Radio",
			["Radio not equipped"] = "Р Р°РґРёРѕ РЅРµ РЅР°РґРµС‚Рѕ",
			["Rain Count"] = "РЎРєРѕР»СЊРєРѕ С€С‚СѓРє",
			["Rain Delay"] = "Р—Р°РґРµСЂР¶РєР° РїРµСЂРµРґ РґРѕР¶РґС‘Рј",
			["Rain Lifetime"] = "РЎРєРѕР»СЊРєРѕ РІРёСЃСЏС‚",
			["Rain Party"] = "Р”РѕР¶РґСЊ",
			["Rain Preload Wait"] = "РћР¶РёРґР°РЅРёРµ Р·Р°РіСЂСѓР·РєРё",
			["Rain Size"] = "Р Р°Р·РјРµСЂ",
			["Rain effect is not loaded."] = "Р­С„С„РµРєС‚ РґРѕР¶РґСЏ РЅРµ Р·Р°РіСЂСѓР¶РµРЅ.",
			["Rain started for you. Others need the admin secret."] = "РЈ С‚РµР±СЏ Р·Р°РїСѓС‰РµРЅРѕ. Р”Р»СЏ РѕСЃС‚Р°Р»СЊРЅС‹С… РЅСѓР¶РµРЅ СЃРµРєСЂРµС‚ Р°РґРјРёРЅР°.",
			["Rain"] = "РљР°РїР»Рё",
			["Rainbow Tracers"] = "Р Р°РґСѓР¶РЅС‹Рµ С‚СЂРµР№СЃРµСЂС‹",
			["Rainbow"] = "Р Р°РґСѓРіР°",
			["Rainy Night"] = "Р”РѕР¶РґР»РёРІР°СЏ РЅРѕС‡СЊ",
			["Random song each round"] = "РЎР»СѓС‡Р°Р№РЅС‹Р№ С‚СЂРµРє РєР°Р¶РґС‹Р№ СЂР°СѓРЅРґ",
			["Random"] = "РЎР»СѓС‡Р°Р№РЅРѕ",
			["Rarity"] = "Р РµРґРєРѕСЃС‚СЊ",
			["Rate this config"] = "РћС†РµРЅРё РєРѕРЅС„РёРі",
			["Rate"] = "РЎРєРѕСЂРѕСЃС‚СЊ",
			["Rating saved"] = "РћС†РµРЅРєР° СЃРѕС…СЂР°РЅРµРЅР°",
			["Ray intensity"] = "РЎРёР»Р° Р»СѓС‡РµР№",
			["Ray spread"] = "Р Р°Р·Р±СЂРѕСЃ Р»СѓС‡РµР№",
			["Re-run the loader and make sure your executor is up to date. Still nothing? Open a ticket in our Discord with a screenshot of the F9 console."] = "РџРµСЂРµР·Р°РїСѓСЃС‚Рё Р»РѕР°РґРµСЂ Рё РїСЂРѕРІРµСЂСЊ, С‡С‚Рѕ СЌРєР·РµРєСѓС‚РѕСЂ РѕР±РЅРѕРІР»С‘РЅ. РќРµ РїРѕРјРѕРіР»Рѕ? РћС‚РєСЂРѕР№ С‚РёРєРµС‚ РІ РЅР°С€РµРј Discord Рё РїСЂРёР»РѕР¶Рё СЃРєСЂРёРЅ РєРѕРЅСЃРѕР»Рё F9.",
			["React"] = "Р РµР°РєС†РёСЏ",
			["Reaction failed"] = "Р РµР°РєС†РёСЏ РЅРµ РїРѕСЃС‚Р°РІР»РµРЅР°",
			["Ready"] = "Р“РѕС‚РѕРІ",
			["Real weapon"] = "РќР°СЃС‚РѕСЏС‰РµРµ РѕСЂСѓР¶РёРµ",
			["Real weapons back"] = "РќР°СЃС‚РѕСЏС‰РµРµ РѕСЂСѓР¶РёРµ РІРѕР·РІСЂР°С‰РµРЅРѕ",
			["Realistic Brightness"] = "Р РµР°Р»РёСЃС‚РёС‡РЅС‹Р№: СЏСЂРєРѕСЃС‚СЊ",
			["Realistic Exposure"] = "Р РµР°Р»РёСЃС‚РёС‡РЅС‹Р№: СЌРєСЃРїРѕР·РёС†РёСЏ",
			["Realistic Haze"] = "Р РµР°Р»РёСЃС‚РёС‡РЅС‹Р№: РїР»РѕС‚РЅРѕСЃС‚СЊ РґС‹РјРєРё",
			["Realistic Time"] = "Р РµР°Р»РёСЃС‚РёС‡РЅС‹Р№: РІСЂРµРјСЏ СЃСѓС‚РѕРє",
			["Realistic"] = "Р РµР°Р»РёСЃС‚РёС‡РЅС‹Р№",
			["Recent"] = "РќРµРґР°РІРЅРёРµ",
			["Red"] = "РљСЂР°СЃРЅС‹Р№",
			["Reflections"] = "РћС‚СЂР°Р¶РµРЅРёСЏ",
			["Rejoin Server"] = "РџРµСЂРµР·Р°Р№С‚Рё РЅР° СЃРµСЂРІРµСЂ",
			["Rejoin"] = "РџРµСЂРµР·Р°Р№С‚Рё",
			["Rejoin, hop and server info"] = "РџРµСЂРµР·Р°С…РѕРґ, СЃРјРµРЅР° Рё РёРЅС„Рѕ СЃРµСЂРІРµСЂР°",
			["Rejoining..."] = "РџРµСЂРµР·Р°С…РѕРґ...",
			["Remove Particles/Effects"] = "РЈР±СЂР°С‚СЊ С‡Р°СЃС‚РёС†С‹/СЌС„С„РµРєС‚С‹",
			["Remove Reflections"] = "РЈР±РёСЂР°С‚СЊ РѕС‚СЂР°Р¶РµРЅРёСЏ",
			["Remove Skin"] = "РЎРЅСЏС‚СЊ СЃРєРёРЅ",
			["Remove Textures"] = "РЈР±СЂР°С‚СЊ С‚РµРєСЃС‚СѓСЂС‹",
			["Remove all"] = "РЎРЅСЏС‚СЊ РІСЃРµ",
			["Removed"] = "РЈРґР°Р»РµРЅРѕ",
			["Render distance"] = "Р”РёСЃС‚Р°РЅС†РёСЏ РѕС‚СЂРёСЃРѕРІРєРё",
			["Repeat"] = "РџРѕРІС‚РѕСЂ",
			["Reply to you"] = "РћС‚РІРµС‚ РІР°Рј",
			["Reply"] = "РћС‚РІРµС‚РёС‚СЊ",
			["Replying to"] = "РћС‚РІРµС‚ РґР»СЏ",
			["Report sent"] = "Р–Р°Р»РѕР±Р° РѕС‚РїСЂР°РІР»РµРЅР°",
			["Report"] = "РџРѕР¶Р°Р»РѕРІР°С‚СЊСЃСЏ",
			["Reset All Settings"] = "РЎР±СЂРѕСЃРёС‚СЊ РІСЃРµ РЅР°СЃС‚СЂРѕР№РєРё",
			["Reset To Real"] = "Р’РµСЂРЅСѓС‚СЊ РЅР°СЃС‚РѕСЏС‰РµРµ РѕСЂСѓР¶РёРµ",
			["Reset UIS Position"] = "РЎР±СЂРѕСЃРёС‚СЊ РїРѕР·РёС†РёСЋ UIS",
			["Reset all settings?"] = "РЎР±СЂРѕСЃРёС‚СЊ РІСЃРµ РЅР°СЃС‚СЂРѕР№РєРё?",
			["Reset appearance"] = "РЎР±СЂРѕСЃРёС‚СЊ РІРЅРµС€РЅРёР№ РІРёРґ",
			["Reset done"] = "РЎР±СЂРѕСЃ РІС‹РїРѕР»РЅРµРЅ",
			["Reset to default animations"] = "РЎР±СЂРѕСЃРёС‚СЊ РЅР° СЃС‚Р°РЅРґР°СЂС‚РЅС‹Рµ Р°РЅРёРјР°С†РёРё",
			["Reset"] = "РЎР±СЂРѕСЃРёС‚СЊ",
			["Resolver"] = "Resolver",
			["Restore original color"] = "Р’РµСЂРЅСѓС‚СЊ РёСЃС…РѕРґРЅС‹Р№ С†РІРµС‚",
			["Restore"] = "Р’РµСЂРЅСѓС‚СЊ",
			["Results"] = "РќР°Р№РґРµРЅРѕ",
			["Retro"] = "Р РµС‚СЂРѕ",
			["Retrowave"] = "Р РµС‚СЂРѕРІРµР№РІ",
			["Return to window"] = "Р’РµСЂРЅСѓС‚СЊ РІ РѕРєРЅРѕ",
			["Reverb"] = "Р РµРІРµСЂР±",
			["Ribbon Aura"] = "РђСѓСЂР°: Р›РµРЅС‚С‹",
			["Ring"] = "РљРѕР»СЊС†Рѕ",
			["Rings"] = "РљРѕР»СЊС†Р°",
			["Roblox did not respond to the teleport"] = "Roblox РЅРµ РѕС‚РІРµС‚РёР» РЅР° С‚РµР»РµРїРѕСЂС‚ (СЌРєР·РµРєСѓС‚РѕСЂ РіР»СѓС€РёС‚ РІС‹Р·РѕРІ)",
			["Roblox replied"] = "РћС‚РІРµС‚ Roblox",
			["Robot"] = "Р РѕР±РѕС‚",
			["Rock"] = "Р РѕРє",
			["Role ESP Style"] = "РЎС‚РёР»СЊ ESP СЂРѕР»РµР№",
			["Role ESP"] = "ESP СЂРѕР»РµР№",
			["Role Farm"] = "Р¤Р°СЂРј СЂРѕР»РµР№",
			["Role Reveal Sound"] = "Р—РІСѓРє РІС‹РґР°С‡Рё СЂРѕР»Рё",
			["Role Roll Sound"] = "Р—РІСѓРє СЂСѓР»РµС‚РєРё СЂРѕР»РµР№",
			["Role"] = "Р РѕР»СЊ",
			["Royal Blue"] = "РљРѕСЂРѕР»РµРІСЃРєРёР№",
			["Run"] = "Р‘РµРі",
			["Sakura Aura"] = "РђСѓСЂР°: РЎР°РєСѓСЂР°",
			["Sandstorm"] = "РџРµСЃС‡Р°РЅР°СЏ Р±СѓСЂСЏ",
			["Saturation"] = "РќР°СЃС‹С‰РµРЅРЅРѕСЃС‚СЊ",
			["Save Secret"] = "РЎРѕС…СЂР°РЅРёС‚СЊ СЃРµРєСЂРµС‚",
			["Save Theme"] = "РЎРѕС…СЂР°РЅРёС‚СЊ С‚РµРјСѓ",
			["Save current"] = "РЎРѕС…СЂР°РЅРёС‚СЊ С‚РµРєСѓС‰РёРµ",
			["Saved bundles & emotes. Apply to use, to remove."] = "РЎРѕС…СЂР°РЅС‘РЅРЅС‹Рµ Р±Р°РЅРґР»С‹ Рё СЌРјРѕС†РёРё. Apply вЂ” РїСЂРёРјРµРЅРёС‚СЊ, РєСЂРµСЃС‚РёРє вЂ” СѓРґР°Р»РёС‚СЊ.",
			["Saved"] = "РР·Р±СЂР°РЅРЅРѕРµ",
			["Screen Blur"] = "Р Р°Р·РјС‹С‚РёРµ СЌРєСЂР°РЅР°",
			["Screen Stretch"] = "Р Р°СЃС‚СЏР¶РµРЅРёРµ СЌРєСЂР°РЅР°",
			["Screen"] = "Р­РєСЂР°РЅ",
			["Script won't load"] = "РЎРєСЂРёРїС‚ РЅРµ Р·Р°РїСѓСЃРєР°РµС‚СЃСЏ",
			["Search SoundCloud or paste a link"] = "РџРѕРёСЃРє SoundCloud РёР»Рё СЃСЃС‹Р»РєР°",
			["Search auras"] = "РџРѕРёСЃРє Р°СѓСЂ",
			["Search configs  В·  %d"] = "РџРѕРёСЃРє РєРѕРЅС„РёРіРѕРІ  В·  %d",
			["Search configs or players"] = "РџРѕРёСЃРє РєРѕРЅС„РёРіРѕРІ Рё РёРіСЂРѕРєРѕРІ",
			["Search player"] = "РџРѕРёСЃРє РёРіСЂРѕРєР°",
			["Search skins"] = "РџРѕРёСЃРє СЃРєРёРЅР°",
			["Search"] = "РџРѕРёСЃРє",
			["Search..."] = "РџРѕРёСЃРє...",
			["Searching"] = "РџРѕРёСЃРє",
			["Searching..."] = "РС‰Сѓ СЃРµСЂРІРµСЂ...",
			["Secret removed from this machine."] = "РЎРµРєСЂРµС‚ СѓРґР°Р»С‘РЅ СЃ СЌС‚РѕРіРѕ СѓСЃС‚СЂРѕР№СЃС‚РІР°.",
			["Seeds"] = "РЎРµРјРµРЅР°",
			["Select All"] = "Р’С‹Р±СЂР°С‚СЊ РІСЃС‘",
			["Select Player"] = "Р’С‹Р±СЂР°С‚СЊ РёРіСЂРѕРєР°",
			["Select"] = "Р’С‹Р±СЂР°С‚СЊ",
			["Selected"] = "Р’С‹Р±СЂР°РЅ",
			["Selected: none"] = "Р’С‹Р±СЂР°РЅ: РЅРёРєС‚Рѕ",
			["Self Chams"] = "Р§Р°РјСЃС‹ РЅР° СЃРµР±СЏ",
			["Sell when count >="] = "РџСЂРѕРґР°РІР°С‚СЊ РєРѕРіРґР° РєРѕР»-РІРѕ >=",
			["Send Broadcast"] = "РћС‚РїСЂР°РІРёС‚СЊ РѕР±СЉСЏРІР»РµРЅРёРµ",
			["Sent to every Pulse user online. The backend decides who may send."] = "РЈР№РґС‘С‚ РІСЃРµРј Pulse-СЋР·РµСЂР°Рј РѕРЅР»Р°Р№РЅ. РљРѕРјСѓ РјРѕР¶РЅРѕ РѕС‚РїСЂР°РІР»СЏС‚СЊ вЂ” СЂРµС€Р°РµС‚ СЃРµСЂРІРµСЂ.",
			["Server Hop"] = "РЎРјРµРЅР° СЃРµСЂРІРµСЂР°",
			["Server Info"] = "РРЅС„Рѕ СЃРµСЂРІРµСЂР°",
			["Server busy, try again"] = "РЎРµСЂРІРµСЂ Р·Р°РЅСЏС‚, РїРѕРїСЂРѕР±СѓР№ РµС‰С‘ СЂР°Р·",
			["Server is full"] = "РЎРµСЂРІРµСЂ Р·Р°РїРѕР»РЅРµРЅ",
			["Server unavailable"] = "РЎРµСЂРІРµСЂ РЅРµРґРѕСЃС‚СѓРїРµРЅ",
			["Server"] = "РЎРµСЂРІРµСЂ",
			["Servers"] = "РЎРµСЂРІРµСЂС‹",
			["Servers: %d"] = "РЎРµСЂРІРµСЂРѕРІ: %d",
			["Session"] = "РЎРµСЃСЃРёСЏ",
			["Settings reset"] = "РќР°СЃС‚СЂРѕР№РєРё СЃР±СЂРѕС€РµРЅС‹",
			["Settings"] = "РќР°СЃС‚СЂРѕР№РєРё",
			["Shaded"] = "Р’ С‚РµРЅРё",
			["Shader Packs"] = "РЁРµР№РґРµСЂ-РїР°РєРё",
			["Shaders"] = "РЁРµР№РґРµСЂС‹",
			["Shards"] = "РћСЃРєРѕР»РєРё",
			["Sharp zone"] = "Р—РѕРЅР° СЂРµР·РєРѕСЃС‚Рё",
			["Sheriff Win Farm"] = "Р¤Р°СЂРј РїРѕР±РµРґ Р·Р° С€РµСЂРёС„Р°",
			["Sheriff"] = "РЁРµСЂРёС„",
			["Shoot Murderer on full bag"] = "РЈР±РёС‚СЊ РјР°СЂРґРµСЂР° РїСЂРё РїРѕР»РЅРѕРј РјРµС€РєРµ",
			["Shooting"] = "РЎС‚СЂРµР»СЊР±Р°",
			["Shot Murder Button"] = "РљРЅРѕРїРєР° РІС‹СЃС‚СЂРµР»Р° РІ РјР°СЂРґРµСЂР°",
			["Shot Murder"] = "Р’С‹СЃС‚СЂРµР» РІ РјР°СЂРґРµСЂР°",
			["Shot Sound"] = "Р—РІСѓРє РІС‹СЃС‚СЂРµР»Р°",
			["Shot Timing"] = "Р’СЂРµРјСЏ РІС‹СЃС‚СЂРµР»Р°",
			["Show Animation"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ Р°РЅРёРјР°С†РёСЋ",
			["Show Aura Ring"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РєСЂСѓРі Р°СѓСЂС‹",
			["Show FOV Circle"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РєСЂСѓРі FOV",
			["Show FPS / Ping"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ FPS / РїРёРЅРі",
			["Show Hero"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РіРµСЂРѕСЏ",
			["Show Innocent"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РјРёСЂРЅС‹С…",
			["Show Keybinds"] = "РџРѕРєР°Р·Р°С‚СЊ РєРµР№Р±РёРЅРґС‹",
			["Show Murderer"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ СѓР±РёР№С†Сѓ",
			["Show Nickname"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РЅРёРє",
			["Show Other Shots"] = "Р’С‹СЃС‚СЂРµР»С‹ РґСЂСѓРіРёС…",
			["Show Ping/Fps UI"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ Ping/FPS",
			["Show Role Text"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ СЂРѕР»СЊ",
			["Show Sheriff"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ С€РµСЂРёС„Р°",
			["Show Studs"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ СЂР°СЃСЃС‚РѕСЏРЅРёРµ",
			["Show despawn timer"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ С‚Р°Р№РјРµСЂ РёСЃС‡РµР·РЅРѕРІРµРЅРёСЏ",
			["Show distance"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РґРёСЃС‚Р°РЅС†РёСЋ",
			["Show more"] = "РџРѕРєР°Р·Р°С‚СЊ РµС‰С‘",
			["Show mutation"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РјСѓС‚Р°С†РёСЋ",
			["Show name"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РЅРёРє",
			["Show price"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ С†РµРЅСѓ",
			["Show sell value"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ С†РµРЅСѓ РїСЂРѕРґР°Р¶Рё",
			["Show weight"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ РІРµСЃ",
			["Shuffle"] = "РџРµСЂРµРјРµС€Р°С‚СЊ",
			["Side Profile"] = "Р‘РѕРєРѕРј Рє РІСЂР°РіСѓ",
			["Sidebar density"] = "РџР»РѕС‚РЅРѕСЃС‚СЊ РїР°РЅРµР»Рё",
			["Sidebar width"] = "РЁРёСЂРёРЅР° РїР°РЅРµР»Рё",
			["Silence"] = "РўРёС€РёРЅР°",
			["Silent Aim"] = "РЎР°Р№Р»РµРЅС‚ Р°РёРј",
			["Silent Aim: executor has no hooks. Use Auto Shoot."] = "РЎР°Р№Р»РµРЅС‚ Р°РёРј: Сѓ СЌРєР·РµРєСѓС‚РѕСЂР° РЅРµС‚ С…СѓРєРѕРІ. Р’РєР»СЋС‡Рё РђРІС‚Рѕ СЃС‚СЂРµР»СЊР±Сѓ.",
			["Silent Aim: limited mode (V2 only, no Wallbang)"] = "РЎР°Р№Р»РµРЅС‚ Р°РёРј: РѕРіСЂР°РЅРёС‡РµРЅРЅС‹Р№ СЂРµР¶РёРј (С‚РѕР»СЊРєРѕ V2, Р±РµР· В«РЎРєРІРѕР·СЊ СЃС‚РµРЅС‹В»)",
			["Silent Fog"] = "РўРёС…РёР№ С‚СѓРјР°РЅ",
			["Silent aim, aimbot and gun tools"] = "РЎР°Р№Р»РµРЅС‚ Р°РёРј, Р°РёРјР±РѕС‚ Рё РїРёСЃС‚РѕР»РµС‚",
			["Simple Players"] = "РџСЂРѕСЃС‚С‹Рµ РёРіСЂРѕРєРё",
			["Size"] = "Р Р°Р·РјРµСЂ",
			["Skeleton Brightness"] = "РЇСЂРєРѕСЃС‚СЊ СЃРєРµР»РµС‚Р°",
			["Skeleton Color"] = "Р¦РІРµС‚ СЃРєРµР»РµС‚Р°",
			["Skeleton ESP"] = "РЎРєРµР»РµС‚",
			["Skeleton Own Color"] = "РЎРІРѕР№ С†РІРµС‚ СЃРєРµР»РµС‚Р°",
			["Skeleton Saturation"] = "РќР°СЃС‹С‰РµРЅРЅРѕСЃС‚СЊ СЃРєРµР»РµС‚Р°",
			["Skies"] = "РќРµР±Рѕ",
			["Skin Catalog"] = "РљР°С‚Р°Р»РѕРі СЃРєРёРЅРѕРІ",
			["Skin equipped"] = "РЎРєРёРЅ РЅР°РґРµС‚",
			["Skin on"] = "РЎРєРёРЅ РЅР°РґРµС‚",
			["Skin removed"] = "РЎРєРёРЅ СЃРЅСЏС‚",
			["Skin"] = "РЎРєРёРЅ",
			["Skins & effects"] = "РЎРєРёРЅС‹ Рё СЌС„С„РµРєС‚С‹",
			["Skins"] = "РЎРєРёРЅС‹",
			["Skulls"] = "Р§РµСЂРµРїР°",
			["Sky details"] = "Р”РµС‚Р°Р»Рё РЅРµР±Р°",
			["Sky"] = "Р’ РЅРµР±Рѕ",
			["Skybox"] = "РЎРєР°Р№Р±РѕРєСЃ",
			["Slider Fill"] = "Р—Р°Р»РёРІРєР° СЃР»Р°Р№РґРµСЂР°",
			["Smart Pause"] = "РЈРјРЅР°СЏ РїР°СѓР·Р°",
			["Smoke"] = "Р”С‹Рј",
			["Snow"] = "РЎРЅРµРі",
			["Soft shadows"] = "РњСЏРіРєРёРµ С‚РµРЅРё",
			["Softness"] = "РњСЏРіРєРѕСЃС‚СЊ",
			["Something else"] = "Р”СЂСѓРіРѕРµ",
			["Sound ID + name, then tap  +"] = "ID Р·РІСѓРєР° + РЅР°Р·РІР°РЅРёРµ, РїРѕС‚РѕРј Р¶РјРё  +",
			["Sound ID or link"] = "ID РёР»Рё СЃСЃС‹Р»РєР° РЅР° Р·РІСѓРє",
			["Sound Volume"] = "Р“СЂРѕРјРєРѕСЃС‚СЊ Р·РІСѓРєРѕРІ",
			["Sound volume"] = "Р“СЂРѕРјРєРѕСЃС‚СЊ Р·РІСѓРєРѕРІ",
			["SoundCloud is turned off"] = "SoundCloud РІСЂРµРјРµРЅРЅРѕ РІС‹РєР»СЋС‡РµРЅ",
			["SoundCloud key not found - their site layout changed."] = "РљР»СЋС‡ SoundCloud РЅРµ РЅР°Р№РґРµРЅ вЂ” Сѓ РЅРёС… РїРѕРјРµРЅСЏР»Р°СЃСЊ РІС‘СЂСЃС‚РєР°.",
			["SoundCloud: getting the key..."] = "SoundCloud: РїРѕР»СѓС‡Р°СЋ РєР»СЋС‡...",
			["SoundCloud: resolving the track..."] = "SoundCloud: РёС‰Сѓ С‚СЂРµРє...",
			["Sounds"] = "Р—РІСѓРєРё",
			["Spectating"] = "РќР°Р±Р»СЋРґР°СЋ",
			["Speed & Jump"] = "РЎРєРѕСЂРѕСЃС‚СЊ Рё РїСЂС‹Р¶РѕРє",
			["Speed (delay, 0 = max)"] = "РЎРєРѕСЂРѕСЃС‚СЊ (Р·Р°РґРµСЂР¶РєР°, 0 = РјР°РєСЃ)",
			["Speed Glitch"] = "РЎРїРёРґ РіР»РёС‚С‡",
			["Speed Hack"] = "РЈСЃРєРѕСЂРµРЅРёРµ",
			["Speed Method"] = "РЎРїРѕСЃРѕР± СЃРєРѕСЂРѕСЃС‚Рё",
			["Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ",
			["Spin + Float"] = "Р’СЂР°С‰РµРЅРёРµ + РїР°СЂРµРЅРёРµ",
			["Spin Key"] = "Spin",
			["Spin Mode"] = "Р РµР¶РёРј РєСЂСѓС‚РёР»РєРё",
			["Spin Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ РєСЂСѓС‚РёР»РєРё",
			["Spin"] = "Р’СЂР°С‰РµРЅРёРµ",
			["Spoof Move Direction"] = "РџРѕРґРјРµРЅР° РЅР°РїСЂР°РІР»РµРЅРёСЏ",
			["Spoof Strength"] = "РЎРёР»Р° РїРѕРґРјРµРЅС‹",
			["Spoof Velocity"] = "РџРѕРґРјРµРЅР° СЃРєРѕСЂРѕСЃС‚Рё",
			["Star Aura"] = "РђСѓСЂР°: Р—РІРµР·РґР°",
			["Star count"] = "РљРѕР»РёС‡РµСЃС‚РІРѕ Р·РІС‘Р·Рґ",
			["Stardust"] = "Р—РІС‘Р·РґРЅР°СЏ РїС‹Р»СЊ",
			["Starlight Aura"] = "РђСѓСЂР°: Р—РІС‘Р·РґРЅС‹Р№ СЃРІРµС‚",
			["Stars"] = "Р—РІС‘Р·РґС‹",
			["Start Rain Party"] = "Р—Р°РїСѓСЃС‚РёС‚СЊ РґРѕР¶РґСЊ",
			["Static (max offset)"] = "РЎС‚Р°С‚РёРєР° (РјР°РєСЃ. СЃРјРµС‰РµРЅРёРµ)",
			["Stats"] = "РЎС‚Р°С‚РёСЃС‚РёРєР°",
			["Status"] = "РЎС‚Р°С‚СѓСЃ",
			["Stop Animations (others)"] = "РЎС‚РѕРїРёС‚СЊ Р°РЅРёРјР°С†РёРё (РґСЂСѓРіРёС…)",
			["Stop For Everyone"] = "РћСЃС‚Р°РЅРѕРІРёС‚СЊ Сѓ РІСЃРµС…",
			["Stop Rain"] = "РћСЃС‚Р°РЅРѕРІРёС‚СЊ РґРѕР¶РґСЊ",
			["Stop emote"] = "РћСЃС‚Р°РЅРѕРІРёС‚СЊ СЌРјРѕС†РёСЋ",
			["Stopped"] = "РћСЃС‚Р°РЅРѕРІР»РµРЅРѕ",
			["Stopped."] = "РћСЃС‚Р°РЅРѕРІР»РµРЅРѕ.",
			["Stopped: "] = "РћСЃС‚Р°РЅРѕРІР»РµРЅРѕ: ",
			["Strength"] = "РЎРёР»Р°",
			["Studio Brightness"] = "РЎС‚СѓРґРёСЏ: СЏСЂРєРѕСЃС‚СЊ",
			["Studio Haze"] = "РЎС‚СѓРґРёСЏ: РїР»РѕС‚РЅРѕСЃС‚СЊ РґС‹РјРєРё",
			["Studio Hour"] = "РЎС‚СѓРґРёСЏ: РІСЂРµРјСЏ СЃСѓС‚РѕРє",
			["Studio Light"] = "РЎС‚СѓРґРёСЏ: СЃРІРµС‚",
			["Studio Mist"] = "РЎС‚СѓРґРёСЏ: РґС‹РјРєР°",
			["Studio Time"] = "РЎС‚СѓРґРёСЏ: РІСЂРµРјСЏ СЃСѓС‚РѕРє",
			["Style"] = "РЎС‚РёР»СЊ",
			["Summer"] = "Р›РµС‚Рѕ",
			["Sun & moon"] = "РЎРѕР»РЅС†Рµ Рё Р»СѓРЅР°",
			["Sun Rays"] = "Р›СѓС‡Рё СЃРѕР»РЅС†Р°",
			["Sun angle"] = "РЈРіРѕР» СЃРѕР»РЅС†Р°",
			["Sun glare"] = "Р‘Р»РёРє СЃРѕР»РЅС†Р°",
			["Sun rays"] = "РЎРѕР»РЅРµС‡РЅС‹Рµ Р»СѓС‡Рё",
			["Sun size"] = "Р Р°Р·РјРµСЂ СЃРѕР»РЅС†Р°",
			["Sunlit"] = "РќР° СЃРІРµС‚Сѓ",
			["Sunrise"] = "Р Р°СЃСЃРІРµС‚",
			["Sunset"] = "Р—Р°РєР°С‚",
			["Sure?"] = "РўРѕС‡РЅРѕ?",
			["Surviving"] = "Р’С‹Р¶РёРІР°РЅРёРµ",
			["Sway"] = "РџРѕРєР°С‡РёРІР°РЅРёРµ",
			["Swim"] = "РџР»Р°РІР°РЅРёРµ",
			["System"] = "РЎРёСЃС‚РµРјР°",
			["TP Player"] = "РўРџ Рє РёРіСЂРѕРєСѓ",
			["TP Role"] = "РўРџ Рє СЂРѕР»Рё",
			["Tags"] = "РўРµРіРё",
			["Tail Color"] = "Р¦РІРµС‚ С…РІРѕСЃС‚Р°",
			["Talk with other Pulse users"] = "РћР±С‰РµРЅРёРµ СЃ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏРјРё Pulse",
			["Talk"] = "РџРѕРіРѕРІРѕСЂРёС‚СЊ",
			["Tantrum"] = "РСЃС‚РµСЂРёРєР°",
			["Tap a link to copy it"] = "РќР°Р¶РјРё РЅР° СЃСЃС‹Р»РєСѓ, С‡С‚РѕР±С‹ СЃРєРѕРїРёСЂРѕРІР°С‚СЊ",
			["Tap a player to fling them"] = "РќР°Р¶РјРё РЅР° РёРіСЂРѕРєР° С‡С‚РѕР±С‹ РµРіРѕ С„Р»РёРЅРіР°РЅСѓС‚СЊ",
			["Targets"] = "Р¦РµР»Рё",
			["Teleport Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ С‚РµР»РµРїРѕСЂС‚Р°",
			["Teleport failed"] = "РўРµР»РµРїРѕСЂС‚ РЅРµ СѓРґР°Р»СЃСЏ",
			["Teleport failed: %s"] = "РўРµР»РµРїРѕСЂС‚ РЅРµ СѓРґР°Р»СЃСЏ: %s",
			["Teleport to Player"] = "РўРµР»РµРїРѕСЂС‚ Рє РёРіСЂРѕРєСѓ",
			["Teleport to garden (collect range)"] = "РўРµР»РµРїРѕСЂС‚ РІ СЃР°Рґ (СЂР°РґРёСѓСЃ СЃР±РѕСЂР°)",
			["Teleport"] = "РўРµР»РµРїРѕСЂС‚",
			["Teleporting"] = "РўРµР»РµРїРѕСЂС‚",
			["Tell me what's wrong and I'll point you the right way."] = "Р Р°СЃСЃРєР°Р·С‹РІР°Р№, С‡С‚Рѕ СЃР»СѓС‡РёР»РѕСЃСЊ, РїРѕРґСЃРєР°Р¶Сѓ, РєСѓРґР° РёРґС‚Рё.",
			["Test Rain (me only)"] = "РџСЂРѕРІРµСЂРёС‚СЊ РґРѕР¶РґСЊ (С‚РѕР»СЊРєРѕ СЃРµР±Рµ)",
			["Text size"] = "Р Р°Р·РјРµСЂ С‚РµРєСЃС‚Р°",
			["Text"] = "РўРµРєСЃС‚",
			["That's the big stuff! Small fixes and every next update land in our Discord first. Problem?"] = "Р­С‚Рѕ РіР»Р°РІРЅРѕРµ! РњРµР»РєРёРµ С„РёРєСЃС‹ Рё РєР°Р¶РґРѕРµ СЃР»РµРґСѓСЋС‰РµРµ РѕР±РЅРѕРІР»РµРЅРёРµ РїРµСЂРІС‹РјРё РїРѕСЏРІР»СЏСЋС‚СЃСЏ РІ РЅР°С€РµРј Discord. РџСЂРѕР±Р»РµРјС‹?",
			["The new Nova menu: themes, glass, sizes, keybind list and floating cards. Pulse Chat with replies and reactions, Pulse Users to jump into other Pulse players' servers, Config Hub to share configs, owner and admin tags, map vote boost, a music player, game sounds and victory music."] = "РќРѕРІРѕРµ РјРµРЅСЋ Nova: С‚РµРјС‹, СЃС‚РµРєР»Рѕ, СЂР°Р·РјРµСЂС‹, СЃРїРёСЃРѕРє Р±РёРЅРґРѕРІ Рё РїР»Р°РІР°СЋС‰РёРµ РєР°СЂС‚РѕС‡РєРё. Pulse Chat СЃ РѕС‚РІРµС‚Р°РјРё Рё СЂРµР°РєС†РёСЏРјРё, Pulse Users, С‡С‚РѕР±С‹ Р·Р°С…РѕРґРёС‚СЊ РЅР° СЃРµСЂРІРµСЂС‹ Рє РґСЂСѓРіРёРј Pulse СЋР·РµСЂР°Рј, Config Hub РґР»СЏ РѕР±РјРµРЅР° РєРѕРЅС„РёРіР°РјРё, РјРµС‚РєРё РІР»Р°РґРµР»СЊС†Р° Рё Р°РґРјРёРЅР°, Р±СѓСЃС‚ РіРѕР»РѕСЃРѕРІР°РЅРёСЏ Р·Р° РєР°СЂС‚Сѓ, РјСѓР·С‹РєР°Р»СЊРЅС‹Р№ РїР»РµРµСЂ, Р·РІСѓРєРё РёРіСЂС‹ Рё РїРѕР±РµРґРЅР°СЏ РјСѓР·С‹РєР°.",
			["Theme Creator"] = "РљРѕРЅСЃС‚СЂСѓРєС‚РѕСЂ С‚РµРј",
			["Theme"] = "РўРµРјР°",
			["This config is already published"] = "Р­С‚РѕС‚ РєРѕРЅС„РёРі СѓР¶Рµ РѕРїСѓР±Р»РёРєРѕРІР°РЅ",
			["This function is not finished yet."] = "Р­С‚Р° С„СѓРЅРєС†РёСЏ РµС‰С‘ РЅРµ РґРѕРґРµР»Р°РЅР°.",
			["This is a WAV. Roblox wants mp3 or ogg."] = "Р­С‚Рѕ WAV. Roblox РїСЂРёРЅРёРјР°РµС‚ mp3 РёР»Рё ogg.",
			["This is a web page, not a file. Use the direct file link."] = "Р­С‚Рѕ РІРµР±-СЃС‚СЂР°РЅРёС†Р°, Р° РЅРµ С„Р°Р№Р». РќСѓР¶РЅР° РїСЂСЏРјР°СЏ СЃСЃС‹Р»РєР° РЅР° С„Р°Р№Р».",
			["Throw Knife"] = "Р‘СЂРѕСЃРёС‚СЊ РЅРѕР¶",
			["Time of day"] = "Р’СЂРµРјСЏ СЃСѓС‚РѕРє",
			["Tint"] = "РћС‚С‚РµРЅРѕРє",
			["Title"] = "РќР°Р·РІР°РЅРёРµ",
			["Title: 3-32 characters"] = "РќР°Р·РІР°РЅРёРµ: 3-32 СЃРёРјРІРѕР»Р°",
			["Today"] = "РЎРµРіРѕРґРЅСЏ",
			["Toggle Menu"] = "РћС‚РєСЂС‹С‚СЊ/Р·Р°РєСЂС‹С‚СЊ РјРµРЅСЋ",
			["Toggle OFF"] = "РўСѓРјР±Р»РµСЂ Р’Р«РљР›",
			["Toggle ON"] = "РўСѓРјР±Р»РµСЂ Р’РљР›",
			["Toggle it off and on again and check its settings. Still broken? Send a short video in our Discord and we'll fix it fast."] = "Р’С‹РєР»СЋС‡Рё Рё РІРєР»СЋС‡Рё РµС‘ Р·Р°РЅРѕРІРѕ Рё РїСЂРѕРІРµСЂСЊ РЅР°СЃС‚СЂРѕР№РєРё. Р’СЃС‘ РµС‰С‘ СЃР»РѕРјР°РЅРѕ? РЎРєРёРЅСЊ РєРѕСЂРѕС‚РєРѕРµ РІРёРґРµРѕ РІ РЅР°С€ Discord, РїРѕС‡РёРЅРёРј Р±С‹СЃС‚СЂРѕ.",
			["Tone mapping"] = "РўРѕРЅРјР°РїРїРёРЅРі",
			["Too fast"] = "РЎР»РёС€РєРѕРј С‡Р°СЃС‚Рѕ",
			["Too many requests"] = "РЎР»РёС€РєРѕРј РјРЅРѕРіРѕ Р·Р°РїСЂРѕСЃРѕРІ",
			["Too many requests, try later"] = "РЎР»РёС€РєРѕРј С‡Р°СЃС‚Рѕ, РїРѕРїСЂРѕР±СѓР№ РїРѕР·Р¶Рµ",
			["Too short - that does not look like the secret."] = "РЎР»РёС€РєРѕРј РєРѕСЂРѕС‚РєРѕ вЂ” РЅРµ РїРѕС…РѕР¶Рµ РЅР° СЃРµРєСЂРµС‚.",
			["Tool Chams"] = "Р§Р°РјСЃС‹ РЅР° РѕСЂСѓР¶РёРµ",
			["Tooltips"] = "РџРѕРґСЃРєР°Р·РєРё",
			["Top Rock"] = "РўРѕРї-СЂРѕРє",
			["Top"] = "РЎРІРµСЂС…Сѓ",
			["Topics"] = "РўРµРјС‹",
			["Torso"] = "РўРµР»Рѕ",
			["Total"] = "Р’СЃРµРіРѕ",
			["Touch Fling"] = "РўР°С‡ Р¤Р»РёРЅРі",
			["Toxic"] = "РўРѕРєСЃРёС‡РЅС‹Р№",
			["Toy"] = "РРіСЂСѓС€РєР°",
			["Toys"] = "РРіСЂСѓС€РєРё",
			["Tp Lobby"] = "Р’ Р»РѕР±Р±Рё",
			["Tp Map"] = "РќР° РєР°СЂС‚Сѓ",
			["Tp Murderer"] = "Рљ СѓР±РёР№С†Рµ",
			["Tp Sheriff"] = "Рљ С€РµСЂРёС„Сѓ",
			["Tracer Color"] = "Р¦РІРµС‚ С‚СЂРµР№СЃРµСЂР°",
			["Tracer Duration"] = "Р”Р»РёС‚РµР»СЊРЅРѕСЃС‚СЊ С‚СЂРµР№СЃРµСЂР°",
			["Tracer Method"] = "РњРµС‚РѕРґ С‚СЂРµР№СЃРµСЂР°",
			["Tracer Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ С‚СЂРµР№СЃРµСЂР°",
			["Tracer Style"] = "РЎС‚РёР»СЊ С‚СЂРµР№СЃРµСЂР°",
			["Tracer Width"] = "РўРѕР»С‰РёРЅР° С‚СЂРµР№СЃРµСЂР°",
			["Tracers"] = "РўСЂРµР№СЃРµСЂС‹",
			["Track unavailable"] = "РўСЂРµРє РЅРµРґРѕСЃС‚СѓРїРµРЅ",
			["Trade Value Counter"] = "РЎС‡С‘С‚С‡РёРє СЃС‚РѕРёРјРѕСЃС‚Рё С‚СЂРµР№РґР°",
			["Trade"] = "РўСЂРµР№Рґ",
			["Trail"] = "РЎР»РµРґ",
			["Trap"] = "РўСЂСЌРї",
			["Treble"] = "Р’С‹СЃРѕРєРёРµ",
			["Trending"] = "Р’ С‚СЂРµРЅРґРµ",
			["Troll Fun"] = "РўСЂРѕР»Р»-С„Р°РЅ",
			["Troll"] = "РўСЂРѕР»Р»",
			["Trolly Dances"] = "РўР°РЅС†С‹ РўСЂРѕР»Р»Рё",
			["Trolly NPC"] = "РўСЂРѕР»Р»Рё РІ Р»РѕР±Р±Рё",
			["Trolly Volume"] = "Р“СЂРѕРјРєРѕСЃС‚СЊ РўСЂРѕР»Р»Рё",
			["Try again in a few seconds"] = "РџРѕРїСЂРѕР±СѓР№ С‡РµСЂРµР· РїР°СЂСѓ СЃРµРєСѓРЅРґ",
			["Try again later"] = "РџРѕРїСЂРѕР±СѓР№ РїРѕР·Р¶Рµ",
			["Turn off the heavy stuff: Shaders, Texture Pack, Weather and ESP glow. Your FPS will thank you."] = "Р’С‹РєР»СЋС‡Рё С‚СЏР¶С‘Р»РѕРµ: С€РµР№РґРµСЂС‹, Texture Pack, РїРѕРіРѕРґСѓ Рё СЃРІРµС‡РµРЅРёРµ ESP. FPS СЃРєР°Р¶РµС‚ СЃРїР°СЃРёР±Рѕ.",
			["Twirl"] = "Р’РёС…СЂСЊ",
			["UI Size"] = "Р Р°Р·РјРµСЂ РјРµРЅСЋ",
			["UI Theme"] = "РўРµРјР° РјРµРЅСЋ",
			["UI Transparency"] = "РџСЂРѕР·СЂР°С‡РЅРѕСЃС‚СЊ РјРµРЅСЋ",
			["UI scale"] = "РњР°СЃС€С‚Р°Р± РјРµРЅСЋ",
			["UIS Style"] = "РЎС‚РёР»СЊ UIS",
			["Ultra Realism"] = "РЈР»СЊС‚СЂР° СЂРµР°Р»РёР·Рј",
			["Unavailable"] = "РќРµРґРѕСЃС‚СѓРїРµРЅ",
			["Under Map"] = "РџРѕРґ РєР°СЂС‚РѕР№",
			["Underground"] = "РџРѕРґ Р·РµРјР»СЋ",
			["Unequip"] = "РЎРЅСЏС‚СЊ",
			["Universal (Cam Lock)"] = "РЈРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Р№ (Cam Lock)",
			["Unknown"] = "РќРµРёР·РІРµСЃС‚РЅРѕ",
			["Unload hub"] = "Р’С‹РіСЂСѓР·РёС‚СЊ С…Р°Р±",
			["Unlock All Effects (game menu)"] = "Р’С‹РґР°С‚СЊ РІСЃРµ СЌС„С„РµРєС‚С‹ (РІ РјРµРЅСЋ РёРіСЂС‹)",
			["Unpin"] = "РћС‚РєСЂРµРїРёС‚СЊ",
			["Unpinned"] = "РћС‚РєСЂРµРїР»С‘РЅ",
			["Unrecognised format - not mp3 or ogg."] = "Р¤РѕСЂРјР°С‚ РЅРµ СЂР°СЃРїРѕР·РЅР°РЅ вЂ” СЌС‚Рѕ РЅРµ mp3 Рё РЅРµ ogg.",
			["Up to 4 tags"] = "РќРµ Р±РѕР»СЊС€Рµ 4 С‚РµРіРѕРІ",
			["Uploading config..."] = "Р—Р°РіСЂСѓР¶Р°СЋ РєРѕРЅС„РёРі...",
			["Uploading"] = "Р—Р°РіСЂСѓР·РєР°",
			["Use Gradient (for target)"] = "Р“СЂР°РґРёРµРЅС‚ (РґР»СЏ С†РµР»Рё)",
			["Username or user ID"] = "РќРёРє РёР»Рё ID РёРіСЂРѕРєР°",
			["Users"] = "Р®Р·РµСЂС‹",
			["Vaporwave"] = "Р’РµР№РїРѕСЂРІРµР№РІ",
			["Version v0.01"] = "Р’РµСЂСЃРёСЏ v0.01",
			["Version"] = "Р’РµСЂСЃРёСЏ",
			["Victory Music"] = "РњСѓР·С‹РєР° РїРѕР±РµРґС‹",
			["Vignette"] = "Р’РёРЅСЊРµС‚РєР°",
			["Visible"] = "Р’РёРґРµРЅ",
			["Visuals"] = "Р’РёР·СѓР°Р»",
			["Vivid"] = "РЎРѕС‡РЅС‹Р№",
			["Volume (local)"] = "Р“СЂРѕРјРєРѕСЃС‚СЊ (Р»РѕРєР°Р»СЊРЅРѕ)",
			["Volume applied to everyone."] = "Р“СЂРѕРјРєРѕСЃС‚СЊ РїСЂРёРјРµРЅРµРЅР° РєРѕ РІСЃРµРј.",
			["Waiting"] = "РћР¶РёРґР°РЅРёРµ",
			["Walk Speed Value"] = "РЎРєРѕСЂРѕСЃС‚СЊ С…РѕРґСЊР±С‹",
			["Walk Speed"] = "РЎРєРѕСЂРѕСЃС‚СЊ С…РѕРґСЊР±С‹",
			["Walk"] = "РҐРѕРґСЊР±Р°",
			["Wall Hop"] = "РћС‚СЃРєРѕРє РѕС‚ СЃС‚РµРЅ",
			["Wallbang"] = "РЎРєРІРѕР·СЊ СЃС‚РµРЅС‹",
			["Water Vortex (Feet)"] = "Р’РѕРґСЏРЅРѕР№ РІРёС…СЂСЊ (РїРѕРґ РЅРѕРіРё)",
			["Wave"] = "Р’РѕР»РЅР°",
			["Weapon Skin Changer with its own Changer page in your inventory and Pulse rarity skins. Avatar skins, free animation bundles, emotes and combos that load without lag. Auras, hats, walk trails, self and tool chams. Everyone with Pulse sees your skins and effects too."] = "РЎРјРµРЅР° СЃРєРёРЅРѕРІ РѕСЂСѓР¶РёСЏ СЃРѕ СЃРІРѕРµР№ СЃС‚СЂР°РЅРёС†РµР№ Changer РІ РёРЅРІРµРЅС‚Р°СЂРµ Рё СЃРєРёРЅР°РјРё СЂРµРґРєРѕСЃС‚Рё Pulse. РЎРєРёРЅС‹ Р°РІР°С‚Р°СЂР°, Р±РµСЃРїР»Р°С‚РЅС‹Рµ Р±Р°РЅРґР»С‹ Р°РЅРёРјР°С†РёР№, СЌРјРѕС†РёРё Рё РєРѕРјР±Рѕ, РєРѕС‚РѕСЂС‹Рµ РіСЂСѓР·СЏС‚СЃСЏ Р±РµР· Р»Р°РіРѕРІ. РђСѓСЂС‹, С€Р»СЏРїС‹, СЃР»РµРґС‹, С‡Р°РјСЃС‹ РЅР° СЃРµР±Рµ Рё РѕСЂСѓР¶РёРё. Р’СЃРµ СЃ Pulse РІРёРґСЏС‚ С‚РІРѕРё СЃРєРёРЅС‹ Рё СЌС„С„РµРєС‚С‹.",
			["Weapon Skin Changer"] = "РЎРјРµРЅР° СЃРєРёРЅРѕРІ РѕСЂСѓР¶РёСЏ",
			["Weapon Skins"] = "РЎРєРёРЅС‹ РѕСЂСѓР¶РёСЏ",
			["Wear"] = "РќР°РґРµС‚СЊ",
			["Weather"] = "РџРѕРіРѕРґР°",
			["What's new?"] = "Р§С‚Рѕ РЅРѕРІРѕРіРѕ?",
			["White"] = "Р‘РµР»С‹Р№",
			["Who are you?"] = "РўС‹ РєС‚Рѕ?",
			["Wind Aura"] = "РђСѓСЂР°: Р’РµС‚РµСЂ",
			["Wind Lines"] = "Р›РёРЅРёРё РІРµС‚СЂР°",
			["Window (main frame)"] = "РћРєРЅРѕ (РіР»Р°РІРЅС‹Р№ С„СЂРµР№Рј)",
			["Window opacity"] = "РџСЂРѕР·СЂР°С‡РЅРѕСЃС‚СЊ РѕРєРЅР°",
			["Wings & Halos"] = "РљСЂС‹Р»СЊСЏ Рё РЅРёРјР±С‹",
			["Wings"] = "РљСЂС‹Р»СЊСЏ",
			["Wins"] = "РџРѕР±РµРґС‹",
			["Wobble"] = "РљРѕР»РµР±Р°РЅРёРµ",
			["World"] = "РњРёСЂ",
			["Worn"] = "РќР°РґРµС‚С‹Рµ",
			["Wrong language for this chat"] = "РќРµ С‚РѕС‚ СЏР·С‹Рє РґР»СЏ СЌС‚РѕРіРѕ С‡Р°С‚Р°",
			["X-Ray (see through walls)"] = "X-Ray (СЃРєРІРѕР·СЊ СЃС‚РµРЅС‹)",
			["X-Ray Strength"] = "РЎРёР»Р° X-Ray",
			["X-Ray"] = "РЎРєРІРѕР·СЊ СЃС‚РµРЅС‹",
			["YOU "] = "РўР« ",
			["Yesterday"] = "Р’С‡РµСЂР°",
			["You already published this config"] = "РўС‹ СѓР¶Рµ РѕРїСѓР±Р»РёРєРѕРІР°Р» СЌС‚РѕС‚ РєРѕРЅС„РёРі",
			["You are already on this server"] = "РўС‹ СѓР¶Рµ РЅР° СЌС‚РѕРј СЃРµСЂРІРµСЂРµ",
			["You are muted"] = "РЈ С‚РµР±СЏ РјСѓС‚",
			["You can publish up to 3 configs"] = "РњРѕР¶РЅРѕ РѕРїСѓР±Р»РёРєРѕРІР°С‚СЊ РґРѕ 3 РєРѕРЅС„РёРіРѕРІ",
			["You can't rate your own config"] = "РЎРІРѕР№ РєРѕРЅС„РёРі РѕС†РµРЅРёРІР°С‚СЊ РЅРµР»СЊР·СЏ",
			["You need the in-game Radio gamepass to play music. Buy it, then EQUIP (wear) the radio."] = "Р”Р»СЏ РјСѓР·С‹РєРё РЅСѓР¶РµРЅ РёРіСЂРѕРІРѕР№ РіРµР№РјРїР°СЃСЃ Radio. РљСѓРїРё РµРіРѕ Рё РќРђР”Р•РќР¬ СЂР°РґРёРѕ.",
			["Your HWID"] = "РўРІРѕР№ HWID",
			["Your account is too new"] = "РђРєРєР°СѓРЅС‚ СЃР»РёС€РєРѕРј РЅРѕРІС‹Р№",
			["Your config"] = "РўРІРѕР№ РєРѕРЅС„РёРі",
			["Your rating: %d"] = "РўРІРѕСЏ РѕС†РµРЅРєР°: %d",
			["Your server"] = "РўРІРѕР№ СЃРµСЂРІРµСЂ",
			["Zombies: Kill All as Zombie"] = "Р—РѕРјР±Рё: СѓР±РёС‚СЊ РІСЃРµС… Р·Р° Р·РѕРјР±Рё",
			["Zombies: fling gun holders after reset"] = "Р—РѕРјР±Рё: С„Р»РёРЅРі СЃС‚СЂРµР»РєРѕРІ РїРѕСЃР»Рµ СЂРµСЃРµС‚Р°",
			["Zombies: shoot as Survivor"] = "Р—РѕРјР±Рё: СЃС‚СЂРµР»СЏС‚СЊ Р·Р° РІС‹Р¶РёРІС€РµРіРѕ",
			["bundles"] = "Р±Р°РЅРґР»С‹",
			["downloads"] = "СЃРєР°С‡РёРІР°РЅРёР№",
			["emotes"] = "СЌРјРѕС†РёРё",
			["favs"] = "РёР·Р±СЂ.",
			["min"] = "РјРёРЅ",
			["new pings"] = "РЅРѕРІС‹С… СѓРїРѕРјРёРЅР°РЅРёР№",
			["none"] = "РЅРёРєС‚Рѕ",
			["now"] = "СЃРµР№С‡Р°СЃ",
			["online"] = "РІ СЃРµС‚Рё",
			["published"] = "РѕРїСѓР±Р»РёРєРѕРІР°РЅ",
			["selected"] = "РІС‹Р±СЂР°РЅРѕ",
			["skins"] = "СЃРєРёРЅРѕРІ",
			["votes"] = "РѕС†РµРЅРѕРє",
			["Map Vote"] = "Р“РѕР»РѕСЃРѕРІР°РЅРёРµ Р·Р° РєР°СЂС‚Сѓ",
			["Votes to add"] = "РЎРєРѕР»СЊРєРѕ РіРѕР»РѕСЃРѕРІ",
			["Dupe Votes"] = "РќР°РґСЋРїР°С‚СЊ РіРѕР»РѕСЃР°",
			["Stop"] = "РЎС‚РѕРї",
			["Vote Panel"] = "РџР°РЅРµР»СЊ РіРѕР»РѕСЃРѕРІР°РЅРёСЏ",
			["Silent Respawn"] = "РўРёС…РёР№ СЂРµСЃРїР°РІРЅ",
			["Waiting for vote"] = "Р–РґС‘Рј РіРѕР»РѕСЃРѕРІР°РЅРёРµ",
			["Voting"] = "Р“РѕР»РѕСЃРѕРІР°РЅРёРµ",
			["Pick a map"] = "Р’С‹Р±РµСЂРё РєР°СЂС‚Сѓ",
			["Respawning"] = "Р РµСЃРїР°РІРЅ",
			["Voting ended"] = "Р“РѕР»РѕСЃРѕРІР°РЅРёРµ Р·Р°РєРѕРЅС‡РёР»РѕСЃСЊ",
			["Vote not counted"] = "Р“РѕР»РѕСЃ РЅРµ Р·Р°СЃС‡РёС‚Р°РЅ",
			["Done"] = "Р“РѕС‚РѕРІРѕ",
			["No character"] = "РќРµС‚ РїРµСЂСЃРѕРЅР°Р¶Р°",
			["Auto Dupe"] = "РђРІС‚Рѕ РґСЋРї",
			["Other maps"] = "РћСЃС‚Р°Р»СЊРЅС‹Рµ РєР°СЂС‚С‹",
			["Don't dupe"] = "РќРµ РґСЋРїР°С‚СЊ",
			["Dupe most voted"] = "Р”СЋРїР°С‚СЊ Р»РёРґРµСЂР°",
			["Dupe first map"] = "Р”СЋРїР°С‚СЊ РїРµСЂРІСѓСЋ",
			["Reset Priority"] = "РЎР±СЂРѕСЃРёС‚СЊ РїСЂРёРѕСЂРёС‚РµС‚",
			["Map Priority"] = "РџСЂРёРѕСЂРёС‚РµС‚ РєР°СЂС‚",
			["Farm Priority"] = "РџСЂРёРѕСЂРёС‚РµС‚ РїРѕРґ С„Р°СЂРј",
			["Explore Maps"] = "РР·СѓС‡Р°С‚СЊ РєР°СЂС‚С‹",
			["Show Round Timer"] = "РџРѕРєР°Р·С‹РІР°С‚СЊ С‚Р°Р№РјРµСЂ СЂР°СѓРЅРґР°",
			["Webhook"] = "Р’РµР±С…СѓРє",
			["Webhook URL"] = "РЎСЃС‹Р»РєР° РІРµР±С…СѓРєР°",
			["Send Farm Stats"] = "РћС‚РїСЂР°РІР»СЏС‚СЊ СЃС‚Р°С‚РёСЃС‚РёРєСѓ",
			["Every"] = "РљР°Р¶РґС‹Рµ",
			["Disconnect Alert"] = "РЎРѕРѕР±С‰Р°С‚СЊ Рѕ РєРёРєРµ",
			["Send Test"] = "РћС‚РїСЂР°РІРёС‚СЊ С‚РµСЃС‚",
			["Sent"] = "РћС‚РїСЂР°РІР»РµРЅРѕ",
			["Invalid webhook URL"] = "РќРµРІРµСЂРЅР°СЏ СЃСЃС‹Р»РєР° РІРµР±С…СѓРєР°",
			["Send failed"] = "РќРµ СѓРґР°Р»РѕСЃСЊ РѕС‚РїСЂР°РІРёС‚СЊ",
			["Kill Effects"] = "Р­С„С„РµРєС‚С‹ СѓР±РёР№СЃС‚РІ",
			["Knife Kill"] = "РЈР±РёР№СЃС‚РІРѕ РЅРѕР¶РѕРј",
			["Gun Kill"] = "РЈР±РёР№СЃС‚РІРѕ РёР· РїРёСЃС‚РѕР»РµС‚Р°",
			["Only My Kills"] = "РўРѕР»СЊРєРѕ РјРѕРё СѓР±РёР№СЃС‚РІР°",
			["Kill Sounds"] = "Р—РІСѓРєРё СѓР±РёР№СЃС‚РІ",
			["Kill Volume"] = "Р“СЂРѕРјРєРѕСЃС‚СЊ",
			["Preview Knife Kill"] = "РџРѕРєР°Р·Р°С‚СЊ СЌС„С„РµРєС‚ РЅРѕР¶Р°",
			["Preview Gun Kill"] = "РџРѕРєР°Р·Р°С‚СЊ СЌС„С„РµРєС‚ РїРёСЃС‚РѕР»РµС‚Р°",
			["Show All Effects"] = "РџРѕРєР°Р·Р°С‚СЊ РІСЃРµ СЌС„С„РµРєС‚С‹",
			["Stop Showing"] = "РћСЃС‚Р°РЅРѕРІРёС‚СЊ РїРѕРєР°Р·",
			["Slash"] = "Р Р°Р·СЂРµР·",
			["Blood"] = "РљСЂРѕРІСЊ",
			["Soul"] = "Р”СѓС€Р°",
			["Shatter"] = "РћСЃРєРѕР»РєРё",
			["Void"] = "Р‘РµР·РґРЅР°",
			["Sever"] = "Р Р°СЃСЃРµС‡РµРЅРёРµ",
			["Reaper"] = "Р–РЅРµС†",
			["Impale"] = "РЁРёРїС‹",
			["Inferno"] = "РџРµРєР»Рѕ",
			["Shadow"] = "РўРµРЅСЊ",
			["Vampire"] = "Р’Р°РјРїРёСЂ",
			["Thunder"] = "Р“СЂРѕРј",
			["Orbital"] = "РћСЂР±РёС‚Р°Р»СЊРЅС‹Р№ СѓРґР°СЂ",
			["Midas"] = "РњРёРґР°СЃ",
			["Hologram"] = "Р“РѕР»РѕРіСЂР°РјРјР°",
			["BlastOff"] = "РЈР»С‘С‚",
			["Blast Off"] = "РЈР»С‘С‚",
			["Impact"] = "РћС‚Р±СЂРѕСЃ",
			["Dragon"] = "Р”СЂР°РєРѕРЅ",
			["ShadowClones"] = "РўРµРЅРµРІС‹Рµ РєР»РѕРЅС‹",
			["Shadow Clones"] = "РўРµРЅРµРІС‹Рµ РєР»РѕРЅС‹",
			["Judgment"] = "РќРµР±РµСЃРЅС‹Р№ СЃСѓРґ",
			["Hellfire"] = "РђРґСЃРєРѕРµ РїР»Р°РјСЏ",
			["BlackFlash"] = "Р§С‘СЂРЅР°СЏ РІСЃРїС‹С€РєР°",
			["Black Flash"] = "Р§С‘СЂРЅР°СЏ РІСЃРїС‹С€РєР°",
			["PhantomBlades"] = "РџСЂРёР·СЂР°С‡РЅС‹Рµ РєР»РёРЅРєРё",
			["Phantom Blades"] = "РџСЂРёР·СЂР°С‡РЅС‹Рµ РєР»РёРЅРєРё",
			["CrystalPrison"] = "РљСЂРёСЃС‚Р°Р»СЊРЅР°СЏ С‚СЋСЂСЊРјР°",
			["Crystal Prison"] = "РљСЂРёСЃС‚Р°Р»СЊРЅР°СЏ С‚СЋСЂСЊРјР°",
			["BloodRitual"] = "РљСЂРѕРІР°РІС‹Р№ СЂРёС‚СѓР°Р»",
			["Blood Ritual"] = "РљСЂРѕРІР°РІС‹Р№ СЂРёС‚СѓР°Р»",
			["Chains"] = "Р¦РµРїРё",
			["DemonHand"] = "Р СѓРєР° РґРµРјРѕРЅР°",
			["Demon Hand"] = "Р СѓРєР° РґРµРјРѕРЅР°",
			["VoidRift"] = "Р Р°Р·Р»РѕРј",
			["Void Rift"] = "Р Р°Р·Р»РѕРј",
			["Puppet"] = "РњР°СЂРёРѕРЅРµС‚РєР°",
			["Iaido"] = "РР°Р№РґРѕ",
			["FrostBite"] = "Р›РµРґСЏРЅРѕР№ СѓРєСѓСЃ",
			["Frost Bite"] = "Р›РµРґСЏРЅРѕР№ СѓРєСѓСЃ",
			["Bladestorm"] = "Р’РёС…СЂСЊ РєР»РёРЅРєРѕРІ",
			["Claws"] = "РљРѕРіС‚Рё",
			["Gore"] = "РљСЂРѕРІР°РІС‹Р№ РІР·СЂС‹РІ",
			["LightningBlade"] = "Р“СЂРѕРјРѕРІРѕР№ РєР»РёРЅРѕРє",
			["Lightning Blade"] = "Р“СЂРѕРјРѕРІРѕР№ РєР»РёРЅРѕРє",
			["StarFall"] = "Р—РІРµР·РґРѕРїР°Рґ",
			["Star Fall"] = "Р—РІРµР·РґРѕРїР°Рґ",
			["Butterflies"] = "Р‘Р°Р±РѕС‡РєРё",
			["Railgun"] = "Р РµР»СЊСЃРѕС‚СЂРѕРЅ",
			["Nuke"] = "РЇРґРµСЂРЅС‹Р№ РІР·СЂС‹РІ",
			["Meteor"] = "РњРµС‚РµРѕСЂРёС‚",
			["Supernova"] = "РЎРІРµСЂС…РЅРѕРІР°СЏ",
			["Missiles"] = "Р Р°РєРµС‚РЅС‹Р№ Р·Р°Р»Рї",
			["HollowPurple"] = "РџСѓСЃС‚РѕС‚Р°",
			["Hollow Purple"] = "РџСѓСЃС‚РѕС‚Р°",
			["TimeStop"] = "РћСЃС‚Р°РЅРѕРІРєР° РІСЂРµРјРµРЅРё",
			["Time Stop"] = "РћСЃС‚Р°РЅРѕРІРєР° РІСЂРµРјРµРЅРё",
			["UFO"] = "РќР›Рћ",
			["Volcano"] = "Р’СѓР»РєР°РЅ",
			["SpiritBomb"] = "Р“РµРЅРєРё-РґР°РјР°",
			["Spirit Bomb"] = "Р“РµРЅРєРё-РґР°РјР°",
			["Ricochet"] = "Р РёРєРѕС€РµС‚",
			["Tesseract"] = "РўРµСЃСЃРµСЂР°РєС‚",
			["Cannonball"] = "РЇРґСЂРѕ",
			["Bubble"] = "РџСѓР·С‹СЂСЊ",
			["Drones"] = "Р”СЂРѕРЅС‹",
			["Disco"] = "Р”РёСЃРєРѕ",
			["Earthquake"] = "Р—РµРјР»РµС‚СЂСЏСЃРµРЅРёРµ",
			["Glacier"] = "Р›РµРґРЅРёРє",
			["Execution"] = "РљР°Р·РЅСЊ",
			["Crows"] = "Р’РѕСЂРѕРЅС‹",
			["KnifeRain"] = "Р”РѕР¶РґСЊ РЅРѕР¶РµР№",
			["Knife Rain"] = "Р”РѕР¶РґСЊ РЅРѕР¶РµР№",
			["Sand"] = "РџРµСЃРѕРє",
			["Jackpot"] = "Р”Р¶РµРєРїРѕС‚",
			["Portal"] = "РџРѕСЂС‚Р°Р»",
			["Anvil"] = "РќР°РєРѕРІР°Р»СЊРЅСЏ",
			["Paint"] = "РљСЂР°СЃРєР°",
			["Shred"] = "РќР°СЂРµР·РєР°",
			["Petrify"] = "РћРєР°РјРµРЅРµРЅРёРµ",
			["Poison"] = "РЇРґ",
			["Ninja"] = "РќРёРЅРґР·СЏ",
			["Firework"] = "Р¤РµР№РµСЂРІРµСЂРє",
			["Tornado"] = "РўРѕСЂРЅР°РґРѕ",
			["Balloon"] = "РЁР°СЂРёРє",
			["Levitate"] = "РќРµРІРµСЃРѕРјРѕСЃС‚СЊ",
			["BlackHole"] = "Р§С‘СЂРЅР°СЏ РґС‹СЂР°",
			["Black Hole"] = "Р§С‘СЂРЅР°СЏ РґС‹СЂР°",
			["Screen Shake"] = "РўСЂСЏСЃРєР° СЌРєСЂР°РЅР°",
			["Headshot"] = "РҐРµРґС€РѕС‚",
			["Electric"] = "Р­Р»РµРєС‚СЂРѕ",
			["Disintegrate"] = "Р Р°СЃРїР°Рґ",
			["Explosion"] = "Р’Р·СЂС‹РІ",
			["Freeze"] = "Р—Р°РјРѕСЂРѕР·РєР°",
			["Glitch"] = "Р“Р»РёС‚С‡",
		}},
	}

	function translator.tr(value)
		local dictionary = translator.data[translator.lang]
		return dictionary and dictionary[value] or value
	end

	function translator.bind(instance, source, property)
		property = property or "Text"
		table.insert(translator.reg, {inst = instance, src = source, prop = property})
		pcall(function() instance[property] = translator.tr(source) end)
	end

	function translator.addSearch(search)
		table.insert(translator.searchRegs, search)
	end

	function translator.setLang(language)
		translator.lang = translator.data[language] and language or "en"

		for _, binding in ipairs(translator.reg) do
			pcall(function()
				if binding.inst.Parent then
					binding.inst[binding.prop] = translator.tr(binding.src)
				end
			end)
		end

		for _, entries in ipairs(translator.searchRegs) do
			for _, entry in ipairs(entries) do
				if entry.srcText then
					entry.text = translator.tr(entry.srcText)
				end
			end
		end

		for _, callback in ipairs(translator.onChange) do
			pcall(callback, translator.lang)
		end
	end

	return translator
end

local NovaFoundation = {}

function NovaFoundation.create(environment)
	local game = environment.game
	local services = {
		Players = game:GetService("Players"), TweenService = game:GetService("TweenService"),
		UserInputService = game:GetService("UserInputService"), RunService = game:GetService("RunService"),
		TextService = game:GetService("TextService"), HttpService = game:GetService("HttpService"),
		Lighting = game:GetService("Lighting"),
	}
	local foundation = {Version = "1.0.0", Windows = {}, Conns = {}, Services = services}
	foundation.tr = function(value) return value end
	foundation.safe = function(callback, ...)
		if type(callback) ~= "function" then return end
		local ok, message = environment.pcall(callback, ...)
		if not ok then environment.warn("[Nova] " .. tostring(message)) end
	end
	foundation.trace = function(message)
		local ok, globals = environment.pcall(environment.getgenv)

		if ok and globals and globals.NOVA_TRACE and environment.appendfile then
			environment.pcall(environment.appendfile, "PulseHub/nova_trace.txt",
				environment.string.format("%.3f %s\n", environment.os.clock(), environment.tostring(message)))
		end
	end
	foundation.Refresh = NovaRefresh.create(environment, foundation.Windows)
	foundation.U = NovaUtility.create(environment, foundation.Windows, foundation.Conns, {
		refresh = foundation.Refresh, player = services.Players.LocalPlayer,
		inputService = services.UserInputService, textService = services.TextService,
	})
	foundation.Motion = NovaMotion.create(environment, services.TweenService, foundation.U)
	foundation.Theme = NovaTheme.create(environment, foundation.U, foundation.Refresh)
	foundation.Font = NovaFont.create(environment, foundation.U, foundation.Refresh)
	foundation.Icons = NovaIcons.create(environment)
	foundation.Sound = NovaSound.create(environment)
	foundation.Store = NovaStore.create(environment, services.HttpService)
	table.insert(foundation.Refresh.full, function(object) foundation.Theme.applyOne(object) end)
	table.insert(foundation.Refresh.full, foundation.U.radiusOne)
	table.insert(foundation.Refresh.full, foundation.Font.fontOne)
	table.insert(foundation.Refresh.full, foundation.Font.sizeOne)
	foundation.Tex = NovaTexture.create(environment, foundation.U, foundation.Refresh)
	NovaWidgets.install(environment, foundation)
	foundation.SectionClass = NovaSection.createClass(environment, foundation)
	foundation.TabClass = NovaTab.createClass(environment, foundation)
	foundation.WindowClass = NovaWindow.createClass(environment, foundation)
	foundation.CreateWindow = function(_, options)
		return NovaWindow.create(environment, foundation, options)
	end
	foundation.Notify = function(_, options)
		local window = foundation.Windows[#foundation.Windows]
		if window and not window.Destroyed then return window:Notify(options) end
	end
	foundation.screenFactor = function(viewport)
		return NovaWindow.screenFactor(environment, foundation.U, viewport)
	end

	return foundation
end




local foundation = NovaFoundation.create(environment)

local function applyBluePhotoBackground(window, options)
	options = options or {}
	local root = window.Root or window.Gui
	if not root then
		return
	end

	pcall(function()
		if window.SetBackground then
			window:SetBackground(options.BackgroundStyle or "Aurora")
		end
		if window.SetBackgroundIntensity then
			window:SetBackgroundIntensity(options.BackgroundIntensity or 1.15)
		end
	end)

	local photo = options.BackgroundImage or options.BackgroundPhoto or options.Photo
	if type(photo) == "number" then
		photo = "rbxassetid://" .. tostring(photo)
	end

	local existing = root:FindFirstChild("NovaCustomPhotoBg")
	if existing then
		existing:Destroy()
	end

	if type(photo) == "string" and #photo > 0 then
		local layer = Instance.new("ImageLabel")
		layer.Name = "NovaCustomPhotoBg"
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Size = UDim2.fromScale(1, 1)
		layer.Position = UDim2.fromScale(0, 0)
		layer.ZIndex = 0
		layer.ScaleType = Enum.ScaleType.Crop
		layer.Image = photo
		layer.ImageTransparency = tonumber(options.BackgroundTransparency) or 0.42
		layer.ImageColor3 = options.BackgroundTint or Color3.fromRGB(160, 200, 255)
		layer.Parent = root

		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 120, 255)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(30, 180, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 60, 160)),
		})
		grad.Rotation = 125
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0.25),
		})
		grad.Parent = layer
	end

	local veil = root:FindFirstChild("NovaBlueVeil")
	if veil then
		veil:Destroy()
	end
	veil = Instance.new("Frame")
	veil.Name = "NovaBlueVeil"
	veil.BackgroundColor3 = Color3.fromRGB(10, 30, 70)
	veil.BackgroundTransparency = 0.82
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 1
	veil.Parent = root
	local vg = Instance.new("UIGradient")
	vg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 140, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 80, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 40, 100)),
	})
	vg.Rotation = 160
	vg.Parent = veil
end

local Library = {}
Library.Version = (foundation.Version or "1.0.0") .. "-azure"
Library.Foundation = foundation
Library.Environment = environment

function Library:CreateWindow(options)
	options = options or {}
	if options.Accent == nil then
		options.Accent = Color3.fromRGB(64, 170, 255)
	end
	if options.Base == nil then
		options.Base = "Deep Sea"
	end
	if options.BackgroundStyle == nil then
		options.BackgroundStyle = "Aurora"
	end
	if options.LogoGlow == nil then
		options.LogoGlow = Color3.fromRGB(80, 180, 255)
	end

	local window = foundation.CreateWindow(foundation, options)
	pcall(applyBluePhotoBackground, window, options)

	function window:SetBackgroundPhoto(image, transparency, tint)
		local opts = {
			BackgroundImage = image,
			BackgroundTransparency = transparency,
			BackgroundTint = tint,
			BackgroundStyle = options.BackgroundStyle or "Aurora",
			BackgroundIntensity = options.BackgroundIntensity or 1.15,
		}
		applyBluePhotoBackground(window, opts)
	end

	return window
end

function Library:Notify(options)
	return foundation.Notify(foundation, options or {})
end

return Library
