import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:video_player/video_player.dart';
import 'live/channel_repository.dart';
import 'screens/intro_screen.dart';
import 'theme/rocha_theme.dart';

/// C7 sideload entry: approved Android theme and intro, no commercial auth.
class RochaFullUiLabApp extends StatefulWidget {
  final ChannelRepository? repository;
  final VideoPlayerController Function()? introControllerFactory;
  const RochaFullUiLabApp({super.key, this.repository, this.introControllerFactory});
  @override
  State<RochaFullUiLabApp> createState() => _RochaFullUiLabAppState();
}

class _RochaFullUiLabAppState extends State<RochaFullUiLabApp> {
  bool introFinished = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rocha+ LAB',
    debugShowCheckedModeBanner: false,
    theme: RochaTheme.dark,
    home: introFinished
        ? HomeScreen(laboratoryFeatures: true, repository: widget.repository)
        : IntroScreen(controllerFactory: widget.introControllerFactory, onFinished: () => setState(() => introFinished = true)),
  );
}
