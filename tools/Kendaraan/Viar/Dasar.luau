--[[
	Ukuran & helper bareng buat semua bagian gerobak motor (Motor, Bak, Box,
	Lapak).

	Arah depan = -Z, kiri = -X (sisi trotoar). Semua angka relatif ke tanah
	di "tengah" kendaraan (BUILD_AT), yang nanti jadi pivot. Dibangun jauh di
	atas map, terus template-nya dipindah ke ServerStorage.

	Angka badan avatar R15 yang dipake buat ngepasin (diukur pas duduk,
	relatif ke permukaan atas jok): kepala +3.6, bahu +2.3, telapak kaki
	-0.6 & 1.2 stud ke depan, panjang lengan ~2.2.

	Aturan anti kedip (z-fighting): dua permukaan yang sejajar & ngadep arah
	sama nggak boleh numpuk dengan jarak < 0.05 stud. Hiasan ditempel DI ATAS
	permukaan (nyentuh) atau nongol >= 0.05. Cek pake tools/CekTumpuk.
]]

local Bantu = require(script.Parent.Parent.Parent.Bantu)

local V3 = Vector3.new
local RGB = Color3.fromRGB

local D = {}

D.BUILD_AT = CFrame.new(0, 400, 0)

D.BODY = RGB(30, 75, 160) -- biru motor
D.BODY_DARK = RGB(22, 52, 115)
D.ALU = RGB(190, 195, 200) -- rangka aluminium box
D.DINDING = RGB(250, 246, 235) -- panel box
D.MERAH = RGB(200, 40, 35)
D.KUNING = RGB(250, 205, 60)

D.WHEEL_R = 1
D.AS_DEPAN = -6 -- Z as roda depan
D.AS_BELAKANG = 3.1 -- Z as roda belakang
D.TRACK = 2.6 -- X roda belakang (kiri/kanan)

-- Lantai & box. Lebar mentok 6 karena petak parkir di pasar lebarnya 6.4.
D.BED_TOP = 2.325 -- permukaan lantai box
D.BOX_W = 6
D.BOX_DEPAN = -1.5 -- Z sisi luar box bagian depan
D.BOX_BELAKANG = 6.5 -- Z sisi luar box bagian belakang
D.BOX_TOP = 8.3 -- atas rangka box (atap box nempel di atasnya)
D.RANGKA = 0.22 -- tebal pipa kotak rangka box
D.PANEL = 0.1 -- tebal panel dinding
D.MASUK = 0.06 -- panel dinding masuk segini dari muka luar rangka

-- Pintu belakang 2 daun (jalan masuk ke box). Tingginya muat avatar R15
-- (~5.2 stud) berdiri.
D.PINTU_W = 2.6
D.PINTU_TOP = D.BED_TOP + 5.2

-- Counter jualan di sisi kiri dalem box (panel angkat ada di atasnya).
D.COUNTER_TOP = D.BED_TOP + 1.55
D.COUNTER_DALAM = -0.54 -- X tepi counter yang ngadep penjual

-- Jok motor (VehicleSeat "Kemudi").
D.JOK = V3(0, 2.85, -2.75)
D.JOK_SIZE = V3(1.4, 0.35, 1.9)

function D.L(x, y, z)
	return D.BUILD_AT * CFrame.new(x, y, z)
end

function D.P(x, y, z)
	return D.L(x, y, z).Position
end

-- ProximityPrompt di attachment kecil di atas part.
function D.prompt(parent, name, actionText, objectText, key, gamepadKey, distance)
	local attachment = Instance.new("Attachment")
	attachment.Name = name .. "Attachment"
	attachment.Position = V3(0, 0.6, 0)
	attachment.Parent = parent
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = actionText
	p.ObjectText = objectText
	p.KeyboardKeyCode = key
	p.GamepadKeyCode = gamepadKey
	p.HoldDuration = 0
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.Parent = attachment
	return p
end

D.Bantu = Bantu
return D
