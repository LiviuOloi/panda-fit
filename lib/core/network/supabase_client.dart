import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client configuration and singleton accessor
class SupabaseService {
  SupabaseService._();

  static const String defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder-project.supabase.co',
  );

  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
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
