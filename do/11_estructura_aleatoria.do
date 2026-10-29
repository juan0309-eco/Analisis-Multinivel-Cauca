********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 11 - ESTRUCTURA ALEATORIA CON MUNICIPIO-ANO Y SEDE-ANO (C1)
* ENTRADA  : Base_Multinivel_PCA.dta, Base_Estimacion.dta, N3_Municipios_PCA.dta
* SALIDA   : log_11_estructura.log, archivos .ster,
*            Particion_7b.dta e Inferencia_C1.dta
* STATA    : 17
********************************************************************************
* QUE RESUELVE
* La estructura aleatoria actual (|| mcpio_id: || sede_id:) trata a cada
* municipio como una sola cosa constante durante seis anos. Pero las variables
* de Nivel 3 varian en 252 combinaciones municipio-ano, de modo que el choque
* comun a un municipio en un ano cae al residual individual y los 276,8
* estudiantes promedio de ese municipio-ano se cuentan como informacion
* independiente sobre una misma variable agregada (Moulton, 1990). Lo mismo
* ocurre con la sede, que aparece en promedio en 5,6 cohortes sin ningun
* componente propio de cohorte.
*
* ANTES DE CORRER ESTE SCRIPT
* Correr 11a_ensayo_estructura.do y fijar el local `estructura' de abajo con su
* resultado. El ensayo decide si la especificacion principal es la cruzada
* (municipio permanente + municipio-ano + sede + sede-ano) o la anidada.
*
* ADVERTENCIA DE TIEMPO
* El bloque [2] estima cuatro modelos principales y tres de robustez, cada uno
* sobre veinte imputaciones y 69.750 observaciones, con un nivel aleatorio mas
* que el script 08. La ejecucion completa se mide en horas. Cada modelo se
* guarda en su .ster apenas termina, de modo que una interrupcion no obliga a
* repetir lo ya estimado.
*
* QUE HAY QUE CAMBIAR EN OTROS SCRIPTS
* 10_blindaje.do, bloque [1]: `estimates use "ML3.ster"` pasa a ser
* `estimates use "ML3b.ster"`. Al reejecutarlo, dejar hacer_cotas = 1 y TODOS
* los demas interruptores en 0: el bloque [6] carga M3_cwc.ster, que ningun
* script genera (asunto de C2), y el bloque [7] termina en r(451), ya corregido
* aparte en 10b_planta_fe_v2.do.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "11_estructura"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase11)

timer clear
timer on 1


********************************************************************************
* [0] INTERRUPTORES Y DEFINICION DE LA ESTRUCTURA ALEATORIA
********************************************************************************

local hacer_nulo = 1    // [1] particion de la varianza: rapido, sin imputacion
local hacer_ml   = 1    // [2] LENTO: ML1b-ML4b y robustez, veinte imputaciones
local hacer_kr   = 1    // [3] LENTO: Kenward-Roger sobre m = 1
local hacer_fe   = 1    // [4] rapido: efectos fijos, bootstrap salvaje, 2 etapas

* ----------------------------------------------------------------------
* ESTRUCTURA PRINCIPAL. Fijar segun el resultado de 11a_ensayo_estructura.do
* ----------------------------------------------------------------------
*   "cruzada" : municipio permanente + municipio-ano + sede + sede-ano.
*               Es la estructura completa. El choque municipio-ano entra
*               dentro de la ecuacion del municipio para no convertir la base
*               en un unico conglomerado.
*               VERIFICADA en 11a_ensayo_estructura.do sobre 2018-2019: da las
*               mismas varianzas que la sintaxis canonica de efectos cruzados
*               (|| _all: R.mcpio_anio ...) hasta la quinta cifra, con la misma
*               log-verosimilitud restringida, en 9,34 s frente a 73,11 s.
*   "anidada" : municipio > municipio-ano > sede-ano (opcion 3). Corrige la
*               inferencia municipal pero PIERDE el efecto permanente de sede,
*               de modo que exige un modelo de verificacion aparte para las
*               variables permanentes de sede (rural, cole_femenino, tecnico),
*               cuya variacion dentro de la sede es nula o minima.
local estructura "cruzada"

if "`estructura'" == "cruzada" {
    global RE    "|| mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:"
    global REVER ""
    * Si el ensayo mostro que Stata rechaza repetir mcpio_id, sustituir por:
    * global RE "|| mcpio_id: ibn.year, noconstant covariance(exchangeable) || sede_id: || sede_anio:"
}
else {
    global RE    "|| mcpio_id: || mcpio_anio: || sede_anio:"
    global REVER "|| mcpio_id: || sede_id: || sede_anio:"
}

display _newline "{hline 78}"
display "ESTRUCTURA ALEATORIA PRINCIPAL: `estructura'"
display "$RE"
if "$REVER" != "" {
    display "ESTRUCTURA DE VERIFICACION (variables permanentes de sede):"
    display "$REVER"
}
display "{hline 78}"

* ----------------------------------------------------------------------
* BLOQUES DE VARIABLES. Identicos a los del 08_estimacion_v5.do, bloque [2.4]
* ----------------------------------------------------------------------
global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino


********************************************************************************
* [1] PARTICION DE LA VARIANZA CON MUNICIPIO-ANO Y SEDE-ANO
********************************************************************************
* Se estiman TRES modelos nulos porque ninguno por separado contesta todo:
*
*   (a) anidada    municipio > municipio-ano > sede-ano
*                  No tiene sede permanente.
*   (b) principal  la estructura completa definida arriba.
*                  Es la que alimenta la Tabla 7b.
*   (c) sede       municipio > sede > sede-ano
*                  No tiene municipio-ano. Es el puente directo con la Tabla 7
*                  publicada: anade un solo componente a lo ya conocido.
*
* Si (b) no converge, la Tabla 7b se arma con (a) y (c) y se declara en la nota
* de la tabla que el modelo de cuatro componentes simultaneos no fue estimable.
*
* NO HACE FALTA IMPUTAR: el modelo nulo solo involucra punt_global, que no
* tiene un solo faltante. Es el mismo argumento del bloque [1] del 08.
*
* estat icc NO esta disponible para efectos cruzados ni con la notacion R., de
* modo que la particion se calcula a mano.
*
* LOS NOMBRES DE LOS PARAMETROS DE VARIANZA SON UNA TRAMPA
* La convencion de Stata es lns{NIVEL}_{ECUACION}_{elemento}. En la estructura
* cruzada, las DOS ecuaciones del municipio cuelgan del MISMO nivel, de modo
* que se numeran como ecuacion 1 y ecuacion 2 del nivel 1, y todo lo que viene
* debajo se corre un piso:
*
*   municipio       lns1_1_1
*   municipio-ano   lns1_2_1     <- NO lns2_1_1
*   sede            lns2_1_1     <- NO lns3_1_1
*   sede-ano        lns3_1_1     <- NO lns4_1_1 (que no existe)
*
* En las estructuras anidadas (a) y (c), con una sola ecuacion por nivel, si
* corresponde lns1_1_1, lns2_1_1, lns3_1_1. Por eso cada modelo imprime
* matrix list e(b) ANTES de extraer nada: verificado en el ensayo 11a, donde
* este mismo mapeo mal puesto cruzo las etiquetas de sede y municipio-ano.

if `hacer_nulo' == 1 {

    display _newline(2) "{hline 78}"
    display "[1] PARTICION DE LA VARIANZA"
    display "{hline 78}"

    use "Base_Multinivel_PCA.dta", clear
    capture xtset, clear

    * OJO: `drop` es todo o nada. Si una variable de la lista no existe, el
    * comando falla entero y no borra NINGUNA, el `capture` lo oculta, y el
    * `egen` siguiente muere con r(110) "already defined". Por eso va una a una.
    foreach v in sede_id mcpio_id mcpio_anio sede_anio {
        capture drop `v'
    }
    egen long sede_id    = group(cole_cod_dane_sede)
    egen long mcpio_id   = group(cole_cod_mcpio_ubicacion)
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)

    tempname pp
    postfile `pp' str10 modelo str14 comp1 str14 comp2 str14 comp3 str14 comp4 ///
        double v1 v2 v3 v4 v_est using "Particion_7b.dta", replace

    * ------------------------------------------------------------------
    * (a) Anidada: municipio > municipio-ano > sede-ano
    * ------------------------------------------------------------------
    display _newline "--- (a) || mcpio_id: || mcpio_anio: || sede_anio: ---"
    capture noisily mixed punt_global ib2018.year ///
        || mcpio_id: || mcpio_anio: || sede_anio: , reml
    if _rc == 0 {
        estimates save "M0b_anidado_reml.ster", replace
        display _newline "--- Nombres REALES de los parametros de varianza ---"
        matrix list e(b)
        estat icc

        scalar v1 = .
        scalar v2 = .
        scalar v3 = .
        scalar v4 = .
        scalar ve = .
        capture noisily {
            scalar v1 = exp(2*_b[lns1_1_1:_cons])   // municipio
            scalar v2 = exp(2*_b[lns2_1_1:_cons])   // municipio-ano
            scalar v3 = exp(2*_b[lns3_1_1:_cons])   // sede-ano
            scalar ve = exp(2*_b[lnsig_e:_cons])
        }
        if _rc != 0 {
            display as error "(a): fallo la extraccion de varianzas. Leerlas"
            display as error "del listado de matrix list e(b) de arriba y"
            display as error "corregir los nombres en este bloque."
        }
        post `pp' ("anidada") ("municipio") ("municipio-ano") ("sede-ano") ("") ///
            (v1) (v2) (v3) (v4) (ve)
    }
    else {
        display as error "(a) no termino. Codigo: " _rc
    }

    * ------------------------------------------------------------------
    * (b) Estructura principal
    * ------------------------------------------------------------------
    display _newline "--- (b) estructura principal: $RE ---"
    capture noisily mixed punt_global ib2018.year $RE , reml
    if _rc == 0 {
        estimates save "M0b_principal_reml.ster", replace
        display _newline "--- Nombres REALES de los parametros de varianza ---"
        matrix list e(b)

        scalar v1 = .
        scalar v2 = .
        scalar v3 = .
        scalar v4 = .
        scalar ve = .

        if "`estructura'" == "cruzada" {
            * Las dos ecuaciones del municipio comparten NIVEL, de modo que
            * son lns1_1_1 y lns1_2_1, y sede y sede-ano bajan a lns2 y lns3.
            capture noisily {
                scalar v1 = exp(2*_b[lns1_1_1:_cons])   // municipio
                scalar v2 = exp(2*_b[lns1_2_1:_cons])   // municipio-ano
                scalar v3 = exp(2*_b[lns2_1_1:_cons])   // sede
                scalar v4 = exp(2*_b[lns3_1_1:_cons])   // sede-ano
                scalar ve = exp(2*_b[lnsig_e:_cons])
            }
            if _rc != 0 {
                display as error "(b): fallo la extraccion de varianzas."
                display as error "Leerlas del matrix list e(b) de arriba."
            }
            post `pp' ("principal") ("municipio") ("municipio-ano") ("sede")   ///
                ("sede-ano") (v1) (v2) (v3) (v4) (ve)
        }
        else {
            capture noisily {
                scalar v1 = exp(2*_b[lns1_1_1:_cons])   // municipio
                scalar v2 = exp(2*_b[lns2_1_1:_cons])   // municipio-ano
                scalar v3 = exp(2*_b[lns3_1_1:_cons])   // sede-ano
                scalar ve = exp(2*_b[lnsig_e:_cons])
            }
            if _rc != 0 {
                display as error "(b): fallo la extraccion de varianzas."
                display as error "Leerlas del matrix list e(b) de arriba."
            }
            post `pp' ("principal") ("municipio") ("municipio-ano") ("sede-ano") ///
                ("") (v1) (v2) (v3) (v4) (ve)
        }
    }
    else {
        display as error "(b) no termino. Codigo: " _rc
        display as error "La Tabla 7b tendra que armarse con (a) y (c), y la"
        display as error "nota de la tabla debe declararlo."
    }

    * ------------------------------------------------------------------
    * (c) Sede persistente y sede-ano, sin municipio-ano
    * ------------------------------------------------------------------
    display _newline "--- (c) || mcpio_id: || sede_id: || sede_anio: ---"
    capture noisily mixed punt_global ib2018.year ///
        || mcpio_id: || sede_id: || sede_anio: , reml
    if _rc == 0 {
        estimates save "M0b_sede_reml.ster", replace
        display _newline "--- Nombres REALES de los parametros de varianza ---"
        matrix list e(b)
        estat icc

        scalar v1 = .
        scalar v2 = .
        scalar v3 = .
        scalar v4 = .
        scalar ve = .
        capture noisily {
            scalar v1 = exp(2*_b[lns1_1_1:_cons])   // municipio
            scalar v2 = exp(2*_b[lns2_1_1:_cons])   // sede
            scalar v3 = exp(2*_b[lns3_1_1:_cons])   // sede-ano
            scalar ve = exp(2*_b[lnsig_e:_cons])
        }
        if _rc != 0 {
            display as error "(c): fallo la extraccion de varianzas. Leerlas"
            display as error "del listado de matrix list e(b) de arriba."
        }
        post `pp' ("sede") ("municipio") ("sede") ("sede-ano") ("")  ///
            (v1) (v2) (v3) (v4) (ve)
    }
    else {
        display as error "(c) no termino. Codigo: " _rc
    }

    postclose `pp'

    * ------------------------------------------------------------------
    * [1.0] Contraste: aporta el componente permanente de sede?
    * ------------------------------------------------------------------
    * (a) es (b) con la varianza de sede restringida a cero, de modo que los
    * dos modelos estan ANIDADOS y la razon de verosimilitudes es legitima.
    * Tienen ademas exactamente los mismos efectos fijos, que es la condicion
    * para comparar verosimilitudes REML.
    *
    * El contraste importa porque en (a) el componente municipio-ano se estima
    * en la frontera (practicamente cero) mientras que en (b) esta claramente
    * separado de cero: sin sede permanente, la persistencia de la sede se
    * reparte entre el municipio y el sede-ano y el municipio-ano se queda sin
    * nada que capturar. Es el argumento empirico para descartar la estructura
    * anidada, y va citado en 3.6.1.
    capture {
        estimates use "M0b_anidado_reml.ster"
        scalar ll_a = e(ll)
        estimates use "M0b_principal_reml.ster"
        scalar ll_b = e(ll)
    }
    if _rc == 0 & !missing(ll_a) & !missing(ll_b) {
        scalar lr_ab = 2*(ll_b - ll_a)
        display _newline "{hline 78}"
        display "[1.0] APORTA EL COMPONENTE PERMANENTE DE SEDE?"
        display "{hline 78}"
        display "Log-verosimilitud restringida, (a) sin sede:  " %14.2f ll_a
        display "Log-verosimilitud restringida, (b) con sede:  " %14.2f ll_b
        display "Razon de verosimilitudes, 1 gl:               " %14.2f lr_ab
        display "p, conservador por parametro en la frontera:  " %14.4f ///
            chi2tail(1, lr_ab)
    }
    else {
        display as error "No se pudo comparar (a) con (b): falta alguno de los"
        display as error "dos .ster. Calcularlo a mano con las log-verosimilitudes"
        display as error "que aparecen en los encabezados de los dos modelos."
    }

    * ------------------------------------------------------------------
    * [1.1] Cuotas de varianza, listas para la Tabla 7b
    * ------------------------------------------------------------------
    display _newline "{hline 78}"
    display "[1.1] CUOTAS DE VARIANZA POR MODELO"
    display "{hline 78}"

    preserve
        use "Particion_7b.dta", clear
        egen double v_tot = rowtotal(v1 v2 v3 v4 v_est)
        foreach j in 1 2 3 4 {
            generate double pct`j' = 100*v`j'/v_tot
        }
        generate double pct_est = 100*v_est/v_tot
        format v* pct* %9.2f
        list modelo comp1 pct1 comp2 pct2 comp3 pct3 comp4 pct4 pct_est, ///
            clean noobs
        save "Particion_7b.dta", replace
    restore

    display _newline "Nota de lectura: la particion publicada en la Tabla 7"
    display "(11,8 / 15,8 / 72,4) proviene de un modelo nulo de DOS componentes"
    display "estimado por maxima verosimilitud. Toda mencion de esas tres"
    display "cifras en el Resumen, 4.2, 5.1, 5.3 y la Tabla 16 debe"
    display "actualizarse o declararse como procedente de ese modelo."
}


********************************************************************************
* [2] ML1b-ML4b Y ROBUSTEZ CON LA NUEVA ESTRUCTURA (VEINTE IMPUTACIONES)
********************************************************************************
* Base_Estimacion.dta ya trae sede_id y mcpio_id creados y registrados como
* regulares por el bloque [2.3] del 08. Aqui solo se anaden mcpio_anio y
* sede_anio.
*
* Se estima por REML, no por maxima verosimilitud como el 08: con 42 municipios
* la ML ordinaria subestima el componente de varianza de Nivel 3. Dos
* consecuencias que hay que declarar en la nota de las Tablas 13 a 15:
*   - los coeficientes no son numericamente identicos a los del 08;
*   - bajo REML NO son validas las pruebas de razon de verosimilitud entre
*     modelos con efectos fijos distintos.

if `hacer_ml' == 1 {

    display _newline(2) "{hline 78}"
    display "[2] ML1b-ML4b CON LA NUEVA ESTRUCTURA"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    * Una a una, por la misma razon que en el bloque [1]: con datos mi hay
    * ademas que desregistrar antes de borrar.
    foreach v in mcpio_anio sede_anio {
        capture mi unregister `v'
        capture drop `v'
    }
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)
    mi register regular mcpio_anio sede_anio
    mi update

    display _newline "--- Verificacion de los identificadores nuevos ---"
    quietly count if missing(mcpio_anio) | missing(sede_anio)
    display "Filas sin identificador: " r(N) " (debe ser 0)"
    assert r(N) == 0

    timer clear 2
    timer on 2

    * --- ML1b: indice de vulnerabilidad ---
    display _newline "--- ML1b: indice de vulnerabilidad ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2      ///
        indice_vuln ib2018.year $RE , reml
    estimates save "ML1b.ster", replace

    timer off 2
    display _newline "--- Tiempo de ML1b (multiplicar por cuatro) ---"
    timer list 2

    * --- ML2b: descomposicion de Mundlak del indice ---
    display _newline "--- ML2b: descomposicion entre y dentro de municipio ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2      ///
        vuln_bar vuln_dev ib2018.year $RE , reml
    estimates save "ML2b.ster", replace
    display _newline "--- Contraste: componente entre frente a dentro ---"
    test vuln_bar = vuln_dev

    * --- ML3b: las tres dimensiones por separado (MODELO DE REFERENCIA) ---
    display _newline "--- ML3b: homicidios, coca e inversion por separado ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2      ///
        tasa_homicidios_bar tasa_homicidios_dev                       ///
        ln_coca_bar ln_coca_dev                                       ///
        ln_inversion_pc_bar ln_inversion_pc_dev ib2018.year $RE , reml
    estimates save "ML3b.ster", replace
    display _newline "--- Contrastes por dimension ---"
    test tasa_homicidios_bar = tasa_homicidios_dev
    test ln_coca_bar = ln_coca_dev
    test ln_inversion_pc_bar = ln_inversion_pc_dev
    test tasa_homicidios_dev ln_coca_dev ln_inversion_pc_dev

    * --- ML4b: interaccion entre vulnerabilidad y ano ---
    display _newline "--- ML4b: la asociacion cambia en el tiempo ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2      ///
        vuln_bar c.vuln_dev##ib2018.year $RE , reml
    estimates save "ML4b.ster", replace
    display _newline "--- Aporta la interaccion? ---"
    testparm c.vuln_dev#i.year

    * ------------------------------------------------------------------
    * [2.1] R5, R5b y R6 con la nueva estructura
    * ------------------------------------------------------------------
    * El sufijo _b marca la estructura nueva. No se usa el prefijo "R5b" solo,
    * porque en el 08 ese nombre ya designa la serie depurada del atipico del
    * FUT y la confusion seria permanente.
    display _newline(2) "{hline 78}"
    display "[2.1] MEDIDAS FISCALES ALTERNATIVAS CON LA NUEVA ESTRUCTURA"
    display "{hline 78}"

    local fiscales  "ln_inv_fut_pc ln_inv_fut_pc_x ln_ing_trib_pc"
    local etiquetas "R5_inv_fut_b R5b_inv_fut_dep_b R6_ing_trib_b"
    local k = 1
    foreach f of local fiscales {
        local nom : word `k' of `etiquetas'
        capture confirm variable `f'_dev
        if _rc == 0 {
            display _newline "--- `nom' ---"
            mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2  ///
                tasa_homicidios_bar tasa_homicidios_dev                   ///
                ln_coca_bar ln_coca_dev                                   ///
                `f'_bar `f'_dev ib2018.year $RE , reml
            estimates save "`nom'.ster", replace
            display "Observaciones utilizadas: " e(N)
            lincom `f'_dev
        }
        else {
            display as error "`f'_dev no esta en la base; se omite `nom'."
            display as error "Correr el 04 v4 y el 07c antes de esta prueba."
        }
        local ++k
    }

    * ------------------------------------------------------------------
    * [2.2] Verificacion para las variables permanentes de sede
    * ------------------------------------------------------------------
    * Solo bajo la estructura anidada. Esa estructura no tiene efecto
    * permanente de sede, y rural tiene variacion DENTRO de la sede igual a
    * cero: su error estandar quedaria calculado como si las 5,6 cohortes de
    * cada sede fueran observaciones independientes. Las Tablas 13 a 15 leen
    * las variables municipales del modelo principal y las permanentes de sede
    * de este.
    if "$REVER" != "" {
        display _newline(2) "{hline 78}"
        display "[2.2] VERIFICACION CON SEDE PERSISTENTE"
        display "{hline 78}"

        display _newline "--- ML1v: indice, con sede persistente ---"
        mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2  ///
            indice_vuln ib2018.year $REVER , reml
        estimates save "ML1v.ster", replace

        display _newline "--- ML3v: tres dimensiones, con sede persistente ---"
        mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2  ///
            tasa_homicidios_bar tasa_homicidios_dev                   ///
            ln_coca_bar ln_coca_dev                                   ///
            ln_inversion_pc_bar ln_inversion_pc_dev ib2018.year       ///
            $REVER , reml
        estimates save "ML3v.ster", replace

        display _newline "Comparar los errores estandar de rural,"
        display "cole_femenino, tecnico y pct_planta entre ML3b y ML3v."
    }
}


********************************************************************************
* [3] KENWARD-ROGER SOBRE LA PRIMERA IMPUTACION
********************************************************************************
* `mi estimate` combina con grados de libertad de muestra grande, que es
* justamente lo que no corresponde con 42 municipios. Kenward-Roger se calcula
* sobre m = 1 como verificacion y asi se declara.
*
* dfmethod(kroger) exige REML y calcula derivadas de la matriz de covarianza
* completa. Con 69.750 observaciones puede ser impracticable, de modo que
* primero se mide sobre un solo ano. Si un ano tarda mucho, los seis no tardan
* seis veces eso: tardan bastante mas.

if `hacer_kr' == 1 {

    display _newline(2) "{hline 78}"
    display "[3] KENWARD-ROGER"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear
    mi extract 1, clear

    foreach v in mcpio_anio sede_anio {
        capture drop `v'
    }
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)

    * --- Medicion previa sobre una sola cohorte ---
    display _newline "--- Ensayo de tiempo: cohorte 2018 ---"
    timer clear 3
    timer on 3
    capture noisily mixed punt_global c_inse $v_n1 $v_n2 if year == 2018 ///
        || mcpio_id: || sede_id: , reml dfmethod(kroger)
    timer off 3
    timer list 3
    display _newline "Si esto tardo mas de quince minutos, NO lanzar el modelo"
    display "completo: pasar a dfmethod(satterthwaite), y si tampoco, declarar"
    display "que la verificacion de pocos grupos descansa en el bootstrap"
    display "salvaje y en la regresion de dos etapas."

    * --- Modelo completo ---
    display _newline "--- ML3b con Kenward-Roger sobre m = 1 ---"
    timer clear 4
    timer on 4
    capture noisily mixed punt_global c_inse $v_n1 $v_n2              ///
        tasa_homicidios_bar tasa_homicidios_dev                       ///
        ln_coca_bar ln_coca_dev                                       ///
        ln_inversion_pc_bar ln_inversion_pc_dev ib2018.year           ///
        $RE , reml dfmethod(kroger)
    timer off 4
    scalar rc_kr = _rc
    timer list 4

    if rc_kr == 0 {
        estimates save "ML3b_kr_m1.ster", replace
    }
    else {
        display as error "Kenward-Roger no termino. Codigo: " rc_kr
        display as error "Intentando con Satterthwaite."
        capture noisily mixed punt_global c_inse $v_n1 $v_n2          ///
            tasa_homicidios_bar tasa_homicidios_dev                   ///
            ln_coca_bar ln_coca_dev                                   ///
            ln_inversion_pc_bar ln_inversion_pc_dev ib2018.year       ///
            $RE , reml dfmethod(satterthwaite)
        if _rc == 0 {
            estimates save "ML3b_satt_m1.ster", replace
            display as error "SE USO SATTERTHWAITE. Declararlo en 3.6.1."
        }
        else {
            display as error "Tampoco termino Satterthwaite. Declarar en 3.6.1"
            display as error "que la verificacion descansa en los otros dos"
            display as error "procedimientos."
        }
    }
}


********************************************************************************
* [4] EFECTOS FIJOS, BOOTSTRAP SALVAJE Y DOS ETAPAS (m = 1 a 5)
********************************************************************************
* Los dos procedimientos de este bloque no dependen de la estructura aleatoria:
* no modelan el agrupamiento, lo absorben. Por eso son la verificacion mas
* exigente de los canales territoriales.
*
* (a) Efectos fijos de municipio y de ano, errores agrupados por municipio y
*     bootstrap salvaje con pesos de Webb, que es el procedimiento indicado
*     con pocos conglomerados.
* (b) Regresion en dos etapas: cada municipio-ano aporta UNA observacion. Es
*     la traduccion literal de la objecion del profesor.
*
* Se repite en m = 1 a 5 para mostrar que el resultado no depende de una
* imputacion concreta. En el documento se reporta el RANGO.

if `hacer_fe' == 1 {

    display _newline(2) "{hline 78}"
    display "[4] EFECTOS FIJOS, BOOTSTRAP SALVAJE Y DOS ETAPAS"
    display "{hline 78}"

    capture which boottest
    if _rc != 0 {
        capture ssc install boottest, replace
        if _rc != 0 {
            display as error "No se pudo instalar boottest. Instalarlo a mano"
            display as error "y volver a correr este bloque."
            exit 601
        }
    }

    * ------------------------------------------------------------------
    * Desviaciones dentro del municipio, para expresar el EMD por DE
    * ------------------------------------------------------------------
    * Misma convencion del bloque [1] del 10_blindaje.do, para que los EMD
    * nuevos sean comparables con los de la Tabla 28.
    use "N3_Municipios_PCA.dta", clear
    xtset cole_cod_mcpio_ubicacion year
    foreach v in tasa_homicidios ln_coca ln_inversion_pc {
        quietly xtsum `v'
        scalar sdw_`v' = r(sd_w)
        display "DE dentro del municipio, `v': " %8.4f sdw_`v'
    }

    tempname pi
    postfile `pi' int m str20 variable str12 procedimiento ///
        double b p_cluster p_salvaje emd ///
        using "Inferencia_C1.dta", replace

    forvalues m = 1/5 {

        display _newline(2) "{hline 78}"
        display "IMPUTACION `m'"
        display "{hline 78}"

        * --------------------------------------------------------------
        * (a) Efectos fijos de municipio y ano, errores por municipio
        * --------------------------------------------------------------
        use "Base_Estimacion.dta", clear
        mi extract `m', clear

        display _newline "--- (a) Efectos fijos, m = `m' ---"
        areg punt_global c_inse $v_n1 $v_n2                           ///
            tasa_homicidios ln_coca ln_inversion_pc ib2018.year,      ///
            absorb(mcpio_id) vce(cluster mcpio_id)

        foreach v in tasa_homicidios ln_coca ln_inversion_pc {
            scalar b_v = _b[`v']
            quietly test `v'
            scalar p_cl = r(p)

            boottest `v', weighttype(webb) reps(9999) seed(2026) nograph
            scalar p_wb = r(p)

            scalar emd_v = .
            matrix CI = r(CI)
            if rowsof(CI) > 1 {
                display as error "`v' (m=`m'): intervalo disjunto en " ///
                    rowsof(CI) " tramos. EMD no calculado; revisar a mano."
            }
            else {
                * La semiamplitud del intervalo se traduce a error estandar
                * suponiendo simetria y normalidad. Es una APROXIMACION, y
                * justamente lo que el bootstrap salvaje no asume: declararlo
                * en la nota del Anexo F.1.
                scalar se_b  = (CI[1,2] - CI[1,1]) / (2*1.96)
                scalar emd_v = 2.802*se_b*sdw_`v'
            }

            display "`v' (m=`m'): b = " %9.5f b_v                     ///
                "   p cluster = " %6.4f p_cl                          ///
                "   p salvaje = " %6.4f p_wb                          ///
                "   EMD por DE dentro = " %8.4f emd_v

            post `pi' (`m') ("`v'") ("efectos fijos") (b_v) (p_cl) (p_wb) (emd_v)
        }

        * --------------------------------------------------------------
        * (b) Dos etapas: cada municipio-ano cuenta una vez
        * --------------------------------------------------------------
        * La variable dependiente de la segunda etapa es un efecto fijo
        * ESTIMADO, con error de muestreo mayor donde hay menos estudiantes.
        * Los pesos por numero de evaluados son una correccion aproximada de
        * eso, no exacta, y asi hay que declararlo en 4.5.
        display _newline "--- (b) Dos etapas, m = `m' ---"

        capture drop mcpio_anio
        egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)

        quietly areg punt_global c_inse $v_n1 $v_n2, absorb(mcpio_anio)
        predict double d_ma, d

        collapse (mean) d_ma tasa_homicidios ln_coca ln_inversion_pc  ///
            (count) n_est = punt_global, by(mcpio_id year)

        quietly count
        display "Observaciones de la segunda etapa: " r(N) " (esperadas: 252)"

        capture noisily regress d_ma tasa_homicidios ln_coca ln_inversion_pc ///
            i.year i.mcpio_id [aw = n_est], vce(cluster mcpio_id)
        if _rc != 0 {
            display as error "La segunda etapa fallo en m = `m'. Codigo: " _rc
            continue
        }

        foreach v in tasa_homicidios ln_coca ln_inversion_pc {
            scalar b_v = _b[`v']
            quietly test `v'
            scalar p_cl = r(p)

            scalar p_wb  = .
            scalar emd_v = .
            capture noisily boottest `v', weighttype(webb) reps(9999) ///
                seed(2026) nograph
            if _rc == 0 {
                scalar p_wb = r(p)
                matrix CI = r(CI)
                if rowsof(CI) == 1 {
                    scalar se_b  = (CI[1,2] - CI[1,1]) / (2*1.96)
                    scalar emd_v = 2.802*se_b*sdw_`v'
                }
            }
            else {
                display as error "boottest fallo en la segunda etapa; es"
                display as error "probable que no admita pesos analiticos."
                display as error "Repetir esta etapa sin [aw = n_est] y"
                display as error "reportar las dos versiones."
            }

            display "`v' (m=`m', dos etapas): b = " %9.5f b_v         ///
                "   p cluster = " %6.4f p_cl                          ///
                "   p salvaje = " %6.4f p_wb                          ///
                "   EMD = " %8.4f emd_v

            post `pi' (`m') ("`v'") ("dos etapas") (b_v) (p_cl) (p_wb) (emd_v)
        }
    }

    postclose `pi'

    * ------------------------------------------------------------------
    * [4.1] Resumen para la tabla de inferencia que sustituye a la Tabla 30
    * ------------------------------------------------------------------
    display _newline(2) "{hline 78}"
    display "[4.1] RANGO DE LOS RESULTADOS ENTRE IMPUTACIONES"
    display "{hline 78}"

    use "Inferencia_C1.dta", clear
    format b p_cluster p_salvaje emd %9.4f
    list, clean noobs sepby(procedimiento variable)

    display _newline "--- Rango por variable y procedimiento ---"
    tabstat b p_cluster p_salvaje emd, by(variable) ///
        stat(n min max) format(%9.4f)
}


********************************************************************************
* [5] CIERRE
********************************************************************************

timer off 1
display _newline "--- Tiempo total de ejecucion ---"
timer list 1

display _newline "{hline 78}"
display "ESTRUCTURA ALEATORIA COMPLETADA."
display "Siguiente: reejecutar 10_blindaje.do SOLO con hacer_cotas = 1,"
display "cambiando ML3.ster por ML3b.ster en el bloque [1], para recalcular"
display "el EMD de la Tabla 28 con los errores de la especificacion nueva."
display "{hline 78}"

log close fase11
