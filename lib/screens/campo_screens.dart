import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/campo_model.dart';
import '../services/campo_hardware_service.dart';
import '../services/campo_service.dart';
import '../services/mock_auth_service.dart';

class CampoHomeScreen extends StatefulWidget {
  final CampoService? service;
  const CampoHomeScreen({super.key, this.service});

  @override
  State<CampoHomeScreen> createState() => _CampoHomeScreenState();
}

class _CampoHomeScreenState extends State<CampoHomeScreen> {
  late final CampoService _service = widget.service ?? CampoService();
  String _canalFilter = 'TODOS';
  late Future<CampoResult<List<SolicitudResumenCampo>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.getWorklist(
      requiereEvaluacion: true,
      canalOrigen: _canalFilter == 'TODOS' ? null : _canalFilter,
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Desea cerrar la sesión de Oficial de Crédito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('dialog_confirm_logout_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      AuthService.tokenJWT = null;
      AuthService.currentRole = null;
      try {
        await AuthService.currentStore.clearToken();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Módulo de Campo',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            key: const Key('campo_precalificar_nav_btn'),
            tooltip: 'Precalificar',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrecalificacionScreen(service: _service),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('campo_logout_btn'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cardBg,
            child: Row(
              children: [
                Text(
                  'Canal:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('filter_canal_todos'),
                  label: const Text('Todos'),
                  selected: _canalFilter == 'TODOS',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _canalFilter = 'TODOS';
                        _load();
                      });
                    }
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  key: const Key('filter_canal_movil'),
                  label: const Text('Móvil'),
                  selected: _canalFilter == 'MOVIL',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _canalFilter = 'MOVIL';
                        _load();
                      });
                    }
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  key: const Key('filter_canal_ventanilla'),
                  label: const Text('Ventanilla'),
                  selected: _canalFilter == 'VENTANILLA',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _canalFilter = 'VENTANILLA';
                        _load();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          // Worklist List
          Expanded(
            child: FutureBuilder<CampoResult<List<SolicitudResumenCampo>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final result = snapshot.data;
                if (result == null || !result.success) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            result?.error ?? 'Error al cargar lista de trabajo',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => setState(_load),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final items = result.value!;
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_turned_in,
                              size: 48, color: subtextColor),
                          const SizedBox(height: 12),
                          Text(
                            'No hay solicitudes pendientes de evaluación.',
                            style: TextStyle(color: subtextColor, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _load();
                    await _future;
                    if (mounted) setState(() {});
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isMovil = item.canalOrigen == 'MOVIL';

                      return InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FichaCampoScreen(
                                solicitudId: item.id,
                                service: _service,
                              ),
                            ),
                          );
                          _load();
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.numeroSolicitud,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isMovil
                                          ? accentColor.withValues(alpha: 0.15)
                                          : Colors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.canalOrigen,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMovil
                                            ? accentColor
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.socioNombre} (CI: ${item.socioCi})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.productoNombre} · ${item.monto} ${item.monedaSimbolo} · ${item.plazoMeses} meses',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Destino: ${item.destino}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios,
                                      size: 14, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('campo_precalificar_fab'),
        icon: const Icon(Icons.calculate_outlined),
        label: const Text('Precalificar'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrecalificacionScreen(service: _service),
            ),
          );
        },
      ),
    );
  }
}

class FichaCampoScreen extends StatefulWidget {
  final int solicitudId;
  final CampoService? service;
  final CampoLocationService? locationService;
  final CampoCameraService? cameraService;

  const FichaCampoScreen({
    super.key,
    required this.solicitudId,
    this.service,
    this.locationService,
    this.cameraService,
  });

  @override
  State<FichaCampoScreen> createState() => _FichaCampoScreenState();
}

class _FichaCampoScreenState extends State<FichaCampoScreen> {
  late final CampoService _service = widget.service ?? CampoService();
  late final CampoLocationService _locationService =
      widget.locationService ?? GeolocatorCampoLocationService();
  late final CampoCameraService _cameraService =
      widget.cameraService ?? DefaultCampoCameraService();
  late Future<CampoResult<FichaCampo>> _future;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _ingresoCtrl = TextEditingController();
  final _egresoCtrl = TextEditingController();
  final _deudasCtrl = TextEditingController(text: '0.00');
  final _actividadCtrl = TextEditingController();
  final _antiguedadCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  String _fuenteIngresos = 'DEPENDIENTE';
  String _calificacionAsfi = 'A';

  // Location GPS state (CU-M9)
  bool _gpsLoading = false;
  String? _gpsError;
  String? _coordenadas;
  double? _gpsAccuracy;

  // Photos state (CU-M9)
  List<FotoEvaluacionCampo> _fotos = [];
  bool _uploadingPhoto = false;
  String? _fotoError;

  bool _formInitialized = false;
  bool _saving = false;
  bool _scoringLoading = false;
  String? _scoringError;
  ScoringResultado? _scoringResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.getFichaCampo(widget.solicitudId);
  }

  @override
  void dispose() {
    _ingresoCtrl.dispose();
    _egresoCtrl.dispose();
    _deudasCtrl.dispose();
    _actividadCtrl.dispose();
    _antiguedadCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  void _initFormFields(FichaCampo ficha) {
    if (_formInitialized) return;
    _formInitialized = true;

    final eval = ficha.evaluacion;
    final declared = ficha.datosDeclarados;

    if (eval != null) {
      _ingresoCtrl.text = eval.ingresoMensual;
      _egresoCtrl.text = eval.egresoMensual;
      _deudasCtrl.text = eval.cuotaDeudasMensual;
      _actividadCtrl.text = eval.actividadEconomica;
      _antiguedadCtrl.text = eval.antiguedadLaboralMeses.toString();
      _observacionesCtrl.text = eval.observaciones ?? '';
      _fuenteIngresos = eval.fuenteIngresos;
      _calificacionAsfi = eval.calificacionAsfi;
      _coordenadas = eval.coordenadas;
      _fotos = List.from(eval.fotografias);
    } else {
      _coordenadas = null;
      _fotos = [];
      if (declared != null) {
        _ingresoCtrl.text = declared.ingresoMensual ?? '';
        _egresoCtrl.text = declared.egresoMensual ?? '';
        _actividadCtrl.text = declared.actividadEconomica ?? '';
        if (declared.fuenteIngresos != null &&
            ficha.catalogos.fuentesIngresos.contains(declared.fuenteIngresos)) {
          _fuenteIngresos = declared.fuenteIngresos!;
        }
      }
    }
  }

  Future<void> _capturarUbicacion() async {
    setState(() {
      _gpsLoading = true;
      _gpsError = null;
    });

    final res = await _locationService.getCurrentPosition();

    if (!mounted) return;
    setState(() {
      _gpsLoading = false;
      if (res.success && res.position != null) {
        _coordenadas = res.position!.coordenadas;
        _gpsAccuracy = res.position!.accuracy;
        _gpsError = null;
      } else {
        _gpsError = res.error ?? 'No se pudo obtener la ubicación GPS.';
      }
    });
  }

  Future<void> _tomarFoto() async {
    if (_fotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se ha alcanzado el límite máximo de 5 fotografías.'),
        ),
      );
      return;
    }

    setState(() => _fotoError = null);
    final photoRes = await _cameraService.capturePhoto(context);

    if (photoRes.isCancelled || photoRes.bytes == null) {
      if (photoRes.error != null) {
        setState(() => _fotoError = photoRes.error);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _uploadingPhoto = true;
      _fotoError = null;
    });

    final uploadRes = await _service.subirFotoEvaluacion(
      widget.solicitudId,
      bytes: photoRes.bytes!,
      filename: photoRes.filename ?? 'foto.jpg',
    );

    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (uploadRes.success) {
        _fotos = List.from(uploadRes.value!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotografía subida exitosamente.')),
        );
      } else {
        _fotoError = uploadRes.error ?? 'Error al subir fotografía.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_fotoError!)),
        );
      }
    });
  }

  Future<void> _eliminarFoto(FotoEvaluacionCampo foto) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar fotografía'),
        content: const Text(
          '¿Está seguro de eliminar esta fotografía de respaldo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('dialog_confirm_delete_foto_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await _service.eliminarFotoEvaluacion(
      widget.solicitudId,
      foto.id,
    );

    if (!mounted) return;
    if (res.success) {
      setState(() {
        _fotos = List.from(res.value!);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotografía eliminada exitosamente.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Error al eliminar fotografía.'),
        ),
      );
    }
  }

  Future<void> _guardarEvaluacion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final form = EvaluacionCampoForm(
      ingresoMensual: _ingresoCtrl.text.trim(),
      egresoMensual: _egresoCtrl.text.trim(),
      cuotaDeudasMensual: _deudasCtrl.text.trim().isEmpty ? '0.00' : _deudasCtrl.text.trim(),
      actividadEconomica: _actividadCtrl.text.trim(),
      fuenteIngresos: _fuenteIngresos,
      antiguedadLaboralMeses: int.tryParse(_antiguedadCtrl.text.trim()) ?? 0,
      calificacionAsfi: _calificacionAsfi,
      observaciones: _observacionesCtrl.text.trim().isNotEmpty
          ? _observacionesCtrl.text.trim()
          : null,
      coordenadas: _coordenadas,
    );

    final res = await _service.guardarEvaluacion(widget.solicitudId, form);

    if (!mounted) return;
    setState(() => _saving = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evaluación guardada exitosamente.')),
      );
      _formInitialized = false;
      _load();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Error al guardar evaluación.')),
      );
    }
  }

  Future<void> _calcularScoring() async {
    setState(() {
      _scoringLoading = true;
      _scoringError = null;
    });

    final res = await _service.calcularScoring(widget.solicitudId);

    if (!mounted) return;
    setState(() {
      _scoringLoading = false;
      if (res.success) {
        _scoringResult = res.value;
        _scoringError = null;
      } else {
        _scoringError = res.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Ficha de Campo',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: FutureBuilder<CampoResult<FichaCampo>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null || !result.success) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(result?.error ?? 'Error al cargar ficha de campo'),
              ),
            );
          }

          final ficha = result.value!;
          _initFormFields(ficha);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Solicitud Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ficha.solicitud.numeroSolicitud,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ficha.solicitud.estado,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    _row('Producto:', ficha.solicitud.producto),
                    _row('Monto:', '${ficha.solicitud.monto} BOB'),
                    _row('Plazo:', '${ficha.solicitud.plazoMeses} meses'),
                    _row('Destino:', ficha.solicitud.destino),
                    if (ficha.solicitud.destinoDetalle != null)
                      _row('Detalle destino:', ficha.solicitud.destinoDetalle!),
                    _row('Canal origen:', ficha.solicitud.canalOrigen),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Socio Card (with null safety "—")
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del Socio',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    const Divider(height: 16),
                    _row('Nombre:', ficha.socio.nombreCompleto),
                    _row('C.I.:', ficha.socio.ci),
                    _row('Teléfono:', ficha.socio.telefonoDisplay),
                    _row('Dirección:', ficha.socio.direccionDisplay),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Reference self-declared data card
              if (ficha.datosDeclarados != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(
                            'Declarado por el socio (Referencia)',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _row('Ingreso declarado:',
                          '${ficha.datosDeclarados!.ingresoMensual ?? "—"} BOB'),
                      _row('Egreso declarado:',
                          '${ficha.datosDeclarados!.egresoMensual ?? "—"} BOB'),
                      _row('Actividad económica:',
                          ficha.datosDeclarados!.actividadEconomica ?? '—'),
                      _row('Fuente de ingresos:',
                          ficha.datosDeclarados!.fuenteIngresos ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Socioeconomic evaluation form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Evaluación Socioeconómica',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          Text(
                            ficha.evaluacion != null
                                ? 'Completada'
                                : 'Pendiente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ficha.evaluacion != null
                                  ? AppColors.forestGreen
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      TextFormField(
                        key: const Key('eval_ingreso_field'),
                        controller: _ingresoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Ingreso mensual verificado (BOB) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingrese el ingreso mensual';
                          }
                          final numVal = double.tryParse(val.trim());
                          if (numVal == null || numVal <= 0) {
                            return 'El ingreso debe ser mayor a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('eval_egreso_field'),
                        controller: _egresoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Egreso mensual verificado (BOB) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingrese el egreso mensual';
                          }
                          final numVal = double.tryParse(val.trim());
                          if (numVal == null || numVal < 0) {
                            return 'El egreso no puede ser negativo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('eval_deudas_field'),
                        controller: _deudasCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cuota de otras deudas mensual (BOB) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingrese la cuota de deudas';
                          }
                          final numVal = double.tryParse(val.trim());
                          if (numVal == null || numVal < 0) {
                            return 'No puede ser negativo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('eval_actividad_field'),
                        controller: _actividadCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Actividad económica verificada *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingrese la actividad económica';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const Key('eval_fuente_dropdown'),
                        initialValue: _fuenteIngresos,
                        decoration: const InputDecoration(
                          labelText: 'Fuente de ingresos *',
                          border: OutlineInputBorder(),
                        ),
                        items: ficha.catalogos.fuentesIngresos
                            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _fuenteIngresos = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('eval_antiguedad_field'),
                        controller: _antiguedadCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Antigüedad laboral (meses) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingrese la antigüedad laboral';
                          }
                          final intVal = int.tryParse(val.trim());
                          if (intVal == null || intVal < 0) {
                            return 'La antigüedad debe ser mayor o igual a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const Key('eval_calificacion_dropdown'),
                        initialValue: _calificacionAsfi,
                        decoration: const InputDecoration(
                          labelText: 'Calificación ASFI *',
                          border: OutlineInputBorder(),
                        ),
                        items: ficha.catalogos.calificacionesAsfi
                            .map((c) => DropdownMenuItem(value: c, child: Text('Categoría $c')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _calificacionAsfi = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('eval_observaciones_field'),
                        controller: _observacionesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones de campo (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Georreferenciación GPS (CU-M9)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 20, color: accentColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Georreferenciación GPS',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_coordenadas != null) ...[
                              Text(
                                'Coordenadas: $_coordenadas',
                                key: const Key('eval_coordenadas_text'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              if (_gpsAccuracy != null)
                                Text(
                                  'Precisión: ±${_gpsAccuracy!.toStringAsFixed(1)} m',
                                  key: const Key('eval_gps_accuracy_text'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subtextColor,
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                            if (_gpsError != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _gpsError!,
                                  key: const Key('eval_gps_error_text'),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const Key('eval_capturar_gps_btn'),
                                icon: _gpsLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location, size: 18),
                                label: Text(
                                  _coordenadas != null
                                      ? 'Actualizar ubicación GPS'
                                      : 'Capturar ubicación GPS',
                                ),
                                onPressed:
                                    _gpsLoading ? null : _capturarUbicacion,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('eval_guardar_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Guardar Evaluación'),
                          onPressed: _saving ? null : _guardarEvaluacion,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Photos Section (CU-M9)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fotografías de Respaldo (${_fotos.length}/5)',
                          key: const Key('fotos_section_title'),
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        if (ficha.evaluacion != null && _fotos.length < 5)
                          ElevatedButton.icon(
                            key: const Key('fotos_tomar_foto_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            icon: _uploadingPhoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt, size: 16),
                            label: const Text(
                              'Tomar foto',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: _uploadingPhoto ? null : _tomarFoto,
                          ),
                      ],
                    ),
                    const Divider(height: 16),
                    if (ficha.evaluacion == null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Debe guardar la evaluación socioeconómica antes de adjuntar fotografías de respaldo.',
                                key: const Key(
                                    'fotos_evaluacion_requerida_hint'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.amber[200]
                                      : Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (_fotoError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 16, color: Colors.red),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _fotoError!,
                                  key: const Key('fotos_error_text'),
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_fotos.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'No hay fotografías adjuntas. Puede agregar hasta 5 fotos.',
                              style: TextStyle(
                                  fontSize: 12, color: subtextColor),
                            ),
                          ),
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(_fotos.length, (index) {
                            final foto = _fotos[index];
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[850]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: foto.url != null &&
                                          foto.url!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: foto.url!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              const Center(
                                            child: Icon(Icons.broken_image,
                                                color: Colors.grey),
                                          ),
                                        )
                                      : Column(
                                          key: Key(
                                              'foto_placeholder_tile_$index'),
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.photo_outlined,
                                              size: 32,
                                              color: subtextColor,
                                            ),
                                            const SizedBox(height: 4),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              child: Text(
                                                'Sin vista previa',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: subtextColor),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      key: Key('foto_delete_btn_$index'),
                                      customBorder: const CircleBorder(),
                                      onTap: () => _eliminarFoto(foto),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Scoring Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motor de Scoring Crediticio (CU-W23)',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Calcula automáticamente el dictamen y puntaje a partir de los datos socioeconómicos levantados en campo.',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('eval_calcular_scoring_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _scoringLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bolt),
                        label: const Text('Calcular scoring'),
                        onPressed: _scoringLoading ? null : _calcularScoring,
                      ),
                    ),
                    if (_scoringError != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _scoringError!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_scoringResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dictamen: ${_scoringResult!.dictamen}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: _scoringResult!.isAprobado
                                        ? AppColors.forestGreen
                                        : AppColors.error,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_scoringResult!.score} / 1000 pts',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_scoringResult!.explicacion != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _scoringResult!.explicacion!,
                                style: TextStyle(fontSize: 12, color: subtextColor),
                              ),
                            ],
                            const Divider(height: 18),
                            Text(
                              'Factores de Decisión:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._scoringResult!.factores.map((f) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.indigo),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.descripcion,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                          ),
                                          Text(
                                            '${f.puntos}/${f.maximo} pts · ${f.motivo}',
                                            style: TextStyle(fontSize: 11, color: subtextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class PrecalificacionScreen extends StatefulWidget {
  final CampoService? service;

  const PrecalificacionScreen({super.key, this.service});

  @override
  State<PrecalificacionScreen> createState() => _PrecalificacionScreenState();
}

class _PrecalificacionScreenState extends State<PrecalificacionScreen> {
  late final CampoService _service = widget.service ?? CampoService();

  bool _loadingData = true;
  String? _initError;
  bool _submitting = false;
  String? _backendError;

  List<SocioPrecalificacion> _socios = [];
  List<ProductoPrecalificacion> _productos = [];

  SocioPrecalificacion? _selectedSocio;
  ProductoPrecalificacion? _selectedProducto;

  final _montoCtrl = TextEditingController();
  final _plazoCtrl = TextEditingController();
  final _ingresoCtrl = TextEditingController();
  final _egresoCtrl = TextEditingController();
  final _deudasCtrl = TextEditingController(text: '0.00');
  final _antiguedadCtrl = TextEditingController();

  String? _calificacionAsfi;
  String? _fuenteIngresos;

  String? _socioError;
  String? _montoError;
  String? _plazoError;
  String? _ingresoError;
  String? _egresoError;
  String? _deudasError;
  String? _antiguedadError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _plazoCtrl.dispose();
    _ingresoCtrl.dispose();
    _egresoCtrl.dispose();
    _deudasCtrl.dispose();
    _antiguedadCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loadingData = true;
      _initError = null;
    });

    try {
      final results = await Future.wait([
        _service.getSociosActivos(),
        _service.getProductosActivos(),
      ]);

      final sociosRes = results[0] as CampoResult<List<SocioPrecalificacion>>;
      final prodRes = results[1] as CampoResult<List<ProductoPrecalificacion>>;

      if (!mounted) return;

      if (!sociosRes.success) {
        setState(() {
          _loadingData = false;
          _initError = sociosRes.error ?? 'Error al cargar socios activos';
        });
        return;
      }

      if (!prodRes.success) {
        setState(() {
          _loadingData = false;
          _initError = prodRes.error ?? 'Error al cargar productos activos';
        });
        return;
      }

      setState(() {
        _loadingData = false;
        _socios = sociosRes.value ?? [];
        _productos = prodRes.value ?? [];
        if (_productos.isNotEmpty) {
          _selectedProducto = _productos.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingData = false;
        _initError = e.toString();
      });
    }
  }

  Future<void> _openSocioPicker() async {
    final socio = await showDialog<SocioPrecalificacion>(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final filtered = _socios.where((s) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return s.ci.toLowerCase().contains(q) ||
                  s.nombreCompleto.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              title: const Text('Buscar Socio Activo'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('precal_socio_search_field'),
                      decoration: const InputDecoration(
                        labelText: 'Buscar por CI o nombre',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          query = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron socios activos',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                return ListTile(
                                  key: Key('precal_socio_tile_${s.id}'),
                                  title: Text(
                                    s.nombreCompleto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text('CI: ${s.ci}'),
                                  onTap: () {
                                    Navigator.pop(ctx, s);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (socio != null) {
      setState(() {
        _selectedSocio = socio;
        _socioError = null;
      });
    }
  }

  Future<void> _onSubmit() async {
    final socioError =
        _selectedSocio == null ? 'Debe seleccionar un socio' : null;

    final prod = _selectedProducto;
    String? montoError;
    final montoVal = double.tryParse(_montoCtrl.text.trim());
    if (montoVal == null) {
      montoError = 'Ingrese un monto válido';
    } else if (prod != null &&
        (montoVal < prod.montoMinDouble || montoVal > prod.montoMaxDouble)) {
      montoError =
          'El monto debe estar entre ${prod.montoMin} y ${prod.montoMax} ${prod.monedaSimbolo ?? "Bs."}';
    }

    String? plazoError;
    final plazoVal = int.tryParse(_plazoCtrl.text.trim());
    if (plazoVal == null) {
      plazoError = 'Ingrese un plazo válido';
    } else if (prod != null &&
        (plazoVal < prod.plazoMinMeses || plazoVal > prod.plazoMaxMeses)) {
      plazoError =
          'El plazo debe estar entre ${prod.plazoMinMeses} y ${prod.plazoMaxMeses} meses';
    }

    String? ingresoError;
    final ingresoVal = double.tryParse(_ingresoCtrl.text.trim());
    if (ingresoVal == null || ingresoVal <= 0) {
      ingresoError = 'El ingreso debe ser mayor a 0';
    }

    String? egresoError;
    final egresoVal = double.tryParse(_egresoCtrl.text.trim());
    if (egresoVal == null || egresoVal < 0) {
      egresoError = 'El egreso no puede ser negativo';
    }

    String? deudasError;
    final deudasVal = double.tryParse(_deudasCtrl.text.trim());
    if (deudasVal == null || deudasVal < 0) {
      deudasError = 'Las deudas no pueden ser negativas';
    }

    String? antiguedadError;
    final antiguedadVal = int.tryParse(_antiguedadCtrl.text.trim());
    if (antiguedadVal == null || antiguedadVal < 0) {
      antiguedadError = 'La antigüedad debe ser mayor o igual a 0';
    }

    setState(() {
      _socioError = socioError;
      _montoError = montoError;
      _plazoError = plazoError;
      _ingresoError = ingresoError;
      _egresoError = egresoError;
      _deudasError = deudasError;
      _antiguedadError = antiguedadError;
      _backendError = null;
    });

    if (socioError != null ||
        montoError != null ||
        plazoError != null ||
        ingresoError != null ||
        egresoError != null ||
        deudasError != null ||
        antiguedadError != null ||
        prod == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final form = PrecalificacionForm(
      socioId: _selectedSocio!.id,
      productoId: prod.id,
      monto: montoVal!.toStringAsFixed(2),
      plazoMeses: plazoVal!,
      ingresoMensual: ingresoVal!.toStringAsFixed(2),
      egresoMensual: egresoVal!.toStringAsFixed(2),
      cuotaDeudasMensual: (deudasVal ?? 0.0).toStringAsFixed(2),
      antiguedadLaboralMeses: antiguedadVal!,
      calificacionAsfi: _calificacionAsfi,
      fuenteIngresos: _fuenteIngresos,
    );

    final result = await _service.precalificar(form);
    if (!mounted) return;

    setState(() {
      _submitting = false;
    });

    if (!result.success || result.value == null) {
      setState(() {
        _backendError = result.error ?? 'Error al procesar la precalificación';
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrecalificacionResultadoScreen(
          resultado: result.value!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Precalificación en Campo',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          _initError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInitialData,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Socio Selector
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _socioError != null
                                ? AppColors.error
                                : borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedSocio == null
                                  ? Icons.person_outline
                                  : Icons.person,
                              color: _selectedSocio == null
                                  ? subtextColor
                                  : accentColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Socio',
                                    style: TextStyle(
                                        fontSize: 12, color: subtextColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedSocio?.nombreCompleto ??
                                        'Ningún socio seleccionado',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _selectedSocio != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _selectedSocio != null
                                          ? textColor
                                          : subtextColor,
                                    ),
                                  ),
                                  if (_selectedSocio != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'CI: ${_selectedSocio!.ci}',
                                      style: TextStyle(
                                          fontSize: 12, color: subtextColor),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            ElevatedButton(
                              key: const Key('precal_seleccionar_socio_btn'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _openSocioPicker,
                              child: Text(
                                _selectedSocio == null
                                    ? 'Seleccionar'
                                    : 'Cambiar',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_socioError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            _socioError!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Producto Selector
                      DropdownButtonFormField<ProductoPrecalificacion>(
                        key: const Key('precal_producto_dropdown'),
                        initialValue: _selectedProducto,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Producto de Crédito *',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                        items: _productos.map((p) {
                          final label =
                              '${p.nombre} (${p.montoMin} - ${p.montoMax} ${p.monedaSimbolo} · ${p.plazoMinMeses}-${p.plazoMaxMeses} m)';
                          return DropdownMenuItem<ProductoPrecalificacion>(
                            value: p,
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProducto = val;
                            _montoError = null;
                            _plazoError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Monto
                      TextFormField(
                        key: const Key('precal_monto_field'),
                        controller: _montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Monto solicitado *',
                          hintText: 'Ej: 8000.00',
                          prefixIcon: const Icon(Icons.attach_money),
                          suffixText:
                              _selectedProducto?.monedaSimbolo ?? 'Bs.',
                          errorText: _montoError,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Plazo
                      TextFormField(
                        key: const Key('precal_plazo_field'),
                        controller: _plazoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Plazo en meses *',
                          hintText: 'Ej: 24',
                          prefixIcon: const Icon(Icons.calendar_month),
                          suffixText: 'meses',
                          errorText: _plazoError,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Ingreso
                      TextFormField(
                        key: const Key('precal_ingreso_field'),
                        controller: _ingresoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Ingreso mensual *',
                          hintText: 'Ej: 6000.00',
                          prefixIcon: const Icon(Icons.trending_up),
                          suffixText:
                              _selectedProducto?.monedaSimbolo ?? 'Bs.',
                          errorText: _ingresoError,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Egreso
                      TextFormField(
                        key: const Key('precal_egreso_field'),
                        controller: _egresoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Egreso mensual *',
                          hintText: 'Ej: 2000.00',
                          prefixIcon: const Icon(Icons.trending_down),
                          suffixText:
                              _selectedProducto?.monedaSimbolo ?? 'Bs.',
                          errorText: _egresoError,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Deudas
                      TextFormField(
                        key: const Key('precal_deudas_field'),
                        controller: _deudasCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Cuota deudas mensual *',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.credit_card),
                          suffixText:
                              _selectedProducto?.monedaSimbolo ?? 'Bs.',
                          errorText: _deudasError,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Antigüedad
                      TextFormField(
                        key: const Key('precal_antiguedad_field'),
                        controller: _antiguedadCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Antigüedad laboral (meses) *',
                          hintText: 'Ej: 48',
                          prefixIcon: const Icon(Icons.work_outline),
                          suffixText: 'meses',
                          errorText: _antiguedadError,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ASFI
                      DropdownButtonFormField<String?>(
                        key: const Key('precal_asfi_dropdown'),
                        initialValue: _calificacionAsfi,
                        decoration: InputDecoration(
                          labelText: 'Calificación ASFI (opcional)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin calificar'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'A',
                            child: Text('Categoría A'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'B',
                            child: Text('Categoría B'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'C',
                            child: Text('Categoría C'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'D',
                            child: Text('Categoría D'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'E',
                            child: Text('Categoría E'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'F',
                            child: Text('Categoría F'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _calificacionAsfi = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Fuente
                      DropdownButtonFormField<String?>(
                        key: const Key('precal_fuente_dropdown'),
                        initialValue: _fuenteIngresos,
                        decoration: InputDecoration(
                          labelText: 'Fuente de ingresos (opcional)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: cardBg,
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin especificar'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'DEPENDIENTE',
                            child: Text('DEPENDIENTE'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'INDEPENDIENTE',
                            child: Text('INDEPENDIENTE'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'MIXTO',
                            child: Text('MIXTO'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _fuenteIngresos = val);
                        },
                      ),

                      if (_backendError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          key: const Key('precal_error_banner'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _backendError!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('precal_calcular_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bolt),
                          label: Text(
                            _submitting
                                ? 'Calculando precalificación...'
                                : 'Precalificar',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _submitting ? null : _onSubmit,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class PrecalificacionResultadoScreen extends StatelessWidget {
  final PrecalificacionResultado resultado;

  const PrecalificacionResultadoScreen({
    super.key,
    required this.resultado,
  });

  static Color _dictamenColor(String dictamen) {
    switch (dictamen.toUpperCase()) {
      case 'APROBADO':
        return AppColors.forestGreen;
      case 'RECHAZADO':
        return AppColors.error;
      case 'REVISION_MANUAL':
      case 'OBSERVADO':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  static String _formatProbabilidad(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final val = double.tryParse(raw);
    if (val == null) return raw;
    return '${(val * 100).toStringAsFixed(1)}%';
  }

  Widget _metricRow(String label, String value, {Key? key}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          Text(
            value,
            key: key,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Resultado de Precalificación',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent banner: Precalificación — no es una solicitud
            Container(
              key: const Key('precal_banner_no_solicitud'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precalificación — no es una solicitud',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color:
                                isDark ? Colors.amber[200] : Colors.amber[900],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Este resultado es meramente informativo y preliminar. No constituye una solicitud formal ni representa un compromiso de crédito.',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dictamen and Score Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        key: const Key('precal_dictamen_badge'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _dictamenColor(resultado.dictamen)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _dictamenColor(resultado.dictamen),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          resultado.dictamen,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _dictamenColor(resultado.dictamen),
                          ),
                        ),
                      ),
                      Text(
                        '${resultado.score} / 1000 pts',
                        key: const Key('precal_score_text'),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  if (resultado.socioNombre != null ||
                      resultado.productoNombre != null) ...[
                    const Divider(height: 24),
                    if (resultado.socioNombre != null)
                      _infoRow(
                        'Socio:',
                        '${resultado.socioNombre} (CI: ${resultado.socioCi ?? "-"})',
                      ),
                    if (resultado.productoNombre != null)
                      _infoRow('Producto:', resultado.productoNombre!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metrics Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Métricas Estimadas',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const Divider(height: 18),
                  _metricRow(
                    'Cuota estimada:',
                    '${resultado.cuotaEstimada ?? "0.00"} BOB',
                    key: const Key('precal_cuota_estimada_text'),
                  ),
                  if (resultado.relacionCuotaIngreso != null)
                    _metricRow(
                      'Relación cuota-ingreso:',
                      '${resultado.relacionCuotaIngreso}%',
                    ),
                  _metricRow(
                    'Nivel de riesgo:',
                    resultado.nivelRiesgo ?? 'NO DETERMINADO',
                    key: const Key('precal_nivel_riesgo_text'),
                  ),
                  _metricRow(
                    'Probabilidad de mora:',
                    _formatProbabilidad(resultado.probabilidadMora),
                    key: const Key('precal_probabilidad_mora_text'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Knockouts Section FIRST (if present)
            if (resultado.knockouts.isNotEmpty) ...[
              Container(
                key: const Key('precal_knockouts_section'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Reglas de Excepción (Knockouts)',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    ...resultado.knockouts.map((k) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.close,
                                size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${k.codigo} (${k.efecto})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    k.descripcion,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Factors Section
            Container(
              key: const Key('precal_factores_section'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Factores de Decisión',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const Divider(height: 18),
                  if (resultado.factores.isEmpty)
                    Text(
                      'No hay factores registrados.',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    )
                  else
                    ...resultado.factores.map((f) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.descripcion,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${f.puntos}/${f.maximo} pts · ${f.motivo}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),

            if (resultado.explicacion != null &&
                resultado.explicacion!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explicación:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resultado.explicacion!,
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver al formulario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
