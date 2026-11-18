<#
.SYNOPSIS
Ejecuta un diagnostico acotado y de solo lectura de un cliente del laboratorio.

.DESCRIPTION
Comprueba identidad, pertenencia al dominio, canal seguro, descubrimiento del
controlador, configuracion y resolucion DNS, conectividad TCP, rutas, acceso
SMB, politicas de grupo, servicios, hora, licencia y errores recientes.
No repara nada, no cambia configuracion y no solicita credenciales. Esta
pensado para ejecutarse dentro de CL01 o DC01.

.PARAMETER OutputDirectory
Carpeta donde se guardan el JSON y el resumen de texto.

.PARAMETER DomainName
Dominio esperado. Por defecto usa USERDNSDOMAIN y, si no existe, ad.empresa.test.

.PARAMETER ExpectedDnsServer
Servidor DNS que se espera encontrar en el cliente. Si se omite, solo se informa.

.PARAMETER ExpectedDomainControllerIp
IP esperada del controlador. Si se omite, se usa la que descubre el cliente.

.PARAMETER TcpTimeoutMs
Tiempo maximo por prueba TCP, en milisegundos.

.PARAMETER MaxEvents
Cantidad maxima de eventos de error recientes por registro.

.EXAMPLE
.\Test-LabClientHealth.ps1 -ExpectedDnsServer 10.10.10.10 -ExpectedDomainControllerIp 10.10.10.10

.NOTES
Version 1.0.0. Solo lectura. Codigos de salida: 0 sano, 1 advertencias, 2 critico.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = (Join-Path $env:ProgramData 'ITSupportLab\Health'),

    [ValidateNotNullOrEmpty()]
    [string]$DomainName = $(if ($env:USERDNSDOMAIN) { $env:USERDNSDOMAIN } else { 'ad.empresa.test' }),

    [string]$ExpectedDnsServer,

    [string]$ExpectedDomainControllerIp,

    [ValidateRange(500, 10000)]
    [int]$TcpTimeoutMs = 2000,

    [ValidateRange(1, 100)]
    [int]$MaxEvents = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '1.0.2'
$started = Get-Date
$checks = [Collections.Generic.List[object]]::new()
$criticalChecks = [Collections.Generic.List[string]]::new()
$warningChecks = [Collections.Generic.List[string]]::new()

function New-DirectoryIfMissing {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('Ok', 'Warning', 'Critical')][string]$Status,
        $Details = $null,
        [string]$ErrorText = $null
    )

    $checks.Add([pscustomobject]@{
        Name = $Name
        Status = $Status
        Details = $Details
        Error = $ErrorText
    })

    if ($Status -eq 'Critical') {
        $criticalChecks.Add($Name)
    }
    elseif ($Status -eq 'Warning') {
        $warningChecks.Add($Name)
    }
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$Address,
        [Parameter(Mandatory = $true)][int]$Port,
        [Parameter(Mandatory = $true)][int]$TimeoutMs
    )

    $client = [Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($Address, $Port)
        if (-not $task.Wait($TimeoutMs)) {
            return $false
        }
        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Limit-Text {
    param(
        [string]$Text,
        [int]$Length = 300
    )

    if ($null -eq $Text) {
        return $null
    }
    if ($Text.Length -le $Length) {
        return $Text
    }
    return $Text.Substring(0, $Length) + '...'
}

function Invoke-DnsCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('A', 'SRV')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Label,
        [ValidateSet('Warning', 'Critical')][string]$Severity = 'Critical'
    )

    try {
        $answers = @(Resolve-DnsName -Name $Name -Type $Type -DnsOnly -ErrorAction Stop)
        $records = @(
            $answers |
                Where-Object { $_.Type -eq $Type } |
                ForEach-Object {
                    if ($Type -eq 'A') {
                        [pscustomobject]@{
                            Type = 'A'
                            Name = $_.Name
                            IPAddress = $_.IPAddress
                        }
                    }
                    else {
                        [pscustomobject]@{
                            Type = 'SRV'
                            Name = $_.Name
                            Target = $_.NameTarget
                            Port = $_.Port
                            Priority = $_.Priority
                            Weight = $_.Weight
                        }
                    }
                }
        )

        if (@($records).Count -eq 0) {
            Add-Check -Name $Label -Status $Severity -ErrorText 'La consulta no devolvio registros.'
            return $null
        }

        Add-Check -Name $Label -Status 'Ok' -Details $records
        return $records
    }
    catch {
        Add-Check -Name $Label -Status $Severity -ErrorText $_.Exception.Message
        return $null
    }
}

New-DirectoryIfMissing -Path $OutputDirectory

$identity = $null
$isDomainController = $false
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption, Version, BuildNumber, InstallDate, LastBootUpTime, LocalDateTime
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -Property Name, Domain, PartOfDomain, DomainRole
    $timeZone = Get-TimeZone
    $isDomainController = $computer.DomainRole -in @(4, 5)
    $identity = [pscustomobject]@{
        ComputerName = $computer.Name
        Domain = $computer.Domain
        PartOfDomain = $computer.PartOfDomain
        DomainRole = $computer.DomainRole
        IsDomainController = $isDomainController
        User = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        OperatingSystem = $os.Caption
        Version = $os.Version
        BuildNumber = $os.BuildNumber
        InstallDate = $os.InstallDate
        LastBootUpTime = $os.LastBootUpTime
        LocalDateTime = $os.LocalDateTime
        TimeZone = $timeZone.Id
    }
    if ($computer.PartOfDomain) {
        Add-Check -Name 'Identidad y dominio' -Status 'Ok' -Details $identity
    }
    else {
        Add-Check -Name 'Identidad y dominio' -Status 'Critical' -Details $identity -ErrorText 'El equipo no esta unido a un dominio.'
    }
}
catch {
    Add-Check -Name 'Identidad y dominio' -Status 'Critical' -ErrorText $_.Exception.Message
}

if ($isDomainController) {
    Add-Check -Name 'Canal seguro' -Status 'Ok' -Details ([pscustomobject]@{
        Applicable = $false
        Reason = 'El equipo es un controlador de dominio; Test-ComputerSecureChannel no aplica.'
    })
}
else {
    try {
        $secureChannel = Test-ComputerSecureChannel -ErrorAction Stop
        if ($secureChannel) {
            Add-Check -Name 'Canal seguro' -Status 'Ok' -Details ([pscustomobject]@{ SecureChannel = $true })
        }
        else {
            Add-Check -Name 'Canal seguro' -Status 'Critical' -Details ([pscustomobject]@{ SecureChannel = $false }) -ErrorText 'Test-ComputerSecureChannel devolvio False.'
        }
    }
    catch {
        Add-Check -Name 'Canal seguro' -Status 'Critical' -ErrorText $_.Exception.Message
    }
}

$dcHost = $null
$dcIp = $null
try {
    $adDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    $dc = $adDomain.FindDomainController()
    $dcHost = $dc.Name.TrimStart('\')
    $dcIp = $dc.IPAddress
    Add-Check -Name 'Descubrimiento de DC' -Status 'Ok' -Details ([pscustomobject]@{
        Domain = $adDomain.Name
        DomainController = $dcHost
        IpAddress = $dcIp
        Site = $dc.SiteName
    })
}
catch {
    Add-Check -Name 'Descubrimiento de DC' -Status 'Critical' -ErrorText $_.Exception.Message
}

if (-not $dcHost) {
    $dcHost = "dc01.$DomainName"
}

$targetIp = $ExpectedDomainControllerIp
if (-not $targetIp) {
    $targetIp = $dcIp
}
if (-not $targetIp) {
    try {
        $targetIp = @(
            Resolve-DnsName -Name $dcHost -Type A -DnsOnly -ErrorAction Stop |
                Where-Object { $_.Type -eq 'A' } |
                Select-Object -ExpandProperty IPAddress
        ) | Select-Object -First 1
    }
    catch {
        $targetIp = $null
    }
}

try {
    $dnsClients = @(
        Get-DnsClientServerAddress -AddressFamily IPv4 |
            Where-Object { @($_.ServerAddresses).Count -gt 0 } |
            ForEach-Object {
                [pscustomobject]@{
                    InterfaceAlias = $_.InterfaceAlias
                    ServerAddresses = @($_.ServerAddresses)
                }
            }
    )
    $dnsServers = @($dnsClients | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique)
    $dnsDetails = [pscustomobject]@{
        Clients = $dnsClients
        UniqueServers = $dnsServers
    }
    if ($ExpectedDnsServer) {
        if ($dnsServers -contains $ExpectedDnsServer) {
            Add-Check -Name 'Configuracion DNS del cliente' -Status 'Ok' -Details $dnsDetails
        }
        else {
            Add-Check -Name 'Configuracion DNS del cliente' -Status 'Critical' -Details $dnsDetails -ErrorText "No se encontro el DNS esperado $ExpectedDnsServer."
        }
    }
    else {
        Add-Check -Name 'Configuracion DNS del cliente' -Status 'Ok' -Details $dnsDetails
    }
}
catch {
    Add-Check -Name 'Configuracion DNS del cliente' -Status 'Warning' -ErrorText $_.Exception.Message
}

Invoke-DnsCheck -Name $dcHost -Type 'A' -Label "Resolucion A de $dcHost" -Severity 'Critical' | Out-Null
Invoke-DnsCheck -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type 'SRV' -Label 'Resolucion SRV de LDAP del dominio' -Severity 'Critical' | Out-Null
Invoke-DnsCheck -Name $DomainName -Type 'A' -Label "Resolucion A de $DomainName" -Severity 'Critical' | Out-Null

try {
    $external = @(
        Resolve-DnsName -Name 'www.microsoft.com' -Type A -DnsOnly -ErrorAction Stop |
            Where-Object { $_.Type -eq 'A' } |
            Select-Object -ExpandProperty IPAddress
    )
    Add-Check -Name 'Aislamiento de salida' -Status 'Warning' -Details ([pscustomobject]@{
        ExternalResolution = $true
        Addresses = $external
    }) -ErrorText 'La resolucion externa funciona; revisar si la ventana de Internet sigue abierta.'
}
catch {
    Add-Check -Name 'Aislamiento de salida' -Status 'Ok' -Details ([pscustomobject]@{
        ExternalResolution = $false
        ExpectedInBaseLab = $true
    })
}

if ($targetIp) {
    foreach ($port in @(53, 88, 389, 445, 135)) {
        $open = Test-TcpPort -Address $targetIp -Port $port -TimeoutMs $TcpTimeoutMs
        $severity = 'Critical'
        if ($port -eq 135) {
            $severity = 'Warning'
        }
        $status = 'Ok'
        $errorText = $null
        if (-not $open) {
            $status = $severity
            $errorText = "No se pudo conectar al puerto $port de $targetIp en $TcpTimeoutMs ms."
        }
        Add-Check -Name "TCP $port" -Status $status -Details ([pscustomobject]@{
            Target = $targetIp
            Port = $port
            Open = $open
        }) -ErrorText $errorText
    }
}
else {
    Add-Check -Name 'Conectividad TCP al DC' -Status 'Critical' -ErrorText 'No se pudo determinar la IP del controlador.'
}

try {
    $routes = @(
        Get-NetRoute -AddressFamily IPv4 |
            Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } |
            Select-Object -Property InterfaceAlias, NextHop, RouteMetric
    )
    if (@($routes).Count -eq 0) {
        Add-Check -Name 'Rutas por defecto' -Status 'Ok' -Details ([pscustomobject]@{
            Count = 0
            ExpectedInBaseLab = $true
        })
    }
    else {
        Add-Check -Name 'Rutas por defecto' -Status 'Warning' -Details $routes -ErrorText 'Hay rutas por defecto; revisar el aislamiento.'
    }
}
catch {
    Add-Check -Name 'Rutas por defecto' -Status 'Warning' -ErrorText $_.Exception.Message
}

try {
    $sharePath = "\\$dcHost\Empresa"
    $shareVisible = Test-Path -LiteralPath $sharePath -ErrorAction Stop
    $shareStatus = 'Ok'
    $shareError = $null
    if (-not $shareVisible) {
        $shareStatus = 'Warning'
        $shareError = "El recurso $sharePath no fue visible para el usuario actual."
    }
    Add-Check -Name 'Conectividad SMB al recurso Empresa' -Status $shareStatus -Details ([pscustomobject]@{
        Path = $sharePath
        Visible = $shareVisible
        Identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        Note = 'Test-Path acredita visibilidad, no permisos de un usuario distinto.'
    }) -ErrorText $shareError
}
catch {
    Add-Check -Name 'Conectividad SMB al recurso Empresa' -Status 'Warning' -ErrorText $_.Exception.Message
}

try {
    $gpresult = & "$env:SystemRoot\System32\gpresult.exe" /r 2>&1 | Out-String
    $gpresultCode = $LASTEXITCODE
    $gpresultLines = @($gpresult -split "`r?`n")
    $gpresultBounded = ($gpresultLines | Select-Object -First 120) -join "`n"
    $gpStatus = 'Ok'
    $gpError = $null
    if ($gpresultCode -ne 0) {
        $gpStatus = 'Warning'
        $gpError = "gpresult devolvio el codigo $gpresultCode."
    }
    Add-Check -Name 'Politicas de grupo' -Status $gpStatus -Details ([pscustomobject]@{
        ExitCode = $gpresultCode
        Output = $gpresultBounded
        TotalLines = @($gpresultLines).Count
        Truncated = (@($gpresultLines).Count -gt 120)
        Note = 'La seccion de usuario corresponde al usuario de esta sesion.'
    }) -ErrorText $gpError
}
catch {
    Add-Check -Name 'Politicas de grupo' -Status 'Warning' -ErrorText $_.Exception.Message
}

try {
    $desktopPath = 'HKCU:\Control Panel\Desktop'
    $desktop = Get-ItemProperty -LiteralPath $desktopPath -ErrorAction Stop
    $screenSaveActive = if ($desktop.PSObject.Properties['ScreenSaveActive']) { $desktop.ScreenSaveActive } else { $null }
    $screenSaveTimeOut = if ($desktop.PSObject.Properties['ScreenSaveTimeOut']) { $desktop.ScreenSaveTimeOut } else { $null }
    $screenSaverIsSecure = if ($desktop.PSObject.Properties['ScreenSaverIsSecure']) { $desktop.ScreenSaverIsSecure } else { $null }
    $allValuesPresent = ($null -ne $screenSaveActive -and $null -ne $screenSaveTimeOut -and $null -ne $screenSaverIsSecure)
    $matchesPolicy = $allValuesPresent -and $screenSaveActive -eq '1' -and $screenSaveTimeOut -eq '300' -and $screenSaverIsSecure -eq '1'
    $screenLock = [pscustomobject]@{
        ScreenSaveActive = $screenSaveActive
        ScreenSaveTimeOut = $screenSaveTimeOut
        ScreenSaverIsSecure = $screenSaverIsSecure
        AllValuesPresent = $allValuesPresent
        MatchesLabPolicy = $matchesPolicy
        Note = 'Valores del usuario actual; no prueban el bloqueo efectivo ni la sesion de jperez.'
    }
    if ($matchesPolicy) {
        Add-Check -Name 'Bloqueo de pantalla (usuario actual)' -Status 'Ok' -Details $screenLock
    }
    elseif (-not $allValuesPresent) {
        Add-Check -Name 'Bloqueo de pantalla (usuario actual)' -Status 'Warning' -Details $screenLock -ErrorText 'Faltan valores de bloqueo de pantalla para el usuario actual.'
    }
    else {
        Add-Check -Name 'Bloqueo de pantalla (usuario actual)' -Status 'Warning' -Details $screenLock -ErrorText 'Los valores no coinciden con la politica esperada (1/300/1).'
    }
}
catch {
    Add-Check -Name 'Bloqueo de pantalla (usuario actual)' -Status 'Warning' -ErrorText $_.Exception.Message
}

$serviceNames = @('Dnscache', 'LanmanWorkstation', 'Netlogon', 'Winmgmt', 'w32time')
$serviceResults = @(
    foreach ($serviceName in $serviceNames) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Name = $serviceName
            Exists = ($null -ne $service)
            Status = $(if ($null -ne $service) { [string]$service.Status } else { $null })
            StartType = $(if ($null -ne $service) { [string]$service.StartType } else { $null })
        }
    }
)
$dnsServiceStopped = @($serviceResults | Where-Object { $_.Name -eq 'Dnscache' -and $_.Status -ne 'Running' })
$otherServicesStopped = @($serviceResults | Where-Object { $_.Name -ne 'Dnscache' -and $_.Status -ne 'Running' })
if (@($dnsServiceStopped).Count -gt 0) {
    Add-Check -Name 'Servicios clave' -Status 'Critical' -Details $serviceResults -ErrorText 'El cliente DNS no esta en ejecucion.'
}
elseif (@($otherServicesStopped).Count -gt 0) {
    Add-Check -Name 'Servicios clave' -Status 'Warning' -Details $serviceResults -ErrorText 'Hay servicios del cliente detenidos.'
}
else {
    Add-Check -Name 'Servicios clave' -Status 'Ok' -Details $serviceResults
}

try {
    $w32tm = & "$env:SystemRoot\System32\w32tm.exe" /query /status 2>&1 | Out-String
    $w32Code = $LASTEXITCODE
    Add-Check -Name 'Hora y zona horaria' -Status 'Ok' -Details ([pscustomobject]@{
        LocalTime = (Get-Date).ToString('o')
        TimeZone = (Get-TimeZone).Id
        W32TimeExitCode = $w32Code
        W32TimeStatus = $w32tm.Trim()
    })
}
catch {
    Add-Check -Name 'Hora y zona horaria' -Status 'Warning' -ErrorText $_.Exception.Message
}

try {
    $products = @(
        Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" -Property Name, Description, LicenseStatus, LicenseStatusReason, GracePeriodRemaining, EvaluationEndDate |
            Where-Object { $_.Name -match 'Windows' -and $_.LicenseStatus -ne 0 } |
            Select-Object -Property Name, Description, LicenseStatus,
                @{N = 'LicenseStatusReasonHex'; E = { '0x{0:X8}' -f [uint32]$_.LicenseStatusReason }},
                GracePeriodRemaining, EvaluationEndDate
    )
    $expiration = & "$env:SystemRoot\System32\cscript.exe" //Nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr 2>&1 | Out-String
    $activeProducts = @($products | Where-Object { $_.LicenseStatus -eq 1 })
    $licenseStatus = 'Warning'
    $licenseError = 'Ningun producto de Windows figura activado.'
    if (@($activeProducts).Count -gt 0) {
        $licenseStatus = 'Ok'
        $licenseError = $null
    }
    Add-Check -Name 'Licencia de Windows' -Status $licenseStatus -Details ([pscustomobject]@{
        Products = $products
        Expiration = $expiration.Trim()
    }) -ErrorText $licenseError
}
catch {
    Add-Check -Name 'Licencia de Windows' -Status 'Warning' -ErrorText $_.Exception.Message
}

$eventResults = [ordered]@{}
$totalEventErrors = 0
foreach ($logName in @('System', 'Application')) {
    try {
        $events = @(
            Get-WinEvent -FilterHashtable @{
                LogName = $logName
                Level = @(1, 2)
                StartTime = (Get-Date).AddHours(-24)
            } -MaxEvents $MaxEvents -ErrorAction Stop |
                Select-Object -Property TimeCreated, Id, LevelDisplayName, ProviderName,
                    @{N = 'Message'; E = { Limit-Text -Text $_.Message -Length 300 }}
        )
        $eventResults[$logName] = [pscustomobject]@{
            Count = @($events).Count
            Error = $null
            Events = $events
        }
        $totalEventErrors += @($events).Count
    }
    catch {
        $eventResults[$logName] = [pscustomobject]@{
            Count = 0
            Error = $_.Exception.Message
            Events = @()
        }
    }
}
if ($totalEventErrors -gt 0) {
    Add-Check -Name 'Errores recientes' -Status 'Warning' -Details $eventResults -ErrorText "$totalEventErrors eventos de error en las ultimas 24 horas."
}
else {
    Add-Check -Name 'Errores recientes' -Status 'Ok' -Details $eventResults
}

try {
    $profiles = @(
        Get-NetFirewallProfile -PolicyStore ActiveStore |
            Select-Object -Property Name,
                @{N = 'Enabled'; E = { [string]$_.Enabled }},
                @{N = 'DefaultInboundAction'; E = { [string]$_.DefaultInboundAction }},
                @{N = 'DefaultOutboundAction'; E = { [string]$_.DefaultOutboundAction }}
    )
    $disabledProfiles = @($profiles | Where-Object { $_.Enabled -ne 'True' })
    if (@($disabledProfiles).Count -gt 0) {
        Add-Check -Name 'Firewall' -Status 'Warning' -Details $profiles -ErrorText 'Hay perfiles de firewall deshabilitados.'
    }
    else {
        Add-Check -Name 'Firewall' -Status 'Ok' -Details $profiles
    }
}
catch {
    Add-Check -Name 'Firewall' -Status 'Warning' -ErrorText $_.Exception.Message
}

$overallStatus = 'Healthy'
$exitCode = 0
if ($criticalChecks.Count -gt 0) {
    $overallStatus = 'Critical'
    $exitCode = 2
}
elseif ($warningChecks.Count -gt 0) {
    $overallStatus = 'Warning'
    $exitCode = 1
}

$report = [ordered]@{
    Metadata = [ordered]@{
        Script = 'Test-LabClientHealth.ps1'
        Version = $script:Version
        StartedAt = $started.ToString('o')
        CompletedAt = (Get-Date).ToString('o')
        Computer = $env:COMPUTERNAME
        User = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        DomainName = $DomainName
        ExpectedDnsServer = $ExpectedDnsServer
        ExpectedDomainControllerIp = $ExpectedDomainControllerIp
        TcpTimeoutMs = $TcpTimeoutMs
        ReadOnly = $true
    }
    Identity = $identity
    Summary = [ordered]@{
        OverallStatus = $overallStatus
        ExitCode = $exitCode
        OkCount = @($checks | Where-Object { $_.Status -eq 'Ok' }).Count
        WarningCount = $warningChecks.Count
        CriticalCount = $criticalChecks.Count
        CriticalChecks = @($criticalChecks)
        WarningChecks = @($warningChecks)
    }
    Checks = $checks
}

$jsonPath = Join-Path $OutputDirectory ("lab-client-health-{0}.json" -f $env:COMPUTERNAME)
$txtPath = Join-Path $OutputDirectory ("lab-client-health-{0}.txt" -f $env:COMPUTERNAME)

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$summaryLines = @(
    "Diagnostico de cliente - $($env:COMPUTERNAME) - $($started.ToString('s'))"
    "Usuario: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    "Dominio esperado: $DomainName"
    "Estado general: $overallStatus"
    "Criticos: $($criticalChecks.Count); advertencias: $($warningChecks.Count)"
    ''
    'Comprobaciones:'
)
foreach ($check in $checks) {
    $suffix = ''
    if ($check.Error) {
        $suffix = ": $($check.Error)"
    }
    $summaryLines += " - [$($check.Status)] $($check.Name)$suffix"
}
$summaryLines += ''
$summaryLines += "Salida JSON: $jsonPath"
$summaryLines | Set-Content -LiteralPath $txtPath -Encoding UTF8

Write-Host "Diagnostico guardado en $jsonPath"
Write-Host "Resumen guardado en $txtPath"
Write-Host "Estado general: $overallStatus (codigo $exitCode)"

exit $exitCode
