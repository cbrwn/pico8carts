pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
--pyoro
--@z6v / cmrn.io
cartdata("pyoro")

local transcolor=3

debug=false

pointheights={}
--      [points]  =height
pointheights[10]  =128
pointheights[50]  =90
pointheights[100] =70
pointheights[300] =50
pointheights[1000]=30
pointcolors={}
--      [points] ={colors}
pointcolors[10]  ={8}
pointcolors[50]  ={0}
pointcolors[100] ={7}
pointcolors[300] ={0,1,9}
pointcolors[1000]={0,7,9}

function _init()
	startmenu()
end

function _draw()
	cls()
	if(gs.draw)gs.draw()
	
	if debug then
		print("m:"..flr(stat(0)),2,20,7)
		print("c:"..flr(stat(1)*100).."%",2,30,7)
	end
end

function _update60()
	updateinput()
	
	if(gs.update)gs.update()
end

--==============================
-- game state start
--==============================

--game init
function startgame()
	gs={}
	gs.draw=drawgame
	gs.update=updategame
	
	settrans(transcolor)
	
	score=0
	hiscore=dget(1)
	
	--difficulty
	bspawnt=0--bean spawn timer
	beanint=70--bean spawn interval
	beanspd=0.45--bean fall speed
	playspdmod=2.22--player speed = beanspd*this
	normstrk=0--normal bean streak
	
	actors={}
	beans={}
	makefloor()
	makeplayer()
end

--makes our player!
function makeplayer()
	local p={x=56,y=105}
	p.tongue=nil
	p.footsprite=4
	p.stepsound=0
	p.f=false--flipped
	p.ms=1--move speed
	p.t=0--walk timer for bobbing
	p.wheight=0--bobbing height
	p.e=0--eating anim
	p.dead=false
	p.sprloc={x=8,y=0}--location of bird sprite
	p.draw=function()
		--draw tongue
		if p.tongue!=nil then
			local l=p.tongue
			lineb(l.x,l.y,l.t.x,l.t.y,14,0)
			
			--end of tongue
			local ex=l.t.x-1
			if(p.f)ex-=7--flipped
			sspr(72,0,10,8,ex,l.t.y-1,10,8,p.f)
		end
		
		--footsies
		local footpos=5
		if(p.f)footpos=4--flipped
		sspr(40,p.footsprite,7,3,p.x+footpos,p.y+12,7,3,p.f)
		--bird sprite
		sspr(p.sprloc.x,p.sprloc.y,16,14,p.x,p.y+p.wheight,16,14,p.f)
	end
	
	--movement bounds
	local xmin=0
	local xmax=128-16
	
	p.update=function()
		if p.dead then
			--move off screen on death
			p.y+=0.5
			return
		end
		local m=false--moving
		
		--check if there is floor in front
		local fc=p.f and p.x+11 or p.x+4
		local fe=flooratpoint({x=fc,y=p.y+16})
		
		if p.tongue!=nil then
			--only need to update tongue
			--since we don't want to move
			p.tongue.update()
		else
			-- walkywalk
			if btn(0) and p.x>xmin then
				if fe then
				 m=true
				 p.x-=p.ms
				end
				p.f=false
			end
			if btn(1) and p.x<xmax then
				if fe then
					m=not m
					p.x+=p.ms
				end
				p.f=true
			end
		end
		
		--limit movement
		if(p.x<xmin)p.x=xmin
		if(p.x>xmax)p.x=xmax
		
		-- walky timer
		if m then
			p.t+=1
		else
			p.t=0
			p.wheight=0
		end
			
		-- eating anim
		if p.e>0 then
			p.e-=1
			if p.e%5==0 then
				if p.sprloc.y==0 then
					p.sprloc.y=16
				else
					p.sprloc.y=0
				end
			end
		else
			p.sprloc.y=0
		end
		
		--bob up and down
		if p.t > 3 then
			p.t=0
			if p.wheight==0 then
				p.wheight=1
				sfx(p.stepsound)
				--p.stepsound=(p.stepsound+1)%2
			else
				p.wheight=0
				sfx(1)
			end
		end
		
		--licking
		if keypressed(5) then
			p.maketongue()
		end
		
		--licking graphics
		if p.tongue!=nil then
			--tiptoe
			p.wheight=-1
			p.footsprite=0
			
			--open mouth
			p.sprloc.x=24
			p.sprloc.y=0
			p.e=0--dont eat with your mouth open
		else
			p.footsprite=4
			p.sprloc.x=8
		end
	end
	
	p.maketongue=function()
		if(p.tongue!=nil)return
		sfx(2,2)--channel 2 so we can stop it
		
		local t={x=p.x+1,y=p.y+5}
		if(p.f)t.x=p.x+14--flipped
		t.l=0 --length
		t.ext=true
		t.spd=flr(4.5*beanspd) --extend speed
		t.bspd=flr(18*beanspd) --retract speed
		t.t={x=t.x,y=t.y}--tip position
		t.lbean=nil--attached bean
		
		t.hit=function()
			t.ext=false
			sfx(4)
		end
	 
		t.update=function()
			if(t==nil)return
			if(not btn(5))t.ext=false
			
		 if t.ext then
		 	t.l+=t.spd
		 else
		 	t.l-=t.bspd
		 end
		 
		 -- delete
		 if t.l<=0 then
		 	t=nil
		 	p.tongue=nil
		 	sfx(-1,2)
		 	if lbean != nil then
		 		p.e=20
		 		del(actors,lbean)
		 		del(beans,lbean)
		 		lbean=nil
		 	end
		 	return
		 end
		 
		 --tip position
		 t.t.y=t.y-t.l
		 t.t.x=p.f and t.x+t.l or t.x-t.l
		 
		 --retract if we hit the edge
		 if t.t.y<=0 or
		    t.t.x<=1 or
		    t.t.x>=127 then
		    t.hit()
		 end
		 
		 --bean collision
		 if t.ext then
		 	for b in all(beans) do
		 		if pointinbox(t.t,b.x-2,b.y-2,10,10) then
		 			takebean(b)
		 			t.hit()
		 			lbean=b
		 			break
		 		end
		 	end
		 end
		 
		 --attach bean to tip
		 if lbean!=nil then
		 	lbean.x=t.t.x-4
		 	lbean.y=t.t.y-2
		 end
		end
		p.tongue=t
	end
	
	p.kill=function()
		p.dead=true
		p.sprloc.x=24
		p.sprloc.y=16
		p.tongue=nil
	end
	
	add(actors,p)
	player=p
end

--floor-related functions
function makefloor()
	floor={}
	
	local l=0
	local fwidth=8
	while l<128 do
		local f={x=l,y=120,a=2,s=21}
		l+=fwidth
		
		f.draw=function()
			if(f.a==2)spr(f.s,f.x,f.y)
		end
		
		add(floor,f)
		add(actors,f)
	end
end

--fixes n missing floor segments
function fixfloor(n)
	n=n or 1
	local d=0
	local amt=0
	while closestbrokenfloor()!=nil and amt<n do
		repairfloor(closestbrokenfloor(),amt*15)
		amt+=1
	end
end

--finds the closest missing floor
function closestbrokenfloor()
	local f=nil
	for fl in all(floor) do
		if fl.a==0 and
					(f==nil or
					 abs(f.x-player.x)>abs(fl.x-player.x)) then
			f=fl 
		end
	end
	return f
end

function breakfloor(f)
	--allow for index too
	if(type(f)=="number")f=floor[f]
	f.a=0
	sfx(5)
end

--is there a floor at point p?
function flooratpoint(p)
	for f in all(floor) do
		if f.a==2 then
			if p.x>f.x and
						p.y>f.y and
						p.x<=f.x+8 and
						p.y<=f.y+8 then
				return true			
			end
		end
	end
	return false
end

function repairfloor(f,d)
	d=d or 0
	--allow for index
	if(type(f)=="number")f=floor[f]
	makerepair(f,d)
end

function makerepair(f,d,s)
	s=s or 0
	d=d or 0
	
	local rp={x=f.x,y=-30,d=d,s=s}
	rp.hf=true--has floor
	rp.f=f
	rp.t=0
	rp.tl=40
	f.a=1--set floor to repairing
	
	local fpos=16
	
	rp.draw=function()
		sspr(64,8,9,16,rp.x,rp.y)
		
		--draw floor
		if rp.hf then
		 spr(21,rp.x,rp.y+fpos)
		end
	end
	
	rp.update=function()
	 local s=-30
	 local d=f.y-fpos
	 if not rp.hf then
	 	--swap dest and start
	 	-- when going up
	 	local t=s
	 	s=d
	 	d=t
	 end
	 
	 --delay
	 if rp.d>0 then
	 	rp.d-=1
	 	return
	 end
	 
	 rp.t+=1
	 local per=rp.t/rp.tl
	 
	 local yp=cerp(s,d,per)
	 rp.y=yp
	 
	 if per>1 then
	 	if rp.hf then
	 		--place floor
	 		rp.f.a=2
	 		rp.t=2
	 		rp.hf=false
	 	else
	 		--kill repairman
	 		del(actors,rp)
	 	end
	 end
	end
	
	add(actors,rp)
end

--bean-related functions

function makebean(x,y,t,spd)
	local b={x=x,y=y,t=t}
	b.s=0
	b.spd=spd or 0.5
	b.t=t
	b.tm=0
	b.swingspeed=50+rnd(40)
	b.a=true
	
	local sc1=11
	local sc2=3
	local bc1=11
	local bc2=3
	
	if b.t==1 then
		sc1=14
		sc2=8
		bc1=7
		bc2=6
	end
	
	local stemspr={x=48,y=16,
																w=16,h=8}
	local beanspr=7
	b.draw=function()
		--beans have different bg col
		settrans(2)
		
		--setup colours
		pal(11,sc1)
		pal(3,sc2)
		--draw stem
		sspr(stemspr.x,stemspr.y+(flr(b.s)*stemspr.h),stemspr.w,stemspr.h,b.x-(stemspr.w/4),b.y-stemspr.h)
		
		--setup colours
		setpal()
		pal(11,bc1)
		pal(3,bc2)
		--draw bean
		spr(beanspr+flr(b.s),b.x,b.y)
		
		--reset colour stuff
		setpal()
		settrans(transcolor)
	end
	
	b.update=function()
		b.y+=b.spd
		
		b.tm+=1
		--sprite swings
		b.s=sin(b.tm/b.swingspeed)+0.5
		
		if b.y > 140 then
			b.delete(0)
		end
		
		--only check collisions when
		-- it hasn't been licked
		if b.a then
			--check for floor collision
			for f in all(floor) do
				if b.y+7>=f.y and b.x+6>f.x and b.x+2<f.x+8 and f.a==2 then
					b.delete()
					breakfloor(f)
					break
				end
			end
			
			--check for player collision
			if b.x+8>player.x and
			   b.x<player.x+16 and
			   b.y+8>player.y and
			   b.y<player.y+15 then
				player.kill()
				b.delete()
			end
		end
	end
	
	b.delete=function(xpl)
		xpl=xpl or 1
		if(xpl==1)explosion(b.x,b.y)
		del(beans,b)
		del(actors,b)
	end
	
	add(beans,b)
	add(actors,b)
end

function takebean(b)
	b.a=false--disable collision
 
 --bean abilities
 if(b.t==1)fixfloor()
	
	--determine points
 local pts=-1
 for k,v in pairs(pointheights) do
 	if b.y<v and k>pts then
 		pts=k
 	end
 end
 
 setscore(score+pts/10)
	makepopup(pts,b.x,b.y)
	sfx(3)
end

--score popup
function makepopup(s,x,y)
	local p={x=x,y=y,t=s}
	p.cl=pointcolors[s] or {1}
	p.ci=1
	p.t=0
	
	p.draw=function()
		print(s.."",p.x,p.y,p.cl[p.ci])
	end
	
	p.update=function()
		p.t+=1
		
		if(p.t%3==0)p.ci+=1
		
		if(p.ci > #p.cl)p.ci=1
		
		if(p.t>=60)del(actors,p)
	end
	
	add(actors,p)
end

--bean 'explosion'
function explosion(x,y)
	local mdif=0.5
	local mov=1.3
	for i=0,30 do
		local xp=x-mdif+rnd(mdif*2)
		local yp=y-mdif+rnd(mdif*2)
		
		local dx=-mov+rnd(mov*2)
		local dy=-mov+rnd(mov*2)
		
		local col=6
		if(rnd(100)<50)col=7
		local s=2+rnd(2)
		
		makeparticle(xp,yp,dx,dy,col,s,25)
	end
end

--generic circle particle
function makeparticle(x,y,dx,dy,c,s,t)
 local p={x=x,y=y,dx=dx,dy=dy,c=c,s=s,t=t}
 
 p.update=function()
 	p.t-=1
 	
 	p.x+=p.dx
 	p.y+=p.dy
 	p.dx*=0.9
 	p.dy*=0.9
 	p.s-=0.15
 	
 	if(p.t<=0)del(actors,p)
 end
 
 p.draw=function()
 	circfill(p.x,p.y,p.s,p.c)
 end
 
 add(actors,p)
 return p
end

function updategame()
	bspawnt-=1
	
	if bspawnt<=0 then
		spawnbean()
	end
	
	for a in all(actors) do
		if a.update then
			a.update()
		elseif a.dx or a.dy then
			a.x+=a.dx
			a.y+=a.dy
		end
	end
	
	if player.dead and keypressed(4) then
		_init()
	end
end

--all the bean spawning magic
function spawnbean()
	local btype=0

	--ensure a special bean every once in a while
	if(rnd(100)<5 or normstrk>15)btype=1
	
	local spd=beanspd+rnd(0.1)
	if(rnd(100)<2)spd+=0.2
	
	--difficulty changes
	if(beanint>15)beanint-=0.7
	beanspd+=0.004
	beanint=(0.8/beanspd)*30
	player.ms=playspdmod*beanspd
	
	--update the number of beans since last special
	normstrk+=(btype==0 and 1 or -normstrk)
	
	makebean(rnd(104)+6,-24,btype,spd)
	bspawnt=beanint+rnd(30)
end

--sets score and changes hiscore
-- if new one is reached
function setscore(n)
 score=n
 if score>hiscore then
 	hiscore=score
 	dset(1,hiscore)
 end
end

function drawgame()
	drawbackground()
	
	for a in all(actors) do
		if a.draw then
			a.draw()
		elseif a.s then
			spr(a.s,a.x,a.y)
		end
	end
	
	local xof=6
	local yof=2
	print("score",xof,yof,7)
	print(padnumber(score,5).."0",xof+22,yof,7)
	print("high score",xof+50,yof,7)
	print(padnumber(hiscore,5).."0",xof+92,yof,7)
	
	if debug then
		print("int:"..beanint,2,60,7)
		print("spd:"..beanspd,2,68,7)
	end
	
	if player.dead then
		printbc("game over",64,90,7)
		printbc("Ž to restart",62,100,7)
	end
end

function drawbackground()
	cls(12)
	
	local col=1
	for b in all(bg) do
		rectfill(b.x,128,b.x+b.w,128-b.h,col)
		
		circfill(b.x+(b.w/2),128-b.h,b.w/2,col)
	end
end

--//////////////////////////////
-- game state end
--//////////////////////////////

--==============================
-- menu state start
--==============================

function startmenu()
	gs={}
	gs.update=updatemenu
	gs.draw=drawmenu
	settrans(0)
	makebackground()
	
	helppos=180
	helptext="press ‹‘ to move and — to shoot your tongue!   eat the tasty beans - the higher they are, the more points you'll earn     if you get hit, you lose!"
end

function makebackground()
	bg={}
	
	local lx=-rnd(20)
	
	while lx<128 do
		local w=9+rnd(8)
		if(w%2!=0)w+=1
		local h=30+rnd(50)
		
		local tp={x=lx,h=h,w=w}
		add(bg,tp)
		
		lx+=w+rnd(1)
	end
end

function updatemenu()
	if(btnp(5))startgame()
	
	helppos-=1
	if(btn(4))helppos-=1
	if helppos<=-(#helptext*4 + 24) then
		helppos=130
	end	
end

function drawmenu()
	drawbackground()
	
	local scale=1
	local sx=65
	local sy=33
	local tx=64-(sx*scale)/2
	local ty=54-(sy*scale)/2
	setpal(3)
	sspr(0,64,sx,sy,tx+1,ty+1,sx*scale,sy*scale)
	setpal()
	sspr(0,64,sx,sy,tx,ty,sx*scale,sy*scale)
	
	printb("— start",64-(15),75,7,0)
	
	printb(helptext,helppos,120,7,0)
end

--//////////////////////////////
-- menu state end
--//////////////////////////////

-- useful functions

-- cubic interpolation
-- start,destination,time(0..1)
function cerp(s,d,t)
	local c=(t*t*(3-2*t))
	return s+(d-s)*c
end

function pointinbox(p,x1,y1,w,h)
	if(p.x<x1)return false
	if(p.y<y1)return false
	if(p.x>x1+w)return false
	if(p.y>y1+h)return false
	return true
end

function padnumber(n,l)
	l=l or 6
	local s=n..""
	while #s < l do
		s = "0"..s
	end
	return s
end

--sets all pal colours to c
--or resets pal if c isn't given
function setpal(c)
	for i=0,16 do
		pal(i,c or i)
	end
end

local ctrans=0
function settrans(c)
	c=c or 0
	palt(ctrans,false)
	palt(c,true)
	ctrans=c
end

function printb(s,x,y,c,b)
	b=b or 0
	print(s,x-1,y,b)
	print(s,x+1,y,b)
	print(s,x,y-1,b)
	print(s,x,y+1,b)
	print(s,x+1,y+1,b)
	print(s,x-1,y-1,b)
	print(s,x-1,y+1,b)
	print(s,x+1,y-1,b)
	print(s,x,y,c)
end

function printbc(s,x,y,c,b)
	printb(s,x-(#s*2),y,c,b)
end

--bordered sprite
--draws a sprite with a 1px border
-- of colour b
function bspr(n,x,y,w,h,f,b)
	w=w or 1
	h=h or 1
	f=f or false
	b=b or 0
	
	-- border
	setpal(b)
	for i=-1,1,2 do
		spr(n,x+i,y,w,h,f)
		spr(n,x,y+i,w,h,f)
	end
	setpal()
	
	-- normal sprite
	spr(n,x,y,w,h,f)
end

function lineb(x1,y1,x2,y2,c,b)
	line(x1+1,y1,x2+1,y2,b)
	line(x1-1,y1,x2-1,y2,b)
	line(x1,y1+1,x2,y2+1,b)
	line(x1,y1-1,x2,y2-1,b)
	line(x1,y1,x2,y2,c)
end

function intable(v,tab)
	for t in all(tab) do
		if(t==v)return true
	end
	return false
end

-- input stuff

keysdown={}
keyspressed={}
function updateinput()
	keyspressed={}
	for i=0,7 do
		if btn(i) then
			if not intable(i,keysdown) then
				add(keyspressed,i)
				add(keysdown,i)
			end
		else
			if intable(i,keysdown) then
				del(keysdown,i)
			end
		end
	end
end

function keypressed(v)
	return intable(v,keyspressed)
end
__gfx__
00000000333333300003333333333000003333333303303322000022220002222220002230003333330000000000000000000000000000000000000000000000
00000000333330088880033300000888880033333003300320bbb02220bbb022220bb7020ee70333330000000000000000000000000000000000000000000000
0070070033330070008880330990700088880333030303030bbb70220bbb7022220bb7b00eeee033330000000000000000000000000000000000000000000000
0007700033330770070880330999000708880333333333330bbb70220bbb7b02220bbbb0300eee03330000000000000000000000000000000000000000000000
00077000333090007708880330999077088880333303303303bbb02203bbbb02220bbbb03330ee03330000000000000000000000000000000000000000000000
0070070033099990008888033309900088888033330330330333b02203bbbb022203bbb033330ee0330000000000000000000000000000000000000000000000
000000003099909988888803333099888888880300030003200002222033b022220333b0333330ee030000000000000000000000000000000000000000000000
0000000030000990888888033300998888888880333333332222222222000222222000023333330ee00000000000000000000000000000000000000000000000
00000000330990077788888033099077770888805666666722000002222222223300003333c383b3000000000000000000000000000000000000000000000000
00000000333007777770888030990777777088800555555620bbbbb022000222333333333b3e3c38000000000000000000000000000000000000000000000000
0000000033330777777088803090777777770003055555560b3003bb00bbb022330000333383b3e3000000000000000000000000000000000000000000000000
0000000033333077777700033000777777703333055555560002203b0bbbbb02307777033e3c383b000000000000000000000000000000000000000000000000
00000000333333000000033333330000000333330555555622222203b3003bb00677777033b3e3c3000000000000000000000000000000000000000000000000
00000000333333333333333333333333333333330555555622222220902203b0060707703c383b38000000000000000000000000000000000000000000000000
0000000033333333333333333333333333333333055555562222220a022220b00607077033e3c383000000000000000000000000000000000000000000000000
0000000033333333333333333333333333333333000000052222220a0222200030666603383b3e3c000000000000000000000000000000000000000000000000
00000000333333300003333333333330000333330000000022000022222222223000007033c383b3000000000000000000000000000000000000000000000000
00000000333330088880033333333008888003330000000020bbbb0220000222006777770b3e3c38000000000000000000000000000000000000000000000000
00000000333300700088803333330888888880330000000003333bb00bbbb022006777070383b3e3000000000000000000000000000000000000000000000000
000000003330077007088033333308888888803300000000000003b0bb33bb02300666003e3c383b000000000000000000000000000000000000000000000000
00000000330990007708880333309008888888030000000022222033b30003b03300077033b3e3c3000000000000000000000000000000000000000000000000
00000000309999900088880333099990008888030000000022222209002220b0333060703c383b3e000000000000000000000000000000000000000000000000
0000000030000099888888033099999988888803000000002222220a022222023333030333e3c383000000000000000000000000000000000000000000000000
0000000033330990888888033000099088888803000000002222220a0222222233333333383b3e3b000000000000000000000000000000000000000000000000
00000000333099077788888033099007778888800000000022222222220002220000000000000000000000000000000000000000000000000000000000000000
0000000033099077777088803330077777708880000000002220002200bbb0220000000000000000000000000000000000000000000000000000000000000000
000000003330077777708880333307777770888000000000220bbb00bbbbbb020000000000000000000000000000000000000000000000000000000000000000
00000000333330777777000333333077777700030000000020bb33b0b30003b00000000000000000000000000000000000000000000000000000000000000000
0000000033333300000003333333330000000333000000000b300033302220020000000000000000000000000000000000000000000000000000000000000000
0000000033333333333333333333333333333333000000000b022209022222220000000000000000000000000000000000000000000000000000000000000000
00000000333333333333333333333333333333330000000020222220a02222220000000000000000000000000000000000000000000000000000000000000000
00000000333333333333333333333333333333330000000022222220a02222220000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001111111111111100000000000000000111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000
00111aaaaaaaaaaaa1100000000000000001aaaaaaaaaa1100000000000000000000000000000000000000000000000000000000000000000000000000000000
11aaaabbbbbbbbbbaaa11000000000000001abbbbbbbbaaa11000000000000000000000000000000000000000000000000000000000000000000000000000000
1aabbbbbbbbbbbbbbbaa1100000000000001abbbbbbbbbbaaa100000000000000000000000000000000000000000000000000000000000000000000000000000
11abbbbbbbbbbbbbbbbaa100000000000001abbbbbbbbbbbbaa10000000000000000000000000000000000000000000000000000000000000000000000000000
01abbbbbbbbbbbbbbbbbaa10000000000001abbbbbbbbbbbbbaa1000000000000000000000000000000000000000000000000000000000000000000000000000
01aabbbbbbbbbbbbbbbbba11000000000001aaabbbbbaaaaabba1000000000000000000000000000000000000000000000000000000000000000000000000000
011abbbbbbbbbbbbbbbbbaa100000001100111aabbba1111aabaa100000000000000000000000000000000000000000000000000000000000000000000000000
001aaaaaaaaaaabbbbbbbba1000000110000011abbba10011abba100000000000000000000000000000000000000000000000000000000000000000000000000
0011111111111aaabbbbbba1000000100000001abbba10001abba100000110000000000000000000000000000000000000000000000000000000000000000000
000000000000111aabbbbba1000011100000001abbba10001abba100000011000000000000000000000000000000000000000000000000000000000000000000
0000000000000011abbbbba1100110110000001abbba10011abaa100000001000000000000000000000000000000000000000000000000000000000000000000
0000000000000001abababaa100100011000001abbba1111abaa1100000011111000000000000000000000000000000000000000000000000000000000000000
0001111100000001abbbbbaa100000001000001abbbbaaaaba001000000010001100000000000000000000000000000000000000000000000000000000000000
0011aaa100000011abababa1100000011111001abbbbbbbbba011000011110001100000000000000000000000000000000000000000000000000000000000000
001aaaa10000011aaaba1aa100000011aaa111aababababaaa1100111aaa11000100000000000000000000000000000000000000000000000000000000000000
001aaaa1000111aaaaa1a1a10001111aabaaa1aaabababaa1110011aaabaaa100000000000000000000000000000000000000000000000000000000000000000
001aaaa11111aaaaba1aaa11001aa1aabbbbaa1aaaaaaaaaa11001aabbbbbaa10000000000000000000000000000000000000000000000000000000000000000
0001aaaaaaaaaaaaa1aabba101aaaa1bbbbbba1aaaaaaaaaaa101aabbbbbbba10000000000000000000000000000000000000000000000000000000000000000
0001aaaaaaaaaaaaaa1aabba1aabbaa1bbbbba1aaaaaaaaaaa111abbbbbbbba10000000000000000000000000000000000000000000000000000000000000000
0001aaaaaaaaaaaa11111abbaabbaa1bababaaa1aaaa111aaaa11aabbbbbbba10000000000000000000000000000000000000000000000000000000000000000
00011aaaaaa11111000001abbbbaa1babababaa1aa11101aaaaa11aabababaa10000000000000000000000000000000000000000000000000000000000000000
00001aaa111100000000001abbaa1aaaaaaaaaa1a1100011aaaaa1ababababa10000000000000000000000000000000000000000000000000000000000000000
00001aaa10000000000001abbaa1aaaaaaaaaaa1a1000001aaaaa11aaaaaaaa10000000000000000000000000000000000000000000000000000000000000000
00001aaa1000000111101aaaba111aaaaaaaaaa1a10000011aa111aaaaaaaa110000000000000000000000000000000000000000000000000000000000000000
00001aa11000001aaaa1aabaa1001aaaaaaaaa11a10000001a11101aaaaaaa100000000000000000000000000000000000000000000000000000000000000000
00001111000001aaaaaaaaaa100011aaaaaaaa111100000011100001111111000000000000000000000000000000000000000000000000000000000000000000
00000000000001aaaaaaaaa100000111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000001aaaaaaaa1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000001aaaaaaa10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000001aaaaaa100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000001aaaa1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc11111111111111ccccccccccccccccc11111111111ccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc111aaaaaaaaaaaa11cccccccccccccccc1aaaaaaaaaa11ccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccc11aaaabbbbbbbbbbaaa11cccccccccccccc1abbbbbbbbaaa11ccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccc1aabbbbbbbbbbbbbbbaa11ccccccccccccc1abbbbbbbbbbaaa1cccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccc11abbbbbbbbbbbbbbbbaa13cccccccccccc1abbbbbbbbbbbbaa1ccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc1abbbbbbbbbbbbbbbbbaa1cccccccccccc1abbbbbbbbbbbbbaa1cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc1aabbbbbbbbbbbbbbbbba11ccccccccccc1aaabbbbbaaaaabba13ccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc11abbbbbbbbbbbbbbbbbaa13cccccc11cc111aabbba1111aabaa1ccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc1aaaaaaaaaaabbbbbbbba13ccccc1133cc311abbba13311abba13cccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc11111111111aaabbbbbba13ccccc133ccccc1abbba13cc1abba13cccc11cccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccc333333333111aabbbbba13ccc1113cccccc1abbba13cc1abba13ccccc11ccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc311abbbbba11cc11311cccccc1abbba13c11abaa13cccccc13cccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccc1abababaa13c133c11ccccc1abbba1111abaa113ccccc11111cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccc11111ccccccc1abbbbbaa13cc3ccc13cccc1abbbbaaaaba33133ccccc133313ccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc11aaa13ccccc11abababa113ccccc11111cc1abbbbbbbbba3113ccc11113cc13ccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc1aaaa13cccc11aaaba1aa133cccc11aaa111aababababaaa1133111aaa11ccc3ccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc1aaaa13cc111aaaaa1a1a13cc1111aabaaa1aaabababaa1113311aaabaaa1cccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc1aaaa11111aaaaba1aaa113c1aa1aabbbbaa1aaaaaaaaaa113c1aabbbbbaa1ccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccc1aaaaaaaaaaaaa1aabba131aaaa1bbbbbba1aaaaaaaaaaa131aabbbbbbba13cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccc1aaaaaaaaaaaaaa1aabba1aabbaa1bbbbba1aaaaaaaaaaa111abbbbbbbba13cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccc1aaaaaaaaaaaa11111abbaabbaa1bababaaa1aaaa111aaaa11aabbbbbbba13cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccc11aaaaaa11111333331abbbbaa1babababaa1aa11131aaaaa11aabababaa13cccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc1aaa111133333ccccc1abbaa1aaaaaaaaaa1a1133311aaaaa1ababababa13cccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc1aaa13333cccccccc1abbaa1aaaaaaaaaaa1a133ccc1aaaaa11aaaaaaaa13cccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc1aaa13ccccc1111c1aaaba111aaaaaaaaaa1a13cccc11aa111aaaaaaaa113cccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc1aa113cccc1aaaa1aabaa1331aaaaaaaaa11a13ccccc1a11131aaaaaaa133cccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc111133ccc1aaaaaaaaaa133c11aaaaaaaa11113ccccc1113331111111133ccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc3333cccc1aaaaaaaaa133ccc11111111133333cccccc33311113333333cccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc1aaaaaaaa133ccccc333333333ccccccccc1111111111111cccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc1aaaaaaa133cccccccccccccccccccccccc1111111111111cccccccc11111ccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccc1aaaaaa133cccccccccccccccccccccccc111111111111111ccccc111111111ccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccc1aaaa133ccccccccccccccccccccccccc111111111111111cccc11111111111cccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccc111133ccccccccccccccccccccccccc11111111111111111cc1111111111111ccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccc3333cccccccccccccccccccccccccc11111111111111111c111111111111111cccccccccccccccccc
ccc11111cccccccccccccccccccccccccccccccccccccccccccccccc11111cccccccc11111ccc11111111111111111c111111111111111cccccccccccccccccc
cc1111111cccccccccccccccccccccccccccccccccccccccccccccc1111111cccccc1111111cc1111111111111111111111111111111111ccccccccccccccccc
c111111111ccccccccccccccccccccc11111cccccccccccccccccc111111111cccc111111111c1111111111111111111111111111111111ccccccccccccccccc
11111111111ccccccccccccccccccc1111111cccccccccccc000000011111000000000000000000001111111111111111111111111111111cccccccccccccccc
111111111111ccccccccccccccccc111111111cccccccccc0077777001110077077707770777077701111111111111111111111111111111cccccccccccccccc
111111111111ccccc11111cccccc11111111111ccccccccc0770707701110700007007070707007001111111111111111111111111111111cccccccccccccccc
1111111111111cc111111111cccc11111111111ccccccccc0777077701110777007007770770007011111111111111111111111111111111cccccccccccccccc
1111111111111c11111111111cc1111111111111ccc111110770707701110007007007070707007011111111111111111111111111111111cccccccccccccccc
11111111111111111111111111c1111111111111cc1111110077777001110770007007070707007011111111111111111111111111111111cccccccccccccccc
11111111111111111111111111c1111111111111c11111111000000011110000100000000000000011111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cccccccccccccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111ccccc11111cccccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111ccc111111111cccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111cc11111111111ccc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111c1111111111111cc
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111c
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111c
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010100000752000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100000952006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d00001a1301b1311c1311d1311e1311f131201312113122131231311f001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200000f757000001b7560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00003561500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010500001315300000051530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

