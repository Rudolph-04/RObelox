-- Leaderstats "Coins" per player.
-- CATATAN: belum ada DataStore, jadi coins RESET tiap player rejoin.
-- Ini next-step yang harus ditambahin sebelum publish beneran.

local Players = game:GetService("Players")

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)
