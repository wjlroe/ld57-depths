package main

import "core:log"
import "core:os"

fail :: proc(error: string, loc := #caller_location) {
	args := []any{error}
	log.error(args = args, location = loc)
	assert(condition = false, message = error, loc = loc)
}

die :: proc(error: string, loc := #caller_location) {
	assert(condition = false, message = error, loc = loc)
	args := []any{error}
	log.error(args = args, location = loc)
	os.exit(1)
}
