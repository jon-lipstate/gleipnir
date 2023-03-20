package skip_rope

import "core:fmt"
import "core:runtime"
import "core:sync"
import "core:math/rand"

Allocator :: runtime.Allocator
//////////////////////////////////
SkipNode :: struct {
	cursor_start: int, // update on traversals?
	node:         ^Node,
	next:         ^SkipNode,
	down:         ^SkipNode,
}

Node :: struct {
	str:        string,
	level:      int,
	is_deleted: bool,
	next:       ^Node,
	prev:       ^Node,
}

Rope :: struct {
	rune_count: int,
	size:       int,
	rng:        rand.Rand,
	head:       ^Node,
	index:      [MAX_HEIGHT]^SkipNode, // len(index) -1 is highest node in the tower
	max_level:  int,
	allocator:  Allocator,
}
/////////////////////////

// insert_node :: proc(k: int, v: string, rope: ^Rope) -> bool {
// 	// Corresponds to lines 29-30
// 	return do_operation("insert", k, v, rope)
// }

// delete_node :: proc(k: int, rope: ^Rope) -> bool {
// 	// Corresponds to lines 27-28
// 	return do_operation("delete", k, "", rope)
// }

// contains :: proc(k: int, rope: ^Rope) -> bool {
// 	// Corresponds to lines 25-26
// 	return do_operation("contains", k, "", rope)
// }

// Searches for a node who contains the cursor position, a local zero index will return this node
// `current_pos` includes aggregated positional weights up to, but not including `node`
find_node :: proc(rope: ^Rope, cursor_pos: int) -> (node: ^Node, current_pos: int) {
	// Corresponds to lines 61-89
	skip := rope.index[rope.max_level] // Highest Index is the highest level in the tower
	current_pos = 0
	node = nil
	if skip == nil {return node, current_pos} 	// case: empty rope | TO-VERIFY: is this even possible?
	for {
		went_down := false
		next_skip := skip.next // Traverse the list
		if next_skip == nil || len(skip.node.str) + current_pos > cursor_pos {
			went_down = true
			next_skip = skip.down // Go down a level
			if next_skip == nil { 	// Bottom level reached
				node = skip.node
				break
			} else if current_pos <= cursor_pos && current_pos + len(skip.node.str) > cursor_pos {
				// Convention: Cursor 0 is in this node
				node = skip.node // Correct Position is in this node or its leading-edge
				break
			}
		}
		if (!went_down) {
			current_pos += len(skip.node.str)
		}
		skip = next_skip
	}
	return node, current_pos
}

// do_operation :: proc(rope: ^Rope, op_type: string, cursor_pos: int, str: string) -> bool {
// 	// Corresponds to lines 61-89
// 	node, current_pos := find_node(rope, cursor_pos)
// 	node_str := node.str
// 	for {
// 		//Go backwards till find a valid node:
// 		for node.is_deleted {
// 			node = node.prev
// 			current_pos -= len(node.str) // VERIFY: can this be nil? not if we use is_deleted...
// 		}
// 		// Load the next node
// 		next := node.next
// 		next_str := next.str
// 		if next != nil {
// 			help_remove(node, next)
// 			continue
// 		}
// 		// cursor check replaced next.key > fn-key - not sure if i kept correct semantics?
// 		if next == nil || current_pos + len(next_str) > cursor_pos {
// 			result, done := finish(op_type, k, v, node, val, next, next_val)
// 			if done {
// 				return result
// 			}
// 			// Cannot finish due to concurrency, continue the loop
// 		} else {
// 			node = next // Continue traversal
// 		}
// 	}
// }
// Here's a step-by-step explanation of the while loop:

// Lines 75-76: This inner while loop checks if the current node's value is logically deleted (v = ⊥). If it is, it moves to the previous node until a node with a value is found.

// Lines 77-78: Load the next node and its value.

// Lines 79-81: If the next node is not null (⊥) and its value is equal to its next pointer, it means the next node is is_deleted for removal. In this case, the 'help-remove' function is called to remove the node, and the code moves to the next iteration.

// Lines 82-86: If the next node is null (⊥) or its key is greater than the search key 'k', the code attempts to finish the operation (insert/delete/contains) using the 'finish' function. If the operation is completed, the loop breaks.

// Line 87: If the operation cannot be completed due to concurrency, the code will move to the next iteration without breaking the loop.

// Line 88: If the loop has not been broken, the traversal continues by setting the current node to the next node.

// The loop will continue until the desired operation is completed or the end of the skiplist is reached. Finally, the result of the operation is returned in line 89.

// TODO: much nicer to insert relative to another node
make_node :: proc(str: string, allocator: Allocator) -> ^Node {
	// Corresponds to lines 20-24
	node := new(Node, allocator)
	node.str = str
	node.level = 1
	node.is_deleted = false
	return node
}

// finish :: proc(
// 	op_type: string,
// 	k: int,
// 	v: string,
// 	node: ^Node,
// 	val: string,
// 	next: ^Node,
// 	next_val: string,
// ) -> (
// 	bool,
// 	bool,
// ) {
// 	// Corresponds to lines 31-60
// 	result := false
// 	done := false

// 	if op_type == "contains" {
// 		if node.k == k {
// 			if v != "" {
// 				result = true
// 			}
// 		}
// 		done = true
// 	} else if op_type == "delete" {
// 		if node.k != k {
// 			result = false
// 		} else {
// 			if val != "" {
// 				if cas(&node.v, val, "") {
// 					remove(node.prev, node)
// 					result = true
// 				} else {
// 					result = false
// 				}
// 			}
// 		}
// 		done = true
// 	} else if op_type == "insert" {
// 		if node.k == k {
// 			if val == "" {
// 				if cas(&node.v, "", v) {
// 					result = true
// 				} else {
// 					result = false
// 				}
// 			}
// 		} else {
// 			new_node := setup_node(node, next, k, v)
// 			if cas(&node.next, next, new_node) {
// 				next.prev = new_node
// 				result = true
// 			}
// 		}
// 		done = true
// 	}

// 	return result, done
// }

// remove :: proc(prev: ^Node, target: ^Node) {
// 	// Corresponds to lines 90-94
// 	if target.level == 0 { 	// Only remove short nodes
// 		CAS(&target.is_deleted, true, true) // Mark for removal
// 		if target.v == target {
// 			help_remove(prev, target)
// 		}
// 	}
// }

// help_remove :: proc(prev: ^Node, target: ^Node) {
// 	// Corresponds to lines 95-105
// 	if target.is_deleted {
// 		return
// 	}
// 	n := target.next
// 	for !n.marker { 	// Marker to prevent lost inserts
// 		new := setup_node(target, n, -1, "") // -1 is used to represent ⊥ for k
// 		new.v = new
// 		new.marker = true
// 		CAS(target.next, n, new) // Insert the marker
// 		n = node.next
// 	}
// 	if prev.next != target || prev.marker {
// 		return
// 	}
// 	CAS(pred.next, node, n.next) // Remove the nodes
// }

// lower_index_level :: proc(rope: ^Rope) {
// 	// Corresponds to lines 108-115
// 	index := rope.index[0]
// 	for index.down.down != nil {
// 		index = index.down // Get to the 2nd lowest level
// 	}
// 	for index != nil {
// 		index.down = nil // Remove the index-level below
// 		index.node.height -= 1
// 		index = index.next
// 	}
// }

// raise_index :: proc(rope: ^Rope) {
// 	// Corresponds to lines 116-128
// 	max := -1
// 	next := rope.index[0]
// 	for next != nil { 	// Add leftmost idx-items to array
// 		max += 1
// 		rope.first[max] = next
// 		next = next.down
// 	}
// 	inc_lvl := raise_nlevel(rope.first[max].node, rope.first[max], 0)
// 	for i := max; i > 0; i -= 1 { 	// Traverses indices
// 		inc_lvl = raise_ilevel(rope.first[i], rope.first[i - 1], max - i)
// 	}
// 	if inc_lvl {
// 		new.down = rope.index[0] // Allocate an index-item: new
// 		rope.index[0] = new // Add a new index-level
// 	}
// }
// raise_ilevel :: proc(prev, prev_tall: ^SkipNode, height: int) -> bool {
// 	// Corresponds to lines 129-154
// 	raised := false
// 	index := prev.right
// 	for {
// 		next := index.right // Traverse the list
// 		if next == nil {
// 			break
// 		}
// 		for index.node.v == index.node {
// 			prev.right = next // Skip removed nodes
// 			if next == nil {
// 				break
// 			}
// 			index = next
// 			next = next.right
// 		}
// 		if prev.node.level <= height && index.node.level <= height && next.node.level <= height {
// 			raised = true
// 			new.down = index // Allocate an index-item: new
// 			new.node = index.node
// 			new.right = prev_tall.right
// 			prev_tall.right = new // Raise the tower
// 			index.node.level = height + 1
// 			prev_tall = new
// 		}
// 		prev = index // Continue the traversal
// 		index = index.right
// 	}
// 	return raised
// }

// contains :: proc(rope: ^Rope, k: int) -> bool {
// 	return do_operation(rope, "contains", k, "")
// }

delete_text :: proc(rope: ^Rope, cursor_position: int, n_runes: int) -> bool {
	// return do_operation(rope, "delete", k, "")
	panic("not impl")
}

// insert_text :: proc(rope: ^Rope, cursor_position: int, str: string) {
// 	node, cursor_p := find_node(rope, cursor_position)
// 	// TODO:SPLIT
// 	insert_node(rope, cursor_p, node, make_node(str, rope.allocator))
// }
// insert_node :: proc(rope: ^Rope, cursor_p: int, after: ^Node, node: ^Node) {
// 	if after == nil {
// 		assert(rope.head == nil)
// 		rope.head = node
// 	} else {
// 		node.prev = after
// 		node.next = after.next
// 		if after.next != nil {after.next.prev = node}
// 		after.next = node
// 	}
// 	insert_tower(rope, node, cursor_p)
// }

// Generates the entire tower and node, does **not** conect to anything
make_tower :: proc(rope: ^Rope, cursor_start: int, str: string) -> (top_skip: ^SkipNode, level: int) {
	level = random_tower_height(rope)
	node := new(Node, rope.allocator)
	node.level = level
	node.str = str
	top_skip = new(SkipNode, rope.allocator)
	top_skip.node = node
	prev := top_skip
	for i := int(level) - 1; i >= 0; i -= 1 {
		skip := new(SkipNode, rope.allocator)
		skip.node = node
		prev.down = skip
		skip.cursor_start = cursor_start
		prev = skip
	}
	skip_count := 0
	sk := top_skip
	for sk != nil {
		skip_count += 1
		sk = sk.down
	}
	fmt.printf("Tower:L:%v,SK:%v\n", level, skip_count)
	return top_skip, level
}
//  [0] - [0] - [0] - [0]
//  [1] - [1] - - - - [1]
//  [2] - - - - - - - [2]
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
			if next != nil && next.cursor_start < found_pos {
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
insert_text :: proc(rope: ^Rope, cursor_position: int, str: string) {
	node, cursor_p := find_node(rope, cursor_position) // TODO: this is redundant traversal to find_skips
	skip, level := make_tower(rope, cursor_p, str)
	prev_skips := find_skips(rope, cursor_p, int(level))
	target := skip.node
	if node != nil {
		DLL_INSERT(node, target)
	} else {
		rope.head = target
	}
	skip_count := 0
	sk := skip
	for sk != nil {
		skip_count += 1
		sk = sk.down
	}
	// TODO: FIX cursor_start downstream
	for i := int(level); i > 0; i -= 1 {
		assert(skip != nil, "skip was nil")
		ps := prev_skips[i]
		if ps == nil {rope.index[i] = skip} else {
			assert(node != nil)
			skip.next = ps.next
			ps.next = skip
		}
		skip = skip.down
	}
	assert(skip.down == nil, fmt.tprintf("skip.down wasnt nil: %v sk vs %v max_level", skip_count, rope.max_level))
	rope.rune_count += len(target.str)
}

DLL_INSERT :: proc(prev: ^$T, target: ^T) {
	target.prev = prev
	target.next = prev.next
	if prev.next != nil {prev.next.prev = target}
	prev.next = target
}

CAS :: proc(dst: ^$T, old: T, new: T) -> bool {
	//dst: ^$T, old, new: T
	success := sync.atomic_compare_exchange_strong(dst, old, new)
	return success
}
MAX_HEIGHT :: 12 // Adjust this value as needed

// Generate random tower height
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

import "core:intrinsics"
make_rope :: proc(allocator := context.allocator) -> ^Rope {
	context.allocator = allocator
	r := new(Rope, allocator)
	r.allocator = allocator
	r.head = nil // Todo: switch to sentinel?

	r.rng = rand.create(u64(intrinsics.read_cycle_counter()))
	r.max_level = 0
	return r
}
free_rope :: proc(rope: ^Rope) {
	for node in rope.index {
		if node.next == nil {break}
		free(node)
	}
	free(rope)
}

///////////////////////////////

main :: proc() {
	rope := make_rope()
	insert_text(rope, 0, "Ropes")
	insert_text(rope, rope.rune_count, "Are")
	insert_text(rope, rope.rune_count, "Easy")
	insert_text(rope, rope.rune_count, "Peasy")
	fmt.println("After End-Inserts:")
	print_rope(rope)
	// // Insert in the middle:
	// insert_text(rope, 8, "_NOT_")
	// fmt.println("After Mid-Insert:")
	// print_rope(rope)
	// // Delete the "_NOT_" token
	// delete_text(rope, 8, 5)
	// fmt.println("After Delete:")
	// print_rope(rope)

	// // Free the rope
	// free_rope(rope)
}

// Helper function to print the rope
print_rope :: proc(rope: ^Rope) {
	index := 0
	current := rope.head
	for current != nil {
		fmt.printf("([%v] %s)", index, current.str)
		index += 1
		current = current.next
	}
}

// print_skip_list :: proc(rope: ^SkipNode) {
// 	// Find the top-left node of the skip list
// 	top_left := rope
// 	for top_left.down != nil {
// 		top_left = top_left.down
// 	}

// 	// Traverse and print each level
// 	level := 1
// 	for current_level := top_left; current_level != nil; current_level = current_level.up {
// 		fmt.printf("Level %d:\n", level)
// 		for n := current_level; n != nil; n = n.next {
// 			fmt.print(n.str, " ")
// 			for i := 0; i < len(n.str); i += 1 {
// 				fmt.print(" ") // Align the towers by adding extra spaces for each character in the string
// 			}
// 		}
// 		fmt.println()
// 		level += 1
// 	}
// }

/////
// // Procedure to make the rope a perfect skip list
// make_perfect_skip_list :: proc(rope: ^SkipNode) {
//     nodes := []^SkipNode{}
//     for n := rope; n != nil; n = n.next {
//         nodes = append(nodes, n)
//     }

//     node_count := len(nodes)
//     level := 1
//     for ; 1 << level <= node_count; level += 1 {} // Find the maximum level for the given node_count

//     for i, n in nodes {
//         target_level := 1
//         for j := 1; j < level; j += 1 {
//             if (i + 1) % (1 << j) == 0 {
//                 target_level += 1
//             }
//         }

//         while n.level < target_level {
//             // Raise the tower height
//             new_node := ^SkipNode{str: n.str, level: n.level + 1, is_deleted: n.is_deleted, next: n.next, prev: n.prev, down: n}
//             n = new_node
//         }

//         while n.level > target_level {
//             // Lower the tower height
//             n = n.down
//         }

//         if i > 0 {
//             nodes[i - 1].next = n
//         }

//         if i < node_count - 1 {
//             n.next = nodes[i + 1]
//         } else {
//             n.next = nil
//         }
//     }
// }