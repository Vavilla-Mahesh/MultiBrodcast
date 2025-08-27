import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // YouTube Integration Section
          const Text(
            'YouTube Integration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        authState.googleAccount != null 
                          ? Icons.check_circle 
                          : Icons.warning,
                        color: authState.googleAccount != null 
                          ? Colors.green 
                          : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        authState.googleAccount != null 
                          ? 'Connected' 
                          : 'Not Connected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: authState.googleAccount != null 
                            ? Colors.green 
                            : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  
                  if (authState.googleAccount != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Channel: ${authState.googleAccount!.channelTitle}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Channel ID: ${authState.googleAccount!.channelId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: authState.googleAccount!.scopes.map((scope) {
                        return Chip(
                          label: Text(
                            scope.split('/').last,
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Connect your YouTube account to enable live streaming and video management features.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      if (authState.googleAccount != null) ...[
                        ElevatedButton.icon(
                          onPressed: () => _disconnect(context, ref),
                          icon: const Icon(Icons.logout),
                          label: const Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _refresh(context, ref),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _connectYouTube(context, ref),
                          icon: const Icon(Icons.video_call),
                          label: const Text('Connect YouTube'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Account Section
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logged in as: ${authState.user?.email ?? "Unknown"}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Role: ${authState.user?.role ?? "Unknown"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _logout(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _connectYouTube(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening Google OAuth...'),
          ],
        ),
      ),
    );

    final success = await ref.read(authServiceProvider.notifier).startGoogleOAuth();
    
    Navigator.of(context).pop();

    if (!success) {
      final error = ref.read(authServiceProvider).error;
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect YouTube'),
        content: const Text(
          'Are you sure you want to disconnect your YouTube account? '
          'This will disable live streaming and video management features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await ref.read(authServiceProvider.notifier).disconnectYouTube();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('YouTube account disconnected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  void _refresh(BuildContext context, WidgetRef ref) async {
    // TODO: Implement token refresh
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing connection...'),
      ),
    );
  }
  
  void _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await ref.read(authServiceProvider.notifier).logout();
      // Navigation will be handled by the app router based on auth state
    }
  }
}