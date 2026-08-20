import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modelos/analise.dart';
import '../../modelos/dose_dia.dart';
import '../../modelos/revision_pauta.dart';
import '../../modelos_vista/revision_pauta.dart';

class RevisionPautaScreen extends StatelessWidget {
  final AnaliseModel analise;
  final bool paraEnviar;

  const RevisionPautaScreen({
    super.key,
    required this.analise,
    this.paraEnviar = false,
  });

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => TreatmentReviewViewModel(analise),
    child: _RevisionPautaView(paraEnviar: paraEnviar),
  );
}

class _RevisionPautaView extends StatefulWidget {
  final bool paraEnviar;
  const _RevisionPautaView({required this.paraEnviar});

  @override
  State<_RevisionPautaView> createState() => _RevisionPautaViewState();
}

class _RevisionPautaViewState extends State<_RevisionPautaView> {
  TreatmentReviewViewModel get _vm => context.read<TreatmentReviewViewModel>();
  AnaliseModel get _analise => _vm.analise;
  bool get _editando => _vm.editando;

  static const _azul = Colors.blue;
  static const _verde = Color(0xFF268F5A);
  static const _fondo = Color(0xFFF8F9FA);
  static const _escuro = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    context.watch<TreatmentReviewViewModel>();
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Text(
          _editando ? 'Corrixir a pauta' : 'Revisar o informe',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _cabecera(),
            const SizedBox(height: 16),
            _datosXerais(),
            const SizedBox(height: 16),
            _tarxetaPauta(),
            const SizedBox(height: 16),
            _proximaVisita(),
            const SizedBox(height: 18),
            _accions(),
          ],
        ),
      ),
    );
  }

  Widget _cabecera() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F4FF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
          child: Icon(
            _editando ? Icons.edit_outlined : Icons.fact_check_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editando
                    ? 'Corrixe os datos necesarios'
                    : 'Comproba que a pauta sexa correcta',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _editando
                    ? 'Podes modificar as datas, as doses, os días de control e a seguinte visita.'
                    : 'A pauta anterior non se substituirá ata que confirmes estes datos.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _datosXerais() {
    final c = _analise.cabeceira;
    final datos = <({IconData icona, String etiqueta, String valor})>[
      if (_tenValor(c.dataInforme))
        (
          icona: Icons.description_outlined,
          etiqueta: 'Data do informe',
          valor: c.dataInforme!,
        ),
      if (_tenValor(c.farmaco))
        (
          icona: Icons.medication_outlined,
          etiqueta: 'Fármaco',
          valor: c.farmaco!,
        ),
      if (_tenValor(c.inr))
        (icona: Icons.water_drop_outlined, etiqueta: 'INR', valor: c.inr!),
      if (_tenValor(c.doseSemanal))
        (
          icona: Icons.calendar_view_week_outlined,
          etiqueta: 'Dose semanal',
          valor: c.doseSemanal!,
        ),
    ];
    if (datos.isEmpty) return const SizedBox.shrink();

    return _tarxeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos extraídos',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final ancho = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: datos
                    .map(
                      (dato) => SizedBox(
                        width: ancho,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(dato.icona, color: _azul, size: 23),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dato.etiqueta,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dato.valor,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tarxetaPauta() => _tarxeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pauta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${_analise.calendario.length} días',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_editando) _listaEditable() else _gradePauta(),
      ],
    ),
  );

  Widget _gradePauta() => LayoutBuilder(
    builder: (context, constraints) {
      final columnas = constraints.maxWidth >= 340 ? 4 : 3;
      final ancho = (constraints.maxWidth - ((columnas - 1) * 10)) / columnas;
      return Wrap(
        spacing: 10,
        runSpacing: 18,
        children: _analise.calendario
            .map((dia) => SizedBox(width: ancho, child: _diaPauta(dia)))
            .toList(),
      );
    },
  );

  Widget _diaPauta(DoseDiaModel dia) {
    final dose = dia.eControl ? 'CTRL' : (dia.dose ?? '--');
    final fondoDose = dia.eControl
        ? _escuro
        : dia.dose == '0'
        ? const Color(0xFFFFD0C8)
        : const Color(0xFFDDF3EF);
    return Semantics(
      label: dia.eControl
          ? '${dia.diaSemanaTexto}, ${dia.data}, control'
          : '${dia.diaSemanaTexto}, ${dia.data}, dose ${dia.dose}',
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: fondoDose,
            radius: 28,
            child: Text(
              dose,
              style: TextStyle(
                color: dia.eControl ? Colors.white : const Color(0xFF167B72),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _nomeDiaCurto(dia.diaSemanaTexto),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            _dataCurta(dia.data),
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _listaEditable() => Column(
    children: List.generate(_analise.calendario.length, (indice) {
      final dia = _analise.calendario[indice];
      return Padding(
        padding: EdgeInsets.only(
          bottom: indice == _analise.calendario.length - 1 ? 0 : 12,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1E4E8)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: dia.eControl
                        ? _escuro
                        : const Color(0xFFDDF3EF),
                    child: Text(
                      dia.eControl ? 'C' : (dia.dose ?? '--'),
                      style: TextStyle(
                        color: dia.eControl
                            ? Colors.white
                            : const Color(0xFF167B72),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _escollerDataDia(indice),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          _dataVisible(dia.data),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: ValueKey('eliminar-dia-$indice'),
                    tooltip: 'Eliminar este día',
                    onPressed: () => _eliminarDia(indice),
                    color: Colors.red.shade700,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: dia.eControl
                          ? null
                          : () => _escollerDose(indice),
                      icon: const Icon(Icons.medication_outlined),
                      label: Text(
                        dia.eControl ? 'Sen dose' : 'Dose: ${dia.dose ?? '--'}',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      const Text(
                        'Control',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Switch(
                        value: dia.eControl,
                        activeThumbColor: _verde,
                        onChanged: (valor) =>
                            _vm.actualizarDia(indice, eControl: valor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }),
  );

  Widget _proximaVisita() {
    final visita = _analise.cabeceira.proximaVisita;
    return _tarxeta(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.event_outlined, color: _azul, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seguinte visita',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  _tenValor(visita)
                      ? _dataVisible(visita!)
                      : 'Non identificada',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_tenValor(_analise.cabeceira.centro)) ...[
                  const SizedBox(height: 2),
                  Text(
                    _analise.cabeceira.centro!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_editando)
            IconButton.filledTonal(
              tooltip: 'Corrixir a seguinte visita',
              onPressed: _escollerProximaVisita,
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
        ],
      ),
    );
  }

  Widget _accions() {
    if (_editando) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF9A6A00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ao rematar volverás á revisión para comprobar as correccións.',
                    style: TextStyle(fontSize: 14, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _revisarCorreccions,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Revisar correccións'),
            style: _estiloBotonPrincipal(_verde),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _vm.cancelarCambios,
            child: const Text(
              'Cancelar os cambios',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      );
    }

    return _tarxeta(
      child: Column(
        children: [
          const Icon(Icons.help_outline, color: _azul, size: 38),
          const SizedBox(height: 8),
          const Text(
            'Está todo correcto?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirma especialmente as datas e as doses antes de continuar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.35, color: Colors.black54),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _confirmar,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              widget.paraEnviar
                  ? 'Si, confirmar e enviar'
                  : 'Si, confirmar e gardar',
            ),
            style: _estiloBotonPrincipal(_verde),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _vm.iniciarEdicion,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Non, corrixir datos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _escuro,
              minimumSize: const Size(double.infinity, 54),
              side: const BorderSide(color: _escuro, width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _estiloBotonPrincipal(Color cor) => ElevatedButton.styleFrom(
    backgroundColor: cor,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 56),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  void _eliminarDia(int indice) {
    final eliminado = _vm.eliminarDia(indice);

    final mensaxeiro = ScaffoldMessenger.of(context);
    mensaxeiro
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Eliminouse a fila da pauta.'),
          action: SnackBarAction(
            label: 'Desfacer',
            onPressed: () => _vm.desfacerEliminacion(indice, eliminado),
          ),
        ),
      );
  }

  Widget _tarxeta({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Future<void> _escollerDataDia(int indice) async {
    final actual =
        RevisionPauta.interpretarData(_analise.calendario[indice].data) ??
        DateTime.now();
    final nova = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecciona a data da dose',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (nova == null || !mounted) return;
    _vm.actualizarDia(indice, data: nova);
  }

  Future<void> _escollerProximaVisita() async {
    final ultimaData = _analise.calendario.isEmpty
        ? null
        : RevisionPauta.interpretarData(_analise.calendario.last.data);
    final actual =
        RevisionPauta.interpretarData(_analise.cabeceira.proximaVisita) ??
        ultimaData ??
        DateTime.now();
    final nova = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecciona a seguinte visita',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (nova == null || !mounted) return;
    _vm.actualizarProximaVisita(nova);
  }

  Future<void> _escollerDose(int indice) async {
    final actual = _analise.calendario[indice].dose ?? '';
    final controlador = TextEditingController(text: actual);
    const habituais = ['0', '1/4', '1/2', '3/4', '1', '1+1/4', '1+1/2'];
    final novaDose = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Corrixir a dose',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Escolle unha dose habitual ou escribe outro valor.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: habituais
                    .map(
                      (dose) => ActionChip(
                        label: Text(
                          dose,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: dose == actual
                            ? const Color(0xFFDDF3EF)
                            : null,
                        onPressed: () => Navigator.pop(context, dose),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controlador,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Outra dose',
                  hintText: 'Ex.: 1/2',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (valor) => Navigator.pop(context, valor.trim()),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, controlador.text.trim()),
                style: _estiloBotonPrincipal(_escuro),
                child: const Text('Aplicar dose'),
              ),
            ],
          ),
        ),
      ),
    );
    controlador.dispose();
    if (novaDose == null || !mounted) return;
    _vm.actualizarDia(indice, dose: novaDose);
  }

  void _revisarCorreccions() {
    if (!_vm.revisarCorreccions()) _mostrarErro(_vm.erro!);
  }

  void _confirmar() {
    final analise = _vm.confirmar();
    if (analise == null) {
      _mostrarErro(_vm.erro!);
      return;
    }
    Navigator.pop(context, analise);
  }

  void _mostrarErro(String mensaxe) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          content: Text(mensaxe),
        ),
      );

  bool _tenValor(String? valor) => valor?.trim().isNotEmpty == true;

  String _nomeDiaCurto(String nome) {
    final limpo = nome.trim();
    return limpo.length <= 3 ? limpo : limpo.substring(0, 3);
  }

  String _dataCurta(String valor) {
    final data = RevisionPauta.interpretarData(valor);
    if (data == null) return valor;
    const meses = [
      'Xan',
      'Feb',
      'Mar',
      'Abr',
      'Mai',
      'Xuñ',
      'Xul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dec',
    ];
    return '${data.day.toString().padLeft(2, '0')} ${meses[data.month - 1]}';
  }

  String _dataVisible(String valor) {
    final data = RevisionPauta.interpretarData(valor);
    return data == null ? valor : RevisionPauta.formatoVisita(data);
  }
}
