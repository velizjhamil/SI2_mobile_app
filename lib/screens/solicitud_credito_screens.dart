import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/solicitud_credito_model.dart';
import '../services/socio_service.dart';

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'PENDIENTE':
      return AppColors.warning;
    case 'EN_EVALUACION':
    case 'EN_COMITE':
      return Colors.blue;
    case 'APROBADA':
    case 'DESEMBOLSADO':
      return AppColors.forestGreen;
    case 'RECHAZADA':
      return AppColors.error;
    case 'ANULADA':
    case 'OBSERVADA':
    default:
      return Colors.grey;
  }
}

String _destinoLabel(String destino) {
  switch (destino.toUpperCase()) {
    case 'CONSUMO':
      return 'Consumo personal';
    case 'CAPITAL_TRABAJO':
      return 'Capital de trabajo';
    case 'VIVIENDA':
      return 'Vivienda';
    case 'ACTIVO_FIJO':
      return 'Activo fijo';
    case 'EDUCACION':
      return 'Educación';
    case 'SALUD':
      return 'Salud';
    case 'REFINANCIAMIENTO':
      return 'Refinanciamiento';
    case 'OTRO':
      return 'Otro';
    default:
      return destino;
  }
}

String _fuenteLabel(String fuente) {
  switch (fuente.toUpperCase()) {
    case 'DEPENDIENTE':
      return 'Dependiente (Asalariado)';
    case 'INDEPENDIENTE':
      return 'Independiente / Negocio propio';
    case 'MIXTO':
      return 'Ingresos mixtos';
    default:
      return fuente;
  }
}

/// Pantalla 1: Catálogo de productos crediticios activos
class ProductosCreditoScreen extends StatefulWidget {
  final SocioService? service;
  const ProductosCreditoScreen({super.key, this.service});

  @override
  State<ProductosCreditoScreen> createState() => _ProductosCreditoScreenState();
}

class _ProductosCreditoScreenState extends State<ProductosCreditoScreen> {
  late Future<SocioResult<List<ProductoCreditoSocio>>> _future;
  late final SocioService _service = widget.service ?? SocioService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.creditProducts();
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
          'Solicitar crédito',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Mis solicitudes',
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MisSolicitudesScreen(service: _service),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<SocioResult<List<ProductoCreditoSocio>>>(
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
                      result?.error ?? 'Error al cargar productos crediticios',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor),
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

          final products = result.value!;
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No hay productos crediticios disponibles por el momento.',
                  style: TextStyle(color: subtextColor),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final prod = products[index];
              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod.nombre,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  prod.codigo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (prod.requiereGarantia)
                          Chip(
                            label: const Text('Garantía req.',
                                style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.amber.withValues(alpha: 0.2),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCol(
                            label: 'Rango de monto',
                            value:
                                '${prod.montoMin} a ${prod.montoMax} ${prod.moneda}',
                          ),
                        ),
                        Expanded(
                          child: _InfoCol(
                            label: 'Plazo permitido',
                            value:
                                '${prod.plazoMinMeses} a ${prod.plazoMaxMeses} meses',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCol(
                            label: 'Tasa anual',
                            value: '${prod.tasaInteresAnual}% anual',
                          ),
                        ),
                        Expanded(
                          child: _InfoCol(
                            label: 'Amortización',
                            value: prod.tipoAmortizacion == 'FRANCES'
                                ? 'Sistema Francés'
                                : 'Sistema Alemán',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.calculate, size: 18),
                        label: const Text('Simular crédito'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SimuladorCreditoScreen(
                                producto: prod,
                                service: _service,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoCol extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }
}

/// Pantalla 2: Simulador de crédito
class SimuladorCreditoScreen extends StatefulWidget {
  final ProductoCreditoSocio producto;
  final SocioService? service;

  const SimuladorCreditoScreen({
    super.key,
    required this.producto,
    this.service,
  });

  @override
  State<SimuladorCreditoScreen> createState() => _SimuladorCreditoScreenState();
}

class _SimuladorCreditoScreenState extends State<SimuladorCreditoScreen> {
  late final TextEditingController _montoCtrl;
  late final TextEditingController _plazoCtrl;
  late final SocioService _service = widget.service ?? SocioService();

  SimulacionCredito? _simulacion;
  bool _calculating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(text: widget.producto.montoMin);
    _plazoCtrl =
        TextEditingController(text: widget.producto.plazoMinMeses.toString());
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _plazoCtrl.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    final monto = _montoCtrl.text.trim();
    final plazo = int.tryParse(_plazoCtrl.text.trim());

    if (monto.isEmpty || plazo == null) {
      setState(() {
        _errorMessage = 'Ingrese un monto y plazo válidos.';
      });
      return;
    }

    setState(() {
      _calculating = true;
      _errorMessage = null;
    });

    final res = await _service.simulateCredit(
      productId: widget.producto.id,
      amount: monto,
      termMonths: plazo,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _calculating = false;
      if (res.success) {
        _simulacion = res.value;
        _errorMessage = null;
      } else {
        _simulacion = null;
        _errorMessage = res.error;
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
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Simulador de Crédito',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.producto.nombre,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Límites: ${widget.producto.montoMin} a ${widget.producto.montoMax} ${widget.producto.moneda} · ${widget.producto.plazoMinMeses} a ${widget.producto.plazoMaxMeses} meses',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('simulador_monto_field'),
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto solicitado (${widget.producto.moneda})',
              hintText: 'Ej. 1500.00',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('simulador_plazo_field'),
            controller: _plazoCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Plazo en meses',
              hintText: 'Ej. 12',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('simulador_calcular_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _calculating ? null : _calcular,
              child: _calculating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Calcular cuota y cronograma'),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
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
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_simulacion != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultado de la Simulación',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cuota mensual estimada:'),
                      Text(
                        '${_simulacion!.cuotaEstimada} ${widget.producto.moneda}',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total intereses estimados:'),
                      Text(
                        '${_simulacion!.totalIntereses} ${widget.producto.moneda}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a pagar:'),
                      Text(
                        '${_simulacion!.totalAPagar} ${widget.producto.moneda}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text(
                'Ver cronograma preliminar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('N°')),
                      DataColumn(label: Text('Capital')),
                      DataColumn(label: Text('Interés')),
                      DataColumn(label: Text('Cuota')),
                      DataColumn(label: Text('Saldo')),
                    ],
                    rows: _simulacion!.cronograma.map((c) {
                      return DataRow(cells: [
                        DataCell(Text(c.numero.toString())),
                        DataCell(Text(c.capital)),
                        DataCell(Text(c.interes)),
                        DataCell(Text(c.cuota)),
                        DataCell(Text(c.saldo)),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar con la solicitud'),
                onPressed: () {
                  final monto = _montoCtrl.text.trim();
                  final plazo = int.parse(_plazoCtrl.text.trim());
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FormularioSolicitudScreen(
                        producto: widget.producto,
                        monto: monto,
                        plazoMeses: plazo,
                        cuotaEstimada: _simulacion!.cuotaEstimada,
                        service: _service,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pantalla 3: Formulario de datos declarados y destino
class FormularioSolicitudScreen extends StatefulWidget {
  final ProductoCreditoSocio producto;
  final String monto;
  final int plazoMeses;
  final String cuotaEstimada;
  final SocioService? service;

  const FormularioSolicitudScreen({
    super.key,
    required this.producto,
    required this.monto,
    required this.plazoMeses,
    required this.cuotaEstimada,
    this.service,
  });

  @override
  State<FormularioSolicitudScreen> createState() =>
      _FormularioSolicitudScreenState();
}

class _FormularioSolicitudScreenState extends State<FormularioSolicitudScreen> {
  final _formKey = GlobalKey<FormState>();

  String _destino = 'CONSUMO';
  final _destinoDetalleCtrl = TextEditingController();
  final _actividadCtrl = TextEditingController();
  String _fuenteIngresos = 'DEPENDIENTE';
  final _ingresosCtrl = TextEditingController();
  final _egresosCtrl = TextEditingController();

  final List<String> _destinos = const [
    'CONSUMO',
    'CAPITAL_TRABAJO',
    'VIVIENDA',
    'ACTIVO_FIJO',
    'EDUCACION',
    'SALUD',
    'REFINANCIAMIENTO',
    'OTRO',
  ];

  final List<String> _fuentes = const [
    'DEPENDIENTE',
    'INDEPENDIENTE',
    'MIXTO',
  ];

  @override
  void dispose() {
    _destinoDetalleCtrl.dispose();
    _actividadCtrl.dispose();
    _ingresosCtrl.dispose();
    _egresosCtrl.dispose();
    super.dispose();
  }

  void _revisar() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final declared = DatosDeclarados(
      ingresoMensual: _ingresosCtrl.text.trim(),
      egresoMensual: _egresosCtrl.text.trim().isEmpty ? '0.00' : _egresosCtrl.text.trim(),
      actividadEconomica: _actividadCtrl.text.trim(),
      fuenteIngresos: _fuenteIngresos,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumenSolicitudScreen(
          producto: widget.producto,
          monto: widget.monto,
          plazoMeses: widget.plazoMeses,
          cuotaEstimada: widget.cuotaEstimada,
          destino: _destino,
          destinoDetalle: _destinoDetalleCtrl.text.trim().isNotEmpty
              ? _destinoDetalleCtrl.text.trim()
              : null,
          datosDeclarados: declared,
          service: widget.service,
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
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Datos de la Solicitud',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.producto.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.monto} ${widget.producto.moneda} · ${widget.plazoMeses} m',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Destino del Crédito',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _destino,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Destino',
              ),
              items: _destinos
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(_destinoLabel(d)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _destino = val);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('formulario_destino_detalle_field'),
              controller: _destinoDetalleCtrl,
              decoration: InputDecoration(
                labelText: _destino == 'OTRO'
                    ? 'Detalle del destino *'
                    : 'Detalle o propósito (opcional)',
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (_destino == 'OTRO' && (val == null || val.trim().isEmpty)) {
                  return 'Debe detallar el destino cuando selecciona OTRO';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Datos Socioeconómicos Declarados',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('formulario_actividad_field'),
              controller: _actividadCtrl,
              decoration: const InputDecoration(
                labelText: 'Actividad económica principal *',
                hintText: 'Ej. Comercio minorista, Docente, etc.',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese su actividad económica';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fuenteIngresos,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Fuente de ingresos',
              ),
              items: _fuentes
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(_fuenteLabel(f)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _fuenteIngresos = val);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('formulario_ingresos_field'),
              controller: _ingresosCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    'Ingreso mensual promedio (${widget.producto.moneda}) *',
                hintText: 'Ej. 3500.00',
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese sus ingresos mensuales';
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
              key: const Key('formulario_egresos_field'),
              controller: _egresosCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    'Egreso mensual promedio (${widget.producto.moneda}) *',
                hintText: 'Ej. 1200.00',
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese sus egresos mensuales';
                }
                final numVal = double.tryParse(val.trim());
                if (numVal == null || numVal < 0) {
                  return 'El egreso no puede ser negativo';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('formulario_revisar_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _revisar,
                child: const Text('Revisar y confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla 4: Resumen y confirmación de envío
class ResumenSolicitudScreen extends StatefulWidget {
  final ProductoCreditoSocio producto;
  final String monto;
  final int plazoMeses;
  final String cuotaEstimada;
  final String destino;
  final String? destinoDetalle;
  final DatosDeclarados datosDeclarados;
  final SocioService? service;

  const ResumenSolicitudScreen({
    super.key,
    required this.producto,
    required this.monto,
    required this.plazoMeses,
    required this.cuotaEstimada,
    required this.destino,
    this.destinoDetalle,
    required this.datosDeclarados,
    this.service,
  });

  @override
  State<ResumenSolicitudScreen> createState() => _ResumenSolicitudScreenState();
}

class _ResumenSolicitudScreenState extends State<ResumenSolicitudScreen> {
  late final SocioService _service = widget.service ?? SocioService();
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _enviar() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final res = await _service.createCreditRequest(
      productId: widget.producto.id,
      amount: widget.monto,
      termMonths: widget.plazoMeses,
      destination: widget.destino,
      destinationDetail: widget.destinoDetalle,
      declaredData: widget.datosDeclarados,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (res.success) {
      final item = res.value!;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Solicitud Enviada!'),
          content: Text(
            'Tu solicitud ${item.numeroSolicitud} fue registrada exitosamente con estado PENDIENTE. Un oficial de crédito la revisará.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MisSolicitudesScreen(service: _service),
                  ),
                  (route) => route.isFirst,
                );
              },
              child: const Text('Ver mis solicitudes'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorMessage = res.error;
      });
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
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Confirmar Solicitud',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen del Financiamiento',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const Divider(height: 20),
                _summaryRow('Producto:', widget.producto.nombre),
                _summaryRow('Monto solicitado:',
                    '${widget.monto} ${widget.producto.moneda}'),
                _summaryRow('Plazo:', '${widget.plazoMeses} meses'),
                _summaryRow('Cuota estimada:',
                    '${widget.cuotaEstimada} ${widget.producto.moneda}'),
                _summaryRow('Destino:', _destinoLabel(widget.destino)),
                if (widget.destinoDetalle != null)
                  _summaryRow('Detalle destino:', widget.destinoDetalle!),
                const Divider(height: 20),
                Text(
                  'Datos Declarados',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                _summaryRow('Actividad:',
                    widget.datosDeclarados.actividadEconomica),
                _summaryRow('Fuente ingresos:',
                    _fuenteLabel(widget.datosDeclarados.fuenteIngresos)),
                _summaryRow('Ingreso mensual:',
                    '${widget.datosDeclarados.ingresoMensual} ${widget.producto.moneda}'),
                _summaryRow('Egreso mensual:',
                    '${widget.datosDeclarados.egresoMensual} ${widget.producto.moneda}'),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
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
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('resumen_confirmar_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _submitting ? null : _enviar,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmar y Enviar Solicitud'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

/// Pantalla 5: Listado de "Mis solicitudes"
class MisSolicitudesScreen extends StatefulWidget {
  final SocioService? service;
  const MisSolicitudesScreen({super.key, this.service});

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  late Future<SocioResult<List<SolicitudCreditoItem>>> _future;
  late final SocioService _service = widget.service ?? SocioService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.creditRequests();
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Mis Solicitudes',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: FutureBuilder<SocioResult<List<SolicitudCreditoItem>>>(
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
                      result?.error ?? 'Error al cargar solicitudes',
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

          final list = result.value!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tienes solicitudes de crédito registradas.',
                  style: TextStyle(color: subtextColor),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = list[index];
              final statusColor = _statusColor(req.estado);

              return InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleSolicitudScreen(
                        solicitudId: req.id,
                        service: _service,
                      ),
                    ),
                  );
                  _load();
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            req.numeroSolicitud,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.estado,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${req.producto} · ${req.monto} BOB',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Plazo: ${req.plazoMeses} m · ${_destinoLabel(req.destino)}',
                            style: TextStyle(fontSize: 12, color: subtextColor),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Pantalla 6: Detalle de solicitud y cancelación
class DetalleSolicitudScreen extends StatefulWidget {
  final int solicitudId;
  final SocioService? service;

  const DetalleSolicitudScreen({
    super.key,
    required this.solicitudId,
    this.service,
  });

  @override
  State<DetalleSolicitudScreen> createState() => _DetalleSolicitudScreenState();
}

class _DetalleSolicitudScreenState extends State<DetalleSolicitudScreen> {
  late Future<SocioResult<SolicitudCreditoDetalle>> _future;
  late final SocioService _service = widget.service ?? SocioService();
  bool _canceling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.creditRequestDetail(widget.solicitudId);
  }

  Future<void> _cancelar(SolicitudCreditoDetalle detalle) async {
    final motivoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud de crédito'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Está seguro que desea cancelar esta solicitud? Esta acción no se puede deshacer.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('dialog_motivo_cancelacion_field'),
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo de cancelación *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese el motivo de cancelación';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            key: const Key('dialog_confirmar_cancelacion_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _canceling = true);

    final res = await _service.cancelCreditRequest(
      widget.solicitudId,
      reason: motivoCtrl.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _canceling = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada exitosamente.')),
      );
      _load();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Error al cancelar la solicitud.')),
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Detalle de Solicitud',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: FutureBuilder<SocioResult<SolicitudCreditoDetalle>>(
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
                child: Text(result?.error ?? 'Error al cargar detalle'),
              ),
            );
          }

          final det = result.value!;
          final statusColor = _statusColor(det.estado);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          det.numeroSolicitud,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            det.estado,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _detailRow('Producto:', det.producto),
                    _detailRow('Monto:', '${det.monto} BOB'),
                    _detailRow('Plazo:', '${det.plazoMeses} meses'),
                    _detailRow('Destino:', _destinoLabel(det.destino)),
                    _detailRow('Canal de origen:', det.canalOrigen),
                    _detailRow('Fecha:', det.fechaSolicitud),
                    if (det.motivo != null && det.motivo!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Observación / Motivo: ${det.motivo}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.brown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Línea de tiempo',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              if (det.lineaTiempo.isEmpty)
                Text(
                  'Sin eventos registrados.',
                  style: TextStyle(color: subtextColor, fontSize: 13),
                )
              else
                ...det.lineaTiempo.map((event) {
                  final eColor = _statusColor(event.estado);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, color: eColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.estado,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: eColor,
                                ),
                              ),
                              Text(
                                event.fecha,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subtextColor,
                                ),
                              ),
                              if (event.motivo != null &&
                                  event.motivo!.isNotEmpty)
                                Text(
                                  event.motivo!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              if (det.canCancel) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _canceling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar solicitud'),
                    onPressed: _canceling ? null : () => _cancelar(det),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
