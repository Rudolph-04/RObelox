--[[
	Rig — langkah terakhir semua builder kendaraan: bikin model yang tadinya
	cuma tumpukan part anchored jadi kendaraan yang bisa jalan.

	  - Part ber-atribut "Tabrakan" = collider: nggak keliatan, punya massa,
	    tanpa gesekan (gerak diatur constraint, bukan gesekan roda).
	    Sisanya visual: nggak nabrak, nggak punya massa.
	  - Fisika di PrimaryPart (Chassis), diatur KendaraanController:
	      Gerak = LinearVelocity mode Plane (sumbu X/Z dunia) -> maju/mundur,
	              sumbu Y bebas (gravitasi tetep jalan)
	      Arah  = AlignOrientation -> arah hadap, sekaligus bikin kendaraan
	              selalu tegak (nggak bisa miring nyangkut / kebalik)
	  - Motor6D "Setir" (garpu depan) + "PutarRoda" (tiap roda): animasi client.
	  - WeldConstraint buat sisanya, semua di-unanchor, pivot = tanah.

	opsi = {
	  origin = CFrame tanah di tengah kendaraan (jadi pivot),
	  setir  = { group = Model, kepala = root part-nya, sumbu = CFrame sumbu belok (Y-nya) } atau nil,
	  roda   = { { model = Model roda, diSetir = true kalau nempel ke garpu }, ... },
	  gerak  = { { group = Model atau Part, root = Part, nama = nama Motor6D,
	             sendi = CFrame dunia titik putar }, ... } atau nil
	           -> bagian lain yang digerakin client (panel angkat, piston).
	}
]]

local function motor6D(name, part0, part1, jointCF)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(jointCF)
	m.C1 = part1.CFrame:ToObjectSpace(jointCF)
	m.Parent = part1
	return m
end

local function weld(part0, part1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

return function(kendaraan, opsi)
	local chassis = kendaraan.PrimaryPart
	assert(chassis, "Kendaraan butuh PrimaryPart (Chassis)")

	local noFriction = PhysicalProperties.new(0.7, 0, 0.2, 100, 1)
	for _, p in ipairs(kendaraan:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanTouch = false
			if p:GetAttribute("Tabrakan") then
				p.Transparency = 1
				p.CanCollide = true
				p.CanQuery = false
				p.Massless = false
				p.CustomPhysicalProperties = noFriction
			else
				p.CanCollide = false
				p.Massless = true
			end
		end
	end
	-- Chassis jadi root assembly walau ada karakter yang duduk (karakter
	-- defaultnya ikut rebutan jadi root), biar SetNetworkOwner di Chassis
	-- nggak "nyangkut" ke HumanoidRootPart pemain.
	chassis.RootPriority = 127

	local pusat = Instance.new("Attachment")
	pusat.Name = "Pusat"
	pusat.Parent = chassis

	local gerak = Instance.new("LinearVelocity")
	gerak.Name = "Gerak"
	gerak.Attachment0 = pusat
	gerak.RelativeTo = Enum.ActuatorRelativeTo.World
	gerak.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	gerak.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	gerak.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	gerak.PlaneVelocity = Vector2.zero
	gerak.MaxForce = 400000
	gerak.Parent = chassis

	local arah = Instance.new("AlignOrientation")
	arah.Name = "Arah"
	arah.Mode = Enum.OrientationAlignmentMode.OneAttachment
	arah.Attachment0 = pusat
	arah.CFrame = opsi.origin.Rotation
	arah.MaxTorque = 3000000
	arah.Responsiveness = 40
	arah.Parent = chassis

	-- Grup yang gerak sendiri (setir, roda) di-weld ke root grupnya,
	-- root grupnya nyambung pake Motor6D.
	local groupRoots = {}
	if opsi.setir then
		motor6D("Setir", chassis, opsi.setir.kepala, opsi.setir.sumbu)
		groupRoots[opsi.setir.group] = opsi.setir.kepala
	end
	for _, roda in ipairs(opsi.roda or {}) do
		local ban = roda.model:FindFirstChild("Ban")
		local part0 = roda.diSetir and opsi.setir and opsi.setir.kepala or chassis
		motor6D("PutarRoda", part0, ban, ban.CFrame)
		groupRoots[roda.model] = ban
	end
	for _, g in ipairs(opsi.gerak or {}) do
		motor6D(g.nama, chassis, g.root, g.sendi)
		groupRoots[g.group] = g.root
	end

	for _, p in ipairs(kendaraan:GetDescendants()) do
		if p:IsA("BasePart") and p ~= chassis then
			local root = chassis
			for group, groupRoot in pairs(groupRoots) do
				if p == group or p:IsDescendantOf(group) then
					root = groupRoot
					break
				end
			end
			if p ~= root then
				weld(root, p)
			end
		end
	end

	for _, p in ipairs(kendaraan:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
		end
	end

	-- Pivot = tanah di tengah kendaraan (bukan tengah Chassis), biar
	-- PivotTo(titik parkir) langsung napak. Model yang punya PrimaryPart
	-- nyimpen pivot-nya di PivotOffset.
	chassis.PivotOffset = chassis.CFrame:ToObjectSpace(opsi.origin)
	kendaraan.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- nyampe ke client utuh
end
