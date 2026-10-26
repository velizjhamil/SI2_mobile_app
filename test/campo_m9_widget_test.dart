import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/screens/campo_screens.dart';
import 'package:forest_microfinance/services/campo_hardware_service.dart';
import 'package:forest_microfinance/services/campo_service.dart';

class FakeM9CampoService extends CampoService {
  FichaCampo fichaResponse;
  EvaluacionCampoForm? lastSavedForm;
  int saveCalls = 0;
  int uploadCalls = 0;
  int deleteCalls = 0;
  String? lastDeletedFotoId;
  String? uploadError;
  String? deleteError;

  List<FotoEvaluacionCampo> uploadedPhotosResult = [
    const FotoEvaluacionCampo(id: 'foto1.jpg', url: null),
    const FotoEvaluacionCampo(
      id: 'foto2.jpg',
      url: 'https://storage.test/foto2.jpg',
    ),
  ];

  FakeM9CampoService({required this.fichaResponse});

  @override
  Future<CampoResult<FichaCampo>> getFichaCampo(
    int solicitudId, {
    http.Client? client,
  }) async {
    return CampoResult.success(fichaResponse);
  }

  @override
  Future<CampoResult<SolicitudResumenCampo>> guardarEvaluacion(
    int solicitudId,
    EvaluacionCampoForm form, {
    http.Client? client,
  }) async {
    saveCalls++;
    lastSavedForm = form;
    return const CampoResult.success(
      SolicitudResumenCampo(
        id: 3,
        numeroSolicitud: 'SOL-000002',
        fechaSolicitud: '2026-10-16',
        estado: 'PENDIENTE',
        socioNombre: 'Diego Vargas',
        socioCi: '8877004 SC',
        productoNombre: 'Demo',
        monedaSimbolo: 'Bs.',
        monto: '8000.00',
        plazoMeses: 10,
        destino: 'COMERCIO',
        canalOrigen: 'VENTANILLA',
        requiereEvaluacion: false,
      ),
    );
  }

  @override
  Future<CampoResult<List<FotoEvaluacionCampo>>> subirFotoEvaluacion(
    int solicitudId, {
    required List<int> bytes,
    required String filename,
    http.Client? client,
  }) async {
    uploadCalls++;
    if (uploadError != null) {
      return CampoResult.failure(uploadError);
    }
    return CampoResult.success(uploadedPhotosResult);
  }

  @override
  Future<CampoResult<List<FotoEvaluacionCampo>>> eliminarFotoEvaluacion(
    int solicitudId,
    String fotoId, {
    http.Client? client,
  }) async {
    deleteCalls++;
    lastDeletedFotoId = fotoId;
    if (deleteError != null) {
      return CampoResult.failure(deleteError);
    }
    return CampoResult.success(
      fichaResponse.evaluacion?.fotografias
              .where((f) => f.id != fotoId)
              .toList() ??
          [],
    );
  }
}

class FakeM9LocationService implements CampoLocationService {
  GpsResult result;
  int callCount = 0;

  FakeM9LocationService({required this.result});

  @override
  Future<GpsResult> getCurrentPosition() async {
    callCount++;
    return result;
  }
}

class FakeM9CameraService implements CampoCameraService {
  CameraPhotoResult result;
  int callCount = 0;

  FakeM9CameraService({required this.result});

  @override
  Future<CameraPhotoResult> capturePhoto(BuildContext context) async {
    callCount++;
    return result;
  }
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: child,
    ),
  );
}

FichaCampo _buildFicha({
  EvaluacionCampoExistente? evaluacion,
}) {
  return FichaCampo(
    solicitud: const FichaCampoSolicitud(
      id: 3,
      numeroSolicitud: 'SOL-000002',
      producto: 'Crédito Demo',
      monto: '8000.00',
      plazoMeses: 10,
      destino: 'COMERCIO',
      estado: 'PENDIENTE',
      canalOrigen: 'VENTANILLA',
      requiereEvaluacion: true,
    ),
    socio: const FichaCampoSocio(
      id: 8,
      nombreCompleto: 'Diego Vargas',
      ci: '8877004 SC',
    ),
    datosDeclarados: const FichaCampoDatosDeclarados(
      ingresoMensual: '6500.00',
      egresoMensual: '2500.00',
      actividadEconomica: 'Comercio',
      fuenteIngresos: 'DEPENDIENTE',
    ),
    evaluacion: evaluacion,
  );
}

void main() {
  group('CU-M9 Mobile Widget Tests (GPS and Photos)', () {
    testWidgets('Location capture success updates coordinates and accuracy and sends in save',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM9CampoService(
        fichaResponse: _buildFicha(
          evaluacion: const EvaluacionCampoExistente(
            id: 3,
            ingresoMensual: '6500.00',
            egresoMensual: '2500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Comercio',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 24,
            calificacionAsfi: 'A',
          ),
        ),
      );

      final locationService = FakeM9LocationService(
        result: const GpsResult.success(
          GpsPosition(
            latitude: -17.783300,
            longitude: -63.182100,
            accuracy: 4.8,
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 3,
            service: service,
            locationService: locationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gpsBtn = find.byKey(const Key('eval_capturar_gps_btn'));
      expect(gpsBtn, findsOneWidget);

      await tester.tap(gpsBtn);
      await tester.pumpAndSettle();

      expect(locationService.callCount, 1);
      expect(find.byKey(const Key('eval_coordenadas_text')), findsOneWidget);
      expect(find.text('Coordenadas: -17.783300,-63.182100'), findsOneWidget);
      expect(find.text('Precisión: ±4.8 m'), findsOneWidget);

      final saveBtn = find.byKey(const Key('eval_guardar_btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(service.saveCalls, 1);
      expect(service.lastSavedForm?.coordenadas, '-17.783300,-63.182100');
    });

    testWidgets('Location capture failure shows clear error message',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM9CampoService(
        fichaResponse: _buildFicha(
          evaluacion: const EvaluacionCampoExistente(
            id: 3,
            ingresoMensual: '6500.00',
            egresoMensual: '2500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Comercio',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 24,
            calificacionAsfi: 'A',
          ),
        ),
      );

      final locationService = FakeM9LocationService(
        result: const GpsResult.failure(
          'El servicio de ubicación (GPS) está desactivado. Por favor actívalelo.',
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 3,
            service: service,
            locationService: locationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gpsBtn = find.byKey(const Key('eval_capturar_gps_btn'));
      expect(gpsBtn, findsOneWidget);

      await tester.tap(gpsBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('eval_gps_error_text')), findsOneWidget);
      expect(
        find.textContaining('El servicio de ubicación (GPS) está desactivado'),
        findsOneWidget,
      );
    });

    testWidgets('Photos section is disabled with required evaluation hint when evaluation is null',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM9CampoService(
        fichaResponse: _buildFicha(evaluacion: null),
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 3,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('fotos_evaluacion_requerida_hint')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Debe guardar la evaluación socioeconómica antes de adjuntar fotografías'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('fotos_tomar_foto_btn')), findsNothing);
    });

    testWidgets('Photo grid displays placeholder tile for null url photos (legacy or unsigned)',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM9CampoService(
        fichaResponse: _buildFicha(
          evaluacion: const EvaluacionCampoExistente(
            id: 3,
            ingresoMensual: '6500.00',
            egresoMensual: '2500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Comercio',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 24,
            calificacionAsfi: 'A',
            fotografias: [
              FotoEvaluacionCampo(id: 'negocio_demo.jpg', url: null),
              FotoEvaluacionCampo(id: 'domicilio_demo.jpg', url: null),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 3,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foto_placeholder_tile_0')), findsOneWidget);
      expect(find.byKey(const Key('foto_placeholder_tile_1')), findsOneWidget);
      expect(find.text('Sin vista previa'), findsNWidgets(2));

      expect(find.byKey(const Key('fotos_error_text')), findsNothing);
    });

    testWidgets('Uploading photo with error shows error message',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM9CampoService(
        fichaResponse: _buildFicha(
          evaluacion: const EvaluacionCampoExistente(
            id: 3,
            ingresoMensual: '6500.00',
            egresoMensual: '2500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Comercio',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 24,
            calificacionAsfi: 'A',
            fotografias: [],
          ),
        ),
      );
      service.uploadError = 'Solo se permiten fotografías JPEG o PNG válidas';

      final cameraService = FakeM9CameraService(
        result: const CameraPhotoResult.success(
          bytes: [0x47, 0x49, 0x46],
          filename: 'invalido.gif',
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 3,
            service: service,
            cameraService: cameraService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tomarFotoBtn = find.byKey(const Key('fotos_tomar_foto_btn'));
      expect(tomarFotoBtn, findsOneWidget);
      await tester.tap(tomarFotoBtn);
      await tester.pumpAndSettle();

      expect(cameraService.callCount, 1);
      expect(service.uploadCalls, 1);
      expect(find.byKey(const Key('fotos_error_text')), findsOneWidget);
      expect(
        find.text('Solo se permiten fotografías JPEG o PNG válidas'),
        findsWidgets,
      );
    });

    testWidgets('Delete photo shows confirmation dialog and removes on confirm',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM9CampoService(
        fichaResponse: _buildFicha(
          evaluacion: const EvaluacionCampoExistente(
            id: 3,
            ingresoMensual: '6500.00',
            egresoMensual: '2500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Comercio',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 24,
            calificacionAsfi: 'A',
            fotografias: [
              FotoEvaluacionCampo(id: 'negocio_demo.jpg', url: null),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 3,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byKey(const Key('foto_delete_btn_0'));
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Eliminar fotografía'), findsOneWidget);
      expect(
        find.text('¿Está seguro de eliminar esta fotografía de respaldo?'),
        findsOneWidget,
      );

      final confirmBtn = find.byKey(const Key('dialog_confirm_delete_foto_btn'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(service.deleteCalls, 1);
      expect(service.lastDeletedFotoId, 'negocio_demo.jpg');
      expect(find.text('Fotografía eliminada exitosamente.'), findsOneWidget);
    });

    testWidgets('Photos max 5 limit hides take photo button',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM9CampoService(
        fichaResponse: _buildFicha(
          evaluacion: const EvaluacionCampoExistente(
            id: 3,
            ingresoMensual: '6500.00',
            egresoMensual: '2500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Comercio',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 24,
            calificacionAsfi: 'A',
            fotografias: [
              FotoEvaluacionCampo(id: '1.jpg', url: null),
              FotoEvaluacionCampo(id: '2.jpg', url: null),
              FotoEvaluacionCampo(id: '3.jpg', url: null),
              FotoEvaluacionCampo(id: '4.jpg', url: null),
              FotoEvaluacionCampo(id: '5.jpg', url: null),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 3,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fotografías de Respaldo (5/5)'), findsOneWidget);
      expect(find.byKey(const Key('fotos_tomar_foto_btn')), findsNothing);
    });
  });
}
