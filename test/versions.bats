#!/usr/bin/env bats

load test_helper

create_version() {
  mkdir -p "${PYENV_ROOT}/versions/$1"
}

setup() {
  mkdir -p "$PYENV_TEST_DIR"
  cd "$PYENV_TEST_DIR"
}

stub_system_python() {
  local stub="${PYENV_TEST_DIR}/bin/python"
  mkdir -p "$(dirname "$stub")"
  touch "$stub" && chmod +x "$stub"
}

create_executable() {
  local name="$1"
  local bin="${PYENV_TEST_DIR}/bin"
  mkdir -p "$bin"
  sed -Ee '1s/^ +//' > "${bin}/$name"
  chmod +x "${bin}/$name"
}

@test "no versions installed" {
  stub_system_python
  assert [ ! -d "${PYENV_ROOT}/versions" ]
  run pyenv-versions
  assert_success "* system (set by ${PYENV_ROOT}/version)"
}

@test "not even system python available" {
  PATH="$(path_without python python2 python3)" run pyenv-versions
  assert_failure
  assert_output "Warning: no Python detected on the system"
}

@test "bare output no versions installed" {
  assert [ ! -d "${PYENV_ROOT}/versions" ]
  run pyenv-versions --bare
  assert_success ""
}

@test "single version installed" {
  stub_system_python
  create_version "3.3"
  run pyenv-versions
  assert_success
  assert_output <<OUT
* system (set by ${PYENV_ROOT}/version)
  3.3
OUT
}

@test "single version bare" {
  create_version "3.3"
  run pyenv-versions --bare
  assert_success "3.3"
}

@test "multiple versions" {
  stub_system_python
  create_version "2.7.6"
  create_version "3.3.3"
  create_version "3.4.0"
  run pyenv-versions
  assert_success
  assert_output <<OUT
* system (set by ${PYENV_ROOT}/version)
  2.7.6
  3.3.3
  3.4.0
OUT
}

@test "indicates current version" {
  stub_system_python
  create_version "3.3.3"
  create_version "3.4.0"
  PYENV_VERSION=3.3.3 run pyenv-versions
  assert_success
  assert_output <<OUT
  system
* 3.3.3 (set by PYENV_VERSION environment variable)
  3.4.0
OUT
}

@test "bare doesn't indicate current version" {
  create_version "3.3.3"
  create_version "3.4.0"
  PYENV_VERSION=3.3.3 run pyenv-versions --bare
  assert_success
  assert_output <<OUT
3.3.3
3.4.0
OUT
}

@test "globally selected version" {
  stub_system_python
  create_version "3.3.3"
  create_version "3.4.0"
  cat > "${PYENV_ROOT}/version" <<<"3.3.3"
  run pyenv-versions
  assert_success
  assert_output <<OUT
  system
* 3.3.3 (set by ${PYENV_ROOT}/version)
  3.4.0
OUT
}

@test "per-project version" {
  stub_system_python
  create_version "3.3.3"
  create_version "3.4.0"
  cat > ".python-version" <<<"3.3.3"
  run pyenv-versions
  assert_success
  assert_output <<OUT
  system
* 3.3.3 (set by ${PYENV_TEST_DIR}/.python-version)
  3.4.0
OUT
}

@test "ignores non-directories under versions" {
  create_version "3.3"
  touch "${PYENV_ROOT}/versions/hello"

  run pyenv-versions --bare
  assert_success "3.3"
}

@test "lists symlinks under versions" {
  create_version "2.7.8"
  ln -s "2.7.8" "${PYENV_ROOT}/versions/2.7"

  run pyenv-versions --bare
  assert_success
  assert_output <<OUT
2.7
2.7.8
OUT
}

@test "doesn't list symlink aliases when --skip-aliases" {
  create_version "1.8.7"
  ln -s "1.8.7" "${PYENV_ROOT}/versions/1.8"
  mkdir moo
  ln -s "${PWD}/moo" "${PYENV_ROOT}/versions/1.9"

  run pyenv-versions --bare --skip-aliases
  assert_success

  assert_output <<OUT
1.8.7
1.9
OUT
}

@test "lists dot directories under versions" {
  create_version ".venv"

  run pyenv-versions --bare
  assert_success ".venv"
}

@test "uses version sort when available" {
  create_version "1.9.0"
  create_version "1.53.0"
  create_version "1.218.0"

  correct_versions_file="$(mktemp)"
  printf '%s/versions/%s\n' "${PYENV_ROOT}" "1.9.0" >>"$correct_versions_file"
  printf '%s/versions/%s\n' "${PYENV_ROOT}" "1.53.0" >>"$correct_versions_file"
  printf '%s/versions/%s\n' "${PYENV_ROOT}" "1.218.0" >>"$correct_versions_file"

  wrong_versions_file="$(mktemp)"
  printf '%s/versions/%s\n' "${PYENV_ROOT}" "1.218.0" >>"$wrong_versions_file"
  printf '%s/versions/%s\n' "${PYENV_ROOT}" "1.53.0" >>"$wrong_versions_file"
  printf '%s/versions/%s\n' "${PYENV_ROOT}" "1.9.0" >>"$wrong_versions_file"

  create_executable sort <<SH
#!$BASH
if [ "\$1" == "--version-sort" ]; then cat $(printf %q "$correct_versions_file")
else cat $(printf %q "$wrong_versions_file")
fi
SH

  run pyenv-versions --bare
  assert_success
  assert_output <<OUT
1.9.0
1.53.0
1.218.0
OUT
}
