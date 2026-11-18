# Guía de reconstrucción

Esta guía describe cómo reconstruir el laboratorio en Hyper-V. Sintetiza los
pasos verificados durante su construcción; **no se ejecutó como una
reconstrucción completa desde cero**. Los permisos, nombres y resultados
esperados son los que se comprobaron en este equipo.

## Alcance y seguridad

- Se ejecuta todo dentro de máquinas virtuales. El Windows físico no se une al
  dominio, no cambia su DNS habitual y no recibe adaptadores en `LAB-AD`.
- El switch `LAB-AD` es **privado**: no tiene acceso a la LAN doméstica ni a
  Internet. No se abre ningún puerto del router.
- No se compran licencias ni servicios. Se usan las evaluaciones de Windows
  Server 2025 y Windows 11 Enterprise.
- Las contraseñas se escriben solo en los cuadros locales de Windows. No se
  guardan en archivos, scripts, capturas ni en este repositorio.
- Antes de cambiar una VM, crear un checkpoint manual con un nombre claro.
  Los checkpoints automáticos están deshabilitados y no reemplazan un respaldo
  del disco físico.

## 1. Requisitos del host

- Windows 11 Pro con Hyper-V habilitado.
- Virtualización por hardware y SLAT disponibles.
- Espacio libre suficiente para las VM, las ISO y las evidencias.
- ISO de Windows Server 2025 Standard (Desktop Experience) y de Windows 11
  Enterprise, obtenidas de los medios de evaluación.
- Conexión a Internet solo para la descarga inicial de las ISO. La
  activación se trata en [activacion.md](activacion.md).

Verificación de solo lectura:

```powershell
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsArchitecture
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All |
    Select-Object FeatureName, State
Get-Service vmms, vmcompute | Select-Object Name, Status
Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription
```

Si Hyper-V no está habilitado, se habilita con aprobación explícita y reinicio:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
```

## 2. Carpetas y red virtual

```powershell
New-Item -ItemType Directory -Path C:\LAB\ISO, C:\LAB\VMs, C:\LAB\Evidencias -Force
New-VMSwitch -Name LAB-AD -SwitchType Private
Get-VMSwitch -Name LAB-AD | Format-List Name, SwitchType, NetAdapterInterfaceDescription
```

El resultado esperado es un switch privado sin adaptador físico asociado. El
host no debe obtener una dirección en `10.10.10.0/24`.

## 3. DC01: creación de la VM

Valores usados: generación 2, 2 vCPU, 4 GB de RAM fija, disco dinámico de
80 GB, checkpoints automáticos deshabilitados y arranque automático
deshabilitado.

```powershell
$vmPath = 'C:\LAB\VMs\DC01'
New-Item -ItemType Directory -Path $vmPath -Force
New-VM -Name DC01 -Generation 2 -MemoryStartupBytes 4GB `
    -NewVHDPath "$vmPath\DC01.vhdx" -NewVHDSizeBytes 80GB `
    -SwitchName LAB-AD
Set-VMProcessor -VMName DC01 -Count 2
Set-VMMemory -VMName DC01 -DynamicMemoryEnabled $false
Set-VM -Name DC01 -AutomaticCheckpointsEnabled $false -AutomaticStartAction Nothing
```

Agregar la ISO como unidad DVD y ajustar el orden de arranque:

```powershell
Add-VMDvdDrive -VMName DC01 -Path 'C:\LAB\ISO\WS2025_Eval_x64_es-es.iso'
$dvd = Get-VMDvdDrive -VMName DC01
Set-VMFirmware -VMName DC01 -BootOrder $dvd
Start-VM -Name DC01
```

Instalar Windows Server 2025 Standard (Desktop Experience). En la instalación
se define la contraseña del Administrador local; debe cumplir la política y no
se documenta.

## 4. DC01: red, nombre y zona horaria

Dentro de DC01, con una consola elevada:

```powershell
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 10.10.10.10 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 127.0.0.1
Set-TimeZone -Id 'Argentina Standard Time'
Rename-Computer -NewName DC01 -Restart
```

El nombre de la interfaz puede variar. Verificar antes de aplicarlo:

```powershell
Get-NetIPConfiguration
Get-DnsClientServerAddress -AddressFamily IPv4
```

## 5. DC01: AD DS y DNS

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
$dsrm = Read-Host -AsSecureString 'Contraseña de DSRM'
Install-ADDSForest `
    -DomainName 'ad.empresa.test' `
    -DomainNetbiosName 'EMPRESA' `
    -InstallDns `
    -SafeModeAdministratorPassword $dsrm `
    -Force
```

La contraseña de DSRM se escribe solo en el prompt. No se guarda en el
repositorio ni en las evidencias. El servidor reinicia al finalizar.

Verificación:

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode, DistinguishedName
Get-ADForest | Select-Object Name, ForestMode, RootDomain, GlobalCatalogs
Get-Service NTDS, DNS, Netlogon | Select-Object Name, Status, StartType
Get-DnsServerZone | Select-Object ZoneName, ZoneType, IsDsIntegrated
Test-Path '\\DC01\SYSVOL'
```

Resultados esperados: dominio `ad.empresa.test`, NetBIOS `EMPRESA`, modo
`Windows2025Domain`, `NTDS` y `DNS` en ejecución, zona primaria
`ad.empresa.test` y `SYSVOL` accesible.

## 6. Estructura de directorio, grupos y usuarios

```powershell
$base = 'DC=ad,DC=empresa,DC=test'
$empresa = "OU=EMPRESA,$base"
New-ADOrganizationalUnit -Name EMPRESA -Path $base
New-ADOrganizationalUnit -Name Usuarios -Path $empresa
foreach ($area in 'Administracion', 'Ventas', 'Soporte') {
    New-ADOrganizationalUnit -Name $area -Path "OU=Usuarios,$empresa"
}
foreach ($ou in 'Grupos', 'Equipos', 'Recursos') {
    New-ADOrganizationalUnit -Name $ou -Path $empresa
}

New-ADGroup -Name GG_Administracion -SamAccountName GG_Administracion `
    -GroupScope Global -GroupCategory Security -Path "OU=Grupos,$empresa"
New-ADGroup -Name GG_Ventas -SamAccountName GG_Ventas `
    -GroupScope Global -GroupCategory Security -Path "OU=Grupos,$empresa"
New-ADGroup -Name GG_Soporte -SamAccountName GG_Soporte `
    -GroupScope Global -GroupCategory Security -Path "OU=Grupos,$empresa"
```

Crear los cuatro usuarios ficticios. Repetir el patrón para cada uno,
cambiando nombre, SamAccountName y OU:

```powershell
$password = Read-Host -AsSecureString 'Contraseña inicial del usuario'
New-ADUser -Name 'Juan Perez' -SamAccountName jperez `
    -UserPrincipalName 'jperez@ad.empresa.test' `
    -Path "OU=Administracion,OU=Usuarios,$empresa" `
    -AccountPassword $password -Enabled $true -ChangePasswordAtLogon $true
Add-ADGroupMember -Identity GG_Administracion -Members jperez
```

Usuarios y grupos verificados:

| Usuario | OU | Grupo |
|---|---|---|
| `jperez` | `Administracion` | `GG_Administracion` |
| `mgomez` | `Ventas` | `GG_Ventas` |
| `dsuarez` | `Ventas` | `GG_Ventas` |
| `crodriguez` | `Soporte` | `GG_Soporte` |

La contraseña inicial compartida es una simplificación de laboratorio; los
usuarios deben cambiarla en el primer inicio de sesión.

## 7. Recurso compartido y permisos NTFS

Crear la estructura:

```powershell
New-Item -ItemType Directory -Path C:\Empresa\Publico, C:\Empresa\Ventas, C:\Empresa\Administracion -Force
New-SmbShare -Name Empresa -Path C:\Empresa -ChangeAccess 'EMPRESA\Usuarios del dominio'
```

Los permisos NTFS verificados son:

| Carpeta | Lectura | Modificación |
|---|---|---|
| `Publico` | `EMPRESA\Usuarios del dominio` | — |
| `Ventas` | — | `EMPRESA\GG_Ventas` |
| `Administracion` | — | `EMPRESA\GG_Administracion` |

Un método reproducible con `icacls`, ejecutado en DC01, es:

```powershell
icacls C:\Empresa\Publico /inheritance:r
icacls C:\Empresa\Publico /grant:r 'EMPRESA\Usuarios del dominio:(OI)(CI)(RX)'
icacls C:\Empresa\Ventas /inheritance:r
icacls C:\Empresa\Ventas /grant:r 'EMPRESA\GG_Ventas:(OI)(CI)(M)'
icacls C:\Empresa\Administracion /inheritance:r
icacls C:\Empresa\Administracion /grant:r 'EMPRESA\GG_Administracion:(OI)(CI)(M)'
```

Antes de confiar en estos comandos, revisar que el recurso SMB y los grupos
existan. El recurso SMB otorga `Change` a `Usuarios del dominio`; el control
efectivo se aplica con NTFS. Verificar con un usuario de prueba y no atribuir
permisos a `Test-Path`: la existencia visible no demuestra lectura ni
escritura.

## 8. GPO de bloqueo de pantalla

```powershell
$gpo = New-GPO -Name GPO-Bloqueo-Pantalla
$target = 'OU=EMPRESA,DC=ad,DC=empresa,DC=test'
New-GPLink -Name GPO-Bloqueo-Pantalla -Target $target

Set-GPRegistryValue -Name GPO-Bloqueo-Pantalla `
    -Key 'HKCU\Control Panel\Desktop' -ValueName ScreenSaveActive `
    -Type String -Value '1'
Set-GPRegistryValue -Name GPO-Bloqueo-Pantalla `
    -Key 'HKCU\Control Panel\Desktop' -ValueName ScreenSaveTimeOut `
    -Type String -Value '300'
Set-GPRegistryValue -Name GPO-Bloqueo-Pantalla `
    -Key 'HKCU\Control Panel\Desktop' -ValueName ScreenSaverIsSecure `
    -Type String -Value '1'
```

Verificación en CL01, con la sesión de `jperez`:

```powershell
gpresult /r
Get-ItemProperty 'HKCU:\Control Panel\Desktop' |
    Select-Object ScreenSaveActive, ScreenSaveTimeOut, ScreenSaverIsSecure
```

La GPO y sus valores están verificados. El bloqueo efectivo es una prueba
funcional independiente; no se deduce solo de los valores del registro. Para
comprobarlo, dejar la sesión de `jperez` más de cinco minutos sin
interacción y verificar que aparezcan `LogonUI` y `LockApp` en esa sesión.
Se hizo así el 18/11/2026; la exigencia de contraseña al volver está
pendiente.

## 9. CL01: creación, instalación y unión

Valores usados: generación 2, 2 vCPU, 4 GB de RAM fija, disco dinámico de
80 GB, TPM virtual y Secure Boot.

```powershell
$vmPath = 'C:\LAB\VMs\CL01'
New-Item -ItemType Directory -Path $vmPath -Force
New-VM -Name CL01 -Generation 2 -MemoryStartupBytes 4GB `
    -NewVHDPath "$vmPath\CL01.vhdx" -NewVHDSizeBytes 80GB `
    -SwitchName LAB-AD
Set-VMProcessor -VMName CL01 -Count 2
Set-VMMemory -VMName CL01 -DynamicMemoryEnabled $false
Set-VM -Name CL01 -AutomaticCheckpointsEnabled $false -AutomaticStartAction Nothing
Set-VMKeyProtector -VMName CL01 -NewLocalKeyProtector
Enable-VMTPM -VMName CL01
Set-VMFirmware -VMName CL01 -EnableSecureBoot On -SecureBootTemplate 'MicrosoftWindows'
```

Agregar la ISO de Windows 11 Enterprise, ajustar el arranque e instalar. En la
instalación se crea una cuenta local `localadmin`; no se usa para el dominio.

Dentro de CL01:

```powershell
Get-NetAdapter | Select-Object Name, Status
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 10.10.10.20 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 10.10.10.10
Set-TimeZone -Id 'Argentina Standard Time'
Rename-Computer -NewName CL01 -Restart
```

Unir al dominio en la OU de equipos:

```powershell
Add-Computer `
    -DomainName 'ad.empresa.test' `
    -OUPath 'OU=Equipos,OU=EMPRESA,DC=ad,DC=empresa,DC=test' `
    -Credential (Get-Credential -UserName 'EMPRESA\Administrador') `
    -Restart -Force
```

Iniciar sesión con `EMPRESA\jperez`, cambiar la contraseña en el primer
inicio y comprobar:

```powershell
whoami
Test-ComputerSecureChannel
gpresult /r
Get-DnsClientServerAddress -AddressFamily IPv4
Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -eq '0.0.0.0/0'
```

## 10. Verificación final

Checklist mínimo:

- [ ] DC01 responde `Get-ADDomain` y `Get-ADForest`.
- [ ] `NTDS`, `DNS` y `Netlogon` están en ejecución.
- [ ] CL01 aparece en `Get-ADComputer CL01`.
- [ ] CL01 usa DNS `10.10.10.10` y no tiene ruta por defecto.
- [ ] `jperez` puede leer `Publico` y escribir en `Administracion`.
- [ ] `jperez` recibe acceso denegado al listar o escribir en `Ventas`.
- [ ] `GPO-Bloqueo-Pantalla` aparece aplicada y los tres valores están en el
      registro de `jperez`.
- [ ] Los scripts de [scripts/README.md](../scripts/README.md) generan sus
      informes sin errores críticos inesperados.
- [ ] Las evaluaciones tienen fecha de vencimiento registrada en
      [limitaciones.md](limitaciones.md).

## 11. Activación y Internet

La activación se realizó en una ventana temporal y filtrada, documentada en
[activacion.md](activacion.md). No se debe conectar `LAB-AD` a Internet ni
repetir `/ato` sin una decisión deliberada. Al vencer las evaluaciones, el
laboratorio debe detenerse o regularizarse; restaurar un checkpoint no concede
un nuevo período.

## 12. Fuera de alcance

- DHCP, replicación entre controladores, sitios múltiples y confianzas.
- Alta disponibilidad, clúster y respaldo corporativo del dominio.
- MFA, certificados, LAPS y cuentas de servicio.
- publicar puertos, modificar el router o unir el host al dominio.

Las limitaciones completas están en [limitaciones.md](limitaciones.md).
