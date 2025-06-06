// 📦 Package imports:
import 'package:flutter/foundation.dart';
// 🌎 Project imports:
import 'package:flutter_dogfooding/core/repos/app_preferences.dart';
import 'package:flutter_dogfooding/core/repos/user_chat_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide User;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_noise_cancellation/noise_cancellation_audio_processor.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import '../app/user_auth_controller.dart';
import '../core/model/environment.dart';
import '../core/repos/custom_environment_loader.dart';
import '../core/repos/token_service.dart';
import '../core/repos/user_auth_repository.dart';
import '../log_config.dart';
import '../utils/consts.dart';

GetIt locator = GetIt.instance;

/// This class is responsible for registering dependencies
/// and injecting them into the app.
class AppInjector {
  // Register dependencies
  static Future<void> init({
    Environment? forceEnvironment,
  }) async {
    // Google sign in
    locator.registerSingleton<GoogleSignIn>(
      GoogleSignIn(hostedDomain: 'getstream.io'),
    );

    // App Preferences
    final prefs = await SharedPreferences.getInstance();
    final appPrefs = AppPreferences(prefs: prefs);

    if (forceEnvironment != null) {
      await appPrefs.setEnvironment(forceEnvironment);
    }

    locator.registerSingleton<AppPreferences>(appPrefs);

    // Repositories
    locator.registerSingleton(
      TokenService(
        customEnvironmentLoader: customEnvironmentLoader,
      ),
    );

    locator.registerFactoryParam<UserAuthRepository, User, TokenResponse>(
      (user, tokenResponse) {
        registerStreamChat(tokenResponse.apiKey);

        // We need to register the video client here because we need it to
        // initialise the user auth repo.
        registerStreamVideo(tokenResponse, user, appPrefs.environment);

        return UserAuthRepository(
          videoClient: locator(),
          tokenService: locator(),
        );
      },
    );

    // App wide Controller
    locator.registerLazySingleton<UserAuthController>(
      dispose: (controller) => controller.dispose(),
      () => UserAuthController(prefs: locator(), tokenService: locator()),
    );
  }

  static void registerStreamChat(String apiKey) {
    locator.registerSingleton<StreamChatClient>(
      _initStreamChat(apiKey),
      dispose: (client) => client.dispose(),
    );

    locator.registerLazySingleton<UserChatRepository>(
      () => UserChatRepository(
        chatClient: locator(),
        tokenService: locator(),
      ),
    );
  }

  static StreamVideo registerStreamVideo(
    TokenResponse tokenResponse,
    User user,
    Environment environment,
  ) {
    _setupLogger();

    return locator.registerSingleton(
      dispose: (_) => StreamVideo.reset(),
      _initStreamVideo(
        tokenResponse.apiKey,
        user,
        initialToken: tokenResponse.token,
        tokenLoader: switch (user.type) {
          UserType.authenticated => (String userId) {
              final tokenService = locator<TokenService>();
              return tokenService
                  .loadToken(userId: userId, environment: environment)
                  .then((response) => response.token);
            },
          _ => null,
        },
      ),
    );
  }

  static Future<void> reset() => locator.reset();
}

StreamLog _setupLogger() {
  const consoleLogger = ConsoleStreamLogger();
  final children = <StreamLogger>[consoleLogger];
  FileStreamLogger? fileLogger;
  if (!kIsWeb) {
    fileLogger = FileStreamLogger(
      AppFileLogConfig('1.0.0'),
      sender: (logFile) async {
        consoleLogger.log(
          Priority.debug,
          'DogFoodingApp',
          () => '[send] logFile: $logFile(${logFile.existsSync()})',
        );

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(logFile.path)],
            subject: 'Share Logs',
            text: 'Stream Flutter Dogfooding Logs',
          ),
        );
      },
      console: consoleLogger,
    );
    children.add(fileLogger);
  }
  return StreamLog()..logger = CompositeStreamLogger(children);
}

StreamChatClient _initStreamChat(String apiKey) {
  final streamChatClient = StreamChatClient(
    apiKey,
    logLevel: Level.INFO,
  );

  return streamChatClient;
}

StreamVideo _initStreamVideo(
  String apiKey,
  User user, {
  String? initialToken,
  TokenLoader? tokenLoader,
}) {
  final streamVideoClient = StreamVideo(
    apiKey,
    user: user,
    tokenLoader: tokenLoader,
    options: StreamVideoOptions(
      logPriority: Priority.debug,
      muteAudioWhenInBackground: false,
      muteVideoWhenInBackground: false,
      keepConnectionsAliveWhenInBackground: true,
      audioProcessor: NoiseCancellationAudioProcessor(),
    ),
    pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
      iosPushProvider: const StreamVideoPushProvider.apn(
        name: 'flutter-apn',
      ),
      androidPushProvider: const StreamVideoPushProvider.firebase(
        name: 'flutter-firebase',
      ),
      pushParams: const StreamVideoPushParams(
        appName: kAppName,
        ios: IOSParams(iconName: 'IconMask'),
      ),
      registerApnDeviceToken: true,
    ),
  );

  return streamVideoClient;
}
