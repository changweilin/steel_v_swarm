class_name SourceNumeric
extends RefCounted

# V8's two-argument Math.hypot: scale by the larger magnitude, then its Kahan sum
# reduces to one addition. Infinity outranks NaN, as in the original builtin.
static func hypot(x: float, y: float) -> float:
	var a := absf(x)
	var b := absf(y)
	if is_inf(a) or is_inf(b):
		return INF
	if is_nan(a) or is_nan(b):
		return NAN
	var largest := maxf(a, b)
	if largest == 0:
		return 0.0
	a /= largest
	b /= largest
	return sqrt(a * a + b * b) * largest
