-- Tampilan + animasi prajurit & musuh (ModuleScript di StarterPlayerScripts,
-- dipanggil LaskarClient).
--
-- Server cuma punya "Akar" (part nggak keliatan) per unit: posisi, arah hadap,
-- bar HP, atribut Jenis/Warna/Musuh, dan "SerangKe" (nambah tiap nyerang).
-- Client yang bikin badannya & gerakin tiap frame, jadi animasinya bisa
-- detail tanpa makan jaringan.
--
-- Desain: "bakso" bulet bermata satu (coklat berbintil, BUKAN siluet hitam
-- polos kayak Patapon), alis, mulut, selempang warna pasukan, kaki & tangan
-- lidi. Topi per kelas: Perisai = helm, Pedang = ikat kepala warna pasukan,
-- Tombak = ikat kepala + bulu, Panah = caping, Bendera = peci warna pasukan.
-- Musuh: "bakso gosong", mata merah, bertanduk.
--
-- Animasi:
--   tiap ketukan       : loncat kecil (semua unit ikut ngedenyut sama musik)
--   jawab perintah     : loncat tinggi + tangan ke atas + mulut kebuka (TAHAN: jongkok)
--   jalan              : kaki melangkah, tangan ngayun, badan naik-turun
--   nunggu             : celingak-celinguk, goyang-goyang, ketuk kaki; pasukan
--                        sendiri nyeletuk ("Nunggu apa nih?") tiap ~10 detik
--   nyerang            : Tombak nusuk, Perisai/Pedang mbacok, Panah narik busur
--   bendera            : kibar pelan, kenceng pas jawab perintah
--   mati               : jatuh ke belakang terus ilang
--   SEMANGAT           : sorot emas + loncat lebih tinggi
-- Badan diserongin ~35 derajat ke kamera biar matanya keliatan dari samping.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local C = require(ReplicatedStorage:WaitForChild("LaskarConfig"))

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local HADAP_DEPAN = CFrame.Angles(0, math.rad(90), 0) -- silinder: sumbu X -> Z
local TEGAK = CFrame.Angles(0, 0, math.rad(90)) -- silinder: sumbu X -> Y

local BAKSO = RGB(168, 136, 106)
local BAKSO_BINTIL = RGB(140, 110, 84)
local BAKSO_GOSONG = RGB(70, 48, 40)
local PUTIH_MATA = RGB(250, 250, 246)
local HITAM = RGB(24, 20, 20)
local MERAH = RGB(196, 48, 40)
local KAYU = RGB(140, 96, 56)
local KAYU_GELAP = RGB(98, 66, 40)
local BESI = RGB(176, 178, 184)
local JERAMI = RGB(222, 190, 120)
local TULANG = RGB(232, 222, 196)

local SERONG = math.rad(35) -- badan diputer segini ke arah kamera
local LAMA_SERANG = 0.4
local LAMA_MATI = 0.55

-- Engsel (relatif Akar = tanah di tengah badan, depan = -Z).
local ENGSEL = {
	badan = CFrame.new(),
	kakiL = CFrame.new(-0.28, 0.9, 0),
	kakiR = CFrame.new(0.28, 0.9, 0),
	lenganL = CFrame.new(-0.82, 1.65, 0),
	lenganR = CFrame.new(0.82, 1.65, 0),
}

-- Sudut dasar lengan (radian, + = keangkat ke depan) per jenis senjata.
local SUDUT_DASAR = {
	Tombak = { lenganL = 0.15, lenganR = math.rad(15) },
	Perisai = { lenganL = math.rad(50), lenganR = math.rad(20) },
	Panah = { lenganL = math.rad(90), lenganR = math.rad(25) },
	Pedang = { lenganL = 0.15, lenganR = math.rad(25) },
	Bendera = { lenganL = math.rad(35), lenganR = math.rad(30) },
}

-- Titik di permukaan badan buat bintil bakso (sudut horizontal, tinggi), jauh dari mata.
local BINTIL = { { 100, 0.3 }, { 150, -0.2 }, { 200, 0.45 }, { 250, -0.35 }, { 300, 0.15 }, { 60, -0.5 }, { 180, 0.75 } }

local Prajurit = {}

local folderVisual
local rigs = {} -- [akar] = rig
local MULAI
local kamera = workspace.CurrentCamera

-- ── BIKIN BADAN ────────────────────────────────────────────────────
local function arahLengan(sudut)
	return V3(0, -math.cos(sudut), -math.sin(sudut))
end

local function bikinRig(jenis, warna, musuh)
	local senjata = C.MUSUH[jenis] and C.MUSUH[jenis].senjata or jenis
	local dasar = SUDUT_DASAR[senjata] or SUDUT_DASAR.Tombak
	local model = Instance.new("Model")
	model.Name = jenis
	local rig = { model = model, parts = {}, grup = {}, offset = {}, senjata = senjata, musuh = musuh, dasar = dasar, warna = warna }

	-- Part ditaruh di pose dasarnya; offset disimpen relatif engsel grup (yang udah diputer sudut dasar).
	local function pivotDasar(grup)
		local sudut = dasar[grup] or 0
		return ENGSEL[grup] * CFrame.Angles(sudut, 0, 0)
	end
	local function tambah(grup, nama, size, cf, warnaP, material, bentuk, bayangan)
		local p = Instance.new("Part")
		p.Name = nama
		p.Size = size
		p.CFrame = cf
		p.Color = warnaP
		p.Material = material or M.SmoothPlastic
		if bentuk then
			p.Shape = bentuk
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = bayangan ~= false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(rig.parts, p)
		table.insert(rig.grup, grup)
		table.insert(rig.offset, pivotDasar(grup):Inverse() * cf)
		return p
	end
	local function lidi(grup, nama, a, b, tebal, warnaP, material)
		-- Arah tegak lurus ke atas/bawah: vektor "atas" lookAt diganti biar nggak rusak.
		local atas = math.abs((b - a).Unit.Y) > 0.99 and Vector3.zAxis or Vector3.yAxis
		local cf = CFrame.lookAt((a + b) / 2, b, atas) * HADAP_DEPAN -- sumbu silinder searah a->b
		return tambah(grup, nama, V3((b - a).Magnitude, tebal, tebal), cf, warnaP, material, Enum.PartType.Cylinder)
	end
	local function bola(grup, nama, d, pos, warnaP, material)
		return tambah(grup, nama, V3(d, d, d), CFrame.new(pos), warnaP, material, Enum.PartType.Ball)
	end

	local warnaBadan = musuh and BAKSO_GOSONG or BAKSO

	-- Kaki lidi + telapak bulet.
	for _, sx in ipairs({ -1, 1 }) do
		local grup = sx < 0 and "kakiL" or "kakiR"
		lidi(grup, "Kaki", V3(sx * 0.28, 0.95, 0), V3(sx * 0.28, 0.14, 0), 0.14, HITAM)
		bola(grup, "Telapak", 0.28, V3(sx * 0.28, 0.13, -0.07), HITAM)
	end

	-- Badan bakso + bintil-bintil.
	local pusat = V3(0, 1.85, 0)
	rig.badanPart = bola("badan", "Badan", 1.9, pusat, warnaBadan, M.Sand)
	for _, b in ipairs(BINTIL) do
		local a = math.rad(b[1])
		local arah = V3(math.sin(a) * math.sqrt(1 - b[2] ^ 2), b[2], math.cos(a) * math.sqrt(1 - b[2] ^ 2))
		bola("badan", "Bintil", 0.32, pusat + arah * 0.9, musuh and RGB(52, 36, 30) or BAKSO_BINTIL, M.Sand)
	end

	-- Satu mata gede + pupil + kilau.
	bola("badan", "Mata", 1.0, V3(0, 2.0, -0.62), musuh and RGB(240, 220, 150) or PUTIH_MATA)
	bola("badan", "Pupil", 0.46, V3(0, 2.0, -1.02), musuh and RGB(220, 40, 30) or HITAM, musuh and M.Neon or M.SmoothPlastic)
	bola("badan", "Kilau", 0.12, V3(0.1, 2.12, -1.24), RGB(255, 255, 255))

	-- Alis: dua potong, miring galak buat Tombak, Pedang & musuh.
	local galak = musuh or senjata == "Tombak" or senjata == "Pedang"
	for _, sx in ipairs({ -1, 1 }) do
		local miring = galak and sx * math.rad(-16) or sx * math.rad(6)
		tambah("badan", "Alis", V3(0.46, 0.13, 0.12), CFrame.new(sx * 0.24, 2.62, -0.86) * CFrame.Angles(0, 0, miring), HITAM)
	end

	-- Mulut: garis kalau diem, bulet kebuka pas jawab perintah.
	rig.mulutTutup = tambah("badan", "Mulut", V3(0.32, 0.06, 0.06), CFrame.new(0, 1.36, -0.82), HITAM)
	rig.mulutBuka = bola("badan", "MulutBuka", 0.36, V3(0, 1.36, -0.78), RGB(90, 20, 24))
	rig.mulutBuka.Transparency = 1

	if musuh then
		for _, sx in ipairs({ -1, 1 }) do
			lidi("badan", "Tanduk", V3(sx * 0.45, 2.5, 0), V3(sx * 0.75, 3.15, 0.1), 0.16, TULANG)
		end
	else
		-- Selempang warna pasukan.
		tambah("badan", "Selempang", V3(0.24, 1.62, 1.62), CFrame.new(0, 1.3, 0) * TEGAK, warna, M.Fabric, Enum.PartType.Cylinder)
		if senjata == "Tombak" or senjata == "Pedang" then
			tambah("badan", "IkatKepala", V3(0.16, 1.5, 1.5), CFrame.new(0, 2.5, 0) * TEGAK, senjata == "Pedang" and warna or RGB(240, 236, 226), M.Fabric, Enum.PartType.Cylinder)
			if senjata == "Tombak" then
				for i, miring in ipairs({ -18, 0, 18 }) do
					lidi("badan", "Bulu", V3(0, 2.75, 0.1), V3(math.rad(miring) * 1.2, 3.35 + (i == 2 and 0.15 or 0), 0.5), 0.1, MERAH, M.Fabric)
				end
			else
				for _, sx in ipairs({ -1, 1 }) do
					lidi("badan", "UjungIkat", V3(0, 2.5, 0.72), V3(sx * 0.25, 2.1, 1.15), 0.1, warna, M.Fabric)
				end
			end
		elseif senjata == "Perisai" then
			tambah("badan", "PinggirHelm", V3(0.12, 1.95, 1.95), CFrame.new(0, 2.5, 0.05) * TEGAK, BESI, M.Metal, Enum.PartType.Cylinder)
			bola("badan", "Helm", 1.5, V3(0, 2.6, 0.1), BESI, M.Metal)
			lidi("badan", "TandukHelm", V3(0, 3.25, 0.1), V3(0, 3.6, 0.1), 0.14, BESI, M.Metal)
		elseif senjata == "Bendera" then
			tambah("badan", "Peci", V3(0.4, 1.25, 1.25), CFrame.new(0, 2.78, 0.05) * TEGAK, warna, M.Fabric, Enum.PartType.Cylinder)
		else -- Panah: caping
			for i, ukuran in ipairs({ { 2.3, 0.1 }, { 1.4, 0.22 }, { 0.6, 0.24 } }) do
				local y = 2.72 + (i - 1) * 0.16
				tambah("badan", "Caping", V3(ukuran[2], ukuran[1], ukuran[1]), CFrame.new(0, y, 0.05) * TEGAK, JERAMI, M.Fabric, Enum.PartType.Cylinder)
			end
		end
	end

	-- Lengan lidi + tangan, dipasang di pose dasarnya.
	local tangan = {}
	for _, sx in ipairs({ -1, 1 }) do
		local grup = sx < 0 and "lenganL" or "lenganR"
		local bahu = ENGSEL[grup].Position
		local arah = arahLengan(dasar[grup])
		lidi(grup, "Lengan", bahu, bahu + arah * 0.72, 0.13, HITAM)
		tangan[grup] = bahu + arah * 0.74
		bola(grup, "Tangan", 0.22, tangan[grup], HITAM)
	end

	-- Senjata.
	if senjata == "Tombak" then
		local h = tangan.lenganR
		local arah = V3(0, math.cos(math.rad(12)), -math.sin(math.rad(12)))
		lidi("lenganR", "Gagang", h - arah * 1.0, h + arah * 2.4, 0.1, KAYU, M.Wood)
		local ujung = h + arah * 2.4
		tambah("lenganR", "MataTombak", V3(0.06, 0.6, 0.2), CFrame.lookAt(ujung + arah * 0.3, ujung + arah * 0.3 + V3(1, 0, 0)), BESI, M.Metal)
	elseif senjata == "Perisai" then
		local h = tangan.lenganL
		tambah("lenganL", "Perisai", V3(0.16, 1.55, 1.55), CFrame.new(h + V3(0, 0.1, -0.2)) * HADAP_DEPAN, KAYU, M.WoodPlanks, Enum.PartType.Cylinder)
		bola("lenganL", "PakuPerisai", 0.34, h + V3(0, 0.1, -0.32), BESI, M.Metal)
		local g = tangan.lenganR
		local arah = V3(0, 0.45, -0.89)
		tambah("lenganR", "Golok", V3(0.06, 0.2, 1.0), CFrame.lookAt(g + arah * 0.55, g + arah * 1.1), BESI, M.Metal)
	elseif senjata == "Pedang" then
		local g = tangan.lenganR
		local arah = V3(0, 0.55, -0.84)
		lidi("lenganR", "GagangPedang", g - arah * 0.15, g + arah * 0.2, 0.12, KAYU_GELAP, M.Wood)
		tambah("lenganR", "PelindungPedang", V3(0.5, 0.08, 0.1), CFrame.lookAt(g + arah * 0.22, g + arah * 1.0), RGB(200, 170, 80), M.Metal)
		tambah("lenganR", "BilahPedang", V3(0.06, 0.2, 1.5), CFrame.lookAt(g + arah * 0.98, g + arah * 2.0), BESI, M.Metal)
	elseif senjata == "Bendera" then
		-- Tiang dipegang tangan kanan, kain warna pasukan berkibar ke belakang.
		local g = tangan.lenganR
		local arah = V3(0, math.cos(math.rad(8)), math.sin(math.rad(8)))
		lidi("lenganR", "TiangBendera", g - arah * 0.8, g + arah * 4.2, 0.12, KAYU, M.Wood)
		local puncak = g + arah * 4.2
		bola("lenganR", "PucukTiang", 0.26, puncak + arah * 0.1, RGB(220, 190, 80), M.Metal)
		local kain = puncak - arah * 0.75 + V3(0, 0, 0.85)
		tambah("lenganR", "KainBendera", V3(0.06, 1.2, 1.6), CFrame.new(kain), rig.warna, M.Fabric)
		tambah("lenganR", "LambangBendera", V3(0.09, 0.6, 0.6), CFrame.new(kain), RGB(250, 246, 236), M.Fabric, Enum.PartType.Cylinder)
	else
		-- Busur tegak di depan tangan kiri (lengan kiri dasarnya lurus ke depan).
		local h = tangan.lenganL
		local titik = {}
		for _, derajat in ipairs({ -70, -35, 0, 35, 70 }) do
			local a = math.rad(derajat)
			table.insert(titik, h + V3(0, 1.1 * math.sin(a), -0.38 * math.cos(a) + 0.05))
		end
		for i = 1, #titik - 1 do
			lidi("lenganL", "Busur", titik[i], titik[i + 1], 0.1, KAYU_GELAP, M.Wood)
		end
		lidi("lenganL", "TaliBusur", titik[1], titik[#titik], 0.03, RGB(235, 230, 215))
		lidi("badan", "WadahPanah", V3(0.35, 1.55, 0.78), V3(0.6, 2.75, 0.55), 0.34, RGB(120, 80, 50), M.Fabric)
	end

	return rig
end

-- ── POSE ───────────────────────────────────────────────────────────
-- Kurva patah-patah: nilai di titik-titik yang jaraknya sama, k = 0..1.
local function kurva(k, titik)
	local n = #titik - 1
	local x = math.clamp(k, 0, 1) * n
	local i = math.min(math.floor(x), n - 1)
	local f = x - i
	return titik[i + 1] + (titik[i + 2] - titik[i + 1]) * f
end

local function lompatan(p, lama)
	return math.sin(math.pi * math.clamp(p / lama, 0, 1))
end

local parts, cfs = {}, {}

local function pose(rig, akarCF, t, posisiKetukan, dt)
	local n = math.floor(posisiKetukan)
	local p = posisiKetukan - n
	local army = rig.army
	local jawab, semangat, perintah = false, false, nil
	if army then
		local mulai, selesai = army:GetAttribute("JawabMulai"), army:GetAttribute("JawabSelesai")
		jawab = mulai ~= nil and n >= mulai and n <= selesai
		semangat = army:GetAttribute("Semangat") == true
		perintah = army:GetAttribute("Perintah")
	end

	-- Jalan: dari perubahan posisi Akar.
	local pos = akarCF.Position
	local kecepatan = rig.posTerakhir and (pos - rig.posTerakhir).Magnitude / math.max(dt, 1e-3) or 0
	rig.posTerakhir = pos
	rig.jalan = rig.jalan + ((kecepatan > 1 and 1 or 0) - rig.jalan) * math.min(1, dt * 10)
	local siklus = t * 13 + rig.fase
	local ayun = math.sin(siklus) * math.rad(38) * rig.jalan

	local y = (rig.musuh and 0.06 or 0.14) * lompatan(p, 0.3) -- denyut ketukan
	y += math.abs(math.sin(siklus)) * 0.09 * rig.jalan
	local angkat = 0
	local jongkok = 0
	if jawab then
		if perintah == "Tahan" then
			jongkok = 0.28
		else
			local l = lompatan(p, 0.45)
			y += (semangat and 0.75 or 0.5) * l
			angkat = math.rad(150) * l
		end
	end

	local dL = -ayun * 0.6 + angkat
	local dR = ayun * 0.6 + angkat
	if rig.senjata == "Bendera" then
		-- Kibar: pelan pas diem, kenceng pas jawab perintah. Tiangnya nggak ikut diangkat tinggi.
		dR = math.sin(t * (jawab and 9 or 2.5) + rig.fase) * math.rad(jawab and 14 or 4)
		dL = -ayun * 0.3 + angkat * 0.3
	elseif rig.senjata == "Panah" then
		dL = -ayun * 0.15 -- busur tetep di depan
	elseif rig.senjata == "Perisai" then
		dL = -ayun * 0.2 + (jongkok > 0 and math.rad(35) or 0)
	end

	-- Nyerang.
	local maju = 0
	local s = (os.clock() - rig.serangMulai) / LAMA_SERANG
	if s < 1 then
		maju = math.sin(s * math.pi) * (rig.senjata == "Panah" and 0.1 or 0.6)
		if rig.senjata == "Tombak" then
			dR = math.rad(kurva(s, { 0, 25, -95, -95, 0 }))
		elseif rig.senjata == "Perisai" then
			dR = math.rad(kurva(s, { 0, 120, 30, 30, 0 }))
		else
			dR = math.rad(kurva(s, { 0, 60, 70, 40, 0 }))
		end
	end

	-- Nunggu perintah: celingak-celinguk, goyang dikit, ketuk-ketuk kaki.
	local diam = not jawab and rig.jalan < 0.1 and s >= 1
	local celingak = diam and math.sin(t * 0.7 + rig.fase) * math.rad(18) or 0
	local goyang = diam and math.sin(t * 1.9 + rig.fase) * math.rad(4) or 0
	local ketuk = diam and math.max(0, math.sin(t * 5 + rig.fase)) * math.rad(-14) or 0

	-- Mulut kebuka pas "jawab" perintah.
	local teriak = jawab and perintah ~= "Tahan"
	if teriak ~= rig.teriak and rig.mulutBuka then
		rig.teriak = teriak
		rig.mulutBuka.Transparency = teriak and 0 or 1
		rig.mulutTutup.Transparency = teriak and 1 or 0
	end

	-- Serongin ke kamera (+Z), apa pun arah hadapnya.
	local hadap = akarCF.LookVector.X >= 0 and 1 or -1
	local akar = akarCF * CFrame.Angles(0, -SERONG * hadap + celingak, goyang) * CFrame.new(0, y - jongkok, -maju)

	-- Mati: jatuh ke belakang sambil ambles.
	if rig.mati then
		local k = math.clamp((os.clock() - rig.mati) / LAMA_MATI, 0, 1)
		akar = rig.cfMati * CFrame.new(0, -k * 0.6, 0) * CFrame.Angles(k * math.rad(85), 0, 0)
		dL, dR, ayun = math.rad(120), math.rad(120), 0
	end

	local grupCF = {
		badan = akar,
		kakiL = akar * ENGSEL.kakiL * CFrame.Angles(ayun, 0, 0),
		kakiR = akar * ENGSEL.kakiR * CFrame.Angles(-ayun + ketuk, 0, 0),
		lenganL = akar * ENGSEL.lenganL * CFrame.Angles(rig.dasar.lenganL + dL, 0, 0),
		lenganR = akar * ENGSEL.lenganR * CFrame.Angles(rig.dasar.lenganR + dR, 0, 0),
	}
	rig.cfTerakhir = akar
	return grupCF
end

-- ── CELETUKAN ──────────────────────────────────────────────────────
local acakCeletuk = Random.new()
local celetukTerakhir = 0

local function celetuk(rig, isi)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Celetuk"
	bb.Size = UDim2.fromOffset(180, 40)
	bb.StudsOffset = V3(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = RGB(252, 250, 244)
	label.TextColor3 = RGB(40, 34, 30)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = isi
	label.Parent = bb
	local sudut = Instance.new("UICorner")
	sudut.CornerRadius = UDim.new(0, 12)
	sudut.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = label
	bb.Parent = rig.badanPart
	task.delay(3, function()
		bb:Destroy()
	end)
end

-- Pasukan player ini nyeletuk kalau udah CELETUK_DETIK nggak dikasih perintah.
local function cekCeletuk(posisiKetukan, waktuAwal)
	local folder = workspace:FindFirstChild("Pasukan")
	local armyKu = folder and folder:FindFirstChild("Pasukan_" .. Players.LocalPlayer.UserId)
	if not armyKu or os.clock() - celetukTerakhir < C.CELETUK_DETIK then
		return
	end
	local selesai = armyKu:GetAttribute("JawabSelesai")
	local diamSejak = selesai and (selesai + 1) or (waktuAwal - MULAI) / C.KETUKAN
	if (posisiKetukan - diamSejak) * C.KETUKAN < C.CELETUK_DETIK then
		return
	end
	local calon = {}
	for _, rig in pairs(rigs) do
		if rig.army == armyKu and not rig.mati and rig.badanPart then
			table.insert(calon, rig)
		end
	end
	if #calon > 0 then
		celetuk(calon[acakCeletuk:NextInteger(1, #calon)], C.CELETUK[acakCeletuk:NextInteger(1, #C.CELETUK)])
		celetukTerakhir = os.clock()
	end
end

-- ── DAFTAR UNIT ────────────────────────────────────────────────────
local function wadah(nama)
	local m = folderVisual:FindFirstChild(nama)
	if not m then
		m = Instance.new("Model")
		m.Name = nama
		local sorot = Instance.new("Highlight") -- nyala pas SEMANGAT
		sorot.FillColor = RGB(255, 205, 90)
		sorot.FillTransparency = 0.8
		sorot.OutlineColor = RGB(255, 220, 120)
		sorot.OutlineTransparency = 0.3
		sorot.DepthMode = Enum.HighlightDepthMode.Occluded
		sorot.Enabled = false
		sorot.Parent = m
		m.Parent = folderVisual
	end
	return m
end

local function daftar(akar)
	if rigs[akar] or not akar:IsA("BasePart") or akar.Name ~= "Akar" then
		return
	end
	local jenis = akar:GetAttribute("Jenis")
	if not jenis then
		return
	end
	local musuh = akar:GetAttribute("Musuh") == true
	local rig = bikinRig(jenis, akar:GetAttribute("Warna") or RGB(52, 92, 168), musuh)
	rig.akar = akar
	rig.army = (not musuh and akar.Parent and akar.Parent:IsA("Model")) and akar.Parent or nil
	rig.fase = math.random() * math.pi * 2
	rig.jalan = 0
	rig.serangMulai = -10
	rig.model.Parent = wadah(rig.army and rig.army.Name or "Musuh")
	rigs[akar] = rig

	akar:GetAttributeChangedSignal("SerangKe"):Connect(function()
		rig.serangMulai = os.clock()
	end)
	akar.AncestryChanged:Connect(function()
		if not akar:IsDescendantOf(workspace) and not rig.mati then
			rig.mati = os.clock()
			rig.cfMati = rig.cfTerakhir or akar.CFrame
		end
	end)
end

local function pantau(folder)
	for _, d in ipairs(folder:GetDescendants()) do
		daftar(d)
	end
	folder.DescendantAdded:Connect(function(d)
		-- Atribut kadang nyampe sedikit telat dari part-nya.
		if d:IsA("BasePart") and d.Name == "Akar" then
			if d:GetAttribute("Jenis") then
				daftar(d)
			else
				d:GetAttributeChangedSignal("Jenis"):Once(function()
					daftar(d)
				end)
			end
		end
	end)
end

function Prajurit.mulai()
	if folderVisual then
		return
	end
	folderVisual = Instance.new("Folder")
	folderVisual.Name = "PrajuritVisual"
	folderVisual.Parent = workspace

	MULAI = ReplicatedStorage:GetAttribute("MulaiKetukan")
	local waktuAwal = workspace:GetServerTimeNow()
	task.spawn(function()
		pantau(workspace:WaitForChild("Pasukan"))
	end)
	task.spawn(function()
		pantau(workspace:WaitForChild("Musuh"))
	end)

	RunService.RenderStepped:Connect(function(dt)
		MULAI = MULAI or ReplicatedStorage:GetAttribute("MulaiKetukan")
		if not MULAI then
			return
		end
		local t = os.clock()
		local posisiKetukan = (workspace:GetServerTimeNow() - MULAI) / C.KETUKAN
		local kameraX = kamera.CFrame.Position.X
		local n = 0
		table.clear(parts)
		table.clear(cfs)

		for akar, rig in pairs(rigs) do
			if rig.mati and os.clock() - rig.mati > LAMA_MATI + 0.15 then
				rig.model:Destroy()
				rigs[akar] = nil
			else
				local akarCF = rig.mati and rig.cfMati or akar.CFrame
				if math.abs(akarCF.Position.X - kameraX) < 120 then
					local grupCF = pose(rig, akarCF, t, posisiKetukan, dt)
					for i, part in ipairs(rig.parts) do
						n += 1
						parts[n] = part
						cfs[n] = grupCF[rig.grup[i]] * rig.offset[i]
					end
				end
			end
		end
		if n > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		cekCeletuk(posisiKetukan, waktuAwal)

		-- Sorot SEMANGAT per pasukan.
		for _, m in ipairs(folderVisual:GetChildren()) do
			local sorot = m:FindFirstChildOfClass("Highlight")
			local asli = workspace:FindFirstChild("Pasukan") and workspace.Pasukan:FindFirstChild(m.Name)
			if sorot then
				sorot.Enabled = asli ~= nil and asli:GetAttribute("Semangat") == true
			end
		end
	end)
end

return Prajurit
