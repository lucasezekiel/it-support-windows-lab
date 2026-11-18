# T04 — CL01 se apaga por licencia de evaluación

| Campo | Valor |
|---|---|
| Fecha | 18/11/2026 |
| Equipo | CL01; DC01 |
| Usuario | Laboratorio |
| Categoría | Licencias / evaluación |
| Prioridad | Alta |
| Estado | Cerrado |

## Síntoma

CL01 se apagó sola a las **14:58:41** y `wlms.exe` registró «El período de
licencia de esta instalación de Windows ha expirado». La marca de agua y el
estado de licencia indicaban evaluación sin activar. DC01 ya estaba activado.

## Impacto y prioridad

El cliente se apaga solo y bloquea todas las prácticas que dependen de CL01:
prioridad **Alta**.

## Hipótesis

1. La evaluación venció de forma definitiva. Se descartó después de activar:
   `/xpr` informa el 16/02/2027.
2. La evaluación no se activó por falta de Internet. Se confirmó:
   `0x80072EE7`.
3. La clave o la edición no son válidas. Se descartó: `0xC004E028` fue una
   colisión con una activación en curso.

## Diagnóstico

- CL01 es Windows 11 Enterprise Evaluation 26H2, build `26300`.
- Antes de activar: `LicenseStatus=5`, razón `0xC004F009`, gracia 0 y
  `EvaluationEndDate` de época.
- Los intentos automáticos de activación registraron `0x80072EE7` por falta de
  resolución de nombres durante el aislamiento.
- Se abrió una ventana temporal y filtrada de Internet, documentada en
  `docs/activacion.md`.
- La activación automática comenzó a las 15:09:01–02. El `/ato` manual de las
  15:09:03 devolvió `0xC004E028` por colisión con esa activación en curso; no
  fue un rechazo de licencia.
- Después del intento, `LicenseStatus=1`, gracia 129600 minutos y `/xpr`
  **16/02/2027 15:09:03**.

## Acción

1. Se mantuvo el aislamiento y se aplicaron filtros antes de conectar el
   adaptador temporal.
2. Se ejecutó la activación una sola vez para CL01.
3. No se repitió `/ato` ni se usó `slmgr /rearm`.
4. Se retiró el adaptador temporal y se restauró DNS, rutas y firewall.
5. Se ejecutó una auditoría independiente.

## Verificación

- CL01: `LicenseStatus=1`, `/xpr` 16/02/2027, `10.10.10.20/24`, DNS
  `10.10.10.10`, sin ruta por defecto y firewall activo.
- DC01: activo hasta 17/05/2027, sin `ListenAddresses` ni
  `PublishAddresses`, sin reenviadores, DNS/NTDS/Netlogon activos.
- No quedaron registros A temporales.
- La ventana de Internet se cerró.

## Evidencia

- `C:\LAB\Evidencias\activacion-ejecucion-20261118-04`.
- `C:\LAB\Evidencias\activacion-auditoria-20261118-07`.
- `docs/activacion.md` y `docs/limitaciones.md`.

## Respuesta al usuario

«El equipo de pruebas se apagaba porque su licencia de evaluación no estaba
activada. Ya quedó activada hasta el 16/02/2027 y podés seguir usándolo. Antes
de esa fecha te vamos a avisar para que guardes lo necesario, porque después
el equipo vuelve a apagarse.»

## Criterio de escalamiento

- No se compran licencias ni se usa `slmgr /rearm` sin autorización.
- Escalar al responsable del presupuesto si la activación falla con un error
  que no sea de conectividad o si `/xpr` no informa una fecha.
- Escalar también antes del vencimiento, para decidir si el laboratorio
  continúa.

## Cierre y límites

La licencia quedó activa, pero el informe original contiene
`ActivationCompleted=false` porque el script evaluó el código de `/ato` antes
que `LicenseStatus`. La discrepancia se documenta y no se editó el informe
original. Son evaluaciones temporales: CL01 vence el 16/02/2027 y DC01 el
17/05/2027. Restaurar un checkpoint no concede un nuevo período.
