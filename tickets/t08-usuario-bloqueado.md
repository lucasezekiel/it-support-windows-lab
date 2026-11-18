# T08 — mgomez no puede iniciar sesión: cuenta bloqueada

| Campo | Valor |
|---|---|
| Fecha | 18/11/2026 |
| Equipo | CL01 / DC01 |
| Usuario | `EMPRESA\mgomez` |
| Categoría | Cuentas / bloqueo y restablecimiento de contraseña |
| Prioridad | Alta |
| Estado | Cerrado |

## Síntoma

`mgomez` informa que no puede entrar a CL01. Después de varios intentos,
Windows muestra «Credenciales no válidas, retrasando el siguiente intento…»
y deja de aceptar la contraseña.

## Impacto y prioridad

Una usuaria no puede trabajar hasta que se resuelva y no hay alternativa:
prioridad **Alta**. Afecta a una sola cuenta, sin indicios de un problema
general del dominio.

## Hipótesis

1. La cuenta está bloqueada por intentos fallidos. Se confirmó.
2. La contraseña venció o debe cambiarse. También aplica: `mgomez` tenía
   pendiente el cambio de contraseña inicial.
3. La cuenta está deshabilitada. Se descartó: `Enabled=True`.
4. Hay un problema de red o DNS en CL01. Se descartó: el DC registró los
   intentos fallidos, así que la autenticación llegaba al controlador.

## Preparación del laboratorio

El dominio no bloqueaba cuentas (`LockoutThreshold=0` en la política por
defecto). Para reproducir el caso sin afectar a otras cuentas se creó la
PSO `PSO-Bloqueo-Helpdesk`, aplicada solo a `mgomez`, con 5 intentos y
bloqueo de 15 minutos. El resto de los valores son iguales a los de la
política por defecto. Antes se crearon checkpoints de DC01 y CL01.

## Diagnóstico

Consulta de solo lectura en DC01 a las 17:46:

- `LockedOut=True`, `BadLogonCount=5`.
- `LockoutTime` y `LastBadPasswordAttempt`: 17:46:05.
- Evento **4740** «Se bloqueó una cuenta de usuario» a las 17:46:05.
- `Get-ADUserResultantPasswordPolicy mgomez` devuelve la PSO con umbral 5.

## Acción

1. Verificar la identidad de la usuaria antes de actuar. En el caso simulado
   se dio por hecha; en un caso real se haría por un canal acordado.
2. En DC01, a las 17:49:10:

   ```powershell
   Unlock-ADAccount -Identity mgomez
   $pw = Read-Host -AsSecureString 'Nueva contraseña temporal'
   Set-ADAccountPassword -Identity mgomez -Reset -NewPassword $pw
   Set-ADUser -Identity mgomez -ChangePasswordAtLogon $true
   ```

3. Comunicar la contraseña temporal por un canal distinto del ticket. No se
   registra en ningún documento.

## Verificación

- DC01, después del cambio: `LockedOut=False`, `BadLogonCount=0` y cambio
  de contraseña obligatorio en el próximo inicio.
- Eventos en DC01 a las 17:49:10: **4767** (desbloqueo), **4724**
  (restablecimiento) y **4738** (cambio de la cuenta).
- CL01: al iniciar sesión con la contraseña temporal, Windows exigió
  cambiarla. Después del cambio mostró «Se cambió su contraseña» y comenzó
  el primer inicio de sesión («Preparando todo para ti»).

## Evidencia

- `C:\LAB\Evidencias\helpdesk-relevamiento-20261118-01`: política sin
  bloqueo.
- `C:\LAB\Evidencias\helpdesk-t08-pso-20261118-01`: creación de la PSO.
- `C:\LAB\Evidencias\helpdesk-t08-bloqueo-20261118-01`: bloqueo y evento
  4740.
- `C:\LAB\Evidencias\helpdesk-t08-desbloqueo-20261118-01`: desbloqueo,
  restablecimiento y eventos 4767, 4724 y 4738.
- Capturas de CL01 en `evidencias/`: `t08-01-cambio-obligatorio.jpg`,
  `t08-02-nueva-contrasena.jpg`, `t08-03-contrasena-cambiada.jpg` y
  `t08-04-primer-inicio.jpg`.

## Respuesta al usuario

«María, tu cuenta se había bloqueado por varios intentos con una contraseña
incorrecta. Ya la desbloqueamos y te asignamos una contraseña temporal, que
te pasamos por otro medio. Al entrar, Windows te va a pedir que elijas una
nueva: usá una que no hayas usado antes y no la compartas. Si se vuelve a
bloquear sin que te hayas equivocado, avisanos enseguida.»

## Criterio de escalamiento

- Escalar a seguridad si la cuenta se bloquea de forma repetida sin que la
  usuaria haya fallado, porque puede ser un ataque o credenciales viejas
  guardadas en otro equipo. Hay que revisar el equipo de origen del evento
  4740.
- Escalar si fallan varias cuentas a la vez o si el desbloqueo no se refleja
  en el DC.
- No se desbloquea ni se restablece la contraseña sin verificar la
  identidad.

## Cierre y límites

El bloqueo, el desbloqueo, el restablecimiento y el cambio obligatorio
están verificados.

Límites:
- La verificación de identidad fue simulada.
- No se registraron los eventos 4625/4771 de los intentos fallidos, y el
  script no extrajo el equipo de origen del evento 4740.
- No se capturó el mensaje «cuenta bloqueada» en CL01; el bloqueo se
  acredita con el estado en DC01 y el evento 4740.
- La PSO se eliminó al terminar las prácticas, el 18/11/2026 a las 18:58:45
  (`C:\LAB\Evidencias\helpdesk-t08-pso-borrado-20261118-01`). `mgomez`
  volvió a la Default Domain Policy, así que el dominio otra vez no bloquea
  cuentas. Para repetir la práctica hay que volver a crear la PSO.
- La captura `t08-04-primer-inicio.jpg` muestra el inicio de la creación del
  perfil, no el escritorio ni `whoami`.
