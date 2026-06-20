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


def build_sheet(rows: list, tile_w: int, tile_h: int) -> Image.Image:
    max_frames = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (max_frames * tile_w, len(rows) * tile_h), (0, 0, 0, 0))
    for row_idx, frames in enumerate(rows):
        for col_idx, frame in enumerate(frames):
            scaled = frame.resize((tile_w, tile_h), Image.BILINEAR)
            sheet.paste(scaled, (col_idx * tile_w, row_idx * tile_h))
    return sheet


def append_row(sheet: Image.Image, frames: list, tile_w: int, tile_h: int) -> Image.Image:
    cur_w, cur_h = sheet.size
    new_w = max(cur_w, len(frames) * tile_w)
    canvas = Image.new("RGBA", (new_w, cur_h + tile_h), (0, 0, 0, 0))
    canvas.paste(sheet, (0, 0))
    for col_idx, frame in enumerate(frames):
        scaled = frame.resize((tile_w, tile_h), Image.BILINEAR)
        canvas.paste(scaled, (col_idx * tile_w, cur_h))
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


def cmd_create(output_png: str, tile_w: int, gif_paths: list) -> None:
    rows = []
    for path in gif_paths:
        frames = extract_frames(Image.open(path))
        if not frames:
            sys.exit(f"error: {path} has zero frames")
        rows.append(frames)
    native_w, native_h = rows[0][0].size
    tile_h = round(native_h * tile_w / native_w)
    build_sheet(rows, tile_w, tile_h).save(output_png)
    write_sidecar(_sidecar_path(output_png), tile_w, tile_h, [len(r) for r in rows])


def cmd_append(output_png: str, gif_path: str) -> None:
    lua = _sidecar_path(output_png)
    if not os.path.exists(output_png):
        sys.exit(f"error: {output_png} not found")
    if not os.path.exists(lua):
        sys.exit(f"error: {lua} not found")
    tile_w, tile_h, frame_counts = read_sidecar(lua)
    frames = extract_frames(Image.open(gif_path))
    if not frames:
        sys.exit(f"error: {gif_path} has zero frames")
    sheet = append_row(Image.open(output_png).convert("RGBA"), frames, tile_w, tile_h)
    sheet.save(output_png)
    frame_counts.append(len(frames))
    write_sidecar(lua, tile_w, tile_h, frame_counts)


def cmd_inspect(gif_paths: list) -> None:
    for path in gif_paths:
        frames = extract_frames(Image.open(path))
        w, h = frames[0].size if frames else (0, 0)
        print(f"{path}: {len(frames)} frame(s), {w}x{h}px")


def main():
    parser = argparse.ArgumentParser(prog="tilesheet")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_create = sub.add_parser("create")
    p_create.add_argument("output")
    p_create.add_argument("--tile-width", type=int, required=True)
    p_create.add_argument("gifs", nargs="+")

    p_append = sub.add_parser("append")
    p_append.add_argument("output")
    p_append.add_argument("gif")

    p_inspect = sub.add_parser("inspect")
    p_inspect.add_argument("gifs", nargs="+")

    args = parser.parse_args()
    if args.cmd == "create":
        cmd_create(args.output, args.tile_width, args.gifs)
    elif args.cmd == "append":
        cmd_append(args.output, args.gif)
    else:
        cmd_inspect(args.gifs)


if __name__ == "__main__":
    main()
