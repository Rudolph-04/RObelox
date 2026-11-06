-- Latar hutan yang hidup (ModuleScript di StarterPlayerScripts, dipanggil LaskarClient).
--
-- Versi 3D dari latar berlapis ala game 2D: kamera ikut panglima ke kanan, jadi
-- lapisan deket lewat lebih cepet dari lapisan jauh (paralaks asli dari 3D).
--
-- Dibikin & digerakin di client doang (nggak ada di server): nggak makan
-- jaringan, gerakannya mulus, dan pake seed tetap jadi semua player liat
-- hutan yang sama.
--
--   Lapisan depan  (z +11..+16) : rumput & bunga (goyang)
--   Pinggir jalur  (z -11..-13) : rumput
--   Hutan deket    (z -14..-22) : pohon bulat, pisang, semak
--   Hutan tengah   (z -24..-36) : cemara, pohon bulat, rumpun bambu
--   Hutan jauh     (z -40..-62) : pohon gede
--   Langit                      : awan jalan pelan, kawanan burung
--   Udara                       : daun jatuh dari pohon, kupu-kupu
--
-- Angin: tiupan dasar + hembusan yang jalan dari kiri ke kanan layar tiap
-- beberapa detik (pohon goyang berurutan kayak gelombang).
-- Cuma yang deket kamera yang dianimasiin, diupdate 40x per detik lewat
-- workspace:BulkMoveTo biar ringan.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local C = require(ReplicatedStorage:WaitForChild("LaskarConfig"))

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local TEGAK = CFrame.Angles(0, 0, math.rad(90)) -- silinder berdiri

local DAUN = { RGB(66, 128, 58), RGB(84, 146, 66), RGB(54, 112, 52), RGB(102, 156, 72) }
local DAUN_GELAP = { RGB(40, 92, 52), RGB(34, 82, 48), RGB(48, 100, 58) }
local BATANG = { RGB(104, 72, 46), RGB(92, 64, 42), RGB(120, 86, 56) }
local RUMPUT = { RGB(92, 150, 70), RGB(110, 166, 78), RGB(78, 136, 62) }
local BUNGA = { RGB(240, 200, 70), RGB(236, 120, 150), RGB(250, 250, 240), RGB(200, 120, 220), RGB(245, 140, 70) }

local JANGKAU_POHON = 100 -- jarak X dari kamera yang dianimasiin
local JANGKAU_RUMPUT = 60
local HZ = 40

local acak = Random.new(11) -- seed tetap: hutan sama buat semua player
local folder
local goyang = {} -- { akar, x, parts, offset, bobot, kekuatan, fase, kaku, kecil }
local kanopi = {} -- posisi kanopi (buat titik jatuh daun)

local Latar = {}

local function part(nama, size, cf, warna, material, bentuk, bayangan)
	local p = Instance.new("Part")
	p.Name = nama
	p.Size = size
	p.CFrame = cf
	p.Color = warna
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
	p.Parent = folder
	return p
end

local function pilih(list)
	return list[acak:NextInteger(1, #list)]
end

-- Daftarin bagian-bagian yang goyang bareng di sekitar akar (pangkal batang).
-- bobot: 0 = diem di akar, 1 = goyang penuh (makin ke atas makin gede).
local function daftar(akar, isi, kekuatan, kaku, kecil)
	local e = {
		akar = akar,
		x = akar.Position.X,
		parts = {},
		offset = {},
		bobot = {},
		kekuatan = kekuatan,
		fase = acak:NextNumber(0, math.pi * 2),
		kaku = kaku or 1,
		kecil = kecil,
	}
	for _, item in ipairs(isi) do
		table.insert(e.parts, item[1])
		table.insert(e.offset, akar:ToObjectSpace(item[1].CFrame))
		table.insert(e.bobot, item[2])
	end
	table.insert(goyang, e)
end

local TANAH = 0.5 -- permukaan rumput (Arena: tanah atasnya y 0.5)

-- ── POHON ──────────────────────────────────────────────────────────
local function pohonBulat(x, z, s)
	local akar = CFrame.new(x, TANAH, z)
	local tinggi = 6 * s
	local batang = part("Batang", V3(tinggi, 0.9 * s, 0.9 * s), akar * CFrame.new(0, tinggi / 2, 0) * TEGAK, pilih(BATANG), M.Wood, Enum.PartType.Cylinder)
	local isi = { { batang, 0.3 } }
	local utama = part("Daun", V3(5 * s, 5 * s, 5 * s), akar * CFrame.new(0, tinggi + 1.2 * s, 0), pilih(DAUN), M.Grass, Enum.PartType.Ball)
	table.insert(isi, { utama, 1 })
	for _, sx in ipairs({ -1, 1 }) do
		local d = acak:NextNumber(3.2, 4) * s
		local p = part("Daun", V3(d, d, d), akar * CFrame.new(sx * 1.9 * s, tinggi + acak:NextNumber(0, 0.6) * s, acak:NextNumber(-0.8, 0.8) * s), pilih(DAUN), M.Grass, Enum.PartType.Ball)
		table.insert(isi, { p, 0.9 })
	end
	daftar(akar, isi, 2.2, acak:NextNumber(0.8, 1.1))
	table.insert(kanopi, V3(x, TANAH + tinggi + s, z))
end

local function cemara(x, z, s)
	local akar = CFrame.new(x, TANAH, z)
	local tinggi = 9 * s
	local isi = { { part("Batang", V3(tinggi, 0.6 * s, 0.6 * s), akar * CFrame.new(0, tinggi / 2, 0) * TEGAK, pilih(BATANG), M.Wood, Enum.PartType.Cylinder), 0.3 } }
	local warna = pilih(DAUN_GELAP)
	for i = 0, 3 do
		local d = (5 - i * 1.1) * s
		local y = (2.6 + i * 1.7) * s
		local p = part("Daun", V3(1.4 * s, d, d), akar * CFrame.new(0, y, 0) * TEGAK, warna, M.Grass, Enum.PartType.Cylinder)
		table.insert(isi, { p, 0.45 + i * 0.25 })
	end
	daftar(akar, isi, 1.6, acak:NextNumber(0.9, 1.2))
	table.insert(kanopi, V3(x, TANAH + 6 * s, z))
end

local function pisang(x, z, s)
	local akar = CFrame.new(x, TANAH, z)
	local tinggi = 4.5 * s
	local isi = { { part("Batang", V3(tinggi, 0.7 * s, 0.7 * s), akar * CFrame.new(0, tinggi / 2, 0) * TEGAK, RGB(126, 142, 74), M.Grass, Enum.PartType.Cylinder), 0.35 } }
	local jumlah = 6
	for i = 1, jumlah do
		local yaw = (i / jumlah) * math.pi * 2 + acak:NextNumber(-0.2, 0.2)
		local panjang = acak:NextNumber(3.2, 4) * s
		local cf = akar * CFrame.new(0, tinggi, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-acak:NextNumber(10, 35)), 0, 0) * CFrame.new(0, 0, -panjang / 2)
		local p = part("DaunPisang", V3(1.0 * s, 0.08, panjang), cf, pilih(DAUN), M.Grass, nil, true)
		table.insert(isi, { p, 1.3 })
	end
	daftar(akar, isi, 2.6, acak:NextNumber(1.1, 1.4))
	table.insert(kanopi, V3(x, TANAH + tinggi, z))
end

local function rumpunBambu(x, z, s)
	for _ = 1, acak:NextInteger(5, 8) do
		local bx, bz = x + acak:NextNumber(-1.2, 1.2) * s, z + acak:NextNumber(-1.2, 1.2) * s
		local akar = CFrame.new(bx, TANAH, bz) * CFrame.Angles(math.rad(acak:NextNumber(-6, 6)), 0, math.rad(acak:NextNumber(-8, 8)))
		local tinggi = acak:NextNumber(10, 14) * s
		local warna = RGB(118 + acak:NextInteger(-10, 10), 156 + acak:NextInteger(-10, 10), 70)
		local isi = { { part("Bambu", V3(tinggi, 0.35 * s, 0.35 * s), akar * CFrame.new(0, tinggi / 2, 0) * TEGAK, warna, M.Wood, Enum.PartType.Cylinder), 0.6 } }
		for j = 1, 3 do
			local d = acak:NextNumber(1.2, 1.8) * s
			local p = part("DaunBambu", V3(d, d, d), akar * CFrame.new(acak:NextNumber(-0.8, 0.8), tinggi - j * 1.3 * s, acak:NextNumber(-0.8, 0.8)), pilih(DAUN), M.Grass, Enum.PartType.Ball)
			table.insert(isi, { p, 1 })
		end
		daftar(akar, isi, 4.5, acak:NextNumber(1.2, 1.7))
	end
end

local function semak(x, z, s)
	local akar = CFrame.new(x, TANAH, z)
	local isi = {}
	for i = 1, 3 do
		local d = acak:NextNumber(1.6, 2.6) * s
		local p = part("Semak", V3(d, d, d), akar * CFrame.new((i - 2) * 1.2 * s, d * 0.3, acak:NextNumber(-0.5, 0.5)), pilih(DAUN), M.Grass, Enum.PartType.Ball)
		table.insert(isi, { p, 0.6 })
	end
	daftar(akar, isi, 1.2, 1.6)
end

-- ── RUMPUT & BUNGA ─────────────────────────────────────────────────
local function rumput(x, z)
	local akar = CFrame.new(x, TANAH, z)
	local isi = {}
	for i = 1, 3 do
		local h = acak:NextNumber(0.6, 1.3)
		local cf = akar * CFrame.Angles(0, acak:NextNumber(0, math.pi), math.rad((i - 2) * 18)) * CFrame.new(0, h / 2, 0)
		table.insert(isi, { part("Rumput", V3(0.08, h, 0.22), cf, pilih(RUMPUT), M.Grass, nil, false), 1 })
	end
	if acak:NextNumber() < 0.18 then
		local h = acak:NextNumber(0.9, 1.4)
		table.insert(isi, { part("Tangkai", V3(0.05, h, 0.05), akar * CFrame.new(0.2, h / 2, 0), RGB(80, 130, 60), M.Grass, nil, false), 1 })
		table.insert(isi, { part("Bunga", V3(0.35, 0.35, 0.35), akar * CFrame.new(0.2, h, 0), pilih(BUNGA), M.SmoothPlastic, Enum.PartType.Ball, false), 1 })
	end
	daftar(akar, isi, 10, acak:NextNumber(1.6, 2.4), true)
end

-- ── LANGIT ─────────────────────────────────────────────────────────
local awan = {} -- { parts, offset, x, y, z, kecepatan }

local function bikinAwan(x)
	-- Di depan gunung, di atas bukit, dan masih masuk frame kamera samping.
	local y, z = acak:NextNumber(44, 60), acak:NextNumber(-200, -150)
	local e = { parts = {}, offset = {}, x = x, y = y, z = z, kecepatan = acak:NextNumber(1, 2.2) }
	for _ = 1, acak:NextInteger(4, 7) do
		local d = acak:NextNumber(10, 20)
		local off = V3(acak:NextNumber(-14, 14), acak:NextNumber(-3, 4), acak:NextNumber(-4, 4))
		local p = part("Awan", V3(d, d, d), CFrame.new(x + off.X, y + off.Y, z + off.Z), RGB(250, 250, 252), M.SmoothPlastic, Enum.PartType.Ball, false)
		p.Transparency = 0.05
		table.insert(e.parts, p)
		table.insert(e.offset, off)
	end
	table.insert(awan, e)
end

local burung = {} -- { badan, sayap = {kiri, kanan}, x, y, z, arah, kecepatan, fase }

local function kawananBurung(kameraX)
	local arah = acak:NextNumber() < 0.5 and 1 or -1
	local x0 = kameraX - arah * 130
	local y0, z0 = acak:NextNumber(22, 34), acak:NextNumber(-80, -45)
	local kecepatan = acak:NextNumber(12, 18)
	for i = 1, acak:NextInteger(3, 6) do
		local b = {
			x = x0 - arah * i * 2.2,
			y = y0 + (i % 2) * 1.2 - i * 0.3,
			z = z0 + acak:NextNumber(-3, 3),
			arah = arah,
			kecepatan = kecepatan * acak:NextNumber(0.95, 1.05),
			fase = acak:NextNumber(0, math.pi * 2),
		}
		b.badan = part("Burung", V3(0.5, 0.5, 0.5), CFrame.new(b.x, b.y, b.z), RGB(40, 36, 40), M.SmoothPlastic, Enum.PartType.Ball, false)
		b.sayap = {}
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(b.sayap, { part("Sayap", V3(1.1, 0.06, 0.4), CFrame.new(b.x, b.y, b.z), RGB(50, 44, 48), M.SmoothPlastic, nil, false), sx })
		end
		table.insert(burung, b)
	end
end

-- ── DAUN JATUH & KUPU-KUPU ─────────────────────────────────────────
local daunJatuh = {} -- { part, x, y, z, kecepatan, putar, fase, diam }
local kupu = {} -- { badan, sayap, pusat, fase, kecepatan, warna }

local function lepasDaun(d, kameraX)
	local calon = {}
	for _, k in ipairs(kanopi) do
		if math.abs(k.X - kameraX) < 70 then
			table.insert(calon, k)
		end
	end
	if #calon == 0 then
		d.diam = 1
		d.part.Transparency = 1
		return
	end
	local k = calon[acak:NextInteger(1, #calon)]
	d.x, d.y, d.z = k.X + acak:NextNumber(-2, 2), k.Y + acak:NextNumber(-1, 1), k.Z + acak:NextNumber(-1.5, 1.5)
	d.kecepatan = acak:NextNumber(1.2, 2.2)
	d.fase = acak:NextNumber(0, math.pi * 2)
	d.diam = nil
	d.part.Transparency = 0
	d.part.Color = acak:NextNumber() < 0.5 and pilih(DAUN) or RGB(214, 170, 70)
end

-- ── ANGIN ──────────────────────────────────────────────────────────
-- Nilai ~0..2: tiupan dasar (pelan ngombak) + hembusan yang jalan ke kanan.
local function angin(x, t, kameraX)
	local dasar = 0.45 + 0.3 * math.sin(t * 0.6 + x * 0.025)
	local pusatHembusan = kameraX - 90 + (t * 26) % 220
	local hembusan = 1.1 * math.exp(-((x - pusatHembusan) / 16) ^ 2)
	return dasar + hembusan
end

-- ── EFEK LAYAR ─────────────────────────────────────────────────────
local function efekLayar()
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.3
		a.Offset = 0.2
		a.Color = RGB(206, 220, 232)
		a.Decay = RGB(120, 140, 150)
		a.Glare = 0.2
		a.Haze = 1.4
		a.Parent = Lighting
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "LaskarWarna"
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.TintColor = RGB(255, 250, 242)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "LaskarBloom"
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 0.95
	bloom.Parent = Lighting
	local sinar = Instance.new("SunRaysEffect")
	sinar.Name = "LaskarSinar"
	sinar.Intensity = 0.06
	sinar.Spread = 0.8
	sinar.Parent = Lighting
end

-- ── BANGUN & JALANIN ───────────────────────────────────────────────
function Latar.mulai()
	if folder then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "LatarHidup"

	local a = C.ARENA
	local x1, x2 = a.mulaiX - 70, a.akhirX + 70

	local x = x1
	while x < x2 do -- hutan deket
		local r = acak:NextNumber()
		local z = acak:NextNumber(-22, -14)
		if r < 0.45 then
			pohonBulat(x, z, acak:NextNumber(0.8, 1.1))
		elseif r < 0.7 then
			pisang(x, z, acak:NextNumber(0.8, 1.1))
		else
			semak(x, z + 2, acak:NextNumber(0.8, 1.2))
		end
		x += acak:NextNumber(6, 9)
	end
	x = x1 + 3
	while x < x2 do -- hutan tengah
		local r = acak:NextNumber()
		local z = acak:NextNumber(-36, -24)
		if r < 0.4 then
			cemara(x, z, acak:NextNumber(0.9, 1.25))
		elseif r < 0.8 then
			pohonBulat(x, z, acak:NextNumber(1, 1.3))
		else
			rumpunBambu(x, z, acak:NextNumber(0.9, 1.1))
		end
		x += acak:NextNumber(7, 10)
	end
	x = x1 + 6
	while x < x2 do -- hutan jauh
		local z = acak:NextNumber(-62, -40)
		if acak:NextNumber() < 0.5 then
			cemara(x, z, acak:NextNumber(1.4, 1.8))
		else
			pohonBulat(x, z, acak:NextNumber(1.4, 1.8))
		end
		x += acak:NextNumber(10, 14)
	end
	x = x1
	while x < x2 do -- rumput depan
		rumput(x, acak:NextNumber(11, 16))
		x += acak:NextNumber(2, 3.5)
	end
	x = x1
	while x < x2 do -- rumput pinggir jalur belakang
		rumput(x, acak:NextNumber(-13, -11))
		x += acak:NextNumber(3, 5)
	end
	x = x1
	while x < x2 + 200 do
		bikinAwan(x)
		x += acak:NextNumber(40, 70)
	end
	for _ = 1, 26 do
		local p = part("DaunJatuh", V3(0.35, 0.04, 0.25), CFrame.new(0, -50, 0), pilih(DAUN), M.SmoothPlastic, nil, false)
		p.Transparency = 1
		table.insert(daunJatuh, { part = p, diam = acak:NextNumber(0, 4) })
	end
	for _ = 1, 6 do
		local warna = pilih(BUNGA)
		local k = {
			pusat = V3(acak:NextNumber(-30, 30), 0, acak:NextNumber(6, 13)),
			fase = acak:NextNumber(0, 100),
			kecepatan = acak:NextNumber(0.6, 1.1),
		}
		k.badan = part("Kupu", V3(0.08, 0.08, 0.3), CFrame.new(0, -50, 0), RGB(40, 30, 30), M.SmoothPlastic, nil, false)
		k.sayap = {}
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(k.sayap, { part("SayapKupu", V3(0.35, 0.03, 0.3), CFrame.new(0, -50, 0), warna, M.SmoothPlastic, nil, false), sx })
		end
		table.insert(kupu, k)
	end

	folder.Parent = workspace
	efekLayar()

	local kamera = workspace.CurrentCamera
	local tunggu, t = 0, 0
	local burungBerikut = 3
	local parts, cfs = {}, {}

	RunService.Heartbeat:Connect(function(dt)
		t += dt
		tunggu += dt
		if tunggu < 1 / HZ then
			return
		end
		local langkah = tunggu
		tunggu = 0
		local kameraX = kamera.CFrame.Position.X
		local n = 0
		table.clear(parts)
		table.clear(cfs)

		-- Pohon & rumput goyang.
		for _, e in ipairs(goyang) do
			if math.abs(e.x - kameraX) < (e.kecil and JANGKAU_RUMPUT or JANGKAU_POHON) then
				local w = angin(e.x, t, kameraX)
				local sudut = (w + math.sin(t * 1.7 * e.kaku + e.fase) * 0.25) * e.kekuatan
				for i, p in ipairs(e.parts) do
					local b = e.bobot[i]
					n += 1
					parts[n] = p
					cfs[n] = e.akar * CFrame.Angles(math.rad(sudut * b * 0.25 * math.sin(t + e.fase)), 0, math.rad(-sudut * b)) * e.offset[i]
				end
			end
		end

		-- Awan jalan ke kanan, muter balik kalau udah jauh dari kamera.
		for _, e in ipairs(awan) do
			e.x += e.kecepatan * langkah
			if e.x > kameraX + 260 then
				e.x -= 520
			elseif e.x < kameraX - 260 then
				e.x += 520
			end
			for i, p in ipairs(e.parts) do
				local off = e.offset[i]
				n += 1
				parts[n] = p
				cfs[n] = CFrame.new(e.x + off.X, e.y + off.Y, e.z + off.Z)
			end
		end

		-- Burung.
		burungBerikut -= langkah
		if burungBerikut <= 0 then
			kawananBurung(kameraX)
			burungBerikut = acak:NextNumber(10, 18)
		end
		for i = #burung, 1, -1 do
			local b = burung[i]
			b.x += b.arah * b.kecepatan * langkah
			if math.abs(b.x - kameraX) > 150 then
				b.badan:Destroy()
				for _, s in ipairs(b.sayap) do
					s[1]:Destroy()
				end
				table.remove(burung, i)
			else
				local y = b.y + math.sin(t * 1.5 + b.fase) * 0.6
				local hadap = CFrame.lookAt(V3(b.x, y, b.z), V3(b.x + b.arah, y, b.z))
				n += 1
				parts[n] = b.badan
				cfs[n] = hadap
				local kepak = math.rad(math.sin(t * 11 + b.fase) * 40)
				for _, s in ipairs(b.sayap) do
					n += 1
					parts[n] = s[1]
					cfs[n] = hadap * CFrame.Angles(0, 0, s[2] * kepak) * CFrame.new(s[2] * 0.55, 0, 0) -- engsel di badan
				end
			end
		end

		-- Daun jatuh: melayang turun kebawa angin, diem bentar di tanah, terus ilang.
		for _, d in ipairs(daunJatuh) do
			if d.diam then
				d.diam -= langkah
				if d.diam <= 0 then
					lepasDaun(d, kameraX)
				end
			else
				d.y -= d.kecepatan * langkah
				d.x += (angin(d.x, t, kameraX) * 1.4 + math.sin(t * 2 + d.fase) * 0.8) * langkah
				d.z += math.cos(t * 1.3 + d.fase) * 0.4 * langkah
				if d.y <= TANAH + 0.05 then
					d.y = TANAH + 0.05
					d.diam = acak:NextNumber(1.5, 3)
					d.part.Transparency = 1
				end
				n += 1
				parts[n] = d.part
				cfs[n] = CFrame.new(d.x, d.y, d.z) * CFrame.Angles(math.sin(t * 3 + d.fase) * 1.2, t * 2 + d.fase, math.cos(t * 2.5 + d.fase) * 0.8)
			end
		end

		-- Kupu-kupu: terbang muter-muter di depan, ikut pindah kalau kamera jalan jauh.
		for _, k in ipairs(kupu) do
			if math.abs(k.pusat.X - kameraX) > 45 then
				k.pusat = V3(kameraX + acak:NextNumber(-35, 35), 0, k.pusat.Z)
			end
			local u = t * k.kecepatan + k.fase
			local pos = k.pusat + V3(math.sin(u) * 3 + math.sin(u * 2.3) * 1.2, TANAH + 1.6 + math.sin(u * 1.7) * 0.7, math.cos(u * 1.3) * 1.5)
			local maju = V3(math.cos(u) * 3 + math.cos(u * 2.3) * 2.8, 0, -math.sin(u * 1.3) * 2)
			local hadap = maju.Magnitude > 0.01 and CFrame.lookAt(pos, pos + maju) or CFrame.new(pos)
			n += 1
			parts[n] = k.badan
			cfs[n] = hadap
			local kepak = math.rad(20 + math.abs(math.sin(t * 16 + k.fase)) * 60)
			for _, s in ipairs(k.sayap) do
				n += 1
				parts[n] = s[1]
				cfs[n] = hadap * CFrame.Angles(0, 0, s[2] * kepak) * CFrame.new(s[2] * 0.18, 0, 0)
			end
		end

		if n > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Latar
