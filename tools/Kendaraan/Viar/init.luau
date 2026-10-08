--[[
	Gerobak motor roda tiga + box jualan "TAHU JURAGAN". Hasilnya 2 template
	(diganti kalau udah ada) di ServerStorage.Kendaraan:
	  Viar      -> kendaraannya, di-clone KendaraanService tiap player pencet
	               "Keluarin" di menu Kendaraan
	  ViarLapak -> meja goreng + bangku di luar gerobak, di-clone pas buka
	               lapak & dihapus pas tutup (nggak di-weld ke kendaraan)
	("Viar" cuma nama internal/id; di dalem game nggak ada tulisan merek.)

	Jalanin (Command Bar, mode Edit), terus Save place:
	  require(game.ServerStorage.Tools.Jalankan)("Kendaraan/Viar")

	Dipecah per bagian biar gampang diedit:
	  Dasar  -> ukuran bareng (box, as roda, counter, jok) + helper
	  Motor  -> rangka, mesin, tangki bensin, jok, setir (+ titik pegangan tangan)
	  Bak    -> lantai, rangka bawah, as belakang, sepatbor, lampu, plat
	  Box    -> rangka aluminium, dinding, atap, papan nama, atap kabin,
	            panel samping angkat + piston
	  Lapak  -> isi box: counter, etalase, tirisan, stok
	  LapakLuar -> template ViarLapak: meja goreng, kompor + wajan, gas, bangku
	  Pernak -> hiasan lapak luar (ember tahu, peti, kaleng uang, bohlam, dll)

	Nama yang dipake script (jangan diganti):
	  Chassis (PrimaryPart), Kemudi (VehicleSeat) + NaikPrompt,
	  KursiGoreng (Seat) + DudukPrompt & Wajan (di ViarLapak, lihat Wajan.luau),
	  PeganganKiri/PeganganKanan (attachment di handel), SikuKiri/SikuKanan
	  (attachment di Kemudi), Motor6D EngselPanel & Piston (lihat Box.luau),
	  PangkalPiston<i> (attachment di Chassis), atribut model "Kendaraan" = id
	  di KendaraanConfig, "SudutBuka" / "SudutPintu" = sudut panel / pintu belakang
	  kebuka (radian), Motor6D EngselPintu, PenghalangPintu (collider lubang
	  pintu), RuangBox (penanda ruang dalem box), KursiJaga (Seat) + JagaPrompt.

	Cek permukaan numpuk (bikin kedip) abis ngubah apa-apa:
	  print(require(game.ServerStorage.Tools.CekTumpuk)(game.ServerStorage.Kendaraan.Viar))
	  print(require(game.ServerStorage.Tools.CekTumpuk)(game.ServerStorage.Kendaraan.ViarLapak))
]]

local ServerStorage = game:GetService("ServerStorage")

local D = require(script.Dasar)
local Motor = require(script.Motor)
local Bak = require(script.Bak)
local Box = require(script.Box)
local Lapak = require(script.Lapak)
local LapakLuar = require(script.LapakLuar)
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
	for _, name in ipairs({ "Viar", "ViarLapak" }) do
		local old = folder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local viar = Instance.new("Model")
	viar.Name = "Viar"
	viar:SetAttribute("Kendaraan", "Viar")
	viar.Parent = workspace -- sementara (CSG butuh DataModel)

	-- ── COLLIDER (diatur Rig: nggak keliatan, punya massa) ──────────
	-- Atas Chassis = lantai box, jadi orang bisa berdiri di dalem box.
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
		Bantu.ball(viar, name, D.WHEEL_R * 2, L(pos.X, pos.Y, pos.Z), W.RANGKA):SetAttribute("Tabrakan", "Roda") -- tanpa gesekan (lihat Rig)
	end

	-- Dinding box padat (nggak bisa ditembus); masuknya cuma lewat pintu
	-- belakang. "PenghalangPintu" nutup lubang pintu, dimatiin server pas lapak
	-- buka (pintu kebuka) & dinyalain lagi pas tutup.
	local T = 0.16
	local half = D.BOX_W / 2
	local wallH = D.BOX_TOP - D.BED_TOP
	local wallY = D.BED_TOP + wallH / 2
	local boxLen = D.BOX_BELAKANG - D.BOX_DEPAN
	local backZ = D.BOX_BELAKANG - T / 2
	local doorHalf = D.PINTU_W / 2
	local doorH = D.PINTU_TOP - D.BED_TOP
	local colliders = {
		{ "TabrakDindingKiri", V3(T, wallH, boxLen), L(-(half - T / 2), wallY, zMid) },
		{ "TabrakDindingKanan", V3(T, wallH, boxLen), L(half - T / 2, wallY, zMid) },
		{ "TabrakDindingDepan", V3(D.BOX_W - 2 * T, wallH, T), L(0, wallY, D.BOX_DEPAN + T / 2) },
		{ "TabrakDindingBelakang", V3(half - T - doorHalf, wallH, T), L(-(doorHalf + (half - T - doorHalf) / 2), wallY, backZ) },
		{ "TabrakDindingBelakang", V3(half - T - doorHalf, wallH, T), L(doorHalf + (half - T - doorHalf) / 2, wallY, backZ) },
		{ "TabrakAtasPintu", V3(D.PINTU_W, D.BOX_TOP - D.PINTU_TOP, T), L(0, (D.BOX_TOP + D.PINTU_TOP) / 2, backZ) },
		{ "PenghalangPintu", V3(D.PINTU_W, doorH, T), L(0, D.BED_TOP + doorH / 2, backZ) },
	}
	for _, c in ipairs(colliders) do
		Bantu.box(viar, c[1], c[2], c[3], W.RANGKA):SetAttribute("Tabrakan", true)
	end
	-- Ruang dalem box (nggak nabrak, cuma penanda): KendaraanService ngecek
	-- siapa yang masih di dalem pas lapak mau ditutup.
	Bantu.box(viar, "RuangBox", V3(D.BOX_W - 2 * T, wallH, boxLen - 2 * T), L(0, wallY, zMid), W.RANGKA, nil, {
		Transparency = 1,
		CanQuery = false,
	})

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
	viar:SetAttribute("SudutPintu", box.sudutPintu)

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

	-- ── LAPAK LUAR (template terpisah, nggak ikut Rig) ──────────────
	local lapakLuar = LapakLuar()
	lapakLuar.Name = "ViarLapak"
	lapakLuar.Parent = folder

	local function count(m)
		local n = 0
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end
	return ("Template Viar ok (%d part) + ViarLapak (%d part)"):format(count(viar), count(lapakLuar))
end
