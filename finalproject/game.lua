game = {}

local transitionin = false
local transitionintime = .38
local transitioninstencil = function() --circle transition
	local r = (1-transitionin/transitionintime)*248
	if r > 0.5 then
		love.graphics.circle("fill", res[1]/2, res[2]/2, r)
	end
end
local transitionout = false
local transitionouttime = .5
local transitionoutto --what game state to transition out to
local transitionoutstencil = function() --circle transition
	local r = (transitionout/transitionintime)*248
	if r > 0.5 then
		love.graphics.circle("fill", res[1]/2, res[2]/2, r)
	end
end

-- Save the original new LÖVE functions
local old_setColor = love.graphics.setColor
local old_setBlendMode = love.graphics.setBlendMode

-- Fix colors automatically: Convert 0-255 down to 0-1
love.graphics.setColor = function(r, g, b, a)
if type(r) == "number" and r > 1 then r = r / 255 end
if type(g) == "number" and g > 1 then g = g / 255 end
if type(b) == "number" and b > 1 then b = b / 255 end
if type(a) == "number" and a > 1 then a = a / 255 end
old_setColor(r, g, b, a)
end

-- Fix blend modes automatically: Apply "premultiplied" when needed
love.graphics.setBlendMode = function(mode, alpha)
	if mode == "multiply" and not alpha then
		alpha = "premultiplied"
	end
	old_setBlendMode(mode, alpha)
end

local wrenchcollectanim = {0, false} --wrench animation in hud when collect {time (wrenchcollectanimtime), id of wrench}
local wrenchcollectanimtime = 0.44

local updatelighting
local nighttime = false
local levelfinish = false
local levelfinishtime = 5

local helppopup = false--show pop up if first time playing level

local nextdt = false --if something causes lag, prevent a sudden jump
local spritebatch

local undo = false

function game.load(level)
	--Model loading
	startlevel(level)
	
	--transition in
	transitionin = transitionintime
	transitionout = false
	transitionoutto = false
	
	--pause
	paused = false
	pausedselection = 1
	
	if graphicsquality == "best" then
		pauseimage = false--screen shot
		pausecanvas = love.graphics.newCanvas(res[1], res[2])--love.graphics.getWidth(), love.graphics.getHeight()) --canvas for blur
		pausecanvas:setFilter("linear", "linear")
		shader["blur"]:send("size", {pausecanvas:getWidth(), pausecanvas:getHeight()});
		shader["blur"]:send("blursize", 3.0)
	end
	if helppopup then
		paused = 0; nextdt = 0
	end
	
	--level finish
	levelfinish = false
	
	--sprite batch optimization
	if usespritebatch then
		spritebatch = love.graphics.newSpriteBatch(gamesprites, 1000, "stream")
	end
end

function game.update(dt)
	if nextdt then dt = nextdt nextdt = false end --prevent lag spike
	
	--transition from menu
	if transitionin then
		transitionin = transitionin - dt
		if transitionin < 0 then
			transitionin = false
		end
	elseif transitionout then
		transitionout = transitionout - dt
		if transitionout < 0 then
			transitionout = false
			writesave() --save progress
			setgamestate(unpack(transitionoutto))
		end
	end
	
	--pause menu
	if paused then
		if paused < 0 then
			paused = math.min(0, paused + dt*2.4)
			if paused == 0 then paused = false; helppopup = false end
		elseif paused < 1 and not transitionin then
			paused = math.min(1, paused + dt*2.4)
		end
		return
	elseif levelfinish then
		--level finished
		levelfinish = levelfinish + dt
		if levelfinish > levelfinishtime then
			writesave() --save progress
			local gamefinished = 1
			if not levelinfo[levelno].wrench.all then
				for n = 1, #levelinfo do
					if not levelinfo[n].wrench.all then
						gamefinished = gamefinished - 1
					end
					if gamefinished < 0 then --more levels need to be completed
						break
					end	
				end
			end
			if gamefinished == 0 then --show ending if all wrenches have been collected making sure it only shows once
				unlocklevels() --update to see if levels have all wrenches 
				setgamestate("ending")
			else
				setgamestate("menu", {"select"})
			end
			return
		end
	end
	
	--move camera
	if love.keyboard.isDown(controls["cameral"]) then
		rotation = rotation - 1.8*dt
	elseif love.keyboard.isDown(controls["camerar"]) then
		rotation = rotation + 1.8*dt
	end
	if zoom then
		if love.keyboard.isDown("up") then
			blocksize = math.max(16, math.min(48, blocksize - 20*dt))
			if blocksize > 16 and blocksize < 48 then
				angledblocksize = angledblocksize - 20*dt
			end
		elseif love.keyboard.isDown("down") then
			blocksize = math.max(16, math.min(48, blocksize + 20*dt))
			if blocksize > 16 and blocksize < 48 then
				angledblocksize = angledblocksize + 20*dt
			end
		end
	end
	
	--deal with rotation
	rotation = rotation%(math.pi*2)
	
	--divide rotation into four sections
	rotationsection = 1
	if rotation > math.pi*1.75 then
		rotationsection = 1
	elseif rotation > math.pi*1.25 then
		rotationsection = 2
	elseif rotation > math.pi*.75 then
		rotationsection = 3
	elseif rotation > math.pi*.25 then
		rotationsection = 4
	end
	--divide rotation into 8 sections
	local u, u2 = math.pi/4, math.pi/8--distance of steps
	rotationsection2 = math.ceil((rotation+u2)/u)
	if rotationsection2 > 8 then
		rotationsection2 = 1
	end
	
	--gravity and offsets for blocks
	for z = #model, 1, -1 do
		for x = 1, #model[z] do
			for y = 1, #model[z][x] do
				local i = gettilei(x, y, z)
				if i == blockid.push then
					local offset = gettilei(x, y, z, "offset")
					local falltime = gettilei(x, y, z, "falltime") or blockfalltime
					if offset then
						--smooth horizontal movement
						if offset[1] > 0 then
							offset[1] = math.max(0, offset[1] - pushblockspeed*dt)
						elseif offset[1] < 0 then
							offset[1] = math.min(0, offset[1] + pushblockspeed*dt)
						elseif offset[2] > 0 then
							offset[2] = math.max(0, offset[2] - pushblockspeed*dt)
						elseif offset[2] < 0 then
							offset[2] = math.min(0, offset[2] + pushblockspeed*dt)
						end
						if offset[1] == 0 and offset[2] == 0 then
							settilei(x, y, z, nil, "offset")
						end
					else
						--falling
						if (gettilei(x, y, z+1) == 0 or gettilei(x, y, z+1, "falltime")) and not (z+1 == player.z and x == player.x and y == player.y) then
							if falltime <= 0 then
								if gettilei(x, y, z+1) == 0 then
									settilei(x, y, z, nil, "falltime")
									settilei(x, y, z, 0)
									settilei(x, y, z+1, blockid.push)
									if player.x == x and player.y == y then
										player_updateshadow()
									end
								end
							else
								falltime = falltime-dt
								settilei(x, y, z, falltime, "falltime")
							end
						else
							if falltime then
								settilei(x, y, z, nil, "falltime")
							end
						end
					end
				end
			end
		end
	end
	
	--player stuffs
	local b = gettilei(player.x, player.y, player.z+1)--block below player
	if not levelfinish and not player.farjump and not player.ice and not (b==blockid.jump or b==blockid.tele1 or b==blockid.tele2 or b==blockid.tele3 or b==blockid.tele4) then--don't move if trampoline jumping, on ice, or on portal
		if player.movew > 0 then --wait 0.3 seconds until player can move again
			player.movew = math.max(0, player.movew-dt)
		else --move when key is being held down
			if love.keyboard.isDown(controls["left"]) then
				player_move(4)
			elseif love.keyboard.isDown(controls["right"]) then
				player_move(2)
			elseif love.keyboard.isDown(controls["up"]) then
				player_move(3)
			elseif love.keyboard.isDown(controls["down"]) then
				player_move(1)
			end
		end
	end
	local below = gettilei(player.x, player.y, player.z+1) --get tile below player
	if below == 0 then --vertical movement
		 if player.jt then
			--make sure player doesn't fall inside block
			local offx, offy = math.ceil(player.movet[1]), math.ceil(player.movet[2])--offsets rounded up
			if player.movet[1] < 0 then offx = math.floor(player.movet[1]) end
			if player.movet[2] < 0 then offy = math.floor(player.movet[2]) end
			if gettilei(player.x+offx, player.y+offy, player.z+1) == 0 then
				player.jt = player.jt - dt --drain time for falling
				if player.jt < 0 then --keep falling or stop
					player.z = player.z+1
					local b = gettilei(player.x, player.y, player.z+1)
					if b == blockid.wrench or b == blockid.colwrench then --collect wrench below
						collectwrench(player.x, player.y, player.z+1)
						player_updateshadow()
						b = 0
					end
					
					if b == 0  then -- falling
						player.jt = playerfalltime-math.abs(player.jt)
						player.jump[3] = false
					else --land
						player.jt = false
						player.jump[1] = false
						player.jump[3] = false
						player.movew = playerholdmove3
						player.farjump = false
						player_setquad("idle", 1)
						--button press [set to 1(turn) or 2(switch) when hit ground button.Note : This is to make sure it is only presses once]
						if b == blockid.turnh1 or b == blockid.turnh2 or b == blockid.turnv1 or b == blockid.turnv2 then
							player.buttonb = 1
						elseif b == blockid.switch1 or b == blockid.switch2 or b == blockid.switch3 or b == blockid.switch4 or b == blockid.switch5 or b == blockid.switch6 then
							player.buttonb = 2
						end
						playsound(sounds["land"])
					end
				end
			end
		else
			--falling
			player.jt = playerfalltime
			player.jump[1] = player.dir
			player.jump[2] = 1
			player.jump[3] = false
		 end
	elseif below == blockid.wrench or below == blockid.colwrench then --collect wrench
		collectwrench(player.x, player.y, player.z+1)
		player_updateshadow()
	elseif not player.farjump and below == blockid.jump then --jump on trampoline
		if player.movet[1] == 0 and player.movet[2] == 0 then
			player_jump(1)
			player.farjump = player.dir --jump in direction of player
			playsound(sounds["spring"])
		end
	elseif not player.ice and below == blockid.ice then --slide on ice
		player.ice = player.dir
		playsound(sounds["ice"])
	elseif not player.teleport and (below == blockid.tele1 or below == blockid.tele2 or below == blockid.tele3 or below == blockid.tele4) then --teleport 
		local ti = below+1-blockid.tele1 --color of teleporter
		local dir = 2 --horizontal, vertical
		if gettilei(player.x-1, player.y, player.z+1) == below or gettilei(player.x+1, player.y, player.z+1) == below then --check if horizontal
			dir = 1
		end
		local slot = (gettilei(player.x, player.y-1, player.z+1) == below)--side of teleporter
		if dir == 1 then
			slot = (gettilei(player.x-1, player.y, player.z+1) == below)
		end
		if not player.teleport then
			if player.movet[1] == 0 and player.movet[2] == 0 then
				player.teleport = player.dir
				local breakit = false
				for z = 1, #model do
					for x = 1, #model[z] do
						for y = 1, #model[z][x] do
							local i = gettilei(x, y, z)
							if i == below and ((not slot) or ((dir == 1 and gettilei(x-1, y, z) == i) or (dir == 2 and gettilei(x, y-1, z) == i))) then
								local d = math.abs(player.x-x)+math.abs(player.y-y)+math.abs(player.z+1-z)--get distance
								if d > 1 then --teleport if far enough (don't teleport to starting teleporter)
									local slotaddx, slotaddy = 0, 0 --where to place other animation relative to current place
									if dir == 1 then
										slotaddx = -1
										if not slot then slotaddx = 1 end
									else
										slotaddy = -1
										if not slot then slotaddy = 1 end
									end
									table.insert(animations, {x=player.x, y=player.y, z=player.z, t=1, ts=1.5, img=gamesprites, q=animationsq, f=1, color={255,255,255}, qfade=true}) --teleport animation
									table.insert(animations, {x=player.x+slotaddx, y=player.y+slotaddy, z=player.z, t=1, ts=1.5, img=gamesprites, q=animationsq, f=1, color={255,255,255}, qfade=true})
									table.insert(animations, {x=x, y=y, z=z-1, t=1, ts=1.5, img=gamesprites, q=animationsq, f=1, color={255,255,255}, qfade=true})
									table.insert(animations, {x=x+slotaddx, y=y+slotaddy, z=z-1, t=1, ts=1.5, img=gamesprites, q=animationsq, f=1, color={255,255,255}, qfade=true})
									table.insert(animations, {type = "floor", x=player.x, y=player.y, z=player.z+0.99999, t=1, ts=1.5, img=gamesprites, q=animationsq, f=2, color={255,255,255}, qfade=true}) --floor teleport animation
									table.insert(animations, {type = "floor", x=player.x+slotaddx, y=player.y+slotaddy, z=player.z+0.99999, t=1, ts=1.5, img=gamesprites, q=animationsq, f=2, color={255,255,255}, qfade=true})
									table.insert(animations, {type = "floor", x=x, y=y, z=z-0.00001, t=1, ts=1.5, img=gamesprites, q=animationsq, f=2, color={255,255,255}, qfade=true})
									table.insert(animations, {type = "floor", x=x+slotaddx, y=y+slotaddy, z=z-0.00001, t=1, ts=1.5, img=gamesprites, q=animationsq, f=2, color={255,255,255}, qfade=true})
									player.x = x
									player.y = y
									player.z = z-1
									local d = (player.dir+rotationsection-1)%4 --undo rotation 
									player_move(d)
									player.teleport = false
									breakit = true
									break
								end
							end
						end
						if breakit then break end
					end
					if breakit then break end
				end
				playsound(sounds["teleport"])
			end
		end
	end
	if player.movet[1] ~= 0 then --smooth horizontal movement
		if player.movet[1] > 0 then
			player.movet[1] = math.max(0, player.movet[1] - playermovespeed*dt)
		else
			player.movet[1] = math.min(0, player.movet[1] + playermovespeed*dt)
		end
	elseif player.movet[2] ~= 0 then
		if player.movet[2] > 0 then
			player.movet[2] = math.max(0, player.movet[2] - playermovespeed*dt)
		else
			player.movet[2] = math.min(0, player.movet[2] + playermovespeed*dt)
		end
	end
	if player.farjump then --far jumps for trampoline
		if player.movet[1] == 0 and player.movet[2] == 0 and below == 0 then
			local oldx, oldy = player.x, player.y
			local d = player.farjump+rotationsection-1 --undo rotation 
			while d > 4 do
				d = d - 4
			end
			player_move(d)
			if player.x == oldx and player.y == oldy then
				player.farjump = false
			end
		end
	elseif player.ice then --ice slide
		if player.movet[1] == 0 and player.movet[2] == 0 then
			local oldx, oldy = player.x, player.y
			local d = player.dir+rotationsection-1 --undo rotation 
			while d > 4 do
				d = d - 4
			end
			player_move(d)
			if not (player.x == oldx and player.y == oldy) and gettilei(player.x, player.y, player.z+1) == blockid.ice then
				player.ice = player.dir
			else
				player.ice = false
				stopsound(sounds["ice"])
			end
		end
	elseif player.buttonb == 1 then --block rotate button
		if player.movet[1] == 0 and player.movet[2] == 0 then
			local bx, by, bz = player.x, player.y, player.z+1
			local slot = 1 
			if gettilei(bx-1,by,bz) == blockid.turnh1 then
				slot = 1
				bx = bx -1
			elseif gettilei(bx,by-1,bz) == blockid.turnv1 then
				slot = 2
				by = by - 1
			elseif gettilei(bx,by+1,bz) == blockid.turnv2 then
				slot = 2
			end
			--rotate 4x4 space with orange blocks underneath 
			local c = false --x/y of 4x4 space
			local cz = false --z of 4x4 space
			local cdist = math.huge
			for z = 1, #model do
				if slot == 1 then--horizontal button
					for y = 1, #model[z][bx] do
						if gettilei(bx, y, z) == blockid.turn then
							local dist = math.abs(by-y)
							if dist < cdist then
								c = y
								cz = z
								cdist = dist
							end
						end
					end
				else
					for x = 1, #model[z] do
						if gettilei(x, by, z) == blockid.turn then
							local dist = math.abs(bx-x)
							if dist < cdist then
								c = x
								cz = z
								cdist = dist
							end
						end
					end
				end
			end
			if (slot == 1 and gettilei(bx, c-1, cz) == blockid.turn) or (slot == 2 and gettilei(c-1, by, cz) == blockid.turn) then -- to make sure its top right corner
				c = c-1
			end
			--start to rotate
			if slot == 1 then
				for z = 1, cz-1 do
					local t1, t2, t3, t4 = gettiledata(bx, c, z), gettiledata(bx+1, c, z), gettiledata(bx+1, c+1, z), gettiledata(bx, c+1, z)
					settiledata(bx, c, z, t4)
					settiledata(bx+1, c, z, t1)
					settiledata(bx+1, c+1, z, t2)
					settiledata(bx, c+1, z, t3)
				end
			else
				for z = 1, cz-1 do
					local t1, t2, t3, t4 = gettiledata(c, by, z), gettiledata(c+1, by, z), gettiledata(c+1, by+1, z), gettiledata(c, by+1, z)
					settiledata(c, by, z, t4)
					settiledata(c+1, by, z, t1)
					settiledata(c+1, by+1, z, t2)
					settiledata(c, by+1, z, t3)
				end
			end
			
			player.buttonb = false
			playsound(sounds["rotate"])
		end
	elseif player.buttonb == 2 then --switch area button
		if player.movet[1] == 0 and player.movet[2] == 0 then
			if not player.switchsel then
				--Select first area to switch
				player.switchsel = gettilei(player.x, player.y, player.z+1)-blockid.switch1+1
				player.buttonb = false
				table.insert(animations, {type = "floor", x=player.x, y=player.y, z=player.z+0.99999, t=1, ts=1.5, img=gamesprites, q=animationsq, f=3, color={255,255,255}, qfade=true}) --button flash
			else
				--Once both areas are selected, they can be switched
				local s1, s2 = player.switchsel, gettilei(player.x, player.y, player.z+1)-blockid.switch1+1--what section to switch
				if s1 ~= s2 then --don't switch with itself
					local startx, starty = math.huge, math.huge --top right corner of buttons
					local sl1x, sl1y, sl2x, sl2y --position of buttons
					local s1x, s1y, s2x, s2y
					for x = player.x-2, player.x+2 do
						for y = player.y-2, player.y+2 do
							local b = gettilei(x, y, player.z+1)
							if b == s1+blockid.switch1-1 then
								s1x, s1y = x, y
							elseif b == s2+blockid.switch1-1 then
								s2x, s2y = x, y
							end
							if (b == blockid.switch1 or b == blockid.switch2 or b == blockid.switch3 or b == blockid.switch4 or b == blockid.switch5 or b == blockid.switch6) and x <= startx and y <= starty then
								startx, starty = x, y
							end
						end
					end
					settilei(s1x, s1y, player.z+1, s2+blockid.switch1-1)
					settilei(s2x, s2y, player.z+1, s1+blockid.switch1-1)
					sl1x, sl1y, sl2x, sl2y = s1x-startx+1, s1y-starty+1, s2x-startx+1, s2y-starty+1
					local mw, mh = math.floor(modelw/3), math.floor(modelh/2)--1/3 of the width and 1/2 of height of model
					for z = 1, modeld do --start switching, one tile at a time
						for x = 1, mw do
							for y = 1, mh do
								local x1, y1, x2, y2 = x+(sl1x-1)*mw, y+(sl1y-1)*mh, x+(sl2x-1)*mw, y+(sl2y-1)*mh
								local t1, t2 = gettiledata(x1, y1, z), gettiledata(x2, y2, z)
								settiledata(x1, y1, z, t2)
								settiledata(x2, y2, z, t1)
								if player.z == z then --move the player too
									if player.x == x1 and player.y == y1 then
										player.x = x2
										player.y = y2
									elseif player.x == x2 and player.y == y2 then
										player.x = x1
										player.y = y1
									end
								end
							end
						end
					end
				end
				table.insert(animations, {type = "floor", x=player.x, y=player.y, z=player.z+0.99999, t=1, ts=1.5, img=gamesprites, q=animationsq, f=3, color={255,255,255}, qfade=true}) --button flash
				player.switchsel = false
				player.buttonb = false
				playsound(sounds["switch"])
			end
		end
	end
	player_updateanim(dt)
	
	--animations
	for i, t in pairs(animations) do
		t.t = t.t - t.ts*dt
		if t.t < 0 then
			table.remove(animations, i)
		else
			if t.spinout then
				local v = 1-t.t
				t.f = ((math.floor(v*(32*v))+t.sf)%8)+1 --determine frame
			end
		end
	end
	
	wrenchanimtimer = (wrenchanimtimer + dt)%(wrenchanimdelay*8)
	
	wrenchcollectanim[1] = math.max(0, wrenchcollectanim[1]-dt)
	
	--lighting
	if updatelighting then
		calculatelighting()
		updatelighting = false
	end
end

function game.draw()
	--background
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(backgroundimg[levelinfo[levelno].background], 856*((rotation/(math.pi*2))-1), 0)
	if rotation < math.pi then
		love.graphics.draw(backgroundimg[levelinfo[levelno].background], 856*((rotation/(math.pi*2))-1)+856, 0)
	end
	
	--calculate a single layer of points
	for x = 1, #points do
		for y = 1, #points[x] do
			local p = points[x][y]
			points[x][y] = {((x-1)-((modelw)/2)), ((y-1)-((modelh)/2))}
			points[x][y] = {math.cos(rotation)*points[x][y][1]-math.sin(rotation)*points[x][y][2], math.sin(rotation)*points[x][y][1]+math.cos(rotation)*points[x][y][2]}
		end
	end
	
	--add to draw elements to a table for later sorting
	love.graphics.setColor(255, 255, 255)
	local todraw = {}
	for z = 1, #model do
		for x = 1, #model[z] do
			for y = 1, #model[z][x] do
				local i = gettilei(x, y, z)
				if i == blockid.wrench or i == blockid.colwrench then
					local x1, y1 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
					local x2, y2 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
					local x3, y3 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
					local x4, y4 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
					local a = math.max(1, math.ceil(wrenchanimtimer/wrenchanimdelay))
					--while a > 8 do a = a - 8 end
					local q = wrenchq[a]
					local color = {255, 255, 255}
					if i == blockid.colwrench then color = {240, 240, 240, 156} end
					table.insert(todraw, {i = "img", x = (x1+x2+x3+x4)/4, y = (y1+y2+y3+y4)/4, p = {x, y, z}, t = {gamesprites, q}, v = {color = color}})
				elseif type(i) == "string" then --image
					local x1, y1 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
					local x2, y2 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
					local x3, y3 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
					local x4, y4 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
					local i = tonumber(i)
					local a = rotationsection2
					local q = objimgs[i][a]
					table.insert(todraw, {i = "img", x = (x1+x2+x3+x4)/4, y = (y1+y2+y3+y4)/4, p = {x, y, z}, t = {gamesprites, q}, v = {}}) --id (what to draw), x, y, p (used for sorting), texture, vars
				elseif i >= 1 then --block
					local x1, y1 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
					local x2, y2 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
					local x3, y3 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
					local x4, y4 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
					if gettilei(x,y,z,"offset") then --offset block
						x1, y1, x2, y2, x3, y3, x4, y4 = offsetblock(x, y, z, gettilei(x,y,z,"offset"), x1, y1, x2, y2, x3, y3, x4, y4)
					end
					local faces = {isvisible(x, y-1, z), isvisible(x+1, y, z), isvisible(x, y+1, z), isvisible(x-1, y, z), isvisible(x, y, z-1)}--side1, side2, side3, side4, top 
					if gettilei(x, y, z) == blockid.ice then
						faces = {not getisblock(x, y-1, z) , not getisblock(x+1, y, z), not getisblock(x, y+1, z), not getisblock(x-1, y, z), not getisblock(x, y, z-1)}
					end
					table.insert(todraw, {i = "cube", x = (x1+x2+x3+x4)/4, y = (y1+y2+y3+y4)/4, p = {x, y, z}, t = i, v = {z, x, y, faces}}) --id (what to draw), x, y, z (used for sorting), texture, vars
					
					if shadowtype == "best" and gettilei(x, y, z, "s") then
						local t = gettilei(x, y, z, "s")
						table.insert(todraw, {i = "shadow", x = (x1+x2+x3+x4)/4, y = (y1+y2+y3+y4)/4, p = {x, y, z-0.000001}, t = i, v = {z, x, y, t[1], t[2]}})
					end
				end
			end
		end
	end
	--add player to sorting table
	if player then
		local x, y, z = player.x, player.y, player.z
		local x1, y1 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
		local x2, y2 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
		local x3, y3 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
		local x4, y4 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
		local dx, dy, dz = (x1+x2+x3+x4)/4, (y1+y2+y3+y4)/4, z --draw posiition
		local scissor = false
		local olddx, olddy, olddz = dx, dy, dz

		if player.movet[1] ~= 0 then --smooth movement 
			local v = math.abs(player.movet[1])
			local x21, y21, x22, y22, x23, y23, x24, y24
			if player.movet[1] > 0 then --offset right
				x21, y21 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
				x22, y22 = calcxpoint(points[x+2][y][1]), calcypoint(points[x+2][y][2], z)
				x23, y23 = calcxpoint(points[x+2][y+1][1]), calcypoint(points[x+2][y+1][2], z)
				x24, y24 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
			else --offset left
				x21, y21 = calcxpoint(points[x-1][y][1]), calcypoint(points[x-1][y][2], z)
				x22, y22 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
				x23, y23 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
				x24, y24 = calcxpoint(points[x-1][y+1][1]), calcypoint(points[x-1][y+1][2], z)
			end
			dx, dy = (dx*(1-v))+((x21+x22+x23+x24)/4*v), (dy*(1-v))+((y21+y22+y23+y24)/4*v)
		elseif player.movet[2] ~= 0 then
			local v = math.abs(player.movet[2])
			local x21, y21, x22, y22, x23, y23, x24, y24
			if player.movet[2] > 0 then --offset down
				x21, y21 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
				x22, y22 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
				x23, y23 = calcxpoint(points[x+1][y+2][1]), calcypoint(points[x+1][y+2][2], z)
				x24, y24 = calcxpoint(points[x][y+2][1]), calcypoint(points[x][y+2][2], z)
			else --offset up
				x21, y21 = calcxpoint(points[x][y-1][1]), calcypoint(points[x][y-1][2], z)
				x22, y22 = calcxpoint(points[x+1][y-1][1]), calcypoint(points[x+1][y-1][2], z)
				x23, y23 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
				x24, y24 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
			end
			dx, dy = (dx*(1-v))+((x21+x22+x23+x24)/4*v), (dy*(1-v))+((y21+y22+y23+y24)/4*v)
		end
		olddy = dy
		--check if in shadow
		local playercolor = nil
		if graphicsquality == "best" then
			local below = gettilei(player.x, player.y, player.z+1, "s")
			if below and below[1] and below[2] then
				playercolor = {shadowcolor[1], shadowcolor[2], shadowcolor[3], 255}
			end
		end
		
		local shadowdy = dy+((player.shadow-player.z)*angledblocksize)
		if player.jt then --smooth falling
			scissor = dy 
			if player.jt > playerjumpfalltime then --jumping
				local v = (player.jt-playerjumpfalltime)/(playerjumptime-playerjumpfalltime)
				dy = dy + v*(angledblocksize*v)
			elseif player.jump[3] then
				local v = 1-player.jt/playerjumpfalltime
				dy = dy + v*(angledblocksize*v)
			else
				dy = dy - (((player.jt/playerfalltime)-1)*angledblocksize)
			end
		end
		local i = 1
		local a = rotationsection+player.dir-1
		while a > 4 do
			a = a - 4
		end
		local q = objimgs[i][a]
		if scissor then
			table.insert(todraw, {i = "img", x = dx, y = olddy, p = {player.x, player.y, dz}, t = {player.img, player.quad}, v = {scissor = {dx-blocksize/2, math.ceil(scissor), blocksize, angledblocksize}, y = dy, color = playercolor}})
			table.insert(todraw, {i = "img", x = dx, y = olddy+angledblocksize, p = {player.x, player.y, dz+1}, t = {player.img, player.quad}, v = {scissor = {dx-blocksize/2, math.floor(scissor+angledblocksize), blocksize, angledblocksize}, y = dy, color = playercolor}})
		else
			table.insert(todraw, {i = "img", x = dx, y = dy, p = {player.x, player.y, dz}, t = {player.img, player.quad}, v = {color = playercolor}})
		end
		if getisblock(x, y, player.shadow) then
			table.insert(todraw, {i = "floor", x = dx, y = shadowdy, p = {player.x, player.y, player.shadow-0.00001}, t = {gamesprites,shadowq,size = math.max(0, (shadowdy-angledblocksize-dy)/angledblocksize)}, v = {size = true}})--shadow 
		end
		if gettilei(player.x, player.y, player.z+1) == blockid.ice or (gettilei(player.x, player.y, player.z+2) == blockid.ice and scissor) then---ice reflection
			local offx, offy = math.ceil(player.movet[1]), math.ceil(player.movet[2])--offsets rounded up
			if player.movet[1] < 0 then offx = math.floor(player.movet[1]) end
			if player.movet[2] < 0 then offy = math.floor(player.movet[2]) end
			if (gettilei(player.x, player.y, player.z+1) == blockid.ice and gettilei(player.x+offx, player.y+offy, player.z+1) ~= 0) then --check if player is fully on ice
				table.insert(todraw, {i = "img", x = dx, y = dy+angledblocksize, p = {player.x, player.y, dz+1.5}, t = {player.img, player.quad}, v = {color = {255, 255, 255, 200}, upsidedown = true}})--player reflection
			elseif scissor and (gettilei(player.x, player.y, player.z+2) == blockid.ice or gettilei(player.x+offx, player.y+offy, player.z+2) ~= 0) then
				table.insert(todraw, {i = "img", x = dx, y = math.ceil(scissor+angledblocksize*2)-(math.abs(dy-olddy)-angledblocksize), p = {player.x, player.y, dz+2.5}, t = {player.img, player.quad},
					v = {scissor = {dx-blocksize/2, math.ceil(scissor+angledblocksize*2), blocksize, angledblocksize}, color = {255, 255, 255, 200}, upsidedown = true}})
			end
		end
	end
	--add animations to sorting table
	for i, t in pairs(animations) do
		local x, y, z = t.x, t.y, t.z
		local x1, y1 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
		local x2, y2 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
		local x3, y3 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
		local x4, y4 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
		local q = t.q[t.f]
		local color = {t.color[1], t.color[2], t.color[3], t.color[4] or 255}
		if t.fade then color[4] = math.min(color[4], (t.t*(color[4]*t.t))*(t.t*(color[4]*t.t))) end
		if t.qfade then color[4] = color[4]*t.t end --quick
		table.insert(todraw, {i = t.type or "img", x = (x1+x2+x3+x4)/4, y = (y1+y2+y3+y4)/4, p = {x, y, z}, t = {t.img, q}, v = {color = color}})
	end
	--Drawing scene--
	if graphicsquality == "best" and nighttime then
		love.graphics.setShader(shader["night"])
	end
	
	--sort draw elements then draw them in order
	table.sort(todraw, 
		function(a, b)
			local ax, ay, az, bx, by, bz = a.x, a.y, a.p[3], b.x, b.y, b.p[3]
			local samez = (az == bz)
			return ((az > bz and not samez) or (samez and ay < by) or (samez and ay == by and ax < bx))
		end)
	if usespritebatch then
		spritebatch:clear()
	end
	for i, t in pairs(todraw) do
		if t.i == "img" then --image
			local x, y = t.v.x or t.x, t.v.y or t.y
			if t.v.color then--change color
				game.setcolor(t.v.color)
			else
				game.setcolor(255, 255, 255)
			end
			if t.v.scissor then
				love.graphics.setScissor(t.v.scissor[1], t.v.scissor[2], t.v.scissor[3], t.v.scissor[4])
			end
			local sx, sy = blocksize/texturesize, angledblocksize/texturesize
			if usespritebatch then
				y = y*(1/angleval); sy = sy*(1/angleval)
			end
			if t.v.upsidedown then --reflection
				game.gdraw(t.t[2], x, y+angledblocksize, 0, sx, -sy, texturesize/2, 0)
			else
				game.gdraw(t.t[2], x, y, 0, sx, sy, texturesize/2, 0)
			end
			love.graphics.setScissor()
		elseif t.i == "floor" then --image drawn to floor
			game.setcolor(255, 255, 255)
			local s = 1
			if t.v.size then
				s = math.max(0, 1-(t.t.size/10))--scale
			end
			if t.v.color then--change color
				game.setcolor(t.v.color)
			else
				game.setcolor(255, 255, 255)
			end
			local x, y = t.x, 0
			local sx, sy = (blocksize/texturesize)*s, (blocksize/texturesize)*s
			if usespritebatch then
				y = t.y*(1/angleval)
			else
				love.graphics.push()
				love.graphics.translate(0, t.y); love.graphics.scale(1, angleval)
			end
			if t.t[2] then
				game.gdraw(t.t[2], x, y, rotation, sx, sy, texturesize/2, texturesize/2)
			else
				game.gdraw(x, y, rotation, sx, sy, texturesize/2, texturesize/2)
			end
			if not usespritebatch then
				love.graphics.pop()
			end
		elseif t.i == "cube" then
			local z, x, y, faces = t.v[1], t.v[2], t.v[3], t.v[4]
			local x1, y1 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
			local x2, y2 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
			local x3, y3 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
			local x4, y4 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
			local la = lightangle--light angle
			local sc = shadowcolor--shadow color
			
			if gettilei(x,y,z,"offset") then --offset block
				x1, y1, x2, y2, x3, y3, x4, y4 = offsetblock(x, y, z, gettilei(x,y,z,"offset"), x1, y1, x2, y2, x3, y3, x4, y4)
			end
			
			if lensblur then --blur anything far away
				local i = math.min(1, (calcypoint(points[x][y][2], 1)/(res[2]/3)))
				if i < 0.1 then
					gamesprites:setFilter("linear", "linear")
				else
					gamesprites:setFilter("nearest", "nearest")
				end
			end
			
			if faces[1] and x1 > x2 then
				local v = (math.sin(la+math.pi*1.5)+1)/2
				game.setcolor(sc[1]+(255-sc[1])*v, sc[2]+(255-sc[2])*v, sc[3]+(255-sc[3])*v)
				--love.graphics.polygon("fill", x1, y1, x2, y2, x2, y2+angledblocksize, x1, y1+angledblocksize) -- side 1
				drawtexture({gamesprites, textures[t.t].side3}, "side", x1, y1, x2, y2, x2, y2+angledblocksize, x1, y1+angledblocksize)
			end
			if faces[2] and x2 > x3 then
				local v = (math.sin(la)+1)/2
				game.setcolor(sc[1]+(255-sc[1])*v, sc[2]+(255-sc[2])*v, sc[3]+(255-sc[3])*v)
				--love.graphics.polygon("fill", x2, y2, x3, y3, x3, y3+angledblocksize, x2, y2+angledblocksize) -- side 2
				drawtexture({gamesprites, textures[t.t].side4}, "side", x2, y2, x3, y3, x3, y3+angledblocksize, x2, y2+angledblocksize)
			end
			if faces[3] and x3 > x4 then
				local v = (math.sin(la+math.pi*.5)+1)/2
				game.setcolor(sc[1]+(255-sc[1])*v, sc[2]+(255-sc[2])*v, sc[3]+(255-sc[3])*v)
				--love.graphics.polygon("fill", x3, y3, x4, y4, x4, y4+angledblocksize, x3, y3+angledblocksize) -- side 3
				drawtexture({gamesprites, textures[t.t].side1}, "side", x3, y3, x4, y4, x4, y4+angledblocksize, x3, y3+angledblocksize)
			end
			if faces[4] and x4 > x1 then
				local v = (math.sin(la+math.pi)+1)/2
				game.setcolor(sc[1]+(255-sc[1])*v, sc[2]+(255-sc[2])*v, sc[3]+(255-sc[3])*v)
				--love.graphics.polygon("fill", x4, y4, x1, y1, x1, y1+angledblocksize, x4, y4+angledblocksize) -- side 4
				drawtexture({gamesprites, textures[t.t].side2}, "side", x4, y4, x1, y1, x1, y1+angledblocksize, x4, y4+angledblocksize)
			end
			if faces[5] then
				game.setcolor(255, 255, 255)
				if shadowtype == "fast" and gettilei(x, y, z, "s") then --fast shadow
					local v = 1
					game.setcolor(sc[1], sc[2], sc[3])
				end
				--love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4) --top
				drawtexture({gamesprites, textures[t.t].top}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
				if ambientocclusion and gettilei(x, y, z, "ao") then
					love.graphics.push("all")
					love.graphics.setShader()
					love.graphics.setBlendMode("multiply")
					game.setcolor(255, 255, 255)
					local ao = gettilei(x, y, z, "ao")
					if ao[1] then
						drawtexture({gamesprites, ashadowq[1][1]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					if ao[2] then
						drawtexture({gamesprites, ashadowq[2][1]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					if ao[3]  then
						drawtexture({gamesprites, ashadowq[3][1]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					if ao[4] then
						drawtexture({gamesprites, ashadowq[1][2]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					if ao[5] then
						drawtexture({gamesprites, ashadowq[3][2]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					if ao[6] then
						drawtexture({gamesprites, ashadowq[1][3]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					if ao[7] then
						drawtexture({gamesprites, ashadowq[2][3]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					if ao[8]  then
						drawtexture({gamesprites, ashadowq[3][3]}, "top", x1, y1, x2, y2, x3, y3, x4, y4)
					end
					love.graphics.pop()
				end
			end
			
			if lensblur then
				gamesprites:setFilter("nearest", "nearest")
			end
		elseif t.i == "shadow" then
			z, x, y = t.v[1], t.v[2], t.v[3]
			s1, s2 = t.v[4], t.v[5] --shadow height
			local x1, y1 = calcxpoint(points[x][y][1]), calcypoint(points[x][y][2], z)
			local x2, y2 = calcxpoint(points[x+1][y][1]), calcypoint(points[x+1][y][2], z)
			local x3, y3 = calcxpoint(points[x+1][y+1][1]), calcypoint(points[x+1][y+1][2], z)
			local x4, y4 = calcxpoint(points[x][y+1][1]), calcypoint(points[x][y+1][2], z)
			
			love.graphics.push("all")
			love.graphics.setShader()
			love.graphics.setBlendMode("multiply")
			love.graphics.setColor(shadowcolor)
			if s1 and s2 then
				love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
			elseif s1 then
				love.graphics.polygon("fill", (x1+x4)/2, (y1+y4)/2, (x2+x3)/2, (y2+y3)/2, x3, y3, x4, y4)
			else
				love.graphics.polygon("fill", x1, y1, x2, y2, (x2+x3)/2, (y2+y3)/2, (x1+x4)/2, (y1+y4)/2)
			end
			love.graphics.pop()
		end
	end
	if usespritebatch then
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(spritebatch, 0, 0, 0, 1, angleval) --shrink vertically for perspective
	end
	if graphicsquality == "best" and nighttime then
		love.graphics.setShader()
	end
	
	--Overlay HUD
	love.graphics.setColor(255, 255, 255)
	love.graphics.setFont(hudfont)
	love.graphics.print("level " .. levelno, 6, 6)
	for i = 1, #levelinfo[levelno].wrench do
		local q = 1
		if levelinfo[levelno].wrench[i] then q = 2 end
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(wrenchiconimg, wrenchiconq[q], 8+(22*(i-1)), 27)
		if wrenchcollectanim[1] > 0 and wrenchcollectanim[2] == i then --flash white
			love.graphics.setColor(255, 255, 255, wrenchcollectanim[1]/wrenchcollectanimtime*255*wrenchcollectanim[1]/wrenchcollectanimtime)
			love.graphics.draw(wrenchiconimg, wrenchiconq[4], 8+(22*(i-1)), 27)
		end
	end
	

	
	--pause menu
	if paused then
		--background
		if graphicsquality == "best" then --blur
			if not pauseimage then --generated blurred image for help pop up
				blurpause()
			end
			love.graphics.setColor(255, 255, 255, math.abs(paused)*255)
			love.graphics.draw(pausecanvas, 0, 0, 0, 1, 1)
		elseif graphicsquality == "fast" then --darken
			love.graphics.setColor(0, 0, 0, math.abs(paused)*86)
			love.graphics.rectangle("fill", 0, 0, res[1], res[2])
		end
		
		local w = 182-((1-math.abs(paused))*182*(1-math.abs(paused)))
		local h = 100
		
		if helppopup then --help popup
			w = 256-((1-math.abs(paused))*256*(1-math.abs(paused)))
			h = 128
			love.graphics.setScissor((res[1]-w)/2, 0, w, res[2])
			love.graphics.setColor(24, 23, 33, 128)
			love.graphics.rectangle("fill", (res[1]-256)/2, (res[2]-h)/2, 256, h)
			love.graphics.rectangle("fill", (res[1]-128)/2, 156, 128, 22)
			love.graphics.setFont(hudfont)
			love.graphics.setColor(255, 198, 56)
			love.graphics.print("- help -", (res[1]-hudfont:getWidth("- help -"))/2, 64)
			love.graphics.setColor(255, 255, 255)
			love.graphics.printf(levelinfo[levelno].help[1], (res[1]-256)/2+2, 90, 256, "center")
			love.graphics.print("got it", (res[1]-hudfont:getWidth("got it"))/2, 158)
		else
			love.graphics.setScissor((res[1]-w)/2, 0, w, res[2])
			love.graphics.setColor(24, 23, 33, 128)
			love.graphics.rectangle("fill", (res[1]-182)/2, (res[2]-h)/2, 182, h)
			love.graphics.rectangle("fill", (res[1]-174)/2, 102+20*(pausedselection-1), 174, 22)
			love.graphics.setFont(hudfont)
			love.graphics.setColor(255, 198, 56)
			love.graphics.print("- paused -", (res[1]-hudfont:getWidth("- paused -"))/2, 78)
			love.graphics.setColor(255, 255, 255)
			love.graphics.print("resume", (res[1]-hudfont:getWidth("resume"))/2, 104)
			love.graphics.print("restart level", math.floor((res[1]-hudfont:getWidth("restart level"))/2), 124)
			love.graphics.print("exit level", (res[1]-hudfont:getWidth("exit level"))/2, 144)
		end
		love.graphics.setScissor()
	--level finish animation
	elseif levelfinish then
		if levelfinish > 4.5 then
			love.graphics.setColor(0, 0, 0, 86+((levelfinish-4.5)/.5)*169)
		elseif levelfinish > .6 then
			love.graphics.setColor(0, 0, 0, math.min(1, (levelfinish-.6)/.8)*86)
		else
			love.graphics.setColor(0, 0, 0, 0)
		end
		love.graphics.rectangle("fill", 0, 0, res[1], res[2])
		
		--text & info
		local v = 1
		if levelfinish > 4 then
			v = math.min(1, (levelfinish-4)/.8)
		elseif levelfinish > .6 then
			v = 1-math.min(1, (levelfinish-.6)/.8)
		else
		end
		love.graphics.translate(0, 80-(v*(146*v)))
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.print("level " .. levelno .. " complete!", math.floor((res[1]-hudfont:getWidth("level " .. levelno .. " complete!"))/2))
		love.graphics.setColor(255, 198, 56, 255)
		love.graphics.print(levelinfo[levelno].name, math.floor((res[1]-hudfont:getWidth(levelinfo[levelno].name))/2), 22)
		for i = 1, #levelinfo[levelno].wrench do --collected wrenches
			local q = 1
			local t = 1.8+((2.25/#levelinfo[levelno].wrench)*(i-1))--time
			if levelfinish > t then
				q = 2
			end
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(wrenchiconimg, wrenchiconq[q], math.floor(res[1]/2+(22*(i-1-#levelinfo[levelno].wrench/2))), 44)
			
			if levelfinish > t and levelfinish-t < wrenchcollectanimtime then --flash
				love.graphics.setColor(255, 255, 255, 255*((wrenchcollectanimtime-(levelfinish-t))/wrenchcollectanimtime))
				love.graphics.draw(wrenchiconimg, wrenchiconq[4], math.floor(res[1]/2+(22*(i-1-#levelinfo[levelno].wrench/2))), 44)
			end
		end
	end
	
	--Transition from menu
	if transitionin or transitionout then
		love.graphics.setColor(0, 0, 0)
		if transitionin then
			love.graphics.stencil(transitioninstencil, "replace", 1)
		else
			love.graphics.stencil(transitionoutstencil, "replace", 1)
		end
		love.graphics.setStencilTest("less", 1)
		love.graphics.rectangle("fill", 0, 0, res[1], res[2])
		love.graphics.setStencilTest()
	end
end

--Controls--
function game.keypressed(k)
	if transitionin or transitionout or levelfinish then --can't control when transitioning
		return
	end
	
	if paused then --selection pause options
		if paused == 1 and not transitionout then
			if helppopup then
				if k == controls["jump"] or k == controls["select"] or k == "escape" then
					paused = -1
				end
			else
				if k == controls["down"] or k == "down" then
					pausedselection = pausedselection + 1
					if pausedselection > 3 then pausedselection = 1 end
					playsound(sounds["select2"])
				elseif k == controls["up"] or k == "up" then
					pausedselection = pausedselection - 1
					if pausedselection < 1 then pausedselection = 3 end
					playsound(sounds["select2"])
				elseif k == controls["jump"] or k == controls["select"] or k == "escape" then
					if pausedselection == 1 then
						paused = -1
						if levelinfo[levelno].music > 0 then
							resumesound(gamemusic[levelinfo[levelno].music])
						end
					elseif pausedselection == 2 then
						transitionout = transitionouttime
						transitionoutto = {"game", {levelno}}
					elseif pausedselection == 3 then
						transitionout = transitionouttime
						transitionoutto = {"menu", {"select"}}
					end
				end
			end
		end
		return
	else
		if (k == controls["select"] or k == "escape") then
			paused = 0
			if levelinfo[levelno].music > 0 then
				pausesound(gamemusic[levelinfo[levelno].music])
			end
			if graphicsquality == "best" then
				blurpause()
			end
		end
	end
	
	if k == controls["undo"] then
		loadUndo()
		return
	end
		
	local b = gettilei(player.x, player.y, player.z+1)--block below player
	if not player.farjump and not player.ice and not (b==blockid.jump or b==blockid.tele1 or b==blockid.tele2 or b==blockid.tele3 or b==blockid.tele4) then--don't move if trampoline jumping, on ice, or on portal
		if k == controls["left"] then
			if not player.jump[1] then
				storeUndo()
			end
			player_move(4)
		elseif k == controls["right"] then
			if not player.jump[1] then
				storeUndo()
			end
			player_move(2)
		elseif k == controls["up"] then
			if not player.jump[1] then
				storeUndo()
			end
			player_move(3)
		elseif k == controls["down"] then
			if not player.jump[1] then
				storeUndo()
			end
			player_move(1)
		elseif k == controls["jump"] then
			player_jump(1)
		end
	end
end
function blurpause()
	pauseimage = love.graphics.newCanvas()
	love.graphics.setCanvas(pauseimage)
	love.graphics.clear()
	pausecanvas:renderTo(function() love.graphics.setShader(shader["blur"]); love.graphics.setColor(255, 255, 255); love.graphics.draw(pauseimage, 0, 0, 0, 1/scale[1]/scale[1], 1/scale[2]/scale[2]); 
	love.graphics.setShader() end)
	love.graphics.setCanvas()
	if not helppopup then--prevent lag spike
		nextdt = 0
	end
end

function game.mousepressed(x, y, b)
	if paused and b == 1 then --select pause things
		if paused == 1 and not transitionout then
			if helppopup then
				if x > (res[1]-128)/2 and y > 158 and x < (res[1]-128)/2+128 and y < 178 then
					paused = -1
				end
			else
				if x > (res[1]-174)/2 and y > 103 and x < (res[1]-174)/2+174 and y < 163 then
					game.mousemoved(x, y, 0, 0)
					if pausedselection == 1 then
						paused = -1
					elseif pausedselection == 2 then
						transitionout = transitionouttime
						transitionoutto = {"game", {levelno}}
					elseif pausedselection == 3 then
						transitionout = transitionouttime
						transitionoutto = {"menu", {"select"}}
					end
				end
			end
		end
		return
	end
end

function game.wheelmoved(x, y)
	if zoom then --zoom in with mouse
		blocksize = blocksize + 2*y
		angledblocksize = angledblocksize + 2*y
	end
end

function game.mousemoved(x, y, dx, dy)
	if paused then --select pause options
		if paused == 1 and not transitionout then
			love.graphics.rectangle("fill", (res[1]-174)/2, 102+20*(pausedselection-1), 174, 22)
			if x > (res[1]-174)/2 and y > 103 and x < (res[1]-174)/2+174 and y < 163 then
				pausedselection = math.floor((y-103)/20)+1
			end
		end
		return
	end
	
	if love.mouse.isDown(1) then --rotate with mouse
		rotation = rotation + ((-dx/res[1])*math.pi*2)
		
		if vrotate then
			vrotation = math.max(0.00001, math.min(0.99999, vrotation + dy/(blocksize*2)))
			angleval = math.sin((vrotation)*math.pi/2)
			angledblocksize = blocksize*math.sin((1-vrotation)*math.pi/2)
		end
	end
end

--Misc functions--
function calcxpoint(x)
	--convert points to onscreen points
	return res[1]/2+(x)*blocksize
end

function calcypoint(y, z)
	--convert points and also angle it
	return res[2]/2+((y*angleval)*blocksize)+((z-(modeld/1.5))*angledblocksize)-(angleval*blocksize*2) 
end
function drawtexture(i, t, x1, y1, x2, y2, x3, y3, x4, y4) --draw texture by distorting it
	if t == "top" then
		local r = rotation --rotation
		local sx, sy = blocksize/texturesize, blocksize/texturesize --scale
		local cx, cy = texturesize/2, texturesize/2 --center
		local shearx, sheary = 0, 0
		local x, y =  (x1+x2+x3+x4)/4, 0
		if usespritebatch then--no transformations
			y = (y1+y2+y3+y4)/4*(1/angleval)
		else
			love.graphics.push()
			love.graphics.translate(0, (y1+y2+y3+y4)/4)
			love.graphics.scale(1, angleval)
		end
		if #i == 2 then
			game.gdraw(i[2], x, y, r, sx, sy, cx, cy, shearx, sheary) --quad
		else
			game.gdraw(x, y, r, sx, sy, cx, cy, shearx, sheary) --single image
		end
		if not usespritebatch then
			love.graphics.pop()
		end
	elseif t == "side" then
		local r = 0 --rotation
		local sx, sy = blocksize/texturesize, angledblocksize/texturesize
		sx = sx * ((x2-x1)/blocksize)
		local cx, cy = texturesize/2, texturesize/2 --center
		local shearx, sheary = 0, ((y2-y1)/angledblocksize)
		local x, y = (x1+x2+x3+x4)/4, (y1+y2+y3+y4)/4
		if usespritebatch then y = y*(1/angleval); sy = sy*(1/angleval) end --stretch for spritebatch
		if #i == 2 then
			game.gdraw(i[2], x, y, r, -sx, sy, cx, cy, shearx, -sheary) --quad
		else
			game.gdraw(x, y, r, -sx, sy, cx, cy, shearx, -sheary) --single image
		end
	end
end
function offsetblock(x, y, z, o, x1, y1, x2, y2, x3, y3, x4, y4)
	local v = o[1]+o[2]
	local xx, yy = x+(o[1]/math.abs(o[1])), y+(o[2]/math.abs(o[2]))
	if xx ~= xx then xx = x end 
	if yy ~= yy then yy = y end
	local x12, y12 = calcxpoint(points[xx][yy][1]), calcypoint(points[xx][yy][2], z)
	local x22, y22 = calcxpoint(points[xx+1][yy][1]), calcypoint(points[xx+1][yy][2], z)
	local x32, y32 = calcxpoint(points[xx+1][yy+1][1]), calcypoint(points[xx+1][yy+1][2], z)
	local x42, y42 = calcxpoint(points[xx][yy+1][1]), calcypoint(points[xx][yy+1][2], z)
	if v < 0 then v = math.abs(v) end
	x1, y1 = x1*(1-v)+x12*v, y1*(1-v)+y12*v
	x2, y2 = x2*(1-v)+x22*v, y2*(1-v)+y22*v
	x3, y3 = x3*(1-v)+x32*v, y3*(1-v)+y32*v
	x4, y4 = x4*(1-v)+x42*v, y4*(1-v)+y42*v
	return x1, y1, x2, y2, x3, y3, x4, y4
end

function gettilei(x, y, z, v)--get id of tile
	local i = false
	if model[z] and model[z][x] and model[z][x][y] then
		i = model[z][x][y][v or 1]
	end
	return i
end
function settilei(x, y, z, i, v) --set id of tile
	if model[z] and model[z][x] and model[z][x][y] then
		model[z][x][y][v or 1] = i
		updatelighting = true
	end
end
function isvisible(x, y, z)--check if block is visible
	local tilei = gettilei(x, y, z)
	local visible = false
	if not getisblock(x, y, z) or tilei == blockid.ice or gettilei(x, y, z, "offset") then
		visible = true
	end
	return visible
end
function getisblock(x, y, z)--check if block is not image, not empty space or border
	if type(gettilei(x, y, z)) == "number" and gettilei(x, y, z) ~= 0 then
		return true
	end
	return false
end
function gettiledata(x, y, z) --gets all of data in tile (tilei, shadows, wrenchno, etc.)
	local t = false
	if model[z] and model[z][x] and model[z][x][y] then
		t = model[z][x][y]
	end
	return t
end
function settiledata(x, y, z, t) --set tile data 
	if model[z] and model[z][x] and model[z][x][y] then
		model[z][x][y] = t
		updatelighting = true
	end
end

--Level loading--
function startlevel(i)
	--load level from files
	levelno = i
	model = loadlevel(i)
	
	--model viewing vars
	rotation = math.pi*.15
	rotationsection = 1--1-4
	rotationsection2 = 1 --1-8
	lightangle = 0--0
	nighttime = (i > #levelinfo-bonuslevels)
	
	--objects
	player_updateshadow()
	
	--animations
	animations = {}
	wrenchanimtimer = 0
	
	if levelinfo[levelno].music > 0 then
		playsound(gamemusic[levelinfo[levelno].music])
	end
	
	calculatelighting()
	updatelighting = false
	
	undo = false
end
function loadlevel(i)--load level from image and .txt file
	local img = love.image.newImageData("levels/" .. i .. ".png")
	local info = levelinfo[i]
	local m = {}
	
	modeld = info.depth
	modelw = img:getWidth()
	modelh = math.floor(img:getHeight()/modeld)
	
	--Creating player
	player = {
		x = 1,
		y = 1,
		z = 1,
		
		img = gamesprites,
		quad = playerq[1][1],
		frame = 1,
		animtimer = 0,
		idleframe = 1,
		
		dir = 1, --direction player facing 
		shadow = 2, --z of shadow
		jt = false, --falling timer
		jump = {false, 0, false}, 
		movet = {0, 0}, --moving offset
		movew = 0,--how much to wait to move when holding key down
		
		farjump = false, --move 2 blocks
		ice = false, --don't move when ice
		teleport = false, --don't move when portal
		onbutton = false, --just got on button
		switchsel = false --block switch button
	}
	player_setquad("idle", 1)
	
	local wrenchcount = 0 --wrenches to collect
	if info.help[1] and i <= #levelinfo-bonuslevels then
		helppopup = true --show help popup if not wrenches collected
	end
	
	--Loading level from images
	for z = 1, modeld do
		m[z] = {}
		for x = 1, modelw do
			m[z][x] = {}
			for y = 1, modelh do
				local r, g, b, a = img:getPixel(x-1, (modelh*(z-1))+(y-1))
				local tile = tiletable[r .. "-" ..  g.. "-" .. b .. "-" .. a] or 0
				if tile == "1" then--player
					player.x = x
					player.y = y
					player.z = z
					tile = 0
				end
				m[z][x][y] = {tile}
				if tile == blockid.wrench then
					wrenchcount = wrenchcount + 1
					m[z][x][y]["wrenchno"] = wrenchcount
					if levelinfo[levelno].wrench[wrenchcount] then
						m[z][x][y][1] = blockid.colwrench
						helppopup = false
					end
				end
			end
		end
	end
	
	--set up model draw points
	points = {}
	for x = 1, #m[1]+1 do
		points[x] = {}
		for y = 1, #m[1][1]+1 do
			points[x][y] = {}
		end
	end
	
	return m
end

--Player
function player_move(dir)
	if player.movet[1] ~= 0 or player.movet[2] ~= 0 then --wait for player to stop moving
		return
	end
	
	--adjust for rotation
	local d = dir-rotationsection+1
	while d < 1 do
		d = d + 4
	end
	
	--limit jump distance
	if player.jt and player.jump[1] then
		if player.jump[1] == true then
			player.jump[1] = d
		elseif player.jump[1] ~= false then --player jumping in a direction
			player.jump[2] = player.jump[2] + 1
			local nextblock = false --is player jumping on a high block
			if d == 4 then nextblock = getisblock(player.x-1, player.y, player.z+1) or gettilei(player.x-1, player.y, player.z+1) == blockid.jump
			elseif d == 2 then nextblock = getisblock(player.x+1, player.y, player.z+1) or gettilei(player.x+1, player.y, player.z+1) == blockid.jump
			elseif d == 3 then nextblock = getisblock(player.x, player.y-1, player.z+1) or gettilei(player.x, player.y-1, player.z+1) == blockid.jump
			else nextblock = getisblock(player.x, player.y+1, player.z+1) or gettilei(player.x, player.y+1, player.z+1) == blockid.jump end 
			if (not player.farjump and (player.jump[2] >= playerjumpdist or (player.jump[2] == 1 and nextblock))) or (player.farjump and player.jump[2] >= farjumpdist) or d ~= player.jump[1] then
				return
			end
		end
	end
	player.dir = d
	
	local oldx, oldy = player.x, player.y
	
	-- moving the player
	if d == 4 then --left
		if gettilei(player.x-1, player.y, player.z) == blockid.wrench or gettilei(player.x-1, player.y, player.z) == blockid.colwrench then --collect wrench
			collectwrench(player.x-1, player.y, player.z)
		end
		
		if gettilei(player.x-1, player.y, player.z) == 0 and not gettilei(player.x-1, player.y, player.z+1, "falltime") and not (gettilei(player.x-1, player.y, player.z+1) == blockid.push and not getisblock(player.x-1, player.y, player.z+2)) then
			player.x = player.x - 1
		elseif not player.jt and gettilei(player.x-1, player.y, player.z) == blockid.push and gettilei(player.x-2, player.y, player.z) == 0 and getisblock(player.x-1, player.y, player.z+1) and not gettilei(player.x-1, player.y, player.z, "falltime") then --push block
			--push stack
			local z = player.z
			while gettilei(player.x-1, player.y, z) == blockid.push and gettilei(player.x-2, player.y, z) == 0 do
				settilei(player.x-1, player.y, z, "falltime", nil)
				settilei(player.x-1, player.y, z, 0)
				settilei(player.x-2, player.y, z, blockid.push)
				--settilei(player.x-2, player.y, z, {1, 0}, "offset") 
				z = z-1
				playsound(sounds["push"])
			end
			player.x = player.x - 1
		end
	elseif d == 2 then --right
		if gettilei(player.x+1, player.y, player.z) == blockid.wrench or gettilei(player.x+1, player.y, player.z) == blockid.colwrench then
			collectwrench(player.x+1, player.y, player.z)
		end
		
		if gettilei(player.x+1, player.y, player.z) == 0 and not gettilei(player.x+1, player.y, player.z+1, "falltime") and not (gettilei(player.x+1, player.y, player.z+1) == blockid.push and not getisblock(player.x+1, player.y, player.z+2)) then
			player.x = player.x + 1
		elseif not player.jt and gettilei(player.x+1, player.y, player.z) == blockid.push and gettilei(player.x+2, player.y, player.z) == 0 and getisblock(player.x+1, player.y, player.z+1) and not gettilei(player.x+1, player.y, player.z, "falltime") then
			local z = player.z
			while gettilei(player.x+1, player.y, z) == blockid.push and gettilei(player.x+2, player.y, z) == 0 do
				settilei(player.x+1, player.y, z, "falltime", nil)
				settilei(player.x+1, player.y, z, 0)
				settilei(player.x+2, player.y, z, blockid.push)
				--settilei(player.x+2, player.y, z, {-1, 0}, "offset")
				z = z-1
				playsound(sounds["push"])
			end
			player.x = player.x + 1
		end
	elseif d == 3 then --up
		if gettilei(player.x, player.y-1, player.z) == blockid.wrench or gettilei(player.x, player.y-1, player.z) == blockid.colwrench then
			collectwrench(player.x, player.y-1, player.z)
		end
		
		if gettilei(player.x, player.y-1, player.z) == 0 and not gettilei(player.x, player.y-1, player.z+1, "falltime") and not (gettilei(player.x, player.y-1, player.z+1) == blockid.push and not getisblock(player.x, player.y-1, player.z+2)) then
			player.y = player.y - 1
		elseif not player.jt and gettilei(player.x, player.y-1, player.z) == blockid.push and gettilei(player.x, player.y-2, player.z) == 0 and getisblock(player.x, player.y-1, player.z+1) and not gettilei(player.x, player.y-1, player.z, "falltime") then
			local z = player.z
			while gettilei(player.x, player.y-1, z) == blockid.push and gettilei(player.x, player.y-2, z) == 0 do
				settilei(player.x, player.y-1, z, "falltime", nil)
				settilei(player.x, player.y-1, z, 0)
				settilei(player.x, player.y-2, z, blockid.push)
				--settilei(player.x, player.y-2, z, {0, 1}, "offset")
				z = z-1
				playsound(sounds["push"])
			end
			player.y = player.y - 1
		end
	elseif d == 1 then --down
		if gettilei(player.x, player.y+1, player.z) == blockid.wrench or gettilei(player.x, player.y+1, player.z) == blockid.colwrench then
			collectwrench(player.x, player.y+1, player.z)
		end
		
		if gettilei(player.x, player.y+1, player.z) == 0 and not gettilei(player.x, player.y+1, player.z+1, "falltime") and not (gettilei(player.x, player.y+1, player.z+1) == blockid.push and not getisblock(player.x, player.y+1, player.z+2)) then
			player.y = player.y + 1
		elseif not player.jt and gettilei(player.x, player.y+1, player.z) == blockid.push and gettilei(player.x, player.y+2, player.z) == 0 and getisblock(player.x, player.y+1, player.z+1) and not gettilei(player.x, player.y+1, player.z, "falltime") then
			local z = player.z
			while gettilei(player.x, player.y+1, z) == blockid.push and gettilei(player.x, player.y+2, z) == 0 do
				settilei(player.x, player.y+1, z, "falltime", nil)
				settilei(player.x, player.y+1, z, 0)
				settilei(player.x, player.y+2, z, blockid.push)
				--settilei(player.x, player.y+2, z, {0, -1}, "offset")
				z = z-1
				playsound(sounds["push"])
			end
			player.y = player.y + 1
		end
	end
	
	if player.jt and not (gettilei(player.x, player.y, player.z+1) == 0) then
		player.jt = false
		player.jump[1] = false
		player.jump[3] = false
		player.farjump = false
		player_setquad("idle", 1)
		--button press [set to 1(turn) or 2(switch) when hit ground button (To make sure it only presses once)]
		local b = gettilei(player.x, player.y, player.z+1)
		if b == blockid.turnh1 or b == blockid.turnh2 or b == blockid.turnv1 or b == blockid.turnv2 then
			player.buttonb = 1
		elseif b == blockid.switch1 or b == blockid.switch2 or b == blockid.switch3 or b == blockid.switch4 or b == blockid.switch5 or b == blockid.switch6 then
			player.buttonb = 2
		end
	end
	
	player.movet = {oldx-player.x, oldy-player.y}
	
	if (oldx ~= player.x or oldy ~= player.y) then 
		if not player.jt then
			player_setquad("idle", 1) --update walk cycle
		end
		player.movew = playerholdmove1 --add wait time when holding down key
	end
	
	player_updateshadow()
end

function player_jump(h, ignore)
	--jump 
	if ignore or (gettilei(player.x, player.y, player.z+1) ~= 0 and (gettilei(player.x, player.y, player.z-h) == 0 or gettilei(player.x, player.y, player.z-h) == blockid.wrench or gettilei(player.x, player.y, player.z-h) == blockid.colwrench)) then
		player.z = player.z - h
		player.jt = playerjumptime--jumptimer
		player.jump[1] = true
		player.jump[2] = 0
		player.jump[3] = true
		player.movew = playerholdmove2 --add wait time until player can move when holding key
		if gettilei(player.x, player.y, player.z) == blockid.wrench or gettilei(player.x, player.y, player.z) == blockid.colwrench then --collect wrench
			collectwrench(player.x, player.y, player.z)
		end
		playsound(sounds["jump"])
	elseif player.jt and player.jt == playerfalltime and player.jump[1] and (player.movet[1] ~= 0 or player.movet[2] ~= 0) and gettilei(player.x, player.y, player.z+1) == 0 and gettilei(player.x, player.y, player.z-h) == 0 then
		local isblock = false
		local dir = player.dir
		if player.movet[1] > 0 then
			local i = gettilei(player.x+1, player.y, player.z+1)
			isblock = getisblock(player.x+1, player.y, player.z+1) and (not (i == blockid.ice)) and (not (i == blockid.tele1)) and (not (i == blockid.tele2)) and (not (i == blockid.tele3)) and (not (i == blockid.tele4))
		elseif player.movet[1] < 0 then
			local i = gettilei(player.x-1, player.y, player.z+1)
			isblock = getisblock(player.x-1, player.y, player.z+1) and (not (i == blockid.ice)) and (not (i == blockid.tele1)) and (not (i == blockid.tele2)) and (not (i == blockid.tele3)) and (not (i == blockid.tele4))
		elseif player.movet[2] > 0 then
			local i = gettilei(player.x, player.y+1, player.z+1)
			isblock = getisblock(player.x, player.y+1, player.z+1) and (not (i == blockid.ice)) and (not (i == blockid.tele1)) and (not (i == blockid.tele2)) and (not (i == blockid.tele3)) and (not (i == blockid.tele4))
		elseif player.movet[2] < 0 then
			local i = gettilei(player.x, player.y-1, player.z+1)
			isblock = getisblock(player.x, player.y-1, player.z+1) and (not (i == blockid.ice)) and (not (i == blockid.tele1)) and (not (i == blockid.tele2)) and (not (i == blockid.tele3)) and (not (i == blockid.tele4))
		end
		if isblock and dir then
			player_jump(1, true)
			--player.jump[2] = player.jump[2] + 1
			player.jump[1] = dir
			player.movew = playerholdmove1
		end
	end
end

function player_updateshadow()
	--update position of shadow
	for z = player.z+1, modeld do
		if not (gettilei(player.x, player.y, z) == 0) then
			player.shadow = z
			break
		end
	end
end

function player_updateanim(dt) --automatically find correct player sprite
	if player.jt and player.jump[1] then
		if player.jump[3] and player.jt > playerjumpfalltime then
			player_setquad("jump")
		else
			player_setquad("fall")
		end
		player.idleframe = 1
	elseif player.ice then
		player_setquad("ice")
		player.idleframe = 1
	else
		player.animtimer = player.animtimer + dt
		while player.animtimer > playeranimidletime*dt do
			if player.frame == 1 then
				player.idleframe = 2
			else
				player.idleframe = 1
			end
			player.animtimer = player.animtimer - playeranimidletime
		end
		player_setquad("idle", player.idleframe)
	end
end

function player_setquad(n, i) --set player sprite
	local n, i = n or "idle", i or 1
	local dir = (rotationsection or 1)+player.dir-1
	while dir > 4 do
		dir = dir - 4
	end
	
	if n == "idle" then
		player.frame = i
	elseif n == "jump" then
		player.frame = 3
	elseif n == "fall" then
		player.frame = 4
	elseif n == "ice" then
		player.frame = 5
	end
	player.quad = playerq[dir][player.frame]
end

function collectwrench(x, y, z)--collect wrench
	if not levelinfo[levelno].wrench[gettilei(x, y, z, "wrenchno")] then
		levelinfo[levelno].wrench[gettilei(x, y, z, "wrenchno")] = true
		local a = math.max(1, math.ceil(wrenchanimtimer/wrenchanimdelay))
		table.insert(animations, {x=x, y=y, z=z, t=1, ts=.9, img=gamesprites, q=wrenchq, f=a, sf=a, color={255,255,255,255}, fade=true, spinout=true})
		
		local all = true --check if collected all wrenches
		for i = 1, #levelinfo[levelno].wrench do
			if not levelinfo[levelno].wrench[i] then all = false end
		end
		if all then levelfinish = 0 end
	else
		local a = math.max(1, math.ceil(wrenchanimtimer/wrenchanimdelay))
		table.insert(animations, {x=x, y=y, z=z, t=1, ts=.9, img=gamesprites, q=wrenchq, f=a, sf=a, color={240, 240, 240, 156}, fade=true, spinout=true})
		
		local all = 0 --check if one or less wrenches are left 
		for z = 1, #model do
			for x = 1, #model[z] do
				for y = 1, #model[z][x] do
					local i = gettilei(x, y, z)
					if i == blockid.wrench or i == blockid.colwrench then
						all = all + 1
					end
				end
			end
		end
		if all <= 1 then levelfinish = 0 end
	end
	wrenchcollectanim[1] = wrenchcollectanimtime --hud animation
	wrenchcollectanim[2] = gettilei(x, y, z, "wrenchno") --id
	settilei(x, y, z, 0)
	settilei(x, y, z, nil, "wrenchno")
	playsound(sounds["wrench"])
end

function calculatelighting()
	--adding depth to shadow
	for z = 1, modeld do
		for x = 1, modelw do
			for y = 1, modelh do
				--Shadow
				if shadowtype == "best" and shadowdepth > 0 then
					settilei(x, y, z, nil, "s")
					if getisblock(x, y, z) and not getisblock(x, y, z-1) then
						local ss1, ss2 = false, false
						for i = 1, shadowdepth do
							local s1 = getisblock(x, y+i, z-i*2+1) or getisblock(x, y+i, z-i*2)
							local s2 = getisblock(x, y+i, z-i*2) or getisblock(x, y+i, z-i*2-1)
							if not ss1 then
								ss1 = s1
							end
							if not ss2 then
								ss2 = s2
							end
							if (ss1 and ss2) or not gettilei(x, y+i, z-i*2) then
								break
							end
						end
						if ss1 or ss2 then
							settilei(x, y, z, {ss1, ss2}, "s")
						end
					end
				elseif shadowtype == "fast" and shadowdepth > 0 then
					settilei(x, y, z, nil, "s")
					if getisblock(x, y, z) and not getisblock(x, y, z-1) then
						for i = 1, shadowdepth do
							if getisblock(x, y+i, z-i) then
								settilei(x, y, z, true, "s")
								break
							elseif not gettilei(x, y+i, z-i) then
								break
							end
						end
					end
				end
				
				if ambientocclusion then
					--lighter shadow
					settilei(x, y, z, nil, "ao")
					if getisblock(x, y, z) and not getisblock(x, y, z-1) then
						local sides = {getisblock(x, y-1, z-1), getisblock(x+1, y, z-1), getisblock(x, y+1, z-1), getisblock(x-1, y, z-1)} 
						local ao = {false, false, false, false, false, false, false, false}
						if getisblock(x+1, y+1, z-1) and not (sides[2] or sides[3]) then
							ao[1] = true
						end
						if sides[3] then
							ao[2] = true
						end
						if getisblock(x-1, y+1, z-1) and not (sides[4] or sides[3])  then
							ao[3] = true
						end
						if sides[2] then
							ao[4] = true
						end
						if sides[4] then
							ao[5] = true
						end
						if getisblock(x+1, y-1, z-1) and not (sides[2] or sides[1])  then
							ao[6] = true
						end
						if sides[1] then
							ao[7] = true
						end
						if getisblock(x-1, y-1, z-1) and not (sides[1] or sides[4])  then
							ao[8] = true
						end
						if ao[1] or ao[2] or ao[3] or ao[4] or ao[5] or ao[6] or ao[7] or ao[8] then
							settilei(x, y, z, ao, "ao")
						end
					end
				end
			end
		end
	end
end

function game.gdraw(...)
	--adjust for spritebatch
	if not usespritebatch then
		love.graphics.draw(gamesprites, ...)
	else
		spritebatch:add(...)
	end
end

function game.setcolor(...)
	--adjust for spritebatch
	if not usespritebatch then
		love.graphics.setColor(...)
	else
		local r, g, b, a = ...
		if nighttime and graphicsquality == "fast" and tonumber(r) then
			spritebatch:setColor(r-80, g-80, b, a or 255)
		else
			spritebatch:setColor(...)
		end
	end
end

function storeUndo()
	undo = {}
	undo.model = deepcopy(model)
	undo.player = deepcopy(player)
	undo.wrenches = deepcopy(levelinfo[levelno].wrench)
end

function loadUndo()
	if undo then
		model = deepcopy(undo.model)
		player = deepcopy(undo.player)
		levelinfo[levelno].wrench = deepcopy(undo.wrenches)
		playsound(sounds["undo"])
		return true
	end
	return false
end