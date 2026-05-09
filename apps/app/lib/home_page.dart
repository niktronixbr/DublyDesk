import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'api_config.dart';
import 'auth_service.dart';
import 'finance_page.dart';
import 'login_page.dart';

final NumberFormat moeda =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List schedules = [];
  List filteredSchedules = [];

  double totalRealizado = 0;
  bool carregando = false;
  String userName = '';

  final TextEditingController buscaController = TextEditingController();
  String filtroProdutora = 'Todas';

  @override
  void initState() {
    super.initState();
    carregarUsuario();
    fetchSchedules();
    buscaController.addListener(aplicarFiltros);
  }

  @override
  void dispose() {
    buscaController.dispose();
    super.dispose();
  }

  Future<void> carregarUsuario() async {
    final nome = await AuthService.getUserName();
    if (!mounted) return;
    setState(() {
      userName = nome ?? '';
    });
  }

  Future<void> logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> fetchSchedules() async {
    setState(() => carregando = true);

    try {
      final headers = await AuthService.authHeaders();

      final res = await http
          .get(Uri.parse('$baseUrl/schedules'), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List data = json.decode(res.body);

        double soma = 0;
        for (final item in data) {
          if (item['realizado'] == true) {
            soma += double.tryParse(item['valor_total'].toString()) ?? 0;
          }
        }

        if (!mounted) return;

        setState(() {
          schedules = data;
          totalRealizado = soma;
        });

        aplicarFiltros();
      } else {
        _mostrarErro('Erro ao buscar escalas.');
      }
    } catch (e) {
      _mostrarErro('Falha ao carregar escalas.');
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  void aplicarFiltros() {
    final termo = buscaController.text.trim().toLowerCase();

    final lista = schedules.where((item) {
      final produtora = (item['produtora'] ?? '').toString();
      final projeto = (item['projeto'] ?? '').toString();
      final diretor = (item['diretor'] ?? '').toString();

      final atendeBusca = termo.isEmpty ||
          produtora.toLowerCase().contains(termo) ||
          projeto.toLowerCase().contains(termo) ||
          diretor.toLowerCase().contains(termo);

      final atendeProdutora =
          filtroProdutora == 'Todas' || produtora == filtroProdutora;

      return atendeBusca && atendeProdutora;
    }).toList();

    if (!mounted) return;
    setState(() {
      filteredSchedules = lista;
    });
  }

  List<String> produtorasDisponiveis() {
    final produtoras = schedules
        .map((e) => (e['produtora'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['Todas', ...produtoras];
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void openForm({Map? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormPage(item: item),
      ),
    ).then((_) => fetchSchedules());
  }

  Future<void> toggleRealizado(Map item) async {
    try {
      final headers = await AuthService.authHeaders();

      final response = await http
          .put(
            Uri.parse('$baseUrl/schedules/${item['id']}'),
            headers: headers,
            body: json.encode({
              'realizado': !(item['realizado'] == true),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await fetchSchedules();
      } else {
        _mostrarErro('Não foi possível atualizar a escala.');
      }
    } catch (e) {
      _mostrarErro('Erro ao atualizar status da escala.');
    }
  }

  Future<void> deletar(int id) async {
    try {
      final headers = await AuthService.authHeaders();

      final response = await http
          .delete(Uri.parse('$baseUrl/schedules/$id'), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await fetchSchedules();
      } else {
        _mostrarErro('Não foi possível apagar a escala.');
      }
    } catch (e) {
      _mostrarErro('Erro ao apagar a escala.');
    }
  }

  void confirmarDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir escala'),
        content: const Text('Deseja apagar esta escala?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deletar(id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoTopo() {
    final realizadas =
        schedules.where((item) => item['realizado'] == true).length;
    final pendentes =
        schedules.where((item) => item['realizado'] != true).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C2B), Color(0xFF2A2A40)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userName.isEmpty ? 'Painel rápido' : 'Olá, $userName',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            moeda.format(totalRealizado),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStatusCard(
                  titulo: 'Realizadas',
                  valor: realizadas.toString(),
                  cor: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatusCard(
                  titulo: 'Pendentes',
                  valor: pendentes.toString(),
                  cor: Colors.orangeAccent,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          TextField(
            controller: buscaController,
            decoration: const InputDecoration(
              hintText: 'Buscar por projeto, produtora ou diretor',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButton<String>(
              value: filtroProdutora,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E2E),
              underline: const SizedBox(),
              items: produtorasDisponiveis()
                  .map(
                    (produtora) => DropdownMenuItem(
                      value: produtora,
                      child: Text(produtora),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  filtroProdutora = value;
                });
                aplicarFiltros();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (carregando) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (filteredSchedules.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('Nenhuma escala encontrada.'),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: fetchSchedules,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: filteredSchedules.length,
          itemBuilder: (context, index) {
            final item = filteredSchedules[index];

            final DateTime data =
                DateTime.parse(item['data'].toString());
            final String dataFormatada =
                DateFormat('dd/MM/yyyy HH:mm').format(data);

            final bool realizado = item['realizado'] == true;
            final double valorTotal =
                double.tryParse(item['valor_total'].toString()) ?? 0;

            return Dismissible(
              key: Key('schedule_${item['id']}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Excluir escala'),
                    content: const Text('Deseja apagar esta escala?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );

                if (result == true) {
                  await deletar(item['id'] as int);
                }
                return false;
              },
              background: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: GestureDetector(
                onTap: () => openForm(item: item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E1E2E),
                        Color(0xFF2A2A3C),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['produtora']} • ${item['projeto']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Checkbox(
                            value: realizado,
                            onChanged: (_) => toggleRealizado(item),
                          ),
                          IconButton(
                            tooltip: 'Apagar',
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                confirmarDelete(item['id'] as int),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Diretor: ${item['diretor'] ?? ''}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              Text(dataFormatada),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time,
                                  size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              Text(
                                '${item['hora_inicio']} - ${item['hora_fim']}',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: realizado
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              realizado ? 'Realizada' : 'Pendente',
                              style: TextStyle(
                                color: realizado
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            moeda.format(valorTotal),
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escalas Premium'),
        actions: [
          IconButton(
            tooltip: 'Nova escala',
            icon: const Icon(Icons.add),
            onPressed: () => openForm(),
          ),
          IconButton(
            tooltip: 'Financeiro',
            icon: const Icon(Icons.attach_money),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FinancePage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildResumoTopo(),
          _buildFiltros(),
          _buildLista(),
        ],
      ),
    );
  }
}

class _MiniStatusCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;

  const _MiniStatusCard({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

class FormPage extends StatefulWidget {
  final Map? item;

  const FormPage({super.key, this.item});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final projeto = TextEditingController();
  final produtora = TextEditingController();
  final diretor = TextEditingController();
  final valorHora = TextEditingController();
  final horaInicio = TextEditingController();
  final horaFim = TextEditingController();

  DateTime? dataSelecionada;
  bool salvando = false;

  @override
  void initState() {
    super.initState();

    if (widget.item != null) {
      final item = widget.item!;
      projeto.text = item['projeto']?.toString() ?? '';
      produtora.text = item['produtora']?.toString() ?? '';
      diretor.text = item['diretor']?.toString() ?? '';
      valorHora.text =
          item['valor_hora']?.toString().replaceAll('.', ',') ?? '';
      horaInicio.text = item['hora_inicio']?.toString() ?? '';
      horaFim.text = item['hora_fim']?.toString() ?? '';
      dataSelecionada = DateTime.parse(item['data'].toString());
    }
  }

  @override
  void dispose() {
    projeto.dispose();
    produtora.dispose();
    diretor.dispose();
    valorHora.dispose();
    horaInicio.dispose();
    horaFim.dispose();
    super.dispose();
  }

  double parseValor(String valor) {
    return double.parse(valor.replaceAll('.', '').replaceAll(',', '.'));
  }

  Future<void> selecionarHora(TextEditingController controller) async {
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
    );

    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dataSelecionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => dataSelecionada = picked);
    }
  }

  bool validarCampos() {
    if (produtora.text.trim().isEmpty ||
        projeto.text.trim().isEmpty ||
        horaInicio.text.trim().isEmpty ||
        horaFim.text.trim().isEmpty ||
        valorHora.text.trim().isEmpty ||
        dataSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios.')),
      );
      return false;
    }
    return true;
  }

  Future<void> salvar() async {
    if (!validarCampos()) return;

    setState(() => salvando = true);

    try {
      final headers = await AuthService.authHeaders();

      final inicio = horaInicio.text.split(':');
      final fim = horaFim.text.split(':');

      final horaInicioInt = int.parse(inicio[0]);
      final minutoInicioInt = int.parse(inicio[1]);

      final horaFimInt = int.parse(fim[0]);
      final minutoFimInt = int.parse(fim[1]);

      final inicioDate = DateTime(
        dataSelecionada!.year,
        dataSelecionada!.month,
        dataSelecionada!.day,
        horaInicioInt,
        minutoInicioInt,
      );

      final fimDate = DateTime(
        dataSelecionada!.year,
        dataSelecionada!.month,
        dataSelecionada!.day,
        horaFimInt,
        minutoFimInt,
      );

      final diferencaMinutos = fimDate.difference(inicioDate).inMinutes;
      final horasCalculadas = diferencaMinutos / 60.0;

      if (horasCalculadas <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hora fim deve ser maior que hora início.'),
          ),
        );
        setState(() => salvando = false);
        return;
      }

      final valorHoraDouble = parseValor(valorHora.text);
      final valorTotal = horasCalculadas * valorHoraDouble;

      final body = {
        'projeto': projeto.text.trim(),
        'produtora': produtora.text.trim(),
        'diretor': diretor.text.trim(),
        'data': inicioDate.toIso8601String(),
        'hora_inicio': horaInicio.text.trim(),
        'hora_fim': horaFim.text.trim(),
        'valor_hora': valorHoraDouble,
        'valor_total': valorTotal,
        'realizado': widget.item?['realizado'] ?? false,
      };

      final response = widget.item == null
          ? await http
              .post(
                Uri.parse('$baseUrl/schedules'),
                headers: headers,
                body: json.encode(body),
              )
              .timeout(const Duration(seconds: 8))
          : await http
              .put(
                Uri.parse('$baseUrl/schedules/${widget.item!['id']}'),
                headers: headers,
                body: json.encode(body),
              )
              .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a escala.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar a escala.')),
      );
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  Widget campo(
    String label,
    TextEditingController c, {
    VoidCallback? onTap,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        readOnly: onTap != null,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
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
            campo('Produtora', produtora),
            campo('Projeto', projeto),
            campo('Diretor', diretor),
            ElevatedButton(
              onPressed: selecionarData,
              child: Text(
                dataSelecionada == null
                    ? 'Selecionar Data'
                    : DateFormat('dd/MM/yyyy').format(dataSelecionada!),
              ),
            ),
            const SizedBox(height: 12),
            campo(
              'Hora início',
              horaInicio,
              onTap: () => selecionarHora(horaInicio),
              hint: 'HH:mm',
            ),
            campo(
              'Hora fim',
              horaFim,
              onTap: () => selecionarHora(horaFim),
              hint: 'HH:mm',
            ),
            campo(
              'Valor/hora',
              valorHora,
              hint: 'Ex: 100,50',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: salvando ? null : salvar,
              child: Text(salvando ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}