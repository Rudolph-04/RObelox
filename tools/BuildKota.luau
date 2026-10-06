--[[
	BuildKota — bangun map kota Juragan Tahu (graybox).

	BUKAN script game. Jalanin SEKALI di mode Edit (Command Bar Studio, atau
	lewat Claude Code + Studio MCP), terus Save place-nya (Ctrl+S). Hasilnya part
	biasa di Workspace.Kota yang bisa diedit/digeser manual di Studio.

	Layout (Y = atas, jalan raya di z = 0):

	                  [ ALUN-ALUN ]   (plot cabang, terkunci)
	                        |
	   ruko ruko ruko       |       ruko ruko ruko
	  ===================== jalan raya =====================
	   [ DEPAN SEKOLAH ]  [ PASAR ]  [ TERMINAL ]
	   (terkunci)         (main)     (terkunci)

	Yang dipake gameplay (sisanya dekorasi, bebas diubah):
	  - part bertag "TitikJualan": area tempat kendaraan boleh jualan
	  - part bertag "ParkirKendaraan": tempat kendaraan player muncul
	Wajan sekarang nempel di kendaraan (tools/Kendaraan/), bukan di map.

	Kalau Workspace.Kota udah ada, script ini nggak ngapa-ngapain
	(hapus dulu manual kalau mau bangun ulang).
]]

local CollectionService = game:GetService("CollectionService")

if workspace:FindFirstChild("Kota") then
	warn("[BuildKota] Workspace.Kota udah ada, skip. Hapus dulu kalau mau bangun ulang.")
	return "skip"
end

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local rng = Random.new(20261003) -- seed tetap: tiap bangun ulang hasilnya sama

-- ── UKURAN KOTA ────────────────────────────────────────────────────
local HALF_X = 260 -- batas kiri/kanan
local MIN_Z, MAX_Z = -135, 155 -- batas selatan/utara
local ROAD_HALF = 12 -- jalan raya: z -12..12
local WALK = 6 -- lebar trotoar

-- Titik tengah tiap lokasi (permukaan tanah y = 0).
local PASAR = V3(0, 0, -60)
local SEKOLAH = V3(-150, 0, -64)
local TERMINAL = V3(150, 0, -64)
local ALUN = V3(0, 0, 100)

-- Warna
local WOOD = RGB(150, 100, 55)
local WOOD_DARK = RGB(110, 72, 40)
local METAL = RGB(70, 72, 78)
local CREAM = RGB(250, 240, 215)
local ASPHALT = RGB(58, 58, 62)
local SIDEWALK = RGB(185, 180, 170)
local LEAF = { RGB(62, 120, 52), RGB(76, 135, 58), RGB(50, 105, 48) }

-- ── HELPER ─────────────────────────────────────────────────────────
-- Props buat cat di lantai/jalan (marka, garis parkir): cuma tampilan, jangan
-- sampe bikin kendaraan nyangkut.
local CAT = { CanCollide = false, CanQuery = false }

local function box(parent, name, size, at, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = typeof(at) == "CFrame" and at or CFrame.new(at)
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

-- Silinder di Roblox sumbunya X.
-- disc()  = silinder berdiri (tutup di atas): tiang, wajan, batang pohon.
-- wheel() = silinder rebahan sumbu X: roda.
local function disc(parent, name, height, diameter, pos, color, material, props)
	local p = box(parent, name, V3(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function wheel(parent, name, width, diameter, pos, color, material)
	local p = box(parent, name, V3(width, diameter, diameter), pos, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, diameter, pos, color, material)
	local p = box(parent, name, V3(diameter, diameter, diameter), pos, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function folder(parent, name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = parent
	return f
end

local function signText(board, face, text, textColor, bgColor, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bgColor
	label.BorderSizePixel = 0
	label.Font = font or Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = textColor
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
end

-- Papan nama berdiri (2 tiang + papan), tulisan ngadep `faceDir` (+1 = +Z, -1 = -Z).
local function signPost(parent, pos, width, text, faceDir, textColor, bgColor)
	local m = folder(parent, "Papan")
	for _, dx in ipairs({ -width / 2 + 0.4, width / 2 - 0.4 }) do
		box(m, "Tiang", V3(0.4, 6, 0.4), pos + V3(dx, 3, 0), METAL, M.Metal)
	end
	local board = box(m, "Papan", V3(width, 2.6, 0.3), pos + V3(0, 5.2, 0), bgColor, M.SmoothPlastic)
	signText(board, faceDir > 0 and Enum.NormalId.Back or Enum.NormalId.Front, text, textColor, bgColor)
	return m
end

local function tree(parent, pos, scale)
	local m = folder(parent, "Pohon")
	local h = 7 * scale
	disc(m, "Batang", h, 1.1 * scale, pos + V3(0, h / 2, 0), RGB(95, 65, 40), M.Wood)
	local leaf = LEAF[rng:NextInteger(1, #LEAF)]
	ball(m, "Daun", 7 * scale, pos + V3(0, h + 1.5 * scale, 0), leaf, M.Grass)
	ball(m, "Daun", 5 * scale, pos + V3(1.8 * scale, h + 0.4 * scale, 1 * scale), leaf, M.Grass)
	ball(m, "Daun", 5 * scale, pos + V3(-1.6 * scale, h + 0.6 * scale, -1.2 * scale), leaf, M.Grass)
	return m
end

local function streetLamp(parent, pos, armDir)
	local m = folder(parent, "LampuJalan")
	disc(m, "Tiang", 12, 0.5, pos + V3(0, 6, 0), RGB(90, 95, 100), M.Metal)
	box(m, "Lengan", V3(0.3, 0.3, 3), pos + V3(0, 11.8, armDir * 1.5), RGB(90, 95, 100), M.Metal)
	box(m, "Lampu", V3(1.2, 0.5, 1.6), pos + V3(0, 11.5, armDir * 3), RGB(255, 236, 190), M.Neon)
end

-- Pagar rendah keliling plot, bolong di sisi `gateSide` (+1 = +Z / -1 = -Z).
local function fence(parent, center, sizeX, sizeZ, gateSide, gateWidth)
	local m = folder(parent, "Pagar")
	local color = RGB(225, 225, 220)
	local y = 1.25
	local zGate = center.Z + gateSide * sizeZ / 2
	local zBack = center.Z - gateSide * sizeZ / 2
	box(m, "Pagar", V3(sizeX, 2.5, 0.5), V3(center.X, y, zBack), color, M.Concrete)
	for _, sx in ipairs({ -1, 1 }) do
		box(m, "Pagar", V3(0.5, 2.5, sizeZ), V3(center.X + sx * sizeX / 2, y, center.Z), color, M.Concrete)
		local segment = (sizeX - gateWidth) / 2
		box(m, "Pagar", V3(segment, 2.5, 0.5), V3(center.X + sx * (gateWidth / 2 + segment / 2), y, zGate), color, M.Concrete)
	end
	return m
end

local kota = Instance.new("Folder")
kota.Name = "Kota"

-- ── TANAH, JALAN, TROTOAR ──────────────────────────────────────────
local ground = folder(kota, "Jalan")

-- Tanah pakai terrain rumput (lebih natural dari part datar).
-- Permukaan smooth terrain jadinya ~2 stud DI ATAS batas isian (voxel 4 stud),
-- jadi diisi sampe y = -2 biar permukaannya pas di y ≈ 0, sejajar bawah jalan
-- & lantai. (Dulu diisi sampe 0 -> seluruh kota kekubur 2 stud tanah.)
workspace.Terrain:FillBlock(
	CFrame.new(0, -5, (MIN_Z + MAX_Z) / 2),
	V3(HALF_X * 2 + 80, 6, (MAX_Z - MIN_Z) + 80),
	M.Grass
)

-- Di bawah semua yang diaspal/dibangun, terrain diganti tanah. Rumput terrain
-- tumbuh nembus part tipis (lantai pasar, jalan), dan tinggi rumputnya nggak
-- bisa diatur dari script, jadi rumput cuma dibiarin di lahan kosong.
local function pave(x1, x2, z1, z2)
	local region = Region3.new(V3(math.min(x1, x2), -8, math.min(z1, z2)), V3(math.max(x1, x2), 4, math.max(z1, z2)))
	workspace.Terrain:ReplaceMaterial(region:ExpandToGrid(4), 4, M.Grass, M.Ground)
end
pave(-HALF_X - 2, HALF_X + 2, -(ROAD_HALF + WALK + 1), ROAD_HALF + WALK + 1) -- jalan raya + trotoar
pave(PASAR.X - 39, PASAR.X + 39, PASAR.Z - 31, -(ROAD_HALF + WALK))
pave(-7, 7, ROAD_HALF + WALK, ALUN.Z - 45) -- jalan ke alun-alun
pave(SEKOLAH.X - 43, SEKOLAH.X + 43, SEKOLAH.Z - 33, SEKOLAH.Z + 33)
pave(TERMINAL.X - 47, TERMINAL.X + 47, TERMINAL.Z - 33, TERMINAL.Z + 33)
pave(ALUN.X - 47, ALUN.X + 47, ALUN.Z - 47, ALUN.Z + 47)
for _, side in ipairs({ -1, 1 }) do
	pave(side * 53, side * 236, ROAD_HALF + WALK - 2, ROAD_HALF + WALK + 17) -- deretan ruko
end
for _, x in ipairs({ -95, -75, -55, 55, 75, 95, -224, 224 }) do -- rumah (lihat bagian RUMAH)
	pave(x - 7, x + 7, -47, -33)
	pave(x - 7, x + 7, -73, -59)
end

box(ground, "JalanRaya", V3(HALF_X * 2, 0.3, ROAD_HALF * 2), V3(0, 0.15, 0), ASPHALT, M.Asphalt)
for x = -HALF_X + 10, HALF_X - 10, 16 do
	box(ground, "Marka", V3(8, 0.05, 0.6), V3(x, 0.32, 0), RGB(240, 240, 235), M.SmoothPlastic, CAT)
end
for _, side in ipairs({ -1, 1 }) do
	box(ground, "Trotoar", V3(HALF_X * 2, 0.6, WALK), V3(0, 0.3, side * (ROAD_HALF + WALK / 2)), SIDEWALK, M.Concrete)
	box(ground, "Kanstin", V3(HALF_X * 2, 0.7, 0.4), V3(0, 0.35, side * (ROAD_HALF + 0.2)), RGB(230, 225, 210), M.Concrete)
end

-- Jalan ke alun-alun (utara).
local alunRoadStart = ROAD_HALF + WALK
local alunRoadEnd = ALUN.Z - 46
box(ground, "JalanAlun", V3(12, 0.3, alunRoadEnd - alunRoadStart), V3(0, 0.15, (alunRoadStart + alunRoadEnd) / 2), ASPHALT, M.Asphalt)

-- Lampu jalan di kedua trotoar, mepet kanstin (biar nggak nabrak kanopi ruko),
-- selang-seling utara/selatan, nggak sampe ke barisan pohon batas kota.
for x = -HALF_X + 20, HALF_X - 36, 32 do
	streetLamp(ground, V3(x, 0.6, ROAD_HALF + 1.5), -1)
	streetLamp(ground, V3(x + 16, 0.6, -(ROAD_HALF + 1.5)), 1)
end

-- ── PASAR (lokasi pertama, yang bisa dimainin) ────────────────────
local function buildPasar(origin)
	local pasar = folder(kota, "Pasar")
	local FLOOR = 0.4

	local function at(x, y, z)
		return origin + V3(x, y, z)
	end

	-- Lantai sampe nyambung ke trotoar.
	local front = -(ROAD_HALF + WALK) - origin.Z -- z relatif batas trotoar selatan
	local back = -30
	box(pasar, "Lantai", V3(76, 0.4, front - back), at(0, 0.2, (front + back) / 2), RGB(168, 160, 148), M.Concrete)

	-- Gapura "PASAR" di pintu masuk.
	for _, x in ipairs({ -13, 13 }) do
		box(pasar, "TiangGapura", V3(2, 11, 2), at(x, 5.5, front - 3), RGB(200, 70, 50), M.Brick)
	end
	local gapura = box(pasar, "Gapura", V3(30, 3, 1.4), at(0, 11.5, front - 3), RGB(200, 70, 50), M.Brick)
	signText(gapura, Enum.NormalId.Back, "PASAR", CREAM, RGB(150, 40, 30))
	signText(gapura, Enum.NormalId.Front, "PASAR", CREAM, RGB(150, 40, 30))

	-- TITIK JUALAN: 6 petak parkir kendaraan dagangan. Cuma bisa goreng kalau
	-- kendaraannya diparkir di dalem part bertag "TitikJualan" (dicek KendaraanService).
	-- Part bertag "ParkirKendaraan" = tempat kendaraan muncul (ngadep -Z,
	-- moncong ke dalem pasar, bak + wajan ngadep pintu masuk).
	local BAY_W, BAY_Z1, BAY_Z2 = 6.4, 7, 21
	local bayCount = 6
	local bayLeft = -BAY_W * bayCount / 2
	for i = 0, bayCount do
		box(pasar, "GarisParkir", V3(0.2, 0.04, BAY_Z2 - BAY_Z1), at(bayLeft + i * BAY_W, FLOOR + 0.02, (BAY_Z1 + BAY_Z2) / 2), RGB(245, 245, 240), M.SmoothPlastic, CAT)
	end
	box(pasar, "GarisParkir", V3(BAY_W * bayCount, 0.04, 0.2), at(0, FLOOR + 0.02, BAY_Z1), RGB(245, 245, 240), M.SmoothPlastic, CAT)
	box(pasar, "GarisJualan", V3(BAY_W * bayCount, 0.04, 0.5), at(0, FLOOR + 0.02, BAY_Z2 + 0.4), RGB(245, 200, 40), M.SmoothPlastic, CAT)
	for i = 1, bayCount do
		local slot = box(pasar, "ParkirKendaraan", V3(1, 1, 1), CFrame.new(at(bayLeft + (i - 0.5) * BAY_W, FLOOR, (BAY_Z1 + BAY_Z2) / 2)), RGB(255, 255, 255), M.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		CollectionService:AddTag(slot, "ParkirKendaraan")
	end
	local zone = box(pasar, "TitikJualan", V3(BAY_W * bayCount + 2, 12, BAY_Z2 - BAY_Z1 + 2), at(0, FLOOR + 6, (BAY_Z1 + BAY_Z2) / 2), RGB(245, 200, 40), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	zone:SetAttribute("Lokasi", "Pasar")
	CollectionService:AddTag(zone, "TitikJualan")
	signPost(pasar, at(-BAY_W * bayCount / 2 - 5, FLOOR, BAY_Z2), 9, "TITIK JUALAN\nParkir di sini", 1, RGB(90, 50, 20), RGB(250, 215, 70))

	-- Lapak-lapak tetangga biar kerasa pasar.
	local function lapak(name, x, z, tarpColor, goodsColor)
		local m = folder(pasar, name)
		box(m, "Meja", V3(7, 0.4, 3.5), at(x, FLOOR + 2.8, z), WOOD, M.WoodPlanks)
		box(m, "Kolong", V3(6.6, 2.6, 3.1), at(x, FLOOR + 1.3, z), WOOD_DARK, M.Wood)
		for _, dx in ipairs({ -3.3, 3.3 }) do
			for _, dz in ipairs({ -1.6, 1.6 }) do
				box(m, "Tiang", V3(0.25, 6.6, 0.25), at(x + dx, FLOOR + 3.3, z + dz), METAL, M.Metal)
			end
		end
		box(m, "Terpal", V3(7.6, 0.2, 4.4), at(x, FLOOR + 6.7, z), tarpColor, M.Fabric)
		for i = 0, 2 do
			box(m, "Barang", V3(1.6, 0.8, 1.2), at(x - 2 + i * 2, FLOOR + 3.4, z), goodsColor)
		end
	end

	lapak("LapakSayur", -16, 2, RGB(40, 110, 200), RGB(90, 170, 70))
	lapak("LapakBuah", 16, 2, RGB(60, 150, 90), RGB(235, 150, 40))
	lapak("LapakIkan", -28, 2, RGB(230, 160, 40), RGB(150, 175, 195))
	lapak("LapakBumbu", 28, 2, RGB(170, 60, 140), RGB(200, 90, 40))
	lapak("LapakTelur", -16, -18, RGB(60, 150, 90), RGB(240, 225, 190))
	lapak("LapakKelontong", 16, -18, RGB(40, 110, 200), RGB(200, 60, 60))

	box(pasar, "Krat", V3(2, 1.6, 2), at(7.2, FLOOR + 0.8, -1.5), WOOD, M.WoodPlanks)
	box(pasar, "Krat", V3(2, 1.6, 2), CFrame.new(at(7.4, FLOOR + 2.4, -1.4)) * CFrame.Angles(0, math.rad(15), 0), WOOD, M.WoodPlanks)

	-- Spawn di antara lapak, ngadep titik jualan (kendaraan muncul di situ).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPasar"
	spawn.Anchored = true
	spawn.Size = V3(6, 1, 6)
	local spawnPos = at(0, 0.9, -10)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + V3(0, 0, 1))
	spawn.Color = RGB(200, 190, 170)
	spawn.Material = M.Concrete
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = pasar
end

buildPasar(PASAR)

-- ── PLOT CABANG (terkunci, buat Step "Buka Cabang") ───────────────
local function lockedSign(parent, pos, name, faceDir)
	signPost(parent, pos, 14, name .. "\nSegera dibuka • Buka Cabang", faceDir, RGB(255, 245, 225), RGB(60, 70, 90))
end

-- Depan Sekolah
do
	local plot = folder(kota, "DepanSekolah")
	plot:SetAttribute("Cabang", "Sekolah")
	local c = SEKOLAH
	box(plot, "Halaman", V3(84, 0.3, 64), c + V3(0, 0.15, 0), RGB(170, 160, 140), M.Concrete)
	fence(plot, c, 84, 64, 1, 16)
	box(plot, "Gerbang", V3(16, 3, 0.4), c + V3(0, 1.5, 32), RGB(40, 90, 60), M.Metal) -- ditutup = terkunci

	-- Gedung 2 lantai (dinding krem, list hijau, jendela biru, atap genteng).
	local gedung = c + V3(0, 0, -20)
	box(plot, "Gedung", V3(56, 16, 14), gedung + V3(0, 8, 0), RGB(240, 232, 205), M.Concrete)
	box(plot, "List", V3(56.4, 0.8, 14.4), gedung + V3(0, 8, 0), RGB(60, 130, 80), M.SmoothPlastic)
	box(plot, "Atap", V3(58, 1, 16), gedung + V3(0, 16.5, 0), RGB(170, 70, 45), M.Slate)
	for floor = 0, 1 do
		for i = -3, 3 do
			if not (floor == 0 and i == 0) then -- tengah lantai 1 = pintu
				box(plot, "Jendela", V3(4.5, 3.5, 0.3), gedung + V3(i * 7.5, 4 + floor * 8, 7.05), RGB(110, 160, 200), M.Glass, {
					Transparency = 0.2,
				})
			end
		end
	end
	box(plot, "Pintu", V3(4, 6, 0.3), gedung + V3(0, 3, 7.1), RGB(110, 72, 40), M.Wood)

	-- Tiang bendera merah-putih.
	local flag = c + V3(0, 0, 10)
	box(plot, "AlasBendera", V3(4, 0.6, 4), flag + V3(0, 0.3, 0), RGB(200, 200, 195), M.Concrete)
	disc(plot, "TiangBendera", 16, 0.35, flag + V3(0, 8.6, 0), RGB(220, 220, 225), M.Metal)
	box(plot, "BenderaMerah", V3(4, 1.3, 0.1), flag + V3(2.2, 15.4, 0), RGB(205, 30, 40), M.Fabric)
	box(plot, "BenderaPutih", V3(4, 1.3, 0.1), flag + V3(2.2, 14.1, 0), RGB(250, 250, 250), M.Fabric)

	lockedSign(plot, c + V3(14, 0, 36), "DEPAN SEKOLAH", 1)
end

-- Terminal
do
	local plot = folder(kota, "Terminal")
	plot:SetAttribute("Cabang", "Terminal")
	local c = TERMINAL
	box(plot, "Lantai", V3(92, 0.3, 64), c + V3(0, 0.15, 0), RGB(140, 140, 145), M.Concrete)
	fence(plot, c, 92, 64, 1, 24)
	box(plot, "Palang", V3(24, 0.5, 0.5), c + V3(0, 3, 32), RGB(220, 50, 40), M.SmoothPlastic) -- palang ditutup

	-- Kanopi panjang di atas jalur bus.
	local canopy = c + V3(0, 0, -14)
	for x = -36, 36, 12 do
		box(plot, "Tiang", V3(1, 9, 1), canopy + V3(x, 4.5, -6), RGB(200, 200, 200), M.Metal)
		box(plot, "Tiang", V3(1, 9, 1), canopy + V3(x, 4.5, 6), RGB(200, 200, 200), M.Metal)
	end
	box(plot, "Kanopi", V3(80, 0.8, 16), canopy + V3(0, 9.4, 0), RGB(40, 120, 190), M.Metal)

	-- Marka jalur.
	for x = -30, 30, 15 do
		box(plot, "Marka", V3(0.4, 0.05, 20), c + V3(x, 0.32, 4), RGB(240, 240, 235), M.SmoothPlastic, CAT)
	end

	-- Bus + angkot (kotak doang, nanti diganti model beneran).
	local function vehicle(name, pos, size, bodyColor)
		local m = folder(plot, name)
		box(m, "Body", size, pos + V3(0, size.Y / 2 + 0.8, 0), bodyColor, M.SmoothPlastic)
		box(m, "Kaca", V3(size.X - 1, size.Y * 0.32, size.Z + 0.1), pos + V3(0, size.Y * 0.68 + 0.8, 0), RGB(40, 50, 60), M.Glass)
		for _, dx in ipairs({ -size.X / 2 + 2, size.X / 2 - 2 }) do
			for _, dz in ipairs({ -size.Z / 2, size.Z / 2 }) do
				box(m, "Roda", V3(1.6, 1.6, 0.6), pos + V3(dx, 0.8, dz), RGB(30, 30, 30), M.Rubber)
			end
		end
	end
	vehicle("Bus", c + V3(-22, 0, -14), V3(24, 7, 7), RGB(230, 230, 225))
	vehicle("Angkot", c + V3(8, 0, -14), V3(10, 4.5, 5), RGB(40, 140, 80))
	vehicle("Angkot", c + V3(24, 0, -14), V3(10, 4.5, 5), RGB(220, 160, 40))

	lockedSign(plot, c + V3(20, 0, 36), "TERMINAL", 1)
end

-- Alun-alun
do
	local plot = folder(kota, "AlunAlun")
	plot:SetAttribute("Cabang", "AlunAlun")
	local c = ALUN
	box(plot, "Jalur", V3(92, 0.3, 92), c + V3(0, 0.15, 0), RGB(190, 180, 160), M.Pavement)
	box(plot, "Lapangan", V3(76, 0.4, 76), c + V3(0, 0.2, 0), RGB(90, 150, 70), M.Grass)

	-- Pohon beringin besar di tengah (ciri khas alun-alun).
	disc(plot, "AlasBeringin", 1.2, 18, c + V3(0, 0.8, 0), RGB(230, 230, 225), M.Concrete)
	disc(plot, "BatangBeringin", 14, 4, c + V3(0, 7, 0), RGB(85, 60, 40), M.Wood)
	for _, offset in ipairs({ V3(0, 17, 0), V3(6, 15, 3), V3(-6, 15, -2), V3(2, 15, -7), V3(-3, 15, 7) }) do
		ball(plot, "DaunBeringin", 14, c + offset, RGB(48, 100, 45), M.Grass)
	end

	-- Bangku + lampu taman di keliling jalur.
	for _, d in ipairs({ V3(1, 0, 0), V3(-1, 0, 0), V3(0, 0, 1), V3(0, 0, -1) }) do
		local p = c + d * 42
		streetLamp(plot, p + d:Cross(V3(0, 1, 0)) * 8, 0)
		box(plot, "Bangku", d.X ~= 0 and V3(1.5, 1.2, 6) or V3(6, 1.2, 1.5), p + V3(0, 0.6, 0), WOOD, M.WoodPlanks)
	end

	box(plot, "Palang", V3(12, 0.5, 0.5), V3(0, 3, alunRoadEnd - 2), RGB(220, 50, 40)) -- palang ditutup
	for _, x in ipairs({ -6, 6 }) do
		box(plot, "TiangPalang", V3(0.6, 3.4, 0.6), V3(x, 1.7, alunRoadEnd - 2), RGB(240, 240, 240), M.Metal)
	end
	lockedSign(plot, V3(14, 0, alunRoadEnd - 4), "ALUN-ALUN", -1)
end

-- ── RUKO (deretan toko di utara jalan) ────────────────────────────
local SHOP_NAMES = {
	"Toko Kelontong", "Warung Kopi", "Bengkel Motor", "Fotokopi", "Apotek",
	"Konter Pulsa", "Laundry", "Toko Bangunan", "Warung Nasi", "Pangkas Rambut",
	"Toko Sembako", "Penjahit", "Toko Buku", "Warung Bakso", "Toko Plastik",
}
local SHUTTER_COLORS = { RGB(180, 185, 190), RGB(70, 110, 160), RGB(160, 60, 50), RGB(70, 130, 90) }
local WALL_COLORS = { RGB(240, 230, 200), RGB(220, 230, 235), RGB(245, 215, 190), RGB(230, 225, 235) }

local ruko = folder(kota, "Ruko")
local shopIndex = 0
for _, side in ipairs({ -1, 1 }) do
	for i = 0, 13 do
		local x = side * (60 + i * 13)
		if math.abs(x) < HALF_X - 16 then
			shopIndex += 1
			local base = V3(x, 0, ROAD_HALF + WALK + 8)
			local unit = folder(ruko, "Ruko")
			local wall = WALL_COLORS[(shopIndex % #WALL_COLORS) + 1]
			local shutter = SHUTTER_COLORS[(shopIndex % #SHUTTER_COLORS) + 1]
			box(unit, "Bangunan", V3(12.6, 12, 14), base + V3(0, 6, 1), wall, M.Concrete)
			box(unit, "Teras", V3(12.6, 0.6, 4), base + V3(0, 0.3, -7.6), SIDEWALK, M.Concrete)
			box(unit, "RollingDoor", V3(10, 5.6, 0.2), base + V3(0, 2.8, -6.05), shutter, M.DiamondPlate)
			box(unit, "Kanopi", V3(12.6, 0.4, 3), base + V3(0, 6.6, -7.4), shutter, M.Metal)
			local sign = box(unit, "PapanToko", V3(10, 2.2, 0.3), base + V3(0, 8.4, -6.2), CREAM)
			signText(sign, Enum.NormalId.Front, SHOP_NAMES[(shopIndex - 1) % #SHOP_NAMES + 1], RGB(60, 40, 30), CREAM)
			box(unit, "JendelaAtas", V3(8, 2.4, 0.2), base + V3(0, 10.6, -6.05), RGB(110, 150, 180), M.Glass)
		end
	end
end

-- ── RUMAH (di sela-sela plot selatan) ──────────────────────────────
local rumah = folder(kota, "Rumah")
local ROOF_COLORS = { RGB(170, 70, 45), RGB(140, 60, 40), RGB(90, 90, 100) }
local function house(pos, facing)
	local m = folder(rumah, "Rumah")
	local wall = WALL_COLORS[rng:NextInteger(1, #WALL_COLORS)]
	local roof = ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)]
	box(m, "Dinding", V3(12, 7, 10), pos + V3(0, 3.5, 0), wall, M.Plaster)
	box(m, "Atap", V3(14, 1.2, 12), pos + V3(0, 7.6, 0), roof, M.Slate)
	box(m, "Atap", V3(10, 1, 8), pos + V3(0, 8.7, 0), roof, M.Slate)
	box(m, "Pintu", V3(2.4, 4.5, 0.2), pos + V3(-2.5, 2.25, facing * 5.05), RGB(110, 72, 40), M.Wood)
	box(m, "Jendela", V3(3, 2.2, 0.2), pos + V3(2.5, 3.8, facing * 5.05), RGB(110, 150, 180), M.Glass)
end

for _, x in ipairs({ -95, -75, -55, 55, 75, 95 }) do
	house(V3(x, 0, -40), 1)
	house(V3(x, 0, -66), 1)
end
for _, x in ipairs({ -224, 224 }) do
	house(V3(x, 0, -40), 1)
	house(V3(x, 0, -66), 1)
end

-- ── POHON ──────────────────────────────────────────────────────────
local pohon = folder(kota, "Pohon")
-- Sepanjang trotoar selatan, di sela lampu.
for x = -HALF_X + 12, HALF_X - 12, 32 do
	if math.abs(x) > 40 then
		tree(pohon, V3(x, 0, -(ROAD_HALF + WALK + 3)), 0.9)
	end
end
-- Barisan pohon di pinggir kota (batas alami).
for x = -HALF_X, HALF_X, 18 do
	tree(pohon, V3(x + rng:NextNumber(-3, 3), 0, MIN_Z + rng:NextNumber(0, 6)), rng:NextNumber(1, 1.4))
	if math.abs(x) > 56 then
		tree(pohon, V3(x + rng:NextNumber(-3, 3), 0, MAX_Z - rng:NextNumber(0, 6)), rng:NextNumber(1, 1.4))
	end
end
for z = MIN_Z + 18, MAX_Z - 18, 18 do
	tree(pohon, V3(-HALF_X + rng:NextNumber(0, 6), 0, z), rng:NextNumber(1, 1.4))
	tree(pohon, V3(HALF_X - rng:NextNumber(0, 6), 0, z), rng:NextNumber(1, 1.4))
end
-- Kebun kecil di belakang ruko.
for _ = 1, 24 do
	local x = rng:NextNumber(-HALF_X + 20, HALF_X - 20)
	if math.abs(x) > 52 then
		tree(pohon, V3(x, 0, rng:NextNumber(48, MAX_Z - 20)), rng:NextNumber(0.8, 1.2))
	end
end

-- ── BATAS KOTA (tembok nggak keliatan biar player nggak keluar map) ─
local batas = folder(kota, "Batas")
local wallHeight = 60
local function invisibleWall(size, pos)
	box(batas, "TembokBatas", size, pos, RGB(0, 0, 0), M.SmoothPlastic, {
		Transparency = 1,
		CanQuery = false,
	})
end
invisibleWall(V3(1, wallHeight, MAX_Z - MIN_Z + 20), V3(-HALF_X - 6, wallHeight / 2, (MIN_Z + MAX_Z) / 2))
invisibleWall(V3(1, wallHeight, MAX_Z - MIN_Z + 20), V3(HALF_X + 6, wallHeight / 2, (MIN_Z + MAX_Z) / 2))
invisibleWall(V3(HALF_X * 2 + 20, wallHeight, 1), V3(0, wallHeight / 2, MIN_Z - 6))
invisibleWall(V3(HALF_X * 2 + 20, wallHeight, 1), V3(0, wallHeight / 2, MAX_Z + 6))

kota.Parent = workspace
return "ok"
