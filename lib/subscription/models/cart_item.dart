
import 'package:barky_matches_fixed/models/product.dart';

class CartItem {
  final String productId;
  final String shopId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final Product product;
  final List<String>? allowedCarrierCodes;
  
 
  

  const CartItem({
    required this.productId,
    required this.shopId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    required this.product,
    this.allowedCarrierCodes,
    
  });

  Map<String, dynamic> toJson() {
  return {
    'productId': productId,
    'shopId': shopId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'imageUrl': imageUrl,

    // ✅ فقط primitive های لازم برای backend
    'lengthCm': product.lengthCm,
    'widthCm': product.widthCm,
    'heightCm': product.heightCm,
    'weightKg': product.weightKg,
    'fixedDesi': product.fixedDesi,
    "allowedCarrierCodes": allowedCarrierCodes,
  };
}

  factory CartItem.fromJson(Map<String, dynamic> json) {
  final productJson = json['product'];

  return CartItem(
    productId: json['productId'] as String,
    shopId: json['shopId'] as String,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int,
    imageUrl: json['imageUrl'] as String?,
    allowedCarrierCodes: List<String>.from(
  json["allowedCarrierCodes"] ?? [],
),

    product: productJson != null
        ? Product.fromJson(
            json['productId'],
            Map<String, dynamic>.from(productJson),
          )
        : Product.empty(json['productId']),
  );
}

  CartItem copyWith({
  String? productId,
  String? shopId,
  String? name,
  double? price,
  int? quantity,
  String? imageUrl,
  Product? product,
  List<String>? allowedCarrierCodes,
}) {
  return CartItem(
    productId: productId ?? this.productId,
    shopId: shopId ?? this.shopId,
    name: name ?? this.name,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    imageUrl: imageUrl ?? this.imageUrl,
    product: product ?? this.product,
    allowedCarrierCodes: allowedCarrierCodes ?? this.allowedCarrierCodes,
  );
}
}