
res = {426, 240}

bonuslevels = 6 -- no. of bonus levels
unlockbonus = 16 --how many wrenches must be collected in order to unlock the bonus levels

shadowcolor = {191, 202, 209, 55}--color of shadows 

vrotate = false
vrotation = 0.55--vertical rotation
zoom = false
usespritebatch = false

blockid = {push=3, jump="4", ice=9, wrench="2", colwrench = "3", tele1=13, tele2=14, tele3=15, tele4=16, turn=18, turnh1=19, turnh2=20, turnv1=21, turnv2=22, switch1=24, switch2=25, switch3=26, switch4=27, switch5=28, switch6=29}--block property
blocksize = 16 --should be texturesize
angledblocksize = 16	--block size of sides
angleval = 0.55 --angle value (block size is multiplied for top)

playerfalltime = 0.11 --time it takes to fall one block
playerjumpfalltime = 0.22 --playerfalltime*2 --falling from jump
playerjumptime = .2+playerjumpfalltime --time it takes to jump one block 
playermovespeed = 12
playerjumpdist = 2
farjumpdist = 3 --how far player jumps on trampoline
playeranimidletime = 0.24 --animation speed of idle

playerholdmove1 = 0.22 --time button needs to be held to move again
playerholdmove2 = 0.04 --time button needs to be held to move againa after jumping
playerholdmove3 = 0.2--time button needs to be held to move again after landing

pushblockspeed = playermovespeed

wrenchanimdelay = 0.18 --how fast is spins

blockfalltime = 0.06