-- Loading screen custom. Ditaruh di ReplicatedFirst biar jalan PALING AWAL
-- (sebelum asset/script lain ke-load), jadi player langsung liat ini begitu join.
-- Ilang (fade out) setelah game ke-load + character udah spawn.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MIN_SHOW_SECONDS = 2 -- biar nggak cuma kedip sekali pas loading-nya cepet (Studio)
local FADE_SECONDS = 0.8
local TIP_INTERVAL = 3

local TIPS = {
	"Tips: klik joran buat mancing!",
	"Tips: tekan 1 buat equip FishingRod dari backpack.",
	"Tips: makin langka ikannya, makin gede coins-nya.",
	"Tips: ikan Legendary itu super langka, sabar ya!",
	"Tips: tunggu beberapa detik sampe ikannya nyangkut.",
}

-- ── BUILD UI ───────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 100
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- CanvasGroup biar seluruh isi bisa di-fade bareng cuma lewat GroupTransparency.
local root = Instance.new("CanvasGroup")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = screenGui

-- Background sengaja Frame terpisah: UIGradient yang ditaruh langsung di
-- CanvasGroup bakal ngewarnain SELURUH isi grup (judul ikut jadi gelap).
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.new(1, 1, 1)
background.BorderSizePixel = 0
background.Parent = root

local bgGradient = Instance.new("UIGradient")
bgGradient.Rotation = 90
bgGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 58, 120)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(8, 30, 74)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 10, 30)),
})
bgGradient.Parent = background

-- Gelembung dekorasi yang naik pelan-pelan dari bawah.
local bubbleLayer = Instance.new("Frame")
bubbleLayer.Name = "Bubbles"
bubbleLayer.Size = UDim2.fromScale(1, 1)
bubbleLayer.BackgroundTransparency = 1
bubbleLayer.Parent = root

local content = Instance.new("Frame")
content.Name = "Content"
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.fromScale(0.5, 0.5)
content.Size = UDim2.new(0.9, 0, 0, 260)
content.BackgroundTransparency = 1
content.Parent = root

local contentSize = Instance.new("UISizeConstraint")
contentSize.MaxSize = Vector2.new(820, math.huge)
contentSize.Parent = content

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0)
title.Size = UDim2.new(1, 0, 0, 120)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.Text = "BRAINROT FISHING"
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = content

local titleGradient = Instance.new("UIGradient")
titleGradient.Rotation = 90
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 40)),
})
titleGradient.Parent = title

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(10, 20, 50)
titleStroke.Thickness = 4
titleStroke.Parent = title

local titleSize = Instance.new("UITextSizeConstraint")
titleSize.MaxTextSize = 96
titleSize.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0, 124)
subtitle.Size = UDim2.new(1, 0, 0, 26)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamBold
subtitle.Text = "Siapin joranmu..."
subtitle.TextSize = 20
subtitle.TextColor3 = Color3.fromRGB(160, 205, 255)
subtitle.Parent = content

local barTrack = Instance.new("Frame")
barTrack.Name = "BarTrack"
barTrack.AnchorPoint = Vector2.new(0.5, 0)
barTrack.Position = UDim2.new(0.5, 0, 0, 172)
barTrack.Size = UDim2.new(0.6, 0, 0, 16)
barTrack.BackgroundColor3 = Color3.fromRGB(4, 12, 32)
barTrack.BorderSizePixel = 0
barTrack.Parent = content

local barTrackSize = Instance.new("UISizeConstraint")
barTrackSize.MaxSize = Vector2.new(440, 16)
barTrackSize.Parent = barTrack

Instance.new("UICorner", barTrack).CornerRadius = UDim.new(1, 0)

local barTrackStroke = Instance.new("UIStroke")
barTrackStroke.Color = Color3.fromRGB(90, 150, 230)
barTrackStroke.Thickness = 2
barTrackStroke.Parent = barTrack

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.new(1, 1, 1)
barFill.BorderSizePixel = 0
barFill.Parent = barTrack

Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 220, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 90)),
})
fillGradient.Parent = barFill

local percentLabel = Instance.new("TextLabel")
percentLabel.Name = "Percent"
percentLabel.AnchorPoint = Vector2.new(0.5, 0)
percentLabel.Position = UDim2.new(0.5, 0, 0, 194)
percentLabel.Size = UDim2.new(1, 0, 0, 20)
percentLabel.BackgroundTransparency = 1
percentLabel.Font = Enum.Font.GothamBold
percentLabel.Text = "Loading... 0%"
percentLabel.TextSize = 16
percentLabel.TextColor3 = Color3.fromRGB(200, 225, 255)
percentLabel.Parent = content

local tipLabel = Instance.new("TextLabel")
tipLabel.Name = "Tip"
tipLabel.AnchorPoint = Vector2.new(0.5, 1)
tipLabel.Position = UDim2.new(0.5, 0, 1, -40)
tipLabel.Size = UDim2.new(0.9, 0, 0, 24)
tipLabel.BackgroundTransparency = 1
tipLabel.Font = Enum.Font.Gotham
tipLabel.Text = TIPS[math.random(#TIPS)]
tipLabel.TextSize = 18
tipLabel.TextWrapped = true
tipLabel.TextColor3 = Color3.fromRGB(190, 215, 245)
tipLabel.Parent = root

screenGui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- ── ANIMASI ────────────────────────────────────────────────────────
local finished = false

-- Gelembung: spawn terus selama loading, naik + fade, terus di-destroy.
task.spawn(function()
	while not finished do
		local size = math.random(6, 22)
		local bubble = Instance.new("Frame")
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Position = UDim2.new(math.random(), 0, 1, size)
		bubble.Size = UDim2.fromOffset(size, size)
		bubble.BackgroundColor3 = Color3.fromRGB(150, 210, 255)
		bubble.BackgroundTransparency = 0.75
		bubble.Parent = bubbleLayer
		Instance.new("UICorner", bubble).CornerRadius = UDim.new(1, 0)

		local rise = TweenService:Create(
			bubble,
			TweenInfo.new(math.random(40, 70) / 10, Enum.EasingStyle.Linear),
			{ Position = bubble.Position - UDim2.fromScale(0, 1.1), BackgroundTransparency = 0.95 }
		)
		rise.Completed:Once(function()
			bubble:Destroy()
		end)
		rise:Play()
		task.wait(0.25)
	end
end)

-- Judul "napas" pelan biar nggak kaku.
local titleBob = TweenService:Create(
	title,
	TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Position = UDim2.new(0.5, 0, 0, -8) }
)
titleBob:Play()

-- Ganti tips tiap beberapa detik, fade out -> ganti teks -> fade in.
task.spawn(function()
	local index = table.find(TIPS, tipLabel.Text) or 1
	while not finished do
		task.wait(TIP_INTERVAL)
		if finished then
			break
		end
		local fadeOut = TweenService:Create(tipLabel, TweenInfo.new(0.25), { TextTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Wait()
		index = index % #TIPS + 1
		tipLabel.Text = TIPS[index]
		TweenService:Create(tipLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end
end)

-- Progress bar: `target` naik per tahap loading, fill ngejar pelan biar mulus.
-- Selama nunggu, target "merayap" sendiri tapi nggak pernah lewat batas tahapnya.
local progress = 0
local target = 0.15
local stageCap = 0.5

local progressConn = RunService.RenderStepped:Connect(function(dt)
	target = math.min(target + dt * 0.08, stageCap)
	progress += (target - progress) * math.min(dt * 6, 1)
	barFill.Size = UDim2.fromScale(progress, 1)
	percentLabel.Text = ("Loading... %d%%"):format(math.floor(progress * 100 + 0.5))
end)

local startTime = os.clock()

if not game:IsLoaded() then
	game.Loaded:Wait()
end
target = math.max(target, 0.5)
stageCap = 0.9

local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart")
target = math.max(target, 0.9)

local remaining = MIN_SHOW_SECONDS - (os.clock() - startTime)
if remaining > 0 then
	task.wait(remaining)
end

target = 1
stageCap = 1
while progress < 0.995 do
	RunService.RenderStepped:Wait()
end
percentLabel.Text = "Loading... 100%"
subtitle.Text = "Siap mancing!"
task.wait(0.25)

-- ── FADE OUT ───────────────────────────────────────────────────────
finished = true
progressConn:Disconnect()
titleBob:Cancel()

local fade = TweenService:Create(
	root,
	TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ GroupTransparency = 1 }
)
fade:Play()
fade.Completed:Wait()
screenGui:Destroy()
