import 'package:flutter/material.dart';
import '../services/app_config_service.dart';

class TermsView extends StatelessWidget {
  const TermsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<AppConfig>(
        stream: AppConfigService.instance.watchConfig(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final config = snapshot.data!;
          if (config.termsAndConditions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Terms & Conditions are currently unavailable. Please try again later.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (config.termsLastUpdated.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Last updated: ${config.termsLastUpdated}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Text(
                  config.termsAndConditions,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
