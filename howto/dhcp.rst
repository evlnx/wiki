====
DHCP
====
--------------------------------------
HowTo de como instalar; en Linux, DHCP
--------------------------------------

Descripción
===========
Éste es un servidor instalado en CentOS 7. Consta de una red privada previamente conectada.

Prerrequisitos
==============

yum install dhcp.
yum install NetworkManager


DHCP
====
# configurar el archivo /etc/dhcp/dhcpd.conf.
```bash:/howto/dhcp/dhcpd```
# "ip a" es para verificar las direcciones IP con las que se cuenta.
# "journalctl -u dhcpd" es para revisar el estado continuamente de la aplicación.
# "nmtui" un gestor gráfico para configurar redes.
# MODIFICAR UNA CONEXIÓN
#     Establecerla como manual
#     Añadir la dirección deseada, yo utilicé 10.0.0.10/24.
#     Añadir la búsqueda de dominios requerida.
#     Activar la opción de "nunca usar...".
#     Activar la opción de "ignorar rutas obtenidas automáticamente.
# ACTIVAR LA CONEXIÓN
# NUNCA ESTABLECER LA CONEXIÓN EN BASE A DHCP AL PORVEEDOR DE INTERNET (eth0)
