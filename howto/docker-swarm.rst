=====
Swarm
=====
---------------------------
Instalación y configuración
---------------------------

Describimos como instalar swarm y jugar con él un poco.

Pre-requisitos
==============

Sistema Operativo
-----------------

* Instalación de Fedora o Enterprise Linux (Rocky Linux, AlmaLinux, CentOS Stream, RHEL).
* Red pública para el controlador (ej. ``ens3`` o ``enp1s0``).
* Red privada para los nodos del clúster (ej. ``ens4`` o ``enp2s0``).

Firewall
--------
El firewall debe modificarse para permitir el tráfico del clúster Swarm a través de la interfaz de red privada. Solo abriremos los puertos requeridos:

* ``2377/tcp``: Comunicación para administración del clúster (manager).
* ``7946/tcp`` y ``7946/udp``: Comunicación entre nodos del clúster.
* ``4789/udp``: Tráfico de redes superpuestas (*overlay network*).

.. code:: sh

    # configurar zona privada
    firewall-cmd --permanent --zone=work --add-port=2377/tcp --add-port=7946/tcp --add-port=7946/udp --add-port=4789/udp

    # asignar interfaz privada a la zona work
    nmcli connection modify ens4 connection.zone work

    # aplicar cambios
    firewall-cmd --reload
    nmcli connection up ens4

    # verificar configuración
    firewall-cmd --list-all --zone=work


Instalación
===========
Instalaremos el motor de contenedores en el sistema:

En Fedora (usando el motor Moby estándar de Fedora):

.. code:: sh

    dnf -y install moby-engine
    systemctl enable --now docker.service

En Enterprise Linux (Rocky/Alma/RHEL):

.. code:: sh

    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf -y install docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker.service


Configuración
=============
Debemos iniciar un swarm en el nodo manager y unir los nodos trabajadores (*workers*) a él.


.. code:: bash

    # crear un swarm (manager)
    docker swarm init --advertise-addr 192.168.77.1

    # agregar nodos (nodos)
    # ejecutar ésto en nodos swarm2 y swarm3
    docker swarm join --token <token-generado> 192.168.77.1:2377

    # verificar (manager)
    docker info
    docker node ls


Despliegue
==========
Veremos como desplegar algunas aplicaciones, usando ejemplos simplificados.

.. code:: bash

    # crear un servicio con 1 réplica
    docker service create --replicas 1 --name helloworld alpine ping docker.com
    docker service ls
    docker service rm helloworld


    # crear un servicio con 3 réplicas
    docker service create --replicas 3 --name helloworld alpine ping docker.com
    docker service ls


    # inspeccionar el servicio
    docker service inspect --pretty helloworld


    # escalar
    ## abajo
    docker service scale helloworld=1
    docker service inspect --pretty helloworld

    ## arriba
    docker service scale helloworld=5
    docker service inspect --pretty helloworld
    docker service rm helloworld


    # exponer servicios
    docker service create --name my-web --publish 8080:80 --replicas 3 nginx
    docker service ls
    docker ps

    ## probar
    curl localhost:8080
    curl 192.168.77.1:8080
    curl 104.36.16.224:8080


Referencias
===========
* https://docs.docker.com/engine/swarm/swarm-tutorial/
