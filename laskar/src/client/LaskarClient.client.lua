-- Client prototipe Laskar Kendang (LocalScript di StarterPlayerScripts).
--
-- Tugas:
--   1. Nilai timing pukulan kendang (di client, soalnya ping bikin server
--      nggak bisa nilai adil). Selisih ke ketukan terdekat: <= JENDELA_PERFECT
--      = PERFECT, <= JENDELA_BAGUS = BAGUS, lebih = MELESET.
--   2. Rangkai 4 pukulan di 4 ketukan berturut-turut -> cocokkan ke perintah
--      -> kirim ke server. Abis itu 4 ketukan "jawaban" pasukan: mukul di situ
--      = KACAU (kombo putus). Perintah berikutnya harus mulai pas di ketukan
--      sesudahnya biar kombo nyambung.
--   3. Kamera samping, avatar (panglima) jalan sendiri ngikutin pasukan
--      (kontrol jalan dimatiin), suara kendang/metronom/musik, UI, efek.
--
-- Tombol: D F J K = kendang, H = daftar perintah, C = ganti kamera,
-- [ ] = kalibrasi (kalau pukulan selalu kerasa telat/kecepetan).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local C = require(ReplicatedStorage:WaitForChild("LaskarConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("LaskarRemotes"))
local UI = require(script.Parent:WaitForChild("LaskarUI"))
local Efek = require(script.Parent:WaitForChild("LaskarEfek"))

local pemain = Players.LocalPlayer
local kamera = workspace.CurrentCamera
local K = C.KETUKAN
local EMAS = Color3.fromRGB(255, 205, 90)
local PUTIH = Color3.fromRGB(245, 245, 245)
local MERAH = Color3.fromRGB(255, 110, 100)

local MULAI = ReplicatedStorage:GetAttribute("MulaiKetukan")
while not MULAI do
	ReplicatedStorage:GetAttributeChangedSignal("MulaiKetukan"):Wait()
	MULAI = ReplicatedStorage:GetAttribute("MulaiKetukan")
end

-- ── KONTROL JALAN DIMATIIN (panglima gerak ngikutin perintah) ──────
local function matiinKontrol()
	local ok, PlayerModule = pcall(function()
		return require(pemain:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and PlayerModule then
		PlayerModule:GetControls():Disable()
	end
end
task.spawn(matiinKontrol)
pemain.CharacterAdded:Connect(function()
	task.defer(matiinKontrol)
end)

-- ── SUARA ──────────────────────────────────────────────────────────
local function bikinSuara(id, volume)
	if not id or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	return s
end
local suaraDrum = {}
for _, d in ipairs(C.DRUM) do
	suaraDrum[d.id] = bikinSuara(C.SUARA[d.id], 0.9)
end
local suaraTik = bikinSuara(C.SUARA.TIK, 0.3)
local musik = bikinSuara(C.SUARA.MUSIK, 0.45)
if musik then
	musik.Looped = true
end

local function bunyi(s)
	if s then
		s.TimePosition = 0
		s:Play()
	end
end

-- Musik latar dijaga pas sama jam ketukan (dicek tiap detik).
task.spawn(function()
	local panjang = C.MUSIK_KETUKAN * K
	while musik do
		if musik.IsLoaded then
			local seharusnya = (workspace:GetServerTimeNow() - MULAI) % panjang
			local beda = math.abs(musik.TimePosition - seharusnya)
			if not musik.IsPlaying then
				musik.TimePosition = seharusnya
				musik:Play()
			elseif beda > 0.06 and beda < panjang - 0.06 then
				musik.TimePosition = seharusnya
			end
		end
		task.wait(1)
	end
end)

-- ── STATE RITME ────────────────────────────────────────────────────
local kalibrasiMs = 0
local urutan, ketukanUrutan, skor = {}, {}, 0
local jawabSampai = -math.huge -- ketukan terakhir fase jawaban pasukan
local harusMulai = nil -- ketukan pukulan pertama perintah berikutnya biar kombo nyambung
local kombo = 0 -- dari server
local lagiJawab = false

-- Posisi sekarang dalam satuan ketukan (pecahan). Buat nilai pukulan, waktu
-- dikurangin kalibrasi (telinga/layar telat -> pukulan juga telat segitu).
local function posisiKetukan(pakaiKalibrasi)
	local t = workspace:GetServerTimeNow()
	if pakaiKalibrasi then
		t -= kalibrasiMs / 1000
	end
	return (t - MULAI) / K
end

local ui -- diisi di bawah

local function resetUrutan()
	urutan, ketukanUrutan, skor = {}, {}, 0
	ui.kosongkanSlot()
end

local function putusKombo()
	harusMulai = nil
	if kombo > 0 then
		Remotes.Perintah:FireServer("Putus")
	end
end

local function pukul(id)
	local d = C.drum(id)
	if not d then
		return
	end
	bunyi(suaraDrum[id])
	ui.pukul(id)
	Efek.pukul(pemain.Character)

	local posisi = posisiKetukan(true)
	local n = math.floor(posisi + 0.5)
	local selisih = math.abs(posisi - n) * K

	if n <= jawabSampai then
		ui.nilai("KACAU", MERAH) -- mukul pas pasukan lagi jawab
		resetUrutan()
		putusKombo()
		return
	end
	if selisih > C.JENDELA_BAGUS then
		ui.nilai("MELESET", MERAH)
		resetUrutan()
		putusKombo()
		return
	end
	local sebelum = ketukanUrutan[#ketukanUrutan]
	if sebelum and n == sebelum then
		ui.nilai("KEDOBELAN", MERAH) -- 2x mukul di 1 ketukan
		resetUrutan()
		putusKombo()
		return
	end
	if sebelum and n ~= sebelum + 1 then
		resetUrutan() -- ada ketukan kelewat: pukulan ini jadi awal urutan baru
		putusKombo()
	end

	table.insert(urutan, id)
	table.insert(ketukanUrutan, n)
	local perfect = selisih <= C.JENDELA_PERFECT
	skor += perfect and 1 or 0.6
	ui.isiSlot(#urutan, id)
	ui.nilai(perfect and "PERFECT" or "BAGUS", perfect and EMAS or PUTIH)

	if #urutan == 4 then
		local p = C.cocokkan(urutan)
		if p then
			-- Server sendiri yang ngitung kombo dari ketukan (nyambung = pas 8 ketukan setelah yang lalu).
			Remotes.Perintah:FireServer(p.id, n, skor / 4)
			jawabSampai = n + 4
			harusMulai = n + 5
			lagiJawab = true
			ui.jawaban(p.teks)
		else
			ui.nilai("??", MERAH)
			putusKombo()
		end
		resetUrutan()
	end
end

local function ubahKalibrasi(ms)
	kalibrasiMs = math.clamp(kalibrasiMs + ms, -200, 300)
	ui.kalibrasi(kalibrasiMs)
	ui.pesan(("Kalibrasi %+d ms (plus = pukulan lu dianggap lebih awal)"):format(kalibrasiMs), 2)
end

-- ── KAMERA ─────────────────────────────────────────────────────────
local kameraSamping = true
local fokusX = nil

local function gantiKamera()
	kameraSamping = not kameraSamping
	if not kameraSamping then
		kamera.CameraType = Enum.CameraType.Custom
		kamera.FieldOfView = 70
	end
end

ui = UI.buat(pemain, pukul, ubahKalibrasi, gantiKamera)
ui.pesan("Pukul kendang (D F J K) pas ketukan. Daftar perintah di kanan atas.", 6)

local function modelPasukan()
	local folder = workspace:FindFirstChild("Pasukan")
	return folder and folder:FindFirstChild("Pasukan_" .. pemain.UserId)
end

RunService:BindToRenderStep("LaskarKamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not kameraSamping then
		return
	end
	local character = pemain.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local model = modelPasukan()
	local x = root and root.Position.X or (model and model:GetAttribute("PanglimaX")) or C.ARENA.mulaiX
	local target = x + C.KAMERA.lihatDepan
	fokusX = fokusX and fokusX + (target - fokusX) * math.min(1, dt * 4) or target
	kamera.CameraType = Enum.CameraType.Scriptable
	kamera.FieldOfView = C.KAMERA.fov
	local lihat = Vector3.new(fokusX, C.ARENA.tanahY + 3, 0)
	kamera.CFrame = CFrame.lookAt(lihat + Vector3.new(0, C.KAMERA.tinggi - 3, C.KAMERA.jarak), lihat)
end)

-- ── PANGLIMA NGIKUTIN PASUKAN ──────────────────────────────────────
local targetTerakhir, waktuMoveTo = nil, 0

local function ikutiPasukan()
	local model = modelPasukan()
	local character = pemain.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (model and hum and root) or hum.Health <= 0 then
		return
	end
	local x, z = model:GetAttribute("PanglimaX"), model:GetAttribute("LaneZ")
	if not x or not z then
		return
	end
	local pos = root.Position
	local jauh = Vector3.new(x - pos.X, 0, z - pos.Z).Magnitude
	if jauh > 0.6 then
		if x ~= targetTerakhir or os.clock() - waktuMoveTo > 1 then
			hum:MoveTo(Vector3.new(x, pos.Y, z))
			targetTerakhir, waktuMoveTo = x, os.clock()
		end
	elseif root.CFrame.LookVector.X < 0.97 then
		root.CFrame = CFrame.lookAt(pos, pos + Vector3.xAxis) -- udah nyampe: ngadep musuh lagi
	end
end

-- ── LOOP PER FRAME ─────────────────────────────────────────────────
local ketukanTampil = math.floor(posisiKetukan(false))

RunService.RenderStepped:Connect(function()
	local n = math.floor(posisiKetukan(false))
	if n ~= ketukanTampil then
		ketukanTampil = n
		local jawab = n <= jawabSampai
		ui.denyut(jawab and "jawab" or "input")
		if not musik then
			bunyi(suaraTik)
		end
		if lagiJawab and not jawab then
			lagiJawab = false
			ui.jawaban(nil)
		end
	end

	local posisi = posisiKetukan(true)
	local batas = C.JENDELA_BAGUS / K
	-- Urutan setengah jalan tapi ketukan berikutnya kelewat.
	local sebelum = ketukanUrutan[#ketukanUrutan]
	if sebelum and posisi > sebelum + 1 + batas then
		resetUrutan()
		ui.nilai("TERPUTUS", MERAH)
		putusKombo()
	end
	-- Nggak mulai perintah berikutnya tepat waktu: kombo putus.
	if harusMulai and posisi > harusMulai + batas and ketukanUrutan[1] ~= harusMulai then
		putusKombo()
	end

	ikutiPasukan()
end)

-- ── INPUT ──────────────────────────────────────────────────────────
local petaTombol = {}
for _, d in ipairs(C.DRUM) do
	petaTombol[d.tombol] = d.id
	petaTombol[d.pad] = d.id
end

UserInputService.InputBegan:Connect(function(input, diproses)
	if diproses then
		return -- lagi ngetik di chat, dll
	end
	local id = petaTombol[input.KeyCode]
	if id then
		pukul(id)
	elseif input.KeyCode == Enum.KeyCode.H then
		ui.toggleBantuan()
	elseif input.KeyCode == Enum.KeyCode.C then
		gantiKamera()
	elseif input.KeyCode == Enum.KeyCode.LeftBracket then
		ubahKalibrasi(-10)
	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		ubahKalibrasi(10)
	end
end)

-- ── DARI SERVER ────────────────────────────────────────────────────
Remotes.Umpan.OnClientEvent:Connect(function(info)
	if info.jenis == "kombo" then
		kombo = info.kombo
		ui.kombo(info.kombo, info.semangat)
	elseif info.jenis == "menang" then
		local detik = math.floor(info.waktu)
		ui.banner("MENANG!", ("Waktu %d:%02d  ·  Kombo tertinggi %d"):format(detik // 60, detik % 60, info.komboMaks), C.JEDA_ULANG_STAGE - 1)
	elseif info.jenis == "pesan" then
		ui.pesan(info.teks, 4)
	end
end)

Remotes.Efek.OnClientEvent:Connect(function(jenis, a, b, c, d)
	if jenis == "angka" then
		Efek.angka(a, b, c, d)
	elseif jenis == "panah" then
		Efek.panah(a, b, c)
	elseif jenis == "mati" then
		Efek.mati(a)
	elseif jenis == "ayun" then
		local p = Players:GetPlayerByUserId(a)
		if p then
			Efek.ayun(p.Character)
		end
	end
end)
