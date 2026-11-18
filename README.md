# it-support-windows-lab

Laboratorio local de soporte IT corporativo sobre Windows Server 2025 y
Windows 11 Enterprise, ejecutado en Hyper-V y documentado con evidencias
verificables.

**Estado:** en construcción. Este repositorio distingue explícitamente lo
probado de lo pendiente.

## Objetivo

Practicar y demostrar tareas de soporte IT y administración junior:

- Active Directory Domain Services y DNS.
- Unión de un cliente Windows al dominio.
- Usuarios, grupos y unidades organizativas.
- Altas, bajas, bloqueos y restablecimiento de contraseñas.
- Carpetas compartidas y permisos NTFS.
- Políticas de grupo verificables.
- Diagnóstico de accesos, DNS y aplicación de GPO.
- PowerShell para inventario y diagnóstico.
- Documentación de incidentes y comunicación con usuarios.

## Arquitectura

| VM | Sistema | Rol | CPU | RAM | Disco |
|---|---|---|---:|---:|---:|
| DC01 | Windows Server 2025 Standard (Desktop Experience), evaluación | AD DS, DNS, recurso compartido | 2 | 4 GB | 80 GB dinámico |
| CL01 | Windows 11 Enterprise 26H2, evaluación | Cliente del dominio | 2 | 4 GB | 80 GB dinámico |

Red: switch virtual **privado** `LAB-AD`, subred `10.10.10.0/24`.

| Equipo | IP | DNS |
|---|---|---|
| DC01 | 10.10.10.10/24 | 127.0.0.1 |
| CL01 | 10.10.10.20/24 | 10.10.10.10 |

Dominio: `ad.empresa.test` (NetBIOS `EMPRESA`). Identidades ficticias.

Detalle en [docs/arquitectura.md](docs/arquitectura.md).

## Requisitos

Host utilizado y verificado:

- Windows 11 Pro 10.0.26200, 64 bits.
- AMD Ryzen 9 5900XT, 16 núcleos / 32 hilos.
- 15,9 GB de RAM.
- SSD NVMe de 931,5 GB, con espacio libre suficiente.
- Virtualización por hardware y SLAT disponibles.
- Hyper-V habilitado con `Microsoft-Hyper-V-All`.

El laboratorio se ejecuta íntegramente en máquinas virtuales. El equipo
físico no se une al dominio ni cambia su DNS habitual.

## Alcance verificado

Fecha de verificación base: **17/11/2026**. Activación de DC01 y CL01
verificada el **18/11/2026**; scripts de inventario y diagnóstico validados
el **18/11/2026**.

- [x] Hyper-V habilitado y servicios `vmms`/`vmcompute` en ejecución.
- [x] Switch privado `LAB-AD` sin adaptador en el host.
- [x] DC01 instalada, con IP fija, nombre y DNS propio.
- [x] Bosque `ad.empresa.test` promovido; servicios `NTDS` y `DNS` activos.
- [x] Zona DNS primaria y `SYSVOL` accesible.
- [x] OU `EMPRESA` con `Usuarios`, `Grupos`, `Equipos` y `Recursos`.
- [x] Grupos `GG_Administracion`, `GG_Ventas`, `GG_Soporte`.
- [x] Usuarios ficticios `jperez`, `mgomez`, `dsuarez`, `crodriguez`.
- [x] Recurso `\\DC01\Empresa` con permisos NTFS por grupo.
- [x] CL01 instalada con TPM virtual y Secure Boot.
- [x] CL01 unida al dominio y ubicada en `OU=Equipos`.
- [x] GPO `GPO-Bloqueo-Pantalla` aplicada y verificada en el registro.
- [x] Lectura de `Publico` y escritura en `Administracion` con `jperez`.
- [x] Acceso denegado comprobado en `Ventas` para `jperez`.
- [x] DC01 activado con el servicio oficial el 18/11/2026; `/xpr` informa
  vencimiento el **17/05/2027**.
- [x] CL01 activado con el servicio oficial el 18/11/2026; `/xpr` informa
  vencimiento el **16/02/2027**.
- [x] Scripts `Get-LabADInventory.ps1` 1.0.1 y `Test-LabClientHealth.ps1`
  1.0.2 validados en DC01 y CL01; inventario con código 0 y diagnósticos con
  código 1 por advertencias revisadas, sin críticos inesperados.
- [x] Guía de reconstrucción redactada a partir de los pasos verificados; no
  se ejecutó como una reconstrucción completa desde cero.
- [x] Procedimientos de administración y recuperación documentados. La
  prueba de restauración no se ejecutó y figura como pendiente.
- [x] Bloqueo de cuenta por intentos fallidos, desbloqueo y restablecimiento
  de contraseña con `mgomez` (T08, 18/11/2026). Se usó la PSO
  `PSO-Bloqueo-Helpdesk`, aplicada solo a esa cuenta, y quedaron registrados
  los eventos 4740, 4767 y 4724. El cambio obligatorio de contraseña se
  comprobó en CL01.
- [x] Alta de empleada `lfernandez` en Ventas (T09, 18/11/2026): cambio de
  contraseña obligatorio en el primer inicio. Lectura en `Publico` y
  escritura en `Ventas` permitidas; acceso a `Administracion` denegado.
- [x] Baja de `crodriguez` con revocación verificada (T10, 18/11/2026):
  cuenta deshabilitada, grupos quitados, sesiones SMB y de equipo cerradas,
  e inicio de sesión nuevo rechazado. Se documenta que una sesión abierta
  conservó el acceso a la red hasta cerrarla.
- [x] Ocho tickets de soporte documentados con síntoma, impacto/prioridad, hipótesis,
  diagnóstico, acción, verificación, evidencia, respuesta al usuario,
  criterio de escalamiento y límites.
- [x] Bloqueo efectivo de la sesión de `jperez` por inactividad, comprobado
  el 18/11/2026 (`LogonUI`/`LockApp` en la misma sesión a las 16:22:16;
  evidencia `screenlock-20261118-02`). La prueba manual de las 19:04 a las
  19:12 comprobó que al volver se exige la contraseña y se recupera la misma
  sesión (T03).

## Alcance pendiente

- [ ] Revisión final de las evidencias antes de publicar. Las capturas de
  `evidencias/` ya se revisaron una por una.
- [ ] Publicación en GitHub (requiere autorización expresa).

## Costos y licencias

| Componente | Costo adicional | Condición |
|---|---:|---|
| Hyper-V | $0 | Incluido en Windows 11 Pro |
| Windows Server 2025 Evaluation | $0 | 180 días; activación por Internet dentro de los primeros 10 días |
| Windows 11 Enterprise Evaluation | $0 | 90 días; activación por Internet |

Fechas de referencia:

- Server instalado el **16/11/2026**; activado el **18/11/2026**. `/xpr`
  informa vencimiento el **17/05/2027**; conservar la salida original.
- Windows 11 instalado el **17/11/2026**; activado el **18/11/2026**.
  `/xpr` informa vencimiento el **16/02/2027**; conservar la salida original.
- La promoción del dominio no inicia ni reinicia el período de evaluación.
  No se encontró documentación oficial que defina el inicio exacto del
  plazo de 90 días de la evaluación de Windows 11.
- La marca «La licencia de Windows expiró» y el estado `0xC004F009` se
  observaron en CL01 antes de la activación; no acreditaban por sí solos una
  evaluación agotada. El intento 04 confirmó la licencia activa.

Consulta real del **18/11/2026**: DC01 activado hasta el **17/05/2027** y
CL01 hasta el **16/02/2027**. Antes de activarse, CL01 se apagó sola a las
**14:58:41**; `wlms.exe` registró «El período de licencia de esta
instalación de Windows ha expirado». La activación posterior se completó a
las 15:09:03. El `/ato` devolvió `0xC004E028` por una activación automática
en curso, pero `LicenseStatus=1`; se conserva esa evidencia en
`C:\LAB\Evidencias\activacion-ejecucion-20261118-04`, junto con la
auditoría `activacion-auditoria-20261118-07`. La ventana de Internet se
cerró y no quedaron registros A temporales. Seguimiento en
[docs/activacion.md](docs/activacion.md).

Son evaluaciones temporales, no licencias permanentes. No se contrataron
servicios ni se usaron cuentas pagas.

## Estructura

```text
.
├── README.md
├── docs/
│   ├── arquitectura.md
│   ├── activacion.md
│   ├── administracion.md
│   ├── bitacora.md
│   ├── limitaciones.md
│   ├── reconstruccion.md
│   └── recuperacion.md
├── evidencias/
├── scripts/
│   ├── Get-LabADInventory.ps1
│   ├── Test-LabClientHealth.ps1
│   └── README.md
└── tickets/
    ├── README.md
    ├── t01-union-dominio.md
    ├── t02-acceso-ventas.md
    ├── t03-gpo-bloqueo.md
    ├── t04-licencia-cl01.md
    ├── t07-aislamiento-internet.md
    ├── t08-usuario-bloqueado.md
    ├── t09-alta-empleado.md
    └── t10-baja-empleado.md
```

## Seguridad y datos

- Identidades y datos ficticios.
- No se publican contraseñas, claves, hashes de credenciales ni capturas
  con datos personales.
- El laboratorio no expone puertos ni modifica el router.
- Los checkpoints de VM no reemplazan un respaldo del equipo host.
