********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 11A - ENSAYO DE ESTRUCTURA ALEATORIA (SUBMUESTRA 2018-2019) (C1)
* ENTRADA  : Base_Multinivel_PCA.dta
* SALIDA   : log_11a_ensayo.log y archivos .ster del ensayo
* STATA    : 17
********************************************************************************
* PARA QUE SIRVE
* Antes de lanzar el 11 completo hay que decidir cual es la especificacion
* principal. Este script compara, SOBRE LA MISMA SUBMUESTRA DE DOS ANOS, tres
* escrituras del mismo modelo de cuatro componentes aleatorios:
*
*   E1  || _all: R.mcpio_anio || mcpio_id: || sede_id: || sede_anio:
*       Sintaxis canonica de efectos cruzados. Es correcta, pero el nivel _all
*       convierte TODA la base en un solo conglomerado: un grupo de 69.750
*       observaciones con 252 efectos aleatorios. Es el cuello de botella.
*
*   E2  || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:
*       El choque municipio-ano entra DENTRO de la ecuacion del municipio. La
*       primera ecuacion aporta el intercepto permanente del municipio; la
*       segunda, los efectos de ano con varianza comun. El grupo mas grande
*       pasa a ser el municipio (maximo 13.962 observaciones), no la base.
*
*   E3  || mcpio_id: ibn.year, noconstant covariance(exchangeable) || ...
*       La misma descomposicion escrita como covarianza intercambiable:
*       var(municipio permanente) = la COVARIANZA entre anos
*       var(choque municipio-ano) = la VARIANZA menos la covarianza
*       Es el respaldo por si Stata rechaza repetir mcpio_id en E2.
*
* POR QUE R.year SOLO NO BASTA
* La notacion R. implica noconstant. Escribir unicamente
*     || mcpio_id: R.year || sede_id: || sede_anio:
* produce seis efectos INDEPENDIENTES por municipio, sin componente compartido
* entre ellos: el modelo afirmaria que un municipio no tiene nada permanente.
* Serian tres componentes (municipio-ano, sede, sede-ano), no cuatro.
*
* CRITERIO DE DECISION
* Si E2 (o en su defecto E3) reproduce las varianzas de E1 y tarda una fraccion
* del tiempo, esa escritura es la especificacion principal del script 11. Si
* ninguna converge en tiempo razonable, se va a la opcion 3: anidada
* municipio > municipio-ano > sede-ano como principal, mas un modelo de
* verificacion con sede persistente.
*
* ADVERTENCIA DE LECTURA
* Las cifras de este ensayo NO van al documento. Con dos anos, separar el
* componente permanente del municipio de su choque anual descansa en dos
* observaciones por municipio. El ensayo compara ESCRITURAS y TIEMPOS, no
* magnitudes interpretables.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "11a_ensayo"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase11a)

timer clear


********************************************************************************
* [0] SUBMUESTRA E IDENTIFICADORES
********************************************************************************

display _newline "{hline 78}"
display "[0] SUBMUESTRA 2018-2019"
display "{hline 78}"

use "Base_Multinivel_PCA.dta", clear
capture xtset, clear

keep if inlist(year, 2018, 2019)

* OJO: `drop` es todo o nada. Si una variable de la lista no existe, el
* comando falla entero y no borra NINGUNA, el `capture` lo oculta, y el `egen`
* siguiente muere con r(110) "already defined". Por eso va una por una.
foreach v in sede_id mcpio_id mcpio_anio sede_anio {
    capture drop `v'
}
egen long sede_id    = group(cole_cod_dane_sede)
egen long mcpio_id   = group(cole_cod_mcpio_ubicacion)
egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
egen long sede_anio  = group(cole_cod_dane_sede year)

quietly count
display _newline "Observaciones:        " r(N)

foreach v in mcpio_id mcpio_anio sede_id sede_anio {
    capture drop _tag
    egen byte _tag = tag(`v')
    quietly count if _tag == 1
    display "Niveles de `v': " r(N)
}
capture drop _tag

display _newline "La variable dependiente no tiene faltantes, asi que el ensayo"
display "no necesita imputacion. Es el mismo argumento del bloque [1] del 08."
quietly count if missing(punt_global)
display "Faltantes de punt_global: " r(N) " (debe ser 0)"


********************************************************************************
* [E1] SINTAXIS CANONICA DE EFECTOS CRUZADOS
********************************************************************************

display _newline(2) "{hline 78}"
display "[E1] || _all: R.mcpio_anio || mcpio_id: || sede_id: || sede_anio:"
display "{hline 78}"

scalar E1_mcpio = .
scalar E1_ma    = .
scalar E1_sede  = .
scalar E1_sa    = .
scalar E1_est   = .

timer on 1
capture noisily mixed punt_global ib2018.year ///
    || _all: R.mcpio_anio || mcpio_id: || sede_id: || sede_anio: , reml
timer off 1
scalar rc_E1 = _rc

if rc_E1 == 0 {
    estimates save "E1_ensayo_all.ster", replace

    display _newline "--- Nombres REALES de los parametros de varianza ---"
    display "Revisar este listado antes de creerle a cualquier _b[lns...]."
    matrix list e(b)

    capture noisily {
        scalar E1_ma    = exp(2*_b[lns1_1_1:_cons])   // _all: R.mcpio_anio
        scalar E1_mcpio = exp(2*_b[lns2_1_1:_cons])   // mcpio_id
        scalar E1_sede  = exp(2*_b[lns3_1_1:_cons])   // sede_id
        scalar E1_sa    = exp(2*_b[lns4_1_1:_cons])   // sede_anio
        scalar E1_est   = exp(2*_b[lnsig_e:_cons])
    }
    if _rc != 0 {
        display as error "No se pudieron extraer las varianzas de E1."
        display as error "Leerlas del listado de matrix list e(b) de arriba."
    }
}
else {
    display as error "E1 NO termino. Codigo de error: " rc_E1
    display as error "Si es r(3900)/memoria o nunca converge, el nivel _all es"
    display as error "inviable y la decision recae en E2 o E3."
}

display _newline "--- Tiempo de E1 ---"
timer list 1


********************************************************************************
* [E2] CHOQUE MUNICIPIO-ANO DENTRO DE LA ECUACION DEL MUNICIPIO
********************************************************************************

display _newline(2) "{hline 78}"
display "[E2] || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:"
display "{hline 78}"

scalar E2_mcpio = .
scalar E2_ma    = .
scalar E2_sede  = .
scalar E2_sa    = .
scalar E2_est   = .

timer on 2
capture noisily mixed punt_global ib2018.year ///
    || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio: , reml
timer off 2
scalar rc_E2 = _rc

if rc_E2 == 0 {
    estimates save "E2_ensayo_ryear.ster", replace

    display _newline "--- Nombres REALES de los parametros de varianza ---"
    display "OJO: las DOS ecuaciones del municipio comparten NIVEL, de modo que"
    display "son lns1_1_1 y lns1_2_1, y sede y sede-ano bajan a lns2 y lns3."
    display "No hay lns4. En E1 la numeracion es otra. Confundirlas cruza las"
    display "etiquetas de la Tabla 7b sin ningun mensaje de error."
    matrix list e(b)

    capture noisily {
        scalar E2_mcpio = exp(2*_b[lns1_1_1:_cons])   // mcpio_id intercepto
        scalar E2_ma    = exp(2*_b[lns1_2_1:_cons])   // mcpio_id: R.year
        scalar E2_sede  = exp(2*_b[lns2_1_1:_cons])   // sede_id
        scalar E2_sa    = exp(2*_b[lns3_1_1:_cons])   // sede_anio
        scalar E2_est   = exp(2*_b[lnsig_e:_cons])
    }
    if _rc != 0 {
        display as error "No se pudieron extraer las varianzas de E2."
        display as error "Leerlas del listado de matrix list e(b) de arriba."
    }
}
else {
    display as error "E2 NO termino. Codigo de error: " rc_E2
    display as error "Si el error es de anidamiento, Stata no acepta repetir"
    display as error "mcpio_id en dos ecuaciones y hay que usar E3."
}

display _newline "--- Tiempo de E2 ---"
timer list 2


********************************************************************************
* [E3] COVARIANZA INTERCAMBIABLE ENTRE LOS ANOS DEL MUNICIPIO
********************************************************************************
* var(municipio permanente) = covarianza entre dos anos del mismo municipio
* var(choque municipio-ano) = varianza menos esa covarianza
*
* Si la covarianza estimada sale NEGATIVA, la descomposicion no tiene lectura
* como suma de dos componentes y hay que declararlo: significa que los anos de
* un mismo municipio no comparten nada permanente una vez descontado el resto
* de la estructura.

display _newline(2) "{hline 78}"
display "[E3] || mcpio_id: ibn.year, noconstant covariance(exchangeable)"
display "{hline 78}"

scalar E3_mcpio = .
scalar E3_ma    = .
scalar E3_sede  = .
scalar E3_sa    = .
scalar E3_est   = .

timer on 3
capture noisily mixed punt_global ib2018.year ///
    || mcpio_id: ibn.year, noconstant covariance(exchangeable) ///
    || sede_id: || sede_anio: , reml
timer off 3
scalar rc_E3 = _rc

if rc_E3 == 0 {
    estimates save "E3_ensayo_exch.ster", replace

    display _newline "--- Matriz de covarianza de los efectos del municipio ---"
    display "La diagonal es la varianza de cada ano; el elemento fuera de la"
    display "diagonal es el componente permanente del municipio."
    capture noisily estat recovariance

    capture noisily {
        matrix G3 = r(Gmat1)
        scalar E3_mcpio = G3[1,2]
        scalar E3_ma    = G3[1,1] - G3[1,2]
        scalar E3_sede  = exp(2*_b[lns2_1_1:_cons])
        scalar E3_sa    = exp(2*_b[lns3_1_1:_cons])
        scalar E3_est   = exp(2*_b[lnsig_e:_cons])
    }
    if _rc != 0 {
        display as error "No se pudo extraer la descomposicion de E3."
        display as error "Tomar la diagonal y la covarianza de la matriz de"
        display as error "arriba y hacer la resta a mano."
    }
}
else {
    display as error "E3 NO termino. Codigo de error: " rc_E3
}

display _newline "--- Tiempo de E3 ---"
timer list 3


********************************************************************************
* [C] COMPARACION
********************************************************************************

display _newline(2) "{hline 78}"
display "COMPARACION DE LAS VARIANZAS (submuestra 2018-2019)"
display "{hline 78}"
display _newline ///
"Componente              E1 (_all)       E2 (R.year)     E3 (exchang.)"
display "{hline 70}"
display "Municipio         " %14.4f E1_mcpio %16.4f E2_mcpio %16.4f E3_mcpio
display "Municipio-ano     " %14.4f E1_ma    %16.4f E2_ma    %16.4f E3_ma
display "Sede              " %14.4f E1_sede  %16.4f E2_sede  %16.4f E3_sede
display "Sede-ano          " %14.4f E1_sa    %16.4f E2_sa    %16.4f E3_sa
display "Estudiante        " %14.4f E1_est   %16.4f E2_est   %16.4f E3_est

display _newline "--- Discrepancia relativa de E2 frente a E1 ---"
if rc_E1 == 0 & rc_E2 == 0 {
    scalar dmax = 0
    foreach c in mcpio ma sede sa est {
        scalar d_`c' = abs(E2_`c' - E1_`c') / E1_`c'
        display "`c': " %10.6f d_`c'
        if d_`c' > dmax  scalar dmax = d_`c'
    }
    display _newline "Discrepancia maxima: " %10.6f dmax
    if dmax < 0.01 {
        display "E1 y E2 estiman el MISMO modelo. La diferencia es numerica."
    }
    else {
        display as error "E1 y E2 NO coinciden. Antes de usar E2 hay que"
        display as error "entender por que: probablemente el orden de los"
        display as error "parametros no es el supuesto. Revisar matrix list."
    }
}
else {
    display "No se pueden comparar: alguno de los dos modelos no termino."
}

display _newline "--- Tiempos de los tres ensayos ---"
timer list

display _newline "{hline 78}"
display "COMO DECIDIR"
display "{hline 78}"
display "1. Si E2 coincide con E1 y es claramente mas rapido:"
display "   el script 11 corre con estructura = cruzada (E2)."
display "2. Si E2 falla por anidamiento pero E3 coincide con E1:"
display "   el script 11 corre con estructura = cruzada, cambiando la global"
display "   RE por la escritura de E3."
display "3. Si ninguna de las dos coincide o ninguna termina en tiempo util:"
display "   el script 11 corre con estructura = anidada (opcion 3)."
display _newline "Para extrapolar: el ensayo usa dos de los seis anos. El modelo"
display "completo tiene tres veces mas observaciones y mas niveles, de modo que"
display "el tiempo crece MAS que por tres. Y el bloque [2] del 11 repite cada"
display "modelo VEINTE veces, una por imputacion."

log close fase11a
