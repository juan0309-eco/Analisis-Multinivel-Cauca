********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 17 - DIAGNOSTICOS DE CIERRE DE C7 (VERSION 3)
* ENTRADA  : Base_Estimacion.dta
* SALIDA   : log_17_diagnosticos_C7_<hoy>.log
*            ML3b_m1_diag_<hoy>.ster
*            Cola_inferior_ML3b_<hoy>.dta
* STATA    : 17
* FECHA    : 19 de noviembre de 2026 (R4, auditoria de referencias)
********************************************************************************
* POR QUE EXISTE ESTA VERSION
*
* El Anexo H, parrafo 11, cita ocho municipios de la cola inferior de la
* Figura 8 y una correlacion de -0,10 con el indice de vulnerabilidad. Ninguna
* de las dos cosas tiene salida en un log:
*   - v1 (log_17_diagnosticos_C7_20261022.log, bloque [2]) murio con r(459):
*     "estimates use" + "estimates esample" no reconstruye la muestra.
*   - v2 (claude/17_diagnosticos_C7_v2.do) corrige eso reestimando ML3b, pero
*     no hay log de su corrida en el Project y tiene dos fallos que la harian
*     morir o dar una cifra distinta:
*       (a) "predict double re_mcpio re_mcpio_anio re_sede re_sede_anio,
*           reffects" pide CUATRO variables, pero "|| mcpio_id: R.year" genera
*           un efecto por cada nivel de year (seis). predict devuelve
*           1 + 6 + 1 + 1 = 9 efectos y falla por numero de variables.
*       (b) La correlacion se calcula con indice_vuln en la primera fila de
*           cada municipio, es decir, el indice de un ano arbitrario. Para un
*           efecto PERMANENTE del municipio la comparacion coherente es con el
*           promedio del periodo, vuln_bar.
*
* Esta version: predice con re_*, identifica cada efecto por su constancia en
* su nivel (no por su posicion), reporta la correlacion con vuln_bar y, como
* referencia, con indice_vuln de 2018, y guarda la lista en un .dta.
*
* CONTROL. Varianzas de ML3b sobre la primera imputacion (Anexo H, parr. 5):
* municipio 188,390; municipio-ano 3,139; sede 127,378; sede-ano 21,599;
* residual 1.180,667. Si no coinciden, NO usar la lista.
*
* DESCRIPTIVO. No estima nada que vaya al informe como resultado.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

local tarea "17_diagnosticos_C7"
local hoy   "20261119"          // <<< etiqueta de ESTA corrida

capture log close _all
capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log. Cambiar el local hoy."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase17)
display "Tarea: `tarea'   salida: `hoy'   " c(current_date) " " c(current_time)

timer clear
timer on 1

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino
global v_mun tasa_homicidios_bar tasa_homicidios_dev ln_coca_bar ///
             ln_coca_dev ln_inversion_pc_bar ln_inversion_pc_dev


********************************************************************************
* [2] ML3b SOBRE LA PRIMERA IMPUTACION
********************************************************************************
use "Base_Estimacion.dta", clear
mi extract 1, clear

capture drop mcpio_anio sede_anio
egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
egen long sede_anio  = group(cole_cod_dane_sede year)

confirm variable vuln_bar indice_vuln mcpio_id sede_id

timer on 2
mixed punt_global c_inse $v_n1 $v_n2 $v_mun ib2018.year              ///
    || mcpio_id: || mcpio_id: R.year                                 ///
    || sede_id: || sede_anio: , reml
timer off 2
estimates save "ML3b_m1_diag_`hoy'.ster"

display _newline "--- CONTROL: varianzas (Anexo H: 188,390 / 3,139 / 127,378 / 21,599 / 1.180,667) ---"
estat sd, variance


********************************************************************************
* [2.1] EFECTOS PREDICHOS, IDENTIFICADOS POR SU NIVEL
********************************************************************************
predict double re_*, reffects
describe re_*

* El efecto permanente del municipio es la unica variable re_* constante
* dentro de mcpio_id. Se busca, no se supone su posicion.
local re_m ""
foreach v of varlist re_* {
    tempvar s
    quietly bysort mcpio_id: egen double `s' = sd(`v')
    quietly count if `s' > 1e-8 & !missing(`s')
    if r(N) == 0 & "`re_m'" == "" local re_m `v'
    drop `s'
}
display _newline "Efecto permanente del municipio: `re_m'"
assert "`re_m'" != ""
rename `re_m' re_mcpio


********************************************************************************
* [2.2] COLA INFERIOR DE LA FIGURA 8
********************************************************************************
egen byte _tm = tag(mcpio_id)

* Indice del primer ano, solo como referencia de la version 2
bysort mcpio_id (year): generate double _iv2018 = indice_vuln[1]

capture confirm variable cole_mcpio_ubicacion
local nom = cond(_rc == 0, "cole_mcpio_ubicacion", "")

preserve
    keep if _tm == 1
    keep mcpio_id cole_cod_mcpio_ubicacion `nom' re_mcpio vuln_bar _iv2018

    quietly count
    display _newline "Municipios: " r(N) " (esperados: 42)"
    assert r(N) == 42

    gsort re_mcpio
    generate int orden = _n

    display _newline "--- Los ocho efectos mas bajos ---"
    list orden cole_cod_mcpio_ubicacion `nom' re_mcpio vuln_bar in 1/8, ///
        clean noobs abbreviate(24)

    display _newline "--- Salto entre el octavo y el noveno ---"
    display "  re_mcpio[8] = " %8.3f re_mcpio[8] "   re_mcpio[9] = " %8.3f re_mcpio[9]

    display _newline "--- Signo del indice (promedio del periodo) entre los ocho ---"
    quietly count if orden <= 8 & vuln_bar > 0
    display "  Con vuln_bar > 0: " r(N) " de 8"

    display _newline "--- Correlacion del efecto del municipio con el indice ---"
    correlate re_mcpio vuln_bar
    display "  Con el promedio del periodo (vuln_bar): " %7.4f r(rho)
    quietly correlate re_mcpio _iv2018
    display "  Con indice_vuln de 2018 (como en v2):   " %7.4f r(rho)

    save "Cola_inferior_ML3b_`hoy'.dta", replace
restore

display _newline "LECTURA: descriptiva. Los efectos predichos estan encogidos hacia"
display "la media. Pasar los codigos DANE a nombres con DIVIPOLA y comparar con"
display "la lista del Anexo H, parrafo 11, antes de conservarla."

timer off 1
timer list
log close fase17
