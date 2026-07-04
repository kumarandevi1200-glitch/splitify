import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';

class AddExpenseScreen extends StatefulWidget {
  final int groupId;
  final List<User> members;
  final String currency;
  final Expense? expenseToEdit;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.members,
    required this.currency,
    this.expenseToEdit,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedSplitType = 'EQUAL'; // EQUAL, EXACT, PERCENTAGE, SHARES
  int? _selectedPayerId;
  
  final Map<int, bool> _participating = {};
  final Map<int, TextEditingController> _splitControllers = {};
  
  bool _isLoading = false;
  String? _errorMessage;
  late String _idempotencyKey;
  
  bool _isDirty = false;

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  Future<bool?> _showDiscardDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _idempotencyKey = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    
    // Add listener to rebuild amount reactively for equal splits
    _amountController.addListener(() {
      setState(() {});
    });

    // Initialize participant states
    for (var m in widget.members) {
      _participating[m.id] = true;
      _splitControllers[m.id] = TextEditingController();
    }

    // Pre-populate fields if in EDIT mode
    if (widget.expenseToEdit != null) {
      final exp = widget.expenseToEdit!;
      _amountController.text = exp.amount.toString();
      _descriptionController.text = exp.description;
      _selectedSplitType = exp.splitType;
      _selectedPayerId = exp.payer.id;

      // Mark who is participating and their split values
      for (var m in widget.members) {
        _participating[m.id] = false;
      }
      for (var share in exp.shares) {
        _participating[share.userId] = true;
        final controller = _splitControllers[share.userId];
        if (controller != null) {
          if (_selectedSplitType == 'EXACT') {
            controller.text = share.shareAmount.toString();
          } else if (_selectedSplitType == 'PERCENTAGE') {
            controller.text = share.percentage?.toString() ?? '';
          } else if (_selectedSplitType == 'SHARES') {
            controller.text = share.shares?.toString() ?? '';
          }
        }
      }
    } else {
      // Default payer is the current user
      final api = Provider.of<ApiService>(context, listen: false);
      _selectedPayerId = api.userId;
    }

    _amountController.addListener(_markDirty);
    _descriptionController.addListener(_markDirty);
    for (var controller in _splitControllers.values) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    for (var controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updatePercentageSplits() {
    if (_selectedSplitType != 'PERCENTAGE') return;
    final activeCount = _participating.values.where((v) => v).length;
    if (activeCount == 0) {
      for (var member in widget.members) {
        _splitControllers[member.id]!.clear();
      }
      return;
    }

    final double standardPct = double.parse((100.0 / activeCount).toStringAsFixed(2));
    final double sumOfStandard = standardPct * activeCount;
    final double leftover = double.parse((100.0 - sumOfStandard).toStringAsFixed(2));

    bool isFirst = true;
    for (var member in widget.members) {
      if (_participating[member.id] == true) {
        double memberPct = standardPct;
        if (isFirst) {
          memberPct = double.parse((standardPct + leftover).toStringAsFixed(2));
          isFirst = false;
        }
        _splitControllers[member.id]!.text = memberPct.toStringAsFixed(2);
      } else {
        _splitControllers[member.id]!.clear();
      }
    }
  }

  void _onSplitTypeChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedSplitType = val;
      // Clear inputs
      for (var controller in _splitControllers.values) {
        controller.clear();
      }
      if (_selectedSplitType == 'PERCENTAGE') {
        _updatePercentageSplits();
      }
    });
    _markDirty();
  }

  // Local calculations validation check
  bool _validateSplits() {
    final double? totalAmt = double.tryParse(_amountController.text);
    if (totalAmt == null || totalAmt <= 0) {
      setState(() => _errorMessage = 'Invalid total amount');
      return false;
    }

    final activeParticipants = widget.members.where((m) => _participating[m.id] == true).toList();
    if (activeParticipants.isEmpty) {
      setState(() => _errorMessage = 'Select at least one participant');
      return false;
    }

    if (_selectedSplitType == 'EXACT') {
      double sum = 0;
      for (var p in activeParticipants) {
        final val = double.tryParse(_splitControllers[p.id]?.text ?? '') ?? 0;
        sum += val;
      }
      if ((sum - totalAmt).abs() > 0.01) {
        setState(() => _errorMessage = 'Sum of shares ($sum) must equal total amount ($totalAmt)');
        return false;
      }
    } else if (_selectedSplitType == 'PERCENTAGE') {
      double sum = 0;
      for (var p in activeParticipants) {
        final val = double.tryParse(_splitControllers[p.id]?.text ?? '') ?? 0;
        sum += val;
      }
      if ((sum - 100).abs() > 0.01) {
        setState(() => _errorMessage = 'Sum of percentages ($sum%) must equal 100%');
        return false;
      }
    } else if (_selectedSplitType == 'SHARES') {
      for (var p in activeParticipants) {
        final val = double.tryParse(_splitControllers[p.id]?.text ?? '') ?? 0;
        if (val <= 0) {
          setState(() => _errorMessage = 'Shares weight must be greater than 0');
          return false;
        }
      }
    }

    return true;
  }

  String _predictCategory(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('food') || desc.contains('restaurant') || desc.contains('dinner') || 
        desc.contains('lunch') || desc.contains('breakfast') || desc.contains('pizza') || 
        desc.contains('cafe') || desc.contains('burger') || desc.contains('grocery') || 
        desc.contains('groceries') || desc.contains('eat') || desc.contains('drink') || 
        desc.contains('coffee') || desc.contains('starbucks') || desc.contains('mcdonald')) {
      return 'Food';
    }
    if (desc.contains('travel') || desc.contains('flight') || desc.contains('hotel') || 
        desc.contains('uber') || desc.contains('taxi') || desc.contains('cab') || 
        desc.contains('bus') || desc.contains('train') || desc.contains('trip') || 
        desc.contains('gas') || desc.contains('fuel') || desc.contains('airline') || 
        desc.contains('ticket') || desc.contains('metro') || desc.contains('commute')) {
      return 'Travel';
    }
    if (desc.contains('housing') || desc.contains('rent') || desc.contains('stay') || 
        desc.contains('room') || desc.contains('accommodation') || desc.contains('hostel') || 
        desc.contains('apartment') || desc.contains('lease')) {
      return 'Housing';
    }
    if (desc.contains('entertainment') || desc.contains('movie') || desc.contains('show') || 
        desc.contains('cinema') || desc.contains('netflix') || desc.contains('game') || 
        desc.contains('party') || desc.contains('club') || desc.contains('concert') || 
        desc.contains('fun') || desc.contains('spotify') || desc.contains('pub')) {
      return 'Entertainment';
    }
    if (desc.contains('utilities') || desc.contains('electricity') || desc.contains('water') || 
        desc.contains('wifi') || desc.contains('internet') || desc.contains('bill') || 
        desc.contains('power') || desc.contains('phone') || desc.contains('recharge')) {
      return 'Utilities';
    }
    return 'General';
  }

  void _deleteExpenseInside() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);

    try {
      await api.deleteExpense(widget.groupId, widget.expenseToEdit!.id);
      if (mounted) {
        setState(() {
          _isDirty = false;
        });
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
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${widget.expenseToEdit!.description}"? This action soft-deletes and preserves history.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteExpenseInside();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateSplits()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);

    // Build the shares array for payload
    final activeParticipants = widget.members.where((m) => _participating[m.id] == true).toList();
    final List<Map<String, dynamic>> sharesPayload = [];

    for (var p in activeParticipants) {
      final inputVal = double.tryParse(_splitControllers[p.id]?.text ?? '') ?? 0;
      sharesPayload.add({
        'userId': p.id,
        'amount': _selectedSplitType == 'EXACT' ? inputVal : null,
        'percentage': _selectedSplitType == 'PERCENTAGE' ? inputVal : null,
        'shares': _selectedSplitType == 'SHARES' ? inputVal : null,
      });
    }

    final category = _predictCategory(_descriptionController.text.trim());

    try {
      if (widget.expenseToEdit != null) {
        await api.updateExpense(
          widget.groupId,
          widget.expenseToEdit!.id,
          double.parse(_amountController.text),
          _selectedPayerId!,
          _descriptionController.text.trim(),
          _selectedSplitType,
          category,
          sharesPayload,
        );
      } else {
        await api.createExpense(
          widget.groupId,
          double.parse(_amountController.text),
          _selectedPayerId!,
          _descriptionController.text.trim(),
          _selectedSplitType,
          category,
          sharesPayload,
          idempotencyKey: _idempotencyKey,
        );
      }

      if (mounted) {
        setState(() {
          _isDirty = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context, listen: false);
    final canEdit = widget.expenseToEdit == null || widget.expenseToEdit!.payer.id == api.userId;

    final double totalAmt = double.tryParse(_amountController.text) ?? 0.0;
    final activeCount = _participating.values.where((v) => v).length;
    final shareAmt = activeCount > 0 ? totalAmt / activeCount : 0.0;

    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final leave = await _showDiscardDialog(context);
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.expenseToEdit != null ? (canEdit ? 'Edit Expense' : 'View Expense') : 'Add Expense'),
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
                      // Amount Field
                      TextFormField(
                        controller: _amountController,
                        enabled: canEdit,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        validator: (value) {
                          if (value == null || double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Enter a valid amount greater than 0';
                          }
                          if (double.parse(value) > 999999999999) {
                            return 'Amount is too large (maximum 999,999,999,999)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                          hintText: 'e.g. Dinner, Uber, Groceries',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter a description' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payer', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // Payer Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedPayerId,
                        decoration: const InputDecoration(
                          labelText: 'Who Paid?',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: widget.members.map((m) {
                          return DropdownMenuItem<int>(
                            value: m.id,
                            child: Text(m.email),
                          );
                        }).toList(),
                        onChanged: canEdit ? (val) {
                          setState(() => _selectedPayerId = val);
                          _markDirty();
                        } : null,
                        validator: (val) => val == null ? 'Select who paid' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Split Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          DropdownButton<String>(
                            value: _selectedSplitType,
                            dropdownColor: Theme.of(context).cardColor,
                            items: const [
                              DropdownMenuItem(value: 'EQUAL', child: Text('Equally')),
                              DropdownMenuItem(value: 'EXACT', child: Text('Exact Amounts')),
                              DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentages')),
                              DropdownMenuItem(value: 'SHARES', child: Text('Shares')),
                            ],
                            onChanged: canEdit ? _onSplitTypeChanged : null,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('Participants', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      // Participant list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.members.length,
                        itemBuilder: (context, index) {
                          final member = widget.members[index];
                          final isChecked = _participating[member.id] ?? false;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isChecked,
                                  onChanged: canEdit
                                      ? (val) {
                                          setState(() {
                                            _participating[member.id] = val ?? false;
                                            if (_selectedSplitType == 'PERCENTAGE') {
                                              _updatePercentageSplits();
                                            }
                                          });
                                          _markDirty();
                                        }
                                      : null,
                                ),
                                Expanded(
                                  child: Text(member.email, overflow: TextOverflow.ellipsis),
                                ),
                                if (_selectedSplitType == 'EQUAL')
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      isChecked
                                          ? '${widget.currency} ${shareAmt.toStringAsFixed(2)}'
                                          : '${widget.currency} 0.00',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isChecked ? const Color(0xFF8B5CF6) : Colors.grey,
                                      ),
                                    ),
                                  ),
                                if (isChecked && _selectedSplitType != 'EQUAL')
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: _splitControllers[member.id],
                                      enabled: canEdit,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: _selectedSplitType == 'EXACT'
                                            ? 'Amount'
                                            : _selectedSplitType == 'PERCENTAGE'
                                                ? '%'
                                                : 'Shares',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      validator: (value) {
                                        if (isChecked && (value == null || double.tryParse(value) == null)) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
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
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.expenseToEdit != null ? 'Save Changes' : 'Record Expense'),
                ),
                if (widget.expenseToEdit != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _showDeleteConfirmationInside,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                    ),
                    child: const Text('Delete Expense'),
                  ),
                ],
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Read-only: Only the payer of this expense can edit or delete it.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
