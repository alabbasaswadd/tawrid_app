import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/warehouse_medicine_models.dart';

class WhCartItem {
  const WhCartItem({
    required this.warehouseMedicineId,
    required this.catalogItemId,
    required this.displayName,
    required this.genericName,
    required this.dosageForm,
  });

  final String warehouseMedicineId;
  final String catalogItemId;
  final String displayName;
  final String genericName;
  final DosageForm dosageForm;

  factory WhCartItem.fromMedicine(WarehouseMedicine m) => WhCartItem(
        warehouseMedicineId: m.id,
        catalogItemId: m.catalogItemId,
        displayName: m.displayName,
        genericName: m.genericName,
        dosageForm: m.dosageForm,
      );
}

class WhCartNotifier extends Notifier<List<WhCartItem>> {
  @override
  List<WhCartItem> build() => const [];

  bool contains(String warehouseMedicineId) =>
      state.any((i) => i.warehouseMedicineId == warehouseMedicineId);

  void add(WarehouseMedicine medicine) {
    if (contains(medicine.id)) return;
    state = [...state, WhCartItem.fromMedicine(medicine)];
  }

  void remove(String warehouseMedicineId) {
    state = state
        .where((i) => i.warehouseMedicineId != warehouseMedicineId)
        .toList();
  }

  void clear() => state = const [];
}

final whCartProvider =
    NotifierProvider<WhCartNotifier, List<WhCartItem>>(
  WhCartNotifier.new,
);
