import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DownloadsService extends StateNotifier<DownloadsState> {
  DownloadsService() : super(DownloadsState());

  static const String baseUrl = 'http://localhost:3000/api';

  Future<bool> requestDownload({
    required String videoId,
    required String title,
    String format = 'mp4',
    String quality = '720p',
    required String token,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final response = await http.post(
        Uri.parse('$baseUrl/downloads/$videoId/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'format': format,
          'quality': quality,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final downloadItem = DownloadItem.fromJson(data['data']);
        
        // Add to current downloads list
        final updatedDownloads = [...state.downloads, downloadItem];
        state = state.copyWith(
          isLoading: false,
          downloads: updatedDownloads,
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

  Future<void> checkDownloadStatus(String videoId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/downloads/$videoId/status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedItem = DownloadItem.fromJson(data['data']);
        
        // Update the item in the downloads list
        final updatedDownloads = state.downloads.map((item) {
          if (item.videoId == videoId) {
            return updatedItem;
          }
          return item;
        }).toList();
        
        state = state.copyWith(downloads: updatedDownloads);
      }
    } catch (e) {
      // Silently fail for status checks
      print('Error checking download status: $e');
    }
  }

  Future<void> loadDownloads(String token) async {
    try {
      state = state.copyWith(isLoading: true);

      // Note: This would need a backend endpoint to list user's downloads
      // For now, we'll use mock data
      final mockDownloads = [
        DownloadItem(
          id: '1',
          videoId: 'abc123',
          title: 'My First Livestream',
          status: DownloadStatus.completed,
          progress: 1.0,
          fileSize: 1200000000, // 1.2 GB
          format: 'mp4',
          quality: '720p',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        DownloadItem(
          id: '2',
          videoId: 'def456',
          title: 'Gaming Session #5',
          status: DownloadStatus.downloading,
          progress: 0.65,
          fileSize: 850000000, // 850 MB
          format: 'mp4',
          quality: '720p',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        DownloadItem(
          id: '3',
          videoId: 'ghi789',
          title: 'Tutorial: Flutter Tips',
          status: DownloadStatus.pending,
          progress: 0.0,
          fileSize: 500000000, // 500 MB
          format: 'mp4',
          quality: '720p',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ];

      state = state.copyWith(
        isLoading: false,
        downloads: mockDownloads,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load downloads: $e',
      );
    }
  }

  String getDownloadUrl(String token) {
    return '$baseUrl/downloads/file/$token';
  }

  void removeDownload(String id) {
    final updatedDownloads = state.downloads.where((item) => item.id != id).toList();
    state = state.copyWith(downloads: updatedDownloads);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class DownloadsState {
  final bool isLoading;
  final List<DownloadItem> downloads;
  final String? error;

  DownloadsState({
    this.isLoading = false,
    this.downloads = const [],
    this.error,
  });

  DownloadsState copyWith({
    bool? isLoading,
    List<DownloadItem>? downloads,
    String? error,
  }) {
    return DownloadsState(
      isLoading: isLoading ?? this.isLoading,
      downloads: downloads ?? this.downloads,
      error: error,
    );
  }
}

enum DownloadStatus {
  pending,
  downloading,
  processing,
  completed,
  error,
  expired,
}

class DownloadItem {
  final String id;
  final String videoId;
  final String title;
  final DownloadStatus status;
  final double progress;
  final int? fileSize;
  final String format;
  final String quality;
  final String? downloadUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;

  DownloadItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.status,
    required this.progress,
    this.fileSize,
    required this.format,
    required this.quality,
    this.downloadUrl,
    required this.createdAt,
    this.expiresAt,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['vodAssetId'].toString(),
      videoId: json['videoId'],
      title: json['title'] ?? 'Unknown',
      status: _parseStatus(json['status']),
      progress: _parseProgress(json['status']),
      fileSize: json['fileSize'],
      format: json['format'] ?? 'mp4',
      quality: json['quality'] ?? '720p',
      downloadUrl: json['downloadUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt']) 
          : null,
    );
  }

  static DownloadStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return DownloadStatus.pending;
      case 'downloading':
        return DownloadStatus.downloading;
      case 'processing':
        return DownloadStatus.processing;
      case 'ready':
        return DownloadStatus.completed;
      case 'error':
        return DownloadStatus.error;
      case 'expired':
        return DownloadStatus.expired;
      default:
        return DownloadStatus.pending;
    }
  }

  static double _parseProgress(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0.0;
      case 'downloading':
        return 0.5; // Could be dynamic in real implementation
      case 'processing':
        return 0.8;
      case 'ready':
        return 1.0;
      case 'error':
      case 'expired':
        return 0.0;
      default:
        return 0.0;
    }
  }

  String get sizeFormatted {
    if (fileSize == null) return 'Unknown';
    
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    
    if (fileSize! >= gb) {
      return '${(fileSize! / gb).toStringAsFixed(1)} GB';
    } else if (fileSize! >= mb) {
      return '${(fileSize! / mb).toStringAsFixed(0)} MB';
    } else if (fileSize! >= kb) {
      return '${(fileSize! / kb).toStringAsFixed(0)} KB';
    } else {
      return '$fileSize B';
    }
  }

  String get statusText {
    switch (status) {
      case DownloadStatus.pending:
        return 'Pending';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.processing:
        return 'Processing';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.error:
        return 'Error';
      case DownloadStatus.expired:
        return 'Expired';
    }
  }
}

final downloadsServiceProvider = StateNotifierProvider<DownloadsService, DownloadsState>((ref) {
  return DownloadsService();
});