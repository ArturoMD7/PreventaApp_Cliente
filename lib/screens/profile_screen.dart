import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../services/data_service.dart';
import 'seleccionar_ubicacion_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataService = DataService();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  double? _latitud;
  double? _longitud;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _isLoading = true);
    try {
      final perfil = await _dataService.getMiPerfil();
      if (perfil != null) {
        _nombreController.text = perfil['nombre'] ?? '';
        _telefonoController.text = perfil['telefono_real'] ?? '';
        _direccionController.text = perfil['direccion'] ?? '';
        _latitud = perfil['latitud']?.toDouble();
        _longitud = perfil['longitud']?.toDouble();
      } else {
        // Pre-llenar con nombre de Google si existe
        final user = Supabase.instance.client.auth.currentUser;
        _nombreController.text =
            user?.userMetadata?['full_name'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirMapa() async {
    LatLng? inicial;
    if (_latitud != null && _longitud != null) {
      inicial = LatLng(_latitud!, _longitud!);
    }

    final LatLng? seleccion = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SeleccionarUbicacionScreen(ubicacionInicial: inicial),
      ),
    );

    if (seleccion != null) {
      setState(() {
        _latitud = seleccion.latitude;
        _longitud = seleccion.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ubicación capturada ✓'),
              backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      await _dataService.updateProfile(
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
        latitud: _latitud,
        longitud: _longitud,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Perfil actualizado correctamente!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // regresa con señal de que actualizó
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatar = user?.userMetadata?['avatar_url'] as String?;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        backgroundImage:
                            avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? Text(
                                (_nombreController.text.isNotEmpty
                                        ? _nombreController.text[0]
                                        : '?')
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 40,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(email,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                    ),
                    const SizedBox(height: 32),

                    // Nombre
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'El nombre es requerido'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // Teléfono
                    TextFormField(
                      controller: _telefonoController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Dirección descriptiva
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección descriptiva',
                        hintText: 'Ej. Calle 5 de Mayo #12, Col. Centro',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Botón mapa
                    OutlinedButton.icon(
                      onPressed: _abrirMapa,
                      icon: Icon(
                        _latitud != null ? Icons.edit_location_alt : Icons.map,
                        color: _latitud != null
                            ? Colors.green[700]
                            : Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        _latitud != null
                            ? 'Ubicación guardada  •  Toca para cambiar'
                            : 'Fijar ubicación en el mapa',
                        style: TextStyle(
                          color: _latitud != null
                              ? Colors.green[700]
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _latitud != null
                              ? Colors.green
                              : Colors.grey.shade400,
                        ),
                        backgroundColor: _latitud != null
                            ? Colors.green.shade50
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    if (_latitud != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '📍 Lat: ${_latitud!.toStringAsFixed(5)}, Lon: ${_longitud!.toStringAsFixed(5)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.green[700], fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Guardar
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _guardar,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar cambios'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
