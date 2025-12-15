package main

import gv ".."

import "vendor:raylib"
import "core:time"
import "core:mem"
import "core:math"
import "core:fmt"

import example_util "./example_util"

main :: proc() {
    example_util.debug_tracking_allocator_init()
    
    // gv_path := "test_asset/test-10px.gv"
    gv_path := "gv_asset_for_test/alpha-countdown-blue.gv"
    video, err := gv.load_gvvideo(gv_path)
    defer gv.delete_gvvideo(&video)
    if err != nil {
        raylib.TraceLog(.ERROR, "Failed to load GV video")
        return
    }

    width := int(video.header.width)
    height := int(video.header.height)
    frame_count := int(video.header.frame_count)
    fps := int(video.header.fps)
    format := video.header.format

    fmt.println("video size:", width, ",", height)
    fmt.println("video frame count:", frame_count)
    fmt.println("video fps:", fps)
    fmt.println("video format:", format)

    window_width := 640
    window_height := 480

    raylib.SetTraceLogLevel(.WARNING)

    raylib.InitWindow(i32(window_width), i32(window_height), "GV Video Viewer")
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(i32(fps))
    raylib.SetExitKey(.ESCAPE)

    frame_index := 0
    frame, err2 := gv.read_frame_compressed(video, u32(frame_index))
    defer delete(frame)

    pix_format : raylib.PixelFormat = .COMPRESSED_DXT1_RGBA
    switch format {
    case .DXT1:
        pix_format = .COMPRESSED_DXT1_RGBA
    case .DXT3:
        pix_format = .COMPRESSED_DXT3_RGBA
    case .DXT5:
        pix_format = .COMPRESSED_DXT5_RGBA
    }

    img := raylib.Image{
        data = raw_data(frame),
        width = i32(width),
        height = i32(height),
        mipmaps = 1,
        format = pix_format
    }
    // commented out to suppress crash after exit
    // defer {
    //     if raylib.IsImageValid(img) && raylib.IsImageReady(img) {
    //         raylib.UnloadImage(img)
    //     }
    // }

    tex := raylib.LoadTextureFromImage(img)
    defer {
        if raylib.IsTextureValid(tex) && raylib.IsTextureReady(tex) {
            raylib.UnloadTexture(tex)
        }
    }

    for !raylib.WindowShouldClose() {
        // t1 := time.now()

        if frame_index > 0 {
            err2 = gv.read_frame_compressed_to(video, u32(frame_index), frame)
            if err2 != nil {
                raylib.TraceLog(.ERROR, "Failed to read frame")
                break
            }
            img.data = raw_data(frame)
            raylib.UnloadTexture(tex)
            tex = raylib.LoadTextureFromImage(img)
        }
        
        // t2 := time.now()
        // diff := time.diff(t1, t2)
        // fmt.println("read_frame elapsed sec:", time.duration_seconds(diff))

        scale_x := f32(window_width) / f32(width)
        scale_y := f32(window_height) / f32(height)
        scale := math.min(scale_x, scale_y)
        tex_width := int(f32(width) * scale)
        tex_height := int(f32(height) * scale)
        pos_x := (window_width - tex_width) / 2
        pos_y := (window_height - tex_height) / 2

        raylib.BeginDrawing()
        raylib.ClearBackground(raylib.RAYWHITE)
        raylib.DrawTextureEx(
            tex,
            raylib.Vector2{f32(pos_x), f32(pos_y)},
            0.0,
            scale,
            raylib.WHITE,
        )
        raylib.DrawFPS(10, 10)
        raylib.EndDrawing()

        frame_index = (frame_index + 1) % frame_count
    }
}