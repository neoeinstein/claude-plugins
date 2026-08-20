#!/bin/bash
# Self-check for check-rust-tenets.sh. Run it directly; it prints FAIL lines
# and exits non-zero on the first broken expectation.
#
# Cases are the ones the regexes cannot get right by inspection: the
# converter-vs-dispatch split on `match x.as_str()`, and field-vs-binding on
# the identifier-shaped-String family. Every case below is real code from a
# repo the hook runs against.

set -uo pipefail
HOOK="$(dirname "$0")/check-rust-tenets.sh"
fails=0

# expect <should-fire|should-be-silent> <family> <label> <<< rust source
expect() {
  local mode="$1" family="$2" label="$3" code
  code=$(cat)
  local out
  out=$(jq -n --arg c "$code" '{tool_input:{file_path:"/x/y.rs",new_string:$c}}' | bash "$HOOK")
  local hit=no
  [ -n "$out" ] && printf '%s' "$out" | grep -q "$family" && hit=yes
  if { [ "$mode" = fire ] && [ "$hit" = no ]; } || { [ "$mode" = silent ] && [ "$hit" = yes ]; }; then
    echo "FAIL [$mode/$family] $label"
    fails=$((fails + 1))
  fi
}

# --- stringly: converters are exempt ------------------------------------

expect silent 'Stringly dispatch' 'arms produce Self:: variants (from_name converter)' <<'RS'
pub fn from_name(name: &str) -> Self {
    let key: String = name.chars().filter(|c| c.is_alphanumeric()).collect();
    match key.as_str() {
        "boosterdraft" | "wotcdraft" | "draft" => Self::BoosterDraft,
        "commander" => Self::Commander,
        _ => Self::Other(name.to_string()),
    }
}
RS

expect silent 'Stringly dispatch' 'arms match named consts' <<'RS'
pub(crate) fn hfcu_account(txn_id: &str) -> Option<RepoAccountId> {
    let disc = Discriminator::new(txn_id.to_string());
    match disc.as_str() {
        DISC_MORTGAGE => None,
        DISC_SAVINGS => Some(RepoAccountId::new("hfcu-savings".to_string())),
        other => Some(RepoAccountId::new(format!("hfcu-{other}"))),
    }
}
RS

# --- stringly: business dispatch still trips ----------------------------

expect fire 'Stringly dispatch' 'arms produce tuples, not a closed type' <<'RS'
let (mode, days) = match form.automation_type.as_str() {
    "auto_open" => (form.auto_open_mode.as_deref().unwrap_or("period"), 0),
    "auto_fw" => (form.auto_fw_mode.as_deref().unwrap_or("period"), 1),
    _ => ("period", 0),
};
RS

expect fire 'Stringly dispatch' 'arms produce plain values' <<'RS'
fn proof(kind: &str) -> u8 {
    match kind.as_str() {
        "a" => 1,
        _ => 0,
    }
}
RS

expect fire 'Stringly dispatch' 'bare literal comparison outside any match' <<'RS'
if form.automation_type.as_str() != "reminder" {
    return Err(AppError::new(AppErrorKind::BadRequest("no".to_string())));
}
RS

expect fire 'Stringly dispatch' 'converter block does not silence a later violation' <<'RS'
pub fn from_name(name: &str) -> Self {
    match name.as_str() {
        "draft" => Self::BoosterDraft,
        _ => Self::Other(name.to_string()),
    }
}
fn route(kind: &str) -> u8 {
    match kind.as_str() {
        "a" => 1,
        _ => 0,
    }
}
RS

# --- identifier-shaped String: fields only ------------------------------

expect fire 'Identifier-shaped String' 'struct field named *_token' <<'RS'
#[derive(serde::Deserialize)]
pub struct ResendLinkForm {
    pub email: constant_gathering_core::Email,
    pub nonce_token: String,
}
RS

expect silent 'Identifier-shaped String' 'let binding is not a field' <<'RS'
let boundary_token: String = boundary_seed.iter().map(|b| format!("{b:02x}")).collect();
let org_ids: Vec<String> = user_info.orgs.iter().map(|o| o.id.clone()).collect();
RS

if [ "$fails" -eq 0 ]; then
  echo "check-rust-tenets: all cases pass"
else
  echo "check-rust-tenets: $fails case(s) failed"
  exit 1
fi
