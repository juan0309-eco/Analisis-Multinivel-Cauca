********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 07C - ACTUALIZACIÓN DE LAS VARIABLES DE NIVEL 3 EN LA BASE IMPUTADA
* ENTRADA  : Base_Multinivel_MI.dta, N3_Municipios_PCA.dta
* SALIDA   : Base_Multinivel_MI.dta (reemplazada)
* STATA    : 17
********************************************************************************
* PARA QUÉ SIRVE
* Incorpora las variables municipales (índice de vulnerabilidad, su
* descomposición de Mundlak y las medidas fiscales) a la base imputada.
*
* Desde la versión 3 del script 07 este paso es OBLIGATORIO, no opcional: el
* modelo de imputación ya no usa el índice como predictor auxiliar, de modo que
* el 07 lo retira de la base antes de imputar y es aquí donde entra.
*
* NO hace falta volver a imputar cuando el índice cambia. Las variables
* municipales son completas y entran al conjunto como REGULARES, no como
* imputadas: son idénticas en las veinte imputaciones y basta con sustituirlas.
* Las cuatro horas del script 07 no se repiten.
*
* LA SALVEDAD DE LA VERSIÓN ANTERIOR YA NO APLICA
* Hasta la versión 2 del script 07, el modelo de imputación usaba el índice
* antiguo entre sus predictores, lo que obligaba a declarar en la metodología
* que los valores imputados correspondían a una versión previa del índice. La
* versión 3 sustituyó el índice por sus tres dimensiones crudas, de modo que
* los valores imputados ya no dependen de cómo se construya el índice y esa
* limitación desaparece.
*
* IMPORTANTE: esto solo es cierto si la base imputada se generó con el 07 v3.
* Si se está trabajando sobre una base imputada producida por el 07 v2, la
* limitación sigue vigente y hay que declararla.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

cd "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Objetivo 2"

capture log close _all
log using "log_07c_actualizar_n3.log", replace text name(fase7c)


********************************************************************************
* [1] PREPARACIÓN DE LAS VARIABLES NUEVAS
********************************************************************************

display _newline "{hline 78}"
display "[1] VARIABLES MUNICIPALES ACTUALIZADAS"
display "{hline 78}"

use "N3_Municipios_PCA.dta", clear
capture xtset, clear

keep cole_cod_mcpio_ubicacion year ///
     indice_vuln indice_vuln_anual vuln_bar vuln_dev ///
     tasa_homicidios tasa_homicidios_bar tasa_homicidios_dev ///
     coca ln_coca ln_coca_bar ln_coca_dev ///
     ln_inversion_pc ln_inversion_pc_bar ln_inversion_pc_dev ///
     ln_inv_fut_pc ln_inv_fut_pc_bar ln_inv_fut_pc_dev ///
     ln_inv_fut_pc_x ln_inv_fut_pc_x_bar ln_inv_fut_pc_x_dev ///
     ln_ing_trib_pc ln_ing_trib_pc_bar ln_ing_trib_pc_dev ///
     ln_sgp_pae_pc ln_sgp_total_pc

quietly count
display "Municipio-año: " r(N) " (esperados: 252)"
assert _N == 252
isid cole_cod_mcpio_ubicacion year

display _newline "--- Índice corregido por año ---"
tabstat indice_vuln, by(year) stat(n mean sd min max) format(%9.4f)

tempfile n3nuevo
save `n3nuevo', replace


********************************************************************************
* [2] SUSTITUCIÓN DENTRO DE LA BASE IMPUTADA
********************************************************************************

display _newline "{hline 78}"
display "[2] SUSTITUCIÓN EN LA BASE IMPUTADA"
display "{hline 78}"

use "Base_Multinivel_MI.dta", clear

quietly count
display "Filas del conjunto imputado: " r(N)

* Las variables municipales viejas se retiran del registro antes de borrarlas,
* porque `mi` no permite eliminar una variable registrada sin desregistrarla.
local n3viejas indice_vuln indice_vuln_anual vuln_bar vuln_dev ///
               tasa_homicidios tasa_homicidios_bar tasa_homicidios_dev ///
               coca ln_coca ln_coca_bar ln_coca_dev ///
               ln_inversion_pc ln_inversion_pc_bar ln_inversion_pc_dev ///
               ln_inv_fut_pc ln_inv_fut_pc_bar ln_inv_fut_pc_dev ///
               ln_inv_fut_pc_x ln_inv_fut_pc_x_bar ln_inv_fut_pc_x_dev ///
               ln_ing_trib_pc ln_ing_trib_pc_bar ln_ing_trib_pc_dev ///
               ln_sgp_pae_pc ln_sgp_total_pc inversion_pc

foreach v of local n3viejas {
    capture mi unregister `v'
    capture drop `v'
}

display _newline "Variables municipales antiguas eliminadas."

* El merge es m:1 sobre municipio y año. Como las variables son idénticas en
* todas las imputaciones, se replican correctamente en las 21 copias de cada
* estudiante.
mi merge m:1 cole_cod_mcpio_ubicacion year using `n3nuevo', generate(_m_n3)

display _newline "--- Resultado de la unión ---"
tabulate _m_n3
assert _m_n3 == 3
drop _m_n3

* Se registran como regulares: son completas y no varían entre imputaciones.
mi register regular indice_vuln indice_vuln_anual vuln_bar vuln_dev ///
    tasa_homicidios tasa_homicidios_bar tasa_homicidios_dev ///
    coca ln_coca ln_coca_bar ln_coca_dev ///
    ln_inversion_pc ln_inversion_pc_bar ln_inversion_pc_dev ///
    ln_inv_fut_pc ln_inv_fut_pc_bar ln_inv_fut_pc_dev ///
    ln_ing_trib_pc ln_ing_trib_pc_bar ln_ing_trib_pc_dev ///
    ln_sgp_pae_pc ln_sgp_total_pc

* La serie depurada del FUT también se registra como regular, aunque tiene
* faltantes en el municipio-año excluido. `mi update` emitirá una nota
* advirtiendo que una variable regular tiene valores perdidos: es esperado y no
* es un error. Lo que NO debe hacerse es registrarla como imputada, porque el
* dato no falta, sino que se descartó a propósito por ser un error de reporte.
* La consecuencia práctica es que la prueba R5b estimará sobre un número de
* observaciones menor que R5, diferencia que hay que declarar en los resultados.
mi register regular ln_inv_fut_pc_x ln_inv_fut_pc_x_bar ln_inv_fut_pc_x_dev

quietly count if missing(ln_inv_fut_pc_x)
display _newline "Filas sin valor en la serie depurada del FUT: " r(N)

mi update


********************************************************************************
* [3] VERIFICACIÓN
********************************************************************************

display _newline "{hline 78}"
display "[3] VERIFICACIÓN"
display "{hline 78}"

mi describe

display _newline "--- El índice debe ser idéntico en todas las imputaciones ---"
bysort _mi_id: egen double _sd_idx = sd(indice_vuln)
quietly count if _sd_idx > 1e-10 & !missing(_sd_idx)
display "Estudiantes con índice distinto entre imputaciones: " r(N) " (debe ser 0)"
assert r(N) == 0
drop _sd_idx

display _newline "--- El índice debe ser constante dentro de cada municipio-año ---"
bysort _mi_m cole_cod_mcpio_ubicacion year: egen double _sd_mcp = sd(indice_vuln)
quietly count if _sd_mcp > 1e-10 & !missing(_sd_mcp)
display "Municipio-año con índice no constante: " r(N) " (debe ser 0)"
assert r(N) == 0
drop _sd_mcp

quietly count if missing(indice_vuln)
display _newline "Estudiantes sin valor del índice: " r(N) " (debe ser 0)"
assert r(N) == 0

display _newline "--- Índice y componentes en la base de estudiantes ---"
tabstat indice_vuln vuln_bar vuln_dev ln_coca if _mi_m == 1, ///
    by(year) stat(n mean sd) format(%9.4f)

display _newline "--- Medidas fiscales alternativas ---"
tabstat ln_inversion_pc ln_inv_fut_pc ln_ing_trib_pc if _mi_m == 1, ///
    by(year) stat(n mean sd) format(%9.4f)


********************************************************************************
* [4] GUARDADO
********************************************************************************

compress
save "Base_Multinivel_MI.dta", replace

display _newline "{hline 78}"
display "BASE IMPUTADA ACTUALIZADA con el Nivel 3 corregido."
display "Siguiente: 08_estimacion_v4.do"
display "{hline 78}"

log close fase7c
