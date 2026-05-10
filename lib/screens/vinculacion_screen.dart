import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VinculacionScreen extends StatefulWidget {
  /// Si [isAdding] es true, se muestra como pantalla de "agregar tienda"
  /// sin redirigir automáticamente (para usuarios que ya tienen proveedor).
  final bool isAdding;

  const VinculacionScreen({Key? key, this.isAdding = false}) : super(key: key);

  @override
  _VinculacionScreenState createState() => _VinculacionScreenState();
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

  Future<void> _checkExistingProvider() async {
    final providerId = await _dataService.getProviderId();
    if (providerId != null && providerId.isNotEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
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
      // Verificar si el negocio existe
      final response = await Supabase.instance.client
          .from('negocios')
          .select()
          .eq('id', codigo)
          .maybeSingle();

      if (response == null) {
        throw Exception('El código no es válido o el proveedor no existe.');
      }

      // Obtener perfil del usuario para pre-registrarlo en la nueva tienda
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final perfil = await _dataService.getMiPerfil();
        final nombre = perfil?['nombre'] ??
            Supabase.instance.client.auth.currentUser
                ?.userMetadata?['full_name'] ??
            'Cliente Nuevo';

        // Verificar si ya existe en esta tienda
        final clienteExistente = await Supabase.instance.client
            .from('clientes')
            .select()
            .eq('user_id', codigo)
            .eq('telefono', userId)
            .maybeSingle();

        if (clienteExistente == null) {
          // Registrarlo automáticamente en la nueva tienda
          await Supabase.instance.client.from('clientes').insert({
            'user_id': codigo,
            'nombre': nombre,
            'telefono': userId,
            'direccion': perfil?['direccion'],
            'latitud': perfil?['latitud'],
            'longitud': perfil?['longitud'],
          });
        }
      }

      await _dataService.setProviderId(codigo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('¡Vinculado a: ${response['nombre_negocio']}!'),
              backgroundColor: Colors.green),
        );

        if (widget.isAdding) {
          // Solo regresar si estamos en modo "agregar"
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
          SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.red),
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
                  hintText: 'Ej. a1b2c3d4-e5f6-7g8h...',
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
