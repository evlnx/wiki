==============================================================
Servidor de respaldos con Bareos en CentOS Stream 10/Fedora 44
==============================================================

---------------------------------------------------------------------------
HowTo de cómo instalar en GNU/Linux Bareos, NginX, PostgreSQL y PHP-FPM
---------------------------------------------------------------------------

Descripción
===========
Servidor para respaldos automatizados en CentOS Stream 10 y/o Fedora 44. Los respaldos se gestionan a través de Bareos (Backup Archiving Recovery Open Sourced), utilizando NginX, PostgreSQL y PHP-FPM para el panel web Bareos-WebUI.


Prerrequisitos
==============

Instalación del sistema operativo
---------------------------------
Para la instalación base de CentOS Stream 10 o Fedora 44, consulta: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]

Instalación de herramientas y paquetes esenciales
-------------------------------------------------
```bash:/howto/bareos-centos/prerrequisitos.bash```


Procedimiento
=============

NginX
-----

```bash:/howto/bareos-centos/nginx.bash```

.. note::
   `server.name` deberá ser sustituido por el FQDN o dirección asignada al servidor de administración.


PHP-FPM
-------

```bash:/howto/bareos-centos/php-fpm.bash```


SELinux
-------

```bash:/howto/bareos-centos/selinux.bash```


Servicios (NginX y PHP-FPM)
---------------------------

```bash:/howto/bareos-centos/servicios.bash```


Firewall
--------

```bash:/howto/bareos-centos/seguridad.bash```


PostgreSQL
----------

```bash:/howto/bareos-centos/postgresql.bash```


Bareos
------

```bash:/howto/bareos-centos/bareos.bash```

.. note::
    La contraseña y el usuario para el perfil de administración web pueden generarse de manera aleatoria y segura con:

    .. code:: sh

        openssl rand -base64 24

    O mediante:

    .. code:: sh

        cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 30; echo


Verificación y Pruebas
======================
Para validar que el motor de respaldos, el catálogo en PostgreSQL y la interfaz web operan sin inconsistencias, ejecuta las siguientes pruebas:

1. **Estado de los demonios de Bareos y servicios dependientes**:

   .. code:: bash

      # Comprobar estado de los demonios Director, Storage Daemon y File Daemon
      systemctl status bareos-dir.service bareos-sd.service bareos-fd.service

      # Comprobar servicios de base de datos y pila web
      systemctl status postgresql.service nginx.service php-fpm.service

2. **Verificación interactiva del Director y Storage con bconsole**:

   .. code:: bash

      # Consultar el estado del Director
      echo "status dir" | bconsole

      # Consultar el estado de los dispositivos de almacenamiento configurados
      echo "status storage" | bconsole

      # Listar clientes registrados y versión del protocolo
      echo "status client" | bconsole

3. **Ejecución de un respaldo de prueba manual**:

   .. code:: bash

      # Lanzar un trabajo de respaldo del catálogo o archivo local
      echo "run job=BackupCatalog yes" | bconsole

      # Monitorear bitácora de ejecución del trabajo
      echo "messages" | bconsole

4. **Verificación de acceso HTTP al panel Bareos-WebUI**:

   .. code:: bash

      # Probar respuesta de la interfaz web
      curl -I http://127.0.0.1/bareos-webui/


Problemática
============

Fallo de autenticación con PostgreSQL (Ident authentication failed)
-------------------------------------------------------------------
Si ``bareos-dir`` no logra conectar al catálogo, revisa el archivo ``/var/lib/pgsql/data/pg_hba.conf`` para permitir la autenticación por socket o red local mediante SCRAM-SHA-256:

.. code:: bash

   # En /var/lib/pgsql/data/pg_hba.conf:
   # local   bareos          bareos                                  scram-sha-256
   # host    bareos          bareos          127.0.0.1/32            scram-sha-256

   # Recargar configuración del motor
   systemctl reload postgresql.service

Bloqueos por SELinux al escribir en volúmenes de respaldo externos
------------------------------------------------------------------
Si el demonio de almacenamiento (SD) almacena volúmenes en puntos de montaje personalizados:

.. code:: bash

   # Etiquetar el directorio de volúmenes con el tipo de contexto bareos
   semanage fcontext -a -t bareos_var_run_t "/mnt/respaldos(/.*)?"
   restorecon -Rv /mnt/respaldos


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Documentación oficial de Bareos: https://docs.bareos.org/
* Documentación de Nginx: https://nginx.org/en/docs/
* Documentación de PostgreSQL: https://www.postgresql.org/docs/

