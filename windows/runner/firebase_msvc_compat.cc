// MSVC runtime-compatibility shim for the prebuilt Firebase C++ libraries.
//
// The Firebase C++ SDK static libs (firebase_firestore / firebase_database)
// were compiled against an MSVC vcruntime that exported the internal global
// flag `_Avx2WmemEnabled`. An inlined `wmemcmp` reads that flag to choose
// between an AVX2 and a scalar code path. Newer vcruntime (VS 17.14 /
// toolset 14.44) no longer exports this symbol, so linking yswords.exe fails:
//
//   error LNK2019: unresolved external symbol _Avx2WmemEnabled
//                  referenced in function f_b_wmemcmp
//   error LNK2001: unresolved external symbol _Avx2WmemEnabled
//
// Defining it here satisfies the linker. 0 selects the always-correct scalar
// path; the comparison result is identical, only the AVX2 fast path is skipped.
extern "C" int _Avx2WmemEnabled = 0;
