#!/usr/bin/env python3
"""Promote the generated DocC module page into the GitHub Pages root index."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def root_relative_link(match: re.Match[str]) -> str:
    href = match.group(1)
    if href.startswith(("#", "/", "http://", "https://", "mailto:", "data:")):
        return match.group(0)

    if href.endswith("/index.html"):
        href = href[:-10]

    return f'href="documentation/chatkitswift/{href}"'


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: promote_docc_root_index.py <module-index> <root-index>", file=sys.stderr)
        return 2

    source_path = Path(sys.argv[1])
    destination_path = Path(sys.argv[2])
    source = source_path.read_text(encoding="utf-8")

    match = re.search(r"<noscript>(?P<article><article>.*?</article>)</noscript>", source, re.DOTALL)
    if not match:
        print(f"could not find DocC article content in {source_path}", file=sys.stderr)
        return 1

    article = re.sub(r'href="([^"]+)"', root_relative_link, match.group("article"))
    destination_path.write_text(
        f"""<!doctype html>
<html lang="en-US">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Embed a native SwiftUI chat surface that speaks the OpenAI ChatKit protocol.">
    <link rel="canonical" href="https://yazdanra.com/chatkit-swift/">
    <link rel="icon" href="/chatkit-swift/favicon.ico">
    <title>ChatKitSwift Documentation</title>
    <style>
      :root {{
        color-scheme: light dark;
        --accent: #2563eb;
        --border: color-mix(in srgb, CanvasText 16%, transparent);
        --muted: color-mix(in srgb, CanvasText 68%, Canvas);
      }}

      body {{
        margin: 0;
        font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: CanvasText;
        background: Canvas;
      }}

      article {{
        box-sizing: border-box;
        width: min(100%, 980px);
        margin: 0 auto;
        padding: 48px 24px 72px;
      }}

      h1 {{
        margin: 0 0 12px;
        font-size: clamp(2.25rem, 7vw, 4.75rem);
        line-height: 1.02;
      }}

      h2 {{
        margin-top: 44px;
        padding-top: 28px;
        border-top: 1px solid var(--border);
      }}

      h3 {{
        margin-top: 28px;
      }}

      p {{
        max-width: 760px;
      }}

      a {{
        color: var(--accent);
        text-decoration-thickness: 0.08em;
        text-underline-offset: 0.18em;
      }}

      code {{
        font: 0.92em ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      }}

      pre {{
        overflow-x: auto;
        border: 1px solid var(--border);
        border-radius: 8px;
        padding: 16px;
      }}

      section > ul:first-child {{
        display: none;
      }}

      section > p:first-of-type {{
        color: var(--muted);
        font-weight: 600;
        margin-bottom: 8px;
      }}

      li + li {{
        margin-top: 8px;
      }}
    </style>
  </head>
  <body>
    {article}
  </body>
</html>
""",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
