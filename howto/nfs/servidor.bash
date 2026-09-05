# crear directorio compartido
mkdir -p /srv/nfs/compartido
chmod 775 /srv/nfs/compartido

# configurar exportación en /etc/exports
cat << 'EOF' > /etc/exports
/srv/nfs/compartido 192.168.77.0/24(rw,sync,no_root_squash)
EOF

# aplicar cambios de exportación
exportfs -arv
systemctl restart nfs-server.service

