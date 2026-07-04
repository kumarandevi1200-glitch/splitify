import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api_service.dart';
import '../models.dart';

class ReportScreen extends StatefulWidget {
  final int groupId;
  final String currency;

  const ReportScreen({
    super.key,
    required this.groupId,
    required this.currency,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Report? _report;
  bool _isLoading = false;
  String? _errorMessage;
  bool _useOptimalSettlements = true; // Default to ON (optimal)

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final r = await api.fetchReport(widget.groupId);
      setState(() {
        _report = r;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Report & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReport,
          ),
        ],
      ),
      body: _isLoading && _report == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
              : _report == null
                  ? const Center(child: Text('No data available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- TOTAL SPEND CARD ---
                          _buildTotalSpendCard(),
                          const SizedBox(height: 16),

                          // --- MEMBER BALANCES SECTION ---
                          _buildBalancesSection(),
                          const SizedBox(height: 16),

                          // --- SETTLEMENT DEBTS TOGGLE CARD ---
                          _buildDebtsSection(),
                          const SizedBox(height: 16),

                          // --- CHARTS / INSIGHTS ---
                          _buildInsightsSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildTotalSpendCard() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'TOTAL GROUP SPEND',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.currency} ${_report!.totalSpend.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Net Balances',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Positive means owed money; negative means owes money.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _report!.balances.length,
              itemBuilder: (context, index) {
                final mb = _report!.balances[index];
                final isPositive = mb.balance > 0;
                final isNegative = mb.balance < 0;
                
                Color statusColor = Colors.grey;
                String statusText = 'Settled';
                 if (isPositive) {
                  statusColor = const Color(0xFF10B981);
                  statusText = 'gets back';
                } else if (isNegative) {
                  statusColor = const Color(0xFFEF4444);
                  statusText = 'owes';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: statusColor.withOpacity(0.15),
                        child: Text(
                          mb.email.substring(0, 1).toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mb.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.currency} ${mb.balance.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtsSection() {
    final activeDebts = _useOptimalSettlements ? _report!.optimalTransactions : _report!.directDebts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debt Settlement Plan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _useOptimalSettlements ? 'Optimal (simplified)' : 'Direct pairwise (unsimplified)',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Switch(
                  value: _useOptimalSettlements,
                  activeColor: const Color(0xFF8B5CF6),
                  onChanged: (val) {
                    setState(() {
                      _useOptimalSettlements = val;
                    });
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            if (activeDebts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'No payments needed! Everyone is settled.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeDebts.length,
                itemBuilder: (context, index) {
                  final debt = activeDebts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  debt.fromUser.email,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text('pays', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  debt.toUser.email,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${widget.currency} ${debt.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      children: [
        // --- CATEGORY PIE CHART ---
        if (_report!.categoryBreakdown.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 40,
                        sections: _buildPieSections(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPieLegend(),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Helper colors for charts
  final List<Color> _chartColors = [
    const Color(0xFF8B5CF6),
    const Color(0xFF10B981),
    const Color(0xFF3B82F6),
    const Color(0xFFF59E0B),
    const Color(0xFFEC4899),
    const Color(0xFF06B6D4),
  ];

  List<PieChartSectionData> _buildPieSections() {
    double total = _report!.categoryBreakdown.fold(0.0, (sum, item) => sum + item.amount);
    if (total == 0) total = 1;

    return List.generate(_report!.categoryBreakdown.length, (index) {
      final cat = _report!.categoryBreakdown[index];
      final pct = (cat.amount / total) * 100;
      final color = _chartColors[index % _chartColors.length];

      return PieChartSectionData(
        color: color,
        value: cat.amount,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
  }

  Widget _buildPieLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(_report!.categoryBreakdown.length, (index) {
        final cat = _report!.categoryBreakdown[index];
        final color = _chartColors[index % _chartColors.length];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '${cat.category}: ${widget.currency} ${cat.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }),
    );
  }}
