import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';

class AddExpenseScreen extends StatefulWidget {
  final int groupId;
  final List<User> members;
  final Expense? expenseToEdit;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.members,
    this.expenseToEdit,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'General';
  String _selectedSplitType = 'EQUAL'; // EQUAL, EXACT, PERCENTAGE, SHARES
  int? _selectedPayerId;
  
  final Map<int, bool> _participating = {};
  final Map<int, TextEditingController> _splitControllers = {};
  
  bool _isLoading = false;
  String? _errorMessage;
  late String _idempotencyKey;

  final List<String> _categories = ['General', 'Food', 'Travel', 'Housing', 'Entertainment', 'Utilities'];

  @override
  void initState() {
    super.initState();
    _idempotencyKey = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    
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
      _selectedCategory = _categories.contains(exp.category) ? exp.category : 'General';
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

  void _onSplitTypeChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedSplitType = val;
      // Clear inputs
      for (var controller in _splitControllers.values) {
        controller.clear();
      }
    });
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

    try {
      if (widget.expenseToEdit != null) {
        await api.updateExpense(
          widget.groupId,
          widget.expenseToEdit!.id,
          double.parse(_amountController.text),
          _selectedPayerId!,
          _descriptionController.text.trim(),
          _selectedSplitType,
          _selectedCategory,
          sharesPayload,
        );
      } else {
        await api.createExpense(
          widget.groupId,
          double.parse(_amountController.text),
          _selectedPayerId!,
          _descriptionController.text.trim(),
          _selectedSplitType,
          _selectedCategory,
          sharesPayload,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseToEdit != null ? 'Edit Expense' : 'Add Expense'),
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
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

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
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
                      const Text('Payer & Category', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        onChanged: (val) => setState(() => _selectedPayerId = val),
                        validator: (val) => val == null ? 'Select who paid' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val ?? 'General'),
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
                            onChanged: _onSplitTypeChanged,
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
                                  onChanged: (val) {
                                    setState(() {
                                      _participating[member.id] = val ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(member.email, overflow: TextOverflow.ellipsis),
                                ),
                                if (isChecked && _selectedSplitType != 'EQUAL')
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: _splitControllers[member.id],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.expenseToEdit != null ? 'Save Changes' : 'Record Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
