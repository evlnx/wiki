# crear punto de montaje
mkdir -p /mnt/compartido

# montar manualmente
mount -t nfs 192.168.77.10:/srv/nfs/compartido /mnt/compartido
