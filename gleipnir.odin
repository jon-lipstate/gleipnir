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
	insert_text(rope, 8, "_NOT_")
	// print_rope(rope) // (Ropes)(Are)(_NOT_)(Easy)(Peasy)

	delete_text(rope, 2, 12)
	insert_text(rope, 2, "pes")
	insert_text(rope, 5, "Are")
	insert_text(rope, 7, "E")
	insert_text(rope, 8, "_NOT_")
	delete_text(rope, 13, 1)
	insert_text(rope, 13, "e")

	// print_rope(rope) // 
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
		Branch,
		Leaf,
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
	return node, current
}
// Assumes the cursor starts *AFTER* the supplied leaf
// todo: is that ergonomic?
// return nil on end of rope??
find_next :: proc(leaf: ^Node, cursor: Position, allocator := context.allocator) -> (next: ^Node, current: Position) {
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
	// TODO: YOU ARE HERE
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
	//
	if left == nil && left == nil {return nil} else if left == nil {return right} else if right == nil {return left}
	//
	left_br, left_is_br := &left.kind.(Branch)
	right_br, right_is_br := &right.kind.(Branch)
	//
	if left_is_br && left_br.right == nil {
		left.parent = nil
		left_br.right = right
		right.parent = left
		return left
	} else if right_is_br && right_br.right == nil {
		right.parent = nil
		right_br.right = right_br.left
		right_br.left = left
		left.parent = right
		return right
	} else {
		node := new(Node, allocator)
		node^ = {
			parent = nil,
			kind = Branch{left = left, right = right, weight = get_weight(left)},
		}
		left.parent = node
		right.parent = node
		return node
	}
}
// can return nil if nop
split :: proc(rope: ^Rope, cursor: Position, allocator := context.allocator) -> (right_tree: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if cursor == 0 || rope == nil {return nil}
	node, current := find(rope, cursor)
	if current == -1 {return nil} 	// beyond the string (nop)
	//
	leaf := node.kind.(Leaf) // Expect Leaf - todo: verify for edge cases
	parent := node.parent
	right_tree = new(Rope, allocator)
	split_the_leaf := current > 0 && current < len(leaf)
	//
	// Protect for nil parent:
	if parent == nil && split_the_leaf {
		left, right := split_leaf(node, current)
		append_node(right_tree, right)
		rope.head = left
		left.parent = nil
		return right_tree
	} else if parent == nil {
		return nil // this case is move the left tree into the right tree. not sure i want to support
	}
	was_left := is_left(node)
	//
	// Case: Splitting a leaf in the middle
	if split_the_leaf {
		left, right := split_leaf(node, current)
		node = parent // node was freed, set to parent
		append_node(right_tree, right)
		current = -1 // Current set to invalid state as guard
		if was_left {
			set_left_child(parent, left)
			append_node(right_tree, as_branch(parent).right)
			as_branch(parent).right = nil
		} else {
			set_right_child(parent, left)
		}
		update_weight(parent)
	} else if current == 0 {
		// The entire subtree should move
		if was_left {
			grand_parent := parent.parent
			assert(grand_parent != nil) // todo: replace with guard ..?
			parent_is_left := is_left(parent)
			append_node(right_tree, parent)
			// update_weight(parent)
			if parent_is_left {
				as_branch(grand_parent).left = as_branch(grand_parent).right
			}
			as_branch(grand_parent).right = nil
			update_weight(grand_parent)
			// the right leaf should move:
		} else {
			append_node(right_tree, node)
			as_branch(parent).right = nil
			update_weight(parent)
		}
	} else {
		// this is off the edge of the tree (guard above should prevent)
		invalid_code_path(#procedure)
		return nil
	}

	for {
		node = node.parent
		if was_left {
			append_node(right_tree, as_branch(node).right)
			as_branch(node).right = nil
			update_weight(node)
		}
		if node.parent == nil {break}
		was_left = is_left(node)
	}
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
append_node :: proc(rope: ^Rope, node: ^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	// case: rope is empty:
	if rope.head == nil {
		rope.head = concat(node, nil)
		return
	}
	if node == nil {return}
	// todo: replace with for loop, no need for a trace here.
	trace, current := trace_to(rope, I32MAX)
	defer delete(trace)
	assert(current == -1) // otherwise we're not at end of rope
	trace_leaf := pop(&trace)
	if trace_leaf.is_slot {
		trace_leaf.slot^ = node
		return
	}
	// case: rope has one leaf only:
	if len(trace) == 0 {
		rope.head = concat(trace_leaf.self, node)
		return
	}
	trace_parent := pop(&trace)
	parent_branch := as_branch(trace_parent.self)
	if trace_leaf.is_left {
		parent_branch.right = node
	} else {
		parent_branch.right = concat(parent_branch.right, node)
	}

	if root, rok := (&rope.head.(Branch)); rok {
		if root.right == nil {
			tmp := root.left
			free(root)
			rope.head = tmp
		}
	}
	// TODO: if node.kind == branch,update its weights?
	rebalance(&rope.head)
}
// Replaces a leaf with a branch, and with two leaves.
// calls `free(old_leaf)`
split_leaf :: proc(leaf_node: ^Node, local: Position) -> (left: ^Node, right: ^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)

	leaf := leaf_node.kind.(Leaf)
	left = make_leaf(strings.clone(leaf[:local]))
	right = make_leaf(strings.clone(leaf[local:]))
	// delete(leaf) // TODO: where to alloc strings??
	free(leaf_node)
	return left, right
}

LeafIter :: struct {
	trace: [dynamic]Trace,
}
into_iter :: proc(trace: [dynamic]Trace) -> LeafIter {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	return LeafIter{trace = trace} // clone it??
}
next_leaf :: proc(it: ^LeafIter) -> (node: ^Node, ok: bool) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	// fmt.println(it.trace)
	start_trace := pop(&it.trace)
	previous := start_trace.self // remove the leaf
	going_up := false
	for {
		current := it.trace[len(it.trace) - 1].self
		switch n in current {
		case (Branch):
			// Move from the left child to the right child
			if n.left == previous {
				//

				append(&it.trace, Trace{self = n.right, is_left = false}) // move into the right
			} else if n.right == previous {
				// Go up the tree until we can move from the left child to the right child
				going_up = true
				for going_up {
					previous = current
					current = it.trace[len(it.trace) - 1].self
					// Move from the left child to the right child
					if current.(Branch).left == previous {
						going_up = false
						branch_right := (&current.(Branch)).right
						//
						append(&it.trace, Trace{self = branch_right, is_left = false}) // move into the right
					} else {
						// Keep going up the tree
						pop(&it.trace)
						if len(it.trace) == 0 {return nil, false} 	// No more leaves
					}
				}
			} else {
				// Go down the left-most unvisited nodes
				for {
					switch k in current {
					case (Branch):
						assert(k.left != nil, "Left Nil?!")
						append(&it.trace, Trace{self = k.left, is_left = true})
						current = k.left
					case (Leaf):
						return current, true // Found the next leaf
					}
				}
			}
		case (Leaf):
			return current, true // Found the next leaf
		}
		previous = current
	}
	return nil, false
}
// Expects n & n.right to be Branches
rotate_left :: proc(n: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	b := (&n.(Branch))
	pivot := b.right
	p := (&pivot.(Branch))
	b.right = p.left
	p.left = n
	update_weight(n)
	update_weight(pivot)
	return pivot
}
// Expects n & n.left to be Branches
rotate_right :: proc(n: ^Node) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	b := (&n.(Branch))
	pivot := b.left
	p := (&pivot.(Branch))
	b.left = p.right
	p.right = n
	update_weight(n)
	update_weight(pivot)
	return pivot
}
rebalance :: proc(node: ^^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return}
	if np, ok := &node^.(Branch); ok {
		balance := get_height(np.left) - get_height(np.right)
		if balance > 1 {
			np_left := &np.left.(Branch)
			if get_height(np_left.left) < get_height(np_left.right) {
				np.left = rotate_left(np.left)
			}
			node^ = rotate_right(node^)
		} else if balance < -1 {
			np_right := &np.right.(Branch)
			if get_height(np_right.right) < get_height(np_right.left) {
				np.right = rotate_right(np.right)
			}
			node^ = rotate_left(node^)
		} else {
			update_weight(node^)
		}
	}
}
insert_text :: proc(rope: ^Rope, cursor: Position, text: string) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if rope.head == nil {
		leaf := make_leaf(text)
		node := concat(leaf, nil)
		rope.head = node
		return
	}
	right_tree := split(rope, cursor)

	append_node(rope, make_leaf(text))
	if right_tree != nil {
		rope.head = concat(rope.head, right_tree.head)
	}
	rebalance(&rope.head)
}

import "core:mem"
delete_text :: proc(rope: ^Rope, cursor: Position, count: int) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if count <= 0 {return}
	middle_tree := split(rope, cursor)
	right_tree := split(middle_tree, count)
	rope.head = concat(rope.head, right_tree.head)
	free(right_tree)
	delete_rope(middle_tree)
	rebalance(&rope.head)
	// print_in_order(rope.head)
	// fmt.println()
}
delete_rope :: proc(rope: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
}

cleanup_tree :: proc(tree: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if tree == nil || tree.head == nil {return}
	fmt.print("Cleanup Before:: ")
	print_in_order(tree.head)
	fmt.println()

	stack := make([dynamic]^Node)
	append(&stack, tree.head)

	for len(stack) > 0 {
		current := pop(&stack)
		switch node in current {
		case (Branch):
			// Left subtree has data:
			if node.left != nil && node.right == nil {
				// edge case for tree's head (concat with one item on the head)
				if tree.head == current {
					tree.head = node.left
					fmt.println("fix left")
				} else {
					// Replace the current branch node with its left child
					next := stack[len(stack) - 1]
					switch nxt in next {
					case (Branch):
						panic("not impl")
					case (Leaf):
					//nop
					}
				}
				append(&stack, node.left) // Continue with the left child
			} else if node.left == nil && node.right != nil {
				// Replace the current branch node with its right child
				if tree.head == current {
					tree.head = node.right
					fmt.println("fix right")

				} else {
					parent := stack[len(stack) - 1]
					panic("not impl")
				}
				append(&stack, node.right) // Continue with the right child
			} else {
				// Push left and right children onto the stack
				if node.left != nil {
					append(&stack, node.left)
				}
				if node.right != nil {
					append(&stack, node.right)
				}
			}
		case (Leaf):
		// Do nothing for leaf nodes
		}
	}
	fmt.print("Cleanup After:: ")
	print_in_order(tree.head)
	fmt.println()
}
