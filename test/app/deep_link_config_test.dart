import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS declares the Supabase OAuth callback scheme', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('<key>CFBundleURLTypes</key>'));
    expect(infoPlist, contains('<string>io.supabase.timeotalk</string>'));
  });

  test('Android declares the Supabase OAuth callback intent filter', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:scheme="io.supabase.timeotalk"'));
    expect(manifest, contains('android:host="login-callback"'));
  });
}
