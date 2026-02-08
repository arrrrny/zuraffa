// Auto-generated cache for Product
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../domain/entities/product/product.dart';

Future<void> initProductCache() async {
  await Hive.openBox<Product>('products');
}
