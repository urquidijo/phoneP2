import 'dart:convert';

import '../utils/formatters.dart';

class Category {
  const Category({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String?,
      );

  final int id;
  final String nombre;
  final String? descripcion;
}

class DiscountSummary {
  const DiscountSummary({
    required this.id,
    required this.porcentaje,
    required this.fechaInicio,
    this.fechaFin,
    required this.precioOriginal,
    required this.precioConDescuento,
    required this.estaActivo,
  });

  factory DiscountSummary.fromJson(Map<String, dynamic> json) => DiscountSummary(
        id: json['id'] as int,
        porcentaje: json['porcentaje'].toString(),
        fechaInicio: json['fecha_inicio'] as String,
        fechaFin: json['fecha_fin'] as String?,
        precioOriginal: json['precio_original'].toString(),
        precioConDescuento: json['precio_con_descuento'].toString(),
        estaActivo: json['esta_activo'] as bool? ?? false,
      );

  final int id;
  final String porcentaje;
  final String fechaInicio;
  final String? fechaFin;
  final String precioOriginal;
  final String precioConDescuento;
  final bool estaActivo;

  String get formattedWindow {
    final start = formatShortDate(fechaInicio);
    final end = fechaFin != null ? formatShortDate(fechaFin!) : 'Sin fecha fin';
    return '$start · $end';
  }
}

class Product {
  const Product({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precioRaw,
    required this.stock,
    required this.lowStockThreshold,
    this.categoria,
    this.imagen,
    this.activeDiscount,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String?,
        precioRaw: json['precio'].toString(),
        stock: json['stock'] as int? ?? 0,
        lowStockThreshold: json['low_stock_threshold'] as int? ?? 0,
        categoria: json['categoria'] == null
            ? null
            : Category.fromJson(json['categoria'] as Map<String, dynamic>),
        imagen: json['imagen'] as String?,
        activeDiscount: json['active_discount'] == null
            ? null
            : DiscountSummary.fromJson(
                json['active_discount'] as Map<String, dynamic>,
              ),
      );

  final int id;
  final String nombre;
  final String? descripcion;
  final String precioRaw;
  final int stock;
  final int lowStockThreshold;
  final Category? categoria;
  final String? imagen;
  final DiscountSummary? activeDiscount;

  double get precio => double.tryParse(precioRaw) ?? 0.0;

  double get effectivePrice {
    if (activeDiscount == null || !activeDiscount!.estaActivo) {
      return precio;
    }
    return double.tryParse(activeDiscount!.precioConDescuento) ?? precio;
  }
}

class ProductPayload {
  ProductPayload({
    required this.nombre,
    required this.precio,
    required this.stock,
    this.descripcion,
    this.lowStockThreshold,
    this.categoriaId,
    this.imagen,
  });

  final String nombre;
  final String precio;
  final int stock;
  final String? descripcion;
  final int? lowStockThreshold;
  final int? categoriaId;
  final String? imagen;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'precio': precio,
        'stock': stock,
        if (descripcion != null) 'descripcion': descripcion,
        if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
        if (categoriaId != null) 'categoria_id': categoriaId,
        if (imagen != null) 'imagen': imagen,
      };
}

class ProductDiscount {
  const ProductDiscount({
    required this.id,
    required this.porcentaje,
    required this.fechaInicio,
    this.fechaFin,
    required this.precioOriginal,
    required this.precioConDescuento,
    required this.estaActivo,
    required this.producto,
  });

  factory ProductDiscount.fromJson(Map<String, dynamic> json) => ProductDiscount(
        id: json['id'] as int,
        porcentaje: json['porcentaje'].toString(),
        fechaInicio: json['fecha_inicio'] as String,
        fechaFin: json['fecha_fin'] as String?,
        precioOriginal: json['precio_original'].toString(),
        precioConDescuento: json['precio_con_descuento'].toString(),
        estaActivo: json['esta_activo'] as bool? ?? false,
        producto: Product.fromJson(json['producto'] as Map<String, dynamic>),
      );

  final int id;
  final String porcentaje;
  final String fechaInicio;
  final String? fechaFin;
  final String precioOriginal;
  final String precioConDescuento;
  final bool estaActivo;
  final Product producto;
}

class DiscountPayload {
  DiscountPayload({
    required this.porcentaje,
    required this.fechaInicio,
    this.fechaFin,
    this.productoId,
  });

  final double porcentaje;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final int? productoId;

  Map<String, dynamic> toJson() => {
        'porcentaje': porcentaje,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin?.toIso8601String(),
        if (productoId != null) 'producto_id': productoId,
      };
}

class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    this.rol,
    this.rolNombre,
    this.permisos = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        email: json['email'] as String? ?? '',
        rol: json['rol'] as int?,
        rolNombre: json['rol_nombre'] as String?,
        permisos: (json['permisos'] as List<dynamic>? ?? []).cast<String>(),
      );

  final int id;
  final String username;
  final String email;
  final int? rol;
  final String? rolNombre;
  final List<String> permisos;

  bool get isAdmin => (rolNombre ?? '').toLowerCase() == 'administrador';
}

class Role {
  const Role({required this.id, required this.nombre});

  factory Role.fromJson(Map<String, dynamic> json) =>
      Role(id: json['id'] as int, nombre: json['nombre'] as String);

  final int id;
  final String nombre;
}

class Invoice {
  const Invoice({
    required this.id,
    this.usuario,
    required this.stripeInvoiceId,
    required this.stripeSessionId,
    required this.amountTotal,
    required this.currency,
    required this.status,
    this.hostedInvoiceUrl,
    required this.createdAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as int,
        usuario: json['usuario'] as int?,
        stripeInvoiceId: json['stripe_invoice_id'] as String,
        stripeSessionId: json['stripe_session_id'] as String,
        amountTotal: double.tryParse(json['amount_total'].toString()) ?? 0.0,
        currency: json['currency'] as String? ?? 'USD',
        status: json['status'] as String? ?? 'pending',
        hostedInvoiceUrl: json['hosted_invoice_url'] as String?,
        createdAt: json['created_at'] as String,
      );

  final int id;
  final int? usuario;
  final String stripeInvoiceId;
  final String stripeSessionId;
  final double amountTotal;
  final String currency;
  final String status;
  final String? hostedInvoiceUrl;
  final String createdAt;
}

class ReportSummaryRow {
  const ReportSummaryRow({
    required this.label,
    required this.montoTotal,
    required this.cantidad,
  });

  factory ReportSummaryRow.fromJson(Map<String, dynamic> json) => ReportSummaryRow(
        label: json['label'] as String,
        montoTotal: (json['monto_total'] as num).toDouble(),
        cantidad: json['cantidad'] as int? ?? 0,
      );

  final String label;
  final double montoTotal;
  final int cantidad;
}

class ReportRow {
  const ReportRow({
    required this.factura,
    required this.cliente,
    required this.producto,
    required this.cantidad,
    required this.montoTotal,
    required this.fecha,
  });

  factory ReportRow.fromJson(Map<String, dynamic> json) => ReportRow(
        factura: json['factura'] as String,
        cliente: json['cliente'] as String,
        producto: json['producto'] as String,
        cantidad: json['cantidad'] as int? ?? 0,
        montoTotal: (json['monto_total'] as num).toDouble(),
        fecha: json['fecha'] as String,
      );

  final String factura;
  final String cliente;
  final String producto;
  final int cantidad;
  final double montoTotal;
  final String fecha;
}

class ReportMetadata {
  const ReportMetadata({
    required this.groupBy,
    this.startDate,
    this.endDate,
    required this.format,
    required this.prompt,
  });

  factory ReportMetadata.fromJson(Map<String, dynamic> json) => ReportMetadata(
        groupBy: json['metadata']['group_by'] as String,
        startDate: json['metadata']['start_date'] as String?,
        endDate: json['metadata']['end_date'] as String?,
        format: json['metadata']['format'] as String,
        prompt: json['metadata']['prompt'] as String,
      );

  final String groupBy;
  final String? startDate;
  final String? endDate;
  final String format;
  final String prompt;
}

class ReportScreenResponse {
  const ReportScreenResponse({
    required this.metadata,
    required this.summary,
    required this.rows,
  });

  factory ReportScreenResponse.fromJson(Map<String, dynamic> json) => ReportScreenResponse(
        metadata: ReportMetadata(
          groupBy: json['metadata']['group_by'] as String,
          startDate: json['metadata']['start_date'] as String?,
          endDate: json['metadata']['end_date'] as String?,
          format: json['metadata']['format'] as String,
          prompt: json['metadata']['prompt'] as String,
        ),
        summary: (json['summary'] as List<dynamic>)
            .map((item) => ReportSummaryRow.fromJson(item as Map<String, dynamic>))
            .toList(),
        rows: (json['rows'] as List<dynamic>)
            .map((item) => ReportRow.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final ReportMetadata metadata;
  final List<ReportSummaryRow> summary;
  final List<ReportRow> rows;
}

class SalesPoint {
  const SalesPoint({required this.label, required this.total});

  factory SalesPoint.fromJson(Map<String, dynamic> json) => SalesPoint(
        label: json['label'] as String,
        total: (json['total'] as num).toDouble(),
      );

  final String label;
  final double total;
}

class SalesHistoryResponse {
  const SalesHistoryResponse({
    required this.monthlyTotals,
    required this.byProduct,
    required this.byCustomer,
    required this.byCategory,
  });

  factory SalesHistoryResponse.fromJson(Map<String, dynamic> json) => SalesHistoryResponse(
        monthlyTotals: (json['monthly_totals'] as List<dynamic>)
            .map((item) => SalesPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
        byProduct: (json['by_product'] as List<dynamic>)
            .map((item) => SalesPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
        byCustomer: (json['by_customer'] as List<dynamic>)
            .map((item) => SalesPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
        byCategory: (json['by_category'] as List<dynamic>)
            .map((item) => SalesPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final List<SalesPoint> monthlyTotals;
  final List<SalesPoint> byProduct;
  final List<SalesPoint> byCustomer;
  final List<SalesPoint> byCategory;
}

class CategoryForecast {
  const CategoryForecast({
    required this.category,
    required this.share,
    required this.historical,
    required this.predictions,
  });

  factory CategoryForecast.fromJson(Map<String, dynamic> json) => CategoryForecast(
        category: json['category'] as String,
        share: (json['share'] as num).toDouble(),
        historical: (json['historical'] as List<dynamic>)
            .map((item) => SalesPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
        predictions: (json['predictions'] as List<dynamic>)
            .map((item) => SalesPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final String category;
  final double share;
  final List<SalesPoint> historical;
  final List<SalesPoint> predictions;
}

class SalesPredictionsResponse {
  const SalesPredictionsResponse({
    required this.predictions,
    required this.byCategory,
    required this.metadata,
  });

  factory SalesPredictionsResponse.fromJson(Map<String, dynamic> json) =>
      SalesPredictionsResponse(
        predictions: (json['predictions'] as List<dynamic>)
            .map((item) => SalesPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
        byCategory: (json['by_category'] as List<dynamic>)
            .map((item) => CategoryForecast.fromJson(item as Map<String, dynamic>))
            .toList(),
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      );

  final List<SalesPoint> predictions;
  final List<CategoryForecast> byCategory;
  final Map<String, dynamic> metadata;
}

class CartItem {
  CartItem({required this.product, this.quantity = 1});

  final Product product;
  int quantity;

  double get subtotal => product.effectivePrice * quantity;

  Map<String, dynamic> toJson() => {
        'product': {
          'id': product.id,
          'nombre': product.nombre,
          'descripcion': product.descripcion,
          'precio': product.precioRaw,
          'stock': product.stock,
          'low_stock_threshold': product.lowStockThreshold,
          'categoria': product.categoria == null
              ? null
              : {
                  'id': product.categoria!.id,
                  'nombre': product.categoria!.nombre,
                  'descripcion': product.categoria!.descripcion,
                },
          'imagen': product.imagen,
          'active_discount': product.activeDiscount == null
              ? null
              : {
                  'id': product.activeDiscount!.id,
                  'porcentaje': product.activeDiscount!.porcentaje,
                  'fecha_inicio': product.activeDiscount!.fechaInicio,
                  'fecha_fin': product.activeDiscount!.fechaFin,
                  'precio_original': product.activeDiscount!.precioOriginal,
                  'precio_con_descuento': product.activeDiscount!.precioConDescuento,
                  'esta_activo': product.activeDiscount!.estaActivo,
                },
        },
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        quantity: json['quantity'] as int? ?? 1,
      );
}

class CheckoutItemPayload {
  CheckoutItemPayload({required this.productId, required this.quantity});

  final int productId;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
      };
}

class CheckoutPayload {
  CheckoutPayload({
    required this.usuarioId,
    required this.items,
    required this.successUrl,
    required this.cancelUrl,
  });

  final int usuarioId;
  final List<CheckoutItemPayload> items;
  final String successUrl;
  final String cancelUrl;

  Map<String, dynamic> toJson() => {
        'usuarioId': usuarioId,
        'items': items.map((item) => item.toJson()).toList(),
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
      };
}

class CheckoutSessionResponse {
  const CheckoutSessionResponse({required this.url});

  factory CheckoutSessionResponse.fromJson(Map<String, dynamic> json) =>
      CheckoutSessionResponse(url: json['url'] as String);

  final String url;
}

class ReportPromptPayload {
  ReportPromptPayload({
    required this.prompt,
    this.format = ReportFormat.screen,
    this.channel = ReportChannel.texto,
  });

  final String prompt;
  final ReportFormat format;
  final ReportChannel channel;

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'format': format.name,
        'channel': channel.name,
      };
}

enum ReportFormat { screen, pdf, excel }

enum ReportChannel { texto, voz }

class AuthResponse {
  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String token;
  final User user;
}

class LoginPayload {
  const LoginPayload({required this.username, required this.password});

  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

class RegisterPayload {
  const RegisterPayload({
    required this.username,
    required this.email,
    required this.password,
  });

  final String username;
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
      };
}

class AdminUserPayload {
  AdminUserPayload({
    this.username,
    this.email,
    this.password,
    this.rol,
  });

  final String? username;
  final String? email;
  final String? password;
  final int? rol;

  Map<String, dynamic> toJson() => {
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        if (rol != null) 'rol': rol,
      };
}

class FileDownload {
  const FileDownload({required this.bytes, required this.filename, required this.mimeType});

  final List<int> bytes;
  final String filename;
  final String mimeType;

  @override
  String toString() => 'FileDownload(filename: $filename, bytes: ${bytes.length})';
}

String encodeBasicAuth(String username, String password) {
  final raw = utf8.encode('$username:$password');
  return base64Encode(raw);
}
