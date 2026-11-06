-- Server prototipe Laskar Kendang (Script di ServerScriptService).
--
-- Jam ketukan: satu buat semua player (atribut "MulaiKetukan" di
-- ReplicatedStorage, pake workspace:GetServerTimeNow()). Ketukan ke-n
-- jatuh di MulaiKetukan + n * KETUKAN.
--
-- Alur perintah:
--   client mukul 4 kendang pas ketukan -> client yang nilai timing-nya
--   (ping bikin server nggak bisa nilai adil) -> kirim (id, ketukan pukulan
--   ke-4, kualitas 0..1) -> server cek masuk akal -> pasukan jalanin perintah
--   di 4 ketukan berikutnya (ketukan+1 .. ketukan+4).
--   Perintah berikutnya nyambung (kombo) kalau pukulan ke-4-nya pas di
--   ketukan+8. Kombo >= KOMBO_SEMANGAT = Semangat (damage & langkah naik).
--
-- Pasukan tiap player: avatar player (panglima, digerakin client-nya sendiri
-- ngikutin atribut "PanglimaX") + prajurit model (digerakin server).
-- Musuh diem di posnya & nyerang yang masuk jangkauan. Benteng ancur = menang.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local C = require(ReplicatedStorage:WaitForChild("LaskarConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("LaskarRemotes"))
local Bentuk = require(script.Parent:WaitForChild("Bentuk"))
local Arena = require(script.Parent:WaitForChild("Arena"))

local V3 = Vector3.new
local K = C.KETUKAN
local TANAH = C.ARENA.tanahY
local rng = Random.new()

-- Posisi barisan paling depan di formasi (relatif panglima di x = 0).
local DEPAN_FORMASI = 0
for _, f in ipairs(C.FORMASI) do
	DEPAN_FORMASI = math.max(DEPAN_FORMASI, f.x)
end

Players.RespawnTime = 5
Arena.bangun()

local MULAI = math.floor(workspace:GetServerTimeNow())
ReplicatedStorage:SetAttribute("MulaiKetukan", MULAI)

local function ketukanSekarang()
	return math.floor((workspace:GetServerTimeNow() - MULAI) / K)
end

local folderPasukan = Instance.new("Folder")
folderPasukan.Name = "Pasukan"
folderPasukan.Parent = workspace
local folderMusuh = Instance.new("Folder")
folderMusuh.Name = "Musuh"
folderMusuh.Parent = workspace

local pasukan = {} -- [player] = data pasukan
local musuh = {} -- list data musuh
local stage = { selesai = false, mulai = os.clock() }
local ketukanDiproses = ketukanSekarang()

-- ── UNIT ───────────────────────────────────────────────────────────
-- Unit prajurit/musuh: { model (= akar), akar, isi (bar), kelas, x, targetX, z,
--   hp, maxHp, hidup, arah (+1 ngadep +X / -1), cfTerakhir }
-- Server cuma ngurus posisi & arah Akar. Badan, loncat, ayunan senjata dll
-- digambar client (LaskarPrajurit) dari atribut Akar & model pasukan.
-- Panglima: { panglima = true, kelas, targetX, character, hum, root }

local function setBar(u)
	u.isi.Size = UDim2.fromScale(math.clamp(u.hp / u.maxHp, 0, 1), 1)
end

local function hidup(u)
	if u.panglima then
		return u.hum ~= nil and u.hum.Health > 0 and u.root ~= nil and u.root.Parent ~= nil
	end
	return u.hidup
end

local function posX(u)
	return u.panglima and u.root.Position.X or u.x
end

-- Titik tengah badan (buat angka damage & panah).
local function posBadan(u)
	if u.panglima then
		return u.root.Position
	end
	return V3(u.x, TANAH + (u.kelas.benteng and 6 or 1.8), u.z)
end

local function semuaUnit(army)
	local list = {}
	for _, u in ipairs(army.prajurit) do
		table.insert(list, u)
	end
	if hidup(army.panglima) then
		table.insert(list, army.panglima)
	end
	return list
end

-- Musuh hidup terdekat di depan x (boleh mepet sampai 1 stud di belakang).
local function musuhDepan(x, jarakMaks)
	local best, bestD
	for _, e in ipairs(musuh) do
		if e.hidup then
			local d = e.x - x
			if d >= -1 and d <= jarakMaks and (not best or d < bestD) then
				best, bestD = e, d
			end
		end
	end
	return best, bestD
end

-- Paling jauh unit di x boleh maju (ketahan musuh terdekat / ujung stage).
local function batasMaju(x)
	local e = musuhDepan(x, math.huge)
	local batas = C.ARENA.akhirX
	if e then
		batas = math.min(batas, e.x - e.kelas.lebar)
	end
	return batas
end

local function hitung(penyerang, korban, pengali)
	local crit = rng:NextNumber() < (penyerang.crit or 0)
	local dmg = penyerang.atk * pengali * (crit and C.CRIT_KALI or 1) - (korban.def or 0)
	return math.max(1, math.floor(dmg + 0.5)), crit
end

-- Gerak halus ke targetX. Cuma ngirim CFrame kalau berubah (diem = nggak ada kiriman).
local function gerakUnit(u, dt, kaliLangkah)
	if u.statis then
		return
	end
	local dx = u.targetX - u.x
	local maks = (u.kelas.kecepatan or 0) * dt * kaliLangkah -- musuh nggak punya kecepatan (diem di pos)
	local hadap = u.arah or 1
	if math.abs(dx) > 0.05 then
		u.x += math.clamp(dx, -maks, maks)
		hadap = dx > 0 and 1 or -1
	end
	local pos = V3(u.x, TANAH, u.z)
	local cf = CFrame.lookAt(pos, pos + V3(hadap, 0, 0))
	if cf ~= u.cfTerakhir then
		u.cfTerakhir = cf
		u.akar.CFrame = cf
	end
end

local function tandaSerang(u)
	u.akar:SetAttribute("SerangKe", (u.akar:GetAttribute("SerangKe") or 0) + 1)
end

-- ── MUSUH ──────────────────────────────────────────────────────────
local mulaiStage -- dipanggil menang()

local function menang()
	if stage.selesai then
		return
	end
	stage.selesai = true
	local waktu = os.clock() - stage.mulai
	for player, army in pairs(pasukan) do
		Remotes.Umpan:FireClient(player, { jenis = "menang", waktu = waktu, komboMaks = army.komboMaks })
	end
	task.delay(C.JEDA_ULANG_STAGE, mulaiStage)
end

local function lukaiMusuh(e, dmg, crit)
	if not e.hidup then
		return
	end
	e.hp -= dmg
	setBar(e)
	Remotes.Efek:FireAllClients("angka", posBadan(e), dmg, crit, false)
	if e.hp <= 0 then
		e.hidup = false
		Remotes.Efek:FireAllClients("mati", posBadan(e))
		e.model:Destroy()
		if e.kelas.benteng then
			menang()
		end
	end
end

local function bangunMusuh()
	for _, e in ipairs(musuh) do
		e.hidup = false
		if e.model.Parent then
			e.model:Destroy()
		end
	end
	musuh = {}
	for _, g in ipairs(C.GELOMBANG) do
		for i, id in ipairs(g.musuh) do
			local kelas = C.MUSUH[id]
			local akar, isi = Bentuk.akar(id, Color3.fromRGB(110, 34, 36), true)
			local e = {
				model = akar,
				akar = akar,
				isi = isi,
				kelas = kelas,
				x = g.x + (i - 1) * 2.6 + (kelas.panah and 3 or 0), -- pemanah di belakang
				z = (i % 2 == 0) and -1.2 or 1.2,
				hp = kelas.hp,
				maxHp = kelas.hp,
				hidup = true,
				arah = -1,
				siap = os.clock() + rng:NextNumber(0.5, 2),
			}
			e.targetX = e.x
			gerakUnit(e, 0, 1)
			akar.Parent = folderMusuh
			table.insert(musuh, e)
		end
	end
	local model, akar, isi = Bentuk.benteng()
	model:PivotTo(CFrame.new(C.BENTENG_X, TANAH, 0))
	model.Parent = folderMusuh
	table.insert(musuh, {
		model = model,
		akar = akar,
		isi = isi,
		kelas = C.MUSUH.Benteng,
		x = C.BENTENG_X,
		targetX = C.BENTENG_X,
		z = 0,
		hp = C.MUSUH.Benteng.hp,
		maxHp = C.MUSUH.Benteng.hp,
		hidup = true,
		statis = true,
		siap = math.huge,
	})
end

-- ── PASUKAN ────────────────────────────────────────────────────────
local resetPasukan -- dipanggil pas semua prajurit gugur

local function kirimKombo(army)
	Remotes.Umpan:FireClient(army.player, { jenis = "kombo", kombo = army.kombo, semangat = army.semangat })
end

local function putusKombo(army)
	army.terakhir = nil
	if army.kombo > 0 or army.semangat then
		army.kombo = 0
		army.semangat = false
		army.model:SetAttribute("Semangat", false)
		kirimKombo(army)
	end
end

local function lukaiPasukan(army, u, dmg, crit)
	if not hidup(u) then
		return
	end
	if ketukanDiproses <= army.pengaliSampai then
		dmg = math.max(1, math.floor(dmg * army.pengaliTerima + 0.5))
	end
	Remotes.Efek:FireAllClients("angka", posBadan(u), dmg, crit, true)
	if u.panglima then
		u.hum:TakeDamage(dmg)
		return
	end
	u.hp -= dmg
	setBar(u)
	if u.hp <= 0 then
		u.hidup = false
		Remotes.Efek:FireAllClients("mati", posBadan(u))
		u.model:Destroy()
		local i = table.find(army.prajurit, u)
		if i then
			table.remove(army.prajurit, i)
		end
		if #army.prajurit == 0 and not army.lagiReset then
			army.lagiReset = true
			task.delay(3, function()
				if pasukan[army.player] == army then
					resetPasukan(army, "Pasukan tumbang! Mulai lagi dari awal.")
				end
			end)
		end
	end
end

local function setPanglimaX(army, x)
	army.panglima.targetX = x
	army.model:SetAttribute("PanglimaX", x)
end

local function taruhPanglima(army)
	local p = army.panglima
	if p.root and p.root.Parent then
		local pos = V3(p.targetX, TANAH + 3, army.z)
		p.root.Parent:PivotTo(CFrame.lookAt(pos, pos + Vector3.xAxis))
	end
end

local function bikinPrajurit(army, mulaiX)
	for _, u in ipairs(army.prajurit) do
		u.hidup = false
		if u.model.Parent then
			u.model:Destroy()
		end
	end
	army.prajurit = {}
	for i, f in ipairs(C.FORMASI) do
		local kelas = C.KELAS[f.kelas]
		local akar, isi = Bentuk.akar(f.kelas, army.warna, false)
		local x = mulaiX + f.x
		local u = {
			model = akar,
			akar = akar,
			isi = isi,
			kelas = kelas,
			x = x,
			targetX = x,
			z = army.z + ((i % 2 == 0) and -0.9 or 0.9),
			hp = kelas.hp,
			maxHp = kelas.hp,
			hidup = true,
			arah = 1,
			antri = DEPAN_FORMASI - f.x, -- jarak ke barisan paling depan (formasi pas ketahan musuh)
		}
		gerakUnit(u, 0, 1)
		akar.Parent = army.model
		table.insert(army.prajurit, u)
	end
end

resetPasukan = function(army, pesan)
	army.lagiReset = false
	army.aksi = nil
	army.pengaliSampai = -1
	putusKombo(army)
	bikinPrajurit(army, C.ARENA.mulaiX)
	setPanglimaX(army, C.ARENA.mulaiX)
	taruhPanglima(army)
	if pesan then
		Remotes.Umpan:FireClient(army.player, { jenis = "pesan", teks = pesan })
	end
end

local function pasangPanglima(army, character)
	local hum = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root or pasukan[army.player] ~= army then
		return
	end
	hum.MaxHealth = C.KELAS.Panglima.hp
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = C.KELAS.Panglima.kecepatan
	hum.JumpPower = 0
	hum.JumpHeight = 0
	Bentuk.perlengkapanPanglima(character)
	army.panglima.character = character
	army.panglima.hum = hum
	army.panglima.root = root
	task.wait() -- tunggu karakter beres ditaruh di spawn dulu
	taruhPanglima(army)
end

local function slotKosong()
	local dipakai = {}
	for _, army in pairs(pasukan) do
		dipakai[army.slot] = true
	end
	local i = 1
	while dipakai[i] do
		i += 1
	end
	return i
end

-- Jalur tiap player: 0, -3.5, +3.5, -7, +7, ... (makin jauh dari kamera makin belakang)
local function laneZ(slot)
	local n = (slot - 1) % 5 -- maksimal +-7 (jalan lebarnya 20)
	if n == 0 then
		return 0
	end
	return math.ceil(n / 2) * 3.5 * ((n % 2 == 1) and -1 or 1)
end

local function tambahPemain(player)
	-- Kontrol jalan bawaan mati: panglima cuma gerak ngikutin perintah (D juga
	-- tombol kendang, jangan sampe ikut jalan ke kanan). PlayerModule udah nggak
	-- di PlayerScripts lagi, jadi dimatiin lewat sini, bukan GetControls():Disable().
	player.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
	player.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
	local slot = slotKosong()
	local model = Instance.new("Model")
	model.Name = "Pasukan_" .. player.UserId
	-- Dibaca client buat animasi pasukan (jawab perintah, SEMANGAT).
	model:SetAttribute("Semangat", false)
	local z = laneZ(slot)
	model:SetAttribute("LaneZ", z)
	model:SetAttribute("Pemilik", player.UserId)
	model.Parent = folderPasukan

	local army = {
		player = player,
		slot = slot,
		z = z,
		warna = C.WARNA_PLAYER[(slot - 1) % #C.WARNA_PLAYER + 1],
		model = model,
		prajurit = {},
		panglima = { panglima = true, kelas = C.KELAS.Panglima, targetX = C.ARENA.mulaiX, antri = DEPAN_FORMASI },
		kombo = 0,
		komboMaks = 0,
		semangat = false,
		terakhir = nil, -- ketukan pukulan ke-4 perintah terakhir
		aksi = nil,
		pengaliTerima = 1,
		pengaliSampai = -1,
	}
	pasukan[player] = army
	setPanglimaX(army, C.ARENA.mulaiX)
	bikinPrajurit(army, C.ARENA.mulaiX)

	player.CharacterAdded:Connect(function(character)
		pasangPanglima(army, character)
	end)
	if player.Character then
		task.spawn(pasangPanglima, army, player.Character)
	end
end

Players.PlayerAdded:Connect(tambahPemain)
for _, player in ipairs(Players:GetPlayers()) do
	tambahPemain(player)
end
Players.PlayerRemoving:Connect(function(player)
	local army = pasukan[player]
	if army then
		pasukan[player] = nil
		army.model:Destroy()
	end
end)

-- ── PERINTAH ───────────────────────────────────────────────────────
local function serang(army, u, e, pengali)
	local dmg, crit = hitung(u.kelas, e.kelas, pengali)
	if u.panglima then
		Remotes.Efek:FireAllClients("ayun", army.player.UserId)
	else
		tandaSerang(u) -- client: animasi nusuk/bacok/manah
	end
	if u.kelas.panah then
		local dari = posBadan(u) + V3(0, 0.6, 0)
		local ke = posBadan(e)
		local durasi = math.clamp((ke - dari).Magnitude / 45, 0.2, 0.6)
		Remotes.Efek:FireAllClients("panah", dari, ke, durasi)
		task.delay(durasi, lukaiMusuh, e, dmg, crit)
	else
		lukaiMusuh(e, dmg, crit)
	end
end

-- Satu ketukan jawaban pasukan. ke = 1..4.
local function langkahAksi(army, aksi, ke)
	local p = aksi.perintah
	local kaliLangkah = aksi.semangat and C.SEMANGAT.langkah or 1
	local pengali = (aksi.semangat and C.SEMANGAT.damage or 1) * (0.85 + 0.3 * aksi.kualitas)
	local ketukanSerang = aksi.semangat and C.KETUKAN_SERANG_SEMANGAT or C.KETUKAN_SERANG
	for _, u in ipairs(semuaUnit(army)) do
		local x = posX(u)
		local langkah = C.LANGKAH_PER_KETUKAN * kaliLangkah
		if p.id == "Maju" then
			u.targetX = math.min(math.max(u.targetX, x) + langkah, batasMaju(x) - (u.antri or 0))
		elseif p.id == "Mundur" then
			if ke == 1 then
				u.targetX = math.max(C.ARENA.mulaiX - 6, x - p.jarakMundur)
			end
		elseif p.id == "Serang" then
			local e, d = musuhDepan(x, 40)
			if e then
				if d > u.kelas.jangkau then
					u.targetX = math.min(x + langkah, e.x - u.kelas.jangkau * 0.7, batasMaju(x))
				elseif table.find(ketukanSerang, ke) then
					serang(army, u, e, pengali)
				end
			else
				u.targetX = math.min(x + langkah * 0.5, batasMaju(x) - (u.antri or 0))
			end
		end
	end
	setPanglimaX(army, army.panglima.targetX)

	if p.pengaliTerima and ke == 1 then
		army.pengaliTerima = p.pengaliTerima
		army.pengaliSampai = aksi.selesai
	end
end

Remotes.Perintah.OnServerEvent:Connect(function(player, id, ketukan, kualitas)
	local army = pasukan[player]
	if not army or stage.selesai or army.lagiReset then
		return
	end
	if id == "Putus" then
		putusKombo(army)
		return
	end
	local p = typeof(id) == "string" and C.perintah(id)
	if not p or typeof(ketukan) ~= "number" or ketukan ~= ketukan then
		return
	end
	ketukan = math.floor(ketukan)
	local sekarang = ketukanSekarang()
	if ketukan < sekarang - 2 or ketukan > sekarang + 1 then
		return -- kejauhan dari jam server: abaikan
	end
	if army.terakhir and ketukan < army.terakhir + 8 then
		return -- masih fase jawaban perintah sebelumnya (atau spam)
	end
	kualitas = (typeof(kualitas) == "number" and kualitas == kualitas) and math.clamp(kualitas, 0, 1) or 0

	if army.terakhir and ketukan == army.terakhir + 8 then
		army.kombo += 1
	else
		army.kombo = 1
	end
	army.terakhir = ketukan
	army.komboMaks = math.max(army.komboMaks, army.kombo)
	army.semangat = army.kombo >= C.KOMBO_SEMANGAT
	army.aksi = { perintah = p, mulai = ketukan + 1, selesai = ketukan + 4, semangat = army.semangat, kualitas = kualitas }
	army.model:SetAttribute("Semangat", army.semangat)
	army.model:SetAttribute("Perintah", p.id)
	army.model:SetAttribute("JawabMulai", army.aksi.mulai)
	army.model:SetAttribute("JawabSelesai", army.aksi.selesai)
	kirimKombo(army)

	-- Ping gede: ketukan jawaban yang udah lewat langsung dijalanin.
	for n = army.aksi.mulai, math.min(ketukanDiproses, army.aksi.selesai) do
		langkahAksi(army, army.aksi, n - army.aksi.mulai + 1)
	end
end)

-- ── LOOP ───────────────────────────────────────────────────────────
local function prosesKetukan(n)
	for _, army in pairs(pasukan) do
		local aksi = army.aksi
		if aksi and n >= aksi.mulai and n <= aksi.selesai then
			langkahAksi(army, aksi, n - aksi.mulai + 1)
		end
		if aksi and n >= aksi.selesai then
			army.aksi = nil
		end
		-- Nggak ngasih perintah lanjutan tepat waktu: kombo putus.
		if army.terakhir and n >= army.terakhir + 10 then
			putusKombo(army)
		end
	end
end

local function musuhBertindak(sekarang)
	for _, e in ipairs(musuh) do
		if e.hidup and e.kelas.atk > 0 and sekarang >= e.siap then
			-- Target: unit pasukan terdekat di depan musuh (x lebih kecil) dalam jangkauan.
			local target, targetArmy, terbaik
			for _, army in pairs(pasukan) do
				for _, u in ipairs(semuaUnit(army)) do
					local d = e.x - posX(u)
					if d >= -1 and d <= e.kelas.jangkau and (not terbaik or d < terbaik) then
						target, targetArmy, terbaik = u, army, d
					end
				end
			end
			if target then
				local dmg, crit = hitung(e.kelas, target.kelas, 1)
				if e.kelas.panah then
					tandaSerang(e)
					local dari = posBadan(e) + V3(0, 0.6, 0)
					local ke = posBadan(target)
					local durasi = math.clamp((ke - dari).Magnitude / 45, 0.2, 0.6)
					Remotes.Efek:FireAllClients("panah", dari, ke, durasi)
					task.delay(durasi, lukaiPasukan, targetArmy, target, dmg, crit)
				else
					tandaSerang(e)
					lukaiPasukan(targetArmy, target, dmg, crit)
				end
				e.siap = sekarang + e.kelas.jeda * rng:NextNumber(0.85, 1.15)
			else
				e.siap = sekarang + 0.3
			end
		end
	end
end

function mulaiStage()
	stage.selesai = false
	stage.mulai = os.clock()
	bangunMusuh()
	for _, army in pairs(pasukan) do
		army.komboMaks = 0
		resetPasukan(army)
	end
end

mulaiStage()

RunService.Heartbeat:Connect(function(dt)
	local n = ketukanSekarang()
	while ketukanDiproses < n do
		ketukanDiproses += 1
		prosesKetukan(ketukanDiproses)
	end

	local sekarang = os.clock()
	for _, army in pairs(pasukan) do
		local kali = army.semangat and C.SEMANGAT.langkah or 1
		for _, u in ipairs(army.prajurit) do
			gerakUnit(u, dt, kali)
		end
	end
	for _, e in ipairs(musuh) do
		if e.hidup then
			gerakUnit(e, dt, 1)
		end
	end
	if not stage.selesai then
		musuhBertindak(sekarang)
	end
end)
