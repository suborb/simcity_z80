-- usage: MAME -autoboot_script samkeys.lua ; env SAMKEYS="frame:port:field:len,..." SAMSNAPS="frame,frame"
local keys={}
for item in (os.getenv("SAMKEYS") or ""):gmatch("[^,]+") do
  local f,p,name,len=item:match("^(%d+)|([%w_]+)|(.-)|(%d+)$")
  keys[#keys+1]={f=tonumber(f),p=":"..p,name=name,len=tonumber(len)}
end
local snaps={}
for f in (os.getenv("SAMSNAPS") or ""):gmatch("%d+") do snaps[tonumber(f)]=true end
local last=tonumber(os.getenv("SAMEND") or "1500")
local memlog
if os.getenv("SAMMEM") then
  memlog={}
  for f,a in os.getenv("SAMMEM"):gmatch("(%d+):(%x+)") do f=tonumber(f); memlog[f]=memlog[f] or {}; table.insert(memlog[f],a) end
end
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
  if os.getenv('SAMPOKE') and n == tonumber(os.getenv('SAMPOKEAT') or '1400') then   -- SAMPOKE="addr=hexbytes addr=hexbytes": game variables set directly (the data window is page 3)
    local mem=cpu.spaces['program']; local io=cpu.spaces['io']; io:write_u8(0xfb,3)
    for a,b in os.getenv('SAMPOKE'):gmatch('(%x+)=(%x+)') do local v=tonumber(a,16); for i=1,#b,2 do mem:write_u8(v+(i-1)//2,tonumber(b:sub(i,i+1),16)) end end
  end
  if snaps[n] then manager.machine.video:snapshot() end
  if memlog and memlog[n] then   -- SAMMEM="frame:addr,frame:addr": one byte of the data window (page 3) printed at each frame, "peek-mem frame addr value" (go.sh keeps the lines that say peek)
    local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3)
    for _,a in ipairs(memlog[n]) do print(string.format("peek-mem %d %s %d", n, a, mem:read_u8(tonumber(a,16)))) end
  end
  if os.getenv("SAMDUMP") and n == tonumber(os.getenv("SAMDUMPAT") or "0") then   -- SAMDUMP="addr:len:file": the data window (page 3) written to a file
    local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3)
    for a,l,fn in os.getenv("SAMDUMP"):gmatch("(%x+):(%d+):([^,]+)") do
      local out=_G.io.open(fn,"wb"); local v=tonumber(a,16)
      for i=0,tonumber(l)-1 do out:write(string.char(mem:read_u8(v+i))) end
      out:close()
    end
  end
  if n==last and os.getenv("SAMPEEK") then local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3); for a in os.getenv("SAMPEEK"):gmatch("%x+") do local v=tonumber(a,16); print(string.format("peek %04x = %02x %02x %02x %02x",v,mem:read_u8(v),mem:read_u8(v+1),mem:read_u8(v+2),mem:read_u8(v+3))) end end
  if n==last then print(string.format("pc=%04x sp=%04x",cpu.state["PC"].value,cpu.state["SP"].value)); manager.machine:exit() end
end)
