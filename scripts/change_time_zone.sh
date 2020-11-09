# Delete any existing localtime link
sudo rm /etc/localtime
# Update time clock file with ZONE property
sudo vi /etc/sysconfig/clock
#Update the ZONE property to what you want say
ZONE="Asia/Dubai"
sudo ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
sudo reboot
