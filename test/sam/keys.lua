-- usage: MAME -autoboot_script samkeys.lua ; env SAMKEYS="frame:port:field:len,..." SAMSNAPS="frame,frame"
local keys={}
for item in (os.getenv("SAMKEYS") or ""):gmatch("[^,]+") do
  local f,p,name,len=item:match("^(%d+)|([%w_]+)|(.-)|(%d+)$")
  keys[#keys+1]={f=tonumber(f),p=":"..p,name=name,len=tonumber(len)}
end
local snaps={}
for f in (os.getenv("SAMSNAPS") or ""):gmatch("%d+") do snaps[tonumber(f)]=true end
local last=tonumber(os.getenv("SAMEND") or "1500")
local n=0
local cpu=manager.machine.devices[":maincpu"]
local function field(k) return manager.machine.ioport.ports[k.p].fields[k.name] end
local f9=manager.machine.ioport.ports[":kbd_2"].fields["F9"]
emu.register_frame_done(function()
  n=n+1
  if n==200 then f9:set_value(1) end
  if n==300 then f9:set_value(0) end
  for _,k in ipairs(keys) do
    if n==k.f then field(k):set_value(1) end
    if n==k.f+k.len then field(k):set_value(0) end
  end
  if snaps[n] then manager.machine.video:snapshot() end
  if n==last and os.getenv("SAMPEEK") then local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3); for a in os.getenv("SAMPEEK"):gmatch("%x+") do local v=tonumber(a,16); print(string.format("peek %04x = %02x %02x %02x %02x",v,mem:read_u8(v),mem:read_u8(v+1),mem:read_u8(v+2),mem:read_u8(v+3))) end end
  if n==last then print(string.format("pc=%04x sp=%04x",cpu.state["PC"].value,cpu.state["SP"].value)); manager.machine:exit() end
end)
