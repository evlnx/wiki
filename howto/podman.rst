======
Podman
======
-------------------------------------------------------------------------
HowTo: Cómo gestionar contenedores y pods en CentOS Stream 10 y Fedora 44
-------------------------------------------------------------------------

Descripción
===========
Podman (*Pod Manager*) es el motor de contenedores estándar de nivel empresarial en **CentOS Stream 10** y **Fedora 44**.

Implementa las especificaciones OCI de forma completamente descentralizada y sin demonios (*daemonless*), priorizando la ejecución sin privilegios de root (*rootless* por diseño) e integrando gestión de Pods compartidos, servicios de systemd mediante Quadlets y despliegue declarativo de manifiestos Kubernetes (``podman kube play``).


Prerrequisitos
==============
* Instalación mínima de **CentOS Stream 10** y/o **Fedora 44**.
* Rangos de subordinate UID/GID configurados en ``/etc/subuid`` y ``/etc/subgid`` (asignados automáticamente al crear usuarios en Fedora y CentOS Stream 10).
* Para que los contenedores rootless continúen ejecutándose tras cerrar sesión, habilitar la persistencia de usuario:

  .. code:: sh

     loginctl enable-linger $USER


Instalación
===========
Podman está empaquetado nativamente en los repositorios oficiales de CentOS Stream 10 y Fedora 44:

.. code:: bash

   # Instalar Podman
   dnf -y install podman


Operación Básica Rootless
=========================
A diferencia de motores con demonios centralizados, Podman ejecuta los contenedores directamente bajo el contexto del usuario:

.. code:: bash

   # Descargar y ejecutar contenedor efímero de prueba
   podman run --rm -it alpine cat /etc/os-release

   # Listar contenedores activos
   podman ps

   # Listar todos los contenedores (incluyendo detenidos)
   podman ps -a

   # Descargar imágenes de registro
   podman pull registry.fedoraproject.org/fedora-minimal:latest


Gestión de Pods
===============
Un Pod es una colección de uno o más contenedores que comparten el mismo espacio de red (dirección IP, interfaces y ``localhost``), espacio IPC y límites de recursos (cgroups v2):

.. code:: bash

   # Crear un Pod exponiendo el puerto 8080 del host hacia el puerto 80 del pod
   podman pod create --name web-pod -p 8080:80

   # Inspeccionar los pods activos
   podman pod ps

   # Ejecutar un servidor web dentro del pod
   podman run -d --pod web-pod --name web-service nginx:alpine

   # Ejecutar un contenedor de soporte dentro del mismo pod (se comunican vía localhost)
   podman run -d --pod web-pod --name sidecar-service alpine sh -c "while true; do sleep 3600; done"

   # Comprobar conectividad hacia el Pod
   curl http://127.0.0.1:8080


Almacenamiento y Volúmenes con SELinux
======================================
En CentOS Stream 10 y Fedora 44, SELinux opera en modo Enforcing de forma predeterminada. Para que un contenedor pueda leer o escribir en volúmenes montados desde el host (*bind mounts*), se deben aplicar las banderas de reetiquetado OCI:

* ``:z``: El volumen se etiqueta para ser compartido de forma segura entre múltiples contenedores (contexto ``container_share_t``).
* ``:Z``: El volumen se etiqueta para acceso privado y exclusivo del contenedor actual (contexto ``container_file_t``).

.. code:: bash

   # Crear directorio en el host
   mkdir -p $HOME/srv-data

   # Montar con etiqueta compartida :z
   podman run -d --name storage-app -v $HOME/srv-data:/data:z alpine sleep infinity


Servicios Gestionados con Systemd (Quadlets)
============================================
Quadlet es el estándar declarativo en CentOS Stream 10 y Fedora 44 para ejecutar contenedores como servicios administrados directamente por systemd.

Para servicios de usuario sin root (*rootless*), los archivos se ubican en ``~/.config/containers/systemd/``.
Para servicios de todo el sistema (*rootful*), se ubican en ``/etc/containers/systemd/``.

Crea el archivo ``~/.config/containers/systemd/evalinux-web.container``:

.. code:: ini

   [Unit]
   Description=Servidor Web EVALinux
   After=network-online.target

   [Container]
   Image=registry.fedoraproject.org/fedora-minimal:latest
   Exec=sleep infinity

   [Service]
   Restart=always

   [Install]
   WantedBy=default.target

Activar y controlar el servicio mediante systemd:

.. code:: bash

   # Recargar systemd para que Quadlet compile la unidad
   systemctl --user daemon-reload

   # Iniciar y habilitar el servicio
   systemctl --user enable --now evalinux-web.service

   # Verificar estado del servicio
   systemctl --user status evalinux-web.service


Despliegue Declarativo con Kubernetes YAML
==========================================
Podman permite desplegar pods de forma reproducible mediante manifiestos YAML estándar de Kubernetes:

.. code:: bash

   # Generar manifiesto Kubernetes a partir del pod web-pod
   podman kube generate web-pod > web-pod.yaml

   # Desplegar el pod desde el manifiesto YAML
   podman kube play web-pod.yaml

   # Detener y desmantelar el pod
   podman kube down web-pod.yaml


Configuración de Firewall
=========================
Si el contenedor expone puertos hacia la red local o pública:

.. code:: bash

   # Permitir el puerto de servicio en firewalld
   firewall-cmd --permanent --add-port=8080/tcp
   firewall-cmd --reload


Verificación y Pruebas
======================
Para comprobar el correcto aprovisionamiento, aislamiento y funcionamiento de los contenedores y pods, realiza las siguientes validaciones:

1. **Verificación del entorno Rootless y subsistemas de seguridad**:

   .. code:: bash

      # Comprobar que Podman opera en modo sin privilegios (debe retornar true)
      podman info --format '{{.Host.Security.Rootless}}'

      # Verificar aislamiento de namespaces de usuario y mapeos de UID
      podman unshare id

2. **Estado operativo de Pods y contenedores**:

   .. code:: bash

      # Listar pods activos y cantidad de contenedores asociados
      podman pod ps

      # Listar contenedores con sus nombres, estados de salud y puertos mapeados
      podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

3. **Verificación de servicios Quadlet en systemd**:

   .. code:: bash

      # Confirmar que la unidad compilada por Quadlet está activa
      systemctl --user is-active evalinux-web.service

      # Inspeccionar los registros de inicio del servicio en journald
      journalctl --user-unit evalinux-web.service -e --no-pager

4. **Prueba funcional de conectividad de red**:

   .. code:: bash

      # Probar respuesta HTTP en el puerto publicado del host
      curl -I http://127.0.0.1:8080

5. **Telemetría y consumo de recursos (cgroups v2)**:

   .. code:: bash

      # Inspeccionar uso instantáneo de CPU, memoria y E/S de red
      podman stats --no-stream


Problemática
============

Error de permisos en volúmenes montados (Permission Denied)
-----------------------------------------------------------
Causado comúnmente por políticas de SELinux. Verifica haber agregado la bandera ``:z`` o ``:Z`` al argumento ``-v``/``--volume``:

.. code:: bash

   podman run -v /ruta/host:/ruta/contenedor:Z ...

Falla de mapeo en modo rootless (subuid/subgid)
----------------------------------------------
Si las asignaciones de subordinate UIDs cambian o se corrompen, regenera la configuración de almacenamiento:

.. code:: bash

   podman system migrate


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Sitio oficial de Podman: https://podman.io/
