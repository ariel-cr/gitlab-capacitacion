# Verificación de requisitos previos. Se corre ANTES del primer día.
#
# Su único propósito es que nadie llegue a la sesión con la máquina sin
# preparar. Si este script sale todo en verde, la persona puede seguir el
# laboratorio; si sale algo en rojo, hay tiempo de arreglarlo antes.
#
#   powershell -ExecutionPolicy Bypass -File 00-verificar.ps1
#
# El parámetro -Instalar intenta poner lo que falte con winget.

param([switch]$Instalar)

$ErrorActionPreference = 'Continue'
$fallos = 0
$avisos = 0

function Titulo($t) { Write-Host ""; Write-Host $t -ForegroundColor Cyan; Write-Host ("-" * $t.Length) -ForegroundColor DarkCyan }
function Ok($m)     { Write-Host "  [ ok ] $m" -ForegroundColor Green }
function Falla($m)  { Write-Host "  [FALLA] $m" -ForegroundColor Red;    $script:fallos++ }
function Aviso($m)  { Write-Host "  [aviso] $m" -ForegroundColor Yellow; $script:avisos++ }

function Existe($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Titulo "1 . Recursos de la maquina"
$cs  = Get-CimInstance Win32_ComputerSystem
$ram = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$cpu = $cs.NumberOfLogicalProcessors
$libre = [math]::Round((Get-PSDrive C).Free / 1GB, 1)

if ($ram -ge 16)      { Ok "RAM ${ram} GB" }
elseif ($ram -ge 8)   { Aviso "RAM ${ram} GB - justo. Cierre todo lo demas durante la clase" }
else                  { Falla "RAM ${ram} GB - insuficiente. Se necesitan 8 GB como minimo" }

if ($cpu -ge 4) { Ok "CPU ${cpu} nucleos logicos" } else { Falla "CPU ${cpu} nucleos - se necesitan 4" }
if ($libre -ge 25) { Ok "Disco libre ${libre} GB" } else { Falla "Disco libre ${libre} GB - se necesitan 25 GB" }

Titulo "2 . Virtualizacion y WSL2"
if ($cs.HypervisorPresent) { Ok "Virtualizacion activa" }
else { Falla "Virtualizacion DESACTIVADA - hay que habilitarla en la BIOS" }

if (Existe wsl) {
    $v = (wsl --status 2>&1 | Out-String)
    if ($v -match '2') { Ok "WSL2 presente" } else { Aviso "WSL presente, confirme que la version por defecto es 2: wsl --set-default-version 2" }
} else { Falla "WSL no instalado - ejecute: wsl --install" }

Titulo "3 . Herramientas"
$necesarias = @(
    @{ cmd='git';     nombre='Git';            winget='Git.Git';                      version='git --version' },
    @{ cmd='docker';  nombre='Docker Desktop'; winget='Docker.DockerDesktop';         version='docker --version' },
    @{ cmd='kubectl'; nombre='kubectl';        winget='Kubernetes.kubectl';           version='kubectl version --client' },
    @{ cmd='k3d';     nombre='k3d';            winget='k3d.k3d';                      version='k3d version' }
)

foreach ($h in $necesarias) {
    if (Existe $h.cmd) {
        $v = (Invoke-Expression $h.version 2>&1 | Select-Object -First 1)
        Ok "$($h.nombre) - $v"
    } else {
        if ($Instalar) {
            Write-Host "  ... instalando $($h.nombre) con winget" -ForegroundColor DarkGray
            winget install --id $($h.winget) -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
            if (Existe $h.cmd) { Ok "$($h.nombre) instalado" } else { Falla "$($h.nombre) no se pudo instalar - hagalo a mano" }
        } else {
            Falla "$($h.nombre) no instalado - winget install --id $($h.winget) -e"
        }
    }
}

Titulo "4 . Docker en marcha"
if (Existe docker) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) {
        Ok "El demonio de Docker responde"
        $imgs = (docker images --format '{{.Repository}}:{{.Tag}}' 2>$null)
        foreach ($i in @('alpine:3.20','nginx:1.27-alpine','docker:27-cli','bitnami/kubectl:1.31')) {
            if ($imgs -contains $i) { Ok "imagen precargada $i" }
            else { Aviso "falta la imagen $i - descarguela antes: docker pull $i" }
        }
    } else { Falla "Docker instalado pero el demonio no responde - abra Docker Desktop" }
}

Titulo "5 . Red"
foreach ($destino in @('registry-1.docker.io','gitlab.com')) {
    if (Test-NetConnection -ComputerName $destino -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue) {
        Ok "alcanza $destino"
    } else { Aviso "no alcanza $destino - puede ser el proxy de la red corporativa" }
}

Write-Host ""
Write-Host ("=" * 60)
if ($fallos -eq 0 -and $avisos -eq 0) {
    Write-Host " TODO LISTO. Puede venir a la capacitacion." -ForegroundColor Green
} elseif ($fallos -eq 0) {
    Write-Host " LISTO CON $avisos AVISO(S). Revise lo amarillo, pero puede venir." -ForegroundColor Yellow
} else {
    Write-Host " $fallos PROBLEMA(S) QUE HAY QUE RESOLVER ANTES DE LA CLASE." -ForegroundColor Red
    Write-Host " Vuelva a correr con -Instalar para que intente ponerlo solo." -ForegroundColor DarkGray
}
Write-Host ("=" * 60)
exit $(if ($fallos -gt 0) { 1 } else { 0 })
