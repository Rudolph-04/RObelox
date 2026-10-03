-- HUD coins kecil di kanan atas: ikon koin + angka, update otomatis dari
-- leaderstats.Coins. Tiap coins nambah: angka count-up + pill "bounce" +
-- teks "+N" melayang.
--
-- Posisinya ditaruh DI DALAM baris topbar Roblox (pake GuiService.TopbarInset),
-- bukan di bawahnya, soalnya area kanan atas di bawah topbar itu tempat
-- PlayerList (leaderboard) bawaan Roblox — kalau di situ bakal ketumpuk.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RIGHT_MARGIN = 12
local PILL_HEIGHT = 40
local COUNT_UP_SECONDS = 0.6

local GOLD = Color3.fromRGB(255, 205, 60)
local DARK_GOLD = Color3.fromRGB(140, 85, 0)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinsHUD"
screenGui.IgnoreGuiInset = true -- koordinat dihitung manual dari TopbarInset
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(1, 0.5)
pill.Size = UDim2.fromOffset(0, PILL_HEIGHT)
pill.AutomaticSize = Enum.AutomaticSize.X
pill.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
pill.BackgroundTransparency = 0.2
pill.BorderSizePixel = 0
pill.Parent = screenGui

Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

local pillStroke = Instance.new("UIStroke")
pillStroke.Color = GOLD
pillStroke.Thickness = 2
pillStroke.Transparency = 0.25
pillStroke.Parent = pill

local pillScale = Instance.new("UIScale")
pillScale.Parent = pill

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = pill

local pillPadding = Instance.new("UIPadding")
pillPadding.PaddingLeft = UDim.new(0, 6)
pillPadding.PaddingRight = UDim.new(0, 16)
pillPadding.Parent = pill

-- Ikon koin dibikin dari Frame bulat + gradient (tanpa asset luar).
local coin = Instance.new("Frame")
coin.Name = "CoinIcon"
coin.LayoutOrder = 1
coin.Size = UDim2.fromOffset(28, 28)
coin.BackgroundColor3 = Color3.new(1, 1, 1)
coin.BorderSizePixel = 0
coin.Parent = pill

Instance.new("UICorner", coin).CornerRadius = UDim.new(1, 0)

local coinGradient = Instance.new("UIGradient")
coinGradient.Rotation = 90
coinGradient.Color = ColorSequence.new(Color3.fromRGB(255, 230, 110), Color3.fromRGB(235, 150, 20))
coinGradient.Parent = coin

local coinStroke = Instance.new("UIStroke")
coinStroke.Color = DARK_GOLD
coinStroke.Thickness = 2
coinStroke.Parent = coin

local coinRing = Instance.new("Frame")
coinRing.Name = "Ring"
coinRing.AnchorPoint = Vector2.new(0.5, 0.5)
coinRing.Position = UDim2.fromScale(0.5, 0.5)
coinRing.Size = UDim2.fromOffset(18, 18)
coinRing.BackgroundTransparency = 1
coinRing.Parent = coin

Instance.new("UICorner", coinRing).CornerRadius = UDim.new(1, 0)

local ringStroke = Instance.new("UIStroke")
ringStroke.Color = Color3.fromRGB(255, 245, 190)
ringStroke.Thickness = 1.5
ringStroke.Transparency = 0.3
ringStroke.Parent = coinRing

local coinSymbol = Instance.new("TextLabel")
coinSymbol.Name = "Symbol"
coinSymbol.Size = UDim2.fromScale(1, 1)
coinSymbol.BackgroundTransparency = 1
coinSymbol.Font = Enum.Font.GothamBlack
coinSymbol.Text = "$"
coinSymbol.TextSize = 14
coinSymbol.TextColor3 = DARK_GOLD
coinSymbol.Parent = coin

local amountLabel = Instance.new("TextLabel")
amountLabel.Name = "Amount"
amountLabel.LayoutOrder = 2
amountLabel.Size = UDim2.fromOffset(0, PILL_HEIGHT)
amountLabel.AutomaticSize = Enum.AutomaticSize.X
amountLabel.BackgroundTransparency = 1
amountLabel.Font = Enum.Font.GothamBlack
amountLabel.Text = "0"
amountLabel.TextSize = 22
amountLabel.TextColor3 = Color3.new(1, 1, 1)
amountLabel.Parent = pill

local amountStroke = Instance.new("UIStroke")
amountStroke.Color = Color3.fromRGB(0, 0, 0)
amountStroke.Thickness = 1.5
amountStroke.Transparency = 0.4
amountStroke.Parent = amountLabel

screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── POSISI ─────────────────────────────────────────────────────────
-- Rata kanan + di tengah vertikal area topbar yang kosong. Kalau topbar-nya
-- nggak ada (tinggi 0), jatuh ke pojok kanan atas biasa.
local function updatePosition()
	local inset = GuiService.TopbarInset
	local height = inset.Height
	if height <= 0 then
		pill.Position = UDim2.new(1, -RIGHT_MARGIN, 0, RIGHT_MARGIN + PILL_HEIGHT / 2)
	else
		pill.Position = UDim2.fromOffset(inset.Max.X - RIGHT_MARGIN, inset.Min.Y + height / 2)
	end
end

updatePosition()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(updatePosition)

-- ── ANGKA + ANIMASI ────────────────────────────────────────────────
local function formatNumber(n)
	local s = tostring(math.floor(n + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Angka yang lagi ditampilin; di-tween biar count-up, bukan langsung loncat.
local displayed = Instance.new("NumberValue")
displayed.Changed:Connect(function(value)
	amountLabel.Text = formatNumber(value)
end)

local countTween = nil

local function bounce()
	pillScale.Scale = 1.2
	TweenService:Create(pillScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	coin.Rotation = 0
	TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 360,
	}):Play()
end

local function floatGain(amount)
	local gain = Instance.new("TextLabel")
	gain.Name = "Gain"
	gain.AnchorPoint = Vector2.new(1, 0.5)
	gain.Position = pill.Position - UDim2.fromOffset(pill.AbsoluteSize.X + 8, 0)
	gain.Size = UDim2.fromOffset(0, 28)
	gain.AutomaticSize = Enum.AutomaticSize.X
	gain.BackgroundTransparency = 1
	gain.Font = Enum.Font.GothamBlack
	gain.Text = "+" .. formatNumber(amount)
	gain.TextSize = 20
	gain.TextColor3 = GOLD
	gain.Parent = screenGui

	local gainStroke = Instance.new("UIStroke")
	gainStroke.Color = Color3.fromRGB(60, 35, 0)
	gainStroke.Thickness = 1.5
	gainStroke.Parent = gain

	-- Geser terus dari awal, tapi fade-nya ditahan dulu biar "+N" sempet kebaca.
	TweenService:Create(gain, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = gain.Position - UDim2.fromOffset(24, 0),
	}):Play()
	local fadeInfo = TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35)
	local fade = TweenService:Create(gain, fadeInfo, { TextTransparency = 1 })
	TweenService:Create(gainStroke, fadeInfo, { Transparency = 1 }):Play()
	fade.Completed:Once(function()
		gain:Destroy()
	end)
	fade:Play()
end

local lastValue = nil

local function onCoinsChanged(newValue)
	if lastValue == nil then
		-- Nilai awal: langsung set tanpa animasi.
		displayed.Value = newValue
		lastValue = newValue
		return
	end

	local delta = newValue - lastValue
	lastValue = newValue

	if countTween then
		countTween:Cancel()
	end
	countTween = TweenService:Create(
		displayed,
		TweenInfo.new(COUNT_UP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = newValue }
	)
	countTween:Play()

	if delta > 0 then
		floatGain(delta) -- duluan, biar posisinya dihitung dari ukuran pill sebelum di-scale
		bounce()
	end
end

-- ── BIND KE leaderstats.Coins ──────────────────────────────────────
-- Re-bind kalau Coins-nya diganti/ke-destroy (misal leaderstats dibikin ulang).
local coinsConn = nil

local function bindCoins(coins)
	if coinsConn then
		coinsConn:Disconnect()
	end
	lastValue = nil
	onCoinsChanged(coins.Value)
	coinsConn = coins.Changed:Connect(onCoinsChanged)

	coins.AncestryChanged:Connect(function()
		if coins:IsDescendantOf(player) then
			return
		end
		local leaderstats = player:WaitForChild("leaderstats")
		bindCoins(leaderstats:WaitForChild("Coins"))
	end)
end

bindCoins(player:WaitForChild("leaderstats"):WaitForChild("Coins"))
