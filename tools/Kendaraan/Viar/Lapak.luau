--[[
	Isi box: lapak tahu. Counter memanjang di sisi kiri (di bawah panel
	angkat), penjual DUDUK DI DALEM BOX ngadep kiri ke counter & pembeli.

	  depan  [ etalase kaca ][ WAJAN (kompor tanam) ][ tirisan, baskom ]  <- counter (kiri)
	                          KURSI (Seat "KursiGoreng"), ngadep kiri
	         [ stok: gabus, krat, jerigen ]          [ tabung gas ]        <- sisi kanan

	Wajan "ditanam": dudukannya di bawah permukaan counter, papan counter
	dilubangin (CSG) seukuran badan wajan, jadi yang nongol cuma bibirnya.
	Tinggi kursi ngikutin badan R15 (lihat Dasar.luau).
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

local BED = D.BED_TOP
local TOP = D.COUNTER_TOP
local TAHU_GORENG = RGB(205, 140, 45)
local TAHU_MENTAH = RGB(245, 240, 220)

-- Counter: dari rel rangka kiri sampe tepi dalem, sepanjang dinding dalem box.
local COUNTER_X1 = -(D.BOX_W / 2 - D.RANGKA)
local COUNTER_X2 = D.COUNTER_DALAM
local Z1 = D.BOX_DEPAN + D.MASUK + D.PANEL
local Z2 = D.BOX_BELAKANG - D.MASUK - D.PANEL

local WAJAN = V3(-1.6, TOP, 3.4) -- tengah wajan; Y = permukaan counter
local WAJAN_RIM, WAJAN_DALAM = 2.4, 0.6
local WAJAN_TURUN = 0.5 -- dudukan wajan segini di bawah permukaan counter
local KURSI = V3(0.85, BED + 1.1, 3.4) -- Y = permukaan duduk

local function counter(lapak)
	local m = model(lapak, "Counter")
	local width = COUNTER_X2 - COUNTER_X1
	local cx = (COUNTER_X1 + COUNTER_X2) / 2
	local zMid = (Z1 + Z2) / 2

	-- Papan atas dilubangin buat wajan. Jari-jari lubang = jari-jari badan
	-- wajan pas di permukaan counter (bola wajan dipotong setinggi itu).
	local sphereR = ((WAJAN_RIM / 2) ^ 2 + WAJAN_DALAM ^ 2) / (2 * WAJAN_DALAM)
	local h = WAJAN_TURUN - 0.15 -- tinggi permukaan counter dari dasar wajan
	local holeR = math.sqrt(sphereR ^ 2 - (sphereR - h) ^ 2) + 0.01
	Bantu.carve(m, "PapanCounter", box(nil, "Papan", V3(width, 0.12, Z2 - Z1), L(cx, TOP - 0.06, zMid), W.KAYU), {
		cylinder(nil, "Lubang", 0.5, holeR * 2, L(WAJAN.X, TOP, WAJAN.Z) * UPRIGHT, W.KAYU),
	}, W.KAYU, M.WoodPlanks)

	-- Kolong counter (masuk dikit dari tepi papan), pintu ngadep penjual.
	local cabX2 = COUNTER_X2 - 0.16
	local cabH = TOP - 0.12 - BED
	box(m, "KolongCounter", V3(cabX2 - (COUNTER_X1 - 0.06), cabH, Z2 - Z1), L((cabX2 + COUNTER_X1 - 0.06) / 2, BED + cabH / 2, zMid), W.KAYU_GELAP, M.Wood)
	for _, z in ipairs({ -0.3, 1.5, 3.5, 5.4 }) do
		box(m, "PintuKolong", V3(0.05, 1.0, 1.7), L(cabX2 + 0.025, BED + 0.65, z), W.KAYU, M.Wood)
		box(m, "GagangKolong", V3(0.06, 0.18, 0.06), L(cabX2 + 0.08, BED + 0.9, z + 0.6), W.KROM, M.Metal)
	end

	Wajan(m, L(WAJAN.X, TOP - WAJAN_TURUN, WAJAN.Z), WAJAN_RIM, WAJAN_DALAM)
	box(m, "KenopKompor", V3(0.08, 0.2, 0.2), L(cabX2 + 0.04, TOP - 0.25, WAJAN.Z + 1.25), RGB(20, 20, 20))
end

local function etalase(lapak)
	-- Etalase kaca di atas counter bagian depan, tulisannya ngadep pembeli.
	local m = model(lapak, "Etalase")
	local x, z = -1.7, 0.4
	local w, l, h = 2.0, 2.2, 1.15
	box(m, "AlasEtalase", V3(w, 0.08, l), L(x, TOP + 0.04, z), D.ALU, M.Metal)
	local bottom = TOP + 0.08
	local kaca = box(m, "KacaEtalase", V3(w - 0.1, h, l - 0.1), L(x, bottom + h / 2, z), RGB(200, 230, 240), M.Glass, {
		Transparency = 0.6,
	})
	Bantu.surfaceText(kaca, Enum.NormalId.Left, "TAHU", D.MERAH, nil, 40)
	for _, dx in ipairs({ -1, 1 }) do
		for _, dz in ipairs({ -1, 1 }) do
			box(m, "TiangEtalase", V3(0.1, h, 0.1), L(x + dx * (w / 2 - 0.05), bottom + h / 2, z + dz * (l / 2 - 0.05)), D.ALU, M.Metal)
		end
	end
	box(m, "AtasEtalase", V3(w, 0.06, l), L(x, bottom + h + 0.03, z), D.ALU, M.Metal)
	for row = 0, 1 do
		for col = 0, 2 do
			ball(m, "TahuPajangan", 0.45, L(x - 0.4 + row * 0.8, bottom + 0.23, z - 0.6 + col * 0.6), TAHU_GORENG)
		end
	end
	for col = 0, 1 do
		ball(m, "TahuPajangan", 0.45, L(x, bottom + 0.6, z - 0.3 + col * 0.6), RGB(195, 130, 40))
	end
end

local function meja(lapak)
	-- Bagian belakang counter: tirisan, baskom tahu mentah, sambel, kertas.
	local m = model(lapak, "MejaKerja")
	box(m, "Tirisan", V3(1.0, 0.05, 1.0), L(-2.1, TOP + 0.025, 5.3), W.KROM, M.DiamondPlate)
	for i = 0, 3 do
		ball(m, "TahuTiris", 0.42, L(-2.35 + (i % 2) * 0.5, TOP + 0.26, 5.05 + math.floor(i / 2) * 0.5), TAHU_GORENG)
	end

	local bowl = L(-1.05, TOP + 0.2, 5.75)
	Bantu.carve(m, "Baskom", cylinder(nil, "Luar", 0.4, 0.9, bowl * UPRIGHT, RGB(60, 120, 200)), {
		cylinder(nil, "Dalam", 0.4, 0.78, bowl * CFrame.new(0, 0.05, 0) * UPRIGHT, RGB(60, 120, 200)),
	}, RGB(60, 120, 200), M.SmoothPlastic)
	cylinder(m, "AirBaskom", 0.04, 0.77, bowl * CFrame.new(0, 0.1, 0) * UPRIGHT, RGB(200, 225, 235), M.Glass, {
		Transparency = 0.3,
	})
	for _, d in ipairs({ V3(-0.15, 0.12, -0.15), V3(0.15, 0.12, 0.15), V3(0.15, 0.12, -0.15) }) do
		box(m, "TahuMentah", V3(0.26, 0.2, 0.26), bowl * CFrame.new(d), TAHU_MENTAH)
	end

	for i = 0, 1 do
		local bottle = L(-2.5 + i * 0.25, TOP + 0.25, 6.1)
		cylinder(m, "BotolSambal", 0.5, 0.18, bottle * UPRIGHT, RGB(190, 30, 25))
		cylinder(m, "TutupBotol", 0.1, 0.1, bottle * CFrame.new(0, 0.3, 0) * UPRIGHT, W.PUTIH)
	end
	box(m, "KertasBungkus", V3(0.6, 0.15, 0.4), L(-1.85, TOP + 0.075, 6.1), RGB(235, 225, 195), M.SmoothPlastic)
end

local function kursi(viar, lapak)
	-- Kursi bar kayu ngadep kiri (ke counter), sandaran di kanan.
	local m = model(lapak, "KursiPenjual")
	local x, top, z = KURSI.X, KURSI.Y, KURSI.Z
	cylinder(m, "DudukanKursi", 0.15, 1.1, L(x, top - 0.075, z) * UPRIGHT, RGB(35, 35, 38), M.Leather)
	local feet, tops = {}, {}
	for _, d in ipairs({ V3(-1, 0, -1), V3(1, 0, -1), V3(1, 0, 1), V3(-1, 0, 1) }) do
		table.insert(feet, P(x + d.X * 0.4, BED, z + d.Z * 0.4))
		table.insert(tops, P(x + d.X * 0.25, top - 0.15, z + d.Z * 0.25))
	end
	for i = 1, 4 do
		tube(m, "KakiKursi", feet[i], tops[i], 0.1, W.KAYU_GELAP, M.Wood)
	end
	-- Pijakan kaki melingkar (di ketinggian 40% kaki).
	local ring = {}
	for i = 1, 4 do
		ring[i] = feet[i]:Lerp(tops[i], 0.4)
	end
	for i = 1, 4 do
		tube(m, "PijakanKursi", ring[i], ring[i % 4 + 1], 0.07, W.KROM, M.Metal)
	end
	for _, dz in ipairs({ -0.35, 0.35 }) do
		tube(m, "TiangSandaran", P(x + 0.42, top, z + dz), P(x + 0.55, top + 0.95, z + dz), 0.08, W.KAYU_GELAP, M.Wood)
	end
	box(m, "Sandaran", V3(0.1, 0.4, 0.95), L(x + 0.6, top + 0.8, z) * CFrame.Angles(0, 0, math.rad(-8)), RGB(35, 35, 38), M.Leather)

	local seat = Instance.new("Seat")
	seat.Name = "KursiGoreng"
	seat.Anchored = true
	seat.Size = V3(1, 0.2, 1)
	seat.CFrame = L(x, top - 0.1, z) * CFrame.Angles(0, math.rad(90), 0) -- ngadep -X (ke counter & pembeli)
	seat.Transparency = 1
	seat.Parent = viar
	-- Jangkauan pendek + harus keliatan langsung: cuma muncul kalau beneran deket
	-- kursi (di dalem box / nempel counter), nggak dari jok supir atau luar dinding.
	local duduk = D.prompt(seat, "DudukPrompt", "Duduk Jualan", "Kursi", Enum.KeyCode.G, Enum.KeyCode.ButtonX, 5)
	duduk.RequiresLineOfSight = true
end

local function stok(lapak)
	-- Sisi kanan box: stok + tabung gas (selangnya masuk ke kolong counter).
	local m = model(lapak, "Stok")
	box(m, "KotakGabus", V3(1.4, 0.75, 1.0), L(2.0, BED + 0.375, -0.6), W.PUTIH, M.SmoothPlastic)
	box(m, "Krat", V3(1.2, 0.6, 0.9), L(2.0, BED + 0.75 + 0.3, -0.6), RGB(230, 120, 30), M.SmoothPlastic)
	for i = 0, 2 do
		box(m, "TahuDiKrat", V3(0.3, 0.2, 0.3), L(1.6 + i * 0.4, BED + 1.35 + 0.1, -0.6), TAHU_MENTAH)
	end
	box(m, "JerigenMinyak", V3(0.55, 0.85, 0.4), L(2.3, BED + 0.425, 1.0), RGB(240, 200, 40))
	cylinder(m, "TutupJerigen", 0.12, 0.15, L(2.45, BED + 0.91, 1.0) * UPRIGHT, RGB(200, 40, 40))
	box(m, "KarungTepung", V3(0.8, 0.95, 0.65), L(2.2, BED + 0.475, 5.4) * CFrame.Angles(0, math.rad(8), 0), RGB(225, 210, 175), M.Fabric)

	local gx, gz = -0.15, 5.9
	local GAS = RGB(95, 165, 60)
	cylinder(m, "TabungGas", 0.95, 0.85, L(gx, BED + 0.475, gz) * UPRIGHT, GAS)
	cylinder(m, "LeherTabung", 0.25, 0.35, L(gx, BED + 1.07, gz) * UPRIGHT, GAS)
	cylinder(m, "Regulator", 0.2, 0.3, L(gx, BED + 1.29, gz) * UPRIGHT, W.KROM, M.Metal)
	local hose = { P(gx, BED + 1.3, gz), P(-0.45, BED + 0.9, 5.3), P(COUNTER_X2 - 0.2, BED + 0.6, 4.7) }
	for i = 1, #hose - 1 do
		tube(m, "Selang", hose[i], hose[i + 1], 0.08, RGB(200, 60, 40), M.Rubber)
	end
	ball(m, "Selang", 0.08, CFrame.new(hose[2]) * D.BUILD_AT.Rotation, RGB(200, 60, 40), M.Rubber)
end

local function langitLangit(lapak)
	-- Lampu TL di plafon + gantungan serok & sutil di atas counter.
	local m = model(lapak, "Plafon")
	local ceiling = D.BOX_TOP
	local lampu = box(m, "LampuTL", V3(0.2, 0.1, 3.0), L(0, ceiling - 0.05, 2.5), RGB(255, 250, 235), M.Neon)
	local cahaya = Instance.new("PointLight")
	cahaya.Range = 16
	cahaya.Brightness = 1.3
	cahaya.Color = RGB(255, 235, 200)
	cahaya.Shadows = false
	cahaya.Parent = lampu

	local railY, railX = ceiling - 0.6, -2.3
	tube(m, "Gantungan", P(railX, railY, 4.6), P(railX, railY, 6.0), 0.08, W.KROM, M.Metal)
	for _, z in ipairs({ 4.7, 5.9 }) do
		tube(m, "TaliGantungan", P(railX, ceiling, z), P(railX, railY, z), 0.05, W.RANGKA, M.Metal)
	end
	tube(m, "GagangSerok", P(railX, railY, 4.95), P(railX, railY - 1.0, 4.95), 0.07, W.KAYU, M.Wood)
	cylinder(m, "JaringSerok", 0.04, 0.5, L(railX, railY - 1.25, 4.95), RGB(150, 150, 155), M.DiamondPlate)
	tube(m, "GagangSutil", P(railX, railY, 5.6), P(railX, railY - 0.9, 5.6), 0.07, W.KAYU, M.Wood)
	box(m, "Sutil", V3(0.04, 0.45, 0.4), L(railX, railY - 1.12, 5.6), W.KROM, M.Metal)
end

return function(viar)
	local lapak = model(viar, "Lapak")
	counter(lapak)
	etalase(lapak)
	meja(lapak)
	kursi(viar, lapak)
	stok(lapak)
	langitLangit(lapak)
	return lapak
end
