#!/bin/sh
# Compiles and runs a one-line Odin program: proves the installed compiler can link, which
# `odin version` does not, since linking is clang's part.
set -eu
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cat >"$dir/main.odin" <<'ODIN'
package main

import "core:fmt"

main :: proc() {
	fmt.println("hello from odin")
}
ODIN
out=$(odin run "$dir" -out:"$dir/hello")
[ "$out" = "hello from odin" ] || {
	echo "hello.sh: the program printed: $out" >&2
	exit 1
}
echo "hello.sh: compiled, linked and ran"
