package gleipnir
import "core:fmt"
import "core:strings"
//
import _spall "core:prof/spall"
spall :: _spall
spall_ctx := spall.Context{}
spall_buffer := spall.Buffer{}
TRACE_MODE :: false
when TRACE_MODE {
	TRACE :: #force_inline proc(ctx: ^spall.Context, buf: ^spall.Buffer, loc: string) {
		spall.SCOPED_EVENT(ctx, buf, loc)
	}
} else {
	TRACE :: #force_inline proc(ctx: ^spall.Context, buf: ^spall.Buffer, loc: string) {}
}

//
main :: proc() {
	when TRACE_MODE {
		// Profiling Setup:
		spall_ctx = spall.context_create("gleipnir.spall")
		buffer_backing := make([]u8, 1 << 18) // 256kb profiling buffer
		spall_buffer = spall.buffer_create(buffer_backing)
		defer delete(buffer_backing)
		defer spall.context_destroy(&spall_ctx)
		defer spall.buffer_destroy(&spall_ctx, &spall_buffer)
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	}
	//
	rope := &Rope{}
	insert_text(rope, 0, "Ropes")
	insert_text(rope, 5, "Are")
	insert_text(rope, 8, "Easy")
	insert_text(rope, 12, "Peasy")
	insert_text(rope, 8, "_NOT_")

	print_rope(rope)
}
//

Rope :: struct {
	head: ^Node,
	// todo: trace block, other memory stuff?
}
Trace :: struct {
	self:    ^Node,
	is_left: bool,
}
Position :: int
Branch :: struct {
	weight: int, // aggregate weights of left subtree
	left:   ^Node,
	right:  ^Node,
}
Leaf :: string
Node :: union {
	Branch,
	Leaf,
}
get_height :: proc(node: ^Node) -> int {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	b := (&node.(Branch))
	b.weight = get_weight(b.left, true)
}
// O(log-n)
// updating :: true: recurse left subtree, false: use node's weight
get_weight :: proc(node: ^Node, updating: bool = false) -> int {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	context.allocator = allocator
	node := new(Node)
	node^ = Branch {
		left   = left,
		right  = right,
		weight = get_weight(left), // <-- O(log-n)
	}
	return node
}
//
// finds the leaf containing p and its parent branch (expects in-bounds)
//O(log-n)
find_node :: proc(root: ^Node, cursor: Position) -> (parent: ^Node, leaf: string, current: Position) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	node := root
	parent = nil
	stop := false
	current = cursor
	for {
		next: ^Node
		switch n in node {
		case (Branch):
			if current >= n.weight && n.right != nil {
				next = n.right
				current -= n.weight
			} else if n.left != nil {
				next = n.left
			} else {
				invalid_code_path(#procedure)
			}
		case (Leaf):
			if current >= len(n) {
				panic(fmt.tprintf("Index [%v] exceeds length of Leaf: [%s], len: [%v]", current, string(n), len(n)))
			}
			// if current >= len(n) {current -= len(n)}
			stop = true
			leaf = n
		}
		if stop {break}
		parent = node
		node = next
	}
	return parent, leaf, current
}
trace_to :: proc(root: ^Node, cursor: Position) -> (trace: [dynamic]Trace, current: Position) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	trace = make([dynamic]Trace)
	node := root
	stop := false
	current = cursor
	next_is_left := false
	is_left := false
	for {
		is_left = next_is_left
		next: ^Node
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
			if current >= len(n) {current = -1}
			stop = true
		}
		append(&trace, Trace{node, is_left})
		if stop {break}
		node = next
	}
	return trace, current
}
split :: proc(root: ^Node, cursor: Position) -> (did_split: bool, right_tree: ^Node) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	if cursor == 0 {return}
	parent, leaf, current := find_node(root, cursor)
	(&parent.(Branch)).left = split_leaf(parent.(Branch).left, current)

	return true, nil
}
// Replaces a leaf with a branch, and with two leaves
// Frees original leaf
split_leaf :: proc(leaf_node: ^Node, local: Position) -> ^Node {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	// fmt.println("ROL", n)

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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	// fmt.println("ROR", n)
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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	if rope.head == nil {
		leaf := new(Node)
		leaf^ = text
		node := concat(leaf, nil)
		rope.head = node
		return
	}
	trace, current := trace_to(rope.head, cursor)
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
