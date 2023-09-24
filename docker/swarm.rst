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

* Instalación mínima de Fedora 25
* Red pública para el controlador (ens3)
* Red privada para los nodos (ens4)

Firewall
--------
El firewall debe modificarse para permitir acceso de/a swarm por la interfaz de red privada. Solo abriremos los puertos necesarios.

.. code:: bash

    # configurar zona
    firewall-cmd --permanent --zone=work --add-port=2377/tcp --add-port=7946/tcp --add-port=7946/udp --add-port=4789/udp

    # modificar la zona de ens4
    nmcli connection modify ens4 connection.zone work

    # activar
    firewall-cmd --full-reload
    nmcli connection reload ens4

    # verificar
    nmcli connection show ens4

    firewall-cmd --list-all
    firewall-cmd --list-all --zone=work


Instalación
===========
Instalaremos la versión más reciente en los repositorios de Fedora.

.. code:: bash

    # instalar
    dnf -y install docker-latest

    # activar
    systemctl enable docker-latest
    systemctl start docker-latest


Configuración
=============
Debemos iniciar un swarm y unir los nodos a él.

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
