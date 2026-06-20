import os
import tempfile
import unittest
from unittest.mock import patch, MagicMock
from giphy_dl import extract_filename, find_gif_src, main


class TestExtractFilename(unittest.TestCase):
    def test_derives_filename_from_last_path_segment(self):
        url = "https://giphy.com/gifs/cat-jumping-shooting-in-war-xun2qNfnK1cV5r07GM"
        self.assertEqual(extract_filename(url), "cat-jumping-shooting-in-war-xun2qNfnK1cV5r07GM.gif")

    def test_ignores_trailing_slash(self):
        url = "https://giphy.com/gifs/cat-jumping-shooting-in-war-xun2qNfnK1cV5r07GM/"
        self.assertEqual(extract_filename(url), "cat-jumping-shooting-in-war-xun2qNfnK1cV5r07GM.gif")


class TestFindGifSrc(unittest.TestCase):
    def test_returns_src_of_first_giphy_gif_img(self):
        html = """
        <html><body>
          <img class="giphy-gif-img" src="https://media.giphy.com/media/abc123/giphy.gif" />
        </body></html>
        """
        self.assertEqual(find_gif_src(html), "https://media.giphy.com/media/abc123/giphy.gif")

    def test_returns_first_when_multiple(self):
        html = """
        <html><body>
          <img class="giphy-gif-img" src="https://media.giphy.com/media/first/giphy.gif" />
          <img class="giphy-gif-img" src="https://media.giphy.com/media/second/giphy.gif" />
        </body></html>
        """
        self.assertEqual(find_gif_src(html), "https://media.giphy.com/media/first/giphy.gif")

    def test_raises_when_no_img_found(self):
        html = "<html><body><p>no image here</p></body></html>"
        with self.assertRaises(ValueError):
            find_gif_src(html)


class TestMain(unittest.TestCase):
    def _make_response(self, content, text=None):
        r = MagicMock()
        r.content = content
        if text is not None:
            r.text = text
        r.raise_for_status = MagicMock()
        return r

    def test_saves_gif_to_cwd_with_slug_filename(self):
        url = "https://giphy.com/gifs/cat-jumping-xun2qNfnK1cV5r07GM"
        page_html = '<img class="giphy-gif-img" src="https://media.giphy.com/media/abc/giphy.gif" />'
        gif_bytes = b"GIF89a..."

        page_resp = self._make_response(content=b"", text=page_html)
        gif_resp = self._make_response(content=gif_bytes)

        with tempfile.TemporaryDirectory() as tmpdir:
            with patch("giphy_dl.requests.get", side_effect=[page_resp, gif_resp]):
                with patch("os.getcwd", return_value=tmpdir):
                    main(url)

            saved = os.path.join(tmpdir, "cat-jumping-xun2qNfnK1cV5r07GM.gif")
            self.assertTrue(os.path.exists(saved))
            with open(saved, "rb") as f:
                self.assertEqual(f.read(), gif_bytes)

    def test_exits_nonzero_on_missing_img(self):
        url = "https://giphy.com/gifs/no-img-slug"
        page_resp = self._make_response(content=b"", text="<html>no image</html>")

        with patch("giphy_dl.requests.get", return_value=page_resp):
            with self.assertRaises(SystemExit) as ctx:
                main(url)
        self.assertNotEqual(ctx.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
