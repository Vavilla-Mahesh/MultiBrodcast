import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class StreamingService extends StateNotifier<StreamingState> {
  StreamingService() : super(StreamingState());

  static const String baseUrl = 'http://localhost:3000/api';

  Future<bool> scheduleStream({
    required String title,
    String? description,
    String visibility = 'public',
    String latency = 'normal',
    List<String>? tags,
    DateTime? startTime,
    int? googleAccountId,
    String? token,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final response = await http.post(
        Uri.parse('$baseUrl/streams/schedule'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'visibility': visibility,
          'latency': latency,
          'tags': tags ?? [],
          'startTime': startTime?.toIso8601String(),
          'googleAccountId': googleAccountId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final broadcast = Broadcast.fromJson(data['data']);
        
        state = state.copyWith(
          isLoading: false,
          currentBroadcast: broadcast,
        );
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(
          isLoading: false,
          error: error['error']['message'],
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
      return false;
    }
  }

  Future<bool> startLivestream(int broadcastId, String token) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final response = await http.post(
        Uri.parse('$baseUrl/streams/$broadcastId/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        state = state.copyWith(
          isLoading: false,
          isLive: true,
        );
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(
          isLoading: false,
          error: error['error']['message'],
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
      return false;
    }
  }

  Future<bool> stopLivestream(int broadcastId, String token) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final response = await http.post(
        Uri.parse('$baseUrl/streams/$broadcastId/stop'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        state = state.copyWith(
          isLoading: false,
          isLive: false,
        );
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(
          isLoading: false,
          error: error['error']['message'],
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
      return false;
    }
  }

  Future<List<Broadcast>> getActiveStreams(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/streams/active'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final broadcasts = (data['data']['broadcasts'] as List)
            .map((json) => Broadcast.fromJson(json))
            .toList();
        
        return broadcasts;
      } else {
        throw Exception('Failed to load active streams');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to load streams: $e');
      return [];
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = StreamingState();
  }
}

class StreamingState {
  final bool isLoading;
  final bool isLive;
  final Broadcast? currentBroadcast;
  final String? error;

  StreamingState({
    this.isLoading = false,
    this.isLive = false,
    this.currentBroadcast,
    this.error,
  });

  StreamingState copyWith({
    bool? isLoading,
    bool? isLive,
    Broadcast? currentBroadcast,
    String? error,
  }) {
    return StreamingState(
      isLoading: isLoading ?? this.isLoading,
      isLive: isLive ?? this.isLive,
      currentBroadcast: currentBroadcast ?? this.currentBroadcast,
      error: error,
    );
  }
}

class Broadcast {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String? streamKey;
  final String? ingestionAddress;
  final DateTime? startTime;

  Broadcast({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.streamKey,
    this.ingestionAddress,
    this.startTime,
  });

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      streamKey: json['streamKey'],
      ingestionAddress: json['ingestionAddress'],
      startTime: json['startTime'] != null 
          ? DateTime.parse(json['startTime']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'streamKey': streamKey,
      'ingestionAddress': ingestionAddress,
      'startTime': startTime?.toIso8601String(),
    };
  }
}

final streamingServiceProvider = StateNotifierProvider<StreamingService, StreamingState>((ref) {
  return StreamingService();
});