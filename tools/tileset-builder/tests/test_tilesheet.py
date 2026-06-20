from PIL import Image
import sys, os, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from tilesheet import build_sheet, append_row, write_sidecar, read_sidecar, cmd_create, scale_frame
import pytest


def solid(color, w=8, h=8):
    return Image.new("RGBA", (w, h), color)


# --- build_sheet ---

def test_build_sheet_canvas_size_single_row():
    frames = [solid((255, 0, 0, 255)), solid((0, 255, 0, 255)), solid((0, 0, 255, 255))]
    sheet = build_sheet([frames], tile_w=8, tile_h=8)
    assert sheet.size == (3 * 8, 1 * 8)


def test_build_sheet_rectangular_tiles():
    frames = [solid((255, 0, 0, 255), w=16, h=8), solid((0, 255, 0, 255), w=16, h=8)]
    sheet = build_sheet([frames], tile_w=16, tile_h=8)
    assert sheet.size == (2 * 16, 1 * 8)


def test_build_sheet_transparent_pixels_preserved():
    frame = Image.new("RGBA", (8, 8), (255, 0, 0, 0))
    sheet = build_sheet([[frame]], tile_w=8, tile_h=8)
    assert sheet.getpixel((0, 0))[3] == 0


def test_build_sheet_unequal_rows_width_and_padding():
    row0 = [solid((255, 0, 0, 255)), solid((0, 255, 0, 255)), solid((0, 0, 255, 255))]
    row1 = [solid((255, 255, 0, 255))]
    sheet = build_sheet([row0, row1], tile_w=8, tile_h=8)
    assert sheet.size == (3 * 8, 2 * 8)
    assert sheet.getpixel((1 * 8, 1 * 8))[3] == 0


# --- append_row ---

def test_append_row_grows_height_same_width():
    sheet = build_sheet([[solid((255, 0, 0, 255)), solid((0, 255, 0, 255))]], tile_w=8, tile_h=8)
    assert sheet.size == (16, 8)
    result = append_row(sheet, [solid((0, 0, 255, 255)), solid((255, 255, 0, 255))], tile_w=8, tile_h=8)
    assert result.size == (16, 16)


def test_append_row_expands_width_for_more_frames():
    sheet = build_sheet([[solid((255, 0, 0, 255))]], tile_w=8, tile_h=8)
    new_frames = [solid((0, 0, 255, 255)), solid((0, 255, 0, 255)), solid((255, 255, 0, 255))]
    result = append_row(sheet, new_frames, tile_w=8, tile_h=8)
    assert result.size == (3 * 8, 2 * 8)
    assert result.getpixel((1 * 8, 0))[3] == 0


def test_append_row_does_not_shrink_width_for_fewer_frames():
    sheet = build_sheet([[solid((255, 0, 0, 255)), solid((0, 255, 0, 255))]], tile_w=8, tile_h=8)
    result = append_row(sheet, [solid((0, 0, 255, 255))], tile_w=8, tile_h=8)
    assert result.size == (2 * 8, 2 * 8)


def test_append_row_rectangular_tiles():
    sheet = build_sheet([[solid((255, 0, 0, 255), w=16, h=8)]], tile_w=16, tile_h=8)
    result = append_row(sheet, [solid((0, 0, 255, 255), w=16, h=8)], tile_w=16, tile_h=8)
    assert result.size == (16, 16)


# --- scale_frame ---

def test_scale_frame_same_aspect_fills_tile():
    frame = solid((255, 0, 0, 255), w=16, h=16)
    out = scale_frame(frame, tile_w=8, tile_h=8)
    assert out.size == (8, 8)
    assert out.getpixel((4, 4))[3] == 255


def test_scale_frame_strict_raises_on_aspect_mismatch():
    frame = solid((255, 0, 0, 255), w=16, h=8)
    with pytest.raises(ValueError):
        scale_frame(frame, tile_w=8, tile_h=8, mode="strict")


def test_scale_frame_shrink_letterboxes_wide_frame():
    # 2:1 frame into 1:1 tile → bars on top and bottom
    frame = solid((255, 0, 0, 255), w=16, h=8)
    out = scale_frame(frame, tile_w=8, tile_h=8, mode="shrink")
    assert out.size == (8, 8)
    assert out.getpixel((4, 0))[3] == 0   # letterbox bar transparent
    assert out.getpixel((4, 4))[3] == 255  # center opaque


def test_scale_frame_shrink_pillarboxes_tall_frame():
    # 1:2 frame into 1:1 tile → bars on left and right
    frame = solid((255, 0, 0, 255), w=8, h=16)
    out = scale_frame(frame, tile_w=8, tile_h=8, mode="shrink")
    assert out.size == (8, 8)
    assert out.getpixel((0, 4))[3] == 0   # pillarbox bar transparent
    assert out.getpixel((4, 4))[3] == 255  # center opaque


def test_scale_frame_crop_fills_tile_no_transparency():
    # 2:1 frame into 1:1 tile → crop sides, no transparent pixels
    frame = solid((255, 0, 0, 255), w=16, h=8)
    out = scale_frame(frame, tile_w=8, tile_h=8, mode="crop")
    assert out.size == (8, 8)
    assert out.getpixel((0, 0))[3] == 255
    assert out.getpixel((7, 7))[3] == 255


# --- cmd_create aspect ratio ---

def test_create_derives_tile_height_from_aspect_ratio():
    # 2:1 GIF (32x16), tile_width=64 → tile_height should be 32
    gif = Image.new("RGBA", (32, 16), (255, 0, 0, 255))
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        gif.save(gif_path)
        cmd_create(png_path, tile_w=64, gif_paths=[gif_path])
        tile_w, tile_h, _ = read_sidecar(os.path.splitext(png_path)[0] + ".lua")
        assert tile_w == 64
        assert tile_h == 32
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


# --- sidecar ---

def test_sidecar_round_trip():
    with tempfile.NamedTemporaryFile(suffix=".lua", delete=False) as f:
        path = f.name
    try:
        write_sidecar(path, tile_w=64, tile_h=48, frame_counts=[4, 8, 3])
        tile_w, tile_h, frame_counts = read_sidecar(path)
        assert tile_w == 64
        assert tile_h == 48
        assert frame_counts == [4, 8, 3]
    finally:
        os.unlink(path)
