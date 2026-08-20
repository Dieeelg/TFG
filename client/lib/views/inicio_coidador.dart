import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modelos_vista/inicio_coidador.dart';
import 'autenticacion/vinculacion_coidador.dart';
import 'paciente_supervisado.dart';
import 'configuracion_paciente_supervisado.dart';
import 'axustes_coidador.dart';

class CaregiverHomeScreen extends StatelessWidget {
  const CaregiverHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => CaregiverHomeViewModel()..iniciar(),
    child: const _CaregiverHomeView(),
  );
}

class _CaregiverHomeView extends StatefulWidget {
  const _CaregiverHomeView();

  @override
  State<_CaregiverHomeView> createState() => _CaregiverHomeViewState();
}

class _CaregiverHomeViewState extends State<_CaregiverHomeView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CaregiverHomeViewModel>().sincronizar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CaregiverHomeViewModel>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8F9FA),
        title: const Text(
          'Bo día,',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: vm.sincronizar,
            icon: vm.actualizando
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 32),
          ),
          IconButton(
            tooltip: 'Axustes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AxustesCoidadorScreen()),
            ).then((_) => vm.cargar()),
            icon: const Icon(Icons.settings_outlined, size: 32),
          ),
          IconButton(
            tooltip: 'Notificacións',
            onPressed: () {},
            icon: const Icon(Icons.mail_outline, size: 32),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.sincronizar,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Lista de pacientes asociados',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (vm.pacientes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(
                  child: Text(
                    'Aínda non hai pacientes vinculados',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ),
            for (var i = 0; i < vm.pacientes.length; i++)
              _tarxeta(vm, vm.pacientes[i], i),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VincularCoidadorScreen(),
                ),
              ).then((_) => vm.sincronizar()),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text(
                'Vincular outro paciente',
                style: TextStyle(fontSize: 17),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarxeta(
    CaregiverHomeViewModel vm,
    Map<String, dynamic> paciente,
    int indice,
  ) {
    final d = paciente['datos'] as Map<String, dynamic>;
    final nome = (d['nome'] as String?)?.trim();
    final tenInforme = d['tenInforme'] == true;
    final estado = d['estadoHoxe'];
    final tomada = estado == 'TOMADA' || estado == 'TOMADA_FORA_HORA';
    final cumprimento = (d['cumprimento'] as num?)?.toInt() ?? 0;
    return Card(
      color: tomada ? const Color(0xFFB8E5E1) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (nome == null || nome.isEmpty || d['horaToma'] == null) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaregiverPatientSettingsScreen(
                  tokenPaciente: paciente['token'] as String,
                  nomeInicial: nome ?? 'Persoa ${indice + 1}',
                ),
              ),
            );
            await vm.sincronizar();
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaregiverPatientScreen(
                  paciente: paciente,
                  numero: indice + 1,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nome?.isNotEmpty == true ? nome! : 'Persoa ${indice + 1}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 30),
                ],
              ),
              const SizedBox(height: 14),
              if (!tenInforme) ...[
                const Center(
                  child: Icon(Icons.info_outline, color: Colors.blue, size: 38),
                ),
                const Center(
                  child: Text(
                    'Escanee o documento para comezar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${tomada ? 'TOMADOS' : 'TOMAR'} ${d['doseHoxe'] ?? '--'}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: tomada ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _resumo(
                      '${d['diasTomados'] ?? 0}',
                      'Días tomados',
                      Colors.green,
                    ),
                    _resumo(
                      '${d['diasNonTomados'] ?? 0}',
                      'Non tomados',
                      Colors.red,
                    ),
                    _resumo('$cumprimento %', 'Cumprimento', Colors.blue),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: cumprimento / 100, minHeight: 8),
                const SizedBox(height: 12),
                Text(
                  'Próxima cita: ${d['proximaVisita'] ?? 'Non dispoñible'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resumo(String v, String t, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: c),
        ),
        Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
