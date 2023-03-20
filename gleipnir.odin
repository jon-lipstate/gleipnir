package gleipnir
import "core:fmt"
import "core:strings"
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
	delete_text(rope, 2, 12)

	print_rope(rope) // (Ropes)(Are)(_NOT_)(Easy)(Peasy)
}
//

Rope :: struct {
	head: ^Node,
}
Trace :: struct {
	self:    ^Node,
	is_left: bool,
}
Position :: int
Branch :: struct {
	weight: int, // left subtree
	left:   ^Node,
	right:  ^Node,
}
Leaf :: string
Node :: union {
	Branch,
	Leaf,
}
get_height :: proc(node: ^Node) -> int {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return 0}
	value := 1
	switch n in node {
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
	b := (&node.(Branch))
	b.weight = get_weight(b.left, true)
}
// O(log-n)
// updating :: true: recurse left subtree, false: use node's weight
get_weight :: proc(node: ^Node, updating: bool = false) -> int {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	w := 0
	if node == nil {return w}
	switch n in node {
	case (Branch):
		if updating {w += get_weight(n.left)} else {w += n.weight}
		w += get_weight(n.right)
	case (Leaf):
		w += len(n)
	}
	return w
}
// O(log-n) [get_weight]
concat :: proc(left: ^Node, right: ^Node, allocator := context.allocator) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	context.allocator = allocator
	node := new(Node)
	node^ = Branch {
		left   = left,
		right  = right,
		weight = get_weight(left),
	}
	return node
}
trace_to :: proc(rope: ^Rope, cursor: Position) -> (trace: [dynamic]Trace, current: Position) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	trace = make([dynamic]Trace)
	node := rope.head
	stop := false
	current = cursor
	next_is_left := false
	is_left := false
	for {
		is_left = next_is_left
		next: ^Node
		length := 0
		switch n in node {
		case (Branch):
			if current >= n.weight && n.right != nil {
				next = n.right
				current -= n.weight
			} else if n.left != nil {
				next = n.left
				next_is_left = true
			} else {
				invalid_code_path(#procedure)
			}
		case (Leaf):
			length = len(n)
			if current >= length {current = -1}
			stop = true
		}
		append(&trace, Trace{node, is_left})
		if stop {break}
		node = next
	}
	return trace, current
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

				append(&it.trace, Trace{n.right, false}) // move into the right
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
						append(&it.trace, Trace{branch_right, false}) // move into the right
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
						append(&it.trace, Trace{k.left, true})
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

split :: proc(root: ^Node, cursor: Position) -> (did_split: bool, right_tree: ^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if cursor == 0 {return}
	invalid_code_path("NOT IMPL")
	return false, nil
}
// Replaces a leaf with a branch, and with two leaves.
// calls `free(old_leaf)`
split_leaf :: proc(leaf_node: ^Node, local: Position) -> ^Node {
	TRACE(&spall_ctx, &spall_buffer, #procedure)

	leaf := leaf_node.(Leaf)
	left := new(Node)
	left^ = strings.clone(leaf[:local])
	right := new(Node)
	right^ = strings.clone(leaf[local:])
	b := concat(left, right)
	// delete(leaf) // TODO: where to alloc strings??
	free(leaf_node)
	return b
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
	np := &node^.(Branch)
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
insert_text :: proc(rope: ^Rope, cursor: Position, text: string) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if rope.head == nil {
		leaf := new(Node)
		leaf^ = text
		node := concat(leaf, nil)
		rope.head = node
		return
	}
	trace, current := trace_to(rope, cursor)
	defer delete(trace)
	trace_leaf := trace[len(trace) - 1]
	parent := trace[len(trace) - 2]
	parent_branch := &parent.self.(Branch)
	new_leaf := new(Node)
	new_leaf^ = text
	switch current {
	// at end of rope
	case -1:
		if trace_leaf.is_left {
			parent_branch.right = new_leaf
		} else {
			parent_branch.right = concat(parent_branch.right, new_leaf)
		}
	// before current element
	case 0:
		parent_branch.left = concat(new_leaf, parent_branch.left)
	// mid-element
	case:
		split_leaf := split_leaf(trace_leaf.self, current)
		(&split_leaf.(Branch)).right = concat(new_leaf, (&split_leaf.(Branch)).right)
		if trace_leaf.is_left {
			parent_branch.left = split_leaf
		} else {
			parent_branch.right = split_leaf
		}
	}
	rebalance(&rope.head)
}

DeleteMe :: struct {
	parent:      ^Node,
	leaf:        ^Node,
	local_start: int,
	local_end:   int,
}

import "core:mem"
delete_text :: proc(rope: ^Rope, cursor: Position, count: int) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if count <= 0 {return}
	trace, current := trace_to(rope, cursor)
	defer delete(trace)
	delmes := make([dynamic]DeleteMe)
	defer delete(delmes)

	end := cursor + count
	remaining := count

	it := into_iter(trace)
	current_node := it.trace[len(it.trace) - 1].self
	ok := true
	for remaining > 0 && ok {
		#partial switch n in current_node {
		case (Leaf):
			local_start := current // zero after first iter
			local_end := min(end - cursor, len(n))
			remaining -= local_end - local_start
			parent := it.trace[len(it.trace) - 2].self // Leaf must be under a branch .. cannot be out of bounds
			append(&delmes, DeleteMe{parent, current_node, local_start, local_end})
		}
		current_node, ok = next_leaf(&it)
		if !ok {break}
		current = 0 // need actual value for first iter of loop and then not after
	}
	fmt.println("TODO: math seems off in the delme calcs, taking too much")
	for d in delmes {
		fmt.println(d) // TODO: math seems off in the delme calcs, taking too much
		parent_node := d.parent
		parent_branch := &parent_node.(Branch)
		leaf_node := d.leaf
		leaf_str := leaf_node.(Leaf)
		local_start := d.local_start
		local_end := d.local_end
		if local_start == 0 && local_end == len(leaf_str) {
			// Whole leaf is deleted, remove the leaf from the tree
			if parent_branch.left == leaf_node {
				free(parent_branch.left)
				parent_branch.left = nil //note: this makes the tree invalid atm
			} else {
				free(parent_branch.right)
				parent_branch.right = nil
			}
		} else if local_start == 0 {
			// Left part is deleted, update the leaf content
			leaf_node^ = strings.clone(leaf_str[local_end:])
		} else if local_end == len(leaf_str) {
			// Right part is deleted, update the leaf content
			leaf_node^ = strings.clone(leaf_str[:local_start])
		} else {
			// Middle part is deleted, split the leaf into two
			left := new(Node)
			left^ = strings.clone(leaf_str[:local_start])
			right := new(Node)
			right^ = strings.clone(leaf_str[local_end:])
			new_branch := concat(left, right)
			if parent_branch.left == leaf_node {
				parent_branch.left = new_branch
			} else {
				parent_branch.right = new_branch
			}
		}
	}

	// Rebalance the tree
	// for i := len(trace) - 1; i > 0; i -= 1 {
	// 	node := trace[i].self
	// 	#partial switch n in node {
	// 	case (Branch):
	// 		rebalance(&node)
	// 	}
	// }
}
