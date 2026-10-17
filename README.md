# Panadero

Calculadora, biblioteca de recetas y diario de fermentación para Android y
Windows. Funciona sin internet, sin cuentas y sin servidor.

## Uso rápido

La navegación tiene cuatro secciones:

1. **Calculadora:** crear una fórmula, revisar la balanza, guardar la receta o
   iniciar directamente una amasada. Guardar nuevamente desde el mismo formulario
   actualiza esa receta; para otra fórmula independiente, usar **Crear copia**
   en la biblioteca.
2. **Recetas:** buscar por nombre o variedad. Tocar una receta para editarla.
   Su menú permite iniciar una amasada, crear una copia, compartir, exportar o
   eliminar con confirmación.
3. **Amasadas:** abrir un registro para cargar el estado de la MM, etapas,
   observaciones y resultado. Cada amasada conserva una copia de la fórmula:
   editar o eliminar la receta original no altera el historial.
4. **Preparados:** calcular y registrar refrescos de MM, biga y poolish desde MM,
   con fecha, ingredientes y notas. Se pueden buscar, editar y eliminar.

Al crear el almacén se incluyen tres recetas editables: **lactal de 2000 g** con
200 g de MM, **masa dual de 3000 g** con 400 g de MM y **focaccia de 932 g** con
200 g de MM. No se crean amasadas ficticias. Para cargar una preparación anterior,
iniciar una amasada y registrar manualmente los horarios reales de sus etapas;
la fecha de creación del registro corresponde al momento de iniciarlo en la app.

## Cómo calcular

- **Por harina:** ingresar la harina base y los porcentajes.
- **Por peso final:** ingresar el peso deseado del pastón. La app despeja la
  harina y conserva la MM fija si se indicó en gramos.
- **Pesos → porcentajes:** ingresar gramos para obtener sus porcentajes respecto
  de la harina. Este modo no utiliza prefermentos ni precocciones.

Los números admiten coma o punto decimal. Cambiar el modo de cálculo reinicia
las cantidades base y los adicionales; guardar antes de hacerlo para conservarlos.
Las variedades son etiquetas editables: elegir una no cambia las cantidades.
Cada campo de cantidad muestra su equivalencia junto al valor: si se ingresa
un porcentaje, aparecen los gramos a pesar; si se ingresan gramos, aparece
el porcentaje. El agua distingue el objetivo de los gramos a agregar después
del descuento, y las premezclas muestran sus aportes de harina y agua.

### Masa madre, prefermentos y precocción

- La **MM directa** se ingresa en gramos o como
  `peso de MM / harina base × 100`. Se puede ajustar su hidratación.
- En **poolish y biga**, el porcentaje indica la **harina destinada al
  prefermento**, no su peso completo. El inóculo puede ser MM o levadura.
  Su porcentaje se calcula sobre la harina del prefermento. Cuando es MM,
  su harina y agua ya están incluidas, no se suman por fuera.
- La **levadura adicional** del amasado es independiente de la del prefermento.
  Especificar en las instrucciones si se usa fresca o seca; no hay conversión
  automática entre ellas.
- Se puede combinar un prefermento con **tangzhong o yudane**. La proporción de
  agua por gramo de harina es editable; se sugieren 5 para tangzhong y 1 para yudane.
- **Descontar** está activado por defecto: la harina base es la harina total de
  la fórmula; la balanza resta los aportes de todas las preparaciones previas.
  Desactivado, las preparaciones se agregan además de la harina y el agua base.
  En este caso, los porcentajes de entrada usan esa base, mientras que el resumen
  muestra los porcentajes reales sobre toda la harina resultante.

La balanza separa preparaciones previas y amasado final, y muestra hidratación,
peso de MM, harina prefermentada, peso total y división en piezas iguales.
Por ejemplo, 200 g de MM al 100 % sobre 500 g de harina total equivalen a
**40 % de MM**, pero a **20 % de harina prefermentada**.

Los cálculos no redondean intermedios; se muestran dos decimales. La suma de
pesos redondeados puede diferir ligeramente del total calculado. No se estiman
pérdidas de cocción o manipulación. La hidratación cuenta agua y el agua contenida
en las preparaciones, **no** la humedad de leche, manteca, miel u otros adicionales.
Los ingredientes de cubierta se describen aparte en las instrucciones.

## Diario de fermentación

Agregar una etapa para registrar inicio y fin, o dejar el fin vacío mientras
sigue en curso. **Finalizar ahora** completa el horario de fin. También se pueden
editar horarios anteriores con formato local `AAAA-MM-DD HH:MM`.

Cada etapa permite indicar opcionalmente temperatura ambiente, de masa y de
heladera, crecimiento observado y notas. Se pueden registrar bloque, pliegues,
frío en bloque, frío formado, fermentación final u otras etapas. Pueden superponerse
porque los pliegues pueden ocurrir dentro del bloque. Guardar una etapa también
guarda las notas y evaluación que se estén editando.

El historial muestra fórmula, MM, levadura, duraciones, temperaturas y resultado
para comparar preparaciones similares. No calcula todavía estadísticas ni
predice tiempos de fermentación: la actividad de la MM, la harina, la temperatura
y el enfriamiento del pastón impiden una regla universal.

## Refrescos de MM y preparados

En **Preparados → Nuevo preparado / refresco**:

- **Refresco de MM:** ingresar los gramos de MM inicial, su hidratación y la
  proporción `1 : harina nueva : agua nueva`. Por ejemplo, 20 g de MM al 100 %
  y proporción 1:2:2 requieren 40 g de harina y 40 g de agua: se obtienen
  100 g de MM al 100 %. La hidratación final también considera la MM inicial,
  por lo que no siempre coincide con la relación agua/harina nuevas.
- **Biga de MM / Poolish de MM:** ingresar la harina total del prefermento,
  hidratación objetivo, porcentaje de peso de MM sobre esa harina y la
  hidratación de la MM de inóculo. Se sugieren 50 % de hidratación para biga
  y 100 % para poolish; son editables. Por ejemplo, 200 g de harina total,
  50 % de hidratación y 10 % de MM al 100 % requieren **190 g de harina nueva,
  90 g de agua y 20 g de MM**, para 300 g de biga.

Los campos porcentuales muestran los gramos correspondientes. El formulario
indica la balanza completa y rechaza descuentos imposibles. La fecha y hora
son editables para registrar preparaciones anteriores. Guardar deja un registro
independiente de las amasadas; en esta sección no se registran etapas ni
temperaturas, solo fecha, fórmula y notas.

En una amasada, **Vincular preparado** permite elegir el refresco o prefermento
utilizado. Se guarda una copia histórica: editar o eliminar el preparado no
cambia esa copia. También se puede cambiar o quitar el vínculo. Vincular guarda
las notas de la amasada que estén en edición. El vínculo es **documental**:
no cambia automáticamente la fórmula, no comprueba que las cantidades coincidan,
no limita el uso a una sola amasada y no administra existencias.

## Compartir, importar y respaldar

- **Compartir archivo** genera un JSON de receta y abre las opciones del sistema.
  En Android se puede elegir WhatsApp si está disponible. En Windows también se
  puede **Exportar archivo** a una carpeta y adjuntarlo manualmente.
- Para recibirlo, descargar el adjunto y elegir **Importar archivo** desde el
  menú superior de Panadero. No está configurada la apertura directa de adjuntos
  desde WhatsApp.
- Se valida formato, versión y contenido, y se muestra una vista previa.
  La importación es **aditiva**: crea copias con nuevos identificadores y nunca
  reemplaza datos existentes. Importar el mismo archivo otra vez crea duplicados.
- **Exportar todas las recetas** incluye la biblioteca. **Respaldo completo**
  incluye biblioteca, amasadas, fórmulas utilizadas, etapas y preparados con
  sus vínculos históricos. Se recupera usando
  la misma importación, sin borrar lo que ya exista.
- En Android, exportar utiliza el selector para compartir del sistema: elegir
  una aplicación que permita guardar el archivo y verificar el destino.
- Los archivos nuevos usan formato `panadero`, versión `2`, extensión `.json`.
  Se siguen importando archivos de la versión `1`. Las versiones anteriores
  de la app no pueden importar archivos de versión `2`.
  Se admite importar hasta 20 MB. El archivo puede incluir notas personales:
  revisar antes de compartir un respaldo.

Elegir una aplicación para compartir no prueba que el destinatario haya recibido
el archivo. La app informa cuando el sistema no confirma el resultado.

## Almacenamiento y límites

Los datos viven en `panadero.sqlite`, dentro del directorio de soporte de la
aplicación del usuario en cada dispositivo. No hay sincronización automática
entre Android y Windows ni respaldo remoto. Exportar respaldos periódicamente;
desinstalar o borrar los datos de la aplicación puede eliminar el almacén.

La base utiliza SQLite en Android y SQLite FFI en Windows. La biblioteca puede
crecer sin depender de `localStorage`; esta versión carga las listas completas
para la búsqueda local, sin paginación.
El esquema SQLite se migra de versión 1 a 2 al abrir la app para incorporar
preparados sin eliminar las recetas ni las amasadas existentes.

## Desarrollo y validación

Los proyectos nativos Android y Windows ya están generados.
Se requiere Flutter con Dart compatible con las dependencias resueltas,
Visual Studio con herramientas C++ para Windows y Android SDK/JDK con sus
licencias aceptadas para Android.

```powershell
flutter pub get
dart format lib test
flutter analyze
# Continuar solo con cero errores, advertencias y lints:
flutter test
flutter run -d windows
# Con un dispositivo Android elegido:
flutter run -d ID_DEL_DISPOSITIVO
```

Para compilar en modo release:

```powershell
flutter build windows --release
flutter build apk --release
```

- **Windows:** ejecutar `build\windows\x64\runner\Release\panadero.exe`.
  Para trasladar la aplicación, copiar toda la carpeta `Release`, no solo el
  ejecutable: las DLL y la carpeta `data` son necesarias. El equipo de destino
  debe tener Microsoft Visual C++ Redistributable x64.
- **Android:** instalar `build\app\outputs\flutter-apk\app-release.apk`.
  La configuración actual firma también release con la clave de depuración
  para pruebas locales. Si ya está instalada la versión debug de este equipo,
  se puede actualizar sin borrar sus datos mientras coincidan la firma y el
  identificador. No desinstalar para actualizar sin hacer un respaldo.

La distribución Android de producción todavía requiere identidad de aplicación
y firma propia; no publicar en tiendas usando las claves de depuración.

El cálculo puro está en [domain.dart](lib/domain.dart), la persistencia en
[storage.dart](lib/storage.dart), el intercambio en
[file_exchange.dart](lib/file_exchange.dart), y las pantallas en
[main.dart](lib/main.dart), [editor.dart](lib/editor.dart) y
[diary.dart](lib/diary.dart) y [preparations.dart](lib/preparations.dart).

### Dependencias

Los paquetes directos se verificaron contra las últimas versiones estables de
pub.dev el 17/10/2026. Se conserva `pubspec.lock` para reproducir la instalación.
`cross_file` es indirecto: `share_plus 13.3.1` requiere la rama estable `0.3.x`,
por lo que no se fuerza `0.4.0`. Algunas dependencias indirectas están limitadas
por Flutter o por los paquetes que las utilizan. Revisar con `flutter pub outdated`
antes de una actualización y validar sus cambios; no usar versiones preliminares
ni `dependency_overrides` para forzar compatibilidad.
