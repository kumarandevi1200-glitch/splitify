import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import 'add_expense_screen.dart';
import 'record_settlement_screen.dart';
import 'report_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Expense> _expenses = [];
  List<Settlement> _settlements = [];
  List<User> _members = [];
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _members = widget.group.members;
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final exps = await api.fetchExpenses(widget.group.id);
      final sets = await api.fetchSettlements(widget.group.id);
      final mems = await api.fetchGroupMembers(widget.group.id);
      
      setState(() {
        _expenses = exps;
        _settlements = sets;
        _members = mems;
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

  void _showInviteCodeDialog() {
    final validityController = TextEditingController(text: '24');
    final maxUsesController = TextEditingController(text: '10');
    bool isGenerating = false;
    String? generatedCode;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Generate Invite Code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (generatedCode == null) ...[
                    TextField(
                      controller: validityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Validity Duration (Hours)',
                        hintText: 'e.g. 24',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: maxUsesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum Uses (Optional)',
                        hintText: 'e.g. 5',
                      ),
                    ),
                  ] else ...[
                    const Center(
                      child: Text(
                        'Share this code with your friends:',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          generatedCode!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Color(0xFF03DAC6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (generatedCode == null) ...[
                  TextButton(
                    onPressed: isGenerating ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isGenerating
                        ? null
                        : () async {
                            setDialogState(() => isGenerating = true);
                            try {
                              final api = Provider.of<ApiService>(context, listen: false);
                              final code = await api.generateInviteCode(
                                widget.group.id,
                                validityHours: int.tryParse(validityController.text),
                                maxUses: int.tryParse(maxUsesController.text),
                              );
                              setDialogState(() {
                                generatedCode = code;
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            } finally {
                              setDialogState(() => isGenerating = false);
                            }
                          },
                    child: isGenerating
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Generate'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: generatedCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _deleteExpense(Expense expense) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.deleteExpense(widget.group.id, expense.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully')),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          tabs: const [
            Tab(text: 'Expenses', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Settlements', icon: Icon(Icons.payment)),
            Tab(text: 'Members', icon: Icon(Icons.people)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Invite Members',
            onPressed: _showInviteCodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'View Report & Balances',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportScreen(groupId: widget.group.id, currency: widget.group.currency),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading && _expenses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // --- EXPENSES TAB ---
                    _buildExpensesList(),
                    
                    // --- SETTLEMENTS TAB ---
                    _buildSettlementsList(),
                    
                    // --- MEMBERS TAB ---
                    _buildMembersList(),
                  ],
                ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton(
              onPressed: _showInviteCodeDialog,
              backgroundColor: const Color(0xFF6C63FF),
              child: const Icon(Icons.person_add),
            )
          : null,
      bottomNavigationBar: _tabController.index != 2
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecordSettlementScreen(groupId: widget.group.id, members: _members),
                            ),
                          );
                          if (result == true) _refreshData();
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Settle Debt'),
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
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(groupId: widget.group.id, members: _members),
                            ),
                          );
                          if (result == true) _refreshData();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return const Center(child: Text('No expenses recorded yet.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final exp = _expenses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.05),
              child: Icon(
                exp.category.toLowerCase() == 'food'
                    ? Icons.restaurant
                    : exp.category.toLowerCase() == 'travel'
                        ? Icons.flight
                        : exp.category.toLowerCase() == 'housing'
                            ? Icons.home
                            : Icons.receipt_long,
                color: const Color(0xFF03DAC6),
              ),
            ),
            title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Paid by ${exp.payer.email}\nSplit: ${exp.splitType} • ${exp.expenseDate.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.group.currency} ${exp.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(groupId: widget.group.id, members: _members, expenseToEdit: exp),
                        ),
                      );
                      if (result == true) _refreshData();
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(exp);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${expense.description}"? This action soft-deletes and preserves history.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteExpense(expense);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsList() {
    if (_settlements.isEmpty) {
      return const Center(child: Text('No settlements recorded yet.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _settlements.length,
      itemBuilder: (context, index) {
        final set = _settlements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF00C853).withOpacity(0.15),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF00C853)),
            ),
            title: Text('${set.paidBy.email} paid ${set.paidTo.email}'),
            subtitle: Text(
              '${set.note ?? "Settled debt"}\n${set.settlementDate.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Text(
              '${widget.group.currency} ${set.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00C853)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isMe = member.id == Provider.of<ApiService>(context, listen: false).userId;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: const Icon(Icons.person, color: Color(0xFF6C63FF)),
            ),
            title: Text(member.email + (isMe ? ' (You)' : '')),
            subtitle: Text('Member ID: ${member.id}'),
          ),
        );
      },
    );
  }
}
