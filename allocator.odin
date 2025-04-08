package main

import "core:mem"
import "core:sys/unix"

allocator :: proc(a: ^KV_Allocator) -> mem.Allocator {
    ptr := unix.sys_mmap(nil, KV_RESERVE_SIZE, unix.PROT_NONE, unix.MAP_PRIVATE | unix.MAP_ANONYMOUS, -1, 0)
    assert(ptr > 0)
    a.base = cast(^u8)uintptr(ptr)
    return {
        procedure = allocator_proc,
        data = a,
    }
}

allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int,
    loc := #caller_location) -> (bytes: []byte, err: mem.Allocator_Error) {
        kv := (^KV_Allocator)(allocator_data)

        if mode == .Alloc
        {
            if kv.committed < kv.size + u32(size)
            {
                assert(0 == unix.sys_mprotect(
                        mem.ptr_offset(
                            kv.base,
                            kv.committed
                        ),
                        KV_COMMIT_SIZE,
                        unix.PROT_READ | unix.PROT_WRITE
                ))
                kv.committed += KV_COMMIT_SIZE
            }
            bytes = mem.ptr_to_bytes(mem.ptr_offset(kv.base, kv.size), size)
            kv.size += u32(size)
            err = .None
            return
        }
        else
        {
            assert(false, "KV_Allocator only allocs for now.")
        }

        return nil, mem.Allocator_Error.None
    }