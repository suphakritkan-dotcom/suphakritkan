shader = {}

shader["blur"] = love.graphics.newShader[[
	extern vec2 size;
	extern number blursize;

	vec2 clamp(vec2 pos) {
		number x = pos.x;
		number y = pos.y;
		if (x < 0.0) x = 0.0;
		if (y < 0.0) y = 0.0;
		if (x > 1.0) x = 1.0;
		if (y > 1.0) y = 1.0;
		return vec2(x, y);
	}

	vec4 effect ( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ) {
		number distance = 1.0;
		number num = 0.0;
		vec4 averagecolor = vec4(0.0, 0.0, 0.0, 0.0);
		for (number x = -blursize ; x <= blursize; x++)
		for (number y = -blursize ; y <= blursize; y++) {
			vec4 color = Texel(texture, clamp(vec2(texture_coords.x + x/size.x, texture_coords.y + y/size.y)));
			if (color.a > 0.0) {
				num = num + 1.0;
				averagecolor.r = (averagecolor.r + color.r);
				averagecolor.g = (averagecolor.g + color.g);
				averagecolor.b = (averagecolor.b + color.b);
				averagecolor.a = (averagecolor.a + color.a);
				number x1 = x/size.x;
				number y1 = y/size.y;
				number dist = sqrt( x1*x1 + y1*y1 ) * 200;
				if (dist < distance) {
					distance = dist;
				}
			}
		}
		return vec4(averagecolor.r / num, averagecolor.g / num, averagecolor.b / num, averagecolor.a / num - distance);
	}
]]

shader["blur"]:send("size", {160, 160})
shader["blur"]:send("blursize", 3.0)
	
shader["glow"] = love.graphics.newShader[[
	//BlackBulletIV
   extern vec2 size = vec2(20,20);
   extern int samples = 2; // pixels per axis; higher = bigger glow, worse performance
   extern float quality = .5; // lower = smaller glow, better quality

   vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
   {
      vec4 src = Texel(tex, tc);
      vec4 sum = vec4(0);
      int diff = (samples - 1) / 2;
      vec2 sizeFactor = vec2(1) / size * quality;

      for (int x = -diff; x <= diff; x++)
      {
         for (int y = -diff; y <= diff; y++)
         {
            vec2 offset = vec2(x, y) * sizeFactor;
            sum += Texel(tex, tc + offset);
         }
      }

   return ((sum / (samples * samples)) + src) * color;
   }
]]

shader["night"] = love.graphics.newShader[[
	//Alesan
	
	vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
	{
		vec4 texcolor = Texel(texture, texture_coords);
		
		//Exclude certain colors (makes it slower? idk)
		//if (floor(texcolor.r*255) == 255 && floor(texcolor.g*255) == 198 && floor(texcolor.b*255) == 56)
		//	{}
		//else if (floor(texcolor.r*255) == 255 && floor(texcolor.g*255) == 244 && floor(texcolor.b*255) == 50)
		//	{}
		//else
		//	{
		
		texcolor.r = texcolor.r-0.19;
		texcolor.g = texcolor.g-0.19;
		texcolor.b = min(223, texcolor.b+0.01);
		
		return texcolor * color;
	}
]]

local pixelcode = [[
	vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
	{
		vec4 texcolor = Texel(texture, texture_coords);
		return texcolor * color;
	}
]]
local vertexcode = [[
	vec4 position( mat4 transform_projection, vec4 vertex_position )
	{
		return transform_projection * vertex_position;
	}
]]
shader["none"] = love.graphics.newShader(pixelcode, vertexcode)