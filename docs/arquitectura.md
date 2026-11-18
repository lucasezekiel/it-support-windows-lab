# Arquitectura del laboratorio

## Diagrama

```text
HOST Windows 11 Pro (Hyper-V)
│
├── Switch virtual privado LAB-AD
│   │   (sin adaptador del host, sin acceso a la LAN doméstica)
│   │
│   ├── DC01  10.10.10.10/24
│   │   Windows Server 2025 Standard (Desktop Experience)
│   │   AD DS · DNS · recurso compartido \\DC01\Empresa
│   │
│   └── CL01  10.10.10.20/24
│       Windows 11 Enterprise 26H2
│       Cliente unido a ad.empresa.test
```

## Decisiones

**Hyper-V.** Incluido en Windows 11 Pro, sin costo adicional y con soporte
de TPM virtual y Secure Boot, necesarios para Windows 11.

**Switch privado.** Conecta solo a las VM entre sí. El host no recibe
dirección en esa red y no existe ruta hacia la LAN doméstica ni a Internet.
La administración se realiza por la consola de Hyper-V.

**Direccionamiento estático.** La red no tiene DHCP. Se asignan direcciones
fijas para que el laboratorio sea reproducible y no dependa de servicios
externos.

**DNS en DC01.** CL01 apunta exclusivamente a `10.10.10.10`, requisito para
localizar el dominio y aplicar políticas.

**Recursos.** 4 GB de RAM por VM y 2 CPU virtuales. Los discos son dinámicos
de 80 GB. La memoria es fija para que el comportamiento sea predecible.

## Dominio

| Dato | Valor |
|---|---|
| Bosque y dominio | `ad.empresa.test` |
| NetBIOS | `EMPRESA` |
| Nivel funcional | Windows Server 2025 |
| Controlador | DC01 |
| Zona DNS | `ad.empresa.test` (Primary) |

## Estructura de directorio

```text
DC=ad,DC=empresa,DC=test
└── OU=EMPRESA
    ├── OU=Usuarios
    │   ├── OU=Administracion
    │   ├── OU=Ventas
    │   └── OU=Soporte
    ├── OU=Grupos
    ├── OU=Equipos
    └── OU=Recursos
```

## Usuarios y grupos

| Usuario | Área | Grupo |
|---|---|---|
| `jperez` | Administración | `GG_Administracion` |
| `mgomez` | Ventas | `GG_Ventas` |
| `dsuarez` | Ventas | `GG_Ventas` |
| `crodriguez` | Soporte | `GG_Soporte` |

## Recursos compartidos

| Ruta | Lectura | Modificación |
|---|---|---|
| `\\DC01\Empresa\Publico` | Usuarios del dominio | — |
| `\\DC01\Empresa\Ventas` | — | `GG_Ventas` |
| `\\DC01\Empresa\Administracion` | — | `GG_Administracion` |

El recurso SMB otorga `Change` a `EMPRESA\Usuarios del dominio`; el control
efectivo se aplica con permisos NTFS por carpeta.

## Política de grupo

`GPO-Bloqueo-Pantalla`, vinculada a `OU=EMPRESA`.

| Valor | Configuración |
|---|---|
| `ScreenSaveActive` | 1 |
| `ScreenSaveTimeOut` | 300 segundos |
| `ScreenSaverIsSecure` | 1 |

Verificada con `gpresult /r` y con los valores del registro del usuario.

## Herramientas de diagnóstico

- `scripts/Get-LabADInventory.ps1` (1.0.1): inventario de solo lectura de
  AD DS, DNS, GPO, recursos y servicios. Se ejecuta en DC01.
- `scripts/Test-LabClientHealth.ps1` (1.0.2): diagnóstico de solo lectura de
  identidad, DNS, conectividad, GPO, licencia y eventos recientes. Se ejecuta
  en CL01 o DC01.

Ambos se validaron el 18/11/2026. El detalle, los códigos de salida y las
limitaciones están en [scripts/README.md](../scripts/README.md).

## Acceso a Internet

Usado el 18/11/2026 para activar DC01 y CL01: adaptadores adicionales
temporales en `Default Switch`, con filtros previos a la conexión. `LAB-AD`
conserva su tipo privado y transporta el tráfico del dominio. El cierre del
mantenimiento retiró esos adaptadores y restauró los ajustes DNS; ambas VM
quedaron sin ruta por defecto.

Procedimiento, criterios de éxito y estado en [activacion.md](activacion.md).

## Almacenamiento en el host

```text
C:\LAB\
├── ISO\          imágenes de evaluación
├── VMs\          discos virtuales por VM
└── Evidencias\   capturas y salidas revisadas
```
