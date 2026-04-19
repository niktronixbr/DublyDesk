class ScheduleModel {
  final int id;
  final String projeto;
  final String produtora;
  final String? diretor;
  final DateTime data;
  final String horaInicio;
  final String horaFim;
  final double valorHora;
  final double valorTotal;
  final bool realizado;
  final String? observacao;
  final Map<String, bool> lembretes;
  final DateTime createdAt;

  static const defaultLembretes = {
    '60min': false,
    '30min': true,
    '5min': true,
    'exato': true,
  };

  const ScheduleModel({
    required this.id,
    required this.projeto,
    required this.produtora,
    this.diretor,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.valorHora,
    required this.valorTotal,
    required this.realizado,
    this.observacao,
    this.lembretes = defaultLembretes,
    required this.createdAt,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    Map<String, bool> lembretes = Map<String, bool>.from(defaultLembretes);
    if (json['lembretes'] is Map) {
      final raw = json['lembretes'] as Map;
      lembretes = {
        '60min': raw['60min'] == true,
        '30min': raw['30min'] != false,
        '5min': raw['5min'] != false,
        'exato': raw['exato'] != false,
      };
    }

    return ScheduleModel(
      id: (json['id'] as num).toInt(),
      projeto: json['projeto']?.toString() ?? '',
      produtora: json['produtora']?.toString() ?? '',
      diretor: json['diretor']?.toString(),
      data: DateTime.parse(json['data'].toString()),
      horaInicio: json['hora_inicio']?.toString() ?? '',
      horaFim: json['hora_fim']?.toString() ?? '',
      valorHora: double.tryParse(json['valor_hora'].toString()) ?? 0,
      valorTotal: double.tryParse(json['valor_total'].toString()) ?? 0,
      realizado: json['realizado'] == true,
      observacao: json['observacao']?.toString(),
      lembretes: lembretes,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'projeto': projeto,
        'produtora': produtora,
        'diretor': diretor,
        'data': data.toIso8601String(),
        'hora_inicio': horaInicio,
        'hora_fim': horaFim,
        'valor_hora': valorHora,
        'valor_total': valorTotal,
        'realizado': realizado,
        'observacao': observacao,
        'lembretes': lembretes,
      };

  ScheduleModel copyWith({bool? realizado}) => ScheduleModel(
        id: id,
        projeto: projeto,
        produtora: produtora,
        diretor: diretor,
        data: data,
        horaInicio: horaInicio,
        horaFim: horaFim,
        valorHora: valorHora,
        valorTotal: valorTotal,
        realizado: realizado ?? this.realizado,
        observacao: observacao,
        lembretes: lembretes,
        createdAt: createdAt,
      );
}
