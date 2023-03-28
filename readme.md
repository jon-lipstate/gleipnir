## Gleipnir: Odin Rope Data Structure Library

This library provides a rope data structure implementation in the Odin programming language. A rope is a data structure that is used to efficiently store and manipulate very long strings.

## Installation

Odin Compiler: [Odin](https://odin-lang.org/)

Clone this repository and place `gleipnir.odin` and `utils.odin` in `vendor/gleipnir`. (The other files are inmaterial to the rope's operation).

## Usage

```odin
main :: proc() {
	rope := &Rope{}
	insert_text(rope, 0, "Ropes")
	insert_text(rope, 5, "Are")
	insert_text(rope, 8, "Easy")
	insert_text(rope, 12, "Peasy")
	//
	insert_text(rope, 8, "_NOT_")

	delete_text(rope, 2, 12)

	insert_text(rope, 2, "pes")
	insert_text(rope, 5, "Are")

	insert_text(rope, 8, "E")
	insert_text(rope, 8, "_NOT_")

	delete_text(rope, 13, 1)
	insert_text(rope, 13, "E")

	print_in_order(rope.head, "Final Rope") // Final Rope :: [8]([5]([2](Ro,pes),Are),[6]([5](_NOT_,E),[3](asy,Peasy)))
	fmt.println(to_string(rope)) // RopesAre_NOT_EasyPeasy
}
```

## API

The following calls are intended for public use:
- `insert_text`: inserts text at a given position. cursors in excess of the ropes length will append to the end. `cursor=-1` will shortcut/fast append.
- `delete_text`
- `find`: gets a character at a given cursor position
- `to_string`: transforms the entire rope into a string

## Contributing

If you find any bugs or have any suggestions, please open an issue or a pull request in the GitHub repository.

### TODOs:

- At present, both simplification and performance acceleration are the prime interests.
- Additional APIs such as to_string for a range need produced as well.
- Test recursive vs stack based calls to accelerate node ops
- Reduce calls to rebalance (maybe h>2 as criteria?)
- Preallocated nodes + freelist on the rope
- Split should not allocate a rope, pass by value
- UTF-8 Cursor Traversal (Likely leaf should stash rune-count to help read-heavy ops)

## License

This library is licensed under the MIT license.