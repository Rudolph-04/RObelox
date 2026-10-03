-- Deteksi lempar joran (Tool.Activated) dan tampilin hasil tangkapan
-- lewat popup card (CatchPopup).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local CatchPopup = require(script.Parent:WaitForChild("CatchPopup"))

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
	CatchPopup.show(fish)
end)
