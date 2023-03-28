package gleipnir
//
import "core:fmt"
import "core:strings"

//
invalid_code_path :: proc(p: string) {
	if true {fmt.panicf("Invalid Code Path - %v", p)}
}
unreachable :: proc(p: string) {
	if true {fmt.panicf("Unreachable Code Path - %v", p)}
}
not_implemented :: proc(p: string) {
	if true {fmt.panicf("Not Implemented - %v", p)}
}
//
print_node :: proc(node: ^Node) {
	if _, ok := node.kind.(Branch); ok {
		print_rope(&Rope{node})
	} else {
		fmt.println("Leaf:", node.kind.(Leaf))
	}
}
print_rope :: proc(rope: ^Rope) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	sb := strings.builder_make_len_cap(0, 2 * rope.head.kind.(Branch).weight)
	defer delete(sb.buf)
	print_node :: proc(node: ^Node, buf: ^strings.Builder) {
		TRACE(&spall_ctx, &spall_buffer, #procedure)
		if node == nil {return}
		switch n in node.kind {
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
to_string :: proc(rope: ^Rope, allocator := context.allocator) -> string {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	sb := strings.builder_make_len_cap(0, 2 * rope.head.kind.(Branch).weight, allocator)
	defer delete(sb.buf)
	node_to_string :: proc(node: ^Node, buf: ^strings.Builder) {
		TRACE(&spall_ctx, &spall_buffer, #procedure)
		if node == nil {return}
		switch n in node.kind {
		case (Branch):
			node_to_string(n.left, buf)
			node_to_string(n.right, buf)
		case (Leaf):
			strings.write_string(buf, n)
		}
	}
	node_to_string(rope.head, &sb)
	str := strings.to_string(sb)
	return str
}
print_parent_ptrs :: proc(node: ^Node, prefix: string = "") {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if len(prefix) > 0 {
		fmt.print(prefix, ":: ")
	}
	pptr :: proc(node: ^Node) {
		if node == nil {
			fmt.print("<nil>")
			return
		}
		switch n in node.kind {
		case (Branch):
			if node.parent != nil {
				fmt.printf("<<<%p>>>[%p](", node, node.parent)
			} else {
				fmt.printf("[--](")
			}
			pptr(n.left)
			fmt.print(",")
			pptr(n.right)
			fmt.print(")")
		case (Leaf):
			if node.parent != nil {
				fmt.printf("<<%p>>[%p]", node, node.parent)
			} else {
				fmt.printf("<-->")
			}
		}
	}
	pptr(node)
	fmt.println()
}
print_in_order :: proc(node: ^Node, prefix: string = "") {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if len(prefix) > 0 {
		fmt.print(prefix, ":: ")
	}
	pio :: proc(node: ^Node) {
		if node == nil {
			fmt.print("<nil>")
			return
		}
		switch n in node.kind {
		case (Branch):
			fmt.printf("[%v](", n.weight)
			pio(n.left)
			fmt.print(",")
			pio(n.right)
			fmt.print(")")
		case (Leaf):
			fmt.print(n)
		}
	}
	pio(node)
	fmt.println()
}
get_height_iterative :: proc(node: ^Node) -> int {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {return 0}

	stack := make([dynamic]^Node)
	defer delete(stack)
	append(&stack, node)
	height := 0
	current: ^Node
	for len(stack) > 0 {
		size := len(stack)
		for size > 0 {
			front := pop_front(&stack)
			if br, ok := &front.kind.(Branch); ok {
				if br.left != nil {append(&stack, br.left)}
				if br.right != nil {append(&stack, br.right)}
			}
			height += 1
			size -= 1
		}

	}

	return height
}
assert_parentage :: proc(rope: ^Rope) {
	if rope == nil {return}
	assert(rope.head.parent == nil)
	switch n in rope.head.kind {
	case (Branch):
		assert_node_parentage(n.left, rope.head)
		assert_node_parentage(n.right, rope.head)
	case (Leaf):
		assert_node_parentage(rope.head, nil)
	}
}
assert_node_parentage :: proc(node: ^Node, parent: ^Node) {
	if node == nil {return}
	assert(node.parent == parent, "Parent Pointer Corruption")
	if parent != nil {assert(node.parent.kind != nil, "Parent Union Nil")}
	#partial switch n in node.kind {
	case (Branch):
		assert_node_parentage(n.left, node)
		assert_node_parentage(n.right, node)
	}
}
assert_weights :: proc(rope: ^Rope) {
	if rope == nil {return}
	#partial switch n in rope.head.kind {
	case (Branch):
		assert_node_weights(n.left)
		assert_node_weights(n.right)
	}
}
assert_node_weights :: proc(node: ^Node) {
	if node == nil {return}
	#partial switch n in node.kind {
	case (Branch):
		expected_weight := get_weight(n.left, true)
		if expected_weight != n.weight {
			fmt.printf("Expected:%v, Got:%v\n", expected_weight, n.weight)
			print_in_order(node, "Failed_Node::Assert_Weight")
			panic("Bad Weight")
		}
		assert_node_parentage(n.left, node)
		assert_node_parentage(n.right, node)
	}
}
