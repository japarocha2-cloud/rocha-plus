import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../cast/cast_readiness.dart';
import '../live/validated_lab_repository.dart';
import 'home_screen.dart';

/// Separate debug-package navigation, with no candidate-directory fallback.
class FeatureLabScreen extends StatefulWidget {
  const FeatureLabScreen({super.key});
  @override
  State<FeatureLabScreen> createState() => _FeatureLabScreenState();
}

class _FeatureLabScreenState extends State<FeatureLabScreen> {
  final repository = ValidatedLabRepository();
  @override
  void initState() {
    super.initState();
    CastReadiness.initialize(
      () => GoogleCastContext.instance.setSharedInstanceWithOptions(
        GoogleCastOptionsAndroid(
          appId: GoogleCastDiscoveryCriteria.kDefaultApplicationId,
          stopCastingOnAppTerminated: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => HomeScreen(
    repository: repository,
    laboratoryFeatures: true,
    onSignOut: () async {
      Navigator.pop(context);
    },
  );
}
