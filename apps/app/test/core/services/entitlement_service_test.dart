import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/services/entitlement_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EntitlementService.resetForTesting();
  });

  test('current returns free entitlement before any load', () {
    final ent = EntitlementService.current.value;
    expect(ent.pro, false);
  });

  test('updateFromJson updates current and persists', () async {
    await EntitlementService.updateFromJson({
      'pro': true,
      'trial': true,
      'until': '2026-06-01T00:00:00.000Z',
      'source': 'play',
      'cancelAtPeriodEnd': false,
    });

    expect(EntitlementService.current.value.pro, true);
    expect(EntitlementService.current.value.trial, true);
    expect(EntitlementService.current.value.source, 'play');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entitlement_cache'), isNotNull);
  });

  test('loadCached restores from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'entitlement_cache':
          '{"pro":true,"trial":false,"until":"2026-12-01T00:00:00.000Z","source":"stripe","cancelAtPeriodEnd":false}',
    });
    EntitlementService.resetForTesting();
    await EntitlementService.loadCached();
    expect(EntitlementService.current.value.pro, true);
    expect(EntitlementService.current.value.source, 'stripe');
  });

  test('clear resets to free and removes cache', () async {
    await EntitlementService.updateFromJson({
      'pro': true,
      'trial': false,
      'until': '2026-12-01T00:00:00.000Z',
      'source': 'stripe',
      'cancelAtPeriodEnd': false,
    });
    await EntitlementService.clear();
    expect(EntitlementService.current.value.pro, false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entitlement_cache'), isNull);
  });
}
