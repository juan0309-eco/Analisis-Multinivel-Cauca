********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 99 - HUELLA DE LOS ARCHIVOS .ster
* ENTRADA  : todos los .ster de la carpeta de trabajo
* SALIDA   : huella_<etiqueta>.dta y huella_<etiqueta>.csv   (modo "tomar")
*            log_99_huella_<modo>_<hoy>.log
* STATA    : 17
* FECHA    : 23 de octubre de 2026
********************************************************************************
* PARA QUE SIRVE
* Demuestra que la reorganizacion de la carpeta no altero ningun resultado.
* NO ESTIMA NADA: solo hace `estimates use` sobre cada .ster y guarda lo que
* contiene.
*
* QUE GUARDA, POR CADA .ster
*   tipo "b"        cada elemento de e(b), con su nombre completo (ecuacion:var)
*   tipo "se"       la raiz de la diagonal de e(V)
*   tipo "varianza" exp(2*b) para los parametros lns* y lnsig_e, es decir las
*                   varianzas de los componentes aleatorios de `mixed`
*   tipo "escalar"  e(N), e(ll), e(M_mi), e(converged)
*   tipo "cmd"      e(cmd) y e(cmd_mi), como texto
*   tipo "error"    si el .ster no se pudo leer
*
* COMO SE USA
*   1. ANTES de tocar nada:   modo "tomar",    etiqueta "antes"
*   2. DESPUES de reorganizar: modo "tomar",    etiqueta "despues"
*   3. Comparacion:            modo "comparar", ref "antes", nueva "despues"
*
* LA COMPARACION ES EXACTA, NO A SEIS DECIMALES. Compara los valores double
* tal como estan guardados. El .csv se escribe con seis decimales solo para
* leerlo a ojo.
*
* LO QUE NO DEMUESTRA
* Solo cubre los .ster que estan en la carpeta. Los resultados que viven solo
* en un log (por ejemplo, un lincom) se verifican con las cifras de control de
* la seccion 4.2 del inventario.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ----------------------------------------------------------------------
* PARAMETROS DE ESTA CORRIDA. Solo se editan las lineas marcadas con <<<.
* ----------------------------------------------------------------------
local modo     "comparar"     // <<< "tomar" o "comparar"
local etiqueta "post_verif"      // <<< al tomar: "antes" o "despues"
local ref      "antes"        //     al comparar: huella de referencia
local nueva    "post_verif"      //     al comparar: huella nueva
local hoy      "20261024c"    // <<< etiqueta del log; anadir b, c... si se repite

* ----------------------------------------------------------------------
* LOG: primero se cierra cualquier log abierto, despues el guard.
* ----------------------------------------------------------------------
local tarea "99_huella_`modo'"

capture log close _all
capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(huella)
display "Tarea: `tarea'   " c(current_date) " " c(current_time)

timer clear
timer on 1


********************************************************************************
* [A] TOMAR LA HUELLA
********************************************************************************

if "`modo'" == "tomar" {

    display _newline "{hline 78}"
    display "[A] HUELLA DE LOS .ster, ETIQUETA: `etiqueta'"
    display "{hline 78}"

    capture confirm file "huella_`etiqueta'.dta"
    if _rc == 0 {
        display as error "Ya existe huella_`etiqueta'.dta. No se sobrescribe."
        display as error "Si hay que repetirla, usar otra etiqueta (antes_b...)."
        exit 602
    }

    local lista : dir . files "*.ster", respectcase
    local lista : list sort lista
    local nster : word count `lista'
    display "Archivos .ster en la carpeta: `nster'"

    tempname ph bb VV
    postfile `ph' str120 archivo str10 tipo str244 parametro double valor ///
        using "huella_`etiqueta'.dta"

    local nerr = 0
    foreach f of local lista {

        capture estimates use "`f'"
        if _rc != 0 {
            local cod = _rc
            post `ph' ("`f'") ("error") ("estimates use, codigo `cod'") (.)
            display as error "  No se pudo leer `f' (codigo `cod')."
            local ++nerr
            continue
        }

        * --- Comando que produjo el archivo ---
        post `ph' ("`f'") ("cmd") ("cmd: `e(cmd)'") (.)
        post `ph' ("`f'") ("cmd") ("cmd_mi: `e(cmd_mi)'") (.)

        * --- Escalares (quedan en faltante si el archivo no los tiene) ---
        foreach s in N ll M_mi converged {
            post `ph' ("`f'") ("escalar") ("`s'") (e(`s'))
        }

        * --- Coeficientes, errores estandar y varianzas ---
        matrix `bb' = e(b)
        capture matrix `VV' = e(V)
        local tieneV = (_rc == 0)

        local nombres : colfullnames `bb'
        local k = colsof(`bb')
        forvalues j = 1/`k' {
            local p : word `j' of `nombres'
            post `ph' ("`f'") ("b") ("`p'") (`bb'[1,`j'])
            if `tieneV' == 1 {
                post `ph' ("`f'") ("se") ("`p'") (sqrt(`VV'[`j',`j']))
            }
            * lns1_1_1, lns1_2_1, lns2_1_1, ... y lnsig_e empiezan por "lns"
            if substr("`p'", 1, 3) == "lns" {
                post `ph' ("`f'") ("varianza") ("`p'") (exp(2*`bb'[1,`j']))
            }
        }

        display "  `f': `k' parametros"
    }

    postclose `ph'

    * --- Resumen y copia legible ---
    use "huella_`etiqueta'.dta", clear

    display _newline "--- Filas por tipo ---"
    tabulate tipo

    display _newline "Archivos leidos: " `nster' - `nerr' " de `nster'"
    if `nerr' > 0 {
        display as error "Archivos que no se pudieron leer:"
        list archivo parametro if tipo == "error", clean noobs
    }

    format valor %15.6f
    export delimited using "huella_`etiqueta'.csv", datafmt replace

    display _newline "Guardado: huella_`etiqueta'.dta y huella_`etiqueta'.csv"
}


********************************************************************************
* [B] COMPARAR DOS HUELLAS
********************************************************************************

if "`modo'" == "comparar" {

    display _newline "{hline 78}"
    display "[B] COMPARACION: `ref' frente a `nueva'"
    display "{hline 78}"

    foreach h in `ref' `nueva' {
        capture confirm file "huella_`h'.dta"
        if _rc != 0 {
            display as error "No se encuentra huella_`h'.dta. Tomarla primero."
            log close huella
            exit 601
        }
    }

    * Un mismo nombre de parametro puede repetirse dentro de un .ster: Stata
    * nombra igual varios terminos omitidos. Le paso a punt_global:o.cwc_inse,
    * tres veces en b y en se, en C5_CC_M5_ctrl_20261013b, ctrl_alin_20261013d,
    * ctrl10_20261013b y ctrl10_alin_20261013d (log_99_huella_comparar_20261024,
    * r(459)). Cada repeticion se numera (rep) en el orden en que se guardo,
    * que es el orden de e(b), y la comparacion usa tambien ese numero.
    use "huella_`nueva'.dta", clear
    rename valor valor_nueva
    generate long fila = _n
    bysort archivo tipo parametro (fila): generate int rep = _n
    drop fila
    tempfile hn
    save `hn'

    use "huella_`ref'.dta", clear
    rename valor valor_ref
    generate long fila = _n
    bysort archivo tipo parametro (fila): generate int rep = _n
    drop fila

    quietly count if rep > 1
    display "Repeticiones de un mismo nombre dentro de un .ster (rep > 1): " r(N)

    capture isid archivo tipo parametro rep
    if _rc != 0 {
        display as error "Sigue habiendo filas repetidas en huella_`ref'.dta."
        log close huella
        exit 459
    }

    merge 1:1 archivo tipo parametro rep using `hn'

    * --- 1. Archivos o parametros que estan en una sola huella ---
    display _newline "--- Filas presentes en una sola huella ---"
    display "_merge = 1: estaban ANTES y ya no estan  <- NO deberia haber ninguna"
    display "_merge = 2: son NUEVOS (una corrida posterior); no es un fallo"
    tabulate _merge

    quietly count if _merge == 1
    local faltan = r(N)
    if `faltan' > 0 {
        display as error _newline "Archivos que desaparecieron o cambiaron de contenido:"
        preserve
            keep if _merge == 1
            contract archivo
            list archivo, clean noobs
        restore
    }

    * --- 2. Diferencias en los valores comunes ---
    generate double dif = abs(valor_nueva - valor_ref) if _merge == 3
    generate byte cambia = (_merge == 3) & ///
        ( (dif > 0 & !missing(dif)) | (missing(valor_ref) != missing(valor_nueva)) )

    quietly count if _merge == 3
    local comunes = r(N)
    quietly count if cambia == 1
    local ncambia = r(N)

    display _newline "Valores comunes comparados: `comunes'"
    display "Valores que cambiaron:      `ncambia'"

    if `ncambia' > 0 {
        display as error _newline "--- Valores distintos ---"
        format valor_ref valor_nueva dif %15.6f
        list archivo tipo parametro valor_ref valor_nueva dif if cambia == 1, ///
            clean noobs
    }

    * --- 3. Veredicto ---
    display _newline "{hline 78}"
    if `faltan' == 0 & `ncambia' == 0 {
        display "VEREDICTO: IDENTICAS. Ningun .ster existente cambio."
    }
    else {
        display as error "VEREDICTO: HAY DIFERENCIAS. Revisar las listas de arriba"
        display as error "antes de seguir con la reorganizacion."
    }
    display "{hline 78}"
}


********************************************************************************
* CIERRE
********************************************************************************

timer off 1
display _newline "--- Tiempo total ---"
timer list 1

log close huella
