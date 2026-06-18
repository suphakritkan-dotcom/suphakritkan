button = class:new()

local ontime = 0.1 --how long mouse has to hover in order to change color of button completely
local releaseduration = 0.5 --how long ripple effect lasts after release
local rippleduration = 0.25 --how long it takes for ripple to fill button. above is the time left for fading away
local buttoncolor = {49, 178, 247}

--button
function button:init(x, y, w, h, t, func, a, c)
	self.x = x
	self.y = y
	self.w = w
	self.h = h
	self.t = t or "" --text
	self.func = func or function() end
	self.a = a or {}
	self.delay = self.a and self.a.delay --call function after button release
	self.c = c or buttoncolor --color
	--calculate colors
	self.highc = {math.min(255, self.c[1]*1.15), math.min(255, self.c[2]*1.15), math.min(255, self.c[3]*1.15)}
	self.holdc = {math.min(255, self.c[1]*.9), math.min(255, self.c[2]*.9), math.min(255, self.c[3]*.9)}
	self.ripplec = {math.min(255, self.c[1]*1.3), math.min(255, self.c[2]*1.3), math.min(255, self.c[3]*1.3)}
	
	self.active = false
	
	self.alpha = 255
	
	self.on = false
	self.ontimer = 0 --time mouse been hovering (0-1)
	self.hold = false
	
	self.ripple = {} --ripple effect when clicking
	self.ripple.x = false
	self.ripple.y = false
	self.ripple.t = false --timer
end

function button:update(dt)
	local mx, my = love.mouse.getPosition()
	--is mosue on button
	self.on = mx >= self.x and my >= self.y and mx <= self.x+self.w and my <= self.y+self.h
	if self.on and not self.ripple.t and not self.hold then
		self.ontimer = math.min(1, self.ontimer+dt/ontime)
	else
		self.ontimer = math.max(0, self.ontimer-dt/ontime)
	end
	
	--update ripple effect
	if self.ripple.t then
		self.ripple.t = self.ripple.t - dt
		if self.ripple.t < 0 then
			self.ripple.t = false
			if self.delay then
				self.func(unpack(self.a))
			end
		end
	end
end

function button:draw()
	if self.alpha <= 0 then
		return
	end
	
	--actual button
	    if self.ontimer > 0 then
		love.graphics.setColor(self.c[1]*(1-self.ontimer)+self.highc[1]*self.ontimer, self.c[2]*(1-self.ontimer)+self.highc[2]*self.ontimer, self.c[3]*(1-self.ontimer)+self.highc[3]*self.ontimer, self.alpha)
	else
		love.graphics.setColor(self.c[1], self.c[2], self.c[3], self.alpha)
	end
	love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
	--ripple
	if self.ripple.t then
		local d = {math.sqrt((-self.ripple.x)^2+(-self.ripple.y)^2), math.sqrt((self.w-self.ripple.x)^2+(-self.ripple.y)^2), math.sqrt((self.w-self.ripple.x)^2+(self.h-self.ripple.y)^2), math.sqrt((-self.ripple.x)^2+(self.h-self.ripple.y)^2)}
		local big = false
		for i = 1, 4 do
			if not big or d[i] > d[big] then
				big = i
			end
		end
		local r = d[big]*(1-math.max(0, (self.ripple.t-(releaseduration-rippleduration))/rippleduration)) --radius
		love.graphics.setScissor(self.x, self.y, self.w, self.h)
		love.graphics.setColor(self.ripplec[1], self.ripplec[2], self.ripplec[3], math.min(1, self.ripple.t/(releaseduration-rippleduration))*self.alpha)
		love.graphics.circle("fill", self.x+self.ripple.x, self.y+self.ripple.y, r)
		love.graphics.setScissor()
	end
	--border
	love.graphics.setColor(255, 255, 255, self.alpha)
	love.graphics.draw(buttonimg, buttonq[1], self.x, self.y)
	love.graphics.draw(buttonimg, buttonq[2], self.x+texturesize, self.y, 0, (self.w-texturesize*2)/texturesize, 1)
	love.graphics.draw(buttonimg, buttonq[3], self.x+self.w-texturesize, self.y)
	love.graphics.draw(buttonimg, buttonq[4], self.x, self.y+texturesize, 0, 1, (self.h-texturesize*2)/texturesize)
	love.graphics.draw(buttonimg, buttonq[6], self.x+self.w-texturesize, self.y+texturesize, 0, 1, (self.h-texturesize*2)/texturesize)
	love.graphics.draw(buttonimg, buttonq[7], self.x, self.y+self.h-texturesize)
	love.graphics.draw(buttonimg, buttonq[8], self.x+texturesize, self.y+self.h-texturesize, 0, (self.w-texturesize*2)/texturesize, 1)
	love.graphics.draw(buttonimg, buttonq[9], self.x+self.w-texturesize, self.y+self.h-texturesize)
	--text
	love.graphics.setColor(255, 255, 255, self.alpha)
	love.graphics.setFont(hudfont)
	love.graphics.print(self.t, self.x+math.floor((self.w-hudfont:getWidth(self.t))/2), self.y+math.floor((self.h-hudfont:getHeight())/2))
end

function button:pressed(x, y, b)
	if b == 1 and self.on then
		self.hold = true
	end
end

function button:released(x, y, b)
	if b == 1 and self.hold and x >= self.x and y >= self.y and x <= self.x+self.w and y <= self.y+self.h then
		if self.on and not self.ripple.t then
			self.ripple.x = x-self.x
			self.ripple.y = y-self.y
			self.ripple.t = releaseduration
			if not self.delay then --if func is not delayed then call function
				self.func(unpack(self.a))
			end
			playsound(sounds["button"])
		end
		self.hold = false
	end
end