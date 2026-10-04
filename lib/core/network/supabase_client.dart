import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client configuration and singleton accessor
class SupabaseService {
  SupabaseService._();

  static const String defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://grmgmxesbyrkbmustwfd.supabase.co',
  );

  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_EixbwCeC7SaY1mUSAlZ1DA_8dXK3WkG',
  );

  static Future<void> initialize({String? url, String? anonKey}) async {
    final finalUrl = url ?? defaultUrl;
    final finalAnonKey = anonKey ?? defaultAnonKey;

    if (finalUrl.contains('placeholder')) {
      // In offline/mock mode if keys not yet configured
      return;
    }

    await Supabase.initialize(
      url: finalUrl,
      // ignore: deprecated_member_use
      anonKey: finalAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isInitialized => client != null;
}
