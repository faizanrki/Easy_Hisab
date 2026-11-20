import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../receipt_providers.dart';

class ReceiptPreviewScreen extends ConsumerWidget {
  const ReceiptPreviewScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(receiptDataProvider(saleId));
    final theme = Theme.of(context);

    return receiptAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading Receipt...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Receipt Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Could not load receipt: $err',
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
      data: (receipt) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Receipt #${receipt.receiptNo}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy Receipt Text',
                onPressed: () {
                  final text = receipt.formatWhatsAppText();
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt text copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Single WhatsApp send action
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // 1. Send WhatsApp Text
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                        ),
                        onPressed: () async {
                          final shareService =
                              ref.read(receiptShareServiceProvider);
                          final msg = receipt.formatWhatsAppText();
                          final launched = await shareService.shareToWhatsApp(
                            phone: receipt.customerPhone,
                            message: msg,
                          );
                          if (!launched && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Could not open WhatsApp. Receipt text copied to clipboard.'),
                              ),
                            );
                            Clipboard.setData(ClipboardData(text: msg));
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                        label: Text(
                          receipt.customerPhone != null
                              ? 'Send to ${receipt.customerName} on WhatsApp'
                              : 'WhatsApp Text',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive High-DPI PDF Preview (Crisp vector rendering)
              Expanded(
                child: PdfPreview(
                  dpi: 220, // High-DPI rendering for crisp typography
                  build: (format) async {
                    final renderer = ref.read(receiptRendererProvider);
                    return renderer.renderReceiptPdf(receipt);
                  },
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: false,
                  pdfFileName: 'EasyHisab_Receipt_${receipt.receiptNo}.pdf',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
