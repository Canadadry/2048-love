import os
import sys
from urllib.parse import urlparse
import requests
from bs4 import BeautifulSoup

HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; curl-giphy/1.0)"}


def extract_filename(url):
    path = urlparse(url).path.rstrip("/")
    slug = path.split("/")[-1]
    return slug + ".gif"


def find_gif_src(html):
    soup = BeautifulSoup(html, "html.parser")
    img = soup.find("img", class_="giphy-gif-img")
    if img is None:
        raise ValueError("no img.giphy-gif-img found")
    return img["src"]


def main(url):
    try:
        page = requests.get(url, headers=HEADERS)
        page.raise_for_status()
        src = find_gif_src(page.text)
        gif = requests.get(src, headers=HEADERS)
        gif.raise_for_status()
        filename = extract_filename(url)
        dest = os.path.join(os.getcwd(), filename)
        with open(dest, "wb") as f:
            f.write(gif.content)
    except Exception:
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(1)
    main(sys.argv[1])
