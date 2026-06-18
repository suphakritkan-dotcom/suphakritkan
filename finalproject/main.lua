
function love.load()
	randomize()
	
	require "class"
	require "intro"
	require "game"
	require "menu"
	require "button"
	require "ending"
	
	--VARIABLES
	require "values"
	
	--SETTINGS
	love.filesystem.setIdentity("britebot")
	controlstable = {"up", "down", "left", "right", "jump", "cameral", "camerar", "select", "undo"}
	if love.filesystem.exists("settings") then
		loadsettings()
	else
		defaultsettings()
		savesettings()
	end
	love.audio.setVolume(volume)
	setscale(scale[1])
	love.window.setTitle("BRiTEBOT")
	love.window.setIcon(love.image.newImageData("graphics/icon.png"))
	maxmsaa = love.graphics.getSystemLimits().canvasmsaa or 0
	require "shaders"
	
	--IMAGES
	love.graphics.setDefaultFilter("nearest", "nearest", 1)
	
	backgroundimg = {}
	backgroundimg[1]= love.graphics.newImage("graphics/background1.png")
	backgroundimg[2] = love.graphics.newImage("graphics/background2.png")
	backgroundimg[3] = love.graphics.newImage("graphics/background3.png")
	backgroundimg[4] = love.graphics.newImage("graphics/background4.png")
	
	gamesprites = love.graphics.newImage("graphics/gamesprites.png")--texture of all the game sprites
	local w, h = gamesprites:getWidth(), gamesprites:getHeight()--width and height of texture 
	
	tiletable = {} --colors of blocks and objects for map loading
	texturesize = 16
	local texturesp = texturesize+2
	--texturesimg = love.graphics.newImage("graphics/blocks.png")
	local data = love.image.newImageData("graphics/gamesprites.png")
	textures = {}
	for x = 1, 29 do
		for y = 1, 1 do
			local t = {}
			t.top = love.graphics.newQuad(1+(x-1)*texturesp, 1+(y-1)*(texturesp*5+1), texturesize, texturesize, w, h)
			t.side1 = love.graphics.newQuad(1+(x-1)*texturesp, 1+(y-1)*(texturesp*5+1)+texturesp, texturesize, texturesize, w, h)
			t.side2 = love.graphics.newQuad(1+(x-1)*texturesp, 1+(y-1)*(texturesp*5+1)+texturesp*2, texturesize, texturesize, w, h)
			t.side3 = love.graphics.newQuad(1+(x-1)*texturesp, 1+(y-1)*(texturesp*5+1)+texturesp*3, texturesize, texturesize, w, h)
			t.side4 = love.graphics.newQuad(1+(x-1)*texturesp, 1+(y-1)*(texturesp*5+1)+texturesp*4, texturesize, texturesize, w, h)
			
			table.insert(textures, t)
			local r, g, b, a = data:getPixel(1+(x-1)*texturesp, (y-1)*(texturesp*5+1)+texturesp*5)
			tiletable[r .. "-" .. g .. "-" .. b .. "-" .. a] = #textures
		end
	end
	--objimgsimg = love.graphics.newImage("graphics/objects.png")
	--local data = love.image.newImageData("graphics/objects.png")
	objimgs = {}
	for x = 1, 4 do
		for y = 1, 1 do
			local t = {}
			t[1] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1), texturesize, texturesize, w, h)
			t[2] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1)+texturesp, texturesize, texturesize, w, h)
			t[3] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1)+texturesp*2, texturesize, texturesize, w, h)
			t[4] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1)+texturesp*3, texturesize, texturesize, w, h)
			t[5] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1)+texturesp*4, texturesize, texturesize, w, h)
			t[6] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1)+texturesp*5, texturesize, texturesize, w, h)
			t[7] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1)+texturesp*6, texturesize, texturesize, w, h)
			t[8] = love.graphics.newQuad(109+(x-1)*texturesp, 92+(y-1)*(texturesp*4+1)+texturesp*7, texturesize, texturesize, w, h)
			
			table.insert(objimgs, t)
			local r, g, b, a = data:getPixel(109+(x-1)*texturesp, 91+(y-1)*(texturesp*4+1)+texturesp*8)
			tiletable[r .. "-" .. g .. "-" .. b .. "-" .. a] = "" .. #objimgs
		end
	end
	
	playerq = {}
	for y = 1, 4 do
		playerq[y] = {}
		for x = 1, 6 do
			playerq[y][x] = love.graphics.newQuad(1+(x-1)*texturesp, 92+(y-1)*texturesp, texturesize, texturesize, w, h)
		end
	end
	
	shadowq = love.graphics.newQuad(55, 182, texturesize, texturesize, w, h)
	ashadowq = {}
	for x = 1, 3 do
		ashadowq[x] = {}
		for y = 1, 3 do
			ashadowq[x][y] = love.graphics.newQuad(1+texturesp*(x-1), 182+texturesp*(y-1), texturesize, texturesize, w, h)
		end
	end
	
	wrenchq = {}
	for i = 1, 8 do
		wrenchq[i] = love.graphics.newQuad(127, 92+(i-1)*texturesp, texturesize, texturesize, w, h)
	end
	
	wrenchiconimg = love.graphics.newImage("graphics/wrenchicon.png")
	wrenchiconq = {}
	for i = 1, 4 do
		wrenchiconq[i] = love.graphics.newQuad(21*(i-1), 0, 21, 21, 84, 21)
	end
	
	animationsq = {}
	for i = 1, 5 do
		animationsq[i] = love.graphics.newQuad(1+texturesp*(i-1), 164, texturesize, texturesize, w, h)
	end
	
	buttonimg = love.graphics.newImage("graphics/button.png")
	buttonq = {}
	for y = 1, 3 do
		for x = 1, 3 do
			table.insert(buttonq, love.graphics.newQuad(texturesize*(x-1), texturesize*(y-1), texturesize, texturesize, texturesize*3, texturesize*3))
		end
	end
	
	logoimg = love.graphics.newImage("graphics/logo.png")
	menuartimg = love.graphics.newImage("graphics/menuart.png")
	menuart2img = love.graphics.newImage("graphics/menuart2.png")
	menuart3img = love.graphics.newImage("graphics/menuart3.png")
	menubackgroundimg = love.graphics.newImage("graphics/menubackground.png")
	menubackgroundnightimg = love.graphics.newImage("graphics/menubackgroundnight.png")
	arrowimg = love.graphics.newImage("graphics/arrow.png")
	lockimg = love.graphics.newImage("graphics/lock.png")
	endingartimg = love.graphics.newImage("graphics/endingart.png")
	
	--FONTS
	hudfont = love.graphics.newImageFont("graphics/font.png", "abcdefghijklmnopqrstuvwxyz0123456789.!?_-+:☐☑<>I ", 1)
	love.graphics.setFont(hudfont)
	
	--AUDIO
	menumusic = love.audio.newSource("sounds/menu.ogg", "stream"); menumusic:setLooping(true)
	gamemusic = {}
	gamemusic[1] = love.audio.newSource("sounds/game1.ogg", "stream"); gamemusic[1]:setLooping(true); gamemusic[1]:setVolume(0.3)
	gamemusic[2] = love.audio.newSource("sounds/game2.ogg", "stream"); gamemusic[2]:setLooping(true); gamemusic[2]:setVolume(0.6)
	--gamemusic[3] = love.audio.newSource("sounds/game3.ogg", "stream"); gamemusic[3]:setLooping(true); gamemusic[3]:setVolume(0.9)
	--gamemusic[4] = love.audio.newSource("sounds/game4.ogg", "stream"); gamemusic[4]:setLooping(true); gamemusic[4]:setVolume(0.9)
	sounds = {}
	sounds["select"] = love.audio.newSource("sounds/select.ogg", "static")
	sounds["select2"] = love.audio.newSource("sounds/select2.ogg", "static")
	sounds["button"] = love.audio.newSource("sounds/button.ogg", "static")
	
	sounds["jump"] = love.audio.newSource("sounds/jump.ogg", "static")
	sounds["wrench"] = love.audio.newSource("sounds/wrench.ogg", "static")
	sounds["land"] = love.audio.newSource("sounds/land.ogg", "static")
	sounds["push"] = love.audio.newSource("sounds/push.ogg", "static")
	sounds["spring"] = love.audio.newSource("sounds/spring.ogg", "static")
	sounds["ice"] = love.audio.newSource("sounds/ice.ogg", "static"); sounds["ice"]:setLooping(true)
	sounds["teleport"] = love.audio.newSource("sounds/teleport.ogg", "static")
	sounds["rotate"] = love.audio.newSource("sounds/rotate.ogg", "static")
	sounds["switch"] = love.audio.newSource("sounds/switch.ogg", "static")
	sounds["undo"] = love.audio.newSource("sounds/undo.ogg", "static")
	
	--LEVELS
	leveliconimg = love.graphics.newImage("levels/icons.png")
	levelinfo = {}
	local f = love.filesystem.getDirectoryItems("levels")
	for i, n in pairs(f) do
		if tonumber(n:sub(1, -5)) and n:sub(-3) == "png" then
			levelinfo[tonumber(n:sub(1, -5))] = {}
		end
	end
	local s = love.filesystem.read("levels/info.txt")
	s = s:gsub("\r\n", "") --get rid of spacing
	local s2 = s:split("~")
	for i = 1, #levelinfo do
		local d = s2[i]:split("`")
		levelinfo[i].name = d[1] --name of level
		levelinfo[i].depth = tonumber(d[2]) --layers
		levelinfo[i].quad = love.graphics.newQuad(100*(i-1), 0, 100, 100, leveliconimg:getWidth(), 100) --image
		levelinfo[i].wrench = {all = false} --wrenches collected
		for n = 1, tonumber(d[3]) do
			levelinfo[i].wrench[n] = false
		end
		levelinfo[i].lock = {true, tonumber(d[4])} --how many wrenches it takes to unlock 
		levelinfo[i].help = {d[5] or false} --help pop-up at beginning of level 
		if levelinfo[i].help[1] then	levelinfo[i].help[1] = d[5]:gsub("*", "\n") end
		levelinfo[i].background = tonumber(d[6]) or 1
		levelinfo[i].music = tonumber(d[7]) or 1
	end
	loadsave()
	
	
	
	--setgamestate("ending")
	setgamestate("intro")
	--setgamestate("menu")
end

function love.update(dt)
	dt = math.min(0.06, dt)
	if _G[gamestate].update then
		_G[gamestate].update(dt)
	end
end

function love.draw()
	if rescale then
		love.graphics.scale(scale[1], scale[2])
	end
	if _G[gamestate].draw then
		_G[gamestate].draw()
	end
end

function love.keypressed(key)
	if key == "f11" then
		if math.floor(scale[1]) == scale[1] and scale[1] < 6 then
			setscale(6)
		else
			setscale(2)
		end
	end
	
	if _G[gamestate].keypressed then
		_G[gamestate].keypressed(key)
	end
end

function love.keyreleased(key)
	if _G[gamestate].keyreleased then
		_G[gamestate].keyreleased(key)
	end
end

function love.mousepressed(x, y, button)
	local x, y = love.mouse.getX(), love.mouse.getY()
	if _G[gamestate].mousepressed then
		_G[gamestate].mousepressed(x, y, button)
	end
end

function love.mousereleased(x, y, button)
	local x, y = love.mouse.getX(), love.mouse.getY()
	if _G[gamestate].mousereleased then
		_G[gamestate].mousereleased(x, y, button)
	end
end

function love.wheelmoved(x, y)
	if _G[gamestate].wheelmoved then
		_G[gamestate].wheelmoved(x, y)
	end
end

function love.mousemoved(x, y, dx, dy)
	local x, y, dx, dy = love.mouse.getX(), love.mouse.getY(), dx/scale[1], dy/scale[2]
	if _G[gamestate].mousemoved then
		_G[gamestate].mousemoved(x, y, dx, dy)
	end
end

function setgamestate(state, args)
	love.audio.stop()
	assert(_G[state], "Invalid game state")
	gamestate = state
	local args = args or {}
	_G[state].load(unpack(args))
end

function savesettings()
	local s = volume .. "~"
	s = s .. scale[1] .. "~"
	s = s .. tostring(vsync) .. "~"
	s = s .. msaa .. "~"
	s = s .. graphicsquality .. "~"
	for i = 1, #controlstable-1 do
		s = s .. controls[controlstable[i]] .. "`"
	end
	s = s .. controls[controlstable[#controlstable]]
	
	
	love.filesystem.write("settings", s)
end

function loadsettings()
	local s = love.filesystem.read("settings")
	local s2 = s:split("~")
	
	volume = tonumber(s2[1])
	scale = {tonumber(s2[2]), tonumber(s2[2])}
	vsync = (s2[3] == "true")
	msaa = tonumber(s2[4])
	
	setgraphicsquality(s2[5])
	
	local s3 = s2[6]:split("`")
	defaultcontrols()
	for i = 1, #s3 do
		controls[controlstable[i]] = s3[i]
	end
end
function defaultsettings()
	volume = 1
	scale = {2, 2}
	vsync = false
	msaa = 0
	
	setgraphicsquality("best")
	
	defaultcontrols()
end

function defaultcontrols()
	controls = {}
	controls["up"] = "w"
	controls["down"] = "s"
	controls["left"] = "a"
	controls["right"] = "d"
	controls["jump"] = "space"
	
	controls["cameral"] = "left"
	controls["camerar"] = "right"
	
	controls["select"] = "return"
	
	controls["undo"] = "r"
end

function loadsave()
	if love.filesystem.exists("save") then
		local s = love.filesystem.read("save")
		local s2 = s:split("~")
		local s3 = s2[1]:split("`")
		for i = 1, #s3 do --collected wrenches
			for n = 1, #s3[i] do
				levelinfo[i].wrench[n] = (s3[i]:sub(n, n) == "t")
			end
		end
	else
		writesave()
	end
	unlocklevels()--unlock levels base on wrenches
end

function writesave()
	local s = ""
	for i = 1, #levelinfo do
		for n = 1, #levelinfo[i].wrench do
			if levelinfo[i].wrench[n] then
				s = s .. "t"
			else
				s = s .. "f"
			end
		end
		s = s .. "`"
	end
	s = s:sub(1, -2)
	love.filesystem.write("save", s)
end

function unlocklevels()
	local ut = {} --unlocked levels
	local c = 0 --number of wrenches 
	for i = 1, #levelinfo do
		levelinfo[i].wrench.all = true
		for n = 1, #levelinfo[i].wrench do
			if levelinfo[i].wrench[n] then c = c + 1 else levelinfo[i].wrench.all = false end
		end
	end
	for i, t in pairs(levelinfo) do--unlock levels base on wrenches
		if t.lock[1] and c >= t.lock[2] then
			table.insert(ut, i)
			t.lock[1] = false
		end
	end
	return ut
end

function setscale(s)
	if s == 6 then --fullscreen
		local _, _, flags = love.window.getMode()
		local w, h = love.window.getDesktopDimensions(flags.display)
		scale = {w/res[1], h/res[2]}
		love.window.setMode(w, h, {vsync = vsync, msaa = msaa, fullscreen = true, fullscreentype = "desktop"})
	else
		scale = {s, s}
		love.window.setMode(math.floor(res[1]*scale[1]), math.floor(res[2]*scale[2]), {vsync = vsync, msaa = msaa, fullscreen = false})
	end
	if s == 1 then
		rescale = false
	else
		rescale = true
	end
end

function setgraphicsquality(q)
	graphicsquality = q --Graphics: Fast, Best, Custom
	if graphicsquality == "best" then
		shadowtype = "best" --type of shadow 
		shadowdepth = 6 --how far "dynamic" shadows can go
		ambientocclusion = true --fake ambient occlusion (light shadow around blocks)
		lensblur = false --blur anything far away 
		usespritebatch = false 
	elseif graphicsquality == "fast" then
		shadowtype = "fast"
		shadowdepth = 2
		ambientocclusion = false
		lensblur = false
		usespritebatch = true
	end
end

function string:split(d)
	local data = {}
	local from, to = 1, string.find(self, d)
	while to do
		table.insert(data, string.sub(self, from, to-1))
		from = to+#d
		to = string.find(self, d, from)
	end
	table.insert(data, string.sub(self, from))
	return data
end

function math.round(v)
	return math.floor(v+.5)
end

function playsound(sound, a)
	if not a then
		sound:stop()
	end
	sound:play()
end

function pausesound(sound)
	sound:pause()
end

function resumesound(sound)
	sound:resume()
end

function stopsound(sound)
	sound:stop()
end

function randomize()
	math.randomseed(os.time())
	for i = 1, 5 do
		math.random()
	end
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--scaling edits
lgs = love.graphics.setScissor
function love.graphics.setScissor(x, y, w, h)
	if x and y and w and h then
		if rescale then
			x, y, w, h = x*scale[1], y*scale[2], w*scale[1], h*scale[2]
		end
		lgs(x, y, w, h)
	else
		lgs()
	end
end

lmx = love.mouse.getX
function love.mouse.getX()
	local x = lmx()
	if rescale then
		x = x/scale[1]
	end
	return x
end
lmy = love.mouse.getY
function love.mouse.getY()
	local y = lmy()
	if rescale then
		y = y/scale[2]
	end
	return y
end
function love.mouse.getPosition()
	local x, y = love.mouse.getX(), love.mouse.getY()
	return x, y
end