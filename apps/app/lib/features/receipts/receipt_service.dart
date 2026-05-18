import '../../core/services/api_service.dart';

class ReceiptGenerateResult {
  final bool success;
  final int? receiptId;
  final String? pdfPath;
  final String? errorMessage;
  final bool proRequired;

  const ReceiptGenerateResult({
    required this.success,
    this.receiptId,
    this.pdfPath,
    this.errorMessage,
    this.proRequired = false,
  });
}

class PendingPayment {
  final int scheduleId;
  final String projeto;
  final String produtora;
  final String? diretor;
  final DateTime data;
  final double valorTotal;
  final double valorPago;
  final String statusPagamento;
  final DateTime? vencimento;

  const PendingPayment({
    required this.scheduleId,
    required this.projeto,
    required this.produtora,
    required this.diretor,
    required this.data,
    required this.valorTotal,
    required this.valorPago,
    required this.statusPagamento,
    required this.vencimento,
  });

  factory PendingPayment.fromJson(Map<String, dynamic> json) => PendingPayment(
        scheduleId: (json['id'] as num).toInt(),
        projeto: json['projeto']?.toString() ?? '',
        produtora: json['produtora']?.toString() ?? '',
        diretor: json['diretor']?.toString(),
        data: DateTime.parse(json['data'].toString()),
        valorTotal: double.tryParse(json['valor_total'].toString()) ?? 0,
        valorPago: double.tryParse(json['valor_pago'].toString()) ?? 0,
        statusPagamento: json['status_pagamento']?.toString() ?? 'pendente',
        vencimento: json['vencimento'] != null
            ? DateTime.tryParse(json['vencimento'].toString())
            : null,
      );

  double get valorRestante => valorTotal - valorPago;
}

class ReceiptService {
  static Future<ReceiptGenerateResult> generate({
    required int scheduleId,
    String? cpf,
  }) async {
    final response = await ApiService.post('/receipts/generate', {
      'scheduleId': scheduleId,
      if (cpf != null && cpf.isNotEmpty) 'cpf': cpf,
    });
    return parseGenerateResponse(response);
  }

  static ReceiptGenerateResult parseGenerateResponse(
      Map<String, dynamic> response) {
    if (response['success'] == true && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      return ReceiptGenerateResult(
        success: true,
        receiptId: (data['id'] as num?)?.toInt(),
        pdfPath: data['pdfPath']?.toString(),
      );
    }
    final proRequired = response['statusCode'] == 402 ||
        (response['data'] is Map &&
            (response['data'] as Map)['code'] == 'PRO_REQUIRED');
    return ReceiptGenerateResult(
      success: false,
      errorMessage: response['error']?.toString() ?? 'Erro desconhecido',
      proRequired: proRequired,
    );
  }

  static Future<bool> sendEmail({
    required int receiptId,
    required String destinatario,
    String? mensagem,
  }) async {
    final response = await ApiService.post('/receipts/$receiptId/send-email', {
      'destinatario': destinatario,
      if (mensagem != null && mensagem.isNotEmpty) 'mensagem': mensagem,
    });
    return response['success'] == true;
  }

  static Future<({List<PendingPayment> items, double total})>
      listPending() async {
    final response = await ApiService.get('/receipts/pending');
    if (response['success'] == true && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      final rawItems = (data['items'] as List?) ?? [];
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(PendingPayment.fromJson)
          .toList();
      final total =
          double.tryParse(data['totalPendente'].toString()) ?? 0;
      return (items: items, total: total);
    }
    return (items: <PendingPayment>[], total: 0.0);
  }

  static Future<bool> updatePaymentStatus({
    required int scheduleId,
    required String statusPagamento,
    double? valorPago,
    DateTime? vencimento,
  }) async {
    final response =
        await ApiService.patch('/schedules/$scheduleId/payment', {
      'status_pagamento': statusPagamento,
      'valor_pago': ?valorPago,
      'vencimento': ?vencimento?.toIso8601String().split('T').first,
    });
    return response['success'] == true;
  }
}
