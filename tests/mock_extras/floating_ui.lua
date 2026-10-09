-- Mock additions for the floating UI specs: a Lighting service (BlurEffect parent).
do
	local lighting = Instance.new("Lighting")
	M.lighting = lighting
	local original = game.GetService
	game.GetService = function(self, name)
		if name == "Lighting" then
			return lighting
		end
		return original(self, name)
	end
end
