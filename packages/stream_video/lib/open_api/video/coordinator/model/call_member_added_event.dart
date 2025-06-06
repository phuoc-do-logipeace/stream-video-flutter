//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CallMemberAddedEvent {
  /// Returns a new [CallMemberAddedEvent] instance.
  CallMemberAddedEvent({
    required this.call,
    required this.callCid,
    required this.createdAt,
    this.members = const [],
    this.type = 'call.member_added',
  });

  CallResponse call;

  String callCid;

  DateTime createdAt;

  /// the members added to this call
  List<MemberResponse> members;

  /// The type of event: \"call.member_added\" in this case
  String type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallMemberAddedEvent &&
          other.call == call &&
          other.callCid == callCid &&
          other.createdAt == createdAt &&
          _deepEquality.equals(other.members, members) &&
          other.type == type;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (call.hashCode) +
      (callCid.hashCode) +
      (createdAt.hashCode) +
      (members.hashCode) +
      (type.hashCode);

  @override
  String toString() =>
      'CallMemberAddedEvent[call=$call, callCid=$callCid, createdAt=$createdAt, members=$members, type=$type]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'call'] = this.call;
    json[r'call_cid'] = this.callCid;
    json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    json[r'members'] = this.members;
    json[r'type'] = this.type;
    return json;
  }

  /// Returns a new [CallMemberAddedEvent] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CallMemberAddedEvent? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "CallMemberAddedEvent[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "CallMemberAddedEvent[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CallMemberAddedEvent(
        call: CallResponse.fromJson(json[r'call'])!,
        callCid: mapValueOfType<String>(json, r'call_cid')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        members: MemberResponse.listFromJson(json[r'members']),
        type: mapValueOfType<String>(json, r'type')!,
      );
    }
    return null;
  }

  static List<CallMemberAddedEvent> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CallMemberAddedEvent>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallMemberAddedEvent.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CallMemberAddedEvent> mapFromJson(dynamic json) {
    final map = <String, CallMemberAddedEvent>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CallMemberAddedEvent.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CallMemberAddedEvent-objects as value to a dart map
  static Map<String, List<CallMemberAddedEvent>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<CallMemberAddedEvent>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CallMemberAddedEvent.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'call',
    'call_cid',
    'created_at',
    'members',
    'type',
  };
}
