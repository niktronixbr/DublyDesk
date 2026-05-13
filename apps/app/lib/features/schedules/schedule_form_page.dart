import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../core/models/schedule_model.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../notification_service.dart';

/// Tipos de trabalho mais comuns sugeridos no autocomplete.
const _tiposTrabalhoSugeridos = <String>[
  'Loops',
  'Voz Adicional',
  'Cachet Fixo',
  'Protagonista',
  'Cocô',
  'Reality',
  'Documentário',
  'Locução',
];

const _labelLembretes = {
  '60min': '1 hora antes',
  '30min': '30 minutos antes',
  '5min': '5 minutos antes',
  'exato': 'No horário exato',
};

enum _CalculoModo { horaCheia, proporcional, manual }

class ScheduleFormPage extends StatefulWidget {
  final ScheduleModel? item;
  final List<ScheduleModel> escalasExistentes;
  final DateTime? dataInicial;

  const ScheduleFormPage({
    super.key,
    this.item,
    this.escalasExistentes = const [],
    this.dataInicial,
  });

  @override
  State<ScheduleFormPage> createState() => _ScheduleFormPageState();
}

class _ScheduleFormPageState extends State<ScheduleFormPage> {
  final _projeto = TextEditingController();
  final _produtora = TextEditingController();
  final _diretor = TextEditingController();
  final _tipoTrabalho = TextEditingController();
  final _contatoNome = TextEditingController();
  final _contatoTelefone = TextEditingController();
  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'\d')},
    type: MaskAutoCompletionType.lazy,
  );
  final _valorHora = TextEditingController();
  final _valorTotalManual = TextEditingController();
  final _horaInicio = TextEditingController();
  final _horaFim = TextEditingController();
  final _observacao = TextEditingController();

  _CalculoModo _modoCalculo = _CalculoModo.horaCheia;
  DateTime? _dataSelecionada;
  bool _salvando = false;
  bool _mostrarLembretes = false;

  List<Map<String, dynamic>> _produtorasFull = [];
  List<String> _produtorasNomes = [];
  List<String> _projetosSugeridos = [];
  List<String> _diretoresSugeridos = [];
  Map<String, bool> _lembretes = Map<String, bool>.from(
    ScheduleModel.defaultLembretes,
  );

  @override
  void initState() {
    super.initState();
    _carregarSugestoes();

    if (widget.dataInicial != null && widget.item == null) {
      _dataSelecionada = widget.dataInicial;
    }

    if (widget.item != null) {
      final item = widget.item!;
      _projeto.text = item.projeto;
      _produtora.text = item.produtora;
      _diretor.text = item.diretor ?? '';
      _tipoTrabalho.text = item.tipoTrabalho ?? '';
      _contatoNome.text = item.contatoNome ?? '';
      final rawPhone = item.contatoTelefone ?? '';
      _phoneMask.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: rawPhone),
      );
      _contatoTelefone.text = _phoneMask.getMaskedText();
      _valorHora.text = item.valorHora.toString().replaceAll('.', ',');
      _valorTotalManual.text = item.valorTotal.toString().replaceAll('.', ',');
      _horaInicio.text = item.horaInicio;
      _horaFim.text = item.horaFim;
      _observacao.text = item.observacao ?? '';
      _dataSelecionada = item.data;
      _lembretes = Map<String, bool>.from(item.lembretes);
    }

    _valorHora.addListener(() => setState(() {}));
    _valorTotalManual.addListener(() => setState(() {}));
    _horaInicio.addListener(() => setState(() {}));
    _horaFim.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _projeto.dispose();
    _produtora.dispose();
    _diretor.dispose();
    _tipoTrabalho.dispose();
    _contatoNome.dispose();
    _contatoTelefone.dispose();
    _valorHora.dispose();
    _valorTotalManual.dispose();
    _horaInicio.dispose();
    _horaFim.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _carregarSugestoes() async {
    final results = await Future.wait([
      ApiService.get('/produtoras'),
      ApiService.get('/projetos'),
      ApiService.get('/diretores'),
    ]);

    List<String> nomes(Map<String, dynamic> r) {
      if (r['success'] != true || r['data'] is! List) return [];
      return (r['data'] as List)
          .map((e) => e['nome']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    }

    final produtorasResp = results[0];
    final List<Map<String, dynamic>> produtorasFull =
        (produtorasResp['success'] == true && produtorasResp['data'] is List)
            ? (produtorasResp['data'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : [];

    if (!mounted) return;
    setState(() {
      _produtorasFull = produtorasFull;
      _produtorasNomes = produtorasFull
          .map((e) => e['nome']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      _projetosSugeridos = nomes(results[1]);
      _diretoresSugeridos = nomes(results[2]);
    });
  }

  void _autoPreencherContato(String nomeProdutora) {
    final p = _produtorasFull.firstWhere(
      (e) => (e['nome']?.toString() ?? '') == nomeProdutora,
      orElse: () => <String, dynamic>{},
    );
    final cn = p['contato_nome']?.toString();
    final ct = p['contato_telefone']?.toString();

    // Só preenche se o usuário ainda não digitou nada manualmente.
    setState(() {
      if (_contatoNome.text.trim().isEmpty && cn != null && cn.isNotEmpty) {
        _contatoNome.text = cn;
      }
      if (_contatoTelefone.text.trim().isEmpty &&
          ct != null &&
          ct.isNotEmpty) {
        _phoneMask.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: ct),
        );
        _contatoTelefone.text = _phoneMask.getMaskedText();
      }
    });
  }

  double _parseValor(String valor) {
    if (valor.trim().isEmpty) return 0;
    return double.tryParse(
            valor.replaceAll('.', '').replaceAll(',', '.')) ??
        0;
  }

  double get _valorTotalPreview {
    if (_modoCalculo == _CalculoModo.manual) {
      return _parseValor(_valorTotalManual.text);
    }
    final inicio = _horaInicio.text.split(':');
    final fim = _horaFim.text.split(':');
    if (inicio.length != 2 || fim.length != 2) return 0;
    final hI = int.tryParse(inicio[0]);
    final mI = int.tryParse(inicio[1]);
    final hF = int.tryParse(fim[0]);
    final mF = int.tryParse(fim[1]);
    if (hI == null || mI == null || hF == null || mF == null) return 0;
    final minutos = (hF * 60 + mF) - (hI * 60 + mI);
    if (minutos <= 0) return 0;
    final valorHora = _parseValor(_valorHora.text);
    if (_modoCalculo == _CalculoModo.horaCheia) {
      return (minutos / 60.0).ceil() * valorHora;
    }
    return (minutos / 60.0) * valorHora;
  }

  Future<void> _selecionarHora(TextEditingController controller) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (controller.text.contains(':')) {
      final partes = controller.text.split(':');
      if (partes.length == 2) {
        final h = int.tryParse(partes[0]) ?? initialTime.hour;
        final m = int.tryParse(partes[1]) ?? initialTime.minute;
        initialTime = TimeOfDay(hour: h, minute: m);
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  bool _validarCampos() {
    final valorPreenchido = _modoCalculo == _CalculoModo.manual
        ? _valorTotalManual.text.trim().isNotEmpty
        : _valorHora.text.trim().isNotEmpty;

    if (_produtora.text.trim().isEmpty ||
        _horaInicio.text.trim().isEmpty ||
        _horaFim.text.trim().isEmpty ||
        !valorPreenchido ||
        _dataSelecionada == null) {
      _snack('Preencha todos os campos obrigatórios.');
      return false;
    }
    return true;
  }

  bool _temConflito(DateTime inicio, DateTime fim) {
    for (final escala in widget.escalasExistentes) {
      if (widget.item != null && escala.id == widget.item!.id) continue;
      if (escala.data.year != inicio.year ||
          escala.data.month != inicio.month ||
          escala.data.day != inicio.day) {
        continue;
      }
      final partes = escala.horaInicio.split(':');
      final partesF = escala.horaFim.split(':');
      final eInicio = DateTime(inicio.year, inicio.month, inicio.day,
          int.parse(partes[0]), int.parse(partes[1]));
      final eFim = DateTime(inicio.year, inicio.month, inicio.day,
          int.parse(partesF[0]), int.parse(partesF[1]));
      if (inicio.isBefore(eFim) && eInicio.isBefore(fim)) return true;
    }
    return false;
  }

  Future<void> _garantirFavorito(
    String endpoint,
    List<String> lista,
    String nome, {
    Map<String, dynamic>? extra,
  }) async {
    final n = nome.trim();
    if (n.isEmpty) return;
    if (!lista.contains(n)) {
      await ApiService.post(endpoint, {'nome': n, ...?extra});
    } else if (endpoint == '/produtoras' && extra != null) {
      // Atualiza contato da produtora existente.
      final produtora = _produtorasFull.firstWhere(
        (e) => (e['nome']?.toString() ?? '') == n,
        orElse: () => <String, dynamic>{},
      );
      final id = produtora['id'];
      if (id != null) {
        await ApiService.put('/produtoras/$id', {'nome': n, ...extra});
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _salvar() async {
    if (!_validarCampos()) return;
    setState(() => _salvando = true);

    try {
      final inicio = _horaInicio.text.split(':');
      final fim = _horaFim.text.split(':');
      final inicioDate = DateTime(_dataSelecionada!.year, _dataSelecionada!.month,
          _dataSelecionada!.day, int.parse(inicio[0]), int.parse(inicio[1]));
      final fimDate = DateTime(_dataSelecionada!.year, _dataSelecionada!.month,
          _dataSelecionada!.day, int.parse(fim[0]), int.parse(fim[1]));

      final diferencaMinutos = fimDate.difference(inicioDate).inMinutes;
      if (diferencaMinutos <= 0) {
        _snack('Hora fim deve ser maior que hora início.');
        setState(() => _salvando = false);
        return;
      }

      final double valorHoraDouble;
      final double valorTotal;
      if (_modoCalculo == _CalculoModo.manual) {
        valorTotal = _parseValor(_valorTotalManual.text);
        valorHoraDouble = 0;
      } else {
        valorHoraDouble = _parseValor(_valorHora.text);
        if (_modoCalculo == _CalculoModo.horaCheia) {
          valorTotal = (diferencaMinutos / 60.0).ceil() * valorHoraDouble;
        } else {
          valorTotal = (diferencaMinutos / 60.0) * valorHoraDouble;
        }
      }

      if (_temConflito(inicioDate, fimDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Período indisponível! Já existe uma escala nesse horário.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _salvando = false);
        return;
      }

      final contatoExtra = <String, dynamic>{
        if (_contatoNome.text.trim().isNotEmpty)
          'contato_nome': _contatoNome.text.trim(),
        if (_contatoTelefone.text.trim().isNotEmpty)
          'contato_telefone': _contatoTelefone.text.trim(),
      };

      await Future.wait([
        _garantirFavorito(
          '/produtoras',
          _produtorasNomes,
          _produtora.text,
          extra: contatoExtra.isEmpty ? null : contatoExtra,
        ),
        _garantirFavorito('/projetos', _projetosSugeridos, _projeto.text),
        if (_diretor.text.trim().isNotEmpty)
          _garantirFavorito('/diretores', _diretoresSugeridos, _diretor.text),
      ]);

      final body = {
        'projeto': _projeto.text.trim(),
        'produtora': _produtora.text.trim(),
        'diretor': _diretor.text.trim(),
        'data': inicioDate.toIso8601String(),
        'hora_inicio': _horaInicio.text.trim(),
        'hora_fim': _horaFim.text.trim(),
        'valor_hora': valorHoraDouble,
        'valor_total': valorTotal,
        'realizado': widget.item?.realizado ?? false,
        if (_observacao.text.trim().isNotEmpty)
          'observacao': _observacao.text.trim(),
        if (_tipoTrabalho.text.trim().isNotEmpty)
          'tipo_trabalho': _tipoTrabalho.text.trim(),
        if (_contatoNome.text.trim().isNotEmpty)
          'contato_nome': _contatoNome.text.trim(),
        if (_contatoTelefone.text.trim().isNotEmpty)
          'contato_telefone': _contatoTelefone.text.trim(),
        'lembretes': _lembretes,
      };

      final result = widget.item == null
          ? await ApiService.post('/schedules', body)
          : await ApiService.put('/schedules/${widget.item!.id}', body);

      if (!mounted) return;

      if (result['success'] != true) {
        _snack(result['error'] ?? 'Não foi possível salvar a escala.');
        return;
      }

      final responseData = result['data'];
      final int id = widget.item == null
          ? ((responseData is Map ? responseData['id'] as num? : null)?.toInt() ?? 0)
          : widget.item!.id;

      try {
        if (id != 0) {
          await NotificationService.scheduleDefaultAgendaNotifications(
            baseId: id,
            corpo:
                '${_produtora.text.trim()} • ${_projeto.text.trim()} às ${_horaInicio.text.trim()}',
            dataHora: inicioDate,
            lembretes: _lembretes,
          );
        }
      } catch (e) {
        debugPrint('Erro ao agendar notificações: $e');
        if (mounted) {
          _snack('Escala salva, mas não foi possível agendar as notificações.');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Erro ao salvar escala: $e');
      _snack('Erro ao salvar a escala: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ----------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titulo = widget.item == null ? 'Nova Escala' : 'Editar Escala';
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              const SizedBox(height: 8),

              // ----- Bloco: dados do trabalho -----
              _label('NOME DO PROJETO', secondaryColor),
              _autocomplete(
                controller: _projeto,
                sugestoes: _projetosSugeridos,
                hint: 'Ex.: Cyberpunk: Edgerunners',
              ),

              _label('PRODUTORA *', secondaryColor),
              _autocomplete(
                controller: _produtora,
                sugestoes: _produtorasNomes,
                hint: 'Ex.: Unidub',
                onSelected: _autoPreencherContato,
              ),

              _label('DIRETOR', secondaryColor),
              _autocomplete(
                controller: _diretor,
                sugestoes: _diretoresSugeridos,
                hint: 'Ex.: Wellington Lima',
              ),

              _label('TIPO DE TRABALHO', secondaryColor),
              _autocomplete(
                controller: _tipoTrabalho,
                sugestoes: _tiposTrabalhoSugeridos,
                hint: 'Loops, Voz Adicional, etc.',
              ),

              const SizedBox(height: 8),
              _sectionCard(
                theme,
                title: 'CONTATO',
                titleColor: secondaryColor,
                child: Column(
                  children: [
                    _label('NOME', secondaryColor),
                    TextField(
                      controller: _contatoNome,
                      decoration:
                          const InputDecoration(hintText: 'Ex.: Maria Silva'),
                    ),
                    const SizedBox(height: 12),
                    _label('TELEFONE', secondaryColor),
                    TextField(
                      controller: _contatoTelefone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_phoneMask],
                      decoration: const InputDecoration(
                        hintText: '(11) 99999-9999',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _sectionCard(
                theme,
                title: 'AGENDAMENTO',
                titleColor: secondaryColor,
                child: Column(
                  children: [
                    _label('DATA *', secondaryColor),
                    OutlinedButton.icon(
                      onPressed: _selecionarData,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _dataSelecionada == null
                            ? 'Selecionar data'
                            : DateFormat('EEEE, dd/MM/yyyy', 'pt_BR')
                                .format(_dataSelecionada!),
                      ),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('INÍCIO *', secondaryColor),
                              TextField(
                                controller: _horaInicio,
                                readOnly: true,
                                onTap: () => _selecionarHora(_horaInicio),
                                decoration: const InputDecoration(
                                  hintText: 'HH:mm',
                                  prefixIcon: Icon(Icons.access_time, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('FIM *', secondaryColor),
                              TextField(
                                controller: _horaFim,
                                readOnly: true,
                                onTap: () => _selecionarHora(_horaFim),
                                decoration: const InputDecoration(
                                  hintText: 'HH:mm',
                                  prefixIcon: Icon(Icons.access_time, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _sectionCard(
                theme,
                title: 'VALOR',
                titleColor: secondaryColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('CÁLCULO', secondaryColor),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_CalculoModo>(
                        segments: const [
                          ButtonSegment(
                            value: _CalculoModo.horaCheia,
                            label: Text('Hora cheia'),
                            icon: Icon(Icons.access_time, size: 16),
                          ),
                          ButtonSegment(
                            value: _CalculoModo.proporcional,
                            label: Text('Proporcional'),
                            icon: Icon(Icons.timelapse, size: 16),
                          ),
                          ButtonSegment(
                            value: _CalculoModo.manual,
                            label: Text('Manual'),
                            icon: Icon(Icons.edit, size: 16),
                          ),
                        ],
                        selected: {_modoCalculo},
                        onSelectionChanged: (s) =>
                            setState(() => _modoCalculo = s.first),
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_modoCalculo == _CalculoModo.manual) ...[
                      _label('VALOR TOTAL (R\$) *', secondaryColor),
                      TextField(
                        controller: _valorTotalManual,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ex.: 150,00',
                          prefixText: 'R\$  ',
                        ),
                      ),
                    ] else ...[
                      _label('VALOR / HORA (R\$) *', secondaryColor),
                      TextField(
                        controller: _valorHora,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ex.: 100,50',
                          prefixText: 'R\$  ',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'TOTAL PREVISTO',
                            style: AppTheme.labelCaps(
                              color: AppColors.secondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            NumberFormat.currency(
                              locale: 'pt_BR',
                              symbol: 'R\$',
                            ).format(_valorTotalPreview),
                            style: AppTheme.financialDisplay(
                                    color: AppColors.secondary)
                                .copyWith(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _sectionCard(
                theme,
                title: 'OBSERVAÇÕES',
                titleColor: secondaryColor,
                child: TextField(
                  controller: _observacao,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ex.: levar texto impresso',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ----- Lembretes (collapse) -----
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(
                        () => _mostrarLembretes = !_mostrarLembretes,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              size: 18,
                              color: AppColors.primaryLight,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'LEMBRETES',
                              style: AppTheme.labelCaps(color: secondaryColor),
                            ),
                            const Spacer(),
                            Icon(
                              _mostrarLembretes
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: secondaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_mostrarLembretes)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          children: _labelLembretes.entries
                              .map(
                                (e) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    e.value,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  value: _lembretes[e.key] ?? false,
                                  onChanged: (v) => setState(
                                    () => _lembretes[e.key] = v ?? false,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: Text(_salvando ? 'Salvando...' : 'Salvar Escala'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar e Voltar'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ---- helpers ----

  Widget _label(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(text, style: AppTheme.labelCaps(color: color)),
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required String title,
    required Color titleColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.labelCaps(color: titleColor)),
          child,
        ],
      ),
    );
  }

  Widget _autocomplete({
    required TextEditingController controller,
    required List<String> sugestoes,
    String? hint,
    void Function(String value)? onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (v) {
          final input = v.text.toLowerCase();
          if (input.isEmpty) return sugestoes;
          return sugestoes.where((s) => s.toLowerCase().contains(input));
        },
        onSelected: (v) {
          controller.text = v;
          if (onSelected != null) onSelected(v);
        },
        fieldViewBuilder: (context, ctrl, focus, onSubmit) {
          controller.addListener(() {
            if (ctrl.text != controller.text) ctrl.text = controller.text;
          });
          return TextField(
            controller: ctrl,
            focusNode: focus,
            onChanged: (v) => controller.text = v,
            decoration: InputDecoration(hintText: hint),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options.elementAt(i);
                  return ListTile(
                    title: Text(opt),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
