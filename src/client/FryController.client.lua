-- UI goreng: bar kematangan + tombol "Angkat" + feedback hasil.
-- Murni tampilan: kualitas & uang ditentuin FryService di server. Client cuma
-- ngirim "angkat sekarang" (plus jam klik, buat kompensasi lag).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local FryConfig = require(ReplicatedStorage:WaitForChild("FryConfig"))

local player = Players.LocalPlayer

local LIFT_ACTION = "AngkatTahu"
local PANEL_HEIGHT = 136
local BOTTOM_MARGIN = 24

local ZONE_COLORS = {
	Mentah = Color3.fromRGB(236, 226, 192),
	Oke = Color3.fromRGB(245, 200, 60),
	Perfect = Color3.fromRGB(80, 200, 90),
	Gosong = Color3.fromRGB(45, 32, 25),
}

local RESULT_COLORS = {
	Mentah = Color3.fromRGB(240, 232, 200),
	Oke = Color3.fromRGB(255, 210, 70),
	Perfect = Color3.fromRGB(110, 235, 110),
	Gosong = Color3.fromRGB(170, 140, 120),
}

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(18, 20, 28)

local function formatRupiah(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return "Rp " .. formatted:gsub("^%.", "")
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function makeLabel(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = WHITE
	for key, value in pairs(props) do
		label[key] = value
	end
	return label
end

-- ── BUILD UI ───────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FryUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- CanvasGroup biar panel bisa di-fade sekaligus.
-- (Background-nya Frame terpisah: UIGradient/warna di CanvasGroup ngaruh ke seluruh isi.)
local panel = Instance.new("CanvasGroup")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN)
panel.Size = UDim2.new(0.92, 0, 0, PANEL_HEIGHT)
panel.BackgroundTransparency = 1
panel.GroupTransparency = 1
panel.Visible = false
panel.Parent = screenGui
addCorner(panel, UDim.new(0, 16))

local panelSize = Instance.new("UISizeConstraint")
panelSize.MaxSize = Vector2.new(480, PANEL_HEIGHT)
panelSize.Parent = panel

local panelBg = Instance.new("Frame")
panelBg.Name = "Background"
panelBg.Size = UDim2.fromScale(1, 1)
panelBg.BackgroundColor3 = DARK
panelBg.BackgroundTransparency = 0.08
panelBg.BorderSizePixel = 0
panelBg.Parent = panel
addCorner(panelBg, UDim.new(0, 16))

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.fromScale(1, 1)
content.BackgroundTransparency = 1
content.Parent = panel

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 10)
contentPadding.PaddingBottom = UDim.new(0, 12)
contentPadding.PaddingLeft = UDim.new(0, 16)
contentPadding.PaddingRight = UDim.new(0, 16)
contentPadding.Parent = content

local title = makeLabel({
	Name = "Title",
	Size = UDim2.new(0.5, 0, 0, 20),
	Font = Enum.Font.GothamBlack,
	Text = "LAGI GORENG...",
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = content,
})

makeLabel({
	Name = "Hint",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.5, 0, 0, 20),
	Font = Enum.Font.GothamMedium,
	Text = "Angkat pas jarumnya di hijau!",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(170, 180, 200),
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = content,
})

-- Bulet "tahu" di kiri bar, warnanya ngikutin kematangan.
local tahuIcon = Instance.new("Frame")
tahuIcon.Name = "TahuIcon"
tahuIcon.Position = UDim2.fromOffset(0, 34)
tahuIcon.Size = UDim2.fromOffset(36, 36)
tahuIcon.BackgroundColor3 = FryConfig.TAHU_RAW
tahuIcon.BorderSizePixel = 0
tahuIcon.Parent = content
addCorner(tahuIcon, UDim.new(1, 0))
addStroke(tahuIcon, Color3.fromRGB(90, 60, 30), 2)

local barArea = Instance.new("Frame")
barArea.Name = "BarArea"
barArea.Position = UDim2.fromOffset(48, 24)
barArea.Size = UDim2.new(1, -48, 0, 50)
barArea.BackgroundTransparency = 1
barArea.Parent = content

-- CanvasGroup kecil buat nge-clip segmen zona ke sudut bulat.
local barClip = Instance.new("CanvasGroup")
barClip.Name = "Bar"
barClip.Position = UDim2.fromOffset(0, 18)
barClip.Size = UDim2.new(1, 0, 0, 24)
barClip.BackgroundTransparency = 1
barClip.Parent = barArea
addCorner(barClip, UDim.new(0, 8))

local previousTo = 0
for _, zone in ipairs(FryConfig.ZONES) do
	local segment = Instance.new("Frame")
	segment.Name = zone.quality
	segment.Position = UDim2.fromScale(previousTo, 0)
	segment.Size = UDim2.fromScale(zone.to - previousTo, 1)
	segment.BackgroundColor3 = ZONE_COLORS[zone.quality]
	segment.BorderSizePixel = 0
	segment.Parent = barClip
	previousTo = zone.to
end

-- Label di atas bar: MENTAH / PAS / GOSONG (Oke+Perfect+Oke digabung jadi "PAS").
local function zoneRange(qualities)
	local from, to, previous = nil, nil, 0
	for _, zone in ipairs(FryConfig.ZONES) do
		if table.find(qualities, zone.quality) then
			from = from or previous
			to = zone.to
		end
		previous = zone.to
	end
	return from, to
end

for _, info in ipairs({
	{ text = "MENTAH", qualities = { "Mentah" } },
	{ text = "PAS", qualities = { "Oke", "Perfect" } },
	{ text = "GOSONG", qualities = { "Gosong" } },
}) do
	local from, to = zoneRange(info.qualities)
	makeLabel({
		Name = info.text,
		Position = UDim2.fromScale(from, 0),
		Size = UDim2.new(to - from, 0, 0, 16),
		Font = Enum.Font.GothamBold,
		Text = info.text,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(200, 208, 225),
		Parent = barArea,
	})
end

local needle = Instance.new("Frame")
needle.Name = "Needle"
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Position = UDim2.new(0, 0, 0, 30)
needle.Size = UDim2.fromOffset(6, 34)
needle.BackgroundColor3 = WHITE
needle.BorderSizePixel = 0
needle.ZIndex = 3
needle.Parent = barArea
addCorner(needle, UDim.new(1, 0))
addStroke(needle, DARK, 2)

local liftButton = Instance.new("TextButton")
liftButton.Name = "AngkatButton"
liftButton.AnchorPoint = Vector2.new(0.5, 1)
liftButton.Position = UDim2.fromScale(0.5, 1)
liftButton.Size = UDim2.fromOffset(220, 40)
liftButton.BackgroundColor3 = Color3.fromRGB(240, 135, 35)
liftButton.AutoButtonColor = true
liftButton.Font = Enum.Font.GothamBlack
liftButton.TextSize = 18
liftButton.TextColor3 = WHITE
liftButton.Text = "ANGKAT!"
liftButton.Parent = content
addCorner(liftButton, UDim.new(0, 10))
addStroke(liftButton, Color3.fromRGB(120, 55, 0), 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Feedback hasil: muncul di atas panel, pop terus ilang sendiri.
local resultPop = Instance.new("CanvasGroup")
resultPop.Name = "Result"
resultPop.AnchorPoint = Vector2.new(0.5, 1)
resultPop.Position = UDim2.new(0.5, 0, 1, -(BOTTOM_MARGIN + PANEL_HEIGHT + 16))
resultPop.Size = UDim2.fromOffset(420, 110)
resultPop.BackgroundTransparency = 1
resultPop.GroupTransparency = 1
resultPop.Visible = false
resultPop.Parent = screenGui

local resultScale = Instance.new("UIScale")
resultScale.Parent = resultPop

local resultTitle = makeLabel({
	Name = "Title",
	Size = UDim2.new(1, 0, 0, 54),
	Font = Enum.Font.FredokaOne,
	TextSize = 46,
	Parent = resultPop,
})
local resultTitleStroke = addStroke(resultTitle, DARK, 3)

local resultReward = makeLabel({
	Name = "Reward",
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 0, 26),
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 220, 90),
	Parent = resultPop,
})
addStroke(resultReward, DARK, 2)

-- Keterangan kecil dari server (masuk etalase, kembalian, dll). Kosong = ilang.
local resultNote = makeLabel({
	Name = "Catatan",
	Position = UDim2.fromOffset(0, 84),
	Size = UDim2.new(1, 0, 0, 22),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	Parent = resultPop,
})
addStroke(resultNote, DARK, 2)

screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── STATE ──────────────────────────────────────────────────────────
local active = false -- lagi goreng (bar jalan)
local waitingResult = false -- udah klik angkat, nunggu jawaban server
local startTime = 0
local duration = FryConfig.DURATION
local resultToken = 0

local function setNeedle(progress)
	needle.Position = UDim2.new(progress, 0, 0, 30)
	tahuIcon.BackgroundColor3 = FryConfig.tahuColorAt(progress)
end

local function showPanel()
	panel.Visible = true
	panel.Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN + 30)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
	}):Play()
end

local function hidePanel()
	local tween = TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		GroupTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN + 30),
	})
	tween:Play()
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and not active then
			panel.Visible = false
		end
	end)
end

local function requestLift()
	if not active or waitingResult then
		return
	end
	waitingResult = true
	liftButton.Text = "..."
	Remotes.LiftTahu:FireServer(workspace:GetServerTimeNow())
end

local function onLiftAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		requestLift()
	end
	return Enum.ContextActionResult.Sink
end

local function showResult(result)
	resultToken += 1
	local token = resultToken

	resultTitle.Text = result.label
	resultTitle.TextColor3 = RESULT_COLORS[result.quality] or WHITE
	resultTitleStroke.Color = result.quality == "Gosong" and Color3.fromRGB(0, 0, 0) or DARK
	-- Uang yang beneran masuk (bayaran + kembalian yang nggak diambil pembeli).
	local total = result.total or (result.pay + result.tip)
	resultReward.Text = total > 0 and ("+" .. formatRupiah(total)) or ""
	resultNote.Text = result.catatan or ""

	resultPop.Visible = true
	resultPop.GroupTransparency = 0
	resultScale.Scale = result.quality == "Perfect" and 0.4 or 0.6
	TweenService:Create(resultScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.delay(1.6, function()
		if token ~= resultToken then
			return -- udah ada hasil baru
		end
		local fade = TweenService:Create(resultPop, TweenInfo.new(0.4), { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		if token == resultToken then
			resultPop.Visible = false
		end
	end)
end

-- ── EVENTS ─────────────────────────────────────────────────────────
liftButton.Activated:Connect(requestLift)

RunService.RenderStepped:Connect(function()
	if active and not waitingResult then
		setNeedle(math.clamp((workspace:GetServerTimeNow() - startTime) / duration, 0, 1))
	end
end)

Remotes.FryStarted.OnClientEvent:Connect(function(serverStartTime, fryDuration)
	active = true
	waitingResult = false
	startTime = serverStartTime
	duration = fryDuration
	liftButton.Text = UserInputService.KeyboardEnabled and "ANGKAT!  [E]" or "ANGKAT!"
	setNeedle(0)
	showPanel()
	ContextActionService:BindActionAtPriority(
		LIFT_ACTION,
		onLiftAction,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX
	)
end)

-- Tahu dari etalase dibeli pembeli NPC (bisa dateng kapan aja, bar goreng nggak diubah).
Remotes.Penjualan.OnClientEvent:Connect(showResult)

Remotes.FryResult.OnClientEvent:Connect(function(result)
	active = false
	waitingResult = false
	ContextActionService:UnbindAction(LIFT_ACTION)
	setNeedle(result.progress) -- jarum berhenti di titik yang dinilai server
	showResult(result)
	task.delay(0.5, function()
		if not active then
			hidePanel()
		end
	end)
end)
