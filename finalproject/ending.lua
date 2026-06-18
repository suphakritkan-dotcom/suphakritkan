ending = {}

local endingtime = 18
local transitiontime = 2 --time it takes to transition
local transitionin = true
local transitionout = false
local timer = 0
local artanimation = 0
local wrenchanimtimer = 0
local wrenchanimdelay = 0.22

function ending.load(s)
	--fade in
	transitionin = true
	
	artanimation = 0
	wrenchanimtimer = 0
end

function ending.update(dt)
	timer = timer + dt
	if timer > endingtime then
		setgamestate("menu", {"main"})
	end
	
	transitionin = (timer < transitiontime)
	transitionout = (timer > endingtime-transitiontime)
	
	artanimation = math.min(artanimation+0.25*dt, (artanimation+0.25*dt)%1)
	wrenchanimtimer = (wrenchanimtimer + dt)%(wrenchanimdelay*8)
end

function ending.draw()
	--background
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(menubackgroundimg)
	--wrenches
	love.graphics.setColor(255, 255, 255, 255)
	local wrenches = 16
	for i = 1, wrenches do
		love.graphics.draw(gamesprites, wrenchq[math.max(1, math.ceil(wrenchanimtimer/wrenchanimdelay))], 213-8+100*math.sin(math.pi*2/wrenches*(i+artanimation)), 130+100*math.cos(math.pi*2/wrenches*(i+artanimation)))
	end
	--art
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(endingartimg, 158, 76+7*math.sin(artanimation*math.pi*2))
	--text
	local v = 1-math.min(1, (timer-transitiontime/2)/3)
	love.graphics.setColor(255, 255, 255, 255-255*v*v)
	love.graphics.printf("congratulations!\nbrItebot has retrieved all the wrenches\n\n\n\nthank you for playing!", 0, 50+((res[2]-50)*(v))*v, res[1], "center")
	--fading
	local a = 0
	if transitionin then
		a = math.max(0, 1-(timer-(transitiontime/2))/(transitiontime/2))*255
		love.graphics.setColor(255, 255, 255, a)
		love.graphics.rectangle("fill", 0, 0, res[1], res[2])
		a = math.min(1, 1-timer/(transitiontime/2))*255
		love.graphics.setColor(0, 0, 0, a)
		a = math.min(1, 1-timer/(transitiontime/2))*255
		love.graphics.setColor(0, 0, 0, a)
	elseif transitionout then
		a = (timer-endingtime+transitiontime)/transitiontime*255
		love.graphics.setColor(0, 0, 0, a)
	else
		love.graphics.setColor(255, 255, 255, a)
	end
	love.graphics.rectangle("fill", 0, 0, res[1], res[2])
end