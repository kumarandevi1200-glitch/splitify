import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class ApiService extends ChangeNotifier {
  // Production URL hosted on Render
  String _baseUrl = 'https://split-api-0qdn.onrender.com';
  
  String? _accessToken;
  String? _refreshToken;
  String? _email;
  int? _userId;
  String? _name;
  bool _isAuthenticated = false;

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;
  int? get userId => _userId;
  String? get displayName => _name ?? _email;
  String? get name => _name;

  void setBaseUrl(String url) {
    _baseUrl = url;
    notifyListeners();
  }

  ApiService() {
    _loadSession();
  }

  // Load persistence details on initialization
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _email = prefs.getString('email');
    _userId = prefs.getInt('user_id');
    _name = prefs.getString('name');
    _isAuthenticated = _accessToken != null;
    notifyListeners();
  }

  Future<void> _saveSession(String access, String refresh, String email, int userId, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
    await prefs.setString('email', email);
    await prefs.setInt('user_id', userId);
    if (name != null) {
      await prefs.setString('name', name);
    } else {
      await prefs.remove('name');
    }

    _accessToken = access;
    _refreshToken = refresh;
    _email = email;
    _userId = userId;
    _name = name;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('email');
    await prefs.remove('user_id');
    await prefs.remove('name');

    _accessToken = null;
    _refreshToken = null;
    _email = null;
    _userId = null;
    _name = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Map<String, String> _headers({String? idempotencyKey}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  // Handle Token Refresh flow
  Future<bool> _refreshTokenFlow() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(
          data['accessToken'],
          data['refreshToken'],
          data['email'],
          data['userId'],
          name: data['name'],
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Token refresh failed: $e');
    }
    await logout();
    return false;
  }

  // Intercepting request method to automatically handle 401s and token refresh
  Future<http.Response> _authenticatedRequest(
      Future<http.Response> Function() requestFn) async {
    var response = await requestFn();
    
    if (response.statusCode == 401) {
      // Access token might be expired. Try to refresh.
      final refreshed = await _refreshTokenFlow();
      if (refreshed) {
        // Retry request with new token
        response = await requestFn();
      }
    }
    return response;
  }

  // --- AUTH SERVICES ---

  Future<void> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveSession(
        data['accessToken'],
        data['refreshToken'],
        data['email'],
        data['userId'],
        name: data['name'],
      );
    } else {
      _throwError(response);
    }
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveSession(
        data['accessToken'],
        data['refreshToken'],
        data['email'],
        data['userId'],
        name: data['name'],
      );
    } else {
      _throwError(response);
    }
  }

  Future<void> updateProfileName(String newName) async {
    final response = await _authenticatedRequest(() => http.put(
      Uri.parse('$_baseUrl/api/users/profile'),
      headers: _headers(),
      body: jsonEncode({'name': newName}),
    ));

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', newName);
      _name = newName;
      notifyListeners();
    } else {
      _throwError(response);
    }
  }

  // --- GROUP SERVICES ---

  Future<List<Group>> fetchGroups() async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/api/groups'),
      headers: _headers(),
    ));

    if (response.statusCode == 200) {
      var list = jsonDecode(response.body) as List;
      return list.map((g) => Group.fromJson(g)).toList();
    } else {
      _throwError(response);
      return [];
    }
  }

  Future<Group> createGroup(String name, String currency) async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/api/groups'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'currency': currency}),
    ));

    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(response.body));
    } else {
      _throwError(response);
      throw Exception('Create group failed');
    }
  }

  Future<String> generateInviteCode(int groupId, {int? validityHours, int? maxUses}) async {
    String query = '';
    if (validityHours != null || maxUses != null) {
      final params = <String>[];
      if (validityHours != null) params.add('validityHours=$validityHours');
      if (maxUses != null) params.add('maxUses=$maxUses');
      query = '?${params.join('&')}';
    }

    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/api/groups/$groupId/invite-code$query'),
      headers: _headers(),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['code'] as String;
    } else {
      _throwError(response);
      throw Exception('Generate invite code failed');
    }
  }

  Future<Group> joinGroup(String code) async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/api/groups/join'),
      headers: _headers(),
      body: jsonEncode({'code': code}),
    ));

    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(response.body));
    } else {
      _throwError(response);
      throw Exception('Join group failed');
    }
  }

  Future<List<User>> fetchGroupMembers(int groupId) async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/api/groups/$groupId/members'),
      headers: _headers(),
    ));

    if (response.statusCode == 200) {
      var list = jsonDecode(response.body) as List;
      return list.map((m) => User.fromJson(m)).toList();
    } else {
      _throwError(response);
      return [];
    }
  }

  // --- EXPENSE SERVICES ---

  Future<List<Expense>> fetchExpenses(int groupId) async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/api/groups/$groupId/expenses'),
      headers: _headers(),
    ));

    if (response.statusCode == 200) {
      var list = jsonDecode(response.body) as List;
      return list.map((e) => Expense.fromJson(e)).toList();
    } else {
      _throwError(response);
      return [];
    }
  }

  Future<Expense> createExpense(
      int groupId, 
      double amount, 
      int payerId, 
      String description, 
      String splitType, 
      String category, 
      List<Map<String, dynamic>> shares,
      {String? idempotencyKey}) async {
    
    final body = {
      'amount': amount,
      'payerId': payerId,
      'description': description,
      'splitType': splitType,
      'category': category,
      'shares': shares,
    };

    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/api/groups/$groupId/expenses'),
      headers: _headers(idempotencyKey: idempotencyKey),
      body: jsonEncode(body),
    ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Expense.fromJson(jsonDecode(response.body));
    } else {
      _throwError(response);
      throw Exception('Create expense failed');
    }
  }

  Future<Expense> updateExpense(
      int groupId,
      int expenseId,
      double amount,
      int payerId,
      String description,
      String splitType,
      String category,
      List<Map<String, dynamic>> shares) async {

    final body = {
      'amount': amount,
      'payerId': payerId,
      'description': description,
      'splitType': splitType,
      'category': category,
      'shares': shares,
    };

    final response = await _authenticatedRequest(() => http.put(
      Uri.parse('$_baseUrl/api/groups/$groupId/expenses/$expenseId'),
      headers: _headers(),
      body: jsonEncode(body),
    ));

    if (response.statusCode == 200) {
      return Expense.fromJson(jsonDecode(response.body));
    } else {
      _throwError(response);
      throw Exception('Update expense failed');
    }
  }

  Future<void> deleteExpense(int groupId, int expenseId) async {
    final response = await _authenticatedRequest(() => http.delete(
      Uri.parse('$_baseUrl/api/groups/$groupId/expenses/$expenseId'),
      headers: _headers(),
    ));

    if (response.statusCode != 204 && response.statusCode != 200) {
      _throwError(response);
    }
  }

  // --- SETTLEMENT SERVICES ---

  Future<List<Settlement>> fetchSettlements(int groupId) async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/api/groups/$groupId/settlements'),
      headers: _headers(),
    ));

    if (response.statusCode == 200) {
      var list = jsonDecode(response.body) as List;
      return list.map((s) => Settlement.fromJson(s)).toList();
    } else {
      _throwError(response);
      return [];
    }
  }

  Future<Settlement> recordSettlement(
      int groupId, 
      int paidToId, 
      double amount, 
      String? note,
      {String? idempotencyKey}) async {

    final body = {
      'paidToId': paidToId,
      'amount': amount,
      'note': note,
    };

    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/api/groups/$groupId/settlements'),
      headers: _headers(idempotencyKey: idempotencyKey),
      body: jsonEncode(body),
    ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Settlement.fromJson(jsonDecode(response.body));
    } else {
      _throwError(response);
      throw Exception('Record settlement failed');
    }
  }

  // --- REPORT SERVICES ---

  Future<Report> fetchReport(int groupId) async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/api/groups/$groupId/report'),
      headers: _headers(),
    ));

    if (response.statusCode == 200) {
      return Report.fromJson(jsonDecode(response.body));
    } else {
      _throwError(response);
      throw Exception('Fetch report failed');
    }
  }

  // Error Helper to translate API Error DTOs to Custom Dart Exceptions
  void _throwError(http.Response response) {
    try {
      final errorData = jsonDecode(response.body);
      final code = errorData['code'] as String?;
      final message = errorData['message'] as String?;
      throw ApiException(
        code: code ?? 'UNKNOWN_ERROR',
        message: message ?? 'An unexpected error occurred',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: 'HTTP_${response.statusCode}',
        message: 'Request failed with status code ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => '[$code] $message (HTTP $statusCode)';
}
