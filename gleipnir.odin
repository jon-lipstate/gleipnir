package gleipnir
import "core:fmt"
import "core:math/bits"
I32MAX :: bits.I32_MAX
import "core:strings"
import "core:slice"
//
import _spall "core:prof/spall"
spall :: _spall
spall_ctx := spall.Context{}
spall_buffer := spall.Buffer{}
TRACE_MODE :: true
TRACE :: spall.SCOPED_EVENT

//
main :: proc() {
	// Profiling Setup:
	spall_ctx = spall.context_create("gleipnir.spall")
	buffer_backing := make([]u8, 1 << 16) // 64kb profiling buffer
	spall_buffer = spall.buffer_create(buffer_backing)
	defer delete(buffer_backing)
	defer spall.context_destroy(&spall_ctx)
	defer spall.buffer_destroy(&spall_ctx, &spall_buffer)
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	//
	rope := &Rope{}
	insert_text(rope, 0, "Ropes")
	assert_parentage(rope)
	insert_text(rope, 5, "Are")
	insert_text(rope, 8, "Easy")
	insert_text(rope, 12, "Peasy")
	// print_in_order(rope.head, "End-Inserts")
	insert_text(rope, 8, "_NOT_")
	assert_parentage(rope)

	// print_rope(rope) // (Ropes)(Are)(_NOT_)(Easy)(Peasy)
	delete_text(rope, 2, 12)
	// print_in_order(rope.head, "Deleted 2-12")
	assert_parentage(rope)
	// print_rope(rope) // (Ropes)(Are)(_NOT_)(Easy)(Peasy)

	insert_text(rope, 2, "pes")
	insert_text(rope, 5, "Are")
	// print_rope(rope) // (Ropes)(Are)(_NOT_)(Easy)(Peasy)

	insert_text(rope, 8, "E")
	insert_text(rope, 8, "_NOT_")
	// print_in_order(rope.head, "Re-inserted")

	delete_text(rope, 13, 1)
	insert_text(rope, 13, "E")

	// print_in_order(rope.head, "Final Rope") //
	// fmt.println(to_string(rope))
}
//
Rope :: struct {
	head: ^Node,
}

Position :: int
Branch :: struct {
	weight: int, // left subtree
	left:   ^Node,
	right:  ^Node,
}
Leaf :: string
Node :: struct {
	parent: ^Node,
	kind:   union {
		Leaf,
		Branch,
	},
}
find :: proc(rope: ^Rope, cursor: Position) -> (leaf: ^Node, current: Position) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	node := rope.head
	assert(rope.head != nil)
	stop := false
	current = cursor
	next_is_left := false
	is_left := false
	for {
		is_left = next_is_left
		next: ^Node
		length := 0
		switch n in node.kind {
		case (Branch):
			if current >= n.weight && n.right != nil {
				next = n.right
				current -= n.weight
				next_is_left = false
			} else if n.left != nil {
				next = n.left
				next_is_left = true
			} else {
				// Right == Nil TODO: look at this more closely
				invalid_code_path(#procedure)
			}
		case (Leaf):
			length = len(n)
			if current >= length {current = -1}
			stop = true
		}
		if stop {break}
		node = next
	}
	assert(rope.head.parent == nil, "rope.head.parent must be nil")
	return node, current
}

is_left :: #force_inline proc(node: ^Node) -> bool {
	return as_branch(node.parent).left == node
}
has_right :: #force_inline proc(branch: ^Node) -> bool {
	return as_branch(branch).right != nil
}
is_branch :: #force_inline proc(node: ^Node) -> bool {
	_, ok := node.kind.(Branch)
	return ok
}
set_left_child :: #force_inline proc(parent: ^Node, child: ^Node) {
	as_branch(parent).left = child
	child.parent = parent
}
set_right_child :: #force_inline proc(parent: ^Node, child: ^Node) {
	as_branch(parent).right = child
	child.parent = parent
}
find_next_leaf :: proc(node: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	assert(node != nil)

	parent := node.parent
	if parent == nil {return nil}

	current := node
	was_left := is_left(node)
	for parent != nil {
		// fmt.print(was_left)
		// print_in_order(current, " FOR ::")
		if was_left && has_right(parent) {
			// Find the leftmost leaf in the right subtree using find_min
			current = find_min(as_branch(parent).right)
			return current
		} else {
			was_left = is_left(current)
			current = parent
			parent = current.parent
		}
	}

	return nil
}

// Continues down left branches until a leaf is reached
find_min :: proc(node: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return nil}
	current := node
	for current != nil {
		switch c in current.kind {
		case (Branch):
			assert(c.left != nil)
			current = c.left
		case (Leaf):
			return current
		}
	}
	unreachable(#procedure)
	return nil
}
find_max :: proc(node: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return nil}
	current := node
	for current != nil {
		switch c in current.kind {
		case (Branch):
			if c.right != nil {current = c.right} else {
				assert(c.left != nil, "Left Was Nil")
				current = c.left
			}
		case (Leaf):
			return current
		}
	}
	unreachable(#procedure)
	return nil
}
//
get_height :: proc(node: ^Node) -> int {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return 0}
	value := 1
	switch n in node.kind {
	case (Branch):
		left := get_height(n.left)
		right := get_height(n.right)
		value += max(left, right)
	case (Leaf):
		value = 0
	}
	return value
}
//
update_weight :: proc(node: ^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	b := (&node.kind.(Branch))
	b.weight = get_weight(b.left, true)
}
// O(log-n)
// updating :: true: recurse left subtree, false: use node's weight
get_weight :: proc(node: ^Node, updating: bool = false) -> int {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	w := 0
	if node == nil {return w}
	switch n in node.kind {
	case (Branch):
		if updating {w += get_weight(n.left)} else {w += n.weight}
		w += get_weight(n.right)
	case (Leaf):
		w += len(n)
	}
	return w
}
// O(log-n) [get_weight]
// Returned node has parent = nil
concat :: proc(left: ^Node, right: ^Node, allocator := context.allocator) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	// One side is nil:
	if left == nil && right == nil {return nil} else if left == nil {
		right.parent = nil
		return right
	} else if right == nil {
		left.parent = nil
		return left
	}
	// fmt.print(">> Concat: (R) ")
	// print_node(right)
	// print_in_order(left, "Concat (L)")
	// one child is nil:
	left_br, left_is_br := &left.kind.(Branch)
	right_br, right_is_br := &right.kind.(Branch)
	//
	if left_is_br && left_br.right == nil {
		set_right_child(left, right)
		return left
	} else if right_is_br && right_br.right == nil {
		right_br.right = right_br.left
		set_left_child(right, left)
		update_weight(right)
		return right
	} else {
		// concat:
		node := new(Node, allocator)
		node^ = {
			parent = nil,
			kind = Branch{weight = get_weight(left)},
		}
		set_left_child(node, left)
		set_right_child(node, right)
		return node
	}
}
// set parent's child pointer to nil
nilify_child :: #force_inline proc(parent: ^Node, do_left: bool) {
	if do_left {
		as_branch(parent).left = nil
	} else {
		as_branch(parent).right = nil
	}
}
// can return nil if nop
split :: proc(rope: ^Rope, cursor: Position, allocator := context.allocator) -> (right_tree: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if cursor == 0 || rope == nil || rope.head == nil {return nil}
	//
	// print_in_order(rope.head, fmt.tprintf(">> Split (%v)", cursor))
	right_tree = new(Rope, allocator)
	//
	node := rope.head
	stop := false
	current := cursor
	next_is_left := false
	node_is_left := false
	at_root := true
	// TODO: use a depth int counter so dont need so many parent nil checks
	for {
		// print_in_order(node, fmt.tprintf("FOR [%v]::", current))
		// print_in_order(rope.head, "(Rope.head)")
		// print_in_order(right_tree.head, "(right_tree.head)")
		node_is_left = next_is_left
		next: ^Node
		at_root = node.parent == nil

		//move subtree to right tree:
		if current == 0 {
			parent := node.parent
			assert(!at_root, "Split doesnt allow cursor=0, unreachable")
			grandparent := parent.parent
			// print_in_order(node, "C=0 (Node)")

			if is_left(node) {
				// print_in_order(parent, "C=0,IsLeft (parent)")
				// parent is not root:
				if grandparent != nil {
					p_is_left := is_left(parent)
					prepend_node(right_tree, parent)
					nilify_child(grandparent, p_is_left)
					update_weight(grandparent)
				} else {
					//parent is root
					rope.head = nil
					free(parent)
					fmt.println("MOVED ENTIRE ROPE???")
					not_implemented("Unverified to be correct")
				}
				update_weight(parent)
			} else {
				// print_in_order(parent, "C=0,!IsLeft (parent)")
				// Node is RIGHT child:
				nilify_child(parent, false)
				prepend_node(right_tree, node)
				update_weight(parent)

				if grandparent != nil {
					// fmt.println("GP NOT NIL", is_left(parent))
					// print_rope(rope)
					// print_rope(right_tree)
					// parent is not root:

					if is_left(parent) {
						set_left_child(grandparent, as_branch(parent).left)
					} else {
						set_right_child(grandparent, as_branch(parent).left)
					}
					free(parent)
					update_weight(grandparent)
				} else {
					// fmt.println("GP NIL")
					//parent is root:
					rope.head = as_branch(parent).left
					rope.head.parent = nil
					free(parent)
				}
			}
			break
		}
		switch n in node.kind {
		case (Branch):
			if current >= n.weight && n.right != nil {
				next = n.right
				current -= n.weight
				next_is_left = false
				// fmt.println("Go Right", current)
			} else if n.left != nil {
				next = n.left
				next_is_left = true
				// fmt.println("Go Left", current)
				// print_in_order(node, "NODE, RM RT")
				tmp := node
				prepend_node(right_tree, n.right)
				as_branch(node).right = nil
				if !at_root {
					// fmt.println("Replace self with left child")
					if node_is_left {
						set_left_child(node.parent, n.left)
					} else {
						set_right_child(node.parent, n.left)
					}
					update_weight(node.parent)

				} else {
					rope.head = n.left
					rope.head.parent = nil
					if is_branch(rope.head) {
						update_weight(rope.head)
					}
				}
				node = tmp.parent
				free(tmp)
				// print_in_order(node, "NEXT-ITER")
			} else {
				// Right == Nil TODO: look at this more closely
				invalid_code_path(#procedure)
			}

		case (Leaf):
			length := len(n)
			parent := node.parent
			if current < length {
				// if !node_is_left {
				// 	print_in_order(node.parent, "SPLIT_LEAF.parent")
				// }
				left, right := split_leaf(node, current)
				// fmt.println("> split leaf", node_is_left, left.kind.(Leaf))
				prepend_node(right_tree, right)
				if parent == nil {
					rope.head = left
					rope.head.parent = nil
				} else {
					if node_is_left {
						grandparent := parent.parent
						as_branch(parent).right = nil
						set_left_child(parent, left)
						update_weight(parent)
					} else {
						set_right_child(parent, left)
					}

				}

			} else if current >= length {current = -1}
			stop = true
		}
		if stop {break}
		node = next
	}
	// fmt.println("Current", current)
	// print_in_order(rope.head, "<< rope")
	// print_in_order(right_tree.head, "<< right_tree")
	if right_tree.head == nil {
		free(right_tree)
		right_tree = nil
	}
	assert_weights(rope)
	assert_weights(right_tree)
	return right_tree
}

as_branch :: #force_inline proc(node: ^Node) -> ^Branch {
	assert(node != nil)
	return &node.kind.(Branch)
}
as_leaf :: #force_inline proc(node: ^Node) -> ^Leaf {
	assert(node != nil)
	return &node.kind.(Leaf)
}
make_leaf :: proc(str: string, allocator := context.allocator) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	leaf := new(Node, allocator)
	leaf^.kind = str
	return leaf
}
prepend_node :: proc(rope: ^Rope, prependand: ^Node, allocator := context.allocator) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if prependand == nil {return}
	// fmt.print(">> PrePendNode (L) ")
	// print_node(prependand)
	// print_in_order(rope.head, "PrePendNode (head)")
	// case: rope is empty:
	if rope.head == nil {
		prependand.parent = nil
		rope.head = concat(prependand, nil, allocator)
		when ODIN_DEBUG {
			assert_parentage(rope)
			assert_weights(rope)
		}
		return
	}
	left := find_min(rope.head)
	// left is the root element:
	if left.parent == nil {
		rope.head = concat(prependand, left, allocator)
		rope.head.parent = nil
		when ODIN_DEBUG {
			assert_parentage(rope)
			assert_weights(rope)
		}
		return
	} else {
		// stash parent-state:
		parent := left.parent
		is_left_child := is_left(left)
		appended := concat(prependand, left, allocator)
		if is_left_child {
			set_left_child(parent, appended)
		} else {
			set_right_child(parent, appended)
		}
	}
	node_to_update := left.parent
	for node_to_update != nil {
		update_weight(node_to_update)
		node_to_update = node_to_update.parent
	}
	when ODIN_DEBUG {
		assert_parentage(rope)
		assert_weights(rope)
	}
}
append_node :: proc(rope: ^Rope, right: ^Node, allocator := context.allocator) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if right == nil {return}
	// fmt.print(">> AppendNode (R) ")
	// print_node(right)
	// print_in_order(rope.head, "AppendNode (head)")
	// case: rope is empty:
	if rope.head == nil {
		right.parent = nil
		rope.head = concat(right, nil, allocator)
		when ODIN_DEBUG {
			assert_parentage(rope)
			assert_weights(rope)
		}
		return
	}
	//
	left := find_max(rope.head)
	// left is the root element:
	if left.parent == nil {
		rope.head = concat(left, right, allocator)
		rope.head.parent = nil
		when ODIN_DEBUG {
			assert_parentage(rope)
			assert_weights(rope)
		}
		return
	} else {
		// stash parent-state:
		parent := left.parent
		is_left_child := is_left(left)
		appended := concat(left, right, allocator)
		if is_left_child {set_left_child(parent, appended)} else {set_right_child(parent, appended)}
	}
	node_to_update := left.parent
	for node_to_update != nil {
		update_weight(node_to_update)
		node_to_update = node_to_update.parent
	}
	when ODIN_DEBUG {
		assert_parentage(rope)
		assert_weights(rope)
	}
}
// Replaces a leaf with a branch, and with two leaves.
// calls `free(old_leaf)`
split_leaf :: proc(leaf_node: ^Node, local: Position, allocator := context.allocator) -> (left: ^Node, right: ^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	leaf := leaf_node.kind.(Leaf)
	left = make_leaf(strings.clone(leaf[:local], allocator))
	right = make_leaf(strings.clone(leaf[local:], allocator))
	// TODO: where to delete/make strings??
	free(leaf_node)
	return left, right
}

// Expects n & n.right to be Branches
rotate_left :: proc(node: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	//
	node_branch := (&node.kind.(Branch))
	pivot := node_branch.right
	pivot_branch := (&pivot.kind.(Branch))
	// early exit (dont have 3 children):
	if pivot_branch.right == nil {
		set_right_child(node, pivot_branch.left)
		free(pivot)
		return node
	}
	if node.parent != nil {
		if is_left(node) {
			set_left_child(node.parent, pivot)
		} else {
			set_right_child(node.parent, pivot)
		}
	} else {
		pivot.parent = nil
	}
	set_right_child(node, pivot_branch.left)
	set_left_child(pivot, node)
	//
	update_weight(node)
	update_weight(pivot)
	return pivot
}
// Expects n & n.left to be Branches
rotate_right :: proc(node: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	//
	node_branch := (&node.kind.(Branch))
	pivot := node_branch.left
	pivot_branch := (&pivot.kind.(Branch))
	// early exit (dont have 3 children):
	if pivot_branch.right == nil {
		set_left_child(node, pivot_branch.left)
		free(pivot)
		return node
	}
	if node.parent != nil {
		if is_left(node) {
			set_left_child(node.parent, pivot)
		} else {
			set_right_child(node.parent, pivot)
		}
	} else {
		pivot.parent = nil
	}
	set_left_child(node, pivot_branch.right)
	set_right_child(pivot, node)
	//
	update_weight(node)
	update_weight(pivot)
	return pivot
}
rebalance :: proc(node: ^^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return}
	if np, ok := &node^.kind.(Branch); ok {
		balance := get_height(np.left) - get_height(np.right)
		if balance > 1 {
			np_left := &np.left.kind.(Branch)
			if get_height(np_left.left) < get_height(np_left.right) {
				np.left = rotate_left(np.left)
			}
			node^ = rotate_right(node^)
		} else if balance < -1 {
			np_right := &np.right.kind.(Branch)
			if get_height(np_right.right) < get_height(np_right.left) {
				np.right = rotate_right(np.right)
			}
			node^ = rotate_left(node^)
		}
	}
}
insert_text :: proc(rope: ^Rope, cursor: Position, text: string, allocator := context.allocator) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	// fmt.println("\n>>> Insert", cursor, text)
	// case - Empty Rope:
	if rope.head == nil {
		leaf := make_leaf(text, allocator)
		node := concat(leaf, nil, allocator)
		rope.head = node
		when ODIN_DEBUG {
			assert_parentage(rope)
			assert_weights(rope)
		}
		return
		//case - Root Element:
	}

	right_tree := split(rope, cursor)
	// print_in_order(rope.head, "ROPE_after_split")
	// if right_tree != nil {print_in_order(right_tree.head, "RIGHT_after_split")}

	assert_parentage(right_tree)
	assert_parentage(rope)
	append_node(rope, make_leaf(text, allocator))
	if right_tree != nil {
		// print_in_order(rope.head, "Joining Right Tree:")
		rope.head = concat(rope.head, right_tree.head, allocator)
		free(right_tree)
	}
	// fmt.printf("Post-Insert Rebalance :: ")
	// print_in_order(rope.head)
	rebalance(&rope.head)
	assert(rope.head.parent == nil, "rope.head.parent must be nil")
	// print_in_order(rope.head, "<<< Insert Done")
	when ODIN_DEBUG {
		assert_parentage(rope)
		assert_weights(rope)
	}
}

import "core:mem"
delete_text :: proc(rope: ^Rope, cursor: Position, count: int, allocator := context.allocator) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	// fmt.println("\n>>> Delete", cursor, count)

	if count <= 0 {return}
	middle_tree := split(rope, cursor, allocator)
	// print_in_order(middle_tree.head, "middle_tree")
	right_tree := split(middle_tree, count, allocator)
	// print_in_order(rope.head, "rope")

	if right_tree != nil {
		// print_in_order(right_tree.head, "right_tree")
		rope.head = concat(rope.head, right_tree.head, allocator)
		free(right_tree)
	}
	delete_rope(middle_tree)
	rebalance(&rope.head)
	assert(rope.head.parent == nil, "rope.head.parent must be nil")
	// print_in_order(rope.head, "<<< Delete Done")

}
delete_rope :: proc(rope: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	delete_nodes(rope.head)
	free(rope)
}
delete_nodes :: proc(node: ^Node, leaves_too := false) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return}
	switch n in node.kind {
	case (Branch):
		delete_nodes(n.left)
		delete_nodes(n.right)
		free(node)
	case (Leaf):
		if leaves_too {
			// delete(n) // TODO: fix backing storage somewhere...
			free(node)
		}
	}
}
