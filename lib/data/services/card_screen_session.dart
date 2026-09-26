import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// A card temporarily overrides application brightness. On exit, follow the
/// phone setting again instead of pinning the app to an old sampled value.
class CardScreenSession {
  static final controller = CardScreenController(
    brighten: () => ScreenBrightness.instance.setApplicationScreenBrightness(1),
    reset: () => ScreenBrightness.instance.resetApplicationScreenBrightness(),
    wake: WakelockPlus.enable,
    sleep: WakelockPlus.disable,
  );

  final CardScreenController _controller;
  final bool _bright;
  final bool _awake;
  bool _closed = false;
  late final Future<void> ready;

  CardScreenSession({required bool brighten, required bool keepAwake})
      : this._(controller, brighten, keepAwake);

  CardScreenSession._(this._controller, this._bright, this._awake) {
    if (_bright) _controller._brightUsers++;
    if (_awake) _controller._awakeUsers++;
    ready = _controller._schedule();
  }

  Future<void> close() {
    if (_closed) return _controller._pending;
    _closed = true;
    if (_bright) _controller._brightUsers--;
    if (_awake) _controller._awakeUsers--;
    return _controller._schedule();
  }
}

/// Serializes native changes and keeps nested card views from restoring each
/// other's overrides. Injected operations also allow lifecycle regression tests.
class CardScreenController {
  final Future<void> Function() brighten, reset, wake, sleep;
  int _brightUsers = 0;
  int _awakeUsers = 0;
  bool _brightApplied = false;
  bool _awakeApplied = false;
  Future<void> _pending = Future<void>.value();

  CardScreenController({
    required this.brighten,
    required this.reset,
    required this.wake,
    required this.sleep,
  });

  CardScreenSession open({bool brighten = true, bool keepAwake = true}) =>
      CardScreenSession._(this, brighten, keepAwake);

  Future<void> _schedule() {
    _pending = _pending.then((_) async {
      final bright = _brightUsers > 0;
      if (bright != _brightApplied) {
        try {
          await (bright ? brighten() : reset());
          _brightApplied = bright;
        } catch (_) {
          // Platform brightness support must never prevent opening a card.
        }
      }
      final awake = _awakeUsers > 0;
      if (awake != _awakeApplied) {
        try {
          await (awake ? wake() : sleep());
          _awakeApplied = awake;
        } catch (_) {}
      }
    });
    return _pending;
  }
}
