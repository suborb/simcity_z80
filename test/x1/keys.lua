-- MAME x1 driver: env X1KEYS="frame:text,..." typed with natkeyboard, X1SNAPS="frame,frame" screenshots, X1END = last frame
local keys={}
for f,t in (os.getenv("X1KEYS") or ""):gmatch("(%d+):([^,]*)") do keys[tonumber(f)]=t:gsub("<CR>","\r"):gsub("<SP>"," ") end
local snaps={}
for f in (os.getenv("X1SNAPS") or ""):gmatch("%d+") do snaps[tonumber(f)]=true end
local last=tonumber(os.getenv("X1END") or "1500")
local n=0
local cpu=manager.machine.devices[":maincpu"]
emu.register_frame_done(function()
  n=n+1
  if keys[n] then manager.machine.natkeyboard:post(keys[n]) end
  if snaps[n] then manager.machine.video:snapshot() end
  if n==last then print(string.format("pc=%04x sp=%04x",cpu.state["PC"].value,cpu.state["SP"].value)); manager.machine:exit() end
end)
