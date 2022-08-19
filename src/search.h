#ifndef MATTER_SEARCH
#define MATTER_SEARCH

#define R_NO_REMAP

#include <R.h>

#include <cmath>
#include <cfloat>

#include "utils.h"
#include "signal.h"

#define SEARCH_ERROR -1

//// Linear search
//-----------------

// fuzzy linear search (fallback for unsorted arrays)
template<typename T>
index_t linear_search(T x, SEXP table, size_t start, size_t end,
	double tol, int tol_ref, int nomatch, bool nearest = FALSE)
{
	index_t pos = nomatch;
	double diff, diff_min = DBL_MAX;
	T * pTable = DataPtr<T>(table);
	for ( size_t i = start; i < end; i++ )
	{
		diff = rel_diff(x, pTable[i], tol_ref);
		if ( diff == 0 )
			return i;
		if ( diff < diff_min ) {
			diff_min = diff;
			pos = i;
		}
	}
	if ( diff_min < tol || nearest )
		return pos;
	else
		return nomatch;
}

//// Binary search
//-----------------

// fuzzy binary search returning position of 'x' in 'table'
template<typename T>
index_t binary_search(T x, SEXP table, size_t start, size_t end,
	double tol, int tol_ref, int nomatch, bool nearest = FALSE,
	bool ind1 = FALSE, int err = SEARCH_ERROR)
{
	double diff;
	index_t min = start, max = end, mid = nomatch;
	T * pTable = DataPtr<T>(table);
	while ( start < end )
	{
		mid = start + (end - start) / 2;
		double d1 = rel_change(pTable[start], pTable[mid]);
		double d2 = rel_change(pTable[mid], pTable[end - 1]);
		if ( d1 > 0 || d2 > 0 )
			return err; // table is not sorted
		diff = rel_change(x, pTable[mid], tol_ref);
		if ( diff < 0 )
			end = mid;
		else if ( diff > 0 )
			start = mid + 1;
		else
			return mid + ind1;
	}
	if ( (nearest || tol > 0) && (max - min) > 0 )
	{
		index_t left = mid >= min + 1 ? mid - 1 : min;
		index_t right = mid < max - 1 ? mid + 1 : max - 1;
		double dleft = rel_diff(x, pTable[left], tol_ref);
		double dmid = rel_diff(x, pTable[mid], tol_ref);
		double dright = rel_diff(x, pTable[right], tol_ref);
		if ( (mid == left && diff < 0) && (nearest || dleft < tol) )
			return left + ind1;
		else if ( (mid == right && diff > 0) && (nearest || dright < tol) )
			return right + ind1;
		else {
			if ( (dleft <= dmid && dleft <= dright) && (nearest || dleft < tol) )
				return left + ind1;
			else if ( (dmid <= dleft && dmid <= dright) && (nearest || dmid < tol) )
				return mid + ind1;
			else if ( nearest || dright < tol )
				return right + ind1;
		}
	}
	return nomatch;
}

template<typename T>
index_t do_binary_search(int * ptr, SEXP x, SEXP table, size_t start, size_t end,
	double tol, int tol_ref, int nomatch, bool nearest = FALSE,
	bool ind1 = FALSE, int err = SEARCH_ERROR)
{
	R_xlen_t len = XLENGTH(x);
	T * pX = DataPtr<T>(x);
	R_xlen_t n = XLENGTH(table);
	size_t num_matches = 0;
	for ( size_t i = 0; i < len; i++ ) {
		if ( isNA(pX[i]) )
			ptr[i] = nomatch;
		else {
			index_t pos = binary_search<T>(pX[i], table, 0, n,
				tol, tol_ref, nomatch, nearest, ind1, err);
			if ( pos != err ) {
				ptr[i] = pos;
				num_matches++;
			}
			else
				return err;
		}
	}
	return num_matches;
}

template<typename T>
SEXP do_binary_search(SEXP x, SEXP table, double tol, int tol_ref,
	int nomatch, bool nearest = FALSE, bool ind1 = FALSE)
{
	R_xlen_t len = XLENGTH(x);
	SEXP pos;
	if ( IS_LONG_VEC(table) ) {
		PROTECT(pos = Rf_allocVector(REALSXP, len));
	} else {
		PROTECT(pos = Rf_allocVector(INTSXP, len));
	}
	int * pPos = INTEGER(pos);
	do_binary_search<T>(pPos, x, table, 0, len,
		tol, tol_ref, nomatch, nearest, ind1);
	UNPROTECT(1);
	return pos;
}

//// Approximate search
//----------------------

// search for 'values' indexed by 'keys' with interpolation
template<typename Tkey, typename Tval>
Pair<index_t,Tval> approx_search(Tkey x, SEXP keys, SEXP values, size_t start, size_t end,
	double tol, int tol_ref, Tval nomatch, int interp = EST_NEAR, bool sorted = TRUE)
{
	Tkey * pKeys = DataPtr<Tkey>(keys);
	Tval * pValues = DataPtr<Tval>(values);
	index_t pos = NA_INTEGER;
	Tval val = nomatch;
	Pair<index_t,Tval> result;
	if ( isNA(x) )
		return result;
	if ( sorted )
		pos = binary_search<Tkey>(x, keys,
			start, end, tol, tol_ref, NA_INTEGER);
	else
		pos = linear_search<Tkey>(x, keys,
			start, end, tol, tol_ref, NA_INTEGER);
	if ( !isNA(pos) && pos >= 0 )
	{
		if ( tol > 0 )
			val = interp1<Tkey,Tval>(x, pKeys, pValues,
				pos, end, tol, tol_ref, interp, sorted);
		else
			val = pValues[pos];
	}
	result = {pos, val};
	return result;
}

template<typename Tkey, typename Tval>
index_t do_approx_search(Tval * ptr, Tkey * x, size_t xlen, SEXP keys, SEXP values,
	size_t start, size_t end, double tol, int tol_ref, Tval nomatch,
	int interp = EST_NEAR, bool sorted = TRUE, size_t stride = 1)
{
	index_t num_matches = 0, i = 0, current = start;
	while ( i < xlen )
	{
		ptr[i * stride] = nomatch;
		if ( !isNA(x[i]) )
		{
			Pair<index_t,Tval> result = approx_search(x[i], keys, values,
				current, end, tol, tol_ref, nomatch, interp, sorted);
			if ( !isNA(result.first) ) {
				if ( result.first < 0 ) { // keys are not sorted
					sorted = FALSE; // fall back to linear search
					current = start; // reset search space
					continue;
				}
				current = result.first;
				ptr[i * stride] = result.second;
				num_matches++;
			}
			if ( !sorted || (i + 1 < xlen && x[i + 1] < x[i]) )
				current = start; // reset if either 'x' or 'keys' is unsorted
		}
		i++;
	}
	return num_matches;
}

template<typename Tkey, typename Tval>
SEXP do_approx_search(SEXP x, SEXP keys, SEXP values, double tol, int tol_ref,
	Tval nomatch, int interp = EST_NEAR, bool sorted = TRUE)
{
	R_xlen_t xlen = XLENGTH(x);
	R_xlen_t keylen = XLENGTH(keys);
	SEXP result;
	PROTECT(result = Rf_allocVector(TYPEOF(values), xlen));
	Tval * pResult = DataPtr<Tval>(result);
	Tkey * pX = DataPtr<Tkey>(x);
	do_approx_search<Tkey, Tval>(pResult, pX, xlen, keys, values,
		0, keylen, tol, tol_ref, nomatch, interp, sorted);
	UNPROTECT(1);
	return result;
}

#endif // MATTER_SEARCH
