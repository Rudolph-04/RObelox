-- Bagian server dari tampilan (ModuleScript di ServerScriptService).
--
--   akar()                 unit prajurit/musuh versi server: cuma 1 part nggak
--                          keliatan + bar HP + atribut Jenis/Warna/Musuh. Badan &
--                          animasinya dibikin client (LaskarPrajurit).
--   benteng()              benteng kayu di ujung stage (statis)
--   perlengkapanPanglima() golok di tangan kanan avatar player
--
-- Tanpa tulisan, tanpa merek, tanpa desain karakter Patapon.

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

local TEGAK = CFrame.Angles(0, 0, math.rad(90)) -- silinder: sumbu X -> Y (berdiri)

local KAYU = RGB(140, 96, 56)
local KAYU_GELAP = RGB(98, 66, 40)
local BESI = RGB(170, 172, 178)

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

-- Unit versi server. Akar = titik di tanah tengah badan; server cuma gerakin
-- ini (CFrame) & nambahin atribut "SerangKe" tiap nyerang.
function Bentuk.akar(jenis, warna, musuh)
	local akar = part(nil, "Akar", V3(1, 1, 1), CFrame.new(), RGB(255, 255, 255))
	akar.Transparency = 1
	akar.Anchored = true
	akar:SetAttribute("Jenis", jenis)
	akar:SetAttribute("Warna", warna)
	akar:SetAttribute("Musuh", musuh == true)
	akar:SetAttribute("SerangKe", 0)
	local isi = barHp(akar, 4.3, 44, musuh and RGB(220, 70, 60) or RGB(110, 210, 120))
	return akar, isi
end

-- Benteng kayu di ujung stage (semua anchored, nggak gerak).
function Bentuk.benteng()
	local m = Instance.new("Model")
	m.Name = "Benteng"
	-- Bukan "Akar": client nyari part bernama Akar buat digambar jadi prajurit.
	local akar = part(m, "AkarBenteng", V3(1, 1, 1), CFrame.new(), RGB(255, 255, 255))
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

-- Golok di tangan kanan avatar player. Diganti tiap respawn.
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

	m.Parent = character
	return m
end

return Bentuk
