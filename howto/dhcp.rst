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

```bash:/howto/dhcp/servicios```

.. note::

    `ip address` es para verificar las conexiones con las que se cuenta.

.. note::

    `journalctl -fu dhcpd` es para revisar los logs que la aplicación registra.

.. warning::

    Nunca habilitar DHCP para la interfaz pública (eth0) porque podemos causar grandes problemas para nuestro ISP.


Referencias
===========
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-DHCP_Servers.html
