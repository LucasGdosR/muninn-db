package main

import "core:math/rand" // Only used for tests
import "core:mem"
import "core:sys/unix"
import "core:fmt"

// _____________________________________________________________________________
// PUBLIC API
// _____________________________________________________________________________

// Overwrites existing keys. Flips flags for deleted keys.
// Inserts new keys and rebalances.
put :: proc(k: Blob, val: Blob) {
    _put(k, val)
}

// Adds deleted flag to existing keys.
// Inserts node for non-existent keys and rebalances.
remove :: proc(k: Blob) {
    i := _put(k)
    avl.nodes[i].deleted = true
}

// If the state returned is NOT_EXISTS, the query must go to disk.
get :: proc(k: Blob) -> ([]byte, NodeState) {
    v : []byte
    i, state := _get(k)
    if state == NodeState.EXISTS
    {
        v = fetch_blob(avl.nodes[i].val)
    }
    return v, state
}

// _____________________________________________________________________________
// HELPER FUNCTIONS
// _____________________________________________________________________________

@(private="file")
fetch_blob :: proc(blob: Blob) -> []byte {
    return mem.ptr_to_bytes(mem.ptr_offset(kv.base, blob.offset), int(blob.size))
}

// If the key exists (even if deleted), returns its index in curr.
// Else, returns the index of the last valid node visited (for insertion).
@(private="file")
_get :: proc(k: Blob) -> (u16, NodeState) {
    curr, parent: u16
    k := fetch_blob(k)

    for curr = avl.root; curr != 0;
    {
        cmp := mem.compare(k, fetch_blob(avl.nodes[curr].key))
        if cmp == 0
        {
            break
        }
        parent = curr
        curr = cmp < 0 ? avl.nodes[curr].left : avl.nodes[curr].right
    }
    state := curr == 0                       ? NodeState.NOT_EXISTS :
                     avl.nodes[curr].deleted ? NodeState.DELETED :
                                               NodeState.EXISTS
    curr = curr == 0 ? parent : curr
    return curr, state
}

// Overwrites existing keys and returns their index.
// Inserts new keys (and balances) and returns their index.
@(private="file")
_put ::proc(k: Blob, val: Blob = {}) -> (ret: u16) {
    // Empty tree: add the root
    if avl.size == 0
    {
        avl.size, avl.root = 1, 1
        {
            root := &avl.nodes[1]
            root.key = k
            root.val =  val
            root.height = 1
        }
        ret = 1
    }
    else
    // Non-empty tree
    {
        i, state := _get(k)
        // Overwrite
        if state != NodeState.NOT_EXISTS
        {
            avl.nodes[i].deleted = false
            avl.nodes[i].val = val
            ret = i
        }
        else
        // Insert
        {
            avl.size += 1
            ret = avl.size
            {
                n := &avl.nodes[avl.size]
                n.key = k
                n.val = val
                n.height = 1
                n.parent = i
            }
            if mem.compare(fetch_blob(k), fetch_blob(avl.nodes[i].key)) < 0
            {
                avl.nodes[i].left = avl.size
            }
            else
            {
                avl.nodes[i].right = avl.size
            }
            balance_tree(i)
        }
    }
    return
}

@(private="file")
balance_tree :: proc(node: u16) {
    i := node
    for i != 0
    {
        n := &avl.nodes[i]
        old_height := n.height
        update_height(n)
        balance_factor := node_balance_factor(n)
        if balance_factor == 2
        {
            if node_balance_factor(&avl.nodes[n.left]) < 0
            {
                left := &avl.nodes[n.left]       
                rotate_left(left, &avl.nodes[left.right], n.left, left.right)
            }
            rotate_right(n, &avl.nodes[n.left], i, n.left)
        }
        else if balance_factor == -2
        {
            if node_balance_factor(&avl.nodes[n.right]) > 0
            {
                right := &avl.nodes[n.right]       
                rotate_right(right, &avl.nodes[right.left], n.right, right.left)
            }
            rotate_left(n, &avl.nodes[n.right], i, n.right)
        }
        if n.height == old_height
        {
            break
        }
        i = n.parent
    }
}

// 1)
// Parent's right becomes child's left.
// Child's left's parent becomes parent.
// 2)
// Child's left becomes parent.
// Parent's parent becomes child.
// 3)
// Child's parent becomes parent's parent.
// Some child of parent's parent becomes child.
@(private="file")
rotate_left :: proc(#no_alias parent, child: ^Node, pi, ci: u16) {
    ppi := parent.parent
    gp := &avl.nodes[ppi]
    // 1)
    parent.right = child.left
    if child.left != 0
    {
        avl.nodes[child.left].parent = pi
    }
    // 2)
    child.left = pi
    parent.parent = ci
    // 3)
    child.parent = ppi
    if gp.left == pi 
    {
        gp.left = ci
    }
    else if gp.right == pi
    {
        gp.right = ci
    }
    else
    {
        avl.root = ci
    }
    update_height(parent)
    update_height(child)
}

// 1)
// Parent's left becomes child's right.
// Child's right's parent becomes parent.
// 2)
// Child's right becomes parent.
// Parent's parent becomes child.
// 3)
// Child's parent becomes parent's parent.
// Some child of parent's parent becomes child.
@(private="file")
rotate_right :: proc(#no_alias parent, child: ^Node, pi, ci: u16) {
    ppi := parent.parent
    gp := &avl.nodes[ppi]
    // 1)
    parent.left = child.right
    if child.right != 0
    {
        avl.nodes[child.right].parent = pi
    }
    // 2)
    child.right = pi
    parent.parent = ci
    // 3)
    child.parent = ppi
    if gp.left == pi 
    {
        gp.left = ci
    }
    else if gp.right == pi
    {
        gp.right = ci
    }
    else
    {
        avl.root = ci
    }
    update_height(parent)
    update_height(child)
}

@(private="file")
node_balance_factor :: proc(n: ^Node) -> i8 {
    return avl.nodes[n.left].height - avl.nodes[n.right].height
}

@(private="file")
update_height :: proc(n: ^Node) {
    n.height = 1 + max(avl.nodes[n.left].height, avl.nodes[n.right].height)
}

// _____________________________________________________________________________
// TESTS
// _____________________________________________________________________________
AVL_TEST :: #config(AVL_TEST, false)
when AVL_TEST {
    @(private="file")
    test :: proc() {
        assert(avl.size == count_nodes(avl.root))
        assert(ordering_is_valid(avl.root))
        assert(height_property_is_valid(avl.root))
    }
    
    @(private="file")
    count_nodes :: proc(node: u16) -> u16 {
        return node == 0 ? 0 : 1 + count_nodes(avl.nodes[node].left) + count_nodes(avl.nodes[node].right)
    }
    
    @(private="file")
    height_property_is_valid :: proc(node: u16) -> bool {
        return node == 0 ? true :
        abs(node_balance_factor(&avl.nodes[node])) > 1 ? false :
        height_property_is_valid(avl.nodes[node].left) && height_property_is_valid(avl.nodes[node].right)
    }

    @(private="file")
    ordering_is_valid :: proc(node: u16) -> bool {
        keys := make([dynamic][]u8, 0, avl.size)
        in_order_traversal(&keys, avl.root)
        for k, i in keys[:len(keys)-1]
        {
            if mem.compare(k, keys[i + 1]) > 0
            {
                return false
            }
        }
        return true
    }

    @(private="file")
    in_order_traversal :: proc(keys: ^[dynamic][]u8, node: u16) {
        if node != 0
        {
            in_order_traversal(keys, avl.nodes[node].left)
            append(keys, fetch_blob(avl.nodes[node].key))
            in_order_traversal(keys, avl.nodes[node].right)
        }
    }

    main :: proc() {
        ptr := unix.sys_mmap(nil, KV_RESERVE_SIZE, unix.PROT_NONE, unix.MAP_PRIVATE | unix.MAP_ANONYMOUS, -1, 0)
        assert(ptr > 0)
        kv.base = cast(^u8)uintptr(ptr)

        for i in 0..<20000
        {
            k := rand.int_max(0xFFFF)
            k_seq := &k
            v := i
            v_seq := &v
            
            if kv.committed < kv.size + 16
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
            
            key, val : Blob
            key.offset = kv.size
            key.size = 8
            mem.copy(mem.ptr_offset(
                kv.base,
                kv.size
                ),
                k_seq, 8
            )
            kv.size += 8
                      
            val.offset = kv.size
            val.size = 8
            mem.copy(mem.ptr_offset(
                kv.base,
                kv.size
                ),
                v_seq, 8
            )
            kv.size += 8

            put(key, val)
        }
        test()
    }
}