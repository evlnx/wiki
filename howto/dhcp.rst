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

#. Tener una red pública en "eth0".
#. Tener una red privada en "eth1".
#. Es necesario tener una red privada.
#. Instalar los paquetes necesarios.

    yum install dhcp NetworkManager


Activar la red privada
======================

```bash
# Entrar al configurador de redes.
nmtui
```

Modificar una conexión
______________________
#. Seleccionar la red "eth1".
#. Establecerla como manual.
#. Añadir la dirección deseada.
#. Agregar la búsqueda de dominios requerida.
#. Activar la opción de "nunca usar...".
#. Activar la opción de "ignorar rutas obtenidas automáticamente"

Activar una conexión
____________________
#. Activar la red "eth1".


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
