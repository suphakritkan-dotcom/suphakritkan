intro = {}

local transitiontime = 1.1 --time it takes to transition
local transitionin = true
local transitionout = false
local timer = 0
local introtime = 3.8
local introskip = false
local introimg

function intro.load(s)
	--fade in
	transitionin = true
	timer = 0
	love.graphics.setBackgroundColor(0, 0, 0)
	
	introimg = love.graphics.newImage("graphics/loading.png")
end

function intro.update(dt)
	timer = timer + dt
	if timer > introtime then
		setgamestate("menu", {"main"})
		return
	end
	transitionin = (timer < transitiontime)
	transitionout = (timer > introtime-transitiontime)
end

function intro.draw()
	--background
	local a = 1
	if transitionin then
		a = timer/transitiontime*1
	elseif transitionout then
		a = -(timer-introtime)/transitiontime*1
	end
	love.graphics.setColor(1, 1, 1, a)
	love.graphics.draw(introimg, 0.537, 0.419)
end

function intro.skip()
	if transitionout then
		timer = introtime
	else
		timer = math.max(introtime-transitiontime, introtime-timer)
	end
	introskip = true
end

function intro.keypressed(k)
	if k == "-" then 
		if gamemusic[1] then
			gamemusic[1]:setVolume(0)
		end
		if gamemusic[2] then
			gamemusic[2]:setVolume(0)
		end
		if menumusic then
			menumusic:setVolume(0)
		end
	end
	if not introskip then
		intro.skip()
	end
end

function intro.mousepressed(x, y, b)
	if not introskip then
		intro.skip()
	end
end

function intro.mousereleased(x, y, b)
end