#!/bin/bash
#
#Vars
mounted=0
GREEN='\033[1;32m';GREEN_D='\033[0;32m';RED='\033[0;31m';YELLOW='\033[0;33m';BLUE='\033[0;34m';NC='\033[0m'
# Virtualization checking..
#virtu=$(egrep -i '^flags.*(vmx|svm)' /proc/cpuinfo | wc -l)
#if [ $virtu = 0 ] ; then echo -e "[Error] ${RED}Virtualization/KVM in your Server/VPS is OFF\nExiting...${NC}";
else
#
# Deleting Previous Windows Installation by the Script
umount -l /mnt /media/script /media/sw
rm -rf /mediabots /floppy /virtio /media/* /tmp/*
rm -f /sw.iso /disk.img 
# installing required Ubuntu packages
dist=$(hostnamectl | egrep "Operating System" | cut -f2 -d":" | cut -f2 -d " ")
if [ $dist = "CentOS" ] ; then
	printf "Y\n" | yum install sudo -y
	sudo yum install wget vim curl genisoimage -y
	# Downloading Portable QEMU-KVM
	echo "Downloading QEMU"
	sudo yum update -y
	sudo yum install -y qemu-kvm
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

# Kiểm tra xem libvirt đã được kích hoạt chưa
if [ $libvirt_status = "active" ]; then
    echo -e "${GREEN}Libvirt đã được kích hoạt.${NC}"
else
    # Kích hoạt libvirt nếu chưa được kích hoạt
    sudo systemctl start libvirtd
    echo -e "${GREEN}Đã kích hoạt Libvirt.${NC}"
fi

# Kiểm tra xem có user hiện tại trong nhóm libvirt không
current_user=$(whoami)
if id "$current_user" | grep -q libvirt; then
    echo -e "${GREEN}Người dùng hiện tại đã được thêm vào nhóm libvirt.${NC}"
else
    # Thêm user hiện tại vào nhóm libvirt nếu chưa có
    sudo usermod -aG libvirt $current_user
    echo -e "${GREEN}Đã thêm người dùng hiện tại vào nhóm libvirt.${NC}"
fi

# Menu chọn cài đặt Windows
echo -e "${GREEN}Menu cài đặt Windows:${NC}"
echo "1. Cài đặt Windows 10"
echo "2. Cài đặt Windows Server 2012"
read -t 15 -p "Chọn phiên bản Windows bạn muốn cài đặt (nhập số): " choice

case $choice in
    1)
        # Cài đặt Windows 10
        echo "Bạn đã chọn cài đặt Windows 10"
        # Thêm mã để tải tài nguyên cần thiết cho Windows 10 ở đây
        sudo wget -P /floppy https://download.microsoft.com/download/6/2/A/62A76ABB-9990-4EFC-A4FE-C7D698DAEB96/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO
        ;;
    2)
        # Cài đặt Windows Server 2012
        echo "Bạn đã chọn cài đặt Windows Server 2012"
        # Thêm mã để tải tài nguyên cần thiết cho Windows Server 2012 ở đây
        sudo wget -P /floppy https://ia601506.us.archive.org/4/items/WS2012R2/WS2012R2.ISO
        ;;
    *)
        # Cài đặt Windows Server 2012 mặc định sau 15 giây
        echo "Không có lựa chọn được chọn. Tự động cài đặt Windows Server 2012 sau 15 giây..."
        sleep 15
        # Thêm mã để tải tài nguyên cần thiết cho Windows Server 2012 ở đây
        sudo wget -P /floppy https://ia601506.us.archive.org/4/items/WS2012R2/WS2012R2.ISO
        ;;
esac

# Tạo tập lệnh PowerShell để kích hoạt kết nối máy tính từ xa
sudo touch /floppy/EnableRDP.ps1
sudo cat <<EOF | sudo tee -a /floppy/EnableRDP.ps1
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
EOF

# Kích hoạt RAM ảo
sudo echo 1 > /proc/sys/vm/overcommit_memory
sudo ufw allow 3398/tcp
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw --force enableGiải phóng bộ nhớ

sync
sudo echo 3 > /proc/sys/vm/drop_caches

Thu thập thông tin về hệ thống

idx=0
hddlist=””
while read line; do
((idx++))
if [ $idx = 1 ]; then
hddlist=”$line”
else
hddlist=”$hddlist,$line”
fi
done < <(lsblk -lp | grep -o ‘^/dev/sd[^ ]*’)
echo -e “Các ổ cứng có sẵn trong hệ thống của bạn : $hddlist”
echo -e “Tổng RAM Hệ thống : $(grep MemTotal /proc/meminfo | awk ‘{print $2/1024}’)”

#!/bin/bash

Lấy thông tin người dùng hiện tại

current_user=$(whoami)
echo “Tên người dùng hiện tại: $current_user”

Lấy danh sách người dùng và mật khẩu

echo “Danh sách người dùng và mật khẩu:”
cat /etc/passwd | awk -F: ‘{print “Người dùng: “ $1 “, Mật khẩu: “ $2}’

Lấy địa chỉ IP của máy

echo “Địa chỉ IP của máy:”
ip_addr=$(hostname -I)
echo “$ip_addr”
