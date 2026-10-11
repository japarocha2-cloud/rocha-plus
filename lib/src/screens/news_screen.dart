import 'package:flutter/material.dart';
import '../live/channel_repository.dart';
import '../live/favorites_repository.dart';
import 'live_tv_screen.dart';

class NewsScreen extends StatelessWidget {
  final ChannelRepository? repository;
  final FavoritesRepository? favoritesRepository;
  const NewsScreen({super.key, this.repository, this.favoritesRepository});
  @override
  Widget build(BuildContext context) => LiveTvScreen(initialGroup: 'Notícias',
    repository: repository, favoritesRepository: favoritesRepository);
}
