import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProfileService {
  static Future<Map<String, dynamic>?> getProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();

    await supabase.from('profiles').update(updates).eq('id', userId);
  }
}
