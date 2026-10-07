class Medicine {
  final String id;
  final String gtin;
  final String name;
  final String description;
  final DateTime expiryDate;
  final String lotNumber;
  final String? serialNumber;
  final List<String> assignedTo;
  final DateTime scannedAt;

  Medicine({
    required this.id,
    required this.gtin,
    required this.name,
    required this.description,
    required this.expiryDate,
    required this.lotNumber,
    this.serialNumber,
    this.assignedTo = const [],
    required this.scannedAt,
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isForAll => assignedTo.contains('ALL');

  Map<String, dynamic> toJson() => {
        'id': id,
        'gtin': gtin,
        'name': name,
        'description': description,
        'expiryDate': expiryDate.toIso8601String(),
        'lotNumber': lotNumber,
        'serialNumber': serialNumber,
        'assignedTo': assignedTo,
        'scannedAt': scannedAt.toIso8601String(),
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        gtin: json['gtin'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        expiryDate: DateTime.parse(json['expiryDate'] as String),
        lotNumber: json['lotNumber'] as String? ?? '',
        serialNumber: json['serialNumber'] as String?,
        assignedTo: (json['assignedTo'] as List<dynamic>?)?.cast<String>() ?? [],
        scannedAt: DateTime.parse(json['scannedAt'] as String),
      );

  Medicine copyWith({
    String? id,
    String? gtin,
    String? name,
    String? description,
    DateTime? expiryDate,
    String? lotNumber,
    String? serialNumber,
    List<String>? assignedTo,
    DateTime? scannedAt,
  }) =>
      Medicine(
        id: id ?? this.id,
        gtin: gtin ?? this.gtin,
        name: name ?? this.name,
        description: description ?? this.description,
        expiryDate: expiryDate ?? this.expiryDate,
        lotNumber: lotNumber ?? this.lotNumber,
        serialNumber: serialNumber ?? this.serialNumber,
        assignedTo: assignedTo ?? this.assignedTo,
        scannedAt: scannedAt ?? this.scannedAt,
      );
}