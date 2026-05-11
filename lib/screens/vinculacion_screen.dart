import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/data_service.dart';
import 'home_screen.dart';

class VinculacionScreen extends StatefulWidget {
  /// Si [isAdding] es true, se muestra como pantalla de "agregar tienda"
  /// sin redirigir automáticamente.
  final bool isAdding;

  const VinculacionScreen({super.key, this.isAdding = false});

  @override
  State<VinculacionScreen> createState() => _VinculacionScreenState();
}

class _VinculacionScreenState extends State<VinculacionScreen> {
  final _codigoController = TextEditingController();
  final _dataService = DataService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAdding) {
      _checkExistingProvider();
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  /// Verifica si ya hay proveedor guardado Y si el cliente está registrado en él.
  /// Si ya están registrados, va directo a HomeScreen.
  /// Si tiene proveedor pero no registro, lo registra antes de ir.
  Future<void> _checkExistingProvider() async {
    final providerId = await _dataService.getProviderId();
    if (providerId == null || providerId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Verificar si ya está registrado en esa tienda
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final existente = await Supabase.instance.client
            .from('clientes')
            .select('id')
            .eq('user_id', providerId)
            .eq('telefono', userId)
            .maybeSingle();

        if (existente == null) {
          // Tiene el proveedor guardado pero nunca quedó registrado → registrar ahora
          final perfil = await _dataService.getMiPerfil();
          if (perfil != null) {
            await _dataService.registrarClienteEnTienda(
              providerId: providerId,
              nombre: perfil['nombre'] ??
                  Supabase.instance.client.auth.currentUser
                      ?.userMetadata?['full_name'] ??
                  'Cliente',
              telefonoReal: perfil['telefono_real'],
              direccion: perfil['direccion'],
              latitud: (perfil['latitud'] as num?)?.toDouble(),
              longitud: (perfil['longitud'] as num?)?.toDouble(),
            );
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      // Si falla, simplemente mostrar la pantalla de vinculación
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vincular() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, ingresa un código válido'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verificar que el negocio existe
      final negocio = await Supabase.instance.client
          .from('negocios')
          .select()
          .eq('id', codigo)
          .maybeSingle();

      if (negocio == null) {
        throw Exception('El código no es válido o el proveedor no existe.');
      }

      final nombreNegocio = negocio['nombre_negocio'] as String? ?? 'la tienda';

      // 2. Obtener perfil (de Supabase o local)
      final perfil = await _dataService.getMiPerfil();
      final nombre = perfil?['nombre'] ??
          Supabase.instance.client.auth.currentUser
              ?.userMetadata?['full_name'] ??
          'Cliente';

      // 3. Registrar en la tienda (idempotente)
      await _dataService.registrarClienteEnTienda(
        providerId: codigo,
        nombre: nombre,
        telefonoReal: perfil?['telefono_real'],
        direccion: perfil?['direccion'],
        latitud: (perfil?['latitud'] as num?)?.toDouble(),
        longitud: (perfil?['longitud'] as num?)?.toDouble(),
      );

      // 4. Guardar proveedor activo
      await _dataService.setProviderId(codigo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('¡Vinculado a: $nombreNegocio!'),
              backgroundColor: Colors.green),
        );

        if (widget.isAdding) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdding ? 'Agregar Tienda' : 'Vincular Proveedor'),
        actions: [
          if (!widget.isAdding)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                widget.isAdding
                    ? Icons.add_business_outlined
                    : Icons.storefront,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                widget.isAdding ? 'Nueva Tienda' : '¡Bienvenido!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ingresa el Código de Proveedor para acceder a su catálogo de productos y hacer tus pedidos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codigoController,
                decoration: const InputDecoration(
                  labelText: 'Código de Proveedor',
                  prefixIcon: Icon(Icons.qr_code),
                  hintText: 'Ej. a1b2c3d4-e5f6-7890...',
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _vincular,
                      icon: const Icon(Icons.link),
                      label: Text(widget.isAdding
                          ? 'Vincular nueva tienda'
                          : 'Vincular y Entrar'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
