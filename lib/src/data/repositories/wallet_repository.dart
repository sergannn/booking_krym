import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';
import '../models/wallet.dart';

class WalletRepository {
  WalletRepository(this._client);

  final ApiClient _client;

  Future<WalletInfo> fetchWallet(int userId) async {
    final response = await _client.getJson(
      '/api/users/$userId/wallet',
      authenticated: true,
    );
    return WalletInfo.fromJson(response);
  }

  Future<SalesInfo> fetchSales(int userId) async {
    final response = await _client.getJson(
      '/api/users/$userId/sales',
      authenticated: true,
    );
    return SalesInfo.fromJson(response);
  }
}
