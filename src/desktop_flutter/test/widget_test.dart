import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adb_device_manager/main.dart';
import 'package:adb_device_manager/app/bootloader_screen.dart';

void main() {
  testWidgets('AdbDeviceManagerApp bootloader renders correctly', (WidgetTester tester) async {
    // Set a desktop surface size for rendering test
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const AdbDeviceManagerApp());
    await tester.pump();

    // Verify BootloaderScreen widget renders on app startup
    expect(find.byType(BootloaderScreen), findsOneWidget);

    // Reset surface size after test
    addTearDown(tester.view.resetPhysicalSize);
  });
}
