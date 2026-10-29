********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 00 - MAESTRO
* FUNCIÓN  : Ejecuta la cadena completa en orden, de los microdatos originales
*            a las tablas y figuras del capítulo de resultados
* STATA    : 17
********************************************************************************
* ADVERTENCIA DE TIEMPO
* La cadena completa tarda entre siete y nueve horas, concentradas casi por
* entero en el script 07 (imputación múltiple, unas cuatro horas) y en el 08
* (modelos mixtos sobre veinte imputaciones, cerca de tres horas).
*
* REEJECUCIÓN PARCIAL CUANDO CAMBIA EL NIVEL 3
* Si solo cambian las variables municipales (por ejemplo, al corregir una serie
* o reconstruir el índice), basta con la secuencia 04 -> 06 -> 07c -> 08 -> 09.
* No hay que repetir el 01, el 02, el 03, el 05 ni el 07: desde la versión 3 del
* 07 los valores imputados no dependen del índice.
*
* Este archivo existe para documentar el orden y permitir la reproducción
* íntegra. Para el trabajo cotidiano conviene ejecutar los scripts por
* separado: cada uno guarda su salida en disco y el siguiente la lee.
*
* REQUISITOS DE SOFTWARE
*     ssc install estout, replace
*     ssc install factortest, replace
*     ssc install mimrgns, replace
*
* REQUISITO DE ESPACIO EN DISCO
* La base imputada ocupa alrededor de un gigabyte en formato flong, y los
* archivos intermedios suman otro tanto. Conviene tener al menos cinco
* gigabytes libres antes de ejecutar el 07: una corrida previa se interrumpió
* por falta de espacio al escribir archivos temporales.
********************************************************************************

clear all
set more off
version 17

cd "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Objetivo 2"

capture log close _all
log using "log_00_master.log", replace text name(master)

timer clear 99
timer on 99

display _newline "{hline 78}"
display "CADENA COMPLETA - INICIO: " c(current_date) " " c(current_time)
display "{hline 78}"

* ----------------------------------------------------------------------
* CONSTRUCCIÓN DE LAS BASES
* ----------------------------------------------------------------------
* 01  Microdatos ICFES               -> N1_Saber11_2018_2023.dta
* 02  Paneles DANE de sede           -> N2_Sedes_sinTIC.dta
* 03  Dotación tecnológica           -> N2_Sedes_2018_2023.dta
* 04  Panel municipal y deflactación -> N3_Municipios_2018_2023.dta
* 05  Ensamblaje de los tres niveles -> Base_Multinivel_2018_2023.dta
do "01_depuracion_N1_ICFES_v2.do"
do "02_panel_sedes_N2_v2.do"
do "03_panel_tic_N2_v2.do"
do "04_panel_municipal_N3_v4.do"
do "05_ensamblaje_v2.do"

* ----------------------------------------------------------------------
* ÍNDICE E IMPUTACIÓN
* ----------------------------------------------------------------------
* 06  Componentes principales y Mundlak -> Base_Multinivel_PCA.dta
* 07  Imputación en dos niveles          -> MI_Sedes.dta, MI_Estudiantes.dta
* 07b Unión de los conjuntos             -> Base_Multinivel_MI.dta
* 07c Incorporación del Nivel 3          -> Base_Multinivel_MI.dta actualizada
*
* El 07c es OBLIGATORIO desde la versión 3 del 07: el modelo de imputación ya
* no usa el índice de vulnerabilidad como predictor, de modo que el 07 lo retira
* de la base y es el 07c quien lo incorpora. Esa separación es lo que permite
* reconstruir el índice sin repetir las cuatro horas de imputación.
do "06_pca_vulnerabilidad.do"
do "07_imputacion_v3.do"
do "07b_reparar_y_unir_v2.do"
do "07c_actualizar_nivel3.do"

* ----------------------------------------------------------------------
* ESTIMACIÓN Y SALIDAS
* ----------------------------------------------------------------------
* 08  Modelos multinivel y robustez -> archivos .ster
* 09  Tablas en RTF y figuras en PNG
do "08_estimacion_v4.do"
do "09_tablas_graficos_v4.do"

timer off 99
display _newline "--- Tiempo total de la cadena ---"
timer list 99

display _newline "{hline 78}"
display "CADENA COMPLETA - FIN: " c(current_date) " " c(current_time)
display "{hline 78}"

log close master
