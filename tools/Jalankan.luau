--[[
	Jalanin builder di tools/ dari Command Bar Studio (mode Edit), contoh:

	  require(game.ServerStorage.Tools.Jalankan)("Kendaraan/Viar")

	Folder Tools di-clone dulu tiap jalan: require() di Studio nge-cache
	ModuleScript, jadi tanpa clone editan module nggak kebaca sampe Studio
	dibuka ulang. Abis jalan, clone-nya dibuang.
]]

return function(path)
	local tools = script.Parent
	local copy = tools:Clone()
	copy.Name = "_ToolsJalan"
	copy.Parent = tools.Parent

	local ok, result = pcall(function()
		local target = copy
		for name in string.gmatch(path, "[^/]+") do
			target = target:FindFirstChild(name) or error("Builder nggak ketemu: " .. path, 0)
		end
		local builder = require(target)
		-- Builder baru nge-return function; BuildKota (lama) langsung jalan pas di-require.
		if type(builder) == "function" then
			return builder()
		end
		return builder
	end)

	copy:Destroy()
	if not ok then
		error(result, 0)
	end
	return result
end
