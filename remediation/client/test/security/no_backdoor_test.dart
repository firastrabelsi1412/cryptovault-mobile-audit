// test/security/no_backdoor_test.dart
// ✅ V10b — Garde-fou CI : échoue si une backdoor ou un secret réapparaît
//           un jour dans lib/. À lancer avec `flutter test`.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aucune backdoor ni secret en dur dans lib/', () {
    final forbidden = <String>[
      'dev@cryptovault.local',
      'Override_2026',
      'FAKE_SIG_DEV_MASTER',
      'devMasterToken',
      'cryptovault_jwt_s3cr3t',
      'cb-live-',
      'ETSC-K8Z2QF7YH9X3P1M5VN6J4WL0RT8DBC',
      'CryptoVault_AES_Seed_Key',
      'badCertificateCallback',
      'BurpProxyOverride',
    ];
    final files =
        Directory('lib').listSync(recursive: true).whereType<File>().where(
              (f) => f.path.endsWith('.dart'),
            );
    final hits = <String>[];
    for (final f in files) {
      final body = f.readAsStringSync();
      for (final marker in forbidden) {
        if (body.contains(marker)) hits.add('${f.path} contient "$marker"');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
