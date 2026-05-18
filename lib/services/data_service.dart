import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/negocio.dart';

class DataService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _providerKey = 'provider_id';
  static const String _vinculacionSkippedKey = 'vinculacion_skipped';

  static const String _nombreKey = 'perfil_nombre';
  static const String _telefonoKey = 'perfil_telefono';
  static const String _direccionKey = 'perfil_direccion';
  static const String _latitudKey = 'perfil_latitud';
  static const String _longitudKey = 'perfil_longitud';

  // ── SharedPreferences: proveedor activo ──

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

  // ── SharedPreferences: vinculación skip ──

  Future<void> setVinculacionSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vinculacionSkippedKey, true);
  }

  Future<bool> hasVinculacionSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vinculacionSkippedKey) ?? false;
  }

  Future<void> clearVinculacionSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vinculacionSkippedKey);
  }

  // ── SharedPreferences: perfil local ──

  Future<void> guardarPerfilLocal({
    required String nombre,
    String? telefono,
    String? direccion,
    double? latitud,
    double? longitud,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nombreKey, nombre);
    if (telefono != null) await prefs.setString(_telefonoKey, telefono);
    if (direccion != null) await prefs.setString(_direccionKey, direccion);
    if (latitud != null) await prefs.setDouble(_latitudKey, latitud);
    if (longitud != null) await prefs.setDouble(_longitudKey, longitud);
  }

  Future<Map<String, dynamic>?> getPerfilLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString(_nombreKey);
    if (nombre == null || nombre.isEmpty) return null;
    return {
      'nombre': nombre,
      'telefono_real': prefs.getString(_telefonoKey) ?? '',
      'direccion': prefs.getString(_direccionKey),
      'latitud': prefs.getDouble(_latitudKey),
      'longitud': prefs.getDouble(_longitudKey),
    };
  }

  // ── NEGOCIO ──

  Future<Negocio?> getNegocio() async {
    try {
      final providerId = await getProviderId();
      if (providerId == null) return null;

      final response = await _supabase
          .from('negocios')
          .select()
          .eq('id', providerId)
          .maybeSingle();

      return response != null ? Negocio.fromMap(response) : null;
    } catch (e) {
      throw Exception('Error al obtener negocio: $e');
    }
  }

  // ── MÚLTIPLES TIENDAS ──

  Future<List<Map<String, dynamic>>> getLinkedProviders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final clienteRows = await _supabase
          .from('clientes')
          .select('user_id')
          .eq('telefono', userId);

      if ((clienteRows as List).isEmpty) return [];

      final providerIds =
          clienteRows.map((c) => c['user_id'] as String).toSet().toList();

      final negocios = await _supabase
          .from('negocios')
          .select()
          .inFilter('id', providerIds);

      return (negocios as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Error al obtener proveedores vinculados: $e');
    }
  }

  Future<void> desvincularProveedor(String providerId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('clientes')
          .delete()
          .eq('user_id', providerId)
          .eq('telefono', userId);
    } catch (e) {
      throw Exception('Error al desvincular proveedor: $e');
    }
  }

  // ── PRODUCTOS Y CATEGORÍAS ──

  Future<List<Producto>> getProductos() async {
    try {
      final providerId = await getProviderId();
      if (providerId == null) return [];

      final response = await _supabase
          .from('productos')
          .select()
          .eq('user_id', providerId)
          .order('nombre', ascending: true);

      return (response as List).map((map) => Producto.fromMap(map)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Error de base de datos al obtener productos: ${e.message}');
    } catch (e) {
      throw Exception('Error al obtener productos: $e');
    }
  }

  Future<List<Categoria>> getCategorias() async {
    try {
      final providerId = await getProviderId();
      if (providerId == null) return [];

      final response = await _supabase
          .from('categorias')
          .select()
          .eq('user_id', providerId)
          .order('nombre', ascending: true);

      return (response as List).map((map) => Categoria.fromMap(map)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Error de base de datos al obtener categorías: ${e.message}');
    } catch (e) {
      throw Exception('Error al obtener categorías: $e');
    }
  }

  // ── PERFIL DEL CLIENTE ──

  Future<bool> tienePerfil() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final row = await _supabase
          .from('clientes')
          .select('id')
          .eq('telefono', userId)
          .limit(1)
          .maybeSingle();

      return row != null;
    } catch (e) {
      throw Exception('Error al verificar perfil: $e');
    }
  }

  Future<Map<String, dynamic>?> getMiPerfil() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final row = await _supabase
          .from('clientes')
          .select()
          .eq('telefono', userId)
          .limit(1)
          .maybeSingle();

      if (row != null) {
        return {
          'nombre': row['nombre'],
          'telefono_real': row['telefono_real'] ?? '',
          'direccion': row['direccion'],
          'latitud': row['latitud'],
          'longitud': row['longitud'],
        };
      }

      return getPerfilLocal();
    } catch (e) {
      throw Exception('Error al obtener perfil: $e');
    }
  }

  Future<void> registrarClienteEnTienda({
    required String providerId,
    required String nombre,
    String? telefonoReal,
    String? direccion,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No has iniciado sesión');

      final existente = await _supabase
          .from('clientes')
          .select('id')
          .eq('user_id', providerId)
          .eq('telefono', userId)
          .maybeSingle();

      if (existente != null) return;

      await _supabase.from('clientes').insert({
        'user_id': providerId,
        'nombre': nombre,
        'telefono': userId,
        'telefono_real': telefonoReal?.isNotEmpty == true ? telefonoReal : null,
        'direccion': direccion?.isNotEmpty == true ? direccion : null,
        'latitud': latitud,
        'longitud': longitud,
      });
    } on PostgrestException catch (e) {
      throw Exception('Error al registrar cliente: ${e.message}');
    } catch (e) {
      throw Exception('Error al registrar cliente en tienda: $e');
    }
  }

  Future<void> updateProfile({
    required String nombre,
    String? telefono,
    String? direccion,
    double? latitud,
    double? longitud,
  }) async {
    try {
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

      await guardarPerfilLocal(
        nombre: nombre,
        telefono: telefono,
        direccion: direccion,
        latitud: latitud,
        longitud: longitud,
      );
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  // ── PEDIDOS ──

  Future<List<Map<String, dynamic>>> getMisPedidos() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final clienteRows = await _supabase
          .from('clientes')
          .select('id')
          .eq('telefono', userId);

      if ((clienteRows as List).isEmpty) return [];

      final clienteIds = clienteRows.map((c) => c['id'] as String).toList();

      final ventas = await _supabase
          .from('ventas')
          .select('*')
          .inFilter('cliente_id', clienteIds)
          .order('fecha', ascending: false);

      final ventasList = (ventas as List).cast<Map<String, dynamic>>();
      if (ventasList.isEmpty) return [];

      final providerIds =
          ventasList.map((v) => v['user_id'] as String).toSet().toList();

      final negociosRows = await _supabase
          .from('negocios')
          .select('id, nombre_negocio')
          .inFilter('id', providerIds);

      final Map<String, String> negocioNombres = {
        for (var n in negociosRows as List)
          n['id'] as String: (n['nombre_negocio'] as String?) ?? 'Tienda'
      };

      return ventasList.map((v) {
        return {
          ...v,
          'negocios': {
            'nombre_negocio': negocioNombres[v['user_id']] ?? 'Tienda',
          },
        };
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener pedidos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDetallesPedido(String ventaId) async {
    try {
      final detalles = await _supabase
          .from('detalles_venta')
          .select('*, productos(nombre)')
          .eq('venta_id', ventaId);

      return (detalles as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Error al obtener detalles del pedido: $e');
    }
  }

  // ── CANCELAR PEDIDO ──

  Future<void> cancelarPedido(String ventaId) async {
    try {
      await _supabase
          .from('ventas')
          .update({'estado': 'cancelado'})
          .eq('id', ventaId);
    } catch (e) {
      throw Exception('Error al cancelar pedido: $e');
    }
  }

  // ── NEGOCIO POR ID ──

  Future<Negocio?> getNegocioById(String negocioId) async {
    try {
      final response = await _supabase
          .from('negocios')
          .select()
          .eq('id', negocioId)
          .maybeSingle();

      return response != null ? Negocio.fromMap(response) : null;
    } catch (e) {
      return null;
    }
  }

  // ── HACER PEDIDO ──

  Future<void> hacerPedido(
      List<Map<String, dynamic>> items, double total) async {
    try {
      final providerId = await getProviderId();
      if (providerId == null) throw Exception('No hay proveedor vinculado');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No has iniciado sesión');

      var clienteRes = await _supabase
          .from('clientes')
          .select('id')
          .eq('user_id', providerId)
          .eq('telefono', userId)
          .maybeSingle();

      if (clienteRes == null) {
        final perfil = await getMiPerfil();
        final nombre = perfil?['nombre'] ??
            _supabase.auth.currentUser?.userMetadata?['full_name'] ??
            'Cliente';

        await registrarClienteEnTienda(
          providerId: providerId,
          nombre: nombre,
          telefonoReal: perfil?['telefono_real'],
          direccion: perfil?['direccion'],
          latitud: (perfil?['latitud'] as num?)?.toDouble(),
          longitud: (perfil?['longitud'] as num?)?.toDouble(),
        );

        clienteRes = await _supabase
            .from('clientes')
            .select('id')
            .eq('user_id', providerId)
            .eq('telefono', userId)
            .single();
      }

      final clienteId = clienteRes['id'] as String;

      final ventaRes = await _supabase.from('ventas').insert({
        'user_id': providerId,
        'cliente_id': clienteId,
        'fecha': DateTime.now().toIso8601String(),
        'total': total,
        'estado': 'pendiente',
      }).select().single();

      final ventaId = ventaRes['id'];

      for (final item in items) {
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
    } on PostgrestException catch (e) {
      throw Exception('Error de base de datos al crear pedido: ${e.message}');
    } catch (e) {
      throw Exception('Error al hacer pedido: $e');
    }
  }
}
