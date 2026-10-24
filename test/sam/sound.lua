-- Plays the game's sound hooks in MAME and logs the SAA 1099 writes.
--   env SAMSFX="frame:address,frame:address"  the frames at which the hook at the (hex) address is called, as if the game had called it
--       SAMEND   the frame to stop at     SAMLOG  the file for the log
local hooks = {}
for f, a in (os.getenv("SAMSFX") or ""):gmatch("(%d+):(%x+)") do hooks[tonumber(f)] = tonumber(a, 16) end
local last = tonumber(os.getenv("SAMEND") or "1500")
local log = io.open(os.getenv("SAMLOG") or "saa.log", "w")
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local io_space = cpu.spaces["io"]
local n = 0
local f9 = manager.machine.ioport.ports[":kbd_2"].fields["F9"]
local addr = 0
local taps = {}
taps[#taps + 1] = io_space:install_write_tap(0x00ff, 0x01ff, "saa", function(offset, data, mask)
  if offset & 0xff ~= 0xff then return end
  if offset & 0xff00 == 0x100 then addr = data else log:write(string.format("%d %02x %02x\n", n, addr, data)) end
end)
emu.register_frame_done(function()
  n = n + 1
  if n == 200 then f9:set_value(1) end
  if n == 300 then f9:set_value(0) end
  if hooks[n] then
    local sp = cpu.state["SP"].value
    local pc = cpu.state["PC"].value
    sp = sp - 2
    mem:write_u8(sp, pc & 0xff); mem:write_u8(sp + 1, pc >> 8)
    cpu.state["SP"].value = sp
    if os.getenv("SAMREGS") then for r, v in os.getenv("SAMREGS"):gmatch("(%u+)=(%x+)") do cpu.state[r].value = tonumber(v, 16) end end
    cpu.state["PC"].value = hooks[n]
    log:write(string.format("%d hook %04x from pc=%04x\n", n, hooks[n], pc))
  end
  if n > 700 and n < 760 and os.getenv("SAMVARS") then
    local t = {}
    for a in os.getenv("SAMVARS"):gmatch("%x+") do t[#t + 1] = string.format("%02x", mem:read_u8(tonumber(a, 16))) end
    log:write(string.format("%d status=%02x vars %s\n", n, io_space:read_u8(0xf9), table.concat(t, " ")))
  end
  if n == last then log:close(); manager.machine:exit() end
end)
