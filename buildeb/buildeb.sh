#!/usr/bin/env bash

set -e  # Exit immediately if a command exits with a non-zero status

# Enhanced error handling and debugging
DEBUG_LOG="/tmp/secos_build_debug.log"
exec 2> >(tee -a "${DEBUG_LOG}")

debug_info() {
    echo "=== DEBUG: $1 ===" | tee -a "${DEBUG_LOG}"
    echo "Timestamp: $(date)" | tee -a "${DEBUG_LOG}"
    echo "Memory usage: $(free -h | grep '^Mem:' | awk '{print "Used: " $3 ", Available: " $7}')" | tee -a "${DEBUG_LOG}"
    echo "Disk usage: $(df -h /tmp | tail -1 | awk '{print "Used: " $3 ", Available: " $4}')" | tee -a "${DEBUG_LOG}"
    echo "Process count: $(ps aux | wc -l)" | tee -a "${DEBUG_LOG}"
    echo "Last 5 apt errors:" | tee -a "${DEBUG_LOG}"
    tail -5 /var/log/apt/term.log 2>/dev/null | tee -a "${DEBUG_LOG}" || echo "No apt logs available" | tee -a "${DEBUG_LOG}"
    echo "" | tee -a "${DEBUG_LOG}"
}

handle_error() {
    local exit_code=$?
    local line_number=$1
    echo "=== CRITICAL ERROR ===" | tee -a "${DEBUG_LOG}"
    echo "Exit code: ${exit_code}" | tee -a "${DEBUG_LOG}"
    echo "Failed at line: ${line_number}" | tee -a "${DEBUG_LOG}"
    echo "Command: ${BASH_COMMAND}" | tee -a "${DEBUG_LOG}"
    echo "Function stack: ${FUNCNAME[*]}" | tee -a "${DEBUG_LOG}"
    debug_info "Error occurred"
    
    # Show chroot processes if they exist
    if [ -d "${LIVE_BOOT_DIR}/chroot/proc" ]; then
        echo "Chroot processes:" | tee -a "${DEBUG_LOG}"
        sudo lsof "${LIVE_BOOT_DIR}/chroot" 2>/dev/null | tee -a "${DEBUG_LOG}" || echo "No chroot processes found" | tee -a "${DEBUG_LOG}"
    fi
    
    # Show last 20 lines of debug log
    echo "=== LAST 20 DEBUG LINES ===" | tee -a "${DEBUG_LOG}"
    tail -20 "${DEBUG_LOG}"
    
    exit $exit_code
}

trap 'handle_error ${LINENO}' ERR
trap 'rm -rf "${LIVE_BOOT_DIR}"' EXIT  # Clean up on exit

echo "=== Starting secOS Build Process ===" | tee -a "${DEBUG_LOG}"
debug_info "Build initialization"

# Constants
DEBIAN_MIRROR="http://ftp.us.debian.org/debian/"
NODY_GREETER_URL="https://github.com/JezerM/nody-greeter/releases/download/1.6.2/nody-greeter-1.6.2-debian.deb"
OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.7.4/obsidian_1.7.4_amd64.deb"
CAIDO_URL="https://caido.download/releases/v0.42.0/caido-cli-v0.42.0-linux-x86_64.tar.gz"

# Try current directory first, fall back to /tmp if needed
if mkdir -p "${PWD}/LIVE_BOOT" 2>/dev/null; then
    LIVE_BOOT_DIR="${PWD}/LIVE_BOOT"
else
    LIVE_BOOT_DIR="/tmp/LIVE_BOOT"
fi
ISO_NAME="secOS.iso"
USERNAME="mist"

CUSTOM_PROGRAMS=(
    # Dev
    openssh-server
    # Packages
    firefox-esr kitty spotify-client vim nmap hashcat hydra netcat-openbsd lightdm awesome picom rofi proxychains kismet calamares
    # Dependencies
    sudo git golang-go python3 python3-pip pipx python3-setuptools unzip pciutils wget tar dpkg locales tzdata curl gpg
    network-manager net-tools network-manager-gnome wpasupplicant wireless-tools dnsutils aircrack-ng iputils-ping iproute2
    firmware-linux-nonfree firmware-iwlwifi xorg xserver-xorg xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-all alsa-utils playerctl
    gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev
    libxcb1-dev libx11-dev libnss3-tools libxft-dev libxrandr-dev libxpm-dev uthash-dev os-prober kpackagetool5 libkf5configcore5 libkf5coreaddons5 libkf5package5 libkf5parts5 
    libkpmcore12 libparted2 libpwquality1 libqt5dbus5 libqt5gui5 libqt5network5 libqt5qml5 libqt5quick5 libqt5svg5 libqt5widgets5 libqt5xml5 libstdc++6
    qml-module-qtquick2 qml-module-qtquick-controls qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-window2 python3-yaml 
    udisks2 dosfstools e2fsprogs btrfs-progs xfsprogs squashfs-tools grub-efi-amd64 tcpdump hostapd hcxdumptool bluez
)

NO_RECOMMENDS_PROGRAMS=(
    nemo
)

setup_build_env() {
    echo "Setting up build environment..."
    if [ -f "${ISO_NAME}" ]; then
        rm "${ISO_NAME}"
    fi
    
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y apt-utils debootstrap squashfs-tools xorriso \
        isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin grub-efi-ia32-bin \
        mtools dosfstools wget unzip >/dev/null 2>&1
}

bootstrap_debian() {
    echo "Bootstrapping Debian..."
    mkdir -p "${LIVE_BOOT_DIR}"
    sudo debootstrap --arch=amd64 --variant=minbase stable \
        "${LIVE_BOOT_DIR}/chroot" "${DEBIAN_MIRROR}" >/dev/null 2>&1
}

install_kernel_and_packages() {
    echo "Installing kernel and packages..." | tee -a "${DEBUG_LOG}"
    debug_info "Starting package installation"
    
    # Create user with detailed logging
    echo "Creating user ${USERNAME}..." | tee -a "${DEBUG_LOG}"
    if sudo chroot "${LIVE_BOOT_DIR}/chroot" useradd -m -s /bin/bash "${USERNAME}" 2>>"${DEBUG_LOG}"; then
        echo "✓ User ${USERNAME} created successfully" | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Failed to create user ${USERNAME}" | tee -a "${DEBUG_LOG}"
        return 1
    fi
    
    # Set passwords
    echo "Setting user passwords..." | tee -a "${DEBUG_LOG}"
    echo "${USERNAME}:live" | sudo chroot "${LIVE_BOOT_DIR}/chroot" chpasswd 2>>"${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" usermod -aG sudo "${USERNAME}" 2>>"${DEBUG_LOG}"
    echo 'root:live' | sudo chroot "${LIVE_BOOT_DIR}/chroot" chpasswd 2>>"${DEBUG_LOG}"
    
    debug_info "User setup completed"
    
    # Configure repositories with detailed logging
    echo "Configuring repositories..." | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list" 2>>"${DEBUG_LOG}"
    
    echo "Current sources.list content:" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" cat /etc/apt/sources.list | tee -a "${DEBUG_LOG}"
    
    # Install basic tools first
    echo "Installing basic tools (curl, gpg)..." | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install -y curl gpg" 2>>"${DEBUG_LOG}"
    
    if [ $? -eq 0 ]; then
        echo "✓ Basic tools installed successfully" | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Failed to install basic tools" | tee -a "${DEBUG_LOG}"
        debug_info "Basic tools installation failed"
        return 1
    fi
    
    # Add external repositories with error handling
    echo "Adding external repositories..." | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        # Test network connectivity first
        echo 'Testing network connectivity...'
        if curl -s --connect-timeout 10 https://www.google.com >/dev/null; then
            echo '✓ Network connectivity OK'
        else
            echo '✗ Network connectivity issues'
            exit 1
        fi
        
        # Spotify repository
        echo 'Adding Spotify repository...'
        if curl -f -sS --connect-timeout 30 https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/spotify.gpg 2>/dev/null; then
            echo 'deb http://repository.spotify.com stable non-free' > /etc/apt/sources.list.d/spotify.list
            echo '✓ Spotify repository added successfully'
        else
            echo '✗ Failed to add Spotify repository (continuing without it)'
        fi
        
        # Kismet repository
        echo 'Adding Kismet repository...'
        if curl -f -sS --connect-timeout 30 https://www.kismetwireless.net/repos/kismet-release.gpg.key | gpg --dearmor > /usr/share/keyrings/kismet-archive-keyring.gpg 2>/dev/null; then
            echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' > /etc/apt/sources.list.d/kismet.list
            echo '✓ Kismet repository added successfully'
        else
            echo '✗ Failed to add Kismet repository (continuing without it)'
        fi
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    debug_info "Repository setup completed"
    
    # Update package lists with more thorough approach
    echo "Updating package lists..." | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && apt-get clean && apt-get update" 2>&1 | tee -a "${DEBUG_LOG}"
    
    local update_exit_code=${PIPESTATUS[0]}
    if [ $update_exit_code -eq 0 ]; then
        echo "✓ Package lists updated successfully" | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Failed to update package lists with exit code: $update_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "Package list update failed"
        
        # Show what repositories are configured
        echo "Current repository configuration:" | tee -a "${DEBUG_LOG}"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "find /etc/apt -name '*.list*' -exec echo '=== {} ===' \; -exec cat {} \;" 2>&1 | tee -a "${DEBUG_LOG}"
        
        # Try a more forceful update
        echo "Attempting forceful package list update..." | tee -a "${DEBUG_LOG}"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
            "export DEBIAN_FRONTEND=noninteractive && apt-get update --allow-insecure-repositories" 2>&1 | tee -a "${DEBUG_LOG}"
    fi
    
    # Install kernel first (most critical)
    echo "Installing Linux kernel..." | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && \
        apt-get --yes --quiet -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" install linux-image-amd64 live-boot systemd-sysv" 2>&1 | tee -a "${DEBUG_LOG}"
    
    local kernel_exit_code=${PIPESTATUS[0]}
    if [ $kernel_exit_code -eq 0 ]; then
        echo "✓ Kernel installed successfully" | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Kernel installation failed with exit code: $kernel_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "Kernel installation failed"
        echo "Attempting to check what went wrong..." | tee -a "${DEBUG_LOG}"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "apt-cache policy linux-image-amd64" 2>&1 | tee -a "${DEBUG_LOG}"
        return $kernel_exit_code
    fi
    
    debug_info "Kernel installation completed"
    
    # Install packages in smaller batches
    echo "Installing core packages..." | tee -a "${DEBUG_LOG}"
    
    # Remove problematic packages that we know might fail
    SAFE_PROGRAMS=($(printf '%s\n' "${CUSTOM_PROGRAMS[@]}" | grep -v -E '^(spotify-client|kismet|firmware-iwlwifi)$'))
    
    # Install packages with detailed error reporting
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && \
        apt-get --yes --quiet -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" install ${SAFE_PROGRAMS[*]}" 2>&1 | tee -a "${DEBUG_LOG}"
    
    local packages_exit_code=${PIPESTATUS[0]}
    if [ $packages_exit_code -eq 0 ]; then
        echo "✓ Core packages installed successfully" | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Core packages installation failed with exit code: $packages_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "Core packages installation failed"
        
        # Try to identify which packages failed
        echo "Checking individual package availability..." | tee -a "${DEBUG_LOG}"
        for pkg in "${SAFE_PROGRAMS[@]}"; do
            sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "apt-cache show $pkg >/dev/null 2>&1" && echo "✓ $pkg available" || echo "✗ $pkg NOT available" 
        done 2>&1 | tee -a "${DEBUG_LOG}"
        
        return $packages_exit_code
    fi
    
    # Try to install optional packages separately
    echo "Installing optional packages..." | tee -a "${DEBUG_LOG}"
    for optional_pkg in spotify-client firmware-iwlwifi; do
        echo "Attempting to install $optional_pkg..." | tee -a "${DEBUG_LOG}"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
            "export DEBIAN_FRONTEND=noninteractive && \
            apt-get --yes --quiet -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" install $optional_pkg" 2>&1 | tee -a "${DEBUG_LOG}"
        
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            echo "✓ $optional_pkg installed successfully" | tee -a "${DEBUG_LOG}"
        else
            echo "✗ $optional_pkg installation failed (continuing without it)" | tee -a "${DEBUG_LOG}"
        fi
    done
    
    # Install no-recommends packages
    echo "Installing no-recommends packages..." | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && \
        apt-get --yes --quiet --no-install-recommends install ${NO_RECOMMENDS_PROGRAMS[*]}" 2>&1 | tee -a "${DEBUG_LOG}"
    
    debug_info "Package installation phase completed"
    
    # External package installations with error handling
    install_external_packages_with_debug
}

install_external_packages_with_debug() {
    echo "Installing external packages..." | tee -a "${DEBUG_LOG}"
    
    # Nody-Greeter install with error handling
    echo "Installing Nody-Greeter..." | tee -a "${DEBUG_LOG}"
    if sudo wget --timeout=30 -q -O "${LIVE_BOOT_DIR}/chroot/tmp/nody-greeter.deb" "$NODY_GREETER_URL" 2>>"${DEBUG_LOG}"; then
        echo "✓ Nody-Greeter downloaded successfully" | tee -a "${DEBUG_LOG}"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            dpkg -i /tmp/nody-greeter.deb 2>&1 && echo 'Nody-Greeter installed successfully' || echo 'Nody-Greeter installation failed'
            rm /tmp/nody-greeter.deb
        " 2>&1 | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Failed to download Nody-Greeter" | tee -a "${DEBUG_LOG}"
    fi

    # Calamares install - commented out, moved to custom packages list
    # echo "Installing Calamares..." | tee -a "${DEBUG_LOG}"
    # if [ -f "${PWD}/config/calamares/calamares_3.3.8.deb" ]; then
    #     sudo cp "${PWD}/config/calamares/calamares_3.3.8.deb" "${LIVE_BOOT_DIR}/chroot/tmp/calamares.deb"
    #     sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
    #         dpkg -i /tmp/calamares.deb 2>&1 && echo 'Calamares installed successfully' || echo 'Calamares installation failed'
    #         rm /tmp/calamares.deb
    #     " 2>&1 | tee -a "${DEBUG_LOG}"
    # else
    #     echo "✗ Calamares .deb file not found" | tee -a "${DEBUG_LOG}"
    # fi

    # Obsidian install with error handling
    echo "Installing Obsidian..." | tee -a "${DEBUG_LOG}"
    if sudo wget --timeout=30 -q -O "${LIVE_BOOT_DIR}/chroot/tmp/obsidian.deb" "$OBSIDIAN_URL" 2>>"${DEBUG_LOG}"; then
        echo "✓ Obsidian downloaded successfully" | tee -a "${DEBUG_LOG}"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            dpkg -i /tmp/obsidian.deb 2>&1 || apt-get install -f -y
            ln -sf /opt/Obsidian/obsidian /usr/local/bin/obsidian 2>/dev/null || echo 'Failed to create Obsidian symlink'
            rm /tmp/obsidian.deb
            echo 'Obsidian installation completed'
        " 2>&1 | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Failed to download Obsidian" | tee -a "${DEBUG_LOG}"
    fi

    # Caido CLI install with error handling
    echo "Installing Caido CLI..." | tee -a "${DEBUG_LOG}"
    if sudo wget --timeout=30 -q -O "${LIVE_BOOT_DIR}/chroot/tmp/caido-cli.tar.gz" "$CAIDO_URL" 2>>"${DEBUG_LOG}"; then
        echo "✓ Caido CLI downloaded successfully" | tee -a "${DEBUG_LOG}"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            cd /tmp &&
            tar -xzf caido-cli.tar.gz 2>&1 &&
            mv caido-cli /usr/local/bin/caido-cli &&
            chmod +x /usr/local/bin/caido-cli &&
            rm caido-cli.tar.gz
            echo 'Caido CLI installation completed'
        " 2>&1 | tee -a "${DEBUG_LOG}"
    else
        echo "✗ Failed to download Caido CLI (continuing without it)" | tee -a "${DEBUG_LOG}"
    fi
    
    debug_info "External packages installation completed"
}

install_github_packages() {
    echo "Installing Github packages..." | tee -a "${DEBUG_LOG}"
    debug_info "Starting GitHub packages installation"
    
    # Installing Wifite2
    echo "=== Installing Wifite2 ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Cloning Wifite2 repository...'
        git clone https://github.com/derv82/wifite2.git /usr/local/bin/.wifite2
        echo 'Creating symlinks...'
        ln -sf /usr/local/bin/.wifite2/Wifite.py /usr/local/bin/wifite
        ln -sf /usr/bin/python3 /usr/bin/python
        echo 'Wifite2 installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local wifite_exit_code=${PIPESTATUS[0]}
    if [ $wifite_exit_code -ne 0 ]; then
        echo "✗ Wifite2 installation failed with exit code: $wifite_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "Wifite2 installation failed"
        return $wifite_exit_code
    fi

    # Installing ffuf
    echo "=== Installing ffuf ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Downloading ffuf...'
        wget https://github.com/ffuf/ffuf/releases/download/v2.1.0/ffuf_2.1.0_linux_amd64.tar.gz -O /tmp/ffuf.tar.gz
        echo 'Creating directory and extracting...'
        mkdir -p /usr/local/bin/.ffuf
        tar -xf /tmp/ffuf.tar.gz -C /usr/local/bin/.ffuf ffuf
        echo 'Creating symlink...'
        ln -sf /usr/local/bin/.ffuf/ffuf /usr/local/bin/ffuf
        echo 'Cleaning up...'
        rm /tmp/ffuf.tar.gz
        echo 'ffuf installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local ffuf_exit_code=${PIPESTATUS[0]}
    if [ $ffuf_exit_code -ne 0 ]; then
        echo "✗ ffuf installation failed with exit code: $ffuf_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "ffuf installation failed"
        return $ffuf_exit_code
    fi

    # Installing gospider
    echo "=== Installing gospider ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Downloading gospider...'
        wget https://github.com/jaeles-project/gospider/releases/download/v1.1.6/gospider_v1.1.6_linux_x86_64.zip -O /tmp/gospider.zip
        echo 'Extracting...'
        unzip /tmp/gospider.zip -d /tmp/gospider
        echo 'Moving binary...'
        mv /tmp/gospider/gospider_v1.1.6_linux_x86_64/gospider /usr/local/bin/gospider
        echo 'Setting permissions...'
        chmod +x /usr/local/bin/gospider
        echo 'Cleaning up...'
        rm -rf /tmp/gospider /tmp/gospider.zip
        echo 'gospider installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local gospider_exit_code=${PIPESTATUS[0]}
    if [ $gospider_exit_code -ne 0 ]; then
        echo "✗ gospider installation failed with exit code: $gospider_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "gospider installation failed"
        return $gospider_exit_code
    fi

    # Installing dnsReaper
    echo "=== Installing dnsReaper ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Cloning dnsReaper repository...'
        git clone https://github.com/punk-security/dnsReaper.git /usr/local/bin/.dnsReaper
        echo 'Installing requirements...'
        cd /usr/local/bin/.dnsReaper
        pip install -r requirements.txt --break-system-packages
        echo 'Setting permissions and creating symlink...'
        chmod +x main.py
        ln -sf /usr/local/bin/.dnsReaper/main.py /usr/local/bin/dnsreaper
        echo 'dnsReaper installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local dnsreaper_exit_code=${PIPESTATUS[0]}
    if [ $dnsreaper_exit_code -ne 0 ]; then
        echo "✗ dnsReaper installation failed with exit code: $dnsreaper_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "dnsReaper installation failed"
        return $dnsreaper_exit_code
    fi

    # Installing jsluice
    echo "=== Installing jsluice ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Installing jsluice via go install...'
        go install -v github.com/BishopFox/jsluice/cmd/jsluice@latest
        echo 'Moving binary and creating symlink...'
        mv /root/go/bin/jsluice /usr/local/bin/.jsluice
        ln -sf /usr/local/bin/.jsluice /usr/local/bin/jsluice
        echo 'Cleaning up...'
        rm -rf /root/go
        echo 'jsluice installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local jsluice_exit_code=${PIPESTATUS[0]}
    if [ $jsluice_exit_code -ne 0 ]; then
        echo "✗ jsluice installation failed with exit code: $jsluice_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "jsluice installation failed"
        return $jsluice_exit_code
    fi

    # Installing shortscan
    echo "=== Installing shortscan ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Installing shortscan via go install...'
        go install -v github.com/bitquark/shortscan/cmd/shortscan@latest
        echo 'Moving binary...'
        mv /root/go/bin/shortscan /usr/local/bin/shortscan
        echo 'Cleaning up...'
        rm -rf /root/go
        echo 'shortscan installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local shortscan_exit_code=${PIPESTATUS[0]}
    if [ $shortscan_exit_code -ne 0 ]; then
        echo "✗ shortscan installation failed with exit code: $shortscan_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "shortscan installation failed"
        return $shortscan_exit_code
    fi

    # Installing CloudBrute
    echo "=== Installing CloudBrute ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Downloading CloudBrute...'
        wget https://github.com/0xsha/CloudBrute/releases/download/v1.0.7/cloudbrute_1.0.7_Linux_x86_64.tar.gz -O /tmp/cloudbrute.tar.gz
        echo 'Creating directory and extracting...'
        mkdir -p /usr/local/bin/.cloudbrute
        tar -xf /tmp/cloudbrute.tar.gz -C /usr/local/bin/.cloudbrute
        echo 'Creating symlink...'
        ln -sf /usr/local/bin/.cloudbrute/cloudbrute /usr/local/bin/cloudbrute
        echo 'Cleaning up...'
        rm /tmp/cloudbrute.tar.gz
        echo 'CloudBrute installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local cloudbrute_exit_code=${PIPESTATUS[0]}
    if [ $cloudbrute_exit_code -ne 0 ]; then
        echo "✗ CloudBrute installation failed with exit code: $cloudbrute_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "CloudBrute installation failed"
        return $cloudbrute_exit_code
    fi

    # Installing wafw00f
    echo "=== Installing wafw00f ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Installing wafw00f via pip for user ${USERNAME}...'
        su - ${USERNAME} -c 'pip install wafw00f --user --break-system-packages'
        echo 'Creating symlink...'
        ln -sf /home/${USERNAME}/.local/bin/wafw00f /usr/local/bin/wafw00f
        echo 'Setting permissions...'
        chmod +x /usr/local/bin/wafw00f
        echo 'wafw00f installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local wafw00f_exit_code=${PIPESTATUS[0]}
    if [ $wafw00f_exit_code -ne 0 ]; then
        echo "✗ wafw00f installation failed with exit code: $wafw00f_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "wafw00f installation failed"
        return $wafw00f_exit_code
    fi

    # Installing Arjun
    echo "=== Installing Arjun ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Installing Arjun via pip for user ${USERNAME}...'
        su - ${USERNAME} -c 'pip install arjun --user --break-system-packages'
        echo 'Creating symlink...'
        ln -sf /home/${USERNAME}/.local/bin/arjun /usr/local/bin/arjun
        echo 'Setting permissions...'
        chmod +x /usr/local/bin/arjun
        echo 'Arjun installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local arjun_exit_code=${PIPESTATUS[0]}
    if [ $arjun_exit_code -ne 0 ]; then
        echo "✗ Arjun installation failed with exit code: $arjun_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "Arjun installation failed"
        return $arjun_exit_code
    fi

    # Installing Corsy
    echo "=== Installing Corsy ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Cloning Corsy repository...'
        git clone https://github.com/s0md3v/Corsy.git /usr/local/bin/.corsy
        echo 'Installing requirements...'
        cd /usr/local/bin/.corsy
        pip install -r requirements.txt --break-system-packages
        echo 'Creating wrapper script...'
        echo '#!/bin/bash' > /usr/local/bin/corsy
        echo 'python3 /usr/local/bin/.corsy/corsy.py \"\$@\"' >> /usr/local/bin/corsy
        echo 'Setting permissions...'
        chmod +x /usr/local/bin/corsy
        echo 'Corsy installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local corsy_exit_code=${PIPESTATUS[0]}
    if [ $corsy_exit_code -ne 0 ]; then
        echo "✗ Corsy installation failed with exit code: $corsy_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "Corsy installation failed"
        return $corsy_exit_code
    fi

    # Installing FireProx and AWS CLI
    echo "=== Installing FireProx and AWS CLI ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Cloning FireProx repository...'
        git clone https://github.com/ustayready/fireprox /usr/local/bin/.fireprox
        echo 'Installing FireProx requirements...'
        cd /usr/local/bin/.fireprox
        pip3 install -r requirements.txt --break-system-packages
        echo 'Creating FireProx wrapper script...'
        echo '#!/bin/bash' > /usr/local/bin/fireprox
        echo 'python3 /usr/local/bin/.fireprox/fire.py \"\$@\"' >> /usr/local/bin/fireprox
        chmod +x /usr/local/bin/fireprox
        echo 'FireProx installation completed'
        
        echo 'Installing AWS CLI...'
        curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'
        unzip awscliv2.zip
        ./aws/install
        rm -rf aws awscliv2.zip
        echo 'AWS CLI installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    local fireprox_aws_exit_code=${PIPESTATUS[0]}
    if [ $fireprox_aws_exit_code -ne 0 ]; then
        echo "✗ FireProx/AWS CLI installation failed with exit code: $fireprox_aws_exit_code" | tee -a "${DEBUG_LOG}"
        debug_info "FireProx/AWS CLI installation failed"
        return $fireprox_aws_exit_code
    fi

    # Installing ronema (local)
    echo "=== Installing ronema (local) ===" | tee -a "${DEBUG_LOG}"
    sudo mkdir -p "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema" 2>&1 | tee -a "${DEBUG_LOG}"
    sudo cp -r "${PWD}/config/ronema/src"/* "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema/" 2>&1 | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Setting up ronema...'
        cp /home/${USERNAME}/.config/ronema/ronema /usr/local/bin/ronema
        cp /home/${USERNAME}/.config/ronema/roblma /usr/local/bin/roblma
        chmod +x /usr/local/bin/ronema
        chmod +x /usr/local/bin/roblma
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/ronema
        echo 'ronema installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"

    # Copying recon (local)
    echo "=== Installing recon (local) ===" | tee -a "${DEBUG_LOG}"
    sudo cp -r "../recon" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/.recon" 2>&1 | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Setting up recon...'
        chmod +x /usr/local/bin/.recon/recon.py
        ln -sf /usr/local/bin/.recon/recon.py /usr/local/bin/recon
        echo 'recon installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"

    # Copying infra (local)
    echo "=== Installing infra (local) ===" | tee -a "${DEBUG_LOG}"
    sudo cp "../infra/infra.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/infra.py" 2>&1 | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Setting up infra...'
        chmod +x /usr/local/bin/infra.py
        ln -sf /usr/local/bin/infra.py /usr/local/bin/infra
        echo 'Installing infra dependencies...'
        pip3 install cloudflare python-dotenv boto3 questionary botocore --break-system-packages
        echo 'infra installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"

    # Copying osint (local)
    echo "=== Installing osint (local) ===" | tee -a "${DEBUG_LOG}"
    sudo cp "../OSINT/osint.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/osint.py" 2>&1 | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Setting up osint...'
        chmod +x /usr/local/bin/osint.py
        ln -sf /usr/local/bin/osint.py /usr/local/bin/osint
        echo 'Installing osint dependencies...'
        pip3 install requests beautifulsoup4 cloudscraper --break-system-packages
        echo 'osint installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"

    # Installing bbot and configuring pipx path for mist user
    echo "=== Installing bbot ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Installing bbot via pipx for user mist...'
        su - mist -c 'pipx install bbot'
        echo 'bbot installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"

    # Installing Spiderfoot
    echo "=== Installing Spiderfoot ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Cloning Spiderfoot repository...'
        git clone https://github.com/smicallef/spiderfoot.git /usr/local/bin/.spiderfoot
        echo 'Installing Spiderfoot requirements...'
        cd /usr/local/bin/.spiderfoot
        pip3 install -r requirements.txt --break-system-packages
        echo 'Creating Spiderfoot wrapper script...'
        echo '#!/bin/bash' > /usr/local/bin/spiderfoot
        echo 'python3 /usr/local/bin/.spiderfoot/sf.py \"\$@\"' >> /usr/local/bin/spiderfoot
        chmod +x /usr/local/bin/spiderfoot
        echo 'Spiderfoot installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"

    # Installing RF-Lockpick (local)
    echo "=== Installing RF-Lockpick (local) ===" | tee -a "${DEBUG_LOG}"
    sudo cp -r "${PWD}/../RF-Lockpick" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/RF-Lockpick" 2>&1 | tee -a "${DEBUG_LOG}"
    sudo cp "${PWD}/config/system/rf_wrapper.sh" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/rf" 2>&1 | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Installing RF-Lockpick dependencies...'
        pip3 install flask flask-cors flask-socketio python-dotenv requests --break-system-packages
        echo 'Setting permissions...'
        chmod +x /usr/local/bin/rf
        echo 'RF-Lockpick installation completed'
    " 2>&1 | tee -a "${DEBUG_LOG}"

    # Ensure all users can access the installed tools
    echo "=== Setting final permissions ===" | tee -a "${DEBUG_LOG}"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        set -x
        echo 'Setting permissions for all tools...'
        chmod -R 755 /usr/local/bin
        echo 'All GitHub packages installation completed successfully'
    " 2>&1 | tee -a "${DEBUG_LOG}"
    
    echo "✓ All GitHub packages installed successfully" | tee -a "${DEBUG_LOG}"
    debug_info "GitHub packages installation completed"
}

configure_system() {
    echo "Configuring system..."
    local system_conf="${PWD}/config/system/system.conf"
    source "${system_conf}" >/dev/null 2>&1

    # Set hostname
    echo "${HOSTNAME}" | sudo tee "${LIVE_BOOT_DIR}/chroot/etc/hostname"
    echo "${HOSTS}" | sudo tee "${LIVE_BOOT_DIR}/chroot/etc/hosts"
    echo "export DISPLAY=:0" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/etc/profile.d/display.sh"

    # Configure paths for all users
    echo "PATH=$PATH:${PATH_APPEND}" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/etc/environment"

    # Create all required directories
    for dir in "${DIRECTORIES[@]}"; do
        sudo mkdir -p "${LIVE_BOOT_DIR}/chroot${dir}"
    done
    
    # Configure LightDM and Awesome WM
    echo "${LIGHTDM_CONF}" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/etc/lightdm/lightdm.conf"
    sudo sed -i 's/^#greeter-session=.*/greeter-session=nody-greeter/g' "${LIVE_BOOT_DIR}/chroot/etc/lightdm/lightdm.conf"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        sed -i 's/^[[:space:]]*theme:[[:space:]]*.*$/    theme: sechorda/' /etc/lightdm/web-greeter.yml
    "

    # Set GTK theme
    sudo mkdir -p "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/gtk-3.0"
    echo "${GTK_THEME}" | sudo tee "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/gtk-3.0/settings.ini"
    
    # Set Firefox ESR as default browser
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        xdg-settings set default-web-browser firefox-esr.desktop
    "

    # Copy configuration files
    for file in "${FILES_TO_COPY[@]}"; do
        IFS=':' read -r src dst <<< "${file}"
        sudo cp "${src}" "${LIVE_BOOT_DIR}/chroot${dst}"
    done

    # Copy/unzip directories
    for dir in "${DIRS_TO_COPY[@]}"; do
        IFS=':' read -r src dst <<< "${dir}"
        if [[ "${src}" == *.tar.gz ]]; then
            sudo mkdir -p "${LIVE_BOOT_DIR}/chroot${dst}"
            sudo tar -xzf "${src}" -C "${LIVE_BOOT_DIR}/chroot${dst}"
        else
            sudo cp -r "${src}" "${LIVE_BOOT_DIR}/chroot${dst}"
        fi
    done

    # Hide rofi entries
    for app in nody-greeter lstopo picom systemsettings kdesystemsettings install-debian; do 
        echo "NoDisplay=true" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/usr/share/applications/${app}.desktop"
    done

    # Configure bash settings for mist user
    echo "${BASH_CONFIG}" | sudo tee "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.bashrc"
    echo "mist ALL=(ALL) NOPASSWD: ALL" | sudo chroot "${LIVE_BOOT_DIR}/chroot" tee -a /etc/sudoers.d/mist

    # Set correct ownership and permissions
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config /home/${USERNAME}/secos-vault
        $(printf '%s\n' "${PERMISSIONS[@]}")
    "

    # Configure and generate locales
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        sed -i 's/# ${LOCALE} UTF-8/${LOCALE} UTF-8/' /etc/locale.gen
        locale-gen ${LOCALE} >/dev/null 2>&1
        update-locale LANG=${LOCALE} LC_ALL=${LOCALE} LANGUAGE=${LOCALE%.*}
        ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
        echo '${TIMEZONE}' > /etc/timezone
        dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
    "
    
    # Clean up unnecessary packages
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        apt-get autoremove -y >/dev/null 2>&1
        apt-get clean >/dev/null 2>&1
    "        
}

create_filesystem() {
    echo "Creating filesystem..."
    mkdir -p "${LIVE_BOOT_DIR}"/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp/grub-embed}
    sudo mksquashfs "${LIVE_BOOT_DIR}/chroot" "${LIVE_BOOT_DIR}/staging/live/filesystem.squashfs"

    cp "${LIVE_BOOT_DIR}/chroot/boot"/vmlinuz-* "${LIVE_BOOT_DIR}/staging/live/vmlinuz"
    cp "${LIVE_BOOT_DIR}/chroot/boot"/initrd.img-* "${LIVE_BOOT_DIR}/staging/live/initrd"
}

configure_boot_loaders() {
    echo "Configuring boot loaders..."
    # Copy isolinux config
    sudo cp "${PWD}/config/system/isolinux.cfg" "${LIVE_BOOT_DIR}/staging/isolinux/isolinux.cfg"

    # Copy grub config
    sudo cp "${PWD}/config/system/grub.cfg" "${LIVE_BOOT_DIR}/staging/boot/grub/grub.cfg"
    sudo cp "${LIVE_BOOT_DIR}/staging/boot/grub/grub.cfg" "${LIVE_BOOT_DIR}/staging/EFI/BOOT/"
    sudo cp "${PWD}/config/system/grub-early.cfg" "${LIVE_BOOT_DIR}/tmp/grub-embed/grub-early.cfg"
    
    # Staging
    cp /usr/lib/ISOLINUX/isolinux.bin "${LIVE_BOOT_DIR}/staging/isolinux/"
    cp /usr/lib/syslinux/modules/bios/* "${LIVE_BOOT_DIR}/staging/isolinux/"
    cp -r /usr/lib/grub/x86_64-efi/* "${LIVE_BOOT_DIR}/staging/boot/grub/x86_64-efi/"
}

create_efi_images() {
    echo "Creating EFI images..."
    grub-mkstandalone -O i386-efi --modules="part_gpt part_msdos fat iso9660" --locales="" --themes="" --fonts="" \
        --output="${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" "boot/grub/grub.cfg=${LIVE_BOOT_DIR}/tmp/grub-embed/grub-early.cfg" >/dev/null 2>&1

    grub-mkstandalone -O x86_64-efi --modules="part_gpt part_msdos fat iso9660" --locales="" --themes="" --fonts="" \
        --output="${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTx64.EFI" "boot/grub/grub.cfg=${LIVE_BOOT_DIR}/tmp/grub-embed/grub-early.cfg" >/dev/null 2>&1
}

create_uefi_boot_image() {
    echo "Creating UEFI boot image..."
    cd "${LIVE_BOOT_DIR}/staging"
    dd if=/dev/zero of=efiboot.img bs=1M count=20 >/dev/null 2>&1
    mkfs.vfat efiboot.img >/dev/null 2>&1
    mmd -i efiboot.img ::/EFI ::/EFI/BOOT >/dev/null 2>&1
    mcopy -vi efiboot.img "${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" "${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTx64.EFI" "${LIVE_BOOT_DIR}/staging/boot/grub/grub.cfg" ::/EFI/BOOT/ >/dev/null 2>&1
    cd - >/dev/null
}

create_iso() {
    echo "Creating ISO and VMDK..."
    # Create ISO
    xorriso -as mkisofs -iso-level 3 -o "${ISO_NAME}" -full-iso9660-filenames \
        -volid "SECOS" --mbr-force-bootable -partition_offset 16 \
        -joliet -joliet-long -rational-rock -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -eltorito-boot isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
        --eltorito-catalog isolinux/isolinux.cat \
        -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot -isohybrid-gpt-basdat \
        -append_partition 2 0xef "${LIVE_BOOT_DIR}/staging/efiboot.img" \
        "${LIVE_BOOT_DIR}/staging"

    # Convert ISO to VMDK using QEMU
    local VMDK_NAME="secOS.vmdk"
    qemu-img convert -f raw -O vmdk "${ISO_NAME}" "${VMDK_NAME}"
}
    
main() {
    # Check and remove existing temporary directory if it exists
    if [ -d "${LIVE_BOOT_DIR}" ]; then
        sudo rm -rf "${LIVE_BOOT_DIR}"
    fi
    
    echo "Starting secOS build process..."
    
    setup_build_env
    bootstrap_debian
    install_kernel_and_packages
    install_github_packages    
    configure_system
    create_filesystem
    configure_boot_loaders
    create_efi_images
    create_uefi_boot_image
    create_iso
    
    echo "Build complete!"
}

main
