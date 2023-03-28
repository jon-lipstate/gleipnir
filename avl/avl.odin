package avl
import "core:fmt"
String_Iterator :: struct {
	s: string,
	i: int,
}
into_iter :: proc(s: string) -> String_Iterator {
	it := String_Iterator{s, 0}
	return it
}
iter_next :: proc(it: ^String_Iterator) -> (rune, bool) {
	if it.i >= len(it.s) {return rune('-'), false}
	r := rune((it.s)[it.i])
	it.i += 1
	return r, true
}
////////////
// AVLNode represents a node in an AVL tree
AVLNode :: struct {
	key:    int,
	value:  int,
	height: int,
	left:   ^AVLNode,
	right:  ^AVLNode,
}
// safe-height
safe_height :: proc(n: ^AVLNode) -> int {
	if n == nil {return -1} 	// shouldnt this be zero??
	return n.height
}
// update_height updates the height of the node
update_height :: proc(n: ^AVLNode) {
	n.height = max(safe_height(n.left), safe_height(n.right)) + 1
}
// rotate_left performs a left rotation on the given node
rotate_left :: proc(n: ^AVLNode) -> ^AVLNode {
	pivot := n.right
	n.right = pivot.left
	pivot.left = n
	update_height(n)
	update_height(pivot)
	return pivot
}
// rotate_right performs a right rotation on the given node
rotate_right :: proc(n: ^AVLNode) -> ^AVLNode {
	pivot := n.left
	n.left = pivot.right
	pivot.right = n
	update_height(n)
	update_height(pivot)
	return pivot
}
// rebalance rebalances the given node
rebalance :: proc(n: ^^AVLNode) {
	np := n^
	balance := safe_height(np.left) - safe_height(np.right)
	if balance > 1 {
		if safe_height(np.left.left) < safe_height(np.left.right) {
			n^.left = rotate_left(np.left)
		}
		n^ = rotate_right(n^)
	} else if balance < -1 {
		if safe_height(np.right.right) < safe_height(np.right.left) {
			n^.right = rotate_right(np.right)
		}
		n^ = rotate_left(np)
	} else {
		update_height(np)
	}
}
// search looks for a node with the given key in the tree
search :: proc(n: ^AVLNode, key: int) -> ^AVLNode {
	if n == nil {return nil}
	if key < n.key {
		return search(n.left, key)
	} else if key > n.key {
		return search(n.right, key)
	} else {
		return n
	}
}

// insert inserts a new node with the given key and value into the tree
insert :: proc(n: ^AVLNode, key, value: int) -> ^AVLNode {
	if n == nil {
		node := new(AVLNode)
		node^ = {
			key    = key,
			value  = value,
			height = 0,
		}
		return node
	}

	if key < n.key {
		n.left = insert(n.left, key, value)
	} else if key > n.key {
		n.right = insert(n.right, key, value)
	} else {
		n.value = value // Update the value if the key is self
	}

	n := n
	rebalance(&n)
	return n
}

// find_min returns the node with the minimum key in the tree
find_min :: proc(n: ^AVLNode) -> ^AVLNode {
	if n == nil || n.left == nil {
		return n
	}
	return find_min(n.left)
}

// delete_min removes the node with the minimum key from the tree
delete_min :: proc(n: ^AVLNode) -> ^AVLNode {
	if n == nil || n.left == nil {
		return n.right
	}
	n.left = delete_min(n.left)
	n := n
	rebalance(&n)
	return n
}

// delete removes the node with the given key from the tree
delete :: proc(n: ^AVLNode, key: int) -> ^AVLNode {
	if n == nil {
		return nil
	}
	if key < n.key {
		n.left = delete(n.left, key)
	} else if key > n.key {
		n.right = delete(n.right, key)
	} else {
		if n.left == nil {
			return n.right
		} else if n.right == nil {
			return n.left
		} else {
			min_right := find_min(n.right)
			n.key = min_right.key
			n.value = min_right.value
			n.right = delete_min(n.right)
		}
	}
	n := n
	rebalance(&n)
	return n
}
import "core:strconv"
import "core:strings"
get_height :: proc(n: ^AVLNode) -> int {
	if n == nil {return 0}
	return max(get_height(n.left), get_height(n.right)) + 1
}
get_width :: proc(height: int) -> int {
	return (height + 1) * 2 + 1
}
fill_table :: proc(node: ^AVLNode, depth: int, start: int, end: int, table: [dynamic][dynamic]string) {
	if node == nil {return}

	mid := (start + end) / 2
	table[depth][mid] = strconv.itoa(make([]u8, 4), node.key)
	if node.left != nil {fill_table(node.left, depth + 1, start, mid - 1, table)}
	if node.right != nil {fill_table(node.right, depth + 1, mid + 1, end, table)}
}

print_tree_ascii :: proc(n: ^AVLNode) {
	data: [dynamic][dynamic]string = {}
	depth := get_height(n)
	width := get_width(depth)
	for i := 0; i < depth; i += 1 {
		append(&data, make_dynamic_array_len([dynamic]string, width))
	}
	for row in &data {
		for cell in &row {
			cell = " "
		}
	}
	fill_table(n, 0, 0, width - 1, data)

	for row in data {
		fmt.println(row)
	}
	for row in data {
		sb := strings.builder_make_len_cap(0, width)
		for cell in row {
			remaining := 2 - len(cell)
			b := remaining / 2
			a := remaining - b
			//spaces before:
			strings.write_string(&sb, strings.repeat(" ", b))
			strings.write_string(&sb, cell)
			//spaces-after
			strings.write_string(&sb, strings.repeat(" ", a))
		}
		fmt.println(strings.to_string(sb))
	}
}

main :: proc() {
	// Example usage of the AVL tree
	tree := &AVLNode{}
	keys := []int{3, 1, 7, 5, 9, 0, 2, 4, 6, 8}
	// Insert nodes
	for key in keys {
		tree = insert(tree, key, key)
	}
	print_tree_ascii(tree)
}
