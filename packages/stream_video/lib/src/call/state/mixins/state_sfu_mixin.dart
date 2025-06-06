import 'package:collection/collection.dart';
import 'package:state_notifier/state_notifier.dart';

import '../../../../stream_video.dart';
import '../../../models/call_participant_pin.dart';
import '../../../sfu/data/events/sfu_events.dart';
import '../../../sfu/data/models/sfu_pin.dart';
import '../../../sfu/sfu_extensions.dart';

final _logger = taggedLogger(tag: 'SV:CoordNotifier');

mixin StateSfuMixin on StateNotifier<CallState> {
  void sfuParticipantLeft(
    SfuParticipantLeftEvent event,
  ) {
    _logger.d(() => '[sfuParticipantLeft] ${state.sessionId}; event: $event');
    final callParticipants = [...state.callParticipants]..removeWhere(
        (participant) =>
            participant.userId == event.participant.userId &&
            participant.sessionId == event.participant.sessionId,
      );

    state = state.copyWith(
      callParticipants: callParticipants,
    );
  }

  void sfuJoinResponse(
    SfuJoinResponseEvent event,
  ) {
    _logger.d(() => '[sfuJoinResponse] ${state.sessionId}; event: $event');
    final participants = event.callState.participants
        .map((sfuParticipant) => sfuParticipant.toParticipantState(state))
        .toList();

    state = state.copyWith(
      callParticipants: participants,
    );
  }

  void sfuCallEnded(
    SfuCallEndedEvent event,
  ) {
    _logger.d(() => '[sfuCallEnded] ${state.sessionId}; event: $event');

    state = state.copyWith(
      status: CallStatus.disconnected(
        DisconnectReason.ended(),
      ),
      callParticipants: const [],
    );
  }

  void sfuTrackUnpublished(
    SfuTrackUnpublishedEvent event,
  ) {
    _logger.d(
      () => '[sfuTrackUnpublished] ${state.sessionId}; event: $event',
    );
    state = state.copyWith(
      callParticipants: state.callParticipants.map((participant) {
        if (participant.userId == event.userId &&
            participant.sessionId == event.sessionId) {
          final trackState = participant.publishedTracks[event.trackType]
              ?.copyWith(muted: true);

          return participant.copyWith(
            publishedTracks: {
              ...participant.publishedTracks,
              if (trackState != null) event.trackType: trackState,
            },
          );
        }

        return participant;
      }).toList(),
    );
  }

  void sfuTrackPublished(
    SfuTrackPublishedEvent event,
  ) {
    _logger.d(() => '[sfuTrackPublished] ${state.sessionId}; event: $event');

    state = state.copyWith(
      callParticipants: state.callParticipants.map((participant) {
        if (participant.userId == event.userId &&
            participant.sessionId == event.sessionId) {
          _logger.v(() => '[sfuTrackPublished] pFound: $participant');

          final trackState = participant.publishedTracks[event.trackType]
                  ?.copyWith(muted: false) ??
              TrackState.base(isLocal: participant.isLocal);
          return participant.copyWith(
            publishedTracks: {
              ...participant.publishedTracks,
              event.trackType: trackState,
            },
          );
        } else {
          _logger.v(() => '[sfuTrackPublished] pSame: $participant');
          return participant;
        }
      }).toList(),
    );
  }

  void sfuUpdateAudioLevelChanged(
    SfuAudioLevelChangedEvent event,
  ) {
    state = state.copyWith(
      callParticipants: state.callParticipants.map((participant) {
        final levelInfo = event.audioLevels.firstWhereOrNull((level) {
          return level.userId == participant.userId &&
              level.sessionId == participant.sessionId;
        });
        if (levelInfo != null) {
          return participant.copyWithUpdatedAudioLevels(
            audioLevel: levelInfo.level,
            isSpeaking: levelInfo.isSpeaking,
          );
        } else {
          return participant;
        }
      }).toList(),
    );
  }

  void sfuDominantSpeakerChanged(
    SfuDominantSpeakerChangedEvent event,
  ) {
    state = state.copyWith(
      callParticipants: state.callParticipants.map((participant) {
        // Mark the new dominant speaker
        if (participant.userId == event.userId &&
            participant.sessionId == event.sessionId) {
          return participant.copyWith(
            isDominantSpeaker: true,
          );
        }
        // Unmark the old dominant speaker
        if (participant.isDominantSpeaker) {
          return participant.copyWith(
            isDominantSpeaker: false,
          );
        }
        return participant;
      }).toList(),
    );
  }

  void sfuPinsUpdated(
    List<SfuPin> pins,
  ) {
    state = state.copyWith(
      callParticipants: state.callParticipants.map((participant) {
        final pin = pins.firstWhereOrNull((it) {
          return it.userId == participant.userId &&
              it.sessionId == participant.sessionId;
        });
        if (pin != null) {
          return participant.copyWithPin(
            participantPin: CallParticipantPin(
              isLocalPin: false,
              pinnedAt: DateTime.now(),
            ),
          );
        } else if (participant.pin != null && !participant.pin!.isLocalPin) {
          return participant.copyWithPin(
            participantPin: null,
          );
        } else {
          return participant;
        }
      }).toList(),
    );
  }

  void sfuConnectionQualityChanged(
    SfuConnectionQualityChangedEvent event,
  ) {
    state = state.copyWith(
      callParticipants: state.callParticipants.map((participant) {
        final update = event.connectionQualityUpdates.firstWhereOrNull((it) {
          return it.userId == participant.userId &&
              it.sessionId == participant.sessionId;
        });
        if (update != null) {
          return participant.copyWith(
            connectionQuality: update.connectionQuality,
          );
        } else {
          return participant;
        }
      }).toList(),
    );
  }

  void sfuParticipantJoined(
    SfuParticipantJoinedEvent event,
  ) {
    _logger.d(
      () => '[sfuParticipantJoined] ${state.sessionId}; event: $event',
    );
    final isLocal = state.currentUserId == event.participant.userId &&
        state.sessionId == event.participant.sessionId;

    final participant = CallParticipantState(
      userId: event.participant.userId,
      roles: event.participant.roles,
      name: event.participant.userName,
      custom: event.participant.custom,
      image: event.participant.userImage,
      sessionId: event.participant.sessionId,
      trackIdPrefix: event.participant.trackLookupPrefix,
      isLocal: isLocal,
      isOnline: !isLocal,
    );
    var isExisting = false;
    final participants = state.callParticipants.map((it) {
      if (it.userId == participant.userId &&
          it.sessionId == participant.sessionId) {
        isExisting = true;
        return participant;
      } else {
        return it;
      }
    });
    state = state.copyWith(
      callParticipants: [
        ...participants,
        if (!isExisting) participant,
      ],
    );
  }

  void sfuParticipantUpdated(
    SfuParticipantUpdatedEvent event,
  ) {
    _logger.d(
      () => '[sfuParticipantUpdated] ${state.sessionId}; event: $event',
    );
    final participant = event.participant;

    final participants = state.callParticipants.map((it) {
      if (it.userId == participant.userId &&
          it.sessionId == participant.sessionId) {
        return it
            .copyWith(
              name: participant.userName,
              custom: participant.custom,
              image: participant.userImage,
              trackIdPrefix: participant.trackLookupPrefix,
              isSpeaking: participant.isSpeaking,
              isDominantSpeaker: participant.isDominantSpeaker,
              connectionQuality: participant.connectionQuality,
              roles: participant.roles,
            )
            .copyWithUpdatedAudioLevels(audioLevel: participant.audioLevel);
      } else {
        return it;
      }
    });
    state = state.copyWith(
      callParticipants: [
        ...participants,
      ],
    );
  }
}
