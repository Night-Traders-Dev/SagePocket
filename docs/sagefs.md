# SageFS Specification

> **Version:** 0.1.0 · **Component:** sagefs/ · **Related:** [architecture.md](architecture.md)

SageFS is the persistent storage layer of SagePocket. It starts as a VFS with
a FAT32 backend (matching the board's official TF-card example), and later
gains a native journalled filesystem with wear-aware allocation, checksums,
and crash recovery, while retaining FAT32 import/export compatibility.

---

## 1. Architecture

```text
Application
    ↓
SageFS API
    ↓
VFS
    ↓
Filesystem driver
    ↓
Block device
    ↓
SD SPI
    ↓
microSD
```

Source layout:

```text
sagefs/
├── vfs.sage       Virtual filesystem (mounts, namespace, dispatch)
├── fat32.sage     FAT32 driver
├── inode.sage     Inode/metadata model
├── block.sage     Block device abstraction
├── cache.sage     Block caching
├── journal.sage   Journaling (native SageFS)
└── sagefs.sage    Native SageFS implementation
```

## 2. Bootstrap: FAT32

The initial system uses FAT32 for compatibility:

- SageOS mounts the FAT32 card at `/sd`
- The SageFS VFS then provides `/` over it
- Read support first (`ls` must work from the physical SD card), then write

```text
/sd            raw FAT32 mount point
/              VFS root across filesystems/mounts
```

## 3. Native SageFS

Later, the native filesystem:

```text
native metadata
allocation tables
directories
file extents
journaling
crash recovery
integrity checking
caching
wear-aware allocation
checksums
```

### 3.1 Evolution Path

```text
FAT32 compatibility
       ↓
SageFS metadata
       ↓
SageFS native format
```

`mkfs.sage` (host) and `sdfmt` (device) implement this progression.
**Never destroy user data without explicit confirmation.**

## 4. Directory Layout

```text
/
├── system/
│   ├── kernel
│   ├── boot
│   ├── config/
│   ├── drivers/
│   └── libraries/
│
├── bin/
│
├── apps/
│
├── lib/
│
├── home/
│   └── user/
│
├── data/
│
├── games/
│
├── roms/
│
├── tmp/
│
├── logs/
│
├── cache/
│
└── recovery/
```

## 5. SageFS API

Implemented as the VFS-facing API:

```text
fs.open()
fs.close()
fs.read()
fs.write()
fs.seek()
fs.stat()
fs.mkdir()
fs.remove()
fs.rename()
fs.list()
fs.mount()
fs.unmount()
fs.sync()
```

## 6. Filesystem CLI

```text
ls
cd
pwd
cat
cp
mv
rm
mkdir
touch
df
mount
umount
```

## 7. Block Devices

The filesystem must not know the storage is an SD card. Storage is exposed
through a block device interface:

```text
block_device.read_sector()
block_device.write_sector()
```

The SD driver implements this interface (see [drivers.md](drivers.md) §4).

## 8. Caching

The block cache limits SRAM usage (budgeted at 32 KB in the resource plan):

```text
read-through cache
write-back with explicit fs.sync() / cache flush
dirty-block accounting
```

## 9. Journaling and Crash Recovery

The native SageFS journals metadata updates. On unclean shutdown:

```text
mount → journal replay → consistent state
```

Fault-injection scenarios that must recover (see [security.md](security.md)):

```text
corrupt filesystem metadata
remove SD during read
remove SD during write
power loss during write
```

## 10. Logging

```text
/logs/sagefs.log
```

## 11. Formatting Tools

Host:

```text
tools/mkfs.sage        create FAT32 / SageFS images
sagepack-image         full system image (boot + kernel + filesystem)
```

Device:

```text
sdfmt                  format SD card on-device
```

## 12. Definitions of Done

### FAT32 milestone (Phase 3 / SagePocket 0.3)

- [ ] SD card detected and initialized over SPI
- [ ] Block reads/writes work
- [ ] FAT32 read: files and directories enumerable (`sage> ls`)
- [ ] FAT32 write: files creatable and editable

### Native milestone (Phase 16 / SagePocket 1.0)

- [ ] SageFS survives power-loss testing
- [ ] SageFS survives filesystem corruption tests
- [ ] FAT32 import/export compatibility retained

Related docs: [architecture.md](architecture.md), [hardware.md](hardware.md),
[docs/boot.md](boot.md), [drivers.md](drivers.md), [security.md](security.md).