import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/external_launcher.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/debt_customer.dart';
import '../../data/models/debt_entry.dart';
import '../../data/repos/debt_repo.dart';
import '../../data/repos/providers.dart';
import 'debt_message.dart';
import 'debt_provider.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final _customerFormKey = GlobalKey<FormState>();
  final _entryFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _customerNotes = TextEditingController();
  final _itemName = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _amount = TextEditingController();
  final _entryNotes = TextEditingController();

  int? _selectedCustomerId;
  int? _editingCustomerId;
  String _search = '';
  bool _savingCustomer = false;
  bool _savingEntry = false;
  bool _sendingReminder = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _customerNotes.dispose();
    _itemName.dispose();
    _quantity.dispose();
    _amount.dispose();
    _entryNotes.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _selectCustomer(int? customerId) {
    setState(() => _selectedCustomerId = customerId);
  }

  void _loadCustomerForEdit(DebtCustomer customer) {
    setState(() {
      _editingCustomerId = customer.id;
      _selectedCustomerId = customer.id;
      _name.text = customer.name;
      _phone.text = customer.phone;
      _address.text = customer.address;
      _customerNotes.text = customer.notes;
    });
  }

  void _clearCustomerForm() {
    setState(() {
      _editingCustomerId = null;
      _name.clear();
      _phone.clear();
      _address.clear();
      _customerNotes.clear();
    });
    _customerFormKey.currentState?.reset();
  }

  void _clearEntryForm() {
    _itemName.clear();
    _quantity.text = '1';
    _amount.clear();
    _entryNotes.clear();
    _entryFormKey.currentState?.reset();
  }

  Future<void> _refreshDebtData() async {
    ref.invalidate(debtCustomersProvider);
    final selectedCustomerId = _selectedCustomerId;
    if (selectedCustomerId != null) {
      ref.invalidate(debtCustomerDetailsProvider(selectedCustomerId));
    }
  }

  Future<void> _saveCustomer() async {
    if (!(_customerFormKey.currentState?.validate() ?? false)) return;

    setState(() => _savingCustomer = true);
    try {
      final repo = ref.read(debtRepoProvider);
      final customer = await repo.saveCustomer(
        DebtCustomer(
          id: _editingCustomerId,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          notes: _customerNotes.text.trim(),
        ),
      );

      if (!mounted) return;
      _showSnack(_editingCustomerId == null ? 'Debt profile added' : 'Debt profile updated');
      _clearCustomerForm();
      setState(() => _selectedCustomerId = customer.id);
      await _refreshDebtData();
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Failed to save profile: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _savingCustomer = false);
      }
    }
  }

  Future<void> _addDebtEntry() async {
    if (_selectedCustomerId == null) {
      _showSnack('Select or create a customer first', error: true);
      return;
    }
    if (!(_entryFormKey.currentState?.validate() ?? false)) return;

    setState(() => _savingEntry = true);
    try {
      await ref.read(debtRepoProvider).addDebtEntry(
        DebtEntry(
          customerId: _selectedCustomerId!,
          itemName: _itemName.text.trim(),
          quantity: int.parse(_quantity.text.trim()),
          amountDue: double.parse(_amount.text.trim()),
          note: _entryNotes.text.trim(),
        ),
      );
      if (!mounted) return;
      _clearEntryForm();
      await _refreshDebtData();
      _showSnack('Debt item added');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Failed to add debt item: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _savingEntry = false);
      }
    }
  }

  Future<void> _togglePaid(DebtEntry entry, bool value) async {
    try {
      await ref.read(debtRepoProvider).toggleEntryPaid(entry.id!, value);
      await _refreshDebtData();
      if (!mounted) return;
      _showSnack(value ? 'Marked as paid' : 'Marked as unpaid');
    } catch (e) {
      _showSnack('Failed to update payment state: $e', error: true);
    }
  }

  Future<void> _deleteEntry(DebtEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete debt entry'),
        content: Text('Remove "${entry.itemName}" from this customer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ref.read(debtRepoProvider).deleteEntry(entry.id!);
      await _refreshDebtData();
      if (!mounted) return;
      _showSnack('Debt entry deleted');
    } catch (e) {
      _showSnack('Failed to delete debt entry: $e', error: true);
    }
  }

  Future<void> _openWhatsAppReminder(DebtCustomerDetails details) async {
    final normalizedPhone = normalizeWhatsAppPhone(details.customer.phone);
    if (normalizedPhone.isEmpty) {
      _showSnack('This customer does not have a valid WhatsApp number', error: true);
      return;
    }

    setState(() => _sendingReminder = true);
    try {
      final message = buildDebtReminderMessage(details);
      final url = 'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}';
      await launchExternalUrl(url);
      if (!mounted) return;
      _showSnack('WhatsApp reminder opened');
    } catch (e) {
      _showSnack('Could not open WhatsApp: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _sendingReminder = false);
      }
    }
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Required';
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid phone number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(debtCustomersProvider);
    final selectedCustomerId = _selectedCustomerId;
    final selectedDetailsAsync = selectedCustomerId == null
        ? null
        : ref.watch(debtCustomerDetailsProvider(selectedCustomerId));

    return Row(
      children: [
        SizedBox(
          width: 340,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _customerFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingCustomerId == null ? 'Add Debt Profile' : 'Edit Debt Profile',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _name,
                          label: 'Customer Name',
                          validator: Validators.required,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _phone,
                          label: 'WhatsApp Number',
                          validator: _validatePhone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _address,
                          label: 'Address',
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _customerNotes,
                          label: 'Notes',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _savingCustomer ? null : _saveCustomer,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(_editingCustomerId == null ? 'Save Profile' : 'Update Profile'),
                        ),
                        if (_editingCustomerId != null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _clearCustomerForm,
                            child: const Text('Cancel Editing'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _entryFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add Debt Item',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        summariesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Customers unavailable: $e'),
                          data: (summaries) {
                            if (_selectedCustomerId == null && summaries.isNotEmpty) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _selectedCustomerId == null) {
                                  setState(() => _selectedCustomerId = summaries.first.customer.id);
                                }
                              });
                            }
                            return DropdownButtonFormField<int>(
                              value: _selectedCustomerId,
                              items: summaries
                                  .map(
                                    (summary) => DropdownMenuItem<int>(
                                      value: summary.customer.id,
                                      child: Text(
                                        summary.customer.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              decoration: const InputDecoration(labelText: 'Select Customer'),
                              onChanged: summaries.isEmpty ? null : _selectCustomer,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _itemName,
                          label: 'Item Taken on Debt',
                          validator: Validators.required,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _quantity,
                          label: 'Quantity',
                          validator: Validators.nonZeroInt,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _amount,
                          label: 'Amount Due (PKR)',
                          validator: Validators.positiveDouble,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _entryNotes,
                          label: 'Entry Note',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _savingEntry ? null : _addDebtEntry,
                          icon: const Icon(Icons.add_card),
                          label: const Text('Add Debt Record'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: summariesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load debt profiles: $e')),
              data: (summaries) {
                final query = _search.toLowerCase();
                final filtered = summaries.where((summary) {
                  if (query.isEmpty) return true;
                  return summary.customer.name.toLowerCase().contains(query) ||
                      summary.customer.phone.toLowerCase().contains(query) ||
                      summary.customer.address.toLowerCase().contains(query);
                }).toList();

                final totalDue = summaries.fold<double>(0, (sum, item) => sum + item.totalDue);
                final outstandingCustomers = summaries.where((item) => item.totalDue > 0).length;
                final pendingRecords = summaries.fold<int>(0, (sum, item) => sum + item.unpaidCount);

                return Column(
                  children: [
                    SectionHeader(
                      title: 'Debt Profiles',
                      action: SizedBox(
                        width: 260,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search by name or phone',
                            prefixIcon: Icon(Icons.search, size: 18),
                            isDense: true,
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _DebtSummaryTile(
                            label: 'Outstanding Customers',
                            value: outstandingCustomers.toString(),
                            icon: Icons.people_alt_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DebtSummaryTile(
                            label: 'Total Due',
                            value: Fmt.currency(totalDue),
                            icon: Icons.account_balance_wallet_outlined,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DebtSummaryTile(
                            label: 'Debt Records',
                            value: pendingRecords.toString(),
                            icon: Icons.receipt_long_outlined,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Card(
                              child: filtered.isEmpty
                                  ? const EmptyState(
                                      icon: Icons.person_search,
                                      message: 'No debt profiles found',
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final summary = filtered[index];
                                        final isSelected = summary.customer.id == _selectedCustomerId;
                                        return ListTile(
                                          selected: isSelected,
                                          selectedTileColor: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.35),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          onTap: () => _selectCustomer(summary.customer.id),
                                          leading: CircleAvatar(
                                            child: Text(
                                              summary.customer.name.isEmpty
                                                  ? '?'
                                                  : summary.customer.name[0].toUpperCase(),
                                            ),
                                          ),
                                          title: Text(
                                            summary.customer.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Text(
                                            '${summary.customer.phone} | ${summary.lastItemName ?? 'No items yet'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                Fmt.currency(summary.totalDue),
                                                style: TextStyle(
                                                  color: summary.totalDue > 0
                                                      ? Theme.of(context).colorScheme.error
                                                      : Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                '${summary.unpaidCount} pending',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: selectedCustomerId == null
                                ? const Card(
                                    child: EmptyState(
                                      icon: Icons.contact_phone_outlined,
                                      message: 'Select a customer to view details',
                                    ),
                                  )
                                : selectedDetailsAsync!.when(
                                    loading: () => const Card(
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                    error: (e, _) => Card(
                                      child: Center(child: Text('Failed to load details: $e')),
                                    ),
                                    data: (details) {
                                      if (details == null) {
                                        return const Card(
                                          child: EmptyState(
                                            icon: Icons.person_off_outlined,
                                            message: 'Customer details unavailable',
                                          ),
                                        );
                                      }
                                      return _DebtDetailsPanel(
                                        details: details,
                                        isSendingReminder: _sendingReminder,
                                        onEditProfile: () => _loadCustomerForEdit(details.customer),
                                        onSendReminder: () => _openWhatsAppReminder(details),
                                        onTogglePaid: _togglePaid,
                                        onDeleteEntry: _deleteEntry,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DebtSummaryTile extends StatelessWidget {
  const _DebtSummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtDetailsPanel extends StatelessWidget {
  const _DebtDetailsPanel({
    required this.details,
    required this.isSendingReminder,
    required this.onEditProfile,
    required this.onSendReminder,
    required this.onTogglePaid,
    required this.onDeleteEntry,
  });

  final DebtCustomerDetails details;
  final bool isSendingReminder;
  final VoidCallback onEditProfile;
  final VoidCallback onSendReminder;
  final Future<void> Function(DebtEntry entry, bool value) onTogglePaid;
  final Future<void> Function(DebtEntry entry) onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final unpaidEntries = details.entries.where((entry) => !entry.isPaid).toList();
    final paidEntries = details.entries.where((entry) => entry.isPaid).toList();
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.customer.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(details.customer.phone),
                      if (details.customer.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(details.customer.address),
                      ],
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isSendingReminder || details.totalDue <= 0 ? null : onSendReminder,
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('WhatsApp Reminder'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailChip(
                  label: 'Outstanding',
                  value: Fmt.currency(details.totalDue),
                  color: cs.error,
                ),
                _DetailChip(
                  label: 'Pending Items',
                  value: unpaidEntries.length.toString(),
                  color: cs.primary,
                ),
                _DetailChip(
                  label: 'Paid Items',
                  value: paidEntries.length.toString(),
                  color: const Color(0xFF0F766E),
                ),
              ],
            ),
            if (details.customer.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(details.customer.notes),
            ],
            const SizedBox(height: 16),
            const SectionHeader(title: 'Debt History'),
            Expanded(
              child: details.entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'No debt records yet',
                    )
                  : ListView.separated(
                      itemCount: details.entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = details.entries[index];
                        final dateText = entry.entryDate == null ? '-' : Fmt.dateTime(entry.entryDate!);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: Checkbox(
                            value: entry.isPaid,
                            onChanged: (value) {
                              if (value != null) {
                                onTogglePaid(entry, value);
                              }
                            },
                          ),
                          title: Text(
                            '${entry.itemName} x${entry.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            entry.note.isEmpty ? dateText : '${entry.note}\n$dateText',
                          ),
                          isThreeLine: entry.note.isNotEmpty,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Fmt.currency(entry.amountDue),
                                style: TextStyle(
                                  color: entry.isPaid ? cs.primary : cs.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => onDeleteEntry(entry),
                                icon: Icon(Icons.delete_outline, color: cs.error, size: 18),
                                tooltip: 'Delete entry',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(label),
        ],
      ),
    );
  }
}
