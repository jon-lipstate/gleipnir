package gleipnir
//
import "core:fmt"
import "core:strings"

//
invalid_code_path :: proc(p: string) {
	if true {panic(fmt.tprintf("Invalid Code Path - %v", p))}
}
//
print_node :: proc(node: ^Node) {
	if _, ok := node.(Branch); ok {
		print_rope(&Rope{node})
	} else {
		fmt.println(node.(Leaf))
	}
}
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

print_in_order :: proc(node: ^Node) {
	TRACE(&spall_ctx, &spall_buffer, #procedure)
	if node == nil {
		fmt.print("<nil>")
		return
	}
	switch n in node {
	case (Branch):
		fmt.print("(")
		print_in_order(n.left)
		fmt.print(",")
		print_in_order(n.right)
		fmt.print(")")
	case (Leaf):
		fmt.print(n)
	}
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
			if br, ok := &front.(Branch); ok {
				if br.left != nil {append(&stack, br.left)}
				if br.right != nil {append(&stack, br.right)}
			}
			height += 1
			size -= 1
		}

	}

	return height
}
