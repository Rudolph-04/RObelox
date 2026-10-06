--[[
	Dasar box belakang: lantai, rangka bawah, per daun, as roda belakang,
	sepatbor + karet lumpur, bumper, lampu belakang, plat nomor. Box-nya
	sendiri (rangka, dinding, panel angkat) ada di Box.luau.
]]

local D = require(script.Parent.Dasar)
local Bantu = D.Bantu

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local W = Bantu.WARNA
local L = D.L
local box, cylinder, ball, model = Bantu.box, Bantu.cylinder, Bantu.ball, Bantu.model

return function(viar)
	local bak = model(viar, "Bak")
	local inner = D.BOX_W / 2 - D.RANGKA -- lantai ngepas di dalem rangka bawah
	local zF, zB = D.BOX_DEPAN + D.RANGKA, D.BOX_BELAKANG - D.RANGKA
	local floorBottom = D.BED_TOP - 0.25

	box(bak, "Lantai", V3(inner * 2, 0.25, zB - zF), L(0, D.BED_TOP - 0.125, (zF + zB) / 2), RGB(120, 122, 128), M.DiamondPlate)

	-- Rangka bawah + per daun + as belakang.
	for _, sx in ipairs({ -1, 1 }) do
		box(bak, "RangkaBawah", V3(0.3, 0.3, D.BOX_BELAKANG - D.BOX_DEPAN - 0.4), L(sx * 1.2, floorBottom - 0.16, (D.BOX_DEPAN + D.BOX_BELAKANG) / 2), W.RANGKA, M.Metal)
		box(bak, "PerDaun", V3(0.25, 0.18, 2.2), L(sx * 2.0, 1.55, D.AS_BELAKANG), RGB(60, 60, 64), M.Metal)
	end
	cylinder(bak, "AsBelakang", D.TRACK * 2 - 0.7, 0.3, L(0, D.WHEEL_R, D.AS_BELAKANG), W.RANGKA, M.Metal)
	ball(bak, "Gardan", 0.75, L(-0.3, D.WHEEL_R, D.AS_BELAKANG), RGB(60, 60, 64), M.Metal)

	-- Sepatbor (kulit silinder, bagian bawahnya dipotong) + karet lumpur.
	for _, sx in ipairs({ -1, 1 }) do
		local wheel = L(sx * D.TRACK, D.WHEEL_R, D.AS_BELAKANG)
		Bantu.carve(bak, "Sepatbor", cylinder(nil, "Luar", 0.85, D.WHEEL_R * 2 + 0.4, wheel, D.BODY), {
			cylinder(nil, "Dalam", 1, D.WHEEL_R * 2 + 0.2, wheel, D.BODY),
			box(nil, "Potong", V3(2, 2, 4), wheel * CFrame.new(0, -0.85, 0), D.BODY),
		}, D.BODY, M.SmoothPlastic)
		box(bak, "KaretLumpur", V3(0.85, 0.85, 0.06), L(sx * D.TRACK, 0.75, D.AS_BELAKANG + D.WHEEL_R + 0.25), W.BAN, M.Rubber)
	end

	-- Belakang: bumper, lampu, plat (semua nongol dari muka bumper).
	local bumperZ = D.BOX_BELAKANG + 0.1
	box(bak, "BumperBelakang", V3(D.BOX_W, 0.45, 0.2), L(0, 1.875, bumperZ), W.RANGKA, M.Metal)
	local face = bumperZ + 0.1
	for _, sx in ipairs({ -1, 1 }) do
		box(bak, "LampuBelakang", V3(0.8, 0.3, 0.08), L(sx * 2.35, 1.875, face + 0.04), RGB(220, 30, 30), M.Neon)
		box(bak, "Sein", V3(0.35, 0.3, 0.08), L(sx * 1.65, 1.875, face + 0.04), RGB(255, 150, 30), M.Neon)
	end
	local plat = box(bak, "Plat", V3(1.6, 0.4, 0.06), L(0, 1.875, face + 0.03), RGB(15, 15, 15))
	Bantu.surfaceText(plat, Enum.NormalId.Back, "B 500 TH", W.PUTIH, RGB(15, 15, 15), 60)

	return bak
end
