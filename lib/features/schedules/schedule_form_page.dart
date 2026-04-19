import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/schedule_model.dart';
import '../../core/services/api_service.dart';
import '../../notification_service.dart';

// Rótulos exibidos para cada chave de lembrete
const _labelLembretes = {
  '60min': '1 hora antes',
  '30min': '30 minutos antes',
  '5min': '5 minutos antes',
  'exato': 'No horário exato',
};

class ScheduleFormPage extends StatefulWidget {
  final ScheduleModel? item;
  final List<ScheduleModel> escalasExistentes;

  const ScheduleFormPage({
    super.key,
    this.item,
    this.escalasExistentes = const [],
  });

  @override
  State<ScheduleFormPage> createState() => _ScheduleFormPageState();
}

class _ScheduleFormPageState extends State<ScheduleFormPage> {
  final _projeto = TextEditingController();
  final _produtora = TextEditingController();
  final _diretor = TextEditingController();
  final _valorHora = TextEditingController();
  final _horaInicio = TextEditingController();
  final _horaFim = TextEditingController();
  final _observacao = TextEditingController();

  DateTime? _dataSelecionada;
  bool _salvando = false;
  List<String> _produtorasSugeridas = [];
  Map<String, bool> _lembretes = Map<String, bool>.from(ScheduleModel.defaultLembretes);

  @override
  void initState() {
    super.initState();
    _carregarProdutoras();

    if (widget.item != null) {
      final item = widget.item!;
      _projeto.text = item.projeto;
      _produtora.text = item.produtora;
      _diretor.text = item.diretor ?? '';
      _valorHora.text = item.valorHora.toString().replaceAll('.', ',');
      _horaInicio.text = item.horaInicio;
      _horaFim.text = item.horaFim;
      _observacao.text = item.observacao ?? '';
      _dataSelecionada = item.data;
      _lembretes = Map<String, bool>.from(item.lembretes);
    }
  }

  @override
  void dispose() {
    _projeto.dispose();
    _produtora.dispose();
    _diretor.dispose();
    _valorHora.dispose();
    _horaInicio.dispose();
    _horaFim.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutoras() async {
    final result = await ApiService.get('/produtoras');
    if (result['success'] == true && result['data'] is List) {
      setState(() {
        _produtorasSugeridas = (result['data'] as List)
            .map((e) => e['nome']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
      });
    }
  }

  double _parseValor(String valor) {
    return double.parse(valor.replaceAll('.', '').replaceAll(',', '.'));
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

    if (picked != null) {
      setState(() => _dataSelecionada = picked);
    }
  }

  bool _validarCampos() {
    if (_produtora.text.trim().isEmpty ||
        _projeto.text.trim().isEmpty ||
        _horaInicio.text.trim().isEmpty ||
        _horaFim.text.trim().isEmpty ||
        _valorHora.text.trim().isEmpty ||
        _dataSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios.'),
        ),
      );
      return false;
    }
    return true;
  }

  bool _temConflito(DateTime inicio, DateTime fim) {
    for (final escala in widget.escalasExistentes) {
      // Ignora a própria escala ao editar
      if (widget.item != null && escala.id == widget.item!.id) continue;

      // Compara apenas escalas do mesmo dia
      if (escala.data.year != inicio.year ||
          escala.data.month != inicio.month ||
          escala.data.day != inicio.day) continue;

      final partes = escala.horaInicio.split(':');
      final partesF = escala.horaFim.split(':');
      final eInicio = DateTime(inicio.year, inicio.month, inicio.day,
          int.parse(partes[0]), int.parse(partes[1]));
      final eFim = DateTime(inicio.year, inicio.month, inicio.day,
          int.parse(partesF[0]), int.parse(partesF[1]));

      // Sobreposição: A < D && C < B
      if (inicio.isBefore(eFim) && eInicio.isBefore(fim)) return true;
    }
    return false;
  }

  Future<void> _garantirProdutora(String nome) async {
    final nomeNormalizado = nome.trim();
    if (nomeNormalizado.isEmpty) return;
    if (!_produtorasSugeridas.contains(nomeNormalizado)) {
      await ApiService.post('/produtoras', {'nome': nomeNormalizado});
    }
  }

  Future<void> _salvar() async {
    if (!_validarCampos()) return;

    setState(() => _salvando = true);

    try {
      final inicio = _horaInicio.text.split(':');
      final fim = _horaFim.text.split(':');

      final inicioDate = DateTime(
        _dataSelecionada!.year,
        _dataSelecionada!.month,
        _dataSelecionada!.day,
        int.parse(inicio[0]),
        int.parse(inicio[1]),
      );

      final fimDate = DateTime(
        _dataSelecionada!.year,
        _dataSelecionada!.month,
        _dataSelecionada!.day,
        int.parse(fim[0]),
        int.parse(fim[1]),
      );

      final diferencaMinutos = fimDate.difference(inicioDate).inMinutes;

      if (diferencaMinutos <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hora fim deve ser maior que hora início.'),
          ),
        );
        setState(() => _salvando = false);
        return;
      }

      final valorHoraDouble = _parseValor(_valorHora.text);
      final valorTotal = (diferencaMinutos / 60.0) * valorHoraDouble;

      // Verifica conflito de horário com escalas existentes
      if (_temConflito(inicioDate, fimDate)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Período indisponível! Já existe uma escala nesse horário.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _salvando = false);
        return;
      }

      await _garantirProdutora(_produtora.text);

      final observacaoTexto = _observacao.text.trim();
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
        if (observacaoTexto.isNotEmpty) 'observacao': observacaoTexto,
        'lembretes': _lembretes,
      };

      final result = widget.item == null
          ? await ApiService.post('/schedules', body)
          : await ApiService.put('/schedules/${widget.item!.id}', body);

      if (!mounted) return;

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ?? 'Não foi possível salvar a escala.',
            ),
          ),
        );
        return;
      }

      final responseData = result['data'];
      final int id = widget.item == null
          ? ((responseData is Map ? responseData['id'] as num? : null)
                  ?.toInt() ??
              0)
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Escala salva, mas não foi possível agendar as notificações.',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Erro ao salvar escala: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar a escala: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(
    String label,
    TextEditingController c, {
    VoidCallback? onTap,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        readOnly: onTap != null,
        onTap: onTap,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.item == null ? 'Nova Escala' : 'Editar Escala';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Campo Produtora com Autocomplete
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: _produtora.text),
                optionsBuilder: (textEditingValue) {
                  final input = textEditingValue.text.toLowerCase();
                  if (input.isEmpty) return _produtorasSugeridas;
                  return _produtorasSugeridas
                      .where((p) => p.toLowerCase().contains(input))
                      .toList();
                },
                onSelected: (value) => _produtora.text = value,
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  _produtora.addListener(() {
                    if (controller.text != _produtora.text) {
                      controller.text = _produtora.text;
                    }
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (v) => _produtora.text = v,
                    decoration: const InputDecoration(labelText: 'Produtora *'),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(8),
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, i) {
                            final option = options.elementAt(i);
                            return ListTile(
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _campo('Projeto *', _projeto),
            _campo('Diretor', _diretor),
            ElevatedButton(
              onPressed: _selecionarData,
              child: Text(
                _dataSelecionada == null
                    ? 'Selecionar Data'
                    : DateFormat('dd/MM/yyyy').format(_dataSelecionada!),
              ),
            ),
            const SizedBox(height: 12),
            _campo(
              'Hora início *',
              _horaInicio,
              onTap: () => _selecionarHora(_horaInicio),
              hint: 'HH:mm',
            ),
            _campo(
              'Hora fim *',
              _horaFim,
              onTap: () => _selecionarHora(_horaFim),
              hint: 'HH:mm',
            ),
            _campo('Valor/hora *', _valorHora, hint: 'Ex: 100,50'),
            _campo('Observações', _observacao,
                hint: 'Ex: levar texto impresso', maxLines: 3),
            const SizedBox(height: 20),

            // --- Seção Lembretes ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          size: 16, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Lembretes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._labelLembretes.entries.map(
                    (entry) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value,
                          style: const TextStyle(fontSize: 14)),
                      value: _lembretes[entry.key] ?? false,
                      onChanged: (v) => setState(
                          () => _lembretes[entry.key] = v ?? false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
