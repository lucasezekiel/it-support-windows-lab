# Scripts de inventario y diagnóstico

Dos scripts de **solo lectura**, acotados, para el laboratorio
`it-support-windows-lab`. No modifican AD, DNS, GPO, firewall ni servicios.
Escriben únicamente sus informes en la carpeta indicada.

## Estado de validación

| Script | Versión | Resultado | Código |
|---|---:|---|---:|
| `Get-LabADInventory.ps1` | 1.0.1 | Inventario generado en DC01 | 0 |
| `Test-LabClientHealth.ps1` | 1.0.2 | Sin críticos; advertencias revisadas en CL01 y DC01 | 1 |

Validación del **18/11/2026** en `C:\LAB\Evidencias\scripts-20261118-04`.
Hashes SHA-256 de los archivos ejecutados:

```text
Get-LabADInventory.ps1  9B036F06FB16DFE86E8B573BCBB95E03BE444E7DE5C150E120783F5488FADAD5
Test-LabClientHealth.ps1 BC4FB8F8E2A9B1F0AB96D3446C3A91454ADEA69C18F4DDEC5E636CFCD6C440B1
```

El código 1 del diagnóstico corresponde a advertencias, no a un fallo crítico:
el usuario `EMPRESA\Administrador` no tiene los valores de bloqueo de pantalla
en su propio perfil y los registros contienen errores históricos del período
de activación. El detalle está en el JSON y en la bitácora.

## `Get-LabADInventory.ps1`

Ejecutar en **DC01** con el módulo `ActiveDirectory`. Usa `DnsServer` y
`GroupPolicy` si están disponibles.

```powershell
.\Get-LabADInventory.ps1 -OutputDirectory C:\Temp\Inventario -MaxItems 200
```

Recolecta dominio, bosque, controladores, unidades organizativas, usuarios,
grupos (incluidos los miembros de los grupos del laboratorio), equipos,
recursos compartidos, GPO, zonas DNS, servicios y estado de SYSVOL. Genera:

- `lab-ad-inventory-<equipo>.json`
- `lab-ad-inventory-<equipo>.txt`

`-MaxItems` limita cada sección. Un conteo igual al límite puede indicar
truncamiento; no es un inventario pensado para dominios grandes. Los conteos
de usuarios y grupos incluyen los objetos predeterminados de AD, no solo las
identidades del laboratorio.

Los grupos `Domain Admins` y `Enterprise Admins` se localizan por SID
(`-512` y `-519`) para que la búsqueda funcione aunque Windows muestre nombres
localizados, como `Admins. del dominio`.

## `Test-LabClientHealth.ps1`

Ejecutar en **CL01** (o en DC01) como usuario del dominio.

```powershell
.\Test-LabClientHealth.ps1 `
  -OutputDirectory C:\Temp\Diagnostico `
  -DomainName ad.empresa.test `
  -ExpectedDnsServer 10.10.10.10 `
  -ExpectedDomainControllerIp 10.10.10.10
```

Comprueba identidad, pertenencia al dominio, canal seguro, descubrimiento del
controlador, configuración y resolución DNS, conectividad TCP
(53/88/389/445/135), rutas por defecto, visibilidad del recurso `Empresa`,
políticas de grupo, bloqueo de pantalla del usuario actual, servicios, hora,
licencia y errores recientes. Genera:

- `lab-client-health-<equipo>.json`
- `lab-client-health-<equipo>.txt`

Códigos de salida:

| Código | Significado |
|---:|---|
| 0 | Sin hallazgos críticos ni advertencias. |
| 1 | Advertencias que requieren revisión. |
| 2 | Fallo crítico de identidad, DNS, canal seguro o conectividad básica. |

En un controlador de dominio, `Test-ComputerSecureChannel` no aplica y el
script informa `Applicable=false` en lugar de marcar un falso crítico. El
bloqueo de pantalla se lee del perfil del usuario que ejecuta el script; si
faltan valores, informa `Warning` con los valores ausentes en lugar de fallar.

## Incidencias de desarrollo

Durante la validación del 18/11/2026 se corrigieron dos fallos de los propios
scripts. Al principio estaban registrados como tickets T05 y T06. Se pasaron
a esta sección porque no son incidentes de usuario, y por eso los
identificadores T05 y T06 no se usan en `tickets/`.

### Inventario: `-ResultPageSize` no válido (versión 1.0.1)

- **Síntoma:** `Get-LabADInventory.ps1` terminaba con «No se encuentra
  ningún parámetro que coincida con el nombre del parámetro
  'ResultPageSize'» y no generaba ni el JSON ni el TXT.
- **Causa:** `Get-ADDomainController -Filter * -ResultPageSize 100`.
  `Get-ADDomainController` no tiene ese parámetro, a diferencia de
  `Get-ADUser` o `Get-ADGroup`. Era un error de enlace de parámetros, no de
  permisos ni de conectividad.
- **Corrección:** se quitó el parámetro y se mantuvo
  `Select-Object -First $MaxItems`.
- **Verificación:** código 0, con el JSON y el TXT generados (1 DC, 9 OU,
  7 usuarios, 54 grupos, 2 equipos, 3 recursos, 3 GPO, 5 zonas DNS).
- **Evidencia:** `scripts-20261118-01-diagnostico` (error original) y
  `scripts-20261118-04` (salida final).

### Diagnóstico: falso crítico de canal seguro en DC01 (versión 1.0.2)

- **Síntoma:** código 2 en DC01, con `Canal seguro` como **Critical** («No
  se puede comprobar el canal seguro del equipo local…»), aunque el dominio
  y DNS funcionaban.
- **Causa:** `Test-ComputerSecureChannel` es una prueba para clientes y no
  aplica al propio controlador (`DomainRole=5`). En la misma ejecución se
  encontraron otros dos fallos: la lectura de `ScreenSaveTimeOut` daba error
  si el valor no existía, y `Domain Admins`/`Enterprise Admins` figuraban
  como inexistentes porque sus nombres están localizados al español.
- **Corrección:**
  - en los controladores (roles 4/5) la prueba se informa como
    `Applicable=false`;
  - la lectura del registro pasó a ser tolerante
    (`Get-ItemProperty` + `PSObject.Properties`);
  - en el inventario, los grupos se buscan por SID (`-512` y `-519`).
- **Verificación:** DC01 y CL01 con código 1, sin críticos; `Domain Admins`
  y `Enterprise Admins` se resuelven.
- **Evidencia:** `scripts-20261118-02` (falso crítico) y
  `scripts-20261118-04` (validación final).
- **Criterio aplicado:** no se ocultaron las advertencias reales ni se
  cambiaron la licencia o la GPO para obtener un resultado «verde».

## Seguridad

- No solicitan ni guardan credenciales.
- No usan `Set-*`, no modifican AD, no ejecutan `gpupdate /force`, `rearm`
  ni reparaciones.
- No consultan contraseñas, claves, hashes ni LAPS.
- Los informes pueden contener nombres de usuarios y equipos ficticios;
  revisarlos antes de publicarlos.

## Limitaciones

- El diagnóstico de GPO corresponde al usuario de la sesión; no demuestra
  el bloqueo efectivo de `jperez`.
- `Test-Path` sobre el recurso compartido acredita visibilidad, no permisos
  de otro usuario.
- En la configuración aislada se espera que falle la resolución externa; el
  script lo informa como estado normal, no como error.
- Los eventos recientes pueden incluir errores históricos de activación,
  unión al dominio, TPM o BitLocker. El script los muestra para revisión; no
  decide por sí solo que sean incidentes activos.
- Los scripts están pensados para este laboratorio; no reemplazan monitoreo
  ni auditoría de seguridad.
