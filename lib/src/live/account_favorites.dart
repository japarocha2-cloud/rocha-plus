import 'package:flutter/widgets.dart';
import 'favorites_repository.dart';

class AccountFavorites extends StatefulWidget {
  final String uid;
  final Widget Function(FavoritesRepository) builder;
  final FavoritesRepository Function(String)? repositoryFactory;
  const AccountFavorites({super.key, required this.uid, required this.builder,
    this.repositoryFactory});
  @override
  State<AccountFavorites> createState() => _AccountFavoritesState();
}

class _AccountFavoritesState extends State<AccountFavorites> {
  late FavoritesRepository repository;
  FavoritesRepository _create() => widget.repositoryFactory?.call(widget.uid) ??
    FavoritesRepository.forAccount(widget.uid);
  @override
  void initState() { super.initState(); repository = _create(); }
  @override
  void didUpdateWidget(AccountFavorites oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      repository.dispose();
      repository = _create();
    }
  }
  @override
  void dispose() { repository.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.builder(repository);
}
