# agregar usuario admin a BareOS
cat << 'EOF' > /etc/bareos/bareos-dir.d/console/admin.conf
Console {
  Name = admin
  Password = "Gevvirt4slyttinnEdErthoobchilU"
  Profile = "webui-admin"
}

EOF

# activar e iniciar servicios de Bareos
systemctl enable --now bareos-dir.service bareos-sd.service bareos-fd.service
 
