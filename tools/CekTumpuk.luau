--[[
	CekTumpuk — nyari permukaan yang numpuk (z-fighting): dua part keliatan
	yang punya sisi sejajar, ngadep arah yang sama, jaraknya nyaris nol, dan
	saling nutupin. Di game itu keliatan kayak kotak pixel kedip-kedip.

	Jalanin (Command Bar), contoh buat template Viar:
	  print(require(game.ServerStorage.Tools.CekTumpuk)(game.ServerStorage.Kendaraan.Viar))

	Cuma ngecek sisi datar Part kotak + tutup silinder (dianggep persegi, jadi
	bisa ada laporan palsu di silinder). Bola, union, sama part ber-mesh di-skip.
	Pasangan yang warna + materialnya sama nggak dilaporin (numpuk pun nggak
	keliatan kedip), begitu juga yang luas tumpukannya cuma secuil.
]]

local TOLERANSI = 0.04 -- stud; di bawah ini dua sisi dianggep "satu bidang"
local LUAS_MIN = 0.005 -- stud²

local function faces(part)
	local list = {}
	local cf, size = part.CFrame, part.Size
	local axes = {
		{ cf.RightVector, size.X, cf.UpVector, size.Y, cf.LookVector, size.Z },
		{ cf.UpVector, size.Y, cf.RightVector, size.X, cf.LookVector, size.Z },
		{ cf.LookVector, size.Z, cf.RightVector, size.X, cf.UpVector, size.Y },
	}
	local shape = part:IsA("Part") and part.Shape or Enum.PartType.Block
	for i, a in ipairs(axes) do
		-- Silinder: cuma tutupnya (sumbu X) yang datar.
		if shape == Enum.PartType.Block or (shape == Enum.PartType.Cylinder and i == 1) then
			for _, sign in ipairs({ 1, -1 }) do
				table.insert(list, {
					normal = a[1] * sign,
					center = cf.Position + a[1] * sign * a[2] / 2,
					u = a[3], hu = a[4] / 2,
					v = a[5], hv = a[6] / 2,
				})
			end
		end
	end
	return list
end

-- Dua persegi panjang di bidang yang sama: luas tumpukannya (kira-kira,
-- diukur di sumbu f1). 0 = nggak numpuk (SAT 2D).
local function overlapArea(f1, f2)
	local d = f2.center - f1.center
	for _, axis in ipairs({ f1.u, f1.v, f2.u, f2.v }) do
		local r1 = math.abs(f1.u:Dot(axis)) * f1.hu + math.abs(f1.v:Dot(axis)) * f1.hv
		local r2 = math.abs(f2.u:Dot(axis)) * f2.hu + math.abs(f2.v:Dot(axis)) * f2.hv
		if math.abs(d:Dot(axis)) >= r1 + r2 then
			return 0
		end
	end
	local area = 1
	for _, axis in ipairs({ { f1.u, f1.hu }, { f1.v, f1.hv } }) do
		local r2 = math.abs(f2.u:Dot(axis[1])) * f2.hu + math.abs(f2.v:Dot(axis[1])) * f2.hv
		local c = d:Dot(axis[1])
		area *= math.max(0, math.min(axis[2], c + r2) - math.max(-axis[2], c - r2))
	end
	return area
end

local function visible(p)
	if not p:IsA("BasePart") or p.Transparency >= 1 or p:FindFirstChildWhichIsA("DataModelMesh") then
		return false
	end
	if p:IsA("Part") then
		return p.Shape == Enum.PartType.Block or p.Shape == Enum.PartType.Cylinder
	end
	return p.ClassName == "Seat" or p.ClassName == "VehicleSeat"
end

return function(root)
	local parts = {}
	for _, p in ipairs(root:GetDescendants()) do
		if visible(p) then
			table.insert(parts, { part = p, faces = faces(p) })
		end
	end

	local hasil = {}
	for i = 1, #parts do
		local a = parts[i]
		for j = i + 1, #parts do
			local b = parts[j]
			local reach = (a.part.Size.Magnitude + b.part.Size.Magnitude) / 2
			local looksSame = a.part.Color == b.part.Color and a.part.Material == b.part.Material
			if not looksSame and (a.part.Position - b.part.Position).Magnitude <= reach then
				for _, fa in ipairs(a.faces) do
					for _, fb in ipairs(b.faces) do
						if fa.normal:Dot(fb.normal) > 0.999
							and math.abs((fb.center - fa.center):Dot(fa.normal)) < TOLERANSI
							and overlapArea(fa, fb) > LUAS_MIN
						then
							table.insert(hasil, ("%s  <->  %s  (jarak %.3f)"):format(
								a.part:GetFullName(),
								b.part:GetFullName(),
								math.abs((fb.center - fa.center):Dot(fa.normal))
							))
						end
					end
				end
			end
		end
	end
	if #hasil == 0 then
		return "Aman: nggak ada permukaan numpuk"
	end
	return ("%d permukaan numpuk:\n%s"):format(#hasil, table.concat(hasil, "\n"))
end
