import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/pdf_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _dataService = DataService();
  List<Map<String, dynamic>> _pedidos = [];
  bool _isLoading = true;
  String _filtroTienda = 'all';
  List<Map<String, dynamic>> _tiendas = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final tiendas = await _dataService.getLinkedProviders();
      final pedidos = await _dataService.getMisPedidos();
      if (mounted) {
        setState(() {
          _tiendas = tiendas;
          _pedidos = pedidos;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelarPedido(Map<String, dynamic> pedido) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text(
            '\u00bfEst\u00e1s seguro de que deseas cancelar este pedido? Esta acci\u00f3n no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await _dataService.cancelarPedido(pedido['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido cancelado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _cargarDatos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _pedidosFiltrados {
    if (_filtroTienda == 'all') return _pedidos;
    return _pedidos
        .where((p) => p['user_id'] == _filtroTienda)
        .toList();
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'en_proceso':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _iconEstado(String estado) {
    switch (estado) {
      case 'entregado':
        return Icons.check_circle_outline;
      case 'cancelado':
        return Icons.cancel_outlined;
      case 'en_proceso':
        return Icons.local_shipping_outlined;
      default:
        return Icons.pending_outlined;
    }
  }

  void _verDetalles(Map<String, dynamic> pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DetallesPedidoSheet(
        pedido: pedido,
        dataService: _dataService,
        onPedidoCancelado: () => _cancelarPedido(pedido),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = _pedidosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          )
        ],
      ),
      body: Column(
        children: [
          if (_tiendas.isNotEmpty)
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FiltroChip(
                      label: 'Todas',
                      selected: _filtroTienda == 'all',
                      onTap: () => setState(() => _filtroTienda = 'all'),
                    ),
                    ..._tiendas.map((t) => _FiltroChip(
                          label: t['nombre_negocio'] ?? 'Tienda',
                          selected: _filtroTienda == t['id'],
                          onTap: () =>
                              setState(() => _filtroTienda = t['id']),
                        )),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : pedidos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 72, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'A\u00fan no tienes pedidos',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tus pedidos aparecer\u00e1n aqu\u00ed una vez que los hagas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: pedidos.length,
                          itemBuilder: (ctx, i) {
                            final pedido = pedidos[i];
                            final estado = pedido['estado'] ?? 'pendiente';
                            final fecha =
                                DateTime.tryParse(pedido['fecha'] ?? '') ??
                                    DateTime.now();
                            final total =
                                (pedido['total'] as num?)?.toDouble() ?? 0.0;
                            final negocioNombre =
                                pedido['negocios']?['nombre_negocio'] ??
                                    'Tienda';

                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _verDetalles(pedido),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _colorEstado(estado)
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _iconEstado(estado),
                                          color: _colorEstado(estado),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              negocioNombre,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat('dd/MM/yyyy HH:mm')
                                                  .format(fecha),
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 13),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _colorEstado(estado)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                estado.replaceAll('_', ' '),
                                                style: TextStyle(
                                                  color:
                                                      _colorEstado(estado),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\$${total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Icon(Icons.chevron_right,
                                              color: Colors.grey),
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
          ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FiltroChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

// ─── Bottom sheet detalles ──────────────────────────────────────────────────

class _DetallesPedidoSheet extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final DataService dataService;
  final VoidCallback onPedidoCancelado;

  const _DetallesPedidoSheet({
    required this.pedido,
    required this.dataService,
    required this.onPedidoCancelado,
  });

  @override
  State<_DetallesPedidoSheet> createState() => _DetallesPedidoSheetState();
}

class _DetallesPedidoSheetState extends State<_DetallesPedidoSheet> {
  List<Map<String, dynamic>> _detalles = [];
  bool _isLoading = true;
  bool _actionsLoading = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final detalles = await widget.dataService
          .getDetallesPedido(widget.pedido['id']);
      if (mounted) setState(() => _detalles = detalles);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _puedeCancelar {
    final estado = widget.pedido['estado'] ?? 'pendiente';
    return estado == 'pendiente' || estado == 'en_proceso';
  }

  Future<void> _cancelar() async {
    if (_actionsLoading) return;
    setState(() => _actionsLoading = true);
    try {
      await widget.dataService.cancelarPedido(widget.pedido['id']);
      if (mounted) {
        Navigator.pop(context);
        widget.onPedidoCancelado();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionsLoading = false);
    }
  }

  Future<void> _imprimirRecibo() async {
    if (_actionsLoading) return;
    setState(() => _actionsLoading = true);
    try {
      final negocioId = widget.pedido['user_id'] as String?;
      final negocio = negocioId != null
          ? await widget.dataService.getNegocioById(negocioId)
          : null;
      await PdfService.imprimirRecibo(
        pedido: widget.pedido,
        detalles: _detalles,
        negocio: negocio,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionsLoading = false);
    }
  }

  Future<void> _imprimirPdf() async {
    if (_actionsLoading) return;
    setState(() => _actionsLoading = true);
    try {
      final negocioId = widget.pedido['user_id'] as String?;
      final negocio = negocioId != null
          ? await widget.dataService.getNegocioById(negocioId)
          : null;
      await PdfService.imprimirPdf(
        pedido: widget.pedido,
        detalles: _detalles,
        negocio: negocio,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;
    final fecha = DateTime.tryParse(pedido['fecha'] ?? '') ?? DateTime.now();
    final estado = pedido['estado'] ?? 'pendiente';
    final negocio = pedido['negocios']?['nombre_negocio'] ?? 'Tienda';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(negocio,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(fecha),
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(estado.replaceAll('_', ' ')),
                    backgroundColor:
                        _estadoColor(estado).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                        color: _estadoColor(estado),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Productos',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView.builder(
                        controller: controller,
                        itemCount: _detalles.length,
                        itemBuilder: (_, i) {
                          final d = _detalles[i];
                          final nombre =
                              d['productos']?['nombre'] ?? 'Producto';
                          final cant = d['cantidad'] ?? 1;
                          final precio =
                              (d['precio_unitario'] as num?)?.toDouble() ??
                                  0.0;
                          final sub =
                              (d['subtotal'] as num?)?.toDouble() ?? 0.0;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text(
                                '$cant \u00d7 \$${precio.toStringAsFixed(2)}'),
                            trailing: Text('\$${sub.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Color(0xFF1E3A8A))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  if (_puedeCancelar)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _actionsLoading ? null : _cancelar,
                        icon: const Icon(Icons.cancel_outlined,
                            size: 18),
                        label: const Text('Cancelar',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                        ),
                      ),
                    ),
                  if (_puedeCancelar) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _actionsLoading ? null : _imprimirRecibo,
                      icon: const Icon(Icons.receipt_long_outlined,
                          size: 18),
                      label: const Text('Recibo',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(
                            color: Color(0xFF1E3A8A)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _actionsLoading ? null : _imprimirPdf,
                      icon: const Icon(Icons.picture_as_pdf,
                          size: 18),
                      label: const Text('PDF',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(
                            color: Color(0xFF1E3A8A)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Color _estadoColor(String e) {
    switch (e) {
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'en_proceso':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
