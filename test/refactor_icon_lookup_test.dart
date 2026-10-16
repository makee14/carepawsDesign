import 'package:carepaws/design/icons.dart';
import 'package:flutter_test/flutter_test.dart';

/// Refactor pin for the Ic.byName switch -> map move (ponytail pass).
/// Every seed icon name must resolve to its own glyph, and anything else
/// must fall back to the info glyph — never a blank. Green before the
/// move and green after; a dropped or mis-keyed entry fails loudly.
void main() {
  test('byName resolves every icon name to its glyph', () {
    expect(Ic.byName('home'), Ic.home, reason: 'home');
    expect(Ic.byName('chat'), Ic.chat, reason: 'chat');
    expect(Ic.byName('calendar'), Ic.calendar, reason: 'calendar');
    expect(Ic.byName('bag'), Ic.bag, reason: 'bag');
    expect(Ic.byName('person'), Ic.person, reason: 'person');
    expect(Ic.byName('search'), Ic.search, reason: 'search');
    expect(Ic.byName('bell'), Ic.bell, reason: 'bell');
    expect(Ic.byName('chevronRight'), Ic.chevronRight, reason: 'chevronRight');
    expect(Ic.byName('chevronLeft'), Ic.chevronLeft, reason: 'chevronLeft');
    expect(Ic.byName('chevronDown'), Ic.chevronDown, reason: 'chevronDown');
    expect(Ic.byName('close'), Ic.close, reason: 'close');
    expect(Ic.byName('plus'), Ic.plus, reason: 'plus');
    expect(Ic.byName('minus'), Ic.minus, reason: 'minus');
    expect(Ic.byName('check'), Ic.check, reason: 'check');
    expect(Ic.byName('checkCircle'), Ic.checkCircle, reason: 'checkCircle');
    expect(Ic.byName('heart'), Ic.heart, reason: 'heart');
    expect(Ic.byName('star'), Ic.star, reason: 'star');
    expect(Ic.byName('phone'), Ic.phone, reason: 'phone');
    expect(Ic.byName('clock'), Ic.clock, reason: 'clock');
    expect(Ic.byName('pin'), Ic.pin, reason: 'pin');
    expect(Ic.byName('doc'), Ic.doc, reason: 'doc');
    expect(Ic.byName('cart'), Ic.cart, reason: 'cart');
    expect(Ic.byName('camera'), Ic.camera, reason: 'camera');
    expect(Ic.byName('truck'), Ic.truck, reason: 'truck');
    expect(Ic.byName('bookmark'), Ic.bookmark, reason: 'bookmark');
    expect(Ic.byName('stethoscope'), Ic.stethoscope, reason: 'stethoscope');
    expect(Ic.byName('image'), Ic.image, reason: 'image');
    expect(Ic.byName('shield'), Ic.shield, reason: 'shield');
    expect(Ic.byName('heartPulse'), Ic.heartPulse, reason: 'heartPulse');
    expect(Ic.byName('pill'), Ic.pill, reason: 'pill');
    expect(Ic.byName('scissors'), Ic.scissors, reason: 'scissors');
    expect(Ic.byName('syringe'), Ic.syringe, reason: 'syringe');
    expect(Ic.byName('trash'), Ic.trash, reason: 'trash');
    expect(Ic.byName('pencil'), Ic.pencil, reason: 'pencil');
    expect(Ic.byName('info'), Ic.info, reason: 'info');
    expect(Ic.byName('alert'), Ic.alert, reason: 'alert');
    expect(Ic.byName('sparkle'), Ic.sparkle, reason: 'sparkle');
    expect(Ic.byName('moon'), Ic.moon, reason: 'moon');
    expect(Ic.byName('globe'), Ic.globe, reason: 'globe');
    expect(Ic.byName('lock'), Ic.lock, reason: 'lock');
    expect(Ic.byName('settings'), Ic.settings, reason: 'settings');
    expect(Ic.byName('paw'), Ic.paw, reason: 'paw');
    expect(Ic.byName('pawHeart'), Ic.pawHeart, reason: 'pawHeart');
    expect(Ic.byName('qr'), Ic.qr, reason: 'qr');
    expect(Ic.byName('wallet'), Ic.wallet, reason: 'wallet');
    expect(Ic.byName('gift'), Ic.gift, reason: 'gift');
    expect(Ic.byName('barcode'), Ic.barcode, reason: 'barcode');
    expect(Ic.byName('droplet'), Ic.droplet, reason: 'droplet');
    expect(Ic.byName('sun'), Ic.sun, reason: 'sun');
    expect(Ic.byName('monitor'), Ic.monitor, reason: 'monitor');
    expect(Ic.byName('refresh'), Ic.refresh, reason: 'refresh');
    expect(Ic.byName('download'), Ic.download, reason: 'download');
    expect(Ic.byName('upload'), Ic.upload, reason: 'upload');
    expect(Ic.byName('send'), Ic.send, reason: 'send');
    expect(Ic.byName('filter'), Ic.filter, reason: 'filter');
    expect(Ic.byName('scale'), Ic.scale, reason: 'scale');
    expect(Ic.byName('tooth'), Ic.tooth, reason: 'tooth');
    expect(Ic.byName('clipboard'), Ic.clipboard, reason: 'clipboard');
    expect(Ic.byName('logout'), Ic.logout, reason: 'logout');
    expect(Ic.byName('language'), Ic.language, reason: 'language');
    expect(Ic.byName('plusCircle'), Ic.plusCircle, reason: 'plusCircle');
    expect(Ic.byName('arrowRight'), Ic.arrowRight, reason: 'arrowRight');
    expect(Ic.byName('arrowUp'), Ic.arrowUp, reason: 'arrowUp');
    expect(Ic.byName('card2'), Ic.card2, reason: 'card2');
    expect(Ic.byName('cash'), Ic.cash, reason: 'cash');
    expect(Ic.byName('cat'), Ic.cat, reason: 'cat');
    expect(Ic.byName('dog'), Ic.dog, reason: 'dog');
    expect(Ic.byName('bone'), Ic.bone, reason: 'bone');
    expect(Ic.byName('eye'), Ic.eye, reason: 'eye');
    expect(Ic.byName('fire'), Ic.fire, reason: 'fire');
  });

  test('byName falls back to info for unknown names', () {
    expect(Ic.byName('no-such-icon'), Ic.info);
    expect(Ic.byName(''), Ic.info);
    expect(Ic.byName('HOME'), Ic.info);
  });
}
