********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 14C - INFLUENCIA DE POPAYÁN SOBRE LA DESCOMPOSICIÓN Y EL GRADIENTE
* ENTRADA  : Base_C2.dta   (la deja el bloque [0] de 12_composicional.do)
* SALIDA   : log_14c_popayan_20261014.log
*            C5_A0_permdev_full_*.ster, C5_A1_permdev_sinpop_*.ster,
*            C5_B1_inter_pop_*.ster,    C5_B2_inter_pop_rural_*.ster
* STATA    : 17
********************************************************************************
* POR QUÉ EXISTE ESTE SCRIPT
*
* El bloque [2] del script 14 mostró que excluir Popayán mueve dos coeficientes
* de forma material [log_14_sensibilidad_20261014.log, submuestras 1 y 4]:
*
*     c_inse            de 0,2797 (0,0276) a 0,2076 (0,0303)
*     c_inse_prom_sede  de 0,2717 (0,0977) a 0,1549 (0,1030), p de 0,005 a 0,133
*
* El segundo es el beta_b del modelo agrupado, es decir la columna (1) de la
* Tabla 11b. La conclusión de C2 NO descansa en esa columna sino en la (2),
* donde la media de sede se descompone en componente permanente (1,946) y
* componente de cohorte (0,010). Esa descomposición nunca se reestimó sin
* Popayán, de modo que hoy no se puede afirmar ni que aguante ni que no.
*
* Este script la reestima y, además, mide directamente si el gradiente de
* Popayán difiere del resto del departamento.
*
* EL CRITERIO ESTÁ FIJADO ANTES DE ESTA CORRIDA (registro de C5, 14 de octubre,
* 13:10). En síntesis, con referencia a 1,946 [1,460; 2,432] y 0,010:
*     (a) el permanente sigue significativo al 5 %
*     (b) su punto estimado es >= 1,460
*     (c) el contraste permanente = cohorte se sigue rechazando al 5 %
*     (d) el de cohorte sigue sin alcanzar el 5 %
*   (a)(b)(c)(d) -> SE MANTIENE
*   (a)(c)(d) sin (b) -> SE DEBILITA
*   (b) sin (a) -> NO CONCLUYENTE POR POTENCIA, no refutación
*   fallan (a) y (b), o falla (c) -> DEPENDE DE UN SOLO MUNICIPIO
*   falla (d) -> hallazgo nuevo, se reabre C2 por derecho propio
*
* POR QUÉ SE LEE Base_C2.dta Y NO SE RECONSTRUYEN LAS VARIABLES
* `inse_sede_perm` e `inse_sede_dev` las construye el bloque [0] del script 12
* con un promedio sobre SEDE-AÑOS, no sobre estudiantes, y un centrado sobre la
* media no ponderada de las sedes. Reconstruirlas aquí a mano arriesga una
* diferencia sutil que haría incomparable el resultado con la Tabla 11b. Se
* leen tal como quedaron.
*
* El centrado de `inse_sede_perm` se conserva sin recentrar al excluir Popayán:
* el propio script 12 advierte que esa elección sólo mueve el intercepto y
* ningún otro coeficiente depende de ella. Recentrar introduciría una
* diferencia respecto de la Tabla 11b sin ganar nada.
*
* POR QUÉ EL MODELO [A0] NO ES PRESCINDIBLE
* La Tabla 11b se estimó con VEINTE imputaciones y este script usa CINCO, por
* coherencia con el bloque [2] del script 14. Antes de comparar la submuestra
* con la cifra publicada hay que comprobar que cinco imputaciones reproducen
* esa cifra sobre la muestra completa. Si [A0] no reprodujera 1,946 y 0,010,
* cualquier diferencia de [A1] sería atribuible al número de imputaciones y no
* a Popayán, y el ejercicio no probaría nada.
*
* TIEMPOS ESTIMADOS (cálculo derivado)
*   El bloque [2] del script 14 hizo nueve modelos de este tipo en 5.005,26 s,
*   unos 556 s cada uno. Aquí son cuatro, uno de ellos sobre el 80 % de la
*   muestra.
*     [A0] 8-11 min   [A1] 7-10 min   [B1] 8-11 min   [B2] 8-12 min
*     Total con cargas: 35 a 50 min.
********************************************************************************

clear all
set more off
set varabbrev off
set seed 2026
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all

* `hoy` etiqueta las salidas. Si se reanuda el mismo día, añadir sufijo.
local hoy "20261014b"

capture confirm file "log_14c_popayan_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_14c_popayan_`hoy'.log."
    display as error "Cambiar el local hoy (anadir un sufijo) o renombrar el anterior."
    exit 602
}
log using "log_14c_popayan_`hoy'.log", text name(fase14c)

* ---------------------------------------------------------------------------
* INTERRUPTORES
* ---------------------------------------------------------------------------
local hacer_prep = 1    // [0] preparación y verificaciones   (2-4 min)
local hacer_A    = 1    // [A] descomposición de C2            (15-21 min)
local hacer_B    = 1    // [B] gradiente de Popayán            (16-23 min)

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino
global v_mun tasa_homicidios_bar tasa_homicidios_dev ln_coca_bar ///
             ln_coca_dev ln_inversion_pc_bar ln_inversion_pc_dev

* Estructura aleatoria de C1, idéntica a la del script 12 y a la del 14
global RE "|| mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:"

timer clear


********************************************************************************
* [0] PREPARACIÓN Y VERIFICACIONES
********************************************************************************

if `hacer_prep' == 1 {

    timer on 1
    display _newline "{hline 78}"
    display "[0] PREPARACION"
    display "{hline 78}"

    capture confirm file "Base_C2.dta"
    if _rc != 0 {
        display as error "No se encuentra Base_C2.dta."
        display as error "Correr el bloque [0] de 12_composicional.do."
        exit 601
    }

    use "Base_C2.dta", clear

    * --- [0.1] Que estén las variables de la descomposición ---
    confirm variable inse_sede_perm inse_sede_dev cwc_inse c_inse
    confirm variable c_inse_prom_sede inse_prom_sede sede_anio mcpio_id sede_id
    confirm variable cole_cod_mcpio_ubicacion
    * El cuerpo de un foreach NO puede ir en la misma línea que la llave de
    * apertura: Stata responde r(198), "code follows on the same line as open
    * brace". Así abortó la corrida de las 13:26.
    foreach v of global v_n1 {
        confirm variable `v'
    }
    foreach v of global v_n2 {
        confirm variable `v'
    }
    foreach v of global v_mun {
        confirm variable `v'
    }
    display "Todas las variables necesarias están presentes."

    display _newline "--- Estado del conjunto de imputación ---"
    mi describe

    * --- [0.2] Indicadora de Popayán ---
    * Verificada en el bloque [0] del script 14: 19001 reúne 13.962 estudiantes,
    * que es el municipio mayor del agrupado [log_08, bloque 1].
    capture drop popayan
    generate byte popayan = (cole_cod_mcpio_ubicacion == 19001)
    label variable popayan "Municipio de Popayán (1 = sí)"
    mi register regular popayan
    mi update

    quietly count if popayan == 1 & _mi_m == 0
    display _newline "Estudiantes en Popayán: " r(N) " (esperados: 13.962)"
    assert r(N) == 13962

    quietly count if popayan == 0 & _mi_m == 0
    display "Estudiantes fuera de Popayán: " r(N) " (esperados: 55.788)"
    assert r(N) == 55788

    * --- [0.3] Cuántas sedes aporta Popayán ---
    * Importa para leer el resultado: si Popayán concentra buena parte de las
    * sedes de nivel socioeconómico alto, excluirlo recorta el rango sobre el
    * que se identifica el componente permanente, y la pérdida de precisión
    * sería esperable antes que sorprendente.
    display _newline "--- Sedes y dispersión del componente permanente ---"
    preserve
        keep if _mi_m == 1
        egen byte _ts = tag(cole_cod_dane_sede)
        tabulate popayan if _ts == 1
        display _newline "Componente permanente, dentro y fuera de Popayán:"
        tabstat inse_sede_perm if _ts == 1, by(popayan) ///
            stat(n mean sd min max) format(%9.4f)
        display _newline "Desviación de cohorte:"
        tabstat inse_sede_dev, by(popayan) stat(n mean sd min max) format(%9.4f)
    restore

    save "C5_Base_Pop_`hoy'.dta", replace
    display _newline "Base guardada: C5_Base_Pop_`hoy'.dta"

    timer off 1
    display _newline "Tiempo del bloque [0]:"
    timer list 1
}


********************************************************************************
* [A] LA DESCOMPOSICIÓN DE C2, CON Y SIN POPAYÁN
********************************************************************************
* [A0] reproduce la Tabla 11b columna (2) con cinco imputaciones. Es el control
*      que vuelve interpretable a [A1].
* [A1] es el modelo que decide, sobre popayan == 0.

if `hacer_A' == 1 {

    timer on 2
    display _newline "{hline 78}"
    display "[A] COMPONENTE PERMANENTE FRENTE A DESVIACION DE COHORTE"
    display "{hline 78}"

    capture confirm file "C5_Base_Pop_`hoy'.dta"
    if _rc != 0 {
        display as error "No se encuentra C5_Base_Pop_`hoy'.dta. Correr el bloque [0]."
        exit 601
    }
    use "C5_Base_Pop_`hoy'.dta", clear

    * ----------------------------------------------------------------------
    * [A0] Muestra completa: control de reproducción
    * ----------------------------------------------------------------------
    display _newline "--- [A0] Muestra completa, cinco imputaciones ---"
    display "Debe reproducir la Tabla 11b columna (2):"
    display "   permanente 1,946 (0,248)   cohorte 0,010 (0,106)   betaw 0,279 (0,027)"
    display "Si no la reproduce, [A1] no es interpretable y hay que parar."

    mi estimate, imputations(1/5) dots post: mixed punt_global cwc_inse    ///
        inse_sede_perm inse_sede_dev $v_n1 $v_n2 indice_vuln ib2018.year   ///
        $RE , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_A0_permdev_full_`hoy'.ster", replace

    display _newline "Contraste permanente = desviación de cohorte:"
    test inse_sede_perm = inse_sede_dev
    lincom inse_sede_perm - inse_sede_dev
    display "   [referencia con 20 imputaciones: chi2(1) = 52,69; p < 0,0001]"

    display _newline "Desviación de cohorte frente al efecto dentro de la sede:"
    test inse_sede_dev = cwc_inse
    lincom inse_sede_dev - cwc_inse

    * ----------------------------------------------------------------------
    * [A1] Sin Popayán: el modelo que decide
    * ----------------------------------------------------------------------
    display _newline(2) "--- [A1] Sin Popayán ---"
    display "Esperadas 55.788 observaciones."

    mi estimate, imputations(1/5) dots post: mixed punt_global cwc_inse    ///
        inse_sede_perm inse_sede_dev $v_n1 $v_n2 indice_vuln ib2018.year   ///
        if popayan == 0 $RE , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_A1_permdev_sinpop_`hoy'.ster", replace

    display _newline "Contraste permanente = desviación de cohorte:"
    test inse_sede_perm = inse_sede_dev
    lincom inse_sede_perm - inse_sede_dev

    display _newline "Desviación de cohorte frente al efecto dentro de la sede:"
    test inse_sede_dev = cwc_inse
    lincom inse_sede_dev - cwc_inse

    * Efecto mínimo detectable del componente de cohorte sin Popayán, para
    * poder distinguir pérdida de potencia de refutación, como exige el
    * criterio. Mismo factor 2,802 que usaron C1 y C2.
    display _newline "--- EMD del componente de cohorte, sin Popayán ---"
    scalar se_dev = _se[inse_sede_dev]
    display "   E. E. del componente de cohorte : " %8.4f se_dev
    display "   EMD = 2,802 x E. E.             : " %8.4f 2.802*se_dev
    display "   [referencia con la muestra completa: EMD = 0,296]"

    display _newline "--- CRITERIO (fijado el 14 de octubre, 13:10) ---"
    display "  (a) permanente significativo al 5 %"
    display "  (b) permanente >= 1,460"
    display "  (c) contraste permanente = cohorte rechazado al 5 %"
    display "  (d) cohorte sin significancia al 5 %"
    display "  (a)(b)(c)(d)        -> SE MANTIENE"
    display "  (a)(c)(d) sin (b)   -> SE DEBILITA"
    display "  (b) sin (a)         -> NO CONCLUYENTE POR POTENCIA"
    display "  sin (a) ni (b), o sin (c) -> DEPENDE DE UN SOLO MUNICIPIO"
    display "  falla (d)           -> hallazgo nuevo, se reabre C2"

    timer off 2
    display _newline "Tiempo del bloque [A]:"
    timer list 2
}


********************************************************************************
* [B] ¿ES EL GRADIENTE DE POPAYÁN DISTINTO DEL RESTO?
********************************************************************************
* [B1] mide la diferencia directamente, en lugar de inferirla de la comparación
*      entre submuestras.
* [B2] pregunta si esa diferencia es de Popayán o simplemente de urbanidad. C6
*      estimó un gradiente de 0,373 en sedes urbanas y 0,015 en rurales, de modo
*      que la interacción con Popayán podría estar recogiendo eso.

if `hacer_B' == 1 {

    timer on 3
    display _newline "{hline 78}"
    display "[B] GRADIENTE DE POPAYAN FRENTE AL RESTO"
    display "{hline 78}"

    use "C5_Base_Pop_`hoy'.dta", clear

    * ----------------------------------------------------------------------
    * [B1] Interacción con Popayán sobre la especificación de ML3b
    * ----------------------------------------------------------------------
    display _newline "--- [B1] c_inse x Popayán ---"
    display "Hipótesis declarada: la interacción es POSITIVA."
    display "Si resulta significativa y NEGATIVA, revisar la construcción de"
    display "las variables antes de interpretar nada."

    mi estimate, imputations(1/5) dots post: mixed punt_global             ///
        c.c_inse##i.popayan $v_n1 $v_n2 $v_mun ib2018.year $RE , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_B1_inter_pop_`hoy'.ster", replace

    display _newline "Gradiente FUERA de Popayán:"
    lincom c_inse
    display "   [comparar con 0,2076 (0,0303) de la submuestra 4]"

    display _newline "Gradiente DENTRO de Popayán:"
    lincom c_inse + 1.popayan#c.c_inse

    display _newline "Diferencia (la interacción):"
    lincom 1.popayan#c.c_inse

    * ----------------------------------------------------------------------
    * [B2] ¿Popayán, o simplemente urbanidad?
    * ----------------------------------------------------------------------
    display _newline(2) "--- [B2] Añade c_inse x rural ---"
    display "Si la interacción con Popayán sobrevive, el efecto es de Popayán."
    display "Si desaparece, es urbanidad: conecta con el apartado 4.3.5."

    * `rural` ya viene dentro de $v_n2, de modo que la interacción se añade
    * con una sola almohadilla. Con `##` Stata la duplicaría y la omitiría por
    * colinealidad, que es lo que ensució la salida del bloque [1] del 14.
    mi estimate, imputations(1/5) dots post: mixed punt_global             ///
        c.c_inse##i.popayan c.c_inse#i.rural $v_n1 $v_n2 $v_mun            ///
        ib2018.year $RE , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_B2_inter_pop_rural_`hoy'.ster", replace

    display _newline "Interacción con Popayán, ya controlada la ruralidad:"
    lincom 1.popayan#c.c_inse

    display _newline "Interacción con ruralidad:"
    lincom 1.rural#c.c_inse
    display "   [C6 estimó, con centrado al clúster, -0,314 (0,052)]"

    display _newline "Gradiente en sede urbana fuera de Popayán:"
    lincom c_inse

    display _newline "Gradiente en sede rural fuera de Popayán:"
    lincom c_inse + 1.rural#c.c_inse

    display _newline "Gradiente en sede urbana de Popayán:"
    lincom c_inse + 1.popayan#c.c_inse

    display _newline "Contraste conjunto de las dos interacciones:"
    testparm 1.popayan#c.c_inse 1.rural#c.c_inse

    timer off 3
    display _newline "Tiempo del bloque [B]:"
    timer list 3
}


********************************************************************************
* CIERRE
********************************************************************************

display _newline "{hline 78}"
display "SCRIPT 14C TERMINADO."
display ""
display "Tiempos por bloque:"
timer list
display ""
display "NO reescribir el apartado 4.3.3 ni la Tabla 11b hasta aplicar el"
display "criterio fijado antes de esta corrida sobre el resultado de [A1]."
display "{hline 78}"

log close fase14c
