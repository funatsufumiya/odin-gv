package tests

import gv ".."

import "core:fmt"
import "core:testing"

@(private)
almost_equal :: proc(a: u8, b: u8) -> bool {
    d := int(a) - int(b)
    if d < 0 {
        d = -d
    }
    return d <= 8
}

@(private)
assert_rgba :: proc(t: ^testing.T, got: []u8, want_r, want_g, want_b, want_a: u8, msg: string) {
    testing.expect(t, almost_equal(got[0], want_r), fmt.tprint(msg, ": R mismatch (got ", got[0], ", expected ", want_r, ")"))
    testing.expect(t, almost_equal(got[1], want_g), fmt.tprint(msg, ": G mismatch (got ", got[1], ", expected ", want_g, ")"))
    testing.expect(t, almost_equal(got[2], want_b), fmt.tprint(msg, ": B mismatch (got ", got[2], ", expected ", want_b, ")"))
    testing.expect(t, almost_equal(got[3], want_a), fmt.tprint(msg, ": A mismatch (got ", got[3], ", expected ", want_a, ")"))
}

@(test)
test_gvvideo_read_header :: proc(t: ^testing.T) {
    gv_path := "test_asset/test-10px.gv"
    video, err := gv.load_gvvideo(gv_path)
    testing.expect_value(t, err, nil)
    w := int(video.header.width)
    h := int(video.header.height)
    testing.expect_value(t, w, 10)
    testing.expect_value(t, h, 10)
    testing.expect_value(t, video.header.frame_count, 5)
    testing.expect_value(t, video.header.fps, 1.0)
    testing.expect_value(t, video.header.format, gv.gv_format_dxt1)
    testing.expect_value(t, video.header.frame_bytes, 72)
}

@(test)
test_gvvideo_read_frame :: proc(t: ^testing.T) {
    gv_path := "test_asset/test-10px.gv"
    video, err := gv.load_gvvideo(gv_path)
    testing.expect_value(t, err, nil)
    w := int(video.header.width)
    h := int(video.header.height)
    testing.expect_value(t, w, 10)
    testing.expect_value(t, h, 10)
    testing.expect_value(t, video.header.frame_count, 5)
    testing.expect_value(t, video.header.fps, 1.0)
    testing.expect_value(t, video.header.format, gv.gv_format_dxt1)
    testing.expect_value(t, video.header.frame_bytes, 72)

    frame, err2 := gv.read_frame(video, 3)
    testing.expect_value(t, err2, nil)
    testing.expect_value(t, len(frame), w * h * 4)

    assert_rgba(t, frame[0:4], 255, 0, 0, 255, "(0,0) should be red")
    assert_rgba(t, frame[6*4:6*4+4], 0, 0, 255, 255, "(6,0) should be blue")
    assert_rgba(t, frame[(0+w*6)*4:(0+w*6)*4+4], 0, 255, 0, 255, "(0,6) should be green")
    assert_rgba(t, frame[(6+w*6)*4:(6+w*6)*4+4], 231, 255, 0, 255, "(6,6) should be yellow (allow error)")
}

@(test)
test_gvvideo_read_frame_at :: proc(t: ^testing.T) {
    gv_path := "test_asset/test-10px.gv"
    video, err := gv.load_gvvideo(gv_path)
    testing.expect_value(t, err, nil)
    frame, err2 := gv.read_frame(video, 0)
    testing.expect_value(t, err2, nil)

    assert_rgba(t, frame[0:4], 255, 0, 0, 255, "(0,0) should be red")
}