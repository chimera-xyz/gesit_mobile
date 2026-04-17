import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const GesitApp());
}
