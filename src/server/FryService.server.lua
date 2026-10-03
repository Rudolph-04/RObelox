-- Mekanik goreng (server-authoritative).
--
-- Alur: player pencet ProximityPrompt di wajan -> server catet waktu mulai ->
-- client nampilin bar -> player klik "Angkat" -> server ngitung sendiri udah
-- berapa lama -> kualitas (Mentah/Oke/Perfect/Gosong) -> kasih uang.
-- Client NGGAK pernah ngirim kualitas atau jumlah uang, cuma "angkat sekarang".
--
-- Wajan dicari lewat tag CollectionService "Wajan" (lihat tools/BuildPasar.luau),
-- jadi map bebas diubah/ditambah wajan tanpa ngedit script ini.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local FryConfig = require(ReplicatedStorage:WaitForChild("FryConfig"))

local WOK_TAG = "Wajan"
local TAHU_PER_BATCH = 5

local sessions = {} -- [player] = session yang lagi goreng
local busyWoks = {} -- [wok] = player yang lagi make

local function getUang(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Uang")
end

local function progressAt(session, serverTime)
	return math.clamp((serverTime - session.startTime) / FryConfig.DURATION, 0, 1)
end

-- Tahu bulat kecil-kecil yang ngambang di minyak.
local function spawnTahu(wok)
	local oil = wok:FindFirstChild("Minyak")
	local folder = Instance.new("Folder")
	folder.Name = "TahuDiWajan"
	folder.Parent = wok

	local tahuList = {}
	local radius = oil.Size.Z * 0.22
	local top = oil.Position.Y + oil.Size.X / 2
	for i = 1, TAHU_PER_BATCH do
		local angle = (i / TAHU_PER_BATCH) * math.pi * 2
		local tahu = Instance.new("Part")
		tahu.Name = "Tahu"
		tahu.Shape = Enum.PartType.Ball
		tahu.Size = Vector3.new(0.6, 0.6, 0.6)
		tahu.Material = Enum.Material.SmoothPlastic
		tahu.Color = FryConfig.TAHU_RAW
		tahu.Anchored = true
		tahu.CanCollide = false
		tahu.CanQuery = false
		tahu.CanTouch = false
		tahu.Position = Vector3.new(
			oil.Position.X + math.cos(angle) * radius,
			top + 0.18,
			oil.Position.Z + math.sin(angle) * radius
		)
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

local function setSmoke(wok, enabled)
	local oil = wok:FindFirstChild("Minyak")
	local smoke = oil and oil:FindFirstChild("Asap")
	if smoke then
		smoke.Enabled = enabled
	end
end

local function endSession(player, session)
	sessions[player] = nil
	busyWoks[session.wok] = nil
	session.heartbeat:Disconnect()
	setSmoke(session.wok, false)
	liftTahuVisual(session.tahuFolder, session.tahuList)

	task.delay(FryConfig.COOLDOWN_SECONDS, function()
		if not busyWoks[session.wok] then
			session.prompt.Enabled = true
		end
	end)
end

local function finish(player, session, progress)
	if sessions[player] ~= session then
		return -- udah selesai duluan (misal auto-gosong barengan sama klik angkat)
	end
	endSession(player, session)

	local quality = FryConfig.qualityAt(progress)
	local result = FryConfig.RESULTS[quality]
	local total = result.pay + result.tip

	local uang = getUang(player)
	if uang then
		uang.Value += total
	end

	Remotes.FryResult:FireClient(player, {
		quality = quality,
		label = result.label,
		pay = result.pay,
		tip = result.tip,
		total = total,
		progress = progress,
	})
end

local function startFrying(player, wok, prompt)
	if sessions[player] or busyWoks[wok] then
		return
	end

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

	-- Visual di dunia (keliatan semua player): warna tahu + asap pas gosong.
	local gosongStart = FryConfig.gosongStart()
	session.heartbeat = RunService.Heartbeat:Connect(function()
		local progress = progressAt(session, workspace:GetServerTimeNow())
		local color = FryConfig.tahuColorAt(progress)
		for _, tahu in ipairs(tahuList) do
			tahu.Color = color
		end
		setSmoke(wok, progress >= gosongStart)

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
