import 'package:flutter/foundation.dart';

import '../modelos/analise.dart';
import '../modelos/dose_dia.dart';
import '../modelos/revision_pauta.dart';

class RevisionPautaViewModel extends ChangeNotifier {
  RevisionPautaViewModel(AnaliseModel analise)
    : _analise = RevisionPauta.ordenar(analise),
      _ultimaRevisionConfirmada = RevisionPauta.ordenar(analise);

  AnaliseModel _analise;
  AnaliseModel _ultimaRevisionConfirmada;
  bool _editando = false;
  String? _erro;

  AnaliseModel get analise => _analise;
  bool get editando => _editando;
  String? get erro => _erro;

  void iniciarEdicion() {
    _ultimaRevisionConfirmada = _analise;
    _editando = true;
    _erro = null;
    notifyListeners();
  }

  void cancelarCambios() {
    _analise = _ultimaRevisionConfirmada;
    _editando = false;
    _erro = null;
    notifyListeners();
  }

  void actualizarDia(
    int indice, {
    DateTime? data,
    String? dose,
    bool? eControl,
  }) {
    _analise = RevisionPauta.actualizarDia(
      _analise,
      indice,
      data: data,
      dose: dose,
      eControl: eControl,
    );
    _erro = null;
    notifyListeners();
  }

  void actualizarProximaVisita(DateTime? data) {
    _analise = RevisionPauta.actualizarProximaVisita(_analise, data);
    _erro = null;
    notifyListeners();
  }

  DoseDiaModel eliminarDia(int indice) {
    final eliminado = _analise.calendario[indice];
    _analise = RevisionPauta.eliminarDia(_analise, indice);
    _erro = null;
    notifyListeners();
    return eliminado;
  }

  void desfacerEliminacion(int indice, DoseDiaModel eliminado) {
    final posicion = indice.clamp(0, _analise.calendario.length);
    _analise = RevisionPauta.inserirDia(_analise, posicion, eliminado);
    notifyListeners();
  }

  bool revisarCorreccions() {
    final erros = RevisionPauta.validar(_analise);
    if (erros.isNotEmpty) {
      _erro = erros.first;
      notifyListeners();
      return false;
    }
    _analise = RevisionPauta.ordenar(_analise);
    _ultimaRevisionConfirmada = _analise;
    _editando = false;
    _erro = null;
    notifyListeners();
    return true;
  }

  AnaliseModel? confirmar() {
    final erros = RevisionPauta.validar(_analise);
    if (erros.isNotEmpty) {
      _erro = erros.first;
      notifyListeners();
      return null;
    }
    _erro = null;
    return RevisionPauta.ordenar(_analise);
  }
}
