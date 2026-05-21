#!/usr/bin/env python3
import mmap, os, struct, sys

BASE = 0x40600000
SIZE = 0x10000

ADDR_TAP  = 0x00
ADDR_IDX  = 0x04
ADDR_DATA = 0x08
ADDR_WE   = 0x0C

if len(sys.argv) != 3:
    print("Usage: python3 read_coeff.py <tap> <addr>")
    sys.exit(1)

tap  = int(sys.argv[1])
idx  = int(sys.argv[2])

fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
mm = mmap.mmap(fd, SIZE, mmap.MAP_SHARED,
               mmap.PROT_READ | mmap.PROT_WRITE,
               offset=BASE)

def write_reg(off, val):
    mm.seek(off)
    mm.write(struct.pack("<I", val & 0xFFFFFFFF))

def read_reg(off):
    mm.seek(off)
    return struct.unpack("<I", mm.read(4))[0]

# -------------------------------
# TAP auswählen
# -------------------------------
write_reg(ADDR_TAP, tap)

# -------------------------------
# IDX auswählen
# -------------------------------
write_reg(ADDR_IDX, idx)


# -------------------------------
# BUS-READ triggern
# Dazu ren=1 schreiben: (ren == write to ADDR_WE mit Wert bit31=1)
# -------------------------------
write_reg(ADDR_WE, 0x80000000)

# -------------------------------
# READ 2× (BRAM Latenz!)
# -------------------------------
_ = read_reg(ADDR_DATA)
val = read_reg(ADDR_DATA)

print(f"TAP {tap}  ADDR {idx} = {val}")

mm.close()
os.close(fd)

