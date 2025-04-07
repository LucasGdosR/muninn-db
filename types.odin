package main

import "core:mem"

CRITICAL_MASS :: 0xFFFF
KV_RESERVE_SIZE :: 4 * mem.Gigabyte
KV_COMMIT_SIZE :: 2 * mem.Megabyte

NodeState :: enum {
    NOT_EXISTS,
    EXISTS,
    DELETED,
}

AVL :: struct {
    nodes: [CRITICAL_MASS]Node,
    root: u16,
    size: u16,
}

Blob :: struct {
    offset, size: u32,
}

Node :: struct {
    key: Blob,
    val: Blob,
    parent: u16,
    left: u16,
    right: u16,
    height: i8,
    deleted: bool,
}

KV_Allocator :: struct {
    base: ^u8,
    size: u32,
    committed: u32,
}