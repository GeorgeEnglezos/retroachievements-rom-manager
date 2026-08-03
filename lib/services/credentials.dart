import 'package:shared_preferences/shared_preferences.dart';
import 'metadata/metadata_provider.dart';
import 'pref_keys.dart';
import 'secret_store.dart';

/// The RA Web API key, or '' when unset.
///
/// Versions before secure storage kept the key as a plaintext pref. The first
/// read after upgrading moves it into [SecretStore] and clears the pref.
/// Migrating lazily here rather than at startup means there is no
/// initialization order to get wrong, and a user who skips a release still
/// migrates on their next launch.
Future<String> readApiKey() async {
  final stored = await SecretStore.read(PrefKeys.raApiKey);
  if (stored != null && stored.isNotEmpty) return stored;

  final prefs = await SharedPreferences.getInstance();
  final legacy = prefs.getString(PrefKeys.raApiKey) ?? '';
  if (legacy.isEmpty) return '';

  // In fallback the store *is* this pref, so writing and then removing would
  // delete the key we just recovered. Nothing to migrate in that case.
  if (SecretStore.usingFallback) return legacy;

  await SecretStore.write(PrefKeys.raApiKey, legacy);
  await prefs.remove(PrefKeys.raApiKey);
  return legacy;
}

/// Persists the key, or clears it when [value] is empty. Empty has always meant
/// "no credentials" to [savedCredentials], so an empty string is never stored.
Future<void> saveApiKey(String value) async {
  if (value.isEmpty) {
    await SecretStore.delete(PrefKeys.raApiKey);
    return;
  }
  await SecretStore.write(PrefKeys.raApiKey, value);
}

/// Saved RA credentials as (username, apiKey), or null when either is missing.
Future<(String, String)?> savedCredentials() async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString(PrefKeys.raUsername) ?? '';
  final apiKey = await readApiKey();
  if (username.isEmpty || apiKey.isEmpty) return null;
  return (username, apiKey);
}

/// The third-party metadata provider for RA-unsupported (display-only) systems.
///
/// Currently always null: RA is the only data source. Every third-party API we
/// evaluated (ScreenScraper, IGDB, RAWG, Wikidata) was unworkable for an
/// open-source, backend-less, user-facing app. The [MetadataProvider] interface
/// and the fetch pipeline are kept intact, so a viable provider only needs
/// building here; no other wiring changes.
Future<MetadataProvider?> savedMetadataProvider() async => null;
