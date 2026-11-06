-- Model-model prototipe (prajurit, musuh, benteng, perlengkapan panglima),
-- dibikin dari part biasa lewat kode. ModuleScript di ServerScriptService.
--
-- Prajurit: semua part di-weld ke "Akar" (satu-satunya yang anchored, ada di
-- tanah tengah badan). Server cukup ngubah Akar.CFrame buat gerakin satu
-- prajurit, jadi yang dikirim ke client cuma 1 CFrame per prajurit.
-- Hadap depan = -Z lokal (server muter Akar biar ngadep +X / -X).
--
-- Gaya sengaja beda dari Patapon: badan bulet-panjang pake baju, kepala
-- bulet dua mata, ikat kepala. Tanpa tulisan, tanpa merek.

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

local TEGAK = CFrame.Angles(0, 0, math.rad(90)) -- silinder: sumbu X -> Y (berdiri)
local HADAP_DEPAN = CFrame.Angles(0, math.rad(90), 0) -- silinder: sumbu X -> Z (muka datar ngadep depan)

local KULIT = { RGB(222, 176, 128), RGB(196, 146, 100), RGB(160, 112, 74), RGB(124, 86, 58) }
local KAYU = RGB(140, 96, 56)
local KAYU_GELAP = RGB(98, 66, 40)
local BESI = RGB(170, 172, 178)
local HITAM = RGB(25, 22, 22)

local rng = Random.new()
local Bentuk = {}

local function part(model, nama, size, cf, warna, material, bentuk)
	local p = Instance.new("Part")
	p.Name = nama
	p.Size = size
	p.CFrame = cf
	p.Color = warna
	p.Material = material or M.SmoothPlastic
	if bentuk then
		p.Shape = bentuk
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Balok panjang dari titik a ke b (gagang, tali busur, ruas busur).
local function batang(model, nama, a, b, tebal, warna, material)
	return part(model, nama, V3(tebal, tebal, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), warna, material)
end

local function silinder(model, nama, panjang, diameter, cf, warna, material)
	return part(model, nama, V3(panjang, diameter, diameter), cf, warna, material, Enum.PartType.Cylinder)
end

local function bola(model, nama, diameter, pos, warna, material)
	return part(model, nama, V3(diameter, diameter, diameter), CFrame.new(pos), warna, material, Enum.PartType.Ball)
end

local function barHp(akar, tinggi, lebarPx, warnaIsi)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bar"
	bb.Size = UDim2.fromOffset(lebarPx, 6)
	bb.StudsOffset = V3(0, tinggi, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = akar
	local dasar = Instance.new("Frame")
	dasar.Size = UDim2.fromScale(1, 1)
	dasar.BackgroundColor3 = RGB(20, 20, 24)
	dasar.BackgroundTransparency = 0.3
	dasar.BorderSizePixel = 0
	dasar.Parent = bb
	local isi = Instance.new("Frame")
	isi.Name = "Isi"
	isi.Size = UDim2.fromScale(1, 1)
	isi.BackgroundColor3 = warnaIsi
	isi.BorderSizePixel = 0
	isi.Parent = dasar
	return isi
end

-- Semua part (selain akar) di-weld ke akar. Dipanggil abis semua part di posisinya.
local function rekat(model, akar)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= akar then
			local w = Instance.new("WeldConstraint")
			w.Part0 = akar
			w.Part1 = p
			w.Parent = p
		end
	end
end

-- ── SENJATA (koordinat lokal prajurit, depan = -Z) ─────────────────
local function tombak(m)
	local a, b = V3(0.85, 0.7, 0.55), V3(0.85, 4.3, -1.25)
	batang(m, "Gagang", a, b, 0.12, KAYU, M.Wood)
	local arah = (b - a).Unit
	batang(m, "MataTombak", b, b + arah * 0.65, 0.2, BESI, M.Metal)
end

local function perisai(m)
	silinder(m, "Perisai", 0.18, 1.75, CFrame.new(-0.75, 1.55, -0.72) * HADAP_DEPAN, KAYU, M.WoodPlanks)
	bola(m, "PakuPerisai", 0.36, V3(-0.75, 1.55, -0.84), BESI, M.Metal)
	part(m, "Golok", V3(0.06, 0.22, 1.1), CFrame.lookAt(V3(0.85, 1.55, -0.55), V3(0.85, 2.0, -1.4)), BESI, M.Metal)
end

local function busur(m)
	local titik = {}
	for _, derajat in ipairs({ -70, -35, 0, 35, 70 }) do
		local a = math.rad(derajat)
		table.insert(titik, V3(-0.72, 1.8 + 1.15 * math.sin(a), -0.75 - 0.42 * math.cos(a)))
	end
	for i = 1, #titik - 1 do
		batang(m, "Busur", titik[i], titik[i + 1], 0.11, KAYU_GELAP, M.Wood)
	end
	batang(m, "TaliBusur", titik[1], titik[#titik], 0.03, RGB(235, 230, 215))
	-- Wadah anak panah di punggung.
	silinder(m, "WadahPanah", 1.1, 0.36, CFrame.new(0.2, 2.0, 0.62) * CFrame.Angles(math.rad(18), 0, 0) * TEGAK, RGB(120, 80, 50), M.Fabric)
	for i, dx in ipairs({ -0.08, 0.06, 0.16 }) do
		part(m, "BuluPanah", V3(0.05, 0.25, 0.12), CFrame.new(0.2 + dx, 2.62 + i * 0.02, 0.78), RGB(230, 225, 210))
	end
end

local SENJATA = { Tombak = tombak, Perisai = perisai, Panah = busur }

-- opsi = { senjata = "Tombak"|"Perisai"|"Panah", baju = Color3, musuh = bool, warnaBar = Color3 }
-- Balikin model (PrimaryPart = Akar) + Frame isi bar HP.
function Bentuk.prajurit(opsi)
	local m = Instance.new("Model")
	m.Name = opsi.senjata

	-- Akar tepat di tanah (pivot model = Akar), setengahnya kependem, nggak keliatan.
	local akar = part(m, "Akar", V3(0.4, 0.4, 0.4), CFrame.new(), RGB(255, 255, 255))
	akar.Transparency = 1
	akar.Anchored = true
	m.PrimaryPart = akar

	local kulit = KULIT[rng:NextInteger(1, #KULIT)]
	local baju = opsi.baju
	local celana = opsi.musuh and RGB(40, 32, 30) or RGB(60, 52, 46)
	local ikat = opsi.musuh and HITAM or RGB(240, 236, 226)

	for _, sx in ipairs({ -1, 1 }) do
		part(m, "Kaki", V3(0.4, 0.95, 0.42), CFrame.new(sx * 0.3, 0.48, 0), celana)
	end
	silinder(m, "Badan", 1.35, 1.3, CFrame.new(0, 1.6, 0) * TEGAK, baju, M.Fabric)
	silinder(m, "Sabuk", 0.2, 1.36, CFrame.new(0, 1.0, 0) * TEGAK, KAYU_GELAP, M.Fabric)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "Lengan", V3(0.3, 0.95, 0.3), CFrame.new(sx * 0.8, 1.55, -0.12) * CFrame.Angles(math.rad(28), 0, 0), kulit)
	end

	local kepala = V3(0, 2.78, 0)
	bola(m, "Kepala", 1.15, kepala, kulit)
	silinder(m, "IkatKepala", 0.2, 1.2, CFrame.new(kepala + V3(0, 0.2, 0)) * TEGAK, ikat, M.Fabric)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "UjungIkat", V3(0.08, 0.5, 0.14), CFrame.new(sx * 0.1, kepala.Y - 0.05, 0.66) * CFrame.Angles(math.rad(25), 0, math.rad(sx * 12)), ikat, M.Fabric)
	end
	for _, sx in ipairs({ -1, 1 }) do
		bola(m, "Mata", 0.17, kepala + V3(sx * 0.2, 0.02, -0.52), HITAM)
	end
	if opsi.musuh then
		-- Kain penutup muka bagian bawah (biar keliatan "lawan").
		part(m, "Cadar", V3(0.95, 0.3, 0.3), CFrame.new(kepala + V3(0, -0.28, -0.42)), HITAM, M.Fabric)
	end

	SENJATA[opsi.senjata](m)
	rekat(m, akar)

	local isi = barHp(akar, 4.3, 44, opsi.warnaBar or RGB(110, 210, 120))
	return m, akar, isi
end

-- Benteng kayu di ujung stage (semua anchored, nggak gerak).
function Bentuk.benteng()
	local m = Instance.new("Model")
	m.Name = "Benteng"
	local akar = part(m, "Akar", V3(1, 1, 1), CFrame.new(), RGB(255, 255, 255))
	akar.Transparency = 1
	m.PrimaryPart = akar

	-- Pagar kayu gelondongan sepanjang Z, gerbang di tengah (tempat jalur lewat).
	local z = -10
	local i = 0
	while z <= 10 do
		i += 1
		local tinggi = 9 + (i % 3) * 0.7
		local diGerbang = math.abs(z) < 2.2
		local warna = diGerbang and KAYU_GELAP or KAYU
		silinder(m, "Gelondong", tinggi, 1.1, CFrame.new(0, tinggi / 2, z) * TEGAK, warna, M.Wood)
		bola(m, "UjungGelondong", 1.1, V3(0, tinggi, z), warna, M.Wood)
		z += 1.05
	end
	for _, y in ipairs({ 2.2, 6.5 }) do
		part(m, "Palang", V3(0.5, 0.5, 21.5), CFrame.new(-0.7, y, 0), KAYU_GELAP, M.Wood)
	end
	-- Bendera polos.
	silinder(m, "TiangBendera", 6, 0.2, CFrame.new(0, 12, -6) * TEGAK, KAYU_GELAP, M.Wood)
	part(m, "Bendera", V3(0.08, 1.6, 2.6), CFrame.new(0, 14, -7.3), RGB(140, 30, 34), M.Fabric)

	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	local isi = barHp(akar, 12, 140, RGB(220, 70, 60))
	isi.Parent.Parent.Size = UDim2.fromOffset(140, 10)
	return m, akar, isi
end

-- Golok di tangan kanan + kendang di pinggang avatar player. Diganti tiap respawn.
function Bentuk.perlengkapanPanglima(character)
	local lama = character:FindFirstChild("PerlengkapanPanglima")
	if lama then
		lama:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "PerlengkapanPanglima"

	local function tempel(induk, p, c0)
		p.Massless = true
		local w = Instance.new("Weld")
		w.Part0 = induk
		w.Part1 = p
		w.C0 = c0
		w.Parent = p
	end

	local tangan = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if tangan then
		local y = tangan.Name == "Right Arm" and -0.9 or -0.1
		tempel(tangan, part(m, "GagangGolok", V3(0.16, 0.16, 0.5), CFrame.new(), KAYU_GELAP, M.Wood), CFrame.new(0, y, -0.15))
		tempel(tangan, part(m, "BilahGolok", V3(0.06, 0.26, 2.0), CFrame.new(), BESI, M.Metal), CFrame.new(0, y, -1.4))
	end

	local pinggang = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if pinggang then
		local depan = -(pinggang.Size.Z / 2 + 0.45)
		local y = pinggang.Name == "Torso" and -0.7 or 0
		tempel(pinggang, silinder(m, "Kendang", 1.3, 0.85, CFrame.new(), KAYU, M.Wood), CFrame.new(0, y, depan))
		for _, sx in ipairs({ -1, 1 }) do
			tempel(pinggang, silinder(m, "KulitKendang", 0.05, 0.8, CFrame.new(), RGB(236, 222, 190), M.Fabric), CFrame.new(sx * 0.66, y, depan))
		end
	end

	m.Parent = character
	return m
end

return Bentuk
