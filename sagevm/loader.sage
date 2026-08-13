# sagevm/loader.sage - Phase 8 loader: guest bytecode on a SageFS volume,
# executed by the vendored VM core (composed; see tools/compose_sagevm.py).
#
# Mirrors the on-board flow: a precompiled .sgvm payload sits on storage
# (here the RAM-disk FAT32 volume; on the board the SD card). The loader
# reads its bytes through the VFS and hands the byte array to the VM via
# SGVMRunner's bytes override (pocket_load_override seam), so no host
# path is involved - the VM never opens the payload file itself.

import sagefs.block as block
import sagefs.cache as cache
import sagefs.mkfs as mkfs
import sagefs.vfs as vfs
import sagefs.memfs as memfs
import sagefs.fatfs as fatfs
import io

proc loader_main():
    # RAM-disk volume (the SD card on the board)
    block.block_ram_init(64)
    var disk = block.block_ram_device()
    var cached = cache.cache_wrap(disk, 8)
    if not mkfs.mkfs_fat32(cached):
        print "loader: mkfs FAILED"
        return
    if not vfs.vfs_mount("/", fatfs.ffs_ops(), cached):
        print "loader: mount / FAILED"
        return
    if not vfs.vfs_mkdir("/apps"):
        print "loader: mkdir /apps FAILED"
        return

    # The payload arrives precompiled (host: `sagevm compile`; board: SD
    # image written by tools/mkimg.py or mkfs tooling).
    var payload = io.readbytes("build/sgvm_demo.sgvm")
    if payload == nil:
        print "loader: host payload missing (sagevm compile first)"
        return
    if not vfs.vfs_write_bytes("/apps/HELLO.SGV", payload):
        print "loader: payload write FAILED"
        return

    # Boot the guest: read the payload from storage, hand the bytes to
    # the VM core directly.
    var bytes = vfs.vfs_read_bytes("/apps/HELLO.SGV")
    if bytes == nil:
        print "loader: payload read FAILED"
        return
    print "loader: payload " + str(len(bytes)) + " bytes from /apps/HELLO.SGV"

    let runner = SGVMRunner()
    runner.pocket_bytes = bytes
    if not runner.run_file("/apps/HELLO.SGV", false):
        print "loader: VM run FAILED"
        return
    print "loader done"

loader_main()