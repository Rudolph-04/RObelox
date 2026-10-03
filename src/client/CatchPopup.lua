-- Popup card hasil tangkapan (nama ikan, rarity, +coins).
-- Dipanggil dari FishingController tiap CatchResult masuk.
-- Cuma ada 1 card aktif: kalau dapet ikan lagi sebelum card lama ilang,
-- card lama langsung diganti (replace), bukan numpuk.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SHOW_SECONDS = 3
local CARD_WIDTH = 340
local CARD_HEIGHT = 118
local TOP_MARGIN = 16
local BORDER = 3

local WHITE = Color3.new(1, 1, 1)

local RARITY_STYLES = {
	Common = { color = Color3.fromRGB(205, 210, 220), textColor = Color3.fromRGB(30, 34, 44) },
	Uncommon = { color = Color3.fromRGB(80, 205, 110), textColor = WHITE },
	Rare = { color = Color3.fromRGB(70, 150, 255), textColor = WHITE },
	Epic = { color = Color3.fromRGB(170, 90, 255), textColor = WHITE },
	Legendary = {
		color = Color3.fromRGB(255, 190, 40),
		accent = Color3.fromRGB(255, 110, 30),
		textColor = Color3.fromRGB(70, 35, 0),
		shine = true,
	},
}

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatchPopup"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local currentCard = nil

local function formatNumber(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function buildCard(fish, style)
	-- Holder: yang digerakin (posisi) + di-scale buat efek pop.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.BackgroundTransparency = 1

	local scale = Instance.new("UIScale")
	scale.Parent = card

	-- CanvasGroup: buat fade satu card sekaligus + nge-clip kilau di sudut bulat.
	-- (Jangan taro UIGradient langsung di sini, nanti ngewarnain seluruh isi.)
	local body = Instance.new("CanvasGroup")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.Parent = card
	addCorner(body, UDim.new(0, 16))

	-- Lapisan warna rarity paling belakang, keliatan sebagai "border" tebal.
	local border = Instance.new("Frame")
	border.Name = "Border"
	border.Size = UDim2.fromScale(1, 1)
	border.BackgroundColor3 = WHITE
	border.BorderSizePixel = 0
	border.Parent = body
	addCorner(border, UDim.new(0, 16))

	local borderGradient = Instance.new("UIGradient")
	borderGradient.Color = ColorSequence.new(style.color, style.accent or style.color)
	borderGradient.Rotation = 45
	borderGradient.Parent = border

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Position = UDim2.fromOffset(BORDER, BORDER)
	inner.Size = UDim2.new(1, -BORDER * 2, 1, -BORDER * 2)
	inner.BackgroundColor3 = WHITE
	inner.BorderSizePixel = 0
	inner.Parent = body
	addCorner(inner, UDim.new(0, 16 - BORDER))

	local innerGradient = Instance.new("UIGradient")
	innerGradient.Rotation = 90
	innerGradient.Color = ColorSequence.new(
		style.color:Lerp(Color3.fromRGB(16, 18, 28), 0.62),
		Color3.fromRGB(16, 18, 28)
	)
	innerGradient.Parent = inner

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = inner

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -120, 0, 20)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.Text = "KAMU DAPET IKAN!"
	header.TextSize = 13
	header.TextColor3 = Color3.fromRGB(185, 195, 215)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = inner

	-- Pill rarity di kanan atas, lebarnya ngikutin teks.
	local pill = Instance.new("Frame")
	pill.Name = "RarityPill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.fromScale(1, 0)
	pill.Size = UDim2.fromOffset(0, 22)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = style.color
	pill.BorderSizePixel = 0
	pill.Parent = inner
	addCorner(pill, UDim.new(1, 0))

	local pillPadding = Instance.new("UIPadding")
	pillPadding.PaddingLeft = UDim.new(0, 10)
	pillPadding.PaddingRight = UDim.new(0, 10)
	pillPadding.Parent = pill

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.fromScale(0, 1)
	rarityLabel.AutomaticSize = Enum.AutomaticSize.X
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBlack
	rarityLabel.Text = string.upper(fish.rarity)
	rarityLabel.TextSize = 13
	rarityLabel.TextColor3 = style.textColor
	rarityLabel.Parent = pill

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "FishName"
	nameLabel.Position = UDim2.fromOffset(0, 22)
	nameLabel.Size = UDim2.new(1, 0, 0, 36)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = fish.name
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = WHITE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = inner
	addStroke(nameLabel, Color3.new(0, 0, 0), 1.5, 0.35)

	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MaxTextSize = 30
	nameSize.Parent = nameLabel

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "Coins"
	coinsLabel.AnchorPoint = Vector2.new(0, 1)
	coinsLabel.Position = UDim2.fromScale(0, 1)
	coinsLabel.Size = UDim2.new(1, 0, 0, 26)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Font = Enum.Font.GothamBlack
	coinsLabel.Text = ("+%s Coins"):format(formatNumber(fish.value))
	coinsLabel.TextSize = 22
	coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinsLabel.Parent = inner
	addStroke(coinsLabel, Color3.fromRGB(60, 35, 0), 1.5, 0.2)

	local loops = {}

	if style.shine then
		-- Kilau tipis yang nyapu card berkala + border gradient muter pelan.
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Position = UDim2.fromScale(-0.2, 0.5)
		shine.Size = UDim2.new(0, 46, 2, 0)
		shine.Rotation = 20
		shine.BackgroundColor3 = WHITE
		shine.BorderSizePixel = 0
		shine.ZIndex = 5
		shine.Parent = body

		local shineGradient = Instance.new("UIGradient")
		shineGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		shineGradient.Parent = shine

		table.insert(loops, TweenService:Create(
			shine,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 0.6),
			{ Position = UDim2.fromScale(1.2, 0.5) }
		))
		table.insert(loops, TweenService:Create(
			borderGradient,
			TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 405 }
		))
	end

	return card, scale, body, loops
end

local CatchPopup = {}

function CatchPopup.show(fish)
	local style = RARITY_STYLES[fish.rarity] or RARITY_STYLES.Common

	if currentCard then
		currentCard:Destroy()
	end

	local card, scale, body, loops = buildCard(fish, style)
	currentCard = card

	local shownPosition = UDim2.new(0.5, 0, 0, TOP_MARGIN)
	card.Position = shownPosition - UDim2.fromOffset(0, 40)
	scale.Scale = 0.6
	body.GroupTransparency = 1
	card.Parent = screenGui

	-- Masuk: turun dari atas + pop (Back easing biar ada "mantul" dikit).
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = shownPosition,
	}):Play()
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(body, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	for _, loop in ipairs(loops) do
		loop:Play()
	end

	task.delay(SHOW_SECONDS, function()
		if currentCard ~= card then
			return -- udah diganti card baru
		end
		local fadeOut = TweenService:Create(body, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
		})
		TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = shownPosition - UDim2.fromOffset(0, 20),
		}):Play()
		fadeOut:Play()
		fadeOut.Completed:Wait()
		if currentCard == card then
			currentCard = nil
		end
		card:Destroy()
	end)
end

return CatchPopup
