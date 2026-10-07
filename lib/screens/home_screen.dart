import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/storage_service.dart';
import 'scanner_screen.dart';
import 'add_medicine_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;

  const HomeScreen({super.key, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filterAssignee = 'Tutti';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Medicine> get _filteredMedicines {
    var list = widget.storage.medicines;

    // Filtro persona
    if (_filterAssignee != 'Tutti') {
      list = widget.storage.filterByAssignee(_filterAssignee);
    }

    // Copia mutabile per il sort
    list = list.toList();

    // Filtro nome
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((m) => m.name.toLowerCase().contains(q)).toList();
    }

    // Ordina: scaduti prima, poi per scadenza più vicina
    list.sort((a, b) {
      final aExp = a.isExpired ? 0 : 1;
      final bExp = b.isExpired ? 0 : 1;
      if (aExp != bExp) return aExp.compareTo(bExp);
      return a.expiryDate.compareTo(b.expiryDate);
    });

    return list;
  }

  List<String> get _assignees {
    final names = widget.storage.allAssignees;
    return ['Tutti', ...names];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.storage,
        builder: (context, _) {
          final medicines = _filteredMedicines;
          if (widget.storage.medicines.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildMedicineList(context, medicines);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startScan(context),
        backgroundColor: const Color(0xFF1b5a5a),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scansiona'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Nessun medicinale registrato',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Scansiona il codice a barre sulla confezione\ndi un medicinale per iniziare.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _startScan(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scansiona primo medicinale'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1b5a5a)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineList(BuildContext context, List<Medicine> medicines) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expiredCount = widget.storage.expiredCount;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('I miei medicinali'),
          backgroundColor: const Color(0xFF1b5a5a),
          foregroundColor: Colors.white,
          pinned: true,
          expandedHeight: 170,
          flexibleSpace: FlexibleSpaceBar(background: Container(), expandedTitleScale: 1),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                if (expiredCount > 0)
                  Container(
                    color: Colors.red.shade100,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          '$expiredCount medicinale${expiredCount == 1 ? '' : 'i'} scaduto${expiredCount == 1 ? '' : 'i'}',
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                // Barra di ricerca
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Cerca per nome...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                // Filtro persone
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _assignees.map((name) {
                        final isSelected = _filterAssignee == name;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FilterChip(
                            label: Text(name),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _filterAssignee = name),
                            selectedColor: const Color(0xFF1b5a5a).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFF1b5a5a),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (medicines.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'Nessun medicinale trovato per "$_searchQuery"'
                      : 'Nessun medicinale per "$_filterAssignee"',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final medicine = medicines[index];
                  final daysLeft = medicine.daysUntilExpiry;
                  final isExpired = medicine.isExpired;

                  Color statusColor;
                  IconData statusIcon;
                  String statusText;

                  if (isExpired) {
                    statusColor = Colors.red;
                    statusIcon = Icons.cancel;
                    statusText = 'SCADUTO';
                  } else if (daysLeft <= 30) {
                    statusColor = Colors.orange;
                    statusIcon = Icons.warning_amber_rounded;
                    statusText = 'Scade tra $daysLeft gg';
                  } else if (daysLeft <= 90) {
                    statusColor = Colors.amber.shade700;
                    statusIcon = Icons.info_outline;
                    statusText = 'Scade il ${dateFormat.format(medicine.expiryDate)}';
                  } else {
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle_outline;
                    statusText = 'Scade il ${dateFormat.format(medicine.expiryDate)}';
                  }

                  return Dismissible(
                    key: Key(medicine.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Eliminare medicinale?'),
                          content: Text('Rimuovere "${medicine.name}" dalla lista?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Elimina', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) => widget.storage.delete(medicine.id),
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      color: isExpired ? Colors.red.shade50 : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showDetail(context, medicine),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(statusIcon, color: statusColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(medicine.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          decoration: isExpired ? TextDecoration.lineThrough : null,
                                        )),
                                    if (medicine.description.isNotEmpty)
                                      Text(medicine.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                    if (medicine.assignedTo.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          medicine.assignedTo.join(', '),
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(statusText,
                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: medicines.length,
              ),
            ),
          ),
      ],
    );
  }

  void _showDetail(BuildContext context, Medicine medicine) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final daysLeft = medicine.daysUntilExpiry;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(medicine.name,
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF1b5a5a)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _editMedicine(context, medicine);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('Eliminare?'),
                        content: Text('Rimuovere "${medicine.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annulla')),
                          TextButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Elimina', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true && ctx.mounted) {
                      Navigator.pop(ctx);
                      widget.storage.delete(medicine.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (medicine.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(medicine.description, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
              ),
            if (medicine.assignedTo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  children: medicine.assignedTo
                      .map((n) => Chip(
                            label: Text(n, style: const TextStyle(fontSize: 12)),
                            backgroundColor: n == 'ALL' ? Colors.blue.shade50 : Colors.teal.shade50,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),
            _detailRow('GTIN', medicine.gtin),
            _detailRow('Lotto', medicine.lotNumber.isNotEmpty ? medicine.lotNumber : '-'),
            if (medicine.serialNumber != null && medicine.serialNumber!.isNotEmpty)
              _detailRow('Seriale', medicine.serialNumber!),
            _detailRow('Scadenza', dateFormat.format(medicine.expiryDate)),
            if (daysLeft < 0)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 6),
                    Text('Questo medicinale è SCADUTO!',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade700))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _editMedicine(BuildContext context, Medicine medicine) async {
    final updated = await Navigator.of(context).push<Medicine>(
      MaterialPageRoute(builder: (_) => AddMedicineScreen.edit(medicine: medicine)),
    );
    if (updated != null && mounted) {
      await widget.storage.update(updated);
    }
  }

  Future<void> _startScan(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result == null || !context.mounted) return;

    final medicine = await Navigator.of(context).push<Medicine>(
      MaterialPageRoute(
        builder: (_) => AddMedicineScreen(
          gtin: result['gtin'] as String,
          expiryDate: result['expiry_date'] as DateTime?,
          lot: result['lot'] as String,
          serial: result['serial'] as String?,
          isGs1: result['is_gs1'] as bool? ?? false,
        ),
      ),
    );

    if (medicine != null && mounted) {
      await widget.storage.add(medicine);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('"${medicine.name}" salvato!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}