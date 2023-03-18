package gap_buffer
import "core:unicode/utf8"
import "core:mem"
import "core:testing"

main :: proc() {
	test_chars(nil)
	test_slices(nil)
	test_utf8(nil)
}

BufferPosition :: int // index offsets
GapBuffer :: struct {
	buf:       []u8,
	gap_start: BufferPosition,
	gap_end:   BufferPosition,
}

make_gap_buffer :: proc(n_bytes: int, allocator := context.allocator) -> GapBuffer {
	b := GapBuffer{}
	b.buf = make([]u8, n_bytes)
	b.gap_end = BufferPosition(n_bytes)
	return b
}

insert :: proc {
	insert_rune,
	insert_slice,
	insert_string,
	insert_character,
}

insert_rune :: proc(b: ^GapBuffer, p: BufferPosition, r: rune) {
	bytes, len := utf8.encode_rune(r)
	insert_slice(b, p, bytes[:len])
}
insert_string :: #force_inline proc(b: ^GapBuffer, p: BufferPosition, s: string) {
	insert_slice(b, p, transmute([]u8)s)
}
insert_slice :: proc(b: ^GapBuffer, p: BufferPosition, chars: []u8) {
	slice_len := len(chars)
	check_gap_size(b, slice_len)
	shift_gap_to(b, p)
	gap_len := b.gap_end - b.gap_start
	gap := transmute([^]u8)&b.buf[b.gap_start]
	copy_slice(gap[:gap_len], chars)
	b.gap_start += slice_len
}
insert_character :: proc(b: ^GapBuffer, p: BufferPosition, char: u8) {
	check_gap_size(b, 1)
	shift_gap_to(b, p)
	b.buf[b.gap_start] = char
	b.gap_start += 1
}

copy_line_from_buffer :: proc(
	dest: [^]u8,
	max_width: int,
	b: ^GapBuffer,
	start_pos: BufferPosition,
) -> (
	n_copied: int,
	wrote_to: BufferPosition,
) {
	p := start_pos == b.gap_start ? b.gap_end : start_pos
	n_copied = 0
	blen := len(b.buf)
	for i := 0; i < max_width; i += 1 {
		if p == b.gap_start {p += b.gap_end - b.gap_start}
		if p == blen {break}
		c := b.buf[p]
		p += 1
		dest[i] = c
		n_copied += 1
		if c == '\n' {break} 	// write the newline??
	}
	return n_copied, p
}

shift_gap_to :: proc(b: ^GapBuffer, p: BufferPosition) {
	gap_len := b.gap_end - b.gap_start
	p := min(p, len(b.buf) - gap_len) // prevent referencing off the end of the buffer
	if b.gap_start == p {return}

	if b.gap_start < p {
		//   v~~~~v
		//[12]           [3456789abc]
		//--------|------------------ Gap is BEFORE Cursor
		//[123456]           [789abc]
		delta := p - b.gap_start
		mem.copy(&b.buf[b.gap_start], &b.buf[b.gap_end], delta)
		b.gap_start += delta
		b.gap_end += delta
	} else if b.gap_start > p {
		//   v~~~v
		//[123456]           [789abc]
		//---|----------------------- Gap is AFTER Cursor
		//[12]           [3456789abc]
		delta := b.gap_start - p
		mem.copy(&b.buf[b.gap_end - delta], &b.buf[b.gap_start - delta], delta)
		b.gap_start -= delta
		b.gap_end -= delta
	}
}
check_gap_size :: proc(b: ^GapBuffer, n_bytes_req: int, allocator := context.allocator) {
	gap_len := b.gap_end - b.gap_start
	if gap_len < n_bytes_req {
		shift_gap_to(b, len(b.buf) - gap_len)
		new_buf := make([]u8, 2 * len(b.buf)) // TODO: re-allocate HeapRealloc() ?
		copy_slice(new_buf, b.buf[:])
		delete(b.buf)
		b.buf = new_buf
		b.gap_end = len(b.buf)
	}
}

import "core:fmt"
@(test)
test_chars :: proc(t: ^testing.T) {
	gb := make_gap_buffer(2)
	insert_character(&gb, 0, 'D') // from start
	insert_character(&gb, 0, 'C')
	insert_character(&gb, 0, 'B')
	insert_character(&gb, 0, 'A')
	insert_character(&gb, 3, '3') // in middle
	insert_character(&gb, 3, '2')
	insert_character(&gb, 3, '1')
	insert_character(&gb, 7, 'E') // at tail
	insert_character(&gb, 8, 'F')

	line := make([]u8, 9)
	n, p := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text := string(line)

	assert(text == "ABC123DEF", "expected strings to match")
	assert(n == 9, "expected 9 chars copied")
	assert(p == 9, "expeceted buffer-position after line of text")
}
@(test)
test_slices :: proc(t: ^testing.T) {
	gb := make_gap_buffer(2)
	insert_slice(&gb, 0, transmute([]u8)string("ABCD")) // from start
	insert_string(&gb, 3, "123") // from start
	insert_slice(&gb, 7, transmute([]u8)string("EF")) // from start

	line := make([]u8, 9)
	n, p := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text := string(line)

	assert(text == "ABC123DEF", "expected strings to match")
	assert(n == 9, "expected 9 chars copied")
	assert(p == 9, "expeceted buffer-position after line of text")
}
@(test)
test_utf8 :: proc(t: ^testing.T) {
	gb := make_gap_buffer(2)
	insert_slice(&gb, 0, transmute([]u8)string("ABCD")) // from start
	insert_rune(&gb, 3, '涼') // from start
	insert_slice(&gb, 7, transmute([]u8)string("EF")) // from start

	line := make([]u8, 9)
	n, p := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text := string(line)
	// fmt.println(gb.buf)
	// fmt.println(text)

	assert(text == "ABC涼DEF", "expected strings to match")
	assert(n == 9, "expected 9 chars copied")
	assert(p == 9, "expeceted buffer-position after line of text")
}
