import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChannelsService extends StateNotifier<ChannelsState> {
  ChannelsService() : super(ChannelsState());

  static const String baseUrl = 'http://localhost:3000/api';

  Future<void> loadChannels(String token) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final response = await http.get(
        Uri.parse('$baseUrl/channels'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final channels = (data['data']['channels'] as List)
            .map((json) => YoutubeChannel.fromJson(json))
            .toList();
        
        state = state.copyWith(
          isLoading: false,
          channels: channels,
        );
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(
          isLoading: false,
          error: error['error']['message'],
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
    }
  }

  Future<YoutubeChannel?> getChannelDetails(String channelId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channels/$channelId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return YoutubeChannel.fromJson(data['data']['channel']);
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(error: error['error']['message']);
        return null;
      }
    } catch (e) {
      state = state.copyWith(error: 'Network error: $e');
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class ChannelsState {
  final bool isLoading;
  final List<YoutubeChannel> channels;
  final String? error;

  ChannelsState({
    this.isLoading = false,
    this.channels = const [],
    this.error,
  });

  ChannelsState copyWith({
    bool? isLoading,
    List<YoutubeChannel>? channels,
    String? error,
  }) {
    return ChannelsState(
      isLoading: isLoading ?? this.isLoading,
      channels: channels ?? this.channels,
      error: error,
    );
  }
}

class YoutubeChannel {
  final int id;
  final String channelId;
  final String title;
  final List<String> scopes;
  final DateTime connectedAt;
  final ChannelStatistics? statistics;
  final String? error;

  YoutubeChannel({
    required this.id,
    required this.channelId,
    required this.title,
    required this.scopes,
    required this.connectedAt,
    this.statistics,
    this.error,
  });

  factory YoutubeChannel.fromJson(Map<String, dynamic> json) {
    return YoutubeChannel(
      id: json['id'],
      channelId: json['channelId'],
      title: json['title'],
      scopes: List<String>.from(json['scopes']),
      connectedAt: DateTime.parse(json['connectedAt']),
      statistics: json['statistics'] != null 
          ? ChannelStatistics.fromJson(json['statistics'])
          : null,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'title': title,
      'scopes': scopes,
      'connectedAt': connectedAt.toIso8601String(),
      'statistics': statistics?.toJson(),
      'error': error,
    };
  }
}

class ChannelStatistics {
  final int viewCount;
  final int subscriberCount;
  final int videoCount;

  ChannelStatistics({
    required this.viewCount,
    required this.subscriberCount,
    required this.videoCount,
  });

  factory ChannelStatistics.fromJson(Map<String, dynamic> json) {
    return ChannelStatistics(
      viewCount: int.tryParse(json['viewCount'].toString()) ?? 0,
      subscriberCount: int.tryParse(json['subscriberCount'].toString()) ?? 0,
      videoCount: int.tryParse(json['videoCount'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'viewCount': viewCount.toString(),
      'subscriberCount': subscriberCount.toString(),
      'videoCount': videoCount.toString(),
    };
  }

  String get formattedSubscriberCount {
    if (subscriberCount >= 1000000) {
      return '${(subscriberCount / 1000000).toStringAsFixed(1)}M';
    } else if (subscriberCount >= 1000) {
      return '${(subscriberCount / 1000).toStringAsFixed(1)}K';
    } else {
      return subscriberCount.toString();
    }
  }

  String get formattedViewCount {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    } else {
      return viewCount.toString();
    }
  }
}

final channelsServiceProvider = StateNotifierProvider<ChannelsService, ChannelsState>((ref) {
  return ChannelsService();
});