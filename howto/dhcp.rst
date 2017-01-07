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

#. Tener una red privada en "eth1".


Instalación
===========
```bash:/howto/dhcp/instalacion```


DHCP
====

```bash:/howto/dhcp/dhcpd```

.. note::

    "ip a" es para verificar las conexiones con las que se cuenta.
    "journalctl -u dhcpd" es para revisar el estado constante de la aplicación.

.. warning::

    NUNCA ESTABLECER LA CONEXIÓN EN BASE A DHCP AL PORVEEDOR DE INTERNET (eth0)


Referencias
===========
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-DHCP_Servers.html
