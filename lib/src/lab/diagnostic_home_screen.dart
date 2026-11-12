import 'package:flutter/material.dart';

class DiagnosticHomeScreen extends StatefulWidget {
  final String? accountName;
  final VoidCallback onSignOut;

  const DiagnosticHomeScreen({
    super.key,
    required this.onSignOut,
    this.accountName,
  });

  @override
  State<DiagnosticHomeScreen> createState() => _DiagnosticHomeScreenState();
}

class _DiagnosticHomeScreenState extends State<DiagnosticHomeScreen> {
  int _selectedIndex = 0;

  Widget _statusCard(IconData icon, String title, String detail) => Card(
        child: ListTile(
          leading: Icon(icon, color: Colors.amber.shade300),
          title: Text(title),
          subtitle: Text(detail),
        ),
      );

  Widget _page() {
    switch (_selectedIndex) {
      case 1:
        return ListView(
          key: const ValueKey('diagnostic-session-page'),
          padding: const EdgeInsets.all(20),
          children: [
            _statusCard(
              Icons.verified_user_outlined,
              'Firebase LAB session active',
              widget.accountName?.trim().isNotEmpty == true
                  ? widget.accountName!.trim()
                  : 'Authenticated account for this session.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('diagnostic-sign-out'),
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        );
      case 2:
        return ListView(
          key: const ValueKey('diagnostic-catalog-page'),
          padding: const EdgeInsets.all(20),
          children: [
            _statusCard(
              Icons.live_tv_outlined,
              'Definitive catalog pending',
              'The approved C6 selection is not available in this build.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              icon: Icon(Icons.block),
              label: Text('Channel playback is unavailable in this build'),
            ),
          ],
        );
      default:
        return ListView(
          key: const ValueKey('diagnostic-summary-page'),
          padding: const EdgeInsets.all(20),
          children: [
            _statusCard(
              Icons.login,
              'Login',
              'This app session was authenticated by Firebase LAB.',
            ),
            _statusCard(
              Icons.fact_check_outlined,
              'Authorization',
              'Access confirmed by the entitlementReadOnly endpoint.',
            ),
            _statusCard(
              Icons.touch_app_outlined,
              'Navigation and interface',
              'Explore the Summary, Session, and Catalog tabs.',
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Rocha+ LAB Diagnostic')),
        body: Column(
          children: [
            Container(
              key: const ValueKey('diagnostic-catalog-warning'),
              width: double.infinity,
              color: Colors.amber.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                'LAB DIAGNOSTIC BUILD - definitive catalog pending; channel playback blocked.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: _page()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined), label: 'Summary'),
            NavigationDestination(
                icon: Icon(Icons.account_circle_outlined), label: 'Session'),
            NavigationDestination(
                icon: Icon(Icons.live_tv_outlined), label: 'Catalog'),
          ],
        ),
      );
}
