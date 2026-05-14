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
  final bool remunerado;
  final String tipo;
  final String? observacao;
  final String? tipoTrabalho;
  final String? contatoNome;
  final String? contatoTelefone;
  final Map<String, bool> lembretes;
  final DateTime createdAt;

  bool get isCompromisso => tipo == 'compromisso';

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
    this.remunerado = true,
    this.tipo = 'trabalho',
    this.observacao,
    this.tipoTrabalho,
    this.contatoNome,
    this.contatoTelefone,
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

    final rawData = json['data'];
    final DateTime parsedData;
    try {
      parsedData = DateTime.parse(rawData.toString());
    } catch (e) {
      throw FormatException(
          'ScheduleModel.fromJson: data inválida em id=${json['id']} '
          '(valor: ${rawData.runtimeType}=$rawData) — $e');
    }

    return ScheduleModel(
      id: (json['id'] as num).toInt(),
      projeto: json['projeto']?.toString() ?? '',
      produtora: json['produtora']?.toString() ?? '',
      diretor: json['diretor']?.toString(),
      data: parsedData,
      horaInicio: json['hora_inicio']?.toString() ?? '',
      horaFim: json['hora_fim']?.toString() ?? '',
      valorHora: double.tryParse(json['valor_hora'].toString()) ?? 0,
      valorTotal: double.tryParse(json['valor_total'].toString()) ?? 0,
      realizado: json['realizado'] == true,
      remunerado: json['remunerado'] != false,
      tipo: json['tipo']?.toString() ?? 'trabalho',
      observacao: json['observacao']?.toString(),
      tipoTrabalho: json['tipo_trabalho']?.toString(),
      contatoNome: json['contato_nome']?.toString(),
      contatoTelefone: json['contato_telefone']?.toString(),
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
        'remunerado': remunerado,
        'tipo': tipo,
        'observacao': observacao,
        'tipo_trabalho': tipoTrabalho,
        'contato_nome': contatoNome,
        'contato_telefone': contatoTelefone,
        'lembretes': lembretes,
      };

  ScheduleModel copyWith({bool? realizado, bool? remunerado, String? tipo}) => ScheduleModel(
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
        remunerado: remunerado ?? this.remunerado,
        tipo: tipo ?? this.tipo,
        observacao: observacao,
        tipoTrabalho: tipoTrabalho,
        contatoNome: contatoNome,
        contatoTelefone: contatoTelefone,
        lembretes: lembretes,
        createdAt: createdAt,
      );
}
