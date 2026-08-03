# Building the Models Documentation PDF

The documentation is now authored as an **editable HTML source** rather than in
Google Docs, so it can be version-controlled and regenerated deterministically.

## Files
- `DaiFootCare_Models_Documentation.html` — the editable source (all text, tables,
  callouts, and the Figure 1 dataflow diagram as inline SVG).
- `stamp_pdf.py` — stamps the running header and `Page N of M` footer into the
  page margins after rendering.
- `DaiFootCare_Models_Documentation.pdf` — the rendered output (also copied to the
  project root).
- `DaiFootCare_Models_Documentation_v1.0_original.pdf` — the previous Google Docs
  export (v1.0), kept for reference.

## Rebuild (Windows, Git Bash)
```bash
cd docs
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
ABS=$(python -c "import pathlib;print(pathlib.Path('DaiFootCare_Models_Documentation.html').resolve().as_uri())")
"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$(pwd -W)/_raw.pdf" "$ABS"
python stamp_pdf.py _raw.pdf DaiFootCare_Models_Documentation.pdf
rm _raw.pdf
cp DaiFootCare_Models_Documentation.pdf ../DaiFootCare_Models_Documentation.pdf
```
Requires Google Chrome and `pymupdf` (`pip install pymupdf`).

## Editing notes
- Section page breaks use `class="page"` (break after) and `class="newsec"`
  (break before). If you add/remove content, re-check the Contents page numbers.
- To change the version, update the title block, the running-header/footer text in
  `stamp_pdf.py`, and add a bullet to the Revision note.

## v1.1 change (26 July 2026)
Wound **depth** was removed from the pipeline and UI (a 2-D photo cannot recover
true depth; the old value was a pixel-density heuristic). The reference-object
scale-calibration and manual-depth capture steps were retired, so measurements now
run uncalibrated (length/width/area only, relative-area trend). Figure 1 and
sections 1.2, 2.1, 2.4, 2.5, 2.7 and 6 were updated. Segmentation network, training
and metrics are unchanged.
