# Activación temporal de las evaluaciones

## Estado al iniciar el 18/11/2026

- Procedimiento autorizado por el propietario; activación pendiente tras
  detener el primer intento y revertir la salida temporal.
- DC01: `Windows(R), ServerStandardEval edition`. La consulta `/xpr`
  informó: «El período de gracia inicial finaliza el 26/11/2026 16:45:00».
- CL01: `Windows(R), EnterpriseEval edition`, build `26300`. La consulta
  `/xpr` informó: «Windows está en modo de notificación».
- La cuenta administrativa del dominio se llama `EMPRESA\Administrador`.
- Los informes originales de esta etapa se conservan localmente en
  `C:\LAB\Evidencias\activacion-*`, sujetos a revisión antes de publicar.

> **Estado al 18/11/2026, tras el intento 04:** DC01 está activado hasta
> el 17/05/2027 y CL01 hasta el 16/02/2027. La red volvió al aislamiento,
> sin residuos DNS, y ambas VM conservan una sola interfaz en `LAB-AD`.

## Primer intento: detenido y revertido

Informe: `activacion-ejecucion-20261118-01` (18/11/2026).

- Se aplicaron los filtros antes de conectar DC01.
- La interfaz temporal tenía el registro DNS desactivado. La comprobación
  detectó un registro A con la IP temporal y detuvo el procedimiento
  **antes de ejecutar `/ato`**.
- Ese intento no guardó el nombre ni la IP del registro detectado; tampoco
  demuestra qué servicio lo publicó.
- La limpieza terminó sin errores informados. Las dos VM quedaron con
  una interfaz en `LAB-AD`, cero rutas IPv4 por defecto y los tres perfiles
  del firewall activos. `dc01.ad.empresa.test` resolvió solo a `10.10.10.10`.
- Se informó la restauración del reenviador y la retirada de la regla
  temporal de DC01. La lista de registros eliminados estaba vacía; no se
  atribuye al script una eliminación que el informe no demuestra.

La guía Microsoft KB 2023004 indica que, en un DC con varias interfaces,
desactivar el registro del cliente DNS no controla todas las fuentes:
el servicio DNS también puede publicar sus direcciones de escucha y
Netlogon registra datos del dominio. Falta acotar las interfaces de escucha
y revisar los servidores de nombres de las zonas.

## Corrección preparada para el siguiente intento

Todavía no acredita una activación ni una publicación DNS corregida.

- Antes de modificar, guardar los valores y la existencia de
  `ListenAddresses` y `PublishAddresses`, los reenviadores y los registros
  A/NS de las zonas integradas en AD.
- Limitar temporalmente la escucha a `10.10.10.10` con
  `dnscmd /resetlistenaddresses`. Publicar únicamente `10.10.10.10`.
  No se incluye loopback como dirección de escucha porque `dnscmd` lo
  rechazó con el error 9552; la resolución mediante `127.0.0.1` se probará
  igualmente antes de conectar y cualquier fallo obligará a revertir.
- Reiniciar solamente el servicio DNS para aplicar `PublishAddresses`.
  Esto puede producir una breve interrupción de resolución; no reinicia
  DC01 ni cambia la configuración del dominio.
- Probar resolución mediante loopback y la IP del laboratorio antes de
  conectar. No cambiar Netlogon sin una evidencia nueva que lo justifique.
- Registrar zona, nombre e IP si aparece un registro temporal. Revisar
  nuevamente después de `/ato`.
- Al limpiar, restaurar los valores originales, reiniciar DNS y verificar
  los valores reales, la ausencia de registros temporales y la topología.

Una auditoría adicional (`activacion-auditoria-20261118-05`) no llegó a
iniciarse porque Windows rechazó la credencial; no produjo cambios.

La comprobación `activacion-preflight-20261118-01` terminó con código 0,
sin crear adaptadores ni modificar servicios. Confirmó la topología aislada,
la ausencia original de `ListenAddresses`, `PublishAddresses` y reenviadores,
y registros A exclusivamente con las direcciones del laboratorio. Esto valida
la copia previa y la lectura del estado, no todavía la corrección multihomed.

### Segundo intento: comando de escucha rechazado

Informe: `activacion-ejecucion-20261118-02`.

- `dnscmd` rechazó la lista que incluía `127.0.0.1` con
  `DNS_ERROR_INVALID_IP_ADDRESS` (9552). Se detuvo antes de conectar y
  antes de `/ato`; no se solicitó activación.
- La reversión ejecutó `dnscmd /resetlistenaddresses` sin direcciones y
  el comando informó éxito. La verificación final mostró los mismos valores
  que la copia inicial: `ListenAddresses` y `PublishAddresses` ausentes,
  sin reenviadores, con las mismas direcciones de escucha observadas y
  DNS/NTDS/Netlogon en ejecución.
- Un valor inexistente produjo un error en la comprobación de reversión.
  Se corrigió el manejo de ese valor nulo; el código 2 de este intento no
  debe interpretarse como una diferencia DNS residual, pues el informe
  posterior demuestra que los valores coinciden con la línea de base.
- Ambas VM terminaron con una interfaz en `LAB-AD`, sin ruta por defecto,
  firewall activo y `dc01.ad.empresa.test` resolviendo solo a `10.10.10.10`.

### Tercer intento: DC01 activado, CL01 detenido por error de activación

Informe: `activacion-ejecucion-20261118-03`.

**DC01**

- La restricción DNS se aplicó antes de conectar: escucha únicamente en
  `10.10.10.10` y publicación únicamente de esa dirección. Las consultas
  por `127.0.0.1` y `10.10.10.10` resolvieron `dc01.ad.empresa.test` a
  `10.10.10.10`.
- No se detectaron registros A con la IP temporal antes ni después de
  `/ato`.
- `/ato` informó «El producto se activó correctamente».
- El producto `Windows(R), ServerStandardEval edition` quedó con
  `LicenseStatus=1` y `GracePeriodRemaining=259200` minutos (180 días).
- `/xpr` informó vencimiento el **17/05/2027**. La hora mostrada varió
  entre consultas (14:47:25 y 14:48:18); se conservan las salidas originales.
- La reversión de red no deshace esta activación.

**CL01**

- `/ato` devolvió `0xC004E028`. La salida de `/xpr` siguió siendo
  «Windows está en modo de notificación».
- El producto `Windows(R), EnterpriseEval edition` quedó con
  `LicenseStatus=5`, `LicenseStatusReason=0xC004F009` y
  `GracePeriodRemaining=0`; `EvaluationEndDate` es un valor de época y no
  permite establecer el vencimiento real.
- Microsoft documenta `0xC004E028` como otra activación ya en curso. No
  demuestra por sí solo una clave inválida ni exige una compra.
- No se reintentó `/ato` en la misma ejecución.

**Red y DNS**

- Ambas VM volvieron a una única interfaz en `LAB-AD`, sin ruta por
  defecto y con el firewall activo.
- La limpieza de DC01 no retiró `PublishAddresses` porque comprobó su
  existencia con `Get-Item`; el valor residual `10.10.10.10` fue
  confirmado por la auditoría independiente `activacion-auditoria-20261118-06`.
- La reparación `activacion-reparacion-dns-20261118-01` eliminó solo ese
  valor, reinició DNS y verificó: `ListenAddresses` ausente,
  `PublishAddresses` ausente, sin reenviadores, DNS/NTDS/Netlogon activos,
  resolución por loopback y por `10.10.10.10`, y cero rutas por defecto.
- El registro `CL01 -> 10.10.10.20` de la zona `ad.empresa.test` existe en
  la auditoría 06. Una captura inmediatamente posterior al reinicio de DNS
  no lo mostró; se trató de una lectura transitoria, no de una eliminación
  demostrada. No se editó manualmente.

La corrección de escucha y publicación DNS quedó validada en este intento:
la IP temporal no se publicó y la resolución local siguió funcionando. El
defecto de la limpieza fue de verificación, no de la restricción aplicada.

### Diagnóstico del apagado de CL01

Informe: `activacion-diagnostico-cl01-20261118-02`. Evento del host:
`activacion-apagado-cl01-20261118-01`.

- A las **14:58:41**, `C:\WINDOWS\system32\wlms\wlms.exe`, ejecutado como
  `NT AUTHORITY\SYSTEM`, inició un apagado planificado del invitado con el
  comentario: «El período de licencia de esta instalación de Windows ha
  expirado. El sistema operativo se está apagando.» Hyper-V registró el
  cierre del sistema operativo invitado a las **14:58:43**.
- El estado de licencia no cambió: `LicenseStatus=5`,
  `LicenseStatusReason=0xC004F009` y `GracePeriodRemaining=0`.
- Los eventos de Security-SPP muestran que la activación automática de
  CL01 falló con `0x80072EE7` (resolución de nombres) al activarse la red
  durante el intento 03. El `/ato` manual devolvió `0xC004E028` porque esa
  activación automática seguía en curso. No hubo un rechazo de licencia.
- Tras el reinicio, sin Internet, los intentos automáticos volvieron a
  fallar por resolución de nombres (`0x80072EE7`) y estado inválido
  (`0x8007139F`). Son coherentes con la ausencia de salida, no con una
  clave rechazada.
- El apagado por `wlms.exe` impedía tratar a CL01 como un cliente estable
  mientras siguiera sin activar. Ese estado quedó resuelto con la
  activación del intento 04. No se modificó la licencia ni se ejecutó
  `rearm`.

### Cuarto intento: CL01 activado

Informe: `activacion-ejecucion-20261118-04`. Auditoría final:
`activacion-auditoria-20261118-07`.

- La ejecución se limitó a CL01; DC01 se consultó en modo de solo lectura y
  no recibió otra solicitud de activación.
- La interfaz temporal obtuvo `172.26.213.221`, con registro DNS desactivado.
  No se detectaron registros A temporales, la LAN doméstica no fue alcanzable
  y `activation.sls.microsoft.com` y `activation-v2.sls.microsoft.com`
  resolvieron a `48.192.1.65`.
- La espera de 60 segundos mantuvo `LicenseStatus=5`, gracia 0 y las razones
  `0xC004F009` y `0xC004F200`. Los eventos de Security-SPP registraron
  actividad de activación a las **15:09:01–15:09:02**.
- El `/ato` de las **15:09:03** devolvió otra vez `0xC004E028` (otra
  activación ya en curso), pero el producto quedó con `LicenseStatus=1`,
  razón `0x4004FC04` y `GracePeriodRemaining=129600` minutos (90 días).
  `/xpr` informó vencimiento el **16/02/2027 15:09:03**.
- El script marcó la ejecución como fallida porque evaluó el código de salida
  de `/ato` antes que `LicenseStatus`. Por eso `result.json` dice
  `ActivationCompleted=false`, aunque el mismo informe y la auditoría 07
  demuestran la licencia activa. No se repitió `/ato`; el código de error se
  conserva como evidencia de la colisión.
- La limpieza no informó errores: se retiraron la regla de firewall y el
  adaptador temporal, no quedaron registros A temporales y ambas VM volvieron
  a una sola interfaz en `LAB-AD`.
- La auditoría 07 confirmó que CL01 conserva `10.10.10.20/24`, DNS
  `10.10.10.10`, cero rutas por defecto y los tres perfiles de firewall
  activos. `dc01.ad.empresa.test` resuelve a `10.10.10.10`.
- La misma auditoría confirmó que DC01 sigue activado hasta el
  **17/05/2027**, sin `ListenAddresses` ni `PublishAddresses`, sin
  reenviadores, con DNS/NTDS/Netlogon en ejecución y el registro
  `CL01 -> 10.10.10.20` en la zona `ad.empresa.test`.
- `/xpr` mostró 15:09:03, 15:09:06 y 15:09:09 en consultas sucesivas; la
  fecha permaneció en 16/02/2027. Se conservan las salidas originales.
- A las **15:14:31**, más de cinco minutos después de la activación, CL01
  seguía encendida y no se había registrado otro apagado por licencia.

Con esto, ambas evaluaciones quedaron activadas dentro de su período. La
ventana de Internet se cerró y no reemplaza la obligación de detener el uso
al vencer cada evaluación.

## Objetivo y criterios de éxito

1. Activar cada evaluación con el servicio oficial de Microsoft.
2. Registrar `/xpr` y el estado de licencia, sin claves de producto.
3. Mantener resolución del dominio y acceso por `LAB-AD`.
4. Comprobar el bloqueo de un servicio de la LAN que sea accesible desde
   el host, junto con las reglas efectivas del adaptador temporal.
5. Al finalizar, cada VM debe tener únicamente su adaptador en `LAB-AD`,
   sin ruta por defecto, con sus ajustes DNS originales restaurados.

Un mensaje de activación solicitado, una marca de agua o conectividad
HTTP por sí solos no prueban que la licencia esté activada.

## Diseño autorizado

Se conserva el switch privado `LAB-AD`. La salida usa adaptadores
temporales en `Default Switch`; el NAT por sí solo no bloquea la LAN.

Antes de conectar cada adaptador:

- Aplicar ACL de Hyper-V únicamente a ese adaptador.
- Denegar tráfico no permitido, incluido IPv6 por ese adaptador.
- Bloquear los rangos privados y locales; permitir al gateway del switch
  únicamente los servicios DNS y DHCP necesarios.
- Permitir salida IPv4 TCP 80/443 y sus respuestas con seguimiento de
  conexiones. Es una ventana de salida web, no una lista de dominios
  Microsoft exclusivamente.
- Desactivar el registro DNS de la nueva interfaz, asignar métrica alta y
  conservar los DNS del dominio.
- Agregar una regla de firewall del invitado, acotada a esa interfaz,
  contra la LAN doméstica.

DC01 utilizará un reenviador temporal hacia el proxy DNS del switch.
Sus valores anteriores se guardan antes de cambiarlos. El registro DNS de
un controlador con dos interfaces exige verificar los registros A además
de desactivar el registro del cliente DNS.

## Administración y reversión

Se utiliza PowerShell Direct con credenciales ingresadas localmente.
No se guardan las contraseñas ni se habilita administración por la LAN.

La limpieza se ejecuta también ante un error:

1. Desconectar los adaptadores temporales.
2. Restaurar los reenviadores anteriores.
3. Retirar únicamente registros A que correspondan a la IP temporal
   obtenida durante esta ejecución, si llegaron a crearse.
4. Retirar las reglas de firewall creadas por esta ejecución y sus
   adaptadores temporales.
5. Verificar las interfaces restantes, rutas, DNS y estado de licencia.

La reversión de red no deshace una activación válida. Si la activación
falla, se conserva el error y se diagnostica antes de reintentar.

## Fuentes oficiales

Consultadas el 18/11/2026:

- [Windows Server 2025 Evaluation](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025):
  180 días y activación por Internet durante los primeros diez días.
- [Windows 11 Enterprise Evaluation](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise):
  90 días, sin clave de producto requerida.
- [PowerShell Direct](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell-direct).
- [ACL extendidas de Hyper-V](https://learn.microsoft.com/en-us/powershell/module/hyper-v/add-vmnetworkadapterextendedacl).
- [KB 2023004: evitar registros de NIC no deseadas en un DC](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/unwanted-nic-registered-dns-mulithomed-dc).
- [KB 246804: componentes que realizan registros DNS dinámicos](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/enable-disable-dns-dynamic-registration).
- [`dnscmd /resetlistenaddresses`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/dnscmd#dnscmd-resetlistenaddresses-command).

### Consultas de la comunidad (contexto, no normativas)

- [Windows 11 Enterprise Evaluation 26H2 — Is offline activation supported?](https://techcommunity.microsoft.com/discussions/windows11/windows-11-enterprise-evaluation-26h2-%E2%80%94-is-offline-activation-supported/4566227)
  (20/10/2026): una VM 26H2 instalada sin red muestra el mismo estado
  `Notification`, `0xC004F009` y gracia 0 antes de cualquier intento.
- [Windows 11 Enterprise Evaluation 26H2 — Hyper-V VM setup, activation and license requirements](https://learn.microsoft.com/en-us/answers/questions/6055528/indows-11-enterprise-evaluation-26h2-hyper-v-vm-se)
  (30/10/2026): respuesta generada por IA; indica que la activación en
  línea es el camino documentado y que no está definido el inicio exacto
  del plazo. No se usa como garantía.

Estos reportes explican por qué no se interpretó el estado inicial como un
vencimiento consumado. La activación posterior del intento 04 confirmó que
la evaluación seguía siendo activable; los reportes no se usan como prueba
de ese resultado.

Los períodos nominales no sustituyen el vencimiento que informa cada
instalación. Conservar evidencias antes de ese vencimiento.
