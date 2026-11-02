#!/bin/bash
# Solo test Node (Dama, Forza 4, Tris). Richiede node e tsc.
set -e
# Test logica Dama (richiede node e tsc)
if command -v tsc >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  T=$(mktemp -d)
  cp "$(dirname "$0")/../supabase/functions/dama-move/dama.ts" "$T/dama.ts"
  sed "s#../supabase/functions/dama-move/dama.ts#./dama.ts#" "$(dirname "$0")/dama_test.ts" > "$T/test.ts"
  (cd "$T" && tsc --strict --target es2020 --module commonjs --allowImportingTsExtensions --outDir out --rewriteRelativeImportExtensions test.ts \
    && sed -i 's#./dama.ts#./dama.js#' out/test.js && node out/test.js)
fi

# Test logica Forza 4 e Tris Pro
if command -v tsc >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  R="$(cd "$(dirname "$0")/.." && pwd)"
  T=$(mktemp -d); mkdir "$T/supabase" "$T/tests"
  cp -r "$R/supabase/functions" "$T/supabase/"; cp "$R/tests/f4_tris_test.ts" "$T/tests/"
  (cd "$T" && tsc --strict --target es2020 --module commonjs --allowImportingTsExtensions --outDir out --rewriteRelativeImportExtensions tests/f4_tris_test.ts >/dev/null 2>&1
   F=$(find out -name f4_tris_test.js); sed -i "s#\.ts'#.js'#" "$F"; node "$F")
fi
