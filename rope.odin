package rope
import "core:fmt"
import "core:slice"

main :: proc() {
	test_insert(nil)
}
to_string :: proc(node: ^Node, allocator := context.allocator) -> string {
	context.allocator = allocator
	weight := get_weight(node)
	str := make([]u8, weight)
	to_str :: proc(node: ^Node, dest: []u8) {
		switch n in node.kind {
		case (Leaf):
			copy_slice(dest, n)
		// fmt.println(string(n))
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
	weight: int, // aggregate weights of left subtree
}
Leaf :: []u8
Node :: struct {
	parent: ^Node,
	kind:   union {
		Branch,
		Leaf,
	},
}
// Finds a character at index `i` and returns it (Avg: O(log-n),Worst:O(n))
// TODO: Return a Rune??
index_char :: proc(node: ^Node, p: int) -> u8 {
	v: u8
	switch n in node.kind {
	case (Branch):
		if p >= n.weight && n.right != nil {
			v = index_char(n.right, p - n.weight)
		} else if n.left != nil {
			v = index_char(n.left, p)
		}
	case (Leaf):
		if p >= len(n) {panic(fmt.tprintf("Index [%v] exceeds length of Leaf: [%s], len: [%v]", p, string(n), len(n)))}
		v = n[p]
	}
	return v
}
// finds the leaf containing p and its parent branch
//O(log-n)
find_node :: proc(node: ^Node, p: int) -> (leaf: ^Node, p_local: int) {
	leaf = nil
	p_local = p
	switch n in node.kind {
	case (Branch):
		if p >= n.weight && n.right != nil {
			leaf, p_local = find_node(n.right, p - n.weight)
		} else if n.left != nil {
			leaf, p_local = find_node(n.left, p)
		}
	case (Leaf):
		if p >= len(n) {panic(fmt.tprintf("Index [%v] exceeds length of Leaf: [%s], len: [%v]", p, string(n), len(n)))}
		leaf = node
	}
	return leaf, p_local
}

// O(log-n)
get_weight :: proc(node: ^Node) -> int {
	w := 0
	if node == nil {return w}
	switch n in node.kind {
	case (Branch):
		w += get_weight(n.left) // contains full left subtree
		w += get_weight(n.right) // recurse right subtree
	case (Leaf):
		w += len(n)
	}
	return w
}
get_root :: proc(node: ^Node) -> ^Node {
	root := node
	for root.parent != nil {
		root = root.parent
	}
	return root
}
// Recursively resets weight upwards in the tree
reset_weights :: proc(node: ^Node) {
	switch n in &node.kind {
	case (Branch):
		n.weight = get_weight(n.left)
		if node.parent != nil {reset_weights(node.parent)}
	case (Leaf):
		reset_weights(node.parent)
	}
}

// produces a new branch wrapping the left and right
// O(log-n)
concat :: proc(left: ^Node, right: ^Node) -> ^Node {
	root := make_branch(left, right)
	return root
}

//Remove child from parent, and parent from child
//O(1)
detach_child :: proc(parent: ^Node, child: ^Node) -> (was_left: bool) {
	assert(child.parent == parent)
	child.parent = nil
	pbr := &parent.kind.(Branch)
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
	node.kind = Branch {
		left   = left,
		right  = right,
		weight = get_weight(left), // <-- O(log-n)
	}
	left.parent = node
	right.parent = node
	return node
}
//Parent is _not_ set
// O(s) [clone]
make_leaf :: proc(str: []u8, allocator := context.allocator) -> ^Node {
	context.allocator = allocator
	leaf := new(Node)
	leaf.kind = slice.clone(str, allocator)
	return leaf
}
destroy_leaf :: proc(leaf_node: ^^Node) {
	delete(leaf_node^.kind.(Leaf))
	free(leaf_node^)
}

//mutates left, returns right side, resets weights
// O(log-n) i think?
split :: proc(node: ^Node, p: int) -> ^Node {
	assert(p > 0 && get_weight(node) > p, "cannot split 0th or last index")
	leaf_node, leaf_idx, did_split := split_at_p(node, p)
	//
	leaf := &leaf_node.kind.(Leaf)
	branch_node := leaf_node.parent
	branch := &branch_node.kind.(Branch)
	right_tree: ^Node = nil
	parent: ^Node
	self: ^Node
	//
	if leaf_idx == 0 && branch.left == leaf_node {
		// Case 1: Before Left
		right_tree = leaf_node.parent
		parent = right_tree.parent
		self = right_tree
		if parent.kind.(Branch).left == self {
			(&parent.kind.(Branch)).left = nil
		} else {
			(&parent.kind.(Branch)).right = nil
		}
	} else {
		assert(leaf_idx < get_weight(branch_node))
		// Case 2: Between the branches
		right_tree = branch.right
		branch.right = nil
		parent = branch_node.parent
		self = branch_node
	}
	//Clip the right tree: O(log-n) for loop
	for parent != nil {
		if parent.kind.(Branch).right != nil && parent.kind.(Branch).right != self {
			right_tree = concat(right_tree, parent.kind.(Branch).right) // O(log-n) concat
			(&parent.kind.(Branch)).right = nil
		}
		self = parent
		parent = parent.parent
	}
	reset_weights(leaf_node)
	return right_tree
}
// Splits a leaf-node into two and attaches a floating parent branch
// O(s)
split_leaf :: proc(leaf_node: ^^Node, p: int) -> ^Node {
	assert(p >= 0 && p < len(leaf_node^.kind.(Leaf)))
	left := make_leaf(leaf_node^.kind.(Leaf)[:p])
	right := make_leaf(leaf_node^.kind.(Leaf)[p:])
	root := make_branch(left, right) // O(log-h) [h=1]
	left.parent = root
	right.parent = root
	destroy_leaf(leaf_node)
	leaf_node^ = left
	return root
}
// O(log-n)
split_at_p :: proc(node: ^Node, p: int) -> (leaf_node: ^Node, leaf_idx: int, did_split: bool) {
	leaf_node, leaf_idx = find_node(node, p) // O(log-n)
	leaf := &leaf_node.kind.(Leaf)
	assert(leaf_idx >= 0 && leaf_idx < len(leaf))
	branch_node := leaf_node.parent
	branch := &branch_node.kind.(Branch)
	// Split the leaf, cursor was inside its text:
	if len(leaf) > leaf_idx - 1 && leaf_idx != 0 {
		did_split = true
		new_branch_node := split_leaf(&leaf_node, leaf_idx) // O(s)
		if branch.left == leaf_node {branch.left = new_branch_node} else {branch.right = new_branch_node}
		new_branch_node.parent = branch_node
	}
	return leaf_node, leaf_idx, did_split
}

// O(log-n)
insert_text :: proc(root: ^Node, p: int, s: string, allocator := context.allocator) {
	leaf_node, leaf_idx, did_split := split_at_p(root, p)
	parent := leaf_node.parent
	was_left := detach_child(parent, leaf_node) // TODO: why is everything is a left node ??
	new_leaf := make_leaf(transmute([]u8)s)
	left := leaf_idx == 0 ? new_leaf : leaf_node
	right := leaf_idx == 0 ? leaf_node : new_leaf
	new_branch := concat(left, right)
	new_branch.parent = parent
	if was_left {
		(&parent.kind.(Branch)).left = new_branch
	} else {
		(&parent.kind.(Branch)).right = new_branch
	}
	reset_weights(leaf_node)
}

delete_text :: proc(root: ^Node, start: int, end: int) -> ^Node {
	panic("not impl")
}

replace_text :: proc(root: ^Node, start: int, end: int, new_string: string) -> ^Node {
	panic("not impl")
}

substring :: proc(root: ^Node, start: int, end: int) -> ^Node {
	panic("not impl")
}

rebalance :: proc(root: ^Node) -> ^Node {
	panic("not impl")
}

Iterator :: struct {}
iterator_init :: proc(root: ^Node) -> Iterator {
	panic("not impl")
}
iterator_next :: proc(it: ^Iterator) -> bool {
	panic("not impl")
}
iterator_current :: proc(it: ^Iterator) -> u8 {
	panic("not impl")
}

/////////////////////////////////////////////////////////////////////////////////////////////////

import "core:testing"

// @(test)
// test_index :: proc(t: ^testing.T) {
// 	rope := make_test_rope()
// 	R := rune(index_char(rope, 0))
// 	s := rune(index_char(rope, 4))
// 	A := rune(index_char(rope, 5))
// 	E := rune(index_char(rope, 8))
// 	assert(R == 'R')
// 	assert(s == 's')
// 	assert(A == 'A')
// 	assert(E == 'E')

// 	// assert(text == "Hello, world", "expected strings to match")
// 	// assert(n == 12, "expected 12 chars copied")
// }
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

// @(test)
// test_split :: proc(t: ^testing.T) {
// 	rope := make_test_rope()
// 	right_side := split(rope, 8)
// 	assert(to_string(rope) == string("RopesAre"), "--> Split on word Boundary")
// 	assert(to_string(right_side) == string("EasyPeasy"))

// 	rope2 := make_test_rope()
// 	right_side2 := split(rope2, 7)

// 	assert(to_string(rope2) == string("RopesAr"), "--> Split mid-word")
// 	assert(to_string(right_side2) == string("eEasyPeasy"))
// }
@(test)
test_insert :: proc(t: ^testing.T) {
	root := make_test_rope()
	insert_text(root, 9, "NOT")
	// assert(to_string(root) == "RopesAreENOTasyPeasy")

	root2 := make_test_rope()
	insert_text(root2, 8, "NOT")
	assert(to_string(root2) == "RopesAreNOTEasyPeasy")

	root3 := make_test_rope()
	insert_text(root3, 7, "NOT")
	assert(to_string(root3) == "RopesArNOTeEasyPeasy")
	// RopesAreEasyPeasy
	// 0123456789 123456789
	// RopesAreENOTasyPeasy

}
// RopeIterator :: struct {
// 	current_node:    ^Node,
// 	global_position: int,
// 	local_position:  int,
// 	total_length:    int,
// }

// next_leaf_node :: proc(node: ^Node) -> ^Node {
// 	if node == nil {return nil}
// 	// In-order traversal to find the next leaf node
// 	current := node
// 	if _, was_a_leaf := node.kind.(Leaf); was_a_leaf {
// 		current = node.parent
// 		current_branch_right := (&current.kind.(Branch)).right
// 		if current_branch_right != node && current_branch_right != nil {
// 			return current_branch_right
// 		}
// 	}
// 	// We know we're not in a bottom branch, go up then down and left:
// 	next := current.parent
// 	// go up till 
// 	for next != nil {
// 		next_branch := &next.kind.(Branch)
// 		if next_branch.left == current && next_branch.right != nil {
// 			next = next_branch.right
// 			// go down to bottom left leaf:
// 			if vv, is_leaf := next.kind.(Leaf); is_leaf {
// 				fmt.println("VVV", string(vv))
// 			}
// 			for {
// 				next = (&next.kind.(Branch)).left
// 				if _, next_is_leaf := next.kind.(Leaf); next_is_leaf {
// 					return next
// 				}
// 			}
// 		} else {
// 			current = next
// 			next = next.parent
// 		}
// 	}
// 	return nil
// }

// rope_iterator :: proc(it: ^RopeIterator) -> (char: u8, index: int, ok: bool) {
// 	if it.global_position < it.total_length {
// 		leaf := &it.current_node.kind.(Leaf)
// 		char = leaf[it.local_position]
// 		index = it.global_position

// 		it.local_position += 1
// 		if it.local_position >= len(leaf) {
// 			it.current_node = next_leaf_node(it.current_node)
// 			it.local_position = 0
// 		}

// 		it.global_position += 1
// 		ok = true
// 	} else {
// 		ok = false
// 	}
// 	return char, index, ok
// }
// @(test)
// test_iterator :: proc(t: ^testing.T) {
// 	// root := make_test_rope()
// 	// insert_text(root, 6, "_not_")
// 	// fmt.println(to_string(root))
// 	// first_leaf, _ := find_node(root, 0)
// 	// it := RopeIterator {
// 	// 	current_node    = first_leaf,
// 	// 	global_position = 0,
// 	// 	local_position  = 0,
// 	// 	total_length    = get_weight(root),
// 	// }
// 	// for ch, index in rope_iterator(&it) {
// 	// 	fmt.print(rune(ch))
// 	// }
// }

import "core:strings"
print_tree :: proc(node: ^Node, depth: int = 0) {
	if node == nil {return}
	spaces := strings.repeat("-", depth)
	sb := strings.builder_make()
	strings.write_string(&sb, spaces)
	//strings.to_string(sb)
	switch n in node.kind {
	case (Leaf):
		strings.write_string(&sb, fmt.aprintf("Leaf:(%v)[%v]", len(n), string(n)))
		fmt.println(strings.to_string(sb))
	case (Branch):
		strings.write_string(&sb, fmt.aprintf("Branch:(w:%v)", n.weight))
		fmt.println(strings.to_string(sb))
		print_tree(n.left, depth + 1)
		print_tree(n.right, depth + 1)
	}
}
