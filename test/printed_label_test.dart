import 'package:flutter_test/flutter_test.dart';
import 'package:diafootcare_new/features/wound/analysis/services/ai_service.dart';

/// The segmenter reads the small magenta calibration ring as granulation
/// tissue: on 153 clinic photographs it measured the label instead of the wound
/// in 40% of small-label shots, returning the ring's own 1.5 cm diameter — which
/// matched one patient's clinical figure by coincidence.
///
/// These tests pin the rule that refuses it. The threshold is not arbitrary: on
/// that set the ten labels actually measured scored 0.59–0.87 white surround and
/// the 126 real wounds at most 0.25, so 0.40 sits in an empty gap. The cases
/// below are written around those two figures.
void main() {
  /// A grid with one filled rectangle of region id 1.
  List<List<int>> gridWithBlob(int w, int h, int x0, int y0, int x1, int y1) {
    final g = List.generate(h, (_) => List.filled(w, 0));
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        g[y][x] = 1;
      }
    }
    return g;
  }

  group('isPrintedLabelRegion', () {
    test('a blob surrounded by white card is the label', () {
      expect(
        isPrintedLabelRegion(
          ids: gridWithBlob(40, 40, 15, 15, 24, 24),
          id: 1,
          box: const [15, 15, 24, 24],
          isPaper: (x, y) => true,
        ),
        isTrue,
      );
    });

    test('a blob surrounded by skin is a wound', () {
      expect(
        isPrintedLabelRegion(
          ids: gridWithBlob(40, 40, 15, 15, 24, 24),
          id: 1,
          box: const [15, 15, 24, 24],
          isPaper: (x, y) => false,
        ),
        isFalse,
      );
    });

    test('the field value of a real wound (0.25 surround) is kept', () {
      // Paper on the left quarter of the collar only.
      expect(
        isPrintedLabelRegion(
          ids: gridWithBlob(60, 60, 20, 20, 39, 39),
          id: 1,
          box: const [20, 20, 39, 39],
          isPaper: (x, y) => x < 25,
          whiteSurround: 0.40,
        ),
        isFalse,
      );
    });

    test('the field value of a measured label (0.59+ surround) is refused', () {
      // Paper everywhere except a narrow strip: comfortably above the threshold.
      expect(
        isPrintedLabelRegion(
          ids: gridWithBlob(60, 60, 20, 20, 39, 39),
          id: 1,
          box: const [20, 20, 39, 39],
          isPaper: (x, y) => y > 24,
          whiteSurround: 0.40,
        ),
        isTrue,
      );
    });

    test('only the collar is inspected, never the region itself', () {
      // Every pixel INSIDE the blob is paper-white, none outside it is. If the
      // interior leaked into the count this would read as a label.
      final ids = gridWithBlob(40, 40, 15, 15, 24, 24);
      expect(
        isPrintedLabelRegion(
          ids: ids,
          id: 1,
          box: const [15, 15, 24, 24],
          isPaper: (x, y) => ids[y][x] == 1,
        ),
        isFalse,
      );
    });

    test('a neighbouring region does not count as this one\'s collar', () {
      // Two blobs 2px apart: the wound (id 2) must not inherit the label's
      // white surround through proximity.
      final ids = gridWithBlob(60, 40, 10, 15, 19, 24);
      for (var y = 15; y <= 24; y++) {
        for (var x = 22; x <= 31; x++) {
          ids[y][x] = 2;
        }
      }
      // Paper only around the left blob, skin around the right one.
      expect(
        isPrintedLabelRegion(
          ids: ids,
          id: 2,
          box: const [22, 15, 31, 24],
          isPaper: (x, y) => x < 21,
        ),
        isFalse,
      );
    });

    test('a region filling the frame is kept, not refused', () {
      // No collar exists, so the question cannot be answered — and deleting a
      // very close-up wound would be worse than measuring a sticker.
      expect(
        isPrintedLabelRegion(
          ids: gridWithBlob(12, 12, 0, 0, 11, 11),
          id: 1,
          box: const [0, 0, 11, 11],
          isPaper: (x, y) => true,
        ),
        isFalse,
      );
    });

    test('a blob against the frame edge still gets judged on the collar it has',
        () {
      expect(
        isPrintedLabelRegion(
          ids: gridWithBlob(40, 40, 0, 0, 9, 9),
          id: 1,
          box: const [0, 0, 9, 9],
          isPaper: (x, y) => true,
        ),
        isTrue,
      );
    });

    test('an empty grid is not a label', () {
      expect(
        isPrintedLabelRegion(
          ids: const [],
          id: 1,
          box: const [0, 0, 0, 0],
          isPaper: (x, y) => true,
        ),
        isFalse,
      );
    });
  });
}
