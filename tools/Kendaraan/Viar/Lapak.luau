--[[
	Isi box: tempat nyimpen barang + etalase. Masaknya NGGAK di sini (goreng
	minyak panas di box tertutup nggak masuk akal), tapi di meja goreng di
	luar box yang muncul pas buka lapak (lihat LapakLuar.luau).

	  depan  [ ETALASE KACA (ngadep pembeli) ][ tirisan ][ baskom, sambel ]  <- counter (kiri)
	         [ stok: gabus, krat, jerigen ]                [ karung ]       <- sisi kanan
]]

local D = require(script.Parent.Dasar)
local Bantu = D.Bantu

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local W = Bantu.WARNA
local UPRIGHT = Bantu.UPRIGHT
local L = D.L
local box, cylinder, ball, model = Bantu.box, Bantu.cylinder, Bantu.ball, Bantu.model

local BED = D.BED_TOP
local TOP = D.COUNTER_TOP
local TAHU_GORENG = RGB(205, 140, 45)
local TAHU_MENTAH = RGB(245, 240, 220)

-- Counter: dari rel rangka kiri sampe tepi dalem, sepanjang dinding dalem box.
local COUNTER_X1 = -(D.BOX_W / 2 - D.RANGKA)
local COUNTER_X2 = D.COUNTER_DALAM
local Z1 = D.BOX_DEPAN + D.MASUK + D.PANEL
local Z2 = D.BOX_BELAKANG - D.MASUK - D.PANEL

local function counter(lapak)
	local m = model(lapak, "Counter")
	local width = COUNTER_X2 - COUNTER_X1
	local zMid = (Z1 + Z2) / 2
	box(m, "PapanCounter", V3(width, 0.12, Z2 - Z1), L((COUNTER_X1 + COUNTER_X2) / 2, TOP - 0.06, zMid), W.KAYU, M.WoodPlanks)

	-- Kolong counter (masuk dikit dari tepi papan), pintu ngadep dalem box.
	local cabX2 = COUNTER_X2 - 0.16
	local cabH = TOP - 0.12 - BED
	box(m, "KolongCounter", V3(cabX2 - (COUNTER_X1 - 0.06), cabH, Z2 - Z1), L((cabX2 + COUNTER_X1 - 0.06) / 2, BED + cabH / 2, zMid), W.KAYU_GELAP, M.Wood)
	for _, z in ipairs({ -0.3, 1.5, 3.5, 5.4 }) do
		box(m, "PintuKolong", V3(0.05, 1.0, 1.7), L(cabX2 + 0.025, BED + 0.65, z), W.KAYU, M.Wood)
		box(m, "GagangKolong", V3(0.06, 0.18, 0.06), L(cabX2 + 0.08, BED + 0.9, z + 0.6), W.KROM, M.Metal)
	end
end

local function etalase(lapak)
	-- Etalase kaca panjang di atas counter, tulisannya ngadep pembeli (kiri).
	local m = model(lapak, "Etalase")
	local x, z = -1.7, 1.2
	local w, l, h = 2.0, 3.6, 1.15
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
		for col = 0, 4 do
			ball(m, "TahuPajangan", 0.45, L(x - 0.4 + row * 0.8, bottom + 0.23, z - 1.3 + col * 0.65), TAHU_GORENG)
		end
	end
	for col = 0, 3 do
		ball(m, "TahuPajangan", 0.45, L(x, bottom + 0.6, z - 1.0 + col * 0.65), RGB(195, 130, 40))
	end
end

local function meja(lapak)
	-- Bagian belakang counter: tirisan, baskom tahu mentah, sambel, kertas.
	local m = model(lapak, "MejaKerja")
	box(m, "Tirisan", V3(1.0, 0.05, 1.0), L(-2.1, TOP + 0.025, 4.1), W.KROM, M.DiamondPlate)
	for i = 0, 3 do
		ball(m, "TahuTiris", 0.42, L(-2.35 + (i % 2) * 0.5, TOP + 0.26, 3.85 + math.floor(i / 2) * 0.5), TAHU_GORENG)
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

local function stok(lapak)
	-- Sisi kanan box: stok barang.
	local m = model(lapak, "Stok")
	box(m, "KotakGabus", V3(1.4, 0.75, 1.0), L(2.0, BED + 0.375, -0.6), W.PUTIH, M.SmoothPlastic)
	box(m, "Krat", V3(1.2, 0.6, 0.9), L(2.0, BED + 0.75 + 0.3, -0.6), RGB(230, 120, 30), M.SmoothPlastic)
	for i = 0, 2 do
		box(m, "TahuDiKrat", V3(0.3, 0.2, 0.3), L(1.6 + i * 0.4, BED + 1.35 + 0.1, -0.6), TAHU_MENTAH)
	end
	box(m, "JerigenMinyak", V3(0.55, 0.85, 0.4), L(2.3, BED + 0.425, 1.0), RGB(240, 200, 40))
	cylinder(m, "TutupJerigen", 0.12, 0.15, L(2.45, BED + 0.91, 1.0) * UPRIGHT, RGB(200, 40, 40))
	box(m, "KarungTepung", V3(0.8, 0.95, 0.65), L(2.2, BED + 0.475, 5.4) * CFrame.Angles(0, math.rad(8), 0), RGB(225, 210, 175), M.Fabric)
	box(m, "KratCadangan", V3(1.2, 0.6, 0.9), L(2.0, BED + 0.3, 3.2), RGB(60, 120, 200), M.SmoothPlastic)
end

local function plafon(lapak)
	-- Lampu TL di plafon box.
	local m = model(lapak, "Plafon")
	local lampu = box(m, "LampuTL", V3(0.2, 0.1, 3.0), L(0, D.BOX_TOP - 0.05, 2.5), RGB(255, 250, 235), M.Neon)
	local cahaya = Instance.new("PointLight")
	cahaya.Range = 16
	cahaya.Brightness = 1.3
	cahaya.Color = RGB(255, 235, 200)
	cahaya.Shadows = false
	cahaya.Parent = lampu
end

return function(viar)
	local lapak = model(viar, "Lapak")
	counter(lapak)
	etalase(lapak)
	meja(lapak)
	stok(lapak)
	plafon(lapak)
	return lapak
end
