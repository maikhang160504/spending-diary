import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import 'package:intl/intl.dart';

class LoanFormScreen extends StatefulWidget {
  final String? walletId;
  const LoanFormScreen({super.key, this.walletId});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _contactName = '';
  String _type = 'lend';
  String _amount = '';
  DateTime? _dueDate;
  String _note = '';
  bool _createTransaction = false;
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày đến hạn')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiClient().createLoan({
        'wallet_id': widget.walletId,
        'contact_name': _contactName,
        'type': _type,
        'amount': double.tryParse(_amount.replaceAll(',', '')) ?? 0,
        'due_date': DateFormat('yyyy-MM-dd').format(_dueDate!),
        'note': _note,
        'create_transaction': _createTransaction,
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: const Text('Thêm khoản vay'),
        backgroundColor: context.palette.card,
        foregroundColor: context.palette.textPrimary,
        elevation: 0,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Loại giao dịch', style: TextStyle(color: context.palette.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Cho vay'),
                      value: 'lend',
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Đi vay'),
                      value: 'borrow',
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: _type == 'lend' ? 'Người vay' : 'Người cho vay',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
                onSaved: (v) => _contactName = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Số tiền',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixText: 'đ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập số tiền' : null,
                onSaved: (v) => _amount = v!,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _dueDate = date);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Hạn trả',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_dueDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(_dueDate!)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
                onSaved: (v) => _note = v ?? '',
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Tạo giao dịch thu/chi trong ví'),
                subtitle: const Text('Tự động trừ hoặc cộng số dư vào ví thực tế của bạn'),
                value: _createTransaction,
                onChanged: (v) => setState(() => _createTransaction = v),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.teal,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text('Lưu khoản vay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
