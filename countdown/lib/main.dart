import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_client_hoc081098/http_client_hoc081098.dart';
import 'package:rxdart_ext/rxdart_ext.dart';

void main() async {
  final ci = Platform.environment['CI'] == 'true';
  final chatIds = Platform.environment['TELEGRAM_CHAT_IDS']?.split(',');
  final botToken = Platform.environment['TELEGRAM_BOT_TOKEN'];

  if (chatIds == null ||
      chatIds.isEmpty ||
      botToken == null ||
      botToken.isEmpty) {
    print(
        'TELEGRAM_CHAT_IDS or TELEGRAM_BOT_TOKEN environment variable is not set');
    exit(1);
  }

  final loggingInterceptor = SimpleLoggingInterceptor(
    SimpleLogger(
      loggerFunction: print,
      level: ci ? SimpleLogLevel.basic : SimpleLogLevel.body,
    ),
  );

  final simpleHttpClient = SimpleHttpClient(
    client: http.Client(),
    timeout: const Duration(seconds: 20),
    requestInterceptors: [
      loggingInterceptor.requestInterceptor,
    ],
    responseInterceptors: [
      loggingInterceptor.responseInterceptor,
    ],
  );

  await Stream.fromIterable(chatIds)
      .asyncExpand(
        (chatId) => send(
          chatId: chatId,
          botToken: botToken,
          simpleHttpClient: simpleHttpClient,
        ),
      )
      .forEach((_) {});
}

Single<void> send({
  required String chatId,
  required String botToken,
  required SimpleHttpClient simpleHttpClient,
}) =>
    useCancellationToken((cancelToken) {
      final now = DateTime.now();
      final noelDay = DateTime(2022, 12, 25);
      final newYearDay = DateTime(2023, 1, 1);
      final tetHoliday = DateTime(2023, 1, 22);

      final uri = Uri.https(
        'api.telegram.org',
        '/bot$botToken/sendMessage',
        {
          'chat_id': chatId,
          'text': '''
*❤️Countdown❤️*
-------------------
Còn ${noelDay.difference(now).inDays} ngày nữa là Noel.
Còn ${newYearDay.difference(now).inDays} ngày nữa là Tết Dương.
Còn ${tetHoliday.difference(now).inDays} ngày nữa là Tết Âm.
Have a nice day ❤️!
-------------------
- This message is sent by a bot (@hoc081098).
- Source code: [countdown](https://github.com/hoc081098/hoc081098/tree/master/countdown)
      ''',
          'parse_mode': 'Markdown',
        },
      );

      return simpleHttpClient.getJson(
        uri,
        cancelToken: cancelToken,
      );
    });
