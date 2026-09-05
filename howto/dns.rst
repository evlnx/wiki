=============
Servidor DNS
=============
------------------------------------------------------------------
HowTo: Cómo instalar un servidor DNS en CentOS Stream 10/Fedora 44
------------------------------------------------------------------


Descripción
===========
Un servidor DNS traduce nombres de dominio a direcciones IP (resolución directa) e inversamente. Esta guía aborda la implementación autoritativa y recursiva con BIND 9.


Prerrequisitos
==============

* CentOS Stream 10 y/o Fedora 44.

Vamos a asumir que tenemos dos redes: la pública y la privada. La privada es ``192.168.77.0/24``. El DNS primario vivirá en ``192.168.77.10``.

El dominio a configurar es: ``example.tld``.


Instalación
===========

```bash:/howto/dns/prerrequisitos.bash```


Configuración
=============

/etc/rndc.key
-------------
Para no quedarnos con la llave pre-generada, vamos a generar una nosotros mismos:

```bash:/howto/dns/rndc.bash```

De lo que resulte, vamos a obtener las secciones ``key`` y ``controls``; y las acomodaremos en ``/etc/rndc.key`` y ``/etc/named.conf`` respectivamente.

Ejemplo:

```bash:/howto/dns/rndc.key```

.. note::
    Ver la sección ``/etc/named.conf`` para el ejemplo de controls.

/etc/named.conf
---------------
Debemos cambiar las instancias de ``127.0.0.1`` o ``::1`` en las directivas ``listen-on``, ``listen-on-v6`` y ``allow-query`` a ``localnets`` y ``localhost``.

Ejemplo:

```bash:/howto/dns/named.conf```


/var/named/masters/example.tld.db
---------------------------------
Este archivo contiene varias secciones que requieren algo de explicación:

La '@':
    Este signo se substituye por el valor declarado de ``$ORIGIN``. Es decir, si tienes ``example.tld.`` como el valor de
    ``$ORIGIN``, cada vez que pongas '@' o nada, se substituirá por ``example.tld.``.

Serial '2017041100':
    El serial es un número que debe aumentar cada vez que actualizas una zona para notificarle a los secundarios (esclavos) de que hay cambios. Se estila poner año, mes, día e ID incremental (YYYYMMDDNN).

```bash:/howto/dns/example.tld.db```

Permisos
########
El directorio ``masters`` debe tener como dueño y grupo a ``root:named`` con permisos ``2750``. Los archivos de zona deben pertenecer a ``root:named`` con permisos ``640``.


Servicios
=========

```bash:/howto/dns/servicios.bash```


Verificación y Pruebas
======================
Para certificar la integridad de las zonas, la sintaxis del motor BIND 9 y la resolución DNS autoritativa, ejecuta los siguientes pasos de validación:

1. **Validación sintáctica de la configuración global**:

   .. code:: bash

      # Comprobar la sintaxis de named.conf y archivos incluidos
      named-checkconf -z /etc/named.conf

2. **Validación de consistencia y número serial de la zona**:

   .. code:: bash

      # Verificar integridad estructural y registros de la zona example.tld
      named-checkzone example.tld /var/named/masters/example.tld.db

3. **Estado del servicio y sockets en systemd**:

   .. code:: bash

      # Comprobar que named.service está activo y en ejecución
      systemctl status named.service

      # Verificar sockets escuchando en el puerto 53 (TCP y UDP)
      ss -tulnp | grep ':53 '

4. **Verificación del canal de control RNDC**:

   .. code:: bash

      # Consultar el estado operativo y estadísticas del servidor mediante rndc
      rndc status

5. **Pruebas funcionales de consulta directa con dig**:

   .. code:: bash

      # Consultar el registro SOA de la zona directamente en la IP del servidor
      dig @192.168.77.10 example.tld SOA +short

      # Consultar registros NS y A
      dig @192.168.77.10 example.tld NS +short
      dig @192.168.77.10 ns1.example.tld A +short
      dig @192.168.77.10 mail1.example.tld A +short

      # Verificar respuesta autoritativa negativa (NXDOMAIN) para registros inexistentes
      dig @192.168.77.10 inexistente.example.tld

6. **Monitoreo de bitácoras del demonio**:

   .. code:: bash

      # Inspeccionar advertencias o rechazos en las bitácoras del sistema
      journalctl -u named.service -e --no-pager


Problemática
============

Permisos incorrectos en archivos de zona (Permission Denied)
-----------------------------------------------------------
Si BIND falla al cargar una zona o reporta errores de acceso, confirma que los permisos y propietarios correspondan a ``root:named``:

.. code:: bash

   # Asignar propietario y permisos estrictos FHS
   chown -R root:named /var/named/masters
   chmod 2750 /var/named/masters
   chmod 640 /var/named/masters/*.db

Bloqueos por SELinux al alojar zonas en rutas no estándar
---------------------------------------------------------
Si los archivos de zona se almacenan fuera de ``/var/named`` o fueron restaurados desde un respaldo:

.. code:: bash

   # Restaurar el contexto SELinux predeterminado de BIND (named_zone_t)
   restorecon -Rv /var/named

Bloqueos en el cortafuegos (Puerto 53 UDP/TCP)
----------------------------------------------
El protocolo DNS opera primordialmente sobre UDP 53, pero requiere TCP 53 para transferencias de zona (AXFR/IXFR) y respuestas truncadas:

.. code:: bash

   # Habilitar el servicio dns en firewalld
   firewall-cmd --permanent --add-service=dns
   firewall-cmd --reload


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Documentación oficial de BIND 9: https://bind9.readthedocs.io/


