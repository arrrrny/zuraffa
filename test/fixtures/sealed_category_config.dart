sealed class CategoryConfig {
  final String id;
  final String name;

  const CategoryConfig({required this.id, required this.name});
}

final class PrimaryCategory extends CategoryConfig {
  const PrimaryCategory({required super.id, required super.name});
}

final class SecondaryCategory extends CategoryConfig {
  const SecondaryCategory({required super.id, required super.name});
}
