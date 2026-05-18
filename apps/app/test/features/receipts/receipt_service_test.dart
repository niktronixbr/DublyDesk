import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/receipts/receipt_service.dart';

void main() {
  group('ReceiptService.parseGenerateResponse', () {
    test('parses successful generate response', () {
      final r = ReceiptService.parseGenerateResponse({
        'success': true,
        'data': {
          'id': 42,
          'pdfPath': 'uploads/receipts/1/42-abc.pdf',
          'createdAt': '2026-05-18T10:00:00.000Z',
        },
      });
      expect(r.success, true);
      expect(r.receiptId, 42);
      expect(r.pdfPath, 'uploads/receipts/1/42-abc.pdf');
    });

    test('returns PRO_REQUIRED error from 402 response', () {
      final r = ReceiptService.parseGenerateResponse({
        'success': false,
        'statusCode': 402,
        'data': {'error': 'Recurso disponível apenas no Pro', 'code': 'PRO_REQUIRED'},
        'error': 'Recurso disponível apenas no Pro',
      });
      expect(r.success, false);
      expect(r.proRequired, true);
    });

    test('parses generic error', () {
      final r = ReceiptService.parseGenerateResponse({
        'success': false,
        'statusCode': 500,
        'error': 'Erro ao gerar recibo',
      });
      expect(r.success, false);
      expect(r.proRequired, false);
      expect(r.errorMessage, 'Erro ao gerar recibo');
    });
  });
}
