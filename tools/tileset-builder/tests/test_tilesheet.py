from PIL import Image
import sys, os, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from tilesheet import build_sheet, append_row, write_sidecar, read_sidecar


def solid(color, size=8):
    img = Image.new("RGBA", (size, size), color)
    return img


# --- build_sheet ---

def test_build_sheet_canvas_size_single_row():
    frames = [solid((255, 0, 0, 255)), solid((0, 255, 0, 255)), solid((0, 0, 255, 255))]
    sheet = build_sheet([frames], tile_size=8)
    assert sheet.size == (3 * 8, 1 * 8)


def test_build_sheet_transparent_pixels_preserved():
    frame = Image.new("RGBA", (8, 8), (255, 0, 0, 0))  # fully transparent red
    sheet = build_sheet([[frame]], tile_size=8)
    assert sheet.getpixel((0, 0))[3] == 0


def test_build_sheet_unequal_rows_width_and_padding():
    row0 = [solid((255, 0, 0, 255)), solid((0, 255, 0, 255)), solid((0, 0, 255, 255))]  # 3 frames
    row1 = [solid((255, 255, 0, 255))]                                                   # 1 frame
    sheet = build_sheet([row0, row1], tile_size=8)
    assert sheet.size == (3 * 8, 2 * 8)
    # padding pixel in row1 at col 1 must be fully transparent
    assert sheet.getpixel((1 * 8, 1 * 8))[3] == 0


# --- append_row ---

def test_append_row_grows_height_same_width():
    sheet = build_sheet([[solid((255, 0, 0, 255)), solid((0, 255, 0, 255))]], tile_size=8)
    assert sheet.size == (16, 8)
    new_frames = [solid((0, 0, 255, 255)), solid((255, 255, 0, 255))]
    result = append_row(sheet, new_frames, tile_size=8)
    assert result.size == (16, 16)


def test_append_row_expands_width_for_more_frames():
    sheet = build_sheet([[solid((255, 0, 0, 255))]], tile_size=8)  # 1 frame wide
    new_frames = [solid((0, 0, 255, 255)), solid((0, 255, 0, 255)), solid((255, 255, 0, 255))]
    result = append_row(sheet, new_frames, tile_size=8)
    assert result.size == (3 * 8, 2 * 8)
    # original row padding pixels must be transparent
    assert result.getpixel((1 * 8, 0))[3] == 0


def test_append_row_does_not_shrink_width_for_fewer_frames():
    sheet = build_sheet([[solid((255, 0, 0, 255)), solid((0, 255, 0, 255))]], tile_size=8)
    result = append_row(sheet, [solid((0, 0, 255, 255))], tile_size=8)
    assert result.size == (2 * 8, 2 * 8)


# --- sidecar ---

def test_sidecar_round_trip():
    with tempfile.NamedTemporaryFile(suffix=".lua", delete=False) as f:
        path = f.name
    try:
        write_sidecar(path, tile_size=64, frame_counts=[4, 8, 3])
        tile_size, frame_counts = read_sidecar(path)
        assert tile_size == 64
        assert frame_counts == [4, 8, 3]
    finally:
        os.unlink(path)
