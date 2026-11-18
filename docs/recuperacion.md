# Recuperación del laboratorio

Procedimientos de recuperación para un laboratorio con **un solo
controlador de dominio**, sin respaldo corporativo y con checkpoints de
Hyper-V. Distingue lo comprobado de lo que es un procedimiento propuesto.

## Advertencias

- Un checkpoint de Hyper-V no es un respaldo de AD. Revierte la VM completa y
  puede perder cambios posteriores, incluida la activación o el estado de
  licencia.
- No hay un segundo DC, replicación, clúster ni sistema de respaldo del
  dominio. La recuperación depende del checkpoint o de reconstruir.
- No se probó una restauración autoritativa de AD, una recuperación de DSRM
  ni un arranque desde un respaldo del host. No se presentan como hechos.
- Ante una falla del disco físico del host se pierden las VM y las evidencias
  locales. Mantener copias de la documentación fuera del equipo.
- Las evaluaciones vencen. Restaurar un checkpoint no concede un nuevo
  período de evaluación.

## Árbol de decisión

1. **¿Falla solo CL01?** Seguir la sección de cliente. No tocar AD ni DNS.
2. **¿Falla DC01 o el dominio?** Detener cambios, guardar evidencia y revisar
   servicios, DNS, hora y espacio antes de reiniciar o restaurar.
3. **¿Hay una cambio reciente?** Identificar el checkpoint anterior y el
   alcance de lo que se perdería.
4. **¿No hay checkpoint útil?** Reconstruir según
   [reconstruccion.md](reconstruccion.md), con aprobación.
5. **¿Hay duda sobre DSRM o restauración de AD?** No improvisar. Documentar y
   buscar asistencia; un paso incorrecto puede dejar el dominio inaccesible.

## CL01: canal seguro o confianza rota

Síntomas: error de inicio de sesión, “no se puede establecer una relación de
confianza” o `Test-ComputerSecureChannel` devuelve `False`.

1. Verificar red, DNS y hora:

```powershell
Get-NetIPConfiguration
Get-DnsClientServerAddress -AddressFamily IPv4
Resolve-DnsName ad.empresa.test
w32tm /query /status
Test-ComputerSecureChannel -Verbose
```

2. Si DNS y hora son correctas, intentar la reparación con credenciales de
   dominio, sin guardar la contraseña:

```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential -UserName 'EMPRESA\Administrador')
```

3. Reiniciar y volver a comprobar. Si sigue fallando, evaluar un rejoin
   controlado: crear checkpoint, salir del dominio, reiniciar, volver a unir
   en `OU=Equipos` y verificar. Un rejoin puede requerir limpiar la cuenta de
   equipo duplicada; hacerlo solo con autorización.

4. Verificar:

```powershell
Test-ComputerSecureChannel
gpresult /r
Get-ADComputer CL01
```

La reparación del canal seguro no se ejecutó en este laboratorio; el
procedimiento queda documentado. No se debe usar como primera acción si el
problema es DNS o hora.

## CL01: no aplica la GPO

1. Confirmar que el usuario está en la OU correcta y que la GPO está
   vinculada a `OU=EMPRESA`.
2. Ejecutar `gpresult /r` y revisar el orden, el filtrado y los eventos.
3. Comprobar los valores del registro del usuario.
4. Si la GPO aparece aplicada pero el bloqueo no ocurre, revisar el tiempo de
   espera, el protector de pantalla y la sesión interactiva. No cambiar la
   GPO sin una hipótesis concreta.

## CL01: cuenta bloqueada o contraseña vencida

1. Confirmar el estado en DC01:

```powershell
Get-ADUser usuario -Properties LockedOut, PasswordExpired, PasswordLastSet, LastBadPasswordAttempt |
    Select-Object SamAccountName, Enabled, LockedOut, PasswordExpired, PasswordLastSet, LastBadPasswordAttempt
```

2. Verificar la identidad del usuario y desbloquear o restablecer según
   [administracion.md](administracion.md).
3. Probar el inicio de sesión y exigir cambio de contraseña si corresponde.
4. No enviar contraseñas por correo ni registrarlas en el ticket.

## CL01: reconstrucción

Si el sistema está corrupto y no hay un checkpoint útil:

1. Guardar las evidencias que se puedan extraer.
2. Crear la VM de nuevo o restaurar el checkpoint más cercano.
3. Instalar Windows 11 Enterprise, asignar `10.10.10.20/24`, DNS
   `10.10.10.10`, nombre `CL01`.
4. Unir a `OU=Equipos` y probar con `jperez`.
5. Verificar GPO, recurso compartido y canal seguro.

## DC01: servicios detenidos o dominio no responde

1. No reiniciar en cadena. Registrar hora, estado de la VM y últimos eventos.
2. Comprobar servicios y DNS:

```powershell
Get-Service NTDS, DNS, Netlogon, KDC, LanmanServer
Get-DnsServerZone
dcdiag /test:dns
```

3. Revisar espacio en disco, memoria y hora:

```powershell
Get-PSDrive C
w32tm /query /status
Get-WinEvent -LogName System -MaxEvents 30
```

4. Si un servicio está detenido, revisar el evento que lo detuvo antes de
   iniciarlo. Iniciar `NTDS` o `DNS` sin diagnóstico puede ocultar la causa.
5. Si el problema empezó después de un cambio, evaluar el checkpoint anterior
   con el responsable. Antes de aplicarlo, anotar qué datos se perderán.

## DC01: DNS incorrecto o zona dañada

Síntomas: CL01 no encuentra el dominio, fallan `_ldap._tcp` o el registro A
de DC01.

```powershell
Get-DnsServerZone
Get-DnsServerResourceRecord -ZoneName ad.empresa.test -RRType A
Get-DnsServerResourceRecord -ZoneName ad.empresa.test -RRType SRV
Get-DnsServerForwarder
Resolve-DnsName dc01.ad.empresa.test
Resolve-DnsName _ldap._tcp.dc._msdcs.ad.empresa.test -Type SRV
```

- Si falta un registro, comprobar primero si el servicio DNS y el registro
  dinámico están funcionando. No crear registros duplicados a ciegas.
- Si la zona está dañada y hay checkpoint previo, restaurar la VM es la vía
  más segura en este laboratorio. No hay zona secundaria.
- Si se recrea la zona, verificar los registros SRV y el registro A de CL01;
  documentar el cambio.

## DC01: base de AD o DSRM

No se ejecutó ninguna restauración de AD. Consideraciones:

- La contraseña de DSRM se definió al promover el bosque y no se guarda en el
  repositorio. Si se perdió, no se debe intentar un reset improvisado.
- `ntdsutil` y una restauración autoritativa requieren una ventana de
  mantenimiento, un respaldo válido y conocimiento del alcance. No se usan
  como prueba en este laboratorio.
- Un checkpoint puede devolver el DC a un estado anterior, pero también
  revierte usuarios, contraseñas, GPO y registros DNS creados después. Es una
  reversión, no una recuperación selectiva.
- Si no hay checkpoint ni respaldo, la opción documentada es reconstruir el
  dominio y volver a unir CL01. Eso implica recrear identidades, permisos,
  recurso y GPO.

## DC01: eliminación accidental de un usuario o OU

- No se verificó que AD Recycle Bin esté habilitado ni se probó una
  restauración de objetos eliminados.
- Si hay checkpoint anterior, se puede revertir la VM, con pérdida de los
  cambios posteriores.
- Si no hay checkpoint, recrear el objeto y sus permisos, verificar la
  pertenencia a grupos y documentar la pérdida.
- No se debe prometer una restauración autoritativa sin haberla probado.

## GPO: copia y restauración

Si se necesita un cambio riesgoso, respaldar la GPO antes:

```powershell
New-Item -ItemType Directory -Path C:\LAB\Evidencias\gpo-backup -Force
Backup-GPO -Name GPO-Bloqueo-Pantalla -Path C:\LAB\Evidencias\gpo-backup
```

Restaurar solo con autorización:

```powershell
Restore-GPO -Name GPO-Bloqueo-Pantalla -Path C:\LAB\Evidencias\gpo-backup
gpresult /r
```

El respaldo de GPO no respalda AD ni el resto de los datos. No se ejecutó una
restauración de GPO en este laboratorio.

## Validación posterior a cualquier recuperación

- [ ] DC01 responde `Get-ADDomain` y `Get-ADForest`.
- [ ] `NTDS`, `DNS` y `Netlogon` están en ejecución.
- [ ] La zona `ad.empresa.test` resuelve DC01 y los SRV de LDAP.
- [ ] CL01 tiene `10.10.10.20/24`, DNS `10.10.10.10` y ninguna ruta por
      defecto.
- [ ] `Test-ComputerSecureChannel` devuelve `True` en CL01.
- [ ] `jperez` puede leer `Publico` y escribir en `Administracion`; `Ventas`
      sigue denegado.
- [ ] La GPO aparece aplicada y el bloqueo se prueba funcionalmente.
- [ ] Los scripts de diagnóstico no muestran críticos nuevos.
- [ ] Se registran hora, causa, cambios, pérdida de datos y seguimiento.

## Limitaciones de recuperación

- Sin respaldo del dominio, sin DC secundario y sin restauración probada.
- Sin recuperación selectiva: el checkpoint revierte toda la VM.
- Sin garantía de conservar la activación después de una reversión o
  reconstrucción.
- Sin recuperación del host si falla el disco físico; las copias de la
  documentación deben estar fuera del equipo.
