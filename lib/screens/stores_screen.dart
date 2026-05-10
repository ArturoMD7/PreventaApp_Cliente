import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'home_screen.dart';
import 'vinculacion_screen.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({Key? key}) : super(key: key);

  @override
  _StoresScreenState createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final _dataService = DataService();
  List<Map<String, dynamic>> _tiendas = [];
  String? _tiendaActualId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final tiendas = await _dataService.getLinkedProviders();
      final current = await _dataService.getProviderId();
      setState(() {
        _tiendas = tiendas;
        _tiendaActualId = current;
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

  Future<void> _seleccionarTienda(String providerId) async {
    await _dataService.setProviderId(providerId);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _desvincularTienda(Map<String, dynamic> tienda) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desvincular tienda'),
        content: Text(
            '¿Deseas desvincular de "${tienda['nombre_negocio']}"? No podrás ver su catálogo ni hacer pedidos hasta volver a vincularte.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desvincular',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dataService.desvincularProveedor(tienda['id']);
      // Si era la tienda activa, limpiar
      if (_tiendaActualId == tienda['id']) {
        await _dataService.clearProviderId();
      }
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tienda desvinculada'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tiendas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const VinculacionScreen(isAdding: true)),
          );
          _cargar();
        },
        icon: const Icon(Icons.add_business),
        label: const Text('Vincular nueva tienda'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tiendas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No tienes tiendas vinculadas',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text(
                        'Usa el botón de abajo para vincular\ntu primer proveedor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
                  itemCount: _tiendas.length,
                  itemBuilder: (ctx, i) {
                    final tienda = _tiendas[i];
                    final isActiva = tienda['id'] == _tiendaActualId;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            (tienda['nombre_negocio'] as String? ?? 'T')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                                child: Text(
                              tienda['nombre_negocio'] ?? 'Tienda',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            )),
                            if (isActiva)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Activa',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        subtitle: isActiva
                            ? const Text('Tienda seleccionada actualmente')
                            : const Text('Toca para cambiar a esta tienda'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'select') _seleccionarTienda(tienda['id']);
                            if (val == 'unlink') _desvincularTienda(tienda);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'select',
                                child: ListTile(
                                    leading: Icon(Icons.storefront),
                                    title: Text('Ir a esta tienda'),
                                    contentPadding: EdgeInsets.zero)),
                            const PopupMenuItem(
                                value: 'unlink',
                                child: ListTile(
                                    leading: Icon(Icons.link_off,
                                        color: Colors.red),
                                    title: Text('Desvincular',
                                        style:
                                            TextStyle(color: Colors.red)),
                                    contentPadding: EdgeInsets.zero)),
                          ],
                        ),
                        onTap: isActiva
                            ? null
                            : () => _seleccionarTienda(tienda['id']),
                      ),
                    );
                  },
                ),
    );
  }
}
