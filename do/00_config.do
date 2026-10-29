********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 00 - CONFIGURACION COMUN
* STATA    : 17
* FECHA    : 23 de octubre de 2026
********************************************************************************
* QUE ES
* Un solo lugar para la ruta de trabajo, las semillas, el numero de
* imputaciones, los paquetes requeridos y los bloques de variables. Lo llama
* el 00_master.do y, cuando un script se corre suelto, el propio script:
*
*     if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
*     cd "$RAIZ"
*
* QUE NO HACE
* No borra datos de la memoria, no abre logs, no estima nada y no cambia el
* directorio de trabajo. Solo define globales y avisa si falta un paquete.
*
* LAS GLOBALES DE VARIABLES estan copiadas literalmente de
* 08_estimacion_v5.do, bloque [2.4], y de 13_cohortes_oaxaca.do. Los scripts
* siguen definiendolas tambien, para poder correrse sin este archivo. Si alguna
* vez se cambian aqui, hay que cambiarlas alla.
********************************************************************************

global TESIS_CONFIG "ok"

* ----------------------------------------------------------------------
* MODO DE TRABAJO
*   "normal" : la carpeta de trabajo real
*   "verif"  : la carpeta verificacion/, para la corrida con pocas
*              imputaciones (inventario, seccion 5.2). Nunca toca la real.
* ----------------------------------------------------------------------
* El master fija el modo ANTES de llamar a este archivo; corrido suelto, el
* modo es siempre "normal". El master borra MODO al terminar.
if "$MODO" == "" global MODO "normal"

* DOS CARPETAS
*   RAIZ_DO   : donde viven los do-files (este archivo incluido). No cambia
*               con el modo: la verificacion corre los mismos scripts.
*   RAIZ_REAL : donde viven los datos, los .ster, las tablas y los logs.
*               Los scripts hacen cd aqui (o a verificacion/).
global RAIZ_DO   "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo"
global RAIZ_REAL "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Objetivo 2"

if "$MODO" == "verif" {
    global RAIZ "$RAIZ_REAL\verificacion"
}
else {
    global RAIZ "$RAIZ_REAL"
}

* ----------------------------------------------------------------------
* SEMILLAS E IMPUTACIONES
* ----------------------------------------------------------------------
* 2026 es la que usan 07 (set seed y rseed), 13, 14, 14b, 14c y boottest.
global SEMILLA 2026
global M_TOTAL 20
global M_VERIF 2

* ----------------------------------------------------------------------
* VERSION Y PAQUETES
* ----------------------------------------------------------------------
* Stata 17. Paquetes de SSC que usa la cadena:
*   estout   (09)      mimrgns   (citado en el Anexo E)
*   boottest (11, 16)  oaxaca    (13)
* Solo se avisa: instalar es decision del usuario, no de este archivo.
foreach p in estout mimrgns boottest oaxaca {
    capture which `p'
    if _rc != 0 {
        display as error "Falta el paquete `p'. Instalar con: ssc install `p'"
    }
}

* ----------------------------------------------------------------------
* BLOQUES DE VARIABLES Y ESTRUCTURA ALEATORIA VIGENTE (C1)
* ----------------------------------------------------------------------
global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

global RE "|| mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:"

display "Configuracion cargada. Modo: $MODO"
display "  Datos y logs : $RAIZ"
display "  Do-files     : $RAIZ_DO"
