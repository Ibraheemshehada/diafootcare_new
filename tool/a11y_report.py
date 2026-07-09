#!/usr/bin/env python3
"""Accessibility sweep helper for the TalkBack / screen-reader check (§11 #5).

Flutter only builds its full semantics tree once an accessibility service is
active, so the flow is:

    adb shell settings put secure enabled_accessibility_services \
        com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
    adb shell settings put secure accessibility_enabled 1
    # ... navigate to the screen under test ...
    adb shell uiautomator dump /sdcard/ui.xml
    adb pull /sdcard/ui.xml
    python tool/a11y_report.py ui.xml

For each screen it writes `<dump>.txt` listing every labelled node (marking the
tappable ones) and — crucially — flags any *clickable* node that exposes no
label or text, i.e. a control a screen-reader user could focus but not
understand. A clean screen reports `clickable-but-unlabeled: 0`.

Remember to turn the service back off afterwards:
    adb shell settings put secure enabled_accessibility_services '""'
    adb shell settings put secure accessibility_enabled 0
"""
import re
import io
import sys


def report(path):
    s = io.open(path, encoding='utf-8').read()
    nodes = re.findall(r'<node[^>]*?/>|<node[^>]*?>', s)
    labeled = []
    clickable_unlabeled = []
    for n in nodes:
        desc = re.search(r'content-desc="([^"]*)"', n)
        text = re.search(r'text="([^"]*)"', n)
        cls = re.search(r'class="([^"]*)"', n)
        clk = 'clickable="true"' in n
        d = desc.group(1) if desc else ''
        t = text.group(1) if text else ''
        c = cls.group(1).split('.')[-1] if cls else '?'
        if d.strip():
            labeled.append((c, clk, d))
        elif clk and not t.strip():
            clickable_unlabeled.append(c)
    with io.open(path + '.txt', 'w', encoding='utf-8') as out:
        out.write('=== %s ===\n' % path)
        out.write('labeled nodes: %d | clickable-but-unlabeled: %d\n\n'
                  % (len(labeled), len(clickable_unlabeled)))
        for c, clk, d in labeled:
            out.write('%s %-14s %s\n' % ('[TAP]' if clk else '     ', c, d))
        if clickable_unlabeled:
            out.write('\n!! clickable nodes with NO label/text:\n')
            for c in clickable_unlabeled:
                out.write('   - %s\n' % c)
    print(path, '-> labeled:', len(labeled),
          '| clickable-unlabeled:', len(clickable_unlabeled))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('usage: python tool/a11y_report.py <uiautomator_dump.xml> ...')
        sys.exit(1)
    for p in sys.argv[1:]:
        report(p)
