import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sale_transaction.dart';

class RenderSyncService {
  // Replace with your actual Render deployment URL
  static const String _baseUrl = 'https://your-smartshop-api.onrender.com/api';

  static Future<bool> syncSaleToRender(SaleTransaction sale) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sync-sale'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(sale.toMap()),
      );

      if (response.statusCode == 200) {
        debugPrint('Sale ${sale.id} synced to Render successfully.');
        return true;
      } else {
        debugPrint('Render Sync Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Network error during Render sync: $e');
      return false;
    }
  }
}
