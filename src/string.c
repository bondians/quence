#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "string.h"

int verbosity = 0;

const char specials[256] = {
	['b'] '\b',
	['t'] '\t',
	['r'] '\r',
	['n'] '\n'
};

const char _Oct[256] = {
	['0'] 1,
	['1'] 1,
	['2'] 1,
	['3'] 1,
	['4'] 1,
	['5'] 1,
	['6'] 1,
	['7'] 1
};

#define specialize(chr)		if (specials[(unsigned char) chr]) {chr = specials[(unsigned char) chr];}
#define isOctal(chr)		(_Oct[(unsigned char) chr])

char *cpstring(char *src) {
	int size = strlen(src);
	char *copy;

	copy = (char *) malloc(size + 1);

	strcpy(copy, src);

	return copy;
}

char *catstring(char *src1, char *src2) {
	int s1 = strlen(src1);
	int s2 = strlen(src2);
	int size = s1 + s2;

	char *copy;

	copy = (char *) realloc(src1, size + 1);
	strcpy(copy + s1, src2);

	return copy;
}

char *unescape(char *text) {
	int idx = 0, drops = 0;

	while (text[idx + drops]) {
		if (text[idx + drops] == '\\') {
			drops++;

				// Handle special escapes, eg '\n'
			specialize(text[idx + drops]);

				// Handle Octal escapes
			if ((text[idx + drops] == '0') || (text[idx + drops] == '1')) {
				char octbuf[4] = {0, 0, 0, 0};
				int ob_idx = 0;

				octbuf[ob_idx++] = text[idx + drops];

				while ((ob_idx < 3) && isOctal(text[idx + drops + 1])) {
					octbuf[ob_idx] = text[idx + drops + 1];
					ob_idx++;
					drops++;
				}

				text[idx + drops] = atoi_oct(octbuf);
			}
		}

		if (drops) {
			text[idx] = text[idx + drops];
		}

		idx++;
	}

	text[idx] = '\0';

	return text;
}

/* unquote - Like unescape, but also implicitly drop the first and last chars */
char *unquote(char *text) {
	int idx = 0, drops = 1;

	while (text[idx + drops]) {
		if (text[idx + drops] == '\\') {
			drops++;

			specialize(text[idx + drops]);

				// Handle Octal escapes
			if ((text[idx + drops] == '0') || (text[idx + drops] == '1')) {
				char octbuf[4] = {0, 0, 0, 0};
				int ob_idx = 0;

				octbuf[ob_idx++] = text[idx + drops];

				while ((ob_idx < 3) && isOctal(text[idx + drops + 1])) {
					octbuf[ob_idx] = text[idx + drops + 1];
					ob_idx++;
					drops++;
				}

				text[idx + drops] = atoi_oct(octbuf);
			}
		}

		if (drops) {
			text[idx] = text[idx + drops];
		}

		idx++;
	}

	text[idx - 1] = '\0';

	return text;
}


int count_endlines(char *text) {
	int lines = 0;

	while (*text) {
		if ((*text == '\n') || (*text == '\r'))
			lines++;

		text++;
	}

	return lines;
}

int atoi_bin(char *text) {
	int i = 0;

	if (*text == '%')
		text++;

	while ((*text == '0') || (*text == '1')) {
		i <<= 1;
		i += (*text - '0');
		text++;
	}

	return i;
}

int atoi_oct(char *text) {
	int i = 0;
	int digit = 0;

	if (*text == '\\')
		text++;

	for(digit = *text - '0'; (digit >= 0) && (digit <= 7); text++, digit = *text - '0') {
		i <<= 3;
		i += digit;
	}

	return i;
}

int atoi_hex(char *text) {
	int i = 0;
	int digit = 0;

	if ((*text == '0') && (tolower(text[1]) == 'x'))
		text += 2;
	else if (*text == '$')
		text += 1;

	if (isalpha(*text)) {
		*text = tolower(*text);
		*text -= 'a';
		*text += '0' + 10;
	}

	digit = *text - '0';

	while ((digit >= 0) && (digit <= 15)) {
		i <<= 4;
		i += digit;

		text++;
		if (isalpha(*text)) {
			*text = tolower(*text);
			*text -= 'a';
			*text += '0' + 10;
		}

		digit = *text - '0';
	}

	return i;
}

int atoi_char(char *text) {
	text = unquote(text);

	return text[0];
}

int atoi_wchar(char *text) {
	text = unquote(text);

	return (text[0] << 8) | text[1];
}

char *change_ext(char *file, char *ext) {
	int last_dot = -1;
	int idx;
	int ext_len = strlen(ext);
	int m_sz;

	char *new_name;

	for (idx = 0; file[idx]; idx++) {
		if (file[idx] == '.')
			last_dot = idx;
	}

	if (last_dot < 0)
		last_dot = idx;

	m_sz = last_dot + 1 + ext_len + 1;
	new_name = (char *) malloc(m_sz);

	for (idx = 0; idx < last_dot; idx++) {
		new_name[idx] = file[idx];
	}

	if (ext_len) new_name[idx] = '.';
		else	new_name[idx] = 0;

	for (idx = 0; idx < ext_len; idx++) {
		new_name[last_dot + 1 + idx] = ext[idx];
	}

	new_name[last_dot + 1 + idx] = 0;

	return new_name;
}

char *bprintf(char *fmt, ...) {
	va_list args;
	char *string;

	va_start(args, fmt);

	#ifdef __MINGW32_VERSION
	string = malloc(256);
	vsprintf(string, fmt, args);
	#else
	vasprintf(&string, fmt, args);
	#endif

	va_end(args);
	return string;
}

void eprintf(char *fmt, ...) {
	va_list args;
	va_start(args, fmt);

	if (verbosity >= 0)
		vfprintf(stderr, fmt, args);

	va_end(args);
}

void d_printf(int lvl, char *fmt, ...) {
	va_list args;
	va_start(args, fmt);

	if (verbosity >= lvl)
		vfprintf(stderr, fmt, args);

	va_end(args);
}
