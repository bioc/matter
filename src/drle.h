#ifndef DRLE
#define DRLE

#include "matterDefines.h"

// run types
// (must match factor levels)
#define RUN_DELTA	1 // arbitary delta
#define RUN_ONLY	2 // same value runs only
#define RUN_SEQ		3 // sequential (delta=+/-1)

//// Struct for run length encoding info
//---------------------------------------

template<typename T>
struct RunInfo {
	T value;
	T delta;
	R_xlen_t length;
};

//// Delta run length encoding utilities
//---------------------------------------

// calculate run length and delta
template<typename T>
RunInfo<T> compute_run(T * x, size_t i, size_t len, int type = RUN_DELTA)
{
	R_xlen_t n = 1;
	T value = x[i], delta = 0;
	if ( i + 1 < len && !isNA(x[i]) && !isNA(x[i + 1]) )
		delta = x[i + 1] - x[i];
	if ( !equal<T>(delta, 0) )
	{
		if ( type == RUN_ONLY || 
			(type == RUN_SEQ && !equal<T>(std::fabs(delta), 1)) )
		{
			RunInfo<T> run = {value, 0, 1};
			return run;
		}
	}
	while( i + 1 < len )
	{
		bool both_na = isNA(x[i]) && isNA(x[i + 1]);
		T delta2 = both_na ? 0 : x[i + 1] - x[i];
		if ( equal<T>(delta, delta2) || both_na ) {
			n++;
			i++;
		}
		else
			break;
	}
	if ( n <= 2 && (i + 2 < len) && !equal<T>(delta, 0) )
	{
		R_xlen_t n2 = 1;
		T delta2 = 0;
		if ( !isNA(x[i + 1]) && !isNA(x[i + 2]) )
			delta2 = x[i + 2] - x[i + 1];
		while( i + 2 < len )
		{
			bool both_na = isNA(x[i + 1]) && isNA(x[i + 2]);
			T delta3 = both_na ? 0 : x[i + 2] - x[i + 1];
			if ( equal<T>(delta2, delta3) || both_na ) {
				n2++;
				i++;
			}
			else
				break;
		}
		if ( n2 > n ) {
			n = 1;
			delta = 0;
		}
	}
	if ( isNA(value) )
		delta = NA<T>();
	RunInfo<T> run = {value, delta, n};
	return run;
}

// count runs in an array x
template<typename T>
R_xlen_t num_runs(T * x, R_xlen_t len, int type = RUN_DELTA)
{
	R_xlen_t i = 0, n = 0;
	while ( i < len )
	{
		RunInfo<T> run = compute_run<T>(x, i, len, type);
		i += run.length;
		n++;
	}
	return n;
}

// count runs in a SEXP x
inline R_xlen_t num_runs(SEXP x, int type = RUN_DELTA)
{
	R_xlen_t len = XLENGTH(x);
	switch(TYPEOF(x)) {
		case LGLSXP:
		case INTSXP:
			return num_runs<int>(INTEGER(x), len, type);
		case REALSXP:
			return num_runs<double>(REAL(x), len, type);
		default:
			Rf_error("unsupported data type");
	}
}

//// Create DRLE objects
//------------------------

// initialize a DRLE S4 instance
inline SEXP make_drle(SEXP values, SEXP deltas, SEXP lengths)
{
	SEXP classDef, obj;
	PROTECT(classDef = R_do_MAKE_CLASS("drle"));
	PROTECT(obj = R_do_new_object(classDef));
	R_do_slot_assign(obj, Rf_install("values"), values);
	R_do_slot_assign(obj, Rf_install("deltas"), deltas);
	R_do_slot_assign(obj, Rf_install("lengths"), lengths);
	UNPROTECT(2);
	return obj;
}

// use DRLE to encode an array of x
template<typename Tval, typename Tlen>
size_t encode_drle(Tval * x, size_t len, Tval * values,
	Tval * deltas, Tlen * lengths, size_t nruns, int type = RUN_DELTA)
{
	size_t i = 0, j = 0;
	while ( i < len && j < nruns )
	{
		RunInfo<Tval> run = compute_run<Tval>(x, i, len, type);
		values[j] = static_cast<Tval>(run.value);
		deltas[j] = static_cast<Tval>(run.delta);
		lengths[j] = static_cast<Tlen>(run.length);
		i += lengths[j];
		j++;
	}
	return j;
}

// use DRLE to encode a SEXP
inline SEXP encode_drle(SEXP x, int type = RUN_DELTA, double cr = 0)
{
	SEXP values, deltas, lengths, obj;
	size_t nruns = num_runs(x, type);
	size_t sizeof_x = Rf_isReal(x) ? sizeof(double) : sizeof(int);
	size_t sizeof_lens = IS_LONG_VEC(x) ? sizeof(double) : sizeof(int);
	double uncomp_size = 48 + (XLENGTH(x) * sizeof_x);
	double comp_size = 984 + (nruns * (2 * sizeof_x + sizeof_lens));
	double comp_ratio = uncomp_size / comp_size;
	if ( comp_ratio < cr )
		return x;
	SEXPTYPE valstype = TYPEOF(x);
	SEXPTYPE delstype = Rf_isLogical(x) ? INTSXP : valstype;
	SEXPTYPE lenstype = IS_LONG_VEC(x) ? REALSXP : INTSXP;
	PROTECT(values = Rf_allocVector(valstype, nruns));
	PROTECT(deltas = Rf_allocVector(delstype, nruns));
	PROTECT(lengths = Rf_allocVector(lenstype, nruns));
	switch(TYPEOF(x)) {
		case LGLSXP: 
		case INTSXP: {
			switch(lenstype) {
				case INTSXP:
					encode_drle<int,int>(INTEGER(x), XLENGTH(x), INTEGER(values),
						INTEGER(deltas), INTEGER(lengths), nruns, type);
					break;
				case REALSXP:
					encode_drle<int,double>(INTEGER(x), XLENGTH(x), INTEGER(values),
						INTEGER(deltas), REAL(lengths), nruns, type);
					break;
			}
			break;
		}
		case REALSXP: {
			switch(lenstype) {
				case INTSXP:
					encode_drle<double,int>(REAL(x), XLENGTH(x), REAL(values),
						REAL(deltas), INTEGER(lengths), nruns, type);
					break;
				case REALSXP:
					encode_drle<double,double>(REAL(x), XLENGTH(x), REAL(values),
						REAL(deltas), REAL(lengths), nruns, type);
					break;
			}
			break;
		}
		default:
			Rf_error("unsupported data type");
	}	
	PROTECT(obj = make_drle(values, deltas, lengths));
	UNPROTECT(4);
	return obj;
}

//// CompressedVector class
//--------------------------

// container for DRLE S4 instance OR atomic vector
template<typename T>
class CompressedVector {

	public:

		CompressedVector(SEXP x)
		{
			if ( Rf_isS4(x) )
			{
				_type = TYPEOF(R_do_slot(x, Rf_install("values")));
				_pvalues = DataPtr<T>(R_do_slot(x, Rf_install("values")));
				_lengths = R_do_slot(x, Rf_install("lengths"));
				if ( XLENGTH(R_do_slot(x, Rf_install("deltas"))) > 0 )
					_pdeltas = DataPtr<T>(R_do_slot(x, Rf_install("deltas")));
				else
					_pdeltas = NULL;
				_truelength = XLENGTH(R_do_slot(x, Rf_install("values")));
				_length = 0;
				switch(TYPEOF(_lengths)) {
					case INTSXP:
						for ( index_t i = 0; i < _truelength; i++ )
							_length += INTEGER_ELT(_lengths, i);
						break;
					case REALSXP:
						for ( index_t i = 0; i < _truelength; i++ )
							_length += REAL_ELT(_lengths, i);
						break;
				}
				_is_compressed = true;
				_is_long_vec = Rf_isReal(_lengths);
			}
			else
			{
				_type = TYPEOF(x);
				_pvalues = DataPtr<T>(x);
				_truelength = XLENGTH(x);
				_length = _truelength;
				_is_compressed = false;
				_is_long_vec = IS_LONG_VEC(x);
			}
		}

		~CompressedVector() {}

		SEXPTYPE type() {
			return _type;
		}

		R_xlen_t length() {
			return _length;
		}

		R_xlen_t truelength() {
			return _truelength;
		}

		bool is_compressed() {
			return _is_compressed;
		}

		bool is_long_vec() {
			return _is_long_vec;
		}

		T values(index_t i) {
			if ( i < 0 || i >= truelength() )
				Rf_error("subscript out of bounds");
			return _pvalues[i];
		}

		T deltas(index_t i) {
			if ( !is_compressed() )
				return NA<T>();
			if ( _pdeltas == NULL )
				return 0;
			if ( i < 0 || i >= truelength() )
				Rf_error("subscript out of bounds");
			return _pdeltas[i];
		}

		R_xlen_t lengths(index_t i) {
			if ( !is_compressed() )
				return 0;
			if ( i < 0 || i >= truelength() )
				Rf_error("subscript out of bounds");
			switch(TYPEOF(_lengths)) {
				case INTSXP:
					return static_cast<R_xlen_t>(INTEGER_ELT(_lengths, i));
				case REALSXP:
					return static_cast<R_xlen_t>(REAL_ELT(_lengths, i));
				default:
					Rf_error("invalid lengths type");
			}
		}

		T get(index_t i)
		{
			if ( i < 0 || i >= length()  )
				Rf_error("subscript out of bounds");
			if ( isNA(i) )
				return NA<T>();
			if ( !is_compressed() )
				return values(i);
			index_t j = _last_index; // track last run accessed
			index_t run = _last_run; // to give ~O(1) iter access
			if ( i >= j )
			{
				while ( j < length() && run < truelength() ) {
					if ( i < j + lengths(run) ) {
						_last_index = j;
						_last_run = run;
						if ( isNA(values(run)) )
							return values(run);
						else
							return values(run) + deltas(run) * (i - j);
					}
					else {
						j += lengths(run);
						run++;
					}
				}
				return NA<T>();
			}
			else
			{
				while ( j >= 0 && run >= 0 ) {
					if ( i >= j ) {
						_last_index = j;
						_last_run = run;
						if ( isNA(values(run)) )
							return values(run);
						else
							return values(run) + deltas(run) * (i - j);
					}
					else
					{
						run--;
						j -= lengths(run);
					}
				}
				return NA<T>();
			}
		}

		size_t getRegion(index_t i, size_t size, T * buffer)
		{
			size_t j;
			for ( j = 0; j < size; j++ )
				buffer[j] = get(i + j);
			return j;
		}

		SEXP getRegion(index_t i, size_t size)
		{
			SEXP x;
			PROTECT(x = Rf_allocVector(type(), size));
			getRegion(i, size, DataPtr<T>(x));
			UNPROTECT(1);
			return x;
		}

		size_t getElements(SEXP indx, T * buffer)
		{
			R_xlen_t ni = XLENGTH(indx);
			index_t j;
			for ( j = 0; j < ni; j++ )
			{
				index_t i = IndexElt(indx, j);
				if ( isNA(i) )
					buffer[j] = NA<T>();
				else	
					buffer[j] = get(i - 1);
			}
			return j;
		}

		SEXP getElements(SEXP indx)
		{
			SEXP x;
			if ( indx == R_NilValue )
				return getRegion(0, length());
			PROTECT(x = Rf_allocVector(type(), XLENGTH(indx)));
			getElements(indx, DataPtr<T>(x));
			UNPROTECT(1);
			return x;
		}

		index_t find(T value)
		{
			if ( is_compressed() )
			{
				index_t i = 0;
				for ( index_t run = 0; run < truelength(); run++ ) {
					T delta = value - values(run);
					T mvalue = values(run) + (deltas(run) * (lengths(run) - 1));
					if ( equal<T>(delta, 0) )
						return i;
					if ( value <= mvalue && equal(std::fmod(delta, deltas(run)), 0) )
						return i + static_cast<index_t>(delta / deltas(run));
					i += lengths(run);
				}
			}
			else
			{
				for ( index_t i = 0; i < length(); i++ )
					if ( equal<T>(get(i), value) )
						return i;
			}
			return NA_INTEGER;
		}

		T operator[](index_t i) {
			return get(i);
		}

	protected:

		SEXPTYPE _type;
		T * _pvalues;
		T * _pdeltas;
		SEXP _lengths;
		R_xlen_t _length;
		R_xlen_t _truelength;
		index_t _last_index = 0; // cache most recent access
		index_t _last_run = 0;   // cache most recent access
		bool _is_compressed;
		bool _is_long_vec;

};

// container for DRLE S4 instance w/ levels OR factor
class CompressedFactor : public CompressedVector<int> {

	public:

		CompressedFactor(SEXP x) : CompressedVector<int>(x)
		{
			if ( Rf_isS4(x) )
				_levels = R_do_slot(x, Rf_install("levels"));
			else
				_levels = Rf_getAttrib(x, R_LevelsSymbol);
			_nlevels = LENGTH(_levels);
		}

		SEXP levels() {
			return _levels;
		}

		SEXP levels(index_t i) {
			return STRING_ELT(_levels, i);
		}

		int nlevels() {
			return _nlevels;
		}

	protected:

		SEXP _levels;
		int _nlevels;

};

//// Delta run length encoding for CompressedVector
//--------------------------------------------------

// compute run for CompressedVector
template<typename T>
RunInfo<T> compute_run(CompressedVector<T> x, SEXP indx, index_t j)
{
	R_xlen_t n = 1;
	index_t i1 = 0;
	index_t i2 = 0;
	T value = x[IndexElt(indx, j) - 1], delta = 0;
	if ( j + 1 < XLENGTH(indx) )
	{
		i1 = IndexElt(indx, j) - 1;
		i2 = IndexElt(indx, j + 1) - 1;
		if ( !isNA(x[i1]) && !isNA(x[i2]) )
			delta = x[i2] - x[i1];
	}
	while( j + 1 < XLENGTH(indx) )
	{
		i1 = IndexElt(indx, j) - 1;
		i2 = IndexElt(indx, j + 1) - 1;
		bool both_na = isNA(x[i1]) && isNA(x[i2]);
		T delta2 = both_na ? 0 : x[i2] - x[i1];
		if ( equal<T>(delta, delta2) || both_na ) {
			n++;
			j++;
		}
		else
			break;
	}
	if ( n <= 2 && (j + 2 < XLENGTH(indx)) && !equal<T>(delta, 0) )
	{
		R_xlen_t n2 = 1;
		i1 = IndexElt(indx, j + 1) - 1;
		i2 = IndexElt(indx, j + 2) - 1;
		T delta2 = 0;
		if ( !isNA(x[i1]) && !isNA(x[i2]) )
			delta2 = x[i2] - x[i1];
		while( j + 2 < XLENGTH(indx) )
		{
			i1 = IndexElt(indx, j + 1) - 1;
			i2 = IndexElt(indx, j + 2) - 1;
			bool both_na = isNA(x[i1]) && isNA(x[i2]);
			T delta3 = both_na ? 0 : x[i2] - x[i1];
			if ( equal<T>(delta2, delta3) || both_na ) {
				n2++;
				j++;
			}
			else
				break;
		}
		if ( n2 > n ) {
			n = 1;
			delta = 0;
		}
	}
	if ( isNA(value) )
		delta = NA<T>();
	RunInfo<T> run = {value, delta, n};
	return run;
}

// count runs in a CompressedVector
template<typename T>
R_xlen_t num_runs(CompressedVector<T> x, SEXP indx)
{
	R_xlen_t i = 0, n = 0;
	while ( i < XLENGTH(indx) )
	{
		RunInfo<T> run = compute_run<T>(x, indx, i);
		i += run.length;
		n++;
	}
	return n;
}

// recode a subsetted CompressedVector, must pre-calculate output length
template<typename Tval, typename Tlen>
size_t recode_drle(CompressedVector<Tval> x, SEXP indx, Tval * values,
	Tval * deltas, Tlen * lengths, size_t nruns)
{
	size_t i = 0, j = 0;
	while ( i < XLENGTH(indx) && j < nruns )
	{
		RunInfo<Tval> run = compute_run<Tval>(x, indx, i);
		values[j] = static_cast<Tval>(run.value);
		deltas[j] = static_cast<Tval>(run.delta);
		lengths[j] = static_cast<Tlen>(run.length);
		i += lengths[j];
		j++;
	}
	return j;
}

// recode a subsetted CompressedVector, return a SEXP
template<typename T>
SEXP recode_drle(CompressedVector<T> x, SEXP indx)
{
	SEXP values, deltas, lengths, obj;
	SEXPTYPE lengthstype = x.is_long_vec() ? REALSXP : INTSXP;
	size_t nruns = num_runs(x, indx);
	PROTECT(values = Rf_allocVector(x.type(), nruns));
	PROTECT(deltas = Rf_allocVector(x.type(), nruns));
	PROTECT(lengths = Rf_allocVector(lengthstype, nruns));
	switch(lengthstype) {
		case INTSXP:
			recode_drle<T,int>(x, indx, DataPtr<T>(values),
				DataPtr<T>(deltas), INTEGER(lengths), nruns);
			break;
		case REALSXP:
			recode_drle<T,double>(x, indx, DataPtr<T>(values),
				DataPtr<T>(deltas), REAL(lengths), nruns);
			break;
	}
	PROTECT(obj = make_drle(values, deltas, lengths));
	UNPROTECT(4);
	return obj;
}

// recode a subsetted DRLE S4 instance
inline SEXP recode_drle(SEXP x, SEXP indx)
{
	if ( indx == R_NilValue )
		return x;
	SEXP values = R_do_slot(x, Rf_install("values"));
	switch(TYPEOF(values)) {
		case LGLSXP: 
		case INTSXP: {
			CompressedVector<int> y(x);
			return recode_drle(y, indx);
		}
		case REALSXP: {
			CompressedVector<double> y(x);
			return recode_drle(y, indx);
		}
		default:
			Rf_error("unsupported data type");
	}
}

// decode a DRLE S4 instance at specified indices
inline SEXP decode_drle(SEXP x, SEXP indx)
{
	SEXP values = R_do_slot(x, Rf_install("values"));
	switch(TYPEOF(values)) {
		case LGLSXP: 
		case INTSXP: {
			CompressedVector<int> y(x);
			return y.getElements(indx);
		}
		case REALSXP: {
			CompressedVector<double> y(x);
			return y.getElements(indx);
		}
		default:
			Rf_error("unsupported data type");
	}
}

#endif // DRLE
