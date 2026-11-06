-- Efek visual di client (ModuleScript di StarterPlayerScripts, dipake LaskarClient).
-- Semua cuma tampilan lokal: server ngirim "Efek" ke semua client, tiap client
-- gambar sendiri. Jadi server nggak perlu bikin/ngapus part kecil-kecil.
--
--   angka(pos, nilai, crit, kenaPasukan)  angka damage melayang
--   panah(dari, ke, durasi)              anak panah melengkung
--   mati(pos)                            kepulan debu
--   ayun(character)                      avatar ngayun golok lewat Motor6D.Transform,
--                                        diset di Stepped biar nimpa animasi bawaan.
--                                        Cuma avatar R15.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Efek = {}

local folder = Instance.new("Folder")
folder.Name = "EfekLokal"
folder.Parent = workspace

local function partEfek(size, cf, warna, bentuk)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = warna
	p.Material = Enum.Material.SmoothPlastic
	if bentuk then
		p.Shape = bentuk
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

function Efek.angka(pos, nilai, crit, kenaPasukan)
	local jangkar = partEfek(Vector3.new(0.1, 0.1, 0.1), CFrame.new(pos + Vector3.new(0, 2.2, 0)), Color3.new(1, 1, 1))
	jangkar.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(80, 30)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 150
	bb.Parent = jangkar
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextSize = crit and 26 or 18
	t.Text = tostring(nilai) .. (crit and "!" or "")
	t.TextColor3 = kenaPasukan and Color3.fromRGB(255, 110, 100) or (crit and Color3.fromRGB(255, 205, 90) or Color3.fromRGB(250, 250, 250))
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffset = Vector3.new(0, 1.6, 0) }):Play()
	TweenService:Create(t, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(jangkar, 0.8)
end

function Efek.panah(dari, ke, durasi)
	local p = partEfek(Vector3.new(0.08, 0.08, 1.3), CFrame.new(dari), Color3.fromRGB(110, 76, 46))
	local tinggi = math.min(4, (ke - dari).Magnitude * 0.15)
	local mulai = os.clock()
	local function titik(k)
		return dari:Lerp(ke, k) + Vector3.new(0, math.sin(k * math.pi) * tinggi, 0)
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - mulai) / durasi
		if k >= 1 then
			conn:Disconnect()
			p:Destroy()
			return
		end
		local a, b = titik(k), titik(math.min(k + 0.05, 1))
		if (b - a).Magnitude > 1e-3 then
			p.CFrame = CFrame.lookAt(a, b)
		end
	end)
end

function Efek.mati(pos)
	for i = 1, 7 do
		local sudut = i / 7 * math.pi * 2
		local arah = Vector3.new(math.cos(sudut), 0.6, math.sin(sudut))
		local p = partEfek(Vector3.new(0.7, 0.7, 0.7), CFrame.new(pos), Color3.fromRGB(200, 190, 175), Enum.PartType.Ball)
		p.Transparency = 0.2
		TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(pos + arah * 1.8),
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1,
		}):Play()
		Debris:AddItem(p, 0.5)
	end
end

-- ── GERAK TANGAN ───────────────────────────────────────────────────
local gerakan = {} -- [character] = { jenis, mulai }
local DURASI = { ayun = 0.38 }

function Efek.ayun(character)
	if character then
		gerakan[character] = { jenis = "ayun", mulai = os.clock() }
	end
end

local function motor(character, bagian, nama)
	local p = character:FindFirstChild(bagian)
	local m = p and p:FindFirstChild(nama)
	return m and m:IsA("Motor6D") and m or nil
end

-- R15: putar bahu di sumbu X positif = lengan keangkat ke depan.
RunService.Stepped:Connect(function()
	local sekarang = os.clock()
	for character, g in pairs(gerakan) do
		local kanan = motor(character, "RightUpperArm", "RightShoulder")
		local kiri = motor(character, "LeftUpperArm", "LeftShoulder")
		local k = (sekarang - g.mulai) / DURASI[g.jenis]
		if k >= 1 or character.Parent == nil then
			gerakan[character] = nil
			for _, m in ipairs({ kanan, kiri }) do
				if m then
					m.Transform = CFrame.identity
				end
			end
		elseif kanan then
			-- Golok: ancang-ancang ke atas, terus bacok ke depan-bawah.
			local sudut
			if k < 0.45 then
				sudut = 0.3 + (2.7 - 0.3) * (k / 0.45)
			else
				sudut = 2.7 + (0.5 - 2.7) * ((k - 0.45) / 0.55)
			end
			kanan.Transform = CFrame.Angles(sudut, 0, 0)
		end
	end
end)

return Efek
