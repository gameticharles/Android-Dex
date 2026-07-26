import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adb_device_manager/services/call_state_service.dart';
import 'package:adb_device_manager/ui/incoming_call_banner.dart';

void main() {
  testWidgets('IncomingCallBanner renders incoming call and active call states', (WidgetTester tester) async {
    // 1. Initial State -> Idle -> Nothing rendered
    CallStateService.currentCallState.value = CallStateData.idle();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IncomingCallBanner())));
    expect(find.text("Sophia"), findsNothing);

    // 2. Incoming Call State (Ringing)
    CallStateService.triggerSimulatedCall(name: "Sophia", location: "Shenzhen");
    await tester.pumpAndSettle();
    expect(find.text("Sophia"), findsOneWidget);
    expect(find.text("Shenzhen"), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget); // Green accept button
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget); // Red decline button

    // 3. Active Call State (Connected)
    CallStateService.currentCallState.value = CallStateData(
      state: "ACTIVE",
      name: "Sophia",
      number: "+8613800000000",
      location: "Shenzhen",
      durationSec: 56,
    );
    await tester.pumpAndSettle();
    expect(find.text("Sophia"), findsOneWidget);
    expect(find.text("00:56"), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget); // Speaker toggle button
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget); // End call button
  });
}
