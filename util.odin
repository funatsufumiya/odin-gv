package gv

import "core:os"
import "core:math"

@(private)
read_le_u64 :: proc(f: File) -> (u64, os.Error) {
    buf: [8]u8
    n, err := os.read(f, buf[:])
    if err != nil {
        return 0, err
    }
    if n != 8 {
        return 0, .EOF
    }
    // Little-endian
    return u64(buf[0]) |
           (u64(buf[1]) << 8) |
           (u64(buf[2]) << 16) |
           (u64(buf[3]) << 24) |
           (u64(buf[4]) << 32) |
           (u64(buf[5]) << 40) |
           (u64(buf[6]) << 48) |
           (u64(buf[7]) << 56), nil
}

@(private)
read_le_u32 :: proc(f: File) -> (u32, os.Error) {
    buf: [4]u8
    n, err := os.read(f, buf[:])
    if err != nil {
        return 0, err
    }
    if n != 4 {
        return 0, .EOF
    }
    return u32(buf[0]) |
           (u32(buf[1]) << 8) |
           (u32(buf[2]) << 16) |
           (u32(buf[3]) << 24), nil
}

@(private)
read_le_f32 :: proc(f: File) -> (f32, os.Error) {
    u, err := read_le_u32(f)
    if err != nil {
        return 0, err
    }
    
    return transmute(f32)u, nil
}

@(private)
read_bytes_at :: proc(f: File, size: int, offset: u64, allocator := context.allocator) -> ([]u8, os.Error) {
    old_pos, err := os.seek(f, 0, FILE_CURRENT)
    if err != nil {
        return {}, err
    }
    _, err = os.seek(f, i64(offset), FILE_BEGIN)
    if err != nil {
        return {}, err
    }
    buf := make([]u8, size, allocator)
    n: int
    n, err = os.read(f, buf)
    if err != nil {
        return {}, err
    }
    _, err = os.seek(f, old_pos, FILE_BEGIN)
    if err != nil {
        return {}, err
    }
    if n != size {
        return {}, .EOF
    }
    return buf, nil
}