import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';

class RecordSettlementScreen extends StatefulWidget {
  final int groupId;
  final List<User> members;
  final Settlement? settlementToEdit;

  const RecordSettlementScreen({
    super.key,
    required this.groupId,
    required this.members,
    this.settlementToEdit,
  });

  @override
  State<RecordSettlementScreen> createState() => _RecordSettlementScreenState();
}

class _RecordSettlementScreenState extends State<RecordSettlementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  int? _selectedRecipientId;
  bool _isLoading = false;
  String? _errorMessage;
  late String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    
    if (widget.settlementToEdit != null) {
      _amountController.text = widget.settlementToEdit!.amount.toString();
      _noteController.text = widget.settlementToEdit!.note ?? '';
      _selectedRecipientId = widget.settlementToEdit!.paidTo.id;
    } else {
      // Default recipient is the first member that is not the logged-in user
      final api = Provider.of<ApiService>(context, listen: false);
      final otherMembers = widget.members.where((m) => m.id != api.userId).toList();
      if (otherMembers.isNotEmpty) {
        _selectedRecipientId = otherMembers.first.id;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);

    try {
      if (widget.settlementToEdit != null) {
        await api.updateSettlement(
          widget.groupId,
          widget.settlementToEdit!.id,
          _selectedRecipientId!,
          double.parse(_amountController.text),
          _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      } else {
        await api.recordSettlement(
          widget.groupId,
          _selectedRecipientId!,
          double.parse(_amountController.text),
          _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          idempotencyKey: _idempotencyKey,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _deleteSettlementInside() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);

    try {
      await api.deleteSettlement(widget.groupId, widget.settlementToEdit!.id);
      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showDeleteConfirmationInside() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Settlement?'),
        content: Text('Are you sure you want to delete this settlement of ${widget.settlementToEdit!.amount.toStringAsFixed(2)}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSettlementInside();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context, listen: false);
    final otherMembers = widget.members.where((m) => m.id != api.userId).toList();
    final canEdit = widget.settlementToEdit == null || widget.settlementToEdit!.paidBy.id == api.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.settlementToEdit != null ? (canEdit ? 'Edit Settlement' : 'View Settlement') : 'Record Settlement'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Amount Input
                      TextFormField(
                        controller: _amountController,
                        enabled: canEdit,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Payment Amount',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        validator: (value) {
                          if (value == null || double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Enter a valid amount greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Recipient Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedRecipientId,
                        decoration: const InputDecoration(
                          labelText: 'Paid To (Recipient)',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: otherMembers.map((m) {
                          return DropdownMenuItem<int>(
                            value: m.id,
                            child: Text(m.email),
                          );
                        }).toList(),
                        onChanged: canEdit ? (val) => setState(() => _selectedRecipientId = val) : null,
                        validator: (val) => val == null ? 'Select a recipient' : null,
                      ),
                      const SizedBox(height: 16),

                      // Note Input
                      TextFormField(
                        controller: _noteController,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                          labelText: 'Note (Optional)',
                          prefixIcon: Icon(Icons.note),
                          hintText: 'e.g. Settle grocery dues',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              if (canEdit) ...[
                ElevatedButton(
                  onPressed: _isLoading || _selectedRecipientId == null ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.settlementToEdit != null ? 'Update Settlement' : 'Record Settlement Payment'),
                ),
                if (widget.settlementToEdit != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _showDeleteConfirmationInside,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                    ),
                    child: const Text('Delete Settlement'),
                  ),
                ],
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Read-only: Only the sender of this settlement can edit or delete it.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
