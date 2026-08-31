# Probas Flutter

A suite combina varias capas para non depender unicamente de tests unitarios:

- **Modelos e regras de dominio:** conversión do JSON do OCR, datas, doses,
  revisión da pauta e planificación de recordatorios.
- **ViewModels:** estados de carga, éxito e erro, concorrencia, preferencias,
  captura de informes e sincronización paciente–supervisor con dependencias
  substituídas por dobres deterministas.
- **Servizos:** API HTTP con `MockClient`, cifrado real AES-GCM e SQLite real
  en memoria mediante `sqflite_common_ffi`.
- **Widgets:** navegación, formularios, diálogos, estados baleiros/cargando,
  datos de calendario e progreso e adaptación a pantallas baixas.
- **Integración entre capas:** fluxos setup→QR, configuración→inicio,
  extracción→persistencia/notificación e reimportación dunha pauta en SQLite.

## Execución

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --coverage
```

O informe LCOV queda en `coverage/lcov.info`.

## Cobertura de referencia

Na execución do 21/08/2026 pasaron 114 tests e obtívose un 72,7 % global:

- modelos: 100 %;
- ViewModels: 81,6 %;
- widgets cargados pola suite: 78,7 %;
- API: 100 %;
- SQLite: 99,4 %;
- cifrado P2P: 99,3 %.

As chamadas nativas de Firebase Messaging e do plugin de notificacións locais
deben completarse con probas nun emulador/dispositivo, xa que o test runner de
escritorio non ofrece esas plataformas. As regras que deciden que mensaxes e
recordatorios crear están cubertas con dobres e tests unitarios.
