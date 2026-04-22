import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/data/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await PushNotificationService.instance.bootstrap();
  runApp(const GesitApp());
}
