import 'package:flutter/material.dart';
import 'src/lab/functional_lab_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Cast stays unavailable until remote revocation is homologated too.
  runApp(const FunctionalLabApp());
}
