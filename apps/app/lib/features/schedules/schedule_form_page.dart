import 'dart:async';

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
  final _valorTotal = TextEditingController();
  final _horaInicio = TextEditingController();
  final _horaFim = TextEditingController();
  final _observacao = TextEditingController();

  DateTime? _dataSelecionada;
  bool _salvando = false;
  bool _mostrarLembretes = false;
  String _tipo = 'trabalho';
  bool _remunerado = true;
  Timer? _contatoDebounce;

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
      _valorTotal.text = item.valorTotal.toString().replaceAll('.', ',');
      _horaInicio.text = item.horaInicio;
      _horaFim.text = item.horaFim;
      _observacao.text = item.observacao ?? '';
      _dataSelecionada = item.data;
      _lembretes = Map<String, bool>.from(item.lembretes);
      _tipo = item.tipo;
      _remunerado = item.remunerado;
      if (_tipo == 'compromisso') {
        _valorTotal.text = '';
      }
    }

    _valorTotal.addListener(() => setState(() {}));
    _horaInicio.addListener(() => setState(() {}));
    _horaFim.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contatoDebounce?.cancel();
    _projeto.dispose();
    _produtora.dispose();
    _diretor.dispose();
    _tipoTrabalho.dispose();
    _contatoNome.dispose();
    _contatoTelefone.dispose();
    _valorTotal.dispose();
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

  void _onContatoNomeChanged(String nome) {
    _contatoDebounce?.cancel();
    _contatoDebounce =
        Timer(const Duration(milliseconds: 400), () => _buscarTelefonePorContato(nome));
  }

  void _buscarTelefonePorContato(String nome) {
    if (!mounted) return;
    final n = nome.trim().toLowerCase();
    if (n.isEmpty) return;

    Map<String, dynamic>? match;
    for (final p in _produtorasFull) {
      final cn = (p['contato_nome']?.toString() ?? '').trim().toLowerCase();
      if (cn == n) {
        match = p;
        break;
      }
    }

    final tel = match?['contato_telefone']?.toString();
    if (tel == null || tel.isEmpty) return;
    if (_contatoTelefone.text.trim().isNotEmpty) return;

    setState(() {
      _phoneMask.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: tel),
      );
      _contatoTelefone.text = _phoneMask.getMaskedText();
    });
  }

  double _parseValor(String valor) {
    if (valor.trim().isEmpty) return 0;
    return double.tryParse(
            valor.replaceAll('.', '').replaceAll(',', '.')) ??
        0;
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
    if (_dataSelecionada == null ||
        _horaInicio.text.trim().isEmpty ||
        _horaFim.text.trim().isEmpty) {
      _snack('Preencha data e horários obrigatórios.');
      return false;
    }

    if (_tipo == 'compromisso') {
      if (_projeto.text.trim().isEmpty) {
        _snack('Informe o título do compromisso.');
        return false;
      }
    } else {
      if (_produtora.text.trim().isEmpty) {
        _snack('Produtora é obrigatória.');
        return false;
      }
      if (_remunerado && _valorTotal.text.trim().isEmpty) {
        _snack('Informe o valor total ou desative a remuneração.');
        return false;
      }
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

      final isCompromisso = _tipo == 'compromisso';
      final valorTotal = (!isCompromisso && _remunerado) ? _parseValor(_valorTotal.text) : 0.0;

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

      if (!isCompromisso) {
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
      }

      final body = <String, dynamic>{
        'tipo': _tipo,
        'projeto': _projeto.text.trim(),
        'produtora': isCompromisso ? '' : _produtora.text.trim(),
        if (!isCompromisso) 'diretor': _diretor.text.trim(),
        'data': inicioDate.toIso8601String(),
        'hora_inicio': _horaInicio.text.trim(),
        'hora_fim': _horaFim.text.trim(),
        'valor_hora': 0,
        'valor_total': valorTotal,
        'remunerado': isCompromisso ? false : _remunerado,
        'realizado': widget.item?.realizado ?? false,
        if (_observacao.text.trim().isNotEmpty)
          'observacao': _observacao.text.trim(),
        if (!isCompromisso && _tipoTrabalho.text.trim().isNotEmpty)
          'tipo_trabalho': _tipoTrabalho.text.trim(),
        if (!isCompromisso && _contatoNome.text.trim().isNotEmpty)
          'contato_nome': _contatoNome.text.trim(),
        if (!isCompromisso && _contatoTelefone.text.trim().isNotEmpty)
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
            corpo: isCompromisso
                ? '${_projeto.text.trim()} às ${_horaInicio.text.trim()}'
                : '${_produtora.text.trim()} • ${_projeto.text.trim()} às ${_horaInicio.text.trim()}',
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
    final isCompromisso = _tipo == 'compromisso';
    final titulo = widget.item == null
        ? (isCompromisso ? 'Novo Compromisso' : 'Nova Escala')
        : (isCompromisso ? 'Editar Compromisso' : 'Editar Escala');
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

              // Tipo selector
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'trabalho', label: Text('Trabalho')),
                    ButtonSegment(value: 'compromisso', label: Text('Compromisso')),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() {
                      _tipo = s.first;
                      if (_tipo == 'compromisso') {
                        _remunerado = false;
                        _valorTotal.text = '';
                        _diretor.clear();
                        _tipoTrabalho.clear();
                        _contatoNome.clear();
                        _contatoTelefone.clear();
                        _produtora.clear();
                      } else {
                        _remunerado = true;
                      }
                    });
                  },
                ),
              ),

              // ----- Bloco: dados do trabalho -----
              _label(isCompromisso ? 'TÍTULO *' : 'NOME DO PROJETO', secondaryColor),
              _autocomplete(
                controller: _projeto,
                sugestoes: _projetosSugeridos,
                hint: isCompromisso ? 'Ex.: Reunião escola' : 'Ex.: Cyberpunk: Edgerunners',
              ),

              if (!isCompromisso) ...[
                _label('PRODUTORA *', secondaryColor),
                _autocomplete(
                  controller: _produtora,
                  sugestoes: _produtorasNomes,
                  hint: 'Ex.: Unidub',
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
                        onChanged: _onContatoNomeChanged,
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
              ],

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

              if (!isCompromisso) ...[
                const SizedBox(height: 16),
                _sectionCard(
                  theme,
                  title: 'VALOR',
                  titleColor: secondaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Remuneração',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Switch(
                            value: _remunerado,
                            onChanged: (v) => setState(() {
                              _remunerado = v;
                              if (!v) _valorTotal.text = '';
                            }),
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _remunerado
                            ? Column(
                                key: const ValueKey('valor-on'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('VALOR TOTAL (R\$) *', secondaryColor),
                                  TextField(
                                    controller: _valorTotal,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Ex.: 150,00',
                                      prefixText: 'R\$  ',
                                    ),
                                  ),
                                ],
                              )
                            : Padding(
                                key: const ValueKey('valor-off'),
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Sem remuneração (teste, retake, etc.)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: secondaryColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],

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
                  child: Text(_salvando ? 'Salvando...' : (isCompromisso ? 'Salvar Compromisso' : 'Salvar Escala')),
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
