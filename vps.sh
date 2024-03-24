#!/bin/bash
#
#Vars
mounted=0
GREEN='\033[1;32m';GREEN_D='\033[0;32m';RED='\033[0;31m';YELLOW='\033[0;33m';BLUE='\033[0;34m';NC='\033[0m'
# Kiểm tra ảo hóa..
virtu=$(egrep -i '^flags.*(vmx|svm)' /proc/cpuinfo | wc -l)
if [ $virtu = 0 ]; then 
    echo -e "[Lỗi] ${RED}Ảo hóa/KVM trên Máy chủ/VPS của bạn đã TẮT\nThoát...${NC}"
else
    # Xóa Cài đặt Windows Trước đó bằng Kịch bản
    umount -l /mnt /media/script /media/sw
    rm -rf /mediabots /floppy /virtio /media/* /tmp/*
    rm -f /sw.iso /disk.img 
    # Cài đặt gói Ubuntu cần thiết
    dist=$(hostnamectl | egrep "Operating System" | cut -f2 -d":" | cut -f2 -d " ")
    if [ $dist = "CentOS" ]; then
        printf "Y\n" | yum install sudo -y
        sudo yum install wget vim curl genisoimage -y
        # Tải xuống QEMU-KVM Portable
        echo "Đang Tải loading..."
        sudo yum update -y
        sudo yum install -y qemu-kvm
    elif [ $dist = "Ubuntu" -o $dist = "Debian" ]; then
        printf "Y\n" | apt-get install sudo -y
        sudo apt-get install vim curl genisoimage -y
        # Tải xuống QEMU-KVM Portable
        echo "Đang Tải...."
        sudo apt-get update
        sudo apt-get install -y qemu-kvm
    fi
    sudo ln -s /usr/bin/genisoimage /usr/bin/mkisofs
    # Tải tài nguyên
    sudo mkdir /mediabots /floppy /virtio
    link1_status=$(curl -Is http://download.microsoft.com/download/6/2/A/62A76ABB-9990-4EFC-A4FE-C7D698DAEB96/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO | grep HTTP | cut -f2 -d" " | head -1)
    link2_status=$(curl -Is https://ia601506.us.archive.org/4/items/WS2012R2/WS2012R2.ISO | grep HTTP | cut -f2 -d" ")
    #sudo wget -P /mediabots https://archive.org/download/WS2012R2/WS2012R2.ISO # Windows Server 2012 R2 
    if [ $link1_status = "200" ]; then 
        sudo wget -O /mediabots/WS2012R2.ISO http://download.microsoft.com/download/6/2/A/62A76ABB-9990-4EFC-A4FE-C7D698DAEB96/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO 
    elif [ $link2_status = "200" -o $link2_status = "301" -o $link2_status = "302" ]; then 
        sudo wget -P /mediabots https://ia601506.us.archive.org/4/items/WS2012R2/WS2012R2.ISO
    else
        echo -e "${RED}[Lỗi]${NC} ${YELLOW}Xin lỗi! Không có URL hình ảnh hệ điều hành Windows nào khả dụng, vui lòng báo cáo về vấn đề này trên trang Github : ${NC}https://github.com/mediabots/Linux-to-Windows-with-QEMU"
        echo "Thoát.."
        sleep 30
        exit 1
    fi
    sudo wget -P /floppy https://ftp.mozilla.org/pub/firefox/releases/64.0/win32/en-US/Firefox%20Setup%2064.0.exe
    sudo mv /floppy/'Firefox Setup 64.0.exe' /floppy/Firefox.exe
    sudo wget -P /floppy https://downloadmirror.intel.com/23073/eng/PROWinx64.exe # Bộ điều hợp Mạng Intel cho Windows Server 2012 R2 
    # Kịch bản Powershell để tự động kích hoạt kết nối máy tính từ xa cho người quản trị
    sudo touch /floppy/EnableRDP.ps1
    sudo echo -e "Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name \"fDenyTSConnections\" -Value 0" >> /floppy/EnableRDP.ps1
    sudo echo -e "Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name \"UserAuthentication\" -Value 1" >> /floppy/EnableRDP.ps1
    sudo echo -e "Enable-NetFirewallRule -DisplayGroup \"Remote Desktop\"" >> /floppy/EnableRDP.ps1
    # Tải về Trình điều khiển Virtio
    sudo wget -P /virtio https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
    # Tạo .iso cho các công cụ và trình điều khiển Windows
    sudo mkisofs -o /sw.iso /floppy
    #
    # Bật KSM
    sudo echo 1 > /sys/kernel/mm/ksm/run
    # Kích hoạt RAM ảo
    sudo echo 1 > /proc/sys/vm/overcommit_memory
    # Mở các cổng 3398, 443, 80
    sudo ufw allow 3398/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 80/tcp
    sudo ufw --force enable
    # Giải phóng bộ nhớ
    sync; sudo echo 3 > /proc/sys/vm/drop_caches
    # Thu thập thông tin hệ thốngidx=0; hddlist=””;
while read line; do
    ((idx++))
    if [ $idx = 1 ]; then
        hddlist=”$line”
    else
        hddlist=”$hddlist,$line”
    fi
done < <(lsblk -lp | grep -o ‘^/dev/sd[^ ]*’)
echo -e “${GREEN}Các ổ cứng có sẵn trong hệ thống của bạn :${NC} ${YELLOW}$hddlist${NC}”
echo -e “${GREEN}Tổng RAM Hệ thống :${NC} ${YELLOW}$(grep MemTotal /proc/meminfo | awk ‘{print $2/1024}’) MB${NC}”
#
# Kịch bản Kết thúc
echo -e “\n${BLUE}Tất cả Tài nguyên Cần thiết Đã Được Tải Xuống Thành công!${NC}”
sleep 2
echo -e “\n${YELLOW}Đang Khởi chạy Máy..${NC}\n”
sleep 3
sudo qemu-system-x86_64 -m 3072 -smp cores=4 -enable-kvm -cpu host -cdrom /mediabots/WS2012R2.ISO -drive file=disk.img,if=virtio -drive file=/virtio/virtio-win.iso,index=3 -boot order=d -net nic -net user -usb -usbdevice mouse -usbdevice keyboard -vga std
echo “IP: $(hostname -I) | Cổng: 3398, 443, 80 | Người dùng: admin | Mật khẩu: @Aa123123”

fi
