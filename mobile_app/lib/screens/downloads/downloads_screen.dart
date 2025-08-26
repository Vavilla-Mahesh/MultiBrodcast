import 'package:flutter/material.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final List<DownloadItem> _downloads = [
    DownloadItem(
      id: '1',
      title: 'My First Livestream',
      status: DownloadStatus.completed,
      progress: 1.0,
      size: '1.2 GB',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    DownloadItem(
      id: '2',
      title: 'Gaming Session #5',
      status: DownloadStatus.downloading,
      progress: 0.65,
      size: '850 MB',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    DownloadItem(
      id: '3',
      title: 'Tutorial: Flutter Tips',
      status: DownloadStatus.pending,
      progress: 0.0,
      size: '500 MB',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDownloads,
          ),
        ],
      ),
      body: _downloads.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Your downloaded videos will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _downloads.length,
              itemBuilder: (context, index) {
                final download = _downloads[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    download.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Size: ${download.size}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    'Created: ${_formatDateTime(download.createdAt)}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            _StatusIcon(status: download.status),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Progress bar
                        if (download.status == DownloadStatus.downloading ||
                            download.status == DownloadStatus.pending)
                          Column(
                            children: [
                              LinearProgressIndicator(
                                value: download.progress,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  download.status == DownloadStatus.downloading
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getStatusText(download.status),
                                    style: TextStyle(
                                      color: _getStatusColor(download.status),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${(download.progress * 100).toInt()}%',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        
                        if (download.status == DownloadStatus.completed ||
                            download.status == DownloadStatus.error)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getStatusText(download.status),
                                style: TextStyle(
                                  color: _getStatusColor(download.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  if (download.status == DownloadStatus.completed) ...[
                                    TextButton.icon(
                                      onPressed: () => _shareDownload(download),
                                      icon: const Icon(Icons.share),
                                      label: const Text('Share'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _openDownload(download),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Open'),
                                    ),
                                  ],
                                  if (download.status == DownloadStatus.error)
                                    ElevatedButton.icon(
                                      onPressed: () => _retryDownload(download),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestNewDownload,
        icon: const Icon(Icons.add),
        label: const Text('New Download'),
      ),
    );
  }

  void _refreshDownloads() {
    // TODO: Implement refresh logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshing downloads...')),
    );
  }

  void _shareDownload(DownloadItem download) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing ${download.title}...')),
    );
  }

  void _openDownload(DownloadItem download) {
    // TODO: Implement open/play functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${download.title}...')),
    );
  }

  void _retryDownload(DownloadItem download) {
    setState(() {
      download.status = DownloadStatus.pending;
      download.progress = 0.0;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Retrying download for ${download.title}')),
    );
  }

  void _requestNewDownload() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Download'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Video ID or URL',
                hintText: 'Enter YouTube video ID',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Enter the YouTube video ID of the stream you want to download.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download request submitted!')),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return 'Pending';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.error:
        return 'Error';
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Colors.orange;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.error:
        return Colors.red;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final DownloadStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DownloadStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange);
      case DownloadStatus.downloading:
        return const Icon(Icons.download, color: Colors.blue);
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case DownloadStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  error,
}

class DownloadItem {
  final String id;
  final String title;
  DownloadStatus status;
  double progress;
  final String size;
  final DateTime createdAt;

  DownloadItem({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    required this.size,
    required this.createdAt,
  });
}