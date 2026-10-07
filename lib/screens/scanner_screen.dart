import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/gs1_parser.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final Gs1Parser _parser = Gs1Parser();
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [
        BarcodeFormat.dataMatrix,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.pdf417,
        BarcodeFormat.qrCode,
        BarcodeFormat.aztec,
        BarcodeFormat.itf,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    debugPrint('Barcode: format=${barcode.format}, value=$rawValue');

    setState(() => _isProcessing = true);

    // Prova il parsing GS1
    _parser.parse(rawValue);
    final gtin = _parser.gtin;
    final expiryDate = _parser.expiryDate;
    final lot = _parser.lot;
    final serial = _parser.serial;

    if (!mounted) return;

    // Se GS1 funziona, usa quei dati. Altrimenti passa il codice raw come identificativo.
    Navigator.of(context).pop({
      'gtin': gtin ?? rawValue,
      'expiry_date': expiryDate,
      'lot': lot ?? '',
      'serial': serial ?? '',
      'is_gs1': gtin != null,
      'raw_barcode': rawValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona medicinale'),
        backgroundColor: const Color(0xFF1b5a5a),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Errore fotocamera: $error', textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Indietro'),
                    ),
                  ],
                ),
              );
            },
          ),
          // Mirino
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1b5a5a), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Istruzioni
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Text(
              'Inquadra il codice a barre\nsulla confezione del medicinale',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 8),
                ],
              ),
            ),
          ),
          // Torcia
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.flashlight_on,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
              onPressed: () => _controller.toggleTorch(),
            ),
          ),
        ],
      ),
    );
  }
}