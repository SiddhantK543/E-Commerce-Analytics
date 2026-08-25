# queries/ (original difficulty-tiered collection)

This folder holds the **original** SQL work from the first version of
this project, organized by difficulty (easy → medium → hard) rather
than by business domain. It is preserved as-is (with the Phase 2
hygiene fixes below) because it demonstrates a clear progression of
SQL technique and is a strength worth keeping for portfolio purposes.

**For the primary, business-organized version of this project, see
`sql/`** — each of these queries (plus new additions for previously
thin domains like refunds/cancellations and risk/fraud) now also lives
under `sql/<domain>/`, grouped the way a real analytics team would
organize its work.

## Phase 2 hygiene fixes applied to this folder

- `hard_question` renamed to `hard_questions.sql` (was missing its
  extension and used a singular filename, inconsistent with the other
  two files and with the README).
- Removed a fully duplicated copy of Q1–Q9 that had been accidentally
  pasted twice into the file.
- Fixed a syntax error in Q10 (misplaced parenthesis around a window
  function).
- Removed a dangling, unmatched `*/` comment closer at the end of the
  file.
- Added the missing `-- Q3:` label (query existed but was unlabeled).
- Added Q7 ("first and last order per customer"), which was documented
  in the README's table of contents but absent from the file — written
  to match the documented concepts (MIN, MAX, DATE_PART, CASE WHEN).
  This query has not yet been executed against real data, so no
  result/finding commentary is attached to it.

No other query logic was rewritten — working queries were left
untouched.
