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

const Color primaryColor = Color(0xFF4361EE);
const Color secondaryColor = Color(0xFF3A0CA3);
const Color accentColor = Color(0xFF4CC9F0);
const Color backgroundColor = Color(0xFFF8F9FA);
const Color cardColor = Colors.white;
const Color textPrimary = Color(0xFF212529);
const Color textSecondary = Color(0xFF6C757D);

const List<Color> qrColors = [
  Colors.black,
  Color(0xFF4361EE),
  Color(0xFF7209B7),
  Color(0xFFF72585),
  Color(0xFF4CC9F0),
  Color(0xFF38B000),
  Color(0xFFFF9E00),
];

const List<Color> qrBackgroundColors = [
  Colors.white,
  Color(0xFFF8F9FA),
  Color(0xFFE9ECEF),
  Color(0xFFE3F2FD),
  Color(0xFFE8F5E9),
  Color(0xFFFFF3E0),
  Color(0xFFF3E5F5),
  Color(0xFF212529),
];

const List<LinearGradient> qrGradients = [
  LinearGradient(colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)]),
  LinearGradient(colors: [Color(0xFF7209B7), Color(0xFFF72585)]),
  LinearGradient(colors: [Color(0xFF4CC9F0), Color(0xFF4361EE)]),
  LinearGradient(colors: [Color(0xFF38B000), Color(0xFF4CC9F0)]),
  LinearGradient(colors: [Color(0xFFFF9E00), Color(0xFFF72585)]),
  LinearGradient(colors: [Color(0xFF7209B7), Color(0xFF3A0CA3)]),
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
  final TextEditingController _textController = TextEditingController();

  String? _qrData;
  Color _qrColor = qrColors[0];
  Color _qrBackgroundColor = qrBackgroundColors[0];
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
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
                  bottom: 20,
                  right: 20,
                  child: pw.Opacity(
                    opacity: 0.3,
                    child: pw.Text(
                      'QRSG',
                      style: pw.TextStyle(
                        fontSize: 40,
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
                      pw.Text('QR Code Generated', 
                        style: pw.TextStyle(
                          fontSize: 28, 
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue
                        )
                      ),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300, width: 1),
                          borderRadius: pw.BorderRadius.circular(16),
                        ),
                        child: pw.Image(qrImage, width: 250, height: 250),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('Content:', 
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700
                              )
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(_qrData!, 
                              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                              textAlign: pw.TextAlign.center
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text('Generated on: ${DateTime.now().toString().split(' ')[0]}', 
                        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey500)
                      ),
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
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveImage(String format) async {
    if (_qrData == null || _qrData!.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      
      if (imageBytes == null) {
        throw Exception("Failed to capture QR Code");
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

      if (mounted) Navigator.pop(context);

      if (kIsWeb) {
        _downloadFileWeb(bytesToSave, '$fileName.$extension');
        return;
      }

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
        throw Exception("Could not find Downloads folder");
      }

      final String path = '${directory.path}/$fileName.$extension';
      final File file = File(path);
      await file.writeAsBytes(bytesToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to: ${path.split('/').last}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await OpenFile.open(path);
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.download_rounded, color: primaryColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Download QR Code',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Choose your preferred format',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _DownloadOptionTile(
                      icon: Icons.picture_as_pdf_rounded,
                      title: 'Save as PDF',
                      subtitle: 'Best for printing and documents',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _generateAndPrintPdf();
                      },
                    ),
                    _DownloadOptionTile(
                      icon: Icons.image_rounded,
                      title: 'Save as PNG',
                      subtitle: 'High quality with transparency',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _saveImage('png');
                      },
                    ),
                    _DownloadOptionTile(
                      icon: Icons.photo_rounded,
                      title: 'Save as JPG',
                      subtitle: 'Standard image format',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _saveImage('jpg');
                      },
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: textSecondary)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetAll() {
    setState(() {
      _qrData = null;
      _textController.clear();
      _qrColor = qrColors[0];
      _qrBackgroundColor = qrBackgroundColors[0];
      _logoBytes = null;
      _useGradient = false;
      _qrGradient = null;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = _qrData != null && _qrData!.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120,
              collapsedHeight: 80,
              floating: true,
              pinned: true,
              snap: false,
              elevation: 0,
              backgroundColor: cardColor,
              surfaceTintColor: cardColor,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: CircleAvatar(
                  backgroundColor: backgroundColor,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              title: Text(
                'Create QR Code',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              centerTitle: false,
              actions: [
                if (hasData)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      backgroundColor: backgroundColor,
                      child: IconButton(
                        icon: const Icon(Icons.share_rounded, color: textPrimary),
                        onPressed: () async {
                          if (_qrData == null || _qrData!.isEmpty) return;

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
                              text: 'Check out this QR Code!',
                              subject: 'QR Code from QR Generator',
                            );
                          }
                        },
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor.withOpacity(0.05), accentColor.withOpacity(0.02)],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // QR Code Preview Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _qrBackgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: !hasData
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.qr_code_2_rounded, size: 60, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Enter text or link below to generate QR code',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
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
                                      // Logo Overlay
                                      if (_useGradient && _logoBytes != null)
                                        LayoutBuilder(
                                          builder: (context, constraints) {
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
                      const SizedBox(height: 24),
                      if (hasData)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ActionButton(
                              icon: Icons.download_rounded,
                              label: 'Download',
                              color: primaryColor,
                              onPressed: _showDownloadOptions,
                            ),
                            _ActionButton(
                              icon: Icons.restart_alt_rounded,
                              label: 'Reset',
                              color: textSecondary,
                              onPressed: _resetAll,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Input Section
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.text_fields_rounded, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QR Content',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Enter URL, text, or contact information',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'https://example.com or any text...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        maxLines: 4,
                        style: const TextStyle(color: textPrimary),
                        onChanged: (value) {
                          setState(() => _qrData = value.trim().isEmpty ? null : value.trim());
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Logo Upload Section
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.image_rounded, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Custom Logo',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Add your logo to the QR code center',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_logoBytes != null)
                        Column(
                          children: [
                            Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                                image: DecorationImage(
                                  image: MemoryImage(_logoBytes!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.upload_rounded),
                              label: Text(_logoBytes == null ? 'Upload Logo' : 'Change Logo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          if (_logoBytes != null) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => setState(() => _logoBytes = null),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.delete_rounded, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Customization Section
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.palette_rounded, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customize Style',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Choose colors and background',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Style Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _StyleToggleButton(
                                label: 'Solid',
                                icon: Icons.circle_rounded,
                                isActive: !_useGradient,
                                onTap: () => setState(() => _useGradient = false),
                              ),
                            ),
                            Expanded(
                              child: _StyleToggleButton(
                                label: 'Gradient',
                                icon: Icons.gradient_rounded,
                                isActive: _useGradient,
                                onTap: () {
                                  setState(() {
                                    _useGradient = true;
                                    if (_qrGradient == null) {
                                      _qrGradient = qrGradients.first;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Color/Gradient Selection
                      Text(
                        _useGradient ? 'Select Gradient' : 'Select Color',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _useGradient
                              ? qrGradients.map((gradient) {
                                  final isSelected = _qrGradient == gradient;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _qrGradient = gradient),
                                      child: Container(
                                        width: 56,
                                        decoration: BoxDecoration(
                                          gradient: gradient,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? primaryColor : Colors.transparent,
                                            width: 3,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Center(
                                                child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList()
                              : qrColors.map((color) {
                                  final isSelected = _qrColor == color;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _qrColor = color),
                                      child: Container(
                                        width: 56,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? primaryColor : Colors.transparent,
                                            width: 3,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Center(
                                                child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Background Color Selection
                      Text(
                        'Background Color',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: qrBackgroundColors.map((color) {
                            final isSelected = _qrBackgroundColor == color;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => setState(() => _qrBackgroundColor = color),
                                child: Container(
                                  width: 56,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? primaryColor : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: color == Colors.black ? Colors.white : Colors.black,
                                            size: 20,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }
}

class _StyleToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _StyleToggleButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : textSecondary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DownloadOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}