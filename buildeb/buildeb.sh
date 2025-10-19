#!/usr/bin/env bash

# Constants
DEBIAN_MIRROR="http://ftp.us.debian.org/debian/"
NODY_GREETER_URL="https://github.com/JezerM/nody-greeter/releases/download/1.6.2/nody-greeter-1.6.2-debian.deb"
OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.7.4/obsidian_1.7.4_amd64.deb"
CAIDO_URL="https://caido.download/releases/v0.42.0/caido-cli-v0.42.0-linux-x86_64.tar.gz"

ISO_NAME="secOS.iso"
USERNAME="mist"

CUSTOM_PROGRAMS=(
    # Dev
    openssh-server
    # Packages
    firefox-esr kitty spotify-client vim nmap hashcat hydra netcat-openbsd lightdm awesome compton rofi proxychains calamares
    # Dependencies (including build/development packages required for building Kismet)
    sudo git golang-go python3 python3-pip pipx python3-setuptools unzip pciutils wget tar dpkg locales tzdata curl gpg
    network-manager net-tools network-manager-gnome wpasupplicant wireless-tools dnsutils aircrack-ng iputils-ping iproute2
    firmware-linux-nonfree firmware-iwlwifi xorg xserver-xorg xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-all alsa-utils playerctl
    gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev
    libxcb1-dev libx11-dev libnss3-tools libxft-dev libxrandr-dev libxpm-dev uthash-dev os-prober kpackagetool5 libkf5configcore5 libkf5coreaddons5 libkf5package5 libkf5parts5 
    libkpmcore12 libparted2 libpwquality1 libqt5dbus5 libqt5gui5 libqt5network5 libqt5qml5 libqt5quick5 libqt5svg5 libqt5widgets5 libqt5xml5 libstdc++6
    qml-module-qtquick2 qml-module-qtquick-controls qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-window2 python3-yaml 
    udisks2 dosfstools e2fsprogs btrfs-progs xfsprogs squashfs-tools grub-efi-amd64 tcpdump hostapd hcxdumptool bluez kismet
)

bootstrap_debian() {
    echo "Bootstrapping Debian..."
    LIVE_BOOT_DIR="${PWD}/LIVE_BOOT"
    mkdir -p "${LIVE_BOOT_DIR}"
    sudo debootstrap --arch=amd64 --variant=minbase stable \
        "${LIVE_BOOT_DIR}/chroot" "${DEBIAN_MIRROR}"

    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "useradd -m -s /bin/bash ${USERNAME} && echo '${USERNAME}:live' | chpasswd && usermod -aG sudo ${USERNAME} && echo 'root:live' | chpasswd && export DEBIAN_FRONTEND=noninteractive"
    
    # Add Spotify repository (refresh package lists)
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
        apt-get update
        apt-get install -y curl gnupg
        echo 'deb http://repository.spotify.com stable non-free' > /etc/apt/sources.list.d/spotify.list
        curl -fL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/spotify.gpg
        curl -sS https://www.kismetwireless.net/repos/kismet-release.gpg.key | gpg --dearmor | tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
        echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/trixie trixie main' | tee /etc/apt/sources.list.d/kismet.list >/dev/null

        apt-get update
    "
}

install_kernel_and_packages() {
    echo "Installing kernel and packages..."
    
    # Install kernel
    echo "Installing Linux kernel..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && \
        apt-get --yes -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" install linux-image-amd64 live-boot systemd-sysv"
    
    # Install all packages from CUSTOM_PROGRAMS array
    echo "Installing APT packages..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
        "export DEBIAN_FRONTEND=noninteractive && \
        apt-get --yes -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" \
        install ${CUSTOM_PROGRAMS[*]} && \
        apt-get --yes -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" --no-install-recommends install nemo"
}

install_external_packages() {
    echo "Installing external packages..."
    
    # Installing Wifite2
    echo "Installing Wifite2..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/derv82/wifite2.git /usr/local/bin/.wifite2
        ln -sf /usr/local/bin/.wifite2/Wifite.py /usr/local/bin/wifite
        ln -sf /usr/bin/python3 /usr/bin/python
    "

    # Installing ffuf
    echo "Installing ffuf..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        wget https://github.com/ffuf/ffuf/releases/download/v2.1.0/ffuf_2.1.0_linux_amd64.tar.gz -O /tmp/ffuf.tar.gz
        mkdir -p /usr/local/bin/.ffuf
        tar -xf /tmp/ffuf.tar.gz -C /usr/local/bin/.ffuf ffuf
        ln -sf /usr/local/bin/.ffuf/ffuf /usr/local/bin/ffuf
        rm /tmp/ffuf.tar.gz
    "

    # Installing gospider
    echo "Installing gospider..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        wget https://github.com/jaeles-project/gospider/releases/download/v1.1.6/gospider_v1.1.6_linux_x86_64.zip -O /tmp/gospider.zip
        unzip /tmp/gospider.zip -d /tmp/gospider
        mv /tmp/gospider/gospider_v1.1.6_linux_x86_64/gospider /usr/local/bin/gospider
        chmod +x /usr/local/bin/gospider
        rm -rf /tmp/gospider /tmp/gospider.zip
    "

    # Installing dnsReaper
    echo "Installing dnsReaper..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/punk-security/dnsReaper.git /usr/local/bin/.dnsReaper
        cd /usr/local/bin/.dnsReaper
        pip install -r requirements.txt --break-system-packages
        chmod +x main.py
        ln -sf /usr/local/bin/.dnsReaper/main.py /usr/local/bin/dnsreaper
    "

    # Installing jsluice
    echo "Installing jsluice..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        export GOROOT=/usr/lib/go
        export GOPATH=/root/go
        export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin
        go install github.com/BishopFox/jsluice/cmd/jsluice@latest >/dev/null 2>&1 || true
        mv /root/go/bin/jsluice /usr/local/bin/.jsluice || true
        ln -sf /usr/local/bin/.jsluice /usr/local/bin/jsluice
        rm -rf /root/go
        umount /proc || true
    "

    # Installing shortscan
    echo "Installing shortscan..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        export GOROOT=/usr/lib/go
        export GOPATH=/root/go
        export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin
        go install github.com/bitquark/shortscan/cmd/shortscan@latest >/dev/null 2>&1 || true
        mv /root/go/bin/shortscan /usr/local/bin/shortscan || true
        rm -rf /root/go
        umount /proc || true
    "

    # Installing CloudBrute
    echo "Installing CloudBrute..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        wget https://github.com/0xsha/CloudBrute/releases/download/v1.0.7/cloudbrute_1.0.7_Linux_x86_64.tar.gz -O /tmp/cloudbrute.tar.gz
        mkdir -p /usr/local/bin/.cloudbrute
        tar -xf /tmp/cloudbrute.tar.gz -C /usr/local/bin/.cloudbrute
        ln -sf /usr/local/bin/.cloudbrute/cloudbrute /usr/local/bin/cloudbrute
        rm /tmp/cloudbrute.tar.gz
    "

    # Installing wafw00f and Arjun via pip
    echo "Installing wafw00f and Arjun..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        su - ${USERNAME} -c 'pip install wafw00f arjun --user --break-system-packages'
        ln -sf /home/${USERNAME}/.local/bin/wafw00f /usr/local/bin/wafw00f
        ln -sf /home/${USERNAME}/.local/bin/arjun /usr/local/bin/arjun
        chmod +x /usr/local/bin/wafw00f /usr/local/bin/arjun
    "

    # Installing Corsy
    echo "Installing Corsy..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/s0md3v/Corsy.git /usr/local/bin/.corsy
        cd /usr/local/bin/.corsy
        pip install -r requirements.txt --break-system-packages
        echo '#!/bin/bash' > /usr/local/bin/corsy
        echo 'python3 /usr/local/bin/.corsy/corsy.py \"\$@\"' >> /usr/local/bin/corsy
        chmod +x /usr/local/bin/corsy
    "

    # Installing FireProx and AWS CLI
    echo "Installing FireProx and AWS CLI..."
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/ustayready/fireprox /usr/local/bin/.fireprox
        cd /usr/local/bin/.fireprox
        pip3 install -r requirements.txt --break-system-packages
        echo '#!/bin/bash' > /usr/local/bin/fireprox
        echo 'python3 /usr/local/bin/.fireprox/fire.py \"\$@\"' >> /usr/local/bin/fireprox
        chmod +x /usr/local/bin/fireprox
        
        curl -fL 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'
        unzip awscliv2.zip
        ./aws/install
        rm -rf aws awscliv2.zip
    "
    
    # ronema
    sudo mkdir -p "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema"
    sudo cp -r "${PWD}/config/ronema/src"/* "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema/"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        cp /home/${USERNAME}/.config/ronema/ronema /usr/local/bin/ronema
        cp /home/${USERNAME}/.config/ronema/roblma /usr/local/bin/roblma
        chmod +x /usr/local/bin/ronema /usr/local/bin/roblma
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/ronema
    "

    # recon
    sudo cp -r "../recon" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/.recon"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod +x /usr/local/bin/.recon/recon.py
        ln -sf /usr/local/bin/.recon/recon.py /usr/local/bin/recon
    "

    # infra
    sudo cp "../infra/infra.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/infra.py"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod +x /usr/local/bin/infra.py
        ln -sf /usr/local/bin/infra.py /usr/local/bin/infra
        pip3 install cloudflare python-dotenv boto3 questionary botocore --break-system-packages
    "

    # osint
    sudo cp "../OSINT/osint.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/osint.py"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod +x /usr/local/bin/osint.py
        ln -sf /usr/local/bin/osint.py /usr/local/bin/osint
        pip3 install requests beautifulsoup4 cloudscraper --break-system-packages
    "

    # bbot
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        su - mist -c 'pipx install bbot'
    "

    # Spiderfoot
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        git clone https://github.com/smicallef/spiderfoot.git /usr/local/bin/.spiderfoot
        cd /usr/local/bin/.spiderfoot
        pip3 install -r requirements.txt --break-system-packages
        echo '#!/bin/bash' > /usr/local/bin/spiderfoot
        echo 'python3 /usr/local/bin/.spiderfoot/sf.py \"\$@\"' >> /usr/local/bin/spiderfoot
        chmod +x /usr/local/bin/spiderfoot
    "

    # RF-Lockpick
    sudo cp -r "${PWD}/../RF-Lockpick" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/RF-Lockpick"
    sudo cp "${PWD}/config/system/rf_wrapper.sh" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/rf"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        pip3 install flask flask-cors flask-socketio python-dotenv requests --break-system-packages
        chmod +x /usr/local/bin/rf
    "

    # Set final permissions
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        chmod -R 755 /usr/local/bin
    "
    
    # Nody-Greeter install
    echo "Installing Nody-Greeter..."
    sudo wget --timeout=30 -O "${LIVE_BOOT_DIR}/chroot/tmp/nody-greeter.deb" "$NODY_GREETER_URL"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        dpkg -i /tmp/nody-greeter.deb || true
        rm -f /tmp/nody-greeter.deb
    "

    # Obsidian install
    echo "Installing Obsidian..."
    sudo wget --timeout=30 -O "${LIVE_BOOT_DIR}/chroot/tmp/obsidian.deb" "$OBSIDIAN_URL"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        dpkg -i /tmp/obsidian.deb || apt-get install -f -y
        ln -sf /opt/Obsidian/obsidian /usr/local/bin/obsidian
        rm -f /tmp/obsidian.deb
    "

    # Caido CLI install
    echo "Installing Caido CLI..."
    sudo wget --timeout=30 -O "${LIVE_BOOT_DIR}/chroot/tmp/caido-cli.tar.gz" "$CAIDO_URL"
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        cd /tmp &&
        tar -xzf caido-cli.tar.gz &&
        mv caido-cli /usr/local/bin/caido-cli &&
        chmod +x /usr/local/bin/caido-cli &&
        rm -f caido-cli.tar.gz
    "
}

configure_system() {
    echo "Configuring system..."
    local system_conf="${PWD}/config/system/system.conf"
    source "${system_conf}"

    # Set hostname
    echo "${HOSTNAME}" | sudo tee "${LIVE_BOOT_DIR}/chroot/etc/hostname"
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
        locale-gen ${LOCALE}
        update-locale LANG=${LOCALE} LC_ALL=${LOCALE} LANGUAGE=${LOCALE%.*}
        ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
        echo '${TIMEZONE}' > /etc/timezone
        dpkg-reconfigure -f noninteractive tzdata
    "
    
    # Clean up unnecessary packages
    sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
        apt-get autoremove -y
        apt-get clean
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
        --output="${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" "boot/grub/grub.cfg=${LIVE_BOOT_DIR}/tmp/grub-embed/grub-early.cfg"

    grub-mkstandalone -O x86_64-efi --modules="part_gpt part_msdos fat iso9660" --locales="" --themes="" --fonts="" \
        --output="${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTx64.EFI" "boot/grub/grub.cfg=${LIVE_BOOT_DIR}/tmp/grub-embed/grub-early.cfg"
}

create_uefi_boot_image() {
    echo "Creating UEFI boot image..."
    cd "${LIVE_BOOT_DIR}/staging"
    dd if=/dev/zero of=efiboot.img bs=1M count=20
    mkfs.vfat efiboot.img
    mmd -i efiboot.img ::/EFI ::/EFI/BOOT
    mcopy -vi efiboot.img "${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" "${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTx64.EFI" "${LIVE_BOOT_DIR}/staging/boot/grub/grub.cfg" ::/EFI/BOOT/
    cd -
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
    echo "Starting secOS build process..."
    
    bootstrap_debian
    install_kernel_and_packages
    install_external_packages
    configure_system
    create_filesystem
    configure_boot_loaders
    create_efi_images
    create_uefi_boot_image
    create_iso
    
    echo "Build complete!"
}

main
