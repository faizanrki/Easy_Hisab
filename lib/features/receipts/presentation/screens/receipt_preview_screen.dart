import 'package:flutter/material.dart';
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
                tooltip: 'Share via WhatsApp',
                icon: const Icon(Icons.send_rounded),
                onPressed: () async {
                  final shareService = ref.read(receiptShareServiceProvider);
                  final msg = receipt.formatWhatsAppText();
                  final launched = await shareService.shareToWhatsApp(
                    phone: receipt.customerPhone,
                    message: msg,
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open WhatsApp on this device.'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Bottom WhatsApp share bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp green
                          foregroundColor: Colors.white,
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
                                    'Could not open WhatsApp on this device.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(
                          receipt.customerPhone != null
                              ? 'Send to ${receipt.customerName} on WhatsApp'
                              : 'Share via WhatsApp',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive PDF Preview
              Expanded(
                child: PdfPreview(
                  build: (format) async {
                    final renderer = ref.read(receiptRendererProvider);
                    return renderer.renderReceiptPdf(receipt);
                  },
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  pdfFileName: 'receipt_${receipt.receiptNo}.pdf',
                  actions: [
                    PdfPreviewAction(
                      icon: const Icon(Icons.share_outlined),
                      onPressed: (ctx, buildFn, pageFormat) async {
                        final bytes = await buildFn(pageFormat);
                        final share = ref.read(receiptShareServiceProvider);
                        await share.shareReceiptPdf(receipt, bytes);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
