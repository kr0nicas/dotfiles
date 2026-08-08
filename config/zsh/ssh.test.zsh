#!/usr/bin/env zsh
# Tests de _ssh_target, el resolutor de destino del wrapper `ssh` del zshrc.
# Ejecutar: zsh config/zsh/ssh.test.zsh
#
# La función se extrae del zshrc en vez de copiarse aquí: una copia se queda
# desincronizada del original y los tests pasan verdes sobre código que ya no
# es el que corre. No hay red ni conexiones — solo parseo de argumentos.

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
eval "$(sed -n '/^_ssh_target()/,/^}/p' "$ZSHRC")"
(( $+functions[_ssh_target] )) || { print "  ✗ _ssh_target no se pudo extraer del zshrc"; exit 1 }

print "\n_ssh_target · caso básico"
assert_eq "prod-web" "$(_ssh_target prod-web)"            "host suelto"
assert_eq "prod-web" "$(_ssh_target root@prod-web)"       "quita el usuario@"

print "\n_ssh_target · con comando detrás (la regresión que motivó el fix)"
# Antes devolvía el último no-flag, o sea el comando: "ls" y "restart".
assert_eq "prod-web" "$(_ssh_target prod-web ls -la)"                  "no confunde el comando con el host"
assert_eq "prod-web" "$(_ssh_target prod-web systemctl restart nginx)" "ni el último argumento del comando"
assert_eq "prod-web" "$(_ssh_target root@prod-web uptime)"             "usuario@ y comando a la vez"

print "\n_ssh_target · opciones con valor separado"
assert_eq "prod-web"    "$(_ssh_target -p 2222 prod-web)"               "-p no se toma como destino"
assert_eq "bastion-aws" "$(_ssh_target -i ~/.ssh/id_ed25519 bastion-aws)" "-i con ruta"
assert_eq "staging-db"  "$(_ssh_target -L 8080:localhost:80 staging-db)"  "-L con forward"
assert_eq "jump-host"   "$(_ssh_target -J bastion jump-host)"             "-J con salto"
assert_eq "qa-node1"    "$(_ssh_target -o ConnectTimeout=5 qa-node1)"     "-o con valor separado"

print "\n_ssh_target · flags sin valor"
assert_eq "qa-node1" "$(_ssh_target -4 -q qa-node1 df -h)"                "flags sueltos y comando"
assert_eq "dev-box"  "$(_ssh_target -o StrictHostKeyChecking=no dev-box)" "-o con valor pegado"

print "\n_ssh_target · sin destino"
_ssh_target -v >/dev/null 2>&1
assert_eq "1" "$?" "sale con 1 si no hay ningún destino"

print "\n$((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN tests pasaron"
(( TESTS_FAILED == 0 ))
