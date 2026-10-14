import 'package:flutter/material.dart';
import '../billing/trial_welcome_dialog.dart';
import 'home_screen.dart';

/// Uses the same static alert as the app; preview never grants stream access.
class VisualTrialTestScreen extends StatefulWidget {
  const VisualTrialTestScreen({super.key});

  @override
  State<VisualTrialTestScreen> createState() => _VisualTrialTestScreenState();
}

class _VisualTrialTestScreenState extends State<VisualTrialTestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTrialWelcomeDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) => HomeScreen(
    previewOnly: true, onSignOut: () async {});
}
