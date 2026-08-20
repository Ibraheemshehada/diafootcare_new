import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diafootcare_new/features/wound/capture/services/live_frame_check.dart';

/// The camera format the live guidance asks for, per platform.
///
/// This is not a preference. iOS accepts `yuv420` and then delivers a
/// **two-plane** biplanar buffer (Y, then interleaved CbCr); Android delivers
/// three separate planes. `LiveFrameCheck` needs three and returns null
/// otherwise — by design, so an unfamiliar format cannot crash the camera.
///
/// Together those two facts made the format request a silent failure. On iOS
/// every frame would have been dropped: no ring, no angle, no guidance — and
/// since "no label in view" deliberately leaves the shutter enabled, the screen
/// would have looked like it was working while checking nothing at all. The
/// angle block that this whole feature exists for would simply never fire.
///
/// Nothing on an Android device or a Windows workstation can show that. Only
/// asserting both branches can, which is why the choice is a function of a bool
/// rather than a read of `Platform.isIOS` buried in a widget.
void main() {
  test('iOS gets BGRA, which is the format it actually delivers', () {
    expect(previewFormatFor(isIOS: true), ImageFormatGroup.bgra8888);
  });

  test('Android keeps YUV420, its three-plane native format', () {
    expect(previewFormatFor(isIOS: false), ImageFormatGroup.yuv420);
  });

  test('the two platforms do not share a format', () {
    // Guards the shortcut of "simplifying" this back to one constant.
    expect(previewFormatFor(isIOS: true),
        isNot(previewFormatFor(isIOS: false)));
  });
}
