How to run the merge (PowerShell)
----------------------------------
1> Run: powershell -ExecutionPolicy Bypass -File tools/build/merge_CTLD.ps1
2> In PowerShell, enter: powershell -ExecutionPolicy Bypass -File tools/build/merge_CTLD.ps1
   Confirm execution if prompted.

The merger reads listToMerge.txt, merges all source files from ../src/
and generates CTLD_Next.lua in the parent (repo root) folder.

Notes:
- Lines starting with "--" in listToMerge.txt are comments and are skipped.
- Subdirectory paths (e.g. scenes/CTLD_fobSceneDatas.lua) are resolved
  relative to ../src/.
- CTLD_Next.lua is the development output. At final release it replaces CTLD.lua.
