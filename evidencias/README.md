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

## Disponibles

- `C:\LAB\Evidencias\scripts-20261118-04` — validación final de los scripts
  de inventario y diagnóstico, revisada el 18/11/2026. Incluye `result.json`,
  consolas, JSON/TXT de DC01 y CL01, copias de los scripts y sus hashes.
  Resultado: inventario 0; diagnósticos 1 (advertencias), sin críticos.
- `C:\LAB\Evidencias\activacion-auditoria-20261118-07` — auditoría de
  licencias, DNS, rutas, firewall y registro A de CL01.
- `C:\LAB\Evidencias\activacion-ejecucion-20261118-04` — evidencia del
  intento de activación de CL01 y su limpieza.

Las carpetas de ejecuciones anteriores se conservan para auditoría; la
validación final es la 04. No se copiaron a este repositorio los JSON
completos: pueden contener nombres de equipos y usuarios ficticios y deben
revisarse antes de publicarse.

## Pendiente

- Capturas de la configuración verificada el 17/11/2026.
- Evidencias de los tickets.
- Revisión y anonimización antes de cualquier publicación.
