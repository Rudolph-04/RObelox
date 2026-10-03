--[[
	BuildPasar — bangun area "Pasar" (graybox) + gerobak tahu + wajan.

	BUKAN script game. Jalanin SEKALI di mode Edit (Command Bar Studio, atau
	lewat Claude Code + Studio MCP), terus Save place-nya (Ctrl+S). Hasilnya jadi
	part biasa di Workspace.Pasar yang bisa diedit/digeser manual di Studio.

	Yang penting buat gameplay cuma model wajan:
	  - tag CollectionService "Wajan"
	  - child Part "Minyak" (tempat tahu ngambang, ada ParticleEmitter "Asap")
	  - ProximityPrompt di dalamnya
	FryService nyari wajan lewat tag itu, jadi gerobak/dekorasi bebas diubah.

	Kalau Workspace.Pasar udah ada, script ini nggak ngapa-ngapain
	(hapus dulu manual kalau mau bangun ulang).
]]

local CollectionService = game:GetService("CollectionService")

if workspace:FindFirstChild("Pasar") then
	warn("[BuildPasar] Workspace.Pasar udah ada, skip. Hapus dulu kalau mau bangun ulang.")
	return "skip"
end

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

-- Titik tengah pasar (permukaan tanahnya). Kalau ada Baseplate: di tengahnya.
-- Kalau nggak ada (map custom), pake CUSTOM_ORIGIN + dibikinin pondasi ke bawah.
-- Place sekarang (bekas map mancing): lepas pantai, di belakang dermaga lama.
local CUSTOM_ORIGIN = V3(0, 4, 260)

local baseplate = workspace:FindFirstChild("Baseplate")
local ORIGIN = baseplate and V3(0, baseplate.Position.Y + baseplate.Size.Y / 2, 0) or CUSTOM_ORIGIN
local GROUND = ORIGIN.Y

local function part(parent, name, size, pos, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = V3(ORIGIN.X + pos.X, GROUND + pos.Y, ORIGIN.Z + pos.Z)
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- Silinder di Roblox sumbunya X. Buat silinder "berdiri" (tutup di atas),
-- size = (tinggi, diameter, diameter) lalu diputer 90° di Z.
local function disc(parent, name, height, diameter, pos, color, material, props)
	local p = part(parent, name, V3(height, diameter, diameter), pos, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function signText(board, face, text, textColor, bgColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bgColor
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
end

local WOOD = RGB(150, 100, 55)
local WOOD_DARK = RGB(110, 72, 40)
local METAL = RGB(70, 72, 78)
local CREAM = RGB(250, 240, 215)

local pasar = Instance.new("Folder")
pasar.Name = "Pasar"

-- ── LANTAI PASAR ───────────────────────────────────────────────────
part(pasar, "Lantai", V3(56, 0.4, 44), V3(0, 0.2, 4), RGB(168, 160, 148), M.Concrete)
if not baseplate then
	-- Map tanpa Baseplate: kasih pondasi biar lantainya nggak ngambang.
	part(pasar, "Pondasi", V3(56, 12, 44), V3(0, -6, 4), RGB(120, 115, 108), M.Concrete)
end

-- ── GEROBAK (customer di sisi +Z, yang goreng di sisi -Z) ─────────
local gerobak = model(pasar, "Gerobak")
local FLOOR = 0.4

part(gerobak, "Badan", V3(9, 2.4, 3.6), V3(0, FLOOR + 2.3, 0), WOOD_DARK, M.Wood)
local meja = part(gerobak, "Meja", V3(9.6, 0.4, 4.2), V3(0, FLOOR + 3.5, 0), WOOD, M.WoodPlanks)
local mejaTop = meja.Position.Y - GROUND + meja.Size.Y / 2

for _, x in ipairs({ -4.75, 4.75 }) do
	disc(gerobak, "Roda", 0.4, 2.2, V3(x, FLOOR + 1.1, 0.4), RGB(40, 40, 42), M.Rubber)
	disc(gerobak, "As", 0.5, 0.6, V3(x, FLOOR + 1.1, 0.4), RGB(150, 150, 155), M.Metal)
end
part(gerobak, "Kaki", V3(0.5, 1.2, 0.5), V3(-3.6, FLOOR + 0.6, -1.3), WOOD_DARK, M.Wood)
part(gerobak, "Kaki", V3(0.5, 1.2, 0.5), V3(3.6, FLOOR + 0.6, -1.3), WOOD_DARK, M.Wood)

-- Pegangan dorong di sisi -X.
for _, z in ipairs({ -1.4, 1.4 }) do
	part(gerobak, "Pegangan", V3(2.8, 0.3, 0.3), V3(-5.9, FLOOR + 2.9, z), WOOD, M.Wood)
end

-- Tiang + atap belang merah-putih.
for _, x in ipairs({ -4.5, 4.5 }) do
	for _, z in ipairs({ -1.9, 1.9 }) do
		part(gerobak, "Tiang", V3(0.3, 4.2, 0.3), V3(x, mejaTop + 2.1, z), WOOD_DARK, M.Wood)
	end
end
local roofY = mejaTop + 4.35
for i = 0, 4 do
	local color = (i % 2 == 0) and RGB(205, 50, 45) or RGB(245, 240, 230)
	part(gerobak, "Atap", V3(2.1, 0.3, 5), V3(-4.2 + i * 2.1, roofY, 0), color, M.Fabric)
end

-- Papan nama di atas atap, dua sisi.
local papan = part(gerobak, "PapanNama", V3(6.5, 1.5, 0.2), V3(0, roofY + 1, 0), WOOD, M.Wood)
signText(papan, Enum.NormalId.Front, "TAHU JURAGAN", RGB(120, 40, 20), CREAM)
signText(papan, Enum.NormalId.Back, "TAHU JURAGAN", RGB(120, 40, 20), CREAM)

-- Papan harga di depan badan gerobak (sisi pembeli = +Z = Back face).
local papanDepan = part(gerobak, "PapanDepan", V3(5.5, 1.5, 0.15), V3(0, FLOOR + 1.9, 1.88), CREAM, M.SmoothPlastic)
signText(papanDepan, Enum.NormalId.Back, "Tahu Goreng  •  Rp 500/biji", RGB(90, 50, 20), CREAM)

-- Etalase kaca + tahu mateng pajangan.
part(gerobak, "Etalase", V3(3, 1.8, 2.8), V3(2.6, mejaTop + 0.9, 0.2), RGB(200, 230, 240), M.Glass, {
	Transparency = 0.6,
})
for i = 0, 5 do
	local tahu = part(gerobak, "TahuPajangan", V3(0.55, 0.55, 0.55), V3(
		2.6 - 0.8 + (i % 3) * 0.8,
		mejaTop + 0.3,
		0.2 - 0.4 + math.floor(i / 3) * 0.8
	), RGB(215, 150, 50), M.SmoothPlastic)
	tahu.Shape = Enum.PartType.Ball
end

-- Kompor + api.
local kompor = part(gerobak, "Kompor", V3(2.8, 0.8, 2.8), V3(-1.6, mejaTop + 0.4, -0.3), METAL, M.DiamondPlate)
local komporTop = kompor.Position.Y - GROUND + kompor.Size.Y / 2
disc(gerobak, "Api", 0.12, 1.6, V3(-1.6, komporTop + 0.06, -0.3), RGB(80, 150, 255), M.Neon)

-- ── WAJAN (ini yang dipake FryService) ────────────────────────────
local wajan = model(gerobak, "Wajan")
local pan = disc(wajan, "Pan", 0.5, 3.4, V3(-1.6, komporTop + 0.37, -0.3), RGB(40, 40, 44), M.Metal)
wajan.PrimaryPart = pan
local panTop = pan.Position.Y - GROUND + 0.25

local minyak = disc(wajan, "Minyak", 0.1, 2.9, V3(-1.6, panTop + 0.03, -0.3), RGB(230, 175, 60), M.SmoothPlastic, {
	Reflectance = 0.25,
	Transparency = 0.1,
	CanCollide = false,
})
for _, x in ipairs({ -1, 1 }) do
	part(wajan, "Gagang", V3(0.7, 0.2, 0.35), V3(-1.6 + x * 2, panTop - 0.05, -0.3), RGB(30, 30, 30), M.Plastic)
end

-- Asap (default texture bawaan, nyala cuma pas zona gosong).
local asap = Instance.new("ParticleEmitter")
asap.Name = "Asap"
asap.Enabled = false
asap.Color = ColorSequence.new(RGB(60, 60, 60), RGB(150, 150, 150))
asap.Transparency = NumberSequence.new(0.3, 1)
asap.Size = NumberSequence.new(0.6, 2.2)
asap.Lifetime = NumberRange.new(1, 1.6)
asap.Rate = 18
asap.Speed = NumberRange.new(2, 3.5)
asap.SpreadAngle = Vector2.new(15, 15)
asap.EmissionDirection = Enum.NormalId.Right -- silinder diputer: sumbu X lokal = atas
asap.Parent = minyak

local promptAttachment = Instance.new("Attachment")
promptAttachment.Name = "PromptAttachment"
promptAttachment.Parent = pan

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "GorengPrompt"
prompt.ActionText = "Goreng Tahu"
prompt.ObjectText = "Wajan"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Parent = promptAttachment

CollectionService:AddTag(wajan, "Wajan")

-- ── LAPAK TETANGGA (dekorasi biar kerasa pasar) ───────────────────
local function lapak(name, x, z, tarpColor, goodsColor)
	local m = model(pasar, name)
	part(m, "Meja", V3(7, 0.4, 3.5), V3(x, FLOOR + 2.8, z), WOOD, M.WoodPlanks)
	part(m, "Kolong", V3(6.6, 2.6, 3.1), V3(x, FLOOR + 1.3, z), WOOD_DARK, M.Wood)
	for _, dx in ipairs({ -3.3, 3.3 }) do
		for _, dz in ipairs({ -1.6, 1.6 }) do
			part(m, "Tiang", V3(0.25, 6.6, 0.25), V3(x + dx, FLOOR + 3.3, z + dz), METAL, M.Metal)
		end
	end
	part(m, "Terpal", V3(7.6, 0.2, 4.4), V3(x, FLOOR + 6.7, z), tarpColor, M.Fabric)
	for i = 0, 2 do
		part(m, "Barang", V3(1.6, 0.8, 1.2), V3(x - 2 + i * 2, FLOOR + 3.4, z), goodsColor, M.SmoothPlastic)
	end
end

lapak("LapakSayur", -16, 2, RGB(40, 110, 200), RGB(90, 170, 70))
lapak("LapakBuah", 16, 2, RGB(60, 150, 90), RGB(235, 150, 40))

-- Krat kayu di samping gerobak.
part(pasar, "Krat", V3(2, 1.6, 2), V3(7.2, FLOOR + 0.8, -1.5), WOOD, M.WoodPlanks)
part(pasar, "Krat", V3(2, 1.6, 2), V3(7.4, FLOOR + 2.4, -1.4), WOOD, M.WoodPlanks, {
	Orientation = V3(0, 15, 0),
})

pasar.Parent = workspace

-- ── SPAWN: di belakang gerobak (sisi tukang goreng), ngadep gerobak ─
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
if not spawn then
	spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Parent = workspace
end
spawn.Size = V3(6, 1, 6)
local spawnPos = ORIGIN + V3(0, 0.9, -10)
spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + V3(0, 0, 1))
spawn.Transparency = 0
spawn.Color = RGB(200, 190, 170)
spawn.Material = M.Concrete
local decal = spawn:FindFirstChildOfClass("Decal")
if decal then
	decal:Destroy()
end

return "ok"
