import 'package:flutter/material.dart'; // Calendario do tratamento.
import 'package:provider/provider.dart';
import '../modelos_vista/calendario.dart';
import '../compoñentes/barra_navegacion_inferior.dart';

class CalendarioScreen extends StatelessWidget {
  const CalendarioScreen({super.key, this.viewModel});

  final CalendarioViewModel? viewModel;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => viewModel ?? (CalendarioViewModel()..cargar()),
    child: const _CalendarioView(),
  );
}

class _CalendarioView extends StatelessWidget {
  const _CalendarioView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarioViewModel>();
    final diasAtaCita = vm.diasAtaCita;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8F9FA),
        title: const Text(
          'O meu calendario',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
      body: vm.cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Monitoriza as tomas e as datas das citas de control',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                if (vm.meses.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Non hai ningunha pauta gardada.'),
                    ),
                  )
                else
                  ...vm.meses.expand(
                    (mes) => [_mes(mes, vm), const SizedBox(height: 14)],
                  ),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    title: const Text(
                      'Próxima cita',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vm.proximaVisita ?? 'Non dispoñible',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (diasAtaCita != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            diasAtaCita == 0
                                ? 'É hoxe'
                                : diasAtaCita > 0
                                ? 'Quedan $diasAtaCita días'
                                : 'A cita xa pasou',
                            style: TextStyle(
                              fontSize: 16,
                              color: diasAtaCita >= 0
                                  ? Colors.orange
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.schedule, size: 38),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumo da pauta actual',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _resumo(
                              '${vm.tomadas}',
                              'Días tomados',
                              Colors.green,
                            ),
                            _resumo(
                              '${vm.esquecidas}',
                              'Días non tomados',
                              Colors.red,
                            ),
                            _resumo(
                              '${vm.cumprimento} %',
                              'Cumprimento',
                              Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: vm.cumprimento / 100,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFE1E4E8),
                            color: vm.cumprimento >= 80
                                ? Colors.green
                                : vm.cumprimento >= 50
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const BarraNavegacionInferior(currentIndex: 3),
    );
  }

  Widget _mes(MesCalendario mes, CalendarioViewModel vm) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            '${_nomeMes(mes.mes)} ${mes.ano}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _CabeceiraDia('Lun')),
              Expanded(child: _CabeceiraDia('Mar')),
              Expanded(child: _CabeceiraDia('Mér')),
              Expanded(child: _CabeceiraDia('Xov')),
              Expanded(child: _CabeceiraDia('Ven')),
              Expanded(child: _CabeceiraDia('Sáb')),
              Expanded(child: _CabeceiraDia('Dom')),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            children: mes.celas.map((dia) => _dia(dia, vm)).toList(),
          ),
        ],
      ),
    ),
  );

  Widget _dia(DiaCalendario? entrada, CalendarioViewModel vm) {
    if (entrada == null) return const SizedBox.shrink();
    final dia = entrada.dose;
    if (dia == null) {
      return Center(
        child: Text(
          '${entrada.data.day}',
          style: const TextStyle(color: Colors.black38),
        ),
      );
    }

    Color cor = const Color(0xFFE1E4E8);
    if (dia.dose == '0') {
      cor = const Color(0xFFFFD0C8);
    } else if (vm.estadoDe(dia.data) == 'TOMADA') {
      cor = const Color(0xFF9BE0CA);
    } else if (vm.estadoDe(dia.data) == 'TOMADA_FORA_HORA') {
      cor = const Color(0xFFFFD180);
    } else if (dia.data.compareTo(vm.hoxe) < 0) {
      cor = const Color(0xFFFFA99B);
    }
    return Tooltip(
      message: dia.eControl ? 'Control' : 'Dose: ${dia.dose}',
      child: CircleAvatar(
        backgroundColor: cor,
        child: Text(
          '${dia.dia}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _nomeMes(int mes) => const [
    'Xaneiro',
    'Febreiro',
    'Marzo',
    'Abril',
    'Maio',
    'Xuño',
    'Xullo',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Decembro',
  ][mes - 1];

  Widget _resumo(String valor, String etiqueta, Color cor) => Expanded(
    child: SizedBox(
      height: 78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              etiqueta,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.15),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CabeceiraDia extends StatelessWidget {
  const _CabeceiraDia(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    textAlign: TextAlign.center,
    style: const TextStyle(fontWeight: FontWeight.bold),
  );
}
