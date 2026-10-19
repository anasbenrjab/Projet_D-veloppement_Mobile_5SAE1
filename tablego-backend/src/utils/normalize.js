const JSON_FIELDS = ['photos', 'opening_hours', 'dietary_preferences', 'allergies', 'tags', 'matching_dishes'];

function normalizeRow(row) {
  if (!row || typeof row !== 'object') return row;
  for (const f of JSON_FIELDS) {
    if (f in row && typeof row[f] === 'string') {
      try { row[f] = JSON.parse(row[f]); } catch (_) { row[f] = null; }
    }
  }
  return row;
}

function normalizeRows(rows) {
  if (!Array.isArray(rows)) return normalizeRow(rows);
  return rows.map(normalizeRow);
}

module.exports = { normalizeRows };
