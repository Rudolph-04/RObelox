--[[
	Wajan + minyak + efek + prompt goreng. FryService nyari wajan lewat tag
	"Wajan" dan butuh: part "Minyak" (isi ParticleEmitter "Asap" & "Gelembung")
	+ satu ProximityPrompt di dalemnya.

	atasKompor = CFrame dunia di tengah permukaan atas kompor (ikut arah
	kendaraan). Mangkoknya = kulit bola (bola luar - bola dalam) yang dipotong
	rata di bibirnya, jadi cekung beneran kayak wajan.
]]

local CollectionService = game:GetService("CollectionService")

local Bantu = require(script.Parent.Parent.Bantu)

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local UPRIGHT = Bantu.UPRIGHT
local BESI = Bantu.WARNA.BESI

local TEBAL = 0.08

return function(parent, atasKompor, rimDiameter, depth)
	local function at(x, y)
		return atasKompor * CFrame.new(x, y, 0)
	end

	local wajan = Bantu.model(parent, "Wajan")
	local rimR = rimDiameter / 2
	local sphereR = (rimR * rimR + depth * depth) / (2 * depth) -- bola yang "tutupnya" selebar bibir
	local bottom = 0.15 -- dasar wajan di atas kompor (nangkring di tungku)
	local rim = bottom + depth
	local s = rimDiameter / 3.7 -- skala bagian kecil (ukuran awalnya buat wajan 3.7)
	local center = at(0, bottom + sphereR)

	local pan = Bantu.carve(wajan, "Pan", Bantu.ball(nil, "Luar", 2 * sphereR, center, BESI), {
		Bantu.ball(nil, "Dalam", 2 * (sphereR - TEBAL), center, BESI),
		Bantu.box(nil, "Potong", V3(10, 2 * sphereR, 10), at(0, rim + sphereR), BESI),
	}, RGB(38, 38, 42), M.Metal)
	wajan.PrimaryPart = pan

	Bantu.carve(wajan, "Bibir", Bantu.cylinder(nil, "Luar", 0.07, rimDiameter + 0.14, at(0, rim - 0.02) * UPRIGHT, BESI), {
		Bantu.cylinder(nil, "Dalam", 0.2, rimDiameter - 0.1, at(0, rim - 0.02) * UPRIGHT, BESI),
	}, RGB(55, 55, 60), M.Metal)

	-- Kuping wajan: cincin setengah lingkaran di kiri-kanan bibir.
	for _, sx in ipairs({ -1, 1 }) do
		local hx = sx * (rimR + 0.05)
		Bantu.carve(wajan, "Gagang", Bantu.cylinder(nil, "Luar", 0.09, 0.95 * s, at(hx, rim - 0.05) * UPRIGHT, BESI), {
			Bantu.cylinder(nil, "Dalam", 0.3, 0.65 * s, at(hx, rim - 0.05) * UPRIGHT, BESI),
			Bantu.box(nil, "Potong", V3(1, 1, 1.2), at(hx - sx * 0.5, rim - 0.05), BESI),
		}, RGB(30, 30, 32), M.Metal)
	end

	-- Tungku: ring dudukan wajan, apinya di dalem.
	Bantu.carve(wajan, "Tungku", Bantu.cylinder(nil, "Luar", 0.35, rimDiameter * 0.68, at(0, 0.175) * UPRIGHT, BESI), {
		Bantu.cylinder(nil, "Dalam", 0.5, rimDiameter * 0.54, at(0, 0.175) * UPRIGHT, BESI),
	}, RGB(25, 25, 27), M.CorrodedMetal)
	Bantu.cylinder(wajan, "Api", 0.1, rimDiameter * 0.4, at(0, 0.05) * UPRIGHT, RGB(80, 150, 255), M.Neon)

	-- Minyak setengah wajan, dua lapis: permukaan Glass yang mengkilap + badan
	-- amber di bawahnya (tanpa badan, di tempat teduh minyaknya keliatan item).
	-- Diameternya pas sama dinding dalem wajan di ketinggian itu.
	local oilY = bottom + TEBAL + depth * 0.5
	local innerR = sphereR - TEBAL
	local fromCenter = (bottom + sphereR) - oilY
	local oilD = 2 * math.sqrt(innerR * innerR - fromCenter * fromCenter) + 0.04
	local minyak = Bantu.cylinder(wajan, "Minyak", 0.06, oilD, at(0, oilY) * UPRIGHT, RGB(220, 155, 40), M.Glass, {
		Reflectance = 0.15,
		Transparency = 0.5,
	})
	Bantu.cylinder(wajan, "MinyakDalam", 0.08, oilD - 0.02, at(0, oilY - 0.07) * UPRIGHT, RGB(175, 112, 22), M.SmoothPlastic, {
		CanQuery = false,
	})

	local gelembung = Instance.new("ParticleEmitter")
	gelembung.Name = "Gelembung" -- nyala selama goreng (FryService)
	gelembung.Enabled = false
	gelembung.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	gelembung.Shape = Enum.ParticleEmitterShape.Cylinder
	gelembung.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	gelembung.EmissionDirection = Enum.NormalId.Right -- silinder diputer: sumbu X lokal = atas
	gelembung.Color = ColorSequence.new(RGB(255, 240, 200))
	gelembung.LightEmission = 0.3
	gelembung.Transparency = NumberSequence.new(0.2, 1)
	gelembung.Size = NumberSequence.new(0.07, 0.15)
	gelembung.Lifetime = NumberRange.new(0.25, 0.5)
	gelembung.Speed = NumberRange.new(0.3, 0.8)
	gelembung.Rate = 50
	gelembung.Parent = minyak

	local asap = Instance.new("ParticleEmitter")
	asap.Name = "Asap" -- nyala pas mulai gosong (FryService)
	asap.Enabled = false
	asap.Color = ColorSequence.new(RGB(60, 60, 60), RGB(150, 150, 150))
	asap.Transparency = NumberSequence.new(0.3, 1)
	asap.Size = NumberSequence.new(0.5, 2)
	asap.Lifetime = NumberRange.new(1, 1.6)
	asap.Rate = 18
	asap.Speed = NumberRange.new(2, 3.5)
	asap.SpreadAngle = Vector2.new(15, 15)
	asap.EmissionDirection = Enum.NormalId.Right
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
	prompt.MaxActivationDistance = 5
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAttachment

	CollectionService:AddTag(wajan, "Wajan")
	return wajan
end
