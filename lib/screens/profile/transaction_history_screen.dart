import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';

class TransactionHistoryScreen extends StatefulWidget {
  static const routeName = '/transaction-history';

  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  _TransactionHistoryScreenState createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _selectedTimezone = 'WIB';
  final List<String> _timezones = ['WIB', 'WITA', 'WIT', 'London'];
  
  // Filter waktu
  String _selectedTimeFilter = 'all';
  final List<Map<String, dynamic>> _timeFilters = [
    {'value': 'all', 'label': 'Semua'},
    {'value': 'week', 'label': 'Seminggu Terakhir'},
    {'value': 'month', 'label': 'Sebulan Terakhir'},
    {'value': 'older', 'label': '> Sebulan'},
  ];
  
  @override
  void initState() {
    super.initState();
    _loadTransactionHistory();
  }

  Future<void> _loadTransactionHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await transactionProvider.fetchTransactions(authProvider.currentUser!.id!);
    }
  }

  List<BookTransaction> _getFilteredTransactions(List<BookTransaction> transactions) {
    if (_selectedTimeFilter == 'all') {
      return transactions;
    }
    
    final now = DateTime.now();
    
    return transactions.where((transaction) {
      final difference = now.difference(transaction.timestamp);
      
      switch (_selectedTimeFilter) {
        case 'week':
          return difference.inDays <= 7;
        case 'month':
          return difference.inDays <= 30;
        case 'older':
          return difference.inDays > 30;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final filteredTransactions = _getFilteredTransactions(transactionProvider.transactions);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          // Timezone Selection
          DropdownButton<String>(
            value: _selectedTimezone,
            dropdownColor: Theme.of(context).primaryColor,
            underline: Container(),
            icon: const Icon(Icons.access_time, color: Colors.white),
            selectedItemBuilder: (context) {
              return _timezones.map<Widget>((String item) {
                return Container(
                  alignment: Alignment.centerRight,
                  constraints: const BoxConstraints(minWidth: 60),
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList();
            },
            items: _timezones.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTimezone = value!;
              });
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Time filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Waktu:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _timeFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _timeFilters[index];
                      final isSelected = _selectedTimeFilter == filter['value'];
                      
                      return ChoiceChip(
                        label: Text(filter['label']),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTimeFilter = filter['value'];
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Transaction List
          Expanded(
            child: transactionProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTransactions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Belum ada transaksi',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactionHistory,
                        child: ListView.builder(
                          itemCount: filteredTransactions.length,
                          itemBuilder: (ctx, index) {
                            final transaction = filteredTransactions[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BookTransaction transaction) {
    final bool isCoinPurchase = transaction.transactionType == TransactionType.coinPurchase;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction ID and Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: #${transaction.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Chip(
                  label: Text(
                    isCoinPurchase ? 'Pembelian Koin' : 'Pembelian Buku',
                  ),
                  backgroundColor: isCoinPurchase ? Colors.green : Colors.blue,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Transaction Date
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _formatDate(transaction.timestamp),
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Transaction Time with Timezone
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _formatTime(transaction.getFormattedTimestamp(_selectedTimezone)),
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($_selectedTimezone)',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Transaction Details
            if (isCoinPurchase) ...[
              _buildDetailRow(
                'Jumlah Pembayaran',
                '${transaction.currency} ${transaction.amount.toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                'Koin Diterima',
                '${transaction.coins} Koin',
                valueColor: Colors.green,
              ),
            ] else ...[
              _buildDetailRow(
                'Koin Digunakan',
                '${transaction.coins} Koin',
                valueColor: Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }
  
  String _formatTime(String formattedTimestamp) {
    // Extract time part from "yyyy-MM-dd HH:mm:ss" format
    final parts = formattedTimestamp.split(' ');
    if (parts.length > 1) {
      return parts[1];
    }
    return formattedTimestamp;
  }
}