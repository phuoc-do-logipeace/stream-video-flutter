import 'dart:async';

import 'package:stream_webrtc_flutter/stream_webrtc_flutter.dart' as rtc;

import '../disposable.dart';
import '../errors/video_error_composer.dart';
import '../logger/impl/tagged_logger.dart';
import '../models/call_cid.dart';
import '../utils/none.dart';
import '../utils/result.dart';
import '../utils/standard.dart';
import 'model/stats/rtc_printable_stats.dart';
import 'model/stats/rtc_stats.dart';
import 'model/stats/rtc_stats_mapper.dart';
import 'peer_type.dart';
import 'sdp/editor/sdp_editor.dart';
import 'sdp/sdp.dart';

/// {@template onStreamAdded}
/// Handler when a new [rtc.MediaStream] gets added.
/// {@endtemplate}
typedef OnStreamAdded = void Function(StreamPeerConnection, rtc.MediaStream);

/// {@template onRenegotiationNeeded}
/// Handler when there's a new negotiation.
/// {@endtemplate}
typedef OnRenegotiationNeeded = void Function(StreamPeerConnection);

/// {@template onIceCandidate}
/// Handler whenever we receive [rtc.RTCIceCandidate]s.
/// {@endtemplate}
typedef OnIceCandidate = void Function(
  StreamPeerConnection,
  rtc.RTCIceCandidate,
);

/// {@template onIceCandidate}
/// Handler whenever [rtc.RTCIceConnectionState]s is [rtc.RTCIceConnectionState.RTCIceConnectionStateFailed] or [rtc.RTCIceConnectionState.RTCIceConnectionStateDisconnected].
/// {@endtemplate}
typedef OnIssue = void Function(
  StreamPeerConnection,
);

/// {@template onTrack}
/// Handler whenever we receive [rtc.RTCTrackEvent]s.
/// {@endtemplate}
typedef OnTrack = void Function(
  StreamPeerConnection,
  rtc.RTCTrackEvent,
);

/// Wrapper around the WebRTC connection that contains tracks.
class StreamPeerConnection extends Disposable {
  /// Creates [StreamPeerConnection] instance.
  StreamPeerConnection({
    required this.sessionId,
    required this.callCid,
    required this.type,
    required this.pc,
    required this.sdpEditor,
  }) {
    _initRtcCallbacks();
  }

  final _logger = taggedLogger(tag: 'SV:PeerConnection');

  final String sessionId;
  final StreamCallCid callCid;
  final StreamPeerType type;
  final rtc.RTCPeerConnection pc;
  final SdpEditor sdpEditor;

  /// {@macro onStreamAdded}
  OnStreamAdded? onStreamAdded;

  /// {@macro onRenegotiationNeeded}
  OnRenegotiationNeeded? onRenegotiationNeeded;

  /// {@macro onIceCandidate}
  OnIceCandidate? onIceCandidate;

  OnIssue? onIssue;

  /// {@macro onTrack}
  OnTrack? onTrack;

  final _pendingCandidates = <rtc.RTCIceCandidate>[];

  /// Creates an offer and sets it as the local description.
  Future<Result<rtc.RTCSessionDescription>> createOffer([
    Map<String, dynamic> mediaConstraints = const {},
  ]) async {
    try {
      final localOffer = await pc.createOffer(mediaConstraints);
      final modifiedSdp = sdpEditor.edit(localOffer.sdp?.let(Sdp.localOffer));
      final modifiedOffer = localOffer.copyWith(sdp: modifiedSdp);

      await setLocalDescription(modifiedOffer);
      return Result.success(modifiedOffer);
    } catch (e, stk) {
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  /// Creates an answer and sets it as the local description.
  ///
  /// The remote description must be set before calling this method.
  Future<Result<rtc.RTCSessionDescription>> createAnswer([
    Map<String, dynamic> mediaConstraints = const {},
  ]) async {
    try {
      _logger.v(
        () => '[createLocalAnswer] #$type; mediaConstraints: $mediaConstraints',
      );
      final localAnswer = await pc.createAnswer(mediaConstraints);
      final modifiedSdp = sdpEditor.edit(localAnswer.sdp?.let(Sdp.localAnswer));
      final modifiedAnswer = localAnswer.copyWith(sdp: modifiedSdp);
      _logger.v(
        () => '[createLocalAnswer] #$type; sdp:\n${modifiedAnswer.sdp}',
      );
      await setLocalDescription(modifiedAnswer);
      return Result.success(modifiedAnswer);
    } catch (e, stk) {
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  /// Sets the offer session description.
  Future<Result<void>> setRemoteOffer(
    String remoteOfferSdp,
  ) async {
    final modifiedSdp = sdpEditor.edit(Sdp.remoteOffer(remoteOfferSdp));
    _logger.v(() => '[setRemoteOffer] #$type; sdp:\n$modifiedSdp');
    return setRemoteDescription(
      rtc.RTCSessionDescription(modifiedSdp, 'offer'),
    );
  }

  /// Sets the answer session description.
  Future<Result<void>> setRemoteAnswer(
    String remoteAnswerSdp,
  ) async {
    final modifiedSdp = sdpEditor.edit(Sdp.remoteAnswer(remoteAnswerSdp));
    _logger.v(() => '[setRemoteAnswer] #$type; sdp:\n$modifiedSdp');
    return setRemoteDescription(
      rtc.RTCSessionDescription(modifiedSdp, 'answer'),
    );
  }

  /// Sets the remote description and adds any pending ice candidates.
  Future<Result<void>> setRemoteDescription(
    rtc.RTCSessionDescription sd,
  ) async {
    try {
      final result = await pc.setRemoteDescription(sd);
      for (final candidate in _pendingCandidates) {
        await pc.addCandidate(candidate);
      }
      _pendingCandidates.clear();
      return Result.success(result);
    } catch (e, stk) {
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  //Sets the local description
  Future<Result<void>> setLocalDescription(
    rtc.RTCSessionDescription description,
  ) async {
    try {
      final result = await pc.setLocalDescription(description);
      return Result.success(result);
    } catch (e, stk) {
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  /// Adds an ice candidate to the peer connection.
  ///
  /// If the peer connection is not yet ready, the candidate is added to a list
  /// of pending candidates.
  Future<Result<None>> addIceCandidate(rtc.RTCIceCandidate candidate) async {
    try {
      final remoteDescription = await pc.getRemoteDescription();
      if (remoteDescription == null) {
        _pendingCandidates.add(candidate);
        return Result.error('no remoteDescription set');
      }
      await pc.addCandidate(candidate);
      return const Result.success(none);
    } catch (e, stk) {
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  /// Adds a local [rtc.MediaStreamTrack] with audio to the current connection.
  Future<Result<rtc.RTCRtpTransceiver>> addAudioTransceiver({
    required rtc.MediaStreamTrack track,
    List<rtc.RTCRtpEncoding>? encodings,
  }) async {
    try {
      final transceiver = await pc.addTransceiver(
        track: track,
        kind: rtc.RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: rtc.RTCRtpTransceiverInit(
          direction: rtc.TransceiverDirection.SendOnly,
          sendEncodings: encodings,
        ),
      );

      return Result.success(transceiver);
    } catch (e, stk) {
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  /// Adds a local [rtc.MediaStreamTrack] with video to a given connection.
  ///
  /// The video is then sent in three different resolutions using simulcast.
  Future<Result<rtc.RTCRtpTransceiver>> addVideoTransceiver({
    required rtc.MediaStreamTrack track,
    List<rtc.RTCRtpEncoding>? encodings,
  }) async {
    try {
      final transceiver = await pc.addTransceiver(
        track: track,
        kind: rtc.RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: rtc.RTCRtpTransceiverInit(
          direction: rtc.TransceiverDirection.SendOnly,
          sendEncodings: encodings,
        ),
      );

      return Result.success(transceiver);
    } catch (e, stk) {
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  void _initRtcCallbacks() {
    pc
      ..onAddStream = _onAddStream
      ..onRemoveStream = _onRemoveStream
      ..onAddTrack = _onAddTrack
      ..onTrack = _onTrack
      ..onRemoveTrack = _onRemoveTrack
      ..onIceCandidate = _onIceCandidate
      ..onIceConnectionState = _onIceConnectionState
      ..onRenegotiationNeeded = _onRenegotiationNeeded;
  }

  void _dropRtcCallbacks() {
    pc
      ..onAddStream = null
      ..onRemoveStream = null
      ..onAddTrack = null
      ..onTrack = null
      ..onRemoveTrack = null
      ..onIceCandidate = null
      ..onIceConnectionState = null
      ..onRenegotiationNeeded = null
      ..onIceGatheringState = null
      ..onSignalingState = null
      ..onConnectionState = null
      ..onDataChannel = null;
  }

  void _onAddStream(rtc.MediaStream stream) {
    _logger.v(() => '[onAddStream] stream.id: ${stream.id}');
    onStreamAdded?.call(this, stream);
  }

  void _onRemoveStream(rtc.MediaStream stream) {
    _logger.v(() => '[onRemoveStream] stream.id: ${stream.id}');
  }

  void _onAddTrack(rtc.MediaStream stream, rtc.MediaStreamTrack track) {
    _logger.v(
      () => '[onAddTrack] stream.id: ${stream.id}, track.id: ${track.id}, '
          'track.kind: ${track.kind}',
    );
  }

  void _onTrack(rtc.RTCTrackEvent event) {
    _logger.v(
      () => '[onTrack] event: $event',
    );
    onTrack?.call(this, event);
  }

  void _onRemoveTrack(rtc.MediaStream stream, rtc.MediaStreamTrack track) {
    _logger.v(
      () => '[onRemoveTrack] stream.id: ${stream.id}, track.id: ${track.id}, '
          'track.kind: ${track.kind}',
    );
  }

  void _onIceCandidate(rtc.RTCIceCandidate iceCandidate) {
    onIceCandidate?.call(this, iceCandidate);
  }

  void _onIceConnectionState(rtc.RTCIceConnectionState state) {
    _logger.v(() => '[onIceConnectionState] state: $state');

    switch (state) {
      case rtc.RTCIceConnectionState.RTCIceConnectionStateFailed:
      case rtc.RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        onIssue?.call(this);
      default:
        break;
    }
  }

  void _onRenegotiationNeeded() {
    _logger.v(() => '[onRenegotiationNeeded] no args');

    onRenegotiationNeeded?.call(this);
  }

  Future<
      ({
        List<RtcStats> rtcStats,
        RtcPrintableStats printable,
        List<Map<String, dynamic>> rawStats,
      })> getStats() async {
    final stats = await pc.getStats();

    final rtcPrintableStats = stats.toPrintableRtcStats();
    final rawStats = stats.toRawStats();
    final rtcStats = stats
        .map((report) => report.toRtcStats())
        .where((element) => element != null)
        .cast<RtcStats>()
        .toList();

    return (
      rtcStats: rtcStats,
      printable: rtcPrintableStats,
      rawStats: rawStats,
    );
  }

  @override
  Future<void> dispose() async {
    _logger.d(() => '[dispose] no args');
    _dropRtcCallbacks();
    onStreamAdded = null;
    onRenegotiationNeeded = null;
    onIceCandidate = null;
    onTrack = null;
    _pendingCandidates.clear();
    await pc.dispose();
    return await super.dispose();
  }
}

extension on rtc.RTCSessionDescription {
  rtc.RTCSessionDescription copyWith({
    String? type,
    String? sdp,
  }) {
    return rtc.RTCSessionDescription(
      sdp ?? this.sdp,
      type ?? this.type,
    );
  }
}
