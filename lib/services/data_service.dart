import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/negocio.dart';

class DataService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _providerKey = 'provider_id';

  Future<void> setProviderId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, id);
  }

  Future<String?> getProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey);
  }

  Future<void> clearProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerKey);
  }

  Future<Negocio?> getNegocio() async {
    final providerId = await getProviderId();
    if (providerId == null) return null;

    final response = await _supabase
        .from('negocios')
        .select()
        .eq('id', providerId)
        .maybeSingle();

    if (response != null) {
      return Negocio.fromMap(response);
    }
    return null;
  }

  Future<List<Producto>> getProductos() async {
    final providerId = await getProviderId();
    if (providerId == null) return [];

    final response = await _supabase
        .from('productos')
        .select()
        .eq('user_id', providerId)
        .order('nombre', ascending: true);
        
    return (response as List).map((map) => Producto.fromMap(map)).toList();
  }

  Future<List<Categoria>> getCategorias() async {
    final providerId = await getProviderId();
    if (providerId == null) return [];

    final response = await _supabase
        .from('categorias')
        .select()
        .eq('user_id', providerId)
        .order('nombre', ascending: true);
        
    return (response as List).map((map) => Categoria.fromMap(map)).toList();
  }

  Future<void> hacerPedido(List<Map<String, dynamic>> items, double total) async {
    final providerId = await getProviderId();
    if (providerId == null) throw Exception('No hay proveedor vinculado');
    
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('No has iniciado sesión');

    // Primero verificamos si el cliente actual (usuario de esta app)
    // está registrado en la tabla "clientes" del proveedor.
    // Si no está, lo registramos.
    final clienteRes = await _supabase
        .from('clientes')
        .select()
        .eq('user_id', providerId)
        .eq('telefono', userId) // Guardaremos el userId de Supabase temporalmente en el campo telefono o similar para identificarlo
        .maybeSingle();

    String clienteId;
    
    if (clienteRes == null) {
      // Registrar al cliente
      final nuevoCliente = await _supabase.from('clientes').insert({
        'user_id': providerId,
        'nombre': _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'Cliente Nuevo',
        'telefono': userId, // Guardamos su UUID de Supabase para enlazarlo luego
      }).select().single();
      
      clienteId = nuevoCliente['id'];
    } else {
      clienteId = clienteRes['id'];
    }

    // Insertar venta (estado 'pendiente')
    final ventaRes = await _supabase.from('ventas').insert({
      'user_id': providerId,
      'cliente_id': clienteId,
      'fecha': DateTime.now().toIso8601String(),
      'total': total,
      'estado': 'pendiente',
    }).select().single();

    final ventaId = ventaRes['id'];

    // Insertar detalles
    for (var item in items) {
      final Producto prod = item['producto'];
      final int cantidad = item['cantidad'];
      final double subtotal = prod.precio * cantidad;

      await _supabase.from('detalles_venta').insert({
        'venta_id': ventaId,
        'producto_id': prod.id,
        'cantidad': cantidad,
        'precio_unitario': prod.precio,
        'subtotal': subtotal,
      });
    }
  }
}
