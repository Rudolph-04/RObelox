--[[
	Bagian motor (depan): rangka, mesin, knalpot, tangki bensin, jok
	(VehicleSeat "Kemudi"), pijakan kaki, sama grup "Setir" yang ikut belok
	(garpu, stang, lampu, spion, spidometer, spakbor depan).

	Stang sengaja ditarik ke belakang-atas biar tangan pengendara nyampe:
	KendaraanController masang IK dari tangan avatar ke attachment
	"PeganganKiri"/"PeganganKanan" di handel, siku diarahin ke attachment
	"SikuKiri"/"SikuKanan" di jok.

	Return: info setir buat Rig ({ group, kepala, sumbu }).
]]

local D = require(script.Parent.Dasar)
local Bantu = D.Bantu

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local W = Bantu.WARNA
local UPRIGHT, ALONG_Z = Bantu.UPRIGHT, Bantu.ALONG_Z
local L, P = D.L, D.P
local box, cylinder, ball, model, tube = Bantu.box, Bantu.cylinder, Bantu.ball, Bantu.model, Bantu.tube

local KARET = RGB(20, 20, 20)

-- Pipa beberapa ruas, sambungannya ditutup bola biar nggak keliatan patah.
local function pipe(parent, name, points, diameter, color, material)
	for i = 1, #points - 1 do
		tube(parent, name, points[i], points[i + 1], diameter, color, material)
		if i > 1 then
			ball(parent, name .. "Sambungan", diameter, CFrame.new(points[i]) * D.BUILD_AT.Rotation, color, material)
		end
	end
end

local function rangkaDanMesin(motor)
	-- Rangka: pipa atas (di bawah tangki) + pipa bawah (nyangga mesin).
	pipe(motor, "Rangka", { P(0, 3.45, -4.85), P(0, 2.8, -3.4), P(0, 2.45, -1.55) }, 0.28, W.RANGKA, M.Metal)
	pipe(motor, "Rangka", { P(0, 3.15, -4.95), P(0, 1.35, -4.1), P(0, 1.0, -2.4), P(0, 1.85, -1.55) }, 0.28, W.RANGKA, M.Metal)

	-- Mesin: bak mesin + tutup bulet di samping, silinder miring ke depan.
	box(motor, "BakMesin", V3(1.1, 0.85, 1.4), L(0, 1.5, -2.95), W.BESI, M.Metal)
	cylinder(motor, "TutupMesin", 1.24, 0.75, L(0, 1.45, -2.75), RGB(150, 152, 158), M.Metal)
	local blok = L(0, 2.2, -3.6) * CFrame.Angles(math.rad(-25), 0, 0)
	box(motor, "BlokSilinder", V3(0.75, 0.9, 0.75), blok, W.BESI, M.Metal)
	for i = 0, 3 do
		box(motor, "SiripMesin", V3(0.9, 0.06, 1.0), blok * CFrame.new(0, -0.3 + i * 0.2, 0), RGB(95, 97, 103), M.Metal)
	end
	box(motor, "KepalaSilinder", V3(0.85, 0.28, 0.85), blok * CFrame.new(0, 0.59, 0), RGB(110, 112, 118), M.Metal)

	-- Knalpot: dari kepala silinder turun, terus ke belakang di sisi kanan.
	pipe(motor, "PipaKnalpot", { P(0.15, 2.55, -4.05), P(0.3, 1.5, -4.45), P(0.75, 1.2, -3.7), P(0.85, 1.25, -3.15) }, 0.2, W.KROM, M.Metal)
	cylinder(motor, "Knalpot", 2.6, 0.44, L(0.85, 1.25, -1.9) * ALONG_Z, W.KROM, M.Metal)
	cylinder(motor, "UjungKnalpot", 0.3, 0.28, L(0.85, 1.25, -0.5) * ALONG_Z, W.RANGKA, M.Metal)
	box(motor, "PelindungKnalpot", V3(0.06, 0.3, 1.3), L(1.1, 1.32, -1.8), W.RANGKA, M.Metal)

	-- Rantai (kiri) dari mesin ke gardan di as belakang.
	local zRantai1, zRantai2 = -2.75, D.AS_BELAKANG + 0.05
	box(motor, "TutupRantai", V3(0.16, 0.5, zRantai2 - zRantai1), L(-0.62, 1.2, (zRantai1 + zRantai2) / 2), W.RANGKA, M.Metal)
end

local function tangki(motor)
	-- Tangki bensin di antara stang & jok, moncongnya agak naik.
	local tilt = CFrame.Angles(math.rad(9), 0, 0)
	Bantu.ellipsoid(motor, "TangkiBensin", V3(1.15, 0.8, 1.75), L(0, 3.42, -4.3) * tilt, D.BODY, M.SmoothPlastic)
	Bantu.ellipsoid(motor, "StripTangki", V3(1.19, 0.3, 1.5), L(0, 3.33, -4.3) * tilt, W.PUTIH, M.SmoothPlastic)
	cylinder(motor, "TutupTangki", 0.08, 0.32, L(0, 3.83, -4.35) * UPRIGHT, W.KROM, M.Metal)
end

local function jok(viar, motor)
	-- Bodi di bawah jok + tutup samping.
	box(motor, "BodiJok", V3(1.0, 0.45, 1.5), L(0, 2.425, -2.55), D.BODY, M.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		box(motor, "TutupSamping", V3(0.08, 0.6, 1.2), L(sx * 0.54, 2.35, -2.55), D.BODY_DARK, M.SmoothPlastic)
	end

	-- Pijakan kaki: batang nembus depan mesin, karet di ujungnya.
	cylinder(motor, "BatangPijakan", 1.7, 0.14, L(0, 2.15, -3.95), W.RANGKA, M.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		cylinder(motor, "Pijakan", 0.4, 0.2, L(sx * 0.85, 2.17, -3.95), KARET, M.Rubber)
	end

	local kemudi = Instance.new("VehicleSeat")
	kemudi.Name = "Kemudi"
	kemudi.Anchored = true
	kemudi.Size = D.JOK_SIZE
	kemudi.CFrame = L(D.JOK.X, D.JOK.Y, D.JOK.Z)
	kemudi.Color = RGB(25, 25, 25)
	kemudi.Material = M.Leather
	kemudi.MaxSpeed = 0 -- jalannya diatur KendaraanController, bukan VehicleSeat
	kemudi.Torque = 0
	kemudi.TurnSpeed = 0
	kemudi.HeadsUpDisplay = false
	kemudi.TopSurface = Enum.SurfaceType.Smooth
	kemudi.Parent = viar
	D.prompt(kemudi, "NaikPrompt", "Naik Motor", "Motor", Enum.KeyCode.F, Enum.KeyCode.ButtonY, 6)

	-- Arah siku pas megang stang (ke samping-bawah, biar nggak nekuk ke atas).
	for name, sx in pairs({ SikuKiri = -1, SikuKanan = 1 }) do
		local siku = Instance.new("Attachment")
		siku.Name = name
		siku.Position = kemudi.CFrame:PointToObjectSpace(P(sx * 1.9, 3.5, -3.1))
		siku.Parent = kemudi
	end
	return kemudi
end

local function setir(viar)
	-- Sumbu setir miring (rake) dari as roda depan ke atas-belakang.
	local base = V3(0, D.WHEEL_R, D.AS_DEPAN)
	local rake = V3(0, 2.9, 1.1).Unit
	local rakeW = D.BUILD_AT:VectorToWorldSpace(rake)
	local right = D.BUILD_AT.RightVector
	local function at(t) -- titik dunia di sumbu setir
		return (D.BUILD_AT * CFrame.new(base + rake * t)).Position
	end
	local function axis(t) -- CFrame di sumbu setir, sumbu Y-nya = arah rake
		return CFrame.fromMatrix(at(t), right, rakeW)
	end
	local rot = D.BUILD_AT.Rotation

	local group = model(viar, "Setir")
	local kepala = cylinder(group, "Kepala", 1, 0.45, axis(2.6) * UPRIGHT, W.RANGKA, M.Metal)

	-- Garpu: pipa dalem krom + tabung shock di atasnya, dijepit 2 segitiga.
	for _, sx in ipairs({ -1, 1 }) do
		local side = right * sx * 0.42
		tube(group, "Garpu", at(0) + side, at(2.05) + side, 0.17, W.KROM, M.Metal)
		tube(group, "Shock", at(1.35) + side, at(3.12) + side, 0.3, W.RANGKA, M.Metal)
		-- Per shock (cincin-cincin di pipa garpu) biar suspensinya keliatan.
		for t = 0.75, 1.25, 0.25 do
			tube(group, "PerShock", at(t) + side - rakeW * 0.03, at(t) + side + rakeW * 0.03, 0.3, W.KROM, M.Metal)
		end
	end
	box(group, "SegitigaBawah", V3(1.2, 0.2, 0.5), axis(2.2), W.RANGKA, M.Metal)
	box(group, "SegitigaAtas", V3(1.2, 0.16, 0.5), axis(2.95), RGB(60, 60, 64), M.Metal)

	-- Stang: tiang pendek, batang tengah, terus nekuk ke belakang-atas ke handel.
	local clampTop = at(3.03)
	local barY = clampTop.Y - D.BUILD_AT.Y + 0.24
	local barZ = (D.BUILD_AT:PointToObjectSpace(clampTop)).Z
	for _, sx in ipairs({ -1, 1 }) do
		local x = right * sx * 0.25
		tube(group, "TiangStang", clampTop + x, P(sx * 0.25, barY, barZ), 0.12, W.KROM, M.Metal)
	end
	local GRIP = V3(1.2, barY + 0.23, -4.35) -- titik pegangan (kanan; kiri = X dibalik)
	tube(group, "Stang", P(-0.6, barY, barZ), P(0.6, barY, barZ), 0.16, W.KROM, M.Metal)
	for name, sx in pairs({ PeganganKiri = -1, PeganganKanan = 1 }) do
		local bend = P(sx * 0.6, barY, barZ)
		local inner = P(sx * 0.92, GRIP.Y, GRIP.Z)
		ball(group, "SambunganStang", 0.17, CFrame.new(bend) * rot, W.KROM, M.Metal)
		tube(group, "Stang", bend, inner, 0.16, W.KROM, M.Metal)
		ball(group, "SambunganStang", 0.17, CFrame.new(inner) * rot, W.KROM, M.Metal)
		tube(group, "Stang", inner, P(sx * 1.28, GRIP.Y, GRIP.Z), 0.14, W.KROM, M.Metal)
		local handel = cylinder(group, "Handel", 0.42, 0.26, L(sx * GRIP.X, GRIP.Y, GRIP.Z), KARET, M.Rubber)
		local pegangan = Instance.new("Attachment")
		pegangan.Name = name
		pegangan.Parent = handel
		cylinder(group, "UjungStang", 0.08, 0.2, L(sx * (GRIP.X + 0.25), GRIP.Y, GRIP.Z), W.KROM, M.Metal)
		-- Tuas rem/kopling di depan handel.
		box(group, "Tuas", V3(0.6, 0.05, 0.08), L(sx * 1.12, GRIP.Y, GRIP.Z - 0.22), W.KROM, M.Metal)
		-- Spion.
		tube(group, "TiangSpion", P(sx * 0.72, GRIP.Y - 0.12, GRIP.Z - 0.35), P(sx * 0.86, GRIP.Y + 0.65, GRIP.Z - 0.5), 0.06, W.RANGKA, M.Metal)
		local mirror = L(sx * 0.9, GRIP.Y + 0.77, GRIP.Z - 0.53)
		cylinder(group, "RumahSpion", 0.1, 0.45, mirror * ALONG_Z, W.RANGKA, M.Metal)
		cylinder(group, "KacaSpion", 0.05, 0.36, mirror * CFrame.new(0, 0, 0.075) * ALONG_Z, W.KROM, M.Metal, {
			Reflectance = 0.5,
		})
	end

	-- Spidometer ngadep pengendara.
	local gaugePos = P(0, barY + 0.3, barZ - 0.1)
	local facing = D.BUILD_AT:VectorToWorldSpace(V3(0, 0.55, 0.835).Unit)
	local gauge = CFrame.lookAt(gaugePos, gaugePos + facing) * ALONG_Z -- sumbu X silinder = arah hadap
	cylinder(group, "Spidometer", 0.18, 0.5, gauge, W.RANGKA, M.SmoothPlastic)
	cylinder(group, "MukaSpidometer", 0.04, 0.38, gauge * CFrame.new(0.12, 0, 0), W.PUTIH, M.SmoothPlastic)
	box(group, "JarumSpidometer", V3(0.04, 0.03, 0.16), gauge * CFrame.new(0.17, 0.04, 0.02) * CFrame.Angles(math.rad(40), 0, 0), RGB(220, 30, 30), M.Neon)

	-- Lampu depan + sein + klakson.
	local lampPos = at(2.65) + D.BUILD_AT.LookVector * 0.55
	local lamp = CFrame.new(lampPos) * rot
	cylinder(group, "RumahLampu", 0.55, 0.8, lamp * ALONG_Z, W.KROM, M.Metal)
	local lensa = cylinder(group, "LampuDepan", 0.06, 0.64, lamp * CFrame.new(0, 0, -0.305) * ALONG_Z, RGB(255, 245, 200), M.Neon)
	local sorot = Instance.new("SpotLight")
	sorot.Face = Enum.NormalId.Right -- silinder diputer 90° di Y: sumbu X lokal (Right) = ngadep depan
	sorot.Brightness = 2
	sorot.Range = 28
	sorot.Angle = 55
	sorot.Color = RGB(255, 240, 210)
	sorot.Parent = lensa
	for _, sx in ipairs({ -1, 1 }) do
		tube(group, "BraketLampu", at(2.45) + right * sx * 0.3, lampPos + right * sx * 0.3 - D.BUILD_AT.UpVector * 0.1, 0.08, W.RANGKA, M.Metal)
		local sein = lamp * CFrame.new(sx * 0.68, 0.05, 0.05)
		tube(group, "TiangSein", lampPos + right * sx * 0.35, sein.Position, 0.06, W.RANGKA, M.Metal)
		box(group, "SeinDepan", V3(0.22, 0.16, 0.2), sein, RGB(255, 150, 30), M.Neon)
	end
	cylinder(group, "Klakson", 0.12, 0.35, lamp * CFrame.new(0, -0.62, 0.15) * ALONG_Z, KARET, M.SmoothPlastic)

	-- Spakbor depan (kulit silinder dipotong bawahnya) + plat nomor depan.
	local wheel = L(0, D.WHEEL_R, D.AS_DEPAN)
	Bantu.carve(group, "SpakborDepan", cylinder(nil, "Luar", 0.7, D.WHEEL_R * 2 + 0.35, wheel, D.BODY), {
		cylinder(nil, "Dalam", 1, D.WHEEL_R * 2 + 0.15, wheel, D.BODY),
		box(nil, "Potong", V3(2, 2, 4), wheel * CFrame.new(0, -0.85, 0), D.BODY),
	}, D.BODY, M.SmoothPlastic)
	local plat = box(group, "PlatDepan", V3(0.9, 0.3, 0.05), wheel * CFrame.new(0, 0.55, -1.085) * CFrame.Angles(math.rad(25), 0, 0), RGB(15, 15, 15))
	Bantu.surfaceText(plat, Enum.NormalId.Front, "B 500 TH", W.PUTIH, RGB(15, 15, 15), 60)

	return { group = group, kepala = kepala, sumbu = axis(2.6) }
end

return function(viar)
	local motor = model(viar, "Motor")
	rangkaDanMesin(motor)
	tangki(motor)
	jok(viar, motor)
	return setir(viar)
end
