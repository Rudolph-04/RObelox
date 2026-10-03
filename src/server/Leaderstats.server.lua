-- Leaderstats "Uang" per player (rupiah).
-- CATATAN: belum ada DataStore, jadi uang RESET tiap player rejoin.

local Players = game:GetService("Players")

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local uang = Instance.new("IntValue")
	uang.Name = "Uang"
	uang.Value = 0
	uang.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
