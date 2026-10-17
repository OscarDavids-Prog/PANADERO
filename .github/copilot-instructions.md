# PANADERO - Reglas del proyecto

Estas instrucciones se aplican solo a PANADERO. No modificar las instrucciones
personales ni las de otros proyectos.

## Producto y alcance

- Aplicacion Flutter para Android y Windows, offline y sin cuentas ni servidor.
- Mantener una interfaz sencilla, adaptable a celular y escritorio, en espanol.
- Consultar antes de ampliar el alcance o cambiar convenciones de calculo,
  formatos de intercambio o decisiones de almacenamiento ya acordadas.
- No inventar registros, temperaturas, tiempos ni resultados de amasadas reales.

## Codigo y datos

- Separar calculo panadero puro, interfaz, almacenamiento SQLite e intercambio
  de archivos. Evitar dependencias circulares y logica de calculo en widgets.
- Preferir soluciones simples, tipos explicitos y reutilizacion de lo existente.
  No incorporar capas, frameworks o archivos sin una necesidad concreta.
- Mantener recetas reutilizables separadas de amasadas. Cada amasada conserva
  una copia de la formula utilizada, independiente de cambios en la receta.
- Explicitar la base de cada porcentaje. Distinguir peso de MM, harina
  prefermentada e hidratacion. Contar una sola vez los aportes de las premezclas.
- Calcular sin redondeos intermedios; redondear solo la presentacion. Validar
  valores finitos, cantidades posibles y coherencia temporal.
- Versionar y validar archivos JSON antes de importar. Mostrar vista previa y
  solicitar confirmacion. No sobrescribir datos locales de forma implicita.
- Hacer cambios de esquema con migraciones que preserven los datos existentes.
- Mostrar errores de validacion, lectura, escritura e intercambio. No anunciar
  exito antes de confirmar la operacion ni ocultar errores con valores por defecto.
- Preservar cambios del usuario. Evitar modificaciones ajenas a la tarea.

## Paquetes

- Preferir la ultima version estable publicada, nunca versiones beta, dev, rc
  ni otras prereleases. Verificar la version y compatibilidad antes de agregar
  o actualizar un paquete; no asumir que la version resuelta es la mas reciente.
- Si la ultima estable exige cambiar Flutter, Dart o requisitos de plataforma,
  explicar el bloqueo y consultar antes de cambiar esos requisitos.
- Usar restricciones de version compatibles con actualizaciones estables y
  conservar pubspec.lock en control de versiones porque este proyecto es una app.
- Agregar dependencias solo para necesidades concretas del alcance aprobado.
  Reutilizar paquetes existentes y quitar dependencias directas sin uso.
- No hacer actualizaciones masivas ni usar dependency_overrides para forzar
  incompatibilidades. Revisar cambios relevantes y validar cada actualizacion.

## Puerta de calidad

1. Formatear los archivos Dart modificados con dart format.
2. Antes de ejecutar pruebas o compilaciones, ejecutar flutter analyze y obtener
   cero errores, cero advertencias y cero lints informativos.
3. No desactivar reglas ni agregar ignores para alcanzar artificialmente cero.
4. Con el analisis limpio, ejecutar las pruebas relevantes. Cubrir formulas,
   balance de masa, descuentos, persistencia e intercambio cuando se modifiquen.
5. Compilar las plataformas afectadas cuando corresponda. Probar la ejecucion
   y hacer hot reload o hot restart despues de cambios Dart/Flutter.
6. Si una herramienta, dispositivo o requisito impide validar, indicarlo
   expresamente. No presentar como probado lo que solo esta implementado.

Los cambios solo de documentacion no requieren pruebas ni compilacion.

## Manual y entrega

- Mantener en README.md un manual breve en espanol que describa lo implementado,
  como usarlo, convenciones de calculo, almacenamiento, compartir/importar,
  respaldos y limitaciones conocidas.
- Actualizar el manual junto con los cambios funcionales. Separar funciones
  disponibles de funciones pendientes; no documentar planes como hechos.
- Al entregar, resumir cambios, validaciones realizadas y bloqueos pendientes.
