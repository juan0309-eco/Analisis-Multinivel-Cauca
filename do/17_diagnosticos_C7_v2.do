********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 17 - DIAGNOSTICOS DE CIERRE DE C7 (VERSION 2)
* ENTRADA  : N3_Municipios_PCA.dta, Base_Estimacion.dta
* SALIDA   : log_17_diagnosticos_C7_<hoy>.log
*            ML3b_m1_diag_<hoy>.ster
*            Fig8_qq_municipio_<hoy>.png, Fig9_qq_sede_anio_<hoy>.png,
*            Fig10_qq_residuos_<hoy>.png
* STATA    : 17
* FECHA    : 29 de octubre de 2026 (C11, pendiente 3 del README)
********************************************************************************
* QUE CAMBIA RESPECTO DE LA VERSION 1
*
* [2] La version 1 hacia "estimates use C5_diag_ML3b_20261014.ster" y
*     "estimates esample", que no reconstruye la muestra (log_17_..._20261022:
*     "e(sample) not set (0 assumed)") y predict moria con r(459). Aqui ML3b se
*     reestima sobre la primera imputacion con la misma especificacion del
*     bloque [3.2] del 14, y los efectos se predicen en la misma corrida. Asi
*     se identifica la cola inferior de la Figura 8 (C5 la dejo a C7).
*
* [3] NUEVO. Las Figuras 8 a 10 del informe salieron del 14 con rotulos de
*     Stata en ingles ("BLUP r.e. for mcpio_id: _cons", "Inverse Normal",
*     "Residuals") y con el titulo dentro de la imagen. Aqui se rehacen con los
*     mismos datos, rotulos en espanol, coma decimal y sin titulo (el titulo va
*     en el rotulo del informe, APA 7). Mismo esquema s1mono que las Figuras 3
*     a 7.
*
* El bloque [1] (los 29 municipio-ano sin homicidios) ya quedo en
* log_17_diagnosticos_C7_20261022.log y no cambia: viene apagado.
*
* CONTROL. Las varianzas de ML3b sobre la primera imputacion deben reproducir
* las del Anexo H, parrafo tras la Tabla 45: municipio 188,390; municipio-ano
* 3,139; sede 127,378; sede-ano 21,599; residual 1.180,667.
*
* TIEMPO. ML3b sobre una imputacion con REML: el bloque [3] del 14 tardo
* 942,82 s con todo el bloque (log_14_sensibilidad_20261014.log). Si predict
* falla por memoria, correr solo este script, sin nada mas abierto.
*
* NO ESTIMA NADA QUE VAYA AL INFORME COMO RESULTADO: es diagnostico.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ---------------------------------------------------------------------------
* CABECERA ESTANDAR. Solo se editan las lineas marcadas con <<<.
* ---------------------------------------------------------------------------
local tarea "17_diagnosticos_C7"
local hoy   "20261029b"          // <<< etiqueta de ESTA corrida (salidas)

local hacer_ceros   = 0         // <<< ya corrido el 22-10 (bloque [1])
local hacer_cola    = 1         // <<< bloque [2]
local hacer_figuras = 1         // <<< bloque [3]

capture log close _all
capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
foreach f in ML3b_m1_diag_`hoy'.ster Fig8_qq_municipio_`hoy'.png ///
             Fig9_qq_sede_anio_`hoy'.png Fig10_qq_residuos_`hoy'.png {
    capture confirm file "`f'"
    if _rc == 0 {
        display as error "Ya existe `f'. Cambiar el local hoy."
        exit 602
    }
}
log using "log_`tarea'_`hoy'.log", text name(fase17)
display "Tarea: `tarea'   salida: `hoy'   " c(current_date) " " c(current_time)

timer clear
timer on 1

set scheme s1mono

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino
global v_mun tasa_homicidios_bar tasa_homicidios_dev ln_coca_bar ///
             ln_coca_dev ln_inversion_pc_bar ln_inversion_pc_dev


********************************************************************************
* [1] LOS 29 MUNICIPIO-ANO SIN REGISTRO DE HOMICIDIOS (sin cambios; apagado)
********************************************************************************
if `hacer_ceros' == 1 {
    display _newline(2) "{hline 78}"
    display "[1] MUNICIPIO-ANO SIN REGISTRO DE HOMICIDIOS"
    display "{hline 78}"

    use "N3_Municipios_PCA.dta", clear
    xtset cole_cod_mcpio_ubicacion year
    quietly count if homicidios == 0
    display "  Municipio-ano con homicidios == 0: " r(N) " (esperados: 29)"
    quietly xtsum tasa_homicidios
    scalar sdw_con = r(sd_w)
    quietly xtsum tasa_homicidios if homicidios > 0
    scalar sdw_sin = r(sd_w)
    display "  DE dentro con ceros " %9.4f sdw_con "  sin ceros " %9.4f sdw_sin ///
            "  cambio " %6.2f 100*(sdw_sin - sdw_con)/sdw_con " %"
    display "  Detalle completo: log_17_diagnosticos_C7_20261022.log, bloque [1]."
}


********************************************************************************
* [2] ML3b SOBRE LA PRIMERA IMPUTACION Y COLA INFERIOR DE LA FIGURA 8
********************************************************************************
if `hacer_cola' == 1 | `hacer_figuras' == 1 {

    display _newline(2) "{hline 78}"
    display "[2] ML3b SOBRE LA IMPUTACION 1 Y EFECTOS PREDICHOS"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear
    mi extract 1, clear

    capture drop mcpio_anio sede_anio
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)

    * Misma especificacion que el bloque [3.2] del 14 (ML3b, cuatro
    * componentes, REML)
    timer on 2
    mixed punt_global c_inse $v_n1 $v_n2 $v_mun ib2018.year              ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: || sede_anio: , reml
    timer off 2
    estimates save "ML3b_m1_diag_`hoy'.ster"

    display _newline "--- Control: varianzas (Anexo H: 188,390 / 3,139 / 127,378 / 21,599 / 1.180,667) ---"
    display "  municipio     " %10.3f exp(2*_b[lns1_1_1:_cons])
    display "  municipio-ano " %10.3f exp(2*_b[lns1_2_1:_cons])
    display "  sede          " %10.3f exp(2*_b[lns2_1_1:_cons])
    display "  sede-ano      " %10.3f exp(2*_b[lns3_1_1:_cons])
    display "  residual      " %10.3f exp(2*_b[lnsig_e:_cons])

    * Cuatro ecuaciones aleatorias: municipio, municipio-ano, sede y sede-ano
    timer on 3
    predict double re_mcpio re_mcpio_anio re_sede re_sede_anio, reffects
    predict double res, residuals
    timer off 3

    * VERIFICACION DEL ORDEN: cada efecto debe ser constante en su nivel
    display _newline "--- Orden de los efectos predichos ---"
    bysort mcpio_id: egen double _sd1 = sd(re_mcpio)
    quietly count if _sd1 > 1e-8 & !missing(_sd1)
    display "  Municipios con re_mcpio no constante: " r(N) " (debe ser 0)"
    assert r(N) == 0
    bysort sede_anio: egen double _sd4 = sd(re_sede_anio)
    quietly count if _sd4 > 1e-8 & !missing(_sd4)
    display "  Sede-ano con re_sede_anio no constante: " r(N) " (debe ser 0)"
    assert r(N) == 0
    drop _sd1 _sd4

    capture drop _tm _tsa
    egen byte _tm  = tag(mcpio_id)
    egen byte _tsa = tag(sede_anio)

    display _newline "--- Desviacion estandar residual por ano (control: Tabla 45) ---"
    tabstat res, by(year) stat(n mean sd) format(%9.3f)
}

if `hacer_cola' == 1 {
    display _newline "{hline 78}"
    display "COLA INFERIOR DE LA FIGURA 8"
    display "{hline 78}"
    preserve
        keep if _tm == 1
        gsort re_mcpio
        display _newline "--- Municipios por debajo de -13 ---"
        list cole_cod_mcpio_ubicacion re_mcpio indice_vuln if re_mcpio < -13, ///
            clean noobs abbreviate(24)
        quietly count if re_mcpio < -13
        display "  Son " r(N) " (C5 leyo ocho sobre el grafico)"

        display _newline "--- Los ocho mas bajos ---"
        list cole_cod_mcpio_ubicacion re_mcpio indice_vuln in 1/8, ///
            clean noobs abbreviate(24)

        display _newline "--- Los seis mas altos, para contraste ---"
        gsort -re_mcpio
        list cole_cod_mcpio_ubicacion re_mcpio indice_vuln in 1/6, ///
            clean noobs abbreviate(24)

        display _newline "--- Relacion con el indice de vulnerabilidad ---"
        quietly correlate re_mcpio indice_vuln
        display "  Correlacion efecto del municipio e indice: " %7.4f r(rho)
        quietly count
        display "  Municipios: " r(N) " (esperados: 42)"
        summarize re_mcpio, detail
    restore
    display _newline "LECTURA: descriptiva. Los efectos predichos estan encogidos hacia"
    display "la media; el grafico es indicativo, no un contraste."
}


********************************************************************************
* [3] FIGURAS 8 A 10 CON ROTULOS EN ESPANOL
********************************************************************************
if `hacer_figuras' == 1 {
    display _newline(2) "{hline 78}"
    display "[3] FIGURAS 8 A 10"
    display "{hline 78}"

    set dp comma

    * Figura 8: efectos predichos del municipio (42 puntos)
    qnorm re_mcpio if _tm == 1,                                           ///
        msymbol(O) mcolor(gs6) rlopts(lcolor(black))                       ///
        ytitle("Efecto predicho del municipio (puntos)")                   ///
        xtitle("Cuantiles de la distribución normal")                      ///
        ylabel(, angle(horizontal) format(%9.0f)) xlabel(, format(%9.0f))  ///
        title("") xsize(5.9) ysize(4.1) name(g_qq_m, replace)
    graph export "Fig8_qq_municipio_`hoy'.png", width(2000)

    * Figura 9: efectos predichos de la cohorte de sede (2.447 puntos)
    qnorm re_sede_anio if _tsa == 1,                                      ///
        msymbol(o) mcolor(gs6) rlopts(lcolor(black))                       ///
        ytitle("Efecto predicho de la cohorte de sede (puntos)")           ///
        xtitle("Cuantiles de la distribución normal")                      ///
        ylabel(, angle(horizontal) format(%9.0f)) xlabel(, format(%9.0f))  ///
        title("") xsize(5.9) ysize(4.1) name(g_qq_sa, replace)
    graph export "Fig9_qq_sede_anio_`hoy'.png", width(2000)

    * Figura 10: residuos individuales (69.750 puntos)
    qnorm res,                                                            ///
        msymbol(p) mcolor(gs6) rlopts(lcolor(black))                       ///
        ytitle("Residuo individual (puntos)")                              ///
        xtitle("Cuantiles de la distribución normal")                      ///
        ylabel(, angle(horizontal) format(%9.0f)) xlabel(, format(%9.0f))  ///
        title("") xsize(5.9) ysize(4.1) name(g_qq_r, replace)
    graph export "Fig10_qq_residuos_`hoy'.png", width(2000)

    set dp period
}


********************************************************************************
* [4] CIERRE
********************************************************************************
timer off 1
display _newline "--- Tiempos: 1 total, 2 estimacion, 3 predict ---"
timer list

display _newline "{hline 78}"
display "17 v2 TERMINADO. Comparar las varianzas con el Anexo H antes de usar"
display "las figuras. Si coinciden, sustituir las Figuras 8 a 10 del informe."
display "{hline 78}"

log close fase17
