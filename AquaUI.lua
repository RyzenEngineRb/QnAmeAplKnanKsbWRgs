--[[
    AquaUI - стеклянная голубая UI-библиотека
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
	Accent = Color3.fromRGB(90, 190, 255),
	Glass = Color3.fromRGB(120, 200, 255),
	Dark = Color3.fromRGB(10, 25, 45),
	Text = Color3.fromRGB(235, 248, 255),
	SubText = Color3.fromRGB(160, 200, 225),
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

local function Round(r)
	return New("UICorner", { CornerRadius = r or UDim.new(0, 10) })
end

local function Stroke(transparency, color)
	return New("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Transparency = transparency or 0.5,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function Glass(frame)
	frame.BackgroundColor3 = THEME.Dark
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	New("UIGradient", {
		Color = ColorSequence.new(THEME.Glass, THEME.Dark),
		Transparency = NumberSequence.new(0.75, 0.2),
		Rotation = 90,
	}).Parent = frame
	return frame
end

local function Tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad), props):Play()
end

local function MakeDraggable(handle, target)
	local dragging, startPos, startInput
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startInput = input.Position
			startPos = target.Position
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
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
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

---------------------------------------------------------------------
-- Watermark: ник | FPS | пинг | время
---------------------------------------------------------------------
local function CreateWatermark(gui)
	local bar = Glass(New("Frame", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(380, 34),
		Parent = gui,
	}))
	Round(UDim.new(1, 0)).Parent = bar
	Stroke(0.45).Parent = bar

	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = THEME.Text,
		RichText = true,
		Text = "",
		Parent = bar,
	})
	MakeDraggable(bar, bar)

	local frames, last, fps = 0, os.clock(), 60
	RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - last >= 0.5 then
			fps = math.floor(frames / (now - last))
			frames, last = 0, now
			local ping = 0
			pcall(function()
				ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
			end)
			label.Text = string.format(
				'<font color="#5abeff">%s</font>  |  FPS %d  |  %d ms  |  %s',
				LocalPlayer.DisplayName, fps, ping, os.date("%H:%M:%S")
			)
		end
	end)
	return bar
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------
function Aqua:CreateWindow(opts)
	opts = opts or {}
	local self = setmetatable({ Tabs = {}, Scale = 1 }, Aqua)

	local gui = New("ScreenGui", {
		Name = "AquaUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = GetParent(),
	})
	self.Gui = gui

	if opts.Watermark ~= false then
		CreateWatermark(gui)
	end

	-- главное окно
	local main = Glass(New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = opts.Size or UDim2.fromOffset(460, 300),
		Visible = true,
		Parent = gui,
	}))
	Round(UDim.new(0, 16)).Parent = main
	Stroke(0.4).Parent = main
	local uiScale = New("UIScale", { Scale = 1, Parent = main })
	self.Main = main

	local top = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38),
		Parent = main,
	})
	MakeDraggable(top, main)

	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -140, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Text,
		Text = opts.Title or "Aqua",
		Parent = top,
	})

	local function HeaderButton(text, xOffset)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = THEME.Accent,
			BackgroundTransparency = 0.7,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = THEME.Text,
			Text = text,
			AutoButtonColor = false,
			Parent = top,
		})
		Round(UDim.new(1, 0)).Parent = b
		b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = 0.4 }) end)
		b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 0.7 }) end)
		return b
	end

	function self:SetScale(s)
		self.Scale = math.clamp(s, 0.6, 1.6)
		Tween(uiScale, { Scale = self.Scale })
	end
	HeaderButton("×", -10).MouseButton1Click:Connect(function() main.Visible = false end)
	HeaderButton("+", -42).MouseButton1Click:Connect(function() self:SetScale(self.Scale + 0.1) end)
	HeaderButton("−", -74).MouseButton1Click:Connect(function() self:SetScale(self.Scale - 0.1) end)

	-- боковая панель вкладок
	local side = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(0, 112, 1, -56),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = main,
	}, { New("UIListLayout", { Padding = UDim.new(0, 6) }) })

	local pages = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(132, 44),
		Size = UDim2.new(1, -142, 1, -56),
		Parent = main,
	})

	-- уголок для растягивания
	local grip = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Text = "◢",
		TextSize = 14,
		TextColor3 = THEME.Accent,
		Parent = main,
	})
	do
		local resizing, startPos, startSize
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing, startPos, startSize = true, input.Position, main.AbsoluteSize / uiScale.Scale
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then resizing = false end
				end)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local d = (input.Position - startPos) / uiScale.Scale
				main.Size = UDim2.fromOffset(math.max(360, startSize.X + d.X), math.max(240, startSize.Y + d.Y))
			end
		end)
	end

	-- кнопка открытия/закрытия панели
	local toggle = Glass(New("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		Text = "◈",
		TextSize = 20,
		TextColor3 = THEME.Accent,
		AutoButtonColor = false,
		Parent = gui,
	}))
	Round(UDim.new(1, 0)).Parent = toggle
	Stroke(0.4).Parent = toggle
	MakeDraggable(toggle, toggle)
	toggle.MouseButton1Click:Connect(function()
		main.Visible = not main.Visible
	end)
	if opts.ToggleKey then
		UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == opts.ToggleKey then main.Visible = not main.Visible end
		end)
	end

	---------------------------------------------------------------
	-- Tabs
	---------------------------------------------------------------
	function self:AddTab(name)
		local tab = {}
		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = THEME.Accent,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = THEME.SubText,
			Text = name,
			AutoButtonColor = false,
			Parent = side,
		})
		Round(UDim.new(0, 10)).Parent = btn

		local page = New("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = THEME.Accent,
			Visible = false,
			Parent = pages,
		}, { New("UIListLayout", { Padding = UDim.new(0, 8) }) })

		local function Select()
			for _, t in ipairs(self.Tabs) do
				t.Page.Visible = false
				Tween(t.Button, { BackgroundTransparency = 1, TextColor3 = THEME.SubText })
			end
			page.Visible = true
			Tween(btn, { BackgroundTransparency = 0.6, TextColor3 = THEME.Text })
		end
		btn.MouseButton1Click:Connect(Select)
		tab.Page, tab.Button = page, btn
		table.insert(self.Tabs, tab)
		if #self.Tabs == 1 then Select() end

		local function Row(h)
			local r = New("Frame", {
				Size = UDim2.new(1, -4, 0, h or 36),
				BackgroundColor3 = THEME.Glass,
				BackgroundTransparency = 0.85,
				Parent = page,
			})
			Round(UDim.new(0, 10)).Parent = r
			Stroke(0.75).Parent = r
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

		function tab:AddLabel(text)
			local r = Row(28)
			RowLabel(r, text).Size = UDim2.new(1, -24, 1, 0)
		end

		function tab:AddButton(text, callback)
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
			b.MouseButton1Click:Connect(function()
				Tween(r, { BackgroundTransparency = 0.6 }, 0.08)
				task.delay(0.1, function() Tween(r, { BackgroundTransparency = 0.85 }) end)
				if callback then task.spawn(callback) end
			end)
		end

		function tab:AddToggle(text, default, callback)
			local r = Row()
			RowLabel(r, text)
			local state = default and true or false
			local track = New("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(38, 20),
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = state and THEME.Accent or Color3.fromRGB(60, 80, 100),
				Parent = r,
			})
			Round(UDim.new(1, 0)).Parent = track
			local knob = New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, state and 20 or 2, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = track,
			})
			Round(UDim.new(1, 0)).Parent = knob
			track.MouseButton1Click:Connect(function()
				state = not state
				Tween(track, { BackgroundColor3 = state and THEME.Accent or Color3.fromRGB(60, 80, 100) })
				Tween(knob, { Position = UDim2.new(0, state and 20 or 2, 0.5, 0) })
				if callback then task.spawn(callback, state) end
			end)
		end

		function tab:AddSlider(text, min, max, default, callback)
			local r = Row(50)
			RowLabel(r, text).Position = UDim2.fromOffset(12, -8)
			local valueLabel = New("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 6),
				Size = UDim2.fromOffset(50, 18),
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = THEME.Accent,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = r,
			})
			local bar = New("TextButton", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -24, 0, 6),
				BackgroundColor3 = Color3.fromRGB(60, 80, 100),
				Text = "",
				AutoButtonColor = false,
				Parent = r,
			})
			Round(UDim.new(1, 0)).Parent = bar
			local fill = New("Frame", { BackgroundColor3 = THEME.Accent, Size = UDim2.fromScale(0, 1), Parent = bar })
			Round(UDim.new(1, 0)).Parent = fill

			local function Set(v)
				v = math.clamp(math.floor(v + 0.5), min, max)
				fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
				valueLabel.Text = tostring(v)
				return v
			end
			Set(default or min)

			local sliding = false
			local function Update(x)
				local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
				local v = Set(min + (max - min) * rel)
				if callback then task.spawn(callback, v) end
			end
			bar.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					Update(i.Position.X)
				end
			end)
			UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					sliding = false
				end
			end)
			UserInputService.InputChanged:Connect(function(i)
				if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
					Update(i.Position.X)
				end
			end)
		end

		return tab
	end

	function self:Destroy()
		gui:Destroy()
	end

	return self
end

return setmetatable({}, { __index = Aqua })
