#!/usr/bin/env bash

set -e  # Exit immediately if a command exits with a non-zero status
trap 'rm -rf "${LIVE_BOOT_DIR}"' EXIT  # Clean up on exit
start_time=$(date +%s)

print_centered_ascii_art() {
    local IFS=$'\n'
    local lines=($(cat << "EOF"                                                                                                                                                                     
                        ##                       
                    ##########                   
                 #######  #######                
              ###### ####    #######             
           ######     ########   ######          
        ######   ###    #########   ######       
      #####    ######         #####    #####     
      ###    #################   ####    ###     
      ###   ####  ######  ######  ####   ###     
      ###  ####  ####        ##########  ###     
      ###  ###  ####   ----    ########  ###     
      ###  ###  ###     ++               ###     
      ###  ###  ###    ---+              ###     
      ###  ####  ###   ++++              ###     
      ###   ###   #####    #####   #########     
      ###   ####   ############  ###########     
      ###  ###    ####  ##     #####     ###     
      #######    ######    #######    ######
         #######   ############   #######        
            #######            #######           
                ######      #######              
                   ############                  
                      ######                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
EOF
    ))
    
    local term_width=$(tput cols)
    local line_width=68  # The ASCII art is approximately 68 characters wide
    local padding=$(( (term_width - line_width) / 2 ))
    
    # Print each line with padding
    for line in "${lines[@]}"; do
        printf "%${padding}s%s\n" "" "$line"
    done
}

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Spinner characters
spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# Array of build steps
build_steps=(
    "Setting up Build Environment"
    "Bootstrapping Debian"
    "Installing Linux kernel"
    "Installing Github packages"
    "Configuring System"
    "Creating Filesystem"
    "Configuring boot loaders"
    "Creating EFI images"
    "Creating UEFI boot image"
    "Creating .ISO and .OVA files"
)

# Function to update step status
update_step() {
    local step=$1
    local status=$2
    local message=$3
    tput cup $((step + 3)) 0
    case $status in
        "idle")
            echo -ne "${BLUE}◯ ${build_steps[$step]}${NC}"
            ;;
        "running")
            echo -ne "${YELLOW}${message} ${build_steps[$step]}${NC}"
            ;;
        "completed")
            echo -ne "${GREEN}✓ ${build_steps[$step]}${NC}"
            ;;
    esac
    tput cup $((${#build_steps[@]} + 4)) 0  # Move cursor to the end
}

# Function to display spinner
display_spinner() {
    local pid=$1
    local step=$2
    local delay=0.1
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        for i in "${spinner[@]}"
        do
            update_step $step "running" "$i"
            sleep $delay
        done
    done
    update_step $step "completed"
}

# Constants
DEBIAN_MIRROR="http://ftp.us.debian.org/debian/"
NODY_GREETER_URL="https://github.com/JezerM/nody-greeter/releases/download/1.6.2/nody-greeter-1.6.2-debian.deb"
OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.7.4/obsidian_1.7.4_amd64.deb"
CAIDO_URL="https://caido.download/releases/v0.42.0/caido-cli-v0.42.0-linux-x86_64.tar.gz"

LIVE_BOOT_DIR="/tmp/LIVE_BOOT"
ISO_NAME="secOS.iso"
USERNAME="mist"

CUSTOM_PROGRAMS=(
    # Dev
    openssh-server
    # Packages
    firefox-esr kitty spotify-client vim nmap hashcat hydra netcat-openbsd lightdm awesome picom rofi proxychains
    # Dependencies
    sudo git golang-go python3 python3-pip pipx python3-setuptools unzip pciutils wget tar dpkg locales tzdata curl gpg
    network-manager net-tools network-manager-gnome wpasupplicant wireless-tools dnsutils aircrack-ng iputils-ping iproute2
    firmware-linux-nonfree firmware-iwlwifi xorg xserver-xorg xserver-xorg-core xserver-xorg-input-all xserver-xorg-video-all alsa-utils playerctl
    gobject-introspection liblightdm-gobject-1-0 liblightdm-gobject-dev libgirepository1.0-dev libcairo2 libcairo2-dev
    libxcb1-dev libx11-dev libnss3-tools libxft-dev libxrandr-dev libxpm-dev uthash-dev os-prober kpackagetool5 libkf5configcore5 libkf5coreaddons5 libkf5package5 libkf5parts5 
    libkpmcore12 libparted2 libpwquality1 libqt5dbus5 libqt5gui5 libqt5network5 libqt5qml5 libqt5quick5 libqt5svg5 libqt5widgets5 libqt5xml5 libstdc++6 libyaml-cpp0.7
    qml-module-qtquick2 qml-module-qtquick-controls qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-window2 python3-yaml 
    udisks2 dosfstools e2fsprogs btrfs-progs xfsprogs squashfs-tools grub-efi-amd64
)

NO_RECOMMENDS_PROGRAMS=(
    nemo
)

setup_build_env() {
    (
        # Remove existing ISO and OVA if they exist
        if [ -f "${ISO_NAME}" ]; then
            rm "${ISO_NAME}"
        fi
        if [ -f "secOS.ova" ]; then
            rm "secOS.ova"
        fi
        
        sudo apt-get update &>/dev/null
        sudo apt-get install -y apt-utils debootstrap squashfs-tools xorriso \
            isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin grub-efi-ia32-bin \
            mtools dosfstools wget unzip virtualbox &>/dev/null
    ) &
    display_spinner $! 0
}

bootstrap_debian() {
    (
        mkdir -p "${LIVE_BOOT_DIR}"
        sudo debootstrap --arch=amd64 --variant=minbase stable \
            "${LIVE_BOOT_DIR}/chroot" "${DEBIAN_MIRROR}" &>/dev/null
    ) &
    display_spinner $! 1
}

install_kernel_and_packages() {    
    (

        # Create user '${USERNAME}'
        sudo chroot "${LIVE_BOOT_DIR}/chroot" useradd -m -s /bin/bash "${USERNAME}"
        echo "${USERNAME}:live" | sudo chroot "${LIVE_BOOT_DIR}/chroot" chpasswd
        sudo chroot "${LIVE_BOOT_DIR}/chroot" usermod -aG sudo "${USERNAME}"

        echo 'root:live' | sudo chroot "${LIVE_BOOT_DIR}/chroot" chpasswd
        
        # Configure repositories
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
            "sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list"
        
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            {
                apt-get install -y curl gpg &&
                curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/spotify.gpg &&
                echo 'deb http://repository.spotify.com stable non-free' | tee /etc/apt/sources.list.d/spotify.list
            } >/dev/null 2>&1
        "
            
        # Install Linux kernel & APT packages
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c \
            "export DEBIAN_FRONTEND=noninteractive && \
            apt-get update &>/dev/null && \
            apt-get --yes --quiet -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" install linux-image-amd64 live-boot systemd-sysv ${CUSTOM_PROGRAMS[*]} &>/dev/null && \
            apt-get --yes --quiet --no-install-recommends install ${NO_RECOMMENDS_PROGRAMS[*]} &>/dev/null
        "
        
        # Nody-Greeter install
        sudo wget -O "${LIVE_BOOT_DIR}/chroot/tmp/nody-greeter.deb" "$NODY_GREETER_URL" >/dev/null 2>&1
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            dpkg -i /tmp/nody-greeter.deb >/dev/null 2>&1
            rm /tmp/nody-greeter.deb >/dev/null 2>&1
        "

        # Calamares install
        sudo cp "${PWD}/config/calamares/calamares_3.3.8.deb" "${LIVE_BOOT_DIR}/chroot/tmp/calamares.deb"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            dpkg -i /tmp/calamares.deb >/dev/null 2>&1
            rm /tmp/calamares.deb >/dev/null 2>&1
        "

        # Obsidian install
        sudo wget -O "${LIVE_BOOT_DIR}/chroot/tmp/obsidian.deb" "$OBSIDIAN_URL" >/dev/null 2>&1
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            dpkg -i /tmp/obsidian.deb >/dev/null 2>&1
            apt-get install -f -y >/dev/null 2>&1  # Install dependencies if needed        
            ln -sf /opt/Obsidian/obsidian /usr/local/bin/obsidian >/dev/null 2>&1        
            rm /tmp/obsidian.deb >/dev/null 2>&1
        "

        # Caido CLI install and setup
        sudo wget -O "${LIVE_BOOT_DIR}/chroot/tmp/caido-cli.tar.gz" "$CAIDO_URL" >/dev/null 2>&1
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            tar -xzf /tmp/caido-cli.tar.gz -C /usr/local/bin >/dev/null 2>&1
            rm /tmp/caido-cli.tar.gz >/dev/null 2>&1
            chmod +x /usr/local/bin/caido >/dev/null 2>&1
        "

    ) &
    display_spinner $! 2
}

install_github_packages() {
    (
        # Installing Wifite2
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            git clone https://github.com/derv82/wifite2.git /usr/local/bin/.wifite2 >/dev/null 2>&1 &&
            ln -sf /usr/local/bin/.wifite2/Wifite.py /usr/local/bin/wifite >/dev/null 2>&1 &&
            ln -sf /usr/bin/python3 /usr/bin/python >/dev/null 2>&1
        "

        # Installing Knock
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            git clone https://github.com/guelfoweb/knock.git /usr/local/bin/.knock >/dev/null 2>&1 &&
            cd /usr/local/bin/.knock >/dev/null 2>&1 &&
            pip install . --break-system-packages >/dev/null 2>&1 &&
            ln -sf /usr/local/bin/.knock/knock/knockpy.py /usr/local/bin/knockpy >/dev/null 2>&1
        "

        # Installing ffuf
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            wget https://github.com/ffuf/ffuf/releases/download/v2.1.0/ffuf_2.1.0_linux_amd64.tar.gz -O /tmp/ffuf.tar.gz >/dev/null 2>&1 &&
            mkdir -p /usr/local/bin/.ffuf >/dev/null 2>&1 &&
            tar -xf /tmp/ffuf.tar.gz -C /usr/local/bin/.ffuf ffuf >/dev/null 2>&1 &&
            ln -sf /usr/local/bin/.ffuf/ffuf /usr/local/bin/ffuf >/dev/null 2>&1 &&
            rm /tmp/ffuf.tar.gz >/dev/null 2>&1
        "

        # Installing gospider
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            wget https://github.com/jaeles-project/gospider/releases/download/v1.1.6/gospider_v1.1.6_linux_x86_64.zip -O /tmp/gospider.zip >/dev/null 2>&1 &&
            unzip /tmp/gospider.zip -d /tmp/gospider >/dev/null 2>&1 &&
            mv /tmp/gospider/gospider_v1.1.6_linux_x86_64/gospider /usr/local/bin/gospider >/dev/null 2>&1 &&
            chmod +x /usr/local/bin/gospider >/dev/null 2>&1 &&
            rm -rf /tmp/gospider /tmp/gospider.zip >/dev/null 2>&1
        "

        # Installing Amass
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            wget https://github.com/owasp-amass/amass/releases/download/v4.2.0/amass_Linux_amd64.zip -O /tmp/amass.zip >/dev/null 2>&1 &&
            unzip /tmp/amass.zip -d /usr/local/bin >/dev/null 2>&1 &&
            mv /usr/local/bin/amass_Linux_amd64 /usr/local/bin/.amass >/dev/null 2>&1 &&
            ln -sf /usr/local/bin/.amass/amass /usr/local/bin/amass >/dev/null 2>&1 &&
            rm /tmp/amass.zip >/dev/null 2>&1
        "

        # Installing dnsReaper
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            git clone https://github.com/punk-security/dnsReaper.git /usr/local/bin/.dnsReaper >/dev/null 2>&1 &&
            cd /usr/local/bin/.dnsReaper >/dev/null 2>&1 &&
            pip install -r requirements.txt --break-system-packages >/dev/null 2>&1 &&
            chmod +x main.py >/dev/null 2>&1 &&
            ln -sf /usr/local/bin/.dnsReaper/main.py /usr/local/bin/dnsreaper >/dev/null 2>&1
        "

        # Installing jsluice
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            go install -v github.com/BishopFox/jsluice/cmd/jsluice@latest >/dev/null 2>&1 &&
            mv /root/go/bin/jsluice /usr/local/bin/.jsluice >/dev/null 2>&1 &&
            ln -sf /usr/local/bin/.jsluice /usr/local/bin/jsluice >/dev/null 2>&1 &&
            rm -rf /root/go >/dev/null 2>&1
        "

        # Installing shortscan
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            go install -v github.com/bitquark/shortscan/cmd/shortscan@latest >/dev/null 2>&1 &&
            mv /root/go/bin/shortscan /usr/local/bin/shortscan >/dev/null 2>&1 &&
            rm -rf /root/go >/dev/null 2>&1
        "

        # Installing CloudBrute
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            wget https://github.com/0xsha/CloudBrute/releases/download/v1.0.7/cloudbrute_1.0.7_Linux_x86_64.tar.gz -O /tmp/cloudbrute.tar.gz >/dev/null 2>&1 &&
            mkdir -p /usr/local/bin/.cloudbrute &&
            tar -xf /tmp/cloudbrute.tar.gz -C /usr/local/bin/.cloudbrute &&
            ln -sf /usr/local/bin/.cloudbrute/cloudbrute /usr/local/bin/cloudbrute &&
            rm /tmp/cloudbrute.tar.gz
        "
        # Installing wafw00f
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            su - ${USERNAME} -c 'pip install wafw00f --user --break-system-packages' >/dev/null 2>&1
            ln -sf /home/${USERNAME}/.local/bin/wafw00f /usr/local/bin/wafw00f >/dev/null 2>&1
            chmod +x /usr/local/bin/wafw00f >/dev/null 2>&1
        "
        # Installing Arjun
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            su - ${USERNAME} -c 'pip install arjun --user --break-system-packages' >/dev/null 2>&1 &&
            ln -sf /home/${USERNAME}/.local/bin/arjun /usr/local/bin/arjun >/dev/null 2>&1 &&
            chmod +x /usr/local/bin/arjun >/dev/null 2>&1
        "

        # Installing Corsy
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            git clone https://github.com/s0md3v/Corsy.git /usr/local/bin/.corsy >/dev/null 2>&1 &&
            cd /usr/local/bin/.corsy >/dev/null 2>&1 &&
            pip install -r requirements.txt --break-system-packages >/dev/null 2>&1 &&
            echo '#!/bin/bash' > /usr/local/bin/corsy &&
            echo 'python3 /usr/local/bin/.corsy/corsy.py \"\$@\"' >> /usr/local/bin/corsy &&
            chmod +x /usr/local/bin/corsy
        "

        # Installing FireProx and AWS CLI
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            git clone https://github.com/ustayready/fireprox /usr/local/bin/.fireprox >/dev/null 2>&1 &&
            cd /usr/local/bin/.fireprox >/dev/null 2>&1 &&
            pip3 install -r requirements.txt --break-system-packages >/dev/null 2>&1 &&
            echo '#!/bin/bash' > /usr/local/bin/fireprox &&
            echo 'python3 /usr/local/bin/.fireprox/fire.py \"\$@\"' >> /usr/local/bin/fireprox &&
            chmod +x /usr/local/bin/fireprox &&
            
            # Installing AWS CLI
            curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' >/dev/null 2>&1 &&
            unzip awscliv2.zip >/dev/null 2>&1 &&
            ./aws/install >/dev/null 2>&1 &&
            rm -rf aws awscliv2.zip >/dev/null 2>&1
        "

        # Installing ronema (local)
        sudo mkdir -p "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema"
        sudo cp -r "${PWD}/config/ronema/src"/* "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/ronema/"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            cp /home/${USERNAME}/.config/ronema/ronema /usr/local/bin/ronema
            cp /home/${USERNAME}/.config/ronema/roblma /usr/local/bin/roblma
            chmod +x /usr/local/bin/ronema
            chmod +x /usr/local/bin/roblma
            chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/ronema
        "

        # Copying recon (local)
        sudo cp -r "../recon" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/.recon" 2>&1
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            chmod +x /usr/local/bin/.recon/recon.py &&
            ln -sf /usr/local/bin/.recon/recon.py /usr/local/bin/recon 
        "

        # Copying infra (local)
        sudo cp "../infra/infra.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/infra.py" 2>&1
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            chmod +x /usr/local/bin/infra.py &&
            ln -sf /usr/local/bin/infra.py /usr/local/bin/infra 
            pip3 install cloudflare python-dotenv boto3 questionary botocore --break-system-packages >/dev/null 2>&1
        "

        # Copying osint (local)
        sudo cp "../OSINT/osint.py" "${LIVE_BOOT_DIR}/chroot/usr/local/bin/osint.py" 2>&1
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            chmod +x /usr/local/bin/osint.py &&
            ln -sf /usr/local/bin/osint.py /usr/local/bin/osint 
            pip3 install requests beautifulsoup4 cloudscraper --break-system-packages >/dev/null 2>&1
        "

        # Installing bbot and configuring pipx path for mist user
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
           su - mist -c 'pipx install bbot >/dev/null 2>&1'
        "

        # Installing Spiderfoot
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            git clone https://github.com/smicallef/spiderfoot.git /usr/local/bin/.spiderfoot > /dev/null 2>&1 &&
            cd /usr/local/bin/.spiderfoot > /dev/null 2>&1 &&
            pip3 install -r requirements.txt --break-system-packages > /dev/null 2>&1 &&
            echo '#!/bin/bash' > /usr/local/bin/spiderfoot &&
            echo 'python3 /usr/local/bin/.spiderfoot/sf.py \"\$@\"' >> /usr/local/bin/spiderfoot &&
            chmod +x /usr/local/bin/spiderfoot
        "

        # Ensure all users can access the installed tools
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            chmod -R 755 /usr/local/bin
        "

    ) &
    display_spinner $! 3
}

configure_system() {
    (
        local system_conf="${PWD}/config/system/system.conf"
        source "${system_conf}"

        # Set hostname
        echo "${HOSTNAME}" | sudo tee "${LIVE_BOOT_DIR}/chroot/etc/hostname" >/dev/null
        echo "${HOSTS}" | sudo tee "${LIVE_BOOT_DIR}/chroot/etc/hosts" >/dev/null
        echo "export DISPLAY=:0" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/etc/profile.d/display.sh" >/dev/null

        # Configure paths for all users
        echo "PATH=$PATH:${PATH_APPEND}" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/etc/environment" >/dev/null

        # Create all required directories
        for dir in "${DIRECTORIES[@]}"; do
            sudo mkdir -p "${LIVE_BOOT_DIR}/chroot${dir}"
        done
        
        # Set Awesome WM as the default window manager for LightDM, Configure LightDM
        echo "${LIGHTDM_CONF}" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/etc/lightdm/lightdm.conf" >/dev/null
        sudo sed -i 's/^#greeter-session=.*/greeter-session=nody-greeter/g' "${LIVE_BOOT_DIR}/chroot/etc/lightdm/lightdm.conf"
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            sed -i 's/^[[:space:]]*theme:[[:space:]]*.*$/    theme: sechorda/' /etc/lightdm/web-greeter.yml
        "

        # Set GTK theme
        sudo mkdir -p "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/gtk-3.0"
        echo "${GTK_THEME}" | sudo tee "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.config/gtk-3.0/settings.ini" >/dev/null
        
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
        for app in nody-greeter lstopo picom systemsettings kdesystemsettings install-debian; do echo "NoDisplay=true" | sudo tee -a "${LIVE_BOOT_DIR}/chroot/usr/share/applications/${app}.desktop" >/dev/null; done

        # Configure bash settings for mist user
        echo "${BASH_CONFIG}" | sudo tee "${LIVE_BOOT_DIR}/chroot/home/${USERNAME}/.bashrc" >/dev/null
        echo "mist ALL=(ALL) NOPASSWD: ALL" | sudo chroot "${LIVE_BOOT_DIR}/chroot" tee -a /etc/sudoers.d/mist >/dev/null

        # Set correct ownership and permissions
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config /home/${USERNAME}/secos-vault >/dev/null 2>&1
            $(printf '%s >/dev/null 2>&1\n' "${PERMISSIONS[@]}")
        "

        # Configure and generate locales
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            sed -i 's/# ${LOCALE} UTF-8/${LOCALE} UTF-8/' /etc/locale.gen
            locale-gen ${LOCALE} >/dev/null 2>&1
            update-locale LANG=${LOCALE} LC_ALL=${LOCALE} LANGUAGE=${LOCALE%.*} >/dev/null 2>&1
            ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
            echo '${TIMEZONE}' > /etc/timezone
            dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
        "
        # Clean up unnecessary packages / Add startup script
        sudo chroot "${LIVE_BOOT_DIR}/chroot" /bin/bash -c "
            apt-get autoremove -y >/dev/null 2>&1
            apt-get clean >/dev/null 2>&1
        "        

    ) &
    display_spinner $! 4
}

create_filesystem() {
    (
        mkdir -p "${LIVE_BOOT_DIR}"/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp/grub-embed}
        sudo mksquashfs "${LIVE_BOOT_DIR}/chroot" "${LIVE_BOOT_DIR}/staging/live/filesystem.squashfs" &>/dev/null

        cp "${LIVE_BOOT_DIR}/chroot/boot"/vmlinuz-* "${LIVE_BOOT_DIR}/staging/live/vmlinuz"
        cp "${LIVE_BOOT_DIR}/chroot/boot"/initrd.img-* "${LIVE_BOOT_DIR}/staging/live/initrd"
    ) &
    display_spinner $! 5
}

configure_boot_loaders() {
    (
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
    ) &
    display_spinner $! 6
}

create_efi_images() {
    (
        grub-mkstandalone -O i386-efi --modules="part_gpt part_msdos fat iso9660" --locales="" --themes="" --fonts="" \
            --output="${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" "boot/grub/grub.cfg=${LIVE_BOOT_DIR}/tmp/grub-embed/grub-early.cfg" &>/dev/null

        grub-mkstandalone -O x86_64-efi --modules="part_gpt part_msdos fat iso9660" --locales="" --themes="" --fonts="" \
            --output="${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTx64.EFI" "boot/grub/grub.cfg=${LIVE_BOOT_DIR}/tmp/grub-embed/grub-early.cfg" &>/dev/null
    ) &
    display_spinner $! 7
}

create_uefi_boot_image() {
    (
        cd "${LIVE_BOOT_DIR}/staging"
        dd if=/dev/zero of=efiboot.img bs=1M count=20 &>/dev/null
        mkfs.vfat efiboot.img &>/dev/null
        mmd -i efiboot.img ::/EFI ::/EFI/BOOT
        mcopy -vi efiboot.img "${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTIA32.EFI" "${LIVE_BOOT_DIR}/staging/EFI/BOOT/BOOTx64.EFI" "${LIVE_BOOT_DIR}/staging/boot/grub/grub.cfg" ::/EFI/BOOT/ >/dev/null 2>&1
        cd - &>/dev/null
    ) &
    display_spinner $! 8
}

create_iso_and_ova() {
    (
        # VM Configuration
        local VM_NAME="secOS_VM"
        local VM_MEMORY=4096
        local VM_CPUS=4
        local VM_HDD_SIZE=20000
        local OUTPUT_OVA="secOS.ova"

        # Create ISO
        xorriso -as mkisofs -iso-level 3 -o "${ISO_NAME}" -full-iso9660-filenames \
            -volid "SECOS" --mbr-force-bootable -partition_offset 16 \
            -joliet -joliet-long -rational-rock -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
            -eltorito-boot isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
            --eltorito-catalog isolinux/isolinux.cat \
            -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot -isohybrid-gpt-basdat \
            -append_partition 2 0xef "${LIVE_BOOT_DIR}/staging/efiboot.img" \
            "${LIVE_BOOT_DIR}/staging" &>/dev/null

        # Create OVA if VBoxManage is available
        if command -v VBoxManage >/dev/null 2>&1; then
            # Clean up any existing VM
            if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
                VBoxManage unregistervm "$VM_NAME" --delete >/dev/null 2>&1
            fi

            # Create VM
            VBoxManage createvm --name "$VM_NAME" --ostype Debian_64 --register >/dev/null 2>&1

            # Configure VM settings
            VBoxManage modifyvm "$VM_NAME" --memory "$VM_MEMORY" --cpus "$VM_CPUS" \
                --firmware efi \
                --chipset piix3 \
                --acpi on \
                --ioapic on \
                --x2apic on \
                --apic on \
                --pae off \
                --longmode on \
                --rtcuseutc on \
                --graphicscontroller vmsvga \
                --vram 16 >/dev/null 2>&1

            # Set boot order
            VBoxManage modifyvm "$VM_NAME" --boot1 dvd --boot2 none --boot3 none --boot4 none >/dev/null 2>&1
            VBoxManage modifyvm "$VM_NAME" --firmware-boot-menu messageandmenu >/dev/null 2>&1

            # Configure storage controllers
            VBoxManage storagectl "$VM_NAME" --name "IDE" --add ide --controller PIIX4 --bootable on >/dev/null 2>&1
            VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci --bootable on >/dev/null 2>&1

            # Attach ISO using absolute path
            local ISO_ABSOLUTE_PATH=$(realpath "${ISO_NAME}")
            VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 \
                --type dvddrive --medium "$ISO_ABSOLUTE_PATH" >/dev/null 2>&1

            # Verify configuration
            VBoxManage showvminfo "$VM_NAME" | grep -A 5 "Storage Controller" >/dev/null 2>&1
            VBoxManage showvminfo "$VM_NAME" | grep "Boot Device" >/dev/null 2>&1

            # Export VM to OVA
            VBoxManage export "$VM_NAME" --output "$OUTPUT_OVA" --options=nomacs,manifest,iso >/dev/null 2>&1

            # Clean up VM after export
            VBoxManage unregistervm "$VM_NAME" --delete >/dev/null 2>&1
        fi
    ) &
    display_spinner $! 9
}

main() {
    # Check and remove existing temporary directory if it exists
    if [ -d "${LIVE_BOOT_DIR}" ]; then
        sudo rm -rf "${LIVE_BOOT_DIR}"
    fi
    
    clear
    print_centered_ascii_art

    # Initialize all steps as idle
    for i in "${!build_steps[@]}"; do
        update_step $i "idle"
    done
    
    setup_build_env
    bootstrap_debian
    install_kernel_and_packages
    install_github_packages    
    configure_system
    create_filesystem
    configure_boot_loaders
    create_efi_images
    create_uefi_boot_image
    create_iso_and_ova

    end_time=$(date +%s)
    build_time=$((end_time - start_time))
    minutes=$((build_time / 60))
    seconds=$((build_time % 60))
    
    printf "💿 secOS ISO created at ./${ISO_NAME}\n"
    printf "📦 secOS OVA created at ./secOS.ova\n"
    printf "                  *\n"
    printf "Total build time: ${minutes}m${seconds}s\n"
}

main
