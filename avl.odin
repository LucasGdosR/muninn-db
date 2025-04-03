package main

import "core:math/rand" // Only used for tests

CRITICAL_MASS :: 0xFFFF

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

@(private="file")
Node :: struct {
    key: int, // string? cstring?
    val: u16, // string?
    parent: u16,
    left: u16,
    right: u16,
    height: i8,
    deleted: bool,
}

// Public API.
// Overwrites existing keys. Flips flags for deleted keys.
// Inserts new keys and rebalances.
put :: proc(t: ^AVL, k: int, val: u16) {
    _put(t, k, val)
}

// Public API.
// Adds deleted flag to existing keys.
// Inserts node for non-existent keys and rebalances.
remove :: proc(t: ^AVL, k: int) {
    i := _put(t, k)
    t.nodes[i].deleted = true
}

// Public API.
// If the state returned is NOT_EXISTS, the query must go to disk.
get :: proc(t: ^AVL, k: int) -> (u16, NodeState) {
    v : u16
    i, state := _get(t, k)
    if state == NodeState.EXISTS
    {
        v = t.nodes[i].val
    }
    return v, state
}

// Helper function.
// If the key exists (even if deleted), returns its index in curr.
// Else, returns the index of the last valid node visited (for insertion).
@(private="file")
_get :: proc(t: ^AVL, k: int) -> (u16, NodeState) {
    curr, parent: u16
    for curr = t.root; curr != 0 && t.nodes[curr].key != k; {
        parent = curr
        curr = k < t.nodes[curr].key ? t.nodes[curr].left : t.nodes[curr].right
    }
    state := curr == 0                     ? NodeState.NOT_EXISTS :
                     t.nodes[curr].deleted ? NodeState.DELETED :
                                             NodeState.EXISTS
    curr = curr == 0 ? parent : curr
    return curr, state
}

// Helper function.
// Overwrites existing keys and returns their index.
// Inserts new keys (and balances) and returns their index.
@(private="file")
_put ::proc(t: ^AVL, k: int, val: u16 = 0) -> (ret: u16) {
    // Empty tree: add the root
    if t.size == 0
    {
        t.size, t.root = 1, 1
        {
            root := &t.nodes[1]
            root.key = k
            root.val =  val
            root.height = 1
        }
        ret = 1
    }
    else
    // Non-empty tree
    {
        i, state := _get(t, k)
        // Overwrite
        if state != NodeState.NOT_EXISTS
        {
            t.nodes[i].deleted = false
            t.nodes[i].val = val
            ret = i
        }
        else
        // Insert
        {
            t.size += 1
            ret = t.size
            {
                n := &t.nodes[t.size]
                n.key = k
                n.val = val
                n.height = 1
                n.parent = i
            }
            if k < t.nodes[i].key
            {
                t.nodes[i].left = t.size
            }
            else
            {
                t.nodes[i].right = t.size
            }
            balance_tree(t, i)
        }
    }
    return
}

// Helper function.
@(private="file")
balance_tree :: proc(t: ^AVL, node: u16) {
    i := node
    for i != 0 {
        n := &t.nodes[i]
        old_height := n.height
        update_height(t, n)
        balance_factor := node_balance_factor(t, n)
        if balance_factor == 2
        {
            if node_balance_factor(t, &t.nodes[n.left]) < 0
            {
                left := &t.nodes[n.left]       
                rotate_left(t, left, &t.nodes[left.right], n.left, left.right)
            }
            rotate_right(t, n, &t.nodes[n.left], i, n.left)
        }
        else if balance_factor == -2
        {
            if node_balance_factor(t, &t.nodes[n.right]) > 0
            {
                right := &t.nodes[n.right]       
                rotate_right(t, right, &t.nodes[right.left], n.right, right.left)
            }
            rotate_left(t, n, &t.nodes[n.right], i, n.right)
        }
        if n.height == old_height
        {
            break
        }
        i = n.parent
    }
}

// Helper function.
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
rotate_left :: proc(#no_alias t: ^AVL, #no_alias parent, child: ^Node, pi, ci: u16) {
    ppi := parent.parent
    gp := &t.nodes[ppi]
    // 1)
    parent.right = child.left
    if child.left != 0
    {
        t.nodes[child.left].parent = pi
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
        t.root = ci
    }
    update_height(t, parent)
    update_height(t, child)
}

// Helper function.
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
rotate_right :: proc(#no_alias t: ^AVL, #no_alias parent, child: ^Node, pi, ci: u16) {
    ppi := parent.parent
    gp := &t.nodes[ppi]
    // 1)
    parent.left = child.right
    if child.right != 0
    {
        t.nodes[child.right].parent = pi
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
        t.root = ci
    }
    update_height(t, parent)
    update_height(t, child)
}

// Helper function.
@(private="file")
node_balance_factor :: proc(#no_alias t: ^AVL, n: ^Node) -> i8 {
    return t.nodes[n.left].height - t.nodes[n.right].height
}

// Helper function.
@(private="file")
update_height :: proc(#no_alias t: ^AVL, n: ^Node) {
    n.height = 1 + max(t.nodes[n.left].height, t.nodes[n.right].height)
}

TEST :: #config(TEST, false)
when TEST {
    @(private="file")
    test :: proc(t: ^AVL) {
        assert(t.size == count_nodes(t, t.root))
        assert(ordering_is_valid(t, t.root))
        assert(height_property_is_valid(t, t.root))
    }
    
    @(private="file")
    count_nodes :: proc(t: ^AVL, node: u16) -> u16 {
        return node == 0 ? 0 : 1 + count_nodes(t, t.nodes[node].left) + count_nodes(t, t.nodes[node].right)
    }
    
    @(private="file")
    height_property_is_valid :: proc(t: ^AVL, node: u16) -> bool {
        return node == 0 ? true :
        abs(node_balance_factor(t, &t.nodes[node])) > 1 ? false :
        height_property_is_valid(t, t.nodes[node].left) && height_property_is_valid(t, t.nodes[node].right)
    }

    @(private="file")
    ordering_is_valid :: proc(t: ^AVL, node: u16) -> bool {
        keys := make([dynamic]int, 0, t.size)
        in_order_traversal(t, &keys, t.root)
        for k, i in keys[:len(keys)-1]
        {
            if k > keys[i + 1]
            {
                return false
            }
        }
        return true
    }

    @(private="file")
    in_order_traversal :: proc(t: ^AVL, keys: ^[dynamic]int, node: u16) {
        if node != 0
        {
            in_order_traversal(t, keys, t.nodes[node].left)
            append(keys, t.nodes[node].key)
            in_order_traversal(t, keys, t.nodes[node].right)
        }
    }

    main :: proc() {
        avl := new(AVL)
        for i in 0..<20000
        {
            put(avl, rand.int_max(0xFFFF), u16(i))
        }
        test(avl)
    }
}