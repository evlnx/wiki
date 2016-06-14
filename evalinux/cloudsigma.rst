Acceso
======
Primero entrar a https://mia.cloudsigma.com/
Hacer login con usuario y contraseña

Crear un servidor
=================
Dar click en "compute" en el menú lateral izquierdo
Dar click en "create" en el menú superior
En la cejilla "properties":
        Name: siguiendo las características de lenguaje de un dominio agregar un nombre al servidor
        CPU type: seleccionar el adecuado de acuerdo al que se está suscrito
        CPU y RAM: seleccionar tamaños de acuerdo a los necesitados
En la cejilla "drives":
        Dar click en "Attach Drive"
                Dar click en "New Drive"
                Name: éste debe ser nuestro principal disco duro, darle nombre
                Device Type: Establecer el tipo de dispositivo que éste será
                Size: Elegir el tamaño que éste tendrá
                Para finalizarlo dar click en "Create and attach drive" en el menú superior
        Crear otro dispositivo en "Attach Drive"
                Agregar el disco de instalación
                Éste deberá ser en formato "CD-ROM" en la opción "Device Type"
                En caso de ser de la librería dar click en el botón "browse" en la parte inferior, buscarlo, seleccionarlo y esperar a que se suba
                Dar click en "Create and attach drive" en el menú superior
En la cejilla "advanced":
        Processor distribution: seleccionar la opción más adecuada
        Procession units to be simulated: establecer los cores necesarios
        Enable NUMA: Depende de la necesidad activarlo o no
        Para terminar dar click en el botón "Save" ubicado en la parte inferior derecha
Una vez terminada la configuración dar click en el ícono verde de guardar en el menú superior
                
