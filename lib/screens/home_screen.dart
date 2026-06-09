import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/negocio.dart';
import 'login_screen.dart';
import 'vinculacion_screen.dart';
import 'profile_screen.dart';
import 'stores_screen.dart';
import 'order_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  // Nombre del usuario para el drawer
  String _nombreUsuario = '';
  String _emailUsuario = '';
  String? _avatarUrl;

  // Carrito: Map<Producto ID, Map<String, dynamic>{producto, cantidad}>
  final Map<String, Map<String, dynamic>> _carrito = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    // Iniciar notificaciones vía Supabase Realtime
    NotificationService().init();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      _emailUsuario = user?.email ?? '';
      _avatarUrl = user?.userMetadata?['avatar_url'] as String?;

      // Cargar nombre del perfil
      final perfil = await _dataService.getMiPerfil();
      _nombreUsuario =
          perfil?['nombre'] ?? user?.userMetadata?['full_name'] ?? 'Mi perfil';

      final negocio = await _dataService.getNegocio();
      if (negocio == null) {
        setState(() {
          _negocio = null;
          _productos = [];
          _categorias = [];
          _productosFiltrados = [];
        });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _productosFiltrados =
          _productos.where((p) {
            final coincideTexto = p.nombre.toLowerCase().contains(
              _filtroBusqueda.toLowerCase(),
            );
            final coincideCat =
                _categoriaSeleccionada == null ||
                _categoriaSeleccionada == 'Todas' ||
                p.categoriaId == _categoriaSeleccionada;
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
        _carrito[producto.id!] = {'producto': producto, 'cantidad': 1};
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double total = 0;
            _carrito.forEach((key, item) {
              total +=
                  (item['producto'] as Producto).precio *
                  (item['cantidad'] as int);
            });

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mi Carrito',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  if (_carrito.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'El carrito está vacío',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _carrito.length,
                        itemBuilder: (context, index) {
                          final key = _carrito.keys.elementAt(index);
                          final item = _carrito[key]!;
                          final prod = item['producto'] as Producto;
                          final cant = item['cantidad'] as int;

                          return ListTile(
                            title: Text(
                              prod.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '\$${prod.precio.toStringAsFixed(2)} c/u',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setModalState(() {
                                      setState(() {
                                        if (cant > 1) {
                                          _carrito[key]!['cantidad'] =
                                              (cant) - 1;
                                        } else {
                                          _carrito.remove(key);
                                        }
                                      });
                                    });
                                  },
                                ),
                                Text(
                                  '$cant',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setModalState(() {
                                      setState(() {
                                        _carrito[key]!['cantidad'] = cant + 1;
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
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _carrito.isEmpty
                              ? null
                              : () async {
                                Navigator.pop(context);
                                await _enviarPedido(total);
                              },
                      child: const Text('Enviar Pedido al Proveedor'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _enviarPedido(double total) async {
    setState(() => _isLoading = true);
    try {
      final items = _carrito.values.toList();
      await _dataService.hacerPedido(items, total);

      setState(() => _carrito.clear());

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('¡Pedido Enviado! 🎉'),
                content: const Text(
                  'Tu pedido ha sido enviado al proveedor con éxito.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Drawer ──────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Encabezado
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            accountName: Text(
              _nombreUsuario.isNotEmpty ? _nombreUsuario : 'Mi Perfil',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(_emailUsuario),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage:
                  _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child:
                  _avatarUrl == null
                      ? Text(
                        (_nombreUsuario.isNotEmpty ? _nombreUsuario[0] : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                      : null,
            ),
          ),

          // Tienda actual
          if (_negocio != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tienda activa',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          _negocio!.nombreNegocio,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          const Divider(),

          // Opciones
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mi Perfil'),
            onTap: () async {
              Navigator.pop(context);
              final updated = await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              if (updated == true) _cargarDatos();
            },
          ),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Mis Tiendas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const StoresScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Mis Pedidos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              );
            },
          ),

          const Divider(),
          const Spacer(),

          // Cerrar sesión
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSinProveedor() {
    return Column(
      children: [
        // Banner persistente de recordatorio
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No tienes ningún proveedor vinculado. Agrega al menos uno para ver productos y hacer pedidos.',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Estado vacío centrado
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sin proveedor',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vincula un proveedor para acceder a su catálogo de productos y empezar a hacer tus pedidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VinculacionScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Vincular un proveedor'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StoresScreen()),
                      );
                    },
                    icon: const Icon(Icons.store_outlined, size: 18),
                    label: const Text('Ir a Mis Tiendas'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalItemsCarrito = _carrito.values.fold(
      0,
      (sum, item) => sum + (item['cantidad'] as int),
    );

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text(_negocio?.nombreNegocio ?? 'Sin proveedor'),
        actions: [
          // Cambio rápido de tienda
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Agregar Tienda',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const StoresScreen()));
            },
          ),
        ],
      ),
      floatingActionButton:
          _negocio != null
              ? FloatingActionButton.extended(
                onPressed: _mostrarCarrito,
                icon: const Icon(Icons.shopping_cart),
                label: Text('Carrito ($totalItemsCarrito)'),
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _negocio == null
              ? _buildSinProveedor()
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
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('Todas'),
                              selected:
                                  _categoriaSeleccionada == null ||
                                  _categoriaSeleccionada == 'Todas',
                              onSelected: (selected) {
                                setState(() {
                                  _categoriaSeleccionada = 'Todas';
                                  _aplicarFiltros();
                                });
                              },
                            ),
                          ),
                          ..._categorias.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat.nombre),
                                selected: _categoriaSeleccionada == cat.id,
                                onSelected: (selected) {
                                  setState(() {
                                    _categoriaSeleccionada =
                                        selected ? cat.id : 'Todas';
                                    _aplicarFiltros();
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Grid de Productos
                  Expanded(
                    child:
                        _productosFiltrados.isEmpty
                            ? const Center(
                              child: Text('No se encontraron productos'),
                            )
                            : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.75,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: _productosFiltrados.length,
                              itemBuilder: (context, index) {
                                final prod = _productosFiltrados[index];
                                final enCarrito =
                                    _carrito.containsKey(prod.id)
                                        ? _carrito[prod.id]!['cantidad'] as int
                                        : 0;

                                return Card(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(16),
                                                    ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  size: 64,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                            if (enCarrito > 0)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$enCarrito',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prod.nombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '\$${prod.precio.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            ElevatedButton(
                                              onPressed:
                                                  () => _agregarAlCarrito(prod),
                                              style: ElevatedButton.styleFrom(
                                                minimumSize: const Size(
                                                  double.infinity,
                                                  36,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
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
