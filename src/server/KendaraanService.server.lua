-- Kendaraan dagangan per player (sekarang baru gerobak motor, nanti nambah lewat upgrade).
--
-- Player ngeluarin kendaraan dari menu KENDARAAN (KendaraanMenu) -> server
-- clone template ServerStorage.Kendaraan.<template> ke petak parkir bertag
-- "ParkirKendaraan" yang kosong & paling deket. Keluarin lagi = yang lama
-- diganti (sekalian jadi cara "reset" kalau kendaraannya nyangkut).
--
-- Nyetirnya di client (KendaraanController) biar responsif: pas pemilik
-- duduk di Kemudi, network owner dikasih ke dia. Server cuma ngatur:
--   - siapa boleh naik Kemudi / duduk di bangku jualan (pemilik doang)
--   - BUKA LAPAK otomatis pas kendaraan diem di dalem part bertag
--     "TitikJualan" & nggak ada yang nyetir: template lapak luar
--     (KendaraanConfig `lapak`, isinya meja goreng + wajan + bangku) di-clone
--     ke sisi kiri kendaraan (anchored, nggak di-weld), atribut "LapakBuka"
--     di model = true (client ngangkat panel jadi peneduh), kendaraan dikunci.
--   - TUTUP LAPAK pas pemilik pencet Naik (F): lapak luar dihapus, panel
--     nutup, kendaraan dilepas, baru dia didudukin di jok. Nggak bisa selama
--     lagi goreng (atribut "LagiGoreng" di wajan, diset FryService).
--   - prompt Naik (F) & Duduk Jualan (G) nyala-mati (lihat refreshPrompts)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local KendaraanConfig = require(ReplicatedStorage:WaitForChild("KendaraanConfig"))

local TEMPLATES = ServerStorage:WaitForChild("Kendaraan")
local SLOT_TAG = "ParkirKendaraan"
local ZONE_TAG = "TitikJualan"
local CHECK_INTERVAL = 0.25
local FALL_LIMIT_Y = -30 -- kecebur keluar map -> balikin ke parkiran
local SLOT_TAKEN_RADIUS = 4

local folder = Instance.new("Folder")
folder.Name = "Kendaraan"
folder.Parent = workspace

local owned = {} -- [player] = { model, chassis, kemudi, gerak, arah, naikPrompt, lapakTemplate, + selama lapak buka: lapak, wajan, kursi, dudukPrompt }
local lastSpawn = {} -- [player] = os.clock() terakhir keluarin kendaraan

local function isInSellZone(position)
	for _, zone in ipairs(CollectionService:GetTagged(ZONE_TAG)) do
		if zone:IsDescendantOf(workspace) then
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- Ada player yang lagi berdiri di petak ini? (Kendaraan yang muncul di atas
-- orang bakal saling dorong.) Ukurannya kira-kira tapak kendaraan (box 6 x 8,
-- motor nongol ke depan).
local function playerStandingIn(slot)
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local p = slot.CFrame:PointToObjectSpace(root.Position)
			if math.abs(p.X) < 3.8 and p.Z > -7.5 and p.Z < 7.5 then
				return true
			end
		end
	end
	return false
end

-- Petak parkir kosong yang paling deket ke player. Kalau penuh semua, taro
-- di belakang barisan petak (di luar titik jualan).
local function findSpawnCFrame(player, ignore)
	local character = player.Character
	local from = character and character:GetPivot().Position or Vector3.zero
	local best, bestDistance = nil, math.huge
	local anySlot
	for _, slot in ipairs(CollectionService:GetTagged(SLOT_TAG)) do
		if slot:IsDescendantOf(workspace) then
			anySlot = anySlot or slot
			local taken = false
			for _, v in pairs(owned) do
				if v ~= ignore then
					local offset = v.model:GetPivot().Position - slot.Position
					if Vector3.new(offset.X, 0, offset.Z).Magnitude < SLOT_TAKEN_RADIUS then
						taken = true
						break
					end
				end
			end
			local distance = (slot.Position - from).Magnitude
			if not taken and distance < bestDistance and not playerStandingIn(slot) then
				best, bestDistance = slot, distance
			end
		end
	end
	if best then
		return best.CFrame
	end
	local count = 0
	for _ in pairs(owned) do
		count += 1
	end
	local first = anySlot and anySlot.CFrame or CFrame.new(0, 5, 0)
	return first * CFrame.new(count * 7 % 40, 0, 20)
end

local function yawOnly(cf)
	local _, yaw = cf:ToOrientation()
	return CFrame.fromOrientation(0, yaw, 0)
end

-- "Rem tangan": berhenti di tempat, ngadep ke arah sekarang. Dipanggil tiap
-- server ngambil alih fisika lagi (target di client nggak ke-replicate).
local function hold(v)
	v.gerak.PlaneVelocity = Vector2.zero
	v.arah.CFrame = yawOnly(v.chassis.CFrame)
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function ejectFrom(seat)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
end

local function despawn(player)
	local v = owned[player]
	owned[player] = nil
	if v then
		ejectFrom(v.kemudi)
		if v.kursi then
			ejectFrom(v.kursi)
		end
		-- Langsung keluar dari dunia (biar nggak tabrakan sama penggantinya),
		-- Destroy-nya ditunda biar FryService sempet beresin sesi goreng dulu.
		v.model.Parent = nil
		task.defer(function()
			v.model:Destroy()
		end)
	end
end

-- Cuma pemilik yang boleh duduk; yang lain langsung diturunin.
local function guardSeat(player, seat, onOwnerSeated, onLeft)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if humanoid then
			if Players:GetPlayerFromCharacter(humanoid.Parent) ~= player then
				ejectFrom(seat)
				return
			end
			if onOwnerSeated then
				onOwnerSeated()
			end
		elseif onLeft then
			onLeft()
		end
	end)
end

local function frying(v)
	return v.wajan ~= nil and v.wajan:GetAttribute("LagiGoreng") == true
end

-- Boleh buka lapak = diem di TITIK JUALAN & nggak ada yang nyetir.
local function canOpen(v)
	return v.kemudi.Occupant == nil
		and v.chassis.AssemblyLinearVelocity.Magnitude < KendaraanConfig.PARKED_SPEED
		and isInSellZone(v.chassis.Position)
end

-- Prompt cuma nyala pas relevan (tombolnya beda semua, jadi nggak rebutan):
--   F (naik)  : jok supir kosong, nggak lagi goreng, nggak ada yang duduk jualan
--   G (duduk) : cuma ada pas lapak buka; mati kalau bangkunya udah didudukin
--   E (goreng): cuma ada pas lapak buka; nyala-matinya diatur FryService
local function refreshPrompts(v)
	local sellerSeated = v.kursi ~= nil and v.kursi.Occupant ~= nil
	v.naikPrompt.Enabled = v.kemudi.Occupant == nil and not frying(v) and not sellerSeated
	if v.dudukPrompt then
		v.dudukPrompt.Enabled = not sellerSeated
	end
end

local function sitPrompt(player, prompt, seat, allowed, beforeSit)
	prompt.Triggered:Connect(function(who)
		if who ~= player or seat.Occupant or not allowed() then
			return
		end
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
			if beforeSit then
				beforeSit()
			end
			seat:Sit(humanoid)
		end
	end)
end

-- Buka lapak: meja goreng + bangku muncul di sisi kiri kendaraan (posisinya
-- diambil dari pivot kendaraan, dibikin rata air), kendaraan dikunci.
local function openStall(player, v)
	if v.lapak or not v.lapakTemplate then
		return
	end
	hold(v)
	v.chassis.Anchored = true

	local lapak = v.lapakTemplate:Clone()
	lapak.Name = "LapakLuar"
	local pivot = v.model:GetPivot()
	lapak:PivotTo(CFrame.new(pivot.Position) * yawOnly(pivot))
	v.lapak = lapak
	v.wajan = lapak:FindFirstChild("Wajan", true)
	v.kursi = lapak:FindFirstChild("KursiGoreng", true)
	v.dudukPrompt = v.kursi and v.kursi:FindFirstChild("DudukPrompt", true)

	if v.wajan then
		v.wajan:SetAttribute("OwnerUserId", player.UserId)
		v.wajan:SetAttribute("BisaJualan", true)
		v.wajan:GetAttributeChangedSignal("LagiGoreng"):Connect(function()
			refreshPrompts(v)
		end)
	end
	if v.kursi and v.dudukPrompt then
		sitPrompt(player, v.dudukPrompt, v.kursi, function()
			return v.lapak == lapak
		end)
		guardSeat(player, v.kursi, function()
			refreshPrompts(v)
		end, function()
			refreshPrompts(v)
		end)
	end

	lapak.Parent = v.model -- ikut keapus kalau kendaraannya dihapus
	v.model:SetAttribute("LapakBuka", true)
	refreshPrompts(v)
end

-- Tutup lapak (sebelum nyetir). Nggak bisa selama lagi goreng.
local function closeStall(v)
	if not v.lapak or frying(v) then
		return
	end
	if v.kursi then
		ejectFrom(v.kursi)
	end
	v.lapak:Destroy()
	v.lapak, v.wajan, v.kursi, v.dudukPrompt = nil, nil, nil, nil
	v.model:SetAttribute("LapakBuka", false)
	v.chassis.Anchored = false
	v.chassis:SetNetworkOwner(nil)
	hold(v)
	refreshPrompts(v)
end

local function spawnFor(player, info)
	local template = TEMPLATES:FindFirstChild(info.template)
	if not template then
		warn(("[KendaraanService] Template %s nggak ada di ServerStorage.Kendaraan"):format(info.template))
		return false
	end

	local spawnCFrame = findSpawnCFrame(player, owned[player])
	despawn(player)

	local model = template:Clone()
	model.Name = info.id .. "_" .. player.Name
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Kendaraan", info.id)

	local chassis = model.PrimaryPart
	local kemudi = model:FindFirstChild("Kemudi")
	local v = {
		model = model,
		chassis = chassis,
		kemudi = kemudi,
		gerak = chassis:FindFirstChild("Gerak"),
		arah = chassis:FindFirstChild("Arah"),
		naikPrompt = kemudi:FindFirstChild("NaikPrompt", true),
		lapakTemplate = info.lapak and TEMPLATES:FindFirstChild(info.lapak),
	}
	if info.lapak and not v.lapakTemplate then
		warn(("[KendaraanService] Template lapak %s nggak ada di ServerStorage.Kendaraan"):format(info.lapak))
	end
	model:SetAttribute("LapakBuka", false)
	local tag = chassis:FindFirstChild("Pemilik", true)
	if tag then
		tag.Nama.Text = info.nama .. " " .. player.DisplayName
	end

	model:PivotTo(spawnCFrame)
	v.arah.CFrame = yawOnly(spawnCFrame)
	model.Parent = folder
	chassis:SetNetworkOwner(nil)
	owned[player] = v

	-- Naik (F) = tutup lapak dulu (kalau kebuka), baru duduk di jok.
	sitPrompt(player, v.naikPrompt, kemudi, function()
		return not frying(v) and not (v.kursi and v.kursi.Occupant)
	end, function()
		closeStall(v)
	end)
	guardSeat(player, kemudi, function()
		if v.lapak then
			closeStall(v) -- jaga-jaga: nggak boleh nyetir selama lapak kebuka
		end
		if chassis.Anchored then
			ejectFrom(kemudi) -- lapak nggak bisa ditutup (lagi goreng)
			return
		end
		chassis:SetNetworkOwner(player)
		refreshPrompts(v)
	end, function()
		hold(v)
		if not chassis.Anchored then
			chassis:SetNetworkOwner(nil)
		end
		refreshPrompts(v)
	end)
	refreshPrompts(v)
	return true
end

Remotes.SpawnKendaraan.OnServerEvent:Connect(function(player, id)
	local info = typeof(id) == "string" and KendaraanConfig.get(id)
	if not info then
		return
	end
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < KendaraanConfig.SPAWN_COOLDOWN then
		Remotes.InfoKendaraan:FireClient(player, "Tunggu bentar ya...", false)
		return
	end
	local current = owned[player]
	if current and frying(current) then
		Remotes.InfoKendaraan:FireClient(player, "Lagi goreng! Angkat tahunya dulu.", false)
		return
	end
	lastSpawn[player] = now
	if spawnFor(player, info) then
		Remotes.InfoKendaraan:FireClient(player, info.nama .. " udah nunggu di parkiran!", true)
	else
		Remotes.InfoKendaraan:FireClient(player, "Kendaraan belum tersedia.", false)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	despawn(player)
	lastSpawn[player] = nil
end)

-- Cek berkala: udah diem di titik jualan (buka lapak)? jatoh dari map?
while true do
	task.wait(CHECK_INTERVAL)
	for player, v in pairs(owned) do
		if v.model.Parent and not v.lapak then
			if v.chassis.Position.Y < FALL_LIMIT_Y and v.kemudi.Occupant == nil then
				v.chassis.Anchored = true
				v.model:PivotTo(findSpawnCFrame(player, v))
				v.chassis.AssemblyLinearVelocity = Vector3.zero
				hold(v)
				v.chassis.Anchored = false
				v.chassis:SetNetworkOwner(nil)
			elseif canOpen(v) then
				openStall(player, v)
			end
		end
	end
end
