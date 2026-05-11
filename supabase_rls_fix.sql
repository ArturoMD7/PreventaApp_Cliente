-- =========================================================
-- FIX DEFINITIVO RLS — tabla clientes
-- Ejecuta esto en el SQL Editor de Supabase.
-- Borra TODAS las policies existentes en clientes y las
-- recrea correctamente sin conflictos.
-- =========================================================

-- 1. Eliminar TODAS las políticas posibles (tanto del script original
--    como del fix anterior y cualquier variante)
DROP POLICY IF EXISTS "CRUD clientes por usuario"           ON public.clientes;
DROP POLICY IF EXISTS "Clientes pueden registrarse a si mismos" ON public.clientes;
DROP POLICY IF EXISTS "Clientes pueden ver su propio registro"  ON public.clientes;
DROP POLICY IF EXISTS "Clientes ven su propio registro"         ON public.clientes;
DROP POLICY IF EXISTS "Proveedores ven sus clientes"            ON public.clientes;
DROP POLICY IF EXISTS "Clientes pueden registrarse"             ON public.clientes;
DROP POLICY IF EXISTS "Proveedores editan sus clientes"         ON public.clientes;
DROP POLICY IF EXISTS "Clientes editan su propio registro"      ON public.clientes;
DROP POLICY IF EXISTS "Proveedores eliminan sus clientes"       ON public.clientes;

-- 2. Recrear limpias

-- SELECT: el proveedor ve sus clientes
CREATE POLICY "Proveedores ven sus clientes"
  ON public.clientes FOR SELECT
  USING (auth.uid() = user_id);

-- SELECT: el cliente ve sus propios registros (en cualquier tienda)
CREATE POLICY "Clientes ven su propio registro"
  ON public.clientes FOR SELECT
  USING (telefono = auth.uid()::text);

-- INSERT: el cliente puede registrarse en cualquier tienda,
--         siempre que el campo 'telefono' sea su propio uid
CREATE POLICY "Clientes pueden registrarse"
  ON public.clientes FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated'
    AND telefono = auth.uid()::text
  );

-- UPDATE: el proveedor puede editar sus clientes
CREATE POLICY "Proveedores editan sus clientes"
  ON public.clientes FOR UPDATE
  USING (auth.uid() = user_id);

-- UPDATE: el cliente puede editar su propio nombre/dirección
CREATE POLICY "Clientes editan su propio registro"
  ON public.clientes FOR UPDATE
  USING (telefono = auth.uid()::text);

-- DELETE: solo el proveedor puede eliminar sus clientes
CREATE POLICY "Proveedores eliminan sus clientes"
  ON public.clientes FOR DELETE
  USING (auth.uid() = user_id);
