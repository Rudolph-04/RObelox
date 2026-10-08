--[[
	Pernak-pernik lapak luar (dipanggil dari LapakLuar). Murni hiasan: nggak
	ada script yang nyari part di sini, jadi bebas digeser/dihapus.

	Isinya, ngikutin posisi meja/wajan/bangku di LapakLuar:
	  - ember air + tahu mentah, baskom adonan di atas peti kecil
	    (di tanah samping bangku penjual)
	  - tumpukan peti di depan meja (sisi depan kendaraan) = "meja kasir":
	    kaleng biskuit bekas buat uang, toples cabe rawit, botol saos,
	    tumpukan kertas bungkus
	  - kipas anyaman di meja deket kompor, lap nyampir di pinggir meja
	  - tiang bambu + bohlam menjuntai di atas meja

	Tanpa tulisan & tanpa merek. Semua part ikut aturan LapakLuar (anchored,
	nggak bisa ditabrak, CanTouch mati). Angka acak sengaja nggak dipake
	biar hasil build selalu sama.
]]

local D = require(script.Parent.Dasar)
local Bantu = D.Bantu

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local W = Bantu.WARNA
local UPRIGHT = Bantu.UPRIGHT
local L, P = D.L, D.P
local box, cylinder, ball, tube = Bantu.box, Bantu.cylinder, Bantu.ball, Bantu.tube

local TAHU_MENTAH = RGB(245, 240, 222)
local KAYU_PETI = RGB(176, 132, 80)
local KAYU_PETI_GELAP = RGB(128, 90, 52)
local BAMBU = RGB(198, 172, 108)

local function rotY(deg)
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Wadah bulet terbuka (ember/baskom): silinder dikurangi silinder dalem.
local function wadah(m, name, x, z, bottomY, height, diameter, wall, color, material)
	local center = L(x, bottomY + height / 2, z) * UPRIGHT
	local inner = L(x, bottomY + height / 2 + wall, z) * UPRIGHT
	return Bantu.carve(m, name, cylinder(nil, "Luar", height, diameter, center, color), {
		cylinder(nil, "Dalam", height, diameter - 2 * wall, inner, color),
	}, color, material)
end

-- Ember air + tahu mentah (stok sebelum digoreng).
local function ember(m, x, z)
	local h, d = 0.8, 0.85
	wadah(m, "Ember", x, z, 0, h, d, 0.06, RGB(40, 110, 200), M.Plastic)
	local airY = 0.6
	cylinder(m, "AirEmber", 0.05, d - 0.11, L(x, airY, z) * UPRIGHT, RGB(150, 200, 230), M.Glass, {
		Transparency = 0.35,
	})
	for i, off in ipairs({ V3(-0.14, 0, -0.12), V3(0.13, 0, -0.1), V3(-0.08, 0, 0.14), V3(0.15, 0, 0.15) }) do
		box(m, "TahuMentah", V3(0.28, 0.28, 0.28), L(x + off.X, airY + 0.05, z + off.Z) * rotY(i * 23), TAHU_MENTAH)
	end
	-- Gagang ember.
	local a, mid, b = P(x - d / 2 + 0.02, h - 0.02, z), P(x, h + 0.32, z), P(x + d / 2 - 0.02, h - 0.02, z)
	tube(m, "GagangEmber", a, mid, 0.04, RGB(60, 60, 65), M.Metal)
	tube(m, "GagangEmber", mid, b, 0.04, RGB(60, 60, 65), M.Metal)
end

-- Peti kecil + baskom adonan tepung di atasnya.
local function baskom(m, x, z)
	local petiH = 0.7
	box(m, "PetiKecil", V3(0.85, petiH, 0.85), L(x, petiH / 2, z) * rotY(6), KAYU_PETI, M.WoodPlanks)
	wadah(m, "Baskom", x, z, petiH, 0.28, 0.85, 0.05, W.KROM, M.Metal)
	cylinder(m, "Adonan", 0.04, 0.76, L(x, petiH + 0.16, z) * UPRIGHT, RGB(240, 228, 195), M.SmoothPlastic)
end

-- Tumpukan peti di depan meja + barang-barang di atasnya.
local function mejaKasir(m, x, z)
	-- Peti bawah + papan-papan di sisi yang ngadep pembeli (-X).
	local bawah = V3(1.2, 1.0, 1.3)
	box(m, "PetiBawah", bawah, L(x, bawah.Y / 2, z), KAYU_PETI, M.WoodPlanks)
	for _, y in ipairs({ 0.3, 0.72 }) do
		box(m, "PapanPeti", V3(0.08, 0.12, bawah.Z - 0.1), L(x - bawah.X / 2 - 0.04, y, z), KAYU_PETI_GELAP, M.WoodPlanks)
	end
	-- Peti atas, sengaja agak miring biar nggak keliatan rapi banget.
	local atas = V3(1.1, 0.9, 1.2)
	box(m, "PetiAtas", atas, L(x, bawah.Y + atas.Y / 2, z) * rotY(4), KAYU_PETI, M.WoodPlanks)
	local top = bawah.Y + atas.Y

	-- Kaleng biskuit bekas = tempat uang.
	local kx, kz = x - 0.27, z - 0.3
	cylinder(m, "KalengUang", 0.3, 0.55, L(kx, top + 0.15, kz) * UPRIGHT, RGB(175, 40, 40), M.Metal)
	cylinder(m, "TutupKaleng", 0.05, 0.6, L(kx, top + 0.325, kz) * rotY(20) * UPRIGHT, RGB(205, 175, 70), M.Metal)

	-- Toples kaca isi cabe rawit hijau.
	local tx, tz = x + 0.25, z - 0.3
	local tH = 0.45
	cylinder(m, "Toples", tH, 0.38, L(tx, top + tH / 2, tz) * UPRIGHT, RGB(220, 235, 235), M.Glass, {
		Transparency = 0.55,
	})
	cylinder(m, "TutupToples", 0.06, 0.4, L(tx, top + tH + 0.03, tz) * UPRIGHT, RGB(200, 45, 40), M.Plastic)
	local cabe = {
		{ 0.00, 0.08, 0.02, 10, 30, 70 },
		{ 0.05, 0.12, -0.04, 60, -20, 15 },
		{ -0.05, 0.16, 0.03, -30, 75, 40 },
		{ 0.02, 0.21, -0.02, 20, 120, -35 },
		{ -0.03, 0.26, 0.05, 80, 10, 60 },
	}
	for _, c in ipairs(cabe) do
		cylinder(m, "CabeRawit", 0.2, 0.06, L(tx + c[1], top + c[2], tz + c[3]) * CFrame.Angles(math.rad(c[4]), math.rad(c[5]), math.rad(c[6])), RGB(70, 150, 45))
	end

	-- Botol saos sambal.
	local bx, bz = x + 0.25, z + 0.3
	cylinder(m, "BotolSaos", 0.5, 0.2, L(bx, top + 0.25, bz) * UPRIGHT, RGB(200, 30, 25), M.Plastic)
	cylinder(m, "LeherBotol", 0.12, 0.1, L(bx, top + 0.56, bz) * UPRIGHT, RGB(200, 30, 25), M.Plastic)
	cylinder(m, "TutupBotol", 0.06, 0.12, L(bx, top + 0.65, bz) * UPRIGHT, RGB(240, 240, 235), M.Plastic)

	-- Tumpukan kertas bungkus (coklat) + selembar kertas koran di atasnya.
	local px, pz = x - 0.27, z + 0.3
	box(m, "KertasBungkus", V3(0.55, 0.12, 0.5), L(px, top + 0.06, pz) * rotY(-8), RGB(175, 140, 95), M.SmoothPlastic)
	box(m, "KertasKoran", V3(0.5, 0.02, 0.45), L(px, top + 0.13, pz) * rotY(17), RGB(232, 226, 210), M.SmoothPlastic)
end

-- Kipas anyaman bambu tergeletak di meja, gagangnya ngadep penjual (+X).
local function kipas(m, x, top, z)
	box(m, "KipasAnyaman", V3(0.55, 0.03, 0.45), L(x, top + 0.015, z) * rotY(10), RGB(205, 180, 120), M.Fabric)
	local dir = (L(0, 0, 0) * rotY(10)).RightVector
	local start = P(x, top + 0.015, z) + dir * 0.27
	tube(m, "GagangKipas", start, start + dir * 0.4, 0.05, BAMBU, M.Wood)
end

-- Lap kain lusuh nyampir di pinggir meja sisi penjual.
local function lap(m, edgeX, top, z)
	local warna = RGB(120, 140, 160)
	box(m, "Lap", V3(0.32, 0.03, 0.38), L(edgeX - 0.15, top + 0.015, z), warna, M.Fabric)
	box(m, "Lap", V3(0.06, 0.6, 0.38), L(edgeX + 0.03, top + 0.03 - 0.3, z), warna, M.Fabric)
end

-- Tiang bambu di pojok depan meja + bohlam menjuntai di atas meja.
local function bohlam(m, poleX, poleZ, bulbX, bulbZ)
	local tinggi = 5.7
	tube(m, "TiangBambu", P(poleX, 0, poleZ), P(poleX, tinggi, poleZ), 0.16, BAMBU, M.Wood)
	tube(m, "LenganBambu", P(poleX, tinggi - 0.1, poleZ), P(bulbX, tinggi - 0.1, bulbZ), 0.1, BAMBU, M.Wood)
	local kabelBawah = 4.3
	tube(m, "Kabel", P(bulbX, tinggi - 0.1, bulbZ), P(bulbX, kabelBawah, bulbZ), 0.04, RGB(20, 20, 22), M.Plastic)
	cylinder(m, "Fitting", 0.18, 0.14, L(bulbX, kabelBawah - 0.09, bulbZ) * UPRIGHT, RGB(20, 20, 22), M.Plastic)
	local bulb = ball(m, "Bohlam", 0.38, L(bulbX, kabelBawah - 0.33, bulbZ), RGB(255, 232, 175), M.Neon)
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 12
	light.Color = RGB(255, 210, 150)
	light.Shadows = false
	light.Parent = bulb
end

-- layout: { meja, mejaSize, wajanZ, bangku } dari LapakLuar.
return function(m, layout)
	local meja, size, bangku = layout.meja, layout.mejaSize, layout.bangku
	local halfX, halfZ = size.X / 2, size.Z / 2
	local frontZ = meja.Z - halfZ -- ujung meja ke arah depan kendaraan
	local backZ = meja.Z + halfZ

	ember(m, bangku.X - 0.7, bangku.Z - 1.4)
	baskom(m, bangku.X - 0.7, bangku.Z - 2.5)
	mejaKasir(m, meja.X, frontZ - 0.85)
	kipas(m, meja.X, meja.Y, layout.wajanZ - 1.26) -- pas di antara tirisan & kompor
	lap(m, meja.X + halfX, meja.Y, backZ - 0.35)
	bohlam(m, meja.X - halfX - 0.2, frontZ - 0.05, meja.X + 0.1, frontZ + 0.8)
end
