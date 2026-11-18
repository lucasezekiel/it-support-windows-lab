# Limitaciones conocidas

Este documento evita presentar el laboratorio como algo que no es.

## Licencias y vigencia

- Windows Server 2025 y Windows 11 Enterprise son **evaluaciones temporales**
  (180 y 90 días). No son licencias permanentes.
- Server requiere activación por Internet dentro de los 10 días posteriores a
  la instalación. Sin activación puede apagarse automáticamente.
- Windows 11 muestra marca de agua y puede apagarse cada hora si la evaluación
  vence o no se activa.
- Al vencer, detener el uso de esa evaluación y conservar la documentación.
  Cualquier continuidad requiere revisar los términos aplicables y contar
  con un derecho de uso válido; reinstalar o restaurar un checkpoint no
  concede automáticamente un nuevo período de evaluación.
- DC01 quedó activado hasta el **17/05/2027** según `/xpr`. La reversión de
  la red temporal no revierte esa activación. La hora mostrada por `/xpr`
  varió entre consultas; se conservan las salidas originales.
- CL01 (Enterprise Evaluation 26H2, build `26300`) quedó activado hasta el
  **16/02/2027** según `/xpr`. Antes de su primera activación mostraba modo
  de notificación, `0xC004F009`, gracia 0 y `EvaluationEndDate` de época.
  Hay reportes públicos de octubre de 2026 con ese mismo estado en
  instalaciones 26H2 sin intentos de activación. No se encontró
  documentación oficial que defina si el plazo de 90 días empieza en la
  instalación, el primer inicio o la activación; la fecha de época no se usa
  como vencimiento. La hora de `/xpr` varió entre consultas; se conservan
  las salidas originales.
- `0xC004E028` significa que ya había otra activación en curso. No prueba
  por sí solo que la clave sea inválida ni exige una compra.
- El informe `activacion-ejecucion-20261118-04` contiene
  `ActivationCompleted=false` porque el script evaluó el código de `/ato`
  antes que `LicenseStatus`. La licencia y la auditoría 07 demuestran la
  activación; la discrepancia se documenta y no se modificó el informe
  original.
- Los reportes de la comunidad sobre 26H2 se conservan solo como contexto;
  no sustituyen una confirmación de Microsoft ni una prueba en este equipo.
- La evaluación de CL01 vence el **16/02/2027**. Al vencer, `wlms.exe`
  puede volver a apagar el cliente con el mensaje de licencia expirada,
  como ocurrió el 18/11/2026 a las 14:58:41 antes de la activación. La
  ventana útil de pruebas depende de esa fecha.

## Infraestructura

- Un solo controlador de dominio: no se practica replicación ni recuperación
  de un DC adicional.
- Sin DHCP: las direcciones son estáticas, lo que simplifica el aislamiento
  pero no representa una red corporativa completa.
- La configuración base no tiene acceso a Internet: no hay actualizaciones
  ni resolución externa. Se abrió una ventana temporal y filtrada para
  activar DC01 y CL01; se cerró y ambas VM quedaron sin ruta por defecto.
- Sin servidor de archivos dedicado: el recurso compartido convive con DC01.
- Sin alta disponibilidad, clúster ni copias de seguridad del dominio.

## Identidades y seguridad

- Los cuatro usuarios comparten una contraseña inicial de laboratorio y deben
  cambiarla al primer inicio de sesión. Es una simplificación aceptable solo
  por tratarse de identidades ficticias en una red aislada.
- No se implementan MFA, certificados, LAPS ni cuentas de servicio.
- No se prueba escenario de múltiples sitios ni confianzas entre dominios.

## Método de prueba

- `Test-Path` acredita existencia observable, no permiso para listar o
  escribir. En este laboratorio devolvió `True` para Ventas mientras el
  listado y la escritura fueron denegados. No se atribuye una causa
  específica a ese resultado sin comprobar los derechos efectivos.
- La GPO aparece aplicada y sus tres valores están en el registro de
  `jperez`. El bloqueo efectivo por inactividad se comprobó el 18/11/2026
  (`screenlock-20261118-02`). La prueba no midió los 300 segundos exactos,
  porque no registró la última entrada del usuario. La exigencia de
  contraseña al volver todavía debe probarse manualmente.
- Las capturas deben revisarse antes de publicarse para excluir nombres de
  usuario reales, rutas personales y cualquier credencial.
- Los checkpoints de VM permiten volver atrás, pero no protegen contra fallas
  del disco físico ni reemplazan un respaldo del host.

## Scripts de diagnóstico

- Los dos scripts son de solo lectura y no reparan nada. Un resultado
  `Warning` requiere revisión humana; no equivale a un incidente confirmado.
- `Test-LabClientHealth.ps1` lee el bloqueo de pantalla del usuario que
  ejecuta la sesión. En la validación se ejecutó como
  `EMPRESA\Administrador`, que no tiene `ScreenSaveTimeOut` ni
  `ScreenSaverIsSecure`; por eso informa `Warning`. La GPO se verificó en la
  sesión de `jperez`; el bloqueo efectivo se comprobó con una prueba
  separada (`screenlock-20261118-02`), no con este script.
- En DC01, `Test-ComputerSecureChannel` no aplica y se informa
  `Applicable=false`. No es un fallo del dominio.
- Los eventos recientes pueden incluir errores históricos de activación,
  unión al dominio, TPM/BitLocker, DCOM y KDC. El script no distingue por sí
  solo entre un error histórico y uno activo.
- El inventario cuenta también objetos predeterminados de AD; por eso
  aparecen 7 usuarios y 54 grupos aunque el laboratorio tenga 4 usuarios y
  3 grupos propios. `-MaxItems` puede truncar secciones y un conteo igual al
  límite no debe interpretarse como total real.
- Los grupos `Domain Admins` y `Enterprise Admins` se localizan por SID para
  no depender de los nombres localizados de Windows.
- Versiones validadas el 18/11/2026: inventario 1.0.1 y diagnóstico 1.0.2.
  Evidencia en `C:\LAB\Evidencias\scripts-20261118-04`, con hashes
  `9B036F06...FADAD5` y `BC4FB8F8...C440B1`.

## Fuera de alcance

- Microsoft 365, Entra ID, Intune y cualquier servicio cloud.
- Publicación de puertos, cambios en el router o exposición a Internet.
- Unión del equipo físico al dominio del laboratorio.
