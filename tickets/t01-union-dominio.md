# T01 — CL01 no puede unirse al dominio

| Campo | Valor |
|---|---|
| Fecha | 17/11/2026 |
| Equipo | CL01 |
| Usuario | Técnico de laboratorio |
| Categoría | Unión al dominio |
| Prioridad | Media |
| Estado | Cerrado |

## Síntoma

La unión de CL01 a `ad.empresa.test` falló. El evento `NetJoin` 4097 registró
un intento de unión con error **1326**. El laboratorio quedaba bloqueado
porque sin unión no se podían probar GPO ni permisos de dominio.

## Impacto y prioridad

Un equipo nuevo y su usuario quedan sin acceso al dominio: sin unión, CL01 no
recibe GPO ni puede usar recursos con cuenta de dominio. Afecta a un solo
equipo, sin pérdida de datos ni impacto en otros usuarios: prioridad **Media**.

## Hipótesis

1. El DNS del cliente no apunta al controlador. Se descartó: CL01 usaba
   `10.10.10.10` y DC01 resolvía.
2. No hay conectividad con los puertos del dominio. Se descartó: estaban
   disponibles.
3. La credencial es inválida o se escribió mal. Es compatible con el error
   1326 y fue la causa más probable.
4. La cuenta no tiene permiso para unir equipos. No se probó.

## Diagnóstico

- CL01 tenía `10.10.10.20/24` y DNS `10.10.10.10`.
- DC01 resolvía y los puertos de dominio estaban disponibles.
- El error 1326 es un fallo de inicio de sesión, no un error de DNS.
- No se conservó el nombre de la cuenta usada en el intento fallido. La
  cuenta administrativa del dominio es `EMPRESA\Administrador`; la
  contraseña se escribe solo en el cuadro local y no se registra.

## Acción

1. Se verificó la configuración de red y DNS de CL01.
2. Se repitió la unión con `Add-Computer` y la credencial
   `EMPRESA\Administrador`, solicitada localmente.
3. Se ubicó el equipo en `OU=Equipos,OU=EMPRESA,DC=ad,DC=empresa,DC=test`.
4. Se reinició CL01 y se inició sesión con `EMPRESA\jperez`; el sistema pidió
   cambiar la contraseña inicial.

## Verificación

- `Get-ADComputer CL01` devuelve el equipo en `OU=Equipos`.
- `whoami` en la sesión de `jperez` devuelve `empresa\jperez`.
- `Test-ComputerSecureChannel` devuelve `True`.
- `gpresult /r` muestra `GPO-Bloqueo-Pantalla` aplicada.

## Evidencia

- `docs/bitacora.md`, sección 17/11/2026.
- Evento `NetJoin` 4097 en CL01, conservado en los registros de la VM.
- `C:\LAB\Evidencias\scripts-20261118-04` confirma el canal seguro y el
  dominio desde CL01.

## Respuesta al usuario

«Tu equipo ya quedó incorporado al dominio de la empresa. Iniciá sesión con
tu usuario `EMPRESA\jperez`; la primera vez el sistema te va a pedir que
cambies la contraseña inicial. Si aparece algún error al entrar, avisanos con
una captura del mensaje.»

## Criterio de escalamiento

Escalar a la administración de AD si:
- el error 1326 persiste con una credencial verificada;
- aparecen errores de DNS, del registro SRV de LDAP o de hora (Kerberos);
- la cuenta de equipo `CL01` ya existe o está duplicada en AD.

Soporte no crea ni borra cuentas de equipo sin autorización.

## Cierre y límites

El equipo quedó unido y el usuario pudo iniciar sesión. No se registró la
contraseña ni se atribuyó el fallo a DNS. No se probó una unión con una cuenta
sin privilegios suficientes; el error 1326 se interpreta por el contexto y el
evento, no como una prueba general de todas las causas posibles.
