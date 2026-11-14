-- usage: MAME -autoboot_script samkeys.lua ; env SAMKEYS="frame:port:field:len,..." SAMSNAPS="frame,frame"
-- SAMSHIFT=n: every frame the script is given (keys, snapshots, peeks, pokes, dumps, the end) is n frames later, and the peeks print the frame they were asked for: the image takes a while to load
-- (go.sh sets it), and the tests are written for frame 700 as the first they may press a key at
local keys={}
for item in (os.getenv("SAMKEYS") or ""):gmatch("[^,]+") do
  local f,p,name,len=item:match("^(%d+)|([%w_]+)|(.-)|(%d+)$")
  keys[#keys+1]={f=tonumber(f),p=":"..p,name=name,len=tonumber(len)}
end
local snaps={}
for f in (os.getenv("SAMSNAPS") or ""):gmatch("%d+") do snaps[tonumber(f)]=true end
local pokes
if os.getenv("SAMPOKES") then
  pokes={}
  for f,a,b in os.getenv("SAMPOKES"):gmatch("(%d+):(%x+)=(%x+)") do f=tonumber(f); pokes[f]=pokes[f] or {}; table.insert(pokes[f],{a=tonumber(a,16),b=b}) end
end
local pgs
if os.getenv("SAMPG") then
  pgs={}
  for f,pg,a in os.getenv("SAMPG"):gmatch("(%d+):(%d+):(%x+)") do f=tonumber(f); pgs[f]=pgs[f] or {}; table.insert(pgs[f],{p=tonumber(pg),a=tonumber(a,16)}) end
end
local pcrange
if os.getenv("SAMPC") then local a,b=os.getenv("SAMPC"):match("(%d+)-(%d+)"); pcrange={tonumber(a),tonumber(b)} end
local last=tonumber(os.getenv("SAMEND") or "1500")
local memlog
if os.getenv("SAMMEM") then
  memlog={}
  for f,a in os.getenv("SAMMEM"):gmatch("(%d+):(%x+)") do f=tonumber(f); memlog[f]=memlog[f] or {}; table.insert(memlog[f],a) end
end
local n=0
local shift=tonumber(os.getenv("SAMSHIFT") or "0")
local ready_addr,ready_at,n0
if (os.getenv("SAMREADY") or "") ~= "" then local a,f=os.getenv("SAMREADY"):match("(%x+):(%d+)"); ready_addr=tonumber(a,16); ready_at=tonumber(f) end
local cpu=manager.machine.devices[":maincpu"]
local function field(k) return manager.machine.ioport.ports[k.p].fields[k.name] end
local f9=manager.machine.ioport.ports[":kbd_2"].fields["F9"]
emu.register_frame_done(function()
  n=n+1
  local hm=cpu.spaces["io"]:read_u8(0xfb)
  local m=n-shift                                   -- (the script's frame)
  if ready_addr and not n0 and m >= 650 then                      -- SAMREADY="addr:frame": (looked at only from script frame 650: the image is still loading before, and a changed HMPR would break that) the game is up when the byte at addr (a game variable that is 0 until then: the loop's frame counter) is not 0; the script's clock is then at `frame`
    cpu.spaces["io"]:write_u8(0xfb,3)
    if cpu.spaces["program"]:read_u8(ready_addr) ~= 0 then n0=n end
    if hm ~= 3 then cpu.spaces["io"]:write_u8(0xfb,hm) end
  end
  if n0 then m=n-n0+ready_at end
  local _unused               -- (the peeks, pokes and dumps below page the data in at $8000 to read it: the game's own HMPR goes back, or its drawing would go into the data)
  if n==200 then f9:set_value(1) end
  if n==300 then f9:set_value(0) end
  for _,k in ipairs(keys) do
    if m==k.f then field(k):set_value(1) end
    if m==k.f+k.len then field(k):set_value(0) end
  end
  if os.getenv('SAMPOKE') and m == tonumber(os.getenv('SAMPOKEAT') or '1400') then   -- SAMPOKE="addr=hexbytes addr=hexbytes": game variables set directly (the data window is page 3)
    local mem=cpu.spaces['program']; local io=cpu.spaces['io']; io:write_u8(0xfb,3)
    for a,b in os.getenv('SAMPOKE'):gmatch('(%x+)=(%x+)') do local v=tonumber(a,16); for i=1,#b,2 do mem:write_u8(v+(i-1)//2,tonumber(b:sub(i,i+1),16)) end end
  end
  if pokes and pokes[m] then   -- SAMPOKES="frame:addr=hexbytes,frame:addr=hexbytes": game variables set directly at the frames (the data window is page 3), as SAMPOKE does at one
    local mem=cpu.spaces['program']; local io=cpu.spaces['io']; io:write_u8(0xfb,3)
    for _,it in ipairs(pokes[m]) do for i=1,#it.b,2 do mem:write_u8(it.a+(i-1)//2,tonumber(it.b:sub(i,i+1),16)) end end
  end
  if pcrange and m >= pcrange[1] and m <= pcrange[2] then   -- SAMPC="first-last": the program counter and stack pointer at the end of each of these frames ("pc frame pc sp")
    print(string.format("pc-trace %d %04x %04x lmpr=%02x hmpr=%02x", m, cpu.state["PC"].value, cpu.state["SP"].value, cpu.spaces["io"]:read_u8(0xfa), hm))
  end
  if pgs and pgs[m] then   -- SAMPG="frame:page:addr,...": 8 bytes at addr ($8000 up) of any page, printed as "peek-pg frame page addr bytes" (HMPR is put back)
    local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; local keep=hm
    for _,it in ipairs(pgs[m]) do io:write_u8(0xfb,it.p); local t={}; for i=0,7 do t[#t+1]=string.format("%02x",mem:read_u8(it.a+i)) end; print(string.format("peek-pg %d %d %04x %s", m, it.p, it.a, table.concat(t))) end
  end
  if snaps[m] then manager.machine.video:snapshot() end
  if memlog and memlog[m] then   -- SAMMEM="frame:addr,frame:addr": one byte of the data window (page 3) printed at each frame, "peek-mem frame addr value" (go.sh keeps the lines that say peek)
    local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3)
    for _,a in ipairs(memlog[m]) do print(string.format("peek-mem %d %s %d", m, a, mem:read_u8(tonumber(a,16)))) end
  end
  if os.getenv("SAMDUMP2") and m == tonumber(os.getenv("SAMDUMP2AT") or "0") then   -- the same as SAMDUMP, at a second frame
    local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3)
    for a,l,fn in os.getenv("SAMDUMP2"):gmatch("(%x+):(%d+):([^,]+)") do
      local out=_G.io.open(fn,"wb"); local v=tonumber(a,16)
      for i=0,tonumber(l)-1 do out:write(string.char(mem:read_u8(v+i))) end
      out:close()
    end
  end
  if os.getenv("SAMDUMP") and m == tonumber(os.getenv("SAMDUMPAT") or "0") then   -- SAMDUMP="addr:len:file": the data window (page 3) written to a file
    local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3)
    for a,l,fn in os.getenv("SAMDUMP"):gmatch("(%x+):(%d+):([^,]+)") do
      local out=_G.io.open(fn,"wb"); local v=tonumber(a,16)
      for i=0,tonumber(l)-1 do out:write(string.char(mem:read_u8(v+i))) end
      out:close()
    end
  end
  if os.getenv("SAMSYSV") and m == tonumber(os.getenv("SAMSYSV")) then   -- SAMSYSV=frame: SAM BASIC's system variables SAMDOS page (SVAR 450 = $5BC2), DOSER ($5BC0), DOSCNT ($5BC3) read with the BASIC LMPR paged in
    local io=cpu.spaces["io"]; local mem=cpu.spaces["program"]; local lm=io:read_u8(0xfa)
    io:write_u8(0xfa,0x1f)
    print(string.format("sysvars samdos_page=%d doser=%02x%02x doscnt=%02x", mem:read_u8(0x5bc2), mem:read_u8(0x5bc1), mem:read_u8(0x5bc0), mem:read_u8(0x5bc3)))
    io:write_u8(0xfa,lm)
  end
  if cpu.spaces["io"]:read_u8(0xfb) ~= hm then cpu.spaces["io"]:write_u8(0xfb,hm) end   -- (only if one of the blocks above changed it)
  if m==last and os.getenv("SAMPEEK") then local mem=cpu.spaces["program"]; local io=cpu.spaces["io"]; io:write_u8(0xfb,3); for a in os.getenv("SAMPEEK"):gmatch("%x+") do local v=tonumber(a,16); print(string.format("peek %04x = %02x %02x %02x %02x",v,mem:read_u8(v),mem:read_u8(v+1),mem:read_u8(v+2),mem:read_u8(v+3))) end end
  if m==last then local io=cpu.spaces["io"]; print(string.format("lmpr=%02x hmpr=%02x vmpr=%02x", io:read_u8(0xfa), io:read_u8(0xfb), io:read_u8(0xfc))) end
  if m==last then print(string.format("pc=%04x sp=%04x",cpu.state["PC"].value,cpu.state["SP"].value)); manager.machine:exit() end
end)
