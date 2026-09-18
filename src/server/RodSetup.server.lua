-- Bikin Tool "FishingRod" sederhana dan taro di StarterPack biar tiap
-- player yang spawn otomatis punya joran di Backpack.

local StarterPack = game:GetService("StarterPack")

if StarterPack:FindFirstChild("FishingRod") then
	return
end

local tool = Instance.new("Tool")
tool.Name = "FishingRod"
tool.RequiresHandle = true

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.4, 0.4, 4)
handle.Color = Color3.fromRGB(92, 64, 51)
handle.Material = Enum.Material.Wood
handle.CanCollide = false
handle.Parent = tool

tool.Parent = StarterPack
