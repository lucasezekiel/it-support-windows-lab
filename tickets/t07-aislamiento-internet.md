# T07 — CL01 no resuelve nombres externos

| Campo | Valor |
|---|---|
| Fecha | 18/11/2026 |
| Equipo | CL01 |
| Usuario | Laboratorio |
| Categoría | Red / DNS / aislamiento |
| Prioridad | Baja |
| Estado | Cerrado; comportamiento esperado |

## Síntoma

Desde CL01 se podía resolver `ad.empresa.test`, pero no nombres de Internet.
La expectativa del usuario era que el equipo tuviera salida a Internet como
una oficina real.

## Impacto y prioridad

El usuario no navega por Internet, pero los servicios del dominio funcionan
y el comportamiento es el diseñado: prioridad **Baja**.

## Hipótesis

1. El DNS de CL01 está mal configurado. Se descartó: resuelve el dominio y el
   registro SRV de LDAP.
2. DC01 no tiene reenviadores. Se confirmó, y es así por diseño.
3. CL01 no tiene ruta por defecto. Se confirmó, y es así por diseño.
4. El firewall bloquea el tráfico. Se descartó como causa: sin ruta por
   defecto, el tráfico no llega a salir.

## Diagnóstico

- `LAB-AD` es un switch **privado**: conecta DC01 y CL01, sin adaptador del
  host y sin ruta a la LAN doméstica ni a Internet.
- CL01 usa DNS `10.10.10.10`; DC01 no tiene reenviadores.
- No hay ruta IPv4 por defecto en CL01.
- La resolución del dominio y de `_ldap._tcp.dc._msdcs.ad.empresa.test`
  funciona.
- La resolución externa falla por diseño. Durante la activación se abrió una
  ventana temporal y filtrada, ya cerrada.

## Acción

No se agregó una ruta por defecto, un reenviador ni un adaptador permanente.
Se explicó el aislamiento y se documentó que cualquier acceso temporal a
Internet requiere el procedimiento autorizado de `docs/activacion.md`, con
filtros, una sola VM por vez y cierre posterior.

## Verificación

- `Resolve-DnsName ad.empresa.test` y el SRV de LDAP responden.
- `Get-NetRoute` no muestra `0.0.0.0/0`.
- La consulta externa falla; el diagnóstico la informa como
  `Aislamiento de salida: Ok`.
- Firewall activo en todos los perfiles.
- La auditoría `activacion-auditoria-20261118-07` confirma una interfaz
  `LAB-AD`, DNS `10.10.10.10`, sin rutas por defecto y sin registros A
  temporales.

## Evidencia

- `C:\LAB\Evidencias\activacion-auditoria-20261118-07`.
- `C:\LAB\Evidencias\scripts-20261118-04` (diagnóstico de CL01).
- `docs/arquitectura.md` y `docs/activacion.md`.

## Respuesta al usuario

«Este equipo está a propósito en una red de laboratorio aislada: puede usar
los servicios de la empresa, como el inicio de sesión y las carpetas
compartidas, pero no sale a Internet. Si necesitás Internet para una tarea
puntual, pedilo indicando el motivo y el tiempo; se habilita de forma
temporal y controlada.»

## Criterio de escalamiento

- Abrir el acceso a Internet es una decisión de seguridad: requiere
  autorización del responsable y seguir `docs/activacion.md`.
- Escalar como incidente si también falla la resolución del dominio interno
  o del registro SRV de LDAP.

## Cierre y límites

No es un incidente de red: es el aislamiento deliberado del laboratorio. No
se probó una salida permanente a Internet ni se debe abrir sin autorización.
La ventana temporal de activación no se usa como acceso cotidiano.
