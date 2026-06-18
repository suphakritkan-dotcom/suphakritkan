menu = {}

local transitionfrom --what state is being transitioned
local updatewindow --update window if settings are changed
local targetscale
local setcontrol --wait for control change
local setcontrolblink
local buttonselected
local mouseselected
local helpdialog --is help dialog showing
local helpdialoga --alpha
local levelselection = 1--what level is being selected
local levelselectt --how long it takes to switch levels
local levelselecttime = 0.28--time it takes to switch level selection
local levelselectarrow --move arrows
local transitionout --when level is selected transition into game
local transitionouttime = 2
local transitionoutblacktime = 1.5 --how long it's black
local transitionoutmovetime = 0.45 --how long it takes for text to move
local transitionoutstencil = function() --circle transition
	local r = math.max(0, (transitionout-transitionoutblacktime)/(transitionouttime-transitionoutblacktime))*248
	if r > 0.5 then
		love.graphics.circle("fill", res[1]/2, res[2]/2, r)
	end
end
local transitiontime = 0.4 --how long it takes to transition between states
local transitionin = false
local transitionintime = .38
local transitioninstencil = function() --circle transition
	local r = (1-transitionin/transitionintime)*248
	if r > 0.5 then
		love.graphics.circle("fill", res[1]/2, res[2]/2, r)
	end
end
local introtransition = true; transitionin = transitionintime --transition from intro (only set to true on startup and ending)
local wrenchcount
local unlockedlevels
local titleanimation = 0 --number between 0-1 used for title art

local maxleveltravel --how far you can see levels. 

local settingslist = {
	--so here's how it works {name, get value (v, max, min, step), set value}
	{"volume", function() return volume*100, 150, 0, 10 end, function(v) volume = math.floor(v)/100; love.audio.setVolume(volume) end},
	{"window size", function() return targetscale, 5, 1, 1 end, function(v) targetscale = v; updatewindow = true end, function() return "x" .. targetscale end},
	{"vsync", function() return vsync end, function(v) vsync = v; updatewindow = true end},
	{"antialiasing", function() return msaa, maxmsaa, 0, 1 end, function(v) msaa = v; updatewindow = true end},
	{"good graphics", function() return (graphicsquality == "best") end, function(v) if v then setgraphicsquality("best") else setgraphicsquality("fast") end end}
	}

function menu.load(s)
	love.graphics.setBackgroundColor(138, 179, 198)
	
	menustate = "main"
	menutransition = true
	transitiontimer = 0
	transitionfrom = "main"
	
	settingsstate = "general"
	settingsselection = 1
	setcontrol = false --queue controls change
	setcontrolblink = 0
	updatewindow = false
	targetscale = scale[1]
	
	buttonselected = false --select button with no mouse
	mouseselected = false --is mouse currently selecting something
	
	titleanimation = 0 --art animation
	helpdialog = false --show help
	helpdialoga = 0
	
	--levelselection = 1
	levelselectarrow = 0
	transitionout = false
	introtransition = (s == "main") --fade in
	transitionin = (s == "main")
	
	unlockedlevels = false
	wrenchcount = 0 --number of wrenches 
	for i = 1, #levelinfo do
		for n = 1, #levelinfo[i].wrench do
			if levelinfo[i].wrench[n] then wrenchcount = wrenchcount + 1 end
		end
	end
	maxleveltravel = #levelinfo-bonuslevels
	if wrenchcount >= unlockbonus then--unlock bonus levels
		maxleveltravel = #levelinfo
	end
	
	--GUI
	buttons = {}
	buttons.select = button:new(32, 103, 128, 35, "start", function() menu.setstate("select"); buttonselected = "start"; levelselectarrow = 0 end, {delay = true}) --select level
	buttons.settings = button:new(32, 146, 128, 35, "settings", function() menu.setstate("settings"); updatewindow = false; targetscale = scale[1] end, {delay = true}) --open settings menu
	buttons.quit = button:new(32, 189, 60, 35, "quit", love.event.quit) --exit game
	buttons.help = button:new(100, 189, 60, 35, "help", function() helpdialog = not helpdialog end) 
	
	buttons.back = button:new(32, 189, 128, 35, "back", function() if updatewindow then setscale(targetscale) end; love.audio.setVolume(volume); savesettings(); menu.setstate("main"); helpdialog = false; helpdialoga = 0; setcontrol = false end, {delay = true})--go back to main settings
	
	buttons.reset = button:new(32, 146, 128, 35, "reset", function() defaultsettings(); targetscale = 2; updatewindow = true; setscale(targetscale); love.audio.setVolume(volume) end)--reset settings
	
	buttons.back2 = button:new(16, 189, 64, 35, "back", function() menu.setstate("main"); helpdialog = false; helpdialoga = 0 end, {delay = true})
	buttons.start = button:new(156, 180, 114, 44, "begin", function() if not levelinfo[levelselection].lock[1] then transitionout = transitionouttime; menu.activatebuttons(false) end end, {delay = true})
	
	menu.activatebuttons(menustate)
	
	if s then--set menu state
		menustate = s; transitionfrom = s; menu.activatebuttons(s); transitionin = transitionintime
		if s == "select" then
			local u = unlocklevels()
			if #u > 0 then
				unlockedlevels = u
				levelselection = levelselection + 1
				levelselectt = levelselecttime
			else
				unlockedlevels = false
			end
			buttonselected = "start"
		end
	end
	
	playsound(menumusic)
end

function menu.update(dt)
	if transitionin then
		transitionin = transitionin - dt
		if transitionin < 0 then
			transitionin = false
			introtransition = false
		end
	end
	
	if menustate == "main" then
		if helpdialog and helpdialoga < 1 then
			helpdialoga = math.min(1, helpdialoga + dt*2)
		elseif not helpdialog and helpdialoga > 0 then
			helpdialoga = math.max(0, helpdialoga - dt*2)
		end
		
		titleanimation = math.min(titleanimation+0.2*dt, (titleanimation+0.2*dt)%1)
	elseif menustate == "settings" then
		if settingsstate == "general" then
			
		elseif settingsstate == "controls" then
			if setcontrol then --make control placeholder blink
				setcontrolblink = setcontrolblink + dt*1.3
				while setcontrolblink > 1 do
					setcontrolblink = setcontrolblink - 1
				end
			end
		end
	elseif menustate == "select" then
		if levelselectt and not transitionin then --move level previews smoothly
			if levelselectt then
				if levelselectt > 0 then
					levelselectt = levelselectt - dt
					if levelselectt < 0 then
						levelselectt = false
						if unlockedlevels then
							if levelselection == unlockedlevels[1] then
								table.remove(unlockedlevels, 1)
							end
							if #unlockedlevels > 0 then
								levelselection = levelselection + 1
								levelselectt = levelselecttime
							else
								unlockedlevels = false
							end
						end
					end
				else
					levelselectt = levelselectt + dt
					if levelselectt > 0 then
						levelselectt = false
						if unlockedlevels then
							if levelselection == unlockedlevels[1] then
								table.remove(unlockedlevels, 1)
							end
							if #unlockedlevels > 0 then
								levelselection = levelselection + 1
								levelselectt = levelselecttime
							else
								unlockedlevels = false
							end
						end
					end
				end
			end
		end
		if not levelselectt then --don't move arrows if changing level
			if love.keyboard.isDown(controls["left"]) or love.keyboard.isDown("left") then --hold keys to select
				menu.keypressed(controls["left"])
			elseif love.keyboard.isDown(controls["right"]) or love.keyboard.isDown("right") then
				menu.keypressed(controls["right"])
			else
				levelselectarrow = (levelselectarrow + dt*1.4)%1 --move level select world
			end
		end
		if transitionout then --circle transition
			transitionout = transitionout - dt
			if transitionout < 0 then
				buttons = {}
				setgamestate("game", {levelselection})
			end
		end
	end
	
	if menutransition then --transition
		transitiontimer = transitiontimer - dt
		if transitiontimer < 0 then
			transitiontimer = 0
			menutransition = false
			transitionfrom = false
			menu.activatebuttons(menustate, true)
		else
			for i, b in pairs(buttons) do
				if b.active then
					b.alpha = 255-(transitiontimer/transitiontime)*255
				else
					b.alpha = (transitiontimer/transitiontime)*255
				end
			end
		end
	end
	
	--update buttons
	for i, b in pairs(buttons) do
		if b.active or b.ripple.t then
			b:update(dt)
			if buttonselected == i then
				b.on = true; b.ontimer = 1
			end
		end
	end
end

function menu.draw()
	--background
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(menubackgroundimg)
	if levelselection >= #levelinfo-bonuslevels then --bonus background
		local v = 1
		if levelselection == #levelinfo-bonuslevels+1 and levelselectt then
			v = 1-levelselectt/levelselecttime
		elseif levelselection == #levelinfo-bonuslevels then
			if levelselectt and levelselectt < 0 then
				v = -levelselectt/levelselecttime
			else
				v = 0
			end
		end
		love.graphics.setColor(255, 255, 255, 255*v)
		love.graphics.draw(menubackgroundnightimg)
	end
	--ui
	if menustate == "select" or transitionfrom == "select" then
		--bonus level background
		--level select
		buttons.back2:draw()
		buttons.start:draw()
		
		local fadev = (1-(transitiontimer/transitiontime)) --fading
		if transitionfrom == "select" then fadev = (transitiontimer/transitiontime) end
		love.graphics.setColor(255, 255, 255, 255*fadev)
		love.graphics.setFont(hudfont)
		love.graphics.print(wrenchcount, res[1]-16-(hudfont:getWidth(wrenchcount)), res[2]-35)
		local q = 2
		if levelinfo[#levelinfo].wrench.all then --if last level has all wrenches collected, then the game is complete
			q = 3
		end
		love.graphics.draw(wrenchiconimg, wrenchiconq[q], res[1]-16-(hudfont:getWidth(wrenchcount))-24, res[2]-36)
		--draw previews with better rotating
		love.graphics.setColor(255, 255, 255, 255*fadev)
		for i = math.max(1, levelselection-2), math.min(maxleveltravel, levelselection+2) do
			local x = 163 + (i-levelselection)*200
			if levelselectt then
				local v = levelselectt/levelselecttime
				if levelselectt > 0 then
					x = x + (v*(200*v))
				else
					x = x - (v*(200*v))
				end
			end
			
			local s = 1-(math.abs(x-163)/163)*0.15
			
			if levelinfo[i].lock[1] or (unlockedlevels and unlockedlevels[1] <= i) then --locked level
				love.graphics.setColor(96, 96, 96, 192*fadev)
				love.graphics.draw(leveliconimg, levelinfo[i].quad, x+50, 65+58, 0, s, s, 50, 50)
				local r = 0
				if (unlockedlevels and unlockedlevels[1] == i) then --shake lock
					r = math.sin(levelselecttime-levelselectt*math.pi*15)*(1-(levelselectt/levelselecttime))
				end
				love.graphics.setColor(255, 255, 255, 255*fadev)
				love.graphics.draw(lockimg, x+50, 65+58, r, s, s, 32, 32)
				love.graphics.print(levelinfo[i].lock[2], math.floor(x+50), 65+62+(10*s), 0, s, s, math.floor(hudfont:getWidth(levelinfo[i].lock[2])/2), hudfont:getHeight()/2)
			else --draw level at normal brightness if unlocked
				love.graphics.draw(leveliconimg, levelinfo[i].quad, x+50, 65+58, 0, s, s, 50, 50)
			end
		end
		
		if levelselection > 1 then --left arrow
			local y = 96
			if levelselectt and levelselectt < 0 then y = 5*math.sin(math.abs(levelselectt/levelselecttime)*math.pi) + y end
			love.graphics.draw(arrowimg, 16+(math.sin(math.pi*2*levelselectarrow))*8, y)
		end
		if levelselection < maxleveltravel then --right arrow
			local y = 96
			if levelselectt and levelselectt > 0 then y = 5*math.sin((levelselectt/levelselecttime)*math.pi) + y end
			love.graphics.draw(arrowimg, res[1]-16-(math.sin(math.pi*2*levelselectarrow))*8, y, 0, -1, 1, 0, 0)
		end
		
		--transition out 
		if transitionout then
			love.graphics.setColor(0, 0, 0)
			love.graphics.stencil(transitionoutstencil, "replace", 1)
			love.graphics.setStencilTest("less", 1)
			love.graphics.rectangle("fill", 0, 0, res[1], res[2])
			love.graphics.setStencilTest()
			if transitionout < transitionoutmovetime then
				love.graphics.push()
				local v = 1-(transitionout/transitionoutmovetime)
				love.graphics.translate(0, -(v*(95*v)))
			end
		end
		
		--text & info
		love.graphics.setColor(255, 255, 255, 255*fadev)
		love.graphics.print("level " .. levelselection, math.floor((res[1]-hudfont:getWidth("level " .. levelselection))/2), 18)
		love.graphics.setColor(255, 198, 56, 255*fadev)
		love.graphics.print(levelinfo[levelselection].name, math.floor((res[1]-hudfont:getWidth(levelinfo[levelselection].name))/2), 40)
		love.graphics.setColor(255, 255, 255, 255*fadev)
		for i = 1, #levelinfo[levelselection].wrench do --collected wrenches
			local q = 1
			if levelinfo[levelselection].wrench.all then q = 3
			elseif levelinfo[levelselection].wrench[i] then q = 2 end
			love.graphics.draw(wrenchiconimg, wrenchiconq[q], math.floor(res[1]/2+(22*(i-1-#levelinfo[levelselection].wrench/2))), 62)
		end
		
		if transitionout and transitionout < transitionoutmovetime then
			love.graphics.pop()
		end
		
		--transition in
		if transitionin then
			love.graphics.setColor(0, 0, 0)
			love.graphics.stencil(transitioninstencil, "replace", 1)
			love.graphics.setStencilTest("less", 1)
			love.graphics.rectangle("fill", 0, 0, res[1], res[2])
			love.graphics.setStencilTest()
		end
	end
	if menustate == "main" or menustate == "settings" or transitionfrom == "main" then
		if menustate == "main" or transitionfrom == "main" then
			--logo and art
			local fadev = (1-(transitiontimer/transitiontime))
			if transitionfrom == "main" then fadev = (transitiontimer/transitiontime) end
			love.graphics.setColor(255, 255, 255, 255*fadev)
			love.graphics.draw(menuartimg, 268, 83+6*math.sin(titleanimation*math.pi*2))
			if levelinfo[#levelinfo].wrench.all then
				love.graphics.draw(menuart3img, 196, 116+4*math.sin(titleanimation*math.pi*2))
			else
				love.graphics.draw(menuart2img, 196, 116+4*math.sin(titleanimation*math.pi*2))
			end
			love.graphics.draw(logoimg, 54, 12)
			--buttons
			buttons.select:draw()
			buttons.settings:draw()
			buttons.quit:draw()
			buttons.help:draw()
			
			if helpdialoga > 0 then
				--help
				local fadev = helpdialoga --fading
				if transitionfrom == "main" then fadev = fadev*(transitiontimer/transitiontime) end
				love.graphics.setColor(24, 23, 33, 216*fadev)
				love.graphics.rectangle("fill", 178, 16, 232, 208)
				love.graphics.setColor(255, 255, 255, 255*fadev)
				
				love.graphics.print({
					{255, 255, 255},
					"control ",
					{255, 255, 255},
					"brItebot\n",
					{255, 255, 255},
					"to collect the\n",
					{255, 198, 56},
					"wrenches",
					{255, 255, 255},
					"!\n\nmove and jump\nin order to\nfind and reach\nthe ",
					{255, 198, 56},
					"wrenches",
					{255, 255, 255},
					"\nin each level."
				}, 190, 32)
			end
		end
		
		--settings pop up
		if menustate == "settings" or transitionfrom == "settings" then
			buttons.back:draw()
			buttons.reset:draw()
			
			love.graphics.setFont(hudfont)
			
			local fadev = (1-(transitiontimer/transitiontime)) --fading
			if transitionfrom == "settings" then fadev = (transitiontimer/transitiontime) end
			love.graphics.setColor(255, 255, 255, 255*fadev)
			love.graphics.draw(logoimg, 32, 16, 0, 128/logoimg:getWidth(), 128/logoimg:getWidth())
			
			love.graphics.setColor(24, 23, 33, 128*fadev)
			love.graphics.rectangle("fill", 178, 51, 232, 173)
			--tabs
			if settingsselection == 0 then
				love.graphics.setColor(24, 23, 33, 25*fadev)
				if settingsstate == "general" then
				love.graphics.rectangle("fill", 178, 16, 114, 35) else
				love.graphics.rectangle("fill", 296, 16, 114, 35) end
			end
			if settingsstate == "general" then
				love.graphics.setColor(24, 23, 33, 128*fadev) else
				love.graphics.setColor(24, 23, 33, 96*fadev) end
			love.graphics.rectangle("fill", 178, 16, 114, 35)
			if settingsstate == "general" then
				love.graphics.setColor(255, 255, 255, 255*fadev) else
				love.graphics.setColor(255, 255, 255, 128*fadev) end
			love.graphics.print("general", 190, 25)
			if settingsstate == "general" then
				love.graphics.setColor(24, 23, 33, 96*fadev) else
				love.graphics.setColor(24, 23, 33, 128*fadev) end
			love.graphics.rectangle("fill", 296, 16, 114, 35)
			if settingsstate == "general" then
				love.graphics.setColor(255, 255, 255, 128*fadev) else
				love.graphics.setColor(255, 255, 255, 255*fadev) end
			love.graphics.print("controls", 301, 25)
			--actual settings
			if settingsstate == "general" then
				for i, t in pairs(settingslist) do
					if settingsselection == i then
						love.graphics.setColor(24, 23, 33, 60*fadev)
						love.graphics.rectangle("fill", 184, 60+(32*(i-1)), 221, 26)
					end
					love.graphics.setColor(255, 255, 255, 255*fadev)
					love.graphics.print(t[1], 188, 64+(32*(i-1)))
					local s = t[2]()
					if t[4] then s = t[4]() end
					if type(s) == "string" or type(s) == "number" then --print text
						s = "<" .. s .. ">"
						love.graphics.print(s, 400-hudfont:getWidth(s), 64+(32*(i-1)))
					else --check mark box
						local c = "☐"
						if s then c = "☑" end
						love.graphics.print(c, 400-hudfont:getWidth(c), 64+(32*(i-1)))
					end
				end
			else
				local y = 52
				for i, t in pairs(controlstable) do
					if settingsselection == i then
						love.graphics.setColor(24, 23, 33, 60*fadev)
						love.graphics.rectangle("fill", 184, y+(19*(i-1)), 221, 20)
					end
					love.graphics.setColor(255, 255, 255, 255*fadev)
					love.graphics.print(controlstable[i], 188, y+1+(19*(i-1)))
					local s = controls[controlstable[i]]
					if i == setcontrol then
						s = ""
						if setcontrolblink < 0.5 then s = "_" end
					end
					love.graphics.print(s, 400-hudfont:getWidth(s), y+1+(19*(i-1)))
				end
			end
		end
	end
	if transitionin and introtransition then --intro transition 
		love.graphics.setColor(0, 0, 0, (transitionin/transitionintime)*255)
		love.graphics.rectangle("fill", 0, 0, res[1], res[2])
	end
end

function menu.keypressed(k)	
	if menustate == "main" then
		--select buttons without mouse
		if k == controls["down"] or k == "down" then
			if buttonselected == "select" then
				buttonselected = "settings"
			elseif buttonselected == "settings" then
				buttonselected = "quit"
			elseif not buttonselected then
				buttonselected = "select"
			end
		elseif k == controls["up"] or k == "up" then
			if buttonselected == "settings" then
				buttonselected = "select"
			elseif buttonselected == "quit" or buttonselected == "help" then
				buttonselected = "settings"
			elseif not buttonselected then
				buttonselected = "select"
			end
		elseif k == controls["left"] or k == "left" then
			if buttonselected == "help" then
				buttonselected = "quit"
			elseif not buttonselected then
				buttonselected = "select"
			end
		elseif k == controls["right"] or k == "right" then
			if buttonselected == "quit" then
				buttonselected = "help"
			elseif not buttonselected then
				buttonselected = "select"
			end
		elseif k == controls["select"] or k == "space" then
			if buttonselected then
				local b =  buttons[buttonselected]
				local click = true --only click if no other buttons are pressed
				for i, bu in pairs(buttons) do
					if bu.ripple.t then
						click = false
						break
					end
				end
				if click and b.active then
					b.hold = true
					b.on = true
					b.ripple.t = false
					b:released(b.x+b.w/2, b.y+b.h/2, 1)
				end
			else
				buttonselected = "select"
			end
		elseif k == "escape" then
			 love.event.quit()
		end
	elseif menustate == "select" then
		if transitionout or transitionin or unlockedlevels or buttons.start.ripple.t then
			return
		end
		--level selection navigation
		if k == controls["down"] or k == "down" then
			if buttonselected == "start" then
				buttonselected = "back2"
			elseif not buttonselected then
				buttonselected = "start"
			end
		elseif k == controls["up"] or k == "up" then
			if buttonselected == "back2" then
				buttonselected = "start"
			elseif not buttonselected then
				buttonselected = "start"
			end
		elseif k == controls["select"] or k == "space" then
			if buttonselected then
				local b =  buttons[buttonselected]
				local click = true --only click if no other buttons are pressed
				for i, bu in pairs(buttons) do
					if bu.ripple.t then
						click = false
						break
					end
				end
				if click and b.active then
					b.hold = true
					b.on = true
					b.ripple.t = false
					b:released(b.x+b.w/2, b.y+b.h/2, 1)
				end
			else
				buttonselected = "start"
			end
		end
		if not levelselectt then --switch level selection
			if k == controls["left"] or k == "left" then --go back
				if levelselection > 1 then
					levelselection = levelselection - 1
					levelselectt = -levelselecttime
				end
			elseif k == controls["right"] or k == "right" then --go forward
				if levelselection < maxleveltravel then
					levelselection = levelselection + 1
					levelselectt = levelselecttime
				end
			end
		end
	elseif menustate == "settings" then
		--settings navigation
		if not setcontrol then
			if k == controls["left"] or k == "left" or k == controls["right"] or k == "right" then
				if settingsselection == 0 then --switch tabs
					if buttonselected then
						buttonselected = false
						if k == controls["left"] or k == "left" then
							settingsstate = "controls"
						else
							settingsstate = "general"
						end
					elseif settingsstate == "general" then
						if k == controls["left"] or k == "left" then
							buttonselected = "back"
						else
							settingsstate = "controls"
						end
					else
						settingsstate = "general"
					end
				else --change settings
					local t = settingslist[settingsselection]
					local v, max, min, step = t[2]()
					if type(v) == "number" then
						local n
						if k == controls["left"] or k == "left" then --decrease
							n = math.floor(v*100-step*100)/100
							if n < min then
								n = max
							end
						else --increase
							n = v+step
							if n > max then
								n = min
							end
						end
						t[3](n)
					else --boolean
						t[3](not v)
					end
					playsound(sounds["select2"])
				end
			elseif k == controls["up"] or k == "up" then --change selection
				if buttonselected then
					if buttonselected == "back" then
						buttonselected = "reset"
					end
				else
					settingsselection = math.max(0, settingsselection - 1)
					playsound(sounds["select"])
				end
			elseif k == controls["down"] or k == "down" then
				if buttonselected then
					if buttonselected == "reset" then
						buttonselected = "back"
					end
				else
					if settingsstate == "general" then
						settingsselection = math.min(#settingslist, settingsselection + 1)
					else
						settingsselection = math.min(#controlstable, settingsselection + 1)
					end
					playsound(sounds["select"])
				end
			elseif k == controls["select"] or k == "space" then --change settings
				if buttonselected then
					local b =  buttons[buttonselected]
					local click = true --only click if no other buttons are pressed
					for i, bu in pairs(buttons) do
						if bu.ripple.t then
							click = false
							break
						end
					end
					if click and b.active then
						b.hold = true
						b.on = true
						b.ripple.t = false
						b:released(b.x+b.w/2, b.y+b.h/2, 1)
					end
				elseif settingsselection > 0 then
					if settingsstate == "general" then
						local t = settingslist[settingsselection]
						local v, max, min, step = t[2]()
						if type(v) == "boolean" then
							t[3](not v)
						end
					elseif settingsstate == "controls" then
						setcontrol = settingsselection
						setcontrolblink = 0
					end
				end
			end
		else --change controls
			controls[controlstable[setcontrol]] = k
			setcontrol = false
		end
	elseif menustate == "help" then
		
	end
end

function menu.mousepressed(x, y, b)
	if menustate == "main" then
	elseif menustate == "select" then
		if transitionout or transitionin or unlockedlevels or buttons.start.ripple.t then
			return
		end
		if not levelselectt then
			if y > 76 and x < 100 and y < 158 then
				if levelselection > 1 then
					levelselection = levelselection - 1
					levelselectt = -levelselecttime
				end
			elseif x > res[1]-100 and y > 76 and y < 158 then
				if levelselection < maxleveltravel then
					levelselection = levelselection + 1
					levelselectt = levelselecttime
				end
			end
		end			
	elseif menustate == "settings" then
		if settingsstate == "general" then --select settings with mouse
			if settingsselection > 0 and mouseselected then
				local t = settingslist[settingsselection]
				local v, max, min, step = t[2]()
				if type(v) == "number" then
					local s = v
					if t[4] then s = t[4]() end
					s = "<" .. s .. ">"
					local n
					if x >= 390-hudfont:getWidth(s) and x <= 413-hudfont:getWidth(s) then 
						n = v-step
						if n < min then
							n = max
						end
					else
						n = v+step
						if n > max then
							n = min
						end
					end
					t[3](n)
				elseif type(v) == "boolean" then
					t[3](not v)
				end
			elseif settingsselection == 0 and mouseselected then
				if x > 294 then
					settingsstate = "controls"
				end
			end
		elseif settingsstate == "controls" then
			if settingsselection > 0 and mouseselected then
				setcontrol = settingsselection
				setcontrolblink = 0
			elseif settingsselection == 0 and mouseselected then
				if x < 294 then
					settingsstate = "general"
					setcontrol = false
				end
			end
		end
	end
	
	local click = true --only click if no other buttons are pressed
	for i, bu in pairs(buttons) do
		if bu.ripple.t then
			click = false
			break
		end
	end
	if click then
		for i, bu in pairs(buttons) do
			if bu.active then
				bu:pressed(x, y, b)
			end
		end
	end
end

function menu.mousereleased(x, y, b)
	for i, bu in pairs(buttons) do
		if bu.active then
			bu:released(x, y, b)
		end
	end
end

function menu.wheelmoved(x, y)
	
end

function menu.mousemoved(x, y, dx, dy)
	if menustate == "main" then
		if buttonselected then --select button with mouse
			buttonselected = false
		end
	elseif menustate == "select" then
		if buttonselected then
			buttonselected = false
		end
	elseif menustate == "settings" then
		if buttonselected then --select button with mouse
			buttonselected = false
		end
		if settingsstate == "general" then --select settings with mouse
			mouseselected = false
			if x >= 178 and x <= 410 then
				local n = math.floor((y-60)/32)+1
				if n <= 0 then
					if y >= 16 and y <= 51 then
						settingsselection = 0
						mouseselected = true
					end
				elseif n <= #settingslist then
					settingsselection = n
					mouseselected = true
				end
			end
		elseif settingsstate == "controls" then
			mouseselected = false
			if x >= 178 and x <= 410 then
				local n = math.floor((y-52)/19)+1
				if n <= 0 then
					if y >= 16 and y <= 51 then
						settingsselection = 0
						mouseselected = true
					end
				elseif n <= #controlstable then
					settingsselection = n
					mouseselected = true
				end
			end
		end
	end
end

function menu.setstate(s)
	transitionfrom = menustate
	menutransition = true
	menustate = s
	transitiontimer = transitiontime
	buttonselected = false
	menu.activatebuttons(s)
end

function menu.activatebuttons(s, a)
	--make buttons active in their proper menu state
	for i, b in pairs(buttons) do
		if a then
			if b.active then
				b.alpha = 255-(transitiontimer/transitiontime)*255
			else
				b.alpha = (transitiontimer/transitiontime)*255
			end
		end
		b.active = false
	end
	if s == "main" then
		buttons.select.active = true
		buttons.settings.active = true
		buttons.quit.active = true
		buttons.help.active = true
	elseif s == "select" then
		buttons.back2.active = true
		buttons.start.active = true
	elseif s == "settings" then
		buttons.back.active = true
		buttons.reset.active = true
	end
end