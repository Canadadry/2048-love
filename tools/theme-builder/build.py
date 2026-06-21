import argparse
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

_CURL_GIPHY_DIR = Path(__file__).resolve().parent.parent / "curl-giphy"
_TILESET_BUILDER_DIR = Path(__file__).resolve().parent.parent / "tileset-builder"
_REPO_ROOT = Path(__file__).resolve().parent.parent.parent

MAX_TILE_ROWS = 13
DEFAULT_MAX_SIZE = 256


def extract_filename(url):
    # Mirrors curl-giphy's giphy_dl.extract_filename — duplicated rather than
    # imported so theme-builder stays stdlib-only (importing giphy_dl pulls
    # in requests/bs4, which live only in curl-giphy's own venv).
    path = urlparse(url).path.rstrip("/")
    slug = path.split("/")[-1]
    return slug + ".gif"


def parse_manifest(path):
    with open(path) as f:
        lines = f.read().splitlines()
    urls = [line for line in lines if line.strip()]
    if not urls:
        raise ValueError(f"manifest {path} is empty")
    if len(urls) > MAX_TILE_ROWS:
        raise ValueError(
            f"manifest {path} has {len(urls)} rows, max is {MAX_TILE_ROWS}"
        )
    return urls


def download_gif(url, raw_dir):
    dest = Path(raw_dir) / extract_filename(url)
    if dest.exists():
        return dest
    python = _CURL_GIPHY_DIR / ".venv" / "bin" / "python3"
    script = _CURL_GIPHY_DIR / "giphy_dl.py"
    subprocess.run([str(python), str(script), url], cwd=str(raw_dir), check=True)
    return dest


def build_sheet(gif_paths, output_path, max_size=DEFAULT_MAX_SIZE):
    python = _TILESET_BUILDER_DIR / ".venv" / "bin" / "python3"
    script = _TILESET_BUILDER_DIR / "tilesheet.py"
    cmd = [
        str(python),
        str(script),
        "create",
        "--crop",
        "--output",
        str(output_path),
        "--tile-width",
        str(max_size),
        "--tile-height",
        str(max_size),
    ]
    cmd += [str(p) for p in gif_paths]
    subprocess.run(cmd, check=True)


def build_theme(manifest_path, max_size=DEFAULT_MAX_SIZE):
    manifest_path = Path(manifest_path)
    name = manifest_path.stem
    urls = parse_manifest(manifest_path)

    raw_dir = manifest_path.parent / name / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    gif_paths = []
    for line_no, url in enumerate(urls, start=1):
        try:
            gif_paths.append(download_gif(url, raw_dir))
        except Exception as e:
            raise RuntimeError(f"failed to download {url} (line {line_no}): {e}") from e

    output_path = _REPO_ROOT / "game" / "assets" / f"{name}.png"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    build_sheet(gif_paths, output_path, max_size=max_size)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="build.py")
    parser.add_argument("manifest_path")
    parser.add_argument("--max-size", type=int, default=DEFAULT_MAX_SIZE)
    args = parser.parse_args()
    build_theme(args.manifest_path, max_size=args.max_size)
