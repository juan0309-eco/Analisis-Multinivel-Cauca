********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 09 - TABLAS Y GRÁFICOS
* ENTRADA  : M0_<año>, M1a…M3ctx_<año>, M3cwc_<año> (.ster del 08)
*            ML1b, ML2b, ML3b, ML4b, R5_inv_fut_b, R5b_inv_fut_dep_b,
*            R6_ing_trib_b (.ster del 11)
*            R1b_indice_anual_<f18>, R3b_parsimonioso_<f18> (.ster del 18)
*            Efectos_sede_M4r_<f15>.dta (del 15)
*            ICC_por_year.dta, Coef_por_year.dta, Base_Estimacion.dta,
*            Base_Multinivel_PCA.dta
* SALIDA   : log_09_tablas_<hoy>.log
*            Tabla_Obj2_ICC_<hoy>.csv, Fig_Obj2_*_<hoy>.png
*            Tabla12_fusionada_<hoy>.rtf        (cuerpo, apartado 4.3.2)
*            Tabla42_completa_<hoy>.rtf         (Anexo G)
*            Tabla_Obj3_anual_<año>_<hoy>.rtf   (progresión por cohorte)
*            Fig_Obj3_evolucion_coef_<hoy>.png  (Figura 5)
*            Tabla_Obj4_temporal_<hoy>.rtf      (ML1b-ML4b)
*            Fig_Obj3_efectos_sede_<hoy>.png, Fig_Obj3_gradiente_<hoy>.png
*            Tabla_robustez_<hoy>.rtf
* STATA    : 17
* VERSIÓN  : 6 - corrección C11 (29-10-2026)
********************************************************************************
* QUÉ CAMBIA RESPECTO DE LA VERSIÓN 5
*
* [2.1] Las Tablas 8 y 10 del informe se fusionan en una sola (Tabla 12):
*       βw, βb y βc con su error estándar, el resto de los coeficientes una
*       vez y, al pie, estudiantes, sedes, municipios, varianzas y ajuste.
*       βc = βb − βw se añade como fila con su error estándar exacto: se
*       reescribe la estimación de M3cwc con la transformación lineal A·b y
*       la varianza A·V·A' (programa _post_ctx). Coincide con el coeficiente
*       de c_inse_prom_sede en M3ctx (identidad de Kreft, bloque [3.1] del 08).
* [2.1b] La versión completa (Tabla 42 del Anexo G) añade la constante, las
*       desviaciones estándar de los efectos aleatorios, el contraste βw = βb
*       y el criterio bayesiano.
* [2.1c] El panel B de la Tabla 12 (coeficientes en desviaciones estándar del
*       puntaje) se calcula aquí. Es un cálculo derivado.
* [5]   La tabla del Objetivo 4 lee ML1b a ML4b del 11 (estructura de cuatro
*       componentes) y no ML1 a ML4 del 08 (pendiente 2 del README).
* [6]   Las dos figuras de efectos de sede dejan de reestimar M4 con la
*       estructura antigua: leen los efectos predichos de M4r que guarda el
*       15 (estructura vigente, la misma de las Figuras 6 y 7 del 15c).
* [7]   La tabla de robustez lee R1b y R3b del 18 y R5, R5b y R6 del 11
*       (pendiente 2), y compara cada prueba con su modelo de referencia.
* Rótulos (C8): ninguna fila dice «inversión» para la asignación, ni
*       «estabilidad» para la planta, ni «contextual» para βb.
* Ejes (29-10-2026, tras la corrida 20261029): con set dp comma, las Figuras
*       4, 5 y 7 mostraban «22,00», «,6» y «-,5». Se fija el formato de las
*       etiquetas de los ejes para que lleven cero inicial y los decimales justos.
* Registro: cabecera estándar del README (guard de log y local hoy). Ninguna
*       salida lleva replace: todas llevan la etiqueta hoy.
*
* ESTE SCRIPT NO ESTIMA MODELOS DEL INFORME
* Lee los .ster. La única estimación es la del bloque [2.0], que reproduce la
* log-verosimilitud, el AIC y el BIC de la Tabla 44 sobre la primera
* imputación (la verosimilitud no se combina entre imputaciones). Se apaga con
* hacer_ajuste = 0; entonces el panel C deja esas filas vacías.
*
* SEPARADOR DECIMAL
* set dp comma hace que esttab escriba coma decimal y punto de miles, como el
* informe. Se restituye al final.
*
* REQUISITOS: ssc install estout, replace
********************************************************************************

version 17
clear all
set more off
set varabbrev off

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ---------------------------------------------------------------------------
* CABECERA ESTÁNDAR. Solo se editan las líneas marcadas con <<<.
* ---------------------------------------------------------------------------
local tarea "09_tablas"
local hoy   "20261029b"         // <<< etiqueta de ESTA corrida (salidas)
local f18   "20261026"          // <<< etiqueta de los .ster del 18 (entrada)
local f15   "20261013"          // <<< etiqueta de Efectos_sede_M4r (entrada)

local hacer_ajuste = 1          // <<< 1: reproduce el ajuste de la Tabla 44

capture log close _all
capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase9)
display "Tarea: `tarea'   salida: `hoy'   " c(current_date) " " c(current_time)
timer clear
timer on 1

capture which esttab
if _rc != 0 {
    display as error "Falta el paquete estout. Ejecute: ssc install estout, replace"
    log close fase9
    exit 111
}

set scheme s1mono
set dp comma

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

* Rótulos de las filas (C8). Una sola lista para todas las tablas.
local rot ///
    c_inse           "INSE, componente dentro de la sede (βw)"            ///
    cwc_inse         "INSE, componente dentro de la sede (βw)"            ///
    c_inse_prom_sede "INSE medio de la sede, componente entre sedes (βb)" ///
    ctx              "Componente contextual (βc = βb − βw)"              ///
    mujer            "Mujer"                                              ///
    edad             "Edad"                                               ///
    repitente        "Repitente de la prueba"                             ///
    lectura_30min    "Lectura diaria (30 min. o más)"                     ///
    libros_26omas    "Libros en el hogar (26 o más)"                      ///
    trabaja_mas20    "Trabajo intensivo (más de 20 h/semana)"             ///
    internet_hogar   "Internet en el hogar"                               ///
    computador_hogar "Computador en el hogar"                             ///
    ln_matricula     "Log de matrícula"                                   ///
    ratio_alumnos_docente "Alumnos por docente"                           ///
    pct_planta       "Docentes de planta"                                 ///
    z_posgrado       "Docentes con posgrado"                              ///
    dotacion_tic     "Dotación TIC"                                       ///
    rural            "Sede rural"                                         ///
    ju_unica         "Jornada única"                                      ///
    tecnico          "Carácter técnico"                                   ///
    tecnico_academico "Técnico-académico"                                 ///
    cole_femenino    "Sede femenina"                                      ///
    indice_vuln      "Índice de vulnerabilidad"                           ///
    indice_vuln_anual "Índice con estandarización intra-anual"            ///
    vuln_bar         "Índice, componente entre municipios"                ///
    vuln_dev         "Índice, componente dentro del municipio"            ///
    tasa_homicidios_bar "Tasa de homicidios, componente entre municipios"  ///
    tasa_homicidios_dev "Tasa de homicidios, componente dentro del municipio" ///
    ln_coca_bar      "Log de coca, componente entre municipios"           ///
    ln_coca_dev      "Log de coca, componente dentro del municipio"       ///
    ln_inversion_pc_bar "Asignación SGP de libre inversión, componente entre municipios" ///
    ln_inversion_pc_dev "Asignación SGP de libre inversión, componente dentro del municipio" ///
    ln_inv_fut_pc_bar "Inversión ejecutada del FUT, componente entre municipios" ///
    ln_inv_fut_pc_dev "Inversión ejecutada del FUT, componente dentro del municipio" ///
    ln_inv_fut_pc_x_bar "Inversión ejecutada del FUT depurada, componente entre municipios" ///
    ln_inv_fut_pc_x_dev "Inversión ejecutada del FUT depurada, componente dentro del municipio" ///
    ln_ing_trib_pc_bar "Recaudo tributario propio, componente entre municipios" ///
    ln_ing_trib_pc_dev "Recaudo tributario propio, componente dentro del municipio" ///
    2019.year "Año 2019" 2020.year "Año 2020" 2021.year "Año 2021"       ///
    2022.year "Año 2022" 2023.year "Año 2023"                             ///
    _cons            "Constante"

* Orden de los coeficientes de la Tabla 12 (el de las Tablas 8 y 10)
local orden12 cwc_inse c_inse_prom_sede ctx $v_n1 $v_n2 indice_vuln


********************************************************************************
* PROGRAMA: añade βc = βb − βw a la estimación de M3cwc en memoria
********************************************************************************
capture program drop _post_ctx
program define _post_ctx, eclass
    tempname b V bf Vf A bn Vn
    matrix `b' = e(b)
    matrix `V' = e(V)
    local N = e(N)
    matrix `bf' = `b'[1, "punt_global:"]
    matrix `Vf' = `V'["punt_global:", "punt_global:"]
    local k  = colsof(`bf')
    local jw = colnumb(`bf', "punt_global:cwc_inse")
    local jb = colnumb(`bf', "punt_global:c_inse_prom_sede")
    if missing(`jw') | missing(`jb') {
        display as error "M3cwc no tiene cwc_inse o c_inse_prom_sede."
        exit 111
    }
    matrix `A' = I(`k') \ J(1, `k', 0)
    matrix `A'[`k' + 1, `jw'] = -1
    matrix `A'[`k' + 1, `jb'] =  1
    matrix `bn' = (`A' * `bf'')'
    matrix `Vn' = `A' * `Vf' * `A''
    local nombres : colnames `bf'
    local nombres `nombres' ctx
    matrix colnames `bn' = `nombres'
    matrix colnames `Vn' = `nombres'
    matrix rownames `Vn' = `nombres'
    ereturn post `bn' `Vn', obs(`N')
    ereturn local cmd "c11_ctx"
end


********************************************************************************
* [1] PARTICIÓN DE LA VARIANZA POR AÑO (OBJETIVO 2): Tabla 10, Figuras 3 y 4
********************************************************************************
display _newline "{hline 78}"
display "[1] OBJETIVO 2"
display "{hline 78}"

use "ICC_por_year.dta", clear
foreach v in icc_mcpio icc_sede icc_est {
    generate double p_`v' = 100 * `v'
}
format p_* %6.2f
format v_* %9.1f
list year p_icc_mcpio p_icc_sede p_icc_est, clean noobs
list year v_mcpio v_sede v_est, clean noobs
export delimited using "Tabla_Obj2_ICC_`hoy'.csv"

generate double acum1 = p_icc_mcpio
generate double acum2 = p_icc_mcpio + p_icc_sede
generate double acum3 = 100
twoway (area acum3 year, color(gs14))                                        ///
       (area acum2 year, color(gs10))                                        ///
       (area acum1 year, color(gs5)),                                        ///
    legend(order(3 "Municipio" 2 "Sede" 1 "Estudiante") rows(1) position(6)) ///
    ytitle("Porcentaje de la varianza total") xtitle("Año de la cohorte")    ///
    ylabel(0(20)100, angle(horizontal)) xlabel(2018(1)2023)                  ///
    title("") name(g_icc_area, replace)
graph export "Fig_Obj2_particion_`hoy'.png", width(2000)

twoway (connected p_icc_sede year, msymbol(O) lpattern(solid))               ///
       (connected p_icc_mcpio year, msymbol(S) lpattern(dash)),              ///
    legend(order(1 "Sede" 2 "Municipio") rows(1) position(6))                ///
    ytitle("Porcentaje de la varianza total") xtitle("Año de la cohorte")    ///
    ylabel(8(2)22, angle(horizontal) format(%9.0f)) xlabel(2018(1)2023)                    ///
    title("") name(g_icc_lineas, replace)
graph export "Fig_Obj2_evolucion_`hoy'.png", width(2000)


********************************************************************************
* [2.0] INSUMOS DE LOS PANELES B Y C: conteos, desviaciones y ajuste
********************************************************************************
display _newline "{hline 78}"
display "[2.0] CONTEOS, DESVIACIONES ESTÁNDAR Y AJUSTE POR COHORTE"
display "{hline 78}"

* Desviación estándar entre sedes de la proporción de docentes de planta,
* sobre las combinaciones de sede y año (mismo cálculo que el bloque [3] del
* 10b: 0,2862276 en log_10b_planta_fe.log).
use "Base_Multinivel_PCA.dta", clear
egen byte _t = tag(cole_cod_dane_sede year)
keep if _t == 1
egen long _sid = group(cole_cod_dane_sede)
xtset _sid year
quietly xtsum pct_planta
scalar sd_b_planta = r(sd_b)
display "DE entre sedes de la planta docente: " %9.7f sd_b_planta " (log_10b: 0,2862276)"

use "Base_Estimacion.dta", clear
mi extract 1, clear

foreach a in 2018 2019 2020 2021 2022 2023 {
    quietly count if year == `a'
    local nest_`a' = r(N)
    egen byte _ts = tag(sede_id) if year == `a'
    quietly count if _ts == 1
    local nsed_`a' = r(N)
    drop _ts
    egen byte _tm = tag(mcpio_id) if year == `a'
    quietly count if _tm == 1
    local nmun_`a' = r(N)
    drop _tm
    quietly summarize punt_global if year == `a'
    scalar sdp_`a' = r(sd)
    quietly summarize cwc_inse if year == `a'
    scalar sdw_`a' = r(sd)
    quietly summarize c_inse_prom_sede if year == `a'
    scalar sdb_`a' = r(sd)
    display "`a'  estudiantes " `nest_`a'' "  sedes " `nsed_`a'' "  municipios " `nmun_`a'' ///
            "  DE puntaje " %7.3f sdp_`a' "  DE dentro " %6.3f sdw_`a' "  DE media " %6.3f sdb_`a'
}
display "Control: estudiantes 11.456 / 11.487 / 10.992 / 11.652 / 11.797 / 12.366;"
display "sedes 388 / 399 / 406 / 416 / 417 / 421 (log_08_estimacion.log, bloque [3])."

* Ajuste sobre la primera imputación (Tabla 44, modelo M3cwc)
foreach a in 2018 2019 2020 2021 2022 2023 {
    local ll_`a'  = .
    local aic_`a' = .
    local bic_`a' = .
}
if `hacer_ajuste' == 1 {
    foreach a in 2018 2019 2020 2021 2022 2023 {
        quietly mixed punt_global cwc_inse c_inse_prom_sede $v_n1 $v_n2 ///
            indice_vuln if year == `a' || mcpio_id: || sede_id: , mle
        quietly estat ic
        matrix S = r(S)
        local ll_`a'  = S[1, 3]
        local aic_`a' = S[1, 5]
        local bic_`a' = S[1, 6]
        display "`a'  ll " %12.2f `ll_`a'' "  AIC " %12.2f `aic_`a'' "  BIC " %12.2f `bic_`a''
    }
    display "Control (Tabla 44, M3cwc): ll 2018 = −56.713,57; AIC 2018 = 113.477,13."
}


********************************************************************************
* [2.1] TABLA 12: MODELO CONTEXTUAL POR COHORTE, TABLAS 8 Y 10 FUSIONADAS
********************************************************************************
display _newline "{hline 78}"
display "[2.1] TABLA 12 FUSIONADA Y TABLA 42 COMPLETA"
display "{hline 78}"

capture estimates clear
local cols ""
foreach a in 2018 2019 2020 2021 2022 2023 {
    * Coeficiente de la media de sede en M3ctx, para verificar βc (Kreft)
    scalar bc_ctx = .
    capture estimates use "M3ctx_`a'.ster"
    if _rc == 0 scalar bc_ctx = _b[c_inse_prom_sede]

    capture estimates use "M3cwc_`a'.ster"
    if _rc != 0 {
        display as error "No se encontró M3cwc_`a'.ster: se omite la cohorte."
        continue
    }
    * Contraste βw = βb (Tabla 15) y efectos aleatorios, antes de reescribir
    quietly test cwc_inse = c_inse_prom_sede
    scalar chi_c = r(chi2)
    scalar p_c   = r(p)
    scalar bw = _b[cwc_inse]
    scalar bb = _b[c_inse_prom_sede]
    scalar bpl = _b[pct_planta]
    scalar bru = _b[rural]
    foreach k in 1 2 {
        scalar lns`k' = _b[lns`k'_1_1:_cons]
        scalar lns`k'_se = _se[lns`k'_1_1:_cons]
    }
    scalar lnse = _b[lnsig_e:_cons]
    scalar lnse_se = _se[lnsig_e:_cons]

    _post_ctx

    estadd scalar chi_c   = chi_c
    estadd scalar p_c     = p_c
    estadd scalar n_est   = `nest_`a''
    estadd scalar n_sede  = `nsed_`a''
    estadd scalar n_mcpio = `nmun_`a''
    estadd scalar v_mcpio = exp(2*lns1)
    estadd scalar v_sede  = exp(2*lns2)
    estadd scalar v_resid = exp(2*lnse)
    estadd scalar sd_mcpio = exp(lns1)
    estadd scalar sd_mcpio_se = exp(lns1)*lns1_se
    estadd scalar sd_sede = exp(lns2)
    estadd scalar sd_sede_se = exp(lns2)*lns2_se
    estadd scalar sd_resid = exp(lnse)
    estadd scalar sd_resid_se = exp(lnse)*lnse_se
    estadd scalar ll_m1  = `ll_`a''
    estadd scalar aic_m1 = `aic_`a''
    estadd scalar bic_m1 = `bic_`a''
    * Panel B (cálculo derivado): coeficiente × DE de su variable / DE del puntaje
    estadd scalar de_bw = bw*sdw_`a'/sdp_`a'
    estadd scalar de_bb = bb*sdb_`a'/sdp_`a'
    estadd scalar de_pl = bpl*sd_b_planta/sdp_`a'
    estadd scalar de_ru = bru/sdp_`a'
    estimates store F`a'
    local cols "`cols' F`a'"
    display "`a'  βc = " %7.4f _b[ctx] " (" %6.4f _se[ctx] ")   M3ctx: " %7.4f bc_ctx
}
display "Control: βc 2018 = 0,606 (0,261), 2023 = 1,018 (0,262) (Tabla 12, βc)."

if "`cols'" != "" {
    * Cuerpo: coeficientes una vez, paneles B y C al pie
    esttab `cols' using "Tabla12_fusionada_`hoy'.rtf",                       ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress             ///
        order(`orden12') keep(`orden12') coeflabels(`rot')                   ///
        mtitles("2018" "2019" "2020" "2021" "2022" "2023") nonumbers         ///
        stats(de_bw de_bb de_pl de_ru n_est n_sede n_mcpio                   ///
              v_mcpio v_sede v_resid ll_m1 aic_m1,                           ///
              fmt(%9.3f %9.3f %9.3f %9.3f %9.0fc %9.0f %9.0f                  ///
                  %9.2f %9.2f %9.2fc %12.2fc %12.2fc)                        ///
              labels("βw en DE del puntaje (cálculo derivado)"                ///
                     "βb en DE del puntaje (cálculo derivado)"                ///
                     "Docentes de planta en DE del puntaje (cálculo derivado)" ///
                     "Sede rural en DE del puntaje (cálculo derivado)"        ///
                     "Estudiantes" "Sedes" "Municipios"                       ///
                     "Varianza entre municipios" "Varianza entre sedes"       ///
                     "Varianza residual" "Log-verosimilitud (imputación 1)"   ///
                     "AIC (imputación 1)"))                                   ///
        title("Modelo contextual por cohorte, con los componentes dentro de la sede, entre sedes y contextual") ///
        addnotes("βw: índice centrado en la media de la sede; βb: media de la sede con centrado al clúster; βc = βb − βw: la misma media con centrado en la gran media." ///
                 "Error estándar entre paréntesis. * p < 0,10; ** p < 0,05; *** p < 0,01." ///
                 "Panel B, cálculo derivado: coeficiente por la DE de su variable en la cohorte (planta: DE entre sedes) entre la DE del puntaje." ///
                 "Log-verosimilitud y AIC sobre la primera imputación; no se combinan entre imputaciones.")

    * Anexo G: versión completa
    esttab `cols' using "Tabla42_completa_`hoy'.rtf",                        ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress             ///
        order(`orden12' _cons) keep(`orden12' _cons) coeflabels(`rot')       ///
        mtitles("2018" "2019" "2020" "2021" "2022" "2023") nonumbers         ///
        stats(sd_mcpio sd_mcpio_se sd_sede sd_sede_se sd_resid sd_resid_se    ///
              chi_c p_c n_est n_sede n_mcpio ll_m1 aic_m1 bic_m1,            ///
              fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.2f %9.3f             ///
                  %9.0fc %9.0f %9.0f %12.2fc %12.2fc %12.2fc)                 ///
              labels("D. E. municipio" "  (error estándar)"                   ///
                     "D. E. sede" "  (error estándar)"                        ///
                     "D. E. residual" "  (error estándar)"                    ///
                     "Contraste βw = βb, chi cuadrado (1 gl)" "Valor p"       ///
                     "Estudiantes" "Sedes" "Municipios"                       ///
                     "Log-verosimilitud (imputación 1)" "AIC (imputación 1)"  ///
                     "BIC (imputación 1)"))                                   ///
        title("Modelo contextual por cohorte, versión completa")             ///
        addnotes("Mismos modelos que la Tabla 12. La constante no se interpreta: corresponde a covariables sin centrar, como la edad.")

    * Vista en pantalla para cotejar con el informe
    esttab `cols', b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress  ///
        order(`orden12') keep(cwc_inse c_inse_prom_sede ctx pct_planta rural) ///
        coeflabels(`rot') mtitles("2018" "2019" "2020" "2021" "2022" "2023") ///
        stats(de_bw de_bb de_pl de_ru n_est n_sede v_mcpio v_sede v_resid,   ///
              fmt(%9.3f %9.3f %9.3f %9.3f %9.0fc %9.0f %9.2f %9.2f %9.2fc))
    display "Control del panel B (Tabla 12, cálculo derivado): planta 2018 = 0,097; rural 2023 = −0,164."
}

* ----------------------------------------------------------------------
* [2.2] Progresión completa de cada cohorte (M1a a M3ctx)
* ----------------------------------------------------------------------
foreach a in 2018 2019 2020 2021 2022 2023 {
    capture estimates clear
    local cp ""
    foreach m in M1a M1 M2 M3 M3ctx {
        capture estimates use "`m'_`a'.ster"
        if _rc == 0 {
            estimates store P`m'
            local cp "`cp' P`m'"
        }
    }
    if "`cp'" != "" {
        esttab `cp' using "Tabla_Obj3_anual_`a'_`hoy'.rtf",                  ///
            b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                         ///
            keep(punt_global:*) noomitted coeflabels(`rot')                  ///
            mtitles("M1a" "M1" "M2" "M3" "M3ctx")                            ///
            title("Progresión de modelos, cohorte `a'")                      ///
            addnotes("M1a: gradiente socioeconómico con sexo y edad; M1: bloque individual completo." ///
                     "En M3ctx, el índice individual mide el componente dentro de la sede y la media de la sede el componente contextual (βc)." ///
                     "Máxima verosimilitud sobre veinte imputaciones.") ///
            nogaps compress
    }
}

* ----------------------------------------------------------------------
* [2.3] Figura 5: evolución del gradiente (modelos por cohorte del 08)
* ----------------------------------------------------------------------
preserve
    use "Coef_por_year.dta", clear
    keep if inlist(modelo, "M1a", "M3ctx")
    generate double lo = b_ind - 1.96*se_ind
    generate double hi = b_ind + 1.96*se_ind
    generate byte mod = 1 if modelo == "M1a"
    replace     mod = 2 if modelo == "M3ctx"
    list year modelo b_ind lo hi, clean noobs
    twoway (rarea lo hi year if mod == 1, color(gs13))                       ///
           (connected b_ind year if mod == 1, msymbol(O) lcolor(black)       ///
                mcolor(black))                                               ///
           (rarea lo hi year if mod == 2, color(gs15))                       ///
           (connected b_ind year if mod == 2, msymbol(S) lpattern(dash)      ///
                lcolor(black) mcolor(black)),                                ///
        legend(order(2 "Gradiente total (M1a)"                               ///
                     4 "Componente dentro de la sede (M3ctx)")               ///
               rows(1) position(6) size(small))                              ///
        ytitle("Puntos por unidad del índice socioeconómico")                ///
        xtitle("Año de la cohorte")                                          ///
        ylabel(0(0.2)0.6, angle(horizontal) format(%3.1f))                     ///
        xlabel(2018(1)2023) yline(0, lpattern(dot) lcolor(gs8))              ///
        name(g_grad_anual, replace)
    graph export "Fig_Obj3_evolucion_coef_`hoy'.png", width(2000)
restore


********************************************************************************
* [3] VARIANZA EXPLICADA POR BLOQUE, COHORTE POR COHORTE (Tabla 43)
********************************************************************************
display _newline "{hline 78}"
display "[3] VARIANZA EXPLICADA POR BLOQUE Y POR COHORTE"
display "{hline 78}"
display _newline "Año   Modelo   Municipio     Sede    Residuo   R2mcpio  R2sede"
foreach a in 2018 2019 2020 2021 2022 2023 {
    capture estimates use "M0_`a'.ster"
    if _rc != 0 {
        display as error "Falta M0_`a'.ster"
        continue
    }
    scalar vm0 = exp(2*_b[lns1_1_1:_cons])
    scalar vs0 = exp(2*_b[lns2_1_1:_cons])
    scalar vr0 = exp(2*_b[lnsig_e:_cons])
    display "`a'  Nulo   " %9.2f vm0 " " %9.2f vs0 " " %9.2f vr0
    foreach m in M1a M1 M2 M3 M3ctx {
        capture estimates use "`m'_`a'.ster"
        if _rc == 0 {
            scalar vm = exp(2*_b[lns1_1_1:_cons])
            scalar vs = exp(2*_b[lns2_1_1:_cons])
            scalar vr = exp(2*_b[lnsig_e:_cons])
            display "`a'  `m'  " %9.2f vm " " %9.2f vs " " %9.2f vr ///
                    "   " %6.3f (vm0-vm)/vm0 "  " %6.3f (vs0-vs)/vs0
        }
    }
}


********************************************************************************
* [3B] GRADIENTE SOCIOECONÓMICO, COHORTE POR COHORTE (Tabla 17)
********************************************************************************
display _newline "{hline 78}"
display "[3B] GRADIENTE SOCIOECONÓMICO POR COHORTE"
display "{hline 78}"
use "Base_Estimacion.dta", clear
display _newline "Año   DE INSE   DE puntaje   Total   Ptos/DE   En DE   Dentro sede   Absorbido"
foreach a in 2018 2019 2020 2021 2022 2023 {
    quietly summarize estu_inse_individual if _mi_m == 1 & year == `a'
    scalar sd_inse = r(sd)
    quietly summarize punt_global if _mi_m == 1 & year == `a'
    scalar sd_punt = r(sd)
    scalar b_total = .
    scalar b_dentro = .
    capture estimates use "M1a_`a'.ster"
    if _rc == 0 scalar b_total = _b[c_inse]
    capture estimates use "M3ctx_`a'.ster"
    if _rc == 0 scalar b_dentro = _b[c_inse]
    if !missing(b_total) & !missing(b_dentro) {
        display "`a'  " %7.3f sd_inse "  " %8.3f sd_punt "  " ///
                %7.4f b_total "  " %7.3f b_total*sd_inse "  " ///
                %6.4f b_total*sd_inse/sd_punt "  " %9.4f b_dentro "  " ///
                %6.1f 100*(1 - b_dentro/b_total) "%"
    }
}


********************************************************************************
* [4] CONTRASTE βw = βb POR COHORTE (Tabla 15)
********************************************************************************
display _newline "{hline 78}"
display "[4] COMPONENTE DENTRO FRENTE A COMPONENTE ENTRE SEDES, POR COHORTE"
display "{hline 78}"
display "Año    βw        βb      βw − βb   Error est.        p"
foreach a in 2018 2019 2020 2021 2022 2023 {
    capture estimates use "M3cwc_`a'.ster"
    if _rc == 0 {
        scalar b_w = _b[cwc_inse]
        scalar b_b = _b[c_inse_prom_sede]
        quietly lincom cwc_inse - c_inse_prom_sede
        display "`a'  " %8.4f b_w "  " %8.4f b_b "  " %10.4f r(estimate) ///
                "  " %10.4f r(se) "  " %8.4f 2*(1-normal(abs(r(estimate)/r(se))))
    }
}


********************************************************************************
* [5] TABLA DEL OBJETIVO 4 CON LA ESTRUCTURA VIGENTE (ML1b a ML4b del 11)
********************************************************************************
display _newline "{hline 78}"
display "[5] OBJETIVO 4: ML1b-ML4b"
display "{hline 78}"

capture estimates clear
local c4 ""
foreach m in ML1b ML2b ML3b ML4b {
    capture estimates use "`m'.ster"
    if _rc == 0 {
        estimates store `m'
        local c4 "`c4' `m'"
    }
    else display as error "No se encontró `m'.ster"
}
local terr indice_vuln vuln_bar vuln_dev                           ///
           tasa_homicidios_bar tasa_homicidios_dev                 ///
           ln_coca_bar ln_coca_dev                                 ///
           ln_inversion_pc_bar ln_inversion_pc_dev
if "`c4'" != "" {
    esttab `c4' using "Tabla_Obj4_temporal_`hoy'.rtf",                       ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) noomitted nogaps compress   ///
        keep(punt_global:*) order(`terr' c_inse pct_planta rural)            ///
        coeflabels(`rot') mtitles("ML1b" "ML2b" "ML3b" "ML4b")               ///
        title("Bloque temporal con el entorno municipal rezagado (estructura aleatoria de cuatro componentes)") ///
        addnotes("ML2b descompone el índice en componente entre municipios y componente dentro del municipio; ML3b hace lo mismo con cada dimensión." ///
                 "Estructura aleatoria: municipio, municipio-año, sede y sede-año (apartado 3.6.1). REML sobre veinte imputaciones." ///
                 "Las condiciones municipales corresponden al año anterior al de la cohorte.")
    esttab `c4', b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) noomitted nogaps   ///
        keep(`terr') coeflabels(`rot') mtitles("ML1b" "ML2b" "ML3b" "ML4b") compress
}

* [5.1] Pendiente anual del componente dentro del municipio en ML4b (Tabla 30)
capture estimates use "ML4b.ster"
if _rc == 0 {
    display _newline "--- Pendiente anual del componente dentro del municipio (ML4b) ---"
    lincom vuln_dev
    foreach a in 2019 2020 2021 2022 2023 {
        display _newline "`a':"
        capture noisily lincom vuln_dev + `a'.year#c.vuln_dev
    }
}


********************************************************************************
* [6] EFECTOS DE SEDE CON LA ESTRUCTURA VIGENTE (M4r del 15)
********************************************************************************
* La versión 5 reestimaba M4 sobre la primera imputación con || mcpio_id: ||
* sede_id:, sin los componentes anuales. Aquí se leen los efectos predichos de
* M4r, que el 15 guardó con la estructura vigente; son los mismos que usa el
* 15c para las Figuras 6 y 7.
display _newline "{hline 78}"
display "[6] EFECTOS DE SEDE (M4r)"
display "{hline 78}"

capture confirm file "Efectos_sede_M4r_`f15'.dta"
if _rc != 0 {
    display as error "No se encontró Efectos_sede_M4r_`f15'.dta: se omite el bloque [6]."
}
else {
    use "Efectos_sede_M4r_`f15'.dta", clear
    summarize b_int b_pend se_int se_pend
    correlate b_int b_pend

    preserve
        sort b_int
        generate long rango = _n
        generate double lo = b_int - 1.96*se_int
        generate double hi = b_int + 1.96*se_int
        twoway (rarea lo hi rango, color(gs13))                              ///
               (line b_int rango, lcolor(black)),                            ///
            yline(0, lpattern(dash) lcolor(gs8)) legend(off)                 ///
            ytitle("Efecto aleatorio de la sede (puntos)")                   ///
            xtitle("Sedes ordenadas por su efecto estimado")                 ///
            xsize(5.9) ysize(4.1) name(g_caterpillar, replace)
        graph export "Fig_Obj3_efectos_sede_`hoy'.png", width(2000)
    restore

    twoway (scatter b_int b_pend, msymbol(oh) mcolor(gs6))                   ///
           (lfit b_int b_pend, lcolor(black)),                               ///
        legend(off) ytitle("Intercepto de la sede")                          ///
        xtitle("Pendiente socioeconómica de la sede")                        ///
        xlabel(-0.5(0.5)1, format(%3.1f)) ylabel(, format(%9.0f))          ///
        xsize(5.9) ysize(4.1) name(g_gradiente, replace)
    graph export "Fig_Obj3_gradiente_`hoy'.png", width(2000)
}


********************************************************************************
* [7] TABLA DE ROBUSTEZ CON LA ESTRUCTURA VIGENTE
********************************************************************************
* Cada prueba va junto a su modelo de referencia: R1b frente a ML1b, R3b
* frente a ML2b (regla de lectura del 18) y R5, R5b y R6 frente a ML3b
* (Tabla 21).
display _newline "{hline 78}"
display "[7] ROBUSTEZ"
display "{hline 78}"

capture estimates clear
local cr ""
local tr ""
foreach par in "ML1b ML1b" "R1b_indice_anual_`f18' R1b" "ML2b ML2b"          ///
               "R3b_parsimonioso_`f18' R3b" "ML3b ML3b" "R5_inv_fut_b R5"     ///
               "R5b_inv_fut_dep_b R5b" "R6_ing_trib_b R6" {
    local arch : word 1 of `par'
    local nom  : word 2 of `par'
    capture estimates use "`arch'.ster"
    if _rc == 0 {
        estimates store `nom'
        local cr "`cr' `nom'"
        local tr `"`tr' "`nom'""'
    }
    else display as error "No se encontró `arch'.ster"
}
local trob indice_vuln indice_vuln_anual vuln_bar vuln_dev             ///
           ln_inversion_pc_dev ln_inv_fut_pc_dev ln_inv_fut_pc_x_dev   ///
           ln_ing_trib_pc_dev tasa_homicidios_dev ln_coca_dev          ///
           c_inse pct_planta rural
if "`cr'" != "" {
    esttab `cr' using "Tabla_robustez_`hoy'.rtf",                            ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) noomitted nogaps compress   ///
        keep(`trob') order(`trob') coeflabels(`rot') mtitles(`tr')           ///
        stats(N, fmt(%9.0fc) labels("Estudiantes"))                          ///
        title("Pruebas de robustez con la estructura aleatoria de cuatro componentes") ///
        addnotes("R1b: índice con estandarización intra-anual, frente a ML1b. R3b: especificación parsimoniosa, frente a ML2b." ///
                 "R5 y R5b: inversión ejecutada del FUT, completa y depurada; R6: recaudo tributario propio; las tres frente a ML3b." ///
                 "R5, R5b y R6 tienen menos observaciones por los faltantes de cada serie fiscal.")
    esttab `cr', b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) noomitted nogaps   ///
        keep(`trob') order(`trob') coeflabels(`rot') mtitles(`tr') compress
    display "Control (nota al pie 5 y Tabla 21): R1b −0,737 (0,639); ML3b dentro 2,863 (1,617)."
}


********************************************************************************
* [8] CIERRE
********************************************************************************
set dp period
timer off 1
display _newline "{hline 78}"
display "SALIDAS DE ESTA CORRIDA (etiqueta `hoy')"
display "  Tabla_Obj2_ICC_`hoy'.csv, Fig_Obj2_particion_`hoy'.png, Fig_Obj2_evolucion_`hoy'.png"
display "  Tabla12_fusionada_`hoy'.rtf, Tabla42_completa_`hoy'.rtf"
display "  Tabla_Obj3_anual_<año>_`hoy'.rtf, Fig_Obj3_evolucion_coef_`hoy'.png"
display "  Tabla_Obj4_temporal_`hoy'.rtf, Tabla_robustez_`hoy'.rtf"
display "  Fig_Obj3_efectos_sede_`hoy'.png, Fig_Obj3_gradiente_`hoy'.png"
display "{hline 78}"
timer list 1
log close fase9
