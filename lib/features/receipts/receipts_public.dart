/// Public contracts and types exported by the Receipts module.
/// Unrelated modules import ONLY this file.
library;

export 'application/receipt_ports.dart'
    show ReceiptRendererPort, ReceiptShareServicePort;
export 'domain/receipt_data.dart' show ReceiptData, ReceiptItemData;
export 'presentation/receipt_providers.dart'
    show
        receiptDataProvider,
        receiptPdfBytesProvider,
        receiptRendererProvider,
        receiptShareServiceProvider;
export 'presentation/screens/receipt_preview_screen.dart'
    show ReceiptPreviewScreen;
