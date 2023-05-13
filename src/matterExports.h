
#ifndef MATTER_EXPORTS
#define MATTER_EXPORTS

#include "drle.h"
#include "atoms.h"
#include "matter.h"
#include "search.h"
#include "sparse.h"

extern "C" {

// Search (binary and approximate)
//--------------------------------

SEXP relativeDiff(SEXP x, SEXP y, SEXP ref);

SEXP binarySearch(SEXP x, SEXP table, SEXP tol,
	SEXP tol_ref, SEXP nomatch, SEXP nearest);
SEXP approxSearch(SEXP x, SEXP keys, SEXP values, SEXP tol,
	SEXP tol_ref, SEXP nomatch, SEXP interp, SEXP sorted);

// Compression (delta run length encoding)
//-----------------------------------------

SEXP encodeDRLE(SEXP x, SEXP cr);
SEXP recodeDRLE(SEXP x, SEXP i);
SEXP decodeDRLE(SEXP x, SEXP i);

// Internal testing for Atoms
//---------------------------

SEXP readAtom(SEXP x, SEXP i, SEXP type);
SEXP writeAtom(SEXP x, SEXP i, SEXP value);
SEXP readAtoms(SEXP x, SEXP indx, SEXP type, SEXP grp);
SEXP writeAtoms(SEXP x, SEXP indx, SEXP value, SEXP grp);
SEXP subsetAtoms(SEXP x, SEXP indx);
SEXP regroupAtoms(SEXP x, SEXP n);
SEXP ungroupAtoms(SEXP x);

// Matter data structures
//-----------------------

SEXP getMatterArray(SEXP x, SEXP i);
SEXP setMatterArray(SEXP x, SEXP i, SEXP value);
SEXP getMatterMatrix(SEXP x, SEXP i, SEXP j);
SEXP setMatterMatrix(SEXP x, SEXP i, SEXP j, SEXP value);
SEXP getMatterListElt(SEXP x, SEXP i, SEXP j);
SEXP setMatterListElt(SEXP x, SEXP i, SEXP j, SEXP value);
SEXP getMatterListSubset(SEXP x, SEXP i, SEXP j);
SEXP setMatterListSubset(SEXP x, SEXP i, SEXP j, SEXP value);
SEXP getMatterStrings(SEXP x, SEXP i, SEXP j);
SEXP setMatterStrings(SEXP x, SEXP i, SEXP j, SEXP value);

// Sparse data structures
//-----------------------

SEXP getSparseArray(SEXP x, SEXP i);
SEXP getSparseMatrix(SEXP x, SEXP i, SEXP j);

// Signal processing
//------------------

SEXP binVector(SEXP x, SEXP lower, SEXP upper, SEXP stat);
SEXP localMaxima(SEXP x, SEXP window);
SEXP peakBoundaries(SEXP x, SEXP peaks);
SEXP peakBases(SEXP x, SEXP peaks);
SEXP peakWidths(SEXP x, SEXP peaks, SEXP domain,
	 SEXP left_end, SEXP right_end, SEXP heights);
SEXP peakAreas(SEXP x, SEXP peaks, SEXP domain,
	 SEXP left_end, SEXP right_end);

} // extern "C"

#endif // MATTER_EXPORTS
