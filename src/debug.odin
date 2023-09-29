package main

import "core:log"

Debug_System :: struct {
	values: map[string]string,
	print_changing_values: bool,
}

_debug_system : ^Debug_System

init_debug_system :: proc(print_values: bool) {
	_debug_system = new(Debug_System)
	_debug_system.print_changing_values = print_values
}

uninit_debug_system :: proc() {
	delete(_debug_system.values)
}

// key,value are the debug key+value, annotation is printed when value changes
debug_only_once :: proc(key, value, annotation: string, location := #caller_location) {
	if !_debug_system.print_changing_values {
		return
	}
	prev_value, ok := _debug_system.values[key]
	if !ok {
		log.debugf("key = {} missing", key)
	}
	if ok && (prev_value == value) {
		return
	}
	if ok && (prev_value != value) {
		log.debugf("value for key {} changed", key)
	}
	args := []any{annotation, key, value}
	log.debugf(fmt_str="[{}], {} => {}", args=args, location=location)
	_debug_system.values[key] = value
}
