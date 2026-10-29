********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 18 - R1 Y R3 CON LA ESTRUCTURA ALEATORIA DE CUATRO COMPONENTES (P1)
* ENTRADA  : Base_Estimacion.dta (mi flong, M = 20), ML1b.ster, ML2b.ster
* SALIDA   : log_18_robustez_<hoy>.log
*            R1b_indice_anual_<hoy>.ster, R3b_parsimonioso_<hoy>.ster
* STATA    : 17
********************************************************************************
* QUE RESUELVE
* El bloque [6] del 08 estimo R1 (indice con estandarizacion intra-anual) y R3
* (especificacion parsimoniosa) con la estructura de dos componentes
* (|| mcpio_id: || sede_id:, mle). El 11 reestimo R5, R5b y R6 con la estructura
* de C1, pero no R1 ni R3, de modo que el segundo parrafo de 4.5 compara esas dos
* pruebas con ML1 y ML2 del 08 y no con la Tabla 13. Este script las reestima
* con la misma estructura, el mismo metodo (REML) y las mismas veinte
* imputaciones que ML1b-ML4b, y las compara con ML1b y ML2b.
*
* Las especificaciones de efectos fijos son LITERALMENTE las del bloque [6] del
* 08; solo cambia la parte aleatoria y el estimador.
*
* TIEMPO DE REFERENCIA
* ML1b, con la misma estructura y la misma muestra: 1.577,80 s
* (log_11_estructura.log, timer 2). Los dos modelos: unos 53 min como maximo.
*
* REGLA DE LECTURA, FIJADA ANTES DE CORRER
* R1 y R3 son pruebas de robustez, no resultados. Se considera que una prueba
* "no altera las conclusiones" si, para cada coeficiente comparado, (i) conserva
* el signo de ML1b (R1) o de ML2b (R3) y (ii) no cambia su clasificacion
* respecto del 5 % (significativo / no significativo). Cualquier cambio de
* clasificacion se reporta en 4.5 tal cual, sin redefinir la regla.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "18_robustez"
local hoy   "20261026"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase18)

* Los .ster nuevos llevan fecha y no se sobrescriben (README, regla 4)
foreach f in R1b_indice_anual R3b_parsimonioso {
    capture confirm file "`f'_`hoy'.ster"
    if _rc == 0 {
        display as error "Ya existe `f'_`hoy'.ster. Cambiar el local hoy."
        exit 602
    }
}

local hacer_r1 = 1
local hacer_r3 = 1

timer clear
timer on 1


********************************************************************************
* [0] ESTRUCTURA ALEATORIA Y BLOQUES DE VARIABLES
********************************************************************************
* Identicos a los de 11_estructura_aleatoria.do (estructura "cruzada").
global RE "|| mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:"

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

display _newline "{hline 78}"
display "ESTRUCTURA ALEATORIA: $RE , reml"
display "{hline 78}"


********************************************************************************
* [1] BASE E IDENTIFICADORES
********************************************************************************
use "Base_Estimacion.dta", clear

capture confirm variable indice_vuln_anual
if _rc != 0 {
    display as error "indice_vuln_anual no esta en Base_Estimacion.dta."
    display as error "Regenerar la base con 16a_rehacer_base.do."
    exit 111
}

foreach v in mcpio_anio sede_anio {
    capture mi unregister `v'
    capture drop `v'
}
egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
egen long sede_anio  = group(cole_cod_dane_sede year)
mi register regular mcpio_anio sede_anio
mi update

quietly count if missing(mcpio_anio) | missing(sede_anio)
display "Filas sin identificador: " r(N) " (debe ser 0)"
assert r(N) == 0


********************************************************************************
* [2] R1b: INDICE CON ESTANDARIZACION INTRA-ANUAL
********************************************************************************
* Misma especificacion de efectos fijos que R1 del 08; se compara con ML1b.
if `hacer_r1' == 1 {
    display _newline "{hline 78}"
    display "[2] R1b: indice alternativo, estructura de cuatro componentes"
    display "{hline 78}"

    timer on 2
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2      ///
        indice_vuln_anual ib2018.year $RE , reml
    estimates save "R1b_indice_anual_`hoy'.ster"
    timer off 2
    display "Observaciones utilizadas: " e(N)
    timer list 2
}


********************************************************************************
* [3] R3b: ESPECIFICACION PARSIMONIOSA
********************************************************************************
* Misma especificacion de efectos fijos que R3 del 08; se compara con ML2b,
* que es el modelo de la Tabla 13 con la misma descomposicion del indice.
if `hacer_r3' == 1 {
    display _newline "{hline 78}"
    display "[3] R3b: especificacion parsimoniosa, estructura de cuatro componentes"
    display "{hline 78}"

    timer on 3
    mi estimate, dots post: mixed punt_global c_inse mujer edad repitente ///
        ln_matricula pct_planta rural ju_unica vuln_bar vuln_dev ib2018.year ///
        $RE , reml
    estimates save "R3b_parsimonioso_`hoy'.ster"
    timer off 3
    display "Observaciones utilizadas: " e(N)
    test vuln_bar = vuln_dev
    timer list 3
}


********************************************************************************
* [4] COMPARACION CON ML1b Y ML2b
********************************************************************************
* Coeficientes comunes a las dos especificaciones de cada par. Para el indice,
* R1b se compara con indice_vuln de ML1b (variable distinta, mismo papel).

display _newline "{hline 78}"
display "[4] COMPARACION: coeficiente, error estandar y p"
display "{hline 78}"

capture program drop _fila
program define _fila
    args modelo archivo var
    capture estimates use "`archivo'"
    if _rc != 0 {
        display as error "  No se encontro `archivo'"
        exit
    }
    capture scalar _b0 = _b[`var']
    if _rc != 0 {
        display "  " %-10s "`modelo'" %-22s "`var'" "   (no esta en el modelo)"
        exit
    }
    scalar _s0 = _se[`var']
    scalar _p0 = 2*normal(-abs(_b0/_s0))
    display "  " %-10s "`modelo'" %-22s "`var'" %10.4f _b0 %10.4f _s0 %9.4f _p0
end

display _newline "  Modelo    Variable                    Coef.   Err.est.        p"

display _newline "--- Par R1b frente a ML1b ---"
foreach v in c_inse pct_planta rural ln_matricula ju_unica cole_femenino ///
             tecnico_academico {
    _fila "ML1b" "ML1b.ster" `v'
    _fila "R1b"  "R1b_indice_anual_`hoy'.ster" `v'
}
_fila "ML1b" "ML1b.ster" indice_vuln
_fila "R1b"  "R1b_indice_anual_`hoy'.ster" indice_vuln_anual

display _newline "--- Par R3b frente a ML2b ---"
foreach v in c_inse pct_planta rural ln_matricula ju_unica vuln_bar vuln_dev {
    _fila "ML2b" "ML2b.ster" `v'
    _fila "R3b"  "R3b_parsimonioso_`hoy'.ster" `v'
}

display _newline "--- Componentes de varianza (DE) ---"
foreach m in ML1b ML2b R1b_indice_anual_`hoy' R3b_parsimonioso_`hoy' {
    capture estimates use "`m'.ster"
    if _rc == 0 {
        display "  `m'"
        display "    municipio " %7.3f exp(_b[lns1_1_1:_cons])          ///
                "  mcpio-ano " %7.3f exp(_b[lns1_2_1:_cons])            ///
                "  sede "      %7.3f exp(_b[lns2_1_1:_cons])            ///
                "  sede-ano "  %7.3f exp(_b[lns3_1_1:_cons])            ///
                "  residual "  %7.3f exp(_b[lnsig_e:_cons])
    }
}

display _newline "Aplicar la regla de lectura del encabezado: signo y"
display "clasificacion al 5 % frente a ML1b (R1b) y ML2b (R3b)."


********************************************************************************
* [5] CIERRE
********************************************************************************
timer off 1
display _newline "--- Tiempos: 1 total, 2 R1b, 3 R3b ---"
timer list

display _newline "{hline 78}"
display "SCRIPT 18 TERMINADO. Subir el log al Project para corregir 4.5."
display "{hline 78}"

log close fase18
