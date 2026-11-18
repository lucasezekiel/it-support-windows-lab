# Administración del laboratorio

Procedimientos para operar el laboratorio sin romper el aislamiento ni el
equipo físico. Las tareas destructivas requieren checkpoint previo y
aprobación del responsable del laboratorio.

## Principios

- Todo cambio se hace dentro de DC01 o CL01. El host no se une al dominio,
  no cambia su DNS y no recibe adaptadores en `LAB-AD`.
- Antes de un cambio: crear un checkpoint manual con nombre descriptivo,
  registrar el estado inicial y definir cómo se verifica y cómo se revierte.
- No guardar contraseñas, claves, hashes de credenciales ni recovery keys en
  tickets, scripts, capturas o documentación.
- No ejecutar `/ato`, `slmgr /rearm`, `gpupdate /force` ni reparaciones de
  confianza sin una causa concreta y una comprobación previa.
- Una advertencia de un script no es un incidente confirmado: revisar el
  detalle y correlacionar con eventos y pruebas.

## Rutina de verificación

Ejecutar desde una consola elevada del host, contra las VM encendidas:

```powershell
Get-VM -Name DC01, CL01 | Select-Object Name, State, Heartbeat, Uptime
```

En DC01:

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
Get-ADForest | Select-Object Name, ForestMode, GlobalCatalogs
Get-Service NTDS, DNS, Netlogon | Select-Object Name, Status, StartType
Get-DnsServerZone | Select-Object ZoneName, ZoneType, IsDsIntegrated
dcdiag /test:dns
```

En CL01, con una cuenta del dominio:

```powershell
whoami
Test-ComputerSecureChannel
Get-DnsClientServerAddress -AddressFamily IPv4
Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -eq '0.0.0.0/0'
gpresult /r
```

Herramientas acotadas:

```powershell
# En DC01
.\scripts\Get-LabADInventory.ps1 -OutputDirectory C:\Temp\Inventario -MaxItems 200

# En CL01
.\scripts\Test-LabClientHealth.ps1 `
  -OutputDirectory C:\Temp\Diagnostico `
  -DomainName ad.empresa.test `
  -ExpectedDnsServer 10.10.10.10 `
  -ExpectedDomainControllerIp 10.10.10.10
```

Revisar los códigos de salida y el JSON. En la validación del 18/11/2026 el
diagnóstico devolvió 1 por advertencias esperadas; no se debe “corregir” un
warning sin entenderlo.

## Altas de usuarios

Patrón verificado durante la construcción:

```powershell
$ou = 'OU=Administracion,OU=Usuarios,OU=EMPRESA,DC=ad,DC=empresa,DC=test'
$password = Read-Host -AsSecureString 'Contraseña inicial'
New-ADUser -Name 'Nombre Apellido' -SamAccountName usuario `
    -UserPrincipalName 'usuario@ad.empresa.test' `
    -Path $ou -AccountPassword $password `
    -Enabled $true -ChangePasswordAtLogon $true
Add-ADGroupMember -Identity GG_Administracion -Members usuario

Get-ADUser usuario -Properties MemberOf, PasswordLastSet, Enabled |
    Select-Object SamAccountName, Enabled, PasswordLastSet, MemberOf
```

La contraseña se escribe solo en el prompt. El alta y la pertenencia a los
grupos del laboratorio están verificadas; el cambio de contraseña en el
primer inicio se comprobó con `jperez`.

## Bajas y deshabilitación

Para una baja temporal o una investigación, deshabilitar es reversible:

```powershell
Disable-ADAccount -Identity usuario
Get-ADUser usuario | Select-Object SamAccountName, Enabled
```

Para retirar accesos:

```powershell
Get-ADPrincipalGroupMembership usuario |
    Where-Object Name -like 'GG_*' |
    ForEach-Object { Remove-ADGroupMember -Identity $_.Name -Members usuario -Confirm:$false }
```

Cerrar las sesiones abiertas en los equipos y verificar la revocación:

```powershell
# En DC01: sesiones SMB del usuario
Get-SmbSession | Where-Object ClientUserName -match '\\usuario$' | Close-SmbSession -Force
# En cada equipo donde trabajaba (por ejemplo, CL01 por PowerShell Direct)
quser
logoff <ID>
```

Verificado el 18/11/2026 (ticket T10): deshabilitar la cuenta no cortó la
sesión que seguía abierta, que leyó `Publico` un minuto después de la baja.
El acceso quedó revocado recién al cerrar la sesión en CL01. Un inicio de
sesión nuevo se rechaza con «Su cuenta está deshabilitada». Un desbloqueo
llegó a entrar con credenciales en caché, sin acceso a la red. No se
aplicó `CachedLogonsCount=0`; el motivo está en T10.

La eliminación definitiva (`Remove-ADUser`) no se ejecutó en este laboratorio.
Si se autoriza, hacer antes un checkpoint y registrar qué se elimina. No se
debe usar como primer paso para resolver un acceso denegado.

## Bloqueo y desbloqueo de cuentas

El bloqueo por intentos fallidos se comprueba con:

```powershell
Get-ADUser usuario -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt
```

Desbloquear solo después de verificar la identidad del usuario y la causa:

```powershell
Unlock-ADAccount -Identity usuario
```

El dominio tiene `LockoutThreshold=0`, así que por defecto no bloquea
cuentas. Para la práctica se aplicó a `mgomez` la PSO
`PSO-Bloqueo-Helpdesk` (5 intentos, 15 minutos). El bloqueo y el desbloqueo
se ejecutaron y verificaron el 18/11/2026 (ticket T08). Después se eliminó
la PSO con `Remove-ADFineGrainedPasswordPolicy -Identity
'PSO-Bloqueo-Helpdesk' -Confirm:$false`, así que hoy no hay bloqueo por
intentos fallidos en ninguna cuenta.

## Restablecimiento de contraseña

```powershell
$newPassword = Read-Host -AsSecureString 'Nueva contraseña'
Set-ADAccountPassword -Identity usuario -Reset -NewPassword $newPassword
Set-ADUser -Identity usuario -ChangePasswordAtLogon $true
Unlock-ADAccount -Identity usuario
```

No se envió la contraseña por correo ni se registró en el ticket. El
restablecimiento con cambio obligatorio se ejecutó con `mgomez` el
18/11/2026 y se comprobó al iniciar sesión en CL01 (ticket T08).

## Grupos y permisos

Para agregar o quitar un miembro:

```powershell
Add-ADGroupMember -Identity GG_Ventas -Members usuario
Remove-ADGroupMember -Identity GG_Ventas -Members usuario -Confirm:$false
Get-ADGroupMember GG_Ventas | Select-Object Name, SamAccountName
```

Los permisos efectivos del recurso se verifican con una sesión del usuario, no
solo con `Test-Path`:

```powershell
Get-ChildItem '\\DC01\Empresa\Publico'
New-Item '\\DC01\Empresa\Administracion\prueba.txt' -ItemType File
Get-ChildItem '\\DC01\Empresa\Ventas'
```

`Test-Path` puede devolver `True` aunque el listado o la escritura estén
denegados; no se usa como prueba de permiso.

Para cambiar NTFS, registrar el estado anterior y probar después:

```powershell
icacls C:\Empresa\Ventas
icacls C:\Empresa\Ventas /grant:r 'EMPRESA\GG_Ventas:(OI)(CI)(M)'
icacls C:\Empresa\Ventas
```

El recurso SMB `Empresa` otorga `Change` a `Usuarios del dominio`; el control
fino se aplica con NTFS. No se debe ampliar el permiso SMB para “resolver” un
acceso denegado sin revisar primero NTFS y la pertenencia al grupo.

## Políticas de grupo

La GPO `GPO-Bloqueo-Pantalla` está vinculada a `OU=EMPRESA`. Para modificarla:

```powershell
Set-GPRegistryValue -Name GPO-Bloqueo-Pantalla `
    -Key 'HKCU\Control Panel\Desktop' -ValueName ScreenSaveTimeOut `
    -Type String -Value '300'
```

En la sesión del usuario de prueba:

```powershell
gpupdate /target:user
gpresult /r
Get-ItemProperty 'HKCU:\Control Panel\Desktop' |
    Select-Object ScreenSaveActive, ScreenSaveTimeOut, ScreenSaverIsSecure
```

No usar `gpupdate /force` como diagnóstico universal. Si la GPO no aparece,
revisar el vínculo, la OU del usuario, el filtrado de seguridad, el orden de
las GPO y los eventos de Group Policy antes de cambiar algo.

El bloqueo efectivo por inactividad se comprobó con `jperez` el 18/11/2026:
`LogonUI`/`LockApp` aparecieron en su sesión
(`C:\LAB\Evidencias\screenlock-20261118-02`). La prueba manual de las 19:04
a las 19:12 comprobó que al volver se exige la contraseña y se recupera la
misma sesión (T03).

## DNS

En DC01:

```powershell
Get-DnsServerZone
Get-DnsServerResourceRecord -ZoneName ad.empresa.test -RRType A
Get-DnsServerForwarder
Resolve-DnsName dc01.ad.empresa.test -Type A
Resolve-DnsName _ldap._tcp.dc._msdcs.ad.empresa.test -Type SRV
```

La configuración base no tiene reenviadores ni ruta por defecto. No agregar
reenviadores, abrir Internet ni publicar puertos sin autorización. Si se crea
un registro temporal para una ventana de mantenimiento, registrar cuál se
creó y eliminarlo al cerrar; no confiar en que el cierre de la interfaz lo
borre solo.

## DC01: salud del dominio

```powershell
dcdiag /test:dns
repadmin /showrepl
Get-Service NTDS, DNS, Netlogon, KDC, LanmanServer
w32tm /query /status
Get-WinEvent -LogName 'Directory Service' -MaxEvents 20
```

Hay un solo controlador: `repadmin` no practica replicación entre sitios y no
demuestra alta disponibilidad. Revisar espacio en disco y la hora antes de
atribuir un fallo a AD.

## CL01: salud del cliente

```powershell
Test-ComputerSecureChannel
Get-DnsClientServerAddress -AddressFamily IPv4
Resolve-DnsName ad.empresa.test
gpresult /r
Get-Service Dnscache, LanmanWorkstation, Netlogon, w32time
```

Si el canal seguro falla, no desunir el equipo como primer intento. Verificar
DNS, hora y conectividad; después evaluar `Test-ComputerSecureChannel -Repair`
con credenciales de dominio. Una reparación o rejoin requiere checkpoint y
registro de la causa.

## Cambios y comunicación

Para cada cambio:

1. Registrar el síntoma, el alcance y el usuario afectado.
2. Guardar evidencia de solo lectura antes de modificar.
3. Crear checkpoint y aplicar el cambio mínimo.
4. Verificar con una prueba reproducible.
5. Registrar el resultado, la reversión y cualquier limitación.
6. Comunicar al usuario qué se hizo, qué debe probar y cuándo volver.

No se publican capturas con nombres reales, rutas personales, correos,
credenciales ni claves. Las identidades del laboratorio son ficticias, pero
igual deben revisarse antes de publicar.

## Qué no hacer

- No unir el host al dominio ni cambiar su DNS.
- No conectar `LAB-AD` al router ni abrir puertos.
- No deshabilitar firewall, antivirus ni protecciones para “probar”.
- No ejecutar `/ato` ni `rearm` sin autorización y sin revisar el estado real.
- No borrar checkpoints ni discos virtuales sin confirmación.
- No presentar procedimientos no ejecutados como resultados verificados.
