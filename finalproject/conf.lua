function love.conf(t)
	t.version = "0.10.0"
	
	--t.window = nil
	t.window.title = "BRiTEBOT"
	t.window.width = 426
	t.window.height = 240
	t.window.vsync = false
	t.window.msaa = 0
	t.window.icon = "graphics/icon.png"
	
	t.console = false
	
	t.modules.joystick = false
	t.modules.physics = false
end