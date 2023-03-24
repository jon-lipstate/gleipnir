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
	insert_text(rope, 5, "Are")
	insert_text(rope, 8, "Easy")
	insert_text(rope, 12, "Peasy")
	print_in_order(rope.head, "End-Inserts")

	insert_text(rope, 8, "_NOT_")
	// print_rope(rope) // (Ropes)(Are)(_NOT_)(Easy)(Peasy)
	delete_text(rope, 2, 12)
	print_in_order(rope.head, "Deleted 2-12")

	insert_text(rope, 2, "pes")
	insert_text(rope, 5, "Are")
	insert_text(rope, 7, "E")
	insert_text(rope, 8, "_NOT_")
	print_in_order(rope.head, "Re-inserted")

	delete_text(rope, 13, 1)
	insert_text(rope, 13, "e")

	print_in_order(rope.head) //

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
// Assumes the cursor starts *AFTER* the supplied leaf
// todo: is that ergonomic?
// return nil on end of rope??
find_next :: proc(leaf: ^Node, cursor: Position) -> (next: ^Node, current: Position) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	current = cursor
	for {
		next = ascend_to_next_branch(leaf)
		next = find_min(next)
		if next == nil {break}
		next_leaf := next.kind.(Leaf)
		if current - len(next_leaf) < 0 {break}
		current -= len(next_leaf)
	}

	return next, current
}
is_left :: #force_inline proc(node: ^Node) -> bool {
	return as_branch(node.parent).left == node
}
has_right :: #force_inline proc(branch: ^Node) -> bool {
	return as_branch(branch).right != nil
}
set_left_child :: #force_inline proc(parent: ^Node, child: ^Node) {
	as_branch(parent).left = child
	child.parent = parent
}
set_right_child :: #force_inline proc(parent: ^Node, child: ^Node) {
	as_branch(parent).right = child
	child.parent = parent
}
// Travels upwards until a right child can be found. Returns that right child.
ascend_to_next_branch :: proc(node: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	assert(node != nil) // todo: count weights too??
	parent := node.parent
	if parent == nil {return nil}
	//
	current := node
	for parent != nil {
		if is_left(current) && has_right(parent) {
			return as_branch(parent).right
		} else {
			current = parent
			parent = current.parent
		}
	}
	return current
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
	if left == nil && left == nil {return nil} else if left == nil {return right} else if right == nil {return left}
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
// Requires: node.parent.parent, free(node.parent)
// replace_parent :: proc(node: ^Node) {
// 	assert(node.parent != nil)
// 	assert(node.parent.parent != nil)
// 	grandparent := node.parent.parent
// 	parent := node.parent
// 	if is_left(parent) {
// 		set_left_child(grandparent, node)
// 	} else {
// 		set_right_child(grandparent, node)
// 	}
// 	free(parent)
// }
// can return nil if nop
split :: proc(rope: ^Rope, cursor: Position, allocator := context.allocator) -> (right_tree: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if cursor == 0 || rope == nil {return nil}
	node, current := find(rope, cursor)
	if current == -1 {return nil} 	// beyond the string (nop)
	//
	leaf := node.kind.(Leaf) // Expect Leaf
	fmt.printf("Split at (%s)[%v] :: ", leaf, current)
	print_in_order(rope.head)
	if node.parent != nil {assert(node != node.parent && node != node.parent.parent, "Make sure no circular ref")}
	right_tree = new(Rope, allocator)
	left_tree := &Rope{}
	split_the_leaf := current > 0 && current < len(leaf)
	//
	// Protect for nil parent:
	if node.parent == nil && split_the_leaf {
		left, right := split_leaf(node, current, allocator)
		append_node(right_tree, right, allocator)
		rope.head = left
		left.parent = nil
		free(left_tree)
		return right_tree
	} else if node.parent == nil {
		free(right_tree)
		free(left_tree)
		return nil // this case is move the left tree into the right tree. not sure i want to support
	}
	was_left := is_left(node)
	// Case: Splitting a leaf in the middle
	if split_the_leaf {
		parent := node.parent
		left, right := split_leaf(node, current)
		append_node(right_tree, right)

		if was_left {
			grandparent := parent.parent
			if grandparent != nil {
				set_left_child(grandparent, left)
				free(parent)
				node = as_branch(grandparent).left
			} else {
				set_left_child(parent, left)
				node = as_branch(parent).left
			}
		} else {
			set_right_child(parent, left)
			node = as_branch(parent).right
		}
		node = node.parent
		if node.parent != nil {assert(node != node.parent && node != node.parent.parent, "Make sure no circular ref")}
	} else if current == 0 {
		node = node.parent
		n_is_left := is_left(node)
		parent := node.parent
		append_node(right_tree, node)
		if n_is_left {
			as_branch(parent).left = nil
		} else {
			as_branch(parent).right = nil
		}
		if node.parent != nil {was_left = is_left(node)}
		if node.parent != nil {assert(node != node.parent && node != node.parent.parent, "Make sure no circular ref")}
	} else {
		// this is off the edge of the tree (guard above should prevent)
		invalid_code_path(#procedure)
		return nil
	}
	if node.parent != nil {assert(node != node.parent && node != node.parent.parent, "Make sure no circular ref")}

	for node.parent != nil {
		if was_left {
			append_node(right_tree, as_branch(node).right, allocator)
			as_branch(node).right = nil
		} else {
			print_in_order(node, "ELSEEE ")
		}
		// if nbr, nok := node.kind.(Branch); nok && node.parent != nil {
		// 	if nbr.right == nil {
		// 		set_left_child(node.parent, nbr.left)
		// 	}
		// }
		update_weight(node)

		// if node.parent == nil {break}
		was_left = is_left(node)
		node = node.parent
	}
	// rope.head = left_tree.head
	// print_in_order(left_tree.head, "SLRope")
	print_in_order(rope.head, "SRope")
	print_in_order(right_tree.head, "SRight")
	assert(rope.head.parent == nil, "rope.head.parent must be nil")
	assert(right_tree.head.parent == nil, "rope.head.parent must be nil")

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
append_node :: proc(rope: ^Rope, right: ^Node, allocator := context.allocator) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	// case: rope is empty:
	if rope.head == nil {
		right.parent = nil
		rope.head = concat(right, nil, allocator)
		assert(rope.head.parent == nil, "rope.head.parent must be nil")
		return
	}
	if right == nil {return}
	left := find_max(rope.head)
	// left is the root element:
	if left.parent == nil {
		rope.head = concat(left, right, allocator)
		rope.head.parent = nil
		assert(rope.head.parent == nil, "rope.head.parent must be nil")
		return
	} else {
		// stash parent-state:
		parent := left.parent
		is_left_child := is_left(left)
		appended := concat(left, right, allocator)
		if is_left_child {set_left_child(parent, appended)} else {set_right_child(parent, appended)}
	}
	assert(rope.head.parent == nil, "rope.head.parent must be nil")
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
		} else {
			update_weight(node^)
		}
	}
}
insert_text :: proc(rope: ^Rope, cursor: Position, text: string, allocator := context.allocator) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	fmt.println(">>>Insert", cursor, text)
	// case - Empty Rope:
	if rope.head == nil {
		leaf := make_leaf(text, allocator)
		node := concat(leaf, nil, allocator)
		rope.head = node
		return
		//case - Root Element:
	}

	right_tree := split(rope, cursor)
	append_node(rope, make_leaf(text, allocator))
	if right_tree != nil {
		print_in_order(rope.head, "Joining Right Tree:")
		rope.head = concat(rope.head, right_tree.head, allocator)
		// fmt.print("IRope :: ")
		// print_in_order(rope.head)
		// fmt.print("IRight :: ")
		// print_in_order(right_tree.head)
	}
	fmt.printf("Post-Insert Rebalance :: ")
	print_in_order(rope.head)
	assert(rope.head.parent == nil, "rope.head.parent must be nil")
	rebalance(&rope.head)
	assert(rope.head.parent == nil, "rope.head.parent must be nil")
}

import "core:mem"
delete_text :: proc(rope: ^Rope, cursor: Position, count: int, allocator := context.allocator) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	fmt.println(">>>Delete", cursor, count)

	if count <= 0 {return}
	print_in_order(rope.head, "BEFORE-DELETE")
	middle_tree := split(rope, cursor, allocator)
	print_in_order(middle_tree.head, "middle_tree")
	right_tree := split(middle_tree, count, allocator)
	print_in_order(rope.head, "rope")

	if right_tree != nil {
		print_in_order(right_tree.head, "right_tree")
		rope.head = concat(rope.head, right_tree.head, allocator)
		free(right_tree)
	}
	delete_rope(middle_tree)
	rebalance(&rope.head)
	assert(rope.head.parent == nil, "rope.head.parent must be nil")

}
delete_rope :: proc(rope: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	delete_node :: proc(node: ^Node) {
		TRACE(&spall_ctx, &spall_buffer, #procedure)
		if node == nil {return}
		switch n in node.kind {
		case (Branch):
			delete_node(n.left)
			delete_node(n.right)
		case (Leaf):
		// delete(n) // TODO: fix backing storage somewhere...
		}
		free(node)
	}
}
