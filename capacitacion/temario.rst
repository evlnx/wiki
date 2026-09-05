============
Capacitación
============
-------------------------------------------
Archivo de iniciación en las artes del FOSS
-------------------------------------------

Descripción
===========
Un intento de delimitar cuál es el conocimiento necesario para trabajar en la industria con GNU & Linux; y FOSS en general.


Establecer canales de comunicación
==================================

Email
-----
Servicio de red que permite a los usuarios enviar y recibir mensajes y archivos rápidamente, más información en
http://es.wikipedia.org/wiki/EMail

Es importante saber que hay una etiqueta a seguir, en general, en el mundo de la tecnología (netiquette):
https://en.wikipedia.org/wiki/Etiquette_in_technology

Google Chat
-----------
Aplicación multiplataforma de mensajería instantánea desarrollada por Google Inc., más información en
https://es.wikipedia.org/wiki/Google_Chat

IRC
---
(Internet Relay Chat) Protocolo de comunicación en tiempo real basado en texto, más información en
https://es.wikipedia.org/wiki/Internet_Relay_Chat

Registrarse en Libera.Chat
##########################
Red principal de servidores IRC orientada a proyectos FOSS y software libre (sucesor de Freenode tras la migración masiva comunitaria en 2021). Más información en https://libera.chat/.

Aprender la etiqueta de IRC
###########################
Directrices y buenas prácticas en canales IRC: https://github.com/fizerkhan/irc-etiquette

Matrix
------
Es, al parecer, la evolución natural de IRC (sin serlo directamente). Puedes encontrar más información aquí: https://matrix.org/.

Puedes encontrar los clientes para celular y PC aquí: https://matrix.org/clients/

El cliente que preferimos en EVALinux es Element.

Desde Matrix puedes acceder a canales de IRC y otros protocolos.

Slack
-----
Un cliente de trabajo bastante común. Más información en: https://slack.com/

Teléfonos
---------
Es importante compartir tu contacto con tus colegas; tanto el de tu casa, si tienes, como tu celular. Hay varias ocasiones en las
que es importante estar en contacto y no siempre vemos las notificaciones de la mensajería.


Fundamentales de Linux
======================
* https://www.funtoo.org/Linux_Fundamentals,_Part_1
* https://www.funtoo.org/Linux_Fundamentals,_Part_2
* https://www.funtoo.org/Linux_Fundamentals,_Part_3
* https://www.funtoo.org/Linux_Fundamentals,_Part_4

vim
---
Aprender vim se hace usando el comando: ``vimtutor``.

Como recurso adicional, pudieras probar: https://www.openvim.com/ o buscar algún otro en Google. Hay muchos.

man
---
El manual, por excelencia, en GNU & Linux es man. Es muy importante aprender a usarlo. Para hacerlo, utiliza el comando ``man man``.

info
----
Info es un complemento para man; leer documentación sobre muchos de los comandos. Para aprender info, escribe ``info`` en tu línea
de comando y sigue las instrucciones.

Bash
----
* https://www.funtoo.org/Bash_by_Example,_Part_1
* https://www.funtoo.org/Bash_by_Example,_Part_2
* https://www.funtoo.org/Bash_by_Example,_Part_3

grep
----
Para aprender grep, utiliza el comando ``info grep`` y sigue las instrucciones.

awk
---
* https://www.funtoo.org/Awk_by_Example,_Part_1
* https://www.funtoo.org/Awk_by_Example,_Part_2
* https://www.funtoo.org/Awk_by_Example,_Part_3

sed
---
* https://www.funtoo.org/Sed_by_Example,_Part_1
* https://www.funtoo.org/Sed_by_Example,_Part_2
* https://www.funtoo.org/Sed_by_Example,_Part_3

OpenSSH
-------
Protocolo estándar de administración y conectividad remota cifrada.

* Consulta nuestro manual en el wiki: ``howto/ssh/instalacion.rst``
* Documentación oficial: https://www.openssh.com/manual.html

find
----
Utilidad de búsqueda recursiva de archivos y directorios según criterios de tiempo, tamaño, tipo y permisos.

* Manual: ``man find``
* https://www.gnu.org/software/findutils/

rsync
-----
Herramienta de sincronización y copia delta eficiente de archivos tanto local como remotamente por SSH.

* Manual: ``man rsync``
* https://rsync.samba.org/

git
---
Sistema distribuido de control de versiones estándar de la industria.

* Libro oficial (*Pro Git*): https://git-scm.com/book/en/v2

KVM/QEMU y libvirt
==================
Solución de virtualización completa nativa del kernel de Linux combinada con emulación de hardware y la API unificada de gestión de hipervisores.

* KVM: https://www.linux-kvm.org/
* QEMU: https://www.qemu.org/docs/master/
* libvirt: https://libvirt.org/

Contenedores (Podman)
=====================

Podman
------
Motor de contenedores estándar en CentOS Stream 10 y Fedora 44. Es una solución sin demonio (*daemonless*), de ejecución sin privilegios de root (*rootless* por diseño) e interoperable con especificaciones OCI. Incorpora gestión de Pods, soporte nativo de manifiestos Kubernetes (``podman kube play``) e integración nativa con systemd mediante Quadlets.

* Guía en este wiki: ``howto/podman.rst``
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Sitio oficial: https://podman.io/


Linux (kernel)
==============
* https://www.kernel.org/doc/html/latest/

cgroups v2
----------
Jerarquía unificada del kernel para aislar, controlar y contabilizar el consumo de recursos (CPU, memoria, I/O) de grupos de procesos, estándar obligatorio en CentOS Stream 10 y Fedora 44.

* Manual: ``man cgroups``
* Guía cgroup-v2: https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html

Syscalls
--------
Puntos de entrada e interfaz programática fundamental entre el espacio de usuario (*user space*) y el kernel (*kernel space*).

* Manual: ``man syscalls``

Procesos
--------
Estructura y gestión del ciclo de vida de procesos en GNU/Linux, señales POSIX, estados (running, sleeping, zombie) y monitoreo con herramientas como ``ps``, ``top`` y ``systemd-cgls``.

Seguridad
---------
Principios de mínimo privilegio, auditoría del sistema con el subsistema ``auditd``, capacidades POSIX (*capabilities*) y aislamiento de espacios de nombres (*namespaces*).

Hardware
--------
Inspección e interacción con hardware del sistema (PCI, USB, bloques de almacenamiento) mediante ``lspci``, ``lsusb``, ``lsblk`` y el pseudo-sistema de ficheros ``/sys`` y ``/proc``.


Redes
=====

TCP/IP
------
Pila fundamental de protocolos de comunicación para interconexión de redes y transporte de datos fiable orientado a conexión.

UDP
---
Protocolo de datagramas no orientado a conexión y de baja latencia utilizado en DNS, streaming y consultas ligeras.

Modelo OSI
----------
Modelo de referencia conceptual de siete capas para estructurar e intercomunicar sistemas de red:

* https://en.wikipedia.org/wiki/OSI_model


Seguridad
=========

iptables
--------
Subsistema legado de filtrado de paquetes y tablas de traducción de direcciones (NAT) en el kernel de Linux.

nftables
--------
Subsistema moderno y unificado del kernel de Linux para clasificación, filtrado y enrutamiento de paquetes de red, reemplazo oficial de iptables.

* https://wiki.nftables.org/

firewalld
---------
Demonio de gestión dinámica de cortafuegos estándar en CentOS Stream 10 y Fedora 44, con soporte para zonas, servicios declarativos y backend nativo nftables.

* Documentación oficial de Red Hat: https://docs.redhat.com/
* Sitio oficial: https://firewalld.org/

SELinux
-------
Módulo de seguridad del kernel de Linux que implementa Control de Acceso Mandatorio (MAC) mediante políticas y contextos de seguridad (usuarios, roles y tipos).

* Documentación oficial de Red Hat: https://docs.redhat.com/


Servicios web
=============

Nginx
-----
Servidor web de arquitectura dirigida por eventos (*event-driven*), proxy inverso y terminador TLS/SSL de alto rendimiento.

* Guía LEMP en este wiki: ``howto/lemp.rst``
* https://nginx.org/en/docs/

PHP
---
Lenguaje de programación interpretado ampliamente extendido para aplicaciones web dinámicas, servido en entornos modernos mediante el gestor de procesos FastCGI (``php-fpm``).

* https://www.php.net/manual/es/

Apache HTTPD
------------
Servidor web modular y clásico de la Apache Software Foundation.

* https://httpd.apache.org/docs/


Bases de datos
==============

MariaDB/MySQL
-------------
Sistemas de gestión de bases de datos relacionales SQL con soporte para transacciones ACID y alta disponibilidad.

* https://mariadb.com/kb/es/

MongoDB
-------
Base de datos orientada a documentos NoSQL de esquema flexible basada en formato BSON.

* https://www.mongodb.com/docs/

PostgreSQL
----------
Sistema gestor de base de datos relacional y objeto-relacional altamente avanzado, robusto, extensible y con estricto apego a estándares SQL.

* https://www.postgresql.org/docs/


Infraestructura
===============

Ansible
-------
Herramienta de automatización, orquestación y aprovisionamiento de configuración sin agentes (*agentless*) mediante playbooks declarativos en YAML y transporte SSH.

* https://docs.ansible.com/

MRTG/sFlow
----------
Herramientas clásicas y protocolos de muestreo para telemetría, monitoreo de interfaces y tráfico de red en tiempo real.

Puppet
------
Plataforma de gestión de configuración declarativa basada en modelos cliente/servidor.

* https://www.puppet.com/docs

Salt (SaltStack)
----------------
Sistema de orquestación y gestión remota basada en bus de eventos ZeroMQ.

* https://docs.saltproject.io/

Terraform
---------
Herramienta declarativa para aprovisionamiento de Infraestructura como Código (IaC) multicloud.

* https://developer.hashicorp.com/terraform/docs

Zabbix
------
Plataforma integral y distribuida de monitorización de infraestructura, servidores, redes y métricas en tiempo real.

* https://www.zabbix.com/documentation/current/


Extras
======

Crystal
-------
Lenguaje de programación compilado, fuertemente tipado, con sintaxis elegante inspirada en Ruby y concurrencia moderna por fibras. Nuestro lenguaje principal de elección.

* https://crystal-lang.org/

HTML, CSS y Javascript
----------------------
Fundamentos y estándares abiertos de la web moderna para estructura, diseño visual y dinamismo en el cliente.

Python
------
Lenguaje de programación interpretado multipropósito para scripting, automatización de sistemas, ingeniería de datos y desarrollo backend.

* https://docs.python.org/3/

Ruby
----
Lenguaje dinámico, reflexivo y enfocado en la simplicidad y productividad del desarrollador.

* https://www.ruby-lang.org/es/documentation/


Documentación
=============

Markdown
--------
Formato de marcado ligero comúnmente empleado en foros técnicos, plataformas de repositorios (GitLab, GitHub) y documentación rápida.

* https://www.markdownguide.org/

reStructuredText
----------------
Estándar de documentación técnica preferido por su rigor sintáctico, extensibilidad semántica y capacidad nativa para compilar hacia múltiples formatos (HTML, PDF, manuales man, ePub) mediante docutils y Sphinx.

* https://docutils.sourceforge.io/rst.html

Recursos válidos y Referencias
------------------------------
#. Documentación oficial de Red Hat (https://docs.redhat.com/)
#. Documentación de Fedora (https://docs.fedoraproject.org/)
#. Documentación de CentOS Stream (https://www.centos.org/centos-stream/)
#. Páginas de manual oficiales del sistema (man-pages)

