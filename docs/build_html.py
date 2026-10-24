#!/usr/bin/env python3
"""Builds docs/index.html from docs/USAGE.md. Handles the Markdown subset USAGE.md uses; no dependencies."""
import html
import re
from pathlib import Path

DOCS = Path(__file__).parent


def slug(text: str) -> str:
    text = re.sub(r"[^\w\s-]", "", re.sub(r"`", "", text).lower())
    return re.sub(r"\s", "-", text.strip())


def inline(text: str) -> str:
    codes: list[str] = []

    def stash(m: re.Match) -> str:
        codes.append(f"<code>{html.escape(m.group(1))}</code>")
        return f"\x00{len(codes) - 1}\x00"

    text = re.sub(r"`([^`]+)`", stash, text)
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], text)


def split_row(line: str) -> list[str]:
    cells = re.split(r"(?<!\\)\|", line.strip().strip("|"))
    return [c.strip().replace("\\|", "|") for c in cells]


def convert(md: str) -> tuple[str, str, list[tuple[str, str]]]:
    lines = md.splitlines()
    out: list[str] = []
    toc: list[tuple[str, str]] = []
    title = ""
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            lang = line[3:].strip()
            body = []
            i += 1
            while not lines[i].startswith("```"):
                body.append(lines[i])
                i += 1
            out.append(f'<pre><code class="language-{lang}">{html.escape(chr(10).join(body))}</code></pre>')
        elif m := re.match(r"(#{1,3}) (.+)", line):
            level, text = len(m.group(1)), m.group(2)
            if level == 1:
                title = text
                out.append(f"<h1>{inline(text)}</h1>")
            else:
                sid = slug(text)
                if level == 2 and text != "Contents":
                    toc.append((sid, text))
                out.append(f'<h{level} id="{sid}">{inline(text)}</h{level}>')
        elif line.startswith("|"):
            header = split_row(line)
            i += 2  # skip the separator row
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(split_row(lines[i]))
                i += 1
            i -= 1
            head = "".join(f"<th>{inline(c)}</th>" for c in header)
            body = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows)
            out.append(f'<div class="table"><table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>')
        elif line.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].startswith(">"):
                quote.append(lines[i].lstrip("> "))
                i += 1
            i -= 1
            out.append(f"<blockquote><p>{inline(' '.join(quote))}</p></blockquote>")
        elif re.match(r"(- |\d+\. )", line):
            ordered = line[0].isdigit()
            items = []
            while i < len(lines) and re.match(r"(- |\d+\. )", lines[i]):
                items.append(re.sub(r"^(- |\d+\. )", "", lines[i]))
                i += 1
            i -= 1
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{inline(t)}</li>" for t in items) + f"</{tag}>")
        elif line.strip():
            para = [line]
            while i + 1 < len(lines) and lines[i + 1].strip() and not re.match(r"(#|```|\||>|- |\d+\. )", lines[i + 1]):
                i += 1
                para.append(lines[i])
            out.append(f"<p>{inline(' '.join(para))}</p>")
        i += 1
    return title, "\n".join(out), toc


TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="How to use Speakeasy, the macOS menu bar manager.">
<style>
:root {{
  --bg: #fbfaf8; --fg: #1d1b20; --muted: #6b6772; --card: #ffffff; --line: #e4e0e8;
  --accent: #6d4aff; --accent-soft: #efeaff; --code-bg: #f1eff5; --pre-bg: #1e1b26; --pre-fg: #ece9f5;
}}
@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
    --bg: #15131a; --fg: #ece9f2; --muted: #a29eac; --card: #1e1b26; --line: #332f3d;
    --accent: #a995ff; --accent-soft: #2a2442; --code-bg: #2a2635; --pre-bg: #0f0d14; --pre-fg: #ece9f5;
  }}
}}
:root[data-theme="dark"] {{
  --bg: #15131a; --fg: #ece9f2; --muted: #a29eac; --card: #1e1b26; --line: #332f3d;
  --accent: #a995ff; --accent-soft: #2a2442; --code-bg: #2a2635; --pre-bg: #0f0d14; --pre-fg: #ece9f5;
}}
* {{ box-sizing: border-box; }}
html {{ scroll-behavior: smooth; scroll-padding-top: 1.5rem; }}
body {{
  margin: 0; background: var(--bg); color: var(--fg);
  font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}}
.layout {{ display: grid; grid-template-columns: 17rem minmax(0, 1fr); max-width: 72rem; margin: 0 auto; }}
nav {{
  position: sticky; top: 0; align-self: start; height: 100vh; overflow-y: auto;
  padding: 2rem 1rem 2rem 1.5rem; border-right: 1px solid var(--line);
}}
nav .brand {{ font-weight: 700; font-size: 1.1rem; display: flex; align-items: center; gap: .5rem; margin-bottom: 1.25rem; }}
nav a {{ display: block; padding: .3rem .6rem; border-radius: 6px; color: var(--muted); text-decoration: none; font-size: .92rem; }}
nav a:hover {{ background: var(--accent-soft); color: var(--accent); }}
main {{ padding: 2.5rem clamp(1rem, 4vw, 3rem) 5rem; min-width: 0; }}
main > * {{ max-width: 46rem; }}
h1 {{ font-size: 2.2rem; line-height: 1.2; margin: 0 0 .5rem; }}
h2 {{ font-size: 1.5rem; margin: 3rem 0 .75rem; padding-top: 1.5rem; border-top: 1px solid var(--line); }}
h3 {{ font-size: 1.12rem; margin: 2rem 0 .5rem; }}
a {{ color: var(--accent); }}
p, li {{ margin: .6rem 0; }}
ul, ol {{ padding-left: 1.4rem; }}
code {{ background: var(--code-bg); padding: .12em .4em; border-radius: 5px; font: .88em ui-monospace, SFMono-Regular, Menlo, monospace; }}
pre {{ background: var(--pre-bg); color: var(--pre-fg); padding: 1rem 1.2rem; border-radius: 10px; overflow-x: auto; }}
pre code {{ background: none; padding: 0; color: inherit; font-size: .86rem; }}
blockquote {{ margin: 1rem 0; padding: .1rem 1rem; background: var(--accent-soft); border-left: 4px solid var(--accent); border-radius: 0 8px 8px 0; }}
.table {{ overflow-x: auto; margin: 1rem 0; border: 1px solid var(--line); border-radius: 10px; background: var(--card); }}
table {{ border-collapse: collapse; width: 100%; font-size: .94rem; }}
th, td {{ text-align: left; padding: .6rem .85rem; vertical-align: top; border-bottom: 1px solid var(--line); }}
th {{ font-size: .8rem; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); }}
tr:last-child td {{ border-bottom: 0; }}
.theme {{ position: fixed; top: 1rem; right: 1rem; border: 1px solid var(--line); background: var(--card); color: var(--fg);
  border-radius: 999px; padding: .35rem .8rem; cursor: pointer; font: inherit; font-size: .85rem; }}
@media (max-width: 52rem) {{
  .layout {{ display: block; }}
  nav {{ position: static; height: auto; border-right: 0; border-bottom: 1px solid var(--line); padding: 1rem; }}
  nav .links {{ display: flex; flex-wrap: wrap; gap: .25rem; }}
  main {{ padding: 1.5rem 1rem 4rem; }}
  .theme {{ top: .5rem; right: .5rem; }}
}}
</style>
</head>
<body>
<button class="theme" id="theme" type="button" aria-label="Toggle dark mode">Theme</button>
<div class="layout">
<nav aria-label="Contents">
  <div class="brand">🍸 Speakeasy</div>
  <div class="links">
{toc}
  </div>
</nav>
<main>
{body}
</main>
</div>
<script>
(function () {{
  var root = document.documentElement, key = "speakeasy-docs-theme";
  try {{ var saved = localStorage.getItem(key); if (saved) root.dataset.theme = saved; }} catch (e) {{}}
  document.getElementById("theme").addEventListener("click", function () {{
    var dark = root.dataset.theme ? root.dataset.theme === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
    root.dataset.theme = dark ? "light" : "dark";
    try {{ localStorage.setItem(key, root.dataset.theme); }} catch (e) {{}}
  }});
}})();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    title, body, toc = convert((DOCS / "USAGE.md").read_text())
    toc_html = "\n".join(f'    <a href="#{sid}">{html.escape(text)}</a>' for sid, text in toc)
    (DOCS / "index.html").write_text(TEMPLATE.format(title=html.escape(title), toc=toc_html, body=body))
    print("wrote docs/index.html")
