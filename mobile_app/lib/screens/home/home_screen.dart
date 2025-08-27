import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MultiBroadcast'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${authState.user?.email ?? 'User'}!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (authState.googleAccount != null)
                      Text(
                        'Connected to: ${authState.googleAccount!.channelTitle}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Production-ready mobile live streaming system for YouTube',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _ActionCard(
                    icon: Icons.schedule,
                    title: 'Schedule Stream',
                    subtitle: authState.googleAccount != null 
                      ? 'Plan your next live broadcast'
                      : 'Connect YouTube to enable',
                    onTap: authState.googleAccount != null 
                      ? () => context.go('/home/schedule')
                      : () => _showConnectPrompt(context, ref),
                    enabled: authState.googleAccount != null,
                  ),
                  _ActionCard(
                    icon: Icons.live_tv,
                    title: 'Active Streams',
                    subtitle: authState.googleAccount != null
                      ? 'Manage ongoing broadcasts'
                      : 'Connect YouTube to enable',
                    onTap: authState.googleAccount != null 
                      ? () {
                          // TODO: Navigate to active streams
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Active streams view coming soon')),
                          );
                        }
                      : () => _showConnectPrompt(context, ref),
                    enabled: authState.googleAccount != null,
                  ),
                  _ActionCard(
                    icon: Icons.replay,
                    title: 'Re-telecast',
                    subtitle: authState.googleAccount != null
                      ? 'Replay previous streams'
                      : 'Connect YouTube to enable',
                    onTap: authState.googleAccount != null 
                      ? () {
                          // TODO: Navigate to re-telecast
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Re-telecast feature coming soon')),
                          );
                        }
                      : () => _showConnectPrompt(context, ref),
                    enabled: authState.googleAccount != null,
                  ),
                  _ActionCard(
                    icon: Icons.settings,
                    title: 'Settings',
                    subtitle: 'Manage YouTube connection',
                    onTap: () => context.go('/settings'),
                    enabled: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: authState.googleAccount != null 
        ? FloatingActionButton.extended(
            onPressed: () => context.go('/home/schedule'),
            icon: const Icon(Icons.add),
            label: const Text('New Stream'),
          )
        : FloatingActionButton.extended(
            onPressed: () => _showConnectPrompt(context, ref),
            icon: const Icon(Icons.link),
            label: const Text('Connect YouTube'),
            backgroundColor: Colors.orange,
          ),
    );
  }

  void _showConnectPrompt(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('YouTube Connection Required'),
        content: const Text(
          'You need to connect your YouTube account to access streaming features. '
          'Go to Settings to connect your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/settings');
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: enabled ? Colors.red : Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: enabled ? null : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled ? Colors.grey : Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}