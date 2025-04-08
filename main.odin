package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"
import "core:strings"

main :: proc() {
    a := allocator(&kv)
    context.allocator = a
    
    stdin_reader := os.stream_from_handle(os.stdin);
    
    scanner: bufio.Scanner;
    bufio.scanner_init(&scanner, stdin_reader);
    
    fmt.print("> ");
    loop: for bufio.scanner_scan(&scanner) {
        line := bufio.scanner_text(&scanner);
        parts := strings.split(line, " ")
        switch strings.to_lower(parts[0]) {
        case "get":
            fmt.println(get(blob_from_string(parts[1])))
        case "put":
            put(blob_from_string(parts[1]), blob_from_string(parts[2]))
        case "del":
            remove(blob_from_string(parts[1]))
        case "quit":
            break loop
        }
        fmt.print("> ");
        
        if err := bufio.scanner_error(&scanner); err != nil {
            fmt.eprintln("Error reading input:", err);
        }
    }
    fmt.println(mem.ptr_to_bytes(kv.base, int(kv.size)))
    fmt.println(kv.size)
}

blob_from_string :: proc(s: string) -> Blob {
    return {
        offset = u32(mem.ptr_sub(cast(^u8)raw_data(s), kv.base)),
        size = u32(len(s))
    }
}