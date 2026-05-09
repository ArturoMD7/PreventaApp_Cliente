import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/data_service.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/negocio.dart';
import 'login_screen.dart';
import 'vinculacion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  bool _isLoading = true;
  Negocio? _negocio;
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  List<Categoria> _categorias = [];
  String _filtroBusqueda = '';
  String? _categoriaSeleccionada;

  // Carrito: Map<Producto ID, Map<String, dynamic>{producto, cantidad}>
  final Map<String, Map<String, dynamic>> _carrito = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final negocio = await _dataService.getNegocio();
      if (negocio == null) {
        // El proveedor no existe o fue desvinculado
        await _dataService.clearProviderId();
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VinculacionScreen()));
        }
        return;
      }

      final productos = await _dataService.getProductos();
      final categorias = await _dataService.getCategorias();

      setState(() {
        _negocio = negocio;
        _productos = productos;
        _categorias = categorias;
        _productosFiltrados = productos;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _productosFiltrados = _productos.where((p) {
        final coincideTexto = p.nombre.toLowerCase().contains(_filtroBusqueda.toLowerCase());
        final coincideCat = _categoriaSeleccionada == null || _categoriaSeleccionada == 'Todas' || p.categoriaId == _categoriaSeleccionada;
        return coincideTexto && coincideCat;
      }).toList();
    });
  }

  void _agregarAlCarrito(Producto producto) {
    setState(() {
      if (_carrito.containsKey(producto.id)) {
        final item = _carrito[producto.id!]!;
        item['cantidad'] = (item['cantidad'] as int) + 1;
      } else {
        _carrito[producto.id!] = {
          'producto': producto,
          'cantidad': 1,
        };
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto.nombre} agregado al carrito'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _mostrarCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double total = 0;
            _carrito.forEach((key, item) {
              total += (item['producto'] as Producto).precio * (item['cantidad'] as int);
            });

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24, left: 16, right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Mi Carrito', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (_carrito.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('El carrito está vacío', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _carrito.length,
                        itemBuilder: (context, index) {
                          final key = _carrito.keys.elementAt(index);
                          final item = _carrito[key]!;
                          final prod = item['producto'] as Producto;
                          final cant = item['cantidad'] as int;

                          return ListTile(
                            title: Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('\$${prod.precio.toStringAsFixed(2)} c/u'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setModalState(() {
                                      setState(() {
                                        if (cant > 1) {
                                          final item = _carrito[key]!;
                                          item['cantidad'] = (item['cantidad'] as int) - 1;
                                        } else {
                                          _carrito.remove(key);
                                        }
                                      });
                                    });
                                  },
                                ),
                                Text('$cant', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setModalState(() {
                                      setState(() {
                                        final item = _carrito[key]!;
                                        item['cantidad'] = (item['cantidad'] as int) + 1;
                                      });
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carrito.isEmpty ? null : () async {
                        Navigator.pop(context); // Cerrar bottom sheet
                        await _enviarPedido(total);
                      },
                      child: const Text('Enviar Pedido al Proveedor'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _enviarPedido(double total) async {
    setState(() => _isLoading = true);
    try {
      final items = _carrito.values.toList();
      await _dataService.hacerPedido(items, total);
      
      setState(() {
        _carrito.clear();
      });
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¡Pedido Enviado!'),
            content: const Text('Tu pedido ha sido enviado al proveedor con éxito.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Aceptar'),
              )
            ],
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar pedido: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalItemsCarrito = _carrito.values.fold(0, (sum, item) => sum + (item['cantidad'] as int));

    return Scaffold(
      appBar: AppBar(
        title: Text(_negocio?.nombreNegocio ?? 'Catálogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Cambiar Proveedor',
            onPressed: () async {
              await _dataService.clearProviderId();
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VinculacionScreen()));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarCarrito,
        icon: const Icon(Icons.shopping_cart),
        label: Text('Carrito ($totalItemsCarrito)'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar producto...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    _filtroBusqueda = val;
                    _aplicarFiltros();
                  },
                ),
              ),
              
              // Categorías
              if (_categorias.isNotEmpty)
                Container(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todas'),
                          selected: _categoriaSeleccionada == null || _categoriaSeleccionada == 'Todas',
                          onSelected: (selected) {
                            setState(() {
                              _categoriaSeleccionada = 'Todas';
                              _aplicarFiltros();
                            });
                          },
                        ),
                      ),
                      ..._categorias.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.nombre),
                          selected: _categoriaSeleccionada == cat.id,
                          onSelected: (selected) {
                            setState(() {
                              _categoriaSeleccionada = selected ? cat.id : 'Todas';
                              _aplicarFiltros();
                            });
                          },
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              
              const SizedBox(height: 8),

              // Grid de Productos
              Expanded(
                child: _productosFiltrados.isEmpty
                  ? const Center(child: Text('No se encontraron productos'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) {
                        final prod = _productosFiltrados[index];
                        return Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: const Icon(Icons.image, size: 64, color: Colors.grey),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prod.nombre,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${prod.precio.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () => _agregarAlCarrito(prod),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 36),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      child: const Text('Agregar'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}
