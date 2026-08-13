# sagefs/inode.sage - metadata model.
#
# Every VFS entry is described by an inode dict:
#
#   {"name": display name, "kind": "file" | "dir",
#    "size": byte count, "cluster": FAT32 first cluster (0 for non-FAT)}
#
# FAT32 directory entries ({name, attr, cluster, size}) map into this
# model via inode_from_entry().

var INODE_FILE = "file"
var INODE_DIR = "dir"

var FAT_ATTR_DIR = 0x10

# inode_file(name, size, cluster): a file inode.
proc inode_file(name, size, cluster):
    return {"name": name, "kind": INODE_FILE, "size": size,
            "cluster": cluster}

# inode_dir(name): a directory inode.
proc inode_dir(name):
    return {"name": name, "kind": INODE_DIR, "size": 0, "cluster": 0}

# inode_is_dir(inode): true for directories.
proc inode_is_dir(node):
    return node["kind"] == INODE_DIR

# inode_from_entry(entry): map a FAT32 directory entry into an inode.
proc inode_from_entry(entry):
    if (entry["attr"] & FAT_ATTR_DIR) != 0:
        return inode_dir(entry["name"])
    return inode_file(entry["name"], entry["size"], entry["cluster"])