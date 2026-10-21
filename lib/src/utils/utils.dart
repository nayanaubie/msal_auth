import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/models.dart';

final class Utils {
  Utils._();

  /// Creates the arguments for creating public client application.
  /// Argument map will be passed to the native side.
  static Future<Map<String, dynamic>> createPcaArguments({
    required String clientId,
    AndroidConfig? androidConfig,
    AppleConfig? appleConfig,
  }) async {
    final arguments = <String, dynamic>{};
    if (Platform.isAndroid) {
      assert(androidConfig != null, 'Android config can not be null');

      final config = Map<String, dynamic>.of(
        androidConfig!.config ??
            json.decode(
              await rootBundle.loadString(androidConfig.configFilePath!),
            ),
      )..addAll({
          'client_id': clientId,
          'redirect_uri': androidConfig.redirectUri,
        });

      arguments.addAll({'config': config});
    } else if (Platform.isIOS || Platform.isMacOS) {
      assert(appleConfig != null, 'Apple config can not be null');
      arguments.addAll({
        'clientId': clientId,
        'authority': appleConfig!.authority,
        'authorityType': appleConfig.authorityType.name,
        'redirectUri': appleConfig.redirectUri,
        'broker': appleConfig.broker.name,
      });
    }
    return arguments;
  }
}
