/*
   Copyright 2009 Kevin Ryde

   This file is part of File-Locate-Iterator.

   File-Locate-Iterator is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as published
   by the Free Software Foundation; either version 3, or (at your option)
   any later version.

   File-Locate-Iterator is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
   Public License for more details.

   You should have received a copy of the GNU General Public License along
   with File-Locate-Iterator.  If not, see <http://www.gnu.org/licenses/>. */

#include <fnmatch.h>
#include <stdlib.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define DEBUG 0

#define GET_FIELD(var,name)                             \
  do {                                                  \
    field = (name);                                     \
    svp = hv_fetch (h, field, strlen(field), 0);        \
    if (! svp) goto FIELD_MISSING;                      \
    (var) = *svp;                                       \
  } while (0)

#if DEBUG >= 1
#define DEBUG1(code) do { code; } while (0)
#else
#define DEBUG1(code)
#endif
#if DEBUG >= 2
#define DEBUG2(code) do { code; } while (0)
#else
#define DEBUG2(code)
#endif

#define MATCH(target)                                                   \
  do {                                                                  \
      if (regexp) {                                                     \
        if (CALLREGEXEC (regexp,                                        \
                         entry_p, entry_p + entry_len,                  \
                         entry_p, 0, entry, NULL,                       \
                         REXEC_IGNOREPOS)) {                            \
          goto target;                                                  \
        }                                                               \
        DEBUG1 (printf ("  no match regexp\n"));                        \
      } else {                                                          \
        if (! globs_ptr) {                                              \
          DEBUG1 (printf ("  no regexp or globs, so match\n"));         \
          goto target;                                                  \
        }                                                               \
      }                                                                 \
      if (globs_ptr) {                                                  \
        SSize_t i;                                                      \
        for (i = 0; i <= globs_end; i++) {                              \
          DEBUG2 (printf ("  fnmatch \"%s\" entry \"%s\"\n",            \
                          SvPV_nolen(globs_ptr[i]), entry_p));          \
          if (fnmatch (SvPV_nolen(globs_ptr[i]), entry_p, 0) == 0)      \
            goto target;                                                \
        }                                                               \
        DEBUG1 (printf ("  no match globs\n"));                         \
      }                                                                 \
      DEBUG1 (printf ("  no match\n"));                                 \
    } while (0)

MODULE = File::Locate::Iterator   PACKAGE = File::Locate::Iterator

void
next (SV *self)
PROTOTYPE:
CODE:
  {
    HV *h;
    SV **svp, *entry, *sharelen_sv;
    SV **globs_ptr = NULL;
    SSize_t globs_end;
    REGEXP *regexp = NULL;
    const char *field;
    char *entry_p;
    STRLEN entry_len;
    IV sharelen, adj;
    int at_eof = 0;

    goto START;
    {
    FIELD_MISSING:
      croak ("oops, missing '%s'", field);
    }

  START:
    h = (HV*) SvRV(self);

    GET_FIELD (entry, "entry");

    GET_FIELD (sharelen_sv, "sharelen");
    sharelen = SvIV (sharelen_sv);

    {
      SV **regexp_svp = hv_fetch (h, "regexp", 6, 0);
      if (regexp_svp) {
        regexp = SvRX(*regexp_svp);
        if (! regexp) croak ("'regexp' not a regexp");
      }
      DEBUG1 (printf ("regexp %p\n", regexp));
    }

    {
      SV **globs_svp = hv_fetch (h, "globs", 5, 0);
      if (globs_svp) {
        SV *globs_sv = *globs_svp;
        if (! SvROK (globs_sv))
          croak ("oops, 'globs' not a reference");
        AV *globs_av = (AV*) SvRV(globs_sv);
        if (SvTYPE(globs_av) != SVt_PVAV)
          croak ("oops, 'globs' not an arrayref");
        globs_ptr = AvARRAY (globs_av);
        globs_end = av_len (globs_av);
      }
      DEBUG1 (printf ("globs_svp %p globs_ptr %p globs_end %d\n",
                      globs_svp, globs_ptr, globs_end));
    }

    svp = hv_fetch (h, "mref", 4, 0);
    if (svp) {
      SV *mref, *mmap, *pos_sv;
      mref = *svp;
      char *mp, *gets_beg, *gets_end;
      STRLEN mlen;
      UV pos;

      mmap = (SV*) SvRV(mref);
      mp = SvPV (mmap, mlen);

      GET_FIELD (pos_sv, "pos");
      pos = SvUV(pos_sv);
      DEBUG2 (printf ("mmap %p mlen %u, pos %u\n", mp, mlen));

      for (;;) {
        DEBUG2 (printf ("MREF_LOOP\n"));
        if (pos >= mlen) {
          /* EOF */
          at_eof = 1;
          break;
        }
        adj = ((I8*)mp)[pos++];

        if (adj == -128) {
          DEBUG1 (printf ("two-byte adj at pos=%lu\n", pos));
          if (pos >= mlen-1) goto UNEXPECTED_EOF;
          adj = (I16) ((((U16) ((U8*)mp)[pos]) << 8)
                       + ((U8*)mp)[pos+1]);
          pos += 2;
        }
        DEBUG1 (printf ("adj %ld at pos=%lu\n", adj, pos));
        
        sharelen += adj;
        if (sharelen < 0 || sharelen > SvCUR(entry)) {
          sv_setpv (entry, NULL);
          croak ("Invalid database contents (bad share length %d)", sharelen);
        }
        DEBUG1 (printf ("sharelen %ld\n", sharelen));
        
        if (pos >= mlen) goto UNEXPECTED_EOF;
        gets_beg = mp + pos;
        gets_end = memchr (gets_beg, '\0', mlen-pos);
        if (! gets_end) {
          DEBUG1 (printf ("NUL not found gets_beg=%p len=%lu\n",
                          gets_beg, mlen-pos));
          goto UNEXPECTED_EOF;
        }
        
        SvCUR_set (entry, sharelen);
        sv_catpvn (entry, gets_beg, gets_end - gets_beg);
        pos = gets_end + 1 - mp;
        
        entry_p = SvPV(entry, entry_len);

        MATCH(MREF_LOOP_END);
      }
    MREF_LOOP_END:
      SvUV_set (pos_sv, pos);

    } else {
      SV *fh;
      PerlIO *fp;
      int got, adj;
      union {
        char buf[2];
        U16 u16;
      } adj_u;
      char *gets_ret;

      GET_FIELD (fh, "fh");
      fp = IoIFP(sv_2io(fh));
      DEBUG2(printf ("fp=%p fh=\n", fp); sv_dump (fh));

      /* $/ = "\0" */
      save_item (PL_rs);
      sv_setpvn (PL_rs, "\0", 1);

      for (;;) {
        DEBUG2 (printf ("IO_LOOP\n"));
        got = PerlIO_read (fp, adj_u.buf, 1);
        if (got == 0) {
          /* EOF */
          at_eof = 1;
          break;
        }
        if (got != 1) {
        READ_ERROR:
          DEBUG1 (printf ("read fp=%p got=%d\n", fp, got));
          if (got < 0) {
            croak ("Error reading database");
          } else {
          UNEXPECTED_EOF:
            croak ("Invalid database contents (unexpected EOF)");
          }
        }

        adj = (I8) adj_u.buf[0];
        if (adj == -128) {
          DEBUG1 (printf ("two-byte adj\n"));
          got = PerlIO_read (fp, adj_u.buf, 2);
          if (got != 2) goto READ_ERROR;
          DEBUG1 (printf ("raw %X,%X %X ntohs %X\n",
                  (int) (U8) adj_u.buf[0], (int) (U8) adj_u.buf[1],
                          adj_u.u16, ntohs(adj_u.u16)));
          adj = (int) (I16) ntohs(adj_u.u16);
        }
        DEBUG1 (printf ("adj %d %#x\n", adj, adj));

        sharelen += adj;
        DEBUG1 (printf ("sharelen %u %#x\n", sharelen, sharelen));

        if (sharelen < 0 || sharelen > SvCUR(entry)) {
          sv_setpv (entry, NULL);
          croak ("Invalid database contents (bad share length %d)", sharelen);
        }

        gets_ret = sv_gets (entry, fp, sharelen);
        if (gets_ret == NULL) goto UNEXPECTED_EOF;
        DEBUG2 (printf ("entry gets to %u, chomp to %u, fpos now %lu(%#x)\n",
                        SvCUR(entry), SvCUR(entry) - 1,
                        (unsigned long) PerlIO_tell(fp),
                        (unsigned long) PerlIO_tell(fp));
                printf ("entry gets to %u, chomp to %u\n",
                        SvCUR(entry), SvCUR(entry) - 1));

        entry_p = SvPV(entry, entry_len);
        if (entry_len < 1 || entry_p[entry_len-1] != '\0') {
          DEBUG1 (printf ("no NUL from sv_gets\n"));
          goto UNEXPECTED_EOF;
        }
        entry_len--;
        SvCUR_set (entry, entry_len); /* chomp \0 terminator */

        MATCH(IO_LOOP_END);
      }
    IO_LOOP_END:
      ;
    }
    if (at_eof) {
      sv_setpv (entry, NULL);
      DEBUG2 (printf ("eof\n  entry=\n"); sv_dump (entry); printf ("\n"));
      XSRETURN(0);

    } else {
      SvUV_set (sharelen_sv, sharelen);
      DEBUG2 (printf ("return entry=\n"); sv_dump (entry); printf ("\n"));

      SvREFCNT_inc_simple_void (entry);
      ST(0) = sv_2mortal(entry);
      XSRETURN(1);
    }
  }
