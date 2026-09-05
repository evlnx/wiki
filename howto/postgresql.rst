=================================================================
Servidor PostgreSQL con Replicación en Caliente y Respaldo Físico
=================================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
PostgreSQL es un sistema de gestión de bases de datos objeto-relacional (ORDBMS) de nivel empresarial, con soporte integral para el estándar SQL, cumplimiento estricto de propiedades ACID (Atomicidad, Consistencia, Aislamiento y Durabilidad) y arquitectura basada en procesos independientes (*process-per-backend*) coordinados mediante memoria compartida, registro previo en bitácora (*Write-Ahead Logging* o WAL) y control de concurrencia multiversión (*Multi-Version Concurrency Control* o MVCC).

En entornos de infraestructura de misión crítica, la disponibilidad continua y la protección contra pérdida de datos se garantizan implementando replicación física en flujo (*Physical Streaming Replication*) en caliente (*Hot Standby*) combinada con archivado continuo de segmentos WAL (*Continuous Archiving*). Esta arquitectura permite mantener uno o más servidores secundarios sincronizados a nivel de bloque binario con el servidor primario, habilitando balanceo de carga para consultas de sólo lectura y conmutación por error (*failover*) sin pérdida de transacciones.

En **CentOS Stream 10** y **Fedora 44**, PostgreSQL está empaquetado nativamente en sus versiones 17 y 18, incorporando subsistemas de E/S asíncrona (*Asynchronous I/O* o AIO), soporte para identificadores secuenciales temporales RFC 9562 (``uuidv7()``), sincronización de ranuras de replicación entre nodos primarios y secundarios (``sync_replication_slots``), integración estricta con políticas SELinux en modo Enforcing y orquestación con ``systemd``.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Acceso como superusuario (cuenta ``root``).
* Políticas de SELinux activas en modo Enforcing (verificar con ``getenforce``).
* Dos servidores dedicados conectados mediante una red privada local segura:

  .. list-table::
     :widths: 25 25 20 30
     :header-rows: 1

     * - Rol del Servidor
       - Nombre de Host (FQDN)
       - Dirección IP
       - Propósito
     * - Servidor Primario
       - ``pg-primary.lab.evalinux.com``
       - ``192.168.10.10/24``
       - Escrituras/lecturas y emisión de WAL
     * - Servidor Secundario
       - ``pg-standby.lab.evalinux.com``
       - ``192.168.10.20/24``
       - Replicación en caliente (sólo lectura)

* Almacenamiento dedicado o punto de montaje independiente para el directorio de datos (``/var/lib/pgsql/data``) montado sobre un sistema de archivos XFS o ext4 con la opción ``noatime`` para maximizar el rendimiento transaccional de disco.
* Directorio dedicado para el repositorio local de archivado WAL (``/var/lib/pgsql/wal_archive``) con permisos restringidos.


Instalación
===========
En **CentOS Stream 10** y **Fedora 44**, los paquetes oficiales de PostgreSQL y sus módulos extendidos están disponibles a través de los repositorios predeterminados del sistema:

.. code-block:: bash

   # Actualizar metadatos del repositorio e instalar el motor y extensiones
   dnf -y install postgresql-server postgresql-contrib

El paquete ``postgresql-server`` proporciona el binario principal ``postgres``, la unidad de servicio para systemd (``postgresql.service``), la herramienta de inicialización y mantenimiento ``postgresql-setup``, y utilidades clave de administración como ``pg_basebackup``. El paquete ``postgresql-contrib`` añade herramientas esenciales de inspección forense e integridad física como ``pg_amcheck`` y extensiones de catálogo como ``pg_stat_statements``.


Configuración
=============

Inicialización del Clúster de Datos
-----------------------------------
En distribuciones de la familia RHEL y Fedora, la inicialización del directorio de clúster principal debe realizarse mediante el asistente estandarizado ``postgresql-setup``.

.. code-block:: bash

   # Inicializar el clúster con cálculo de checksums en bloques de datos
   postgresql-setup --initdb --data-checksums

El parámetro ``--data-checksums`` activa la verificación mediante sumas de verificación (*checksums*) en cada bloque de datos escrito en disco, lo que permite detectar inmediatamente corrupción silenciosa (*bit-rot*) o degradación a nivel de controlador de almacenamiento antes de que se propague a los registros de transacción.

Si se utiliza un volumen dedicado montado en ``/var/lib/pgsql/data``, asegúrese de que el propietario sea exclusivamente la cuenta del sistema ``postgres``:

.. code-block:: bash

   # Ajustar propiedad y permisos estrictos en el directorio de clúster
   chown -R postgres:postgres /var/lib/pgsql/data
   chmod 700 /var/lib/pgsql/data

Ajuste de Rendimiento en postgresql.conf
----------------------------------------
Edite el archivo de configuración del servidor principal en ``/var/lib/pgsql/data/postgresql.conf`` en el nodo primario para afinar parámetros de memoria, concurrencia de E/S y generación de bitácora WAL:

.. code-block:: ini

   # Archivo: /var/lib/pgsql/data/postgresql.conf (Nodo Primario)
   # Red y Conectividad
   listen_addresses = '*'
   port = 5432
   max_connections = 150

   # Gestión de Memoria (Valores base recomendados para nodo con 8GB RAM)
   shared_buffers = 2GB                  # 25% del total de memoria RAM del sistema
   work_mem = 16MB                       # Memoria asignada por operación de ordenamiento/hash
   maintenance_work_mem = 512MB          # Memoria para autovacuum, índices y respaldos
   effective_cache_size = 6GB            # 75% del total de memoria para el planificador CBO

   # Optimizador y Almacenamiento NVMe/SSD
   random_page_cost = 1.1                # Costo de acceso aleatorio en discos de estado sólido
   effective_io_concurrency = 200        # Peticiones de E/S paralelas simultáneas al kernel

   # Registro en Bitácora Transaccional (WAL) y Puntos de Control (Checkpoints)
   wal_level = replica                   # Información requerida para streaming replication
   max_wal_senders = 10                  # Número máximo de procesos walsender simultáneos
   max_replication_slots = 10            # Límite de ranuras de replicación persistentes
   wal_keep_size = 1GB                   # Volumen mínimo de WAL retenido en pg_wal
   checkpoint_timeout = 15min            # Intervalo máximo entre puntos de control
   checkpoint_completion_target = 0.9    # Amortigua el impacto de escritura de páginas sucias
   max_wal_size = 16GB                   # Límite superior suave de WAL antes de forzar checkpoint
   min_wal_size = 1GB                    # Volumen mínimo de WAL reciclado

   # Archivado Continuo de WAL (Point-In-Time Recovery)
   archive_mode = on
   archive_command = 'test ! -f /var/lib/pgsql/wal_archive/%f && cp %p /var/lib/pgsql/wal_archive/%f'

   # Criptografía y Seguridad
   password_encryption = scram-sha-256

Cree el directorio de archivado continuo con los permisos del demonio:

.. code-block:: bash

   # Crear directorio local de archivado WAL en el servidor primario
   mkdir -p /var/lib/pgsql/wal_archive
   chown -R postgres:postgres /var/lib/pgsql/wal_archive
   chmod 700 /var/lib/pgsql/wal_archive

Control de Accesos y Seguridad en pg_hba.conf
---------------------------------------------
El archivo ``/var/lib/pgsql/data/pg_hba.conf`` regula la autenticación basada en host (*Host-Based Authentication*). Las reglas se procesan en estricto orden secuencial. Configure una política de autenticación robusta mediante contraseñas cifradas con SCRAM-SHA-256:

.. code-block:: ini

   # Archivo: /var/lib/pgsql/data/pg_hba.conf (Nodo Primario)
   # TYPE  DATABASE        USER            ADDRESS                 METHOD

   # Conexiones administrativas locales mediante socket UNIX del sistema
   local   all             postgres                                peer
   local   all             all                                     peer

   # Replicación física local vía socket UNIX
   local   replication     all                                     peer

   # Replicación física desde el nodo secundario con SCRAM-SHA-256
   host    replication     replicator      192.168.10.20/32        scram-sha-256

   # Acceso de clientes y servicios desde la subred privada de confianza
   host    all             all             192.168.10.0/24         scram-sha-256

   # Acceso local por TCP en bucle de retorno (loopback)
   host    all             all             127.0.0.1/32            scram-sha-256
   host    all             all             ::1/128                 scram-sha-256

Creación del Rol de Replicación en el Nodo Primario
---------------------------------------------------
Para permitir que el nodo secundario extraiga el respaldo inicial y reciba el flujo continuo de WAL, inicie el servicio en el nodo primario y cree el usuario dedicado con privilegios de replicación:

.. code-block:: bash

   # Iniciar el servicio PostgreSQL en el nodo primario
   systemctl start postgresql.service

   # Crear el rol de replicación ejecutando la sentencia interactiva en psql
   su - postgres -c "psql -c \"CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'ClaveUltraSeguraReplicacion2026!';\""

   # Validar la existencia y atributos del rol creado
   su - postgres -c "psql -c '\du replicator'"

Aprovisionamiento del Nodo Secundario con pg_basebackup
-------------------------------------------------------
En el servidor secundario (``pg-standby.lab.evalinux.com``), el clúster no debe inicializarse mediante ``postgresql-setup``; en su lugar, se sincroniza el estado binario completo del primario utilizando la herramienta ``pg_basebackup``.

#. Asegúrese de que el servicio PostgreSQL se encuentre detenido y que el directorio de datos esté limpio:

   .. code-block:: bash

      # Detener el servicio en el nodo secundario si estuviese activo
      systemctl stop postgresql.service

      # Limpiar o asegurar que el directorio de datos destino esté vacío
      rm -rf /var/lib/pgsql/data/*

#. Ejecute ``pg_basebackup`` conectándose al servidor primario como usuario del sistema ``postgres``:

   .. code-block:: bash

      # Ejecución del respaldo base en frío para replicación en flujo
      su - postgres -c "pg_basebackup -h 192.168.10.10 -p 5432 -U replicator \
         -D /var/lib/pgsql/data -Fp -Xs -R -P"

   Parámetros aplicados:

   * ``-h 192.168.10.10``: Dirección IP del servidor primario.
   * ``-p 5432``: Puerto TCP de escucha de PostgreSQL.
   * ``-U replicator``: Rol con privilegios de replicación creado previamente.
   * ``-D /var/lib/pgsql/data``: Directorio local destino para el clúster.
   * ``-Fp``: Formato plano (*plain format*), escribe la estructura de directorios idéntica al primario.
   * ``-Xs``: Modo de flujo (*stream*), incluye los registros WAL generados durante el respaldo en un segundo hilo concurrente.
   * ``-R``: Escribe automáticamente la configuración de recuperación: crea el archivo testigo ``standby.signal`` y escribe la directiva ``primary_conninfo`` en ``postgresql.auto.conf``.
   * ``-P``: Habilita la barra de progreso en tiempo real durante la transferencia.

#. Verifique la generación del archivo de señal de espera y la cadena de conexión en el nodo secundario:

   .. code-block:: bash

      # Inspeccionar el archivo indicador de modo de recuperación (vacío por diseño)
      ls -la /var/lib/pgsql/data/standby.signal

      # Verificar la cadena generada en postgresql.auto.conf
      cat /var/lib/pgsql/data/postgresql.auto.conf

#. Para optimizar la estabilidad de las consultas de lectura en el nodo secundario, agregue la retroalimentación de transacciones en ``/var/lib/pgsql/data/postgresql.auto.conf`` del secundario:

   .. code-block:: ini

      # Parámetros adicionales en /var/lib/pgsql/data/postgresql.auto.conf (Secundario)
      hot_standby = on
      hot_standby_feedback = on

   La directiva ``hot_standby_feedback = on`` notifica al primario sobre las transacciones activas en el secundario, evitando que el proceso ``autovacuum`` del primario limpie tuplas muertas que aún son necesarias para consultas de larga duración en el secundario.

#. Verifique que la propiedad y los permisos en el nodo secundario sean estrictos:

   .. code-block:: bash

      chown -R postgres:postgres /var/lib/pgsql/data
      chmod 700 /var/lib/pgsql/data

Habilitación e Inicio de Servicios
----------------------------------
Habilite e inicie el servicio PostgreSQL en ambos nodos de forma atómica con ``systemctl enable --now``:

.. code-block:: bash

   # En el Servidor Primario (pg-primary):
   systemctl enable --now postgresql.service

   # En el Servidor Secundario (pg-standby):
   systemctl enable --now postgresql.service

Configuración de Cortafuegos y Red
----------------------------------
En **CentOS Stream 10** y **Fedora 44**, ``firewalld`` opera como el demonio dinámico de gestión de cortafuegos. Nunca exponga el puerto de base de datos a redes públicas no filtradas. Configure reglas sustanciosas (*Rich Rules*) para admitir tráfico en el puerto 5432/tcp exclusivamente desde la subred privada de infraestructura o el nodo secundario:

.. code-block:: bash

   # En el Servidor Primario: autorizar conexiones de la subred privada de base de datos
   firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.10.0/24" port port="5432" protocol="tcp" accept'

   # En ambos servidores: recargar reglas para aplicar cambios en memoria
   firewall-cmd --reload

   # Validar las reglas activas de la zona predeterminada
   firewall-cmd --list-all


Verificación y Pruebas
======================
Siga este procedimiento paso a paso para validar la salud del clúster, la replicación en flujo y el aislamiento de sólo lectura en el nodo secundario:

#. **Estado de los servicios del sistema**:

   .. code-block:: bash

      # Verificar que el servicio esté activo y sin fallos en ambos nodos
      systemctl status postgresql.service

#. **Monitoreo de bitácoras del sistema**:

   .. code-block:: bash

      # Inspeccionar el registro en tiempo real de systemd journald
      journalctl -u postgresql.service -n 50 --no-pager

   En el secundario, la bitácora debe confirmar: ``entering standby mode`` y ``started streaming WAL from primary at ... on timeline 1``.

#. **Inspección de la replicación en el Servidor Primario**:

   Conéctese al nodo primario e invoque la vista administrativa ``pg_stat_replication``:

   .. code-block:: bash

      su - postgres -c "psql -x -c \"SELECT pid, usename, application_name, client_addr, state, sync_state, replay_lsn, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS replay_lag_bytes FROM pg_stat_replication;\""

   El campo ``state`` debe mostrar el valor ``streaming``, ``sync_state`` reflejará ``async`` (o ``sync`` si configuró réplica síncrona), y el cálculo ``replay_lag_bytes`` debe indicar un valor cercano a ``0`` bytes en condiciones normales.

#. **Inspección del estado de recuperación en el Servidor Secundario**:

   Conéctese al nodo secundario y compruebe las funciones del receptor de WAL:

   .. code-block:: bash

      # Comprobar si el nodo opera en modo de recuperación (debe retornar true/t)
      su - postgres -c "psql -c \"SELECT pg_is_in_recovery();\""

      # Inspeccionar la telemetría del proceso receptor de WAL (walreceiver)
      su - postgres -c "psql -x -c \"SELECT sender_host, sender_port, status, received_lsn, latest_end_lsn, latest_end_time FROM pg_stat_wal_receiver;\""

   La salida confirmará que el proceso receptor está en estado ``streaming`` recibiendo datos desde ``192.168.10.10``.

#. **Prueba de extremo a extremo de replicación de datos**:

   Cree una base de datos e inserte registros de prueba en el **Servidor Primario**:

   .. code-block:: sql

      -- En el Servidor Primario (pg-primary):
      CREATE DATABASE lab_evalinux;
      \c lab_evalinux

      CREATE TABLE inventario (
         id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
         dispositivo text NOT NULL,
         cantidad integer NOT NULL,
         creado_el timestamptz DEFAULT now()
      );

      INSERT INTO inventario (dispositivo, cantidad) VALUES
         ('Servidor Dell PowerEdge R650', 4),
         ('Switch de Agregación Arista 7050SX3', 2),
         ('Firewall de Perímetro FortiGate 100F', 2);

   Consulte de inmediato los datos en el **Servidor Secundario**:

   .. code-block:: sql

      -- En el Servidor Secundario (pg-standby):
      \c lab_evalinux
      SELECT id, dispositivo, cantidad, creado_el FROM inventario;

   La consulta retornará de forma instantánea las filas insertadas en el nodo primario.

#. **Verificación de bloqueo de escritura en el Servidor Secundario**:

   Intente realizar una operación de modificación de datos (DML) en el nodo secundario:

   .. code-block:: sql

      -- En el Servidor Secundario (pg-standby):
      INSERT INTO inventario (dispositivo, cantidad) VALUES ('Servidor No Autorizado', 1);

   El motor de base de datos rechazará la instrucción de inmediato con el mensaje de error:

   .. code-block:: text

      ERROR: cannot execute INSERT in a read-only transaction


Problemática
============

Bloqueos por SELinux en Almacenamiento Personalizado
----------------------------------------------------
Si el clúster de base de datos o el repositorio de archivado WAL se ubican en discos independientes o puntos de montaje personalizados fuera de la ruta predeterminada, el demonio fallará al iniciar o archivar debido a denegaciones de política de SELinux (contexto incorrecto).

#. Inspeccione las denegaciones en la bitácora de auditoría de SELinux:

   .. code-block:: bash

      ausearch -m avc -ts recent

#. Defina el contexto persistente ``postgresql_db_t`` para las rutas de almacenamiento de datos y archivado:

   .. code-block:: bash

      # Registrar contexto permanente para el directorio de datos y sus descendientes
      semanage fcontext -a -t postgresql_db_t "/var/lib/pgsql/data(/.*)?"

      # Registrar contexto permanente para el repositorio de archivado continuo
      semanage fcontext -a -t postgresql_db_t "/var/lib/pgsql/wal_archive(/.*)?"

      # Aplicar recursivamente las etiquetas definidas en el sistema de archivos
      restorecon -Rv /var/lib/pgsql

#. Verifique el etiquetado correcto con ``ls -ldZ``:

   .. code-block:: bash

      ls -ldZ /var/lib/pgsql/data /var/lib/pgsql/wal_archive

Fallos de Autenticación con SCRAM-SHA-256
-----------------------------------------
Si el secundario registra el error ``FATAL: password authentication failed for user "replicator"`` durante ``pg_basebackup`` o al conectarse el proceso ``walreceiver``:

#. Compruebe que la directiva ``password_encryption = scram-sha-256`` esté configurada en ``postgresql.conf`` del primario.
#. Regenere la contraseña del usuario de replicación en el primario para forzar el hash SCRAM-SHA-256 (en lugar de MD5 obsoleto):

   .. code-block:: bash

      su - postgres -c "psql -c \"ALTER ROLE replicator WITH ENCRYPTED PASSWORD 'ClaveUltraSeguraReplicacion2026!';\""

#. Valide el orden de registros en ``/var/lib/pgsql/data/pg_hba.conf`` del primario. Las reglas más específicas (como ``host replication replicator 192.168.10.20/32 scram-sha-256``) deben preceder a cualquier regla general que use el método ``reject`` o ``peer``.
#. Tras modificar ``pg_hba.conf``, recargue la configuración en el primario sin reiniciar el demonio:

   .. code-block:: bash

      su - postgres -c "psql -c \"SELECT pg_reload_conf();\""

Desconexión y Retardo de Replicación (Replication Lag)
------------------------------------------------------
Si el secundario pierde la sincronización o el proceso ``walreceiver`` no reporta avances en ``pg_stat_wal_receiver``:

#. Inspeccione si el nodo primario recicló los segmentos WAL antes de que el secundario pudiera transferirlos:

   .. code-block:: bash

      # En el secundario, revisar si se reporta un segmento faltante
      journalctl -u postgresql.service -e --no-pager | grep -i "requested WAL segment"

#. Para evitar que un primario recicle WAL durante desconexiones de red transitorias, configure una ranura de replicación física persistente (*Replication Slot*) en el nodo primario:

   .. code-block:: bash

      # En el Servidor Primario: crear ranura física persistente
      su - postgres -c "psql -c \"SELECT pg_create_physical_replication_slot('standby1_slot');\""

#. En el servidor secundario, agregue la ranura en ``/var/lib/pgsql/data/postgresql.auto.conf``:

   .. code-block:: ini

      primary_slot_name = 'standby1_slot'

#. Recargue o reinicie el servicio en el secundario:

   .. code-block:: bash

      systemctl restart postgresql.service

Saturación de Espacio por Fallos en archive_command
---------------------------------------------------
Si la directiva ``archive_command`` falla (por ejemplo, por falta de permisos en el destino, un directorio inexistente o disco lleno), PostgreSQL continuará acumulando archivos WAL en ``/var/lib/pgsql/data/pg_wal`` indefinidamente hasta agotar el espacio en disco, protegiendo la consistencia transaccional a expensas de la capacidad del sistema de archivos.

#. Verifique el estado del proceso archivador en el nodo primario:

   .. code-block:: bash

      su - postgres -c "psql -x -c \"SELECT archived_count, last_archived_wal, last_archived_time, failed_count, last_failed_wal, last_failed_time FROM pg_stat_archiver;\""

   Si ``failed_count`` es mayor a ``0`` y ``last_failed_time`` es reciente, el archivador está fallando.

#. Compruebe que el comando de archivado pueda ser ejecutado por el usuario ``postgres`` y que la ruta de destino exista:

   .. code-block:: bash

      # Probar permisos de escritura en la ruta de archivado
      su - postgres -c "touch /var/lib/pgsql/wal_archive/test_write && rm -f /var/lib/pgsql/wal_archive/test_write"

#. Asegúrese de que el comando en ``postgresql.conf`` maneje la idempotencia (evitando sobrescritura de archivos existentes) y devuelva código de salida 0:

   .. code-block:: ini

      archive_command = 'test ! -f /var/lib/pgsql/wal_archive/%f && cp %p /var/lib/pgsql/wal_archive/%f'


Referencias
===========
* `Documentación oficial de Red Hat Enterprise Linux 10: Managing Databases <https://docs.redhat.com/>`_
* `PostgreSQL Official Documentation: High Availability, Load Balancing, and Replication <https://www.postgresql.org/docs/18/high-availability.html>`_
* `PostgreSQL Official Documentation: Continuous Archiving and Point-in-Time Recovery (PITR) <https://www.postgresql.org/docs/18/continuous-archiving.html>`_
* `Documentación del Proyecto Fedora: PostgreSQL Administration <https://docs.fedoraproject.org/>`_
* `Referencia Técnica de PostgreSQL en EVALinux <file:///home/renich/Documents/reference/postgresql.rst>`_
