# Evidencias

Esta carpeta reúne capturas y salidas de comandos **revisadas** antes de
publicarse.

## Reglas

- Solo hechos verificados; nada de ejemplos presentados como resultados.
- Revisar cada captura y quitar datos personales, rutas del usuario, correos,
  nombres de equipos reales y cualquier credencial.
- No incluir contraseñas, claves, tokens ni hashes de credenciales.
- Nombrar los archivos por ticket o etapa, por ejemplo
  `t01-bloqueo-antes.png` y `t01-bloqueo-despues.png`.

## Capturas en este repositorio

Todas son recortes de la consola de CL01. Se revisaron una por una: no
muestran datos del host, correos ni credenciales.

| Ticket | Archivos | Qué muestran |
|---|---|---|
| T03 | `t03-01` … `t03-03` | Sesión de `jperez`, contraseña exigida al volver del bloqueo y la misma sesión recuperada |
| T08 | `t08-01` … `t08-04` | Cambio de contraseña obligatorio tras el restablecimiento y primer inicio de `mgomez` |
| T09 | `t09-01`, `t09-02` | Cambio obligatorio en el alta y prueba de accesos de `lfernandez` |
| T10 | `t10-01`, `t10-03` … `t10-05` | Línea base, acceso de la sesión abierta tras la baja, sesión en caché sin red e inicio rechazado |

`t10-02` no se publica porque muestra una ruta del host.

## Salidas originales (fuera del repositorio)

Las salidas completas de los scripts quedan en `C:\LAB\Evidencias` del host,
con su hash SHA-256. Los tickets citan cada carpeta.

- `C:\LAB\Evidencias\scripts-20261118-04` — validación final de los scripts
  de inventario y diagnóstico, revisada el 18/11/2026. Incluye `result.json`,
  consolas, JSON/TXT de DC01 y CL01, copias de los scripts y sus hashes.
  Resultado: inventario 0; diagnósticos 1 (advertencias), sin críticos.
- `C:\LAB\Evidencias\activacion-auditoria-20261118-07` — auditoría de
  licencias, DNS, rutas, firewall y registro A de CL01.
- `C:\LAB\Evidencias\activacion-ejecucion-20261118-04` — evidencia del
  intento de activación de CL01 y su limpieza.
- `C:\LAB\Evidencias\helpdesk-*-20261118-*`: relevamiento, T08, T09 y T10
  (estado antes y después, eventos de seguridad y hashes).

Las carpetas de ejecuciones anteriores se conservan para auditoría. No se
copiaron a este repositorio los JSON completos: pueden contener nombres de
equipos y usuarios ficticios y hay que revisarlos antes de publicarlos.

## No incluido

- Capturas de la configuración del 17/11/2026: la evidencia de esa etapa son
  las salidas de comandos citadas en la bitácora.
