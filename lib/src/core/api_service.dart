import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiService {
  ApiService._internal({http.Client? client})
    : _client = client ?? http.Client();

  static final ApiService instance = ApiService._internal();

  final http.Client _client;
  String? _token;

  static final String _baseUrl = _resolveBaseUrl();

  void attachAuthToken(String? token) {
    _token = token;
  }

  //valor por default para el desplegado
  //https://backendp2-production.up.railway.app/api
  static String _resolveBaseUrl() {
    final envUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://10.0.2.2:8000/api/',
    );
    if (kIsWeb) return envUrl;
    if (Platform.isAndroid && envUrl.contains('127.0.0.1')) {
      return envUrl.replaceFirst('127.0.0.1', '10.0.2.2');
    }
    return envUrl;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(
      _baseUrl,
    ).resolve(normalized).replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw ApiException(_parseError(response));
  }

  String _parseError(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // ignore decode failure
    }
    return 'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Operacion fallida'}';
  }

  Future<List<Product>> fetchProducts() async {
    final response = await _client.get(_uri('productos/'), headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Category>> fetchCategories() async {
    final response = await _client.get(
      _uri('categorias/'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductDiscount>> fetchActiveDiscounts() async {
    final response = await _client.get(
      _uri('descuentos/activos/'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => ProductDiscount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductDiscount>> fetchDiscounts({bool? activos}) async {
    final response = await _client.get(
      _uri('descuentos/', activos == true ? {'activos': 'true'} : null),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => ProductDiscount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Product> updateProduct(int id, ProductPayload payload) async {
    final response = await _client.patch(
      _uri('productos/$id/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return Product.fromJson(data);
  }

  Future<void> deleteProduct(int id) async {
    final response = await _client.delete(
      _uri('productos/$id/'),
      headers: _headers(),
    );
    if (response.statusCode >= 400) throw ApiException(_parseError(response));
  }

  Future<List<Product>> fetchLowStockProducts() async {
    final response = await _client.get(
      _uri('productos/low-stock/'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<User>> fetchUsers() async {
    final response = await _client.get(_uri('usuario/'), headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Role>> fetchRoles() async {
    final response = await _client.get(_uri('rol/'), headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => Role.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<User> adminUpdateUser(int id, AdminUserPayload payload) async {
    final response = await _client.patch(
      _uri('usuario/$id/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<void> adminDeleteUser(int id) async {
    final response = await _client.delete(
      _uri('usuario/$id/'),
      headers: _headers(),
    );
    if (response.statusCode >= 400) throw ApiException(_parseError(response));
  }

  Future<List<ProductDiscount>> createDiscounts(DiscountPayload payload) async {
    final response = await _client.post(
      _uri('descuentos/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response);
    if (data is Map<String, dynamic> && data['creados'] != null) {
      final created = data['creados'] as List<dynamic>;
      return created
          .map((item) => ProductDiscount.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (data is Map<String, dynamic>) {
      return [ProductDiscount.fromJson(data)];
    }
    return const [];
  }

  Future<ProductDiscount> updateDiscount(
    int id,
    DiscountPayload payload,
  ) async {
    final response = await _client.patch(
      _uri('descuentos/$id/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return ProductDiscount.fromJson(data);
  }

  Future<void> deleteDiscount(int id) async {
    final response = await _client.delete(
      _uri('descuentos/$id/'),
      headers: _headers(),
    );
    if (response.statusCode >= 400) throw ApiException(_parseError(response));
  }

  Future<List<ProductDiscount>> fetchConfiguredDiscounts() => fetchDiscounts();

  Future<List<ProductDiscount>> fetchActiveDiscountProducts() async {
    final discounts = await fetchActiveDiscounts();
    return discounts;
  }

  Future<List<Invoice>> fetchInvoices({int? userId}) async {
    final response = await _client.get(
      _uri('pagos/facturas/', userId != null ? {'usuario': '$userId'} : null),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data
        .map((item) => Invoice.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Invoice>> fetchAllInvoices() => fetchInvoices();

  Future<CheckoutSessionResponse> createCheckoutSession(
    CheckoutPayload payload,
  ) async {
    final response = await _client.post(
      _uri('pagos/checkout/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return CheckoutSessionResponse.fromJson(data);
  }

  Future<SalesHistoryResponse> fetchSalesHistory() async {
    final response = await _client.get(
      _uri('analitica/ventas/historicas/'),
      headers: _headers(),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return SalesHistoryResponse.fromJson(data);
  }

  Future<SalesPredictionsResponse> fetchSalesPredictions() async {
    final response = await _client.get(
      _uri('analitica/ventas/predicciones/'),
      headers: _headers(),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return SalesPredictionsResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> retrainSalesModel() async {
    final response = await _client.post(
      _uri('analitica/modelo/entrenar/'),
      headers: _headers(),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return data;
  }

  Future<ReportScreenResponse> generateReportScreen(
    ReportPromptPayload payload,
  ) async {
    final response = await _client.post(
      _uri('analitica/reportes/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return ReportScreenResponse.fromJson(data);
  }

  Future<FileDownload> generateReportFile(ReportPromptPayload payload) async {
    final response = await _client.post(
      _uri('analitica/reportes/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final disposition = response.headers['content-disposition'] ?? '';
      final filenameMatch = RegExp(
        r'filename="?([^";]+)"?',
      ).firstMatch(disposition)?.group(1);
      final contentType =
          response.headers['content-type'] ?? 'application/octet-stream';
      return FileDownload(
        bytes: response.bodyBytes,
        filename: filenameMatch ?? 'reporte.${payload.format.name}',
        mimeType: contentType,
      );
    }
    throw ApiException(_parseError(response));
  }

  Future<AuthResponse> login(LoginPayload payload) async {
    final response = await _client.post(
      _uri('auth/login/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return AuthResponse.fromJson(data);
  }

  Future<User> register(RegisterPayload payload) async {
    final response = await _client.post(
      _uri('usuario/'),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<User> me() async {
    final response = await _client.get(_uri('auth/me/'), headers: _headers());
    final data = _decode(response) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<void> logout() async {
    final response = await _client.post(
      _uri('auth/logout/'),
      headers: _headers(),
    );
    if (response.statusCode >= 400) throw ApiException(_parseError(response));
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException($message)';
}
