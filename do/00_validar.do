********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 00 - VALIDADOR ESTATICO DE DO-FILES
* ENTRADA  : todos los .do de $RAIZ_DO, la carpeta Definitivo (sin subcarpetas)
* SALIDA   : validacion_<hoy>.dta, validacion_<hoy>.csv
*            log_00_validar_<hoy>.log
* STATA    : 17
* FECHA    : 23 de octubre de 2026
* REVISION : 29 de octubre de 2026 (C11): regla V8 (scripts de la cadena que
*            faltan en Definitivo, con el 18 y el 09 v6 en la lista) y fin
*            del estado Conocido del 09 v5, que pasa a archivo\
********************************************************************************
* QUE HACE
* Lee cada do-file como TEXTO y busca los defectos que ya costaron una
* corrida o una pieza de evidencia. No ejecuta ninguno de los scripts que
* revisa, no estima nada y tarda segundos.
*
* POR QUE LA LECTURA VA EN MATA
* Si el texto de un do-file se guarda en un local de Stata, cualquier
* `macro' que contenga se expande al usarlo, y unas comillas compuestas
* desbalanceadas rompen el script. Mata guarda el texto tal cual. Por la misma
* razon, dentro del bloque Mata la comilla invertida y el apostrofo se
* escriben como char(96) y char(39).
*
* REGLAS (inventario, seccion 3)
*   V1a Error  En un display, el texto "local" seguido de una macro: imprime
*              el VALOR en vez del nombre ("Cambiar el local 20261019...")
*   V1b Error  \" dentro de un display: r(198) en log_11_estructura.log
*   V1c Aviso  Macro dentro de un display que el archivo nunca define
*   V2a Error  log using con replace (incidente del 13 de octubre)
*   V2b Aviso  log using sin "capture confirm file" en las 15 lineas previas
*   V2c Aviso  "capture log close" DESPUES del guard (el log que quedo
*              abierto se traga el mensaje del guard y la corrida siguiente)
*   V3a Aviso  estimates save de un .ster sin fecha en el nombre
*   V3b Error  .ster sin fecha y con replace
*   V4  Aviso  Variable creada con egen/generate sobre una base mi, antes de
*              mi extract, que no se registra ni se borra despues
*   V5a Error  mixed con || mcpio_id: || mcpio_anio:  (anidada, descartada)
*   V5b Aviso  mixed con || mcpio_id: || sede_id: en un modelo que no es
*              por ano (sin "if year ==")
*   V6  Info   cd con ruta fija en lugar de cd "$RAIZ"
*   V7  Error  do o run de un archivo que no existe
*   V8  Error  script de la cadena (lista del 00_master) ausente en
*              Definitivo. No es una regla de texto: se comprueba en el
*              bloque [2.2], fuera de la autoprueba
*
* AUTOPRUEBA (bloque [2.0])
* Antes de revisar la carpeta, el validador se prueba a si mismo con un
* do-file de juguete que tiene un caso de cada regla y cuatro casos que no
* deben marcarse. Si una regla falla, se detiene y no reporta nada.
*
* ESTADOS (bloque [2.1])
* Cada hallazgo queda Abierto, Intencional o Conocido. La lista de excepciones
* esta en el bloque [2.1], con su motivo, y se identifica por archivo, regla y
* texto, no por numero de linea. Nada se descarta: todo va al .dta y al .csv.
*
* EXCEPCIONES EN EL PROPIO SCRIPT
* Una linea con el comentario
*     // VALIDADOR: intencional V5b
* deja fuera esa regla para esa orden (se pueden poner varias: V5b V3b).
* Sirve para los modelos que conservan la estructura antigua a proposito.
*
* LIMITES CONOCIDOS
* Es un validador de texto, no un interprete. V1c y V4 pueden dar falsos
* positivos; se leen como "revisar a mano", no como errores. Los comentarios
* de bloque (barra y asterisco) no se descartan.
********************************************************************************

version 17
clear all
set more off
set varabbrev off

* La configuracion es obligatoria: de ella sale RAIZ_DO, la carpeta de los
* do-files, que no es la carpeta de los datos.
local config "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
capture confirm file "`config'"
if _rc != 0 {
    display as error "No se encontro 00_config.do en la carpeta Definitivo."
    exit 601
}
do "`config'"
cd "$RAIZ"

* ----------------------------------------------------------------------
* PARAMETROS. Solo se edita la linea marcada con <<<.
* ----------------------------------------------------------------------
local hoy   "20261029b"        // <<< etiqueta de esta corrida
local tarea "00_validar"

capture log close _all
capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (anadir un sufijo b, c...)."
    exit 602
}
foreach ext in dta csv {
    capture confirm file "validacion_`hoy'.`ext'"
    if _rc == 0 {
        display as error "Ya existe validacion_`hoy'.`ext'. Cambiar el local hoy."
        exit 602
    }
}
log using "log_`tarea'_`hoy'.log", text name(validar)
display "Tarea: `tarea'   " c(current_date) " " c(current_time)
display "Carpeta: " c(pwd)

timer clear
timer on 1


********************************************************************************
* [1] FUNCIONES DEL VALIDADOR (Mata)
********************************************************************************

mata:
mata set matastrict off

void _agregar(string matrix R, string scalar f, real scalar l,
              string scalar regla, string scalar grav, string scalar txt)
{
    string scalar t
    t = ustrregexra(strtrim(txt), "\s+", " ")
    R = R \ (f, strofreal(l), regla, grav, usubstr(t, 1, 200))
}

real scalar _es_display(string scalar s)
{
    return(ustrregexm(s,
      "^\s*((noi|noisily|qui|quietly|cap|capture)\s+)*di(s(p(l(a(y)?)?)?)?)?(\s|\z)"))
}

// Macro anidada, como la de 14_sensibilidad_diagnosticos.do: nom seguido de
// la macro s forma nom1, nom2... El bucle de V1c resuelve primero la interior
// y deja "nom" suelto. Se acepta si el archivo define algun nombre que empieza
// por "nom" y el texto original lo escribe pegado a otra comilla invertida.
real scalar _anidada(string colvector defs, string scalar nm,
                     string scalar cmd)
{
    if (!strpos(cmd, char(96) + nm + char(96))) return(0)
    if (rows(defs) == 0) return(0)
    return(sum(substr(defs, 1, strlen(nm)) :== nm) > 0)
}

string matrix _sinfila(string matrix G, real scalar j)
{
    if (rows(G) == 1) return(J(0, 2, ""))
    if (j == 1)       return(G[|2, 1 \ rows(G), 2|])
    if (j == rows(G)) return(G[|1, 1 \ rows(G) - 1, 2|])
    return(G[|1, 1 \ j - 1, 2|] \ G[|j + 1, 1 \ rows(G), 2|])
}

void _cerrar_mi(string scalar f, string matrix R, string matrix G,
                real rowvector st)
{
    real scalar j
    if (st[4] == 1) {
        for (j = 1; j <= rows(G); j++) {
            _agregar(R, f, strtoreal(G[j, 2]), "V4", "Aviso",
                "creada sobre datos mi sin registrar ni borrar: " + G[j, 1])
        }
    }
    G = J(0, 2, "")
    st[4] = 0
    st[5] = 0
}

void _evaluar(string scalar f, string scalar cmd, real scalar ini,
              string scalar marcas, string matrix R, string colvector defs,
              string matrix G, real rowvector st)
{
    string scalar bt, ap, q, fn, base, rest, nm
    string rowvector toks
    real scalar j, k, esdisp, fechado, repl

    bt = char(96)
    ap = char(39)
    q  = char(34)
    esdisp = _es_display(cmd)

    // V6: cd con ruta fija
    if (ustrregexm(cmd, "^\s*cd\s+" + q + "?[A-Za-z]:")) {
        _agregar(R, f, ini, "V6", "Info", cmd)
    }

    // V7: do o run de un archivo inexistente
    if (!esdisp & ustrregexm(cmd,
        "^\s*((cap|capture|qui|quietly|noi|noisily)\s+)*(do|run)\s+" + q +
        "?([^" + q + ",]+\.do)")) {
        fn = ustrregexs(4)
        if (!fileexists(fn) & !strpos(marcas, "V7")) {
            _agregar(R, f, ini, "V7", "Error", "no existe " + fn + " | " + cmd)
        }
    }

    // V1: reglas sobre display
    if (esdisp) {
        if (ustrregexm(cmd, "local\s+" + bt + "[A-Za-z_][A-Za-z0-9_]*" + ap) &
            !strpos(marcas, "V1a")) {
            _agregar(R, f, ini, "V1a", "Error", cmd)
        }
        if (strpos(cmd, char(92) + q) & !strpos(marcas, "V1b")) {
            _agregar(R, f, ini, "V1b", "Error", cmd)
        }
        rest = cmd
        while (ustrregexm(rest, bt + "([A-Za-z_][A-Za-z0-9_]*)" + ap)) {
            nm = ustrregexs(1)
            if (!anyof(defs, nm) & !_anidada(defs, nm, cmd) &
                !strpos(marcas, "V1c")) {
                _agregar(R, f, ini, "V1c", "Aviso",
                    "macro no definida: " + nm + " | " + cmd)
            }
            rest = ustrregexrf(rest, bt + nm + ap, "")
        }
    }

    // V2: log using
    if (!esdisp & ustrregexm(cmd,
        "^\s*((cap|capture|qui|quietly)\s+)*log\s+using")) {
        if (ustrregexm(cmd, ",.*\breplace\b") & !strpos(marcas, "V2a")) {
            _agregar(R, f, ini, "V2a", "Error", cmd)
        }
        if ((st[1] == 0 | ini - st[1] > 15) & !strpos(marcas, "V2b")) {
            _agregar(R, f, ini, "V2b", "Aviso", cmd)
        }
    }
    if (ustrregexm(cmd, "confirm\s+file\s+" + q + "?log_")) {
        st[1] = ini
        if (st[2] == 0) st[2] = ini
    }
    if (ustrregexm(cmd, "^\s*(cap|capture)\s+log\s+close") & st[3] == 0) {
        st[3] = ini
    }

    // V3: estimates save
    if (!esdisp & ustrregexm(cmd,
        "estimates\s+save\s+" + q + "?([^" + q + ",]+\.ster)")) {
        fn = ustrregexs(1)
        fechado = ustrregexm(fn, bt + "(hoy|f|fin|fecha)" + ap) |
                  ustrregexm(fn, "[0-9]{8}")
        repl = ustrregexm(cmd, ",.*\breplace\b")
        if (!fechado & repl & !strpos(marcas, "V3b")) {
            _agregar(R, f, ini, "V3b", "Error", cmd)
        }
        else if (!fechado & !repl & !strpos(marcas, "V3a")) {
            _agregar(R, f, ini, "V3a", "Aviso", cmd)
        }
    }

    // V5: estructuras aleatorias
    if (!esdisp & strpos(cmd, "mixed")) {
        if (ustrregexm(cmd, "\|\|\s*mcpio_id:\s*\|\|\s*mcpio_anio:") &
            !strpos(marcas, "V5a")) {
            _agregar(R, f, ini, "V5a", "Error", cmd)
        }
        if (ustrregexm(cmd, "\|\|\s*mcpio_id:\s*\|\|\s*sede_id:") &
            !ustrregexm(cmd, "if\s+year\s*==") & !strpos(marcas, "V5b")) {
            _agregar(R, f, ini, "V5b", "Aviso", cmd)
        }
    }

    // V4: variables creadas sobre una base mi antes de mi extract
    if (!esdisp & ustrregexm(cmd,
        "^\s*((cap|capture|qui|quietly)\s+)*use\s+" + q + "?([^" + q + ",]+)")) {
        base = ustrregexs(3)
        _cerrar_mi(f, R, G, st)
        st[4] = ustrregexm(base,
            "^(Base_Estimacion|Base_Multinivel_MI|MI_Estudiantes|MI_Sedes|Base_C2|C3_Base_Trabajo|C5_Base_Trabajo|C5_Base_Pop)")
        return
    }
    if (ustrregexm(cmd, "\bmi\s+extract\b")) {
        _cerrar_mi(f, R, G, st)
        return
    }
    if (st[4] == 1 & !esdisp) {
        if (ustrregexm(cmd, "^\s*preserve\b")) st[5] = rows(G)
        if (ustrregexm(cmd, "^\s*restore\b")) {
            if (st[5] == 0)              G = J(0, 2, "")
            else if (st[5] < rows(G))    G = G[|1, 1 \ st[5], 2|]
        }
        if (ustrregexm(cmd,
            "^\s*((cap|capture|qui|quietly)\s+)*((bysort|by)[^:]*:\s*)?(egen|generate|gen)\s+((byte|int|long|float|double|str[0-9]+)\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=") &
            !strpos(marcas, "V4")) {
            G = G \ (ustrregexs(8), strofreal(ini))
        }
        if (ustrregexm(cmd,
            "^\s*((cap|capture|qui|quietly)\s+)*(mi\s+register|drop|rename)\s+(.*)")) {
            toks = tokens(ustrregexs(4))
            for (k = 1; k <= cols(toks); k++) {
                j = 1
                while (j <= rows(G)) {
                    if (G[j, 1] == toks[k]) G = _sinfila(G, j)
                    else j++
                }
            }
        }
    }
}

void validar_archivo(string scalar f, string matrix R)
{
    string colvector L, defs
    string matrix G
    string scalar s, t, cmd, piece, marcas
    real scalar n, i, ini, cont
    real rowvector st

    L = cat(f)
    n = rows(L)

    // Pase 1: macros que el archivo define
    defs = J(0, 1, "")
    for (i = 1; i <= n; i++) {
        s = subinstr(L[i], char(13), "")
        if (ustrregexm(s,
            "^\s*((cap|capture|qui|quietly)\s+)*local\s+(\+\+|--)?([A-Za-z_][A-Za-z0-9_]*)")) {
            defs = defs \ ustrregexs(4)
        }
        if (ustrregexm(s, "^\s*temp(name|file|var)\s+(.*)")) {
            defs = defs \ tokens(ustrregexs(2))'
        }
        if (ustrregexm(s, "^\s*(foreach|forvalues)\s+([A-Za-z_][A-Za-z0-9_]*)")) {
            defs = defs \ ustrregexs(2)
        }
        if (ustrregexm(s, "local\(([A-Za-z_][A-Za-z0-9_]*)\)")) {
            defs = defs \ ustrregexs(1)
        }
        if (ustrregexm(s, "^\s*args\s+(.*)")) {
            defs = defs \ tokens(ustrregexs(1))'
        }
    }

    // Pase 2: ordenes logicas (se unen las lineas que terminan en tres barras)
    G = J(0, 2, "")
    st = (0, 0, 0, 0, 0)
    cmd = ""
    marcas = ""
    ini = 0
    for (i = 1; i <= n; i++) {
        s = subinstr(L[i], char(13), "")
        t = strtrim(s)
        if (t == "") continue
        if (substr(t, 1, 1) == "*") continue
        if (ustrregexm(s, "VALIDADOR:\s*intencional\s+([A-Za-z0-9 ]+)")) {
            marcas = marcas + " " + ustrregexs(1)
        }
        cont  = ustrregexm(s, "\s/{3}")
        piece = ustrregexra(s, "\s/{3}.*", "")
        piece = ustrregexra(piece, "\s/{2}.*", "")
        if (cmd == "") ini = i
        cmd = cmd + " " + piece
        if (cont) continue
        _evaluar(f, cmd, ini, marcas, R, defs, G, st)
        cmd = ""
        marcas = ""
    }
    if (cmd != "") _evaluar(f, cmd, ini, marcas, R, defs, G, st)

    _cerrar_mi(f, R, G, st)

    if (st[2] > 0 & st[3] > st[2]) {
        _agregar(R, f, st[3], "V2c", "Aviso",
            "capture log close despues del guard de la linea " + strofreal(st[2]))
    }
}

void guardar_resultados(string matrix R)
{
    (void) st_addvar("str120", "archivo")
    (void) st_addvar("long",   "linea")
    (void) st_addvar("str6",   "regla")
    (void) st_addvar("str6",   "gravedad")
    (void) st_addvar("str244", "texto")
    if (rows(R) == 0) return
    st_addobs(rows(R))
    st_sstore(., "archivo",  R[., 1])
    st_store(.,  "linea",    strtoreal(R[., 2]))
    st_sstore(., "regla",    R[., 3])
    st_sstore(., "gravedad", R[., 4])
    st_sstore(., "texto",    R[., 5])
}

// AUTOPRUEBA. Escribe un do-file de juguete con un caso de cada regla y
// cuatro casos que NO deben marcarse, lo pasa por validar_archivo() y compara.
// Es el criterio de aceptacion del inventario (seccion 3.3) para las reglas
// que ya no tienen un caso real en la carpeta (V1b, V1c, V3a, V4).
real scalar autoprueba(string scalar ruta)
{
    real scalar fh, i, n, malos
    string scalar bt, ap, q, bs, cc
    string matrix R
    string colvector reglas

    bt = char(96)
    ap = char(39)
    q  = char(34)
    bs = char(92)
    cc = "/" + "/"

    if (fileexists(ruta)) unlink(ruta)
    fh = fopen(ruta, "w")
    fput(fh, "local hoy " + q + "x" + q)
    fput(fh, "local nom1 " + q + "a" + q)
    fput(fh, "cd " + q + "C:" + bs + "x" + q)                            // V6
    fput(fh, "do " + q + "no_existe_zzz.do" + q)                         // V7
    fput(fh, "display " + q + "Cambiar el local " + bt + "hoy" + ap + q) // V1a
    fput(fh, "display " + q + "a " + bs + q + " b" + q)                  // V1b
    fput(fh, "display " + q + bt + "nodef" + ap + q)                     // V1c
    fput(fh, "forvalues s = 1/1 {")
    fput(fh, "display " + q + bt + "nom" + bt + "s" + ap + ap + q)       // no
    fput(fh, "}")
    fput(fh, "log using " + q + "log_x.log" + q + ", replace text")     // V2a V2b
    fput(fh, "capture confirm file " + q + "log_y.log" + q)
    fput(fh, "capture log close _all")                                   // V2c
    fput(fh, "estimates save " + q + "A.ster" + q)                       // V3a
    fput(fh, "estimates save " + q + "B.ster" + q + ", replace")         // V3b
    fput(fh, "estimates save " + q + "C_" + bt + "hoy" + ap + ".ster" + q) // no
    fput(fh, "mixed y || mcpio_id: || mcpio_anio: || sede_anio:")       // V5a
    fput(fh, "mixed y || mcpio_id: || sede_id:")                         // V5b
    fput(fh, "mixed y if year == 2018 || mcpio_id: || sede_id:")         // no
    fput(fh, "mixed y || mcpio_id: || sede_id:   " + cc +
             " VALIDADOR: intencional V5b")                              // no
    fput(fh, "use " + q + "Base_Estimacion.dta" + q + ", clear")
    fput(fh, "generate double zz = 1")                                   // V4
    fput(fh, "mi extract 1, clear")
    fclose(fh)

    R = J(0, 5, "")
    validar_archivo(ruta, R)
    unlink(ruta)

    reglas = ("V1a", "V1b", "V1c", "V2a", "V2b", "V2c", "V3a", "V3b",
              "V4", "V5a", "V5b", "V6", "V7")'
    malos = 0
    printf("\nRegla   Esperado   Encontrado\n")
    for (i = 1; i <= rows(reglas); i++) {
        n = (rows(R) == 0 ? 0 : sum(R[., 3] :== reglas[i]))
        printf("%-6s %9.0f %12.0f   %s\n", reglas[i], 1, n,
               (n == 1 ? "ok" : "FALLA"))
        if (n != 1) malos++
    }
    printf("Total  %9.0f %12.0f   %s\n", rows(reglas), rows(R),
           (rows(R) == rows(reglas) ? "ok" : "FALLA"))
    if (rows(R) != rows(reglas)) malos++
    return(malos)
}

end


********************************************************************************
* [2] CORRIDA
********************************************************************************

display _newline "{hline 78}"
display "[2.0] AUTOPRUEBA DEL VALIDADOR"
display "{hline 78}"
display "Cada regla debe aparecer exactamente una vez, y el total debe ser 13:"
display "los cuatro casos de control (macro anidada, .ster fechado, modelo por"
display "ano y linea marcada como intencional) no deben marcarse."

tempfile prueba
mata: st_numscalar("fallos_prueba", autoprueba(st_local("prueba")))
if fallos_prueba > 0 {
    display as error _newline "La autoprueba fallo en " fallos_prueba " renglones."
    display as error "Las reglas marcadas FALLA estan mal escritas: no leer los"
    display as error "hallazgos de esta corrida. Subir este log."
    log close validar
    exit 9
}
display _newline "Autoprueba superada."

display _newline "{hline 78}"
display "[2] REVISION DE LOS DO-FILES"
display "{hline 78}"

* Los do-files viven en RAIZ_DO, no en la carpeta de los datos. Las dos
* corridas anteriores buscaron en Objetivo 2 y por eso dijeron "Do-files a
* revisar: 0". Se entra a RAIZ_DO solo para leer; el log ya esta abierto y los
* resultados se guardan al volver a RAIZ.
cd "$RAIZ_DO"
display "Carpeta de do-files: " c(pwd)
local lista : dir . files "*.do", respectcase
local lista : list sort lista
local excluir "00_validar.do"
local lista : list lista - excluir
local nfiles : word count `lista'

display "Configuracion: modo $MODO"
display "Do-files a revisar: `nfiles'"
if `nfiles' == 0 {
    display as error "No se encontro ningun do-file en " c(pwd) "."
    display as error "Contenido de la carpeta (para diagnostico):"
    dir
    cd "$RAIZ"
    log close validar
    exit 601
}

mata: R_VAL = J(0, 5, "")
foreach f of local lista {
    display "  revisando `f'"
    mata: validar_archivo("`f'", R_VAL)
}
cd "$RAIZ"
mata: guardar_resultados(R_VAL)

quietly count
local nhall = r(N)
display _newline "Hallazgos totales: `nhall'"

* ----------------------------------------------------------------------
* [2.1] CLASIFICACION DE LOS HALLAZGOS
* ----------------------------------------------------------------------
* Ningun hallazgo se borra: cada uno queda en una de tres categorias.
*   Abierto     : hay que corregirlo (pasos 3 y 4 del plan)
*   Intencional : decision documentada; no se corrige
*   Conocido    : defecto real que se resuelve en otro chat
* Se identifican por archivo, regla y un trozo del texto, nunca por el numero
* de linea, porque el paso 4 cambia las cabeceras y corre las lineas.
generate str12  estado = "Abierto"
generate str100 motivo = ""

capture program drop _clasif
program define _clasif
    args est regla arch frag mot
    tempvar sel
    quietly generate byte `sel' = estado == "Abierto" & regla == "`regla'" ///
        & archivo == "`arch'" & (`"`frag'"' == "" | strpos(texto, `"`frag'"') > 0)
    quietly replace estado = "`est'" if `sel'
    quietly replace motivo = `"`mot'"' if `sel'
    quietly count if `sel'
    display "  " %-12s "`est'" %-5s "`regla'" %-30s "`arch'" %4.0f r(N)
end

display _newline "--- Clasificacion (estado, regla, archivo, n) ---"

* .ster sin fecha con replace: otros scripts los leen por ese nombre
foreach a in 08_estimacion_v5.do 10_blindaje.do 11_estructura_aleatoria.do ///
             12_composicional.do {
    _clasif Intencional V3b "`a'" "" ///
        "otros scripts leen el .ster por este nombre; reejecutar solo en verificacion/"
}
_clasif Intencional V3b "11a_ensayo_estructura.do" "" ///
    "ensayo apagado en el master; sus cifras no van al informe"

* Estructuras antiguas que se conservan a proposito (inventario, seccion 1.6)
_clasif Intencional V5a "11_estructura_aleatoria.do" "" ///
    "modelo (a) de referencia del bloque [1], descartado en C1"
_clasif Intencional V5b "11_estructura_aleatoria.do" "|| sede_id: || sede_anio:" ///
    "modelo (c) del bloque [1], puente con la Tabla 7"
_clasif Intencional V5b "10_blindaje.do" "" ///
    "bloques [2] y [3]: estructura antigua a proposito (encabezado del 10)"
_clasif Intencional V5b "15_gradiente_medicion.do" "" ///
    "bloque [A], M4b y M5b: aisla el efecto del ano fijo"
_clasif Intencional V5b "11a_ensayo_estructura.do" "" ///
    "ensayo de sintaxis de efectos cruzados"
_clasif Intencional V5b "05_ensamblaje_v2.do" "" ///
    "nulo de verificacion; el propio 05 dice que no es la estimacion formal"

* Logs con fecha y hora y sin replace: si el archivo existe, Stata aborta
* solo con r(602) y no borra nada. Un guard solo cambiaria el mensaje.
foreach a in 15_gradiente_medicion.do 15a_ensayo_gradiente.do ///
             15b_lecturas.do 15c_figuras.do {
    _clasif Intencional V2b "`a'" "" ///
        "log con fecha y hora y sin replace: Stata aborta si ya existe"
}

* Falso positivo de V4: es la reconstruccion de la variable de sistema
_clasif Intencional V4 "07b_reparar_y_unir_v2.do" "_mi_miss" ///
    "reconstruye la variable de sistema; la sigue mi update"

* Defectos reales que se resuelven en otro chat
_clasif Conocido V5b "08_estimacion_v5.do" "" ///
    "M0_pool y bloques [4] a [6], superados por el 11; confirmar uso en el informe"
* C11: el 09 v5 (figura con la estructura antigua) pasa a archivo\. El 09 v6
* ya no estima modelos agrupados con la estructura de dos componentes: si
* aparece un V5b en el 09 v6, es un hallazgo Abierto.

* ----------------------------------------------------------------------
* [2.2] V8: SCRIPTS DE LA CADENA QUE FALTAN EN DEFINITIVO (C11)
* ----------------------------------------------------------------------
* La lista es la del 00_master.do, con el 18 y el 09 v6. Un script ausente
* deja al master detenido con r(601); aqui se ve antes de correrlo.
local cadena 01_depuracion_N1_ICFES_v2.do 02_panel_sedes_N2_v2.do          ///
    03_panel_tic_N2_v2.do 04_panel_municipal_N3_v5.do 05_ensamblaje_v2.do  ///
    06_pca_vulnerabilidad_v3.do 07_imputacion_v3.do                        ///
    07b_reparar_y_unir_v2.do 07c_actualizar_nivel3.do 08_estimacion_v5.do  ///
    09_tablas_graficos_v6.do 10_blindaje.do 10b_planta_fe_v2.do            ///
    11a_ensayo_estructura.do 11_estructura_aleatoria.do 11b_emd.do         ///
    11c_tabla14.do 12_composicional.do 13_cohortes_oaxaca.do               ///
    14_sensibilidad_diagnosticos.do 14b_cierre_bloque1.do 14c_popayan.do   ///
    15a_ensayo_gradiente.do 15_gradiente_medicion.do 15b_lecturas.do       ///
    15c_figuras.do 16a_rehacer_base.do 16_territorial.do                   ///
    17_diagnosticos_C7_v2.do 18_robustez_R1R3.do                              ///
    00_config.do 00_master.do 99_huella.do
local ncadena : word count `cadena'
local nfalta = 0
foreach f of local cadena {
    capture confirm file "$RAIZ_DO/`f'"
    if _rc != 0 {
        local ++nfalta
        quietly set obs `=_N + 1'
        quietly replace archivo  = "`f'" in l
        quietly replace linea    = 0 in l
        quietly replace regla    = "V8" in l
        quietly replace gravedad = "Error" in l
        quietly replace texto    = "script de la cadena ausente en Definitivo" in l
        quietly replace estado   = "Abierto" in l
        display as error "  V8: falta `f'"
    }
}
display _newline "V8: scripts de la cadena ausentes: `nfalta' de `ncadena'"
quietly count
local nhall = r(N)

quietly count if estado == "Abierto" & regla != "V6"
local nabiertos = r(N)
display _newline "Abiertos sin contar V6: `nabiertos'"

* tabulate se detiene con r(2000) si no hay observaciones: por eso los if.
if `nhall' > 0 {
    sort archivo linea regla

    display _newline "--- Hallazgos por regla y estado ---"
    tabulate regla estado

    if `nabiertos' > 0 {
        display _newline "--- Abiertos por archivo (sin contar V6) ---"
        tabulate archivo if estado == "Abierto" & regla != "V6"
    }

    display _newline "{hline 78}"
    display "ERRORES ABIERTOS"
    display "{hline 78}"
    list archivo linea regla texto if gravedad == "Error" & estado == "Abierto", ///
        clean noobs abbreviate(12) string(90)

    display _newline "{hline 78}"
    display "AVISOS ABIERTOS"
    display "{hline 78}"
    list archivo linea regla texto if gravedad == "Aviso" & estado == "Abierto", ///
        clean noobs abbreviate(12) string(90)

    display _newline "{hline 78}"
    display "INTENCIONALES Y CONOCIDOS (no se corrigen en este paso)"
    display "{hline 78}"
    list archivo linea regla estado motivo if estado != "Abierto", ///
        clean noobs abbreviate(12) string(80)
}

save "validacion_`hoy'.dta"
export delimited using "validacion_`hoy'.csv"
display _newline "Guardado: validacion_`hoy'.dta y validacion_`hoy'.csv"

timer off 1
display _newline "--- Tiempo total ---"
timer list 1

log close validar
