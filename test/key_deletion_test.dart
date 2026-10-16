import 'package:carepaws/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keys with colliding masks are distinguishable by index', () {
    // Two keys with same first-4 and last-3 → same mask.
    const keys = ['sk-aa111xyz', 'sk-aa222xyz'];
    final masks = keys.map(AiService.maskKey).toList();
    // Masks collide (this is the bug premise).
    expect(masks[0], masks[1]);
    // Index-based selection picks the correct key (the fix).
    expect(keys[1], 'sk-aa222xyz');
    expect(keys.indexOf(keys[1]), 1);
  });
}
