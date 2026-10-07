import 'package:flutter/material.dart';
import '../live/channel.dart';
import '../theme/rocha_theme.dart';

class RochaChannelCard extends StatefulWidget {
  final Channel channel;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback? onHide;
  const RochaChannelCard({super.key, required this.channel, required this.onOpen,
    required this.onFavorite, this.favorite = false, this.onHide});
  @override
  State<RochaChannelCard> createState() => _RochaChannelCardState();
}

class _RochaChannelCardState extends State<RochaChannelCard> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF111B21), Color(0xFF09070F)]),
      border: Border.all(color: focused ? RochaColors.gold : const Color(0xFF2D293A),
          width: focused ? 2 : 1),
      boxShadow: focused ? const [BoxShadow(color: Color(0x665A20A8), blurRadius: 18)] : [],
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.onOpen,
      onFocusChange: (value) => setState(() => focused = value),
      focusColor: RochaColors.cosmicPurple.withValues(alpha: .15),
      child: Stack(children: [
        Positioned.fill(child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 48, 22, 80),
          child: widget.channel.logo == null ? const Icon(Icons.live_tv,
              color: RochaColors.playGreen, size: 54) :
            Image.network(widget.channel.logo!, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.live_tv,
                  color: RochaColors.playGreen, size: 54)),
        )),
        Positioned(left: 12, top: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFD60D32),
            borderRadius: BorderRadius.circular(7)),
          child: const Text('● AO VIVO', style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.w900, color: Colors.white)),
        )),
        Positioned(right: 4, top: 2, child: IconButton(
          tooltip: widget.favorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
          onPressed: widget.onFavorite,
          icon: Icon(widget.favorite ? Icons.favorite : Icons.favorite_border,
              color: widget.favorite ? RochaColors.gold : Colors.white),
        )),
        Positioned(left: 12, right: 12, bottom: 12, child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channel.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: Text(widget.channel.group, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12))),
              if (widget.onHide != null) SizedBox(width: 30, height: 30,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero, tooltip: 'Opções de ${widget.channel.name}',
                  onSelected: (_) => widget.onHide!(),
                  itemBuilder: (_) => const [PopupMenuItem(
                    value: 'hide', child: Text('Ocultar canal neste aparelho'))],
                )),
            ]),
          ],
        )),
      ]),
    ),
  );
}
