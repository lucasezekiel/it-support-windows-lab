# Bitácora del laboratorio

Registro de acciones realizadas, resultados observados y reversión.
Solo se anotan hechos verificados.

## 16/11/2026 — Preparación del host y DC01

**Relevamiento (solo lectura)**

- Windows 11 Pro 10.0.26200, 64 bits.
- Ryzen 9 5900XT, 16 núcleos / 32 hilos, virtualización y SLAT disponibles.
- 15,9 GB de RAM; SSD NVMe de 931,5 GB.
- Hyper-V, WSL y plataforma de máquina virtual deshabilitados al inicio.
- BitLocker de C: desactivado (confirmado por el usuario).

**Cambios aplicados**

1. Hyper-V habilitado con `Enable-WindowsOptionalFeature -FeatureName
   Microsoft-Hyper-V-All -NoRestart` y reinicio manual.
   Resultado: `HypervisorPresent: True`; `vmms` y `vmcompute` en ejecución.
2. Creadas las carpetas `C:\LAB\ISO`, `C:\LAB\VMs` y `C:\LAB\Evidencias`.
3. Movidas y renombradas las ISO de evaluación:
   - `WS2025_Eval_x64_es-es.iso` (7,60 GB)
   - `Win11_Enterprise_Eval_x64_es-es.iso` (7,66 GB)
   Se registraron sus hashes SHA-256.
4. Creado el switch privado `LAB-AD`. Verificado que el host no obtiene
   adaptador en esa red.
5. Creada DC01 (generación 2, 4 GB fijos, 2 CPU, disco dinámico de 80 GB,
   ISO como primer arranque, checkpoints automáticos desactivados).
6. Instalado Windows Server 2025 Standard (Desktop Experience).
7. Checkpoint `01-instalacion-limpia` creado el 16/11/2026 a las 21:09.

**Observaciones**

- El TPM virtual de DC01 no se habilitó por falta de protector de clave.
  No es requisito para Windows Server en este alcance.
- La sesión no elevada no puede consultar BitLocker; se verificó desde el
  panel de Windows.

**Reversión**

- Hyper-V: `Disable-WindowsOptionalFeature -Online -FeatureName
  Microsoft-Hyper-V-All -NoRestart` y reinicio.
- DC01: apagar, `Remove-VM DC01 -Force` y borrar `C:\LAB\VMs\DC01`.

## 17/11/2026 — Dominio, cliente y políticas

**DC01**

1. Zona horaria Argentina; IP `10.10.10.10/24`; DNS `127.0.0.1`.
2. Equipo renombrado a `DC01` y reiniciado.
3. Rol `AD-Domain-Services` instalado (`Success: True`, sin reinicio).
4. Bosque `ad.empresa.test` promovido con NetBIOS `EMPRESA` e DNS integrado.
   El primer intento falló por complejidad de la contraseña DSRM; se repitió
   con una contraseña que cumple la política.
5. Verificado: `DNSRoot ad.empresa.test`, `Windows2025Domain`, `NTDS` y `DNS`
   en ejecución, zonas primarias creadas, `\\DC01\SYSVOL` accesible.
6. Creadas las OU, los tres grupos y los cuatro usuarios ficticios.
7. Creado `C:\Empresa` con `Publico`, `Ventas` y `Administracion`, permisos
   NTFS explícitos y recurso SMB `Empresa`.
8. Creada y vinculada la GPO `GPO-Bloqueo-Pantalla` a `OU=EMPRESA`.

**CL01**

1. Creada con generación 2, 4 GB, 2 CPU, Secure Boot y TPM virtual.
   En Hyper-V de cliente el protector se creó con
   `Set-VMKeyProtector -NewLocalKeyProtector` (no existe
   `New-VMKeyProtector`).
2. Instalado Windows 11 Enterprise 26H2 con cuenta local `localadmin`.
3. IP `10.10.10.20/24`, DNS `10.10.10.10`; equipo renombrado a `CL01`.
4. Unión al dominio en `OU=Equipos` con `Add-Computer`.
5. Inicio de sesión con `EMPRESA\jperez`; cambio de contraseña exigido.

**Verificaciones**

- `gpresult /r`: `GPO-Bloqueo-Pantalla` aplicada.
- Registro: `ScreenSaveActive 1`, `ScreenSaveTimeOut 300`,
  `ScreenSaverIsSecure 1`.
- `Publico\aviso.txt` legible; escritura correcta en `Administracion`.
- `Ventas`: listado y escritura denegados con “Acceso denegado”.
- `Test-Path` sobre `Ventas` devuelve `True`, mientras listar y escribir
  devuelve acceso denegado; la existencia no demuestra esos permisos.

**Observaciones**

- Un pegado en la consola contaminó la variable `$ruta`; la prueba se repitió
  con rutas literales para obtener evidencia válida.
- Windows 11 muestra «La licencia de Windows expiró». Se había interpretado
  como activación pendiente; la causa y el vencimiento real deben consultarse
  dentro de la VM.

**Pendiente**

- Activación antes del 26/11/2026 (Server).
- Tickets, scripts y documentación de procedimientos.

## 18/11/2026 — Inicio del diagnóstico de activación

- Autorizado el acceso temporal mediante adaptadores adicionales en
  `Default Switch`, filtros de tráfico, activación y retirada posterior.
- El plan requiere aplicar los filtros antes de conectar los adaptadores,
  mantener `LAB-AD` privado y comprobar los registros DNS del controlador.
- Preparada una auditoría de solo lectura mediante PowerShell Direct.
  Las credenciales se solicitan localmente y no se guardan en los informes.
- Primer intento: se detuvo por un valor nulo en el script de auditoría.
  Se corrigió el manejo de listas de reenviadores vacías.
- Segundo intento: el usuario canceló el cuadro de credenciales; se detuvo.
- Tercer intento: DC01 consultada correctamente; CL01 rechazó la credencial
  local propuesta. El usuario aclaró que la cuenta de dominio se llama
  `EMPRESA\Administrador`, y autorizó usarla para CL01.
- Cuarto intento: CL01 consultada correctamente con esa cuenta.
- DC01: build `26100`, Server Standard Evaluation; `/xpr` informa fin del
  período de gracia inicial el **26/11/2026 a las 16:45:00**.
- CL01: build `26300`, Enterprise Evaluation; `/xpr` informa **modo de
  notificación**. No es una activación válida.
- Ambas VM conservaban una interfaz en `LAB-AD`, sin ruta IPv4 por defecto,
  y todos los perfiles del firewall activos.
- Primer intento de acceso temporal (`activacion-ejecucion-20261118-01`):
  la comprobación detectó la IP temporal de DC01 en un registro A, pese a
  estar desactivado el registro DNS de la interfaz. Se detuvo antes de
  solicitar la activación.
- Reversión sin errores informados: un adaptador por VM en `LAB-AD`,
  cero rutas IPv4 por defecto, firewall activo y resolución de DC01
  únicamente a `10.10.10.10`. El informe no conservó el nombre/IP del
  registro detectado ni informó registros eliminados durante la limpieza.
- Activación pendiente. Revisada la guía Microsoft KB 2023004 sobre
  registro DNS de controladores con varias interfaces; el siguiente
  procedimiento debe acotar también la escucha del servidor DNS y
  guardar los registros concretos si vuelve a activarse la salvaguarda.
- Conservada una copia del procedimiento usado en el primer intento como
  `procedure-used-recovered.ps1`, con el mismo SHA-256 que el origen.
- La auditoría `activacion-auditoria-20261118-05` fue rechazada al validar
  la credencial; no abrió sesión ni aplicó cambios.
- Preparada una corrección con copia y restauración de `ListenAddresses`,
  `PublishAddresses` y reenviadores, prueba de resolución local y registro
  exacto de cualquier incidencia DNS. La activación continúa pendiente.
- Comprobación `activacion-preflight-20261118-01` completada con código 0,
  sin crear adaptadores ni modificar servicios. Confirmó que los valores
  `ListenAddresses` y `PublishAddresses` no existían originalmente, que no
  había reenviadores y que los registros A solo usaban IP del laboratorio.
  Las dos VM conservaron una interfaz privada, sin rutas por defecto, y
  `dc01.ad.empresa.test` resolvió únicamente a `10.10.10.10`.
- Segundo intento (`activacion-ejecucion-20261118-02`): `dnscmd` rechazó
  `127.0.0.1` como dirección de escucha, error 9552. No se conectó el
  adaptador ni se ejecutó `/ato`.
- La reversión restableció las direcciones de escucha correctamente. El
  informe final demuestra que `ListenAddresses` y `PublishAddresses`
  quedaron ausentes como al inicio, sin reenviadores, con los mismos
  listeners observados y DNS/NTDS/Netlogon activos.
- La limpieza devolvió código 2 por un error de verificación al procesar
  un valor nulo, no por una diferencia DNS residual. Se corrigió esa
  lectura. La topología final volvió a un adaptador privado por VM,
  sin rutas por defecto y con firewall activo.
- Se retiró loopback de la lista de escucha para el siguiente intento;
  su resolución local seguirá siendo una prueba obligatoria antes de
  conectar. Activación todavía pendiente.
- Tercer intento (`activacion-ejecucion-20261118-03`): la restricción DNS
  de DC01 funcionó; no aparecieron registros A temporales antes ni después
  de `/ato`. DC01 se activó correctamente; `/xpr` informa vencimiento el
  **17/05/2027** y el producto quedó con `LicenseStatus=1` y 259200 minutos
  de gracia. La hora mostrada varió entre consultas.
- CL01 no se activó: `/ato` devolvió `0xC004E028`; `/xpr` sigue en modo de
  notificación, con `LicenseStatus=5`, razón `0xC004F009` y gracia 0. No se
  reintentó. Microsoft documenta ese código como una activación ya en
  curso; no prueba una clave inválida.
- La limpieza de DC01 dejó `PublishAddresses=10.10.10.10` porque la
  comprobación de existencia usó `Get-Item`. La auditoría independiente
  `activacion-auditoria-20261118-06` lo confirmó y la reparación
  `activacion-reparacion-dns-20261118-01` lo eliminó, reinició DNS y
  verificó la configuración original.
- La auditoría 06 también confirmó el registro `CL01 -> 10.10.10.20`.
  La captura que lo omitió fue tomada inmediatamente después del reinicio
  de DNS y no se interpreta como una eliminación.
- El procedimiento se ajustó para activar una sola VM por ejecución y
  esperar a una activación automática antes de solicitar `/ato`. DC01 ya no
  recibe otra solicitud.
- Diagnóstico `activacion-diagnostico-cl01-20261118-02`: CL01 se apagó a
  las **14:58:41** por `wlms.exe` con el mensaje «El período de licencia de
  esta instalación de Windows ha expirado». Hyper-V registró el cierre del
  invitado a las 14:58:43.
- Los eventos de Security-SPP muestran `0x80072EE7` (resolución de nombres)
  en la activación automática durante el intento 03. El `0xC004E028` del
  `/ato` manual fue una colisión con esa activación en curso, no un rechazo
  de licencia.
- CL01 se encendió de nuevo para el diagnóstico; conserva una interfaz en
  `LAB-AD`, sin ruta por defecto, DNS `10.10.10.10` y resolución del
  dominio. No se modificó la licencia ni se ejecutó `rearm`.
- La línea base de DC01 en el mismo diagnóstico sigue activada hasta el
  **17/05/2027**, sin `ListenAddresses` ni `PublishAddresses`, sin
  reenviadores, con DNS/NTDS/Netlogon activos y el registro
  `CL01 -> 10.10.10.20` presente.
- Cuarto intento (`activacion-ejecucion-20261118-04`), solo CL01: la
  interfaz temporal obtuvo `172.26.213.221` con registro DNS desactivado;
  no aparecieron registros A temporales, la LAN doméstica no fue alcanzable
  y los nombres de activación resolvieron a `48.192.1.65`.
- La espera de 60 segundos mantuvo CL01 en estado 5. A las 15:09:01–02 hubo
  actividad de Security-SPP; el `/ato` de las 15:09:03 devolvió
  `0xC004E028` por otra activación en curso, pero la licencia quedó
  `LicenseStatus=1`, con 129600 minutos de gracia y `/xpr` 16/02/2027
  15:09:03.
- El script marcó `ActivationCompleted=false` porque comprobó el código de
  `/ato` antes que `LicenseStatus`; no es un rechazo de licencia. No se
  repitió `/ato`. El código de error se conserva en el informe.
- La limpieza terminó sin errores: regla de firewall y adaptador temporal
  retirados, sin registros A temporales y una interfaz `LAB-AD` por VM.
- Auditoría `activacion-auditoria-20261118-07`: CL01 activado hasta el
  **16/02/2027**, `10.10.10.20/24`, DNS `10.10.10.10`, cero rutas por
  defecto y firewall activo. DC01 sigue activado hasta el **17/05/2027**,
  sin `ListenAddresses` ni `PublishAddresses`, sin reenviadores, con
  DNS/NTDS/Netlogon activos y el registro `CL01 -> 10.10.10.20` presente.
- Ambas evaluaciones quedaron activadas. La ventana temporal de Internet se
  cerró y la topología volvió al aislamiento.
- A las **15:14:31**, CL01 seguía encendida (13 minutos de uptime) y no se
  observó un nuevo apagado por licencia.

## 18/11/2026 — Scripts de inventario y diagnóstico

- Se escribieron `Get-LabADInventory.ps1` y `Test-LabClientHealth.ps1` como
  herramientas de solo lectura, con límites por sección y salidas JSON/TXT.
  No modifican AD, DNS, GPO, firewall ni servicios.
- El primer ejecutor no arrancó: la consola elevada aplicaba
  `ExecutionPolicy Restricted`. Se relanzó con `-ExecutionPolicy Bypass
  -File`; no se aplicaron cambios.
- El primer inventario falló con «No se encuentra ningún parámetro que
  coincida con el nombre del parámetro 'ResultPageSize'». La causa fue
  `Get-ADDomainController -Filter * -ResultPageSize 100`; el parámetro no
  existe en ese cmdlet y se eliminó. El error exacto quedó en
  `scripts-20261118-01-diagnostico`.
- El segundo ejecutor se detuvo al copiar una carpeta de inventario vacía y
  ocultó el error original. Se corrigió para escribir las consolas antes de
  copiar, comprobar archivos en el invitado y usar un directorio nuevo.
- Tercera ejecución (`scripts-20261118-02`): inventario con código 0; CL01
  con código 1 y DC01 con código 2. El crítico de DC01 era un falso positivo:
  `Test-ComputerSecureChannel` no aplica al propio controlador. Además, la
  comprobación de bloqueo falló al leer una propiedad ausente y
  `Domain Admins`/`Enterprise Admins` figuraban como inexistentes porque sus
  nombres SAM están localizados (`Admins. del dominio`,
  `Administradores de empresas`).
- Se corrigió el diagnóstico para omitir el canal seguro en un controlador
  (según `DomainRole` 4/5), leer el registro de forma tolerante y localizar
  los grupos conocidos por SID (`-512` y `-519`). El inventario se ajustó
  además para serializar enums como texto y limpiar la salida de DNS.
- Cuarta ejecución (`scripts-20261118-03`): inventario 0, CL01 1 y DC01 1;
  los grupos conocidos se resolvieron correctamente. El detalle de bloqueo
  seguía vacío porque `Get-ItemPropertyValue` lanzaba una excepción pese a
  `-ErrorAction SilentlyContinue`. Se reemplazó por `Get-ItemProperty` y
  `PSObject.Properties`; versión 1.0.2 del diagnóstico.
- Quinta ejecución (`scripts-20261118-04`), validación final: inventario 0,
  CL01 1 y DC01 1, sin críticos. El bloqueo informa `ScreenSaveActive=1` y
  `ScreenSaveTimeOut`/`ScreenSaverIsSecure` ausentes para
  `EMPRESA\Administrador`; es esperado, porque la GPO se verificó en la
  sesión de `jperez`. Los errores recientes son históricos de activación,
  unión al dominio, TPM/BitLocker, DCOM y KDC, no fallos nuevos.
- Hashes SHA-256 de la ejecución final: inventario
  `9B036F06FB16DFE86E8B573BCBB95E03BE444E7DE5C150E120783F5488FADAD5`;
  diagnóstico `BC4FB8F8E2A9B1F0AB96D3446C3A91454ADEA69C18F4DDEC5E636CFCD6C440B1`.
  Evidencia en `C:\LAB\Evidencias\scripts-20261118-04`, con copias de los
  scripts y sus hashes.
- La verificación es de solo lectura. No se probó el bloqueo efectivo de
  `jperez` ni se modificaron identidades para forzarlo.

## 18/11/2026 — Documentación, tickets y prueba de bloqueo

- Se redactaron `docs/reconstruccion.md`, `docs/administracion.md` y
  `docs/recuperacion.md`. La reconstrucción sintetiza los pasos verificados y
  aclara que no se ejecutó como una reconstrucción completa desde cero. Los
  procedimientos de desbloqueo, restablecimiento y recuperación de AD quedan
  identificados como no ejecutados.
- Se crearon siete tickets en `tickets/`: unión al dominio, acceso denegado a
  Ventas, GPO de bloqueo, licencia de CL01, error `ResultPageSize`, falso
  crítico de DC01 y aislamiento de Internet. Cada uno incluye evidencia y
  límites; no se presentan como probados los pasos que no se ejecutaron.
- Se actualizaron el README raíz, `scripts/README.md`, `docs/arquitectura.md`,
  `docs/limitaciones.md` y `evidencias/README.md` con las versiones 1.0.1 y
  1.0.2, la evidencia `scripts-20261118-04` y los hashes.
- Una sonda de solo lectura en CL01 confirmó que la sesión estaba en la
  pantalla de inicio, que `jperez` no tenía sesión interactiva y que su perfil
  no estaba cargado. Por eso la prueba funcional de bloqueo requiere un
  inicio de sesión manual y no se deduce de los valores del registro.
- Se preparó una prueba de solo lectura que detecta la sesión de `jperez`,
  registra los valores de la GPO en su perfil, espera 5,5 minutos sin
  interacción y comprueba si `LogonUI`/`LockApp` aparece en la misma sesión.
  El resultado se registra en `C:\LAB\Evidencias\screenlock-20261118-01`.
- Nada fue publicado. El repositorio sigue sin commit ni remoto; la
  publicación requiere autorización expresa.

## 18/11/2026 — Prueba funcional del bloqueo de pantalla

- `screenlock-20261118-01` quedó vacía: esa ejecución no dejó archivos y no
  se usa como evidencia.
- Sonda `screenlock-probe-20261118-02` (16:15:10): `jperez` con sesión de
  consola 1 activa desde las 16:07, `explorer` en la sesión 1, sin `LogonUI`
  ni `LockApp`.
- Diagnóstico `gpo-screenlock-diagnostico-20261118-01` (16:17:30):
  `GPO-Bloqueo-Pantalla` con `AllSettingsEnabled`, vinculada a
  `OU=EMPRESA` (habilitada, sin forzar), `GpoApply` para Usuarios
  autentificados; `jperez` en `OU=Administracion,OU=Usuarios,OU=EMPRESA`.
- Prueba `screenlock-20261118-02`, de solo lectura, de 16:19:35 a 16:25:06,
  330 segundos sin interacción. Valores efectivos de `jperez`:
  `ScreenSaveActive=1`, `ScreenSaveTimeOut=300` y `ScreenSaverIsSecure=1`
  (clave de políticas del perfil).
- Resultado: `Locked=True`. `LogonUI` y `LockApp` aparecieron en la sesión 1
  a las **16:22:16**, con el mismo `explorer` en ejecución; la sesión se
  bloqueó, no se cerró.
- El bloqueo ocurrió 161 segundos después del inicio de la prueba. El
  contador de inactividad de Windows empezó antes, desde la última entrada
  del usuario, que no se registró. La prueba acredita el bloqueo por
  inactividad, no mide los 300 segundos exactos.
- No se probó manualmente que al volver se exija la contraseña. Queda
  pendiente.
- Sin cambios en la GPO, el usuario ni CL01.

## 18/11/2026 — Tickets completados según la plantilla

- Se agregaron a T01–T07 las secciones «Impacto y prioridad», «Hipótesis»,
  «Respuesta al usuario» y «Criterio de escalamiento». T03 ya tenía su
  respuesta al usuario.
- Las hipótesis se clasificaron como confirmadas, descartadas o no probadas,
  solo a partir de lo que ya registraban los diagnósticos. No se ejecutaron
  pruebas nuevas.
- Las respuestas al usuario son textos redactados para el caso simulado: no
  se enviaron a ninguna persona.
- Sin cambios en DC01, CL01 ni el host.

## 18/11/2026 — Relevamiento previo a las prácticas de helpdesk

- Relevamiento de solo lectura `helpdesk-relevamiento-20261118-01` (17:38),
  ejecutado desde el host con PowerShell Direct sobre DC01.
- Política por defecto del dominio: `LockoutThreshold=0`, es decir, sin
  bloqueo por intentos fallidos. Complejidad activada, `MinPasswordLength=0`,
  `PasswordHistoryCount=0` y `MaxPasswordAge` de 42 días. No hay PSO.
- Auditoría de «Bloqueo de cuenta» y «Administración de cuentas de usuario»
  en «Aciertos». La papelera de reciclaje de AD está deshabilitada.
- Usuarios: `jperez` (Administración), `mgomez` y `dsuarez` (Ventas) y
  `crodriguez` (Soporte), todos habilitados, sin bloqueo y con
  `BadLogonCount=0`. Sin sesiones SMB abiertas en DC01.
- NTFS sin cambios respecto de `docs/arquitectura.md`.
- Checkpoints existentes: solo `01-instalacion-limpia` de DC01, anterior a la
  promoción del dominio. CL01 no tiene checkpoints.
- Incidencia del script: `Get-FileHash` intentó leer `sha256.csv` mientras se
  escribía. Los hashes de los otros tres archivos quedaron registrados y se
  verificaron después; `sha256.csv` no incluye su propio hash. Se corrigió el
  script para próximas ejecuciones y no se modificó la evidencia.
- Checkpoints creados desde el host a las 17:40: `02-pre-helpdesk-20261118`
  (DC01) y `01-pre-helpdesk-20261118` (CL01). Ambas VM tienen
  `CheckpointType=Standard`, así que los checkpoints incluyen el estado de
  memoria y no son de tipo Production (VSS). No se cambió el tipo.

## 18/11/2026 — T08: PSO de bloqueo para `mgomez`

- A las 17:42:50 se creó en DC01 la PSO `PSO-Bloqueo-Helpdesk`, aplicada solo
  a `mgomez`. Precedencia 10, `LockoutThreshold=5`, duración y ventana de
  observación de 15 minutos. Los valores de contraseña son iguales a los de
  la política por defecto.
- Antes del cambio, `mgomez` y `jperez` recibían la Default Domain Policy.
  Después, `mgomez` recibe la PSO y `jperez` sigue con la política por
  defecto. `mgomez`: `Enabled=True`, `LockedOut=False`, `BadLogonCount=0`.
- Evidencia: `C:\LAB\Evidencias\helpdesk-t08-pso-20261118-01`; hash
  verificado.
- Reversión: `Remove-ADFineGrainedPasswordPolicy -Identity
  'PSO-Bloqueo-Helpdesk' -Confirm:$false`.
- Prueba de bloqueo: ingresé en CL01 cinco contraseñas incorrectas
  para `EMPRESA\mgomez`. CL01 mostró «Credenciales no válidas, retrasando el
  siguiente intento…» (captura del host; contiene el nombre del equipo
  físico y no se publica sin recortar).
- Verificación de solo lectura `helpdesk-t08-bloqueo-20261118-01`:
  `LockedOut=True`, `BadLogonCount=5`, `LastBadPasswordAttempt` y
  `LockoutTime` a las **17:46:05**, y evento **4740** («Se bloqueó una cuenta
  de usuario») en DC01 a la misma hora. Hash verificado.
- `mgomez` nunca inició sesión: `PasswordLastSet` está vacío y debe cambiar
  la contraseña al iniciar. No hay eventos 4625/4771 porque la auditoría de
  inicio de sesión y Kerberos no se relevó; el script no extrajo el equipo de
  origen del 4740.
- Desbloqueo y restablecimiento (`helpdesk-t08-desbloqueo-20261118-01`, a
  las 17:49:10). Antes: `LockedOut=True`, `BadLogonCount=5`. Después:
  `LockedOut=False`, `BadLogonCount=0` y cambio obligatorio en el próximo
  inicio. Eventos 4767, 4724 y 4738 (dos veces). Hash verificado.
- Inicié sesión en CL01 como `mgomez` con la contraseña temporal.
  Windows exigió cambiarla, confirmó «Se cambió su contraseña» y comenzó el
  primer inicio de sesión. Las capturas recortadas, sin datos del host, se
  movieron a `evidencias/t08-01` … `t08-04`.
- Ticket `tickets/t08-usuario-bloqueado.md` redactado.
- La PSO `PSO-Bloqueo-Helpdesk` sigue activa para `mgomez`.

## 18/11/2026 — T09: alta de `lfernandez`

- Alta en DC01 a las 18:01:02 (`helpdesk-t09-alta-20261118-01`, hash
  verificado). Cuenta `lfernandez` (Lucia Fernandez) creada en `OU=Ventas`,
  habilitada, en `GG_Ventas`, con departamento `Ventas`, cambio de
  contraseña obligatorio y la Default Domain Policy como política efectiva.
- Eventos registrados: 4720, 4722, 4724 y 4738. No apareció el **4728**
  (alta en un grupo global), probablemente porque la auditoría de
  «Administración de grupos de seguridad» no está habilitada; no se
  verificó. La pertenencia al grupo sí consta en AD.
- CL01: el primer inicio de `lfernandez` exigió cambiar la contraseña
  (`evidencias/t09-01-cambio-obligatorio.jpg`). En la sesión, `whoami`
  devolvió `empresa\lfernandez` y el token incluye `EMPRESA\GG_Ventas`.
- Prueba de acceso: leer `Publico`, crear y borrar en `Ventas` funcionaron
  sin errores. En `Administracion`, PowerShell mostró «Acceso denegado a la
  ruta de acceso '\\DC01\Empresa\Administracion'».
- Fallo del bloque de prueba: `& $bloque -ErrorAction Stop` no aplica
  `-ErrorAction` a los cmdlets del bloque, así que el error no se capturó y
  la línea imprimió «PERMITIDO» para `Administracion`. El resultado real es
  el error de acceso denegado que aparece en pantalla. Se corrigió el bloque
  para repetir la prueba.
- Prueba de accesos repetida con el bloque corregido, a las 18:10:24:
  `whoami` devuelve `empresa\lfernandez`. Leer `Publico`, crear y borrar en
  `Ventas`: PERMITIDO. Listar `Administracion`: DENEGADO («Acceso denegado
  a la ruta de acceso»). Captura en `evidencias/t09-02-prueba-accesos.jpg`.
- Ticket `tickets/t09-alta-empleado.md` redactado.

## 18/11/2026 — T10: baja de `crodriguez`

- Línea base en CL01, antes de la baja: `whoami` devuelve
  `empresa\crodriguez`, el token incluye `EMPRESA\GG_Soporte` y la lectura
  de `\\DC01\Empresa\Publico` dio PERMITIDO. La sesión quedó abierta para la
  prueba posterior. El `Get-Date` falló porque el texto pegado en la consola
  de la VM llegó alterado (`-Form0;1_at`); la hora de referencia es la de la
  captura del host, 18:22:17. Captura en `evidencias/t10-01-linea-base.jpg`.
- Baja en DC01 a las 18:24:26 (`helpdesk-t10-baja-20261118-01`, hash
  verificado). Antes: `Enabled=True`, en `GG_Soporte`, con una sesión SMB
  abierta desde `10.10.10.20` (CL01). Después: `Enabled=False`, sin grupos
  `GG_*`, descripción de la baja y 0 sesiones SMB (se cerró 1). Eventos
  4725 y 4738 (dos veces); el 4729 no apareció.
- **Desvío:** pude volver a entrar a CL01 como `crodriguez` después de la
  baja. AD muestra la cuenta deshabilitada, así
  que el criterio de éxito «el inicio de sesión nuevo se rechaza» **no se
  cumplió** o no se probó como se esperaba. Se detiene T10 y se prepara un
  diagnóstico de solo lectura en CL01 y DC01: eventos 4624 con tipo de
  inicio, `lastLogon` en DC01 y eventos Kerberos/NTLM.
- Diagnóstico de solo lectura `helpdesk-t10-diagnostico-20261118-01` (hash
  verificado). Hechos observados:
  - CL01: 18:26:17, evento 4647 (cierre de sesión iniciado por el usuario).
    18:27:33, evento **4625** de `crodriguez` con `LogonType=7`, estado
    `0xC000006E` y subestado **`0xC0000072` (cuenta deshabilitada)**: el DC
    rechazó la autenticación. En el mismo segundo, evento **4624 con
    `LogonType=11` (CachedInteractive)**: CL01 permitió entrar con las
    credenciales en caché. `quser` muestra la sesión de consola de
    `crodriguez` activa desde las 18:27. `CachedLogonsCount=10`, canal
    seguro correcto.
  - DC01: `lastLogon` sigue en 18:17:22, así que no hubo autenticación
    contra el DC después de la baja. No hay 4768 (TGT) después de las
    18:17:22. Hay 4769 (vale de servicio) a las 18:22:03, 18:22:46 y
    **18:26:17**: la última es posterior a la baja y se emitió con el TGT
    obtenido a las 18:17:22.
- Conclusión: la baja en AD funcionó, porque el DC rechazó la cuenta. El
  reingreso fue un inicio local con credenciales en caché. Queda pendiente
  comprobar si esa sesión accede a recursos de red. Hipótesis no
  verificada: el KDC no revalida la cuenta en las solicitudes de vales de
  servicio mientras el TGT es reciente.
- Después reinicié CL01, o eso creí; no registré la hora respecto del
  diagnóstico. El diagnóstico `-05` mostró luego que la sesión de las 18:27
  seguía activa, así que CL01 no se reinició después de esa hora.
- Capturas de T10 en `evidencias/`:
  - `t10-02-baja-consola-host.jpg`: salida del script de baja. **Muestra
    una ruta del perfil del host**; no se publica sin recortar.
  - `t10-03-sesion-abierta-tras-baja.jpg` (18:25:46, después de la baja de
    las 18:24:26): en la sesión que seguía abierta, leer `Publico` dio
    **PERMITIDO**. Aunque la cuenta estaba deshabilitada, sin grupos y con
    la sesión SMB cerrada desde el servidor, la sesión existente siguió
    accediendo con sus vales Kerberos vigentes.
  - `t10-04-sesion-cache-sin-red.jpg`: en la sesión iniciada con caché,
    `klist` muestra 0 vales y leer `Publico` dio DENEGADO («No se encuentra
    la ruta de acceso…»). La sesión local no tiene acceso a la red.
- Conclusión: deshabilitar la cuenta corta las autenticaciones nuevas, pero
  no corta de inmediato una sesión abierta ni impide un inicio local con
  caché. Siguiente paso: evaluar cómo resolver la persistencia de la caché.
- Decisión: **no** se aplica la GPO `CachedLogonsCount=0`. Con valor 0,
  ningún usuario del dominio puede entrar a CL01 si DC01 no está disponible,
  y no es una práctica habitual en estaciones de trabajo. Además, el acceso
  a la red después de la baja vino de la sesión abierta, no de la caché. El
  script `T10-3-GPO-Cache.ps1` no se ejecutó.
- Me pareció que la sesión de `crodriguez` en CL01 se había cerrado sola;
  no registré la causa ni la hora. Un intento posterior de inicio de sesión
  como `EMPRESA\crodriguez` mostró «Su cuenta está deshabilitada. Póngase
  en contacto con el administrador del sistema.» y no permitió entrar.
  Captura en `evidencias/t10-05-inicio-rechazado.jpg`.
- El diagnóstico de confirmación se ejecutó desde una consola **sin
  elevación** y falló con `Get-VM`: «No dispone del permiso necesario». Esos
  intentos dejaron vacías las carpetas `helpdesk-t10-diagnostico-20261118-02`,
  `-03` y `-04`. No se usan como evidencia y no se borraron.
- Diagnóstico de confirmación `helpdesk-t10-diagnostico-20261118-05`,
  ejecutado con elevación (hash verificado):
  - 18:41:16: evento 4625 de `crodriguez` con **`LogonType=2`**
    (interactivo), estado `0xC000006E` y subestado `0xC0000072`. **No hay
    un 4624 tipo 11 después**: el inicio de sesión nuevo se rechazó y no
    recurrió a la caché.
  - El reingreso de las 18:27:33 fue distinto: un 4625 con `LogonType=7`
    (desbloqueo) seguido de un 4624 tipo 11. Hipótesis no verificada:
    Windows recurre a la caché en el desbloqueo de una sesión y no en un
    inicio de sesión nuevo.
  - **`quser` sigue mostrando la sesión de consola 1 de `crodriguez`
    activa desde las 18:27.** La sesión no se cerró sola: lo que se vio en
    pantalla fue un intento de inicio nuevo mientras esa sesión seguía
    cargada. Tampoco hubo un reinicio de CL01 después de las 18:27.
  - DC01: `lastLogon` sigue en 18:17:22 y no hay vales nuevos después de
    las 18:26:17.
- Pendiente: cerrar en CL01 la sesión residual de `crodriguez`, como parte
  del procedimiento de baja.
- Cierre remoto de la sesión residual (`helpdesk-t10-cierre-sesion-20261118-01`,
  hash verificado). Antes: sesión de consola 1 de `crodriguez`, `Activo`
  desde las 18:27. Se ejecutó `logoff 1` por PowerShell Direct. Después:
  `quser` devuelve «No existe un usuario para *». Evento 4647 en CL01 a las
  18:48:53.
- T10 cerrado. Ticket `tickets/t10-baja-empleado.md` redactado y
  procedimiento de baja actualizado en `docs/administracion.md`.

## 18/11/2026 — Reducción a ocho tickets de soporte

- T05 (`-ResultPageSize`) y T06 (falso crítico de canal seguro) eran fallos
  de los scripts del laboratorio, no incidentes de usuario. Su contenido se
  pasó a `scripts/README.md`, sección «Incidencias de desarrollo», y los
  archivos se quitaron de `tickets/`.
- Quedan ocho tickets: T01–T04 y T07–T10. Los números no se reasignaron
  porque esta bitácora cita T08, T09 y T10.

## 18/11/2026 — Reversión de la PSO de T08

- A las 18:58:45 se eliminó la PSO `PSO-Bloqueo-Helpdesk`
  (`helpdesk-t08-pso-borrado-20261118-01`, hash verificado). Antes:
  `mgomez` recibía la PSO, que aplicaba solo a esa cuenta y no estaba
  protegida contra borrado. Después: `mgomez` recibe la Default Domain
  Policy, no queda ninguna PSO y la cuenta sigue `Enabled=True` y
  `LockedOut=False`.
- El dominio vuelve a `LockoutThreshold=0`, el estado previo a T08.

## 18/11/2026 — T03: contraseña al volver del bloqueo

- Prueba manual en CL01. A las 19:04, sesión de `jperez` con el Bloc de
  notas abierto (`T03 - 19:04`). Sin interacción con la VM y sin Win+L. A
  las 19:12, al tocar una tecla, apareció `EMPRESA\jperez` con el campo
  Contraseña. Con la contraseña volvió a la misma sesión, con el Bloc de
  notas abierto.
- Capturas en `evidencias/t03-01-sesion-inicial.jpg`,
  `t03-02-pide-contrasena.jpg` y `t03-03-misma-sesion.jpg`. No hay una
  captura de la pantalla bloqueada antes de tocar la tecla.
- T03 cerrado sin pendientes.
