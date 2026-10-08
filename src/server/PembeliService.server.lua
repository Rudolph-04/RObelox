-- NPC warga pasar. Muncul di trotoar, masuk lewat gapura, jalan-jalan random
-- di pasar, kadang mutusin beli ke lapak yang lagi buka: antre, nunggu (bar
-- sabar di atas kepala), dilayani (FryService -> Antrean.serahkan), bayar,
-- terus lanjut jalan-jalan / pulang. Kalau kelamaan, kesel & pergi.
--
-- Catatan teknis (dari riset DevForum):
--   - Script "Animate" bawaan nggak jalan di NPC (LocalScript), jadi animasi
--     jalan/diem diputer sendiri di server lewat Animator. ID-nya diambil dari
--     Animate yang ikut kebikin, baru dibuang (fallback: PembeliConfig).
--   - Humanoid:MoveTo nyerah sendiri setelah ~8 detik, jadi MoveTo diulang
--     + dicek jarak & macet.
--   - Network owner NPC = server biar gerakannya nggak patah-patah.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PembeliConfig = require(ReplicatedStorage:WaitForChild("PembeliConfig"))
local Antrean = require(ServerScriptService:WaitForChild("Antrean"))

local C = PembeliConfig
local rng = Random.new()
local GRUP = "Warga"

pcall(function()
	PhysicsService:RegisterCollisionGroup(GRUP)
	PhysicsService:CollisionGroupSetCollidable(GRUP, GRUP, false) -- antar NPC nggak saling dorong di antrean
end)

local folder = Instance.new("Folder")
folder.Name = "Warga"
folder.Parent = workspace

local warga = {} -- list state NPC

local function pilih(list)
	return list[rng:NextInteger(1, #list)]
end

local function pilihTipe()
	local total = 0
	for _, t in ipairs(C.TIPE) do
		total += t.bobot
	end
	local r = rng:NextNumber() * total
	for _, t in ipairs(C.TIPE) do
		r -= t.bobot
		if r <= 0 then
			return t
		end
	end
	return C.TIPE[1]
end

local function titikAcak(area)
	return Vector3.new(rng:NextNumber(area.minX, area.maxX), area.y or C.AREA_JALAN.y, rng:NextNumber(area.minZ, area.maxZ))
end

local function titikGapura()
	return Vector3.new(rng:NextNumber(C.GAPURA.minX, C.GAPURA.maxX), C.AREA_JALAN.y, C.GAPURA.z)
end

local function titikTrotoar(x)
	return Vector3.new(x or rng:NextNumber(C.TROTOAR.minX, C.TROTOAR.maxX), C.TROTOAR.y, C.TROTOAR.z)
end

-- ── BIKIN NPC ──────────────────────────────────────────────────────
local function ambilAnim(animate, nama, fallback)
	local value = animate and animate:FindFirstChild(nama)
	local anim = value and value:FindFirstChildWhichIsA("Animation")
	return anim and anim.AnimationId ~= "" and anim.AnimationId or fallback
end

local function tempel(model, induk, part)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = induk
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

local function bikinGelembung(head)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Gelembung"
	bb.Size = UDim2.fromOffset(150, 46)
	bb.StudsOffset = Vector3.new(0, 2.3, 0)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	bb.Parent = head

	local kata = Instance.new("TextLabel")
	kata.Name = "Kata"
	kata.AnchorPoint = Vector2.new(0.5, 0)
	kata.Position = UDim2.fromScale(0.5, 0)
	kata.Size = UDim2.new(1, 0, 0, 28)
	kata.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	kata.TextColor3 = Color3.fromRGB(40, 35, 30)
	kata.Font = Enum.Font.FredokaOne
	kata.TextScaled = true
	kata.Visible = false
	kata.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = kata
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = kata

	local bar = Instance.new("Frame")
	bar.Name = "Sabar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 34)
	bar.Size = UDim2.new(0.6, 0, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bar.Visible = false
	bar.Parent = bb
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local isi = Instance.new("Frame")
	isi.Name = "Isi"
	isi.Size = UDim2.fromScale(1, 1)
	isi.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
	isi.Parent = bar
	Instance.new("UICorner", isi).CornerRadius = UDim.new(1, 0)
	return kata, bar, isi
end

local function bikinModel(tipe)
	local kulit = pilih(C.KULIT)
	local baju = pilih(tipe.baju)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = kulit
	desc.TorsoColor = baju
	local lengan = (tipe.id == "Ojol") and baju or kulit -- jaket = lengan panjang
	desc.LeftArmColor = lengan
	desc.RightArmColor = lengan
	local celana = pilih(tipe.celana)
	desc.LeftLegColor = celana
	desc.RightLegColor = celana

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
	end
	if not ok or not model then
		warn("[PembeliService] Gagal bikin NPC:", model)
		return nil
	end

	local animate = model:FindFirstChild("Animate")
	local animJalan = ambilAnim(animate, "walk", C.ANIM_JALAN)
	local animDiem = ambilAnim(animate, "idle", C.ANIM_DIEM)
	if animate then
		animate:Destroy()
	end

	model.Name = "Warga_" .. tipe.id
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = tipe.kecepatan
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false) -- nggak nyedot ke kursi orang

	local head = model:FindFirstChild("Head")
	if tipe.helm and head then
		local helm = Instance.new("Part")
		helm.Name = "Helm"
		helm.Shape = Enum.PartType.Ball
		helm.Size = Vector3.new(1.45, 1.45, 1.45)
		helm.Color = pilih(tipe.helm)
		helm.Material = Enum.Material.SmoothPlastic
		helm.CFrame = head.CFrame * CFrame.new(0, 0.2, 0.05)
		tempel(model, head, helm)
	end
	local torso = model:FindFirstChild("UpperTorso")
	if tipe.tas and torso then
		local tas = Instance.new("Part")
		tas.Name = "Tas"
		tas.Size = Vector3.new(1.2, 1.3, 0.5)
		tas.Color = pilih({ Color3.fromRGB(40, 70, 150), Color3.fromRGB(180, 50, 50), Color3.fromRGB(50, 50, 55) })
		tas.Material = Enum.Material.Fabric
		tas.CFrame = torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2 + 0.25) -- di punggung (+Z = belakang)
		tempel(model, torso, tas)
	end

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = GRUP
		end
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local function track(id, priority)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local t = animator:LoadAnimation(a)
		t.Priority = priority
		t.Looped = true
		return t
	end

	local kata, bar, isi = bikinGelembung(head)
	return {
		model = model,
		humanoid = humanoid,
		root = model:FindFirstChild("HumanoidRootPart"),
		tipe = tipe,
		hidup = true,
		jalan = track(animJalan, Enum.AnimationPriority.Movement),
		diem = track(animDiem, Enum.AnimationPriority.Idle),
		kata = kata,
		bar = bar,
		isi = isi,
		kataToken = 0,
	}
end

-- ── GERAK ──────────────────────────────────────────────────────────
local function jarakDatar(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Jalan ke target. true = nyampe. batal() opsional: true = berhenti.
local function jalanKe(npc, target, batal)
	local hum, root = npc.humanoid, npc.root
	hum:MoveTo(target)
	local dikirim, majuTerakhir, jarakTerbaik = os.clock(), os.clock(), math.huge
	while npc.hidup and root.Parent do
		task.wait(0.2)
		if batal and batal() then
			hum:MoveTo(root.Position)
			return false
		end
		local d = jarakDatar(root.Position, target)
		if d < 1.6 then
			return true
		end
		if d < jarakTerbaik - 0.3 then
			jarakTerbaik, majuTerakhir = d, os.clock()
		elseif os.clock() - majuTerakhir > 3 then
			return false -- macet
		end
		if os.clock() - dikirim > 6 then -- sebelum MoveTo nyerah sendiri (~8 detik)
			hum:MoveTo(target)
			dikirim = os.clock()
		end
	end
	return false
end

local function hadap(npc, cf)
	if npc.root.Parent then
		npc.root.CFrame = CFrame.new(npc.root.Position) * cf.Rotation
	end
end

-- ── GELEMBUNG KATA & BAR SABAR ─────────────────────────────────────
local function ngomong(npc, teks, detik)
	npc.kataToken += 1
	local token = npc.kataToken
	npc.kata.Text = teks
	npc.kata.Visible = true
	task.delay(detik or 2.5, function()
		if npc.kataToken == token then
			npc.kata.Visible = false
		end
	end)
end

local function setSabar(npc, sisa)
	npc.bar.Visible = sisa ~= nil
	if sisa then
		npc.isi.Size = UDim2.fromScale(math.clamp(sisa, 0, 1), 1)
		local hijau, kuning, merah = Color3.fromRGB(90, 200, 90), Color3.fromRGB(240, 200, 60), Color3.fromRGB(220, 60, 50)
		npc.isi.BackgroundColor3 = sisa > 0.5 and kuning:Lerp(hijau, (sisa - 0.5) * 2) or merah:Lerp(kuning, sisa * 2)
	end
end

-- ── BELI ───────────────────────────────────────────────────────────
local function beli(npc, lapak)
	if not Antrean.gabung(lapak, npc) then
		return
	end
	npc.siap = false
	npc.kualitas = {}
	npc.sisaPorsi = rng:NextInteger(npc.tipe.porsi[1], npc.tipe.porsi[2])
	local porsiAwal = npc.sisaPorsi
	local function lepas()
		return npc.lapak ~= lapak
	end

	jalanKe(npc, Antrean.titikMasuk(lapak), lepas)

	local mulaiSabar
	local hasil = "kesel"
	while npc.hidup and npc.lapak == lapak do
		local i = Antrean.posisi(lapak, npc)
		if not i then
			break
		end
		local slot = Antrean.slot(lapak, i)
		if jarakDatar(npc.root.Position, slot.Position) > 1.6 then
			jalanKe(npc, slot.Position, function()
				return lepas() or Antrean.posisi(lapak, npc) ~= i
			end)
		else
			hadap(npc, slot)
			mulaiSabar = mulaiSabar or os.clock()
			if i == 1 and not npc.siap then
				npc.siap = true
				ngomong(npc, pilih(C.KATA.pesan):format(porsiAwal), 3)
			end
		end

		if npc.siap then
			Antrean.beliDariStok(lapak, npc)
		end
		if npc.sisaPorsi <= 0 then
			hasil = "puas"
			break
		end
		if mulaiSabar then
			local sisa = 1 - (os.clock() - mulaiSabar) / npc.tipe.sabar
			setSabar(npc, sisa)
			if sisa <= 0 then
				break
			end
		end
		task.wait(0.25)
	end

	Antrean.keluar(lapak, npc)
	npc.siap = false
	setSabar(npc, nil)
	if hasil == "puas" then
		local gosong = table.find(npc.kualitas, "Gosong") ~= nil
		ngomong(npc, pilih(gosong and C.KATA.gosong or C.KATA.puas))
	elseif mulaiSabar then
		ngomong(npc, pilih(C.KATA.kesel))
	end
end

-- Lapak terbuka terdekat yang antreannya belum penuh.
local function lapakMenarik(npc)
	local best, bestD
	for _, lapak in ipairs(Antrean.lapakTerbuka()) do
		local d = jarakDatar(npc.root.Position, lapak:GetPivot().Position)
		if d <= C.JARAK_TERTARIK and Antrean.jumlah(lapak) < C.MAX_ANTRE and (not best or d < bestD) then
			best, bestD = lapak, d
		end
	end
	return best
end

-- ── SIKLUS HIDUP NPC ───────────────────────────────────────────────
local function hapus(npc)
	npc.hidup = false
	if npc.lapak then
		Antrean.keluar(npc.lapak, npc)
	end
	local i = table.find(warga, npc)
	if i then
		table.remove(warga, i)
	end
	if npc.model.Parent then
		npc.model:Destroy()
	end
end

local function hidupkan(npc)
	local putaran = rng:NextInteger(C.PUTARAN_SEBELUM_PULANG[1], C.PUTARAN_SEBELUM_PULANG[2])
	local sudahBeli = false
	jalanKe(npc, titikGapura())
	for _ = 1, putaran do
		if not npc.hidup then
			return
		end
		jalanKe(npc, titikAcak(C.AREA_JALAN))
		task.wait(rng:NextNumber(1, 4)) -- berhenti liat-liat
		if not sudahBeli and rng:NextNumber() < C.PELUANG_BELI then
			local lapak = lapakMenarik(npc)
			if lapak then
				sudahBeli = true
				beli(npc, lapak)
				task.wait(1)
			end
		end
	end
	-- Pulang: keluar gapura, jalan di trotoar, ilang.
	jalanKe(npc, titikGapura())
	local kanan = rng:NextNumber() < 0.5
	jalanKe(npc, titikTrotoar(kanan and 25 or -25))
	jalanKe(npc, titikTrotoar(kanan and C.TROTOAR.maxX + 10 or C.TROTOAR.minX - 10))
	hapus(npc)
end

local function spawnWarga()
	local npc = bikinModel(pilihTipe())
	if not npc then
		return
	end
	local mulai = titikTrotoar()
	npc.model:PivotTo(CFrame.new(mulai + Vector3.new(0, 3, 0)))
	npc.model.Parent = folder
	pcall(function()
		npc.root:SetNetworkOwner(nil)
	end)
	npc.humanoid.Died:Connect(function()
		task.delay(2, function()
			hapus(npc)
		end)
	end)
	table.insert(warga, npc)
	task.spawn(function()
		local ok, err = pcall(hidupkan, npc)
		if not ok then
			warn("[PembeliService]", err)
		end
		if npc.hidup then
			hapus(npc)
		end
	end)
end

-- Animasi jalan/diem ngikutin kecepatan beneran (apa pun yang bikin dia gerak).
task.spawn(function()
	while true do
		task.wait(0.15)
		for _, npc in ipairs(warga) do
			if npc.hidup and npc.root.Parent then
				local v = npc.root.AssemblyLinearVelocity
				local gerak = Vector3.new(v.X, 0, v.Z).Magnitude > 0.6
				if gerak and not npc.jalan.IsPlaying then
					npc.diem:Stop(0.2)
					npc.jalan:Play(0.2)
				elseif not gerak and not npc.diem.IsPlaying then
					npc.jalan:Stop(0.2)
					npc.diem:Play(0.2)
				end
			end
		end
	end
end)

-- Jaga jumlah warga (cuma kalau ada player di server).
while true do
	task.wait(rng:NextNumber(2, 4))
	if #Players:GetPlayers() > 0 and #warga < C.MAX_WARGA then
		spawnWarga()
	end
end
