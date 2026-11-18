# T03 — Verificar GPO de bloqueo de pantalla

| Campo | Valor |
|---|---|
| Fecha | 17/11/2026 |
| Equipo | CL01 |
| Usuario | `EMPRESA\jperez` |
| Categoría | Políticas de grupo |
| Prioridad | Media |
| Estado | Cerrado |

## Síntoma

Se necesitaba confirmar que la política de bloqueo de pantalla llegaba al
usuario y que los valores eran los esperados. La sola existencia de la GPO no
demuestra que se aplique ni que el bloqueo ocurra.

## Impacto y prioridad

Es un control de seguridad: si la política no se aplicara, una sesión
desatendida quedaría abierta. No interrumpe el trabajo del usuario: prioridad
**Media**.

## Hipótesis

Causas típicas de que una GPO no se aplique, contrastadas con lo observado:

1. El vínculo está ausente o deshabilitado, o el usuario está fuera de la OU
   vinculada. Se descartó.
2. El filtrado de seguridad no concede `GpoApply`. Se descartó: lo concede a
   Usuarios autentificados.
3. El cliente no actualizó la política. Se descartó: `gpresult /r` la
   muestra aplicada.
4. La configuración está en la sección equivocada (equipo en lugar de
   usuario). Se descartó: los valores están en el perfil del usuario.

## Diagnóstico

- La GPO `GPO-Bloqueo-Pantalla` está vinculada a
  `OU=EMPRESA,DC=ad,DC=empresa,DC=test`.
- `jperez` está en `OU=Administracion,OU=Usuarios,OU=EMPRESA,...`, dentro del
  alcance del vínculo.
- `gpresult /r` mostró la GPO aplicada en la sesión de `jperez`.
- El registro del usuario contenía:

| Valor | Resultado |
|---|---|
| `ScreenSaveActive` | `1` |
| `ScreenSaveTimeOut` | `300` |
| `ScreenSaverIsSecure` | `1` |

## Acción

No se modificó la GPO. Se documentó que los valores estaban aplicados y se
separó la verificación de política de la prueba funcional del bloqueo.

## Verificación

- `gpresult /r` en la sesión de `jperez`: GPO aplicada.
- Registro de `jperez`: los tres valores presentes.
- `Test-LabClientHealth.ps1` ejecutado como `EMPRESA\Administrador` informa
  `Warning` porque ese perfil no tiene los valores; no contradice la GPO de
  `jperez`. El script lo advierte en sus limitaciones.
- Prueba funcional del 18/11/2026, de solo lectura: con la sesión de
  `jperez` activa y 330 segundos sin interacción, `LogonUI` y `LockApp`
  aparecieron en la misma sesión a las 16:22:16, con el mismo `explorer`
  en ejecución. Resultado: `Locked=True`.
- Prueba manual del 18/11/2026: a las 19:04, `jperez` dejó abierto el Bloc
  de notas con el texto `T03 - 19:04` y no tocó la VM. No se usó Win+L. A
  las 19:12, al tocar una tecla, Windows mostró `EMPRESA\jperez` con el
  campo **Contraseña**. Con la contraseña volvió a la **misma sesión**, con
  el Bloc de notas `T03 - 19:04` abierto.

## Evidencia

- `docs/bitacora.md`, secciones 17/11/2026 y «Prueba funcional del bloqueo
  de pantalla».
- `docs/arquitectura.md`, sección de política de grupo.
- `C:\LAB\Evidencias\scripts-20261118-04`, diagnóstico de CL01.
- `C:\LAB\Evidencias\gpo-screenlock-diagnostico-20261118-01`: vínculo,
  permisos y ubicación de `jperez`.
- `C:\LAB\Evidencias\screenlock-20261118-02`: prueba funcional
  (`summary.txt`, `result.json`).
- `evidencias/t03-01-sesion-inicial.jpg`, `t03-02-pide-contrasena.jpg` y
  `t03-03-misma-sesion.jpg`: prueba manual de la contraseña al volver.

## Respuesta al usuario

«Revisamos tu equipo: la política de bloqueo está aplicada y comprobamos que
la sesión se bloquea sola al quedar inactiva. Si notás que no se bloquea o
que vuelve sin pedir contraseña, avisanos con la hora aproximada.»

## Criterio de escalamiento

- Escalar a la administración de AD si, después de `gpupdate /force` y un
  inicio de sesión nuevo, `gpresult` no muestra la GPO, o si hay errores de
  `SYSVOL` o eventos de error de Group Policy.
- Cualquier cambio en la GPO afecta a toda `OU=EMPRESA` y requiere
  aprobación.

## Cierre y límites

La aplicación de la GPO, los valores del registro, el bloqueo por
inactividad y la contraseña exigida al volver están verificados.

Límites:
- Ninguna de las dos pruebas mide los 300 segundos exactos.
- En la prueba manual no se capturó la pantalla bloqueada antes de tocar
  una tecla. Que el bloqueo fue por inactividad y no manual se apoya en el
  procedimiento seguido (no se usó Win+L) y en la prueba automática del
  mismo día.
