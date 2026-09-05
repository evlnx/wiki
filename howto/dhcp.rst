====
DHCP
====
----------------------------------------------------------------
HowTo: Cómo instalar DHCP en GNU/Linux (CentOS Stream 10/Fedora 44)
----------------------------------------------------------------

Descripción
===========
Un servidor DHCP ofrece configuración dinámica de red a los equipos clientes conectados en el segmento local.

Prerrequisitos
==============

* CentOS Stream 10 y/o Fedora 44.
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


Verificación y Pruebas
======================
Para comprobar la consistencia sintáctica, la asignación de arrendamientos y el funcionamiento del servidor DHCP, ejecuta las siguientes validaciones:

1. **Validación sintáctica del archivo de configuración**:

   .. code:: bash

      # Comprobar la sintaxis de dhcpd.conf antes de recargar
      dhcpd -t -cf /etc/dhcp/dhcpd.conf

2. **Estado operativo y socket de escucha en systemd**:

   .. code:: bash

      # Verificar que el servicio esté activo y sin fallos
      systemctl status dhcpd.service

      # Verificar que el demonio esté escuchando en el socket UDP 67 (bootps)
      ss -u4lnp | grep ':67'

3. **Monitoreo de bitácoras de asignación (DORA)**:

   .. code:: bash

      # Inspeccionar eventos DHCPDISCOVER, DHCPOFFER, DHCPREQUEST y DHCPACK
      journalctl -u dhcpd.service -e --no-pager

4. **Inspección de la base de datos de arrendamientos activos**:

   .. code:: bash

      # Revisar las concesiones registradas por el servidor
      cat /var/lib/dhcpd/dhcpd.leases

5. **Prueba funcional desde un cliente en la red local**:

   .. code:: bash

      # Liberar y solicitar un nuevo arrendamiento en el cliente
      dhclient -v -r eth0 && dhclient -v eth0

      # Comprobar la IP y máscara asignadas por DHCP
      ip address show dev eth0


Problemática
============

Bloqueo en el cortafuegos para solicitudes broadcast
-----------------------------------------------------
Los clientes DHCP envían peticiones broadcast a ``255.255.255.255:67``. Si Firewalld bloquea el tráfico entrante:

.. code:: bash

   # Habilitar el servicio dhcp en la zona de la interfaz LAN interna
   firewall-cmd --permanent --zone=internal --add-service=dhcp
   firewall-cmd --reload

Restricción del demonio a una interfaz específica
-------------------------------------------------
Para evitar que ``dhcpd`` intente responder solicitudes en interfaces públicas o deseadas para otros propósitos, especifica la interfaz explícita en ``/etc/sysconfig/dhcpd``:

.. code:: bash

   # En /etc/sysconfig/dhcpd:
   # DHCPDARGS="eth1"

   # Reiniciar el servicio
   systemctl restart dhcpd.service


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Base de conocimientos ISC DHCP: https://kb.isc.org/


