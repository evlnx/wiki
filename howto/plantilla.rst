====================
Título del Servicio
====================
----------------------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------------------

Descripción
===========
Breve descripción técnica del servicio o herramienta, su propósito dentro de la infraestructura y los beneficios que aporta.

Mencionar si implementa especificaciones estándar (OCI, POSIX, IETF) o particularidades relevantes para **CentOS Stream 10** y **Fedora 44**.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Privilegios de superusuario (acceso mediante ``sudo``).
* Políticas de SELinux en modo Enforcing activas.
* Acceso a repositorios oficiales y, de ser necesario, EPEL (``epel-release``).


Instalación
===========
Indicar los paquetes del sistema requeridos utilizando ``dnf``:

.. code:: bash

   # Actualizar metadatos e instalar paquetes
   dnf -y install <nombre-paquete>


Configuración
=============
Detallar las directivas de configuración, rutas FHS estandarizadas y archivos necesarios.

.. code:: ini

   # Archivo: /etc/<servicio>/config.conf
   [section]
   option = value

Habilitación e Inicio de Servicios
----------------------------------
Siempre habilitar e iniciar servicios atómicamente con ``systemctl enable --now``:

.. code:: bash

   # Habilitar e iniciar inmediatamente el servicio
   systemctl enable --now <servicio>.service

   # En caso de contenedores rootless gestionados por Quadlet:
   systemctl --user enable --now <servicio>.service


Configuración de Cortafuegos y Red
----------------------------------
Abrir exclusivamente los puertos necesarios en ``firewalld``:

.. code:: bash

   # Permitir puerto en zona activa
   firewall-cmd --permanent --add-service=<servicio>
   # O por puerto:
   # firewall-cmd --permanent --add-port=<puerto>/tcp
   firewall-cmd --reload


Verificación y Pruebas
======================
Procedimientos para validar el correcto funcionamiento del servicio:

1. **Estado del servicio**:

   .. code:: bash

      systemctl status <servicio>.service

2. **Monitoreo de bitácoras (logs)**:

   .. code:: bash

      journalctl -u <servicio>.service -e --no-pager

3. **Prueba funcional**:

   .. code:: bash

      curl -I http://127.0.0.1:<puerto>/


Problemática
============

Bloqueos por SELinux (Permission Denied)
----------------------------------------
Si el servicio falla al acceder a archivos o sockets no convencionales, inspeccionar la bitácora de auditoría:

.. code:: bash

   ausearch -m avc -ts recent
   # Para ajustar contextos permanentes:
   semanage fcontext -a -t <contexto_t> "/ruta(/.*)?"
   restorecon -Rv /ruta

Falla de resolución de red o cortafuegos
----------------------------------------
Verificar que la zona activa contenga la regla:

.. code:: bash

   firewall-cmd --list-all


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación oficial de Fedora: https://docs.fedoraproject.org/
* Documentación oficial de CentOS Stream: https://www.centos.org/centos-stream/
* Documentación upstream del proyecto: https://example.org/
