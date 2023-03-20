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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	sb := strings.builder_make_len_cap(0, 2 * rope.head.(Branch).weight)
	print_node :: proc(node: ^Node, buf: ^strings.Builder) {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
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
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
		fmt.println(str)
	}
	print_to_console(str)
	delete(sb.buf)
}
