*==============================================================================
* 15b_lecturas.do
* C6: lecturas derivadas sobre los .ster ya estimados por 15_gradiente_medicion.do
*     NO reestima ningún modelo. Corre en minutos, no en horas.
*
* ENTRADA : M4r_20261013.ster  M5r_20261013.ster  M4c_20261013.ster
*           M5c_20261013.ster  M4d_20261013.ster  M5d_20261013.ster
*           Efectos_sede_M4r_20261013.dta   Base_Estimacion.dta
* SALIDAS : log_15b_lecturas_AAAAMMDD_HHMM.log
*           Fig6_gradiente_AAAAMMDD.png   Fig7_int_pend_AAAAMMDD.png
*
* QUÉ AÑADE
*   [1] Descriptivos de c_sd_inse y rural (imputación 1), para interpretar los
*       coeficientes de M4c/M4d y para verificar la identidad del promedio.
*   [2] lincom: pendiente del INSE en urbano y en rural, y a mas/menos una DE de
*       dispersión. En M4c/M4d el coeficiente de cwc_inse está evaluado en
*       rural = 0 y c_sd_inse = 0, de modo que por sí solo no es el gradiente medio.
*   [3] Figuras 6 y 7 con los efectos aleatorios de M4r, coloreadas por zona.
*==============================================================================
version 17
clear all
set more off
set varabbrev off
if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* Fecha de los archivos que dejó 15_gradiente_medicion.do
local fin = "20261013"

capture log close _all
local f = string(date(c(current_date),"DMY"),"%tdCCYYNNDD")
local h = subinstr(substr(c(current_time),1,5),":","",.)
log using "log_15b_lecturas_`f'_`h'.log", text name(fase15b)
display "Inicio: " c(current_date) " " c(current_time)

*------------------------------------------------------------------------------
* [1] DESCRIPTIVOS (imputación 1) Y ARCHIVO DE SEDE PARA LOS GRÁFICOS
*------------------------------------------------------------------------------
display _newline(2) "{hline 78}"
display "[1] DESCRIPTIVOS DE c_sd_inse, rural Y n_sa (imputación 1)"
display "{hline 78}"

use "Base_Estimacion.dta", clear
mi extract 1, clear

* Mismas definiciones del bloque [0] del 15, ya sobre datos planos
bysort cole_cod_dane_sede year: egen double sd_inse_sede = sd(estu_inse_individual)
bysort cole_cod_dane_sede year: generate int n_sa = _N
replace sd_inse_sede = 0 if n_sa == 1
bysort year: egen double _msd = mean(sd_inse_sede)
generate double c_sd_inse = sd_inse_sede - _msd
drop _msd

display _newline "--- Proporción de observaciones rurales ---"
summarize rural
scalar p_rural = r(mean)

display _newline "--- Dispersión del INSE por zona ---"
tabstat sd_inse_sede c_sd_inse n_sa, by(rural) stat(n mean sd min max) format(%9.4f)
quietly summarize c_sd_inse
scalar sd_c = r(sd)
display _newline "DE de c_sd_inse (para los lincom): " %9.4f sd_c

display _newline "--- Media de c_sd_inse dentro de cada zona ---"
foreach z in 0 1 {
    quietly summarize c_sd_inse if rural == `z'
    display "  rural = `z' : media " %9.4f r(mean) "   n = " r(N)
    scalar m_csd_`z' = r(mean)
}

* Archivo de sede (zona y dispersión media) para colorear las figuras
preserve
    collapse (mean) rural sd_inse_sede c_sd_inse n_sa, by(cole_cod_dane_sede)
    rename sd_inse_sede sd_inse_media
    rename c_sd_inse    c_sd_media
    rename n_sa         n_sa_medio
    label variable sd_inse_media "DE media del INSE dentro de la sede (imp. 1)"
    tempfile sedes
    save "`sedes'"
restore

*------------------------------------------------------------------------------
* [2] PENDIENTE DEL INSE POR ZONA Y POR DISPERSIÓN (lincom sobre los .ster)
*------------------------------------------------------------------------------
display _newline(2) "{hline 78}"
display "[2] PENDIENTE DEL INSE SEGÚN ZONA Y DISPERSIÓN"
display "{hline 78}"
display "Nota: en M4c/M4d/M5c/M5d el coeficiente de cwc_inse está evaluado en"
display "rural = 0 y c_sd_inse = 0 (dispersión media del año). Los contrastes"
display "siguientes dan el gradiente en puntos interpretables, con su EE."

local sdc = sd_c
local pr  = p_rural

foreach m in M4c M4d M5c M5d {
    capture estimates use "`m'_`fin'.ster"
    if _rc != 0 {
        display as error "No se encontró `m'_`fin'.ster"
        continue
    }
    display _newline "{hline 60}"
    display "--- `m' ---"

    display _newline "  (a) Urbano, dispersión media del año"
    capture noisily lincom cwc_inse

    display _newline "  (b) Rural, dispersión media del año"
    capture noisily lincom cwc_inse + c.cwc_inse#c.rural

    display _newline "  (c) Urbano, +1 DE de dispersión (`sdc')"
    capture noisily lincom cwc_inse + (`sdc')*c.cwc_inse#c.c_sd_inse

    display _newline "  (d) Urbano, -1 DE de dispersión"
    capture noisily lincom cwc_inse - (`sdc')*c.cwc_inse#c.c_sd_inse

    display _newline "  (e) Rural, con la dispersión media observada en zona rural"
    capture noisily lincom cwc_inse + c.cwc_inse#c.rural + (m_csd_1)*c.cwc_inse#c.c_sd_inse

    display _newline "  (f) Urbano, con la dispersión media observada en zona urbana"
    capture noisily lincom cwc_inse + (m_csd_0)*c.cwc_inse#c.c_sd_inse

    display _newline "  (g) Gradiente medio: promedio ponderado por la proporción rural (`pr')"
    capture noisily lincom cwc_inse + (`pr')*c.cwc_inse#c.rural
    display "      Debe quedar cerca del cwc_inse de M4r/M5r. Es una verificación."
}

* En M5r y M5c, el gradiente evaluado en las medias de planta y vulnerabilidad
display _newline(2) "{hline 60}"
display "--- M5c: gradiente en las medias de pct_planta e indice_vuln ---"
quietly summarize pct_planta
local mpl = r(mean)
quietly summarize indice_vuln
local miv = r(mean)
display "Medias: pct_planta = " %9.4f `mpl' "   indice_vuln = " %9.4f `miv'
capture estimates use "M5c_`fin'.ster"
if _rc == 0 {
    capture noisily lincom cwc_inse + (`mpl')*c.cwc_inse#c.pct_planta        ///
        + (`miv')*c.cwc_inse#c.indice_vuln
}

*------------------------------------------------------------------------------
* [3] FIGURAS 6 Y 7 CON LOS EFECTOS ALEATORIOS DE M4r
*------------------------------------------------------------------------------
display _newline(2) "{hline 78}"
display "[3] FIGURAS 6 Y 7"
display "{hline 78}"

use "Efectos_sede_M4r_`fin'.dta", clear
merge 1:1 cole_cod_dane_sede using "`sedes'", keep(master match)
tabulate _merge
drop _merge

* Gradiente total de cada sede: efecto fijo de M4r + BLUP de la pendiente.
* 0.1949758 es el coeficiente de cwc_inse en M4r [log_15_gradiente, bloque B].
generate double grad_sede = 0.1949758 + b_pend
label variable grad_sede "Gradiente socioeconómico de la sede (M4r)"
summarize grad_sede, detail
quietly count if grad_sede < 0
display "Sedes con gradiente negativo estimado: " r(N) " de " _N
display "Nota: son BLUP encogidos hacia cero; describen el ordenamiento, no dan"
display "inferencia sede por sede."

* --- Figura 6: gradiente ordenado, con banda de más/menos un EE ---
sort grad_sede
generate int rango = _n
generate double g_lo = grad_sede - 1.96*se_pend
generate double g_hi = grad_sede + 1.96*se_pend

twoway (rarea g_lo g_hi rango, color(gs13) lwidth(none))                       ///
       (line grad_sede rango, lcolor(navy) lwidth(medthick))                   ///
       (function y = 0.1949758, range(1 `=_N') lpattern(dash) lcolor(maroon)), ///
    legend(order(2 "Gradiente de la sede" 1 "IC 95 %" 3 "Gradiente medio")      ///
           rows(1) size(small))                                                 ///
    ytitle("Puntos del Saber 11 por punto de INSE") xtitle("Sedes ordenadas")  ///
    title("Figura 6. Gradiente socioeconómico por sede")                        ///
    note("M4r: estructura de C1, efectos de año, REML, 20 imputaciones.") ///
    graphregion(color(white))
graph export "Fig6_gradiente_`f'.png", width(2000) replace

* --- Figura 7: intercepto frente a pendiente, por zona ---
twoway (scatter b_pend b_int if rural < 0.5, mcolor(navy%50) msymbol(O))       ///
       (scatter b_pend b_int if rural >= 0.5, mcolor(maroon%50) msymbol(T))    ///
       (lfit b_pend b_int, lcolor(black) lpattern(solid)),                     ///
    legend(order(1 "Urbana" 2 "Rural" 3 "Ajuste lineal") rows(1) size(small))  ///
    xtitle("Efecto aleatorio del nivel de la sede") ///
    ytitle("Efecto aleatorio de la pendiente") ///
    title("Figura 7. Nivel y gradiente de la sede") ///
    note("Correlación del modelo: 0,381 [0,195; 0,540] (M4r). La correlación de" ///
         "los efectos predichos es mayor por el encogimiento de los BLUP.") ///
    graphregion(color(white))
graph export "Fig7_int_pend_`f'.png", width(2000) replace

display _newline "--- Correlación de los efectos predichos, por zona ---"
correlate b_pend b_int
foreach z in 0 1 {
    display _newline "rural = `z':"
    capture noisily correlate b_pend b_int if (rural >= 0.5) == `z'
}

display _newline "--- Pendiente predicha por zona (BLUP, descriptivo) ---"
tabstat grad_sede, by(rural) stat(n mean sd p25 p50 p75) format(%9.4f)

display _newline "Fin: " c(current_date) " " c(current_time)
log close fase15b
