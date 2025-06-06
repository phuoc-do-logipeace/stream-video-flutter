// 📦 Package imports:
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

// 🌎 Project imports:
import '../../utils/consts.dart';
import '../model/environment.dart';
import 'token_service.dart';

class UserChatRepository {
  const UserChatRepository({
    required this.chatClient,
    required this.tokenService,
  });

  final StreamChatClient chatClient;
  final TokenService tokenService;

  OwnUser? get currentUser => chatClient.state.currentUser;

  Future<OwnUser> connectUser(User user, Environment environment) {
    return chatClient.connectUserWithProvider(
      user,
      (userId) => tokenService
          .loadToken(userId: userId, environment: environment)
          .then((response) => response.token),
    );
  }

  Future<void> disconnectUser() => chatClient.disconnectUser();

  Future<Channel> createChannel(String channelId) async {
    final channel = chatClient.channel(kMessageChannelType, id: channelId);
    await channel.watch();
    return channel;
  }
}
