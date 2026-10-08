-- Mekanik goreng (server-authoritative).
--
-- Alur: player pencet ProximityPrompt di wajan -> server catet waktu mulai ->
-- client nampilin bar -> player klik "Angkat" -> server ngitung sendiri udah
-- berapa lama -> kualitas (Mentah/Oke/Perfect/Gosong) -> kasih uang.
-- Client NGGAK pernah ngirim kualitas atau jumlah uang, cuma "angkat sekarang".
--
-- Wajan dicari lewat tag CollectionService "Wajan" (sekarang nempel di kendaraan,
-- lihat tools/Kendaraan/Wajan.luau), jadi wajan bebas ditambah tanpa ngedit script ini.
--
-- Atribut wajan (dipasang KendaraanService, opsional):
--   OwnerUserId  cuma pemilik kendaraan yang boleh goreng
--   BisaJualan   false = kendaraan lagi nggak diparkir di titik jualan
-- Selama goreng, script ini nyalain atribut "LagiGoreng" di wajan
-- (KendaraanService nggak ngizinin lapak ditutup / kendaraan dinaikin).
--
-- Tahu yang diangkat diserahin ke Antrean: dikasih ke pembeli NPC terdepan,
-- masuk etalase, atau dijual murah kalau etalase penuh. Wajan di luar lapak
-- (nggak ada pembeli) tetep dibayar langsung kayak dulu.
--
-- Animasi masak: selama goreng, karakter dikasih sutil di tangan kanan +
-- atribut "LagiGoreng" & "TitikWajan" (Vector3). Gerakan tangannya dihitung
-- tiap client (MasakAnimasi.client.lua), jadi nggak perlu upload animasi.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local FryConfig = require(ReplicatedStorage:WaitForChild("FryConfig"))
local Antrean = require(script.Parent:WaitForChild("Antrean"))

local WOK_TAG = "Wajan"
local TAHU_PER_BATCH = 5

local sessions = {} -- [player] = session yang lagi goreng
local busyWoks = {} -- [wok] = player yang lagi make
local coolingWoks = {} -- [wok] = true selama jeda abis diangkat

local function canFryAt(player, wok)
	local owner = wok:GetAttribute("OwnerUserId")
	if owner ~= nil and owner ~= player.UserId then
		return false
	end
	return wok:GetAttribute("BisaJualan") ~= false
end

local function refreshPrompt(wok, prompt)
	prompt.Enabled = not busyWoks[wok] and not coolingWoks[wok] and wok:GetAttribute("BisaJualan") ~= false
end

local function getUang(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Uang")
end

local function progressAt(session, serverTime)
	return math.clamp((serverTime - session.startTime) / FryConfig.DURATION, 0, 1)
end

-- Potongan tahu kotak yang ngambang di minyak (kotak, biar keliatan pas dibalik).
local function spawnTahu(wok)
	local oil = wok:FindFirstChild("Minyak")
	local folder = Instance.new("Folder")
	folder.Name = "TahuDiWajan"
	folder.Parent = wok

	local tahuList = {}
	-- Ukuran & jarak ngikutin lebar minyak (wajan di kendaraan lebih kecil).
	local radius = oil.Size.Z * 0.25
	local size = math.clamp(oil.Size.Z * 0.24, 0.4, 0.6)
	local tebal = size * 0.6
	local top = oil.Position.Y + oil.Size.X / 2
	for i = 1, TAHU_PER_BATCH do
		local angle = (i / TAHU_PER_BATCH) * math.pi * 2
		local tahu = Instance.new("Part")
		tahu.Name = "Tahu"
		tahu.Size = Vector3.new(size, tebal, size)
		tahu.Material = Enum.Material.SmoothPlastic
		tahu.Color = FryConfig.TAHU_RAW
		tahu.Anchored = true
		tahu.CanCollide = false
		tahu.CanQuery = false
		tahu.CanTouch = false
		tahu.CFrame = CFrame.new(
			oil.Position.X + math.cos(angle) * radius,
			top + tebal * 0.15, -- sebagian besar kecelup
			oil.Position.Z + math.sin(angle) * radius
		) * CFrame.Angles(0, angle * 1.7, 0)
		tahu.Parent = folder
		table.insert(tahuList, tahu)
	end
	return folder, tahuList
end

-- Tahu "diangkat": naik dikit sambil ilang, terus dibuang.
local function liftTahuVisual(folder, tahuList)
	for _, tahu in ipairs(tahuList) do
		TweenService:Create(tahu, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = tahu.Position + Vector3.new(0, 1.2, 0),
			Transparency = 1,
		}):Play()
	end
	task.delay(0.4, function()
		folder:Destroy()
	end)
end

-- Emitter di minyak: "Asap" (pas mulai gosong), "Gelembung" (selama goreng).
-- Dua-duanya opsional, wajan tanpa emitter tetep jalan.
local function setOilEffect(wok, effectName, enabled)
	local oil = wok:FindFirstChild("Minyak")
	local emitter = oil and oil:FindFirstChild(effectName)
	if emitter then
		emitter.Enabled = enabled
	end
end

-- Sutil di tangan kanan (R15). Massless & nggak nabrak, jadi nggak ganggu gerak.
local function pasangSutil(character)
	local hand = character and character:FindFirstChild("RightHand")
	if not hand then
		return nil -- R6 / karakter belum lengkap: goreng tetep jalan, cuma tanpa sutil
	end
	local function part(name, size, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		return p
	end
	local function weld(part0, part1, c0)
		local w = Instance.new("Weld")
		w.Part0 = part0
		w.Part1 = part1
		w.C0 = c0
		w.Parent = part1
	end

	local sutil = Instance.new("Model")
	sutil.Name = "Sutil"
	-- Gagang kayu digenggam, ujungnya keluar ke bawah tangan (sumbu -Y tangan).
	local gagang = part("Gagang", Vector3.new(0.12, 1.0, 0.12), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	gagang.Parent = sutil
	weld(hand, gagang, CFrame.new(0, -0.35, 0))
	-- Daun sutil: pelat besi agak nekuk, buat bolak-balik tahu.
	local daun = part("Daun", Vector3.new(0.45, 0.5, 0.04), Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
	daun.Parent = sutil
	weld(gagang, daun, CFrame.new(0, -0.7, -0.08) * CFrame.Angles(math.rad(20), 0, 0))
	local ujung = Instance.new("Attachment")
	ujung.Name = "Ujung"
	ujung.Position = Vector3.new(0, -0.25, 0)
	ujung.Parent = daun
	sutil.Parent = character
	return sutil
end

local function mulaiAnimasi(player, session)
	local character = player.Character
	if not character then
		return
	end
	session.character = character
	session.sutil = pasangSutil(character)
	local oil = session.wok:FindFirstChild("Minyak")
	character:SetAttribute("TitikWajan", oil.Position + Vector3.new(0, oil.Size.X / 2, 0))
	character:SetAttribute("LagiGoreng", true)
end

local function stopAnimasi(session)
	if session.sutil then
		session.sutil:Destroy()
	end
	if session.character then
		session.character:SetAttribute("LagiGoreng", nil)
		session.character:SetAttribute("TitikWajan", nil)
	end
end

local function endSession(player, session)
	sessions[player] = nil
	busyWoks[session.wok] = nil
	session.heartbeat:Disconnect()
	setOilEffect(session.wok, "Asap", false)
	setOilEffect(session.wok, "Gelembung", false)
	liftTahuVisual(session.tahuFolder, session.tahuList)
	session.wok:SetAttribute("LagiGoreng", false)
	stopAnimasi(session)

	coolingWoks[session.wok] = true
	refreshPrompt(session.wok, session.prompt)
	task.delay(FryConfig.COOLDOWN_SECONDS, function()
		coolingWoks[session.wok] = nil
		refreshPrompt(session.wok, session.prompt)
	end)
end

local function finish(player, session, progress)
	if sessions[player] ~= session then
		return -- udah selesai duluan (misal auto-gosong barengan sama klik angkat)
	end
	endSession(player, session)

	local quality = FryConfig.qualityAt(progress)
	local result = FryConfig.RESULTS[quality]

	-- Wajan di lapak: Antrean yang bayar (pembeli / etalase). Selain itu bayar langsung.
	local pay, tip, catatan
	local info = Antrean.serahkan(session.wok, player, quality)
	if info then
		pay, tip, catatan = info.pay, info.tip, info.catatan
	else
		pay, tip = result.pay, result.tip
		local uang = getUang(player)
		if uang then
			uang.Value += pay + tip
		end
	end

	Remotes.FryResult:FireClient(player, {
		quality = quality,
		label = result.label,
		pay = pay,
		tip = tip,
		total = pay + tip,
		progress = progress,
		catatan = catatan,
	})
end

local function startFrying(player, wok, prompt)
	if sessions[player] or busyWoks[wok] or coolingWoks[wok] or not canFryAt(player, wok) then
		return
	end

	wok:SetAttribute("LagiGoreng", true)
	local tahuFolder, tahuList = spawnTahu(wok)
	local session = {
		wok = wok,
		prompt = prompt,
		startTime = workspace:GetServerTimeNow(),
		tahuFolder = tahuFolder,
		tahuList = tahuList,
	}
	sessions[player] = session
	busyWoks[wok] = player
	prompt.Enabled = false
	setOilEffect(wok, "Gelembung", true)
	mulaiAnimasi(player, session)

	-- Visual di dunia (keliatan semua player): warna tahu + asap pas gosong.
	local gosongStart = FryConfig.gosongStart()
	session.heartbeat = RunService.Heartbeat:Connect(function()
		local progress = progressAt(session, workspace:GetServerTimeNow())
		local color = FryConfig.tahuColorAt(progress)
		for _, tahu in ipairs(tahuList) do
			tahu.Color = color
		end
		setOilEffect(wok, "Asap", progress >= gosongStart)

		if progress >= 1 then
			finish(player, session, 1) -- kelamaan: otomatis keangkat, gosong
		end
	end)

	Remotes.FryStarted:FireClient(player, session.startTime, FryConfig.DURATION)
end

Remotes.LiftTahu.OnServerEvent:Connect(function(player, clientTime)
	local session = sessions[player]
	if not session then
		return
	end

	-- Pake waktu klik dari client biar adil buat yang ping-nya tinggi, tapi
	-- cuma boleh mundur maksimal LIFT_GRACE_SECONDS dan nggak boleh dari masa depan.
	local now = workspace:GetServerTimeNow()
	local liftTime = now
	if typeof(clientTime) == "number" and clientTime == clientTime then -- (x == x) buang NaN
		liftTime = math.clamp(clientTime, now - FryConfig.LIFT_GRACE_SECONDS, now)
	end

	finish(player, session, progressAt(session, liftTime))
end)

local function setupWok(wok)
	local prompt = wok:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt or not wok:FindFirstChild("Minyak") then
		warn(("[FryService] Wajan %s nggak lengkap (butuh ProximityPrompt + part 'Minyak')"):format(wok:GetFullName()))
		return
	end
	prompt.Triggered:Connect(function(player)
		startFrying(player, wok, prompt)
	end)
	wok:GetAttributeChangedSignal("BisaJualan"):Connect(function()
		refreshPrompt(wok, prompt)
	end)
	refreshPrompt(wok, prompt)
end

for _, wok in ipairs(CollectionService:GetTagged(WOK_TAG)) do
	setupWok(wok)
end
CollectionService:GetInstanceAddedSignal(WOK_TAG):Connect(setupWok)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then
		endSession(player, session) -- keluar pas lagi goreng: wajan dibebasin, nggak ada reward
	end
end)
