-- Deteksi lempar joran (Tool.Activated) dan tampilin hasil tangkapan.
-- UI beneran (popup, animasi) belum ada — ini masih versi print/chat doang
-- buat mastiin alur cast -> catch -> coins-nya jalan dulu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local isCasting = false

local function onToolEquipped(tool)
	if tool.Name ~= "FishingRod" then
		return
	end

	tool.Activated:Connect(function()
		if isCasting then
			return
		end
		isCasting = true
		Remotes.CastRod:FireServer()
	end)
end

local function onCharacterAdded(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

Remotes.CatchResult.OnClientEvent:Connect(function(fish)
	isCasting = false
	print(("Dapet ikan: %s [%s] +%d coins"):format(fish.name, fish.rarity, fish.value))
end)
