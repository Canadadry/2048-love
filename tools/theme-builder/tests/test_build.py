import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from build import parse_manifest, download_gif, build_sheet, build_theme, DEFAULT_MAX_SIZE


class TestParseManifest(unittest.TestCase):
    def test_maps_non_blank_lines_in_order(self):
        manifest = "https://giphy.com/gifs/a\nhttps://giphy.com/gifs/b\nhttps://giphy.com/gifs/c\n"
        path = self._write_manifest(manifest)
        self.assertEqual(
            parse_manifest(path),
            ["https://giphy.com/gifs/a", "https://giphy.com/gifs/b", "https://giphy.com/gifs/c"],
        )

    def test_ignores_blank_lines(self):
        manifest = "https://giphy.com/gifs/a\n\n\nhttps://giphy.com/gifs/b\n"
        path = self._write_manifest(manifest)
        self.assertEqual(
            parse_manifest(path),
            ["https://giphy.com/gifs/a", "https://giphy.com/gifs/b"],
        )

    def test_raises_when_more_than_13_non_blank_lines(self):
        manifest = "\n".join(f"https://giphy.com/gifs/{i}" for i in range(14))
        path = self._write_manifest(manifest)
        with self.assertRaises(ValueError):
            parse_manifest(path)

    def test_raises_when_manifest_is_empty(self):
        path = self._write_manifest("")
        with self.assertRaises(ValueError):
            parse_manifest(path)

    def _write_manifest(self, content):
        import tempfile

        fd, path = tempfile.mkstemp(suffix=".txt")
        with os.fdopen(fd, "w") as f:
            f.write(content)
        self.addCleanup(os.remove, path)
        return path


class TestDownloadGif(unittest.TestCase):
    def test_skips_subprocess_when_file_already_cached(self):
        with tempfile.TemporaryDirectory() as raw_dir:
            url = "https://giphy.com/gifs/cat-jumping-xun2qNfnK1cV5r07GM"
            cached = Path(raw_dir) / "cat-jumping-xun2qNfnK1cV5r07GM.gif"
            cached.write_bytes(b"GIF89a")

            with patch("build.subprocess.run") as mock_run:
                result = download_gif(url, raw_dir)

            mock_run.assert_not_called()
            self.assertEqual(result, cached)

    def test_invokes_giphy_dl_with_raw_dir_as_cwd_when_missing(self):
        with tempfile.TemporaryDirectory() as raw_dir:
            url = "https://giphy.com/gifs/cat-jumping-xun2qNfnK1cV5r07GM"

            with patch("build.subprocess.run") as mock_run:
                result = download_gif(url, raw_dir)

            mock_run.assert_called_once()
            args, kwargs = mock_run.call_args
            self.assertTrue(args[0][-2].endswith("giphy_dl.py"))
            self.assertEqual(args[0][-1], url)
            self.assertEqual(kwargs["cwd"], raw_dir)
            self.assertEqual(result, Path(raw_dir) / "cat-jumping-xun2qNfnK1cV5r07GM.gif")

    def test_raises_when_giphy_dl_subprocess_fails(self):
        with tempfile.TemporaryDirectory() as raw_dir:
            url = "https://giphy.com/gifs/cat-jumping-xun2qNfnK1cV5r07GM"

            with patch(
                "build.subprocess.run",
                side_effect=subprocess.CalledProcessError(1, "giphy_dl.py"),
            ):
                with self.assertRaises(subprocess.CalledProcessError):
                    download_gif(url, raw_dir)


class TestBuildSheet(unittest.TestCase):
    def test_invokes_tilesheet_create_with_crop_in_gif_order(self):
        gif_paths = [Path("/raw/tile_2.gif"), Path("/raw/tile_4.gif")]
        output_path = Path("/out/jurassic-park.png")

        with patch("build.subprocess.run") as mock_run:
            build_sheet(gif_paths, output_path)

        mock_run.assert_called_once()
        args, _ = mock_run.call_args
        cmd = args[0]
        self.assertTrue(any(part.endswith("tilesheet.py") for part in cmd))
        self.assertIn("create", cmd)
        self.assertIn("--crop", cmd)
        self.assertIn("--output", cmd)
        self.assertEqual(cmd[cmd.index("--output") + 1], str(output_path))
        self.assertEqual(cmd[-2], str(gif_paths[0]))
        self.assertEqual(cmd[-1], str(gif_paths[1]))

    def test_defaults_tile_size_to_default_max_size(self):
        with patch("build.subprocess.run") as mock_run:
            build_sheet([Path("/raw/tile_2.gif")], Path("/out/theme.png"))

        cmd = mock_run.call_args.args[0]
        self.assertEqual(cmd[cmd.index("--tile-width") + 1], str(DEFAULT_MAX_SIZE))
        self.assertEqual(cmd[cmd.index("--tile-height") + 1], str(DEFAULT_MAX_SIZE))

    def test_passes_through_custom_max_size(self):
        with patch("build.subprocess.run") as mock_run:
            build_sheet([Path("/raw/tile_2.gif")], Path("/out/theme.png"), max_size=64)

        cmd = mock_run.call_args.args[0]
        self.assertEqual(cmd[cmd.index("--tile-width") + 1], "64")
        self.assertEqual(cmd[cmd.index("--tile-height") + 1], "64")


class TestBuildTheme(unittest.TestCase):
    def test_downloads_each_url_then_builds_sheet_in_manifest_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = Path(tmp) / "myTheme.txt"
            manifest_path.write_text("https://giphy.com/gifs/a\nhttps://giphy.com/gifs/b\n")
            expected_raw_dir = Path(tmp) / "myTheme" / "raw"
            fake_paths = [expected_raw_dir / "a.gif", expected_raw_dir / "b.gif"]

            with patch("build.download_gif", side_effect=fake_paths) as mock_download, patch(
                "build.build_sheet"
            ) as mock_build_sheet:
                build_theme(str(manifest_path))

            self.assertEqual(
                [call.args for call in mock_download.call_args_list],
                [
                    ("https://giphy.com/gifs/a", expected_raw_dir),
                    ("https://giphy.com/gifs/b", expected_raw_dir),
                ],
            )
            mock_build_sheet.assert_called_once()
            args, _ = mock_build_sheet.call_args
            self.assertEqual(args[0], fake_paths)
            self.assertTrue(args[1].as_posix().endswith("game/assets/myTheme.png"))

    def test_forwards_custom_max_size_to_build_sheet(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = Path(tmp) / "myTheme.txt"
            manifest_path.write_text("https://giphy.com/gifs/a\n")

            with patch("build.download_gif", return_value=Path("/raw/a.gif")), patch(
                "build.build_sheet"
            ) as mock_build_sheet:
                build_theme(str(manifest_path), max_size=64)

            self.assertEqual(mock_build_sheet.call_args.kwargs["max_size"], 64)

    def test_aborts_on_first_download_failure_naming_url_and_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = Path(tmp) / "myTheme.txt"
            manifest_path.write_text(
                "https://giphy.com/gifs/a\nhttps://giphy.com/gifs/bad\nhttps://giphy.com/gifs/c\n"
            )

            def fake_download(url, raw_dir):
                if url.endswith("/bad"):
                    raise RuntimeError("boom")
                return raw_dir / "ok.gif"

            with patch("build.download_gif", side_effect=fake_download) as mock_download, patch(
                "build.build_sheet"
            ) as mock_build_sheet:
                with self.assertRaises(RuntimeError) as ctx:
                    build_theme(str(manifest_path))

            self.assertIn("https://giphy.com/gifs/bad", str(ctx.exception))
            self.assertIn("line 2", str(ctx.exception))
            self.assertEqual(mock_download.call_count, 2)
            mock_build_sheet.assert_not_called()


if __name__ == "__main__":
    unittest.main()
