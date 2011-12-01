#ifndef __string_h__
#define __string_h__


char *cpstring(char *src);
char *catstring(char *src1, char *src2);

char *unescape(char *text);
char *unquote(char *text);

int count_endlines(char *text);

int atoi_bin(char *text);
int atoi_oct(char *text);
int atoi_hex(char *text);

int atoi_char(char *text);
int atoi_wchar(char *text);

char *change_ext(char *file, char *ext);

/* printf into a new buffer and return the buffer - buffer must be free()d */
char *bprintf(char *fmt, ...);

/* printf to stderr */
void eprintf(char *fmt, ...);

/* printf to stderr if verbosity >= lvl */
void d_printf(int lvl, char *fmt, ...);

extern int verbosity;

#endif /* __string_h__ */
