# Tickets de soporte

Tickets simulados del laboratorio. Cada uno registra síntoma, impacto y
prioridad, hipótesis, diagnóstico, acción (solución), verificación
(validación), evidencia, respuesta al usuario, criterio de escalamiento y lo
que **no** se comprobó. Las identidades son ficticias.

Las respuestas al usuario son textos redactados para el caso simulado: no se
enviaron a ninguna persona. Las hipótesis indican si se confirmaron, se
descartaron o no se probaron, según lo registrado en el diagnóstico.

| ID | Título | Área | Estado |
|---|---|---|---|
| [T01](t01-union-dominio.md) | CL01 no puede unirse al dominio | Unión al dominio | Cerrado |
| [T02](t02-acceso-ventas.md) | Acceso denegado a Ventas para jperez | Permisos NTFS | Cerrado, denegación correcta |
| [T03](t03-gpo-bloqueo.md) | Verificar GPO de bloqueo de pantalla | GPO | Cerrado |
| [T04](t04-licencia-cl01.md) | CL01 se apaga por licencia de evaluación | Licencias | Cerrado |
| [T07](t07-aislamiento-internet.md) | CL01 no resuelve nombres externos | Red / DNS | Cerrado, comportamiento esperado |
| [T08](t08-usuario-bloqueado.md) | mgomez no puede iniciar sesión: cuenta bloqueada | Cuentas / contraseñas | Cerrado |
| [T09](t09-alta-empleado.md) | Alta de empleada: Lucía Fernández (Ventas) | Cuentas / altas | Cerrado |
| [T10](t10-baja-empleado.md) | Baja de empleada: Carla Rodríguez (Soporte) | Cuentas / bajas | Cerrado |

Los identificadores T05 y T06 no se usan. Correspondían a dos fallos de los
scripts del laboratorio, no a incidentes de usuario, y se pasaron a
[scripts/README.md](../scripts/README.md#incidencias-de-desarrollo). Los
demás tickets conservan su número porque la bitácora los cita.

## Reglas

- No se incluyen contraseñas, claves, hashes de credenciales ni recovery
  keys.
- La evidencia vive fuera de las VM, en `C:\LAB\Evidencias`, y se revisa
  antes de publicarse.
- Un ticket cerrado no implica que se haya probado todo lo relacionado: cada
  archivo indica sus límites.
