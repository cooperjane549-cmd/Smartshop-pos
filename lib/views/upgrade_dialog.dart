import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/billing_service.dart';

class UpgradeDialog {
  static void show(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _UpgradeDialogContent(),
    );
  }
}

class _UpgradeDialogContent extends StatefulWidget {
  const _UpgradeDialogContent();

  @override
  State<_UpgradeDialogContent> createState() => _UpgradeDialogContentState();
}

class _UpgradeDialogContentState extends State<_UpgradeDialogContent> {
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final available = await BillingService.instance.isAvailable();
      if (!available) {
        setState(() {
          _loading = false;
          _error = 'Google Play Billing is not available on this device.';
        });
        return;
      }

      final products = await BillingService.instance.loadProducts();
      setState(() {
        _products = products;
        _loading = false;
        if (products.isEmpty) {
          _error = 'No subscription plans found. Please try again shortly.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load plans: $e';
      });
    }
  }

  Future<void> _buy(ProductDetails product) async {
    setState(() => _purchasing = true);
    try {
      await BillingService.instance.purchase(product);
      // Purchase result arrives asynchronously via the purchase stream
      // (handled in BillingService), so we close this dialog now and let
      // the Dashboard's subscription listener reflect the update once it
      // lands.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  String _labelFor(String productId) {
    switch (productId) {
      case 'smartshop_pro_1m':
        return '1 Month';
      case 'smartshop_pro_3m':
        return '3 Months';
      case 'smartshop_pro_6m':
        return '6 Months';
      case 'smartshop_pro_12m':
        return '12 Months';
      default:
        return productId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Text('Upgrade SmartShop POS'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose a plan — payment is handled securely through Google Play.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      ..._products.map((product) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(_labelFor(product.id)),
                            subtitle: Text(product.price),
                            trailing: _purchasing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _buy(product),
                                    child: const Text('Buy'),
                                  ),
                          ),
                        );
                      }),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _purchasing ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
