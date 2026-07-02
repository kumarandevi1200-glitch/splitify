import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import 'group_detail_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  List<Group> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshGroups();
  }

  Future<void> _refreshGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchGroups();
      setState(() {
        _groups = list;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final currencyController = TextEditingController(text: 'INR');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'e.g. Goa Trip, Flatmates',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency Symbol',
                      hintText: 'e.g. INR, USD, EUR',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty) return;
                          setDialogState(() => isSaving = true);
                          try {
                            final api = Provider.of<ApiService>(context, listen: false);
                            await api.createGroup(
                              nameController.text.trim(),
                              currencyController.text.trim(),
                            );
                            Navigator.of(context).pop();
                            _refreshGroups();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          } finally {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();
    bool isJoining = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Join Group'),
              content: TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Invite Code',
                  hintText: 'Enter 6-8 digit code',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isJoining ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isJoining
                      ? null
                      : () async {
                          if (codeController.text.trim().isEmpty) return;
                          setDialogState(() => isJoining = true);
                          try {
                            final api = Provider.of<ApiService>(context, listen: false);
                            await api.joinGroup(codeController.text.trim());
                            Navigator.of(context).pop();
                            _refreshGroups();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
                            );
                          } finally {
                            setDialogState(() => isJoining = false);
                          }
                        },
                  child: isJoining
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await api.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshGroups,
        child: _isLoading && _groups.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red))),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _refreshGroups,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _groups.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          const Center(
                            child: Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'No groups yet. Create or Join one!',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GroupDetailScreen(group: group),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).cardColor,
                                      Theme.of(context).cardColor.withOpacity(0.85),
                                      const Color(0xFF6C63FF).withOpacity(0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
                                      child: Text(
                                        group.name.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${group.members.length} members • Currency: ${group.currency}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showJoinGroupDialog,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join Group'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateGroupDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Group'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
