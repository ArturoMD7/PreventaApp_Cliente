import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _dataService = DataService();
  List<Map<String, dynamic>> _pedidos = [];
  bool _isLoading = true;
  String _filtroTienda = 'all'; // 'all' | <provider_id>
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
      setState(() {
        _tiendas = tiendas;
        _pedidos = pedidos;
      });
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
          // Filtro por tienda
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

          // Lista
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
                              'Aún no tienes pedidos',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tus pedidos aparecerán aquí una vez que los hagas.',
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
                                              .withOpacity(0.1),
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
                                                    .withOpacity(0.12),
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

// ─── Widget filtro chip ─────────────────────────────────────────────────────

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

  const _DetallesPedidoSheet(
      {required this.pedido, required this.dataService});

  @override
  State<_DetallesPedidoSheet> createState() => _DetallesPedidoSheetState();
}

class _DetallesPedidoSheetState extends State<_DetallesPedidoSheet> {
  List<Map<String, dynamic>> _detalles = [];
  bool _isLoading = true;

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
      builder: (_, controller) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
              backgroundColor: _estadoColor(estado).withOpacity(0.15),
              labelStyle: TextStyle(
                  color: _estadoColor(estado),
                  fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            const Text('Productos',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
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
                              '$cant × \$${precio.toStringAsFixed(2)}'),
                          trailing: Text('\$${sub.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
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
          ],
        ),
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
