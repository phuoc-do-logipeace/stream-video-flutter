import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'call_cid.dart';
import 'call_egress.dart';
import 'call_permission.dart';
import 'call_session_data.dart';
import 'call_settings.dart';

@immutable
class CallMetadata with EquatableMixin {
  const CallMetadata({
    required this.cid,
    required this.details,
    required this.settings,
    required this.session,
    required this.users,
    required this.members,
  });

  final StreamCallCid cid;
  final CallDetails details;
  final CallSettings settings;
  final CallSessionData session;
  final Map<String, CallUser> users;
  final Map<String, CallMember> members;

  @override
  List<Object?> get props => [cid, details, settings, session, users, members];

  @override
  String toString() {
    return 'CallMetadata{cid: $cid, details: $details, settings: $settings, '
        'users: $users, members: $members}';
  }
}

@immutable
class CallDetails with EquatableMixin {
  const CallDetails({
    required this.createdBy,
    required this.team,
    required this.ownCapabilities,
    required this.blockedUserIds,
    required this.broadcasting,
    required this.recording,
    required this.backstage,
    required this.transcribing,
    required this.captioning,
    required this.egress,
    required this.custom,
    required this.rtmpIngress,
    this.joinAheadTimeSeconds,
    this.startsAt,
    this.createdAt,
    this.endedAt,
    this.updatedAt,
  });

  final CallUser createdBy;
  final String team;
  final Iterable<CallPermission> ownCapabilities;
  final List<String> blockedUserIds;
  final bool broadcasting;
  final bool recording;
  final bool backstage;
  final bool transcribing;
  final bool captioning;
  final CallEgress egress;
  final Map<String, Object> custom;
  final String rtmpIngress;
  final int? joinAheadTimeSeconds;
  final DateTime? startsAt;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        createdBy,
        ownCapabilities,
        blockedUserIds,
        broadcasting,
        recording,
        backstage,
        transcribing,
        captioning,
        egress,
        custom,
        rtmpIngress,
        startsAt,
        createdAt,
        createdAt,
        updatedAt,
      ];
}

@immutable
class CallMember with EquatableMixin {
  const CallMember({
    required this.userId,
    required this.roles,
    required this.custom,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String userId;
  final List<String> roles;
  final Map<String, Object?> custom;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  @override
  List<Object?> get props => [
        userId,
        roles,
        createdAt,
        updatedAt,
        deletedAt,
      ];

  @override
  String toString() {
    return 'CallMember{userId: $userId, role: $roles,'
        ' createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt}';
  }
}

@immutable
class CallUser with EquatableMixin {
  const CallUser({
    required this.id,
    required this.name,
    required this.roles,
    required this.image,
    this.custom = const {},
    this.teams = const [],
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory CallUser.empty() => const CallUser(
        id: '',
        name: '',
        roles: [],
        image: '',
      );

  final String id;
  final String name;
  final List<String> roles;
  final String image;
  final Map<String, Object?> custom;
  final List<String> teams;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        roles,
        image,
        teams,
        createdAt,
        updatedAt,
        deletedAt,
        custom,
      ];

  @override
  String toString() {
    return 'CallUser{'
        'id: $id'
        ', name: $name'
        ', role: $roles'
        ', image: $image'
        ', teams: $teams'
        ', createdAt: $createdAt'
        ', updatedAt: $updatedAt'
        ', deletedAt: $deletedAt'
        ', custom: $custom'
        '}';
  }
}
