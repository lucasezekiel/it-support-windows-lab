# T10 — Baja de empleada: Carla Rodríguez (Soporte)

| Campo | Valor |
|---|---|
| Fecha | 18/11/2026 |
| Equipo | DC01 / CL01 |
| Usuario | `EMPRESA\crodriguez` |
| Categoría | Cuentas / baja y revocación de accesos |
| Prioridad | Alta |
| Estado | Cerrado |

## Síntoma

Aviso simulado de RR. HH.: Carla Rodríguez deja la empresa hoy. Hay que
revocar sus accesos en el día y comprobar que la revocación es efectiva.

## Impacto y prioridad

Una cuenta activa de alguien que ya no trabaja en la empresa es un riesgo de
seguridad. Se trata en el día: prioridad **Alta**.

## Hipótesis

Es un pedido, no una falla. Lo que se comprobó durante la ejecución:

1. Deshabilitar la cuenta y quitarle los grupos alcanza para cortar todo el
   acceso. **No se cumplió por sí solo**: una sesión que ya estaba abierta
   siguió accediendo a la red.
2. La sesión residual se reconecta con los vales Kerberos que ya tenía. Es
   compatible con lo observado: hubo acceso a `Publico` un minuto después
   de la baja y DC01 emitió un vale de servicio después de la baja con el
   TGT anterior.
3. El reingreso posterior fue un inicio con credenciales en caché. Se
   confirmó con un evento 4624 de tipo 11.

## Diagnóstico

Línea base (18:22, antes de la baja): `crodriguez` en `GG_Soporte`, leer
`Publico` permitido y una sesión SMB abierta desde CL01 en DC01.

Línea de tiempo:

| Hora | Dónde | Hecho |
|---|---|---|
| 18:24:26 | DC01 | Baja: cuenta deshabilitada (4725), se quitó `GG_Soporte`, se cerró 1 sesión SMB |
| 18:25:46 | CL01 | En la sesión que seguía abierta, leer `Publico` dio **PERMITIDO** |
| 18:26:17 | CL01 / DC01 | Cierre de sesión (4647); DC01 emite un vale de servicio (4769) con el TGT de las 18:17 |
| 18:27:33 | CL01 | Desbloqueo rechazado por el DC (4625, `LogonType=7`, `0xC0000072`, cuenta deshabilitada), seguido de un **4624 tipo 11**: entrada con caché |
| — | CL01 | En esa sesión iniciada con caché, `klist` muestra 0 vales y leer `Publico` dio **DENEGADO** |
| 18:41:16 | CL01 | Inicio nuevo rechazado (4625, `LogonType=2`, `0xC0000072`), sin recurrir a la caché: «Su cuenta está deshabilitada» |
| 18:48:53 | CL01 | Cierre remoto de la sesión residual (4647); `quser` sin sesiones |

En DC01, `lastLogon` quedó en 18:17:22: después de la baja no hubo ninguna
autenticación contra el DC.

## Acción

En DC01:

```powershell
Disable-ADAccount -Identity crodriguez
Remove-ADGroupMember -Identity GG_Soporte -Members crodriguez -Confirm:$false
Set-ADUser crodriguez -Description 'Baja T10 18/11/2026 - deshabilitada; grupos quitados: GG_Soporte'
Get-SmbSession | Where-Object ClientUserName -match '\\crodriguez$' | Close-SmbSession -Force
```

En CL01, sesión residual:

```powershell
quser          # identificar el ID de sesión del usuario
logoff 1
```

No se usó `Remove-ADUser`. Deshabilitar la cuenta es reversible y conserva
el SID y la auditoría.

## Verificación

- DC01: `Enabled=False`, sin grupos `GG_*`, descripción de la baja y 0
  sesiones SMB.
- Un inicio de sesión nuevo en CL01 se rechaza con «Su cuenta está
  deshabilitada».
- La sesión iniciada con caché no obtiene vales Kerberos ni accede a
  `\\DC01\Empresa`.
- Después del cierre remoto, `quser` en CL01 no muestra sesiones de
  `crodriguez`.

## Evidencia

- `C:\LAB\Evidencias\helpdesk-t10-baja-20261118-01`: estado antes y después
  de la baja, y eventos.
- `C:\LAB\Evidencias\helpdesk-t10-diagnostico-20261118-01` y `-05`:
  eventos de inicio de sesión en CL01 y Kerberos en DC01. Las carpetas
  `-02` a `-04` están vacías por intentos sin elevación.
- `C:\LAB\Evidencias\helpdesk-t10-cierre-sesion-20261118-01`: cierre
  remoto de la sesión.
- `evidencias/t10-01-linea-base.jpg`, `t10-03-sesion-abierta-tras-baja.jpg`,
  `t10-04-sesion-cache-sin-red.jpg` y `t10-05-inicio-rechazado.jpg`.
  `t10-02-baja-consola-host.jpg` muestra una ruta del host y no se publica
  sin recortar.

## Respuesta al usuario

Mensaje para RR. HH., que pidió la baja:

«La cuenta de Carla Rodríguez quedó deshabilitada hoy a las 18:24 y se le
quitaron los permisos de su área. También cerramos la sesión que tenía
abierta en su equipo y comprobamos que no puede volver a entrar ni acceder a
las carpetas compartidas. La cuenta se conserva deshabilitada por si hay que
revisar algo; si corresponde eliminarla definitivamente, lo coordinamos con
su aprobación. Por favor, confirmen la devolución de su equipo.»

## Criterio de escalamiento

- Una baja sin un pedido formal de RR. HH. no se ejecuta.
- Escalar a seguridad si hay indicios de acceso posterior a la baja, como
  sesiones o eventos de inicio correcto, o si el equipo no se devuelve.
- La eliminación definitiva de la cuenta o de sus datos requiere aprobación
  y un checkpoint o respaldo previo.

## Cierre y límites

La revocación quedó verificada en AD, en la red y en el equipo, después del
cierre remoto de la sesión.

Lecciones:
- Deshabilitar la cuenta no corta una sesión abierta: hay que cerrar las
  sesiones en los equipos y luego verificar.
- Se evaluó y **no se aplicó** `CachedLogonsCount=0`. Con ese valor, ningún
  usuario podría iniciar sesión en CL01 si DC01 no está disponible, y no es
  habitual en estaciones de trabajo. El inicio local con caché queda como
  riesgo aceptado, mitigado por el cierre de sesiones y la recuperación del
  equipo.

Límites:
- No se verificó por qué el desbloqueo (tipo 7) recurrió a la caché y el
  inicio nuevo (tipo 2) no.
- No se midió cuánto tiempo más habría seguido con acceso a la red la
  sesión residual.
- No apareció el evento 4729 (quitar un miembro de un grupo global).
- No hay recursos con permisos propios de `GG_Soporte`, así que la quita
  del grupo se acredita en AD, no con una prueba de acceso.
