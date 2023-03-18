package jumprope

import "core:runtime"
Allocator :: runtime.Allocator
//\\//\\//\\//\\//\\//\\//\\//\\//\\////\\//\\//\\//\\//\\//\\//\\//\\//\\//

MAX_HEIGHT :: 16
SkipNode :: struct {
	/// Number of RUNEs (UTF8 Chars)
	node: ^Node,
	next: ^SkipNode, // nil when end-of-list
	prev: ^SkipNode,
	down: ^SkipNode, // Nil at level 1
}
Node :: struct {
	str:    string,
	level:  u8, // Height Guaranteed to be >= 1
	marked: bool, // deletion-flag
	next:   ^Node,
	prev:   ^Node,
}
Rope :: struct {
	rune_count: int,
	size:       int, //bytes
	head:       ^Node,
	index:      [dynamic]^SkipNode,
	allocator:  Allocator,
}
//\\//\\//\\//\\//\\//\\//\\//\\//\\////\\//\\//\\//\\//\\//\\//\\//\\//\\//

make_rope :: proc(allocator := context.allocator) -> ^Rope {
	context.allocator = allocator
	r := new(Rope, allocator)
	r.allocator = allocator
	r.index = make_dynamic_array_len_cap([dynamic]^SkipNode, 0, MAX_HEIGHT, allocator)
	r.head = nil // Todo: switch to sentinel?
	return r
}
free_rope :: proc(rope: ^Rope) {
	for node in rope.index {
		if node.next == nil {break}
		free(node)
	}
	delete(rope.index)
	free(rope)
}

// todo: need residual position?
search_node :: proc(rope: ^Rope, position: int) -> ^Node {
	panic("not impl")
}
insert_text :: proc(rope: ^Rope, position: int, str: string) {
	panic("not impl")
}
delete_text :: proc(rope: ^Rope, from: int, n_chars: int) {
	panic("not impl")
}
//\\//\\//\\//\\//\\//\\//\\//\\//\\////\\//\\//\\//\\//\\//\\//\\//\\//\\//
main :: proc() {
	rope := make_rope()
	ra := insert_node(rope, nil)
	ra.str = "RopesAre"
	rope.rune_count = len(ra.str)

	ep := insert_node(rope, ra)
	ep.str = "EasyPeasy"
	rope.rune_count += len(ep.str)
	raise_level(rope, ep, 3)
	raise_level(rope, ra, 1)
}

// todo: string here? do i even need the rope?
insert_node :: proc(rope: ^Rope, after: ^Node) -> ^Node {
	node := new(Node)
	node.level = 1
	if rope.head == nil {
		assert(after == nil)
		rope.head = node
		return node
	} else {
		assert(after != nil)
		if after.next != nil {
			after.next.prev = node
			node.next = after.next
		}
		node.prev = after
		after.next = node
	}
	return node
}
// todo: can this be 'set' level and raise or lower arbitrarly?
raise_level :: proc(rope: ^Rope, target: ^Node, level: u8) {
	current_level := target.level
	node := target
	for i: u8 = 0; i < level; i += 1 {
		if node.level > current_level {
			if len(rope.index) - 1 < int(node.level) {
				append(&rope.index, new(SkipNode, rope.allocator))
			}
			skip_node: ^SkipNode = rope.index[node.level] // .next??
			for {
				assert(skip_node != nil)
				if skip_node.node == node {
					break
				}
				skip_node = skip_node.next
			}
			insert_skip_node(skip_node, target)
		}
	}
}
// Assumes inserting one level above existing (or nil)
insert_skip_node :: proc(after: ^SkipNode, target: ^Node) {
	skip := new(SkipNode)
	if after.next != nil {
		after.next.prev = skip
		skip.next = after.next
	}
	skip.prev = after
	after.next = skip
	if after.down != nil {
		skip.down = after.down.next
	}
	skip.node = target
	target.level += 1
}

// raise-ilevel(prev,prev-tall,height)p:  			raise index
// 	raised <- false
// 	index <- prev.right
// 	while true do
// 	next <- index.right  							traverse the list
// 	if next = ⊥ then
// 	break()
// 	while index.node.v = index.node do
// 	prev.right <- next  							skip removed nodes
// 	if next = ⊥ then
// 	break()
// 	index <- next
// 	next <- next.right
// 	if (prev.node.level ≤ height
// 	∧ index.node.level ≤ height
// 	∧ next.node.level ≤ height) then
// 	raised <- true
// 	new.down <- index 								allocate a index-item: new
// 	new.node <- index.node
// 	new.right <- prev-tall.right
// 	prev-tall.right <- new  raise the tower
// 	index.node.level <- height +1
// 	prev-tall <- new
// 	prev <- index  									continue the traversal
// 	index <- index.right
// 	return raised
