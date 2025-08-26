import 'package:flutter/material.dart';

class LiveStreamScreen extends StatefulWidget {
  final String broadcastId;
  
  const LiveStreamScreen({
    Key? key,
    required this.broadcastId,
  }) : super(key: key);

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  bool _isLive = false;
  bool _isPaused = false;
  int _viewerCount = 0;
  Duration _streamDuration = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLive ? 'LIVE' : 'Stream Ready'),
        backgroundColor: _isLive ? Colors.red : null,
        actions: [
          if (_isLive)
            Chip(
              label: Text('$_viewerCount viewers'),
              backgroundColor: Colors.white,
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview placeholder
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Camera Preview',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      'Low-heat mobile streaming',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stream controls
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Stream info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Status:'),
                              Text(
                                _isLive ? 'LIVE' : _isPaused ? 'PAUSED' : 'READY',
                                style: TextStyle(
                                  color: _isLive ? Colors.red : 
                                         _isPaused ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_isLive) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Duration:'),
                                Text(_formatDuration(_streamDuration)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Viewers:'),
                                Text('$_viewerCount'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!_isLive && !_isPaused)
                        ElevatedButton.icon(
                          onPressed: _startStream,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Go Live'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      
                      if (_isLive)
                        ElevatedButton.icon(
                          onPressed: _pauseStream,
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),

                      if (_isPaused)
                        ElevatedButton.icon(
                          onPressed: _resumeStream,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),

                      if (_isLive || _isPaused)
                        ElevatedButton.icon(
                          onPressed: _stopStream,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Additional options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: _showStreamSettings,
                        icon: const Icon(Icons.settings),
                        label: const Text('Settings'),
                      ),
                      TextButton.icon(
                        onPressed: _showStreamInfo,
                        icon: const Icon(Icons.info),
                        label: const Text('Stream Info'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startStream() {
    setState(() {
      _isLive = true;
      _isPaused = false;
      _viewerCount = 1; // Start with at least 1 viewer (the streamer)
    });

    // TODO: Implement actual stream start logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stream started! Going live...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _pauseStream() {
    setState(() {
      _isLive = false;
      _isPaused = true;
    });

    // Show VOD options dialog
    _showVodOptionsDialog();
  }

  void _resumeStream() {
    setState(() {
      _isLive = true;
      _isPaused = false;
    });
  }

  void _stopStream() {
    setState(() {
      _isLive = false;
      _isPaused = false;
    });

    // Show VOD options dialog
    _showVodOptionsDialog();
  }

  void _showVodOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stream Stopped'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your stream has been saved as a VOD (Video on Demand).'),
            SizedBox(height: 16),
            Text('What would you like to do next?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text('Finish'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRetelecastDialog();
            },
            child: const Text('Re-telecast'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadVod();
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showRetelecastDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-telecast Stream'),
        content: const Text(
          'This will create a new live broadcast that replays your recorded stream. '
          'It will be clearly labeled as a replay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement re-telecast logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Re-telecast started!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Start Re-telecast'),
          ),
        ],
      ),
    );
  }

  void _downloadVod() {
    // TODO: Implement download logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download started! Check Downloads section.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showStreamSettings() {
    // TODO: Show stream settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stream settings coming soon')),
    );
  }

  void _showStreamInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stream Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Broadcast ID: ${widget.broadcastId}'),
            const Text('Quality: 720p'),
            const Text('Bitrate: Adaptive'),
            const Text('Latency: Normal'),
            const Text('Hardware Acceleration: Enabled'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
}