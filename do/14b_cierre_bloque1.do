********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 14B - CIERRE DEL BLOQUE [1] DE C5
* ENTRADA  : C5_Base_CC_20261013b.dta  (la deja el bloque [1] del script 14)
* SALIDA   : log_14b_cierre_20261013d.log, C5_CC_*_20261013d.ster
* STATA    : 17
********************************************************************************
* PARA QUÉ ES ESTE SCRIPT
*
* Cierra dos cabos sueltos del bloque [1], que ya corrió y cuyos resultados NO
* se tocan. No reestima ML3b ni las dos variantes sin controles: sólo los dos
* modelos que cambian.
*
* [A] ALINEAR EL TRATAMIENTO DE LAS COHORTES SIN DISPERSIÓN CALCULABLE
*     `15_gradiente_medicion.do`, bloque [0], no las excluye: les asigna cero y
*     las conserva.
*         replace sd_inse_sede = 0 if n_sa == 1 & _mi_m > 0
*     El bloque [1] del script 14 las dejó en faltante, de modo que los modelos
*     con controles corrieron sobre 58.940 observaciones y los modelos sin
*     controles sobre 58.948. La diferencia desplazó la interacción en 0,0009,
*     una centésima de su error estándar [log_14_sensibilidad_20261013b.log,
*     bloques 1.2 y 1.2b], así que no cambia ninguna conclusión; se elimina para
*     que la comparación con la Tabla 25b no tenga que declarar una salvedad.
*
*     IMPORTANTE: al asignar cero a esas filas, la media anual de la dispersión
*     cambia, de modo que `c_sd_inse` hay que CENTRARLO DE NUEVO. Reaprovechar
*     el centrado anterior sería un error silencioso.
*
* [B] EL CONTRASTE CONJUNTO QUE FALTABA EN [1.4]
*     El bloque [1.4] del script 14 guardó el modelo de cohortes de al menos
*     diez pero no corrió `testparm`, de modo que la quinta fila de la tabla de
*     comparación no tiene su valor p conjunto. Aquí se añade.
*
* LO QUE NO CAMBIA
* La regla de decisión de C5 ya se aplicó y su resultado no depende de esto:
* la interacción de casos completos resultó MENOR en valor absoluto que la
* imputada en las tres especificaciones, de modo que la hipótesis de atenuación
* no recibió respaldo (Regla 5) y la diferencia quedó por debajo de medio error
* estándar (Regla 6). Este script sólo afina la comparación que se reporta.
********************************************************************************

clear all
set more off
set varabbrev off
set seed 2026
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all

* `hoy` etiqueta las salidas de ESTA corrida. `fcc` apunta a la base de casos
* completos que dejó el bloque [1]; no se cambia.
local hoy "20261013d"
local fcc "20261013b"

capture confirm file "log_14b_cierre_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_14b_cierre_`hoy'.log."
    display as error "Cambiar el local hoy (anadir un sufijo) o renombrar el anterior."
    exit 602
}
log using "log_14b_cierre_`hoy'.log", text name(fase14b)

capture confirm file "C5_Base_CC_`fcc'.dta"
if _rc != 0 {
    display as error "No se encuentra C5_Base_CC_`fcc'.dta."
    display as error "Correr el bloque [1] del script 14 o ajustar el local fcc."
    exit 601
}

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

timer clear
timer on 1


********************************************************************************
* [A] REALINEACIÓN DE c_sd_inse
********************************************************************************

display _newline "{hline 78}"
display "[A] REALINEACION DE c_sd_inse CON EL CRITERIO DEL SCRIPT 15"
display "{hline 78}"

use "C5_Base_CC_`fcc'.dta", clear

* Punto de partida: lo que dejó el bloque [1].
display _newline "--- Antes de realinear ---"
quietly count if missing(_sd_inse)
display "Estudiantes sin dispersión calculable: " r(N)
tabstat c_sd_inse, stat(n mean sd min max) format(%9.4f)

* Cuántos estudiantes de la cohorte tienen índice observado. Es el análogo en
* casos completos del `n_sa` del script 15: allí el `sd()` falla cuando la
* cohorte tiene un solo estudiante, aquí cuando tiene un solo estudiante CON
* ÍNDICE OBSERVADO.
capture drop n_obs_inse
bysort cole_cod_dane_sede year: egen int n_obs_inse = ///
    total(!missing(estu_inse_individual))
label variable n_obs_inse "Estudiantes de la cohorte con INSE observado"

display _newline "--- Cohortes de sede según el número de índices observados ---"
preserve
    egen byte _t = tag(cole_cod_dane_sede year)
    keep if _t == 1
    tabulate n_obs_inse if n_obs_inse <= 3
    quietly count if n_obs_inse <= 1
    display "Sede-año con uno o ningún índice observado: " r(N) " de " _N
restore

* Criterio del script 15: dispersión cero, no faltante.
replace _sd_inse = 0 if missing(_sd_inse)

* RECENTRADO. La media anual cambia al incorporar esas filas con cero, de modo
* que el centrado anterior ya no corresponde.
capture drop c_sd_inse
bysort year: egen double _gsd = mean(_sd_inse)
generate double c_sd_inse = _sd_inse - _gsd
drop _gsd
label variable c_sd_inse "DE del INSE en la cohorte de sede, centrada (criterio 15)"

display _newline "--- Después de realinear ---"
quietly count if missing(c_sd_inse)
display "Faltantes de c_sd_inse: " r(N) " (debe ser 0)"
assert r(N) == 0
tabstat c_sd_inse, stat(n mean sd min max) format(%9.4f)

display _newline "--- Dispersión por año, criterio alineado ---"
tabstat _sd_inse, by(year) stat(n mean sd min max) format(%9.4f)
display "Comparar con el mismo cuadro del bloque [1]: las medias anuales se"
display "mueven en la cuarta cifra, porque entran trece filas con cero."


********************************************************************************
* [B] M5 CON CONTROLES, MUESTRA ALINEADA
********************************************************************************
* Reemplaza a CC_M5_ctrl del bloque [1.3]. Debe correr sobre 58.948
* observaciones, las mismas que CC_M5 del bloque [1.2].

display _newline "{hline 78}"
display "[B] CC_M5_ctrl ALINEADO: 58.948 observaciones esperadas"
display "{hline 78}"

mixed punt_global c.cwc_inse##c.pct_planta c.cwc_inse##c.indice_vuln ///
    c.cwc_inse##c.c_sd_inse c.cwc_inse##i.rural                      ///
    c_inse_prom_sede $v_n1 $v_n2 ib2018.year                         ///
    || mcpio_id: || mcpio_id: R.year                                 ///
    || sede_id: cwc_inse, covariance(unstructured)                   ///
    || sede_anio: , reml

display "Observaciones utilizadas: " e(N) "  (esperadas: 58.948)"
estimates save "C5_CC_M5_ctrl_alin_`hoy'.ster", replace

display _newline "Contraste conjunto de las dos interacciones declaradas:"
testparm c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln

display _newline "Referencias de comparación:"
display "  Bloque [1.3] sin alinear : 0,0313 (0,1131), conjunto p = 0,1578"
display "  Tabla 25b, cuarta fila   : 0,063 (0,101), p 0,537, conjunto 0,194"


********************************************************************************
* [C] M5 CON CONTROLES, COHORTES DE AL MENOS DIEZ, CON EL CONTRASTE CONJUNTO
********************************************************************************
* Reemplaza a CC_M5_ctrl10 del bloque [1.4] y añade el `testparm` que allí
* faltaba.

display _newline "{hline 78}"
display "[C] CC_M5_ctrl10 ALINEADO, CON CONTRASTE CONJUNTO"
display "{hline 78}"

mixed punt_global c.cwc_inse##c.pct_planta c.cwc_inse##c.indice_vuln ///
    c.cwc_inse##c.c_sd_inse c.cwc_inse##i.rural                      ///
    c_inse_prom_sede $v_n1 $v_n2 ib2018.year if coh10 == 1           ///
    || mcpio_id: || mcpio_id: R.year                                 ///
    || sede_id: cwc_inse, covariance(unstructured)                   ///
    || sede_anio: , reml

display "Observaciones utilizadas: " e(N)
estimates save "C5_CC_M5_ctrl10_alin_`hoy'.ster", replace

display _newline "Contraste conjunto de las dos interacciones declaradas:"
testparm c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln

display _newline "Referencias de comparación:"
display "  Bloque [1.4] sin alinear : -0,0094 (0,1188), sin contraste conjunto"
display "  Tabla 25b, quinta fila   : 0,040 (0,107), p 0,707, conjunto 0,386"


********************************************************************************
* CIERRE
********************************************************************************

save "C5_Base_CC_alin_`hoy'.dta", replace

timer off 1
display _newline "Tiempo total:"
timer list 1

display _newline "{hline 78}"
display "SCRIPT 14B TERMINADO."
display ""
display "La regla de decision de C5 ya se aplico sobre el bloque [1] y su"
display "resultado no depende de esta corrida. Si alguna de las dos"
display "interacciones de arriba resultara MAYOR en valor absoluto que su"
display "contraparte imputada, hay que volver a aplicar las reglas 5 y 6 antes"
display "de dar C5 por cerrada."
display "{hline 78}"

log close fase14b
