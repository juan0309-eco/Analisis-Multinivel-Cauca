*==============================================================================
* 15a_ensayo_gradiente.do
* C6: ensayo de viabilidad de M4 y M5 con la estructura aleatoria de C1
* Muestra: 2018-2019, UNA imputación (mi extract 1), sin mi estimate.
* Objetivo: medir tiempos y convergencia ANTES de escribir 15_gradiente_medicion.do
*
* Estructura C1: || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio: , reml
* M4 añade la pendiente aleatoria de cwc_inse en sede_id (covarianza no restringida).
* El log lleva fecha y hora en el nombre; no usa replace, así que Stata aborta
* si el archivo ya existe y ningún log anterior se sobrescribe.
*==============================================================================
version 17
clear all
set more off
if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* [0] LOG FECHADO (sin replace) -----------------------------------------------
local f  = string(date(c(current_date),"DMY"),"%tdCCYYNNDD")
local h  = subinstr(substr(c(current_time),1,5),":","",.)
log using "log_15a_ensayo_`f'_`h'.log", text
display "Inicio: " c(current_date) " " c(current_time)

* [1] GLOBALES (idénticos a 08_estimacion_v5.do) ------------------------------
global v_n1 mujer edad repitente lectura_30min libros_26omas trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado dotacion_tic rural ju_unica tecnico tecnico_academico cole_femenino

* [2] DATOS: una imputación, ids, submuestra ----------------------------------
use "Base_Estimacion.dta", clear
mi extract 1, clear

* mcpio_id y sede_id ya existen en Base_Estimacion (los usa 08). Si falta
* alguno, el do-file se detiene: copiar entonces desde 11_estructura_aleatoria.do
* las líneas que los crean.
capture confirm variable mcpio_id sede_id year punt_global cwc_inse c_inse_prom_sede pct_planta indice_vuln
if _rc != 0 {
    display as error "Falta alguna variable base. Revisar 11_estructura_aleatoria.do, bloque de ids."
    log close
    exit 111
}

* sede_anio se crea ANTES del keep para que coincida con la corrida completa.
* Si 11_estructura_aleatoria.do ya la construye con otra regla, usar esa.
capture confirm variable sede_anio
if _rc != 0 {
    egen long sede_anio = group(sede_id year)
}

keep if inlist(year, 2018, 2019)
display "Observaciones del ensayo: " _N

* [3] REFERENCIA DE TIEMPO: estructura C1 sin pendiente ------------------------
timer clear
display _newline "--- [3] Referencia: estructura C1, sin pendiente aleatoria ---"
timer on 1
mixed punt_global cwc_inse c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year ///
    || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio: , reml
timer off 1
display "converged (referencia) = " e(converged)
matrix list e(b)

* [4] M4: pendiente aleatoria de cwc_inse en sede -------------------------------
display _newline "--- [4] M4 con estructura C1 ---"
timer on 2
mixed punt_global cwc_inse c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year ///
    || mcpio_id: || mcpio_id: R.year                                           ///
    || sede_id: cwc_inse, covariance(unstructured)                             ///
    || sede_anio: , reml
timer off 2
display "converged (M4) = " e(converged)
display "log-verosimilitud (M4) = " e(ll)
* Confirmar los nombres lns / atr antes de usarlos en el do-file final:
matrix list e(b)

* [5] M5: interacciones entre niveles ------------------------------------------
display _newline "--- [5] M5 con estructura C1 ---"
timer on 3
mixed punt_global cwc_inse c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln     ///
    c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year                        ///
    || mcpio_id: || mcpio_id: R.year                                           ///
    || sede_id: cwc_inse, covariance(unstructured)                             ///
    || sede_anio: , reml
timer off 3
display "converged (M5) = " e(converged)
display "log-verosimilitud (M5) = " e(ll)
matrix list e(b)

* Contraste conjunto de las dos interacciones (familia declarada de M5)
test c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln

* [6] RESUMEN DE TIEMPOS --------------------------------------------------------
display _newline "--- Tiempos (segundos): 1 = referencia, 2 = M4, 3 = M5 ---"
timer list
display "Fin: " c(current_date) " " c(current_time)
log close
