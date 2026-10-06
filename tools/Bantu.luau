--[[
	Bantu — helper bareng buat semua builder di tools/ (bikin part, silinder,
	CSG, tulisan). Semua fungsi nerima CFrame dunia; tiap builder bikin
	fungsi L(x, y, z) sendiri buat ngubah posisi lokal -> CFrame dunia.
]]

local Bantu = {}

local V3 = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

-- Silinder di Roblox sumbunya X. Dikali ke CFrame biar sumbunya:
Bantu.UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- ke atas (Y)
Bantu.ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- ke depan-belakang (Z)

Bantu.WARNA = {
	KAYU = RGB(150, 100, 55),
	KAYU_GELAP = RGB(110, 72, 40),
	KRIM = RGB(250, 240, 215),
	BESI = RGB(70, 72, 78),
	KROM = RGB(205, 205, 210),
	BAN = RGB(28, 28, 30),
	RANGKA = RGB(40, 40, 45),
	MERAH = RGB(205, 50, 45),
	PUTIH = RGB(245, 240, 230),
}

function Bantu.box(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

function Bantu.cylinder(parent, name, length, diameter, cf, color, material, props)
	local p = Bantu.box(parent, name, V3(length, diameter, diameter), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Bantu.ball(parent, name, diameter, cf, color, material, props)
	local p = Bantu.box(parent, name, V3(diameter, diameter, diameter), cf, color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Batang dari titik a ke titik b (posisi dunia).
function Bantu.rod(parent, name, a, b, thickness, color, material)
	local cf = CFrame.lookAt((a + b) / 2, b)
	return Bantu.box(parent, name, V3(thickness, thickness, (b - a).Magnitude), cf, color, material)
end

-- Pipa bulat (silinder) dari titik a ke titik b (posisi dunia).
function Bantu.tube(parent, name, a, b, diameter, color, material, props)
	local mid = (a + b) / 2
	local dir = (b - a).Unit
	local up = math.abs(dir.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
	local cf = CFrame.lookAt(mid, b, up) * Bantu.ALONG_Z -- sumbu silinder (X) -> arah a ke b
	return Bantu.cylinder(parent, name, (b - a).Magnitude, diameter, cf, color, material, props)
end

-- Bola lonjong (elips 3D), ukurannya = size. Buat bentuk bulet kayak tangki.
function Bantu.ellipsoid(parent, name, size, cf, color, material, props)
	local p = Bantu.box(parent, name, size, cf, color, material, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- CSG: `main` dikurangi `cutters` -> satu part baru di `parent`.
-- CSG butuh part-nya ada di DataModel, jadi sementara ditaro di workspace.
function Bantu.carve(parent, name, main, cutters, color, material)
	main.Parent = workspace
	for _, c in ipairs(cutters) do
		c.Parent = workspace
	end
	local u = main:SubtractAsync(cutters, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	main:Destroy()
	for _, c in ipairs(cutters) do
		c:Destroy()
	end
	u.Name = name
	u.Anchored = true
	u.UsePartColor = true
	u.Color = color
	u.Material = material
	u.Parent = parent
	return u
end

function Bantu.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Tulisan di satu sisi part. bgColor nil = latar transparan.
function Bantu.surfaceText(part, face, text, textColor, bgColor, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 50
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bgColor or RGB(0, 0, 0)
	label.BackgroundTransparency = bgColor and 0 or 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = textColor
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	return gui
end

return Bantu
