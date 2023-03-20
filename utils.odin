package gleipnir
//
import "core:fmt"
import "core:strings"

//
invalid_code_path :: proc(p: string) {
	if true {panic(fmt.tprintf("Invalid Code Path - %v", p))}
}
//
print_rope :: proc(rope: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	sb := strings.builder_make_len_cap(0, 2 * rope.head.(Branch).weight)
	defer delete(sb.buf)
	print_node :: proc(node: ^Node, buf: ^strings.Builder) {
		TRACE(&spall_ctx, &spall_buffer, #procedure)
		if node == nil {return}
		switch n in node {
		case (Branch):
			print_node(n.left, buf)
			print_node(n.right, buf)
		case (Leaf):
			strings.write_string(buf, "(")
			strings.write_string(buf, n)
			strings.write_string(buf, ")")
		}
	}
	print_node(rope.head, &sb)
	str := strings.to_string(sb)
	print_to_console :: proc(str: string) {
		TRACE(&spall_ctx, &spall_buffer, #procedure)
		fmt.println(str)
	}
	print_to_console(str)
}
// for remaining > 0 && ok {
// 	next_node, ok = next_leaf(&it)
// 	next_trace = it.trace[len(it.trace) - 1]
// 	//
// 	#partial switch n in current_node {

// 	case (Leaf):
// 		local_start := current // zero after first iter
// 		local_end := min(end - cursor, len(n))
// 		remaining -= local_end - local_start
// 		//
// 		parent := it.trace[len(it.trace) - 2] // Leaf must be under a branch .. cannot be out of bounds
// 		p_branch := (&parent.self.(Branch))

// 		if local_start == 0 && local_end == len(n) {
// 			// Whole leaf is deleted, remove the leaf from the tree
// 			if current_trace.is_left {
// 				old_left := p_branch.left
// 				fmt.printf("ol:%p\n", old_left)
// 				free(old_left)
// 				fmt.printf("olfree:%p\n", old_left)

// 				p_branch.left = p_branch.right
// 				p_branch.right = nil
// 			} else {
// 				fmt.printf("or:%p\n", p_branch.right)
// 				free(p_branch.right)
// 				fmt.printf("orfree:%p\n", p_branch.right)

// 				p_branch.right = nil
// 			}
// 			// // If the concat node has a grandparent, remove it
// 			// // todo: test if this slows us down or not
// 			// if len(it.trace) > 2 {
// 			// 	grandparent := it.trace[len(it.trace) - 3]
// 			// 	if gp, is_br := &grandparent.self.(Branch); is_br {
// 			// 		if parent.is_left {
// 			// 			gp.left = p_branch.left
// 			// 			free(parent.self)
// 			// 			ordered_remove(&it.trace, len(it.trace) - 2)
// 			// 		}
// 			// 	}
// 			// }
// 		} else if local_start == 0 {
// 			// Left part is deleted, update the leaf content
// 			current_node^ = strings.clone(n[local_end:])
// 		} else if local_end == len(n) {
// 			// Right part is deleted, update the leaf content
// 			current_node^ = strings.clone(n[:local_start])
// 		} else {
// 			// Middle part is deleted, split the leaf into two
// 			left := new(Node)
// 			left^ = strings.clone(n[:local_start])
// 			right := new(Node)
// 			right^ = strings.clone(n[local_end:])
// 			new_branch := concat(left, right)
// 			if current_trace.is_left {
// 				p_branch.left = new_branch
// 			} else {
// 				p_branch.right = new_branch
// 			}
// 		}
// 	}
// 	current_node = next_node
// 	current_trace = next_trace
// 	if !ok {break}
// 	current = 0 // need actual value for first iter of loop and then not after
// }
