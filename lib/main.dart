import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nudge/core/providers/reminder_provider.dart';
import 'package:nudge/services/notification_service.dart';
import 'package:nudge/services/boot_recovery.dart';
import 'package:nudge/ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  // Cold-start self-heal: re-arm alarms wiped by a reboot that
  // BOOT_COMPLETED never reported (suppressed on several OEM skins).
  await BootRecovery.checkAndHeal();
  runApp(const NudgeApp());
}

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReminderProvider(),
      child: MaterialApp(
        title: 'Nudge',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6FA5)),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}