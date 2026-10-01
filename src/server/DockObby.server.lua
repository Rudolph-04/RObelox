-- Dermaga kayu dari pulau tropical ke arah laut, ujungnya nyambung ke
-- obby ringan (platform loncat jarak aman + 1 platform gerak).
-- Baca posisi/level dari attribute yang disimpen TerrainBuilder, biar
-- nggak hardcode ulang dan otomatis nyambung meski terrain-nya di-tweak.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

if not RunService:IsStudio() then
	return
end

if workspace:GetAttribute("BF_DockObbyBuilt") then
	return
end

if not workspace:GetAttribute("BF_TerrainBuilt") then
	warn("[BF-DockObby] Terrain belum dibangun, jalanin TerrainBuilder dulu.")
	return
end

local OFFSET_X = workspace:GetAttribute("BF_OffsetX") or 0
local OFFSET_Z = workspace:GetAttribute("BF_OffsetZ") or 0
local SURF = workspace:GetAttribute("BF_Surf") or 10

local V3 = Vector3.new
local CF = CFrame.new

local function log(s)
	print("[BF-DockObby] " .. s)
end

local folder = Instance.new("Folder")
folder.Name = "DockObby"
folder.Parent = workspace

local function plank(x, y, z, sx, sy, sz, name)
	local p = Instance.new("Part")
	p.Name = name or "Plank"
	p.Size = V3(sx, sy, sz)
	p.Position = V3(x + OFFSET_X, y, z + OFFSET_Z)
	p.Anchored = true
	p.Material = Enum.Material.WoodPlanks
	p.Color = Color3.fromRGB(120, 84, 53)
	p.Parent = folder
	return p
end

local function piling(x, z, topY)
	local bottomY = topY - 140 -- nancep sampe dasar laut, aman lebih panjang drpd nanggung
	local height = topY - bottomY
	local post = Instance.new("Part")
	post.Name = "Piling"
	post.Shape = Enum.PartType.Cylinder
	post.Size = V3(height, 1.2, 1.2)
	post.CFrame = CF(V3(x + OFFSET_X, (topY + bottomY) / 2, z + OFFSET_Z)) * CFrame.Angles(0, 0, math.rad(90))
	post.Anchored = true
	post.Material = Enum.Material.Wood
	post.Color = Color3.fromRGB(84, 58, 36)
	post.Parent = folder
end

-- ══════════════════════════════════════════════════════════════════
-- DERMAGA: dari pinggir pulau tropical (z≈145) ke laut (z≈255)
-- ══════════════════════════════════════════════════════════════════
log("Bangun dermaga...")

local DOCK_START_Z = 145
local DOCK_END_Z = 255
local DOCK_WIDTH = 8

plank(0, SURF + 0.5, (DOCK_START_Z + DOCK_END_Z) / 2, DOCK_WIDTH, 1.2, DOCK_END_Z - DOCK_START_Z, "Dermaga")

for z = DOCK_START_Z + 10, DOCK_END_Z - 5, 20 do
	piling(-3, z, SURF)
	piling(3, z, SURF)
end

-- Gazebo kecil di ujung dermaga, enak buat spot mancing.
plank(0, SURF + 0.6, DOCK_END_Z + 8, 16, 1.4, 16, "DermagaUjung")
piling(-6, DOCK_END_Z + 8, SURF)
piling(6, DOCK_END_Z + 8, SURF)
piling(-6, DOCK_END_Z + 14, SURF)
piling(6, DOCK_END_Z + 14, SURF)

-- ══════════════════════════════════════════════════════════════════
-- OBBY RINGAN: platform loncat jarak aman (6-8 stud), 1 platform gerak
-- ══════════════════════════════════════════════════════════════════
log("Bangun obby ringan...")

local obbyStartZ = DOCK_END_Z + 16 -- jarak gazebo→platform pertama disamain sama step lain
local steps = {
	{ x = 0, dz = 8, dy = 0 },
	{ x = 5, dz = 8, dy = 1 },
	{ x = -5, dz = 8, dy = -1 },
	{ x = 0, dz = 8, dy = 2 },
	{ x = 5, dz = 8, dy = 0 },
}

local z = obbyStartZ
local y = SURF + 2
local lastMovingPlatform
for i, step in ipairs(steps) do
	z += step.dz
	y += step.dy
	local part = plank(step.x, y, z, 6, 1, 6, "Obby_" .. i)
	if i == 3 then
		-- platform ke-3 digerakin bolak-balik, ringan, bukan maut
		lastMovingPlatform = part
	end
end

-- Platform tujuan akhir (checkpoint), lebih gede + nyala.
local goal = plank(0, y, z + 10, 10, 1.2, 10, "ObbyGoal")
goal.Material = Enum.Material.Neon
goal.Color = Color3.fromRGB(80, 220, 140)

local bg = Instance.new("BillboardGui")
bg.Size = UDim2.new(0, 160, 0, 36)
bg.StudsOffset = V3(0, 4, 0)
bg.AlwaysOnTop = true
bg.Parent = goal

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = "Obby Selesai!"
label.Parent = bg

-- Platform gerak bolak-balik (ringan: jarak pendek, speed santai).
if lastMovingPlatform then
	local startCF = lastMovingPlatform.CFrame
	local endCF = startCF * CFrame.new(8, 0, 0)
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(lastMovingPlatform, tweenInfo, { CFrame = endCF })
	tween:Play()
end

workspace:SetAttribute("BF_DockObbyBuilt", true)
log("Dermaga + obby selesai. File > Save kalau udah oke.")
