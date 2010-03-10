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

/* Written by Richard Stallman by simplifying the original so called
   ``semantic'' parser.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output.  */
#define YYBISON 1

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Using locations.  */
#define YYLSP_NEEDED 0

/* If NAME_PREFIX is specified substitute the variables and functions
   names.  */
#define yyparse dvdvmparse
#define yylex   dvdvmlex
#define yyerror dvdvmerror
#define yylval  dvdvmlval
#define yychar  dvdvmchar
#define yydebug dvdvmdebug
#define yynerrs dvdvmnerrs


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




/* Copy the first part of user declarations.  */
#line 1 "dvdvmy.y"


/*
 * Copyright (C) 2002 Scott Smith (trckjunky@users.sourceforge.net)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
 * USA
 */

#include "dvdvm.h"

static const char RCSID[]="$Id: //depot/dvdauthor/src/dvdvmy.y#2 $";

#define YYERROR_VERBOSE



/* Enabling traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif

/* Enabling verbose error messages.  */
#ifdef YYERROR_VERBOSE
# undef YYERROR_VERBOSE
# define YYERROR_VERBOSE 1
#else
# define YYERROR_VERBOSE 0
#endif

#if ! defined (YYSTYPE) && ! defined (YYSTYPE_IS_DECLARED)
#line 79 "dvdvmy.y"
typedef union YYSTYPE {
    int int_val;
    char *str_val;
    struct vm_statement *statement;
} YYSTYPE;
/* Line 191 of yacc.c.  */
#line 242 "dvdvmy.c"
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif



/* Copy the second part of user declarations.  */


/* Line 214 of yacc.c.  */
#line 254 "dvdvmy.c"

#if ! defined (yyoverflow) || YYERROR_VERBOSE

# ifndef YYFREE
#  define YYFREE free
# endif
# ifndef YYMALLOC
#  define YYMALLOC malloc
# endif

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   define YYSTACK_ALLOC alloca
#  endif
# else
#  if defined (alloca) || defined (_ALLOCA_H)
#   define YYSTACK_ALLOC alloca
#  else
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's `empty if-body' warning. */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
# else
#  if defined (__STDC__) || defined (__cplusplus)
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   define YYSIZE_T size_t
#  endif
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
# endif
#endif /* ! defined (yyoverflow) || YYERROR_VERBOSE */


#if (! defined (yyoverflow) \
     && (! defined (__cplusplus) \
	 || (defined (YYSTYPE_IS_TRIVIAL) && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  short int yyss;
  YYSTYPE yyvs;
  };

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (sizeof (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (sizeof (short int) + sizeof (YYSTYPE))			\
      + YYSTACK_GAP_MAXIMUM)

/* Copy COUNT objects from FROM to TO.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined (__GNUC__) && 1 < __GNUC__
#   define YYCOPY(To, From, Count) \
      __builtin_memcpy (To, From, (Count) * sizeof (*(From)))
#  else
#   define YYCOPY(To, From, Count)		\
      do					\
	{					\
	  register YYSIZE_T yyi;		\
	  for (yyi = 0; yyi < (Count); yyi++)	\
	    (To)[yyi] = (From)[yyi];		\
	}					\
      while (0)
#  endif
# endif

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack)					\
    do									\
      {									\
	YYSIZE_T yynewbytes;						\
	YYCOPY (&yyptr->Stack, Stack, yysize);				\
	Stack = &yyptr->Stack;						\
	yynewbytes = yystacksize * sizeof (*Stack) + YYSTACK_GAP_MAXIMUM; \
	yyptr += yynewbytes / sizeof (*yyptr);				\
      }									\
    while (0)

#endif

#if defined (__STDC__) || defined (__cplusplus)
   typedef signed char yysigned_char;
#else
   typedef short int yysigned_char;
#endif

/* YYFINAL -- State number of the termination state. */
#define YYFINAL  32
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   361

/* YYNTOKENS -- Number of terminals. */
#define YYNTOKENS  62
/* YYNNTS -- Number of nonterminals. */
#define YYNNTS  17
/* YYNRULES -- Number of rules. */
#define YYNRULES  77
/* YYNRULES -- Number of states. */
#define YYNSTATES  148

/* YYTRANSLATE(YYLEX) -- Bison symbol number corresponding to YYLEX.  */
#define YYUNDEFTOK  2
#define YYMAXUTOK   316

#define YYTRANSLATE(YYX) 						\
  ((unsigned int) (YYX) <= YYMAXUTOK ? yytranslate[YYX] : YYUNDEFTOK)

/* YYTRANSLATE[YYLEX] -- Bison symbol number corresponding to YYLEX.  */
static const unsigned char yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23,    24,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    36,    37,    38,    39,    40,    41,    42,    43,    44,
      45,    46,    47,    48,    49,    50,    51,    52,    53,    54,
      55,    56,    57,    58,    59,    60,    61
};

#if YYDEBUG
/* YYPRHS[YYN] -- Index of the first RHS symbol of rule number YYN in
   YYRHS.  */
static const unsigned short int yyprhs[] =
{
       0,     0,     3,     5,     7,    10,    12,    14,    17,    20,
      22,    26,    28,    31,    33,    34,    37,    39,    43,    47,
      51,    55,    59,    63,    65,    68,    69,    72,    73,    79,
      84,    89,    92,    93,   100,   102,   104,   106,   108,   110,
     112,   114,   116,   120,   122,   126,   130,   134,   138,   142,
     146,   150,   154,   158,   162,   166,   170,   174,   178,   182,
     186,   190,   194,   198,   202,   206,   209,   214,   219,   224,
     229,   234,   239,   244,   249,   254,   260,   262
};

/* YYRHS -- A `-1'-separated list of the rules' RHS. */
static const yysigned_char yyrhs[] =
{
      63,     0,    -1,    64,    -1,    65,    -1,    65,    64,    -1,
      69,    -1,    71,    -1,    17,    60,    -1,    26,    60,    -1,
      76,    -1,    22,    64,    13,    -1,    78,    -1,    31,     3,
      -1,    32,    -1,    -1,    21,     3,    -1,    21,    -1,    21,
      16,    30,    -1,    21,    16,    27,    -1,    21,    16,    29,
      -1,    21,    16,     8,    -1,    21,    16,     7,    -1,    21,
      16,    25,    -1,    18,    -1,    30,     3,    -1,    -1,    12,
       3,    -1,    -1,    20,    66,    67,    68,    60,    -1,    20,
      11,     3,    60,    -1,    20,    24,     3,    60,    -1,    26,
       3,    -1,    -1,    10,    66,    67,    68,    70,    60,    -1,
       4,    -1,     5,    -1,     8,    -1,    29,    -1,     7,    -1,
       9,    -1,    72,    -1,     3,    -1,    23,    74,    14,    -1,
      73,    -1,    74,    48,    74,    -1,    74,    47,    74,    -1,
      74,    51,    74,    -1,    74,    50,    74,    -1,    74,    49,
      74,    -1,    74,    37,    74,    -1,    74,    33,    74,    -1,
      74,    39,    74,    -1,    74,    36,    74,    -1,    74,    35,
      74,    -1,    23,    75,    14,    -1,    74,    42,    74,    -1,
      74,    41,    74,    -1,    74,    46,    74,    -1,    74,    45,
      74,    -1,    74,    44,    74,    -1,    74,    43,    74,    -1,
      75,    34,    75,    -1,    75,    38,    75,    -1,    75,    36,
      75,    -1,    75,    39,    75,    -1,    40,    75,    -1,    72,
      28,    74,    60,    -1,    72,    52,    74,    60,    -1,    72,
      53,    74,    60,    -1,    72,    54,    74,    60,    -1,    72,
      55,    74,    60,    -1,    72,    56,    74,    60,    -1,    72,
      57,    74,    60,    -1,    72,    58,    74,    60,    -1,    72,
      59,    74,    60,    -1,    19,    23,    75,    14,    65,    -1,
      77,    -1,    77,    15,    65,    -1
};

/* YYRLINE[YYN] -- source line where rule number YYN was defined.  */
static const unsigned short int yyrline[] =
{
       0,    90,    90,    95,    98,   104,   107,   110,   114,   118,
     121,   124,   129,   132,   135,   140,   143,   146,   149,   152,
     155,   158,   161,   164,   167,   170,   175,   178,   183,   190,
     195,   202,   205,   210,   220,   223,   226,   229,   232,   235,
     240,   243,   248,   251,   256,   259,   262,   265,   268,   271,
     274,   277,   280,   283,   288,   291,   294,   297,   300,   303,
     306,   309,   312,   315,   318,   321,   328,   334,   337,   340,
     343,   346,   349,   352,   355,   360,   370,   373
};
#endif

#if YYDEBUG || YYERROR_VERBOSE
/* YYTNME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals. */
static const char *const yytname[] =
{
  "$end", "error", "$undefined", "NUM_TOK", "G_TOK", "S_TOK", "ID_TOK",
  "ANGLE_TOK", "AUDIO_TOK", "BUTTON_TOK", "CALL_TOK", "CELL_TOK",
  "CHAPTER_TOK", "CLOSEBRACE_TOK", "CLOSEPAREN_TOK", "ELSE_TOK",
  "ENTRY_TOK", "EXIT_TOK", "FPC_TOK", "IF_TOK", "JUMP_TOK", "MENU_TOK",
  "OPENBRACE_TOK", "OPENPAREN_TOK", "PROGRAM_TOK", "PTT_TOK", "RESUME_TOK",
  "ROOT_TOK", "SET_TOK", "SUBTITLE_TOK", "TITLE_TOK", "TITLESET_TOK",
  "VMGM_TOK", "BOR_TOK", "LOR_TOK", "XOR_TOK", "_OR_TOK", "BAND_TOK",
  "LAND_TOK", "_AND_TOK", "NOT_TOK", "NE_TOK", "EQ_TOK", "LT_TOK",
  "LE_TOK", "GT_TOK", "GE_TOK", "SUB_TOK", "ADD_TOK", "MOD_TOK", "DIV_TOK",
  "MUL_TOK", "ADDSET_TOK", "SUBSET_TOK", "MULSET_TOK", "DIVSET_TOK",
  "MODSET_TOK", "ANDSET_TOK", "ORSET_TOK", "XORSET_TOK", "SEMICOLON_TOK",
  "ERROR_TOK", "$accept", "finalparse", "statements", "statement", "jtsl",
  "jtml", "jcl", "jumpstatement", "resumel", "callstatement", "reg",
  "regornum", "expression", "boolexpr", "setstatement", "ifstatement",
  "ifelsestatement", 0
};
#endif

# ifdef YYPRINT
/* YYTOKNUM[YYLEX-NUM] -- Internal token number corresponding to
   token YYLEX-NUM.  */
static const unsigned short int yytoknum[] =
{
       0,   256,   257,   258,   259,   260,   261,   262,   263,   264,
     265,   266,   267,   268,   269,   270,   271,   272,   273,   274,
     275,   276,   277,   278,   279,   280,   281,   282,   283,   284,
     285,   286,   287,   288,   289,   290,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   309,   310,   311,   312,   313,   314,
     315,   316
};
# endif

/* YYR1[YYN] -- Symbol number of symbol that rule YYN derives.  */
static const unsigned char yyr1[] =
{
       0,    62,    63,    64,    64,    65,    65,    65,    65,    65,
      65,    65,    66,    66,    66,    67,    67,    67,    67,    67,
      67,    67,    67,    67,    67,    67,    68,    68,    69,    69,
      69,    70,    70,    71,    72,    72,    72,    72,    72,    72,
      73,    73,    74,    74,    74,    74,    74,    74,    74,    74,
      74,    74,    74,    74,    75,    75,    75,    75,    75,    75,
      75,    75,    75,    75,    75,    75,    76,    76,    76,    76,
      76,    76,    76,    76,    76,    77,    78,    78
};

/* YYR2[YYN] -- Number of symbols composing right hand side of rule YYN.  */
static const unsigned char yyr2[] =
{
       0,     2,     1,     1,     2,     1,     1,     2,     2,     1,
       3,     1,     2,     1,     0,     2,     1,     3,     3,     3,
       3,     3,     3,     1,     2,     0,     2,     0,     5,     4,
       4,     2,     0,     6,     1,     1,     1,     1,     1,     1,
       1,     1,     3,     1,     3,     3,     3,     3,     3,     3,
       3,     3,     3,     3,     3,     3,     3,     3,     3,     3,
       3,     3,     3,     3,     3,     2,     4,     4,     4,     4,
       4,     4,     4,     4,     4,     5,     1,     3
};

/* YYDEFACT[STATE-NAME] -- Default rule to reduce with in state
   STATE-NUM when YYTABLE doesn't specify something else to do.  Zero
   means the default is an error.  */
static const unsigned char yydefact[] =
{
       0,    34,    35,    38,    36,    39,    14,     0,     0,    14,
       0,     0,    37,     0,     2,     3,     5,     6,     0,     9,
      76,    11,     0,    13,    25,     7,     0,     0,     0,    25,
       0,     8,     1,     4,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,    12,    23,    16,     0,    27,    41,
       0,     0,    40,    43,     0,     0,     0,     0,    27,    10,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
      77,    15,     0,    24,     0,    32,     0,     0,    65,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
      29,    30,     0,     0,    66,    67,    68,    69,    70,    71,
      72,    73,    74,    21,    20,    22,    18,    19,    17,    26,
       0,     0,    42,    54,    50,    53,    52,    49,    51,    56,
      55,    60,    59,    58,    57,    45,    44,    48,    47,    46,
      75,    61,    63,    62,    64,    28,    31,    33
};

/* YYDEFGOTO[NTERM-NUM]. */
static const yysigned_char yydefgoto[] =
{
      -1,    13,    14,    15,    24,    48,    75,    16,   121,    17,
      52,    53,    54,    55,    19,    20,    21
};

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
#define YYPACT_NINF -47
static const short int yypact[] =
{
     291,   -47,   -47,   -47,   -47,   -47,    -3,   -46,    -7,     7,
     291,   -35,   -47,    41,   -47,   291,   -47,   -47,    90,   -47,
      49,   -47,    77,   -47,     3,   -47,   112,    78,    80,     3,
      72,   -47,   -47,   -47,   265,   265,   265,   265,   265,   265,
     265,   265,   265,   291,   -47,   -47,    10,   104,    81,   -47,
     112,   112,   -47,   -47,   286,    -2,    53,    67,    81,   -47,
     265,   118,   123,   149,   154,   180,   185,   211,   216,   242,
     -47,   -47,    15,   -47,   106,   102,    55,    48,   -47,   265,
     265,   265,   265,   265,   265,   265,   265,   265,   265,   265,
     265,   265,   265,   265,   265,   291,   112,   112,   112,   112,
     -47,   -47,    69,    75,   -47,   -47,   -47,   -47,   -47,   -47,
     -47,   -47,   -47,   -47,   -47,   -47,   -47,   -47,   -47,   -47,
     127,    71,   -47,   -47,   310,   310,   310,    23,    23,   305,
     305,   305,   305,   305,   305,    26,    26,   -47,   -47,   -47,
     -47,    40,    40,   -47,   -47,   -47,   -47,   -47
};

/* YYPGOTO[NTERM-NUM].  */
static const yysigned_char yypgoto[] =
{
     -47,   -47,    20,   -32,   124,   103,    76,   -47,   -47,   -47,
       0,   -47,   -33,   -31,   -47,   -47,   -47
};

/* YYTABLE[YYPACT[STATE-NUM]].  What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule which
   number is the opposite.  If zero, do what YYDEFACT says.
   If YYTABLE_NINF, syntax error.  */
#define YYTABLE_NINF -1
static const unsigned char yytable[] =
{
      18,    61,    62,    63,    64,    65,    66,    67,    68,    69,
      18,    70,    95,    71,    25,    18,    26,    76,    27,    77,
      78,    45,   113,   114,    46,    31,    72,   103,    22,    23,
      30,    28,    96,    47,    97,    33,    98,    99,    22,    23,
     115,    32,   116,    18,   117,   118,   124,   125,   126,   127,
     128,   129,   130,   131,   132,   133,   134,   135,   136,   137,
     138,   139,   123,   140,    43,   141,   142,   143,   144,   122,
      90,    91,    92,    93,    94,    92,    93,    94,    98,    99,
      44,    56,    96,    57,    97,    59,    98,    99,    79,   122,
      80,    81,    82,    74,    83,    18,    84,    85,    86,    87,
      88,    89,    90,    91,    92,    93,    94,    73,    79,   119,
      80,    81,    82,   100,    83,    49,     1,     2,    34,     3,
       4,     5,    90,    91,    92,    93,    94,   101,   120,   145,
     146,   147,    58,    29,   102,    50,     0,     0,     0,     0,
       0,    12,    35,    36,    37,    38,    39,    40,    41,    42,
       0,    79,    51,    80,    81,    82,    79,    83,    80,    81,
      82,     0,    83,     0,     0,    90,    91,    92,    93,    94,
      90,    91,    92,    93,    94,     0,     0,     0,   104,     0,
       0,     0,    79,   105,    80,    81,    82,    79,    83,    80,
      81,    82,     0,    83,     0,     0,    90,    91,    92,    93,
      94,    90,    91,    92,    93,    94,     0,     0,     0,   106,
       0,     0,     0,    79,   107,    80,    81,    82,    79,    83,
      80,    81,    82,     0,    83,     0,     0,    90,    91,    92,
      93,    94,    90,    91,    92,    93,    94,     0,     0,     0,
     108,     0,     0,     0,    79,   109,    80,    81,    82,    79,
      83,    80,    81,    82,     0,    83,     0,     0,    90,    91,
      92,    93,    94,    90,    91,    92,    93,    94,    49,     1,
       2,   110,     3,     4,     5,    79,   111,    80,    81,    82,
       0,    83,     0,     0,     0,     0,     0,     0,    60,    90,
      91,    92,    93,    94,    12,     1,     2,     0,     3,     4,
       5,     6,   112,     0,     0,     0,     0,     0,     7,     0,
       8,     9,     0,    10,     0,     0,     0,    11,     0,    79,
      12,    80,    81,    82,     0,    83,     0,    84,    85,    86,
      87,    88,    89,    90,    91,    92,    93,    94,    79,     0,
      80,     0,    82,     0,     0,     0,     0,    82,     0,    83,
       0,     0,    90,    91,    92,    93,    94,    90,    91,    92,
      93,    94
};

static const yysigned_char yycheck[] =
{
       0,    34,    35,    36,    37,    38,    39,    40,    41,    42,
      10,    43,    14,     3,    60,    15,    23,    50,    11,    50,
      51,    18,     7,     8,    21,    60,    16,    60,    31,    32,
      10,    24,    34,    30,    36,    15,    38,    39,    31,    32,
      25,     0,    27,    43,    29,    30,    79,    80,    81,    82,
      83,    84,    85,    86,    87,    88,    89,    90,    91,    92,
      93,    94,    14,    95,    15,    96,    97,    98,    99,    14,
      47,    48,    49,    50,    51,    49,    50,    51,    38,    39,
       3,     3,    34,     3,    36,    13,    38,    39,    33,    14,
      35,    36,    37,    12,    39,    95,    41,    42,    43,    44,
      45,    46,    47,    48,    49,    50,    51,     3,    33,     3,
      35,    36,    37,    60,    39,     3,     4,     5,    28,     7,
       8,     9,    47,    48,    49,    50,    51,    60,    26,    60,
       3,    60,    29,     9,    58,    23,    -1,    -1,    -1,    -1,
      -1,    29,    52,    53,    54,    55,    56,    57,    58,    59,
      -1,    33,    40,    35,    36,    37,    33,    39,    35,    36,
      37,    -1,    39,    -1,    -1,    47,    48,    49,    50,    51,
      47,    48,    49,    50,    51,    -1,    -1,    -1,    60,    -1,
      -1,    -1,    33,    60,    35,    36,    37,    33,    39,    35,
      36,    37,    -1,    39,    -1,    -1,    47,    48,    49,    50,
      51,    47,    48,    49,    50,    51,    -1,    -1,    -1,    60,
      -1,    -1,    -1,    33,    60,    35,    36,    37,    33,    39,
      35,    36,    37,    -1,    39,    -1,    -1,    47,    48,    49,
      50,    51,    47,    48,    49,    50,    51,    -1,    -1,    -1,
      60,    -1,    -1,    -1,    33,    60,    35,    36,    37,    33,
      39,    35,    36,    37,    -1,    39,    -1,    -1,    47,    48,
      49,    50,    51,    47,    48,    49,    50,    51,     3,     4,
       5,    60,     7,     8,     9,    33,    60,    35,    36,    37,
      -1,    39,    -1,    -1,    -1,    -1,    -1,    -1,    23,    47,
      48,    49,    50,    51,    29,     4,     5,    -1,     7,     8,
       9,    10,    60,    -1,    -1,    -1,    -1,    -1,    17,    -1,
      19,    20,    -1,    22,    -1,    -1,    -1,    26,    -1,    33,
      29,    35,    36,    37,    -1,    39,    -1,    41,    42,    43,
      44,    45,    46,    47,    48,    49,    50,    51,    33,    -1,
      35,    -1,    37,    -1,    -1,    -1,    -1,    37,    -1,    39,
      -1,    -1,    47,    48,    49,    50,    51,    47,    48,    49,
      50,    51
};

/* YYSTOS[STATE-NUM] -- The (internal number of the) accessing
   symbol of state STATE-NUM.  */
static const unsigned char yystos[] =
{
       0,     4,     5,     7,     8,     9,    10,    17,    19,    20,
      22,    26,    29,    63,    64,    65,    69,    71,    72,    76,
      77,    78,    31,    32,    66,    60,    23,    11,    24,    66,
      64,    60,     0,    64,    28,    52,    53,    54,    55,    56,
      57,    58,    59,    15,     3,    18,    21,    30,    67,     3,
      23,    40,    72,    73,    74,    75,     3,     3,    67,    13,
      23,    74,    74,    74,    74,    74,    74,    74,    74,    74,
      65,     3,    16,     3,    12,    68,    74,    75,    75,    33,
      35,    36,    37,    39,    41,    42,    43,    44,    45,    46,
      47,    48,    49,    50,    51,    14,    34,    36,    38,    39,
      60,    60,    68,    74,    60,    60,    60,    60,    60,    60,
      60,    60,    60,     7,     8,    25,    27,    29,    30,     3,
      26,    70,    14,    14,    74,    74,    74,    74,    74,    74,
      74,    74,    74,    74,    74,    74,    74,    74,    74,    74,
      65,    75,    75,    75,    75,    60,     3,    60
};

#if ! defined (YYSIZE_T) && defined (__SIZE_TYPE__)
# define YYSIZE_T __SIZE_TYPE__
#endif
#if ! defined (YYSIZE_T) && defined (size_t)
# define YYSIZE_T size_t
#endif
#if ! defined (YYSIZE_T)
# if defined (__STDC__) || defined (__cplusplus)
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# endif
#endif
#if ! defined (YYSIZE_T)
# define YYSIZE_T unsigned int
#endif

#define yyerrok		(yyerrstatus = 0)
#define yyclearin	(yychar = YYEMPTY)
#define YYEMPTY		(-2)
#define YYEOF		0

#define YYACCEPT	goto yyacceptlab
#define YYABORT		goto yyabortlab
#define YYERROR		goto yyerrorlab


/* Like YYERROR except do call yyerror.  This remains here temporarily
   to ease the transition to the new meaning of YYERROR, for GCC.
   Once GCC version 2 has supplanted version 1, this can go.  */

#define YYFAIL		goto yyerrlab

#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)					\
do								\
  if (yychar == YYEMPTY && yylen == 1)				\
    {								\
      yychar = (Token);						\
      yylval = (Value);						\
      yytoken = YYTRANSLATE (yychar);				\
      YYPOPSTACK;						\
      goto yybackup;						\
    }								\
  else								\
    { 								\
      yyerror ("syntax error: cannot back up");\
      YYERROR;							\
    }								\
while (0)

#define YYTERROR	1
#define YYERRCODE	256

/* YYLLOC_DEFAULT -- Compute the default location (before the actions
   are run).  */

#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)		\
   ((Current).first_line   = (Rhs)[1].first_line,	\
    (Current).first_column = (Rhs)[1].first_column,	\
    (Current).last_line    = (Rhs)[N].last_line,	\
    (Current).last_column  = (Rhs)[N].last_column)
#endif

/* YYLEX -- calling `yylex' with the right arguments.  */

#ifdef YYLEX_PARAM
# define YYLEX yylex (YYLEX_PARAM)
#else
# define YYLEX yylex ()
#endif

/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)			\
do {						\
  if (yydebug)					\
    YYFPRINTF Args;				\
} while (0)

# define YYDSYMPRINT(Args)			\
do {						\
  if (yydebug)					\
    yysymprint Args;				\
} while (0)

# define YYDSYMPRINTF(Title, Token, Value, Location)		\
do {								\
  if (yydebug)							\
    {								\
      YYFPRINTF (stderr, "%s ", Title);				\
      yysymprint (stderr, 					\
                  Token, Value);	\
      YYFPRINTF (stderr, "\n");					\
    }								\
} while (0)

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yy_stack_print (short int *bottom, short int *top)
#else
static void
yy_stack_print (bottom, top)
    short int *bottom;
    short int *top;
#endif
{
  YYFPRINTF (stderr, "Stack now");
  for (/* Nothing. */; bottom <= top; ++bottom)
    YYFPRINTF (stderr, " %d", *bottom);
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)				\
do {								\
  if (yydebug)							\
    yy_stack_print ((Bottom), (Top));				\
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yy_reduce_print (int yyrule)
#else
static void
yy_reduce_print (yyrule)
    int yyrule;
#endif
{
  int yyi;
  unsigned int yylno = yyrline[yyrule];
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %u), ",
             yyrule - 1, yylno);
  /* Print the symbols being reduced, and their result.  */
  for (yyi = yyprhs[yyrule]; 0 <= yyrhs[yyi]; yyi++)
    YYFPRINTF (stderr, "%s ", yytname [yyrhs[yyi]]);
  YYFPRINTF (stderr, "-> %s\n", yytname [yyr1[yyrule]]);
}

# define YY_REDUCE_PRINT(Rule)		\
do {					\
  if (yydebug)				\
    yy_reduce_print (Rule);		\
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args)
# define YYDSYMPRINT(Args)
# define YYDSYMPRINTF(Title, Token, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef	YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   SIZE_MAX < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#if defined (YYMAXDEPTH) && YYMAXDEPTH == 0
# undef YYMAXDEPTH
#endif

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif



#if YYERROR_VERBOSE

# ifndef yystrlen
#  if defined (__GLIBC__) && defined (_STRING_H)
#   define yystrlen strlen
#  else
/* Return the length of YYSTR.  */
static YYSIZE_T
#   if defined (__STDC__) || defined (__cplusplus)
yystrlen (const char *yystr)
#   else
yystrlen (yystr)
     const char *yystr;
#   endif
{
  register const char *yys = yystr;

  while (*yys++ != '\0')
    continue;

  return yys - yystr - 1;
}
#  endif
# endif

# ifndef yystpcpy
#  if defined (__GLIBC__) && defined (_STRING_H) && defined (_GNU_SOURCE)
#   define yystpcpy stpcpy
#  else
/* Copy YYSRC to YYDEST, returning the address of the terminating '\0' in
   YYDEST.  */
static char *
#   if defined (__STDC__) || defined (__cplusplus)
yystpcpy (char *yydest, const char *yysrc)
#   else
yystpcpy (yydest, yysrc)
     char *yydest;
     const char *yysrc;
#   endif
{
  register char *yyd = yydest;
  register const char *yys = yysrc;

  while ((*yyd++ = *yys++) != '\0')
    continue;

  return yyd - 1;
}
#  endif
# endif

#endif /* !YYERROR_VERBOSE */



#if YYDEBUG
/*--------------------------------.
| Print this symbol on YYOUTPUT.  |
`--------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yysymprint (FILE *yyoutput, int yytype, YYSTYPE *yyvaluep)
#else
static void
yysymprint (yyoutput, yytype, yyvaluep)
    FILE *yyoutput;
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  /* Pacify ``unused variable'' warnings.  */
  (void) yyvaluep;

  if (yytype < YYNTOKENS)
    {
      YYFPRINTF (yyoutput, "token %s (", yytname[yytype]);
# ifdef YYPRINT
      YYPRINT (yyoutput, yytoknum[yytype], *yyvaluep);
# endif
    }
  else
    YYFPRINTF (yyoutput, "nterm %s (", yytname[yytype]);

  switch (yytype)
    {
      default:
        break;
    }
  YYFPRINTF (yyoutput, ")");
}

#endif /* ! YYDEBUG */
/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yydestruct (int yytype, YYSTYPE *yyvaluep)
#else
static void
yydestruct (yytype, yyvaluep)
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  /* Pacify ``unused variable'' warnings.  */
  (void) yyvaluep;

  switch (yytype)
    {

      default:
        break;
    }
}


/* Prevent warnings from -Wmissing-prototypes.  */

#ifdef YYPARSE_PARAM
# if defined (__STDC__) || defined (__cplusplus)
int yyparse (void *YYPARSE_PARAM);
# else
int yyparse ();
# endif
#else /* ! YYPARSE_PARAM */
#if defined (__STDC__) || defined (__cplusplus)
int yyparse (void);
#else
int yyparse ();
#endif
#endif /* ! YYPARSE_PARAM */



/* The lookahead symbol.  */
int yychar;

/* The semantic value of the lookahead symbol.  */
YYSTYPE yylval;

/* Number of syntax errors so far.  */
int yynerrs;



/*----------.
| yyparse.  |
`----------*/

#ifdef YYPARSE_PARAM
# if defined (__STDC__) || defined (__cplusplus)
int yyparse (void *YYPARSE_PARAM)
# else
int yyparse (YYPARSE_PARAM)
  void *YYPARSE_PARAM;
# endif
#else /* ! YYPARSE_PARAM */
#if defined (__STDC__) || defined (__cplusplus)
int
yyparse (void)
#else
int
yyparse ()

#endif
#endif
{
  
  register int yystate;
  register int yyn;
  int yyresult;
  /* Number of tokens to shift before error messages enabled.  */
  int yyerrstatus;
  /* Lookahead token as an internal (translated) token number.  */
  int yytoken = 0;

  /* Three stacks and their tools:
     `yyss': related to states,
     `yyvs': related to semantic values,
     `yyls': related to locations.

     Refer to the stacks thru separate pointers, to allow yyoverflow
     to reallocate them elsewhere.  */

  /* The state stack.  */
  short int yyssa[YYINITDEPTH];
  short int *yyss = yyssa;
  register short int *yyssp;

  /* The semantic value stack.  */
  YYSTYPE yyvsa[YYINITDEPTH];
  YYSTYPE *yyvs = yyvsa;
  register YYSTYPE *yyvsp;



#define YYPOPSTACK   (yyvsp--, yyssp--)

  YYSIZE_T yystacksize = YYINITDEPTH;

  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;


  /* When reducing, the number of symbols on the RHS of the reduced
     rule.  */
  int yylen;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yystate = 0;
  yyerrstatus = 0;
  yynerrs = 0;
  yychar = YYEMPTY;		/* Cause a token to be read.  */

  /* Initialize stack pointers.
     Waste one element of value and location stack
     so that they stay on the same level as the state stack.
     The wasted elements are never initialized.  */

  yyssp = yyss;
  yyvsp = yyvs;


  goto yysetstate;

/*------------------------------------------------------------.
| yynewstate -- Push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
 yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed. so pushing a state here evens the stacks.
     */
  yyssp++;

 yysetstate:
  *yyssp = yystate;

  if (yyss + yystacksize - 1 <= yyssp)
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYSIZE_T yysize = yyssp - yyss + 1;

#ifdef yyoverflow
      {
	/* Give user a chance to reallocate the stack. Use copies of
	   these so that the &'s don't force the real ones into
	   memory.  */
	YYSTYPE *yyvs1 = yyvs;
	short int *yyss1 = yyss;


	/* Each stack pointer address is followed by the size of the
	   data in use in that stack, in bytes.  This used to be a
	   conditional around just the two extra args, but that might
	   be undefined if yyoverflow is a macro.  */
	yyoverflow ("parser stack overflow",
		    &yyss1, yysize * sizeof (*yyssp),
		    &yyvs1, yysize * sizeof (*yyvsp),

		    &yystacksize);

	yyss = yyss1;
	yyvs = yyvs1;
      }
#else /* no yyoverflow */
# ifndef YYSTACK_RELOCATE
      goto yyoverflowlab;
# else
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
	goto yyoverflowlab;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
	yystacksize = YYMAXDEPTH;

      {
	short int *yyss1 = yyss;
	union yyalloc *yyptr =
	  (union yyalloc *) YYSTACK_ALLOC (YYSTACK_BYTES (yystacksize));
	if (! yyptr)
	  goto yyoverflowlab;
	YYSTACK_RELOCATE (yyss);
	YYSTACK_RELOCATE (yyvs);

#  undef YYSTACK_RELOCATE
	if (yyss1 != yyssa)
	  YYSTACK_FREE (yyss1);
      }
# endif
#endif /* no yyoverflow */

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;


      YYDPRINTF ((stderr, "Stack size increased to %lu\n",
		  (unsigned long int) yystacksize));

      if (yyss + yystacksize - 1 <= yyssp)
	YYABORT;
    }

  YYDPRINTF ((stderr, "Entering state %d\n", yystate));

  goto yybackup;

/*-----------.
| yybackup.  |
`-----------*/
yybackup:

/* Do appropriate processing given the current state.  */
/* Read a lookahead token if we need one and don't already have one.  */
/* yyresume: */

  /* First try to decide what to do without reference to lookahead token.  */

  yyn = yypact[yystate];
  if (yyn == YYPACT_NINF)
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* YYCHAR is either YYEMPTY or YYEOF or a valid lookahead symbol.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token: "));
      yychar = YYLEX;
    }

  if (yychar <= YYEOF)
    {
      yychar = yytoken = YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YYDSYMPRINTF ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yyn == 0 || yyn == YYTABLE_NINF)
	goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  /* Shift the lookahead token.  */
  YYDPRINTF ((stderr, "Shifting token %s, ", yytname[yytoken]));

  /* Discard the token being shifted unless it is eof.  */
  if (yychar != YYEOF)
    yychar = YYEMPTY;

  *++yyvsp = yylval;


  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  yystate = yyn;
  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- Do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     `$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
        case 2:
#line 90 "dvdvmy.y"
    {
    dvd_vm_parsed_cmd=yyval.statement;
;}
    break;

  case 3:
#line 95 "dvdvmy.y"
    {
    yyval.statement=yyvsp[0].statement;
;}
    break;

  case 4:
#line 98 "dvdvmy.y"
    {
    yyval.statement=yyvsp[-1].statement;
    yyval.statement->next=yyvsp[0].statement;
;}
    break;

  case 5:
#line 104 "dvdvmy.y"
    {
    yyval.statement=yyvsp[0].statement;
;}
    break;

  case 6:
#line 107 "dvdvmy.y"
    {
    yyval.statement=yyvsp[0].statement;
;}
    break;

  case 7:
#line 110 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_EXIT;
;}
    break;

  case 8:
#line 114 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_RESUME;
;}
    break;

  case 9:
#line 118 "dvdvmy.y"
    {
    yyval.statement=yyvsp[0].statement;
;}
    break;

  case 10:
#line 121 "dvdvmy.y"
    {
    yyval.statement=yyvsp[-1].statement;
;}
    break;

  case 11:
#line 124 "dvdvmy.y"
    {
    yyval.statement=yyvsp[0].statement;
;}
    break;

  case 12:
#line 129 "dvdvmy.y"
    {
    yyval.int_val=(yyvsp[0].int_val)+1;
;}
    break;

  case 13:
#line 132 "dvdvmy.y"
    {
    yyval.int_val=1;
;}
    break;

  case 14:
#line 135 "dvdvmy.y"
    {
    yyval.int_val=0;
;}
    break;

  case 15:
#line 140 "dvdvmy.y"
    {
    yyval.int_val=yyvsp[0].int_val;
;}
    break;

  case 16:
#line 143 "dvdvmy.y"
    {
    yyval.int_val=120; // default entry
;}
    break;

  case 17:
#line 146 "dvdvmy.y"
    {
    yyval.int_val=122;
;}
    break;

  case 18:
#line 149 "dvdvmy.y"
    {
    yyval.int_val=123;
;}
    break;

  case 19:
#line 152 "dvdvmy.y"
    {
    yyval.int_val=124;
;}
    break;

  case 20:
#line 155 "dvdvmy.y"
    {
    yyval.int_val=125;
;}
    break;

  case 21:
#line 158 "dvdvmy.y"
    {
    yyval.int_val=126;
;}
    break;

  case 22:
#line 161 "dvdvmy.y"
    {
    yyval.int_val=127;
;}
    break;

  case 23:
#line 164 "dvdvmy.y"
    {
    yyval.int_val=121;
;}
    break;

  case 24:
#line 167 "dvdvmy.y"
    {
    yyval.int_val=(yyvsp[0].int_val)|128;
;}
    break;

  case 25:
#line 170 "dvdvmy.y"
    {
    yyval.int_val=0;
;}
    break;

  case 26:
#line 175 "dvdvmy.y"
    {
    yyval.int_val=yyvsp[0].int_val;
;}
    break;

  case 27:
#line 178 "dvdvmy.y"
    {
    yyval.int_val=0;
;}
    break;

  case 28:
#line 183 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_JUMP;
    yyval.statement->i1=yyvsp[-3].int_val;
    yyval.statement->i2=yyvsp[-2].int_val;
    yyval.statement->i3=yyvsp[-1].int_val;
;}
    break;

  case 29:
#line 190 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_JUMP;
    yyval.statement->i3=2*65536+yyvsp[-1].int_val;
;}
    break;

  case 30:
#line 195 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_JUMP;
    yyval.statement->i3=65536+yyvsp[-1].int_val;
;}
    break;

  case 31:
#line 202 "dvdvmy.y"
    {
    yyval.int_val=yyvsp[0].int_val;
;}
    break;

  case 32:
#line 205 "dvdvmy.y"
    {
    yyval.int_val=0;
;}
    break;

  case 33:
#line 210 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_CALL;
    yyval.statement->i1=yyvsp[-4].int_val;
    yyval.statement->i2=yyvsp[-3].int_val;
    yyval.statement->i3=yyvsp[-2].int_val;
    yyval.statement->i4=yyvsp[-1].int_val;
;}
    break;

  case 34:
#line 220 "dvdvmy.y"
    {
    yyval.int_val=yyvsp[0].int_val;
;}
    break;

  case 35:
#line 223 "dvdvmy.y"
    {
    yyval.int_val=yyvsp[0].int_val+0x80;
;}
    break;

  case 36:
#line 226 "dvdvmy.y"
    {
    yyval.int_val=0x81;
;}
    break;

  case 37:
#line 229 "dvdvmy.y"
    {
    yyval.int_val=0x82;
;}
    break;

  case 38:
#line 232 "dvdvmy.y"
    {
    yyval.int_val=0x83;
;}
    break;

  case 39:
#line 235 "dvdvmy.y"
    {
    yyval.int_val=0x88;
;}
    break;

  case 40:
#line 240 "dvdvmy.y"
    {
    yyval.int_val=yyvsp[0].int_val-256;
;}
    break;

  case 41:
#line 243 "dvdvmy.y"
    {
    yyval.int_val=yyvsp[0].int_val;
;}
    break;

  case 42:
#line 248 "dvdvmy.y"
    {
    yyval.statement=yyvsp[-1].statement;
;}
    break;

  case 43:
#line 251 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_VAL;
    yyval.statement->i1=yyvsp[0].int_val;
;}
    break;

  case 44:
#line 256 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_ADD,yyvsp[0].statement);
;}
    break;

  case 45:
#line 259 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_SUB,yyvsp[0].statement);
;}
    break;

  case 46:
#line 262 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_MUL,yyvsp[0].statement);
;}
    break;

  case 47:
#line 265 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_DIV,yyvsp[0].statement);
;}
    break;

  case 48:
#line 268 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_MOD,yyvsp[0].statement);
;}
    break;

  case 49:
#line 271 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_AND,yyvsp[0].statement);
;}
    break;

  case 50:
#line 274 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_OR, yyvsp[0].statement);
;}
    break;

  case 51:
#line 277 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_AND,yyvsp[0].statement);
;}
    break;

  case 52:
#line 280 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_OR, yyvsp[0].statement);
;}
    break;

  case 53:
#line 283 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_XOR,yyvsp[0].statement);
;}
    break;

  case 54:
#line 288 "dvdvmy.y"
    {
    yyval.statement=yyvsp[-1].statement;
;}
    break;

  case 55:
#line 291 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_EQ,yyvsp[0].statement);
;}
    break;

  case 56:
#line 294 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_NE,yyvsp[0].statement);
;}
    break;

  case 57:
#line 297 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_GTE,yyvsp[0].statement);
;}
    break;

  case 58:
#line 300 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_GT,yyvsp[0].statement);
;}
    break;

  case 59:
#line 303 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_LTE,yyvsp[0].statement);
;}
    break;

  case 60:
#line 306 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_LT,yyvsp[0].statement);
;}
    break;

  case 61:
#line 309 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_LOR,yyvsp[0].statement);
;}
    break;

  case 62:
#line 312 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_LAND,yyvsp[0].statement);
;}
    break;

  case 63:
#line 315 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_LOR,yyvsp[0].statement);
;}
    break;

  case 64:
#line 318 "dvdvmy.y"
    {
    yyval.statement=statement_expression(yyvsp[-2].statement,VM_LAND,yyvsp[0].statement);
;}
    break;

  case 65:
#line 321 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_NOT;
    yyval.statement->param=yyvsp[0].statement;
;}
    break;

  case 66:
#line 328 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_SET;
    yyval.statement->i1=yyvsp[-3].int_val;
    yyval.statement->param=yyvsp[-1].statement;
;}
    break;

  case 67:
#line 334 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_ADD,yyvsp[-1].statement);
;}
    break;

  case 68:
#line 337 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_SUB,yyvsp[-1].statement);
;}
    break;

  case 69:
#line 340 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_MUL,yyvsp[-1].statement);
;}
    break;

  case 70:
#line 343 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_DIV,yyvsp[-1].statement);
;}
    break;

  case 71:
#line 346 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_MOD,yyvsp[-1].statement);
;}
    break;

  case 72:
#line 349 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_AND,yyvsp[-1].statement);
;}
    break;

  case 73:
#line 352 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_OR,yyvsp[-1].statement);
;}
    break;

  case 74:
#line 355 "dvdvmy.y"
    {
    yyval.statement=statement_setop(yyvsp[-3].int_val,VM_XOR,yyvsp[-1].statement);
;}
    break;

  case 75:
#line 360 "dvdvmy.y"
    {
    yyval.statement=statement_new();
    yyval.statement->op=VM_IF;
    yyval.statement->param=yyvsp[-2].statement;
    yyvsp[-2].statement->next=statement_new();
    yyvsp[-2].statement->next->op=VM_IF;
    yyvsp[-2].statement->next->param=yyvsp[0].statement;
;}
    break;

  case 76:
#line 370 "dvdvmy.y"
    {
    yyval.statement=yyvsp[0].statement;
;}
    break;

  case 77:
#line 373 "dvdvmy.y"
    {
    yyval.statement=yyvsp[-2].statement;
    yyval.statement->param->next->next=yyvsp[0].statement;
;}
    break;


    }

/* Line 1010 of yacc.c.  */
#line 1879 "dvdvmy.c"

  yyvsp -= yylen;
  yyssp -= yylen;


  YY_STACK_PRINT (yyss, yyssp);

  *++yyvsp = yyval;


  /* Now `shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */

  yyn = yyr1[yyn];

  yystate = yypgoto[yyn - YYNTOKENS] + *yyssp;
  if (0 <= yystate && yystate <= YYLAST && yycheck[yystate] == *yyssp)
    yystate = yytable[yystate];
  else
    yystate = yydefgoto[yyn - YYNTOKENS];

  goto yynewstate;


/*------------------------------------.
| yyerrlab -- here on detecting error |
`------------------------------------*/
yyerrlab:
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
#if YYERROR_VERBOSE
      yyn = yypact[yystate];

      if (YYPACT_NINF < yyn && yyn < YYLAST)
	{
	  YYSIZE_T yysize = 0;
	  int yytype = YYTRANSLATE (yychar);
	  const char* yyprefix;
	  char *yymsg;
	  int yyx;

	  /* Start YYX at -YYN if negative to avoid negative indexes in
	     YYCHECK.  */
	  int yyxbegin = yyn < 0 ? -yyn : 0;

	  /* Stay within bounds of both yycheck and yytname.  */
	  int yychecklim = YYLAST - yyn;
	  int yyxend = yychecklim < YYNTOKENS ? yychecklim : YYNTOKENS;
	  int yycount = 0;

	  yyprefix = ", expecting ";
	  for (yyx = yyxbegin; yyx < yyxend; ++yyx)
	    if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
	      {
		yysize += yystrlen (yyprefix) + yystrlen (yytname [yyx]);
		yycount += 1;
		if (yycount == 5)
		  {
		    yysize = 0;
		    break;
		  }
	      }
	  yysize += (sizeof ("syntax error, unexpected ")
		     + yystrlen (yytname[yytype]));
	  yymsg = (char *) YYSTACK_ALLOC (yysize);
	  if (yymsg != 0)
	    {
	      char *yyp = yystpcpy (yymsg, "syntax error, unexpected ");
	      yyp = yystpcpy (yyp, yytname[yytype]);

	      if (yycount < 5)
		{
		  yyprefix = ", expecting ";
		  for (yyx = yyxbegin; yyx < yyxend; ++yyx)
		    if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
		      {
			yyp = yystpcpy (yyp, yyprefix);
			yyp = yystpcpy (yyp, yytname[yyx]);
			yyprefix = " or ";
		      }
		}
	      yyerror (yymsg);
	      YYSTACK_FREE (yymsg);
	    }
	  else
	    yyerror ("syntax error; also virtual memory exhausted");
	}
      else
#endif /* YYERROR_VERBOSE */
	yyerror ("syntax error");
    }



  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse lookahead token after an
	 error, discard it.  */

      if (yychar <= YYEOF)
        {
          /* If at end of input, pop the error token,
	     then the rest of the stack, then return failure.  */
	  if (yychar == YYEOF)
	     for (;;)
	       {
		 YYPOPSTACK;
		 if (yyssp == yyss)
		   YYABORT;
		 YYDSYMPRINTF ("Error: popping", yystos[*yyssp], yyvsp, yylsp);
		 yydestruct (yystos[*yyssp], yyvsp);
	       }
        }
      else
	{
	  YYDSYMPRINTF ("Error: discarding", yytoken, &yylval, &yylloc);
	  yydestruct (yytoken, &yylval);
	  yychar = YYEMPTY;

	}
    }

  /* Else will try to reuse lookahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:

#ifdef __GNUC__
  /* Pacify GCC when the user code never invokes YYERROR and the label
     yyerrorlab therefore never appears in user code.  */
  if (0)
     goto yyerrorlab;
#endif

  yyvsp -= yylen;
  yyssp -= yylen;
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;	/* Each real token shifted decrements this.  */

  for (;;)
    {
      yyn = yypact[yystate];
      if (yyn != YYPACT_NINF)
	{
	  yyn += YYTERROR;
	  if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYTERROR)
	    {
	      yyn = yytable[yyn];
	      if (0 < yyn)
		break;
	    }
	}

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
	YYABORT;

      YYDSYMPRINTF ("Error: popping", yystos[*yyssp], yyvsp, yylsp);
      yydestruct (yystos[yystate], yyvsp);
      YYPOPSTACK;
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  YYDPRINTF ((stderr, "Shifting error token, "));

  *++yyvsp = yylval;


  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturn;

/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturn;

#ifndef yyoverflow
/*----------------------------------------------.
| yyoverflowlab -- parser overflow comes here.  |
`----------------------------------------------*/
yyoverflowlab:
  yyerror ("parser stack overflow");
  yyresult = 2;
  /* Fall through.  */
#endif

yyreturn:
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif
  return yyresult;
}



