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
  final DateTime createdAt;

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
    required this.createdAt,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
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
        createdAt: createdAt,
      );
}
