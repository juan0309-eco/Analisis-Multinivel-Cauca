********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 00 - MASTER DE LA CADENA
* ENTRADA  : los do-files de Definitivo, en el orden del inventario (sec. 6.3)
* SALIDA   : log_00_master_<hoy>.log (en la carpeta de datos del modo)
*            cada script deja ademas su propio log
* STATA    : 17
* FECHA    : 24 de octubre de 2026
* REVISION : 29 de octubre de 2026 (C11): se anade el 18 (R1b y R3b, P1) y
*            el 09 pasa a la version 6 (tablas con la estructura vigente)
********************************************************************************
* QUE ES
* Un mapa ejecutable de la cadena: un interruptor por script, en orden de
* dependencias. TODOS LOS INTERRUPTORES VIENEN EN 0: correr este archivo sin
* editarlo no ejecuta nada, no borra nada y no lanza horas de computo.
*
* COMO SE USA
*   1. Elegir el modo (normal o verif) en la seccion [0].
*   2. Poner en 1 solo los scripts que se quieren correr.
*   3. Antes de encender un script, cambiar SU local hoy: si su log ya existe,
*      el guard lo detiene con r(602) y el master se detiene con el.
*   4. En modo normal, los scripts marcados "reescribe" sobrescriben bases o
*      .ster que el informe usa. Para correrlos hay que poner ademas
*      permitir_reescribir = 1. Es un freno deliberado.
*
* LO QUE HACE EL MASTER Y LO QUE NO
*   - Fija el modo, carga 00_config.do y llama a cada script con su ruta.
*   - Cada script cierra los logs abiertos al empezar (capture log close
*     _all), asi que el master reabre el suyo con append despues de cada uno
*     y anota codigo de salida y duracion.
*   - Si un script falla, el master se detiene y dice cual y con que codigo.
*   - No cambia los interruptores internos de los scripts (hacer_*): esos se
*     editan en cada script.
*
* TIEMPOS DE REFERENCIA (de los logs de cierre o del Anexo E; ver inventario)
*   07   16.616,32 s  log_07_imputacion.log
*   08   20.774,50 s  log_08_estimacion.log
*   10   1 h 44 min   Anexo E, Tabla 37 (nota)
*   11   14.645,60 s  log_11_estructura.log
*   12    4.087,56 s  log_12_composicional.log
*   13    3.002,16 s  log_13_cohortes_20261022.log (bloques [0] y [1])
*   14   29 min + 1 h 23 min + 4 min   Anexo E
*   14c   2.793,06 s  log_14c_popayan_20261014b.log (suma de tres timers)
*   15   8 h 30 min   Anexo E
*   16    3.409,31 s  log_16_territorial_20261019d.log
*   16a     137,08 s  segun el encabezado del 16_d (no verificado en su log)
*   18    2.899,32 s  log_18_robustez_20261026.log
*   17 v2 reestima ML3b sobre la imputacion 1 (del orden de 15 min).
*   Los demas no tienen timer: tardan minutos. El 09 v6 reestima seis
*   modelos por cohorte sobre la primera imputacion (bloque [2.0]).
*
* DEPENDENCIAS QUE CONVIENE RECORDAR
*   - 07c SOBRESCRIBE Base_Multinivel_MI.dta y exige la copia
*     Base_Multinivel_MI_pre_C7.dta.
*   - Cuando cambia el Nivel 3, la cadena minima es 04 -> 06 -> 07c -> 16a,
*     sin repetir el 07 ni el 08.
*   - 11a y 15a son ensayos: no alimentan el informe.
*   - El 09 v6 lee .ster del 08, del 11, del 18 y Efectos_sede_M4r del 15.
*     Va despues de ellos aunque su numero sea menor; si le falta un .ster,
*     avisa y omite ese bloque.
*   - El 18 lee Base_Estimacion.dta y ML1b/ML2b del 11. Escribe .ster con
*     fecha y sin replace: no exige permitir_reescribir.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

* ----------------------------------------------------------------------
* [0] MODO Y PARAMETROS. Solo se editan las lineas marcadas con <<<.
* ----------------------------------------------------------------------
local modo  "normal"             // <<< "normal" o "verif"
local hoy   "20261029"           // <<< etiqueta del log del master
local permitir_reescribir = 0    // <<< 1 solo si se quiere reescribir bases
local perfil ""                  // <<< "" o "verifA" (ver mas abajo)

* PERFIL verifA (paso 7, opcion A, aprobada el 24 de octubre)
* Enciende de una vez los scripts rapidos de la prueba de la cadena. Exige
* modo verif: nunca corre sobre la carpeta real. Quedan fuera los lentos (07,
* 08, 10, 11, 12, 14, 14c, 15, 16, 18), los ensayos (11a, 15a), los que dejan
* salidas fechadas que ya estan copiadas en verificacion/ (13, 14b) y el 17,
* cuyo bloque [2] termina en r(459) (asunto pendiente de otro chat).
if "`perfil'" != "" & "`perfil'" != "verifA" {
    display as error "Perfil desconocido: `perfil'. Usar vacio o verifA."
    exit 198
}
if "`perfil'" == "verifA" & "`modo'" != "verif" {
    display as error "El perfil verifA exige local modo verif."
    exit 198
}

* El modo se fija ANTES de cargar el config, que lo respeta.
macro drop TESIS_CONFIG MODO
global MODO "`modo'"
local config "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
capture confirm file "`config'"
if _rc != 0 {
    display as error "No se encontro 00_config.do en la carpeta Definitivo."
    exit 601
}
do "`config'"

mata: st_numscalar("hay_raiz", direxists(st_global("RAIZ")))
if hay_raiz == 0 {
    display as error "No existe la carpeta de trabajo de este modo: $RAIZ"
    display as error "En modo verif hay que preparar antes verificacion/ (paso 7)."
    macro drop TESIS_CONFIG MODO
    exit 601
}
cd "$RAIZ"

capture log close _all
capture confirm file "log_00_master_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_00_master_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    macro drop TESIS_CONFIG MODO
    exit 602
}
log using "log_00_master_`hoy'.log", text name(master)
display "Master   modo: $MODO   perfil: `perfil'   datos: $RAIZ   do-files: $RAIZ_DO"
display "Inicio: " c(current_date) " " c(current_time)


* ----------------------------------------------------------------------
* [1] INTERRUPTORES (todos en 0). Una fila por script, en orden.
*     tipo: R = rapido (minutos), L = lento (horas), E = ensayo
*     reescribe: 1 = sobrescribe bases o .ster sin fecha
* ----------------------------------------------------------------------
*                                                         tipo  reescribe
local s01  = 0    // 01  depuracion del Nivel 1            R     1
local s02  = 0    // 02  panel de sedes                    R     1
local s03  = 0    // 03  TIC de sedes                      R     1
local s04  = 0    // 04  panel municipal (v5)              R     1
local s05  = 0    // 05  ensamblaje                        R     1
local s06  = 0    // 06  PCA de vulnerabilidad (v3)        R     1
local s07  = 0    // 07  imputacion multiple, M = 20       L     1
local s07b = 0    // 07b union de los niveles imputados    R     1
local s07c = 0    // 07c Nivel 3 actualizado (C7)          R     1
local s08  = 0    // 08  estimacion principal              L     1
local s10  = 0    // 10  blindaje (bloques [2] y [3] L)    L     1
local s10b = 0    // 10b planta docente con efectos fijos  R     0
local s11a = 0    // 11a ensayo de estructura aleatoria    E     1
local s11  = 0    // 11  estructura aleatoria de C1        L     1
local s11b = 0    // 11b efecto minimo detectable          R     1
local s11c = 0    // 11c pendientes anuales de ML4b        R     1
local s12  = 0    // 12  efecto composicional (C2)         L     1
local s13  = 0    // 13  cohortes y Oaxaca (C3)            L     0
local s14  = 0    // 14  sensibilidad y diagnosticos (C5)  L     0
local s14b = 0    // 14b cierre del bloque [1] del 14      R     0
local s14c = 0    // 14c Popayan                           L     0
local s15a = 0    // 15a ensayo del gradiente              E     0
local s15  = 0    // 15  gradiente y medicion (C6)         L     0
local s15b = 0    // 15b lecturas del 15                   R     0
local s15c = 0    // 15c Figuras 6 y 7                     R     0
local s16a = 0    // 16a rehace Base_Estimacion (C7)       R     1
local s16  = 0    // 16  canales territoriales (C7)        L     0
local s17  = 0    // 17  diagnosticos de C7 (v2, Fig 8-10)  L     0
local s18  = 0    // 18  R1b y R3b con cuatro componentes  L     0
local s09  = 0    // 09  tablas y graficos (v6, C11)       R     0

* Archivo y marca de reescritura de cada clave. El 09 va al final porque
* lee los .ster del 11, del 15 y del 18.
local orden "01 02 03 04 05 06 07 07b 07c 08 10 10b 11a 11 11b 11c 12 13 14 14b 14c 15a 15 15b 15c 16a 16 17 18 09"

local a01  "01_depuracion_N1_ICFES_v2.do"
local a02  "02_panel_sedes_N2_v2.do"
local a03  "03_panel_tic_N2_v2.do"
local a04  "04_panel_municipal_N3_v5.do"
local a05  "05_ensamblaje_v2.do"
local a06  "06_pca_vulnerabilidad_v3.do"
local a07  "07_imputacion_v3.do"
local a07b "07b_reparar_y_unir_v2.do"
local a07c "07c_actualizar_nivel3.do"
local a08  "08_estimacion_v5.do"
local a09  "09_tablas_graficos_v6.do"
local a10  "10_blindaje.do"
local a10b "10b_planta_fe_v2.do"
local a11a "11a_ensayo_estructura.do"
local a11  "11_estructura_aleatoria.do"
local a11b "11b_emd.do"
local a11c "11c_tabla14.do"
local a12  "12_composicional.do"
local a13  "13_cohortes_oaxaca.do"
local a14  "14_sensibilidad_diagnosticos.do"
local a14b "14b_cierre_bloque1.do"
local a14c "14c_popayan.do"
local a15a "15a_ensayo_gradiente.do"
local a15  "15_gradiente_medicion.do"
local a15b "15b_lecturas.do"
local a15c "15c_figuras.do"
local a16a "16a_rehacer_base.do"
local a16  "16_territorial.do"
local a17  "17_diagnosticos_C7_v2.do"
local a18  "18_robustez_R1R3.do"

* El 09 v6 ya no reescribe nada: todas sus salidas llevan fecha.
local reescriben "01 02 03 04 05 06 07 07b 07c 08 10 11a 11 11b 11c 12 16a"

if "`perfil'" == "verifA" {
    foreach k in 01 02 03 04 05 06 07b 07c 09 10b 11b 11c 15b 15c 16a {
        local s`k' = 1
    }
    display _newline "Perfil verifA: 15 scripts encendidos."
    display "El 09 v6 omite los bloques cuyos .ster no esten en verificacion/."
}


* ----------------------------------------------------------------------
* [2] COMPROBACIONES ANTES DE CORRER NADA
* ----------------------------------------------------------------------
local encendidos ""
local ncad : word count `orden'
foreach k of local orden {
    if `s`k'' == 1 local encendidos "`encendidos' `k'"
    capture confirm file "$RAIZ_DO/`a`k''"
    if _rc != 0 {
        display as error "No existe `a`k'' en la carpeta Definitivo."
        log close master
        macro drop TESIS_CONFIG MODO
        exit 601
    }
}
local nenc : word count `encendidos'
display _newline "Scripts encendidos: `nenc'  (`encendidos' )"

if `nenc' == 0 {
    display _newline "Ningun interruptor esta en 1: no se corre nada."
    display "Los `ncad' do-files de la cadena existen en Definitivo."
}

local peligro : list encendidos & reescriben
if "$MODO" == "normal" & "`peligro'" != "" & `permitir_reescribir' != 1 {
    display as error _newline "En modo normal, estos scripts sobrescriben bases o"
    display as error ".ster que usa el informe: `peligro'"
    display as error "Para correrlos, poner permitir_reescribir = 1. Antes,"
    display as error "considerar el modo verif."
    log close master
    macro drop TESIS_CONFIG MODO
    exit 9
}


* ----------------------------------------------------------------------
* [3] CORRIDA
* ----------------------------------------------------------------------
local resumen ""
foreach k of local encendidos {
    display _newline "{hline 78}"
    display "MASTER: inicia `a`k''   " c(current_date) " " c(current_time)
    display "{hline 78}"
    local t0 = clock(c(current_date) + " " + c(current_time), "DMYhms")

    capture noisily do "$RAIZ_DO/`a`k''"
    local rc = _rc

    * El script cerro el log del master al empezar: se reabre
    capture log close _all
    cd "$RAIZ"
    log using "log_00_master_`hoy'.log", append text name(master)   // VALIDADOR: intencional V2b
    local seg = round((clock(c(current_date) + " " + c(current_time), "DMYhms") - `t0') / 1000)
    display "MASTER: termina `a`k''   codigo `rc'   `seg' s"
    local resumen "`resumen' `k':`rc':`seg'"

    if `rc' != 0 {
        display as error _newline "El master se detiene: `a`k'' termino con r(`rc')."
        if `rc' == 602 {
            display as error "r(602): su log ya existe. Cambiar el local hoy de ese script."
        }
        display as error "Su propio log dice en que linea fallo."
        log close master
        macro drop TESIS_CONFIG MODO
        exit `rc'
    }
}


* ----------------------------------------------------------------------
* [4] RESUMEN Y CIERRE
* ----------------------------------------------------------------------
if `nenc' > 0 {
    display _newline "{hline 78}"
    display "RESUMEN (clave : codigo : segundos)"
    display "{hline 78}"
    foreach r of local resumen {
        display "  `r'"
    }
}
display _newline "Fin: " c(current_date) " " c(current_time)

* Se borran MODO y TESIS_CONFIG para que un script corrido suelto despues
* vuelva a cargar el config en modo normal.
log close master
macro drop TESIS_CONFIG MODO
