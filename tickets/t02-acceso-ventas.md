# T02 — Acceso denegado a Ventas para jperez

| Campo | Valor |
|---|---|
| Fecha | 17/11/2026 |
| Equipo | CL01 / DC01 |
| Usuario | `EMPRESA\jperez` |
| Categoría | Permisos NTFS y grupos |
| Prioridad | Baja |
| Estado | Cerrado; la denegación es correcta |

## Síntoma

`jperez` podía leer `\\DC01\Empresa\Publico` y escribir en
`\\DC01\Empresa\Administracion`, pero al intentar listar o escribir en
`\\DC01\Empresa\Ventas` recibía «Acceso denegado».

## Impacto y prioridad

Un usuario no accede a una carpeta que no corresponde a su área. Sigue
trabajando con normalidad en `Publico` y `Administracion`: prioridad **Baja**.

## Hipótesis

1. `jperez` no pertenece a `GG_Ventas`. Se confirmó.
2. Los permisos NTFS de `Ventas` están mal configurados. Se descartó:
   conceden acceso a `GG_Ventas`, según el diseño.
3. El permiso del recurso SMB es más restrictivo que NTFS. Se descartó: el
   recurso otorga `Change` a `Usuarios del dominio`.
4. El token de sesión no refleja un cambio de grupo reciente. No aplica: no
   hubo cambios de grupo.

## Diagnóstico

- `jperez` pertenece a `GG_Administracion`, no a `GG_Ventas`.
- El recurso SMB `Empresa` otorga `Change` a `Usuarios del dominio`; el
  control fino está en NTFS.
- La carpeta `Ventas` concede modificación a `GG_Ventas`.
- `Test-Path` sobre `Ventas` devolvió `True`, pero listar y escribir fueron
  denegados. La existencia visible no demuestra permiso de lectura ni
  escritura.

## Acción

No se cambió el permiso. Se explicó al usuario que el acceso está denegado
por diseño y que, si necesita trabajar en Ventas, debe solicitar la
incorporación a `GG_Ventas` con aprobación. Si se aprobara:

```powershell
Add-ADGroupMember -Identity GG_Ventas -Members jperez
```

Después se probaría con una sesión nueva y se revisaría el acceso efectivo.

## Verificación

- `Get-ADGroupMember GG_Administracion` incluye a `jperez`.
- `Get-ADGroupMember GG_Ventas` no incluye a `jperez`.
- Lectura de `Publico` y escritura en `Administracion`: correctas.
- Listado y escritura en `Ventas`: denegados.

## Evidencia

- `docs/bitacora.md`, sección 17/11/2026.
- `docs/arquitectura.md`, tabla de recursos y permisos.
- `C:\LAB\Evidencias\scripts-20261118-04` confirma la pertenencia a grupos y
  la visibilidad del recurso, no los permisos de `jperez`.

## Respuesta al usuario

«Revisamos tu acceso: la carpeta Ventas está reservada al equipo de Ventas y
tu usuario pertenece a Administración, por eso aparece "Acceso denegado". No
es una falla. Si necesitás trabajar en esa carpeta, pedile a tu responsable
que solicite el acceso. Cuando esté aprobado lo habilitamos, y vas a tener
que cerrar sesión y volver a entrar.»

## Criterio de escalamiento

- Agregar a `jperez` a `GG_Ventas` requiere la aprobación del responsable
  del área. Soporte no decide los accesos a datos.
- Escalar a la administración si un miembro de `GG_Ventas` también recibe
  «Acceso denegado» o si la ACL de `Ventas` difiere de
  `docs/arquitectura.md`.

## Cierre y límites

El ticket se cierra como **comportamiento esperado de mínimo privilegio**, no
como un fallo de la carpeta. No se probó el acceso con `jperez` en una sesión
nueva después de un cambio de grupo, porque no se autorizó ese cambio. No se
usa `Test-Path` como prueba de permisos.
