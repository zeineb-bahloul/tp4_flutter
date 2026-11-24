import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/queue_state.dart';
import '../providers/connectivity_provider.dart';
import '../providers/queue_provider.dart';
import '../services/auth_service.dart';
import '../widgets/client_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/offline_banner.dart';
import '../widgets/queue_empty_widget.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<QueueProvider>().loadMore();
    }
  }

  void _addClient() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<QueueProvider>().addClient(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivityStatus = context.watch<ConnectivityProvider>().status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resilient Waiting Room'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline / Connectivity Banner
          OfflineBanner(status: connectivityStatus),

          // Input Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter client name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addClient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addClient,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),

          // Queue List & States
          Expanded(
            child: Consumer<QueueProvider>(
              builder: (context, provider, _) {
                switch (provider.state) {
                  case QueueState.initial:
                  case QueueState.loading:
                    return const LoadingWidget(message: 'Loading waiting queue...');
                  case QueueState.empty:
                    return const QueueEmptyWidget();
                  case QueueState.error:
                    return Center(
                      child: Text(
                        provider.errorMessage ?? 'An error occurred',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  default:
                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: provider.clients.length +
                          (provider.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == provider.clients.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final client = provider.clients[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          child: Dismissible(
                            key: Key(client.id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              context.read<QueueProvider>().removeClient(client.id);
                            },
                            child: ClientCard(client: client),
                          ),
                        );
                      },
                    );
                }
              },
            ),
          ),

          // Next Client Action
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<QueueProvider>().nextClient();
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

