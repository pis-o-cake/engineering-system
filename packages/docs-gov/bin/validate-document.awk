# Validate flattened rules and document facts in one process per document.
# Filesystem reference checks remain in the POSIX shell caller.
BEGIN { FS = "\t" }
FNR == NR {
  if ($1 == "alias") aliases[$2] = $3
  if ($1 == "rule") {
    known[$2] = 1
    if ($3 == "statuses") { statuses[$2, $4] = 1; status_list[$2] = status_list[$2] $4 " " }
    if ($3 == "required-frontmatter") required[$2, ++required_count[$2]] = $4
    if ($3 == "frozen-status") frozen[$2, $4] = 1
  }
  if ($1 == "section") {
    section_key[$2, ++section_count[$2]] = $4
    section_pattern[$2, section_count[$2]] = $5
  }
  next
}
$1 == "meta" && !($2 in metadata) { metadata[$2] = $3 }
$1 == "head" { heading[++head_count] = $3; filled[head_count] = $2 }
$1 == "lead" { lead = $2 }
function finding(message) { print "finding\t" message }
function validate(    declared, canonical, status, i, field, count, fields, pattern, anywhere, position, cursor, order, j) {
  declared = metadata["type"]
  if (declared == "") { finding("no declared document type; add frontmatter `type` or a doc-type meta"); return }
  canonical = (declared in aliases) ? aliases[declared] : declared
  if (!(canonical in known)) { finding("unknown document type: " declared); return }
  if (canonical != expected) finding("declared type " canonical " does not match the assigned type " expected)
  status = metadata["status"]
  if (!statuses[canonical, status]) finding("status '" status "' is not one of " status_list[canonical])
  for (i = 1; i <= required_count[canonical]; i++) {
    field = required[canonical, i]
    if (metadata[field] == "") finding("required metadata field is missing or empty: " field)
  }
  count = split(reference_fields, fields, " ")
  for (i = 1; i <= count; i++) {
    field = fields[i]
    if (metadata[field] != "") print "reference\t" field "\t" metadata[field]
  }
  if (deferred == "true") return
  if (lead != 1) finding("no leading summary before the first section")
  cursor = 1
  for (i = 1; i <= section_count[canonical]; i++) {
    pattern = section_pattern[canonical, i]
    if (pattern == "") continue
    anywhere = 0
    for (j = 1; j <= head_count; j++) if (match(heading[j], pattern)) { anywhere = j; break }
    field = section_key[canonical, i]
    if (!anywhere) { finding("missing required section (" field "): " pattern); continue }
    if (frozen[canonical, status]) position = anywhere
    else {
      position = 0
      for (j = cursor; j <= head_count; j++) if (match(heading[j], pattern)) { position = j; break }
    }
    if (!position) order = order (order == "" ? "" : " ") field
    else {
      if (filled[position] != 1) finding("required section has no content (" field "): " heading[position])
      if (!frozen[canonical, status]) cursor = position + 1
    }
  }
  if (order != "") finding("required sections are out of the declared order: " order)
}
END { validate() }
