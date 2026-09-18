-- Logika mancing: terima CastRod dari client, tunggu beberapa detik,
-- roll ikan secara weighted-random, kasih coins, kirim hasil ke client.
-- SEMUA hasil (ikan + coins) ditentukan di SERVER, client cuma trigger
-- & nampilin — supaya nggak bisa dicurangin dari client (exploit).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local FishData = require(ReplicatedStorage:WaitForChild("FishData"))

local CAST_MIN_SECONDS = 3
local CAST_MAX_SECONDS = 7

local castingPlayers = {}

local function rollFish()
	local totalWeight = 0
	for _, fish in ipairs(FishData) do
		totalWeight += fish.weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, fish in ipairs(FishData) do
		cumulative += fish.weight
		if roll <= cumulative then
			return fish
		end
	end

	return FishData[1]
end

Remotes.CastRod.OnServerEvent:Connect(function(player)
	if castingPlayers[player] then
		return -- lagi mancing, abaikan spam klik
	end
	castingPlayers[player] = true

	local waitTime = math.random(CAST_MIN_SECONDS, CAST_MAX_SECONDS)
	task.wait(waitTime)

	if player.Parent then
		local fish = rollFish()

		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")
		if coins then
			coins.Value += fish.value
		end

		Remotes.CatchResult:FireClient(player, fish)
	end

	castingPlayers[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	castingPlayers[player] = nil
end)
