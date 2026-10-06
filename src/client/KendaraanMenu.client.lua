-- Menu KENDARAAN: tombol di kiri layar -> daftar kendaraan dagangan ->
-- "Keluarin" (minta server spawn di parkiran Pasar). Kalau kendaraannya
-- udah ada, tombolnya jadi "Panggil Ulang" (sekalian buat yang nyangkut).
-- Isi daftarnya dari KendaraanConfig.DAFTAR, jadi kendaraan upgrade nanti
-- otomatis muncul di sini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local KendaraanConfig = require(ReplicatedStorage:WaitForChild("KendaraanConfig"))

local player = Players.LocalPlayer
local kendaraanFolder = workspace:WaitForChild("Kendaraan")

local DARK = Color3.fromRGB(18, 20, 28)
local CARD = Color3.fromRGB(32, 36, 48)
local ORANGE = Color3.fromRGB(240, 135, 35)
local ORANGE_EDGE = Color3.fromRGB(120, 55, 0)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 180, 200)

local PANEL_WIDTH = 300
local ENTRY_HEIGHT = 96

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = WHITE
	l.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in pairs(props) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function button(parent, props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = ORANGE
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = WHITE
	b.TextSize = 16
	for key, value in pairs(props) do
		b[key] = value
	end
	addCorner(b, 10)
	addStroke(b, ORANGE_EDGE, 2)
	b.Parent = parent
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "KendaraanMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Tombol buka/tutup di kiri tengah.
local toggle = button(gui, {
	Name = "TombolKendaraan",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(132, 48),
	Text = "KENDARAAN",
})

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 156, 0.5, 0)
panel.Size = UDim2.fromOffset(PANEL_WIDTH, 52 + #KendaraanConfig.DAFTAR * (ENTRY_HEIGHT + 8))
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
addCorner(panel, 14)

label(panel, {
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -60, 0, 28),
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	Text = "Kendaraan Dagangan",
})
local close = button(panel, {
	Name = "Tutup",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = CARD,
	Text = "X",
	TextSize = 14,
})

local function findMine(id)
	for _, model in ipairs(kendaraanFolder:GetChildren()) do
		if model:GetAttribute("OwnerUserId") == player.UserId and model:GetAttribute("Kendaraan") == id then
			return model
		end
	end
	return nil
end

local entryButtons = {} -- [id] = TextButton
for i, info in ipairs(KendaraanConfig.DAFTAR) do
	local card = Instance.new("Frame")
	card.Name = info.id
	card.Position = UDim2.fromOffset(10, 48 + (i - 1) * (ENTRY_HEIGHT + 8))
	card.Size = UDim2.new(1, -20, 0, ENTRY_HEIGHT)
	card.BackgroundColor3 = CARD
	card.Parent = panel
	addCorner(card, 10)

	label(card, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Text = info.nama,
	})
	label(card, {
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = MUTED,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = info.deskripsi,
	})
	local spawnButton = button(card, {
		Name = "Keluarin",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "KELUARIN",
	})
	spawnButton.Activated:Connect(function()
		Remotes.SpawnKendaraan:FireServer(info.id)
	end)
	entryButtons[info.id] = spawnButton
end

local function refreshButtons()
	for id, b in pairs(entryButtons) do
		b.Text = findMine(id) and "PANGGIL ULANG" or "KELUARIN"
	end
end

local function setOpen(open)
	panel.Visible = open
	if open then
		refreshButtons()
	end
end

toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)
kendaraanFolder.ChildAdded:Connect(refreshButtons)
kendaraanFolder.ChildRemoved:Connect(refreshButtons)

-- Pesan dari server (berhasil / ditolak), muncul sebentar di atas tengah.
local toast = label(gui, {
	Name = "Pesan",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 124),
	Size = UDim2.fromOffset(360, 40),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
})
addCorner(toast, 10)

local toastToken = 0
Remotes.InfoKendaraan.OnClientEvent:Connect(function(pesan, berhasil)
	toastToken += 1
	local token = toastToken
	toast.Text = pesan
	toast.TextColor3 = berhasil and Color3.fromRGB(140, 235, 140) or Color3.fromRGB(255, 200, 90)
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.15
	toast.Visible = true
	if berhasil then
		setOpen(false)
	end
	task.delay(2.5, function()
		if token ~= toastToken then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.4)
		if token == toastToken then
			toast.Visible = false
		end
	end)
end)
