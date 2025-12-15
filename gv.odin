package gv

import "core:os"
import dxt_decoder "./dxt_decoder"
import "vendor:compress/lz4"

gv_format_dxt1 :: 1
gv_format_dxt3 :: 3
gv_format_dxt5 :: 5

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
    format      : u32,
    frame_bytes : u32,
}

GVAddressSizeBlock :: struct {
    address : u64,
    size    : u64,
}

GVVideo :: struct {
    header              : GVHeader,
    address_size_blocks : []GVAddressSizeBlock,
    file                : os.File,
}

// Read header from file
// returns error at last paramter
read_header :: proc(f: os.File) -> (GVHeader, bool) {
    header := GVHeader{}
    header.width = f.read_le[u32]()
    header.height = f.read_le[u32]()
    header.frame_count = f.read_le[u32]()
    header.fps = f.read_le[f32]()
    header.format = f.read_le[u32]()
    header.frame_bytes = f.read_le[u32]()
    return header
}

// Read address/size blocks from file
// returns error at last paramter
read_address_size_blocks :: proc(f: os.File, frame_count: u32) -> ([]GVAddressSizeBlock, bool) {
    blocks_len := int(frame_count)
    blocks := [blocks_len]GVAddressSizeBlock{}
    f.seek(-i64(frame_count * 16), .end)
    for i in 0..<int(frame_count) {
        blocks[i].address = f.read_le[u64]()
        blocks[i].size = f.read_le[u64]()
    }
    return blocks
}

// Load GVVideo from file path
// returns error at last paramter
load_gvvideo :: proc(path: string) -> (GVVideo, bool) {
    f := os.open(path)
    header := read_header(f)
    blocks := read_address_size_blocks(f, header.frame_count)
    f.seek(0, .start)
    return GVVideo{
        header =              header,
        address_size_blocks = blocks,
        file =                f
    }
}

// Read compressed frame (LZ4 decompress only, no DXT decode)
// returns error at last paramter
read_frame_compressed :: proc(v: GVVideo, frame_id: u32) -> ([]u8, ReadFrameError) {
    buf_len := int(v.header.frame_bytes)
    buf : [buf_len]u8
    buf = {}
    err = read_frame_compressed_to(v, frame_id, buf)
    if err != nil {
        return {}, err
    }
    return buf, nil
}

// Read compressed frame to buffer (LZ4 decompress only, no DXT decode)
// returns error at last paramter
read_frame_compressed_to :: proc(v: GVVideo, frame_id: u32, buf: []u8) -> ReadFrameError {
    if frame_id >= v.header.frame_count {
        return .END_OF_VIDEO
    }
    block := v.address_size_blocks[frame_id]
    compressed := v.file.read_bytes_at(int(block.size), block.address)
    uncompressed_size := int(v.header.frame_bytes)
    if buf.len < uncompressed_size {
        return .BUFFER_TOO_SMALL
    }
    decompressed_size := lz4.lz_4_decompress_safe(&u8(compressed.data), &u8(buf.data),
        compressed.len, uncompressed_size)
    if decompressed_size < 0 {
        return .LZ4_DECOMPRESS_FAILED
    }

    return nil
}

// Read and decode frame to RGBA buffer
// returns error at last paramter
read_frame_to :: proc(v: GVVideo, frame_id: u32, buf: []u8) -> ReadFrameError {
    if frame_id >= v.header.frame_count {
        return .END_OF_VIDEO
    }
    block := v.address_size_blocks[frame_id]
    compressed := v.file.read_bytes_at(int(block.size), block.address)
    width := int(v.header.width)
    height := int(v.header.height)
    uncompressed_size := int(v.header.frame_bytes)
    decompressed : [uncompressed_size]u8
    decompressed = {}
    decompressed_size := lz4.lz_4_decompress_safe(&u8(compressed.data), &u8(decompressed.data),
        compressed.len, uncompressed_size)
    if decompressed_size < 0 {
        return .LZ4_DECOMPRESS_FAILED
    }
    // DXT decode
    dxt_format := dxt_decoder.DxtFormat.DXT1
    if v.header.format == gv_format_dxt3 {
        dxt_format = .DXT3
    } else if v.header.format == gv_format_dxt5 {
        dxt_format = .DXT5
    }
    decoded := dxt_decoder.decode(decompressed[0:uncompressed_size], width, height, dxt_format)
    if buf.len < decoded.len {
        return .BUFFER_TOO_SMALL
    }
    for i in 0..<decoded.len {
        buf[i] = decoded[i]
    }

    return nil
}

// Read and decode frame, return RGBA []u8
// returns error at last paramter
read_frame :: proc(v: GVVideo, frame_id: u32) -> ([]u8, ReadFrameError) {
    width := int(v.header.width)
    height := int(v.header.height)
    buf_len := width * height * 4
    buf : [buf_len]u8
    buf = {}
    err = read_frame_to(v, frame_id, buf)
    if err != nil {
        return {}, err
    }
    return buf, nil
}
