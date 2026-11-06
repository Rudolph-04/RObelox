-- Bagian server dari tampilan (ModuleScript di ServerScriptService).
--
--   akar()                 unit prajurit/musuh versi server: cuma 1 part nggak
--                          keliatan + bar HP + atribut Jenis/Warna/Musuh. Badan &
--                          animasinya dibikin client (LaskarPrajurit).
--   benteng()              benteng kayu di ujung stage (statis)
--   perlengkapanPanglima() senjata avatar player sesuai peran panglima
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

-- Senjata avatar player sesuai peran panglima (Perisai: tameng + golok,
-- Pedang, Tombak, Panah: busur + wadah panah). Diganti tiap respawn / ganti peran.
function Bentuk.perlengkapanPanglima(character, peran)
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
	-- Balok dari titik a ke b (di ruang lokal tangan).
	local function ruas(induk, nama, a, b, tebal, warna, material)
		local atas = math.abs((b - a).Unit.Y) > 0.99 and Vector3.zAxis or Vector3.yAxis
		tempel(induk, part(m, nama, V3(tebal, tebal, (b - a).Magnitude), CFrame.new(), warna, material), CFrame.lookAt((a + b) / 2, b, atas))
	end

	local kanan = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local kiri = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local punggung = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local function yTangan(t)
		return (t.Name == "Right Arm" or t.Name == "Left Arm") and -0.9 or -0.1
	end

	if peran == "Perisai" then
		if kanan then
			local y = yTangan(kanan)
			tempel(kanan, part(m, "GagangGolok", V3(0.16, 0.16, 0.5), CFrame.new(), KAYU_GELAP, M.Wood), CFrame.new(0, y, -0.15))
			tempel(kanan, part(m, "BilahGolok", V3(0.06, 0.26, 2.0), CFrame.new(), BESI, M.Metal), CFrame.new(0, y, -1.4))
		end
		if kiri then
			local y = yTangan(kiri)
			tempel(kiri, silinder(m, "Tameng", 0.16, 2.1, CFrame.new(), KAYU, M.WoodPlanks), CFrame.new(0, y, -0.35) * CFrame.Angles(0, math.rad(90), 0))
			tempel(kiri, bola(m, "PakuTameng", 0.4, V3(), BESI, M.Metal), CFrame.new(0, y, -0.45))
		end
	elseif peran == "Tombak" then
		if kanan then
			local y = yTangan(kanan)
			tempel(kanan, part(m, "GagangTombak", V3(0.14, 0.14, 5.5), CFrame.new(), KAYU, M.Wood), CFrame.new(0, y, -1.8))
			tempel(kanan, part(m, "MataTombak", V3(0.08, 0.36, 0.8), CFrame.new(), BESI, M.Metal), CFrame.new(0, y, -4.9))
		end
	elseif peran == "Panah" then
		if kiri then
			local y = yTangan(kiri)
			local titik = {}
			for _, derajat in ipairs({ -70, -35, 0, 35, 70 }) do
				local a = math.rad(derajat)
				table.insert(titik, V3(0, y + 1.6 * math.sin(a), -0.55 * math.cos(a) + 0.1))
			end
			for i = 1, #titik - 1 do
				ruas(kiri, "Busur", titik[i], titik[i + 1], 0.12, KAYU_GELAP, M.Wood)
			end
			ruas(kiri, "TaliBusur", titik[1], titik[#titik], 0.03, RGB(235, 230, 215))
		end
		if punggung then
			tempel(punggung, silinder(m, "WadahPanah", 1.6, 0.45, CFrame.new(), RGB(120, 80, 50), M.Fabric), CFrame.new(0.35, 0.2, punggung.Size.Z / 2 + 0.25) * CFrame.Angles(math.rad(-15), 0, 0) * TEGAK)
		end
	else -- Pedang
		if kanan then
			local y = yTangan(kanan)
			tempel(kanan, part(m, "GagangPedang", V3(0.16, 0.16, 0.5), CFrame.new(), KAYU_GELAP, M.Wood), CFrame.new(0, y, -0.05))
			tempel(kanan, part(m, "PelindungPedang", V3(0.7, 0.12, 0.14), CFrame.new(), RGB(200, 170, 80), M.Metal), CFrame.new(0, y, -0.32))
			tempel(kanan, part(m, "BilahPedang", V3(0.08, 0.3, 2.8), CFrame.new(), BESI, M.Metal), CFrame.new(0, y, -1.8))
		end
	end

	m.Parent = character
	return m
end

return Bentuk
