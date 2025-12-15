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

    fmt.println("video size:", width, ",", height)
    fmt.println("video frame count:", frame_count)
    fmt.println("video fps:", fps)

    window_width := 640
    window_height := 480

    raylib.InitWindow(i32(window_width), i32(window_height), "GV Video Viewer")
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(i32(fps))

    frame_index := 0
    for !raylib.WindowShouldClose() {
        frame, err2 := gv.read_frame(video, u32(frame_index))
        if err2 != nil {
            raylib.TraceLog(.ERROR, "Failed to read frame")
            break
        }

        // RGBA8 → raylib.Image
        img := raylib.GenImageColor(i32(width), i32(height), raylib.BLANK)
        defer raylib.UnloadImage(img)
        raylib.ImageFormat(&img, .UNCOMPRESSED_R8G8B8A8)
        mem.copy(img.data, raw_data(frame), width * height * 4)
        tex := raylib.LoadTextureFromImage(img)
        defer raylib.UnloadTexture(tex)

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
        raylib.EndDrawing()

        frame_index = (frame_index + 1) % frame_count
        time.sleep(time.Duration(f32(time.Second) / f32(fps)))
    }
}