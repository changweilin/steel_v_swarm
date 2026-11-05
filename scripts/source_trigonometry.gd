class_name SourceTrigonometry
extends RefCounted

# Chromium 151's Math.sin/Math.cos (LLVM libc) are correctly rounded, so any exact
# evaluation reproduces their bits; the platform libm does not (it misses sin(pi/4)).
# Numbers are fixed-point limb arrays: index 0 holds the integer part and indices
# 1..LIMBS hold 28-bit fractions, so 196 fraction bits carry every intermediate.
# Payne-Hanek reduction keeps the deepest double cancellation (about 2^-62) exact.

const BITS := 28
const MASK := (1 << BITS) - 1
const LIMBS := 7
const REDUCTION_LIMBS := 12
const SERIES_TERMS := 12
const TABLE_STEPS := 51
# 2/pi as 28-bit fractions, enough for the largest double exponent.
const TWO_OVER_PI: Array[int] = [
	0xa2f9836, 0xe4e4415, 0x29fc275, 0x7d1f534, 0xddc0db6, 0x295993c, 0x439041f, 0xe5163ab,
	0xdebbc56, 0x1b7246e, 0x3a424dd, 0x2e00649, 0x2eea09d, 0x1921cfe, 0x1deb1cb, 0x129a73e,
	0xe88235f, 0x52ebb44, 0x84e99c7, 0x026b45f, 0x7e41399, 0x1d63983, 0x5339f49, 0xc845f8b,
	0xbdf9283, 0xb1ff897, 0xffde059, 0x80fef2f, 0x118b5a0, 0xa6d1f6d, 0x367ecf2, 0x7cb09b7,
	0x4f463f6, 0x69e5fea, 0x2d7527b, 0xac7ebe5, 0xf17b3d0, 0x739f78a, 0x5292ea6, 0xbfb5fb1,
	0x1f8d5d0, 0x8560330, 0x46fc7b6, 0xbabf0cf, 0xbc209af, 0x4361da9, 0xe391615, 0xee61b08,
	0x6599855, 0xf14a068,
]
const HALF_PI: Array[int] = [0x0000001, 0x921fb54, 0x442d184, 0x69898cc, 0x51701b8, 0x39a2520, 0x49c1114, 0xcf98e80]
const PI_OVER_FOUR := 0.7853981633974483
const TINY := 7.450580596923828e-09 # 2^-27: sin(x) rounds to x and cos(x) to 1 below it.

# sin(j/64) and cos(j/64) for j = 0..TABLE_STEPS, built once by exact rotation.
static var _table_sin: Array[PackedInt64Array] = []
static var _table_cos: Array[PackedInt64Array] = []

static func sin(x: float) -> float:
	if is_nan(x) or is_inf(x):
		return NAN
	if absf(x) < TINY:
		return x
	var reduced := _reduce(absf(x))
	var values := _sin_cos(reduced)
	var quadrant: int = reduced.quadrant
	var result: float = values[quadrant & 1]
	if quadrant & 1 == 0 and reduced.negative:
		result = -result
	if quadrant >= 2:
		result = -result
	return -result if x < 0 else result

static func cos(x: float) -> float:
	if is_nan(x) or is_inf(x):
		return NAN
	if absf(x) < TINY:
		return 1.0
	var reduced := _reduce(absf(x))
	var values := _sin_cos(reduced)
	var quadrant: int = reduced.quadrant
	var result: float = values[1 - (quadrant & 1)]
	if quadrant & 1 == 1 and reduced.negative:
		result = -result
	if quadrant == 1 or quadrant == 2:
		result = -result
	return result

# |x| = quadrant * pi/2 + r with |r| <= pi/4; r = mantissa * 2^-shift, mantissa in [1/2, 1).
static func _reduce(x: float) -> Dictionary:
	var word := PackedByteArray()
	word.resize(8)
	word.encode_double(0, x)
	var raw := word.decode_s64(0)
	var mantissa := (raw & ((1 << 52) - 1)) | (1 << 52)
	var exponent := ((raw >> 52) & 0x7ff) - 1075
	if x <= PI_OVER_FOUR:
		var fraction := _empty(LIMBS + 1)
		var lead := _bit_length(mantissa)
		var shift := -(exponent + lead)
		# mantissa * 2^(exponent + shift) lies in [1/2, 1); place its bits after the point.
		_place(fraction, mantissa, lead)
		return {"quadrant": 0, "negative": false, "mantissa": fraction, "shift": shift}
	var unit := floori(float(exponent) / BITS)
	var offset := exponent - unit * BITS
	var parts := [(mantissa & ((1 << (BITS - offset)) - 1)) << offset, (mantissa >> (BITS - offset)) & MASK, mantissa >> (2 * BITS - offset)]
	# Column k collects products weighted 2^(-28k); heavier columns are multiples of 4.
	var columns := _empty(REDUCTION_LIMBS + 2)
	for part in range(3):
		for column in range(REDUCTION_LIMBS + 2):
			var index: int = column + unit + part - 1
			if index >= 0 and index < TWO_OVER_PI.size():
				columns[column] += parts[part] * TWO_OVER_PI[index]
	for column in range(REDUCTION_LIMBS + 1, 0, -1):
		columns[column - 1] += columns[column] >> BITS
		columns[column] &= MASK
	var quadrant := columns[0] & 3
	columns[0] = 0
	var negative := false
	if columns[1] >> (BITS - 1) == 1:
		var one := _empty(columns.size())
		one[0] = 1
		columns = _subtract(one, columns)
		quadrant = (quadrant + 1) & 3
		negative = true
	var normalized := _normalize(columns)
	var product := _multiply(normalized.value, _limbs(HALF_PI))
	var shift: int = normalized.shift
	if product[0] != 0:
		product = _shift_right(product, 1)
		shift -= 1
	return {"quadrant": quadrant, "negative": negative, "mantissa": product, "shift": shift}

# Returns [sin |r|, cos |r|] rounded to doubles.
static func _sin_cos(reduced: Dictionary) -> Array[float]:
	_ensure_table()
	var mantissa: PackedInt64Array = reduced.mantissa
	var shift: int = reduced.shift
	if shift > 7:
		# |r| < 1/128: keep r's relative precision through r * S(r^2).
		var square := _shift_right(_multiply(mantissa, mantissa), 2 * shift)
		return [_to_double(_multiply(mantissa, _sine_series(square)), shift), _to_double(_cosine_series(square), 0)]
	var r := _shift_right(mantissa, shift)
	# j = round(64 r); s = r - j/64 with |s| <= 1/128.
	var step := (r[1] >> (BITS - 6)) + ((r[1] >> (BITS - 7)) & 1)
	var anchor := _empty(LIMBS + 1)
	anchor[1] = step << (BITS - 6)
	var below := _compare(r, anchor) < 0
	var delta := _subtract(anchor, r) if below else _subtract(r, anchor)
	var square := _multiply(delta, delta)
	var sine_delta := _multiply(delta, _sine_series(square))
	var cosine_delta := _cosine_series(square)
	var sine_anchor := _table_sin[step]
	var cosine_anchor := _table_cos[step]
	var sine_cos := _multiply(sine_anchor, cosine_delta)
	var cos_sine := _multiply(cosine_anchor, sine_delta)
	var cos_cos := _multiply(cosine_anchor, cosine_delta)
	var sine_sine := _multiply(sine_anchor, sine_delta)
	var sine := _subtract(sine_cos, cos_sine) if below else _add(sine_cos, cos_sine)
	var cosine := _add(cos_cos, sine_sine) if below else _subtract(cos_cos, sine_sine)
	return [_to_double(sine, 0), _to_double(cosine, 0)]

# S(z) = sum (-z)^n / (2n+1)!, so sin(s) = s * S(s^2).
static func _sine_series(square: PackedInt64Array) -> PackedInt64Array:
	var value := _one()
	for term in range(SERIES_TERMS, 0, -1):
		value = _subtract(_one(), _divide(_multiply(square, value), (2 * term) * (2 * term + 1)))
	return value

# C(z) = sum (-z)^n / (2n)!, so cos(s) = C(s^2).
static func _cosine_series(square: PackedInt64Array) -> PackedInt64Array:
	var value := _one()
	for term in range(SERIES_TERMS, 0, -1):
		value = _subtract(_one(), _divide(_multiply(square, value), (2 * term - 1) * (2 * term)))
	return value

static func _ensure_table() -> void:
	if not _table_sin.is_empty():
		return
	var first := _empty(LIMBS + 1)
	first[1] = 1 << (BITS - 6)
	var square := _multiply(first, first)
	var sine_step := _multiply(first, _sine_series(square))
	var cosine_step := _cosine_series(square)
	var sine := _empty(LIMBS + 1)
	var cosine := _one()
	for step in range(TABLE_STEPS + 1):
		_table_sin.append(sine)
		_table_cos.append(cosine)
		var next_sine := _add(_multiply(sine, cosine_step), _multiply(cosine, sine_step))
		cosine = _subtract(_multiply(cosine, cosine_step), _multiply(sine, sine_step))
		sine = next_sine

# Rounds value * 2^-shift (value in (0, 1)) to the nearest double.
static func _to_double(value: PackedInt64Array, shift: int) -> float:
	var first := 1
	while first < value.size() and value[first] == 0:
		first += 1
	if first == value.size():
		return 0.0
	var lead := BITS * (first - 1) + (BITS - _bit_length(value[first])) + 1
	var window := (_window(value, lead) << BITS) | _window(value, lead + BITS)
	var mantissa := window >> 3
	var rest := window & 7
	var position := lead + 2 * BITS
	while rest & 3 == 0 and position <= BITS * (value.size() - 1):
		rest |= 1 if _window(value, position) != 0 else 0
		position += BITS
	if rest & 4 != 0 and (rest & 3 != 0 or mantissa & 1 == 1):
		mantissa += 1
	return float(mantissa) * _power_of_two(-(lead + 52) - shift)

# 28 bits whose most significant bit is fraction bit `bit` (bit 1 weighs 1/2).
static func _window(value: PackedInt64Array, bit: int) -> int:
	var index := (bit - 1) / BITS + 1
	var offset := (bit - 1) % BITS
	var high := value[index] if index < value.size() else 0
	if offset == 0:
		return high
	var low := value[index + 1] if index + 1 < value.size() else 0
	return ((high << offset) & MASK) | (low >> (BITS - offset))

# Shifts a fraction left until its leading bit weighs 1/2: value = result * 2^-shift.
static func _normalize(value: PackedInt64Array) -> Dictionary:
	var first := 1
	while value[first] == 0:
		first += 1
	var lead := BITS * (first - 1) + (BITS - _bit_length(value[first])) + 1
	var result := _empty(LIMBS + 1)
	for index in range(1, LIMBS + 1):
		result[index] = _window(value, lead + BITS * (index - 1))
	return {"value": result, "shift": lead - 1}

static func _place(target: PackedInt64Array, mantissa: int, length: int) -> void:
	# Writes mantissa so that its top bit is fraction bit 1.
	var remaining := length
	var index := 1
	while remaining > 0:
		var take := mini(BITS, remaining)
		remaining -= take
		target[index] = ((mantissa >> remaining) & ((1 << take) - 1)) << (BITS - take)
		index += 1

static func _shift_right(value: PackedInt64Array, bits: int) -> PackedInt64Array:
	var result := _empty(LIMBS + 1)
	if bits >= BITS * (LIMBS + 1):
		return result
	result[0] = value[0] >> bits if bits < BITS else 0
	# Prefixing a zero limb makes value[0] the first fraction limb, so original
	# fraction bit k sits at bit k + 28 and result fraction bit b reads bit b - bits + 28.
	var extended := PackedInt64Array([0])
	extended.append_array(value)
	for index in range(1, LIMBS + 1):
		var start := BITS * index + 1 - bits
		if start >= 1:
			result[index] = _window(extended, start)
		elif start > -BITS:
			result[index] = extended[1] >> (1 - start)
	return result

static func _multiply(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var columns := _empty(LIMBS + 2)
	for i in range(LIMBS + 1):
		if a[i] == 0:
			continue
		for j in range(mini(LIMBS + 2 - i, LIMBS + 1)):
			columns[i + j] += a[i] * b[j]
	for column in range(LIMBS + 1, 0, -1):
		columns[column - 1] += columns[column] >> BITS
		columns[column] &= MASK
	columns.resize(LIMBS + 1)
	return columns

static func _divide(value: PackedInt64Array, divisor: int) -> PackedInt64Array:
	var result := _empty(LIMBS + 1)
	var remainder := 0
	for index in range(LIMBS + 1):
		var current := (remainder << BITS) | value[index]
		result[index] = current / divisor
		remainder = current % divisor
	return result

static func _add(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var result := _empty(LIMBS + 1)
	var carry := 0
	for index in range(LIMBS, -1, -1):
		var total := a[index] + b[index] + carry
		carry = total >> BITS if index > 0 else 0
		result[index] = total & MASK if index > 0 else total
	return result

# a - b for a >= b, over the shorter of the two lengths' common prefix.
static func _subtract(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var size := mini(a.size(), b.size())
	var result := _empty(size)
	var borrow := 0
	for index in range(size - 1, -1, -1):
		var total := a[index] - b[index] - borrow
		borrow = 1 if total < 0 and index > 0 else 0
		result[index] = total + (borrow << BITS) if index > 0 else total
	return result

static func _compare(a: PackedInt64Array, b: PackedInt64Array) -> int:
	for index in range(LIMBS + 1):
		if a[index] != b[index]:
			return -1 if a[index] < b[index] else 1
	return 0

static func _limbs(values: Array[int]) -> PackedInt64Array:
	return PackedInt64Array(values)

static func _one() -> PackedInt64Array:
	var value := _empty(LIMBS + 1)
	value[0] = 1
	return value

static func _empty(size: int) -> PackedInt64Array:
	var value := PackedInt64Array()
	value.resize(size)
	value.fill(0)
	return value

static func _bit_length(value: int) -> int:
	var length := 0
	while value >> length != 0:
		length += 1
	return length

static func _power_of_two(exponent: int) -> float:
	var word := PackedByteArray()
	word.resize(8)
	word.encode_s64(0, (exponent + 1023) << 52)
	return word.decode_double(0)
