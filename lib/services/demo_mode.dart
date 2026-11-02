import 'dart:math' as math;
import 'dart:typed_data';

import '../models/campo_model.dart';
import '../models/cuenta_ahorro_model.dart';
import '../models/socio_model.dart';

/// Modo demo: datos simulados para presentar los casos de uso móviles
/// (CU-M6 cronograma de pagos y DPF, CU-M8 levantamiento socioeconómico,
/// CU-M9 fotos y GPS, CU-M10 precalificación y scoring) sin backend.
///
/// Los servicios ([CampoService], [SocioService], [CuentasService]) verifican
/// [DemoMode.enabled] al inicio de cada método y delegan aquí.
class DemoMode {
  DemoMode._();

  static bool enabled = false;
  static String? sessionRole;

  static final DemoCampoData campo = DemoCampoData();
  static final DemoSocioData socio = DemoSocioData();

  static void enter(String role) {
    enabled = true;
    sessionRole = role;
  }

  static void exit() {
    enabled = false;
    sessionRole = null;
  }
}

// ---------------------------------------------------------------------------
// Helpers compartidos
// ---------------------------------------------------------------------------

String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _addMonths(DateTime d, int months) =>
    DateTime(d.year, d.month + months, d.day);

double _parse(String? value) => double.tryParse((value ?? '').trim()) ?? 0;

/// Cuota mensual con amortización francesa.
double _cuotaFrances(double monto, double tasaAnualPct, int plazo) {
  if (plazo <= 0) return monto;
  final r = tasaAnualPct / 100 / 12;
  if (r <= 0) return monto / plazo;
  final f = math.pow(1 + r, plazo).toDouble();
  return monto * r * f / (f - 1);
}

// ---------------------------------------------------------------------------
// Datos demo del módulo de campo (CU-M8, CU-M9, CU-M10)
// ---------------------------------------------------------------------------

class DemoCampoData {
  static const _delay = Duration(milliseconds: 350);

  final Map<int, FichaCampo> _fichas = {};
  final Map<int, String> _fechaSolicitud = {};
  final Map<int, List<FotoEvaluacionCampo>> _fotos = {};
  final Map<String, Uint8List> _fotoBytes = {};
  final Map<int, PrecalificacionResultado> _scoringCache = {};
  final List<PrecalificacionResultado> prequalHistory = [];

  late List<SolicitudResumenCampo> _worklist;
  late final List<SocioPrecalificacion> socios;
  late final List<ProductoPrecalificacion> productos;

  int _fotoSeq = 0;

  DemoCampoData() {
    socios = const [
      SocioPrecalificacion(
          id: 7, ci: '4852147', nombre: 'María', apellido: 'Condori Mamani'),
      SocioPrecalificacion(
          id: 5, ci: '3852147', nombre: 'Juan', apellido: 'Pérez Quispe'),
      SocioPrecalificacion(
          id: 9, ci: '5221147', nombre: 'Rosa', apellido: 'Gutiérrez Flores'),
      SocioPrecalificacion(
          id: 12, ci: '6214589', nombre: 'Carlos', apellido: 'Choque Huanca'),
      SocioPrecalificacion(
          id: 15, ci: '7055123', nombre: 'Ana', apellido: 'Mamani Apaza'),
      SocioPrecalificacion(
          id: 18, ci: '5821047', nombre: 'Luis', apellido: 'Flores Vargas'),
    ];
    productos = const [
      ProductoPrecalificacion(
        id: 1,
        codigo: 'PEQ',
        nombre: 'Crédito Emprendedor',
        monedaSimbolo: 'Bs.',
        montoMin: '5000.00',
        montoMax: '50000.00',
        plazoMinMeses: 6,
        plazoMaxMeses: 36,
        tasaInteresAnual: '12.50',
        requiereGarantia: false,
      ),
      ProductoPrecalificacion(
        id: 2,
        codigo: 'AGR',
        nombre: 'Crédito Agrícola',
        monedaSimbolo: 'Bs.',
        montoMin: '10000.00',
        montoMax: '100000.00',
        plazoMinMeses: 12,
        plazoMaxMeses: 48,
        tasaInteresAnual: '11.80',
        requiereGarantia: true,
      ),
      ProductoPrecalificacion(
        id: 3,
        codigo: 'VIV',
        nombre: 'Crédito Vivienda',
        monedaSimbolo: 'Bs.',
        montoMin: '20000.00',
        montoMax: '200000.00',
        plazoMinMeses: 24,
        plazoMaxMeses: 120,
        tasaInteresAnual: '9.50',
        requiereGarantia: true,
      ),
    ];

    _fichas[118] = const FichaCampo(
      solicitud: FichaCampoSolicitud(
        id: 118,
        numeroSolicitud: 'SOL-2026-0118',
        producto: 'Crédito Emprendedor',
        monto: '25000.00',
        plazoMeses: 24,
        destino: 'Capital de trabajo',
        destinoDetalle: 'Compra de mercadería para tienda de abarrotes',
        estado: 'EN_EVALUACION',
        canalOrigen: 'MOVIL',
        requiereEvaluacion: true,
      ),
      socio: FichaCampoSocio(
        id: 7,
        nombreCompleto: 'María Condori Mamani',
        ci: '4852147',
        telefono: '76543210',
        direccion: 'Av. Busch #123, El Alto',
      ),
      datosDeclarados: FichaCampoDatosDeclarados(
        ingresoMensual: '3500.00',
        egresoMensual: '2200.00',
        actividadEconomica: 'Comercio — tienda de abarrotes',
        fuenteIngresos: 'INDEPENDIENTE',
      ),
    );
    _fechaSolicitud[118] = '2026-10-24';

    _fichas[105] = const FichaCampo(
      solicitud: FichaCampoSolicitud(
        id: 105,
        numeroSolicitud: 'SOL-2026-0105',
        producto: 'Crédito Agrícola',
        monto: '40000.00',
        plazoMeses: 36,
        destino: 'Inversión agrícola',
        destinoDetalle: 'Compra de maquinaria agrícola',
        estado: 'EN_EVALUACION',
        canalOrigen: 'VENTANILLA',
        requiereEvaluacion: true,
      ),
      socio: FichaCampoSocio(
        id: 5,
        nombreCompleto: 'Juan Pérez Quispe',
        ci: '3852147',
        telefono: '70012345',
        direccion: 'Calle Warnes #45, Montero',
      ),
      datosDeclarados: FichaCampoDatosDeclarados(
        ingresoMensual: '6000.00',
        egresoMensual: '3500.00',
        actividadEconomica: 'Agricultura — producción de soya',
        fuenteIngresos: 'INDEPENDIENTE',
      ),
    );
    _fechaSolicitud[105] = '2026-10-18';

    _fichas[91] = const FichaCampo(
      solicitud: FichaCampoSolicitud(
        id: 91,
        numeroSolicitud: 'SOL-2026-0091',
        producto: 'Crédito Emprendedor',
        monto: '12000.00',
        plazoMeses: 12,
        destino: 'Capital de trabajo',
        destinoDetalle: 'Ampliación de tienda de ropa',
        estado: 'EN_EVALUACION',
        canalOrigen: 'MOVIL',
        requiereEvaluacion: true,
      ),
      socio: FichaCampoSocio(
        id: 9,
        nombreCompleto: 'Rosa Gutiérrez Flores',
        ci: '5221147',
        telefono: '78945612',
        direccion: 'Av. 6 de Agosto #220, La Paz',
      ),
      evaluacion: EvaluacionCampoExistente(
        id: 41,
        ingresoMensual: '4200.00',
        egresoMensual: '2600.00',
        cuotaDeudasMensual: '350.00',
        actividadEconomica: 'Comercio — venta de ropa',
        fuenteIngresos: 'MIXTO',
        antiguedadLaboralMeses: 18,
        calificacionAsfi: 'A',
        coordenadas: '-16.500000, -68.150000',
        observaciones:
            'Negocio estable con más de un año de funcionamiento. Local propio.',
        fecha: '2026-10-18',
        fotografias: [
          FotoEvaluacionCampo(id: 'demo-foto-rosa-1'),
        ],
      ),
    );
    _fechaSolicitud[91] = '2026-10-05';

    _worklist = _fichas.values
        .map((ficha) => _resumen(ficha))
        .toList()
        .reversed
        .toList();

    _scoringCache[91] = _compute(_inputDesdeFicha(_fichas[91]!));
  }

  SolicitudResumenCampo _resumen(FichaCampo ficha) {
    final cache = _scoringCache[ficha.solicitud.id];
    return SolicitudResumenCampo(
      id: ficha.solicitud.id,
      numeroSolicitud: ficha.solicitud.numeroSolicitud,
      fechaSolicitud: _fechaSolicitud[ficha.solicitud.id] ?? '2026-10-20',
      estado: ficha.solicitud.estado,
      socioNombre: ficha.socio.nombreCompleto,
      socioCi: ficha.socio.ci,
      productoNombre: ficha.solicitud.producto,
      monedaSimbolo: 'Bs.',
      monto: ficha.solicitud.monto,
      plazoMeses: ficha.solicitud.plazoMeses,
      destino: ficha.solicitud.destino,
      destinoDetalle: ficha.solicitud.destinoDetalle,
      canalOrigen: ficha.solicitud.canalOrigen,
      requiereEvaluacion: ficha.solicitud.requiereEvaluacion,
      evaluacion: ficha.evaluacion,
      ultimaEvaluacionDictamen: cache?.dictamen,
      ultimaEvaluacionScore: cache?.score,
    );
  }

  Future<List<SolicitudResumenCampo>> getWorklist({
    bool requiereEvaluacion = true,
    String? canalOrigen,
  }) async {
    await Future<void>.delayed(_delay);
    return _worklist
        .where((i) => !requiereEvaluacion || i.requiereEvaluacion)
        .where((i) =>
            canalOrigen == null ||
            canalOrigen.isEmpty ||
            canalOrigen == 'TODOS' ||
            i.canalOrigen == canalOrigen)
        .toList();
  }

  Future<FichaCampo?> getFichaCampo(int solicitudId) async {
    await Future<void>.delayed(_delay);
    return _fichas[solicitudId];
  }

  Future<SolicitudResumenCampo?> guardarEvaluacion(
    int solicitudId,
    EvaluacionCampoForm form,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final ficha = _fichas[solicitudId];
    if (ficha == null) return null;
    final previa = ficha.evaluacion;
    final evaluacion = EvaluacionCampoExistente(
      id: previa?.id,
      ingresoMensual: form.ingresoMensual,
      egresoMensual: form.egresoMensual,
      cuotaDeudasMensual: form.cuotaDeudasMensual,
      capacidadPago: previa?.capacidadPago,
      actividadEconomica: form.actividadEconomica,
      fuenteIngresos: form.fuenteIngresos,
      antiguedadLaboralMeses: form.antiguedadLaboralMeses,
      calificacionAsfi: form.calificacionAsfi,
      coordenadas: form.coordenadas,
      observaciones: form.observaciones,
      fecha: _fmt(DateTime.now()),
      fotografias: _fotos[solicitudId] ?? previa?.fotografias ?? const [],
    );
    final nueva = FichaCampo(
      solicitud: ficha.solicitud,
      socio: ficha.socio,
      datosDeclarados: ficha.datosDeclarados,
      evaluacion: evaluacion,
      catalogos: ficha.catalogos,
    );
    _fichas[solicitudId] = nueva;
    final item = _resumen(nueva);
    final idx = _worklist.indexWhere((i) => i.id == solicitudId);
    if (idx >= 0) _worklist[idx] = item;
    return item;
  }

  Future<ScoringResultado?> calcularScoring(int solicitudId) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final ficha = _fichas[solicitudId];
    if (ficha == null) return null;
    final resultado = _compute(_inputDesdeFicha(ficha));
    _scoringCache[solicitudId] = resultado;
    return ScoringResultado(
      id: solicitudId,
      solicitudId: solicitudId,
      score: resultado.score,
      dictamen: resultado.dictamen,
      factores: resultado.factores,
      explicacion: resultado.explicacion,
      cuotaEstimada: resultado.cuotaEstimada,
      relacionCuotaIngreso: resultado.relacionCuotaIngreso,
    );
  }

  Future<List<SocioPrecalificacion>> getSociosActivos() async {
    await Future<void>.delayed(_delay);
    return List.of(socios);
  }

  Future<List<ProductoPrecalificacion>> getProductosActivos() async {
    await Future<void>.delayed(_delay);
    return List.of(productos);
  }

  Future<PrecalificacionResultado?> precalificar(
    PrecalificacionForm form,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    SocioPrecalificacion? socio;
    for (final s in socios) {
      if (s.id == form.socioId) {
        socio = s;
        break;
      }
    }
    ProductoPrecalificacion? producto;
    for (final p in productos) {
      if (p.id == form.productoId) {
        producto = p;
        break;
      }
    }
    if (socio == null || producto == null) return null;

    final resultado = _compute(_ScoringInput(
      solicitudId: 0,
      monto: _parse(form.monto),
      tasaAnualPct: _parse(producto.tasaInteresAnual),
      plazo: form.plazoMeses,
      ingreso: _parse(form.ingresoMensual),
      egreso: _parse(form.egresoMensual),
      deudas: _parse(form.cuotaDeudasMensual),
      antiguedad: form.antiguedadLaboralMeses,
      calif: (form.calificacionAsfi ?? '').trim().isEmpty
          ? 'B'
          : form.calificacionAsfi!.trim(),
      fuente: (form.fuenteIngresos ?? '').trim().isEmpty
          ? 'INDEPENDIENTE'
          : form.fuenteIngresos!.trim(),
      requiereGarantia: producto.requiereGarantia,
      montoMax: producto.montoMaxDouble,
      plazoMin: producto.plazoMinMeses,
      socioId: socio.id,
      socioNombre: socio.nombreCompleto,
      socioCi: socio.ci,
      productoId: producto.id,
      productoNombre: producto.nombre,
    ));
    prequalHistory.insert(0, resultado);
    return resultado;
  }

  Future<List<FotoEvaluacionCampo>> getFotosEvaluacion(
    int solicitudId,
  ) async {
    await Future<void>.delayed(_delay);
    return List.of(_fotos[solicitudId] ?? const []);
  }

  Future<List<FotoEvaluacionCampo>> subirFotoEvaluacion(
    int solicitudId,
    Uint8List bytes,
    String filename,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final list = _fotos.putIfAbsent(solicitudId, () => []);
    if (list.length >= 5) return List.of(list);
    final id = 'demo-foto-${++_fotoSeq}-$solicitudId';
    _fotoBytes[id] = bytes;
    list.add(FotoEvaluacionCampo(id: id, url: null));
    return List.of(list);
  }

  Future<List<FotoEvaluacionCampo>> eliminarFotoEvaluacion(
    int solicitudId,
    String fotoId,
  ) async {
    await Future<void>.delayed(_delay);
    final list = _fotos[solicitudId];
    if (list != null) {
      list.removeWhere((f) => f.id == fotoId);
      _fotoBytes.remove(fotoId);
    }
    return List.of(list ?? const []);
  }

  Uint8List? fotoBytes(String fotoId) => _fotoBytes[fotoId];

  _ScoringInput _inputDesdeFicha(FichaCampo ficha) {
    final eval = ficha.evaluacion;
    final declared = ficha.datosDeclarados;
    final producto = _productoPorNombre(ficha.solicitud.producto);
    final calif = (eval?.calificacionAsfi ?? '').trim();
    final fuente = (eval?.fuenteIngresos ?? '').trim();
    return _ScoringInput(
      solicitudId: ficha.solicitud.id,
      monto: _parse(ficha.solicitud.monto),
      tasaAnualPct:
          producto != null ? _parse(producto.tasaInteresAnual) : 12.5,
      plazo: ficha.solicitud.plazoMeses,
      ingreso: _parse(eval?.ingresoMensual ?? declared?.ingresoMensual),
      egreso: _parse(eval?.egresoMensual ?? declared?.egresoMensual),
      deudas: _parse(eval?.cuotaDeudasMensual),
      antiguedad: eval?.antiguedadLaboralMeses ?? 0,
      calif: calif.isEmpty ? 'B' : calif,
      fuente: fuente.isEmpty
          ? (declared?.fuenteIngresos ?? 'INDEPENDIENTE')
          : fuente,
      requiereGarantia: producto?.requiereGarantia ?? false,
      montoMax: producto?.montoMaxDouble ?? 50000,
      plazoMin: producto?.plazoMinMeses ?? 6,
      socioId: ficha.socio.id,
      socioNombre: ficha.socio.nombreCompleto,
      socioCi: ficha.socio.ci,
      productoId: producto?.id,
      productoNombre: ficha.solicitud.producto,
    );
  }

  ProductoPrecalificacion? _productoPorNombre(String nombre) {
    for (final p in productos) {
      if (p.nombre == nombre) return p;
    }
    return null;
  }
}

class _ScoringInput {
  final int solicitudId;
  final double monto;
  final double tasaAnualPct;
  final int plazo;
  final double ingreso;
  final double egreso;
  final double deudas;
  final int antiguedad;
  final String calif;
  final String fuente;
  final bool requiereGarantia;
  final double montoMax;
  final int plazoMin;
  final int? socioId;
  final String? socioNombre;
  final String? socioCi;
  final int? productoId;
  final String? productoNombre;

  const _ScoringInput({
    required this.solicitudId,
    required this.monto,
    required this.tasaAnualPct,
    required this.plazo,
    required this.ingreso,
    required this.egreso,
    required this.deudas,
    required this.antiguedad,
    required this.calif,
    required this.fuente,
    required this.requiereGarantia,
    required this.montoMax,
    required this.plazoMin,
    this.socioId,
    this.socioNombre,
    this.socioCi,
    this.productoId,
    this.productoNombre,
  });
}

/// Motor de scoring simulado (CU-M10 / CU-W23).
///
/// Reglas: knockouts duros (ASFI E/F, capacidad de pago > 55%) rechazan;
/// monto con garantía o antigüedad corta pasan a revisión manual; el score
/// pondera ASFI, relación cuota/ingreso, antigüedad, fuente y egresos.
PrecalificacionResultado _compute(_ScoringInput i) {
  final cuota = _cuotaFrances(i.monto, i.tasaAnualPct, i.plazo);
  final disponible = i.ingreso - i.egreso - i.deudas;
  final rci = disponible > 0 ? cuota / disponible : double.infinity;
  final calif = (i.calif.trim().isEmpty ? 'B' : i.calif.trim()).toUpperCase();
  final fuente = i.fuente.trim().isEmpty ? 'INDEPENDIENTE' : i.fuente.trim();

  final knockouts = <ScoringKnockout>[];
  String? knockoutDictamen;

  if (calif == 'E' || calif == 'F') {
    knockouts.add(const ScoringKnockout(
      codigo: 'ASFI_CRITICO',
      descripcion:
          'Calificación ASFI insuficiente (E/F): mora o castigo en el sistema financiero.',
      efecto: 'RECHAZADO',
    ));
    knockoutDictamen = 'RECHAZADO';
  }
  if (!rci.isFinite || rci > 0.55) {
    knockouts.add(ScoringKnockout(
      codigo: 'CAPACIDAD_PAGO',
      descripcion: !rci.isFinite
          ? 'El ingreso disponible no cubre la cuota estimada.'
          : 'La cuota estimada supera el 55% del ingreso disponible '
              '(${(rci * 100).toStringAsFixed(1)}%).',
      efecto: 'RECHAZADO',
    ));
    knockoutDictamen ??= 'RECHAZADO';
  }
  if (i.requiereGarantia && i.monto > i.montoMax * 0.6) {
    knockouts.add(const ScoringKnockout(
      codigo: 'GARANTIA_INSUFICIENTE',
      descripcion:
          'El monto supera el 60% del límite del producto con garantía; '
          'requiere avalúo.',
      efecto: 'REVISION_MANUAL',
    ));
    knockoutDictamen ??= 'REVISION_MANUAL';
  }
  if (i.antiguedad < 6 && i.monto > 15000) {
    knockouts.add(const ScoringKnockout(
      codigo: 'ANTIGUEDAD_CORTA',
      descripcion:
          'Antigüedad laboral menor a 6 meses con monto superior a Bs 15.000.',
      efecto: 'REVISION_MANUAL',
    ));
    knockoutDictamen ??= 'REVISION_MANUAL';
  }

  final asfiPts = {'A': 120, 'B': 100, 'C': 80, 'D': 50}[calif] ?? 0;
  final rciPts = !rci.isFinite
      ? 0
      : rci <= 0.25
          ? 180
          : rci <= 0.35
              ? 140
              : rci <= 0.45
                  ? 90
                  : 40;
  final antigPts = math.min(i.antiguedad * 3, 90);
  final fuentePts = {
    'DEPENDIENTE': 60,
    'MIXTO': 50,
    'INDEPENDIENTE': 40,
  }[fuente.toUpperCase()] ??
      40;
  final cargaEgresos = i.ingreso > 0 ? i.egreso / i.ingreso : 1.0;
  final egresoPts = cargaEgresos <= 0.5
      ? 80
      : cargaEgresos <= 0.7
          ? 55
          : 25;
  final montoPts = i.monto <= i.montoMax * 0.8 ? 50 : 30;
  final plazoPts = i.plazo >= i.plazoMin + 6 ? 40 : 25;
  const basePts = 380;
  final score = math.min(
    1000,
    basePts + asfiPts + rciPts + antigPts + fuentePts + egresoPts + montoPts + plazoPts,
  );

  final dictamen = knockoutDictamen ??
      (score >= 700
          ? 'APROBADO'
          : score >= 550
              ? 'REVISION_MANUAL'
              : 'RECHAZADO');

  String fmtRci() =>
      !rci.isFinite ? 'N/A' : '${(rci * 100).toStringAsFixed(1)}%';

  final factores = <ScoringFactor>[
    const ScoringFactor(
      codigo: 'BASE',
      descripcion: 'Puntaje base del modelo',
      puntos: basePts,
      maximo: 380,
      valor: '$basePts',
      motivo: 'Base uniforme del modelo de scoring.',
    ),
    ScoringFactor(
      codigo: 'ASFI',
      descripcion: 'Calificación ASFI del socio',
      puntos: asfiPts,
      maximo: 120,
      valor: calif,
      motivo: asfiPts >= 100
          ? 'Sin observaciones relevantes en el buró.'
          : 'Historial crediticio con observaciones.',
    ),
    ScoringFactor(
      codigo: 'RCI',
      descripcion: 'Relación cuota / ingreso disponible',
      puntos: rciPts,
      maximo: 180,
      valor: fmtRci(),
      motivo: rciPts >= 140
          ? 'Carga financiera holgada.'
          : 'Carga financiera elevada.',
    ),
    ScoringFactor(
      codigo: 'ANTIGUEDAD',
      descripcion: 'Antigüedad laboral',
      puntos: antigPts,
      maximo: 90,
      valor: '${i.antiguedad} meses',
      motivo: antigPts >= 60
          ? 'Estabilidad laboral comprobada.'
          : 'Historial laboral corto.',
    ),
    ScoringFactor(
      codigo: 'FUENTE_INGRESOS',
      descripcion: 'Fuente de ingresos',
      puntos: fuentePts,
      maximo: 60,
      valor: fuente,
      motivo: 'Ingresos verificados según fuente declarada.',
    ),
    ScoringFactor(
      codigo: 'CARGA_EGRESOS',
      descripcion: 'Carga de egresos sobre ingresos',
      puntos: egresoPts,
      maximo: 80,
      valor: '${(cargaEgresos * 100).toStringAsFixed(0)}%',
      motivo: egresoPts >= 80
          ? 'Margen operativo saludable.'
          : 'Margen operativo ajustado.',
    ),
    ScoringFactor(
      codigo: 'MONTO_PRODUCTO',
      descripcion: 'Monto vs límite del producto',
      puntos: montoPts,
      maximo: 50,
      valor: i.monto.toStringAsFixed(0),
      motivo: montoPts >= 50
          ? 'Monto dentro del rango cómodo del producto.'
          : 'Monto cercano al límite del producto.',
    ),
    ScoringFactor(
      codigo: 'PLAZO',
      descripcion: 'Plazo solicitado',
      puntos: plazoPts,
      maximo: 40,
      valor: '${i.plazo} meses',
      motivo: plazoPts >= 40
          ? 'Plazo consistente con el destino.'
          : 'Plazo corto para el monto solicitado.',
    ),
  ];

  final probabilidadMora =
      score >= 700 ? '0.12' : score >= 550 ? '0.28' : '0.55';
  final nivelRiesgo =
      score >= 700 ? 'BAJO' : score >= 550 ? 'MEDIO' : 'ALTO';

  final motivoKnockout =
      knockouts.isEmpty ? '' : knockouts.map((k) => k.descripcion).join(' ');
  final explicacion = dictamen == 'APROBADO'
      ? 'El socio cumple los umbrales de capacidad de pago '
          '(RCI ${fmtRci()}) y su perfil de riesgo es ${nivelRiesgo.toLowerCase()}. '
          'Sin observaciones críticas.'
      : dictamen == 'REVISION_MANUAL'
          ? 'El perfil requiere revisión de un analista de crédito antes de '
              'aprobar: $motivoKnockout'
          : 'El perfil no cumple los criterios mínimos del motor de scoring: '
              '$motivoKnockout';

  return PrecalificacionResultado(
    precalificacion: true,
    score: score,
    dictamen: dictamen,
    factores: factores,
    knockouts: knockouts,
    explicacion: explicacion,
    cuotaEstimada: cuota.toStringAsFixed(2),
    relacionCuotaIngreso: fmtRci(),
    probabilidadMora: probabilidadMora,
    nivelRiesgo: nivelRiesgo,
    versionModelo: 'SCORING-DEMO-1.0',
    socioId: i.socioId,
    socioNombre: i.socioNombre,
    socioCi: i.socioCi,
    productoId: i.productoId,
    productoNombre: i.productoNombre,
    clientId: 'demo-precal-${DateTime.now().millisecondsSinceEpoch}',
  );
}

// ---------------------------------------------------------------------------
// Datos demo del módulo socio (CU-M6 cronograma de pagos y DPF)
// ---------------------------------------------------------------------------

class DemoSocioData {
  static const _delay = Duration(milliseconds: 350);

  late List<CuentaAhorro> _cuentas;
  late SocioPerfil _perfil;

  DemoSocioData() {
    _cuentas = [
      const CuentaAhorro(
        id: 1,
        accountNumber: 'CA-1001-4852',
        productType: 'CAJA DE AHORRO',
        availableBalance: 8450.50,
        blockedBalance: 0,
        status: 'ACTIVA',
        registrationDate: '2022-03-15',
        socioId: 7,
        currency: Moneda(
            id: 1, currencyCode: 'BOB', name: 'Boliviano', symbol: 'Bs'),
      ),
      const CuentaAhorro(
        id: 2,
        accountNumber: 'CA-1002-4852',
        productType: 'AHORRO PROGRAMADO',
        availableBalance: 3200.00,
        blockedBalance: 0,
        status: 'ACTIVA',
        registrationDate: '2023-08-02',
        socioId: 7,
        currency: Moneda(
            id: 1, currencyCode: 'BOB', name: 'Boliviano', symbol: 'Bs'),
      ),
    ];
    _perfil = const SocioPerfil(
      id: 7,
      codigoSocio: 'SOC-0007',
      ci: '4852147',
      nombre: 'María',
      apellido: 'Condori Mamani',
      nombreCompleto: 'María Condori Mamani',
      direccion: 'Av. Busch #123, El Alto',
      telefono: '76543210',
      correo: 'socio@test.com',
      estado: 'ACTIVO',
      categoria: 'SOCIO',
      fechaRegistro: '2022-03-15',
      cooperativaId: 1,
    );
  }

  Future<List<CuentaAhorro>> cuentas() async {
    await Future<void>.delayed(_delay);
    return List.of(_cuentas);
  }

  Future<SocioPerfil> perfil() async {
    await Future<void>.delayed(_delay);
    return _perfil;
  }

  Future<SocioPerfil> updatePerfil({
    String? direccion,
    String? telefono,
    String? correo,
  }) async {
    await Future<void>.delayed(_delay);
    _perfil = _perfil.copyWith(
      direccion: direccion,
      telefono: telefono,
      correo: correo,
    );
    return _perfil;
  }

  Future<Map<String, dynamic>> deposit({
    required int accountId,
    required double amount,
    String? concept,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final idx = _cuentas.indexWhere((c) => c.id == accountId);
    if (idx >= 0) {
      final c = _cuentas[idx];
      _cuentas[idx] = CuentaAhorro(
        id: c.id,
        accountNumber: c.accountNumber,
        productType: c.productType,
        availableBalance: c.availableBalance + amount,
        blockedBalance: c.blockedBalance,
        status: c.status,
        registrationDate: c.registrationDate,
        socioId: c.socioId,
        currency: c.currency,
      );
    }
    return {
      'id': 9000,
      'monto': amount.toStringAsFixed(2),
      'concepto': concept,
      'fecha': _fmt(DateTime.now()),
    };
  }

  Future<ExtractoCuenta> extracto(
    int accountId, {
    String? from,
    String? to,
  }) async {
    await Future<void>.delayed(_delay);
    final cuenta = _cuentas.firstWhere(
      (c) => c.id == accountId,
      orElse: () => _cuentas.first,
    );
    return ExtractoCuenta(
      account: {
        'id': cuenta.id,
        'numero': cuenta.accountNumber,
        'tipo': cuenta.productType,
        'moneda': 'BOB',
      },
      from: from ?? '2026-10-01',
      to: to ?? '2026-10-31',
      openingBalance: '7840.20',
      totalCredits: '1500.00',
      totalDebits: '889.70',
      closingBalance: cuenta.availableBalance.toStringAsFixed(2),
      total: 4,
      movements: [
        const ExtractoMovimiento(
          transactionId: 1001,
          date: '2026-10-03',
          type: 'DEPOSITO',
          description: 'Depósito en ventanilla',
          channel: 'VENTANILLA',
          amount: '500.00',
          direction: 'CREDITO',
          resultingBalance: '8340.20',
          receiptId: 5001,
        ),
        const ExtractoMovimiento(
          transactionId: 1002,
          date: '2026-10-07',
          type: 'RETIRO',
          description: 'Retiro en cajero automático',
          channel: 'ATM',
          amount: '300.00',
          direction: 'DEBITO',
          resultingBalance: '8040.20',
          receiptId: null,
        ),
        const ExtractoMovimiento(
          transactionId: 1003,
          date: '2026-10-12',
          type: 'PAGO_CREDITO',
          description: 'Pago de cuota crédito CRE-2024-0032',
          channel: 'MOVIL',
          amount: '589.70',
          direction: 'DEBITO',
          resultingBalance: '7450.50',
          receiptId: 5002,
        ),
        ExtractoMovimiento(
          transactionId: 1004,
          date: '2026-10-18',
          type: 'DEPOSITO',
          description: 'Transferencia recibida',
          channel: 'MOVIL',
          amount: '1000.00',
          direction: 'CREDITO',
          resultingBalance: cuenta.availableBalance.toStringAsFixed(2),
          receiptId: 5003,
        ),
      ],
    );
  }

  Future<List<SocioCredit>> credits() async {
    await Future<void>.delayed(_delay);
    final sched1 = _buildCreditSchedule(
      creditId: 1,
      numero: 'CRE-2024-0032',
      monto: 25000,
      tasaPct: 12.5,
      plazo: 24,
      firstDue: DateTime(2025, 12, 15),
      pagadas: 10,
    );
    CreditScheduleItem? primeraPendiente;
    for (final c in sched1.installments) {
      if (!c.isPaid) {
        primeraPendiente = c;
        break;
      }
    }

    return [
      SocioCredit(
        id: 1,
        number: 'CRE-2024-0032',
        product: 'Crédito Emprendedor',
        currency: 'BOB',
        disbursedAmount: '25000.00',
        outstandingBalance: sched1.installments[9].capitalBalance,
        status: 'VIGENTE',
        nextInstallment: primeraPendiente == null
            ? null
            : CreditInstallment(
                number: primeraPendiente.number,
                dueDate: primeraPendiente.dueDate,
                totalAmount: primeraPendiente.totalAmount,
              ),
      ),
      const SocioCredit(
        id: 2,
        number: 'CRE-2023-0018',
        product: 'Crédito Agrícola',
        currency: 'BOB',
        disbursedAmount: '40000.00',
        outstandingBalance: '0.00',
        status: 'CANCELADO',
        nextInstallment: null,
      ),
    ];
  }

  Future<CreditSchedule?> creditSchedule(int creditId) async {
    await Future<void>.delayed(_delay);
    if (creditId == 1) {
      return _buildCreditSchedule(
        creditId: 1,
        numero: 'CRE-2024-0032',
        monto: 25000,
        tasaPct: 12.5,
        plazo: 24,
        firstDue: DateTime(2025, 12, 15),
        pagadas: 10,
      );
    }
    if (creditId == 2) {
      return _buildCreditSchedule(
        creditId: 2,
        numero: 'CRE-2023-0018',
        monto: 40000,
        tasaPct: 11.8,
        plazo: 36,
        firstDue: DateTime(2023, 6, 10),
        pagadas: 36,
      );
    }
    return null;
  }

  CreditSchedule _buildCreditSchedule({
    required int creditId,
    required String numero,
    required double monto,
    required double tasaPct,
    required int plazo,
    required DateTime firstDue,
    required int pagadas,
  }) {
    final cuota = _cuotaFrances(monto, tasaPct, plazo);
    final r = tasaPct / 100 / 12;
    var saldo = monto;
    final items = <CreditScheduleItem>[];
    final hoy = DateTime.now();
    for (var n = 1; n <= plazo; n++) {
      final interes = saldo * r;
      final capital = cuota - interes;
      saldo = math.max(0, saldo - capital);
      final due = _addMonths(firstDue, n - 1);
      final isPaid = n <= pagadas;
      final status = isPaid
          ? 'PAGADA'
          : (n == pagadas + 1 && hoy.isAfter(due))
              ? 'VENCIDA'
              : 'PENDIENTE';
      items.add(CreditScheduleItem(
        number: n,
        dueDate: _fmt(due),
        capital: capital.toStringAsFixed(2),
        interest: interes.toStringAsFixed(2),
        insurance: '0.00',
        mora: '0.00',
        totalAmount: cuota.toStringAsFixed(2),
        capitalBalance: saldo.toStringAsFixed(2),
        status: status,
        paymentDate: isPaid ? _fmt(due) : '',
      ));
    }
    final saldoPendiente = items[pagadas - 1].capitalBalance;
    final estado = saldoPendiente == '0.00' ? 'CANCELADO' : 'VIGENTE';
    return CreditSchedule(
      credit: {
        'id': creditId,
        'numero_credito': numero,
        'producto': creditId == 1 ? 'Crédito Emprendedor' : 'Crédito Agrícola',
        'moneda': 'BOB',
        'monto_desembolsado': monto.toStringAsFixed(2),
        'saldo_pendiente': saldoPendiente,
        'estado': estado,
        'tasa_interes': '$tasaPct%',
        'plazo_meses': plazo,
        'cuota_estimada': cuota.toStringAsFixed(2),
      },
      installments: items,
    );
  }

  Future<Map<String, dynamic>> debt(int creditId) async {
    await Future<void>.delayed(_delay);
    if (creditId == 1) {
      return {
        'capital_pendiente': '11250.00',
        'interes_pendiente': '117.19',
        'total': '11367.19',
        'cuota_mensual': '1210.55',
      };
    }
    return {
      'capital_pendiente': '0.00',
      'interes_pendiente': '0.00',
      'total': '0.00',
      'cuota_mensual': '0.00',
    };
  }

  Future<List<Map<String, dynamic>>> paymentHistory(int creditId) async {
    await Future<void>.delayed(_delay);
    return const [];
  }

  Future<List<Dpf>> dpfs() async {
    await Future<void>.delayed(_delay);
    final dpf1 = Dpf(
      id: 1,
      certificateNumber: 'DPF-2026-0041',
      currency: 'BOB',
      amount: '15000.00',
      interestRate: '5.80%',
      termDays: 360,
      openingDate: '2026-01-10',
      maturityDate: '2027-01-05',
      status: 'VIGENTE',
      paymentFrequency: 'MENSUAL',
      schedule: _dpfSchedule(
        monto: 15000,
        tasaPct: 5.8,
        opening: DateTime(2026, 1, 10),
        count: 12,
      ),
    );
    final dpf2 = Dpf(
      id: 2,
      certificateNumber: 'DPF-2025-0017',
      currency: 'BOB',
      amount: '8000.00',
      interestRate: '5.20%',
      termDays: 180,
      openingDate: '2025-11-02',
      maturityDate: '2026-05-01',
      status: 'VENCIDO',
      paymentFrequency: 'MENSUAL',
      schedule: _dpfSchedule(
        monto: 8000,
        tasaPct: 5.2,
        opening: DateTime(2025, 11, 2),
        count: 6,
      ),
    );
    return [dpf1, dpf2];
  }

  Future<Dpf?> dpfDetail(int dpfId) async {
    await Future<void>.delayed(_delay);
    final lista = await dpfs();
    for (final dpf in lista) {
      if (dpf.id == dpfId) return dpf;
    }
    return null;
  }

  List<DpfScheduleItem> _dpfSchedule({
    required double monto,
    required double tasaPct,
    required DateTime opening,
    required int count,
  }) {
    final bruto = monto * tasaPct / 100 / 12;
    final retencion = bruto * 0.125;
    final neto = bruto - retencion;
    final hoy = DateTime.now();
    return List.generate(count, (idx) {
      final fecha = _addMonths(opening, idx + 1);
      final pagada = hoy.isAfter(fecha);
      return DpfScheduleItem(
        number: idx + 1,
        paymentDate: _fmt(fecha),
        grossInterest: bruto.toStringAsFixed(2),
        withholding: retencion.toStringAsFixed(2),
        netInterest: neto.toStringAsFixed(2),
        status: pagada ? 'PAGADA' : 'PENDIENTE',
        actualPaymentDate: pagada ? _fmt(fecha) : '',
      );
    });
  }

  Future<List<RecreditOffer>> offers() async {
    await Future<void>.delayed(_delay);
    return const [];
  }

  Future<List<ProductoCreditoSocio>> creditProducts() async {
    await Future<void>.delayed(_delay);
    return const [
      ProductoCreditoSocio(
        id: 1,
        codigo: 'PEQ',
        nombre: 'Crédito Emprendedor',
        moneda: 'BOB',
        montoMin: '5000.00',
        montoMax: '50000.00',
        plazoMinMeses: 6,
        plazoMaxMeses: 36,
        tasaInteresAnual: '12.50',
        tipoAmortizacion: 'FRANCESA',
        requiereGarantia: false,
      ),
      ProductoCreditoSocio(
        id: 2,
        codigo: 'AGR',
        nombre: 'Crédito Agrícola',
        moneda: 'BOB',
        montoMin: '10000.00',
        montoMax: '100000.00',
        plazoMinMeses: 12,
        plazoMaxMeses: 48,
        tasaInteresAnual: '11.80',
        tipoAmortizacion: 'FRANCESA',
        requiereGarantia: true,
      ),
      ProductoCreditoSocio(
        id: 3,
        codigo: 'VIV',
        nombre: 'Crédito Vivienda',
        moneda: 'BOB',
        montoMin: '20000.00',
        montoMax: '200000.00',
        plazoMinMeses: 24,
        plazoMaxMeses: 120,
        tasaInteresAnual: '9.50',
        tipoAmortizacion: 'FRANCESA',
        requiereGarantia: true,
      ),
    ];
  }

  Future<SimulacionCredito?> simulateCredit({
    required int productId,
    required String amount,
    required int termMonths,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final productos = await creditProducts();
    ProductoCreditoSocio? producto;
    for (final p in productos) {
      if (p.id == productId) {
        producto = p;
        break;
      }
    }
    if (producto == null) return null;
    final monto = _parse(amount);
    final tasa = _parse(producto.tasaInteresAnual);
    final cuota = _cuotaFrances(monto, tasa, termMonths);
    final r = tasa / 100 / 12;
    var saldo = monto;
    final cronograma = <SimulacionCuota>[];
    for (var n = 1; n <= termMonths; n++) {
      final interes = saldo * r;
      final capital = cuota - interes;
      saldo = math.max(0, saldo - capital);
      cronograma.add(SimulacionCuota(
        numero: n,
        capital: capital.toStringAsFixed(2),
        interes: interes.toStringAsFixed(2),
        cuota: cuota.toStringAsFixed(2),
        saldo: saldo.toStringAsFixed(2),
      ));
    }
    final totalIntereses =
        cronograma.fold(0.0, (sum, c) => sum + _parse(c.interes));
    return SimulacionCredito(
      cuotaEstimada: cuota.toStringAsFixed(2),
      totalIntereses: totalIntereses.toStringAsFixed(2),
      totalAPagar: (monto + totalIntereses).toStringAsFixed(2),
      cronograma: cronograma,
    );
  }

  Future<List<SolicitudCreditoItem>> creditRequests() async {
    await Future<void>.delayed(_delay);
    return const [];
  }
}
