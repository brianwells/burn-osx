/* A Bison parser, made by GNU Bison 1.875d.  */

/* Skeleton parser for Yacc-like parsing with Bison,
   Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.  */

/* As a special exception, when this file is copied by Bison into a
   Bison output file, you may use that output file without restriction.
   This special exception was added by the Free Software Foundation
   in version 1.24 of Bison.  */

/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     NUM_TOK = 258,
     G_TOK = 259,
     S_TOK = 260,
     ID_TOK = 261,
     ANGLE_TOK = 262,
     AUDIO_TOK = 263,
     BUTTON_TOK = 264,
     CALL_TOK = 265,
     CELL_TOK = 266,
     CHAPTER_TOK = 267,
     CLOSEBRACE_TOK = 268,
     CLOSEPAREN_TOK = 269,
     ELSE_TOK = 270,
     ENTRY_TOK = 271,
     EXIT_TOK = 272,
     FPC_TOK = 273,
     IF_TOK = 274,
     JUMP_TOK = 275,
     MENU_TOK = 276,
     OPENBRACE_TOK = 277,
     OPENPAREN_TOK = 278,
     PROGRAM_TOK = 279,
     PTT_TOK = 280,
     RESUME_TOK = 281,
     ROOT_TOK = 282,
     SET_TOK = 283,
     SUBTITLE_TOK = 284,
     TITLE_TOK = 285,
     TITLESET_TOK = 286,
     VMGM_TOK = 287,
     BOR_TOK = 288,
     LOR_TOK = 289,
     XOR_TOK = 290,
     _OR_TOK = 291,
     BAND_TOK = 292,
     LAND_TOK = 293,
     _AND_TOK = 294,
     NOT_TOK = 295,
     NE_TOK = 296,
     EQ_TOK = 297,
     LT_TOK = 298,
     LE_TOK = 299,
     GT_TOK = 300,
     GE_TOK = 301,
     SUB_TOK = 302,
     ADD_TOK = 303,
     MOD_TOK = 304,
     DIV_TOK = 305,
     MUL_TOK = 306,
     ADDSET_TOK = 307,
     SUBSET_TOK = 308,
     MULSET_TOK = 309,
     DIVSET_TOK = 310,
     MODSET_TOK = 311,
     ANDSET_TOK = 312,
     ORSET_TOK = 313,
     XORSET_TOK = 314,
     SEMICOLON_TOK = 315,
     ERROR_TOK = 316
   };
#endif
#define NUM_TOK 258
#define G_TOK 259
#define S_TOK 260
#define ID_TOK 261
#define ANGLE_TOK 262
#define AUDIO_TOK 263
#define BUTTON_TOK 264
#define CALL_TOK 265
#define CELL_TOK 266
#define CHAPTER_TOK 267
#define CLOSEBRACE_TOK 268
#define CLOSEPAREN_TOK 269
#define ELSE_TOK 270
#define ENTRY_TOK 271
#define EXIT_TOK 272
#define FPC_TOK 273
#define IF_TOK 274
#define JUMP_TOK 275
#define MENU_TOK 276
#define OPENBRACE_TOK 277
#define OPENPAREN_TOK 278
#define PROGRAM_TOK 279
#define PTT_TOK 280
#define RESUME_TOK 281
#define ROOT_TOK 282
#define SET_TOK 283
#define SUBTITLE_TOK 284
#define TITLE_TOK 285
#define TITLESET_TOK 286
#define VMGM_TOK 287
#define BOR_TOK 288
#define LOR_TOK 289
#define XOR_TOK 290
#define _OR_TOK 291
#define BAND_TOK 292
#define LAND_TOK 293
#define _AND_TOK 294
#define NOT_TOK 295
#define NE_TOK 296
#define EQ_TOK 297
#define LT_TOK 298
#define LE_TOK 299
#define GT_TOK 300
#define GE_TOK 301
#define SUB_TOK 302
#define ADD_TOK 303
#define MOD_TOK 304
#define DIV_TOK 305
#define MUL_TOK 306
#define ADDSET_TOK 307
#define SUBSET_TOK 308
#define MULSET_TOK 309
#define DIVSET_TOK 310
#define MODSET_TOK 311
#define ANDSET_TOK 312
#define ORSET_TOK 313
#define XORSET_TOK 314
#define SEMICOLON_TOK 315
#define ERROR_TOK 316




#if ! defined (YYSTYPE) && ! defined (YYSTYPE_IS_DECLARED)
#line 79 "dvdvmy.y"
typedef union YYSTYPE {
    int int_val;
    char *str_val;
    struct vm_statement *statement;
} YYSTYPE;
/* Line 1285 of yacc.c.  */
#line 165 "dvdvmy.h"
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif

extern YYSTYPE dvdvmlval;



