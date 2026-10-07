-- Nyetir kendaraan dagangan (client).
--
-- Pas player duduk di Kemudi kendaraannya, server (KendaraanService) ngasih
-- network ownership ke client ini, jadi gerakannya langsung diatur dari sini
-- tiap frame lewat constraint di Chassis:
--   Gerak (LinearVelocity)   -> kecepatan maju/mundur
--   Arah  (AlignOrientation) -> arah hadap; sekalian bikin kendaraan selalu tegak
-- Input dibaca langsung dari arah gerak kontrol bawaan (PlayerModule
-- GetMoveVector: WASD/panah, stik gamepad, thumbstick HP). VehicleController
-- bawaan Roblox kadang nggak nyala pas duduk (ThrottleFloat diem di 0 padahal
-- tombol dipencet), jadi ThrottleFloat/SteerFloat jok cuma cadangan (trigger
-- gamepad), dan nilai akhirnya ditulis balik ke jok biar animasi setir
-- keliatan di player lain. Angka-angkanya per kendaraan di KendaraanConfig.
--
-- Selain itu (cuma tampilan, buat semua kendaraan, tiap client sendiri-sendiri):
--   - roda muter + setir belok
--   - tangan pengendara megang stang (IKControl ke attachment Pegangan*)
--   - panel samping box & pintu belakang kebuka/ketutup (TweenService)
--     ngikutin atribut "LapakBuka" dari server, piston penyangganya ikut nyesuaiin
--   - prompt di kendaraan punya orang lain disembunyiin
--   - petunjuk kecil di atas layar (cara nyetir / harus parkir di titik jualan)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local KendaraanConfig = require(ReplicatedStorage:WaitForChild("KendaraanConfig"))

local player = Players.LocalPlayer
local kendaraanFolder = workspace:WaitForChild("Kendaraan")

local HINT_RANGE = 14 -- jarak ke kendaraan sendiri buat nampilin petunjuk parkir
local MAX_YAW_LEAD = 0.5 -- rad; target arah nggak boleh kabur jauh pas mentok tembok
-- Di bawah ini (stud/detik) kendaraan dianggep berhenti. Abis diem/di-anchor,
-- fisika suka nyisain kecepatan seuprit (misal +0.00001 ke depan); tanpa batas
-- ini, pencet mundur dianggep "rem dulu" terus selamanya & kendaraan nggak gerak.
local STOPPED_SPEED = 0.3
local PANEL_TIME = 1.2 -- detik buka/tutup panel penuh
local ALONG_X = CFrame.Angles(0, math.rad(90), 0) -- sumbu X silinder -> arah LookVector

local function statsOf(model)
	return KendaraanConfig.get(model:GetAttribute("Kendaraan")) or KendaraanConfig.DAFTAR[1]
end

local function yawOf(cf)
	local _, yaw = cf:ToOrientation()
	return yaw
end

local function angleDiff(a, b)
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

-- ── NYETIR ─────────────────────────────────────────────────────────
local driving = nil -- { model, chassis, stats, yaw }

local function getMyDrivingSeat()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "Kemudi" and seat:IsDescendantOf(kendaraanFolder) then
		return seat
	end
	return nil
end

-- Abis turun: nolin target lokal (nilai yang diset client nggak ke-replicate,
-- jadi kalau nggak dinolin bisa kebawa lagi pas naik berikutnya).
local function release(state)
	local gerak = state.chassis:FindFirstChild("Gerak")
	local arah = state.chassis:FindFirstChild("Arah")
	if gerak then
		gerak.PlaneVelocity = Vector2.zero
	end
	if arah then
		arah.CFrame = CFrame.fromOrientation(0, yawOf(state.chassis.CFrame), 0)
	end
end

local function approachZero(value, amount)
	if math.abs(value) <= amount then
		return 0
	end
	return value - math.sign(value) * amount
end

-- Kontrol bawaan (PlayerModule) buat baca arah gerak; di-require pas pertama
-- dibutuhin (PlayerModule bisa belum ada pas script ini mulai).
local controls = nil

local function readInput(seat)
	if not controls then
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			controls = require(module):GetControls()
		end
	end
	local move = controls and controls:GetMoveVector() or Vector3.zero
	-- WASD/stik: maju = -Z, kanan = +X. Kalau diem, pake nilai jok (trigger gamepad).
	local throttle = move.Z ~= 0 and math.clamp(-move.Z, -1, 1) or seat.ThrottleFloat
	local steer = move.X ~= 0 and math.clamp(move.X, -1, 1) or seat.SteerFloat
	return throttle, steer
end

local function drive(seat, state, dt)
	local chassis, stats = state.chassis, state.stats
	local gerak = chassis:FindFirstChild("Gerak")
	local arah = chassis:FindFirstChild("Arah")
	if not (gerak and arah) then
		return
	end
	local look = chassis.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		return
	end
	forward = forward.Unit

	-- Mulai dari kecepatan beneran (kalau nabrak, kecepatannya ikut turun).
	local speed = chassis.AssemblyLinearVelocity:Dot(forward)
	local throttle, steer = readInput(seat)
	-- Tulis balik ke jok: animasi setir di semua client baca SteerFloat.
	seat.ThrottleFloat = throttle
	seat.SteerFloat = steer
	if throttle > 0 then
		if speed < -STOPPED_SPEED then
			speed = math.min(speed + stats.brake * dt, 0) -- lagi mundur: rem dulu
		else
			speed = math.min(math.max(speed, 0) + stats.accel * throttle * dt, stats.maxSpeed)
		end
	elseif throttle < 0 then
		if speed > STOPPED_SPEED then
			speed = math.max(speed - stats.brake * dt, 0) -- lagi maju: rem dulu
		else
			speed = math.max(math.min(speed, 0) + stats.accel * throttle * dt, -stats.maxReverse)
		end
	else
		speed = approachZero(speed, stats.coastDrag * dt)
	end

	-- Belok cuma kalau jalan; pas mundur arahnya kebalik (kayak kendaraan beneran).
	local grip = math.clamp(math.abs(speed) / stats.turnFullSpeed, 0, 1)
	local direction = speed >= 0 and 1 or -1
	state.yaw -= steer * stats.turnRate * grip * direction * dt
	local actualYaw = yawOf(chassis.CFrame)
	local lead = angleDiff(state.yaw, actualYaw)
	if math.abs(lead) > MAX_YAW_LEAD then
		state.yaw = actualYaw + math.sign(lead) * MAX_YAW_LEAD
	end

	local velocity = forward * speed
	gerak.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	arah.CFrame = CFrame.fromOrientation(0, state.yaw, 0)
end

RunService.Heartbeat:Connect(function(dt)
	local seat = getMyDrivingSeat()
	local model = seat and seat.Parent
	if model ~= (driving and driving.model) then
		if driving then
			release(driving)
		end
		driving = nil
		if model and model.PrimaryPart then
			driving = {
				model = model,
				chassis = model.PrimaryPart,
				stats = statsOf(model),
				yaw = yawOf(model.PrimaryPart.CFrame),
			}
		end
	end
	if driving and driving.chassis:IsDescendantOf(workspace) and not driving.chassis.Anchored then
		drive(seat, driving, dt)
	end
end)

-- ── ANIMASI (semua kendaraan): RODA, SETIR, TANGAN, PANEL ──────────
-- Tabel biasa (bukan weak): Instance yang dijadiin key weak table bisa
-- "ilang" sendiri pas wrapper Lua-nya ke-GC, terus rig-nya kebikin ulang
-- (panel loncat ketutup, IK tangan dobel). Dibersihin di ChildRemoved.
local rigs = {}

local function getRig(model)
	local rig = rigs[model]
	if rig then
		return rig
	end
	local chassis = model.PrimaryPart
	rig = {
		wheels = {},
		steer = nil,
		seat = model:FindFirstChild("Kemudi"),
		stats = statsOf(model),
		spin = 0,
		steerAngle = 0,
		hands = {}, -- IKControl yang lagi kepasang
		handsFor = nil, -- Humanoid pemiliknya
		engsel = nil, -- Motor6D panel samping
		pistons = {},
		openAngle = model:GetAttribute("SudutBuka") or 0,
		doors = {}, -- Motor6D pintu belakang + arah putarnya
		doorAngle = model:GetAttribute("SudutPintu") or 0,
		sudut = Instance.new("NumberValue"), -- sudut panel sekarang (di-tween)
	}
	local pistonMotors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			if d.Name == "PutarRoda" then
				table.insert(rig.wheels, d)
			elseif d.Name == "Setir" then
				rig.steer = d
			elseif d.Name == "EngselPanel" then
				rig.engsel = d
			elseif d.Name == "EngselPintu" then
				table.insert(rig.doors, { motor = d, arah = d.Part1:GetAttribute("Arah") or 1 })
			elseif d.Name == "Piston" then
				table.insert(pistonMotors, d)
			end
		end
	end
	-- Tiap bagian piston: tabung nempel di pangkal (Chassis), batang di ujung (panel).
	for _, motor in ipairs(pistonMotors) do
		local part = motor.Part1
		local i = part:GetAttribute("Piston")
		local pangkal = chassis:FindFirstChild("PangkalPiston" .. tostring(i))
		local ujung = rig.engsel and rig.engsel.Part1:FindFirstChild("UjungPiston" .. tostring(i))
		if pangkal and ujung then
			table.insert(rig.pistons, {
				motor = motor,
				tabung = part:GetAttribute("Bagian") == "Tabung",
				length = part.Size.X,
				pangkal = pangkal.Position, -- ruang Chassis
				ujung = ujung.Position, -- ruang panel
			})
		end
	end
	rigs[model] = rig
	return rig
end

-- Tangan avatar megang stang selama duduk di Kemudi.
local function attachHands(humanoid, model)
	local character = humanoid.Parent
	local made = {}
	for side, nama in pairs({ Left = "Kiri", Right = "Kanan" }) do
		local target = model:FindFirstChild("Pegangan" .. nama, true)
		local pole = model:FindFirstChild("Siku" .. nama, true)
		-- R15: lengan atas -> tangan. R6: lengannya satu part.
		local root = character:FindFirstChild(side .. "UpperArm") or character:FindFirstChild(side .. " Arm")
		local hand = character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")
		if target and root and hand then
			local ik = Instance.new("IKControl")
			ik.Name = "PegangStang" .. nama
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot = root
			ik.EndEffector = hand
			ik.Target = target
			ik.Pole = pole
			ik.Parent = humanoid
			table.insert(made, ik)
		end
	end
	return made
end

local function updateHands(rig, model)
	local occupant = rig.seat and rig.seat.Occupant
	if occupant == rig.handsFor then
		return
	end
	for _, ik in ipairs(rig.hands) do
		ik:Destroy()
	end
	rig.hands = occupant and attachHands(occupant, model) or {}
	rig.handsFor = occupant
end

-- Panel samping: kebuka pas lapak buka (diparkir di titik jualan), ketutup
-- selain itu. Sudutnya di-tween, terus dipasang ke engsel + piston.
local function updatePanel(rig, model)
	if not rig.engsel then
		return
	end
	local target = model:GetAttribute("LapakBuka") == true and rig.openAngle or 0
	if rig.panelTarget ~= target then
		rig.panelTarget = target
		if rig.tween then
			rig.tween:Cancel()
		end
		local share = rig.openAngle > 0 and math.abs(target - rig.sudut.Value) / rig.openAngle or 0
		rig.tween = TweenService:Create(rig.sudut, TweenInfo.new(PANEL_TIME * share, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Value = target,
		})
		rig.tween:Play()
	end

	local angle = rig.sudut.Value
	if angle == rig.appliedAngle then
		return
	end
	rig.appliedAngle = angle
	local turn = CFrame.Angles(0, 0, -angle) -- ujung bawah panel muter ke luar (kiri) lalu ke atas
	rig.engsel.Transform = turn
	local panelCF = rig.engsel.C0 * turn * rig.engsel.C1:Inverse() -- panel di ruang Chassis
	for _, p in ipairs(rig.pistons) do
		local ujung = panelCF * p.ujung
		local dir = (ujung - p.pangkal).Unit
		local rot = CFrame.lookAt(Vector3.zero, dir, Vector3.zAxis) * ALONG_X
		local center = p.tabung and p.pangkal + dir * p.length / 2 or ujung - dir * p.length / 2
		-- Motor6D: Part1 = Part0 * C0 * Transform * C1^-1  ->  Transform = C0^-1 * tujuan * C1
		p.motor.Transform = p.motor.C0:Inverse() * (CFrame.new(center) * rot) * p.motor.C1
	end
	-- Pintu belakang kebuka bareng panel (porsi bukaannya sama).
	local share = rig.openAngle > 0 and angle / rig.openAngle or 0
	for _, door in ipairs(rig.doors) do
		door.motor.Transform = CFrame.Angles(0, door.arah * rig.doorAngle * share, 0)
	end
end

RunService.RenderStepped:Connect(function(dt)
	for _, model in ipairs(kendaraanFolder:GetChildren()) do
		local chassis = model.PrimaryPart
		if chassis then
			local rig = getRig(model)
			local speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
			rig.spin = (rig.spin + speed / rig.stats.wheelRadius * dt) % (math.pi * 2)
			for _, motor in ipairs(rig.wheels) do
				motor.Transform = CFrame.Angles(-rig.spin, 0, 0) -- maju (-Z) = bagian atas roda gerak ke depan
			end
			if rig.steer then
				local target = -(rig.seat and rig.seat.SteerFloat or 0) * rig.stats.maxSteerAngle
				rig.steerAngle += (target - rig.steerAngle) * math.min(dt * 10, 1)
				rig.steer.Transform = CFrame.Angles(0, rig.steerAngle, 0)
			end
			updateHands(rig, model)
			updatePanel(rig, model)
		end
	end
end)

kendaraanFolder.ChildRemoved:Connect(function(model)
	local rig = rigs[model]
	if rig then
		rigs[model] = nil
		for _, ik in ipairs(rig.hands) do
			ik:Destroy()
		end
		if rig.tween then
			rig.tween:Cancel()
		end
		rig.sudut:Destroy()
	end
end)

-- ── PROMPT KENDARAAN ORANG LAIN DISEMBUNYIIN ───────────────────────
-- (Server tetep ngecek pemilik; ini biar player lain nggak liat tombolnya.)
local function hidePrompt(prompt)
	prompt.Enabled = false
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled then
			prompt.Enabled = false
		end
	end)
end

local function onKendaraanAdded(model)
	if model:GetAttribute("OwnerUserId") == player.UserId then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			hidePrompt(d)
		end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			hidePrompt(d)
		end
	end)
end

kendaraanFolder.ChildAdded:Connect(onKendaraanAdded)
for _, model in ipairs(kendaraanFolder:GetChildren()) do
	onKendaraanAdded(model)
end

-- ── PETUNJUK DI LAYAR ──────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "KendaraanHint"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.Name = "Petunjuk"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 64)
hint.Size = UDim2.new(0.9, 0, 0, 52)
hint.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
hint.BackgroundTransparency = 0.25
hint.Font = Enum.Font.GothamBold
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextScaled = true
hint.TextWrapped = true
hint.Visible = false
hint.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = hint
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(560, 52)
sizeLimit.Parent = hint
local textLimit = Instance.new("UITextSizeConstraint")
textLimit.MaxTextSize = 18
textLimit.Parent = hint
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = hint

local function isInSellZone(position)
	for _, zone in ipairs(CollectionService:GetTagged("TitikJualan")) do
		if zone:IsDescendantOf(workspace) then
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local function findMine()
	for _, model in ipairs(kendaraanFolder:GetChildren()) do
		if model:GetAttribute("OwnerUserId") == player.UserId then
			return model
		end
	end
	return nil
end

local function controlsText()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Stik: gas & belok  •  Lompat: turun"
	end
	return "W/S: gas & mundur  •  A/D: belok  •  Spasi: turun"
end

local function hintText()
	local model = findMine()
	local chassis = model and model.PrimaryPart
	if not chassis then
		return nil
	end
	local inZone = isInSellZone(chassis.Position)

	if getMyDrivingSeat() then
		if inZone then
			return "Udah di TITIK JUALAN! Berhenti, terus turun buat buka lapak"
		end
		return controlsText() .. "\nGoreng cuma bisa di TITIK JUALAN (Pasar)"
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - chassis.Position).Magnitude < HINT_RANGE then
		if model:GetAttribute("LapakBuka") ~= true and not inZone then
			return "Naik kendaraan, terus parkir di TITIK JUALAN (Pasar) buat buka lapak"
		end
	end
	return nil
end

task.spawn(function()
	while true do
		local text = hintText()
		hint.Visible = text ~= nil
		if text then
			hint.Text = text
		end
		task.wait(0.2)
	end
end)
