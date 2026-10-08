-- Animasi masak tanpa aset animasi: tangan kanan karakter yang lagi goreng
-- (atribut "LagiGoreng" + "TitikWajan" dari FryService) digerakin manual lewat
-- Motor6D.Transform. Ngaduk minyak muter-muter, terus tiap siklus nyendok &
-- ngebalik tahu (sutil diputer, satu tahu loncat kebalik).
--
-- Transform nggak di-replikasi, jadi script ini (StarterPlayerScripts) ngitung
-- buat SEMUA player yang lagi goreng, bukan cuma diri sendiri.
--
-- Cara kerja tiap frame (IK 2 ruas):
--   1. tentuin titik ujung sutil (muter di minyak / naik pas balik tahu)
--   2. hukum cosinus -> seberapa siku ditekuk biar ujung sutil pas di titik itu
--   3. susun orientasi lengan atas & bawah, ubah jadi Transform di
--      RightShoulder / RightElbow / RightWrist
-- Diset di RunService.Stepped (abis Animator jalan), jadi cuma nimpa tangan
-- kanan; animasi duduk/idle bagian lain tetep jalan. Cuma buat avatar R15.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PERIODE = 1.6 -- detik per siklus (ngaduk -> balik tahu)
local MULAI_BALIK = 0.62 -- fase mulai nyendok
local JARI_ADUK = 0.35 -- radius puteran ujung sutil di minyak
local JARAK_MAKS = 9 -- kejauhan dari wajan (misal ditinggal jalan): nggak dianimasiin
local UJUNG_DEFAULT = Vector3.new(0, -1.3, -0.15) -- ujung sutil di ruang tangan (kalau Sutil belum kebaca)

local rigs = {} -- [character] = data rig + state animasi
local lagiDibalik = {} -- [tahu] = true selama animasi loncat

-- Ujung sutil di ruang RightHand, dihitung dari rantai weld (bukan posisi dunia,
-- biar nggak salah baca pas weld belum diproses fisika).
local function ujungSutil(character)
	local sutil = character:FindFirstChild("Sutil")
	local gagang = sutil and sutil:FindFirstChild("Gagang")
	local daun = sutil and sutil:FindFirstChild("Daun")
	local w1 = gagang and gagang:FindFirstChildWhichIsA("Weld")
	local w2 = daun and daun:FindFirstChildWhichIsA("Weld")
	local ujung = daun and daun:FindFirstChild("Ujung")
	if not (w1 and w2 and ujung) then
		return UJUNG_DEFAULT, sutil
	end
	return (w1.C0 * w1.C1:Inverse() * w2.C0 * w2.C1:Inverse()) * ujung.Position, sutil
end

local function ambilRig(character)
	local sutil = character:FindFirstChild("Sutil")
	local r = rigs[character]
	if r and r.sutil == sutil then
		return r
	end
	local torso = character:FindFirstChild("UpperTorso")
	local upper = character:FindFirstChild("RightUpperArm")
	local lower = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	local bahu = upper and upper:FindFirstChild("RightShoulder")
	local siku = lower and lower:FindFirstChild("RightElbow")
	local perg = hand and hand:FindFirstChild("RightWrist")
	if not (torso and bahu and siku and perg) then
		return nil -- R6 / karakter belum kebentuk
	end
	local ujung
	ujung, sutil = ujungSutil(character)
	local player = Players:GetPlayerFromCharacter(character)
	r = {
		torso = torso,
		bahu = bahu,
		siku = siku,
		perg = perg,
		sutil = sutil,
		-- Panjang ruas dari posisi sendi (ikut skala avatar).
		a = (siku.C0.Position - bahu.C1.Position).Magnitude,
		b = (perg.C0.Position - siku.C1.Position).Magnitude + (ujung - perg.C1.Position).Magnitude,
		-- Tiap player beda fase biar nggak gerak barengan kayak robot.
		offset = player and (player.UserId % 97) * 0.137 or 0,
		siklusDibalik = -1,
	}
	rigs[character] = r
	return r
end

local function lepas(character)
	local r = rigs[character]
	rigs[character] = nil
	if r then
		for _, motor in ipairs({ r.bahu, r.siku, r.perg }) do
			motor.Transform = CFrame.identity
		end
	end
end

-- Komponen v yang tegak lurus sumbu (unit), nil kalau v sejajar sumbu.
local function tegakLurus(v, sumbu)
	local p = v - sumbu * v:Dot(sumbu)
	return p.Magnitude > 1e-3 and p.Unit or nil
end

-- Orientasi ruas lengan: -Y = arah ruas (ke ujung), X = sumbu engsel siku.
local function orientasi(engsel, arah)
	return CFrame.fromMatrix(Vector3.zero, engsel, -arah, engsel:Cross(-arah))
end

local function gerakTangan(r, target, putar)
	local cfTorso = r.torso.CFrame
	local jBahu = cfTorso * r.bahu.C0
	local S = jBahu.Position
	local ke = target - S
	local jarak = ke.Magnitude
	if jarak < 1e-3 then
		return
	end
	local d = ke / jarak
	local a, b = r.a, r.b
	local c = math.clamp(jarak, math.abs(a - b) + 0.05, a + b - 0.05)
	local cosA = math.clamp((a * a + c * c - b * b) / (2 * a * c), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)

	-- Siku ngarah ke bawah, agak ke kanan & belakang badan.
	local kutub = cfTorso.RightVector * 0.6 - cfTorso.UpVector - cfTorso.LookVector * 0.2
	local p = tegakLurus(kutub, d) or tegakLurus(cfTorso.RightVector, d) or cfTorso.LookVector
	local u = d * cosA + p * sinA -- lengan atas (bahu -> siku)
	local siku = S + u * a
	local l = (S + d * c - siku).Unit -- lengan bawah (siku -> ujung sutil)
	local depan = tegakLurus(l, u) or tegakLurus(-p, u) or -p
	local engsel = u:Cross(depan)

	local rotAtas = orientasi(engsel, u)
	local rotBawah = orientasi(engsel, l)

	-- Part1 = J * Transform * C1^-1  ->  Transform = J.Rotation^-1 * rotTarget * C1.Rotation
	local bahu, sikuM, perg = r.bahu, r.siku, r.perg
	bahu.Transform = jBahu.Rotation:Inverse() * rotAtas * bahu.C1.Rotation
	local jSiku = jBahu * bahu.Transform * bahu.C1:Inverse() * sikuM.C0
	sikuM.Transform = jSiku.Rotation:Inverse() * rotBawah * sikuM.C1.Rotation
	local jPerg = jSiku * sikuM.Transform * sikuM.C1:Inverse() * perg.C0
	perg.Transform = jPerg.Rotation:Inverse() * (rotBawah * CFrame.Angles(0, putar, 0)) * perg.C1.Rotation
end

-- Satu tahu di wajan deket titik itu loncat & kebalik (lokal, cuma visual).
local function balikTahu(titik)
	for _, wok in ipairs(CollectionService:GetTagged("Wajan")) do
		local oil = wok:FindFirstChild("Minyak")
		local folder = wok:FindFirstChild("TahuDiWajan")
		if oil and folder and (oil.Position - titik).Magnitude < 3 then
			local list = {}
			for _, tahu in ipairs(folder:GetChildren()) do
				if tahu:IsA("BasePart") and not lagiDibalik[tahu] then
					table.insert(list, tahu)
				end
			end
			if #list == 0 then
				return
			end
			local tahu = list[math.random(#list)]
			local awal = tahu.CFrame
			local mulai = os.clock()
			local durasi = 0.4
			lagiDibalik[tahu] = true
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local k = math.min((os.clock() - mulai) / durasi, 1)
				if tahu.Parent == nil or k >= 1 then -- selesai, atau udah diangkat server
					conn:Disconnect()
					lagiDibalik[tahu] = nil
					if tahu.Parent then
						tahu.CFrame = awal * CFrame.Angles(math.pi, 0, 0)
					end
					return
				end
				local loncat = math.sin(k * math.pi) * 0.6
				tahu.CFrame = awal * CFrame.new(0, loncat, 0) * CFrame.Angles(math.pi * k, 0, 0)
			end)
			return
		end
	end
end

RunService.Stepped:Connect(function()
	local sekarang = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local titik = character:GetAttribute("TitikWajan")
			local r = character:GetAttribute("LagiGoreng") == true
				and typeof(titik) == "Vector3"
				and ambilRig(character)
			if r and (r.torso.Position - titik).Magnitude <= JARAK_MAKS then
				local waktu = sekarang + r.offset
				local fase = (waktu % PERIODE) / PERIODE
				local target, putar
				if fase < MULAI_BALIK then
					-- Ngaduk: ujung sutil muter pelan di permukaan minyak.
					local sudut = fase / MULAI_BALIK * math.pi * 2
					target = titik + Vector3.new(math.cos(sudut) * JARI_ADUK, 0.05, math.sin(sudut) * JARI_ADUK)
					putar = 0
				else
					-- Balik tahu: nyendok, angkat dikit sambil sutil diputer, turun lagi.
					local k = (fase - MULAI_BALIK) / (1 - MULAI_BALIK)
					target = titik + Vector3.new(JARI_ADUK, 0.05 + math.sin(k * math.pi) * 0.7, 0)
					putar = math.sin(k * math.pi) * math.pi * 0.9
					local siklus = math.floor(waktu / PERIODE)
					if k > 0.2 and r.siklusDibalik ~= siklus then
						r.siklusDibalik = siklus
						balikTahu(titik)
					end
				end
				gerakTangan(r, target, putar)
			elseif rigs[character] then
				lepas(character)
			end
		end
	end
	-- Bersihin karakter yang udah ilang (respawn / keluar).
	for character in pairs(rigs) do
		if character.Parent == nil then
			rigs[character] = nil
		end
	end
end)
