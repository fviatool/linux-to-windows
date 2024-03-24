#!/bin/bash
#
# Vars
mounted=0
GREEN='\033[1;32m';RED='\033[0;31m';YELLOW='\033[0;33m';BLUE='\033[0;34m';NC='\033[0m'

# Xóa cài đặt Windows và Ubuntu trước đó
umount -l /mnt /media/script /media/sw
rm -rf /mediabots /floppy /virtio /media/* /tmp/*
rm -f /sw.iso /disk.img 

# Cài đặt gói cần thiết cho Ubuntu
dist=$(hostnamectl | egrep "Operating System" | cut -f2 -d":" | cut -f2 -d " ")
if [ $dist = "CentOS" ]; then
    printf "Y\n" | yum install sudo -y
    sudo yum install wget vim curl genisoimage -y
    echo "Đang tải loading..."
    sudo yum update -y
    sudo yum install -y qemu-kvm
elif [ $dist = "Ubuntu" -o $dist = "Debian" ]; then
    printf "Y\n" | apt-get install sudo -y
    sudo apt-get install vim curl genisoimage -y
    echo "Đang tải...."
    sudo apt-get update
    sudo apt-get install -y qemu-kvm
fi
sudo ln -s /usr/bin/genisoimage /usr/bin/mkisofs

# Cài đặt gói libvirt và qemu-kvm
if [ $dist = "CentOS" ]; then
    sudo yum install libvirt qemu-kvm -y
elif [ $dist = "Ubuntu" -o $dist = "Debian" ]; then
    sudo apt-get install libvirt-daemon-system qemu-kvm -y
fi

# Kiểm tra trạng thái của libvirt
libvirt_status=$(systemctl is-active libvirtd)

# Kích hoạt libvirt nếu chưa được kích hoạt
if [ $libvirt_status = "active" ]; then
    echo -e "${GREEN}Libvirt đã được kích hoạt.${NC}"
else
    sudo systemctl start libvirtd
    echo -e "${GREEN}Đã kích hoạt Libvirt.${NC}"
fi

# Thêm user hiện tại vào nhóm libvirt nếu chưa có
current_user=$(whoami)
if id "$current_user" | grep -q libvirt; then
    echo -e "${GREEN}Người dùng hiện tại đã được thêm vào nhóm libvirt.${NC}"
else
    sudo usermod -aG libvirt $current_user
    echo -e "${GREEN}Đã thêm người dùng hiện tại vào nhóm libvirt.${NC}"
fi

# Cài đặt Windows Server 2012
echo "Bạn đã chọn cài đặt Windows Server 2012"
echo "Tải tài nguyên cần thiết cho Windows Server 2012..."
sudo wget -P /mediabots https://ia601506.us.archive.org/4/items/WS2012R2/WS2012R2.ISO
echo "Tạo tập lệnh PowerShell để kích hoạt kết nối máy tính từ xa..."
sudo touch /floppy/EnableRDP.ps1
sudo cat <<EOF | sudo tee -a /floppy/EnableRDP.ps1
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
EOF

# Tạo tài khoản người dùng và cấp quyền truy cập Remote Desktop
sudo New-LocalUser -Name "admin" -Password (ConvertTo-SecureString -AsPlainText "@Aa123123" -Force) -FullName "admin" -Description "admin"
sudo Set-LocalUser -Name "admin" -RemoteDesktopUser

sudo wget -P /floppy https://ftp.mozilla.org/pub/firefox/releases/64.0/win32/en-US/Firefox%20Setup%2064.0.exe
sudo mv /floppy/'Firefox Setup 64.0.exe' /floppy/Firefox.exe
sudo wget -P /floppy https://downloadmirror.intel.com/23073/eng/PROWinx64.exe

# Tạo tập lệnh PowerShell để kích hoạt kết nối máy tính từ xa
sudo tee -a /floppy/EnableRDP.ps1 > /dev/null <<'EOF'
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
EOF

# Tải về trình điều khiển Virtio
sudo wget -P /virtio https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

# Tạo file ISO chứa các tài nguyên và trình điều khiển Windows
sudo mkisofs -o /sw.iso /floppy

# Bật KSM
sudo echo 1 > /sys/kernel/mm/ksm/run
sudo echo 1 > /proc/sys/vm/overcommit_memory
echo "Mở cổng cho các dịch vụ..."
sudo ufw allow 3398/tcp
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw --force enable
echo "Giải phóng bộ nhớ..."
sync
sudo echo 3 > /proc/sys/vm/drop_caches

# Thu thập thông tin về hệ thống
idx=0
hddlist=""
while read line; do
    ((idx++))
    if [ $idx = 1 ]; then
        hddlist="$line"
    else
        hddlist="$hddlist,$line"
    fi
done < <(lsblk -lp | grep -o '^/dev/sd[^ ]*')
echo -e "${GREEN}Các ổ cứng có sẵn trong hệ thống của bạn :${NC} ${YELLOW}$hddlist${NC}"
echo -e "${GREEN}Tổng RAM Hệ thống :${NC} ${YELLOW}$(grep MemTotal /proc/meminfo | awk ‘{print $2/1024}’)${NC}”

Kết thúc thông báo

echo -e “\n${BLUE}Mọi tài nguyên cần thiết đã được tải thành công!${NC}”
sleep 2
echo -e “\n${YELLOW}Khởi động máy ảo QEMU..${NC}\n”
sleep 3

Khởi động máy ảo Windows Server 2012

sudo qemu-system-x86_64 -m 3072 -smp cores=4 -enable-kvm -cpu host -cdrom /mediabots/WS2012R2.ISO -drive file=disk.img,if=virtio -boot order=d -net nic -net user -usb -usbdevice mouse -usbdevice keyboard -vga stdp
