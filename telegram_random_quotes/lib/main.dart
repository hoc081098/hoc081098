import 'dart:io';

import 'package:http_client_hoc081098/http_client_hoc081098.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart_ext/rxdart_ext.dart';

void main() async {
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
      level: SimpleLogLevel.none,
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

  // await simpleHttpClient.getJson(
  //   Uri.https(
  //     'api.telegram.org',
  //     '/bot$botToken/getUpdates',
  //   ),
  // );

  await getQuote(simpleHttpClient)
      .exhaustMap(
        (quote) => Stream.fromIterable(chatIds).asyncExpand(
          (chatId) => send(
            simpleHttpClient: simpleHttpClient,
            quote: quote,
            chatId: chatId,
            botToken: botToken,
          ),
        ),
      )
      .forEach((_) {});

  simpleHttpClient.close();
}

Single<Quote> getQuote(SimpleHttpClient simpleHttpClient) =>
    useCancellationToken(
      (cancelToken) => simpleHttpClient.getJson(
        Uri.parse('https://zenquotes.io/api/random'),
        cancelToken: cancelToken,
      ),
    ).map((json) => Quote.fromJson(json[0]));

Single<void> send({
  required SimpleHttpClient simpleHttpClient,
  required Quote quote,
  required String chatId,
  required String botToken,
}) =>
    useCancellationToken((cancelToken) {
      final uri = Uri.https(
        'api.telegram.org',
        '/bot$botToken/sendMessage',
        {
          'chat_id': chatId,
          'text': '''
**${quote.quote}** - _${quote.author}_
Have a nice day ❤️!
-------------------
- This message is sent by a bot (@hoc081098).
- Source code: [telegram_random_quotes](https://github.com/hoc081098/hoc081098/tree/master/telegram_random_quotes)
      ''',
          'parse_mode': 'Markdown',
        },
      );

      return simpleHttpClient.getJson(
        uri,
        cancelToken: cancelToken,
      );
    });

class Quote {
  final String quote;
  final String author;

  Quote({
    required this.quote,
    required this.author,
  });

  factory Quote.fromJson(Map<String, dynamic> json) =>
      Quote(quote: json['q'], author: json['a']);
}
