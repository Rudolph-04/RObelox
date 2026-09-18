-- Bangun ocean + beberapa pulau beda biome sekali doang.
-- Guard + auto-delete Baseplate + offset ke posisi build yang ada,
-- sama kayak versi sebelumnya. Yang baru: multi-pulau (Tropical, Rocky
-- Mountain, Snow, Desert) + pohon/kaktus procedural (Part primitif,
-- bukan asset Toolbox, biar nggak gantung ke ID yang belum tentu ada).

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

if workspace:GetAttribute("BF_TerrainBuilt") then
	return
end

local T = workspace.Terrain
local V3 = Vector3.new
local CF = CFrame.new
local M = Enum.Material

local function log(s)
	print("[BF-Terrain] " .. s)
end

-- ── CONSTANTS ──────────────────────────────────────────────────────
local OCEAN_SIZE = 2500
local OFFSET_X = -157 -- deket SpawnLocation yang udah ada
local OFFSET_Z = -38
local SEA_LEVEL = 161
local FLOOR_Y = SEA_LEVEL - 130
local FLOOR_THICK = 30
local SURF = SEA_LEVEL + 10

local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	log("Menghapus Baseplate default...")
	baseplate:Destroy()
end

log("Clearing existing terrain...")
T:Clear()
task.wait(0.3)

-- ── HELPERS (x/z RELATIF ke OFFSET_X/OFFSET_Z) ──────────────────────
local function col(x, z, r, mat, topY)
	x += OFFSET_X
	z += OFFSET_Z
	topY = topY or SURF
	local h = topY - FLOOR_Y
	T:FillCylinder(CF(V3(x, (topY + FLOOR_Y) / 2, z)), h, r, mat)
end

local function slab(x, y, z, sx, sy, sz, mat)
	x += OFFSET_X
	z += OFFSET_Z
	T:FillBlock(CF(V3(x, y, z)), V3(sx, sy, sz), mat)
end

local function cap(x, z, r, mat, thick)
	x += OFFSET_X
	z += OFFSET_Z
	thick = thick or 8
	T:FillCylinder(CF(V3(x, SURF + 1, z)), thick, r, mat)
end

-- Hill acak + batu-batu di lereng (rockMat opsional, nil = polos).
local function hill(cx, cz, baseR, peakH, mat, rockMat, steps)
	cx += OFFSET_X
	cz += OFFSET_Z
	steps = steps or 16
	for i = 0, steps - 1 do
		local t = i / (steps - 1)
		local jitter = 0.8 + math.random() * 0.4
		local r = math.floor(baseR * (1 - t) ^ 0.7 * jitter)
		if r < 3 then
			r = 3
		end
		local wobble = baseR * 0.15 * (1 - t)
		local wx = cx + (math.random() - 0.5) * wobble
		local wz = cz + (math.random() - 0.5) * wobble
		local yBot = SURF + t * peakH
		local segH = (peakH / steps) + 2
		local yCtr = yBot + segH / 2
		T:FillCylinder(CF(V3(wx, yCtr, wz)), segH, r, mat)
	end

	if rockMat then
		for _ = 1, 8 do
			local t = math.random()
			local angle = math.random() * math.pi * 2
			local rAtT = baseR * (1 - t) ^ 0.7 * (math.random(60, 95) / 100)
			local rx = cx + math.cos(angle) * rAtT
			local rz = cz + math.sin(angle) * rAtT
			local ry = SURF + t * peakH
			T:FillBall(V3(rx, ry, rz), math.random(3, 7), rockMat)
		end
	end
end

-- Pohon: batang silinder + kanopi bola. Part primitif, bukan asset.
local function tree(x, z, canopyColor, trunkH, canopyR)
	x += OFFSET_X
	z += OFFSET_Z
	trunkH = trunkH or math.random(6, 10)
	canopyR = canopyR or math.random(4, 6)

	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = V3(trunkH, 1.4, 1.4)
	trunk.CFrame = CF(V3(x, SURF + trunkH / 2, z)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(92, 64, 51)
	trunk.Parent = workspace

	local canopy = Instance.new("Part")
	canopy.Shape = Enum.PartType.Ball
	canopy.Size = V3(canopyR * 2, canopyR * 2, canopyR * 2)
	canopy.Position = V3(x, SURF + trunkH + canopyR * 0.6, z)
	canopy.Anchored = true
	canopy.CanCollide = false
	canopy.Material = Enum.Material.Grass
	canopy.Color = canopyColor
	canopy.Parent = workspace
end

-- Kaktus sederhana buat pulau gurun.
local function cactus(x, z)
	x += OFFSET_X
	z += OFFSET_Z
	local h = math.random(5, 8)

	local body = Instance.new("Part")
	body.Shape = Enum.PartType.Cylinder
	body.Size = V3(h, 1.6, 1.6)
	body.CFrame = CF(V3(x, SURF + h / 2, z)) * CFrame.Angles(0, 0, math.rad(90))
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.Grass
	body.Color = Color3.fromRGB(59, 122, 87)
	body.Parent = workspace

	local arm = Instance.new("Part")
	arm.Shape = Enum.PartType.Cylinder
	arm.Size = V3(h * 0.4, 1.1, 1.1)
	arm.CFrame = CF(V3(x + 1.5, SURF + h * 0.6, z))
	arm.Anchored = true
	arm.CanCollide = false
	arm.Material = Enum.Material.Grass
	arm.Color = body.Color
	arm.Parent = workspace
end

-- Sebar n titik acak (merata) di dalem lingkaran radius r dari (cx,cz).
local function scatter(cx, cz, r, n, fn)
	for _ = 1, n do
		local angle = math.random() * math.pi * 2
		local dist = math.sqrt(math.random()) * r * 0.85
		fn(cx + math.cos(angle) * dist, cz + math.sin(angle) * dist)
	end
end

-- ── OCEAN FLOOR + WATER ─────────────────────────────────────────────
log("Filling ocean floor (rock)...")
local floorCenterY = FLOOR_Y - (FLOOR_THICK / 2)
T:FillBlock(CF(V3(OFFSET_X, floorCenterY, OFFSET_Z)), V3(OCEAN_SIZE, FLOOR_THICK, OCEAN_SIZE), M.Rock)
task.wait(0.1)

log("Filling water...")
local waterH = SEA_LEVEL - FLOOR_Y
local waterCenterY = (SEA_LEVEL + FLOOR_Y) / 2
T:FillBlock(CF(V3(OFFSET_X, waterCenterY, OFFSET_Z)), V3(OCEAN_SIZE, waterH, OCEAN_SIZE), M.Water)
T.WaterWaveSize = 0.15
T.WaterWaveSpeed = 15
task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- PULAU 1: TROPICAL (utama) — pusat relatif (0,0)
-- ══════════════════════════════════════════════════════════════════
log("Pulau tropical...")
local tropicalLobes = {
	{ 0, 0, 130 }, { 45, 6, 100 }, { -45, 8, 96 },
	{ 18, 55, 90 }, { -15, 52, 85 }, { 6, -52, 95 },
}
for _, l in ipairs(tropicalLobes) do
	col(l[1], l[2], l[3], M.Sand)
end
local tropicalGrass = {
	{ 0, 0, 110 }, { 38, 6, 82 }, { -38, 8, 78 }, { 14, 52, 72 }, { -12, 48, 68 },
}
for _, g in ipairs(tropicalGrass) do
	cap(g[1], g[2], g[3], M.Grass)
end
slab(0, SURF + 2, 20, 100, 7, 84, M.Grass)
slab(40, SURF + 2, 20, 55, 7, 55, M.Grass)
hill(-10, -48, 32, 40, M.Grass, M.Rock)
scatter(0, 0, 120, 14, function(x, z)
	tree(x, z, Color3.fromRGB(63, 122, 55))
end)
task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- PULAU 2: ROCKY MOUNTAIN — pusat relatif (700, 300)
-- ══════════════════════════════════════════════════════════════════
log("Pulau rocky mountain...")
local rockyCX, rockyCZ = 700, 300
col(rockyCX, rockyCZ, 90, M.Rock)
col(rockyCX + 30, rockyCZ - 20, 60, M.Rock)
col(rockyCX - 35, rockyCZ + 15, 55, M.Rock)
hill(rockyCX, rockyCZ, 55, 85, M.Rock, M.Rock)
scatter(rockyCX, rockyCZ, 85, 10, function(x, z)
	x += OFFSET_X
	z += OFFSET_Z
	T:FillBall(V3(x, SURF + math.random(1, 6), z), math.random(4, 9), M.Rock)
end)
task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- PULAU 3: SNOW / ICE — pusat relatif (-650, 350)
-- ══════════════════════════════════════════════════════════════════
log("Pulau snow...")
local snowCX, snowCZ = -650, 350
col(snowCX, snowCZ, 80, M.Snow)
col(snowCX + 25, snowCZ - 15, 45, M.Snow)
hill(snowCX, snowCZ, 40, 35, M.Snow, M.Ice)
scatter(snowCX, snowCZ, 75, 10, function(x, z)
	tree(x, z, Color3.fromRGB(35, 70, 55), math.random(5, 8), math.random(3, 5))
end)
task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- PULAU 4: DESERT — pusat relatif (100, -750)
-- ══════════════════════════════════════════════════════════════════
log("Pulau desert...")
local desertCX, desertCZ = 100, -750
col(desertCX, desertCZ, 85, M.Sand)
col(desertCX - 25, desertCZ + 20, 50, M.Sand)
hill(desertCX + 20, desertCZ - 15, 35, 20, M.Sand, nil)
scatter(desertCX, desertCZ, 80, 6, function(x, z)
	cactus(x, z)
end)
scatter(desertCX, desertCZ, 80, 6, function(x, z)
	x += OFFSET_X
	z += OFFSET_Z
	T:FillBall(V3(x, SURF + 1, z), math.random(3, 6), M.Rock)
end)
task.wait(0.1)

-- ── MARKERS ──────────────────────────────────────────────────────
log("Placing markers...")
local folder = Instance.new("Folder")
folder.Name = "_BF_Markers_HAPUS_SETELAH_BUILD"
folder.Parent = workspace

local mk = {
	{ "1", "SPAWN AREA", 0, SURF + 12, 20, 255, 255, 0 },
	{ "2", "SHOP / NPC", 40, SURF + 12, 20, 255, 165, 0 },
	{ "3", "UPGRADE HILL", -10, SURF + 46, -48, 170, 0, 255 },
	{ "4", "ROCKY ISLAND", rockyCX, SURF + 95, rockyCZ, 150, 150, 150 },
	{ "5", "SNOW ISLAND", snowCX, SURF + 45, snowCZ, 200, 230, 255 },
	{ "6", "DESERT ISLAND", desertCX, SURF + 30, desertCZ, 235, 195, 120 },
}

for _, m in ipairs(mk) do
	local p = Instance.new("Part")
	p.Name = "[" .. m[1] .. "] " .. m[2]
	p.Size = V3(4, 4, 4)
	p.Position = V3(m[3] + OFFSET_X, m[4], m[5] + OFFSET_Z)
	p.Anchored = true
	p.CanCollide = false
	p.Color = Color3.fromRGB(m[6], m[7], m[8])
	p.Material = M.Neon
	p.CastShadow = false
	p.Parent = folder

	local bg = Instance.new("BillboardGui", p)
	bg.Size = UDim2.new(0, 160, 0, 40)
	bg.StudsOffset = V3(0, 5, 0)
	bg.AlwaysOnTop = true

	local tl = Instance.new("TextLabel", bg)
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundColor3 = Color3.new(0, 0, 0)
	tl.BackgroundTransparency = 0.3
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Text = "[" .. m[1] .. "] " .. m[2]
end

workspace:SetAttribute("BF_TerrainBuilt", true)
log("Terrain selesai. Kalau udah oke, File > Save Studio biar kesimpen.")
