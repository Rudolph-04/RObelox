-- Stage prototipe: jalur lurus sepanjang X + latar (bukit, pohon, gerbang
-- start). Dibangun pas server mulai, jadi place-nya boleh kosong.
-- ModuleScript di ServerScriptService.
--
-- Kamera ngeliat dari +Z ke -Z, jadi latar ditaruh di -Z. Lantai di atas
-- y = 0.5 biar nggak numpuk sama Baseplate bawaan (atasnya y = 0).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage:WaitForChild("LaskarConfig"))

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

local Arena = {}

local function part(parent, nama, size, cf, warna, material, bentuk)
	local p = Instance.new("Part")
	p.Name = nama
	p.Size = size
	p.CFrame = cf
	p.Color = warna
	p.Material = material or M.SmoothPlastic
	if bentuk then
		p.Shape = bentuk
	end
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Arena.bangun()
	local lama = workspace:FindFirstChild("Arena")
	if lama then
		lama:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arena"

	local a = C.ARENA
	local x1, x2 = a.mulaiX - 60, a.akhirX + 60
	local tengahX = (x1 + x2) / 2
	local panjang = x2 - x1

	-- Tanah (atas y 0.5) + jalan tanah (atas y = tanahY).
	part(folder, "Tanah", V3(panjang, 1, 140), CFrame.new(tengahX, 0, -30), RGB(96, 140, 72), M.Grass)
	local tebalJalan = 0.2
	part(folder, "Jalan", V3(panjang, tebalJalan, 20), CFrame.new(tengahX, a.tanahY - tebalJalan / 2, 0), RGB(176, 146, 104), M.Ground)

	-- Bukit (bola setengah kependem) di belakang jalur.
	local acak = Random.new(7) -- seed tetap: bentuk stage selalu sama
	local warnaBukit = { RGB(84, 128, 66), RGB(72, 116, 60), RGB(98, 142, 78) }
	local x = x1
	while x < x2 do
		local d = acak:NextNumber(50, 90)
		local z = acak:NextNumber(-95, -70)
		part(folder, "Bukit", V3(d, d, d), CFrame.new(x, -d * 0.3, z), warnaBukit[acak:NextInteger(1, #warnaBukit)], M.Grass, Enum.PartType.Ball)
		x += d * 0.6
	end
	-- Gunung jauh (agak kebiruan).
	x = x1
	while x < x2 do
		local d = acak:NextNumber(140, 220)
		part(folder, "Gunung", V3(d, d, d), CFrame.new(x, -d * 0.35, -230), RGB(110, 140, 160), M.SmoothPlastic, Enum.PartType.Ball)
		x += d * 0.7
	end

	-- Pohon sederhana di antara jalur & bukit.
	for _ = 1, 26 do
		local px = acak:NextNumber(x1 + 10, x2 - 10)
		local pz = acak:NextNumber(-40, -16)
		local tinggi = acak:NextNumber(5, 9)
		part(folder, "Batang", V3(tinggi, 0.8, 0.8), CFrame.new(px, 0.5 + tinggi / 2, pz) * CFrame.Angles(0, 0, math.rad(90)), RGB(104, 72, 46), M.Wood, Enum.PartType.Cylinder)
		local daun = acak:NextNumber(4.5, 7)
		part(folder, "Daun", V3(daun, daun, daun), CFrame.new(px, 0.5 + tinggi + daun * 0.25, pz), warnaBukit[acak:NextInteger(1, #warnaBukit)], M.Grass, Enum.PartType.Ball)
	end

	-- Gerbang start: dua tiang bambu + kain melintang (polos, tanpa tulisan).
	local gx = a.mulaiX - 14
	for _, z in ipairs({ -10.5, 10.5 }) do
		part(folder, "TiangGerbang", V3(9, 0.6, 0.6), CFrame.new(gx, 0.5 + 4.5, z) * CFrame.Angles(0, 0, math.rad(90)), RGB(198, 172, 108), M.Wood, Enum.PartType.Cylinder)
	end
	part(folder, "KainGerbang", V3(0.1, 1.4, 21), CFrame.new(gx, 8.2, 0), RGB(170, 50, 44), M.Fabric)

	-- Spawn sendiri di belakang garis start (server mindahin avatar ke formasi).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLaskar"
	spawn.Anchored = true
	spawn.Size = V3(8, 0.2, 8)
	spawn.CFrame = CFrame.new(a.mulaiX - 22, a.tanahY + 0.1, 0)
	spawn.Color = RGB(176, 146, 104)
	spawn.Material = M.Ground
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0 -- tanpa ForceField (panglima langsung bisa kena serang)
	spawn.Parent = folder
	-- Spawn lain (bawaan template) dimatiin biar nggak muncul di tempat aneh.
	for _, s in ipairs(workspace:GetDescendants()) do
		if s:IsA("SpawnLocation") and s ~= spawn then
			s.Enabled = false
		end
	end

	Lighting.ClockTime = 15.5
	folder.Parent = workspace
	return folder
end

return Arena
