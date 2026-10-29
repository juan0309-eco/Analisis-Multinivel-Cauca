*==============================================================================
* 15_gradiente_medicion.do
* C6: heterogeneidad del gradiente (M4, M5) con efectos de año, la estructura
*     aleatoria de C1 y controles de error de medida.
*
* ENTRADA : Base_Estimacion.dta (la misma que usa 08 y 11)
* SALIDAS : log_15_gradiente_AAAAMMDD_HHMM.log, archivos .ster y .dta con fecha
*           en el nombre. Nada usa `replace`: si un archivo ya existe, Stata
*           aborta en vez de sobrescribirlo.
*
* MODELOS
*   [B] M4r, M5r : estructura C1 + pendiente aleatoria de cwc_inse en sede, REML
*   [E] efectos aleatorios por sede de M4r (insumo de las Figuras 6 y 7)
*   [C] M4c, M5c : M4r/M5r + DE del INSE en la cohorte de sede e INSE x rural
*   [D] M4d, M5d : M4c/M5c solo con cohortes de sede de al menos 10 estudiantes
*   [A] M4b, M5b : estructura ANTIGUA de 08 + ib2018.year, mle (aísla el efecto
*                  de añadir año fijo, sin tocar la estructura aleatoria)
*
* REGLAS FIJADAS ANTES DE VER RESULTADOS (se imprimen al final de cada modelo)
*   M5 : contraste conjunto de las dos interacciones al 5 %; solo si es
*        significativo se miran las interacciones con corrección de Holm (2
*        pruebas); en otro caso, M5 queda como exploratorio.
*   M4 : la correlación pendiente-intercepto se mantiene si su IC al 95 %
*        excluye el cero en M4r, M4c y M4d.
*
* Nombres de parámetros (confirmados con matrix list e(b) en el ensayo 15a):
*   lns1_1_1 municipio | lns1_2_1 municipio-año | lns2_1_1 DE de la pendiente
*   lns2_1_2 DE del intercepto de sede | atr2_1_1_2 atanh(corr) | lns3_1_1
*   sede-año | lnsig_e residual
*==============================================================================
version 17
clear all
set more off
set varabbrev off
if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* Interruptores: poner 0 para saltar un bloque
local hacer_r    = 1
local hacer_c    = 1
local hacer_d    = 1
local hacer_b    = 1
local hacer_efec = 1

capture log close _all
local f = string(date(c(current_date),"DMY"),"%tdCCYYNNDD")
local h = subinstr(substr(c(current_time),1,5),":","",.)
log using "log_15_gradiente_`f'_`h'.log", text name(fase15)
display "Inicio: " c(current_date) " " c(current_time)

global v_n1 mujer edad repitente lectura_30min libros_26omas trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado dotacion_tic rural ju_unica tecnico tecnico_academico cole_femenino

* Estructura aleatoria de C1 con la pendiente en sede
global RE_M4 "|| mcpio_id: || mcpio_id: R.year || sede_id: cwc_inse, covariance(unstructured) || sede_anio:"

*------------------------------------------------------------------------------
* Programas de lectura (usan los resultados posteados por mi estimate)
*------------------------------------------------------------------------------
capture program drop rep_corr
program define rep_corr
    args et
    local a   = _b[atr2_1_1_2:_cons]
    local s   = _se[atr2_1_1_2:_cons]
    local sdb = _b[lns2_1_1:_cons]
    local sds = _se[lns2_1_1:_cons]
    local z   = invnormal(0.975)
    display as text _newline "[`et']"
    display as text "  DE de la pendiente = " %7.4f exp(`sdb') "   IC95% [" %7.4f exp(`sdb'-`z'*`sds') "; " %7.4f exp(`sdb'+`z'*`sds') "]"
    display as text "  Correlación        = " %7.4f tanh(`a') "   IC95% [" %7.4f tanh(`a'-`z'*`s') "; " %7.4f tanh(`a'+`z'*`s') "]"
    if tanh(`a'-`z'*`s') > 0 | tanh(`a'+`z'*`s') < 0 {
        display as result "  REGLA M4: el IC de la correlación EXCLUYE el cero."
    }
    else {
        display as result "  REGLA M4: el IC de la correlación INCLUYE el cero."
    }
end

capture program drop rep_m5
program define rep_m5
    args et
    quietly test c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln
    local pj = r(p)
    quietly test c.cwc_inse#c.pct_planta
    local pa = r(p)
    quietly test c.cwc_inse#c.indice_vuln
    local pb = r(p)
    local pmin = min(`pa',`pb')
    local pmax = max(`pa',`pb')
    local h1 = min(1, 2*`pmin')
    local h2 = min(1, max(`h1', `pmax'))
    if `pa' <= `pb' {
        local ha = `h1'
        local hb = `h2'
    }
    else {
        local ha = `h2'
        local hb = `h1'
    }
    display as text _newline "[`et']"
    display as text "  cwc_inse x pct_planta   : coef " %7.4f _b[c.cwc_inse#c.pct_planta] " (EE " %6.4f _se[c.cwc_inse#c.pct_planta] ")  p = " %6.4f `pa' "  p Holm = " %6.4f `ha'
    display as text "  cwc_inse x indice_vuln  : coef " %7.4f _b[c.cwc_inse#c.indice_vuln] " (EE " %6.4f _se[c.cwc_inse#c.indice_vuln] ")  p = " %6.4f `pb' "  p Holm = " %6.4f `hb'
    display as text "  Contraste conjunto      : p = " %6.4f `pj'
    if `pj' >= 0.05 {
        display as result "  REGLA M5: contraste conjunto >= 0,05 -> sin heterogeneidad detectable; M5 pasa a anexo como exploratorio."
    }
    else {
        if min(`ha',`hb') < 0.05 {
            display as result "  REGLA M5: conjunto < 0,05 y al menos una interacción supera Holm -> se reporta solo la que la supera."
        }
        else {
            display as result "  REGLA M5: conjunto < 0,05 pero ninguna supera Holm -> evidencia conjunta no atribuible a una interacción; exploratoria."
        }
    }
end

*------------------------------------------------------------------------------
* [0] DATOS Y VARIABLES DERIVADAS (una sola vez, en memoria; no se guarda)
*------------------------------------------------------------------------------
display _newline(2) "{hline 78}"
display "[0] DATOS Y VARIABLES DERIVADAS"
display "{hline 78}"

use "Base_Estimacion.dta", clear

* sede_anio igual que en 11_estructura_aleatoria.do
foreach v in sede_anio {
    capture mi unregister `v'
    capture drop `v'
}
egen long sede_anio = group(cole_cod_dane_sede year)
mi register regular sede_anio
mi update

* DE del INSE dentro de la cohorte de sede, recalculada en cada imputación
foreach v in sd_inse_sede c_sd_inse n_sa {
    capture mi unregister `v'
    capture drop `v'
}
bysort _mi_m cole_cod_dane_sede year: egen double sd_inse_sede = sd(estu_inse_individual) if _mi_m > 0
bysort _mi_m cole_cod_dane_sede year: generate int n_sa = _N
replace sd_inse_sede = 0 if n_sa == 1 & _mi_m > 0
bysort _mi_m year: egen double _msd = mean(sd_inse_sede) if _mi_m > 0
generate double c_sd_inse = sd_inse_sede - _msd if _mi_m > 0
drop _msd
label variable sd_inse_sede "DE del INSE dentro de la cohorte de sede"
label variable c_sd_inse    "DE del INSE dentro de la cohorte de sede, centrada por año"
label variable n_sa         "Estudiantes en la cohorte de sede (sede-año)"
mi register imputed sd_inse_sede c_sd_inse
mi register regular n_sa
mi update

display _newline "--- Verificaciones ---"
quietly count if _mi_m > 0 & missing(c_sd_inse)
display "Faltantes de c_sd_inse en las imputaciones: " r(N) " (debe ser 0)"
assert r(N) == 0
quietly count if missing(sede_anio)
display "Filas sin sede_anio: " r(N) " (debe ser 0)"
assert r(N) == 0
quietly count if _mi_m == 1 & n_sa < 10
display "Observaciones en cohortes de sede con menos de 10 estudiantes (m=1): " r(N)
tabstat sd_inse_sede c_sd_inse n_sa if _mi_m == 1, stat(n mean sd min max) format(%9.4f)

timer clear

*------------------------------------------------------------------------------
* [B] M4r y M5r: estructura C1 + año fijo + pendiente aleatoria, REML
*------------------------------------------------------------------------------
if `hacer_r' == 1 {
    display _newline(2) "{hline 78}"
    display "[B] M4r y M5r: estructura C1, REML, 20 imputaciones"
    display "{hline 78}"

    timer on 1
    mi estimate, dots post: mixed punt_global cwc_inse c_inse_prom_sede          ///
        $v_n1 $v_n2 indice_vuln ib2018.year $RE_M4 , reml
    timer off 1
    estimates save "M4r_`f'.ster"
    matrix list e(b)
    rep_corr "M4r: estructura C1 + año fijo, REML"

    timer on 2
    mi estimate, dots post: mixed punt_global cwc_inse                           ///
        c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln                         ///
        c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year $RE_M4 , reml
    timer off 2
    estimates save "M5r_`f'.ster"
    matrix list e(b)
    rep_m5 "M5r: estructura C1 + año fijo, REML"
    rep_corr "M5r: componentes de la pendiente"

    * Efecto del INSE dentro de la sede evaluado en las medias de pct_planta e
    * indice_vuln (en M5 el coeficiente de cwc_inse está en pct_planta = 0 e
    * indice_vuln = 0, que no es un punto interpretable). Cálculo derivado.
    quietly summarize pct_planta if _mi_m == 1
    local mpl = r(mean)
    quietly summarize indice_vuln if _mi_m == 1
    local miv = r(mean)
    display _newline "Medias usadas: pct_planta = " %9.4f `mpl' "  indice_vuln = " %9.4f `miv'
    lincom cwc_inse + (`mpl')*c.cwc_inse#c.pct_planta + (`miv')*c.cwc_inse#c.indice_vuln
}

*------------------------------------------------------------------------------
* [C] M4c y M5c: controles de error de medida
*------------------------------------------------------------------------------
if `hacer_c' == 1 {
    display _newline(2) "{hline 78}"
    display "[C] M4c y M5c: + DE del INSE en la cohorte e INSE x rural"
    display "{hline 78}"

    timer on 3
    mi estimate, dots post: mixed punt_global cwc_inse                           ///
        c.cwc_inse#c.c_sd_inse c.cwc_inse#c.rural c_sd_inse                      ///
        c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year $RE_M4 , reml
    timer off 3
    estimates save "M4c_`f'.ster"
    matrix list e(b)
    rep_corr "M4c"

    timer on 4
    mi estimate, dots post: mixed punt_global cwc_inse                           ///
        c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln                         ///
        c.cwc_inse#c.c_sd_inse c.cwc_inse#c.rural c_sd_inse                      ///
        c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year $RE_M4 , reml
    timer off 4
    estimates save "M5c_`f'.ster"
    matrix list e(b)
    rep_m5 "M5c"
    rep_corr "M5c: componentes de la pendiente"
}

*------------------------------------------------------------------------------
* [D] M4d y M5d: solo cohortes de sede con al menos 10 estudiantes
*------------------------------------------------------------------------------
if `hacer_d' == 1 {
    display _newline(2) "{hline 78}"
    display "[D] M4d y M5d: n_sa >= 10"
    display "{hline 78}"

    timer on 5
    mi estimate, dots post: mixed punt_global cwc_inse                           ///
        c.cwc_inse#c.c_sd_inse c.cwc_inse#c.rural c_sd_inse                      ///
        c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year if n_sa >= 10       ///
        $RE_M4 , reml
    timer off 5
    estimates save "M4d_`f'.ster"
    matrix list e(b)
    rep_corr "M4d (n_sa >= 10)"

    timer on 6
    mi estimate, dots post: mixed punt_global cwc_inse                           ///
        c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln                         ///
        c.cwc_inse#c.c_sd_inse c.cwc_inse#c.rural c_sd_inse                      ///
        c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year if n_sa >= 10       ///
        $RE_M4 , reml
    timer off 6
    estimates save "M5d_`f'.ster"
    matrix list e(b)
    rep_m5 "M5d (n_sa >= 10)"
    rep_corr "M5d: componentes de la pendiente"
}

*------------------------------------------------------------------------------
* [A] M4b y M5b: estructura ANTIGUA de 08 + año fijo (mle)
*     Aísla el efecto de añadir ib2018.year; no es un modelo de referencia final.
*------------------------------------------------------------------------------
if `hacer_b' == 1 {
    display _newline(2) "{hline 78}"
    display "[A] M4b y M5b: estructura antigua de 08 + ib2018.year (mle)"
    display "{hline 78}"

    timer on 7
    mi estimate, dots post: mixed punt_global cwc_inse c_inse_prom_sede          ///
        $v_n1 $v_n2 indice_vuln ib2018.year                                      ///
        || mcpio_id: || sede_id: cwc_inse , mle covariance(unstructured)
    timer off 7
    estimates save "M4b_`f'.ster"
    matrix list e(b)
    rep_corr "M4b: estructura antigua + año fijo, mle"

    timer on 8
    mi estimate, dots post: mixed punt_global cwc_inse                           ///
        c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln                         ///
        c_inse_prom_sede $v_n1 $v_n2 indice_vuln ib2018.year                     ///
        || mcpio_id: || sede_id: cwc_inse , mle covariance(unstructured)
    timer off 8
    estimates save "M5b_`f'.ster"
    matrix list e(b)
    rep_m5 "M5b: estructura antigua + año fijo, mle"
}

*------------------------------------------------------------------------------
* [E] Efectos aleatorios por sede de M4r (Figuras 6 y 7), imputación 1
*     Va al final porque reemplaza el conjunto de datos en memoria.
*     Los BLUP están encogidos hacia cero: sirven para el gráfico, NO para
*     estimar la correlación, que sale del modelo (rep_corr).
*------------------------------------------------------------------------------
if `hacer_efec' == 1 {
    display _newline(2) "{hline 78}"
    display "[E] EFECTOS ALEATORIOS POR SEDE (M4r, imputación 1)"
    display "{hline 78}"

    mi extract 1, clear
    timer on 9
    mixed punt_global cwc_inse c_inse_prom_sede $v_n1 $v_n2 indice_vuln          ///
        ib2018.year $RE_M4 , reml
    timer off 9
    display "converged (M4r, m=1) = " e(converged)

    * Orden esperado de los efectos de sede: pendiente (cwc_inse), luego intercepto.
    * VERIFICAR con describe y con los signos antes de graficar.
    capture noisily predict double b_pend b_int, reffects relevel(sede_id)
    capture noisily predict double se_pend se_int, reses relevel(sede_id)
    describe b_pend b_int se_pend se_int
    summarize b_pend b_int se_pend se_int
    correlate b_pend b_int

    keep cole_cod_dane_sede sede_id b_pend b_int se_pend se_int
    duplicates drop
    isid sede_id
    display "Sedes con efectos predichos: " _N
    save "Efectos_sede_M4r_`f'.dta"
}

*------------------------------------------------------------------------------
display _newline(2) "--- Tiempos (s): 1=M4r 2=M5r 3=M4c 4=M5c 5=M4d 6=M5d 7=M4b 8=M5b 9=efectos ---"
timer list
display "Fin: " c(current_date) " " c(current_time)
log close fase15
