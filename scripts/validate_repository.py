from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "DESCRIPTION",
    "NAMESPACE",
    "R/main.R",
    "inst/extdata/rf_fit.rds",
    "inst/extdata/m6A_input_example.csv",
    "man/figures/AU.png",
    "man/figures/ROC.png",
    "man/figures/PRC.png",
]

missing = [name for name in REQUIRED if not (ROOT / name).is_file()]
assert not missing, f"Missing package files: {missing}"

description = (ROOT / "DESCRIPTION").read_text(encoding="utf-8")
assert "BIO215_P3_m6APrediction" in description, "Repository URL is stale"
assert "Ci-yo@users.noreply.github.com" in description, "Public maintainer email is missing"
assert "MIT + file LICENSE" in description, "License metadata is missing"

namespace = (ROOT / "NAMESPACE").read_text(encoding="utf-8")
expected_exports = {"dna_encoding", "prediction_single", "prediction_multiple"}
exports = set(re.findall(r"export\(([^)]+)\)", namespace))
assert expected_exports.issubset(exports), f"Missing exports: {sorted(expected_exports - exports)}"

source = (ROOT / "R/main.R").read_text(encoding="utf-8")
for function in expected_exports:
    assert re.search(rf"{function}\s*<-\s*function", source), f"Missing implementation: {function}"
assert (ROOT / "inst/extdata/rf_fit.rds").stat().st_size > 1_000_000, "Bundled model is unexpectedly small"

for forbidden in (".Rhistory", ".RData", ".Renviron", "README.html"):
    assert not (ROOT / forbidden).exists(), f"Remove generated/local file: {forbidden}"

print("OK: package metadata, three exported functions, model and figures validated")
