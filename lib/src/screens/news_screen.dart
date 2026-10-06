import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notícias'),
          backgroundColor: RochaColors.background,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: const [
            Text(
              'Destaques locais',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Matérias da sua região aparecem primeiro quando a localização é autorizada.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 18),
            _EditorialPlaceholder(),
            SizedBox(height: 28),
            Text(
              'Jornais e informação',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Canais gratuitos e autorizados serão organizados por proximidade e disponibilidade.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 28),
            _SponsoredPlaceholder(),
          ],
        ),
      );
}

class _EditorialPlaceholder extends StatelessWidget {
  const _EditorialPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [
              RochaColors.cosmicPurple,
              RochaColors.cosmicBlue,
              RochaColors.background,
            ],
          ),
        ),
        child: const Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            'Carrossel editorial • matéria local → site original do jornal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
}

class _SponsoredPlaceholder extends StatelessWidget {
  const _SponsoredPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: RochaColors.gold),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PATROCINADO',
              style: TextStyle(
                color: RochaColors.gold,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Espaço comercial regional',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}
