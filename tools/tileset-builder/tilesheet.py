import re
import sys
import os
import argparse
from PIL import Image


def extract_frames(gif: Image.Image) -> list:
    frames = []
    try:
        while True:
            frame = gif.copy().convert("RGBA")
            frames.append(frame)
            gif.seek(gif.tell() + 1)
    except EOFError:
        pass
    return frames


def scale_frame(frame: Image.Image, tile_w: int, tile_h: int, mode: str = "strict") -> Image.Image:
    fw, fh = frame.size
    if fw * tile_h != fh * tile_w:
        if mode == "strict":
            raise ValueError(
                f"frame aspect ratio {fw}x{fh} does not match tile {tile_w}x{tile_h}; "
                "use --shrink or --crop"
            )
        if mode == "shrink":
            scale = min(tile_w / fw, tile_h / fh)
            sw, sh = round(fw * scale), round(fh * scale)
            scaled = frame.resize((sw, sh), Image.BILINEAR)
            canvas = Image.new("RGBA", (tile_w, tile_h), (0, 0, 0, 0))
            canvas.paste(scaled, ((tile_w - sw) // 2, (tile_h - sh) // 2))
            return canvas
        if mode == "crop":
            scale = max(tile_w / fw, tile_h / fh)
            sw, sh = round(fw * scale), round(fh * scale)
            scaled = frame.resize((sw, sh), Image.BILINEAR)
            x = (sw - tile_w) // 2
            y = (sh - tile_h) // 2
            return scaled.crop((x, y, x + tile_w, y + tile_h))
    return frame.resize((tile_w, tile_h), Image.BILINEAR)


def build_sheet(rows: list, tile_w: int, tile_h: int, mode: str = "strict") -> Image.Image:
    max_frames = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (max_frames * tile_w, len(rows) * tile_h), (0, 0, 0, 0))
    for row_idx, frames in enumerate(rows):
        for col_idx, frame in enumerate(frames):
            sheet.paste(scale_frame(frame, tile_w, tile_h, mode), (col_idx * tile_w, row_idx * tile_h))
    return sheet


def append_row(sheet: Image.Image, frames: list, tile_w: int, tile_h: int, mode: str = "strict") -> Image.Image:
    cur_w, cur_h = sheet.size
    new_w = max(cur_w, len(frames) * tile_w)
    canvas = Image.new("RGBA", (new_w, cur_h + tile_h), (0, 0, 0, 0))
    canvas.paste(sheet, (0, 0))
    for col_idx, frame in enumerate(frames):
        canvas.paste(scale_frame(frame, tile_w, tile_h, mode), (col_idx * tile_w, cur_h))
    return canvas


def write_sidecar(path: str, tile_w: int, tile_h: int, frame_counts: list) -> None:
    counts_str = ", ".join(str(c) for c in frame_counts)
    with open(path, "w") as f:
        f.write(
            f"return {{\n"
            f"  tile_width = {tile_w},\n"
            f"  tile_height = {tile_h},\n"
            f"  frame_counts = {{ {counts_str} }},\n"
            f"}}\n"
        )


def read_sidecar(path: str) -> tuple:
    with open(path) as f:
        content = f.read()
    tile_w = int(re.search(r"tile_width\s*=\s*(\d+)", content).group(1))
    tile_h = int(re.search(r"tile_height\s*=\s*(\d+)", content).group(1))
    counts = list(map(int, re.findall(r"frame_counts\s*=\s*\{([^}]*)\}", content)[0].split(",")))
    return tile_w, tile_h, counts


def _sidecar_path(png_path: str) -> str:
    return os.path.splitext(png_path)[0] + ".lua"


def cmd_create(output_png: str, tile_w: int, gif_paths: list, mode: str = "strict") -> None:
    rows = []
    for path in gif_paths:
        frames = extract_frames(Image.open(path))
        if not frames:
            sys.exit(f"error: {path} has zero frames")
        rows.append(frames)
    native_w, native_h = rows[0][0].size
    tile_h = round(native_h * tile_w / native_w)
    try:
        build_sheet(rows, tile_w, tile_h, mode).save(output_png)
    except ValueError as e:
        sys.exit(f"error: {e}")
    write_sidecar(_sidecar_path(output_png), tile_w, tile_h, [len(r) for r in rows])


def cmd_append(output_png: str, gif_path: str, mode: str = "strict") -> None:
    lua = _sidecar_path(output_png)
    if not os.path.exists(output_png):
        sys.exit(f"error: {output_png} not found")
    if not os.path.exists(lua):
        sys.exit(f"error: {lua} not found")
    tile_w, tile_h, frame_counts = read_sidecar(lua)
    frames = extract_frames(Image.open(gif_path))
    if not frames:
        sys.exit(f"error: {gif_path} has zero frames")
    try:
        sheet = append_row(Image.open(output_png).convert("RGBA"), frames, tile_w, tile_h, mode)
    except ValueError as e:
        sys.exit(f"error: {e}")
    sheet.save(output_png)
    frame_counts.append(len(frames))
    write_sidecar(lua, tile_w, tile_h, frame_counts)


def cmd_inspect(gif_paths: list) -> None:
    for path in gif_paths:
        frames = extract_frames(Image.open(path))
        w, h = frames[0].size if frames else (0, 0)
        print(f"{path}: {len(frames)} frame(s), {w}x{h}px")


def _add_mode_flags(parser) -> None:
    g = parser.add_mutually_exclusive_group()
    g.add_argument("--shrink", action="store_true", help="fit frame within tile, pad with transparency")
    g.add_argument("--crop", action="store_true", help="scale frame to fill tile, center crop")


def _mode(args) -> str:
    if args.shrink:
        return "shrink"
    if args.crop:
        return "crop"
    return "strict"


def main():
    parser = argparse.ArgumentParser(prog="tilesheet")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_create = sub.add_parser("create")
    p_create.add_argument("output")
    p_create.add_argument("--tile-width", type=int, required=True)
    p_create.add_argument("gifs", nargs="+")
    _add_mode_flags(p_create)

    p_append = sub.add_parser("append")
    p_append.add_argument("output")
    p_append.add_argument("gif")
    _add_mode_flags(p_append)

    p_inspect = sub.add_parser("inspect")
    p_inspect.add_argument("gifs", nargs="+")

    args = parser.parse_args()
    if args.cmd == "create":
        cmd_create(args.output, args.tile_width, args.gifs, _mode(args))
    elif args.cmd == "append":
        cmd_append(args.output, args.gif, _mode(args))
    else:
        cmd_inspect(args.gifs)


if __name__ == "__main__":
    main()
