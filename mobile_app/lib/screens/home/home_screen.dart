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
                    subtitle: 'Plan your next live broadcast',
                    onTap: () => context.go('/home/schedule'),
                  ),
                  _ActionCard(
                    icon: Icons.live_tv,
                    title: 'Active Streams',
                    subtitle: 'Manage ongoing broadcasts',
                    onTap: () {
                      // TODO: Navigate to active streams
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Active streams view coming soon')),
                      );
                    },
                  ),
                  _ActionCard(
                    icon: Icons.replay,
                    title: 'Re-telecast',
                    subtitle: 'Replay previous streams',
                    onTap: () {
                      // TODO: Navigate to re-telecast
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Re-telecast feature coming soon')),
                      );
                    },
                  ),
                  _ActionCard(
                    icon: Icons.download,
                    title: 'Downloads',
                    subtitle: 'Manage video downloads',
                    onTap: () => context.go('/home/downloads'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home/schedule'),
        icon: const Icon(Icons.add),
        label: const Text('New Stream'),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}