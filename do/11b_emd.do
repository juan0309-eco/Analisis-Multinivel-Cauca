********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 11B - EFECTO MINIMO DETECTABLE CON LA ESTRUCTURA NUEVA (C1)
* ENTRADA  : N3_Municipios_PCA.dta y los .ster de ML3 generados por el 08,
*            el 10 y el 11
* SALIDA   : log_11b_emd.log y EMD_C1.dta
* STATA    : 17
********************************************************************************
* POR QUE UN SCRIPT APARTE Y NO UNA EDICION DEL 10
* C1 pedia modificar el bloque [1] de 10_blindaje.do para que leyera ML3b.ster.
* Se hace aqui en vez de alli por tres razones:
*
*   1. Los otros bloques del 10 tardan horas y sus resultados ya existen en
*      log_10_blindaje.log. No hay por que repetirlos.
*   2. El bloque [6] del 10 carga M3_cwc.ster, que ningun script genera. Es el
*      hallazgo H1 y se resuelve en C2.
*   3. El bloque [7] del 10 termina en r(451) y ya quedo corregido aparte en
*      10b_planta_fe_v2.do.
*
* Asi 10_blindaje.do queda intacto como registro de lo que se corrio el 23 de
* agosto, y este script documenta el recalculo con su propio log.
*
* QUE HACE
* Reescala los coeficientes del entorno municipal a puntos de examen por
* desviacion estandar DENTRO del municipio y calcula el efecto minimo
* detectable con 80% de potencia al 5%: EMD = (1,96 + 0,84) por el error
* estandar. Es la misma convencion del bloque [1] del 10, de modo que las
* cifras son comparables con las de la Tabla 28.
*
* LO QUE ANADE RESPECTO DEL 10
* El 10 calculaba el EMD de una sola especificacion. Aqui se calculan cuatro,
* para separar de donde viene el cambio:
*
*   ML3          maxima verosimilitud, dos niveles  (la de la Tabla 28)
*   ML3_reml     REML, dos niveles                  (aisla el efecto de REML)
*   ML3_robust   MV con errores agrupados por mcpio (aisla el sandwich)
*   ML3b         REML, estructura nueva             (la que entra al documento)
*
* Si el EMD apenas se mueve entre ML3 y ML3_reml pero salta en ML3b, el cambio
* viene de la estructura aleatoria y no del metodo de estimacion. Eso es
* exactamente lo que hay que poder afirmar en el Anexo F.1.
*
* ADVERTENCIA DE LECTURA
* El p que se imprime usa la aproximacion normal sobre el cociente entre el
* coeficiente y su error. Los p oficiales de cada modelo son los de su propio
* log; aqui se muestran solo para orientar la lectura de la tabla.
*
* TIEMPO: minutos. No reestima nada, solo lee archivos .ster.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "11b_emd"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase11b)


********************************************************************************
* [1] DESVIACIONES ESTANDAR DENTRO DEL MUNICIPIO
********************************************************************************
* Se recalculan en vez de copiarse a mano, para que el numero del documento no
* se desactualice si cambia el panel municipal.

display _newline "{hline 78}"
display "[1] DESVIACIONES ESTANDAR DENTRO DEL MUNICIPIO"
display "{hline 78}"

use "N3_Municipios_PCA.dta", clear
xtset cole_cod_mcpio_ubicacion year

foreach v in tasa_homicidios ln_coca ln_inversion_pc {
    quietly xtsum `v'
    scalar sdw_`v' = r(sd_w)
    display "`v': " %10.4f sdw_`v'
}

display _newline "Comparar con el bloque [1] de log_10_blindaje.log:"
display "homicidios 28,6618   coca 0,8865   inversion 0,1632"


********************************************************************************
* [2] EMD DE CADA ESPECIFICACION
********************************************************************************

display _newline(2) "{hline 78}"
display "[2] EFECTO MINIMO DETECTABLE POR ESPECIFICACION"
display "{hline 78}"

tempname pe
postfile `pe' str12 modelo str20 variable ///
    double b se z p emd using "EMD_C1.dta", replace

foreach m in ML3 ML3_reml ML3_robust ML3b {

    capture confirm file "`m'.ster"
    if _rc != 0 {
        display as error _newline "`m'.ster no existe en el directorio; se omite."
        continue
    }

    capture noisily estimates use "`m'.ster"
    if _rc != 0 {
        display as error "No se pudo leer `m'.ster. Codigo: " _rc
        continue
    }

    display _newline "{hline 70}"
    display "--- `m' ---"
    display "{hline 70}"

    foreach v in tasa_homicidios ln_coca ln_inversion_pc {

        capture noisily lincom sdw_`v' * `v'_dev
        if _rc != 0 {
            display as error "  `v'_dev no esta en `m'. Se omite."
            continue
        }

        scalar b_v   = r(estimate)
        scalar se_v  = r(se)
        scalar z_v   = b_v / se_v
        scalar p_v   = 2*normal(-abs(z_v))
        scalar emd_v = 2.802 * se_v

        display "  `v': b = " %9.4f b_v "   EE = " %8.4f se_v ///
            "   EMD = " %8.4f emd_v

        post `pe' ("`m'") ("`v'") (b_v) (se_v) (z_v) (p_v) (emd_v)
    }
}

postclose `pe'


********************************************************************************
* [3] TABLA COMPARATIVA
********************************************************************************

display _newline(2) "{hline 78}"
display "[3] TABLA PARA EL ANEXO F.1"
display "{hline 78}"

use "EMD_C1.dta", clear
format b se z p emd %9.4f

display _newline "--- Todas las especificaciones ---"
list modelo variable b se p emd, clean noobs sepby(modelo)

display _newline "--- EMD por variable, una fila por especificacion ---"
preserve
    keep modelo variable emd
    quietly reshape wide emd, i(variable) j(modelo) string
    format emd* %9.4f
    list, clean noobs
restore

display _newline "--- Cuanto crece el EMD frente a la Tabla 28 (ML3) ---"
preserve
    keep modelo variable emd
    quietly reshape wide emd, i(variable) j(modelo) string
    capture confirm variable emdML3
    if _rc == 0 {
        foreach m in ML3_reml ML3_robust ML3b {
            capture confirm variable emd`m'
            if _rc == 0 {
                generate double razon_`m' = emd`m' / emdML3
            }
        }
        format razon_* %9.3f
        list variable razon_*, clean noobs
    }
    else {
        display as error "ML3.ster no estaba; no hay base de comparacion."
    }
restore

display _newline "{hline 78}"
display "COMO LEER ESTA TABLA"
display "{hline 78}"
display "Si el EMD apenas se mueve de ML3 a ML3_reml, el metodo de estimacion"
display "no es el responsable. Si ML3_robust y ML3b dan EMD parecidos, el"
display "modelo de la estructura nueva esta reproduciendo lo que el estimador"
display "sandwich ya indicaba, que es la mejor senal de que la estructura esta"
display "bien especificada."
display _newline "Desviacion estandar del puntaje global: 45,98 puntos."
display "Un EMD de un punto equivale a 0,022 desviaciones del puntaje."
display _newline "El EMD de este script sale de los errores estandar del MODELO."
display "El del bloque [4] del 11 sale del bootstrap salvaje y es mayor. Los"
display "dos van al Anexo F.1, cada uno declarando su origen."

log close fase11b
