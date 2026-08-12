# SD card probe test for Phase 3
# Tests SD card init, FAT32 mount, and directory listing

import drivers.sd.sd_spi as sd
import drivers.fs.fat32 as fat

print("=== SD Card Probe ===")

# Test SD init
t = sd.sd_init()
if t == 0:
    print("SD init: FAIL (no card or init error)")
    print("=== FAIL ===")
    quit()
else:
    sd_type_names = {1: "SDv1", 2: "SDHC", 0: "None"}
    print(f"SD init: type {t} ({sd_type_names.get(t, 'unknown')})")

# Test FAT mount
if not fat.fat_mount():
    print("FAT mount: FAIL")
    print("=== FAIL ===")
    quit()
print("FAT mount: OK")

# Test directory listing
entries = fat.fat_ls()
print(f"FAT ls: {len(entries)} entries")

# Print entry details
for e in entries[:10]:
    kind = "D" if (e["attr"] & 0x10) else "F"
    print(f"  {kind} {e['name']} ({e['size']} bytes)")

# Test file read
print("\n=== Probe complete ===")
