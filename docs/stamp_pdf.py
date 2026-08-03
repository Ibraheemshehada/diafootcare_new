#!/usr/bin/env python3
"""Stamp a running header and 'Page N of M' footer into the top/bottom margins.

Chrome renders the body (docs/DaiFootCare_Models_Documentation.html -> _raw);
this adds the page furniture in the reserved margins, where it can never collide
with flowed content. The title page (page 1) is left clean.
"""
import sys
import pymupdf as fitz

TEAL = (0.122, 0.361, 0.455)   # #1f5c74
MUTED = (0.357, 0.416, 0.447)  # #5b6a72
LINE = (0.84, 0.87, 0.89)

def stamp(src: str, dst: str, header_left: str = "DaiFootCare · AI Models Documentation",
          header_right: str = "Technical Reference · v1.1") -> None:
    doc = fitz.open(src)
    n = doc.page_count
    for i, page in enumerate(doc):
        w, h = page.rect.width, page.rect.height
        if i > 0:  # skip the title page
            # --- running header ---
            page.insert_text((48, 34), header_left,
                             fontname="hebo", fontsize=8.3, color=TEAL)
            tw = fitz.get_text_length(header_right,
                                      fontname="helv", fontsize=8.3)
            page.insert_text((w - 48 - tw, 34), header_right,
                             fontname="helv", fontsize=8.3, color=MUTED)
            page.draw_line((48, 40), (w - 48, 40), color=LINE, width=0.6)
        # --- footer page number (every page) ---
        foot = f"Page {i + 1} of {n}"
        tw = fitz.get_text_length(foot, fontname="helv", fontsize=8.3)
        page.draw_line((48, h - 34), (w - 48, h - 34), color=LINE, width=0.6)
        page.insert_text(((w - tw) / 2, h - 22), foot,
                         fontname="helv", fontsize=8.3, color=MUTED)
    doc.set_metadata({
        "title": "DaiFootCare — AI Models Documentation",
        "author": "DaiFootCare — doctoral research",
        "subject": "On-Device Deep Learning for Diabetic-Foot-Ulcer Assessment "
                   "(v1.1)",
        "keywords": "DFU, segmentation, CLIP, tissue classification, infection, "
                    "ischaemia, TFLite",
    })
    doc.save(dst, garbage=4, deflate=True)
    print(f"stamped {n} pages -> {dst}")

if __name__ == "__main__":
    hl = sys.argv[3] if len(sys.argv) > 3 else "DaiFootCare · AI Models Documentation"
    hr = sys.argv[4] if len(sys.argv) > 4 else "Technical Reference · v1.1"
    stamp(sys.argv[1], sys.argv[2], hl, hr)
