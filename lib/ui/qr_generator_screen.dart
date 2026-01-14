import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:image/image.dart' as img;
import 'package:universal_html/html.dart' as html;

const Color primaryColor = Color(0xFF3A2EC3);

const List<Color> qrColors = [
  Colors.black,
  Color(0xFF3A2EC3),
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
];

const List<Color> qrBackgroundColors = [
  Colors.white,
  Color(0xFFF5F5F5), // Grey 100
  Color(0xFFE3F2FD), // Blue 50
  Color(0xFFE8F5E9), // Green 50
  Color(0xFFFFF3E0), // Orange 50
  Color(0xFFF3E5F5), // Purple 50
  Colors.black,
];

const List<LinearGradient> qrGradients = [
  LinearGradient(colors: [Color(0xFF3A2EC3), Color(0xFFF65C8C)]),
  LinearGradient(colors: [Colors.blue, Colors.purple]),
  LinearGradient(colors: [Colors.orange, Colors.red]),
  LinearGradient(colors: [Colors.green, Colors.teal]),
  LinearGradient(colors: [Colors.indigo, Colors.cyan]),
  LinearGradient(colors: [Colors.black, Colors.grey]),
];

// 1x1 Transparent PNG for placeholder
final Uint8List kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82
]);

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();

  String? _qrData;
  Color _qrColor = Colors.black;
  Color _qrBackgroundColor = Colors.white;
  Uint8List? _logoBytes;
  Gradient? _qrGradient;
  bool _useGradient = false;

  Future<void> _pickLogo() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _logoBytes = bytes;
      });
    }
  }

  // Helper for Web Download
  void _downloadFileWeb(List<int> bytes, String fileName) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _generateAndPrintPdf() async {
    if (_qrData == null || _qrData!.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      
      if (imageBytes == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final pdf = pw.Document();
      final qrImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // Watermark
                pw.Positioned(
                  bottom: 0,
                  right: 0,
                  child: pw.Opacity(
                    opacity: 0.5,
                    child: pw.Text(
                      'QR S&G App',
                      style: pw.TextStyle(
                        fontSize: 20,
                        color: PdfColors.grey,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Content
                pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('QR Code Generated', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 20),
                      pw.Image(qrImage, width: 250, height: 250),
                      pw.SizedBox(height: 20),
                      pw.Text('Link/Teks: $_qrData', style: pw.TextStyle(fontSize: 14)),
                      pw.SizedBox(height: 10),
                      pw.Text('Dibuat oleh: Mas Ade', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();

      // Hide loading
      if (mounted) Navigator.pop(context);

      // Handle Web Download
      if (kIsWeb) {
        _downloadFileWeb(pdfBytes, 'QR_Code_${DateTime.now().millisecondsSinceEpoch}.pdf');
        return;
      }

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'QR_Code_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      // Hide loading if error
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Future<void> _saveImage(String format) async {
    if (_qrData == null || _qrData!.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      
      if (imageBytes == null) {
        throw Exception("Gagal mengambil screenshot QR Code");
      }

      String fileName = 'QR_Code_${DateTime.now().millisecondsSinceEpoch}';
      List<int> bytesToSave = imageBytes;
      String extension = 'png';

      if (format == 'jpg') {
        final img.Image? image = img.decodeImage(imageBytes);
        if (image != null) {
          bytesToSave = img.encodeJpg(image);
          extension = 'jpg';
        }
      }

      // Hide loading
      if (mounted) Navigator.pop(context);

      // Handle Web
      if (kIsWeb) {
        _downloadFileWeb(bytesToSave, '$fileName.$extension');
        return;
      }

      // Handle Mobile (Android/iOS)
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception("Tidak dapat menemukan folder Downloads");
      }

      final String path = '${directory.path}/$fileName.$extension';
      final File file = File(path);
      await file.writeAsBytes(bytesToSave);

      // Show success & Open file
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gambar disimpan di: $path')),
        );
        await OpenFile.open(path);
      }

    } catch (e) {
      // Hide loading if error
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Download QR Code', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Save as PDF'),
                subtitle: const Text('Best for printing'),
                onTap: () {
                  Navigator.pop(context);
                  _generateAndPrintPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('Save as PNG'),
                subtitle: const Text('High quality image with transparency support'),
                onTap: () {
                  Navigator.pop(context);
                  _saveImage('png');
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined, color: Colors.orange),
                title: const Text('Save as JPG'),
                subtitle: const Text('Standard image format'),
                onTap: () {
                  Navigator.pop(context);
                  _saveImage('jpg');
                },
              ),
              ListTile(
                leading: const Icon(Icons.code, color: Colors.purple),
                title: const Text('Save as SVG'),
                subtitle: const Text('Vector format (Coming Soon)'),
                enabled: false, // Disabled for now as it requires complex vector export logic
                onTap: () {
                  Navigator.pop(context);
                  // Implement SVG export if feasible or show "Not supported"
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = _qrData != null && _qrData!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create QR', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(height: 220, color: primaryColor),
              Expanded(child: Container(color: Colors.grey.shade50)),
            ],
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // QR Display + Input + Controls
                        Screenshot(
                          controller: _screenshotController,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _qrBackgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                              ],
                            ),
                            child: !hasData
                                ? const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Text(
                                      'Masukkan teks/link untuk generate QR',
                                      style: TextStyle(color: Colors.grey, fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : AspectRatio(
                                    aspectRatio: 1,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Base QR Code
                                        Builder(
                                          builder: (context) {
                                            Widget qrView = PrettyQrView.data(
                                              data: _qrData!,
                                              errorCorrectLevel: QrErrorCorrectLevel.H,
                                              decoration: PrettyQrDecoration(
                                                shape: PrettyQrSmoothSymbol(
                                                  color: _useGradient ? Colors.black : _qrColor,
                                                ),
                                                image: _logoBytes != null
                                                    ? PrettyQrDecorationImage(
                                                        image: _useGradient
                                                            ? MemoryImage(kTransparentPng)
                                                            : MemoryImage(_logoBytes!),
                                                        scale: 0.2,
                                                      )
                                                    : null,
                                              ),
                                            );

                                            if (_useGradient && _qrGradient != null) {
                                              return ShaderMask(
                                                shaderCallback: (bounds) => _qrGradient!.createShader(bounds),
                                                blendMode: BlendMode.srcIn,
                                                child: qrView,
                                              );
                                            }
                                            return qrView;
                                          },
                                        ),
                                        // Logo Overlay (only if gradient is used, to avoid tinting)
                                        if (_useGradient && _logoBytes != null)
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Calculate 20% size to match PrettyQrDecorationImage default scale
                                              final size = constraints.maxWidth * 0.2;
                                              return Container(
                                                width: size,
                                                height: size,
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: MemoryImage(_logoBytes!),
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Link atau Teks',
                            hintText: 'https://example.com atau teks apa saja',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            setState(() => _qrData = value.trim().isEmpty ? null : value.trim());
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Logo Picker
                        Row(
                          children: [
                            Text('Logo (Optional)', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            if (_logoBytes != null)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => setState(() => _logoBytes = null),
                              ),
                            ElevatedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.image),
                              label: Text(_logoBytes == null ? 'Upload' : 'Change'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                foregroundColor: Colors.black,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Collapsible QR Style & Colors
                        ExpansionTile(
                          title: const Text('QR Style & Colors'),
                          childrenPadding: const EdgeInsets.only(bottom: 16),
                          children: [
                            Row(
                              children: [
                                Text('QR Style', style: Theme.of(context).textTheme.titleMedium),
                                const Spacer(),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(value: false, label: Text('Solid')),
                                    ButtonSegment(value: true, label: Text('Gradient')),
                                  ],
                                  selected: {_useGradient},
                                  onSelectionChanged: (Set<bool> newSelection) {
                                    setState(() {
                                      _useGradient = newSelection.first;
                                      if (_useGradient && _qrGradient == null) {
                                        _qrGradient = qrGradients.first;
                                      }
                                    });
                                  },
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Color/Gradient Picker
                            if (!_useGradient)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: qrColors.map((color) {
                                  return GestureDetector(
                                    onTap: () => setState(() => _qrColor = color),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _qrColor == color ? Colors.black : Colors.grey.shade300,
                                          width: _qrColor == color ? 3 : 1,
                                        ),
                                      ),
                                      child: _qrColor == color
                                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              )
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: qrGradients.map((gradient) {
                                  final isSelected = _qrGradient == gradient;
                                  return GestureDetector(
                                    onTap: () => setState(() => _qrGradient = gradient),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: gradient,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.black : Colors.grey.shade300,
                                          width: isSelected ? 3 : 1,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            
                            const SizedBox(height: 24),

                            // Background Color Picker
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Background Color', style: Theme.of(context).textTheme.titleMedium),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: qrBackgroundColors.map((color) {
                                final isSelected = _qrBackgroundColor == color;
                                return GestureDetector(
                                  onTap: () => setState(() => _qrBackgroundColor = color),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? primaryColor : Colors.grey.shade300,
                                        width: isSelected ? 3 : 1,
                                      ),
                                      boxShadow: [
                                        if (isSelected)
                                          BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: isSelected
                                        ? Icon(Icons.check, color: color == Colors.white ? Colors.black : Colors.white, size: 20)
                                        : null,
                                    ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _qrData = null;
                                    _qrColor = Colors.black;
                                    _qrBackgroundColor = Colors.white;
                                    _logoBytes = null;
                                    _useGradient = false;
                                    _qrGradient = null;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: !hasData ? null : () async {
                                  if (_qrData == null || _qrData!.isEmpty) return;

                                  await Future.delayed(const Duration(milliseconds: 100));

                                  final Uint8List? imageBytes = await _screenshotController.capture(
                                    pixelRatio: MediaQuery.of(context).devicePixelRatio,
                                  );

                                  if (imageBytes != null) {
                                    await Share.shareXFiles(
                                      [
                                        XFile.fromData(
                                          imageBytes,
                                          name: 'qr_code.png',
                                          mimeType: 'image/png',
                                        ),
                                      ],
                                      text: 'QR Code untuk: $_qrData\nDibuat dengan QR S&G',
                                      subject: 'QR Code dari QR S&G App',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text('Send'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: !hasData ? null : () async {
                                  if (_qrData == null || _qrData!.isEmpty) return;

                                  await Future.delayed(const Duration(milliseconds: 100));

                                  final Uint8List? imageBytes = await _screenshotController.capture(
                                    pixelRatio: MediaQuery.of(context).devicePixelRatio,
                                  );

                                  if (imageBytes != null) {
                                    await Share.shareXFiles([
                                      XFile.fromData(
                                        imageBytes,
                                        name: 'qrcode_dateTime.png',
                                        mimeType: 'image/png',
                                      ),
                                    ]);
                                  }
                                },
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text('Share'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: !hasData ? null : _showDownloadOptions,
                            icon: const Icon(Icons.download),
                            label: const Text('Download QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}