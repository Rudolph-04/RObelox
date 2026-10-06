--[[
	Box jualan di belakang: rangka aluminium (tiang di tiap sudut + rel atas
	& bawah), dinding, pintu belakang, atap box + papan nama "TAHU JURAGAN",
	atap kabin melengkung di atas pengendara, dan PANEL SAMPING KIRI yang
	bisa diangkat jadi kanopi, disangga 2 piston.

	Panel & piston digerakin client (KendaraanController) lewat Motor6D:
	  "EngselPanel" (chassis -> PanelLuar): Transform = putar di sumbu Z
	      engsel; 0 = ketutup, SUDUT_BUKA = kebuka jadi kanopi.
	  "Piston" (chassis -> tiap bagian piston): Transform diitung tiap frame
	      biar tabung nempel di "PangkalPiston<i>" (attachment di Chassis)
	      dan batang nempel di "UjungPiston<i>" (attachment di PanelLuar).
	      Atribut part: Piston = i, Bagian = "Tabung" / "Batang".
	Attachment di Chassis dibikin di init.luau (Chassis belum ada di sini),
	posisinya dari pangkalPiston yang di-return.

	Return: { gerak = {...} buat Rig, pangkalPiston = { Vector3 dunia, ... },
	          sudutBuka = radian }
]]

local D = require(script.Parent.Dasar)
local Bantu = D.Bantu

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local W = Bantu.WARNA
local ALONG_Z = Bantu.ALONG_Z
local L, P = D.L, D.P
local box, cylinder, ball, model, tube = Bantu.box, Bantu.cylinder, Bantu.ball, Bantu.model, Bantu.tube

local F = D.RANGKA
local HALF = D.BOX_W / 2
local ZF, ZB = D.BOX_DEPAN, D.BOX_BELAKANG
local Z_MID = (ZF + ZB) / 2
local FLOOR_BOTTOM = D.BED_TOP - 0.25
local WALL_X = HALF - D.MASUK - D.PANEL / 2 -- tengah panel dinding samping
local WALL_TOP = D.BOX_TOP - F -- bawah rel atas
local INNER_Z1, INNER_Z2 = ZF + F, ZB - F -- di antara tiang sudut

local function rangka(m)
	-- Tiang sudut dari bawah lantai sampe atas box.
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ ZF + F / 2, ZB - F / 2 }) do
			box(m, "TiangRangka", V3(F, D.BOX_TOP - FLOOR_BOTTOM, F), L(sx * (HALF - F / 2), (D.BOX_TOP + FLOOR_BOTTOM) / 2, z), D.ALU, M.Metal)
		end
	end
	-- Rel atas & bawah (bawah setebal lantai). Rel X di antara tiang.
	for _, y in ipairs({ D.BOX_TOP - F / 2, D.BED_TOP - 0.125 }) do
		local h = y > D.BED_TOP and F or 0.25
		for _, sx in ipairs({ -1, 1 }) do
			box(m, "RelRangka", V3(F, h, INNER_Z2 - INNER_Z1), L(sx * (HALF - F / 2), y, Z_MID), D.ALU, M.Metal)
		end
		for _, z in ipairs({ ZF + F / 2, ZB - F / 2 }) do
			box(m, "RelRangka", V3(D.BOX_W - 2 * F, h, F), L(0, y, z), D.ALU, M.Metal)
		end
	end
	-- Ambang bukaan kiri (setinggi counter).
	box(m, "AmbangBukaan", V3(F, F, INNER_Z2 - INNER_Z1), L(-(HALF - F / 2), D.COUNTER_TOP - F / 2, Z_MID), D.ALU, M.Metal)
end

-- Strip tulisan nempel di muka luar dinding samping (sx = -1 kiri, 1 kanan).
local function stripSamping(m, name, sx, y, h, text, bg, fg)
	local x = sx * (HALF - D.MASUK / 2)
	local s = box(m, name, V3(D.MASUK, h, INNER_Z2 - INNER_Z1), L(x, y, Z_MID), bg, M.SmoothPlastic)
	Bantu.surfaceText(s, sx < 0 and Enum.NormalId.Left or Enum.NormalId.Right, text, fg, bg)
	return s
end

local function dinding(m)
	local h = WALL_TOP - D.BED_TOP
	local y = (WALL_TOP + D.BED_TOP) / 2
	local innerX = HALF - F -- di antara tiang sudut
	box(m, "DindingKanan", V3(D.PANEL, h, INNER_Z2 - INNER_Z1), L(WALL_X, y, Z_MID), D.DINDING, M.SmoothPlastic)
	for _, z in ipairs({ ZF + D.MASUK + D.PANEL / 2, ZB - D.MASUK - D.PANEL / 2 }) do
		box(m, z < 0 and "DindingDepan" or "DindingBelakang", V3(innerX * 2, h, D.PANEL), L(0, y, z), D.DINDING, M.SmoothPlastic)
	end
	-- Dinding counter (bawah bukaan kiri), muka luarnya keliatan pembeli.
	local counterH = D.COUNTER_TOP - F - D.BED_TOP
	box(m, "DindingCounter", V3(D.PANEL, counterH, INNER_Z2 - INNER_Z1), L(-WALL_X, D.BED_TOP + counterH / 2, Z_MID), D.DINDING, M.SmoothPlastic)

	-- Branding.
	stripSamping(m, "StripNama", 1, WALL_TOP - 0.75, 1.1, "TAHU JURAGAN", D.MERAH, W.PUTIH)
	stripSamping(m, "StripHarga", 1, D.BED_TOP + 1.0, 0.7, "Tahu Goreng  •  Rp 500", D.KUNING, RGB(120, 40, 20))
	stripSamping(m, "StripHarga", -1, D.BED_TOP + 0.75, 0.7, "Tahu Goreng  •  Rp 500", D.KUNING, RGB(120, 40, 20))
	for _, z in ipairs({ ZF + D.MASUK / 2, ZB - D.MASUK / 2 }) do
		local s = box(m, "StripNama", V3(innerX * 2, 0.8, D.MASUK), L(0, WALL_TOP - 0.6, z), D.MERAH, M.SmoothPlastic)
		Bantu.surfaceText(s, z < 0 and Enum.NormalId.Front or Enum.NormalId.Back, "TAHU JURAGAN", W.PUTIH, D.MERAH)
	end

	-- Pintu belakang (nongol dari dinding, segaris muka rangka).
	local doorZ = ZB - D.MASUK / 2
	box(m, "PintuBelakang", V3(2.6, 4.2, D.MASUK), L(0, D.BED_TOP + 0.3 + 2.1, doorZ), RGB(235, 230, 218), M.SmoothPlastic)
	box(m, "GagangPintu", V3(0.12, 0.6, 0.08), L(0.95, D.BED_TOP + 2.3, ZB + 0.04), W.KROM, M.Metal)
	for _, y in ipairs({ D.BED_TOP + 0.9, D.BED_TOP + 3.9 }) do
		box(m, "EngselPintu", V3(0.3, 0.25, 0.06), L(-1.15, y, ZB + 0.03), W.KROM, M.Metal)
	end
end

local function atapBox(m)
	local top = D.BOX_TOP
	box(m, "AtapBox", V3(D.BOX_W + 0.2, 0.12, ZB - ZF + 0.2), L(0, top + 0.06, Z_MID), D.DINDING, M.SmoothPlastic)

	-- Papan nama memanjang di atas box (kebaca dari kiri & kanan).
	local signBottom = top + 0.12 + 0.15
	local signH = 1.1
	for _, z in ipairs({ Z_MID - 2, Z_MID + 2 }) do
		box(m, "KakiPapan", V3(0.15, 0.15, 0.15), L(0, top + 0.12 + 0.075, z), D.ALU, M.Metal)
	end
	box(m, "PapanNama", V3(0.25, signH, 5.6), L(0, signBottom + signH / 2, Z_MID), D.MERAH, M.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		local muka = box(m, "MukaPapan", V3(0.05, signH - 0.2, 5.4), L(sx * 0.15, signBottom + signH / 2, Z_MID), W.KRIM, M.SmoothPlastic)
		Bantu.surfaceText(muka, sx < 0 and Enum.NormalId.Left or Enum.NormalId.Right, "TAHU JURAGAN", D.MERAH, W.KRIM)
	end
end

local function atapKabin(m)
	-- Atap melengkung di atas pengendara, nyelip di bawah tepi atap box.
	local width = 3.4
	local points = {}
	for i = 0, 5 do
		local t = i / 5
		table.insert(points, P(0, D.BOX_TOP + 0.02 - 1.05 * t * t, ZF - 0.05 - 3.3 * t))
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local cf = CFrame.lookAt((a + b) / 2, b, D.BUILD_AT.UpVector)
		box(m, "AtapKabin", V3(width, 0.12, (b - a).Magnitude + 0.04), cf, D.DINDING, M.SmoothPlastic)
	end
	local front = points[#points]
	cylinder(m, "ListAtapKabin", width + 0.1, 0.16, CFrame.new(front) * D.BUILD_AT.Rotation, D.ALU, M.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		tube(m, "PenyanggaAtap", P(sx * 1.4, 5.6, ZF + D.MASUK + 0.02), P(sx * 1.4, 7.74, -3.85), 0.12, D.ALU, M.Metal)
	end
end

-- Panel angkat kiri. Engselnya di ujung atas muka luar panel.
local SUDUT_BUKA = math.rad(100)
local PISTON_Z = { ZF + 0.5, ZB - 0.5 }
local PISTON_TURUN = 2.2 -- jarak dudukan piston di panel dari engsel

local function panelSamping(viar, boxModel, gerak)
	local group = model(viar, "PanelSamping")
	local bottom = D.COUNTER_TOP
	local h = WALL_TOP - bottom
	local x = -WALL_X
	local panel = box(group, "PanelLuar", V3(D.PANEL, h, INNER_Z2 - INNER_Z1), L(x, bottom + h / 2, Z_MID), D.DINDING, M.SmoothPlastic)
	-- Tulisan di muka dalem diputer 180°: kebacanya pas panel kebuka (dari bawah kanopi).
	local teksDalam = Bantu.surfaceText(panel, Enum.NormalId.Right, "Tahu Goreng  •  Rp 500", RGB(150, 40, 25), nil, 30)
	teksDalam:FindFirstChildOfClass("TextLabel").Rotation = 180

	-- Muka luar: list atas-bawah, strip nama, gagang.
	local outX = -(HALF - D.MASUK / 2)
	for _, y in ipairs({ bottom + 0.06, WALL_TOP - 0.06 }) do
		box(group, "ListPanel", V3(D.MASUK, 0.12, INNER_Z2 - INNER_Z1), L(outX, y, Z_MID), D.ALU, M.Metal)
	end
	local strip = box(group, "StripNama", V3(D.MASUK, 1.2, INNER_Z2 - INNER_Z1), L(outX, bottom + h * 0.55, Z_MID), D.MERAH, M.SmoothPlastic)
	Bantu.surfaceText(strip, Enum.NormalId.Left, "TAHU JURAGAN", W.PUTIH, D.MERAH)
	box(group, "GagangPanel", V3(0.08, 0.12, 1.2), L(-(HALF - D.MASUK) - 0.04, bottom + 0.35, Z_MID), W.KROM, M.Metal)

	-- Muka dalem: lampu strip (jadi lampu kanopi pas kebuka).
	local inX = x + D.PANEL / 2 + 0.025
	box(group, "LampuKanopi", V3(0.05, 0.1, INNER_Z2 - INNER_Z1 - 1), L(inX, bottom + 0.5, Z_MID), RGB(255, 245, 220), M.Neon)

	-- Engsel (silinder sepanjang Z di garis putar).
	local hingeX = -(HALF - D.MASUK)
	for _, z in ipairs({ INNER_Z1 + 0.6, Z_MID, INNER_Z2 - 0.6 }) do
		cylinder(group, "Engsel", 0.5, 0.14, L(hingeX, WALL_TOP, z) * ALONG_Z, W.KROM, M.Metal)
	end

	table.insert(gerak, { group = group, root = panel, nama = "EngselPanel", sendi = L(hingeX, WALL_TOP, Z_MID) })

	-- Piston: tabung (bawah, nempel rangka) + batang (atas, nempel panel).
	local pistonModel = model(viar, "Piston")
	local pangkal = {}
	for i, z in ipairs(PISTON_Z) do
		local base = P(-(HALF - 0.28), D.COUNTER_TOP + 0.3, z)
		local mount = P(x + D.PANEL / 2, WALL_TOP - PISTON_TURUN, z)
		table.insert(pangkal, base)
		local ujung = Instance.new("Attachment")
		ujung.Name = "UjungPiston" .. i
		ujung.Position = panel.CFrame:PointToObjectSpace(mount)
		ujung.Parent = panel
		ball(group, "DudukanPiston", 0.16, CFrame.new(mount) * D.BUILD_AT.Rotation, W.RANGKA, M.Metal)
		ball(boxModel, "DudukanPiston", 0.18, CFrame.new(base) * D.BUILD_AT.Rotation, W.RANGKA, M.Metal)

		-- Posisi awal = ketutup (tegak); client yang ngatur tiap frame.
		local dir = (mount - base).Unit
		for _, bagian in ipairs({ { "Tabung", 2.1, 0.16, W.RANGKA }, { "Batang", 2.9, 0.08, W.KROM } }) do
			local name, length, diameter, color = bagian[1], bagian[2], bagian[3], bagian[4]
			local center = name == "Tabung" and base + dir * length / 2 or mount - dir * length / 2
			local part = cylinder(pistonModel, "Piston" .. name, length, diameter, CFrame.lookAt(center, center + dir, D.BUILD_AT.LookVector) * ALONG_Z, color, M.Metal)
			part:SetAttribute("Piston", i)
			part:SetAttribute("Bagian", name)
			table.insert(gerak, { group = part, root = part, nama = "Piston", sendi = part.CFrame })
		end
	end
	return pangkal
end

return function(viar)
	local m = model(viar, "Box")
	rangka(m)
	dinding(m)
	atapBox(m)
	atapKabin(m)
	local gerak = {}
	local pangkal = panelSamping(viar, m, gerak)
	return { gerak = gerak, pangkalPiston = pangkal, sudutBuka = SUDUT_BUKA }
end
