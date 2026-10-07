--[[
	Lapak luar: meja goreng + bangku plastik yang muncul di SISI KIRI LUAR
	gerobak (di bawah panel yang keangkat jadi peneduh) pas buka lapak, plus
	tangga lipat di belakang buat masuk ke box lewat pintu belakang.
	Goreng di udara terbuka, kayak tukang gorengan pinggir jalan.

	Ini template terpisah (ServerStorage.Kendaraan.ViarLapak), BUKAN bagian
	dari model kendaraan: semua part-nya Anchored dan nggak di-weld ke
	kendaraan. KendaraanService nge-clone ini ke posisi kendaraan pas lapak
	buka (kendaraan dikunci selama itu) dan ngapus pas lapak tutup.

	Tampak atas (kiri = luar gerobak):

	  pembeli  |  MEJA GORENG  |  penjual  | box
	  (kosong) | wajan, tiris  |  bangku   |  gerobak
	           |  [gas di tanah, ujung belakang meja]

	Koordinat sama kayak kendaraan (Dasar.luau), Y 0 = tanah. Part "Dasar"
	(nggak keliatan) = pivot, di titik yang sama kayak pivot kendaraan.
	Nama yang dipake script: KursiGoreng (Seat) + DudukPrompt, Wajan.
]]

local D = require(script.Parent.Dasar)
local Bantu = D.Bantu
local Wajan = require(script.Parent.Parent.Wajan)

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local W = Bantu.WARNA
local UPRIGHT = Bantu.UPRIGHT
local L, P = D.L, D.P
local box, cylinder, ball, model, tube = Bantu.box, Bantu.cylinder, Bantu.ball, Bantu.model, Bantu.tube

local TAHU_GORENG = RGB(205, 140, 45)
local MERAH_PLASTIK = RGB(210, 35, 40)

-- Meja: sejajar sisi kiri box, jarak 2.4 stud dari box buat tempat penjual.
local MEJA = V3(-6.1, 2.4, 3.8) -- tengah meja; Y = permukaan atas (setinggi pinggang)
local MEJA_SIZE = V3(1.4, 0.12, 4.0)
local WAJAN_Z = 4.6
local BANGKU = V3(-4.0, 1.7, WAJAN_Z) -- Y = permukaan duduk; sejajar wajan

local function mejaGoreng(m)
	local x, top, z = MEJA.X, MEJA.Y, MEJA.Z
	box(m, "PapanMeja", MEJA_SIZE, L(x, top - MEJA_SIZE.Y / 2, z), W.KAYU, M.WoodPlanks)
	local legTop = top - MEJA_SIZE.Y
	for _, dx in ipairs({ -0.6, 0.6 }) do
		for _, dz in ipairs({ -1.85, 1.85 }) do
			tube(m, "KakiMeja", P(x + dx, 0, z + dz), P(x + dx, legTop, z + dz), 0.12, W.BESI, M.Metal)
		end
		tube(m, "PalangMeja", P(x + dx, 0.5, z - 1.85), P(x + dx, 0.5, z + 1.85), 0.08, W.BESI, M.Metal)
	end
	-- Kain penutup sisi depan meja (ngadep pembeli) + harga.
	local kain = box(m, "KainMeja", V3(0.05, 0.75, MEJA_SIZE.Z), L(x - MEJA_SIZE.X / 2 - 0.025, legTop - 0.375, z), W.KRIM, M.Fabric)
	Bantu.surfaceText(kain, Enum.NormalId.Left, "Tahu Goreng  •  Rp 500", RGB(150, 40, 25), W.KRIM)

	-- Kompor 1 tungku + wajan (api biru keliatan, udara terbuka).
	local komporTop = top + 0.25
	box(m, "Kompor", V3(1.0, 0.25, 1.0), L(x, top + 0.125, WAJAN_Z), RGB(45, 45, 50), M.Metal)
	box(m, "KenopKompor", V3(0.08, 0.14, 0.14), L(x + 0.54, top + 0.125, WAJAN_Z + 0.3), RGB(200, 200, 205), M.Metal)
	Wajan(m, L(x, komporTop, WAJAN_Z), 2.2, 0.55)

	-- Tirisan berisi tahu mateng di ujung depan meja.
	local tirisZ = z - MEJA_SIZE.Z / 2 + 0.7
	box(m, "Tirisan", V3(1.0, 0.05, 1.1), L(x, top + 0.025, tirisZ), W.KROM, M.DiamondPlate)
	for i = 0, 3 do
		ball(m, "TahuTiris", 0.42, L(x - 0.25 + (i % 2) * 0.5, top + 0.26, tirisZ - 0.25 + math.floor(i / 2) * 0.5), TAHU_GORENG)
	end

	-- Serok & sutil digantung di ujung belakang meja.
	local endZ = z + MEJA_SIZE.Z / 2 + 0.06
	tube(m, "GagangSerok", P(x + 0.25, legTop - 0.05, endZ), P(x + 0.25, legTop - 0.9, endZ), 0.07, W.KAYU, M.Wood)
	cylinder(m, "JaringSerok", 0.04, 0.5, L(x + 0.25, legTop - 1.15, endZ) * Bantu.ALONG_Z, RGB(150, 150, 155), M.DiamondPlate)
	tube(m, "GagangSutil", P(x - 0.3, legTop - 0.05, endZ), P(x - 0.3, legTop - 0.8, endZ), 0.07, W.KAYU, M.Wood)
	box(m, "Sutil", V3(0.4, 0.45, 0.04), L(x - 0.3, legTop - 1.02, endZ), W.KROM, M.Metal)

	-- Tabung gas melon di tanah, di belakang ujung meja, selangnya ke kompor.
	local gx, gz = x, z + MEJA_SIZE.Z / 2 + 0.85
	local GAS = RGB(95, 165, 60)
	cylinder(m, "TabungGas", 0.95, 0.85, L(gx, 0.475, gz) * UPRIGHT, GAS)
	cylinder(m, "LeherTabung", 0.25, 0.35, L(gx, 1.07, gz) * UPRIGHT, GAS)
	cylinder(m, "Regulator", 0.2, 0.3, L(gx, 1.29, gz) * UPRIGHT, W.KROM, M.Metal)
	local hose = { P(gx, 1.3, gz), P(x + 0.45, 1.0, z + MEJA_SIZE.Z / 2 - 0.3), P(x + 0.45, top + 0.1, WAJAN_Z + 0.4) }
	for i = 1, #hose - 1 do
		tube(m, "Selang", hose[i], hose[i + 1], 0.08, RGB(200, 60, 40), M.Rubber)
	end
	ball(m, "Selang", 0.08, CFrame.new(hose[2]) * D.BUILD_AT.Rotation, RGB(200, 60, 40), M.Rubber)
end

local function bangku(m)
	-- Bangku plastik merah di tanah, ngadep wajan (-X).
	local x, top, z = BANGKU.X, BANGKU.Y, BANGKU.Z
	cylinder(m, "DudukanBangku", 0.12, 1.1, L(x, top - 0.06, z) * UPRIGHT, MERAH_PLASTIK)
	local feet, tops = {}, {}
	for _, d in ipairs({ V3(-1, 0, -1), V3(1, 0, -1), V3(1, 0, 1), V3(-1, 0, 1) }) do
		table.insert(feet, P(x + d.X * 0.48, 0, z + d.Z * 0.48))
		table.insert(tops, P(x + d.X * 0.32, top - 0.12, z + d.Z * 0.32))
	end
	for i = 1, 4 do
		tube(m, "KakiBangku", feet[i], tops[i], 0.12, MERAH_PLASTIK)
	end
	for i = 1, 4 do
		tube(m, "LingkarBangku", feet[i]:Lerp(tops[i], 0.35), feet[i % 4 + 1]:Lerp(tops[i % 4 + 1], 0.35), 0.07, MERAH_PLASTIK)
	end

	local seat = Instance.new("Seat")
	seat.Name = "KursiGoreng"
	seat.Anchored = true
	seat.Size = V3(1, 0.2, 1)
	seat.CFrame = L(x, top - 0.1, z) * CFrame.Angles(0, math.rad(90), 0) -- ngadep -X (ke wajan & pembeli)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Parent = m
	-- Jangkauan pendek + harus keliatan langsung: cuma muncul kalau beneran deket bangku.
	local duduk = D.prompt(seat, "DudukPrompt", "Duduk Goreng", "Bangku", Enum.KeyCode.G, Enum.KeyCode.ButtonX, 5)
	duduk.RequiresLineOfSight = true
end

local function tangga(m)
	-- Tangga lipat aluminium di belakang bumper, buat naik ke pintu belakang box.
	-- Dua anak tangga (0.8 & 1.6), terus satu langkah lagi ke lantai box.
	local z0 = D.BOX_BELAKANG + 0.25
	for _, step in ipairs({ { top = 1.6, z = z0 + 0.35 }, { top = 0.8, z = z0 + 1.05 } }) do
		box(m, "AnakTangga", V3(1.8, 0.12, 0.7), L(0, step.top - 0.06, step.z), D.ALU, M.DiamondPlate)
	end
	for _, sx in ipairs({ -1, 1 }) do
		tube(m, "RangkaTangga", P(sx * 0.95, 0, z0 + 1.5), P(sx * 0.95, 1.6, z0 + 0.05), 0.1, D.ALU, M.Metal)
	end
end

-- Yang boleh ditabrak orang: meja, bangku, tangga, tabung gas. Sisanya tembus.
local SOLID = {
	PapanMeja = true,
	KakiMeja = true,
	DudukanBangku = true,
	AnakTangga = true,
	KakiBangku = true,
	TabungGas = true,
}

return function()
	local m = Instance.new("Model")
	m.Name = "LapakLuar"
	local dasar = box(m, "Dasar", V3(1, 1, 1), D.BUILD_AT, W.RANGKA, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	m.PrimaryPart = dasar
	mejaGoreng(m)
	bangku(m)
	tangga(m)

	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false -- biar Seat nggak "nyedot" orang yang nyenggol
			if p ~= dasar and p.ClassName ~= "Seat" then
				p.CanCollide = SOLID[p.Name] == true
			end
		end
	end
	return m
end
