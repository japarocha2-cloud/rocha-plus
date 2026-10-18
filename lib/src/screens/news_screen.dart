import 'package:flutter/material.dart';
import 'live_tv_screen.dart';

class NewsScreen extends StatelessWidget {
  final String? accountId;
  const NewsScreen({super.key, this.accountId});
  @override
  Widget build(BuildContext context) =>
      LiveTvScreen(initialGroup: 'Notícias', accountId: accountId);
}
