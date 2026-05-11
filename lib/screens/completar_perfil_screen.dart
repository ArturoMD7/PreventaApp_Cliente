import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/data_service.dart';
import 'vinculacion_screen.dart';
import 'package:latlong2/latlong.dart';
import 'seleccionar_ubicacion_screen.dart';

/// Pantalla que se muestra UNA SOLA VEZ cuando el usuario recién se registra.
/// Pide: nombre, teléfono y dirección. Estos datos serán compartidos
/// en todas las tiendas a las que se vincule.
class CompletarPerfilScreen extends StatefulWidget {
  const CompletarPerfilScreen({super.key});

  @override
  State<CompletarPerfilScreen> createState() => _CompletarPerfilScreenState();
}

class _CompletarPerfilScreenState extends State<CompletarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataService = DataService();

  late final TextEditingController _nombreCtrl;
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  double? _latitud;
  double? _longitud;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-llenar nombre desde Google
    final fullName = Supabase.instance.client.auth.currentUser
            ?.userMetadata?['full_name'] as String? ??
        '';
    _nombreCtrl = TextEditingController(text: fullName);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirMapa() async {
    LatLng? inicial;
    if (_latitud != null && _longitud != null) {
      inicial = LatLng(_latitud!, _longitud!);
    }
    final LatLng? seleccion = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SeleccionarUbicacionScreen(ubicacionInicial: inicial),
      ),
    );
    if (seleccion != null) {
      setState(() {
        _latitud = seleccion.latitude;
        _longitud = seleccion.longitude;
      });
    }
  }

  Future<void> _guardarYContinuar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Guardar perfil en SharedPreferences (aún sin tienda vinculada,
      // se insertará en clientes cuando se vincule a una tienda)
      await _dataService.guardarPerfilLocal(
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        latitud: _latitud,
        longitud: _longitud,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VinculacionScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Completa tu perfil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta información se compartirá con los proveedores\na los que te vincules para que puedan identificarte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 36),

                // Nombre
                TextFormField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 16),

                // Teléfono
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: 'Ej. 8712345678',
                  ),
                ),
                const SizedBox(height: 16),

                // Dirección
                TextFormField(
                  controller: _direccionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.home_outlined),
                    hintText: 'Ej. Calle 5 de Mayo #12, Col. Centro',
                  ),
                ),
                const SizedBox(height: 16),

                // Botón mapa
                OutlinedButton.icon(
                  onPressed: _abrirMapa,
                  icon: Icon(
                    _latitud != null ? Icons.edit_location_alt : Icons.map,
                    color: _latitud != null
                        ? Colors.green[700]
                        : theme.colorScheme.primary,
                  ),
                  label: Text(
                    _latitud != null
                        ? '📍 Ubicación capturada  •  Toca para cambiar'
                        : 'Fijar ubicación en el mapa (opcional)',
                    style: TextStyle(
                      color: _latitud != null
                          ? Colors.green[700]
                          : theme.colorScheme.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _latitud != null ? Colors.green : Colors.grey.shade400,
                    ),
                    backgroundColor:
                        _latitud != null ? Colors.green.shade50 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 36),

                // Botón continuar
                _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _guardarYContinuar,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Guardar y continuar'),
                      ),

                const SizedBox(height: 16),
                // Opción para omitir
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => const VinculacionScreen()),
                          );
                        },
                  child: const Text('Omitir por ahora',
                      style: TextStyle(color: Colors.black45)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
