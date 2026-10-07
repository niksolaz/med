import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';
import '../services/drug_lookup_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final String? gtin;
  final DateTime? expiryDate;
  final String? lot;
  final String? serial;
  final bool isGs1;
  final Medicine? medicine; // se non-null, modalità modifica

  const AddMedicineScreen({
    super.key,
    this.gtin,
    this.expiryDate,
    this.lot = '',
    this.serial,
    this.isGs1 = false,
    this.medicine,
  });

  /// Factory per modalità modifica
  factory AddMedicineScreen.edit({required Medicine medicine}) {
    return AddMedicineScreen(
      gtin: medicine.gtin,
      expiryDate: medicine.expiryDate,
      lot: medicine.lotNumber,
      serial: medicine.serialNumber,
      isGs1: true,
      medicine: medicine,
    );
  }

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _assigneeController = TextEditingController();
  final _lookupService = DrugLookupService();
  bool _isLookingUp = false;
  bool _isSaving = false;
  String? _lookupError;
  DateTime? _selectedExpiry;
  final List<String> _assignees = [];
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool get _isEditMode => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    _selectedExpiry = widget.expiryDate;

    if (_isEditMode) {
      final m = widget.medicine!;
      _nameController.text = m.name;
      _descController.text = m.description;
      _assignees.addAll(m.assignedTo);
    } else if (widget.isGs1) {
      _autoLookup();
    } else {
      _lookupError = 'Codice non GS1 rilevato. Inserisci i dati manualmente.';
    }
  }

  Future<void> _autoLookup() async {
    setState(() => _isLookingUp = true);
    final info = await _lookupService.lookupByGtin(widget.gtin!);
    if (mounted) {
      setState(() {
        _isLookingUp = false;
        if (info != null) {
          _nameController.text = info.name;
          _descController.text = info.description;
        } else {
          _lookupError = 'Nessun dato trovato nel database FDA.\nInserisci i dati manualmente.';
        }
      });
    }
  }

  Future<void> _searchManually() async {
    final query = _nameController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLookingUp = true;
      _lookupError = null;
    });

    final results = await _lookupService.searchByName(query);
    if (!mounted) return;

    if (results.isEmpty) {
      setState(() {
        _isLookingUp = false;
        _lookupError = 'Nessun risultato trovato.';
      });
      return;
    }

    final chosen = await showDialog<DrugInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleziona medicinale'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (_, i) {
              final d = results[i];
              return ListTile(
                title: Text(d.name),
                subtitle: Text(d.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, d),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        ],
      ),
    );

    setState(() => _isLookingUp = false);
    if (chosen != null && mounted) {
      _nameController.text = chosen.name;
      _descController.text = chosen.description;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _selectedExpiry = picked);
  }

  void _addAssignee() {
    final name = _assigneeController.text.trim();
    if (name.isEmpty) return;
    if (_assignees.contains(name)) {
      _assigneeController.clear();
      return;
    }
    setState(() {
      _assignees.add(name);
      _assigneeController.clear();
    });
  }

  void _removeAssignee(String name) {
    setState(() => _assignees.remove(name));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il nome del medicinale')),
      );
      return;
    }
    if (_selectedExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci la data di scadenza')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final medicine = Medicine(
      id: _isEditMode ? widget.medicine!.id : const Uuid().v4(),
      gtin: widget.gtin ?? '',
      name: name,
      description: _descController.text.trim(),
      expiryDate: _selectedExpiry!,
      lotNumber: widget.lot ?? '',
      serialNumber: widget.serial,
      assignedTo: List.from(_assignees),
      scannedAt: _isEditMode ? widget.medicine!.scannedAt : DateTime.now(),
    );

    if (mounted) Navigator.of(context).pop(medicine);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = _selectedExpiry != null ? _selectedExpiry!.difference(now).inDays : null;
    final isExpired = daysLeft != null && daysLeft < 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifica medicinale' : 'Aggiungi medicinale'),
        backgroundColor: const Color(0xFF1b5a5a),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            if (widget.gtin != null && widget.gtin!.isNotEmpty)
              Card(
                color: const Color(0xFFf5f0e8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Dati rilevati',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          if (!widget.isGs1)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Manuale', style: TextStyle(fontSize: 11, color: Colors.orange)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _infoRow('Codice', widget.gtin ?? '-'),
                      if (widget.lot != null && widget.lot!.isNotEmpty) _infoRow('Lotto', widget.lot!),
                      if (widget.serial != null && widget.serial!.isNotEmpty) _infoRow('Seriale', widget.serial!),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Data scadenza
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data di scadenza *',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                  errorText: _selectedExpiry == null ? 'Obbligatoria' : null,
                ),
                child: Text(
                  _selectedExpiry != null ? _dateFormat.format(_selectedExpiry!) : 'Seleziona data',
                  style: TextStyle(
                    color: _selectedExpiry != null ? (isExpired ? Colors.red : null) : Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (daysLeft != null && daysLeft >= 0 && daysLeft <= 60)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text('Scade tra $daysLeft giorni',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
              ),
            const SizedBox(height: 16),

            // Nome
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome medicinale *',
                border: const OutlineInputBorder(),
                suffixIcon: _isLookingUp
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Cerca nel database FDA',
                        onPressed: _searchManually,
                      ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Descrizione
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descrizione / A cosa serve',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),

            // Assegnatari
            Text('Assegnato a', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _assigneeController,
                    decoration: InputDecoration(
                      hintText: 'Nome persona o animale',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF1b5a5a)),
                        onPressed: _addAssignee,
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _addAssignee(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Chip "ALL"
            Row(
              children: [
                ActionChip(
                  avatar: Icon(
                    _assignees.contains('ALL') ? Icons.check : Icons.add,
                    size: 18,
                  ),
                  label: const Text('Tutti (ALL)'),
                  backgroundColor: _assignees.contains('ALL') ? Colors.blue.shade100 : null,
                  onPressed: () {
                    setState(() {
                      if (_assignees.contains('ALL')) {
                        _assignees.remove('ALL');
                      } else {
                        _assignees.insert(0, 'ALL');
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text('assegna a tutti', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            if (_assignees.where((n) => n != 'ALL').isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _assignees
                    .where((n) => n != 'ALL')
                    .map((name) => Chip(
                          label: Text(name),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeAssignee(name),
                          backgroundColor: Colors.teal.shade50,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],

            if (_lookupError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_lookupError!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic)),
              ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isEditMode ? Icons.check : Icons.save),
              label: Text(_isSaving ? 'Salvataggio...' : (_isEditMode ? 'Aggiorna medicinale' : 'Salva medicinale')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1b5a5a),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}