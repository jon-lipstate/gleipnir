package rope
import "core:fmt"
import "core:slice"

main :: proc() {
	l1 := make_leaf(transmute([]u8)string("Ropes")) // 0-4
	r1 := make_leaf(transmute([]u8)string("Are")) //5-7
	l2 := make_leaf(transmute([]u8)string("Easy")) //8-11
	r2 := make_leaf(transmute([]u8)string("Peasy")) //12-16
	// bc := concat(l1, r1)
	// c := index_char(bc, 8)
	// fmt.println(c)
	// assert(c == 'A')
	// b1 := make_branch(l1, r1)
	// b2 := make_branch(l2, r2)
	// b := make_branch(b1, b2)
	// parent, rem := find_parent(b, -6)
	// pn := new(Node)
	// pn^ = parent^
	// bstr := to_string(pn)
	b3 := make_branch(r1, l2)

	insert(b3, 2, "_not_")

	// fmt.println(len(to_string(b)))
	// s := split(b, 4)
	// sstr := to_string(s)
	// fmt.println("SPLIT RIGHT:", sstr)
	// rstr := to_string(b)
	// fmt.println("SPLIT LEFT:", rstr)
	// fmt.println(string(parent.left.(^Leaf)), rem)
}
to_string :: proc(node: ^Node, allocator := context.allocator) -> string {
	context.allocator = allocator
	weight := get_weight(node)
	str := make([]u8, weight)
	to_str :: proc(node: ^Node, dest: []u8) {
		switch n in node {
		case (Leaf):
			copy_slice(dest, n.data)
		case (Branch):
			if n.left != nil {
				to_str(n.left, dest)
			} else {
				fmt.println("<nil>")
			}
			if n.right != nil {
				to_str(n.right, dest[n.weight:])
			}
		}
	}
	to_str(node, str)
	return string(str)
}
invalid_code_path :: proc(p: string) {
	if true {panic(fmt.tprintf("Invalid Code Path - %v", p))}
}
Branch :: struct {
	left:   ^Node,
	right:  ^Node,
	parent: ^Node,
	weight: int, // aggregate weights of left subtree
}
Leaf :: struct {
	data:   []u8,
	parent: ^Node,
}
Node :: union {
	Branch,
	Leaf,
}
// Finds a character at index `i` and returns it (Avg: O(log-n),Worst:O(n))
// TODO: Return a Rune??
index_char :: proc(node: ^Node, p: int) -> u8 {
	v: u8
	switch n in node {
	case (Branch):
		if p >= n.weight && n.right != nil {
			v = index_char(n.right, p - n.weight)
		} else if n.left != nil {
			v = index_char(n.left, p)
		}
	case (Leaf):
		if p >=
		   len(
			   n.data,
		   ) {panic(fmt.tprintf("Index [%v] exceeds length of Leaf: [%s], len: [%v]", p, string(n.data), len(n.data)))}
		v = n.data[p]
	}
	return v
}
// finds the leaf containing p and its parent branch
//O(log-n)
find_node :: proc(node: ^Node, p: int) -> (leaf: ^Node, p_local: int) {
	leaf = nil
	p_local = p
	switch n in node {
	case (Branch):
		if p >= n.weight && n.right != nil {
			leaf, p_local = find_node(n.right, p - n.weight)
		} else if n.left != nil {
			leaf, p_local = find_node(n.left, p)
		}
	case (Leaf):
		if p >=
		   len(
			   n.data,
		   ) {panic(fmt.tprintf("Index [%v] exceeds length of Leaf: [%s], len: [%v]", p, string(n.data), len(n.data)))}
		leaf = node
	}
	return leaf, p_local
}

// O(log-n)
get_weight :: proc(node: ^Node) -> int {
	w := 0
	if node == nil {return w}
	switch n in node {
	case (Branch):
		w += n.weight // contains full left subtree
		w += get_weight(n.right) // recurse right subtree
	case (Leaf):
		w += len(n.data)
	}
	return w
}
// produces a new branch wrapping the left and right
// O(log-n)
concat :: proc(left: ^Node, right: ^Node) -> ^Node {
	root := make_branch(left, right)
	return root
}
// Clears old parent pointer
//O(1)
set_parent :: proc(parent: ^Node, child: ^Node) {
	parent_ptr: ^^Node
	switch node in child {
	case (Branch):
		parent_ptr = &node.parent
	case (Leaf):
		parent_ptr = &node.parent
	}
	// // if there was a previous parent, clear it:
	// if parent_ptr^ != nil {
	// 	old_parent := &parent_ptr^.(Branch)
	// 	if old_parent.left == child {
	// 		old_parent.left = nil
	// 	} else if old_parent.right == child {
	// 		old_parent.right = nil
	// 	} else {invalid_code_path(#procedure)}
	// }
	parent_ptr^ = parent
}
//Remove child from parent, and parent from child
//O(1)
detach_child :: proc(parent: ^Node, child: ^Node) -> (was_left: bool) {
	assert(parent_of(child) == parent)
	switch c in child {
	case (Branch):
		c.parent = nil
	case (Leaf):
		c.parent = nil
	}
	pbr := &parent.(Branch)
	if child == pbr.left {
		pbr.left = nil
		return true
	} else if child == pbr.right {
		pbr.right = nil
	} else {
		invalid_code_path(#procedure)
	}
	return false
}
// O(log-n) [get_weight]
make_branch :: proc(left: ^Node, right: ^Node, allocator := context.allocator) -> ^Node {
	context.allocator = allocator
	node := new(Node)
	node^ = Branch {
		left   = left,
		right  = right,
		weight = get_weight(left), // <-- O(log-n)
	}
	set_parent(node, left)
	set_parent(node, right)
	return node
}
//Parent is _not_ set
// O(s) [clone]
make_leaf :: proc(str: []u8, allocator := context.allocator) -> ^Node {
	context.allocator = allocator
	leaf := new(Node)
	leaf^ = Leaf{slice.clone(str, allocator), nil}
	return leaf
}
destroy_leaf :: proc(leaf: ^^Leaf) {
	delete(leaf^^.data)
	free(leaf^)
}

//mutates left, returns right side
// O(log-n) i think?
split :: proc(node: ^Node, p: int) -> ^Node {
	assert(p > 0 && get_weight(node) > p, "cannot split 0th or last index")
	leaf_node, leaf_idx, did_split := split_at_p(node, p)
	//
	leaf := &leaf_node.(Leaf)
	branch_node := leaf.parent
	branch := &branch_node.(Branch)
	right_tree: ^Node = nil
	parent: ^Node
	self: ^Node
	//
	if leaf_idx == 0 && branch.left == leaf_node {
		// Case 1: Before Left
		right_tree = leaf.parent
		parent = right_tree.(Branch).parent
		self = right_tree
		if parent.(Branch).left == self {
			(&parent.(Branch)).left = nil
		} else {
			(&parent.(Branch)).right = nil
		}
	} else if leaf_idx >= get_weight(branch_node) {
		fmt.println("IDX GTE RIGHT - NOT POSSIBLE (?)") // todo: delete this else if once proven out
		invalid_code_path(#procedure)
	} else {
		// Case 2: Between the branches
		right_tree = branch.right
		branch.right = nil
		parent = branch.parent
		self = branch_node
	}
	//Clip the right tree: O(log-n) for loop
	for parent != nil {
		if parent.(Branch).right != self && parent.(Branch).right != nil {
			right_tree = concat(right_tree, parent.(Branch).right) // O(log-n) concat
			(&parent.(Branch)).right = nil
		}
		self = parent
		parent = parent.(Branch).parent
	}
	return right_tree
}
// Splits a leaf-node into two and attaches a floating parent branch
// O(s)
split_leaf :: proc(leaf: ^^Leaf, p: int) -> ^Node {
	left := make_leaf(leaf^.data[:p])
	right := make_leaf(leaf^.data[p:])
	root := make_branch(left, right) // O(log-h) [h=1]
	set_parent(root, left)
	set_parent(root, right)
	destroy_leaf(leaf)
	return root
}
// O(log-n)
split_at_p :: proc(node: ^Node, p: int) -> (leaf_node: ^Node, leaf_idx: int, did_split: bool) {
	leaf_node, leaf_idx = find_node(node, p) // O(log-n)
	leaf := &leaf_node.(Leaf)
	branch_node := leaf.parent
	branch := &branch_node.(Branch)
	// Split the leaf, cursor was inside its text:
	if len(leaf.data) - 1 > leaf_idx && leaf_idx != 0 {
		did_split = true
		fmt.println("inside split,L", to_string(leaf_node))
		fmt.println("inside split,B", to_string(branch_node))
		new_branch_node := split_leaf(&leaf, leaf_idx) // O(s)
		if branch.left == leaf_node {branch.left = new_branch_node} else {branch.right = new_branch_node}
		set_parent(branch_node, new_branch_node)
	}
	return leaf_node, leaf_idx, did_split
}

// is_left_child :: proc(node: ^Node) -> bool {
// 	parent_node: ^Node = parent_of(node)
// 	assert(parent_node != nil, "nil parent for `is_left_child`")
// 	return (&parent_node.(Branch)).left == node
// }
parent_of :: proc(node: ^Node) -> ^Node {
	parent_node: ^Node
	switch n in node {
	case (Branch):
		parent_node = n.parent
	case (Leaf):
		parent_node = n.parent
	}
	return parent_node
}

// O(log-n)
insert :: proc(root: ^Node, p: int, s: string, allocator := context.allocator) {
	// rhs := split(root, p)
	leaf_node, leaf_idx, did_split := split_at_p(root, p)
	// leaf := &leaf_node.(Leaf)
	// existing_branch := leaf.parent
	// branch := &existing_branch.(Branch)
	// is_left := is_left_child(existing_branch)
	parent := parent_of(leaf_node)
	// is_left_child:=is_left_child(leaf_node)
	was_left := detach_child(parent, leaf_node)
	new_leaf := make_leaf(transmute([]u8)s)
	new_branch := concat(leaf_node, new_leaf)
	set_parent(parent, new_branch)
	if was_left {
		(&parent.(Branch)).left = new_leaf
	} else {
		(&parent.(Branch)).right = new_leaf
	}
	fmt.println("split-new_branch", to_string(new_branch))
	fmt.println("split-parent", to_string(parent))

	// new_branch_node := concat(leaf_node, new_leaf) // BRANCH(ARE-NOT)
	// set_parent(existing_branch, new_branch_node)
	// new2_branch_node := concat(existing_branch, new_branch_node)
	// set_parent(parent, new2_branch_node)
	// if is_left {
	// 	assert((&parent.(Branch)).left != nil)
	// 	fmt.println("was left", to_string((&parent.(Branch)).left))
	// 	(&parent.(Branch)).left = new2_branch_node
	// } else {
	// 	fmt.println("was right")
	// 	assert((&parent.(Branch)).right == existing_branch)
	// 	(&parent.(Branch)).right = new2_branch_node
	// }

	// fmt.println("split-new_branch_node", to_string(new_branch_node))
	// fmt.println("split-new2_branch_node", to_string(new2_branch_node))
	fmt.println("split-parent", to_string(parent))
	// fmt.println("split-node", to_string(node))
	// fmt.println("split-rhs", to_string(rhs))

}

/////////////////////////////////////////////////////////////////////////////////////////////////

import "core:testing"

@(private)
@(test)

test_index :: proc(t: ^testing.T) {
	rope := make_test_rope()

	// insert(&r, 0, "Hello") // insert at start
	// insert(&r, 5, ",") // insert in middle
	// insert(&r, 6, " ")
	// insert(&r, 7, "world") // insert at end

	// line := make([]u8, 12)
	// n := copy_line_from_rope(&line[0], len(line), &r, 0)
	// text := string(line)

	// assert(text == "Hello, world", "expected strings to match")
	// assert(n == 12, "expected 12 chars copied")
}
//text-fixture
@(private)
make_test_rope :: proc() -> ^Node {
	l1 := make_leaf(transmute([]u8)string("Ropes")) // 0-4
	r1 := make_leaf(transmute([]u8)string("Are")) //5-7
	l2 := make_leaf(transmute([]u8)string("Easy")) //8-11
	r2 := make_leaf(transmute([]u8)string("Peasy")) //12-16
	b1 := make_branch(l1, r1)
	b2 := make_branch(l2, r2)
	b := make_branch(b1, b2)
	return b
}
