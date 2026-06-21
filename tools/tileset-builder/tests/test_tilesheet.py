from PIL import Image
import sys, os, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from tilesheet import build_sheet, append_row, write_sidecar, read_sidecar, cmd_create, cmd_append, scale_frame, main, SizeMismatchError
import pytest


def solid(color, w=8, h=8):
    return Image.new("RGBA", (w, h), color)


def save_gif(path: str, w: int, h: int, n_frames: int = 1) -> None:
    frames = [Image.new("RGB", (w, h), (255, 0, 0)).convert("P") for _ in range(n_frames)]
    frames[0].save(path, save_all=True, append_images=frames[1:])


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


# --- cmd_create: explicit tile_height ---


def test_create_explicit_tile_height_overrides_derivation_width_defaults_to_native():
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        save_gif(gif_path, w=40, h=20)  # native aspect would derive tile_h=20 if tile_w=40
        cmd_create(png_path, tile_w=None, gif_paths=[gif_path], mode="shrink", tile_h=64)
        tile_w, tile_h, _ = read_sidecar(os.path.splitext(png_path)[0] + ".lua")
        assert tile_w == 40
        assert tile_h == 64
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


def test_create_explicit_width_and_height_force_square_tile():
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        save_gif(gif_path, w=40, h=20)  # non-square row 0
        cmd_create(png_path, tile_w=64, gif_paths=[gif_path], mode="shrink", tile_h=64)
        tile_w, tile_h, _ = read_sidecar(os.path.splitext(png_path)[0] + ".lua")
        assert tile_w == 64
        assert tile_h == 64
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


def test_create_row0_mismatch_strict_mode_exits():
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        save_gif(gif_path, w=40, h=20)  # 2:1, forced tile is 1:1 → mismatch
        with pytest.raises(SystemExit):
            cmd_create(png_path, tile_w=64, gif_paths=[gif_path], tile_h=64)
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


def test_create_row0_mismatch_error_names_gif_file(monkeypatch, tmp_path):
    gif_path = str(tmp_path / "tile_2.gif")
    png_path = str(tmp_path / "out.png")
    save_gif(gif_path, w=40, h=20)  # 2:1, forced tile is 1:1 → mismatch
    monkeypatch.setattr("sys.argv", ["tilesheet", "create", "--output", png_path, "--tile-width", "64", "--tile-height", "64", gif_path])
    with pytest.raises(SystemExit) as exc:
        main()
    assert "tile_2.gif" in str(exc.value)


def test_create_row0_mismatch_with_shrink_letterboxes():
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        gif = Image.new("RGBA", (16, 8), (255, 0, 0, 255))  # 2:1
        gif.save(gif_path)
        cmd_create(png_path, tile_w=8, gif_paths=[gif_path], mode="shrink", tile_h=8)
        sheet = Image.open(png_path)
        assert sheet.getpixel((4, 0))[3] == 0   # letterbox bar transparent
        assert sheet.getpixel((4, 4))[3] == 255  # center opaque
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


def test_create_row0_mismatch_with_crop_fills_no_transparency():
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        gif = Image.new("RGBA", (16, 8), (255, 0, 0, 255))  # 2:1
        gif.save(gif_path)
        cmd_create(png_path, tile_w=8, gif_paths=[gif_path], mode="crop", tile_h=8)
        sheet = Image.open(png_path)
        assert sheet.getpixel((0, 0))[3] == 255
        assert sheet.getpixel((7, 7))[3] == 255
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


def test_create_later_row_mismatch_error_names_gif_file(monkeypatch, tmp_path):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "tile_4.gif")
    png_path = str(tmp_path / "out.png")
    save_gif(gif1, w=32, h=32)
    save_gif(gif2, w=40, h=20)  # mismatched aspect, second row
    monkeypatch.setattr("sys.argv", ["tilesheet", "create", "--output", png_path, gif1, gif2])
    with pytest.raises(SystemExit) as exc:
        main()
    assert "tile_4.gif" in str(exc.value)


# --- cmd_create: optional tile_width ---


def test_create_no_tile_width_preserves_native_height():
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        save_gif(gif_path, w=40, h=25)
        cmd_create(png_path, tile_w=None, gif_paths=[gif_path])
        _, tile_h, _ = read_sidecar(os.path.splitext(png_path)[0] + ".lua")
        assert tile_h == 25
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


def test_create_no_tile_width_uses_gif_native_width():
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as f:
        gif_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        png_path = f.name
    try:
        save_gif(gif_path, w=40, h=20)
        cmd_create(png_path, tile_w=None, gif_paths=[gif_path])
        tile_w, tile_h, _ = read_sidecar(os.path.splitext(png_path)[0] + ".lua")
        assert tile_w == 40
    finally:
        for p in (gif_path, png_path, os.path.splitext(png_path)[0] + ".lua"):
            if os.path.exists(p):
                os.unlink(p)


# --- CLI: optional tile_width and default output ---

def test_cli_create_no_tile_width_uses_native_width(monkeypatch, tmp_path):
    gif_path = str(tmp_path / "test.gif")
    png_path = str(tmp_path / "out.png")
    save_gif(gif_path, w=32, h=16)
    monkeypatch.setattr("sys.argv", ["tilesheet", "create", "--output", png_path, gif_path])
    main()
    tile_w, _, _ = read_sidecar(str(tmp_path / "out.lua"))
    assert tile_w == 32


def test_cli_create_tile_height_flag_overrides_derivation(monkeypatch, tmp_path):
    gif_path = str(tmp_path / "test.gif")
    png_path = str(tmp_path / "out.png")
    save_gif(gif_path, w=32, h=16)  # native aspect would derive tile_h=16 if tile_w=32
    monkeypatch.setattr("sys.argv", ["tilesheet", "create", "--output", png_path, "--tile-height", "48", "--shrink", gif_path])
    main()
    tile_w, tile_h, _ = read_sidecar(str(tmp_path / "out.lua"))
    assert tile_w == 32
    assert tile_h == 48


def test_cli_create_default_output_is_output_png(monkeypatch, tmp_path):
    gif_path = str(tmp_path / "test.gif")
    save_gif(gif_path, w=20, h=10)
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr("sys.argv", ["tilesheet", "create", gif_path])
    main()
    assert (tmp_path / "output.png").exists()
    assert (tmp_path / "output.lua").exists()



# --- cmd_append: size mismatch detection ---

def test_append_exits_cleanly_when_gif_not_found(tmp_path):
    gif1 = str(tmp_path / "first.gif")
    png = str(tmp_path / "sheet.png")
    save_gif(gif1, w=32, h=32)
    cmd_create(png, tile_w=None, gif_paths=[gif1])
    with pytest.raises(SystemExit):
        cmd_append(png, "/nonexistent/path.gif")


def test_append_raises_on_aspect_ratio_mismatch(tmp_path):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "second.gif")
    png = str(tmp_path / "sheet.png")
    save_gif(gif1, w=32, h=32)
    save_gif(gif2, w=16, h=24)  # different aspect ratio
    cmd_create(png, tile_w=None, gif_paths=[gif1])
    with pytest.raises(SizeMismatchError):
        cmd_append(png, gif2)


def test_append_no_raise_on_same_aspect_different_size(tmp_path):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "second.gif")
    png = str(tmp_path / "sheet.png")
    save_gif(gif1, w=32, h=32)
    save_gif(gif2, w=16, h=16)  # same 1:1 aspect, just smaller — must not raise
    cmd_create(png, tile_w=None, gif_paths=[gif1])
    cmd_append(png, gif2)


def test_append_no_raise_when_sizes_match(tmp_path):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "second.gif")
    png = str(tmp_path / "sheet.png")
    save_gif(gif1, w=32, h=32)
    save_gif(gif2, w=32, h=32)
    cmd_create(png, tile_w=None, gif_paths=[gif1])
    cmd_append(png, gif2)  # must not raise


def test_append_no_raise_with_shrink_flag_on_mismatch(tmp_path):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "second.gif")
    png = str(tmp_path / "sheet.png")
    save_gif(gif1, w=32, h=32)
    save_gif(gif2, w=16, h=24)  # different aspect ratio
    cmd_create(png, tile_w=None, gif_paths=[gif1])
    cmd_append(png, gif2, mode="shrink")  # must not raise


def test_append_mismatch_error_contains_both_sizes(tmp_path):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "second.gif")
    png = str(tmp_path / "sheet.png")
    save_gif(gif1, w=32, h=32)
    save_gif(gif2, w=16, h=24)
    cmd_create(png, tile_w=None, gif_paths=[gif1])
    with pytest.raises(SizeMismatchError) as exc:
        cmd_append(png, gif2)
    msg = str(exc.value)
    assert "32x32" in msg  # tileset tile size
    assert "16x24" in msg  # gif native size


def test_cli_append_prints_size_mismatch_and_suggests_flag(monkeypatch, tmp_path, capsys):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "second.gif")
    png = str(tmp_path / "sheet.png")
    save_gif(gif1, w=32, h=32)
    save_gif(gif2, w=16, h=24)  # different aspect ratio
    cmd_create(png, tile_w=None, gif_paths=[gif1])
    monkeypatch.setattr("sys.argv", ["tilesheet", "append", "--output", png, gif2])
    with pytest.raises(SystemExit):
        main()
    err = capsys.readouterr().err
    assert "32x32" in err
    assert "16x24" in err
    assert "--shrink" in err or "--crop" in err


def test_cli_append_default_output_is_output_png(monkeypatch, tmp_path):
    gif1 = str(tmp_path / "first.gif")
    gif2 = str(tmp_path / "second.gif")
    save_gif(gif1, w=20, h=10)
    save_gif(gif2, w=20, h=10)
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr("sys.argv", ["tilesheet", "create", gif1])
    main()
    monkeypatch.setattr("sys.argv", ["tilesheet", "append", gif2])
    main()
    _, _, frame_counts = read_sidecar(str(tmp_path / "output.lua"))
    assert len(frame_counts) == 2


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
