# CKB lock v0.1 semantic rules. Output: array of violation strings (empty = pass).
[ # L1: one entry per (repo_url, ref)
  (.entries | group_by([.repo_url, .ref]) | map(select(length > 1) | "L1 duplicate entry: \(.[0].repo_url)@\(.[0].ref)") | .[]),
  # L2: entries sorted by (repo_url, ref) so lock diffs are minimal and deterministic
  (if (.entries | map([.repo_url, .ref])) != (.entries | map([.repo_url, .ref]) | sort) then "L2 entries not sorted by (repo_url, ref)" else empty end)
]
