-- Antrean pembeli per lapak + stok etalase. ModuleScript bareng (server doang):
--   PembeliService -> masukin/ngeluarin NPC dari antrean, beli dari stok
--   FryService     -> serahkan(wajan, player, kualitas) tiap tahu diangkat
--
-- Lapak = model "LapakLuar" (dibikin KendaraanService pas buka lapak, dihapus
-- pas tutup). Pivot-nya = tanah di tengah kendaraan, -X = sisi pembeli.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local FryConfig = require(ReplicatedStorage:WaitForChild("FryConfig"))
local PembeliConfig = require(ReplicatedStorage:WaitForChild("PembeliConfig"))

local rng = Random.new()
local Antrean = {}
local data = {} -- [lapak] = { antre = { pembeli... }, stok = { kualitas... }, tutup = bool }

local function get(lapak)
	local q = data[lapak]
	if not q then
		q = { antre = {}, stok = {}, tutup = false }
		data[lapak] = q
		lapak.Destroying:Connect(function()
			q.tutup = true
			for _, pembeli in ipairs(q.antre) do
				pembeli.lapak = nil -- dibaca PembeliService: balik jalan-jalan
			end
			q.antre = {}
			data[lapak] = nil
		end)
	end
	return q
end

local function pemilik(lapak)
	local kendaraan = lapak.Parent
	local userId = kendaraan and kendaraan:GetAttribute("OwnerUserId")
	return userId and Players:GetPlayerByUserId(userId)
end

local function tambahUang(player, jumlah)
	local stats = player and player:FindFirstChild("leaderstats")
	local uang = stats and stats:FindFirstChild("Uang")
	if uang then
		uang.Value += jumlah
	end
end

-- Lapak yang lagi buka (kendaraan diparkir di titik jualan, LapakBuka = true).
function Antrean.lapakTerbuka()
	local list = {}
	local folder = workspace:FindFirstChild("Kendaraan")
	if not folder then
		return list
	end
	for _, kendaraan in ipairs(folder:GetChildren()) do
		local lapak = kendaraan:GetAttribute("LapakBuka") == true and kendaraan:FindFirstChild("LapakLuar")
		if lapak and lapak.PrimaryPart then
			table.insert(list, lapak)
		end
	end
	return list
end

function Antrean.jumlah(lapak)
	return #get(lapak).antre
end

function Antrean.gabung(lapak, pembeli)
	local q = get(lapak)
	if q.tutup or #q.antre >= PembeliConfig.MAX_ANTRE then
		return nil
	end
	table.insert(q.antre, pembeli)
	pembeli.lapak = lapak
	return #q.antre
end

function Antrean.posisi(lapak, pembeli)
	local q = data[lapak]
	return q and table.find(q.antre, pembeli)
end

function Antrean.keluar(lapak, pembeli)
	local q = data[lapak]
	local i = q and table.find(q.antre, pembeli)
	if i then
		table.remove(q.antre, i) -- yang di belakang otomatis maju (posisinya berubah)
	end
	if pembeli.lapak == lapak then
		pembeli.lapak = nil
	end
end

-- CFrame slot antrean ke-i (dunia). Slot 1 ngadep meja, sisanya ngadep depannya.
function Antrean.slot(lapak, i)
	local c = PembeliConfig
	local pivot = lapak:GetPivot()
	local pos = (pivot * CFrame.new(c.SLOT_X, 0, c.SLOT_Z1 + (i - 1) * c.SLOT_JARAK)).Position
	local lihat = i == 1 and (pivot * CFrame.new(c.SLOT_X + 5, 0, c.SLOT_Z1)).Position
		or (pivot * CFrame.new(c.SLOT_X, 0, c.SLOT_Z1 + (i - 2) * c.SLOT_JARAK)).Position
	return CFrame.lookAt(pos, Vector3.new(lihat.X, pos.Y, lihat.Z))
end

-- Titik ngumpul di belakang kendaraan sebelum jalan ke slot (biar nggak nembus mobil).
function Antrean.titikMasuk(lapak)
	return (lapak:GetPivot() * CFrame.new(PembeliConfig.SLOT_X, 0, PembeliConfig.MASUK_ANTRE_Z)).Position
end

-- Satu porsi dikasih ke pembeli: bayar ke pemilik. Balikin info buat UI.
local function layani(lapak, pembeli, kualitas, penjual)
	local hasil = FryConfig.RESULTS[kualitas]
	local bayar = math.floor(hasil.pay * pembeli.tipe.harga / 100 + 0.5) * 100
	local bonus = 0
	if kualitas == "Perfect" and rng:NextNumber() < PembeliConfig.BONUS_PELUANG then
		bonus = PembeliConfig.BONUS
	end
	tambahUang(penjual, bayar + bonus)
	pembeli.sisaPorsi -= 1
	pembeli.kualitas = pembeli.kualitas or {}
	table.insert(pembeli.kualitas, kualitas)
	return {
		pay = bayar,
		tip = bonus,
		catatan = bonus > 0 and "Kembaliannya ambil aja, Bang!" or nil,
	}
end

-- Dipanggil FryService tiap tahu diangkat. nil = wajan ini bukan punya lapak
-- (FryService bayar cara lama).
function Antrean.serahkan(wajan, penjual, kualitas)
	local lapak = wajan:FindFirstAncestor("LapakLuar")
	if not lapak then
		return nil
	end
	local q = get(lapak)
	local depan = q.antre[1]
	if depan and depan.siap and depan.sisaPorsi > 0 then
		return layani(lapak, depan, kualitas, penjual)
	end
	if #q.stok < PembeliConfig.STOK_MAX then
		table.insert(q.stok, kualitas)
		return { pay = 0, tip = 0, catatan = ("Masuk etalase (%d/%d)"):format(#q.stok, PembeliConfig.STOK_MAX) }
	end
	-- Etalase penuh: dijual murah ke orang lewat.
	local murah = math.floor(FryConfig.RESULTS[kualitas].pay / 2)
	tambahUang(penjual, murah)
	return { pay = murah, tip = 0, catatan = "Etalase penuh, dijual murah" }
end

-- Pembeli terdepan ambil dari etalase kalau ada stok. true = kebeli 1.
function Antrean.beliDariStok(lapak, pembeli)
	local q = data[lapak]
	if not q or q.antre[1] ~= pembeli or #q.stok == 0 or pembeli.sisaPorsi <= 0 then
		return false
	end
	local kualitas = table.remove(q.stok, 1)
	local penjual = pemilik(lapak)
	local info = layani(lapak, pembeli, kualitas, penjual)
	if penjual then
		info.quality = kualitas
		info.label = "Laku!"
		info.total = info.pay + info.tip
		info.catatan = info.catatan or "Dari etalase"
		Remotes.Penjualan:FireClient(penjual, info)
	end
	return true
end

return Antrean
