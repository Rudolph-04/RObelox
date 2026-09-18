-- Bangun ocean + island sekali doang.
-- Beda sama versi Command Bar sebelumnya:
--   1. OCEAN_SIZE diturunin ke 1200 (4000 kegedean, bikin Studio lama/ngefreeze).
--   2. Baseplate default dihapus otomatis, nggak perlu hapus manual lagi.
--   3. Ada guard (attribute) biar nggak re-build tiap kali server start / tiap Play.
--      Sekali kebangun & lu Save (Ctrl+S) place file-nya, terrain-nya kesimpen,
--      guard ini cuma buat nyegah kebuang waktu re-run pas testing berulang.
--   4. Cuma jalan otomatis di Studio. Kalau lu publish, ini nggak akan re-run
--      di server production (soalnya harusnya udah ke-save di place file).
--   5. OFFSET_X/OFFSET_Z/SEA_LEVEL disesuaikan ke posisi SpawnLocation yang
--      udah ada (-157, 161, -38), bukan lagi di titik (0,0,0). Semua koordinat
--      di bawah ini tetep ditulis RELATIF (misal lobe di 0,0), offset-nya
--      ditambahin otomatis di dalem helper function.

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
local OCEAN_SIZE = 1200 -- total width/length area air (studs)
local OFFSET_X = -157 -- geser pusat pulau ke deket SpawnLocation
local OFFSET_Z = -38
local SEA_LEVEL = 161 -- Y permukaan air, disamain sama Y SpawnLocation
local FLOOR_Y = SEA_LEVEL - 130 -- Y dasar laut
local FLOOR_THICK = 30 -- tebal lapisan rock dasar
local SURF = SEA_LEVEL + 10 -- Y permukaan pulau

-- ── HAPUS BASEPLATE DEFAULT (kalau masih ada) ───────────────────────
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	log("Menghapus Baseplate default...")
	baseplate:Destroy()
end

-- ── CLEAR TERRAIN ───────────────────────────────────────────────────
log("Clearing existing terrain...")
T:Clear()
task.wait(0.3)

-- ── HELPERS (x/z di sini RELATIF ke OFFSET_X/OFFSET_Z) ──────────────
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

local function gcap(x, z, r)
	x += OFFSET_X
	z += OFFSET_Z
	T:FillCylinder(CF(V3(x, SURF + 1, z)), 8, r, M.Grass)
end

-- Hill acak: radius per step dikasih jitter + wobble posisi horizontal,
-- biar siluetnya nggak jadi kerucut sempurna. Ditutup batu-batu nyebar
-- di lereng biar ada tekstur, bukan polos rata.
local function hill(cx, cz, baseR, peakH, mat, steps)
	cx += OFFSET_X
	cz += OFFSET_Z
	steps = steps or 16
	for i = 0, steps - 1 do
		local t = i / (steps - 1)
		local jitter = 0.85 + math.random() * 0.3
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

	for _ = 1, 8 do
		local t = math.random()
		local angle = math.random() * math.pi * 2
		local rAtT = baseR * (1 - t) ^ 0.7 * (math.random(60, 95) / 100)
		local rx = cx + math.cos(angle) * rAtT
		local rz = cz + math.sin(angle) * rAtT
		local ry = SURF + t * peakH
		T:FillBall(V3(rx, ry, rz), math.random(3, 7), M.Rock)
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
task.wait(0.1)

-- ── ISLAND SAND BASE ────────────────────────────────────────────────
log("Island sand base...")
local lobes = {
	{ 0, 0, 130 },
	{ 45, 6, 100 },
	{ -45, 8, 96 },
	{ 18, 55, 90 },
	{ -15, 52, 85 },
	{ 6, -52, 95 },
}
for _, l in ipairs(lobes) do
	col(l[1], l[2], l[3], M.Sand)
end
task.wait(0.1)

-- ── GRASS CAP ───────────────────────────────────────────────────────
log("Grass layer...")
local grassLobes = {
	{ 0, 0, 110 },
	{ 38, 6, 82 },
	{ -38, 8, 78 },
	{ 14, 52, 72 },
	{ -12, 48, 68 },
}
for _, g in ipairs(grassLobes) do
	gcap(g[1], g[2], g[3])
end
task.wait(0.1)

-- ── FLATTEN ZONA PENTING ────────────────────────────────────────────
log("Flattening key zones...")
slab(0, SURF + 2, 20, 100, 7, 84, M.Grass) -- spawn plaza
slab(40, SURF + 2, 20, 55, 7, 55, M.Grass) -- shop area
task.wait(0.1)

-- ── UPGRADE HILL ─────────────────────────────────────────────────────
log("Building hill...")
hill(-10, -48, 32, 40, M.Grass)
T:FillBall(V3(-10 + OFFSET_X, SURF + 36, -48 + OFFSET_Z), 8, M.Rock)
task.wait(0.1)

-- ── MARKERS (referensi lokasi, hapus manual kalau udah nggak butuh) ──
log("Placing markers...")
local folder = Instance.new("Folder")
folder.Name = "_BF_Markers_HAPUS_SETELAH_BUILD"
folder.Parent = workspace

local mk = {
	{ "1", "SPAWN AREA", 0, SURF + 12, 20, 255, 255, 0 },
	{ "2", "SHOP / NPC", 40, SURF + 12, 20, 255, 165, 0 },
	{ "3", "UPGRADE HILL", -10, SURF + 46, -48, 170, 0, 255 },
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
	bg.Size = UDim2.new(0, 150, 0, 40)
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
