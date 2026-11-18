# T09 — Alta de empleada: Lucía Fernández (Ventas)

| Campo | Valor |
|---|---|
| Fecha | 18/11/2026 |
| Equipo | DC01 / CL01 |
| Usuario | `EMPRESA\lfernandez` (nueva) |
| Categoría | Cuentas / alta de usuario |
| Prioridad | Media |
| Estado | Cerrado |

## Síntoma

Pedido simulado de RR. HH.: Lucía Fernández ingresa al área de Ventas y
necesita una cuenta de dominio y acceso a los recursos de su área.

## Impacto y prioridad

Sin la cuenta, la empleada no puede empezar a trabajar. Es un pedido
planificado, no una interrupción del servicio: prioridad **Media**.

## Hipótesis

Es un pedido, no una falla. Antes de actuar se comprobó:

1. Que no existiera otra cuenta `lfernandez`. El script lo verifica y se
   detiene si existe.
2. Que `GG_Ventas` alcanzara para el puesto. Ese grupo concede modificación
   en `Ventas`; `Publico` es lectura para todos los usuarios del dominio. No
   se pidieron otros accesos.

## Diagnóstico

- OU de destino: `OU=Ventas,OU=Usuarios,OU=EMPRESA`.
- La política efectiva para una cuenta nueva es la Default Domain Policy.
  La PSO de T08 aplica solo a `mgomez`.

## Acción

En DC01, a las 18:01:02:

```powershell
$pw = Read-Host -AsSecureString 'Contraseña inicial'
New-ADUser -Name 'Lucia Fernandez' -GivenName 'Lucia' -Surname 'Fernandez' `
    -SamAccountName lfernandez -UserPrincipalName 'lfernandez@ad.empresa.test' `
    -Path 'OU=Ventas,OU=Usuarios,OU=EMPRESA,DC=ad,DC=empresa,DC=test' `
    -Department 'Ventas' -Description 'Alta T09 18/11/2026' `
    -AccountPassword $pw -Enabled $true -ChangePasswordAtLogon $true
Add-ADGroupMember -Identity GG_Ventas -Members lfernandez
```

La contraseña inicial se escribe solo en el prompt y no se registra.

## Verificación

- DC01: la cuenta está habilitada, en `OU=Ventas` y en `GG_Ventas`, con
  cambio de contraseña obligatorio y la Default Domain Policy. Eventos 4720,
  4722, 4724 y 4738.
- CL01: el primer inicio de sesión exigió cambiar la contraseña.
- CL01, sesión de `lfernandez` a las 18:10:24:

| Prueba | Resultado |
|---|---|
| `whoami` | `empresa\lfernandez` |
| Leer `Publico` | Permitido |
| Crear un archivo en `Ventas` | Permitido |
| Borrar ese archivo en `Ventas` | Permitido |
| Listar `Administracion` | Denegado: «Acceso denegado» |

## Evidencia

- `C:\LAB\Evidencias\helpdesk-t09-alta-20261118-01`: estado de la cuenta,
  política efectiva, miembros de `GG_Ventas` y eventos. Hash verificado.
- `evidencias/t09-01-cambio-obligatorio.jpg`: cambio de contraseña en el
  primer inicio.
- `evidencias/t09-02-prueba-accesos.jpg`: prueba de accesos con el bloque
  corregido.

## Respuesta al usuario

Mensaje para quien pidió el alta, con copia a la empleada:

«Ya está creada la cuenta de Lucía Fernández (`lfernandez`), con acceso a la
carpeta de Ventas y a Público. La contraseña inicial se la pasamos por otro
medio; al entrar por primera vez, Windows le va a pedir que elija una nueva.
Si necesita acceso a otra carpeta, el pedido tiene que venir aprobado por su
responsable.»

## Criterio de escalamiento

- Un alta sin un pedido formal de RR. HH. o del responsable del área no se
  hace: se devuelve el pedido.
- Los accesos fuera del grupo de su área, o los grupos privilegiados,
  requieren la aprobación del responsable de los datos o de seguridad.
- Escalar a la administración de AD si la cuenta no replica o no puede
  iniciar sesión pese a estar habilitada y en el grupo correcto.

## Cierre y límites

El alta, el cambio obligatorio y los accesos están verificados.

Límites:
- El pedido de RR. HH. y la entrega de la contraseña fueron simulados.
- No se registró el evento 4728 (alta en un grupo global): la auditoría de
  administración de grupos de seguridad probablemente no está habilitada,
  aunque no se comprobó. La pertenencia consta en AD y en el token
  (`whoami /groups`).
- La primera prueba de accesos usó un bloque que informaba mal la
  denegación. El error de acceso se vio en pantalla igual, y la prueba se
  repitió con el bloque corregido (ver `docs/bitacora.md`).
