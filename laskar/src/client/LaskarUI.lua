-- UI prototipe (ModuleScript di StarterPlayerScripts, dipake LaskarClient).
--
-- Isi layar:
--   pinggir layar : bingkai putih yang ngedenyut tiap ketukan (emas pas pasukan jawab)
--   kiri/kanan/atas: kendang "muncul" tiap dipukul. Nggak ada karakter yang
--                   keliatan mukul: lu "dewa" yang ngatur dari luar layar.
--   bawah tengah  : 4 pad kendang (bisa dipencet di HP) + 4 slot urutan pukulan
--   atas kiri     : kombo + bar Semangat
--   atas kanan    : daftar perintah (H buat buka/tutup) + kalibrasi + kamera
--   tengah        : penilaian (PERFECT/BAGUS/MELESET), teks perintah, banner menang
-- Gaya: panel gelap transparan, teks putih, warna cuma buat kendang.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage:WaitForChild("LaskarConfig"))

local PUTIH = Color3.fromRGB(245, 245, 245)
local PANEL = Color3.fromRGB(18, 18, 22)
local EMAS = Color3.fromRGB(255, 205, 90)
local REDUP = Color3.fromRGB(150, 150, 158)

local UI = {}

local function buat(kelas, props, anak)
	local obj = Instance.new(kelas)
	for k, v in pairs(props) do
		obj[k] = v
	end
	for _, a in ipairs(anak or {}) do
		a.Parent = obj
	end
	return obj
end

local function sudut(r)
	return buat("UICorner", { CornerRadius = r or UDim.new(0, 10) })
end

local function teks(props)
	local t = buat("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = PUTIH,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	})
	for k, v in pairs(props) do
		t[k] = v
	end
	return t
end

local function panel(props)
	local f = buat("Frame", {
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, { sudut() })
	for k, v in pairs(props) do
		f[k] = v
	end
	return f
end

-- pemain: Player. onPad(drumId) dipanggil pas pad dipencet (sentuh/klik).
-- onKalibrasi(delta) & onKamera() buat tombol di panel bantuan.
function UI.buat(pemain, onPad, onKalibrasi, onKamera)
	local gui = buat("ScreenGui", {
		Name = "LaskarUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local self = {}

	-- ── BINGKAI DENYUT & KENDANG MUNCUL ─────────────────────────
	local bingkai = buat("Frame", {
		Name = "Bingkai",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		Parent = gui,
	})
	local garisBingkai = buat("UIStroke", { Color = PUTIH, Thickness = 0, Transparency = 0.25, Parent = bingkai })

	local POSISI_MUNCUL = {
		DUNG = UDim2.fromScale(0.1, 0.48),
		TAK = UDim2.fromScale(0.9, 0.48),
		PAK = UDim2.fromScale(0.3, 0.2),
		TUNG = UDim2.fromScale(0.7, 0.2),
	}
	local muncul = {}
	for _, d in ipairs(C.DRUM) do
		local grup = buat("CanvasGroup", {
			Name = "Muncul" .. d.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = POSISI_MUNCUL[d.id] or UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromOffset(104, 104),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Parent = gui,
		})
		buat("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = d.warna,
			BackgroundTransparency = 0.08,
			Parent = grup,
		}, {
			sudut(UDim.new(1, 0)),
			buat("UIStroke", { Color = PUTIH, Thickness = 4 }),
			teks({ Text = d.id .. "!", Size = UDim2.fromScale(1, 1), TextSize = 24, Font = Enum.Font.GothamBlack }),
		})
		muncul[d.id] = { grup = grup, skala = buat("UIScale", { Parent = grup }), token = 0 }
	end

	-- ── PAD KENDANG ─────────────────────────────────────────────
	local PAD, JARAK = 74, 14
	local lebarPad = #C.DRUM * PAD + (#C.DRUM - 1) * JARAK
	local barisPad = buat("Frame", {
		Name = "Pad",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(lebarPad, PAD),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local pad = {}
	for i, d in ipairs(C.DRUM) do
		local tombol = buat("TextButton", {
			Name = d.id,
			Position = UDim2.fromOffset((i - 1) * (PAD + JARAK), 0),
			Size = UDim2.fromOffset(PAD, PAD),
			BackgroundColor3 = d.warna,
			BackgroundTransparency = 0.15,
			AutoButtonColor = false,
			Text = "",
			Parent = barisPad,
		}, { sudut(UDim.new(1, 0)) })
		local garis = buat("UIStroke", { Color = PUTIH, Thickness = 0, Parent = tombol })
		local skala = buat("UIScale", { Parent = tombol })
		teks({ Text = d.id, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 20), TextSize = 17, Parent = tombol })
		teks({
			Text = d.tombol.Name,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 44),
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextTransparency = 0.25,
			Parent = tombol,
		})
		-- InputBegan (bukan Activated) biar langsung kerasa pas jari nyentuh, bukan pas dilepas.
		tombol.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
				onPad(d.id)
			end
		end)
		pad[d.id] = { tombol = tombol, garis = garis, skala = skala }
	end

	-- ── SLOT URUTAN ─────────────────────────────────────────────
	local SLOT, JARAK_SLOT = 46, 12
	local kotakUrutan = panel({
		Name = "Urutan",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(22 + PAD + 14)),
		Size = UDim2.fromOffset(4 * SLOT + 3 * JARAK_SLOT + 24, SLOT + 20),
		Parent = gui,
	})
	local denyut = buat("UIStroke", { Color = PUTIH, Thickness = 0, Transparency = 0.2, Parent = kotakUrutan })
	local slot = {}
	for i = 1, 4 do
		local s = buat("Frame", {
			Position = UDim2.fromOffset(12 + (i - 1) * (SLOT + JARAK_SLOT), 10),
			Size = UDim2.fromOffset(SLOT, SLOT),
			BackgroundColor3 = Color3.fromRGB(60, 60, 68),
			BackgroundTransparency = 0.4,
			Parent = kotakUrutan,
		}, { sudut(UDim.new(1, 0)) })
		local label = teks({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 12, Parent = s })
		slot[i] = { frame = s, label = label }
	end
	local teksJawaban = teks({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 26,
		Font = Enum.Font.GothamBlack,
		TextColor3 = EMAS,
		Visible = false,
		Parent = kotakUrutan,
	})

	local penilaian = teks({
		Name = "Penilaian",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(22 + PAD + 14 + SLOT + 28)),
		Size = UDim2.fromOffset(240, 30),
		Text = "",
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		Parent = gui,
	})
	-- Outline ikut pudar bareng teks (kalau nggak, garis tulisan terakhir nyangkut di layar).
	local garisPenilaian = buat("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 1, Parent = penilaian })

	-- ── KOMBO ───────────────────────────────────────────────────
	local kotakKombo = panel({
		Name = "Kombo",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(190, 74),
		Parent = gui,
	})
	teks({ Text = "KOMBO", Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(80, 18), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = REDUP, Parent = kotakKombo })
	local angkaKombo = teks({ Text = "0", Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(80, 30), TextSize = 28, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = kotakKombo })
	local labelSemangat = teks({ Text = "", Position = UDim2.fromOffset(84, 30), Size = UDim2.fromOffset(96, 20), TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = EMAS, TextXAlignment = Enum.TextXAlignment.Right, Parent = kotakKombo })
	local barSemangat = buat("Frame", { Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = Color3.fromRGB(60, 60, 68), BorderSizePixel = 0, Parent = kotakKombo }, { sudut(UDim.new(1, 0)) })
	local isiSemangat = buat("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = PUTIH, BorderSizePixel = 0, Parent = barSemangat }, { sudut(UDim.new(1, 0)) })

	-- ── BANTUAN ─────────────────────────────────────────────────
	local kotakBantuan = panel({
		Name = "Bantuan",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(250, 52 + #C.PERINTAH * 30 + 70),
		Parent = gui,
	})
	teks({ Text = "PERINTAH", Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(120, 18), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = REDUP, Parent = kotakBantuan })
	for i, p in ipairs(C.PERINTAH) do
		local y = 34 + (i - 1) * 30
		teks({ Text = p.teks:gsub("!", ""), Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(80, 24), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = kotakBantuan })
		for j, id in ipairs(p.pola) do
			local d = C.drum(id)
			buat("Frame", {
				Position = UDim2.fromOffset(94 + (j - 1) * 36, y + 2),
				Size = UDim2.fromOffset(32, 20),
				BackgroundColor3 = d.warna,
				BorderSizePixel = 0,
				Parent = kotakBantuan,
			}, {
				sudut(UDim.new(0, 6)),
				teks({ Text = d.tombol.Name, Size = UDim2.fromScale(1, 1), TextSize = 12 }),
			})
		end
	end
	local yBawah = 34 + #C.PERINTAH * 30 + 6
	local labelKalibrasi = teks({ Text = "", Position = UDim2.fromOffset(14, yBawah), Size = UDim2.fromOffset(150, 20), TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = REDUP, Parent = kotakBantuan })
	local function tombolKecil(label, x, y, w, aksi)
		local b = buat("TextButton", {
			Text = label,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, 24),
			BackgroundColor3 = Color3.fromRGB(70, 70, 80),
			BackgroundTransparency = 0.2,
			TextColor3 = PUTIH,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutoButtonColor = true,
			Parent = kotakBantuan,
		}, { sudut(UDim.new(0, 6)) })
		b.Activated:Connect(aksi)
	end
	tombolKecil("-", 172, yBawah - 2, 28, function()
		onKalibrasi(-10)
	end)
	tombolKecil("+", 206, yBawah - 2, 28, function()
		onKalibrasi(10)
	end)
	tombolKecil("Kamera [C]", 14, yBawah + 28, 100, onKamera)
	teks({ Text = "H tutup", Position = UDim2.fromOffset(120, yBawah + 30), Size = UDim2.fromOffset(116, 20), TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = REDUP, Parent = kotakBantuan })

	local tombolBantuan = buat("TextButton", {
		Name = "BukaBantuan",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		Text = "?",
		TextColor3 = PUTIH,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		Visible = false,
		Parent = gui,
	}, { sudut(UDim.new(1, 0)) })

	-- ── BANNER & PESAN ──────────────────────────────────────────
	local banner = panel({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(360, 110),
		Visible = false,
		Parent = gui,
	})
	local judulBanner = teks({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 12), TextSize = 40, Font = Enum.Font.GothamBlack, TextColor3 = EMAS, Parent = banner })
	local subBanner = teks({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 70), TextSize = 15, Font = Enum.Font.GothamMedium, Parent = banner })

	local pesan = panel({
		Name = "Pesan",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2), -- di bawah panel kombo/bantuan biar nggak numpuk di layar HP
		Size = UDim2.fromOffset(340, 36),
		Visible = false,
		Parent = gui,
	})
	local teksPesan = teks({ Size = UDim2.fromScale(1, 1), TextSize = 15, Parent = pesan })

	gui.Parent = pemain:WaitForChild("PlayerGui")

	-- ── FUNGSI ──────────────────────────────────────────────────
	local tokenPenilaian, tokenPesan = 0, 0

	function self.pukul(id)
		local q = muncul[id]
		if q then
			q.token += 1
			local token = q.token
			q.grup.GroupTransparency = 0
			q.skala.Scale = 0.6
			TweenService:Create(q.skala, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.delay(0.22, function()
				if q.token == token then
					TweenService:Create(q.grup, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
				end
			end)
		end
		local p = pad[id]
		if not p then
			return
		end
		p.skala.Scale = 1.14
		p.garis.Thickness = 3
		TweenService:Create(p.skala, TweenInfo.new(0.15), { Scale = 1 }):Play()
		TweenService:Create(p.garis, TweenInfo.new(0.2), { Thickness = 0 }):Play()
	end

	function self.denyut(fase)
		local warna = fase == "jawab" and EMAS or PUTIH
		denyut.Color = warna
		denyut.Thickness = 3
		TweenService:Create(denyut, TweenInfo.new(0.22), { Thickness = 0 }):Play()
		garisBingkai.Color = warna
		garisBingkai.Thickness = 12
		TweenService:Create(garisBingkai, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = 0 }):Play()
	end

	function self.isiSlot(i, id)
		local s = slot[i]
		local d = id and C.drum(id)
		s.frame.BackgroundColor3 = d and d.warna or Color3.fromRGB(60, 60, 68)
		s.frame.BackgroundTransparency = d and 0.05 or 0.4
		s.label.Text = d and d.id or ""
	end

	function self.kosongkanSlot()
		for i = 1, 4 do
			self.isiSlot(i, nil)
		end
	end

	-- Fase jawaban pasukan: slot diganti teks perintah.
	function self.jawaban(teksPerintah)
		teksJawaban.Text = teksPerintah or ""
		teksJawaban.Visible = teksPerintah ~= nil
		for i = 1, 4 do
			slot[i].frame.Visible = teksPerintah == nil
		end
	end

	function self.nilai(label, warna)
		tokenPenilaian += 1
		local token = tokenPenilaian
		penilaian.Text = label
		penilaian.TextColor3 = warna or PUTIH
		penilaian.TextTransparency = 0
		garisPenilaian.Transparency = 0.4
		task.delay(0.45, function()
			if token == tokenPenilaian then
				TweenService:Create(penilaian, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
				TweenService:Create(garisPenilaian, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
		end)
	end

	function self.kombo(n, semangat)
		angkaKombo.Text = tostring(n)
		labelSemangat.Text = semangat and "SEMANGAT!" or ""
		isiSemangat.BackgroundColor3 = semangat and EMAS or PUTIH
		TweenService:Create(isiSemangat, TweenInfo.new(0.2), {
			Size = UDim2.fromScale(math.clamp(n / C.KOMBO_SEMANGAT, 0, 1), 1),
		}):Play()
	end

	function self.kalibrasi(ms)
		labelKalibrasi.Text = ("Kalibrasi: %+d ms"):format(ms)
	end

	function self.toggleBantuan()
		kotakBantuan.Visible = not kotakBantuan.Visible
		tombolBantuan.Visible = not kotakBantuan.Visible
	end
	tombolBantuan.Activated:Connect(self.toggleBantuan)

	function self.pesan(isi, detik)
		tokenPesan += 1
		local token = tokenPesan
		teksPesan.Text = isi
		pesan.Visible = true
		task.delay(detik or 3, function()
			if token == tokenPesan then
				pesan.Visible = false
			end
		end)
	end

	function self.banner(judul, sub, detik)
		judulBanner.Text = judul
		subBanner.Text = sub or ""
		banner.Visible = true
		task.delay(detik or 6, function()
			banner.Visible = false
		end)
	end

	self.kalibrasi(0)
	self.kombo(0, false)
	return self
end

return UI
