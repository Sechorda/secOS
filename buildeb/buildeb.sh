#!/usr/bin/env bash

set -e  # Exit immediately if a command exits with a non-zero status

trap 'rm -rf "${LIVE_BOOT_DIR}"' EXIT  # Clean up on exit

echo "=== Starting secOS Build Process ==="

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
    firefox-esr kitty spotify-client vim nmap hashcat hydra netcat-openbsd lightdm awesome compton rofi proxychains kismet calamares
    # Dependencies
    sudo git golang-go python3 python3-pip pipx python3-setuptools unzip pciutils wget tar dpkg locales tzdata curl gpg
    network-manager net-tools network-manager-gnome wpasupplicant wireless-tools dnsutils aircrack-ng iputils-ping iproute2
    firmware-linux-nonfree firmware-iwlwifi xorg xserver-xorg xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-all alsa-utils playerctl
    gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev
    libxcb1-dev libx11-dev libnss3-tools libxft-dev libxrandr-dev libxpm-dev uthash-dev os-prober kpackagetool5 libkf5configcore5 libkf5coreaddons5 libkf5package5 libkf5parts5 
    libkpmcore12 libparted2 libpwquality1 libqt5dbus5 libqt5gui5 libqt5network5 libqt5qml5 libqt5quick5 libqt5svg5 libqt5widgets5 libqt5xml5 libstdc++6
    qml-module-qtquick2 qml-module-qtquick-controls qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-window2 python3-yaml 
    udisks2 dosfstools e2fsprogs btrfs-progs xfsprogs squashfs-tools grub-efi-amd64 tcpdump hostapd hcxdumptool bluez nemo
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
    echo "Installing kernel and packages..."
    
    # Create user
    echo "Creating user ${USERNAME}..."
    if sudo chroot "${LIVE_BOOT_DIR}/chroot" useradd -m -s /bin/bash "${USERNAME}" >/dev/null 2>&1; then
        echo "✓ User ${USERNAME} created successfully"
    else
        echo "✗ Failed to create user ${USERNAME}"
        return 1
    fi
    
    # Set passwords
    echo "Setting user passwords..."
    echo "${USERNAME}:live" | sudo chroot "${LIVE_BOOT_DIR}/chroot" chpasswd >/dev/null 2>&1
    sudo chroot "${LIVE_BOOT_DIR}/chroot" usermod -aG sudo "${USERNAME}" >/dev/null 2>&1
    echo 'root:live' | sudo chroot "${LIVE_BOOT_DIR}/chroot" chpasswd >/dev/null 2>&1
    
    # Configure repositories
    echo "Configuring repositories..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list" >/dev/null 2>&1
    
    # Install basic tools first
    echo "Installing basic tools (curl, gpg)..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && apt-get update >/dev/null 2>&1 && apt-get install -y curl gpg >/dev/null 2>&1"
    
    if [ $? -eq 0 ]; then
        echo "✓ Basic tools installed successfully"
    else
        echo "✗ Failed to install basic tools"
        return 1
    fi
    
    # Add external repositories
    echo "Adding external repositories..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        # Spotify repository
        if curl -f -sS --connect-timeout 30 https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/spotify.gpg 2>/dev/null; then
            echo 'deb http://repository.spotify.com stable non-free' > /etc/apt/sources.list.d/spotify.list
        fi
        
        # Kismet repository
        if curl -f -sS --connect-timeout 30 https://www.kismetwireless.net/repos/kismet-release.gpg.key | gpg --dearmor > /usr/share/keyrings/kismet-archive-keyring.gpg 2>/dev/null; then
            echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' > /etc/apt/sources.list.d/kismet.list
        fi
    " >/dev/null 2>&1
    
    # Update package lists
    echo "Updating package lists..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && apt-get clean >/dev/null 2>&1 && apt-get update >/dev/null 2>&1"
    
    # Install kernel first (most critical)
    echo "Installing Linux kernel..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && \
        apt-get --yes --quiet -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" install linux-image-amd64 live-boot systemd-sysv >/dev/null 2>&1"
    
    local kernel_exit_code=$?
    if [ $kernel_exit_code -eq 0 ]; then
        echo "✓ Kernel installed successfully"
    else
        echo "✗ Kernel installation failed with exit code: $kernel_exit_code"
        return $kernel_exit_code
    fi
    
    # Install all packages from CUSTOM_PROGRAMS array
    echo "Installing all packages..."
    
    # Install packages with graceful failure handling
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && \
        apt-get --yes --quiet -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" install ${CUSTOM_PROGRAMS[*]} >/dev/null 2>&1"
    
    local packages_exit_code=$?
    if [ $packages_exit_code -eq 0 ]; then
        echo "✓ All packages installed successfully"
    else
        echo "✗ Some packages installation failed, but continuing..."
    fi
    
    # External package installations
    install_external_packages
}

install_external_packages() {
    echo "Installing external packages..."
    
    # Nody-Greeter install
    echo "Installing Nody-Greeter..."
    if sudo wget --timeout=30 -q -O "${LIVE_BOOT_DIR}/chroot/tmp/nody-greeter.deb" "$NODY_GREETER_URL" >/dev/null 2>&1; then
        echo "✓ Nody-Greeter downloaded successfully"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            dpkg -i /tmp/nody-greeter.deb >/dev/null 2>&1
            rm /tmp/nody-greeter.deb
        " >/dev/null 2>&1
    else
        echo "✗ Failed to download Nody-Greeter"
    fi

    # Obsidian install
    echo "Installing Obsidian..."
    if sudo wget --timeout=30 -q -O "${LIVE_BOOT_DIR}/chroot/tmp/obsidian.deb" "$OBSIDIAN_URL" >/dev/null 2>&1; then
        echo "✓ Obsidian downloaded successfully"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            dpkg -i /tmp/obsidian.deb >/dev/null 2>&1 || apt-get install -f -y >/dev/null 2>&1
            ln -sf /opt/Obsidian/obsidian /usr/local/bin/obsidian >/dev/null 2>&1
            rm /tmp/obsidian.deb
        " >/dev/null 2>&1
    else
        echo "✗ Failed to download Obsidian"
    fi

    # Caido CLI install
    echo "Installing Caido CLI..."
    if sudo wget --timeout=30 -q -O "${LIVE_BOOT_DIR}/chroot/tmp/caido-cli.tar.gz" "$CAIDO_URL" >/dev/null 2>&1; then
        echo "✓ Caido CLI downloaded successfully"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            cd /tmp &&
            tar -xzf caido-cli.tar.gz >/dev/null 2>&1 &&
            mv caido-cli /usr/local/bin/caido-cli &&
            chmod +x /usr/local/bin/caido-cli &&
            rm caido-cli.tar.gz
        " >/dev/null 2>&1
    else
        echo "✗ Failed to download Caido CLI"
    fi
}

install_github_packages() {
    echo "Installing GitHub packages..."
    
    # Installing Wifite2
    echo "Installing Wifite2..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/derv82/wifite2.git /usr/local/bin/.wifite2 >/dev/null 2>&1
        ln -sf /usr/local/bin/.wifite2/Wifite.py /usr/local/bin/wifite
        ln -sf /usr/bin/python3 /usr/bin/python
    " >/dev/null 2>&1

    # Installing ffuf
    echo "Installing ffuf..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        wget https://github.com/ffuf/ffuf/releases/download/v2.1.0/ffuf_2.1.0_linux_amd64.tar.gz -O /tmp/ffuf.tar.gz >/dev/null 2>&1
        mkdir -p /usr/local/bin/.ffuf
        tar -xf /tmp/ffuf.tar.gz -C /usr/local/bin/.ffuf ffuf >/dev/null 2>&1
        ln -sf /usr/local/bin/.ffuf/ffuf /usr/local/bin/ffuf
        rm /tmp/ffuf.tar.gz
    " >/dev/null 2>&1

    # Installing gospider
    echo "Installing gospider..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        wget https://github.com/jaeles-project/gospider/releases/download/v1.1.6/gospider_v1.1.6_linux_x86_64.zip -O /tmp/gospider.zip >/dev/null 2>&1
        unzip /tmp/gospider.zip -d /tmp/gospider >/dev/null 2>&1
        mv /tmp/gospider/gospider_v1.1.6_linux_x86_64/gospider /usr/local/bin/gospider
        chmod +x /usr/local/bin/gospider
        rm -rf /tmp/gospider /tmp/gospider.zip
    " >/dev/null 2>&1

    # Installing dnsReaper
    echo "Installing dnsReaper..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/punk-security/dnsReaper.git /usr/local/bin/.dnsReaper >/dev/null 2>&1
        cd /usr/local/bin/.dnsReaper
        pip install -r requirements.txt --break-system-packages >/dev/null 2>&1
        chmod +x main.py
        ln -sf /usr/local/bin/.dnsReaper/main.py /usr/local/bin/dnsreaper
    " >/dev/null 2>&1

    # Installing jsluice
    echo "Installing jsluice..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        go install -v github.com/BishopFox/jsluice/cmd/jsluice@latest >/dev/null 2>&1
        mv /root/go/bin/jsluice /usr/local/bin/.jsluice
        ln -sf /usr/local/bin/.jsluice /usr/local/bin/jsluice
        rm -rf /root/go
    " >/dev/null 2>&1

    # Installing shortscan
    echo "Installing shortscan..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        go install -v github.com/bitquark/shortscan/cmd/shortscan@latest >/dev/null 2>&1
        mv /root/go/bin/shortscan /usr/local/bin/shortscan
        rm -rf /root/go
    " >/dev/null 2>&1

    # Installing CloudBrute
    echo "Installing CloudBrute..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        wget https://github.com/0xsha/CloudBrute/releases/download/v1.0.7/cloudbrute_1.0.7_Linux_x86_64.tar.gz -O /tmp/cloudbrute.tar.gz >/dev/null 2>&1
        mkdir -p /usr/local/bin/.cloudbrute
        tar -xf /tmp/cloudbrute.tar.gz -C /usr/local/bin/.cloudbrute >/dev/null 2>&1
        ln -sf /usr/local/bin/.cloudbrute/cloudbrute /usr/local/bin/cloudbrute
        rm /tmp/cloudbrute.tar.gz
    " >/dev/null 2>&1

    # Installing wafw00f and Arjun via pip
    echo "Installing wafw00f and Arjun..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        su - ${USERNAME} -c 'pip install wafw00f arjun --user --break-system-packages' >/dev/null 2>&1
        ln -sf /home/${USERNAME}/.local/bin/wafw00f /usr/local/bin/wafw00f
        ln -sf /home/${USERNAME}/.local/bin/arjun /usr/local/bin/arjun
        chmod +x /usr/local/bin/wafw00f /usr/local/bin/arjun
    " >/dev/null 2>&1

    # Installing Corsy
    echo "Installing Corsy..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/s0md3v/Corsy.git /usr/local/bin/.corsy >/dev/null 2>&1
        cd /usr/local/bin/.corsy
        pip install -r requirements.txt --break-system-packages >/dev/null 2>&1
        echo '#!/bin/bash' > /usr/local/bin/corsy
        echo 'python3 /usr/local/bin/.corsy/corsy.py \"\$@\"' >> /usr/local/bin/corsy
        chmod +x /usr/local/bin/corsy
    " >/dev/null 2>&1

    # Installing FireProx and AWS CLI
    echo "Installing FireProx and AWS CLI..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/ustayready/fireprox /usr/local/bin/.fireprox >/dev/null 2>&1
        cd /usr/local/bin/.fireprox
        pip3 install -r requirements.txt --break-system-packages >/dev/null 2>&1
        echo '#!/bin/bash' > /usr/local/bin/fireprox
        echo 'python3 /usr/local/bin/.fireprox/fire.py \"\$@\"' >> /usr/local/bin/fireprox
        chmod +x /usr/local/bin/fireprox
        
        curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' >/dev/null 2>&1
        unzip awscliv2.zip >/dev/null 2>&1
        ./aws/install >/dev/null 2>&1
        rm -rf aws awscliv2.zip
    " >/dev/null 2>&1

    # Installing local tools
    echo "Installing local tools..."
    
    # ronema
    sudo mkdir -p "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema" >/dev/null 2>&1
    sudo cp -r "${PWD}/config/ronema/src"/* "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema/" >/dev/null 2>&1
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        cp /home/${USERNAME}/.config/ronema/ronema /usr/local/bin/ronema
        cp /home/${USERNAME}/.config/ronema/roblma /usr/local/bin/roblma
        chmod +x /usr/local/bin/ronema /usr/local/bin/roblma
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/ronema
    " >/dev/null 2>&1

    # recon
    sudo cp -r "../recon" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/.recon" >/dev/null 2>&1
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod +x /usr/local/bin/.recon/recon.py
        ln -sf /usr/local/bin/.recon/recon.py /usr/local/bin/recon
    " >/dev/null 2>&1

    # infra
    sudo cp "../infra/infra.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/infra.py" >/dev/null 2>&1
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod +x /usr/local/bin/infra.py
        ln -sf /usr/local/bin/infra.py /usr/local/bin/infra
        pip3 install cloudflare python-dotenv boto3 questionary botocore --break-system-packages >/dev/null 2>&1
    " >/dev/null 2>&1

    # osint
    sudo cp "../OSINT/osint.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/osint.py" >/dev/null 2>&1
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod +x /usr/local/bin/osint.py
        ln -sf /usr/local/bin/osint.py /usr/local/bin/osint
        pip3 install requests beautifulsoup4 cloudscraper --break-system-packages >/dev/null 2>&1
    " >/dev/null 2>&1

    # bbot
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        su - mist -c 'pipx install bbot' >/dev/null 2>&1
    " >/dev/null 2>&1

    # Spiderfoot
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/smicallef/spiderfoot.git /usr/local/bin/.spiderfoot >/dev/null 2>&1
        cd /usr/local/bin/.spiderfoot
        pip3 install -r requirements.txt --break-system-packages >/dev/null 2>&1
        echo '#!/bin/bash' > /usr/local/bin/spiderfoot
        echo 'python3 /usr/local/bin/.spiderfoot/sf.py \"\$@\"' >> /usr/local/bin/spiderfoot
        chmod +x /usr/local/bin/spiderfoot
    " >/dev/null 2>&1

    # RF-Lockpick
    sudo cp -r "${PWD}/../RF-Lockpick" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/RF-Lockpick" >/dev/null 2>&1
    sudo cp "${PWD}/config/system/rf_wrapper.sh" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/rf" >/dev/null 2>&1
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        pip3 install flask flask-cors flask-socketio python-dotenv requests --break-system-packages >/dev/null 2>&1
        chmod +x /usr/local/bin/rf
    " >/dev/null 2>&1

    # Set final permissions
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod -R 755 /usr/local/bin
    " >/dev/null 2>&1
    
    echo "✓ GitHub packages installation completed"
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
