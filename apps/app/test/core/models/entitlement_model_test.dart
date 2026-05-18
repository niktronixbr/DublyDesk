import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/entitlement_model.dart';

void main() {
  group('EntitlementModel.fromJson', () {
    test('parses Free user (pro=false)', () {
      final m = EntitlementModel.fromJson({
        'pro': false,
        'trial': false,
        'until': null,
        'source': null,
        'cancelAtPeriodEnd': false,
      });
      expect(m.pro, false);
      expect(m.trial, false);
      expect(m.until, isNull);
      expect(m.source, isNull);
      expect(m.cancelAtPeriodEnd, false);
    });

    test('parses Pro active stripe user', () {
      final m = EntitlementModel.fromJson({
        'pro': true,
        'trial': false,
        'until': '2026-06-18T00:00:00.000Z',
        'source': 'stripe',
        'cancelAtPeriodEnd': false,
      });
      expect(m.pro, true);
      expect(m.trial, false);
      expect(m.until, DateTime.parse('2026-06-18T00:00:00.000Z'));
      expect(m.source, 'stripe');
    });

    test('parses Pro trial play user', () {
      final m = EntitlementModel.fromJson({
        'pro': true,
        'trial': true,
        'until': '2026-05-25T00:00:00.000Z',
        'source': 'play',
        'cancelAtPeriodEnd': true,
      });
      expect(m.pro, true);
      expect(m.trial, true);
      expect(m.cancelAtPeriodEnd, true);
      expect(m.source, 'play');
    });

    test('daysUntilExpiry returns correct count for future date', () {
      final future = DateTime.now().add(const Duration(days: 7));
      final m = EntitlementModel(
        pro: true,
        trial: true,
        until: future,
        source: 'stripe',
        cancelAtPeriodEnd: false,
      );
      expect(m.daysUntilExpiry, inInclusiveRange(6, 7));
    });

    test('daysUntilExpiry returns null when until is null', () {
      const m = EntitlementModel.free();
      expect(m.daysUntilExpiry, isNull);
    });
  });
}
