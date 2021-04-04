
$cache_hit=$args[0]

function Export-Path {
    # Store the CUDA_PATH in the environment for the current session, to be forwarded in the action.
    $CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$($CUDA_MAJOR).$($CUDA_MINOR)"
    $CUDA_PATH_VX_Y = "CUDA_PATH_V$($CUDA_MAJOR)_$($CUDA_MINOR)"
    # Set environmental variables in this session
    $env:CUDA_PATH = "$($CUDA_PATH)"
    $env:CUDA_PATH_VX_Y = "$($CUDA_PATH_VX_Y)"
    Write-Output "CUDA_PATH $($CUDA_PATH)"
    Write-Output "CUDA_PATH_VX_Y $($CUDA_PATH_VX_Y)"

    # PATH needs updating elsewhere, anything in here won't persist.
    # Append $CUDA_PATH/bin to path.
    # Set CUDA_PATH as an environmental variable
}


## -------------------
## Select CUDA version
## -------------------

# Get the cuda version from the environment as env:cuda.
$CUDA_VERSION_FULL = $env:cuda
# Make sure CUDA_VERSION_FULL is set and valid, otherwise error.

# Validate CUDA version, extracting components via regex
$cuda_ver_matched = $CUDA_VERSION_FULL -match "^(?<major>[1-9][0-9]*)\.(?<minor>[0-9]+)\.(?<patch>[0-9]+)$"
if(-not $cuda_ver_matched){
    Write-Output "Invalid CUDA version specified, <major>.<minor>.<patch> required. '$CUDA_VERSION_FULL'."
    exit 1
}
$CUDA_MAJOR=$Matches.major
$CUDA_MINOR=$Matches.minor
$CUDA_PATCH=$Matches.patch

if ($cache_hit -eq 'true') {
    Write-Output "CUDA Cache hit, I don't need to install, so I will only export paths"

    Export-Path
    exit 0
}
## -------------------
## Constants
## -------------------

# Dictionary of known cuda versions and thier download URLS, which do not follow a consistent pattern :(
$CUDA_KNOWN_URLS = @{
    "8.0.44" = "http://developer.nvidia.com/compute/cuda/8.0/Prod/network_installers/cuda_8.0.44_win10_network-exe";
    "8.0.61" = "http://developer.nvidia.com/compute/cuda/8.0/Prod2/network_installers/cuda_8.0.61_win10_network-exe";
    "9.0.176" = "http://developer.nvidia.com/compute/cuda/9.0/Prod/network_installers/cuda_9.0.176_win10_network-exe";
    "9.1.85" = "http://developer.nvidia.com/compute/cuda/9.1/Prod/network_installers/cuda_9.1.85_win10_network";
    "9.2.148" = "http://developer.nvidia.com/compute/cuda/9.2/Prod2/network_installers2/cuda_9.2.148_win10_network";
    "10.0.130" = "http://developer.nvidia.com/compute/cuda/10.0/Prod/network_installers/cuda_10.0.130_win10_network";
    "10.1.105" = "http://developer.nvidia.com/compute/cuda/10.1/Prod/network_installers/cuda_10.1.105_win10_network.exe";
    "10.1.168" = "http://developer.nvidia.com/compute/cuda/10.1/Prod/network_installers/cuda_10.1.168_win10_network.exe";
    "10.1.243" = "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/network_installers/cuda_10.1.243_win10_network.exe";
    "10.2.89" = "http://developer.download.nvidia.com/compute/cuda/10.2/Prod/network_installers/cuda_10.2.89_win10_network.exe";
    "11.0.167" = "http://developer.download.nvidia.com/compute/cuda/11.0.1/network_installers/cuda_11.0.1_win10_network.exe";
    "11.2.152" = "https://developer.download.nvidia.com/compute/cuda/11.2.2/network_installers/cuda_11.2.2_win10_network.exe"
}

# cuda_runtime.h is in nvcc <= 10.2, but cudart >= 11.0
# @todo - make this easier to vary per CUDA version.
# https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html#install-cuda-software
$CUDA_PACKAGES_IN = @(
    "cufft_dev";
    "cublas_dev";
    "nvcc";
    "curand_dev";
    "nvrtc_dev";
    "cudart";
    "nvrtc_dev";
    "nvml_dev";
    "npp_dev";
    "cusparse_dev";
    "curand_dev";
    "cusolver_dev";
)



## ------------------------------------------------
## Select CUDA packages to install from environment
## ------------------------------------------------

$CUDA_PACKAGES = ""

# for CUDA >= 11 cudart is a required package.
# if([version]$CUDA_VERSION_FULL -ge [version]"11.0") {
#     if(-not $CUDA_PACKAGES_IN -contains "cudart") {
#         $CUDA_PACKAGES_IN += 'cudart'
#     }
# }

Foreach ($package in $CUDA_PACKAGES_IN) {
    # Make sure the correct package name is used for nvcc.
    if($package -eq "nvcc" -and [version]$CUDA_VERSION_FULL -lt [version]"9.1"){
        $package="compiler"
    } elseif($package -eq "compiler" -and [version]$CUDA_VERSION_FULL -ge [version]"9.1") {
        $package="nvcc"
    }
    $CUDA_PACKAGES += " $($package)_$($CUDA_MAJOR).$($CUDA_MINOR)"

}
echo "$($CUDA_PACKAGES)"
## -----------------
## Prepare download
## -----------------

# Select the download link if known, otherwise have a guess.
$CUDA_REPO_PKG_REMOTE=""
if($CUDA_KNOWN_URLS.containsKey($CUDA_VERSION_FULL)){
    $CUDA_REPO_PKG_REMOTE=$CUDA_KNOWN_URLS[$CUDA_VERSION_FULL]
} else{
    # Guess what the url is given the most recent pattern (at the time of writing, 10.1)
    Write-Output "note: URL for CUDA ${$CUDA_VERSION_FULL} not known, estimating."
    $CUDA_REPO_PKG_REMOTE="http://developer.download.nvidia.com/compute/cuda/$($CUDA_MAJOR).$($CUDA_MINOR)/Prod/network_installers/cuda_$($CUDA_VERSION_FULL)_win10_network.exe"
}
$CUDA_REPO_PKG_LOCAL="cuda_$($CUDA_VERSION_FULL)_win10_network.exe"


## ------------
## Install CUDA
## ------------

# Get CUDA network installer
Write-Output "Downloading CUDA Network Installer for $($CUDA_VERSION_FULL) from: $($CUDA_REPO_PKG_REMOTE)"
Invoke-WebRequest $CUDA_REPO_PKG_REMOTE -OutFile $CUDA_REPO_PKG_LOCAL | Out-Null
if(Test-Path -Path $CUDA_REPO_PKG_LOCAL){
    Write-Output "Downloading Complete"
} else {
    Write-Output "Error: Failed to download $($CUDA_REPO_PKG_LOCAL) from $($CUDA_REPO_PKG_REMOTE)"
    exit 1
}

# Invoke silent install of CUDA (via network installer)
Write-Output "Installing CUDA $($CUDA_VERSION_FULL). Subpackages $($CUDA_PACKAGES)"
Start-Process -Wait -FilePath .\"$($CUDA_REPO_PKG_LOCAL)" -ArgumentList "-s $($CUDA_PACKAGES)"

# Check the return status of the CUDA installer.
if (!$?) {
    Write-Output "Error: CUDA installer reported error. $($LASTEXITCODE)"
    exit 1
}

Export-Path
