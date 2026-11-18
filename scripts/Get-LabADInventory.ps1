<#
.SYNOPSIS
Genera un inventario acotado y de solo lectura de AD DS, DNS y recursos del laboratorio.

.DESCRIPTION
Recopila dominio, bosque, controladores, unidades organizativas, usuarios,
grupos, equipos, recursos compartidos, GPO y zonas DNS. No modifica
configuracion, no escribe en AD y no solicita credenciales. Esta pensado
para el laboratorio it-support-windows-lab y debe ejecutarse en DC01 con el
modulo ActiveDirectory. DnsServer y GroupPolicy se usan si estan disponibles.

.PARAMETER OutputDirectory
Carpeta donde se guardan el JSON y el resumen de texto.

.PARAMETER MaxItems
Maximo de objetos por seccion. Limita la salida; no reemplaza la paginacion
en dominios grandes.

.EXAMPLE
.\Get-LabADInventory.ps1 -OutputDirectory C:\Temp\Inventario

.EXAMPLE
.\Get-LabADInventory.ps1 -OutputDirectory C:\Temp\Inventario -MaxItems 100

.NOTES
Version 1.0.0. Solo lectura. No incluye contrasenas, claves ni hashes.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = (Join-Path $env:ProgramData 'ITSupportLab\Inventory'),

    [ValidateRange(10, 1000)]
    [int]$MaxItems = 200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '1.0.1'
$started = Get-Date

function New-DirectoryIfMissing {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

New-DirectoryIfMissing -Path $OutputDirectory

foreach ($moduleName in @('ActiveDirectory')) {
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        throw "Falta el modulo requerido: $moduleName."
    }
    Import-Module -Name $moduleName -ErrorAction Stop
}

$dnsAvailable = $null -ne (Get-Module -ListAvailable -Name DnsServer)
if ($dnsAvailable) {
    Import-Module -Name DnsServer -ErrorAction Stop
}

$gpoAvailable = $null -ne (Get-Module -ListAvailable -Name GroupPolicy)
if ($gpoAvailable) {
    Import-Module -Name GroupPolicy -ErrorAction Stop
}

$domain = Get-ADDomain -ErrorAction Stop
$forest = Get-ADForest -ErrorAction Stop

$domainControllers = @(
    Get-ADDomainController -Filter * |
        Select-Object -First $MaxItems |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                HostName = $_.HostName
                IPv4Address = $(if ($null -ne $_.IPv4Address) { $_.IPv4Address.ToString() } else { $null })
                Site = $_.Site
                IsGlobalCatalog = $_.IsGlobalCatalog
                IsReadOnly = $_.IsReadOnly
                OperatingSystem = $_.OperatingSystem
                OperationMasterRoles = @($_.OperationMasterRoles | ForEach-Object { [string]$_ })
            }
        }
)

$ous = @(
    Get-ADOrganizationalUnit -Filter * -ResultPageSize 100 -Properties Description |
        Sort-Object DistinguishedName |
        Select-Object -First $MaxItems |
        Select-Object -Property Name, DistinguishedName, Description
)

$users = @(
    Get-ADUser -Filter * -ResultPageSize 100 -ResultSetSize $MaxItems -Properties LockedOut, PasswordLastSet, LastLogonDate, whenCreated, whenChanged |
        Sort-Object SamAccountName |
        Select-Object -Property SamAccountName, Name, Enabled, LockedOut, PasswordLastSet, LastLogonDate, whenCreated, whenChanged, DistinguishedName
)

$groups = @(
    Get-ADGroup -Filter * -ResultPageSize 100 -ResultSetSize $MaxItems -Properties Description |
        Sort-Object SamAccountName |
        Select-Object -Property SamAccountName, Name,
            @{N = 'SID'; E = { $_.SID.Value } },
            @{N = 'GroupCategory'; E = { [string]$_.GroupCategory } },
            @{N = 'GroupScope'; E = { [string]$_.GroupScope } },
            Description, DistinguishedName
)

$computers = @(
    Get-ADComputer -Filter * -ResultPageSize 100 -ResultSetSize $MaxItems -Properties OperatingSystem, OperatingSystemVersion, LastLogonDate, whenCreated |
        Sort-Object Name |
        Select-Object -Property Name, DNSHostName, Enabled, OperatingSystem, OperatingSystemVersion, LastLogonDate, whenCreated, DistinguishedName
)

$domainSid = [string]$domain.DomainSID
if ([string]::IsNullOrEmpty($domainSid)) {
    throw 'No se pudo obtener el SID del dominio para localizar los grupos conocidos.'
}

$labGroupSpecs = @(
    [pscustomobject]@{ Label = 'GG_Administracion'; SamAccountName = 'GG_Administracion'; Sid = $null }
    [pscustomobject]@{ Label = 'GG_Ventas'; SamAccountName = 'GG_Ventas'; Sid = $null }
    [pscustomobject]@{ Label = 'GG_Soporte'; SamAccountName = 'GG_Soporte'; Sid = $null }
    [pscustomobject]@{ Label = 'Domain Admins'; SamAccountName = $null; Sid = "$domainSid-512" }
    [pscustomobject]@{ Label = 'Enterprise Admins'; SamAccountName = $null; Sid = "$domainSid-519" }
)

$labGroupMembers = @(
    foreach ($spec in $labGroupSpecs) {
        if ($spec.Sid) {
            $group = $groups | Where-Object { $_.SID -eq $spec.Sid } | Select-Object -First 1
        }
        else {
            $group = $groups | Where-Object { $_.SamAccountName -eq $spec.SamAccountName } | Select-Object -First 1
        }

        if ($null -eq $group) {
            [pscustomobject]@{
                Group = $spec.Label
                Exists = $false
                SamAccountName = $spec.SamAccountName
                DistinguishedName = $null
                MemberCount = 0
                Truncated = $false
                Members = @()
            }
        }
        else {
            $members = @(
                Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction Stop |
                    Select-Object -First $MaxItems |
                    Select-Object -Property Name, SamAccountName, objectClass
            )
            [pscustomobject]@{
                Group = $spec.Label
                Exists = $true
                SamAccountName = $group.SamAccountName
                DistinguishedName = $group.DistinguishedName
                MemberCount = @($members).Count
                Truncated = (@($members).Count -ge $MaxItems)
                Members = $members
            }
        }
    }
)

$shares = @(
    Get-SmbShare -ErrorAction Stop |
        Where-Object { -not $_.Special } |
        Sort-Object Name |
        Select-Object -First $MaxItems |
        ForEach-Object {
            $share = $_
            $access = @()
            $accessError = $null
            try {
                $access = @(
                    Get-SmbShareAccess -Name $share.Name -ErrorAction Stop |
                        ForEach-Object {
                            [pscustomobject]@{
                                AccountName = $_.AccountName
                                AccessControlType = [string]$_.AccessControlType
                                AccessRight = [string]$_.AccessRight
                            }
                        }
                )
            }
            catch {
                $accessError = $_.Exception.Message
            }
            [pscustomobject]@{
                Name = $share.Name
                Path = $share.Path
                Description = $share.Description
                Access = $access
                AccessError = $accessError
            }
        }
)

$gpos = @()
if ($gpoAvailable) {
    $gpos = @(
        Get-GPO -All -ErrorAction Stop |
            Sort-Object DisplayName |
            Select-Object -First $MaxItems |
            ForEach-Object {
                [pscustomobject]@{
                    DisplayName = $_.DisplayName
                    Id = $_.Id.ToString()
                    GpoStatus = [string]$_.GpoStatus
                    ModificationTime = $_.ModificationTime
                    Description = $_.Description
                }
            }
    )
}

$gpoLinks = @()
if ($gpoAvailable) {
    $targets = @(
        $domain.DistinguishedName
        "OU=EMPRESA,$($domain.DistinguishedName)"
    )
    foreach ($target in $targets) {
        try {
            $inheritance = Get-GPInheritance -Target $target -ErrorAction Stop
            $links = @($inheritance.GpoLinks | Select-Object -Property DisplayName, Enabled, Enforced, Order)
            $gpoLinks += [pscustomobject]@{
                Target = $target
                Links = $links
                Error = $null
            }
        }
        catch {
            $gpoLinks += [pscustomobject]@{
                Target = $target
                Links = @()
                Error = $_.Exception.Message
            }
        }
    }
}

$dns = [ordered]@{
    ModuleAvailable = $dnsAvailable
    Zones = @()
    Forwarders = @()
    Settings = $null
    DomainARecords = @()
}
if ($dnsAvailable) {
    $dns.Zones = @(
        Get-DnsServerZone |
            Sort-Object ZoneName |
            Select-Object -First $MaxItems -Property ZoneName, ZoneType, IsDsIntegrated, IsReverseLookupZone, DynamicUpdate
    )

    $forwarders = Get-DnsServerForwarder -ErrorAction Stop
    $dns.Forwarders = @($forwarders.IPAddress | Where-Object { $null -ne $_ } | ForEach-Object { $_.ToString() })

    $settings = Get-DnsServerSetting -All -ErrorAction Stop
    $dns.Settings = [pscustomobject]@{
        ListeningIPAddress = @($settings.ListeningIPAddress | Where-Object { $null -ne $_ } | ForEach-Object { $_.ToString() })
        AllIPAddress = @($settings.AllIPAddress | Where-Object { $null -ne $_ } | ForEach-Object { $_.ToString() })
    }

    $dns.DomainARecords = @(
        Get-DnsServerResourceRecord -ZoneName $domain.DNSRoot -RRType A -ErrorAction SilentlyContinue |
            Select-Object -First $MaxItems -Property HostName, @{N = 'IPv4'; E = { $_.RecordData.IPv4Address.ToString() } }
    )
}

$serviceNames = @('NTDS', 'DNS', 'Netlogon', 'Dnscache', 'LanmanServer')
$services = @(
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

$sysvol = [pscustomobject]@{
    SysvolShare = ($null -ne (Get-SmbShare -Name 'SYSVOL' -ErrorAction SilentlyContinue))
    NetlogonShare = ($null -ne (Get-SmbShare -Name 'NETLOGON' -ErrorAction SilentlyContinue))
    SysvolPath = $(if (Test-Path -LiteralPath "$env:SystemRoot\SYSVOL\sysvol") { "$env:SystemRoot\SYSVOL\sysvol" } else { $null })
}

$counts = [ordered]@{
    DomainControllers = @($domainControllers).Count
    OrganizationalUnits = @($ous).Count
    Users = @($users).Count
    Groups = @($groups).Count
    Computers = @($computers).Count
    Shares = @($shares).Count
    Gpos = @($gpos).Count
    DnsZones = @($dns.Zones).Count
}

$report = [ordered]@{
    Metadata = [ordered]@{
        Script = 'Get-LabADInventory.ps1'
        Version = $script:Version
        StartedAt = $started.ToString('o')
        CompletedAt = (Get-Date).ToString('o')
        Computer = $env:COMPUTERNAME
        User = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        ReadOnly = $true
        MaxItems = $MaxItems
    }
    Domain = [ordered]@{
        DNSRoot = $domain.DNSRoot
        NetBIOSName = $domain.NetBIOSName
        DomainMode = [string]$domain.DomainMode
        DistinguishedName = $domain.DistinguishedName
        PDCEmulator = $domain.PDCEmulator
        Forest = $domain.Forest
        ParentDomain = $domain.ParentDomain
    }
    Forest = [ordered]@{
        Name = $forest.Name
        ForestMode = [string]$forest.ForestMode
        RootDomain = $forest.RootDomain
        GlobalCatalogs = @($forest.GlobalCatalogs)
        SchemaMaster = $forest.SchemaMaster
        DomainNamingMaster = $forest.DomainNamingMaster
    }
    DomainControllers = $domainControllers
    OrganizationalUnits = $ous
    Users = $users
    Groups = $groups
    LabGroupMembers = $labGroupMembers
    Computers = $computers
    Shares = $shares
    Gpos = $gpos
    GpoLinks = $gpoLinks
    Dns = $dns
    Services = $services
    Sysvol = $sysvol
    Counts = $counts
    Limits = [ordered]@{
        MaxItemsPerSection = $MaxItems
        Note = 'La salida esta limitada por seccion; un conteo igual a MaxItems puede indicar truncamiento.'
    }
}

$jsonPath = Join-Path $OutputDirectory ("lab-ad-inventory-{0}.json" -f $env:COMPUTERNAME)
$txtPath = Join-Path $OutputDirectory ("lab-ad-inventory-{0}.txt" -f $env:COMPUTERNAME)

$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$summary = @(
    "Inventario AD - $($env:COMPUTERNAME) - $($started.ToString('s'))"
    "Dominio: $($domain.DNSRoot) ($($domain.NetBIOSName))"
    "Bosque: $($forest.Name)"
    "Controladores: $($counts.DomainControllers)"
    "Unidades organizativas: $($counts.OrganizationalUnits)"
    "Usuarios: $($counts.Users)"
    "Grupos: $($counts.Groups)"
    "Equipos: $($counts.Computers)"
    "Recursos compartidos: $($counts.Shares)"
    "GPO: $($counts.Gpos)"
    "Zonas DNS: $($counts.DnsZones)"
    "Salida JSON: $jsonPath"
)
$summary | Set-Content -LiteralPath $txtPath -Encoding UTF8

Write-Host "Inventario guardado en $jsonPath"
Write-Host "Resumen guardado en $txtPath"
