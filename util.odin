package gv

import "core:os"

@(private)
read_le_u64 :: proc(f: File) -> (u64, os.Error) {
    // TODO: implement
    return u64(0), nil
}

@(private)
read_le_u32 :: proc(f: File) -> (u32, os.Error) {
    // TODO: implement
    return u32(0), nil
}

@(private)
read_le_f32 :: proc(f: File) -> (f32, os.Error) {
    // TODO: implement
    return f32(0), nil
}

@(private)

read_bytes_at :: proc(f: File, size: int, offset: u64) -> ([]u8, os.Error) {
    // TODO: implement
    return {}, nil
}