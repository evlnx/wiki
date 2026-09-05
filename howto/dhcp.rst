====
DHCP
====
--------------------------------------------
HowTo de como instalar; en GNU & Linux, DHCP
--------------------------------------------

Descripción
===========
Un servidor DHCP ofrece configuración de red a las máquinas conectadas. Es el que se encargará de mantener la red tal cual y la
queramos.


Prerrequisitos
==============

* Enterprise Linux/Fedora (RHEL, Rocky Linux, AlmaLinux o Fedora).
* Al menos dos interfaces de red (una de enlace ascendente/WAN y otra de red local/LAN).


Instalación
===========

```bash:/howto/dhcp/instalacion.bash```


Configuración
=============

```bash:/howto/dhcp/dhcpd.conf```

.. note::
    La dirección MAC declarada en `hardware ethernet` es solo un ejemplo. Debes incluir la dirección física real de la interfaz del cliente a asignar.


Servicios
=========

```bash:/howto/dhcp/servicios.bash```

.. warning::
    Nunca habilites el servicio DHCP en la interfaz conectada a la red pública o WAN/ISP, ya que generarás un conflicto de red severo y fallas operativas inmediatas. Limita la escucha a la interfaz interna o subred LAN.


Probar
======
Para probar, simplemente debes conectar a un cliente en la red interna. En cuanto su interfaz solicite arrendamiento, vas a ver información al respecto en: ``/var/lib/dhcpd/dhcpd.leases``.

Si el cliente es: ``client.example.tld`` y su dirección de hardware coincide con la reservación estática, se le asignará la IP definida en la configuración.


Comandos comunes
================
Estos comandos son para revisar configuraciones y ver información de logs.

Verificar la dirección y estado de nuestras interfaces de red:

.. code:: sh

    ip address

Activar la interfaz de red interna (ej. ``eth1`` o ``enp2s0``):

.. code:: sh

    ip link set dev eth1 up

Desactivar la interfaz de red interna:

.. code:: sh

    ip link set dev eth1 down

Revisar el estado y logs en vivo de la aplicación:

.. code:: sh

    journalctl -u dhcpd.service -f


Problemática
============
Nada por el momento.


Referencias
===========
* https://docs.redhat.com/
* https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol


