import '../../../core/domain/money.dart';
import '../../../core/domain/quantity.dart';
import '../../products/products_public.dart';
import '../application/create_sale.dart';
import '../domain/sale.dart';

/// An in-progress line item in the shopkeeper's cart.
final class CartLine {
  const CartLine({
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.productId,
  });

  final String? productId;
  final String description;
  final String unit;
  final Quantity quantity;
  final Money unitPrice;

  Money get lineTotal => quantity.times(unitPrice);

  CartLine copyWith({
    String? description,
    String? unit,
    Quantity? quantity,
    Money? unitPrice,
  }) =>
      CartLine(
        productId: productId,
        description: description ?? this.description,
        unit: unit ?? this.unit,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );

  CreateSaleItemInput toInput() => CreateSaleItemInput(
        productId: productId,
        description: description,
        unit: unit,
        quantity: quantity,
        unitPrice: unitPrice,
      );
}

/// In-progress bill state.
final class CartState {
  const CartState({
    this.customerId,
    this.customerName,
    this.saleType = SaleType.credit,
    this.items = const [],
    this.initialPayment,
    this.note,
    this.dueAt,
  });

  final String? customerId;
  final String? customerName;
  final SaleType saleType;
  final List<CartLine> items;
  final Money? initialPayment;
  final String? note;
  final DateTime? dueAt;

  Money get total => Money.sum(items.map((i) => i.lineTotal));

  Money get balanceDue {
    final paid = initialPayment ?? Money.zero;
    final remaining = total - paid;
    return remaining.isNegative ? Money.zero : remaining;
  }

  bool get isValid =>
      customerId != null && items.isNotEmpty && !total.isNegative;

  CartState copyWith({
    String? customerId,
    String? customerName,
    SaleType? saleType,
    List<CartLine>? items,
    Money? initialPayment,
    bool clearInitialPayment = false,
    String? note,
    DateTime? dueAt,
  }) =>
      CartState(
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        saleType: saleType ?? this.saleType,
        items: items ?? this.items,
        initialPayment: clearInitialPayment
            ? null
            : (initialPayment ?? this.initialPayment),
        note: note ?? this.note,
        dueAt: dueAt ?? this.dueAt,
      );

  CartState addItemFromProduct(Product product, Quantity quantity) {
    final existingIndex =
        items.indexWhere((line) => line.productId == product.id);
    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      final newQty = Quantity.milli(existing.quantity.milli + quantity.milli);
      final updated = List<CartLine>.from(items);
      updated[existingIndex] = existing.copyWith(quantity: newQty);
      return copyWith(items: updated);
    }

    final newLine = CartLine(
      productId: product.id,
      description: product.name,
      unit: product.unit,
      quantity: quantity,
      unitPrice: product.unitPrice,
    );
    return copyWith(items: [...items, newLine]);
  }
}
