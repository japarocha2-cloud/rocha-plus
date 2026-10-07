import 'package:flutter/material.dart';
import 'live_tv_screen.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const LiveTvScreen(initialGroup: 'Notícias');
}
