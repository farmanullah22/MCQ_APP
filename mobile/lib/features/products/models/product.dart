class Product {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String? categoryId;
  final String? categoryName;
  final String brand;
  final String supplier;
  final double costPrice;
  final double sellingPrice;
  final int quantity;
  final int lowStockThreshold;
  final String description;
  final List<String> images;
  final String? shopId;
  final String? shopName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.categoryId,
    this.categoryName,
    this.brand = '',
    this.supplier = '',
    required this.costPrice,
    required this.sellingPrice,
    this.quantity = 0,
    this.lowStockThreshold = 5,
    this.description = '',
    this.images = const [],
    this.shopId,
    this.shopName,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  double get stockValue => quantity * costPrice;

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    String? catId;
    String? catName;
    if (category is Map<String, dynamic>) {
      catId = (category['id'] ?? category['_id'])?.toString();
      catName = category['name']?.toString();
    } else if (category != null) {
      catId = category.toString();
    }
    final shop = json['shop'];
    String? sId;
    String? sName;
    if (shop is Map<String, dynamic>) {
      sId = (shop['id'] ?? shop['_id'])?.toString();
      sName = shop['name']?.toString();
    } else if (shop != null) {
      sId = shop.toString();
    }

    return Product(
      id: (json['id'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      categoryId: catId,
      categoryName: catName,
      brand: json['brand']?.toString() ?? '',
      supplier: json['supplier']?.toString() ?? '',
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 5,
      description: json['description']?.toString() ?? '',
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      shopId: sId,
      shopName: sName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'category': categoryId,
        'brand': brand,
        'supplier': supplier,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'lowStockThreshold': lowStockThreshold,
        'description': description,
        'images': images,
      };
}
