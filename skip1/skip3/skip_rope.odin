package skip_rope

import "core:fmt"
import "core:runtime"
import "core:sync"
import "core:strings"
import "core:math/rand"

Allocator :: runtime.Allocator
//////////////////////////////////
// Height must be 2^H to remain efficient, 1<<20 gives 4.2 gb file size
MAX_HEIGHT :: 4
SkipNode :: struct {
	node: ^Node,
	next: ^SkipNode,
	prev: ^SkipNode,
	down: ^SkipNode,
	up:   ^SkipNode,
}

Node :: struct {
	str:          string,
	cursor_start: int,
	level:        int,
	is_deleted:   bool,
	up:           ^SkipNode,
	next:         ^Node,
	prev:         ^Node,
}

Rope :: struct {
	rune_count: int,
	size:       int,
	rng:        rand.Rand,
	head:       ^Node,
	free_node:  ^Node,
	free_skips: ^SkipNode,
	index:      [MAX_HEIGHT]^SkipNode, // len(index) -1 is highest node in the tower
	max_level:  int,
	allocator:  Allocator,
}
/////////////////////////

// Searches for a node who contains the cursor position, a local zero index will return this node
// `current_pos` includes aggregated positional weights up to, but not including `node`
find_node :: proc(rope: ^Rope, cursor_pos: int) -> (node: ^Node, current_pos: int) {
	current_pos = 0
	node = rope.head
	for node != nil {
		next := node.next
		if next == nil || len(node.str) + current_pos > cursor_pos {
			break
		}
		current_pos += len(node.str)
		node = node.next
	}

	return node, current_pos
}

delete_text :: proc(rope: ^Rope, cursor_position: int, n_runes: int) {
	node, current_p := find_node(rope, cursor_position)
	str_len := node != nil ? len(node.str) : 0
	local_offset := cursor_position - current_p
	del_split :: #force_inline proc(rope: ^Rope, node: ^Node, str: string) -> ^Node {
		node.is_deleted = true
		keep := new(Node)
		if rope.head == node {rope.head = keep}
		keep.str = strings.clone(str) // TODO: should be external data buffer, clone for now
		DLL_REPLACE(node, keep)
		FREELIST_APPEND(rope, node)
		return keep
	}
	del_node :: #force_inline proc(rope: ^Rope, node: ^Node) -> ^Node {
		node.is_deleted = true
		next := node.next
		if rope.head == node {rope.head = next}
		DLL_REMOVE(node)
		FREELIST_APPEND(rope, node)
		return next
	}
	if local_offset + n_runes > str_len {
		n_to_del := n_runes
		if local_offset != 0 {
			// cut right portion off:
			node = del_split(rope, node, node.str[:local_offset + 1])
			n_to_del -= str_len - local_offset
		}
		node = node.next
		for n_to_del >= len(node.str) {
			n_to_del -= len(node.str)
			node = del_node(rope, node)
		}
		if n_to_del > 0 {
			// cut left portion off:
			del_split(rope, node, node.str[n_to_del:])
		}
	} else if local_offset + n_runes < str_len {
		// case 1: cuts to edge:
		left_keep := node.str[:local_offset]
		right_keep := node.str[local_offset + n_runes:]
		if len(left_keep) > 0 && len(right_keep) > 0 {
			node = del_split(rope, node, left_keep)
			insert_text(rope, cursor_position, right_keep)
		} else if len(left_keep) > 0 {
			node = del_split(rope, node, left_keep)
		} else if len(right_keep) > 0 {
			node = del_split(rope, node, right_keep)
		}
	} else {
		node = del_node(rope, node)
	}
}
split_text :: proc(rope: ^Rope, node: ^Node, local_pos: int) -> ^Node {
	left_str := strings.clone(node.str[:local_pos]) // TODO: should be external data buffer, clone for now
	right_str := strings.clone(node.str[local_pos:])
	node.is_deleted = true
	left := new(Node)
	left.str = left_str
	DLL_REPLACE(node, left)
	if rope.head == node {rope.head = left}
	right := new(Node)
	right.str = right_str
	DLL_INSERT(left, right)
	FREELIST_APPEND(rope, node)
	return left
}
insert_text :: proc(rope: ^Rope, cursor_position: int, str: string) {
	node, current_p := find_node(rope, cursor_position)
	str_len := node != nil ? len(node.str) : 0
	local_offset := cursor_position - current_p
	//Insert to left edge:
	if local_offset == 0 {
		if node != nil {
			node = node.prev // move back so we can attach to right of
		}
	} else if str_len - local_offset > 0 {
		node = split_text(rope, node, cursor_position - current_p)
	}
	target := new(Node)
	target.str = str
	if node == nil {
		rope.head = target
	} else {
		DLL_INSERT(node, target)
	}
	rope.rune_count += len(target.str)
}
DLL_REPLACE :: proc(old: ^$T, target: ^T) {
	target.next = old.next
	target.prev = old.prev
	if target.next != nil {target.next.prev = target}
	if target.prev != nil {target.prev.next = target}
}
DLL_INSERT :: proc(prev: ^$T, target: ^T) {
	target.prev = prev
	target.next = prev.next
	if prev.next != nil {prev.next.prev = target}
	prev.next = target
}
DLL_REMOVE :: proc(target: ^$T) {
	if target.next != nil {target.next.prev = target.prev}
	if target.prev != nil {target.prev.next = target.next}
}
FREELIST_APPEND :: proc(rope: ^Rope, node: ^Node) {
	if rope.free_node == nil {rope.free_node = node} else {
		node.next = rope.free_node
		rope.free_node = node
	}
}
import "core:intrinsics"
make_rope :: proc(allocator := context.allocator) -> ^Rope {
	context.allocator = allocator
	r := new(Rope, allocator)
	r.allocator = allocator
	r.rng = rand.create(u64(intrinsics.read_cycle_counter()))
	r.max_level = 0
	return r
}
free_rope :: proc(rope: ^Rope) {
	for node := rope.head; node != nil; node = node.next {
		free(node)
	}
	free(rope)
}

///////////////////////////////

main :: proc() {
	rope := make_rope()
	defer free_rope(rope)
	//
	insert_text(rope, 0, "RopesAreEasy")
	insert_text(rope, rope.rune_count, "Peasy") // end-insert
	insert_text(rope, 8, "_NOT_") // Middle-Insert
	delete_text(rope, 1, 2)
	insert_text(rope, 1, "op")

	delete_text(rope, 8, 5)
	print_rope(rope)
	fmt.println(get_range(rope, 0, 20))
	free_all(context.temp_allocator)

}
get_range :: proc(rope: ^Rope, cursor_position: int, n_chars: int, allocator := context.temp_allocator) -> string {
	context.allocator = allocator
	node, current_p := find_node(rope, cursor_position)
	sb := strings.builder_make_len_cap(0, n_chars, allocator)
	chars_remaining := n_chars
	if cursor_position - current_p != 0 {
		strings.write_string(&sb, node.str[cursor_position - current_p:])
		node = node.next
	}
	for ; node != nil; node = node.next {
		if len(node.str) > chars_remaining {
			strings.write_string(&sb, node.str[:chars_remaining])
			break
		}
		strings.write_string(&sb, node.str)
		chars_remaining -= len(node.str)
	}
	return strings.to_string(sb)
}

print_rope :: proc(rope: ^Rope) {
	index := 0
	current := rope.head
	for current != nil {
		fmt.printf("([%v] %s)", index, current.str)
		index += 1
		current = current.next
		// catch infinite loops:
		if index > 20 {
			fmt.println("ERR :: I>20")
			break
		}
	}
	fmt.println()
}
///////////////////////////////////////
random_tower_height :: proc(rope: ^Rope) -> int {
	tower_height := int(rand.float64_range(1, 1 << MAX_HEIGHT, &rope.rng))
	final_level := MAX_HEIGHT - 1
	for level: uint = 0; level < MAX_HEIGHT; level += 1 {
		// If the current level is included, return the current level
		if tower_height & (1 << level) != 0 {
			final_level = int(level)
			break
		}
	}
	rope.max_level = max(rope.max_level, final_level)
	// If none of the levels were included, return the maximum height
	return final_level
}

//  [3]                               [3]                         [3]
//  [2]                               [2]                         [2]
//  [1]          [1]    [1]           [1]                         [1]
//  [0]   [0]    [0]    [0]    [0]    [0]    [0]    [0]    [0]    [0]    [0]
// [ 5 ] [10]   [ 1 ]  [ 4 ]  [ 5 ]  [10 ]  [ 10]  [ 1 ]  [ 1 ]  [ 5 ]  [10 ]
//  5     15     16     20     25     35     45     46     47     52     62
RopeIter :: struct {
	skips:   [MAX_HEIGHT]^SkipNode,
	offsets: [MAX_HEIGHT]int,
}
iter_to :: proc(rope: ^Rope, cursor: int) -> RopeIter {
	it := RopeIter{}
	height := rope.max_level
	skip := rope.index[height]
	current_cursor := 0
	//
	for {
		if skip.next == nil || current_cursor + skip.next.node.cursor_start > cursor {
			it.skips[height] = skip
			it.offsets[height] = current_cursor
			height -= 1
			skip = skip.down
			if skip.down == nil {break}
			if height < 0 {panic("mismatch")}
		}
		current_cursor += skip.node.cursor_start
		skip = skip.next
	}
	assert(skip.down == nil && height == 0)
	return it
}
find_skips :: proc(rope: ^Rope, cursor_pos: int, max_level: int) -> [MAX_HEIGHT]^SkipNode {
	found_node, found_pos := find_node(rope, cursor_pos)
	prev_skips := [MAX_HEIGHT]^SkipNode{}
	current_level := rope.max_level
	skip := rope.index[current_level] // Highest Index is the highest level in the tower
	for current_level > 0 {
		if skip != nil {break}
		current_level -= 1
		skip = rope.index[current_level]
	}
	if skip != nil {
		for skip.down != nil && current_level > 0 {
			next := skip.next
			if next != nil && next.node.cursor_start < found_pos {
				skip = next
			} else {
				prev_skips[current_level] = skip
				skip = skip.down
				current_level -= 1
			}
		}
	}

	return prev_skips
}
