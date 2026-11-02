import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the one thing a design system cannot recover from: the font files
/// being missing, unreadable, or declared for the wrong family.
///
/// `flutter test` does not load the fonts declared in `pubspec.yaml`, so this
/// registers them the same way the engine does at launch and then measures the
/// result. A silent fallback to the platform face would otherwise look fine in
/// a screenshot and wrong on every handset.
Future<void> _loadFamily(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}

double _width(String text, {required String family, required int weight}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontSize: 24,
        fontVariations: [FontVariation('wght', weight.toDouble())],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  return painter.width;
}

void main() {
  setUpAll(() async {
    await _loadFamily('Inter', InterPath.value);
    await _loadFamily('Sora', SoraPath.value);
  });

  test('both font files are bundled and parse', () {
    expect(File(InterPath.value).existsSync(), isTrue);
    expect(File(SoraPath.value).existsSync(), isTrue);
    expect(File(InterPath.value).lengthSync(), greaterThan(100 * 1024));
    expect(File(SoraPath.value).lengthSync(), greaterThan(50 * 1024));
  });

  test('pubspec declares both families with their variable files', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('family: Inter'));
    expect(pubspec, contains('family: Sora'));
    expect(pubspec, contains(InterPath.value));
    expect(pubspec, contains(SoraPath.value));
  });

  test('the Inter weight axis changes the rendered width', () {
    const sample = 'PeerPass helps students get unstuck';

    final regular = _width(sample, family: 'Inter', weight: 400);
    final extraBold = _width(sample, family: 'Inter', weight: 800);

    expect((extraBold - regular).abs(), greaterThan(0.5));
  });

  test('the Sora weight axis changes the rendered width', () {
    const sample = 'What is giving you trouble?';

    final regular = _width(sample, family: 'Sora', weight: 400);
    final extraBold = _width(sample, family: 'Sora', weight: 800);

    expect((extraBold - regular).abs(), greaterThan(0.5));
  });

  test('the two families are not the same typeface', () {
    const sample = 'Session with Sarah';

    final inter = _width(sample, family: 'Inter', weight: 700);
    final sora = _width(sample, family: 'Sora', weight: 700);

    expect((sora - inter).abs(), greaterThan(0.5));
  });
}

/// The asset paths, in one place so the test and its failure messages agree.
abstract final class InterPath {
  static const String value = 'assets/fonts/Inter-Variable.ttf';
}

abstract final class SoraPath {
  static const String value = 'assets/fonts/Sora-Variable.ttf';
}
