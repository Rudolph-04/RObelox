-- Kendaraan dagangan per player (sekarang baru gerobak motor, nanti nambah lewat upgrade).
--
-- Player ngeluarin kendaraan dari menu KENDARAAN (KendaraanMenu) -> server
-- clone template ServerStorage.Kendaraan.<template> ke petak parkir bertag
-- "ParkirKendaraan" yang kosong & paling deket. Keluarin lagi = yang lama
-- diganti (sekalian jadi cara "reset" kalau kendaraannya nyangkut).
--
-- Nyetirnya di client (KendaraanController) biar responsif: pas pemilik
-- duduk di Kemudi, network owner dikasih ke dia. Server cuma ngatur:
--   - siapa boleh naik Kemudi / duduk di KursiGoreng (pemilik doang)
--   - atribut "BisaJualan" di wajan + "LapakBuka" di model: true kalau
--     kendaraan diem di dalem part bertag "TitikJualan" dan nggak ada yang
--     nyetir. FryService nolak goreng kalau false; client ngebuka panel
--     samping box (jadi kanopi) kalau true. Pemilik boleh goreng sambil
--     berdiri atau duduk di KursiGoreng (di dalem box).
--   - prompt Naik (F) & Duduk Jualan (G) nyala-mati (lihat refreshSellState)
--   - kendaraan dikunci (Anchored) selama wajan "LagiGoreng" (diset FryService)

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

local owned = {} -- [player] = { model, chassis, kemudi, kursi, wajan, gerak, arah, naikPrompt, dudukPrompt }
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

-- Boleh jualan = diem di TITIK JUALAN & nggak ada yang nyetir. Selama goreng
-- (kendaraan dikunci) dianggep boleh, soalnya goreng cuma bisa mulai kalau udah boleh.
local function canSellNow(v)
	if v.chassis.Anchored then
		return true
	end
	return v.kemudi.Occupant == nil
		and v.chassis.AssemblyLinearVelocity.Magnitude < KendaraanConfig.PARKED_SPEED
		and isInSellZone(v.chassis.Position)
end

-- Satu tempat buat status jualan + prompt, biar nggak ada prompt yang nongol
-- pas nggak relevan (tombolnya beda semua, jadi nggak rebutan):
--   F (naik)  : jok supir kosong, nggak lagi goreng, nggak ada yang duduk jualan
--   G (duduk) : lapak buka & kursi jualan kosong
--   E (goreng): diatur FryService dari atribut BisaJualan di wajan
local function refreshSellState(v)
	local open = canSellNow(v)
	if v.model:GetAttribute("LapakBuka") ~= open then
		v.model:SetAttribute("LapakBuka", open)
	end
	if v.wajan and v.wajan:GetAttribute("BisaJualan") ~= open then
		v.wajan:SetAttribute("BisaJualan", open)
	end
	local sellerSeated = v.kursi ~= nil and v.kursi.Occupant ~= nil
	v.naikPrompt.Enabled = v.kemudi.Occupant == nil and not frying(v) and not sellerSeated
	if v.dudukPrompt then
		v.dudukPrompt.Enabled = open and not sellerSeated
	end
end

local function sitPrompt(player, prompt, seat, allowed)
	prompt.Triggered:Connect(function(who)
		if who ~= player or seat.Occupant or not allowed() then
			return
		end
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
			seat:Sit(humanoid)
		end
	end)
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
	local kursi = model:FindFirstChild("KursiGoreng")
	local v = {
		model = model,
		chassis = chassis,
		kemudi = kemudi,
		kursi = kursi,
		wajan = model:FindFirstChild("Wajan", true),
		gerak = chassis:FindFirstChild("Gerak"),
		arah = chassis:FindFirstChild("Arah"),
		naikPrompt = kemudi:FindFirstChild("NaikPrompt", true),
		dudukPrompt = kursi and kursi:FindFirstChild("DudukPrompt", true),
	}
	model:SetAttribute("LapakBuka", false)
	if v.wajan then
		v.wajan:SetAttribute("OwnerUserId", player.UserId)
		v.wajan:SetAttribute("BisaJualan", false)
	end
	local tag = chassis:FindFirstChild("Pemilik", true)
	if tag then
		tag.Nama.Text = info.nama .. " " .. player.DisplayName
	end

	model:PivotTo(spawnCFrame)
	v.arah.CFrame = yawOnly(spawnCFrame)
	model.Parent = folder
	chassis:SetNetworkOwner(nil)
	owned[player] = v

	sitPrompt(player, v.naikPrompt, kemudi, function()
		return not frying(v) and not (kursi and kursi.Occupant)
	end)
	guardSeat(player, kemudi, function()
		if chassis.Anchored then
			ejectFrom(kemudi) -- lagi goreng, nggak bisa jalan
			return
		end
		chassis:SetNetworkOwner(player)
		refreshSellState(v) -- langsung tutup lapak, jangan nunggu cek berkala
	end, function()
		hold(v)
		if not chassis.Anchored then
			chassis:SetNetworkOwner(nil)
		end
		refreshSellState(v)
	end)

	if kursi and v.dudukPrompt then
		-- Duduk jualan cuma pas lapak buka (sama kayak prompt-nya); goreng
		-- sambil berdiri juga tetep boleh.
		sitPrompt(player, v.dudukPrompt, kursi, function()
			return model:GetAttribute("LapakBuka") == true
		end)
		guardSeat(player, kursi, function()
			refreshSellState(v)
		end, function()
			refreshSellState(v)
		end)
	end

	if v.wajan then
		v.wajan:GetAttributeChangedSignal("LagiGoreng"):Connect(function()
			local isFrying = frying(v)
			hold(v)
			chassis.Anchored = isFrying
			if not isFrying then
				chassis:SetNetworkOwner(nil)
			end
			refreshSellState(v)
		end)
	end
	refreshSellState(v)
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
	if current and current.wajan and current.wajan:GetAttribute("LagiGoreng") then
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

-- Cek berkala: boleh jualan di sini? jatoh dari map?
while true do
	task.wait(CHECK_INTERVAL)
	for player, v in pairs(owned) do
		if v.model.Parent then
			local position = v.chassis.Position
			if position.Y < FALL_LIMIT_Y and v.kemudi.Occupant == nil then
				v.chassis.Anchored = true
				v.model:PivotTo(findSpawnCFrame(player, v))
				v.chassis.AssemblyLinearVelocity = Vector3.zero
				hold(v)
				v.chassis.Anchored = false
				v.chassis:SetNetworkOwner(nil)
			end

			refreshSellState(v)
		end
	end
end
