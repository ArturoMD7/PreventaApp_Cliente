import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VinculacionScreen extends StatefulWidget {
  const VinculacionScreen({Key? key}) : super(key: key);

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
    _checkExistingProvider();
  }

  Future<void> _checkExistingProvider() async {
    final providerId = await _dataService.getProviderId();
    if (providerId != null && providerId.isNotEmpty) {
      // Ya tiene un proveedor vinculado
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
        const SnackBar(content: Text('Por favor, ingresa un código válido'), backgroundColor: Colors.orange),
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

      await _dataService.setProviderId(codigo);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vinculado a: ${response['nombre_negocio']}'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
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
        title: const Text('Vincular Proveedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // Volverá automáticamente al LoginScreen debido a la suscripción en auth_service o main
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 80, color: Color(0xFF1E3A8A)),
              const SizedBox(height: 24),
              const Text(
                '¡Bienvenido!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
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
                  : ElevatedButton(
                      onPressed: _vincular,
                      child: const Text('Vincular y Entrar'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
