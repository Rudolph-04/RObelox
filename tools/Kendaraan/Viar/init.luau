--[[
	Gerobak motor roda tiga + box jualan "TAHU JURAGAN". Hasilnya template
	ServerStorage.Kendaraan.Viar (diganti kalau udah ada), yang di-clone
	KendaraanService tiap player pencet "Keluarin" di menu Kendaraan.
	("Viar" cuma nama internal/id; di dalem game nggak ada tulisan merek.)

	Jalanin (Command Bar, mode Edit), terus Save place:
	  require(game.ServerStorage.Tools.Jalankan)("Kendaraan/Viar")

	Dipecah per bagian biar gampang diedit:
	  Dasar  -> ukuran bareng (box, as roda, counter, jok) + helper
	  Motor  -> rangka, mesin, tangki bensin, jok, setir (+ titik pegangan tangan)
	  Bak    -> lantai, rangka bawah, as belakang, sepatbor, lampu, plat
	  Box    -> rangka aluminium, dinding, atap, papan nama, atap kabin,
	            panel samping angkat + piston
	  Lapak  -> isi box: counter + kompor tanam + wajan, etalase, kursi, stok

	Nama yang dipake script (jangan diganti):
	  Chassis (PrimaryPart), Kemudi (VehicleSeat) + NaikPrompt,
	  KursiGoreng (Seat) + DudukPrompt, Wajan (lihat Wajan.luau),
	  PeganganKiri/PeganganKanan (attachment di handel), SikuKiri/SikuKanan
	  (attachment di Kemudi), Motor6D EngselPanel & Piston (lihat Box.luau),
	  PangkalPiston<i> (attachment di Chassis), atribut model "Kendaraan" = id
	  di KendaraanConfig, "SudutBuka" = sudut panel kebuka (radian).

	Cek permukaan numpuk (bikin kedip) abis ngubah apa-apa:
	  print(require(game.ServerStorage.Tools.CekTumpuk)(game.ServerStorage.Kendaraan.Viar))
]]

local ServerStorage = game:GetService("ServerStorage")

local D = require(script.Dasar)
local Motor = require(script.Motor)
local Bak = require(script.Bak)
local Box = require(script.Box)
local Lapak = require(script.Lapak)
local Roda = require(script.Parent.Roda)
local Rig = require(script.Parent.Rig)

local Bantu = D.Bantu
local V3 = Vector3.new
local W = Bantu.WARNA
local L = D.L

return function()
	local folder = ServerStorage:FindFirstChild("Kendaraan")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Kendaraan"
		folder.Parent = ServerStorage
	end
	local old = folder:FindFirstChild("Viar")
	if old then
		old:Destroy()
	end

	local viar = Instance.new("Model")
	viar.Name = "Viar"
	viar:SetAttribute("Kendaraan", "Viar")
	viar.Parent = workspace -- sementara (CSG butuh DataModel)

	-- ── COLLIDER (diatur Rig: nggak keliatan, tanpa gesekan) ────────
	-- Atas Chassis = lantai box, jadi orang bisa berdiri di dalem box.
	-- Box-nya sendiri visual doang, biar fisika nyetir tetep sama.
	local zMid = (D.BOX_DEPAN + D.BOX_BELAKANG) / 2
	local chassisH = D.BED_TOP - 1.4
	local chassis = Bantu.box(viar, "Chassis", V3(D.BOX_W, chassisH, D.BOX_BELAKANG - D.BOX_DEPAN), L(0, 1.4 + chassisH / 2, zMid), W.RANGKA)
	chassis:SetAttribute("Tabrakan", true)
	viar.PrimaryPart = chassis
	Bantu.box(viar, "BadanDepan", V3(1.5, 1.5, 4.2), L(0, 2.3, D.BOX_DEPAN - 2.1), W.RANGKA):SetAttribute("Tabrakan", true)
	-- Bola di posisi roda: bisa naik kanstin yang lebih pendek dari jari-jarinya.
	local wheels = {
		TabrakDepan = V3(0, D.WHEEL_R, D.AS_DEPAN),
		TabrakKiri = V3(-D.TRACK, D.WHEEL_R, D.AS_BELAKANG),
		TabrakKanan = V3(D.TRACK, D.WHEEL_R, D.AS_BELAKANG),
	}
	for name, pos in pairs(wheels) do
		Bantu.ball(viar, name, D.WHEEL_R * 2, L(pos.X, pos.Y, pos.Z), W.RANGKA):SetAttribute("Tabrakan", true)
	end

	-- ── BAGIAN-BAGIAN ───────────────────────────────────────────────
	local rodaDepan = Roda(viar, "RodaDepan", L(0, D.WHEEL_R, D.AS_DEPAN), D.WHEEL_R, 0.6)
	local rodaKiri = Roda(viar, "RodaKiri", L(-D.TRACK, D.WHEEL_R, D.AS_BELAKANG), D.WHEEL_R, 0.7)
	local rodaKanan = Roda(viar, "RodaKanan", L(D.TRACK, D.WHEEL_R, D.AS_BELAKANG), D.WHEEL_R, 0.7)
	local setir = Motor(viar)
	Bak(viar)
	local box = Box(viar)
	Lapak(viar)

	for i, pos in ipairs(box.pangkalPiston) do
		local pangkal = Instance.new("Attachment")
		pangkal.Name = "PangkalPiston" .. i
		pangkal.Position = chassis.CFrame:PointToObjectSpace(pos)
		pangkal.Parent = chassis
	end
	viar:SetAttribute("SudutBuka", box.sudutBuka)

	-- ── PAPAN NAMA PEMILIK (teksnya diisi KendaraanService) ─────────
	local tagAttachment = Instance.new("Attachment")
	tagAttachment.Name = "PemilikAttachment"
	tagAttachment.Position = chassis.CFrame:PointToObjectSpace(D.P(0, D.BOX_TOP + 2.6, zMid))
	tagAttachment.Parent = chassis
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Pemilik"
	billboard.Size = UDim2.fromOffset(200, 34)
	billboard.MaxDistance = 80
	billboard.Parent = tagAttachment
	local nama = Instance.new("TextLabel")
	nama.Name = "Nama"
	nama.Size = UDim2.fromScale(1, 1)
	nama.BackgroundTransparency = 1
	nama.Font = Enum.Font.FredokaOne
	nama.TextScaled = true
	nama.TextColor3 = W.PUTIH
	nama.TextStrokeTransparency = 0.4
	nama.Text = ""
	nama.Parent = billboard

	-- ── JADIIN KENDARAAN ────────────────────────────────────────────
	Rig(viar, {
		origin = D.BUILD_AT,
		setir = setir,
		roda = {
			{ model = rodaDepan, diSetir = true },
			{ model = rodaKiri },
			{ model = rodaKanan },
		},
		gerak = box.gerak,
	})
	viar.Parent = folder

	local parts = 0
	for _, p in ipairs(viar:GetDescendants()) do
		if p:IsA("BasePart") then
			parts += 1
		end
	end
	return ("Template Viar ok (%d part)"):format(parts)
end
