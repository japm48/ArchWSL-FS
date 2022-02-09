OUT_TGZ=rootfs.tar.gz

DLR=curl
DLR_FLAGS=-L
BASE_URL=http://mirrors.edge.kernel.org/archlinux/iso/2022.02.01/archlinux-bootstrap-2022.02.01-x86_64.tar.gz
FRTCP_URL=https://github.com/yuk7/arch-prebuilt/releases/download/21082800/fakeroot-tcp-1.25.3-2-x86_64.pkg.tar.zst
GLIBC_URL=https://github.com/yuk7/arch-prebuilt/releases/download/21082800/glibc-2.33-5-x86_64.pkg.tar.zst
PAC_PKGS=base less nano sudo vim curl

all: $(OUT_TGZ)

tgz: $(OUT_TGZ)
$(OUT_TGZ): rootfinal.tmp
	@echo -e '\e[1;31mBuilding $(OUT_TGZ)\e[m'
	cd root.x86_64; sudo tar --xattrs --xattrs-include="security.capability" -zcpf ../$(OUT_TGZ) *
	sudo chown `id -un` $(OUT_TGZ)

rootfinal.tmp: glibc.tmp fakeroot.tmp locale.tmp
	@echo -e '\e[1;31mCleaning files from rootfs...\e[m'
	yes | sudo chroot root.x86_64 /usr/bin/pacman -Scc
	sudo umount root.x86_64/sys
	sudo umount root.x86_64/proc
	-sudo umount root.x86_64/sys
	-sudo umount root.x86_64/proc
	sudo mv -f root.x86_64/etc/mtab.bak root.x86_64/etc/mtab
	sudo cp -f pacman.conf root.x86_64/etc/pacman.conf
	echo "# This file was automatically generated by WSL. To stop automatic generation of this file, remove this line." | sudo tee root.x86_64/etc/resolv.conf
	sudo rm -rf `sudo find root.x86_64/root/ -type f`
	sudo rm -rf `sudo find root.x86_64/tmp/ -type f`
	@echo -e '\e[1;31mCopy Extra files to rootfs...\e[m'
	sudo cp bash_profile root.x86_64/root/.bash_profile
	echo > rootfinal.tmp

fakeroot.tmp: proc-tmp.tmp glibc.tmp fakeroot-tcp.pkg.tar.zst
	@echo -e '\e[1;31mInstalling fakeroot-tcp...\e[m'
	sudo cp -f fakeroot-tcp.pkg.tar.zst root.x86_64/root/fakeroot-tcp.pkg.tar.zst
	yes | sudo chroot root.x86_64 /usr/bin/pacman -U /root/fakeroot-tcp.pkg.tar.zst
	sudo rm -rf root.x86_64/root/fakeroot-tcp.pkg.tar.zst
	touch fakeroot.tmp

glibc.tmp: proc-tmp.tmp pacpkgs.tmp glibc.pkg.tar.zst
	@echo -e '\e[1;31mInstalling glibc...\e[m'
	sudo cp -f glibc.pkg.tar.zst root.x86_64/root/glibc.tar.zst
	yes | sudo chroot root.x86_64 /usr/bin/pacman -U /root/glibc.tar.zst
	sudo rm -rf root.x86_64/root/glibc.pkg.tar.zst
	touch  glibc.tmp

pacpkgs.tmp: proc-tmp.tmp resolv-tmp.tmp mirrorlist-tmp.tmp paccnf-tmp.tmp
	@echo -e '\e[1;31mInstalling basic packages...\e[m'
	sudo chroot root.x86_64 /usr/bin/pacman -Syu --noconfirm $(PAC_PKGS)
	sudo mkdir -p root.x86_64/etc/pacman.d/hooks
	sudo cp -f setcap-iputils.hook root.x86_64/etc/pacman.d/hooks/50-setcap-iputils.hook
	sudo setcap cap_net_raw+p root.x86_64/usr/bin/ping
	touch pacpkgs.tmp

locale.tmp: proc-tmp.tmp pacpkgs.tmp
	sudo sed -i -e "s/#en_US.UTF-8/en_US.UTF-8/" root.x86_64/etc/locale.gen
	echo "LANG=en_US.UTF-8" | sudo tee root.x86_64/etc/locale.conf
	sudo ln -sf /etc/locale.conf root.x86_64/etc/default/locale
	sudo chroot root.x86_64 /usr/bin/locale-gen
	touch locale.tmp

resolv-tmp.tmp: proc-tmp.tmp
	sudo cp -f /etc/resolv.conf root.x86_64/etc/resolv.conf
	touch resolv-tmp.tmp

mirrorlist-tmp.tmp: root.x86_64.tmp
	sudo cp -bf mirrorlist root.x86_64/etc/pacman.d/mirrorlist
	touch mirrorlist-tmp.tmp

paccnf-tmp.tmp: root.x86_64.tmp
	sudo cp -bf pacman.conf.nosig root.x86_64/etc/pacman.conf
	touch paccnf.tmp

proc-tmp.tmp: root.x86_64.tmp
	@echo -e '\e[1;31mMounting proc to rootfs...\e[m'
	sudo mv root.x86_64/etc/mtab root.x86_64/etc/mtab.bak
	echo "rootfs / rootfs rw 0 0" | sudo tee root.x86_64/etc/mtab
	sudo mount -t proc proc root.x86_64/proc/
	sudo mount --bind /sys root.x86_64/sys
	touch proc-tmp.tmp

root.x86_64.tmp: base.tar.gz
	@echo -e '\e[1;31mExtracting rootfs...\e[m'
	sudo tar --xattrs --xattrs-include="security.capability" -zxpf base.tar.gz
	sudo chmod +x root.x86_64
	touch root.x86_64.tmp

glibc.pkg.tar.zst:
	@echo -e '\e[1;31mDownloading glibc.pkg.tar.zst...\e[m'
	$(DLR) $(DLR_FLAGS) $(GLIBC_URL) -o glibc.pkg.tar.zst

fakeroot-tcp.pkg.tar.zst:
	@echo -e '\e[1;31mDownloading fakeroot-tcp.pkg.tar.zst...\e[m'
	$(DLR) $(DLR_FLAGS) $(FRTCP_URL) -o fakeroot-tcp.pkg.tar.zst

base.tar.gz:
	@echo -e '\e[1;31mDownloading base.tar.gz...\e[m'
	$(DLR) $(DLR_FLAGS) $(BASE_URL) -o base.tar.gz

clean: cleanall

cleanall: cleanroot cleanproc cleantmp cleanpkg cleanbase

cleanroot: cleanproc
	-sudo rm -rf root.x86_64
	-rm root.x86_64.tmp
	
cleanproc:
	-sudo umount root.x86_64/sys
	-sudo umount root.x86_64/proc
	-sudo umount root.x86_64/sys
	-sudo umount root.x86_64/proc
	-rm proc-tmp.tmp

cleantmp:
	-rm *.tmp

cleanpkg:
	-rm glibc.pkg.tar.zst
	-rm fakeroot-tcp.pkg.tar.zst

cleanbase:
	-rm base.tar.gz
