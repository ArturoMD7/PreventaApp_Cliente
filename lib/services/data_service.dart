import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/negocio.dart';

class DataService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _providerKey = 'provider_id';

  // ─────────────────────────────────────────────────────────────
  // SharedPreferences: proveedor activo
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  // NEGOCIO (tienda activa)
  // ─────────────────────────────────────────────────────────────

  Future<Negocio?> getNegocio() async {
    final providerId = await getProviderId();
    if (providerId == null) return null;

    final response = await _supabase
        .from('negocios')
        .select()
        .eq('id', providerId)
        .maybeSingle();

    return response != null ? Negocio.fromMap(response) : null;
  }

  // ─────────────────────────────────────────────────────────────
  // MÚLTIPLES TIENDAS
  // ─────────────────────────────────────────────────────────────

  /// Devuelve todos los negocios a los que este usuario está vinculado
  /// (buscando registros en `clientes` donde telefono = auth.uid())
  Future<List<Map<String, dynamic>>> getLinkedProviders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Obtenemos todos los registros de clientes cuyo "telefono" es nuestro userId
    final clienteRows = await _supabase
        .from('clientes')
        .select('user_id')
        .eq('telefono', userId);

    if ((clienteRows as List).isEmpty) return [];

    final providerIds =
        clienteRows.map((c) => c['user_id'] as String).toSet().toList();

    // Traemos info de esos negocios
    final negocios = await _supabase
        .from('negocios')
        .select()
        .inFilter('id', providerIds);

    return (negocios as List).cast<Map<String, dynamic>>();
  }

  /// Desvincula al usuario de un proveedor eliminando su registro de clientes
  Future<void> desvincularProveedor(String providerId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('clientes')
        .delete()
        .eq('user_id', providerId)
        .eq('telefono', userId);
  }

  // ─────────────────────────────────────────────────────────────
  // PRODUCTOS Y CATEGORÍAS
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  // PERFIL DEL CLIENTE
  // ─────────────────────────────────────────────────────────────

  /// Obtiene el perfil del usuario leyendo cualquiera de sus registros en `clientes`
  Future<Map<String, dynamic>?> getMiPerfil() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('clientes')
        .select()
        .eq('telefono', userId)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;

    // Separamos el teléfono real (que puede haber sido guardado aparte)
    return {
      'nombre': row['nombre'],
      'telefono_real': row['telefono_real'] ?? '',
      'direccion': row['direccion'],
      'latitud': row['latitud'],
      'longitud': row['longitud'],
    };
  }

  /// Actualiza el perfil en TODOS los registros de clientes del usuario
  Future<void> updateProfile({
    required String nombre,
    String? telefono,
    String? direccion,
    double? latitud,
    double? longitud,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('No has iniciado sesión');

    await _supabase
        .from('clientes')
        .update({
          'nombre': nombre,
          'telefono_real': telefono,
          'direccion': direccion,
          'latitud': latitud,
          'longitud': longitud,
        })
        .eq('telefono', userId);
  }

  // ─────────────────────────────────────────────────────────────
  // PEDIDOS
  // ─────────────────────────────────────────────────────────────

  /// Obtiene todos los pedidos del usuario en todas sus tiendas
  Future<List<Map<String, dynamic>>> getMisPedidos() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Primero obtenemos los IDs de cliente en todas las tiendas
    final clienteRows = await _supabase
        .from('clientes')
        .select('id')
        .eq('telefono', userId);

    if ((clienteRows as List).isEmpty) return [];

    final clienteIds =
        clienteRows.map((c) => c['id'] as String).toList();

    // Traemos las ventas con info del negocio
    final ventas = await _supabase
        .from('ventas')
        .select('*, negocios(nombre_negocio)')
        .inFilter('cliente_id', clienteIds)
        .order('fecha', ascending: false);

    return (ventas as List).cast<Map<String, dynamic>>();
  }

  /// Devuelve los detalles (productos) de un pedido específico
  Future<List<Map<String, dynamic>>> getDetallesPedido(
      String ventaId) async {
    final detalles = await _supabase
        .from('detalles_venta')
        .select('*, productos(nombre)')
        .eq('venta_id', ventaId);

    return (detalles as List).cast<Map<String, dynamic>>();
  }

  // ─────────────────────────────────────────────────────────────
  // HACER PEDIDO
  // ─────────────────────────────────────────────────────────────

  Future<void> hacerPedido(
      List<Map<String, dynamic>> items, double total) async {
    final providerId = await getProviderId();
    if (providerId == null) throw Exception('No hay proveedor vinculado');

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('No has iniciado sesión');

    // Buscar registro de cliente en esta tienda
    final clienteRes = await _supabase
        .from('clientes')
        .select()
        .eq('user_id', providerId)
        .eq('telefono', userId)
        .maybeSingle();

    String clienteId;

    if (clienteRes == null) {
      // Obtener datos del perfil del usuario para pre-llenar
      final perfil = await getMiPerfil();
      final nombre = perfil?['nombre'] ??
          _supabase.auth.currentUser?.userMetadata?['full_name'] ??
          'Cliente Nuevo';

      final nuevoCliente = await _supabase.from('clientes').insert({
        'user_id': providerId,
        'nombre': nombre,
        'telefono': userId, // UUID como identificador
        'direccion': perfil?['direccion'],
        'latitud': perfil?['latitud'],
        'longitud': perfil?['longitud'],
      }).select().single();

      clienteId = nuevoCliente['id'];
    } else {
      clienteId = clienteRes['id'];
    }

    // Insertar venta
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
