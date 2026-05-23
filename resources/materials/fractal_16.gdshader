shader_type canvas_item;

const int MAX_DIGITS = 16;
const int LIMB_BASE = 10000;
const int LIMB_DIGITS = 4;
uniform int ex[MAX_DIGITS];
uniform int ey[MAX_DIGITS];
uniform int box_size[MAX_DIGITS];
uniform int ex_size;
uniform int ey_size;
uniform int box_size_size;
uniform int digits_precision;
uniform int max_iter = 100;
uniform float colors = 0.5;
uniform vec2 viewport_size;
uniform vec2 tile_origin = vec2(0.0, 0.0);
uniform vec2 tile_size = vec2(32.0, 32.0);

/*
========================================================
ARBITRARY PRECISION FLOAT LIBRARY FOR GODOT SHADERS
========================================================

Representation format ("repr"):

[decimal_pos, limbs...]

Each limb stores 4 decimal digits in base 10000.

Examples:

[1, 12, 3400] = 12.34
[1, 0, 5600] = 0.56
[1, -123, 4500] = -123.45
[1, 0] = 0

--------------------------------------------------------
IMPORTANT: SIZE != PRECISION
--------------------------------------------------------

This library uses TWO different concepts:

1. repr size
2. decimal precision

They are NOT the same thing.

repr size:
- number of VALID entries in the repr array
- used by all arithmetic functions

Correct:

float_repr_add(a, a_size, b, b_size, ...)

Wrong:

float_repr_add(a, digits_precision, b, digits_precision, ...)

decimal precision:
- number of decimal digits to GENERATE
- only used in functions like:

_float_to_repr(value, precision, ...)
float_repr_div(a, a_size, b, b_size, precision, ...)

Example:

_float_to_repr(0.123456, 2, ...) -> 0.12
_float_to_repr(0.123456, 6, ...) -> 0.123456

--------------------------------------------------------
SIGN RULE
--------------------------------------------------------

The number sign is encoded in the FIRST NON-ZERO limb.

Positive: [1, 12, 3400]
Negative: [1, -12, 3400]

--------------------------------------------------------
GDSCRIPT -> SHADER UNIFORM
--------------------------------------------------------

Shader:

uniform int number_a[32];
uniform int number_a_size;

uniform int number_b[32];
uniform int number_b_size;


GDScript:

material.set_shader_parameter("number_a", PackedInt32Array([1, 12,3400]))
material.set_shader_parameter("number_a_size", 3)
material.set_shader_parameter("number_b", PackedInt32Array([1, 0,5600]))
material.set_shader_parameter("number_b_size", 3)

--------------------------------------------------------
EXAMPLE: ADDITION
--------------------------------------------------------

12.34 + 0.56

A: [1,12,3400]
B: [1,0,5600]
Result: [1,12,9000] = 12.9

--------------------------------------------------------
EXAMPLE: SUBTRACTION
--------------------------------------------------------

12.34 - 0.56

A: [2,1,2,3,4]
B: [1,5,6]
Result: [1,11,7800] = 11.78

--------------------------------------------------------
EXAMPLE: MULTIPLICATION
--------------------------------------------------------

12.34 * 0.56

Result: [1,6,9104] = 6.9104

--------------------------------------------------------
EXAMPLE: DIVISION
--------------------------------------------------------

12.34 / 0.56

precision = 6
Result: [1,22,357,1400] = 22.035714

--------------------------------------------------------
SHADER EXAMPLE
--------------------------------------------------------

void fragment() {

    int result[MAX_DIGITS];
    int result_size = 0;

    float_repr_add(number_a, number_a_size, number_b, number_b_size, result, result_size);

    float r = float(abs(result[1])) / float(LIMB_BASE - 1);

    COLOR = vec4(r, 0.0, 0.0, 1.0);
}

--------------------------------------------------------
READING RESULTS BACK IN GDSCRIPT
--------------------------------------------------------

await RenderingServer.frame_post_draw()
var img = subviewport.get_texture().get_image()
var pixel = img.get_pixel(0, 0)
print(pixel.r)

--------------------------------------------------------
IMPORTANT LIMITATIONS
--------------------------------------------------------

1. Arrays are FIXED SIZE.
   MAX_DIGITS defines maximum precision.

2. GPU shaders are NOT ideal for arbitrary precision math.
   Large values may become expensive.

3. Division is the slowest operation.

4. Avoid gigantic MAX_DIGITS values unless necessary.

5. Shader compiler behavior may vary across GPUs/drivers.

--------------------------------------------------------
RECOMMENDED STARTING VALUES
--------------------------------------------------------

MAX_DIGITS = 32
MAX_DIGITS = 64

128 may already become expensive depending on usage.

========================================================
*/


int _precision_to_limb_count(int precision) {
	if (precision <= 0) {
		return 0;
	}
	return (precision + LIMB_DIGITS - 1) / LIMB_DIGITS;
}

void _set_zero_digits(out int digits[MAX_DIGITS], out int digits_size) {
	digits[0] = 0;
	digits_size = 1;
}

void _set_zero_repr(out int repr[MAX_DIGITS], out int repr_size) {
	repr[0] = 1;
	repr[1] = 0;
	repr_size = 2;
}

int _first_nonzero_index(int digits[MAX_DIGITS], int size) {
	if (size > MAX_DIGITS) {
		size = MAX_DIGITS;
	}

	int i = 0;
	while (i < size - 1 && digits[i] == 0) {
		i += 1;
	}
	return i;
}

void _trim_copy(int src[MAX_DIGITS], int src_size, out int dst[MAX_DIGITS], out int dst_size) {
	if (src_size > MAX_DIGITS) {
		src_size = MAX_DIGITS;
	}

	if (src_size <= 0) {
		_set_zero_digits(dst, dst_size);
		return;
	}

	int start = _first_nonzero_index(src, src_size);
	dst_size = src_size - start;

	if (dst_size <= 0) {
		_set_zero_digits(dst, dst_size);
		return;
	}

	for (int i = 0; i < dst_size; i++) {
		dst[i] = src[start + i];
	}
}

int _bigint_cmp(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size) {
	if (a_size > MAX_DIGITS) {
		a_size = MAX_DIGITS;
	}
	if (b_size > MAX_DIGITS) {
		b_size = MAX_DIGITS;
	}

	int ai = _first_nonzero_index(a, a_size);
	int bi = _first_nonzero_index(b, b_size);

	int a_len = a_size - ai;
	int b_len = b_size - bi;

	if (a_len != b_len) {
		return (a_len > b_len) ? 1 : -1;
	}

	for (int i = 0; i < a_len; i++) {
		int av = a[ai + i];
		int bv = b[bi + i];
		if (av != bv) {
			return (av > bv) ? 1 : -1;
		}
	}

	return 0;
}

void _decode_repr(int packed[MAX_DIGITS], int packed_size, out int sign, out int decimal_pos, out int digits[MAX_DIGITS], out int digits_size) {
	sign = 1;
	decimal_pos = 1;
	_set_zero_digits(digits, digits_size);

	if (packed_size > MAX_DIGITS) {
		packed_size = MAX_DIGITS;
	}

	if (packed_size <= 1) {
		return;
	}

	decimal_pos = packed[0];
	sign = 1;

	digits_size = packed_size - 1;
	if (digits_size > MAX_DIGITS) {
		_set_zero_digits(digits, digits_size);
		decimal_pos = 1;
		sign = 1;
		return;
	}

	for (int i = 0; i < digits_size; i++) {
		int d = packed[i + 1];
		if (d < 0) {
			sign = -1;
			d = -d;
		}
		digits[i] = d;
	}

	if (digits_size <= 0) {
		_set_zero_digits(digits, digits_size);
		decimal_pos = 1;
		sign = 1;
	}
}

void _align_digits(int digits[MAX_DIGITS], int digits_size, int decimal_pos, int common_int, int common_frac, out int out_digits[MAX_DIGITS], out int out_size) {
	if (digits_size > MAX_DIGITS) {
		digits_size = MAX_DIGITS;
	}

	out_size = common_int + common_frac;

	if (out_size <= 0 || out_size > MAX_DIGITS) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	for (int i = 0; i < out_size; i++) {
		out_digits[i] = 0;
	}

	int left_pad = common_int - decimal_pos;
	if (left_pad < 0) {
		left_pad = 0;
	}

	for (int i = 0; i < digits_size; i++) {
		int dst_i = left_pad + i;
		if (dst_i >= 0 && dst_i < out_size) {
			out_digits[dst_i] = digits[i];
		}
	}
}

void _bigint_add(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size, out int out_digits[MAX_DIGITS], out int out_size) {
	if (a_size > MAX_DIGITS) {
		a_size = MAX_DIGITS;
	}
	if (b_size > MAX_DIGITS) {
		b_size = MAX_DIGITS;
	}

	int rev[MAX_DIGITS];
	int rev_size = 0;

	int i = a_size - 1;
	int j = b_size - 1;
	int carry = 0;

	while (i >= 0 || j >= 0 || carry > 0) {
		if (rev_size >= MAX_DIGITS) {
			_set_zero_digits(out_digits, out_size);
			return;
		}

		int da = (i >= 0) ? a[i] : 0;
		int db = (j >= 0) ? b[j] : 0;
		int s = da + db + carry;

		rev[rev_size] = s % LIMB_BASE;
		rev_size += 1;

		carry = s / LIMB_BASE;
		i -= 1;
		j -= 1;
	}

	if (rev_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	out_size = rev_size;
	for (int k = 0; k < rev_size; k++) {
		out_digits[k] = rev[rev_size - 1 - k];
	}

	int start = _first_nonzero_index(out_digits, out_size);
	int trimmed_size = out_size - start;

	if (trimmed_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	if (start > 0) {
		for (int i2 = 0; i2 < trimmed_size; i2++) {
			out_digits[i2] = out_digits[start + i2];
		}
	}
	out_size = trimmed_size;
}

void _bigint_sub(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size, out int out_digits[MAX_DIGITS], out int out_size) {
	if (a_size > MAX_DIGITS) {
		a_size = MAX_DIGITS;
	}
	if (b_size > MAX_DIGITS) {
		b_size = MAX_DIGITS;
	}

	int rev[MAX_DIGITS];
	int rev_size = 0;

	int i = a_size - 1;
	int j = b_size - 1;
	int borrow = 0;

	while (i >= 0) {
		if (rev_size >= MAX_DIGITS) {
			_set_zero_digits(out_digits, out_size);
			return;
		}

		int da = a[i];
		int db = (j >= 0) ? b[j] : 0;
		int d = da - borrow - db;

		if (d < 0) {
			d += LIMB_BASE;
			borrow = 1;
		} else {
			borrow = 0;
		}

		rev[rev_size] = d;
		rev_size += 1;

		i -= 1;
		j -= 1;
	}

	if (rev_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	out_size = rev_size;
	for (int k = 0; k < rev_size; k++) {
		out_digits[k] = rev[rev_size - 1 - k];
	}

	int start = _first_nonzero_index(out_digits, out_size);
	int trimmed_size = out_size - start;

	if (trimmed_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	if (start > 0) {
		for (int i2 = 0; i2 < trimmed_size; i2++) {
			out_digits[i2] = out_digits[start + i2];
		}
	}
	out_size = trimmed_size;
}

void _bigint_mul_small(	int a[MAX_DIGITS], int a_size, int m, out int out_digits[MAX_DIGITS], out int out_size) {
	if (a_size > MAX_DIGITS) {
		a_size = MAX_DIGITS;
	}

	if (m == 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	if (m < 0) {
		m = -m;
	}

	int rev[MAX_DIGITS];
	int rev_size = 0;

	int i = a_size - 1;
	int carry = 0;

	while (i >= 0) {
		if (rev_size >= MAX_DIGITS) {
			_set_zero_digits(out_digits, out_size);
			return;
		}

		int p = a[i] * m + carry;
		rev[rev_size] = p % LIMB_BASE;
		rev_size += 1;
		carry = p / LIMB_BASE;

		i -= 1;
	}

	while (carry > 0) {
		if (rev_size >= MAX_DIGITS) {
			_set_zero_digits(out_digits, out_size);
			return;
		}

		rev[rev_size] = carry % LIMB_BASE;
		rev_size += 1;
		carry = carry / LIMB_BASE;
	}

	if (rev_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	out_size = rev_size;
	for (int k = 0; k < rev_size; k++) {
		out_digits[k] = rev[rev_size - 1 - k];
	}

	int start = _first_nonzero_index(out_digits, out_size);
	int trimmed_size = out_size - start;

	if (trimmed_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	if (start > 0) {
		for (int i2 = 0; i2 < trimmed_size; i2++) {
			out_digits[i2] = out_digits[start + i2];
		}
	}
	out_size = trimmed_size;
}

void _bigint_mul(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size, out int out_digits[MAX_DIGITS], out int out_size) {
	if (a_size > MAX_DIGITS) {
		a_size = MAX_DIGITS;
	}
	if (b_size > MAX_DIGITS) {
		b_size = MAX_DIGITS;
	}

	int a_start = _first_nonzero_index(a, a_size);
	int b_start = _first_nonzero_index(b, b_size);

	int aa_size = a_size - a_start;
	int bb_size = b_size - b_start;

	if (aa_size <= 0 || bb_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	if (aa_size == 1 && a[a_start] == 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}
	if (bb_size == 1 && b[b_start] == 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	int res[MAX_DIGITS];
	int res_size = aa_size + bb_size;

	if (res_size > MAX_DIGITS) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	for (int i = 0; i < res_size; i++) {
		res[i] = 0;
	}

	int i = aa_size - 1;
	while (i >= 0) {
		int j = bb_size - 1;
		while (j >= 0) {
			int idx = i + j + 1;
			int s = a[a_start + i] * b[b_start + j] + res[idx];
			res[idx] = s % LIMB_BASE;
			res[idx - 1] += s / LIMB_BASE;
			j -= 1;
		}
		i -= 1;
	}

	int k = res_size - 1;
	while (k > 0) {
		if (res[k] >= LIMB_BASE) {
			res[k - 1] += res[k] / LIMB_BASE;
			res[k] = res[k] % LIMB_BASE;
		}
		k -= 1;
	}

	out_size = res_size;
	for (int i2 = 0; i2 < res_size; i2++) {
		out_digits[i2] = res[i2];
	}

	int start = _first_nonzero_index(out_digits, out_size);
	int trimmed_size = out_size - start;

	if (trimmed_size <= 0) {
		_set_zero_digits(out_digits, out_size);
		return;
	}

	if (start > 0) {
		for (int i2 = 0; i2 < trimmed_size; i2++) {
			out_digits[i2] = out_digits[start + i2];
		}
	}
	out_size = trimmed_size;
}

void _bigint_divmod(int dividend[MAX_DIGITS], int dividend_size, int divisor[MAX_DIGITS], int divisor_size, out int quotient[MAX_DIGITS], out int quotient_size, out int remainder[MAX_DIGITS], out int remainder_size) {
	if (dividend_size > MAX_DIGITS) {
		dividend_size = MAX_DIGITS;
	}
	if (divisor_size > MAX_DIGITS) {
		divisor_size = MAX_DIGITS;
	}

	int dvs_start = _first_nonzero_index(divisor, divisor_size);
	int dvs_trim_size = divisor_size - dvs_start;

	if (dvs_trim_size <= 0 || (dvs_trim_size == 1 && divisor[dvs_start] == 0)) {
		_set_zero_digits(quotient, quotient_size);
		_set_zero_digits(remainder, remainder_size);
		return;
	}

	int dvd_start = _first_nonzero_index(dividend, dividend_size);
	int dvd_trim_size = dividend_size - dvd_start;

	if (_bigint_cmp(dividend, dividend_size, divisor, divisor_size) < 0) {
		_set_zero_digits(quotient, quotient_size);
		_trim_copy(dividend, dividend_size, remainder, remainder_size);
		return;
	}

	int q[MAX_DIGITS];
	int q_size = 0;

	int r[MAX_DIGITS];
	int r_size = 1;
	r[0] = 0;

	for (int di = 0; di < dvd_trim_size; di++) {
		if (r_size == 1 && r[0] == 0) {
			r[0] = dividend[dvd_start + di];
		} else {
			if (r_size >= MAX_DIGITS) {
				_set_zero_digits(quotient, quotient_size);
				_set_zero_digits(remainder, remainder_size);
				return;
			}
			r[r_size] = dividend[dvd_start + di];
			r_size += 1;
		}

		int r_start = _first_nonzero_index(r, r_size);
		int r_trim_size = r_size - r_start;
		if (r_trim_size <= 0) {
			r[0] = 0;
			r_size = 1;
		} else if (r_start > 0) {
			for (int i2 = 0; i2 < r_trim_size; i2++) {
				r[i2] = r[r_start + i2];
			}
			r_size = r_trim_size;
		}

		int lo = 0;
		int hi = LIMB_BASE - 1;
		int qdigit = 0;

		while (lo <= hi) {
			int mid = (lo + hi) / 2;

			int prod[MAX_DIGITS];
			int prod_size = 0;
			_bigint_mul_small(divisor, divisor_size, mid, prod, prod_size);

			int cmp = _bigint_cmp(prod, prod_size, r, r_size);
			if (cmp <= 0) {
				qdigit = mid;
				lo = mid + 1;
			} else {
				hi = mid - 1;
			}
		}

		if (q_size >= MAX_DIGITS) {
			_set_zero_digits(quotient, quotient_size);
			_set_zero_digits(remainder, remainder_size);
			return;
		}

		q[q_size] = qdigit;
		q_size += 1;

		if (qdigit > 0) {
			int sub[MAX_DIGITS];
			int sub_size = 0;
			_bigint_mul_small(divisor, divisor_size, qdigit, sub, sub_size);

			int tmp[MAX_DIGITS];
			int tmp_size = 0;
			_bigint_sub(r, r_size, sub, sub_size, tmp, tmp_size);

			r_size = tmp_size;
			for (int i2 = 0; i2 < tmp_size; i2++) {
				r[i2] = tmp[i2];
			}
		}
	}

	int q_start = _first_nonzero_index(q, q_size);
	int q_trim_size = q_size - q_start;
	if (q_trim_size <= 0) {
		_set_zero_digits(quotient, quotient_size);
	} else {
		if (q_start > 0) {
			for (int i2 = 0; i2 < q_trim_size; i2++) {
				q[i2] = q[q_start + i2];
			}
		}
		quotient_size = q_trim_size;
		for (int i2 = 0; i2 < q_trim_size; i2++) {
			quotient[i2] = q[i2];
		}
	}

	int r_start2 = _first_nonzero_index(r, r_size);
	int r_trim_size2 = r_size - r_start2;
	if (r_trim_size2 <= 0) {
		_set_zero_digits(remainder, remainder_size);
	} else {
		if (r_start2 > 0) {
			for (int i2 = 0; i2 < r_trim_size2; i2++) {
				r[i2] = r[r_start2 + i2];
			}
		}
		remainder_size = r_trim_size2;
		for (int i2 = 0; i2 < r_trim_size2; i2++) {
			remainder[i2] = r[i2];
		}
	}
}

void _copy_and_pad_right(int src[MAX_DIGITS], int src_size, int pad, out int dst[MAX_DIGITS], out int dst_size) {
	if (src_size > MAX_DIGITS) {
		src_size = MAX_DIGITS;
	}
	if (pad < 0) {
		pad = 0;
	}

	dst_size = src_size + pad;

	if (dst_size <= 0 || dst_size > MAX_DIGITS) {
		_set_zero_digits(dst, dst_size);
		return;
	}

	for (int i = 0; i < dst_size; i++) {
		dst[i] = 0;
	}

	for (int i = 0; i < src_size; i++) {
		dst[i] = src[i];
	}
}

void _integer_digits_to_repr(int digits[MAX_DIGITS], int digits_size, int frac_count, int sign, out int repr[MAX_DIGITS], out int repr_size) {
	if (digits_size > MAX_DIGITS) {
		digits_size = MAX_DIGITS;
	}

	int src[MAX_DIGITS];
	int src_size = 0;
	_trim_copy(digits, digits_size, src, src_size);

	if (src_size == 1 && src[0] == 0) {
		_set_zero_repr(repr, repr_size);
		return;
	}

	int out_digits[MAX_DIGITS];
	int out_size = 0;
	int decimal_pos = 1;

	if (src_size <= frac_count) {
		int pad = frac_count + 1 - src_size;
		out_size = src_size + pad;

		if (out_size > MAX_DIGITS) {
			_set_zero_repr(repr, repr_size);
			return;
		}

		for (int i = 0; i < pad; i++) {
			out_digits[i] = 0;
		}
		for (int i = 0; i < src_size; i++) {
			out_digits[pad + i] = src[i];
		}
		decimal_pos = 1;
	} else {
		out_size = src_size;
		if (out_size > MAX_DIGITS) {
			_set_zero_repr(repr, repr_size);
			return;
		}
		for (int i = 0; i < src_size; i++) {
			out_digits[i] = src[i];
		}
		decimal_pos = src_size - frac_count;
	}

	while (out_size > 1 && decimal_pos > 1 && out_digits[0] == 0) {
		for (int i = 0; i < out_size - 1; i++) {
			out_digits[i] = out_digits[i + 1];
		}
		out_size -= 1;
		decimal_pos -= 1;
	}

	while (out_size > decimal_pos && out_digits[out_size - 1] == 0) {
		out_size -= 1;
	}

	int all_zero = 1;
	for (int i = 0; i < out_size; i++) {
		if (out_digits[i] != 0) {
			all_zero = 0;
			break;
		}
	}

	if (all_zero == 1) {
		_set_zero_repr(repr, repr_size);
		return;
	}

	if (sign < 0) {
		for (int i = 0; i < out_size; i++) {
			if (out_digits[i] != 0) {
				out_digits[i] = -out_digits[i];
				break;
			}
		}
	}

	if (out_size + 1 > MAX_DIGITS) {
		_set_zero_repr(repr, repr_size);
		return;
	}

	repr[0] = decimal_pos;
	for (int i = 0; i < out_size; i++) {
		repr[i + 1] = out_digits[i];
	}
	repr_size = out_size + 1;
}

void _negate_repr(int packed[MAX_DIGITS], int packed_size, out int out_packed[MAX_DIGITS], out int out_size) {
	if (packed_size > MAX_DIGITS) {
		packed_size = MAX_DIGITS;
	}

	if (packed_size <= 0) {
		_set_zero_repr(out_packed, out_size);
		return;
	}

	out_size = packed_size;
	out_packed[0] = packed[0];

	for (int i = 1; i < packed_size; i++) {
		out_packed[i] = packed[i];
	}

	for (int i = 1; i < out_size; i++) {
		int d = out_packed[i];
		if (d != 0) {
			out_packed[i] = -d;
			break;
		}
	}
}

void float_repr_add(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size, out int out_repr[MAX_DIGITS], out int out_repr_size) {
	int a_sign;
	int a_dec;
	int a_digits[MAX_DIGITS];
	int a_digits_size;
	_decode_repr(a, a_size, a_sign, a_dec, a_digits, a_digits_size);

	int b_sign;
	int b_dec;
	int b_digits[MAX_DIGITS];
	int b_digits_size;
	_decode_repr(b, b_size, b_sign, b_dec, b_digits, b_digits_size);

	int a_int = a_dec;
	int b_int = b_dec;

	int a_frac = a_digits_size - a_int;
	int b_frac = b_digits_size - b_int;

	int common_int = (a_int > b_int) ? a_int : b_int;
	int common_frac = (a_frac > b_frac) ? a_frac : b_frac;

	int a_al[MAX_DIGITS];
	int a_al_size = 0;
	_align_digits(a_digits, a_digits_size, a_int, common_int, common_frac, a_al, a_al_size);

	int b_al[MAX_DIGITS];
	int b_al_size = 0;
	_align_digits(b_digits, b_digits_size, b_int, common_int, common_frac, b_al, b_al_size);

	int result_digits[MAX_DIGITS];
	int result_digits_size = 0;
	int result_sign = 1;

	if (a_sign == b_sign) {
		result_sign = a_sign;
		_bigint_add(a_al, a_al_size, b_al, b_al_size, result_digits, result_digits_size);
	} else {
		int cmp = _bigint_cmp(a_al, a_al_size, b_al, b_al_size);

		if (cmp == 0) {
			_set_zero_repr(out_repr, out_repr_size);
			return;
		}

		if (cmp > 0) {
			result_sign = a_sign;
			_bigint_sub(a_al, a_al_size, b_al, b_al_size, result_digits, result_digits_size);
		} else {
			result_sign = b_sign;
			_bigint_sub(b_al, b_al_size, a_al, a_al_size, result_digits, result_digits_size);
		}
	}

	_integer_digits_to_repr(result_digits, result_digits_size, common_frac, result_sign, out_repr, out_repr_size);
}

void float_repr_sub(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size, out int out_repr[MAX_DIGITS], out int out_repr_size) {
	int neg_b[MAX_DIGITS];
	int neg_b_size = 0;
	_negate_repr(b, b_size, neg_b, neg_b_size);
	float_repr_add(a, a_size, neg_b, neg_b_size, out_repr, out_repr_size);
}

void float_repr_mul(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size, out int out_repr[MAX_DIGITS], out int out_repr_size) {
	int a_sign;
	int a_dec;
	int a_digits[MAX_DIGITS];
	int a_digits_size;
	_decode_repr(a, a_size, a_sign, a_dec, a_digits, a_digits_size);

	int b_sign;
	int b_dec;
	int b_digits[MAX_DIGITS];
	int b_digits_size;
	_decode_repr(b, b_size, b_sign, b_dec, b_digits, b_digits_size);

	int sign = a_sign * b_sign;
	int a_frac = a_digits_size - a_dec;
	int b_frac = b_digits_size - b_dec;
	int total_frac = a_frac + b_frac;

	int product[MAX_DIGITS];
	int product_size = 0;
	_bigint_mul(a_digits, a_digits_size, b_digits, b_digits_size, product, product_size);

	_integer_digits_to_repr(product, product_size, total_frac, sign, out_repr, out_repr_size);
}

void float_repr_div(int a[MAX_DIGITS], int a_size, int b[MAX_DIGITS], int b_size, int precision, out int out_repr[MAX_DIGITS], out int out_repr_size) {
	int a_sign;
	int a_dec;
	int a_digits[MAX_DIGITS];
	int a_digits_size;
	_decode_repr(a, a_size, a_sign, a_dec, a_digits, a_digits_size);

	int b_sign;
	int b_dec;
	int b_digits[MAX_DIGITS];
	int b_digits_size;
	_decode_repr(b, b_size, b_sign, b_dec, b_digits, b_digits_size);

	if (b_digits_size == 1 && b_digits[0] == 0) {
		_set_zero_repr(out_repr, out_repr_size);
		return;
	}

	int sign = a_sign * b_sign;

	int a_frac = a_digits_size - a_dec;
	int b_frac = b_digits_size - b_dec;

	int precision_limbs = _precision_to_limb_count(precision);

	int dividend[MAX_DIGITS];
	int dividend_size = 0;
	_copy_and_pad_right(a_digits, a_digits_size, b_frac + precision_limbs, dividend, dividend_size);

	int divisor[MAX_DIGITS];
	int divisor_size = 0;
	_copy_and_pad_right(b_digits, b_digits_size, a_frac, divisor, divisor_size);

	int q[MAX_DIGITS];
	int q_size = 0;
	int r[MAX_DIGITS];
	int r_size = 0;
	_bigint_divmod(dividend, dividend_size, divisor, divisor_size, q, q_size, r, r_size);

	_integer_digits_to_repr(q, q_size, precision_limbs, sign, out_repr, out_repr_size);
}

float _repr_to_float(int packed[MAX_DIGITS], int packed_size) {
	int sign;
	int decimal_pos;
	int digits[MAX_DIGITS];
	int digits_size;

	_decode_repr(packed, packed_size, sign, decimal_pos, digits, digits_size);

	float value = 0.0;

	for (int i = 0; i < digits_size; i++) {
		int expv = decimal_pos - i - 1;
		float digit = float(digits[i]);

		if (expv >= 0) {
			value += digit * pow(float(LIMB_BASE), float(expv));
		} else {
			value += digit / pow(float(LIMB_BASE), float(-expv));
		}
	}

	return value * float(sign);
}

void _float_to_repr(float value, int precision, out int repr[MAX_DIGITS], out int repr_size) {
	if (precision < 0) {
		precision = 0;
	}

	if (precision > MAX_DIGITS - 2) {
		precision = MAX_DIGITS - 2;
	}

	int sign = 1;

	if (value < 0.0) {
		sign = -1;
		value = -value;
	}

	int int_part = int(floor(value));
	float frac_part = value - float(int_part);

	int int_digits[MAX_DIGITS];
	int int_digits_size = 0;

	if (int_part == 0) {
		int_digits[0] = 0;
		int_digits_size = 1;
	} else {
		int rev[MAX_DIGITS];
		int rev_size = 0;

		while (int_part > 0 && rev_size < MAX_DIGITS) {
			rev[rev_size] = int_part % LIMB_BASE;
			rev_size += 1;
			int_part /= LIMB_BASE;
		}

		int_digits_size = rev_size;

		for (int i = 0; i < rev_size; i++) {
			int_digits[i] = rev[rev_size - i - 1];
		}
	}

	int digits[MAX_DIGITS];
	int digits_size = 0;

	for (int i = 0; i < int_digits_size; i++) {
		digits[digits_size] = int_digits[i];
		digits_size += 1;
	}

	int limb_precision = _precision_to_limb_count(precision);

	for (int i = 0; i < limb_precision; i++) {
		frac_part *= float(LIMB_BASE);

		int d = int(floor(frac_part));

		digits[digits_size] = d;
		digits_size += 1;

		frac_part -= float(d);
	}

	int first_nonzero = -1;

	for (int i = 0; i < digits_size; i++) {
		if (digits[i] != 0) {
			first_nonzero = i;
			break;
		}
	}

	if (first_nonzero == -1) {
		_set_zero_repr(repr, repr_size);
		return;
	}

	if (sign < 0) {
		digits[first_nonzero] = -digits[first_nonzero];
	}

	repr[0] = int_digits_size;

	for (int i = 0; i < digits_size; i++) {
		repr[i + 1] = digits[i];
	}

	repr_size = digits_size + 1;
}

void float_repr_limit_precision(int packed[MAX_DIGITS], int packed_size, int precision, out int out_repr[MAX_DIGITS], out int out_size) {
	if (packed_size > MAX_DIGITS) {
		packed_size = MAX_DIGITS;
	}

	if (packed_size <= 1) {
		_set_zero_repr(out_repr, out_size);
		return;
	}

	int decimal_pos = packed[0];
	int max_size = decimal_pos + _precision_to_limb_count(precision) + 1;

	if (max_size < 2) {
		max_size = 2;
	}
	if (max_size > MAX_DIGITS) {
		max_size = MAX_DIGITS;
	}

	out_size = (packed_size < max_size) ? packed_size : max_size;

	for (int i = 0; i < out_size; i++) {
		out_repr[i] = packed[i];
	}

	while (out_size > 2 && out_size > decimal_pos + 1 && out_repr[out_size - 1] == 0) {
		out_size -= 1;
	}

	int all_zero = 1;
	for (int i = 1; i < out_size; i++) {
		if (out_repr[i] != 0) {
			all_zero = 0;
			break;
		}
	}

	if (all_zero == 1) {
		_set_zero_repr(out_repr, out_size);
	}
}

/*
==================
FRACTAL FUNCTIONS
=================
*/

void transform_coordinate_system(vec2 uv, out int x[MAX_DIGITS], out int x_size, out int y[MAX_DIGITS], out int y_size) {
    uv.y = 1.0 - uv.y;
    uv = uv - 0.5;

    int uvx[MAX_DIGITS];
    int uvx_size = 0;
    _float_to_repr(uv.x, digits_precision, uvx, uvx_size);

    int uvy[MAX_DIGITS];
    int uvy_size = 0;
    _float_to_repr(uv.y, digits_precision, uvy, uvy_size);

	int tmp[MAX_DIGITS];
	int tmp_size = 0;
	
	int limited[MAX_DIGITS];
	int limited_size = 0;

    float_repr_mul(box_size, box_size_size, uvx, uvx_size, tmp, tmp_size);
    float_repr_add(ex, ex_size, tmp, tmp_size, limited, limited_size);
	float_repr_limit_precision(limited, limited_size, digits_precision, x, x_size);

    float_repr_mul(box_size, box_size_size, uvy, uvy_size, tmp, tmp_size);
    float_repr_add(ey, ey_size, tmp, tmp_size, limited, limited_size);
	float_repr_limit_precision(limited, limited_size, digits_precision, y, y_size);
}

vec3 palette(int i) {
	float t = float(i) / float(max_iter);

	// Corta exterior completamente.
	if (i < int(0.01 * float(max_iter))) {
		return vec3(0.0);
	}

	// Remapeia só a região interessante.
	t = (t - 0.1) / 0.8;

	// Melhora contraste perto da borda.
	t = pow(t, 0.2);

	// Paleta com cores distintas.
	return 0.5 + colors * cos(2.0 * colors * TAU * (t + vec3(0.0, 0.25, 0.5)));
}

vec4 compute_iteration(int x[MAX_DIGITS], int x_size, int y[MAX_DIGITS], int y_size) {
	int zx[MAX_DIGITS];
	int zx_size = 0;
	_set_zero_repr(zx, zx_size);

	int zy[MAX_DIGITS];
	int zy_size = 0;
	_set_zero_repr(zy, zy_size);

	int mag2[MAX_DIGITS];
	int mag2_size = 0;

	int zx2[MAX_DIGITS];
	int zx2_size = 0;

	int zy2[MAX_DIGITS];
	int zy2_size = 0;

	int diff[MAX_DIGITS];
	int diff_size = 0;
	
	int tmp[MAX_DIGITS];
	int tmp_size = 0;

	int twice[MAX_DIGITS];
	int twice_size = 0;

	int zx_old[MAX_DIGITS];
	int zx_old_size = 0;

	for (int i = 0; i < max_iter; i++) {
		zx_old_size = zx_size;
		for (int k = 0; k < zx_size; k++) {
			zx_old[k] = zx[k];
		}

		// |z|^2 = zx^2 + zy^2
		float_repr_mul(zx, zx_size, zx, zx_size, zx2, zx2_size);
		float_repr_mul(zy, zy_size, zy, zy_size, zy2, zy2_size);
		float_repr_add(zx2, zx2_size, zy2, zy2_size, mag2, mag2_size);

		if (_repr_to_float(mag2, mag2_size) > 4.0) {
			return vec4(palette(i), 1.0);
		}

		// zx' = zx^2 - zy^2 + cx
		float_repr_sub(zx2, zx2_size, zy2, zy2_size, diff, diff_size);
		float_repr_add(diff, diff_size, x, x_size, tmp, tmp_size);
		float_repr_limit_precision(tmp, tmp_size, digits_precision, zx, zx_size);

		// zy' = 2 * old_zx * zy + cy
		float_repr_mul(zx_old, zx_old_size, zy, zy_size, diff, diff_size);
		float_repr_add(diff, diff_size, diff, diff_size, twice, twice_size);
		float_repr_add(twice, twice_size, y, y_size, tmp, tmp_size);
		float_repr_limit_precision(tmp, tmp_size, digits_precision, zy, zy_size);
	}

	return vec4(1.0, 1.0, 1.0, 1.0);
}

void fragment() {
    vec2 uv = UV;
	vec2 pixel = floor(uv * viewport_size);
	
	if (pixel.x < tile_origin.x || pixel.y < tile_origin.y || pixel.x >= tile_origin.x + tile_size.x || pixel.y >= tile_origin.y + tile_size.y) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
	else{
		int x[MAX_DIGITS];
		int x_size = 0;

		int y[MAX_DIGITS];
		int y_size = 0;

		transform_coordinate_system(uv, x, x_size, y, y_size);
		
		COLOR = compute_iteration(x, x_size, y, y_size);
	}
}
