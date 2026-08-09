#!/usr/bin/env zsh
# Tests del zshrc como archivo: que resourcearlo no aborte a mitad.
# Ejecutar: zsh config/zsh/zshrc.test.zsh
#
# `zsh -n zshrc` NO cubre esto. La sintaxis del archivo es válida en el vacío;
# lo que rompe es el ESTADO de la sesión que lo carga. Un alias preexistente con
# el mismo nombre que una función hace que zsh expanda el alias al parsear la
# definición y aborte el parseo del archivo entero. El chequeo de sintaxis pasa
# verde y el usuario pierde media shell.
#
# La región bajo test se extrae del zshrc con sed —igual que ssh.test.zsh, para
# no mantener una copia que se desincronice— pero aquí se escribe a un archivo y
# se SOURCEA, en vez de pasarla por `eval`. La diferencia no es cosmética: `eval`
# parsea toda la cadena de una vez, así que el alias se expandiría antes de que
# corriese el `unalias` y el test fallaría contra un zshrc correcto. `source`
# parsea y ejecuta comando a comando, que es como se carga el zshrc de verdad.

typeset -g TESTS_RUN=0 TESTS_FAILED=0

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    (( TESTS_RUN++ ))
    if [[ "$expected" == "$actual" ]]; then
        print "  ✓ $name"
    else
        (( TESTS_FAILED++ ))
        print "  ✗ $name"
        print "      esperado: «$expected»"
        print "      obtenido: «$actual»"
    fi
}

ZSHRC="${0:A:h}/../../zshrc"
[[ -f "$ZSHRC" ]] || { print "  ✗ no se encontró $ZSHRC"; exit 1 }

# La región va del comentario de cabecera al cierre de la función, así que
# incluye el `unalias` defensivo. Si alguien lo borra, estos tests fallan.
REGION=$(mktemp) || exit 1
trap 'rm -f "$REGION"' EXIT
sed -n '/^# dots — guardar/,/^}/p' "$ZSHRC" > "$REGION"
[[ -s "$REGION" ]] || { print "  ✗ no se pudo extraer la región de dots del zshrc"; exit 1 }
# A propósito NO se comprueba aquí que la región traiga el `unalias`: eso sería
# afirmar sobre el texto, y el texto no es lo que protege al usuario. Si alguien
# lo borra, fallan las tres aserciones de comportamiento de abajo, que es la
# señal correcta y además explica qué se rompe.

# El alias exacto que tenía el zshrc antes de migrar `dots` a función, que es el
# que sigue vivo en sesiones viejas y en los snapshots de shell cacheados.
ALIAS_VIEJO='git add . && git commit -m "Update dots: $(date)" && git push'

print "\ndots · colisión con el alias que precedió a la función"

# Control del experimento: en una sesión limpia esto siempre funcionó.
assert_eq "ok" "$(zsh -c "
    source ${(q)REGION}
    (( \$+functions[dots] )) && print ok || print roto
" 2>/dev/null)" "en sesión limpia define la función"

# El caso real: sesión que ya trae el alias viejo.
assert_eq "ok" "$(zsh -c "
    alias dots=${(q)ALIAS_VIEJO}
    source ${(q)REGION}
    (( \$+functions[dots] )) && print ok || print roto
" 2>/dev/null)" "con el alias viejo presente sigue definiendo la función"

# Lo que de verdad importa no es que `dots` exista, sino que el parseo no se
# detenga: sin el unalias se perdía todo lo que el zshrc define más abajo
# —zoxide, el sessionizer `t`, `sp`, el wrapper ssh() y los aliases de kubectl.
#
# El marcador va DENTRO del archivo que se sourcea. Puesto detrás del `source`
# se ejecutaría igual —una shell sigue viva tras un source fallido— y el test
# pasaría en verde sobre el bug, que es justo lo que hay que evitar.
REGION_CON_COLA=$(mktemp) || exit 1
trap 'rm -f "$REGION" "$REGION_CON_COLA"' EXIT
cat "$REGION" > "$REGION_CON_COLA"
print 'print sigue-vivo' >> "$REGION_CON_COLA"

assert_eq "sigue-vivo" "$(zsh -c "
    alias dots=${(q)ALIAS_VIEJO}
    source ${(q)REGION_CON_COLA}
" 2>/dev/null)" "no aborta el parseo: lo que el archivo define después sobrevive"

# Y sin ruido: «defining function based on alias» en stderr es la firma del bug.
assert_eq "0" "$(zsh -c "
    alias dots=${(q)ALIAS_VIEJO}
    source ${(q)REGION}
" 2>&1 >/dev/null | grep -c 'defining function based on alias')" \
    "no emite «defining function based on alias»"

print ""
if (( TESTS_FAILED > 0 )); then
    print "$((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN tests pasaron — $TESTS_FAILED fallaron"
    exit 1
fi
print "$TESTS_RUN/$TESTS_RUN tests pasaron"
