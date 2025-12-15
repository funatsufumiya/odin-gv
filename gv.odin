package gv

import "core:os"
import "core:fmt"
import "core:time"
import dxt_decoder "./dxt_decoder"
import lz4 "./lz4/lz4"

// gv_format_dxt1 :: 1
// gv_format_dxt3 :: 3
// gv_format_dxt5 :: 5

GVTextureFormat :: enum {
    DXT1 = 1,
    DXT3 = 3,
    DXT5 = 5,
}

File :: #type os.Handle

FILE_BEGIN :: 0
FILE_CURRENT :: 1
FILE_END :: 2

ReadFrameDxtOsError :: union {
    ReadFrameError,
    dxt_decoder.DxtDecodeError,
    os.Error
}

ReadFrameError :: enum {
    OK,
    END_OF_VIDEO,
    LZ4_DECOMPRESS_FAILED,
    BUFFER_TOO_SMALL,
}

GVHeader :: struct {
    width       : u32,
    height      : u32,
    frame_count : u32,
    fps         : f32,
    format      : GVTextureFormat,
    frame_bytes : u32,
}

GVAddressSizeBlock :: struct {
    address : u64,
    size    : u64,
}

GVVideo :: struct {
    header              : GVHeader,
    address_size_blocks : []GVAddressSizeBlock,
    file                : File,
}

delete_gvvideo :: proc(v: ^GVVideo) {
    delete(v.address_size_blocks)
    err := os.close(v.file)
    if err != nil {
        fmt.eprintln("[Error] delete_gvvideo: ", err)

        // just show error and ignore it now
    }
}

// Read header from file
// returns error at last paramter
read_header :: proc(f: File) -> (GVHeader, os.Error) {
    header := GVHeader{}
    err : os.Error = nil
    header.width, err = read_le_u32(f)
    if err != nil { return {}, err }
    header.height, err = read_le_u32(f)
    if err != nil { return {}, err }
    header.frame_count, err = read_le_u32(f)
    if err != nil { return {}, err }
    header.fps, err = read_le_f32(f)
    if err != nil { return {}, err }
    raw_format : u32
    raw_format, err = read_le_u32(f)
    if err != nil { return {}, err }
    header.format = GVTextureFormat(raw_format)
    header.frame_bytes, err = read_le_u32(f)
    if err != nil { return {}, err }
    return header, nil
}

// Read address/size blocks from file
// returns error at last paramter
read_address_size_blocks :: proc(f: File, frame_count: u32, allocator := context.allocator) -> ([]GVAddressSizeBlock, os.Error) {
    blocks_len := int(frame_count)
    blocks := make([]GVAddressSizeBlock, blocks_len, allocator)
    _, err := os.seek(f, -i64(frame_count * 16), FILE_END)
    if err != nil {
        return {}, err
    }
    for i in 0..<int(frame_count) {
        err2 : os.Error = nil
        blocks[i].address, err2 = read_le_u64(f)
        if err2 != nil { return {}, err2 }
        blocks[i].size, err2 = read_le_u64(f)
        if err2 != nil { return {}, err2 }
    }
    return blocks, nil
}

// Load GVVideo from file path
// returns error at last paramter
load_gvvideo :: proc(path: string, allocator := context.allocator) -> (GVVideo, os.Error) {
    f, err1 := os.open(path)
    if err1 != nil {
        return {}, err1
    }
    header, err2 := read_header(f)
    if err2 != nil {
        return {}, err2
    }
    blocks, err3 := read_address_size_blocks(f, header.frame_count, allocator)
    if err3 != nil {
        return {}, err3
    }
    _, err4 := os.seek(f, 0, FILE_BEGIN)
    if err4 != nil {
        return {}, err4
    }

    return GVVideo{
        header =              header,
        address_size_blocks = blocks,
        file =                f
    }, nil
}

// Read compressed frame (LZ4 decompress only, no DXT decode)
// returns error at last paramter
read_frame_compressed :: proc(v: GVVideo, frame_id: u32, allocator := context.allocator) -> ([]u8, ReadFrameDxtOsError) {
    buf_len := int(v.header.frame_bytes)
    buf := make([]u8, buf_len, allocator)
    err := read_frame_compressed_to(v, frame_id, buf)
    if err != nil {
        return {}, err
    }
    return buf, nil
}

// Read compressed frame to buffer (LZ4 decompress only, no DXT decode)
// returns error at last paramter
read_frame_compressed_to :: proc(v: GVVideo, frame_id: u32, buf: []u8) -> ReadFrameDxtOsError {
    if frame_id >= v.header.frame_count {
        return .END_OF_VIDEO
    }
    block := v.address_size_blocks[frame_id]

    compressed, err := read_bytes_at(v.file, int(block.size), block.address)
    defer delete(compressed)

    if err != nil {
        return err
    }
    uncompressed_size := int(v.header.frame_bytes)
    if len(buf) < uncompressed_size {
        return .BUFFER_TOO_SMALL
    }
    decompressed_size := lz4.decompress_safe(raw_data(compressed), raw_data(buf),
        i32(len(compressed)), i32(uncompressed_size))
    if decompressed_size < 0 {
        return .LZ4_DECOMPRESS_FAILED
    }

    return nil
}

// Read and decode frame to RGBA buffer
// returns error at last paramter
read_frame_to :: proc(v: GVVideo, frame_id: u32, buf: []u8) -> ReadFrameDxtOsError {
    if frame_id >= v.header.frame_count {
        return .END_OF_VIDEO
    }

    block := v.address_size_blocks[frame_id]
    compressed, err := read_bytes_at(v.file, int(block.size), block.address)
    defer delete(compressed)

    if err != nil {
        return err
    }
    width := int(v.header.width)
    height := int(v.header.height)
    uncompressed_size := int(v.header.frame_bytes)
    decompressed := make([]u8, uncompressed_size)
    defer delete(decompressed)

    decompressed_size := lz4.decompress_safe(raw_data(compressed), raw_data(decompressed),
        i32(len(compressed)), i32(uncompressed_size))
    if decompressed_size < 0 {
        return .LZ4_DECOMPRESS_FAILED
    }

    // DXT decode
    dxt_format := dxt_decoder.DxtFormat.DXT1
    if v.header.format == .DXT3 {
        dxt_format = .DXT3
    } else if v.header.format == .DXT5 {
        dxt_format = .DXT5
    }

    decoded, err2 := dxt_decoder.decode(decompressed[0:uncompressed_size], width, height, dxt_format)
    defer delete(decoded)

    if err2 != nil {
        return err2
    }
    if len(buf) < len(decoded) {
        return .BUFFER_TOO_SMALL
    }
    for i in 0..<len(decoded) {
        buf[i] = decoded[i]
    }

    return nil
}

// Read and decode frame, return RGBA []u8
// returns error at last paramter
read_frame :: proc(v: GVVideo, frame_id: u32, allocator := context.allocator) -> ([]u8, ReadFrameDxtOsError) {
    width := int(v.header.width)
    height := int(v.header.height)
    buf_len := width * height * 4
    buf := make([]u8, buf_len, allocator)
    err := read_frame_to(v, frame_id, buf)
    if err != nil {
        return {}, err
    }
    return buf, nil
}
