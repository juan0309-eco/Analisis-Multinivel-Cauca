********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 17 - DIAGNOSTICOS DE CIERRE DE C7
* ENTRADA  : N3_Municipios_PCA.dta, Base_Estimacion.dta,
*            C5_diag_ML3b_20261014.ster
* SALIDA   : log_17_diagnosticos_C7_<hoy>.log
* STATA    : 17
* FECHA    : 22 de octubre de 2026
********************************************************************************
* POR QUE UN SCRIPT NUEVO Y NO UN BLOQUE MAS EN EL 16
*
* El 16_territorial.do produjo log_16_territorial_20261019d.log, que es el log
* que el informe cita en 4.4.3, 4.5.1, 3.6.1 y el Anexo F.4. Anadirle bloques
* ahora romperia la correspondencia entre el script y el log citado. Los
* diagnosticos de cierre van aparte.
*
* QUE DEJA EN LOG
*
* [1] Las cifras de los 29 municipio-ano sin registro de homicidios que el
*     apartado 3.4.4 y el 5.4 citan. Hasta ahora eran un calculo hecho fuera
*     de Stata y el informe las menciona sin respaldo en log.
*
* [2] La identificacion de los ocho municipios de la cola inferior de la
*     Figura 8, que C5 asigno a C7 [anexo_registro_C5_1.md, apartado 5].
*
* NINGUNO DE LOS DOS BLOQUES ESTIMA NADA NUEVO. El [1] es descriptivo sobre el
* panel municipal y el [2] solo hace predict sobre un .ster ya guardado. No se
* promueve ningun resultado de aqui a hallazgo: el [1] documenta una limitacion
* de la fuente y el [2] abre una lectura para la discusion territorial.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ----------------------------------------------------------------------
* FECHA DE LAS SALIDAS. Cambiar en cada corrida nueva.
* ----------------------------------------------------------------------
local hoy "20261022"

* Interruptores por bloque.
local hacer_ceros = 1
local hacer_cola  = 1

* Guard: ningun log se sobrescribe nunca. Es la leccion del incidente del
* 13 de octubre, cuando un `log using ..., replace` destruyo la salida del
* bloque [7] del 10_blindaje.do.
capture log close _all
capture confirm file "log_17_diagnosticos_C7_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_17_diagnosticos_C7_`hoy'.log."
    display as error "Cambiar el local hoy antes de volver a correr."
    exit 602
}

log using "log_17_diagnosticos_C7_`hoy'.log", text name(fase17)

timer clear 1
timer on 1


********************************************************************************
* [1] LOS 29 MUNICIPIO-ANO SIN REGISTRO DE HOMICIDIOS
********************************************************************************
* El informe cita en 3.4.4 y en 5.4 cuatro cifras de este bloque: la tasa media
* de los municipios afectados en sus anos con registro (26,22), la del conjunto
* del departamento (49,03), la mediana de homicidios de los afectados (3) y el
* cambio en la desviacion estandar dentro del municipio al excluirlos (0,20 %,
* de 28,66 a 28,60). Este bloque las deja en log.

if `hacer_ceros' == 1 {

    display _newline(2) "{hline 78}"
    display "[1] MUNICIPIO-ANO SIN REGISTRO DE HOMICIDIOS"
    display "{hline 78}"

    use "N3_Municipios_PCA.dta", clear
    xtset cole_cod_mcpio_ubicacion year

    * --- [1.1] Cuantos son y donde estan ---
    display _newline "--- Recuento de registros en cero ---"
    quietly count if homicidios == 0
    display "  Municipio-ano con homicidios == 0: " r(N) " (esperados: 29)"
    quietly count
    display "  Total de municipio-ano:            " r(N) " (esperados: 252)"

    display _newline "--- Reparto por ano del dato ---"
    tabulate year_dato if homicidios == 0

    display _newline "--- Municipios distintos afectados ---"
    quietly levelsof cole_cod_mcpio_ubicacion if homicidios == 0, local(afect)
    display "  Municipios con al menos un ano sin registro: " wordcount("`afect'")
    display "  Codigos: `afect'"

    * --- [1.2] Perfil de los afectados frente al departamento ---
    * La pregunta es si los ceros caen en municipios violentos, donde serian
    * sospechosos, o en municipios de baja violencia, donde son verosimiles.
    generate byte _afectado = 0
    foreach m of local afect {
        quietly replace _afectado = 1 if cole_cod_mcpio_ubicacion == `m'
    }
    label define _afec 0 "Sin ceros" 1 "Con algun cero"
    label values _afectado _afec

    display _newline "--- Tasa y conteo en los anos CON registro, por grupo ---"
    tabstat tasa_homicidios homicidios if homicidios > 0, ///
        by(_afectado) stat(n mean p50 sd) format(%9.2f)

    display _newline "--- Cada municipio afectado, uno por linea ---"
    preserve
        keep if _afectado == 1
        bysort cole_cod_mcpio_ubicacion: egen byte _nceros = total(homicidios == 0)
        bysort cole_cod_mcpio_ubicacion: egen double _tasa_cd = ///
            mean(cond(homicidios > 0, tasa_homicidios, .))
        bysort cole_cod_mcpio_ubicacion: egen double _pob = mean(pob)
        bysort cole_cod_mcpio_ubicacion: keep if _n == 1
        gsort -_nceros
        list cole_cod_mcpio_ubicacion _nceros _pob _tasa_cd, ///
            clean noobs abbreviate(24)
    restore

    * --- [1.3] Lo que decide el asunto: cuanto mueven la variacion dentro ---
    * El coeficiente confirmatorio se identifica con la variacion de la tasa
    * dentro del municipio. Si excluir los ceros apenas la mueve, los ceros no
    * pueden estar fabricando el resultado nulo.
    display _newline "--- Variacion dentro del municipio, con y sin los ceros ---"
    quietly xtsum tasa_homicidios
    scalar sdw_con = r(sd_w)
    scalar sdt_con = r(sd)
    quietly xtsum tasa_homicidios if homicidios > 0
    scalar sdw_sin = r(sd_w)
    scalar sdt_sin = r(sd)

    display "  CON los ceros: DE dentro " %9.4f sdw_con ///
            "  DE total " %9.4f sdt_con ///
            "  razon " %6.3f sdw_con/sdt_con
    display "  SIN los ceros: DE dentro " %9.4f sdw_sin ///
            "  DE total " %9.4f sdt_sin ///
            "  razon " %6.3f sdw_sin/sdt_sin
    display "  Cambio en la DE dentro: " ///
        %6.2f 100*(sdw_sin - sdw_con)/sdw_con " %"

    display _newline "{hline 78}"
    display "LECTURA. Si el cambio en la DE dentro es de decimas de punto"
    display "porcentual, los 29 ceros no alteran la variacion que identifica"
    display "el coeficiente, y asi se declara en 3.4.4. No es una prueba de"
    display "hipotesis: es un diagnostico de la variable explicativa."
    display "{hline 78}"

    drop _afectado
}


********************************************************************************
* [2] LOS OCHO MUNICIPIOS DE LA COLA INFERIOR DE LA FIGURA 8
********************************************************************************
* C5 dejo esta identificacion asignada a C7. La Figura 8 es el grafico
* cuantil-cuantil de los efectos aleatorios de municipio de ML3b sobre la
* primera imputacion, y su cola inferior reune ocho municipios con efectos
* entre -27 y -14, separados del resto por un salto de unos cinco puntos.

if `hacer_cola' == 1 {

    display _newline(2) "{hline 78}"
    display "[2] COLA INFERIOR DE LA FIGURA 8"
    display "{hline 78}"

    capture confirm file "C5_diag_ML3b_20261014.ster"
    if _rc != 0 {
        display as error "No esta C5_diag_ML3b_20261014.ster."
        display as error "Es el modelo de la primera imputacion que produjo la"
        display as error "Figura 8 en el bloque [3.2] del script 14."
        exit 601
    }

    use "Base_Estimacion.dta", clear
    mi extract 1, clear

    capture drop mcpio_anio sede_anio
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)

    estimates use "C5_diag_ML3b_20261014.ster"
    estimates esample

    predict double re_*, reffects

    * VERIFICACION OBLIGATORIA DEL ORDEN.
    * Con la estructura cruzada de C1, predict devuelve un efecto por cada
    * ecuacion aleatoria y en el orden en que aparecen en el modelo. El
    * intercepto de municipio es el primero, pero hay que comprobarlo antes de
    * leer nada: es la misma precaucion que en C6 con b_pend y b_int.
    display _newline "--- Orden de los efectos predichos. COMPROBAR ---"
    describe re_*

    display _newline "--- El primero debe ser constante dentro del municipio ---"
    bysort cole_cod_mcpio_ubicacion: egen double _sd_re = sd(re_1)
    quietly count if _sd_re > 1e-8 & !missing(_sd_re)
    display "  Municipios con re_1 no constante: " r(N) " (debe ser 0)"
    assert r(N) == 0
    drop _sd_re

    preserve
        bysort cole_cod_mcpio_ubicacion: keep if _n == 1
        gsort re_1

        display _newline "--- Municipios por debajo de -13 ---"
        list cole_cod_mcpio_ubicacion re_1 indice_vuln if re_1 < -13, ///
            clean noobs abbreviate(24)
        quietly count if re_1 < -13
        display "  Son " r(N) " (C5 leyo ocho sobre el grafico)"

        display _newline "--- Los ocho mas bajos, coincidan o no con el umbral ---"
        list cole_cod_mcpio_ubicacion re_1 indice_vuln in 1/8, ///
            clean noobs abbreviate(24)

        display _newline "--- Los seis mas altos, para contraste ---"
        gsort -re_1
        list cole_cod_mcpio_ubicacion re_1 indice_vuln in 1/6, ///
            clean noobs abbreviate(24)

        * La pregunta sustantiva de C5: coinciden con los mas vulnerables?
        display _newline "--- Relacion con el indice de vulnerabilidad ---"
        quietly correlate re_1 indice_vuln
        display "  Correlacion efecto del municipio e indice: " %7.4f r(rho)
        quietly count
        display "  Municipios: " r(N) " (esperados: 42)"

        display _newline "--- Rango de los efectos ---"
        summarize re_1, detail
    restore

    display _newline "{hline 78}"
    display "LECTURA. Si los ocho coinciden con los mas vulnerables del indice,"
    display "hay algo sistematico en esos territorios que las tres dimensiones"
    display "no captan, y es material de 4.4.3 y 5.3. Si no coinciden, el"
    display "deficit de desempeno y la vulnerabilidad medida apuntan a sitios"
    display "distintos, que es un resultado mas fuerte todavia. En los dos"
    display "casos es DESCRIPTIVO: los efectos predichos estan encogidos hacia"
    display "la media y el grafico es indicativo, no un contraste."
    display "{hline 78}"
}


********************************************************************************
* [3] CIERRE
********************************************************************************

timer off 1
display _newline "--- Tiempo total ---"
timer list 1

display _newline "{hline 78}"
display "DIAGNOSTICOS DE CIERRE DE C7 COMPLETADOS."
display "El bloque [1] respalda las cifras que 3.4.4 y 5.4 ya citan."
display "El bloque [2] cierra el punto que C5 dejo asignado a C7."
display "{hline 78}"

log close fase17
