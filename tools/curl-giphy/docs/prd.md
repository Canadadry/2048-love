# curl-giphy — PRD

## Goal

CLI tool that downloads a GIF from a Giphy page URL.

## Interface

```
python giphy_dl.py <giphy-url>
```

- One positional argument: the full Giphy page URL
- No output on success
- Exits with non-zero status on failure (no error message required)

## Behavior

1. Fetch the HTML at the provided URL
2. Select the first `img.giphy-gif-img` element
3. Download the file at its `src` attribute
4. Save to the current working directory

## Output filename

Derived from the last path segment of the input URL.

Example:
- Input: `https://giphy.com/gifs/cat-jumping-shooting-in-war-xun2qNfnK1cV5r07GM`
- Output: `cat-jumping-shooting-in-war-xun2qNfnK1cV5r07GM.gif`

## Implementation notes

- Plain HTTP fetch (no headless browser needed — `img.giphy-gif-img` is present in server-rendered HTML)
- Use a browser `User-Agent` header to avoid blocks
- Language: Python
- Dependencies: `requests`, `beautifulsoup4`
