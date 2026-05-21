#!/usr/bin/env python3
import mmap, os, struct

COEFF_FILE = "/root/coeffs_int.txt"

BASE = 0x40600000
SIZE = 0x10000

ADDR_TAP  = 0x00
ADDR_IDX  = 0x04
ADDR_DATA = 0x08
ADDR_WE   = 0x0C

# ----------------------------- mem -----------------------------

fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
mm = mmap.mmap(fd, SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE, offset=>

def write_reg(offset, value):
    mm.seek(offset)
    mm.write(struct.pack("<i", int(value)))

# ----------------------------- Lade Datei -----------------------------

# Sortiere nach TAP und ADDR
entries = {}
with open(COEFF_FILE) as f:
    for line in f:
        parts = line.split()
        tap   = int(parts[1])
        addr  = int(parts[3])
        val   = int(parts[5])
        entries.setdefault(tap, {})[addr] = val

print("Starte Schreiben...")

# ----------------------------- Schreiben -----------------------------

for tap in sorted(entries.keys()):

    write_reg(ADDR_TAP, tap)

    for addr in sorted(entries[tap].keys()):
        write_reg(ADDR_IDX, addr)
        write_reg(ADDR_DATA, entries[tap][addr])
        write_reg(ADDR_WE, 1)
        write_reg(ADDR_WE, 0)

mm.close()
os.close(fd)

print("Fertig.")

