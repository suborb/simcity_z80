-- The FP-1100's floppy pack for z88dk-ticks: a uPD765A (upd765.lua in z88dk's lib/ticks, which ticks has on its Lua path) behind the slot ports, with one disc.  The slot group/slot is chosen by $FFA0 (CPU select) and the
-- $FF00 range (I/O select): the driver has to look for the pack in PACK_SLOT (default 5: slot group 1, slot 1).  Port $00FE written with 1 dumps the sectors that were written to
-- disk_out.txt and the commands to fdc_log.txt.  env: FDC_IMAGE (a .d88), FDC_TRACE, PACK_SLOT.
-- (newer ticks puts z88dk's lib/ticks on the path itself; the older ones do not)
package.path = (os.getenv("ZCCCFG") or "") .. "/../ticks/?.lua;" .. package.path
local PACK_SLOT = tonumber(os.getenv("PACK_SLOT") or "5")
local fdc = require("upd765")({ image = os.getenv("FDC_IMAGE"), cylinders = 40, heads = 2, sectors = 16, trace = os.getenv("FDC_TRACE") ~= nil })
local cpusel, iosel = 0, 0
local errors = fdc.errors

local function selected()
    return (cpusel & 1) == (PACK_SLOT >> 2) and (iosel & 3) == (PACK_SLOT & 3)
end

function io_in(addr)
    if addr >= 0xff00 and addr < 0xff80 then
        if selected() then return 4 end
        return 0xff
    end
    if addr >= 0xff00 then return nil end
    if not selected() then return 0xff end
    local r = addr & 7
    if r == 4 then return fdc.msr()
    elseif r == 5 or r == 6 then return fdc.data_read() end
    return 0xff
end

function io_out(addr, value)
    value = value & 0xff
    if (addr & 0xffff) == 0xffa0 then cpusel = value; if value & 2 == 0 then errors[#errors + 1] = "ROM selected" end; return 0 end
    if (addr & 0xffe0) == 0xff00 then iosel = value; return 0 end
    if (addr & 0xff) == 0xfe and addr < 0x100 then
        if value == 1 then fdc.dump() end
        return 0
    end
    if addr >= 0xff00 then return -1 end
    if not selected() then return -1 end
    local r = addr & 7
    if r == 0 or r == 1 then fdc.motor(true); return 0
    elseif r == 2 or r == 3 then fdc.tc(); return 0
    elseif r == 5 or r == 6 then fdc.data_write(value); return 0 end
    return -1
end
